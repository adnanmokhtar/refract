---
description: Implement a saga (orchestration / choreography) for a multi-step distributed transaction with compensations. Outputs the state machine + compensations + idempotency + retry + observability.
---

# /add-saga

Add a saga when a business transaction spans 2+ services AND can't be a single atomic DB transaction. Distributed transactions need explicit state, retries, and compensations.

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

Orchestration tools: Temporal (preferred — durable execution), AWS Step Functions, Azure Durable Functions, Camunda Zeebe, Cadence.

Choreography: just events on a bus (Kafka / RabbitMQ / SQS / EventBridge) + per-service handlers.

## Phase 3 — Retrieve

- `ai/architecture.md` — service boundaries.
- `ai/patterns/event-sourcing.md` if event-sourced.
- `ai/decisions/` for past saga choices.
- Existing saga state machines in code (mirror their style).

## Phase 4 — Generate

### Orchestration (Temporal example)

```ts
// place-order.workflow.ts
import { proxyActivities } from '@temporalio/workflow'

const { reserveInventory, chargePayment, scheduleShipping, sendConfirmation,
        releaseInventory, refundPayment, cancelShipping }
  = proxyActivities<typeof activities>({
    startToCloseTimeout: '30s',
    retry: { maximumAttempts: 3 }
  })

export async function placeOrderWorkflow(input: OrderInput): Promise<OrderResult> {
  const { orderId, lineItems, paymentMethodId, shippingAddress } = input

  // Step 1: reserve inventory
  let inventoryReserved = false
  try {
    await reserveInventory(orderId, lineItems)
    inventoryReserved = true
  } catch (e) {
    return { status: 'failed', step: 'reserveInventory', reason: e.message }
  }

  // Step 2: charge payment
  let payment = null
  try {
    payment = await chargePayment(orderId, paymentMethodId)
  } catch (e) {
    if (inventoryReserved) await releaseInventory(orderId, lineItems)
    return { status: 'failed', step: 'chargePayment', reason: e.message }
  }

  // Step 3: schedule shipping
  let shipping = null
  try {
    shipping = await scheduleShipping(orderId, shippingAddress)
  } catch (e) {
    await refundPayment(payment.id)
    if (inventoryReserved) await releaseInventory(orderId, lineItems)
    return { status: 'failed', step: 'scheduleShipping', reason: e.message }
  }

  // Step 4: send confirmation (best-effort; not in critical path)
  await sendConfirmation(orderId)
    .catch(e => { /* log; don't compensate; user can re-trigger */ })

  return {
    status: 'completed',
    orderId,
    paymentId: payment.id,
    shippingId: shipping.id,
  }
}
```

### Choreography (events example)

```ts
// inventory-service: handles OrderRequested
async function onOrderRequested(event: OrderRequested) {
  try {
    await reserveInventory(event.orderId, event.lineItems)
    await publish('InventoryReserved', { orderId: event.orderId })
  } catch (e) {
    await publish('InventoryReservationFailed', { orderId: event.orderId, reason: e.message })
  }
}

// payment-service: handles InventoryReserved
async function onInventoryReserved(event: InventoryReserved) {
  try {
    const payment = await chargePayment(event.orderId)
    await publish('PaymentSucceeded', { orderId: event.orderId, paymentId: payment.id })
  } catch (e) {
    await publish('PaymentFailed', { orderId: event.orderId, reason: e.message })
    // inventory-service listens for PaymentFailed and compensates
  }
}

// inventory-service: handles PaymentFailed (compensation)
async function onPaymentFailed(event: PaymentFailed) {
  await releaseInventory(event.orderId)
  await publish('InventoryReleased', { orderId: event.orderId })
}
```

### Common requirements (BOTH patterns)

- **Idempotency** — every step has an idempotency key (typically the orderId + step name). Re-submission produces same effect.
- **Retry** — transient failures retry with backoff; non-transient (4xx) don't.
- **Timeout** — every step has a max time; saga halts and compensates if exceeded.
- **Observability** — saga state visible at every step; trace ID propagates across services.
- **Persistence** — saga state durable across crashes (Temporal handles; choreography needs explicit ledger).
- **Compensations** — per step, the inverse operation defined. Compensations are themselves idempotent.
- **Failure surfaces** — user-facing message on failure (don't silently retry forever).

## Phase 5 — Update

- `ai/patterns/saga-<feature>.md` — pattern doc for THIS saga.
- `ai/decisions/<NNNN>-saga-<feature>.md` — orchestration vs choreography choice + rationale.
- `ai/runbooks/saga-recovery.md` — runbook for stuck sagas (manual unstick steps).
- Code: workflow file + activity files + tests.

## Phase 6 — Validate

- Happy path: all steps succeed.
- Failure at each step: verify correct compensation order.
- Idempotent retry: re-run same input twice → same final state.
- Timeout at each step: saga halts + compensates.
- Crash recovery: kill the worker mid-flow; saga resumes from last persisted state (Temporal: automatic; choreography: harder — requires careful design).
- Observability: trace shows all steps + status.
- Manual unstick path: documented.

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

Tested:
- happy path
- failure at each step (compensation correctness)
- timeout
- crash + resume
```

## Hard rules

- **Every step idempotent.** Same input + same effect on retry.
- **Every step has compensation OR is documented as fire-and-forget acceptable.**
- **Every step has timeout.** No unbounded waits.
- **Saga state durable across crashes.** Temporal / Step Functions / event ledger.
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
- `@event-sourcing-architect` agent (if pack has it).
