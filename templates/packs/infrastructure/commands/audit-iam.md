---
description: Audit IAM (cloud + service) policies for least-privilege violations, dead permissions, overly-broad roles, missing MFA, and suspicious entitlement chains.
---

# /audit-iam

IAM is where blast-radius lives. Over-broad roles + dead permissions + missing MFA = the pre-conditions for the next breach. Run periodically.

## Phases applied

1, 2, 3, 4, 6 (skips Update/Improve — read-only audit + recommendations).

## When to use

- Quarterly minimum.
- Pre-acquisition due diligence.
- After org / team change (members joined / left / changed roles).
- Post-incident — verify the breach class is now mitigated.

## Phase 1 — Understand

Confirm scope:
- Cloud provider(s): AWS / GCP / Azure / multi.
- Account scope: single account / multi-account org / specific.
- Identities to audit: humans only / services only / both.
- Granularity: every role / production-facing only.

## Phase 2 — Organize

Five concerns audited in parallel:

1. **Identity inventory** — humans, service accounts, OIDC federations, role assumptions.
2. **Permission breadth** — wildcards (`*`), broad-action policies (`AdministratorAccess`), unscoped resources.
3. **Permission usage** — Access Analyzer / CloudTrail data → which permissions are actually used vs declared.
4. **MFA + auth** — humans without MFA, IAM users with long-lived access keys.
5. **Cross-account / cross-service entitlement** — chains where service A can assume role in service B; identify trust boundaries.

## Phase 3 — Retrieve

Tools:
- AWS: `aws iam`, IAM Access Analyzer, `aws-iam-tester`, Steampipe (`steampipe query aws_iam_*`), Cloudsplaining, ScoutSuite.
- GCP: `gcloud iam`, Policy Analyzer, Forseti, Trivy.
- Azure: `az role`, Microsoft Defender for Cloud, AzureRM Tooling.
- Multi-cloud: Cloudsplaining, ScoutSuite, Prowler.
- Org-wide: Sumologic Cloud SIEM, Wiz, Lacework.

Read project's:
- `ai/architecture.md` — system topology.
- IAM policy files in repo (Terraform / CloudFormation / Pulumi).
- Auth setup (SSO / Okta / Azure AD).
- Past incidents in `ai/_baseline/failures/`.

## Phase 4 — Generate

```
## IAM audit — <date>

### Identity inventory
- Human identities:        <count>
  - via SSO:               <count>
  - via IAM users:         <count>      (target: 0; SSO preferred)
  - with MFA enforced:     <count>      (target: 100%)
  - inactive 90+ days:     <count>      (target: 0; deactivate)
- Service identities:      <count>
  - via OIDC federation:   <count>      (preferred for CI/CD)
  - via long-lived keys:   <count>      (target: 0; rotate or replace)
- Cross-account roles:     <count>

### Permission breadth findings

**CRITICAL — wildcard or admin-equivalent:**
- Role `prod-deployer` has `iam:*` on `*`. Effectively root.
  Used permissions (CloudTrail 90d): `iam:PassRole`, `iam:GetRole` only.
  Recommended: scope to specific roles + actions.

- IAM user `ci-bot` has `AdministratorAccess` policy attached.
  Used permissions (90d): only S3 + Lambda invoke.
  Recommended: replace with OIDC federation; scope to S3 + Lambda actions only.

**HIGH — broad action, broad resource:**
- Role `analytics-reader` has `s3:Get*` on `arn:aws:s3:::*`.
  Used: only `prod-analytics-bucket`.
  Recommended: scope resource to specific bucket ARN.

**MEDIUM — broad action, specific resource:**
- (lower-priority items)

### MFA + access key findings

**MISSING MFA:**
- 3 IAM users without MFA enforced.
  - alice@team — last activity 2025-09-12 (active).
  - bob@team — last activity 2025-04-01 (inactive — should be deactivated).
  - service-tester — service account; should not be IAM user. Migrate to OIDC federation.

**LONG-LIVED ACCESS KEYS (> 90 days old):**
- 12 access keys not rotated > 90d.
  - 2 are "emergency break-glass" — verify rotation policy + storage location.
  - 10 are CI/CD service identities — migrate to OIDC federation; eliminate keys.

### Cross-service entitlement chains

```
ci-bot (AdminAccess)
  └─→ assume → prod-deployer (iam:*)
                    └─→ assume → root-org-admin
                                      └─ effectively manages every account
```

**CRITICAL:** ci-bot → prod-deployer → root-org-admin chain. Compromise of `ci-bot` = compromise of org root.

Recommended: break the chain. ci-bot should not assume `prod-deployer`; deploys should use OIDC + per-environment scoped role.

### Dead permissions (declared but never used in 90d)

- 47 role/permission pairs declared but never invoked in 90 days.
- 23 are clearly safe to remove (long-deprecated services).
- 24 require investigation (might be break-glass / disaster-recovery only).

### Recommendations (ordered by impact)

| # | Action | Impact | Effort |
|---|---|---|---|
| 1 | Break ci-bot → prod-deployer → root-org-admin chain | CRITICAL — prevents single-point-of-compromise | 2 days |
| 2 | Replace IAM-user CI bots with OIDC federation | Eliminates 10 long-lived keys | 3 days |
| 3 | Enforce MFA org-wide (deactivate users without MFA after grace) | High — single biggest auth-attack mitigation | 1 week with comms |
| 4 | Scope `prod-deployer` to actual used actions | Reduces blast radius | 1 day |
| 5 | Remove dead-permission grants (47 pairs) | Reduces audit noise | 4 hours |
| 6 | Enable IAM Access Analyzer org-wide | Continuous detection | 2 hours |
| 7 | Set 90-day rotation policy on remaining IAM keys | Compliance + hygiene | 1 day |

### Posture
- Cloudsplaining score: <X/100>
- ScoutSuite findings (last run): <C / H / M / L>
- AWS Trusted Advisor IAM findings: <count>

### Out-of-scope (deferred)

- Network IAM (VPC + security groups) — separate audit.
- Application-level RBAC (in-app permissions) — covered by `@auth-reviewer`.
- Database IAM (RDS, Cloud SQL) — separate per-engine audit.
```

## Phase 6 — Validate

After applying recommendations:
- Re-run audit; findings count drops.
- CloudTrail confirms operational scripts still work (didn't break ci-bot deploys).
- MFA enforcement: confirm SSO / IdP applies to remaining IAM users.
- Access Analyzer enabled + alerts wired.

## Output format

```
## /audit-iam complete

Cloud: <provider>
Identities audited: <count>
Critical findings: <count>
High findings: <count>
Recommendations: P0 <count> / P1 <count> / P2 <count>

Report: ai/audits/iam-<date>.md
```

## Hard rules

- **No `iam:*` wildcards on production roles.** Scope always.
- **No long-lived IAM access keys for CI/CD.** Use OIDC federation (GitHub Actions / GitLab / etc.).
- **MFA enforced on all human identities.** No exceptions.
- **Cross-account chains documented with trust rationale.** Implicit chains = invisible blast radius.
- **Access Analyzer / Policy Analyzer enabled.** Continuous detection beats periodic audits.

## Failure modes

- Removed "dead" permission that was actually used by a once-monthly job → broke job.
- Enforced MFA on a non-human IAM user used by CI → CI broke.
- Scoped role to actions used in last 90d → missed seasonal / annual operations.
- "Eliminated" key in IAM but the secret was hardcoded in a Lambda → Lambda broken on next invocation.
- Broke trust chain without comms → service deploys started failing silently.

## Related

- `cost-audit` — sometimes overlap (costly resources can be removed when their roles are).
- `provision-tier` — uses IAM scoping principles in new resources.
- `@security-auditor` — broader; this command is the IAM dimension.
- `secret-scan` — different concern; related (long-lived keys are ugly secrets).
- `.claude/rules/security-principles.md` — A01 (Broken Access Control), A07 (Auth Failures).
