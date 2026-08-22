---
description: Audit IAM (cloud + service) policies for least-privilege violations, dead permissions, overly-broad roles, missing MFA, and suspicious entitlement chains.
---

# /audit-iam

IAM is where blast-radius lives. Over-broad roles + dead permissions + missing MFA = the pre-conditions for the next breach. Run periodically.

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves. Every finding cites `<resource>:<arn>` or `<terraform-file:line>`.** A finding without a concrete identifier is a hand-wave and MUST be dropped from the report. "Some roles look broad" is not a finding. "`arn:aws:iam::123456789012:role/prod-deployer` has `iam:*` on `*` (declared at `infra/terraform/iam/prod.tf:42`); CloudTrail 90d shows only `iam:PassRole` + `iam:GetRole` invoked" is a finding.

**The closure verb is `report-with-citation`.** Each row in the output table closes by citing one of:
- a cloud resource ARN / GCP resource ID / Azure resource ID
- a `<terraform|cloudformation|pulumi-file>:<line>` for declared-in-IaC findings
- a CloudTrail / Access Analyzer / Policy Analyzer event ID for usage-based findings
- a SSO / IdP record ID for human-identity findings

No citation = no finding. The audit halts before write if any row lacks a citation.

**Mechanical halt — hand-wave grep (mandatory before report write):**
1. Grep the draft report for: `some `, `several `, `a few `, `many `, `appears to`, `looks like`, `might be`, `possibly`, `etc.`, `...`. Each hit MUST be replaced with a citation or the row is dropped.
2. Grep for any finding row missing both `arn:` and `<file>:<line>` — drop the row.
3. Grep recommendations for verbs without resource scope (`tighten policies`, `review keys`, `clean up`) — replace with the specific resource list or drop.
4. If the draft is empty after these passes, report "0 findings — surface area clean" rather than padding.

**The agent does NOT:**
- Generalize ("most roles are over-broad") without enumerating each role.
- Recommend "review X periodically" — the audit IS the review; produce concrete deletes/scopes.
- Defer to "the team should decide" — surface the data; the recommendation column is mandatory.

**The agent ONLY escalates when:**
- A finding's blast radius is org-root level (cross-account chain reaching org admin) — surface as P0 with the chain enumerated, not as a question.
- IaC source for a live resource cannot be located (drift) — record `drift: <arn> not declared in repo` as the finding itself.

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

**Prefer the provider's own least-privilege primitives over a third-party scanner.** They are first-party, always current, and they answer the two questions this audit is actually asking — what is over-granted, and what is unused. Third-party tools in this space churn hard (this list previously named Forseti, archived by Google on 2025-01-11); confirm any tool is still maintained before recommending it.

- **AWS — start here, not with a scanner.** IAM Access Analyzer gives you all of it first-party (https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html):
  - **unused access analyzers** — "findings highlight unused roles, unused access keys for IAM users, and unused passwords for IAM users. For active IAM roles and users, the findings provide visibility into unused services and actions." That IS the "dead permissions" section below; do not hand-roll it from raw CloudTrail when this exists.
  - **external access analyzers** — resources shared outside the zone of trust, via logic-based reasoning rather than pattern matching.
  - **policy validation + custom policy checks** — including "check whether your updated policy grants new access compared to the existing version", which turns least-privilege into a CI gate rather than a quarterly report.
  - **policy generation from CloudTrail** — generates a scoped policy from observed activity, which is the concrete fix for every over-broad role this audit finds.
  - Note the Region caveat from the same page: external-access findings are per-Region and need an analyzer in each Region; unused-access findings are not Region-dependent.
  - Supplement with `aws iam get-account-authorization-details`, last-accessed data, and Prowler / Cloudsplaining / ScoutSuite for reporting shape.
- **GCP**: `gcloud iam`, Policy Analyzer, the IAM Recommender's role-recommendation surface, and Security Command Center for org-wide posture.
- **Azure**: `az role`, Microsoft Entra Permissions Management, Microsoft Defender for Cloud.
- **Multi-cloud**: Prowler, ScoutSuite, Cloudsplaining — check each is still maintained.

**Also audit the ENFORCEMENT mechanisms, not just the grants.** A least-privilege report that never mentions the controls that make least privilege stick is a snapshot, not a posture:
- **Permissions boundaries** on any role a developer or a pipeline can create or modify — without one, the ability to create roles is the ability to escalate.
- **Service control policies** (or the equivalent org-level guardrail) — the only control an account admin cannot remove.
- **Role trust policies** — an over-broad `Principal` or a missing external-id / OIDC `sub` condition is a wider hole than any permission list, because it decides WHO can assume, not what they can then do.

Read project's:
- `ai/architecture.md` — system topology.
- IAM policy files in repo (Terraform / CloudFormation / Pulumi).
- Auth setup (SSO / Okta / Azure AD).
- Past incidents in `ai/failures/`.

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

Source: IAM Access Analyzer unused-access findings, cross-checked against last-accessed data. Every
pair is enumerated — halt #1 bans `several`/`some`/`clearly`, and halt #2 drops any row without an
ARN, so a summary line with no list is not a finding.

| Principal (ARN) | Unused action(s) | Last used | Recommendation |
|---|---|---|---|
| `arn:aws:iam::123456789012:role/prod-deployer` | `iam:CreatePolicy`, `iam:DeleteRole`, `iam:AttachUserPolicy` | never (analyzer tracking since 2026-05-19) | remove — the role's deploy path never calls IAM write actions |
| `arn:aws:iam::123456789012:role/analytics-reader` | `s3:PutObject`, `s3:DeleteObject` | never | remove — read-only consumer |
| `arn:aws:iam::123456789012:role/legacy-etl` | `dynamodb:*` on `arn:aws:dynamodb:*:*:table/*` | 2025-11-02 | scope to the 2 tables it touched, or retire the role with its pipeline |
| … 44 further pairs enumerated in Appendix A, each with principal ARN + action + last-used date | | | |

Split the list by evidence, never by adjective:
- **Removable — no invocation in the window AND no documented periodic use**: 23 pairs (Appendix A, rows 1-23).
- **Hold — invocation window is shorter than the caller's period**: 24 pairs (Appendix A, rows 24-47), each naming the periodic job (month-end close, annual key rotation, DR drill) that would use it. A 90-day window cannot see a quarterly or annual operation; that is a limit of the evidence, not a property of the permission.

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
- **Access Analyzer / Policy Analyzer enabled**, including the unused-access analyzer. Continuous detection beats periodic audits, and it is what makes the dead-permission section evidence rather than inference.
- **Permissions boundary on every role-creating principal.** The ability to create a role without a boundary is the ability to escalate.
- **Org-level guardrail (SCP or equivalent) on the actions no account may ever take.** Anything enforceable only inside the account is not enforced against the account's own admin.
- **Trust policies scoped.** Every `sts:AssumeRole` trust names a specific principal plus a condition (external id, OIDC `sub`, source account). Who can assume is a wider question than what they can then do.

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (public exposure, wildcard / admin-equivalent grants, privilege escalation paths) → **SHOULD FIX** (over-broad scopes that should be tightened) → **OPTIONAL** (cleanup of unused roles) — each step carrying the policy / principal / `<file:line>` + **Fix** (concrete least-privilege grant) + **Verify** (the access test proving the principal can still do its job and no more), then the closing steps (re-run `/audit-iam` to confirm it comes back clean, `/learn-from-task`, then ship). A clean run collapses to a single line ("Least-privilege holds — clear to proceed"). The reader must never assemble the next steps themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Removed "dead" permission that was actually used by a once-monthly job → broke job.
- Enforced MFA on a non-human IAM user used by CI → CI broke.
- Scoped role to actions used in last 90d → missed seasonal / annual operations. The window is the limit of the evidence; say so in the report rather than calling the remainder "safe".
- Wrote "N pairs are clearly safe to remove" without listing them. Nobody could act on it, and the one row that was not safe was invisible.
- Recommended a scanner that had been archived for a year. Check maintenance status before naming a tool.
- "Eliminated" key in IAM but the secret was hardcoded in a Lambda → Lambda broken on next invocation.
- Broke trust chain without comms → service deploys started failing silently.

## Related

- `cost-audit` — sometimes overlap (costly resources can be removed when their roles are).
- `provision-tier` — uses IAM scoping principles in new resources.
- `@security-auditor` — broader; this command is the IAM dimension.
- `secret-scan` — different concern; related (long-lived keys are ugly secrets).
- `.claude/rules/security-principles.md` — A01 (Broken Access Control), A07 (Auth Failures).
