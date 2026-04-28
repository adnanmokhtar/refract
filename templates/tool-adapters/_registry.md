# Tool adapter capability matrix

Single-source registry of what each adapter produces and which capabilities it covers. `/setup-project` reads this to decide what to generate when a tool is selected.

## Capability legend

- **R** = Rules / instructions (prose guidance — every tool supports this)
- **A** = Agents (specialized personas with their own system prompts)
- **S** = Skills (scripted procedures the tool can invoke)
- **C** = Slash commands / custom prompts
- **H** = Hooks (lifecycle shell scripts: PreToolUse, PostToolUse, Stop, SessionStart)
- **N** = Nested/path-scoped rules (different rules for different subfolders)

## Registry

| Tool | Key | R | A | S | C | H | N | Primary files written |
|---|---|---|---|---|---|---|---|---|
| Claude Code | `claude-code` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | `.claude/*`, `CLAUDE.md` |
| OpenCode | `opencode` | ✓ | ✓ | ✓ | ✓ | — | — | `AGENTS.md`, `opencode.json`, `.opencode/agents/*.md`, `.opencode/commands/*.md`, `.opencode/skills/<name>/SKILL.md` |
| Cursor | `cursor` | ✓ | ~ | ✓ | ✓ | ✓ | ✓ | `.cursor/rules/*.mdc`, `.cursor/skills/<name>/SKILL.md`, `.cursor/commands/*.md`, `.cursor/hooks.json`, `AGENTS.md` |
| Aider | `aider` | ✓ | — | — | — | — | — | `.aider.conf.yml`, `CONVENTIONS.md` |
| Continue.dev | `continue` | ✓ | ~ | ~ | ✓ | — | — | `.continue/config.yaml`, `.continue/rules/*.md`, `.continue/prompts/*.md` |
| Cline / Roo | `cline` | ✓ | — | — | ✓ | — | — | `.clinerules/*.md`, `.clinerules/workflows/*.md` |
| Windsurf | `windsurf` | ✓ | — | — | ✓ | — | — | `.windsurf/rules/*.md`, `.windsurf/workflows/*.md` |
| GitHub Copilot | `copilot` | ✓ | ✓ | ✓ | ✓ | — | ✓ | `.github/copilot-instructions.md`, `.github/instructions/*.instructions.md`, `.github/agents/*.agent.md`, `.github/skills/<name>/SKILL.md`, `.github/prompts/*.prompt.md`, `.github/chatmodes/*.chatmode.md` |
| Codex (OpenAI) | `codex` | ✓ | ~ | — | — | — | ✓ | `AGENTS.md`, optional `AGENTS.override.md` |
| Gemini CLI | `gemini` | ✓ | — | — | — | — | — | `GEMINI.md` |

Legend:
- ✓ = first-class support
- ~ = partial / convention-based (e.g. "agents" documented in prose but no tool-managed dispatch)
- — = not supported
- † = behavior reported but version-dependent — verify against the tool's current docs

## Standalone-tool guarantee

Each adapter's output MUST let the tool work end-to-end **without `.claude/` present**. If a tool natively supports skills / commands / agents / hooks, the adapter writes those into the tool's native folder (e.g. `.cursor/skills/<name>/SKILL.md`, `.opencode/commands/<name>.md`, `.github/agents/<name>.agent.md`). It does NOT cram everything into the tool's rules folder with prefixes. If a tool has no native equivalent for a Claude artifact (e.g. Cline has no agent dispatch), the adapter falls back to a documented translation that the tool can still consume on its own.

The `_translate.md` file under each `<adapter>/` folder records the tool's native surface as of the last verification date; Phase 4.8 / 4.8-DEEP read it to decide where to write each artifact.

## Universal baseline (always written, regardless of tool selection)

- `AGENTS.md` at repo root — the cross-tool canonical. The codex adapter is the canonical writer; every other adapter that consumes AGENTS.md is marked in the registry table above.
- `ai/` knowledge base — referenced by every adapter via a pointer at the top of its generated config.

## Driver selection logic (for `/setup-project`)

1. User passes `--tools claude-code,cursor,aider` → use that list.
2. User passes `--tools auto` (or omits) → run auto-detection heuristics (see `README.md`).
3. No signal at all → default to `claude-code` + universal `AGENTS.md`.

## When a driver is added later

Enhance-mode detects signals (e.g. `.cursor/` folder appears after a prior setup). Next run offers: "Detected Cursor. Add Cursor adapter? [y/n]". On yes, run the adapter.

## When Claude Code is NOT in the driver set

Even without Claude Code selected, the Claude Code adapter runs **partially** to produce the canonical `CLAUDE.md` (because CLAUDE.md is a superset of AGENTS.md and other tools can read it as fallback). `.claude/` subdirectories are skipped.

## Adapter file shape (every `<tool>/adapter.md`)

1. **Target files** — exact paths relative to repo root.
2. **File formats** — markdown flavor, frontmatter schema, JSON/YAML keys.
3. **Translation recipe** — how to render `.claude/rules/*.md` + `ai/` references into the tool's native format.
4. **Idempotency** — how to detect + update without clobbering user edits (usually: delimiter comments or dedicated top-of-file section).
5. **Known gotchas** — character limits, ordering constraints, activation triggers.
6. **Sample output** — a small worked example of what the generator emits.
