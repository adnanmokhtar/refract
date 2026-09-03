#!/usr/bin/env bash
# verify-gate-count.sh — CONTRIBUTING's gate count must equal the workflow's.
#
# WHY. CONTRIBUTING carried THREE different counts at once — 33, 25 and 19 — for the same set of
# CI steps, while the workflow ran 48. Nothing read the workflow, so every number was written by
# hand and each drifted on its own schedule. A contributor who trusts "all 25 gates are green"
# and sees 48 results has no way to tell which figure lies.
#
# The workflow is the only source that cannot be wrong about itself: it IS the gates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WF="$REPO_ROOT/.github/workflows/quality-gates.yml"
DOC="$REPO_ROOT/CONTRIBUTING.md"

actual="$( { grep -cE '^      - name: ' "$WF" || echo 0; } | tail -1 )"

# A step excluded from blocking would make "blocking steps" a different number than "steps".
soft="$( { grep -cE 'continue-on-error' "$WF" || echo 0; } | tail -1 )"
if [[ "$soft" -ne 0 ]]; then
  echo "FAIL — $soft step(s) are continue-on-error; 'blocking' is no longer the same as 'named'." >&2
  exit 1
fi

fail=0
while IFS= read -r line; do
  n="${line%%:*}"; txt="${line#*:}"
  # A QUOTED figure is a citation, not a claim. CONTRIBUTING documents its own history — the row
  # explaining this gate quotes "all 25 gates are green" as the wrong number it was written to
  # catch. Scanning that made the gate fail on the sentence describing it. Strip double-quoted
  # spans before looking for a live claim.
  txt="$(printf '%s' "$txt" | sed -E 's/"[^"]*"//g')"
  claimed="$(printf '%s' "$txt" | sed -nE 's/.*[^0-9]([0-9]+) (blocking (steps|gates)|gates are green).*/\1/p' | head -1)"
  [[ -n "$claimed" ]] || continue
  if [[ "$claimed" -ne "$actual" ]]; then
    echo "FAIL — CONTRIBUTING.md:$n claims $claimed; the workflow defines $actual." >&2
    fail=1
  fi
done < <(grep -nE '[0-9]+ (blocking (steps|gates)|gates are green)' "$DOC")

[[ $fail -eq 0 ]] || exit 1
echo "PASS — every gate-count claim in CONTRIBUTING matches the workflow's $actual steps."
