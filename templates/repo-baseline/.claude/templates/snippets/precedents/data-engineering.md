# Precedents — Data engineering (loads and increments, orchestrators, data tests, table contracts, lineage, derived data and time buckets, extracts, analytical copies of personal data, warehouse SQL cost, grain)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **data-engineering** class: a load that writes a source row twice or never, an
orchestrated run that is not bounded by its interval, a data test that cannot fail or never runs, a
published table that changes shape under its readers, a model graph with hidden edges, a rollup,
materialized view or snapshot that drifts from its source, bucket SQL that does not implement the
declared zone, an export or dump that is not a faithful copy, personal data copied where erasure and
access control do not reach, pipeline SQL that scans more than it reads, and a model whose grain is
not what it claims. The oracles that prove them are in [`proof-oracles.md`](../proof-oracles.md)
§ Data engineering (V540–V569). The detectors are `incremental-load-scan` (IN §1–§10),
`orchestration-scan` (OR §1–§9), `data-test-scan` (DQ §1–§8), `derived-data-scan` (MV §1–§6,
TB §7–§10), `extract-scan` (EX §1–§4), `pii-copy-scan` (PC §1–§6), `contract-diff` (SC §1–§6),
`lineage-trace` (LN §1–§4), `warehouse-scan-audit` (CO §1–§5) and `grain-probe` (GR §1–§4)
(data-engineering pack); the dbt lanes read `incremental-load-scan/scripts/model-graph.py`. They are
run by `/audit-data-quality` and closed by `/data-fix`. The judges, in refute mode, are
`@data-quality-auditor` (DQ, MV, TB, EX, PC rows), `@dag-reviewer` (OR rows) and `@warehouse-modeler`
(SC, CO, GR, IN and LN rows — `@analytics-engineer` writes models and is not a judge); every BLOCKER
and HIGH a run keeps goes once more to `@verifier` mode `refute`.

**Data engineering owns the derived copy; other packs own the number, the table, the message and the
schedule.** A neighbour that sees the same `file:line` lists it as corroboration, deduped by
`file:line`; without the owner's pack the row is tagged `<class> (owner pack <x> not installed)` and
listed, never graded as the owner would grade it. The splits:
- a reported number (fan-out in a report's `SUM`, a metric defined twice, exclusions, currency, ratio
  SQL, books reconciliation, which zone and week start a business day uses) is business
  `report-scan` §1–§9; this pack owns whether the rollup and the bucket SQL implement the declared
  zone and stay equal to their source;
- deep-OFFSET cost, a non-unique sort key on a paged API read, unbounded reads, OLTP timestamp storage,
  PII storage, retention and erasure in the OLTP tables, and an application's N-1 migration are
  database `query-shape-scan` §1/§2/§8, `schema-integrity-scan` §5/§10 and `migration-safety` §4;
- message consumers, the outbox, CDC *consumers* in application code and gap-blind event cursors are
  distributed-systems `messaging-scan` §1–§3 and `dual-write-scan` §1–§6; event and message schema
  compatibility is `event-contract-scan`;
- an application scheduler's overlap, misfire and zone are backend `job-lifecycle-scan` §4–§6; API
  wire formats are backend `wire-format-scan`;
- CSV formula injection, PII in logs and who may export are security; whole-file export buffering is
  performance; warehouse budgets, `maximum_bytes_billed` and auto-suspend are finops.

## The claim, restated

§ 1 of the protocol takes this shape here. Every data-engineering claim names **the copy and its
source**, not only the code:

> Under **[the effective config, the orchestrator version, the declared grain or zone, the test's
> severity — each with the file it came from, or `UNDECLARED`]**, **[the run: a scheduled load, a
> retry, a backfill of a past interval, a rollup pass, an export, a dump, an erasure request]**
> executing **[the model, task, statement or mapper at file:line]** leaves **[the target table,
> rollup, view, snapshot, file or test result]** **[with a row doubled, lost, stale, shifted,
> unmasked, or a test green]** when **[the source row: a tie on the watermark, a late row, an
> update after the window, a delete, a NULL key, a row inserted mid-export, a 22:30Z row, an erased
> subject, a violating row]** arrives, proven by **[V-number, family]**.

**Two parts, refuted separately.** Part A says *the copy is real and consumed*: a scheduled job,
dbt job, DAG, connector or export writes it, and an exposure, a screen, an export, a downstream model
or a partner reads it. Part B says *the mechanism breaks it for a source row that occurs*. A
candidate whose effective config was not read (an incremental "without a key" whose key is set in
`dbt_project.yml`, a DAG verdict without the Airflow pin) is Refuted at Part A until the value and its
source are printed.

**The proof rule.** Static two-ended facts pass gate 6 with both ends cited: the effective config
value and the source behaviour that makes it wrong; the trigger's column list and the rollup's source
columns; the erasure job's table list and the derived table that carries the identifier; the
migration's dropped column and the extract that reads it. Behaviour classes (replay, late rows,
ties, dedup order, overwrite scope, bucket arithmetic on DST days, paging under concurrent writes,
a test that must go red) need the oracle red on a scratch target (duckdb, a container, a rolled-back
transaction). Without either the row is **Unconfirmed** with the oracle written out.

## Reading the seven gates for data engineering

| Gate | Data engineering |
|---|---|
| 1 Reachability | a dbt job in CI/cron/dbt Cloud, a deployed DAG, asset or flow, a Spark job, a scheduled application writer, a connector, an export runner, a dump script that runs, an erasure job; a one-off backfill that already ran, a paused-forever DAG and `analyses/` fail here |
| 2 Trigger | the source row occurs: a tie at the watermark's precision, a row later than the lookback, an update after the window, a hard delete, a NULL key, a write during the export, a row at local midnight or on a DST day, a subject who asks for erasure |
| 3 Version | dbt (`require-dbt-version` or the `dbt-core` pin; ≤ 1.8 vs ≥ 1.9 snapshot flags), the adapter, Airflow 2 vs 3, Dagster and Prefect majors, Spark 3 vs 4, Debezium < 3.2 vs ≥ 3.2, the Postgres/MySQL engine; `UNREAD` without a pin |
| 4 Existing control | the effective config (model → properties YAML → `dbt_project.yml` → default), a merge on the grain key, a lookback, a delete-then-insert of the partition in one transaction, a total order in the dedup window, a reconciliation job that fails or marks stale, a trigger list held equal to the fact columns by a spec, keyset paging compared in SQL, a `REPEATABLE READ` snapshot, a masking policy, a dry-run bound |
| 5 Impact | a consumed table, export, dashboard or partner file with a row doubled, lost, stale or shifted; a test that cannot go red on the class it names; personal data outside the erasure path; a measured scan cost. Hygiene with none of these is Hardening (§ 41) |
| 6 Proof | the two-ended static fact, or the V-oracle red on a scratch target |
| 7 Environment | the adapter and engine the project deploys, the zones its tenants use, the orchestrator the repo pins, the destinations its exports reach |

## Loads and increments (IN)

- **§ 1.** **An append-only immutable event table with no `unique_key`.** `append` does not deduplicate by design; an event that never updates, deduplicated downstream by an event id, is not IN-2. *Flips back:* the source has `updated_at`, a status column or a CDC op column, or nothing downstream deduplicates.
- **§ 2.** **A strict `>` watermark with a lookback window and a merge on the key.** The lookback re-reads the boundary and the merge absorbs the overlap. *Flips back:* no merge (the lookback re-appends), or the lookback is shorter than the source's documented arrival window.
- **§ 5.** **`on_schema_change` unset on a `view` or `table` model.** Both rebuild every run; the setting only applies to incrementals.
- **§ 6.** **A `table` or `view` model with no `is_incremental()` block.** Not an incremental; nothing to filter.
- **§ 7.** **A microbatch model with no `is_incremental()` filter.** dbt filters each `ref()` by `event_time` per batch.
- **§ 8.** **`insert_overwrite` with no `unique_key`.** Partition replacement is the dedup.
- **§ 9.** **`full_refresh: false` on a huge incremental.** Recommended: it stops an accidental full rebuild of an unrecoverable history.
- **§ 15.** **`dropDuplicates` / `distinct` on full-row duplicates.** Deterministic in effect: every duplicate is identical.
- **§ 16.** **`hard_deletes: ignore` (or no hard-delete flag) for a source that never hard-deletes.** A soft-delete column the staging model filters, or an append-only source, needs no delete propagation. *Flips back:* any erasure, admin delete or retention purge touches the source table.
- **§ 18.** **`tombstones.on.delete=false` when the topic is not compacted and the sink applies `op=d` itself.** The tombstone exists for log compaction; the delete still arrives as an event.
- **§ 28.** **Delta `replaceWhere` or a Hive serde table.** The overwrite is already partition-scoped.
- **§ 37.** **A snapshot with `strategy: check` when the source has no reliable `updated_at`.** The documented choice for that source. *Flips back:* `check_cols: all` includes audit columns that change on every load (a version opens per run).

## Orchestrators (OR)

- **§ 13.** **`datetime.now()` in a task for logging, a temp name or a run label.** Not a data window. *Flips back:* it selects rows, names a partition or bounds a query.
- **§ 14.** **No `catchup=` on an Airflow 3 DAG.** It matches the new default `False`. *Flips back:* the team relies on catchup for gaps (the README or a runbook says so), or the repo pins Airflow 2.

Cleanup and notification tasks with `trigger_rule="all_done"` are not OR-4: they publish nothing. A
publish task is.

## Data tests (DQ)

- **§ 3.** **`severity: warn` or a non-blocking check on an advisory or statistical test.** A distribution or volume band at warn routes to the owner. *Flips back:* a primary-key, foreign-key or contract-critical test.
- **§ 4.** **A test `where:` on a rolling window of a huge table.** Cost-bounded by design. *Flips back:* nothing covers the full table, or the window can be empty on a quiet day.
- **§ 10.** **`relationships` passing NULLs.** FK semantics: an optional relation. *Flips back:* the column is business-mandatory and has no `not_null`.
- **§ 11.** **An unenforced PK/FK with `warn_unenforced: false` as an optimizer hint** when a data test also covers uniqueness. *Flips back:* no data test covers it and the adapter keeps the constraint as metadata.
- **§ 12.** **`mostly < 1` / `catch_exceptions` on sampled, noisy, non-key columns.** *Flips back:* the column is a key or a money amount.

`freshness: null` on a static seed or reference table, and a separate scheduled job that runs the
tests (cited), are not DQ-4 / DQ-3.

## Derived data, rollups and materialized views (MV)

- **§ 17.** **An insert-only counter trigger on an append-only source** whose UPDATE and DELETE are revoked or refused by a trigger. Nothing can change behind the counter. *Flips back:* any path (admin, erasure, retention purge, `TRUNCATE`) can update or delete the source.
- **§ 19.** **`count = count + 1` in the same transaction as the source write.** A retry replays both or neither. *Flips back:* the increment runs in a job, a consumer or an `after_commit` hook separate from the source write.
- **§ 20.** **`count = count + 1` in a job guarded by a processed-events table with a unique key in the same transaction; or a find-then-insert upsert behind a unique `(tenant, day)` constraint.** The loser of a race fails on the constraint and is retried; a replay is a no-op. (A real NestJS + MikroORM repo's tenant-usage processor.) *Flips back:* the guard table and the increment commit separately, or the constraint is missing in the migrations.
- **§ 21.** **UTC-day facts beside sub-day buckets** (15-minute quarters with `date_bin`) — any tenant zone re-buckets from the quarters; or a single-zone product with the zone documented. *Flips back:* a tenant-zone reader sums UTC-day rows directly.
- **§ 22.** **A rollup that is a full recompute, or a whole-day replacement, from the source each pass** needs no separate reconciliation; a doubled pass is harmless. (The same repo also reconciles nightly and marks disagreeing days stale.) *Flips back:* the pass recomputes a window shorter than the period in which the source still changes (§ 38 applies to closed periods).
- **§ 25.** **A non-concurrent `REFRESH MATERIALIZED VIEW` off-hours on a small view**, or the first refresh after `WITH NO DATA` (which cannot be concurrent). *Flips back:* the refresh runs while a request path reads the view.
- **§ 26.** **`now()` inside a materialized view** when the refresh cadence is finer than the window it bounds and the staleness is documented. *Flips back:* the window is a day and the refresh is weekly, or the view is read as live.
- **§ 38.** **A closed-period snapshot** (a nightly performance history for yesterday) — point-in-time by design. *Flips back:* a screen, an export or an API presents it as current truth.
- **§ 40.** **A materialized view refresh managed outside the repo** (pg_cron, a DBA runbook, a managed scheduler). Ask; never report "never refreshed" as fact.

A trigger column list held equal to the fact columns by a spec (the spec names both lists) is the
MV-4 control. A nightly reconcile that marks disagreeing days stale and counts a failed unit is the
MV-3 control; one that only logs is not.

## Time buckets (TB)

- **§ 27.** **`ts AT TIME ZONE 'UTC' AT TIME ZONE tz` on a naive column that holds UTC.** The correct double form: the first conversion attaches UTC, the second converts. One conversion on a naive column is TB-1.
- **§ 29.** **`BETWEEN` on `date` columns.** Discrete; both ends inclusive is the intent. *Flips back:* the column is a timestamp or the bound carries a time.

A numeric offset on a zone with no DST, documented (`+03:00` for a Riyadh-only product), is not
TB-4. `CONVERT_TZ` with numeric offsets (`'+00:00','+03:00'`) needs no zone tables and is not TB-3.

## Extracts and exports (EX)

- **§ 30.** **OFFSET paging inside a `REPEATABLE READ` snapshot, over an immutable partition, or bounded by `id <= :max_id` with a unique order; keyset on `(created_at, id)` compared in SQL.** (The same repo's orders export.) *Flips back:* the bound is read but the pages run in separate transactions, or the order is not unique.
- **§ 39.** **An export ceiling that refuses with a message instead of truncating** (the same repo's export-size guard). Not EX-3.

A dump of a quiescent source (maintenance mode, a replica stopped at an LSN) is not EX-2. A header
row that states the zone (`created_at (UTC)`) and ISO-8601 instants with `Z` are not EX-4.

## Personal data in analytical copies (PC)

- **§ 31.** **A PII column already pseudonymised with a keyed HMAC** (key in a KMS, output still treated as personal data under the access and erasure rules). Not PC-3.
- **§ 32.** **Erased subjects still in backups that are on rotation and never restored into production without re-applying erasures** — "beyond use". Not PC-2.
- **§ 33.** **A hash used only as an internal join key**, never shared, exported or labelled anonymous. Not PC-3. *Flips back:* the column is named `anon_*`, sent to a third party or published.
- **§ 34.** **PII in an export that is the data-subject access response for that subject, or the controller exporting its own customer list to its own destination** (the same repo's merchant-initiated sheet push). Not PC-5. *Flips back:* the destination is shared with a third party or has no access control.

Synthetic seeds generated by a faker, and a lower environment restored through a masking step
(`pg_anonymizer`, a masking view, a `--exclude-table-data` list), are not PC-4.

## Warehouse SQL cost (CO)

- **§ 35.** **No `require_partition_filter` on small tables.** Below the size where a full scan costs more than a planning step, the guard is noise. *Flips back:* the table grows with events or time.
- **§ 23.** **`SELECT *` in a staging passthrough, or `select * from final` as the last CTE statement**; on a row-store engine over a narrow view. Not SC-3 / CO-4.

## Lineage (LN)

- **§ 24.** **`from information_schema.*`, `{{ this }}`, `{{ source(...) }}` resolved by a macro, or a CTE name** in a dbt model. Not a lineage bypass (LN-1).

A source declared for a non-dbt reader (an export job, a reverse-ETL sync cited by file) is not LN-4.
A small project with two layers is not LN-2.

## Contracts and grain (SC, GR)

- **§ 36.** **BACKWARD (non-transitive) registry compatibility for latest-only consumers.** Routed to distributed-systems `event-contract-scan`; listed here for corroboration only.

A pre-release model (no exposure, no `access: public`, no reader outside the project) changing shape
is not SC-2. A calendar spine cross-joined to a dimension is not GR-2. A composite key compared as a
tuple, or concatenated with a separator that cannot occur in the values, is not GR-4.

## Posting rules (data engineering)

- **§ 41.** Hygiene with no consumed copy affected is **Hardening**: a staging-only model with no grain test, a `SELECT *` on a row-store view, a warn-level advisory test, an orphan model with no schedule. NITs are capped at 5 per report, each with its site.
- **§ 42.** Every IN, SC, CO and GR row carries the effective config value **and where it came from**; every OR row the orchestrator version and its pin; every DQ row the test's effective severity and source; every MV and TB row the source columns and the declared zone (or `UNDECLARED`); every EX row the paging key and the transaction boundary; every PC row the column, the classification found (or none) and the erasure path read.
- **§ 43.** One root cause at N sites is one finding with N sites: one `+on_schema_change` missing in `dbt_project.yml`, one `+severity: warn` on a path, one export base class paging by OFFSET, one bucket helper with a single `AT TIME ZONE`.
- **§ 44.** **Decisions are not code fixes.** A restatement of a closed period, a retention period, a masking policy, the zone a rollup serves, a contract version bump, a backfill of history: the finding names the decision and stops; `/data-fix` asks before writing it.
- **§ 45.** **Never against production.** Every oracle runs on duckdb, a container, a rolled-back transaction or a target the user names; a warehouse query that would scan above the stated bound without a dry-run estimate is `NOT-RUN`, never "probably fine".

## Rationalizations to reject (data engineering)

**Wrongly accepting "correct":**
- "The model has a `unique_key`." In which file — and is the effective strategy `append`, which ignores it (§ 1, § 8)?
- "The tests pass in CI." Does CI run `dbt build` or only `dbt run`, and is the key test at `error` (§ 3)?
- "The rollup is reconciled." Does the reconciliation fail, mark stale, or only log (§ 22)?
- "The export is sorted." By a unique key, compared in SQL, inside one snapshot (§ 30)?
- "The DAG is idempotent." Run it for last March: does it read last March (§ 13)?
- "PII is masked in the warehouse." Is the policy tag persisted to the column, and is the snapshot masked too (§ 31)?

**Wrongly flagging a defect:**
- "This incremental has no key." Is the source append-only and deduplicated downstream (§ 1)?
- "This test is only a warning." Is it advisory (§ 3)?
- "This view uses `now()`." Is the cadence finer than the window, and documented (§ 26)?
- "This export uses OFFSET." Inside a snapshot, or bounded by a max id with a unique order (§ 30)?
- "This hash of an email is reversible." Is it a keyed HMAC, or an internal join key nobody shares (§ 31, § 33)?
- "This snapshot is stale." Is it a closed-period snapshot nobody reads as current (§ 38)?

---

Sources: the data-engineering research catalog (2026-10-19) § 4 for entries 1–40 (numbering kept), and
its notes on dbt incremental strategies, snapshots, constraints and tests, Airflow 3, Dagster and
Prefect, Spark overwrite modes, Debezium delete handling, Postgres materialized views and time-zone
functions, MySQL `CONVERT_TZ`, pseudonymisation guidance and erasure in analytical copies; the batch-8
data-engineering eval (2026-10-19) for the ownership splits. The real-repo observations behind § 20,
§ 21, § 22, § 30, § 34, § 38 and § 39 were measured read-only on one NestJS + MikroORM + Postgres
monorepo on 2026-10-19. Paraphrased; no text is reproduced beyond identifiers.
