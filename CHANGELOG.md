# CHANGELOG

All notable changes to claude-config and its commands. Per-pack changelogs live under `templates/packs/<name>/CHANGELOG.md` (Hard rule A27).

The format is loosely inspired by Keep a Changelog. Versions follow Semantic Versioning at the command level: major = breaking artifact-shape change; minor = new capability; patch = fix or doc.

## [Unreleased]

## [2.1.0] — 2026-04-28

### M4 — Verification + tooling

#### Added (executable tools)
- `tests/setup-project/run.sh` — snapshot test runner (shape-only mode today; full-runner mode documented but stubbed pending automation strategy).
- `scripts/lint-track.sh` — validates `templates/tracks/<name>/` against the schema (required files, frontmatter keys, signal kinds, weights, merge modes).
- `scripts/migrate-setup.sh` — applies a named migration to a target repo. Implements the `v1-to-v2` migration spec; dry-run by default.
- `scripts/smoke-test.sh` — structural integrity check: command parsing, import resolution, track lint, phase frontmatter, HOT-tier budget, sync state, fixture shape. Exits 0 healthy / 1 broken.

#### Added (artifacts)
- `templates/migrations/v1-to-v2.md` — migration spec for the M2 split (markers, version stamps, derived files, adapter re-sync). Idempotent.
- `templates/import-tiers.md` — HOT / WARM / COLD definitions with line budgets. HOT ≤ 600 lines combined. Tier-budget audit lives in `/setup-project-health` (C7).
- `templates/tracks/web-backend-django/` — first concrete track plugin under the M2 schema. Has `detect.md` (signals + threshold + exclusive-with), `pack.md` (emits contract), `conventions.md` (Django MUST / MUST-NOT rules), `meta.yaml`. Validates the schema end-to-end.

#### Changed
- `commands/setup-project.md` `imports:` reorganized into HOT / WARM / COLD groups. Loaders are expected to honor tier when pulling content.
- `templates/governance/hard-rules.md` — added "Top 10" surface at the top, ranking the highest-impact rules so readers see the floor before the full table.
- `templates/phases/phase-5-verify.md` (was 577 lines) split into:
  - `phase-5-verify.md` (397 lines, orchestrator)
  - `phase-5.0-retry.md` (coverage check + retry loop)
  - `phase-5.1-baseline.md` (required-baseline + inventory diff)
  - `phase-5.5-quality.md` (REFINE-only setup-quality score)

#### Verified
- `scripts/smoke-test.sh` — all 7 checks pass: 0 fail, 0 warn.
- `scripts/lint-track.sh` — `web-backend-django` track validates clean.
- `scripts/sync-to-global.sh` — 30 symlinks ok, 0 drift.

#### Still deferred to M5+
- Real `/setup-project` invocation against fixtures (the runner has the harness; the missing piece is non-interactive CLI invocation strategy — Claude Code commands are model-executed prompts, not shell commands). Two paths documented in `tests/setup-project/run.sh` header.
- Snapshots — empty until a real runner records them.
- Additional tracks — `web-frontend-nextjs`, `mobile-react-native`, `data-pipeline-airflow`, etc.
- Migration runner Step 2 (auto-wrapping existing managed regions) is currently advisory; a non-interactive runner is too risky for that step. User runs it manually and re-runs migrate-setup.sh.

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
