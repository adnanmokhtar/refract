---
name: unit-cost-probe
description: Compute the measured cost of one named business unit — per request, tenant, order, job, GB, or 1k tokens — by joining attributed spend to the unit's denominator over the same whole billing period, and label every branch measured / allocated / not derivable. Run when a unit cost is claimed, before a pricing decision, to verify a cost model's branch, and to check whether a predicted change appeared. Produces the NUMBER for one unit — `commitment-coverage` explains the rate half of a change, `egress-trace` explains the transfer branch, and `spend-anomaly-triage` explains a spike.
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: unit-cost-probe

## Premise

A cost per unit is a division, and both sides of it lie easily. The numerator lies through unallocated spend and unamortised commitments; the denominator lies through ambiguity ("per user" is at least three different counts). This skill makes both sides explicit and refuses to produce a figure whose inputs it cannot name.

Every output states: the numerator's source and filters, the denominator's source and query, the period, and the label on each branch.

## Halt conditions

- **Denominator undefined.** "Per user" is not a denominator; "monthly active users, as counted by `<named metric>`, over the same billing period" is. Refuse until it is named.
- **Period mismatch** between numerator and denominator. A cost from a calendar month divided by a count from a trailing-30-day window is not a unit cost.
- **Cost/usage export unavailable at row level.** Console summaries cannot be filtered to a branch.
- **Shared-cost basis undeclared** when the unit's branches include shared infrastructure. The choice changes the answer materially and belongs to a human.
- **Flat-rate capacity environment** — there is no marginal cost. Report share-of-a-fixed-pool instead and label it as such.

## When to run

- Someone states a cost per customer, per order, or per request, and it needs verification.
- Before a pricing, packaging, or plan-limit decision.
- To populate or verify one branch of `/cost-model`'s driver tree independently.
- After a change that `@cost-reviewer` predicted would move a unit cost — did it?
- When two teams disagree about what something costs; usually they are using different denominators.

## Procedure

### 1. Pin the denominator

Write it as a sentence and a query: what is counted, from which source, over which period, with which filters (do trials count? do internal accounts? do churned tenants who were active for part of the period?).

Cross-check against a second source if one exists. A material disagreement between the billing system's tenant count and the analytics tool's is itself the finding — stop and report it rather than picking one.

### 2. Pin the numerator

Pull the cost/usage export for whole billing periods and filter to the branch:
- Amortise committed and reserved purchases across their term.
- Apply credits and discounts. Never use list price.
- Exclude one-off charges into their own bucket.
- Filter by the allocation axis (account, tag, service, usage type) that defines this branch.

Record the filters and the row count. A number that cannot be recomputed from the stated filters is not reportable.

### 3. Divide per branch, not just in total

```
cost per <unit>, branch <b> = attributed cost for branch b / count of <unit> in the same period
```

Label each branch:
- **measured** — cost and usage both attributable at this granularity.
- **ALLOCATED (basis: <named proxy>)** — divided by a stated proxy. A legitimate assumption, labelled as one.
- **NOT DERIVABLE — <instrumentation that would provide it>** — do not fill it in.

### 4. Compute the error bar

The unallocated share of spend is the model's error bar. State it. A cost per unit of "$0.043" derived from a bill that is 30% unallocated should be read as "somewhere between $0.043 and $0.061", and saying so is the difference between a useful number and a misleading one.

### 5. Trend it

One period is a data point. Report at least three consecutive periods so the direction is visible, and split any change into rate, usage, and mix — the three have completely different owners.

### 6. Report

```
## unit-cost-probe — <unit> — <periods>

Denominator: <sentence>
  source: <metric/query>   cross-check: <second source | none>   agreement: <%|n/a>
Numerator:   cost/usage export, amortised, discounts applied, one-offs excluded
  filters: <list>   rows: <N>
Unallocated share (error bar): <%>

| Branch | Cost this period | Cost/unit | Prior | Δ | Δ class | Basis |
|--------|------------------|-----------|-------|---|---------|-------|

Total cost/unit: <$>  (measured <%> · allocated <%> · not derivable <%>)
Read as: <$low>–<$high> given the error bar
Trend over <n> periods: <direction, with the per-period figures>
Not derivable (N): <each with the instrumentation that would provide it>
```

## Inputs

- Cost and usage export at row level for whole billing periods.
- The unit's denominator metric or query.
- The allocation policy and the shared-cost basis.
- `ai/finops/unit-economics.md` for the branch definitions, when verifying an existing model.

## Outputs

- The report block above, pasted into the consuming command's ledger.
- The `NOT DERIVABLE` list, which is an instrumentation backlog rather than a failure.
- Where a branch moved: a handoff to `spend-anomaly-triage` (usage/mix) or `commitment-coverage` (rate).

## False positives / gotchas

- **Denominator drift.** The count definition changes (a new "active" rule ships) and the unit cost moves with nothing real changing. Pin the query, not the concept.
- **Unamortised commitments.** A month with a large upfront purchase shows a spike that is an accounting artefact. Amortise, always.
- **Partial billing periods.** Providers finalise late; a period pulled too early undercounts. Wait for finalisation or say the period is provisional.
- **28 versus 31 days.** Normalise per-day before comparing months, or a February that looks efficient is just short.
- **New-tenant dilution.** A cohort of tenants onboarded mid-period consumes little and counts fully in the denominator, flattering the unit cost. Cohort the denominator if this is material.
- **Comparing against list price** to manufacture a saving.
- **A branch that is "measured" only because the tag exists.** If the tag is wrong, the measurement is wrong. `/audit-cost-attribution` bounds how much to trust it.
- **Presenting a point estimate with no error bar** when a third of the bill is unallocated.

## Related

### Skills
- `commitment-coverage` — the rate half of any change this probe surfaces.
- `egress-trace` — the transfer branch, which is usually the one labelled NOT DERIVABLE first.
- `spend-anomaly-triage` — takes over when a branch moves unexpectedly.

### Agents
- `@finops-analyst` — runs this at scale across every unit.
- `@cost-architect` — compares the measured result against the design-time projection.

### Commands
- `/cost-model` — this skill verifies one branch of its tree independently.
- `/audit-cost-attribution` — supplies the error bar.

### Patterns
- `ai/patterns/unit-economics.md`, `ai/patterns/spend-allocation.md`
