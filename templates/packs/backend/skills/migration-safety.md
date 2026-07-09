---
name: migration-safety
kind: skill
pack: backend
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

## Scans for

### 1. Blocking index creation

```
BAD:   CREATE INDEX idx_orders_user ON orders(user_id);          -- ACCESS EXCLUSIVE-ish lock on a big table
GOOD:  CREATE INDEX CONCURRENTLY idx_orders_user ON orders(user_id);   -- (own migration, no txn)
```
Flag `CREATE INDEX` without `CONCURRENTLY` (PG) / not using `algorithm: :concurrently` / not `pt-osc`/`gh-ost` (MySQL) on a non-trivial table.

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
Flag a `FOREIGN KEY`/`CHECK` added without the `NOT VALID` → `VALIDATE` two-step on a large table.

## Output

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
- **Small tables** — the concurrency ceremony isn't worth it on a tiny lookup table; note it, don't hard-block.

## When to run

- On any diff that adds/edits a migration file (pair with `add-endpoint`/`add-module` when they emit one).
- Before a deploy that ships a schema change.
- After adopting a new migration tool or switching DB engines.

## Halt conditions

- Halt on any finding without the cited migration `<file:line>` + the unsafe statement + the safe rewrite.
- Halt if an edit touches an already-applied (non-newest) migration — that is fix-forward-only, always.
- Halt on a `RENAME`/`DROP` of a column the current code still reads without an expand→contract sequence across deploys.
- Defer engine-specific lock semantics you cannot confirm to a `report-flagged` (verify the engine/version), never a false-confident `dismiss`.

## Related

- `rules/migration-backend.md` — the migration discipline this skill verifies.
- `add-endpoint` / `add-module` — emit reversible migrations; run this on their output.
- `database` pack — index/lock/engine deep-dive.
