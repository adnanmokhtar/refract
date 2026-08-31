#!/usr/bin/env bash
# test-audit-precision.sh — fixture suite for the ONE thing an audit owes its reader:
# every ERR it prints must be actionable. Three checks were failing that, each in its own
# way, and each is pinned here.
#
# ── PART A — C2n's baseline. The promise it makes is
# "the state this file was in BEFORE THIS RUN". Not before some run. Before THIS one.
#
# WHY. C2n walks backup dirs oldest-first and takes the first sighting of a path as
# the pre-run state. Correct inside one run; badly wrong across runs, because a
# backup from a PREVIOUS run then supplies the baseline and every legitimate change
# made since is reported as knowledge the refresh destroyed.
#
# 📏 Measured on the reference monorepo after a third setup in three days: 15 backup dirs
# spanning 2026-08-22 to 08-24, and the audit reported 227 KNOWLEDGE_LOSS errors,
# every one reading `lost 0 line(s), 0 project token(s) and 1 project-specific
# region(s)`. Diffed by hand the regions were BYTE-IDENTICAL — 16 lines before,
# 16 after, empty diff. Zero real losses, 227 alarms, on a healthy project.
#
# `--refresh` is documented as repeatable, so this fired for anyone using the tool
# the way we tell them to. And a gate that cries wolf on a correct run teaches its
# reader to scroll past it — taking the next run's one true ERR with it.
#
# Four properties, all asserted here:
#   § 1  dirs from an EARLIER run are excluded, however recently touched;
#   § 2  every dir from THIS run is included — the Phase-0 floor and all after it;
#   § 3  the floor comes from the NAME, never the mtime (same lesson as M35);
#   § 4  no floor at all (Phase-0 backup pruned) falls back to reading everything —
#        over-reporting beats silently checking nothing.
#
# Everything runs under mktemp -d. Nothing is written outside it.
#
# Usage: test-audit-precision.sh [--quiet]
# Exit:  0 all fixtures pass / 1 a fixture failed
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

AUDIT="$REPO_ROOT/scripts/audit-setup.sh"
QUIET=0
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }
pass=0; fail=0
ok()  { pass=$((pass+1)); say "  ok   $1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

[ -f "$AUDIT" ] || { echo "ERR: $AUDIT not found" >&2; exit 1; }

# Lift the function out rather than sourcing the script, which would run a whole audit.
# From its definition line to the first column-0 `}`.
FN="$(awk '/^c2n_run_backups\(\) \{$/{f=1} f{print} f&&/^\}$/{exit}' "$AUDIT")"
[ -n "$FN" ] || { echo "ERR: c2n_run_backups not found in $AUDIT — did it get renamed?" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
CL="$TMP/.claude"; mkdir -p "$CL/backups"

# Three runs' worth of backups, in the exact shape setup produces: a bare-timestamp
# Phase-0 dir opening each run, then `<script>-<stamp>` dirs after it.
STALE=(20260822-051300 study-decisions-20260822-051357 anchors-20260822-052509
       20260823-165413 merge-decide-20260823-165632 adapter-sync-20260823-170520)
CURRENT=(20260824-124606 merge-decide-20260824-124716 rule-imports-20260824-124746
         anchors-20260824-125803 adapter-sync-20260824-130721)
for d in "${STALE[@]}" "${CURRENT[@]}"; do mkdir -p "$CL/backups/$d"; done

# § 3 — every dir gets the SAME mtime, and it is NOW. Any implementation reaching for
# `find -mmin` or `ls -t` passes the other sections and fails here, which is the point:
# a `git reset` refreshing mtimes inside an old backup is what defeated the last one.
find "$CL/backups" -mindepth 1 -maxdepth 1 -type d -exec touch {} +

eval "$FN"
got="$(CL="$CL" c2n_run_backups | sed 's#/$##' | xargs -n1 basename 2>/dev/null)"

# § 1 — nothing from an earlier run
leaked=""
for d in "${STALE[@]}"; do
  printf '%s\n' "$got" | grep -qxF "$d" && leaked="$leaked $d"
done
if [ -z "$leaked" ]; then ok "§1 dirs from earlier runs excluded (${#STALE[@]} of them)"
else bad "§1 a previous run's backup would supply the baseline" "leaked:$leaked"; fi

# § 2 — everything from this run, floor included
missing=""
for d in "${CURRENT[@]}"; do
  printf '%s\n' "$got" | grep -qxF "$d" || missing="$missing $d"
done
if [ -z "$missing" ]; then ok "§2 all ${#CURRENT[@]} of this run's backups included"
else bad "§2 this run's own backup is not being read" "missing:$missing"; fi

# § 3 — restated as its own assertion so a failure names the right cause
n_got="$(printf '%s\n' "$got" | grep -c . )"
if [ "$n_got" -eq "${#CURRENT[@]}" ]; then ok "§3 selection came from the NAME, not the mtime"
else bad "§3 mtime leaked into the selection" "expected ${#CURRENT[@]} dirs, got $n_got"; fi

# § 4 — floor pruned: fall back to reading everything rather than checking nothing
CL2="$TMP/pruned/.claude"; mkdir -p "$CL2/backups"
for d in study-decisions-20260822-051357 anchors-20260824-125803; do mkdir -p "$CL2/backups/$d"; done
n_fb="$(CL="$CL2" c2n_run_backups | grep -c . )"
if [ "$n_fb" -eq 2 ]; then ok "§4 no Phase-0 floor → reads every dir (over-report, never under)"
else bad "§4 a pruned floor silently emptied the baseline" "expected 2 dirs, got $n_fb"; fi

# § 5 — under the caller's REAL shell flags. audit-setup.sh runs `set -euo pipefail`, and
# the first version of this function died on its own `grep` — no bare-timestamp dir means
# grep exits 1, pipefail promotes it to the substitution, and a bare assignment propagates
# it. The function returned nothing, C2n compared against nothing, and every one of its
# checks became a silent no-op. It PASSED §1–§4 while doing that, because this suite runs
# without `-e`. So the flags are part of the fixture now.
n_strict="$(bash -c "set -euo pipefail
$FN
CL='$CL2' c2n_run_backups" 2>/dev/null | grep -c . )"
if [ "$n_strict" -eq 2 ]; then ok "§5 survives set -euo pipefail with no floor present"
else bad "§5 the function dies under the caller's own shell flags" "expected 2 dirs, got $n_strict — C2n would silently check nothing"; fi

# A 4-digit stamp is what older installs wrote. It must still work as a floor.
CL3="$TMP/legacy/.claude"; mkdir -p "$CL3/backups"
for d in 20260823-1408 anchors-20260823-141145 20260824-1246 anchors-20260824-124747; do mkdir -p "$CL3/backups/$d"; done
n_lg="$(CL="$CL3" c2n_run_backups | grep -c . )"
if [ "$n_lg" -eq 2 ]; then ok "§3b legacy YYYYMMDD-HHMM stamps scope correctly too"
else bad "§3b legacy 4-digit stamp not recognised as a floor" "expected 2 dirs, got $n_lg"; fi


# ══ PART B — C2y: a probe is CODE, the word "grep" in a sentence is not ═══════════════
#
# C2y greps whole LINES for rg/grep/find/ls/fd and then harvests `a/b` tokens from the
# matched line. Artifacts are mostly prose, and "find" is an ordinary English verb, so on
# the sibling repo 26 of 55 reported probes came from sentences — `JSX/template`,
# `analytics/telemetry`, `tool/function` read as directories. The unit of judgement is now
# the CODE on the line: a fenced block, an indented block, or the inline `…` spans.
#
# The recall half matters as much as the precision half and is asserted first: this check
# exists because a probe over a directory that does not exist returns zero hits, and a
# zero-hit probe is indistinguishable from a clean result.
say ""
say "part B — C2y judges code, not prose"

FNY="$(awk '/^c2y_code_probes\(\) \{$/{f=1} f{print} f&&/^\}$/{exit}' "$AUDIT")"
[ -n "$FNY" ] || { echo "ERR: c2y_code_probes not found in $AUDIT — did it get renamed?" >&2; exit 1; }
eval "$FNY"

PROJ="$TMP/probe"; mkdir -p "$PROJ/.claude/agents" "$PROJ/.claude/commands" "$PROJ/.claude/skills" "$PROJ/.claude/rules" "$PROJ/ai" "$PROJ/apps/web"
: > "$PROJ/apps/web/main.ts"
cat > "$PROJ/.claude/agents/reviewer.md" <<'FIX'
# Reviewer

Known limit of that grep: it is line-scoped, so a multi-line JSX/template `<input>` wraps.
An APPROVE verdict on a change that adds an analytics/telemetry event is a finding.
A new tool/function the model can call must be listed. Go and find the store/service pair.

Run this probe:

```bash
rg "SELECT.*FROM (orders|products)" src/ | grep -v "tenant_id"
```

Then check `ls migrations/` for anything unversioned.
FIX

got_y="$(CL="$PROJ/.claude" TARGET="$PROJ" c2y_code_probes \
          | while IFS="$(printf '\t')" read -r loc code; do printf '%s\n' "$code"; done)"

# recall — the two REAL probes must both be seen
if printf '%s' "$got_y" | grep -q 'src/' && printf '%s' "$got_y" | grep -q 'migrations/'; then
  ok "§6 the fenced probe AND the inline-code probe are both read"
else
  bad "§6 a real probe was dropped — this check's whole point is the zero-hit it catches" \
      "saw: $(printf '%s' "$got_y" | tr '\n' '|')"
fi

# precision — no sentence may reach the path extractor
prose_leak=""
for w in JSX/template analytics/telemetry tool/function store/service; do
  printf '%s' "$got_y" | grep -qF "$w" && prose_leak="$prose_leak $w"
done
if [ -z "$prose_leak" ]; then ok "§7 English sentences are not mistaken for probes"
else bad "§7 prose reached the path extractor" "leaked:$prose_leak"; fi

# and the flag word alone must not qualify a line
n_y="$(CL="$PROJ/.claude" TARGET="$PROJ" c2y_code_probes | grep -c . )"
if [ "$n_y" -eq 2 ]; then ok "§8 exactly the 2 code lines qualify, not the 4 prose ones"
else bad "§8 wrong number of probe lines" "expected 2, got $n_y"; fi

say ""
say "  $pass passed, $fail failed"
[ $fail -eq 0 ]
