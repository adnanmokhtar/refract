---
name: dr-audit
description: Backup-coverage + restore-readiness audit of an EXISTING footprint (terraform state / live cloud / k8s). Finds unbackupped stores, missing PITR, stale/absent restore drills, undeclared RPO/RTO.
---

# dr-audit

## Premise

Backup existence is not recovery capability. An untested backup is a hope, not a control — this skill audits what is already running for provable restore capability.

**Cite-or-halt.** Every gap cites the resource id / state address / manifest path **and** the specific missing config. "DR looks weak" is a vibe, not a finding.

**Ownership boundary:** `multi-region` *designs* RTO/RPO + failover · `provision-tier` *enforces* backups at creation · `tf-plan-review` catches backup *removal* in a pending plan · `dr-audit` (this) *audits the running footprint*.

## Adapt to the codebase

Detect the footprint (`terraform state list`, cloud CLI, `kubectl`) and map each stateful store to its native backup + restore-test signal.

| Platform | Backup mechanism | PITR / snapshot | Restore-test signal |
|---|---|---|---|
| **AWS** | RDS automated backups, AWS Backup plans, EBS snapshots | RDS/Aurora PITR (`backup_retention_period > 0`), DynamoDB `point_in_time_recovery`, EBS snapshot schedule | AWS Backup restore-job history; a recorded restore-drill doc |
| **AWS S3** | Versioning + Cross-Region Replication | Object versions; MFA-delete | Documented object-restore test |
| **GCP** | Cloud SQL automated backups, GCS versioning, Persistent Disk snapshots | Cloud SQL PITR (binary logs / WAL), disk snapshot schedule | Cloud SQL clone/restore record |
| **Azure** | Recovery Services / Backup vault | Azure SQL PITR, disk snapshots | Backup vault restore-point + test-restore log |
| **k8s** | Velero (cluster + PV), CSI volume snapshots, stateful-set backup jobs | VolumeSnapshot / VolumeSnapshotClass; Velero schedules | `velero restore` history; recorded namespace restore test |
| **terraform** | Backup resources declared in IaC + `lifecycle { prevent_destroy = true }` | `aws_db_instance.backup_retention_period`, `aws_dynamodb_table.point_in_time_recovery`, `aws_s3_bucket_versioning` | ADR / runbook citing the last drill |

## Scans for (cite-or-halt)

Each finding cites `<resource id / state address / path>` + the missing config. The heuristic beside each one is what produces the citation — a scan with no command behind it produces an opinion.

1. **Stateful store with NO backup config.** BAD: `backup_retention_period = 0`. GOOD: a non-zero retention plus a backup plan covering it.
   - `grep -rn 'backup_retention_period\s*=\s*0' *.tf`
   - `aws rds describe-db-instances --query 'DBInstances[?BackupRetentionPeriod==`0`].DBInstanceIdentifier'`
2. **No PITR / retention too short for the data class.** BAD: `point_in_time_recovery { enabled = false }` on a system-of-record table. GOOD: PITR on, retention sized to the declared RPO plus a discovery-lag margin.
   - `grep -rn 'point_in_time_recovery' *.tf` — flag `enabled = false` or absent on managed tables.
3. **No restore-drill record, or a stale one (> 90 days).** GOOD: a drill record dated within 90d carrying the measured restore time and a data-integrity check.
   - `find ai -name 'restore-*.md'` and compare its date; `aws backup list-restore-jobs`.
4. **Undeclared RPO/RTO per store.** A store with backups but no stated objectives cannot have its retention sized or its readiness judged.
   - Cross-reference every stateful resource against a declared objectives table; unmatched = finding.
5. **Single-AZ production datastore (no failover).**
   - `grep -rn 'multi_az\s*=\s*false' *.tf`
6. **Missing `prevent_destroy` / deletion-protection on a data resource.** One destroy or console fat-finger from data loss.
   - `grep -rn 'prevent_destroy\|deletion_protection' *.tf` — flag data resources missing both.
7. **Declares multi-region but has no cross-region replica/backup.** The design says active-passive; the footprint does not back it.
   - Reconcile the declared topology against actual replication configuration / cross-region backup copy actions.
8. **Backups encrypted with a key sharing the store's blast radius.** Snapshots encrypted under a key in the same account and region as the primary are unrecoverable in exactly the scenario they exist for.
   - Compare the backup's key region/account to the primary's; same blast radius = finding.

## Output

A backup-coverage matrix (one row per stateful store) + a restore-readiness verdict. The Backup and Last-drill columns are separate precisely so a green backup cannot be read as recovery capability.

```
## DR audit — <footprint>

| Resource                    | Backup? | PITR? | Retention | Last drill        | RPO/RTO | Verdict |
|-----------------------------|---------|-------|-----------|-------------------|---------|---------|
| aws_db_instance.orders      | ✓       | ✓     | 14d       | 2026-05-02 (68d)  | ✓       | READY   |
| aws_s3_bucket.uploads       | ✗       | —     | —         | never             | ✗       | BLOCK   |
| pv/postgres-primary         | ✓       | n/a   | 30d       | 2026-01-10 (180d) | ✓       | BLOCK*  |

* backup present but drill stale — restore capability unproven.

**BLOCK.** N production stores without proven restore capability.
```

Verdict rule: **BLOCK on any unbackupped production store**, and BLOCK a store whose only weakness is a stale/absent drill. Closure verbs: **report-with-fix** for config-level gaps you can hand a diff for; **halt-handoff** where a drill must be run by the data owner.

## False positives / gotchas

- **Ephemeral / reproducible stores need no backup** — a cache, a derived index, a rebuildable materialized view. Dismiss citing the documented rebuild path, not silence.
- **A read-replica is not a backup.** It replicates a `DROP TABLE` in seconds. It protects against host failure, not against a mistake.
- **Backup existence ≠ restore capability.** A green Backup column with no drill is not READY; the matrix separates the two columns so this cannot be waved past.
- **Multi-AZ / HA is not DR.** Cross-AZ failover survives a rack or AZ loss, not an account deletion or a corrupt write.

## Halt conditions

- Refuse to emit a gap without the cited resource id / state address / path **and** the specific missing config. No cite → no finding.
- A cache or derived store with a documented rebuild path is not a finding — do not flag it to pad the matrix.
- Never call a store DR-ready without a restore-drill record. Backup config present + no drill = BLOCK, never READY.
- Refuse to call retention "adequate" without the declared RPO to size it against — an undeclared RPO is finding #4, not an assumption to invent.
- Don't fabricate or trigger a restore drill — audit that one is recorded and fresh; hand the drill to the data owner.

## Related

- `provision-tier` — creation-time backup enforcement; this audits the running result.
- `multi-region` — designs RTO/RPO + failover; this verifies the footprint backs the design.
- `k8s-audit` — cluster HA/security; DR of PVs is audited here via Velero / VolumeSnapshot.
- `@infra-architect` — owns the topology; DR gaps route back for the design fix.
