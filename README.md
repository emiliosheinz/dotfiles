# Dotfiles

This repository contains my dotfiles and scripts that I use to setup my devepment environment. I mainly use `bash` and [GNU Stow](https://www.gnu.org/software/stow/) to manage them.


## Usage

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/emiliosheinz/dotfiles/main/init.sh)"
```

## Agent sandbox

`claude` and `opencode` are shell functions that run the agent through
`sandbox-run`, which enforces the `ws` workspace rules with a macOS Seatbelt
profile.

Launched under `~/dev` (including inside a repo or a worktree), the agent can
read everything and write everywhere except:

- primary clones: `~/dev/<repo>/` is read-only outside its `.git/`, so a repo
  changes only through a worktree enlisted with `ws wt add <repo> -b <base>`;
- other workspaces: `~/dev/.worktrees/` is read-only except the active
  workspace's folder;
- renaming or deleting `~/dev`, `~/dev/.worktrees` or a primary clone.

The active workspace is `ws workspace` (the tmux session), so launch agents
from a workspace pane. Launching inside another workspace's folder is refused.
Launched outside `~/dev`, the agent runs unsandboxed. Claude runs in auto mode
(`permissions.defaultMode` in its user settings); opencode runs with every
permission allowed. `command claude` / `command opencode` skip the sandbox.

Known limits:

- Primary clones are the repos present when the agent starts; a repo cloned
  into `~/dev` later is writable for that session.
- Every clone's `.git/` is writable (`ws wt add` and commits need it), so an
  agent can still move other workspaces' branches or edit `.git/hooks` and
  `.git/config`. tmux, Docker and `open` also reach outside the sandbox.
- A tool cannot start its own sandbox inside the session (`sandbox_apply:
  Operation not permitted`). Chrome and the Playwright MCP run with
  `--no-sandbox`; add the same flag to other MCP servers
  (`claude mcp add ... -- <cmd> --no-sandbox`) or run the tool on the host.
- `ws wt remove` and `ws kill` write to other workspaces and the primary
  clone; run them from a host shell.
- A tmux server first started inside a session hands its sandbox to every
  later pane. Run `tmux kill-server` and start tmux from the host.

`dev/dev/AGENTS.local.md` (with `CLAUDE.local.md` symlinked to it so both
agents share one file) holds the rules agents get at `~/dev`.

## Inspiration

- https://github.com/CoreyMSchafer/dotfiles
