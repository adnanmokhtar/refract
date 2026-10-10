# Restore — ledger database

1. Restore the snapshot (or a point in time) to a **new** instance; never over `larder-ledger`.
2. Compare row counts of `payouts`, `refunds` and `ledger_entries` against the source at the restore time.
3. Swap the `ledger-db` secret to the new endpoint, restart `ledger-sync` consumers.

## Drill log

- 2026-09-14: restored snapshot rds:larder-ledger-2026-09-14-03-10 to a new instance larder-ledger-drill-0914 (job restore-7c41e2); row counts payouts 1 204 311, refunds 88 402, ledger_entries 9 876 120 — identical to the source at 03:10; restore took 41 min against the 1 h RTO; drill instance deleted afterwards.
