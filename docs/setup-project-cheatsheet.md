# `/setup-project` — Cheat sheet

Quick reference for the `/setup-project` command. For the full spec see `commands/setup-project.md`.

## What it does

Scaffolds OR enhances a project's AI-tool setup — `.claude/` folder + `ai/` knowledge base + per-tool adapter configs (Cursor, OpenCode, Aider, etc.).

Detects mode automatically:
- **CREATE** — empty folder OR brand-new project (no `.claude/` / `ai/`).
- **ENHANCE-retrofit** — code exists but no `.claude/` / `ai/`.
- **ENHANCE-extend** — `.claude/` + `ai/` already exist (most common for established projects).
- **REFRESH** *(opt-in via `--refresh`)* — backup → extract → wipe → regenerate from latest templates.
- **REFINE** *(opt-in via `--refine`)* — round two: deepen existing artifacts via deep code analysis (no overwrite of user-authored content).

## All flags

| Flag | Purpose | Default |
|---|---|---|
| `--dry-run` | Preview the plan; write nothing | off |
| `--create` | Force CREATE mode | auto |
| `--enhance` | Force ENHANCE mode (additive — adds missing files only, never touches existing) | auto |
| `--refresh` | Force REFRESH mode (backup → extract knowledge → wipe → regenerate from latest templates) | auto |
| `--refine` | Force REFINE mode — round two (deepens existing artifacts via deep code analysis: entities / architecture / flows / emergent conventions / hot paths / failure history). Rewrites only auto-generated `## Project-specific` blocks; user-authored sections preserved verbatim. **Adapter sync (Phase 4.8-DEEP)**: every selected non-claude-code adapter (Cursor / OpenCode / Aider / Continue / Cline / Windsurf / Copilot / Codex / Gemini) is incrementally re-translated from the deepened `.claude/` + `ai/`. Idempotent — three-way plateau verdict (DEEP / WEAK / NOT). Emits `.claude/_setup-quality.md` with per-artifact 0-100 anchor-density scores. | auto |
| `--max-subagents=<N>` | **REFINE-only cost cap.** Bounds the parallel Explore / re-anchor / adapter-sync subagents fanned out by Phases 2.7–2.12 + 4.6-DEEP + 4.8-DEEP. Lower for cost-sensitive runs / very large codebases; raise for time-sensitive runs on small codebases. | 8 (REFINE) |
| `--include-incidents=<path>` | **REFINE-only opt-in** for failure-history extraction. Phase 2.12 reads postmortem/incident docs at `<path>` (e.g. `docs/postmortems/`) in addition to git log. Customer names + dollar amounts + individual blame are sanitized. | off (git log only) |
| `--include-runbooks` | **REFINE-only opt-in** for runbook enrichment. Phase 4.7-DEEP writes `ai/runbooks/<flow>.md` from Phase 2.9 flow narrations. Off by default (runbooks are operational docs the team owns). | off |
| `--plateau-delta=<N>` | **REFINE-only.** Override plateau classifier `plateau_delta` threshold (max artifacts whose anchor density changed by ≥ 5 — below this, run is "plateau"). Lower = stricter; higher = looser. | `2` |
| `--plateau-consumed=<F>` | **REFINE-only.** Override `plateau_consumed` threshold (fraction of available deep-extraction signal actually consumed). Range `0.0–1.0`. Distinguishes PLATEAU-DEEP (≥) from PLATEAU-WEAK (<). | `0.85` |
| `--plateau-score=<N>` | **REFINE-only.** Override `avg_score` threshold for PLATEAU-DEEP. Below this average, classifier emits PLATEAU-WEAK regardless of delta + consumed. | `80` |
| `--minimal` | Focused setup — Phase 4.2 reads `_essentials.md` per track and copies ONLY essentials (~**30%** of full pack surface by default; per-track % varies — see full spec). Best for MVPs, prototypes, learning. Upgrade later via `--enhance` (without `--minimal`). | off |
| `--force-replace-all` | Overwrite every overlapping file | off |
| `--force-keep-all` | Never overwrite; only add new files | off |
| `--include=<signal>` | Force-apply technical signal(s) — comma-separated | off |
| `--tools=<list\|auto>` | Tool adapters to generate | `claude-code` (CREATE) / `auto` (ENHANCE / REFRESH) |
| `--add-tool=<name>` | Add ONE tool adapter without refreshing others | — |
| `--plan` | **Universal** (works on EVERY command, not just `/setup-project`). Runs Phases 1-3 only, writes plan to `.claude/plans/<command>-<slug>-<timestamp>.md`, exits before implementation. Hand off the plan file to OpenCode / Cursor / Aider for execution; come back to Claude with `/verify-plan <file>` to audit drift. | off |

## Tool adapter keys

Use with `--tools=` or `--add-tool=`:

`claude-code` · `opencode` · `cursor` · `aider` · `continue` · `cline` · `windsurf` · `copilot` · `codex` · `gemini`

## Technical signals (for `--include=`)

Values are **folder names under `~/.claude/templates/domains/`** only (technical signals — NOT `business-domains/`).

`ai` · `webhook` · `multi-tenant` · `payment` · `real-time` · `event-sourced` · `file-upload` · `search` · `feature-flags` · `notifications` · `background-jobs` · `compliance`

## Conflict rules

- `--create` + `--enhance` → ❌ refused (user error)
- `--create` + `--refresh` → ❌ refused (refresh requires existing setup)
- `--create` + `--refine` → ❌ refused (refine requires existing artifacts to deepen)
- `--refine` with no existing artifacts → ❌ refused (suggests CREATE first)
- `--refine` + `--force-replace-all` → ❌ refused (incompatible with REFINE's "preserve user-authored sections" contract)
- `--max-subagents=<N>` without `--refine` → ⚠️ ignored (REFINE-only)
- `--max-subagents=<N>` with `N<1` → ❌ refused (use `N=1` for fully-serial)
- `--include-incidents=` / `--include-runbooks` without `--refine` → ❌ refused (REFINE-only opt-ins)
- `--force-replace-all` + `--force-keep-all` → ❌ refused (user error)
- `--enhance` + `--refresh` → REFRESH wins (warns)
- `--enhance` + `--refine` → ✅ runs as 2-phase pipeline (ENHANCE first, then REFINE)
- `--refresh` + `--refine` → REFRESH wins; recommends running `--refine` afterwards if needed
- `--refine` + `--dry-run` → ✅ both apply (dry-run shows per-artifact anchor-density delta + proposed rewrites)
- `--tools=<list>` + `--add-tool=<name>` → ✅ both apply
- `--minimal` + `--enhance` (already-standard project) → expands existing standard, ignores `--minimal` (don't shrink); warn user

## Common invocations

```bash
# 1. Auto-detect (most common — works for 90% of cases)
/setup-project

# 2. Greenfield with prompt
/setup-project "WhatsApp sales agent for Egyptian SMBs, NestJS + Postgres + Claude"

# 3. Preview the plan without writing anything
/setup-project --dry-run

# 4. Existing project — fill in missing pieces without touching your work
/setup-project --enhance

# 5. Existing project + preview what would be added
/setup-project --enhance --dry-run

# 6. Multi-tool: generate Claude Code + Cursor + OpenCode configs together
/setup-project --tools=claude-code,cursor,opencode

# 7. Auto-detect which AI tools you use, generate adapters for each
/setup-project --tools=auto

# 8. Add Cursor adapter to existing setup without refreshing others
/setup-project --add-tool=cursor

# 9. Force CREATE mode (start fresh even if code exists)
/setup-project --create

# 10. Force a technical signal the auto-detector missed
/setup-project --enhance --include=payment

# 11. Force multiple technical signals
/setup-project --enhance --include=payment,multi-tenant,background-jobs

# 12. Safe mode — only add new files, never overwrite anything
/setup-project --enhance --force-keep-all

# 13. Aggressive mode — overwrite all overlapping files with pack versions
/setup-project --enhance --force-replace-all

# 14. Greenfield + multi-tool from the start
/setup-project "AI-powered LMS, Laravel + Vue 3" --tools=claude-code,cursor

# 15. Combination: enhance Laravel project, only Claude Code, add background-jobs signal
/setup-project --enhance --tools=claude-code --include=background-jobs

# 16. Greenfield workspace with multiple sub-projects
/setup-project "SaaS B2B platform with NestJS API + Angular dashboard, Stripe billing"

# 17. Existing workspace — refresh all detected tools, fill missing artifacts
/setup-project --enhance --tools=auto

# 18. Greenfield — just give me Claude Code (skip other tool adapters)
/setup-project "Express + MongoDB blog" --tools=claude-code

# 19. Add OpenCode adapter to existing Cursor + Claude project
/setup-project --add-tool=opencode

# 20. Fix an existing project where /setup-project ran incompletely (missing skills/agents/commands)
/setup-project --enhance --tools=claude-code

# 21. Minimal setup — focused subset (~30% of full pack), best for MVPs / prototypes
/setup-project --minimal

# 22. Minimal greenfield with prompt
/setup-project "Internal admin tool, Laravel + Inertia" --minimal

# 23. Minimal multi-tool
/setup-project --minimal --tools=claude-code,cursor

# 24. Upgrade a minimal setup to standard later
/setup-project --enhance     # adds the rest of the standard pack on top of minimal

# 25. Minimal + selective signals (lean but with payment + multi-tenant tooling)
/setup-project --minimal --include=payment,multi-tenant

# 26. Plan-then-implement handoff (universal — works on EVERY command)
/add-feature "let pharmacists filter prescriptions by status" --plan
# → writes .claude/plans/add-feature-prescription-filter-<timestamp>.md, exits

# 27. Verify drift after another tool implemented from the plan
/verify-plan .claude/plans/add-feature-prescription-filter-20260427-1430.md
# → reports: ✓ matched / ⚠ deviated / ✗ missing.  Verdict: PLAN FULFILLED|DRIFTED|VIOLATED.

# 28. Retrofit --plan onto existing project (commands installed before --plan existed)
/setup-project --refresh    # regenerates commands with --plan support; preserves project knowledge

# 29. Round two — deepen existing setup against the real codebase (after CREATE/ENHANCE)
/setup-project --refine
# → reads code (entities, architecture, flows, conventions, hot paths, failure history),
#   rewrites only auto-generated Project-specific blocks of shallow artifacts,
#   preserves user-authored content verbatim.

# 30. Preview what --refine would change without writing
/setup-project --refine --dry-run
# → shows per-artifact anchor-density delta and proposed rewrites.

# 31. ENHANCE then REFINE in one pipeline (pick up a half-set-up project + go deep)
/setup-project --enhance --refine
# → gap-fills missing files first, then deepens the now-complete set.

# 32. REFINE with opt-in postmortem reading (failure-history extraction)
/setup-project --refine --include-incidents=docs/postmortems/
# → extracts recurring failure themes into ai/failures/<theme>.md;
#   sanitizes customer names / dollar amounts / individual blame.

# 33. REFINE with cost cap on a very large codebase
/setup-project --refine --max-subagents=4
# → caps parallel Explore subagents to 4 (instead of default 8);
#   slower wall-clock, lower API cost — good for 500k+ LOC repos.

# 34. REFINE with opt-in runbook generation
/setup-project --refine --include-runbooks
# → Phase 4.7-DEEP writes ai/runbooks/<flow>.md from Phase 2.9 flow narrations.

# 35. REFINE with multiple adapters — propagate deepening to every selected tool
/setup-project --refine --tools=claude-code,cursor,opencode,aider
# → Phase 4.8-DEEP incrementally re-translates affected outputs to each tool's
#   NATIVE shape: `.cursor/{rules,commands,skills}/`, `.cursor/hooks.json`,
#   `.opencode/{agents,commands,skills}/`, `CONVENTIONS.md`, AGENTS.md
#   named-procedures section. claude-code is auto-current (no-op).
#   Decision log: .claude/_phase-4-8-decisions.md.
```

## Plan-then-implement workflow (one-line summary)

`<command> --plan` writes a tool-agnostic plan file to `.claude/plans/`.  Hand it to OpenCode / Cursor / Aider / a human for execution.  Return with `/verify-plan <file>` to audit drift.  See README § "Plan-then-implement workflow" for the full story including the retrofit caveat.

## Decision tree — which invocation should I use?

```
Is this a new empty folder OR a folder where I want to start fresh?
├─ YES → /setup-project "<your prompt>"
│        (add --tools=auto if you want multi-tool)
│        (add --minimal if you want focused setup)
│
└─ NO (existing codebase)
   │
   Does the project already have .claude/ or ai/?
   ├─ NO → /setup-project --enhance
   │       (enhance-retrofit will detect this and build from your code)
   │
   └─ YES → What's the goal?
            │
            ├─ Add missing files (round 1, gap-fill)
            │  → /setup-project --enhance
            │    (never touches existing files; preview with --dry-run)
            │
            ├─ Deepen existing files (round 2 — feels generic, want concrete)
            │  → /setup-project --refine
            │    (deep code analysis; rewrites only auto-generated
            │     Project-specific blocks; preserves user content verbatim)
            │
            └─ Pack version drift / structural upgrade
               → /setup-project --refresh
                 (backup → extract knowledge → wipe → regenerate)

Want a focused setup (~30% of full pack — essentials manifest)?
└─ Add --minimal
   (good for: MVPs, prototypes, learning, single-purpose tools)
   (NOT good for: production projects that will grow → standard is better)

Want multi-tool support (Cursor, OpenCode, Aider, etc.)?
└─ Add --tools=auto OR --tools=cursor,aider,...

Want to force a technical signal the detector missed?
└─ Add --include=payment,multi-tenant,...

Worried about overwriting your customizations?
└─ Add --force-keep-all  (or use --refine — it never touches user content)

How do I know my setup is anchored deeply enough?
└─ Run /setup-project --health
   • Score < 70/100 avg → run --refine
   • Score 70-84 → anchored; refine optional
   • Score ≥ 85 → DEEP; further refine would plateau
```

## What `--minimal` includes vs full

For each selected track, `--minimal` copies only files listed in the track's `_essentials.md` manifest (roughly **~30%** of the full pack on average — exact counts vary by track; treat the manifest as source of truth).

| Track | Minimal / Standard (illustrative) | ~Reduction vs full |
|---|---|---|
| backend | 11 / 24 | ~54% |
| frontend | 8 / 21 | ~62% |
| database | 7 / 14 | ~50% |
| testing | 6 / 10 | ~40% |
| security | 5 / 9 | ~44% |
| code-quality | 6 / 14 | ~57% |
| documentation | 4 / 9 | ~56% |
| business | 3 / 5 | ~40% |
| devops | 6 / 9 | ~33% |
| performance | 4 / 5 | ~20% |
| observability | 4 / 10 | ~60% |
| distributed-systems | 4 / 13 | ~69% |
| infrastructure | 3 / 7 | ~57% |
| mobile | 2 / 2 | 0% |
| ui-ux | 4 / 11 | ~64% |

**ALWAYS included regardless of `--minimal`** (foundational):
- All 7 baseline hooks
- ENTIRE `learning` track (Phase 6 needs the full set)
- All baseline `ai/` files (status, stack, modules, conventions, business-domain, project-goals, etc.)
- 3 compact derived files (`_session-digest.md`, `_decision-index.md`, `_convention-cheatsheet.md`)
- Business-domain pack for the detected domain
- Selected tool adapter outputs

## Three modes for existing projects (one-line each)

| Mode | What it does | When |
|---|---|---|
| `--enhance` | **Add missing files only** — never touches existing ones. | Half-set-up project; pulling in newly-released packs. |
| `--refresh` | **Backup → extract → wipe → regenerate** all artifacts from latest templates. | Pack version drift; structural upgrade; recover from accumulated drift. |
| `--refine` | **Round two — deepen existing files** via deep code analysis. Rewrites only auto-generated `## Project-specific` blocks; user-authored content preserved verbatim. **Phase 4.8-DEEP propagates the deepening to every selected non-claude-code adapter** (`.cursor/`, `opencode.json`, `CONVENTIONS.md`, `AGENTS.md`, etc.) so Cursor / OpenCode / Aider / etc. all see the same deepened guidance, not just Claude. | After CREATE / ENHANCE when first-pass artifacts feel generic; periodically as the codebase grows. |

Common pipeline: `--create` (round 1) → use the project for a while → `--refine` (round 2: deepen) → later `--refresh` (when packs ship a major upgrade).

## What the flags don't control

These are decided by detection, not flags:

- **Business domain** (ecommerce / lms / fintech / etc.) — auto-detected from entity names + folders + deps. If ambiguous, the command asks ONE consolidated question.
- **Tracks applied** (backend / frontend / database / etc.) — auto-selected based on detected stack.
- **Pack agents/commands/skills copied** — driven by selected tracks. Use `--minimal` for the focused subset, no flag for full.

To skip a track entirely: run `--dry-run`, see the plan, request changes interactively.

## See also

- `commands/setup-project.md` — full command spec (~4900 lines, 7-phase pipeline + 6 round-two deep-extraction phases)
- `templates/packs/` — pack catalog (18 tracks including `align`, `migration`, and `learning`, 41 commands, 51+ agents) + per-track `_essentials.md` manifests
- `templates/packs/learning/skills/` — extraction skills (round-one: `extract-codebase-overview`, `extract-base-class-idiom`; round-two: `extract-domain-entities-deeply`, `extract-architecture-deeply`, `extract-flows-deeply`, `extract-conventions-emerging`, `extract-hotpaths`, `extract-failures-from-history`, `compute-anchor-density`)
- `templates/packs/learning/ai-patterns/setup-quality-scoring.md` — the four-axis anchor-density rubric used by `--refine` Phase 5.5
- `templates/business-domains/` — 15 business domains
- `templates/tool-adapters/` — 10 tool adapters
- `templates/repo-baseline/` — baseline scaffolding (`.claude/` + `ai/`)
- [`docs/TASK-PROVIDERS.md`](TASK-PROVIDERS.md) — set up `/task` (Trello / Jira / Linear / GitHub). Setup's `scripts/detect-mcp.sh --apply` wires the provider MCP per repo, gated on `.env` creds.
