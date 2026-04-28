# templates/governance/

The "Hard Rules" overlay — Always / Never tables that govern every phase.

## Why

Currently the monolith contains "Always / Never" guidance as prose scattered through the document. M2 extracts it into a single table file imported once by the orchestrator.

## Contract

- One source file: `hard-rules.md`.
- Format: a markdown table with columns `Rule | Why | Applies-To-Phases | Severity`.
- Severity is one of `must`, `must-not`, `should`, `should-not`.
- A `must`/`must-not` violation in Phase 5 audit = command refuses to report success.
- The orchestrator imports this file ONCE; phases reference rules by ID, not by re-stating them.

Populated in Milestone 3 (governance pass).
