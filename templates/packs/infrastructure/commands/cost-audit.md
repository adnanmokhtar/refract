---
description: Cloud cost audit. Identifies unutilized / over-provisioned / forgotten resources. Reports per-cost-class with quick-win + medium-effort + structural recommendations.
---

# /cost-audit

Cloud cost grows silently. Forgotten resources, over-provisioned defaults, expensive choices baked in — none page anyone. Run periodically.

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves. Every finding cites `<resource>:<arn>` or `<terraform-file:line>`.** A cost finding without a concrete identifier and a concrete dollar number is a hand-wave and MUST be dropped. "EC2 looks over-provisioned" is not a finding. "`i-0abc123` (m6i.4xlarge, declared at `infra/terraform/compute/web.tf:88`) ran at p95=12% CPU / 18% mem over 30d per Compute Optimizer rec `co-rec-9f...`; right-size to m6i.large saves $312/mo" is a finding.

**The closure verb is `report-with-citation-and-dollar`.** Each row in the output table closes by citing:
- a cloud resource ARN / instance-id / bucket name / volume-id / EIP / snapshot-id
- a `<iac-file>:<line>` for IaC-declared resources
- a Cost Explorer / Compute Optimizer / Trusted Advisor recommendation ID for usage-based findings
- a concrete `$N/mo` or `$N/yr` saving — never "significant" or "substantial"

No resource ID + no dollar = no finding. The audit halts before write if any row lacks either.

**Mechanical halt — hand-wave grep (mandatory before report write):**
1. Grep the draft report for: `some `, `several `, `a few `, `many `, `large amount`, `significant`, `substantial`, `appears to`, `roughly`, `etc.`, `...`. Each hit MUST be replaced with a count + citation or dropped.
2. Grep every recommendation row for a `$` saving figure — drop rows missing one.
3. Grep every "delete / right-size / migrate" recommendation for the explicit resource list (ARNs, instance-ids) — drop rows that say "12 instances" without naming them.
4. Grep "Quick wins" / "Medium-effort" totals — they MUST equal the sum of cited row savings; mismatch halts.
5. **Arithmetic halt — every `$` figure shows its working.** Each row states `<quantity> × <unit price>` and where the unit price came from: the bill line for that resource, or the provider's current pricing page for that region. A saving with no derivation is a guess wearing a decimal point.
6. **Ceiling halt — a saving may never exceed what the resource currently costs.** For every row, compare the claimed saving against that resource's current monthly spend on the bill. Claiming more than 100% of a line item is arithmetically impossible and it is the failure that survives every other check, because the number looks specific. Storage-tier and retention rows are where this bites: moving N TB to a cheaper class saves the *difference* between the classes, never the whole line.
7. **Direction halt — confirm the sign of every retention / tiering / commitment change.** Log and object storage bill per GB-month, so LONGER retention costs MORE; a saving from retention comes from shortening it or exporting to a cheaper store. Reserved capacity saves only against the steady-state baseline it actually covers. State which direction the change goes and why that direction saves money.
8. If the draft is empty after these passes, report "0 findings — spend baseline tight" rather than padding.

**The agent does NOT:**
- Estimate savings with adjectives ("big", "meaningful") — only `$N/mo` or `$N/yr`.
- Recommend "consider X" or "explore X" — recommend a concrete delete / scope / migrate with a target.
- Inflate the report with generic best-practice tips not tied to a current resource.

**The agent ONLY escalates when:**
- A resource has zero usage but its owner cannot be identified from tags + IaC + recent commits — surface as `unowned: <arn>` for human triage rather than auto-recommending deletion.
- A right-size recommendation crosses a memory headroom threshold (<20% margin) on a production instance — surface as "needs canary" rather than auto-recommending.

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

**Every row of this audit makes one of three claims, and each has a different authoritative source.
Mixing them is how an audit produces numbers that do not reconcile with the bill.**

| The claim the row makes | What can settle it | What cannot |
|---|---|---|
| *This cost $N* — the dollar figure the premise demands | The **per-resource billing export**, not the cost dashboard. AWS CUR breaks costs down "by product or product resource"; GCP's *detailed* usage export adds "granular, resource-level cost data"; Azure's Cost Management **Cost and usage details** export scopes to the resource group | The console's cost view. It aggregates by *service*, so it says "EBS: $4,100" and can never say *which volume* — and a finding without a resource id is dropped by the premise |
| *It is over-provisioned* — the utilization claim behind a right-size row | A **utilization recommender** that read real telemetry over a stated window (Compute Optimizer, GCP Recommender / Active Assist, Azure Advisor), cited by its recommendation id, with the window named | The instance type. "m6i.4xlarge looks big" is the hand-wave halt 1 exists to catch |
| *Nobody asked for this* — the orphan rows | The **live resource inventory diffed against IaC**: everything the provider lists, minus everything Terraform / CloudFormation / Pulumi declares. Orphans live in the remainder, by definition | The bill. A $3/mo unattached EIP is invisible inside a $40k bill and is still a finding — orphans are found by inventory, then priced by the export |

**Where a recommender and the export disagree, the export wins.** A recommender's "estimated savings"
is a projection priced at list; the export carries what was actually charged after commitments and
discounts, which is usually less. A row citing a recommender's dollar figure without reconciling it
to the bill line fails halt 6.

On **multi-cloud**, do not hand-normalize three schemas — all three providers can emit
[FOCUS](https://focus.finops.org/), a vendor-neutral cost-and-usage schema, and comparing clouds on
anything else is comparing their marketing terms. Third-party cost platforms are a convenience over
these same exports, never a substitute for one: if the platform cannot show you the resource id
behind a number, the number cannot be cited here.

On **Kubernetes**, the provider stops being useful at the node boundary — the bill knows the node,
not the namespace that filled it. Allocation below the node needs a cost allocator that reads the
cluster's own requests and usage per container (OpenCost, or a vendor built on it; its spec allocates
at `max(request, usage)` at container level and aggregates upward). **Without one, per-team or
per-namespace Kubernetes chargeback is not measurable — report that as the finding rather than
apportioning by guesswork.** Reporting "cluster: $12k, attribution unavailable" is honest; splitting
it by headcount is a fabricated number wearing a decimal point.

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

Every row names its resources (halt #3), shows its arithmetic (halt #5), and stays under that
resource's current bill line (halt #6). IDs beyond three per row go to an appendix, but they are
enumerated somewhere — "47 volumes" with no list is not actionable and is dropped.

| # | Recommendation (resources enumerated) | Saving — with working | Effort |
|---|---|---|---|
| 1 | Delete 47 unattached EBS volumes — `vol-0a1b2c…`, `vol-0d4e5f…`, `vol-0f7a8b…` + 44 more (Appendix A) | $420/mo — 5,250 GB total × gp3 GB-month rate from the July bill line `EBS:VolumeUsage.gp3` | 30m |
| 2 | Delete 23 orphaned snapshots > 90d, parent volumes already deleted — ids in Appendix B | $180/mo — 4,100 GB × snapshot GB-month rate, same bill | 30m |
| 3 | Release 12 unattached Elastic IPs — `eipalloc-01…` + 11 more (Appendix C) | $44/mo — 12 × idle public-IPv4 hourly rate × 730h | 5m |
| 4 | Delete 4 ALBs with 0 requests in 30d — `app/legacy-web`, `app/beta-api`, `app/demo`, `app/old-admin` | $90/mo — 4 × LCU-hour base charge × 730h | 30m |
| 5 | **Shorten** retention on 3 stale log groups (`/aws/lambda/legacy-etl`, `/aws/ecs/beta`, `/aws/rds/audit-old`) from never-expire to 30d, exporting anything with a retention obligation to object storage first | $35/mo — 780 GB stored × log GB-month rate. Note the direction: retention is billed per GB-month, so LENGTHENING it costs more | 15m |

**Quick win total: ~$770/mo savings; <2 hours work.** (420 + 180 + 44 + 90 + 35 = 769 — halt #4: the total is the sum of the cited rows, not a rounded impression.)

### Medium-effort recommendations

| # | Recommendation (resources enumerated) | Saving — with working | Effort |
|---|---|---|---|
| 6 | Right-size 12 EC2 instances — `i-0abc123`, `i-0def456`, `i-0ghi789` + 9 more (Appendix D), each flagged by Compute Optimizer rec `co-rec-…` with p95 CPU below 15% over 30d | $1,200/mo — sum of the 12 per-instance on-demand deltas (m6i.4xlarge → m6i.large etc.), each from the instance's own bill line | 4-8h |
| 7 | Convert 9 named dev instances (Appendix E) to spot — all restartable, none stateful | $400/mo — 9 × (on-demand − current spot) at the observed 30d average spot price; state the assumption, spot prices move | 1 day |
| 8 | Enable S3 Intelligent-Tiering on `s3://acme-prod-backups` — 24 TB, 81% untouched > 30d per Storage Lens | $180/mo — ~19.4 TB moving Standard → Infrequent Access: 19,400 GB × (Standard − IA per-GB delta) minus the per-object monitoring charge. **Sanity check (halt #6): this bucket's current line on the bill is $560/mo, so a $180 saving is 32% of it — plausible. A $180 saving on a 4 TB bucket would NOT be, because 4 TB of Standard costs less than that in total** | 1h |
| 9 | Lifecycle to Glacier after 90d on 3 named log buckets (Appendix F) | $250/mo — 31 TB aged past 90d × (Standard − Glacier per-GB delta); restore latency accepted, see Failure modes | 2h |
| 10 | Replace the single NAT Gateway with VPC endpoints for the 3 highest-traffic AWS APIs (S3, ECR, CloudWatch Logs) | $300/mo — 6.4 TB/mo of the 8.1 TB NAT-processed volume, at the NAT per-GB processing rate, moved to endpoints | 1 day |

**Medium-effort total: ~$2,330/mo; ~3 days work.** (1,200 + 400 + 180 + 250 + 300 = 2,330.)

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

- **Show the arithmetic or drop the row.** `<quantity> × <unit price>` plus where the unit price came from. Unit prices are region-specific and change; a figure carried from memory is a fabrication with a decimal point.
- **A saving can never exceed the line item.** Check every row against the resource's current bill line before writing it.
- **Confirm the direction.** Longer retention costs more, not less. Say which way the change goes and why that direction saves.
- **Verify before delete.** `0 requests in 30 days` is good signal but not absolute — ask owner.
- **Don't right-size production without canary.** Memory pressure surfaces under load, not in metrics.
- **Don't sell saving plans on speculative growth.** Buy SPs to cover STEADY-STATE; over-commit hurts.
- **Tag everything.** Untagged = unattributable = uncuttable.
- **Anomaly alerting on.** Catch the next runaway before it costs $10K.

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — ordered by **savings**, not severity: **BIGGEST SAVINGS** → **SMALLER** → **MARGINAL** — each step carrying the resource / `<file:line or resource-id>` + **Fix** (concrete change — rightsize / delete idle / reserved-vs-on-demand) + **Verify** (projected monthly $ saved + the safety check that it won't break the workload), then the closing steps (re-run `/cost-audit` after changes land, `/learn-from-task`, then proceed). A clean run collapses to a single line ("No material waste — clear"). The reader must never assemble the next steps themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Right-sized EC2 to 50% memory then a memory leak resurfaced → OOM under load.
- Deleted "orphaned" snapshot that was actually a manual backup the DBA hadn't tagged.
- Bought 1-year SP at end of quarter → vendor's price drop a month later left commitment over-priced.
- "Idle" ALB was actually warming connections for a hot-standby system → traffic spike on next failover broke.
- Migrated to Glacier; restoration takes hours; legal request needed data in minutes → rush rollback.
- Reported a storage-tier saving larger than the bucket's entire monthly cost. The figure was specific, so nobody checked it; the whole report lost credibility when finance did.
- "Increased log retention to save money" — retention is billed per GB-month. The change raised the bill and the report claimed a saving.

## Related

- `audit-iam` — pair when restructuring resources (IAM stays in sync).
- `provision-tier` — applies cost-optimal patterns to new resources.
- `@infra-architect` agent — for structural cost recommendations (re-architecting a workload, not a line-item right-size).
- `tf-plan-review` skill — verify cost implications of next IaC change.
