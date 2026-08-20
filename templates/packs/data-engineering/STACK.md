# Data-engineering pack — stack assumption

This pack's agents, commands, skills, and patterns assume:

- **An analytical store** that is columnar and does not enforce referential integrity or (in most cases) uniqueness constraints — a cloud warehouse or a lakehouse table format.
- **A transformation framework** with a dependency graph built from a reference function, model materializations, and a test/assertion runner.
- **An orchestrator** that injects a run window into each task and expresses dependencies as a graph.
- **Query history / job statistics** exposed by the platform, so cost and scan findings come from measurement rather than estimation.
- **A consumption layer** (BI tool, reverse-ETL, scheduled exports) whose model definitions can be read or at least enumerated.

Where any of these is absent, the affected artifact says so explicitly rather than degrading silently: `warehouse-scan-audit` halts without query history, `lineage-trace` reports `PARTIAL` without a readable consumption layer, and `contract-diff` reports `NO CONTRACT` rather than diffing against the last successful load.

## Inline examples in this pack

Examples are written in plain SQL against role-shaped names (`<model>`, `<key_expression>`, `fct_*`, `dim_*`, `stg_*`) rather than any one vendor's dialect or any one framework's macros. Substitute per stack:

| Concept (illustrated generically) | Warehouse-native | Lakehouse-native | Framework-native | Substitution source |
|---|---|---|---|---|
| reference to an upstream model | fully-qualified table | catalog.schema.table | the framework's model-reference function | the project's transformation framework |
| source declaration | external table / stage | external location | the framework's source declaration | same |
| incremental merge on a key | `MERGE INTO` | `MERGE` / upsert on the table format | the framework's incremental materialization | same |
| partition pruning column | partitioning column | partition / liquid-clustering column | model config | the platform's DDL |
| assertion | scheduled query + alert | table constraint where supported | the framework's test/assertion runner | the project's test idiom |
| query cost / scan bytes | information-schema job history | query-history table | — | the platform's own statistics |
| Type 2 capture | `MERGE` with effective dating | table-format time travel plus effective dating | the framework's snapshot materialization | same |

## Where stack-specific names live

- The project's `_extracted-codebase.md` — the warehouse platform, the transformation framework, the orchestrator, and the model directory layout.
- The project's `_extracted-idioms.md` — the reference/source function actually used, the assertion placement convention, the naming scheme, and the materialization defaults.
- `ai/data/contracts/` — the declared contracts per source and per published model.
- `ai/data/quality-contract.md` — the per-model grain, freshness SLA, failure policy, and owner.

Universal hard rules (declare and probe the grain, ship assertions with the model, one definition per metric, never overwrite during a backfill) are framework-agnostic.
