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

## Adapt to the provider

The audit demands cited tool output, so each surface names **the command that produces the citation** and **the field to read**. Emit JSON and read the named field rather than eyeballing a console — the field name is the durable part.

| Surface | Command → field to read |
|---|---|
| AWS security groups | `aws ec2 describe-security-groups --output json` → `IpPermissions[].IpRanges[].CidrIp` + `Ipv6Ranges[].CidrIpv6`, paired with `FromPort`/`ToPort`/`IpProtocol`. A finding needs the CIDR **and** the port range |
| AWS subnet placement | `aws ec2 describe-route-tables --output json` → a route whose `GatewayId` starts `igw-` makes the associated subnets public, whatever they are named; then `aws ec2 describe-subnets` → `MapPublicIpOnLaunch` |
| AWS managed data stores | `aws rds describe-db-instances --output json` → `PubliclyAccessible`, plus the subnet group checked against those route tables |
| AWS object storage | `aws s3api get-public-access-block --bucket <name>` → the four `BlockPublic*` / `RestrictPublic*` booleans; `aws s3api get-bucket-policy` → any statement with `"Principal": "*"` |
| AWS load balancers | `aws elbv2 describe-load-balancers --output json` → `Scheme`; `describe-listeners` → `Protocol` + `Certificates` |
| GCP | `gcloud compute firewall-rules list --format=json` → `sourceRanges`, `direction`, `allowed[].ports`, `disabled`; `gcloud sql instances describe <i> --format=json` → `settings.ipConfiguration.ipv4Enabled` + `authorizedNetworks` |
| Azure | `az network nsg rule list -g <rg> --nsg-name <n> -o json` → `sourceAddressPrefix` (`*` / `Internet`), `destinationPortRange`, `access`, `direction`; `az storage account show` → `publicNetworkAccess` + `allowBlobPublicAccess` |
| Kubernetes | `kubectl get networkpolicy -A -o yaml` → default-deny is `podSelector: {}` with empty `ingress` (and `egress` for egress control); `kubectl get svc -A -o json` → `spec.type == "LoadBalancer"` on internal-only workloads |
| Terraform / IaC | The same resources in declared form — the whole state, not one PR diff |

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

## False positives / gotchas

This section is what stops the audit returning a wall of findings nobody can triage. Each of these looks like exposure and is not:

- `0.0.0.0/0` on 80/443 behind a public ALB or ingress is the intended path — not a finding on its own.
- A public IP on a NAT gateway or a bastion is expected; the finding is a DB, cache, or app tier with one.
- A NetworkPolicy that exists but selects no pods (wrong label) is NOT default-deny — verify the selector before crediting it.
- Cloud console shows the running state; IaC shows the declared state. Drift between them is itself a finding, and the more interesting one.
- "Private subnet" means no route to an internet gateway. **A subnet named `private` with an IGW route is public** — read the route table, not the name.

## Boundary

- `tf-plan-review` catches an exposure change in one PLAN diff before apply; `admission-policy` enforces at ADMISSION. THIS skill audits the running/declared exposure across the whole footprint — the drift no single diff sees.
- The `security` pack owns app-layer exposure; this owns the network layer (who can reach the port at all).

## Related

- `k8s-audit` — the NetworkPolicy check overlaps; that skill audits cluster safety/HA/cost broadly, this drills the exposure axis across cloud + cluster.
- `tf-plan-review` — a widening SG flagged in a plan is the same class this catches in the running footprint.
- `admission-policy` — enforces default-deny at admission; this verifies the already-running state.
