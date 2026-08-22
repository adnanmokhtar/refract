---
name: saga
description: Pattern: Saga
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Saga

> **Hard rule:** A saga is a sequence of local transactions where each step has an explicit, idempotent compensating action; saga state is persisted at every step transition. Distributed 2PC, "we'll just retry the whole thing", or compensations that aren't idempotent are forbidden.

**When to apply**
- A workflow spans 2+ services with local DBs and partial-commit must be reversible.
- A long-running process (≥ seconds) where in-memory state would be lost on crash.
- Cross-service "all-or-nothing" semantics where ACID is impossible.

**When NOT to apply**
- All steps live in one service with one DB — use a local transaction.
- Steps don't actually need rollback (event-driven projection updates) — use outbox + idempotent consumers.

**Halt conditions / mandatory cites**
- Every step MUST cite its forward action AND its compensating action at `<path:line>`.
- Saga state persistence (table, columns, status enum) MUST be cited.
- A doc with a step lacking a compensation is a bug — reject; either add one or redesign.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "compensation is idempotent".
- If the orchestration mechanism (orchestrator vs choreography) isn't extracted, halt.

Long-running distributed transaction via a sequence of local transactions + compensating actions. Used when you need "all-or-nothing" across services but can't use a distributed ACID transaction.

## When to use

- Workflow spans ≥2 services with local DBs.
- All steps must complete OR all completed steps must be compensated.
- Examples: order placement (reserve inventory → charge card → create shipment), booking (hold seat → charge → confirm).

## Two flavors

### Choreography (peer-to-peer events)
- Each service listens for events, does its work, emits next event.
- No central coordinator.
- Simpler for 2-3 step flows. Gets tangled past that.

### Orchestration (central coordinator)
- A "saga orchestrator" service calls each step explicitly.
- Compensations triggered by orchestrator on failure.
- Clearer for complex flows, easier to visualize + debug.

## Shape (orchestrated, stack-agnostic)

The orchestrator runs each forward step in sequence, persisting state after each one. On any step failure, it runs the compensations in reverse order. Concretely, for a place-order saga:

1. `inventory.reserve(orderId)` → on failure: mark order failed.
2. `payments.charge(orderId)` → on failure: `inventory.release(reservation.id)`.
3. `shipments.create(orderId)` → on failure: `payments.refund(charge.id)` + `inventory.release(reservation.id)`.

Implement using the language's structured exception / try-finally semantics OR (preferred) a durable workflow engine (design + review it with the `@workflow-orchestrator` agent, which owns the workflow-vs-activity split that makes replay safe).

Saga state persisted at each step (a saga-state table in the project's DB) so crashes resume correctly.

## Compensations

- Every forward action has a reverse action. Document them per saga.
- Compensations must be idempotent (run may happen twice).
- Some actions are not reversible (sent an email, made a physical shipment) — design so those are LAST, or explicitly accept non-compensation.

## Saga isolation (the missing I in ACID)

A saga gives you **A, C, D** but **not I**. Its steps commit locally as they go, so a concurrent saga (or any reader) can see a saga's *intermediate* state — the classic anomalies return:

- **Dirty reads** — a saga reads a value another in-flight saga wrote but hasn't yet committed/compensated.
- **Lost updates** — two sagas read-modify-write the same row; one clobbers the other.
- **Fuzzy / non-repeatable reads** — a saga reads the same row twice and gets different values because another saga committed a step in between.

There is no lock spanning the saga, so you engineer isolation with **countermeasures** — pick per how much concurrency and how much anomaly risk the flow carries:

- **Semantic lock** — a `PENDING`/`IN_PROGRESS` status flag on the record the saga is mutating; other sagas (and readers) treat pending rows specially (skip, wait, or fail). The most common default; the compensation/completion clears the flag. Use when a resource must not be double-acted on mid-saga.
- **Commutative updates** — design step effects so order doesn't matter (`balance += x` / `-= x` instead of `set balance = y`). Lost updates vanish because applies commute. Use for counters, balances, additive state.
- **Pessimistic view** — reorder steps so the step most likely to cause a dirty-read anomaly runs last (or earliest-safe), shrinking the window where dangerous intermediate state is visible. Use when reordering is cheap and one step dominates the risk.
- **Reread value / version file** — before acting or compensating, re-read the record and check a version/state (optimistic check); abort or re-plan if it changed since the saga read it. Use to catch lost updates without a lock.
- **By-value** — route each request through a strategy chosen by business **risk**: low-value requests use fast, less-isolated paths (eventual anomalies tolerated); high-value requests use stricter countermeasures (semantic locks, even 2PC for the one critical step). Use when isolation cost must scale with stakes.

Default posture: **semantic lock + commutative updates** cover most flows; add reread/version checks where lost updates bite; reserve pessimistic-view and by-value for hot, high-stakes paths.

## Persistence

- Saga state in a DB table with { saga_id, step, status, payload }.
- On crash + resume: query saga state, continue from last completed step.
- Timeout per step — if step B doesn't respond in N min, mark failed + compensate.

## Failure modes

- Step fails → compensate all preceding.
- Step timeouts → same as fail (after retry policy exhausted).
- Compensation fails → retry with backoff, then escalate to human.

## Testing

- Test each step's failure path — the compensation must fire.
- Test crash mid-saga — state persists + resumes.
- Chaos: inject failures at random steps in test env.

## Forbidden

- Saga without compensations (that's just a pipeline with silent failures).
- Non-idempotent steps (every step + every compensation must be idempotent).
- Synchronous saga in a request-response handler (long-running; move to a job).
- Shared DB across saga services (defeats the purpose).
