---
name: check-business-coverage
description: Cross-feature audit — walks the project's declared business cycles (Create→Update→Delete, Subscribe→Unsubscribe, Send→Resend) and surfaces every missing counterpart. Use for a pre-release sweep across the whole product, before an external audit (GDPR, App Store Privacy), or as a quarterly completeness review. Product-level — `audit-funnel-completion` covers conversion within a single flow.
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: check-business-coverage

A cross-feature scan. Asks the question: "for every action the user can take, is the inverse / completion / recovery action also reachable?" Catches the half-cycles that ship under deadline pressure.

## Premise

Find real issues. Every cycle in the matrix cites the forward action + inverse action with concrete UI paths or API endpoints. "Inverse missing" requires having searched and confirmed: no route handler, no UI button, no settings entry. Severity (CRITICAL / HIGH / MEDIUM) cites the regulatory / security / business consequence — GDPR Article, payment-vendor rule, app-store guideline, security class. Role coverage findings cite the role + the actual response code observed.

## Halt conditions

- Refuse to mark "inverse missing" without grepping routes + UI for the action.
- **Refuse a bare checkmark.** Every `✓` in every matrix carries the path that makes it true — a route, a screen + the click path, or an endpoint. A `✓` that costs nothing to write is a claim the reader cannot check and the next audit cannot compare against; it is the exact defect this skill's own Premise forbids.
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

Each direction is recorded with the **path that proves it**, never a bare mark:

| Forward action (+ path) | Inverse action | Evidence |
|---|---|---|
| Sign up @ `<route>` | Delete account | `<route or screen → click path>` \| MISSING (searched: routes, settings UI, account page) \| PARTIAL (<why>) \| NOT WALKED (<no role / no env>) |
| Subscribe @ `<route>` | Unsubscribe | … |
| Send invite @ `<route>` | Revoke invite | … |
| Enable 2FA @ `<route>` | Disable 2FA | … |
| Connect integration @ `<route>` | Disconnect | … |
| Grant role @ `<route>` | Remove role | … |
| Export data @ `<route>` | (completion, not inverse — verify it completes) | … |
| Submit form @ `<route>` | Edit / cancel before commit | … |

- **PARTIAL** = exists but requires a support ticket / is hidden / is admin-only / takes > 3 clicks to find. State which.
- **MISSING** requires the search to be stated — which routes, which UI surfaces, which settings pages you looked at. "I didn't find it" is not the same claim as "it isn't there".
- **NOT WALKED** rows stay in the denominator. An audit that reached 12 of 50 cycles and reports on 12 is reporting on 12 — say so.

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

Coverage: 50 cycles declared · 46 walked · 4 NOT WALKED (no billing credential in this env)

| # | Cycle | Forward (path) | Inverse (path) | Severity |
|---|---|---|---|---|
| 1 | Sign up / Delete account | `POST /signup` | Settings → Account → Delete → confirm | OK |
| 2 | Subscribe / Unsubscribe | `POST /subscriptions` | MISSING — searched `routes/*`, Settings, Billing page; support ticket only | **CRITICAL** (GDPR Art. 7(3) — "It shall be as easy to withdraw as to give consent", gdpr-info.eu/art-7-gdpr) |
| 3 | Connect chat integration / Disconnect | Integrations → Connect | PARTIAL — `DELETE /integrations/:id` unlinks the row but the outbound webhook stays registered | HIGH |
| 4 | Send invite / Revoke invite | `POST /invites` | MISSING — endpoint exists (`DELETE /invites/:id`), no UI entry point on any screen walked | HIGH |
| 5 | Add payment method / Remove | `POST /billing/cards` | NOT WALKED — no billing credential in this env | — |

### Error recovery matrix

| Error | Recovery (path) |
|---|---|
| Card declined | "Try another card" CTA on the payment step |
| Email not received | MISSING — no resend control on the verify screen or in Settings |
| 2FA lost | PARTIAL — recovery codes not offered at enrolment; support only |

### Role-coverage matrix

For action "Delete project" — tested per role:
| Role | Behavior observed | Response | Verdict |
|---|---|---|---|
| Owner | Confirm dialog, deletes | 204 | OK |
| Admin | Confirm dialog, deletes | 204 | OK — but should this require Owner? Raise with product |
| Member | Button hidden | n/a | OK |
| Viewer | Button visible, fails on click | 403 | GAP — hide the control; a 403 the UI invited is a broken affordance |
| Cross-tenant | Not found | 404 | OK (404 not 403 — correct, does not confirm existence) |

### Metric coverage (each event cited at its emit site, or MISSING)

- `signup.completed` — emitted @ `<path:line>`
- `subscription.started` — emitted @ `<path:line>`
- `subscription.cancelled` — **MISSING** (no emit site; dashboards therefore over-count active subs)
- `invite.bounced` — **MISSING** (bounce webhook handled but not instrumented)

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
- **Bare checkmarks in the matrix** — `✓` with no path is indistinguishable from a guess, and the next quarterly run cannot tell whether the inverse moved. Every mark carries its route or click path.

## Related

- `business-completeness.md` rule — what "done" looks like.
- `@business-auditor` — feature-level audit; this skill is product-level.
- `audit-funnel-completion.md` — single-flow conversion audit; this skill is cross-flow.
