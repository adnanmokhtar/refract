---
phase: 4
sub-phase: "4.8-DEEP"
name: re-sync-tool-adapters
applies-to-modes: [REFINE]
inputs: [updated source artifacts, enabled adapters list]
outputs: [each adapter's native folder re-translated; gap-disclosure refreshed]
exit-criteria: every enabled adapter shows the same artifact-count surface as Claude Code (Phase 4.8.0 contract); gap-disclosure section accurate
note: Most adapter detail also lives in commands/setup-project-adapters.md (sibling). This sub-phase is the REFINE-time refresh path.
imported-by: templates/phases/phase-4-apply.md
---

### Phase 4.8-DEEP — Re-sync tool adapters with deepened artifacts (REFINE mode only)

**Mode constraint**: Phase 4.8-DEEP runs ONLY in REFINE mode. CREATE/ENHANCE/REFRESH use the regular Phase 4.8 (see `phase-4-templates.md`). REFINE adds this deep-sync pass to keep tool adapters in sync with re-deepened `.claude/` artifacts.

**Trigger**: REFINE mode (`--refine`), after Phase 4.7-DEEP completes. Skipped in CREATE / ENHANCE / REFRESH (those modes run regular Phase 4.8 as part of the standard pipeline, which writes every adapter from scratch).

**Why this exists**: Phase 4.6-DEEP rewrites `## Project-specific` blocks of `.claude/{rules,commands,agents,skills}/*.md`; Phase 4.7-DEEP rewrites markered regions of `ai/*.md` and may write new `ai/failures/<theme>.md`. **The `claude-code` adapter is auto-current** — it reads `.claude/` directly. **Every other selected adapter is NOT** — they embed compact translations of those artifacts (`.cursor/rules/<name>.mdc` body inlined from `.claude/rules/<name>.md`; `opencode.json` `commands` block embedding command prompts; `AGENTS.md` § "Named procedures" listing every skill; `CONVENTIONS.md` embedding must/must-not from `ai/_convention-cheatsheet.md`; `.continue/rules/`, `.clinerules/`, `.windsurf/rules/`, `.github/instructions/`, `.github/prompts/`, `GEMINI.md` — all stale after REFINE). Without 4.8-DEEP, REFINE produces the failure mode "Claude got smarter, Cursor still talks generic prose." This phase closes the gap.

**Mechanism**: invoke the `apply-pack-adaptation` skill (already used by 4.6-DEEP and 4.7-DEEP) in `ADAPTER-SYNC` mode against the affected-artifact list:

1. **Collect affected artifacts**: read `.claude/_phase-4-6-decisions.md` REFINE section + `_phase-4-7-decisions.md` REFINE section. Build the list:
   - **Anchor changes**: every artifact with action `ANCHOR-DEEP` in 4.6-DEEP (`.claude/{rules,commands,agents,skills}/*.md` whose `## Project-specific` block was rewritten).
   - **New artifacts**: every artifact with action `NEW-FILE` in 4.6-DEEP (a brand-new `.claude/skills/<name>/SKILL.md` or `.claude/rules/<name>.md` that 4.6-DEEP added because deep extraction surfaced a genuine gap).
   - **`ai/` changes**: every `ai/*.md` whose `<!-- refine-enriched:start/end -->` markers were rewritten in 4.7-DEEP, plus every new `ai/failures/<theme>.md`.
   - **Index-impacting flag**: set `index_refresh = true` if the affected list contains ANY `NEW-FILE` row — adapter "index" outputs (which enumerate every command / agent / skill) MUST regenerate.

2. **Per-adapter affected output map**: for each adapter selected at Phase 3.2 (read `.claude/codebase-profile.md`'s adapter list), the affected artifacts produce a list of adapter-side outputs to re-translate. The mapping reuses Phase 4.8.0's per-adapter contract — the only thing that changes is **which** outputs run, not **how** they're written:

   | Adapter | Per-artifact re-translation | Index-refresh outputs (when `index_refresh = true`) |
   |---|---|---|
   | `claude-code` | NO-OP — REFINE wrote `.claude/` directly. | NO-OP. |
   | `opencode` | For each affected `.claude/commands/<x>.md`: re-render the corresponding `commands.<x>` entry in `opencode.json` (description + prompt). | Regenerate `commands` block fully (every command); regenerate `AGENTS.md` § "Invokable commands", "Named personas", "Named procedures" sections. |
   | `cursor` | For each affected `.claude/{rules,commands,agents}/<x>.md` or `.claude/skills/<x>/SKILL.md`: re-render the corresponding `.cursor/rules/{<domain>,command-<x>,agent-<x>,skill-<x>}.mdc`. | Regenerate `.cursor/rules/00-project.mdc` cross-references section. |
   | `aider` | For each affected `.claude/commands/*.md` or `.claude/agents/*.md` or `.claude/skills/*/SKILL.md`: regenerate the matching named-procedures / personas / runbook entry in `CONVENTIONS.md`. For each affected `.claude/rules/*.md`: refresh the must/must-not list (top 6-10 from `ai/_convention-cheatsheet.md`). | Refresh `.aider.conf.yml` `read:` list if any `ai/*.md` from the affected list is referenceable; regenerate `CONVENTIONS.md` named-procedures / personas / runbook indexes. |
   | `continue` | For each affected `.claude/rules/<x>.md`: re-render `.continue/rules/<x>.md`. For each affected command/agent/skill: re-render the corresponding `prompts:` entry in `.continue/config.yaml`. | Regenerate `.continue/config.yaml` `prompts:` block fully. |
   | `cline` | For each affected `.claude/rules/<x>.md`: re-render `.clinerules/<NN>-<x>.md`. | Regenerate `.clinerules/{80-commands,81-agents,82-skills}.md` indexes. |
   | `windsurf` | For each affected `.claude/rules/<x>.md`: re-render `.windsurf/rules/<NN>-<x>.md`. | Regenerate `.windsurf/rules/{80-commands,81-agents,82-skills}.md` indexes. |
   | `copilot` | For each affected `.claude/rules/<x>.md`: re-render `.github/instructions/<x>.instructions.md`. For each affected command/agent/skill: re-render `.github/prompts/{<command>,agent-<name>,skill-<name>}.prompt.md`. | Regenerate `.github/copilot-instructions.md` (≤2k tokens summary of CLAUDE.md). |
   | `codex` | NO per-artifact files — `codex` puts everything into a single `AGENTS.md`. | Regenerate `AGENTS.md` sections impacted: "Conventions" (if a rule changed), "Invokable commands" / "Named personas" / "Named procedures" (always when `index_refresh = true`, OR when any of those artifacts changed). Other sections (project overview, architecture, code style, deployment) are NOT touched unless the corresponding source file changed. |
   | `gemini` | If `GEMINI.md` is the **thin-pointer** variant (AGENTS.md exists): NO-OP — pointer is already current. If `GEMINI.md` is the **full-copy** variant: same as `codex`. | Same as per-artifact column. |

3. **Concurrency cap**: respects `--max-subagents=<N>` (default 8). Per-adapter generation can fan out across adapters in parallel; within an adapter, per-artifact re-translation can also fan out. Total concurrent subagents at any instant ≤ N, shared with the prior REFINE phases' caps (phase boundaries are sequential — by the time 4.8-DEEP starts, all 4.6-DEEP + 4.7-DEEP subagents have completed).

4. **User-customized adapter files**: Phase 4.8-DEEP does NOT modify adapter files the user has hand-edited beyond the "auto-generated" markers regular Phase 4.8 placed (e.g. user added a custom rule to `.cursor/rules/00-project.mdc` outside the `<!-- generated:start -->` ... `<!-- generated:end -->` block). The same marker-bracketed write contract from 4.6-DEEP / 4.7-DEEP applies: SHA-256 hash-check on bytes outside the generated markers, ROLLBACK + log on mismatch, MARKERS-INJECTED if the file has markerless prior content (record once; subsequent runs use the markers). For adapter files that have NO markers convention yet (most don't — Phase 4.8 typically writes the whole file), the per-adapter contract specifies which files are wholly auto-generated (re-write freely) vs which have user-customizable sections (use markers). See `templates/tool-adapters/<adapter>/_user-customization.md` for each adapter's customization surface.

5. **Affected-list empty → skip**: if the union of 4.6-DEEP + 4.7-DEEP affected lists is empty (e.g. Phase 4.6-DEEP returned all `LEAVE-DEEP-IDEMPOTENT` rows AND Phase 4.7-DEEP returned all `LEAVE-DEEP-IDEMPOTENT` rows), Phase 4.8-DEEP is a no-op. Log `SKIPPED-NO-CHANGES` to `_phase-4-8-decisions.md` and proceed to Phase 5.

6. **Decision log** (`_phase-4-8-decisions.md`): one row per `(adapter, output-file, action)` tuple with columns:

   | Adapter | Output file | Action | Triggered by | Notes |
   |---|---|---|---|---|
   | cursor | `.cursor/rules/database.mdc` | RE-TRANSLATED | `.claude/rules/database.md` ANCHOR-DEEP | anchor density 41 → 76 |
   | opencode | `opencode.json` `commands` block | INDEX-REFRESHED | NEW-FILE: `.claude/commands/db-migration.md` | full block regenerated |
   | aider | `CONVENTIONS.md` | RE-TRANSLATED | 4 rules ANCHOR-DEEP'd | must/must-not list refreshed |
   | claude-code | (n/a) | NO-OP | REFINE writes .claude/ directly | always skipped |
   | gemini | `GEMINI.md` | NO-OP | thin-pointer variant — AGENTS.md is source | always skipped |
   | continue | `.continue/rules/security.md` | ROLLBACK-MARKER-DRIFT | bytes outside generated markers changed | preserved user edits; user MUST re-edit |
   | windsurf | `.windsurf/rules/82-skills.md` | INDEX-REFRESHED | NEW-FILE: `.claude/skills/parallel-fanout/SKILL.md` | + skill listing |

7. **Phase 5 verification still runs**: after 4.8-DEEP, regular Phase 5's per-adapter coverage check (Phase 4.8.0 contract — every command listed, every rule translated, etc.) executes. If REFINE created a new command via NEW-FILE and 4.8-DEEP missed it, Phase 5 catches the shortfall and triggers the standard retry loop.

**Coverage target**: every artifact in the 4.6-DEEP / 4.7-DEEP affected list MUST have a `_phase-4-8-decisions.md` row for every selected adapter (or claude-code's NO-OP / gemini's thin-pointer NO-OP). **No silent skips** — every (adapter, artifact) tuple is logged in `_phase-4-8-decisions.md` for Phase 5 audit. Phase 5.3 cross-checks affected-list against decision-log rows; gaps surface as halt findings. (Until that cross-check is wired, this is partly self-policed; see TODO in scripts/lint-decision-logs.sh.)

**Why this is a phase, not a sub-step of 4.8**: regular Phase 4.8 writes every adapter file from the full artifact set; 4.8-DEEP writes only the affected slice (much faster on a 50-rule project where REFINE only rewrote 8 rules). Splitting them keeps the round-one path cheap and makes round-two cost-bounded.

**4.8 Apply tool adapters** — runs **per scope** in workspace mode:

- **Workspace root**: gets **thin anchor versions** of `AGENTS.md` + `CLAUDE.md` + `opencode.json` — each pointing at sub-projects' own configs. No full-fat rules/commands/agents/skills at workspace root.
- **Each sub-project**: gets **full** tool adapter output matched to its own stack (rules, commands, agents, skills translations per adapter). This is driven by the Phase 4.1 recursive cascade — when 4.1 runs Phases 2→4 for sub-project P, step 4.8 runs inside P and writes P's own `.cursor/`, P's own `opencode.json`, P's own `AGENTS.md`, etc.

Non-workspace mode (single-repo): this distinction doesn't apply — everything goes at repo root.

#### `--plan` flag translation (Phase 3.5 / canonical command structure)

The `--plan` flag is universal in Claude Code (the canonical 7-phase command structure declares it). For each non-Claude adapter, the translation must teach the tool how to honor `--plan` natively, since the source-of-truth flag lives in setup-project's canonical structure but each adapter has its own command syntax.

| Adapter | How `--plan` lands |
|---|---|
| `claude-code` | Native — Phase 3.5 runs as written; plan written to `.claude/plans/`. **Execution: `/execute-plan <file>` implements a saved plan (parallel executor sub-agents default to `model: sonnet` — pairs with an Opus `--plan` pass), then auto-runs `/verify-plan`.** |
| `opencode` | `opencode.json` `commands` block — each command's `prompt` includes "If the user appends `--plan` to the command invocation, write a plan in the canonical format defined at `.claude/plans/README.md` to `.claude/plans/<command>-<slug>-<timestamp>.md` and exit before implementation. Otherwise implement normally." Implementation entry: `--from-plan <file>` reads a plan and runs Phases 4-6 only. |
| `cursor` | `.cursor/rules/command-<name>.mdc` — append a section: "**Plan mode**: when user prompts `<command> ... --plan`, instead of implementing, write the plan to `.claude/plans/<command>-<slug>-<timestamp>.md` per the format in `.claude/plans/README.md`, then stop. Implementation mode (no `--plan`) runs as written above." |
| `aider` | `.aider.conf.yml` — add `read: .claude/plans/README.md` so the plan format is in context. `CONVENTIONS.md` includes a "Plan mode" section: when user types `/plan <command> "<prompt>"`, write plan to `.claude/plans/`, exit. Implementation mode is the default. |
| `continue` | `.continue/prompts/<command>.prompt.md` — branch on `--plan` arg as in OpenCode; same plan-file output. |
| `cline` / `windsurf` / `copilot` | Each command's translated prompt branches on `--plan` per the same pattern. |
| `codex` | `AGENTS.md` § "Invokable commands" — each command entry notes "supports `--plan` flag for handoff" with the format reference. |
| `gemini` | Same as codex — note in `GEMINI.md` command catalog. |

**Plan file format is tool-agnostic markdown** — every adapter consumes the same format. The only thing that varies is HOW each adapter is taught to write the plan (and how `--from-plan <file>` invokes implementation from a plan, where supported).

**Universal fallback (always works)**: any tool that reads markdown can implement from a plan by pasting the plan-file content into the tool's prompt + "implement per this plan." No native `--from-plan` required for the basic workflow.

**`/execute-plan` is universal (Claude-native fan-out; degrades per adapter)** — it ships in `repo-baseline/.claude/commands/execute-plan.md` (like `/verify-plan`) and lands in EVERY project. In Claude Code it implements a saved plan with **parallel `model: sonnet` executor sub-agents** — the "Opus plans, Sonnet executes" handoff. Non-Claude adapters have no parallel sub-agent dispatch, so their plan-execution degrades to the **sequential** path: the native `--from-plan <file>` entry where supported (`opencode`), else the universal paste-the-plan-and-implement fallback above. Same plan file, same Outputs/Steps/Constraints/Verification — only the fan-out is Claude-native (same split as `/refine-prompt`'s deep pass and the simple-surface multi-agent group; see `templates/tool-adapters/_registry.md`).

**`/verify-plan` is universal** — it ships in `repo-baseline/.claude/commands/verify-plan.md` and is included in EVERY project regardless of which adapters are selected. Each adapter translates it the same way it translates other commands. The canonical implementation reads + audits + reports — there's no tool-specific behavior beyond that.

**The spec→build seam is tool-agnostic (parallel to the plan-file seam above).** `/analyze-task` (and `/expand-task` when it saves a doc) writes the spec to `specs/<YYYYMMDD>-<slug>.md` with a `Spec-ID:` header; `/add-feature` accepts a `specs/<file>` path and consumes it as the requirements CONTRACT instead of re-deriving, threading the `Spec-ID` into commits/PR for traceability. The spec file is tool-agnostic markdown — every adapter's `analyze-task` / `add-feature` translation honors the same handoff (spec out → spec in). The conformance enforcement `/add-feature` runs from a spec (NFR / authorization / observability / rollout verified, AC→test traceability rebuilt, sizing-signal-seeded tier) lives in the canonical command body, so it rides the generic per-command translation; its **parallel reviewer fan-out is Claude-native and degrades to sequential** per adapter (same split as the plan seam). Universal fallback: any tool that reads markdown treats the spec's stories + AC + traceability table as the build contract.

### 4.8.0 Per-adapter completeness contract (thin-stub-bug prevention for tool adapters)

**The historical bug**: Phase 4.8 was specced richly ("translate rules + commands + agents + skills + hooks fallback per spec") but the agent under context pressure shipped only the minimum — `opencode.json` with just an `instructions` block, nothing translated.

To prevent this, each adapter has a **minimum-output contract**. Phase 5 verifies. Coverage shortfall → retry → halt.

#### Per-adapter minimum output (each MUST produce all listed)

| Adapter | Required outputs |
|---|---|
| `claude-code` | `.claude/{agents,commands,skills,rules,hooks}/` populated per pack copy (Phase 4.2) + `.claude/settings.json` + `CLAUDE.md` at root. Note: `.claude/codebase-profile.md` is a Phase 2 output (not an adapter output); the claude-code adapter relies on it but never writes it. |
| `opencode` | (a) `opencode.json` with: `provider` block (defaults), `instructions` glob array. (b) `.opencode/agents/<name>.md` for every `.claude/agents/<name>.md` (NATIVE folder). (c) `.opencode/commands/<name>.md` for every `.claude/commands/<name>.md` (NATIVE folder). (d) `.opencode/skills/<name>/SKILL.md` (+ supporting scripts) for every `.claude/skills/<name>/` (NATIVE folder copy). (e) `AGENTS.md` with sections: `## Invokable commands`, `## Named personas`, `## Named procedures`. (f) Optional legacy mirror in `opencode.json` `commands` block when `--legacy-opencode` is set. |
| `cursor` | (a) `.cursor/rules/00-project.mdc` (alwaysApply, project-wide) + per-rule MDC files for every `.claude/rules/*.md`. (b) `.cursor/commands/<name>.md` for every `.claude/commands/<name>.md` (NATIVE folder). (c) `.cursor/commands/agent-<name>.md` for every `.claude/agents/<name>.md` (NATIVE folder — Cursor has no agent dispatch, personas are commands). (d) `.cursor/skills/<name>/SKILL.md` (+ scripts) for every `.claude/skills/<name>/` (NATIVE folder copy). (e) `.cursor/hooks.json` translating every `.claude/hooks/*.sh` to its lifecycle event (NATIVE; ≥ Cursor 2.3). |
| `aider` | (a) `.aider.conf.yml` with `read:` listing — in this exact order — `CONVENTIONS.md`, `AGENTS.md`, `ai/README.md`, `ai/status.md`, and `ai/business-domain.md` IF that file exists in the project. (b) `CONVENTIONS.md` containing: project intro + must/must-not (top 6-10 from `ai/_convention-cheatsheet.md`) + named procedures (every command) + named personas (every agent) + skill-style runbook entries (every skill) + `## Driver-dependent safety` disclosure. (c) `.aiderignore` with `.env*`, `*.lock`, `node_modules/`, `dist/`, `build/` plus project-specific migrations directories detected during Phase 2. |
| `continue` | (a) `.continue/config.yaml` with `models:` (commented stub for user keys), `rules:` listing every `.claude/rules/*.md` translated to `.continue/rules/<name>.md`, `docs:` pointing at `ai/`. (b) `.continue/rules/<name>.md` per rule (one-to-one with `.claude/rules/*.md`). (c) `.continue/prompts/<name>.md` (NATIVE prompts folder, `invokable: true`) for every command, plus `.continue/prompts/agent-<name>.md` per agent and `.continue/prompts/skill-<name>.md` per skill. (d) `.continueignore` covering `.env*`, `*.lock`, project migrations dirs (sensitive-file fallback for missing hooks). (e) Optional minimal `prompts:` mirror in `config.yaml` for Continue < 1.0 backward compat. |
| `cline` | (a) `.clinerules/00-project.md` (always loaded — project rules + driver-gap disclosure). (b) `.clinerules/<NN>-<domain>.md` per `.claude/rules/<domain>.md` (one-to-one; `<NN>` ∈ {10..79}). (c) `.clinerules/workflows/<name>.md` for every `.claude/commands/<name>.md` (NATIVE — Cline workflows = slash commands). (d) `.clinerules/81-agents.md` (every agent persona — no native dispatch). (e) `.clinerules/82-skills.md` (every skill procedure — no native skills primitive). (f) Optional `.clinerules/80-commands.md` catalog for Cline < 3.0 backward compat. |
| `windsurf` | (a) `.windsurf/rules/00-project.md` (always activation) + per-rule files. (b) `.windsurf/workflows/<name>.md` for every `.claude/commands/<name>.md` (NATIVE — Cascade workflows = slash commands). (c) `.windsurf/rules/81-agents.md` (trigger_words activation per agent). (d) `.windsurf/rules/82-skills.md`. (e) Optional `.windsurf/rules/80-commands.md` catalog for backward compat. |
| `copilot` | (a) `.github/copilot-instructions.md` (repo-wide, ≤2k tokens, summary of CLAUDE.md). (b) `.github/instructions/<domain>.instructions.md` for every `.claude/rules/*.md` (with `applyTo:` glob). (c) `.github/prompts/<name>.prompt.md` for every command (NATIVE). (d) `.github/agents/<name>.agent.md` for every agent (NATIVE — Apr 2026 GA). (e) `.github/skills/<name>/SKILL.md` (+ scripts) for every skill (NATIVE — Agent Skills GA). (f) Optional `.github/chatmodes/<name>.chatmode.md` for any agent flagged for chat-mode translation. |
| `codex` | `AGENTS.md` at root with these sections: project overview, architecture, conventions (MUST/MUST-NOT), code style, testing, deployment, `## Invokable commands`, `## Named personas`, `## Named procedures`, `## Driver-dependent safety`, `## AI-tool adapters present`. |
| `gemini` | `GEMINI.md` at root either (a) full content like AGENTS.md if no AGENTS.md exists, OR (b) thin pointer file referencing AGENTS.md if AGENTS.md exists. Plus optional Gemini-specific notes. |

#### Coverage check (Phase 5 verifies, retries on shortfall)

Phase 5 verifies coverage using the contract defined in `scripts/audit-adapter-coverage.sh` (same logic as Phase 4.8.0 contract above; the script is the source of truth — do not duplicate the check here).

If shortfall detected: re-run that adapter's translation (Phase 5 retry loop). If retry also fails: halt with explicit error.

#### What "translate" actually means (each adapter's translation rule)

The Claude Code `.claude/commands/<name>.md` file has frontmatter `description:` + body. To translate to other tools:

- **OpenCode**: write `.opencode/commands/<name>.md` (NATIVE folder) with body 1:1 from `.claude/commands/<name>.md`.
- **Cursor (≥ 2.3)**: write `.cursor/commands/<name>.md` (NATIVE folder) with frontmatter `{description}` and body 1:1 from source. No prefix; filename = slash-command name.
- **Copilot**: write `.github/prompts/<name>.prompt.md` (NATIVE) with frontmatter `{mode: agent, description}` and body.
- **Continue**: write `.continue/prompts/<name>.md` (NATIVE) with frontmatter `{name, description, invokable: true}` and body. Optional minimal `prompts:` mirror in `config.yaml` for Continue < 1.0.
- **Cline**: write `.clinerules/workflows/<name>.md` (NATIVE — Cline workflows = slash commands).
- **Windsurf**: write `.windsurf/workflows/<name>.md` (NATIVE — Cascade workflows = slash commands).
- **Aider / Codex / Gemini**: append section to `CONVENTIONS.md` / `AGENTS.md` / `GEMINI.md` "Invokable commands" section with `### <name>` header + 5-30 line summary (full body stays in `.claude/commands/<name>.md` — referenced).

Same pattern for agents:
- **OpenCode**: `.opencode/agents/<name>.md` (NATIVE — frontmatter `{name, description, mode, model, tools}`).
- **Copilot**: `.github/agents/<name>.agent.md` (NATIVE — frontmatter `{description, tools, model}`).
- **Cursor**: `.cursor/commands/agent-<name>.md` (translated as a command — Cursor has no agent dispatch).
- **Continue**: `.continue/prompts/agent-<name>.md` (translated as a prompt).
- **Cline / Windsurf**: section in `.clinerules/81-agents.md` / `.windsurf/rules/81-agents.md` (no native dispatch).

And for skills:
- **OpenCode / Cursor / Copilot**: copy `.claude/skills/<name>/` folder verbatim to `.opencode/skills/<name>/` / `.cursor/skills/<name>/` / `.github/skills/<name>/` (NATIVE folder copy — `SKILL.md` + supporting scripts copied 1:1).
- **Continue**: `.continue/prompts/skill-<name>.md` (translated as a prompt).
- **Cline / Windsurf**: section in `.clinerules/82-skills.md` / `.windsurf/rules/82-skills.md`.

This translation is mechanical once you know the source — same as pack copying. Phase 4.8 should generate these files DETERMINISTICALLY (loop over `.claude/commands/`, `.claude/agents/`, `.claude/skills/`; for each, write the per-adapter target file). The agent's job: enumerate sources + execute translation; not free-form decide what to include.

**Parallelism (Hard Rules § Always — "Run setup-project's own independent sub-steps in parallel"):** the per-adapter generation loop is **independent across adapters** — `cursor` writes to `.cursor/rules/` while `opencode` writes to `opencode.json` while `aider` writes to `.aider.conf.yml`; no two adapters share a target path. Fan out one Explore subagent per selected adapter (cap = number of selected adapters, typically 1–4). Each subagent executes its adapter's full contract (Phase 4.8.0) end-to-end. After all subagents complete, Phase 4.8.1 runs sequentially (it audits the union of outputs).

Concrete dependency map (what's parallel-safe, what isn't):

```
SEQUENTIAL (must complete before fan-out):
  Phase 4.1 baseline scaffold     → all adapters need .claude/{commands,agents,skills,rules}/ on disk first
  Phase 4.2 / 4.4 / 4.4b / 4.6    → all adapters translate from these; the translation source must be stable

PARALLEL (fan out one subagent per item):
  Phase 2.5  base-class extraction       (one per base class; cap=6)
  Phase 4.2  per-track pack copy          (one per LOAD-BEARING track)
  Phase 4.4  technical-signal overlays    (one per detected signal)
  Phase 4.4b business-domain overlays     (one per detected domain — usually 1)
  Phase 4.8  per-adapter generation       (one per selected adapter; cap = #adapters)

SEQUENTIAL AGAIN (after fan-out joins):
  Phase 4.8.1 cross-adapter parity audit
  Phase 5     audit / leak scan / schema validation (5.1 → 5.2 → 5.3 → ...)
```

---

**Workspace root anchor shapes** (when shape=workspace):

`<workspace>/AGENTS.md`:
```markdown
# <workspace-name>
<one-paragraph workspace purpose>

## Sub-projects
- `api/` — <purpose> — see `api/AGENTS.md` + `api/CLAUDE.md`
- `dashboard/` — <purpose> — see `dashboard/AGENTS.md` + `dashboard/CLAUDE.md`

## Cross-repo commands (workspace .claude/commands/)
- `/cross-repo-task` — orchestrator for features spanning multiple sub-projects
- `/sync-contract` — API contract change → frontend impact
- `/project-map` — workspace dependency map
- `/workspace-status` — quick health + uncommitted state per sub-project

## Conventions
- Per-sub-project AGENTS.md is authoritative for that sub-project's rules.
- Commits stay per-sub-project; no workspace-level PRs.
```

`<workspace>/opencode.json` (schema-valid keys only — `_generator` lives in the sidecar `.opencode/_setup-project-meta.json` per `commands/setup-project-adapters.md § OpenCode contract`):
```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md",
    "CLAUDE.md",
    "api/AGENTS.md",
    "dashboard/AGENTS.md"
  ]
}
```

Each sub-project also writes its own `opencode.json` with its OWN instructions globs scoped to that sub-project.

---

**Per-adapter translation (runs per scope)** — for each adapter in the selected set, translate **all 4 artifact types** (not just rules):

1. Read its spec at `~/.claude/templates/tool-adapters/<key>/adapter.md`.
2. Walk the spec's four translation subsections in order:
   - **Rules** — translate `.claude/rules/*.md` into the tool's native rule format.
   - **Commands** — translate `.claude/commands/*.md` into the tool's native prompt/command format (or named sections for tools without commands).
   - **Agents** — translate `.claude/agents/*.md` into the tool's named-prompt format with "Act as <name>" framing (no tool except Claude Code has auto-dispatch).
   - **Skills** — translate `.claude/skills/<name>/SKILL.md` into the tool's procedure/prompt format. OpenCode is the one free win (reads `~/.claude/skills/` globally).
   - **Hooks** — NOT translatable in any tool. Fall back to:
     a. `.husky/` git hooks for commit-time enforcement.
     b. `.gitignore` / `.<tool>ignore` for sensitive-file blocking.
     c. Always-apply rule stating "read `ai/status.md` before starting" as a session-start proxy.
     d. Dedicated "Driver-dependent safety" section disclosing the gap.
3. Use the spec's "Idempotency" rules — generator markers, preserved user sections.
4. Pull source content from the ALREADY-written `.claude/` tree (so Claude Code adapter runs FIRST, others derive).
5. Always write `AGENTS.md` — even if no non-Claude adapter is selected (codex adapter owns this file + the universal anchor).
6. Always write `ai/references/tool-parity.md` + `ai/references/models.md` — so the gap matrix + model routing are documented once and referenced by every adapter's "driver-dependent safety" section.

**Ordering** (strictly enforced — `AGENTS.md` has exactly ONE writer to avoid last-writer-wins ambiguity):
1. `claude-code` adapter FIRST — produces `CLAUDE.md` + `.claude/{agents,commands,skills,rules,hooks}/`. Does NOT write `AGENTS.md`.
2. `codex` adapter SECOND — owns `AGENTS.md`. Reads the just-written `CLAUDE.md` + `.claude/` and compacts them into the universal anchor. ALWAYS runs, even when `codex` is not in `--tools` (because 8+ other tools fall back to `AGENTS.md`).
3. All other selected adapters in parallel — they don't conflict because each writes to a different native path. They MAY append cross-references to `AGENTS.md` (Phase 4.8 finalize step) but MUST NOT rewrite the codex-managed sections.

**Cross-adapter de-dup**:
- `CLAUDE.md` is the superset; `AGENTS.md` is a compacted version + "AI-tool adapters present" + "Invokable commands/personas/procedures" sections.
- Each tool adapter's rule/command/agent/skill files either REFERENCE the canonical `.claude/rules/`, `.claude/commands/`, `.claude/agents/`, `.claude/skills/` files (via `@file` in Cursor, paths in Aider's `read:`, etc.) OR embed a compact summary + pointer to the canonical file.
- NEVER fan-out full verbatim copies of rule/command/agent/skill bodies across every tool's config — that's duplication rot waiting to happen.

**Artifact-count sanity check (emitted in plan)**:
```
Rules translated:    <N> rules × <M> tools = <N*M> target files
Commands translated: <X> commands × <M tools that support> = <Y> target files
Agents translated:   <A> agents × <M tools that support>   = <B> target files
Skills translated:   <S> skills × <M tools that support>   = <C> target files (OpenCode: free; other tools: <D>)
Hooks:               <H> hooks → git hooks + gap disclosure (not translated)
```

**Gap disclosure** — every non-Claude-Code adapter writes a "Driver-dependent safety" section in its primary config listing which Claude Code hooks become soft (documented but not enforced) when the tool is used as the driver. Reference: `ai/references/tool-parity.md`.

