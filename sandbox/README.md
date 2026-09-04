# Agent sandbox

Claude Code and opencode run under a macOS Seatbelt policy applied by
`sandbox-run` (the `claude` / `opencode` shell functions in
`zsh/.aliases.zsh`). The base policy is generated at every launch by
[agent-safehouse](https://github.com/eugene1g/agent-safehouse); this repo owns
only the workspace scope, self-governance and telemetry rules in
`ws-scope.sb`, plus the launcher, the `hostrun` broker and the denial log.

> `sandbox-exec` is deprecated since macOS 10.15 but still works on macOS 26.
> There is no supported CLI replacement.

**Break-glass:** `command claude` (or `command opencode`) runs the agent
unsandboxed.

## Files

| Path | Role |
|---|---|
| `scripts/.local/scripts/sandbox-run` | launcher: preconditions, workspace scope, session, policy, sidecar, child process |
| `sandbox/ws-scope.sb` | repo-owned rules appended after every generated rule |
| `scripts/.local/bin/claude` | host-owned launcher that runs the newest installed Claude Code version |
| `scripts/.local/scripts/hostrun`, `hostrun-broker` | request/approve/execute channel to the host |
| `sandbox/local.hostrun.plist.template`, `sandbox/install-broker.zsh`, `sandbox/auto-approve.default` | broker launchd job, installer, initial auto-approve list |
| `scripts/.local/scripts/sandbox-denial-hook`, `opencode/.config/opencode/plugins/sandbox-denials/` | agent-visible denial capture (Claude Code hook, opencode plugin) |
| `scripts/.local/scripts/sandbox-note`, `sandbox-report` | agent self-report; host-side report and retention |
| `sandbox/smoke.zsh`, `sandbox/test-*.zsh`, `sandbox/test-opencode-plugin.mjs` | smoke matrix and unit tests (host only) |

## Policy

`sandbox-run` renders the policy with

```
safehouse --stdout --workdir=<cwd> \
  --enable=docker,ssh,playwright-chrome,process-control,shell-init,keychain,clipboard \
  --add-dirs-ro=<brew prefix>[:$TERMINFO] --add-dirs=<brew cache> \
  --append-profile=<per-launch scope file> -- <claude|opencode>
```

and passes the resulting file to `sandbox-exec -f`. The agent name selects
the generator's agent profile (`~/.claude`, `~/.config/opencode` state). The
scope file is the per-launch dynamic block followed by `ws-scope.sb`:

1. **Workspace scope** (dynamic). `~/dev` launches: `~/dev` writable, every
   repo working tree read-only with its `.git` writable, `.worktrees` denied
   except the active workspace. `~/dev/.worktrees/<ws>/<repo>` launches: only
   that repo's source clone (read-only, `.git` writable) and the workdir;
   sibling workspaces are invisible even though the generator snapshots
   linked worktrees as readable. Other launch directories: the workdir only.
2. **Session grants** (dynamic): the session log, the session's broker queue,
   the shared inbox, the workspace tool directory.
3. **Host grants** the generator lacks: dotfiles (read), `~/.local/{bin,scripts}`,
   `~/.cache` (write), oh-my-zsh, zinit, `~/.config/{ccstatusline,worktrunk,nvim,tmux}`,
   the broker job definition, the Docker credential helper's log directory
   (write; image pulls fail without it), `system-sched`, and `/bin/ps` executed
   `(with no-sandbox)` because Seatbelt forbids setuid exec inside a sandbox.
4. **Self-governance denies**: Claude and opencode settings, instructions,
   agents, skills, plugins, hooks; `~/.mcp.json`; shell startup files,
   `~/.gitconfig`, `~/.config/git`, `~/.ssh/config`, `~/Library/LaunchAgents`;
   `~/.local/{bin,scripts}`; `~/.config/gh`; project `.claude/settings*.json`.
5. **Git escape guards**: `.git/hooks`, `.git/config`, `.git/config.worktree`
   in every `~/dev` repo and in the workdir's repository.
6. **tmux socket** (file and unix-socket connect).
7. **Secrets**: `~/.ssh/id_*`, `~/.gnupg`, `~/.aws`, `~/.azure`, `~/.kube`,
   `~/.config/gcloud`, Chrome/Firefox/Safari profiles, Mail, Messages.

The launch directory is always writable except for the guards in 4 and 5.
A `~/dotfiles` launch therefore edits the sandbox, the launcher, hooks and
shell config through their stow targets; the only exception is the claude
launcher script itself, which stays read-only everywhere.

### Allowed unix sockets

Unix sockets are deny-by-default (generator ≥ 0.11). Allowed:

| Socket | Why |
|---|---|
| `/private/tmp/com.apple.launchd.*/Listeners` (ssh-agent) | `git push`, `ssh-add -l`; per-signature approval is opt-in (see host setup) |
| `/var/run/docker.sock`, `~/.docker/run/docker.sock` | Docker CLI against Docker Desktop |
| `/private/var/run/mDNSResponder` | DNS |
| Chrome `SingletonSocket` under `/var/folders` | Chrome launched inside |

The tmux control socket (`/private/tmp/tmux-<uid>/`) is denied; tmux verbs
go through `hostrun`.

## Sessions and state

Every launch is a session `<epoch>-<pid>` under
`~/.local/state/agent-sandbox`:

| Zone | Path | Writable inside |
|---|---|---|
| session | `sessions/<sid>/{log.jsonl,requests/,results/}` | that session only |
| shared | `inbox/` (empty markers `<sid>.<rid>`) | every session |
| host | `host/{meta/,policy/,storm/,scratch/,auto-approve,broker.jsonl,events.jsonl}` | nobody |

Exported inside: `SANDBOX_SESSION_ID`, `SANDBOX_SESSION_LOG`, `WS_WORKSPACE`
(the resolved workspace, empty outside `~/dev`), `PATH` prefixed with
`<tooldir>/bin` (`~/dev/.worktrees/<ws>/.tools` or `<workdir>/.tools`).
`NPM_CONFIG_PREFIX` is unset (nvm). The agent runs as a child of
`sandbox-run`: signals are forwarded, the exit status propagated, the queue
removed on exit, and a supervisor caps the session log at 20 MB.

## hostrun

`hostrun <command> [args...]` asks the host to run a non-interactive command
in the session's workdir. The request goes into the session queue plus an
empty marker in the inbox; the launchd job `local.hostrun` wakes on the
inbox, reads the request once into memory (the snapshot), takes workspace
and workdir from launcher-written host meta, derives the deadline from the
request file's mtime + 30 s, and decides:

1. **storm**: three consecutive denials or timeouts from one session block
   further requests for 10 minutes (`hostrun: storm guard active`, exit 126).
2. **auto**: the command line matches a line of the host-only list
   `host/auto-approve` (anchored extended regexes; a bad line disables the
   whole list). Initial list: `open https://…` and `ws wt add <repo> [-b <base>]`.
3. **dialog**: an osascript dialog showing the workspace and the exact
   command line, default button Deny, giving up at the deadline.

Approved commands run directly (no shell, no rc files), with stdin from
`/dev/null`, a fixed `PATH`, `HOME` and `WS_WORKSPACE`, a 600 s cap and 1 MB
captures. The result is delivered by rename; every request is logged with
its decision in `host/broker.jsonl`. Exit codes: the command's own; 126
denied / storm / invalid; 124 timed out; 127 broker not installed.

The broker is non-interactive: anything that prompts on a TTY (`gh auth
login`, `docker login`) is a user-run step. **Do not pass secrets on the
`hostrun` command line**: it is stored in the broker log.

`ws` inside a session re-dispatches every verb except `workspace` through
`hostrun`; `ws wt add` is auto-approved so worktree creation (which writes
`.git/config`) runs on the host.

## Denial log and report

Three producers append to the session log (`SANDBOX_SESSION_LOG`):

- **kernel** — `sandbox-run` streams `/usr/bin/log stream` denials
  (`Sandbox: <proc>(<pid>) deny(1) <op> <path>`) on the host; the launcher
  warns `denial capture unavailable` and continues when the stream cannot
  start. The stream is system-wide, so concurrent sessions capture the same
  denials; the report dedupes them.
- **hook** — `sandbox-denial-hook` on Claude Code `PostToolUse` /
  `PostToolUseFailure` (Bash) and the opencode `sandbox-denials` plugin
  record tool output matching
  `Operation not permitted|EPERM|Sandbox: .* deny\(|Mounts denied`.
- **note** — `sandbox-note "<want>" "<why>"`, run by the agent once when
  blocked.

`sandbox-report [days]` (default 7) prints top op+path pairs, top hook
commands, every note and every broker record; it prunes session directories
older than 30 days once they exceed 50 MB and rotates the broker log.

## Smoke matrix

`sandbox/smoke.zsh` runs every row of spec SBOX-52 through the real launcher
with a stub agent, one fresh policy per row. Fixture: a throwaway repo
`~/dev/sbx-fixture` with worktrees in workspaces `sbx-a` and `sbx-b`
(override with `SMOKE_REPO`, `SMOKE_WS`, `SMOKE_OTHER`), `~/.ssh/id_ed25519`,
Google Chrome, `gh auth status`, a loaded ssh-agent key, a running tmux
server, `safehouse` and `jq`. Broker rows are skipped until the launchd job
is installed. `sandbox/test-*.zsh` and `node sandbox/test-opencode-plugin.mjs`
are the unit tests; all must run from an unsandboxed shell.

```zsh
zsh sandbox/smoke.zsh            # whole matrix
zsh sandbox/smoke.zsh --only SBOX-40
```

## Accepted risks

| Risk | Why accepted |
|---|---|
| ssh-agent reachable (signing with the loaded key) | git push must work; per-signature approval is opt-in (`ssh-add -c` + askpass) |
| Docker socket reachable | Docker CLI must work; File Sharing list limits bind mounts (`Mounts denied`) |
| Agent binaries writable (`~/.local/share/claude/versions`, `~/.config/opencode` state) | self-update from inside; the launcher entry points stay read-only |
| Cross-workspace `.git` refs/objects writable (`~/dev/<repo>/.git`) | `ws wt add` and fetch/push need it; hooks and config are denied |
| `~/.claude.json` and auto-memory (`~/.claude/projects/*/memory`) writable | live session state; denying breaks sessions |
| `~/dotfiles` launches are trusted sessions (sandbox, launcher, hooks, shell and agent config writable through their stow targets) | the checkout is the workdir; review with `git diff` before committing |
| Inbound network and open egress | exfiltration is out of the threat model |
| `process-control`: agents can signal host processes, including the sidecar | supervisor restarts it once and records every death |
| Inbox markers deletable by another session | markers carry no content; DoS only |
| `/bin/ps` runs unsandboxed | setuid exec is impossible inside; ps only reads process state |

## Host setup

Every step is idempotent; run the whole list on a new machine and again
after changes.

1. **Generator and jq**
   ```zsh
   brew trust eugene1g/safehouse
   brew install eugene1g/safehouse/agent-safehouse   # or brew upgrade agent-safehouse
   brew install jq
   safehouse --version    # must be >= 0.11.1
   ```
2. **Launcher script**: remove the installer's symlink and stow the scripts
   package (`~/.local/bin/claude` becomes the dotfiles launcher).
   ```zsh
   [[ -L ~/.local/bin/claude && "$(readlink ~/.local/bin/claude)" != *dotfiles* ]] && rm ~/.local/bin/claude
   find ~/dotfiles -name .DS_Store -not -path '*/.git/*' -delete   # Finder litter aborts stow
   cd ~/dotfiles && stow scripts opencode claude zsh
   ```
3. **Broker**: renders the launchd job with your `$HOME`, seeds
   `host/auto-approve` only when absent, (re)loads the job.
   ```zsh
   zsh ~/dotfiles/sandbox/install-broker.zsh        # --uninstall to remove
   ```
4. **Docker Desktop**: Settings → Advanced → enable the default socket
   (`/var/run/docker.sock`); Settings → Resources → File Sharing: keep only
   `~/dev`, `/tmp`, `/private`, `/var/folders` (add a path here when a
   compose stack needs it). Start Docker Desktop from inside with
   `hostrun open -a Docker`.
5. **Optional per-signature ssh approval**: `brew install theseal/ssh-askpass/ssh-askpass`,
   then `ssh-add -c ~/.ssh/id_ed25519` (re-add after each login; the agent
   prompts on every signature).
6. **Headed Chrome for automation**: `agent-chrome` (alias) starts Chrome with
   `--remote-debugging-port=9222 --user-data-dir=~/.local/state/agent-chrome`
   on the host; inside, `curl -s http://127.0.0.1:9222/json/version` returns
   the `webSocketDebuggerUrl` for Playwright's `connectOverCDP`.
7. **Smoke fixture** (once):
   ```zsh
   git init ~/dev/sbx-fixture && (cd ~/dev/sbx-fixture && echo fixture > README.md && git add . && git commit -qm init)
   git -C ~/dev/sbx-fixture worktree add -b sbx-a ~/dev/.worktrees/sbx-a/sbx-fixture
   git -C ~/dev/sbx-fixture worktree add -b sbx-b ~/dev/.worktrees/sbx-b/sbx-fixture
   zsh ~/dotfiles/sandbox/smoke.zsh
   ```

**Rollback**: revert the commit; `command claude` bypasses everything;
`brew pin agent-safehouse` (or `brew install agent-safehouse@<version>` from
the tap) if a generator upgrade regresses the policy.

## Manual verification

One line per AC the automated matrix cannot see. Fill `observed on:` with
the date and machine.

| AC | Steps | observed on |
|---|---|---|
| SBOX-08 Docker socket | Docker Desktop running; inside: `docker ps` exits 0 | observed on: 2026-09-04 (personal; `docker ps` and `docker pull alpine:3.20` exit 0 inside) |
| SBOX-09 Ctrl-C / resize | in the Claude TUI: Ctrl-C interrupts a running tool, a second Ctrl-C prompts to exit; resize the pane and the UI reflows | observed on: |
| SBOX-14 Docker mounts | inside: `docker run --rm -v "$HOME/.ssh:/x" alpine true` fails with `Mounts denied`; `docker run --rm -v "$PWD:/x" alpine true` succeeds | observed on: 2026-09-04 (personal; `$PWD` mount ok; `~/.ssh` mount still succeeds because File Sharing has not been narrowed in the Docker Desktop GUI, pending) |
| SBOX-19 browser | inside: `hostrun open https://example.com` exits 0 and the page opens in the default browser | observed on: 2026-09-03 (personal; exit 0 and `auto` in the broker log seen by smoke, tab not visually confirmed) |
| SBOX-30 approve / deny | inside: `hostrun /bin/echo hi` → dialog → Approve prints `hi`; again → Deny prints `hostrun: denied`, exit 126 | observed on: 2026-09-04 (personal; Approve printed `hi` rc 0, Deny printed `hostrun: denied` rc 126) |
| SBOX-31 prompt | the dialog shows the workspace name (or workdir) and the exact command line; Deny is the focused button | observed on: |
| SBOX-33 logged | `sandbox-report 1` on the host lists both requests with `approved` and `denied` | observed on: 2026-09-04 (personal) |
| SBOX-34 timeout | inside: `hostrun /bin/echo hi`, ignore the dialog for 30 s → `hostrun: timed out`, exit 124; the dialog closes | observed on: |
| SBOX-35 concurrent / snapshot | two sessions run `hostrun /bin/echo <session>` at once; each prints its own; broker log shows two records | observed on: |
| SBOX-36 storm | deny three requests in a row; the fourth prints `hostrun: storm guard active` without a dialog | observed on: |
| SBOX-51 OAuth refresh | keep a session open past the token `expiresAt` (`security find-generic-password -s "Claude Code-credentials" -w \| jq .claudeAiOauth.expiresAt`) and send a prompt: no login prompt | observed on: |
| SBOX-53 spoke | `zsh sandbox/smoke.zsh` passes on the spoke machine | observed on: |
| SBOX-62 setup idempotency | run the host setup list twice; the second run changes nothing (`launchctl print gui/$UID/local.hostrun` still loaded, symlinks unchanged) | observed on: 2026-09-04 (personal; steps 1-3 twice, launcher symlink, plist and auto-approve checksums identical, job loaded) |
| SBOX-63 CDP | `agent-chrome` on the host; inside: `curl -s http://127.0.0.1:9222/json/version` contains `webSocketDebuggerUrl` | observed on: 2026-09-03 (personal) |
