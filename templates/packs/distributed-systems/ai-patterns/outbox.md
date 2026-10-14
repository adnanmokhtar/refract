---
name: outbox
description: "Pattern: Transactional Outbox"
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

Separately, a relay polls (or uses CDC). **It never holds a row lock or an open transaction while it talks to the broker** — that is external I/O inside a transaction (database `transaction-scan` § 1's class): the locks and the connection are held for as long as the broker is slow.

1. **Claim, then commit.** In a short transaction, claim up to N unpublished rows in id order and mark them claimed — `UPDATE outbox SET claimed_at = now(), claimed_by = :relay WHERE id IN (SELECT id FROM outbox WHERE published_at IS NULL AND (claimed_at IS NULL OR claimed_at < now() - :lease) ORDER BY id LIMIT :n FOR UPDATE SKIP LOCKED) RETURNING *` — and commit. The lease lets another relay take over rows whose claimer died.
2. **Publish outside any transaction**, in id order, awaiting the broker's confirm for each row.
3. **Mark after the confirm** — `UPDATE outbox SET published_at = now() WHERE id = :id AND claimed_by = :relay`. A crash between publish and mark republishes the row: at-least-once is correct, and consumers dedupe (precedents § 12 in `precedents/distributed.md`).
4. Sleep briefly between batches (back off when empty).

**Order.** Several relays claiming with `SKIP LOCKED`, or one relay publishing a batch in parallel, reorder events of the same aggregate. When a consumer needs per-aggregate order (a state machine, a balance, last-write semantics), run **one relay per ordering key** (a single leader, or relays partitioned by `hash(aggregate_id)`), publish with the aggregate id as the message key, or carry a per-aggregate sequence the consumer checks. Commutative events do not care.

**Gap-blind cursors.** A relay or consumer that advances `WHERE id > :last` over a sequence that concurrent transactions draw skips a row that commits late below the cursor (transaction A holds id 10 while B commits 11). It is safe with one serial writer or a log-ordered source (CDC); otherwise hold the floor back by a lag longer than the longest transaction and rescan periodically.

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
- Claiming outbox rows without `SKIP LOCKED` or a claim column (two relays publish the same rows).
- Holding the claim's row locks or transaction open while publishing.
- Marking a row published before the broker confirmed it (a crash loses the event).
- Parallel relays or parallel publishes over events whose consumers need per-aggregate order.
- Unbounded outbox growth (retention is mandatory).
- Busy-loop worker without backoff when outbox is empty.

## Detectors

Run by the distributed-systems pack's `dual-write-scan`; this pattern is the contract it checks against.

- **Commit, then publish with no outbox** (or an outbox write outside the business transaction) — `dual-write-scan` § 1 (DW-1). Proof: V300 (kill between commit and publish → the event still arrives once).
- **The relay** — no order, parallel publish, mark before confirm, locks held across the publish, no pruning — `dual-write-scan` § 3 (DW-4). Proof: V301.
- **A gap-blind catch-up cursor** — `dual-write-scan` § 6. Proof: V301, gap variant.
- Publish or enqueue **inside** the transaction is database `transaction-scan` § 1 (V8); a claim without `SKIP LOCKED` is database § 5 — when that pack is installed.

## Consumer side

Consumers must be IDEMPOTENT — the outbox worker may publish the same event twice if it crashes between bus-publish and DB-update. Consumer dedupes by event id: a unique row inserted in the same transaction as its effect (`idempotency.md` § Dedup by event id, within the business write).

## Related

- `reconciliation` — outbox is the *fix* for dual-write divergence (write once transactionally, relay to the copy); reconciliation is the safety-net audit where a dual-write still exists, periodically diffing the two stores and repairing the loser toward the source of truth.
