---
name: dr-audit
description: Backup-coverage + restore-readiness audit of an EXISTING footprint (terraform state / live cloud / k8s). Finds unbackupped stores, missing PITR, stale/absent restore drills, undeclared RPO/RTO.
---

# dr-audit

## Premise

Backup existence is not recovery capability. An untested backup is a hope, not a control — this skill audits what is already running for provable restore capability.

**Cite-or-halt.** Every gap cites the resource id / state address / manifest path **and** the specific missing config. "DR looks weak" is a vibe, not a finding.

**Ownership boundary:** `multi-region` *designs* RTO/RPO + failover · `provision-tier` *enforces* backups at creation · `tf-plan-review` catches backup *removal* in a pending plan · `dr-audit` (this) *audits the running footprint*.

## Scans for (cite-or-halt)

1. Stateful store with NO backup config — `backup_retention_period = 0`.
2. No PITR / retention too short for the data class.
3. No restore-drill record OR a stale one (> 90 days).
4. Undeclared RPO/RTO per store — cannot size retention or judge readiness.
5. Single-AZ production datastore (no failover).
6. Missing `prevent_destroy` / deletion-protection on a data resource.
7. Declares multi-region but has no cross-region replica/backup.
8. Backups encrypted with a key sharing the store's blast radius.

## Output

A backup-coverage matrix (one row per stateful store) + a restore-readiness verdict.

```
## DR audit — <footprint>

| Resource                    | Backup? | PITR? | Retention | Last drill        | RPO/RTO | Verdict |
|-----------------------------|---------|-------|-----------|-------------------|---------|---------|
| aws_db_instance.orders      | ✓       | ✓     | 14d       | 2026-05-02 (68d)  | ✓       | READY   |
| aws_s3_bucket.uploads       | ✗       | —     | —         | never             | ✗       | BLOCK   |

**BLOCK.** N production stores without proven restore capability.
```

Verdict rule: **BLOCK on any unbackupped production store**, and BLOCK a store whose only weakness is a stale/absent drill.

## Rules

- A read-replica is not a backup; multi-AZ HA is not DR.
- Ephemeral / reproducible stores are backup-exempt — dismiss citing the rebuild path, not silence.
- Never call a store DR-ready without a fresh restore-drill record. Don't fabricate a drill — hand it to the data owner.

## Related

- `provision-tier` — creation-time backup enforcement; this audits the running result.
- `multi-region` — designs RTO/RPO + failover; this verifies the footprint backs the design.
- `k8s-audit` — cluster HA/security; DR of PVs is audited here via Velero / VolumeSnapshot.
- `@infra-architect` — owns the topology; DR gaps route back for the design fix.
