#!/usr/bin/env bash
# scope-domain-rules.sh — scope each installed DOMAIN rule to the modules that domain actually
# occupies, using the module map extraction already recorded. Phase 4.2 runs this.
#
# WHY. A domain rule is scoped by definition: `payment-idempotency` matters in payment code and
# nowhere else. Measured 2026-08-24: 0 of 35 domain rules and 0 of 28 pack rules carried `paths:`,
# so ~156,738 tok of rules loaded on EVERY turn regardless of what was being edited. On
# the reference monorepo that was ~11,576 tok/turn, of which 3,681 were domain rules irrelevant to most edits.
#
# Phase 4.2 already scoped PACK rules — but only when `is_multi_track: true`, and it never touched
# domain rules at all. So on a single-track project nothing was scoped, and domain rules were
# scoped nowhere, ever.
#
# WHY NOT A GLOB GUESSED FROM THE DOMAIN NAME. Tried and measured against the reference monorepo's 6,187
# source files: `**/*ai*` matched 257 files because `account/domain/**` contains "ai", and
# `**/*tenant*` matched 3,193 (52%) because the app IS multi-tenant. A substring is not a word,
# and a template cannot know a project's layout. The module map does: matching hyphen-split TOKENS
# against recorded module names hits `ai-provider-settings` and not `domain`.
#
# TWO SAFETY RULES, both refusals to scope:
#   1. No module matched  -> leave the rule ALWAYS-LOADED. Scoping to a path that does not exist
#      makes the rule load NEVER, which is the knowledge loss this must never cause.
#   2. Matched modules cover > SCOPE_MAX_SHARE (default 40%) of mapped modules -> leave it
#      always-loaded. The concept is pervasive, not local; scoping buys nothing and risks a miss.
#
# Usage: scope-domain-rules.sh <target-repo> [--apply] [--max-share=N]
# Exit:  0 done (or would-do) / 1 usage or missing inputs
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"
REPO_ROOT="$(cd -P "$SELF_DIR/.." && pwd)"; unset _ss _sd

TARGET=""; APPLY=0; MAX_SHARE="${SCOPE_MAX_SHARE:-40}"
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)       APPLY=1; shift ;;
    --max-share=*) MAX_SHARE="${1#--max-share=}"; shift ;;
    -h|--help)     sed -n '2,28p' "$0"; exit 0 ;;
    *)             TARGET="$1"; shift ;;
  esac
done
[ -n "$TARGET" ] && [ -d "$TARGET" ] || { echo "usage: $0 <target-repo> [--apply] [--max-share=N]" >&2; exit 1; }

VOCAB="${SCOPE_VOCAB:-$REPO_ROOT/templates/domains/_scope-vocabulary.md}"
[ -f "$VOCAB" ] || { echo "ERR: scope vocabulary not found at $VOCAB" >&2; exit 1; }

RULES_DIR="$TARGET/.claude/rules"
[ -d "$RULES_DIR" ] || { echo "no .claude/rules/ in $TARGET — nothing to scope"; exit 0; }

# ── The migration base follows the rules that extend it ─────────────────────────────────────
# migration-discipline.md (the core philosophy: V1 is the contract for behaviour, the baseline
# is the floor for guarantees) ships scoped to DB-migration directories. Its extensions,
# migration-backend.md / migration-frontend.md, get scoped to the track roots where porting
# happens. So during a port the extension loaded and its base did not. MEASURED on a real V2
# repo: migration-backend on `apps/api/src/**`, migration-discipline on `**/migrations/**` only —
# the rule that says a dropped unique constraint is P0 was absent from every port of a
# controller or service. The base gets the union of its extensions' globs plus the anchors'
# v2_root. Runs without the module map below, so it runs on every refresh.
python3 - "$RULES_DIR" "$TARGET" "$APPLY" <<'PYMIG'
import os, re, sys
rules, target, apply_ = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
base = os.path.join(rules, "migration-discipline.md")
if not os.path.isfile(base):
    sys.exit(0)
def fm_and_body(p):
    t = open(p, encoding="utf-8", errors="replace").read()
    if not t.startswith("---"):
        return None, t
    end = t.find("\n---", 3)
    return (t[:end], t[end:]) if end != -1 else (None, t)
def globs(p):
    fm, _ = fm_and_body(p)
    if not fm:
        return []
    m = re.search(r"(?m)^paths:[ \t]*\n((?:[ \t]+-[ \t].*\n?)+)", fm + "\n")
    return [g.strip().strip("\"'") for g in re.findall(r"-[ \t]*(.+)", m.group(1))] if m else []
want = []
for ext in ("migration-backend.md", "migration-frontend.md"):
    p = os.path.join(rules, ext)
    if os.path.isfile(p):
        want += globs(p)
anc = os.path.join(target, "ai", "migration", "_v2-anchors.md")
if os.path.isfile(anc):
    m = re.search(r"(?m)^v2_root:[ \t]*(\S+)", open(anc, encoding="utf-8", errors="replace").read())
    if m and not m.group(1).startswith(("..", "/")):
        want.append(m.group(1).rstrip("/") + "/**")
have = globs(base)
add = [g for g in dict.fromkeys(want) if g not in have]
if not have or not add:
    sys.exit(0)          # unscoped base already loads everywhere; or nothing new to add
print("=== migration base follows its extensions ===")
for g in add:
    print("  FOLLOW   migration-discipline.md  + %s" % g)
if apply_:
    fm, body = fm_and_body(base)
    m = re.search(r"(?m)^paths:[ \t]*\n((?:[ \t]+-[ \t].*\n?)+)", fm + "\n")
    block = m.group(1).rstrip("\n")
    newblock = block + "".join('\n  - "%s"' % g for g in add)
    open(base, "w", encoding="utf-8").write(fm.replace(block, newblock, 1) + body)
print("")
PYMIG

# The module map: extraction writes `| N | <repo> | <module> | \`<path>\` | <kind> | <files> |`.
MAP="$TARGET/.claude/_extracted-codebase.md"
if [ ! -f "$MAP" ]; then
  echo "no .claude/_extracted-codebase.md — no module map to scope against."
  echo "Every domain rule stays always-loaded. That is the safe answer, not a failure:"
  echo "a rule scoped to a path this run cannot verify would load never."
  exit 0
fi

echo "=== scope-domain-rules ==="
echo "  target: $TARGET"
echo "  map:    ${MAP#$TARGET/}"
echo ""

python3 - "$TARGET" "$VOCAB" "$MAP" "$APPLY" "$MAX_SHARE" "$SELF_DIR" <<'PY'
import os, re, subprocess, sys
target, vocab, mapfile, apply_s, max_share_s, self_dir = sys.argv[1:7]
apply_ = apply_s == "1"; max_share = int(max_share_s)

# ── module map ───────────────────────────────────────────────────────────────
mods = []
for m in re.finditer(r'^\|\s*\d+\s*\|\s*[^|]+\|\s*([A-Za-z0-9._-]+)\s*\|\s*`([^`]+)`\s*\|',
                     open(mapfile, encoding='utf-8', errors='replace').read(), re.M):
    mods.append((m.group(1), m.group(2)))
if not mods:
    print("  module map present but no rows parsed — every domain rule stays always-loaded.")
    sys.exit(0)
print("  modules mapped: %d" % len(mods))

# ── vocabulary ───────────────────────────────────────────────────────────────
vrows = {}
for line in open(vocab, encoding='utf-8', errors='replace'):
    m = re.match(r'^\|\s*([a-z0-9-]+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*$', line)
    if not m or m.group(1) == 'domain':
        continue
    rules = [r.strip() for r in m.group(2).split(',') if r.strip()]
    toks  = {t.strip() for t in m.group(3).split(',') if t.strip()}
    if rules and toks:
        vrows[m.group(1)] = (rules, toks)
print("  domains in vocabulary: %d" % len(vrows))
print("")

def name_tokens(n):
    return set(t for t in re.split(r'[-_.]', n.lower()) if t)

scoped = left = 0
for dom in sorted(vrows):
    rules, toks = vrows[dom]
    for rf in rules:
        path = os.path.join(target, '.claude', 'rules', rf)
        if not os.path.isfile(path):
            continue                                   # domain not installed here
        head = open(path, encoding='utf-8', errors='replace').read(400)
        if re.search(r'(?m)^paths:', head):
            print("  skip     %-42s already scoped" % rf); continue

        hits = sorted({p for n, p in mods if name_tokens(n) & toks})
        # keep the most specific path when a parent and child both matched
        hits = [p for p in hits if not any(q != p and p.startswith(q + '/') for q in hits)]

        if not hits:
            left += 1
            print("  KEEP     %-42s no module matched -> stays always-loaded" % rf)
            continue
        share = 100 * len(hits) // max(1, len(mods))
        if share > max_share:
            left += 1
            print("  KEEP     %-42s spans %d%% of modules -> pervasive, stays always-loaded" % (rf, share))
            continue

        globs = ",".join(p.rstrip('/') + "/**" for p in hits)
        print("  SCOPE    %-42s -> %s" % (rf, ", ".join(hits)[:60]))
        scoped += 1
        if apply_:
            subprocess.run(["bash", os.path.join(self_dir, "scope-rules.sh"),
                            os.path.join('.claude', 'rules', rf), globs],
                           cwd=target, capture_output=True)
            # 🔴 VERIFY THE WRITE. This used to report SCOPE on the strength of having CALLED
            # scope-rules.sh. That script exits 0 after refusing a file (it returned 0 for
            # "no frontmatter"), so a refusal was indistinguishable from a success — and on
            # the reference monorepo this printed `SCOPE ai-cost-discipline.md` over a file it had not
            # touched. wire-rule-imports.sh then correctly re-imported it as always-loaded,
            # and the reported saving never happened.
            after = open(path, encoding='utf-8', errors='replace').read(4000)
            fm = after.split('\n---', 1)[0] if after.startswith('---') else ''
            if not re.search(r'(?m)^(paths|globs):', fm):
                scoped -= 1; left += 1
                print("  FAILED   %-42s scope-rules.sh did not write paths: — left always-loaded" % rf)

# ── PASS 2 — retired (2026-09-28) ─────────────────────────────────────────────
#
# This pass gave `paths:` to every rule that was neither imported by CLAUDE.md nor scoped, on
# the premise that such a rule "reaches Claude on no turn". The premise was false: Claude Code
# loads every rule without `paths:` at launch, imported or not (measured with canary rules on
# 2.1.236 — see the header of wire-rule-imports.sh). So the pass did the opposite of its intent:
# it took principle rules that were in context every session — backend-principles,
# concurrency-discipline, security-principles on the measured repo — and made them load only
# once Claude happened to read a file under a module root. A rule with no `paths:` HAS a route.
# Pass 1 above is unaffected: scoping a domain rule to the modules it governs is a real saving.

print("")
print("  %d rule(s) scoped, %d left always-loaded" % (scoped, left))
if not apply_:
    print("")
    print("  Dry run — pass --apply to write the `paths:` frontmatter.")
    print("  Then re-run wire-rule-imports.sh --apply so CLAUDE.md drops the newly scoped rules.")
PY
