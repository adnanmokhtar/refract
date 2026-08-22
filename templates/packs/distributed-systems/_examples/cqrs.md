---
name: cqrs
kind: example
pack: distributed-systems
---

# Pattern: CQRS (Command Query Responsibility Segregation)

> **Hard rule:** Commands mutate via the write model only and return no projection data; queries read from the read model only and never mutate. Crossing the boundary (queries that write, commands that return query DTOs) collapses CQRS into a more expensive CRUD.

**Halt conditions / mandatory cites**
- Each command handler MUST cite its write-model entry at `<path:line>` AND show no read-model coupling.
- Each projection MUST cite its event source AND its lag SLO (cite the dashboard or alert).
- A doc proposing CQRS for a CRUD-shaped resource without traffic data is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "reads dominate".
- If the projection-update mechanism (events, CDC, dual-write) isn't extracted, halt.

Separate write model (commands) from read model (queries). Each optimized independently.

## Shape

```
   Commands                            Queries
     │                                     │
     ▼                                     ▼
┌──────────┐    events    ┌───────────────────────┐
│  Write   │─────────────▶│  Projections / Views  │
│  Model   │              │  (read-optimized)     │
└──────────┘              └───────────────────────┘
     │                                     ▲
     ▼                                     │
Event Store ──────────────────────────────┘
```

## Why

- Writes and reads have different shapes, frequencies, consistency needs.
- Normalized write model (integrity) + denormalized read models (speed).
- Multiple read models serve different queries without distorting the write model.
- Scale reads independently (replicas, caches).

## When to use

- Read-heavy system with complex queries across multiple entities.
- Different consumers need different views of the same data.
- Paired with event sourcing naturally.

## When NOT to use

- Simple CRUD where writes and reads share the same shape.
- Small app — the complexity isn't worth it.

## Components

### Command side (writes)
- Domain model enforcing invariants.
- Normalized schema.
- Transactional consistency.
- Emits domain events.

### Query side (reads)
- Denormalized projections tailored per query.
- Materialized views OR separate read DB.
- Eventually consistent with writes.
- Can use different tech (a relational write store → a search index for full-text reads, or a wide-column / OLAP store for aggregates).

### Event bus
- Connects write model to projections.
- At-least-once delivery.
- Projections are idempotent (may receive same event twice).

## Projection examples

- **Order listing** — flat table with customer name + order total + status (denormalized).
- **Search** — Elasticsearch index with tokenized fields.
- **Analytics** — time-series aggregates updated on each event.
- **Notifications** — user's "unread" count cached per user.

## Consistency

- Write model: strongly consistent.
- Read model: eventually consistent (lag = projection lag).
- If a user immediately reads their own write and needs to see it: query write model directly (exception path).

## Rebuilding projections

- Can be destroyed + rebuilt from event log at any time.
- Versioning projections: add `v2` projection alongside `v1`, cut over when caught up.

## Forbidden

- Mixing command + query responsibilities in the same service / model.
- Projections that write back to the write model.
- Synchronous projection updates in the command's transaction (defeats the purpose).
- Reading eventually-consistent projections for strongly-consistent invariants (use write model).
