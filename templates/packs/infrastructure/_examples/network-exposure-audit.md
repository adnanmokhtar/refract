---
name: network-exposure-audit
description: Audit cloud + K8s network exposure across the running/declared footprint. Every ingress path must be intentional and least-exposed.
---

# network-exposure-audit

Sweep the whole footprint for unintended network exposure. Premise: every ingress path is intentional and least-exposed. A wide-open ingress with no documented reason is forbidden.

## When to use

- Weekly, against the running footprint (drift from console clicks, break-glass rules never reverted).
- After any new public-facing service, LB, or bucket ships.
- Before a compliance / pen-test window; post-incident to confirm blast radius.

## Checks

- **SG / firewall / NSG**: no `0.0.0.0/0` (or `::/0`) inbound on non-public ports (22, 3389, 3306/5432/1433/27017, 6379, admin/metrics); no all-ports rule; every broad-source rule has a documented reason.
- **Subnet placement**: DB / cache / queue / internal tiers in PRIVATE subnets (no IGW route, no public IP). A DB with `publicly_accessible = true` or in a public subnet is HIGH.
- **Kubernetes**: default-deny `NetworkPolicy` in every namespace; no `type: LoadBalancer` on internal-only workloads; `hostNetwork: true` justified.
- **Public storage**: S3 Block Public Access on / GCS uniform access without `allUsers` / Azure public network access disabled. A public bucket with backups/PII is CRITICAL.
- **Admin / debug / metrics ports**: no `/metrics`, `/debug/pprof`, actuator, dashboard reachable from `0.0.0.0/0`.
- **LB / ingress edge**: every public listener terminates TLS; WAF on internet-facing LBs where policy requires.

## Output

```
Network exposure audit — account prod / cluster prod-east-1

CRITICAL:
  ✗ aws_db_instance.orders — publicly_accessible=true, public subnet, SG allows 0.0.0.0/0:5432
  ✗ s3://acme-db-backups — Block Public Access OFF, allUsers s3:GetObject

HIGH:
  ✗ aws_security_group.bastion — inbound 0.0.0.0/0 on port 22
  ✗ namespace payments has no default-deny NetworkPolicy (kubectl get networkpolicy -n payments → empty)

Every path above lacks a documented reason. File tickets for CRITICAL + HIGH.
```

## Boundary

- `tf-plan-review` catches an exposure change in one PLAN diff before apply; `admission-policy` enforces at ADMISSION. THIS skill audits the running/declared exposure across the whole footprint — the drift no single diff sees.
- The `security` pack owns app-layer exposure; this owns the network layer (who can reach the port at all).

## Related

- `k8s-audit` — the NetworkPolicy check overlaps; that skill audits cluster safety/HA/cost broadly, this drills the exposure axis across cloud + cluster.
- `tf-plan-review` — a widening SG flagged in a plan is the same class this catches in the running footprint.
- `admission-policy` — enforces default-deny at admission; this verifies the already-running state.
