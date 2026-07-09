---
name: transaction-isolation
description: "Pattern: Transaction Isolation + Locking"
kind: ai-pattern
pack: database
---

# Pattern: Transaction Isolation + Locking

> **Hard rule:** Concurrent access to the same rows uses the RIGHT isolation level and locking discipline for the workload — pessimistic `SELECT … FOR UPDATE` with a consistent lock order, or an optimistic `version`/`updated_at` column with an affected-rows check — never a read-then-write race. Any code that relies on `SERIALIZABLE` or `REPEATABLE READ` MUST retry on a serialization failure (`40001`). A read-modify-write on a contended row with no lock and no version guard is forbidden. Cite the engine + version and the offending `<path:line>` verbatim, or halt.

**Ownership boundary:** the **backend** pack's `transaction-boundary` owns *where* a transaction opens and closes inside a service — the unit-of-work scope, wrapping the write-set and nothing else, committing before external I/O. THIS pattern owns the *DB engine's* concurrency semantics *inside* that boundary: which isolation level, which lock mode, lock ordering, deadlock and serialization-failure retry, MVCC bloat. Boundary = service scope; isolation = engine mechanics. A finding about a transaction spanning a network call belongs to `transaction-boundary`; a finding about a lost update or a phantom belongs here.

**When to apply**
- A read-modify-write on a hot row (balance, inventory, counter, seat, sequence) where two requests can interleave.
- A polled job-queue `SELECT … FOR UPDATE` where multiple workers pull the same rows.
- An invariant that spans rows the transaction does not directly modify (write-skew: two transfers each pass a min-balance check).
- Any use of `REPEATABLE READ`/`SERIALIZABLE` — the retry loop is mandatory, not optional.

**When NOT to apply**
- A single atomic statement (`UPDATE … SET x = x + 1 WHERE id = ?`) — the engine already serializes it; adding an explicit lock is noise.
- Append-only inserts with no contended read — no lock needed.
- Cross-service atomicity — that is outbox/saga (distributed-systems), not an engine lock.

**Halt conditions / mandatory cites**
- The DB engine + version MUST be extracted — isolation semantics differ (Postgres RR ≠ MySQL RR ≠ SQL Server RR). Without it, halt; advice is engine-specific.
- Every finding MUST cite the read at `<path:line>` AND the write at `<path:line>` that race, or the lock/version guard that is missing.
- A claim of "this uses Serializable" MUST cite where the level is set AND where the retry loop is — a Serializable transaction with no retry is a bug, not a fix.
- Hand-wave grep on `etc.`, `...`, `appears to`, `should be safe` is forbidden when claiming a section is race-free.

Concurrency correctness is not a default you inherit — it is a level you choose and a lock discipline you enforce. Pick deliberately, order locks consistently, retry the failures the engine hands you.

## Isolation levels and the anomaly each prevents

| Level | Prevents | Still allows |
|---|---|---|
| `READ UNCOMMITTED` | (nothing useful) | dirty reads — avoid |
| `READ COMMITTED` (default) | dirty reads | non-repeatable reads, phantoms, lost updates, write-skew |
| `REPEATABLE READ` / snapshot | + non-repeatable reads | phantoms (engine-dependent), write-skew |
| `SERIALIZABLE` | + phantoms + write-skew | nothing — but costs conflicts + retries |

**Engine differences that bite:**
- **Postgres** `READ COMMITTED` is the default and re-reads the latest committed snapshot per statement. `REPEATABLE READ` = a true transaction-level snapshot that *also* prevents phantoms (unlike the SQL standard), but throws `40001` on a concurrent update conflict. `SERIALIZABLE` uses SSI (serializable snapshot isolation) — no extra locks, but aborts conflicting transactions with `40001`; you MUST retry.
- **MySQL / InnoDB** default is `REPEATABLE READ`, implemented with **gap locks / next-key locks** that prevent phantoms by locking ranges — this changes locking behavior (more lock contention, different deadlock surface) versus Postgres RR. `READ COMMITTED` disables most gap locks (common OLTP choice). Deadlocks surface as error `1213`, lock-wait timeout as `1205`.
- **SQL Server / Oracle** — snapshot isolation is opt-in (`READ_COMMITTED_SNAPSHOT`, Oracle is MVCC by default with no dirty reads and no true Serializable-by-SSI). Note the engine before porting advice.

`SERIALIZABLE` is correct-by-default but pays in aborted transactions under contention. Reserve it for invariants that genuinely span rows (write-skew), and always pair it with a bounded retry loop.

## Pessimistic locking

Lock the rows you will write *before* you read the values you will act on.

```sql
BEGIN;
SELECT balance FROM accounts WHERE id = :id FOR UPDATE;   -- exclusive row lock
-- decide, then:
UPDATE accounts SET balance = balance - :n WHERE id = :id;
COMMIT;
```

- `FOR UPDATE` — exclusive; blocks other `FOR UPDATE`/writes on the row.
- `FOR SHARE` (`LOCK IN SHARE MODE` in older MySQL) — shared; readers coexist, writers block. Use for "read must stay valid until commit" without blocking other readers.
- `FOR UPDATE SKIP LOCKED` — job queues: each worker grabs the next *unlocked* rows, workers never collide or wait.
- `FOR UPDATE NOWAIT` — fail fast (`55P03`/`3572`) instead of blocking when the row is already locked; good for interactive paths that must not hang.

Always set a **lock timeout** (`SET lock_timeout`, InnoDB `innodb_lock_wait_timeout`) so a stuck lock doesn't pin a pooled connection forever.

## Optimistic locking

No lock held across the think-time — detect the conflict at write.

```sql
UPDATE items
   SET qty = :new_qty, version = version + 1
 WHERE id = :id AND version = :expected_version;   -- 0 rows updated ⇒ someone else won ⇒ retry / 409 / 412
```

The **affected-rows check is the whole mechanism** — `UPDATE … WHERE version = :v` is only safe if you assert `rowcount == 1` and retry (or return `409`/`412`) on `0`. `updated_at` works as the guard too, but a monotonic integer `version` avoids clock-resolution ties. Optimistic wins under low contention (no lock waits); pessimistic wins under high contention (no retry thrash).

## Deadlock avoidance

Deadlocks come from **inconsistent lock ordering**: T1 locks A then B, T2 locks B then A.

- **Fix:** acquire locks in a **fixed, total order** everywhere — e.g. `ORDER BY id` before locking, or always lock the lower account id first in a transfer. This makes a cycle impossible.
- **Then:** still catch and retry the deadlock error (`40P01` Postgres, `1213` MySQL) with a small bounded backoff — the engine kills one victim; retrying the victim usually succeeds.

## Advisory locks (app-level mutual exclusion)

When the thing to serialize isn't a row — a cron job, a rebuild, a per-tenant single-flight — use an advisory lock instead of locking an unrelated row.

```sql
SELECT pg_try_advisory_xact_lock(:key);   -- Postgres: true = acquired, auto-released at commit
SELECT GET_LOCK('rebuild:tenant42', 5);   -- MySQL named lock with timeout
```

Prefer the `_xact_` (transaction-scoped) variant so the lock releases on commit/rollback and can't leak.

## MVCC ↔ long-transaction bloat

Under MVCC (Postgres, InnoDB, Oracle) an old open transaction pins the oldest snapshot, so dead row versions can't be reclaimed. A long `REPEATABLE READ`/`SERIALIZABLE` transaction (or a leaked idle-in-transaction connection) blocks vacuum/purge → table + index bloat → slow everything. Keep transactions short (cross-ref `transaction-boundary`), monitor `pg_stat_activity` for `idle in transaction`, and set `idle_in_transaction_session_timeout`.

## Retry-on-serialization-failure

`SERIALIZABLE` and Postgres `REPEATABLE READ` don't block writers — they *abort* the loser with `40001`. That abort is expected, not exceptional. Wrap the whole transaction in a bounded retry:

```
for attempt in 1..N:
  try: run_transaction()   # BEGIN … COMMIT at SERIALIZABLE
  catch SerializationFailure(40001 / 40P01):
    if attempt == N: raise
    sleep(jitter_backoff(attempt)); continue   # re-run from the top — side effects must be idempotent
```

The retry re-runs the *entire* transaction body, so it must be free of non-idempotent external side effects (which belongs outside the boundary anyway — see `transaction-boundary`).

## Write-skew under snapshot isolation

Snapshot / `REPEATABLE READ` prevents dirty and non-repeatable reads but NOT write-skew: two transactions each read a set, each check an invariant that's true on their snapshot, each write a disjoint row — together they violate the invariant (e.g. "at least one doctor on call": both read 2-on-call, both go off call). Snapshot can't see it because the rows written don't overlap the rows read. Fix: `SERIALIZABLE` (SSI catches it) **or** materialize the conflict with an explicit `FOR UPDATE` on a shared guard row.

## Adapt to the codebase

Extract the engine + ORM, then map to how each sets isolation and takes a row lock.

| Layer | Set isolation | Row lock |
|---|---|---|
| Raw SQL | `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;` | `SELECT … FOR UPDATE [SKIP LOCKED\|NOWAIT]` / `FOR SHARE` |
| Postgres | `BEGIN ISOLATION LEVEL REPEATABLE READ;` | `FOR UPDATE`; advisory: `pg_advisory_xact_lock` |
| MySQL / InnoDB | `SET TRANSACTION ISOLATION LEVEL READ COMMITTED;` | `FOR UPDATE` / `LOCK IN SHARE MODE`; gap locks under RR |
| TypeORM | `dataSource.transaction("SERIALIZABLE", …)` | `.setLock("pessimistic_write" \| "pessimistic_read")` |
| Prisma | `$transaction(fn, { isolationLevel: "Serializable" })` | raw `FOR UPDATE` (`$queryRaw`) or `version` field |
| SQLAlchemy | `engine.execution_options(isolation_level="SERIALIZABLE")` | `session.query(...).with_for_update(skip_locked=…, nowait=…)` |
| Django | `transaction.atomic()` + `connection` isolation config | `Model.objects.select_for_update(skip_locked=…, nowait=…)` |
| ActiveRecord | `transaction(isolation: :serializable)` | `record.lock!` / `record.with_lock` / `.lock("FOR UPDATE SKIP LOCKED")` |

## Detectors (cite-or-halt)

Each finding cites `<file:line>` for the racing read AND write + the matched pattern + the fix.

### 1. Read-then-write with no lock or version guard (lost update)

```
BAD:   row = repo.get(id); row.qty -= n; repo.save(row)          # two requests → one decrement lost
GOOD:  SELECT qty FROM items WHERE id=:id FOR UPDATE; UPDATE …    # or version-guarded UPDATE, rowcount==1
```
Flag a load → mutate-in-memory → save on a contended resource with no `FOR UPDATE` and no `version`/`updated_at` predicate.

### 2. Multi-row locking in inconsistent order (deadlock)

Flag two code paths that lock ≥2 rows/tables in different orders (transfer locks `from` then `to`; refund locks `to` then `from`). Fix: lock in a fixed total order (`ORDER BY id`).

### 3. Missing retry where Serializable / RR is used

Flag a transaction set to `SERIALIZABLE` or Postgres `REPEATABLE READ` with no `catch` for `40001`/`40P01` and no bounded retry loop. The abort *will* happen under contention.

### 4. `SELECT`-then-`UPDATE` counter (non-atomic increment)

```
BAD:   v = SELECT count FROM c WHERE id=:id;  UPDATE c SET count=:v+1 WHERE id=:id
GOOD:  UPDATE c SET count = count + 1 WHERE id=:id                 # atomic; or FOR UPDATE
```
Flag a read of a counter followed by a write of read-value±1 with no lock.

### 5. Long transaction holding locks across an external call

Flag a lock/`FOR UPDATE` held while an HTTP/gRPC/queue/slow-read runs before commit. Cross-ref **backend `transaction-boundary`** (boundary scope owns the fix); this pattern flags the *lock* held too long.

### 6. `SKIP LOCKED` absent on a polled job-queue SELECT

Flag a worker-loop `SELECT … FOR UPDATE` (or bare `SELECT` claim) on a queue/outbox table with no `SKIP LOCKED` → workers block on each other or double-process. Add `FOR UPDATE SKIP LOCKED`.

### 7. Write-skew under snapshot with no explicit lock

Flag an invariant checked by reading rows the transaction does *not* write, under `READ COMMITTED`/`REPEATABLE READ` (on-call count, seat count, disjoint-transfer min-balance). Fix: `SERIALIZABLE` or a `FOR UPDATE` on a shared guard row.

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete `FOR UPDATE` / version-guard+rowcount / atomic-UPDATE / lock-ordering / `SKIP LOCKED` / retry-loop patch.
- `report-flagged` — the fix is a design call (move `READ COMMITTED` → `SERIALIZABLE`; optimistic ↔ pessimistic under measured contention; write-skew needs an invariant redesign) → surface for ADR.
- `dismiss` — carve-out applies (a genuinely single atomic statement; append-only insert; a lock the engine already implies) → documented with the reason.

## Related

- `indexing-strategy.md` — locks ride on index access paths; a missing index turns a row lock into a range/table lock (and InnoDB gap locks span the scanned range).
- `migrations.md` — backfills and DDL take locks; batch + lock-timeout to avoid blocking writers.
- `connection-pooling.md` — a lock or `FOR UPDATE` held too long pins its pooled connection; long transactions drain the pool. Keep the locked window short.
- `backend` `transaction-boundary` — the ownership boundary above: service scope (where the transaction opens/closes). State the split when a finding is really about boundary, not isolation.
- `distributed-systems` `idempotency` — a retried (`40001`) transaction re-runs its body; side effects must be idempotent.
- `distributed-systems` `distributed-lock` — when mutual exclusion must span services, an in-DB row/advisory lock is not enough.
- `@schema-reviewer` / `@database-optimizer` — review agents that consume these detectors.
