# Runbook — orders cutover

Owner: platform on-call. Flags: `deploy/flags/cutover.yaml`. Plan: `deploy/cutover/plan.yaml`.

1. Backfill: `pnpm --filter @norrow/scripts backfill -- --table=orders,order_lines` (checkpointed,
   resumable; `scripts/backfill/state/orders.checkpoint.json`).
2. Reconcile: `scripts/reconcile/validate.sh` — counts, money sums and row-level status/total.
3. Read flip: `orders.read_from = v2` once both are green.
4. Soak 7 days on V2 reads; V1 keeps every write and every worker.
5. Fence and flip writes: `scripts/cutover/flip-writes.ts` (V1 writer pool paused and its grants
   revoked before the flag moves).
6. Reverse path while soaking writes: `scripts/sync/reverse-sync.ts --table=orders,order_lines`
   replays every V2 write into V1 every minute, so step 7 can still go back.
7. Rollback (any time before step 8): flip `orders.writes_owner` and `orders.read_from` back to
   `v1`; the reverse sync has already copied V2's writes; reconcile, then resume.
8. Point of no return (named, signed by the engineering lead and finance): stop the reverse sync
   and drop the V1 order tables — not before 14 days of V2 writes with zero reconcile mismatches.
