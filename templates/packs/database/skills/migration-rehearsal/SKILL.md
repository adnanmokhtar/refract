---
name: migration-rehearsal
description: Run a pending migration against a restored prod-sized backup. Measure duration + locks held + rollback behavior. Do this BEFORE prod.
---

# migration-rehearsal

A migration that takes 80ms on a dev DB can lock prod for 20 minutes. Rehearse on real data first.

## Premise

Deterministic procedure. Every duration, lock window, and rollback claim must come from a real timed run against a real restored backup. Inputs (dump file, target DB URL, migration ref) and outputs (timing, lock log, schema diff) are cited verbatim. The recommendation block is grounded in the captured numbers, not in folklore about how `ALTER TABLE` "usually" behaves. If the rehearsal DB is empty or undersized, abort and restore a full backup first — synthesized timings are worse than none.

## Halt conditions

- Refuse to report a "duration" without `time` output captured from the actual run.
- Refuse to claim "no locks held" without the `pg_locks` observer log.
- Refuse to certify rollback without a post-rollback schema diff = 0.
- Halt and ask if the backup is a sample / partial — don't extrapolate from a 10k-row table to a 50M-row prod table.

## When to use

- Before any migration on tables > 1M rows.
- Before any `ALTER COLUMN`, `ADD COLUMN NOT NULL` without default, or new index without `CONCURRENTLY`.
- Before a release window so the duration estimate is in the runbook.
- After a migration was rejected in code review for "looks slow" — prove it.

## Prerequisites

- Restored copy of latest prod backup in an isolated rehearsal DB (PII anonymized for regulated data).
- Network isolation — rehearsal DB cannot reach prod.
- `psql` / `mysql` client + `time` for duration measurement.
- Application code at the post-migration commit (so you can run smoke tests).

## Procedure

1. Restore the latest backup:
   ```bash
   pg_restore --clean --if-exists --no-owner -d "$REHEARSAL_DB" /backups/prod-latest.dump
   ```
2. Capture baseline metrics:
   ```bash
   psql "$REHEARSAL_DB" -c "SELECT pg_size_pretty(pg_total_relation_size('orders')), (SELECT count(*) FROM orders);"
   psql "$REHEARSAL_DB" -c "SELECT indexname FROM pg_indexes WHERE tablename='orders';"
   ```
3. Start lock observer in a second session (Postgres):
   ```bash
   watch -n 0.5 "psql \"$REHEARSAL_DB\" -c \"SELECT mode, granted, relation::regclass, pid, now()-query_start AS held FROM pg_locks JOIN pg_stat_activity USING(pid) WHERE relation::regclass::text='orders' ORDER BY held DESC;\""
   ```
4. Apply migration with timing:
   ```bash
   time npx prisma migrate deploy   # or: bun run migration:run, alembic upgrade head, etc.
   ```
5. Run smoke tests against the migrated DB (read paths, write paths, the specific feature this migration enables).
6. Apply rollback:
   ```bash
   time npx prisma migrate resolve --rolled-back <migration-name>   # or framework equivalent
   ```
7. Confirm schema restored — re-run step 2 and diff.

## Output

```
Migration: 042-add-order-status.ts
Target: orders (5.2M rows, 3.1 GB), idx_count=7

Forward:
  Duration:  4m 12s
  Locks:     ACCESS EXCLUSIVE on orders held 2m 18s (steps 3 + 5)
  Impact:    SELECT on orders blocked during lock window
  Side-effect: idx_orders_tenant_status created (CONCURRENTLY ✓)

Rollback:
  Duration:  12s
  Locks:     ACCESS EXCLUSIVE 8s
  Schema:    restored ✓ (baseline diff = 0)

Recommendation:
  2m 18s of blocked reads exceeds SLO (30s).
  Split per expand-contract: (1) ADD COLUMN NULL, (2) backfill via batched UPDATE,
  (3) ALTER ... SET NOT NULL after backfill, (4) drop legacy column in a later release.
```

## False positives / gotchas

- A small backup ≠ realistic — rehearse against full-size copies; row count matters more than table count.
- `CREATE INDEX` (without `CONCURRENTLY`) takes a write lock — always concurrent in Postgres on prod-sized tables.
- MySQL `ALTER TABLE` rewrites with `ALGORITHM=COPY`; verify `INPLACE` is selected via `SHOW WARNINGS` after a dry-run.
- Foreign key adds in MySQL implicitly do a full-table validation — slow on big tables.
- Rehearsal DB on slower disks than prod will OVERESTIMATE duration; on faster disks UNDERESTIMATE — note the disk class.
- Never rehearse ON prod, even "read-only" — replication lag from heavy queries can cascade.
