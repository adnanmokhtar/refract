#!/usr/bin/env bash
# lint-rule-literals.sh — a number a MUST rule enforces lives in the threshold registry.
#
# WHY. The same value was restated in six to ten rule files, and about eighteen of them had
# drifted: retry attempts 5 here and 3 there, a 2 s timeout in one rule and "500–1000 ms" in
# another, a 30-line function cap that no linter in the project agreed with. Two rules that both
# restate a number WILL disagree the first time one of them is edited. The fix is one home —
# templates/governance/thresholds.json — and rules that cite the id (`THR-RES-RETRY`) instead of
# the value. This gate keeps new literals out while the old ones are migrated.
#
# WHAT COUNTS. A threshold-shaped numeric literal — a number with a unit (ms, s, min, h, days,
# %, lines, KB/MB, attempts, retries, chars, tokens, pt, dp, px, rows, items …) or behind a
# comparator (≤ ≥ < > at most / at least / max / min / up to / cap) — on a MUST line of a rule:
#   • a line under a heading that says Must / Must not / Hard rule(s) / Never / Always / Forbidden;
#   • a line that says MUST / MUST NOT, or a `> **Hard rule` TL;DR;
#   • every table row of the engineering-baseline catalog (each row is a standard).
# Fenced code blocks are skipped (they are samples). A line that cites a `THR-` id is registered,
# and every cited id (templates/, commands/, docs/) must exist in the registry — a dangling
# citation fails regardless of the ratchet.
# A literal whose (value, unit) is the registry's own value for some id is reported as
# "same value as THR-x" — often the cheapest migration: replace it with the citation.
#
# RATCHET, not zero. Per-file counts are recorded in scripts/_rule-literals-baseline.txt; a file
# may not GROW past its count and a file with no record must have none. Shrinking is always
# allowed — re-record with --record afterwards.
#
# Scope: templates/packs/*/rules, templates/domains/*/rules, templates/repo-baseline/.claude/rules,
# templates/workspace-baseline/.claude/rules, templates/governance/engineering-baseline.
#
# Usage:  lint-rule-literals.sh [--root=<dir>] [--record] [--list] [--self-test] [--quiet]
# Exit:   0 at or below the ratchet · 1 a file grew / unrecorded file has literals · 2 usage
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
ROOT="$REPO_ROOT"; MODE=check; QUIET=0
for a in "$@"; do
  case "$a" in
    --root=*)    ROOT="${a#--root=}" ;;
    --record)    MODE=record ;;
    --list)      MODE=list ;;
    --self-test) MODE=selftest ;;
    --quiet)     QUIET=1 ;;
    -h|--help)   sed -n '2,31p' "$SELF"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "ERR: python3 required" >&2; exit 2; }

if [ "$MODE" = selftest ]; then
  TD=$(mktemp -d "${TMPDIR:-/tmp}/lint-rule-literals.XXXXXX"); trap 'rm -rf "$TD"' EXIT
  mkdir -p "$TD/templates/packs/demo/rules" "$TD/templates/governance" "$TD/scripts"
  cp "$REPO_ROOT/templates/governance/thresholds.json" "$TD/templates/governance/"
  cat > "$TD/templates/packs/demo/rules/demo.md" <<'MD'
# Demo
## Must
- Every outbound call has a timeout of 2000 ms.
- Retries follow `THR-RES-RETRY` — at most 3 attempts.
```
sleep 500ms   # sample, ignored
```
## Should
- Keep pages under 50 items.
MD
  p=0; f=0
  out=$(bash "$SELF" --root="$TD" --list 2>&1)
  if printf '%s' "$out" | grep -q 'demo.md:3.*2000 ms'; then p=$((p+1)); else f=$((f+1)); echo "  FAIL a literal on a Must line was not reported"; fi
  if printf '%s' "$out" | grep -q 'demo.md:4'; then f=$((f+1)); echo "  FAIL a line citing THR- was reported"; else p=$((p+1)); fi
  if printf '%s' "$out" | grep -q 'sleep 500'; then f=$((f+1)); echo "  FAIL a fenced sample was reported"; else p=$((p+1)); fi
  if printf '%s' "$out" | grep -q '50 items'; then f=$((f+1)); echo "  FAIL a Should line was reported"; else p=$((p+1)); fi
  if printf '%s' "$out" | grep -q 'same value as THR-RES-TIMEOUT'; then p=$((p+1)); else f=$((f+1)); echo "  FAIL a registry value was not traced to its id"; fi
  bash "$SELF" --root="$TD" --record --quiet >/dev/null 2>&1
  if bash "$SELF" --root="$TD" --quiet >/dev/null 2>&1; then p=$((p+1)); else f=$((f+1)); echo "  FAIL recorded tree should pass"; fi
  printf -- '- The job MUST stop after 45 seconds.\n' >> "$TD/templates/packs/demo/rules/demo.md"
  if bash "$SELF" --root="$TD" --quiet >/dev/null 2>&1; then f=$((f+1)); echo "  FAIL a new MUST literal did not fail the ratchet"; else p=$((p+1)); fi
  printf -- '- Use `THR-NO-SUCH-ID` here.\n' >> "$TD/templates/packs/demo/rules/demo.md"
  bash "$SELF" --root="$TD" --record --quiet >/dev/null 2>&1
  if bash "$SELF" --root="$TD" --quiet >/dev/null 2>&1; then f=$((f+1)); echo "  FAIL a citation of an undefined THR- id passed"; else p=$((p+1)); fi
  echo "lint-rule-literals self-test: $p passed, $f failed"
  [ "$f" -eq 0 ]; exit $?
fi

ROOT="$ROOT" MODE="$MODE" QUIET="$QUIET" python3 - <<'PY'
import os, re, sys, glob, json
root = os.environ['ROOT']; mode = os.environ['MODE']; quiet = os.environ['QUIET'] == '1'
base_file = os.path.join(root, 'scripts', '_rule-literals-baseline.txt')
globs = ['templates/packs/*/rules/*.md', 'templates/domains/*/rules/*.md',
         'templates/repo-baseline/.claude/rules/*.md', 'templates/workspace-baseline/.claude/rules/*.md',
         'templates/governance/engineering-baseline/*.md']
files = sorted(set(f for g in globs for f in glob.glob(os.path.join(root, g))))

UNIT = r'(?:ms|s|sec|secs|seconds?|mins?|minutes?|h|hrs?|hours?|days?|d|weeks?|%|lines?|LOC|[KMG]i?B|kB|attempts?|retries|tries|chars?|characters|tokens?|pt|dp|px|rows?|items?|calls?|requests?|req|rps|RPS|x|×|MiB)'
NUM = r'\d+(?:[.,]\d+)?'
LIT = re.compile(r'(?<![\w.-])(' + NUM + r')\s?(' + UNIT + r')(?![\w])'
                 r'|(?:≤|≥|<=|>=|\bat most\b|\bat least\b|\bmax(?:imum)?\b|\bmin(?:imum)?\b|\bup to\b|\bno more than\b|\bcap(?:ped)?(?: at)?\b)\s*(' + NUM + r')(?![\w.])', re.I)
MUST_HEAD = re.compile(r'^#{1,6}\s.*\b(must|hard rules?|never|always|forbidden|non-negotiable)\b', re.I)
HEAD = re.compile(r'^(#{1,6})\s')
IGNORE = re.compile(r'(RFC|WCAG|OWASP|CWE|CVE|ISO|HTTP/|TLS|SHA-?\d|UTF-?\d|IPv\d|OAuth|ES\d|Python \d|Node \d|v\d)', re.I)

# registry values → id, for the "restates THR-x" hint
reg = {}
try:
    th = json.load(open(os.path.join(root, 'templates', 'governance', 'thresholds.json')))['thresholds']
    def walk(tid, v, unit, key=''):
        if isinstance(v, dict):
            for k, x in v.items(): walk(tid, x, unit, k)
        elif isinstance(v, (int, float)) and not isinstance(v, bool):
            u = unit.lower(); k = key.lower()
            for suf in ('_ms', '_max_min', '_h', '_pct', '_mib', '_days', '_pt', '_dp'):
                if k.endswith(suf): u = suf.split('_')[-1]
            if k.endswith('_min') and not k.endswith('_max_min'): u = unit.lower()   # a minimum, not minutes
            reg.setdefault((str(v), u), tid)
            if u in ('ms',) and v >= 1000 and v % 1000 == 0: reg.setdefault((str(v // 1000), 's'), tid)
    for tid, e in th.items(): walk(tid, e.get('value'), e.get('unit', ''))
except Exception:
    pass
UNORM = {'s': 's', 'sec': 's', 'secs': 's', 'second': 's', 'seconds': 's', 'min': 'min', 'mins': 'min', 'minute': 'min',
         'minutes': 'min', 'h': 'h', 'hr': 'h', 'hrs': 'h', 'hour': 'h', 'hours': 'h', '%': 'pct', 'mib': 'mib',
         'attempt': 'attempts', 'attempts': 'attempts', 'items': 'items', 'item': 'items', 'lines': 'lines', 'line': 'lines'}

def scan(path):
    rel = os.path.relpath(path, root)
    is_catalog = '/governance/engineering-baseline/' in '/' + rel
    out = []; fence = False; in_must = False; must_level = 0; fm = 0
    for n, line in enumerate(open(path, encoding='utf-8', errors='replace'), 1):
        s = line.rstrip('\n')
        if n == 1 and s.strip() == '---': fm = 1; continue
        if fm == 1:
            if s.strip() == '---': fm = 2
            continue
        if s.lstrip().startswith('```'): fence = not fence; continue
        if fence: continue
        h = HEAD.match(s)
        if h:
            lvl = len(h.group(1))
            if MUST_HEAD.match(s): in_must, must_level = True, lvl
            elif in_must and lvl <= must_level: in_must = False
            continue
        must = in_must or bool(re.search(r'\bMUST\b', s)) or s.lstrip().startswith('> **Hard rule') \
               or (is_catalog and s.startswith('| ') and not s.startswith('| ID') and not set(s) <= set('|-: '))
        if not must or 'THR-' in s: continue
        for m in LIT.finditer(s):
            frag = m.group(0).strip()
            ctx = s[max(0, m.start() - 12):m.end() + 4]
            if IGNORE.search(ctx): continue
            num = m.group(1) or m.group(3); unit = (m.group(2) or '').lower()
            hint = reg.get((num, UNORM.get(unit, unit)))
            out.append((rel, n, frag, hint))
    return out

# Registry integrity: it parses, and every THR- id cited anywhere resolves (a citation of an id
# that does not exist is a rule pointing at nothing — worse than the literal it replaced).
cite_errs = []
try:
    ids = set(json.load(open(os.path.join(root, 'templates', 'governance', 'thresholds.json')))['thresholds'])
except Exception as e:
    ids = set(); cite_errs.append('templates/governance/thresholds.json does not parse: %s' % e)
CITE = re.compile(r'\bTHR-[A-Z0-9]+(?:-[A-Z0-9]+)*\b')
for dp, dn, fn in os.walk(root):
    if '/.git' in dp or '/node_modules' in dp or '/tmp' in dp.replace(root, '', 1)[:4]: continue
    rp = os.path.relpath(dp, root)
    if not (rp.startswith('templates') or rp.startswith('commands') or rp == 'docs' or rp.startswith('docs/')): continue
    for f in fn:
        if not f.endswith(('.md', '.json')): continue
        fp = os.path.join(dp, f)
        try: txt = open(fp, encoding='utf-8', errors='replace').read()
        except Exception: continue
        for m in CITE.finditer(txt):
            if m.group(0) not in ids and ids:
                cite_errs.append('%s: cites %s, which templates/governance/thresholds.json does not define' % (os.path.relpath(fp, root), m.group(0)))
cite_errs = sorted(set(cite_errs))

found = {}
allhits = []
for f in files:
    hits = scan(f)
    allhits += hits
    if hits: found[os.path.relpath(f, root)] = len(hits)

if mode == 'list':
    for rel, n, frag, hint in allhits:
        print('%s:%d  %s%s' % (rel, n, frag, ('  (same value as %s)' % hint) if hint else ''))
    print('total %d literal(s) in %d file(s)' % (len(allhits), len(found)))
    sys.exit(0)

if mode == 'record':
    if cite_errs:
        for e in cite_errs: print('  ✗ ' + e)
        sys.exit(1)
    with open(base_file, 'w') as fh:
        fh.write('# Threshold-shaped literals on MUST lines, per rule file. A file may not GROW past its count.\n')
        fh.write('# Regenerate: bash scripts/lint-rule-literals.sh --record   (after migrating literals to THR- ids)\n')
        for rel in sorted(found): fh.write('%s %d\n' % (rel, found[rel]))
    if not quiet: print('recorded %d file(s), %d literal(s) → %s' % (len(found), sum(found.values()), base_file))
    sys.exit(0)

rec = {}
if os.path.isfile(base_file):
    for l in open(base_file):
        if l.startswith('#') or not l.strip(): continue
        p, c = l.split(); rec[p] = int(c)
errs = []; shrunk = []
for rel, c in sorted(found.items()):
    r = rec.get(rel)
    if r is None: errs.append('%s: %d unregistered literal(s) on MUST lines (unrecorded file) — cite a THR- id from templates/governance/thresholds.json' % (rel, c))
    elif c > r: errs.append('%s: %d literal(s), recorded %d — a NEW number on a MUST line; cite the THR- id instead' % (rel, c, r))
    elif c < r: shrunk.append(rel)
for rel in rec:
    if rel not in found: shrunk.append(rel)
restates = sum(1 for h in allhits if h[3])
if not quiet:
    print('Rule literals — %d on MUST lines across %d file(s) (ratchet: %d recorded); %d restate a registry value' %
          (len(allhits), len(found), sum(rec.values()), restates))
    if shrunk: print('  shrank: %d file(s) — re-record with --record' % len(set(shrunk)))
errs = cite_errs + errs
if errs:
    for e in errs: print('  ✗ ' + e)
    for rel, n, frag, hint in allhits:
        if any(e.startswith(rel + ':') for e in errs):
            print('      %s:%d  %s%s' % (rel, n, frag, ('  (same value as %s)' % hint) if hint else ''))
    sys.exit(1)
if not quiet: print('OK — no rule file grew a literal.')
PY
