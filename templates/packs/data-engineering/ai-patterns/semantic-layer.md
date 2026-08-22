---
name: semantic-layer
description: 'Pattern: Semantic Layer (one definition per metric, at one altitude, with its filters and denominator declared)'
kind: ai-pattern
pack: data-engineering
---

# Pattern: Semantic Layer

> **Hard rule:** Every business metric has exactly one definition, at one altitude — the semantic layer if the project has one, otherwise one named model. Its filters, its denominator, its grain, and its owner are declared with it. A metric computed a second time anywhere else, including inside a BI tool, is a defect with a citation on each side.

**When to apply**
- Two dashboards show a differently-named-but-supposedly-identical number and disagree.
- A metric's definition is about to change.
- A BI tool has started carrying business logic.
- Someone asks "which revenue is the real one" and there is no fast answer.

**When NOT to apply**
- A single metric with a single consumer and no ambiguity — a named column in a mart is the whole pattern.
- Before the marts are stable. A semantic layer over a shifting model layer moves the problem up a floor.

**Halt conditions / mandatory cites**
- Metric ownership undeclared when two definitions conflict — an engineer cannot pick which revenue is real. Escalate; do not choose silently.
- Denominator unstated for any rate or ratio — the metric is not defined.
- Grain unstated for the metric — "conversion rate" per session, per user, and per day are three different metrics.
- Any claim that two definitions "are basically the same" without a computed difference over a real period is a hand-wave — compute it or drop it.

## Why a metric drifts

Nobody sets out to define revenue twice. It happens in three moves:
1. A mart computes revenue with the filters that mart needs.
2. A second team needs revenue with slightly different filters and finds copying faster than negotiating.
3. A dashboard adds one more filter in the BI tool because the warehouse round-trip was slow that week.

Now there are three numbers, all defended, and no way to retire two of them because each has a stakeholder who has been quoting it for a year. The cost is not the arithmetic; it is that the organisation loses the ability to be corrected.

## What a metric definition contains

| Element | Why |
|---|---|
| **name** | the business term, from `ai/business-domain.md` |
| **grain** | per what — order, user, session, day. Changes the metric entirely |
| **expression** | the numerator, in terms of a named model's columns |
| **denominator** | for every rate/ratio. Unstated denominators are the single largest source of "why does this not match" |
| **filters** | every inclusion and exclusion, each with a reason (test accounts, internal orders, refunds, cancelled states) |
| **time semantics** | which timestamp, in which timezone, and whether the metric attributes to event time or recognition time |
| **owner** | who approves a change |
| **version + change log** | when the definition changed and what happened to the historical series |

A definition missing the denominator, the filters, or the time semantics is a name, not a definition.

## Altitude: pick one and defend it

| Altitude | Metric lives in | Good when | Cost |
|---|---|---|---|
| **Semantic layer** (a dedicated metrics definition layer the BI tool and the warehouse both read) | a versioned definition file | many consumers, several BI surfaces, metrics reused at different grains | another system to run and version |
| **Mart column** | one model, materialised | few consumers, one BI tool, stable grain | a metric needed at another grain forces a second model |
| **BI tool** | the dashboard | never for a shared metric | invisible to review, invisible to lineage, invisible to tests |

The BI tool is not an altitude for shared metrics. Logic there is unreviewable, untestable, untraceable by `lineage-trace`, and invisible to anyone who does not have a licence.

## Additivity travels with the metric

A metric defined at one grain and consumed at another must state how it aggregates. Store the components, not the result:
- Rates and ratios are defined as numerator and denominator, so they re-aggregate correctly at every grain.
- Distinct counts do not sum from a pre-aggregate; either define the metric only at grains where it is computed from detail, or state explicitly that the rollup is an approximation and by how much.
- Semi-additive measures declare their across-time rule (period end, not sum).

## Changing a definition

A metric change is a communication event with a code change attached:
1. Compute the difference over a real historical period, per period, and publish it. "Roughly the same" is not a result.
2. Decide whether history is restated. If not, the series has a documented break at a date and every consumer is told the date.
3. Bump the definition's version, record what changed and why.
4. Repoint every consumer found by `lineage-trace`, then remove the old definition after its stated window.

## Detectors

- The same business term appearing as a column in more than one mart with different filters.
- A rate or percentage stored as a single pre-divided column.
- BI-tool calculated fields that reference raw model columns rather than a defined metric.
- A metric definition with no owner.
- A metric whose filters include an unexplained exclusion (an account id list with no comment).
- Two dashboards whose totals for the same term differ by more than the stated tolerance — compute it on a cadence rather than waiting for someone to notice.
- A definition change with no note on the historical series.

**Closure verbs:** `collapse-duplicate-definition`, `split-ratio-columns`, `repoint-bi-to-metric`, `assign-metric-owner`, `document-metric-exclusion`, `reconcile-dashboard-totals`, `state-historical-series-effect`.

Each detector above closes with exactly one of these. `collapse-duplicate-definition` names which definition survives — a closure that leaves both in place has not closed anything, because two defensible numbers is worse than one wrong one. Never invent a verb.

- `ai/patterns/dimensional-model.md` — measure additivity, which a metric definition must respect.
- `ai/patterns/transformation-layers.md` — the model layer a metric is defined over.
- `@analytics-engineer` — the review agent that enforces single-definition.
- `lineage-trace` — enumerates the consumers a definition change must repoint.
- `/suggest-metrics` (business pack) — decides *which* metrics a domain should have; this pattern owns making each one singular.
