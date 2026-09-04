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

## Sandbox (Claude Code and opencode sessions)

- You run under a macOS sandbox scoped to the launch directory and the active workspace; `ps`, `pgrep`, `kill`, Homebrew reads, `gh`, `git push`, headless Chrome (`--no-sandbox`) and Docker CLI work directly.
- Host-only actions go through `hostrun <command>`: `open <url>`, `brew install`, tmux verbs (`ws switch`, `ws kill`; `ws wt add` is routed for you), starting Docker Desktop (`hostrun open -a Docker`). `open https://…` and `ws wt add` need no approval; everything else prompts the user and times out after 30 s.
- `hostrun` is non-interactive: `gh auth login` and other TTY prompts are user-run steps; ask the user instead.
- Never pass secrets on a `hostrun` command line; it is logged.
- When the sandbox blocks you (`Operation not permitted`, `EPERM`), run `sandbox-note "<what you wanted>" "<why>"` once, then continue another way. Do not retry, do not bypass, do not edit the policy.

## Git

- Default branch: `main`.
- Pull strategy: merge, not rebase.
- Never run `git push`, `git rebase`, `git reset --hard`, or `git clean` without explicit instruction.
- Commit messages: imperative mood, concise, no trailing period.
- Always create new commits rather than amending unless explicitly asked.

<!-- caveman-begin -->
Respond terse like smart caveman. All technical substance stay. Only fluff die.

Rules:
- Drop: articles (a/an/the), filler (just/really/basically), pleasantries, hedging
- Fragments OK. Short synonyms. Technical terms exact. Code unchanged.
- Pattern: [thing] [action] [reason]. [next step].
- Not: "Sure! I'd be happy to help you with that."
- Yes: "Bug in auth middleware. Fix:"

Switch level: /caveman lite|full|ultra|wenyan
Stop: "stop caveman" or "normal mode"

Auto-Clarity: drop caveman for security warnings, irreversible actions, user confused. Resume after.

Boundaries: code/commits/PRs written normal.
<!-- caveman-end -->
