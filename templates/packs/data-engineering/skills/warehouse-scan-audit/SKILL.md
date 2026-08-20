---
name: warehouse-scan-audit
description: Audit what the warehouse's transformation and BI queries actually scan — partition pruning, cluster/sort effectiveness, unpruned full scans, `SELECT *` amplification, exploding joins, and models whose recompute cost has outgrown their value. Run when the warehouse bill jumps, before materializing something expensive, when a model's runtime doubles, and quarterly on the top-cost models. Owns the SQL that causes the spend — the finops pack owns the spend envelope, the budget, and who pays for it.
---

# Skill: warehouse-scan-audit

## Premise

Warehouse spend is bytes scanned or slot-seconds consumed, and both are produced by specific lines of SQL. Every finding names the query or model, the observed bytes/slots, and the specific cause — a predicate that cannot prune, a column list that pulls a wide row, a join that multiplies. "The warehouse is expensive" is not a finding; a table of the ten most expensive queries with their scan bytes and their prune-blocking predicates is.

Numbers come from the platform's own query history or job statistics, never from an estimate, and never from reading the SQL alone.

## Halt conditions

- **No access to query history / job statistics.** Refuse to produce cost findings. Report what is inspectable statically (unpruned predicates, `SELECT *`, cross joins) and mark the cost column `UNKNOWN — requires query history access`.
- **Pricing model unknown** (per-byte-scanned versus per-slot-second versus flat-rate capacity). The optimisation that helps under one is neutral under another; ask before recommending.
- **Reserved-capacity environment** where a single query's marginal money cost is zero. Optimise for contention and runtime instead, and say so — a "$ saved" number would be fiction.

## When to run

- After a warehouse bill increase, alongside the finops pack's `spend-anomaly-triage` (that skill finds *which* dimension moved; this one finds *which SQL* moved it).
- Before changing a model's materialization to table or incremental.
- When a model's runtime or scan volume doubles.
- Quarterly on the top-cost models and dashboards.
- On the orphan list produced by `lineage-trace` — a scheduled model with no consumer is pure spend.

## Procedure

### 1. Rank by observed cost

Pull the platform's query/job history for a full billing cycle. Rank by total bytes scanned (or slot-seconds), aggregated by model and by dashboard, not by individual query — one dashboard firing 400 small queries can outspend one big model.

Record per entry: total cost, run count, cost per run, and trend versus the prior cycle.

### 2. Diagnose the top entries

For each of the top entries, find the cause. These are the recurring ones, in rough order of how much they cost:

- **Predicate cannot prune.** The filter is on a column that is not the partition key, or the partition column is wrapped in a function, or the filter compares against a value the engine cannot resolve at plan time (a subquery, a non-deterministic function). The scan reads everything.
- **Partition key is the load date, filter is the event date.** Every "last 7 days" query reads the whole table. This is the most common expensive mistake in a warehouse and it looks correct.
- **`SELECT *` on a wide columnar table.** Columnar engines charge for columns read; selecting 200 columns to use 6 is a 30x amplification on that step, repeated at every layer that inherits it.
- **View chains.** A view over a view over a view re-executes the whole chain per reference. Materialise the shared middle.
- **Join fan-out.** An unintended many-to-many multiplies rows before the aggregate. This is both a cost defect and a correctness defect — hand it to `grain-probe` immediately; the number is probably also wrong.
- **Full refresh on an append-mostly fact.** Cost grows with history for no benefit.
- **Cluster/sort keys chosen once, never revisited.** Compare the declared keys against the actual predicate columns in the query history; a clustering key nobody filters on is storage overhead with no read benefit.
- **Dashboard queries without a date bound.** A default "all time" range on a large fact, refreshed on a schedule, by every viewer.

### 3. Attribute to a decision, not a person

Each finding names what would change: the partition key, the predicate, the column list, the materialization, the schedule, or the dashboard's default range. A finding whose fix is "write better SQL" is not actionable.

### 4. Quantify the fix

For each recommendation, state the expected reduction and how it was derived — the same query with the corrected predicate, run once, with its observed bytes. A projected saving with no measured comparison run is a guess; mark it `UNMEASURED` and keep it out of any total.

### 5. Report

```
## warehouse-scan-audit — <scope> — <period>

Pricing model: <per-byte | per-slot-second | flat capacity>
Source: <platform query history>   Period: <full billing cycle>

### Top cost entries
| Entry (model/dashboard) | Runs | Bytes/slots total | Per run | Trend | Cause | Fix | Expected Δ (measured?) |
|-------------------------|------|-------------------|---------|-------|-------|-----|------------------------|

### Structural findings (static, no history needed)
| Path:line | Shape | Class |
|-----------|-------|-------|
| models/marts/x.sql:12 | SELECT * over 180-column source | amplification |

### Orphan spend (from lineage-trace)
| Model | Schedule | Cost / cycle | Consumers | Recommendation |

Totals: measured savings <$/bytes> · unmeasured candidates <n> (excluded from the total)
```

## Inputs

- Platform query history / job statistics for a full billing cycle.
- The pricing model in effect.
- `lineage-trace` orphan list.
- The model definitions, for the static pass.

## Outputs

- The report block above.
- Findings routed: correctness-shaped fan-out → `grain-probe` and `@warehouse-modeler`; materialization changes → `@analytics-engineer`; schedule changes → `@dag-reviewer`; the money total and its budget consequence → the finops pack's `/cost-model`.

## False positives / gotchas

- **Ranking by cost per run instead of total.** The expensive thing is usually cheap and frequent.
- **Optimising a query that runs monthly** because it is the single biggest line. Multiply by frequency first.
- **Claiming savings from a query you did not re-run.** Mark it `UNMEASURED` or measure it.
- **Recommending clustering without checking the write cost.** Clustering is maintained on write; a heavy-write, light-read table can lose.
- **Confusing bytes billed with bytes scanned** on platforms that apply a per-query minimum — a thousand tiny queries can bill far above their scanned total.
- **Treating a fan-out as purely a cost problem.** If rows multiplied, the aggregate is wrong. Cost is the symptom; correctness is the finding.
- **Reporting a saving in a flat-rate capacity environment.** There is no marginal money there; report contention and runtime instead.

## Related

### Skills
- `lineage-trace` — supplies the orphan list.
- `grain-probe` — takes over the moment a fan-out is found.

### Agents
- `@analytics-engineer` — materialization and layering fixes.
- `@warehouse-modeler` — partition and cluster key decisions.
- `@dag-reviewer` — schedule and concurrency fixes.

### Commands
- `/backfill-plan` — uses this skill's per-chunk cost estimates.
- `/cost-model` (finops pack) — receives the money total; this skill does not own the budget.

### Patterns
- `ai/patterns/transformation-layers.md`
- `ai/patterns/dimensional-model.md`
