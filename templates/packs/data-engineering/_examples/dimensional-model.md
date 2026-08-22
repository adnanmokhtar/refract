---
name: dimensional-model
kind: example
pack: data-engineering
---

# Pattern: Dimensional Model

> **Hard rule:** Every fact and dimension declares one grain in words and proves it with a duplicate-key probe. Every measure is classified additive / semi-additive / non-additive. Every fact-to-dimension join has a proven many-to-one cardinality. A shared dimension has one definition and one owner.

**Halt conditions / mandatory cites**
- Grain undeclared for any model in scope — halt. Every downstream verdict derives from it.
- History requirement undeclared (does a fact need the dimension's value *as of* the event?) — the SCD verdict is unanswerable; cite `ai/decisions/dimension-history.md`.
- Tenancy model undeclared — determines whether tenant is part of every grain and every key.
- Late-arrival policy undeclared — determines partitioning and restatement shape.
- Any uniqueness claim without a `grain-probe` result from the current change is a hand-wave — reject it.

## Grain

A business statement written before the SQL: *"one row per order line per shipment"*. Not the primary key — the key implements the grain, and if they disagree the key is wrong. A key that happens to be unique today is a coincidence you have not been punished for yet.

The grain fixes what `count(*)` means, which dimensions can join many-to-one, which measures are additive, and the uniqueness assertion that guards the model forever.

## Fact types

| Type | One row is | Measures | Updated after insert |
|---|---|---|---|
| transaction | an event | additive | no |
| periodic snapshot | state at period end | usually semi-additive | no |
| accumulating snapshot | one process instance | durations, milestone dates | yes |

## Additivity

| Class | Sums across | Wrong aggregation |
|---|---|---|
| additive | everything including time | — |
| semi-additive | everything except time | `sum()` over a date range |
| non-additive | nothing | averaging an average; summing a rate or a pre-aggregated distinct count |

Store ratios as numerator and denominator. A stored ratio cannot be re-aggregated at another grain.

## Keys and SCD

Surrogate key for joins; natural key retained for lookup. SCD type is per attribute, not per table. Type 2 integrity is three assertions: one current row per natural key, no overlapping ranges, no coverage gaps. Every dimension carries an unknown member so facts never vanish on an inner join.

## Conformance and cardinality

A dimension used by two facts has one physical model and one owner; mart-specific variation is a flag or a view, never a fork.

Prove every join by counting fact rows before and after: an increase is fan-out (the aggregate is inflated), a decrease is silent row loss (usually a missing unknown member). Genuine many-to-many goes through a bridge with allocation weights summing to one.

## Physical layout

Partition on the column queries filter — usually the event date. Partitioning on load date while filtering on event date makes every "last 7 days" query read the whole table, correctly and expensively, forever.

## Detectors

- A model with no grain sentence.
- `sum()` over a semi-additive or unannotated measure.
- A `_rate` / `_pct` column with no sibling numerator and denominator.
- A Type 2 dimension with no `is_current` uniqueness assertion.
- Two models producing the same business term with different filters.
- A nullable fact foreign key with no unknown member.
- A partition key named for load time while downstream filters use event time.

**Closure verbs:** `declare-grain`, `annotate-additivity`, `split-ratio-columns`, `add-scd2-current-assertion`, `conform-dimension`, `add-unknown-member`, `repartition-on-event-time`.

Each detector closes with exactly one of these; never invent a verb. A finding closed in prose cannot be diffed by the next audit run, so a repeat defect never surfaces as SYSTEMIC.

## Related

- `ai/patterns/transformation-layers.md`, `ai/patterns/semantic-layer.md`, `ai/patterns/data-quality-tests.md`
- `@warehouse-modeler`, `grain-probe`
