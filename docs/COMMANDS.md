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
| `--include=<signal>`    | Force-apply a **technical-signal** pack even if not detected. Comma-separated for multiple. Valid keys: every signal in `~/.claude/templates/domains/_registry.md`. Examples: `multi-tenant`, `webhook`, `payment`, `feature-flags`, `background-jobs`, `migration`. | off |
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
| `/migration-scan`        | Deep V1↔V2 comparison. Reads BOTH codebases. Builds `ai/migration/ledger.md` with every row `unverified` (trust nothing). Outputs `scan-report.md` with structural deltas. |
| `/migration-plan`        | Reads scan + ledger. Produces `ai/migration/plan.md` — phased plan grouped by domain + dependency. Foundation first. **Honors V2's new structure (no lift-and-shift).** |
| `/migration-phase <N>`   | Executes phase N: AUDIT → GAP-FIND → PORT (V2 conventions) → VERIFY (parity test) → UPDATE ledger. Stops at phase boundary. `--feature=<id>` for retry; `--audit-only` for triage. |
| `/migration-gate <N>`    | Phase exit gate. Confirms every phase-N feature is `done` + `parity_test=passing`. Read-only; refuses on any blocker. Append-only `_history.md` entry on PASS. |
| `/migration-final`       | Full sweep across all phases. Optional `--re-audit` re-runs parity tests. Produces V1 retirement plan with cutover sequence + rollback procedure. |

Workflow:
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

Properties:
- **Stack-agnostic** — works for frontend, API, jobs, scripts, anything with identifiable behavior.
- **Trust nothing** — every status reset to `unverified` at scan; `done` requires a passing parity test.
- **No silent ports** — `/migration-scan` and `/migration-plan` write zero code; only `/migration-phase` ports.
- **Phased gating** — next phase blocked until current is green.

#### Suite B — Per-feature commands (also available; included for finer control)

| Command              | Purpose                                                                          |
|----------------------|----------------------------------------------------------------------------------|
| `/port-feature <n>`  | Port one feature V1 → V2: extract V1 contract → architect V2 → parity tests → impl → audit. Use for one-off ports outside the phased flow. |
| `/migration-status`  | Read `ai/migration/ledger.md`, report done / in-flight / not-started + per-phase. Lighter than `/migration-gate` (no enforcement). |

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
