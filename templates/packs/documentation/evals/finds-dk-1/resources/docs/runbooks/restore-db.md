# Restore the database

Use this when the `DatabaseBackupStale` alert fires and a restore is needed, or when data must be
rolled back to a dump.

## Diagnosis

Check the age of the newest dump and whether the backup job failed or never ran.

## Recovery

```bash
kubectl -n tallyhook scale deploy/api --replicas=0
kubectl -n tallyhook scale deploy/worker --replicas=0
make restore-db SNAPSHOT=latest
kubectl -n tallyhook scale deploy/api --replicas=2
kubectl -n tallyhook scale deploy/worker --replicas=1
```

The full background is in the [backup section](../operations.md#restoring-a-backup).

## Verify the restore

Count the orders of the last full day and compare with the reports table. Then open a recent
invoice PDF from the dashboard.

## Escalation

If the restore fails twice, page the database owner and stop writes at the load balancer.

## Snapshots

Dumps older than seven days live outside the cluster. In the AWS RDS console, pick the newest
`tallyhook-prod-nightly` snapshot and restore it to a scratch instance first.
