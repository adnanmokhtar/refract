# Larkmoor data platform

Larkmoor sells home goods online and in 40 stores. This repository holds the data platform:

- `analytics/` — the dbt project (staging → intermediate → marts; snapshots; seeds for local development).
  `dev` builds into a local duckdb file; `prod` is the BigQuery project.
- `dags/`, `assets/`, `flows/` — Airflow 3 DAGs, Dagster assets for the finance ledger, a Prefect flow for the
  logistics partner push.
- `spark/`, `etl/` — PySpark jobs for the event lake, Python and SQL loaders, the CDC merge.
- `cdc/` — Debezium and Kafka Connect configurations.
- `gx/`, `soda/` — data checks.
- `apps/reporting/` — the reporting service inside the commerce app (NestJS, MikroORM, Postgres; the legacy shop
  database is MySQL): rollups, dashboards, exports, the platform dump and privacy requests.
- `warehouse/` — exported job history and monthly data snapshots used for cost and change reviews; Snowflake DDL for the
  support replica.
- `infra/terraform/` — buckets for exports and archives.

Local checks: `./verify.sh` builds the dbt project on duckdb in a scratch folder (needs `pip install -r requirements.txt`).
