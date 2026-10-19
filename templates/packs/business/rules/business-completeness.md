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
- **Every entity lifecycle is a guarded state graph** — every state reachable, ≥1 terminal state, every transition checking its current state before it writes, illegal edges impossible. *Status column present → `lifecycle-scan`, judged by `@workflow-integrity`.*
- **Every empty state is opinionated.** "No orders yet — start by adding products to your catalog [CTA]" beats a blank screen.
- **Every aggregate invariant names the layer that enforces it** — a DB `CHECK`/`UNIQUE`, a model guard or a service assertion; never caller discipline. An invariant enforced nowhere on money / inventory / balance is a BLOCKER. *ORM models present → `@domain-model-auditor` builds the enforcement register.*
- **Money is an integer minor-unit or a decimal type — never a float**, and every amount carries its currency. This pack owns the money RULE (`pricing-rule-scan`, `tax-invoice-scan`, `ledger-scan`, `report-scan`); the arithmetic, the column type, the wire value and a race on a balance belong to code-quality, database, backend and security when installed (`governance/ownership.json`).

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
- [ ] (Money, tax, ledger, report surface) the matching detectors run, each coverage block cited — a bare "clean" is not a result.
- [ ] (Status column) `lifecycle-scan` graph cited (`status-graph.py` exit 0), no trap or unguarded illegal edge on a money entity open.
- [ ] (User-facing forward actions) `check-business-coverage` pairs cited: every forward action has its inverse, resend, status and exit, or a documented exemption.
- [ ] Funnel events fire at each step (analytics).
- [ ] Audit log captures sensitive operations (role change, data export, account delete).
- [ ] Permissions denied path is documented per role.

## Enforcement

- `/audit-business` — the whole repo (six detectors, class ledger, every row refuted, a verdict) or one feature (the three judges plus the detector rows on its files).
- `/business-fix` — closes findings failing first; stops for the business decisions (rounding, tax point, business zone, metric, retention).
- Half-cycles that shipped, and what they cost, are catalogued in `ai-patterns/missing-counterparts.md § What half-cycles actually cost` — read it before arguing an exemption.

## Cross-references

- `ai/business-flows.md` — the declared flows this rule audits against.
- The three judges are orthogonal: `@business-auditor` cycles and the walk, `@workflow-integrity` the graph, `@domain-model-auditor` money and invariants. Detectors find; judges refute.
- `code-quality/rules/quality-principles.md` — the code-level counterpart to this business-level rule.
