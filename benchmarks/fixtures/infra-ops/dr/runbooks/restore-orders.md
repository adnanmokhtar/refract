# Restore — orders database

1. Pick the restore time (the incident's start minus five minutes).
2. `aws rds restore-db-instance-to-point-in-time --source-db-instance-identifier larder-orders-v2 --target-db-instance-identifier larder-orders-restore --restore-time <time>`
3. Point the api at the restored instance (`DATABASE_URL` in the `api-db` secret), restart the api.

## Drill log

- 2026-03-02: restored orders from the latest snapshot, the app came up fine.
