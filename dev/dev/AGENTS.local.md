# Multi-Repo Workspaces at `~/dev/`

_Other workspaces and primary-clone source are blocked by the OS for
writes. Crossing a boundary fails the tool call with `Operation not
permitted`. Do not retry past a denied write and do not try to bypass it._

## The workspace model

A **workspace** is one unit of parallel feature work. Its name is a single
identifier that simultaneously names three things:

- the workspace the user launched you in (exported as `WS_WORKSPACE`),
- the folder `~/dev/.worktrees/<workspace>/`,
- a git branch of the same name in every repo enlisted in the workspace.

A workspace can enlist multiple repos at once. Each enlisted repo gets its
own worktree at `~/dev/.worktrees/<workspace>/<repo>/`, checked out to the
branch named `<workspace>`. This is how you work on the same feature across
multiple repos in parallel — and how you keep several features in flight on
the same repo without stepping on each other.

Run `ws workspace` to print the active workspace name.

Switching branches inside a worktree (`git switch`) is fine: the workspace is
the folder, not the branch. `ws wt remove` and `ws kill` remove each worktree
whatever it has checked out, delete only the workspace's own branch and keep
any other branch.

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
your current directory; it runs directly inside the sandbox. Do not call `wt`
directly — `ws wt add` resolves the workspace and
validates the target repo for you.

## Permissions

- **Reads** are allowed everywhere.
- **Writes allowed** on:
  - `~/dev/.worktrees/<workspace>/**` — the current workspace's worktrees.
  - `~/dev/<repo>/.git/**` — git metadata under the primary clone (refs,
    objects, worktrees).
  - anything else under `~/dev/` that is not a repo (e.g. `~/dev/.specs/`).
- **Writes denied** on primary-clone source (`~/dev/<repo>/` outside
  `.git/`) and on `~/dev/.worktrees/<other-workspace>/**`. Do not change
  another workspace's branches through the shared `.git` either.

A permission-denied error means you targeted the wrong path. Re-check the
active workspace with `ws workspace` and the path you used.
