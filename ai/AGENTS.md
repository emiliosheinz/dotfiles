# Agent Rules

## Response style

- No emojis. Ever.
- No filler openers ("Great question!", "Certainly!", "Of course!").
- Do not add Claude or any AI as a co-author on commits or PRs.
- Do not create README, architecture, or module docs unless explicitly asked.

## Code principles

- Never assume. If information is missing or ambiguous, ask before proceeding.
- Never add dependencies without asking first. No exceptions.
- Fail fast. Prefer early returns; throw for impossible states.
- Match existing patterns exactly. Use existing formatters/linters (Prettier, ESLint, Biome).
- Fix obvious issues in scope (poor naming, local duplication). Do not refactor for its own sake.
- Self-documenting code is the goal. Add comments only for:
  - Public API documentation (JSDoc/equivalent)
  - Non-obvious algorithms or performance optimizations
  - Critical business logic that can't be expressed in code

## Testing

- Cover new functionality with tests.
- No coverage-metric tests.
- Test meaningful behavior, not implementation details.

## Error handling

- APIs and boundaries: explicit handling with clear messages.
- Internal utilities: let errors bubble.
- Default: early returns for validation, throw for impossible states.

## Shell environment (macOS)

- Homebrew prefix: `~/.homebrew`.
- Aliases that affect scripted behavior: `cat` → bat, `cd` → zoxide, `ls`/`ll`/`la`/`lt` → eza.

## Git

- Default branch: `main`.
- Pull strategy: merge, not rebase.
- Never run `git push`, `git rebase`, `git reset --hard`, or `git clean` without explicit instruction.
- Commit messages: imperative mood, concise, no trailing period.
- Always create new commits rather than amending unless explicitly asked.
