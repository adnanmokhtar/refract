# API latency

Use this when the `ApiHighLatency` alert fires: p95 latency above 800 ms for ten minutes.

## Diagnosis

```bash
kubectl -n tallyhook top pods
kubectl -n tallyhook logs deploy/api --since=15m
```

Look for one slow endpoint first: a single query that lost its index explains most incidents.
Then check Redis: a full rate-limit store slows every request.

The usual suspects, in order: the orders list with a large page size, the monthly report
without the month filter, and the invoice PDF download when S3 is slow.

## Production

From a workstation with production access, the same check against the production cluster:

```bash
kubectl --context tallyhook-prod -n tallyhook top pods
```

## Mitigation

```bash
kubectl -n tallyhook scale deploy/api --replicas=4
```
