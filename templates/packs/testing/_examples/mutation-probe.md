---
name: mutation-probe
description: Measure test STRENGTH by mutation-testing changed code — surface survived mutants (the source was corrupted, the suite stayed green) and the assertion-free tests that let them live. Sits beside coverage-gap; coverage-gap proves a branch RAN, mutation-probe proves a test would CATCH it breaking.
---

# mutation-probe

A green test that asserts nothing is worse than no test — it buys false confidence. Coverage says the line ran; mutation testing says the line's behaviour is actually pinned. This is the strength probe.

## Premise

The failure mode: "100% coverage, 0% mutation score" — every line executes, yet you can corrupt the logic (`>` → `>=`, `&&` → `||`, `return x` → `return null`) and every test stays green. Coverage measured presence; nothing measured strength.

Cite-or-halt: a survived mutant is cited by `<file:line>` + the exact mutation applied + why the test missed it. "Weak tests here" is not a finding; "`pricing.ts:42` `>` → `>=` survived — the spec calls `calc()` but never asserts the boundary" is.

Boundary with `coverage-gap` (state it, don't cross it): **coverage-gap finds branches never EXECUTED (presence); mutation-probe finds branches executed but never ASSERTED (strength).** A mutant that survives because its line never ran is a coverage gap — hand it off, don't report it here.

## When to run

- On the **changed scope of a PR** (mutation testing is expensive — scope to the diff, never the whole tree).
- **Before a refactor** you're about to trust the suite for.
- After a bug fix — confirm the regression test *kills* the reintroducing mutant, not just runs the line.

## Adapt to the codebase

Drive the project's own tool, detected from config/deps: Stryker (JS/TS), mutmut / cosmic-ray (Python), PIT (Java), gremlins (Go), mutant (Ruby), Stryker.NET, cargo-mutants (Rust). Prefer each tool's incremental / `--since` / `--in-diff` mode. Parse the report for `Survived` / `alive` / `LIVED` / `MISSED`.

## Output (abridged)

```
Mutation probe — feature/checkout-rules  (base=origin/main)
Scope: 6 files  |  Mutants: 48  |  Killed: 39  |  Survived: 7  |  Equivalent: 2  |  Score: 85%

SURVIVED (assertion gaps):
  pricing.service:42  `>` → `>=`  — spec calls calc() but never asserts the == boundary
    add: expect(calc(threshold)).toBe(<no-discount>)

HAND TO coverage-gap (line never ran):
  legacy-fee:120 — presence gap, not strength gap.

DISMISSED (equivalent mutants — excluded from denominator):
  logger:9  `i++` → `++i` in a discarded expression — behaviourally identical.
```

Closure verbs: **report-with-fix** (name the assertion for each genuine survivor) and **halt-handoff** (route unexecuted lines to coverage-gap).

## Halt conditions

- Halt on a survived-mutant claim without `<file:line>` + the cited mutation + which test failed to assert.
- Halt on classifying an unexecuted line as a strength gap — that's a coverage gap; hand it off.
- Halt on a mutation score reported without stating whether equivalent mutants were excluded.

## Related

- `coverage-gap.md` — boundary sibling: presence (did the branch run) vs strength (would a test catch it breaking).
- `@test-reviewer` — the assertion-quality auditor mutation-probe feeds surviving-mutant fixes into.
- `test-strategy.md` — where mutation testing sits in the pyramid (a strength gate on critical modules, not every file).
