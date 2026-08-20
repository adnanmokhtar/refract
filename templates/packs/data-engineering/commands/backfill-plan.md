---
description: Plan a safe backfill or reprocess of a warehouse model — bounded scope, shadow target, cost and runtime estimate, validation against the live table, cutover, and rollback. Read-only by default; produces a plan and a ledger, never an in-place overwrite.
kind: command
pack: data-engineering
---

# /backfill-plan <model> [--from <date>] [--to <date>] [--reason "<why>"]

Backfills are the most dangerous routine operation in a warehouse. They rewrite history, they run at a scale nothing else does, and the failure mode is silent: the numbers change and nobody knows which run produced them. This command produces the plan — scope, target, cost, validation, cutover, rollback — before anything is written.

## When to use / NOT to use

- USE: a bug in a model was fixed and history must be restated; a source system corrected past data; a new column must be populated for existing rows; a late-arriving batch fell outside the incremental lookback window; a model's grain or key changed.
- NOT: the normal incremental run catching up a day or two — that is the schedule, not a backfill.
- NOT: a one-off analytical query over history — that is a query, and it writes nothing.
- NOT: reprocessing to fix an ingestion/movement defect — fix the pipeline first via the data-pipeline signal's `/audit-pipeline`; a backfill through a broken loader reproduces the corruption at scale.

## Phases applied

1-3 + 4 (the plan is the generated artifact) + 6. **Phase 5 (Update) is deliberately not executed by this command** — it plans and validates; the operator executes the cutover.

## The Premise (read this first, internalize, do not deviate)

**In-place overwrite is forbidden.** The backfill writes to a shadow target — a separate table, a versioned dataset, or an isolated partition set. The live table changes only at a single cutover step that is reversible. A plan that mutates the live table is rejected outright, whatever the urgency.

**Scope is bounded before cost is estimated, and cost is estimated before anything runs.** "Reprocess everything" is not a scope. Name the partition range, the row count, the bytes scanned, and the money. A backfill with no cost estimate is an unbounded spend authorised by nobody.

**The old numbers are evidence.** Snapshot the live table's aggregate totals per period BEFORE the backfill. Without the before-picture there is no way to explain what changed, and "the numbers moved" becomes an unanswerable question from finance.

**Halt conditions (refuse to produce an executable plan):**
- The model's loader is not proven idempotent for the target range — `@data-pipeline-reviewer` must clear it first.
- The restatement policy is undeclared: may a closed period's published numbers change? If they may not, the backfill needs a business decision, not an engineering plan.
- No rollback target exists (the prior version is not retained anywhere).
- The consumers are unenumerated — `lineage-trace` has not been run.
- The run window is not parameterised, so a past date cannot be reprocessed deterministically.

## Phase 1 — Understand

Confirm:
- **Model and range** — exact partitions/dates, not "recent history".
- **Reason** — bug fix, source correction, new column, late data, structural change. The reason determines whether the output should differ from the current table at all.
- **Expected delta** — should totals change, and roughly by how much? A backfill that "should change nothing" but does is the most informative failure available; state the expectation up front so the validation can catch it.
- **Restatement policy** — are the affected periods closed? Who signs off?
- **Freeze window** — will the normal schedule be paused for the affected model during the backfill? Concurrent normal runs and a backfill writing the same partitions is the classic double-write.

## Phase 2 — Organize

Split the range into **chunks** sized so that one chunk fits comfortably inside the platform's limits and can be retried alone. Chunk by the model's partition key, most-recent-first when the recent data matters more, oldest-first when the goal is a clean full history.

For each chunk record: partition range, estimated rows, estimated bytes scanned, estimated cost, estimated runtime.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/patterns/transformation-layers.md`, `ai/patterns/dimensional-model.md`.
- `.claude/rules/data-engineering-principles.md`.
- The model's incremental configuration: unique key, predicate, lookback window, full-refresh trigger.
- The platform's query-history statistics for this model's normal daily run — the per-chunk estimate is derived from measured daily cost multiplied by chunk size, not guessed.
- `lineage-trace` output: every downstream model, dashboard, export, and reverse-ETL sync that reads this table.

## Phase 4 — Generate (the plan)

The plan has six required parts. A plan missing any part is not executable.

1. **Scope** — the chunk table with per-chunk rows, bytes, cost, runtime, and the totals.
2. **Shadow target** — where the rebuilt data lands (a suffixed table, a versioned dataset, an isolated partition set), and how long it is retained after cutover.
3. **Freeze** — which scheduled runs are paused, for how long, and who re-enables them.
4. **Before-snapshot** — the query that captures live aggregate totals per period, and where its output is stored. Run it before the first chunk.
5. **Validation** — the comparisons that must pass before cutover (below).
6. **Cutover and rollback** — the single atomic step that swaps shadow into live (partition swap, table rename, view repoint), and the exact inverse step, with the retention window during which the inverse is possible.

## Phase 6 — Validate

Before cutover, all of these run against the shadow target and their output goes in the ledger:

- **`grain-probe`** on the shadow target. Duplicates mean the backfill itself fanned out.
- **Row-count comparison** per period, shadow versus live, with the delta and its explanation.
- **Measure-total comparison** per period for every headline measure, shadow versus live, against the expected delta stated in Phase 1. An unexpected change is a stop, not a note.
- **Referential completeness** — no fact rows orphaned by the rebuild.
- **Assertion suite** — the model's full assertion set runs against the shadow target and passes.
- **Spot reconciliation** — at least one period reconciled against the source system.
- **Idempotency proof** — reprocess one chunk twice into the shadow target; totals must not move.

### Backfill ledger — REQUIRED OUTPUT ARTIFACT (the plan is not approved until this table exists)

```
Chunk (range)     | Rows est. | Bytes est. | Cost est. | Runtime est. | Probe | Row Δ vs live | Measure Δ | Assertions | Status
2026-01 … 2026-03 | 41.2M     | 380 GB     | $1.90     | 22 min       | unique| +0.02%        | +$1,204   | 6/6 pass   | VALIDATED
```

Per-row `Status`:
- **VALIDATED** — every check above ran and passed, and the observed delta matches the expectation stated in Phase 1.
- **UNEXPLAINED-DELTA** — the numbers moved in a way Phase 1 did not predict. Stop. Investigate before cutover; this is the check earning its keep.
- **FAILED** — probe found duplicates, an assertion failed, or the double-run changed totals.

## Output format

```
## /backfill-plan — <model> — <date>

Reason:          <bug fix | source correction | new column | late data | structural change>
Range:           <from> → <to>   (<N> chunks)
Shadow target:   <path/name>     retained <N> days after cutover
Freeze:          <schedules paused>  by <owner>  for <window>
Expected delta:  <stated up front>

Total estimate:  <rows> rows · <bytes> scanned · <cost> · <runtime>
Consumers affected (lineage-trace): <N> models · <N> dashboards · <N> exports (named)

Backfill ledger: <the table above, verbatim>

Cutover step:   <the single atomic operation>
Rollback step:  <the exact inverse>  possible until <date>

Status: <see gate below>
```

### Closure gate — APPROVED-FOR-CUTOVER only when every ledger row is VALIDATED

- **`Status: APPROVED-FOR-CUTOVER`** — every chunk VALIDATED, the shadow target complete, the before-snapshot stored, the rollback step written and its retention window stated, and every affected consumer named and notified.
- **`Status: BLOCKED — unmet: <list>`** — any chunk UNEXPLAINED-DELTA or FAILED, or any halt condition still open. Name each and why.

This command never sets `COMPLETE` on its own. Cutover is an operator action; this plan authorises it and records the evidence.

## Hard rules

- **Never overwrite in place.** Shadow target, then one reversible cutover.
- **Never run a backfill while the model's normal schedule is live** on the same partitions.
- **Never skip the before-snapshot.** It is the only way to explain what moved.
- **An unexplained delta stops the run.** "It is probably the fix working" is not an explanation; find the rows.
- **Rollback must be possible for a stated window**, and the plan states the date it expires.
- **A backfill on a loader not proven idempotent is refused**, not attempted carefully.

## Failure modes

- Reprocessing "everything" because bounding the range felt like extra work; the bill arrives later.
- Backfilling into the live table over a weekend, with the only record of what changed being the absence of complaints.
- Cutover succeeds, downstream marts are not refreshed, and dashboards mix rebuilt and stale data for a week.
- The double-run idempotency check skipped because "it is a merge" — merges on the wrong key duplicate too.
- Rollback nominally possible, but the prior version's retention expired three days before anyone noticed the regression.
- Consumers notified after the fact; an external partner had already exported the old numbers.

## Related

- `@dag-reviewer` — the graph configuration that makes a re-run deterministic.
- `@analytics-engineer` — the incremental configuration and lookback window that determine whether a backfill was needed at all.
- `@warehouse-modeler` — the partitions and grain the rebuild must preserve.
- `grain-probe`, `lineage-trace`, `warehouse-scan-audit` — the executors.
- `/audit-pipeline` (data-pipeline signal) — clears the loader as idempotent before this plan is executable.
- `.claude/rules/data-engineering-principles.md`.
