---
name: transformation-layers
description: 'Pattern: Transformation Layers (staging / intermediate / mart, materialization choice, incremental correctness)'
kind: ai-pattern
pack: data-engineering
---

# Pattern: Transformation Layers

> **Hard rule:** Staging reads sources only and does no business logic; intermediate holds the reusable joins; marts are the consumable surface. Nothing past staging reads a raw source. Every model reaches its upstream through the framework's reference function — never a hardcoded table name. Every incremental model declares its merge key, its event-time predicate, its late-arrival lookback, and its full-refresh trigger.

**When to apply**
- Adding or refactoring any transformation model.
- A full refresh has become too slow or too expensive to run.
- A raw column name or a source sentinel value has appeared in a dashboard.
- The same join or the same business rule exists in more than one mart.

**When NOT to apply**
- A single-hop extract with one consumer and no reuse — three layers over one query is ceremony.
- Streaming transformations with a different execution model; the layering idea transfers, the materialization table does not.

**Halt conditions / mandatory cites**
- Refresh contract undeclared (how fresh, for whom) — materialization cannot be chosen.
- Late-arrival window undeclared on any incremental model — "incremental is safe" is unassertable.
- Restatement policy undeclared — determines whether append-only is legal at all.
- Cost envelope unknown when recommending a durable materialization increase — cite the finops pack's unit-economics ledger or ask.

## The three layers and their contracts

| Layer | Reads | Does | Never does | Default materialization |
|---|---|---|---|---|
| **Staging** | exactly one source table each | rename to project convention, cast types, coerce sentinels to null, deduplicate to the source's grain | join across sources, apply business rules, filter for a report | view / ephemeral |
| **Intermediate** | staging + intermediate | the joins and derived logic that more than one mart needs | get exposed to BI | view; table when reused and expensive |
| **Mart** | intermediate + staging | produce the consumable facts and dimensions in business vocabulary | read a raw source | table or incremental |

The direction is one-way. The value of the staging layer is precisely that it is boring: it is the only place that knows the source's quirks, so a source rename changes one file instead of eleven.

**Violations worth grepping for**, each a finding with a citation:
- A mart or intermediate model selecting from a source directly.
- A staging model joining two sources.
- A hardcoded fully-qualified table name instead of the reference function — the edge is invisible to the dependency graph, so build order and lineage are both wrong and nothing reports it.
- Two staging models over the same source with different dedup rules.
- A model that both aggregates and filters for one specific dashboard — a report has been pushed into the warehouse.

## Materialization: choose from the table, record the reason

| Situation | Choose | Why |
|---|---|---|
| thin rename/cast, cheap to recompute | view | zero storage, always fresh |
| reused by several downstream models, expensive | table | pay once per run, not once per reader |
| large append-mostly fact, event-dated, bounded restatement window | incremental | full-refresh cost otherwise grows without bound |
| the source has no history and history is needed | snapshot / Type 2 capture | history cannot be reconstructed later |
| one ad-hoc reader, monthly | view | storage for one reader is waste |

Write the reason next to the model. Materialization chosen by habit is the most common source of both surprise cost and surprise staleness.

## Incremental correctness — the four declarations

An incremental model without all four is a bug that has not surfaced yet:

1. **Merge key** — the model's declared grain key. The write is an upsert on it, so a reprocessed row replaces rather than duplicates.
2. **Predicate on event time, with a lookback** — `event_at >= <high-water mark> - <lookback>`. Filtering on load time, or on the high-water mark with no lookback, loses every late-arriving row permanently and silently: row counts keep growing daily, so nothing looks wrong.
3. **Late-arrival lookback window** — a number, justified by how late rows actually arrive in this system, measured rather than assumed.
4. **Full-refresh trigger** — the condition under which the incremental history must be rebuilt (logic change, key change, a correction outside the lookback).

And one property: **a full refresh must reproduce the incremental history.** If it cannot, that is a known divergence and must be written down, not discovered during an audit.

## Naming and exposure

- One scheme, applied everywhere: layer prefix, entity, grain qualifier (`stg_`, `int_`, `fct_`, `dim_`, `_daily`).
- Mart columns use the vocabulary in `ai/business-domain.md`, not the source system's vocabulary.
- Deprecation is a sequence, never a rename: ship the replacement → repoint consumers found by `lineage-trace` → remove. Renaming in place breaks every consumer at once and the graph will not tell you who they were.

## Detectors

- `SELECT *` outside a dated, annotated staging passthrough.
- A model file containing a fully-qualified physical table name.
- An incremental model whose predicate mentions a load/ingested timestamp.
- An incremental model with no lookback expression.
- A model with no downstream edge and a live schedule.
- Duplicate `CASE` expressions defining the same business category in more than one mart.
- A view chain deeper than three hops feeding a dashboard.
- A hardcoded date literal as the "start of data".

**Closure verbs:** `narrow-select-star`, `use-reference-function`, `fix-incremental-predicate`, `add-lookback-window`, `retire-unconsumed-model`, `consolidate-duplicate-case`, `flatten-view-chain`, `parameterise-start-date`.

Each detector above closes with exactly one of these. Never invent a verb — a finding that fits none of them belongs to a different pattern.

- `ai/patterns/dimensional-model.md` — the shape the mart layer produces.
- `ai/patterns/semantic-layer.md` — where a metric is defined once, above the marts.
- `ai/patterns/data-contract.md` — what staging absorbs when a source changes.
- `@analytics-engineer` — the review agent that enforces this pattern.
- `lineage-trace`, `warehouse-scan-audit` — the executors for deprecation and materialization decisions.
