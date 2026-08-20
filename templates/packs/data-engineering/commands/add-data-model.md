---
description: Author a new warehouse model (staging / intermediate / fact / dimension) in the project's own layering and naming idiom, with its declared grain, its assertions, and its lineage registered before it is exposed to any dashboard.
kind: command
pack: data-engineering
---

# /add-data-model <model-name> [--layer staging|intermediate|mart] [--grain "<one sentence>"]

Add one transformation model that is trustworthy on the day it ships: grain declared and proven, layering respected, materialization justified, assertions written alongside the SQL, and every consumer of anything it changes named before the commit.

## When to use / NOT to use

- USE: a new source needs a staging model; a mart needs a new fact or dimension; a repeated join belongs in an intermediate model; an existing report calculation should move into the warehouse.
- NOT: designing the dimensional shape of a whole subject area — dispatch `@warehouse-modeler` first, then come back with the grain decided.
- NOT: changing what an existing model means — that is a contract change; run `contract-diff` and `lineage-trace` and treat it as a migration, not an addition.
- NOT: an OLTP table or migration — that is `/add-migration` in the database pack.

## Phases applied

All 7.

## The Premise (read this first, internalize, do not deviate)

**Sibling models are the truth.** The layer directories, the naming scheme, the reference function, the materialization defaults, the assertion style, and the documentation block used by the models already in this repo ARE the convention. A new model matches its nearest sibling in the same layer — same header shape, same reference idiom, same test placement. Divergence needs a cited reason recorded next to the model.

**Grain before SQL.** The model's grain is written in one sentence before a line of SQL is authored, and proven with `grain-probe` before the model is considered complete. A model that is written first and grained afterwards has already chosen its bugs.

**Closure verb (default): match-sibling-shape.** Apply layering, naming, materialization, and assertion parity silently; batch into the end-of-run summary. Halt only on the escalation triggers.

**Escalation triggers (halt and ask):**
- No sibling exists in the target layer (first model of its kind — the user picks the convention).
- The declared grain cannot be proven unique with any candidate key in the source.
- The model would duplicate a metric definition that already exists elsewhere in the repo.
- Materialising it as a table or incremental would add durable warehouse spend with no stated envelope.

## Phase 1 — Understand

Confirm, in one consolidated question if anything is missing:
- **Grain** — one sentence: "one row per `<entity>` per `<qualifier>`".
- **Layer** — staging (one source, rename/cast only), intermediate (reusable joins), or mart (consumable).
- **Consumer** — who reads it and what decision it feeds. A model with no named consumer is not built.
- **Freshness expectation** — how stale may it be.
- **History requirement** — does anything need "the value as of the event date"? If yes, `@warehouse-modeler` decides the SCD type before this command proceeds.

## Phase 2 — Organize

- Locate the nearest sibling model in the target layer; that file is the shape template.
- Decide the materialization from the decision table in `ai/patterns/transformation-layers.md` and write the reason down now, not after.
- List the upstream models/sources this will reference and confirm each exists via the framework's reference function.
- List the assertions this model will ship with — at minimum: uniqueness on the grain key, not-null on join/filter columns, referential integrity to every dimension it references, accepted values on every enum it branches on.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/patterns/transformation-layers.md`, `ai/patterns/dimensional-model.md`, `ai/patterns/data-quality-tests.md`.
- `.claude/rules/data-engineering-principles.md`.
- The sibling model file and its assertion file.
- `ai/business-domain.md` for the vocabulary mart columns must use.

## Phase 4 — Generate

1. Write the model with its documentation block first: grain sentence, consumer, freshness expectation, materialization reason.
2. Reference upstream exclusively through the project's reference function — never a hardcoded fully-qualified table name.
3. Name every column explicitly. No `SELECT *` outside a staging passthrough that is annotated as temporary with a date.
4. If incremental: state the unique key, the incremental predicate on the **event** timestamp, the late-arrival lookback window, and the condition under which a full refresh is required — all four, next to the code.
5. Write the assertions in the same commit. A model whose tests arrive "in a follow-up" ships untested.
6. Money as integer minor units or exact decimal plus a currency column. Ratios as numerator + denominator columns, never pre-divided.

## Phase 5 — Update

- Register the model in the project's model documentation/catalog.
- If it introduces or changes a metric definition, update the semantic-layer definition and note the change date.
- If it supersedes an existing model, do NOT delete the old one in this commit — run `lineage-trace`, point the consumers, then remove in a later change.

## Phase 6 — Validate

Agent-verified, in this order — each produces evidence pasted into the ledger:

1. **`grain-probe`** on the built model. A duplicate-key result stops the run; the grain or the key is wrong.
2. **Assertions run** — every new assertion executes and reports pass/fail. An assertion that has never executed is not shipped.
3. **Referential check** — every dimension reference resolves; unmatched fact rows counted and either zero or explained by an unknown-member row.
4. **Row-count sanity** — compare against the source's expected count at the same grain, with the delta explained.
5. **`lineage-trace`** — confirms the new model appears downstream of exactly the upstreams intended, and that nothing unexpected already depends on a name it shadows.
6. If incremental: **run it twice** on the same window. The second run must not change row count or measure totals. A model that fails this is not incremental, it is append.

### Model ledger — REQUIRED OUTPUT ARTIFACT (the run is not done until this table exists)

One row per model authored:

```
Model            | Layer | Grain (declared)             | grain-probe | Assertions run (pass/fail) | Re-run stable | Status
stg_orders       | stg   | one row per source order     | unique      | 4/4 pass                   | n-a (view)    | READY
fct_order_lines  | mart  | one row per order line       | unique      | 6/6 pass                   | yes           | READY
```

Per-row `Status`:
- **READY** — grain proven unique, every assertion executed and passed, referential check clean, incremental re-run stable (or not applicable), lineage confirmed.
- **UNPROVEN** — an assertion did not execute, or `grain-probe` was not run. Not shippable; name what is missing.
- **FAILED** — grain not unique, an assertion failed, or the second incremental run changed totals. Halt.

## Phase 7 — Improve

- Record any new convention decision (a first-of-its-kind layer, a new materialization rule) in `ai/decisions/`.
- If the model was hard to grain because the source lacks a stable key, file that as a source-side finding for the database pack rather than compensating for it forever in SQL.

## Output format

```
## /add-data-model — <model-name>

Layer:            <staging|intermediate|mart>
Grain:            <one sentence>
Materialization:  <view|table|incremental|snapshot> — <reason>
Upstreams:        <list>
Assertions added: <N>

Model ledger: <rows> — READY <r> | UNPROVEN <u> | FAILED <f>
  <the ledger table above, verbatim>

Sibling matched: <path of the sibling whose shape was mirrored>
Parity edits applied silently: <N>

Status: <see gate below>
```

### Closure gate — COMPLETE only when every ledger row is READY

- **`Status: COMPLETE`** — every row READY, `lineage-trace` clean, and the model documented in the catalog. Nothing else.
- **`Status: INCOMPLETE — unmet: <list>`** — the moment any row is UNPROVEN or FAILED, or an assertion was written but not executed. Name each unmet model and why (`fct_order_lines — FAILED: grain-probe found 12 duplicate order_line_id`).

This gate is **[self-policed]** on the Status line but wired to checkable evidence: `grain-probe` output, assertion run results, and the second incremental run are all reproducible. `@warehouse-modeler` and `@data-quality-auditor` will BLOCK a COMPLETE whose ledger has no probe output.

## Hard rules

- **Grain declared and proven before COMPLETE.** Not asserted — probed.
- **Assertions ship in the same commit as the model.**
- **No hardcoded table references.** The dependency graph is only as complete as the reference function usage.
- **No metric defined twice.** If the calculation already exists, reference it; do not re-derive.
- **No mart reading a raw source** when a staging model exists or could exist.

## Failure modes

- Grain written after the SQL, so the key was chosen to fit the query rather than the business event.
- Incremental predicate on load time instead of event time — late rows lost forever, silently.
- Tests deferred to a follow-up that never lands.
- A "temporary" `SELECT *` in a staging model that outlives the person who wrote it.
- Superseding model shipped and old model deleted in the same commit, breaking consumers nobody enumerated.

## Related

- `@warehouse-modeler` — decides grain, keys, and SCD before this command runs.
- `@analytics-engineer` — owns the layering and materialization conventions this command mirrors.
- `@data-quality-auditor` — audits whether the assertions written here are sufficient.
- `grain-probe`, `lineage-trace`, `contract-diff` — the executors in Phase 6.
- `ai/patterns/transformation-layers.md`, `ai/patterns/dimensional-model.md`, `ai/patterns/data-quality-tests.md`.
- `.claude/rules/data-engineering-principles.md`.
