# Multi-Repo Workspace at `~/dev/`

_These rules are enforced by the macOS sandbox at the filesystem level.
Crossing a boundary fails the tool call. Follow them deliberately — do not
retry past a denied read or write, do not bypass, do not try to edit the
policy._

## Layout

- You are running at `~/dev/`. Every repo on the machine is visible here.
  `~/dev/<repo>/` is the primary clone of `<repo>`; do not edit source files
  there. All feature work happens in worktrees, not in the primary clone.
- Code for the current feature lives under
  `~/dev/.worktrees/<active-branch>/<repo>/`. That is the worktree for `<repo>`
  in this feature. All edits happen there.
- The "active branch" is the tmux session name and equals the feature name.
  Run `ws branch` to print it.

## Enlisting a repo

When `<repo>` has no worktree yet for the active branch, run:

```
ws wt add <repo>
```

This materializes `~/dev/.worktrees/<active-branch>/<repo>/` without changing
your current directory. Do not call `wt` directly — `ws wt add` resolves the
branch and validates the target repo for you.

## Permissions

- **Writes allowed** on:
  - `~/dev/.worktrees/<active-branch>/**` — your worktrees for this feature.
  - `~/dev/<repo>/**` — git metadata under the primary clone; `ws wt add`
    writes here. Do not edit source files in the primary clone yourself.
- **Reads and writes denied** on `~/dev/.worktrees/<other-branch>/**`.
  Other features are invisible to you. This isolation is intentional.

A permission-denied error means you targeted the wrong path. Re-check the
active branch with `ws branch` and the path you used.
