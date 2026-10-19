# Seeded defects — `data-pipelines`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the agent scans. If you stage
the fixture by hand, delete this file from the copy first — an agent that reads it will score 100% and the number will
mean nothing.

Fixture shape: `Larkmoor` — a commerce company's data platform: a dbt project (`analytics/`, dbt-core 1.9.4; a duckdb
`dev` target for offline proofs and a BigQuery `prod` target) with staging, intermediate and marts layers, two
snapshots, seeds, sources with freshness, contracts, model versions and one exposure; Airflow 3.0.2 DAGs (`dags/`), a
Dagster asset file, a Prefect flow, PySpark jobs, Python and SQL loaders, Debezium connectors, a Great Expectations
suite, a Soda file, GitHub workflows; recorded BigQuery job history and two data snapshots (`warehouse/`); and a
NestJS 11 + MikroORM 6 + Knex reporting module over Postgres 17 with a legacy MySQL 8.4 lane (`apps/reporting/`):
rollup jobs, counters, triggers, materialized views, bucket SQL, export runners, a platform dump and an erasure
handler. 132 seeds over 66 classes (two per class), 37 decoys.

Invocation: /audit-data-quality --whole-repo
Invocation[/audit-data-model]: /audit-data-model
Stage with: --git — `/audit-data-quality` proves it wrote nothing with `git status --porcelain` before and after.

Eval source: Track A batch 8, `eval-batch8-data-engineering.md` § 2 (the 66-class map), § 3.2 (the real target's
correct shapes, re-created here as decoys), § 5.12 (fixture design), § 6 items 23–24. Classes are the research
catalog's ids, shipped as `DE-<family>-<n>`; precedents are `templates/snippets/precedents/data-engineering.md` § n;
proofs are `proof-oracles.md` § Data engineering (V540–V569). Roots (name them all in `ROOTS`):
- `analytics/` — the dbt project (`model-graph.py` reads it without dbt; exit 0);
- `dags/`, `assets/`, `flows/`, `spark/`, `etl/`, `cdc/`, `gx/`, `soda/`, `.github/workflows/`, `Makefile`, `scripts/`;
- `apps/reporting/` — the in-app lane (`src/reports`, `src/exports`, `src/platform`, `src/privacy`, `src/legacy-mysql`,
  `migrations/`);
- `warehouse/` (recorded `INFORMATION_SCHEMA.JOBS` export, two monthly snapshots, Snowflake masking DDL), `infra/terraform/`.

Departures from the eval, stated so a reader can audit them:
- **132 seeds, not 130**: two per class over all 66 classes (CO-5 is seeded as two rows of the recorded job-history
  CSV; SC-5 as a unit change and a new enum member visible only in the two `warehouse/snapshots` files — both are
  `report-flagged`, data lane only).
- **Every model-level `model-graph.py` candidate is a seed or a decoy.** Its model-level rows (IN-2, IN-6, IN-9, CO-2,
  CO-3, DQ-1, DQ-5 CASE, DQ-6, DQ-8, SC-1, LN-4) anchor at the model's `config(` line (or line 1), so each model
  carries at most one of them; the fixture was built and re-run until the candidate list held no stray row.
- **No git history.** SC-2 is seeded statically (an older version with no `deprecation_date` under a breaking v2);
  the `git diff` lane prints `NOT-RUN` on a staged copy, as designed.
- **`verify.sh` cannot run dbt in the build environment** (no dbt, duckdb or sqlglot installed; nothing was installed).
  Its execution lane prints `NOT-RUN`, never PASS, until run where `dbt-duckdb` is available.

Ownership and scoring. One run: **`/audit-data-quality --whole-repo`** scores every row (it dispatches all ten
detectors). The GR rows also score under `/audit-data-model`. Routed classes (a report's number, consumer dedup,
app schedulers, OLTP query cost, PII in logs) are not seeded here — `business-rules`, `ds-defects` and
`backend-defects` carry them. `bucket:` is the row's expected disposition: `report-with-fix` (the V-oracle can fail
first on a scratch target, or the fact is two-ended, and the fix is local), `report-flagged` (one link needs data the
repo does not hold: two snapshots, a dry run, a deploy order, a declared grain).

Secrets. None. Connection strings come from the environment; e-mails and names in seeds are fabricated under
`example.test`; bucket and project names are fictional.

Line numbers are exact against the files in this directory and are re-checked by `benchmarks/run.sh --verify`, which also
fails if a decoy sits within 12 lines of a defect in the same file. Every line was computed from its anchor.

### Measured (2026-10-19, `ROOTS=(.)` on a staged copy; read-only; under 1 s per detector; 0 `rg` errors)

`model-graph.py` exit 0 — 49 models · 3 seeds · 2 snapshots · 14 source tables · 108 tests · 1 exposure · 10
incrementals; 37 candidates, every one a seed or a decoy. Each detector's pre-flight lists its seeds; the extra lines
it also prints (a DAG insert that `incremental-load-scan` 2b lists, a `limit 1000` in the dump that `extract-scan` 3a
lists, `at time zone 'UTC'` lines that `derived-data-scan` 7b lists for reading) are the read's to refute and are not
seeded or scored.

## Summary

| id | file:line | severity | command | class | bucket |
|----|-----------|----------|---------|-------|--------|
| DE-IN1-a | `analytics/models/marts/product/fct_events.sql:10` | high | `/audit-data-quality` | DE-IN-1 | report-with-fix |
| DE-IN1-b | `etl/loaders/orders_sync.py:15` | high | `/audit-data-quality` | DE-IN-1 | report-with-fix |
| DE-IN2-a | `analytics/models/marts/finance/fct_refund_events.sql:1` | high | `/audit-data-quality` | DE-IN-2 | report-with-fix |
| DE-IN2-b | `etl/loaders/payments_load.py:10` | high | `/audit-data-quality` | DE-IN-2 | report-with-fix |
| DE-IN3-a | `analytics/models/marts/product/fct_clicks.sql:11` | medium | `/audit-data-quality` | DE-IN-3 | report-with-fix |
| DE-IN3-b | `etl/loaders/orders_sync.py:12` | medium | `/audit-data-quality` | DE-IN-3 | report-with-fix |
| DE-IN4-a | `analytics/snapshots/customers_snapshot.sql:1` | high | `/audit-data-quality` | DE-IN-4 | report-with-fix |
| DE-IN4-b | `etl/sql/merge_orders.sql:2` | high | `/audit-data-quality` | DE-IN-4 | report-with-fix |
| DE-IN5-a | `analytics/models/marts/product/fct_sessions.sql:12` | medium | `/audit-data-quality` | DE-IN-5 | report-with-fix |
| DE-IN5-b | `spark/jobs/dedupe_events.py:8` | medium | `/audit-data-quality` | DE-IN-5 | report-with-fix |
| DE-IN6-a | `analytics/models/marts/product/fct_events.sql:1` | medium | `/audit-data-quality` | DE-IN-6 | report-with-fix |
| DE-IN6-b | `spark/jobs/land_events.py:6` | medium | `/audit-data-quality` | DE-IN-6 | report-with-fix |
| DE-IN7-a | `spark/jobs/write_daily.py:10` | high | `/audit-data-quality` | DE-IN-7 | report-with-fix |
| DE-IN7-b | `etl/loaders/refresh_customers.py:7` | high | `/audit-data-quality` | DE-IN-7 | report-with-fix |
| DE-IN8-a | `Makefile:5` | high | `/audit-data-quality` | DE-IN-8 | report-with-fix |
| DE-IN8-b | `scripts/backfill_orders_raw.sh:4` | high | `/audit-data-quality` | DE-IN-8 | report-with-fix |
| DE-IN9-a | `analytics/models/marts/product/fct_page_views_batched.sql:1` | high | `/audit-data-quality` | DE-IN-9 | report-with-fix |
| DE-IN9-b | `analytics/models/marts/product/fct_page_views_batched.sql:12` | medium | `/audit-data-quality` | DE-IN-9 | report-with-fix |
| DE-IN10-a | `cdc/orders-connector.json:11` | high | `/audit-data-quality` | DE-IN-10 | report-with-fix |
| DE-IN10-b | `cdc/payments-sink.json:7` | high | `/audit-data-quality` | DE-IN-10 | report-with-fix |
| DE-OR1-a | `dags/orders_daily.py:26` | high | `/audit-data-quality` | DE-OR-1 | report-with-fix |
| DE-OR1-b | `dags/payments_hourly.py:18` | high | `/audit-data-quality` | DE-OR-1 | report-with-fix |
| DE-OR2-a | `dags/orders_daily.py:11` | high | `/audit-data-quality` | DE-OR-2 | report-with-fix |
| DE-OR2-b | `dags/inventory_snapshot.py:10` | high | `/audit-data-quality` | DE-OR-2 | report-with-fix |
| DE-OR3-a | `dags/payments_hourly.py:13` | medium | `/audit-data-quality` | DE-OR-3 | report-with-fix |
| DE-OR3-b | `dags/marketing_attribution.py:12` | medium | `/audit-data-quality` | DE-OR-3 | report-with-fix |
| DE-OR4-a | `dags/orders_daily.py:36` | high | `/audit-data-quality` | DE-OR-4 | report-with-fix |
| DE-OR4-b | `dags/payments_hourly.py:29` | high | `/audit-data-quality` | DE-OR-4 | report-with-fix |
| DE-OR5-a | `dags/orders_daily.py:22` | high | `/audit-data-quality` | DE-OR-5 | report-with-fix |
| DE-OR5-b | `flows/partner_push.py:6` | high | `/audit-data-quality` | DE-OR-5 | report-with-fix |
| DE-OR6-a | `dags/marketing_attribution.py:14` | medium | `/audit-data-quality` | DE-OR-6 | report-with-fix |
| DE-OR6-b | `dags/finance_close.py:14` | medium | `/audit-data-quality` | DE-OR-6 | report-with-fix |
| DE-OR7-a | `dags/legacy_exports.py:15` | high | `/audit-data-quality` | DE-OR-7 | report-with-fix |
| DE-OR7-b | `dags/legacy_exports.py:19` | high | `/audit-data-quality` | DE-OR-7 | report-with-fix |
| DE-OR8-a | `dags/sessions_daily.py:9` | high | `/audit-data-quality` | DE-OR-8 | report-with-fix |
| DE-OR8-b | `dags/refunds_daily.py:9` | high | `/audit-data-quality` | DE-OR-8 | report-with-fix |
| DE-OR9-a | `assets/finance_assets.py:15` | high | `/audit-data-quality` | DE-OR-9 | report-with-fix |
| DE-OR9-b | `assets/finance_assets.py:25` | high | `/audit-data-quality` | DE-OR-9 | report-with-fix |
| DE-DQ1-a | `analytics/models/marts/finance/refunds_ledger.sql:1` | medium | `/audit-data-quality` | DE-DQ-1 | report-with-fix |
| DE-DQ1-b | `analytics/models/intermediate/int_customer_ltv.sql:1` | medium | `/audit-data-quality` | DE-DQ-1 | report-with-fix |
| DE-DQ2-a | `analytics/models/marts/product/_product.yml:10` | medium | `/audit-data-quality` | DE-DQ-2 | report-with-fix |
| DE-DQ2-b | `analytics/models/marts/product/_product.yml:34` | medium | `/audit-data-quality` | DE-DQ-2 | report-with-fix |
| DE-DQ3-a | `.github/workflows/dbt-ci.yml:10` | medium | `/audit-data-quality` | DE-DQ-3 | report-with-fix |
| DE-DQ3-b | `.github/workflows/dbt-ci.yml:11` | medium | `/audit-data-quality` | DE-DQ-3 | report-with-fix |
| DE-DQ4-a | `analytics/models/staging/_sources.yml:14` | medium | `/audit-data-quality` | DE-DQ-4 | report-with-fix |
| DE-DQ4-b | `analytics/models/staging/_sources.yml:65` | medium | `/audit-data-quality` | DE-DQ-4 | report-with-fix |
| DE-DQ5-a | `analytics/models/marts/core/_order_lines.yml:26` | medium | `/audit-data-quality` | DE-DQ-5 | report-with-fix |
| DE-DQ5-b | `analytics/models/marts/finance/rpt_payment_methods.sql:4` | medium | `/audit-data-quality` | DE-DQ-5 | report-with-fix |
| DE-DQ6-a | `analytics/models/marts/finance/payments_daily.sql:2` | medium | `/audit-data-quality` | DE-DQ-6 | report-with-fix |
| DE-DQ6-b | `analytics/models/marts/product/sessions_daily.sql:1` | medium | `/audit-data-quality` | DE-DQ-6 | report-with-fix |
| DE-DQ7-a | `analytics/models/staging/_sources.yml:25` | medium | `/audit-data-quality` | DE-DQ-7 | report-with-fix |
| DE-DQ7-b | `soda/checks_payments.yml:1` | medium | `/audit-data-quality` | DE-DQ-7 | report-with-fix |
| DE-DQ8-a | `analytics/models/marts/product/fct_sessions.sql:1` | low | `/audit-data-quality` | DE-DQ-8 | report-with-fix |
| DE-DQ8-b | `analytics/models/marts/product/fct_ad_spend.sql:1` | low | `/audit-data-quality` | DE-DQ-8 | report-with-fix |
| DE-SC1-a | `analytics/models/marts/finance/fct_payments.sql:1` | medium | `/audit-data-quality` | DE-SC-1 | report-with-fix |
| DE-SC1-b | `analytics/models/marts/core/_order_lines.yml:22` | medium | `/audit-data-quality` | DE-SC-1 | report-with-fix |
| DE-SC2-a | `analytics/models/marts/core/_dim_customers.yml:15` | high | `/audit-data-quality` | DE-SC-2 | report-flagged |
| DE-SC2-b | `analytics/models/marts/finance/_finance.yml:76` | high | `/audit-data-quality` | DE-SC-2 | report-flagged |
| DE-SC3-a | `analytics/models/marts/core/rpt_customer_export.sql:2` | low | `/audit-data-quality` | DE-SC-3 | report-with-fix |
| DE-SC3-b | `analytics/models/intermediate/int_orders_enriched.sql:2` | low | `/audit-data-quality` | DE-SC-3 | report-with-fix |
| DE-SC4-a | `apps/reporting/migrations/Migration20261012000000_drop_legacy_status.ts:6` | high | `/audit-data-quality` | DE-SC-4 | report-with-fix |
| DE-SC4-b | `apps/reporting/migrations/20261015_rename_phone.ts:5` | high | `/audit-data-quality` | DE-SC-4 | report-with-fix |
| DE-SC5-a | `analytics/models/staging/stg_refunds.sql:7` | high | `/audit-data-quality` | DE-SC-5 | report-flagged |
| DE-SC5-b | `warehouse/snapshots/payments_2026-10.csv:3` | high | `/audit-data-quality` | DE-SC-5 | report-flagged |
| DE-SC6-a | `analytics/models/staging/stg_events.sql:6` | medium | `/audit-data-quality` | DE-SC-6 | report-with-fix |
| DE-SC6-b | `etl/sql/load_payments.sql:3` | medium | `/audit-data-quality` | DE-SC-6 | report-with-fix |
| DE-LN1-a | `analytics/models/staging/stg_payments.sql:9` | medium | `/audit-data-quality` | DE-LN-1 | report-with-fix |
| DE-LN1-b | `analytics/models/marts/finance/payouts.sql:3` | medium | `/audit-data-quality` | DE-LN-1 | report-with-fix |
| DE-LN2-a | `analytics/models/marts/finance/refunds_ledger.sql:9` | low | `/audit-data-quality` | DE-LN-2 | report-with-fix |
| DE-LN2-b | `analytics/models/staging/stg_sessions.sql:7` | low | `/audit-data-quality` | DE-LN-2 | report-with-fix |
| DE-LN3-a | `apps/reporting/src/exports/finance-feed.export.ts:6` | medium | `/audit-data-quality` | DE-LN-3 | report-with-fix |
| DE-LN3-b | `dags/reverse_etl_sync.py:15` | medium | `/audit-data-quality` | DE-LN-3 | report-with-fix |
| DE-LN4-a | `analytics/models/staging/stg_sessions.sql:1` | low | `/audit-data-quality` | DE-LN-4 | report-with-fix |
| DE-LN4-b | `analytics/models/staging/_sources.yml:56` | low | `/audit-data-quality` | DE-LN-4 | report-with-fix |
| DE-MV1-a | `apps/reporting/src/reports/sales-counter.job.ts:18` | high | `/audit-data-quality` | DE-MV-1 | report-with-fix |
| DE-MV1-b | `apps/reporting/src/reports/usage-counter.processor.ts:14` | high | `/audit-data-quality` | DE-MV-1 | report-with-fix |
| DE-MV2-a | `apps/reporting/src/reports/revenue-rollup.job.ts:17` | high | `/audit-data-quality` | DE-MV-2 | report-with-fix |
| DE-MV2-b | `apps/reporting/src/reports/merchant-snapshot.job.ts:13` | high | `/audit-data-quality` | DE-MV-2 | report-with-fix |
| DE-MV3-a | `apps/reporting/migrations/Migration20260305000000_reporting_tables.ts:14` | medium | `/audit-data-quality` | DE-MV-3 | report-with-fix |
| DE-MV3-b | `apps/reporting/src/reports/inventory-stats.reconcile.ts:20` | medium | `/audit-data-quality` | DE-MV-3 | report-with-fix |
| DE-MV4-a | `apps/reporting/migrations/Migration20260310000000_rollup_triggers.ts:15` | medium | `/audit-data-quality` | DE-MV-4 | report-with-fix |
| DE-MV4-b | `apps/reporting/src/reports/inventory-import.job.ts:13` | medium | `/audit-data-quality` | DE-MV-4 | report-with-fix |
| DE-MV5-a | `apps/reporting/migrations/Migration20260320000000_materialized_views.ts:9` | medium | `/audit-data-quality` | DE-MV-5 | report-with-fix |
| DE-MV5-b | `apps/reporting/src/reports/mv-refresh.job.ts:12` | medium | `/audit-data-quality` | DE-MV-5 | report-with-fix |
| DE-MV6-a | `apps/reporting/src/reports/tenant-sales.query.ts:7` | medium | `/audit-data-quality` | DE-MV-6 | report-with-fix |
| DE-MV6-b | `apps/reporting/src/reports/usage-report.service.ts:10` | medium | `/audit-data-quality` | DE-MV-6 | report-with-fix |
| DE-TB1-a | `apps/reporting/src/reports/hourly-orders.query.ts:6` | high | `/audit-data-quality` | DE-TB-1 | report-with-fix |
| DE-TB1-b | `apps/reporting/src/reports/page-view-buckets.query.ts:6` | high | `/audit-data-quality` | DE-TB-1 | report-with-fix |
| DE-TB2-a | `apps/reporting/src/reports/window-report.query.ts:8` | medium | `/audit-data-quality` | DE-TB-2 | report-with-fix |
| DE-TB2-b | `apps/reporting/src/reports/payouts-report.query.ts:7` | medium | `/audit-data-quality` | DE-TB-2 | report-with-fix |
| DE-TB3-a | `apps/reporting/src/legacy-mysql/settlement.query.ts:6` | high | `/audit-data-quality` | DE-TB-3 | report-with-fix |
| DE-TB3-b | `apps/reporting/src/legacy-mysql/daily-orders.query.ts:6` | high | `/audit-data-quality` | DE-TB-3 | report-with-fix |
| DE-TB4-a | `apps/reporting/src/reports/berlin-sales.query.ts:6` | medium | `/audit-data-quality` | DE-TB-4 | report-with-fix |
| DE-TB4-b | `apps/reporting/src/reports/us-sales.query.ts:6` | medium | `/audit-data-quality` | DE-TB-4 | report-with-fix |
| DE-EX1-a | `apps/reporting/src/exports/activity-export.runner.ts:13` | medium | `/audit-data-quality` | DE-EX-1 | report-with-fix |
| DE-EX1-b | `apps/reporting/src/exports/customers-export.runner.ts:13` | medium | `/audit-data-quality` | DE-EX-1 | report-with-fix |
| DE-EX2-a | `apps/reporting/src/platform/db-dump.port.ts:14` | medium | `/audit-data-quality` | DE-EX-2 | report-with-fix |
| DE-EX2-b | `scripts/nightly_dump.sh:4` | medium | `/audit-data-quality` | DE-EX-2 | report-with-fix |
| DE-EX3-a | `apps/reporting/src/exports/big-orders-export.runner.ts:11` | medium | `/audit-data-quality` | DE-EX-3 | report-with-fix |
| DE-EX3-b | `apps/reporting/src/exports/statement-export.runner.ts:11` | medium | `/audit-data-quality` | DE-EX-3 | report-with-fix |
| DE-EX4-a | `apps/reporting/src/exports/settlement-export.mapper.ts:12` | medium | `/audit-data-quality` | DE-EX-4 | report-with-fix |
| DE-EX4-b | `apps/reporting/src/exports/settlement-export.mapper.ts:15` | medium | `/audit-data-quality` | DE-EX-4 | report-with-fix |
| DE-PC1-a | `analytics/models/marts/core/_dim_customers.yml:10` | medium | `/audit-data-quality` | DE-PC-1 | report-with-fix |
| DE-PC1-b | `analytics/models/marts/marketing/rpt_newsletter_audience.sql:3` | medium | `/audit-data-quality` | DE-PC-1 | report-with-fix |
| DE-PC2-a | `analytics/snapshots/customers_snapshot.sql:5` | high | `/audit-data-quality` | DE-PC-2 | report-with-fix |
| DE-PC2-b | `apps/reporting/migrations/Migration20260307000000_customer_ltv_daily.ts:7` | high | `/audit-data-quality` | DE-PC-2 | report-with-fix |
| DE-PC3-a | `apps/reporting/src/exports/partner-feed.export.ts:8` | medium | `/audit-data-quality` | DE-PC-3 | report-with-fix |
| DE-PC3-b | `analytics/models/marts/marketing/rpt_ad_audience.sql:3` | medium | `/audit-data-quality` | DE-PC-3 | report-with-fix |
| DE-PC4-a | `scripts/refresh_staging.sh:4` | high | `/audit-data-quality` | DE-PC-4 | report-with-fix |
| DE-PC4-b | `Makefile:9` | high | `/audit-data-quality` | DE-PC-4 | report-with-fix |
| DE-PC5-a | `infra/terraform/exports.tf:1` | medium | `/audit-data-quality` | DE-PC-5 | report-with-fix |
| DE-PC5-b | `apps/reporting/src/exports/customers-export.runner.ts:23` | medium | `/audit-data-quality` | DE-PC-5 | report-with-fix |
| DE-PC6-a | `analytics/models/marts/finance/_finance_pii.yml:10` | medium | `/audit-data-quality` | DE-PC-6 | report-with-fix |
| DE-PC6-b | `warehouse/snowflake/masking.sql:8` | medium | `/audit-data-quality` | DE-PC-6 | report-with-fix |
| DE-CO1-a | `analytics/models/marts/product/rpt_ad_performance.sql:7` | medium | `/audit-data-quality` | DE-CO-1 | report-flagged |
| DE-CO1-b | `analytics/models/marts/product/fct_ad_impressions.sql:6` | medium | `/audit-data-quality` | DE-CO-1 | report-with-fix |
| DE-CO2-a | `analytics/models/marts/product/fct_ad_impressions.sql:1` | medium | `/audit-data-quality` | DE-CO-2 | report-with-fix |
| DE-CO2-b | `etl/sql/merge_impressions.sql:2` | medium | `/audit-data-quality` | DE-CO-2 | report-with-fix |
| DE-CO3-a | `analytics/models/marts/finance/fct_order_status_history.sql:1` | medium | `/audit-data-quality` | DE-CO-3 | report-with-fix |
| DE-CO3-b | `.github/workflows/dbt-nightly.yml:11` | medium | `/audit-data-quality` | DE-CO-3 | report-with-fix |
| DE-CO4-a | `analytics/models/marts/product/rpt_daily_kpis.sql:1` | low | `/audit-data-quality` | DE-CO-4 | report-with-fix |
| DE-CO4-b | `analytics/models/marts/product/rpt_ad_performance.sql:1` | low | `/audit-data-quality` | DE-CO-4 | report-with-fix |
| DE-CO5-a | `warehouse/history/jobs_2026-10.csv:2` | low | `/audit-data-quality` | DE-CO-5 | report-flagged |
| DE-CO5-b | `warehouse/history/jobs_2026-10.csv:3` | low | `/audit-data-quality` | DE-CO-5 | report-flagged |
| DE-GR1-a | `analytics/models/marts/finance/_refunds.yml:4` | medium | `/audit-data-quality /audit-data-model` | DE-GR-1 | report-flagged |
| DE-GR1-b | `analytics/models/intermediate/_intermediate.yml:4` | medium | `/audit-data-quality /audit-data-model` | DE-GR-1 | report-flagged |
| DE-GR2-a | `analytics/models/marts/core/order_lines.sql:12` | high | `/audit-data-quality /audit-data-model` | DE-GR-2 | report-with-fix |
| DE-GR2-b | `analytics/models/marts/core/promo_exposure.sql:2` | high | `/audit-data-quality /audit-data-model` | DE-GR-2 | report-with-fix |
| DE-GR3-a | `analytics/models/marts/core/dim_products_scd.sql:8` | high | `/audit-data-quality /audit-data-model` | DE-GR-3 | report-with-fix |
| DE-GR3-b | `analytics/models/marts/core/dim_store_history.sql:7` | high | `/audit-data-quality /audit-data-model` | DE-GR-3 | report-with-fix |
| DE-GR4-a | `analytics/models/marts/core/order_lines.sql:4` | low | `/audit-data-quality /audit-data-model` | DE-GR-4 | report-with-fix |
| DE-GR4-b | `analytics/models/marts/marketing/rpt_ad_audience.sql:2` | low | `/audit-data-quality /audit-data-model` | DE-GR-4 | report-with-fix |

Severity split: 49 high · 69 medium · 14 low. Families: IN 20 · OR 18 · DQ 16 · SC 12 · LN 8 · MV 12 · TB 8 · EX 8 · PC 12 · CO 10 · GR 8. Total 132 seeds over 66 classes (two per class), 37 decoys.

### Coverage by class

One row per class; every class carries two seeds, and the detector § named is the one whose pre-flight (or `model-graph.py` candidate list) surfaces the line.

| class | detector § | seeds |
|-------|------------|-------|
| DE-IN-1 | incremental-load-scan §1 | DE-IN1-a, DE-IN1-b |
| DE-IN-2 | incremental-load-scan §2 | DE-IN2-a, DE-IN2-b |
| DE-IN-3 | incremental-load-scan §3 | DE-IN3-a, DE-IN3-b |
| DE-IN-4 | incremental-load-scan §4 | DE-IN4-a, DE-IN4-b |
| DE-IN-5 | incremental-load-scan §5 | DE-IN5-a, DE-IN5-b |
| DE-IN-6 | incremental-load-scan §6 | DE-IN6-a, DE-IN6-b |
| DE-IN-7 | incremental-load-scan §7 | DE-IN7-a, DE-IN7-b |
| DE-IN-8 | incremental-load-scan §8 | DE-IN8-a, DE-IN8-b |
| DE-IN-9 | incremental-load-scan §9 | DE-IN9-a, DE-IN9-b |
| DE-IN-10 | incremental-load-scan §10 | DE-IN10-a, DE-IN10-b |
| DE-OR-1 | orchestration-scan §1 | DE-OR1-a, DE-OR1-b |
| DE-OR-2 | orchestration-scan §2 | DE-OR2-a, DE-OR2-b |
| DE-OR-3 | orchestration-scan §3 | DE-OR3-a, DE-OR3-b |
| DE-OR-4 | orchestration-scan §4 | DE-OR4-a, DE-OR4-b |
| DE-OR-5 | orchestration-scan §5 | DE-OR5-a, DE-OR5-b |
| DE-OR-6 | orchestration-scan §6 | DE-OR6-a, DE-OR6-b |
| DE-OR-7 | orchestration-scan §7 | DE-OR7-a, DE-OR7-b |
| DE-OR-8 | orchestration-scan §8 | DE-OR8-a, DE-OR8-b |
| DE-OR-9 | orchestration-scan §9 | DE-OR9-a, DE-OR9-b |
| DE-DQ-1 | data-test-scan §1 | DE-DQ1-a, DE-DQ1-b |
| DE-DQ-2 | data-test-scan §2 | DE-DQ2-a, DE-DQ2-b |
| DE-DQ-3 | data-test-scan §3 | DE-DQ3-a, DE-DQ3-b |
| DE-DQ-4 | data-test-scan §4 | DE-DQ4-a, DE-DQ4-b |
| DE-DQ-5 | data-test-scan §5 | DE-DQ5-a, DE-DQ5-b |
| DE-DQ-6 | data-test-scan §6 | DE-DQ6-a, DE-DQ6-b |
| DE-DQ-7 | data-test-scan §7 | DE-DQ7-a, DE-DQ7-b |
| DE-DQ-8 | data-test-scan §8 | DE-DQ8-a, DE-DQ8-b |
| DE-SC-1 | contract-diff §1 | DE-SC1-a, DE-SC1-b |
| DE-SC-2 | contract-diff §2 | DE-SC2-a, DE-SC2-b |
| DE-SC-3 | contract-diff §3 | DE-SC3-a, DE-SC3-b |
| DE-SC-4 | contract-diff §4 | DE-SC4-a, DE-SC4-b |
| DE-SC-5 | contract-diff §5 | DE-SC5-a, DE-SC5-b |
| DE-SC-6 | contract-diff §6 | DE-SC6-a, DE-SC6-b |
| DE-LN-1 | lineage-trace §1 | DE-LN1-a, DE-LN1-b |
| DE-LN-2 | lineage-trace §2 | DE-LN2-a, DE-LN2-b |
| DE-LN-3 | lineage-trace §3 | DE-LN3-a, DE-LN3-b |
| DE-LN-4 | lineage-trace §4 | DE-LN4-a, DE-LN4-b |
| DE-MV-1 | derived-data-scan §1 | DE-MV1-a, DE-MV1-b |
| DE-MV-2 | derived-data-scan §2 | DE-MV2-a, DE-MV2-b |
| DE-MV-3 | derived-data-scan §3 | DE-MV3-a, DE-MV3-b |
| DE-MV-4 | derived-data-scan §4 | DE-MV4-a, DE-MV4-b |
| DE-MV-5 | derived-data-scan §5 | DE-MV5-a, DE-MV5-b |
| DE-MV-6 | derived-data-scan §6 | DE-MV6-a, DE-MV6-b |
| DE-TB-1 | derived-data-scan §7 | DE-TB1-a, DE-TB1-b |
| DE-TB-2 | derived-data-scan §8 | DE-TB2-a, DE-TB2-b |
| DE-TB-3 | derived-data-scan §9 | DE-TB3-a, DE-TB3-b |
| DE-TB-4 | derived-data-scan §10 | DE-TB4-a, DE-TB4-b |
| DE-EX-1 | extract-scan §1 | DE-EX1-a, DE-EX1-b |
| DE-EX-2 | extract-scan §2 | DE-EX2-a, DE-EX2-b |
| DE-EX-3 | extract-scan §3 | DE-EX3-a, DE-EX3-b |
| DE-EX-4 | extract-scan §4 | DE-EX4-a, DE-EX4-b |
| DE-PC-1 | pii-copy-scan §1 | DE-PC1-a, DE-PC1-b |
| DE-PC-2 | pii-copy-scan §2 | DE-PC2-a, DE-PC2-b |
| DE-PC-3 | pii-copy-scan §3 | DE-PC3-a, DE-PC3-b |
| DE-PC-4 | pii-copy-scan §4 | DE-PC4-a, DE-PC4-b |
| DE-PC-5 | pii-copy-scan §5 | DE-PC5-a, DE-PC5-b |
| DE-PC-6 | pii-copy-scan §6 | DE-PC6-a, DE-PC6-b |
| DE-CO-1 | warehouse-scan-audit §1 | DE-CO1-a, DE-CO1-b |
| DE-CO-2 | warehouse-scan-audit §2 | DE-CO2-a, DE-CO2-b |
| DE-CO-3 | warehouse-scan-audit §3 | DE-CO3-a, DE-CO3-b |
| DE-CO-4 | warehouse-scan-audit §4 | DE-CO4-a, DE-CO4-b |
| DE-CO-5 | warehouse-scan-audit §5 | DE-CO5-a, DE-CO5-b |
| DE-GR-1 | grain-probe §1 | DE-GR1-a, DE-GR1-b |
| DE-GR-2 | grain-probe §2 | DE-GR2-a, DE-GR2-b |
| DE-GR-3 | grain-probe §3 | DE-GR3-a, DE-GR3-b |
| DE-GR-4 | grain-probe §4 | DE-GR4-a, DE-GR4-b |
| **decoys (must not be reported)** | — | **37**: DE-DECOY-01 … DE-DECOY-37 |

---

## DE-IN1-a — Strict `>` on `max(occurred_at)` with no lookback

```defect
id:       DE-IN1-a
file:     analytics/models/marts/product/fct_events.sql
line:     10
severity: high
command:  /audit-data-quality
class:    DE-IN-1
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §1 (model-graph IN-1)
anchor:   where occurred_at > (select max(occurred_at) from {{ this }})
match:    fct_events|occurred_at|watermark|incremental
match:    strict|>|lookback|tie|late|same.?timestamp
```

The incremental branch keeps only rows strictly newer than the target's maximum `occurred_at`, with no lookback. A row committed later with the same timestamp, or a tracker event that arrives late, is never loaded. Proof V542/V541 (tie row and late row on the duckdb build). Fix: `>=` with a lookback window and the merge on `event_id` (precedent § 2).

## DE-IN1-b — The 15-minute order sync compares `updated_at > since` with no lookback

```defect
id:       DE-IN1-b
file:     etl/loaders/orders_sync.py
line:     15
severity: high
command:  /audit-data-quality
class:    DE-IN-1
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §1 (1b)
anchor:   "select * from orders where updated_at > %(since)s",
match:    orders_sync|updated_at|watermark|since
match:    strict|>|tie|late|lookback|same.?timestamp|lost
```

Two orders updated in the same second straddle a run boundary and the second is skipped for good; replication lag loses rows the same way. Proof V542 against a scratch Postgres. Fix: `>=` with a lookback and an upsert on `order_id`.

## DE-IN2-a — A merge incremental with no `unique_key`

```defect
id:       DE-IN2-a
file:     analytics/models/marts/finance/fct_refund_events.sql
line:     1
severity: high
command:  /audit-data-quality
class:    DE-IN-2
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §2 (model-graph IN-2)
anchor:   {{ config(materialized='incremental', incremental_strategy='merge') }}
match:    fct_refund_events|refund
match:    unique.?key|merge|duplicat|key
```

Without `unique_key` the merge strategy inserts every returned row; the 3-day lookback re-reads refunds already loaded and duplicates them on every run. Proof V540 (same batch twice → count and checksum move). Fix: `unique_key='refund_event_id'` with its `not_null` test.

## DE-IN2-b — The settlement loader appends the file with no key

```defect
id:       DE-IN2-b
file:     etl/loaders/payments_load.py
line:     10
severity: high
command:  /audit-data-quality
class:    DE-IN-2
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §2 (2c)
anchor:   df.to_sql("payments_copy", engine, if_exists="append", index=False)
match:    payments_load|payments_copy|to_sql
match:    append|twice|duplicat|idempot|replay|retr|double|re-?run|re-?insert|re-?append|unique.?key|merge|append
```

`to_sql(if_exists='append')` inserts the provider file again when the job is retried or re-run for the same day. Proof V540. Fix: load into a staging table and `MERGE`/`ON CONFLICT (payment_id)`, or delete the file's day first in one transaction.

## DE-IN3-a — The click incremental filters on the warehouse load column

```defect
id:       DE-IN3-a
file:     analytics/models/marts/product/fct_clicks.sql
line:     11
severity: medium
command:  /audit-data-quality
class:    DE-IN-3
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §3 (model-graph IN-3)
anchor:   and _loaded_at >= (select max(_loaded_at) from {{ this }}) - interval '2 days'
match:    fct_clicks|_loaded_at
match:    load.?time|load column|loaded_at|processing|event.?time|clock
```

`_loaded_at` is the loader's clock, not the event's: rows the extractor delivers out of order relative to their event time, or re-delivered, are filtered by when they landed. Proof V541 with the two stamps skewed. Fix: filter on `occurred_at` with a lookback and merge on `event_id`.

## DE-IN3-b — The watermark is advanced to `now()` before the read and the write

```defect
id:       DE-IN3-b
file:     etl/loaders/orders_sync.py
line:     12
severity: medium
command:  /audit-data-quality
class:    DE-IN-3
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §3 (3b)
anchor:   state.set("orders_last_synced_at", datetime.now(timezone.utc))
match:    orders_sync|last_synced|watermark|state
match:    before|advanc|crash|commit|now|clock
```

A crash between `state.set` and `upsert_orders` loses the whole window, and `now()` is the job host's clock, not the source's. Proof: V541 with a fault injected after line 12. Fix: advance to `max(updated_at)` of the rows written, after the commit.

## DE-IN4-a — The customers snapshot never closes a deleted customer

```defect
id:       DE-IN4-a
file:     analytics/snapshots/customers_snapshot.sql
line:     1
severity: high
command:  /audit-data-quality
class:    DE-IN-4
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §4 (model-graph IN-4)
anchor:   {% snapshot customers_snapshot %}
match:    customers_snapshot|snapshot
match:    hard.?delete|delete|erase|current
```

`hard_deletes` is unset (default `ignore`, dbt 1.9.4), and customers are hard-deleted by `apps/reporting/src/privacy/erase-customer.handler.ts`. A deleted customer stays current in the snapshot forever. Proof V543 on duckdb. Fix: `hard_deletes='invalidate'` (the erasure question is `pii-copy-scan` §2, DE-PC2-a).

## DE-IN4-b — The CDC merge has no delete branch

```defect
id:       DE-IN4-b
file:     etl/sql/merge_orders.sql
line:     2
severity: high
command:  /audit-data-quality
class:    DE-IN-4
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §4 (4b)
anchor:   MERGE INTO warehouse.orders t
match:    merge_orders|merge|warehouse\.orders
match:    delete|op|'d'|tombstone
```

`staging.orders_delta` carries an `op` column, but the MERGE only updates and inserts: a source delete never reaches `warehouse.orders`. Proof V543. Fix: `WHEN MATCHED AND s.op = 'd' THEN DELETE` (or a soft-delete flag).

## DE-IN5-a — Entry-event dedup orders by one non-unique key

```defect
id:       DE-IN5-a
file:     analytics/models/marts/product/fct_sessions.sql
line:     12
severity: medium
command:  /audit-data-quality
class:    DE-IN-5
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §5 (model-graph IN-5)
anchor:   row_number() over (partition by session_id order by occurred_at) as rn
match:    fct_sessions|row_number|session
match:    tie|order|determin|winner|one key
```

Two events in a session sharing `occurred_at` (the tracker resends at second precision) pick a different `entry_event` per run. Proof V544 (ten seeded shuffles, one checksum). Fix: `order by occurred_at, event_id`.

## DE-IN5-b — `dropDuplicates(["event_id"])` keeps an arbitrary copy of a corrected event

```defect
id:       DE-IN5-b
file:     spark/jobs/dedupe_events.py
line:     8
severity: medium
command:  /audit-data-quality
class:    DE-IN-5
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §5
anchor:   clean = raw.dropDuplicates(["event_id"])
match:    dedupe_events|dropDuplicates|event_id
match:    arbitrar|determin|which|winner|corrected|payload|keep
```

The tracker resends an event with a corrected payload; dropDuplicates on the id keeps whichever row Spark sees first. Proof V544. Fix: a window over `event_id` ordered by the resend sequence, keeping the latest (full-row duplicates are precedent § 15).

## DE-IN6-a — `on_schema_change` resolves to the default `ignore`

```defect
id:       DE-IN6-a
file:     analytics/models/marts/product/fct_events.sql
line:     1
severity: medium
command:  /audit-data-quality
class:    DE-IN-6
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §6 (model-graph IN-6)
anchor:   {{ config(materialized='incremental', unique_key='event_id') }}
match:    fct_events|on_schema_change
match:    ignore|schema|column|drift|default
```

`marts/product` has no `+on_schema_change` in `dbt_project.yml` (finance and core do), so a column the tracker adds never reaches `fct_events` and nothing fails. Proof V545. Fix: `+on_schema_change: append_new_columns` (or `fail`) for `marts/product`.

## DE-IN6-b — The landing read has no `mergeSchema` over two schema versions

```defect
id:       DE-IN6-b
file:     spark/jobs/land_events.py
line:     6
severity: medium
command:  /audit-data-quality
class:    DE-IN-6
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §6 (6b)
anchor:   events = spark.read.parquet("s3://larkmoor-landing/events/")
match:    land_events|parquet|mergeSchema
match:    schema|column|mergeSchema|drift|version
```

Files before 2026-08 lack two columns; Spark infers the schema from a sample, so the new columns are dropped (or the old files fail) depending on which file it reads first. Proof V545. Fix: `.option('mergeSchema', 'true')` or an explicit schema.

## DE-IN7-a — A daily job overwrites the whole partitioned path

```defect
id:       DE-IN7-a
file:     spark/jobs/write_daily.py
line:     10
severity: high
command:  /audit-data-quality
class:    DE-IN-7
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §7 (7a)
anchor:   daily.write.mode("overwrite").partitionBy("event_date").parquet("s3://larkmoor-lake/events_daily/")
match:    write_daily|overwrite|partition
match:    static|dynamic|partitionOverwriteMode|every partition|wipe|delete
```

`partitionOverwriteMode` is the default STATIC (Spark 3.5), so writing one day deletes every other day under the path. Proof V546. Fix: `spark.sql.sources.partitionOverwriteMode=dynamic` or a Delta `replaceWhere`.

## DE-IN7-b — Hourly truncate-and-reload of a table dashboards read

```defect
id:       DE-IN7-b
file:     etl/loaders/refresh_customers.py
line:     7
severity: high
command:  /audit-data-quality
class:    DE-IN-7
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §7 (7b)
anchor:   cur.execute("TRUNCATE TABLE mart.customers")
match:    refresh_customers|truncate|mart\.customers
match:    empty|truncate|reload|reader|swap
```

Between the TRUNCATE and the COPY readers see an empty `mart.customers`; a failed COPY leaves it empty until the next hour. Proof V546 (a reader during the reload). Fix: load a staging table and swap, or replace in one transaction.

## DE-IN8-a — A full refresh of an incremental whose raw source keeps 30 days

```defect
id:       DE-IN8-a
file:     Makefile
line:     5
severity: high
command:  /audit-data-quality
class:    DE-IN-8
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §8 (0d)
anchor:   dbt run --project-dir analytics --full-refresh --select fct_page_views
match:    Makefile|full.?refresh|fct_page_views
match:    history|retention|30 days|rebuild|lost|full_refresh
```

`raw.page_views` keeps 30 days (`_sources.yml`), so `--full-refresh` rebuilds `fct_page_views` with one month and drops the rest of its history; nothing pins `full_refresh: false`. Proof V550. Fix: `full_refresh: false` on the model and a backfill through `/backfill-plan`.

## DE-IN8-b — The outage backfill replays a plain-insert task

```defect
id:       DE-IN8-b
file:     scripts/backfill_orders_raw.sh
line:     4
severity: high
command:  /audit-data-quality
class:    DE-IN-8
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §8 (0d)
anchor:   airflow dags backfill -s "$1" -e "$2" orders_daily
match:    backfill
match:    append|double|twice|insert|duplicat|re-?run
```

`orders_daily.load_orders` inserts a day with no delete or key; backfilling a range that already loaded doubles every order in it. Proof V550 (range twice → identical aggregates fails). Fix: make the write replace the day first, then backfill.

## DE-IN9-a — A microbatch model with no `begin`

```defect
id:       DE-IN9-a
file:     analytics/models/marts/product/fct_page_views_batched.sql
line:     1
severity: high
command:  /audit-data-quality
class:    DE-IN-9
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §9 (model-graph IN-9)
anchor:   {{ config(
match:    fct_page_views_batched|microbatch
match:    begin|missing|config
```

dbt microbatch requires `begin`; without it the first build and every `--event-time-start` backfill have no lower bound. Proof: `dbt parse` on the duckdb profile errors. Fix: `begin='2025-01-01'`.

## DE-IN9-b — The microbatch parent declares no `event_time`

```defect
id:       DE-IN9-b
file:     analytics/models/marts/product/fct_page_views_batched.sql
line:     12
severity: medium
command:  /audit-data-quality
class:    DE-IN-9
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §9 (model-graph IN-9)
anchor:   from {{ ref('fct_page_views') }}
match:    fct_page_views
match:    event_time|parent|full|every batch
```

`fct_page_views` has no `event_time`, so every daily batch reads the whole parent. Proof V541 over two batches with the query log. Fix: `event_time='viewed_at'` on `fct_page_views`.

## DE-IN10-a — Debezium drops deletes before they reach the lake

```defect
id:       DE-IN10-a
file:     cdc/orders-connector.json
line:     11
severity: high
command:  /audit-data-quality
class:    DE-IN-10
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §10 (10a)
anchor:   "transforms.unwrap.delete.handling.mode": "drop",
match:    orders-connector|delete.handling|tombstone
match:    delete|drop|tombstone
```

`delete.handling.mode=drop` and `drop.tombstones=true`: a deleted order never reaches the landing table (Debezium 3.2 renamed these options — read the image tag). Proof V543 on a scratch connector. Fix: rewrite deletes to a flag the staging model applies.

## DE-IN10-b — The JDBC sink inserts every change event

```defect
id:       DE-IN10-b
file:     cdc/payments-sink.json
line:     7
severity: high
command:  /audit-data-quality
class:    DE-IN-10
owner:    data-engineering
bucket:   report-with-fix
detector: incremental-load-scan §10 (10a, 2c)
anchor:   "insert.mode": "insert",
match:    payments-sink|insert.mode|sink
match:    insert|upsert|duplicat|update|restart|snapshot
```

Updates and a restarted snapshot append the payment again; `insert.mode=insert` over a change topic is an append log, not a table. Proof V540/V543. Fix: `insert.mode=upsert` with `pk.mode=record_key` and delete handling.

## DE-OR1-a — The load computes its day from the wall clock

```defect
id:       DE-OR1-a
file:     dags/orders_daily.py
line:     26
severity: high
command:  /audit-data-quality
class:    DE-OR-1
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §1
anchor:   day = datetime.now().date() - timedelta(days=1)
match:    orders_daily|datetime\.now|load_orders
match:    wall.?clock|interval|replay|backfill|now|logical
```

A backfill of last March reads yesterday's orders; the run is not replayable. Proof V549 (`task.execute` for a past interval). Fix: use `data_interval_start` (or `logical_date`) injected by Airflow.

## DE-OR1-b — The hourly card load bounds its window with `current_date`

```defect
id:       DE-OR1-b
file:     dags/payments_hourly.py
line:     18
severity: high
command:  /audit-data-quality
class:    DE-OR-1
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §1
anchor:   sql="insert into mart.payments select * from staging.card_payments where paid_at >= current_date",
match:    payments_hourly|current_date|card
match:    wall.?clock|interval|replay|now|current_date
```

Every run re-reads the whole day so far, and a replay reads the day it runs on. Proof V549. Fix: `paid_at >= '{{ data_interval_start }}' and paid_at < '{{ data_interval_end }}'` with an explicit interval timetable.

## DE-OR2-a — A secret is fetched at parse time

```defect
id:       DE-OR2-a
file:     dags/orders_daily.py
line:     11
severity: high
command:  /audit-data-quality
class:    DE-OR-2
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §2 (2a AST)
anchor:   PARTNER_API_KEY = Variable.get("partner_api_key")
match:    Variable\.get|parse|module|top.?level
match:    parse|every|import|module|top.?level
```

`Variable.get` at module level runs on every scheduler parse (and, on Airflow 3, cannot reach the metadata DB from the DAG processor). Proof V549 (DagBag import). Fix: read it inside the task.

## DE-OR2-b — A dynamic `start_date`

```defect
id:       DE-OR2-b
file:     dags/inventory_snapshot.py
line:     10
severity: high
command:  /audit-data-quality
class:    DE-OR-2
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §2 (2b)
anchor:   start_date=datetime.now() - timedelta(days=1),
match:    inventory_snapshot|start_date
match:    dynamic|now|never|moving
```

`start_date` moves with every parse, so the interval never closes and the DAG can stop scheduling; Airflow 3 writes a new DAG version per parse. Proof V549. Fix: a fixed date.

## DE-OR3-a — Four concurrent runs write the same payments table

```defect
id:       DE-OR3-a
file:     dags/payments_hourly.py
line:     13
severity: medium
command:  /audit-data-quality
class:    DE-OR-3
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §3
anchor:   max_active_runs=4,
match:    payments_hourly|max_active_runs
match:    overlap|concurren|parallel|interleav|same partition
```

Runs that catch up overlap and their inserts into `mart.payments` interleave (the write is not idempotent). Proof V550. Fix: `max_active_runs=1` (with the user) after making the write replace its interval.

## DE-OR3-b — `catchup=True` from 2019 on a full rebuild

```defect
id:       DE-OR3-b
file:     dags/marketing_attribution.py
line:     12
severity: medium
command:  /audit-data-quality
class:    DE-OR-3
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §3
anchor:   catchup=True,
match:    marketing_attribution|catchup
match:    catchup|2019|history|backfill|flood
```

The first deploy (or a pause) launches ~2,500 runs of a model that rebuilds the full history each time. Proof V550. Fix: `catchup=False`; backfills through `/backfill-plan`.

## DE-OR4-a — The finance publish runs after a failed load

```defect
id:       DE-OR4-a
file:     dags/orders_daily.py
line:     36
severity: high
command:  /audit-data-quality
class:    DE-OR-4
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §4
anchor:   trigger_rule="all_done",
match:    orders_daily|publish|all_done|trigger_rule
match:    fail|regardless|all_done|upstream|stale
```

`all_done` publishes `fct_orders+` over yesterday's data when `load_orders` failed. Proof V551. Fix: `all_success` (the default).

## DE-OR4-b — The rollup refresh runs when either load succeeded

```defect
id:       DE-OR4-b
file:     dags/payments_hourly.py
line:     29
severity: high
command:  /audit-data-quality
class:    DE-OR-4
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §4
anchor:   trigger_rule=TriggerRule.ONE_SUCCESS,
match:    payments_hourly|ONE_SUCCESS|trigger_rule|publish
match:    one_success|fail|partial|half|upstream
```

`ONE_SUCCESS` refreshes `payments_daily` with only card or only bank payments when the other load failed. Proof V551. Fix: `ALL_SUCCESS`.

## DE-OR5-a — Retries around a plain insert

```defect
id:       DE-OR5-a
file:     dags/orders_daily.py
line:     22
severity: high
command:  /audit-data-quality
class:    DE-OR-5
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §5 (+ incremental-load-scan §2)
anchor:   @task(retries=3, retry_delay=timedelta(minutes=5))
match:    retries|load_orders|orders_daily
match:    retr|idempot|insert|duplicat|twice
```

A retry after a partial failure inserts the day's orders again. Proof V540 (`task.execute` twice). Fix: delete-then-insert the day in one transaction (as `stock_levels` does), then keep the retries.

## DE-OR5-b — Prefect retries a non-idempotent POST

```defect
id:       DE-OR5-b
file:     flows/partner_push.py
line:     6
severity: high
command:  /audit-data-quality
class:    DE-OR-5
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §5
anchor:   @task(retries=3, retry_delay_seconds=30)
match:    partner_push|retries|post
match:    retr|idempot|post|duplicat|twice|key
```

A timeout after the partner accepted the batch re-posts it; the partner has no idempotency key. Proof V540 against a stub server. Fix: an idempotency key per batch, or no retries.

## DE-OR6-a — A poke-mode sensor with no timeout

```defect
id:       DE-OR6-a
file:     dags/marketing_attribution.py
line:     14
severity: medium
command:  /audit-data-quality
class:    DE-OR-6
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §6
anchor:   wait_for_orders = ExternalTaskSensor(
match:    ExternalTaskSensor|sensor|wait_for
match:    timeout|poke|slot|forever
```

The default timeout is seven days and `mode="poke"` holds a worker slot the whole time. Proof V551. Fix: `timeout=` and `mode="reschedule"`.

## DE-OR6-b — The month-end sensor waits forever for the bank file

```defect
id:       DE-OR6-b
file:     dags/finance_close.py
line:     14
severity: medium
command:  /audit-data-quality
class:    DE-OR-6
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §6
anchor:   statement = S3KeySensor(
match:    S3KeySensor|sensor|statement
match:    timeout|poke|slot|forever|alert
```

No `timeout` and the default poke mode: a missing statement holds a slot for a week and nobody is alerted. Proof V551. Fix: `timeout`, `mode="reschedule"`, `soft_fail=False` with an alert.

## DE-OR7-a — `{{ execution_date }}` on Airflow 3

```defect
id:       DE-OR7-a
file:     dags/legacy_exports.py
line:     15
severity: high
command:  /audit-data-quality
class:    DE-OR-7
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §7 (pinned apache-airflow==3.0.2)
anchor:   bash_command="python -m larkmoor.exports.partner --day {{ execution_date }}",
match:    execution_date|legacy_exports
match:    airflow 3|removed|AF3|logical_date|3\.0
```

`requirements.txt` pins `apache-airflow==3.0.2`, where `execution_date` is removed from the template context. Proof V549 (render the template on the pinned version). Fix: `{{ logical_date }}` / `{{ ds }}`.

## DE-OR7-b — `DummyOperator` import on Airflow 3

```defect
id:       DE-OR7-b
file:     dags/legacy_exports.py
line:     19
severity: high
command:  /audit-data-quality
class:    DE-OR-7
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §7
anchor:   from airflow.operators.dummy import DummyOperator
match:    DummyOperator|operators\.dummy
match:    airflow 3|removed|EmptyOperator|import
```

The module is gone in Airflow 3; the DAG fails to import. Proof V549 (DagBag import errors). Fix: `EmptyOperator` from the standard provider.

## DE-OR8-a — Cron schedule + `data_interval_*` filter on Airflow 3

```defect
id:       DE-OR8-a
file:     dags/sessions_daily.py
line:     9
severity: high
command:  /audit-data-quality
class:    DE-OR-8
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §8
anchor:   schedule="30 1 * * *",
match:    sessions_daily|cron|schedule|data_interval
match:    zero|empty|width|CronTriggerTimetable|interval|no rows
```

A cron string maps to `CronTriggerTimetable` in Airflow 3, so `data_interval_start == data_interval_end`: the delete and insert select nothing and the run succeeds. Proof V549 (render the interval). Fix: `CronDataIntervalTimetable` or `create_cron_data_intervals=True`.

## DE-OR8-b — `@daily` + `data_interval_*` on Airflow 3

```defect
id:       DE-OR8-b
file:     dags/refunds_daily.py
line:     9
severity: high
command:  /audit-data-quality
class:    DE-OR-8
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §8
anchor:   schedule="@daily",
match:    refunds_daily|@daily|schedule|data_interval
match:    zero|empty|width|interval|no rows|CronTrigger
```

Presets are cron too: the refunds copy reads a zero-width interval and loads nothing. Proof V549. Fix: an explicit interval timetable.

## DE-OR9-a — `context.partition_key` under `BackfillPolicy.single_run`

```defect
id:       DE-OR9-a
file:     assets/finance_assets.py
line:     15
severity: high
command:  /audit-data-quality
class:    DE-OR-9
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §9
anchor:   day = context.partition_key
match:    partition_key|single_run|ledger_daily
match:    range|single.?run|backfill|one partition
```

A range backfill hands the asset a partition range in one run; `partition_key` raises or builds one day. Proof V550. Fix: `context.partition_key_range` / `partition_time_window`.

## DE-OR9-b — A non-blocking balance check on an asset with dependants

```defect
id:       DE-OR9-b
file:     assets/finance_assets.py
line:     25
severity: high
command:  /audit-data-quality
class:    DE-OR-9
owner:    data-engineering
bucket:   report-with-fix
detector: orchestration-scan §9
anchor:   @asset_check(asset=ledger_daily)
match:    asset_check|ledger_balances|ledger_daily
match:    block|non.?blocking|downstream|monthly
```

Asset checks do not block by default: an unbalanced `ledger_daily` still materializes `ledger_monthly`. Proof V553 (plant an imbalance). Fix: `blocking=True`.

## DE-DQ1-a — The refunds mart has no grain test

```defect
id:       DE-DQ1-a
file:     analytics/models/marts/finance/refunds_ledger.sql
line:     1
severity: medium
command:  /audit-data-quality
class:    DE-DQ-1
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §1 (model-graph DQ-1)
anchor:   {{ config(materialized='table') }}
match:    refunds_ledger
match:    grain|unique|not.?null|test
```

No `unique`/`not_null` on `refund_id` and no combination test: a duplicated refund reaches finance silently. Proof V553 (plant a duplicate → still green). Fix: `unique` + `not_null` on `refund_id`.

## DE-DQ1-b — The LTV model the marketing marts read has no grain test

```defect
id:       DE-DQ1-b
file:     analytics/models/intermediate/int_customer_ltv.sql
line:     1
severity: medium
command:  /audit-data-quality
class:    DE-DQ-1
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §1 (model-graph DQ-1)
anchor:   with orders as (
match:    int_customer_ltv|ltv
match:    grain|unique|not.?null|test
```

`customer_id` carries no test; a fan-out in the refunds join would double LTV in the newsletter audience. Proof V553. Fix: `unique` + `not_null` on `customer_id`.

## DE-DQ2-a — The event grain test runs at `severity: warn`

```defect
id:       DE-DQ2-a
file:     analytics/models/marts/product/_product.yml
line:     10
severity: medium
command:  /audit-data-quality
class:    DE-DQ-2
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §2 (model-graph DQ-2)
anchor:   - unique:
match:    fct_events|event_id|unique
match:    warn|severity|exit|cannot fail
```

A duplicated `event_id` exits 0 (dbt build passes). Proof V553 on duckdb. Fix: severity `error` (precedent § 3 covers advisory tests, not keys).

## DE-DQ2-b — `accepted_values` on `entry_event` only checks today's sessions

```defect
id:       DE-DQ2-b
file:     analytics/models/marts/product/_product.yml
line:     34
severity: medium
command:  /audit-data-quality
class:    DE-DQ-2
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §2 (2a, model-graph DQ-2)
anchor:   where: "started_at >= current_date"
match:    entry_event|accepted_values|where|fct_sessions
match:    empty|slice|current_date|where|cannot fail
```

Before the first session of the day the slice is empty and the test passes; history is never checked. Proof V553 with no row today. Fix: drop the `where:` or add a full-table test beside it (precedent § 4).

## DE-DQ3-a — CI runs `dbt run` and never `dbt build`/`test`

```defect
id:       DE-DQ3-a
file:     .github/workflows/dbt-ci.yml
line:     10
severity: medium
command:  /audit-data-quality
class:    DE-DQ-3
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §3 (3a, 3b)
anchor:   - run: dbt run --select marts+ --project-dir analytics --target dev
match:    dbt-ci|dbt run|marts\+
match:    test|build|never|run only|select
```

No data test executes in CI, and `marts+` leaves source tests out. Proof V554 (a failing test leaves the job green). Fix: `dbt build --select +marts+`.

## DE-DQ3-b — Freshness failures are swallowed with `|| true`

```defect
id:       DE-DQ3-b
file:     .github/workflows/dbt-ci.yml
line:     11
severity: medium
command:  /audit-data-quality
class:    DE-DQ-3
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §3 (3c)
anchor:   dbt source freshness --project-dir analytics --target dev || true
match:    freshness|\|\| true
match:    swallow|true|exit|never fail|ignored
```

A stale source never fails CI. Proof V554. Fix: remove `|| true`.

## DE-DQ4-a — `shop.orders` overrides freshness with `warn_after` only

```defect
id:       DE-DQ4-a
file:     analytics/models/staging/_sources.yml
line:     14
severity: medium
command:  /audit-data-quality
class:    DE-DQ-4
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §4 (model-graph DQ-4)
anchor:   warn_after: {count: 2, period: hour}
match:    orders|freshness|warn_after
match:    error_after|warn|never fail|override
```

The table-level `freshness:` replaces the source's (which had `error_after`), so stale orders only warn. Proof V555. Fix: add `error_after` to the table override.

## DE-DQ4-b — `ads.impressions` has no freshness check

```defect
id:       DE-DQ4-b
file:     analytics/models/staging/_sources.yml
line:     65
severity: medium
command:  /audit-data-quality
class:    DE-DQ-4
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §4 (model-graph DQ-4)
anchor:         - name: impressions
match:    impressions|ads|freshness
match:    no freshness|missing|stale|freshness
```

The `ads` source declares no freshness (its sibling `spend` does at table level). Proof V555. Fix: `freshness` with `error_after` and `loaded_at_field`.

## DE-DQ5-a — `relationships` on a nullable key that the email join leaves NULL

```defect
id:       DE-DQ5-a
file:     analytics/models/marts/core/_order_lines.yml
line:     26
severity: medium
command:  /audit-data-quality
class:    DE-DQ-5
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §5 (model-graph DQ-5)
anchor:   - relationships:
match:    customer_id|relationships|order_lines
match:    null|not_null|nullable|pass
```

The join on e-mail (DE-GR2-a) leaves `customer_id` NULL for guests and mismatches, and `relationships` passes NULLs by design. Proof V553 (a NULL row stays green). Fix: `not_null` (the key is business-mandatory here; precedent § 10 flips back).

## DE-DQ5-b — A CASE on `method` with no `accepted_values`

```defect
id:       DE-DQ5-b
file:     analytics/models/marts/finance/rpt_payment_methods.sql
line:     4
severity: medium
command:  /audit-data-quality
class:    DE-DQ-5
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §5 (model-graph DQ-5)
anchor:   case method
match:    method|case|rpt_payment_methods
match:    accepted_values|else|new|member|enum
```

A new payment method falls into `else 'card'` silently (the October snapshot already has `bnpl`, DE-SC5-b). Proof V553. Fix: `accepted_values` on `stg_payments.method` and an explicit `else null`.

## DE-DQ6-a — The payments rollup is never compared with its detail

```defect
id:       DE-DQ6-a
file:     analytics/models/marts/finance/payments_daily.sql
line:     2
severity: medium
command:  /audit-data-quality
class:    DE-DQ-6
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §6 (model-graph DQ-6)
anchor:   date(paid_at) as paid_day,
match:    payments_daily|rollup
match:    reconcil|equal|detail|compar|sum
```

`orders_daily` has a singular test that ties it to `fct_orders`; `payments_daily` has none. Proof V564. Fix: an equality test against `fct_payments` per day and method.

## DE-DQ6-b — The sessions rollup is never compared with its detail

```defect
id:       DE-DQ6-b
file:     analytics/models/marts/product/sessions_daily.sql
line:     1
severity: medium
command:  /audit-data-quality
class:    DE-DQ-6
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §6 (model-graph DQ-6)
anchor:   select date(started_at) as session_day, count(*) as sessions
match:    sessions_daily|rollup
match:    reconcil|equal|detail|compar|count
```

Proof V564. Fix: `dbt_utils.equal_rowcount`-style comparison with `fct_sessions` per day.

## DE-DQ7-a — The events source has no row-count check

```defect
id:       DE-DQ7-a
file:     analytics/models/staging/_sources.yml
line:     25
severity: medium
command:  /audit-data-quality
class:    DE-DQ-7
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §7 (model-graph DQ-7)
anchor:         - name: events
match:    events|row.?count|source
match:    empty|zero|row.?count|no rows
```

Every other `shop` table carries `expect_table_row_count_to_be_between(min_value: 1)`; an empty events load passes every column test. Proof V556. Fix: the same row-count test.

## DE-DQ7-b — Soda checks for payments pass on an empty table

```defect
id:       DE-DQ7-b
file:     soda/checks_payments.yml
line:     1
severity: medium
command:  /audit-data-quality
class:    DE-DQ-7
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §7 (2c)
anchor:   checks for payments:
match:    soda|payments|checks
match:    row_count|empty|zero|pass
```

`missing_count` and `duplicate_count` are 0 on an empty dataset; only `refunds` has `row_count > 0`. Proof V556. Fix: `row_count > 0`.

## DE-DQ8-a — Window-based incremental logic with no unit test

```defect
id:       DE-DQ8-a
file:     analytics/models/marts/product/fct_sessions.sql
line:     1
severity: low
command:  /audit-data-quality
class:    DE-DQ-8
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §8 (model-graph DQ-8)
anchor:   {{ config(
match:    fct_sessions|unit
match:    unit.?test|window|incremental|logic
```

The dedup window and the incremental branch are never exercised with fixed inputs. Proof V553 via a dbt unit test overriding `is_incremental`. Fix: `unit_tests:` for `fct_sessions`.

## DE-DQ8-b — CASE logic in a microbatch model with no unit test

```defect
id:       DE-DQ8-b
file:     analytics/models/marts/product/fct_ad_spend.sql
line:     1
severity: low
command:  /audit-data-quality
class:    DE-DQ-8
owner:    data-engineering
bucket:   report-with-fix
detector: data-test-scan §8 (model-graph DQ-8)
anchor:   {{ config(
match:    fct_ad_spend|unit
match:    unit.?test|case|incremental|logic
```

Proof V553 via a unit test. Fix: `unit_tests:` covering negative spend.

## DE-SC1-a — `fct_payments` is `access: public` with no enforced contract

```defect
id:       DE-SC1-a
file:     analytics/models/marts/finance/fct_payments.sql
line:     1
severity: medium
command:  /audit-data-quality
class:    DE-SC-1
owner:    data-engineering
bucket:   report-with-fix
detector: contract-diff §1 (model-graph SC-1)
anchor:   {{ config(
match:    fct_payments|contract|public
match:    contract|enforc|public|publish
```

Read by the acquiring-bank feed (`finance-feed.export.ts`) and declared public, yet its shape can change in any merge. Proof V557. Fix: `contract: {enforced: true}` with a `data_type` per column.

## DE-SC1-b — A foreign key on BigQuery treated as a guarantee

```defect
id:       DE-SC1-b
file:     analytics/models/marts/core/_order_lines.yml
line:     22
severity: medium
command:  /audit-data-quality
class:    DE-SC-1
owner:    data-engineering
bucket:   report-with-fix
detector: contract-diff §1 (model-graph SC-1)
anchor:   constraints: [{type: foreign_key, to: "ref('stg_products')", to_columns: [product_id]}]
match:    product_id|foreign_key|order_lines
match:    metadata|enforc|bigquery|test|not enforced
```

BigQuery keeps foreign keys as metadata; no `relationships` test covers `product_id`. Proof V553 (an orphan product id passes). Fix: a `relationships` test (precedent § 11).

## DE-SC2-a — v2 drops `phone_number` and v1 has no `deprecation_date`

```defect
id:       DE-SC2-a
file:     analytics/models/marts/core/_dim_customers.yml
line:     15
severity: high
command:  /audit-data-quality
class:    DE-SC-2
owner:    data-engineering
bucket:   report-flagged
detector: contract-diff §2 (0a)
anchor:         - v: 1
match:    dim_customers|version|v1|v: 1
match:    deprecation|phone|breaking|remov|version
```

The CRM sync (`dags/reverse_etl_sync.py`) reads `phone_number`; nothing tells it when v1 disappears. Unproven link: whether the sync pins v1. Settling: V557 (`dbt build` with v1 removed). Fix: `deprecation_date` on v1 and notice to the reader.

## DE-SC2-b — `revenue_by_order` v2 narrows `amount` numeric→int64 with no deprecation date

```defect
id:       DE-SC2-b
file:     analytics/models/marts/finance/_finance.yml
line:     76
severity: high
command:  /audit-data-quality
class:    DE-SC-2
owner:    data-engineering
bucket:   report-flagged
detector: contract-diff §2 (0a)
anchor:         - v: 1
match:    revenue_by_order|amount|version|v: 1
match:    int64|numeric|narrow|deprecation|breaking
```

The exposure `revenue_reporting` reads the model; v1 has no `deprecation_date`. Settling: V557. Fix: `deprecation_date` and a migration window.

## DE-SC3-a — The partner file is `select *` from the dimension

```defect
id:       DE-SC3-a
file:     analytics/models/marts/core/rpt_customer_export.sql
line:     2
severity: low
command:  /audit-data-quality
class:    DE-SC-3
owner:    data-engineering
bucket:   report-with-fix
detector: contract-diff §3 (model-graph SC-3)
anchor:   select * from {{ ref('dim_customers') }}
match:    rpt_customer_export|select \*
match:    shape|upstream|column|explicit|star
```

Any column added to `dim_customers` (an internal flag, a new PII field) lands in the partner's file. Proof V557. Fix: an explicit column list.

## DE-SC3-b — `select *` past staging

```defect
id:       DE-SC3-b
file:     analytics/models/intermediate/int_orders_enriched.sql
line:     2
severity: low
command:  /audit-data-quality
class:    DE-SC-3
owner:    data-engineering
bucket:   report-with-fix
detector: contract-diff §3 (model-graph SC-3)
anchor:   select * from {{ ref('stg_orders') }}
match:    int_orders_enriched|select \*
match:    shape|upstream|column|explicit|star
```

Proof V557. Fix: an explicit column list.

## DE-SC4-a — The app drops a column the dbt source and the CDC connector still read

```defect
id:       DE-SC4-a
file:     apps/reporting/migrations/Migration20261012000000_drop_legacy_status.ts
line:     6
severity: high
command:  /audit-data-quality
class:    DE-SC-4
owner:    data-engineering
bucket:   report-with-fix
detector: contract-diff §4 (4a/4b)
anchor:   alter table "orders" drop column "legacy_status";
match:    legacy_status|drop column
match:    reader|source|connector|cdc|stg_orders|break
```

Readers: `analytics/models/staging/_sources.yml`, `stg_orders.sql`, `cdc/orders-connector.json` (`column.include.list`). Proof V558 (apply to a scratch DB, build `stg_orders`). Fix: expand/contract — move the readers first.

## DE-SC4-b — A rename under the staging model, the snapshot and the CRM sync

```defect
id:       DE-SC4-b
file:     apps/reporting/migrations/20261015_rename_phone.ts
line:     5
severity: high
command:  /audit-data-quality
class:    DE-SC-4
owner:    data-engineering
bucket:   report-with-fix
detector: contract-diff §4 (4a/4b)
anchor:   table.renameColumn('phone_number', 'phone');
match:    phone_number|rename
match:    reader|stg_customers|snapshot|crm|reverse|break
```

`stg_customers.sql`, `customers_snapshot.sql` and `dags/reverse_etl_sync.py` read `phone_number`. Proof V558. Fix: add `phone`, move readers, drop later.

## DE-SC5-a — A unit change under the same column name

```defect
id:       DE-SC5-a
file:     analytics/models/staging/stg_refunds.sql
line:     7
severity: high
command:  /audit-data-quality
class:    DE-SC-5
owner:    data-engineering
bucket:   report-flagged
detector: contract-diff §5 (data lane: warehouse/snapshots/refunds_*.csv)
anchor:   refund_amount_minor / 100.0 as refund_amount,
match:    refund_amount|stg_refunds|unit
match:    unit|major|minor|100|magnitude|semantic
```

Since the 2026-10 export the source sends major units in `refund_amount_minor`; the two snapshots differ by ~100× with the row count stable. Nothing fails; net revenue moves. Settling: V553 with a magnitude bound. Fix: stop dividing for the new export (versioned), and a distribution test.

## DE-SC5-b — A new payment method appears in the data

```defect
id:       DE-SC5-b
file:     warehouse/snapshots/payments_2026-10.csv
line:     3
severity: high
command:  /audit-data-quality
class:    DE-SC-5
owner:    data-engineering
bucket:   report-flagged
detector: contract-diff §5 (data lane)
anchor:   p4,bnpl,2500
match:    bnpl|method|payments
match:    new|member|enum|else|semantic|card
```

`bnpl` is absent from the September snapshot and present in October; `rpt_payment_methods` sends it to `else 'card'`. Settling: V553 (`accepted_values` red on the October snapshot). Fix: see DE-DQ5-b.

## DE-SC6-a — Local wall-clock time cast to an instant

```defect
id:       DE-SC6-a
file:     analytics/models/staging/stg_events.sql
line:     6
severity: medium
command:  /audit-data-quality
class:    DE-SC-6
owner:    data-engineering
bucket:   report-with-fix
detector: contract-diff §6 (6a)
anchor:   cast(occurred_at_local as timestamp) as occurred_at,
match:    occurred_at|stg_events|cast
match:    local|zone|utc|timestamp|shift
```

The tracker sends the visitor's local time; `cast(... as timestamp)` on BigQuery reads it as UTC, shifting every event by the visitor's offset. Proof V552. Fix: carry the offset, or `timestamp(occurred_at_local, visitor_zone)`.

## DE-SC6-b — `timestamptz` cast to naive on landing

```defect
id:       DE-SC6-b
file:     etl/sql/load_payments.sql
line:     3
severity: medium
command:  /audit-data-quality
class:    DE-SC-6
owner:    data-engineering
bucket:   report-with-fix
detector: contract-diff §6 (6a)
anchor:   select payment_id, order_id, amount_cents, paid_at::timestamp
match:    paid_at|load_payments|::timestamp
match:    zone|timestamptz|naive|session|shift
```

`paid_at::timestamp` converts at the session `TimeZone`; a loader with a non-UTC session shifts every payment. Proof V552. Fix: keep `timestamptz` (or `at time zone 'UTC'` explicitly).

## DE-LN1-a — A hard-coded raw relation in staging

```defect
id:       DE-LN1-a
file:     analytics/models/staging/stg_payments.sql
line:     9
severity: medium
command:  /audit-data-quality
class:    DE-LN-1
owner:    data-engineering
bucket:   report-with-fix
detector: lineage-trace §1 (model-graph LN-1)
anchor:   from analytics_raw.payments
match:    analytics_raw|stg_payments|hard.?coded
match:    source\(|ref\(|hard.?coded|graph|lineage
```

The graph has no parent for `stg_payments`, so a fresh build can run it before the raw table lands and a trace from payments stops here. Proof V559. Fix: declare `raw.payments` and use `source()`.

## DE-LN1-b — A mart reads a raw table by name

```defect
id:       DE-LN1-b
file:     analytics/models/marts/finance/payouts.sql
line:     3
severity: medium
command:  /audit-data-quality
class:    DE-LN-1
owner:    data-engineering
bucket:   report-with-fix
detector: lineage-trace §1 (model-graph LN-1)
anchor:   from analytics_raw.payouts
match:    analytics_raw|payouts|hard.?coded
match:    source\(|ref\(|hard.?coded|graph|lineage
```

Proof V559. Fix: a source and a staging model for payouts.

## DE-LN2-a — A mart reads `source()` directly

```defect
id:       DE-LN2-a
file:     analytics/models/marts/finance/refunds_ledger.sql
line:     9
severity: low
command:  /audit-data-quality
class:    DE-LN-2
owner:    data-engineering
bucket:   report-with-fix
detector: lineage-trace §2 (model-graph LN-2)
anchor:   from {{ source('shop', 'refunds') }}
match:    refunds_ledger|source
match:    layer|staging|mart|direct
```

`stg_refunds` exists (and carries the unit conversion); the mart bypasses it. Proof V559. Fix: `ref('stg_refunds')`.

## DE-LN2-b — A staging model joins two sources

```defect
id:       DE-LN2-b
file:     analytics/models/staging/stg_sessions.sql
line:     7
severity: low
command:  /audit-data-quality
class:    DE-LN-2
owner:    data-engineering
bucket:   report-with-fix
detector: lineage-trace §2 (model-graph LN-2)
anchor:   left join {{ source('shop', 'orders') }} o on o.session_id = s.session_id
match:    stg_sessions|source
match:    staging|join|two sources|layer
```

Proof V559. Fix: join in an intermediate model.

## DE-LN3-a — The bank feed reads `fct_payments` with no exposure

```defect
id:       DE-LN3-a
file:     apps/reporting/src/exports/finance-feed.export.ts
line:     6
severity: medium
command:  /audit-data-quality
class:    DE-LN-3
owner:    data-engineering
bucket:   report-with-fix
detector: lineage-trace §3 (3b)
anchor:   query: 'select payment_id, amount_cents, paid_at from analytics.fct_payments where date(paid_at) = @day',
match:    fct_payments|finance-feed|exposure
match:    exposure|undeclared|reader|lineage|consumer
```

A breaking change to `fct_payments` would not list the acquiring-bank feed. Fix: an `exposures:` entry for the feed.

## DE-LN3-b — The CRM sync reads `dim_customers` with no exposure

```defect
id:       DE-LN3-b
file:     dags/reverse_etl_sync.py
line:     15
severity: medium
command:  /audit-data-quality
class:    DE-LN-3
owner:    data-engineering
bucket:   report-with-fix
detector: lineage-trace §3 (3b)
anchor:   cur.execute("select customer_id, email, full_name, phone_number from analytics.dim_customers")
match:    dim_customers|reverse_etl|crm
match:    exposure|undeclared|reader|lineage|consumer
```

It reads `phone_number`, which v2 drops (DE-SC2-a). Fix: an exposure for the sync.

## DE-LN4-a — A staging model nothing reads

```defect
id:       DE-LN4-a
file:     analytics/models/staging/stg_sessions.sql
line:     1
severity: low
command:  /audit-data-quality
class:    DE-LN-4
owner:    data-engineering
bucket:   report-with-fix
detector: lineage-trace §4 (model-graph LN-4)
anchor:   select
match:    stg_sessions
match:    orphan|unused|no reader|unread|nothing reads
```

No model, test or exposure reads `stg_sessions`; it is built every run. Retirement is the owner's call.

## DE-LN4-b — A source declared and never read

```defect
id:       DE-LN4-b
file:     analytics/models/staging/_sources.yml
line:     56
severity: low
command:  /audit-data-quality
class:    DE-LN-4
owner:    data-engineering
bucket:   report-with-fix
detector: lineage-trace §4 (model-graph LN-4)
anchor:         - name: legacy_coupons
match:    legacy_coupons
match:    orphan|unused|never read|unread
```

Its row-count test still runs every build. Fix: remove the declaration (owner's call).

## DE-MV1-a — A cron increments the daily counter

```defect
id:       DE-MV1-a
file:     apps/reporting/src/reports/sales-counter.job.ts
line:     18
severity: high
command:  /audit-data-quality
class:    DE-MV-1
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §1
anchor:   update daily_sales set orders_count = orders_count + 1
match:    daily_sales|orders_count|sales-counter
match:    increment|\+ ?1|replay|overlap|twice|idempot|double
```

The five-minute window and the cron overlap a slow run, so an order paid at the boundary is counted twice; a crash mid-loop leaves half the increments. Proof V547 (run twice → counter ≠ recompute). Fix: recompute and replace the day (the `order-day-rollup.ts` shape).

## DE-MV1-b — A retried BullMQ job increments usage

```defect
id:       DE-MV1-b
file:     apps/reporting/src/reports/usage-counter.processor.ts
line:     14
severity: high
command:  /audit-data-quality
class:    DE-MV-1
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §1
anchor:   .increment('calls', job.data.calls);
match:    api_usage_daily|increment|usage
match:    retr|attempt|twice|idempot|double|replay
```

`notifyQuota` can fail after the increment; BullMQ retries (5 attempts) and the calls are counted again. Proof V547. Fix: a processed-jobs key in the same transaction (precedent § 20).

## DE-MV2-a — Net revenue is recomputed for two days; refunds land for 60

```defect
id:       DE-MV2-a
file:     apps/reporting/src/reports/revenue-rollup.job.ts
line:     17
severity: high
command:  /audit-data-quality
class:    DE-MV-2
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §2
anchor:   where o.created_at >= now() - interval '2 days'
match:    revenue_daily|revenue-rollup|2 days|window
match:    refund|late|after|window|restat
```

A refund on day 5 never restates day 1's `net_cents`. Proof V548. Fix: recompute the days the refunds touch (dirty markers from refund writes).

## DE-MV2-b — A closed-period snapshot shown as the merchant's balance "right now"

```defect
id:       DE-MV2-b
file:     apps/reporting/src/reports/merchant-snapshot.job.ts
line:     13
severity: high
command:  /audit-data-quality
class:    DE-MV-2
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §2 (2b)
anchor:   insert into merchant_snapshots (merchant_id, period_end, balance_cents)
match:    merchant_snapshots|snapshot
match:    current|point.?in.?time|right now|stale|as of
```

`merchant-dashboard.controller.ts` returns yesterday's snapshot as `currentBalanceCents` under the title "Your balance right now". Two-ended: the job and the reader. Fix: compute the live balance, or label it "as of <period_end>" (precedent § 38 flips back).

## DE-MV3-a — An incrementally maintained usage table nothing reconciles

```defect
id:       DE-MV3-a
file:     apps/reporting/migrations/Migration20260305000000_reporting_tables.ts
line:     14
severity: medium
command:  /audit-data-quality
class:    DE-MV-3
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §3
anchor:   create table "api_usage_daily" (
match:    api_usage_daily
match:    reconcil|never|drift|recompute|compar
```

Increments are the only writer and no job compares it with the request log, so drift from DE-MV1-b is invisible. Proof V564. Fix: a nightly recompute that marks drift and fails.

## DE-MV3-b — The inventory reconciliation only logs

```defect
id:       DE-MV3-b
file:     apps/reporting/src/reports/inventory-stats.reconcile.ts
line:     20
severity: medium
command:  /audit-data-quality
class:    DE-MV-3
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §3
anchor:   inventory_stats drift in
match:    inventory_stats|reconcil
match:    log|warn|only|nothing|act
```

Drift is found and written to a warn log; nothing is corrected or failed. Proof V564. Fix: mark the warehouses stale and recompute them, and fail the run.

## DE-MV4-a — The revenue dirty-day trigger misses the columns the rollup sums

```defect
id:       DE-MV4-a
file:     apps/reporting/migrations/Migration20260310000000_rollup_triggers.ts
line:     15
severity: medium
command:  /audit-data-quality
class:    DE-MV-4
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §4 (4a)
anchor:   after update of "status", "created_at" on "orders"
match:    trigger|revenue|update of
match:    total_cents|column|missing|cover|refund|insert|delete
```

It fires on `status` and `created_at` only: an amount correction (`total_cents`), a new order and a delete never mark the day, and refunds are another table. Two-ended: the trigger list and the rollup's select. Fix: insert/update-of-every-read-column/delete triggers, and a spec holding the lists equal.

## DE-MV4-b — A truncate reload bypasses the row trigger that keeps `order_item_counts`

```defect
id:       DE-MV4-b
file:     apps/reporting/src/reports/inventory-import.job.ts
line:     13
severity: medium
command:  /audit-data-quality
class:    DE-MV-4
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §4 (4b)
anchor:   truncate table order_items
match:    order_items|truncate|order_item_counts
match:    trigger|bypass|truncate|counter|insert.?only
```

`TRUNCATE` fires no row trigger and the counter trigger is insert-only: after each nightly reload the counts double. Proof V564. Fix: recompute `order_item_counts` after the load (or replace the trigger with a recompute).

## DE-MV5-a — `now()` in a view refreshed weekly

```defect
id:       DE-MV5-a
file:     apps/reporting/migrations/Migration20260320000000_materialized_views.ts
line:     9
severity: medium
command:  /audit-data-quality
class:    DE-MV-5
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §5 (5c)
anchor:   where created_at > now() - interval '30 days'
match:    merchant_balances_mv|now\(\)
match:    frozen|refresh|weekly|now|stale
```

The 30-day window is frozen at Monday's refresh; by Sunday it covers days 6–36. Proof V563/V564. Fix: drop the window from the view and filter at read time (precedent § 26 flips back: weekly ≫ window granularity).

## DE-MV5-b — `CONCURRENTLY` on a view with no unique index

```defect
id:       DE-MV5-b
file:     apps/reporting/src/reports/mv-refresh.job.ts
line:     12
severity: medium
command:  /audit-data-quality
class:    DE-MV-5
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §5 (5b)
anchor:   refresh materialized view concurrently top_products_mv
match:    top_products_mv|concurrently
match:    unique index|fail|index
```

Postgres refuses `REFRESH … CONCURRENTLY` without a unique index on plain columns; every refresh fails and the storefront strip goes stale. Proof V563. Fix: `create unique index on top_products_mv (product_id)`.

## DE-MV6-a — A tenant-zone screen sums UTC-day facts

```defect
id:       DE-MV6-a
file:     apps/reporting/src/reports/tenant-sales.query.ts
line:     7
severity: medium
command:  /audit-data-quality
class:    DE-MV-6
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §6
anchor:   from order_day_facts
match:    order_day_facts|tenant|zone
match:    utc|zone|local|quarter|bucket
```

`timeZone` is accepted and unused: a UTC+3 tenant's 22:30Z sale lands on the wrong local day. The quarter-hour facts beside it can re-bucket any zone (precedent § 21 flips back). Proof V564. Fix: read `order_quarter_facts` bucketed in the tenant's zone.

## DE-MV6-b — Billing shows UTC-day usage as local days

```defect
id:       DE-MV6-b
file:     apps/reporting/src/reports/usage-report.service.ts
line:     10
severity: medium
command:  /audit-data-quality
class:    DE-MV-6
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §6
anchor:   select('day', 'calls')
match:    api_usage_daily|tenantZone|usage
match:    utc|zone|local|day|bucket
```

`api_usage_daily.day` is a UTC date; the page labels it in the tenant's zone. Proof V564. Fix: keep hourly usage and bucket per zone (zone policy: business `report-scan` §8).

## DE-TB1-a — One `AT TIME ZONE` on a naive UTC column

```defect
id:       DE-TB1-a
file:     apps/reporting/src/reports/hourly-orders.query.ts
line:     6
severity: high
command:  /audit-data-quality
class:    DE-TB-1
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §7 (7a × 7b)
anchor:   select date_trunc('day', created_at at time zone ?) as local_day, count(*) as events
match:    created_at|at time zone|events
match:    naive|timestamp\(3\)|without time zone|direction|wrong way|two|UTC
```

`events.created_at` is `timestamp(3)` holding UTC; one conversion treats it as local time in the zone and shifts the wrong way. Proof V552 (2026-06-01T22:30Z). Fix: `(created_at at time zone 'UTC') at time zone ?` (precedent § 27).

## DE-TB1-b — One `AT TIME ZONE` on `timestamp without time zone`

```defect
id:       DE-TB1-b
file:     apps/reporting/src/reports/page-view-buckets.query.ts
line:     6
severity: high
command:  /audit-data-quality
class:    DE-TB-1
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §7 (7a × 7b)
anchor:   select to_char(viewed_at at time zone ?, 'YYYY-MM-DD') as day, count(*) as views
match:    viewed_at|at time zone|page_views
match:    naive|without time zone|direction|wrong way|two|UTC
```

Proof V552. Fix: the double conversion, or migrate the column to `timestamptz`.

## DE-TB2-a — `BETWEEN` with the next window's start as the upper bound

```defect
id:       DE-TB2-a
file:     apps/reporting/src/reports/window-report.query.ts
line:     8
severity: medium
command:  /audit-data-quality
class:    DE-TB-2
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §8
anchor:   where tenant_id = ? and created_at between ? and ?
match:    between|created_at|window
match:    inclusive|boundary|midnight|twice|half.?open
```

An order at exactly Monday 00:00 counts in both weeks. Proof V552. Fix: `>= start and < nextStart`.

## DE-TB2-b — `whereBetween` on instants double-counts a payment at the month boundary

```defect
id:       DE-TB2-b
file:     apps/reporting/src/reports/payouts-report.query.ts
line:     7
severity: medium
command:  /audit-data-quality
class:    DE-TB-2
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §8
anchor:   .whereBetween('paid_at', [monthStart, nextMonthStart])
match:    whereBetween|paid_at|payout
match:    inclusive|boundary|midnight|twice|half.?open
```

Proof V552. Fix: `where('paid_at', '>=', monthStart).where('paid_at', '<', nextMonthStart)`.

## DE-TB3-a — Named-zone `CONVERT_TZ` with no zone tables loaded

```defect
id:       DE-TB3-a
file:     apps/reporting/src/legacy-mysql/settlement.query.ts
line:     6
severity: high
command:  /audit-data-quality
class:    DE-TB-3
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §9
anchor:   CONVERT_TZ(paid_at, '+00:00', 'Asia/Riyadh')
match:    CONVERT_TZ|Asia/Riyadh|settlement
match:    zone table|NULL|mysql_tzinfo|named
```

The legacy MySQL image loads no zone tables (9b: no `mysql_tzinfo_to_sql` anywhere), so every settlement day is NULL. Proof V552 on a scratch MySQL. Fix: load the zone tables or use `'+03:00'` (Riyadh has no DST).

## DE-TB3-b — Named zones in `CONVERT_TZ` return NULL

```defect
id:       DE-TB3-b
file:     apps/reporting/src/legacy-mysql/daily-orders.query.ts
line:     6
severity: high
command:  /audit-data-quality
class:    DE-TB-3
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §9
anchor:   CONVERT_TZ(created_at, 'UTC', 'Europe/Berlin')
match:    CONVERT_TZ|Europe/Berlin
match:    zone table|NULL|mysql_tzinfo|named
```

Proof V552. Fix: load the zone tables (Berlin has DST, so a fixed offset is not an option).

## DE-TB4-a — A fixed `+01` offset for Berlin

```defect
id:       DE-TB4-a
file:     apps/reporting/src/reports/berlin-sales.query.ts
line:     6
severity: medium
command:  /audit-data-quality
class:    DE-TB-4
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §10
anchor:   at time zone '+01'
match:    \+01|berlin
match:    DST|summer|offset|Europe/Berlin|fixed
```

From the last Sunday of March to the last Sunday of October Berlin is UTC+2; an hour of every summer day lands on the wrong date (and POSIX sign rules make `'+01'` mean UTC−1 in Postgres). Proof V552. Fix: `at time zone 'Europe/Berlin'`.

## DE-TB4-b — A five-hour shift as New York time

```defect
id:       DE-TB4-b
file:     apps/reporting/src/reports/us-sales.query.ts
line:     6
severity: medium
command:  /audit-data-quality
class:    DE-TB-4
owner:    data-engineering
bucket:   report-with-fix
detector: derived-data-scan §10
anchor:   created_at - interval '5 hours'
match:    5 hours|nyc|interval
match:    DST|offset|America/New_York|fixed|shift
```

New York is UTC−4 from March to November. Proof V552 (2026-03-08, 2026-11-01). Fix: `at time zone 'America/New_York'`.

## DE-EX1-a — OFFSET paging newest-first over the activity log the same module appends to

```defect
id:       DE-EX1-a
file:     apps/reporting/src/exports/activity-export.runner.ts
line:     13
severity: medium
command:  /audit-data-quality
class:    DE-EX-1
owner:    data-engineering
bucket:   report-with-fix
detector: extract-scan §1 (1a + 1c)
anchor:   const batch = await this.activity.list({ tenantId, page, pageSize: PAGE });
match:    activity|page|offset
match:    offset|keyset|newest|duplicat|skip|insert|mutat
```

`ActivityPort.list` sorts `createdAt desc` with `offset`; every request appends a row (`activity.service.ts`), so a row added mid-export shifts later pages and a boundary row appears twice. Proof V560. Fix: keyset on `(created_at, id)` compared in SQL (the orders export's shape).

## DE-EX1-b — OFFSET over customers ordered by `created_at desc`

```defect
id:       DE-EX1-b
file:     apps/reporting/src/exports/customers-export.runner.ts
line:     13
severity: medium
command:  /audit-data-quality
class:    DE-EX-1
owner:    data-engineering
bucket:   report-with-fix
detector: extract-scan §1 (1a + 1c)
anchor:   for (let offset = 0; ; offset += PAGE) {
match:    customers|offset
match:    offset|keyset|newest|duplicat|skip|insert|mutat
```

Customers sign up during the nightly export; the first page shifts. Proof V560. Fix: keyset on `(created_at, id)`, or one `REPEATABLE READ` snapshot.

## DE-EX2-a — The platform dump reads each page of each table in its own statement

```defect
id:       DE-EX2-a
file:     apps/reporting/src/platform/db-dump.port.ts
line:     14
severity: medium
command:  /audit-data-quality
class:    DE-EX-2
owner:    data-engineering
bucket:   report-with-fix
detector: extract-scan §2 (2a)
anchor:   select * from "${table_name}" where id::text > ? order by id limit 1000
match:    dump|table_name|information_schema
match:    snapshot|isolation|repeatable|consistent|FK|foreign|transaction
```

A child row inserted after its parent's table was dumped references a parent absent from the file; the restore fails with FKs on. Proof V561. Fix: one `REPEATABLE READ` read-only transaction (the tenant export's shape) or `pg_dump`.

## DE-EX2-b — `mysqldump` without `--single-transaction`

```defect
id:       DE-EX2-b
file:     scripts/nightly_dump.sh
line:     4
severity: medium
command:  /audit-data-quality
class:    DE-EX-2
owner:    data-engineering
bucket:   report-with-fix
detector: extract-scan §2 (2b)
anchor:   mysqldump --host "$LEGACY_MYSQL_HOST" --user backup shopdb
match:    mysqldump|nightly_dump
match:    single-transaction|snapshot|consistent|lock|InnoDB
```

On InnoDB the tables are read at different instants (or locked for the duration). Proof V561. Fix: `--single-transaction`.

## DE-EX3-a — The enterprise export is cut at 50,000 rows without a word

```defect
id:       DE-EX3-a
file:     apps/reporting/src/exports/big-orders-export.runner.ts
line:     11
severity: medium
command:  /audit-data-quality
class:    DE-EX-3
owner:    data-engineering
bucket:   report-with-fix
detector: extract-scan §3 (3a, 3b)
anchor:   return rows.slice(0, MAX_EXPORT_ROWS);
match:    slice|MAX_EXPORT_ROWS|big-orders
match:    truncat|silent|cap|cut|refus
```

The tenant receives a file that looks complete. Proof V562 (a run above the cap). Fix: refuse like `export-size.ts` (precedent § 39), or paginate into files.

## DE-EX3-b — The statement is marked ready before it is uploaded

```defect
id:       DE-EX3-b
file:     apps/reporting/src/exports/statement-export.runner.ts
line:     11
severity: medium
command:  /audit-data-quality
class:    DE-EX-3
owner:    data-engineering
bucket:   report-with-fix
detector: extract-scan §3 (3c)
anchor:   update({ status: 'ready', file_url: fileUrl })
match:    ready|file_url|statement
match:    before|partial|upload|order|fail
```

A failed render or upload leaves a ready job pointing at a missing or older file. Proof V562 (fault after the update). Fix: upload first, mark ready last.

## DE-EX4-a — Settlement instants in the server's locale and zone

```defect
id:       DE-EX4-a
file:     apps/reporting/src/exports/settlement-export.mapper.ts
line:     12
severity: medium
command:  /audit-data-quality
class:    DE-EX-4
owner:    data-engineering
bucket:   report-with-fix
detector: extract-scan §4
anchor:   paid_at: row.paidAt.toLocaleString(),
match:    toLocaleString|paid_at|settlement
match:    zone|offset|locale|server|ISO
```

Merchants reconcile this file against their bank; the value has no offset and changes with the server's locale. Proof V562. Fix: `toISOString()` (or a header that states the zone).

## DE-EX4-b — Phone numbers exported as numbers

```defect
id:       DE-EX4-b
file:     apps/reporting/src/exports/settlement-export.mapper.ts
line:     15
severity: medium
command:  /audit-data-quality
class:    DE-EX-4
owner:    data-engineering
bucket:   report-with-fix
detector: extract-scan §4
anchor:   customer_phone: Number(row.phone),
match:    phone|Number
match:    leading zero|lossy|number|text|digit
```

`Number('0551112222')` drops the leading zero. Proof V562. Fix: export as text.

## DE-PC1-a — A public-facing customer dimension carries email unclassified

```defect
id:       DE-PC1-a
file:     analytics/models/marts/core/_dim_customers.yml
line:     10
severity: medium
command:  /audit-data-quality
class:    DE-PC-1
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §1 (1a)
anchor:         - name: email
match:    email|dim_customers|pii
match:    classif|meta|pii|policy|tag|unclassified
```

`rpt_customer_contacts` classifies the same columns (`meta: {contains_pii: true}`); `dim_customers` does not. Proof V566. Fix: `meta`/`policy_tags` on email, full_name, phone_number.

## DE-PC1-b — The newsletter audience mart copies email and name unclassified

```defect
id:       DE-PC1-b
file:     analytics/models/marts/marketing/rpt_newsletter_audience.sql
line:     3
severity: medium
command:  /audit-data-quality
class:    DE-PC-1
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §1 (1b)
anchor:       c.email,
match:    email|newsletter|pii
match:    classif|meta|pii|policy|tag|unclassified
```

Proof V566. Fix: classify in `_marketing.yml` (or drop email and resolve at send time).

## DE-PC2-a — The customers snapshot keeps every version of an erased customer

```defect
id:       DE-PC2-a
file:     analytics/snapshots/customers_snapshot.sql
line:     5
severity: high
command:  /audit-data-quality
class:    DE-PC-2
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §2 (2b)
anchor:       email,
match:    customers_snapshot|snapshot|email
match:    erasure|erase|history|scd|forgot|delete
```

`erase-customer.handler.ts` deletes the customer row; SCD2 history in the snapshot keeps email, name and phone for every past version. Proof V565 (erase a synthetic subject, scan the snapshot). Fix: an erasure step over snapshots (and `hard_deletes`, DE-IN4-a).

## DE-PC2-b — A daily table keyed by e-mail that erasure never touches

```defect
id:       DE-PC2-b
file:     apps/reporting/migrations/Migration20260307000000_customer_ltv_daily.ts
line:     7
severity: high
command:  /audit-data-quality
class:    DE-PC-2
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §2 (0b, 2c)
anchor:   create table "customer_ltv_daily" (
match:    customer_ltv_daily|customer_email
match:    erasure|erase|handler|not named|delete
```

The handler names `sessions`, `orders` and `customers` only; no FK or trigger reaches `customer_ltv_daily`. Two-ended. Fix: key by customer id, or add the table to the erasure job.

## DE-PC3-a — An unkeyed SHA-256 of the e-mail sent to a partner as "anonymous"

```defect
id:       DE-PC3-a
file:     apps/reporting/src/exports/partner-feed.export.ts
line:     8
severity: medium
command:  /audit-data-quality
class:    DE-PC-3
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §3
anchor:   anon_id: createHash('sha256').update(c.email.trim().toLowerCase()).digest('hex'),
match:    sha256|anon_id|createHash|partner
match:    unsalted|unkeyed|reversible|pseudonym|dictionary|hmac
```

A dictionary of e-mails reverses it; it is pseudonymised personal data. Proof V567. Fix: the clean-room HMAC in `partner-match.ts` (precedent § 31), and treat the output as personal data.

## DE-PC3-b — An unkeyed e-mail hash labelled anonymous in a mart

```defect
id:       DE-PC3-b
file:     analytics/models/marts/marketing/rpt_ad_audience.sql
line:     3
severity: medium
command:  /audit-data-quality
class:    DE-PC-3
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §3
anchor:   sha256(lower(c.email)) as anon_email_hash,
match:    sha256|anon_email_hash|ad_audience
match:    unsalted|unkeyed|reversible|pseudonym|dictionary|hmac
```

Proof V567. Fix: a keyed HMAC, and classify the column.

## DE-PC4-a — Production copied into staging every Monday unmasked

```defect
id:       DE-PC4-a
file:     scripts/refresh_staging.sh
line:     4
severity: high
command:  /audit-data-quality
class:    DE-PC-4
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §4
anchor:   pg_dump "$PROD_DATABASE_URL" --no-owner | psql "$STAGING_DATABASE_URL"
match:    pg_dump|staging|refresh_staging
match:    mask|anonymi|production|lower|personal
```

Proof V567 (a staging sample holds production identifiers). Fix: restore through the masking step `refresh_preview_masked.sh` uses.

## DE-PC4-b — `make seed-from-prod` restores the production dump into staging

```defect
id:       DE-PC4-b
file:     Makefile
line:     9
severity: high
command:  /audit-data-quality
class:    DE-PC-4
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §4
anchor:   pg_restore --clean --no-owner -d $(STAGING_DATABASE_URL) prod-latest.dump
match:    pg_restore|seed-from-prod|Makefile
match:    mask|anonymi|production|lower|personal
```

Proof V567. Fix: a masked dump or synthetic seeds.

## DE-PC5-a — The partner-exports bucket has no lifecycle rule

```defect
id:       DE-PC5-a
file:     infra/terraform/exports.tf
line:     1
severity: medium
command:  /audit-data-quality
class:    DE-PC-5
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §5 (5a)
anchor:   resource "aws_s3_bucket" "partner_exports" {
match:    partner_exports|bucket
match:    lifecycle|retention|expir|forever
```

Customer files written nightly are kept forever (`report_archive` beside it expires after 90 days). Proof V565. Fix: an `aws_s3_bucket_lifecycle_configuration` (the period is the user's call).

## DE-PC5-b — Each nightly customer file is a new object nobody deletes

```defect
id:       DE-PC5-b
file:     apps/reporting/src/exports/customers-export.runner.ts
line:     23
severity: medium
command:  /audit-data-quality
class:    DE-PC-5
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §5 (5b)
anchor:   Bucket: 'larkmoor-partner-exports'
match:    customers-export|PutObject|partner-exports
match:    retention|expir|forever|delete|lifecycle
```

A timestamped key per run, no expiry, no cleanup: erasure never reaches old files. Proof V565. Fix: overwrite one key per merchant or expire objects.

## DE-PC6-a — `policy_tags` on IBAN with no `persist_docs: {columns: true}`

```defect
id:       DE-PC6-a
file:     analytics/models/marts/finance/_finance_pii.yml
line:     10
severity: medium
command:  /audit-data-quality
class:    DE-PC-6
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §6 (6a)
anchor:   policy_tags: ['projects/larkmoor-analytics/locations/eu/taxonomies/41/policyTags/7']
match:    policy_tags|iban|payouts
match:    persist_docs|not applied|never|effective
```

dbt writes BigQuery policy tags only when `persist_docs` persists column docs; nothing sets it, so IBAN is readable by every analyst. Proof V566. Fix: `+persist_docs: {columns: true}` for the model (or project).

## DE-PC6-b — A string masking policy attached by tag to a NUMBER column

```defect
id:       DE-PC6-b
file:     warehouse/snowflake/masking.sql
line:     8
severity: medium
command:  /audit-data-quality
class:    DE-PC-6
owner:    data-engineering
bucket:   report-with-fix
detector: pii-copy-scan §6 (6b)
anchor:   alter table support.customers modify column phone_number set tag pii.contact = 'phone';
match:    phone_number|masking|tag
match:    type|number|string|skip|not masked
```

`support.customers.phone_number` is `number(15,0)`; the tag's policy takes `string`, so the phone column is not masked. Proof V566 (read as a low-privilege role). Fix: a numeric policy on the tag, or store phones as text.

## DE-CO1-a — The partition column is wrapped in `date()` by its reader

```defect
id:       DE-CO1-a
file:     analytics/models/marts/product/rpt_ad_performance.sql
line:     7
severity: medium
command:  /audit-data-quality
class:    DE-CO-1
owner:    data-engineering
bucket:   report-flagged
detector: warehouse-scan-audit §1 (0 + 1a)
anchor:   where date(impression_ts) >= date_sub(current_date(), interval 7 day)
match:    impression_ts|date\(|prun|rpt_ad_performance
match:    prun|partition|wrap|function|scan
```

`fct_ad_impressions` is partitioned by `impression_ts`; the wrapped predicate may defeat pruning on a multi-terabyte table (the recorded history shows ~1 TiB per run). Settling: V568 dry run before/after. Fix: `impression_ts >= timestamp(date_sub(current_date(), interval 7 day))`.

## DE-CO1-b — A billion-row partitioned fact with no `require_partition_filter`

```defect
id:       DE-CO1-b
file:     analytics/models/marts/product/fct_ad_impressions.sql
line:     6
severity: medium
command:  /audit-data-quality
class:    DE-CO-1
owner:    data-engineering
bucket:   report-with-fix
detector: warehouse-scan-audit §1 (0, 1b)
anchor:   partition_by={'field': 'impression_ts', 'data_type': 'timestamp', 'granularity': 'day'},
match:    require_partition_filter|fct_ad_impressions|partition
match:    require_partition_filter|unfiltered|full scan|partition filter
```

Any unfiltered reader scans every partition. Proof V568 (the unfiltered query fails once the filter is required). Fix: `require_partition_filter=true` (its siblings already set it).

## DE-CO2-a — A merge into the partitioned fact with no `incremental_predicates`

```defect
id:       DE-CO2-a
file:     analytics/models/marts/product/fct_ad_impressions.sql
line:     1
severity: medium
command:  /audit-data-quality
class:    DE-CO-2
owner:    data-engineering
bucket:   report-with-fix
detector: warehouse-scan-audit §2 (model-graph CO-2)
anchor:   {{ config(
match:    fct_ad_impressions|merge|incremental_predicates
match:    incremental_predicates|whole|destination|full|target
```

Each run scans the whole destination to find matches (4 TiB in the recorded history). Two-ended. Fix: `incremental_predicates` bounding `DBT_INTERNAL_DEST.impression_ts` to the lookback.

## DE-CO2-b — The hourly hand merge has no target-side bound

```defect
id:       DE-CO2-b
file:     etl/sql/merge_impressions.sql
line:     2
severity: medium
command:  /audit-data-quality
class:    DE-CO-2
owner:    data-engineering
bucket:   report-with-fix
detector: warehouse-scan-audit §2 (2a)
anchor:   MERGE INTO analytics.fct_ad_impressions t
match:    merge_impressions|MERGE
match:    target|bound|whole|partition|full
```

`ON t.impression_id = s.impression_id` with no range on `t.impression_ts`: every hour scans every day. Proof V568. Fix: add `AND t.impression_ts >= <hour start - 1 day>`.

## DE-CO3-a — An append-mostly history rebuilt in full every night

```defect
id:       DE-CO3-a
file:     analytics/models/marts/finance/fct_order_status_history.sql
line:     1
severity: medium
command:  /audit-data-quality
class:    DE-CO-3
owner:    data-engineering
bucket:   report-with-fix
detector: warehouse-scan-audit §3 (model-graph CO-3)
anchor:   {{ config(materialized='table') }}
match:    fct_order_status_history|table
match:    full|rebuild|append|incremental|every run
```

Seven years of status changes recomputed each run. Proof V568. Fix: incremental on `changed_at` with a merge key.

## DE-CO3-b — `--full-refresh` in the nightly schedule

```defect
id:       DE-CO3-b
file:     .github/workflows/dbt-nightly.yml
line:     11
severity: medium
command:  /audit-data-quality
class:    DE-CO-3
owner:    data-engineering
bucket:   report-with-fix
detector: warehouse-scan-audit §3 (3a)
anchor:   dbt build --full-refresh --select fct_order_status_history+
match:    full-refresh|dbt-nightly
match:    full|refresh|schedule|nightly|rebuild
```

Every downstream incremental is rebuilt too. Proof V568. Fix: remove `--full-refresh` from the schedule; keep it for runbooks.

## DE-CO4-a — A four-deep view chain

```defect
id:       DE-CO4-a
file:     analytics/models/marts/product/rpt_daily_kpis.sql
line:     1
severity: low
command:  /audit-data-quality
class:    DE-CO-4
owner:    data-engineering
bucket:   report-with-fix
detector: warehouse-scan-audit §4 (0 view-chain)
anchor:   {{ config(materialized='view') }}
match:    rpt_daily_kpis|view
match:    chain|depth|view|re-?execut
```

`rpt_daily_kpis` → `int_kpi_base` → `int_kpi_joined` → staging views: every read re-executes the joins. Proof V568. Fix: materialize `int_kpi_base`.

## DE-CO4-b — `select *` over a wide columnar fact for three columns

```defect
id:       DE-CO4-b
file:     analytics/models/marts/product/rpt_ad_performance.sql
line:     1
severity: low
command:  /audit-data-quality
class:    DE-CO-4
owner:    data-engineering
bucket:   report-with-fix
detector: warehouse-scan-audit §4 (4)
anchor:   with imp as (select * from {{ ref('fct_ad_impressions') }})
match:    select \*|fct_ad_impressions|imp
match:    column|wide|bytes|select \*|star
```

On BigQuery bytes are per column read; the CTE pulls every column. Proof V568. Fix: select `campaign_id, impression_ts, cost_micros`.

## DE-CO5-a — Top recorded cost: the impressions merge

```defect
id:       DE-CO5-a
file:     warehouse/history/jobs_2026-10.csv
line:     2
severity: low
command:  /audit-data-quality
class:    DE-CO-5
owner:    data-engineering
bucket:   report-flagged
detector: warehouse-scan-audit §5 (recorded history)
anchor:   job_a1
match:    fct_ad_impressions|job_a1|history
match:    TiB|GiB|bytes|cost|top
```

4 TiB billed in one run (measured: recorded file); its cause is DE-CO2-a.

## DE-CO5-b — Second recorded cost: the ad performance rebuild

```defect
id:       DE-CO5-b
file:     warehouse/history/jobs_2026-10.csv
line:     3
severity: low
command:  /audit-data-quality
class:    DE-CO-5
owner:    data-engineering
bucket:   report-flagged
detector: warehouse-scan-audit §5 (recorded history)
anchor:   job_a2
match:    rpt_ad_performance|job_a2|history
match:    TiB|GiB|bytes|cost|top
```

1 TiB per run (measured: recorded file); its causes are DE-CO1-a and DE-CO4-b.

## DE-GR1-a — The refunds mart declares no grain

```defect
id:       DE-GR1-a
file:     analytics/models/marts/finance/_refunds.yml
line:     4
severity: medium
command:  /audit-data-quality /audit-data-model
class:    DE-GR-1
owner:    data-engineering
bucket:   report-flagged
detector: grain-probe §1
anchor:     - name: refunds_ledger
match:    refunds_ledger|grain
match:    grain|undeclared|one row per|declare
```

"Refunds as finance reads them" — one row per refund, or per refund line? Undeclared (an enabler for `@warehouse-modeler`); no probe is possible until it is.

## DE-GR1-b — The LTV model declares no grain

```defect
id:       DE-GR1-b
file:     analytics/models/intermediate/_intermediate.yml
line:     4
severity: medium
command:  /audit-data-quality /audit-data-model
class:    DE-GR-1
owner:    data-engineering
bucket:   report-flagged
detector: grain-probe §1
anchor:     - name: int_customer_ltv
match:    int_customer_ltv|grain
match:    grain|undeclared|one row per|declare
```

Settling: the grain sentence, then V569.

## DE-GR2-a — A fact joined to the customer dimension on e-mail

```defect
id:       DE-GR2-a
file:     analytics/models/marts/core/order_lines.sql
line:     12
severity: high
command:  /audit-data-quality /audit-data-model
class:    DE-GR-2
owner:    data-engineering
bucket:   report-with-fix
detector: grain-probe §2 (2a)
anchor:   left join {{ ref('dim_customers') }} c on c.email = l.customer_email
match:    email|join|order_lines|dim_customers
match:    fan.?out|cardinal|key|duplicat|multipl
```

E-mail is not `dim_customers`' key; two customers sharing an address multiply order lines. Proof V569 (rows before → after the join). Fix: join on `customer_id`.

## DE-GR2-b — An implicit cross join with no predicate

```defect
id:       DE-GR2-b
file:     analytics/models/marts/core/promo_exposure.sql
line:     2
severity: high
command:  /audit-data-quality /audit-data-model
class:    DE-GR-2
owner:    data-engineering
bucket:   report-with-fix
detector: grain-probe §2 (2b)
anchor:   from {{ ref('stg_orders') }} o, {{ ref('stg_promotions') }} p
match:    promo_exposure|cross|implicit
match:    cross|predicate|cartesian|every|multipl
```

Every order × every promotion (the calendar spine is the deliberate case). Proof V569. Fix: join on the promotion window and eligibility.

## DE-GR3-a — Type 2 ranges share their boundary

```defect
id:       DE-GR3-a
file:     analytics/models/marts/core/dim_products_scd.sql
line:     8
severity: high
command:  /audit-data-quality /audit-data-model
class:    DE-GR-3
owner:    data-engineering
bucket:   report-with-fix
detector: grain-probe §3
anchor:   lead(updated_at) over (partition by product_id order by updated_at) as valid_to
match:    valid_to|dim_products_scd|lead
match:    overlap|boundary|between|inclusive|type 2|scd
```

`valid_to` equals the next `valid_from`, so an as-of join with `between` matches two versions at the boundary and the open version has a NULL end. Proof V569 (overlap probe). Fix: half-open joins, and a coalesced far-future end.

## DE-GR3-b — Two "current" rows on the day a store changes

```defect
id:       DE-GR3-b
file:     analytics/models/marts/core/dim_store_history.sql
line:     7
severity: high
command:  /audit-data-quality /audit-data-model
class:    DE-GR-3
owner:    data-engineering
bucket:   report-with-fix
detector: grain-probe §3
anchor:   coalesce(dbt_valid_to, '9999-12-31') >= current_date as is_current
match:    is_current|dim_store_history
match:    current|two|more than one|duplicat|today
```

A version closed today still satisfies `>= current_date`. Proof V569 (current rows per natural key). Fix: `dbt_valid_to is null`.

## DE-GR4-a — A composite key concatenated without a separator

```defect
id:       DE-GR4-a
file:     analytics/models/marts/core/order_lines.sql
line:     4
severity: low
command:  /audit-data-quality /audit-data-model
class:    DE-GR-4
owner:    data-engineering
bucket:   report-with-fix
detector: grain-probe §4
anchor:   l.order_id || l.line_no as order_line_key,
match:    order_line_key|\|\|
match:    separator|collid|concat|composite
```

Order 11 line 1 and order 1 line 11 both produce `111`. Proof V544 (crafted pair). Fix: `generate_surrogate_key` or a separator.

## DE-GR4-b — The audience key concatenates two ids without a separator

```defect
id:       DE-GR4-b
file:     analytics/models/marts/marketing/rpt_ad_audience.sql
line:     2
severity: low
command:  /audit-data-quality /audit-data-model
class:    DE-GR-4
owner:    data-engineering
bucket:   report-with-fix
detector: grain-probe §4
anchor:   concat(c.customer_id, i.campaign_id) as audience_key,
match:    audience_key|concat
match:    separator|collid|concat|composite
```

Its uniqueness test runs on the collided key. Proof V544. Fix: a separator or a combination test.

## Decoys

Known-safe look-alikes: each sits next to a seeded shape and matches the detector's grep or a `model-graph.py` row. A finding pinned to one is a false positive. Every decoy is more than 12 lines from any seed in its file (`run.sh --verify` checks it).

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| DE-DECOY-01 | `analytics/models/marts/product/fct_page_views.sql:2` | append incremental with no unique_key | Page views never change once tracked and are deduplicated in staging; append is the right strategy (the IN-8 full refresh is a different defect). |
| DE-DECOY-02 | `analytics/models/marts/finance/fct_orders.sql:19` | strict `>` watermark | A 3-day lookback re-reads the boundary and the merge on `order_id` absorbs it. |
| DE-DECOY-03 | `analytics/models/marts/finance/_finance.yml:18` | `severity: warn` | An advisory distribution check on the order mean routes to the owner; precedent § 3. |
| DE-DECOY-04 | `analytics/models/marts/finance/_finance.yml:12` | `relationships` on a nullable column | Most orders carry no coupon; NULL is a legitimate value of an optional FK. |
| DE-DECOY-05 | `analytics/snapshots/stores_snapshot.sql:1` | `hard_deletes: ignore`; `strategy: check` | Stores are never deleted (closing sets `closed_on`) and the source has no `updated_at`. |
| DE-DECOY-06 | `spark/jobs/clean_clicks.py:7` | `dropDuplicates` | Full-row duplicates from collector retries: every copy is identical. |
| DE-DECOY-07 | `spark/jobs/write_partition_ok.py:11` | `mode("overwrite")` | Delta `replaceWhere` scopes the overwrite to the day. |
| DE-DECOY-08 | `cdc/outbox-connector.json:8` | `tombstones.on.delete=false` | The outbox topic is not compacted and its consumer never reads deletes; distributed-systems owns the outbox. |
| DE-DECOY-09 | `dags/stock_levels.py:30` | `trigger_rule="all_done"` | A cleanup of temp files publishes nothing. |
| DE-DECOY-10 | `dags/stock_levels.py:20` | retries around a write | The task deletes the hour then inserts it; a retry replaces, never duplicates. |
| DE-DECOY-11 | `dags/stock_levels.py:12` | cron + `data_interval_*` | An explicit `CronDataIntervalTimetable` gives a real interval on Airflow 3. |
| DE-DECOY-12 | `dags/catalog_refresh.py:10` | no `catchup=` | Airflow 3 defaults catchup to False; a full nightly rebuild needs no backfill. |
| DE-DECOY-13 | `dags/catalog_refresh.py:17` | `datetime.now()` in a task | A log line, not a data window. |
| DE-DECOY-14 | `analytics/tests/assert_orders_daily_matches_fct_orders.sql:9` | a rollup | `orders_daily` is tied to `fct_orders` by this singular test. |
| DE-DECOY-15 | `analytics/models/staging/_sources.yml:80` | source with no freshness | Reference country codes are refreshed by hand twice a year; `freshness: null` is explicit. |
| DE-DECOY-16 | `gx/expectations/payments_suite.json:5` | `mostly` < 1 | A tolerance on a non-key enum column; the key column has no tolerance. |
| DE-DECOY-17 | `analytics/models/marts/marketing/_contacts.yml:7` | PII columns in a mart | Classified with an owner; the support desk is the controller-side reader. |
| DE-DECOY-18 | `analytics/models/marts/core/dim_calendar.sql:4` | a cross join | One row per store per day is the declared grain; the spine is deliberate. |
| DE-DECOY-19 | `analytics/models/marts/core/dim_customers_v1.sql:1` | a model with no grain test | Tests declared on a versioned model apply to every version in dbt; `model-graph.py` lists v1 without them (an integrator note, not a finding). |
| DE-DECOY-20 | `apps/reporting/src/reports/order-day-rollup.ts:14` | a rollup writer | Whole-day replacement in one transaction; a doubled pass is harmless. |
| DE-DECOY-21 | `apps/reporting/src/reports/order-day-rollup.ts:9` | UTC buckets | Quarter-hour facts beside the UTC days let any tenant zone re-bucket. |
| DE-DECOY-22 | `apps/reporting/migrations/Migration20260301000000_order_day_facts.ts:46` | a trigger column list | Insert, update-of-every-read-column and delete triggers; a spec holds the list equal to the fact columns. |
| DE-DECOY-23 | `apps/reporting/src/reports/order-rollup.reconcile.job.ts:23` | a reconciliation | Disagreeing days are marked dirty again and counted as failed units. |
| DE-DECOY-24 | `apps/reporting/src/reports/tenant-usage.processor.ts:22` | find-then-insert | Behind the unique `(tenant_id, day)` constraint the loser fails and is retried as an update. |
| DE-DECOY-25 | `apps/reporting/src/reports/performance-snapshots.job.ts:16` | a snapshot never restated | A closed-period snapshot labelled "as of" where read. |
| DE-DECOY-26 | `apps/reporting/src/reports/reference-refresh.job.ts:12` | refresh without CONCURRENTLY | 250 rows, refreshed at 03:00, cached by its readers. |
| DE-DECOY-27 | `apps/reporting/src/reports/admin-map-refresh.job.ts:12` | `CONCURRENTLY` | The unique index on `country` exists in the migration. |
| DE-DECOY-28 | `apps/reporting/src/reports/hourly-orders-utc.query.ts:6` | `AT TIME ZONE` on a naive column | The correct double conversion. |
| DE-DECOY-29 | `apps/reporting/src/reports/business-days.query.ts:6` | `BETWEEN` | `day` is a `date`; both ends inclusive is the intent. |
| DE-DECOY-30 | `apps/reporting/src/exports/orders-export.runner.ts:14` | a paged export | Keyset on `(created_at, id)` compared in SQL. |
| DE-DECOY-31 | `apps/reporting/src/exports/export-size.ts:15` | an export cap | The ceiling refuses with a message; nothing is cut. |
| DE-DECOY-32 | `apps/reporting/src/exports/iso-export.mapper.ts:5` | an export mapper | Instants carry `Z`; amounts are exact strings. |
| DE-DECOY-33 | `apps/reporting/src/platform/db-snapshot-export.ts:13` | a multi-table export | Every table is read in one REPEATABLE READ read-only transaction. |
| DE-DECOY-34 | `apps/reporting/src/exports/partner-match.ts:7` | a hash of an e-mail | A keyed HMAC with the key in KMS; the output is still treated as personal data. |
| DE-DECOY-35 | `apps/reporting/src/exports/google-sheet-push.ts:8` | customer PII pushed to Google Sheets | The merchant pushes its own customer list to its own sheet. |
| DE-DECOY-36 | `scripts/refresh_preview_masked.sh:4` | a production dump into a lower environment | pg_anonymizer masks people and `--exclude-table-data=customers` drops the rest. |
| DE-DECOY-37 | `infra/terraform/report_archive.tf:5` | a report bucket | Objects expire after 90 days. |

```decoy
id:       DE-DECOY-01
file:     analytics/models/marts/product/fct_page_views.sql
line:     2
command:  /audit-data-quality
class:    decoy/IN-2 (precedents/data-engineering.md § 1)
anchor:   {{ config(materialized='incremental', incremental_strategy='append', on_schema_change='append_new_columns') }}
match:    fct_page_views
match:    append|unique.?key|duplicat
```

```decoy
id:       DE-DECOY-02
file:     analytics/models/marts/finance/fct_orders.sql
line:     19
command:  /audit-data-quality
class:    decoy/IN-1 (precedents/data-engineering.md § 2)
anchor:   where updated_at > (select max(updated_at) - interval '3 days' from {{ this }})
match:    fct_orders|updated_at
match:    strict|>|lookback|tie|late
```

```decoy
id:       DE-DECOY-03
file:     analytics/models/marts/finance/_finance.yml
line:     18
command:  /audit-data-quality
class:    decoy/DQ-2 (precedents/data-engineering.md § 3)
anchor:   config: {severity: warn}
match:    severity|warn|mean
match:    warn|cannot fail|exit
```

```decoy
id:       DE-DECOY-04
file:     analytics/models/marts/finance/_finance.yml
line:     12
command:  /audit-data-quality
class:    decoy/DQ-5 (precedents/data-engineering.md § 10)
anchor:   - relationships:
match:    coupon_id|relationships
match:    null|nullable
```

```decoy
id:       DE-DECOY-05
file:     analytics/snapshots/stores_snapshot.sql
line:     1
command:  /audit-data-quality
class:    decoy/IN-4 (precedents/data-engineering.md § 16, § 37)
anchor:   {% snapshot stores_snapshot %}
match:    stores_snapshot|hard_deletes
match:    delete|ignore|check
```

```decoy
id:       DE-DECOY-06
file:     spark/jobs/clean_clicks.py
line:     7
command:  /audit-data-quality
class:    decoy/IN-5 (precedents/data-engineering.md § 15)
anchor:   clicks.dropDuplicates().write.mode("append").saveAsTable("clean.clicks")
match:    dropDuplicates|clean_clicks
match:    arbitrar|determin|winner
```

```decoy
id:       DE-DECOY-07
file:     spark/jobs/write_partition_ok.py
line:     11
command:  /audit-data-quality
class:    decoy/IN-7 (precedents/data-engineering.md § 28)
anchor:   .option("replaceWhere", f"order_date = '{day}'")
match:    replaceWhere|overwrite
match:    static|partition|wipe
```

```decoy
id:       DE-DECOY-08
file:     cdc/outbox-connector.json
line:     8
command:  /audit-data-quality
class:    decoy/IN-10 (precedents/data-engineering.md § 18)
anchor:   "tombstones.on.delete": "false"
match:    tombstone|outbox
match:    delete|tombstone
```

```decoy
id:       DE-DECOY-09
file:     dags/stock_levels.py
line:     30
command:  /audit-data-quality
class:    decoy/OR-4 (cleanup task)
anchor:   trigger_rule="all_done",
match:    all_done|cleanup
match:    fail|regardless|publish
```

```decoy
id:       DE-DECOY-10
file:     dags/stock_levels.py
line:     20
command:  /audit-data-quality
class:    decoy/OR-5 (idempotent write)
anchor:   retries=2,
match:    retries|stock
match:    retr|idempot|duplicat
```

```decoy
id:       DE-DECOY-11
file:     dags/stock_levels.py
line:     12
command:  /audit-data-quality
class:    decoy/OR-8 (explicit interval timetable)
anchor:   schedule=CronDataIntervalTimetable("0 * * * *", timezone=pendulum.timezone("UTC")),
match:    CronDataIntervalTimetable|data_interval
match:    zero|width|empty
```

```decoy
id:       DE-DECOY-12
file:     dags/catalog_refresh.py
line:     10
command:  /audit-data-quality
class:    decoy/OR-3 (precedents/data-engineering.md § 14)
anchor:   @dag(dag_id="catalog_refresh", schedule="0 4 * * *", start_date=datetime(2025, 1, 1))
match:    catalog_refresh|catchup
match:    catchup|implicit|default
```

```decoy
id:       DE-DECOY-13
file:     dags/catalog_refresh.py
line:     17
command:  /audit-data-quality
class:    decoy/OR-1 (precedents/data-engineering.md § 13)
anchor:   log.info("catalog refreshed at %s", datetime.now().isoformat())
match:    datetime\.now|catalog
match:    wall.?clock|replay
```

```decoy
id:       DE-DECOY-14
file:     analytics/tests/assert_orders_daily_matches_fct_orders.sql
line:     9
command:  /audit-data-quality
class:    decoy/DQ-6 (reconciliation exists)
anchor:   where d.orders <> f.orders
match:    orders_daily
match:    reconcil|compar|detail
```

```decoy
id:       DE-DECOY-15
file:     analytics/models/staging/_sources.yml
line:     80
command:  /audit-data-quality
class:    decoy/DQ-4 (static reference data)
anchor:       freshness: null
match:    reference|countries|freshness
match:    freshness|stale
```

```decoy
id:       DE-DECOY-16
file:     gx/expectations/payments_suite.json
line:     5
command:  /audit-data-quality
class:    decoy/DQ-2 (precedents/data-engineering.md § 12)
anchor:   "mostly": 0.9
match:    mostly|method
match:    mostly|tolerance|cannot fail
```

```decoy
id:       DE-DECOY-17
file:     analytics/models/marts/marketing/_contacts.yml
line:     7
command:  /audit-data-quality
class:    decoy/PC-1 (classified)
anchor:   meta: {contains_pii: true, owner: support-data}
match:    rpt_customer_contacts|email
match:    classif|pii|unclassified
```

```decoy
id:       DE-DECOY-18
file:     analytics/models/marts/core/dim_calendar.sql
line:     4
command:  /audit-data-quality
class:    decoy/GR-2 (calendar spine)
anchor:   cross join (select unnest(generate_series(date '2024-01-01', date '2027-12-31', interval 1 day)) as day) d
match:    cross join|dim_calendar
match:    cross|cartesian|fan
```

```decoy
id:       DE-DECOY-19
file:     analytics/models/marts/core/dim_customers_v1.sql
line:     1
command:  /audit-data-quality
class:    decoy/DQ-1 (tests on a versioned model)
anchor:   -- v1 of dim_customers
match:    dim_customers_v1
match:    grain|test|unique
```

```decoy
id:       DE-DECOY-20
file:     apps/reporting/src/reports/order-day-rollup.ts
line:     14
command:  /audit-data-quality
class:    decoy/MV-1 (precedents/data-engineering.md § 22)
anchor:   delete from order_day_facts where tenant_id = ? and day = any(?::date[])
match:    order_day_facts|rollup
match:    twice|idempot|increment|double
```

```decoy
id:       DE-DECOY-21
file:     apps/reporting/src/reports/order-day-rollup.ts
line:     9
command:  /audit-data-quality
class:    decoy/MV-6 (precedents/data-engineering.md § 21)
anchor:   const QUARTER = (column: string): string => `date_bin('15 minutes'
match:    quarter|date_bin
match:    zone|utc|local
```

```decoy
id:       DE-DECOY-22
file:     apps/reporting/migrations/Migration20260301000000_order_day_facts.ts
line:     46
command:  /audit-data-quality
class:    decoy/MV-4 (trigger list held equal by a spec)
anchor:   after update of "tenant_id", "created_at", "store_id", "status", "total_cents"
match:    trigger|update of|order_day
match:    missing|column|cover
```

```decoy
id:       DE-DECOY-23
file:     apps/reporting/src/reports/order-rollup.reconcile.job.ts
line:     23
command:  /audit-data-quality
class:    decoy/MV-3 (reconcile marks stale)
anchor:   failedUnits.inc(marked.length);
match:    reconcil|order_day
match:    log|only|never
```

```decoy
id:       DE-DECOY-24
file:     apps/reporting/src/reports/tenant-usage.processor.ts
line:     22
command:  /audit-data-quality
class:    decoy/MV-1 (precedents/data-engineering.md § 20)
anchor:   insert into tenant_usage_daily (tenant_id, day, seats) values (?, ?, ?)
match:    tenant_usage_daily|find|insert
match:    race|duplicat|idempot|twice
```

```decoy
id:       DE-DECOY-25
file:     apps/reporting/src/reports/performance-snapshots.job.ts
line:     16
command:  /audit-data-quality
class:    decoy/MV-2 (precedents/data-engineering.md § 38)
anchor:   insert into performance_snapshots (staff_id, period_end, delivered, returned)
match:    performance_snapshots|snapshot
match:    current|stale|restat|late
```

```decoy
id:       DE-DECOY-26
file:     apps/reporting/src/reports/reference-refresh.job.ts
line:     12
command:  /audit-data-quality
class:    decoy/MV-5 (precedents/data-engineering.md § 25)
anchor:   refresh materialized view country_codes_mv
match:    country_codes_mv|refresh
match:    block|concurrently|reader
```

```decoy
id:       DE-DECOY-27
file:     apps/reporting/src/reports/admin-map-refresh.job.ts
line:     12
command:  /audit-data-quality
class:    decoy/MV-5 (unique index present)
anchor:   refresh materialized view concurrently country_sales_mv
match:    country_sales_mv|concurrently
match:    unique index|fail
```

```decoy
id:       DE-DECOY-28
file:     apps/reporting/src/reports/hourly-orders-utc.query.ts
line:     6
command:  /audit-data-quality
class:    decoy/TB-1 (precedents/data-engineering.md § 27)
anchor:   date_trunc('hour', (created_at at time zone 'UTC') at time zone ?)
match:    at time zone
match:    naive|direction|wrong
```

```decoy
id:       DE-DECOY-29
file:     apps/reporting/src/reports/business-days.query.ts
line:     6
command:  /audit-data-quality
class:    decoy/TB-2 (precedents/data-engineering.md § 29)
anchor:   day between ?::date and ?::date
match:    between|store_calendar
match:    inclusive|boundary|midnight
```

```decoy
id:       DE-DECOY-30
file:     apps/reporting/src/exports/orders-export.runner.ts
line:     14
command:  /audit-data-quality
class:    decoy/EX-1 (precedents/data-engineering.md § 30)
anchor:   if (last) q.whereRaw('(created_at, id) < (?::timestamptz, ?::uuid)', [last.createdAt, last.id]);
match:    orders-export|keyset|created_at
match:    offset|duplicat|skip
```

```decoy
id:       DE-DECOY-31
file:     apps/reporting/src/exports/export-size.ts
line:     15
command:  /audit-data-quality
class:    decoy/EX-3 (precedents/data-engineering.md § 39)
anchor:   if (out.length > EXPORT_MAX_ROWS) throw new ExportTooLargeError(kind, out.length);
match:    EXPORT_MAX_ROWS|ceiling|export-size
match:    truncat|silent|cap
```

```decoy
id:       DE-DECOY-32
file:     apps/reporting/src/exports/iso-export.mapper.ts
line:     5
command:  /audit-data-quality
class:    decoy/EX-4 (ISO-8601 UTC, exact decimals)
anchor:   at_utc: row.at.toISOString(),
match:    toISOString|iso-export
match:    zone|lossy|offset
```

```decoy
id:       DE-DECOY-33
file:     apps/reporting/src/platform/db-snapshot-export.ts
line:     13
command:  /audit-data-quality
class:    decoy/EX-2 (one snapshot)
anchor:   { isolationLevel: IsolationLevel.REPEATABLE_READ, readOnly: true },
match:    REPEATABLE_READ|db-snapshot-export
match:    snapshot|consistent|FK
```

```decoy
id:       DE-DECOY-34
file:     apps/reporting/src/exports/partner-match.ts
line:     7
command:  /audit-data-quality
class:    decoy/PC-3 (precedents/data-engineering.md § 31)
anchor:   return createHmac('sha256', key).update(email.trim().toLowerCase()).digest('hex');
match:    createHmac|partner-match
match:    unsalted|reversible|pseudonym
```

```decoy
id:       DE-DECOY-35
file:     apps/reporting/src/exports/google-sheet-push.ts
line:     8
command:  /audit-data-quality
class:    decoy/PC-5 (precedents/data-engineering.md § 34)
anchor:   await sheets.spreadsheets.values.update({
match:    google|sheet
match:    third.?party|PII|retention|export
```

```decoy
id:       DE-DECOY-36
file:     scripts/refresh_preview_masked.sh
line:     4
command:  /audit-data-quality
class:    decoy/PC-4 (masked restore)
anchor:   psql "$PROD_REPLICA_URL" -c "SELECT anon.start_dynamic_masking();"
match:    anon|preview|pg_dump
match:    mask|production|lower
```

```decoy
id:       DE-DECOY-37
file:     infra/terraform/report_archive.tf
line:     5
command:  /audit-data-quality
class:    decoy/PC-5 (lifecycle present)
anchor:   resource "aws_s3_bucket_lifecycle_configuration" "report_archive" {
match:    report_archive|lifecycle
match:    retention|expir|forever
```

---

Sources: the batch-8 data-engineering eval (2026-10-19) § 2, § 3.2 and § 5.12, and the research catalog
`research-data-engineering.md` § 1, § 4 and § 5. The decoys re-create the real target's correct shapes (whole-day
replacement, quarter buckets, a trigger list held equal by a spec, a reconciliation that marks stale, a guarded
find-then-insert, keyset export paging compared in SQL, a refusing export ceiling, a merchant's own-data push, a
closed-period snapshot) under fictional names. No text is reproduced from any source.
