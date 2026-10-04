#!/usr/bin/env bash
# apply-skill-overrides.sh — write the level-B "name-only" listing into a project's settings.
#
# WHY. Claude Code lists every installed command and skill, with its description, in one
# listing capped at 1% of the context window (8,000 chars at 200K). A fresh fullstack install
# demands ~90,000 — so the platform truncates descriptions to bare names in listing order, and
# the five front doors lose theirs along with everything else. Measured with
# scripts/lint-description-budget.sh: with no overrides, 230 of 253 entries of a fullstack
# install are truncated; with this script's overrides, none are and the listing is ~5,800 chars.
#
# WHAT IT WRITES. `.claude/settings.json` → "skillOverrides": { "<name>": "name-only", ... } — a
# per-NAME map, the only shape Claude Code reads (a bare string is not a setting). Levels come
# from templates/governance/visibility-levels.json:
#   A  front door (do, add-feature, fix-bug, review-changes, security-audit) — not listed here,
#      so it keeps its full description.
#   B  every other installed command and skill — "name-only". /do routes to it by name.
#   D  a command whose frontmatter carries `disable-model-invocation: true` — not listed here;
#      the frontmatter already keeps it out of the listing and away from the Skill tool.
# Installed = the target's .claude/commands/*.md, .claude/skills/<name>/SKILL.md, and the global
# commands (this repo's commands/, which sync-to-global.sh links into ~/.claude/commands).
#
# MERGE — the owner wins, always. An entry already present in settings.json OR
# settings.local.json is left exactly as it is, whatever its value ("on" included). Entries are
# only ever ADDED, never removed or rewritten, and nothing else in the file is touched. A
# `skillOverrides` that is not an object, or a settings.json that is not valid JSON, is refused:
# nothing is written. A run with nothing to add does not write (a no-op write would still move
# the mtime). A real write is atomic and backs the old file up under
# .claude/backups/skill-overrides-<ts>/.
#
# PLATFORM LIMIT. Claude Code 2.1.236 ignores skillOverrides for plugin-sourced skills; a Refract
# command installed through a plugin is always listed in full. This script governs project and
# user commands and skills only.
#
# Usage:   apply-skill-overrides.sh <target-repo> [--apply] [--globals-dir=<dir>] [--quiet]
# Exit:    0 written, no-op, or dry run · 1 refused (bad JSON / wrong shape / missing target) ·
#          2 usage error

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

if [ $# -lt 1 ]; then
  echo "Usage: $0 <target-repo> [--apply] [--globals-dir=<dir>] [--quiet]" >&2; exit 2
fi
TARGET="$1"; shift
APPLY=0; QUIET=0; GLOBALS_DIR="$REPO_ROOT/commands"
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --globals-dir=*) GLOBALS_DIR="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -d "$TARGET" ] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }
LEVELS_FILE="$REPO_ROOT/templates/governance/visibility-levels.json"
[ -f "$LEVELS_FILE" ] || { echo "ERR: levels registry missing: $LEVELS_FILE" >&2; exit 1; }

TARGET="$TARGET" APPLY="$APPLY" QUIET="$QUIET" GLOBALS_DIR="$GLOBALS_DIR" LEVELS_FILE="$LEVELS_FILE" \
python3 <<'PY'
import os, re, sys, glob, json, time, shutil, tempfile

T, APPLY, QUIET = os.environ["TARGET"], os.environ["APPLY"] == "1", os.environ["QUIET"] == "1"
def say(m):
    if not QUIET: print(m)

levels = json.load(open(os.environ["LEVELS_FILE"], encoding="utf-8"))
FRONT, VALUE = set(levels.get("front_door", [])), levels.get("level_b_override", "name-only")

def fm(f):
    try: lines = open(f, encoding="utf-8").read().split("\n")
    except OSError: return {}
    if not lines or lines[0].strip() != "---": return {}
    d = {}
    for l in lines[1:]:
        if l.strip() == "---": break
        m = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):[ \t]*(.*)$", l)
        if m: d[m.group(1)] = m.group(2).strip().strip("\"'")
    return d

def is_d(f): return fm(f).get("disable-model-invocation", "").lower() in ("true", "yes", "on")

# name → [files] ; a name is D if ANY file that provides it is D (the cautious reading)
src = {}
def add(n, f): src.setdefault(n, []).append(f)
for f in sorted(glob.glob(os.path.join(os.environ["GLOBALS_DIR"], "*.md"))): add(os.path.basename(f)[:-3], f)
for f in sorted(glob.glob(os.path.join(T, ".claude", "commands", "*.md"))): add(os.path.basename(f)[:-3], f)
for f in sorted(glob.glob(os.path.join(T, ".claude", "skills", "*", "SKILL.md"))):
    add(fm(f).get("name") or os.path.basename(os.path.dirname(f)), f)

A = sorted(n for n in src if n in FRONT and not any(is_d(f) for f in src[n]))
D = sorted(n for n in src if any(is_d(f) for f in src[n]))
B = sorted(n for n in src if n not in FRONT and n not in D)

sp, lp = os.path.join(T, ".claude", "settings.json"), os.path.join(T, ".claude", "settings.local.json")
raw, data = None, {}
if os.path.exists(sp):
    raw = open(sp, encoding="utf-8").read()
    try: data = json.loads(raw)
    except ValueError as e:
        print("REFUSED — .claude/settings.json is not valid JSON (%s); nothing written." % e); sys.exit(1)
    if not isinstance(data, dict):
        print("REFUSED — .claude/settings.json is not a JSON object; nothing written."); sys.exit(1)
cur = data.get("skillOverrides")
if cur is not None and not isinstance(cur, dict):
    print("REFUSED — skillOverrides in .claude/settings.json is %s, not a {name: value} map. Claude "
          "Code reads only the map form; it is the owner's to fix, so nothing was written."
          % type(cur).__name__); sys.exit(1)
owner = dict(cur or {})
if os.path.exists(lp):
    try:
        lo = json.load(open(lp, encoding="utf-8")).get("skillOverrides")
        if isinstance(lo, dict): owner.update(lo)
    except (ValueError, AttributeError): pass

add_names = [n for n in B if n not in owner]
kept = [n for n in B if n in owner and owner[n] != VALUE]
say("skill overrides — %s" % T)
say("  installed names %d: %d front door (A, full description), %d name-only (B), %d D "
    "(disable-model-invocation — never listed)" % (len(src), len(A), len(B), len(D)))
say("  B already set by the owner: %d (%d with a value other than %s — kept as the owner wrote them%s)"
    % (len(B) - len(add_names), len(kept), VALUE, (": " + ", ".join(kept[:8])) if kept else ""))
if not add_names:
    say("  NO-OP — every B name already has an entry; settings.json not touched."); sys.exit(0)
if not APPLY:
    say("  would ADD %d entries (dry run — re-run with --apply): %s%s"
        % (len(add_names), ", ".join(add_names[:12]), " …" if len(add_names) > 12 else "")); sys.exit(0)

new = dict(cur or {})
for n in add_names: new[n] = VALUE
data["skillOverrides"] = new
indent = 2
if raw:
    m = re.search(r"\n([ \t]+)\"", raw)
    if m: indent = m.group(1) if "\t" in m.group(1) else len(m.group(1))
text = json.dumps(data, indent=indent, ensure_ascii=False) + "\n"
os.makedirs(os.path.dirname(sp), exist_ok=True)
if raw is not None:
    bdir = os.path.join(T, ".claude", "backups", "skill-overrides-" + time.strftime("%Y%m%d-%H%M%S"))
    os.makedirs(bdir, exist_ok=True); shutil.copy2(sp, os.path.join(bdir, "settings.json"))
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(sp), prefix=".settings.", suffix=".tmp")
with os.fdopen(fd, "w", encoding="utf-8") as h: h.write(text)
os.replace(tmp, sp)
say("  ADDED %d name-only entries to .claude/settings.json%s"
    % (len(add_names), (" (backup: %s)" % os.path.relpath(bdir, T)) if raw is not None else " (new file)"))
PY
rc=$?
[ $rc -eq 0 ] || exit $rc
# What Claude Code would actually list now — one formula, owned by the budget lint.
if [ "$QUIET" -eq 0 ] && [ -f "$REPO_ROOT/scripts/lint-description-budget.sh" ]; then
  bash "$REPO_ROOT/scripts/lint-description-budget.sh" --target="$TARGET" --globals-dir="$GLOBALS_DIR" || true
fi
exit 0
