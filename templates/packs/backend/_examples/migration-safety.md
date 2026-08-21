---
name: migration-safety
description: Static scan of migration files for online-safety violations — blocking `CREATE INDEX` without `CONCURRENTLY`, `NOT NULL` added with no safe backfill, destructive drops of columns the running code still reads, and table-rewriting DDL. Run on any diff that adds or edits a migration, and before a deploy that ships a schema change. Not the timed rehearsal against prod-sized data — that is `migration-rehearsal` in the database pack.
kind: example
pack: backend
---

# Skill: migration-safety

Migrations run against a live DB under traffic — a lock-taking DDL, a table rewrite, or dropping a column the running code reads = a deploy outage. Verifies the online-safe/reversible promise of migration-backend + add-endpoint/add-module. Every finding cites the migration `<file:line>` + the unsafe statement + the safe rewrite. Detect the tool + engine first (lock behaviour is engine/version dependent — PG ≥11 constant-default ADD COLUMN is safe; MySQL rewrites).

## Premise

A schema migration runs against a live database under concurrent traffic. The failure is invisible in review and catastrophic in prod: a migration that takes an `ACCESS EXCLUSIVE` lock, rewrites a big table, or drops a column the running code still reads → an outage during deploy. The `migration-backend` rule and `add-endpoint`/`add-module` *promise* "online-safe, reversible" migrations; this skill is the verifier that enforces the promise.

**Every finding cites the migration file at `<file:line>` + the unsafe statement + the safe rewrite.** "This migration looks risky" without the cited statement is not a finding. This is a static scan of the migration files in the diff (or a target dir).

## Scans for

1. `CREATE INDEX` without `CONCURRENTLY` / `algorithm: :concurrently` / pt-osc on a big table.
2. `ADD COLUMN … NOT NULL` with no default + no batched backfill → add-nullable → backfill → SET NOT NULL.
3. Same-deploy RENAME/DROP of a column code still reads → expand → migrate → contract (later deploy).
4. Editing an already-applied (non-newest) migration → fix-forward only.
5. Non-reversible `down` with no comment (accidental irreversibility).
6. Large backfill/UPDATE inside the DDL transaction → batched, non-transactional.
7. FK/CHECK added without `NOT VALID` → `VALIDATE` two-step on a large table.

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

## Gotchas

New/empty tables are safe (no rows). Engine+version dependent — confirm before ruling safe. Legitimately-irreversible destructive migration is fine WITH a comment. Small tables skip the ceremony.

## Halt conditions

No finding without the cited migration line + unsafe statement + safe rewrite. Editing a non-newest migration is fix-forward-only. RENAME/DROP of a still-read column needs expand→contract. Unconfirmed engine lock semantics → `report-flagged`, never a false `dismiss`.

## Related

`rules/migration-backend.md` (the discipline verified), add-endpoint/add-module (emit migrations), database pack (index/lock deep-dive).
