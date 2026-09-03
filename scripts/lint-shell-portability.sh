#!/usr/bin/env bash
# lint-shell-portability.sh — shellcheck as a ratchet: what is here today is recorded, anything new
# is a hard FAIL.
#
# WHY. The local gate suite runs on macOS and CI runs on Linux, and a whole class of defect is
# invisible to whichever one you happen to be on. Today it fired in BOTH directions:
#
#   `\|` in a BRE sed, awk IGNORECASE, `\b`   GNU-only — match NOTHING on macOS, work on Linux
#   `declare -a NAME` with no `=()`           unbound under set -u on Linux, harmless on macOS
#
# None of them errors. Each simply does the wrong thing quietly, which is how a guard sits for
# months looking correct. "45 of 45 locally" was said four times before CI said otherwise.
#
# shellcheck reads for this statically — no execution, no platform. It does not catch everything
# (it does not read regex dialects, so `\|` and IGNORECASE are still invisible to it), but of the
# four defects above it would have caught the two that cost a red CI run, plus `$ADAPTERS`
# expanding to one element, which had left a gate checking one adapter out of twelve.
#
# THE REPO WAS ALREADY WRITTEN FOR IT and nothing ran it: eight `# shellcheck` directives across
# seven files, one of which (`disable=SC2086 — reason`) was malformed by an em dash and had
# therefore never suppressed anything. Directives read by nobody.
#
# WHAT IS ENFORCED. `error` and `warning`. `note` is style and is not read at all — 456 of them
# exist and none is a defect. Existing warnings live in scripts/_shell-portability-baseline.txt
# with a reason; anything new fails.
#
# A MISSING shellcheck IS A REFUSAL, not a pass. Same contract as lint-workflow-yaml.sh: a gate
# that silently succeeds when its tool is absent is the always-pass bug this repo keeps closing.
#
# Usage:  lint-shell-portability.sh [--repo-root=<dir>] [--record]
# Exit:   1 on any unbaselined finding; 2 when shellcheck is unavailable.

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
RECORD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}" ;;
    --record)      RECORD=1 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
REPO_ROOT="$(cd -P "$REPO_ROOT" && pwd)" || exit 1
cd "$REPO_ROOT" || exit 1

BASELINE="scripts/_shell-portability-baseline.txt"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "ERR: shellcheck is not installed — shell portability cannot be checked." >&2
  echo "     Install it (brew install shellcheck / apt-get install shellcheck), or this gate" >&2
  echo "     is reporting a pass it did not earn." >&2
  exit 2
fi

echo "=== lint-shell-portability ==="
echo "Repo: $REPO_ROOT"
echo ""

FILES=$(find scripts tests templates/repo-baseline/.claude/hooks -type f -name '*.sh' 2>/dev/null | sort)
[ -n "$FILES" ] || { echo "FAIL  no shell scripts found — is this the right repo root?"; exit 1; }
n_files=$(printf '%s\n' "$FILES" | wc -l | tr -d ' ')

# `<path>:<line>:<col>: <severity>: <text> [SCxxxx]` → the baseline key drops the line/col, which
# move whenever anything above them is edited. Keying on file + code + message keeps a recorded
# finding recorded through an unrelated edit, and still fails a genuinely new one.
findings=$(printf '%s\n' "$FILES" | xargs shellcheck --format=gcc --severity=warning 2>/dev/null \
           | sed -E 's/^([^:]+):[0-9]+:[0-9]+: (error|warning): (.*)$/\1|\3/' | sort -u)

if [ "$RECORD" -eq 1 ]; then
  {
    printf '# Shell-portability baseline — scripts/lint-shell-portability.sh\n#\n'
    printf '# Every shellcheck error/warning present when the gate was added. Anything NOT listed\n'
    printf '# here is a hard FAIL. Recorded with --record; each line needs a reason before it is\n'
    printf '# trusted, on the same contract as the other ratchets in this repo.\n#\n'
    printf '# FORMAT   <file>|<message [SCxxxx]>   # reason\n\n'
    printf '%s\n' "$findings"
  } > "$BASELINE"
  echo "recorded $(printf '%s\n' "$findings" | grep -c . ) finding(s) → $BASELINE"
  exit 0
fi

new=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  key="${f%%|*}|${f#*|}"
  grep -qF -- "$key" "$BASELINE" 2>/dev/null && continue
  echo "  FAIL  ${f%%|*}"
  echo "        ${f#*|}"
  new=$((new + 1))
done <<EOF
$findings
EOF

total=$(printf '%s\n' "$findings" | grep -c .)
baselined=$((total - new))
echo ""
echo "reach: $n_files shell scripts · severity error+warning · $total finding(s) · $baselined baselined"
echo "       not checked: shellcheck 'note' severity (style, 456 of them, none a defect) and regex"
echo "       dialect — \`\\|\` in a BRE sed and awk IGNORECASE are invisible to it and cost a"
echo "       separate repair today."
if [ "$new" -gt 0 ]; then
  echo "FAIL  $new new shellcheck finding(s). Fix them, or re-record with --record if deliberate."
  exit 1
fi
echo "PASS"
