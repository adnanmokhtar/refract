---
name: transaction-boundary
kind: pattern
pack: backend
---

# Pattern: Transaction boundaries (intra-service)

Where a single write must be atomic, the transaction must wrap the whole write-set and nothing else — not a network call, not a slow read, not a queue publish. This pattern owns *intra-service* transaction correctness (unit-of-work, isolation, locking, rollback). *Cross-service* atomicity (outbox / saga / 2PC) is owned by the **distributed-systems** pack — this pattern never reaches across a service boundary inside a transaction.

## Rules

1. **The service owns the boundary, not the repository.** A use-case that mutates two aggregates opens ONE transaction around both; repositories run inside it. Wrapping each repo call in its own transaction leaves a half-applied write on failure.
2. **Wrap the write-set, nothing else.** No HTTP/gRPC call, no queue publish, no external API, no long CPU work inside the transaction — the connection is held from the pool the whole time (see `backend-principles` "no external I/O in a transaction"; the write+publish atomicity case is the **outbox** pattern in distributed-systems).
3. **Keep it short.** Read what you need before opening, commit as soon as the write-set is durable. A transaction open across user think-time or a slow report is a lock held too long.
4. **Rollback on any error, commit only on success.** Use the framework's managed transaction (`@Transactional`, `db.transaction(...)`, `Ecto.Multi`, `unit_of_work`) so an exception rolls back automatically — never a manual `BEGIN`/`COMMIT` with an `except` that forgets to `ROLLBACK`.
5. **Choose the isolation level deliberately.** The default (usually `READ COMMITTED`) is fine for most writes; use `REPEATABLE READ`/`SERIALIZABLE` for read-modify-write invariants (balance checks, inventory) and be ready to retry on a serialization failure (`40001`).
6. **Concurrency control on contended rows:**
   - **Optimistic** (default) — a `version`/`row_version` column, bumped on write, `WHERE version = :expected`; 0 rows updated → retry or `409`/`412`. Pairs with `conditional-requests` for the HTTP `If-Match`/`412` surface.
   - **Pessimistic** (`SELECT … FOR UPDATE`) — only for short, hot critical sections where retries would thrash; always with a lock timeout to avoid a stuck connection.
7. **Consistent lock ordering** across code paths that lock multiple rows/tables — acquire in a fixed order (e.g. by id) to prevent deadlocks; expect and retry the deadlock error (`40P01`).

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix.

### 1. External I/O inside a transaction

```
BAD:   db.transaction(async tx => {
         await tx.orders.insert(o)
         await paymentApi.charge(o)          // network call holds the tx + connection
       })
GOOD:  const o = await db.transaction(tx => tx.orders.insert(o))   // commit first
       await paymentApi.charge(o)                                  // then the call (or outbox)
```
Flag an `http`/`fetch`/gRPC/queue-publish/external-SDK call between `transaction(` and its commit.

### 2. Per-call transactions instead of one boundary

Flag a use-case mutating ≥2 aggregates where each repository opens its own transaction → a failure leaves a partial write. Wrap the use-case in one transaction.

### 3. Read-modify-write with no concurrency control

```
BAD:   const a = await repo.get(id); a.balance -= n; await repo.save(a)   // lost update
GOOD:  UPDATE accounts SET balance = balance - :n, version = version + 1
       WHERE id = :id AND version = :v AND balance >= :n                  // 0 rows → retry/409
```
Flag a load → mutate-in-memory → save on a contended resource with no `version` guard and no `FOR UPDATE`.

### 4. Manual BEGIN/COMMIT with no guaranteed rollback

Flag a hand-managed `BEGIN`/`COMMIT` whose error path can skip `ROLLBACK` (a `catch` that logs and returns, a missing `finally`). Use the managed transaction primitive.

### 5. Long-held transaction

Flag a transaction that spans a slow read, a loop over external calls, or user think-time → recommend reading before, committing after.

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete commit-then-call / single-boundary / version-guard / managed-transaction patch.
- `report-flagged` — the fix is a design call (introduce an outbox for write+publish; move to pessimistic locking) → surface for ADR.
- `dismiss` — carve-out applies (a genuinely single-statement write; an idempotent external call safe to retry after commit) → documented.

## Related

- `backend-principles.md` — "no external I/O in a transaction" MUST.
- `conditional-requests.md` — the HTTP `If-Match`/`412` surface for optimistic concurrency.
- `distributed-systems` pack — outbox (write+publish atomicity), saga (cross-service), idempotency (retry-safe replay). This pattern stays intra-service.
- `database` pack — isolation-level + index + deadlock deep-dive.
