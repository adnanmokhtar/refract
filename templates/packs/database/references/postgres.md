# PostgreSQL reference

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
