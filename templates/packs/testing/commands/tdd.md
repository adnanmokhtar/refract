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

- Dispatch `@tdd-orchestrator` with the resolved feature + criteria. It runs the loop (RED → GREEN → REFACTOR, one behaviour per cycle) and owns every invariant, halt and cheat-detector. This command does not restate them — read the agent.
- **Surface the un-failable branch to the user, because it is a choice they must see.** Some criteria — "the PAN never reaches the logs", "a concurrent double-submit stores one card", "a PSP timeout leaves no partial charge" — cannot be made to fail on demand: they pass on the first run because the thing they forbid does not exist yet, or needs an interleaving a single-threaded cycle cannot produce. The orchestrator's RED step 6 routes these to `RED-UNOBSERVABLE` **with a substitute proof** (seed the violation and watch the test go red; a race harness; an injected fault) rather than dropping them. When a criterion takes that branch, say so in the relayed report and name the proof — a silently-dropped criterion is invisible, and the criteria that land here are disproportionately the security and concurrency ones.
- This command does not override the orchestrator's halts — it surfaces them, unsoftened.

## Phase 3 — Surface

- Relay the orchestrator's per-cycle report (RED observed / GREEN minimal / suite green / refactor under green) + its verdict (DISCIPLINE MAINTAINED · MINOR DEVIATIONS · MAJOR VIOLATIONS) + required follow-ups.

## Output format

```
## /tdd — <feature> — <N> cycles, <verdict>

Cycle 1: <criterion>
  RED:      <test_file>:<line> — observed failing: <the runner's verbatim assertion line> ✓
            # or: RED-UNOBSERVABLE (<class>) — proof: <seeded violation | race harness | injected fault> went RED, reverted ✓
            # or: RED-UNOBSERVABLE — unproven: <what would prove it>
  GREEN:    <impl_file>:<line> — minimal, suite green ✓
  REFACTOR: <one-line> — suite green ✓
Cycle 2: ...

Discipline: DISCIPLINE MAINTAINED | MINOR DEVIATIONS | MAJOR VIOLATIONS
Unproven criteria: <none> | <criterion — what would prove it>
Follow-ups: <trim speculative code / add behavior tests / ...>

Status: DISCIPLINE MAINTAINED — <N> cycles, every RED evidenced
  # OR
Status: MINOR DEVIATIONS — <named>
  # OR
Status: MAJOR VIOLATIONS — <named>   # a cycle with no observed RED and no substitute proof lands here
```

A bare `COMPLETE` is not a valid terminal status: the reader must be able to tell *every RED was evidenced* from *the loop ran and nobody checked*, which is the entire question this command exists to answer.

## Hard rules

These are the *command's* rules. The loop's rules live in `@tdd-orchestrator` and are deliberately not copied here — a duplicated invariant is one that can drift out of step with the engine that enforces it, and this file previously restated three of them under a bullet forbidding exactly that.

- **Thin command, deep agent.** All loop discipline lives in `@tdd-orchestrator`. This command resolves scope, dispatches, and relays. It must never restate, summarise, or weaken an invariant.
- **Relay halts unsoftened.** A `MAJOR VIOLATIONS` verdict is reported as such. Never round a partial pass up, and never report `COMPLETE`.
- **Name every unproven criterion.** A criterion that reached `RED-UNOBSERVABLE — unproven` appears in the output. Dropping it from the report is the one failure this command can cause on its own.

## Failure modes

- Treating `/tdd` as "generate tests for this" → that's `/add-test`; `/tdd` writes tests *first* and drives code from them.
- Relaying the orchestrator's cycle table but omitting its unproven criteria → the report reads clean while a named guarantee rests on nothing.
- Reaching for `@tdd-orchestrator` § "When NOT to use TDD" because a criterion won't go red → that list does not cover it; RED step 6's `RED-UNOBSERVABLE` branch does.

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
