---
name: indexing-strategy
kind: example
pack: database
---

# Pattern: Indexing Strategy

Indexes make reads fast AND writes slow. Every index has a cost. Add deliberately, measure, remove what doesn't earn its keep.

## When to add an index

- Every foreign key column.
- Columns in `WHERE` for common queries.
- Columns in `ORDER BY` / `GROUP BY` for common queries.
- Columns in `JOIN` conditions.
- Columns with high selectivity being filtered (don't index `boolean is_active` alone — low selectivity).

## When NOT to add an index

- Tiny tables (< 1000 rows). Seq scan is faster.
- Low-selectivity columns alone (gender, boolean flags).
- Write-heavy tables with queries that rarely hit the column.
- As "insurance" before measuring need.

## Index types

### B-tree (default)
For equality + range + ORDER BY.
```sql
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_created_desc ON orders(created_at DESC);
```

### Composite (multi-column)
Order MATTERS — leftmost prefix rule.
```sql
CREATE INDEX idx_orders_tenant_status_created
  ON orders(tenant_id, status, created_at DESC);
```
This serves:
- `WHERE tenant_id = ?` ✓
- `WHERE tenant_id = ? AND status = ?` ✓
- `WHERE tenant_id = ? AND status = ? ORDER BY created_at DESC` ✓ (huge win)
- `WHERE status = ?` ✗ (not leftmost — doesn't use this index)

### Covering (include columns)
PG 11+: `INCLUDE` clause stores extra columns in the index — no heap fetch needed.
```sql
CREATE INDEX idx_orders_tenant_created
  ON orders(tenant_id, created_at DESC)
  INCLUDE (status, total_amount);
```
Query `SELECT tenant_id, created_at, status, total_amount WHERE tenant_id = ?` is index-only.

### Partial
Only indexes rows matching a WHERE clause. Smaller, faster.
```sql
CREATE INDEX idx_orders_pending
  ON orders(created_at)
  WHERE status = 'pending';
```
Great for: hot-partition queries, soft-delete filter (`WHERE deleted_at IS NULL`).

### Expression / functional
For queries on computed expressions.
```sql
CREATE INDEX idx_users_lower_email ON users(LOWER(email));
-- Serves: WHERE LOWER(email) = 'foo@bar.com'
```

### Unique
Enforces uniqueness + serves as a regular index.
```sql
CREATE UNIQUE INDEX idx_users_email_lower ON users(LOWER(email));
```

### GIN (Postgres)
For jsonb, arrays, full-text search.
```sql
CREATE INDEX idx_products_tags ON products USING GIN (tags);  -- jsonb/array column
CREATE INDEX idx_docs_tsvector ON docs USING GIN (to_tsvector('english', body));
```

### BRIN (Postgres)
For huge append-only tables where rows are physically clustered by the index column.
```sql
CREATE INDEX idx_events_created_brin ON events USING BRIN (created_at);
```
Tiny index size (KB even on billion rows), great for time-series.

### Hash (rare)
Postgres 10+: decent for equality-only. Rarely chosen over B-tree.

## Composite index design

Put columns in order of:
1. **Equality conditions first** (`tenant_id = ?`)
2. **Then the next equality or range** (`status = ?` or `created_at >= ?`)
3. **Then the `ORDER BY` column** (`created_at DESC`)

Why: the planner walks the index in order. Range scans don't help with columns to their right.

## Covering indexes for frequently-used queries

If a query fetches 3-4 specific columns, make an index that includes all of them:
- Index-only scan (no heap fetch).
- 2-10x faster depending on row size.

Tradeoff: larger index, slower writes.

## Index maintenance

- Rebuild bloated indexes (`REINDEX CONCURRENTLY` in PG).
- Autovacuum handles dead tuples; check `pg_stat_user_tables` for lag.
- Stats keep accurate query plans: `ANALYZE` after big data changes.

## Detect missing indexes

```sql
-- Postgres: sequential scans on large tables
SELECT schemaname, relname, seq_scan, seq_tup_read, idx_scan
FROM pg_stat_user_tables
WHERE seq_scan > idx_scan AND n_live_tup > 100000
ORDER BY seq_tup_read DESC;
```

## Detect unused indexes

```sql
SELECT schemaname, relname, indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname NOT IN ('pg_catalog', 'pg_toast')
ORDER BY pg_relation_size(indexrelid) DESC;
```
Zero scans for a month + non-unique + non-FK = candidate for drop.

## Index size budget

- Every index adds bytes per row + overhead.
- A typical table with 5 indexes: indexes sum to ~50-100% of table size.
- Rule of thumb: if indexes > 3x table size, you have too many.

## Adding on large tables

Postgres: `CREATE INDEX CONCURRENTLY` — MUST be outside a transaction, slower but non-blocking.
MySQL: `CREATE INDEX` blocks on most engines / versions — use `pt-online-schema-change` / `gh-ost` on large tables.

## Observability

- Query `EXPLAIN ANALYZE` on new indexes — did it use the index?
- Track index scan counts over time (growing = good, flat = consider dropping).
- Alert on sudden drop in index usage (stats broken or query changed).

## Forbidden

- Adding indexes without measuring the query pattern.
- Indexes on every column "just in case".
- Missing FK indexes (PG and MySQL often don't auto-create them).
- Unique index on a frequently-updated column (write amplification).
- Ignoring `EXPLAIN ANALYZE` output because "the index should help" — measure.
- Dropping indexes based on `idx_scan = 0` during a quiet period (check a full cycle first).
