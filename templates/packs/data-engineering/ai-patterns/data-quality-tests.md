---
name: data-quality-tests
description: 'Pattern: Data Quality Tests (four floors — structural, temporal, distributional, reconciliation — plus severity and routing)'
kind: ai-pattern
pack: data-engineering
---

# Pattern: Data Quality Tests

> **Hard rule:** Every model a human or a dashboard reads clears four independent floors — structural, temporal, distributional, reconciliation. Every assertion has a severity, an owner, and a route. A money- or count-bearing fact with no reconciliation check is uncovered no matter how many column tests it has, because reconciliation is the only floor that catches corruption which preserves shape and changes values.

**When to apply**
- Any model backing a decision, a dashboard, a payout, a report, or an external export.
- Before a model is exposed to consumers outside the team that built it.
- After any incident where a wrong number reached a human.
- When the test suite has never failed — that is a finding, not a comfort.

**When NOT to apply**
- Genuinely exploratory models with a stated expiry and no consumer.
- Raw landing tables whose whole purpose is to preserve the source verbatim, including its defects — assert on the staging model above them instead.

**Halt conditions / mandatory cites**
- Declared grain missing — uniqueness coverage is unassessable.
- Freshness SLA undeclared — there is no such thing as a late table without one.
- Failure policy undeclared (halt / quarantine / warn) — the correct answer differs per model and cannot be guessed.
- Owner undeclared for any severity-`error` assertion — an unrouted page is worse than no page.
- Any threshold with no derivation from trailing history or a stated business bound is a hand-wave — reject it.

## Why application tests are not enough

Application tests answer *does the code do what it says*. Data tests answer *is what arrived today the same thing that arrived yesterday*. The code can be perfect while the data is wrong: an upstream team renamed a field, a currency changed, a source started sending nulls, a job ran twice, a credential expired and the load succeeded with zero rows.

Coverage is measured **per model and per floor**. An aggregate "94% of models have at least one test" is a hiding place — the one test is usually a not-null on a column nobody reads.

## Floor 1 — Structural: is the shape right?

- Uniqueness on the declared grain key. Composite grains asserted as a composite, never column by column — a column-wise assertion on a legitimate composite key always fails and gets disabled, which is how the real check disappears.
- Not-null on every column a downstream join or filter depends on.
- Referential integrity from every fact foreign key to its dimension. The warehouse does not enforce it; nothing else will.
- Accepted values on every status/type/enum column consumed by a branch, so a new upstream member fails instead of falling silently into `else`.
- Type and range bounds on measures — no negative quantities where impossible, money within a defensible bound.

## Floor 2 — Temporal: is it there, and is it current?

- **Freshness** per source and per mart, with a threshold tied to the load cadence. A daily table with a seven-day threshold is decoration.
- **Volume as a band**, derived from trailing history — not an absolute floor a growing business always clears. This is the assertion that catches the successful-run-loaded-nothing outage, which passes every column test ever written because there are no rows to violate them.
- Type 2 dimension range integrity: one current row per natural key, no overlapping ranges, no coverage gaps.

## Floor 3 — Distributional: is it plausible?

- Null-rate per important column against its trailing baseline. A field that silently starts arriving empty passes every not-null test on the columns you did think of.
- Category-mix drift on key dimensions.
- Sum/mean drift on headline measures against the trailing period, with an explicit tolerance — this is what catches a unit or currency change on the day it happens.

Distributional assertions default to severity `warn` and route to the owner, not to a pager — unless the model backs a money-moving decision, where the correct default is `error`.

## Floor 4 — Reconciliation: does it agree with the source of truth?

- Row-count and sum reconciliation between the source system and the warehouse for every money- and count-bearing fact, at a stated cadence and tolerance.
- Cross-grain agreement: a daily rollup sums to its detail fact.

This is the floor most warehouses skip and the only one that catches "the pipeline is healthy and the data is wrong". Every failure mode that preserves shape while changing values — a currency switch, a partial load, a double run — passes floors 1 through 3 completely.

## Severity, routing, quarantine

| Severity | Meaning | On failure | Routes to |
|---|---|---|---|
| `error` | unusable; would mislead | halt the model's build; downstream does not run on it | the owning team; paged only if a money or decision surface consumes it |
| `warn` | plausible drift, needs a look | build continues, row flagged | owner's ticket queue |
| `quarantine` | some rows bad, most fine | offending rows diverted with their reason; good rows proceed | owner reviews on a stated cadence |

A quarantine table with no reader and no retention policy is a landfill: the rows are lost, and you are paying to store the evidence. Give it a reader or delete it.

## Deriving thresholds honestly

Every threshold cites either a trailing-history statistic computed when it was set (the window, the statistic, the tolerance, all recorded inline) or a stated business bound. Borrowed numbers — "5% is standard" — produce assertions that either never fire or fire constantly, and both end in the assertion being disabled.

## Proving an assertion can fail

An assertion that has only ever run against clean data is unverified. Inject a violating row into a scratch copy — never production — and confirm it fires *and* routes to the right place. Do this once per assertion class, not per assertion.

## Detectors

- A suite with zero failures in its entire run history.
- Assertions disabled with a "temporary" comment older than a quarter.
- A severity-`error` assertion on a model with no owner.
- A model with structural assertions and no freshness or volume monitor.
- A money-bearing fact with no reconciliation assertion.
- A volume monitor expressed as an absolute row floor.
- A quarantine table whose last read is older than its retention.
- Tests concentrated on staging models, with marts untested — the mart is where the number becomes a claim.

**Closure verbs:** `prove-assertion-can-fail`, `retire-disabled-assertion`, `assign-assertion-owner`, `add-freshness-monitor`, `add-volume-band`, `add-reconciliation-check`, `derive-threshold-from-history`, `route-quarantine-reader`, `move-coverage-to-marts`.

Each detector above closes with exactly one of these. `prove-assertion-can-fail` is the one that closes the zero-failure-history detector, and it is the only closure that detector accepts — a suite that has never failed is unproven, not clean, and adding more assertions to it does not change that. Never invent a verb.

- `ai/patterns/data-contract.md` — accepted values and drift bounds come from the contract.
- `ai/patterns/dimensional-model.md` — the grain the structural floor asserts against.
- `@data-quality-auditor` — the review agent that enforces this pattern.
- `/audit-data-quality` — the command that measures coverage and closes the gaps.
- `grain-probe` — the executable uniqueness proof.
- `alert-design` (observability pack) — the routing these assertions reuse rather than duplicating.
