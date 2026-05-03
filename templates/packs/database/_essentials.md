---
track: database
purpose: Schema design, migrations, and query performance for the data layer.
essentials:
  agents: [schema-architect, schema-reviewer]
  commands: [add-migration, db-audit]
  skills: [schema-diff, schema-consistency-audit]
  rules: [database-principles]
  ai-patterns: [migrations]
---

# Database — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: schema-architect designs, schema-reviewer audits — the minimum design+review pair for safe schema work.
- commands: add-migration is the most frequent DB task; db-audit is the periodic health gate.
- skills: schema-diff lets you see what an entity change implies in SQL — essential before generating a migration.
- rules: database-principles is the single rules file in the pack.
- ai-patterns: migrations (the most common DB pattern; safety + reversibility live here).
