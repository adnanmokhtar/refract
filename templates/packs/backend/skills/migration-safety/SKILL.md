---
name: migration-safety
description: Static scan of migration files for online-safety violations — blocking `CREATE INDEX` without `CONCURRENTLY`, `NOT NULL` added with no safe backfill, destructive drops of columns the running code still reads, and table-rewriting DDL. Run on any diff that adds or edits a migration, and before a deploy that ships a schema change. Not the timed rehearsal against prod-sized data — that is `migration-rehearsal` in the database pack.
kind: skill
pack: backend
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: migration-safety

## Premise

A schema migration runs against a live database under concurrent traffic. The failure is invisible in review and catastrophic in prod: a migration that takes an `ACCESS EXCLUSIVE` lock, rewrites a big table, or drops a column the running code still reads → an outage during deploy. The `migration-backend` rule and `add-endpoint`/`add-module` *promise* "online-safe, reversible" migrations; this skill is the verifier that enforces the promise.

**Every finding cites the migration file at `<file:line>` + the unsafe statement + the safe rewrite.** "This migration looks risky" without the cited statement is not a finding. This is a static scan of the migration files in the diff (or a target dir).

## Adapt to the codebase

Detect the migration tool + the target engine and phrase findings in its idiom — lock behaviour differs by engine and version:

| Tool | Migration files | Online-DDL escape hatch |
|---|---|---|
| **Rails (ActiveRecord)** | `db/migrate/*.rb` | `disable_ddl_transaction!` + `algorithm: :concurrently`; `strong_migrations` gem |
| **Django** | `<app>/migrations/*.py` | `AddIndexConcurrently` / `SeparateDatabaseAndState`; `atomic = False` |
| **Prisma / TypeORM / Knex** | `migrations/*.sql|.ts` | raw `CREATE INDEX CONCURRENTLY`; split expand/contract |
| **Alembic** | `alembic/versions/*.py` | `op.create_index(..., postgresql_concurrently=True)` + non-transactional |
| **Flyway / Liquibase** | `db/migration/V*__*.sql` | `CREATE INDEX CONCURRENTLY`; `pt-online-schema-change`/`gh-ost` for MySQL |
| **Ecto** | `priv/repo/migrations/*.exs` | `@disable_ddl_transaction true` + `create index(..., concurrently: true)` |

Engine matters: Postgres ≥11 makes `ADD COLUMN … DEFAULT` non-rewriting for constant defaults; MySQL/older PG rewrite. Confirm the engine before ruling a statement safe.

## Resolving table size — the input detectors 1, 2 and 7 all turn on

Three of the seven scans below gate on "is this table big", and **a migration file does not contain a
row count.** This is a static scan of files; the decisive input lives in the database. Get it, or say
you did not — the one thing this skill must never do is *decide* it without it.

Resolve in this order and record which rung answered, because the answer's confidence differs per rung:

| Where the count comes from | How | Confidence |
|---|---|---|
| A live/staging DB you can reach | Postgres: `SELECT relname, reltuples::bigint FROM pg_class WHERE relname = '<t>';` — the planner's own estimate, refreshed by `ANALYZE`, and free. MySQL: `SELECT table_rows FROM information_schema.tables WHERE table_name='<t>';` (InnoDB estimate — can be off by a large factor; treat as an order of magnitude). | Good — an estimate, not a fact, and that is enough for a threshold two orders of magnitude wide |
| A project-maintained profile | A `db-profile` / capacity note in `ai/` naming the large tables. Cite the `<path:line>`. | Good, if dated |
| The migration history | The table's `CREATE TABLE` migration exists in this repo and is **newer than the current deploy**, or is in this same migration — then it has no rows in production yet. | Conclusive for the empty case only |
| Nothing | — | **Unknown. This is a verdict, not a gap.** |

**Threshold: 100,000 rows.** Below it, an `ACCESS EXCLUSIVE` lock is measured in milliseconds and the
`CONCURRENTLY` ceremony (a separate non-transactional migration, an invalid-index failure mode to
clean up) costs more than it buys. Above it, the lock is long enough to queue every writer behind it,
which is the outage. **This number is a starting point with an order of magnitude behind it, not a
measurement of your hardware** — a wide table on slow disks crosses over sooner, a narrow one on NVMe
later. Replace it with the real crossover the moment you have timed one index build on this system,
and record that timing where the next run can read it.

**Size unknown → `report-flagged`, never `dismiss`.** State it in the finding: *"table size not
resolved (no reachable DB, no profile) — treat as large."* A scan that quietly assumes "probably
small" converts its three highest-value detectors into no-ops, and does it invisibly. Assuming large
costs a developer one minute of reading; assuming small costs a deploy window.

## Scans for

### 1. Blocking index creation

```
BAD:   CREATE INDEX idx_orders_user ON orders(user_id);          -- ACCESS EXCLUSIVE-ish lock on a big table
GOOD:  CREATE INDEX CONCURRENTLY idx_orders_user ON orders(user_id);   -- (own migration, no txn)
```
Flag `CREATE INDEX` without `CONCURRENTLY` (PG) / not using `algorithm: :concurrently` / not `pt-osc`/`gh-ost` (MySQL) on a table over the § Resolving table size threshold — or on a table whose size could not be resolved. Cite the resolved count and its source in the finding.

### 2. `NOT NULL` column with no safe backfill

```
BAD:   ALTER TABLE users ADD COLUMN status text NOT NULL;        -- fails/locks on a populated table
GOOD:  1) ADD COLUMN status text                                 -- nullable
       2) backfill in batches
       3) SET DEFAULT + validate + SET NOT NULL (or a CHECK NOT VALID → VALIDATE)
```
Flag `ADD COLUMN … NOT NULL` with no default (or with a volatile default on an engine that rewrites) and no separate backfill step.

### 3. Same-deploy rename / drop of a column code still uses (no expand→contract)

```
BAD:   ALTER TABLE orders RENAME COLUMN amt TO amount;           -- old code reading `amt` breaks mid-deploy
GOOD:  expand (add `amount`, dual-write) → migrate → contract (drop `amt`) in a LATER deploy
```
Flag a `RENAME`/`DROP COLUMN`/`DROP TABLE` in the same migration that adds the replacement, or a drop of a column the current code still references.

### 4. Editing an already-applied migration

Flag a change to a migration file that is not the newest (already ran on a shared env) — history is immutable; fix forward with a new migration.

### 5. Non-reversible migration with no documented `down`

Flag a migration with an empty / `raise`/`irreversible` `down` and no comment explaining why (data-loss migrations may be legitimately irreversible — but that must be explicit, not accidental).

### 6. Long-locking table rewrite / data backfill inside the DDL transaction

Flag a large `UPDATE`/backfill run in the same transaction as the DDL (holds locks for the whole scan) → move to a separate, batched, non-transactional step.

### 7. Adding a `FOREIGN KEY` / `CHECK` that validates the whole table synchronously

```
GOOD (PG): ADD CONSTRAINT … NOT VALID;  then  VALIDATE CONSTRAINT …   -- second step takes a weaker lock
```
Flag a `FOREIGN KEY`/`CHECK` added without the `NOT VALID` → `VALIDATE` two-step on a table over the § Resolving table size threshold, or on one whose size could not be resolved.

## Output

Each finding carries exactly one closure verb. What each means *here*:

- `[report-with-fix]` — the safe rewrite is mechanical and stated in the finding.
- `[report-flagged]` — the unsafe shape is real but the decisive input is missing (table size not resolved, engine/version unconfirmed) or the fix is a sequencing decision across deploys. **This skill has no `dismiss`**: an unresolved size never becomes an exception, it becomes this verb.
- `[halt-handoff]` — the migration cannot ship as written and the fix is a different artifact (splitting one migration into three, an expand→contract sequence across two deploys). The run stops on it.

```
migration-safety — <migration set>   (tool: <detected>, engine: <postgres 16 | mysql 8 | …>)

Findings: 2

1. db/migrate/20260709_add_index.rb:4                  [report-with-fix]
   add_index :orders, :user_id  — blocking on a large table.
   Fix: disable_ddl_transaction! + add_index :orders, :user_id, algorithm: :concurrently

2. migrations/0042_add_status.sql:1                     [halt-handoff]
   ALTER TABLE users ADD COLUMN status text NOT NULL — locks/fails on a populated table.
   Fix: split into add-nullable → batched backfill → SET NOT NULL (three migrations).
```

## False positives / gotchas

- **New/empty tables are safe** — a blocking index or `NOT NULL` on a table created in the same migration (no rows yet) is fine; flag only against populated/shared tables.
- **Engine + version dependent** — PG ≥11 constant-default `ADD COLUMN` is safe; don't flag it there. Confirm the engine before ruling.
- **A legitimately irreversible migration** (a destructive data change) is fine *with* an explicit comment — flag only the *accidental* missing `down`.
- **Small tables** — under the threshold in § Resolving table size, the concurrency ceremony isn't worth it on a tiny lookup table; note it, don't hard-block. This carve-out requires a *resolved* count. "It's probably a lookup table" is the assumption this skill exists to stop, not an application of this bullet.

## When to run

- On any diff that adds/edits a migration file (pair with `add-endpoint`/`add-module` when they emit one).
- Before a deploy that ships a schema change.
- After adopting a new migration tool or switching DB engines.

## Halt conditions

- Halt on any finding without the cited migration `<file:line>` + the unsafe statement + the safe rewrite.
- Halt if an edit touches an already-applied (non-newest) migration — that is fix-forward-only, always.
- Halt on a `RENAME`/`DROP` of a column the current code still reads without an expand→contract sequence across deploys.
- Defer engine-specific lock semantics you cannot confirm to a `report-flagged` (verify the engine/version), never a false-confident `dismiss`.
- Halt on any size-gated finding (detectors 1, 2, 7) that neither cites a resolved row count with its source nor is marked `report-flagged` as size-unknown. Silently treating an unmeasured table as small is this skill's own worst failure mode: it produces a clean report on the exact migration that takes the site down.

## Related

- `rules/migration-backend.md` — the migration discipline this skill verifies.
- `add-endpoint` / `add-module` — emit reversible migrations; run this on their output.
- `database` pack — index/lock/engine deep-dive.
