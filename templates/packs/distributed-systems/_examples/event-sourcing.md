# Pattern: Event Sourcing

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

### Aggregate
- Loaded by replaying events from the event store.
- Validates commands against current state.
- Emits new events.

```ts
class Order {
  private events: Event[] = [];
  private state: OrderState;

  static fromEvents(events: Event[]): Order {
    const o = new Order();
    events.forEach(e => o.apply(e));
    return o;
  }

  place(items: Item[]) {
    if (this.state.placed) throw new AlreadyPlacedError();
    this.apply(new OrderPlaced(this.id, items));
  }

  private apply(event: Event) {
    switch (event.type) {
      case 'OrderPlaced':
        this.state = { ...this.state, placed: true, items: event.items };
        break;
      // ...
    }
    this.events.push(event);
  }
}
```

### Event store
- Append-only table.
- Index on `aggregate_id` + `version` for loading.
- Concurrency control via `expected_version` on append (optimistic locking).

```sql
CREATE TABLE events (
  id            bigserial PRIMARY KEY,
  aggregate_id  uuid NOT NULL,
  aggregate_type text NOT NULL,
  type          text NOT NULL,
  payload       jsonb NOT NULL,
  metadata      jsonb NOT NULL,
  version       int NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (aggregate_id, version)
);
```

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
