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

# ── PASS 2 — rules with NO ROUTE AT ALL ──────────────────────────────────────
#
# 🔴 A RULE THAT IS NEITHER IMPORTED NOR SCOPED REACHES CLAUDE ON NO TURN.
#
# There are exactly two ways a rule is delivered: its name in CLAUDE.md (charged every
# message, capped by the always-loaded budget) or a `paths:`/`globs:` declaration (injected
# when a matching file is touched, charged once per session). A rule that has neither is
# installed, correct, and unreachable.
#
# 📏 MEASURED on the reference monorepo: 14 of 36 installed rules were in that state — 34,773 tok
# including backend-principles (3,368), concurrency-discipline (3,240) and
# security-principles (2,763) — on a backend project. wire-rule-imports.sh had recorded them
# honestly in `.claude/rules/_unloaded.md` and printed the remedy, and the remedy was
# `scope-rules.sh`, which could not write a form the hook could read until it was fixed. So
# the refusal was recorded, the fix was named, and the fix did not work.
#
# Phase 4.2 was supposed to prevent this and could not: it scopes rules only when the profile
# says `is_multi_track: true`, and that repo's profile contains no such key — nor
# `repo_shape`, nor `track_roots`. The phase's own text says an absent key must HALT rather
# than default to false. It did not halt; it skipped the step in silence.
#
# So this pass asks the only question that matters — CAN THIS RULE ARRIVE? — and gives a
# route to any rule that has none, scoped to the source roots the extraction recorded. Broad
# is correct here: the alternative on offer is not "narrower", it is "never".
imported = set()
cl = os.path.join(target, 'CLAUDE.md')
if os.path.isfile(cl):
    imported = set(re.findall(r'^@\.claude/rules/([A-Za-z0-9._-]+\.md)',
                              open(cl, encoding='utf-8', errors='replace').read(), re.M))

roots = sorted({p for n, p in mods if p.count('/') <= 2})
roots = [r for r in roots if not any(q != r and r.startswith(q + '/') for q in roots)]
if imported and roots:
    print("")
    print("  pass 2 — rules with no route (not imported, not scoped)")
    stranded = 0
    for f in sorted(os.listdir(os.path.join(target, '.claude', 'rules'))):
        if not f.endswith('.md') or f == 'README.md' or f.startswith('_'):
            continue
        if f in imported:
            continue
        fp = os.path.join(target, '.claude', 'rules', f)
        txt = open(fp, encoding='utf-8', errors='replace').read()
        fm = txt.split('\n---', 1)[0] if txt.startswith('---') else ''
        if re.search(r'(?m)^(paths|globs):', fm):
            continue                                    # already has a route
        stranded += 1
        globs = ",".join(r.rstrip('/') + "/**" for r in roots)
        print("  ROUTE    %-42s -> %s" % (f, ", ".join(roots)[:52]))
        if apply_:
            subprocess.run(["bash", os.path.join(self_dir, "scope-rules.sh"),
                            os.path.join('.claude', 'rules', f), globs],
                           cwd=target, capture_output=True)
            after = open(fp, encoding='utf-8', errors='replace').read(4000)
            fm2 = after.split('\n---', 1)[0] if after.startswith('---') else ''
            if not re.search(r'(?m)^(paths|globs):', fm2):
                print("  FAILED   %-42s could not write paths: — still unreachable" % f)
    if stranded == 0:
        print("  none — every installed rule is either imported or scoped")
    else:
        print("  %d rule(s) given a route" % stranded)

print("")
print("  %d rule(s) scoped, %d left always-loaded" % (scoped, left))
if not apply_:
    print("")
    print("  Dry run — pass --apply to write the `paths:` frontmatter.")
    print("  Then re-run wire-rule-imports.sh --apply so CLAUDE.md drops the newly scoped rules.")
PY
