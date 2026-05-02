# Commands reference

The full user-facing reference for the four `/setup-project`-family commands. Source of truth: this file. Sync to `~/.claude/` is symlink-managed, so changes here apply live.

## Table of contents

- [Commands at a glance](#commands-at-a-glance)
- [`/setup-project`](#setup-project)
  - [Modes](#modes)
  - [Flags (full list)](#flags-full-list)
  - [Flag combinations + conflicts](#flag-combinations--conflicts)
- [`/setup-project-adapters`](#setup-project-adapters)
- [`/setup-project-health`](#setup-project-health)
- [`/learn-from-task`](#learn-from-task)
- [Generated commands (in target repo)](#generated-commands-in-target-repo)
- [Workflows](#workflows)
  - [First setup of a new project](#first-setup-of-a-new-project)
  - [First setup of an existing project](#first-setup-of-an-existing-project)
  - [Refresh a stale setup](#refresh-a-stale-setup)
  - [Refine — make output project-specific](#refine--make-output-project-specific)
  - [V1 → V2 migration](#v1--v2-migration)
  - [Codebase alignment — the comprehensive quality sweep](#codebase-alignment--the-comprehensive-quality-sweep)
  - [Plan-only mode (any command)](#plan-only-mode-any-command)
- [Hard rules summary](#hard-rules-summary)
- [Where things live](#where-things-live)

---

## Commands at a glance

| Command                       | Purpose                                           | Read-only? |
|-------------------------------|---------------------------------------------------|------------|
| `/setup-project`              | Scaffold or enhance a project. The brain.         | No (writes) |
| `/setup-project-adapters`     | Re-sync tool adapters (Cursor / OpenCode / Aider…) | No (writes) |
| `/setup-project-health`       | Drift / staleness / budget report                 | **Yes (no writes)** |
| `/learn-from-task`            | Promote learnings into ai/ (Phase 6 manual entry) | No (writes managed blocks only) |

Generated commands ship INTO target repos when a track is selected: `/add-endpoint`, `/add-module`, `/add-feature`, `/fix-bug`, `/review-changes`, `/migration-status`, `/port-feature`, etc. See [Generated commands](#generated-commands-in-target-repo).

---

## `/setup-project`

The orchestrator. Detects mode, runs phases, applies tracks, generates project-specific output.

### Modes

| Mode      | When                                          | What it does                                                                  |
|-----------|------------------------------------------------|-------------------------------------------------------------------------------|
| `CREATE`  | Empty folder + prompt                          | Full scaffold from prompt. Architecture, schema, phase plan, all tooling.     |
| `ENHANCE` | Existing codebase, no prior setup OR partial   | **Adds what's missing.** Doesn't overwrite custom work. Round one.            |
| `REFRESH` | Existing setup is stale or pre-dates this cmd  | Backup → extract knowledge → re-detect → merge → regen. Preserves ADRs + corrections. |
| `REFINE`  | Round-two deepening pass                       | Reads code deeply (Phases 2.7–2.12). Rewrites only `## Project-specific` blocks. Idempotent — exits with "plateau reached" when no further refinement available. |

Phase 1 detects which mode applies by scanning the target repo. You can force a mode with `--create` / `--enhance` / `--refresh` / `--refine`.

### Flags (full list)

#### Universal

| Flag             | Meaning                                                                    | Default |
|------------------|----------------------------------------------------------------------------|---------|
| `--dry-run`      | Preview the plan; write nothing.                                            | off     |
| `--plan`         | **Plan-only mode.** Runs phases 1-3, expands plan via Phase 3.5, writes `.claude/plans/<command>-<slug>-<ts>.md`, exits BEFORE generation. The plan file is the handoff artifact for any tool (Cursor / OpenCode / Aider / a human). After implementation: `/verify-plan <file>` audits drift. **Universal — also works on every generated command** (`/add-feature --plan`, `/fix-bug --plan`, etc.). | off |
| `--no-telemetry` | Disable local telemetry (`.claude/_telemetry.jsonl`).                       | off     |

#### Mode forcing

| Flag         | Meaning                                                | Default     |
|--------------|--------------------------------------------------------|-------------|
| `--create`   | Force CREATE mode.                                     | auto-detect |
| `--enhance`  | Force ENHANCE mode.                                    | auto-detect |
| `--refresh`  | Force REFRESH mode (requires existing setup).          | auto-detect |
| `--refine`   | Force REFINE mode (requires existing setup).           | auto-detect |

#### Track + signal selection

| Flag                    | Meaning                                                                     | Default |
|-------------------------|-----------------------------------------------------------------------------|---------|
| `--include=<signal>`    | Force-apply a **technical-signal** pack even if not detected. Comma-separated for multiple. Valid keys: every signal in `~/.claude/templates/domains/_registry.md`. Examples: `multi-tenant`, `webhook`, `payment`, `feature-flags`, `background-jobs`, `migration`, `align`. | off |
| `--minimal`             | Focused setup — copies only `_essentials.md` per track (~30% of full pack). Best for MVPs / prototypes. Upgrade later via `--enhance` to add the rest. | off |
| `--force-replace-all`   | Bypass merge matrix; overwrite every overlap with pack version.            | off     |
| `--force-keep-all`      | Bypass merge matrix; never overwrite existing files.                       | off     |

#### Tool adapters

| Flag                    | Meaning                                                                     | Default |
|-------------------------|-----------------------------------------------------------------------------|---------|
| `--tools=<list\|auto>`  | Tool adapters to generate. List: `--tools=claude-code,cursor,aider`. `auto`: detect existing adapters. | `claude-code` (CREATE) / `auto` (ENHANCE/REFRESH) |
| `--add-tool=<name>`     | Add ONE tool adapter on top of existing (ENHANCE-only).                    | —       |

#### Backup / safety (REFRESH-only)

| Flag                   | Meaning                                                                       | Default |
|------------------------|-------------------------------------------------------------------------------|---------|
| `--no-backup`          | **Dangerous.** Skip the Phase 0 backup. Refused unless explicitly confirmed in plan. | off (backup ON in REFRESH) |
| `--backup-dir=<path>`  | Override default backup location (`.claude/backups/<YYYYMMDD-HHmm>/`).        | default |

#### REFINE-only

| Flag                              | Meaning                                                                                                                              | Default |
|-----------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|---------|
| `--max-subagents=<N>`             | Cost cap for parallel Explore / re-anchor / adapter-sync subagents during Phases 2.7–2.12 + 4.6-DEEP + 4.8-DEEP.                   | 8       |
| `--include-incidents=<path>`      | Path to postmortem docs (e.g. `docs/postmortems/`). Phase 2.12 reads them in addition to git log. Names + dollar amounts sanitized. | off     |
| `--include-runbooks`              | Allow Phase 4.7-DEEP to write `ai/runbooks/<flow>.md` from Phase 2.9 flow narrations.                                                | off     |
| `--plateau-delta=<N>`             | Plateau-classifier threshold (max artifacts whose anchor-density changed by ≥5 between runs). Lower = stricter.                      | 2       |
| `--plateau-consumed=<F>`          | Plateau threshold for consumed deep-extraction signal (`STRONG_phases / TOTAL_phases`). 0.0–1.0.                                     | 0.85    |
| `--plateau-score=<N>`             | Plateau threshold for `avg_score`. Below this, classifier emits PLATEAU-WEAK ("anchored, but shallow").                              | 80      |

#### Read-only utilities

| Flag                  | Meaning                                                                              | Default |
|-----------------------|--------------------------------------------------------------------------------------|---------|
| `--diff`              | Show pack/template version drift between recorded versions and current `~/.claude/templates/`. Read-only. | off |
| `--health`            | Compute setup health score and exit. Read-only. (Same as `/setup-project-health`.)   | off     |
| `--validate-schemas`  | Validate every generated JSON config against `~/.claude/templates/schemas/`.         | off     |

#### UX

| Flag                    | Meaning                                                                                  | Default |
|-------------------------|------------------------------------------------------------------------------------------|---------|
| `--wizard`              | Interactive Q&A mode. Step-by-step with mock previews. Best for new team members.        | off     |
| `--lang=<ar\|en\|auto>` | Language for setup prompts + bilingual headers in CLAUDE.md / AGENTS.md. `auto` reads `$LANG`. | `auto`  |

### Flag combinations + conflicts

| Combination                          | Behavior                                                                                         |
|--------------------------------------|--------------------------------------------------------------------------------------------------|
| `--create` + `--enhance`             | **Refused.** Pick one mode.                                                                       |
| `--create` + `--refresh`             | **Refused.** REFRESH requires existing setup.                                                     |
| `--enhance` + `--refresh`            | REFRESH wins (it's the strict superset). Warns user.                                              |
| `--enhance` + `--refine`             | Pipeline: ENHANCE first (fill gaps), then REFINE (deepen). Common pattern for half-set-up legacy. |
| `--refresh` + `--refine`             | REFRESH wins. Warns to run `--refine` afterwards if artifacts still feel generic.                |
| `--refine` + `--force-replace-all`   | **Refused.** REFINE preserves user-authored sections; force-replace contradicts that.            |
| `--refine` + `--force-keep-all`      | REFINE wins for `## Project-specific` blocks. Force-keep applies to user-authored sections.       |
| `--refine` + `--minimal`             | Allowed. Keeps minimal scope, deepens essentials.                                                |
| `--refine` + `--dry-run`             | Allowed. Shows per-artifact anchor-density delta + proposed rewrites; no writes.                  |
| `--force-replace-all` + `--force-keep-all` | **Refused.**                                                                                |
| `--force-keep-all` + `--refresh`     | **Refused.** Defeats refresh's purpose. Use `--enhance` instead.                                  |
| `--no-backup` + `--refresh`          | Allowed but requires explicit confirmation in plan.                                              |
| `--no-backup` without `--refresh`    | **Refused.** REFRESH-only flag.                                                                   |
| `--diff` + any write flag            | `--diff` is read-only; write flags ignored. Warn.                                                |
| `--health` + any write flag          | Same as `--diff`.                                                                                 |
| `--include-incidents` without `--refine` | **Refused.** REFINE-only.                                                                     |
| `--include-runbooks` without `--refine` | **Refused.** REFINE-only.                                                                      |
| `--max-subagents` outside REFINE     | Ignored. Warns.                                                                                  |
| `--max-subagents=0` or negative      | **Refused.** N=1 allowed (forces serial REFINE) but warns.                                       |
| `--minimal` + `--enhance` (mature project) | Ignored — won't shrink. Warns.                                                            |
| `--minimal` + `--refresh`            | Allowed. REFRESH downgrades to essentials. Warns. Extracted knowledge still preserved.            |
| `--wizard` + prompt                  | Both apply. Prompt seeds first wizard answer.                                                    |
| `--wizard` + `--dry-run`             | Wizard completes; plan shown; no writes.                                                         |
| `--lang=ar` + workspace cascade      | Sub-projects also get `--lang=ar`.                                                                |

---

## `/setup-project-adapters`

Re-syncs tool adapters AFTER `/setup-project` produced source artifacts. Translates `.claude/rules/`, `.claude/commands/`, `.claude/agents/`, `.claude/skills/` into each enabled tool's native shape.

```
/setup-project-adapters
```

Use when:
- Adding a new tool adapter to a repo already set up.
- Re-syncing after `--upgrade` changes source artifacts.
- After editing `ai/conventions.md` or `.claude/rules/*` — push the change to non-Claude tools.

Per-adapter completeness contract (every adapter MUST translate all 4 artifact types or document a gap-disclosure): see Phase 4.8.0 in this command's source file.

---

## `/setup-project-health`

Read-only health reporter. Exits `0` healthy / `1` needs-attention. Never writes.

```
/setup-project-health
```

Checks:
1. Digest freshness (`_session-digest.md` age).
2. ADR coverage (commits implying decisions vs ADRs created).
3. Convention drift (rules whose code matches dropped to zero).
4. Budget status (file counts + line counts vs budgets in `templates/idempotency.md`).
5. Dead-file detection in `ai/`.
6. Tool-adapter parity (per-adapter contract from Phase 4.8.0).
7. Idempotency markers (`<!-- setup-project:managed -->` discipline).
8. Setup version drift (repo-stamped version vs current command version).

Output: a markdown table with one row per check + a "Recommended actions" section.

---

## `/learn-from-task`

Phase 6 manual entry. Promote concrete learnings from the just-finished task into the persistent knowledge layer.

```
/learn-from-task
```

Outputs (zero, one, or more):

| Target                                  | Trigger                                            |
|-----------------------------------------|----------------------------------------------------|
| `ai/decisions/<NNNN>-<slug>.md`         | Architectural decision (append-only ADR)           |
| `ai/conventions.md` (managed section)   | New convention with ≥2 supporting examples         |
| `ai/patterns/<name>.md`                 | Reusable pattern across modules                    |
| `ai/_baseline/failures/<NNNN>-<slug>.md` | Approach that did NOT work (don't-retry catalog)  |
| `ai/dynamic/learnings.md` (append)      | Lower-confidence note; not yet promoted            |

**Persistence pyramid:** raw → conventions → ADRs / failures. The command writes to `ai/dynamic/` first; only on the 3rd similar observation does the curator agent promote to formal.

Recurring counterpart: `knowledge-curator` agent (auto-invoked via post-task hook + weekly cron via `/schedule`).

---

## Generated commands (in target repo)

When tracks are selected, these commands ship INTO the target repo's `.claude/commands/`. They follow the canonical 7-phase template (Hard Rule A24).

### Backend track

| Command           | Purpose                                                                            |
|-------------------|------------------------------------------------------------------------------------|
| `/add-endpoint`   | New endpoint on existing module. Full chain: DTO + use-case + controller + tests.  |
| `/add-module`     | New module with entity, repository, service, endpoints.                            |
| `/add-feature`    | Cross-module orchestration (multi-module change).                                  |
| `/fix-bug`        | Structured bug-fix workflow.                                                       |
| `/endpoint-test`  | Generate + run an endpoint test against a running server.                          |
| `/log-tail`       | Tail logs filtered by request-id / tenant.                                          |
| `/trace-flow`     | Trace a request from controller → service → repository → DB.                       |
| `/analyze-module` | Audit a module's shape vs conventions.                                              |

### Frontend track

| Command                | Purpose                                                                          |
|------------------------|----------------------------------------------------------------------------------|
| `/add-page`            | New route + page component.                                                      |
| `/add-component`       | New reusable component.                                                          |
| `/add-crud-page`       | Full CRUD UI (list + detail + form).                                              |
| `/i18n-audit`          | Find missing translations.                                                       |
| `/a11y-audit`          | Accessibility audit.                                                             |

### Code-quality track

| Command           | Purpose                                                                            |
|-------------------|------------------------------------------------------------------------------------|
| `/review-changes` | Multi-axis review (correctness, conventions, perf, security) on diff vs base.     |
| `/simplify`       | Surfaces simplification candidates (over-abstraction, dead code, redundancy).      |

### Database track

| Command            | Purpose                                                                          |
|--------------------|----------------------------------------------------------------------------------|
| `/add-migration`   | Generate a migration matching the project's ORM / migration tool.                |
| `/optimize-query`  | Analyze + rewrite a slow query with EXPLAIN.                                     |
| `/db-audit`        | Schema audit — missing indexes, FK gaps, naming, NULL discipline.                |

### Migration track (when `--include=migration` or auto-detected)

The migration pack ships **two suites** of commands. Use the suite that fits.

#### Suite A — Phased migration (recommended for full V1→V2 work)

| Command                  | Purpose                                                                          |
|--------------------------|----------------------------------------------------------------------------------|
| `/migration-scan`        | Deep V1↔V2 comparison. Reads BOTH codebases. Builds `ai/migration/ledger.md` with every row `unverified` (trust nothing). Outputs `scan-report.md` with structural deltas. `--since=<commit>` for incremental on large repos. `--workspace` for cross-repo aggregation. |
| `/migration-plan`        | Reads scan + ledger. Produces `ai/migration/plan.md` — phased plan grouped by domain + dependency. Foundation first. **Honors V2's new structure (no lift-and-shift).** |
| `/migration-phase <N>`   | Executes phase N: AUDIT → GAP-FIND → PORT (V2 conventions) → VERIFY (parity test) → UPDATE ledger. Stops at phase boundary. Modes: default (interactive port-by-port), `--audit-only` (triage; pairs with `/draft-phase-adrs`), `--chain` (unattended port-loop after ADRs accepted). `--feature=<id>` for retry. |
| `/draft-phase-adrs <N>`  | **NEW (M21)** — Decisions-first batch. Reads `phase-<N>.md` audits, drafts one ADR per P0 + cross-cutting decision in `ai/decisions/`. User flips `Status: proposed → accepted` once; `--chain` then runs ports unattended against pre-approved ADRs. Cuts the "same RBAC decision 4 times across 4 features" supervision cost. |
| `/migration-gate <N>`    | Phase exit gate. Confirms every phase-N feature is `done` + `parity_test=passing`. Read-only; refuses on any blocker. Append-only `_history.md` entry on PASS. |
| `/migration-final`       | Full sweep across all phases. Optional `--re-audit` re-runs parity tests. Produces V1 retirement plan with cutover sequence + rollback procedure. |

#### Suite C — Lifecycle commands (M12 — for messy real-world migrations)

| Command                          | Purpose                                                                          |
|----------------------------------|----------------------------------------------------------------------------------|
| `/migration-rollback <N>`        | Restore phase N's pre-run state. Reverts ledger + ported files (managed blocks). User-authored content preserved. Reason mandatory; logged in `_history.md`. Backup directory NEVER auto-deleted. |
| `/migration-replan`              | Regenerate `plan.md` from current ledger. Preserves `done` rows in their original phase numbers; re-phases everything else. Use after rollbacks, after V1 changes, or when day-1 plan ages out. |
| `/migration-park <feature-id>`   | Set a hairy feature aside without blocking the phase gate. Writes `parked/<id>.md` with full context. Reversible via `/migration-unpark`. |
| `/migration-unpark <feature-id>` | Reverse a park. Restores `prior_status` + `prior_phase`. Archives `parked/<id>.md` to `parked/_resolved/`. |
| `/migration-deprecate <feature-id>` | Mark a V1 feature as **never** going to V2. Requires an Accepted ADR. Permanent — no undeprecate. Tenant-impact captured. V1 sunset date documented. |
| `/migration-workspace-status`    | Cross-repo aggregator (workspace-level). Reads each sibling repo's ledger, reports per-repo summary + cross-repo blockers + phase synchronization. Read-only. |

Workflow (interactive — fully supervised):
```
/migration-scan
/migration-plan
/migration-phase 1
/migration-gate 1
/migration-phase 2
/migration-gate 2
... (repeat per phase)
/migration-final
```

Workflow (batch — recommended for phases with ≥4 features sharing cross-cutting decisions):
```
/migration-phase <N> --audit-only      # produce baseline audits (you watch)
/draft-phase-adrs <N>                  # draft ADRs from audits (you watch)
[user reviews + flips Status: proposed → accepted in each ADR]
/migration-phase <N> --chain           # unattended port-loop (walk away)
/migration-gate <N>                    # phase exit verify (you watch)
```

Why batch: making the same RBAC / permission-slug / payload-shape decision 4× across 4 features in 4 separate `/port-feature` runs is the dominant supervision cost. Doing it once upfront with full phase context cuts ~30% of the per-feature time. Matches `migration-discipline.md`'s rule "Document every intentional behaviour break" by doing it batched, not sprinkled.

Properties:
- **Stack-agnostic** — works for frontend, API, jobs, scripts, anything with identifiable behavior.
- **Trust nothing** — every status reset to `unverified` at scan; `done` requires a passing parity test.
- **No silent ports** — `/migration-scan` and `/migration-plan` write zero code; only `/migration-phase` ports.
- **Phased gating** — next phase blocked until current is green.
- **Decisions-first option** — `--audit-only` + `/draft-phase-adrs` + `--chain` decouples decisions from execution; ADRs are auditable; ports run unattended.

#### Suite B — Per-feature commands (also available; included for finer control)

| Command              | Purpose                                                                          |
|----------------------|----------------------------------------------------------------------------------|
| `/port-feature <n>`  | Port one feature V1 → V2: extract V1 contract → architect V2 → parity tests → impl → audit. Use for one-off ports outside the phased flow. |
| `/migration-status`  | Read `ai/migration/ledger.md`, report done / in-flight / not-started + per-phase. Lighter than `/migration-gate` (no enforcement). |
| `/migration-recheck <description-or-path>` | **Plan-independent V1↔V2 spot-check + fix.** NO plan / phase / ledger required. Accepts natural-language descriptions OR paths. Scans V1 + V2 source FRESH for the area, audits parity, fixes drift in V2 to match V1; updates ledger best-effort. Pass `--register-ledger` to track. Works whether or not the area is in the migration plan. |
| `/cross-repo-task <subcommand>`           | **Cross-repo blocker registry + drain.** When a port halts with `reason: cross-repo` (e.g., backend route shape change needed). Subcommands: `register`, `list`, `update`, `close`, `drain`. Tracks blockers in `ai/migration/cross-repo-tasks.md`. Drain re-runs `/find-and-fix` on rows whose blockers landed. |
| `/migration-promote-tier <id> <new-tier>` | **Mid-port tier promotion**. Halt → user demands tier change → backfill artifacts → resume fix loop. Demotion requires `--reason`; security demotion forbidden. |

### Align track (when `--include=align` — opt-in only)

The align pack is the **codebase quality gate** — a comprehensive sweep against the gold-standard inventory. Detects + fixes drift, dead code, duplicates, reinvented wrappers, silent catches, over-abstraction, SOLID violations, clean-code violations, performance issues, and security weaknesses. Stack-agnostic; frontend stacks dispatch UI/UX detectors (a11y, design tokens, i18n, motion) automatically.

**Precondition**: `_extracted-idioms.md` must be populated. If not, run `/setup-project --refine` first.

#### Phased flow (manual — interactive checkpoints)

| Command                | Purpose                                                                          |
|------------------------|----------------------------------------------------------------------------------|
| `/align-scan`          | Deep scan. Runs 11 universal detectors (6 structural + 4 functional + stack-conditional). Builds `ai/align/ledger.md` (every row `detected`), `scan-report.md`, `findings.md`. Frontend stacks auto-dispatch UI/UX detectors. Security findings always ≥ standard tier; critical security always heavy. |
| `/align-plan`          | Reads scan + ledger. Produces `ai/align/plan.md` — phased plan grouped by class + domain + tier. Mechanical first; security front-loaded; UI/UX grouped by domain. Cap: 12 findings/phase. |
| `/align-phase <N>`     | Executes phase N. Per-finding loop: DETECT (re-verify fingerprint) → DECIDE (closure verb in 16-verb vocabulary) → FIX (mechanical edit; touch only `scope`) → VERIFY (lint + typecheck + tests + re-detect + class-specific assertions) → RECORD (one commit per finding). |
| `/align-gate <N>`      | Phase exit gate. 14-check matrix (ledger completeness, gap-count parity, net-lines on structural, no-new-symbols-except-idioms, no scope creep, mechanical, coverage non-decreasing, frontend regressions, oracle unmodified, per-tier artifacts, idiom citation, security assertion, perf baseline, security tier minimum). Read-only; refuses on any check fail. |
| `/align-final`         | Full sweep across all phases. Re-runs the audit; surfaces regressions; produces `final-report-<date>.md` with recommendations (cadence, hooks, idiom gaps). |

#### Fast flow (per-phase one-shot — mirrors `/migration-fast`)

| Command            | Purpose                                                                          |
|--------------------|----------------------------------------------------------------------------------|
| `/align-fast <N>`  | One-shot for phase N: runs the per-finding loop in parallel waves + `/align-gate <N>`. Same discipline; no human-watch pauses. Auto-routes per tier (trivial → loop; standard → loop + rationale; heavy → loop + reviewer pause). Pre-requisites: `/align-scan` and `/align-plan` must have run already. **`--re-audit`**: re-detect every row including `verified` ones; catches false-verified or drifted rows and re-fixes them in the same run. |

#### Sidecar commands

| Command                  | Purpose                                                                          |
|--------------------------|----------------------------------------------------------------------------------|
| `/align-status`          | Read-only progress reader. Per-phase summary, class breakdown, halted / parked / stalled rows. Run via `/schedule align-status weekly` for ongoing monitoring. |
| `/align-rollback <N>`    | Undo phase N. Reverts commits via `git revert` (preserves audit trail), restores ledger rows to `detected`, archives halt files. Mandatory user confirmation; cascade warning if later phases depend on phase N. |
| `/align-park <id> [reason]` | Defer a hairy finding. Sets `status: parked` with rationale; excludes from phase gate. Reversible via `/align-unpark`. |
| `/align-replan`          | Regenerate the phased plan from current ledger state. Run when plan ages out (codebase changed, parked rows piled up, prior phases revealed sequencing wrong, `/setup-project --refine` updated idioms). Preserves verified rows; re-phases the rest. Mirrors `/migration-replan`. |
| `/align-recheck <description-or-path>` | **Plan-independent quality spot-check + fix.** NO plan / phase / ledger required. Accepts natural-language descriptions OR paths. Scans source FRESH for the area via the 11 universal detectors (+ stack-conditional UI/UX); fixes drift; updates ledger best-effort. Pass `--register-ledger` to track findings going forward. Works whether or not alignment was ever set up. |

Workflow (manual — fully supervised):
```
/align-scan
/align-plan
/align-phase 1
/align-gate 1
/align-phase 2
/align-gate 2
... (repeat per phase)
/align-final
```

Workflow (fast — recommended for routine mechanical phases):
```
/align-scan
/align-plan
/align-fast 1
/align-fast 2
... (per phase from the plan)
/align-final
```

Mixed (manual for heavy phases, fast for routine):
```
/align-scan
/align-plan
/align-fast 1                          # mechanical: dead code (fast)
/align-fast 2                          # mechanical: silent catches (fast)
/align-phase 3                         # security critical (manual; supervise per row)
/align-gate 3
/align-fast 4                          # mechanical: reinvented wrappers (fast)
... etc
/align-final
```

Properties:
- **Comprehensive sweep** — covers structural drift + SOLID + clean code + performance + security + stack-specific UI/UX.
- **Stack-agnostic** — same pack, different detector dispatch via `PROJECT_KIND` (frontend / backend / data / mobile).
- **Closure-verb vocabulary is closed** — 16 verbs (5 structural + 11 functional). No new abstractions; functional adds must cite idioms from `_extracted-idioms.md`.
- **Net-lines rule split by class group** — structural rows ≤ 0 hard; functional rows small + budgeted (with idiom citation).
- **Security findings always ≥ standard tier** — critical security ALWAYS heavy.
- **One finding = one commit** — bundling hides regressions and conflates intentional behaviour change with mechanical fixes.
- **Re-detect after every fix** — gap-count parity (`gaps_in == gaps_closed`) is mandatory.

### Other tracks

DevOps (`/dockerize`, `/add-ci`), security (`/security-audit`), testing (`/add-test`, `/flaky-test-hunt`), documentation (`/doc-refresh`, `/add-adr`), observability (`/log-tail`), etc.

### `--plan` works on every generated command

Every generated command supports `--plan`. Example:

```
/add-feature checkout --plan
# → writes .claude/plans/add-feature-checkout-<ts>.md
# → exits before any code is written

# Hand the plan to a different tool, or review it, then:
/verify-plan .claude/plans/add-feature-checkout-<ts>.md
# audits drift between plan and final implementation
```

---

## Workflows

### First setup of a new project

```
cd /path/to/empty-folder
```

In Claude Code:

```
/setup-project "build a SaaS multi-tenant invoicing app with Next.js + Django"
```

Phase 1 detects CREATE mode (empty folder + prompt). Result: full scaffold + tooling for the detected stack + selected tracks.

### First setup of an existing project

```
cd /path/to/existing-repo
```

In Claude Code:

```
/setup-project
```

Phase 1 detects ENHANCE mode (code exists, no prior setup). Phase 2 profiles the codebase. Phase 3 produces a plan ("here's what I found, here's what I'll add"). After approval, Phase 4 applies — never overwriting your custom work.

Want a preview first?

```
/setup-project --dry-run
```

Plan shown, no writes.

### Refresh a stale setup

When the existing setup is older than this command, has accumulated drift, or needs a structural upgrade:

```
/setup-project --refresh
```

What happens:
1. **Phase 0 — Backup** to `.claude/backups/<YYYYMMDD-HHmm>/`. Always.
2. **Phase 0 — Extract** prior knowledge: ADRs, validated corrections, project intent. Read into memory.
3. **Phase 2 — Re-detect** the current codebase.
4. **Phase 3 — Plan** with old + new merged. Annotates "from prior" vs "from code" per item.
5. **Phase 4 — Regenerate** generic packs + conventions. ADRs + user content preserved verbatim.
6. **Phase 5 — Audit** vs the backup; reports preserved-vs-dropped.

To preview:

```
/setup-project --refresh --dry-run
```

### Refine — make output project-specific

After CREATE / ENHANCE / REFRESH, artifacts can still feel generic ("your service layer" instead of `app/services/billing.py:Billing`). REFINE deepens them.

```
/setup-project --refine
```

What happens:
1. Phases 2.7–2.12 run deep extraction (domain entities, architecture, e2e flows, conventions, perf, failures).
2. Phase 4.6-DEEP rewrites ONLY the `## Project-specific` blocks of generated artifacts.
3. Phase 4.7-DEEP refreshes `ai/` knowledge from deep extraction.
4. Phase 4.8-DEEP re-syncs every selected non-Claude adapter from the deepened source.
5. Phase 5.5 reports per-artifact density score in `.claude/_setup-quality.md`.

**Idempotent.** Re-running converges. When no further refinement available: "plateau reached" and exit without writes.

Common pattern for half-set-up legacy projects:

```
/setup-project --enhance --refine
# ENHANCE first (fill gaps), then REFINE (deepen the now-complete set)
```

### V1 → V2 migration

For a real V1+V2 codebase migration. Use the **5-command phased flow** (M10).

**Step 1 — Bootstrap migration tooling in V2.**

```bash
cd /path/to/v2-repo
```

In Claude Code:

```
/setup-project --include=migration
```

What happens:
- Phase 2 Step 16 looks for V1 layout. If V1 is a sibling directory or different repo, the command may prompt: "Where is V1?" — answer with the absolute path.
- Phase 4.2 ships the migration pack: rule, patterns, agents, skills, and 7 commands (the 5 phased commands + `/port-feature` + `/migration-status`).
- Phase 4.6 anchors every migration artifact to your V1 root + V2 root + cutover mechanism.
- The merge matrix decides per command — ADD if no project equivalent, SKIP-with-redirect if you already have a specialized version.

**Step 2 — Deep scan (build the ledger).**

```
/migration-scan
```

Reads BOTH V1 and V2 codebases. Builds `ai/migration/ledger.md` with every row `unverified` (trust nothing — even prior `done` claims reset). Outputs `ai/migration/scan-report.md` with structural deltas and recommended phasing.

**Step 3 — Generate phased plan.**

```
/migration-plan
```

Reads scan + ledger. Produces `ai/migration/plan.md` — phases grouped by domain + dependency. Foundation first (auth, tenant, infra). Each phase has measurable exit criteria. **Honors V2's NEW structure — never lift-and-shift.**

**Step 4 — Run phase 1.**

```
/migration-phase 1
```

For every feature in phase 1:
1. **AUDIT** — compare V1 vs V2 behavior across inputs / outputs / errors / auth / side effects / perf.
2. **GAP-FIND** — classify as `parity-clean` / `missing-in-v2` / `divergent` / `intentional-break`.
3. **PORT** — only if gaps exist. Uses V2 conventions (cite V2 patterns/helpers/base classes). No lift-and-shift.
4. **VERIFY** — re-run audit; parity test must pass.
5. **UPDATE LEDGER** — flip status to `done` only after verify-green.

Optional: `/migration-phase 1 --feature=<id>` for retry of one feature; `/migration-phase 1 --audit-only` for triage.

**Step 5 — Phase 1 exit gate.**

```
/migration-gate 1
```

Read-only. Confirms every phase-1 feature is `done` + `parity_test=passing`. **Refuses on any blocker.** Don't start phase 2 until this returns PASS.

**Step 6 — Repeat for each phase.**

```
/migration-phase 2
/migration-gate 2

/migration-phase 3
/migration-gate 3

... (per phase from the plan)
```

**Step 7 — Final sweep + V1 retirement plan.**

```
/migration-final
```

Confirms every feature complete across all phases. Optional `--re-audit` re-runs parity tests against current state (catches drift since gate). On COMPLETE: writes `ai/migration/retirement-plan.md` with cutover sequence + rollback procedure.

#### Hard rules for migration (from `migration-discipline.md`)

- **One feature per PR.** No port + redesign + perf + new-feature in one PR.
- **Parity is non-negotiable.** Parity tests must pass before status=done.
- **Perf uplift only when parity-preserving.**
- **Every intentional behavior break = ADR.**
- **Trust nothing.** Every `done` claim re-verified before retirement.
- **V2 is the new structure.** Cite V2 patterns/helpers when porting; never lift-and-shift.
- **Foundation first.** Auth / tenant / shared infra always go in phase 1.

### Codebase alignment — the comprehensive quality sweep

For an existing codebase that's accumulated drift / dead code / dups / silent catches / SOLID violations / clean-code rot / perf issues / security gaps. Use the align pack — single-codebase quality gate (no V1/V2 split). Same parallel-dispatch + atomic-fix discipline as migration; turned inward.

**Step 1 — Confirm preconditions.**

```bash
cd /path/to/your-repo
```

In Claude Code:

```
/setup-project-health
```

The align pack requires `_extracted-idioms.md` (the gold-standard inventory) to be populated. If not, run `/setup-project --refine` first — without an oracle, "alignment" is just opinion.

```
/setup-project --refine                  # only if _extracted-idioms.md is empty/missing
```

Mechanical CI (lint / typecheck / build / tests) MUST be green at HEAD. Existing red drowns alignment findings. Use `/check-health` (from `code-quality` pack) to verify.

**Step 2 — Install the align pack.**

```
/setup-project --include=align
```

What happens:
- Phase 2 confirms `_extracted-idioms.md` is non-empty + identifies `PROJECT_KIND` (frontend-* / backend-* / data-* / mobile-*).
- Phase 4.2 ships the align pack: rule (`align-discipline.md`), 2 skills, 9 commands, validator script.
- Phase 4.6 anchors every align artifact to your codebase root + test runner + lint commands + (frontend) a11y / visual / bundle-size tools.
- Per-stack detectors auto-include from sibling packs (`code-quality`, `security`, plus `frontend` + `ui-ux` for `frontend-*`).

**Step 3 — Deep scan (build the findings ledger).**

For an UNTOUCHED codebase that's never been aligned, use `--first-run`:

```
/align-scan --first-run                  # excludes heavy + clean-code; caps at 20/class
```

This typically yields 80–150 findings (vs 200–800+ without the flag) — a manageable phase 1. Clean-code + heavy-tier rows defer to follow-up sweeps after the team has built workflow confidence. For incremental validation on a single module before a full sweep:

```
/align-scan --scope=src/auth/ --first-run    # validate the workflow on one module first
```

For routine cadence sweeps (after the first run), use the full scan:

```
/align-scan
```

Reads the codebase against `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md`. Runs 10 universal detectors in parallel waves:
- **Structural** (6): dead-code, duplicated-logic, reinvented-wrapper, silent-catch, over-abstraction, drift.
- **Functional** (4): SOLID violation, clean-code, performance, security (security includes deps-audit as a sub-class).
- **Stack-conditional**: a11y / design tokens / i18n / motion / lifecycle / default-true wrappers / permission gates for `frontend-*`; tenant-gate / N+1 / transaction-boundary for `backend-*`; etc.

Outputs `ai/align/ledger.md` (every row `detected`, with `<path:line>` evidence), `scan-report.md`, `findings.md`. Security findings always ≥ standard tier; critical security (SQL injection, secret-in-code, RCE vectors) ALWAYS heavy.

**Step 4 — Generate phased plan.**

```
/align-plan
```

Reads scan + ledger. Produces `ai/align/plan.md` — phases grouped by class + domain + tier. Cap: 12 findings/phase. Mechanical-first; security front-loaded (phase 2 typically); UI/UX grouped by page/domain (e.g., "auth pages a11y + tokens + i18n").

**Step 5a — Run a phase (manual flow).**

```
/align-phase 1
```

For every finding in phase 1, the per-finding loop:
1. **DETECT** — re-verify the fingerprint at evidence lines is still present.
2. **DECIDE** — confirm closure verb is in the 16-verb vocabulary; confirm fix is appropriate to row's class.
3. **FIX** — apply the verb-specific edit. Touch only files in `scope`. Net-lines ≤ 0 for structural rows; small + budget for functional rows (added lines must cite the row's `idiom_cited`).
4. **VERIFY** — lint + typecheck + scoped tests + re-detect (universal); plus class-specific assertions (security gates / perf baselines / frontend regressions).
5. **RECORD** — update ledger; one commit per finding.

**Step 5b — OR run the fast flow (recommended for routine mechanical phases).**

```
/align-fast 1                           # one-shot phase 1: per-finding loop in parallel + auto-gate
```

Same discipline; parallel waves; no human-watch pauses. Heavy-tier rows pause for reviewer approval; trivial/standard continue. Mirrors `/migration-fast` exactly — runs ONE phase, requires `/align-scan` + `/align-plan` to have run already.

**Step 6 — Phase exit gate.**

```
/align-gate 1
```

Read-only. Runs the 14-check matrix:
1. Ledger completeness.
2. Gap-count parity (`gaps_closed == len(evidence)`).
3. Net-lines on structural rows ≤ 0.
4. No new symbols (with idioms-named exemption).
5. No scope creep.
6. Mechanical (lint + typecheck + tests) green.
7. Coverage non-decreasing.
8. Frontend regressions (a11y / visual / bundle-size) green for `frontend-*`.
9. Oracle (`_extracted-idioms.md` etc.) unmodified.
10. Per-tier artifacts complete.
11. Functional adds cite idiom.
12. Security assertion present (every security row has a co-committed assertion test).
13. Perf baseline + assertion present.
14. Security tier minimum (no security at trivial; critical at heavy).

Refuses on ANY check fail. Don't start phase 2 until this returns PASS (or use `/align-fast` which auto-gates).

**Step 7 — Repeat for each phase.**

```
/align-fast 2                           # next phase, fast flow
# OR
/align-phase 2                          # next phase, manual flow
/align-gate 2

... (per phase from the plan)
```

**Step 8 — Final sweep + cadence recommendations.**

```
/align-final
```

Confirms every finding closed across all phases. Optionally `--re-scan` to surface drift since the original scan. Produces `ai/align/final-report-<date>.md` with:
- Aggregate impact (lines removed, security findings closed, perf uplifts, dead code removed).
- Outstanding parked findings (revisit per `/align-unpark`).
- Recommendations for next cadence (typically `/schedule align-scan +4w`).
- ADR-worthy hooks / lint-rules / pre-commit additions where alignment is rotting back.

#### Hard rules for align (from `align-discipline.md`)

- **One finding = one commit.** Bundling hides regressions.
- **Closure-verb vocabulary is closed (16 verbs).** No new abstractions; functional verbs (add-gate, parameterize, etc.) USE existing idioms from `_extracted-idioms.md` — never invent.
- **Net-lines ≤ 0 for structural rows.** Alignment is entropy-reducing.
- **Functional adds must cite idioms.** Every block of added lines references `<path:line>` in `_extracted-idioms.md` (gate / validator / cache primitive / etc.).
- **Security findings always ≥ standard tier.** Critical security ALWAYS heavy; never trivial.
- **Security and perf rows ship with assertions / baselines.** Bare gate / hopeful parallelize = halt.
- **Re-detect after every fix.** Gap-count parity (`gaps_in == gaps_closed`) mandatory.
- **Coverage non-decreasing.** A removed branch was either dead (coverage same) or load-bearing (coverage drops; halt).
- **Oracle stays read-only.** `_extracted-idioms.md` / `ai/conventions.md` / `ai/architecture.md` changes ship via `/setup-project --refine`, not align fixes.
- **Heavy-tier rows reviewed before merge.** Reviewer name + timestamp in row's `notes`.

### Plan-only mode (any command)

`--plan` is universal — it works on `/setup-project` AND every generated command (`/add-feature`, `/fix-bug`, `/add-module`, etc.).

```
/add-feature subscription-billing --plan
```

What it does:
1. Runs phases 1-3 (Understand / Organize / Retrieve).
2. Phase 3.5 expands the mini-plan into a full structured plan.
3. Writes `.claude/plans/<command>-<slug>-<YYYYMMDD-HHmm>.md`.
4. Exits BEFORE any code generation.

The plan file is the canonical handoff artifact: hand it to OpenCode, Cursor, Aider, or another human. After implementation:

```
/verify-plan .claude/plans/add-feature-subscription-billing-<ts>.md
```

Audits drift between the plan and the final implementation.

---

## Hard rules summary

The 10 highest-leverage rules. Full table at `templates/governance/hard-rules.md` (A01–A36 always, N01–N20 never).

| Rank | ID  | Rule                                                                  |
|------|-----|-----------------------------------------------------------------------|
| 1    | A04 | Respect existing user-authored content; never overwrite without confirm |
| 2    | A11 | COPY-mode tracks: copy packs verbatim (no LLM rewrite)                |
| 3    | A15 | Adapt to detected conventions; cite project specifics, not generic    |
| 4    | A19 | Always ship the four foundational `repo-baseline` rules               |
| 5    | A02 | Real content. No placeholders                                         |
| 6    | N15 | Do NOT ship generic `ai/conventions.md` when a real codebase exists   |
| 7    | A12 | AUTHOR-mode: cite only symbols traceable to extraction file           |
| 8    | A29 | Architectural agents inject `ai/failures/_index.md` in pre-flight     |
| 9    | A16 | Map every new file to a defined home in `ai/modules.md` BEFORE writing |
| 10   | N17 | Never REFRESH without backup unless `--no-backup` AND user confirmed  |

---

## Where things live

| What                              | Path                                                              |
|-----------------------------------|-------------------------------------------------------------------|
| Command files (this repo)          | `commands/`                                                       |
| Phase files                        | `templates/phases/`                                               |
| Hard rules                         | `templates/governance/hard-rules.md`                              |
| Decision engine                    | `templates/decision-engine.md`                                    |
| Idempotency contract               | `templates/idempotency.md`                                        |
| Track plugins                      | `templates/tracks/<name>/`                                        |
| Pack content (rules/agents/skills) | `templates/packs/<name>/`                                         |
| Domain (technical signal) packs    | `templates/domains/<signal>/`                                     |
| Business-domain content            | `templates/business-domains/<domain>/`                            |
| Tool-adapter contracts             | `templates/tool-adapters/<tool>/`                                 |
| Capabilities (cross-cutting)       | `templates/capabilities/`                                         |
| Migrations (setup-project schema)  | `templates/migrations/`                                           |
| Workflow scripts                   | `scripts/`                                                        |
| Tests + fixtures                   | `tests/setup-project/`                                            |
| Archived monolith                  | `.archive/setup-project.M1.monolith.md`                           |
| Sync state (machine)               | `~/.claude/commands/`, `~/.claude/templates/` (symlinks)          |
| Per-machine override               | `~/.claude/settings.local.json` (NEVER touched by sync)           |

---

## See also

- `README.md` — the elevator pitch + sync workflow.
- `CHANGELOG.md` — milestone history (M1 through current).
- `docs/setup-project-cheatsheet.md` — older one-page cheat sheet.
- `templates/quick-start.md` — flag table that's loaded by the orchestrator at runtime (this file is the user-facing version of the same content).
