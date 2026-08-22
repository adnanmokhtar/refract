---
name: transaction-boundary
kind: example
pack: backend
---

# Pattern: Transaction boundaries (intra-service)

Wrap the whole write-set and nothing else — no network call, no queue publish, no slow read inside the transaction. Owns intra-service atomicity; cross-service (outbox/saga/2PC) is the distributed-systems pack.

## Rules

1. The SERVICE owns the boundary (one tx around the use-case), not per-repo txns.
2. No external I/O / queue publish inside the tx (connection held from the pool).
3. Keep it short — read before, commit as soon as the write-set is durable.
4. Managed transaction (`@Transactional` / `db.transaction` / `Ecto.Multi`) so errors auto-rollback.
5. **Isolation level follows the invariant's shape** — "choose deliberately" is not a procedure. Name the invariant, then pick:
   - *One row's own value* (`balance -= n`) → neither. One atomic statement `UPDATE … SET x = x - :n WHERE id = :id AND x >= :n`, check rows-affected. No retry path exists. **Try this first** — reaching for an isolation level usually means the write was decomposed when it did not need to be.
   - *A row unchanged between your read and your write* → optimistic `version` guard; retry budget is 2–3, then `409`/`412` and let the user's own edit be the retry.
   - *A rule across rows you read but do not write* (quota totals, no-overlapping-booking) → `SERIALIZABLE`, or `REPEATABLE READ` + `FOR UPDATE` on the parent row representing the set. `READ COMMITTED` does **not** protect a predicate read: two transactions each see a compliant world and both commit. Retry `40001` with jitter, and keep the whole read-decide-write inside the transaction so it is replayable. Aborts rise superlinearly on a hot parent — that is the signal to switch to an explicit lock or an atomic statement, not to retry harder.
   - *A consistent snapshot for a report* → `REPEATABLE READ`, read-only, ideally on a replica.
   Engine defaults differ (Postgres/SQL Server `READ COMMITTED`, MySQL InnoDB `REPEATABLE READ`) — confirm yours before assuming which row you are already in.
6. Concurrency: optimistic `version` guard (`WHERE version=:v`, 0 rows → retry/409) default; pessimistic `FOR UPDATE` + lock timeout only for short hot sections.
7. Consistent lock ordering to avoid deadlocks; retry `40P01`.

**When NOT to apply:** a single-statement write (already atomic); a read-only path; anything spanning a service boundary (outbox/saga — no isolation level reaches across a network hop); a write the product already tolerates as eventually consistent.

## Detectors (cite-or-halt)

1. External call between `transaction(` and commit → commit first, then call (or outbox).
2. Per-repo txns in a multi-aggregate use-case → one boundary.
3. Load → mutate-in-memory → save on a contended row with no version guard → optimistic lock.
4. Manual BEGIN/COMMIT whose error path can skip ROLLBACK → managed transaction.
5. Transaction spanning a slow read / external loop / think-time → read before, commit after.

Closure verbs: `report-with-fix` / `report-flagged` (outbox / pessimistic — ADR) / `dismiss` (single-statement write).

## Related

`backend-principles.md` (no I/O in tx), `conditional-requests.md` (If-Match/412), distributed-systems (outbox/saga/idempotency), database pack.
