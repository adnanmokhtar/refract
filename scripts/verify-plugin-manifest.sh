#!/usr/bin/env bash
# verify-plugin-manifest.sh — the figures and command names in .claude-plugin/plugin.json
# must match disk.
#
# WHY. Every other public count in this repo is held to disk by a gate: README prose and
# table by verify-readme-stats.sh, the drawn SVG text by verify-figure-stats.sh, the pack
# matrix by verify-pack-matrix.sh. The plugin manifest was read by none of them, and it is
# the one file a plugin directory quotes back to users verbatim.
#
# MEASURED 2026-08-26, during the plugin-directory pre-submission audit:
#   .claude-plugin/plugin.json  "12 tool adapters, 68 scripts"  — actual 90 scripts
# Every neighbouring figure in the same sentence was correct, because every neighbouring
# figure also appears somewhere a gate reads. This one did not, so it drifted 22 behind
# and was on its way into a submission.
#
# Two classes of check:
#   [1] COUNTS   — each "<N> <thing>" in the description, against the same derivation the
#                  README gates use. A number nobody re-derives is a number that rots.
#   [2] NAMES    — every `/command` the description enumerates must exist in commands/.
#                  A count alone survives a rename; the advertised surface must resolve.
#
# Undated, underivable prose is left alone deliberately — this gate checks claims about
# disk, not marketing.
#
# Usage: verify-plugin-manifest.sh [--repo-root=<dir>] [--quiet]
# Exit:  0 every derivable claim matches disk / 1 one does not / 2 usage error
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" || exit 1
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }

MANIFEST=".claude-plugin/plugin.json"
[ -f "$MANIFEST" ] || { echo "  FAIL $MANIFEST is missing — a plugin without a manifest cannot be listed"; exit 1; }

# The description is the only field carrying derivable claims. Pull it as one line.
DESC=$(python3 -c '
import json,sys
try: d=json.load(open(".claude-plugin/plugin.json"))
except Exception as e: print("PARSE_ERROR:%s"%e); sys.exit(0)
print(d.get("description","") or "")
' 2>/dev/null)

case "$DESC" in
  PARSE_ERROR:*) printf '  FAIL %s does not parse as JSON — %s\n' "$MANIFEST" "${DESC#PARSE_ERROR:}"; exit 1 ;;
esac
[ -n "$DESC" ] || { echo "  FAIL $MANIFEST has no description — nothing to verify, and nothing for a directory to quote"; exit 1; }

# ── derive from disk, the same way verify-readme-stats.sh and verify-figure-stats.sh do ──
PACKS=$(find templates/packs            -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
TECHDOM=$(find templates/domains        -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
BIZDOM=$(find templates/business-domains -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
ADAPTERS=$(find templates/tool-adapters -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
GLOBCMD=$(find commands -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
SCRIPTS=$(find scripts -maxdepth 1 \( -name '*.sh' -o -name '*.py' \) 2>/dev/null | wc -l | tr -d ' ')

fail=0

# ── [1] counts ───────────────────────────────────────────────────────────────
# check "<phrase the manifest uses>" <expected> — the phrase is the key, so a reworded
# description fails loudly here rather than silently skipping its own check.
check_count() {
  local phrase="$1" want="$2" got
  got=$(printf '%s' "$DESC" | grep -oE "[0-9]+ $phrase" | head -1 | grep -oE '^[0-9]+')
  if [ -z "$got" ]; then
    printf '  FAIL %s: no "<N> %s" claim found — did the wording change?\n' "$MANIFEST" "$phrase"
    printf '       This gate is keyed to the phrase; update the pattern with the wording.\n'
    fail=$((fail+1)); return
  fi
  if [ "$got" = "$want" ]; then
    say "  ok   $phrase = $got"
  else
    printf '  FAIL %s: "%s %s" — disk says %s\n' "$MANIFEST" "$got" "$phrase" "$want"
    fail=$((fail+1))
  fi
}

check_count 'global orchestration commands' "$GLOBCMD"
check_count 'role-based packs'              "$PACKS"
check_count 'technical domains'             "$TECHDOM"
check_count 'business domains'              "$BIZDOM"
check_count 'tool adapters'                 "$ADAPTERS"
check_count 'scripts'                       "$SCRIPTS"

# ── [2] every enumerated /command resolves ───────────────────────────────────
named=0; missing=0
for c in $(printf '%s' "$DESC" | grep -oE '/[a-z][a-z0-9-]*' | sed 's|^/||' | sort -u); do
  named=$((named+1))
  [ -f "commands/$c.md" ] || { printf '  FAIL %s names /%s — commands/%s.md does not exist\n' "$MANIFEST" "$c" "$c"; missing=$((missing+1)); fail=$((fail+1)); }
done
if [ "$named" -eq 0 ]; then
  say "  ok   no commands enumerated (nothing to resolve)"
elif [ "$missing" -eq 0 ]; then
  say "  ok   all $named enumerated commands resolve to commands/*.md"
fi

# An enumerated list that has fallen behind the count is the drift a count alone survives.
if [ "$named" -gt 0 ] && [ "$named" != "$GLOBCMD" ]; then
  printf '  FAIL %s enumerates %s commands but commands/ holds %s — the advertised list is incomplete\n' "$MANIFEST" "$named" "$GLOBCMD"
  fail=$((fail+1))
fi

say ""
if [ "$fail" -eq 0 ]; then say "  plugin-manifest: every derivable claim matches disk"
else printf '  plugin-manifest: %d claim(s) disagree with disk\n' "$fail"; fi
[ "$fail" -eq 0 ]
