---
name: mutation-probe
description: "Measure test strength on changed lines: run the repo's mutation tool with current flags (or seed one mutant by hand), surface surviving mutants, dismiss equivalents by a five-check procedure, and emit the mutant-kill evidence row a fix consumes."
---

# mutation-probe

## Premise

Coverage says a line ran; a mutant says whether any test would notice it breaking. A **survived** mutant is a regression the suite would ship green. This is a harness on changed or named lines only — never repo-wide in PR CI. **coverage-gap finds lines never EXECUTED; mutation-probe finds lines executed but never ASSERTED** — an unexecuted mutant goes back to coverage-gap. Every survivor cites `<file:line>` + the operator (original → mutated) + the tests that ran it + the assertion that would kill it.

## Boundaries

- Boundary: unexecuted lines → `coverage-gap`; reading which tests cannot fail → `assertion-strength-scan`; writing the killing test → `@test-engineer` / `/add-test`; closing an audit finding → `/test-fix`; a mutation-exclusion hint added in the change → `.claude/scripts/test-integrity.py` when the repo-baseline is installed.

## Adapt to the codebase

Detect the tool from config and dependencies; never impose one. Use each tool's diff-scoped mode — StrykerJS `--mutate <file:start-end>` (StrykerJS has no `--since`), Stryker.NET `--since:<base>`, mutmut 3 mutant-name globs (`--paths-to-mutate` is gone), PIT `-DtargetClasses` (`scmMutationCoverage` was removed in 1.18.0), gremlins `--diff`, cargo-mutants `--in-diff`. Survivors read `Survived` / `survived` / `SURVIVED` / gremlins `LIVED` / go-mutesting `FAIL` / cargo-mutants `MissedMutant`.

## Scans for

§1 surviving mutant on a changed, executed line · §2 boundary not pinned · §3 error path executed but unasserted · §4 pseudo-tested method · §5 executed but unchecked.

## Procedure

1. Compute the changed lines from the merge base, skip arid lines (logging, imports, braces). With no merge base (a single-commit repo, a shallow clone) the scope is `blocked (no merge-base)` unless named files (`SCOPE=<paths>`) are mutated whole — never the whole repo.
2. Run the project's mutation tool scoped to those lines with its diff-scoped mode (above), never the whole tree. With no tool, seed one operator per branch by hand, run the covering tests, restore, and prove the restore with `git diff --exit-code`.
3. Parse the report for surviving mutants (the survivor statuses above). For each, capture `<file:line>`, the mutation operator applied, and the original → mutated source.
4. Classify each survivor by **why the test missed it** — no assertion on the mutated value (a real gap; name the assertion to add) · asserts a coincidental side value (tighten the existing assertion) · the line never ran (a coverage gap — hand to `coverage-gap`) · equivalent mutant (dismiss only after the five checks: type context, reachability, downstream consumption, semantic comparison, a distinguishing-input attempt).
5. Rank real gaps: money / auth / limits branches and boundary mutants first.

## Output

```
mutation-probe — base 8f3c2a1 · lane StrykerJS (package.json)
Score (StrykerJS): (Killed + Timeout) / (Killed + Timeout + Survived + NoCoverage) — equivalents excluded

1. pricing.service:42  [report-with-fix]  `>` → `>=` Survived — no test sends total == threshold
   add: expect(calc(threshold, threshold)).toBe(<no-discount>)
HAND TO coverage-gap: legacy-fee:120 (NoCoverage)
DISMISSED (equivalent): clamp:9 `>` → `>=` — returns the same value when equal
```

Closure: report-with-fix per survivor, with a `mutant-kill` evidence row (before Survived, after Killed, siblings on the line killed, restore checked).

## Halt conditions

- Halt on a survived-mutant claim without `<file:line>` + the cited mutation + which test failed to assert.
- Halt on any of these wrong flags: StrykerJS `--since`, mutmut `--paths-to-mutate`, PIT `scmMutationCoverage`, gremlins `--diff-ref`, a go-mutesting `LIVED` line, a cargo-mutants `caught` field.
- Halt on classifying an unexecuted line as a strength gap — that's a coverage gap; hand it off.
- Halt on a mutation score reported without its formula and whether equivalent mutants were excluded.
