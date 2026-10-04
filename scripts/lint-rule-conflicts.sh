#!/usr/bin/env bash
# lint-rule-conflicts.sh — a settled rule conflict stays settled.
#
# WHY. Refract's rules contradicted each other with no precedence: Boy Scout vs surgical in two
# always-loaded files, a TODO rule that wanted a ticket against one that wanted an owner and a
# date, RES-4 refusing to retry a 429 that three domain rules said to retry. Each was settled
# once in templates/governance/precedence.md § Conflict log. Nothing stopped the losing wording
# from coming back the next time someone edited the file — a conflict fixed in prose is fixed
# until the next edit. This gate makes the settlement a check.
#
# The fixtures are scripts/_rule-conflicts.tsv, one row per check:
#   forbid  — the LOSING wording must not appear in the named file (hit ⇒ FAIL).
#   require — the resolution marker must stay in the named file (miss ⇒ FAIL).
#   open    — a known unresolved side, usually in a file another track owns right now. Counted,
#             never failed, but the count may not grow past _rule-conflicts-open-baseline.txt.
# A `forbid`/`require` row on templates/governance/engineering-baseline/* is also checked on its
# installed mirror under templates/repo-baseline/.claude/templates/governance/ — the copy users get.
# Every id in the TSV must have a row in precedence.md § Conflict log, and every logged id a
# fixture, so the log and the check cannot drift apart.
#
# Usage:  lint-rule-conflicts.sh [--root=<dir>] [--record] [--self-test] [--quiet]
# Exit:   0 clean · 1 a settled conflict re-opened, a marker lost, the open count grew, or the
#         log and the fixtures disagree · 2 usage / missing inputs
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
ROOT="$REPO_ROOT"; RECORD=0; SELFTEST=0; QUIET=0
for a in "$@"; do
  case "$a" in
    --root=*)    ROOT="${a#--root=}" ;;
    --record)    RECORD=1 ;;
    --self-test) SELFTEST=1 ;;
    --quiet)     QUIET=1 ;;
    -h|--help)   sed -n '2,24p' "$SELF"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done
say() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }

FIX="$ROOT/scripts/_rule-conflicts.tsv"
OPEN_BASE="$ROOT/scripts/_rule-conflicts-open-baseline.txt"
LOG="$ROOT/templates/governance/precedence.md"
MIRROR_FROM="templates/governance/"
MIRROR_TO="templates/repo-baseline/.claude/templates/governance/"

# ── self-test: every resolved conflict, re-opened on a copy, must FAIL ─────────────────────
if [ "$SELFTEST" = 1 ]; then
  TD=$(mktemp -d "${TMPDIR:-/tmp}/lint-rule-conflicts.XXXXXX"); trap 'rm -rf "$TD"' EXIT
  pass=0; fail=0
  copy_tree() {  # copy every file the fixtures name, plus the log and the fixtures themselves
    local dst="$1" f
    mkdir -p "$dst/scripts" "$dst/templates/governance"
    cp "$REPO_ROOT/scripts/_rule-conflicts.tsv" "$dst/scripts/"
    [ -f "$REPO_ROOT/scripts/_rule-conflicts-open-baseline.txt" ] && cp "$REPO_ROOT/scripts/_rule-conflicts-open-baseline.txt" "$dst/scripts/"
    cp "$REPO_ROOT/templates/governance/precedence.md" "$dst/templates/governance/"
    grep -v '^#' "$REPO_ROOT/scripts/_rule-conflicts.tsv" | awk -F'\t' 'NF>=4{print $3}' | sort -u | while IFS= read -r f; do
      [ -f "$REPO_ROOT/$f" ] || continue
      mkdir -p "$dst/$(dirname "$f")"; cp "$REPO_ROOT/$f" "$dst/$f"
      case "$f" in "$MIRROR_FROM"*)
        m="$MIRROR_TO${f#"$MIRROR_FROM"}"
        [ -f "$REPO_ROOT/$m" ] && { mkdir -p "$dst/$(dirname "$m")"; cp "$REPO_ROOT/$m" "$dst/$m"; } ;;
      esac
    done
  }
  # 0 — the real tree, copied, passes.
  copy_tree "$TD/clean"
  if bash "$SELF" --root="$TD/clean" --quiet >/dev/null 2>&1; then pass=$((pass+1)); say "  ok   clean copy passes"
  else fail=$((fail+1)); echo "  FAIL clean copy should pass"; bash "$SELF" --root="$TD/clean" 2>&1 | tail -5; fi
  # 1 — per forbid row: append the row's literal probe (the losing wording) → must fail.
  n=0
  while IFS=$'\t' read -r id kind file re note probe; do
    case "$id" in ''|\#*) continue ;; esac
    [ "$kind" = forbid ] || continue
    n=$((n+1)); d="$TD/f$n"; copy_tree "$d"
    if [ -z "${probe:-}" ] || ! printf '%s\n' "$probe" | grep -Eq -- "$re"; then
      fail=$((fail+1)); echo "  FAIL $id forbid row has no probe, or its probe does not match its ERE"; continue
    fi
    printf '\n%s\n' "$probe" >> "$d/$file"
    if bash "$SELF" --root="$d" --quiet >/dev/null 2>&1; then fail=$((fail+1)); echo "  FAIL $id re-introduced in $file was not caught"
    else pass=$((pass+1)); say "  ok   $id re-opened in $(basename "$file") → FAIL"; fi
  done < "$REPO_ROOT/scripts/_rule-conflicts.tsv"
  # 2 — per require row: strip the marker → must fail.
  n=0
  while IFS=$'\t' read -r id kind file re note _probe; do
    case "$id" in ''|\#*) continue ;; esac
    [ "$kind" = require ] || continue
    n=$((n+1)); d="$TD/r$n"; copy_tree "$d"
    grep -Ev -- "$re" "$d/$file" > "$d/$file.tmp"; mv "$d/$file.tmp" "$d/$file"
    if bash "$SELF" --root="$d" --quiet >/dev/null 2>&1; then fail=$((fail+1)); echo "  FAIL $id marker removed from $file was not caught"
    else pass=$((pass+1)); say "  ok   $id marker removed from $(basename "$file") → FAIL"; fi
  done < "$REPO_ROOT/scripts/_rule-conflicts.tsv"
  # 3 — a logged id with no fixture, and a fixture id with no log row, both fail.
  d="$TD/orphan"; copy_tree "$d"
  printf '| A99 | x | y | — | z | resolved |\n' >> "$d/templates/governance/precedence.md"
  if bash "$SELF" --root="$d" --quiet >/dev/null 2>&1; then fail=$((fail+1)); echo "  FAIL a logged id with no fixture was not caught"
  else pass=$((pass+1)); say "  ok   logged id without fixture → FAIL"; fi
  d="$TD/orphan2"; copy_tree "$d"
  printf 'A98\trequire\ttemplates/governance/precedence.md\tPrecedence\tx\n' >> "$d/scripts/_rule-conflicts.tsv"
  if bash "$SELF" --root="$d" --quiet >/dev/null 2>&1; then fail=$((fail+1)); echo "  FAIL a fixture id with no log row was not caught"
  else pass=$((pass+1)); say "  ok   fixture id without log row → FAIL"; fi
  echo "lint-rule-conflicts self-test: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]; exit $?
fi

[ -f "$FIX" ] || { echo "ERR: fixtures not found: $FIX" >&2; exit 2; }
[ -f "$LOG" ] || { echo "ERR: conflict log not found: $LOG" >&2; exit 2; }

errors=0; open_total=0; open_rows=""
err() { echo "  ✗ $*"; errors=$((errors+1)); }

check_one() {  # $1=id $2=kind $3=file(rel) $4=ERE $5=note
  local id="$1" kind="$2" rel="$3" re="$4" note="$5" path="$ROOT/$3" hits
  if [ ! -f "$path" ]; then
    [ "$kind" = open ] && return 0           # an open side whose file moved is not a failure
    err "$id $kind: $rel not found (fixture names a file that does not exist)"; return 0
  fi
  hits=$(grep -Ec -- "$re" "$path" 2>/dev/null); hits=${hits:-0}
  case "$kind" in
    forbid)  [ "$hits" -eq 0 ] || err "$id re-opened: $rel carries the losing wording ($note) — see precedence.md $id" ;;
    require) [ "$hits" -gt 0 ] || err "$id marker lost: $rel no longer carries the resolution ($note) — see precedence.md $id" ;;
    open)    if [ "$hits" -gt 0 ]; then open_total=$((open_total+1)); open_rows="${open_rows}    open $id  $rel  ($note)\n"; fi ;;
    *)       err "$id: unknown kind '$kind'" ;;
  esac
}

ids_fix=""
while IFS=$'\t' read -r id kind file re note _probe; do
  case "$id" in ''|\#*) continue ;; esac
  ids_fix="$ids_fix $id"
  check_one "$id" "$kind" "$file" "$re" "$note"
  case "$file" in "$MIRROR_FROM"engineering-baseline/*)
    [ "$kind" = open ] || check_one "$id" "$kind" "$MIRROR_TO${file#"$MIRROR_FROM"}" "$re" "$note (installed mirror)" ;;
  esac
done < "$FIX"

# The installed mirror of the governance files is byte-identical to the source: precedence.md,
# thresholds.json and ownership.json reach a project only through the mirror, and a mirror that
# lags the source ships last week's precedence. (The self-test copies only fixture files, so it
# runs this check against whatever subset it copied.)
for g in precedence.md thresholds.json ownership.json; do
  src="$ROOT/${MIRROR_FROM}$g"; dst="$ROOT/${MIRROR_TO}$g"
  [ -f "$src" ] || continue
  [ -f "$dst" ] || { [ "$ROOT" = "$REPO_ROOT" ] && err "governance mirror missing: ${MIRROR_TO}$g (cp ${MIRROR_FROM}$g there)"; continue; }
  cmp -s "$src" "$dst" || err "governance mirror stale: ${MIRROR_TO}$g differs from ${MIRROR_FROM}$g"
done

# The log and the fixtures name the same ids.
ids_log=$(grep -E '^\| A[0-9]+ \|' "$LOG" | sed -E 's/^\| (A[0-9]+) \|.*/\1/' | sort -u)
for i in $ids_log; do
  case " $ids_fix " in *" $i "*) ;; *) err "$i is in precedence.md § Conflict log but has no fixture in _rule-conflicts.tsv" ;; esac
done
for i in $(printf '%s\n' $ids_fix | sort -u); do
  printf '%s\n' "$ids_log" | grep -qx "$i" || err "$i has fixtures but no row in precedence.md § Conflict log"
done

if [ "$RECORD" = 1 ]; then
  { echo "# Open (unresolved) conflict sides counted by scripts/lint-rule-conflicts.sh. May only shrink."
    echo "open $open_total"; } > "$OPEN_BASE"
  say "recorded open=$open_total → $OPEN_BASE"
fi
recorded=""
[ -f "$OPEN_BASE" ] && recorded=$(awk '$1=="open"{print $2}' "$OPEN_BASE" | head -1)
if [ -n "$recorded" ] && [ "$open_total" -gt "$recorded" ]; then
  err "open conflict sides grew: $open_total (recorded $recorded) — settle it in precedence.md instead of adding another"
fi

say "Rule conflicts — $(printf '%s\n' $ids_fix | sort -u | wc -l | tr -d ' ') logged, $open_total open side(s) (recorded ${recorded:-none})"
[ "$QUIET" = 1 ] || printf "%b" "$open_rows"
if [ "$errors" -gt 0 ]; then echo "lint-rule-conflicts: $errors error(s)"; exit 1; fi
say "OK — every settled conflict holds."
exit 0
