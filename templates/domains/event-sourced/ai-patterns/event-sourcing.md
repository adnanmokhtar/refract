---
name: event-sourcing
description: "Pattern: Event sourcing (aggregate → event store → projections)"
kind: ai-pattern
---

# Pattern: Event sourcing (aggregate → event store → projections)

> **Hard rule** — Event store is append-only at the DB role level; aggregates are rehydrated from events with optimistic concurrency on `(aggregate_type, aggregate_id, version)`; projectors are deterministic and idempotent. No mutation of historical events — schema evolution goes through upcasters.

**When to apply**
- Hard audit / regulatory requirement where every state change must be replayable.
- Multiple read models with different shapes derived from the same write stream.
- Temporal queries ("state as of <date>") are first-class product features.

**When NOT to apply**
- CRUD with light audit needs — use an `event_log` table next to your tables.
- Team unfamiliar with the model and no temporal/replay requirement justifying the onboarding cost.
- Dataset where storage cost of every change-history dwarfs business value.

**Halt conditions / mandatory cites**
- Cite the `event_store` schema with role-level `REVOKE UPDATE, DELETE` at `<path:line>`. Mutable event store = halt.
- Cite the optimistic-concurrency append (`WHERE version = expectedVersion`) at `<path:line>`. Last-write-wins = halt.
- Cite at least one upcaster + its test at `<path:line>` if any event has had a schema change. Inline `if (e.version === 1)` patches in projectors = halt.
- Cite a deterministic projector (no `Date.now()`, no external HTTP) at `<path:line>`. Non-deterministic projectors corrupt on replay.
- Grep ban: "we have event sourcing" without cites for store schema, append-with-version, projector, and replay command.

## When to use this pattern

Event sourcing trades simplicity for permanence + replayability. Use when:

- Audit trail is a hard requirement (regulated industry, financial reconciliation).
- Multiple read models need different shapes of the same data.
- Temporal queries are central ("show me state as of last Tuesday").
- Replay is genuinely useful for debugging or analytics.

If none of those apply, use CRUD + an `event_log` table for audit. CRUD is cheaper. This pattern earns its complexity only when you actually need it.

## Architecture

```
Command  →  CommandHandler  →  Aggregate.method()  →  emits Event(s)
                                                     ↓
                                              EventStore.append()
                                                     ↓
                                  ┌──────────────────┼──────────────────┐
                                  ↓                  ↓                  ↓
                          Projector A         Projector B         Projector C
                                  ↓                  ↓                  ↓
                         (read model A)     (read model B)     (read model C)

Query  →  QueryHandler  →  reads READ MODEL  →  returns DTO
```

Writes go through aggregates → events → store. Reads come from projections. The two sides are decoupled and run at different schemas.

## Event store schema (Postgres)

```sql
CREATE TABLE event_store (
  global_position  BIGSERIAL PRIMARY KEY,
  event_id         UUID NOT NULL UNIQUE,
  aggregate_type   TEXT NOT NULL,
  aggregate_id     UUID NOT NULL,
  version          INTEGER NOT NULL,
  event_type       TEXT NOT NULL,
  event_version    INTEGER NOT NULL DEFAULT 1,
  payload          JSONB NOT NULL,
  metadata         JSONB NOT NULL,        -- correlationId, causationId, userId, tenantId
  occurred_at      TIMESTAMPTZ NOT NULL,
  recorded_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (aggregate_type, aggregate_id, version)
);

CREATE INDEX ix_event_store_aggregate ON event_store (aggregate_type, aggregate_id, version);
CREATE INDEX ix_event_store_type      ON event_store (event_type, global_position);

REVOKE UPDATE, DELETE ON event_store FROM PUBLIC, app_role;
GRANT INSERT, SELECT ON event_store TO app_role;
```

Append-only enforced at the role level. Migrations don't touch existing rows — only add columns.

## Aggregate

```ts
// src/modules/orders/core/aggregate/order.aggregate.ts
export class Order {
  private uncommitted: DomainEvent[] = [];
  private id!: string;
  private status!: 'placed' | 'paid' | 'shipped' | 'cancelled';
  private items: OrderItem[] = [];
  private totalCents = 0;
  private version = 0;

  static rehydrate(events: DomainEvent[]): Order {
    const o = new Order();
    for (const e of events) o.when(e);
    o.version = events.length;
    return o;
  }

  // === Public commands ===
  static place(input: { id: string; tenantId: string; items: OrderItem[] }): Order {
    if (input.items.length === 0) throw new EmptyOrderError();
    const totalCents = input.items.reduce((s, i) => s + i.priceCents * i.qty, 0);
    const o = new Order();
    o.apply(new OrderPlaced({
      eventId: uuid(),
      aggregateId: input.id,
      aggregateType: 'order',
      version: 2,                 // schema version, NOT aggregate version
      occurredAt: new Date().toISOString(),
      payload: { tenantId: input.tenantId, items: input.items, totalCents },
    }));
    return o;
  }

  cancel(reason: string): void {
    if (this.status === 'shipped') throw new CannotCancelShipped();
    if (this.status === 'cancelled') return;        // idempotent
    this.apply(new OrderCancelled({
      eventId: uuid(),
      aggregateId: this.id,
      aggregateType: 'order',
      version: 1,
      occurredAt: new Date().toISOString(),
      payload: { reason },
    }));
  }

  // === Internal ===
  private apply(e: DomainEvent): void {
    this.when(e);
    this.uncommitted.push(e);
  }

  private when(e: DomainEvent): void {
    switch (e.eventType) {
      case 'OrderPlaced':
        this.id = e.aggregateId;
        this.status = 'placed';
        this.items = e.payload.items;
        this.totalCents = e.payload.totalCents;
        break;
      case 'OrderCancelled':
        this.status = 'cancelled';
        break;
      // ... future events handled here; unknown types ignored (forward-compatible)
    }
  }

  pullEvents(): { events: DomainEvent[]; expectedVersion: number } {
    const events = [...this.uncommitted];
    this.uncommitted = [];
    return { events, expectedVersion: this.version };
  }
}
```

## Command handler with optimistic concurrency

```ts
@Injectable()
export class CancelOrderCommandHandler {
  constructor(@Inject(EVENT_STORE) private store: EventStore) {}

  async execute(cmd: CancelOrderCommand): Promise<void> {
    const stream = await this.store.readStream('order', cmd.orderId);
    const order = Order.rehydrate(stream.events);

    order.cancel(cmd.reason);

    const { events, expectedVersion } = order.pullEvents();
    await this.store.appendToStream('order', cmd.orderId, expectedVersion, events, {
      correlationId: cmd.correlationId,
      causationId:   cmd.commandId,
      userId:        cmd.actorId,
    });
  }
}
```

`appendToStream` performs `INSERT ... WHERE version = expectedVersion` — concurrent edits raise `ConcurrencyError`, caller retries.

## Projector

```ts
@Injectable()
export class OrderSummaryProjector implements Projector {
  readonly name = 'order_summary';
  readonly events = ['OrderPlaced', 'OrderPlacedV2', 'OrderCancelled', 'OrderShipped'];

  constructor(@Inject(DB) private db: Pool, @Inject(UPCASTERS) private upcasters: Upcasters) {}

  async handle(event: PersistedEvent): Promise<void> {
    const e = this.upcasters.upcast(event);     // OrderPlacedV1 → V2 if needed

    await this.db.transaction(async (tx) => {
      switch (e.eventType) {
        case 'OrderPlaced':                       // includes upcasted V1
          await tx.query(`
            INSERT INTO order_summary (id, tenant_id, status, total_cents, placed_at)
            VALUES ($1, $2, 'placed', $3, $4)
            ON CONFLICT (id) DO NOTHING
          `, [e.aggregateId, e.payload.tenantId, e.payload.totalCents, e.occurredAt]);
          break;
        case 'OrderCancelled':
          await tx.query(`
            UPDATE order_summary SET status = 'cancelled', cancelled_at = $2 WHERE id = $1
          `, [e.aggregateId, e.occurredAt]);
          break;
        case 'OrderShipped':
          await tx.query(`
            UPDATE order_summary SET status = 'shipped', shipped_at = $2 WHERE id = $1
          `, [e.aggregateId, e.occurredAt]);
          break;
        default:
          logger.warn({ event: e.eventType }, 'projector_unhandled_event');
      }
      await tx.query(`
        INSERT INTO projection_state (name, last_global_position) VALUES ($1, $2)
        ON CONFLICT (name) DO UPDATE SET last_global_position = $2
      `, [this.name, e.globalPosition]);
    });
  }
}
```

Idempotent (UPSERT / `DO NOTHING` / position update). Deterministic (only event data + `occurredAt`). No external IO.

## Upcasters (schema evolution)

```ts
// src/modules/orders/core/events/upcasters/order-placed.upcaster.ts
export const upcastOrderPlaced = (e: PersistedEvent): PersistedEvent => {
  if (e.eventType !== 'OrderPlaced' || e.eventVersion >= 2) return e;
  // V1: { customerId, items, totalCents }
  // V2: { tenantId, customerId, items, totalCents } — added tenantId derived from metadata
  return {
    ...e,
    eventVersion: 2,
    payload: { ...e.payload, tenantId: e.metadata.tenantId },
  };
};
```

Pure function. Tested with property-based fixtures. Run at READ time on every event the projector receives.

## Replay

```ts
// src/modules/projections/replay.service.ts
async replay(projector: Projector, opts: { drop?: boolean } = {}): Promise<void> {
  if (opts.drop) {
    await this.db.query(`TRUNCATE ${projector.tableName}`);
    await this.db.query(`UPDATE projection_state SET last_global_position = 0 WHERE name = $1`, [projector.name]);
  }
  const startPos = await this.getPosition(projector.name);
  let processed = 0;
  for await (const event of this.store.streamFrom(startPos, { types: projector.events })) {
    await projector.handle(event);
    processed++;
    if (processed % 10_000 === 0) logger.info({ projector: projector.name, processed }, 'replay_progress');
  }
}
```

Driven by `/replay-projection` command. Used for: schema migrations, recovery, new projector backfill.

## Saga (cross-aggregate coordination)

When one event triggers actions across multiple aggregates, use a saga — NOT a transaction.

```ts
@OnEvent('OrderPlaced')
async onOrderPlaced(e: OrderPlaced): Promise<void> {
  // Reserve inventory in a different aggregate
  await this.commandBus.execute(new ReserveInventoryCommand({
    orderId: e.aggregateId,
    items: e.payload.items,
    correlationId: e.metadata.correlationId,
    causationId: e.eventId,                   // link cause
  }));
}
```

Failure of `ReserveInventory` doesn't roll back `OrderPlaced` — it emits `InventoryReservationFailed`, which a downstream saga handles (cancel order, notify customer). Eventual consistency.

## Trade-offs vs CRUD

| Concern | CRUD | Event sourced |
|---|---|---|
| Initial complexity | Low | High |
| Audit trail | Bolted on (audit table, often incomplete) | Free, complete |
| Reporting flexibility | New report = new query | New report = new projection |
| Temporal queries | Hard | Trivial |
| Schema migration | `ALTER TABLE` | New event type + upcaster (no historical mutation) |
| Storage cost | Low | Higher (every change persisted) |
| Onboarding cost | Low | High (whole team must understand it) |
| Refactoring an aggregate | Trivial (UPDATE) | Doable but careful (snapshot version + projector replay) |

If you're not sure, you don't need it.

## Anti-patterns

- Querying the event store for application reads. Read from projections.
- Mutating events post-write. Use upcasters for shape evolution.
- Cross-aggregate transactions. Use sagas.
- Projectors with external IO. Non-deterministic replay = corruption.
- `Date.now()` inside a projector. Use `event.occurredAt`.
- Renaming an event type. Old data still has the old name.
- Removing a field. Old events still have it.
- Snapshot without version. Schema change → snapshot un-replayable, full replay required.
- Skipping the replay test. CI is the only place catching schema breakage before prod.
- Event sourcing because "it's modern". The cost only pays back if you actually use the capabilities.
