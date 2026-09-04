// sandbox-denials — opencode plugin
//
// Records agent-visible sandbox denials (SBOX-41): after every bash tool
// call whose output matches the denial pattern, appends a `hook` record to
// the session's denial log. No-op outside a sandbox session
// (SANDBOX_SESSION_LOG unset) and once the log reaches its 20 MB cap.
import { appendFileSync, statSync } from "node:fs";

const DENIAL = /Operation not permitted|EPERM|Sandbox: .* deny\(|Mounts denied/;
const LOG_CAP = 20 * 1024 * 1024;

export const SandboxDenialsPlugin = async () => ({
  "tool.execute.after": async (input, output) => {
    const log = process.env.SANDBOX_SESSION_LOG;
    if (!log || input.tool !== "bash") return;
    const text = typeof output.output === "string" ? output.output : JSON.stringify(output.output ?? "");
    if (!DENIAL.test(text)) return;
    try {
      if (statSync(log).size >= LOG_CAP) return;
      const record = {
        ts: new Date().toISOString().replace(/\.\d{3}Z$/, "Z"),
        src: "hook",
        session: process.env.SANDBOX_SESSION_ID ?? "",
        ws: process.env.WS_WORKSPACE || process.cwd(),
        cmd: input.args?.command ?? "",
        snippet: text.slice(0, 400),
      };
      appendFileSync(log, JSON.stringify(record) + "\n");
    } catch {
      // the log is the agent's own file; failing to append must never break the tool call
    }
  },
});
