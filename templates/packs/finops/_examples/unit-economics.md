---
name: unit-economics
kind: example
pack: finops
---

# Pattern: Unit Economics

> **Hard rule:** Cost is a driver tree from a business unit down to billed dimensions, never a single total. Every branch is labelled `measured`, `ALLOCATED (basis: <proxy>)`, or `NOT DERIVABLE — <instrumentation>`. The tree reconciles to the bill. Unallocated spend is the error bar.

**Halt conditions / mandatory cites**
- Target scale or the unit's denominator undeclared — every figure is scale × price.
- Shared-cost allocation basis undeclared — it changes every per-unit number materially and is a business decision.
- Cost/usage export unavailable at row level — console summaries cannot be filtered to a branch.
- Any figure presented without one of the three labels is a hand-wave — reject it.

## The tree

```
cost per <unit>
├── <branch> = <usage per unit> × <unit price>   [measured]
├── shared   = <pool> × <declared basis>          [ALLOCATED (basis: request share)]
└── <branch> = —                                  [NOT DERIVABLE — needs per-tenant token metric]
```

The branch shares say which branch is 40% of the cost and which is 0.5% — that is how review and optimisation effort get aimed. A single total tells nobody what to do.

Each branch names its billed dimension: requests, vCPU-seconds, GB-months, GB transferred, per-object operations, capacity-hours, tokens.

## The denominator is half the model

"Per user" is at least three denominators — registered, monthly active, paying. Pin it as a sentence *and* a query: what is counted, from where, over which period, with which filters. Cross-check against a second source; a material disagreement is itself the finding.

Denominator drift is the quiet killer: the count definition changes, the unit cost moves, nothing real happened.

## The three labels and the error bar

There is no fourth label. An unlabelled number is an estimate wearing a measurement's clothes.

The unallocated share of spend bounds the model: `$0.043` from a bill that is 30% unallocated should be read as a range. Run the attribution audit first.

## Reconciliation and margin

Attributed branches + unallocated = total spend, every time. A tree that does not reconcile is absorbing an error silently.

Pair cost per unit with revenue per unit. `$12` per tenant is a pricing emergency on a `$9` plan and noise on a `$400` one. Segment it — an average hides the tenants a fair-use policy exists for.

## Change decomposition

Split every move three ways before explaining it: **rate** (same usage, different price), **usage** (more of the same), **mix** (same usage, differently-priced resource). Different owners.

## Detectors

- A cost-per-unit figure quoted with no denominator definition.
- Branches that sum to less than the bill, unmentioned.
- A branch carrying an unlabelled number.
- A unit cost that moved with no usage change — check tagging first.
- A model with no revenue side.
- An average per-tenant cost with no segmentation on a long-tailed system.

## Related

- `ai/patterns/spend-allocation.md`, `ai/patterns/commitment-strategy.md`, `ai/patterns/cost-anomaly-detection.md`
- `@cost-architect`, `@finops-analyst`, `unit-cost-probe`, `/cost-model`
