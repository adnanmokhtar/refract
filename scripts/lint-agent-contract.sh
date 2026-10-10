#!/usr/bin/env bash
# lint-agent-contract.sh — an agent's Contract block and its tool list must agree.
#
# WHY. Handoffs went through conversation: two of 126 agents declared their inputs, 78 of 91
# never said where their output goes, and eight verdict vocabularies (APPROVE / GO / READY / …)
# meant no caller could read a result without knowing which agent wrote it. And the tool lists
# lied in both directions: agents that "run the detectors" held no Skill tool (the run silently
# degrades to a grep from memory), while optimizers whose output is a ranked report held Write
# and Edit. templates/snippets/contract-block.md is the standard; this gate holds agents to it.
# It extends lint-tool-scoping.sh, which catches an advisory agent only by its name suffix.
#
# STRICT for every agent that carries a `## Contract` block (the block is a promise; a broken
# promise fails the build) and for every agent in a pack listed in REQUIRED below:
#   C1  the block is present and names `role:`, `output.writes:` and `status:`
#   C2  output.writes other than `none`  ⇒ tools has Write or Edit
#   C3  `skills:` non-empty             ⇒ tools has Skill, or the frontmatter preloads `skills:`
#   C4  role judge | proposer           ⇒ no Write, Edit, MultiEdit, NotebookEdit
#   C5  frontmatter declares `model:`
# RATCHETED across the whole roster (never forced to zero; may not grow — _agent-contract-baseline.txt):
#   missing-contract   agents with no Contract block
#   skill-no-tool      agents whose body says to run / dispatch / invoke a named skill but hold
#                      neither the Skill tool nor a `skills:` preload
#   model-missing      agents with no `model:`
#
# Usage:  lint-agent-contract.sh [--root=<dir>] [--record] [--self-test] [--list] [--quiet]
# Exit:   0 clean · 1 a strict check failed or a ratchet grew · 2 usage
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
    -h|--help)   sed -n '2,27p' "$SELF"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "ERR: python3 required" >&2; exit 2; }

# Packs whose agents must carry a Contract (Phase 3: the packs Track A has finished, plus the
# baseline). Add a pack here when its agents are migrated; never remove one.
REQUIRED="${AGENT_CONTRACT_REQUIRED:-security database performance repo-baseline delivery testing code-quality frontend observability infrastructure devops}"

if [ "$MODE" = selftest ]; then
  TD=$(mktemp -d "${TMPDIR:-/tmp}/lint-agent-contract.XXXXXX"); trap 'rm -rf "$TD"' EXIT
  A="$TD/templates/packs/security/agents"; mkdir -p "$A" "$TD/templates/packs/security/skills/secret-scan" "$TD/scripts"
  : > "$TD/templates/packs/security/skills/secret-scan/SKILL.md"
  good() { cat <<'MD'
---
name: demo-reviewer
description: d
tools: Read, Grep, Glob, Skill
model: opus
---
# Demo
## Contract
```yaml
role: judge
output:
  returns: x
  writes:   none
skills:     [secret-scan]
status:     DONE | INCOMPLETE
```
## Output
MD
  }
  p=0; f=0
  try() {  # $1=label $2=expect(0|1) — content already in $A/demo-reviewer.md
    AGENT_CONTRACT_REQUIRED=security bash "$SELF" --root="$TD" --quiet >/dev/null 2>&1; rc=$?
    if [ "$rc" = "$2" ]; then p=$((p+1)); [ "$QUIET" = 1 ] || echo "  ok   $1"; else f=$((f+1)); echo "  FAIL $1 (exit $rc, want $2)"; fi
  }
  good > "$A/demo-reviewer.md"; bash "$SELF" --root="$TD" --record --quiet >/dev/null 2>&1; try "a consistent contract passes" 0
  good | sed 's/tools: Read, Grep, Glob, Skill/tools: Read, Grep, Glob/' > "$A/demo-reviewer.md"; try "C3 skills without the Skill tool fails" 1
  good | sed 's/tools: Read, Grep, Glob, Skill/tools: Read, Grep, Glob, Skill, Edit/' > "$A/demo-reviewer.md"; try "C4 a judge holding Edit fails" 1
  good | sed 's/  writes:   none/  writes:   [ai\/x.md]/; s/role: judge/role: writer/' > "$A/demo-reviewer.md"; try "C2 a declared write without Write fails" 1
  good | sed '/^model:/d' > "$A/demo-reviewer.md"; try "C5 no model fails" 1
  good | sed '/^## Contract/,/^```$/d' | sed '/^```$/d;/^role:/d;/^output:/d;/^  returns/d;/^  writes/d;/^skills:/d;/^status:/d' > "$A/demo-reviewer.md"; try "C1 a required-pack agent with no contract fails" 1
  echo "lint-agent-contract self-test: $p passed, $f failed"
  [ "$f" -eq 0 ]; exit $?
fi

ROOT="$ROOT" MODE="$MODE" QUIET="$QUIET" REQUIRED="$REQUIRED" python3 - <<'PY'
import os, re, sys, glob
root = os.environ['ROOT']; mode = os.environ['MODE']; quiet = os.environ['QUIET'] == '1'
required = set(os.environ['REQUIRED'].split())
base_file = os.path.join(root, 'scripts', '_agent-contract-baseline.txt')
pats = ['templates/packs/*/agents/*.md', 'templates/domains/*/agents/*.md',
        'templates/repo-baseline/.claude/agents/*.md', 'templates/workspace-baseline/.claude/agents/*.md']
agents = sorted(set(p for g in pats for p in glob.glob(os.path.join(root, g))))
skills = {os.path.basename(os.path.dirname(p)) for p in glob.glob(os.path.join(root, 'templates/packs/*/skills/*/SKILL.md'))}
skills |= {os.path.basename(os.path.dirname(p)) for p in glob.glob(os.path.join(root, 'templates/repo-baseline/.claude/skills/*/SKILL.md'))}
WRITING = {'Write', 'Edit', 'MultiEdit', 'NotebookEdit'}
RUN = re.compile(r'\b(run|runs|dispatch|dispatches|invoke|invokes|load|loads)\b[^.\n]{0,40}`(' + '|'.join(map(re.escape, sorted(skills))) + r')`(?:\s+\*{0,2}skill)?', re.I) if skills else None

def pack_of(rel):
    m = re.match(r'templates/packs/([^/]+)/', rel)
    if m: return m.group(1)
    if rel.startswith('templates/repo-baseline/'): return 'repo-baseline'
    if rel.startswith('templates/workspace-baseline/'): return 'workspace-baseline'
    m = re.match(r'templates/domains/([^/]+)/', rel)
    return 'domain:' + m.group(1) if m else '?'

def frontmatter(text):
    if not text.startswith('---'): return {}
    end = text.find('\n---', 3)
    fm = {}
    for l in text[3:end].splitlines():
        m = re.match(r'^([A-Za-z_-]+):\s*(.*)$', l)
        if m: fm[m.group(1)] = m.group(2).strip()
    return fm

def contract(text):
    m = re.search(r'(?m)^## Contract\b.*?\n```ya?ml\n(.*?)\n```', text, re.S)
    if not m: return None
    c = {}
    for l in m.group(1).splitlines():
        mm = re.match(r'^(\s*)([A-Za-z_]+):\s*(.*?)\s*(#.*)?$', l)
        if not mm: continue
        key = mm.group(2) if not mm.group(1) else 'output.' + mm.group(2) if mm.group(2) in ('writes', 'returns', 'persisted_by') else None
        if key: c[key] = mm.group(3)
    return c

def listval(v):
    v = (v or '').strip()
    if v in ('', '[]', 'none', 'None'): return []
    return [x.strip() for x in v.strip('[]').split(',') if x.strip()]

strict_errs = []; missing = []; skill_no_tool = []; model_missing = []
for p in agents:
    rel = os.path.relpath(p, root); text = open(p, encoding='utf-8', errors='replace').read()
    fm = frontmatter(text); tools = {t.strip() for t in fm.get('tools', '').strip('[]').split(',') if t.strip()}
    has_skill = 'Skill' in tools or bool(fm.get('skills'))
    c = contract(text); pk = pack_of(rel)
    if not fm.get('model'): model_missing.append(rel)
    if c is None:
        missing.append(rel)
        if pk in required: strict_errs.append('%s: C1 no `## Contract` block (pack %s is required to carry one — templates/snippets/contract-block.md)' % (rel, pk))
        if RUN and not has_skill and RUN.search(text): skill_no_tool.append(rel)
        continue
    for k in ('role', 'output.writes', 'status'):
        if k not in c: strict_errs.append('%s: C1 Contract has no `%s:`' % (rel, k))
    writes = listval(c.get('output.writes'))
    if writes and not (tools & {'Write', 'Edit'}):
        strict_errs.append('%s: C2 declares writes %s but tools has neither Write nor Edit' % (rel, writes))
    sk = listval(c.get('skills'))
    if sk and not has_skill:
        strict_errs.append('%s: C3 runs skills %s but holds no Skill tool and preloads none' % (rel, sk))
    unknown = [s for s in sk if s not in skills]
    if unknown: strict_errs.append('%s: C3 Contract names skills that do not exist: %s' % (rel, unknown))
    role = c.get('role', '').split()[0] if c.get('role') else ''
    if role in ('judge', 'proposer') and tools & WRITING:
        strict_errs.append('%s: C4 role %s holds %s' % (rel, role, sorted(tools & WRITING)))
    if role in ('judge', 'proposer') and writes:
        strict_errs.append('%s: C4 role %s declares writes %s' % (rel, role, writes))
    if role and role not in ('judge', 'proposer', 'writer'):
        strict_errs.append('%s: C1 unknown role %r (judge | proposer | writer)' % (rel, role))
    if not fm.get('model'): strict_errs.append('%s: C5 no `model:` in frontmatter' % rel)

counts = {'missing-contract': len(missing), 'skill-no-tool': len(skill_no_tool), 'model-missing': len(model_missing)}
if mode == 'list':
    for k, lst in (('missing-contract', missing), ('skill-no-tool', skill_no_tool), ('model-missing', model_missing)):
        print('== %s (%d)' % (k, len(lst)))
        for r in lst: print('  ' + r)
    sys.exit(0)
if mode == 'record':
    with open(base_file, 'w') as fh:
        fh.write('# Roster-wide agent-contract debt counted by scripts/lint-agent-contract.sh. May only shrink.\n')
        for k in ('missing-contract', 'skill-no-tool', 'model-missing'): fh.write('%s %d\n' % (k, counts[k]))
    if not quiet: print('recorded %s → %s' % (counts, base_file))
    sys.exit(0)
rec = {}
if os.path.isfile(base_file):
    for l in open(base_file):
        if l.startswith('#') or not l.strip(): continue
        k, v = l.split(); rec[k] = int(v)
ratchet = []
for k, v in counts.items():
    if k in rec and v > rec[k]: ratchet.append('%s grew: %d (recorded %d) — run --list to see which agent' % (k, v, rec[k]))
    if k not in rec and v > 0 and rec: ratchet.append('%s: %d, not recorded' % (k, v))
with_contract = len(agents) - len(missing)
if not quiet:
    print('Agent contracts — %d agents, %d with a Contract block; debt: %d missing, %d skill-without-tool, %d no model (recorded %s)' %
          (len(agents), with_contract, counts['missing-contract'], counts['skill-no-tool'], counts['model-missing'],
           ', '.join('%s %d' % (k, rec[k]) for k in sorted(rec)) or 'none'))
errs = strict_errs + ratchet
for e in errs: print('  ✗ ' + e)
if errs: sys.exit(1)
if not quiet: print('OK — every Contract agrees with its tools; no debt grew.')
PY
