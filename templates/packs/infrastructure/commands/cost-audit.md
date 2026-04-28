---
description: Cloud cost audit. Identifies unutilized / over-provisioned / forgotten resources. Reports per-cost-class with quick-win + medium-effort + structural recommendations.
---

# /cost-audit

Cloud cost grows silently. Forgotten resources, over-provisioned defaults, expensive choices baked in — none page anyone. Run periodically.

## Phases applied

1, 2, 3, 4, 6 (skips Update/Improve — read-only audit + recommendations).

## When to use

- Monthly minimum.
- After cost spike.
- Pre-budget cycle.
- After major architecture change.
- Before raising prices (margin pressure check).

## Phase 1 — Understand

- Cloud(s): AWS / GCP / Azure / multi.
- Account / project / subscription scope.
- Last month's bill: total + by service.
- Budget targets if set.

## Phase 2 — Organize

Six cost classes audited in parallel:

1. **Compute** — EC2 / Compute Engine / VMs / containers / Lambdas. Right-sized? On-demand vs reserved? Spot opportunity?
2. **Storage** — S3 / GCS / Blob / EBS volumes / disks. Hot vs cold tier? Lifecycle policies? Orphaned snapshots?
3. **Database** — RDS / Cloud SQL / DynamoDB / Cosmos DB. Right-sized? Reserved vs on-demand? Read replicas necessary?
4. **Network** — egress (data transfer out is the silent killer). NAT gateway hours. CloudFront cache hit rate.
5. **Forgotten / orphaned** — unattached EIPs, idle load balancers, snapshots from deleted instances, old AMIs, abandoned beta projects.
6. **Saving plans / commitments** — unused RIs / Savings Plans / commitment usage rate.

## Phase 3 — Retrieve

Tools:
- AWS: Cost Explorer, Trusted Advisor, AWS Cost Anomaly Detection, Compute Optimizer, Storage Lens.
- GCP: Cost Management, Recommender, Active Assist.
- Azure: Cost Management, Advisor.
- Multi-cloud: Vantage, CloudHealth, Cloudability, Vendor-agnostic OSS like OpenCost (for K8s).

Read project's:
- `ai/architecture.md` — service inventory.
- IaC (Terraform / CloudFormation / Pulumi) — declared resources.
- Last month's bill.

## Phase 4 — Generate

```
## Cloud cost audit — <date>

### Spend overview
- Last month total:        $<X>
- Trailing 3 months:       $<X> (+/- <%> trend)
- Top 5 services:
  1. EC2:           $<X>  (<%>)
  2. S3:            $<X>  (<%>)
  3. RDS:           $<X>  (<%>)
  4. NAT Gateway:   $<X>  (<%>)
  5. CloudFront:    $<X>  (<%>)

### Quick wins (≤1h / large impact)

| # | Recommendation | Estimated saving | Effort |
|---|---|---|---|
| 1 | Delete 47 unattached EBS volumes (orphaned) | $420/mo | 30m |
| 2 | Delete 23 orphaned snapshots > 90 days | $180/mo | 30m |
| 3 | Delete 12 unattached Elastic IPs | $44/mo | 5m |
| 4 | Delete idle ALBs (0 requests in 30d): 4 found | $90/mo | 30m |
| 5 | Move 3 stale CloudWatch log groups to longer retention | $35/mo | 15m |

**Quick win total: ~$770/mo savings; <2 hours work.**

### Medium-effort recommendations

| # | Recommendation | Saving | Effort |
|---|---|---|---|
| 6 | Right-size EC2: 12 instances flagged "over-provisioned" by Compute Optimizer | $1,200/mo | 4-8h |
| 7 | Convert dev instances to spot (where tolerant) | $400/mo | 1 day |
| 8 | Enable S3 Intelligent-Tiering on prod-backups bucket (4 TB) | $180/mo | 1h |
| 9 | Lifecycle to Glacier after 90d on older log buckets | $250/mo | 2h |
| 10 | Replace single NAT Gateway w/ NAT instance OR VPC endpoints for high-traffic AWS APIs | $300/mo | 1 day |

**Medium-effort total: ~$2,330/mo; ~3 days work.**

### Structural recommendations

| # | Recommendation | Saving / Year | Effort |
|---|---|---|---|
| 11 | Buy 1-year Compute Savings Plan covering steady-state baseline | -25% on steady compute (~$15K/yr) | 1 day decision + commitment |
| 12 | Migrate analytics workloads from RDS to Athena | $24K/yr | 1 month engineering |
| 13 | Move static assets to CloudFront origin = R2 (no egress) | $12K/yr | 2 days |
| 14 | Implement K8s VPA / cluster autoscaler tuning | $18K/yr | 1 sprint |

### Forgotten / abandoned resources

| Resource type | Count | Notes |
|---|---|---|
| Stopped EC2 (>30d) — kept volumes | 8 | Volumes still cost. Verify data; delete or AMI. |
| Untagged resources | 142 | Can't attribute cost. Fix tagging policy. |
| Dev environments left running 24/7 | 6 | Auto-shutdown nights/weekends saves 70%. |
| AMIs older than 1 year | 47 | Storage cost trivial; review for retention policy clarity. |

### Egress hot-spots

NAT Gateway: $X/mo + $0.045/GB processed.
- Top sources of egress to NAT:
  - service-A: 1.2 TB/mo to fetch from public S3 → use VPC endpoint instead → $0/GB.
  - service-B: 800 GB/mo to a same-region public AWS API → VPC endpoint → save $36/mo per 1 TB.
- Egress to Internet (CloudFront): cache hit rate 62% — improve to 85% via better caching headers → save $X/mo.

### Reserved capacity / Savings Plan utilization

- Compute SP: 80% of steady-state; **20% over-committed** ($X/mo wasted).
- RDS RI: 100% utilized (good).
- S3 storage class: <breakdown by class>.

### Anomalies (last 30d)

- Day 12: cost spike of $1.2K — investigated; was a runaway Lambda recursion. Already fixed; mention in this report for budget context.
- Cumulative: <X> anomaly events flagged by Cost Anomaly Detection.

### Posture summary

| Metric | Value | Target |
|---|---|---|
| Untagged resources | <%> | < 5% |
| Cost-per-tenant (multi-tenant SaaS) | $<X> | trending |
| Saving plan utilization | <%> | > 85% |
| Idle resources | <%> | < 1% |
```

## Phase 6 — Validate

After applying:
- Re-pull cost data → verify savings materialized.
- Verify no production regression (right-sizing didn't degrade perf).
- Verify saving plans actually consumed.
- Tag policy enforced via SCP / Org policy → re-scan untagged resources.

## Output format

```
## /cost-audit complete

Period: <month or quarter>
Total spend: $<X>
Quick-win savings: $<Y>/mo (≤2h work)
Medium-effort savings: $<Z>/mo (~few days)
Structural opportunities: $<W>/yr
Anomalies flagged: <count>

Report: ai/audits/cost-<date>.md
```

## Hard rules

- **Verify before delete.** `0 requests in 30 days` is good signal but not absolute — ask owner.
- **Don't right-size production without canary.** Memory pressure surfaces under load, not in metrics.
- **Don't sell saving plans on speculative growth.** Buy SPs to cover STEADY-STATE; over-commit hurts.
- **Tag everything.** Untagged = unattributable = uncuttable.
- **Anomaly alerting on.** Catch the next runaway before it costs $10K.

## Failure modes

- Right-sized EC2 to 50% memory then a memory leak resurfaced → OOM under load.
- Deleted "orphaned" snapshot that was actually a manual backup the DBA hadn't tagged.
- Bought 1-year SP at end of quarter → vendor's price drop a month later left commitment over-priced.
- "Idle" ALB was actually warming connections for a hot-standby system → traffic spike on next failover broke.
- Migrated to Glacier; restoration takes hours; legal request needed data in minutes → rush rollback.

## Related

- `audit-iam` — pair when restructuring resources (IAM stays in sync).
- `provision-tier` — applies cost-optimal patterns to new resources.
- `@cost-optimizer` agent if pack has it.
- `tf-plan-review` skill — verify cost implications of next IaC change.
