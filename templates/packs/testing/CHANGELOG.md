# testing pack — changelog

Release history for `templates/packs/testing/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 2.1.2 — 2026-10-10

**rg-glob-order: `suite-execution-scan` greps 1b and 6a put their include globs before `"${K[@]}" "${C[@]}"`.** ripgrep's last matching glob wins, so an `.eslintrc*`, `*.test.*` or `test_*.py` file directly inside `node_modules/` was re-included. Measured 2026-10-10 on rg 15.2.0: `brittle-suite` and `quality-mix` print the same lines before and after (67 and 9). On copies with planted `node_modules/` files the totals drop from 71 to 67 and from 12 to 9.

## 2.1.1 — 2026-10-10

**Two citations to `mutation-probe` named sections that are not headings.** `/test-audit`'s class
ledger and `/test-fix`'s proof table cited `mutation-probe` "§ 1–§ 5"; those are the numbered rows of
its `## Scans for` table (a harness skill, like `contract-test` and `property-invariants`, carries
no `### N.` detector headings). Both now cite `mutation-probe` § Scans for, rows 1–5.

## 2.1.0 — 2026-10-05

**"Behaviour preserved" was a claim; it is now a comparison** (architecture proposal §7, Phase 5).
`/refactor`, `/optimize`, `/upgrade-dep` and `/migrate` asserted it, and only the tests that happened
to exist checked it.

- **New skill `characterize`.** Records what the code DOES before anyone edits it: a golden master of
  pure functions, CLI commands and HTTP endpoints on inputs sampled from their real call sites and
  branch boundaries, scoped to the run's `design.md` files plus their importers in
  `.claude/_graph.json`. The format is `packs/migration/skills/parity-test-generate`'s (inputs /
  `__golden__` / the five-key tolerance taxonomy, stored as `tolerance.json` because the gate scripts
  are standard-library Python), so a port and a refactor are guarded by one comparator. The harness
  is registered with `.claude/scripts/baseline-capture.sh` into `.claude/baselines/main/manifest.json`
  and captured three times — outputs that differ between identical runs are quarantined with an
  owner and an expiry, never silently re-baselined. Gate G14 (`behavior-diff.py`) re-runs it at HEAD;
  a difference no acceptance criterion declares (`changes_baseline`) FAILs.
- `characterize` is in the minimal install: the five callers print `not characterized` without it.
- Measured on `benchmarks/fixtures/regression-baseline`: a "refactor" that moved tax rounding to
  `round()` changed 2 of 8 sampled cases (the two half-cent boundaries) — G14 FAIL; declaring them on
  an AC turned it into EXPLAINED; a docstring-only refactor stayed SAME.

## 2.0.1 — 2026-10-05

**Six measured detector defects, found by running each pre-flight on `benchmarks/fixtures/brittle-suite`
and on a real NestJS + React monorepo (read-only).** Each fix was re-measured on every fixture and on
that repo; counts are before → after.

- **`coverage-gap` grep 4 read every `*.service.ts` as untested.** `sed -E 's/\.[a-z]+$//'` stripped
  the last dotted segment of every import specifier, so `./refund.service` became `refund` and never
  matched `refund.service.ts`. Only a file extension is stripped now, and the check also reads
  dotted Python / JVM imports and test-file stems (`PayoutCalculatorTest`, `settle_test.go`,
  `test_chargebacks.py`). brittle-suite 25 → 14 files (CG-04 still listed); the real repo 334 → 252.
- **`coverage-gap` § 2 counted a route as denial-tested when its deny file named it anywhere.** A
  route named only in a same-tenant 200 case read as covered because another case in the file
  asserted a 404. Grep 2 now matches the route only in the file's preamble (route tables) and in
  cases that assert a refusal; a skipped case never counts, and a multi-line `.expect(\n 403,\n)` and
  `HttpStatus.FORBIDDEN` count as refusals. brittle-suite 2 → 3 gaps (**BS-CG-01**, `GET
  /orders/:id`, now listed); the real repo 123 → 416 — sampled extras are named only in 200 cases.
- **`mutation-probe` printed `awk: can't open file …/ranges.all` with no merge base** (a single-commit
  repo, a shallow clone, an unfetched `origin/main`) — and on any empty diff, as on the real repo with
  HEAD at its merge base: the awk that writes the ranges file never ran. The scope files are created up front; with no base the block prints
  `scope: blocked (no merge-base …)` and an empty scope, and a new `SCOPE=<paths>` mutates named files
  whole. It never widens itself to the whole repo. The diff scope on the real repo is unchanged
  (30 commits: 3,565 lines, 363 hunks, 2,316 mutable).
- **`assertion-strength-scan` grep 3b dropped a whole file when any case in it used `.toThrow` or
  `.rejects`.** A guard is now read in the site's own case only (`fail(`, a `throw new` after the
  call, `.toThrow`, `.rejects`, `expect.assertions`); a file-level `expect.hasAssertions` tags the
  row. brittle-suite reaches **BS-AS-10** (`refund-window.spec.ts:15`); the real repo stays at 2
  sites, its other 17 catch-with-`expect` sites guarded in their own case.
- **`suite-execution-scan` could not see a missing Failsafe plugin** — an absence has no line. New
  grep 3d is a presence check: an `*IT` class under a Maven pom where neither that pom nor any pom
  above it declares `maven-failsafe-plugin` or a Surefire `<include>` of `*IT` prints `NO-FAILSAFE
  <file>:<line>`. brittle-suite reaches **BS-SE-08**; the real repo has no Maven module (0).
- **`flake-source-scan` § 1 saw only the test side of a clock or zone read.** New grep 1d lists a
  zone-dependent format or calendar read in shipped JS / TS / Python (`toLocaleDateString` with no
  `timeZone`, `getMonth()`, `fromtimestamp` with no `tz`) in a module that a date-asserting test
  imports by name, as `source:line <- test:line`. brittle-suite reaches **BS-FL-12**
  (`RefundDue.tsx:3 <- RefundDue.test.tsx:7`) and not the coupon decoy; the real repo prints 61
  source lines in 16 modules behind 22 test files. A clock read behind a service, a helper or the
  database stays with the perturbation run.
- `_examples/coverage-gap.md` and `_examples/mutation-probe.md` carry the case-scoped denial rule,
  the extension-only strip and the no-merge-base rule.

## 2.0.0 — 2026-10-05

**The pack wrote tests and judged the ones in front of it; nothing judged the suite.** It had no
audit and one fix command (`/flaky-test-hunt`). `coverage-gap` and `mutation-probe` were the right
oracles — presence and strength — but described more than they ran, and a whole-repo run graded
nothing: tests that cannot fail, tests no runner collects, CI that masks a red run, flake sources
and doubles that lie were each a checklist line in an agent, checked by reading. `@test-reviewer`'s
one "grep for changes that lack tests" was a loop whose body was a comment: it ran and found nothing
(D-1).

- **Four detector skills**, each a runnable pre-flight script with per-runner lanes, BAD/GOOD and
  "read the code" questions per class, a 3,000-hit path and a class coverage block, measured on a
  real NestJS + React monorepo (read-only) and on `benchmarks/fixtures/*`:
  `assertion-strength-scan` (§1–§6: no or weak oracle, interaction-only, unreached or un-awaited,
  swallowed, expected value from the SUT, snapshot-only), `suite-execution-scan` (§1–§6: focus and
  ownerless skips, never collected, CI masking, coverage config that hides code, retries with no
  flaky gate), `flake-source-scan` (§1–§8: clock and expiring fixture dates, unseeded randomness,
  sleeps, real network, shared state, async leaks, parallel assumptions, brittle e2e) and
  `test-double-scan` (§1–§6: the SUT mocked, unchecked doubles, doubles of what the project does not
  own, engine substitution, test seams and special-cased test inputs in shipped code).
- **`coverage-gap` rewritten** with `--diff` and `--whole-repo` modes and seven classes. Its diff lane
  is `diff-cover` 10.6.0 over LCOV / Cobertura / JaCoCo, with the awk intersect as the fallback; the
  old "intersect changed lines with lcov" step was prose (D-14). A changed file missing from the
  report — which diff-cover silently skips — is its own row.
- **`mutation-probe` rewritten** with flags run on 2026-10-05 (D-3): StrykerJS has no `--since`
  (`--mutate file:L-L`; `--incremental` diffs against its own last report, not git), mutmut 3 dropped
  `--paths-to-mutate`, gremlins' flag is `--diff`, PIT's `scmMutationCoverage` was removed in 1.18.0.
  New Infection (PHP), mull (C/C++) and cosmic-ray rows, a manual seeded-mutant lane, a five-check
  equivalent-mutant procedure and the `mutant-kill` evidence row `/test-fix` consumes.
- **`/test-audit`** (read-only): every detector on a whole repo, by signal on a diff, after the
  repo-baseline's `test-integrity.py` and `oracle-check.py` lanes; every candidate refuted by a
  separate verifier (`templates/snippets/refute-before-report.md` with `precedents/testing.md`); a
  fixed class ledger and a `GO` / `GO-UNVERIFIED` / `NO-GO` verdict, written to
  `ai/audits/<date>-tests.md`.
- **`/test-fix`** closes an audit's findings: prove each failing-first with its oracle
  (`templates/snippets/proof-oracles.md` § Testing), fix the test or the gate and never the code,
  narrow an existing assertion only, run `test-integrity.py` and `oracle-check.py` on its own diff
  and refuse to close if either flags, re-detect, sweep siblings, run the suite shuffled. A finding
  that turns out to be a code defect goes to `/quality-fix` or `/fix-bug` with the test attached.
- **`@test-reviewer` runs the detectors and grades their rows.** On a diff it runs the two tool lanes,
  then `assertion-strength-scan`, `flake-source-scan`, `test-double-scan` and `suite-execution-scan`
  by signal on the changed files, `coverage-gap --diff` (replacing the empty loop, D-1) and
  `mutation-probe` through its diff-scoped lane — the old pointer to a `--since` / `--in-diff` mode
  named one StrykerJS does not have. A signalled detector that did not run is `UNREVIEWED(<class>)`
  and caps the verdict. `/review-changes` and `/pre-commit` (code-quality pack) dispatch the same
  four on changed test files, and `/check-health` reads the latest `/test-audit` verdict as its
  Tests row.
- **`/flaky-test-hunt`.** Phase 4's "scan for the same pattern" is now `flake-source-scan`'s grep for
  the root-cause class, with a class map, so `N_found` is a read list. The Jest row said `--shuffle`;
  Jest 30's flag is `--randomize`, which shuffles within a file only, so cross-file order dependence
  is `NOT TESTED` unless the file order is varied too. Phase 7 pointed at `pylint async-no-await`, a
  message that does not exist (D-4); it now names `@typescript-eslint/no-floating-promises` on test
  globs and ruff `RUF006` / `ASYNC`, at error.
- **`STACK.md` lane table** (D-16): the test lint lane, runtime guards, diff-scoped mutation and
  changed-line coverage for twelve stacks, and the WARN trap — eslint-plugin-jest's `recommended`
  leaves `expect-expect`, `no-disabled-tests` and `no-commented-out-tests` at warn, so a lane run
  without `--max-warnings 0` reads clean while they fire.
- **`testing-principles`: scoped by `paths:`, and enforced by detectors** (D-15). It ships a
  `paths:` default (source, config, CI, snapshot and Makefile shapes) marked
  `paths-origin: pack-default-482709ec`, so `/setup-project` can narrow it and it no longer loads in
  sessions that touch no code. Its Enforcement section names the detector for each MUST, including
  "never `--forceExit`" (the measured real repo ran its e2e job with it). The `.skip` bullet demanded a
  linked issue as well as an owner and a date; precedence A2 settles that the owner and the date are
  required and a ticket is optional (`THR-TODO`), and the coverage and mutation bars cite
  `THR-COVERAGE` and `THR-MUTATION`.
- **`ai-patterns/test-doubles`** gained a Detectors section: `test-double-scan` is its executor.
- **Frontmatter** (D-2): `contract-test`, `property-invariants` and `test-factories` declare
  `kind: skill` and `pack: testing`, as `coverage-gap` and `mutation-probe` now do.
- **Agents carry a Contract block** (`templates/snippets/contract-block.md`):
  `@test-reviewer` is a judge with no write tool, `@test-engineer` and `@tdd-orchestrator` are writers.
- **Minimal install** ships `test-audit`, `assertion-strength-scan` and `suite-execution-scan` beside
  `coverage-gap`. `/test-fix`, `flake-source-scan`, `test-double-scan` and `mutation-probe` ship in
  standard mode; on a minimal install `/test-audit` prints their rows `not run`, forcing
  `GO-UNVERIFIED`.

**Known gaps.** The detectors' recall was measured on one real repo and on fixtures that seed no
testing class; the seeded fixture for this pack (`benchmarks/fixtures/brittle-suite`) was still being
built when this release was cut, and no detector has been scored against its answer key yet. Diff-time detection of a **changed** expected value, a widened tolerance, a
snapshot rewrite, a `NODE_ENV === 'test'` branch or an equality override belongs to
`test-integrity.py` v2 (repo-baseline); until it ships, `test-double-scan` § 5–§ 6 run on diffs too,
and `/test-fix`'s self-check cannot see a flipped expected value. `oracle-check.py` reads supertest's
`.expect(<status>)` as a weak oracle and parses `it(` inside comment blocks; `assertion-strength-scan`
reads its rows as candidates for that reason.

**Upgrading.** Every existing skill and command keeps its name, so name-based references resolve.
On `/setup-project --upgrade` or `--refresh` with this pack selected, the four new skills and the
two new commands are added and the rewritten files replaced. A project that hand-scoped
`testing-principles` keeps its own `paths:`: the setup replaces only a block whose
`pack-default-<sha8>` marker still matches its globs.

## 1.6.1 — 2026-08-23

**`/tdd`'s greenfield fallback was three empty headings over a 98-line dispatcher.**
The topic declared `fallback: stub-from-sections` with `sections: [understand, dispatch, surface]`,
so a no-signal project received three headings and no content — and the entry ledgered in
`templates/packs/_topics-strategy-baseline.md` justified it as "the source reads as a generic
tutorial when copied cold", which does not describe the file. `commands/tdd.md` is a thin entry
point that says outright "the discipline lives in the agent"; there is nothing project-specific in
it to get wrong, and its Phase 2 carries the `RED-UNOBSERVABLE` substitute-proof rule for criteria
that cannot be made to fail on demand (the security and concurrency ones, disproportionately) —
which the skeleton discarded entirely. `fallback:` now names `commands/tdd.md` and the ledger line
is gone. Per `templates/packs/_fallback-baseline.md` § "Source-as-fallback is a trade", this moves
the topic out of check 8b's `_examples/` scope: delivered in full, no longer compared against
anything.

## 1.6.0 — 2026-08-22

- **Audit corrections (same release).** The pytest row of `/flaky-test-hunt`'s invocation table
  prescribed `-p no:randomly`, which switches *off* the shuffling the sweep depends on — a silent
  false-negative machine inside a command whose whole premise is that a green sweep must be honest
  about what it establishes. The row now relies on pytest-randomly's default shuffle (cited) and
  forbids the flag; the mocha / playwright / go / cargo rows gained accurate, cited
  order-randomisation facts. New **failure branch**: where the runner has no shuffle at all, the
  report prints `Order dependence: NOT TESTED (no shuffle available for <runner>)` instead of letting
  a partial sweep read as clean. Phase 5 now also appends each sweep run to `ai/test-runs/` — the
  only path `/run-tests` Phase 7 reads for its flake trigger — so the pack's two commands stop
  keeping separate ledgers of the same fact; `run-tests.md`'s "nothing else writes this path" was
  corrected to match.

**The pack claimed to measure correctness and, in several places, only asserted it.** This release
holds every testing artifact to the same standard the pack's own hard rule states: a result is
transcribed from a runner, or it is a named non-result. Nothing is inferred from scrolled output.

- **`/run-tests`: the exit code is the source of truth.** Every number the report prints is now
  transcribed from the runner's own summary block — command argv, exit status, the summary verbatim
  — and a row that cannot be filled prints its `not computed` form plus what would produce it.
  `NOT-RUN` is a terminal state alongside PASS / FAIL / PARTIAL and may never be reported as a pass.
- **`@tdd-orchestrator`: `RED-UNOBSERVABLE`, and the criteria it stops you from deleting.** The
  old "if it passes on first run, the behaviour exists or the test is too lenient" fork silently
  discarded a third case — behaviours that *cannot* be made to fail on demand. Those are precisely
  the absence invariants ("the PAN is never logged"), concurrency guarantees and external-failure
  paths, i.e. the security and correctness criteria that most need a test. Each now has a required
  substitute proof (seed the violation and observe RED; a race harness; an injected fault at the
  port boundary), and a criterion with no available proof still ships, marked `unproven` and named
  in the verdict. The cycle table now demands the runner's **verbatim assertion message**; a bare
  "observed failing ✓" is an assertion about a measurement, not the measurement.
- **`@test-engineer` / `@test-reviewer`: authorship and audit are never the same run.** Each states
  the axis it owns and hands the rest over by name, so a self-graded effectiveness ledger can no
  longer read as a review. `@test-reviewer` no longer supplies a mutation-score floor — no authority
  publishes one, so the bar is a ratchet against the project's own recorded baseline, and where no
  baseline exists, establishing one *is* the finding.
- **`/add-test`: the coverage ADR no longer names a number nobody measured.** "Multiple modules at
  < 60% → queue ADR" was an invented threshold in the one pack whose thesis is that coverage is a
  floor and not a target. Replaced by the shape that actually indicates a systemic gap (several
  modules missing tests on the *same* axis) and by a ratchet — fail on a drop from what the repo
  already measures — with the reason stated: a threshold nobody measured either fires on everything
  and gets muted, or fires on nothing.
- **`testing-principles`: 5,927 → ~4,380 characters (~1,481 → ~1,094 always-loaded tokens).** The
  "every fixed bug ships with a regression test" MUST was a verbatim restatement of the Hard rule
  eight lines above it. The two coverage bullets are now one, and the pair of illustrative
  percentages inside them ("80% with bad asserts is worse than 50% with sharp ones") is gone —
  the sentence makes the same point without borrowing two numbers in a file that then tells you no
  fixed score is the bar. The depth pointer said `../ai-patterns/`, which from the installed
  `.claude/rules/` resolves to `.claude/rules/ai-patterns/`; patterns install to `ai/patterns/`.

## 1.5.0 — 2026-07-10

- add-test Phase 6 production-grade-or-INCOMPLETE effectiveness gate wired to the mutation-probe
  skill: a new/changed test must kill a seeded mutant (harness-measured) or be reported UNVERIFIED.
- test-reviewer: mutation effectiveness promoted from optional to a gating dimension.

## 1.4.1 — 2026-07-10

- contract-test: added the numbered Procedure (fetch pact -> replay against real provider -> parse
  mismatches with consumer <path:line> -> can-i-deploy gate) + an Output block citing
  verified-interaction/mismatch counts, matching coverage-gap/mutation-probe shape.

## 1.4.0 — 2026-07-10

- skills +2: property-invariants (for-all property/generator testing vs example-based) and
  test-factories (factory/builder test data vs duplicated fixtures / shared-mutable).

## 1.3.0 — 2026-07-09

- skills +1: mutation-probe — measures test STRENGTH via surviving-mutant analysis (branches
  executed but never asserted), orthogonal to coverage-gap's test PRESENCE. Per-stack mutation-tool
  table (Stryker/mutmut/PIT/gremlins). Backing SHOULD in testing-principles.

## 1.2.0 — 2026-06-22

- Sync-chain repair: _topics.md now declares run-tests as a command (kind:command,
  test_framework_detected trigger). It shipped under commands/ and is listed in _essentials.md
  commands, but was absent from the topic list, so /setup-project AUTHOR-mode generation silently
  dropped it. No _examples/run-tests.md stub exists, so the fallback points at the live source
  (commands/run-tests.md).
