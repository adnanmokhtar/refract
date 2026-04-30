---
name: migrations
description: Pattern: Safe Migrations
kind: ai-pattern
pack: database
---

# Pattern: Safe Migrations

> **Hard rule:** Every migration is reversible (or has an explicit one-way ADR), non-blocking on populated tables, and rehearsed against prod-sized data before merge. Adding NOT NULL without default, renaming columns in one step, or destructive `DROP` without expand-contract is forbidden.

**When to apply**
- Any hot table has > 1M rows in production.
- The deploy pipeline runs migrations automatically — a long-running migration blocks deploys.
- The change touches a column read or written by live traffic during deploy.

**When NOT to apply**
- A fresh database with no production data — guardrails are over-engineered for a seed migration.
- Internal-only tooling DB with maintenance windows — schedule downtime, document, move on.

**Halt conditions / mandatory cites**
- Each migration MUST cite the table + estimated row count at `<path:line>` AND its rehearsal evidence.
- Any column rename / drop MUST cite the expand-contract steps (add new, dual-write, backfill, switch reads, drop old).
- A doc proposing `ALTER TABLE ... ADD COLUMN ... NOT NULL` without default on a populated table is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is fast".
- If the DB engine's locking semantics + online-DDL capabilities aren't extracted, halt.

A bad schema migration takes the database lock for 30 minutes and the application down with it. This pattern reduces production migration pain to near-zero by enforcing three rules: every change is reversible (or explicitly accepted as one-way), non-blocking on populated tables, and tested against realistic data volumes before merge.

## Context

Reach for migration discipline when:
- The database has a non-trivial production dataset (>1M rows in any hot table).
- You ship via rolling deploys (multiple app versions running simultaneously during deploy).
- Downtime windows are short or non-existent.
- A previous migration has caused an incident.

For a prototype with empty tables and a maintenance window, you can be sloppier. The patterns below assume you can't afford to be.

## The three rules

1. **Reversible** — `up()` and `down()` both implemented unless data-destructive by design (and then noted explicitly in the commit message).
2. **Non-blocking** — populated tables don't take long locks. `ALTER TABLE`, `CREATE INDEX`, etc. use online variants.
3. **Tested against real data** — restored backup, shadow DB, or representative seed. Never an empty dev DB only.

## Per-migration checklist

- [ ] `up()` and `down()` both implemented (or commit explains why down is impossible)
- [ ] Tested against a populated dataset (not the empty dev DB)
- [ ] No long-locking statement in peak hours (size table; estimate lock time)
- [ ] Index creation uses `CREATE INDEX CONCURRENTLY` on Postgres / `ALGORITHM=INPLACE, LOCK=NONE` on MySQL
- [ ] `CONCURRENTLY` migrations run OUTSIDE a transaction (this is a Postgres requirement, not optional)
- [ ] Deploy ordering declared: app-before-migration OR migration-before-app
- [ ] No data transformation mixed with schema change in the same migration
- [ ] Idempotent on re-run if it might be retried (`IF NOT EXISTS`, `ON CONFLICT DO NOTHING`)

## Expand-contract for breaking changes

The single most important pattern. NEVER do a breaking schema change in one migration on a live system. Split into phases that each ship with compatible application code.

### Adding NOT NULL to existing column

```
Phase 1 (migration):  ALTER TABLE orders ADD COLUMN currency text NULL;
Phase 1 (app):        Read currency if present; default 'USD' on read; write currency on writes.

Phase 2 (migration):  Backfill — UPDATE orders SET currency = 'USD' WHERE currency IS NULL;
                      (batched; see below)
Phase 2 (app):        No change.

Phase 3 (app):        Stop relying on the default; require currency on all writes.

Phase 4 (migration):  ALTER TABLE orders ALTER COLUMN currency SET NOT NULL;
```

Each phase deploys independently. At no point does the app crash because schema doesn't match code.

### Renaming a column

```
Phase 1 (migration):  ALTER TABLE products ADD COLUMN display_name text;
                      Backfill: UPDATE products SET display_name = name; (batched)
Phase 1 (app):        Read display_name with fallback to name; write BOTH.

Phase 2 (app):        Read display_name only; write BOTH (in case of rollback).

Phase 3 (app):        Read + write display_name only.

Phase 4 (migration):  ALTER TABLE products DROP COLUMN name;
```

Four deploys, each safe if the next never ships. If you instead rename in one shot, every running instance of the previous app version errors on every query for the duration of the rolling deploy.

### Changing a column type

Same shape as rename. Add a new column with the new type, dual-write, backfill, switch reads, drop old.

### Dropping a column

```
Phase 1 (app):        Stop reading + writing the column.
Phase 2 (deploy):     Confirm via grep / metric that no version is using it.
Phase 3 (migration):  ALTER TABLE x DROP COLUMN y;
```

Don't skip the soak time between phases — a query you missed in code review still runs in cron jobs you forgot existed.

## Batched updates

For updates touching > ~10k rows, NEVER a single `UPDATE ... WHERE` — it locks the whole table or holds a long transaction. Batch with explicit `LIMIT` and `SKIP LOCKED`:

```sql
-- Postgres: batched backfill of orders.currency
DO $$
DECLARE
  affected int;
BEGIN
  LOOP
    WITH batch AS (
      SELECT id FROM orders
      WHERE currency IS NULL
      LIMIT 1000
      FOR UPDATE SKIP LOCKED
    )
    UPDATE orders SET currency = 'USD'
    WHERE id IN (SELECT id FROM batch);

    GET DIAGNOSTICS affected = ROW_COUNT;
    EXIT WHEN affected = 0;
    PERFORM pg_sleep(0.1);  -- breathing room for replication
  END LOOP;
END $$;
```

For very large backfills, run from a script outside the migration system (so the migration is short + retryable; the script handles the long work).

## Index creation on populated tables

Postgres without `CONCURRENTLY` takes an `ACCESS EXCLUSIVE` lock — every read and write blocks for the duration. On a 100M-row table this is hours of downtime.

```sql
-- WRONG — blocks the table for the full build duration
CREATE INDEX idx_orders_status ON orders(status);

-- RIGHT — builds in background, locks only briefly at start/end
CREATE INDEX CONCURRENTLY idx_orders_status ON orders(status);
```

Caveats:
- `CONCURRENTLY` cannot run inside a transaction. Most ORMs wrap migrations in transactions by default — disable it for this migration.
- If the build fails mid-way, the index is left INVALID. You must `DROP INDEX` and retry.
- Adds load while building — schedule for low-traffic hours on hot tables.

MySQL equivalent:

```sql
ALTER TABLE orders ADD INDEX idx_orders_status (status), ALGORITHM=INPLACE, LOCK=NONE;
```

## NOT NULL + default in one step — DON'T

```sql
-- DANGER on a populated large table — full table rewrite under exclusive lock
ALTER TABLE orders ADD COLUMN status text NOT NULL DEFAULT 'pending';
```

On Postgres 11+, this is fast for many cases (DEFAULT stored as table metadata, no rewrite). On older versions or with complex defaults, it rewrites every row. Same on MySQL pre-8.0.

Safer expand-contract:

```sql
-- Migration 1
ALTER TABLE orders ADD COLUMN status text;
ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'pending';
-- Backfill in batches
UPDATE orders SET status = 'pending' WHERE status IS NULL;  -- batched
-- Migration 2
ALTER TABLE orders ALTER COLUMN status SET NOT NULL;
```

## Migrations vs deploy ordering

Two patterns. Pick ONE per migration and DECLARE it.

**Migrations BEFORE code (backward-compatible).** Migration runs first, adds nullable column. Old + new app code both work (old ignores it; new uses it). Default for additive changes + rolling deploys.

**Migrations AFTER code (forward-compatible).** New code deploys first, understands both old and new schema. Migration runs once all instances are on new code. Default for breaking changes that need an atomic schema flip.

NEVER mix. The PR description says "Migration ordering: BEFORE" or "AFTER" — ambiguity ships incidents.

## Testing before merge

```bash
# 1. Restore production backup to a shadow DB
pg_restore --dbname=shadow_db prod_backup.dump

# 2. Run migration forward, time it, capture lock waits
psql shadow_db -c '\timing on' -f migrations/20260424_add_currency.sql

# 3. Verify down() reverses (where applicable)
psql shadow_db -f migrations/20260424_add_currency.down.sql

# 4. Re-apply forward — confirm idempotency if migration might retry
psql shadow_db -f migrations/20260424_add_currency.sql
```

Real numbers from this run go in the PR description: "Tested on 8M-row backup, took 12s with 0 lock waits."

## CI / review gate

`/migration-review` (or your equivalent) on every PR that adds a migration. Static checks:
- Long-locking statements detected (`ALTER TABLE` on tables with > N rows in production stats).
- `CREATE INDEX` without `CONCURRENTLY`.
- `down()` missing.
- Schema change + data transformation in the same migration.

A blocker cannot be merged without override + reasoning.

## Common mistakes

- **`synchronize: true` (TypeORM) or auto-migrate in any non-dev environment.** Drops columns, alters types based on entity drift. Catastrophic in prod.
- **Renaming a column in one migration.** Rolling deploy means the old app version queries the gone column. 100% errors during deploy.
- **Adding a foreign key with `ON DELETE CASCADE` after the fact.** The constraint check locks both tables. Use `ALTER TABLE ... ADD CONSTRAINT ... NOT VALID; ALTER TABLE ... VALIDATE CONSTRAINT ...` (Postgres) — the second statement is online.
- **Mixing schema and data in one transaction.** A long backfill blocks DDL; a DDL holds locks during the backfill. Separate the migration.
- **Long migrations in the deploy critical path.** A 30-min migration delays every deploy by 30 min. Move to a separate one-off job triggered manually.
- **Generating migrations from ORM auto-diff blindly.** TypeORM/Prisma auto-generate works for simple cases; complex changes (renames, type changes) it gets wrong. Read the generated SQL.
- **Missing `WHERE` clause on backfill.** `UPDATE orders SET currency = 'USD'` without `WHERE currency IS NULL` rewrites every row, including those already set. Long lock + replication lag.

## Trade-offs

Pro: zero-downtime schema changes. Pro: rollback path stays open. Pro: incidents move from "lost data + 4-hour outage" to "missing index until next deploy". Con: a column rename now takes 4 PRs over 2 weeks instead of 1 PR. Con: app code temporarily reads/writes both old and new shapes, doubling complexity during the transition. Con: discipline needed across the team — one careless `ALTER TABLE` wipes the gain.

For an app with five users and a 10-minute maintenance window, the cost outweighs benefit. For a SaaS API with paying customers, the cost is one-time per migration; the alternative is one customer-facing incident per migration.

## Migration path

Adopting this discipline mid-project:
1. Audit recent migrations for the patterns above. The retro produces the team's "what we got away with" list.
2. Set up a shadow DB with a recent prod backup. Smoke-test the next 2-3 migrations against it.
3. Add the CI checks for `CONCURRENTLY`, missing `down()`, and `synchronize: true`.
4. Pick the next risky migration and walk through expand-contract together. The team learns the pattern with backup.
5. Add a runbook (`ai/runbooks/migrations.md`) with the checklist above.

## References

- "Designing Data-Intensive Applications" (Kleppmann), ch. 4 — schema evolution principles.
- The Strong Migrations gem (rails) — codifies these rules as static checks; even non-Rails teams steal from its ruleset.
- gh:laravel-shift/blueprint or similar for your ORM — read source to understand the static checks.
- Postgres docs on `CREATE INDEX CONCURRENTLY` — read carefully, especially the failure recovery.
