# Code-quality pack — stack assumption

This pack's reviewers, linters, and quality gates assume:

- **Strict-typed language** (TypeScript strict / Kotlin / Rust / Python with type hints)
- **Linter + formatter** (ESLint + Prettier / Spotless / Ruff / etc.) wired to CI
- **Unit-test runner** (Vitest / Jest / JUnit / pytest / etc.)
- **Coverage tooling** (c8 / Jacoco / coverage.py)

Where inline examples appear, they use abstract pseudocode or `<ext>` placeholders for file extensions; the principles apply to any strict-typed component-based stack. Substitute your project's primitives from `_extracted-idioms.md`.

## Stack-conditional behaviour

The `code-reviewer` agent and the `/pre-commit` command read the project's own anchored stack facts — `ai/stack.md § Scripts` for the commands to run, `.claude/codebase-profile.md` and `_extracted-idioms.md` for the primitives to check against — and apply stack-appropriate checks from those. Stack-specific lint rule names, test-framework imports and coverage thresholds belong in that per-project layer, not in this pack.

If the anchored layer is absent, the stack-conditional checks are reported as **not run**, not silently skipped: a review that could not determine the project's test command has not established that tests pass.
