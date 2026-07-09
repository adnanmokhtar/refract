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
5. Deliberate isolation level; retry on serialization failure (`40001`) for read-modify-write invariants.
6. Concurrency: optimistic `version` guard (`WHERE version=:v`, 0 rows → retry/409) default; pessimistic `FOR UPDATE` + lock timeout only for short hot sections.
7. Consistent lock ordering to avoid deadlocks; retry `40P01`.

## Detectors (cite-or-halt)

1. External call between `transaction(` and commit → commit first, then call (or outbox).
2. Per-repo txns in a multi-aggregate use-case → one boundary.
3. Load → mutate-in-memory → save on a contended row with no version guard → optimistic lock.
4. Manual BEGIN/COMMIT whose error path can skip ROLLBACK → managed transaction.
5. Transaction spanning a slow read / external loop / think-time → read before, commit after.

Closure verbs: `report-with-fix` / `report-flagged` (outbox / pessimistic — ADR) / `dismiss` (single-statement write).

## Related

`backend-principles.md` (no I/O in tx), `conditional-requests.md` (If-Match/412), distributed-systems (outbox/saga/idempotency), database pack.
