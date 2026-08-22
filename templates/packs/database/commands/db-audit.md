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
- Repeat the same finding under multiple checks (an unindexed access path shows up under check 1, not also under "slow queries" unless it has its own digest entry).
- Surface a finding without a fix — every FAIL must include the migration SQL or the code edit.

**The agent ONLY asks the user when:**
- The target DB is ambiguous (`staging` could be prod-alias — confirm before connecting).
- A finding's fix would auto-DROP an index/column (always propose, never apply).
- Stats are too short-window to trust (< 30 days → flag and ask whether to defer or proceed with caveat).

## Closure-verb tiers (mandatory dispatch table)

| Severity | Closure | User prompt? |
|---|---|---|
| **FAIL P0** — tenant leakage on write path, soft-delete bypass on user-facing query, schema drift in prod | `escalate` | YES — halt, surface, wait |
| **FAIL P1** — an access path with no index that the worth-it verdict clears (`indexing-strategy.md`), a query taking a material share of total exec time with a fixable plan, dead space over the engine's own remediation threshold on a top-20 table | `report-with-fix` (migration SQL or code edit) | NO — include in report |
| **WARN P2** — unused or redundant index (≥ 30 days of stats), moderate dead space, soft-delete on a read-only path | `report-with-proposal` (PROPOSED migration, never auto-apply) | NO — include in report |
| **OK** — check passed | `report-line` | NO |
| Stats < 30 days OR target ambiguous OR auto-DROP would be required | `escalate` | YES — halt before report |

**Forbidden:** the audit MUST NOT emit findings without `<file:line>` or `<table.column>` anchors. Hand-waves are ejected at validation. The Phase 6 self-audit ("did every finding have a location?") is the gate.

## Mechanical halt — hand-wave grep

See [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). Use the audit report draft as the grep target; anchors are `<file:line>` / `<table.column>` / `<query_id>` per the premise above. **Also** grep for DB-audit tokens: `potentially`, `might`, `may`, `consider`, `could be`, `seems`, `appears to`, `possibly`, `unclear`, `unsure`, `TBD`.

## Lightweight default

**Default closure is anchored-finding emission, no chatter.** The agent does NOT pause to ask "should I report X?" on a P1 / P2 finding — it emits with anchor + fix and lets the user route through `/migration-review` for the destructive ones. Mid-run prompts are a token-waste anti-pattern.

```
Auto-emitted (no prompt): <N> FAIL + <M> WARN with anchors
  - orders.tenant_id              — FK without index (migrations/0042:18)
  - audit_logs                    — <pct>% dead tuples (pgstattuple snapshot)
  - src/repos/orders.repo.ts:88   — raw query missing deletedAt IS NULL
Escalated to user: <K>
  - schema drift in prod (requires devops sync)
  - 2 unused-index DROPs (PROPOSED, route via /migration-review)
```

## Phases applied

AUDIT type — 1, 2, 3, 6 dominate. Phase 4 = the report; Phase 5/7 minimal.

## Honesty clause

No finding without the artifact behind it: every FAIL/WARN cites a real `<file:line>` / `<table.column>` / `<query_id>` the agent actually queried — no inferred or remembered locations (per `migration-rehearsal`'s "no number without a real timed run" discipline, applied to audit numbers). A dead-space %, slow-query timing, or unused-index count is reported only from a real read of the engine's own object (per the Phase-4 table); if a check could not run (DB unreachable, extension absent, `performance_schema` off, short window), it is reported as `not run — <object> unavailable`, never as OK or with a guessed number. **A finding about a mechanism the engine does not have — vacuum or dead-tuple bloat on InnoDB — is a fabrication, not a false positive.**

## When to use / NOT to use
- USE: quarterly health check; before a feature that adds high-volume tables; after unexplained slow query alerts.
- NOT: prod without written approval and a read-only role.

## Phase 1 — Understand

- Parse `[dev|staging]`. Default dev. If `staging`, double-check it isn't a prod alias.
- Confirm engine **and version** (Postgres / MySQL / MariaDB) — two of the seven checks are a different check on each engine, not a translation of the same one.
- Success: per-check FAIL/WARN/OK with file:line or table name and a concrete fix.

## Phase 2 — Organize

- Plan parallel checks (7 below).
- For unused-index findings: propose DROP migration but never auto-apply.

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` + `.claude/codebase-profile.md` — engine, ORM, multi-tenancy presence.
- `ai/patterns/indexing-strategy.md`, `ai/patterns/multi-tenancy.md`.

ENGINE-SPECIFIC (the check table below names the exact object per engine):
- Postgres: `pg_indexes`, `pg_stat_user_indexes`, `pg_stat_statements`, `pgstattuple`, `pg_stat_user_tables`.
- MySQL / MariaDB: the `sys` schema (`schema_unused_indexes`, `schema_redundant_indexes`, `schema_tables_with_full_table_scans`), `performance_schema.events_statements_summary_by_digest`, `information_schema.TABLES`/`STATISTICS`.
- If an engine's required object is absent (extension not installed, `performance_schema` off, sys schema missing), that check is `not run — <object> unavailable`. Never substitute the other engine's object, and never report OK for a check that did not run.

## Phase 4 — Generate (run checks; produce findings table)

Run the checks (parallelizable). **Every check names a real object on both engines, or it is `not run`.** Two of them are not the same check on both engines — read the MySQL column, do not translate the Postgres one.

| # | Check | Postgres | MySQL / MariaDB (InnoDB) |
|---|---|---|---|
| 1 | **FK index coverage** | FKs with no index — `pg_indexes` joined to `information_schema.table_constraints`. Postgres does **not** auto-create these | **The finding inverts, into nothing to report.** InnoDB *does* create the FK index automatically, so a missing one is rare — and it is not a redundancy either: a later composite that leads with the FK column may already have caused the engine to drop it, and one that does not lead with it leaves the single-column index **required**. Check `SHOW INDEX` before reporting, and check the FK list before proposing any `sys.schema_redundant_indexes` drop |
| 2 | **Unused indexes** | `pg_stat_user_indexes WHERE idx_scan = 0`, excluding PKs and unique constraints | `SELECT * FROM sys.schema_unused_indexes;` |
| 3 | **Dead space** | Bloat — `pgstattuple` on the top-20 largest tables, flag > 20% dead tuples; cross-check autovacuum lag in `pg_stat_user_tables` | **Different mechanism — not bloat, and there is no vacuum.** The InnoDB analog is fragmentation: `SELECT TABLE_NAME, DATA_LENGTH, DATA_FREE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() ORDER BY DATA_FREE DESC;`. The remedy is `OPTIMIZE TABLE`, which for InnoDB "is mapped to an `ALTER TABLE` operation to rebuild the table" — a full rebuild, so it routes through `/migration-review`, never into this report as a quick fix |
| 4 | **Slow queries** | `pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10` | `SELECT DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT FROM performance_schema.events_statements_summary_by_digest ORDER BY SUM_TIMER_WAIT DESC LIMIT 10;` plus `sys.statements_with_full_table_scans`. The slow-query log is the fallback when `performance_schema` is off |
| 5 | **Soft-delete leakage** | grep `createQueryBuilder` / raw SQL touching tables with `deletedAt`; flag the missing predicate | same — code-side check, engine-independent |
| 6 | **Tenant leakage** | multi-tenant repos: same scan for queries on tenant-scoped tables missing the `tenant_id =` filter | same — code-side check, engine-independent |
| 7 | **Schema drift** | `prisma migrate diff` / `typeorm schema:log` — non-empty = drift | same tooling; for a tool-less repo, `mysqldump --no-data --skip-comments` diffed against the committed schema (see the `schema-diff` skill) |

- **Schema consistency** — runs the `schema-consistency-audit` skill (naming / type / timestamp / timezone / charset / nullability drift across tables). Fold its findings under their own "Schema consistency" section.

**Every slow-query finding reports the query's share of total execution time**, not only its absolute latency. An absolute figure alone cannot say whether fixing it is worth anything; both engines expose the total in the same query (`indexing-strategy.md` § Input 1), and that share is the input the index decision needs downstream.

Print findings table per check with severity, location, fix.

### Dispatch (deep checks)

Run the seven inline checks, then dispatch two specialists in parallel — the audit's findings table is the union of inline checks + both agents' reports (folded under their own sections, de-duped against inline findings):

- **`schema-reviewer`** — with the schema files + multi-tenancy declaration. Owns the tenant-filter-leak and soft-delete-bypass scans (the leakage checks above are its mechanical surface; it confirms each `<file:line>` and catches the dynamic-SQL cases regex misses). Folds in under "Schema / leakage review".
- **`database-optimizer`** — with engine + version + the engine-appropriate health snapshot, scoped to **surfaces that exist on that engine**. Postgres: bloat trend, autovacuum scale-factor, dead-tuple accumulation, index usage, parameter-group deltas. MySQL / InnoDB: **no vacuum, no dead-tuple bloat** — dispatch instead with buffer-pool hit rate, fragmentation (`DATA_FREE`), redundant indexes, and parameter deltas, and name that scoping in the dispatch line. Asking an agent for vacuum findings on InnoDB produces confident advice about a mechanism the engine does not have. Folds in under "DB-layer health". This is the command that exercises `database-optimizer`.

Both run read-only: they emit anchored findings + PROPOSED fixes; neither applies anything (db-audit never writes to the DB).

## Phase 5 — Update

- `ai/audits/<YYYY-MM-DD>-db-audit.md` — full report.
- `ai/status.md` — Recent Changes entry summarizing top blockers.
- `ai/dynamic/drift-log.md` — append schema-drift entries if any.
- For unused-index findings: stage migration file under `migrations/` but tag PROPOSED in filename; user routes through `/migration-review`.

## Phase 6 — Validate

- Verify "unused index" count against ≥ 30 days of stats — short-window data is unreliable, and a monthly or quarterly job makes an index look dead 29 days out of 30. Exclude unique constraints and (on Postgres) the indexes backing foreign keys.
- Verify every engine-specific object actually existed. A check that could not run is reported `not run — <object> unavailable`, never as OK.
- Soft-delete leakage findings on raw SQL: read each flagged file manually — dynamic SQL builders escape regex.

## Phase 7 — Improve

- If the same leakage pattern appears in 3+ files, queue rule update to `ai/dynamic/learned-patterns.md`.
- If schema drift is recurring, queue ADR for migration discipline (CI-enforced drift check).

## Output

```
DB audit  target=local-dev  engine=<engine> <version>

Missing indexes (FAIL, 2):
  orders.tenant_id           — FK without index
  order_items.product_id     — FK without index

Unused indexes (WARN, 3):
  orders_idx_legacy_status   — 0 scans in 30 days; propose drop after confirming with code search

Dead space (WARN, 1):
  audit_logs                 — <pct>% dead tuples (PG) / <bytes> DATA_FREE (InnoDB);
                               remedy is a table rebuild — route via /migration-review

Slow queries (FAIL, 1):
  SELECT * FROM orders WHERE customer_email LIKE '%@%'
                             — <pct>% of total exec time over <calls> calls; no usable index
                               (leading-wildcard LIKE is full-text-search territory, not a b-tree gap)

Soft-delete leakage (FAIL, 2):
  src/repos/orders.repo.ts:88   — raw query missing deletedAt IS NULL
  src/repos/users.repo.ts:142   — same

Schema drift: NONE
```

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (correctness / data-integrity / blocking-perf) → **SHOULD FIX** (meaningful perf wins) → **OPTIONAL** (housekeeping) — each step carrying `<file:line>`/object + **Fix** (concrete; index/migration proposals route through `/migration-review`) + **Verify**, then the closing steps (re-run `/db-audit` to confirm it comes back clean, `/learn-from-task`, then ship). A clean run collapses to a single line ("No findings — clear to proceed"). The reader must never assemble the next steps themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Auto-running `DROP INDEX` / `DROP COLUMN` — never; propose, confirm, route through `/migration-review`.
- Postgres bloat numbers are stale until `ANALYZE` — the % is approximate. InnoDB has no bloat at all; reporting one there is a fabricated finding.
- "Unused index" over short window unreliable — verify against ≥ 30 days; new feature indexes look unused.
- Slow query log on dev meaningless — production EXPLAIN plans needed for real fixes.
- Tenant leakage scan misses dynamic SQL built at runtime — manual review on raw query builders is non-skippable.

## Related

### Sibling commands in database pack
- `/add-migration` — sibling command in database pack
- `/migration-review` — sibling command in database pack
- `/optimize-query` — sibling command in database pack

### Agents
- `@schema-reviewer` — dispatched in Phase 4 for tenant-filter-leak + soft-delete-bypass review.
- `@database-optimizer` — dispatched in Phase 4 for DB-layer health, scoped to the surfaces the project's engine actually has.

### Skills
- `schema-consistency-audit` — dispatched in Phase 4 for schema-consistency findings (naming / type / index / audit-field / soft-delete drift).

### Patterns
- `ai/patterns/indexing-strategy.md`
- `ai/patterns/migrations.md`
- `ai/patterns/sharding-partitioning.md`

### Rules
- `.claude/rules/database-principles.md`
