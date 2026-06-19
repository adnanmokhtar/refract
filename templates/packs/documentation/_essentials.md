---
track: documentation
purpose: Author and maintain code/architecture documentation, ADRs, and knowledge files.
essentials:
  agents: [doc-writer]
  commands: [add-adr, add-runbook]
  skills: []
  rules: [doc-principles]
  ai-patterns: [adr-template]
---

# Documentation — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: doc-writer is the universal author; api-documenter is a specialty kept out of minimal.
- commands: add-adr seeds ADR culture from day one; add-runbook seeds operational-runbook culture (incident/deploy/rollback playbooks) alongside it; doc-refresh is a maintenance task kept out of minimal.
- skills: none essential — drift scanning becomes useful only once a doc baseline exists.
- rules: doc-principles is the single rules file in the pack.
- ai-patterns: adr-template is the literal template needed before any ADR can be written.
