# claude-config

Portable, intelligent Claude Code configuration. One `git clone` on any device = full toolbox.

The entire system has ONE command you actually use:

## `/setup-project` — the brain

Works on **empty projects** AND **existing projects**. One command for everything.

- Empty folder + prompt → full scaffold (architecture + DB schema + phase plan + all tooling).
- Existing codebase → scans it, identifies gaps, proposes enhancements, applies them without overwriting your custom work.
- Fullstack workspace? Monorepo? Single repo? It detects the shape.
- Any stack (NestJS / Django / FastAPI / Laravel / Rails / Go / Elixir / Rust / PHP / .NET / Angular / React / Vue / Nuxt / Next / Svelte / etc.) — role-based packs adapt to whatever's there.

Vibe-coding discipline: **plan first, write once, no placeholders, no filler**. The command produces a plan, shows it, then executes after your approval.

---

## Structure

```
claude-config/
├── commands/
│   └── setup-project.md           # the one command
├── templates/
│   ├── repo-baseline/             # universal — copied into every new repo
│   ├── workspace-baseline/        # for multi-repo workspaces (dispatcher, cross-repo cmds)
│   └── packs/                     # 16 ROLE-based tracks (+ learning, observability, infra, etc.)
│       ├── code-quality/          # code-reviewer, refactorer, dead-code-finder, /review-changes, /simplify
│       ├── documentation/         # doc-writer, /doc-refresh, /add-adr
│       ├── backend/               # api-architect, api-reviewer, endpoint-tester, /add-module, /add-endpoint, /endpoint-test, /log-tail
│       │   └── references/        # nestjs, hexagonal-nestjs, express, fastapi, django, laravel, rails, go
│       ├── frontend/              # ui-architect, ui-reviewer, i18n-auditor, accessibility-auditor, /add-page, /add-component, /add-crud-page, /i18n-audit, /a11y-audit
│       │   └── references/        # angular, react, vue, nuxt, nextjs, svelte
│       ├── database/              # schema-architect, schema-reviewer, query-optimizer, /add-migration, /optimize-query, /db-audit
│       │   └── references/        # postgres, mysql, mongodb
│       ├── testing/               # test-engineer, test-reviewer, /add-test, /flaky-test-hunt
│       ├── security/              # security-auditor, auth-reviewer, /security-audit
│       ├── devops/                # devops-architect, ci-reviewer, /dockerize, /add-ci
│       ├── performance/           # performance-optimizer, /perf-audit
│       ├── ui-ux/                 # ux-reviewer, design-system-guardian, /design-review
│       └── business/              # business-analyst, business-auditor, /analyze-task, /audit-business
├── settings.json                  # your global Claude settings
└── README.md
```

### Why role-based packs, not frameworks

Work is organized by **role** — **17 tracks** under `templates/packs/`: backend, frontend, database, testing, security, devops, performance, UI/UX, business, documentation, code-quality, learning, observability, infrastructure, distributed-systems, mobile, migration. Framework specifics (NestJS vs Django vs Laravel) live as `references/<framework>.md` inside each track.

So one `api-architect` agent works for every backend. One `schema-architect` works for Postgres, MySQL, Mongo. Add a new framework → drop a reference file → same agents adapt.

---

## Install

```bash
# Fresh device:
git clone git@github.com:YOUR_USERNAME/claude-config.git ~/.claude

# Already have ~/.claude:
mv ~/.claude ~/.claude.backup
git clone git@github.com:YOUR_USERNAME/claude-config.git ~/.claude
# restore anything personal from .backup/
```

Verify: open Claude anywhere, type `/set` — `setup-project` should appear.

---

## Using `/setup-project`

### New project (empty folder)

```bash
mkdir ~/my-new-saas && cd ~/my-new-saas
claude
```

```
/setup-project "Multi-tenant SaaS: NestJS API + Angular admin + Nuxt storefront. AI via Claude. WhatsApp integration. Multi-tenant. Phase 1 MVP."
```

What you get:
1. A **plan** showing mode, shape, tracks to apply, domain tooling, files to create — you approve or adjust.
2. Workspace parent with dispatcher + `PROJECTS.md` + cross-repo `ai/architecture.md`.
3. `api/` with `code-quality + documentation + backend(nestjs) + database(postgres) + security + testing + business + performance + devops` tracks applied.
4. `admin/` with `code-quality + documentation + frontend(angular) + ui-ux + testing + security` tracks.
5. `storefront/` with `code-quality + documentation + frontend(nuxt) + ui-ux + testing + security + performance`.
6. **Domain tooling auto-generated** based on prompt signals:
   - AI → `/prompt-eval`, `/token-audit`, `prompt-reviewer` agent
   - WhatsApp → `/simulate-webhook`, `webhook-signature-verifier` rule
   - Multi-tenant → `/tenant-leak-audit`, `tenant-isolation-reviewer`
7. Full `ai/` per repo: architecture, DB schema, modules, Phase-1 plan, ADRs, patterns.

### Existing project (retrofit / enhance)

```bash
cd ~/some-existing-codebase
claude
```

```
/setup-project
```

What happens:
1. **Scans** everything — `package.json`, `CLAUDE.md` (if any), existing `.claude/`, existing `ai/`, recent git log, folder structure.
2. **Gap analysis** — what tracks are missing, what framework references are missing, what domain tooling the code would benefit from, whether docs are stale or drifted from code.
3. **Plan** — lists every proposed action: "add X (new)", "update Y (needs refresh)", "leave Z (custom, keep)". You approve.
4. **Applies only approved changes**. Existing files are never overwritten without explicit confirmation.
5. **Prepends** a dated `Recent Changes` entry to `ai/status.md`.
6. **Reports** what was added / updated / left alone.

### Any stack works

```
/setup-project "Laravel + Vue + MariaDB e-commerce with Stripe checkout"
/setup-project "Django + React + Postgres, GDPR-compliant CRM"
/setup-project "Go CLI that syncs DNS records — no DB"
/setup-project "Python FastAPI + Next.js dashboard + MongoDB, Firebase auth"
/setup-project "PHP Laravel with Inertia + Vue, Stripe, file uploads"
```

Unknown framework? `/setup-project` generates a reference on the fly, saves it to `~/.claude/templates/packs/<track>/references/<framework>.md`, and every future project reuses it.

### Flags

All optional. Full reference (with conflict rules) lives in `commands/setup-project.md`.

**Mode overrides** (auto-detected by default):

```
/setup-project --create             # force CREATE mode (refuse to touch existing setup)
/setup-project --enhance            # force ENHANCE mode (additive gap-fill — NEW files only)
/setup-project --refresh            # backup + extract knowledge + regenerate fresh
/setup-project --refine             # round two: deepen EXISTING files via deep code analysis
```

**Three-mode mental model:**

| Mode | What it does | When |
|---|---|---|
| `--enhance` | **Add missing files only** — never touches existing ones | First-pass on a half-set-up project; pulling in newly-released packs |
| `--refresh` | **Backup → extract knowledge → wipe → regenerate** all artifacts from latest templates | Pack version drift; structural upgrade; recover from accumulated drift |
| `--refine` | **Round two — deepen existing artifacts** via deep code analysis (entities / architecture / flows / emergent conventions / hot paths / failure history). Rewrites only the auto-generated `## Project-specific` blocks; preserves user-authored sections verbatim | After CREATE / ENHANCE when first-pass artifacts feel generic; whenever the codebase has grown enough that round-one anchors are now shallow |

The flags are complementary, not redundant. Common pipeline: `--create` (round 1) → use the project for a while → `--refine` (round 2: deepen) → later `--refresh` (when packs ship a major upgrade).

**Read-only previews** (write nothing):

```
/setup-project --dry-run            # show the plan
/setup-project --diff               # show pack version drift (recorded → current)
/setup-project --health             # compute setup health score + emit telemetry
/setup-project --validate-schemas   # validate generated JSON configs against schemas
```

**Scope / content**:

```
/setup-project --minimal                  # essentials-only (~30% of full pack); upgrade later via --enhance
/setup-project --include=multi-tenant     # force-apply a technical-signal pack (comma-separated)
/setup-project --tools=cursor,aider       # generate adapters for specific tools
/setup-project --tools=auto               # auto-detect installed tools
/setup-project --add-tool=opencode        # ENHANCE-only: add ONE adapter on top of existing
```

**Refresh safety**:

```
/setup-project --refresh --no-backup              # skip Phase 0 backup (DANGEROUS — refuse without explicit confirm)
/setup-project --refresh --backup-dir=<path>      # override default .claude/backups/<YYYYMMDD-HHmm>/
```

**Merge policy** (override Appendix C matrix):

```
/setup-project --force-replace-all   # overwrite every overlap with pack version
/setup-project --force-keep-all      # never overwrite existing files
```

**Refine tuning** (REFINE-only — override the plateau classifier defaults):

```
/setup-project --refine --plateau-delta=1     # stricter: declare plateau only when ≤ 1 artifact moved (default 2)
/setup-project --refine --plateau-consumed=0.9 # require 90% of deep-extraction signal consumed (default 0.85)
/setup-project --refine --plateau-score=85    # require avg score ≥ 85 for PLATEAU-DEEP (default 80)
```

Defaults are theoretical (calibrated against synthetic fixtures). Tune as you accumulate REFINE telemetry from `.claude/_setup-quality.md` history.

**UX**:

```
/setup-project --wizard              # interactive Q&A instead of one consolidated question block
/setup-project --lang=ar             # Arabic prompts + bilingual CLAUDE.md/AGENTS.md headers (also: en, auto)
/setup-project --no-telemetry        # disable local-only telemetry append
```

**Workflow handoff** (universal — applies to EVERY generated command, not just /setup-project):

```
/<command> "..." --plan              # plan only; writes .claude/plans/<file>.md; exits before implementation
/verify-plan <plan-file>             # audits implementation against plan; reports drift
```

See "Plan-then-implement workflow" section below for the full handoff story.

**Common conflicts** (refuses with error):

- `--create` + `--enhance` · `--create` + `--refresh` · `--create` + `--refine` · `--force-replace-all` + `--force-keep-all` · `--no-backup` without `--refresh`
- `--enhance` + `--refresh` → REFRESH wins (warns)
- `--enhance` + `--refine` → runs as 2-phase pipeline: ENHANCE first (gap-fill) → REFINE (deepen)
- `--refresh` + `--refine` → REFRESH wins; recommends running `--refine` afterwards if needed
- `--refine` with no `.claude/` artifacts present → user error; suggests `/setup-project` (CREATE) first
- `--refine` + `--force-replace-all` → refused (incompatible with REFINE's "preserve user-authored sections" contract)
- `--diff` / `--health` + any write flag → read-only wins (warns)

---

## Plan-then-implement workflow (universal handoff)

Use Claude Code to **PLAN**, any other tool (OpenCode, Cursor, Aider, a human) to **IMPLEMENT**, then Claude to **VERIFY**. The split is "expensive thinking once, cheap mechanical execution + drift-checked verification."

### `--plan` is universal

Every command in the system supports `--plan` — not just `/setup-project`:

```
/add-feature "let pharmacists filter prescriptions by status" --plan
/fix-bug 42 --plan
/add-module billing --plan
/refactor src/auth/* --plan
```

What it does: runs Phases 1-3 (Understand / Organize / Retrieve), expands the plan with full detail, writes a structured plan file to `.claude/plans/<command>-<slug>-<YYYYMMDD-HHmm>.md`, exits BEFORE Phase 4 (Generate). The plan file is the handoff artifact.

### The plan file format

Tool-agnostic markdown with these sections: **Context**, **Inputs** (files to read), **Outputs** (files to create / modify / delete), **Steps**, **Constraints** (DO NOT rules), **Verification** (lint/test/curl commands), **Known unknowns**, **Status** checkboxes. Every plan has a Plan ID (short hash) for cross-referencing.

Full spec: `commands/setup-project.md` § "Phase 3.5 — Handoff" + `templates/repo-baseline/.claude/plans/README.md`.

### Hand off to any tool

```bash
$ claude
> /add-feature "..." --plan
# writes .claude/plans/add-feature-...-20260427-1430.md, prints Plan ID, exits

$ opencode
> /add-feature --from-plan .claude/plans/add-feature-...-20260427-1430.md
# OpenCode reads plan, implements per Outputs + Steps, respects Constraints
```

Or paste the plan file content into Cursor / Aider / any tool's prompt as input. Plan file is markdown — universally readable. No native `--from-plan` required for the basic workflow.

### Verify drift after implementation

```bash
$ claude
> /verify-plan .claude/plans/add-feature-...-20260427-1430.md
# Diffs filesystem vs plan: ✓ matched / ⚠ deviated / ✗ missing.
# Verdict: PLAN FULFILLED | PLAN DRIFTED | PLAN VIOLATED.
```

`/verify-plan` ships in `repo-baseline/.claude/commands/` — every new project (or `--enhance` / `--refresh` upgrade) gets it automatically.

`.claude/plans/` is gitignored by default within projects (plans are per-engineer working artifacts). Teams can flip the gitignore to commit plans as PR-attached design docs — that's a project decision.

### Retrofitting existing projects

Projects scaffolded BEFORE the `--plan` machinery was added won't have it on their installed commands.

**Symptoms**: `<command> --plan` runs but the command implements anyway, ignoring the flag — the on-disk command file has no Phase 3.5 logic.

**Two retrofit paths**:

| Path | When to use | What it does |
|---|---|---|
| `/setup-project --refresh` | >2 commands or any team rollout | Regenerates commands with `--plan` support. Phase 0 backup + Phase 0.2 knowledge extract preserve project-specific edits. Non-destructive by design. |
| Manual per-command edit | 1-2 commands, surgical fix | Copy `## Phase 3.5 — Handoff` block from `commands/setup-project.md` into the command file. Add `--plan` to its documented flags. |

**`/verify-plan` standalone install** (no full refresh): `cp ~/.claude/templates/repo-baseline/.claude/commands/verify-plan.md <project>/.claude/commands/`.

**`.claude/plans/` directory standalone**: `mkdir -p <project>/.claude/plans && cp ~/.claude/templates/repo-baseline/.claude/plans/README.md <project>/.claude/plans/` + add `.claude/plans/*.md` (with `!.claude/plans/README.md` exception) to the project's `.gitignore`.

### When NOT to use `--plan`

- Trivial changes (one-line fixes, typos) — overhead exceeds benefit.
- Spike / exploration where the plan would change as you go.
- Read-only commands (no implementation to plan for) — they exit at Phase 3 anyway.

The flag is FOR non-trivial, decomposable, verifiable work. Use judgment.

---

## Round-two deepening (`--refine`)

Round one (`/setup-project` / `--enhance`) gets the floor right: every load-bearing track has its minimum artifacts present, anchored to the project's surface signals (file paths, base classes, suffix matrix, stack identifiers). Sufficient for "the setup exists" — but the auto-generated `## Project-specific` blocks may still read as generic ("the project's billing service") instead of concrete ("`app/services/billing.py:BillingService.create_invoice` line 128").

Round two (`--refine`) closes that gap.

### What `--refine` does

After your initial setup is in place, run `/setup-project --refine`. The command performs **6 deep-extraction phases** (Phases 2.7–2.12 in the spec):

| Phase | Reads | Produces |
|---|---|---|
| 2.7 — Domain entities | ORM/model classes, migrations, repositories, integration tests | Real entity list with fields + relationships + invariants + lifecycle events with `file:line` citations |
| 2.8 — Architecture | Import graph, request lifecycles, bounded-context boundaries | ASCII layer diagram + 3-5 traced lifecycles + cross-cutting concerns located |
| 2.9 — End-to-end flows | ≥3 business + ≥2 admin flows | Step-by-step narration per flow with side effects + error paths + idempotency mechanism |
| 2.10 — Emergent conventions | 8 categories sweeping for 5+ recurrences | Error shape, pagination shape, validation pattern, logging shape, transaction boundaries, async-work naming, time/money/ID handling |
| 2.11 — Performance hot paths | Hotness-scored endpoints (monitoring + git churn + fan-in + coverage) | Top-10 hot paths with N+1 risk + missing indexes + cache layer status + 1-line uplift recommendation |
| 2.12 — Failure history | git log + (opt-in) `docs/postmortems/` | Recurring failure themes for `ai/failures/<theme>.md` (auto-injected in architectural agents' pre-flight) |

Then **Phase 4.6-DEEP** re-anchors the `## Project-specific` blocks of every artifact scoring < 70/100 — using the deep-extraction substrate. **Phase 4.7-DEEP** enriches `ai/architecture.md`, `ai/business-domain.md`, `ai/conventions.md` with the round-two findings. **Phase 4.8-DEEP** propagates those deepenings into every selected non-claude-code adapter (Cursor / OpenCode / Aider / Continue / Cline / Windsurf / Copilot / Codex / Gemini) — incrementally, only re-translating outputs whose source artifact actually changed. **Phase 5** verifies per-adapter coverage. **Phase 5.5** emits `.claude/_setup-quality.md` showing per-artifact 0-100 scores on 4 axes (name density / path density / signal density / specificity) plus plateau detection.

### Adapter sync (Phase 4.8-DEEP)

REFINE deepens the `.claude/` source-of-truth artifacts. The `claude-code` adapter is auto-current (it reads `.claude/` directly). **Every other selected adapter embeds translations into its native shape** — `.cursor/{rules,commands,skills,hooks.json}` (Cursor 2.3+); `.opencode/{agents,commands,skills}/`; `.github/{prompts,agents,skills}/`; `.clinerules/workflows/`; `.windsurf/workflows/`; `.continue/prompts/`; `AGENTS.md` § "Named procedures"; `CONVENTIONS.md`; etc. Without Phase 4.8-DEEP, REFINE produces the failure mode "Claude got smarter, Cursor still talks generic prose."

Phase 4.8-DEEP closes the gap **incrementally and cost-bounded**:

- Reads the affected-artifact list from `_phase-4-6-decisions.md` REFINE section + `_phase-4-7-decisions.md` REFINE section (rows with action `ANCHOR-DEEP` / `NEW-FILE` / markered-rewrite).
- For each selected adapter, re-translates only the per-artifact outputs whose source is in the affected list.
- Regenerates "index" outputs (`AGENTS.md` § "Invokable commands", `.continue/config.yaml` `rules:` block, `.cursor/rules/00-project.mdc` cross-refs, optional `opencode.json` legacy mirror, etc.) only when the affected list contains a `NEW-FILE` row.
- Skips entirely (`SKIPPED-NO-CHANGES`) when the affected list maps to nothing for an adapter (e.g. `gemini` thin-pointer always; `claude-code` always).
- Respects `--max-subagents=<N>`; per-(adapter × artifact) work fans out under the same cap.
- Same marker safety contract as 4.6-DEEP / 4.7-DEEP — adapter outputs with user-customizable sections use `<!-- generated:start/end -->` markers; pre/post hash check; mismatch → rollback.
- Decision log written to `.claude/_phase-4-8-decisions.md`.

### Safety guarantees

1. **User-authored sections preserved verbatim.** REFINE only rewrites between markers — `<!-- project-specific:start/end -->` for `.claude/{rules,commands,agents,skills}/*.md`, `<!-- refine-enriched:start/end -->` for `ai/*.md`, and `<!-- generated:start/end -->` for adapter outputs that have user-customizable sections (4.8-DEEP). Pre/post SHA-256 hash comparison of bytes-outside-markers in all three cases; mismatch → rollback. User content is bit-identical pre/post run across `.claude/`, `ai/`, AND adapter directories.
2. **Idempotent.** Repeated `--refine` runs converge. The plateau report distinguishes **PLATEAU-DEEP** (everything is anchored ≥ 85, nothing left to deepen) from **PLATEAU-WEAK** (extraction was weak so we can't go further; you may need to grow git history, opt into postmortems, etc.) — see "Plateau diagnosis" below. On a fully-idempotent rerun, Phase 4.8-DEEP records `SKIPPED-NO-CHANGES` (affected list empty).
3. **WEAK extraction = no rewrite.** If a deep-extraction phase doesn't yield enough signal (e.g. too few git commits for failure-history), the round-one anchor stays intact. No shallow-rewrite risk. Adapter outputs whose source didn't change are also untouched.
4. **Failure-history is opt-in.** Postmortem docs read only when you pass `--include-incidents=<path>`. Customer names, dollar amounts, and individual blame are sanitized.
5. **Compatible with `--dry-run`.** Preview the per-artifact anchor-density delta, proposed rewrites, AND per-adapter sync plan without writing.
6. **Cost-capped.** `--max-subagents=<N>` (default `8`) bounds parallel Explore + re-anchor + adapter-sync subagents across all REFINE phases. Lower the cap for large codebases; raise it for small ones where speed matters more than cost.
7. **Adapter coverage gates the run.** Phase 5 verifies per-adapter completeness contracts after 4.8-DEEP — every command listed, every rule translated, every agent persona present. Shortfalls trigger the standard retry loop. So `--refine` is "Claude got smarter AND every other tool got smarter too."

### Common pipeline

```bash
# Round 1 — initial setup or gap-fill
/setup-project --enhance

# (work in the project for a while; codebase grows; conventions emerge)

# Round 2 — deepen the auto-generated blocks against the real code
/setup-project --refine

# Quick visibility into where you stand
/setup-project --health     # any time — shows anchor-density score per artifact

# Pack version upgrade later (not the same as deepening)
/setup-project --refresh
```

### When to run `--refine`

- After `--create` / `--enhance-retrofit` on a substantial codebase, when the round-one artifacts feel generic.
- After significant code growth (new modules, new entities, new flows) that round-one detection couldn't have seen.
- Periodically (monthly / quarterly) on a maturing project — the more code there is, the more deep extraction has to surface.

### When NOT to run `--refine`

- Greenfield project with < 1 week of code (round-one detection is already as deep as the substrate allows).
- Right after `--refresh` (refresh just regenerated everything from latest templates; let it settle first).
- When `--health` reports avg score ≥ 85 (you're already in the DEEP band; further `--refine` would plateau immediately).

### Output files

REFINE writes (in addition to whatever Phase 4 normally writes):

- `.claude/_refine-extract.md` — the 6-phase deep extraction substrate.
- `.claude/_setup-quality.md` — per-artifact anchor-density report with round-1 vs round-2 deltas, plus a **three-way plateau verdict** (`PLATEAU-DEEP` / `PLATEAU-WEAK` / `NOT-PLATEAU`).
- `.claude/_phase-4-6-decisions.md` — appended with `## REFINE — round two (<timestamp>)` section per run.
- `.claude/_phase-4-7-decisions.md` — `ai/*.md` enrichment decisions (per-file ANCHOR-DEEP / LEAVE-DEEP / MARKERS-INJECTED / ROLLBACK-MARKER-DRIFT).
- `.claude/_phase-4-8-decisions.md` — adapter-sync decisions (per `(adapter, output-file)` tuple — RE-TRANSLATED / INDEX-REFRESHED / SKIPPED-NO-CHANGES / NO-OP-ADAPTER / NEEDS-FULL-PHASE-4.8 / ROLLBACK-MARKER-DRIFT).
- `ai/failures/<theme>.md` — one file per recurring failure theme (only if Phase 2.12 was STRONG).
- Updated `.cursor/rules/`, `opencode.json`, `CONVENTIONS.md`, `.continue/`, `.clinerules/`, `.windsurf/rules/`, `.github/instructions/`, `.github/prompts/`, `AGENTS.md`, `GEMINI.md` — the per-adapter outputs that Phase 4.8-DEEP re-translated to match the deepened `.claude/` and `ai/`.

### Plateau diagnosis

`--refine` always emits a verdict — never a bare "plateau reached":

| Verdict | What it means | Next step |
|---|---|---|
| **PLATEAU-DEEP** | Avg score ≥ 80 AND ≥ 85% of available signal consumed. Setup is anchored; further `--refine` adds nothing. | Stop running `--refine` until significant new code lands. |
| **PLATEAU-WEAK** | Δ score ≤ 2 BUT extraction was thin (some Phase 2.7–2.12 phase produced WEAK output, OR avg score < 80). Setup is NOT yet deeply anchored — but no further refinement is possible from current substrate. | Grow upstream signal (more code, more git history, opt into `--include-incidents=<path>`, etc.), THEN re-run `--refine`. |
| **NOT-PLATEAU** | Δ score > 2 (or first run, no baseline). REFINE is still climbing. | Run `--refine` again if avg score < 70. |

A WEAK plateau verdict enumerates every WEAK phase + its recommended user action. Exit code is `2` for `PLATEAU-WEAK` (signals "user action required upstream" — distinct from healthy `0` and hard-error `1`).

Full spec: `commands/setup-project.md` § "Phase 2.7-2.12", "Phase 4.6-DEEP", "Phase 4.7-DEEP", "Phase 4.8-DEEP", "Phase 5.5".

---

## The track mix logic

Always applied:
- `code-quality` · `documentation` · `security` · `business` · `testing` (rules)

Conditional:
- `backend` → if backend code / API mentioned
- `frontend` + `ui-ux` → if frontend code / UI mentioned
- `database` → if DB code / schema mentioned
- `devops` → if deploy / Docker / CI mentioned, or Phase 2+
- `performance` → rules always; agents on demand or if scale target mentioned

Framework references copied automatically from the pack into the project's `.claude/references/`.

---

## Domain tooling auto-generated

Based on prompt signals, `/setup-project` creates tools the project will actually use:

| Signal | Generates |
|---|---|
| AI / LLM | `/prompt-eval`, `/token-audit`, `prompt-reviewer` |
| Webhooks (Stripe / WhatsApp / GitHub) | `/simulate-webhook`, `webhook-signature-verifier` |
| Payment / billing | `/replay-charge`, `payment-idempotency-reviewer` |
| Multi-tenant | `/tenant-leak-audit`, `tenant-isolation-reviewer` |
| Real-time / websockets | `/ws-trace`, `ws-contract-reviewer` |
| E-commerce | `/seed-catalog`, `checkout-flow-reviewer` |
| Event-sourced | `/replay-events`, `event-schema-reviewer` |
| File uploads | `/file-security-audit` |
| Search-heavy | `/reindex`, `search-relevance-reviewer` |
| Feature flags | `/flag-cleanup-scan` |
| Notifications | `/notification-preview` |
| Background jobs | `/job-trace`, `job-idempotency-reviewer` |
| Compliance (GDPR / HIPAA / SOC2) | `/compliance-audit`, `data-retention-reviewer` |

Rule: every strong signal gets at least one tool. No speculative tooling for signals that aren't present.

---

## Syncing across devices

```bash
# Push:
cd ~/.claude && git add . && git commit -m "describe change" && git push

# Pull on another device:
cd ~/.claude && git pull
```

---

## What's NOT synced

Machine state (gitignored): `projects/`, `todos/`, `tasks/`, `sessions/`, `shell-snapshots/`, `statsig/`, `telemetry/`, `cache/`, `debug/`, `downloads/`, `backups/`, `plans/`, `history.jsonl`, `settings.local.json`, `plugins/`.

---

## First push to GitHub

1. Create a **private** `claude-config` repo (empty — no README, no .gitignore).
2. From this directory:

```bash
git init
git add .
git commit -m "initial claude config — /setup-project + 17 tracks + workspace template"
git branch -M main
git remote add origin git@github.com:YOUR_USERNAME/claude-config.git
git push -u origin main
```

---

## Extending

- New agent → drop into matching track's `agents/`. Synced to every device + every future project.
- New track → `packs/<name>/{agents,commands,rules,references}/` + update `setup-project.md` track mix logic.
- New framework reference → `packs/<track>/references/<framework>.md`. Agents read it automatically.
- New rule → `packs/<track>/rules/<rule>.md`. Auto-loaded in every new project that uses that track.

Existing projects don't auto-upgrade (intentional — prevents surprise behavior changes). Run `/setup-project` in enhance mode to pull in new stuff.

---

## Verification scripts

The repo ships with a smoke-test pipeline that verifies the spec stays internally consistent and matches the adapter contracts. Run all of them before committing changes that touch `commands/setup-project.md`, the adapter docs, or the apply-pack-adaptation skill:

```bash
scripts/dry-run-setup.sh             # runs everything below in sequence (no network)
scripts/lint-tool-parity.sh          # tool-parity matrix ⇄ adapter docs ⇄ contract row symmetry
scripts/test-refine-fixture.sh       # marker safety + REFINE artifact presence (synthetic fixture)
scripts/test-adapter-fixtures.sh     # per-adapter contract ⇄ adapter doc symmetry (kind-by-kind)
scripts/test-migration-paths.sh      # legacy → native shape regression (Cursor 2.3 / Cline / etc.)
scripts/lint-decision-logs.sh        # Phase 4.6/4.7/4.8 tokens + hooks.json events documented
```

Network-dependent (run as a maintenance task — NOT in the smoke pipeline):

```bash
scripts/check-tool-versions.sh                  # informational drift report against vendor docs
scripts/check-tool-versions.sh --strict         # exit 1 on any drift (use in scheduled CI only)
scripts/check-tool-versions.sh --update         # refresh recorded hashes after manual review
scripts/check-tool-versions.sh --adapter=cursor # restrict to one adapter
```

Every adapter's `_version.json` records `docs_urls` + `last_verified` + `last_verified_hashes`. The watcher hashes the meaningful body of each upstream doc (timestamps + CDN noise scrubbed), compares to the recorded hash, and flags drift so a human can re-verify the adapter doc against the upstream tool's current docs.

## Troubleshooting

**Command not found** → repo isn't at `~/.claude/`. `ls ~/.claude/commands/` should list `setup-project.md`.

**Hooks not running** → `chmod +x ~/.claude/templates/repo-baseline/.claude/hooks/*.sh ~/.claude/templates/workspace-baseline/.claude/hooks/*.sh`.

**Want to undo a scaffold** → delete `.claude/`, `ai/`, `CLAUDE.md` in the target folder. Everything else is yours.

**Want to see the plan without writing** → `/setup-project --dry-run`.

---

## License

Personal config. Use however you want.
