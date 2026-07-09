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
- Read replicas for read-heavy workloads — but route writes + read-your-writes to primary.
- Connection pooler (`pgbouncer` for Postgres, `proxysql` for MySQL) sized to `(cores * 2 + spindles)` per replica, not 1000 per app instance.
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

## Enforcement

- `sqlfluff` / `pgsanity` / `tbls` lint migrations + schema docs.
- Migration linter (`squawk` for Postgres) blocks unsafe migrations in CI.
- Slow query log enabled in dev + staging (`log_min_duration_statement = 100` in Postgres).
- Backups automated; restore tested at least quarterly. Untested backups don't exist.
