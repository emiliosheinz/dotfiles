// ws-agents — report opencode's state to the tmux status line.
//
// Claude reports through its own hooks (see claude/.claude/settings.json);
// opencode has none, so this plugin plays the same role. The event mapping
// mirrors herdr's opencode integration, which sits beside this file. State is
// one file per pane, read back by the ws-agents script.

import { mkdirSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const STATE_DIR = join(homedir(), ".cache", "ws-agents");
const pane = process.env.TMUX_PANE?.replace(/^%/, "");

const STATE_BY_EVENT = new Map([
  ["permission.asked", "blocked"],
  ["question.asked", "blocked"],
  ["session.error", "blocked"],
  ["permission.replied", "working"],
  ["question.replied", "working"],
  ["question.rejected", "working"],
  ["tool.execute.before", "working"],
  ["tool.execute.after", "working"],
  ["session.compacted", "working"],
  ["session.idle", "idle"],
]);

let reported;

function report(state) {
  if (state === reported) return;
  reported = state;
  mkdirSync(STATE_DIR, { recursive: true });
  writeFileSync(join(STATE_DIR, pane), `${state}\n`);
  spawn("tmux", ["refresh-client", "-S"], { stdio: "ignore" }).unref();
}

export const WsAgentsPlugin = async () => {
  // No pane means no status line to report to: a headless or remote server.
  if (!pane) return {};
  report("idle");
  return {
    "chat.message": async () => report("working"),
    event: async ({ event }) => {
      const state = STATE_BY_EVENT.get(event?.type);
      if (state) report(state);
    },
  };
};

export default { id: "ws-agents", server: WsAgentsPlugin, setup() {} };
