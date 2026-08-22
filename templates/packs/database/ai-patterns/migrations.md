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
- [ ] The **operation class** is named (metadata-only / in-place build / rebuild) and cited from the engine's DDL table — not inferred from a row count
- [ ] Index creation uses `CREATE INDEX CONCURRENTLY` on Postgres / `ALGORITHM=INPLACE, LOCK=NONE` on MySQL, written explicitly
- [ ] A **lock timeout is set in the migration** (`SET lock_timeout` on Postgres / `SET SESSION lock_wait_timeout` on MySQL) — see § The lock that is not in any class
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

MySQL / InnoDB equivalent — and note this is *not* the same hazard. Adding a secondary index is In Place, does not rebuild the table, and **permits concurrent DML**: "The table remains available for read and write operations while the index is being created" ([MySQL 8.4 § Online DDL Operations](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-operations.html), Table 17.16).

```sql
SET SESSION lock_wait_timeout = <seconds>;
ALTER TABLE orders ADD INDEX idx_orders_status (status), ALGORITHM=INPLACE, LOCK=NONE;
```

Write the clause even though it is the default behaviour: an unsupported case then fails loudly instead of silently falling back to a table copy.

**Two InnoDB caveats the clause does not cover:**
- `LOCK=NONE` **is rejected** on a table that has `ON…CASCADE` or `ON…SET NULL` constraints ([Online DDL Limitations](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-limitations.html)). A schema that (correctly) declares cascade semantics cannot take `LOCK=NONE` on that table — plan `LOCK=SHARED` (reads continue, writes block) or an external tool, and say which.
- `ADD FULLTEXT` and `ADD SPATIAL` indexes do **not** permit concurrent DML, unlike every other secondary index.

**When `pt-online-schema-change` / `gh-ost` are still right** — not because the native build blocks, but for the three things MySQL's own limitations page says native online DDL cannot do: there is no mechanism to **pause** an online DDL operation or to **throttle** its I/O or CPU; its **rollback is expensive** if it fails; and a long one **causes replication lag**, because a replica cannot begin the DDL until the source has finished it. Name which of the three applies.

## The lock that is not in any class

Every discussion above is about how long the *work* takes. The outage usually comes from somewhere else: the exclusive lock the engine needs to swap the table definition in, and the queue that forms behind it.

MySQL states it plainly: an online DDL operation "may briefly require an exclusive metadata lock on the table during its execution phase, and **always requires one in the final phase** of the operation when updating the table definition… A long running or inactive transaction that holds a metadata lock on the table can cause an online DDL operation to timeout" ([Online DDL Limitations](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-limitations.html)). Postgres has the same shape: most `ALTER TABLE` forms take `ACCESS EXCLUSIVE`, which conflicts with plain `SELECT`.

The queue is the damage. The DDL waits on one open transaction; everything arriving afterwards waits behind the DDL's pending exclusive request — including reads that conflicted with nothing. The table is unavailable for as long as the *oldest transaction* runs, not for as long as the DDL runs. This is why an `ALGORITHM=INSTANT` ALTER can take a site down.

Two obligations follow, for every DDL migration regardless of op class:

1. **Look for the blocker first** — MySQL: `performance_schema.metadata_locks` for the table plus `information_schema.INNODB_TRX ORDER BY trx_started` for the oldest open transaction. Postgres: `pg_locks` joined to `pg_stat_activity`, ordered by `xact_start`.
2. **Bound the wait in the migration itself** — `SET SESSION lock_wait_timeout = <seconds>` on MySQL (the default is `31536000`, one year) or `SET lock_timeout = '<n>s'` on Postgres, so a failed attempt leaves the queue instead of holding it, and retry off-peak.

## NOT NULL + default in one step — DON'T

```sql
-- DANGER on a populated large table — full table rewrite under exclusive lock
ALTER TABLE orders ADD COLUMN status text NOT NULL DEFAULT 'pending';
```

What actually happens, per engine — and on current versions the danger has moved:

- **Postgres 11+** — with a **non-volatile** DEFAULT the value is evaluated once and stored in the catalog: "In neither case is a rewrite of the table required" ([PostgreSQL `ALTER TABLE` § Notes](https://www.postgresql.org/docs/17/sql-altertable.html)). With a **volatile** DEFAULT (`now()`, a random or uuid generator) it "will require the entire table and its indexes to be rewritten". The volatility of the default is the whole decision.
- **MySQL / InnoDB** — "INSTANT is the default algorithm as of MySQL 8.0.12, and INPLACE before that" for `ADD COLUMN` (for `DROP COLUMN` the same became the default only as of 8.0.29). It is metadata-only, concurrent DML permitted, independent of row count. It is refused — silently downgrading to an in-place rebuild or a copy — when the table is `ROW_FORMAT=COMPRESSED`, carries a `FULLTEXT` index, lives in the data dictionary tablespace, or has reached the **row-version ceiling of 64** (255 as of MySQL 9.1.0): `ERROR 4092 (HY000): Maximum row versions reached… Please use COPY/INPLACE`. Every instant add or drop of a column burns one version; only a table rebuild or `OPTIMIZE TABLE` resets `TOTAL_ROW_VERSIONS`. Check `information_schema.INNODB_TABLES.TOTAL_ROW_VERSIONS` before assuming the fast path.
- **MySQL before 8.0.12** — no INSTANT for `ADD COLUMN`; it is INPLACE. Before 8.0.29, INSTANT could add a column only as the *last* column and did not check the row size — read the doc for the running version, not the latest.
- **MariaDB** — a different engine on this point: its instant-DDL support and version thresholds diverge from MySQL's. Do not carry a MySQL row across; read MariaDB's own DDL documentation for the running version.

So on both current engines the naive one-liner above is usually *not* a rewrite. The reason to still split it is the other half: `NOT NULL` on a populated column has to be enforced over existing rows (a scan on Postgres, a table rebuild on MySQL — "Making a column NOT NULL": Rebuilds Table **Yes**), and the app cannot start requiring the column in the same deploy that adds it.

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

Owned by the `migration-rehearsal` skill — it carries the engine lanes (restore, lock observer, timed forward, timed rollback, schema diff) and refuses to report a number that did not come from a real run. Do not improvise a rehearsal here.

The one rule that belongs in the PR: **real numbers from that run go in the description** — forward duration, the maximum lock mode and how long it was held, any wait for the definition lock, and which algorithm the engine actually chose. An estimate presented as a measurement is worse than no number.

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
- **Adding a foreign key after the fact.** On **Postgres**, `ADD CONSTRAINT … NOT VALID` commits without a scan and `VALIDATE CONSTRAINT` then takes only `SHARE UPDATE EXCLUSIVE`, so it does not lock out concurrent updates. **MySQL has no `NOT VALID`**: `ADD FOREIGN KEY` is `ALGORITHM=COPY` — a full rebuild — unless `foreign_key_checks` is disabled, which is the only route to `INPLACE` ("The INPLACE algorithm is supported when `foreign_key_checks` is disabled. Otherwise, only the `COPY` algorithm is supported."). Disabling the check means the engine does *not* verify existing rows, so prove the data is clean with an anti-join first. And if the constraint carries `ON DELETE CASCADE`/`SET NULL`, that table can no longer take `LOCK=NONE` on any later ALTER — a cost paid forever, not once.
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
- [MySQL 8.4 § Online DDL Operations](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-operations.html) and [§ Online DDL Limitations](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-limitations.html) — the per-operation Instant / In Place / Rebuilds / Concurrent-DML tables. Read the table, do not repeat folklore about it.
- [PostgreSQL `ALTER TABLE` § Notes](https://www.postgresql.org/docs/17/sql-altertable.html) — which forms rewrite, which only scan, and what `NOT VALID` buys.
- The Strong Migrations gem (Rails) — codifies these rules as static checks; even non-Rails teams steal from its ruleset.

## Related

- `transaction-isolation.md` — backfills and online DDL take locks; batch + lock-timeout + consistent lock ordering to avoid blocking writers or deadlocking under concurrent load.
