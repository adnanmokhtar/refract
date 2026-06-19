# Commands reference

User-facing reference for every top-level command in `commands/`. Source of truth: this file. Sync to `~/.claude/` is symlink-managed, so changes here apply live.

## Table of contents

- [Commands at a glance](#commands-at-a-glance)
- Setup family
  - [`/setup-project`](#setup-project)
  - [`/setup-project-adapters`](#setup-project-adapters)
  - [`/setup-project-health`](#setup-project-health)
  - [`/scaffold-project`](#scaffold-project)
  - [`/refine-prompt`](#refine-prompt)
- Simple-surface (whole-project, multi-area, deep multi-agent)
  - [`/migrate`](#migrate)
  - [`/align`](#align)
  - [`/optimize`](#optimize)
  - [`/refactor`](#refactor)
  - [`/polish`](#polish)
  - [`/audit`](#audit)
  - [`/unify-surfaces`](#unify-surfaces)
- Meta
  - [`/do`](#do)
  - [`/task`](#task)
  - [`/learn-from-task`](#learn-from-task)
- [Generated commands (in target repo)](#generated-commands-in-target-repo)
- [Workflows](#workflows) — see also [`docs/REFERENCE.md`](REFERENCE.md) for the canonical end-to-end walkthroughs
- [Hard rules summary](#hard-rules-summary)
- [Where things live](#where-things-live)

---

## Commands at a glance

| Command                       | Purpose                                                                | Read-only? |
|-------------------------------|------------------------------------------------------------------------|------------|
| `/setup-project`              | Scaffold or enhance a project. The brain.                              | No (writes) |
| `/setup-project-adapters`     | Re-sync tool adapters (Cursor / OpenCode / Aider…).                    | No (writes) |
| `/setup-project-health`       | Drift / staleness / budget report.                                     | **Yes** |
| `/scaffold-project`           | Generate a working project from scratch (prompt → stack → boot).       | No (writes) |
| `/refine-prompt`              | Turn a rough prompt into a structured spec.                            | No (writes ai/ only) |
| `/migrate [<scope>]`          | One-command V1→V2 port. Deep multi-agent. Brief output.                | No (writes) |
| `/align [<scope>]`            | One-command convention drift sweep.                                    | No (writes) |
| `/optimize [<scope>]`         | One-command architectural diagnosis + tactical sweep.                  | No (writes) |
| `/refactor [<scope>]`        | Targeted behaviour-preserving refactor (Fowler verbs only); not whole-project. See [`commands/refactor.md`](../commands/refactor.md). | No (writes) |
| `/polish [<scope>]`           | One-command UI/UX + API + schema + platform polish.                    | No (writes) |
| `/audit [<scope>]`            | One-command full-stack engineering audit — architecture / SOLID / clean code / security / DB perf / runtime perf / scale + resilience / infra / observability. Cross-axis ranked plan + parallel fixes. Scale-first. **Three modes**: default (scan + rank + fix), `--plan-only` (ranked fix-plan for executor handoff), `--assess` (8-section senior-engineer narrative report — what's good / improve / unify / extract / simplify / redesign / remove / optimize — read-only, for reader handoff). | No (writes) |
| `/unify-surfaces [<scope>]`   | One-command surface-type unification (frontend-*). Tables / forms / headers / tabs / filters / buttons / validation. For each: inventory every consumer, decide canonical wrapper, extract or extend, migrate every consumer in one cascade-rewrite commit. Validation extracts a 3-part pipeline (composable + `<ErrorList>` + API-error mapper). Sibling to `/polish` (axis-typed); this is surface-type-typed. | No (writes) |
| `/do <description>`           | Universal meta-router → dispatches to the right specialized command.   | Routes only |
| `/task <ref>`                 | Provider-agnostic task executor — Trello / Jira / Linear / GitHub Issue (URL, key, or `next`) → fetch title + description + attachments + checklist → execute via `/do` → write status back (in-progress → comment → done). Per-repo provider via `.env` + MCP from `detect-mcp.sh`. | No (writes + updates the card/issue) |
| `/learn-from-task`            | Promote learnings into `ai/` (Phase 6 manual entry).                   | Managed blocks |

Generated commands ship INTO target repos when a track is selected: `/add-endpoint`, `/add-module`, `/add-feature`, `/fix-bug`, `/review-changes`, `/migration-status`, `/port-feature`, etc. See [Generated commands](#generated-commands-in-target-repo).

**SOLID + clean-code discipline:** commands that write or refactor code point Phase 3 at [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) (single pointer to `align-discipline` + engineering/quality principles). Universal Phase 3 file list: [`templates/snippets/phase-3-always-reads.md`](../templates/snippets/phase-3-always-reads.md).

---

## `/setup-project`

The orchestrator. Detects mode, runs phases, applies tracks, generates project-specific output.

### Modes

| Mode      | When                                          | What it does                                                                  |
|-----------|------------------------------------------------|-------------------------------------------------------------------------------|
| `CREATE`  | Empty folder + prompt                          | Full scaffold from prompt. Architecture, schema, phase plan, all tooling.     |
| `ENHANCE` | Existing codebase, no prior setup OR partial   | **Adds what's missing.** Doesn't overwrite custom work. Round one.            |
| `REFRESH` | Existing setup is stale or pre-dates this cmd  | Backup (deterministic, in preflight) → extract knowledge → re-detect → study → apply or ledger-reject every flagged row → reconciliation audit. Preserves ADRs + corrections. Rejections persist in `.claude/_refresh-decisions.md` — never re-proposed; kept-ours/resolved rows re-open only when the pack source actually changes. |
| `REFINE`  | Round-two deepening pass                       | Reads code deeply (Phases 2.7–2.12). Rewrites only `## Project-specific` blocks. Idempotent — exits with "plateau reached" when no further refinement available. |

Phase 1 detects which mode applies by scanning the target repo. You can force a mode with `--create` / `--enhance` / `--refresh` / `--refine`.

### Flags (full list)

#### Universal

| Flag             | Meaning                                                                    | Default |
|------------------|----------------------------------------------------------------------------|---------|
| `--dry-run`      | Preview the plan; write nothing.                                            | off     |
| `--plan`         | **Plan-only mode.** Runs phases 1-3, expands plan via Phase 3.5, writes `.claude/plans/<command>-<slug>-<ts>.md`, exits BEFORE generation. The plan file is the handoff artifact for any tool (Cursor / OpenCode / Aider / a human). Execute it in-place with `/execute-plan <file>` (executors default to Sonnet — pairs with an Opus planning pass); `/verify-plan <file>` audits drift afterwards. Full loop: `--plan` → `/execute-plan` → `/verify-plan`. **Universal — also works on every generated command** (`/add-feature --plan`, `/fix-bug --plan`, etc.). | off |
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
| `--no-backup`          | **Dangerous.** Skip the Phase 0 full backup (tarball). Refused unless explicitly confirmed in plan. M35: the preflight safety-copy (`.claude/` + `ai/` + CLAUDE.md) is always taken regardless. | off (backup ON in REFRESH) |
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
9. Oracle approval + provenance (`_extracted-idioms.md` / `_extracted-codebase.md`: `approved_by:` stamp present + body hash unchanged since approval; `[unconfirmed]` claim count). Warn-only by design; prints the paste-ready stamp command when unapproved.

Output: a markdown table with one row per check + a "Recommended actions" section.

---

## `/task`

`/task <ref>` pulls ONE task from your project-management tool and does it end-to-end. Provider-agnostic — one command for Trello, Jira, Linear, or GitHub Issues.

```
/task https://trello.com/c/aB12cD34   # by URL (provider inferred from host)
/task PROJ-128                          # by key (jira)
/task next                              # top unstarted item assigned to you
/task #57 --no-writeback                # GitHub issue, don't touch labels/comments
```

**What it does** (the command owns the *lifecycle*; code work routes through `/do`):
1. **Resolve** the provider from the ref (URL host / `jira:`-`linear:`-`trello:`-`gh:` prefix / bare key / the single provider MCP in `.mcp.json` for `next`).
2. **Fetch + normalize** the card/issue to a canonical **TaskSpec** (title, description, acceptance-criteria, subtasks, attachments, status-flow) via that provider's adapter.
3. **Ingest attachments** → `.claude/tasks/<provider>-<key>/`, classified (image→design/repro ref, `.md`/`.pdf`→spec, data→fixtures).
4. **Execute** by dispatching the synthesized description to `/do` → the right specialist (`/add-feature`, `/fix-bug`, `/enhance-ui`, …).
5. **Write back**: move source to In-Progress on start → comment summary + commit/PR + per-AC ✓/✗ on finish → move to Review (or Done). Never deletes.

**Per-repo, swappable backend.** Each repo declares its provider + creds in its own `.env`; the matching MCP is wired by `scripts/detect-mcp.sh` (gated on those creds). Adding a provider = one adapter block in [`templates/integrations/task-providers.md`](../templates/integrations/task-providers.md) + one `detect-mcp.sh` entry; the command never changes.

**Flags**: `--prompt-only` (fetch + normalize, then print a paste-ready prompt and stop — no execution, no write-back; hand-off mode), `--to=<command>` (dispatch directly to `/<command>` instead of routing via `/do`), `--no-writeback` (don't touch the source), `--review-only` (stop at Review, never auto-Done).

See [`commands/task.md`](../commands/task.md).

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
| `/add-feature`    | Cross-module orchestration (multi-module change). All tiers gate on prior-art (duplicate-capability HALT) + new-dependency review. Tiered: trivial (default, sibling-mirror only) / standard (+ `n-plus-one-scan` on new list/query endpoints) / heavy (architect + reviewer dispatch, observability + security + release pre-flights). |
| `/fix-bug`        | Structured bug-fix workflow (failing-test-first + similar-bugs ledger; gates new dependencies — a fix that grows the dep tree halts for review). |
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
| `/add-feature`         | End-to-end frontend feature (pages + components + state + i18n + a11y + tests + observability sign-off). Intent-gated (routes to `/enhance-ui` if enhancement, `/fix-bug` if bug) + prior-art gate (duplicate-capability HALT) + new-dependency gate (bundle/license/supply-chain review). Standard tier adds a bundle-size delta check. Heavy tier adds a release note (flag / rollback / staging). |

**Frontend skills (agent invokes when relevant):**
- `visual-check` — Playwright screenshot at the route under change.
- `component-playground` — mount component in isolated route with prop controls.
- `verify-with-playwright` — full Playwright run.
- `dev-server-start` — start the dev server with proper env.
- `bundle-analyze` — bundle-size deltas.
- `lighthouse-ci` — Lighthouse perf score.
- `a11y-scan` — axe-core scan.
- `ssr-audit` — SSR-safety check.

### UI-UX track

| Command                | Purpose                                                                          |
|------------------------|----------------------------------------------------------------------------------|
| `/design-review`       | Read-only audit: cite-or-halt findings on UX, design-system, a11y. |
| `/enhance-ui <description>` | **Single-area enhancement (DRY-aware)**. Phase 1.5 picks scope tier: **token** / **wrapper-variant** / **wrapper-extract** / **leaf-local** so the same button is not styled twice on two pages. Cleanup includes `duplicated-surface-styles` for `frontend-*`. Flags: `--scope`, `--auto-extract`, `--dry-detect`. Then `design-iterate` (`$SCOPE_TIER`, consumer-route screenshots) → re-enforce. |
| `/ui-sweep [<phase>]`  | **Project-wide UI/UX specialist sweep**. Goes beyond align — runs 8 UI/UX-specific deep detectors (visual hierarchy, component utilization %, token coverage %, cross-surface consistency, ui-state coverage, responsive matrix, design-language coherence, visual baseline + drift). Phases by user flow (auth / checkout / dashboard / etc.), not by class. Outputs an HTML visual report with screenshots + metrics. Frontend stacks only. |
| `/ui-crawl [<scope>]`  | **Automated cross-route UI crawler** (v1.2+). Playwright + axe-core. Logs in once, visits every route in the project's route manifest, screenshots at 3 breakpoints + dark mode + RTL, walks in-page tabs, opens dialogs and dropdowns, captures console/network errors, runs axe-core per route, writes a ranked findings JSON + MD. Detect-only — pair with `/ui-crawl-fix` for auto-fix. Flags: `<scope>` (modules), `--smoke`, `--filter=`, `--full-matrix`, `--skip-interactions`, `--refresh-inventory`, `--workers=N`, `--no-dark` / `--no-rtl`. Frontend stacks only. |
| `/ui-crawl-fix [<class>]` | **Wrapper-level auto-fixer for `/ui-crawl` findings** (v1.2+). Patches at shared wrappers (`FormField`, `CrudActions`, `TableActions`, `BaseModal`, etc.) so one fix cascades through hundreds of call sites. Closes `color-contrast` (token swap), `button-name` (aria-label injection), `label` (for/id wiring), `v-html`-without-sanitize, raw library components, hardcoded translations, `target=_blank` without `rel=noopener`, empty silent catches. Skips human-judgment bugs. Re-runs `/ui-crawl` in verify mode for gap-count parity. Inherits closure-verb discipline from `align-discipline.md`. Flags: `<class>`, `--dry-run`, `--safe-only`, `--verify`, `--no-commit`, `--module=`. Frontend stacks only. |

**UI-UX skills:**
- `design-iterate` — generate 3 visual variants (polished / bolder / minimal); screenshot each; user picks.
- `design-token-audit` — find hardcoded values that should use tokens.
- `motion-audit` — find inconsistent transitions.
- `a11y-quick-check` — fast a11y scan (subset of `a11y-scan`).

#### `/ui-sweep` — step-by-step walkthrough

**The 4 commands you'll actually use**:

| When | Command | Time |
|---|---|---|
| First time only | `/ui-sweep --baseline-only` | ~5 min — screenshots every page; no code change |
| First scan | `/ui-sweep --first-run` | ~30 min — scans + plans + runs phase 1 (foundation: tokens + wrappers); produces HTML report |
| Every day after | `/ui-sweep` | runs the next pending phase (auth flow → checkout flow → dashboard → ...) |
| Add visual polish | `/ui-sweep --with-iterate` | after cleanup, dispatches design-iterate per page in the phase's flow |

**Concrete daily workflow**:

```
# Day 1 — set baseline + run first sweep
/ui-sweep --baseline-only         # before-photos of every page
/ui-sweep --first-run             # scan + plan + phase 1 (foundation)

# Days 2+ — keep running until all phases done
/ui-sweep                          # phase 2 (auth flow)
/ui-sweep                          # phase 3 (checkout flow)
/ui-sweep                          # phase 4 (dashboard)
... etc
/ui-sweep                          # final phase + cross-phase verification
```

**`/ui-sweep` figures out what step you're on automatically.** Just keep running it. Override with `/ui-sweep <phase-N>` for a specific phase, or `--with-iterate` to add visual polish.

**Output you'll see**:
- HTML report at `ai/ui-sweep/report-<date>.html` — screenshots, hierarchy heatmaps, coverage dashboards (e.g., "73% token coverage; target 95%"), cross-surface consistency matrix.
- Visual baselines at `ai/ui-sweep/baseline/<iso>/<page>.png` — comparable across sweeps.
- UI/UX-specific ledger at `ai/ui-sweep/ledger.md` (separate from align's structural ledger).

#### `/ui-crawl` + `/ui-crawl-fix` — paired DETECT → FIX → VERIFY loop

**`/ui-crawl` is the QA-style cross-route crawler.** `/ui-sweep` is the deeper specialist with HTML report + visual baselines; `/ui-crawl` is faster, broader, machine-readable. Use `/ui-crawl` for pre-release sweeps, post-token-change regression scans, and recurring CI; use `/ui-sweep` for quarterly UI/UX cadence.

**Typical loop**:

```
/ui-crawl --smoke               # ~5 min triage — 1 route per module
/ui-crawl                       # full crawl — every route, 3 breakpoints + dark + RTL + axe
/ui-crawl-fix --safe-only --verify   # auto-fix the mechanical findings; re-crawl to confirm
/ui-crawl --filter=<area>       # spot-check a fixed area
```

**What `/ui-crawl` produces**:
- `ai/audits/ui-crawl-inventory.json` — route manifest with dialog/DDL/tab counts.
- `ai/audits/ui-crawl-findings.json` — full machine-readable per-route findings.
- `ai/audits/ui-crawl-findings.md` — human triage report, ranked by severity.
- `tests/crawl/.screenshots/` — 5+ screenshots per route.
- `tests/crawl/.report/` — Playwright HTML report.

**What `/ui-crawl-fix` produces**:
- `ai/audits/ui-crawl-fix-log.md` — per-class summary: closures, commits, routes affected, residual human-triage list.
- One commit per finding-class (`fix(<class>): <verb> <wrapper> — closes <N> findings across <M> routes`).

**Pre-requisites**:
- Dev server running (`http://localhost:3000` by default).
- Test account credentials in `tests/crawl/.env` (gitignored).
- `@playwright/test` + `@axe-core/playwright` (auto-installed if missing).
- `_extracted-idioms.md` populated (selectors + wrapper inventory).

### Code-quality track

| Command           | Purpose                                                                            |
|-------------------|------------------------------------------------------------------------------------|
| `/review-changes` | Multi-axis review (correctness, conventions, perf, security) on diff vs base. Universal secret-scan (every file) + coverage-gap (untested new logic) + added-dependency review; uninstalled reviewers run inline, never skipped. |
| `/simplify`       | Surfaces simplification candidates (over-abstraction, dead code, redundancy).      |

### Database track

| Command            | Purpose                                                                          |
|--------------------|----------------------------------------------------------------------------------|
| `/add-migration`   | Generate a migration matching the project's ORM / migration tool.                |
| `/optimize-query`  | Analyze + rewrite a slow query with EXPLAIN.                                     |
| `/db-audit`        | Schema audit — missing indexes, FK gaps, naming, NULL discipline.                |

### Additional track commands

These ship with their respective packs when the track is selected/detected.

**Security track**

| Command | Purpose |
|---|---|
| `/secret-scan` | Scan repo + commit history for leaked secrets; report findings + remediation. |
| `/dependency-vuln-check` | Audit dependencies for known CVEs, abandoned maintainers, license issues. |
| `/threat-model` | Structured STRIDE threat-model session against a feature / system. |

**Observability track**

| Command | Purpose |
|---|---|
| `/alert-design` | Design alerts for a service (RED + USE + SLO-based); avoids alert fatigue. |

**Distributed-systems track**

| Command | Purpose |
|---|---|
| `/add-event-handler` | Add an event handler — idempotent / retryable / observable / DLQ-aware. |
| `/add-saga` | Implement a saga (orchestration / choreography) for a multi-step distributed flow. |
| `/design-system` | Produce a system design — service boundaries, data ownership, consistency model. |

**Mobile track**

| Command | Purpose |
|---|---|
| `/add-screen` | Add a screen — route + screen component + navigation wiring. |
| `/optimize-bundle` | Mobile bundle-size + cold-start optimization (app size, startup path). |

**Business track**

| Command | Purpose |
|---|---|
| `/analyze-task` | Turn a rough business idea into structured requirements + user stories. Writes a technical spec (with a Spec-ID) to `specs/`; build it with `/add-feature specs/<file>`, which consumes the spec instead of re-deriving (the spec→build seam). |
| `/expand-task` | Turn a one-line task into a full implementer-ready prompt with context. |

**Infrastructure track**

| Command | Purpose |
|---|---|
| `/provision-tier` | Provision a new environment tier (dev / staging / prod / DR) — IaC-driven. |

**Learning track (Phase 6 maintenance)**

| Command | Purpose |
|---|---|
| `/detect-drift` | Compare current code against documented conventions in `ai/conventions.md`. |
| `/promote-pattern` | Graduate an emerging pattern from `ai/dynamic/learned-patterns.md` to a convention. |
| `/promote-decision` | Graduate a resolved entry from `ai/dynamic/decisions-pending.md` to a numbered ADR. |
| `/audit-knowledge` | Curator health audit — stale `dynamic/` entries, drifted conventions, dead ADRs, derived-file staleness. |
| `/refresh-knowledge` | Re-run Phase 2 profiling; diff against current `ai/` and update. |

**DevOps track**

| Command | Purpose |
|---|---|
| `/rollback-deploy` | Roll back the environment to a previous known-good deploy (the recovery pair of `/deploy-stage`); `--to=<version>`. |

**Code-quality / Database / Migration (additional)**

| Command | Purpose |
|---|---|
| `/find-module` | Locate a module, feature, or concept across the codebase quickly. |
| `/migration-review` | Review a DB migration for safety, lock impact, reversibility, deploy order. |
| `/compare-v1` | Compare a feature / module / endpoint between V1 and V2 (read-only parity report). |

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
| `/migration-recheck <description-or-path> \| --phase=<N>` | **Plan-independent V1↔V2 spot-check + fix.** NO plan / phase / ledger required (except `--phase=<N>` mode). Accepts natural-language descriptions, paths, OR `--phase=<N>` to loop a whole phase WITHOUT rollback (done rows audited fresh, status preserved unless drift surfaces). Scans V1 + V2 source FRESH for the area, audits parity, fixes drift in V2 to match V1; updates ledger best-effort. Pass `--register-ledger` to track. The non-rollback alternative to `/migration-rollback <N>` + `/migration-fast <N>`. |
| `/cross-repo-task <subcommand>`           | **Cross-repo blocker registry + drain.** When a port halts with `reason: cross-repo` (e.g., backend route shape change needed). Subcommands: `register`, `list` (`--stale`), `update`, `close`, `reopen`, `drain`. `register` captures the expected contract + writes a paste-ready upstream request; `drain` contract-checks then re-runs `/find-and-fix` (a feature reaches `done` only via a clean drain, not via `close`); `reopen` recovers premature closures. Tracks blockers in `ai/migration/cross-repo-tasks.md`. `/migration-final` blocks V1 retirement while any task is open. |
| `/migration-promote-tier <id> <new-tier>` | **Mid-port tier promotion**. Halt → user demands tier change → backfill artifacts → resume fix loop. Demotion requires `--reason`; security demotion forbidden. |

### Align track (when `--include=align` — opt-in only)

The align pack is the **codebase quality gate** — a comprehensive sweep against the gold-standard inventory. Detects + fixes drift, dead code, duplicates, reinvented wrappers, silent catches, unhandled I/O (happy-path-only call sites), over-abstraction, SOLID violations, clean-code violations, performance issues, and security weaknesses. Stack-agnostic; frontend stacks dispatch UI/UX detectors (a11y, design tokens, i18n, motion) automatically.

**Precondition**: `_extracted-idioms.md` must be populated. If not, run `/setup-project --refine` first.

#### Phased flow (manual — interactive checkpoints)

| Command                | Purpose                                                                          |
|------------------------|----------------------------------------------------------------------------------|
| `/align-scan`          | Deep scan. Runs 12 universal detectors (6 structural + 5 functional + stack-conditional). Builds `ai/align/ledger.md` (every row `detected`), `scan-report.md`, `findings.md`. Frontend stacks auto-dispatch UI/UX detectors. Security findings always ≥ standard tier; critical security always heavy. |
| `/align-plan`          | Reads scan + ledger. Produces `ai/align/plan.md` — phased plan grouped by class + domain + tier. Mechanical first; security front-loaded; UI/UX grouped by domain. Cap: 12 findings/phase. |
| `/align-phase <N>`     | Executes phase N. Per-finding loop: DETECT (re-verify fingerprint) → DECIDE (closure verb in 21-verb vocabulary) → FIX (mechanical edit; touch only `scope`) → VERIFY (lint + typecheck + tests + re-detect + class-specific assertions) → RECORD (one commit per finding). |
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
| `/align-recheck <description-or-path>` | **Plan-independent quality spot-check + fix.** NO plan / phase / ledger required. Accepts natural-language descriptions OR paths. Scans source FRESH for the area via the 12 universal detectors (+ stack-conditional UI/UX); fixes drift; updates ledger best-effort. Pass `--register-ledger` to track findings going forward. Works whether or not alignment was ever set up. |

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
- **Closure-verb vocabulary is closed** — 21 verbs (5 structural + 16 functional; see `align-discipline.md`). No new abstractions; functional adds must cite idioms from `_extracted-idioms.md`.
- **Net-lines rule split by class group** — structural rows ≤ 0 hard; functional rows small + budgeted (with idiom citation).
- **Security findings always ≥ standard tier** — critical security ALWAYS heavy.
- **One finding = one commit** — bundling hides regressions and conflates intentional behaviour change with mechanical fixes.
- **Re-detect after every fix** — gap-count parity (`gaps_in == gaps_closed`) is mandatory.

### The 5 simple commands (start here)

These are the recommended user surface. One command per concern. Deep multi-agent execution. NO phases / halts / ADRs / terminology surfaced. Each takes optional `<scope>` (whole project if omitted for migrate/align/optimize/polish, or natural-language description / explicit path). **`/refactor`** defaults to git-changed paths when scope is omitted — omit whole-repo refactor here; use `/optimize` instead.

| Command | Purpose |
|---|---|
| `/migrate [<scope>]` | Deep V1↔V2 scan + compare + port everything. V1 wins on behaviour; V2 wins on structure. Doesn't leave any live V1 feature behind (skips only dead V1 code). |
| `/optimize [<scope>]` | Make code high-quality at architectural AND tactical level. Phase 0 diagnoses bigger picture (layer violations, god modules, missing abstractions, wrong-level responsibilities, cross-cutting duplication, cyclic dependencies), applies foundations FIRST. Phase 2 closes remaining tactical findings (clean code, refactoring, SOLID, performance, dead code, dedup). Architectural fixes cascade — fixing the right layer dissolves dozens of tactical findings. Stack-agnostic. |
| `/refactor [<scope>]` | Targeted behaviour-preserving refactor only — closed vocabulary from `refactoring-sweep` (extract-method, rename, flatten-conditional, …). No architectural moves, no perf, no dead-code sweeps. Ledger at `ai/refactor/ledger.md`; validator `scripts/validate-refactor-artifacts.sh`. |
| `/align [<scope>]` | Detect where code doesn't follow the project's structure (layering, naming, idioms, conventions, design tokens, a11y, i18n) + fix. |
| `/polish [<scope>]` | Stack-conditional polish. Frontend-* → closed 19-verb vocabulary in `ui-design-sweep` (ui-ux pack v1.1+) covering tokens / wrappers / hierarchy / type-scale / rhythm / density / states / contrast / focus / iconography / motion / tap-target / cta / affordance / surface — sibling to `api-consistency-audit` (backend) and `schema-consistency-audit` (data). Backend-* → API consistency (envelope, error contract, pagination, idempotency, log/metric/trace uniformity, OpenAPI gaps). Data-* → schema consistency (column naming, types, indexes, audit fields, migration patterns). Mobile-* → frontend polish + iOS HIG / Material conformance. Validator `scripts/validate-polish-artifacts.sh § check_frontend_verb_vocabulary` rejects any `closure_verb:` outside the 19-verb set (mirrors how `validate-refactor-artifacts.sh` enforces refactoring-sweep). Distinct from `/enhance-ui` (single-area iteration loop) and `/ui-sweep` (frontend specialist with HTML report). |

## `/optimize`

Full contract: [`commands/optimize.md`](../commands/optimize.md).

Each runs in one shot. End-of-run shows: findings closed, commits made, diff stats, test status — **plus the mandatory honesty clause**: `Not validated:` (what did NOT run + why, or `none — <what fully ran>`), `Risks:` (residual risk worth a human glance, or `none identified`), `Revert:` (the exact git command for the run's commit range). `Tests: green` without naming the negative space is forbidden — the Trusted Summary failure mode applied to the run report. Internal discipline is preserved (V1-parity, no fabrication, gap-count parity, idiom citation) but invisible.

Examples:
```
/migrate                              # whole project V1→V2
/migrate the orders module
/optimize                             # whole project quality
/optimize the dashboard, focus on perf
/refactor src/orders/service.ts       # targeted behaviour-preserving refactor
/refactor                             # git-changed paths only (default scope)
/align                                # whole project convention drift
/align the sidebar
/polish                               # whole project UI/UX polish (frontend only)
/polish the dashboard
/audit                                # whole project engineering + scale audit
/audit --target-rps=50000             # scale lens at 10× target traffic
/audit the orders module --plan-only  # scoped, plan only
```

**Multi-day workflow** — `/migrate`, `/optimize`, `/align`, `/polish`, and `/audit` each write to `ai/<cmd>/progress.md`. First run builds the inventory; subsequent runs pick the next pending area automatically. **`/refactor`** is different: it targets explicit paths or git-changed files by default; optional `ai/refactor/progress.md` is session notes only — it does **not** use the inventory / `--refresh` / `--re-audit` / `--restart` / `--ignore-ledger` orchestration. For whole-repo refactors, use **`/optimize`**. See [`commands/refactor.md`](../commands/refactor.md).

**Common flags** (orchestrated simple-surface commands: `/migrate`, `/optimize`, `/align`, `/polish`, `/audit` — **not** `/refactor` unless noted in [`commands/refactor.md`](../commands/refactor.md)):

```
/<cmd>                                # next pending area (or first run: build inventory)
/<cmd> <scope>                        # specific area, skip ahead
/<cmd> --status                       # read-only progress report
/<cmd> --resume                       # pick up the in-progress area
/<cmd> --reset <area>                 # mark one area pending (re-run it)
/<cmd> --refresh                      # re-scan codebase, MERGE into progress.md (new → pending, missing → archived, existing preserved)
/<cmd> --re-audit                     # IGNORE cached verdicts; re-detect EVERY area (verified/done rows re-checked; reappearing drift re-fixed). Combinable with scope.
/<cmd> --ignore-ledger                # TRULY FRESH SCAN — act as if no migration/optimize/align/polish was ever done. Backs up ledger + report + progress; re-discovers everything from source; re-creates report. KEEPS ADR pre-check + dead-code exclusion as safety nets. Combinable with scope. Heavier than --re-audit by 30-50%.
/<cmd> --restart                      # WIPE progress, back up to progress-<iso>.bak.md, start over
/<cmd> --dry-run                      # show what would change, no edits
/<cmd> --max-parallel=<N>             # cap concurrent dispatch (default: 5–6)
/<cmd> --exclude=<scope>              # exclude areas
/<cmd> --surface-blockers             # show halted findings explicitly
```

`--restart` does NOT revert any commits already made — use `git` for that.

## `/audit`

Full contract: [`commands/audit.md`](../commands/audit.md).

One command, full-stack engineering audit against system-design + engineering principles. Detects gaps across **eight axes in one pass** — architecture quality, SOLID + clean code, security (OWASP / auth / tenant / secrets / deps), database performance (schema + indexes + query plans), runtime performance (N+1, hot paths, caching), **scalability + resilience (the differentiating axis — 13 scale-lens detectors: hot-path scan, fan-out depth, sync I/O in critical path, single-instance bottleneck, lock contention, queue back-pressure, write amplification, tenant blast radius, capacity headroom, SLO delta, idempotency gaps, statelessness violations, cold-start cost)**, infrastructure + capacity, observability gaps. Cross-axis ranks findings by `impact-at-target-scale × blast-radius × fix-cost`, generates ONE unified plan, executes in tier order: **P0 scale-blockers → P1 security/correctness → P2 high-leverage scale fixes → P3 architectural foundations → P4 tactical cleanup**.

**Universal across stacks.** Works on ANY codebase — any language, any framework, any project shape:

- **Backends** — Node / TS / Python / Ruby / PHP / Java / Kotlin / Scala / C# / F# / Go / Rust / Elixir / Erlang / Crystal / Haskell / OCaml / Swift, in any framework (Express / NestJS / Fastify / Koa / Django / Flask / FastAPI / Rails / Sinatra / Laravel / Symfony / Spring / Quarkus / Micronaut / Ktor / ASP.NET / Phoenix / Echo / Gin / Fiber / Actix / Axum / Rocket).
- **Frontends** — Vue / Nuxt / React / Next / Remix / Svelte / SvelteKit / Solid / Qwik / Astro / Angular / Lit / Stencil / Preact / vanilla / jQuery legacy, SPA / SSR / SSG / ISR / streaming-SSR / islands / RSC.
- **Mobile** — iOS native (Swift / SwiftUI / UIKit), Android (Kotlin / Compose / Java), React Native, Flutter, Expo, Capacitor / Ionic, .NET MAUI, Kotlin Multiplatform.
- **Data** — Postgres / MySQL / SQL Server / Oracle / SQLite / Mongo / Dynamo / Redis / Cassandra / Neo4j / Elastic / Influx / Snowflake / BigQuery; pipelines (Airflow / Dagster / dbt); streaming (Kafka / Pulsar / Kinesis / RabbitMQ / NATS).
- **CLI / TUI / library / SDK** — startup time, public-API contract, lazy-load gaps, tree-shake regressions.
- **Serverless / edge** — AWS Lambda, Cloudflare Workers, Vercel Edge, Deno Deploy, Fastly Compute, Azure Functions, GCP CFN / Cloud Run.
- **Monorepos / polyglot** — Nx / Turborepo / Bazel / Pants / Lerna / pnpm workspaces / Cargo workspaces / Gradle multi-project. Each subtree's `PROJECT_KIND` drives axis routing for that subtree; cross-`PROJECT_KIND` fixes (e.g., backend idempotency key + frontend retry handler) bundle into one plan row.

**Stack-agnostic by construction**, not by accident. The 13 scale-lens detectors are **shape-based** (entry-point × invoke-rate × cost-per-invoke) rather than name-based. Concrete fingerprint differs per `PROJECT_KIND` — see the stack-conditional detector matrix in `commands/audit.md` (every axis × backend / frontend / mobile / CLI / serverless / data fingerprint cataloged). Specialist agents (`architectural-diagnosis`, `security-auditor`, `database-optimizer`, `system-architect`, `performance-optimizer`) are themselves stack-agnostic. New language or new framework = no detector change required; the agent learns idioms from `_extracted-idioms.md`.

Scale-first by design. Pass stack-appropriate target flags to anchor capacity-headroom + hot-path ranking. Output reports the capacity headroom delta against the target.

Distinct from siblings:
- `/optimize` — code quality + tactical perf only; no security; no scale lens.
- `/security-audit` — security only; no DB / scale / arch.
- `/db-audit` — database only.
- `/perf-audit` — runtime perf only.
- `/audit` — fuses all of the above + adds the 13 scale-lens detectors + cross-axis ranker, applied stack-conditionally. The simple-surface alternative to running them separately.

Specialist flags (in addition to common flags above) — stack-appropriate targets:
```
# Backend / serverless / pipeline (rate-driven)
/audit --target-rps=<N>               # default: 2× current OR 100
/audit --target-p95=<ms>              # default: SLOs from ai/observability.md OR 200

# Frontend (vitals-driven)
/audit --target-vitals=fcp:<ms>,lcp:<ms>,tti:<ms>,inp:<ms>,cls:<n>
/audit --target-bundle=<bytes>        # e.g., 200KB

# Serverless / mobile (cold-start-driven)
/audit --target-cold-start=<ms>

# CLI / library / SDK (startup-driven)
/audit --target-startup=<ms>

# Universal flags
/audit --plan-only                    # scan + rank + write fix-plan; no fixes (executor handoff)
/audit --assess                       # scan + write 8-section narrative assessment; no plan, no fixes (reader handoff)
/audit --focus=<list>                 # narrow axes (security,db,scale,perf,arch,quality,infra,obs)
/audit --skip-p4                      # skip tactical cleanup; focus on P0–P3
```

In a polyglot monorepo, mix flags freely — each `PROJECT_KIND` subtree picks up the flags that apply to it; non-applicable flags are ignored for that subtree.

### `--assess` — senior-engineer narrative assessment

`--assess` is the **read-only narrative mode**. Same eight-axis scan as the default; instead of ranking and executing, it writes `ai/audit/assessment.md` — an 8-section prose report a senior engineer or tech lead can read end-to-end:

1. **What's already good** — load-bearing strengths, with `<file:line>` citations (no empty praise)
2. **What needs improvement** — substantive engineering quality gaps short of redesign
3. **What should be unified** — visible inconsistencies across instances of the same surface/pattern
4. **What should be extracted or shared** — repeated logic / markup / styles / queries / DTOs / utilities to promote
5. **What should be simplified** — over-abstraction, unnecessary wrappers, premature interfaces
6. **What should be redesigned** — architecturally wrong, needs rework not cleanup
7. **What should be removed** — dead code, unused styles / components / DTOs / endpoints
8. **What should be optimized** — concrete performance / scale / cost wins

Closes with a 3–5 sentence verdict and a paste-ready `## Actionable next steps` block routing each section to its execution command (`/optimize`, `/polish`, `/unify-surfaces`, `/align`, `/security-audit`, or `/audit` without flag to execute).

**Stack-conditional rendering** — frontend-* inlines component / composable / state-management / routing / styling / design-system / a11y / typing narrative; backend-* inlines module / DTO / validation / guards-interceptors-filters / repository / transaction / API-design / testing narrative; mobile / data / serverless inherit the 8 sections with stack-appropriate axis emphasis.

Distinct from `--plan-only`:
- `--plan-only` writes `ai/audit/plan.md` — ranked P0–P4 fix-plan, closure verbs, citations, for an executor (agent or human) to act on.
- `--assess` writes `ai/audit/assessment.md` — narrative prose for a reader (stakeholder / tech lead / new joiner).
- Both are read-only and mutually exclusive. Both run the same Phase 1 multi-axis scan underneath; only the rendering differs.

```
/audit --assess                       # whole project, narrative assessment
/audit --assess apps/web              # scoped to one workspace
/audit --assess --focus=arch,quality  # narrative scoped to specific axes
/audit --assess apps/api              # senior-engineer write-up of the NestJS backend
```

## `/unify-surfaces`

Source: [`commands/unify-surfaces.md`](../commands/unify-surfaces.md). Adapter coverage: each `templates/tool-adapters/<tool>/adapter.md` (Unify-surfaces pack bullet).

**One command, surface-type unification across the entire frontend codebase.** Sibling to `/polish`, but typed by SURFACE CATEGORY instead of by axis. Where `/polish` operates per-axis (tokens / rhythm / motion / type-scale / states), `/unify-surfaces` operates per-surface-type (tables / forms / headers / tabs / filters / buttons / validation). They compose: `/unify-surfaces` first to consolidate the wrappers, then `/polish` to polish each canonical wrapper to spec.

### The 7 default categories

| Category | What gets unified |
|---|---|
| **tables** | List/data table chrome — header row, filter bar position, pagination, empty/loading states, action column, density toggle |
| **forms** | Form layout — field rhythm, label placement, input width grid, fieldset grouping, submit-row position, dirty cue |
| **headers** | Page header — title + subtitle + breadcrumb + actions zone, height, spacing, sticky behaviour |
| **tabs** | In-page tabs — strip, indicator, active state, badge, overflow, body container |
| **filters** | List-page filter panel — search + dropdowns + date-range + chip-display + clear-all + position |
| **buttons** | Button primitive variants — primary / secondary / tertiary / danger / ghost; size scale; loading / disabled / pressed; tap-target floor |
| **validation** | **3-part pipeline** — frontend validator composable + `<ErrorList>` / `<FieldError>` rendering + API-validation-error mapper that turns server `{field: [msg]}` into field-level errors. Not a single wrapper — a system. |

### The pipeline (silent, per category)

1. **INVENTORY** — find every consumer of this surface type across the codebase.
2. **DECIDE CANONICAL** — `_extracted-idioms.md § Wrappers` if named there; else cluster by shape and pick the most-used; else halt + ask.
3. **EXTRACT / EXTEND** — extend the existing shared wrapper, or extract a new one from the chosen consumer.
4. **MIGRATE CONSUMERS** — rewrite every non-canonical consumer in **one cascade-rewrite commit per category** (the point of unification).
5. **VERIFY** — typecheck + lint + scoped tests + visual-regression on non-target surfaces (must not change).

### Validation pipeline (special-cased)

Forms-then-validation order ensures each form is on the canonical layout before its validation gets unified. The validation category extracts:

- **Frontend validator composable** — single source of truth for declaring per-field rules (e.g., `useFormValidation()`).
- **Error rendering primitives** — `<ErrorList>` + `<FieldError>` with one convention for placement, tone, required-field marker, summary location.
- **API-validation-error mapper** — wired as a global response interceptor; turns server errors into field-level errors the composable attaches.

Migration order: ship the 3 primitives → wire the API mapper → migrate forms one at a time (each removes its bespoke validator + bespoke error renderer + bespoke server-error handler, replacing all three with the unified pipeline).

### Examples

```
/unify-surfaces                                 # all 7 categories, whole project
/unify-surfaces --surfaces=tables,filters       # only list-page surfaces
/unify-surfaces --surfaces=validation           # form-validation pipeline only
/unify-surfaces --surfaces=headers,tabs         # page chrome only
/unify-surfaces the orders module               # scoped — only orders pages
/unify-surfaces "the customer-facing pages"     # semantic scope
/unify-surfaces --canonical=tables=src/shared/ui/BaseDataTable.vue --canonical=headers=src/shared/ui/PageHeader.vue
```

### Multi-day workflow + common flags

Same flag set as `/migrate` / `/optimize` / `/align` / `/polish` / `/audit` — `--status` / `--resume` / `--re-audit` / `--refresh` / `--restart` / `--ignore-ledger` / `--max-parallel` / `--exclude` / `--surface-blockers` / `--dry-run`. Plus category-specific:

- `--surfaces=<list>` — subset of the 7 categories.
- `--canonical=<category>=<wrapper-path>` — force canonical wrapper (overrides idioms + inventory). Repeatable.
- `--keep-ad-hoc=<glob>` — preserve specific consumers as ad-hoc (legacy / one-offs).
- `--validation-library=<name>` — when 2+ form libraries are present, pick one.

### Output

```
Unify-surfaces complete

Stack:               frontend-vue
Scope:               whole project
Categories:          7 / 7 done

  buttons       canonical=<BaseButton>(5 variants)        298 / 312 consumers migrated
  headers       canonical=<PageHeader>(extracted)          47 /  47 consumers migrated
  tabs          canonical=<RouteTabs>(extracted)           14 /  14 consumers migrated
  forms         canonical=<BaseForm>(extended)             31 /  31 consumers migrated
  tables        canonical=<BaseDataTable>(extended)        24 /  24 consumers migrated
  filters       canonical=<FilterPanel>(extracted)         22 /  22 consumers migrated
  validation    pipeline=useFormValidation+ErrorList+apiErrorMapper  31 forms wired

Wrappers extracted: 4   Wrappers reused/extended: 3   Variants removed: 18
Commits: 7 (one per category)  Diff: +2,148 / -5,492 = -3,344 lines
Tests: 487/487  Visual-regression: target-only  Bundle: -2.1%  a11y: 81 → 96
```

### Pre-requisites

- `PROJECT_KIND` is `frontend-*` (or `mobile-web` / `mobile-rn`). Halts on backend / data / library / CLI.
- `_extracted-idioms.md § Wrappers` populated (the canonical-shape oracle).
- Mechanical CI green; working tree clean (or `--allow-dirty`).
- Playwright MCP wired (visual-regression gate; soft-fails to text-only).

## `/refactor`

Source: [`commands/refactor.md`](../commands/refactor.md). Pack overlays: `templates/packs/{code-quality,backend,frontend,mobile}/commands/refactor.md`. Adapter coverage: [`templates/tool-adapters/_refactor-pack-coverage.md`](../templates/tool-adapters/_refactor-pack-coverage.md).

For phase-by-phase or per-feature control, the detailed pack commands (`/migration-scan`, `/migration-plan`, `/migration-phase`, `/migration-fast`, `/migration-gate`, `/migration-final`, `find-and-fix`, `/align-scan`, `/align-plan`, `/align-phase`, `/align-fast`, `/align-recheck`, etc.) live under `templates/packs/migration/commands/` and `templates/packs/align/commands/`. Documented in [`docs/REFERENCE.md`](REFERENCE.md).

### Universal entry point — `/do`

`/do <description>` is the meta-router. Takes any natural-language description, picks the right specialized command, dispatches. Use when you don't remember the command name. Examples:

```
/do enhance the sidebar          → /enhance-ui
/do add a refund button          → /add-feature
/do fix the order list crash     → /fix-bug
/do audit security               → /security-audit
/do clean up the auth module     → asks: align? enhance? migration-recheck?
```

For high-confidence intent, `/do` dispatches silently. For ambiguous, asks one question. For no-match, halts with available commands listed.

### Testing track

| Command                | Purpose                                                                          |
|------------------------|----------------------------------------------------------------------------------|
| `/run-tests [<scope>]` | Run the project's test suite (or scoped subset). Detects vitest / jest / pytest / playwright / etc. Reports pass/fail/coverage delta. Called by `/align-phase`, `/migration-fast`, `/find-and-fix` VERIFY steps. |
| `/add-test`            | Author a new test. |
| `/flaky-test-hunt`     | Debug intermittent failures. |

### DevOps track

| Command                | Purpose                                                                          |
|------------------------|----------------------------------------------------------------------------------|
| `/deploy-stage`        | Deploy current branch to staging. Detects deploy mechanism (Helm / k8s / Vercel / Netlify / etc.). Pre-flight + monitor + report. Halt-on-red. |
| `/dockerize`           | Add Dockerfile + docker-compose. |
| `/add-ci`              | Add CI workflow. |

### Documentation track

| Command                | Purpose                                                                          |
|------------------------|----------------------------------------------------------------------------------|
| `/add-runbook`         | Author an ops runbook (incident response / deploy / rollback / cutover). Standard sections: trigger, prerequisites, verify-after-each-step, rollback, common failures. |
| `/add-adr`             | Author an Architecture Decision Record. |
| `/doc-refresh`         | Refresh stale documentation. |

### Other tracks

Security (`/security-audit`), observability (`/log-tail`, `/add-tracing`, `/add-metrics`, `/add-telemetry`), database (`/add-migration`, `/optimize-query`, `/db-audit`), performance (`/perf-audit`, `/profile-perf`, `/bundle-perf`), infrastructure (`/k8s-generate`, `/audit-iam`, `/cost-audit`), business (`/audit-business`), distributed-systems (`/audit-distributed-tx`).

### `--plan` works on every generated command

Every generated command supports `--plan`. Example:

```
/add-feature checkout --plan
# → writes .claude/plans/add-feature-checkout-<ts>.md
# → exits before any code is written

# Execute it in-place (executor sub-agents run on Sonnet):
/execute-plan .claude/plans/add-feature-checkout-<ts>.md
# → implements Steps + Outputs, honours Constraints, runs Verification, auto-audits via /verify-plan
# ...or hand the plan to a different tool / a human instead, then audit:
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

Reads the codebase against `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md`. Runs 11 universal detectors in parallel waves:
- **Structural** (6): dead-code, duplicated-logic, reinvented-wrapper, silent-catch, over-abstraction, drift.
- **Functional** (5): SOLID violation, clean-code, performance, security (security includes deps-audit as a sub-class), unhandled-io (happy-path-only I/O — call sites with no error path / timeout / failure surfacing; the absent-error-path sibling of silent-catch).
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
2. **DECIDE** — confirm closure verb is in the 21-verb vocabulary; confirm fix is appropriate to row's class.
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
- **Closure-verb vocabulary is closed (21 verbs).** No new abstractions; functional verbs (add-gate, parameterize, etc.) USE existing idioms from `_extracted-idioms.md` — never invent.
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

The plan file is the canonical handoff artifact. Execute it in-place with `/execute-plan` (Claude-native; executor sub-agents default to Sonnet, pairing with an Opus planning pass), or hand it to OpenCode / Cursor / Aider / a human:

```
/execute-plan .claude/plans/add-feature-subscription-billing-<ts>.md
# implements the plan, then auto-runs /verify-plan
```

To audit drift independently (or after a non-Claude tool implemented it):

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
