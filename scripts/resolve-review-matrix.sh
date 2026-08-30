#!/usr/bin/env bash
# resolve-review-matrix.sh — run /audit Phase 0 resolution + Phase 2b cell ledger against a repo.
#
# This is the executable half of what commands/audit.md Phase 0 describes in prose: read the
# target's § 11 technical_signals, intersect with the model's surface vocabulary, add the
# structural surfaces its project_kind implies, then look each resolved surface's 12 concerns up
# in _review-matrix.md and print the three-column ledger.
#
# It does NOT dispatch agents and finds no defects in the target. It answers the prior question:
# WHICH CELLS WOULD RUN, and which are live-but-unreviewed.
#
# Usage: resolve-review-matrix.sh <target-repo>
set -uo pipefail
export LC_ALL=C
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
T="${1:?usage: resolve-review-matrix.sh <target-repo>}"
[ -d "$T" ] || { echo "no such directory: $T" >&2; exit 2; }
KINDS="$("$ROOT/scripts/detect-project-kind.sh" "$T")"
python3 - "$ROOT" "$T" "$KINDS" <<'PY'
import re, sys, os
root, target, kinds = sys.argv[1], sys.argv[2], sys.argv[3].split()
prof = os.path.join(target, ".claude", "_extracted-codebase.md")

# ---- § 11 signals. Two spellings are accepted, and the divergence is REPORTED, not hidden:
# phase-2-profile.md specifies `technical_signals: [...]` on its own line; live profiles also
# emit a markdown-decorated variant. A parser that accepted only the spec'd form would drop to
# degraded mode on a repo that has the data.
sig, spelled = set(), None
if os.path.exists(prof):
    t = open(prof, encoding="utf-8").read()
    m = re.search(r"^technical_signals: \[(.*?)\]", t, re.M)
    if m:
        spelled = "spec"
    else:
        m = re.search(r"canonical registry keys.*?\n`\[(.*?)\]`", t, re.S)
        if m:
            spelled = "variant"
    if m:
        sig = {k.strip() for k in m.group(1).split(",") if k.strip()}
    conf = bool(re.search(r"^technical_signal_confidence:", t, re.M))
else:
    conf = False

model = open(os.path.join(root, "templates/_review-model.md"), encoding="utf-8").read()
signals_vocab = set(re.search(r"### 2\.1 .*?```\n(.*?)```", model, re.S).group(1).split())
struct_rows = re.search(r"### 2\.2 .*?\n(.*?)\n\*\*The", model, re.S).group(1)
struct = re.findall(r"^\| `(_[a-z]+)`", struct_rows, re.M)

surfaces = sorted(sig & signals_vocab)
extra = sorted(sig - signals_vocab)
structural = []
if "server" in kinds: structural += ["_routes"]
if "browser" in kinds or "mobile" in kinds: structural += ["_screens"]
if any(os.path.exists(os.path.join(target, p)) for p in
       ("Dockerfile", "docker-compose.yml", "Jenkinsfile", ".github/workflows")):
    structural += ["_deployment"]
if re.search(r"typeorm|prisma|sequelize|mongoose|knex|sqlalchemy|activerecord",
             open(os.path.join(target, "package.json"), encoding="utf-8").read()
             if os.path.exists(os.path.join(target, "package.json")) else ""):
    structural += ["_database"]
structural = [s for s in sorted(set(structural)) if s in struct]

# ---- matrix lookup
mx = open(os.path.join(root, "templates/_review-matrix.md"), encoding="utf-8").read()
blk = re.search(r"## 2\. The grid.*?```\n(.*?)```", mx, re.S).group(1).splitlines()
cols = blk[0].split()[1:]
rows = {p[0]: p[1:] for p in (l.split() for l in blk[2:]) if len(p) == len(cols) + 1}
G = {"●": "reviewed", "○": "proposed", "·": "live-unreviewed", "–": "n/a"}

resolved = surfaces + structural
print(f"# Cell ledger — {os.path.basename(target)}\n")
print(f"project_kind   : {' '.join(kinds)}")
have_profile = os.path.exists(prof)
if not have_profile:
    print("MODE           : DEGRADED — no .claude/_extracted-codebase.md; run /setup-project first")
    print("§ 11 spelling  : n/a (no profile)")
    print("confidence blk : n/a (no profile)")
elif spelled is None:
    print("MODE           : DEGRADED — profile present but no technical_signals array found")
    print("§ 11 spelling  : NOT FOUND")
    print("confidence blk : n/a (no signals parsed)")
else:
    print(f"§ 11 spelling  : {spelled}"
          + ("   <-- markdown variant, NOT the format phase-2-profile.md specifies" if spelled == "variant" else ""))
    print(f"confidence blk : {'present' if conf else 'ABSENT — ratios are prose only, so no cell gets a denominator'}")
print(f"surfaces       : {len(resolved)}  ({len(surfaces)} signal + {len(structural)} structural)")
if extra:
    print(f"unresolvable   : {', '.join(extra)}  <-- in § 11, not a registry key")
tot = len(resolved) * len(cols)
print(f"cells resolved : {len(resolved)} x {len(cols)} = {tot}\n")

counts = {"reviewed": 0, "n/a": 0, "live-unreviewed": 0, "proposed": 0}
live = []
for s in resolved:
    if s not in rows:
        print(f"  !! {s} has no row in the matrix"); continue
    for i, c in enumerate(cols):
        st = G[rows[s][i]]
        counts[st] += 1
        if st == "live-unreviewed":
            live.append((c, s))
print(f"Reviewed          {counts['reviewed']:>3}   material exists, an agent runs the cell")
print(f"N/A               {counts['n/a']:>3}   reasoned in a concerns/ rule")
print(f"Live, unreviewed  {counts['live-unreviewed']:>3}   <-- nobody is looking at these")
print(f"                  ---")
print(f"                  {sum(counts.values()):>3}   (must equal {tot})\n")
if live:
    print("## Live, unreviewed\n")
    print("| Cell | Surface |")
    print("|---|---|")
    for c, s in sorted(live):
        print(f"| {c} | `{s}` |")
PY
