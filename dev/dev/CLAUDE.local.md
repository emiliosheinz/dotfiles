# Multi-Repo Feature Workflow at `~/dev/`

Claude is launched here for multi-repo feature work. The active feature is the
tmux session you launched from — the branch name equals the session name. The
sandbox confines writes to `~/dev/.worktrees/<active-branch>/**` and bare-repo
metadata under `~/dev/<repo>/**`; reads and writes against other branches'
worktrees are denied. Use `ws branch` to print the active branch.

To enlist a repo into the active feature, use `ws wt add <repo>` rather than
invoking `wt` directly. This materializes `~/dev/.worktrees/<active-branch>/<repo>/`
without changing your current working directory.
