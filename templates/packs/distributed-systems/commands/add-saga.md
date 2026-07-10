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

Happy-path + compensation-order is the floor, not the bar. A durable engine gives at-least-once **activity** execution and the orchestrator↔worker link can partition, so a saga is production-grade only when: every step's EFFECT is exactly-once under activity redelivery; every compensation is exactly-once AND itself idempotent under redelivery (double-compensation is the signature saga corruption); and the saga survives an orchestrator/worker partition without losing or double-running a step. A saga that passes only happy + sequential compensation-order is FUNCTIONAL, not production-grade.

### Precondition — per-step + per-compensation reserve cited + atomic (HALT if unmet)

Each step's effect AND each compensation MUST carry an **atomic** idempotency reserve keyed by `(sagaId, stepName)`, cited at `<path:line>` — because a durable engine re-runs an activity that timed out mid-effect, and a redelivered compensation must not compensate twice. Detector:

```
rg -n "ON CONFLICT|INSERT .*saga_step|UNIQUE.*saga|status *!= *'|WHERE .*status *=" <activities> <migration>
```

- GOOD — the effect is guarded by a same-tx `(sagaId, stepName)` unique row, OR a conditional state transition (`UPDATE ... SET status='done' WHERE saga_id=? AND step=? AND status='pending'`, affected-rows=0 ⇒ already applied). Compensation guarded the same way (`... AND status='compensating'`).
- BAD — a step or compensation that reads saga state then acts in a separate statement (check-then-act), or a compensation with no reserve of its own (`add-saga` Mechanical halt already forbids this — this gate is where it is PROVEN, not just declared).

No atomic reserve on a step or a compensation → HALT.

### Required failure-mode scenarios — each runs GREEN, or is marked UNVERIFIED/SKIPPED with the reason (never a faked PASS)

`scenarios_required` (the redelivery/partition rows are the deepening over sequential compensation-order):

1. **happy path** — all steps succeed.
2. **failure at each step → compensation ORDER** — reverse order, each compensation fires; the un-run steps are NOT compensated.
3. **exactly-once step effect (crash-in-the-gap)** — kill the worker AFTER a step's effect commits but BEFORE the orchestrator records the step complete; on resume the engine re-runs the activity → the effect is still applied **once** (proves the reserve spans the effect↔record boundary, not just "resumes from last state").
4. **compensation under redelivery** — a compensation runs, the worker crashes, the engine redelivers it → the compensation applies **once**; state is NOT double-compensated (no double refund / double inventory release).
5. **timeout at each step** — saga halts + compensates the completed prefix.
6. **orchestrator/worker partition** — sever the coordinator↔worker link mid-flow: the in-flight step is neither lost nor double-run when the link heals (at-least-once activity + idempotent step ⇒ one effect). Choreography variant: a duplicated/re-ordered bus event does not double-advance the saga.
7. **observability** — trace shows every step + status; **manual unstick path** documented in `ai/runbooks/saga-recovery.md`.

Each row MUST cite the real `<test-file>::<test-name>` it ran and render that test's ACTUAL result. Scenarios 3/4/6 need fault injection (`chaos-test` skill / the engine's test framework); if that harness is absent, mark the row **UNVERIFIED (no crash/partition harness)** — never a faked PASS.

**Exactly-once-effect gate — three outcomes, no fourth.** This gate is **[self-policed]**: no shell script parses this output (there is no `validate-saga-artifacts.sh`), so the halt is only as honest as the render — its falsifiability is the cited `<test-file>::<test-name>` per row, which a reviewer (or `@resilience-reviewer` / `@workflow-orchestrator`) can open and re-run.

- **GREEN** — `scenarios_green == scenarios_required`, every row a cited real PASS → emit `## /add-saga complete`.
- **RED** — any row FAIL / unrun / cites no test → HALT, name the row, emit NOTHING but the failing row. An asserted `Tested:` checklist with no `<test-file>::<test-name>` is RED by definition.
- **INCOMPLETE** — scenarios 3/4/6 UNVERIFIED for lack of a crash/partition harness → do NOT claim production-grade; emit the INCOMPLETE block naming exactly the unverified scenarios and the harness each needs.

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
Idempotency keys: <list>   (per step + per compensation, reserve at <path:line>)
Timeouts: <per step>

Files written:
- workflow / handlers
- compensations
- tests
- ai/patterns/saga-<name>.md
- ai/decisions/<NNNN>-*.md
- ai/runbooks/saga-recovery.md

Tested (actual run — each row cites the test + renders its real result):
- happy path                                   tests/place-order.saga::happy       PASS
- failure at each step (compensation order)    …::compensation_order               PASS
- exactly-once step effect (crash-in-gap)      …::crash_between_effect_and_record  PASS | UNVERIFIED (no crash harness)
- compensation under redelivery (no double)    …::compensation_redelivered_once    PASS | UNVERIFIED (no crash harness)
- timeout at each step → halt + compensate     …::step_timeout                     PASS
- orchestrator/worker partition                …::partition_no_double_run          PASS | UNVERIFIED (no partition harness)
- observability (trace shows all steps)        …::trace_complete                   PASS
scenarios_green: <n>/<required>

Verdict: COMPLETE (production-grade) — emitted only when scenarios_green == scenarios_required with every row a cited PASS.
         INCOMPLETE — <unverified scenarios named> + the harness each needs (e.g. `chaos-test`). Functional, not exactly-once-verified.
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
- `chaos-test` skill — the fault-injection harness that turns the crash-in-gap / compensation-redelivery / partition scenarios from UNVERIFIED to GREEN.
- `@resilience-reviewer` agent — the challenge core; audit the step + compensation reserves for exactly-once effect before merge.
- `ai/patterns/idempotency.md` — the per-step atomic-reserve contract this gate enforces.
- `ai/patterns/outbox.md` — the exactly-once event emission for choreography sagas.
- `ai/patterns/event-sourcing.md` — sometimes overlapping concern.
- `@event-sourcing-architect` agent — same-pack sibling; consult for event-sourced sagas.
- `@workflow-orchestrator` agent — same-pack sibling; owns durable-workflow orchestration design + review.
