---
paths:
  - "**/migrations/**"
  - "**/migrate/**"
  - "**/alembic/versions/**"
  - "**/prisma/migrations/**"
  - "**/db/migrate/**"
---

# Rule: Migration safety (path-scoped)

> **Loads only when editing a migration file** (via `inject-path-rules.sh`). It is NOT in the always-on set — it costs zero tokens until you touch a migration. TL;DR: an applied migration is immutable; change the schema forward, never in place.

## Must

- **Never edit an already-applied migration.** Once a migration has run on any shared environment, it is history. Fix a mistake with a *new* migration, not by rewriting the old one — rewriting silently diverges every database that already ran it.
- **Every migration is reversible.** Provide a real `down` / rollback that returns the schema to its prior state (or an explicit, commented reason it cannot be reversed).
- **Expand → migrate → contract** for changes that touch live reads/writes: add the new column/table (expand), backfill + dual-write, then drop the old shape in a *later* migration (contract). Never rename/drop in the same deploy that adds the replacement.
- **One logical change per migration file**, named with the ordering key the tool expects (timestamp/sequence). Don't bundle unrelated schema changes.
- **Index creation on large tables goes in its own migration** and uses the non-blocking form where the engine supports it (e.g. Postgres `CREATE INDEX CONCURRENTLY`).

## Must not

- Add a `NOT NULL` column without a default or a backfill step — it locks/fails on a populated table.
- Put data backfills that can run long inside the same transaction as DDL that takes a heavy lock.
- Delete a column/table that current code still reads (contract only after the code that used it is gone).

## Review checklist

- [ ] No edits to a migration that has already been applied anywhere shared.
- [ ] `down`/rollback present and correct (or reason documented).
- [ ] Destructive change is the contract half of a prior expand — not a same-deploy rename/drop.
