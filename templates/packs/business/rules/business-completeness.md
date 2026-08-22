---
name: business-completeness
description: Foundational business rule — "done" is the completed cycle, not the compiling code.
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
- **Every entity lifecycle is a guarded state graph** — every state reachable, ≥1 terminal state, every transition checking its current-state precondition before it writes (never a blind overwrite), illegal edges impossible rather than uncommon. *Status / state / phase column present → run `@workflow-integrity`*, which reconstructs the graph and proves each edge.
- **Every empty state is opinionated.** "No orders yet — start by adding products to your catalog [CTA]" beats a blank screen.
- **Every aggregate invariant names the layer that enforces it** — a DB `CHECK`/`UNIQUE`, a model guard / value-object constructor, or a service assertion; never caller discipline. An invariant recited in docs and enforced by no code (`enforced-where: NOWHERE`) on money / inventory / balance is a BLOCKER, not a nit. *ORM models / migrations present → run `@domain-model-auditor`*, which builds the enforcement register and grades each row.
- **Money is an integer minor-unit or a decimal type — never a float**, and every amount carries its currency. *Billing / checkout / tax surface present → run `pricing-tax-audit`*, which owns the money-MATH (rounding step + mode, jurisdiction, tax base, mixed-currency, idempotent charges, proration).

## Must not

- Ship a feature without testing the unhappy path. Card declined / network failure / permission denied / rate limit hit / partial success.
- Ship a "Save" action without a "Cancel" / undo path for irreversible operations.
- Ship a Subscribe flow without an Unsubscribe path that's findable in ≤2 taps.
- Ship a Create flow without verifying the Read flow actually shows what was created.
- Bury exit / cancel paths under destructive language ("Are you sure you want to LOSE all your data?").
- Use the same toast for "saved" and "save failed" — distinguish visually + with text.

## Should

- Track time-to-completion per actor. If admin approval bottlenecks the flow, the metric reveals it.
- Use plain-language error messages: "Card declined by your bank — try another card" beats a vendor-specific error-code dump.
- A/B test copy on action buttons where conversion is already instrumented — measure the lift on this product; do not import a lift figure from elsewhere.

## Review checklist

When reviewing a feature for completeness:

- [ ] Every Create has Update + Read + Delete (or documented exemption).
- [ ] Every async operation has visible status during in-flight.
- [ ] Every error has a user-facing recovery path.
- [ ] Every empty state has an action / explanation.
- [ ] Every cross-actor flow has a defined endpoint.
- [ ] Lifecycle graph reachable + terminal + every transition guarded — `@workflow-integrity` run, verdict cited.
- [ ] Every invariant names its enforcement layer, none NOWHERE on money / inventory / balance — `@domain-model-auditor` run, register cited.
- [ ] (Money surface) `pricing-tax-audit` run, verdict cited — `UNVERIFIED (N unproven)` is a legitimate verdict; a bare `clean` with no property register is not.
- [ ] Funnel events fire at each step (analytics).
- [ ] Audit log captures sensitive operations (role change, data export, account delete).
- [ ] Permissions denied path is documented per role.

## Enforcement

- `/audit-business <feature>` — one feature, deep: dispatches `@business-auditor` (experience), `@workflow-integrity` (state graph) and `@domain-model-auditor` (invariants). Its verdict must carry each agent's, or say which was not run.
- `check-business-coverage` (skill) — the whole product's cycles in one sweep, written to `ai/audits/business-coverage-<date>.md`.
- Half-cycles that shipped, and what they cost, are catalogued in `ai-patterns/missing-counterparts.md § What half-cycles actually cost` — read it before arguing an exemption.

## Cross-references

- `ai/business-flows.md` — the declared flows this rule audits against.
- The three auditors are orthogonal, not redundant: `@business-auditor` = experience, `@workflow-integrity` = state graph, `@domain-model-auditor` = aggregate invariants, `pricing-tax-audit` = money math. Each artifact states its own boundary; none substitutes for another.
- `code-quality/rules/quality-principles.md` — the code-level counterpart to this business-level rule.
