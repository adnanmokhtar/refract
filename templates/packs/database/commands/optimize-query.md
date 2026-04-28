---
description: Profile and optimize one query (SQL string or endpoint that owns it).
---

# /optimize-query <endpoint|sql>

Profiles a target query, proposes index / rewrite / denormalization, and emits a migration if applicable.

## Phases applied

All 7. Phase 6 = before/after `EXPLAIN ANALYZE` on prod-shaped data.

## When to use / NOT to use
- USE: slow endpoint surfaced by `/perf-audit` or APM; N+1 detected in code review; pre-launch query review for high-traffic endpoints.
- NOT: rarely-called paths (admin one-offs, batch jobs without SLO).

## Phase 1 — Understand

- Parse `<endpoint|sql>` arg.
- For endpoint: trace controller → service → repo → final SQL via TypeORM/Prisma logging or `LOG=query` env.
- For raw SQL: use directly.
- Success: chosen fix is one of (index / rewrite / denormalize / matview), with EXPLAIN before/after numbers and a migration file (not applied).

## Phase 2 — Organize

- Sub-tasks: capture baseline, identify dominant cost, pick fix shape, generate migration, validate on shadow data.
- Pause for confirmation if fix is denormalization (writes get more expensive — needs ADR).

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` + `ai/conventions.md` — migration tool + folder.
- `ai/patterns/indexing-strategy.md` — when to add composite vs covering.
- `ai/patterns/migrations.md` — concurrent index, expand-contract.

CONTEXT:
- Target table's row count + relevant existing indexes (`\d+ <table>` Postgres or `SHOW INDEX FROM <table>` MySQL).
- Recent migrations for that table (someone may have just added what you're proposing).

## Phase 4 — Generate

Dispatch `query-optimizer` with SQL + table size + existing indexes.

Capture baseline:
```bash
psql -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <SQL>"
# MySQL: EXPLAIN FORMAT=JSON <SQL>
```

Agent identifies dominant cost (seq scan, sort, hash join, function-on-indexed-column) and proposes ONE of:
- Add index (single or composite) — prefer covering for hot reads.
- Rewrite (`OR` → `UNION ALL`, push down WHERE, add LIMIT).
- Denormalize (only with explicit ADR — increases write cost).
- Materialized view (read-mostly aggregations).

Generate migration file in project's migration folder (do NOT apply).

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry with before/after numbers.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/decisions/` — ADR if denormalization or matview chosen.
- `ai/patterns/indexing-strategy.md` — append example if a new index shape recurs.

## Phase 6 — Validate

- Re-run EXPLAIN ANALYZE on a copy of prod-shaped data; report before/after.
- Confirm new index is used (`Index Scan using <name>`).
- For composite index: confirm left-prefix isn't already covered by an existing index.
- Migration reviewed via `/migration-review` before apply.

## Phase 7 — Improve

- If similar slow pattern (e.g. unindexed FK + ORDER BY) appears 3+ times, queue pattern to `ai/dynamic/learned-patterns.md`.
- If the slow query slipped past code review, queue checklist update to `ai/dynamic/feedback-learned.md`.

## Output

```
Query: SELECT * FROM orders WHERE tenant_id = $1 AND created_at > $2 ORDER BY created_at DESC LIMIT 50
Table: orders (~5M rows)

Before:
  Seq Scan on orders  (cost=0.00..142000)  actual time=820ms
  Filter: tenant_id = $1 AND created_at > $2
  Rows removed by filter: 4_950_000

Proposed: composite index (tenant_id, created_at DESC)
  Migration file: prisma/migrations/20260424-add-orders-tenant-created-idx/migration.sql

After (on staging shadow):
  Index Scan using orders_tenant_created_idx  actual time=8ms
```

## Failure modes

- `EXPLAIN ANALYZE` on prod runs the query for real (Postgres always; MySQL with `ANALYZE`) — use snapshot or staging.
- New index on hot OLTP table locks it under MySQL InnoDB; Postgres needs `CREATE INDEX CONCURRENTLY` outside a transaction.
- Index proliferation hurts writes; don't add a 2-col index when an existing 3-col covers it (left-prefix match).
- `SELECT *` plans differ from explicit column lists — pick column lists before tuning.
- Functions on indexed column (`WHERE LOWER(email) = ...`) defeat the index — fix query OR add functional index.
- Caching as a "fix" hides root cause — only after the query itself is reasonable.

## Related

### Sibling commands in database pack
- `/add-migration` — sibling command in database pack
- `/db-audit` — sibling command in database pack
- `/migration-review` — sibling command in database pack

### Patterns
- `ai/patterns/indexing-strategy.md`
- `ai/patterns/migrations.md`
- `ai/patterns/sharding-partitioning.md`

### Rules
- `.claude/rules/database-principles.md`
