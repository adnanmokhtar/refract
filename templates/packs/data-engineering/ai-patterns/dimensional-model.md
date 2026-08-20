---
name: dimensional-model
description: 'Pattern: Dimensional Model (declared grain, fact types, measure additivity, SCD, conformed dimensions)'
kind: ai-pattern
pack: data-engineering
---

# Pattern: Dimensional Model

> **Hard rule:** Every fact and every dimension declares exactly one grain in words and proves it with a duplicate-key probe. Every measure is classified additive / semi-additive / non-additive next to the column. Every fact-to-dimension join has a proven many-to-one cardinality. A shared dimension has one definition and one owner. A model that violates any of these produces numbers that look right and are not.

**When to apply**
- Designing or reviewing any analytical fact or dimension table.
- Two dashboards disagree about a number that should be the same.
- An aggregate is inflated and nobody can say by how much.
- A "just add a column" request lands on a dimension that facts already reference historically.

**When NOT to apply**
- OLTP schema design — different pressures entirely (normalisation, write contention, constraint enforcement). That is the database pack.
- A single-source, single-consumer extract with no joins and no history requirement — dimensional modelling is overhead there; a well-named flat table is the whole answer.
- Event-level storage where the consumer is a stream processor, not an analyst.

**Halt conditions / mandatory cites**
- Grain undeclared for any model in scope — halt. Every downstream verdict derives from it.
- History requirement undeclared (does a fact need the dimension's value *as of* the event?) — the SCD verdict is unanswerable; cite `ai/decisions/dimension-history.md`.
- Tenancy model undeclared — determines whether tenant is part of every grain and every key.
- Late-arrival policy undeclared — determines partitioning and restatement shape.
- Any uniqueness claim without a `grain-probe` result from the current change is a hand-wave — reject it.

## Grain: the one sentence everything derives from

The grain is a business statement, written before the SQL: *"one row per order line per shipment"*, *"one row per account per calendar day"*, *"one row per customer, current state"*.

It is not the primary key. The key implements the grain; if they disagree, the key is wrong. And a key that happens to be unique in today's data is not a grain — it is a coincidence you have not been punished for yet.

Consequences of the grain, in order:
1. It fixes what one row means, so it fixes what `count(*)` means.
2. It fixes which dimensions can join many-to-one.
3. It fixes which measures are additive at that grain.
4. It fixes the uniqueness assertion that guards the model forever.

A model that mixes grains — order-level and line-level rows in one table, told apart by a nullable column — is two tables sharing a name. Split it.

## Fact types

| Type | One row is | Measures | Updated after insert? |
|---|---|---|---|
| **Transaction** | an event that happened | additive | no (corrections arrive as new rows or a restatement) |
| **Periodic snapshot** | an entity's state at a period end | usually semi-additive (balances, inventory) | no (each period is a new row) |
| **Accumulating snapshot** | one instance of a multi-step process | durations and milestone dates | yes — columns fill in as the process advances |

Accumulating snapshots are the only fact type that is legitimately updated in place, and they are the ones most often implemented as three separate transaction tables that nobody can join.

## Measure additivity — the classification that prevents silent nonsense

| Class | Sums across | Example | Wrong aggregation |
|---|---|---|---|
| **Additive** | every dimension including time | revenue, quantity | — |
| **Semi-additive** | every dimension *except* time | account balance, inventory on hand, headcount | `sum()` over a date range — produces an arbitrary large number presented as money |
| **Non-additive** | nothing; must be recomputed from components | ratios, percentages, distinct counts | averaging an average; summing a rate; summing a pre-aggregated distinct count |

Store ratios as numerator and denominator columns. A stored ratio cannot be re-aggregated at any other grain, so the first person who rolls it up gets a wrong answer with no warning.

## Keys and slowly-changing dimensions

- **Surrogate key** — stable, meaningless, generated. Facts join on it.
- **Natural / business key** — retained as a column for lookup and reconciliation. Never used as the fact's join key on a Type 2 dimension, because it is not unique there.
- **SCD type is per attribute, not per table.** Cosmetic attributes are Type 1 (overwrite); attributes that facts must be attributed by are Type 2 (new row, effective-dated).

Type 2 integrity is three assertions, all mandatory:
- Exactly one current row per natural key.
- No overlapping validity ranges — an overlap duplicates every fact that joins as-of a date inside it.
- No coverage gaps — a gap silently drops facts that fall in it.

Every dimension carries an **unknown member** row so a fact with a missing or late-arriving key still joins. Facts vanishing on an inner join is the most expensive class of warehouse bug precisely because the result still looks like a number.

## Conformed dimensions

A dimension used by more than one fact has ONE physical model and ONE owner. The moment a second `dim_customer` exists with a slightly different active-customer filter, two dashboards can disagree forever and neither is refutable.

Mart-specific variation belongs in a flag column or a view over the conformed dimension — never in a fork.

## Cardinality and bridges

Every join predicate states its expected cardinality, and the expectation is proven by counting fact rows before and after the join:
- Row count increases → fan-out. The aggregate is inflated. This is a defect, not a performance note.
- Row count decreases → silent row loss. Usually a missing unknown member.

Genuine many-to-many relationships (a fact with multiple categories, a transaction split across cost centres) go through an explicit bridge table with a declared allocation rule whose weights sum to one. A raw many-to-many join is double-counting with extra steps.

## Physical layout

- Partition on the column queries filter, which is almost always the **event** date. Partitioning on load date while filtering on event date makes every "last 7 days" query read the entire table — correct-looking, and expensive forever.
- Cluster/sort keys come from observed predicates in the query history, not from intuition, and are revisited when access patterns change.
- Declare a restatement window for late-arriving facts; partitions outside it are closed.

## Detectors

- A model with no grain sentence in its documentation.
- A `sum()` over a column annotated semi-additive, or over a column whose additivity is not annotated at all.
- A stored column whose name ends in `_rate`, `_pct`, or `_ratio` with no sibling numerator/denominator.
- A Type 2 dimension with no `is_current` uniqueness assertion.
- Two models producing a column with the same business name and different filters.
- A fact foreign key that is nullable with no unknown member in the referenced dimension.
- A partition key named for a load timestamp while every downstream filter uses an event timestamp.

## Related

- `ai/patterns/transformation-layers.md` — where these models live and how they are materialised.
- `ai/patterns/semantic-layer.md` — where the metric on top of these facts is defined once.
- `ai/patterns/data-quality-tests.md` — the standing assertions that keep this shape true.
- `@warehouse-modeler` — the review agent that enforces this pattern.
- `grain-probe` — the executable proof behind every uniqueness claim here.
