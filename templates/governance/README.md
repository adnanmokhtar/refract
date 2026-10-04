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

## One truth per fact (Phase 3)

| File | Holds | Read by |
|---|---|---|
| `precedence.md` | which rule wins when two disagree, and the log of settled conflicts | the always-on `engineering-baseline.md` rule (8-line core), `scripts/lint-rule-conflicts.sh` |
| `thresholds.json` | every number and enum a rule enforces, by id (`THR-…`) | rules cite ids; `scripts/lint-rule-literals.sh` |
| `ownership.json` | one owner per defect class: detector → owner → fixer → fallback → pack | agent Boundary sections; the Phase-6 merge |

All three are mirrored byte-for-byte into `templates/repo-baseline/.claude/templates/governance/`
(the copy a project receives); `lint-rule-conflicts.sh` fails a stale mirror.
