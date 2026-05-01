# Tool adapters

This directory holds per-tool adapter specs for `/setup-project`. Each adapter knows:

1. **Where** a tool reads its project config from (e.g. Cursor reads `.cursor/rules/*.mdc`).
2. **What format** that config uses (markdown, YAML, JSON, MDC with frontmatter).
3. **How** to translate our canonical rule/instruction set into that tool's native format.
4. **Capability scope** — which features the tool supports (rules/agents/commands/hooks).

## The adapter list

The single source of truth for which adapters exist + their capabilities is `_registry.md` in this folder. The list below is a quick reference; for the live count and capability matrix, read `_registry.md`. `scripts/lint-tool-parity.sh` enforces consistency between this README, `_registry.md`, and `tool-parity.md`.

| Tool | Folder | Native config |
|---|---|---|
| Claude Code | `claude-code/` | `.claude/` + `CLAUDE.md` |
| OpenCode | `opencode/` | `AGENTS.md` + `opencode.json` |
| Cursor | `cursor/` | `.cursor/rules/*.mdc` |
| Aider | `aider/` | `.aider.conf.yml` + `CONVENTIONS.md` |
| Continue.dev | `continue/` | `.continue/config.yaml` + `.continue/rules/*.md` |
| Cline / Roo | `cline/` | `.clinerules/*.md` |
| Windsurf | `windsurf/` | `.windsurf/rules/*.md` |
| GitHub Copilot | `copilot/` | `.github/copilot-instructions.md` + `.github/instructions/*.instructions.md` |
| Codex (OpenAI) | `codex/` | `AGENTS.md` + `~/.codex/config.toml` |
| Gemini CLI | `gemini/` | `GEMINI.md` |

## The universal anchor: AGENTS.md

`AGENTS.md` at repo root is the de-facto cross-tool standard. The majority of adapters in `_registry.md` consume it as primary or fallback (Codex, Cursor, Aider, Amp, Cline, Copilot, Windsurf, OpenCode). When `/setup-project` runs, it always writes `AGENTS.md` via the `codex` adapter — every other adapter refines from there. The exact "consumes-AGENTS.md" count is encoded in `_registry.md`; this prose intentionally avoids a number to prevent drift.

Claude Code reads `CLAUDE.md` (superset) + `.claude/`.
Gemini CLI reads `GEMINI.md`.

## How adapters compose (defense in depth)

When multiple tools are selected for one repo, the outputs coexist without conflict:

```
repo-root/
├── AGENTS.md                                  ← universal (Codex, Cursor fallback, Amp, Cline, OpenCode, ...)
├── CLAUDE.md                                  ← Claude Code (superset of AGENTS.md)
├── GEMINI.md                                  ← Gemini CLI
├── CONVENTIONS.md                             ← Aider reads via .aider.conf.yml
├── .claude/{agents,skills,commands,rules,hooks}/  ← Claude Code (full native surface)
├── .cursor/                                   ← Cursor (≥ 2.3 — native skills + commands + hooks)
│   ├── rules/*.mdc
│   ├── skills/<name>/SKILL.md
│   ├── commands/<name>.md
│   └── hooks.json
├── .opencode/                                 ← OpenCode (native agents + commands + skills folders)
│   ├── agents/<name>.md
│   ├── commands/<name>.md
│   └── skills/<name>/SKILL.md
├── .continue/                                 ← Continue.dev (native prompts as files)
│   ├── config.yaml
│   ├── rules/*.md
│   └── prompts/*.md
├── .clinerules/                               ← Cline / Roo (workflows = native slash commands)
│   ├── *.md
│   └── workflows/<name>.md
├── .windsurf/                                 ← Windsurf (workflows = native slash commands)
│   ├── rules/*.md
│   └── workflows/<name>.md
├── .github/                                   ← Copilot (native agents/skills/prompts/chatmodes)
│   ├── copilot-instructions.md
│   ├── instructions/*.instructions.md
│   ├── prompts/*.prompt.md
│   ├── agents/*.agent.md
│   ├── skills/<name>/SKILL.md
│   └── chatmodes/*.chatmode.md
├── .aider.conf.yml                            ← Aider (single-doc tool)
├── opencode.json                              ← OpenCode (provider config + instructions globs)
└── ai/                                        ← Universal knowledge base, referenced by all
```

**Standalone-tool guarantee**: each tool's section above is fully self-sufficient. A user opening this repo with only Cursor installed sees skills in Cursor's Skills picker, slash commands in chat, and hooks firing on edits — without `.claude/` being present. Same for OpenCode, Copilot, Cline, Windsurf, Continue. The `.claude/` folder is the canonical source for `setup-project`, but downstream tools never have to read it.

## The translation surface (Apr 2026)

Each tool gets the artifacts mapped to its **own native folder structure** so the tool works standalone, without depending on Claude reading `.claude/`. When a tool has no native equivalent, the adapter falls back to a documented translation that the tool can still consume.

| Capability | Source | Native targets (where supported) | Translated targets |
|---|---|---|---|
| Rules (prose instructions) | `.claude/rules/*.md` | Every tool's native rule folder | n/a (universal) |
| Agents (specialized personas) | `.claude/agents/*.md` | Claude Code, OpenCode (`.opencode/agents/`), Copilot (`.github/agents/`) | Cursor / Continue (as commands), Cline / Windsurf (index file), Aider / Codex / Gemini (AGENTS.md section) |
| Skills (scripted procedures) | `.claude/skills/<name>/SKILL.md` | Claude Code, Cursor (`.cursor/skills/`), OpenCode (`.opencode/skills/`), Copilot (`.github/skills/`) | Continue (as prompts), Cline / Windsurf (index file), Aider / Codex / Gemini (runbook section) |
| Commands (slash commands) | `.claude/commands/*.md` | Claude Code, Cursor (`.cursor/commands/`), OpenCode (`.opencode/commands/`), Cline (`.clinerules/workflows/`), Windsurf (`.windsurf/workflows/`), Copilot (`.github/prompts/`), Continue (`.continue/prompts/` `invokable:true`) | Aider / Codex / Gemini (AGENTS.md section) |
| Hooks (lifecycle shell scripts) | `.claude/hooks/*.sh` | Claude Code, Cursor (`.cursor/hooks.json`) | Husky git hooks + `applyTo` advise rules + `ai/status.md` briefing |
| `ai/` knowledge base | Universal | All tools — every adapter references it | n/a |

> **Drift policy**: when a tool ships a new native primitive (e.g. Cursor 2.3 added `.cursor/skills/`, Apr 2026 → Copilot Agent Skills GA), the corresponding adapter's `adapter.md` (the canonical translation contract) records the new native path; Phase 4.8 / 4.8-DEEP migrate on `--refresh`. Adapter `_version.json` tracks the last-verified tool version. (A per-adapter `_translate.md` sidecar for richer surface tracking is `[PLANNED]` — not yet shipped.)

## How `/setup-project` uses these adapters

Command logic (see `~/.claude/commands/setup-project.md` Phase 3.2):

1. **Detect driver set** — from `--tools` flag, auto-detect existing configs, or ask.
2. **Always generate `AGENTS.md`** + `CLAUDE.md` (Claude Code is the canonical source, even if Claude Code isn't in the driver set).
3. **For each selected tool**, run its adapter to produce its native config. Adapters are idempotent — re-running updates without clobbering user additions.
4. **Cross-link** — each tool's config starts with a pointer to `ai/` + `AGENTS.md` for canonical context.

## Auto-detection heuristics

When `--tools` is not passed, auto-detect from the repo:

| Signal | Tool added |
|---|---|
| `.claude/` exists | Claude Code |
| `opencode.json` or `AGENTS.md` exists | OpenCode (if AGENTS.md mentions OpenCode) or Codex |
| `.cursor/` or `.cursorrules` exists | Cursor |
| `.aider.conf.yml` or `.aiderignore` exists | Aider |
| `.continue/` exists | Continue.dev |
| `.clinerules/` or `.clinerules` exists | Cline |
| `.windsurf/` or `.windsurfrules` exists | Windsurf |
| `.github/copilot-instructions.md` exists | Copilot |
| `GEMINI.md` exists | Gemini CLI |
| No AI config detected | Default: Claude Code + AGENTS.md |

## Missing-tool mode

When enhance-mode detects a project uses a tool whose adapter is missing:
- If an adapter exists in this directory → run it to add the missing config.
- If no adapter exists → warn user with a one-liner: "Detected X, no adapter available. Contribute one at `~/.claude/templates/tool-adapters/<name>/`."

See individual `<tool>/adapter.md` files for each tool's translation spec.
