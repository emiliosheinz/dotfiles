# Agent Rules

Global conventions for AI coding assistants working in any repository.

## Core Principles

**No excessive comments.** Code should be self-documenting. Only add comments for:
- Public API documentation (JSDoc/equivalent)
- Non-obvious algorithms or performance optimizations
- Critical business logic that can't be expressed in code

**Never assume.** All decisions require explicit facts. If information is missing or ambiguous, ask before proceeding.

**Fail fast.** Prefer early returns. Throw errors for states that should never happen.

## Code Quality

### Testing
Write tests for all new functionality. Tests must be:
- Focused on meaningful behavior
- Not written for coverage metrics
- Testing real scenarios, not implementation details

### Error Handling
Context-dependent approach:
- **APIs/boundaries:** Explicit error handling with clear messages
- **Internal utilities:** Minimal ceremony, let errors bubble
- **Default pattern:** Early returns for validation, throw for impossible states

### Refactoring
Fix obvious issues when you encounter them:
- Poor naming
- Code duplication in local scope
- Clear violations of project patterns

Do not gold-plate. Refactoring for its own sake is a separate task.

## Style & Formatting

1. Use existing formatters/linters (Prettier, ESLint, Biome, etc.)
2. If none exist, infer style from codebase
3. Match existing patterns exactly

## Dependencies

**Always ask before adding dependencies.** No exceptions.

## Architecture

Apply industry-standard patterns without discussion:
- SOLID principles
- Domain-Driven Design (DDD) principles
- Established design patterns for the language/framework
- DRY where it improves maintainability (not at the cost of clarity)

For non-standard architectural decisions, proceed with best practice defaults unless there's clear evidence the codebase diverges intentionally.

## Documentation

Self-documenting code is the goal. Do not create:
- README files for internal modules
- Usage examples for private functions
- Architecture decision records unless explicitly requested

Document only public APIs and complex algorithms that benefit from explanation.

## Decision-Making

When in doubt:
1. Check existing codebase patterns
2. Follow language/framework conventions
3. Choose simplicity over cleverness
4. Ask if the choice has meaningful impact
