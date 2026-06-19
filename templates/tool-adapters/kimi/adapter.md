# Kimi Code adapter

**Tool:** Kimi Code (Moonshot AI) — terminal CLI + VS Code integration.
**Docs:** https://www.kimi.com/code/docs/en/
**Capabilities:** R (rules via skills + AGENTS.md fallback), S (native skills), H (native hooks via TOML), A (custom subagents via YAML), C (action commands via subagents — see § "Skills vs subagents — which primitive for what") — no native slash-command surface, no path-scoped rules.

> **Brand-group sibling.** Kimi shares the "brand directory" pattern with Claude Code and Codex: per the Skills doc, "Brand group (mutually exclusive): `~/.kimi/skills/`, `~/.claude/skills/`, or `~/.codex/skills/`." Project-level mirrors that: `.kimi/skills/`, `.claude/skills/`, `.codex/skills/`. Kimi's primary user surface is **skills + subagents** — there is no separate `/<command>` surface. **Custom subagents replace what Claude Code calls slash-command-driven agents** — and this distinction is load-bearing: subagents EXECUTE when invoked, skills LOAD as reference. The adapter MUST route `commands/*.md` (action-style workflows like `/optimize`, `/migrate`, `/polish`) to subagents, NOT to skills.

## Kimi primitives reference (verified against docs.kimi.com 2026-05-14)

Kimi has **THREE** primitives that touch the command-translation question, plus closed built-in slash commands:

1. **Regular Skills** — `.kimi/skills/<name>/SKILL.md`. Auto-discovered from `.kimi/skills/`. Invoked via Kimi's built-in `/skill:<name>` slash command (injects body as **prompt — "contextual guidance, not strict system prompt override"**, per docs). Bodies can be imperative; the AI may comply but Kimi explicitly does NOT guarantee execution semantics.

2. **Flow Skills** — same path, but `type: flow` in frontmatter PLUS an embedded **Mermaid or D2 diagram** in the body defining `BEGIN → ... → END` nodes. Invoked via Kimi's built-in `/flow:<name>` slash command which **autonomously walks the diagram from BEGIN to END**, executing each node. This is Kimi's **explicit autonomous-execution primitive** for multi-step workflows.

3. **Subagents** — `.kimi/subagents/<name>.yaml` is NOT auto-discovered by Kimi. Per docs, subagents must be **declared in a parent agent YAML** under a `subagents:` section with `path:` entries. There is **NO `/subagent:` or `/agent:` slash command** — subagent dispatch is only available via the main agent's `Agent` tool (natural-language description match). Subagents that aren't declared in a parent agent file are **orphans Kimi cannot dispatch**.

4. **Closed built-in slash set** — `/help`, `/skill:<name>`, `/flow:<name>`, `/login`, `/clear`, `/model`, `/theme`, `/sessions`, `/yolo`, `/plan`, `/mcp`, `/hooks`, `/usage`, `/init`, `/task`, `/btw`, `/web`, `/vis`, `/add-dir`, `/feedback`, `/changelog`, `/version`, `/import`, `/export`, `/compact`, `/debug`, `/reload`, `/new`, `/title`, `/undo`, `/fork`, `/editor`. Users **cannot** register new slash commands.

## Which primitive for which artifact

| Source artifact | Nature | Primary Kimi primitive | Why |
|---|---|---|---|
| `commands/*.md` action commands (`/optimize`, `/migrate`, `/polish`, etc.) | **Multi-step autonomous workflow** | **Flow Skill** at `.kimi/skills/<name>/SKILL.md` with `type: flow` + Mermaid/D2 diagram | `/flow:<name>` autonomously executes BEGIN→END. This is Kimi's only built-in primitive with **explicit execute-without-asking semantics**. |
| `commands/*.md` action commands — **fallback** when authoring a Flow diagram is too costly | Same | **Regular Skill** at `.kimi/skills/<name>/SKILL.md` with an "EXECUTE NOW" preamble at the top of the body | `/skill:<name>` loads body as prompt (contextual guidance, not strict). Preamble in second person makes the AI usually treat it as a directive, but Kimi's docs explicitly say loading is "contextual guidance" — execution is best-effort. |
| `skills/*.md` reference procedures (`extract-v1-contract`, `parity-test-generate`, `perf-uplift-survey`) | **Read when relevant** | **Regular Skill** at `.kimi/skills/<name>/SKILL.md`, no preamble | These ARE reference. Skills auto-discover; AI consults SKILL.md when description matches user's task. |
| `agents/*.md` personas (`parity-auditor`, `migration-architect`) | **Dispatched by main agent for a focused task** | **Subagent** at `.kimi/subagents/<name>.yaml` — **PLUS a parent-agent registration entry** | Subagents only work when declared in a parent `agent.yaml`. Orphan subagents in `.kimi/subagents/` are not discoverable by Kimi. The adapter MUST also write a parent agent file that lists every generated subagent. |
| `rules/*.md` (`migration-discipline`) | **Always-loaded guidance** | `AGENTS.md § Rules — <name>` + optionally a knowledge skill | Rules are reference. |

## Subagent registration (critical — easy to miss)

Subagent YAMLs at `.kimi/subagents/<name>.yaml` are **inert** without registration. Kimi does not auto-discover this directory. To make subagents dispatchable, the adapter MUST also write a parent agent YAML that declares them. Recommended location: `.kimi/agent.yaml` (or whichever path the project's `~/.kimi/config.toml` `agent_config:` field points at).

```yaml
# .kimi/agent.yaml — main agent for this project
version: 1
agent:
  extend: kimi:coder           # inherit built-in Coder behaviour
  description: "Main agent for <project>"

subagents:
  code-reviewer:
    path: ./.kimi/subagents/code-reviewer.yaml
    description: "Reviews code changes against project conventions"
  migration-architect:
    path: ./.kimi/subagents/migration-architect.yaml
    description: "Plans per-feature V1→V2 ports"
  # ... one entry per generated subagent
```

Without this file, **subagents do not work** — Kimi has no way to discover them. Pre-2026-05 adapter versions emitted subagent files without this registration and the result was orphan files. The validator's planned `check_kimi_subagent_registration` halts when subagent files exist but no parent agent declares them.

## When user types `/skill:optimize` vs `/flow:optimize` vs "run the optimize subagent"

| User typed | What Kimi does | Outcome |
|---|---|---|
| `/skill:optimize` (Flow Skill) | Loads SKILL.md body as prompt **without** walking the flow diagram | AI reads the body. May or may not execute — Flow Skills loaded this way are reference, not execution. |
| `/flow:optimize` (Flow Skill) | Walks BEGIN→END nodes, executing each step's prompt | **Autonomous execution** — Kimi's actual run-the-workflow semantic. |
| `/skill:optimize` (Regular Skill with EXECUTE NOW preamble) | Loads SKILL.md body as prompt | "Contextual guidance"; AI usually complies with imperative preamble but not guaranteed. |
| "run the optimize subagent" (subagent registered in parent agent) | Main agent uses `Agent` tool to dispatch | Executes in isolated context with subagent's `tools:` whitelist. |
| "run the optimize subagent" (subagent file exists but NOT registered) | Nothing — Kimi can't find it | Silent failure. |

**Recommendation hierarchy for action commands**:
1. **Best**: Flow Skill at `.kimi/skills/<name>/` with `type: flow` + Mermaid diagram → user invokes `/flow:<name>` → autonomous execution.
2. **Good**: Regular Skill with EXECUTE NOW preamble → user invokes `/skill:<name>` → usually executes (contextual guidance).
3. **For dispatched use**: Subagent + parent-agent registration → main agent dispatches via description match.

## Skills vs subagents — which primitive for what

This is the most-frequently-mis-translated rule for Kimi. Kimi has **two complementary primitives** for executable work — and action commands generate to **BOTH**, not just one:

| Source artifact | Nature | Kimi primitives generated | Why both |
|---|---|---|---|
| `.claude/commands/<name>.md` (e.g., `/optimize`, `/migrate`, `/polish`, `/align`, `/refactor`, `/audit`, `/unify-surfaces`) — note `/do` is **Claude-only** (simple-surface multi-agent router, not translated as a slash command per `_registry.md` § Top-level orchestration commands) | **Action** — user invokes, work happens | **BOTH** `.kimi/skills/<name>/SKILL.md` (with EXECUTE NOW preamble) **AND** `.kimi/subagents/<name>.yaml` (with the same preamble + tool whitelist) | Two invocation surfaces. `/skill:<name>` is Kimi's native built-in slash command that loads a named skill into context; the EXECUTE NOW preamble makes the loaded text imperative so the model executes instead of summarising. Subagents support description-based dispatch ("run optimize on src/") and provide tool whitelisting (`tools: read` for audit-only, etc.). Users pick whichever surface feels natural. |
| `.claude/skills/<name>/SKILL.md` (e.g., `extract-v1-contract`, `parity-test-generate`, `perf-uplift-survey`) | **Procedure / runbook** — read when relevant, follow steps | `.kimi/skills/<name>/SKILL.md` (no EXECUTE NOW preamble) | True reference procedures — they ARE supposed to load as documentation when context matches. No subagent generated. |
| `.claude/agents/<name>.md` (e.g., `parity-auditor`, `migration-architect`) | **Persona / reviewer** — main agent dispatches for a focused task | `.kimi/subagents/<name>.yaml` | Subagents handle agent-style dispatch; agents are not user-invoked directly. |
| `.claude/rules/<name>.md` (e.g., `migration-discipline`) | **Constraint / contract** — always-loaded guidance | `AGENTS.md § Rules` + optionally a knowledge skill at `.kimi/skills/<rule-name>/SKILL.md` | Rules are reference; project-memory is the right surface. |

**The EXECUTE NOW preamble** (mandatory for command-derived skills + subagents):

```markdown
<!-- EXECUTE NOW preamble — injected by migrate-kimi-commands. Do not edit this block. -->
> **Direct-invoke directive (read first when this skill loads, e.g. via `/skill:<name>`):**
>
> You are executing the `<name>` workflow. When this skill is loaded into context — by
> any means (`/skill:<name>`, agent dispatch, description match, or main agent request) —
> do NOT summarise the workflow below and ask the user what to do. Immediately begin
> executing against the scope the user named (default: the whole project if no scope given).
> Drive to completion or to an explicit halt; report results, not intent.
>
> This applies BEFORE the rest of the document. The body below is the workflow you execute.
<!-- /EXECUTE NOW preamble -->
```

For skills: prepend AFTER the frontmatter `---` close. For subagents: include at the top of `system_prompt:`.

**Failure modes this dual-surface rule prevents**:
- **"Loaded the manual, did nothing"** — pre-2026-05 adapter generated SKILL.md with no imperative preamble. User typed `/skill:optimize`, Kimi loaded the SKILL.md, treated it as documentation, asked "what now?" Fix: EXECUTE NOW preamble at top of every command-derived skill.
- **"Slash command not found"** — converting skills → subagents only (deleting skills) removes the `/skill:<name>` invocation surface entirely. Users who type `/skill:optimize` get nothing. Fix: keep skills AND add subagents.
- **"Untriggerable by description"** — a skill-only surface can't be dispatched by the main agent via description matching. Fix: subagent provides the dispatch surface.

**Migration script** for projects generated under the old single-surface rule: `scripts/migrate-kimi-commands-to-subagents.py` (creates subagents) + `scripts/kimi-restore-skills-with-preamble.py` (restores skills with preamble injected). Run both in order on each affected project.

> **Standalone-tool goal**: a project generated by `/setup-project` with the `kimi` adapter selected MUST work end-to-end in Kimi Code with **no `.claude/` present**. Skills land in `.kimi/skills/`; subagents in YAML files Kimi discovers; hooks in user-global `~/.kimi/config.toml`; project rules in `AGENTS.md` (cross-tool canonical) at repo root.

## Target files

```
repo-root/
├── .kimi/
│   ├── skills/                                # NATIVE — one folder per skill
│   │   └── <skill-name>/
│   │       ├── SKILL.md                       # Required — YAML frontmatter + Markdown body
│   │       ├── scripts/                       # Optional supporting scripts (copied verbatim)
│   │       ├── references/                    # Optional reference files (read by skill)
│   │       └── assets/                        # Optional binary assets
│   └── subagents/                             # YAML configs referenced by main agent
│       ├── <subagent-name>.yaml               # Custom subagent definition
│       └── README.md                          # How to wire (Kimi reads from main agent config)
├── AGENTS.md                                  # Project memory (cross-tool canonical)
└── ~/.kimi/config.toml                        # USER-LEVEL — NOT shipped per-project
                                                # Adapter writes hooks here when `--include-hooks=user-level` is
                                                # explicit. Default: hooks documented in adapter README, user installs.
```

**Project-level config is `.kimi/skills/` + `.kimi/subagents/` + `AGENTS.md`.** Kimi's main config (`~/.kimi/config.toml`) is user-level — installed once per machine. The adapter does NOT write to it by default; it generates a recommended `[[hooks]]` snippet the user pastes into their global config.

**No user-extensible slash commands.** Per the Customization sidebar (Official Plugins / MCP / Hooks / Skills / Custom Plugins / Agents and Subagents / Wire Protocol), Kimi ships built-in slash commands (`/help`, `/skill:<name>`, `/feedback`, `/theme`) but users cannot register new ones. Project workflows ship via two complementary primitives: **skills** (loadable via Kimi's built-in `/skill:<name>` command) and **subagents** (custom workers dispatched by description). The adapter maps `/setup-project`'s **action commands** (`/optimize`, `/migrate`, `/polish`, etc.) to **BOTH** — a skill (so `/skill:optimize` works) AND a subagent (so "run optimize on src/" works), each with an "EXECUTE NOW" preamble so loading or dispatching produces autonomous execution. **Reference procedures** (`extract-v1-contract`, `parity-test-generate`, etc.) map to skill only. See § "Skills vs subagents — which primitive for what" below.

## File formats

### `.kimi/skills/<name>/SKILL.md` (skill body)
YAML frontmatter + Markdown body. Per the Skills doc:

```markdown
---
name: <name>                            # 1-64 chars, lowercase letters/numbers/hyphens only (optional)
description: <description>              # 1-1024 chars, explains purpose + use cases (optional)
license: MIT                            # License name or file reference (optional)
compatibility:                          # Environment requirements (optional)
  kimi_min_version: "0.x.x"
metadata:                               # Additional key-value attributes (optional)
  tags: [migration, frontend]
---

# <Skill Title>

Body in Markdown. Procedural prose. Reference scripts from `scripts/` and
data from `references/` using relative paths.
```

The `name` field accepts only `[a-z0-9-]{1,64}`. Descriptions are limited to 1024 characters. Skills with no frontmatter are valid (all fields optional) but lose discovery hints.

### `.kimi/subagents/<name>.yaml` (subagent config)
YAML referenced from a main agent config (Kimi's docs show: `subagents: { <name>: { path: ./<name>-sub.yaml, description: "..." } }`):

```yaml
# <subagent-name>.yaml
description: <one-line subagent purpose>
system_prompt: |
  <multi-line system prompt for this subagent>
tools:                                  # Subset of tools this subagent may use
  - read
  - grep
  # - shell                             # omit to disable shell access (Plan-style)
  # - write                             # omit for read-only subagents (Explore-style)
```

The three built-in subagent types — Coder (read+write+shell), Explore (read-only, no write/shell), Plan (read-only, no shell) — set the precedent. Custom subagents inherit unless overridden.

**Subagents cannot create their own subagents.** Per the docs: "The `Agent` tool is only available to the root agent." Subagent files are leaves in the dispatch tree.

### `AGENTS.md` (project memory)
Plain Markdown. No frontmatter. Cross-tool canonical (also consumed by Codex, Cursor fallback, Aider, Cline, Copilot). Kimi's docs do not name a Kimi-specific project-memory file (no `KIMI.md`); Kimi joins the `AGENTS.md` consumer set as the closest-fit primitive. Sections (per `agents.md` spec):
- **Repo overview** — one paragraph: what the project is.
- **Architecture** — short structural description.
- **Key commands** — `pnpm dev`, `pytest`, `cargo run`, etc. (per stack).
- **Conventions** — MUST / MUST NOT rules.
- **Code style** — language-specific style pointers.
- **Testing** — how to run tests.
- **Deployment** — short summary or pointer.

Kimi-specific addendum: a "Skills available" section pointing at `.kimi/skills/` so the user knows what surfaces are pre-installed.

### `~/.kimi/config.toml` (user-level — NOT per-project)
TOML. The adapter does NOT write here directly. It generates a snippet for the user to paste:

```toml
# Recommended hooks for projects using claude-config (paste into ~/.kimi/config.toml)
[[hooks]]
event = "PreToolUse"
matcher = ".*"
command = "~/.claude/scripts/validate-migration-artifacts.sh --hook-mode"
timeout = 30

[[hooks]]
event = "Stop"
command = "echo 'Session ended; consider running /learn-from-task'"
timeout = 5
```

Kimi supports 13 events: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `UserPromptSubmit`, `Stop`, `StopFailure`, `SessionStart`, `SessionEnd`, `SubagentStart`, `SubagentStop`, `PreCompact`, `PostCompact`, `Notification`. Hooks receive JSON via stdin; exit code 0=allow, 2=block (stderr fed to LLM as correction), other=allow with stderr logged.

## Translation recipe

How `/setup-project`'s artifacts map to Kimi's primitives:

| `/setup-project` artifact | Kimi destination | Notes |
|---|---|---|
| `.claude/rules/<name>.md` (rules) | `AGENTS.md` § `## Rules — <name>` (consolidated) + `.kimi/skills/<rule-name>/SKILL.md` (if rule has procedural body) | Kimi has no separate rules folder; rules become project-memory paragraphs OR knowledge skills (rules are reference, not action — skills are the right primitive). |
| `.claude/skills/<name>.md` (skills) | `.kimi/skills/<name>/SKILL.md` | Direct 1:1 with frontmatter rewrite (Kimi's `name` regex differs from Claude's). Skills stay as skills because they ARE reference procedures. |
| `.claude/agents/<name>.md` (agents) | `.kimi/subagents/<name>.yaml` (custom subagent) | Persona body becomes `system_prompt:`; Claude's tool-use config maps to Kimi `tools:` list. Agents are dispatched → subagents are the executable primitive. |
| `.claude/commands/<name>.md` (slash commands) | **BOTH `.kimi/skills/<name>/SKILL.md` AND `.kimi/subagents/<name>.yaml`** (dual-surface) | Commands need two invocation surfaces in Kimi: `/skill:<name>` (Kimi's native built-in slash command that loads a named skill) AND description-based dispatch (main agent picks the subagent by description). The same command body lives in both — with an "EXECUTE NOW" preamble at top so loading OR dispatching produces autonomous execution. Subagent's `tools:` whitelist is derived from the command's expected I/O (read-only audit-style commands omit `write` + `shell`; full-action commands like `/optimize`, `/migrate` get `read` + `write` + `shell`). Removing the skill in favor of subagent-only breaks `/skill:<name>` autocomplete; removing the subagent in favor of skill-only breaks description-based dispatch. Both surfaces are needed. |
| `.claude/settings.json` (hooks) | `~/.kimi/config.toml` `[[hooks]]` snippet (in adapter README) | User-level; not auto-written. |
| `ai/patterns/*.md` (knowledge) | Read by Kimi via `references/` in skills that need them, OR via `AGENTS.md` cross-references. | Kimi has no project-knowledge folder; patterns are referenced from skills. |

## Idempotency

- **`AGENTS.md`** — first line marker `<!-- managed-by: codex -->` (Codex owns this file). Kimi writes inside markers `<!-- kimi:start -->` / `<!-- kimi:end -->` for any Kimi-specific addenda; outside-marker hash check on rewrite.
- **`.kimi/skills/<name>/SKILL.md`** — managed-block markers in the body: `<!-- generated:start -->` / `<!-- generated:end -->` per the adapter system's universal contract (4.8-DEEP). User-customizable sections preserved verbatim across `--refresh`.
- **`.kimi/subagents/<name>.yaml`** — full file is generated; user customizations go in a sibling `.kimi/subagents/<name>.user.yaml` that Kimi merges in (Kimi convention; verify project-side).

## Known gotchas

1. **No path-scoped rules.** Kimi has no equivalent of Cursor's `globs:` or Cline's per-folder rules. All project rules live in one `AGENTS.md` plus skills the user invokes contextually.
2. **Slash commands — Kimi has only built-ins (`/help`, `/skill:<name>`, `/feedback`, `/theme`), not user-extensible.** Workflows that depend on `/<name>` invocation in Claude Code map to Kimi via **dual surfaces**: (a) `.kimi/skills/<name>/SKILL.md` invokable via Kimi's native `/skill:<name>` slash command, and (b) `.kimi/subagents/<name>.yaml` dispatched by description match (e.g., "run optimize on src/"). Both bodies start with an "EXECUTE NOW" preamble so loading OR dispatching produces autonomous execution. Reference procedures (true skills like `extract-v1-contract`, `parity-test-generate`) map to skill only — they ARE supposed to load as documentation. See § "Skills vs subagents — which primitive for what" for the full rule. Document available commands in `AGENTS.md § Available skills + Available subagents` so users know both invocation surfaces exist.
3. **User-level config not auto-written.** Hooks are user-level (`~/.kimi/config.toml`). The adapter generates a paste-ready snippet but does not modify the file (would touch user state outside the project).
4. **Skill `name` regex.** Kimi enforces `[a-z0-9-]{1,64}`. Claude's skill names that include uppercase or underscores must be lowercased + hyphenated when translating.
5. **Subagent dispatch is from the main agent only.** Custom subagents cannot fan out further. Workflows that depend on multi-level agent dispatch (claude-code's nested Agent calls) flatten into a single subagent layer in Kimi.
6. **Brand-group exclusivity.** A user with both Kimi and Claude installed has SEPARATE `~/.kimi/` and `~/.claude/` global skill dirs. Per-project, `.kimi/` and `.claude/` may coexist; tools don't read each other's brand dirs.
7. **TOML config, not JSON.** Kimi 0.x onward uses `~/.kimi/config.toml`. Legacy `~/.kimi/config.json` is auto-migrated on first run with backup `config.json.bak`.

## Sample output (skill from rule)

Source: `.claude/rules/migration-discipline.md` (universal V1→V2 port discipline).

```markdown
.kimi/skills/migration-discipline/SKILL.md
---
name: migration-discipline
description: V1→V2 port discipline. When migrating a feature, read this skill. Covers contract extraction, parity tests, audit halts, gate criteria.
metadata:
  pack: migration
  source: .claude/rules/migration-discipline.md
---

# Migration discipline (V1→V2 ports)

## When to use

When the user asks to port / migrate / move a feature from V1 to V2. Run BEFORE writing any V2 code.

## What this skill enforces

[... body of the rule, inlined ...]
```

## Sample output (subagent from action command)

Source: `commands/optimize.md` (action command). This is the canonical pattern for translating action-style commands (`/optimize`, `/migrate`, `/polish`, `/align`, `/refactor`, `/audit`, `/unify-surfaces`, `/do`) into Kimi.

**The body MUST begin with an explicit "EXECUTE NOW" preamble.** Without it, the subagent reads the workflow as documentation and reports back instead of running. The preamble is what makes Kimi treat dispatch as imperative.

```yaml
# .kimi/subagents/optimize.yaml
description: |
  Run the /optimize workflow on the current repo or a specified scope.
  Deep architectural diagnosis first, then tactical sweep in parallel waves.
  Stack-agnostic. Invoke when the user asks to "optimize", "improve quality",
  "find tech debt", or names this subagent explicitly.

system_prompt: |
  # EXECUTE NOW

  You are the optimize subagent. When dispatched, do NOT summarise this
  document and ask the user what to do — immediately begin the workflow
  below against the scope the main agent passed you (default: whole repo).

  ## Workflow (from commands/optimize.md, inlined)

  [... full body of commands/optimize.md, inlined verbatim, with any
  Claude-Code-specific sub-agent dispatch references rewritten to call
  Kimi skills + subagents by name ...]

  ## Closure verbs (closed vocabulary — do not invent new ones)

  [... 21-verb closure vocabulary from commands/optimize.md ...]

  ## Output contract

  Final report at `ai/optimize/final-report.md` MUST end with the
  `## Actionable next steps` section per
  `templates/snippets/actionable-next-steps.md`.

tools:
  - read
  - write
  - shell                                # /optimize edits code → needs shell + write
  # - search                             # add if Kimi exposes named search; otherwise built-in
```

**Tool whitelist rules per command type:**

| Command class | tools whitelist |
|---|---|
| Audit-only (`/audit`, `/security-audit`, `/perf-audit`, `/db-audit`) | `read` only (no `write`, no `shell`) — Explore-style |
| Plan-only (`/refine-prompt`, `/migration-plan`) | `read`, `write` (writes plan to `ai/`) — no shell. **`/refine-prompt` `medium`/`heavy` deep-refine maps to declared `.kimi/subagents/` (one per §9-15 specialist + a reconcile subagent for §16), dispatched by the parent agent; `light` stays single-pass. Orphan subagents don't dispatch — register them in the parent agent YAML (see § "Subagent registration").** |
| Full-action (`/optimize`, `/migrate`, `/polish`, `/align`, `/refactor`, `/unify-surfaces`, `/setup-project`, `/do`) | `read`, `write`, `shell` — Coder-style |
| Knowledge/help (`/setup-project-health`, `/learn-from-task`) | `read`, `write` — no shell |

The whitelist comes from the command's documented effects, not from a blanket policy. Over-granting tools to an audit subagent breaks the read-only contract.

**Invocation pattern in Kimi**: the user (or main agent) addresses the subagent by name in the prompt — e.g., "Run the `optimize` subagent on `src/api/`". The main agent dispatches via Kimi's `Agent` tool with the subagent name + scope arg.

**Why this is NOT a skill**: a skill at `.kimi/skills/optimize/SKILL.md` would be loaded as reference and the user would have to type the workflow steps manually. A subagent at `.kimi/subagents/optimize.yaml` is dispatched and runs the steps autonomously. Same body, different primitive, completely different runtime behaviour.

## Plugin coverage

Kimi's "Custom Plugins (Beta)" surface (sidebar item) is documented separately. Plugins extend Kimi via the Wire Protocol (also a sidebar item). The adapter does NOT generate plugins by default — pack content lands as skills + subagents + AGENTS.md, which is sufficient for the standalone-tool goal. Plugin generation is a v2 candidate when the Custom Plugins doc stabilises out of beta.

## Cross-references

- **Migration pack — companion scripts (2026-05):** Hook snippet above runs only `validate-migration-artifacts.sh`; users MUST also install **`migration-doctor.sh`**, **`migration-reachability.sh`**, **`migration-detect-existing.sh`**, **`migrate-parallel.sh`**, **`parallel-fan-out.sh`** into `~/.claude/scripts/` for workspace CI + parallel runs. Canonical list: `templates/tool-adapters/_migration-pack-coverage.md` § **Companion scripts (2026-05)**.
- **Optimize pack — companion scripts (2026-05):** Also install **`validate-optimize-artifacts.sh`** + **`optimize-parallel.sh`** for `/optimize`; see `templates/tool-adapters/_optimize-pack-coverage.md`.
- **Refactor pack — companion scripts (2026-05):** Also install **`validate-refactor-artifacts.sh`** for `/refactor`; see `templates/tool-adapters/_refactor-pack-coverage.md`.
- **Polish pack — companion scripts (2026-05):** Also install **`validate-polish-artifacts.sh`** + **`polish-parallel.sh`** for `/polish` (stack-conditional — frontend / backend / data / mobile evidence); frontend rows additionally gated by **`check_frontend_verb_vocabulary`** against the closed 19-verb **`ui-design-sweep`** set (ui-ux pack v1.1+); see `templates/tool-adapters/_polish-pack-coverage.md` + `templates/tool-adapters/_ui-ux-pack-coverage.md`.
- **Align pack — companion scripts (2026-05):** Also install **`validate-align-artifacts.sh`** + **`align-parallel.sh`** for `/align`; see `templates/tool-adapters/_align-pack-coverage.md`.
- **Audit pack — companion scripts (2026-05):** `/audit` artifacts live under `ai/audit/**` (`plan.md`, `progress.md`, per-axis subfiles `_arch.md` / `_quality.md` / `_security.md` / `_db.md` / `_perf.md` / `_scale.md` / `_infra.md` / `_obs.md`, `final-report.md`, `assessment.md`). **Three output modes**: default (execute), `--plan-only` (ranked fix-plan in `plan.md` — executor handoff), `--assess` (8-section senior-engineer narrative in `assessment.md` — what's good / improve / unify / extract / simplify / redesign / remove / optimize — reader handoff). Validator **`validate-audit-artifacts.sh`** ships in `scripts/` — halts on hand-waves (`etc.`, `would be slow`, `at scale this is bad`) and requires P0 findings to cite a target-RPS failure mode (`check_no_handwaves_audit_plan` + `check_p0_failure_mode_cited`; `--strict` adds `<file:line>` citation enforcement on P0/P1/P2). Dispatches existing pack scripts internally (`validate-optimize-artifacts.sh`, `validate-align-artifacts.sh`, `validate-polish-artifacts.sh`) for the architecture / SOLID / clean-code / API-consistency axes; security + DB + scale axes use their respective pack agents and skills directly. See `commands/audit.md` + `templates/tool-adapters/_orchestration-sync.md`.
- **Unify-surfaces pack — companion scripts (2026-05):** `/unify-surfaces` (frontend-only, sibling to `/polish`) artifacts live under `ai/unify-surfaces/**` (`progress.md`, per-category inventory, canonical-wrapper decision evidence, `final-report.md`). Validator **`validate-unify-surfaces-artifacts.sh`** is **planned** — will check per-category inventory completeness, canonical-wrapper decision citations, idioms-update co-commit (`_extracted-idioms.md § Wrappers` updated in same commit), `Reuse-Before-Create` enforcement (extracting a duplicate where a shared wrapper exists fails). 7 default categories: tables / forms / headers / tabs / filters / buttons / validation. Validation is a 3-part pipeline (composable + components + API-error mapper), not a single wrapper. Halts on `PROJECT_KIND` not in `frontend-* / mobile-web / mobile-rn` with redirect to `/polish`. See `commands/unify-surfaces.md` + `templates/tool-adapters/_orchestration-sync.md`.
- **Orchestration / validator sync:** **`templates/tool-adapters/_orchestration-sync.md`** — discipline paths (`ai/migrate/progress.md`), optimize oracle fallbacks, align 21-verb closure vocabulary, polish validator env (`QUIET=1`; no `--strict` CLI), refactor hook paths.
- **`/task` integration (MCP-backed):** provider-agnostic task executor — Trello / Jira / Linear / GitHub Issue → fetch → normalize → dispatch → write-back (in-progress → comment → review/done). This tool surfaces it as `.kimi/skills/task/SKILL.md` (`type: flow`, `/flow:task`); needs a task-provider MCP from `scripts/detect-mcp.sh` (gated on the repo's own `.env` creds). It routes to Kimi specialist skills in place of `/do`. Canonical recipe + per-tool matrix: `templates/tool-adapters/_task-integration-coverage.md`; lifecycle: `commands/task.md`; providers: `templates/integrations/task-providers.md`.
- **Actionable next steps — universal report contract (2026-05):** Every report-producing command (`/optimize`, `/polish`, `/align`, `/migrate`, `/refactor`, `/audit`, `/unify-surfaces`) MUST end its `final-report.md` with a `## Actionable next steps` section per **`templates/snippets/actionable-next-steps.md`** — paste-ready commands. Validator gate: **`check_actionable_next_steps`** halts when missing or prose-not-args. Hook above invokes the validators on edits.
- Kimi data-locations doc: `~/.kimi/{config.toml, kimi.json, mcp.json, credentials/, sessions/, plans/, user-history/, logs/kimi.log}`. Override with `KIMI_SHARE_DIR` env.
- Adapter registry row: `templates/tool-adapters/_registry.md`.
- Universal `AGENTS.md` writer: `templates/tool-adapters/codex/adapter.md` (Codex owns the file; Kimi consumes + appends Kimi-specific markers).
- Built-in subagent types Kimi ships: Coder (full), Explore (read-only), Plan (read-only, no shell).
- Built-in skills Kimi ships: `kimi-cli-help`, `skill-creator` — adapter does NOT overwrite these; the project's pack content lands alongside.
