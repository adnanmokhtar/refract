---
name: idempotency
description: "Pattern: Idempotency"
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Idempotency

> **Hard rule:** Every non-GET endpoint that mutates external state accepts an idempotency key, persists the (key → result) record atomically with the side effect, and returns the cached result on replay. Generating UUIDs server-side per request, storing the key without the result, or "best-effort" dedup via in-memory map is forbidden.

**When to apply**
- Payment, order placement, webhook receivers, message consumers — anywhere a retry can produce a duplicate.
- A saga step or outbox consumer that can be redelivered.
- An external client (mobile, partner) on a flaky network where retries are expected.

**When NOT to apply**
- Pure-read GET endpoints — they're already idempotent by HTTP semantics.
- Internal RPC inside a single transaction where dedup is impossible to violate.

**Halt conditions / mandatory cites**
- The proposal MUST cite the storage row (table + unique constraint) for the idempotency key at `<path:line>`.
- The atomic write (key + side-effect committed in the same tx, or via outbox) MUST be cited; "we'll add the constraint later" is a bug.
- A doc using in-memory cache as the idempotency store is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is idempotent".
- If the key TTL / cleanup strategy isn't extracted, halt.

"Running twice = running once." Foundation for retries, webhooks, sagas, event consumers, payments.

## Why it matters

Networks fail. Clients retry. Without idempotency:
- Duplicate orders.
- Double charges.
- Phantom inventory decrements.
- Event handlers fire twice → duplicate side effects.

## Idempotent operations by type

### HTTP methods (RFC 9110, obsoletes 7231)
- **GET** — idempotent by definition. No side effects.
- **PUT** — idempotent. Full replace.
- **DELETE** — idempotent. Idempotency constrains the *effect on server state* (the resource ends up gone), **not the status code** — a repeat DELETE returning `404`/`410` is fully idempotent and common (a first `200`/`204` then `404` on the second call is fine). Don't force `200`/`204` on an already-deleted resource to "look idempotent."
- **HEAD, OPTIONS** — idempotent.
- **POST** — NOT idempotent by default. Make it idempotent via idempotency keys.
- **PATCH** — NOT guaranteed. Depends on semantics (increment = not idempotent; set-if-match = idempotent).

### At the DB level
- Conditional insert (the engine's "insert if not exists" / "on conflict do nothing" syntax) — idempotent insert.
- Upsert (insert-or-update on conflict / merge) — idempotent upsert.
- `DELETE WHERE id = ?` — idempotent.
- `UPDATE ... SET status = 'X' WHERE id = ? AND status != 'X'` — idempotent "set once".

## Idempotency keys (client-supplied)

Client generates a unique key (UUID) per logical operation. Sends it on retries.

```
POST /orders
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

Server stores first response by key. Subsequent requests with same key return stored response without re-executing.

### Server-side storage (stack-agnostic schema)

`idempotency_records` table with columns: `key` (PK), `request_hash` (prevents key reuse with different body), `response_body` (JSON / structured-data column), `response_status` (int), `created_at` (timestamp), `expires_at` (timestamp, TTL typically 24h). Index on `expires_at` for the cleanup job.

Flow:
```
1. Receive request with Idempotency-Key.
2. Lock on key (advisory lock / row-level "select for update" — a **single-source-of-truth** DB lock is safest here). **If using a distributed lock (Redis etc.), it MUST carry a fencing token** — a monotonically increasing number the resource checks and rejects if stale — because a lock holder can be paused (GC/network) past its TTL and a second holder acquire concurrently. Redlock is contested (Kleppmann vs Antirez); for correctness prefer a single-writer DB lock or a fencing-token-checked resource, not a lock alone. See `distributed-lock.md`.
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

`processed_events` table with `event_id` PK + `processed_at` timestamp. The handler attempts to insert the event_id first; on duplicate-key error, the event is already processed — return early. Otherwise, do the work.

### Dedup within the business write
Combine the processing write + event id in one DB transaction: insert the event id (fails if duplicate) and update the business row in the same transaction. Both succeed or both rollback.

## Payment / financial operations

Most payment vendors require idempotency keys on creates — pass the key as the vendor SDK / API expects. Your side: same idempotency pattern for your internal state changes.

## Idempotent operation design

Prefer operations where repetition is NATURALLY idempotent:

### SET rather than INCREMENT
- BAD: `counter.increment(5)` — two runs = double-counted.
- GOOD: `counter.setToAtLeast(target)` via compare-and-swap — repeated runs converge on the same value.

### Upsert rather than insert
- BAD: plain `INSERT INTO users ...` — second run = duplicate-row error.
- GOOD: insert-or-update / upsert (the engine's merge / on-conflict-do-update primitive).

### State transitions with preconditions
- BAD: `UPDATE orders SET status='paid' WHERE id = ?` — re-runs overwrite, no safety.
- GOOD: `UPDATE orders SET status='paid', paid_at=now() WHERE id = ? AND status = 'pending'` — affected-rows = 0 if already paid; caller knows to skip.

## Retry safety

Retries are safe IF the operation is idempotent. Never retry a non-idempotent POST without an idempotency key. Use the project's retry primitive (the language's structured retry library) and pass the idempotency key on every attempt.

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
