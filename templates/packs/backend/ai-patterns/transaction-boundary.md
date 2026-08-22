---
name: transaction-boundary
kind: pattern
pack: backend
---

# Pattern: Transaction boundaries (intra-service)

Where a single write must be atomic, the transaction must wrap the whole write-set and nothing else — not a network call, not a slow read, not a queue publish. This pattern owns *intra-service* transaction correctness (unit-of-work, isolation, locking, rollback). *Cross-service* atomicity (outbox / saga / 2PC) is owned by the **distributed-systems** pack — this pattern never reaches across a service boundary inside a transaction.

**When NOT to apply**
- **A single-statement write.** One `INSERT`/`UPDATE` is already atomic; wrapping it in an explicit transaction adds a round-trip and nothing else. Detector 2 does not fire on it and neither should a reviewer.
- **A read-only path.** A transaction around pure reads buys a snapshot you probably do not need and holds a connection while you do not need it. The exception is the consistent-report case in rule 5's table — which is a deliberate choice, not a default.
- **Work that spans a service boundary.** If atomicity has to survive a network hop, no isolation level reaches it. That is outbox/saga, in the distributed-systems pack, and reaching for a longer transaction instead is how a distributed problem becomes a lock-contention incident as well.
- **An eventually-consistent write the product already tolerates.** If the business rule is "these two things agree within a minute", a transaction is the wrong instrument and an expensive one.

## Rules

1. **The service owns the boundary, not the repository.** A use-case that mutates two aggregates opens ONE transaction around both; repositories run inside it. Wrapping each repo call in its own transaction leaves a half-applied write on failure.
2. **Wrap the write-set, nothing else.** No HTTP/gRPC call, no queue publish, no external API, no long CPU work inside the transaction — the connection is held from the pool the whole time (see `backend-principles` "no external I/O in a transaction"; the write+publish atomicity case is the **outbox** pattern in distributed-systems).
3. **Keep it short.** Read what you need before opening, commit as soon as the write-set is durable. A transaction open across user think-time or a slow report is a lock held too long.
4. **Rollback on any error, commit only on success.** Use the framework's managed transaction (`@Transactional`, `db.transaction(...)`, `Ecto.Multi`, `unit_of_work`) so an exception rolls back automatically — never a manual `BEGIN`/`COMMIT` with an `except` that forgets to `ROLLBACK`.
5. **Choose the isolation level from the invariant's shape — this is the only rule here a competent engineer routinely gets wrong.** "Choose deliberately" is an instruction to be thoughtful, not a procedure. The procedure is: *name the invariant, then read the row*. Every row below assumes Postgres/`READ COMMITTED` as the default; MySQL InnoDB defaults to `REPEATABLE READ` (with its own gap-locking behaviour) and SQL Server to `READ COMMITTED` with locking rather than MVCC — confirm your engine's default before assuming which row you are already in.

| The invariant you are protecting | Mechanism | Retry budget | What thrashes under contention |
|---|---|---|---|
| **A single row's own value** (`balance -= n`, `stock -= 1`) | Neither. One atomic statement: `UPDATE … SET x = x - :n WHERE id = :id AND x >= :n`, then check rows-affected. | None — it cannot fail this way. | Nothing. The row lock is held for microseconds. **Reach for this first; the isolation-level conversation is usually a sign the write was decomposed when it did not need to be.** |
| **A row that must not change between your read and your write** (edit-then-save, versioned resource) | Optimistic: a `version` column + `WHERE version = :expected`. | Bounded — 2–3 attempts, then surface `409`/`412` to the caller. The user's own edit is the retry. | Nothing at the DB. The retries are the client's. |
| **A rule across rows you read but do not write** ("total allocations must not exceed the quota", "no overlapping booking") | This is the case that genuinely needs `SERIALIZABLE` (or `REPEATABLE READ` + `SELECT … FOR UPDATE` on the parent row that represents the set). A predicate read under `READ COMMITTED` is **not** protected: two transactions each see a compliant world and both commit. | Retry on `40001` with jitter — the transaction must be *replayable* from its inputs, so the whole read-decide-write must live inside it and nothing outside may already have been sent. | `SERIALIZABLE` aborts scale with conflicting concurrency. If the same parent row is hot, serialisation failures rise superlinearly and the retries make it worse — that is the signal to switch to an explicit lock on the parent, or to decompose the invariant into a single atomic statement. |
| **Ordering across several rows in one write-set** | Lock ordering (rule 7), not isolation level. | Retry on `40P01` (deadlock). | A deadlock storm, if the ordering is inconsistent on any path. |
| **A report that must see one consistent snapshot** | `REPEATABLE READ`, read-only, ideally on a replica. | None. | Long-running snapshots hold back vacuum/purge; a report transaction open for minutes is a storage problem, not a correctness one. |

**The move that looks right and is not:** raising the isolation level to fix a race that a single atomic statement would have removed. It converts a lock held for microseconds into a transaction that can abort under load, and it adds a retry path that must now be tested. Escalate isolation only when the invariant spans rows you are not writing — that is the boundary `READ COMMITTED` cannot see across, and everything below it is cheaper somewhere else.
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

Exactly one verb per finding. What each means for *this* pattern:

- `report-with-fix` — matched at `<file:line>` + the concrete commit-then-call / single-boundary / version-guard / managed-transaction patch.
- `report-flagged` — the fix is a design call (introduce an outbox for write+publish; move to pessimistic locking) → surface for ADR.
- `dismiss` — carve-out applies (a genuinely single-statement write; an idempotent external call safe to retry after commit) → documented.

## Related

- `backend-principles.md` — "no external I/O in a transaction" MUST.
- `conditional-requests.md` — the HTTP `If-Match`/`412` surface for optimistic concurrency.
- `distributed-systems` pack — outbox (write+publish atomicity), saga (cross-service), idempotency (retry-safe replay). This pattern stays intra-service.
- `database` pack — isolation-level + index + deadlock deep-dive.
