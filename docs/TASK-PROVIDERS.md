# Task providers — set up `/task` for Trello / Jira / Linear / GitHub

`/task` pulls ONE task from your project-management tool and runs it end-to-end:
**fetch → normalize → execute (via `/do`) → write status back**. One command, swappable
backend. This guide is the setup + usage + troubleshooting reference.

- Command spec: [`commands/task.md`](../commands/task.md)
- Canonical TaskSpec + per-provider field maps: [`templates/integrations/task-providers.md`](../templates/integrations/task-providers.md)
- Per-tool adapter coverage: [`templates/tool-adapters/_task-integration-coverage.md`](../templates/tool-adapters/_task-integration-coverage.md)
- MCP provisioning: [`scripts/detect-mcp.sh`](../scripts/detect-mcp.sh)

---

## How it fits together

```
   /task <ref>           ← one command (globally symlinked, works in every repo)
       │
   resolve provider      ← from URL host / key prefix / the MCP wired in this repo
       │
   fetch + normalize     ← provider MCP if healthy, else REST fallback over .env creds
       │  → canonical TaskSpec (title, description, AC, subtasks, attachments, statusFlow)
       │
   execute via /do  ──→  /add-feature · /fix-bug · /enhance-ui · /optimize · …
       │
   write status back     ← in-progress → comment (commit/PR + per-AC ✓/✗) → review/done
```

**Per-repo.** Each repo declares its own provider + creds in its own `.env`. A repo can
use Trello while the next uses Jira. The MCP is wired by `detect-mcp.sh`, gated on those creds.

| Provider | MCP package | `.env` vars |
|---|---|---|
| Trello | `@delorenj/mcp-server-trello` | `TRELLO_API_KEY`, `TRELLO_TOKEN`, `TRELLO_BOARD_ID` |
| Jira | `@aashari/mcp-server-atlassian-jira` | `ATLASSIAN_SITE_NAME`, `ATLASSIAN_USER_EMAIL`, `ATLASSIAN_API_TOKEN` |
| Linear | `@tacticlaunch/mcp-linear` | `LINEAR_API_KEY` |
| GitHub Issues | `@modelcontextprotocol/server-github` (universal) | `GITHUB_TOKEN` |

> ⚠️ Verify each non-Trello server's exact env-var names against its README — they vary.

---

## Setup (per repo, ~5 min)

### 1. Get your provider credentials

**Trello**
1. Create a Power-Up at <https://trello.com/power-ups/admin> → its **API key** tab → copy the key.
2. Token: visit (swap in your key) —
   `https://trello.com/1/authorize?expiration=never&scope=read,write&response_type=token&key=YOUR_API_KEY`
   → **Allow** → copy the token.
3. Board id: open the board, add `.json` to the URL, copy the top-level `"id"` — or list boards with the key+token via the API.

**Jira** — create an API token at <https://id.atlassian.com/manage-profile/security/api-tokens>; note your site (`yourco.atlassian.net`) and account email.
**Linear** — Settings → API → personal API key.
**GitHub** — a PAT with `repo` scope.

### 2. Put them in the repo's `.env` (gitignored)

```bash
# Trello example
TRELLO_API_KEY=...
TRELLO_TOKEN=...
TRELLO_BOARD_ID=...
```
Confirm `.env` is gitignored (`git check-ignore .env`) so creds never get committed.

### 3. Wire the MCP

```bash
# from the Refract repo (or with detect-mcp.sh on PATH)
scripts/detect-mcp.sh /path/to/your/repo --apply
```
This writes `<repo>/.mcp.json` with a `trello`/`jira`/`linear` block whose `env` values are
**`${VAR}` references** — no secrets in the file (which IS tracked). It only wires providers
whose creds it finds in `.env`.

### 4. (Optional) Cursor + OpenCode

`detect-mcp.sh` writes Claude Code's `.mcp.json`. To use `/task` in those tools too:
- **Cursor** — `.cursor/mcp.json`, same `mcpServers` shape + `${VAR}` refs.
- **OpenCode** — `opencode.json` → `mcp.<name>` with `command: [..]`, `environment: { "VAR": "{env:VAR}" }`, `enabled: true`.

Both files are tracked → use env-var references, never literal secrets.

### 5. ⚠️ Load the env before launching (the #1 gotcha)

**The editor expands `${TRELLO_*}` from the shell it was launched in — it does NOT auto-read `.env`.**
Launch with the env loaded:
```bash
cd /path/to/your/repo
set -a; source .env; set +a        # exports the provider vars
claude                             # (or cursor / opencode) from this same shell
```
Or export the vars in your shell profile once. **Skip this and the MCP authenticates with
empty creds → 401.** (`/task` also self-heals this — see Troubleshooting.)

---

## Usage

```bash
/task https://trello.com/c/NBswBsfN     # do a specific card (URL)
/task PROJ-128                           # by key (Jira)
/task #57                                # GitHub issue in the current repo
/task next                               # top unstarted item assigned to you
```

### Flags
| Flag | Effect |
|---|---|
| `--prompt-only` | Fetch + normalize, then **print a paste-ready prompt and stop** — no execution, no write-back. Hand it to another command/tool/agent. |
| `--to=<command>` | Dispatch directly to `/<command>` instead of routing through `/do`. |
| `--no-writeback` | Execute, but don't touch the source (no status move, no comment). |
| `--review-only` | On finish, stop at the Review state; never auto-advance to Done. |

Drain a list/sprint by looping `/task next`.

### Status-flow mapping
`/task` resolves your board's status lists/states **by name at runtime**. Example (SahlCart Trello board):
start → `in progress`, review → `Need Testing`, done → `done`. If your board uses different
names, `/task` matches case-insensitively; rename or tell it which list maps to which.

---

## How `/task` relates to `/do`
- `/do <trello-url>` also routes to `/task` (we wired that) — so either entry works.
- `/task` is the lifecycle/queue command (`next`, attachments, write-back); `/do` is intent→command routing.
- On non-Claude tools, `/task` routes to that tool's own specialist instead of `/do` (see the adapter coverage doc).

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Unknown command: /task` | command not installed | It's a global symlink (`~/.claude/commands/task.md`). Restart the session; if still missing, re-create the symlink to `<repo>/commands/task.md`. |
| **401 / `get_health` 0%** from the MCP | env not loaded into the editor's process → server got empty creds | Relaunch with `set -a; source .env; set +a` first. **`/task` also auto-falls back to the provider REST API** using `.env` creds, so a run still succeeds — it just notes that fallback was used. |
| `/mcp` shows the server disconnected | wrong env-var names, or creds invalid | Verify names against the server README; test creds directly (e.g. `curl "https://api.trello.com/1/members/me?key=$K&token=$T"` → expect `200`). |
| MCP server "setup issues" for github/postgres | those servers wired but their secrets (`GITHUB_TOKEN`/`DATABASE_URL`) missing | Add the secret, or remove the unused server from `.mcp.json`. |
| `/task` halts: "Provider not configured" | no MCP **and** no `.env` creds | Add creds to `.env` + run `detect-mcp.sh --apply`. |

---

## Adding a new provider (Asana / ClickUp / Notion / …)
1. Add an adapter block in [`templates/integrations/task-providers.md`](../templates/integrations/task-providers.md) (field map + status verbs + ref detection).
2. Add a detection + config entry in [`scripts/detect-mcp.sh`](../scripts/detect-mcp.sh) (gate on the repo's own `.env` creds).
3. Add a row in [`_task-integration-coverage.md`](../templates/tool-adapters/_task-integration-coverage.md).

The `/task` command itself never changes — it reads providers generically.
