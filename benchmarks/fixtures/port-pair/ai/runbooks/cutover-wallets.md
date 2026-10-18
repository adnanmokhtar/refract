# Runbook — wallets cutover

Owner: platform on-call. Flags: `deploy/flags/cutover.yaml`. CDC: `deploy/cdc/wallets-cdc.yaml`.

1. Backfill: `pnpm --filter @norrow/scripts backfill -- --table=wallets`; the ledger table loads
   with `deploy/pgloader/ledger.load` up to the high-water mark.
2. CDC catch-up, then reconcile balances (`scripts/reconcile/validate.sh wallets`).
3. Read flip: `wallets.read_from = v2`.
4. Write flip: `wallets.writes_owner = v2`.
5. Rollback: flip `wallets.read_from` and `wallets.writes_owner` back to `v1`.
