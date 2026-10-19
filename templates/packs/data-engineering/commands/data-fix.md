---
description: "Close data audit findings failing-first; re-scan the class."
kind: command
pack: data-engineering
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /data-fix [report-path | finding-id ... | --all] [--write-tests]

## The Premise (read this first, internalize, do not deviate)

**A data finding is closed when the oracle that proved it now passes, for every variant of its class, on a scratch target — and the detector that raised it goes quiet on the class. Proven, not asserted.** The input is the `## What to do next` list an `/audit-data-quality` run printed (pasted, or saved by the user to a path). Each item cites a `<file:line>`, a class id (`DE-<class>`), the detector § that raised it, and its V-number from [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Data engineering. This command does not discover defects and does not fix guesses: it turns a *reported* finding into a *reproduced* one, closes it at the root, and re-scans the whole class.

**The agent's job, per finding, in order:**
1. **Re-verify, then reproduce.** Refute the finding first ([`refute-before-report.md`](../../../snippets/refute-before-report.md) with [`precedents/data-engineering.md`](../../../snippets/precedents/data-engineering.md)). Then build the V-oracle on a **scratch target** — duckdb from the committed seeds, a throwaway container with the project's migrations, a target the user names — and watch it **FAIL** on current code.
2. **Fix at the root** in the project's own primitive (the table below).
3. **Run the same oracle again.** Green, every variant green, the precedent's control unchanged.
4. **RE-DETECT the class.** Re-run the owning detector's pre-flight: the patched site is quiet, and every remaining hit of that grep in the repo is fixed, Refuted with its gate, or listed as a follow-up.
5. **Run the project's suite** (`dbt build` on the scratch profile, the app's tests, the DAG import test).

**Where it runs.** In a git worktree (`git worktree add`) by default, or in the user's tree when they say so in this session. Never on a branch the user did not name; never a commit unless the repo's convention allows it (see Commit).

**The agent does NOT:**
- Fix a finding it has not reproduced. An Unconfirmed row is settled by its oracle first; a Refuted one is never patched.
- Run any oracle, `dbt run/build`, load, backfill, refresh, export or DAG against a shared or production target, or scan a per-byte warehouse without a dry run under the user's bound.
- "Fix" by hiding the class: `distinct` over duplicates, a wider lookback without a merge, a test downgraded to `warn`, a `where:` that excludes the bad rows, a reconciliation that only logs, a `try/except` around a failing load, a cap that truncates quietly, a larger `max_active_runs` timeout. Nor by editing a detector, a precedent or a test to go green.
- Fix the reported site and leave the class.
- Close a routed row (business, distributed-systems, backend, database, security, finops): those go to their owner's fix command when installed (`/business-fix`, `/ds-fix`, `/backend-fix`, `/db-fix`, `/security-fix`); without the owner pack, the row is closed here only when the user says so, tagged `<class> (owner pack not installed)`.

**The agent STOPS and asks the user before:**
- **Restating history** — a backfill, a full refresh, a re-run of closed periods, a snapshot rebuild. Route to `/backfill-plan` (shadow target, before-snapshot, cutover) and put the plan to the user.
- **A published shape change** — a contract version bump, a dropped or renamed column a reader uses, a new `deprecation_date`. Name the readers (`lineage-trace`) and the notice window.
- **An OLTP migration** — a trigger, a unique index on a populated table, a column type change. Route through `/add-migration` (database pack) or the project's migration process.
- **A policy** — a retention period, a masking policy, an erasure rule, the zone a rollup serves (business `report-scan` §8 owns *which* zone), a restatement policy. The finding names the decision; the user makes it.
- **An orchestration change with run-time effect** — `catchup`, `max_active_runs`, a schedule, a pool, pausing a DAG.
- **Deleting data** — erasing copies of personal data, dropping a snapshot's history, purging stored exports.

This command inherits the two invariants in [`templates/snippets/fix-bug-core.md`](../../../snippets/fix-bug-core.md): **failing test first** and the **sibling ledger** `N_found == N_fixed + N_explained + N_followup`. Here the failing test is an **oracle** from `proof-oracles.md` § Data engineering, and the sibling sweep is the owning detector's grep over the whole repo.

## Phases applied
All seven. Phase 4 is the per-finding loop. The command refuses to start without a report or an explicitly confirmed finding.

## When to use / NOT to use
- USE: after `/audit-data-quality` returns `NO-GO` or `GO-UNVERIFIED`; to close one finding by id (`/data-fix DE-IN-1@fct_events`); `--all` to work MUST → SHOULD → OPTIONAL; `--write-tests` to write the missing data tests the four-floor table lists (each proven by mutation first).
- NOT: with no report (run `/audit-data-quality`). Not to plan a restatement (`/backfill-plan`), to design a new model (`/add-data-model`), to review the model's shape (`/audit-data-model`), or for routed classes whose owner pack is installed.

## Phase 1 — Understand

### Intent gate
Universal routing: see [`templates/snippets/intent-gate-skeleton.md`](../../../snippets/intent-gate-skeleton.md). Then:

| The ask says | Route |
|---|---|
| "audit" / "find" / "are the pipelines healthy" | `/audit-data-quality`; this command closes findings, it does not find them |
| "reprocess March" / "restate history" | `/backfill-plan` |
| "add a model" | `/add-data-model` |
| a report, finding ids, "close the data findings", `--write-tests` | proceed |

**Refuse-to-run gate (mandatory).** Resolve the input to a concrete finding set before any edit:
- **A report.** The `/audit-data-quality` report pasted in this session, or the path the user saved it to; parse its `## What to do next` list ([`review-action-plan.md`](../../../snippets/review-action-plan.md) shape).
- **Finding ids.** Look each one up in that report.
- **An explicitly described, already-confirmed finding.** Accept it only when the user states the site, the class and the evidence; echo it back as one finding row.
- **None of these → HALT** and route to `/audit-data-quality`. Never improvise a finding list from a fresh scan.
- **`--write-tests`** reads the report's four-floor table; each `missing` or `cannot fail` cell becomes one finding row (DQ-1/2/4/5/6/7).

## Phase 2 — Organize

**Order.** MUST FIX first (BLOCKER, then HIGH), then SHOULD FIX, then OPTIONAL. Within a tier, the widest root first: a `dbt_project.yml` default by path, a shared macro, an export base class, a bucket helper, a CI step — before a single model. For each finding record before touching code: `<file:line>`, class, **the detector § that raised it** (RE-DETECT re-runs it), **its V-number**, **its root-cause primitive**, and whether it crosses a STOP line. A STOP finding is listed, put to the user, and the rest proceed.

| Class | Detector § | Oracle | Root-cause primitive (never the alternative) |
|---|---|---|---|
| IN-1/IN-3/IN-9 watermark, load clock, microbatch | `incremental-load-scan` §1/§3/§9 | V541, V542 | event-time filter `>=` with a lookback **and** a merge on the key; advance the watermark after the commit; microbatch `event_time`/`begin`/`batch_size`. Not a wider lookback alone |
| IN-2/IN-10 merge key, CDC landing | §2/§10 | V540, V543 | `unique_key` = the grain + `not_null`; `ON CONFLICT … DO UPDATE` / `MERGE`; an upsert sink keyed by PK + source position. Not `distinct` |
| IN-4 deletes | §4 | V543 | `hard_deletes: invalidate` / `new_record`; `when matched and op = 'd' then delete`; staging filters the delete flag |
| IN-5 dedup order | §5 | V544 | a total order in the window (`order by ts desc, seq desc, id`) |
| IN-6 schema drift | §6 | V545 | `on_schema_change: append_new_columns` or `fail`, by path in `dbt_project.yml` |
| IN-7/IN-8 overwrite scope, backfill shape | §7/§8 | V546, V550 | `partitionOverwriteMode=dynamic`, Delta `replaceWhere`, delete-then-insert of the partition in one transaction; backfills through `/backfill-plan` (STOP) |
| OR-1/OR-2/OR-7/OR-8 | `orchestration-scan` §1/§2/§7/§8 | V549 | the injected interval (`data_interval_start/end`, `context.partition_key`); a static `start_date`; I/O inside the callable; an explicit timetable; the AF3 names |
| OR-3/OR-5/OR-9 | §3/§5/§9 | V550, V540 | the write made idempotent first; `max_active_runs=1` / a pool only with the user (STOP); `BackfillPolicy` matched to the code |
| OR-4/OR-6 | §4/§6 | V551 | `trigger_rule` `all_success` (or a short-circuit) on the publish; sensor `timeout` + `mode="reschedule"` |
| DQ-1/DQ-2/DQ-5/DQ-8 | `data-test-scan` §1/§2/§5/§8 | V553 (mutation) | `unique` + `not_null` (or `unique_combination_of_columns`) at `error`; `accepted_values` covering the `CASE` members; `not_null` beside `relationships`; a unit test for the incremental branch. Not `severity: warn` |
| DQ-3 | §3 | V554 | `dbt build` (not `dbt run`) in CI with sources selected; no `|| true` |
| DQ-4/DQ-7 | §4/§7 | V555, V556 | `freshness` with `error_after` and `loaded_at_field`; a row-count test (`expect_table_row_count_to_be_between(min_value=1)`) |
| DQ-6/MV-3 | §6 / `derived-data-scan` §3 | V564 | a reconciliation that fails or marks stale (an equality test, a recompute check), not a log line |
| MV-1/MV-2/MV-4/MV-6 | `derived-data-scan` §1/§2/§4/§6 | V547, V548, V564 | recompute-and-replace a whole period; dirty markers from insert/update/delete triggers on every source column (+ a spec holding the lists equal); sub-day buckets for zone re-bucketing. Trigger and index changes are migrations (STOP) |
| MV-5 | §5 | V563 | `REFRESH … CONCURRENTLY` + a unique index on plain columns; a schedule; no `now()` in the definition |
| TB-1…TB-4 | §7–§10 | V552 | `(ts at time zone 'UTC') at time zone tz` on naive UTC (or `timestamptz`); half-open windows; named zones with zone tables loaded or app-side conversion. The zone choice is the user's (STOP) |
| EX-1/EX-2 | `extract-scan` §1/§2 | V560, V561 | keyset on `(created_at, id)` compared in SQL; one `REPEATABLE READ` read-only transaction; `chunkById` / `find_each` |
| EX-3/EX-4 | §3/§4 | V562 | refuse at the cap with a message; temp-then-rename publish; ISO-8601 with offset, decimals as strings, ids as text |
| PC-1/PC-3/PC-6 | `pii-copy-scan` §1/§3/§6 | V566, V567 | classification in YAML (`meta`, `policy_tags` + `persist_docs`); keyed HMAC from a managed key; masking policy type = column type. Policy values are the user's (STOP) |
| PC-2/PC-4/PC-5 | §2/§4/§5 | V565, V567 | the erasure job covers the copy (or the copy holds no identifier); a masking step in the restore; a lifecycle rule. Deleting data is STOP |
| SC-1…SC-4, SC-6 | `contract-diff` §1–§4, §6 | V557, V558, V552 | `contract: {enforced: true}` + data tests for uniqueness; a version with `deprecation_date`; an explicit column list; expand/contract with readers moved first (STOP); an aware landing type |
| LN-1…LN-4 | `lineage-trace` §1–§4 | V559 | `source()`/`ref()`; a staging model; an `exposures:` entry; retirement only with the owner (STOP) |
| CO-1…CO-4 | `warehouse-scan-audit` §1–§4 | V568 (dry run, the user's project) | a sargable range on the partition column; `require_partition_filter`; `incremental_predicates`; an incremental instead of a rebuild; a materialized middle link |
| GR-1…GR-4 | `grain-probe` §1–§4 | V569, V544 | the grain sentence (the user's/`@warehouse-modeler`'s); a join on the right side's key; Type 2 as-of predicates; a separator or `generate_surrogate_key` |

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Data-engineering-specific:
- The report being closed: its context map (lanes, versions, proof targets), the finding rows, the first-pass evidence.
- [`refute-before-report.md`](../../../snippets/refute-before-report.md), [`precedents/data-engineering.md`](../../../snippets/precedents/data-engineering.md), [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Data engineering (the harnesses and the class variants).
- The file holding the finding end to end, plus one sibling that does the same thing correctly (a model with a proper merge, the keyset export, the whole-day rollup) — the fix matches its shape.
- The project's data-test idiom (generic tests in YAML, singular tests, dbt-expectations, GX, Soda) — new tests match it; never a second idiom.
- `.claude/rules/data-engineering-principles.md`; `ai/patterns/data-quality-tests.md`, `data-contract.md`, `transformation-layers.md`.

## Phase 4 — Generate (the per-finding loop)

Run all steps for each finding in Phase-2 order. Do not move on until the current finding's closure row is complete.

### 1. Re-verify, then reproduce — the oracle FAILS on current code
**Re-verify first** through the seven gates. **Refuted** → record the gate and stop. **Unconfirmed** → run its oracle to promote or refute. **Finding** → reproduce.

**Reproduce the whole class on a scratch target** ([`proof-oracles.md`](../../../snippets/proof-oracles.md) § Data engineering, harnesses):
- **dbt:** copy the project into `$OUT`, write a duckdb `profiles.yml` there, `DO_NOT_TRACK=1 DBT_SEND_ANONYMOUS_USAGE_STATS=False DBT_ENGINE_SEND_ANONYMOUS_USAGE_STATS=false`; seed the edge rows the variant list names (a tie, a late row, an update after the window, a delete, a NULL key, an empty batch); run the model twice or plant the violating row; assert counts and checksums exactly.
- **In-app:** a throwaway container with the migrations; the real job, query or runner from its module; a writer thread for V560/V561/V563.
- **Airflow:** `AIRFLOW_HOME="$OUT/airflow"`; `task.execute(context)` for a past interval; `DagBag` import.
- **Warehouse:** dry run only, on the user's project, under their bound (V568).
- The test must fail **on the oracle's assertion**, not on setup; paste the failing line into the closure row. Name the test after its class (`fct_events.tie_row.v542.sql`, `sales-counter.replay.v547.spec.ts`). It stays in the repo as the regression guard only where the project keeps such tests; otherwise its recorded output goes in the closure row as `Probe (recorded)`.
- **`--write-tests` rows:** the new data test is itself the subject — plant the violating row in the scratch copy and show the new test red (V553) **before** writing it into the repo, then green on the real seeds.

**No fix until the oracle fails.** No harness and no scratch target → the finding stays Unconfirmed with the recipe written out.

### 2. Fix at the root
Apply the Phase-2 primitive in the project's idiom, at the widest root (the `dbt_project.yml` default, the macro, the base class). A new dependency (dbt package, library) stops the work until an existing primitive is ruled out. STOP items are escalated, not patched.

### 3. Post-patch validation
1. The original oracle passes. 2. Every class variant passes. 3. The precedent's control is unchanged (an append-only table still appends, the keyset export still pages, the whole-day replacement still replaces). 4. No new hazard: a merge key does not drop legitimate rows; a test at `error` does not fail on today's real seeds for a reason unrelated to the finding (if it does, that is a new finding — report it, do not loosen the test); a keyset does not skip ties. 5. Every number is labelled measured, with its target.

### 4. RE-DETECT the class
Re-run the owning detector's pre-flight (its `### N.` grep, and `model-graph.py` for dbt rows) on the patched tree. The patched `<file:line>` is quiet; each remaining hit for that § is fixed in this run, Refuted with its gate, or a follow-up with its own id. `N_found == N_fixed + N_explained + N_followup` must hold. A detector that still reports at the site means the patch moved the symptom: reopen.

### 5. Run the project's suite
`dbt build` on the scratch profile (models, tests, unit tests, contracts), the app's tests, `DagBag` imports, `ruff --select AIR` when the project uses it. A red suite is fixed or the patch is reverted.

### Commit (one finding = one commit, only where the repo allows it)
Read the convention first: recent `git log` subjects, a protected or PR-only branch, any no-commit rule in `CLAUDE.md` or `CONTRIBUTING`. Where allowed, `fix(data): <what drifted> — <finding id>` (e.g. `fix(data): fct_events dropped tie rows at the watermark — DE-IN-1`). Otherwise leave the change uncommitted in the worktree and say so.

## Phase 5 — Update
- Print the closure table and the escalations; append them to the report file only if the user saved one and asks.
- Remove every scratch target the run created (containers stopped and removed, `$OUT` left for the user to inspect or deleted on their word) and say so.

### Closure table (required artifact)
```
| Finding        | Class  | Oracle | Proof (file or recorded probe)                   | Result     | Control            | State                    | RE-DETECT              |
|----------------|--------|--------|--------------------------------------------------|------------|--------------------|--------------------------|------------------------|
| DE-IN-1@fct_ev | IN-1   | V542   | tests/fct_events_tie_row.sql (duckdb)            | fail→green | append model same  | worktree, uncommitted    | §1 quiet; 2 refuted §2 |
| DE-EX-1@act    | EX-1   | V560   | test/exports/activity.keyset.v560.spec.ts (pg)   | fail→green | orders export same | <sha> fix(data)          | 1a: 0 OFFSET in runners|
| DE-PC-2@snap   | PC-2   | V565   | probe recorded (duckdb, synthetic subject)       | fail       | —                  | escalated: delete history| —                      |
```
A finding with no proof row, or a RE-DETECT that is not quiet on the class, is **not** closed.

## Phase 6 — Validate
- Each closed finding: a failing-first proof, every variant green, the control unchanged, a quiet RE-DETECT, a balanced sibling ledger, a green suite.
- **Re-run `/audit-data-quality` on the touched scope.** The verdict must not regress; each first-pass finding no longer reproduces at its site.
- Nothing was closed by `distinct`, a downgraded test, a widened filter, a swallowed error or an edited detector; every STOP item was escalated.
- No production or shared target was touched; every container started was removed.

## Phase 7 — Improve
- `/learn-from-task`: each closed class and the primitive that closed it.
- A class seen in two audits gets a mechanical gate the user approves: `dbt build` in CI, `+on_schema_change: fail`, `require_partition_filter`, a reconciliation test per rollup, `ruff --select AIR`, a snapshot erasure macro.

## Output format
```
## /data-fix — <N closed · M uncommitted · E escalated · K deferred>
Input:  /audit-data-quality report (pasted | <path>)  (findings: <total>; routed to owner packs: <r>)
Order:  MUST FIX (<c>) → SHOULD FIX (<m>) → OPTIONAL (<l>)
Closure table: (Phase 5)
Escalated (STOP — decision owed):
  - DE-PC-2@customers_snapshot  erase the subject's history from 3 snapshot versions — approve the erasure macro over snapshots?
  - DE-SC-4@orders.legacy_status  expand/contract: move stg_orders + the connector first; drop in the next release — approve the sequence?
Scratch targets: duckdb $OUT/scratch.duckdb · postgres container de-fix-41 (removed)
Re-audit: /audit-data-quality on touched scope → verdict <was → now>, no regression
Status: COMPLETE | INCOMPLETE  (COMPLETE only when every MUST-FIX finding is closed or escalated and the re-audit did not regress)
```

## What to do next — required closing section
Every run ends with `## What to do next`: the remaining work as ONE ordered, numbered to-do. **MUST FIX** (open or escalated BLOCKER and HIGH), then **SHOULD FIX**, then **OPTIONAL**. Each step carries `<file:line>`, the **Fix**, and the **Verify** (the V-number). An escalated item names the decision owed: the restatement, the contract version, the migration, the policy value, the deletion. The closing steps: re-run `/audit-data-quality`, `/learn-from-task`, then ship or open the PR. A fully closed run collapses to one line. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes
- **Fixing a refuted finding.** Churn that breaks working pipelines. Re-verify first.
- **A fix with no failing oracle first.** A replay test that passes before the fix proves nothing; it goes back to the verifier.
- **Toy proof.** A seed with no tie, no late row, no delete, no DST day.
- **Symptom fixes.** `distinct`, `severity: warn`, a `where:` that hides the violation, a lookback widened without a merge, a reconciliation that logs.
- **The instance fixed, not the class.** One model's `on_schema_change` set while the path default is still `ignore`; one runner moved to keyset while the base class still pages by OFFSET.
- **A STOP line crossed quietly.** A full refresh, a backfill, a dropped column, a deleted snapshot history shipped as "just the fix".
- **Production touched.** A default profile, a live connector, a warehouse scan with no dry run.

## Related

### Sibling commands
- `/audit-data-quality`: the producer; without its report the refuse-to-run gate halts.
- `/backfill-plan`: every restatement this command escalates. `/add-data-model`: new models. `/audit-data-model`: grain and shape.
- `/add-migration` (database pack, when installed): every OLTP schema change. Owner fix commands for routed rows: `/business-fix`, `/ds-fix`, `/backend-fix`, `/db-fix`, `/security-fix` (each when installed).
- `/fix-bug`: the general discipline this command specialises ([`fix-bug-core.md`](../../../snippets/fix-bug-core.md)).

### Detector skills (re-run for RE-DETECT; same pack)
`incremental-load-scan` (+ `scripts/model-graph.py`) · `orchestration-scan` · `data-test-scan` · `derived-data-scan` · `extract-scan` · `pii-copy-scan` · `contract-diff` · `lineage-trace` · `warehouse-scan-audit` · `grain-probe`.

### Shared contracts
[`refute-before-report.md`](../../../snippets/refute-before-report.md) · [`precedents/data-engineering.md`](../../../snippets/precedents/data-engineering.md) · [`proof-oracles.md`](../../../snippets/proof-oracles.md) · [`fix-bug-core.md`](../../../snippets/fix-bug-core.md) · [`review-action-plan.md`](../../../snippets/review-action-plan.md)
