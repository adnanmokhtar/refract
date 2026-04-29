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
