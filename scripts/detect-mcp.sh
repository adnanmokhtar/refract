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
  echo "Usage: $0 <target-repo> [--quiet]" >&2
  exit 2
fi

TARGET="$1"; shift
QUIET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
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
  printf -- '- **Per-developer secrets**: `${GITHUB_TOKEN}`, `${DATABASE_URL}`, `${FIGMA_TOKEN}` are env-var placeholders. Set them in your shell profile or `.env`, not in `.mcp.json` (which may be committed).\n'
  printf -- '- **Community servers** are flagged as `(community)` when no official `@modelcontextprotocol/server-*` package exists. Verify on npm before installing.\n'
  printf -- '- **MCP server inventory** (recommended at this point, %d servers):\n' "${#RECS[@]}"
  for r in "${RECS[@]}"; do
    IFS='|' read -r id name pkg why <<<"$r"
    printf -- '  - `%s` — %s\n' "$id" "$name"
  done
} > "$REPORT"

[[ $QUIET -eq 0 ]] && echo "Recommended ${#RECS[@]} MCP server(s); report: $REPORT" >&2
exit 0
