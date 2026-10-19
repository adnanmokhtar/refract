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

Prevents decisions made without arithmetic, and arithmetic made up to fill a gap — the worse one, because a fabricated number outlives everyone who knew it was a guess.

## Must

- **Name the billed dimension** (requests, bytes stored, bytes moved, capacity-hours, operations, tokens) before comparing options.
- **Cite a dated unit price** (SKU or tier, as-of date) and **the usage assumption** (measured, stated target, or explicit guess) for every cost figure.
- **Label every figure** `measured`, `ALLOCATED (basis: <named proxy>)` or `NOT DERIVABLE — <instrumentation that would provide it>` — the only permitted labels.
- **Report cost at target and at 10× target**, the **idle floor** with an owner, and the **egress path** (zone, region, internet).
- **Ship a retention or lifecycle policy with every persistent store**, in the change that creates it.
- **Tag every resource** as its allocation policy requires, at creation, through the shared module.
- **Bound every retry and fan-out** against a billed dependency.
- **Declare an expected cost per unit and a deviation threshold** before installing a detector; a change projecting outside it is a review blocker whatever its size. Derive every threshold from trailing history or that expectation, inline.
- **Give every guardrail a named recipient and a named action.**
- **Amortise commitments and apply discounts** in every report.

## Must not

- Present an estimate as a measurement or fill a gap with a plausible figure — `UNKNOWN — <what would settle it>`.
- Report a saving against list price, or compare architectures on a dimension that does not dominate the access pattern.
- Create a store, log stream, topic, backup schedule or preview environment with no expiry.
- Add a paid call inside a loop, a per-row remote call, or an N+1 against a billed dependency.
- Raise a log level, add a high-cardinality label, or add a cross-zone / cross-region hop without stating the volume it adds.
- Configure a budget, detector or quota in a console instead of code. Where the provider has no API for it (DigitalOcean Spend Alerts, a provider-side spend cap), the runbook records value and read-back — documentary, never counted as armed.
- Set a budget from last year plus a margin, suppress a detector without an expiry, or divide shared cost by an undeclared basis.
- Rank findings by absolute dollars alone, or recommend on cost alone — name what is traded away.

## Should

- Express cost as a **driver tree** from a business unit to billed dimensions; pair unit cost with revenue per unit; report unallocated spend as a headline percentage.
- Prefer a hard bound (quota, policy, TTL) over an alert in non-production; detect anomalies **per dimension and on rate of change**.
- Treat commitment expiries as owned decisions; reuse the observability pack's alert routing; track `NOT DERIVABLE` items as an instrumentation backlog.

## Enforcement

Detectors (V570–V589 in `proof-oracles.md` § FinOps); anything not listed is review only (`@cost-architect` for design, `@cost-reviewer` for diffs).

- Budgets, anomaly monitors, non-prod bounds, suppressions, pre-merge estimate — `guardrail-scan` §1–§7.
- Allocation tags — `allocation-scan` §1–§4. Paid dependencies and schedules — `spend-path-scan` §1–§6.
- Retention of what the app writes — `storage-growth-scan` §1–§4 (IaC lifecycle is infrastructure's). Egress — `egress-trace` §1–§5.
- Dated prices and undated money in docs — `candidate-pricing` §0–§4. Labels, reconciliation, amortisation — `bill-lane.py` (`NOT-RUN (no billing export)` without one).
- Every row passes [`refute-before-report.md`](../../../snippets/refute-before-report.md) with [`precedents/finops.md`](../../../snippets/precedents/finops.md) under `@cost-reviewer`; agent-side, not CI, unless a team adds the steps.
