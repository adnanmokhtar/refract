---
track: testing
purpose: Test design, authoring, and coverage analysis across the codebase.
essentials:
  agents: [test-reviewer]
  commands: [add-test, run-tests, test-audit]
  skills: [coverage-gap, assertion-strength-scan, suite-execution-scan, characterize]
  rules: [testing-principles]
  ai-patterns: [test-strategy]
---

# Testing — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: test-reviewer audits tests; the author is the delivery pack's `test-engineer` (always installed), which reads this pack's `lenses/test-craft.md` (the craft that was this pack's own test-engineer until Phase 6, shipped with the pack's lenses in every mode) — the minimal author+review pair; tdd-orchestrator (the RED→GREEN→REFACTOR engine behind `/tdd`) ships in standard mode and is kept out of minimal.
- commands: add-test (test-after) + run-tests (the runner) are the minimal pair; test-audit is the read-only gate that answers "would this suite catch a regression?" with a class ledger and a verdict. test-fix closes an audit's findings and ships in standard mode, like the other packs' fix commands (`/db-fix`, `/security-fix`). flaky-test-hunt (non-determinism) and tdd (test-first, dispatches tdd-orchestrator) also ship in standard mode.
- skills: coverage-gap finds code no test executes — the presence oracle and the entry point for any testing effort. assertion-strength-scan finds tests that cannot fail, the defect agents write most (a weak or missing oracle); suite-execution-scan finds tests that never run or a CI that never fails, without which every other verdict is moot. characterize is in minimal because `/refactor`, `/optimize`, `/upgrade-dep`, `/migrate` and `/add-feature` P5 call it first: without it "behaviour preserved" stays a claim (they print `not characterized`). flake-source-scan (the static half of `/flaky-test-hunt`), test-double-scan (mocked SUTs, untyped doubles, emulated databases, test seams in shipped code) and mutation-probe (the strength harness) ship in standard mode; on a minimal install `/test-audit` prints their ledger rows `not run`, which forces `GO-UNVERIFIED`.
- rules: testing-principles is the single rules file in the pack.
- ai-patterns: test-strategy frames pyramid/diamond decisions; test-doubles is a sub-topic kept out of minimal.
