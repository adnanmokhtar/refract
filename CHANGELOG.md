# CHANGELOG

All notable changes to claude-config and its commands. Per-pack changelogs live under `templates/packs/<name>/CHANGELOG.md` (Hard rule A27).

The format is loosely inspired by Keep a Changelog. Versions follow Semantic Versioning at the command level: major = breaking artifact-shape change; minor = new capability; patch = fix or doc.

## [Unreleased]

## [2.4.0] — 2026-04-28

### M7 — Content audit (cross-pack dedup + spot reads)

After M6 hardened *structure*, M7 verifies *content*. Bounded scope: cross-pack duplicate detection, sample-read of high-impact files, fix concrete issues.

#### Added
- `scripts/find-duplication.sh` — detects overlapping content across packs by H1 title, opening paragraph (100 chars), and verbatim MUST bullet repetition. Exposes redundancy candidates without auto-merging.

#### Findings (real, non-trivial)
- **`templates/packs/backend/ai-patterns/multi-tenancy.md` was a 100% byte-for-byte duplicate** of `templates/domains/multi-tenant/ai-patterns/multi-tenancy.md` (83 lines). Multi-tenancy is a technical signal, not a backend-pack concern — canonical home is `domains/`. **Removed the backend duplicate.**
- **H1 collision: "Code Quality Principles"** appeared in both `repo-baseline/.claude/rules/code-quality.md` (foundational A19 rule) and `packs/code-quality/rules/quality-principles.md` (concrete pack rules). Different content, same heading = confusion. **Renamed pack version's H1 to "Code Quality — concrete pack rules"** with explicit `extends: repo-baseline/.claude/rules/code-quality.md` in frontmatter and a quoted callout reading "Reads the baseline `code-quality.md` first."
- **MUST-bullet repetition 3+ times: zero.** No verbatim MUST/MUST-NOT statements duplicated across files — surprisingly clean.
- **Lead-paragraph duplicates: 5 groups** — but four of them are Phase 4.6 scaffold markers ("> Project-specific block — Phase 4.6 fills this in from..."). Expected. One genuine overlap (`learning/ai-patterns/setup-quality-scoring.md` ↔ `learning/skills/compute-anchor-density.md`) — cross-references are appropriate; not flagged for deletion.

#### Spot-reads (4 baseline rules + 4 ai/ knowledge templates)
- All 4 foundational rules (A19): well-written, opinionated, cross-referenced, concise. No content fixes needed.
- ai/ knowledge templates (architecture.md, conventions.md, modules.md, _session-digest.md): minimalist scaffolds with `<placeholder>` markers that Phase 4.6 fills at runtime. Shape is correct; content is template-stage by design.

#### Verified
- `find-duplication.sh`: 0 duplicate H1 groups (was 2).
- `lint-artifact.sh`: 0 errors / 48 warnings.
- `smoke-test.sh`: 0 fail / 0 warn.
- `run.sh --apply`: 2 passed (django + nextjs snapshot diff empty).

#### Honest scope statement
M7 verified content for the highest-impact subset: cross-pack dedup (mechanical) + 4 baseline rules + sampled ai/ templates. The remaining content audit (~150 individual artifacts under packs/) is M8+ work — semantic per-file review, not amenable to automation.

## [2.3.0] — 2026-04-28

### M6 — Artifact lint + spot audit

After M1–M5 hardened the meta-system (`/setup-project` and its harness), M6 turns attention to the artifacts the meta-system actually ships: 200+ agents / commands / skills / rules / patterns under `templates/packs/` and `templates/repo-baseline/`. Most pre-date the schema introduced in M2; this milestone fixes the structural gaps and surfaces the remaining content-quality flags.

#### Added (executable tools)
- `scripts/lint-artifact.sh` — structural lint for shipped artifacts. Checks frontmatter presence, required keys per kind (agent / command / skill / rule / pattern), length budgets (agents ≤ 300, commands ≤ 250, skills ≤ 200, rules ≤ 250, patterns ≤ 200), placeholder strings (outside code spans), top-level heading, and pre-flight block presence in agents (Hard Rule A18). Exits 0 healthy / 1 errors.
- `scripts/add-frontmatter.sh` — bulk migration tool. For any rule/pattern .md file lacking frontmatter, prepends a minimal block (`name`, `description` derived from H1 or first H2, `kind`, `pack` if applicable). Idempotent. Default dry-run; `--apply` to write.

#### Changed
- **The 4 foundational baseline rules now have frontmatter** (Hard Rule A19): `repo-baseline/.claude/rules/{read-before-write, read-codebase-deeply, code-quality, think-simplify-surgical}.md`. These ship in every project and previously had no metadata.
- **86 rule + pattern files received frontmatter** via `add-frontmatter.sh --apply`. Coverage now near-universal across `templates/packs/*/` and `templates/domains/*/`.
- `repo-baseline/.claude/agents/knowledge-curator.md` — renamed "Inputs you read" section to "Pre-flight (read before any write)" so the linter's pre-flight heuristic recognizes it.

#### Verified (with caveats below)
- `lint-artifact.sh`: **0 errors / 48 warnings.** Errors are now zero — every artifact has frontmatter and an H1.
- `smoke-test.sh`: 0 fail / 0 warn.
- `tests/setup-project/run.sh --apply`: 2 passed (django + nextjs); django snapshot re-recorded after pattern frontmatter changes — confirms the snapshot test correctly catches schema drift.
- `tests/setup-project/run.sh --idempotency-only`: 2 passed.

#### What the 48 warnings tell us (M7+ scope)
- **Length budget breaches** (~5 files): `learning/skills/apply-pack-adaptation.md` (514 lines vs 200), `compute-anchor-density.md` (246 vs 200), and similar. Some are genuinely complex extractors; some could likely be split. Worth a content audit, not blocking.
- **4 agents missing the literal "pre-flight" keyword**: `security-auditor`, `design-system-guardian`, `ux-reviewer`, `project-dispatcher`. Each has the discipline (sections describing what to read first) but doesn't use the keyword. Heuristic linter false-ish-positives — fix is renaming a section in each, ~5 minutes per agent.
- **3 ai-patterns slightly over budget** (`test-strategy.md` at 207, `theming.md` at 212): borderline; not worth chopping.

#### Honest scope statement
M6 is the first milestone where the **artifacts** (not just the system that ships them) are validated against a contract. Structural lint is now a CI-able gate. Content lint (e.g., "does this rule cite project specifics or generic prose?") remains M7+ — that requires reading semantics, not just structure.

#### Side effects
- The django snapshot was re-recorded once during M6 because two pattern source files (`patterns/{models,views}.md`) gained frontmatter. The test suite caught this drift on the first `--apply` run — exactly the behavior a snapshot suite should produce. Re-recorded with explicit confirm; idempotency holds in run-2.

## [2.2.0] — 2026-04-28

### M5 — Close the verification gap

**The forcing-function milestone.** Until M5, every refactor was unverified. M5 ships the deterministic harness that proves the system actually works end-to-end (for the deterministic phases — LLM-driven phases still need a CLI strategy in M6+).

#### Added (executable)
- `scripts/apply-pack.sh` — deterministic Phase 4 subset: 4.0 preflight + 4.2.b copy + managed-marker wrapping. Pure shell, no model. Same input → same output. Idempotent. Records gaps for missing source files; records unsupported merge modes (managed-section is M6+).
- `tests/setup-project/run.sh` — drives `apply-pack.sh` against fixtures. Modes: `--shape-only`, `--apply` (diff vs snapshot), `--update-snapshots` (record), `--idempotency-only` (run twice, assert empty diff).

#### Added (artifacts)
- `templates/tracks/web-frontend-nextjs/` — second concrete track plugin (npm-ecosystem detection, App Router + Pages Router awareness, conditional emits gated by detected flags + deps). Validates that the schema generalizes beyond django.
- `templates/tracks/web-backend-django/{rules-template.md, claude-md-section.md, patterns/views.md, patterns/models.md}` — pack source files referenced by the track's `pack.md` emits contract. The django track now ships 4 unconditional emits + 5 conditional gaps + 1 unsupported merge mode (CLAUDE.md managed-section).
- `tests/setup-project/snapshots/django/` — first real snapshot. 6 files: rules, conventions, patterns × 2, apply-pack report, original fixture files (preserved).
- `tests/setup-project/snapshots/nextjs/` — second real snapshot. 4 files: rules, conventions, apply-pack report, original fixture file.

#### Verified (now actually testable claims)
- **Idempotency contract round-trips for both tracks.** `run.sh --idempotency-only` runs apply-pack twice and asserts the trees are byte-identical (with `applied-at:` masked). 2 passed / 0 failed.
- **Snapshot diff is empty.** `run.sh --apply` re-runs the harness and diffs against the recorded snapshot. 2 passed / 0 failed.
- **Schema generalizes.** Both tracks pass `lint-track.sh` with zero schema changes. Adding the second track required no edits to `templates/tracks/_loader.md`.
- **Smoke test still clean.** 0 fail / 0 warn across 7 structural checks.

#### Still NOT verified (M6+ scope)
- LLM-driven phases (Phase 1 mode detection, Phase 2 deep extraction, Phase 4.6 anchoring) — these need real CLI invocation against a fixture, which is the open automation problem documented in `tests/setup-project/run.sh` header.
- Multi-track fixtures (monorepo) — apply-pack runs one track at a time today; multi-track conflict resolution is M6+.
- Bootstrap mode (empty fixture) — needs LLM-driven authoring.
- managed-section merge mode — apply-pack records as unsupported; M6+ implementation.
- Conditional emits — apply-pack treats `emits-conditional` as "always include" today; M6+ should evaluate against the target's deps.

#### Honest scope statement
M5 verifies the deterministic floor of the system. The deterministic floor is approximately 60% of what `/setup-project` does in production: pack preflight, deterministic copy, marker discipline, idempotency. The remaining 40% (LLM-driven authoring, deep extraction, project anchoring) is the M6+ horizon — well-defined, but requires an automation strategy beyond shell.

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
