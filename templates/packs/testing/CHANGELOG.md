# testing pack — changelog

Release history for `templates/packs/testing/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

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
