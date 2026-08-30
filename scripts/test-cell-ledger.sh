#!/usr/bin/env bash
# test-cell-ledger.sh — fixture suite for check_cell_ledger in validate-audit-artifacts.sh.
#
# WHY THIS SUITE EXISTS. The ledger's whole value is the third column — "live, unreviewed", the
# cells where the surface exists, the concern applies, and no detector does. That column only
# means anything if three things cannot rot:
#   § 1  a bare "N/A" must be rejected. A reasonless N/A is indistinguishable from work that was
#        skipped, which is precisely how a coverage gap disguises itself as a scoping decision.
#   § 2  the three counts must sum to the resolved cell count. A cell that is silently absent is
#        the failure the ledger was built to make impossible.
#   § 3  the ledger must LEAD the artifact. Buried under the findings it answers nothing — the
#        reader is meant to learn what nobody is looking at before reading a single finding.
#   § 4  an artifact carrying findings with no ledger at all must fail.
#   § 5  a well-formed ledger must still PASS (the fix must not buy safety by rejecting everything).
#
# Everything runs under mktemp -d. Nothing is written outside it.
# Usage: test-cell-ledger.sh [--quiet]   Exit: 0 all pass / 1 a fixture failed
set -uo pipefail
export LC_ALL=C
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
V="${VALIDATOR_OVERRIDE:-$ROOT/scripts/validate-audit-artifacts.sh}"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
FAIL=0
say(){ [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

cat > "$W/ok.md" <<'EOF'
## Cell ledger — 11 surfaces × 12 concerns = 132 cells

Reviewed          78   findings ranked below
N/A               31   each with a reason
Live, unreviewed  23   nobody is looking at these

### N/A
| Cell | Reason |
|---|---|
| Tenancy × public-api | single-tenant project, no tenant anchor in schema |
| AI/LLM × _database | no LLM SDK present anywhere in the manifest |

### Live, unreviewed
| Cell | Surface population | Why nothing ran |
|---|---|---|
| Authorization × background-jobs | 34 job classes | no detector exists in any pack or domain |

## P0 — scale blockers
**P0-1** something at `src/a.ts:12`
EOF

python3 - "$W" <<'PY'
import sys, io
W = sys.argv[1]
g = io.open(f"{W}/ok.md", encoding="utf-8").read()
io.open(f"{W}/bad_sum.md",   "w", encoding="utf-8").write(g.replace("Reviewed          78", "Reviewed          70"))
io.open(f"{W}/bad_bare.md",  "w", encoding="utf-8").write(g.replace("| single-tenant project, no tenant anchor in schema |", "| N/A |"))
io.open(f"{W}/bad_order.md", "w", encoding="utf-8").write("## P0 — scale blockers\n**P0-9** early at `x.ts:1`\n\n" + g)
io.open(f"{W}/bad_none.md",  "w", encoding="utf-8").write("## P0 — scale blockers\n**P0-1** x at `a.ts:1`\n")
PY

expect(){ # file, want(pass|fail), pattern, label
  local out; out="$( cd "$W" && bash "$V" --plan="$1" 2>&1 )"
  if [ "$2" = "pass" ]; then
    if printf '%s' "$out" | grep -q "✓ cell ledger"; then say "  ok    $4"; else say "  FAIL  $4"; FAIL=1; fi
  else
    if printf '%s' "$out" | grep -q "$3"; then say "  ok    $4"; else say "  FAIL  $4 (not rejected)"; FAIL=1; fi
  fi
}
say "cell-ledger fixtures"
expect ok.md        pass ""                  "§ 5  a well-formed ledger passes"
expect bad_bare.md  fail "bare N/A"          "§ 1  a bare N/A is rejected"
expect bad_sum.md   fail "ledger arithmetic" "§ 2  counts that do not sum are rejected"
expect bad_order.md fail "must LEAD"         "§ 3  a ledger buried under findings is rejected"
expect bad_none.md  fail "no cell ledger"    "§ 4  findings with no ledger are rejected"
say ""
[ "$FAIL" -eq 0 ] && say "test-cell-ledger: PASS" || printf 'test-cell-ledger: FAIL\n' >&2
exit "$FAIL"
