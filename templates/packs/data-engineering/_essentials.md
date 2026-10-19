---
track: data-engineering
purpose: Warehouse and analytics engineering — declared grain, layered transformations, data contracts, trust assertions, and safe backfills.
essentials:
  agents: [warehouse-modeler, data-quality-auditor]
  commands: [audit-data-model, audit-data-quality]
  skills: [grain-probe]
  rules: [data-engineering-principles]
  ai-patterns: [dimensional-model, data-quality-tests]
---

# Data engineering — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: `warehouse-modeler` decides whether the shape is right and `data-quality-auditor` decides whether the numbers can be trusted — the two questions every warehouse must answer on day one; `analytics-engineer` (layering + materialization, valuable only once a transformation framework is in place) and `dag-reviewer` (needs orchestration definitions to scan) are signal-gated and kept out of minimal.
- commands: the two audits are the entry points into an existing warehouse; `/add-data-model` presumes an established layering convention to mirror, and `/backfill-plan` only matters once there is history worth restating — both ship in standard mode.
- skills: `grain-probe` is the one skill nothing else in the pack can substitute — every uniqueness and aggregation claim in every other artifact cites its output, and its offline duckdb lane runs on any checkout with seeds. The nine other detectors (`incremental-load-scan` with its `model-graph.py`, `orchestration-scan`, `data-test-scan`, `derived-data-scan`, `extract-scan`, `pii-copy-scan`, `contract-diff`, `lineage-trace`, `warehouse-scan-audit`) ship in standard mode; in minimal mode `/audit-data-quality` prints their ledger rows `not run (detector not installed)` and its verdict is at best GO-UNVERIFIED.
- rules: `data-engineering-principles` is the single rules file in the pack.
- ai-patterns: `dimensional-model` (grain, additivity, SCD, conformance) and `data-quality-tests` (the four trust floors) back the two essential agents directly. `transformation-layers` and `semantic-layer` are gated on a transformation framework being present, and `data-contract` on there being an upstream producer to negotiate with — all three ship in standard mode.

## What this pack is for

- Deciding what one row of an analytical table means, and proving it.
- Keeping transformation code layered, referenced, and singular.
- Making the warehouse able to tell you when it is wrong.
- Restating history without overwriting it.

## What this pack is NOT for

- OLTP schema, indexes, and application migrations — that is the `database` pack.
- Message consumers, outbox and CDC *consumers* in application code — that is distributed-systems; application schedulers' overlap and misfire — backend `job-lifecycle-scan`. (Whether a batch or incremental load writes each row exactly once IS this pack's: `incremental-load-scan`; the `data-pipeline` overlay's `/audit-pipeline` and `@schema-reviewer` with `lens: .claude/lenses/data-pipeline-review.md` corroborate when installed.)
- Product-analytics tracking plans and event schemas — that is the `analytics` technical signal.
- The cost envelope, budgets, and unit economics of the warehouse bill — that is the `finops` pack; this pack owns the SQL that produces the bill.

## How this pack relates to others

- **`data-pipeline` overlay** — restates load mechanics in prose; when this pack's detectors are installed, detection is `incremental-load-scan` / `derived-data-scan` and the overlay's reviewer corroborates. `/backfill-plan`'s loader gate reads `incremental-load-scan` §2/§7/§8 first and falls back to `@schema-reviewer` with `lens: .claude/lenses/data-pipeline-review.md` only when the detectors are absent.
- **`database`** — supplies the source schema. This pack never proposes an OLTP change; it reports the source constraint it needs.
- **`observability`** — data assertions that page reuse its alert routing and runbook conventions rather than inventing a second paging path.
- **`business`** — `/suggest-metrics` decides which metrics a domain should have; `semantic-layer` makes each of them singular.
- **`finops`** — receives the money total from `warehouse-scan-audit`; owns the budget, not the SQL.
- **`distributed-systems`, `backend`, `security`** — message consumers and event schemas; application schedulers; PII in logs and who may export. Each detector here names its route "when installed".
