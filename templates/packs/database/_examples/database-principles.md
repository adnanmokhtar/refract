---
name: database-principles
kind: example
pack: database
---

# Database Principles

> **Hard rule.** Schema changes ship via reviewed migrations only — `synchronize: true` / auto-migrate / `db.create_all()` in production are forbidden. Every list query MUST paginate with `LIMIT`; every FK MUST have a usable index; every transaction MUST stay local (no external HTTP / queue / API call held inside).

This file states the **invariant**. The linked `ai/patterns/<x>.md` states the method *and carries the vendor citation for every engine claim below*; `.claude/references/<engine>.md` carries the syntax. Never re-derive either here — and never assert an engine behaviour this file names without following the pointer to the doc that sources it.

## Must

- Primary keys: UUID v7 (time-ordered, B-tree friendly) or bigint sequences. Never `int` — overflow is a real outage at scale.
- Timestamps stored UTC + timezone-aware (`TIMESTAMPTZ` in Postgres, `DATETIME(6)` + always-UTC convention in MySQL).
- Foreign keys declared at the DB level with `ON DELETE` semantics chosen explicitly (`RESTRICT` / `CASCADE` / `SET NULL`). ORM-only FKs do not protect data.
- Every FK column has a usable index — without one, deletes and joins do full scans. **Engine split:** Postgres does not create it, so declare it; InnoDB creates one automatically, so on MySQL the finding inverts. → `ai/patterns/indexing-strategy.md`.
- Money in `DECIMAL(precision, scale)` (e.g. `DECIMAL(19,4)`). Never `FLOAT` / `DOUBLE` — `0.1 + 0.2 != 0.3`.
- `NOT NULL` is the default; nullability is a documented design choice, not laziness.
- Unique constraints for natural keys (`email`, `slug + tenant_id`, `idempotency_key`) — the DB is where the race is actually lost.
- Parameterized queries / prepared statements / ORM bind params only. Never interpolate into SQL.
- Pagination on every list query. `LIMIT` mandatory.
- Soft-delete / multi-tenant projects: every custom query carries the `deleted_at IS NULL` and `tenant_id = :tenantId` filters, or uses the base repo that adds them.
- Contended read-modify-write (balance, inventory, counter, seat, sequence) is `SELECT … FOR UPDATE`-locked or version-guarded on `rowcount == 1` — never load-mutate-save unguarded. Serialization failures (`40001` / `40P01`) retry; multi-row locks take one fixed order. → `ai/patterns/transaction-isolation.md`.
- Every PII column is classified, with a declared retention window enforced by a real mechanism (partition-drop / TTL job / purge), and an erasure path that resolves every dependent FK — no orphan, no FK that silently blocks it. → `ai/patterns/data-retention-pii.md`.
- Text search on a large table uses the engine's real FTS primitive, kept in sync by a `GENERATED … STORED` column or trigger, returning **ranked** results — never `LIKE '%term%'` forcing a full scan. → `ai/patterns/full-text-search.md`.
- Every process reaches the DB through a **bounded** pool satisfying `per_instance_pool_max × instance_count + other_clients ≤ server_max_connections − reserve` — never a connection per request, never a guessed size. → `ai/patterns/connection-pooling.md`.
- A read routed to a replica tolerates lag; read-your-writes and correctness-sensitive reads (auth / authorization / balance / inventory / uniqueness pre-check) go to the **primary** or carry a consistency token. → `ai/patterns/read-replicas.md`.

## Must not

- `synchronize: true` (TypeORM) / `db.create_all()` in production / auto-migrate flags. Schema by migration only.
- Ship an `ALTER TABLE` without naming **(a)** the algorithm the engine will pick and **(b)** whether a long transaction currently holds a metadata lock on the target. The algorithm — not the row count — sets the lock window, and every `ALTER`, INSTANT included, queues behind the oldest open transaction. Check `information_schema.INNODB_TRX` / `pg_stat_activity` first and bound the wait (`lock_wait_timeout` / `lock_timeout`). Per-operation split, `LOCK=NONE`'s cascade restriction, and when `gh-ost` / `pt-online-schema-change` earn their place: → `ai/patterns/migrations.md`, `.claude/references/<engine>.md`, `@schema-reviewer`.
- Hold a transaction across an HTTP / queue / external API call. The pool exhausts at peak, and the pinned snapshot blocks reclaim (Postgres vacuum / InnoDB purge).
- `SELECT *` on wide rows (BLOB / JSON / TEXT) when you need 3 fields.
- Choose composite index column order at random. Leftmost prefix decides: `(tenant_id, status, created_at)` serves `WHERE tenant_id = ? AND status = ?`, not `WHERE status = ?`.
- Over-index. Every index slows writes. Drop what `pg_stat_user_indexes` / `sys.schema_unused_indexes` never records — never one backing a unique constraint or an FK. On InnoDB the FK-index advice inverts (the engine auto-creates that index and may later drop it): read `SHOW INDEX` before reporting "missing FK index" or proposing a drop. → `ai/patterns/indexing-strategy.md`.
- Put business logic in triggers without a documented reason.

## Should

- `EXPLAIN ANALYZE` (Postgres; MySQL 8, always `TREE` format) on any new query whose predicate is not already served by an existing index's leading columns — index coverage is the trigger, not a row-count threshold.
- CHECK constraints for invariants the app should not re-enforce (`CHECK (price >= 0)`).
- Migrations reversible (ship a `down`) where feasible; otherwise document the forward-fix plan in the migration header.
- Expand-contract for breaking changes — add → backfill → switch reads → switch writes → drop — each step its own deploy. → `ai/patterns/migrations.md`.
- `pg_stat_statements` / MySQL `events_statements_summary_by_digest` enabled; review the top statements by total exec time weekly.

## Review + enforcement

Reviewing a change against these rules is `@schema-reviewer`'s job (it owns the APPROVE gate); auditing a running database against them is `/db-audit`'s. Neither is restated here — a checklist inside an always-loaded rule is duplicated context, not extra safety.
