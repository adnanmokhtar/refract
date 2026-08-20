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
- skills: `grain-probe` is the one skill nothing else in the pack can substitute — every uniqueness and aggregation claim in every other artifact cites its output, so minimal mode without it would leave the agents unable to reach a verdict; `lineage-trace`, `contract-diff`, and `warehouse-scan-audit` need a consumption layer, a declared contract, and query-history access respectively, none of which minimal mode can assume.
- rules: `data-engineering-principles` is the single rules file in the pack.
- ai-patterns: `dimensional-model` (grain, additivity, SCD, conformance) and `data-quality-tests` (the four trust floors) back the two essential agents directly. `transformation-layers` and `semantic-layer` are gated on a transformation framework being present, and `data-contract` on there being an upstream producer to negotiate with — all three ship in standard mode.

## What this pack is for

- Deciding what one row of an analytical table means, and proving it.
- Keeping transformation code layered, referenced, and singular.
- Making the warehouse able to tell you when it is wrong.
- Restating history without overwriting it.

## What this pack is NOT for

- OLTP schema, indexes, and application migrations — that is the `database` pack.
- Whether a load is idempotent, checkpointed, and backfill-isolated — that is the `data-pipeline` technical signal (`/audit-pipeline`, `@data-pipeline-reviewer`).
- Product-analytics tracking plans and event schemas — that is the `analytics` technical signal.
- The cost envelope, budgets, and unit economics of the warehouse bill — that is the `finops` pack; this pack owns the SQL that produces the bill.

## How this pack relates to others

- **`data-pipeline` signal** — the closest neighbour and the cleanest split: it owns MOVEMENT (idempotency, checkpoints, DLQ, backfill isolation), this pack owns SHAPE and TRUST. `/backfill-plan` refuses to produce an executable plan until that signal's review has cleared the loader as idempotent.
- **`database`** — supplies the source schema. This pack never proposes an OLTP change; it reports the source constraint it needs.
- **`observability`** — data assertions that page reuse its alert routing and runbook conventions rather than inventing a second paging path.
- **`business`** — `/suggest-metrics` decides which metrics a domain should have; `semantic-layer` makes each of them singular.
- **`finops`** — receives the money total from `warehouse-scan-audit`; owns the budget, not the SQL.
