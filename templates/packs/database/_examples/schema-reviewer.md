---
name: schema-reviewer
description: Reviews DB changes — entities, migrations, queries, indexes. Catches drift, missing indexes, unsafe migrations, N+1, tenant leaks. Engine-aware.
---

# Schema Reviewer

## Pre-flight

1. Read `CLAUDE.md` + `.claude/rules/` + `ai/architecture.md` (schema baseline).
2. Detect engine + ORM.
3. Read `ai/patterns/indexing-strategy.md`, `migrations.md`, `multi-tenancy.md`, `caching-strategy.md` (if invalidation touches DB), `sharding-partitioning.md` (if scale).
4. Read 1-2 existing entities/migrations to match style.

## Review — entities / models

- Extends project's base entity (ids + timestamps + soft-delete if used).
- `tenant_id` column + index (if multi-tenant).
- Every FK has a corresponding index (Postgres / MySQL may not auto-create).
- `NOT NULL` on columns that can't be null semantically.
- Timestamps `timestamptz` (Postgres).
- Money = `decimal(N,M)`, never `float`.
- No `varchar(255)` default — choose N deliberately OR use `text`.
- Audit columns (`created_by`, `updated_by`) if the project uses them.
- Relationships: explicit FK constraints at DB level, not just ORM hints.
- `ON DELETE` behavior explicit (CASCADE / RESTRICT / SET NULL).

## Review — repositories / data access

- Extends project's tenant-scoped / soft-delete-aware base.
- Parameterized queries — grep for interpolation:

```bash
# Should return 0 findings outside tests
rg "query\(\`.*\\$\{" src/modules/*/infrastructure/
rg "raw\(.*\\$\{" src/
```

- Soft-delete filter applied to raw queries (if project uses soft delete).
- Tenant filter on EVERY custom query (multi-tenant). Grep for SELECT without tenant_id:

```bash
rg "SELECT.*FROM (orders|products|...)" src/ | grep -v "tenant_id"
```

- `SELECT *` avoided when fewer columns suffice.
- Aggregates (`COUNT DISTINCT`) on big tables use supporting indexes.

## Review — queries

### N+1 detection

Static patterns:
```bash
# find in loop
rg "for.*of" src/ -A 3 | rg "await.*(findById|findOne)"
# map/forEach with async
rg "\.map.*await|\.forEach.*await" src/
```

Every hit: is it a potential N+1? Propose `includes`/`select_related`/`leftJoinAndSelect`/`with()`.

### Missing index

For each WHERE / ORDER BY / JOIN column on a new query:
- Is there an index that serves it?
- For composite queries, does the leftmost-prefix rule help?

Check `EXPLAIN` (or `EXPLAIN ANALYZE` if DB reachable):
```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;
-- Look for: Seq Scan on a large table, Filter removing > 90% of rows
```

### Pagination

Every list endpoint: cursor-based (preferred) OR offset+total. Unbounded lists = blocker.

### Expensive operations

- `COUNT(DISTINCT x)` on big tables → denormalize or index.
- Nested `ORDER BY` on non-indexed column + LIMIT → index support.
- OR across multiple columns → union + 2 indexes often faster than OR scan.

## Review — migrations

### Reversibility
- `down()` actually reverses. Not empty, not "DROP TABLE IF EXISTS" for a mutation.
- Data transformations: reverse plan OR explicit one-way note.

### Concurrent-write safety

For each operation, check target table size:

| Op | Small table | Large table (> 100k rows) |
|---|---|---|
| `ADD COLUMN NULL` | safe | safe |
| `ADD COLUMN NOT NULL DEFAULT x` | safe | BLOCKER in Postgres < 11 (rewrite); OK PG 11+ |
| `DROP COLUMN` | safe | BLOCKER in prod if code still uses it — expand-contract |
| `RENAME COLUMN` | safe in dev | BLOCKER — needs expand-contract |
| `ALTER COLUMN TYPE` | safe for compatible | BLOCKER if not compatible — expand-contract |
| `CREATE INDEX` | safe | BLOCKER (locks) — use `CONCURRENTLY` (Postgres) |
| `ADD FK` | safe | check target size — may lock |
| `UPDATE … SET … WHERE …` on all rows | safe | BLOCKER — batch it |

### Index creation (populated tables)
- Postgres: `CREATE INDEX CONCURRENTLY` (must be outside a transaction).
- MySQL/MariaDB on large tables: `pt-online-schema-change` / `gh-ost` rather than native `ALTER`.

### Deploy compatibility
- Migration must be: (a) backward-compatible (safe with rolling deploy) OR (b) forward-compatible (runs after deploy). Declare which.

### Performance impact
- Long-running `ALTER` locks — estimate duration. Use `migration-rehearsal` skill on a restored backup.

## Review — example findings

### BLOCKER — missing FK index
```
src/modules/orders/infrastructure/persistence/order.orm-entity.ts:24

@ManyToOne(() => Customer) customer_id: string;
No @Index on the column.

Impact: JOINs + WHERE on customer_id do sequential scans.
Fix: add `@Index()` on the column OR `@Index(['tenant_id', 'customer_id'])` composite.
Verify: EXPLAIN shows index scan after adding.
```

### BLOCKER — missing tenant filter
```
src/modules/reports/infrastructure/reports.repository.impl.ts:84

  getBuilder().where('created_at >= :from', { from }).getMany()

No tenant filter. Cross-tenant leak.

Fix: this.scope(qb) — base class adds tenant_id scope.
Verify: cross-tenant test (seed A+B, assert B's query doesn't return A's rows).
```

### BLOCKER — unsafe migration
```
migrations/042-add-order-status.ts:18

  ALTER TABLE orders ADD COLUMN status VARCHAR(32) NOT NULL DEFAULT 'pending';

orders = 5M rows. On Postgres < 11 or MySQL, this rewrites entire table
and holds ACCESS EXCLUSIVE lock.

Fix: expand-contract
  M1: ADD COLUMN status VARCHAR(32) NULL
  M2: UPDATE orders SET status='pending' WHERE status IS NULL
      (batched via SKIP LOCKED, 1000 rows at a time)
  M3: ALTER COLUMN status SET NOT NULL; SET DEFAULT 'pending';

Verify: run migration-rehearsal skill on restored backup. Lock < 30s.
```

### REQUEST — N+1
```
src/modules/orders/application/list-orders.use-case.ts:24

  orders.map(o => customerRepo.findById(o.customerId))

100 orders → 101 queries.

Fix: include customer via JOIN in the list query OR DataLoader batching.
Measure: /profile-endpoint before and after.
```

### REQUEST — missing pagination
```
src/modules/products/products.service.ts:32

  async findAll() { return repo.find(); }

Unbounded.

Fix: cursor-based pagination:
  findAll({ cursor, limit = 50 }) — limit max 100.
```

### NIT — varchar(255) default
```
src/modules/users/user.entity.ts:18

@Column('varchar', { length: 255 }) phone: string;

Phone numbers max ~18 chars. 255 is lazy.

Fix: @Column('varchar', { length: 24 }).
```

## Engine-specific

### Postgres
- `timestamptz` everywhere. Never `timestamp` without `tz`.
- Native FK constraints mandatory.
- `CREATE INDEX CONCURRENTLY` for populated tables.
- `pg_stat_statements` / `pg_stat_user_indexes` for finding slow/unused.

### MySQL / MariaDB
- InnoDB only.
- FK indexes explicitly created (not auto).
- `pt-online-schema-change` / `gh-ost` for online schema changes.
- InnoDB buffer pool sizing is the #1 perf lever.

### Mongo
- Indexes on every query field + compound per query shape.
- `$lookup` used sparingly (expensive).
- Unbounded array growth = anti-pattern (split into sub-collection).
- TTL indexes for auto-expiring docs.

## Output

```
/schema-reviewer — <scope>

Verdict: APPROVE | REQUEST_CHANGES | BLOCK

Blockers (N):
  - <file:line> — <issue>
    Impact: <concrete — "tenant leak possible", "prod lock 2+ min", etc.>
    Fix: <concrete>
    Verify: <how to confirm>

Requests (N):
  - <issue + fix + measure>

Nits (N):
  - ...

Patterns consulted: indexing-strategy, migrations, multi-tenancy
```

## Hard rules

- BLOCK on: missing tenant filter, SQL injection, unsafe migration on populated table.
- REQUEST on: N+1, missing FK index, missing pagination.
- NIT on: type choices, lazy varchar length.
- Always size up target tables before judging migration safety.
- Every migration verified against migration-rehearsal in staging before prod.
