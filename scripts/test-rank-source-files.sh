#!/usr/bin/env bash
# test-rank-source-files.sh — pin the ranking that replaced depth-4 truncation.
#
# The claim being locked is not "the ranker runs". It is that on the layout the old cap was
# worst at — a workspace where every meaningful file sits below depth 4 — the ranker selects
# what depth truncation deletes, and drops what depth truncation keeps. Case 1 asserts exactly
# that inversion, because a ranking that merely differs from depth order proves nothing.
#
# Usage: test-rank-source-files.sh [--quiet]
# Exit:  0 all assertions hold / 1 one did not

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
RANK="$REPO_ROOT/scripts/rank-source-files.py"

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1
pass=0; fail=0
ok()   { pass=$((pass+1)); [ $QUIET -eq 0 ] && echo "  ok    $1"; return 0; }
bad()  { fail=$((fail+1)); echo "  FAIL  $1"; return 0; }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1 — expected '$3', got '$2'"; }

command -v python3 >/dev/null 2>&1 || { echo "SKIP  rank-source-files (needs python3)"; exit 0; }

echo "=== test-rank-source-files ==="

# ---------- fixture: a workspace whose every real file is at depth 5+ ------------------------
W=$(mktemp -d)
mkdir -p "$W/packages/core/src/shared" "$W/packages/orders/src/modules" \
         "$W/packages/billing/src/modules" "$W/packages/api/src/routes" "$W/tools"
echo 'export class Money {}'          > "$W/packages/core/src/shared/money.ts"
echo 'export const now = () => 0;'    > "$W/packages/core/src/shared/clock.ts"
for p in orders billing; do
  cat > "$W/packages/$p/src/modules/service.ts" <<EOF
import { Money } from "../../../core/src/shared/money";
import { now } from "../../../core/src/shared/clock";
import express from "express";
EOF
done
cat > "$W/packages/api/src/routes/index.ts" <<'EOF'
import { o } from "../../../orders/src/modules/service";
import { b } from "../../../billing/src/modules/service";
import { Money } from "../../../core/src/shared/money";
EOF
echo 'export const scratch = 1;' > "$W/tools/oneoff.ts"

top=$(python3 "$RANK" "$W" --format list | head -1)
assert_eq "the most widely imported file ranks first" "$top" "packages/core/src/shared/money.ts"

last=$(python3 "$RANK" "$W" --format list | tail -1)
assert_eq "the file nothing imports and that imports nothing ranks last" "$last" "tools/oneoff.ts"

# THE inversion: depth-4 keeps exactly tools/oneoff.ts and drops the other five.
sel=$(python3 "$RANK" "$W" --limit 5 --format list)
if printf '%s\n' "$sel" | grep -q 'tools/oneoff.ts'; then
  bad "a top-5 budget must not spend a slot on the only file depth-4 would have kept"
else
  ok "top-5 excludes the depth-2 throwaway that depth truncation kept"
fi
deep=$(printf '%s\n' "$sel" | awk -F/ 'NF>4' | wc -l | tr -d ' ')
assert_eq "all 5 selected files sit below depth 4, where truncation deleted them" "$deep" "5"

# ---------- the hub/root split, and that an entry point survives it --------------------------
three=$(python3 "$RANK" "$W" --limit 3 --format list)
if printf '%s\n' "$three" | grep -q 'packages/api/src/routes/index.ts'; then
  ok "a 3-file budget still reserves a slot for the entry point (root band)"
else
  bad "the root band lost its reserved slot — entry points are invisible to in-degree alone"
fi

# ---------- a bare package specifier must contribute nothing ---------------------------------
unres=$(python3 "$RANK" "$W" --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["unresolved_specifiers"])')
[ "$unres" -ge 2 ] && ok "bare package imports counted as unresolved, not resolved to a guess" \
                    || bad "expected the 2 `express` imports to be unresolved, got $unres"

# ---------- determinism ----------------------------------------------------------------------
a=$(python3 "$RANK" "$W" --format list); b=$(python3 "$RANK" "$W" --format list)
assert_eq "two runs agree exactly (no set-iteration order leaking into the rank)" "$a" "$b"

# ---------- python: absolute AND relative resolution ------------------------------------------
P=$(mktemp -d); mkdir -p "$P/src/core" "$P/src/orders"
echo 'class Money: pass' > "$P/src/core/money.py"
printf 'from src.core.money import Money\n'                     > "$P/src/orders/service.py"
printf 'from ..core.money import Money\nimport src.orders.service\n' > "$P/src/orders/api.py"
ptop=$(python3 "$RANK" "$P" --format list | head -1)
assert_eq "python: dotted and relative imports both resolve" "$ptop" "src/core/money.py"

# ---------- tests are excluded from the census unless asked -----------------------------------
mkdir -p "$W/packages/core/src/shared/__tests__"
echo 'import { Money } from "../money";' > "$W/packages/core/src/shared/__tests__/money.test.ts"
n_no=$(python3 "$RANK" "$W" --format list | wc -l | tr -d ' ')
n_yes=$(python3 "$RANK" "$W" --include-tests --format list | wc -l | tr -d ' ')
[ "$n_yes" -gt "$n_no" ] && ok "test files are excluded by default, included on --include-tests" \
                         || bad "--include-tests changed nothing ($n_no vs $n_yes)"

rm -rf "$W" "$P"
echo "----"
echo "rank-source-files: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
