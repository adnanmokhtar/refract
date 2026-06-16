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
| Kimi Code (Moonshot) | `kimi` | ✓ | ~ | ✓ | — | ✓ | — | `.kimi/skills/<name>/SKILL.md`, `.kimi/subagents/<name>.yaml`, `AGENTS.md` (consumed) |
| Qwen Code (Alibaba) | `qwen` | ✓ | ✓ | ✓ | ✓ | ✓ | — | `QWEN.md`, `.qwen/settings.json`, `.qwen/commands/*.md`, `.qwen/agents/<name>.md`, `.qwen/skills/<name>/SKILL.md`, `AGENTS.md` (consumed) |

Legend:
- ✓ = first-class support
- ~ = partial / convention-based (e.g. "agents" documented in prose but no tool-managed dispatch)
- — = not supported
- † = behavior reported but version-dependent — verify against the tool's current docs

## Command translation — does invoking a translated `/<command>` actually EXECUTE?

The C column above marks whether each tool has a NATIVE command primitive. That's necessary but not sufficient — the adapter must also translate `commands/*.md` into the **right kind of primitive** for the tool. The wrong choice (e.g., routing an action command into a passive "reference skill") makes invocation load a document and ask the user "what now?" instead of running.

Verdict per adapter (refreshed 2026-05-14, verified against official docs):

| Tool | Primitive used for action commands (`/optimize`, `/migrate`, ...) | Verdict | Notes |
|---|---|---|---|
| Claude Code | `.claude/commands/<name>.md` (native slash command) | ✅ Executes | Source of truth — slash commands ARE the native action primitive. |
| OpenCode | `.opencode/commands/<name>.md` with frontmatter **`agent: build`** | ✅ Executes | `agent: build` REQUIRED for full tool access (read+write+shell). Without it, command routes to Plan/Chat mode and can't edit files. |
| Qwen | `.qwen/commands/<name>.md` (Markdown w/ optional YAML frontmatter — current) | ✅ Executes | Markdown is the canonical format as of 2026-05. Legacy TOML still supported for backwards compat (recent TOML→Markdown migration). |
| **Cursor** | **`.cursor/skills/<name>/SKILL.md`** (PRIMARY, since Cursor 2.3+) — `.cursor/commands/<name>.md` legacy fallback | ✅ Executes | Cursor migrated off slash commands to Skills; `/migrate-to-skills` is a built-in conversion command. Skills appear as `/<skill-name>` slash AND auto-match by description. New projects MUST generate skills. |
| Continue.dev | `.continue/prompts/<name>.md` with frontmatter **`invokable: true`** | ✅ Executes | `invokable: true` REQUIRED or the prompt doesn't appear in the `/` picker. User MUST be in Agent mode (Chat / Plan / Agent toggle) for autonomous tool execution. |
| Copilot | `.github/prompts/<name>.prompt.md` with frontmatter **`mode: agent`** | ✅ Executes | `mode: agent` REQUIRED for tool loop; `mode: ask` answers without tools, `mode: edit` edits files but no shell. |
| **Cline** | **`.cline/skills/<name>/SKILL.md`** (PRIMARY, also reads `.claude/skills/`) — `.clinerules/workflows/<name>.md` legacy fallback | ✅ Executes | Cline merged workflows into Skills (workflows docs page now 404s). Auto-discovers from `.cline/skills/`, `.clinerules/skills/`, AND `.claude/skills/` directly — adapter can share Claude Code skills. **Experimental — must enable in Settings → Features → Enable Skills.** |
| Windsurf | `.windsurf/workflows/<name>.md` (native Cascade workflow) | ✅ Executes | **Manual-invoke only** by design — Cascade NEVER auto-invokes workflows (perfect fit for `/optimize`-style user-dispatched commands). |
| **Kimi** | **PRIMARY: `.kimi/skills/<name>/SKILL.md` with `type: flow` + Mermaid diagram (Flow Skill → `/flow:<name>`)** — fallback: regular skill with EXECUTE NOW preamble (`/skill:<name>`) | ✅ Executes (Flow Skill) / ⚠️ "contextual guidance" (regular skill) | Flow Skills are Kimi's only **explicit autonomous-execution** primitive — `/flow:<name>` walks BEGIN→END nodes. Regular `/skill:<name>` only injects body as "contextual guidance, not strict system prompt override" per docs — EXECUTE NOW preamble works in practice but isn't guaranteed. **Subagents (`.kimi/subagents/`) do NOT auto-discover** — they require declaration in a parent agent YAML's `subagents:` section. Orphan subagent files don't dispatch. |
| **Codex** | **`.agents/skills/<name>/SKILL.md`** (Open Agent Skills standard) | ✅ Executes | Codex implements the Open Agent Skills standard. Invocation: `/skills` picker, `$<name>` mention, OR auto-selection by description match. Skills list capped ~2% of context (~8K chars total across descriptions). No direct `/<name>` slash — goes through `/skills` or `$mention`. |
| **Gemini** | **`.gemini/commands/<name>.toml`** (TOML — required format) | ✅ Executes | Gemini CLI custom commands are TOML-only (NOT markdown). `prompt = """..."""` field carries the workflow body. Reload via `/commands reload`. Subdir namespacing via colons (`git/commit.toml` → `/git:commit`). |
| Aider | `CONVENTIONS.md § User-invoked procedures` (passive reference prose) | ⚠️ Executes via imperative preamble | Confirmed: closed slash set (`/add`, `/code`, `/architect`, etc.) — NO user-extensible primitive at any layer. Every translated command MUST start with "EXECUTE NOW" directive in second person. User invokes verbally. |

Verdict legend:
- ✅ = native action primitive — invocation executes the workflow autonomously
- ⚠️ = no executable primitive at any layer — adapter falls back to imperative-preamble reference prose; user must invoke verbally and the model self-directs

**Mandatory frontmatter / config fields per adapter** (most-missed by translators):
- **OpenCode**: `agent: build` on action commands
- **Continue**: `invokable: true` on action prompts
- **Copilot**: `mode: agent` on action prompts
- **Kimi (Flow Skill)**: `type: flow` in frontmatter + Mermaid/D2 diagram in body with `BEGIN` and `END` nodes
- **Codex (Agent Skill)**: `name` and `description` required (per Open Agent Skills standard)
- **Gemini**: TOML format with `description` and `prompt` fields (no markdown)

**Translation contract for future adapters**: a new adapter MUST declare in its `adapter.md` which primitive it uses for `commands/*.md` AND justify the choice in one paragraph against this matrix. PRs that route commands to a passive primitive when an executable one exists are rejected.

**Doc-verified anti-claims** (corrected 2026-05-14 after reading official docs):
- "Codex has no executable primitive" — **FALSE**; Codex has Agent Skills (`.agents/skills/`).
- "Gemini has no executable primitive" — **FALSE**; Gemini has TOML custom commands (`.gemini/commands/`).
- "Cursor commands are the modern primitive" — **FALSE**; Cursor migrated to Skills.
- "Cline uses workflows" — **STALE**; Cline merged workflows into Skills.
- "Kimi subagents auto-discover from `.kimi/subagents/`" — **FALSE**; subagents require parent-agent YAML registration.
- "Qwen uses TOML" — **STALE**; Qwen migrated TOML→Markdown.
- "Gemini uses Markdown" — **FALSE**; Gemini is TOML-only (NOT the same as Qwen despite shared upstream).

## Top-level orchestration commands (Claude-Code-only — by design)

The 12 commands at this repo's `commands/` are split into two groups:

| Group | Commands | Adapter coverage |
|---|---|---|
| **Setup family** (translatable) | `/setup-project`, `/setup-project-adapters`, `/setup-project-health`, `/scaffold-project`, `/refine-prompt`, `/learn-from-task` | Each adapter MAY surface these as its own slash command / prompt / instruction file. Optional — these commands also run end-to-end inside Claude Code and produce per-adapter outputs as a side effect. |
| **Integration commands** (translatable, **MCP-backed**) | `/task` | **Translated to every adapter that can reach a task-provider MCP** (Trello / Jira / Linear / GitHub). `/task` is NOT a parallel-sub-agent command — it is a single-task lifecycle (fetch → normalize → dispatch → write-back), so it ports cleanly. The ONE substitution: where Claude's `/task` routes execution through `/do`, each adapter routes through **its own native dispatch** (the tool's specialist commands/skills translated via `_<pack>-pack-coverage.md`) — `/do` itself stays Claude-only. Per-tool primitive + MCP requirement + degradation path live in **`_task-integration-coverage.md`**. Tools with no MCP and no executable primitive (Aider) fall back to an EXECUTE-NOW preamble that fetches via the provider CLI/API. |
| **Simple-surface multi-agent** (Claude-only as native commands) | `/migrate`, `/align`, `/optimize`, `/refactor`, `/polish`, `/audit`, `/unify-surfaces`, `/do` | **Not translated to other adapters as slash commands.** These commands depend on Claude Code's parallel sub-agent dispatch — no other tool ships an equivalent primitive. Other tools have two equivalent paths: (a) call the underlying pack commands directly (`/migration-fast 1`, `/align-fast 2`, `find-and-fix <id>`, `/security-audit`, `/perf-audit`, `/db-audit`, `/design-system <feature>`) which DO have per-adapter translations via `_<pack>-pack-coverage.md`; OR (b) use the **parallel orchestrator scripts** (see below) that fan out N parallel CLI processes externally — closes the gap without needing the tool to add the primitive. **`/audit`** specifically fans out across 8 specialist axes (architecture / SOLID / security / DB / perf / scale-resilience / infra / observability) and cross-axis ranks; rule-only tools approximate it by running `/security-audit` + `/db-audit` + `/perf-audit` + `/design-system` sequentially and merging findings by hand. |

This is a deliberate split, not adapter drift. Any future adapter that gains parallel-agent dispatch becomes a candidate to add the simple-surface group as native slash commands.

**Adapter sync:** When documenting validators, hooks, or canonical `ai/` paths in any **`templates/tool-adapters/<tool>/adapter.md`**, cross-reference **`templates/tool-adapters/_orchestration-sync.md`** so Codex / Cursor / rule-only tools stay aligned with `commands/*.md` (migrate progress exception, optimize oracle fallbacks, align 21-verb vocabulary, polish `QUIET` env, `/refactor` vs inventory flags).

### Parallel orchestrator scripts (close the gap externally)

For tools without native parallel sub-agent dispatch (Kimi, Aider, Codex, OpenCode partially), the repo ships shell-script orchestrators at `scripts/*-parallel.sh` that fan out per-row CLI invocations. Each worker is a separate headless tool process; coordination is via the ledger file with file locks. **`parallel-fan-out.sh`** wraps workers and **flocks** a ledger file — pass **`--ledger=ai/<pack>/ledger.md`** so the lock matches the pack (default remains `ai/migration/ledger.md` when omitted); `LEDGER_LOCK=""` disables flock. Wrapper scripts (`migrate-parallel.sh`, `optimize-parallel.sh`, etc.) forward **`--ledger`** automatically. **`migrate-parallel.sh`** / **`optimize-parallel.sh`** parse fenced YAML rows beginning with **`id: <token>`** plus **`status:`** / **`state:`**.

| Script | Mirrors | Reads ledger |
|---|---|---|
| `migrate-parallel.sh` | `/migrate` | `ai/migration/ledger.md` |
| `align-parallel.sh` | `/align` | `ai/align/ledger.md` |
| `optimize-parallel.sh` | `/optimize` | `ai/optimize/ledger.md` |
| `polish-parallel.sh` | `/polish` | `ai/polish/ledger.md` |
| `audit-parallel.sh --pack=<name>` | `/security-audit`, `/perf-audit`, `/i18n-audit`, `/a11y-audit`, `/db-audit`, `/ui-sweep` | `ai/<pack>/ledger.md` |
| `unify-surfaces-parallel.sh` *(planned)* | `/unify-surfaces` | `ai/unify-surfaces/progress.md` (per-category fan-out — buttons / headers / tabs / forms / tables / filters / validation; respects category dependency edges) |

Tool support (per `_parallel-tool-config.sh`): kimi, qwen, aider, opencode, codex, claude. Adding a new tool = one function in the config file. Adapter responsibility: ensure the chosen tool ships a headless / non-interactive invocation flag (verified per-tool: `kimi --headless --prompt`, `qwen -p`, `aider --message --no-stream --yes`, `opencode run`, `codex exec`, `claude --print`).

Adapters with no headless mode (Cursor, Cline, Windsurf — IDE-bound) cannot be drivers for parallel orchestrators. Their users either run the underlying pack commands serially OR switch tools for the whole-project sweep step.

## Standalone-tool guarantee

Each adapter's output MUST let the tool work end-to-end **without `.claude/` present**. If a tool natively supports skills / commands / agents / hooks, the adapter writes those into the tool's native folder (e.g. `.cursor/skills/<name>/SKILL.md`, `.opencode/commands/<name>.md`, `.github/agents/<name>.agent.md`). It does NOT cram everything into the tool's rules folder with prefixes. If a tool has no native equivalent for a Claude artifact (e.g. Cline has no agent dispatch), the adapter falls back to a documented translation that the tool can still consume on its own.

**Translation contract** lives in each `<adapter>/adapter.md` (the 4 mandatory sections: Target files / File formats / Idempotency / Full artifact translation). A per-adapter `_translate.md` sidecar is `[PLANNED]` for richer per-tool surface tracking — not yet shipped; `adapter.md` is the canonical contract Phase 4.8 / 4.8-DEEP consume.

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

## Maintaining pack templates (claude-config repo)

Editing `templates/packs/**` or `commands/` in this repository triggers Phase 5 checks (`audit-stack-leakage.sh`, `audit-command-dry.sh`). Canonical discipline links: **`_template-author-scripts.md`**.
