---
name: event-sourcing
description: Pattern: Event Sourcing
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Event Sourcing

> **Hard rule:** State is derived by replaying an append-only event log; the event store is the source of truth. Mutating past events, deleting events, or reconstructing state from a current-state snapshot without replay parity is forbidden.

**When to apply**
- Audit trail / temporal queries are a hard product requirement (finance, healthcare, compliance).
- You need replayable projections to add new read shapes without backfilling from a relational DB.
- Domain experts already think in events ("OrderPlaced", "PaymentCaptured") — the model fits.

**When NOT to apply**
- A simple CRUD service where current state is enough and audit needs are met by a change-log column.
- The team has no operational maturity for replays, snapshots, schema evolution — defer until those exist.

**Halt conditions / mandatory cites**
- Every event type MUST cite its schema file at `<path:line>` AND its version field.
- Every projection MUST cite the event types it consumes AND its rebuild procedure.
- A doc proposing schema migration via mutation of past events is a bug — reject; use upcasters.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "all writes go through events".
- If the event-store technology + snapshot strategy isn't extracted, halt.

Persist every state change as an immutable event. Current state is derived by replaying events.

## When to use

- Audit trail is a hard requirement (financial, healthcare, compliance).
- You want time-travel / temporal queries ("what did the cart look like yesterday at 3pm?").
- Multiple read models from the same writes (CQRS).
- Event-driven architecture is already the shape of the system.

## When NOT to use

- Simple CRUD with no compliance / temporal needs (overkill).
- Small team without DDD experience (steep learning curve).
- Domain doesn't naturally think in events.

## Shape

```
Command → Aggregate → Event → Event Store → Projections (read models)
```

### Events
- Past-tense. `OrderPlaced`, not `PlaceOrder`.
- Immutable. Never edit a published event.
- Versioned. Schema evolution requires upcasters.
- Self-describing. Include all context needed to replay.

### Aggregate (stack-agnostic shape)
- Loaded by replaying events from the event store.
- Validates commands against current state.
- Emits new events.

The aggregate has:
- A `fromEvents(events)` factory that replays events to rebuild state.
- Public command methods (e.g., `place(items)`) that check invariants and append a new event.
- A private `apply(event)` method that dispatches on event type and mutates state.

### Event store (stack-agnostic schema)
- Append-only table.
- Index on `aggregate_id` + `version` for loading.
- Concurrency control via `expected_version` on append (optimistic locking).

Required columns: `id` (sequential), `aggregate_id` (UUID/identifier), `aggregate_type`, event `type`, `payload` (the project's JSON / structured-data column type), `metadata` (correlation id / causation id / tenant), `version` (int), `created_at` (timestamp). Unique constraint on `(aggregate_id, version)` for optimistic locking.

### Projections
- Derived read models built by consuming events.
- Can be rebuilt from scratch by replaying.
- Eventually consistent with the event store.

## Snapshots

- For aggregates with long event streams, periodically snapshot state.
- On load: fetch latest snapshot + events after it.

## Complications

- **Schema evolution**: events are forever. Write upcasters to transform old events to new shapes.
- **GDPR delete requests**: you can't just delete events. Options: crypto-shredding (delete encryption key), retained event with redacted payload.
- **Debugging**: replay is a superpower but requires good tooling.

## Forbidden

- Editing published events.
- Events that reference current-state (break replay).
- Ad-hoc queries against event store in the hot path (use projections).
- Event sourcing without projections (you'll rebuild state on every read — slow).
