---
name: state-machine
description: "Pattern: Workflow state machine (explicit transitions, guarded, idempotent, audited)"
kind: ai-pattern
---

# Pattern: Workflow state machine (explicit transitions, guarded, idempotent, audited)

> **Hard rule** — An entity's lifecycle is driven by an EXPLICIT allowed-transition table over a closed state enum; every state change goes through ONE transition function that looks the edge up (undeclared edges throw), evaluates a GUARD against fresh state, commits the new state ATOMICALLY with an OPTIMISTIC LOCK (version / expected-from-state in the WHERE), is IDEMPOTENT on re-fire, emits side-effects TRANSACTIONALLY via an outbox (never before the commit), and writes an AUDIT row (who/when/from→to/reason) in the same transaction. Terminal states reject all transitions; waiting states carry a timeout; cross-service processes are sagas with a compensation per step.

**When to apply**
- Any entity whose `status` advances through a lifecycle: orders, payments, approvals, KYC/onboarding, fulfilment, subscriptions, tickets, claims, moderation.
- Anywhere two requests (retry, duplicate webhook, double click, two admins) can race the same entity's state.
- Any multi-step process spanning services/aggregates that must not strand the entity half-applied.

**When NOT to apply**
- A field that is set once and never transitions (a `created_at`, a soft-delete flag with no lifecycle) — a full machine is overhead.
- Pure CRUD with no ordered states and no guards between values — there's no lifecycle to model.
- Durable cross-service orchestration where a real engine (Temporal / Cadence / Step Functions) owns the workflow — use its primitives; this pattern is the in-service domain machine, not the orchestrator. See the boundary note in `<rules-path>/workflow-discipline.md`.

**Halt conditions / mandatory cites**
- Cite the state ENUM + the allowed-transition TABLE at `<path:line>`. A `status: string` with no table = halt.
- Cite the SINGLE transition function at `<path:line>`, and grep for raw `status =` / `SET status=` writes elsewhere — any writer outside it = halt.
- Cite the optimistic-lock predicate (`version` / expected-from-state in the WHERE) at `<path:line>`. A blind status overwrite = halt (lost update).
- Cite the idempotency check at `<path:line>`. A transition with no re-fire guard = halt.
- Cite the OUTBOX write inside the same transaction as the state commit at `<path:line>`. An effect fired before commit / best-effort after = halt.
- Cite the audit write at `<path:line>`. A transition with no audit row = halt.
- Grep ban: "the workflow is safe / can't double-fire / can't race" without file:line for the table, the lock, the idempotency check, and the outbox.

## Why

State machines fail in four recurring ways, every one of which corrupts the system of record rather than failing one request:

1. **Implicit transitions** — `order.status = 'shipped'` scattered across controllers. With no table, illegal edges (`draft → shipped`, `refunded → shipped`) happen because nothing forbids them, and the lifecycle is whatever the code accidentally allows.
2. **Concurrency races** — two `approve()` calls both read `pending`, both write `approved`, both run the approval effect. With no optimistic lock the second clobbers the first: lost update, split-brain state, double side-effect.
3. **Non-idempotent advances** — a retried call or a duplicate webhook advances the entity twice and charges/ships twice. The transition must be a no-op on re-fire.
4. **Non-transactional effects** — charge the card, *then* save the order: the charge succeeds and the save rolls back ⇒ money taken, order still `pending`. Or save *then* email best-effort: the process dies between ⇒ order `paid`, customer never told.

The pattern collapses all of this into ONE transition function: closed enum, declared table, guard, optimistic-locked atomic commit, idempotency, transactional outbox, audit.

## The state model: closed enum + declared transition table

```ts
// src/modules/orders/order.machine.ts

export enum OrderStatus {
  Draft           = 'draft',
  AwaitingPayment = 'awaiting_payment',
  Paid            = 'paid',
  InFulfilment    = 'in_fulfilment',
  Shipped         = 'shipped',
  Delivered       = 'delivered',
  Cancelled       = 'cancelled',     // terminal
  Refunded        = 'refunded',      // terminal
}

export type OrderEvent =
  | 'submit' | 'pay' | 'startFulfilment' | 'ship' | 'deliver' | 'cancel' | 'refund' | 'expire';

const TERMINAL = new Set<OrderStatus>([OrderStatus.Cancelled, OrderStatus.Refunded]);

/**
 * The allowed-transition table. (state, event) → to-state, with a guard + effect per edge.
 * An (state, event) pair ABSENT from this table is an ILLEGAL transition — it throws.
 * Illegal states (paid → draft) are unreachable because no edge produces them.
 */
const TABLE: TransitionTable<OrderStatus, OrderEvent, Order> = {
  [OrderStatus.Draft]: {
    submit: { to: OrderStatus.AwaitingPayment, guard: hasLineItems },
    cancel: { to: OrderStatus.Cancelled,       guard: always },
  },
  [OrderStatus.AwaitingPayment]: {
    pay:    { to: OrderStatus.Paid,      guard: paymentDue,   effect: capturePaymentEffect },
    cancel: { to: OrderStatus.Cancelled, guard: always },
    expire: { to: OrderStatus.Cancelled, guard: always,       effect: notifyExpiredEffect }, // timeout edge
  },
  [OrderStatus.Paid]: {
    startFulfilment: { to: OrderStatus.InFulfilment, guard: stockReserved, effect: reserveStockEffect },
    refund:          { to: OrderStatus.Refunded,     guard: always,        effect: refundEffect },
  },
  [OrderStatus.InFulfilment]: {
    ship:   { to: OrderStatus.Shipped,  guard: hasShipment, effect: notifyShippedEffect },
    refund: { to: OrderStatus.Refunded, guard: always,      effect: refundEffect },
  },
  [OrderStatus.Shipped]:   { deliver: { to: OrderStatus.Delivered, guard: always } },
  [OrderStatus.Delivered]: {},                 // no outgoing edges except via support flow
  [OrderStatus.Cancelled]: {},                 // terminal — zero edges
  [OrderStatus.Refunded]:  {},                 // terminal — zero edges
};
```

The table is the lifecycle. Feature code dispatches an EVENT (`pay`), never a target state — so `draft → shipped` cannot be expressed, and the same to-state reached by different events stays distinguishable in the audit trail.

## Guards: preconditions evaluated against fresh state

```ts
// src/modules/orders/order.guards.ts — each guard runs INSIDE the transaction, on freshly-read state.

export const always: Guard<Order>        = () => ok();
export const hasLineItems: Guard<Order>  = (o) => o.lineItems.length > 0 ? ok() : fail('no_line_items');
export const paymentDue: Guard<Order>    = (o) => o.amountDueMinor > 0 ? ok() : fail('nothing_due');
export const stockReserved: Guard<Order> = (o) => o.stockReservedAt != null ? ok() : fail('stock_not_reserved');
export const hasShipment: Guard<Order>   = (o) => o.shipmentId != null ? ok() : fail('no_shipment');
```

A guard returning `fail(reason)` aborts the transition before any mutation. An edge with `guard: always` is genuinely unconditional; everything else declares its precondition.

## The single transition function: atomic, optimistic-locked, idempotent, audited

```ts
// src/modules/orders/order.machine.ts (cont.)

export class OrderMachine {
  constructor(
    private readonly db: Db,
    private readonly outbox: Outbox,     // transactional outbox — effects dispatched AFTER commit by a relay
    private readonly audit: AuditLog,
  ) {}

  /**
   * THE single writer of order state. Nothing else assigns order.status.
   * Idempotent: re-firing the same event on an entity already in the target state is a no-op.
   * Concurrent-safe: the UPDATE is optimistic-locked on (status, version).
   */
  async transition(orderId: string, event: OrderEvent, ctx: ActorCtx, idemKey?: string): Promise<Order> {
    return this.db.tx(async (tx) => {
      const order = await tx.orders.findForUpdate(orderId);          // fresh read inside the tx
      const edge = TABLE[order.status]?.[event];

      // ---- Idempotency: re-fire is a no-op, not a second advance, not a false "illegal" ----
      if (!edge) {
        // Already in a state this event would have produced? Treat the retry as a no-op.
        if (alreadyApplied(order, event)) return order;             // duplicate webhook / retry
        if (TERMINAL.has(order.status)) throw new IllegalTransition(order.status, event, 'terminal');
        throw new IllegalTransition(order.status, event);           // edge not in the table
      }
      if (idemKey && await tx.transitionLog.seen(orderId, idemKey)) {
        return order;                                               // exactly-once on the idem key
      }

      // ---- Guard: precondition on fresh state, BEFORE any mutation ----
      const g = edge.guard(order, ctx);
      if (!g.ok) throw new GuardFailed(order.status, event, g.reason);

      const from = order.status;
      const to = edge.to;

      // ---- Atomic, optimistic-locked commit: expected-from-state + version in the WHERE ----
      const updated = await tx.exec(
        `UPDATE orders
            SET status = $to, version = version + 1, updated_at = now()
          WHERE id = $id AND status = $from AND version = $version`,   // <-- the optimistic lock
        { id: orderId, from, to, version: order.version },
      );
      if (updated.rowCount === 0) {
        // Someone transitioned this row between our read and our write.
        throw new ConcurrentTransition(orderId, from);              // caller re-reads + retries; never blind-overwrite
      }

      // ---- Side-effect emitted TRANSACTIONALLY (outbox row in THIS tx; relay dispatches after commit) ----
      if (edge.effect) {
        await this.outbox.enqueue(tx, {                            // same transaction as the state change
          topic: edge.effect.topic,
          payload: edge.effect.payload(order),
          dedupeKey: `${orderId}:${event}:${idemKey ?? order.version}`,  // exactly-once dispatch
        });
      }

      // ---- Audit in the SAME transaction: an advanced entity ALWAYS has a matching trail ----
      await this.audit.record(tx, {
        entity: 'order', entityId: orderId,
        event, from, to,
        actorId: ctx.actorId, actorKind: ctx.actorKind,            // 'user' | 'system' | 'webhook'
        reason: ctx.reason, correlationId: ctx.correlationId,
        at: new Date(),
      });                                                           // see <rules-path>/audit-log

      if (idemKey) await tx.transitionLog.mark(orderId, idemKey);
      return { ...order, status: to, version: order.version + 1 };
    });
  }
}

function alreadyApplied(order: Order, event: OrderEvent): boolean {
  // Map an event to the state it produces, and treat "already there" as success (idempotent retry).
  const PRODUCED: Partial<Record<OrderEvent, OrderStatus>> = {
    pay: OrderStatus.Paid, ship: OrderStatus.Shipped, deliver: OrderStatus.Delivered,
    cancel: OrderStatus.Cancelled, refund: OrderStatus.Refunded,
  };
  return PRODUCED[event] === order.status;
}
```

> The TypeScript above uses an illustrative `db.tx` / `findForUpdate` / outbox API. Substitute your project's real idiom from `.claude/_extracted-codebase.md` — the ORM's transaction wrapper, its optimistic-lock mechanism (a `@Version` column, a `WHERE updated_at = ?`, or `SELECT … FOR UPDATE`), and your outbox/after-commit hook. The SHAPE is universal: table lookup → idempotency → guard → optimistic-locked UPDATE → outbox-in-tx → audit-in-tx. The specific helper names are not.

The commit is atomic, the lock makes concurrent transitions safe (zero rows ⇒ abort, never overwrite), the re-fire is a no-op, the effect rides the outbox in the same transaction, and the audit row is written before commit.

## Why the optimistic lock (the concurrency race, concretely)

```text
T1: read order (status=awaiting_payment, version=7)   T2: read order (status=awaiting_payment, version=7)
T1: guard ok                                          T2: guard ok
T1: UPDATE … WHERE status='awaiting_payment' v=7  →1  T2: UPDATE … WHERE status='awaiting_payment' v=7  →0 rows
T1: commit  (status=paid, version=8, capture queued)  T2: rowCount===0 → ConcurrentTransition → abort, re-read
```

Without `AND version = $version`, T2's write also succeeds: the order is "paid" once but the capture effect is enqueued twice (double charge) and one of the two writers' audit rows lies. The lock is what makes "exactly one transition wins" true.

## Side-effects: outbox, not best-effort

```ts
// src/modules/_shared/outbox.relay.ts — dispatches outbox rows AFTER the state commit, exactly once.

@Cron('*/2 * * * * *')   // or driven by CDC / LISTEN-NOTIFY
async drain(): Promise<void> {
  const batch = await this.db.outbox.claimUndispatched(100);     // rows committed alongside their state change
  for (const row of batch) {
    try {
      await this.dispatch(row.topic, row.payload, row.dedupeKey); // handler is idempotent on dedupeKey
      await this.db.outbox.markDispatched(row.id);
    } catch (e) {
      await this.db.outbox.markFailed(row.id, e);                 // retried; eventually DLQ — see <rules-path>/background-jobs
    }
  }
}
```

The effect row is committed in the SAME transaction as the state change, so there is never an effect without a state or a state without a (will-eventually-fire) effect. The relay's at-least-once delivery + the handler's `dedupeKey` idempotency give exactly-once application.

## Terminal states and stuck-state timeout / escalation

```ts
// src/modules/orders/order.sweeper.ts — every WAITING state has a deadline; a sweep fires the timeout edge.

@Cron('*/5 * * * *')
async expireStaleAwaitingPayment(): Promise<void> {
  const stale = await this.db.orders.find({
    status: OrderStatus.AwaitingPayment,
    updatedBefore: subHours(new Date(), 24),                      // the state's deadline
  });
  for (const o of stale) {
    // The timeout is itself a transition through the SAME machine — guarded, locked, audited.
    await this.machine.transition(o.id, 'expire', { actorKind: 'system', reason: 'awaiting_payment_timeout' })
      .catch(swallowConcurrent);                                  // a concurrent pay() may have won; that's fine
  }
}
```

Terminal states (`Cancelled`, `Refunded`) have zero outgoing edges in the table, so the function refuses every event on them. Non-terminal waiting states each get a sweep + a timeout edge (`expire`, `escalate`) so nothing sits half-done forever.

## Multi-step process: saga with compensation

```ts
// src/modules/orders/place-order.saga.ts — cross-service process; every forward step has a compensation.

const PLACE_ORDER_SAGA: SagaStep<PlaceOrderCtx>[] = [
  { do: reserveStock,    undo: releaseStock },
  { do: capturePayment,  undo: refundPayment },
  { do: createShipment,  undo: cancelShipment },
];

async function runSaga<C>(steps: SagaStep<C>[], ctx: C): Promise<void> {
  const done: SagaStep<C>[] = [];
  try {
    for (const step of steps) { await step.do(ctx); done.push(step); }
  } catch (err) {
    // Roll back in REVERSE — release stock, refund payment, cancel shipment. Never strand half-applied.
    for (const step of done.reverse()) {
      await step.undo(ctx).catch((e) => alertCompensationFailed(step, ctx, e)); // compensation is itself idempotent
    }
    await machine.transition(ctx.orderId, 'cancel', { actorKind: 'system', reason: `saga_failed:${err.code}` });
    throw err;
  }
}
```

If `createShipment` fails, `refundPayment` then `releaseStock` run in reverse and the order transitions to a clean terminal state. There is no path that leaves stock reserved and payment captured with no order.

## Typed states: make the illegal unrepresentable (optional, where the language allows)

```ts
// A discriminated union carries ONLY the data valid in that state — `Shipped` cannot exist without a trackingId.

type Order =
  | { status: 'draft';            lineItems: Line[] }
  | { status: 'awaiting_payment'; lineItems: Line[]; amountDueMinor: number }
  | { status: 'paid';             paidAt: Date; paymentId: string }
  | { status: 'shipped';          paidAt: Date; shippedAt: Date; trackingId: string }
  | { status: 'cancelled';        cancelledAt: Date; reason: string };
// `{ status: 'shipped' }` without trackingId won't compile — the type system enforces the invariant.
```

## Common mistakes

### Implicit transition
`order.status = 'shipped'; await order.save()` in a controller — no table, no guard, no lock, no audit, and `draft → shipped` is suddenly legal. Route through `machine.transition(id, 'ship', ctx)`.

### Stringly-typed state
`status: string` drifting into `'canceled'` vs `'cancelled'` vs `'CANCELLED'`. Closed enum + table; anything off the table throws.

### Guardless transition
`ship()` flips to `shipped` without checking payment captured / stock reserved. Declare a `hasShipment` / `stockReserved` guard that runs inside the tx.

### Lost update
Two `approve()` calls both read `pending`, both write `approved`, the approval effect runs twice. Optimistic lock: `WHERE status='pending' AND version=$v`; zero rows ⇒ `ConcurrentTransition` ⇒ abort.

### Non-idempotent transition
A duplicate webhook fires `pay()` twice → order advances twice, card charged twice. `alreadyApplied` / `idemKey` make the re-fire a no-op.

### Effect before commit
`await stripe.capture(); order.status='paid'; await save()` → capture succeeds, save throws → money taken, order `pending`. Enqueue the capture on the outbox in the same tx; dispatch after commit.

### State without effect
`await save(); await email.send()` → save commits, process dies → order `paid`, customer never told. Outbox + relay guarantees the effect eventually fires exactly once.

### No audit
Status flips with no record of who/why → a disputed cancellation has no trail. Write the audit row in the same transaction.

### No terminal handling
The table has an edge out of `refunded`, so `ship` after `refund` is accepted. Terminal states have zero outgoing edges.

### Stuck forever
Orders enter `awaiting_payment` and nothing ever expires them; the table fills with zombies. Every waiting state needs a sweep + a timeout edge.

### Saga with no compensation
`reserveStock` + `capturePayment` succeed, `createShipment` fails, nothing rolls back → stock reserved + money captured + no order. Declare an `undo` per step; run them in reverse.

## Cross-references

- `<rules-path>/workflow-discipline.md` — the hard-rule list (explicit table, single writer, guard, optimistic lock, idempotency, transactional outbox, audit, terminal/stuck, saga).
- `<rules-path>/audit-log` — every transition is an audited event; who/when/from→to/reason recorded in the same transaction as the state change.
- `<rules-path>/background-jobs` — the outbox relay (after-commit dispatch) and the scheduled sweep that fires timeout / escalation transitions on stuck states.
- `<patterns-path>/event-sourced` — event-driven lifecycle where state is a fold over an append-only event log and transitions ARE events; the audit trail is the event stream.
- `<commands-path>/audit-state-machine.md` — locate the status field + transitions and verdict the table / guard / lock / idempotency / side-effect-ordering / audit / terminal axes.
- `<agents-path>/workflow-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-workflow-state-model.md` — ADR pinning the state model, concurrency strategy, and saga/compensation approach.
- **Boundary**: this is the APP-LEVEL domain state machine inside your service — distinct from the cataloged `workflow-orchestration` domain (Temporal / Cadence / Step Functions durable-execution infra), which owns cross-service workflow durability rather than a single entity's lifecycle.
