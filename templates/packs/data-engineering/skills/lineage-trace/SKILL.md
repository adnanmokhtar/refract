---
name: lineage-trace
description: Trace a column, model, or metric downstream to every consumer — models, dashboards, exports, reverse-ETL syncs, notebooks — and upstream to its sources, then report orphans and unreachable nodes. Run before changing or deleting anything in the warehouse, when sizing the blast radius of a defect, and when hunting models nobody reads. Answers WHO is affected — `contract-diff` answers WHETHER a change is breaking, and `grain-probe` answers whether the data is what it claims.
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: lineage-trace

## Premise

Nobody changes a warehouse model on purpose without knowing its consumers; they do it because finding the consumers is tedious. This skill makes the enumeration cheap and complete, and it is explicit about where its own vision ends — a lineage report that silently omits the BI layer is more dangerous than no report, because it converts an unknown into a false confidence.

Every node in the output is a real path or a real object identifier. "Some dashboards use this" is not a result.

## Halt conditions

- **The dependency graph is incomplete because models reference each other by hardcoded table name** rather than through the framework's reference function. Report the hardcoded references as findings and mark the trace `PARTIAL` — do not present a partial graph as complete.
- **The BI/consumption layer is unreachable** (no API access, no exported model definitions). Report `PARTIAL — consumption layer not traced` and name what access would settle it. Never imply zero dashboards because none were visible.
- **Reverse-ETL / export destinations unknown.** Same rule: name the gap.

## When to run

- Before renaming, deleting, or changing the meaning of any model or column.
- Before a backfill, to enumerate who must be notified and what must be refreshed after cutover.
- When a defect is found, to size its blast radius: how many live surfaces are serving the wrong number right now.
- When hunting cost: models with no downstream consumer that still run on a schedule.
- After an upstream contract change flagged by `contract-diff`.

## Procedure

### 1. Fix the starting node and the direction

- **Downstream** (impact) — who reads this. The default for any change.
- **Upstream** (provenance) — what this is derived from. The default when a number is disputed.
- **Column-level** where the framework supports it; otherwise model-level, and say which was used. Model-level lineage over-reports (every consumer of the model, not just of the column) — that is the safe direction to err, but state it.

### 2. Walk the in-repo graph

Use the transformation framework's own dependency graph, built from its reference function. Record for each node: path, layer, materialization, schedule.

If any model reaches another by hardcoded table name, that edge is invisible to the graph. Grep for the physical table name across the repo to find them, and list every hardcoded reference found — each is both a lineage gap and a finding for `@analytics-engineer`.

**Name each node the way its own system names it** — the model's path as the framework refers to it, the dashboard by its title *and* its id, the export by its job name. A lineage report that renames things into house vocabulary cannot be acted on: the person who has to repoint a consumer searches for the string their tool shows them.

### 3. Cross the repo boundary — the part that is usually skipped

The graph stops at the warehouse. The consumers do not. Enumerate, per destination, and mark each `traced` or `NOT TRACED`:

| Destination | How to enumerate | Typical gap |
|---|---|---|
| BI dashboards / reports | the tool's API or exported definitions; grep the physical table name in exported model files | dashboards built on ad-hoc SQL rather than a governed model |
| Reverse-ETL / operational syncs | sync configs in the repo or the vendor's job list | a sync nobody remembers configuring |
| Scheduled exports / file drops | the orchestrator's export tasks, plus any storage bucket write | partner file drops with an external contract |
| Notebooks / ad-hoc analysis | grep the analysis repo for the table name | analyst laptops — genuinely untraceable; say so |
| Applications reading the warehouse | grep the application repos | an app treating a mart as an API |

### 4. Find orphans in both directions

- **Downstream orphans** — models with no consumer of any kind, still on a schedule. Each is a cost and a maintenance liability. Report with its schedule and its last-run cost if the platform records it.
- **Upstream orphans** — sources declared but referenced by nothing, and columns selected through several layers but never read at the end. These are the free deletions.
- **Unreachable** — a model whose upstream no longer exists (it runs on a stale table, or it fails silently and nobody noticed).

### 5. Report

```
## lineage-trace — <node> — <date>

Direction:  downstream | upstream | both
Granularity: column | model
Completeness: COMPLETE | PARTIAL — <what was not traced and what access would settle it>

### Downstream (impact)
| Consumer | Kind | Path / identifier | Depth | Live? |
|----------|------|-------------------|-------|-------|

Totals: <n> models · <n> dashboards · <n> exports · <n> syncs · <n> apps

### Upstream (provenance)
| Source | Kind | Path | Depth |
|--------|------|------|-------|

### Lineage gaps
| Gap | Why invisible | Finding for |
|-----|---------------|-------------|
| hardcoded reference at <path:line> | bypasses the reference function | @analytics-engineer |

### Orphans
| Node | Kind | Schedule | Last cost | Recommendation |
|------|------|----------|-----------|----------------|
```

## Inputs

- The transformation framework's dependency graph (built, current).
- Read access to the BI tool's model/dashboard definitions, if it is to be traced.
- The list of reverse-ETL and export destinations.

## Outputs

- The report block above, pasted into the consuming command's ledger.
- A notification list for `/backfill-plan` — the named humans or teams behind each live consumer.
- A deletion candidate list for `warehouse-scan-audit` to cost.

## False positives / gotchas

- **Treating model-level lineage as column-level.** It over-reports consumers; that is safe for change impact and misleading for "is this column used". Say which you ran.
- **Assuming the BI tool's own lineage feature is complete.** Most trace governed models and miss dashboards built on ad-hoc SQL. Grep the physical table name as a second pass.
- **Reporting an orphan without checking access logs.** A model with no graph edge may still be queried directly by humans. Check the platform's query history for the table name before recommending deletion.
- **A view chain that looks shallow.** Views compose; a two-hop graph can be a twelve-table scan. Depth in the graph is not depth in the query.
- **Deleting an "orphan" that a partner export reads monthly.** Monthly jobs are invisible in a 7-day query-history window. Widen the window to at least one full billing/reporting cycle.

## Related

### Skills
- `contract-diff` — whether the change is breaking for the consumers this skill enumerated.
- `warehouse-scan-audit` — costs the orphans this skill finds.
- `grain-probe` — whether the node itself is sound.

### Agents
- `@analytics-engineer` — owns the hardcoded references this skill reports as lineage gaps.
- `@warehouse-modeler` — owns deprecation sequencing (ship replacement → repoint → remove).

### Commands
- `/backfill-plan` — requires this skill's consumer list.
- `/audit-data-model` — uses it for blast radius on every finding.

### Patterns
- `ai/patterns/transformation-layers.md`
- `ai/patterns/data-contract.md`
