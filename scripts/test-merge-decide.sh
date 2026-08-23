#!/usr/bin/env bash
# test-merge-decide.sh — fixture suite for the automatic merge decision engine.
#
# WHY THIS SUITE IS SHAPED THE WAY IT IS. The engine decides, on its own, whether to replace a
# project's file. What makes that safe is not the classifier — a classifier can be wrong — it
# is the pair of checks that read the composed bytes and then the written bytes and refuse or
# roll back if a single unknown-origin line went missing. A safety net nobody has watched
# catch anything is not a safety net, so this suite makes both of them catch something:
#
#   § 5a feeds the engine a corpus that LIES (declares the owner's lines to be pack text),
#        lets the classifier reach OVERRIDE on a file it must never overwrite, and asserts the
#        run refused before touching disk.
#   § 5b lies about the corpus AND stubs the pre-write check to approve, so the bad bytes
#        actually land — then asserts the post-write read-back restored the file byte-for-byte
#        from its backup.
#
# The first draft of this suite failed to fire at all, and that failure was the useful result:
# every leg of the check was derived from the same corpus the classifier used, so a corpus
# that was wrong made the decision and its own audit wrong together. The token and region legs
# exist because of that fixture.
#
# Everything runs in a temp dir. Nothing is written outside it.
#
# Usage: test-merge-decide.sh [--quiet]
# Exit:  0 all fixtures pass / 1 a fixture failed
set -uo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$REPO_ROOT/scripts/merge-decide.py"
QUIET=0
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }

pass=0; fail=0
ok()  { pass=$((pass+1)); say "  ok   $1"; return 0; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not available"; exit 0; }

TD=$(mktemp -d "${TMPDIR:-/tmp}/test-merge-decide.XXXXXX")
trap 'rm -rf "$TD"' EXIT

# ── 1. the engine's own fixture suite ────────────────────────────────────────────────────
say "merge-decide --self-test"
if out=$(python3 "$ENGINE" --self-test 2>&1); then
  ok "self-test ($(printf '%s' "$out" | grep -c '^  ok') assertions)"
else
  bad "self-test" "$(printf '%s' "$out" | tail -8)"
fi

# ── 2. a fixture project + a fixture pack ────────────────────────────────────────────────
PK="$TD/packs/fixture"
mkdir -p "$PK/commands" "$TD/proj/.claude/commands" "$TD/proj/src/services"
: > "$TD/proj/src/services/context.service.ts"
: > "$TD/proj/src/services/tenant.resolver.ts"

cat > "$PK/commands/thing.md" <<'PACK'
---
name: thing
description: Generic pack description.
---

# Thing

Generic pack preamble that the framework wrote.

## Steps

1. Do the generic first step.
2. Do the generic second step.

## Output

A generic report.
PACK

# The installed file: the pack's own text one release behind, plus a hand-written project
# section the pack knows nothing about, plus the generated anchor block.
cat > "$TD/proj/.claude/commands/thing.md" <<'TGT'
---
name: thing
description: Generic pack description.
---

# Thing

<!-- project-specific:start -->
## Project-specific (auto-generated, regenerate with `/setup-project --refine`)

> - **Data access**: DataAccess base at src/services/context.service.ts
<!-- project-specific:end -->

Generic pack preamble that the framework wrote.

## Steps

1. Do the generic first step.

## Our tenant rules

DomainMiddleware resolves tenant from the X-Product-Id header — see src/services/tenant.resolver.ts.
Do NOT short-circuit the chain.
TGT

cp -R "$TD/proj" "$TD/proj.orig"

cat > "$TD/proj/.claude/_study-existing-report.md" <<'RPT'
# Study-existing report

## fixture

### commands
  - `thing.md` — target 20 / pack 17 lines → **MERGE**

## Summary
RPT

# ── 3. the honest run — ADJUST ───────────────────────────────────────────────────────────
say ""
say "fixture: ADJUST keeps the project section and takes the pack's version elsewhere"
out=$(python3 "$ENGINE" "$TD/proj" --packs-root="$TD/packs" --apply --no-git --quiet 2>&1); rc=$?
[ $rc -eq 0 ] && ok "engine exited 0" || bad "engine exit code" "rc=$rc: $out"

R="$TD/proj/.claude/commands/thing.md"
grep -qF 'DomainMiddleware resolves tenant from the X-Product-Id header' "$R" \
  && ok "hand-written project line preserved byte-for-byte" || bad "project line preserved" "$(cat "$R")"
grep -qF 'Do NOT short-circuit the chain.' "$R" \
  && ok "second project line preserved" || bad "second project line preserved"
grep -qF '<!-- project-specific:start -->' "$R" \
  && ok "anchor block carried forward" || bad "anchor block carried forward"
grep -qF 'src/services/tenant.resolver.ts' "$R" \
  && ok "resolving project path token preserved" || bad "project path token preserved"
grep -qF 'Do the generic second step.' "$R" \
  && ok "pack depth was actually brought in" || bad "pack depth brought in"
grep -qF 'A generic report.' "$R" \
  && ok "the pack-only section was adopted" || bad "pack-only section adopted"
grep -qF 'setup-project:kept-project-section' "$R" \
  && ok "the seam is marked for a human" || bad "seam marked"

# ── 4. idempotency ───────────────────────────────────────────────────────────────────────
before=$(shasum "$R" | cut -d' ' -f1)
out2=$(python3 "$ENGINE" "$TD/proj" --packs-root="$TD/packs" --apply --no-git 2>&1)
after=$(shasum "$R" | cut -d' ' -f1)
[ "$before" = "$after" ] && ok "second run is a byte-for-byte no-op" || bad "idempotent" "$out2"
printf '%s' "$out2" | grep -q 'Files written:             0' \
  && ok "second run reports 0 files written" || bad "second run writes nothing" "$(printf '%s' "$out2" | grep 'Files written')"

# ── 5a. pre-write refusal, on a corpus that lies ─────────────────────────────────────────
say ""
say "fixture: a lied-to classifier is refused before it can write"
rm -rf "$TD/proj2"; cp -R "$TD/proj.orig" "$TD/proj2"
cp "$TD/proj/.claude/_study-existing-report.md" "$TD/proj2/.claude/_study-existing-report.md"

python3 - "$ENGINE" "$TD/packs" "$TD/proj2" > "$TD/out3.txt" 2>&1 <<'DRIVER'
import importlib.util, sys
engine, packs, proj = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("md", engine)
md = importlib.util.module_from_spec(spec); spec.loader.exec_module(md)

real = md.build_corpus
def lying_corpus(packs_root, **kw):
    c = real(packs_root, use_git=False, quiet=True)
    # The lie: every line of the installed file is declared framework-written — exactly the
    # failure a stale, truncated or over-broad corpus would produce.
    with open(proj + "/.claude/commands/thing.md", encoding="utf-8") as f:
        for ln in f:
            c.hashes.add(md.lhash(ln.rstrip("\n")))
    return c
md.build_corpus = lying_corpus
sys.exit(md.main([proj, "--packs-root=" + packs, "--apply", "--no-git"]))
DRIVER
rc3=$?; out3=$(cat "$TD/out3.txt")

# The lie makes the classifier reach OVERRIDE. The invariant catches it, and because the
# project content lives in a section the pack does not own, the engine recomposes as ADJUST
# and re-verifies from scratch rather than handing the row to a human. The check FIRING is
# the assertion; recovering from it is the improvement.
printf '%s' "$out3" | grep -q 'REFUSED by the invariant' \
  && ok "the pre-write check FIRED on a corpus that lied" || bad "pre-write check fired" "$out3"
printf '%s' "$out3" | grep -q 'recomposed as ADJUST' \
  && ok "the engine recomposed instead of writing the bad bytes" || bad "recomposed" "$out3"
grep -qF 'DomainMiddleware resolves tenant from the X-Product-Id header' "$TD/proj2/.claude/commands/thing.md" \
  && ok "the owner's line survived the lie byte-for-byte" || bad "owner line survived" "$(cat "$TD/proj2/.claude/commands/thing.md")"
grep -qF 'src/services/tenant.resolver.ts' "$TD/proj2/.claude/commands/thing.md" \
  && ok "the resolving project path survived the lie" || bad "project path survived"
grep -qF '<!-- project-specific:start -->' "$TD/proj2/.claude/commands/thing.md" \
  && ok "the anchor block survived the lie" || bad "anchor survived"

# ── 5a2. no safe recomposition exists → refuse, defer, exit 3, file untouched ────────────
# Same lie, but the project line sits INSIDE a section the pack owns, so ADJUST cannot keep
# it either. There is no safe composition, and the only correct answer is to write nothing.
say ""
say "fixture: when no safe recomposition exists the run refuses and exits 3"
rm -rf "$TD/proj2b"; cp -R "$TD/proj.orig" "$TD/proj2b"
cp "$TD/proj/.claude/_study-existing-report.md" "$TD/proj2b/.claude/_study-existing-report.md"
python3 - "$TD/proj2b/.claude/commands/thing.md" <<'MOVE'
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
# move the project knowledge OUT of its own section and INTO the pack's `## Steps`
t = t.replace("## Our tenant rules\n\n", "")
t = t.replace("1. Do the generic first step.\n",
              "1. Do the generic first step, honouring src/services/tenant.resolver.ts.\n")
open(p, "w", encoding="utf-8").write(t)
MOVE
cp "$TD/proj2b/.claude/commands/thing.md" "$TD/proj2b.before"
python3 - "$ENGINE" "$TD/packs" "$TD/proj2b" > "$TD/out3b.txt" 2>&1 <<'DRIVER'
import importlib.util, sys
engine, packs, proj = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("md", engine)
md = importlib.util.module_from_spec(spec); spec.loader.exec_module(md)
real = md.build_corpus
def lying_corpus(packs_root, **kw):
    c = real(packs_root, use_git=False, quiet=True)
    with open(proj + "/.claude/commands/thing.md", encoding="utf-8") as f:
        for ln in f:
            c.hashes.add(md.lhash(ln.rstrip("\n")))
    return c
md.build_corpus = lying_corpus
sys.exit(md.main([proj, "--packs-root=" + packs, "--apply", "--no-git"]))
DRIVER
rc3b=$?; out3b=$(cat "$TD/out3b.txt")
printf '%s' "$out3b" | grep -qi 'INVARIANT FAILED before write' \
  && ok "the pre-write check refused with no fallback available" || bad "no-fallback refusal" "$out3b"
printf '%s' "$out3b" | grep -qE 'Refused or rolled back: +1' \
  && ok "the run counts the refusal" || bad "refusal counted" "$(printf '%s' "$out3b" | grep -i refused)"
[ "$rc3b" -eq 3 ] && ok "the run exits 3 — a refusal is never reported as success" || bad "exit 3 on refusal" "rc=$rc3b"
cmp -s "$TD/proj2b.before" "$TD/proj2b/.claude/commands/thing.md" \
  && ok "the file on disk was never touched" \
  || bad "file untouched" "$(diff "$TD/proj2b.before" "$TD/proj2b/.claude/commands/thing.md" | head -8)"
printf '%s' "$out3b" | grep -q 'DEFER' && ok "the row was downgraded to DEFER" || bad "downgraded to DEFER"

# ── 5b. post-write rollback, with the pre-write check ALSO fooled ─────────────────────────
say ""
say "fixture: the post-write read-back rolls a bad write back"
rm -rf "$TD/proj5"; cp -R "$TD/proj.orig" "$TD/proj5"
cp "$TD/proj/.claude/_study-existing-report.md" "$TD/proj5/.claude/_study-existing-report.md"

python3 - "$ENGINE" "$TD/packs" "$TD/proj5" > "$TD/out5.txt" 2>&1 <<'DRIVER'
import importlib.util, sys
engine, packs, proj = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("md", engine)
md = importlib.util.module_from_spec(spec); spec.loader.exec_module(md)

real = md.build_corpus
def lying_corpus(packs_root, **kw):
    c = real(packs_root, use_git=False, quiet=True)
    with open(proj + "/.claude/commands/thing.md", encoding="utf-8") as f:
        for ln in f:
            c.hashes.add(md.lhash(ln.rstrip("\n")))
    return c
md.build_corpus = lying_corpus

real_verify = md.verify_invariant
state = {"n": 0}
def fooled_verify(*a, **kw):
    state["n"] += 1
    if state["n"] == 1:
        return True, []            # the pre-write check is fooled; the bytes reach disk
    return real_verify(*a, **kw)   # the post-write read-back is not
md.verify_invariant = fooled_verify
sys.exit(md.main([proj, "--packs-root=" + packs, "--apply", "--no-git"]))
DRIVER
rc5=$?; out5=$(cat "$TD/out5.txt")

printf '%s' "$out5" | grep -q 'ROLLED BACK' \
  && ok "the post-write read-back caught the loss" || bad "post-write read-back" "$out5"
printf '%s' "$out5" | grep -qE 'Refused or rolled back: +1' \
  && ok "the run counts the rollback" || bad "rollback counted" "$(printf '%s' "$out5" | grep -i refused)"
[ "$rc5" -eq 3 ] && ok "the run exits 3 after a rollback" || bad "exit 3 on rollback" "rc=$rc5"
cmp -s "$TD/proj.orig/.claude/commands/thing.md" "$TD/proj5/.claude/commands/thing.md" \
  && ok "the file was restored byte-for-byte from its backup" \
  || bad "restored byte-for-byte" "$(diff "$TD/proj.orig/.claude/commands/thing.md" "$TD/proj5/.claude/commands/thing.md" | head -8)"
ls "$TD/proj5"/.claude/backups/merge-decide-*/.claude/commands/thing.md >/dev/null 2>&1 \
  && ok "the backup that made the rollback possible is on disk" || bad "backup exists"

# ── 6. --conservative restores the old behaviour ─────────────────────────────────────────
say ""
say "fixture: --conservative writes nothing"
rm -rf "$TD/proj3"; cp -R "$TD/proj.orig" "$TD/proj3"
cp "$TD/proj/.claude/_study-existing-report.md" "$TD/proj3/.claude/_study-existing-report.md"
out4=$(python3 "$ENGINE" "$TD/proj3" --packs-root="$TD/packs" --apply --no-git --conservative 2>&1)
cmp -s "$TD/proj.orig/.claude/commands/thing.md" "$TD/proj3/.claude/commands/thing.md" \
  && ok "--conservative left the file untouched" || bad "--conservative is read-only on artifacts"
printf '%s' "$out4" | grep -q 'DEFER' && ok "--conservative reports the row as DEFER" || bad "--conservative defers"

# ── 7. dry-run writes nothing at all ─────────────────────────────────────────────────────
say ""
say "fixture: --dry-run writes nothing"
rm -rf "$TD/proj4"; cp -R "$TD/proj.orig" "$TD/proj4"
cp "$TD/proj/.claude/_study-existing-report.md" "$TD/proj4/.claude/_study-existing-report.md"
b4=$(find "$TD/proj4" -type f | sort | xargs shasum 2>/dev/null | shasum)
python3 "$ENGINE" "$TD/proj4" --packs-root="$TD/packs" --no-git --quiet >/dev/null 2>&1
a4=$(find "$TD/proj4" -type f | sort | xargs shasum 2>/dev/null | shasum)
[ "$b4" = "$a4" ] && ok "dry run left every byte of the target alone" || bad "dry run is read-only"

# ── 8. a degraded corpus is announced, never silent ──────────────────────────────────────
python3 "$ENGINE" "$TD/proj4" --packs-root="$TD/packs" --no-git 2>&1 | grep -q 'DEGRADED' \
  && ok "a corpus-less run announces that it is degraded" || bad "degraded run announces itself"

# ── 9. the two deploy rewrites match apply-study-decisions.sh ────────────────────────────
# Contract, ratcheted by lint-setup-contracts.sh Rule 7. A writer of pack content that skips
# the rewrite leaves a link that resolves under templates/packs/ and nowhere else, and the
# file it just wrote re-flags as MERGE on the next run forever.
mkdir -p "$PK/commands"
printf -- '---\nname: linky\n---\n\n# Linky\n\nSee [x](../../../snippets/x.md) and [y](../../../governance/y.md).\n' > "$PK/commands/linky.md"
mkdir -p "$TD/proj6/.claude/commands"
printf -- '---\nname: linky\n---\n\n# Linky\n' > "$TD/proj6/.claude/commands/linky.md"
cat > "$TD/proj6/.claude/_study-existing-report.md" <<'RPT2'
## fixture

### commands
  - `linky.md` — target 5 / pack 7 lines → **MERGE**
RPT2
python3 "$ENGINE" "$TD/proj6" --packs-root="$TD/packs" --apply --no-git --quiet >/dev/null 2>&1
if grep -q '\.\./templates/snippets/x\.md' "$TD/proj6/.claude/commands/linky.md" \
   && grep -q '\.\./templates/governance/y\.md' "$TD/proj6/.claude/commands/linky.md" \
   && ! grep -q '\.\./\.\./\.\./' "$TD/proj6/.claude/commands/linky.md"; then
  ok "snippet + governance links rewritten to the deployed shape"
else
  bad "deploy link rewrite" "$(cat "$TD/proj6/.claude/commands/linky.md")"
fi

# ── 10. an UNWRITABLE target is refused, recorded, and reported red ──────────────────────
# HISTORY: `chmod 444` on one target raised an uncaught PermissionError, apply-study-decisions.sh
# printed its summary and exited 0, and the tree was left partially rewritten with NO
# _merge-decisions.md and no ledger stamp. A green run over a half-applied merge is the one
# outcome nobody investigates.
say ""
say "fixture: an unwritable target is refused, not crashed through"
rm -rf "$TD/proj7"; cp -R "$TD/proj.orig" "$TD/proj7"
cp "$TD/proj/.claude/_study-existing-report.md" "$TD/proj7/.claude/_study-existing-report.md"
chmod 444 "$TD/proj7/.claude/commands/thing.md"
out7=$(python3 "$ENGINE" "$TD/proj7" --packs-root="$TD/packs" --apply --no-git 2>&1); rc7=$?
chmod 644 "$TD/proj7/.claude/commands/thing.md"
[ "$rc7" -eq 3 ] && ok "an unwritable target exits 3, never 0" || bad "exit 3 on unwritable target" "rc=$rc7"
printf '%s' "$out7" | grep -q 'WRITE REFUSED' \
  && ok "the refusal is named on stdout" || bad "refusal named" "$out7"
printf '%s' "$out7" | grep -qi 'Traceback' \
  && bad "engine traced back instead of refusing" "$out7" || ok "no traceback — the write is a refusable operation"
[ -f "$TD/proj7/.claude/_merge-decisions.md" ] \
  && ok "the durable record was written anyway" || bad "record written on a refused run"
grep -q 'WRITE REFUSED' "$TD/proj7/.claude/_merge-decisions.md" \
  && ok "the record names the refused row" || bad "record names the refused row"
cmp -s "$TD/proj.orig/.claude/commands/thing.md" "$TD/proj7/.claude/commands/thing.md" \
  && ok "the unwritable file is byte-identical to what it was" || bad "unwritable file untouched"

# ── 11. a mid-run crash still leaves a record and reports red ────────────────────────────
say ""
say "fixture: a crash mid-run still produces the durable record"
rm -rf "$TD/proj8"; cp -R "$TD/proj.orig" "$TD/proj8"
cp "$TD/proj/.claude/_study-existing-report.md" "$TD/proj8/.claude/_study-existing-report.md"
python3 - "$ENGINE" "$TD/packs" "$TD/proj8" > "$TD/out8.txt" 2>&1 <<'DRIVER'
import importlib.util, sys
engine, packs, proj = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("md", engine)
md = importlib.util.module_from_spec(spec); spec.loader.exec_module(md)
real = md.compose_adjust
def boom(*a, **kw):
    raise RuntimeError("simulated mid-run engine crash")
md.compose_adjust = boom
md.compose_override = boom
sys.exit(md.main([proj, "--packs-root=" + packs, "--apply", "--no-git"]))
DRIVER
rc8=$?
[ "$rc8" -eq 3 ] && ok "a mid-run crash exits 3" || bad "exit 3 on crash" "rc=$rc8 $(tail -4 "$TD/out8.txt")"
grep -q 'RUN ABORTED' "$TD/out8.txt" && ok "the abort is announced on stdout" || bad "abort announced"
[ -f "$TD/proj8/.claude/_merge-decisions.md" ] \
  && ok "the record exists after a crash" || bad "record after crash"
grep -q 'THIS RUN ABORTED' "$TD/proj8/.claude/_merge-decisions.md" \
  && ok "the record says it is incomplete" || bad "record says incomplete"

# ── 12. the ADJUST fallback ladder ───────────────────────────────────────────────────────
# A refused OVERRIDE is recomposed as ADJUST and re-verified from scratch before the row is
# handed to a human. The invariant is never relaxed to make this work.
say ""
say "fixture: a refused OVERRIDE is recomposed as ADJUST rather than deferred"
rm -rf "$TD/proj9"; mkdir -p "$TD/proj9/.claude/commands" "$TD/proj9/ai/patterns"
printf 'broker topology\n' > "$TD/proj9/ai/patterns/event-bus.md"
printf -- '---\nname: thing\n---\n\n# Thing\n\npreamble the framework wrote.\n\n## Steps\n\n1. generic first.\n2. generic second.\n' > "$PK/commands/thing2.md"
printf -- '---\nname: thing\n---\n\n# Thing\n\npreamble the framework wrote.\n\n## Steps\n\n1. generic first.\n\n## Related\n\nSee ai/patterns/event-bus.md for the broker topology.\n' > "$TD/proj9/.claude/commands/thing2.md"
cat > "$TD/proj9/.claude/_study-existing-report.md" <<'RPT9'
## fixture

### commands
  - `thing2.md` — target 13 / pack 12 lines → **MERGE**
RPT9
python3 - "$ENGINE" "$TD/packs" "$TD/proj9" > "$TD/out9.txt" 2>&1 <<'DRIVER'
import importlib.util, sys
engine, packs, proj = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("md", engine)
md = importlib.util.module_from_spec(spec); spec.loader.exec_module(md)
real = md.build_corpus
def lying_corpus(packs_root, **kw):
    # Prove EVERY line of the target — so the classifier reaches OVERRIDE and only the
    # TOKEN leg stands between the pack body and the project's own citation.
    c = real(packs_root, use_git=False, quiet=True)
    for ln in open(proj + "/.claude/commands/thing2.md", encoding="utf-8"):
        c.hashes.add(md.lhash(ln.rstrip("\n")))
    return c
md.build_corpus = lying_corpus
sys.exit(md.main([proj, "--packs-root=" + packs, "--apply", "--no-git"]))
DRIVER
rc9=$?
grep -q 'REFUSED by the invariant' "$TD/out9.txt" \
  && ok "OVERRIDE was refused on the project citation" || bad "fallback: OVERRIDE refused" "$(cat "$TD/out9.txt")"
grep -q '^\* ADJUST' "$TD/out9.txt" \
  && ok "the row was recomposed as ADJUST, not deferred" || bad "fallback: recomposed" "$(cat "$TD/out9.txt")"
grep -qF 'ai/patterns/event-bus.md' "$TD/proj9/.claude/commands/thing2.md" \
  && ok "the project citation survived" || bad "fallback: citation survived"
grep -qF 'generic second.' "$TD/proj9/.claude/commands/thing2.md" \
  && ok "the pack depth still arrived" || bad "fallback: pack depth"
[ "$rc9" -eq 0 ] && ok "the fallback closes the row (exit 0)" || bad "fallback exit 0" "rc=$rc9"

# ── 13. M41 collisions are decided by CONTENT and are order-independent ──────────────────
say ""
say "fixture: a cross-pack collision picks the pack the installed file matches"
rm -rf "$TD/proj10"; mkdir -p "$TD/proj10/.claude/commands" "$TD/packs/alpha/commands" "$TD/packs/zeta/commands"
printf -- '---\nname: dup\ndescription: ALPHA variant.\n---\n\n# Dup\n\nalpha body line one.\nalpha body line two.\n' > "$TD/packs/alpha/commands/dup.md"
printf -- '---\nname: dup\ndescription: ZETA variant.\n---\n\n# Dup\n\nzeta body line one.\nzeta body line two.\n' > "$TD/packs/zeta/commands/dup.md"
# The installed file is ZETA's, one line behind.
printf -- '---\nname: dup\ndescription: ZETA variant.\n---\n\n# Dup\n\nzeta body line one.\n' > "$TD/proj10/.claude/commands/dup.md"
cat > "$TD/proj10/.claude/_study-existing-report.md" <<'RPT10'
## alpha

### commands
  - `dup.md` — target 7 / pack 9 lines → **MERGE**

## zeta

### commands
  - `dup.md` — target 7 / pack 9 lines → **MERGE**
RPT10
# alpha is listed FIRST — first-come would hand it the file.
out10=$(python3 "$ENGINE" "$TD/proj10" --packs-root="$TD/packs" --no-git --json="$TD/c1.json" 2>&1)
w1=$(python3 -c "import json,sys;print([r['key'] for r in json.load(open(sys.argv[1])) if r['verb']!='SKIP'][0])" "$TD/c1.json")
# reversed report — zeta first
cat > "$TD/reversed-report.md" <<'RPT11'
## zeta

### commands
  - `dup.md` — target 7 / pack 9 lines → **MERGE**

## alpha

### commands
  - `dup.md` — target 7 / pack 9 lines → **MERGE**
RPT11
python3 "$ENGINE" "$TD/proj10" --packs-root="$TD/packs" --no-git --quiet --report="$TD/reversed-report.md" --json="$TD/c2.json" >/dev/null 2>&1
w2=$(python3 -c "import json,sys;print([r['key'] for r in json.load(open(sys.argv[1])) if r['verb']!='SKIP'][0])" "$TD/c2.json")
[ "$w1" = "zeta/commands/dup.md" ] \
  && ok "the winner is the pack the installed file matches, not the first listed" || bad "collision winner" "got $w1"
[ "$w1" = "$w2" ] \
  && ok "reversing the report does not change the winner" || bad "collision order-independence" "$w1 vs $w2"
printf '%s' "$out10" | grep -q 'CROSS-PACK NAME COLLISION' \
  && ok "the SKIP is NAMED on stdout, not just counted" || bad "collision SKIP named" "$out10"
python3 "$ENGINE" "$TD/proj10" --packs-root="$TD/packs" --no-git --quiet --apply >/dev/null 2>&1
grep -q 'CROSS-PACK NAME COLLISION' "$TD/proj10/.claude/_merge-decisions.md" \
  && ok "the SKIP is in the durable record" || bad "collision SKIP recorded"

# ── 13b. M36 — study-existing.sh's own alarm changes the composition ────────────────────
# The alarm is `(project-knowledge protected: … replacing it destroys knowledge no pack can
# regenerate)`. It used to be parsed into rows[]['rest'] and never read. It is read now: when
# the row would OVERRIDE and the target has a section the pack does not own, the engine
# composes ADJUST instead, which keeps that section byte-for-byte. On the two live repos the
# three M36 rows that reach OVERRIDE have NO target-only section, so the branch correctly
# declines there — which is exactly why it needs a fixture.
say ""
say "fixture: an M36 alarm downgrades OVERRIDE to ADJUST when there is something to keep"
rm -rf "$TD/proj12"; mkdir -p "$TD/proj12/.claude/commands"
printf -- '---\nname: m36\n---\n\n# M36\n\npack preamble.\n\n## Steps\n\n1. generic first.\n2. generic second.\n' > "$PK/commands/m36.md"
printf -- '---\nname: m36\n---\n\n# M36\n\npack preamble.\n\n## Steps\n\n1. generic first.\n\n## House rules\n\nkeep this paragraph.\n' > "$TD/proj12/.claude/commands/m36.md"
cat > "$TD/proj12/.claude/_study-existing-report.md" <<'RPT12'
## fixture

### commands
  - `m36.md` — target 13 / pack 12 lines → (project-knowledge protected: 1 project path(s) absent from pack — merge pack depth INTO this file; replacing it destroys knowledge no pack can regenerate) **MERGE**
RPT12
python3 - "$ENGINE" "$TD/packs" "$TD/proj12" > "$TD/out12.txt" 2>&1 <<'DRIVER'
import importlib.util, sys
engine, packs, proj = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("md", engine)
md = importlib.util.module_from_spec(spec); spec.loader.exec_module(md)
real = md.build_corpus
def lying_corpus(packs_root, **kw):
    c = real(packs_root, use_git=False, quiet=True)
    for ln in open(proj + "/.claude/commands/m36.md", encoding="utf-8"):
        c.hashes.add(md.lhash(ln.rstrip("\n")))
    return c
md.build_corpus = lying_corpus
sys.exit(md.main([proj, "--packs-root=" + packs, "--apply", "--no-git"]))
DRIVER
grep -q 'M36: study-existing.sh flagged this file' "$TD/out12.txt" \
  && ok "the M36 alarm is reported, not swallowed" || bad "M36 reported" "$(cat "$TD/out12.txt")"
grep -q 'honoured by composing ADJUST' "$TD/out12.txt" \
  && ok "the M36 alarm changed the verb to ADJUST" || bad "M36 changed the verb" "$(cat "$TD/out12.txt")"
grep -qF 'keep this paragraph.' "$TD/proj12/.claude/commands/m36.md" \
  && ok "the section the pack does not own was kept" || bad "M36 kept the section"
grep -qF 'generic second.' "$TD/proj12/.claude/commands/m36.md" \
  && ok "the pack depth still arrived" || bad "M36 pack depth"

# ── 14. the ledger is backed up before it is rewritten ───────────────────────────────────
say ""
say "fixture: the decisions ledger is backed up before the run rewrites it"
rm -rf "$TD/proj11"; cp -R "$TD/proj.orig" "$TD/proj11"
cp "$TD/proj/.claude/_study-existing-report.md" "$TD/proj11/.claude/_study-existing-report.md"
printf '# Refresh decisions ledger (M35)\n\n---\n\n- `fixture/commands/thing.md` → KEEP-OURS (2026-01-01) — hand-written rationale the owner typed\n' \
  > "$TD/proj11/.claude/_refresh-decisions.md"
cp "$TD/proj11/.claude/_refresh-decisions.md" "$TD/ledger.before"
python3 "$ENGINE" "$TD/proj11" --packs-root="$TD/packs" --apply --no-git --quiet >/dev/null 2>&1
lb=$(ls "$TD/proj11"/.claude/backups/merge-decide-*/.claude/_refresh-decisions.md 2>/dev/null | head -1)
[ -n "$lb" ] && ok "the ledger is backed up at its OWN relative path (so cp -R restores it)" || bad "ledger backed up"
[ -n "$lb" ] && cmp -s "$TD/ledger.before" "$lb" \
  && ok "the ledger backup is byte-identical to the pre-run ledger" || bad "ledger backup byte-identical"
grep -q 'hand-written rationale the owner typed' "$TD/proj11/.claude/_refresh-decisions.md" \
  && ok "the prior hand-written rationale is carried into the new line" || bad "rationale carried forward"

# ── 15. apply-study-decisions.sh — the wrapper's exit contract ───────────────────────────
# EXIT 4 MEANS NOTHING WAS WRITTEN. It used to mean "89 files were written and then a
# pre-existing skill-shape twin failed the run", which a phase runner reads as "nothing
# happened" and a `set -e` caller turns into an aborted pipeline over an already-rewritten
# repo. And a twin that blocks NO row this run would write is a warning, not a failure.
#
# The wrapper has no --packs-root, so these fixtures name REAL pack artifacts.
WRAP="$REPO_ROOT/scripts/apply-study-decisions.sh"
TWIN_SRC="$REPO_ROOT/templates/packs/code-quality/skills/change-brief/SKILL.md"
ADD_SRC="$REPO_ROOT/templates/packs/code-quality/commands/simplify.md"
if [ -f "$WRAP" ] && [ -f "$TWIN_SRC" ] && [ -f "$ADD_SRC" ]; then
  say ""
  say "fixture: apply-study-decisions.sh exit 4 means NOTHING was written"
  rm -rf "$TD/w1"; mkdir -p "$TD/w1/.claude/skills/change-brief" "$TD/w1/.claude/commands"
  printf -- '---\nname: change-brief\n---\n\ninstalled folder twin\n' > "$TD/w1/.claude/skills/change-brief/SKILL.md"
  printf -- '---\nname: change-brief\n---\n\ninstalled flat twin\n'   > "$TD/w1/.claude/skills/change-brief.md"
  cat > "$TD/w1/.claude/_study-existing-report.md" <<'RPTW'
## code-quality

### skills
  - `change-brief/SKILL.md` — target MISSING / pack 5 lines → **ADD**

### commands
  - `simplify.md` — target MISSING / pack 5 lines → **ADD**
RPTW
  outw=$(bash "$WRAP" "$TD/w1" --apply 2>&1); rcw=$?
  [ "$rcw" -eq 4 ] && ok "a twin that blocks a write exits 4" || bad "wrapper exit 4" "rc=$rcw: $outw"
  printf '%s' "$outw" | grep -q 'NOTHING HAS BEEN WRITTEN' \
    && ok "the halt says nothing was written" || bad "halt message" "$outw"
  [ ! -f "$TD/w1/.claude/commands/simplify.md" ] \
    && ok "and nothing WAS written — the unrelated ADD did not land" || bad "exit 4 wrote files anyway"

  say ""
  say "fixture: a twin that blocks no write is a WARN, and the run still succeeds"
  rm -rf "$TD/w2"; mkdir -p "$TD/w2/.claude/skills/change-brief" "$TD/w2/.claude/commands"
  printf -- '---\nname: change-brief\n---\n\ninstalled folder twin\n' > "$TD/w2/.claude/skills/change-brief/SKILL.md"
  printf -- '---\nname: change-brief\n---\n\ninstalled flat twin\n'   > "$TD/w2/.claude/skills/change-brief.md"
  cat > "$TD/w2/.claude/_study-existing-report.md" <<'RPTW2'
## code-quality

### skills
  - `change-brief/SKILL.md` — target 5 / pack 5 lines → **KEEP-OURS-DEEP**

### commands
  - `simplify.md` — target MISSING / pack 5 lines → **ADD**
RPTW2
  outw2=$(bash "$WRAP" "$TD/w2" --apply 2>&1); rcw2=$?
  [ "$rcw2" -eq 0 ] && ok "an idle twin does not fail the run" || bad "idle twin exit 0" "rc=$rcw2: $outw2"
  printf '%s' "$outw2" | grep -q 'installed in BOTH shapes' \
    && ok "the idle twin is still reported as a WARN" || bad "idle twin warned" "$outw2"
  [ -f "$TD/w2/.claude/commands/simplify.md" ] \
    && ok "the unrelated ADD landed" || bad "unrelated ADD landed" "$outw2"
  printf '%s' "$outw2" | grep -q 'ADD .*→ \.claude/commands/simplify\.md' \
    && ok "the ADD names its real destination, not basename(dir)/basename(file)" \
    || bad "ADD destination display" "$(printf '%s' "$outw2" | grep 'ADD ')"

  say ""
  say "fixture: a folder-form skill ADD prints its OWN destination, not skills/SKILL.md"
  rm -rf "$TD/w3"; mkdir -p "$TD/w3/.claude/skills" "$TD/w3/.claude/commands"
  cat > "$TD/w3/.claude/_study-existing-report.md" <<'RPTW3'
## code-quality

### skills
  - `change-brief/SKILL.md` — target MISSING / pack 5 lines → **ADD**
  - `dead-branch-scan/SKILL.md` — target MISSING / pack 5 lines → **ADD**
  - `smoke-verify/SKILL.md` — target MISSING / pack 5 lines → **ADD**
RPTW3
  outw3=$(bash "$WRAP" "$TD/w3" 2>&1)
  n_rows=$(printf '%s' "$outw3" | grep -c 'would-ADD' || true)
  n_dest=$(printf '%s' "$outw3" | grep 'would-ADD' | sed 's/.*→ //' | sort -u | grep -c . || true)
  [ "$n_rows" = "3" ] && [ "$n_dest" = "3" ] \
    && ok "3 folder-form skill ADDs print 3 DISTINCT destinations" \
    || bad "ADD display collapses destinations" "$n_rows rows, $n_dest distinct: $(printf '%s' "$outw3" | grep 'would-ADD')"
else
  say "SKIP: apply-study-decisions.sh or its fixture pack sources not found"
fi

# ── 16. audit-setup.sh C2n fails CLOSED ─────────────────────────────────────────────────
# `command -v python3` succeeding used to set C2N_LINE_MODE=1 permanently, so an engine call
# that then FAILED skipped the token fallback and emitted a warn — and `warn` does not touch
# the exit code, so the audit printed "PASS — Phase 5 audit clean. Safe to report success."
# over a loss test that never executed.
AUDIT="$REPO_ROOT/scripts/audit-setup.sh"
if [ -f "$AUDIT" ]; then
  say ""
  say "fixture: C2n errs when its own mechanism fails, and still catches the loss"
  rm -rf "$TD/c2n"; mkdir -p "$TD/c2n/.claude/commands" "$TD/c2n/src/services" \
                             "$TD/c2n/.claude/backups/merge-decide-20260823-000000/.claude/commands"
  printf 'export class DomainMiddleware {}\n' > "$TD/c2n/src/services/tenant.resolver.ts"
  printf -- '---\nname: thing\n---\n\n# Thing\n\n## Our tenant rules\n\nDomainMiddleware resolves tenant from the X-Product-Id header — see src/services/tenant.resolver.ts.\nDo NOT short-circuit the chain.\n' \
    > "$TD/c2n/.claude/backups/merge-decide-20260823-000000/.claude/commands/thing.md"
  printf -- '---\nname: thing\n---\n\n# Thing\n\n## Steps\n\n1. Do the generic first step.\n' \
    > "$TD/c2n/.claude/commands/thing.md"
  a_ok=$(bash "$AUDIT" "$TD/c2n" --read-only 2>&1 | grep -c 'ERR  KNOWLEDGE_LOSS' || true)
  [ "$a_ok" -ge 1 ] && ok "C2n ERRs on a real loss with a working python3" || bad "C2n line mode errs"
  mkdir -p "$TD/stub"; ln -sf /usr/bin/false "$TD/stub/python3"
  a_bad=$(PATH="$TD/stub:$PATH" bash "$AUDIT" "$TD/c2n" --read-only 2>&1)
  printf '%s' "$a_bad" | grep -q 'ERR  C2n: the LINE-level provenance check FAILED TO RUN' \
    && ok "a failed engine call is an ERR, not a WARN" || bad "C2n fails closed" "$(printf '%s' "$a_bad" | grep -i 'c2n' | head -3)"
  printf '%s' "$a_bad" | grep -q 'ERR  KNOWLEDGE_LOSS' \
    && ok "and the token fallback still catches the same loss" || bad "C2n token fallback ran"
else
  say "SKIP: audit-setup.sh not found"
fi

say ""
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
