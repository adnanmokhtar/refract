---
description: Run the project's test suite (or a scoped subset) and surface results. Detects test runner from `_extracted-codebase.md`. Supports scoped runs (changed files / specific module / specific feature) and full-suite runs. Reports pass/fail counts, coverage delta, time, and flakes. Wires into per-finding VERIFY steps when invoked from /align-phase / /migration-fast / /find-and-fix.
kind: command
pack: testing
---

# /run-tests [<scope>]

## The Premise (read this first)

**Test runner detection + scoped execution + result reporting.** This is the universal test-running command — every project has tests; the runner differs (vitest / jest / pytest / playwright / go test / cargo test / mvn test / phpunit / rspec / etc.). This command:

1. Detects the runner from `_extracted-codebase.md` (or falls back to package manifest probing).
2. Runs the right command for the requested scope.
3. Surfaces a normalized output: pass / fail / skipped / coverage delta / time / flake count.

Other commands (`/align-phase`, `/migration-fast`, `/find-and-fix`, `/fix-bug`'s VERIFY step) can call `/run-tests <scope>` to execute the project's test suite without each command needing to know which runner.

## When to use

- Manual: `/run-tests` to run the full suite.
- Scoped: `/run-tests src/modules/orders/` to run tests under a path.
- Specific: `/run-tests --feature=F042` to run tests for one ledger row.
- Changed-only: `/run-tests --since=HEAD~1` to run tests touching changed files.
- After a fix: confirm nothing regressed.
- Pre-commit: catch obvious regressions before pushing.

## When NOT to use

- For coverage-gap analysis → use `coverage-gap` skill.
- For flaky-test investigation → use `/flaky-test-hunt`.
- For test authoring → use `/add-test`.

## Args

- `<scope>` (optional) — path glob, module path, or `--all` (default: changed-files since branch base).

## Optional flags

- `--all` — run the entire suite regardless of changes.
- `--since=<commit>` — run tests touching files changed since the commit.
- `--feature=<id>` — run tests associated with a ledger row (reads `parity_test:` field for migration; reads `scope:` field for align).
- `--coverage` — produce a coverage report alongside.
- `--watch` — re-run on file changes (interactive; not for CI).
- `--bail` — stop at first failure.
- `--update-snapshots` — accept snapshot diffs (use carefully).
- `--shard=<i>/<n>` — for parallel CI: run shard `i` of `n`.

## Pre-requisites

- Test runner detected in `_extracted-codebase.md § Tests` OR derivable from `package.json` / `Pipfile` / `go.mod` / `Cargo.toml` / etc.
- Working tree state acceptable for the requested scope (`--all` and `--since` work regardless of dirty tree; `--feature=` requires the ledger to be committed).

## Phase 1 — Understand

Detect runner + commands:
- **JS / TS**: vitest, jest, mocha, playwright. Read `package.json` scripts (`test`, `test:unit`, `test:e2e`).
- **Python**: pytest, unittest, nose. Read `pyproject.toml` / `setup.cfg` / `tox.ini`.
- **Go**: `go test ./...`.
- **Rust**: `cargo test`.
- **Ruby**: rspec, minitest. Read `Gemfile`.
- **Java**: `mvn test`, `gradle test`.
- **PHP**: phpunit, pest. Read `composer.json`.

If multiple runners (e.g., vitest for unit + playwright for e2e), run them in sequence (or parallel if scope is non-overlapping).

## Phase 2 — Organize

```
1. DETECT       — read _extracted-codebase.md or probe manifest
2. RESOLVE      — translate <scope> to runner-specific filter args
3. RUN          — execute the runner with the right args
4. PARSE        — normalize the runner's output to pass/fail/skip/coverage/time
5. SURFACE      — report to user (or to caller command)
```

## Phase 3 — Retrieve

- `_extracted-codebase.md § Tests` — runner + commands + coverage tool + thresholds.
- `package.json` / equivalent manifest — fallback for runner detection.
- Project's CI config (`.github/workflows/`, `.gitlab-ci.yml`) — to mirror CI's exact invocation.

## Phase 4 — Generate (output template)

```
/run-tests src/modules/orders/

Test runner:           <project's runner + helpers from package.json / pyproject.toml / etc.>
Scope:                 src/modules/orders/ (28 test files)

Running...
  ✓ src/modules/orders/__tests__/OrderListPage.spec.<ext> (12 tests, 245ms)
  ✓ src/modules/orders/__tests__/OrderForm.spec.<ext> (8 tests, 142ms)
  ✗ src/modules/orders/__tests__/OrderRefund.spec.<ext> (5 of 6, 89ms)
       FAIL: "applies refund tax correctly" — expected 12.50, got 12.55
       file: src/modules/orders/__tests__/OrderRefund.spec.ts:42
  ⊝ src/modules/orders/__tests__/OrderArchive.spec.ts (3 skipped)
  ...

Result: PARTIAL (147/148 passing)

Summary:
  Tests:               148 total
  Passed:              147
  Failed:              1
  Skipped:             3
  Time:                4.2s
  Coverage delta:      no change (87.4%)
  Flakes:              0

Failures:
  src/modules/orders/__tests__/OrderRefund.spec.ts:42
    "applies refund tax correctly" — expected 12.50, got 12.55

Next:
  /fix-bug "OrderRefund applies wrong tax" --evidence=<test-file:line>
  OR run /run-tests --update-snapshots if this was an intentional change
```

## Phase 5 — Update

- Per-run log to `ai/test-runs/<YYYY-MM-DD-HHMMSS>.log` (optional; configurable).
- For caller commands (`/align-phase` etc.): return structured pass/fail to the orchestrator.

## Phase 6 — Validate

- The runner exit code is the source of truth for pass/fail.
- Coverage delta calculated against the prior baseline (from `_session-digest.md` or `coverage/baseline.json`).
- Time measured wall-clock from runner start to exit.

## Phase 7 — Improve

- If the same test fails 3+ times across runs → flag for `/flaky-test-hunt`.
- If coverage drops below the project's threshold → halt; report the drop.
- If time grows > 50% from baseline → flag for perf review.

## Hard rules

- **Detect, don't guess.** If runner can't be detected, halt with the manifest paths checked.
- **Honor project-config.** Use the project's exact command (don't substitute `vitest run` for the project's `pnpm test`).
- **No silent skip on tool missing.** If runner binary not on PATH, halt with install instructions.
- **Don't mutate code.** This command runs tests; it doesn't fix them.

## Failure modes

- **Runner not detected** → halt; route to `/setup-project --refine` to populate `_extracted-codebase.md § Tests`.
- **Runner binary not installed** → halt with install command.
- **Tests time out** → surface; suggest scope reduction or `--shard=`.
- **Coverage tool unavailable** → run tests without coverage, surface as warning.

## Related

- `/add-test` — author a new test.
- `/flaky-test-hunt` — debug intermittent failures.
- `coverage-gap` skill — find untested code paths.
- `contract-test` skill — author a parity / contract test.

### Called by
- `/align-phase`'s VERIFY step.
- `/migration-fast`'s VERIFY step.
- `/find-and-fix`'s step 5 verification.
- `/fix-bug`'s reproduction step.
