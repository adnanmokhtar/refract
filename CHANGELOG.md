# CHANGELOG

All notable changes to claude-config and its commands. Per-pack changelogs live under `templates/packs/<name>/CHANGELOG.md` (Hard rule A27).

The format is loosely inspired by Keep a Changelog. Versions follow Semantic Versioning at the command level: major = breaking artifact-shape change; minor = new capability; patch = fix or doc.

## [Unreleased]

## [2.0.0] — 2026-04-28

### M3 — Polish (this release)

#### Added
- `commands/setup-project-health.md` — read-only health reporter (digest age, ADRs, drift, budgets, dead files, adapter parity, idempotency markers, version drift). Exits 0/1.
- `commands/learn-from-task.md` — Phase 6 manual entry point; respects the persistence pyramid (raw → conventions → ADRs).
- `templates/repo-baseline/.claude/agents/knowledge-curator.md` — recurring counterpart; budget-enforcing; never edits ADRs; "no-op" is a valid run.
- `templates/persona.md` — full prose preserved; orchestrator now references via 5-bullet summary.
- `templates/phases/phase-5-checklist.md` — Phase 5 audit as a checklist (8 sections, must/should rows, halt+retry policy).
- `CHANGELOG.md` (this file).

#### Changed
- `templates/governance/hard-rules.md` reformatted from prose to ID-keyed tables (A01–A36 Always, N01–N20 Never) with severity column. Full prose preserved as reference below the table; Phase 5 references rules by ID.
- `commands/setup-project.md` persona block compressed to 5 bullets + reference to `@templates/persona.md`.
- `README.md` workflow section + milestone status updated for M3.

#### Known follow-ups (deferred)
- Phase 4 file remains at ~1500 lines — sub-phase split (4.0 / 4.2 / 4.6-DEEP / 4.7-DEEP / 4.8-DEEP) is open.
- `templates/capabilities.md` (~830 lines) not yet split per-capability.
- `scripts/lint-track.sh` (track schema validator) not yet implemented.
- `/setup-project --upgrade` migration runner not yet implemented (versioning scaffold + `templates/migrations/` exist; runner is M4).
- Snapshot test runner (`tests/setup-project/run.sh`) not yet implemented; fixtures exist.

### M2 — Split monolith into orchestrator + phase plugins (commit 1bc91cd)

#### Added
- `templates/phases/phase-{0..6}-*.md` — one file per execution phase, each with a frontmatter contract (inputs, outputs, exit criteria, applies-to-modes).
- `templates/critical-execution-rules.md` — the 7 hard guardrails extracted from the monolith head.
- `templates/quick-start.md` — flags, end states, cheat sheet.
- `templates/knowledge-hub.md` — tracks/domains/agents/skills inventory.
- `templates/decision-engine.md` — 4-input reasoning + tie-breaks + self-audit.
- `templates/idempotency.md` — re-run safety contract + managed-marker convention.
- `templates/tracks/_loader.md` — track plugin schema (detect.md weighted signals + pack.md emits contract + meta.yaml).
- `templates/governance/hard-rules.md` (initial extraction; reformatted in M3).
- `templates/canonical-command-template.md` — META: shape of generated commands.
- `templates/capabilities.md` — 7 cross-cutting features (versioning, health, schema, failures, fixtures, multi-language, wizard).
- `templates/appendices.md` — A–F (detection, filter, merge, profile, learnings, glossary).
- `commands/setup-project-adapters.md` — sibling command holding adapter detail.

#### Changed
- `commands/setup-project.md` reduced from 5,153 lines → 236 lines. Behavior preserved via @-imports.

### M1 — Foundation (commit a712053)

#### Added
- `scripts/sync-to-global.sh` — symlink-based sync from this repo to `~/.claude`.
- `scripts/verify-sync.sh` — drift detection.
- `tests/setup-project/` — fixture stubs (empty / django / nextjs / monorepo) + snapshots placeholder.
- `README.md` — workflow doc (edit-here-then-sync) + milestone status.

#### Changed
- `~/.claude/commands/` and `~/.claude/templates/` are now managed symlinks back to this repo. Backup tarball at `~/.claude-backup-20260428-125420.tar.gz`.

## [1.0.0] — pre-2026-04-28

The 5,153-line monolith era. Original archived at `.archive/setup-project.M1.monolith.md`.
