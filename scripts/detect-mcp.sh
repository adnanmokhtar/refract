#!/usr/bin/env bash
# detect-mcp.sh — recommend MCP servers based on project signals.
#
# Reads the same signals detect-tracks.sh uses (package.json deps, manifest
# files, top-level dirs, sibling V1/V2 layout) and emits a per-project
# recommendation report:
#   <target>/.claude/_mcp-recommendations.md
#
# ---------------------------------------------------------------------------
# OWNERSHIP CONTRACT for `<target>/.mcp.json` — the code, the header and the
# report MUST agree. They did not, and the disagreement shipped:
#
#   WITHOUT --apply  the script writes ONLY the report. `.mcp.json` is read
#                    (to say what is already wired) and never modified.
#
#   WITH --apply     the script MAY write `<target>/.mcp.json`, ADDITIVELY ONLY:
#                    it adds server keys that are absent, and never edits,
#                    reorders or removes a key that is already there. If it has
#                    nothing to add, it does not touch the file at all. The
#                    user's entries always win. `--apply` is what
#                    `scripts/run-preflight.sh` (STEP 0.5) passes, and what
#                    `docs/TASK-PROVIDERS.md` tells users to run.
#
#   NEVER            a placeholder. A server whose real package is unknown
#                    (community / not yet published) is reported as UNWIRED and
#                    written NOWHERE — not into `.mcp.json`, not into the
#                    copy-pasteable block. `"args": ["-y","<TODO: …>"]` is
#                    configuration that looks valid and fails at startup, which
#                    is strictly worse than an absent entry.
#
#   EVIDENCE         database servers are gated on the DECLARED engine — the
#                    Prisma `datasource … provider =` line, `DB_TYPE`, the DSN
#                    scheme, or the driver package. The mere EXISTENCE of a
#                    Prisma schema is not a Postgres signal (it used to be, and
#                    put a Postgres MCP into a MySQL-only repo). A DSN counts
#                    only as the value of a LIVE assignment (`env_dsn`): a
#                    commented-out or prose `postgres://` is not a declaration,
#                    and used to re-open the same false positive from the other
#                    side. THE SAME RULE BINDS EVERY env SIGNAL, not just DSNs —
#                    `env_var_set` gates the Trello / Jira / Linear credential
#                    families and the `POSTGRES_*` / `MYSQL_*` families on an
#                    actual assignment. Those three project-management servers
#                    are `wired=1`, so `# we removed Trello in 2025;
#                    TRELLO_API_KEY was here.` did not merely mis-report — it
#                    wrote a Trello entry into the user's tracked `.mcp.json`.
# ---------------------------------------------------------------------------
#
# Usage:
#   detect-mcp.sh <target-repo> [--apply] [--quiet] [--stdout | --report=<path>]
#
#   --stdout        READ-ONLY mode (alias: --no-write). Report goes to stdout and NOTHING
#                   is created under <target-repo> — not the report, not `.claude/`.
#                   Refused together with --apply, which exists to write.
#   --report=<path> Write the report to <path> instead. Must use `=`.
#
# Exit codes:
#   0 — clean (INCLUDING "--apply could not write .mcp.json": the report is
#       still written, says so in a "Blocked" section, and stderr carries an
#       ERR line. run-preflight.sh runs under `set -o pipefail`, so a non-zero
#       here would halt the whole setup over a file this script does not own.)
#   1 — target missing
#   2 — usage error

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--apply] [--quiet] [--stdout|--report=<path>]" >&2
  echo "       --stdout = read-only: report on stdout, nothing written under <target-repo>." >&2
  exit 2
fi

TARGET="$1"; shift
QUIET=0
APPLY=0
SINK_STDOUT=0
REPORT_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --stdout|--no-write) SINK_STDOUT=1; shift ;;
    --report=*) REPORT_OVERRIDE="${1#*=}"; shift ;;
    --report) echo "ERR: use --report=<path> (with '='), not --report <path>" >&2; exit 2 ;;
    *)       echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# --apply exists to write `<target>/.mcp.json`; --stdout promises the opposite. Refuse the
# pair rather than silently honouring one — a "read-only" flag that still wrote .mcp.json
# would be worse than no flag at all.
if [[ $SINK_STDOUT -eq 1 && $APPLY -eq 1 ]]; then
  echo "ERR: --stdout (read-only) and --apply (writes <target>/.mcp.json) are mutually exclusive." >&2
  exit 2
fi

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

# ── Report sink ────────────────────────────────────────────────────────────────
# The default sink is a file INSIDE the target, so a bare no-flag run — the mode whose
# whole contract is "writes ONLY the report, .mcp.json is read and never modified" —
# still wrote to the repo, and the mkdir created `.claude/` in a target that had none.
REPORT="$TARGET/.claude/_mcp-recommendations.md"
REPORT_TMP=""
if [[ $SINK_STDOUT -eq 1 ]]; then
  REPORT_TMP=$(mktemp "${TMPDIR:-/tmp}/mcp-recommendations.XXXXXX")
  REPORT="$REPORT_TMP"
  REPORT_LABEL="(stdout — nothing written under $TARGET)"
else
  [[ -n "$REPORT_OVERRIDE" ]] && REPORT="$REPORT_OVERRIDE"
  mkdir -p "$(dirname "$REPORT")"
  REPORT_LABEL="$REPORT"
fi

# NOTE: returns 0 even when quiet — a bare `[[…]] && echo` would yield exit 1
# under `set -e` when QUIET=1, and since add_rec ends in a trace call that would
# abort the run on the first recommendation.
trace() { [[ $QUIET -eq 0 ]] && echo "  • $*" >&2; return 0; }

# Read package.json deps if present (same parser shape as detect-tracks.sh).
# jq-first: the awk parser silently returns ZERO keys on minified/compact JSON
# (no per-line braces to anchor on). Fall back to awk only when jq is missing OR
# jq yields nothing (e.g. malformed JSON jq couldn't parse).
PKG="$TARGET/package.json"
PKG_DEPS=""
parse_pkg_deps() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '[(.dependencies//{}|keys[]),(.devDependencies//{}|keys[]),(.peerDependencies//{}|keys[])] | .[]' "$1" 2>/dev/null
  fi
}
parse_pkg_deps_awk() {
  awk '
    /"(dependencies|devDependencies|peerDependencies)"[[:space:]]*:/ { in_block=1; next }
    in_block && /^[[:space:]]*}/ { in_block=0; next }
    in_block && /"[^"]+"[[:space:]]*:/ {
      gsub(/^[[:space:]]*"/, "")
      sub(/"[[:space:]]*:.*$/, "")
      print
    }
  ' "$1" 2>/dev/null
}
if [[ -f "$PKG" ]]; then
  PKG_DEPS=$(parse_pkg_deps "$PKG" | tr '\n' ' ')
  if [[ -z "${PKG_DEPS// /}" ]]; then
    PKG_DEPS=$(parse_pkg_deps_awk "$PKG" | tr '\n' ' ')
  fi
fi
has_dep() { [[ " $PKG_DEPS " == *" $1 "* ]]; }
has_dep_prefix() { [[ " $PKG_DEPS " == *" $1"* ]]; }

# ---------- Env files (dotenv-family, whichever exist) ----------
# Array, not a space-joined string: a target path may contain spaces.
declare -a ENV_FILES=()
for _f in "$TARGET/.env" "$TARGET/.env.example" "$TARGET/.env.sample" "$TARGET/.env.local"; do
  [[ -f "$_f" ]] && ENV_FILES+=("$_f")
done
# grep across whatever env files exist; false when there are none.
env_grep() {
  [[ ${#ENV_FILES[@]} -gt 0 ]] || return 1
  grep -qiE "$1" "${ENV_FILES[@]}" 2>/dev/null
}

# A DSN is evidence ONLY when it is the value of a live assignment.
# `env_grep` is unanchored, so `# we no longer use postgres://legacy-host/db`
# used to register Postgres over an explicit `DB_TYPE=mysql` — the same false
# positive the header says was closed, re-entering through the DSN door.
# Require: line start, optional `export`, a VAR name, `=`, and no `#` between
# the `=` and the scheme (so a trailing comment cannot supply the evidence).
env_dsn() {  # <scheme-regex>
  env_grep "^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[^#]*$1"
}

# Same rule for a credential FAMILY: the var must be assigned, not merely
# mentioned. `env_grep 'TRELLO_(API_KEY|TOKEN|...)'` matched
# `# We removed Trello in 2025; TRELLO_API_KEY was here.` and wrote a Trello MCP
# into the user's tracked `.mcp.json` — these three servers are `wired=1`, so a
# false positive here is written config, not just a report line.
env_var_set() {  # <var-name-regex>
  env_grep "^[[:space:]]*(export[[:space:]]+)?($1)[[:space:]]*="
}

# ---------- Database engine resolution (evidence, not guesswork) ----------
# An ORM project's ENGINE is DECLARED, not implied. Four independent sources,
# any of which is proof; none of which is "a schema file exists".
DB_ENGINES=""     # space-separated set drawn from: postgres mysql mongo sqlite mssql
DB_EVIDENCE=""    # "engine ← what proved it", one clause each, printed in the report

db_add() { # <engine> <evidence-text>
  case " $DB_ENGINES " in
    *" $1 "*) return 0 ;;
  esac
  DB_ENGINES="${DB_ENGINES}${DB_ENGINES:+ }$1"
  DB_EVIDENCE="${DB_EVIDENCE}${DB_EVIDENCE:+; }\`$1\` ← $2"
}
has_engine() { case " $DB_ENGINES " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# (a) Prisma — read the datasource `provider = "…"` value. Covers the single-file
#     schema and the multi-file `prisma/schema/*.prisma` layout. `prisma-client-js`
#     and friends are generator providers and are ignored by the map below.
declare -a PRISMA_SCHEMAS=()
for _f in "$TARGET/prisma/schema.prisma" "$TARGET"/prisma/schema/*.prisma "$TARGET/schema.prisma"; do
  [[ -f "$_f" ]] && PRISMA_SCHEMAS+=("$_f")
done
if [[ ${#PRISMA_SCHEMAS[@]} -gt 0 ]]; then
  for _f in "${PRISMA_SCHEMAS[@]}"; do
    while IFS= read -r prov; do
      [[ -n "$prov" ]] || continue
      case "$prov" in
        postgresql|postgres|cockroachdb) db_add postgres "\`$(basename "$_f")\` datasource provider = \"$prov\"" ;;
        mysql|mariadb)                   db_add mysql    "\`$(basename "$_f")\` datasource provider = \"$prov\"" ;;
        mongodb)                         db_add mongo    "\`$(basename "$_f")\` datasource provider = \"$prov\"" ;;
        sqlite)                          db_add sqlite   "\`$(basename "$_f")\` datasource provider = \"$prov\"" ;;
        sqlserver)                       db_add mssql    "\`$(basename "$_f")\` datasource provider = \"$prov\"" ;;
        *) : ;;  # prisma-client-js / prisma-client-py / … — a generator, not an engine
      esac
    done < <(sed -n 's/^[[:space:]]*provider[[:space:]]*=[[:space:]]*"\([A-Za-z]*\)".*/\1/p' "$_f")
  done
fi

# (b) Driver packages — unambiguous.
if has_dep pg || has_dep '@types/pg' || has_dep pg-promise || has_dep postgres || has_dep '@vercel/postgres'; then
  db_add postgres "Postgres driver in \`package.json\`"
fi
if has_dep mysql || has_dep mysql2 || has_dep mariadb; then
  db_add mysql "MySQL driver in \`package.json\`"
fi
if has_dep mongoose || has_dep mongodb || has_dep_prefix '@mongoose/'; then
  db_add mongo "MongoDB driver in \`package.json\`"
fi
if has_dep sqlite3 || has_dep better-sqlite3; then
  db_add sqlite "SQLite driver in \`package.json\`"
fi

# (c) DSN scheme in the env files — the scheme IS the engine.
env_dsn 'postgres(ql)?://'   && db_add postgres "\`postgres://\` DSN assigned in an env file"
env_dsn 'mysql://'           && db_add mysql    "\`mysql://\` DSN assigned in an env file"
env_dsn 'mongodb(\+srv)?://' && db_add mongo    "\`mongodb://\` DSN assigned in an env file"

# (d) TypeORM / Sequelize style `DB_TYPE=`/`DB_CONNECTION=`/`DB_DIALECT=` declaration.
env_grep '^[[:space:]]*(export[[:space:]]+)?(DB_TYPE|DB_CONNECTION|DB_DIALECT|DATABASE_TYPE)[[:space:]]*=[[:space:]]*"?(postgres|postgresql|pgsql)' \
  && db_add postgres "\`DB_TYPE=postgres\` in an env file"
env_grep '^[[:space:]]*(export[[:space:]]+)?(DB_TYPE|DB_CONNECTION|DB_DIALECT|DATABASE_TYPE)[[:space:]]*=[[:space:]]*"?(mysql|mariadb)' \
  && db_add mysql "\`DB_TYPE=mysql\` in an env file"
env_grep '^[[:space:]]*(export[[:space:]]+)?(DB_TYPE|DB_CONNECTION|DB_DIALECT|DATABASE_TYPE)[[:space:]]*=[[:space:]]*"?mongodb' \
  && db_add mongo "\`DB_TYPE=mongodb\` in an env file"

# (e) Engine-specific env-var families (docker-compose style).
env_var_set '(POSTGRES_(USER|PASSWORD|DB|HOST)|PG(HOST|USER|PASSWORD|DATABASE))' \
  && db_add postgres "\`POSTGRES_*\`/\`PG*\` vars in an env file"
env_var_set 'MYSQL_(ROOT_PASSWORD|USER|PASSWORD|DATABASE|HOST)' \
  && db_add mysql "\`MYSQL_*\` vars in an env file"

[[ -n "$DB_ENGINES" ]] && trace "database engine(s): $DB_ENGINES"

# Server registry: pipe-separated rows
#   id|name|package|wired|rationale
# wired=1 → a real, installable package AND a known config shape; may be written.
# wired=0 → no known package; REPORT ONLY, never emitted as config anywhere.
# `rationale` is last so it may contain `|` without breaking the split.
declare -a RECS

add_rec() {          # <id> <name> <package> <rationale>   — runnable, writable
  RECS+=("$1|$2|$3|1|$4")
  trace "$1 → $2"
}
add_rec_unwired() {  # <id> <name> <where-to-look> <rationale> — reported only
  RECS+=("$1|$2|$3|0|$4")
  trace "$1 → $2 (UNWIRED — no known package; nothing will be written)"
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
  # Auth-gated? If the app guards routes (requiresAuth / a route guard / a /login redirect /
  # <PrivateRoute>), a session-less Playwright MCP lands on /login and every screenshot is
  # worthless. When a saved session already exists (tests/.auth/user.json, written by the
  # visual-check auth scaffold), wire it into the MCP so gated routes actually render. Only
  # added when the file EXISTS — pointing --storage-state at a missing file would crash the MCP;
  # a refresh after the human runs tests/auth.setup.ts self-heals this.
  AUTH_GATED=0
  if grep -rqiE 'requiresAuth|PrivateRoute|authGuard|redirect.*/login|meta:[^}]*requiresAuth' "$TARGET/src" 2>/dev/null; then
    AUTH_GATED=1
  fi
  add_rec "playwright" "Playwright MCP" "@playwright/mcp" \
    "Frontend stack detected — drive the running app: navigate, click, type, screenshot, assert. Single best tool for UI feature verification."
  add_rec "puppeteer" "Puppeteer MCP" "@modelcontextprotocol/server-puppeteer" \
    "Frontend stack detected — alternate to Playwright for headless Chromium tasks (lighter dependency footprint, fewer browser engines)."
fi

# ---------- Storybook (frontend + .storybook dir) ----------
if [[ $FRONTEND -eq 1 && -d "$TARGET/.storybook" ]]; then
  add_rec_unwired "storybook" "Storybook MCP" "no official server — search npm for a Storybook MCP" \
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

# ---------- Database servers — gated on the RESOLVED engine, never on "a schema exists" ----------
if has_engine postgres; then
  add_rec "postgres" "Postgres MCP" "@modelcontextprotocol/server-postgres" \
    "Postgres is the declared engine — read-only query agent for schema inspection + analysis."
fi
if has_engine mysql; then
  add_rec_unwired "mysql" "MySQL MCP" "no official \`@modelcontextprotocol/server-mysql\` — search npm for a MySQL MCP" \
    "MySQL is the declared engine — schema introspection + query helper. **Nothing is written**: no MCP server package is known for MySQL, and a guessed name would fail at startup."
fi
if has_engine mongo; then
  add_rec_unwired "mongodb" "MongoDB MCP" "no official server — search npm for a MongoDB MCP" \
    "MongoDB is the declared engine — collection introspection + sample queries."
fi

# ---------- Mobile (iOS + Android) ----------
if [[ -d "$TARGET/ios" && -d "$TARGET/android" ]] || has_dep react-native \
   || has_dep '@capacitor/core' || has_dep expo; then
  add_rec_unwired "ios-simulator" "iOS Simulator MCP" "no official server — search npm for an iOS Simulator MCP" \
    "Mobile project — drive iOS Simulator (boot, install, screenshot, gesture)."
  add_rec_unwired "android-emulator" "Android Emulator MCP" "no official server — search npm for an Android Emulator MCP" \
    "Mobile project — drive Android Emulator (avd, install, adb commands, screenshot)."
fi

# ---------- DevOps / Infrastructure ----------
if [[ -f "$TARGET/Dockerfile" || -f "$TARGET/docker-compose.yml" || -f "$TARGET/docker-compose.yaml" ]]; then
  add_rec_unwired "docker" "Docker MCP" "no official server — search npm for a Docker MCP" \
    "Dockerfile / compose detected — list containers, inspect, exec, log-tail without leaving the dev loop."
fi
if compgen -G "$TARGET/*.tf" >/dev/null 2>&1 || [[ -d "$TARGET/terraform" ]]; then
  add_rec_unwired "terraform" "Terraform MCP" "no official npm server — check HashiCorp's registry" \
    "Terraform config detected — plan/show/state inspection without ad-hoc shell."
fi

# ---------- Project management (Trello) ----------
# No codebase footprint — gate on this repo's OWN Trello credentials so each
# repo wires its own board/account. Keys live in the repo's .env, never here.
if env_var_set 'TRELLO_(API_KEY|TOKEN|BOARD_ID|BOARD_NAME)' || [[ -f "$TARGET/.trello.json" ]]; then
  add_rec "trello" "Trello MCP" "@delorenj/mcp-server-trello" \
    "Trello credentials detected (\`TRELLO_*\` in .env) — pull this repo's board into the dev loop: read cards/lists, move cards, comment, check off items. Per-repo board via \`TRELLO_BOARD_ID\`. Backs /task (provider=trello)."
fi

# ---------- Project management (Jira) ----------
# Gate on this repo's own Atlassian credentials. Backs /task (provider=jira).
if env_var_set '(JIRA|ATLASSIAN)_(URL|SITE_NAME|USER|USER_EMAIL|USERNAME|API_TOKEN|TOKEN)'; then
  add_rec "jira" "Jira MCP" "@aashari/mcp-server-atlassian-jira" \
    "Jira/Atlassian credentials detected in .env — pull this repo's issues into /task: read issue, transition status, comment. Per-repo project. Verify env-var names against the server README."
fi

# ---------- Project management (Linear) ----------
# Gate on this repo's own Linear API key. Backs /task (provider=linear).
if env_var_set 'LINEAR_API_KEY'; then
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

WIRED_N=0
UNWIRED_N=0
for r in "${RECS[@]}"; do
  IFS='|' read -r _id _name _pkg _wired _why <<<"$r"
  if [[ "$_wired" == "1" ]]; then WIRED_N=$((WIRED_N+1)); else UNWIRED_N=$((UNWIRED_N+1)); fi
done

# ---------- .mcp.json: inspect always, write only under --apply ----------
# Runs BEFORE the report is built so the report can state what actually happened
# instead of asserting a policy the caller contradicts.
MCP_FILE="$TARGET/.mcp.json"
STATE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/detect-mcp.XXXXXX")
trap 'rm -rf "$STATE_DIR" ${REPORT_TMP:+"$REPORT_TMP"}' EXIT
STATE="$STATE_DIR/state"
: > "$STATE"

V1_DIR=""
if [[ -n "${v1_candidate:-}" && -d "$parent_dir/$v1_candidate" ]]; then
  V1_DIR="$parent_dir/$v1_candidate"
fi

if command -v python3 >/dev/null 2>&1; then
  RECS_JOINED=$(printf '%s\n' "${RECS[@]}")
  RECS_JOINED="$RECS_JOINED" V1_DIR="$V1_DIR" MCP_FILE="$MCP_FILE" \
  QUIET="$QUIET" APPLY="$APPLY" STATE="$STATE" \
  python3 - <<'PY'
import json, os, pathlib, sys

state     = pathlib.Path(os.environ["STATE"])
mcp_file  = pathlib.Path(os.environ["MCP_FILE"])
apply_on  = os.environ.get("APPLY", "0") == "1"
quiet     = os.environ.get("QUIET", "0") == "1"
v1_dir    = os.environ.get("V1_DIR", "")
recs_raw  = os.environ.get("RECS_JOINED", "").strip()

lines = []
def emit(k, v):
    lines.append("%s\t%s" % (k, v))
def finish(code=0):
    state.write_text("\n".join(lines) + "\n")
    sys.exit(code)

# Parse "id|name|package|wired|rationale". UNWIRED rows are dropped here and
# never reach any config-emitting path — that is the whole no-placeholder rule.
recs, dropped = [], []
for line in recs_raw.split("\n"):
    if not line:
        continue
    parts = line.split("|", 4)
    if len(parts) < 4:
        continue
    if parts[3] != "1":
        dropped.append(parts[0])
        continue
    recs.append({"id": parts[0], "name": parts[1], "package": parts[2]})
emit("unwired_skipped", ",".join(dropped))

def server_config(rec):
    rid, pkg = rec["id"], rec["package"]
    if rid == "filesystem":
        return {"command": "npx", "args": ["-y", pkg, "${PWD}"]}
    if rid == "github":
        return {"command": "npx", "args": ["-y", pkg],
                "env": {"GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"}}
    if rid == "postgres":
        return {"command": "npx", "args": ["-y", pkg, "${DATABASE_URL}"]}
    if rid == "figma":
        return {"command": "npx", "args": ["-y", pkg],
                "env": {"FIGMA_ACCESS_TOKEN": "${FIGMA_TOKEN}"}}
    if rid == "trello":
        return {"command": "npx", "args": ["-y", pkg],
                "env": {"TRELLO_API_KEY": "${TRELLO_API_KEY}",
                        "TRELLO_TOKEN": "${TRELLO_TOKEN}",
                        "TRELLO_BOARD_ID": "${TRELLO_BOARD_ID}"}}
    if rid == "jira":
        return {"command": "npx", "args": ["-y", pkg],
                "env": {"ATLASSIAN_SITE_NAME": "${ATLASSIAN_SITE_NAME}",
                        "ATLASSIAN_USER_EMAIL": "${ATLASSIAN_USER_EMAIL}",
                        "ATLASSIAN_API_TOKEN": "${ATLASSIAN_API_TOKEN}"}}
    if rid == "linear":
        return {"command": "npx", "args": ["-y", pkg],
                "env": {"LINEAR_API_KEY": "${LINEAR_API_KEY}"}}
    if rid == "migration-fs":
        # package is the filesystem server; the extra arg carries the V1 dir.
        # Distinct key so it cannot collide with `filesystem`.
        return {"_key": "filesystem-v1", "command": "npx",
                "args": ["-y", pkg, v1_dir or "${V1_DIR}"]}
    # Every remaining WIRED row carries a real package name, so the generic
    # `npx -y <package>` shape is runnable as-is (playwright, puppeteer, …).
    return {"command": "npx", "args": ["-y", pkg]}

recommended = {}
for rec in recs:
    cfg = server_config(rec)
    key = cfg.pop("_key", rec["id"])
    recommended[key] = cfg

# ---- Read the existing file (always; this half never writes) ----
existing, parse_error = None, ""
if mcp_file.exists():
    try:
        loaded = json.loads(mcp_file.read_text())
    except json.JSONDecodeError as e:
        parse_error = "not valid JSON (%s)" % e
    else:
        if isinstance(loaded, dict):
            existing = loaded
        else:
            parse_error = "root is not a JSON object"

servers_now = {}
if isinstance(existing, dict):
    s = existing.get("mcpServers", {})
    if isinstance(s, dict):
        servers_now = s
    else:
        parse_error = parse_error or "`mcpServers` is not an object"

# Placeholder audit — find `<TODO …>` args an EARLIER version of this script (or
# a hand edit) left behind. Reported, never silently rewritten: the file is the
# user's, and healing it would be an edit to a key they own.
placeholders = []
for k, cfg in servers_now.items():
    if isinstance(cfg, dict):
        for a in (cfg.get("args") or []):
            if isinstance(a, str) and "<TODO" in a:
                placeholders.append(k)
                break
emit("placeholders", ",".join(sorted(placeholders)))
emit("exists", "yes" if mcp_file.exists() else "no")
emit("present", ",".join(sorted(servers_now.keys())))

if not apply_on:
    emit("applied", "no")
    finish()

if parse_error:
    emit("applied", "blocked")
    emit("error", "%s %s — refusing to write; fix it by hand and re-run." % (mcp_file, parse_error))
    print("ERR: %s %s — .mcp.json NOT written." % (mcp_file, parse_error), file=sys.stderr)
    finish()

if existing is None:
    existing = {}

added, preserved = [], []
for key, cfg in recommended.items():
    if key in servers_now:
        preserved.append(key)
    else:
        servers_now[key] = cfg
        added.append(key)

emit("added", ",".join(added))
emit("preserved", ",".join(preserved))
emit("user_only", ",".join(k for k in servers_now if k not in recommended))

if not added:
    # Nothing to add → do not touch the file at all (no reformat, no mtime bump).
    emit("applied", "noop")
    if not quiet:
        print("  = .mcp.json already has every wired recommendation — not written.", file=sys.stderr)
    finish()

existing["mcpServers"] = servers_now
tmp = mcp_file.with_suffix(".json.tmp")
tmp.write_text(json.dumps(existing, indent=2) + "\n")
tmp.replace(mcp_file)
emit("applied", "yes")

if not quiet:
    print("  + added to .mcp.json: %s" % ", ".join(added), file=sys.stderr)
    if preserved:
        print("  = preserved (already present): %s" % ", ".join(preserved), file=sys.stderr)
finish()
PY
else
  printf 'no-python3\t1\n' >> "$STATE"
  if [[ $APPLY -eq 1 ]]; then
    echo "ERR: python3 not found — .mcp.json NOT written. Copy the block from $REPORT by hand." >&2
  fi
fi

# Read the state file back into shell vars (bash 3.2: no associative arrays).
st_applied=""; st_added=""; st_preserved=""; st_user_only=""
st_placeholders=""; st_present=""; st_exists=""; st_error=""; st_unwired_skipped=""
st_nopython=""
while IFS=$'\t' read -r k v; do
  case "$k" in
    applied)         st_applied="$v" ;;
    added)           st_added="$v" ;;
    preserved)       st_preserved="$v" ;;
    user_only)       st_user_only="$v" ;;
    placeholders)    st_placeholders="$v" ;;
    present)         st_present="$v" ;;
    exists)          st_exists="$v" ;;
    error)           st_error="$v" ;;
    unwired_skipped) st_unwired_skipped="$v" ;;
    no-python3)      st_nopython="1" ;;
  esac
done < "$STATE"

# "a,b" -> "`a`, `b`"; empty in, empty out.
commafy() { [[ -n "$1" ]] || { echo ""; return 0; }; echo "$1" | sed 's/,/`, `/g; s/^/`/; s/$/`/'; }

# ---------- Build report ----------
{
  printf '# MCP server recommendations — %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Target: `%s`\n\n' "$TARGET"
  printf 'Generated by: scripts/detect-mcp.sh%s\n\n' "$([[ $APPLY -eq 1 ]] && echo ' --apply' || echo '')"

  # The ownership statement must describe THIS invocation, not a policy the
  # caller overrides. run-preflight.sh STEP 0.5 passes --apply.
  if [[ $APPLY -eq 1 ]]; then
    printf '> **`.mcp.json` ownership — this run used `--apply`, so it MAY have written the file.** The write is *additive only*: server keys that were already present are left exactly as the user wrote them, nothing is edited or removed, and if there was nothing to add the file was not touched at all. Only servers with a real, installable package are ever written — see **Unwired** below for the ones deliberately left out. What this run actually did is recorded under **`.mcp.json` — what this run did**.\n\n'
  else
    printf '> **`.mcp.json` ownership — this run did NOT use `--apply`, so nothing was written.** The file was read only, to report what is already wired. Re-run with `--apply` (which is what `scripts/run-preflight.sh` does) to additively merge the block below, or copy it by hand. Only servers with a real, installable package are ever written — see **Unwired** below.\n\n'
  fi
  printf -- '---\n\n'

  if [[ -n "$DB_ENGINES" ]]; then
    printf '## Database engine (evidence)\n\n'
    printf 'Detected: **%s**\n\n' "$DB_ENGINES"
    printf 'Evidence: %s\n\n' "$DB_EVIDENCE"
    printf 'Database MCP servers are gated on this. The presence of an ORM schema file is *not* on its own evidence of any engine — the `provider =` line inside it is.\n\n'
  else
    printf '## Database engine (evidence)\n\n'
    printf 'Detected: **none**. No datasource `provider =`, driver package, DSN scheme or `DB_TYPE=` declaration resolved to a database engine, so **no database MCP server is recommended**. Guessing one here is how a Postgres server ends up in a MySQL repo.\n\n'
  fi

  printf '## Wired servers (%d) — real packages, safe to run\n\n' "$WIRED_N"
  if [[ $WIRED_N -gt 0 ]]; then
    printf '| ID | Name | Package | Why |\n'
    printf '|---|---|---|---|\n'
    for r in "${RECS[@]}"; do
      IFS='|' read -r id name pkg wired why <<<"$r"
      [[ "$wired" == "1" ]] || continue
      printf '| `%s` | %s | `%s` | %s |\n' "$id" "$name" "$pkg" "$why"
    done
  else
    printf '_None._\n'
  fi
  printf '\n'

  printf '## Unwired (%d) — reported only, written NOWHERE\n\n' "$UNWIRED_N"
  if [[ $UNWIRED_N -gt 0 ]]; then
    printf 'These ecosystems have a real signal in this repo but **no MCP server package this script can name**. Nothing is written for them — not into `.mcp.json`, not into the block below. A `"args": ["-y", "<TODO: …>"]` entry would look configured and fail the moment the server starts, which is worse than an absent entry. To wire one: find the package on npm yourself, verify it, then add the entry by hand.\n\n'
    printf '| ID | Name | Status | Why it was flagged |\n'
    printf '|---|---|---|---|\n'
    for r in "${RECS[@]}"; do
      IFS='|' read -r id name pkg wired why <<<"$r"
      [[ "$wired" == "0" ]] || continue
      printf '| `%s` | %s | %s | %s |\n' "$id" "$name" "$pkg" "$why"
    done
  else
    printf '_None — every signal in this repo maps to a real package._\n'
  fi
  printf '\n'

  printf '## Copy-pasteable `.mcp.json` block\n\n'
  if [[ $WIRED_N -eq 0 ]]; then
    printf '_Nothing to paste — no wired server was recommended._\n\n'
  else
    printf '> Merge into `<target>/.mcp.json`. Paths use `${PWD}` so the config is portable across checkouts; secrets are `${VAR}` references, never literals (this file is usually tracked). Contains the **wired** servers only.\n\n'
    printf '```json\n'
    printf '{\n  "mcpServers": {\n'
    first=1
    for r in "${RECS[@]}"; do
      IFS='|' read -r id name pkg wired why <<<"$r"
      [[ "$wired" == "1" ]] || continue
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
          if [[ "${AUTH_GATED:-0}" -eq 1 && -f "$TARGET/tests/.auth/user.json" ]]; then
            # Auth-gated app WITH a saved session → seed the browser so /dashboard/* renders
            # instead of redirecting to /login. Regenerate the session on expiry via
            # `npx playwright test tests/auth.setup.ts` (creds: E2E_EMAIL/E2E_PASSWORD in .env).
            printf '    "playwright": {\n      "command": "npx",\n      "args": ["-y", "%s", "--headless", "--isolated", "--storage-state", "tests/.auth/user.json"],\n      "_note": "auth-gated: --storage-state seeds the saved session; regenerate via tests/auth.setup.ts when it expires."\n    }' "$pkg"
          else
            printf '    "playwright": {\n      "command": "npx",\n      "args": ["-y", "%s"]\n    }' "$pkg"
          fi
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
          # Wired row with no bespoke shape → the generic runnable form. Never a
          # placeholder: a wired row is one whose package name is real.
          printf '    "%s": {\n      "command": "npx",\n      "args": ["-y", "%s"]\n    }' "$id" "$pkg"
          ;;
      esac
    done
    printf '\n  }\n}\n'
    printf '```\n\n'
  fi

  printf '## `.mcp.json` — what this run did\n\n'
  printf -- '- File: `%s` (%s)\n' "$MCP_FILE" "$([[ "$st_exists" == "yes" ]] && echo 'exists' || echo 'does not exist yet')"
  case "$st_applied" in
    yes)
      printf -- '- **Written** (additive merge). Added: %s\n' "$(commafy "$st_added")"
      [[ -n "$st_preserved" ]] && printf -- '- Left untouched because the key was already there: %s\n' "$(commafy "$st_preserved")"
      [[ -n "$st_user_only" ]] && printf -- '- Your own servers, untouched: %s\n' "$(commafy "$st_user_only")"
      ;;
    noop)
      printf -- '- **Not written.** Every wired recommendation was already present, so the file was not opened for writing at all.\n'
      [[ -n "$st_user_only" ]] && printf -- '- Your own servers, untouched: %s\n' "$(commafy "$st_user_only")"
      ;;
    blocked)
      printf -- '- **BLOCKED — nothing written.** %s\n' "$st_error"
      ;;
    no|"")
      if [[ -n "$st_nopython" ]]; then
        printf -- '- **Nothing written** — `python3` was not found, so the merge step could not run. Paste the block above by hand.\n'
      else
        printf -- '- **Nothing written** — run without `--apply` is read-only by contract.\n'
      fi
      [[ -n "$st_present" ]] && printf -- '- Already wired in that file: %s\n' "$(commafy "$st_present")"
      ;;
  esac
  [[ -n "$st_unwired_skipped" ]] && printf -- '- Deliberately NOT written (unwired, no known package): %s\n' "$(commafy "$st_unwired_skipped")"
  printf '\n'

  if [[ -n "$st_placeholders" ]]; then
    printf '> **⚠ Existing entries carry an unrunnable placeholder.** These keys in `%s` have a `<TODO: …>` string inside `args`, so `npx` will fail the moment the server starts: %s. An earlier version of this script emitted those; it no longer does. They are **your** keys, so this script will not edit them — delete each entry, or replace the placeholder with a package you have verified on npm.\n\n' \
      "$MCP_FILE" "$(commafy "$st_placeholders")"
  fi

  printf '## Notes\n\n'
  printf -- '- **Idempotent**: re-running regenerates `_mcp-recommendations.md` from current signals. With `--apply`, a re-run adds nothing that is already there and leaves the file alone when there is nothing to add.\n'
  printf -- '- **Per-developer secrets**: `${GITHUB_TOKEN}`, `${DATABASE_URL}`, `${FIGMA_TOKEN}`, `${TRELLO_API_KEY}` / `${TRELLO_TOKEN}` / `${TRELLO_BOARD_ID}`, `${ATLASSIAN_SITE_NAME}` / `${ATLASSIAN_USER_EMAIL}` / `${ATLASSIAN_API_TOKEN}`, `${LINEAR_API_KEY}` are env-var placeholders. Set them in your shell profile or `.env`, not in `.mcp.json` (which may be committed). Task-provider servers (`trello` / `jira` / `linear`) back the `/task` command — verify each server'"'"'s exact env-var names against its README.\n'
  printf -- '- **No placeholder configuration, ever**: if this script cannot name a real package for an ecosystem, it writes nothing for it and lists it under **Unwired** instead. An absent entry is honest; `["-y", "<TODO: …>"]` is a startup failure disguised as config.\n'
  [[ $FRONTEND -eq 1 ]] && printf -- '- **Playwright browser binary (REQUIRED turn-on step)**: the `playwright` MCP + `/visual-check` need a browser installed *separately* from the npm package. After adding the MCP, run `npx playwright install chromium` once. Without it, every browser action fails with `Executable doesn'"'"'t exist` — which reads as a cryptic MCP/session failure, not the one-command fix it is. Re-run after a Playwright version bump.\n'
  printf -- '- **MCP server inventory** (%d recommended: %d wired, %d unwired):\n' "${#RECS[@]}" "$WIRED_N" "$UNWIRED_N"
  for r in "${RECS[@]}"; do
    IFS='|' read -r id name pkg wired why <<<"$r"
    if [[ "$wired" == "1" ]]; then
      printf -- '  - `%s` — %s\n' "$id" "$name"
    else
      printf -- '  - `%s` — %s _(unwired — not written)_\n' "$id" "$name"
    fi
  done
} > "$REPORT"

# --stdout: the report was buffered off-target; emit it now and leave $TARGET untouched.
# Every other line this script prints already goes to stderr, so stdout is the report alone.
if [[ -n "$REPORT_TMP" ]]; then
  cat "$REPORT_TMP"
  rm -f "$REPORT_TMP"
  REPORT_TMP=""
fi

[[ $QUIET -eq 0 ]] && echo "Recommended ${#RECS[@]} MCP server(s) — ${WIRED_N} wired, ${UNWIRED_N} unwired (not written); report: $REPORT_LABEL" >&2

exit 0
