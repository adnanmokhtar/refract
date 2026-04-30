---
description: Review a Terraform / Pulumi / CloudFormation plan output. Catches dangerous changes (resource replacements that destroy data, IAM widening, public exposure) before apply.
---

# Skill: tf-plan-review

Pre-apply review of IaC changes. The plan is authoritative; this skill reads it like a hostile actor would.

## Premise

Find real issues. Every risk cites the resource address (`aws_db_instance.app`), the change symbol from the plan (`-/+`, `~`, `-`), and the trigger attribute that forced the change (`engine_version`, `availability_zone`, etc.). "Data loss" requires the resource type + replace symbol + the attribute change that caused it. IAM widening cites the policy name and the action being added. Verdict (BLOCK / APPROVE) is grounded in the specific findings, not a global feel.

## Halt conditions

- Refuse to verdict without `tfplan.json` (or equivalent) parsed — text plans hide sub-module changes.
- Refuse to pass an RDS replacement without explicit data-migration plan + ADR.
- Halt if the plan being reviewed isn't pinned to a saved plan file (`-out=tfplan`) — drift between plan and apply is real.
- Don't dismiss `tfsec` / `checkov` warnings without naming why each is acceptable.

## When to use

- Every Terraform PR / pre-apply.
- Every CloudFormation / Pulumi pre-deploy.
- Anytime a non-author runs `terraform apply` (verify they know what they're applying).
- Post-`terraform refresh` if drift detected (someone changed cloud out-of-band).

## Procedure

### 1. Run the plan

```bash
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
```

Parse `tfplan.json` programmatically OR `terraform show tfplan` for human-readable.

### 2. Categorize each change

| Symbol | Action | Risk |
|---|---|---|
| `+` | create | Low (new resource) |
| `~` | update in-place | Low to medium (depends on attribute) |
| `-/+` | replace (destroy + create) | **HIGH** — data loss possible |
| `-` | destroy | **CRITICAL** — verify intent |

### 3. Scan for high-risk patterns

| Pattern | Risk |
|---|---|
| `aws_db_instance` replaced (delete + create new) | **CRITICAL** — DB data lost |
| `aws_s3_bucket` replaced or destroyed | **CRITICAL** — bucket data lost |
| `aws_ebs_volume` destroyed | **HIGH** — volume data lost |
| `aws_kms_key` destroyed | **HIGH** — encrypted data un-decryptable |
| Security group widening (`0.0.0.0/0`, `::/0`) on inbound | **HIGH** — public exposure |
| S3 bucket ACL → public-read / ACL changed | **HIGH** — public data |
| IAM policy adding wildcard actions | **HIGH** — over-permission |
| IAM role assumed by `*` (any principal) | **CRITICAL** — anyone can assume |
| RDS `publicly_accessible: true` | **HIGH** — DB on public internet |
| VPC peering / TGW attachment | **MEDIUM** — verify networking correctness |
| Removal of monitoring / logging resources | **HIGH** — observability gap |
| Removal of backup resources | **CRITICAL** — recovery loss |
| `ignore_changes` added to a security-relevant attribute | **MEDIUM** — verify intent |

### 4. Verify safety mechanisms

- **`prevent_destroy = true`** on databases, KMS keys, primary buckets — verify lifecycle block respected.
- **State backend** — remote state with locking (S3 + DynamoDB / Terraform Cloud / GCS). NEVER local state for shared infra.
- **Plan applied from CI not local laptop** for production tiers (CI = audit trail + reviewed PR).
- **Approval policy** — production apply gated on manual approval / specific reviewer.

### 5. Cross-reference

- Compare plan to PR description: does the description mention every destroy / replace?
- Compare plan to ADR / ticket: every change is justified.
- Verify `terraform validate` clean.
- Verify `tflint` / `checkov` / `tfsec` static checks clean (or warnings explicitly addressed).

## Output format

```
## Terraform plan review — <PR / ticket>

### Plan summary
- Adds:        <count>
- Updates:     <count>
- Replaces:    <count>
- Destroys:    <count>

### Risks (ordered by severity)

**CRITICAL — DB replacement implies data loss:**
- `aws_db_instance.app` will be REPLACED.
  Trigger: `engine_version` change from 14 to 16 (major) requires replace.
  Implication: ALL DATA LOST unless restored from backup.
  Recommended: do NOT apply this plan. Use blue/green major-version migration instead.
  Alternative: snapshot before, restore after; expect downtime + data freshness gap.

**HIGH — IAM widening:**
- Policy `prod-deploy-policy` adds action `iam:*` on resource `*`.
  Implication: deployer effectively root.
  Recommended: scope to specific actions / resources used.

**HIGH — Public exposure:**
- Security group `web-sg` adds inbound `0.0.0.0/0` on port 22.
  Implication: SSH from anywhere on internet.
  Recommended: restrict to bastion CIDR or use SSM Session Manager instead.

**MEDIUM — Removal of observability:**
- `aws_cloudwatch_log_group.app` will be DESTROYED.
  Implication: existing logs gone; new logs need a replacement group.
  Recommended: add `prevent_destroy = true` if log retention matters; OR change `log_group_name` reference instead of destroy/recreate.

### Safety checks

| Check | Status |
|---|---|
| Remote state backend | ✓ S3 + DynamoDB lock |
| `prevent_destroy` on critical resources | ✗ missing on RDS instance — fix before apply |
| Apply gated through CI | ✓ via GitHub Actions |
| Approval policy | ✓ requires platform-team review |
| `terraform validate` | ✓ clean |
| `tflint` | ⚠ 2 warnings (auto-fixable) |
| `tfsec` | ✓ clean |
| `checkov` | ⚠ 1 warning (S3 bucket without lifecycle policy) |

### Verdict

**BLOCK APPLY.**

Blockers:
1. RDS replacement = data loss — re-plan with major-version blue/green path.
2. IAM widening — scope before merge.
3. Public SG inbound — use SSM or restrict.

Once blockers addressed, re-plan + re-review.
```

## Inputs

- `tfplan.json` (or equivalent for CFN / Pulumi).
- PR description for cross-check.

## Outputs

- Inline PR comments OR `ai/audits/tf-plan-<date>.md`.

## Failure modes

- Reviewed plan output but missed a transitive replacement (Terraform shows top-level changes; sub-modules' replacements may be one screen scroll down).
- Approved a "minor" change that triggered a chain of dependent replacements.
- Missed `lifecycle.create_before_destroy` semantics — resource looks "destroyed" but actually replaced safely.
- Dismissed `tfsec` warning as noise; was real (e.g., S3 bucket without versioning before encryption-at-rest).
- Reviewed plan but applied was a different plan (mismatched plan file).

## Related

- `audit-iam` — IAM widening flagged here also caught there.
- `cost-audit` — sometimes a "minor" change inflates cost.
- `provision-tier` — uses this skill in Phase 6 validate.
- `@security-auditor` — invoked for HIGH+ risks.
- `.claude/rules/security-principles.md` — A01 (Broken Access Control), A05 (Security Misconfiguration).
