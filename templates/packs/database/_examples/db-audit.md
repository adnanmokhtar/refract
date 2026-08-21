---
description: Full DB audit — indexes, bloat, slow queries, soft-delete and tenant filter leakage.
---

# /db-audit [dev|staging]

Health pass on a non-prod DB. Reports findings per check with fixes (and migration SQL where applicable).

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves. Every claim cites `<file:line>` or `<table.column>`.**

An audit report without locations is a hallucination. "There may be missing indexes" is worthless; `orders.tenant_id — FK without index (see migrations/0042-create-orders.sql:18)` is a finding. Every line of the report MUST be a concrete artifact the user can grep, click, or apply a migration to.

**The agent's job is exactly this:**
1. Run each check against the live DB or schema files.
2. For every finding, anchor it: `<file:line>` for code-side leakage, `<table.column>` or `<index_name>` for schema findings, `<query_id>` from `pg_stat_statements` for slow queries.
3. Severity assigned by mechanical rule, not vibes (see closure-verb tiers).

**The agent does NOT:**
- Emit "consider reviewing X" — either it's a finding (with location) or it's not.
- Hand-wave with "potentially slow", "might be unindexed", "could leak". Verify or drop.
- Repeat the same finding under multiple checks (an unindexed FK shows up under "missing indexes", not also under "slow queries" unless it has its own `pg_stat_statements` entry).
- Surface a finding without a fix — every FAIL must include the migration SQL or the code edit.

**The agent ONLY asks the user when:**
- The target DB is ambiguous (`staging` could be prod-alias — confirm before connecting).
- A finding's fix would auto-DROP an index/column (always propose, never apply).
- Stats are too short-window to trust (< 30 days → flag and ask whether to defer or proceed with caveat).

## Mechanical halt — hand-wave grep

See [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). Use the audit report draft as the grep target; anchors are `<file:line>` / `<table.column>` / `<query_id>` per the premise above. **Also** grep for DB-audit tokens: `potentially`, `might`, `may`, `consider`, `could be`, `seems`, `appears to`, `possibly`, `unclear`, `unsure`, `TBD`.

## Phases applied

AUDIT type — 1, 2, 3, 6 dominate. Phase 4 = the report; Phase 5/7 minimal.

## When to use / NOT to use
- USE: quarterly health check; before a feature that adds high-volume tables; after unexplained slow query alerts.
- NOT: prod without written approval and a read-only role.

## Phase 1 — Understand

- Parse `[dev|staging]`. Default dev. If `staging`, double-check it isn't a prod alias.
- Confirm engine (Postgres / MySQL / MariaDB) — checks differ.
- Success: per-check FAIL/WARN/OK with file:line or table name and a concrete fix.

## Phase 2 — Organize

- Plan parallel checks (7 below).
- For unused-index findings: propose DROP migration but never auto-apply.

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` + `.claude/codebase-profile.md` — engine, ORM, multi-tenancy presence.
- `ai/patterns/indexing-strategy.md`, `ai/patterns/multi-tenancy.md`.

ENGINE-SPECIFIC:
- Postgres: `pg_indexes`, `pg_stat_user_indexes`, `pg_stat_statements`, `pgstattuple`.
- MySQL: `information_schema.STATISTICS`, slow-query log.

## Phase 4 — Generate (run checks; produce findings table)

Run checks (parallelizable):
- **Missing indexes** — Postgres: FKs without indexes via `pg_indexes` join `information_schema.table_constraints`; MySQL: `information_schema.STATISTICS`.
- **Unused indexes** — Postgres: `pg_stat_user_indexes WHERE idx_scan = 0` (excluding PKs, unique constraints).
- **Bloat** — Postgres: `pgstattuple` per top-20 largest tables; flag > 20% dead tuples.
- **Slow queries** — Postgres: `pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10`; MySQL: slow-query log tail.
- **Soft-delete leakage** — grep `createQueryBuilder` / raw SQL touching tables with `deletedAt`; flag missing soft-delete WHERE.
- **Tenant leakage** — multi-tenant repos: same scan for queries on tenant-scoped tables missing `tenant_id =` filter.
- **Schema drift** — `prisma migrate diff` / `typeorm schema:log` — non-empty = drift.

Print findings table per check with severity, location, fix.

## Phase 5 — Update

- `ai/audits/<YYYY-MM-DD>-db-audit.md` — full report.
- `ai/status.md` — Recent Changes entry summarizing top blockers.
- `ai/dynamic/drift-log.md` — append schema-drift entries if any.
- For unused-index findings: stage migration file under `migrations/` but tag PROPOSED in filename; user routes through `/migration-review`.

## Phase 6 — Validate

- Re-run any failed check after fix to confirm.
- Verify "unused index" count against ≥ 30 days of stats — short-window data is unreliable.
- Soft-delete leakage findings on raw SQL: read each flagged file manually — dynamic SQL builders escape regex.

## Phase 7 — Improve

- If the same leakage pattern appears in 3+ files, queue rule update to `ai/dynamic/learned-patterns.md`.
- If schema drift is recurring, queue ADR for migration discipline (CI-enforced drift check).

## Output

```
DB audit  target=local-dev  engine=postgres

Missing indexes (FAIL, 2):
  orders.tenant_id           — FK without index
  order_items.product_id     — FK without index

Unused indexes (WARN, 3):
  orders_idx_legacy_status   — 0 scans in 30 days; propose drop after confirming with code search

Bloat (WARN, 1):
  audit_logs                 — 38% dead tuples; VACUUM FULL during off-peak

Slow queries (FAIL, 1):
  SELECT * FROM orders WHERE customer_email LIKE '%@%'  — 4.2s avg, no usable index

Soft-delete leakage (FAIL, 2):
  src/repos/orders.repo.ts:88   — raw query missing deletedAt IS NULL
  src/repos/users.repo.ts:142   — same

Schema drift: NONE
```

## Failure modes

- Auto-running `DROP INDEX` / `DROP COLUMN` — never; propose, confirm, route through `/migration-review`.
- Bloat numbers stale until `ANALYZE` — % is approximate.
- "Unused index" over short window unreliable — verify against ≥ 30 days; new feature indexes look unused.
- Slow query log on dev meaningless — production EXPLAIN plans needed for real fixes.
- Tenant leakage scan misses dynamic SQL built at runtime — manual review on raw query builders is non-skippable.
