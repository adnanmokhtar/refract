#!/usr/bin/env bash
# detect-mcp.sh — recommend MCP servers based on project signals.
#
# Reads the same signals detect-tracks.sh uses (package.json deps, manifest
# files, top-level dirs, sibling V1/V2 layout) and emits a per-project
# recommendation report:
#   <target>/.claude/_mcp-recommendations.md
#
# The report includes:
#   - Per-server rationale (which signal triggered it)
#   - A copy-pasteable `.mcp.json` block
#   - Notes about user-controlled MCP servers vs project-recommended ones
#
# We deliberately do NOT auto-write `.mcp.json`. The user owns their MCP
# config; this script gives them a project-aware recommendation to merge
# manually (or feed to a future apply step).
#
# Usage:
#   detect-mcp.sh <target-repo> [--quiet]
#
# Exit codes:
#   0 — clean
#   1 — target missing
#   2 — usage error

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--apply] [--quiet]" >&2
  exit 2
fi

TARGET="$1"; shift
QUIET=0
APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    *)       echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

REPORT="$TARGET/.claude/_mcp-recommendations.md"
mkdir -p "$(dirname "$REPORT")"

trace() { [[ $QUIET -eq 0 ]] && echo "  • $*" >&2; }

# Read package.json deps if present (same parser shape as detect-tracks.sh)
PKG="$TARGET/package.json"
PKG_DEPS=""
if [[ -f "$PKG" ]]; then
  PKG_DEPS=$(awk '
    /"(dependencies|devDependencies|peerDependencies)"[[:space:]]*:/ { in_block=1; next }
    in_block && /^[[:space:]]*}/ { in_block=0; next }
    in_block && /"[^"]+"[[:space:]]*:/ {
      gsub(/^[[:space:]]*"/, "")
      sub(/"[[:space:]]*:.*$/, "")
      print
    }
  ' "$PKG" 2>/dev/null | tr '\n' ' ')
fi
has_dep() { [[ " $PKG_DEPS " == *" $1 "* ]]; }
has_dep_prefix() { [[ " $PKG_DEPS " == *" $1"* ]]; }

# Server registry: tab-separated rows
#   id  name  package  rationale_signal  rationale_text
# We stage rows in arrays; print only the ones whose signal fires.
declare -a RECS  # "id|name|package|rationale"

add_rec() {
  RECS+=("$1|$2|$3|$4")
  trace "$1 → $2"
}

# ---------- Universal (always recommended) ----------
add_rec "filesystem" "Filesystem MCP" "@modelcontextprotocol/server-filesystem" \
  "Universal — read/write project files outside Claude Code's default sandbox."
add_rec "github" "GitHub MCP" "@modelcontextprotocol/server-github" \
  "Universal — list/comment on PRs + issues, query repo metadata, read CI status."

# ---------- Frontend ----------
FRONTEND=0
if has_dep vue || has_dep_prefix '@vue/' || has_dep react || has_dep_prefix '@types/react' \
   || has_dep '@angular/core' || has_dep svelte || has_dep solid-js || has_dep next \
   || has_dep nuxt || has_dep remix \
   || [[ -f "$TARGET/vite.config.ts" || -f "$TARGET/vite.config.js" ]] \
   || [[ -d "$TARGET/src/components" || -d "$TARGET/src/pages" || -d "$TARGET/src/views" ]]; then
  FRONTEND=1
  add_rec "playwright" "Playwright MCP" "@playwright/mcp" \
    "Frontend stack detected — drive the running app: navigate, click, type, screenshot, assert. Single best tool for UI feature verification."
  add_rec "puppeteer" "Puppeteer MCP" "@modelcontextprotocol/server-puppeteer" \
    "Frontend stack detected — alternate to Playwright for headless Chromium tasks (lighter dependency footprint, fewer browser engines)."
fi

# ---------- Storybook (frontend + .storybook dir) ----------
if [[ $FRONTEND -eq 1 && -d "$TARGET/.storybook" ]]; then
  add_rec "storybook" "Storybook MCP" "(community: search npm for storybook-mcp; not yet official)" \
    "Frontend with Storybook detected (.storybook/) — query component catalog, render stories, inspect args/controls."
fi

# ---------- Figma (frontend + figma config / tokens dir) ----------
if [[ $FRONTEND -eq 1 ]]; then
  if [[ -f "$TARGET/figma.config.json" || -f "$TARGET/.figmarc" \
        || -d "$TARGET/design-tokens" || -d "$TARGET/tokens" ]] \
     || has_dep '@figma/code-connect' || has_dep_prefix '@tokens-studio/'; then
    add_rec "figma" "Figma MCP" "@figma/mcp" \
      "Figma config or design-tokens dir detected — pull token values, component specs, frame dimensions directly from Figma into the dev loop."
  fi
fi

# ---------- Backend Postgres ----------
if has_dep pg || has_dep '@types/pg' || has_dep postgres \
   || [[ -f "$TARGET/prisma/schema.prisma" ]] \
   || grep -qE 'postgres|psql' "$TARGET/.env" "$TARGET/.env.example" 2>/dev/null; then
  add_rec "postgres" "Postgres MCP" "@modelcontextprotocol/server-postgres" \
    "Postgres dependency or schema detected — read-only query agent for schema inspection + analysis."
fi

# ---------- Backend MySQL ----------
if has_dep mysql || has_dep mysql2 \
   || grep -qE 'mysql' "$TARGET/.env" "$TARGET/.env.example" 2>/dev/null; then
  add_rec "mysql" "MySQL MCP" "(community: search npm for mysql-mcp; not yet official)" \
    "MySQL driver detected — schema introspection + query helper."
fi

# ---------- Backend MongoDB ----------
if has_dep mongoose || has_dep mongodb || has_dep_prefix '@mongoose/'; then
  add_rec "mongodb" "MongoDB MCP" "(community: search npm for mongodb-mcp; not yet official)" \
    "MongoDB driver detected — collection introspection + sample queries."
fi

# ---------- Mobile (iOS + Android) ----------
if [[ -d "$TARGET/ios" && -d "$TARGET/android" ]] || has_dep react-native \
   || has_dep '@capacitor/core' || has_dep expo; then
  add_rec "ios-simulator" "iOS Simulator MCP" "(community: search npm for ios-simulator-mcp; not yet official)" \
    "Mobile project — drive iOS Simulator (boot, install, screenshot, gesture)."
  add_rec "android-emulator" "Android Emulator MCP" "(community)" \
    "Mobile project — drive Android Emulator (avd, install, adb commands, screenshot)."
fi

# ---------- DevOps / Infrastructure ----------
if [[ -f "$TARGET/Dockerfile" || -f "$TARGET/docker-compose.yml" || -f "$TARGET/docker-compose.yaml" ]]; then
  add_rec "docker" "Docker MCP" "(community: search npm for docker-mcp; experimental)" \
    "Dockerfile / compose detected — list containers, inspect, exec, log-tail without leaving the dev loop."
fi
if compgen -G "$TARGET/*.tf" >/dev/null 2>&1 || [[ -d "$TARGET/terraform" ]]; then
  add_rec "terraform" "Terraform MCP" "(community: search Hashicorp / npm)" \
    "Terraform config detected — plan/show/state inspection without ad-hoc shell."
fi

# ---------- Project management (Trello) ----------
# No codebase footprint — gate on this repo's OWN Trello credentials so each
# repo wires its own board/account. Keys live in the repo's .env, never here.
if grep -qE 'TRELLO_(API_KEY|TOKEN|BOARD_ID|BOARD_NAME)' "$TARGET/.env" "$TARGET/.env.example" 2>/dev/null \
   || [[ -f "$TARGET/.trello.json" ]]; then
  add_rec "trello" "Trello MCP" "@delorenj/mcp-server-trello" \
    "Trello credentials detected (\`TRELLO_*\` in .env) — pull this repo's board into the dev loop: read cards/lists, move cards, comment, check off items. Per-repo board via \`TRELLO_BOARD_ID\`. Backs /task (provider=trello)."
fi

# ---------- Project management (Jira) ----------
# Gate on this repo's own Atlassian credentials. Backs /task (provider=jira).
if grep -qE '(JIRA|ATLASSIAN)_(URL|SITE_NAME|USER|USER_EMAIL|USERNAME|API_TOKEN|TOKEN)' "$TARGET/.env" "$TARGET/.env.example" 2>/dev/null; then
  add_rec "jira" "Jira MCP" "@aashari/mcp-server-atlassian-jira" \
    "Jira/Atlassian credentials detected in .env — pull this repo's issues into /task: read issue, transition status, comment. Per-repo project. Verify env-var names against the server README."
fi

# ---------- Project management (Linear) ----------
# Gate on this repo's own Linear API key. Backs /task (provider=linear).
if grep -qE 'LINEAR_API_KEY' "$TARGET/.env" "$TARGET/.env.example" 2>/dev/null; then
  add_rec "linear" "Linear MCP" "@tacticlaunch/mcp-linear" \
    "Linear API key detected in .env — pull this repo's issues into /task: read issue, set workflow state, comment. Per-repo team. Backs /task (provider=linear)."
fi

# ---------- Migration (V1/V2) ----------
parent_dir=$(dirname "$TARGET")
target_name=$(basename "$TARGET")
v1_candidate=""
case "$target_name" in
  *-v2|*-V2|*-new|*-rewrite|*-next) v1_candidate="${target_name%-*}" ;;
esac
if [[ -n "$v1_candidate" && -d "$parent_dir/$v1_candidate" ]]; then
  add_rec "migration-fs" "Filesystem MCP (V1 read-only)" "@modelcontextprotocol/server-filesystem" \
    "Sibling V1 repo detected at \`$parent_dir/$v1_candidate\` — configure a SECOND filesystem MCP scoped to that dir (read-only) so /compare-v1 + /port-feature can read V1 source without manual file shuttling."
fi

# ---------- Build report ----------
{
  printf '# MCP server recommendations — %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Target: `%s`\n\n' "$TARGET"
  printf 'Generated by: scripts/detect-mcp.sh\n\n'
  printf '> Recommendations are derived from project signals (package.json deps, manifest files, top-level dirs, sibling repos). The user OWNS `.mcp.json` — this report is a copy-pasteable suggestion, never auto-written. Servers marked **(community)** are placeholders for ecosystems where an official MCP server doesn'"'"'t exist yet — search npm before using.\n\n'
  printf -- '---\n\n'

  printf '## Recommended servers\n\n'
  printf '| ID | Name | Package | Why |\n'
  printf '|---|---|---|---|\n'
  for r in "${RECS[@]}"; do
    IFS='|' read -r id name pkg why <<<"$r"
    printf '| `%s` | %s | `%s` | %s |\n' "$id" "$name" "$pkg" "$why"
  done
  printf '\n'

  printf '## Copy-pasteable `.mcp.json` block\n\n'
  printf '> Drop this into `<target>/.mcp.json` (or merge with your existing one). All paths use `${PWD}` so the config is portable across checkouts. Replace `${GITHUB_TOKEN}` with a real env var.\n\n'
  printf '```json\n'
  printf '{\n  "mcpServers": {\n'
  first=1
  for r in "${RECS[@]}"; do
    IFS='|' read -r id name pkg why <<<"$r"
    [[ $first -eq 0 ]] && printf ',\n'
    first=0
    case "$id" in
      filesystem)
        printf '    "filesystem": {\n      "command": "npx",\n      "args": ["-y", "%s", "${PWD}"]\n    }' "$pkg"
        ;;
      github)
        printf '    "github": {\n      "command": "npx",\n      "args": ["-y", "%s"],\n      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}" }\n    }' "$pkg"
        ;;
      playwright)
        printf '    "playwright": {\n      "command": "npx",\n      "args": ["-y", "%s"]\n    }' "$pkg"
        ;;
      puppeteer)
        printf '    "puppeteer": {\n      "command": "npx",\n      "args": ["-y", "%s"]\n    }' "$pkg"
        ;;
      postgres)
        printf '    "postgres": {\n      "command": "npx",\n      "args": ["-y", "%s", "${DATABASE_URL}"]\n    }' "$pkg"
        ;;
      figma)
        printf '    "figma": {\n      "command": "npx",\n      "args": ["-y", "%s"],\n      "env": { "FIGMA_ACCESS_TOKEN": "${FIGMA_TOKEN}" }\n    }' "$pkg"
        ;;
      trello)
        printf '    "trello": {\n      "command": "npx",\n      "args": ["-y", "%s"],\n      "env": { "TRELLO_API_KEY": "${TRELLO_API_KEY}", "TRELLO_TOKEN": "${TRELLO_TOKEN}", "TRELLO_BOARD_ID": "${TRELLO_BOARD_ID}" }\n    }' "$pkg"
        ;;
      jira)
        printf '    "jira": {\n      "command": "npx",\n      "args": ["-y", "%s"],\n      "env": { "ATLASSIAN_SITE_NAME": "${ATLASSIAN_SITE_NAME}", "ATLASSIAN_USER_EMAIL": "${ATLASSIAN_USER_EMAIL}", "ATLASSIAN_API_TOKEN": "${ATLASSIAN_API_TOKEN}" }\n    }' "$pkg"
        ;;
      linear)
        printf '    "linear": {\n      "command": "npx",\n      "args": ["-y", "%s"],\n      "env": { "LINEAR_API_KEY": "${LINEAR_API_KEY}" }\n    }' "$pkg"
        ;;
      migration-fs)
        printf '    "filesystem-v1": {\n      "command": "npx",\n      "args": ["-y", "%s", "%s/%s"]\n    }' "$pkg" "$parent_dir" "$v1_candidate"
        ;;
      *)
        # Community / experimental — leave a TODO so user wires it up themselves.
        printf '    "%s": {\n      "command": "npx",\n      "args": ["-y", "<TODO: install %s and replace this>"],\n      "_note": "community server — verify package name on npm"\n    }' "$id" "$id"
        ;;
    esac
  done
  printf '\n  }\n}\n'
  printf '```\n\n'

  printf '## Notes\n\n'
  printf -- '- **Idempotent recommendation**: re-running this script regenerates `_mcp-recommendations.md` from current signals. If you accept a recommendation, copy it into `.mcp.json` once — that file is yours to maintain.\n'
  printf -- '- **Per-developer secrets**: `${GITHUB_TOKEN}`, `${DATABASE_URL}`, `${FIGMA_TOKEN}`, `${TRELLO_API_KEY}` / `${TRELLO_TOKEN}` / `${TRELLO_BOARD_ID}`, `${ATLASSIAN_SITE_NAME}` / `${ATLASSIAN_USER_EMAIL}` / `${ATLASSIAN_API_TOKEN}`, `${LINEAR_API_KEY}` are env-var placeholders. Set them in your shell profile or `.env`, not in `.mcp.json` (which may be committed). Task-provider servers (`trello` / `jira` / `linear`) back the `/task` command — verify each server'"'"'s exact env-var names against its README.\n'
  printf -- '- **Community servers** are flagged as `(community)` when no official `@modelcontextprotocol/server-*` package exists. Verify on npm before installing.\n'
  printf -- '- **MCP server inventory** (recommended at this point, %d servers):\n' "${#RECS[@]}"
  for r in "${RECS[@]}"; do
    IFS='|' read -r id name pkg why <<<"$r"
    printf -- '  - `%s` — %s\n' "$id" "$name"
  done
} > "$REPORT"

[[ $QUIET -eq 0 ]] && echo "Recommended ${#RECS[@]} MCP server(s); report: $REPORT" >&2

# ---------- --apply: merge recommendations into <target>/.mcp.json ----------
if [[ $APPLY -eq 1 ]]; then
  MCP_FILE="$TARGET/.mcp.json"
  V1_DIR=""
  if [[ -n "${v1_candidate:-}" && -d "$parent_dir/$v1_candidate" ]]; then
    V1_DIR="$parent_dir/$v1_candidate"
  fi

  # Pass the recommendation list to python via env var (newline-separated id|pkg).
  # python composes the per-server config matching the report's JSON shape, then
  # MERGES into existing .mcp.json without clobbering anything the user added.
  RECS_JOINED=$(printf '%s\n' "${RECS[@]}")

  RECS_JOINED="$RECS_JOINED" V1_DIR="$V1_DIR" MCP_FILE="$MCP_FILE" QUIET="$QUIET" \
  python3 - <<'PY'
import json, os, sys, pathlib

mcp_file = pathlib.Path(os.environ["MCP_FILE"])
v1_dir = os.environ.get("V1_DIR", "")
quiet = os.environ.get("QUIET", "0") == "1"
recs_raw = os.environ.get("RECS_JOINED", "").strip()
if not recs_raw:
    sys.exit(0)

# Parse recs: "id|name|package|rationale"
recs = []
for line in recs_raw.split("\n"):
    if not line:
        continue
    parts = line.split("|", 3)
    if len(parts) >= 3:
        recs.append({"id": parts[0], "name": parts[1], "package": parts[2]})

def server_config(rec):
    rid, pkg = rec["id"], rec["package"]
    if rid == "filesystem":
        return {"command": "npx", "args": ["-y", pkg, "${PWD}"]}
    if rid == "github":
        return {
            "command": "npx",
            "args": ["-y", pkg],
            "env": {"GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"},
        }
    if rid in ("playwright", "puppeteer"):
        return {"command": "npx", "args": ["-y", pkg]}
    if rid == "postgres":
        return {"command": "npx", "args": ["-y", pkg, "${DATABASE_URL}"]}
    if rid == "figma":
        return {
            "command": "npx",
            "args": ["-y", pkg],
            "env": {"FIGMA_ACCESS_TOKEN": "${FIGMA_TOKEN}"},
        }
    if rid == "trello":
        return {
            "command": "npx",
            "args": ["-y", pkg],
            "env": {
                "TRELLO_API_KEY": "${TRELLO_API_KEY}",
                "TRELLO_TOKEN": "${TRELLO_TOKEN}",
                "TRELLO_BOARD_ID": "${TRELLO_BOARD_ID}",
            },
        }
    if rid == "jira":
        return {
            "command": "npx",
            "args": ["-y", pkg],
            "env": {
                "ATLASSIAN_SITE_NAME": "${ATLASSIAN_SITE_NAME}",
                "ATLASSIAN_USER_EMAIL": "${ATLASSIAN_USER_EMAIL}",
                "ATLASSIAN_API_TOKEN": "${ATLASSIAN_API_TOKEN}",
            },
        }
    if rid == "linear":
        return {
            "command": "npx",
            "args": ["-y", pkg],
            "env": {"LINEAR_API_KEY": "${LINEAR_API_KEY}"},
        }
    if rid == "migration-fs":
        # The package field is filesystem; the args carry the V1 dir.
        target_dir = v1_dir or "${V1_DIR}"
        # Use a different server key so it doesn't collide with filesystem.
        return {"_key": "filesystem-v1",
                "command": "npx",
                "args": ["-y", pkg, target_dir]}
    # Community / experimental — leave a TODO so the user notices.
    return {
        "command": "npx",
        "args": ["-y", f"<TODO: install {rid}-mcp and replace this>"],
        "_note": "community server — verify package name on npm",
    }

# Compose the full recommended map (key → config).
recommended = {}
for rec in recs:
    cfg = server_config(rec)
    key = cfg.pop("_key", rec["id"])
    recommended[key] = cfg

# Load existing .mcp.json if any.
if mcp_file.exists():
    try:
        existing = json.loads(mcp_file.read_text())
    except json.JSONDecodeError as e:
        print(f"ERR: existing {mcp_file} is not valid JSON ({e}). Will not overwrite — fix it manually first.", file=sys.stderr)
        sys.exit(1)
    if not isinstance(existing, dict):
        print(f"ERR: existing {mcp_file} root is not an object — refusing to merge.", file=sys.stderr)
        sys.exit(1)
else:
    existing = {}

servers = existing.get("mcpServers", {})
if not isinstance(servers, dict):
    print("ERR: existing .mcp.json has non-object mcpServers — refusing to merge.", file=sys.stderr)
    sys.exit(1)

added = []
preserved = []
for key, cfg in recommended.items():
    if key in servers:
        preserved.append(key)
    else:
        servers[key] = cfg
        added.append(key)

existing["mcpServers"] = servers

# Write atomically: temp + rename
tmp = mcp_file.with_suffix(".json.tmp")
tmp.write_text(json.dumps(existing, indent=2) + "\n")
tmp.replace(mcp_file)

if not quiet:
    if added:
        print(f"  + added to .mcp.json: {', '.join(added)}", file=sys.stderr)
    if preserved:
        print(f"  = preserved (already present): {', '.join(preserved)}", file=sys.stderr)
    user_only = [k for k in servers if k not in recommended]
    if user_only:
        print(f"  · user-managed (untouched): {', '.join(user_only)}", file=sys.stderr)
PY
fi

exit 0
