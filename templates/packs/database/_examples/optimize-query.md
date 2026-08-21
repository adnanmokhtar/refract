---
description: Profile and optimize one query (SQL string or endpoint that owns it).
---

# /optimize-query <endpoint|sql>

Profiles a target query, proposes index / rewrite / denormalization, and emits a migration if applicable.

## The Premise (read this first, internalize, do not deviate)

**The slow query is real. The pattern almost always repeats — index miss / N+1 / missing limit / ungated SELECT \*.**

99% of slow queries fall into 4 buckets: (1) missing index on a hot WHERE / ORDER BY / FK, (2) N+1 in the calling code (the SQL is fine, the loop isn't), (3) missing LIMIT on a paginated endpoint, (4) ungated `SELECT *` pulling TOAST columns or wide rows. The 1% novel cases are denormalization candidates that need an ADR. Default to scanning the 4 buckets first — do not invent exotic fixes.

**The agent's job is exactly this:**
1. Capture baseline `EXPLAIN ANALYZE` against prod-shaped data.
2. Identify dominant cost (seq scan / sort / hash join / function-on-indexed-column).
3. Map to one of the 4 patterns. Apply the canonical fix for that pattern.
4. Re-run EXPLAIN. Confirm the index is used, the N+1 collapsed, the LIMIT lands, the column list shrunk.

**The agent does NOT:** jump to denormalization/matview before scanning the 4 buckets; add an index that left-prefix-matches an existing one; propose caching as a primary fix; tune `SELECT *` plans (replace with column list first); skip prod-shaped EXPLAIN validation.

**The agent ONLY asks the user when:** the fix is denormalization/matview (write-cost ADR), an existing index left-prefix-covers the proposal, or the query is rarely-called below SLO threshold.

## Mechanical halt — similar-query-scan

**Before generating the fix, the agent MUST run the similar-query-scan:**

1. Pull the top-20 slow queries from `pg_stat_statements` (or MySQL slow-query log).
2. Match the target query's shape (table set + WHERE column set + ORDER BY column) against those 20.
3. If ≥ 2 siblings share the shape, the fix MUST apply to all of them — emit a single composite index or a single rewrite that covers the family. Single-query fixes when 3 callers share the pattern is index proliferation.
4. If the proposed index left-prefix-matches an existing index on the same table → HALT. Re-derive: extend the existing index or pick a different shape.
5. The validator-equivalent check: `siblings_found = siblings_covered_by_fix`. If unequal → HALT, surface the uncovered siblings.

If similar-query-scan finds zero siblings → the query is novel; proceed with single-fix but note the absence in the report (so the next slow query in this family triggers re-derivation).

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
