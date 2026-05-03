---
description: Cross-feature audit. Walks the project's declared business cycles (Create→Update→Delete, Subscribe→Unsubscribe, Send→Resend, etc.) and surfaces every missing counterpart.
---

# Skill: check-business-coverage

A cross-feature scan. Asks the question: "for every action the user can take, is the inverse / completion / recovery action also reachable?" Catches the half-cycles that ship under deadline pressure.

## Premise

Find real issues. Every cycle in the matrix cites the forward action + inverse action with concrete UI paths or API endpoints. "Inverse missing" requires having searched and confirmed: no route handler, no UI button, no settings entry. Severity (CRITICAL / HIGH / MEDIUM) cites the regulatory / security / business consequence — GDPR Article, payment-vendor rule, app-store guideline, security class. Role coverage findings cite the role + the actual response code observed.

## Halt conditions

- Refuse to mark "inverse missing" without grepping routes + UI for the action.
- Refuse to label "CRITICAL" without naming the regulation / policy that demands it.
- Halt if `ai/business-flows.md` is absent — recovery is to fill it first, not guess.
- Don't propose 10 fixes; rank by impact + cite effort estimate.
- Don't audit only the happy path — unhappy paths is where the gaps live.

## When to use

- Pre-release sweep across the whole product.
- Preparing for an external audit (GDPR, App Store Privacy, accessibility).
- After a feature freeze, before a major launch.
- Quarterly business-completeness audit.

## Procedure

### 1. List every CRUD-like cycle in the product

From `ai/business-flows.md` + the codebase:
- Account: signup, edit profile, delete account.
- Subscription: subscribe, change tier, unsubscribe, restore.
- Payments: pay, refund, dispute, history.
- Notifications: enable per channel, disable per channel, frequency settings.
- Data: export, import, delete, share, revoke share.
- Authorization: invite member, change role, remove member.
- Content: create, edit, archive, restore, hard-delete.

### 2. For each cycle, verify each direction exists

| Forward action | Inverse action | Both reachable? |
|---|---|---|
| Sign up | Delete account | <yes/no/partial> |
| Subscribe | Unsubscribe | <yes/no/partial> |
| Send invite | Revoke invite | <yes/no/partial> |
| Enable 2FA | Disable 2FA | <yes/no/partial> |
| Connect integration (Slack/etc.) | Disconnect | <yes/no/partial> |
| Grant role | Remove role | <yes/no/partial> |
| Export data | (verify completes; no inverse needed) | n/a |
| Submit form | Edit before final commit / cancel | <yes/no/partial> |

"Partial" = exists but requires support ticket / hidden / requires admin / takes >5 minutes to find.

### 3. Verify recovery from every error

| Error path | Recovery offered? |
|---|---|
| Card declined | Try another card / contact bank |
| Email not received | Resend / change email |
| Password reset link expired | Request new |
| 2FA code lost | Recovery code path / contact support |
| Imported file invalid | Show errors per row / partial import option |
| Network timeout during save | Retry / save draft |
| Permission denied | Explain why / path to fix |
| Rate limited | Show wait time / upgrade option |

### 4. Verify role coverage

For each major action, verify behavior per role:
- Admin: should succeed.
- Member: should succeed within scope.
- Viewer / read-only: should be denied gracefully.
- Tenant from a different tenant: should not see / not act.
- Anonymous: should be redirected to auth.

Test the failure modes — what does a viewer see when they try the admin-only action? "404" vs "Permission denied with explanation" vs "Button disabled with tooltip."

### 5. Verify metric coverage

Each business-critical action should emit an analytics event:
- Forward: signup.completed, subscription.started, invite.sent.
- Inverse: account.deleted, subscription.cancelled, invite.revoked.
- Errors: payment.declined, invite.bounced, signup.email_invalid.

Without inverse + error events, dashboards over-count successes.

## Output format

```
## Business coverage audit — <project> — <date>

### Forward / inverse matrix (50 cycles audited)

| # | Cycle | Forward | Inverse | Severity |
|---|---|---|---|---|
| 1 | Sign up / Delete account | ✓ | ✓ | OK |
| 2 | Subscribe / Unsubscribe | ✓ | ✗ requires support ticket | **CRITICAL** |
| 3 | Connect Slack / Disconnect | ✓ | partial — disconnects but webhook stays active | HIGH |
| 4 | Send invite / Revoke invite | ✓ | ✗ — no UI | HIGH |
| ... | | | | |

### Error recovery matrix

| Error | Recovery? |
|---|---|
| Card declined | ✓ "Try another card" |
| Email not received | ✗ no resend button |
| 2FA lost | partial — only via support |

### Role-coverage matrix

For action "Delete project" — tested per role:
| Role | Behavior | Verdict |
|---|---|---|
| Owner | Confirms + deletes | ✓ |
| Admin | Confirms + deletes | ✓ — but should it require Owner? |
| Member | Button hidden | ✓ |
| Viewer | Button visible but 403 on click | ✗ — should be hidden |
| Cross-tenant | 404 | ✓ |

### Metric coverage

Events firing:
- ✓ signup.completed
- ✓ subscription.started
- ✗ subscription.cancelled — MISSING
- ✗ invite.bounced — MISSING
- ...

### Highest-impact gaps

1. **Unsubscribe flow** — GDPR-relevant; no in-app path. Risk: app-store rejection / regulator complaint. Effort: 1-2 days.
2. **Invite revocation** — security gap; revoked invitee retains access. Risk: data leak. Effort: 1 day.
3. **subscription.cancelled event missing** — funnel dashboards over-count active subs. Effort: 1 hour.

### Recommendation

Fix #1 and #2 before next release. #3 is a 1-hour patch — ship now.
```

## Inputs

- Path to `ai/business-flows.md` (or "scan codebase" if missing).
- Roles list (read from `ai/users-and-personas.md` or ask).

## Outputs

- `ai/audits/business-coverage-<date>.md`.

## Failure modes

- Audited only the happy path UI; missed inverse paths buried in settings.
- Verified API exists for inverse but not the UI to invoke it.
- Tested as one role; missed role-divergent behavior.
- Missed transitive dependencies (e.g., delete account but webhook still posts events to a 3rd party).

## Related

- `business-completeness.md` rule — what "done" looks like.
- `@business-auditor` — feature-level audit; this skill is product-level.
- `audit-funnel-completion.md` — single-flow conversion audit; this skill is cross-flow.
