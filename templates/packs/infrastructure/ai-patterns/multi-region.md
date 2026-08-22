---
name: multi-region
description: Pattern — multi-region architecture (active-passive, active-active, blast-radius isolation). Decision tree + per-tier recommendations + DR drill cadence.
kind: ai-pattern
pack: infrastructure
---

# Pattern: Multi-region

> **Hard rule** — Multi-region is a forced choice (DR, residency, latency, capacity), not a default. Untested DR is no DR; failover is drilled at least quarterly with a recorded RTO/RPO measurement. Conflict-resolution policy is declared per data store — silent last-write-wins on bidirectional replication is forbidden.

**When to apply**
- Region-level outage tolerance is contractually required (MSA, regulator).
- Data residency law forces per-region tenant partitioning.
- Edge cache + single-region origin has been exhausted and global users still complain.

**When NOT to apply**
- The cost of an hour of region-level outage is smaller than the standing 1.5-3x infrastructure multiplier below. That comparison is the decision; company-stage rules of thumb are not.
- Latency complaints from a few users — try CDN / edge cache first.
- Team has no working backup-restore drill — fix single-region resilience BEFORE multiplying regions.

**Halt conditions / mandatory cites**
- Cite the last successful DR drill record as `<path>` (date + measured RTO/RPO); > 90 days stale is a halt.
- Cite the conflict-resolution policy as `<path:line>` per replicated store (CRDT, last-write-wins config, per-tenant primary); unstated policy is a halt.
- Cite the cross-region egress cost projection as `<path>` before promoting to active-active; egress can dwarf compute and surprise budgets.
- Cite the failover runbook (`ai/runbooks/failover-<region>.md`) by path; absent runbook = passive forever.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Infrastructure`.
>
> - **Current topology**: `<single-region | active-passive | active-active | per-region tenants>`
> - **Primary region**: `<region>`
> - **Secondary region(s)**: `<list>`
> - **Failover RTO target**: `<minutes>` (Recovery Time Objective)
> - **Failover RPO target**: `<minutes>` (Recovery Point Objective — data loss budget)
> - **Cutover mechanism**: `<DNS / health-check / BGP / app-level>`
> - **Last DR drill**: `<date>` (drift if > 90 days)

## When multi-region is justified

| Reason | Solution |
|---|---|
| Disaster recovery (region-level outage tolerance) | Active-passive with replication |
| Latency for global users | Active-active OR edge caching (CloudFront / Cloudflare) — start with edge |
| Regulatory data residency (EU customers' data in EU) | Per-region tenants OR data-plane partitioning |
| Capacity at scale | Active-active OR sharded by user/tenant |
| Independent blast radius | Per-region tenants or fully partitioned |

## When NOT multi-region

Do the arithmetic instead of reaching for a stage label. Three numbers decide it:

1. **Cost of an hour of region-level outage** — revenue lost + contractual penalty + churn. From finance, not from intuition.
2. **Expected annual region-outage hours** — your provider's historical regional incidents for the regions you actually use, not their marketing SLA.
3. **The standing multiplier** — 1.5-2x for active-passive, 2-3x plus design overhead for active-active (see Architectures), paid every month whether or not a region ever fails.

Multi-region is justified when (1) × (2) exceeds (3). Usually it does not, which is why the honest defaults are:

- **Cross-AZ HA in one region, with backups that have actually been restored.** Most of the availability, a fraction of the complexity.
- **Global users but no latency complaints**: edge cache handles this; a multi-region origin does not.
- **No working restore drill**: fix single-region resilience first — multiplying regions multiplies an untested recovery path.

Multi-region is a "we're forced to" decision, not a "we should" one. Until you've maxed out single-region resilience, multi-region is over-investment.

## Architectures

### Active-passive (DR)

- Primary region serves all traffic.
- Secondary region: data replicated; compute scaled to zero or minimum hot-standby.
- Failover: DNS swap or load-balancer cutover; secondary scales up.

**RTO**: minutes-to-hours depending on cutover mechanism + data sync state.
**RPO**: replication lag (typically seconds-to-minutes).
**Cost**: secondary infra cost ~30-50% of primary (storage replicated; compute minimal).

Pitfalls:
- Untested DR plan = "passive" forever; failover doesn't actually work.
- Replication lag accumulates silently; alarmed only at failover.
- Stateful services (e.g., session caches) lost on failover.

### Active-active

- Both regions serve traffic concurrently.
- Data replicated bi-directionally (or partitioned by tenant).
- Failover: regional health-check pulls a region; remaining absorbs full load.

**RTO**: seconds-to-minutes.
**RPO**: 0 if same-DC OR replication lag if cross-region.
**Cost**: ~2× single-region.

Pitfalls:
- Bi-directional replication conflict resolution (last-write-wins / CRDTs / per-tenant primary).
- Surprise cross-region calls (latency > 100ms).
- Capacity planning: each region must absorb 100% if other fails.
- Stateful services synced across regions (Redis with cross-region replication, etc.).

### Per-region tenants (data residency / partitioning)

- Tenants assigned to a home region.
- All tenant data in that region.
- No cross-region replication of tenant data (compliance).
- Per-region cluster; control plane (auth, billing) may be globally replicated.

**RTO** (per-region failure): full down for tenants in that region until restored.
**RPO**: backup restore RPO.
**Cost**: linear in region count.

Pitfalls:
- Cross-region tenant migration is hard.
- Customer-facing region selection at signup.
- Search/analytics across tenants requires careful aggregation.
- Compliance (GDPR sub-data residency, sovereignty laws) must be designed in.

## Per-tier recommendations

### Compute

- Active-passive: secondary scaled to 1-2 instances hot-standby.
- Active-active: each region capacity = peak load (2× redundant).
- Per-region: each region sized to its tenant load.

### Database

- AWS RDS: read replicas across regions (max one writer per region; can promote).
- Aurora Global Database: cross-region replicas with storage-level replication — AWS documents replication latency as *"typically under a second"*, and a planned **switchover** relocates the primary *"with no data loss"* while an unplanned **failover** loses whatever had not replicated at that instant (https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html). Do not quote a fixed RPO: for unplanned failover the RPO IS the lag, so measure and alarm on the lag. Aurora PostgreSQL global databases additionally expose a managed RPO setting — read its current limitations before relying on it.
- PostgreSQL native: streaming replication; failover via Patroni / pg_auto_failover.
- Cassandra / DynamoDB / Cosmos DB: native multi-region writeable.
- For transactional workloads: prefer AP design with single primary; CP design (distributed transactions) is hard.

### Cache

- ElastiCache Global Datastore (Redis cross-region).
- Don't share cache across regions for low-latency access; replicate for warm-standby.
- Treat cache as "warm but not authoritative" — DB is source of truth.

### Object storage

- S3 Cross-Region Replication (CRR) for backups / shared assets.
- Bidirectional CRR available — careful with conflicts.
- Per-region buckets for tenant data with residency requirements.

### Queues + streams

- SQS: per-region queue; consumer in same region; fanout via SNS.
- Kafka: cross-region replication via MirrorMaker / Confluent Replicator.
- Background jobs: producer + consumer co-located in region.

### DNS + load balancing

- Route53 with health checks + latency-based routing.
- AWS Global Accelerator for static anycast IP.
- Cloudflare Load Balancer for edge-near routing.
- ALB / NLB are regional — stitched with Global Accelerator or DNS.

## DR drill cadence

| Cadence | Drill |
|---|---|
| Quarterly | Backup restore (verify RPO; restore one DB to a new instance; verify data integrity) |
| Quarterly | Failover dry run (run failover in staging; verify RTO; document gaps) |
| Yearly | Full failover (production cutover to secondary for ≥1 hour; verify operates correctly) |
| After every architecture change | Re-verify DR plan still holds |

A DR plan that's never drilled is a DR plan that won't work when needed.

## Cost vs benefit decision tree

```
Are we losing customers / revenue from outages?
├─ NO → single-region with good SLAs is fine.
└─ YES → quantify: how much / hour of outage?
        ├─ < $X/hour → fix single-region issues first (HA, monitoring).
        └─ > $X/hour → multi-region justified.
                        ├─ Latency-driven? → start with edge cache / CDN.
                        ├─ DR-driven? → active-passive.
                        ├─ Compliance-driven? → per-region partitioning.
                        └─ Capacity-driven? → active-active or shard.
```

## Anti-patterns

- **"Going multi-region"** before understanding which axis matters → wrong architecture.
- **Untested failover** → discovered broken at the moment of disaster.
- **Replication health not monitored** → silent drift.
- **Stateless app → multi-region trivial** assumption — stateful caches / sessions / rate limits / idempotency stores all matter.
- **Cost surprise** — egress between regions can dwarf compute cost.
- **Cross-region calls in hot paths** → latency tail explodes.
- **Conflict-resolution policy unstated** → data corruption under partition.
- **Compliance assumption** that S3 CRR satisfies GDPR — verify with legal.

## Project-specific anchors

(Phase 4.6 fills this with the project's actual region topology, replication mechanism, failover playbook, last drill date.)

## Related

- `dr-audit` — audits the backup + restore posture this pattern's DR topology assumes (its detector #7 reconciles the running footprint against the topology declared here).
