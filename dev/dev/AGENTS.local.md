# Multi-Repo Feature Workflow at `~/dev/`

You are running inside a multi-repo feature workspace. Read this file before
touching the filesystem so you use the supported verbs and stay inside the
allowed paths.

## Launch convention

- The launch point for multi-repo features is `~/dev/`, wrapped by
  `sandbox-run claude` or `sandbox-run opencode`.
- The "active feature" is encoded in the tmux session name, which equals the
  branch name. Run `ws branch` to print it.
- Single-repo work continues to launch inside `~/dev/.worktrees/<branch>/<repo>/`
  unchanged.

## What the sandbox enforces

- **Writes allowed**:
  - `~/dev/.worktrees/<active-branch>/**` — your worktrees for this feature.
  - `~/dev/<repo>/**` — bare-repo metadata only (no source files live here;
    these writes back `wt switch --create`).
- **Reads and writes denied**:
  - `~/dev/.worktrees/<other-branch>/**` — other features are fully invisible.
- Path-level enforcement is the hard guarantee. This file is defense in depth.

## Supported verbs

- `ws branch` — print the active branch. Use it before any path-scoped action
  that needs the branch name.
- `ws wt add <repo> [branch]` — materialize a worktree for `~/dev/<repo>` at
  `~/dev/.worktrees/<active-branch>/<repo>/` without changing CWD. Branch
  defaults to `ws branch`. Use this verb for repo enlistment instead of calling
  `wt` directly.

## When `sandbox-run` refuses to launch

If launching at `~/dev/` (or `~/dev/.worktrees/<branch>/`) fails with
"no active branch resolvable", the tmux state cannot supply a branch. Recovery:

1. Launch from a workspace pane (a tmux session whose name is the branch).
2. Or `cd` into a worktree under `~/dev/.worktrees/<branch>/`.

Backstage sessions (`backstage-*`) and shells outside tmux both refuse — that
is intentional. Don't try to work around it by editing the policy.

## When the agent gets a permission-denied error

Trust the sandbox. If a write or read into another branch's worktree is
denied, you crossed the boundary by accident. Re-check the active branch with
`ws branch` and the path you targeted; do not retry with elevated permissions.
