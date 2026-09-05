---
name: dr-audit
description: Backup-coverage + restore-readiness audit of an EXISTING infrastructure footprint (terraform state / live cloud / k8s). Finds unbackupped stateful stores, missing PITR, stale/absent restore drills, undeclared RPO/RTO. Distinct from provision-tier (creation-time backup enforcement) and multi-region (RTO/RPO design); this audits what is already running.
allowed-tools: [Read, Grep, Glob, Bash]
---

# dr-audit

## Premise

The outage this skill exists to prevent: a production datastore that was never backed up, or one whose "backups" were never restore-tested — the classic "we had backups but nobody ever ran a restore, and the restore didn't work" post-mortem. Backup existence is not recovery capability; an untested backup is a hope, not a control.

**Cite-or-halt.** Every gap cites the resource id / state address / manifest path **and** the specific missing config (the absent `backup_retention_period`, the `point_in_time_recovery { enabled = false }`, the missing drill record). "DR looks weak" is a vibe, not a finding. A verdict (READY / BLOCK) is grounded in the coverage matrix, not a global feel.

**Ownership boundary (state verbatim):**
- **`multi-region`** *designs* the DR topology — it picks active-passive vs active-active and *declares* the RTO/RPO targets and failover mechanism.
- **`provision-tier`** *enforces* backups at *creation time* — it refuses to provision a stateful tier without backup config wired in.
- **`tf-plan-review`** catches *removal* of backup resources in a *pending plan* before apply.
- **`dr-audit`** (this skill) *audits an already-running footprint* — it inspects state / live resources / cluster for whether those backups actually exist, whether PITR is on, and whether a restore has actually been drilled. It is the audit-of-existing-state counterpart to provision-tier's creation-time enforcement.

If the finding is "this new tier should be created with backups," that's provision-tier. If it's "this running store has no backup / no drill," that's here.

## When to run

- Periodic DR-posture review (quarterly, aligned with `multi-region`'s drill cadence).
- Before a launch / GA — verify every production store is backed up and has a declared RPO/RTO.
- After adding a stateful store (new RDS, new bucket, new PV) — confirm it didn't ship without backup coverage.
- **NOT a substitute for an actual restore drill.** This skill audits that a drill is *recorded and fresh*; it does not perform the restore. A green matrix with a stale drill record is still BLOCK on that store.

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

Each finding cites `<resource id / state address / path>` + the missing config.

1. **Stateful store with NO backup config.** Any RDS / ElastiCache-with-persistence / managed DB / bucket / PV with backups off.
   - BAD: `aws_db_instance.app { backup_retention_period = 0 }` — automated backups disabled.
   - GOOD: `backup_retention_period = 14` (+ an AWS Backup plan covering it).
   - Heuristic: `grep -rn 'backup_retention_period\s*=\s*0' *.tf`; `aws rds describe-db-instances --query 'DBInstances[?BackupRetentionPeriod==\`0\`].DBInstanceIdentifier'`.

2. **No PITR / retention too short for the data class.** Retention shorter than the store's tolerable data-loss window.
   - BAD: DynamoDB table with `point_in_time_recovery { enabled = false }`; RDS `backup_retention_period = 1` on a system-of-record.
   - GOOD: PITR enabled; retention sized to the declared RPO + a discovery-lag margin.
   - Heuristic: `grep -rn 'point_in_time_recovery' *.tf` and flag `enabled = false` or absent on managed tables.

3. **No restore-drill record OR a stale one (> 90 days).** No proof a restore was ever exercised.
   - BAD: no `ai/runbooks/restore-*.md` / no AWS Backup restore-job in the last 90 days.
   - GOOD: `ai/runbooks/restore-<store>.md` dated within 90 days, with measured restore time + data-integrity check.
   - Heuristic: check for a drill record path; `find ai -name 'restore-*.md'` + compare its date; `aws backup list-restore-jobs`.

4. **Undeclared RPO/RTO per store.** A store with backups but no stated recovery objectives — you cannot size retention or judge readiness.
   - BAD: RDS backed up, but no RPO/RTO documented anywhere for it.
   - GOOD: each store declares RPO (data-loss budget) + RTO (recovery-time budget) in IaC comments / runbook / ADR.
   - Heuristic: cross-reference each stateful resource against a declared objectives table; unmatched = finding.

5. **Single-AZ production datastore (no failover).** A prod store with no standby.
   - BAD: `aws_db_instance.app { multi_az = false }` on a production tier.
   - GOOD: `multi_az = true` (or an equivalent read-replica promotion path documented).
   - Heuristic: `grep -rn 'multi_az\s*=\s*false' *.tf`.

6. **Missing `prevent_destroy` / deletion-protection on a data resource.** One `terraform destroy` or console fat-finger from data loss.
   - BAD: `aws_db_instance.app` with no `lifecycle { prevent_destroy = true }` and `deletion_protection = false`.
   - GOOD: both set on every system-of-record store + primary bucket + KMS key.
   - Heuristic: `grep -rn 'prevent_destroy\|deletion_protection' *.tf` and flag data resources missing both.

7. **A tier that declares multi-region but has no cross-region replica/backup.** The design says multi-region; the running footprint doesn't back it.
   - BAD: `multi-region`'s project block says active-passive, but the bucket has no CRR rule and the DB has no cross-region snapshot copy.
   - GOOD: cross-region replication / cross-region backup copy present, matching the declared topology.
   - Heuristic: reconcile the declared topology (`multi-region` project block) against actual `aws_s3_bucket_replication_configuration` / cross-region AWS Backup copy actions.

8. **Backups encrypted at rest, but the key shares the store's blast radius.** A backup unrecoverable in the exact scenario it's for.
   - BAD: RDS snapshots encrypted with a KMS key in the *same account + region* as the primary — a region/account compromise takes the backup too.
   - GOOD: backups (or a copy) held under a key / account / region outside the primary's blast radius.
   - Heuristic: compare the backup's KMS key region/account to the primary's; same-blast-radius = finding.

## Output

A **backup-coverage matrix** — one row per stateful store — plus a restore-readiness verdict.

```
## DR audit — <footprint / account / cluster>

### Backup-coverage matrix

| Resource                     | Backup? | PITR? | Retention | Last restore drill | RPO/RTO declared? | Verdict |
|------------------------------|---------|-------|-----------|--------------------|-------------------|---------|
| aws_db_instance.orders       | ✓       | ✓     | 14d       | 2026-05-02 (68d)   | ✓ 5m / 30m        | READY   |
| aws_dynamodb_table.sessions  | ✓       | ✗     | —         | never              | ✗                 | BLOCK   |
| aws_s3_bucket.uploads        | ✗       | —     | —         | never              | ✗                 | BLOCK   |
| pv/postgres-primary          | ✓ Velero| n/a   | 30d       | 2026-01-10 (180d)  | ✓ 15m / 1h        | BLOCK*  |

* backup present but drill stale (>90d) — restore capability unproven.

### Findings (cite-or-halt)

BLOCK — aws_s3_bucket.uploads: no versioning, no replication, no backup.
  Missing: aws_s3_bucket_versioning + a backup/replication rule. Production user data.
BLOCK — aws_dynamodb_table.sessions: point_in_time_recovery.enabled = false; no RPO/RTO.
BLOCK* — pv/postgres-primary: last Velero restore drill 180d ago — refresh the drill.

### Restore-readiness verdict

**BLOCK.** 3 production stores without proven restore capability.
Closure: report-with-fix for #2 (enable PITR) and #7-boundary items;
halt-handoff to the data owner for the un-drilled restore on postgres-primary.
```

Verdict rule: **BLOCK on any unbackupped production store**, and BLOCK a store whose only weakness is a stale/absent drill (restore capability unproven). Closure verbs: **report-with-fix** (config-level gaps you can hand a diff for) / **halt-handoff** (a drill must be run by the data owner — not something the audit fabricates).

## False positives / gotchas

- **Ephemeral / reproducible stores need no backup — dismiss with reason.** A cache, a derived search index, a materialized view that can be rebuilt from the system of record is legitimately backup-exempt. Dismiss it citing the documented rebuild path, not silence.
- **A read-replica is not a backup.** A replica faithfully replicates a `DROP TABLE` / logical corruption / bad migration in seconds. It protects against host failure, not against a mistake. A store whose only "backup" is a replica is still a finding.
- **Backup existence ≠ restore capability** — the whole point. A green "Backup? ✓" with no drill is *not* READY. The matrix separates the two columns precisely so this can't be waved past.
- **Multi-AZ / HA is not DR.** Cross-AZ failover survives a rack/AZ loss, not an account deletion or a corrupt write; don't let `multi_az = true` satisfy the backup detectors.

## Halt conditions

- Refuse to emit a gap without the cited resource id / state address / path **and** the specific missing config. No cite → no finding.
- A cache or derived store with a **documented rebuild path** is not a finding — do not flag it just to pad the matrix.
- Do **not** claim a store DR-ready without a restore-drill record. Backup config present + no drill = BLOCK, never READY.
- Refuse to call retention "adequate" without the declared RPO to size it against — an undeclared RPO is itself finding #4, not an assumption to invent.
- Don't fabricate or trigger a restore drill — audit that one is recorded and fresh; hand off the actual drill to the data owner.

## Related

- `provision-tier` — creation-time backup enforcement; this skill audits the running result.
- `multi-region` — designs RTO/RPO + failover; this skill verifies the footprint backs the design (detector #7).
- `tf-plan-review` — catches backup-resource *removal* in a pending plan (detector overlap on `prevent_destroy`).
- `k8s-audit` — cluster HA/security; DR of PVs is audited here via Velero / VolumeSnapshot.
- `@infra-architect` — owns the infra topology this audits; DR gaps route back to the architect for the design-level fix.
