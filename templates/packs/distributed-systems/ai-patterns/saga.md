---
name: saga
description: Pattern: Saga
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Saga

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

## Shape (orchestrated)

```ts
class PlaceOrderSaga {
  async execute(orderId: string) {
    try {
      const reservation = await inventory.reserve(orderId);
      try {
        const charge = await payments.charge(orderId);
        try {
          await shipments.create(orderId);
        } catch (e) {
          await payments.refund(charge.id);    // compensate
          throw e;
        }
      } catch (e) {
        await inventory.release(reservation.id); // compensate
        throw e;
      }
    } catch (e) {
      await orders.markFailed(orderId, e);
      throw e;
    }
  }
}
```

Saga state persisted at each step (Postgres / dedicated table) so crashes resume correctly.

## Compensations

- Every forward action has a reverse action. Document them per saga.
- Compensations must be idempotent (run may happen twice).
- Some actions are not reversible (sent an email, made a physical shipment) — design so those are LAST, or explicitly accept non-compensation.

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
