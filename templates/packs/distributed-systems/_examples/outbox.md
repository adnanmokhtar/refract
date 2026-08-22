---
name: outbox
kind: example
pack: distributed-systems
---

# Pattern: Transactional Outbox

> **Hard rule:** Domain write and event row are inserted in the SAME database transaction; a separate relay process publishes from the outbox table with at-least-once delivery and consumer-side idempotency. Publishing directly from the request path, dual-writes across two stores, or "we'll just publish after commit" is forbidden.

**Halt conditions / mandatory cites**
- The outbox table schema MUST be cited at `<path:line>` AND its primary key + status column.
- The relay/publisher process MUST be cited (cron, CDC, polling worker) AND its at-least-once guarantee.
- A doc proposing publish-then-commit or commit-then-publish without a relay is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is atomic".
- If the consumer's idempotency key handling isn't extracted, halt — at-least-once requires consumer dedup.

Guarantees that a DB write AND an event publish happen atomically. Solves the classic "wrote to DB but crashed before publishing" bug.

## The problem

```ts
// BAD — two-step operation, no atomicity
await db.orders.insert(order);
await kafka.publish('order.placed', order);  // ← what if this fails?
```

Order saved but event never sent. Downstream consumers never see it. Classic silent data loss.

## The solution

Write the event to an **outbox table** in the SAME DB transaction as the business write. A background process reads the outbox and publishes to the message bus.

```ts
await db.transaction(async (tx) => {
  await tx.orders.insert(order);
  await tx.outbox.insert({
    topic: 'order.placed',
    payload: order,
    created_at: now(),
    published_at: null,
  });
});
```

Separately, a worker polls (or uses CDC):

```ts
// Worker loop
while (true) {
  const batch = await db.outbox
    .where('published_at IS NULL')
    .orderBy('created_at')
    .limit(100)
    .forUpdate('SKIP LOCKED');

  for (const msg of batch) {
    await bus.publish(msg.topic, msg.payload);
    await db.outbox.update(msg.id, { published_at: now() });
  }

  await sleep(1000);
}
```

## Schema

```sql
CREATE TABLE outbox (
  id         bigserial PRIMARY KEY,
  topic      text NOT NULL,
  payload    jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  attempts   int NOT NULL DEFAULT 0,
  last_error text
);
CREATE INDEX idx_outbox_pending ON outbox(created_at) WHERE published_at IS NULL;
```

## Alternatives / complements

- **CDC (Change Data Capture)** — a CDC tool (Debezium and equivalents) reads the DB's write-ahead-log / binlog and publishes to the project's message bus. No polling. Operationally heavier.
- **Event-carried state transfer** — if the event has the full entity, downstreams don't need to re-query.

## Retention

- Rows with `published_at NOT NULL` older than N days → DELETE (periodic job).
- Keep failed rows for investigation.

## Forbidden

- Publishing events outside the DB transaction.
- Reading outbox without `FOR UPDATE SKIP LOCKED` (causes duplicate publishes when multiple workers).
- Unbounded outbox growth (retention is mandatory).
- Busy-loop worker without backoff when outbox is empty.

## Consumer side

Consumers must be IDEMPOTENT — the outbox worker may publish the same event twice if it crashes between bus-publish and DB-update. Consumer dedupes by event id (unique index on `events.id`).
