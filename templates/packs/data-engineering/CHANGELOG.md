# data-engineering pack — changelog

Release history for `templates/packs/data-engineering/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record.

## 1.0.0 — 2026-08-20

- NEW pack. Covers the analytics/warehouse discipline that the `data-pipeline` technical signal
  (`templates/domains/data-pipeline/`) does not: that signal owns per-change MOVEMENT correctness
  (idempotent loads, checkpoints, DLQ, backfill isolation); this pack owns the SHAPE of what lands
  and whether it can be trusted.
- agents (4): `warehouse-modeler` (opus — grain, fact/dimension, additivity, SCD, conformance,
  join cardinality), `analytics-engineer` (opus — staging/intermediate/mart layering, materialization,
  incremental correctness, one-definition-per-metric), `data-quality-auditor` (opus — the four
  trust floors + severity/ownership/routing), `dag-reviewer` (sonnet — mechanical per-task scan of
  orchestration definitions: retries, timeouts, pools, catchup, trigger rules, window parameterisation).
- commands (4): `/add-data-model`, `/audit-data-model`, `/audit-data-quality`, `/backfill-plan`.
  `/backfill-plan` never executes a cutover — it produces an evidence ledger that authorises one.
- skills (4): `grain-probe` (the executable uniqueness proof behind every aggregation claim),
  `lineage-trace` (downstream/upstream consumers including the BI layer, with explicit PARTIAL
  reporting when the consumption layer is unreachable), `contract-diff` (ADDITIVE / BREAKING /
  SEMANTIC-BREAKING classification, with a deliberate hunt for the silent third class),
  `warehouse-scan-audit` (what the SQL actually scans, from platform query history only).
- rules (1): `data-engineering-principles`.
- ai-patterns (5): `dimensional-model`, `transformation-layers`, `data-contract`,
  `data-quality-tests`, `semantic-layer`.
- Boundaries stated in every artifact: `database` pack owns OLTP schema/queries/migrations;
  `data-pipeline` signal owns movement correctness; `finops` owns the spend envelope while
  `warehouse-scan-audit` owns the SQL producing it; `observability` owns alert routing, which data
  assertions reuse rather than duplicating; `business` `/suggest-metrics` decides WHICH metrics a
  domain needs while `semantic-layer` makes each one singular.
