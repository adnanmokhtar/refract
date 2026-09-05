---
name: tf-plan-review
description: Review a Terraform / Pulumi / CloudFormation plan output for dangerous changes before apply — resource replacements that destroy data, IAM widening, public exposure. Run on every pre-apply, and whenever a non-author is about to apply. Reads a plan diff — auditing the already-running footprint is `network-exposure-audit` and `dr-audit`.
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: tf-plan-review

Pre-apply review of IaC changes. The plan is authoritative; this skill reads it like a hostile actor would.

## Premise

Find real issues. Every risk cites the resource address (`aws_db_instance.app`), the change symbol from the plan (`-/+`, `~`, `-`), and the trigger attribute **as the plan itself named it** — the `# forces replacement` marker, or the `replace_paths` entry in `tfplan.json`. "Data loss" requires the resource address + the replace action + that quoted trigger. IAM widening cites the policy name and the action being added. Verdict (BLOCK / APPROVE) is grounded in the specific findings, not a global feel.

## Halt conditions

- Refuse to verdict without `tfplan.json` (or equivalent) parsed — text plans hide sub-module changes.
- Refuse to name a replacement TRIGGER without quoting the plan's own `replace_paths` entry or its `# forces replacement` marker. Which attributes force replacement is provider- and version-specific; asserting it from memory is guessing about the thing that destroys data.
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
terraform plan -out=tfplan -detailed-exitcode   # 0 = no changes, 1 = error, 2 = changes present
terraform show -json tfplan > tfplan.json
```

Parse `tfplan.json` programmatically; `terraform show tfplan` is for the human reader, not for the verdict. `-detailed-exitcode` is what makes "the plan is empty" a machine fact rather than a claim — use it for drift detection in CI.

### 2. Categorize each change — and read the plan's OWN reason

| Symbol | Action | Risk |
|---|---|---|
| `+` | create | Low (new resource) |
| `~` | update in-place | Low to medium (depends on attribute) |
| `-/+` | replace (destroy + create) | **HIGH** — data loss possible |
| `-` | destroy | **CRITICAL** — verify intent |

**Never assert from memory which attribute forces a replacement.** Whether an attribute is ForceNew is provider- and version-specific and it changes between provider majors. The plan already tells you:

- Human-readable plan: the `# forces replacement` marker sits on the exact attribute line.
- `tfplan.json`: `resource_changes[].change.actions` is `["delete","create"]` (or `["create","delete"]` under `create_before_destroy`), and `resource_changes[].change.replace_paths` names the attribute paths responsible.

Quote that marker or that path in the finding. A review that says "this attribute forces replacement" without quoting the plan is guessing, and it is guessing about the one thing that destroys data.

Three change shapes look alarming and are not — read the config before escalating:

- **`moved` blocks** — a resource address changed; Terraform moves state, nothing is destroyed.
- **`removed` blocks** (Terraform 1.7+) — removes a resource from state and *keeps the real infrastructure*. In the plan this reads as a removal; it is not a destroy. The inverse mistake is the dangerous one: a `removed` block written where a destroy was intended leaves an orphaned, unmanaged, still-billing resource.
- **`import` blocks** — brings an existing resource under management; the diff shown is the reconciliation, not a creation.

Conversely, `lifecycle.create_before_destroy` makes a genuine replacement *look* safer than it is; the old resource still goes away.

### 3. Scan for high-risk patterns

| Pattern | Risk |
|---|---|
| Any stateful resource with `-/+` and a `replace_paths` entry | **CRITICAL** — quote the path; data is lost unless a documented migration path exists |
| `aws_s3_bucket` destroyed **with `force_destroy = true` set** | **CRITICAL** — that flag is precisely what lets Terraform delete a non-empty bucket. Without it, a destroy of a non-empty bucket fails rather than silently losing objects, so the finding is the flag, not the destroy |
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

- **`prevent_destroy = true`** on databases, KMS keys, primary buckets — verify the lifecycle block is respected.
- **State backend** — remote state with locking, never local state for shared infra. On the S3 backend the current mechanism is **`use_lockfile = true`** (S3-native conditional writes); HashiCorp's own backend docs state that *"DynamoDB-based locking is deprecated and will be removed in a future minor version"* (https://developer.hashicorp.com/terraform/language/backend/s3). A backend block still carrying `dynamodb_table` is a MEDIUM finding with a named fix, not a pass.
- **Provider lock file committed** — `.terraform.lock.hcl` in version control, and the plan run against it. Without it the plan you reviewed and the plan that applies can resolve different provider versions, which is the same class of defect as an unpinned image tag.
- **`required_providers` + `required_version` constrained** — an unconstrained provider is an unreviewed upgrade waiting for the next `terraform init`.
- **Plan applied from CI, not a laptop** for production tiers (CI = audit trail + reviewed PR).
- **Approval policy** — production apply gated on manual approval / a specific reviewer.

### 5. Cross-reference

- Compare plan to PR description: does the description mention every destroy / replace?
- Compare plan to ADR / ticket: every change is justified.
- Verify `terraform validate` clean.
- Verify `tflint` / `checkov` / `tfsec` static checks clean (or warnings explicitly addressed).
- Confirm the applied plan IS the reviewed plan: `terraform apply tfplan` against the saved file, never a re-plan at apply time.

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
- `aws_db_instance.app` will be REPLACED (`actions: ["delete","create"]`).
  Trigger, quoted from the plan: `replace_paths: [["identifier"]]` — the human plan marks
  `~ identifier = "app-prod" -> "app-production" # forces replacement`.
  Implication: the existing instance is destroyed; its data does not move to the new one.
  Recommended: do NOT apply. Either revert the rename, or use a `moved` block if the intent
  was only to change the Terraform address rather than the real identifier.
  If the rename is genuinely wanted: snapshot → restore into the new instance → cut over,
  and expect downtime plus a data-freshness gap.
  (Note the discipline: the trigger is quoted from `replace_paths` / the `# forces replacement`
  marker. Which attributes are ForceNew differs by provider major — never assert it from memory.)

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
| Remote state backend + locking | ✓ S3 with `use_lockfile = true` (no deprecated `dynamodb_table`) |
| `.terraform.lock.hcl` committed + plan run against it | ✓ |
| `required_providers` / `required_version` constrained | ✗ provider unconstrained — pin before apply |
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
- Read a `removed` block as a destroy (it removes from state and LEAVES the infrastructure) — or, worse, missed that a `removed` block was written where a destroy was intended, leaving an unmanaged resource still on the bill.
- Approved a "minor" change that triggered a chain of dependent replacements.
- Missed `lifecycle.create_before_destroy` semantics — resource looks "destroyed" but actually replaced safely.
- Dismissed `tfsec` warning as noise; was real (e.g., S3 bucket without versioning before encryption-at-rest).
- Reviewed plan but applied was a different plan (mismatched plan file).

## Related

- `network-exposure-audit` — a widening SG / public-DB / public-bucket change flagged in this plan diff is the same exposure class that skill audits across the whole running/declared footprint.
- `audit-iam` — IAM widening flagged here also caught there.
- `cost-audit` — sometimes a "minor" change inflates cost.
- `provision-tier` — uses this skill in Phase 6 validate.
- `@security-auditor` — invoked for HIGH+ risks.
- `.claude/rules/security-principles.md` — A01 (Broken Access Control), A05 (Security Misconfiguration).
