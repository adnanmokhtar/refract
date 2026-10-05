# Code-quality pack — stack assumption

This pack's reviewers, linters, and quality gates assume:

- **Strict-typed language** (TypeScript strict / Kotlin / Rust / Python with type hints)
- **Linter + formatter** (ESLint + Prettier / Spotless / Ruff / etc.) wired to CI **at error, with a zero-warning gate** (§ The WARN trap)
- **A type checker** in CI (tsc / mypy or pyright / javac + Error Prone / Roslyn nullable / PHPStan)
- **Unit-test runner** (Vitest / Jest / JUnit / pytest / etc.) — the correctness oracles are tests that fail first
- **Coverage tooling** (c8 / Jacoco / coverage.py)
- **A reachability tool and a clone tool** where the stack has one (knip / vulture / `deadcode`; jscpd / PMD CPD)

Where inline examples appear, they use abstract pseudocode or `<ext>` placeholders for file extensions; the principles apply to any strict-typed component-based stack. Substitute your project's primitives from `_extracted-idioms.md`.

## The analyzer lane table — what catches each class, per stack

The detector skills carry the rule ids and traps that change a verdict; this table says which lane each stack has, so a project can see what it is missing before `/quality-audit` runs. Versions are from the code-quality research catalog, read 2026-10-05; confirm against the lockfile, never from memory. A rule at **error in CI** owns its class (`precedents/code-quality.md` § 2); a lane that errors is `blocked`, never a quiet lane.

| Stack | Correctness + error handling (`error-handling-scan`, `correctness-smell-scan`) | Types (`type-safety-scan`) | Suppressions — unused / reason checks (`suppression-scan`) | Dead code (`dead-code-scan`) | Clones (`duplication-scan`) | Graph + complexity (`architectural-diagnosis`) |
|---|---|---|---|---|---|---|
| TS / JS | ESLint 10.12 core + typescript-eslint 8.71 — the async rules (`no-floating-promises`, `no-misused-promises`) are **type-aware only** (`projectService`) | tsc `strict`, `noUncheckedIndexedAccess`; `type-coverage` ratchet | `reportUnusedDisableDirectives` (defaults to `warn` in flat config), `eslint-comments/require-description`, `ban-ts-comment` | knip 6.39.0 (dependencies installed); `ts-prune` is superseded | jscpd 5.4.0 with `--fail-on-empty` | dependency-cruiser 18.5.0; lizard 1.24.0 |
| Python | Ruff 0.16.10 (`BLE001`, `B904`, `RUF006`, `DTZ`, `B023`…) | mypy 2.4.0 `--strict` or pyright 1.1.414 strict | Ruff `RUF100`, `PGH003`, `PGH004`; mypy `warn_unused_ignores` | vulture 2.16 + whitelist | pylint 4.1.2 `duplicate-code` (Ruff has no R0801) | import-linter 2.15; Ruff `C901` |
| Go | golangci-lint v2.14 (`errcheck`, `errorlint`, `bodyclose`, `exhaustive`); `go test -race` | `forcetypeassert`; nilaway as a candidate generator | `nolintlint` (`require-explanation`, `require-specific`) | `deadcode`; staticcheck `U1000` | `dupl` | go-arch-lint 1.19.0; `gocyclo`, `gocognit` |
| JVM | Error Prone 2.50 (checks default to WARNING), SpotBugs 4.10, detekt 1.23 **with type resolution** | javac `-Xlint:unchecked,rawtypes -Werror`; NullAway 0.14.2 | none built in — the annotation deleted in a scratch copy is the proof | PMD / detekt unused-private rules; public members stay Investigate | PMD CPD 7.28.0 (`pmd cpd`) | ArchUnit 1.5.1; PMD / detekt metrics |
| C# | Roslyn CA rules, VS Threading 18.7 (`CS4014`, `VSTHRD110`, `CA2012`) | `<Nullable>enable</Nullable>` + nullable warnings as errors | IDE0079 | IDE0051 / IDE0052 / IDE0060 | PMD CPD | ArchUnitNET 0.13.4; CA1502 / CA1506 |
| Ruby | RuboCop 1.91 (`Lint/*`) | Sorbet `# typed:` sigils | `Lint/RedundantCopDisableDirective` | debride 1.15.2 | flay 2.14.4 | packwerk 3.3.1; RuboCop `Metrics/*` |
| PHP | PHPStan 2.2 (+ strict-rules) | PHPStan level max / Psalm 6 | `reportUnmatchedIgnoredErrors` (on by default); Psalm `findUnusedPsalmSuppress` | shipmonk/dead-code-detector 1.4.2 | jscpd or PMD CPD (phpcpd is archived) | deptrac 4.7.2; PHPMD 3.0.0 |
| Rust | clippy (`let_underscore_future`, `await_holding_lock`, `float_cmp`) | clippy `unwrap_used` (restriction, opt-in) | `allow_attributes_without_reason`; `#[expect]` warns when unfulfilled | rustc `dead_code` (crate-private only) | jscpd | `cargo modules`; clippy |

**The WARN trap.** A lane that runs its `recommended` set without `--max-warnings 0` (or the stack's equivalent: `-Werror`, `-warnaserror`, `-D warnings`) reads clean while warn-level correctness rules fire and ship. Error Prone, detekt without type resolution, ESLint's unused-directive report and typescript-eslint's plain `recommended` (no type-aware rule at all) are the measured cases (`precedents/code-quality.md` § 76, § 81, § 82). An installed analyzer is a control only when CI runs it at error level; `suppression-scan` § 3 reports the rest.

## Per-detector lanes

The table above is the overview. Each detector carries the per-stack rule ids and traps it acts on, and is the place to read them:

- `skills/error-handling-scan` § Adapt to the codebase — the analyzer lanes — swallow, async, cause and paired-state rules, plus the runtime hooks that prove a floating failure.
- `skills/correctness-smell-scan` § Adapt to the codebase — the analyzer lanes — discarded results, equality, captured state, numbers, switches, time and breakpoints.
- `skills/type-safety-scan` § Adapt to the codebase — the checker lanes — casts, non-null assertions, strictness and the type-coverage ratchet.
- `skills/suppression-scan` § Adapt to the codebase — the suppression lanes — the executor behind "a suppression needs a rule id and a reason" (`rules/quality-principles.md`): inline forms, the unsuppressed re-run and the config that silences a class.
- `skills/dead-code-scan` § Adapt to the codebase — the reachability lanes.
- `skills/duplication-scan` § Adapt to the codebase — the clone lanes, with the five jscpd traps.
- `skills/architectural-diagnosis` § Adapt to the codebase — the lanes — graph, declared boundaries and complexity, with the relative cut-offs of `THR-ARCH-RELATIVE`.

## Stack-conditional behaviour

The `code-reviewer` agent and the `/pre-commit` command read the project's own anchored stack facts — `ai/stack.md § Scripts` for the commands to run, `.claude/codebase-profile.md` and `_extracted-idioms.md` for the primitives to check against — and apply stack-appropriate checks from those. Which analyzer rules the project enables, its thresholds and its test-framework imports belong in that per-project layer; the lane table above names what exists, not what a project must adopt.

If the anchored layer is absent, the stack-conditional checks are reported as **not run**, not silently skipped: a review that could not determine the project's test command has not established that tests pass.
