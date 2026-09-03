# `/task` integration — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces the **provider-agnostic `/task` command** (`commands/task.md`) when a task-provider MCP is wired into the repo.

`/task` is the first **MCP-backed integration command** (see `_registry.md` § Top-level orchestration commands → *Integration commands*). Unlike the simple-surface multi-agent commands, it does **not** need parallel sub-agent dispatch — it is a single-task lifecycle: **resolve provider → fetch card/issue → normalize to canonical TaskSpec → ingest attachments → dispatch the work → write status back**. That makes it portable to every adapter that can (a) reach a task-provider MCP and (b) dispatch a specialist.

> **Canonical sources**: `commands/task.md` (lifecycle) + `templates/integrations/task-providers.md` (TaskSpec + per-provider adapters) + `scripts/detect-mcp.sh` (per-repo MCP provisioning: `trello` / `jira` / `linear` / universal `github`, each gated on the repo's own `.env` creds).

## The one substitution every adapter makes

Claude's `/task` routes execution through **`/do`** (intent → specialist). `/do` is Claude-only (parallel-dispatch dependent). So each adapter replaces that ONE step:

| In Claude `/task` | In every other adapter |
|---|---|
| dispatch synthesized description to `/do` | dispatch to **this tool's own specialist** command/skill (the translated `add-feature` / `fix-bug` / `enhance-ui` / pack command per `_<pack>-pack-coverage.md`), OR, if the routing is unambiguous, run the matching specialist directly |

Everything else — provider resolution, fetch, TaskSpec normalization, attachment ingestion, acceptance-criteria extraction, the **write-back lifecycle** (in-progress → comment → review/done) — is identical across tools and driven by the same `task-providers.md` adapters.

## Capability mapping per tool

> **`✓` in the MCP-reach column means the TOOL supports MCP — not that this repo has configured it
> for that tool.** `scripts/detect-mcp.sh` writes one file: `<target>/.mcp.json`, which is Claude
> Code's project format. Every other client reads somewhere else, and two of them cannot be
> configured per-project at all:
>
> | Tool | Reads MCP config from | Level | Written by detect-mcp.sh? |
> |---|---|---|---|
> | Claude Code | `.mcp.json` | project | **yes** |
> | Cursor | `.cursor/mcp.json` | project | **yes** — same `mcpServers` schema |
> | Copilot / VS Code | `.vscode/mcp.json` | project | **yes** — root key is `servers`, not `mcpServers`, and each entry carries `"type": "stdio"`. VS Code reading an `mcpServers`-keyed file ignores every server **silently**, so the entries are transformed, never copied. |
> | Windsurf | `~/.codeium/windsurf/mcp_config.json` | **user** | **cannot be** — per-machine, not per-repo |
> | Cline | `cline_mcp_settings.json` in VS Code global storage | **user** | **cannot be** — same reason |
> | OpenCode · Codex · Gemini · Qwen · Kimi | per that tool's own config | varies | no |
>
> So on Claude Code, Cursor and VS Code the servers are **written**; everywhere else they are **detected and reported** — the
> recommendations report at `.claude/_mcp-recommendations.md` carries the same JSON block, and a
> human pastes it into the path above. The two user-level clients are configured once per machine
> and are outside a project-scoped tool's reach by construction, not by omission.
>
> Verified 2026-09-03. MCP client config paths move; re-check before trusting this table.

| Tool | MCP reach (tool supports it) | `/task` primitive | Notes |
|---|---|---|---|
| Claude Code | ✓ (`.mcp.json`) | `.claude/commands/task.md` (native) | Source of truth. Routes via `/do`. |
| OpenCode | ✓ | `.opencode/commands/task.md` (`agent: build`) | `agent: build` REQUIRED (read+write+shell). Routes to OpenCode specialist commands. |
| Cursor | ✓ | `.cursor/skills/task/SKILL.md` | Skill primitive (Cursor 2.3+). Routes to Cursor specialist skills. |
| Cline | ✓ | `.cline/skills/task/SKILL.md` (also reads `.claude/skills/`) | Skills must be enabled in Settings → Features. |
| Continue | ✓ | `.continue/prompts/task.md` (`invokable: true`) | Agent mode required for the tool loop. |
| Copilot | ✓ | `.github/prompts/task.prompt.md` (`mode: agent`) | `mode: agent` REQUIRED for MCP + tool loop. |
| Windsurf | ✓ | `.windsurf/workflows/task.md` | Manual-invoke workflow (Cascade never auto-runs — fits `/task`). |
| Codex | ✓ | `.agents/skills/task/SKILL.md` (Open Agent Skills) | Invoked via `/skills` / `$task` / description match. |
| Gemini | ✓ | `.gemini/commands/task.toml` (TOML only) | `description` + `prompt` fields; reload via `/commands reload`. |
| Kimi | ✓ | `.kimi/skills/task/SKILL.md` (`type: flow`, Flow Skill `/flow:task`) | Flow Skill is Kimi's autonomous primitive; walks resolve→fetch→dispatch→write-back as BEGIN→END nodes. |
| Qwen | ✓ | `.qwen/commands/task.md` (Markdown) | Routes to Qwen specialist commands/agents. |
| Aider | ✗ (no MCP, closed slash set) | `CONVENTIONS.md § User-invoked procedures` (EXECUTE-NOW preamble) | **Degraded path**: no MCP — fetch the card/issue via the provider **REST API / CLI** (`curl` with `.env` creds), then `/architect` + `/code` for the work. Write-back is a manual `curl` documented in the preamble. |

**Rule of thumb**: any tool with MCP support gets the full `/task` (same lifecycle, native primitive, native dispatch substitution). Only Aider degrades to API-fetch + imperative preamble.

## Flags (every adapter's `/task` MUST expose these)

| Flag | Effect |
|---|---|
| `--prompt-only` | Fetch + normalize, then **print a paste-ready prompt and stop** — no dispatch, no write-back. The hand-off mode (give the prompt to another command/tool/agent). |
| `--to=<command>` | Dispatch directly to `/<command>` (this tool's native specialist) instead of the default routing — the per-adapter equivalent of skipping `/do`. |
| `--no-writeback` | Execute, but make no status move / comment on the source. |
| `--review-only` | On finish, stop at the Review state; never auto-advance to Done. |

Translators MUST carry all four — they are part of the command surface, not Claude-only behavior. `--prompt-only` in particular is the universal "emit, don't run" escape hatch for any tool.

## Resilience: env-load + MCP→REST fallback (built into `/task`)

`/task` Phase 1 loads the repo's `.env` and probes the provider MCP. **If the MCP is missing or returns 401 / 0% health (stale or empty env — common when the editor was launched without the provider vars exported), `/task` falls back to the provider's REST API using the `.env` creds** for BOTH fetch and write-back, rather than halting. Every adapter's translation MUST preserve this fallback — it is what keeps `/task` working when a tool spawns the MCP server without the env loaded. This also means **Aider's "degraded path" below is simply this same built-in fallback**, not a special case.

## Degradation when no provider creds exist at all

`/task` halts **only** when there is no provider MCP **and** no provider creds in `.env` (so neither MCP nor REST can authenticate): *"Provider not configured — add `TRELLO_*` / `JIRA_*` / `LINEAR_*` creds to `.env` and re-run setup (or `detect-mcp.sh --apply`)."* No silent no-op. A 401 from a wired MCP is NOT this case — that takes the REST fallback above.

## Honesty clause (inherited from `_orchestration-sync.md`)

`/task`'s write-back comment carries a per-acceptance-criterion ✓/✗ list. That list MUST reflect reality — an unmet AC reported as met is the Trusted-Summary failure mode applied to the ticket. The end-of-run report also closes with `Not validated:` / `Risks:` / `Revert:` when the routed specialist is a simple-surface approximation.

## Adding a provider or a tool
- **New provider** (Asana / ClickUp / Notion / …): add an adapter block in `templates/integrations/task-providers.md` + a detection entry in `scripts/detect-mcp.sh`. No adapter.md change — every tool picks it up via the same MCP.
- **New tool**: add a row above declaring its MCP reach + `/task` primitive + the native-dispatch substitution, and a Cross-references line in its `adapter.md`.

## See also
- `commands/task.md` — the lifecycle command.
- `templates/integrations/task-providers.md` — canonical TaskSpec + per-provider adapters.
- `scripts/detect-mcp.sh` — per-repo MCP provisioning (task-provider servers gated on `.env`).
- `templates/tool-adapters/_orchestration-sync.md` — honesty clause + discipline paths.
- `templates/tool-adapters/_registry.md` § Top-level orchestration commands.
