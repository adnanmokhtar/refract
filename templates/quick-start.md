---
artifact: quick-start
purpose: Cheat sheet + flag reference + end states for users of /setup-project.
imported-by: commands/setup-project.md (orchestrator) — visible near the top so users see flags before phase detail.
---

## 🗺 Setup at a glance (cheat sheet)

```
  WHEN: greenfield project          WHEN: existing codebase            WHEN: existing setup is stale / pre-dates this command
        ↓                                  ↓                                  ↓
  /setup-project "<prompt>"         /setup-project [--tools=auto]      /setup-project --refresh
        ↓                                  ↓                                  ↓
        │                                  │                            Phase 0 (NEW): backup + extract prior knowledge
        │                                  │                                  ↓
  Phase 1: detect mode → CREATE     Phase 1: detect mode → ENHANCE-*   Phase 1: detect mode → REFRESH (forced)
        ↓                                  ↓                                  ↓
  Phase 2: profile from prompt     Phase 2: profile real codebase     Phase 2: profile codebase + MERGE prior knowledge
        ↓                                  ↓                                  ↓
  Phase 3: plan + delta vs prompt  (same)                              (same — but plan annotates "from prior" vs "from code")
        ↓                                  ↓                                  ↓
  Phase 4: apply (8 sub-steps)     (same)                              (same — generators consume Phase 0 knowledge-extract)
   4.1 baseline + workspace cascade
   4.2 packs (rules/agents/skills/commands/patterns)
   4.3 framework refs
   4.4 technical-signal tooling   ← multi-tenant, webhook, payment, AI, etc.
   4.4b business-domain content   ← ecommerce, lms, fintech, etc.
   4.5 generate missing
   4.6 adapt to detected conventions
   4.7 knowledge base (CLAUDE.md, ai/*)
   4.7b project-context files (goals, personas, model, competitive, roadmap)
   4.8 tool adapters (per scope)
        ↓                                  ↓                                  ↓
  Phase 5: verify + self-audit + report                                Phase 5: + diff backup vs new + report knowledge preserved/dropped
        ↓                                  ↓                                  ↓
  Phase 6: continuous learning loop runs forever
   - hooks (post-commit-learn, post-merge-learn, session-start)
   - commands (/refresh-knowledge, /detect-drift, /promote-pattern, /learn-from-task)
   - agents (knowledge-curator, convention-drift-detector, pattern-emergence-watcher)
   - persistence pyramid (raw observations graduate to formal knowledge)
```

**Result**: a knowledge layer that lives + evolves with the project, not a one-shot scaffold.

---

## 🚀 Quick start (TL;DR)

```
/setup-project                       # auto-detect (most common)
/setup-project "<prompt>"            # with intent / new feature
/setup-project --dry-run             # preview plan without writing
/setup-project --tools=cursor,aider  # add/refresh specific tool adapters
/setup-project --tools=auto          # auto-detect tools + add adapters for each
/setup-project --refresh             # backup existing setup, read it as input, regenerate fresh
/setup-project --refresh --dry-run   # preview the refresh: see backup target + extracted knowledge + plan
/setup-project --diff                # show pack version drift: what changed between recorded versions and current ~/.claude/templates
/setup-project --health              # compute setup health score + emit telemetry; no writes
/setup-project --validate-schemas    # validate generated JSON configs (settings.json, opencode.json, .cursor/rules) against schemas
/setup-project --wizard              # interactive Q&A mode (good for new team members or unfamiliar stacks)
/setup-project --lang=ar             # force Arabic prompts + bilingual headers in generated CLAUDE.md/AGENTS.md
```

**Flags** (all optional):

| Flag | Meaning | Default |
|---|---|---|
| `--dry-run` | Preview the plan; write nothing. | off |
| `--create` | Force CREATE mode (override Phase 1 detection). | auto-detected |
| `--enhance` | Force ENHANCE mode (over CREATE auto-detection). | auto-detected |
| `--refresh` | Force REFRESH mode: snapshot existing `.claude/` + `ai/` to backup dir, extract prior knowledge from every existing setup file, then regenerate fresh content using extracted knowledge as input context. Use when existing setup pre-dates this command, has accumulated drift, or needs structural upgrade WITHOUT losing accumulated insights. | auto-detected |
| `--refine` | Force REFINE mode (round two): runs AFTER an initial setup is in place. Performs deep code analysis (Phases 2.7–2.12 — domain entities, architecture, end-to-end flows, convention emergence, perf hot paths, failure history) and re-runs Phase 4.6 STUDY-DECIDE-ACT with the deeper extraction. Rewrites ONLY the `## Project-specific` blocks of generated artifacts; preserves user-authored sections verbatim. **Adapter sync (Phase 4.8-DEEP)**: every selected non-claude-code adapter (Cursor / OpenCode / Aider / Continue / Cline / Windsurf / Copilot / Codex / Gemini) is incrementally re-translated from the deepened `.claude/` + `ai/` — so deepening Claude's view automatically deepens what every other tool sees. Adds new artifacts only when deep extraction surfaces a genuine need. Reports a setup-quality score in `.claude/_setup-quality.md`. Idempotent — repeated runs converge; reports "plateau reached" when no further refinement is available. Use after CREATE / ENHANCE-retrofit when first-pass artifacts feel generic / shallow. | auto-detected |
| `--max-subagents=<N>` | **REFINE-only cost cap.** Bounds the number of parallel Explore / re-anchor / adapter-sync subagents that Phases 2.7–2.12 + 4.6-DEEP + 4.8-DEEP fan out. Important on very large codebases where unbounded fan-out is expensive (each deep-extraction phase can spawn one subagent per domain / per flow / per hot-path candidate; 4.8-DEEP can spawn one per (adapter × affected-artifact)). The cap is shared across phases — within a phase, fan-out stops at `N` and remaining work serializes. | 8 (REFINE); ignored in CREATE/ENHANCE/REFRESH |
| `--include-incidents=<path>` | **REFINE-only opt-in for failure-history extraction.** Path to a directory containing postmortem / incident docs (e.g. `docs/postmortems/`). Phase 2.12 reads these in addition to git log; without this flag, Phase 2.12 stays inside the repo + git log only. Customer names, dollar amounts, and individual blame are sanitized before content lands in `_refine-extract.md` or `ai/failures/<theme>.md`. | off (git log only) |
| `--include-runbooks` | **REFINE-only opt-in for runbook enrichment.** Allows Phase 4.7-DEEP to write under `ai/runbooks/<flow>.md` from the Phase 2.9 flow narrations. Off by default because runbooks are operational docs the team owns. | off |
| `--plateau-delta=<N>` | **REFINE-only.** Override the plateau-classifier `plateau_delta` threshold (max number of artifacts whose anchor density changed by ≥ 5 between the previous REFINE run and this one — below this, the run is "plateau"). Lower = stricter (more runs declared "still climbing"); higher = looser (declare plateau sooner). Defaults are theoretical (calibrated against synthetic fixtures); tune up/down as you collect real-world REFINE telemetry from `.claude/_setup-quality.md` history. | `2` |
| `--plateau-consumed=<F>` | **REFINE-only.** Override the `plateau_consumed` threshold (fraction of available deep-extraction signal actually consumed — `STRONG_phases / TOTAL_deep_phases`). Range `0.0–1.0`. Used to distinguish PLATEAU-DEEP (≥ threshold = "anchored, no more signal") from PLATEAU-WEAK (< threshold = "no more signal, but not anchored — grow upstream"). | `0.85` |
| `--plateau-score=<N>` | **REFINE-only.** Override the `avg_score` threshold for PLATEAU-DEEP. Below this average, even with low delta + high consumed, the classifier emits PLATEAU-WEAK so the user knows the setup is shallow despite running out of signal. Range `0–100`. | `80` |
| `--force-replace-all` | Bypass Appendix C merge matrix; overwrite every overlap with pack version. | off |
| `--force-keep-all` | Bypass Appendix C; never overwrite existing files. | off |
| `--include=<key>[,<key>...]` | Force-apply a **track** OR **technical-signal** pack even if not detected (e.g., `--include=migration,frontend` or `--include=multi-tenant,webhook`). Comma-separated for multiple. Valid values: every key in `~/.claude/templates/packs/_registry.md` (tracks: backend, frontend, database, migration, …) AND every key in `~/.claude/templates/domains/_registry.md` (signals: webhook, payment, multi-tenant, …). Both registries are the same lists Phase 2 detection consults — so this stays in sync without spec edits. NOT `business-domains/` — business domains use prompt detection + Phase 4.4b, not `--include`. Including a key auto-detection would have caught anyway is harmless (`--include` is additive, never subtractive — see setup-project.md § "Flag composition"). | off |
| `--tools=<list\|auto>` | Tool adapters to generate. List = comma-separated keys (e.g. `--tools=claude-code,cursor,aider`). `auto` = run detection heuristics. | `claude-code` (CREATE) / `auto` (ENHANCE/REFRESH) |
| `--add-tool=<name>` | Add ONE tool adapter on top of existing selections (ENHANCE-only; doesn't refresh others). | — |
| `--minimal` | Focused setup. Phase 4.2 reads `_essentials.md` per track and copies ONLY listed essentials (~30% of full pack). Same Phase 2.6 (profile-informed coverage check) uses essentials count as the minimum, still scoped to load-bearing tracks only. Best for MVPs, prototypes, learning. Upgrade later via `--enhance` (without `--minimal`) to add the rest. | off |
| `--no-backup` | REFRESH-only: skip the Phase 0 backup. **Dangerous** — REFRESH regenerates files; without backup there's no rollback path. Refuse unless user passes this flag explicitly AND confirms in plan. | off (backup is ON by default in REFRESH) |
| `--backup-dir=<path>` | REFRESH-only: override the default backup location (`.claude/backups/<YYYYMMDD-HHmm>/`). Useful when the project has its own backup convention or you want backups in `~/Documents/...` outside the repo. | `.claude/backups/<YYYYMMDD-HHmm>/` |
| `--diff` | Show pack/template version drift between what's recorded in `.claude/codebase-profile.md` and what's currently in `~/.claude/templates/`. Read-only — never writes. Output: per-pack `recorded → current` with semver classification (patch / minor / major / breaking). Pairs naturally with `--refresh` to plan an upgrade. | off |
| `--health` | Compute setup health score (% of files matching contract, drift score, telemetry summary) and exit. Read-only. Useful for CI / pre-commit / weekly audit. Writes nothing except optionally appending one entry to `.claude/_telemetry.jsonl` (if telemetry enabled). | off |
| `--validate-schemas` | Run schema validation on every generated JSON config (`settings.json`, `opencode.json`, `.cursor/rules/*.mdc` frontmatter, `.mcp.json`, etc.) against `~/.claude/templates/schemas/`. Halt + report on first failure. Pairs with `--refresh` to confirm the regen produced valid output. | off (Phase 5 runs a lighter version automatically; this flag forces full validation including dry-invoke smoke tests) |
| `--wizard` | Interactive Q&A mode — replaces the "ask ONE consolidated question" with a step-by-step conversation. Best for: new team members, unfamiliar stacks, greenfield CREATE where the prompt was sparse. Each step shows mock output preview before user approval. | off (default is one-question-block mode) |
| `--lang=<ar\|en\|auto>` | Language for setup prompts + generated bilingual headers. `auto` reads `$LANG` / `$LC_ALL` env vars and falls back to `en`. When `ar`: Phase 2.y intent questions output in Arabic; generated CLAUDE.md / AGENTS.md / `ai/README.md` get an Arabic preamble above the English body. Generated code comments stay English. | `auto` |
| `--no-telemetry` | Disable telemetry append to `.claude/_telemetry.jsonl`. Telemetry is local-only (never sent anywhere) but some users prefer no log file at all. | off (telemetry on by default; entirely local) |
| `--plan` | **Universal flag — also applies to every generated command** (`/add-feature`, `/fix-bug`, `/add-module`, etc., not just `/setup-project`). Runs Phases 1-3 (Understand / Organize / Retrieve), expands the mini-plan into a full structured plan via Phase 3.5, writes to `.claude/plans/<command>-<slug>-<YYYYMMDD-HHmm>.md`, and exits BEFORE Phase 4 (Generate). The plan file is the handoff artifact for any other tool (OpenCode, Cursor, Aider, a human). After implementation, run `/verify-plan <file>` to audit drift. See Phase 3.5 in the canonical command structure for the plan-file format + "Retrofitting --plan to existing projects" sub-section for upgrading projects that pre-date this flag (TL;DR: `/setup-project --refresh` regenerates commands with `--plan` support; backups + knowledge-extract make it non-destructive). | off (default is direct execution) |

**Flag precedence when conflicting:**
- `--create` + `--enhance` → user error; refuse.
- `--create` + `--refresh` → user error; refuse (refresh requires existing setup).
- `--enhance` + `--refresh` → REFRESH wins (refresh is the strict superset: it does enhance's gap-fill PLUS regen-with-prior-knowledge); warn the user that refresh is more invasive.
- `--create` + `--refine` → user error; refuse (REFINE requires existing setup to deepen).
- `--refine` + nothing-to-refine (no `.claude/` artifacts present) → user error; suggest plain `/setup-project` (CREATE) first, then `--refine` afterwards.
- `--enhance` + `--refine` → run as a 2-phase pipeline in order: ENHANCE first (gap-fills missing files), then REFINE (deepens the now-complete set). User gets one combined report. Common pattern after picking up a half-set up legacy project.
- `--refresh` + `--refine` → REFRESH wins (refresh already replaces every artifact with the latest template content, so re-deepening a freshly-templated artifact is mostly redundant); warn user and suggest running `--refine` AFTER refresh completes if the refreshed artifacts still feel generic. Refuse silent merge.
- `--refine` + `--minimal` → REFINE only deepens artifacts that already exist; combined with `--minimal` it keeps the minimal scope but deepens the essentials. Allowed.
- `--refine` + `--force-replace-all` → user error; refuse. REFINE's safety contract (never touch user-authored sections) is incompatible with `--force-replace-all`. Suggest `--refresh --force-replace-all` if a full reset is the actual goal.
- `--refine` + `--force-keep-all` → REFINE wins for `## Project-specific` blocks (those are auto-generated, refining them is the whole point); `--force-keep-all` still applies to user-authored sections. Allowed; warn user.
- `--refine` + `--dry-run` → both apply; dry-run shows the per-artifact anchor-density delta and the proposed Project-specific block rewrites without writing.
- `--max-subagents=<N>` + non-REFINE mode → ignored (with warning). The flag is REFINE-only because round-one phases have their own intrinsic caps.
- `--max-subagents=<N>` with `N < 1` → user error; refuse. `N=1` is allowed (forces fully serial REFINE) but emits a warning that REFINE will be slow.
- `--include-incidents=<path>` without `--refine` → user error; refuse. The flag is meaningful only for Phase 2.12 (REFINE-only).
- `--include-runbooks` without `--refine` → user error; refuse. The flag is meaningful only for Phase 4.7-DEEP (REFINE-only).
- `--force-replace-all` + `--force-keep-all` → user error; refuse.
- `--force-keep-all` + `--refresh` → user error; refuse (`--force-keep-all` defeats the purpose of refresh — if you don't want to overwrite anything, use `--enhance` instead).
- `--tools=<list>` + `--add-tool=<name>` → both apply (list refreshed, added tool also applied).
- `--minimal` + `--enhance` (already-standard project) → expands existing standard, ignores `--minimal` (don't shrink); warn user.
- `--minimal` + `--refresh` → REFRESH downgrades to essentials-only regeneration (allowed; warn user that the existing standard set is being shrunk to minimal — extracted knowledge still preserved).
- `--no-backup` + `--dry-run` → both apply (dry-run shows what backup WOULD be skipped).
- `--no-backup` without `--refresh` → user error; refuse (`--no-backup` is REFRESH-only).
- `--diff` + any write-mode flag (`--create` / `--enhance` / `--refresh` / `--force-*`) → `--diff` is read-only; other write flags ignored with a warning. Suggest "run `--diff` first, then re-run without `--diff` to apply."
- `--health` + any write-mode flag → same as `--diff`: read-only wins, warn user.
- `--validate-schemas` standalone → runs schema check against current setup; no writes.
- `--validate-schemas` + `--refresh` → runs full validation INCLUDING dry-invoke smoke tests after regen.
- `--wizard` + non-empty `<prompt>` → both apply (prompt seeds the wizard's first answer; user confirms / edits).
- `--wizard` + `--dry-run` → wizard runs to completion, plan shown, no writes.
- `--lang=ar` + workspace cascade → each sub-project also gets `--lang=ar` applied (locale propagates).

**End state (greenfield)**: baseline scaffolded + CLAUDE.md + `AGENTS.md` + ai/ (status / stack / modules / architecture / conventions / patterns / runbooks / decisions + references/models.md) + phase-1 plan + relevant tracks + domain tooling + `.claude/codebase-profile.md` + selected tool adapters.

**End state (existing codebase)**: zero overwrites of user-authored content; additive track files; adapted knowledge-base with detected reference paths; Recent Changes entry documenting what happened; tool adapters added for any new driver (Cursor, Aider, OpenCode, ...) detected or requested.

## 🎫 Task providers (`/task`)

Setup wires task-tracker MCPs per repo: add provider creds to the repo's `.env` (Trello / Jira / Linear / GitHub), and `scripts/detect-mcp.sh --apply` (run by setup) writes them into `.mcp.json`. Then `/task <url|key|next>` pulls a ticket → executes via `/do` → writes status back. Full guide: [`docs/TASK-PROVIDERS.md`](../docs/TASK-PROVIDERS.md).

---

