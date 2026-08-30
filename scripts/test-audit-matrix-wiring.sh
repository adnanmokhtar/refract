#!/usr/bin/env bash
# test-audit-matrix-wiring.sh — Phase 2 acceptance for the matrix wiring in commands/audit.md.
#
# The plan's acceptance is behavioural ("--focus=security still runs and now returns the union of
# Security × *"), and /audit is a prompt, not a binary — there is nothing to execute here. What CAN
# be asserted mechanically is that the contract the prompt promises is actually written down and
# internally consistent, which is where this class of change rots first: a flag documented in one
# section and forgotten in another.
set -uo pipefail
export LC_ALL=C
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
A="$ROOT/commands/audit.md"; MODEL="$ROOT/templates/_review-model.md"
FAIL=0; QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
say(){ [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
ok(){ say "  ok    $*"; }
no(){ printf '  FAIL  %s\n' "$*" >&2; FAIL=1; }

# 1 — all 8 legacy focus keys still documented
miss=""
for k in arch quality security db perf scale infra obs; do
  grep -qE "^[[:space:]]*\| \`$k\` \|" "$A" || miss="$miss $k"
done
[ -z "$miss" ] && ok "all 8 legacy --focus keys map to a cell set" || no "legacy --focus keys unmapped:$miss"

# 2 — the new selectors exist
for f in -- -surface= -concern=; do :; done
grep -q '`--surface=<list>`' "$A" && grep -q '`--concern=<list>`' "$A" \
  && ok "--surface and --concern selectors documented" || no "new selectors missing"

# 3 — every surface named ANYWHERE in audit.md resolves in the model.
# Done in python because the distinction is not expressible in POSIX ERE: a structural surface is
# a bare `_word` token, while `_extracted-idioms.md` / `_arch.md` / `_review-model.md` are
# FILENAMES that also start with an underscore. Two earlier greps missed a seeded `_datastore`
# because it sat inside a wider backtick span (`Tenancy × _datastore`) rather than its own.
if python3 - "$A" "$MODEL" <<'PYEOF'
import re, sys
audit = open(sys.argv[1], encoding="utf-8").read()
model = open(sys.argv[2], encoding="utf-8").read()

m = re.search(r"\n### 2\.2 .*?\n(.*?)(?=\n## )", model, re.S)
structural = set(re.findall(r"`(_[a-z0-9]+)`", m.group(1) if m else ""))
m = re.search(r"\n### 2\.1 .*?\n.*?```\n(.*?)```", model, re.S)
signals = set((m.group(1) if m else "").split())

# Only tokens used IN SURFACE POSITION count. A bare _word scan over the whole file is wrong
# in the other direction: it flagged `--exclude=tests,migrations,_examples`, which names a
# directory to skip, not a surface. Surface position = either side of a cell's `×`, or listed
# in the Phase 0 SURFACES resolution block.
used = set(re.findall(r"×\s+`?(_[a-z]+)`?", audit))
used |= set(re.findall(r"`?(_[a-z]+)`?\s*×", audit))
blk = re.search(r"SURFACES\s+←(.*?)```", audit, re.S)
if blk:
    used |= set(re.findall(r"`(_[a-z]+)`", blk.group(1)))
bad = sorted(used - structural - signals)
if bad:
    print("  FAIL  unresolvable structural surface(s): " + " ".join(bad), file=sys.stderr)
    sys.exit(1)
print("  ok    every surface named in audit.md resolves in _review-model.md "
      "(%d structural refs checked)" % len(used))
PYEOF
then :; else FAIL=1; fi

# 4 — dispatch is surface-major, and says so
grep -q "surface-major" "$A" && ok "Phase 1 declares surface-major dispatch" || no "Phase 1 does not declare surface-major dispatch"

# 5 — the prose-kind trap is called out where the gate is described
grep -q "MUST NOT be used to gate a matrix cell" "$A" \
  && ok "prose PROJECT_KIND families explicitly barred from gating cells" \
  || no "nothing bars frontend-*/backend-* from gating a cell"

# 6 — degraded mode is specified (no silent fallback)
grep -q "Never silently fall back to the flat 8 buckets" "$A" \
  && ok "degraded mode specified when § 11 is absent" || no "no degraded-mode contract"

say ""
[ "$FAIL" -eq 0 ] && say "test-audit-matrix-wiring: PASS" || printf 'test-audit-matrix-wiring: FAIL\n' >&2
exit "$FAIL"
