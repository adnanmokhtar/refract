# Operations

How Tallyhook is deployed and kept running. The alert runbooks live in [runbooks](runbooks/).

## Deploying

The manifests in `deploy/k8s/` are applied by the release pipeline. To apply them by hand:

```bash
kubectl apply -f deploy/k8s/
kubectl -n tallyhook rollout status deploy/api
```

## Restore from a backup

A custom-format dump is taken every night. To restore one, follow the
[database restore runbook](runbooks/restore-db.md).

## On-call

Pager schedule: <insert the on-call schedule link>.

## Releases

A release is a tag `vX.Y.Z` on `main`. The pipeline builds the API image, tags it with the
version and rolls the `api` and `worker` Deployments. The changelog section for the version is
written before the tag.

## Capacity

The API runs two replicas behind the `api` Service and scales to four during the monthly
invoice run. The worker runs one replica; the nightly reports job runs as a CronJob. Postgres
and Redis are managed services outside the cluster, reached through the `tallyhook-api` Secret.

## Terms

Financial terms used across these pages are defined in the
[glossary](glossary.md#المصطلحات-المالية).
