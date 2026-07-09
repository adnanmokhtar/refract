---
name: database-principles
description: Database Principles
kind: rule
pack: database
severity: must
applies-to: database-track, every-code-writing-task-in-database
---

# Database Principles

> **Hard rule.** Schema changes ship via reviewed migrations only — `synchronize: true` / auto-migrate / `db.create_all()` in production are forbidden. Every list query MUST paginate with `LIMIT`; every FK MUST be indexed; every transaction MUST stay local (no external HTTP / queue / API call held inside).

Engine-agnostic. Engine-specific syntax in `references/<engine>.md` (postgres, mysql, sqlite, mongodb).

Prevents the failures that wake you up: deadlocks, runaway scans, broken migrations, lost data.

## Must

- Primary keys: UUID v7 (time-ordered, B-tree friendly) or bigint sequences. Never `int` (overflow is a real outage at scale).
- Timestamps stored UTC + timezone-aware (`TIMESTAMPTZ` in Postgres, `DATETIME(6)` + always-UTC convention in MySQL).
- Foreign keys declared at the DB level with `ON DELETE` semantics chosen explicitly (`RESTRICT` / `CASCADE` / `SET NULL`). ORM-only FKs do not protect data.
- Every FK column is indexed. Without it, deletes and joins do full scans.
- Money in `DECIMAL(precision, scale)` (e.g. `DECIMAL(19,4)`). Never `FLOAT` / `DOUBLE` — `0.1 + 0.2 != 0.3`.
- `NOT NULL` is the default; nullability is a documented design choice, not laziness.
- Unique constraints for natural keys (`email`, `slug + tenant_id`, `idempotency_key`). Prevents app-level race conditions.
- Parameterized queries / prepared statements / ORM bind params only. Never interpolate into SQL.
- Pagination on every list query. `LIMIT` mandatory.
- Soft-delete projects: every custom query adds the `deleted_at IS NULL` filter (or uses the base repo that adds it).
- Multi-tenant projects: every custom query adds `tenant_id = :tenantId` (or uses the base repo that adds it).
- Concurrent read-modify-write on a contended row (balance, inventory, counter, seat, sequence) holds a `SELECT … FOR UPDATE` lock or a `version`/`updated_at` guard checked with `rowcount == 1` — never load-mutate-save unguarded. Any `SERIALIZABLE` / Postgres `REPEATABLE READ` transaction retries on serialization failure (`40001` / `40P01`), and multi-row locks are acquired in one fixed order (deadlock avoidance). See `ai-patterns/transaction-isolation.md`.
- Every PII column is classified (column comment / data-catalog row / ORM tag) with a declared retention window enforced by a real mechanism (partition-drop / TTL job / scheduled purge) — no personal data stored "forever". The erasure path resolves every dependent FK (CASCADE / anonymize / SET NULL) so a deletion never orphans rows or silently blocks on `ON DELETE RESTRICT`, and soft-deleted rows are still hard-purged past the window. See `ai-patterns/data-retention-pii.md`.
- Text search over a large table uses the engine's real full-text primitive (Postgres `tsvector` + GIN, MySQL `FULLTEXT`, SQLite FTS5, or an external engine) kept in sync by a `GENERATED … STORED` column or trigger, and returns results **ranked** (`ts_rank` / `MATCH … AGAINST` score) — never `LIKE '%term%'` / `ILIKE '%term%'` forcing a full scan, and never an unmaintained (stale) FTS column. `pg_trgm` is the indexed answer for genuine substring/fuzzy. See `ai-patterns/full-text-search.md`.
- Every process reaches the DB through a **bounded** connection pool sized under the server ceiling — `per_instance_pool_max × instance_count + other_clients ≤ server_max_connections − reserve` — never a fresh connection per request and never a guessed size. A transaction-mode pooler (pgbouncer/ProxySQL) requires server-prepared statements + session state disabled; serverless functions route through a proxy (RDS Proxy / Data API) with per-invocation pool size 1. See `ai-patterns/connection-pooling.md`.
- Any read routed to a replica tolerates replication lag; read-your-writes and correctness-sensitive reads (auth / authorization / balance / inventory / uniqueness pre-check) go to the **primary** or use a consistency token (primary-pin window / LSN / GTID) — never blindly to a possibly-lagging async replica. Replica lag is monitored and a failover/promotion plan (with an acknowledged RPO for async loss-of-tail) exists. See `ai-patterns/read-replicas.md`.

## Must not

- `synchronize: true` (TypeORM) / `db.create_all()` in production / auto-migrate flags. Schema by migration only.
- Run `ALTER TABLE` that takes ACCESS EXCLUSIVE during peak. Postgres: `ADD COLUMN ... DEFAULT non-volatile` is fast; `DEFAULT volatile_function()` rewrites the table.
- `CREATE INDEX` on a large table without `CONCURRENTLY` (Postgres) — blocks writes. MySQL: use `ALGORITHM=INPLACE, LOCK=NONE`.
- Hold a transaction across an HTTP / queue / external API call. Connection pool will exhaust at peak.
- `SELECT *` on wide rows (BLOB / JSON / TEXT columns) when you need 3 fields. Bandwidth + parse cost.
- Composite index column order chosen randomly. Leftmost prefix matters: `(tenant_id, status, created_at)` serves `WHERE tenant_id = ? AND status = ?`, not `WHERE status = ?`.
- Over-index. Every index slows writes. Drop indexes that don't appear in `pg_stat_user_indexes` / `sys.schema_unused_indexes`.
- Trigger-based business logic without a documented reason — invisible to code review, painful to debug.

## Should

- Run `EXPLAIN ANALYZE` (Postgres) / `EXPLAIN FORMAT=TREE` (MySQL 8) on every new query against a table > 10k rows. Reject Seq Scan / Full Table Scan unless documented.
- CHECK constraints for invariants the app shouldn't have to re-enforce (`CHECK (price >= 0)`, `CHECK (status IN ('pending','paid','cancelled'))`).
- Migrations are reversible (ship a `down`) when feasible. If not, document the forward-fix plan in the migration file header.
- Expand-contract for breaking schema changes: add new column → backfill → switch reads → switch writes → drop old column. Each step ships in its own deploy.
- Read replicas for read-heavy workloads — but route writes + read-your-writes to primary. See `ai-patterns/read-replicas.md`.
- Connection pooler (`pgbouncer` for Postgres, `proxysql` for MySQL) sized to `(cores * 2 + spindles)` per replica, not 1000 per app instance. See `ai-patterns/connection-pooling.md`.
- `pg_stat_statements` (Postgres) / Performance Schema (MySQL) enabled; review slow queries weekly.

## Review checklist

- [ ] New table has PK, `created_at`, `updated_at`, indexes on every FK.
- [ ] Multi-tenant tables have `tenant_id` + composite index leading with `tenant_id`.
- [ ] New query `EXPLAIN`-ed; no Seq Scan / full table scan over 10k rows.
- [ ] Migration is reversible OR forward-fix documented.
- [ ] Migration safe under concurrent writes (no long lock).
- [ ] No `SELECT *` on tables with BLOB/JSON columns.
- [ ] Soft-delete + tenant filters applied where required.
- [ ] Contended read-modify-write is `FOR UPDATE` / version-guarded; Serializable/RR transactions retry on `40001`; multi-row locks ordered consistently.
- [ ] PII columns classified + retention/purge mechanism wired; erasure path resolves every FK (no orphan, no `RESTRICT` block).
- [ ] Text search on a large table uses the engine's FTS primitive (`tsvector`+GIN / `FULLTEXT`) with ranking + a maintenance mechanism; no `LIKE '%x%'` full scan.
- [ ] DB access goes through a bounded pool; `per_instance × instances < max_connections − reserve`; no per-request connect; transaction-mode pooler checked against prepared statements/session state.
- [ ] Replica reads tolerate lag; read-your-writes + auth/balance/uniqueness reads go to primary or a consistency token; replica lag monitored + failover/RPO planned.

## Enforcement

- `sqlfluff` / `pgsanity` / `tbls` lint migrations + schema docs.
- Migration linter (`squawk` for Postgres) blocks unsafe migrations in CI.
- Slow query log enabled in dev + staging (`log_min_duration_statement = 100` in Postgres).
- Backups automated; restore tested at least quarterly. Untested backups don't exist.
