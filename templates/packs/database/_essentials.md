---
track: database
purpose: Schema design, migrations, and query performance for the data layer.
essentials:
  agents: [schema-architect, schema-reviewer]
  commands: [add-migration, db-audit]
  skills: [schema-diff, migration-safety, n-plus-one-scan, query-shape-scan]
  rules: [database-principles]
  ai-patterns: [migrations, transaction-isolation, connection-pooling]
---

# Database — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: schema-architect designs, schema-reviewer audits — the minimum design+review pair for safe schema work.
- commands: add-migration is the most frequent DB task; db-audit is the periodic health gate.
- skills: schema-diff lets you see what an entity change implies in SQL — essential before generating a migration. migration-safety is the detector `add-migration` and `/migration-review` run on every migration; without it neither can grade a lock window. n-plus-one-scan is the most common data defect agents write, and backend `add-endpoint`'s floor row 5 requires it. query-shape-scan catches the unbounded list, the other half of that floor row. schema-consistency-audit ships in standard mode only: it halts on a repo with no declared schema conventions, which a fresh project does not have. The other detectors (`index-coverage-scan`, `schema-integrity-scan`, `transaction-scan`, `connection-config-scan`) and `/db-fix` also ship in standard mode; on a minimal install `/db-audit` prints their ledger rows `not run`, which forces `GO-UNVERIFIED`.
- rules: database-principles is the single rules file in the pack.
- ai-patterns: migrations (the most common DB pattern; safety + reversibility live here); transaction-isolation (concurrency correctness — lost updates + deadlocks are core data-integrity failures); connection-pooling (every app talks to the DB through a pool — an unbounded/per-request connection strategy exhausts `max_connections` and is a universal production outage).
