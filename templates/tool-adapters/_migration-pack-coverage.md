# Migration pack — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces the migration pack's artifacts when `--include=migration` is selected by `/setup-project`.

The migration pack is **non-negotiable** in the sense that its discipline rule (`migration-discipline.md`) is the contract every tool's setup must preserve. Adapters with low capability (Rules-only) translate the rule fully; adapters with full capability (R+A+S+C+H) get the full pack.

> **Why this file exists**: F039 (geography-mappings audit) shipped to production on Claude Code without enforcing the discipline because `/migration-phase` was a permissive shell. The fix made `migration-discipline.md` self-sufficient. This file documents how every other tool inherits that fix.

## Capability mapping per tool

| Tool | Full discipline via | Rule-only fallback |
|---|---|---|
| Claude Code | All artifacts (rule + agents + skills + commands + hooks) | n/a |
| OpenCode | All artifacts (rule + agents + skills + commands) | n/a |
| Cursor | rule + skills + commands + hooks (agents = convention only) | n/a |
| Copilot | rule + agents + skills + commands | n/a |
| Continue | rule + commands; agents/skills convention-based | partial — rule must self-suffice |
| Cline | rule + commands; no agents/skills | rule must self-suffice for agents/skills content |
| Windsurf | rule + commands; no agents/skills | rule must self-suffice for agents/skills content |
| Aider | rule only | full reliance on self-sufficient rule |
| Codex | rule only (+ agents convention) | full reliance on self-sufficient rule |
| Gemini | rule only | full reliance on self-sufficient rule |

**Conclusion**: every tool MUST receive a faithful translation of `migration-discipline.md` (the self-sufficient rule). The 9 contract sections, 10 hard halts, frontend audit axes, frontend anti-pattern catalogue, and tool-agnostic procedures are inlined in the rule precisely so rule-only tools have the full surface.

## NEW (2026-04-29 hardening) — required artifacts per project

Every adapter setup that includes `--include=migration` MUST also propagate these new elements:

1. **`ai/migration/_v2-anchors.md`** — per-project anchor file declaring `project_kind` (frontend-vue3 / frontend-react / backend-nest / etc.), `v1_root`, `v2_root`, gold-standard files, shared-component map, layering rules, forbidden V1 fingerprints. Schema: `templates/packs/migration/_v2-anchors-schema.md`. The validator + agents read this so checks are project-shape-agnostic.

2. **Audit doc frontmatter** — every audit at `ai/migration/audits/<feature>.md` MUST start with:
   ```yaml
   ---
   auditor_agent_id: <agent run ID OR rule-only-mode/<tool>/<UTC>>
   auditor_mode: agent | rule-only-mode/<tool>
   audit_date: <UTC ISO>
   v1_commit_pinned: <SHA>
   v2_commit: <SHA>
   ---
   ```
   `validate-migration-artifacts.sh § check_audit_provenance` HALTs without it. For rule-only tools (Aider/Codex/Gemini), the sentinel `auditor_agent_id: rule-only-mode/<tool>/<ISO>` is accepted; the trade-off is logged.

3. **`/migration-doctor`** workspace command — for multi-repo workspaces. Backed by `claude-config/scripts/migration-doctor.sh`. Walks every registered repo with a ledger, runs validator, surfaces cross-repo dependency drift + stale audits.

4. **12 new validator checks** (script-shipped — no per-adapter code change needed; just install the script):
   `check_audit_provenance`, `check_audit_freshness`, `check_audit_body_consistency`, `check_intentional_break_adr`, `check_porter_vs_auditor`, `check_corpus_distribution`, `check_tolerance_coverage`, `check_parity_run_v1_commit`, `check_v2_structure` (frontend + backend dispatch via `project_kind`), `check_composable_reuse`, `check_service_shape`, `check_lifecycle_keepalive`, `check_permission_gate_divergence`.

The validator script is location-agnostic — installed once at `~/.claude/scripts/validate-migration-artifacts.sh` (or shell-PATH equivalent) and invoked from any tool's hook system, CI, or pre-commit.

## Per-tool translation expectations

### Claude Code (`.claude/`)
- Full pack as-is.
- `migration-discipline.md` → `.claude/rules/migration-discipline.md`
- `parity-auditor.md`, `migration-architect.md` → `.claude/agents/`
- `extract-v1-contract.md`, `parity-test-generate.md`, `perf-uplift-survey.md` → `.claude/skills/`
- All commands → `.claude/commands/`
- `validate-migration-artifacts.sh` → `~/.claude/scripts/` (user installs once globally)

### OpenCode (`AGENTS.md` + `.opencode/`)
- Rule's contents inlined into `AGENTS.md` migration section + linked from `.opencode/`
- Agents → `.opencode/agents/parity-auditor.md`, `.opencode/agents/migration-architect.md`
- Skills → `.opencode/skills/extract-v1-contract/SKILL.md`, etc.
- Commands → `.opencode/commands/migration-phase.md`, etc.

### Cursor (`.cursor/`)
- Rule → `.cursor/rules/migration-discipline.mdc` (with frontmatter `globs: ai/migration/**`)
- Skills → `.cursor/skills/extract-v1-contract/SKILL.md`, etc.
- Commands → `.cursor/commands/migration-phase.md`, etc.
- Hooks → `.cursor/hooks.json` triggering `validate-migration-artifacts.sh` on file edits in `ai/migration/`
- Agents are **convention-only** in Cursor; document them in the rule prose.

### Copilot (`.github/`)
- Rule → `.github/instructions/migration-discipline.instructions.md`
- Agents → `.github/agents/parity-auditor.agent.md`, `.github/agents/migration-architect.agent.md`
- Skills → `.github/skills/extract-v1-contract/SKILL.md`, etc.
- Commands → `.github/prompts/migration-phase.prompt.md`, etc.
- Or `chatmodes/` for sub-agent-style chat modes

### Continue (`.continue/`)
- Rule → `.continue/rules/migration-discipline.md`
- Skills → expressed as prompts in `.continue/prompts/extract-v1-contract.md` (Continue treats skills as prompt templates)
- Commands → `.continue/prompts/migration-phase.md`, etc.
- Agents → convention-only; document in rule prose

### Cline (`.clinerules/`) and Windsurf (`.windsurf/`)
- Rule → `.clinerules/migration-discipline.md` / `.windsurf/rules/migration-discipline.md`
- Commands → `.clinerules/workflows/migration-phase.md` / `.windsurf/workflows/migration-phase.md`
- **Agents + skills NOT supported natively.** Their content (parity-auditor's hard halts, extract-v1-contract's procedure, etc.) MUST be inlined into the rule. The self-sufficient rule already does this.

### Aider (`CONVENTIONS.md`)
- Rule → appended to `CONVENTIONS.md` under a `## Migration discipline` section
- **No commands, no agents, no skills.** Aider relies entirely on the rule for migration discipline.
- Aider users invoke procedures by reading the rule's "Tool-agnostic procedure" section and following it manually.
- The validator script `validate-migration-artifacts.sh` is the only callable verifier — Aider users run it from the shell or as a pre-commit hook.

### Codex (`AGENTS.md` + `~/.codex/config.toml`)
- Rule → `AGENTS.md` migration section
- Agents are convention-only; document in `AGENTS.md`
- Same rule-only fallback as Aider for the procedural surface

### Gemini CLI (`GEMINI.md`)
- Rule → `GEMINI.md` migration section
- **Rule-only tool.** Same as Aider/Codex.

## Validator script — universal callable

`scripts/validate-migration-artifacts.sh` is callable from any tool's hook system or directly from the shell. Setup per tool:

| Tool | Hook integration |
|---|---|
| Claude Code | `.claude/settings.json` PostToolUse hook on edits to `ai/migration/**` |
| Cursor | `.cursor/hooks.json` `onSave` for `ai/migration/**` |
| Copilot | GitHub Actions workflow (no native pre-commit) |
| Other (Aider, Codex, Gemini, etc.) | Pre-commit hook in `.git/hooks/pre-commit` (manual install) OR CI workflow |

The script returns non-zero on any failure; tool integrations should treat that as a blocking error.

## Adapter responsibilities

When an adapter ships the migration pack:

1. **MUST translate the rule** (`migration-discipline.md`) faithfully — including the inlined 9 contract sections, 10 hard halts, frontend axes, anti-pattern catalogue, and tool-agnostic procedures. Do NOT abridge.
2. **MUST translate or document agents/skills/commands** to the tool's native format if supported. If not supported, document in the rule's "References" section that the procedural detail is inlined.
3. **MUST install or document `validate-migration-artifacts.sh`** as a pre-commit / CI / hook integration.
4. **MUST translate `port-feature.md`** as the per-feature orchestrator (or its 6-phase procedure inlined).
5. **MUST NOT silently drop the migration pack on tools with limited capability.** A rule-only tool gets the rule (which is sufficient).

## Failure mode protections

The F039-class failures (Trusted Summary, Hand-waved Query Param, Optimistic Form Field Match, etc.) catalogued in `_examples/audit-failure-modes.md` are pattern-recognised by the validator script. The script flags hand-wave tokens in audit files, missing contract sections, undersized corpus, and missing artifacts — regardless of which tool produced the artifacts.

This means: a Cursor user, a Copilot user, an Aider user, and a Claude Code user all get the same enforcement floor when they run the validator. The discipline is universal; the tool surface is per-adapter convenience.
