---
description: Add an event handler. Idempotent / retryable / observable / DLQ-aware. Output: handler + tests + DLQ + monitoring.
---

# /add-event-handler

Add a consumer for a single event class. Smaller than a saga — one event in, side effect(s) out, idempotent.

## Phases applied

All 7.

## When to use / NOT to use

- USE: a service needs to react to an event (Kafka topic / SQS message / EventBridge rule / pub-sub message).
- USE: cross-service communication where the producer doesn't care who consumes.
- NOT: complex multi-step coordination → use `/add-saga`.
- NOT: synchronous request/response → use a regular endpoint.

## Phase 1 — Understand

- Event source: what's the producer? What schema?
- Event delivery: at-least-once (typical) / exactly-once / at-most-once?
- Side effect: what happens when this event is consumed?
- Idempotency: can the side effect run twice safely?
- Latency tolerance: must process within Xs / Xm / Xh?
- Failure mode: retry forever / DLQ after N / drop and alert?

## Phase 2 — Organize

The handler has 5 standard parts:

1. **Subscription** — register handler with broker (Kafka consumer / SQS poller / EventBridge rule / Cloud Pub/Sub subscription).
2. **Idempotency check** — was this event already processed? (idempotency key in DB / Redis).
3. **Validation** — schema check; ignore unknown event versions.
4. **Effect** — the actual work.
5. **Ack / DLQ** — on success ack; on failure retry with backoff; on max-retry → DLQ.

## Phase 3 — Retrieve

- `ai/architecture.md` — message bus topology.
- `ai/patterns/event-sourcing.md` if event-sourced.
- Existing handlers in same service — mirror their shape (logger, metrics, idempotency table name).
- Schema of the event (Avro / JSON Schema / Protobuf).

## Phase 4 — Generate

```ts
// handlers/order-created.handler.ts

import { z } from 'zod'
const OrderCreatedSchema = z.object({
  eventVersion: z.literal(1),
  orderId: z.string().uuid(),
  tenantId: z.string().uuid(),
  totalCents: z.number().int().positive(),
  occurredAt: z.string().datetime(),
})
type OrderCreated = z.infer<typeof OrderCreatedSchema>

export async function onOrderCreated(rawEvent: unknown, context: HandlerContext) {
  const tracer = context.tracer
  return tracer.startActiveSpan('handler.onOrderCreated', async span => {
    // 1. Validate
    const event = OrderCreatedSchema.parse(rawEvent)
    span.setAttribute('event.orderId', event.orderId)
    span.setAttribute('event.tenantId', event.tenantId)

    // 2. Idempotency
    const idempKey = `handler:onOrderCreated:${event.orderId}`
    const alreadyProcessed = await context.idempotency.checkAndReserve(idempKey, { ttl: '7d' })
    if (alreadyProcessed) {
      span.setAttribute('idempotent.skipped', true)
      return { status: 'skipped' }
    }

    // 3. Effect
    try {
      await context.notifications.sendOrderConfirmation({
        orderId: event.orderId,
        tenantId: event.tenantId,
      })
      await context.metrics.counter('handler.onOrderCreated.success').add(1)
      return { status: 'processed' }
    } catch (e) {
      // Distinguish retryable vs non-retryable
      if (isRetryableError(e)) {
        span.recordException(e)
        await context.idempotency.release(idempKey)  // allow retry to re-attempt
        await context.metrics.counter('handler.onOrderCreated.retryable_failure').add(1)
        throw e   // throw → broker re-delivers
      }
      // Non-retryable: log, alert, DLQ
      span.recordException(e)
      await context.metrics.counter('handler.onOrderCreated.permanent_failure').add(1)
      await context.deadLetter.publish({
        handler: 'onOrderCreated',
        event: rawEvent,
        error: e.message,
      })
      return { status: 'dead-lettered', reason: e.message }
    }
  })
}
```

Configure the broker:

```yaml
# (Kafka example via Helm / Confluent Cloud config)
consumers:
  - name: notifications-on-order-created
    topic: orders.OrderCreated.v1
    group: notifications-service
    handler: onOrderCreated
    max_retries: 3
    backoff: exponential
    backoff_base_ms: 1000
    dead_letter_topic: notifications.dlq
```

## Phase 5 — Update

- `ai/patterns/event-handlers.md` — add this handler's row to the inventory.
- `ai/architecture.md` — show the new event flow if non-trivial.
- Tests in handler test file.
- Metrics dashboard updated to include this handler's counters.
- Alert added if `handler.<name>.permanent_failure` rate exceeds threshold.

## Phase 6 — Validate

- Unit test: happy path, retryable failure, non-retryable failure, idempotency replay.
- Integration test: produce a real event; verify handler processes; verify ack to broker.
- DLQ test: produce an event that triggers non-retryable; verify it lands in DLQ.
- Idempotency test: produce same event twice; verify side effect runs once.
- Schema-version test: produce event with unknown `eventVersion`; verify graceful skip + alert.
- Replay test: re-run from earlier offset; verify idempotency holds (no duplicate effects).

## Phase 7 — Improve

- Common idempotency pattern → extract helper.
- Common DLQ replay procedure → automate via `dlq-replay` skill.
- Schema versioning conventions → propose pattern.

## Output format

```
## /add-event-handler complete

Handler: <name>
Subscribes: <topic / queue>
Side effect: <what>
Idempotency: enabled (key: <pattern>)
Retry policy: <max>, <backoff>
DLQ: <topic / queue>

Files written:
- handler
- tests
- broker config
- ai/patterns/event-handlers.md (updated)
```

## Hard rules

- **Idempotent.** Same event twice → same effect once.
- **Schema-validated.** Reject malformed events; log, don't crash.
- **Schema-version aware.** Unknown version → skip + alert; don't process.
- **Retryable errors retry; non-retryable DLQ.** Both metrics counted.
- **Observable.** Span per handler invocation; counters per outcome.
- **Bounded retry.** Eventually DLQ; never infinite retry.
- **No PII in event payload logs.** Log IDs; mask PII.

## Failure modes

- Idempotency key wrong (not actually unique per event) → effect skipped.
- Idempotency table never cleaned → unbounded growth.
- Treated all errors as retryable → poison-message stuck retrying forever.
- Treated all errors as non-retryable → transient failures lost in DLQ.
- DLQ has no replay procedure → events accumulate; never re-processed.
- Schema migration: producer ships v2; handler assumes v1 → silent skip OR crash.
- Order-dependent processing (event A must complete before event B) but no guarantee from broker.
- Handler reads from cache that hasn't propagated yet → stale state.

## Related

- `add-saga` command — when 2+ events coordinate.
- `audit-distributed-tx` command — periodic stuck-saga check.
- `dlq-replay` skill — re-process DLQ.
- `ai/patterns/event-sourcing.md` — overlapping for event-sourced systems.
