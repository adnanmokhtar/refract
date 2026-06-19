# Claude Code adapter

**Tool:** Anthropic's Claude Code CLI.
**Docs:** https://code.claude.com/docs/en/overview
**Capabilities:** R, A, S, C, H, N — everything.

This adapter is the **canonical source**. Other adapters derive from what this one produces.

## Target files

```
repo-root/
├── CLAUDE.md                          # Root-level project instructions (superset of AGENTS.md)
└── .claude/
    ├── settings.json                  # Permissions + hook wiring
    ├── agents/*.md                    # Specialized personas (with opus/sonnet/haiku frontmatter)
    ├── skills/<name>/SKILL.md         # Scripted procedures
    ├── commands/*.md                  # Slash commands
    ├── rules/*.md                     # Prose rules / guardrails
    └── hooks/*.sh                     # Shell scripts (PreToolUse/PostToolUse/Stop/SessionStart)

# AGENTS.md is written by the codex adapter (delegated). See codex/adapter.md.
```

## File formats

### `CLAUDE.md` (root)
Plain markdown. Top-level project conventions, architecture pointers, "Read before edit" rules. Loaded into every Claude Code session automatically.

### `.claude/agents/*.md`
Markdown with YAML frontmatter:
```yaml
---
name: agent-name
description: One-line description shown in agent picker
tools: All tools                       # or: Bash, Read, Edit, Write, WebFetch, ...
model: opus|sonnet|haiku|inherit
---
```
Body = the agent's system prompt.

### `.claude/skills/<name>/SKILL.md`
Markdown with frontmatter:
```yaml
---
name: skill-name
description: What this skill does
---
```
Body = instructions the skill follows. Optional sibling files (`script.sh`, `template.md`) live in the skill's folder.

### `.claude/commands/*.md`
Markdown. The command name is the filename (minus `.md`). Body = prompt template Claude executes when user types `/<name>`. Can reference `$ARGUMENTS` placeholder.

### `.claude/rules/*.md`
Plain markdown. Rules are project conventions Claude consults when editing code. Naming: kebab-case. Grouped by concern (e.g. `tenant-safety.md`, `cache.md`, `dtos-mappers.md`).

### `.claude/hooks/*.sh`
POSIX shell. Must be executable. Common hooks:
- `post-edit-check.sh` — runs after Edit/Write/MultiEdit (lint/typecheck).
- `pre-edit-guard.sh` — blocks edits to sensitive paths (.env, lock files, migrations).
- `guard-destructive.sh` — second-layer block on destructive bash.
- `session-start.sh` — one-time briefing on session open.
- `update-session-log.sh` — Stop hook, appends session summary.

### `.claude/settings.json`
JSON. Schema:
```json
{
  "hooks": { "PostToolUse": [...], "PreToolUse": [...], "Stop": [...], "SessionStart": [...] },
  "permissions": { "allow": [...], "deny": [...] }
}
```

## Translation recipe

This adapter **originates** content — it doesn't translate from elsewhere. Other adapters translate FROM `.claude/` outputs.

Generator logic:
1. From `/setup-project` pack selection → copy matching files from `~/.claude/templates/packs/<track>/` into `.claude/`.
2. From detected domain signals → copy `~/.claude/templates/domains/<signal>/` into `.claude/`.
3. From codebase profile → inject real paths into generic agent/rule prose (see main command Phase 2.3 "reference-path injection").
4. Merge baseline from `~/.claude/templates/repo-baseline/.claude/` (hooks + settings.json).
5. Write `CLAUDE.md` from CLAUDE.md template + stack detection.
6. **`AGENTS.md` is owned by the codex adapter, not this one.** Phase 4.8 ordering runs `claude-code` first (this adapter), then `codex` second — codex reads the just-written `CLAUDE.md` + `.claude/` outputs and produces the compacted universal `AGENTS.md`. This adapter does NOT write `AGENTS.md` directly. See `codex/adapter.md`.

## Idempotency

Re-running: each file has a generator-owned top region (ended by `<!-- GENERATOR END -->`). Below that marker, user edits are preserved. Above it, regenerated fresh.

Files that are 100% user-owned once created: all `ai/decisions/*.md`, `ai/status.md`, `ai/dynamic/*`.

## Known gotchas

- `.claude/hooks/*.sh` must be `chmod +x` after copy.
- `settings.json` can't be partially merged by most editors — always full-file overwrite from baseline, then append user's custom entries at the specific slots.
- `CLAUDE.md` is auto-loaded on session start — keep it under 200 lines or it burns context.
- **Agent model cost watch**: `model: opus` costs ~5× more per invocation than `sonnet` and ~25× more than `haiku`. Default policy:
  - `opus` — reserve for reasoning-heavy roles only (architect, security-auditor, schema-architect, distributed-systems-architect).
  - `sonnet` — default for reviewers and most domain agents.
  - `haiku` — short-loop reactive helpers (linters, formatters, doc-syncers).
  - When `model:` is missing, the agent inherits the session model — usually fine for general-purpose roles.
  - Phase 5 emits a warning when more than 5 agents in one project carry `model: opus`. Audit the list against the policy above.

## Sample output

`CLAUDE.md` starts with:
```markdown
# <Project Name> — Project Rules

## #1 Rule: Read Before You Write
...

## AI Knowledge Base
**MANDATORY**: Before performing any task, consult the `ai/` knowledge base:
- `ai/README.md` — Navigation index
- `ai/status.md` — Current state + roadmap
- `ai/references/models.md` — Which tools route to which models
...
```

`.claude/agents/backend-reviewer.md`:
```markdown
---
name: backend-reviewer
description: Reviews backend code against project patterns
tools: All tools
model: sonnet
---

You are the backend reviewer for <Project>. The project uses <stack> ...
```

## Full artifact translation

Claude Code is the source of truth — no translation needed. All 4 artifact types (commands, agents, skills, hooks) are native. Other adapters consume THIS adapter's outputs:

- Rules (`.claude/rules/*.md`) → translated to every tool's native rule format.
- Commands (`.claude/commands/*.md`) → translated to OpenCode commands, Cursor `command-*.mdc`, Continue `prompts:`, Copilot `.github/prompts/*.prompt.md`, Cline/Windsurf/Codex/Gemini sections, Aider `CONVENTIONS.md` sections.
- Agents (`.claude/agents/*.md`) → translated to named prompts with "Act as" framing everywhere except Claude Code.
- Skills (`.claude/skills/<name>/SKILL.md`) → free for OpenCode (reads `~/.claude/skills/` globally); translated to named prompts/procedures for others.
- Hooks (`.claude/hooks/*.sh`) → NOT translatable. Other adapters fall back to git hooks + always-apply rules + gap disclosure. See `ai/references/tool-parity.md`.

**Running order in `/setup-project` Phase 4.8**: claude-code adapter runs FIRST (produces canonical artifacts); all other adapters translate FROM these files. Never write rules/commands/agents/skills in tool-specific adapters without first writing them here.

## Cross-references

- **Template-pack authoring:** When editing commands/snippets in `claude-config` `templates/`, run Phase 5 checks documented in `templates/tool-adapters/_template-author-scripts.md` (`audit-stack-leakage.sh`, `audit-command-dry.sh`; canonical pointers `templates/governance/core-discipline.md`, `templates/snippets/`).
- **Migration pack — companion scripts (2026-05):** With `--include=migration`, install the **full** `claude-config/scripts/` bundle into `~/.claude/scripts/` (validator + `migration-doctor.sh` + `migration-reachability.sh` + `migration-detect-existing.sh` + `migrate-parallel.sh` / `parallel-fan-out.sh`), not only `validate-migration-artifacts.sh`. Canonical list: `templates/tool-adapters/_migration-pack-coverage.md` § **Companion scripts (2026-05)**.
- **Optimize pack — companion scripts (2026-05):** `/optimize` installs **`validate-optimize-artifacts.sh`**, **`optimize-parallel.sh`**, and uses **`parallel-fan-out.sh --ledger=ai/optimize/ledger.md`** (via the optimize wrapper). See `templates/tool-adapters/_optimize-pack-coverage.md`.
- **Refactor pack — companion scripts (2026-05):** `/refactor` installs **`validate-refactor-artifacts.sh`** for `ai/refactor/ledger.md`. See `templates/tool-adapters/_refactor-pack-coverage.md`.
- **Polish pack — companion scripts (2026-05):** `/polish` installs **`validate-polish-artifacts.sh`**, **`polish-parallel.sh`**, and uses **`parallel-fan-out.sh --ledger=ai/polish/ledger.md`** (via the polish wrapper). Stack-conditional evidence per `PROJECT_KIND` (frontend → `_visual-decisions.md`; backend → `_api-decisions.md`; data → `_schema-decisions.md`; mobile → `_platform-decisions.md`). Frontend rows are additionally gated by **`check_frontend_verb_vocabulary`** against the closed 19-verb **`ui-design-sweep`** set (ui-ux pack v1.1+, sibling to refactoring-sweep / api-consistency-audit / schema-consistency-audit). See `templates/tool-adapters/_polish-pack-coverage.md` + `templates/tool-adapters/_ui-ux-pack-coverage.md`.
- **Align pack — companion scripts (2026-05):** `/align` installs **`validate-align-artifacts.sh`**, **`align-parallel.sh`**, and uses **`parallel-fan-out.sh --ledger=ai/align/ledger.md`** (via the align wrapper). See `templates/tool-adapters/_align-pack-coverage.md`.
- **Audit pack — companion scripts (2026-05):** `/audit` artifacts live under `ai/audit/**` (`plan.md`, `progress.md`, per-axis subfiles `_arch.md` / `_quality.md` / `_security.md` / `_db.md` / `_perf.md` / `_scale.md` / `_infra.md` / `_obs.md`, `final-report.md`, `assessment.md`). **Three output modes**: default (execute), `--plan-only` (ranked fix-plan in `plan.md` — executor handoff), `--assess` (8-section senior-engineer narrative in `assessment.md` — what's good / improve / unify / extract / simplify / redesign / remove / optimize — reader handoff). Validator **`validate-audit-artifacts.sh`** ships in `scripts/` — halts on hand-waves (`etc.`, `would be slow`, `at scale this is bad`) and requires P0 findings to cite a target-RPS failure mode (`check_no_handwaves_audit_plan` + `check_p0_failure_mode_cited`; `--strict` adds `<file:line>` citation enforcement on P0/P1/P2). Dispatches existing pack scripts internally (`validate-optimize-artifacts.sh`, `validate-align-artifacts.sh`, `validate-polish-artifacts.sh`) for the architecture / SOLID / clean-code / API-consistency axes; security + DB + scale axes use their respective pack agents and skills directly. See `commands/audit.md` + `templates/tool-adapters/_orchestration-sync.md`.
- **Unify-surfaces pack — companion scripts (2026-05):** `/unify-surfaces` (frontend-only, sibling to `/polish`) artifacts live under `ai/unify-surfaces/**` (`progress.md`, per-category inventory, canonical-wrapper decision evidence, `final-report.md`). Validator **`validate-unify-surfaces-artifacts.sh`** is **planned** — will check per-category inventory completeness, canonical-wrapper decision citations, idioms-update co-commit (`_extracted-idioms.md § Wrappers` updated in same commit), `Reuse-Before-Create` enforcement (extracting a duplicate where a shared wrapper exists fails). 7 default categories: tables / forms / headers / tabs / filters / buttons / validation. Validation is a 3-part pipeline (composable + components + API-error mapper), not a single wrapper. Halts on `PROJECT_KIND` not in `frontend-* / mobile-web / mobile-rn` with redirect to `/polish`. See `commands/unify-surfaces.md` + `templates/tool-adapters/_orchestration-sync.md`.
- **Orchestration / validator sync:** **`templates/tool-adapters/_orchestration-sync.md`** — discipline paths (`ai/migrate/progress.md`), optimize oracle fallbacks, align 21-verb closure vocabulary, polish validator env (`QUIET=1`; no `--strict` CLI), refactor hook paths.
- **`/task` integration (MCP-backed):** provider-agnostic task executor — Trello / Jira / Linear / GitHub Issue → fetch → normalize → dispatch → write-back (in-progress → comment → review/done). This tool surfaces it as `.claude/commands/task.md` (native slash command); needs a task-provider MCP from `scripts/detect-mcp.sh` (gated on the repo's own `.env` creds). It routes execution via `/do` (native). Canonical recipe + per-tool matrix: `templates/tool-adapters/_task-integration-coverage.md`; lifecycle: `commands/task.md`; providers: `templates/integrations/task-providers.md`.
- **Actionable next steps — universal report contract (2026-05):** Every report-producing command (`/optimize`, `/polish`, `/align`, `/migrate`, `/refactor`, `/audit`, `/unify-surfaces`) ends its `final-report.md` with a `## Actionable next steps` section per **`templates/snippets/actionable-next-steps.md`** — paste-ready commands with comment + exact path / `--scope=<path>` / `--focus=<verb>`. The **`check_actionable_next_steps`** function (in all 5 `validate-*-artifacts.sh`) halts when the section is missing OR when a command line is prose-not-args. Native hooks invoke the validators on edits under `ai/{optimize,polish,align,migration,refactor}/**`.
- `~/.claude/templates/packs/` — the pack catalog this adapter pulls from.
- `~/.claude/templates/repo-baseline/.claude/` — baseline hooks + settings.
- `~/.claude/commands/setup-project.md` — the orchestrator that invokes this adapter.
- `ai/references/tool-parity.md` — what other adapters can/can't replicate.
