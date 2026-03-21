# Claude Code — Global Preferences

## Response Style

- No emojis. Ever.
- No filler phrases ("Great question!", "Certainly!", "Of course!").
- Concise, direct answers. Lead with the result, not the reasoning.
- Prefer direct statements over hedging ("This will" not "This might potentially").
- Do not create README files, architecture docs, or internal module docs unless explicitly asked.

## Code Principles

- Self-documenting code is the goal. Add comments only for:
  - Public API documentation (JSDoc/equivalent)
  - Non-obvious algorithms or performance optimizations
  - Critical business logic that can't be expressed in code
- Never assume. If information is missing or ambiguous, ask before proceeding.
- Fail fast. Prefer early returns. Throw for impossible states.
- Never add dependencies without asking first. No exceptions.
- Match existing patterns exactly. Use existing formatters/linters (Prettier, ESLint, Biome).
- Fix obvious issues in scope (poor naming, local duplication). Do not refactor for its own sake.
- Apply SOLID, DDD, and DRY where they improve maintainability — not at the cost of clarity.
- Prefer simplicity over cleverness.

## Testing

- Write tests for all new functionality.
- No coverage-metric tests ever.
- Tests must be focused on meaningful behavior, not implementation details.

## Error Handling

- APIs/boundaries: explicit error handling with clear messages.
- Internal utilities: let errors bubble.
- Default: early returns for validation, throw for impossible states.

## Toolchain (macOS / Darwin)

- Shell: zsh
- Editor: Neovim (`nvim`)
- Terminal multiplexer: tmux
- Package manager: Homebrew (custom prefix: `~/.homebrew`)
- File listing: eza (aliased as `ls`, `ll`, `la`, `lt`)
- File reading: bat (aliased as `cat`)
- Fuzzy finder: fzf
- Directory jumper: zoxide (aliased as `cd`)
- System monitor: btop (aliased as `top`, `htop`)
- Git TUI: lazygit
- GitHub CLI: gh
- Search: ripgrep (`rg`) — available system-wide
- JSON: jq — available system-wide

## Search & Exploration

- Use Grep with targeted patterns before reading files.
- Use Glob to find files by pattern — do not speculatively list directories.
- Read specific files; never read node_modules, .git, or build output directories.
- Prefer `rg` patterns over reading multiple files when searching for usage.

## Context Management

- Run `/compact` when context usage exceeds ~80% (visible in status line).
- After `/compact`, re-read only the files actively being modified before continuing.
- If a task is complete and a new unrelated task starts, suggest `/compact` proactively.

## Git

- Default branch: `main`.
- Pull strategy: merge (not rebase).
- Never `git push`, `git rebase`, `git reset --hard`, or `git clean` without explicit instruction.
- Commit messages: imperative mood, concise, no trailing period.
- Always create new commits rather than amending unless explicitly asked.
