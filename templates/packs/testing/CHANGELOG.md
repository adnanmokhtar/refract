# testing pack — changelog

Release history for `templates/packs/testing/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

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
