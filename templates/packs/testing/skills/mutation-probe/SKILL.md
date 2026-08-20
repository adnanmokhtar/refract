---
name: mutation-probe
description: Measure test STRENGTH by mutation-testing changed code — surface survived mutants (the source was corrupted, the suite stayed green) and the assertion-free tests that let them live. Sits beside coverage-gap; coverage-gap proves a branch RAN, mutation-probe proves a test would CATCH it breaking.
---

# mutation-probe

A green test that asserts nothing is worse than no test — it buys false confidence. Coverage says the line ran; mutation testing says the line's behaviour is actually pinned. This is the strength probe.

## Premise

The failure mode: a suite reports "100% coverage, 0% mutation score" — every line executes under some test, yet you can corrupt the logic (`>` → `>=`, `&&` → `||`, `return x` → `return null`) and every test stays green. The tests exercise the code without asserting on its result. Coverage measured presence; nothing measured strength.

Cite-or-halt: a survived mutant is cited by `<file:line>` + the exact mutation applied + why the test missed it (which test ran, what it failed to assert). A claim without the mutant is a vibe. "Weak tests here" is not a finding; "`pricing.ts:42` `>` → `>=` survived — `pricing.spec.ts` calls `calc()` but never asserts the boundary value" is.

The ownership boundary with `coverage-gap` (state it, don't cross it): **coverage-gap finds branches never EXECUTED (test presence); mutation-probe finds branches executed but never ASSERTED (test strength). A file can be 100% covered and 0% mutation-killed.** A mutant that survives *because the mutated line never ran under any test* is not a mutation-probe finding — it is a coverage gap. Hand it to coverage-gap; do not report it here.

## When to run

- On the **changed scope of a PR** — mutation testing re-runs the suite once per mutant, so it is expensive. Scope it to the diff, never the whole tree.
- **Before a refactor you're about to trust the suite for** — if you're about to change behaviour-preserving internals and lean on tests to catch regressions, first confirm the tests would actually catch them.
- After a bug fix, to confirm the regression test *kills* the mutation that reintroduces the bug (not just that it runs the line).

**Do not** run it on the whole repo every CI run — the runtime is quadratic-feeling (suite × mutants) and it will blow the CI budget. Scope to the diff, or schedule a nightly/weekly run on a critical module.

## Adapt to the codebase

Drive the project's own mutation tool. Detect it (config file / dev-dependency), don't impose one.

| Stack | Tool | Scope to changed files | Survived-mutant report |
|---|---|---|---|
| JS / TS | Stryker (`stryker.conf.*`) | `--mutate "src/changed/**"` or `--since=<base>` (incremental) | `reports/mutation/mutation.html` + `--reporters json` → `mutation.json` (`status: "Survived"`) |
| Python | mutmut (`setup.cfg` `[mutmut]`) / cosmic-ray | `mutmut run --paths-to-mutate <files>` | `mutmut results` → survivors; `mutmut show <id>` for the diff |
| Java | PIT / pitest (`pom.xml` plugin) | `-DtargetClasses=<changed>` + `scmMutationCoverage` (changed-since-SCM) | `target/pit-reports/**/index.html`; `SURVIVED` in the mutations XML |
| Go | go-mutesting / gremlins (`gremlins.yaml`) | run in the changed package dir; gremlins `--diff-ref=<base>` | stdout `LIVED` lines; gremlins JSON output |
| Ruby | mutant (`.mutant.yml`) | `mutant run -- '<Changed::Constant>'` (subject-scoped) | stdout `alive` subjects + the mutation diff |
| C# / .NET | Stryker.NET (`stryker-config.json`) | `--mutate` glob / `--since` | `StrykerOutput/**/mutation-report.html`; `Survived` in JSON |
| Rust | cargo-mutants | `--in-diff <base>.diff` or `--file <changed>` | `mutants.out/outcomes.json`; `MISSED` / `caught: false` |

## Procedure

1. Compute the diff scope:
   ```bash
   BASE=$(git merge-base HEAD origin/main)
   git diff --name-only "$BASE"..HEAD -- '*.<src-ext>'
   ```
2. Run the project's mutation tool scoped to those files (see table). Prefer the tool's own incremental/`--since`/`--in-diff` mode over mutating the whole tree.
3. Parse the report for surviving mutants — status `Survived` / `alive` / `LIVED` / `MISSED`. For each, capture `<file:line>`, the mutation operator applied, and the original → mutated source.
4. Classify each survivor by **why the test missed it**:
   - **No assertion on the mutated value** — a test ran the line but asserted nothing about its output → real gap, name the assertion to add.
   - **Test asserts the wrong thing** — it asserts a coincidental side value, not the mutated behaviour → tighten the existing assertion.
   - **Branch never ran** under any test → this is a coverage gap, **hand to coverage-gap**, do not report as a mutation finding.
   - **Equivalent mutant** — the mutation produces identical observable behaviour → not a gap, dismiss with the reason.
5. Rank real gaps by blast radius: hot module > cold; business-rule / money / auth branch > cosmetic; boundary/off-by-one mutants first (they're the ones that ship real bugs).

## Output

A literal report — ranked survivors, each with the mutation and the exact assertion to add:

```
Mutation probe — feature/checkout-rules  (base=origin/main)

Scope: 6 files changed  |  Mutants: 48  |  Killed: 39  |  Survived: 7  |  Equivalent: 2
Mutation score: 39/46 = 85%  (equivalent mutants excluded from denominator)

SURVIVED (assertion gaps):
  pricing.service.<ext>:42
    mutation: `total > threshold`  →  `total >= threshold`  (boundary off-by-one)
    missed:   pricing.spec calls calc(threshold) but never asserts the == case
    add:      expect(calc(threshold)).toBe(<no-discount>)   ← pins the boundary

  discount.service.<ext>:88
    mutation: `applyA() && applyB()`  →  `applyA() || applyB()`
    missed:   test asserts the happy path where both are true; never the A-only case
    add:      assert A-true / B-false yields no discount

  refund.service.<ext>:15
    mutation: `return computeRefund(order)`  →  `return null`  (return-value swap)
    missed:   test asserts the call happened, not the returned amount (tautology mock)
    add:      assert the returned refund amount equals the expected total

HAND TO coverage-gap (mutant survived because the line never ran):
  legacy-fee.<ext>:120  — no test executes this branch; presence gap, not strength gap.

DISMISSED (equivalent mutants — no observable behaviour change):
  logger.<ext>:9   `i++` → `++i` in a discarded expression — behaviourally identical.
  cache.<ext>:33   reordering two commutative pure guards — same result set.

Closure: report-with-fix on the 3 SURVIVED gaps; halt-handoff legacy-fee:120 to coverage-gap.
```

Closure verbs: **report-with-fix** (name the assertion to add for each genuine survivor) and **halt-handoff** (route genuinely-unexecuted lines to coverage-gap — see boundary).

## False positives / gotchas

- **Equivalent mutants** — a mutation that cannot change observable behaviour (a swap inside a discarded expression, reordering commutative pure guards, a mutated log-only value). No test can kill it and none should try. Dismiss it *with the reason*, and exclude it from the score denominator — counting it drags mutation score down for a non-defect.
- **Timeouts counted as killed** — most tools score a mutant that makes the suite hang (infinite loop) as "killed by timeout". That's usually legitimate (the mutation broke termination), but a flaky-slow suite can time out a mutant the tests never actually caught — spot-check timeout-killed mutants on a slow module before trusting the score.
- **Scope discipline** — never mutation-test generated / vendored / transpiled code (ORM client output, protobuf/OpenAPI types, `node_modules`, `vendor/`). Every mutant there is noise; exclude via the tool's ignore glob.
- **Cost / time tradeoff** — runtime ≈ suite duration × mutant count. A 30s suite with 500 mutants is ~4 hours naive. Always use the tool's incremental/diff mode, cap concurrency, and scope to changed files; if it's still too slow, sample (mutate the highest-risk files only) rather than skip.

## Halt conditions

- Halt on any survived-mutant claim without `<file:line>` + the cited mutation (operator, original → mutated) + which test ran and what it failed to assert.
- Halt on classifying a survivor as a strength gap when the mutated line **never executed** — that is a coverage gap; hand it to `coverage-gap` and don't double-own it.
- Halt on proposing a test whose only job is to kill an **equivalent mutant** — you'd be asserting on behaviour that doesn't exist; dismiss the mutant instead.
- Halt on a mutation score reported without stating whether equivalent mutants were excluded from the denominator.

## Related

- `coverage-gap.md` — boundary sibling: coverage-gap proves a branch was EXECUTED (presence); mutation-probe proves a test would CATCH it breaking (strength). A survived mutant on an unexecuted line belongs to coverage-gap, not here.
- `property-invariants.md` — the third axis of test quality: coverage-gap = presence, mutation-probe = strength (do the assertions catch a mutation), property-invariants = input-space breadth (does the behaviour hold for-all inputs, not just the examples). A mutant killed only because your one example happened to catch it can still survive across the inputs a generator would explore.
- `@test-reviewer` — the assertion-quality auditor; feed it the surviving-mutant → assertion-to-add fixes.
- `test-strategy.md` — where mutation testing sits in the pyramid: a strength gate on critical / changed modules, not a per-file default.
