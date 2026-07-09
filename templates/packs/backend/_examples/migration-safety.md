---
name: migration-safety
kind: example
pack: backend
---

# Skill: migration-safety

Migrations run against a live DB under traffic — a lock-taking DDL, a table rewrite, or dropping a column the running code reads = a deploy outage. Verifies the online-safe/reversible promise of migration-backend + add-endpoint/add-module. Every finding cites the migration `<file:line>` + the unsafe statement + the safe rewrite. Detect the tool + engine first (lock behaviour is engine/version dependent — PG ≥11 constant-default ADD COLUMN is safe; MySQL rewrites).

## Scans for

1. `CREATE INDEX` without `CONCURRENTLY` / `algorithm: :concurrently` / pt-osc on a big table.
2. `ADD COLUMN … NOT NULL` with no default + no batched backfill → add-nullable → backfill → SET NOT NULL.
3. Same-deploy RENAME/DROP of a column code still reads → expand → migrate → contract (later deploy).
4. Editing an already-applied (non-newest) migration → fix-forward only.
5. Non-reversible `down` with no comment (accidental irreversibility).
6. Large backfill/UPDATE inside the DDL transaction → batched, non-transactional.
7. FK/CHECK added without `NOT VALID` → `VALIDATE` two-step on a large table.

## Gotchas

New/empty tables are safe (no rows). Engine+version dependent — confirm before ruling safe. Legitimately-irreversible destructive migration is fine WITH a comment. Small tables skip the ceremony.

## Halt conditions

No finding without the cited migration line + unsafe statement + safe rewrite. Editing a non-newest migration is fix-forward-only. RENAME/DROP of a still-read column needs expand→contract. Unconfirmed engine lock semantics → `report-flagged`, never a false `dismiss`.

## Related

`rules/migration-backend.md` (the discipline verified), add-endpoint/add-module (emit migrations), database pack (index/lock deep-dive).
