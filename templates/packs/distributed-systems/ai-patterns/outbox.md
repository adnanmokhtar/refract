---
name: outbox
description: Pattern: Transactional Outbox
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Transactional Outbox

> **Hard rule:** Domain write and event row are inserted in the SAME database transaction; a separate relay process publishes from the outbox table with at-least-once delivery and consumer-side idempotency. Publishing directly from the request path, dual-writes across two stores, or "we'll just publish after commit" is forbidden.

**When to apply**
- A write must produce an event consumed by another service or projection.
- You need at-least-once delivery and atomicity between DB state and the published event.
- Existing dual-writes have caused drift between DB state and the message bus.

**When NOT to apply**
- Single-process system where the consumer reads from the same DB — query directly.
- A use-case where lossy fire-and-forget is acceptable (analytics breadcrumbs, soft signals).

**Halt conditions / mandatory cites**
- The outbox table schema MUST be cited at `<path:line>` AND its primary key + status column.
- The relay/publisher process MUST be cited (cron, CDC, polling worker) AND its at-least-once guarantee.
- A doc proposing publish-then-commit or commit-then-publish without a relay is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is atomic".
- If the consumer's idempotency key handling isn't extracted, halt — at-least-once requires consumer dedup.

Guarantees that a DB write AND an event publish happen atomically. Solves the classic "wrote to DB but crashed before publishing" bug.

## The problem

The naive two-step "insert business row, then publish to message bus" is NOT atomic. If the publish fails (network blip, broker down) the row is saved but the event is never sent — downstream consumers never see it. Classic silent data loss.

## The solution

Write the event to an **outbox table** in the SAME DB transaction as the business write. A background process reads the outbox and publishes to the message bus.

Inside one DB transaction: insert the business row AND insert a row into `outbox` (topic, payload, created_at, published_at = null). Both rows commit together or both rollback.

Separately, a worker polls (or uses CDC):

1. Select up to N unpublished outbox rows (`WHERE published_at IS NULL`), ordered by `created_at`, locked `FOR UPDATE SKIP LOCKED` so multiple workers don't process the same rows.
2. For each row: publish to the message bus, then update `published_at = now()`.
3. Sleep briefly between batches (back off when empty).

## Schema (stack-agnostic)

`outbox` table with columns: `id` (PK, sequential), `topic` (string), `payload` (the project's JSON / structured-data column type), `created_at` (timestamp), `published_at` (timestamp, nullable), `attempts` (int, default 0), `last_error` (string, nullable). Partial index on `created_at` filtered to `published_at IS NULL` for fast scan.

## Alternatives / complements

- **CDC (Change Data Capture)** — a CDC tool (e.g., Debezium for Postgres/MySQL/MongoDB, the equivalent for the project's DB) reads the DB's write-ahead-log / binlog and publishes to the message bus. No polling. Operationally heavier.
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

## Related

- `reconciliation` — outbox is the *fix* for dual-write divergence (write once transactionally, relay to the copy); reconciliation is the safety-net audit where a dual-write still exists, periodically diffing the two stores and repairing the loser toward the source of truth.
