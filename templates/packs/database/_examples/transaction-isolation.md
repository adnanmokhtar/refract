---
name: transaction-isolation
kind: example
pack: database
---

# Pattern: Transaction Isolation + Locking

Concurrency correctness is a level you choose and a lock discipline you enforce — never a read-then-write race. Pick the isolation level deliberately, order locks consistently, and retry the failures the engine hands you. Extract the **engine + version** first — semantics differ (Postgres RR ≠ MySQL RR ≠ SQL Server RR).

## Isolation levels

| Level | Prevents | Still allows |
|---|---|---|
| `READ COMMITTED` (default) | dirty reads | non-repeatable reads, phantoms, lost updates, write-skew |
| `REPEATABLE READ` / snapshot | + non-repeatable reads | phantoms (engine-dependent), write-skew |
| `SERIALIZABLE` | + phantoms + write-skew | nothing — but costs conflicts + retries |

Postgres `REPEATABLE READ`/`SERIALIZABLE` abort the loser with `40001` — you MUST retry. MySQL/InnoDB defaults to `REPEATABLE READ` with gap/next-key locks (deadlock `1213`, lock-wait `1205`).

## Pessimistic locking

Lock the rows you will write *before* you read the values you act on.
```sql
BEGIN;
SELECT balance FROM accounts WHERE id = :id FOR UPDATE;
UPDATE accounts SET balance = balance - :n WHERE id = :id;
COMMIT;
```
- `FOR UPDATE SKIP LOCKED` — job queues; each worker grabs the next unlocked rows.
- `FOR UPDATE NOWAIT` — fail fast instead of blocking on interactive paths.
- Always set a **lock timeout** so a stuck lock doesn't pin a pooled connection.

## Optimistic locking

```sql
UPDATE items SET qty = :new, version = version + 1
 WHERE id = :id AND version = :expected;   -- 0 rows ⇒ someone won ⇒ retry / 409 / 412
```
The **affected-rows check is the whole mechanism** — assert `rowcount == 1`. Optimistic wins under low contention, pessimistic under high.

## Deadlock avoidance

Deadlocks come from inconsistent lock ordering. Fix: acquire locks in a **fixed total order** everywhere (`ORDER BY id`), then still catch + retry the deadlock error (`40P01` / `1213`) with bounded backoff.

## Retry-on-serialization-failure

`SERIALIZABLE`/Postgres RR abort, they don't block — that abort is expected. Wrap the whole transaction in a bounded retry; the body re-runs, so it must be free of non-idempotent external side effects.

## Write-skew under snapshot

Snapshot/RR does NOT prevent write-skew: two transactions read disjoint rows, each pass an invariant, together violate it (both doctors go off-call). Fix: `SERIALIZABLE` (SSI) or `FOR UPDATE` on a shared guard row.

## Forbidden

- Read-modify-write on a contended row with no lock and no version guard (lost update).
- `SERIALIZABLE` / Postgres `REPEATABLE READ` with no retry loop for `40001`/`40P01`.
- Locking ≥2 rows in different orders across code paths.
- A polled job-queue `SELECT … FOR UPDATE` with no `SKIP LOCKED`.
- A lock held across an external HTTP/queue call (see `transaction-boundary`).
