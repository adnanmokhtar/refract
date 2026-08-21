---
name: network-exposure-audit
description: Audit cloud + K8s network exposure across the running/declared footprint. Every ingress path must be intentional and least-exposed.
---

# network-exposure-audit

Sweep the whole footprint for unintended network exposure. Premise: every ingress path is intentional and least-exposed. A wide-open ingress with no documented reason is forbidden.

## Premise

Find real exposure. Every finding cites the concrete resource (`aws_security_group.web`, `NetworkPolicy` absence in namespace X, `google_compute_firewall.default-allow`, bucket ARN) AND the attribute that opened it (`cidr_blocks = ["0.0.0.0/0"]`, `map_public_ip_on_launch = true`, `publicly_accessible = true`, a missing default-deny). "Public database" requires the resource type + the public-subnet/public-IP/`0.0.0.0/0`-source fact that proves reachability from the internet. Verdict (BLOCK / PASS) is grounded in the specific ingress paths, not a global feel. A path is only acceptable if it's a genuinely public port (80/443 on a public LB/ingress) OR carries a documented reason.

## Halt conditions

- Refuse to flag `0.0.0.0/0` as a finding without naming the port(s) it opens — `0.0.0.0/0` on 443 behind a public ALB is expected; on 22/3306/5432/6379 it is not.
- Refuse to call a database "public" without citing BOTH the subnet placement (route to IGW) and either a public IP or a `0.0.0.0/0` source — one alone is not reachability.
- Refuse to claim "default-deny present" without `kubectl get networkpolicy -n X` showing a policy that selects all pods with empty `ingress` (and `egress` for egress control).
- Halt on hand-waves like "looks locked down" — cite the SG/NACL/firewall/NetworkPolicy rule that proves it.
- Don't propose auto-fix on production ingress; report the least-exposed alternative and let humans decide.

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
