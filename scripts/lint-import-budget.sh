#!/usr/bin/env bash
# lint-import-budget.sh — the tier budgets in templates/import-tiers.md are a table nobody sums.
#
# WHY. `commands/setup-project.md` declares its imports in three tiers, and
# `templates/import-tiers.md` gives each tier a line budget:
#
#     HOT   loaded EVERY session, before any phase      ≤ 600 lines combined
#     WARM  loaded when the relevant phase is active    per-file ≤ 600 lines
#     COLD  loaded only on explicit demand              unbounded
#
# HOT is the one that costs on every single run whether or not it is used, which is the whole
# reason it has a ceiling. Until this gate, that ceiling lived in a markdown table and in nobody's
# tooling: `import-tiers.md` said `≤ 600 lines combined`, and no script had ever added the four
# files up. A section appended to `governance/hard-rules.md` could push every future session over
# the budget and produce no signal anywhere — the failure is silent by construction, because
# nothing gets slower or breaks, it just costs more forever.
#
# Measured when this gate was written: HOT is 542 of 600. That is 58 lines of headroom, i.e. one
# ordinary section. The budget was not being violated; it was being watched by nobody.
#
# WHY COLD IS COUNTED AND NOT ENFORCED. `import-tiers.md` gives COLD no ceiling on purpose — it is
# loaded on demand, so its size is paid only by the run that asks. The gate prints the total anyway,
# because a COLD tier that quietly becomes bigger than HOT + WARM combined is worth seeing even
# though no rule is broken. Reporting a number is not the same as enforcing it, and the reach line
# says which it is doing.
#
# THE CHECKS
#
#   [1] check_hot_budget  (FAIL)
#       The HOT files' combined line count is within the budget parsed from import-tiers.md. Not a
#       hardcoded 600: the number is read from the table, so editing the budget in the doc moves the
#       gate with it and the two cannot disagree. If the table stops stating a number, that is a FAIL
#       too — an unstated budget is not an infinite one.
#
#   [2] check_warm_budget  (FAIL, baselined)
#       Every WARM file is individually within the per-file budget. Three were over when this gate
#       was written (phase-4.2-apply 686, phase-2-profile 634, phase-4.0-preflight 624). They are
#       carried in scripts/_import-budget-baseline.txt as `REPAIR:` lines — the convention
#       scripts/_handoff-baseline.md defines for a defect that is pending a fix rather than accepted.
#       Splitting a 686-line phase file is a content change with its own review; recording it as
#       accepted would be the lie, and recording it as invisible would be worse.
#
#   [3] check_declared_files_exist  (FAIL)
#       Every path in the imports block resolves. A budget computed over a list where two entries
#       silently do not exist is a budget that always passes.
#
# Usage:  lint-import-budget.sh [--repo-root=<dir>]
# Exit:   1 on any FAIL; 0 otherwise.
# Notes:  bash 3.2 (macOS) compatible. Parsing is stdlib python3 — the imports block is YAML-shaped
#         and a shell parser for it would be the fragile half of this gate.

set -euo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
REPO_ROOT="$(cd -P "$REPO_ROOT" && pwd)"   # absolute before cd
cd "$REPO_ROOT" || exit 1

command -v python3 >/dev/null 2>&1 || { echo "SKIP  lint-import-budget (needs python3)"; exit 0; }

echo "=== lint-import-budget ==="
echo "Repo: $REPO_ROOT"
echo ""

python3 - "$REPO_ROOT" <<'PY'
import os, re, sys

ORCH     = "commands/setup-project.md"
TIERS    = "templates/import-tiers.md"
BASELINE = "scripts/_import-budget-baseline.txt"

fails = warns = 0

def fail(msg):
    global fails; print("  FAIL  " + msg); fails += 1

for p in (ORCH, TIERS):
    if not os.path.exists(p):
        print("  FAIL  missing: " + p); sys.exit(1)

# ---- budgets, read from the doc's own table rather than hardcoded ----
# | HOT | ... | ≤ 600 lines combined |    | WARM | ... | per-phase ≤ 600 lines |
budgets = {}
for line in open(TIERS):
    m = re.match(r'^\|\s*(HOT|WARM|COLD)\s*\|', line)
    if not m:
        continue
    tier = m.group(1).lower()
    b = re.search(r'≤\s*([0-9]+)\s*lines', line)
    budgets[tier] = int(b.group(1)) if b else None

# ---- the declared tiers ----
src = open(ORCH).read()
m = re.search(r'^imports:\n(.*?)^(?=\S)', src, re.S | re.M)
if not m:
    print("  FAIL  %s declares no imports: block" % ORCH); sys.exit(1)

tiers, tier = {}, None
for line in m.group(1).split("\n"):
    t = re.match(r'^  (hot|warm|cold):\s*$', line)
    if t:
        tier = t.group(1); tiers[tier] = []; continue
    f = re.match(r'^\s+- (\S+)\s*$', line)
    if f and tier:
        tiers[tier].append(f.group(1))

def lines_of(p):
    with open(p) as fh:
        return sum(1 for _ in fh)

# ---- [3] first: a budget over files that do not exist always passes ----
print("[3] every declared import resolves on disk")
missing = [(t, f) for t in ("hot", "warm", "cold") for f in tiers.get(t, []) if not os.path.exists(f)]
for t, f in missing:
    fail("%s tier declares %s, which does not exist" % (t.upper(), f))
if not missing:
    print("  ok — all %d declared imports resolve" % sum(len(v) for v in tiers.values()))

# ---- baseline: a line suppresses only when it carries a reason ----
def baselined(path):
    global warns
    if not os.path.exists(BASELINE):
        return False
    for raw in open(BASELINE):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, _, reason = line.partition("#")
        if key.strip() != path:
            continue
        if reason.strip():
            return True
        print("  WARN  baseline line has no '# reason' and suppresses nothing: " + path)
        warns += 1
        return False
    return False

# ---- [1] HOT, combined ----
hot_budget = budgets.get("hot")
print("[1] HOT is within its combined budget")
hot_files = [f for f in tiers.get("hot", []) if os.path.exists(f)]
hot_total = sum(lines_of(f) for f in hot_files)
if hot_budget is None:
    fail("%s states no line budget for HOT — an unstated budget is not an infinite one" % TIERS)
elif hot_total > hot_budget:
    fail("HOT is %d lines against a %d budget (over by %d) — every session pays this"
         % (hot_total, hot_budget, hot_total - hot_budget))
    for f in sorted(hot_files, key=lambda x: -lines_of(x)):
        print("          %5d  %s" % (lines_of(f), f))
else:
    print("  ok — HOT %d of %d lines (%d spare) across %d files"
          % (hot_total, hot_budget, hot_budget - hot_total, len(hot_files)))

# ---- [2] WARM, per file ----
warm_budget = budgets.get("warm")
print("[2] every WARM file is within the per-file budget")
# Symmetry with check [1], and for the same reason: an unstated budget is not an infinite one.
# Without this, deleting `≤ 600 lines` from the WARM row of import-tiers.md made three
# REPAIR-baselined over-budget files vanish and the gate print "0 over budget / PASS" — the table
# silently disarming the check that reads it.
if warm_budget is None:
    fail("%s states no per-file line budget for WARM — an unstated budget is not an infinite one" % TIERS)
warm_files = [f for f in tiers.get("warm", []) if os.path.exists(f)]
suppressed = over = 0
for f in sorted(warm_files, key=lambda x: -lines_of(x)):
    n = lines_of(f)
    if warm_budget is None or n <= warm_budget:
        continue
    if baselined(f):
        suppressed += 1; continue
    fail("%s is %d lines against a %d per-file budget (over by %d)" % (f, n, warm_budget, n - warm_budget))
    over += 1
if over == 0:
    print("  ok — %d WARM files, %d over budget and baselined as REPAIR" % (len(warm_files), suppressed))

warm_total = sum(lines_of(f) for f in warm_files)
cold_files = [f for f in tiers.get("cold", []) if os.path.exists(f)]
cold_total = sum(lines_of(f) for f in cold_files)

print("")
print("reach: HOT %d/%d combined · WARM %d files, cap %d each, %d baselined · %d checked"
      % (hot_total, hot_budget or 0, len(warm_files), warm_budget or 0, suppressed,
         len(hot_files) + len(warm_files)))
print("       not enforced: COLD %d lines across %d files — import-tiers.md gives it no ceiling, "
      "it is paid only by the run that asks; reported so a COLD tier outgrowing HOT+WARM (%d) is visible"
      % (cold_total, len(cold_files), hot_total + warm_total))

if fails:
    print("FAIL  %d budget violation(s). Split the file, or add a line WITH a reason to %s." % (fails, BASELINE))
    sys.exit(1)
if warns:
    print("WARN  %d inert baseline line(s)." % warns)
print("PASS")
PY
