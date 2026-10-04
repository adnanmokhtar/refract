---
name: coverage-gap
description: "Find code no test runs or pins: changed lines and branches no test executes (diff-cover, plus the changed file missing from the report), guarded routes with no denial test, typed errors never asserted, critical modules with no test, consumed APIs with no contract test. --diff or --whole-repo."
---

# coverage-gap

## Premise

The **presence** oracle: did any test execute — or, for risk surfaces, even name — the code that would break? A coverage percentage answers nothing; a line, branch, route or error type that no test reaches does. **coverage-gap finds code never EXECUTED; `mutation-probe` finds code executed but never ASSERTED.** Every finding cites `<file:line>` (or the route, error type or module) + the evidence of absence (the report and its 0 hits, the file missing from the report, or the grep) + the merge-base SHA on a diff run + the test to add.

## Boundaries

- Boundary: diff-time weakening (a lowered floor, an exclusion added) is `.claude/scripts/test-integrity.py` when the repo-baseline is installed; coverage config that hides source is `suite-execution-scan`; weak assertions on covered code are `assertion-strength-scan` / `mutation-probe`; the authorization hole behind a missing denial test is the security pack's, when installed; writing the contract test is `contract-test`.

## Procedure

1. `BASE=$(git merge-base HEAD origin/main)`.
2. Changed lines — this parser handles deletion-only hunks, deleted files, names with spaces and `diff.noprefix`:
   ```bash
   git -c core.quotePath=false diff -U0 --no-color --no-ext-diff --src-prefix=a/ --dst-prefix=b/ "$BASE"...HEAD | awk '
   /^\+\+\+ / { f = ($0 == "+++ /dev/null") ? "" : substr($0, 7); sub(/\t$/, "", f); next }
   /^@@ / { if (f == "") next; match($0, /\+[0-9]+(,[0-9]+)?/); s = substr($0, RSTART + 1, RLENGTH - 1)
            n = split(s, a, ","); st = a[1] + 0; c = (n == 2) ? a[2] + 0 : 1; for (i = 0; i < c; i++) print f ":" (st + i) }'
   ```
3. Run coverage over the **full** suite with every source file included:
   ```bash
   npx jest --coverage --coverageReporters=lcov --collectCoverageFrom='src/**/*.{ts,tsx,js}'   # the full suite; --changedSince reads lines other tests pin as uncovered
   ```
   (Vitest `--coverage.include='src/**'`; pytest `--cov=<pkg> --cov-branch`; Go `-coverpkg=./...`.)
4. `diff-cover <report> --compare-branch="$BASE" --fail-under=100 --show-uncovered`, **then** list changed files absent from the report: diff-cover skips a changed file with no coverage data, so its percentage can read 100% for a file no test imports.
5. Intersect changed lines with the report: `DA` 0 → unexecuted; `BRDA` mixed 0 / >0 → one-sided branch.
6. Whole repo: guarded routes no denial test (401 / 403 / 404) names; typed errors no test names; critical modules no test imports; outbound clients with no contract tooling; fix commits with no test.

## Scans for

§1 uncovered changed lines and branches, and changed files missing from the report · §2 guarded route with no denial test (QG-3) · §3 typed error never asserted · §4 critical module with no test · §5 route no route-level test calls · §6 consumed API with no contract test · §7 fix without a regression test.

## Output

```
coverage-gap --diff — base 8f3c2a1 · report coverage/lcov.info (full suite, include src/**)

1. src/billing/refund.ts            [report-with-fix]  high — NOT-INSTRUMENTED: new file absent from the report
2. src/billing/limits.ts:41-43      [report-with-fix]  high — UNEXECUTED over-limit branch (DA:41,0)

Class coverage: §1 checked · §2 checked · §3 checked · §4 checked · §5 checked · §6 N/A (no client) · §7 checked
```

§1 without a report is `blocked (no coverage report)`, never `checked`.

## Halt conditions

- Halt on a §1 finding without the report path, the producing command and the merge-base SHA.
- Do not produce the report with `--changedSince`, and do not trust a diff-cover percentage without the missing-file check.
- Do not report a grep absence as a finding without its oracle (0 hits, the file absent, or the seeded violation); it is Unconfirmed with the settling command.
- Do not print "no gaps" without the class-coverage block.
