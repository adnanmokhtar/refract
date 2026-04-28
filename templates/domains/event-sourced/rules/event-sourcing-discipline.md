---
name: event-sourcing-discipline
description: Events
kind: rule
---

### Event sourcing discipline

Event store data is permanent. Every shortcut today is paid back forever. These rules keep the store usable past the first schema change.

## Events

- Events are IMMUTABLE — `readonly` fields, no setters, no `Object.assign` post-construction. `Object.freeze` in test if needed to enforce.
- Names are PAST TENSE + aggregate-prefixed: `OrderPlaced`, `PaymentCaptured`, `InventoryReserved`. Never `PlaceOrder` (that's a command) or `OrderUpdated` (too vague — what was updated?).
- Every event carries: `eventId` (uuid), `aggregateId`, `aggregateType`, `version` (event schema version), `occurredAt` (ISO ns), `correlationId`, `causationId`, `payload`.
- Event payload is SELF-CONTAINED. Projector should never need to read external state to interpret.
- Events MUST NOT cross aggregate boundaries — one event belongs to exactly one aggregate's stream.

## Schema evolution

- Breaking shape change = NEW event type (`OrderPlaced` → `OrderPlacedV2`). The original is kept FOREVER.
- Additive change (new optional field) = same type, bump `version`, projector tolerates missing field on old events.
- Field RENAME = never in source. Add a NEW field; deprecate old; upcaster maps at read time.
- Field REMOVAL = never. Mark deprecated; projectors ignore. Old events still have it.
- Upcasters live in `core/events/upcasters/` and are PURE + DETERMINISTIC + TESTED. Property-based test on every upcast.

## Aggregates

- Aggregate state mutates ONLY via `when(event)` handlers. No setters that bypass event emission.
- Public methods (`Order.place(...)`, `Order.cancel()`) check invariants → emit event → `apply(event)` → state changes via `when`.
- Optimistic concurrency: aggregate carries `version`, append checks `expectedVersion === currentVersion` else `ConcurrencyError`. Caller retries.
- One command = one aggregate transaction. Cross-aggregate coordination = saga / process manager (eventually consistent).
- Snapshot every N events (typical N=100). Snapshot stored with schema version. Schema change to snapshot = bump version + replay from events past last compatible snapshot.

## Event store

- APPEND-ONLY. Database `REVOKE UPDATE, DELETE` on event store table. Migrations enforce.
- Atomic per-aggregate write: all events from one command persisted in one transaction with version check.
- Global ordering via monotonic `global_position` column (sequence / serial). Projectors stream by it.
- Stream-per-aggregate via `(aggregate_type, aggregate_id, version)` unique constraint.
- Storage: typed JSONB payload + denormalized indexable columns (aggregate_id, type, occurred_at).

## Projections

- Projector is IDEMPOTENT — replaying any event N times yields the same final state. Use UPSERT not INSERT.
- Projector is DETERMINISTIC — no `now()`, no `random()`, no external IO. Use `event.occurredAt` instead of clock.
- Projector handles unknown event types gracefully (log + skip). Don't crash on a future event type.
- Projector tracks `last_event_id` (or `last_global_position`) in a `projection_state` table.
- Each projection update wrapped in a transaction with position update — atomic catchup. Crash mid-batch resumes from last committed position.
- Projector reads NEVER touch the event store directly. Read models exist for reads; events for writes.

## Queries

- Application reads from projections, NEVER from event store.
- Direct `eventStore.readStream(...)` in a query handler = BLOCKER. Replay rehydration is for write-side aggregate loading only.
- Reports = projections. Denormalize for the question being asked.
- Live data (carts, in-flight orders) = projection updated by streaming projector with low lag.

## Replay

- Every projector has a replay test in CI: load fixture event stream → drop projection → replay → assert final state matches.
- Replay is the disaster-recovery primitive. If your projection corrupts, you must be able to rebuild from events. If you can't, the design is broken.
- Catchup time measured + budgeted per projection ("rebuilding `orders_summary` from 10M events: 12 min").
- Snapshot replay tested (snapshot @ v100 + events v101-v150 → same as replay v1-v150).

## Correlation + causation

- `correlationId` propagates from inbound request through every event in the chain.
- `causationId` = id of the previous event (or command) that caused this event. Walking causation gives the cause graph.
- Both surfaced in structured logs. Without them, distributed debugging is impossible.

## Forbidden

- `UPDATE event_store SET ...` — anywhere, ever. Schema-revoke enforces.
- `DELETE FROM event_store WHERE ...` — including "GDPR delete". Use crypto-shredding (encrypt PII payloads with per-subject keys; "delete" = drop the key).
- Mutating an event in a projector or anywhere downstream.
- Reading the event store from a query path.
- A projector that calls an external API (non-deterministic).
- Cross-aggregate atomic transaction.
- Reusing an event type name for a different shape.
- Snapshots without schema version.

## When NOT to use event sourcing

These rules sound expensive because event sourcing IS expensive. Default to CRUD + audit log unless you have a specific reason:

- Audit / compliance trail is a hard requirement (regulated industry).
- Replay-derived read models materially simplify the model (reporting-heavy domain).
- Temporal queries are core ("show me orders as of last Tuesday").
- Multiple read models need different shapes of the same data.

If none apply, use CRUD with an `event_log` table for audit. You'll save weeks.
