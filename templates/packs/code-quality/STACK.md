# Code-quality pack — stack assumption

This pack's reviewers, linters, and quality gates assume:

- **Strict-typed language** (TypeScript strict / Kotlin / Rust / Python with type hints)
- **Linter + formatter** (ESLint + Prettier / Spotless / Ruff / etc.) wired to CI
- **Unit-test runner** (Vitest / Jest / JUnit / pytest / etc.)
- **Coverage tooling** (c8 / Jacoco / coverage.py)

Where inline examples appear, they use abstract pseudocode or `<ext>` placeholders for file extensions; the principles apply to any strict-typed component-based stack. Substitute your project's primitives from `_extracted-idioms.md`.

## Stack-conditional behaviour

The `code-reviewer` agent and `pre-commit` skill read the project's `_v2-anchors.md` and apply stack-appropriate checks. Stack-specific lint rule names, test framework imports, and coverage thresholds belong in the per-project anchor file — not in this pack.
