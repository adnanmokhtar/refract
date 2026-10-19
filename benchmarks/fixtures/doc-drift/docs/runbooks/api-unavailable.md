# API unavailable

Use this when the `ApiUnavailable` alert fires: every API replica fails its health check.

## Diagnosis

```bash
kubectl -n tallyhook get pods -l app=api
kubectl -n tallyhook describe deploy/api
```

## Mitigation

Move traffic to the standby site while the primary is investigated:

```bash
node scripts/failover.mjs --region standby
```

## Rollback

```bash
kubectl -n tallyhook rollout undo deploy/api
```
