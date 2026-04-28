# ai/ — Project Knowledge Base

Treat this folder as the long-lived project brain. Claude reads it at session start; you keep it current as the project evolves.

## Tiered loading (token efficiency)

| Tier | When | Files |
|------|------|--------|
| **1 — HOT** | Every session | `_session-digest.md` (and root `CLAUDE.md` outside this folder) |
| **2 — WARM** | Task-matched | `_convention-cheatsheet.md`, `_decision-index.md`, `business-domain.md`, `business-flows.md` |
| **3 — COLD** | On demand | Full `conventions.md`, `patterns/*`, `decisions/*`, `runbooks/*`, `runtime/*`, `.claude/rules/*` |

Derived Tier 1–2 files (`_session-digest.md`, `_decision-index.md`, `_convention-cheatsheet.md`) are **auto-maintained** from sources — prefer editing `status.md`, `decisions/`, `conventions.md`, then regenerating via `knowledge-curator` / `/audit-knowledge`.

## Root files

- `status.md` — current state, in-flight work, recent changes. **Update after every significant change.**
- `stack.md` — exact versions, scripts, build config.
- `modules.md` — module/feature inventory.
- `conventions.md` — full code conventions (naming, structure, style).
- `architecture.md` — system shape and module boundaries.
- `project-goals.md`, `users-and-personas.md`, `business-model.md`, `competitive-context.md`, `roadmap.md` — product and commercial context.
- `business-domain.md`, `business-flows.md` — domain glossary and flows (filled when a business domain applies).
- `_session-digest.md`, `_decision-index.md`, `_convention-cheatsheet.md` — compact derived views.

## Subdirectories

- `core/` — glossary, entities, stakeholders, invariants, architecture overview.
- `runtime/` — project quirks, environment traps, domain anti-patterns.
- `dynamic/` — session log, changelog, drift, feedback, learned patterns (working layer).
- `patterns/` — worked examples of reusable patterns (`_template.md` for new files).
- `decisions/` — Architecture Decision Records (ADRs). Append-only.
- `runbooks/` — operational step-by-step guides (`_template.md` for new files).
- `audits/` — audit outputs (optional).
- `references/` — models, tool parity, external doc pointers.

## Rules

- `status.md` MUST have an `Updated:` line and a `## Recent Changes` section — the SessionStart hook reads it.
- One pattern file per concept. Don't dump everything into one doc.
- ADRs in `decisions/` are append-only. If a decision is reversed, write a NEW ADR superseding the old one; don't edit the old one in place.

## Continuous learning (Phase 6)

After setup, the learning loop keeps `dynamic/` and derived files aligned with reality. See `.claude/GUIDE.md` and `/setup-project` Phase 6 in the global command spec.
