---
description: Run the project's test suite (or a scoped subset) and surface results. Detects test runner from `_extracted-codebase.md`. Supports scoped runs (changed files / specific module / specific feature) and full-suite runs. Transcribes the runner's own summary — counts, time, and (where a prior run log exists) coverage delta and flake count; rows it cannot compute print as not-computed rather than being estimated. Wires into per-finding VERIFY steps when invoked from /align-phase / /migration-fast / /find-and-fix.
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
- Scoped: `/run-tests <modules-root>/orders/` to run tests under a path.
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

**Every number in this block is transcribed from the runner's own output or it is not printed.** The command runs a process; the process prints a summary; this phase normalises that summary. It never composes one. Where a row cannot be filled from what the runner actually emitted, it prints the row's `not computed` form and says what would produce it — the same discipline `/add-test` Phase 6 and `/perf-audit` Phase 6 apply to their own claims.

```
/run-tests <modules-root>/orders/

Test runner:           <project's runner + helpers from its manifest>
Command:               <the exact argv executed>
Scope:                 <modules-root>/orders/ (<N> test files)
Exit code:             <the runner's actual exit status>

<the runner's own summary block, transcribed — not re-formatted from memory>

Result: <PASS | FAIL | PARTIAL | NOT-RUN>

Summary (each row from the runner's output, or its `not computed` form):
  Tests / Passed / Failed / Skipped:  <as the runner reported them>
  Time:                <wall clock, runner start to exit>
  Coverage:            <n>% — delta vs <prior source> | no prior coverage record: this run is the first
  Flakes:              <n> across <N> prior runs in ai/test-runs/ | not computed (single run — flakes need ≥2 runs of the same scope)

Failures (verbatim from the runner — file:line + the assertion message it printed):
  <path>:<line>
    "<test name>" — <the runner's own assertion text>

Next:
  /fix-bug "<failing behaviour>" --evidence=<test-file:line>
  OR /run-tests --update-snapshots if this was an intentional change
```

**Result vocabulary — this command reports a run, it does not certify a suite.**
- `PASS` — runner exited 0 over the requested scope. This means *the suite that ran was green*, never *the code is correct*: a green run over a scope with no assertions for the behaviour in question proves nothing. Test **strength** is `/add-test`'s and `@test-reviewer`'s question, not this command's.
- `FAIL` — non-zero exit. Failures listed verbatim.
- `PARTIAL` — the scope was reduced (shard, bail, a runner that could not collect some files); name what did not run.
- `NOT-RUN` — the runner could not be executed (binary missing, config unresolved, timeout). **Never reported as PASS.** Name the blocker and the command that was attempted.

## Phase 5 — Update

- **Append the run to `ai/test-runs/<YYYY-MM-DD-HHMMSS>.log`: the argv, the exit code, the scope, the wall time, and the per-test pass/fail set.** This file is not decoration — it is the *only* state that makes Phase 7's cross-run claims computable. The only other writer is `/flaky-test-hunt` Phase 5, which appends its N sweep runs here in this same format; a project that runs neither gets `Flakes: not computed` forever (the honest output), and no later phase may claim a cross-run number.
- Coverage: the runner's reporter writes wherever the project configures it; record that path and value in the log line so the next run has a prior value to diff against.
- For caller commands (`/align-phase` etc.): return the Result verdict + exit code, not a prose summary.

## Phase 6 — Validate

- **The runner's exit code is the source of truth for pass/fail** — never the agent's reading of scrolled output. A run whose exit code was not observed is `NOT-RUN`.
- A coverage *delta* requires a prior recorded coverage value. Absent one, print the absolute number and `no prior coverage record` — never a delta against a remembered figure.
- Time is wall-clock, runner start to exit.
- **Nothing in this command certifies test quality.** If the caller needs "are these tests any good", route to `/add-test --review` or `@test-reviewer`. A green exit code is not that answer and must not be surfaced as one.

## Phase 7 — Improve

Every trigger here reads `ai/test-runs/` (Phase 5). With fewer than two comparable runs of the same scope, each reports `insufficient history` and fires nothing — it never estimates.

- Same test in the failed set on ≥3 recorded runs where the surrounding suite was green → flag for `/flaky-test-hunt`, citing the run ids.
- Coverage below the project's configured threshold → report the drop against the recorded prior value.
- Wall time for the same scope trending up across recorded runs → flag for perf review, citing the run ids and times. There is no fixed percentage here: the trigger is a trend across logged runs, not a number this command invented.

## Hard rules

- **Detect, don't guess.** If runner can't be detected, halt with the manifest paths checked.
- **Honor project-config.** Use the project's exact command (don't substitute `vitest run` for the project's `pnpm test`).
- **No silent skip on tool missing.** If runner binary not on PATH, halt with install instructions.
- **Don't mutate code.** This command runs tests; it doesn't fix them.
- **Transcribe, never compose.** Every count, percentage, duration, and failure message in the report comes from the runner's stdout/stderr or the recorded run log. If the runner did not print it and no log holds it, the row prints its `not computed` form. A plausible-looking summary for a run that did not happen is the worst output this command can produce — it is indistinguishable from a real one.

## Failure modes

- **Runner not detected** → halt; route to `/setup-project --refine` to populate `_extracted-codebase.md § Tests`.
- **Runner binary not installed** → halt with install command.
- **Tests time out** → surface; suggest scope reduction or `--shard=`.
- **Coverage tool unavailable** → run tests without coverage, surface as warning.

## Related

- `/add-test` — author a new test.
- `/tdd` — drive a feature test-first (red→green→refactor).
- `/flaky-test-hunt` — debug intermittent failures.
- `coverage-gap` skill — find untested code paths.
- `contract-test` skill — author a parity / contract test.

### Called by
- `/align-phase`'s VERIFY step.
- `/migration-fast`'s VERIFY step.
- `/find-and-fix`'s step 5 verification.
- `/fix-bug`'s reproduction step.
