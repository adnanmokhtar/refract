# Cost attribution policy

Owner: platform team · adopted 2026-05-04 · reviewed every quarter with finance.

Every cloud resource answers to one team and one environment. Finance splits the monthly bill by
these two keys; spend that carries neither is reported as unallocated in the monthly review.

## Required keys

| Key | Allowed values | Where it is set |
|---|---|---|
| `team` | `dispatch`, `growth`, `platform`, `data` | per resource in Terraform; on the pod template in Kubernetes |
| `env` | `prod`, `preview`, `dev` | `default_tags` in each AWS root; the kustomize `labels` transformer per overlay |

- **AWS:** `env` comes from the provider's `default_tags` in every root; `team` is set on each
  resource (a root owned by one team may put `team` in `default_tags` instead).
- **Kubernetes:** each overlay stamps `env` on every resource and pod template (`labels` with
  `includeTemplates: true`); every workload sets `team` on its pod template and every namespace
  carries `team`. The prod EKS cluster is shared by dispatch (API, worker) and growth (exports,
  tracking widget), so per-workload labels are how its cost is split.
- **DigitalOcean:** tags `team:<team>` and `env:<env>` on every cluster, database and volume —
  `tags` in Terraform, `--tag-names` on every `doctl … create` line in a runbook or script.

## Shared cost

The prod cluster's control plane, NAT and load balancer are split between dispatch and growth by
the share of pod-template CPU requests each team carries, read from OpenCost at month end.

## Unallocated

Tax, support and credits are untaggable and reported on their own line. Anything else without
both keys is unallocated, and the owning account's team fixes it in the next sprint.
