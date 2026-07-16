# Dotfiles

This repository contains my dotfiles and scripts that I use to setup my devepment environment. I mainly use `bash` and [GNU Stow](https://www.gnu.org/software/stow/) to manage them.


## Usage

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/emiliosheinz/dotfiles/main/init.sh)"
```

## Multi-repo agent workflow

Multi-repo features launch an agent at `~/dev/` via `sandbox-run claude` or
`sandbox-run opencode`. From that depth the sandbox resolves the active
workspace from the tmux session name and applies the dev-scope isolation:
`~/dev` stays writable for non-repo files, each git repo directly under
`~/dev` is read-only in its working tree with `.git/` re-allowed for
worktree metadata, and the `~/dev/.worktrees/` subtree is sealed off
except for the active workspace, which is fully writable. Launched from
inside a workspace worktree at `~/dev/.worktrees/<workspace>/<repo>`,
only that worktree and the matching `~/dev/<repo>/.git` are writable;
the source repo's working tree stays read-only. `sandbox-run` refuses to
launch at `~/dev/` outside a workspace pane.

Use `ws wt add <repo>` to enlist a repo into the active feature without
changing your current directory. The agent-facing summary lives at
`~/dev/AGENTS.local.md` (with `~/dev/CLAUDE.local.md` symlinked to it so
Claude and opencode share the same guidance, and the `.local` suffix keeps
it out of the way of per-project AGENTS.md / CLAUDE.md files); see
`.specs/multi-repo-claude-isolation/` for the design.

## Inspiration

- https://github.com/CoreyMSchafer/dotfiles
