---
name: unit-economics
description: 'Pattern: Unit Economics (driver tree, labelled branches, contribution margin, the error bar)'
kind: ai-pattern
pack: finops
---

# Pattern: Unit Economics

> **Hard rule:** Cost is expressed as a driver tree from a business unit down to billed dimensions, never as a single total. Every branch is labelled `measured`, `ALLOCATED (basis: <named proxy>)`, or `NOT DERIVABLE — <instrumentation>`. The tree reconciles to the bill. The unallocated share of spend is the model's error bar and is reported with every figure derived from it.

**When to apply**
- Nobody can answer what a customer, an order, or a request costs to serve.
- Before a pricing, packaging, or plan-limit decision.
- Before setting a budget or an anomaly threshold — both need a declared baseline.
- When two teams disagree about what something costs; they are usually using different denominators.

**When NOT to apply**
- Pre-revenue systems with a bill small enough that the modelling effort exceeds the spend.
- Flat-rate capacity environments where marginal cost is zero — model share-of-a-fixed-pool instead and say so.

**Halt conditions / mandatory cites**
- Target scale or the unit's denominator undeclared — every figure is scale × price.
- Shared-cost allocation basis undeclared — it changes every per-unit number materially and is a business decision.
- Cost/usage export unavailable at row level — console summaries cannot be filtered to a branch.
- Any figure presented without one of the three labels is a hand-wave — reject it.

## The driver tree

```
cost per <unit>
├── <branch>  = <usage per unit> × <unit price of billed dimension>   [measured]
├── <branch>  = ...                                                    [measured]
├── shared    = <shared pool> × <declared allocation basis>            [ALLOCATED (basis: request share)]
└── <branch>  = —                                                      [NOT DERIVABLE — needs per-tenant token metric]
```

The tree is the deliverable. A single "cost per customer" number tells nobody what to do; the branch shares say which branch is 40% of the cost and which is 0.5%, which is how review effort and optimisation effort get aimed.

Each branch names its **billed dimension** explicitly — requests, vCPU-seconds, GB-months, GB transferred, per-object operations, capacity-hours, tokens. A branch whose dimension is unnamed will be measured on the wrong axis, and the resulting comparison will rank options backwards.

## The denominator is half the model

"Per user" is at least three denominators: registered, monthly active, paying. Each produces a different number and each supports a different decision. Pin it as a sentence *and* a query: what is counted, from which source, over which period, with which filters (trials? internal accounts? tenants active for part of the period?).

Cross-check against a second source where one exists. A material disagreement between the billing system's count and the analytics tool's is itself a finding — report it rather than silently picking one.

**Denominator drift** is the quiet killer: the count definition changes, the unit cost moves, and nothing real happened.

## The three labels

| Label | Meaning | Legitimate? |
|---|---|---|
| `measured` | cost and usage both attributable at this granularity from the export | yes |
| `ALLOCATED (basis: <proxy>)` | divided by a named proxy — request share, seat count, storage share | yes, as a labelled assumption |
| `NOT DERIVABLE — <instrumentation>` | the telemetry does not exist | yes — and it is the instrumentation backlog |

There is no fourth label. An unlabelled number is an estimate wearing a measurement's clothes, and the error is invisible because the figure looks precise.

## The error bar

The unallocated share of spend bounds the model. A cost per unit of `$0.043` drawn from a bill that is 30% unallocated should be read as a range, and stating the range is the difference between a useful number and a misleading one. Run the attribution audit before the cost model, not after.

## Reconciliation

Attributed branches + unallocated = total spend for the period. A tree that does not reconcile is wrong somewhere and the error is being absorbed silently. Reconcile every time; it is arithmetic, not judgment.

## Contribution margin

A cost model with no revenue side cannot say whether a number is a problem. Pair cost per unit with revenue per unit:

```
contribution margin per unit = revenue per unit − cost per unit
```

This is what turns "our cost per tenant is $12" into a decision: on a $9 plan it is a pricing emergency; on a $400 plan it is noise. Segment it — a per-tenant average hides the handful of tenants whose usage pattern makes them unprofitable, and those are the ones a plan limit or a fair-use policy exists for.

## Change decomposition

When a unit cost moves, split the change three ways before generating explanations:
- **rate** — same usage, different price (commitment expired, discount changed, tier crossed)
- **usage** — more of the same thing
- **mix** — same usage, differently-priced resource

Each has a different owner. Rate is procurement, usage is engineering or product, mix is usually an accident.

## Detectors

- A cost-per-unit figure quoted with no denominator definition.
- A model whose branches sum to less than the bill, with the difference unmentioned.
- A branch carrying a number with no label.
- A per-unit cost that moved with no usage change — check tagging coverage before believing it.
- A model built once and never refreshed, comparing this year's architecture to last year's assumptions.
- A cost model with no revenue side.
- An average per-tenant cost with no segmentation on a system with a long usage tail.

## Related

- `ai/patterns/spend-allocation.md` — where the error bar comes from.
- `ai/patterns/commitment-strategy.md` — the rate half of every change.
- `ai/patterns/cost-anomaly-detection.md` — the declared expectation this model produces.
- `@cost-architect`, `@finops-analyst` — the design-time and measurement-time owners.
- `unit-cost-probe` — the executor.
- `/cost-model` — the command that builds and refreshes the tree.
