# Tool parity — what works in each driver

**The honest matrix.** Claude Code is the richest driver (rules + commands + agents + skills + hooks). Other tools cover a subset. This doc records what's **natively supported**, what's **translated** (made to work via rules/prompts), and what's **fundamentally not possible** per tool.

Key question this answers: when I run the project in Cursor (or OpenCode, or Cline, etc.), which Claude Code features do I actually get?

## Legend

- **✅ native** — first-class support; tool runs the artifact the way Claude Code does.
- **~ translated** — the artifact is re-expressed in the tool's rules/prompts so a user can invoke it (manual trigger; no auto-dispatch).
- **❌ not possible** — fundamental capability gap; fallback documented below the table.

## Parity matrix

| Capability | Claude Code | OpenCode | Cursor | Aider | Continue.dev | Cline/Roo | Windsurf | Copilot | Codex | Gemini CLI |
|---|---|---|---|---|---|---|---|---|---|---|
| **Rules** (project instructions) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Path-scoped rules (globs) | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ | ~ (nested) | ❌ |
| **Commands** (user-invoked `/<name>`) | ✅ | ✅ (`.opencode/commands/`) | ✅ (`.cursor/commands/` ≥ 2.3) | ❌ | ✅ (`.continue/prompts/` `invokable:true`) | ✅ (`.clinerules/workflows/`) | ✅ (`.windsurf/workflows/`) | ✅ (`.github/prompts/`) | ❌ | ❌ |
| **Agents** (specialized personas) | ✅ (auto-dispatch) | ✅ (`.opencode/agents/`) | ~ (as commands) | ❌ | ~ (as prompts) | ❌ (index file) | ~ (trigger_words rules) | ✅ (`.github/agents/`) | ❌ | ❌ |
| Agent auto-routing (no manual invoke) | ✅ | ~ (intent-match) | ❌ | ❌ | ❌ | ❌ | ~ (trigger_words) | ~ (skill-match) | ❌ | ❌ |
| **Skills** (scripted procedures) | ✅ | ✅ (`.opencode/skills/<name>/`) | ✅ (`.cursor/skills/<name>/` ≥ 2.3) | ❌ | ~ (as prompts) | ❌ (index file) | ❌ (index file) | ✅ (`.github/skills/<name>/`) | ❌ | ❌ |
| **Hooks** (lifecycle shell scripts) | ✅ | ❌ | ✅ (`.cursor/hooks.json` ≥ 2.3) | ~ (lint-cmd, test-cmd) | ❌ | ❌ | ❌ | ~ (instructions advise) | ❌ | ❌ |
| **Knowledge base** (`ai/` reference) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Model routing** (non-default provider) | ✅ (via `ANTHROPIC_BASE_URL`) | ✅ (`opencode.json`) | ✅ (UI BYOK) | ✅ (LiteLLM) | ✅ (`models:`) | ✅ (UI) | ~ (hosted only) | ~ (hosted only) | ~ (via proxy) | ✅ (flags) |

**As of Apr 2026**, the matrix above promotes Commands / Skills / Hooks for Cursor (2.3+), OpenCode, Copilot (Agent Skills GA), Cline (workflows), Windsurf (workflows), and Continue (prompts) from `~ translated` to `✅ native`. Older versions of those tools may not have these primitives — `setup-project --refresh --tools=<name>` re-emits in the current native shape; keep legacy artifacts as harmless fallbacks until the user runs `--refresh`.

## What "native" means per capability (Apr 2026)

### Commands → native folder per tool

Claude Code: `.claude/commands/<name>.md` is auto-loaded; user types `/<name>` and Claude executes it.

Other tools (native — same UX as Claude):
- **Cursor (≥ 2.3)**: `.cursor/commands/<name>.md` — typing `/<name>` in chat invokes it directly. No prefix.
- **OpenCode**: `.opencode/commands/<name>.md` — same.
- **Cline**: `.clinerules/workflows/<name>.md` — typing `/<name>` invokes the workflow.
- **Windsurf**: `.windsurf/workflows/<name>.md` — same as Cline.
- **Copilot**: `.github/prompts/<name>.prompt.md` — picker + slash command in Copilot Chat.
- **Continue**: `.continue/prompts/<name>.md` with `invokable: true` frontmatter — slash command in chat.

Translated (no native equivalent):
- **Aider / Codex / Gemini**: embed as named section in CONVENTIONS.md / AGENTS.md / GEMINI.md; user copies the prompt manually. No slash command UX.

### Agents → native folder where the tool supports it

Claude Code: an agent has its own system prompt + tool set + model. Claude can delegate to it automatically.

Native:
- **OpenCode**: `.opencode/agents/<name>.md` — frontmatter declares mode/model/tools; `@<name>` mention switches persona in chat.
- **Copilot**: `.github/agents/<name>.agent.md` — surfaced in Copilot's agent picker.

Translated (no native dispatch):
- **Cursor**: `.cursor/commands/agent-<name>.md` — invoked as `/agent-<name>`.
- **Continue**: `.continue/prompts/agent-<name>.md` — invoked from prompts picker.
- **Windsurf**: rule with `activation_mode: trigger_words` — closest to auto-dispatch.
- **Cline**: section in `.clinerules/81-agents.md` — user explicitly invokes ("act as the backend-reviewer").
- **Aider / Codex / Gemini**: section in CONVENTIONS.md / AGENTS.md / GEMINI.md.

> **Auto-routing reality check**: Claude Code is the only tool with truly automatic agent dispatch (the model decides when to delegate). OpenCode and Copilot can intent-match a persona based on the user's prompt; the rest require explicit user invocation. The ✅ in the matrix above means "native folder for the persona definition" — not "auto-dispatch."

### Skills → native folder where the tool supports it

Claude Code: a skill bundles instructions + optional shell scripts. Claude loads the skill and can execute the shell steps via Bash tool.

Native (same shape as `.claude/skills/<name>/SKILL.md`):
- **Cursor (≥ 2.3)**: `.cursor/skills/<name>/SKILL.md` — surfaced in Cursor's Skills picker.
- **OpenCode**: `.opencode/skills/<name>/SKILL.md` — repo-local; no symlink trick required.
- **Copilot**: `.github/skills/<name>/SKILL.md` — Agent Skills (GA Apr 2026), progressive disclosure based on description match.

Translated:
- **Continue**: `.continue/prompts/skill-<name>.md` — slash command, no auto-load.
- **Cline / Windsurf**: section in `.clinerules/82-skills.md` / `.windsurf/rules/82-skills.md`.
- **Aider / Codex / Gemini**: runbook-style section in CONVENTIONS.md / AGENTS.md / GEMINI.md.

### Hooks → native lifecycle config where the tool supports it

Claude Code has four lifecycle hooks: `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`.

Native:
- **Cursor (≥ 2.3)**: `.cursor/hooks.json` with events `beforeToolCall`, `afterToolCall`, `sessionStart`, `sessionEnd`. Maps directly to Claude's four hooks.

Translated (no native lifecycle):
- All others — fallbacks per purpose:

| Claude Code hook | Fallback for tools without native hooks |
|---|---|
| `PostToolUse` (lint after edit) | `.husky/` git hooks, `lint-staged`, IDE-level lint-on-save |
| `PreToolUse` (block edits to .env) | `.gitignore` + explicit rule + (Copilot) `applyTo: [".env*"]` advise rule |
| `SessionStart` (briefing) | Always-apply rule saying "read `ai/status.md` first" |
| `Stop` (session log) | Manual: ask user to periodically append to `ai/dynamic/session-log.md` |

**Important**: hooks are defense-in-depth automation. Replacing with manual discipline means the guardrail is softer. Projects that treat hook behavior as critical (e.g., never-commit-secrets) should enforce via git hooks + CI, not rely on the driver.

## Single-doc tool asymmetry (Aider / Codex / Gemini)

Some tools support **only one configuration document** by design — there's no per-artifact-type folder. `setup-project` adapts to that constraint by collapsing the four artifact types into named sections of the single doc:

| Tool | Single doc | What lives there |
|---|---|---|
| **Aider** | `CONVENTIONS.md` | Rules (top), Commands (`## Named procedures`), Agents (`## Personas`), Skills (`## Runbooks`), Hooks (advise-only — Aider has `lint-cmd` / `test-cmd` for two slots, the rest are documented) |
| **Codex** | `AGENTS.md` | Same sections; Codex reads `AGENTS.md` as the canonical instruction surface, and 8+ other tools also read it as fallback (the cross-tool portability win) |
| **Gemini CLI** | `GEMINI.md` | Either a thin pointer (`see AGENTS.md`) when AGENTS.md is also present, OR a self-contained variant when Gemini is the primary driver |

### What the asymmetry costs

- **No slash-command UX**: a user in Aider/Codex/Gemini can't type `/db-migration` and have the tool execute the command — they have to find the named section and copy the prompt manually. Native-folder tools (Cursor/OpenCode/Cline/Windsurf/Copilot/Continue) get true slash-command UX.
- **No agent picker**: personas in single-doc tools are documented sections, not selectable in a UI. The user prompts the model with "act as the backend-reviewer per § Personas".
- **No skills picker**: skills become runbook sections. The user reads the steps and asks the model to follow them — there's no "load skill X" verb.
- **No native hooks**: hook intent is documented as advise-only ("never edit `.env`"). Defense-in-depth requires git hooks (Husky) + CI as the actual enforcement layer.
- **Index density**: as a project grows past ~25 commands + ~15 agents + ~20 skills, the single-doc gets long (1500+ lines). `setup-project` mitigates with `## Quick index` at the top + intra-doc anchors, but readability degrades. Native-folder tools scale to 100+ artifacts without doc bloat.

### Why we still ship these adapters

- **Codex / AGENTS.md is a portability standard** — many tools (Aider, Cline, Cursor, Continue, Gemini, Copilot) read it as a fallback or supplementary signal. Emitting a high-quality `AGENTS.md` lets the project work in tools that don't have a first-class adapter.
- **Aider is terminal-first** — many users prefer it for speed/simplicity even at the cost of UX richness.
- **Gemini CLI is the only native Google ecosystem entry point** — Vertex AI / Google Cloud users have no other option.

### What `setup-project` does NOT promise for single-doc tools

- A user running `--refine` against a project where Aider is the *only* adapter selected gets a deepened `CONVENTIONS.md` with richer per-section anchoring — but they don't get new artifact types (because there's no folder to put them in). Phase 4.8-DEEP for these adapters re-translates the single doc; it doesn't promote translated artifacts to native folders (those folders don't exist).
- The setup-quality score for projects with ONLY a single-doc adapter selected is naturally capped by what the single doc can express. A score of 78 against `CONVENTIONS.md` is roughly equivalent to a score of 88 against `.cursor/{rules,skills,commands,hooks.json}/` — the score formula doesn't auto-adjust for this; reviewers should weight scores by adapter mix when comparing projects.

This is an **unavoidable asymmetry** rooted in tool design, not a bug in `setup-project`. It's documented here so users picking adapters can make an informed trade-off (UX richness vs. terminal/portability).

## Implications for which driver to use

**Use Claude Code when you want:**
- Auto-dispatched agents for different task types.
- Hook-enforced guardrails (can't edit `.env`, auto-lint on save, session-start briefing).
- Skills with executable shell steps.
- Richest pack of commands.

**Use OpenCode when you want:**
- Claude Code-like experience with wider model provider support.
- Keep your `~/.claude/skills/` without re-authoring.
- JSON-configurable instruction globs.

**Use Cursor when you want:**
- IDE-integrated editing with Claude/GPT/Gemini switching.
- Path-scoped rules (glob-based activation).
- The emerging AGENTS.md standard as primary signal.

**Use Aider when you want:**
- Terminal-only pair programming with any LiteLLM-supported model (incl. Kimi K2, DeepSeek, local Ollama).
- Minimal config; a single `CONVENTIONS.md` is enough.
- Strong git integration (auto-commits, per-edit diffs).

**Use Cline / Roo when you want:**
- VS Code-native experience with transparent tool-use tracking.
- No-agents, rules-only simplicity.

**Use Copilot when you want:**
- Deep GitHub integration; one-shot completions in VS Code.
- Path-scoped instructions via `.github/instructions/`.

**Use Codex (AGENTS.md) when you want:**
- Cross-tool portability — the `AGENTS.md` you write is read by 8+ other tools.
- Monorepo-aware nested AGENTS.md scoping.

**Use Gemini CLI when you want:**
- Google ecosystem (Vertex AI, Google Cloud) native routing.
- Lightweight one-file (`GEMINI.md`) setup.

**Use Windsurf when you want:**
- Cascade's proprietary agent orchestration (Codeium's hosted agent system).
- Trigger-word activation of rules.

## Gap disclosure — when project knowledge expects a driver feature the current tool lacks

If the project uses hooks for a critical purpose (e.g., `guard-destructive.sh` blocks `rm -rf`), tools without hooks silently lose that safety. The project's AGENTS.md must call this out explicitly:

```markdown
## Driver-dependent safety

This project uses Claude Code hooks to enforce:
- No writes to `.env*` files.
- No destructive bash without second-layer check.
- Auto-lint after every edit.

If you're running this project in Cursor / OpenCode / Cline / other: these guardrails are soft (documented but not enforced). Install a git pre-commit hook to partially cover the gap:

\`\`\`bash
# .husky/pre-commit (minimum)
pnpm lint
grep -rn 'console\.log\|TODO.*\(security\|auth\)' src/ && exit 1 || true
\`\`\`
```

## Keeping this doc current

Add a row to the parity matrix when:
- A new driver is added to the tool-adapters directory.
- A tool gains a new capability (e.g., Cursor adds hooks).
- A tool deprecates a feature (e.g., Windsurf replaces trigger-words with glob-only).

When updating, **verify each ✓/~/❌ against the tool's current published docs** (don't rely on what was true when this row was first written). Specific claims to re-verify periodically:

- OpenCode reading `~/.claude/skills/` globally — https://opencode.ai/docs/rules/
- Cline reading `.cursorrules`, `.windsurfrules`, `AGENTS.md` from repo root — https://docs.cline.bot/features/cline-rules
- Cursor frontmatter (`alwaysApply`, `globs`) keys + `.mdc` extension requirement — https://cursor.com/docs/context/rules
- Copilot's `.github/prompts/*.prompt.md` user-invoked behavior in VS Code vs github.com — https://docs.github.com/en/copilot/customizing-copilot/

This matrix is the reference `/setup-project` uses to decide what to emit per adapter. Drift between this doc and actual adapter behavior is a bug.
