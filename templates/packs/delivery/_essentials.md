---
track: delivery
purpose: Deliver a feature as a run — risk tier before code, typed artifacts in ai/runs/<run-id>/, a locked acceptance contract, one writer at a time, independent verdict.
essentials:
  agents: [product-analyst, requirements-reviewer, architect, architecture-reviewer, test-engineer, plan-critic, implementer]
  commands: [add-feature]
  skills: [lane-backend, lane-frontend, lane-mobile]
  rules: []
  ai-patterns: []
---

# Delivery — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. For this pack
the minimal set IS the pack: the orchestrator dispatches every agent listed, and a missing writer turns
its phase into `UNREVIEWED(<role>)` — a run that cannot close COMPLETE. Lane skills install only for the
stack tracks the project selected (`lane-<track>` when `<track>` is selected; phase 4.2).

## What this pack is for

- One `/add-feature` for every stack, scaled by risk tier (T0 direct edit … T3 full chain with H1–H4).
- The upstream roles a feature needs before code: requirements, design, contract, plan critique.
- The one-writer rule and the run directory the hooks enforce (`artifact-ownership.sh`, `test-lock.sh`).

## What this pack is NOT for

- Bugs — `/fix-bug` (repo-baseline). Refactors — `/refactor`. Audits — the audit commands.
- Deploys — `/deploy-stage` (devops, level D; P13 is a human act, H3).
- Single-file leaves — `/add-endpoint`, `/add-page`, `/add-component`, `/add-screen` stay in their packs.

## How this pack relates to others

- **repo-baseline** — the verifier, `gate-check.py`, `risk-tier.py`, `trace-matrix.py`, `ears-lint.py`,
  the lock and the hooks this pack's run depends on.
- **backend / frontend / mobile** — their `add-feature` is a thin lane preset of this orchestrator,
  installed as `/add-feature.<stack>`; their architects and reviewers are optional deep slices and lenses.
- **product / business / testing** — the agents merged here keep shipping in those packs until the
  Phase-6 parity check; `/analyze-task` writes a spec this pack consumes.
- **security / code-quality / documentation** (always-on) — the security lenses, `@code-reviewer` and
  `@doc-writer` the run dispatches at P6b and P8–P10.
