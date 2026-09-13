#!/usr/bin/env bash
# lint-shell-pipefail-traps.sh — catch the `set -euo pipefail` trap that aborts a script
# silently, at the first input that simply does not match.
#
# THE TRAP. Under `set -e`, a bare command-substitution assignment fails the script when the
# substitution exits non-zero. `grep` exits 1 when it matches NOTHING, and `grep -c` exits 1 when
# the count is ZERO — both of which are ordinary, expected inputs, not errors. Add `pipefail` and
# a single non-matching grep anywhere in a pipeline fails the whole pipeline. So:
#
#     n=$(grep -c 'needle' "$f")        # 0 matches -> exit 1 -> the SCRIPT ENDS HERE
#     v=$(grep -m1 'k:' "$f" | sed …)   # no match  -> pipefail -> the SCRIPT ENDS HERE
#
# MEASURED, 2026-09-13: this shape in audit-setup.sh's knowledge-review lookup aborted the audit
# inside C2f on every one of five real repos. Every check after that point — adapters, anchoring,
# shell probes, the summary, the exit code — silently did not run. It was caught only because that
# script installs an EXIT trap that says "AUDIT ABORTED" out loud; nothing else would have.
#
# This repo already knows the trap: refresh-extract-checklist.sh and audit-setup.sh both carry
# `# grep -c exits 1 when 0 matches; capture cleanly`. Knowing it in two files and not in the rest
# is what a linter is for.
#
# GUARDED FORMS this accepts, because each makes the non-match a value rather than a failure:
#     v=$(grep … || true)      v=$(grep … || :)      v=$(grep … ) || v=0
#     if v=$(grep …); then     while read … < <(grep …)      [[ $(grep …) ]]
#
# Usage:  lint-shell-pipefail-traps.sh [--quiet]
# Exit:   0 clean / 1 at least one unguarded assignment

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SCRIPTS_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1

BASELINE="$SCRIPTS_DIR/_pipefail-trap-baseline.txt"
hits=0; checked=0; baselined=0

for f in "$ROOT"/scripts/*.sh "$ROOT"/tests/*/run.sh; do
  [ -f "$f" ] || continue
  # Only scripts that actually run under the trap.
  head -40 "$f" | grep -qE '^set -[a-z]*e[a-z]*' || continue
  grep -q 'pipefail' "$f" || continue
  checked=$((checked + 1))
  rel="${f#$ROOT/}"

  while IFS=: read -r ln line; do
    [ -n "${ln:-}" ] || continue
    # Guarded: ANY `||` fallback on the line — inside the substitution (`… || echo 0`),
    # inside a brace group (`$( { grep … || echo 0; } | tail -1 )`), or after it
    # (`v=$(grep …) || v=0`). Narrowing this to a fixed list of fallbacks produced five false
    # positives on the first run, every one of them already correct code. A linter that flags
    # correct code is one someone silences.
    printf '%s' "$line" | grep -qF '||' && continue
    # Guarded: the assignment is itself the condition of an if/while.
    printf '%s' "$line" | grep -qE '^[[:space:]]*(if|while|until|elif)[[:space:]]' && continue
    if grep -qxF "$rel:$ln" "$BASELINE" 2>/dev/null; then
      baselined=$((baselined + 1)); continue
    fi
    hits=$((hits + 1))
    printf '  \033[31mTRAP\033[0m %s:%s\n        %s\n' "$rel" "$ln" "$(printf '%s' "$line" | sed 's/^[[:space:]]*//' | cut -c1-110)"
  done < <(grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\$\([^)]*\b(grep|rg)\b[^)]*\)[[:space:]]*$' "$f" 2>/dev/null || true)
done

if [ "$QUIET" -eq 0 ]; then
  echo ""
  echo "pipefail-traps: $checked script(s) checked, $hits unguarded, $baselined baselined"
fi

if [ "$hits" -gt 0 ]; then
  cat <<'EOF'

Each line above ends its script the first time that grep matches nothing — which is an
ordinary input, not an error. Add a fallback so the non-match becomes a value:

    n=$(grep -c 'x' "$f" 2>/dev/null) || n=0
    v=$(grep -m1 'k:' "$f" 2>/dev/null | sed 's/…//' || true)

Do NOT silence this by moving the line; the abort is real and silent.
EOF
  exit 1
fi
exit 0
