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
- commands: add-adr seeds ADR culture from day one (it finds the project's own ADR folder: docs/adr, docs/decisions or ai/decisions); add-runbook seeds operational-runbook culture (incident/deploy/rollback playbooks) beside the runbooks the project already keeps; doc-refresh (refresh, `--audit`, `--from-audit`) is a maintenance and audit task kept out of minimal.
- skills: none essential — the detectors (`doc-drift-scan` with its engine `scripts/doc-claims.py`, `doc-structure-scan`, `doc-sample-scan`) and the provers (`quickstart-verify`, `docstring-coverage`, `diagram-sync`, `changelog-generate`) earn their place once a doc baseline exists, and all seven are reached through `/doc-refresh`, which is itself outside minimal. NOTE the coupling: `doc-principles` § "Four docs that must be PROVEN" and its Enforcement table name these skills and the engine's `--check` gate, so under `--minimal` they are absent. The rule is phrased to survive that — each row states the OBLIGATION and marks the tool "when installed" — but if this list ever changes, re-read both tables first. `/add-runbook` calls the engine only when it is installed and otherwise resolves step commands by hand.
- rules: doc-principles is the single rules file in the pack.
- ai-patterns: adr-template is the literal template needed before any ADR can be written.
