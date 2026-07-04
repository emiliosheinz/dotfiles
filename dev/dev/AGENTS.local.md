# Multi-Repo Workspaces at `~/dev/`

_These rules are enforced by the macOS sandbox at the filesystem level.
Crossing a boundary fails the tool call. Follow them deliberately — do not
retry past a denied read or write, do not bypass, do not try to edit the
policy._

## The workspace model

A **workspace** is one unit of parallel feature work. Its name is a single
identifier that simultaneously names three things:

- the tmux session you are running in,
- the folder `~/dev/.worktrees/<workspace>/`,
- a git branch of the same name in every repo enlisted in the workspace.

A workspace can enlist multiple repos at once. Each enlisted repo gets its
own worktree at `~/dev/.worktrees/<workspace>/<repo>/`, checked out to the
branch named `<workspace>`. This is how you work on the same feature across
multiple repos in parallel — and how you keep several features in flight on
the same repo without stepping on each other.

Run `ws workspace` to print the active workspace name.

## Layout

- You are running at `~/dev/`. Every repo on the machine is visible here.
  `~/dev/<repo>/` is the primary clone of `<repo>`; do not edit source files
  there. All feature work happens in worktrees, not in the primary clone.
- Code for the current workspace lives under
  `~/dev/.worktrees/<workspace>/<repo>/`. That is `<repo>`'s worktree for
  this workspace. All edits happen there.

## Enlisting a repo

When `<repo>` has no worktree yet for the active workspace, first **ask the
user which base branch to fork from**. Do not guess and do not offer a
free-form prompt — the correct base varies per repo and per workspace.

List the repo's local branches and present them as concrete choices:

```
git -C ~/dev/<repo> for-each-ref --format='%(refname:short)' refs/heads/
```

Show that list to the user and ask them to pick one. Then run:

```
ws wt add <repo> -b <base>
```

This materializes `~/dev/.worktrees/<workspace>/<repo>/` without changing
your current directory. Do not call `wt` directly — `ws wt add` resolves the
workspace and validates the target repo for you.

## Permissions

- **Writes allowed** on:
  - `~/dev/.worktrees/<workspace>/**` — the current workspace's worktrees.
  - `~/dev/<repo>/**` — git metadata under the primary clone; `ws wt add`
    writes here. Do not edit source files in the primary clone yourself.
- **Reads and writes denied** on `~/dev/.worktrees/<other-workspace>/**`.
  Other workspaces are invisible to you. This isolation is intentional.

A permission-denied error means you targeted the wrong path. Re-check the
active workspace with `ws workspace` and the path you used.
