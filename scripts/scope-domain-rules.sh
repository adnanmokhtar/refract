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
# A domain rule ships a broad pack-default `paths:` at source (source + config file shapes, marked
# `paths-origin: pack-default-<sha8>`); this pass REPLACES that default with the module paths. A
# `paths:` without the marker, or with globs edited since (hash mismatch), is the owner's: skipped.
#
# TWO SAFETY RULES, both refusals to scope (the rule keeps its broad default, or stays
# always-loaded when it has none):
#   1. No module matched  -> leave the rule as it is. Scoping to a path that does not exist
#      makes the rule load NEVER, which is the knowledge loss this must never cause.
#   2. Matched modules cover > SCOPE_MAX_SHARE (default 40%) of mapped modules -> leave it
#      as it is. The concept is pervasive, not local; scoping buys nothing and risks a miss.
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
    -h|--help)     sed -n '2,32p' "$0"; exit 0 ;;
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
# is the floor for guarantees) used to ship scoped to DB-migration directories while its
# extensions, migration-backend.md / migration-frontend.md, shipped with NO `paths:` — loaded in
# every session — or got scoped to the track roots where porting happens. Either way the scoping
# was inverted: during a port the extension loaded and its base did not. MEASURED on a real V2
# repo: migration-backend on `apps/api/src/**`, migration-discipline on `**/migrations/**` only —
# the rule that says a dropped unique constraint is P0 was absent from every port of a
# controller or service.
#
# At source the three now share ONE pack-default list (port artifacts + migration dirs + source
# and config shapes), so an extension cannot load where its base does not. Here, per project:
#   1. an extension still at its pack default narrows to the ported tree (`v2_root/**` from the
#      anchors, plus `ai/migration/**`);
#   2. a base still at its pack default narrows to its own directory globs + every extension
#      glob + `v2_root/**`, once anything project-specific is known (else it stays broad);
#      a base somebody scoped only ever WIDENS, by the extension globs and `v2_root/**` it lacks;
#   3. an extension with NO `paths:` beside a scoped base is reported as INVERTED, not rewritten —
#      an unscoped installed rule may be the owner's choice.
# Runs without the module map below, so it runs on every refresh. Fixture: test-rule-loading.sh § 4.
python3 - "$RULES_DIR" "$TARGET" "$APPLY" <<'PYMIG'
import hashlib, os, re, sys
rules, target, apply_ = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
base = os.path.join(rules, "migration-discipline.md")
if not os.path.isfile(base):
    sys.exit(0)
def fm(p):
    t = open(p, encoding="utf-8", errors="replace").read()
    if not t.startswith("---"):
        return ""
    end = t.find("\n---", 3)
    return t[3:end] + "\n" if end != -1 else ""
def scoped(p):
    return re.search(r"(?m)^paths:", fm(p)) is not None
def globs(p):
    m = re.search(r"(?m)^paths:[ \t]*\n((?:[ \t]+-[ \t].*\n?)+)", fm(p))
    return [g.strip().strip("\"'") for g in re.findall(r"-[ \t]*(.+)", m.group(1))] if m else []
def is_default(p):
    m = re.search(r"(?m)^paths-origin:[ \t]*pack-default-([0-9a-f]+)[ \t]*$", fm(p))
    g = globs(p)
    return bool(m and g) and hashlib.sha1(("\n".join(g) + "\n").encode()).hexdigest()[:8] == m.group(1)
def write_paths(p, new):
    lines = open(p, encoding="utf-8", errors="replace").read().split("\n")
    end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    keep, i = [], 1
    while i < end:
        if lines[i].startswith("paths:"):
            i += 1
            while i < end and (lines[i][:1] in (" ", "\t") or lines[i].lstrip().startswith("- ")):
                i += 1
            continue
        if not lines[i].startswith("paths-origin:"):
            keep.append(lines[i])
        i += 1
    block = ["paths:"] + ['  - "%s"' % g for g in new]
    open(p, "w", encoding="utf-8").write("\n".join(lines[:1] + block + keep + lines[end:]))
said = []
def say(s):
    if not said:
        print("=== migration base follows its extensions ==="); said.append(1)
    print(s)

v2 = ""
anc = os.path.join(target, "ai", "migration", "_v2-anchors.md")
if os.path.isfile(anc):
    m = re.search(r"(?m)^v2_root:[ \t]*(\S+)", open(anc, encoding="utf-8", errors="replace").read())
    if m and not m.group(1).startswith(("..", "/")):
        v2 = m.group(1).rstrip("/") + "/**"

ext_globs, ext_project = [], False
for name in ("migration-backend.md", "migration-frontend.md"):
    p = os.path.join(rules, name)
    if not os.path.isfile(p):
        continue
    if not scoped(p):
        if scoped(base):
            say("  INVERTED %s has no paths: (loads every session) while migration-discipline.md is scoped —"
                " give it migration-discipline.md's paths: block, or remove the base's" % name)
        continue
    g = globs(p)
    if is_default(p) and v2:
        g = [v2, "ai/migration/**"]
        say("  RETARGET %s  pack default -> %s" % (name, ", ".join(g)))
        if apply_:
            write_paths(p, g)
    if not is_default(p) or (v2 and not apply_):
        ext_project = True
    ext_globs += g

if not scoped(base):
    sys.exit(0)          # an unscoped base already loads everywhere
want = list(dict.fromkeys(ext_globs + ([v2] if v2 else [])))
have = globs(base)
if is_default(base):
    if not (v2 or ext_project):
        sys.exit(0)      # nothing project-specific known: the broad default already covers its extensions
    dirs = [g for g in have if not g.startswith("**/*.")]
    new = list(dict.fromkeys(dirs + want))
    say("  NARROW   migration-discipline.md  pack default -> %s" % ", ".join(new))
    if apply_:
        write_paths(base, new)
else:
    add = [g for g in want if g not in have]
    if not add:
        sys.exit(0)
    for g in add:
        say("  FOLLOW   migration-discipline.md  + %s" % g)
    if apply_:
        write_paths(base, have + add)
print("")
PYMIG

# The module map: extraction writes `| N | <repo> | <module> | \`<path>\` | <kind> | <files> |`.
MAP="$TARGET/.claude/_extracted-codebase.md"
if [ ! -f "$MAP" ]; then
  echo "no .claude/_extracted-codebase.md — no module map to scope against."
  echo "Every domain rule stays as installed — on its broad pack-default paths:, or always-loaded"
  echo "if it has none. That is the safe answer, not a failure:"
  echo "a rule scoped to a path this run cannot verify would load never."
  exit 0
fi

echo "=== scope-domain-rules ==="
echo "  target: $TARGET"
echo "  map:    ${MAP#$TARGET/}"
echo ""

python3 - "$TARGET" "$VOCAB" "$MAP" "$APPLY" "$MAX_SHARE" "$SELF_DIR" <<'PY'
import hashlib, os, re, subprocess, sys
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

def frontmatter(p):
    t = open(p, encoding='utf-8', errors='replace').read()
    if not t.startswith('---'):
        return ''
    end = t.find('\n---', 3)
    return t[3:end] + '\n' if end != -1 else ''

def is_pack_default(fm):
    """The pack's source default, unedited: `paths-origin: pack-default-<sha8>` present and
    <sha8> == sha1 over the block's globs (one per line, newline-terminated). Same contract as
    scope-rules.sh is_pack_default; an edited or owner-written block is never replaced."""
    m = re.search(r'(?m)^paths-origin:[ \t]*pack-default-([0-9a-f]+)[ \t]*$', fm)
    b = re.search(r'(?m)^paths:[ \t]*\n((?:[ \t]+-[ \t].*\n?)+)', fm)
    if not m or not b:
        return False
    globs = [g.strip().strip('"\'') for g in re.findall(r'-[ \t]*(.+)', b.group(1))]
    return hashlib.sha1(("\n".join(globs) + "\n").encode()).hexdigest()[:8] == m.group(1)

def name_tokens(n):
    return set(t for t in re.split(r'[-_.]', n.lower()) if t)

scoped = left = 0
for dom in sorted(vrows):
    rules, toks = vrows[dom]
    for rf in rules:
        path = os.path.join(target, '.claude', 'rules', rf)
        if not os.path.isfile(path):
            continue                                   # domain not installed here
        fm = frontmatter(path)
        default = is_pack_default(fm)
        if re.search(r'(?m)^paths:', fm) and not default:
            print("  skip     %-42s already scoped" % rf); continue
        # A pack-default `paths:` (the source's conservative list, marked and unedited) is
        # replaced by the module paths below; when no module matches, the default stays —
        # a broad list that loads on source/config reads, never a list that matches nothing.
        stays = "keeps its pack-default paths:" if default else "stays always-loaded"

        hits = sorted({p for n, p in mods if name_tokens(n) & toks})
        # keep the most specific path when a parent and child both matched
        hits = [p for p in hits if not any(q != p and p.startswith(q + '/') for q in hits)]

        if not hits:
            left += 1
            print("  KEEP     %-42s no module matched -> %s" % (rf, stays))
            continue
        share = 100 * len(hits) // max(1, len(mods))
        if share > max_share:
            left += 1
            print("  KEEP     %-42s spans %d%% of modules -> pervasive, %s" % (rf, share, stays))
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
            # A pack default that is still the pack default is a refusal too: the marker and
            # its matching hash survive only when scope-rules.sh did not replace the block.
            fm2 = frontmatter(path)
            if not re.search(r'(?m)^paths:', fm2) or is_pack_default(fm2):
                scoped -= 1; left += 1
                print("  FAILED   %-42s scope-rules.sh did not write the module paths: — left as it was" % rf)

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
print("  %d rule(s) scoped, %d left as they were (always-loaded, or on their pack-default paths:)" % (scoped, left))
if not apply_:
    print("")
    print("  Dry run — pass --apply to write the `paths:` frontmatter.")
    print("  Then re-run wire-rule-imports.sh --apply so CLAUDE.md drops the newly scoped rules.")
PY
