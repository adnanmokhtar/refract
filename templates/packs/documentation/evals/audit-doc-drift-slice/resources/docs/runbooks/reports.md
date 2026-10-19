# Reports job failed

Use this when the `ReportsJobFailed` alert fires: the nightly totals job did not finish.

## Diagnosis

```bash
kubectl -n tallyhook get cronjob reports-nightly
kubectl -n tallyhook get jobs --sort-by=.metadata.creationTimestamp
```

## Recovery

Run the job again by hand from the CronJob's template:

```bash
kubectl -n tallyhook create job --from=cronjob/reports-daily reports-rerun
kubectl -n tallyhook logs job/reports-rerun
```
