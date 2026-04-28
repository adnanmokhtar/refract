---
description: Generate a safe, reversible, deploy-compatible DB migration. Expand-contract for breaking changes on populated tables. Rehearsed against realistic data before prod.
---

# /add-migration

Migrations are the highest-risk code in a repo. One bad migration = hours of prod pain. This command enforces the discipline.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## When to use / NOT to use

- USE: schema change (add/drop/alter column or table).
- USE: data migration (backfill, transformation).
- USE: index addition / removal.
- NOT: mutating data via app code (use a use-case).
- NOT: experimental schema changes (prototype in a branch DB first).

## Phase 1 — Understand (the change)

Ask (one consolidated question):
- What changes? (add column / rename / drop / add table / add index / data transformation / ...)
- Target table(s) + current size (rows + bytes).
- Multi-tenant? (tenant filter on new indexes.)
- Deploy compatibility: backward-compat (app works post-mig) or forward-compat (app deploys first)?

State the success criteria: a reversible, concurrent-write-safe migration (or expand-contract sequence) that ships with rehearsal evidence.

## Phase 2 — Organize (classify + choose pattern)

### Classify the operation

| Op | Small table (<100k) | Populated table (>100k) | Production-scale (>10M) |
|---|---|---|---|
| `ADD COLUMN NULL` | safe | safe | safe |
| `ADD COLUMN NOT NULL DEFAULT` | safe | PG 11+: safe; MySQL/MariaDB: unsafe (rewrite) | same |
| `ALTER COLUMN TYPE` | safe if compatible | unsafe if not exact — expand-contract | dangerous |
| `DROP COLUMN` | safe at rest; dangerous if code reads it | unsafe (expand-contract) | unsafe |
| `RENAME COLUMN` | dangerous (code breaks) | unsafe (expand-contract) | unsafe |
| `ADD FOREIGN KEY` | safe | verify no orphans first; lock scan | use `NOT VALID` + validate later |
| `CREATE INDEX` | safe | unsafe (locks) — use `CONCURRENTLY` (Postgres) | mandatory `CONCURRENTLY` |
| `CREATE UNIQUE INDEX` | verify no dupes | unsafe — find dupes first | validate online first |
| `UPDATE all rows` | safe | unsafe — batch with `SKIP LOCKED` | mandatory batching |
| `DROP TABLE` | safe if unused | unsafe if any code refers | unsafe |

### Choose the pattern

**Simple additions (new column NULL, new table)**: single migration.

**Breaking changes**: expand-contract, split into N migrations + app code phases.

#### Add NOT NULL with default
```
M1: ALTER TABLE t ADD COLUMN x <type> NULL;
     (app keeps reading without x)
App: dual-write x on every write.
M2: UPDATE t SET x = <expr> WHERE x IS NULL;
     (batched, SKIP LOCKED, 1000 rows per batch, run off-peak or via rate-limited job)
M3: ALTER TABLE t ALTER COLUMN x SET NOT NULL;
     ALTER TABLE t ALTER COLUMN x SET DEFAULT <default>;
App: read/write x only.
```

#### Rename column
```
M1: ADD COLUMN new_name <type>;
App: dual-write old_name + new_name.
M2: backfill new_name = old_name (batched).
App: read new_name, write both.
App: read + write new_name only.
M3: DROP COLUMN old_name;
```

#### Change type (incompatible)
Same pattern as rename.

#### Add unique on populated column
```
# Verify no existing duplicates
SELECT col, COUNT(*) FROM t GROUP BY col HAVING COUNT(*) > 1;

# Then create
CREATE UNIQUE INDEX CONCURRENTLY ...
```

#### Add FK on populated table (Postgres)
```
# Use NOT VALID to avoid scan at constraint creation
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (parent_id) REFERENCES parent(id) NOT VALID;

# Then validate in a second migration, faster than adding fully:
ALTER TABLE child VALIDATE CONSTRAINT fk_name;
```

### Index-creation strategy

- **Postgres populated tables**: `CREATE INDEX CONCURRENTLY` — must be outside a transaction. TypeORM / Prisma may need a raw migration.
- **MySQL / MariaDB populated tables**: `pt-online-schema-change` or `gh-ost`. Native `ALTER` locks / rewrites.
- **New tables**: regular `CREATE INDEX` in same migration fine.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

DB-SPECIFIC:
- `ai/patterns/migrations.md`, `indexing-strategy.md`, `zero-downtime-deploys.md`.
- Detect engine + migration tool (TypeORM / Prisma / Alembic / Django / Flyway / goose / Laravel / Rails).
- Size up target table(s): `SELECT COUNT(*), pg_total_relation_size(...)` — migration safety depends on size.
- Read existing migrations in the repo — match naming + style.
- The ORM entity / schema file the migration will sync with.

## Phase 4 — Generate (the migration file)

Per tool:

- **TypeORM**: `pnpm migration:generate -- src/migrations/<Name>` (auto from entity diff) then EDIT.
- **Prisma**: `prisma migrate dev --name <name>` (dev); `prisma migrate deploy` (prod).
- **Alembic**: `alembic revision --autogenerate -m "<name>"` then EDIT.
- **Django**: `python manage.py makemigrations` then EDIT if needed.
- **Laravel**: `php artisan make:migration <name>`.
- **Rails**: `rails generate migration <Name>`.
- **Raw (Flyway / goose / sqlx)**: write `up` + `down` files by hand.

Review the generated file:

- `up()` / `down()` both present.
- `down()` ACTUALLY reverses (not empty, not `DROP TABLE IF EXISTS` for a mutation).
- Concurrent-write safety matches target size (see classification above).
- Index creation uses `CONCURRENTLY` where needed.
- No mixing of schema + data in one migration (separate files).
- Single deploy concern per migration (schema OR data OR index).

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/architecture.md` schema section reflects new state.
- `ai/status.md` Recent Changes entry mentioning the migration + deploy-compatibility declaration.
- ADR if an architectural decision was made (new table introducing a new module, schema pattern change).
- `ai/dynamic/changelog.md` one-line summary.
- If multi-step expand-contract → document the deploy plan in `ai/runbooks/<slug>-deploy.md`.

## Phase 6 — Validate (rehearse + safety check)

### Rehearse (populated tables, mandatory)

Run `migration-rehearsal` skill:
- Restore a prod backup (anonymized if regulated).
- Apply the migration; measure duration + locks held.
- Test app compatibility post-migration.
- Apply `down()` — confirm reversibility.
- Report: is forward < SLO? Is rollback clean?

### Safety checklist

- ✓ Reversible (down() restores state)
- ✓ Concurrent-write safe (no long locks)
- ✓ Index creation uses CONCURRENTLY (Postgres populated)
- ✓ Data step batched with SKIP LOCKED
- ✓ Schema ≠ data in same file
- ✓ No `synchronize: true` / auto-migrate path

### Verify with `schema-diff` skill — entity matches DB after migration.

If any check fails: HALT, report the failure, do not paper over.

## Phase 7 — Improve (feed the learning loop)

- If this migration revealed a NEW expand-contract recipe (e.g., specific to project's ORM quirks): queue to `ai/dynamic/learned-patterns.md`.
- If rehearsal surfaced a slow-down (e.g., index creation took 10x expected time on production-like data): append to `ai/dynamic/drift-log.md` for capacity planning.
- If a coordination concern arose (devops needs to know about multi-step deploy): mention in handoff + queue to `ai/dynamic/decisions-pending.md` if it warrants an ADR.
- Run `/learn-from-task` post-migration.

## Example — complex migration design

User asks: "add `status` column to `orders` (5M rows), values from a fixed list".

Single-migration approach REJECTED (would lock orders for minutes). Proposed:

```
Migration 001: add-orders-status-nullable
  ALTER TABLE orders ADD COLUMN status VARCHAR(32) NULL;
  -- safe: instantaneous

App deploy 1:
  - On write: set status = <computed default based on row state>.
  - On read: tolerate NULL (treat as 'pending').

Migration 002: backfill-orders-status (DATA migration)
  -- Separate script, batched:
  UPDATE orders SET status = 'pending'
  WHERE id IN (
    SELECT id FROM orders WHERE status IS NULL
    FOR UPDATE SKIP LOCKED
    LIMIT 1000
  );
  -- Loop with sleep 100ms between batches, run off-peak.
  -- Monitor: rows remaining. When 0, proceed.

App deploy 2:
  - Read + write status only. Stop computing fallback.

Migration 003: enforce-orders-status-not-null
  ALTER TABLE orders ALTER COLUMN status SET NOT NULL;
  ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'pending';
  ALTER TABLE orders ADD CONSTRAINT orders_status_check
    CHECK (status IN ('pending', 'paid', 'shipped', 'cancelled'));

Migration 004 (optional, index): add-orders-status-index
  CREATE INDEX CONCURRENTLY idx_orders_tenant_status_created_desc
    ON orders (tenant_id, status, created_at DESC);
  -- CONCURRENTLY on 5M rows: ~2-5 minutes.
```

Total deploy: 4 migrations + 2 app deploys over ~1 week.

## Output

```
✅ Migration generated: <name>

Phase 1 (Understand): ADD COLUMN status to orders (5.2M rows), fixed enum.
Phase 2 (Organize): expand-contract — 3 migrations + 2 app deploys.
Phase 3 (Retrieved): migrations.md, indexing-strategy.md, zero-downtime.md, 7 universals.
Phase 4 (Generated): migrations/<NNNN>-<slug>.ts (or equivalent).
Phase 5 (Updated): ai/status.md Recent Changes, ai/architecture.md schema section.
Phase 6 (Validated): rehearsal passed (forward 4.2min, rollback 1.1min); schema-diff clean.
Phase 7 (Improved): /learn-from-task queued; multi-step deploy plan handed to devops.

Files:
  - migrations/<NNNN>-<slug>.ts (or equivalent)

Classification:
  Target table: orders (5.2M rows, 3.1 GB)
  Operation: ADD COLUMN + BACKFILL + SET NOT NULL
  Approach: expand-contract (3 migrations + 2 app deploys)

Safety check:
  ✓ Reversible (down() restores state)
  ✓ Concurrent-write safe (no long locks)
  ✓ Index creation uses CONCURRENTLY
  ✓ Data step batched with SKIP LOCKED
  ⚠ Requires multi-step deploy — coordinate with devops

Next migrations planned:
  - <name-step-2>
  - <name-step-3>
  - <name-step-4>

Deploy compat: backward-compatible (app works before + after each migration).
ADR: <path if architectural decision> OR n/a.

Status: COMPLETE — proceed with M1 deploy when devops ready.
```

## Hard rules

- Reversible `down()`.
- Concurrent-write safe on populated tables.
- `CREATE INDEX CONCURRENTLY` for Postgres populated tables (MUST be outside a transaction).
- `pt-online-schema-change` / `gh-ost` for MySQL populated-table ALTERs.
- Expand-contract for breaking changes — never single-migration.
- Schema ≠ data migrations — separate files.
- `migration-rehearsal` mandatory for populated tables before prod.
- No `synchronize: true` / auto-migrate in prod — EVER.
