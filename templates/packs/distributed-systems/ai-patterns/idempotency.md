---
name: idempotency
description: Pattern: Idempotency
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Idempotency

"Running twice = running once." Foundation for retries, webhooks, sagas, event consumers, payments.

## Why it matters

Networks fail. Clients retry. Without idempotency:
- Duplicate orders.
- Double charges.
- Phantom inventory decrements.
- Event handlers fire twice → duplicate side effects.

## Idempotent operations by type

### HTTP methods (RFC 7231)
- **GET** — idempotent by definition. No side effects.
- **PUT** — idempotent. Full replace.
- **DELETE** — idempotent. Deleting an already-deleted thing is a no-op (200 / 204, not 404).
- **HEAD, OPTIONS** — idempotent.
- **POST** — NOT idempotent by default. Make it idempotent via idempotency keys.
- **PATCH** — NOT guaranteed. Depends on semantics (increment = not idempotent; set-if-match = idempotent).

### At the DB level
- `INSERT ... ON CONFLICT (k) DO NOTHING` — idempotent insert.
- `INSERT ... ON CONFLICT (k) DO UPDATE SET ...` — idempotent upsert.
- `DELETE WHERE id = ?` — idempotent.
- `UPDATE ... SET status = 'X' WHERE id = ? AND status != 'X'` — idempotent "set once".

## Idempotency keys (client-supplied)

Client generates a unique key (UUID) per logical operation. Sends it on retries.

```
POST /orders
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

Server stores first response by key. Subsequent requests with same key return stored response without re-executing.

### Server-side storage

```sql
CREATE TABLE idempotency_records (
  key             text PRIMARY KEY,
  request_hash    text NOT NULL,        -- prevents key reuse with different body
  response_body   jsonb NOT NULL,
  response_status int NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz NOT NULL  -- TTL, typically 24h
);

CREATE INDEX idx_idempotency_expires ON idempotency_records(expires_at);
```

Flow:
```
1. Receive request with Idempotency-Key.
2. Lock on key (advisory lock or SELECT FOR UPDATE).
3. Check idempotency_records:
   - Found + same hash → return stored response. Done.
   - Found + different hash → 409 Conflict (client bug: key reused with different body).
   - Not found → continue.
4. Execute the request.
5. Store result + key + hash + TTL.
6. Release lock.
7. Return response.
```

### Concurrency concerns

- TWO requests with same key arrive concurrently: locking ensures one runs, other waits.
- Crash mid-execution: on retry, step 3 finds the key (if you stored the START before executing) OR not (if you stored only on success). Design per use case.
- Recommended: write the key in a PENDING state, then UPDATE to final state. On retry, PENDING means "wait or rerun carefully".

## Event handlers (consumer-side idempotency)

Messages may be delivered multiple times (at-least-once delivery).

### Dedup by event id
```sql
CREATE TABLE processed_events (
  event_id   text PRIMARY KEY,
  processed_at timestamptz DEFAULT now()
);
```

Handler:
```ts
async function handle(event) {
  try {
    await db.processed_events.insert({ event_id: event.id });
  } catch (e) {
    if (isDuplicateKey(e)) return; // already processed
    throw e;
  }
  // do the work
}
```

### Dedup within the business write
Combine the processing write + event id in one transaction:
```ts
await db.transaction(async tx => {
  await tx.processed_events.insert({ event_id });   // fails if duplicate
  await tx.orders.update({ id: orderId, status: 'paid' });
});
```

## Payment / financial operations

Stripe, most payment APIs, require idempotency keys on creates. Use them.

```ts
await stripe.charges.create(
  { amount: 1000, currency: 'usd', customer: c },
  { idempotencyKey: orderId }          // Stripe dedupes on their side
);
```

Your side: same idempotency pattern for your internal state changes.

## Idempotent operation design

Prefer operations where repetition is NATURALLY idempotent:

### SET rather than INCREMENT
```
BAD: await counter.increment(5);     // 2 runs = 10
GOOD: await counter.setToAtLeast(currentValue + 5, via CAS);
```

### Upsert rather than insert
```
BAD: INSERT INTO users ...;            // 2 runs = duplicate row error
GOOD: INSERT INTO users ... ON CONFLICT DO UPDATE;
```

### State transitions with preconditions
```
BAD: UPDATE orders SET status='paid' WHERE id = ?;   // re-runs overwrite, no safety
GOOD: UPDATE orders SET status='paid', paid_at=now()
      WHERE id = ? AND status = 'pending';           // only if expected state
      -- returns 0 rows if already paid; caller knows to skip
```

## Retry safety

Retries are safe IF the operation is idempotent. Never retry a non-idempotent POST without an idempotency key.

```ts
// Safe — idempotency key carried on every retry
await retry(() => api.post('/orders', body, { headers: { 'Idempotency-Key': key }}), {
  retries: 3,
  backoff: exponential,
});
```

## Observability

- Log idempotency key on every request.
- Metric: `idempotent_replay_total` (how often retries hit).
- Trace spans include `idempotency.replay = true/false`.

## Storage retention

- TTL on idempotency records: 24-48h typical.
- Longer for payments (90 days matches most provider policies).
- Vacuum old records (a periodic job).

## Forbidden

- POST / PATCH endpoints that modify state without an Idempotency-Key option.
- Retries of non-idempotent operations without keys.
- Storing idempotency records forever (unbounded growth).
- Ignoring the hash check — letting a client reuse a key with a different body silently (hides bugs).
- Idempotency via "check if it exists, then create" without locking (classic race).
- Incrementing counters without CAS semantics in distributed systems.
