#!/usr/bin/env bash
# test-skill-sidecars.sh — a skill's references/ must reach the project on EVERY install path.
#
# WHY. Progressive disclosure puts the detail a skill only sometimes needs in `references/`.
# That is worth nothing if the directory does not travel. Two install paths existed and they
# disagreed:
#
#   CREATE   phase-4.2-apply.md § "Copy skills" does `cp -R "$s"` — the folder, sidecars included.
#   REFRESH  apply-study-decisions.sh copied SKILL.md alone.
#
# The first fix added sync_skill_sidecars to that script's ADD and REPLACE arms. Running a REAL
# refresh against a production repo then showed the fix missing the case that matters: of 60
# rows, 57 were MERGE — handed to merge-decide.py, which rewrites SKILL.md and knows nothing
# about sidecars. On a repo that already has the skill installed, MERGE is the normal path, so
# the fix covered the rare arms and skipped the common one.
#
# The second attempt failed too, silently: it derived the skill name with artifact_identity(),
# which takes a `base` (`<name>/SKILL.md`) and was handed a full pack-relative path, so it
# resolved to a directory that cannot exist and copied nothing. Both bugs were invisible
# without an end-to-end assertion. This is that assertion.
#
# Three cases, one per arm:
#   MERGE        skill already installed and differing → engine rewrites it → sidecars follow
#   ADD          skill absent → copied fresh → sidecars follow
#   LEGACY-FLAT  installed as `<name>.md` → a single file cannot hold a directory, so the run
#                must SAY so and name the migration, not drop it silently
#
# Usage:  test-skill-sidecars.sh [--repo-root=<dir>]
# Exit:   1 if any case fails; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"
REPO_ROOT="$(cd -P "$SELF_DIR/.." && pwd)"; unset _ss _sd
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
FAILED=0
fail() { red "  ✗ $*"; FAILED=$((FAILED+1)); }
pass() { green "  ✓ $*"; }

APPLY="$REPO_ROOT/scripts/apply-study-decisions.sh"
[ -f "$APPLY" ] || { echo "no apply-study-decisions.sh under $REPO_ROOT — nothing to test"; exit 0; }

# A pack skill that actually ships a sidecar. Skip cleanly rather than assert against a
# tree that has none — the wiring is what is under test, not this particular skill.
SRC=""
while IFS= read -r d; do SRC="$d"; break; done <<< "$(find "$REPO_ROOT/templates/packs" -type d -name references -path '*/skills/*' 2>/dev/null | sort)"
if [ -z "$SRC" ]; then
  echo "no pack skill ships a references/ dir — nothing to assert"; exit 0
fi
SKILL_DIR="$(dirname "$SRC")"
NAME="$(basename "$SKILL_DIR")"
PACK="$(basename "$(dirname "$(dirname "$SKILL_DIR")")")"
SIDECAR_FILE="$(basename "$(find "$SRC" -type f | sort | head -1)")"
echo "fixture: $PACK/skills/$NAME  (sidecar references/$SIDECAR_FILE)"

TD="$(mktemp -d "${TMPDIR:-/tmp}/test-skill-sidecars.XXXXXX")"
trap 'rm -rf "$TD"' EXIT

report() {  # $1=target  $2=decision
  mkdir -p "$1/.claude"
  printf '# Study report\n\n## %s\n\n### skills\n\n  - `%s/SKILL.md` — target 1 / pack 1 lines → **%s**\n' \
    "$PACK" "$NAME" "$2" > "$1/.claude/_study-existing-report.md"
}

# ── MERGE: installed and different, so the engine rewrites it ──────────────
T1="$TD/merge"; mkdir -p "$T1/.claude/skills/$NAME"
sed 's/^## Purpose$/## Purpose (project note)/' "$SKILL_DIR/SKILL.md" > "$T1/.claude/skills/$NAME/SKILL.md"
report "$T1" MERGE
bash "$APPLY" "$T1" --apply >"$TD/merge.log" 2>&1
if [ -f "$T1/.claude/skills/$NAME/references/$SIDECAR_FILE" ]; then
  pass "MERGE — sidecar reached the project through the merge engine"
else
  fail "MERGE — references/$SIDECAR_FILE did not arrive (see $TD/merge.log)"
fi

# ── ADD: not installed at all ─────────────────────────────────────────────
T2="$TD/add"; mkdir -p "$T2/.claude/skills"
report "$T2" ADD
bash "$APPLY" "$T2" --apply >"$TD/add.log" 2>&1
if [ -f "$T2/.claude/skills/$NAME/references/$SIDECAR_FILE" ]; then
  pass "ADD — sidecar reached a fresh install"
else
  fail "ADD — references/$SIDECAR_FILE did not arrive (see $TD/add.log)"
fi

# ── LEGACY FLAT: one file has nowhere to put a directory; say so ───────────
T3="$TD/flat"; mkdir -p "$T3/.claude/skills"
sed 's/^## Purpose$/## Purpose (project note)/' "$SKILL_DIR/SKILL.md" > "$T3/.claude/skills/$NAME.md"
report "$T3" MERGE
bash "$APPLY" "$T3" --apply >"$TD/flat.log" 2>&1
if grep -q "sidecar-skip" "$TD/flat.log"; then
  pass "LEGACY-FLAT — the dropped sidecar is announced, with the migration named"
elif [ -d "$T3/.claude/skills/$NAME/references" ]; then
  fail "LEGACY-FLAT — wrote a folder beside the flat skill, creating a same-name twin"
else
  fail "LEGACY-FLAT — sidecar silently dropped; no 'sidecar-skip' notice (see $TD/flat.log)"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then green "skill-sidecars: 3 passed, 0 failed"; exit 0; fi
red "skill-sidecars: $FAILED failed"; exit 1
