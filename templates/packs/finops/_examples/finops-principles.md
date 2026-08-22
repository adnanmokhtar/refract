---
name: finops-principles
description: FinOps Principles
kind: example
pack: finops
---

# FinOps Principles

> **Hard rule.** Every design states its cost at target scale and at 10× target, sourced to a dated unit price. Every persistent store ships with a retention policy. Every resource carries its allocation tags. Every cost figure is labelled measured, allocated with a named basis, or NOT DERIVABLE. Every guardrail has a derived threshold, a named recipient, and a named action.

## Must

- Name the billed dimension per component before comparing options.
- Cite a dated unit price and the usage assumption behind every projection.
- Label every figure `measured` / `ALLOCATED (basis: …)` / `NOT DERIVABLE — <instrumentation>`. There is no fourth label.
- Report cost at target and at 10× target; state the idle floor (with a named owner) and the egress path.
- Set a retention or lifecycle policy on every persistent store in the same change that creates it.
- Tag every resource per the allocation policy, enforced at creation in the shared module.
- Bound every retry and fan-out against a billed dependency.
- Declare an expected cost per unit and a threshold before installing any detector; a change projecting a cost/unit outside it is a blocker regardless of absolute size.
- Derive every threshold from trailing history or the declared expectation, recorded inline.
- Amortise commitments and apply discounts in every report.

## Must not

- Present an estimate as a measurement, or interpolate a plausible figure to fill a gap.
- Report a saving against list price.
- Create a store, log stream, topic, backup schedule, or preview environment with no expiry.
- Add a paid call inside a loop, or an N+1 against a billed dependency.
- Introduce a cross-zone or cross-region hop without stating volume and price.
- Configure a budget, detector, or quota in a console rather than as code.
- Set a budget from last year's spend plus a margin with no unit expectation behind it.
- Suppress a detector without an expiry date.
- Divide shared cost by an undeclared basis.
- Rank findings purely by absolute dollars, or recommend on cost alone.

## Should

- Express cost as a driver tree; pair unit cost with revenue per unit.
- Report unallocated spend as a headline percentage — it is the error bar.
- Prefer hard bounds in non-production over alerts.
- Detect per dimension and on rate of change, not only on the total and the level.
- Treat commitment expiries as scheduled decisions with owners.
- Reuse the observability pack's alert routing.

## Enforcement

- A pre-merge infrastructure cost estimate runs in CI and posts the delta on the pull request, so the author sees the number before the resource exists.
- Required allocation tags are enforced by the shared infrastructure module's variable contract — an untagged resource cannot be created, rather than being reported later.
- Every guardrail is proved to fire — live or by replay against a historical spike — before it counts as coverage. This proof is enforced by the `/cost-guardrails` closure gate, which is agent-side; no external validator checks it.
