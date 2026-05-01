# PostgreSQL reference

> **Engine**: PostgreSQL 14+ / 15 / 16 / 17 (16 is the LTS-equivalent default)
> **Official docs**: https://www.postgresql.org/docs/16/index.html
> **Version-specific gotchas**: PG 16 added logical replication for stand-by + streaming I/O improvements; 15 added MERGE statement, `nullsNotDistinct` for unique indexes; UUID v7 is RFC-9562 — generate via `pg_uuidv7` extension or app-side; `pg_stat_statements` lives in `shared_preload_libraries` (restart needed); `CREATE INDEX CONCURRENTLY` cannot run inside a transaction block.
> **Substitution markers**: Replace `<table>` / `<column>` with the project's actual schema.

## Types to prefer

- `uuid` (v7 via app or extensions) over `integer` PKs
- `timestamptz` always — never `timestamp without time zone`
- `text` over `varchar(N)` when there's no real upper bound
- `numeric(P,S)` for money — never `real`/`double`
- `jsonb` over `json` (indexable, better performance)
- `citext` for case-insensitive unique (emails, slugs)

## Constraints

- Native FK constraints, not just ORM-level
- CHECK constraints for domain invariants (`CHECK (price >= 0)`)
- Native ENUM types are ergonomic but painful to modify; CHECK constraints are more flexible

## Indexes

- `CREATE INDEX CONCURRENTLY` on populated tables (MUST be outside a transaction)
- Partial indexes for hot filters: `CREATE INDEX ... WHERE status = 'active'`
- GIN indexes for jsonb / array / full-text search
- BRIN indexes for very large append-only time-series tables

## Advanced

- Use `CTID` with care in batch updates — it shifts after VACUUM
- `pg_stat_statements` for query profiling — enable in prod
- `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` — richest query plan info
- `pg_stat_user_indexes` to find unused indexes
- `pg_stat_user_tables` for bloat / vacuum health

## Migrations on prod

- Never lock a hot table. Use CONCURRENTLY for indexes.
- For NOT NULL + default on big table: add nullable, backfill in batches, then SET NOT NULL.
- For type change: add new column, dual-write in app, backfill, swap reads, drop old.
- Test migration against a restored prod backup before shipping.
