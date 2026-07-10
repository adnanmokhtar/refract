---
description: Implement a saga (orchestration / choreography) for a multi-step distributed transaction with compensations. Outputs the state machine + compensations + idempotency + retry + observability.
---

# /add-saga

Add a saga when a business transaction spans 2+ services AND can't be a single atomic DB transaction. Distributed transactions need explicit state, retries, and compensations.

## Premise

Existing sagas are the truth. Mirror the sibling saga's shape exactly: state-machine definition, step naming, compensation-pairing style, idempotency-key convention, retry classification, timeout defaults, saga-state ledger schema, span/metric naming. Read at least two sibling sagas (or the durable-engine's existing workflows) BEFORE writing — copy their conventions. A bespoke saga that re-rolls compensation pairing or idempotency-key format is a replay-orphan and a stuck-saga incident waiting to happen. New shapes need an ADR, not a fresh invention.

## Mechanical halt

- Sibling-shape parity — refuse to generate a saga that diverges from sibling conventions without an ADR cite in the PR. If the project has zero existing sagas, halt and ask which pattern to seed from.
- Every step MUST carry all five parts (idempotency key, timeout, retry classification, compensation OR documented irreversibility, trace propagation); missing any one on any step halts generation.
- A compensation without its own idempotency guarantee halts — double-compensation corrupts state.
- Saga runtime unconfirmed (durable-engine worker / state-machine ARN / event-broker + saga-state ledger absent) — halt (see Phase 1 pre-flight).

## Phases applied

All 7.

## When to use / NOT to use

- USE: order placement spans inventory + payment + shipping services.
- USE: signup spans auth + billing + email-verification + onboarding.
- USE: any flow where partial completion is possible AND compensations are needed.
- NOT: single-service transaction → use a DB transaction.
- NOT: simple sequential calls where rollback isn't needed → don't add saga overhead.
- NOT: idempotent fire-and-forget events → use simple event-handler.

## Phase 1 — Understand

**Pre-flight (infrastructure check)**: Verify the project's saga infrastructure exists (the durable workflow engine's worker config / state-machine ARN / event broker URL — per the project's stack) in `.claude/codebase-profile.md` or env. If absent, halt and ask the user to confirm the saga runtime before generating saga code.

Confirm:
- The flow's steps (each = a service call OR DB write).
- Per step: what does compensation look like? (Refund a payment? Restore inventory? Cancel email?)
- Per step: is it idempotent? (Same input + same effect on retry.)
- Failure semantics: at-least-once / exactly-once / at-most-once?
- Latency tolerance: synchronous (user waits) or async (background)?
- Existing infrastructure: queue / orchestrator / event bus?

## Phase 2 — Organize

Choose orchestration vs choreography:

| Pattern | When |
|---|---|
| **Orchestration** (central coordinator) | 3+ steps; complex compensation logic; need single-source-of-truth for state. |
| **Choreography** (event-driven) | 2-3 steps; simple flow; teams own services independently; loose coupling preferred. |

Orchestration tools: pick a durable workflow engine (vendor-neutral examples include Temporal, Cadence, Camunda Zeebe; vendor-managed examples include AWS Step Functions, Azure Durable Functions, Inngest, Restate; serverless event-driven options like Trigger.dev). The project's choice is the oracle.

Choreography: just events on the project's bus (the message bus / queue / event-stream platform — Kafka / Pulsar / RabbitMQ / SQS / NATS / EventBridge / Cloud Pub/Sub / Redis Streams) + per-service handlers.

## Phase 3 — Retrieve

- `ai/architecture.md` — service boundaries.
- `ai/patterns/event-sourcing.md` if event-sourced.
- `ai/decisions/` for past saga choices.
- Existing saga state machines in code (mirror their style).

## Phase 4 — Generate

### Orchestration (stack-agnostic, durable workflow engine)

Define a workflow function with the engine's SDK. The workflow:

1. Step 1 — `reserveInventory(orderId, lineItems)`. On failure, return `{status: 'failed', step: 'reserveInventory'}`.
2. Step 2 — `chargePayment(orderId, paymentMethodId)`. On failure, run `releaseInventory` if step 1 succeeded; return failed.
3. Step 3 — `scheduleShipping(orderId, shippingAddress)`. On failure, run `refundPayment` then `releaseInventory`; return failed.
4. Step 4 — `sendConfirmation(orderId)` as best-effort (catch + log + don't compensate).
5. Return `{status: 'completed', orderId, paymentId, shippingId}`.

Each step is registered as an activity / task with the engine's per-step timeout + retry policy. The workflow body is deterministic (no direct I/O / clock / random — use the engine's SDK equivalents).

### Choreography (events example, stack-agnostic)

- **inventory-service** handles `OrderRequested` → calls `reserveInventory`. On success publishes `InventoryReserved`; on failure publishes `InventoryReservationFailed`.
- **payment-service** handles `InventoryReserved` → calls `chargePayment`. On success publishes `PaymentSucceeded`; on failure publishes `PaymentFailed`.
- **inventory-service** handles `PaymentFailed` (compensation) → calls `releaseInventory`, publishes `InventoryReleased`.

All publishes go through the project's message bus / event-stream platform; consumers are idempotent and dedup by event id.

### Common requirements (BOTH patterns)

- **Idempotency** — every step has an idempotency key (typically the orderId + step name). Re-submission produces same effect.
- **Retry** — transient failures retry with backoff; non-transient (4xx) don't.
- **Timeout** — every step has a max time; saga halts and compensates if exceeded.
- **Observability** — saga state visible at every step; trace ID propagates across services.
- **Persistence** — saga state durable across crashes (a durable workflow engine handles this automatically; choreography needs an explicit saga-state ledger in the project's DB).
- **Compensations** — per step, the inverse operation defined. Compensations are themselves idempotent.
- **Failure surfaces** — user-facing message on failure (don't silently retry forever).

## Phase 5 — Update

- `ai/patterns/saga-<feature>.md` — pattern doc for THIS saga.
- `ai/decisions/<NNNN>-saga-<feature>.md` — orchestration vs choreography choice + rationale.
- `ai/runbooks/saga-recovery.md` — runbook for stuck sagas (manual unstick steps).
- Code: workflow file + activity files + tests.

## Phase 6 — Validate

Enumerate the required scenarios; each MUST actually run and be GREEN:

- Happy path: all steps succeed.
- Failure at each step: verify correct compensation order.
- Idempotent retry: re-run same input twice → same final state.
- Timeout at each step: saga halts + compensates.
- Crash recovery: kill the worker mid-flow; saga resumes from last persisted state (durable workflow engine: automatic; choreography: harder — requires careful design).
- Observability: trace shows all steps + status.
- Manual unstick path: documented.

**Green-or-HALT gate (mechanical, mirrors `perf-audit`'s after-projection halt).** `scenarios_green == scenarios_required OR HALT`. Every enumerated scenario test above must have actually EXECUTED and PASSED — an intended-but-unrun scenario counts as red. If any scenario is red / failing / unrun: HALT, report the failing scenario, do NOT emit the `Tested:` / `## /add-saga complete` block. The `Tested:` output must render the real per-scenario pass/fail result (from the actual test run), never an asserted checklist.

## Phase 7 — Improve

- Pattern emerged → propose `saga` pattern doc reuse.
- Common compensation → extract helper.
- Manual unstick frequent → automate the recovery.

## Output format

```
## /add-saga complete

Saga: <name>
Pattern: orchestration | choreography
Steps: <count>
Compensations: <count>
Idempotency keys: <list>
Timeouts: <per step>

Files written:
- workflow / handlers
- compensations
- tests
- ai/patterns/saga-<name>.md
- ai/decisions/<NNNN>-*.md
- ai/runbooks/saga-recovery.md

Tested (actual run — PASS/FAIL per scenario, all must be PASS):
- happy path                                  PASS
- failure at each step (compensation order)   PASS
- idempotent retry                            PASS
- timeout at each step                        PASS
- crash + resume                              PASS
- observability (trace shows all steps)       PASS
scenarios_green: <n>/<required>  (block emitted only when equal)
```

## Hard rules

- **Every step idempotent.** Same input + same effect on retry.
- **Every step has compensation OR is documented as fire-and-forget acceptable.**
- **Every step has timeout.** No unbounded waits.
- **Saga state durable across crashes.** Durable workflow engine / state-machine service / explicit event ledger.
- **User-facing failure surface.** Don't silently retry forever.
- **Observable.** Trace ID through every step.

## Failure modes

- Compensation NOT idempotent → double-compensation breaks state.
- Step assumes other service is up; outage cascades into saga starvation.
- Choreography conflicting events: Service A says "fail," Service B says "succeed" — no central truth.
- Compensation order wrong (refund before inventory release → customer double-charged briefly).
- Saga stuck waiting on a manual approval that never comes; no escalation.
- Idempotency key collision across saga instances.
- Time zone bug in timeout comparison.

## Related

- `add-event-handler` command — chunks of choreography.
- `audit-distributed-tx` command — periodic check for stuck sagas.
- `dlq-replay` skill — replay failed events.
- `ai/patterns/event-sourcing.md` — sometimes overlapping concern.
- `@event-sourcing-architect` agent — same-pack sibling; consult for event-sourced sagas.
- `@workflow-orchestrator` agent — same-pack sibling; owns durable-workflow orchestration design + review.
