---
name: network-exposure-audit
description: Audit cloud + K8s network exposure across the running or declared footprint — every ingress path must be intentional and least-exposed, with no wide-open ingress lacking a documented reason. Run weekly against the running footprint, after any new public-facing service ships, and before a compliance or pen-test window. Drills the exposure axis — `k8s-audit` covers cluster safety/HA/cost broadly.
---

# network-exposure-audit

Sweep the whole footprint for unintended network exposure. The premise: every ingress path is intentional and least-exposed. A wide-open ingress with no documented reason is forbidden.

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
- Before a compliance/pen-test window.
- Post-incident, to confirm the blast radius of an exposed path.

## Adapt to the provider

| Surface | What to read |
|---|---|
| AWS | Security Groups (inbound `cidr_blocks` + port ranges), NACLs, subnet route tables (IGW = public), `map_public_ip_on_launch`, RDS/ElastiCache `publicly_accessible` + subnet group, S3 Block Public Access + bucket policy/ACL, ALB/NLB scheme + listener TLS + WAF association |
| GCP | `google_compute_firewall` (`source_ranges`, `allow` ports), subnet `private_ip_google_access`, Cloud SQL public IP + authorized networks, GCS uniform bucket-level access + IAM `allUsers`/`allAuthenticatedUsers`, LB + Cloud Armor |
| Azure | NSG inbound rules (`source_address_prefix = "*"`/`Internet`), subnet vs public IP association, SQL/Redis firewall + `Allow Azure services`, Storage account public network access + container anonymous access, App Gateway + WAF policy |
| Kubernetes | `NetworkPolicy` default-deny (ingress + egress), `Service type: LoadBalancer` on internal-only workloads, Ingress TLS + annotations, `hostNetwork`, exposed metrics/debug Services |
| Terraform / IaC | Same resources in declared form — this AUDITS the declared exposure across the whole state, not one PR diff |

## Checks

### Security groups / firewalls / NSGs
- No `0.0.0.0/0` (or `::/0`) inbound on non-public ports: SSH (22), RDP (3389), DB (3306/5432/1433/27017), cache (6379/11211), admin/dashboards, internal API ports.
- No all-ports rule (`0-65535` / protocol `-1` / `*`) from a broad source.
- Every broad-source rule has a documented reason (ticket, tag, comment) or it's a finding.
- Egress not left fully open where policy requires egress control (exfil path).

### Public vs private subnet placement
- Databases, caches, queues, internal services live in PRIVATE subnets (no route to IGW, no public IP).
- A DB/cache in a public subnet, OR with a public IP, OR `publicly_accessible = true` is HIGH.
- Bastion/NAT is the only intended public-subnet compute; app tiers sit behind a LB.

### Kubernetes NetworkPolicy
- Default-deny ingress policy in every namespace (all-pods selector, empty ingress).
- Egress control where required (default-deny egress + explicit allows to DNS + needed services).
- No `type: LoadBalancer` Service for an internal-only workload (use ClusterIP + internal LB annotation).
- `hostNetwork: true` justified or flagged.

### Public storage
- S3 Block Public Access on / GCS uniform access without `allUsers` / Azure public network access disabled.
- No bucket policy or ACL granting `*` / `allUsers` read on sensitive data.
- A public bucket holding backups, PII, credentials, or internal artifacts is CRITICAL.

### Exposed admin / debug / metrics ports
- No `/metrics`, `/debug/pprof`, actuator, admin console, or dashboard reachable from `0.0.0.0/0`.
- Metrics scraped over the private network / mesh, not a public listener.

### LB / ingress edge
- Every public listener terminates TLS (no plaintext 80 except redirect-to-443).
- WAF associated on internet-facing HTTP(S) LBs where policy requires it.
- Ingress hostnames map to intended backends only (no wildcard exposing internal services).

## Output

```
Network exposure audit — account prod / cluster prod-east-1

CRITICAL:
  ✗ aws_db_instance.orders — publicly_accessible=true, in public subnet, SG allows 0.0.0.0/0:5432
      → Postgres reachable from the internet. No documented reason.
  ✗ s3://acme-db-backups — Block Public Access OFF, bucket policy grants allUsers s3:GetObject
      → Nightly DB dumps publicly readable.

HIGH:
  ✗ aws_security_group.bastion — inbound 0.0.0.0/0 on port 22
      → SSH from anywhere. Use SSM Session Manager or restrict to office CIDR.
  ✗ namespace payments has no default-deny NetworkPolicy
      → any pod can reach the payments pods (kubectl get networkpolicy -n payments → empty).
  ✗ Service metrics-exporter type=LoadBalancer, /metrics on 0.0.0.0:9090
      → Prometheus metrics public. Switch to ClusterIP + internal scrape.

MEDIUM:
  ⚠ ALB public-web listener :80 has no redirect to 443, no WAF associated.
  ⚠ google_compute_firewall.allow-internal permits egress to 0.0.0.0/0 (no egress control).

Every ingress path above lacks a documented reason. File tickets for CRITICAL + HIGH.
```

## False positives / gotchas
- `0.0.0.0/0` on 80/443 behind a public ALB/ingress is the intended path — not a finding on its own.
- A public IP on a NAT gateway or bastion is expected; the finding is a DB/cache/app tier with one.
- A NetworkPolicy that exists but selects no pods (wrong label) is NOT default-deny — verify the selector.
- Cloud console shows the running state; IaC shows the declared state. Drift between them is itself a finding.
- "Private subnet" means no route to an IGW — a subnet named `private` with an IGW route is public.

## Boundary

- `tf-plan-review` catches an exposure change in a single PLAN diff before apply; `admission-policy` enforces at ADMISSION time. THIS skill audits the running/declared exposure across the whole footprint — the drift and the never-reverted rule that neither of those sees.
- The security pack owns app-layer exposure (authn/authz, injection, secrets); this owns the network/infrastructure layer (who can reach the port at all).

## Related

- `k8s-audit` — the NetworkPolicy presence check here overlaps; that skill audits cluster safety/HA/cost broadly, this drills the exposure axis across cloud + cluster.
- `tf-plan-review` — a widening SG flagged in a plan is the same class this catches in the running footprint.
- `admission-policy` — enforces default-deny + no-public-LB at admission; this verifies the already-running state.
- `@infra-architect` — invoked to redesign a tier that must move to a private subnet.
- Cross-pack `security` — app-layer OWASP findings; hand off anything above the network layer.
