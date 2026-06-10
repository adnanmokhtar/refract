---
name: data-pipeline-discipline
description: Data pipeline (ETL / batch / backfill / CDC / warehouse load) discipline
kind: rule
---

# Data pipeline (ETL / batch / backfill / CDC / warehouse load) discipline

## Hard rule

Every data pipeline — batch ETL, incremental load, CDC sink, backfill, warehouse hydration — MUST be IDEMPOTENT (re-running the same window produces the same result, never duplicates and never corrupts), CHECKPOINTED (a failure resumes from the last committed offset/watermark, NEVER forces a full expensive re-run), and INCREMENTAL where the source supports it (advance a watermark / high-water mark, never re-scan the whole table by default). Input MUST pass an explicit SCHEMA CONTRACT at the boundary; rows that violate it are QUARANTINED / DLQ'd with their reason — NEVER silently dropped and NEVER propagated downstream where they poison every consumer. Rows MUST be STREAMED at constant memory — loading the full source into a list/array is FORBIDDEN. A BACKFILL MUST be ISOLATED from live data (versioned / partitioned / shadow write) — it MUST NOT clobber current rows. Out-of-order / late data MUST be handled explicitly (lateness window + reprocess key), not dropped or double-counted. PII in lower environments (dev / staging copies, sample extracts) MUST be masked.

A pipeline bug is invisible until the warehouse is already wrong: duplicated revenue, a backfill that overwrote a month of live data, a silent schema drift that zeroed a column for three days. By the time a dashboard looks wrong, the corruption is N runs deep. The contract is the guard rail; idempotency is the recovery; the checkpoint is the cost ceiling.

## Must

- **Idempotent sink**: the load step is an UPSERT / MERGE keyed on a stable natural or surrogate business key, or a partition-replace ("delete the partition, write the partition") — NEVER a blind `INSERT` / append. Re-running the same window MUST converge to the same rows, not accumulate them. Prove it: run the window twice, assert row counts and aggregates are identical.
- **Checkpoint + resume**: the pipeline commits its progress (last watermark, last source offset, last completed partition) durably AFTER the sink commit, and on restart resumes from the committed point. A crash at 80% MUST resume at 80%, never restart from zero. Offset commit and data commit are ordered so a crash between them re-processes (at-least-once + idempotent sink), never skips (no at-most-once data loss).
- **Incremental by watermark**: pull only rows changed since the last high-water mark (`WHERE updated_at > :lastWatermark` / CDC log position / sequence id), ordered, and advance the watermark from the data actually read. Full-table reprocess is opt-in (explicit `--full` / declared rebuild), never the default path.
- **Explicit input schema contract**: every source has a declared schema (types, required fields, enums, ranges). Each record is validated at the boundary BEFORE transform. The contract version is pinned; a new/removed/retyped upstream field is detected, not absorbed silently.
- **Quarantine / DLQ bad rows**: a record that fails the contract is written to a dead-letter / quarantine sink WITH its raw payload + the rejection reason + the run id — never dropped, never `continue`'d into a void, never passed downstream. Good rows keep flowing; bad rows are triaged out-of-band.
- **Stream, never load-all**: source rows are read via a cursor / server-side stream / paged keyset loop and processed in bounded batches; memory is flat regardless of source size. The full extract is NEVER materialized into one in-memory collection before the transform.
- **Backfill isolation**: a backfill writes to a versioned / partitioned / shadow target (a dated partition, a `_backfill` table swapped atomically, a new dataset version) and is promoted only after validation. A backfill MUST NOT `UPDATE`/overwrite live rows in place. Live reads keep seeing current data until the swap.
- **Late / out-of-order data handling**: the pipeline declares a lateness window and an event-time vs. processing-time stance. Late records reprocess their owning window (re-aggregate the affected partition) rather than being dropped or appended as if fresh — so a record arriving an hour late is neither lost nor double-counted.
- **Data-quality assertions**: after load, assert invariants — row-count delta within expected bounds, no unexpected nulls in required columns, referential integrity to dimensions, freshness (max(updated_at) within SLA), uniqueness of the business key. A failed assertion HALTS promotion and alerts; it does not ship a silently-wrong dataset.
- **PII masked in lower envs**: any extract copied to dev / staging / a sample dataset has PII masked / tokenized / synthesized (see `<rules-path>/compliance`). Production PII never lands unmasked in a lower environment or an ad-hoc analyst extract.
- **Tenant scope preserved end-to-end**: in a multi-tenant source, `tenant_id` (or equivalent) travels with every row through extract, transform, and load, and partitions/keys the sink — a pipeline must not blend tenants in a shared aggregate (shares the spine with `<patterns-path>/bulk-import` and reporting).
- **Run provenance recorded**: each run logs `{ runId, source, window/watermark range, rowsRead, rowsWritten, rowsQuarantined, durationMs, status }` and writes a run record (see `<rules-path>/audit-log`) so a wrong number can be traced to the run that produced it.

## Must not

- Load with a blind `INSERT` / `append` / `COPY` into the live table on a re-runnable path — a retry duplicates every row in the window.
- Re-process the entire source table on every run when an `updated_at` / CDC cursor exists — cost + lock + lag blowup that grows with the table.
- Restart from row 0 / the beginning of the source after a mid-run failure because progress was never checkpointed — turns a 5-minute retry into a 6-hour re-run.
- Accept upstream rows with no schema validation — an added/renamed/retyped field then silently breaks a transform or writes nulls for days before anyone notices.
- `try/catch { continue }` (or filter out) a bad row with no DLQ — the row vanishes with no record, or worse, a malformed row flows downstream and corrupts every aggregate built on it.
- Run a backfill as an in-place `UPDATE` / `TRUNCATE`+reload against the live table — a bug or a wrong window overwrites current production data with no path back.
- `const rows = await source.fetchAll()` / read the whole extract into memory before transforming — OOM at scale.
- Drop late-arriving records (`if (event.ts < windowStart) return`) or append them as new — silent undercount or double-count in the affected window.
- Promote a freshly-loaded dataset with no post-load data-quality assertions — ship a silently-wrong table to every downstream consumer.
- Copy a production dump to staging / a notebook with PII intact.
- Strip `tenant_id` mid-pipeline / aggregate across tenants in a shared rollup.

## Should

- Wrap the extract/transform/load steps behind a project-internal `<Pipeline>` / `<Loader>` interface so watermark advance, checkpoint commit, contract validation, DLQ routing, and idempotent upsert are enforced in ONE place — feature code declares a pipeline spec (source, key, watermark column, schema, sink), not hand-rolled SQL per job.
- Make the sink a partition-replace where the grain allows ("delete WHERE partition = :p; insert the partition") so a re-run of a window is atomically idempotent without per-row merge cost.
- Orchestrate runs through the jobs/scheduler layer (see `<rules-path>/background-jobs`) with retries, backoff, and a DLQ for the whole run — the pipeline owns idempotency; the orchestrator owns retry/alert.
- Keep the watermark and the checkpoint in one durable record per pipeline so "where are we" is a single source of truth, queryable for lag/freshness alerting.
- Validate a backfill against the live data it will replace (row counts, aggregate parity within tolerance) BEFORE the partition swap; keep the prior version for rollback.
- Emit structured per-run metrics + lag/freshness gauges; alert on quarantine-rate spikes, watermark stall, row-count anomaly, and assertion failure.
- Pin the source contract version in the pipeline spec and fail loudly on drift, with a documented evolution path (additive-only, or an explicit migration).

## Review checklist (PRs touching pipelines / ETL / loaders / backfills / CDC sinks / warehouse loads)

- [ ] Sink is an idempotent upsert/merge/partition-replace keyed on a stable business key — NOT a blind insert/append. Cite the sink at `<path:line>`.
- [ ] Progress is checkpointed durably after the sink commit; restart resumes from it — no restart-from-zero. Cite the checkpoint at `<path:line>`.
- [ ] Default path is incremental on a watermark / CDC offset; full reprocess is explicit/opt-in. Cite the watermark advance at `<path:line>`.
- [ ] Input passes an explicit schema contract at the boundary; the contract version is pinned. Cite the validation at `<path:line>`.
- [ ] Bad rows are quarantined/DLQ'd with payload + reason + runId — never dropped, never propagated. Cite the DLQ write at `<path:line>`.
- [ ] Source is streamed at constant memory — no `fetchAll()` / load-all before transform.
- [ ] Backfill writes to a versioned/partitioned/shadow target and swaps atomically — never an in-place overwrite of live data.
- [ ] Late / out-of-order data has a declared lateness window + reprocess key — not dropped, not double-counted.
- [ ] Post-load data-quality assertions gate promotion (row-count delta, null checks, freshness, key uniqueness, referential integrity).
- [ ] PII is masked in any lower-env / sample extract.
- [ ] `tenant_id` is preserved end-to-end and keys/partitions the sink.
- [ ] Run provenance (runId, window, rows read/written/quarantined, status) is recorded.

## Anti-patterns

- **Blind-insert load** — `INSERT INTO fact_orders SELECT * FROM staging` on a retry-able job -> a retry double-loads the window -> revenue doubles in the warehouse. Upsert on the order key, or delete+replace the partition.
- **Full-table re-scan** — every run does `SELECT * FROM orders` and rebuilds the whole fact table because there's no `updated_at` cursor -> run time and source load grow linearly with history; eventually the run can't finish inside its window. Pull `WHERE updated_at > :watermark`.
- **Restart-from-zero** — the worker dies at 4M of 5M rows and the next run starts at row 0 because nothing was checkpointed -> the job never catches up. Commit the watermark/offset after each batch; resume from it.
- **Silent schema drift** — upstream renames `amount` to `amount_cents`; the transform reads `row.amount` -> `undefined` -> the column writes null for three days before a dashboard looks wrong. Validate against a pinned contract; fail on drift.
- **Swallowed bad row** — `try { transform(row) } catch { continue }` -> malformed rows vanish with no trace and the totals quietly under-count. Route to a DLQ with the raw payload + reason + runId.
- **Poison-row propagation** — a bad row passes validation-less and flows into an aggregate -> every metric built on that partition is wrong, and the corruption is now N joins deep. Quarantine at the boundary, before transform.
- **In-place backfill** — `UPDATE fact SET ... WHERE date BETWEEN ...` to "fix" history, run with a wrong window -> a month of live rows overwritten, no rollback. Backfill into a versioned/partitioned shadow target; validate; swap.
- **Load-all extract** — `const all = await source.fetchAll(); all.map(transform)` for a 50M-row table -> OOM. Stream a keyset/cursor loop in bounded batches.
- **Dropped late event** — `if (event.ts < windowStart) return` -> a record arriving 40 min late is silently lost and the hour undercounts. Declare a lateness window; reprocess the owning window.
- **Double-counted late event** — the same late record is appended as fresh into the current window AND already counted in its own -> the metric over-counts. Reprocess by event-time key, don't append by arrival.
- **No post-load assertion** — the load "succeeds" but wrote 0 rows (or 10x rows) due to a join fan-out; with no row-count/parity check it ships -> the dashboard is silently wrong. Assert invariants; halt promotion on failure.
- **PII in staging** — a prod dump restored to staging for debugging carries real emails / SSNs -> a lower-env breach is a production-PII breach. Mask on extract.

## Enforcement

- `<commands-path>/audit-pipeline.md` (slash: `/audit-pipeline`) — diagnoses a specific pipeline end-to-end from REAL source: the sink's idempotency, the checkpoint/resume path, incremental-vs-full, the schema contract + DLQ, the watermark + late-data stance, backfill isolation, streaming-vs-load-all, and PII in lower envs — cite-or-halt, never an assumed shape.
- `<agents-path>/data-pipeline-reviewer.md` — review gate hard-failing on non-idempotent loads, missing checkpoint/resume, missing schema contract, propagated bad rows, in-place backfills, full-table reprocess, dropped/double-counted late data, load-all-in-memory, missing data-quality assertions, and unmasked PII in lower envs.
- CI lint MUST flag a bare `INSERT` / `append` into a known fact/warehouse table in a pipeline path with no `ON CONFLICT` / `MERGE` / partition-replace (heuristic; flag for review).
- CI lint MUST flag `catch { continue }` / silent filtering in a transform loop with no DLQ write (AST heuristic; flag for review).
- CI lint MUST flag a `fetchAll()` / `.all()` collector feeding `.map()`/`.forEach()` in a pipeline module — pipelines stream.
- CI MUST assert every registered pipeline declares a watermark/offset source, a schema contract, a DLQ sink, and post-load assertions in its spec (config-shape check).
- TODO: `scripts/validate-pipeline-spec.sh` to walk pipeline specs and assert each declares an idempotent sink key, a checkpoint store, a contract version, a DLQ, and at least one post-load assertion before the pipeline is allowed to register.

## Cross-references

- `<patterns-path>/batch-pipeline.md` — watermark loop + idempotent upsert + checkpoint/resume + schema contract + DLQ + streaming + backfill isolation + data-quality assertions code shapes.
- `<patterns-path>/bulk-import` — shared spine (streaming + idempotent upsert + tenant scope + bad-row quarantine) for user-initiated imports; this rule is the scheduled/CDC/warehouse-load counterpart.
- `<rules-path>/background-jobs` — orchestration, retries, backoff, and run-level DLQ for the pipeline runs.
- `<rules-path>/compliance` — PII masking/tokenization for lower-env and sample extracts.
- `<rules-path>/audit-log` — per-run provenance so a wrong number is traceable to the run that produced it.
- `<rules-path>/reporting-export-discipline.md` — the downstream read side (replica, tenant scope, streaming) that consumes the tables this pipeline loads.
- Boundary: `mlops` (cataloged) owns MODEL lifecycle — training data, feature stores, model deploy/rollback; this pack owns DATA movement (ETL/batch/backfill/CDC/warehouse). `workflow-orchestration` (Temporal-style durable workflows) owns long-lived business processes; this pack owns data loads. A feature-engineering pipeline that feeds a model sits on the boundary — use this pack for the load discipline, `mlops` for the model contract.
- `<adr-path>/<NNN>-pipeline-load-strategy.md` — ADR pinning the load strategy (upsert vs. partition-replace), the watermark source, the lateness window, and the backfill/rollback contract.
