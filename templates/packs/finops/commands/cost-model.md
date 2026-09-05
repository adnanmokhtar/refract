---
description: Build or refresh the unit-economics model — the driver tree from a business unit down to billed dimensions, the measured cost per unit, and the declared expectation that every guardrail and anomaly detector is measured against.
kind: command
pack: finops
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /cost-model [<unit>] [--refresh]

Establish what one unit of the business costs to serve, decomposed into the branches that produce it. Without this, cost work is a series of unrelated optimisations; with it, every change has a denominator and every guardrail has a baseline.

## When to use / NOT to use

- USE: no one can answer "what does a customer cost us to serve"; before a pricing or packaging decision; before setting budgets or anomaly thresholds; quarterly to refresh; when gross margin per unit is unknown or disputed.
- NOT: to find idle or over-provisioned resources — that is `/cost-audit` in the infrastructure pack.
- NOT: to explain a specific spike — that is `spend-anomaly-triage`.
- NOT: to check whether spend is attributable at all — run `/audit-cost-attribution` first; a unit model built on 40% unallocated spend inherits that error bar.

## Phases applied

1-3 + 4 + 5 + 6. Phase 7 is the quarterly refresh.

## The Premise (read this first, internalize, do not deviate)

**Every figure is measured, allocated with a named basis, or NOT DERIVABLE.** Those are the only three labels. An estimate presented as a measurement makes every downstream decision — pricing, budget, headcount — quietly wrong, and the error is invisible because the number looks precise.

**The tree is the deliverable; the total is a by-product.** A single "cost per customer" figure tells nobody what to do. The branch breakdown says which branch to attack and which is noise.

**Shared cost allocation is a business decision, not an analytical one.** How a shared cluster or a platform team's spend divides across units changes every per-unit number materially. Get the basis declared and record it; never pick one silently because it made the arithmetic work.

**Closure verb (default): measure-or-label.** Populate every branch from billing and usage data; where a branch cannot be measured at the unit's granularity, label it and move on rather than blocking the whole model.

**Escalation triggers (halt and ask):**
- The shared-cost allocation basis is undeclared.
- The unit's denominator is ambiguous (which count, from which source, over which period).
- Unallocated spend exceeds the threshold at which the model's error bar swamps its conclusions — report the percentage and let the user decide whether to proceed.

## Phase 1 — Understand

Confirm, in one consolidated question:
- **The unit** — per customer, per tenant, per order, per active user, per job, per GB processed, per 1k tokens. State it precisely; "per user" is three different denominators depending on whether it means registered, monthly active, or paying.
- **The denominator source** — the metric or query that counts the unit, and the period it counts over.
- **The period** — whole billing periods only.
- **The shared-cost basis** — how shared infrastructure divides. Named, not assumed.
- **The pricing model** — on-demand, committed, or flat-rate capacity. Under flat-rate, marginal cost is zero and the model measures allocation of a fixed pool instead.

## Phase 2 — Organize

Draw the driver tree before touching data. Start from the unit and decompose into branches that each map to a billed dimension:

```
cost per <unit>
├── <branch>  = <usage per unit> × <unit price of the billed dimension>
├── <branch>  = ...
└── shared    = <shared pool> × <declared allocation basis>
```

Each branch names its billed dimension explicitly — requests, vCPU-seconds, GB-months, GB transferred, per-object operations, capacity-hours, tokens. A branch whose dimension is unnamed will be measured on the wrong axis.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/patterns/unit-economics.md`, `ai/patterns/spend-allocation.md`, `ai/patterns/commitment-strategy.md`.
- `.claude/rules/finops-principles.md`.
- The cost and usage export for the chosen periods, at row-level granularity.
- The usage metrics that supply each branch's numerator and the unit's denominator.
- Any existing `ai/finops/unit-economics.md` — a refresh compares against it rather than replacing it silently.

## Phase 4 — Generate

Dispatch `@finops-analyst` to populate the tree from the export, then:

1. Fill each branch with: usage per unit, unit price with its as-of date, and the resulting cost per unit.
2. Label each branch `measured`, `ALLOCATED (basis: <named proxy>)`, or `NOT DERIVABLE — <instrumentation that would provide it>`.
3. Compute the total and the share per branch, so the top branches are obvious.
4. Compare against the prior model if one exists; classify each change as rate, usage, or mix.
5. Where the unit has revenue attached, compute contribution margin per unit — cost per unit against revenue per unit. A cost model without the revenue side cannot say whether the number is a problem.

## Phase 5 — Update

Write `ai/finops/unit-economics.md`:
- The unit, its denominator and source, the period, the shared-cost basis.
- The driver tree with every branch labelled.
- The declared expectation per unit and the deviation threshold that guardrails fire on.
- The `NOT DERIVABLE` list — this doubles as the instrumentation backlog.
- The date and the next scheduled refresh.

## Phase 6 — Validate

- **Reconcile the tree against the bill.** The sum of all attributed branches plus unallocated must equal the period's total spend. A tree that does not reconcile is wrong somewhere; find it rather than rounding.
- **Sanity-check the denominator** against a second source where one exists (billing system count versus product analytics count). A material disagreement is a finding in its own right.
- **Re-run one branch** with `unit-cost-probe` independently and confirm it matches.
- Dispatch `@finops-analyst` for the numeric review and `@cost-architect` for whether the tree's shape reflects the architecture.

### Unit-economics ledger — REQUIRED OUTPUT ARTIFACT (the run is not done until this table exists)

```
Branch          | Billed dimension | Usage/unit | Unit price (as-of) | Cost/unit | Share | Basis
API compute     | vCPU-seconds     | 0.42       | $x (2026-08-01)    | $0.0031   | 18%   | measured
Shared platform | cluster-hours    | —          | —                  | $0.0044   | 26%   | ALLOCATED (basis: request share)
ML inference    | tokens           | —          | —                  | —         | —     | NOT DERIVABLE — needs per-tenant token metric
```

Per-row `Basis`:
- **measured** — cost and usage both attributable at this granularity from the export.
- **ALLOCATED (basis: …)** — divided by a named proxy. Legitimate, but it is an assumption and is labelled as one.
- **NOT DERIVABLE** — the instrumentation does not exist. Named, with what would fix it.

## Phase 7 — Improve

- Refresh quarterly, or whenever the architecture changes materially.
- Work the `NOT DERIVABLE` list down — each item is a small instrumentation task that converts an assumption into a measurement.
- Feed the declared expectation into `/cost-guardrails` so deviations are detected rather than discovered.

## Output format

```
## /cost-model — <unit> — <period>

Unit:              <unit>   (denominator: <metric/source>)
Period:            <whole billing periods>
Pricing model:     <on-demand | committed | flat-rate capacity>
Shared-cost basis: <declared basis>
Unallocated:       <%> of total spend

Unit-economics ledger: <the table above, verbatim>

Cost per unit:       <$>   (measured <%> · allocated <%> · not derivable <%>)
Revenue per unit:    <$>   Contribution margin: <$> (<%>)
Change vs prior:     <$> — rate <$> · usage <$> · mix <$>
Reconciliation:      branches + unallocated = <$>  vs  bill total <$>   → <match | delta>

Declared expectation: <$/unit> ± <threshold>  → guardrail owner <name>
Not derivable (N): <each with the instrumentation that would provide it>

Status: <see gate below>
```

### Closure gate — COMPLETE only when the tree reconciles and every branch is labelled

- **`Status: COMPLETE`** — every branch labelled measured / ALLOCATED / NOT DERIVABLE, the tree reconciles to the bill total, the denominator's source is named, the shared-cost basis is declared, and the expectation plus threshold are written to `ai/finops/unit-economics.md`.
- **`Status: INCOMPLETE — unmet: <list>`** — the tree does not reconcile, a branch carries an unlabelled figure, the shared-cost basis is undeclared, or the denominator has no named source. Name each.

This gate is **[self-policed]** on the Status line, but every input is checkable: the export, the filters, the usage metric, and the reconciliation arithmetic are all reproducible. `@finops-analyst` will BLOCK a COMPLETE whose branches are unlabelled or whose tree does not reconcile.

## Hard rules

- **Three labels only: measured, ALLOCATED (named basis), NOT DERIVABLE.** No fourth category, no unlabelled numbers.
- **The tree must reconcile to the bill.** Attributed + unallocated = total, or the model is wrong.
- **Amortised and discounted, never list price.**
- **Whole billing periods.**
- **The shared-cost basis is declared by a human**, recorded in the artifact, and never chosen to make the arithmetic tidy.
- **No cost-per-unit figure without its denominator's source.**

## Failure modes

- A precise-looking cost per customer built on a proxy allocation nobody remembers choosing.
- Denominator drift: "active users" counted differently by the billing system and the analytics tool, so the unit cost moves without anything real changing.
- Reporting savings against list price.
- Building the model once, never refreshing it, and comparing this year's architecture to last year's assumptions.
- A model with no revenue side, so nobody can say whether the cost is acceptable.
- Ignoring the unallocated bucket until it is a third of the bill.

## Related

- `@finops-analyst` — populates the tree from the export.
- `@cost-architect` — uses the model as the baseline for the next design.
- `@cost-reviewer` — measures diff-level regressions against the declared expectation.
- `unit-cost-probe`, `commitment-coverage`, `egress-trace` — the executors.
- `/audit-cost-attribution` — run first; this model inherits its unallocated percentage.
- `/cost-guardrails` — consumes the declared expectation and threshold.
- `ai/patterns/unit-economics.md`, `ai/patterns/spend-allocation.md`.
