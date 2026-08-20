---
name: finops-principles
description: FinOps Principles
kind: rule
pack: finops
severity: must
applies-to: finops-track, every-code-writing-task-in-finops
---

# FinOps Principles

> **Hard rule.** Every design states its cost at target scale and at 10× target, sourced to a dated unit price. Every persistent store ships with a retention policy. Every resource carries the allocation tags its policy requires. Every cost claim is labelled measured, allocated with a named basis, or NOT DERIVABLE — never estimated silently. Every guardrail has a derived threshold, a named recipient, and a named action.

Prevents the two failures that make cost work useless: decisions made without arithmetic, and arithmetic made up to fill a gap. The second is worse, because a fabricated number gets quoted in a planning meeting and outlives everyone who knew it was a guess.

## Must

- **Name the billed dimension** for every component before comparing options. Services bill on requests, bytes stored, bytes moved, capacity-hours, per-object operations, or tokens; a design efficient on the wrong axis is expensive.
- **Cite a dated unit price** (SKU or tier, as-of date) for every cost figure. Prices change; an undated projection cannot be re-checked.
- **Cite the usage assumption** behind every projection — a measured metric, a stated target, or an explicit guess. No silent guesses.
- **Label every cost figure** `measured`, `ALLOCATED (basis: <named proxy>)`, or `NOT DERIVABLE — <instrumentation that would provide it>`. These three are the only permitted labels.
- **Report cost at target scale and at 10× target.** Designs are within noise at today's volume and separate by an order of magnitude later.
- **State the idle floor** — what a shape costs at zero traffic — and the **egress path** — which calls cross a zone, a region, or the internet.
- **Set a retention or lifecycle policy on every persistent store, in the same change that creates it.** No policy means forever, and the eventual cleanup is a migration rather than a setting.
- **Give every resource the allocation tags its policy requires**, enforced at creation through the shared module rather than detected afterwards.
- **Bound every retry and every fan-out** against a billed dependency. Retries multiply billed calls precisely when the dependency is already failing.
- **Declare an expected cost per unit and a deviation threshold** before installing any detector. A detector with no declared baseline can never fire correctly.
- **Derive every threshold** from trailing history computed when it was set, or from the declared expectation. Record the derivation inline.
- **Give every guardrail a named recipient and a named action.** An alert whose action is "be aware" is noise.
- **Amortise commitments and apply discounts** in every report. Report the cost the organisation bears.

## Must not

- Present an estimate as a measurement, or interpolate a plausible figure to fill a gap. `UNKNOWN — <what would settle it>` is the correct output.
- Report a saving against list price.
- Compare architectures on a dimension that is not the dominant one for the actual access pattern.
- Create a persistent store, a log stream, a topic, a backup schedule, or a preview environment with no expiry.
- Add a per-row remote call, a paid API call inside a loop, or an N+1 against a billed dependency.
- Raise a log level or add a high-cardinality metric label on a hot path without stating the ingestion volume it adds.
- Introduce a cross-zone or cross-region hop without stating the transfer volume and its price.
- Configure a budget, a detector, or a quota in a console rather than as code in the repository. Console configuration is invisible to review and disappears with the next account restructure.
- Set a budget from last year's spend plus a margin, with no unit expectation behind it. It will be raised rather than investigated.
- Suppress a detector without an expiry date. A permanent suppression is a deleted guardrail.
- Divide shared cost by an undeclared basis. That is unallocated spend with a story attached.
- Rank cost findings purely by absolute dollars — a small recurring leak on a hot path outranks a one-off larger charge.
- Recommend on cost alone. Name what is being traded away.

## Should

- Express cost as a **driver tree** from a business unit down to billed dimensions. The tree tells you which branch to attack; the total tells you nothing.
- Pair every unit cost with revenue per unit, so contribution margin exists and the number can be judged.
- Report unallocated spend as a headline percentage — it is the error bar on every per-unit figure derived from the same bill.
- Prefer a hard bound (quota, policy, time-to-live) in non-production over an alert. A notification-only guardrail is a smoke alarm with no fire door.
- Detect anomalies **per dimension and on rate of change**, not only on the total and the level. A slow creep never breaches a level threshold and is the most common way spend doubles.
- Treat commitment expiries as scheduled decisions with owners, not as renewals. The default outcome of an expiry is a bill increase.
- Reuse the observability pack's alert routing and runbook conventions for cost alerts rather than creating a second paging path.
- Track the `NOT DERIVABLE` list as an instrumentation backlog; each item converts an assumption into a measurement.

## Review checklist

- [ ] Every new priced resource has a stated monthly floor and an owner.
- [ ] Every new persistent store has a retention or lifecycle policy in the same change.
- [ ] Every new resource carries the required allocation tags.
- [ ] Retries and fan-outs against billed dependencies are bounded.
- [ ] No paid call moved inside a per-row loop.
- [ ] New cross-zone or cross-region hops are stated with volume and price.
- [ ] Log-level and metric-cardinality changes state their ingestion delta.
- [ ] The projected cost per unit after this change is within the declared threshold.
- [ ] Every figure in the change's cost note is labelled measured / allocated / not derivable.

## Enforcement

- A pre-merge infrastructure cost estimate runs in CI and posts the delta on the pull request, so the author sees the number before the resource exists.
- Required allocation tags are enforced by the shared infrastructure module's variable contract — an untagged resource cannot be created, rather than being reported later.
- Quotas and policy controls hard-bound non-production accounts; production uses alerts with named owners.
- Anomaly detectors run per dimension against seasonal baselines and route through the existing alerting path.
- Every guardrail is proved to fire — live or by replay against a historical spike — before it counts as coverage. This proof is enforced by the `/cost-guardrails` closure gate, which is agent-side; no external validator checks it.
