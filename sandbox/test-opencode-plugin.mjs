// SBOX-41 second AC: the opencode plugin appends a hook record for a bash
// tool call whose output matches the denial pattern, and nothing otherwise.
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const { SandboxDenialsPlugin } = await import(join(here, "../opencode/.config/opencode/plugins/sandbox-denials/plugin.js"));
const fixture = JSON.parse(readFileSync(join(here, "fixtures/opencode-tool-after.json"), "utf8"));
const dir = mkdtempSync(join(tmpdir(), "sbx-plugin-"));
const log = join(dir, "log.jsonl");
writeFileSync(log, "");
process.env.SANDBOX_SESSION_LOG = log;
process.env.SANDBOX_SESSION_ID = "123-45";
process.env.WS_WORKSPACE = "wsA";
const records = () => readFileSync(log, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
let failed = 0;
const check = (name, fn) => { try { fn(); console.log(`ok   ${name}`); } catch (e) { console.log(`FAIL ${name}: ${e.message}`); failed = 1; } };

const hooks = await SandboxDenialsPlugin({});
await hooks["tool.execute.after"](fixture.input, fixture.output);
check("denied bash call appends one hook record", () => assert.equal(records().length, 1));
check("record carries src, session, ws, cmd, snippet", () => {
  const r = records()[0];
  assert.equal(r.src, "hook");
  assert.equal(r.session, "123-45");
  assert.equal(r.ws, "wsA");
  assert.equal(r.cmd, "cat ~/.ssh/id_ed25519");
  assert.match(r.snippet, /Operation not permitted/);
  assert.match(r.ts, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
});
await hooks["tool.execute.after"](fixture.input, { ...fixture.output, output: "all good\n" });
check("clean output appends nothing", () => assert.equal(records().length, 1));
await hooks["tool.execute.after"]({ ...fixture.input, tool: "read" }, fixture.output);
check("non-bash tools are ignored", () => assert.equal(records().length, 1));
delete process.env.SANDBOX_SESSION_LOG;
await hooks["tool.execute.after"](fixture.input, fixture.output);
check("no SANDBOX_SESSION_LOG: no-op", () => assert.equal(records().length, 1));
rmSync(dir, { recursive: true });
process.exit(failed);
