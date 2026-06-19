---
track: testing
purpose: Test design, authoring, and coverage analysis across the codebase.
essentials:
  agents: [test-engineer, test-reviewer]
  commands: [add-test, run-tests]
  skills: [coverage-gap]
  rules: [testing-principles]
  ai-patterns: [test-strategy]
---

# Testing — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: test-engineer writes tests, test-reviewer audits them — minimal author+review pair; tdd-orchestrator (the RED→GREEN→REFACTOR engine behind `/tdd`) ships in standard mode and is kept out of minimal.
- commands: add-test (test-after) + run-tests (the runner) are the minimal pair; flaky-test-hunt (non-determinism) and tdd (test-first, dispatches tdd-orchestrator) ship in standard mode and are kept out of minimal.
- skills: coverage-gap finds what's actually missing — the entry point for any testing effort.
- rules: testing-principles is the single rules file in the pack.
- ai-patterns: test-strategy frames pyramid/diamond decisions; test-doubles is a sub-topic kept out of minimal.
