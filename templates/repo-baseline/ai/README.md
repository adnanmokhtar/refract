# ai/ — Project Knowledge Base

Treat this folder as the long-lived project brain. Claude reads it at session start; you keep it current as the project evolves.

## Tiered loading (token efficiency)

| Tier | When | Files |
|------|------|--------|
| **1 — HOT** | Every session | `_session-digest.md` (and root `CLAUDE.md` outside this folder) |
| **2 — WARM** | Task-matched | `_convention-cheatsheet.md`, `_decision-index.md`, `business-domain.md`, `business-flows.md` |
| **3 — COLD** | On demand (load-trigger documented at top of each file) | Full `conventions.md`, `architecture.md`, `stack.md`, `modules.md`, `business-model.md`, `competitive-context.md`, `roadmap.md`, `core/*`, `runtime/*`, `patterns/*`, `decisions/*`, `runbooks/*`, `.claude/rules/*` |

Derived Tier 1–2 files (`_session-digest.md`, `_decision-index.md`, `_convention-cheatsheet.md`) are **auto-maintained** from sources — prefer editing `status.md`, `decisions/`, `conventions.md`, then regenerating via `knowledge-curator` / `/audit-knowledge`.

## Root files

Each file's tier is shown in brackets. Tier-3 files carry a `Read by:` / `Load trigger:` line at the top so they get loaded on the right task instead of never.

- `status.md` [Tier 1, via SessionStart hook] — current state, in-flight work, recent changes. **Update after every significant change.**
- `stack.md` [Tier 3] — exact versions, scripts, build config.
- `modules.md` [Tier 3] — module/feature inventory.
- `conventions.md` [Tier 3] — full code conventions (naming, structure, style); `_convention-cheatsheet.md` is its Tier-2 view.
- `architecture.md` [Tier 3] — system shape and module boundaries; one-line shape mirrored into `_session-digest.md`.
- `project-goals.md`, `users-and-personas.md` [Tier 2/3] — product context (personas load on new-feature work).
- `business-model.md`, `competitive-context.md`, `roadmap.md` [Tier 3] — commercial context; load-trigger documented at top of each.
- `business-domain.md`, `business-flows.md` [Tier 2] — domain glossary and flows (filled when a business domain applies).
- `_session-digest.md` [Tier 1], `_decision-index.md`, `_convention-cheatsheet.md` [Tier 2] — compact derived views.

## Subdirectories

- `core/` [Tier 3] — `glossary.md` (vocabulary + entity inventory), `stakeholders.md`, `invariants.md`.
- `runtime/` [Tier 3] — `context.md` (project gotchas), `environment-quirks.md`, `dependencies-with-traps.md`, `domain-anti-patterns.md`.
- `dynamic/` — session log, changelog, drift, feedback, learned patterns (working layer).
- `patterns/` — worked examples of reusable patterns (`_template.md` for new files).
- `decisions/` — Architecture Decision Records (ADRs). Append-only.
- `runbooks/` — operational step-by-step guides (`_template.md` for new files).
- `audits/` — audit outputs (optional).
- `references/` — models, tool parity, external doc pointers.

## Rules

- `status.md` MUST have an `Updated:` line and a `## Recent Changes` section — the SessionStart hook reads it.
- **Every DERIVED knowledge file MUST record the commit it was derived from**, not only a date:
  `Updated: <YYYY-MM-DD> — derived against branch \`<branch>\`, HEAD \`<sha>\`.` This applies to
  `architecture.md`, `conventions.md`, `business-domain.md`, `_session-digest.md`,
  `_convention-cheatsheet.md` and `_decision-index.md`.

  A date cannot be checked; a SHA can. Without one, nobody — not the next agent, not the next
  reader, not the freshness audit — can answer "is this still true?", and the only honest
  answer becomes "re-derive it and find out", which is the expensive one. Measured across five
  real repos: exactly one recorded its derivation HEAD, and it was the only one where the
  question could be settled at all. It turned out to be 5 commits and 46 source files behind,
  including a commit adding the very surfaces its architecture file documents — a fact that was
  invisible in the other four. `audit-setup.sh` C2f warns on a derived file that carries no
  derivation point.
- One pattern file per concept. Don't dump everything into one doc.
- ADRs in `decisions/` are append-only. If a decision is reversed, write a NEW ADR superseding the old one; don't edit the old one in place.

## Continuous learning (Phase 6)

After setup, the learning loop keeps `dynamic/` and derived files aligned with reality. See `.claude/GUIDE.md` and `/setup-project` Phase 6 in the global command spec.
