# Dotfiles

This repository contains my dotfiles and scripts that I use to setup my devepment environment. I mainly use `bash` and [GNU Stow](https://www.gnu.org/software/stow/) to manage them.


## Usage

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/emiliosheinz/dotfiles/main/init.sh)"
```

## Multi-repo agent workflow

Multi-repo features launch an agent at `~/dev/` via `sandbox-run claude` or
`sandbox-run opencode`. From that depth the sandbox resolves the active
branch from the tmux session name and confines writes to
`~/dev/.worktrees/<active-branch>/**` plus bare-repo metadata under
`~/dev/<repo>/**`; other branches' worktrees are sealed off for both reads
and writes. `sandbox-run` refuses to launch outside a workspace pane.

Use `ws wt add <repo>` to enlist a repo into the active feature without
changing your current directory. The agent-facing summary lives at
`~/dev/AGENTS.md` (with `~/dev/CLAUDE.md` symlinked to it so Claude and
opencode share the same guidance); see `.specs/multi-repo-claude-isolation/`
for the design.

## Inspiration

- https://github.com/CoreyMSchafer/dotfiles
