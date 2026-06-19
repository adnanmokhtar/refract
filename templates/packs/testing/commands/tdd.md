---
description: Drive a feature test-first via the tdd-orchestrator — strict RED→GREEN→REFACTOR, one behavior per cycle, no production code before an observed failing test. Thin entry point; the discipline lives in the agent.
kind: command
pack: testing
---

# /tdd [feature]

## The Premise (read this first)

**TDD is an ORDER, not an activity.** Write a failing test, observe it fail for the right reason, write the minimum code to pass it, refactor under green, repeat — one behavior per cycle. "Write the tests after" is not TDD; a test that passes on first run is not TDD either. This command is the **command entry point** for that discipline: it resolves the feature, then hands the whole loop to `@tdd-orchestrator`, which owns every invariant, halt, and cheat-detector. This command does not re-implement the loop — it dispatches the agent that does.

Without this entry point the `tdd-orchestrator` agent is orphaned (no command surfaces it). `/tdd` is the surface; the agent is the engine.

## When to use / NOT to use

- USE: net-new behavior with real logic where you want the design driven by tests.
- USE: a bug fix you want to start from a failing reproduction (or route via `/fix-bug`, which does the same red-first move inline).
- USE: refactor-prone domain logic where regression safety must come first.
- NOT: throwaway scripts / one-off migrations — write the minimum, ship (see `@tdd-orchestrator` § "When NOT to use TDD").
- NOT: spikes / proofs-of-concept where the design hasn't settled — explore first, harden after.
- NOT: authoring tests for already-written code → use `/add-test` (test-after, mirror-sibling).

## Args

- `[feature]` (optional) — feature name, acceptance-criteria reference, or a path to a spec. If omitted, the orchestrator interviews for the acceptance criteria (one cycle per criterion).

## Phase 1 — Understand

- Resolve the feature + its acceptance criteria. Each criterion becomes one RED→GREEN→REFACTOR cycle.
- Detect the test runner + assertion/mock style (the orchestrator's pre-flight does this; this command just passes the resolved scope).

## Phase 2 — Dispatch

- Dispatch `@tdd-orchestrator` with the resolved feature + criteria. It runs the loop:
  - **RED** — write one behavior-named failing test; observe it fail for an assertion reason (not a compile/import error).
  - **GREEN** — minimum code to pass; full suite stays green.
  - **REFACTOR** — structure only, under green; revert any refactor that turns a test red.
- The orchestrator HALTS on every cheat (GREEN without observed RED, REFACTOR that changes behavior, stacked red, mocking the SUT). This command does not override those halts — it surfaces them.

## Phase 3 — Surface

- Relay the orchestrator's per-cycle report (RED observed / GREEN minimal / suite green / refactor under green) + its verdict (DISCIPLINE MAINTAINED · MINOR DEVIATIONS · MAJOR VIOLATIONS) + required follow-ups.

## Output format

```
## /tdd — <feature> — <N> cycles, <verdict>

Cycle 1: <criterion>
  RED:      <test_file>:<line> — observed failing ✓
  GREEN:    <impl_file>:<line> — minimal, suite green ✓
  REFACTOR: <one-line> — suite green ✓
Cycle 2: ...

Discipline: DISCIPLINE MAINTAINED | MINOR DEVIATIONS | MAJOR VIOLATIONS
Follow-ups: <trim speculative code / add behavior tests / ...>

Status: COMPLETE
```

## Hard rules

- **No production code before an observed RED.** If code arrives green, the orchestrator reconstructs the cycle (revert, run, capture failure, reapply).
- **One behavior per cycle.** Multi-behavior cycles get decomposed.
- **Never refactor under red.** Refactoring under a red suite corrupts working code.
- **Thin command, deep agent.** All discipline lives in `@tdd-orchestrator`; this command must not duplicate or weaken it.

## Failure modes

- Treating `/tdd` as "generate tests for this" → that's `/add-test`; `/tdd` writes tests *first* and drives code from them.
- Demanding `/tdd` on a prototype → forces premature design; skip the loop until the design settles.
- Counting tests instead of behaviors → 100 tests on one path is one test in disguise.

## Related

### Agents
- `@tdd-orchestrator` — the engine this command dispatches; owns RED→GREEN→REFACTOR + cheat detection + mutation-testing guidance.

### Sibling commands in testing pack
- `/add-test` — test-after authoring (mirror-sibling); use when code already exists.
- `/run-tests` — run the suite during/after cycles.
- `/flaky-test-hunt` — once green, hunt non-determinism.

### Patterns
- `ai/patterns/test-doubles.md`
- `ai/patterns/test-strategy.md`

### Rules
- `.claude/rules/testing-principles.md`
