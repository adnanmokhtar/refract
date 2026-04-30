---
name: business-completeness
description: Foundational rule for the business pack — a feature is "shipped" when code compiles; it's "done" when the user can complete the cycle end-to-end with recovery from every error path.
kind: rule
pack: business
applies-to: every-feature, every-PR-touching-user-facing-code
severity: must
---

# Business Completeness

> **Hard rule.** A user-facing feature is "done" only when the user can complete the cycle end-to-end AND recover from every error path. Every Create MUST have a matching Read + Update + Delete (or documented exemption); every Send MUST have a Resend; every async operation MUST surface a status; every error path MUST offer a recovery action.

## Must

- **Every Create has a Delete + Update + Read.** If users can sign up, they can delete their account; if users can subscribe, they can unsubscribe. Half-cycles are GDPR / consumer-protection / dark-pattern territory.
- **Every Send has a Resend.** Email / SMS / push / webhook sent and not received → user must have a way to retry without re-entering data.
- **Every async operation has a status surface.** "Processing" / "Sent" / "Failed" / "Cancelled". Silent in-flight = the user re-submits 5 times = duplicate orders.
- **Every error path has a recovery.** "Something went wrong — try again" with a retry button beats a dead-end. "Card declined — try a different card" beats a generic error.
- **Every business metric is wired.** Funnel events at every step. Drop-off detection requires tracking, not "we'll add it later."
- **Every cross-actor flow ends.** Admin approves → user receives notification → user takes action → status updates → other actors notified. Don't leave the chain dangling at any link.
- **Every empty state is opinionated.** "No orders yet — start by adding products to your catalog [CTA]" beats a blank screen.

## Must not

- Ship a feature without testing the unhappy path. Card declined / network failure / permission denied / rate limit hit / partial success.
- Ship a "Save" action without a "Cancel" / undo path for irreversible operations.
- Ship a Subscribe flow without an Unsubscribe path that's findable in ≤2 taps.
- Ship a Create flow without verifying the Read flow actually shows what was created.
- Bury exit / cancel paths under destructive language ("Are you sure you want to LOSE all your data?").
- Use the same toast for "saved" and "save failed" — distinguish visually + with text.

## Should

- Track time-to-completion per actor. If admin approval bottlenecks the flow, the metric reveals it.
- A/B test copy on action buttons when conversion is measured — wording shifts conversion 5–15%.
- Group related actions ("Subscription") in one settings area; never scatter across 3 menus.
- Use plain-language error messages: "Card declined by your bank — try another card" beats "Stripe error code 4002."

## Review checklist

When reviewing a feature for completeness:

- [ ] Every Create has Update + Read + Delete (or documented exemption).
- [ ] Every async operation has visible status during in-flight.
- [ ] Every error has a user-facing recovery path.
- [ ] Every empty state has an action / explanation.
- [ ] Every cross-actor flow has a defined endpoint.
- [ ] Funnel events fire at each step (analytics).
- [ ] Audit log captures sensitive operations (role change, data export, account delete).
- [ ] Permissions denied path is documented per role.

## Failure-history examples

The catalog (in `ai/_baseline/failures/`) of completeness gaps that shipped:

- **Subscribe flow without unsubscribe** — ratchet-only signup, GDPR-rejected by EU users, removed from app stores.
- **Order placed but no email confirmation** — high support ticket volume; funnel conversion looked fine on dashboards but customer trust eroded.
- **Admin approval queue with no notification on completion** — admins forgot, requesters waited hours.
- **Password reset email sent but link expired immediately** — users locked out; support escalation.
- **CSV export "running" indefinitely** — users cancelled, retried, duplicated background jobs.
- **Search results page on empty query → blank screen** — users assumed broken; bounced.

## Enforcement

- `@business-auditor` agent runs the review checklist against every PR touching a flow declared in `ai/business-flows.md` — gaps block merge.
- `/business-flow-audit` command (see pack `commands/`) sweeps the whole repo on demand and writes findings to `ai/business-completeness.md`.
- TODO: validator at `scripts/audit-business-flows.sh` — static scan that every Create-shaped route has a paired Delete + Update + Read route + i18n keys for empty / error / success states.

## Cross-references

- `ai/business-flows.md` — declared flows that this rule audits against.
- `@business-auditor` — agent that runs this rule across a feature.
- `code-quality/rules/quality-principles.md` — code-level quality rule; this is the business-level counterpart.

## Related

(Cross-references in the rule body above.)
