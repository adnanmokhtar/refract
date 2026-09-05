---
name: grain-probe
description: Prove a model's declared grain by executing a duplicate-key query against the built table and reporting rows, distinct keys, and the top offending key values. Run before any aggregation claim is trusted, before approving any fact-to-dimension join, after a grain or key change, and as the uniqueness column of every model audit. Proves the key IS unique in the data — `contract-diff` proves the upstream SHAPE has not changed under it, and `lineage-trace` proves who would be affected if it had.
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: grain-probe

## Premise

A grain is a claim about data, so it is settled by data. Reading the SQL tells you what the author intended; only the probe tells you what is in the table. Every output cites the model, the key expression probed, the row count, the distinct-key count, and — when they differ — real offending key values with their duplicate counts.

No estimate, no sampling shortcut, no "the primary key constraint covers it" (most analytical platforms do not enforce constraints; several accept them as documentation and ignore them at write time — confirm which yours does before ever treating one as proof).

## Halt conditions

- **No declared grain.** Refuse to probe. A probe of a key nobody declared proves nothing; get the grain sentence from `@warehouse-modeler` first.
- **Model not built.** Probe the materialised output, never the definition. A view whose upstream has not run is not evidence.
- **PII classification unknown** and the offending-value sample would print identifiers. Report counts only, and say the sample was withheld.
- **Filtered scope not stated.** If the probe runs on a partition subset (for cost), the output must name the subset — a unique result on last week does not clear the table.

## When to run

- Before any verdict from `@warehouse-modeler`, `@data-quality-auditor`, or `/audit-data-model` that touches uniqueness.
- Before approving a fact-to-dimension join, on the dimension's join key.
- After any change to a model's grain, key expression, deduplication rule, or incremental merge key.
- On the shadow target of a backfill, before cutover.
- On a Type 2 dimension: for the current-row uniqueness check AND the range-integrity checks below.

## Procedure

### 1. State the claim

Write the declared grain sentence and the key expression that is supposed to implement it. Composite grains are probed as a composite, never column by column — a column-wise probe on a legitimate composite key always fails and gets disabled, which is how the real check disappears.

### 2. Run the duplicate-key probe

Three numbers, one query shape:

```sql
select
  count(*)                                as rows_total,
  count(distinct <key_expression>)        as keys_distinct,
  count(*) - count(distinct <key_expression>) as duplicate_rows
from <model>
[ where <stated partition/date filter> ]
```

`duplicate_rows = 0` is the only passing result. Anything else means the grain and the key disagree.

### 3. Name the offenders

Never report only a count. Pull the worst offenders so the cause is findable:

```sql
select <key_expression> as k, count(*) as n
from <model>
[ where <same filter> ]
group by 1
having count(*) > 1
order by n desc
limit 20
```

Then read one offending group's full rows and classify the cause: genuine duplicate load, a join that fanned out, a grain that is finer than declared (the key is missing a column), a source that legitimately emits the same key twice, or a Type 2 dimension where "current" is not unique.

### 4. Null keys

A null key is not a duplicate, and `count(distinct ...)` will hide it. Count nulls in the key expression separately — a null grain key is always a defect, because the row can never be joined to and can never be updated by a merge.

```sql
select count(*) from <model> where <key_expression> is null
```

### 5. Type 2 dimensions — three extra probes

For a dimension with `valid_from` / `valid_to` / `is_current`:

- **One current row per natural key** — probe uniqueness of the natural key filtered to `is_current`.
- **No overlapping ranges** — self-join the dimension on the natural key and count pairs whose validity intervals intersect. Any non-zero result duplicates every fact that joins as-of a date in the overlap.
- **Gapless coverage** — for each natural key ordered by `valid_from`, count rows where the next row's `valid_from` is later than this row's `valid_to`. A gap silently drops facts that fall in it.

### 6. Report

```
## grain-probe — <model> — <date>

Declared grain:  <one sentence>
Key expression:  <expression>
Scope:           <full table | partitions X..Y>

rows_total:      <n>
keys_distinct:   <n>
duplicate_rows:  <n>
null_keys:       <n>

Verdict: UNIQUE | DUPLICATED | NULL-KEYS | NOT-PROBED

Top offenders (withheld if PII classification unknown):
| key | rows |
|-----|------|

Cause (from reading one offending group): <duplicate load | join fan-out | grain finer than
declared | legitimate source repeat | Type 2 current not unique>

Type 2 (when applicable):
  current rows unique per natural key: <yes/no — n offenders>
  overlapping ranges:                  <n pairs>
  coverage gaps:                       <n>
```

## Inputs

- The declared grain sentence (from the model's documentation or `@warehouse-modeler`).
- The built model, materialised.
- The PII classification of the table, if offender values are to be printed.

## Outputs

- The report block above, pasted verbatim into whatever ledger required it (`/audit-data-model`, `/add-data-model`, `/backfill-plan`, `@data-quality-auditor`).
- On a `DUPLICATED` verdict: a proposed standing uniqueness assertion on the declared grain key, so the regression fails a build instead of a dashboard.

## False positives / gotchas

- **Probing the source instead of the model.** The model may deduplicate; the source may not. Probe what consumers read.
- **Probing a filtered subset and reporting it as the table.** State the scope or the result is not usable.
- **`count(distinct)` on a platform that returns an approximation by default.** Several columnar engines approximate distinct counts unless an exact variant is requested — confirm the function's exactness before trusting a small non-zero delta, or the probe will invent duplicates that do not exist.
- **Composite keys concatenated without a separator** — `'ab' || '1'` and `'a' || 'b1'` collide and manufacture false duplicates. Use a separator that cannot appear in the values, or the platform's native tuple/struct comparison.
- **Nulls in a composite key** silently drop the whole row from `count(distinct)` on most engines. Probe nulls separately, always.
- **Declaring the grain from the probe result** — that is backwards. The grain is a business statement; the probe tests it. A key that happens to be unique today is not a grain.

## Related

### Skills
- `contract-diff` — when the probe fails after an upstream change, this classifies what changed.
- `lineage-trace` — sizes who is affected by a duplicated model before you fix it.

### Agents
- `@warehouse-modeler` — declares the grain this probe tests.
- `@data-quality-auditor` — turns a passing probe into a standing assertion.

### Commands
- `/audit-data-model`, `/add-data-model`, `/backfill-plan` — all require this skill's output.

### Patterns
- `ai/patterns/dimensional-model.md`
- `ai/patterns/data-quality-tests.md`
