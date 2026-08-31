#!/usr/bin/env bash
# retarget-probes.sh — rewrite a probe's placeholder source root to the roots this repo has.
#
# WHY. Pack artifacts ship probes written against a generic layout:
#
#     rg "SELECT .* FROM" src/modules/ --type ts | rg -v "tenant_id"
#
# `src/` there is an EXAMPLE, not a fact about the target. On a repo that does not root its
# code at src/ the command returns zero hits — and a zero-hit probe over a directory that does
# not exist is indistinguishable from a clean result. The reviewer reports "no findings" and
# has checked nothing.
#
# 📏 MEASURED on the reference monorepo, a NestJS monorepo whose top level is apps/ · libs/ · prisma/ ·
# tools/: 133 probes across its installed artifacts named a directory that does not exist, 117
# of them `src/`. audit-setup.sh C2y reports them, and nothing fixed them.
#
# The knowledge was already in the run. apply-anchors.sh computes the ranked real source roots
# and repairs the CITATION line of these very files — and stops there, one line above the
# probe that needs the same answer. This carries it down.
#
# TWO RULES, both about not making it worse:
#   1. A target that HAS a top-level src/ is left alone entirely. Nothing to retarget.
#   2. `src/` is replaced only as the FIRST segment of a path — ` src/`, `"src/`, `(src/`.
#      `libs/database/src/repository/` is a real path on that repo and must not be touched.
#
# Rewrites happen inside CODE only (fenced blocks, indented blocks, inline `…` spans), never in
# prose — the same unit of judgement C2y uses, and for the same reason: "find" is an English
# word and half these files are English.
#
# Usage: retarget-probes.sh <target-repo> [--apply] [--root=<dir>]
# Exit:  0 done (or would-do) / 1 usage
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"; unset _ss _sd

TARGET=""; APPLY=0; ROOT_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)  APPLY=1; shift ;;
    --root=*) ROOT_OVERRIDE="${1#--root=}"; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *)        TARGET="$1"; shift ;;
  esac
done
[ -n "$TARGET" ] && [ -d "$TARGET" ] || { echo "usage: $0 <target-repo> [--apply] [--root=<dir>]" >&2; exit 1; }

# RULE 1 — a repo that has src/ needs nothing.
if [ -z "$ROOT_OVERRIDE" ] && [ -d "$TARGET/src" ]; then
  echo "$TARGET has a top-level src/ — probes naming it resolve. Nothing to retarget."
  exit 0
fi

# The replacement root: the top-level dir holding the most source files. Same question
# apply-anchors.sh answers for the citation line; asked here directly so this script works
# whether or not a scan report exists.
if [ -n "$ROOT_OVERRIDE" ]; then
  NEWROOT="$ROOT_OVERRIDE"
else
  # Root detection in python, NOT a shell `case` inside `$( )` — bash 3.2 (the macOS system
  # bash this repo must run on) mis-parses a `case` pattern's `)` inside a command
  # substitution and truncates the line. Measured: "syntax error near unexpected token
  # `newline'" on the first run of this script.
  # Root detection runs as its own step writing to a temp file, NOT a heredoc inside `$( )`.
  # bash 3.2 — the macOS system bash this repo must run on — mis-parses both a `case` pattern
  # and a heredoc when either appears inside a command substitution. Measured: "unexpected EOF
  # while looking for matching `" from a python block that is perfectly well-formed.
  _rootpy="$(mktemp "${TMPDIR:-/tmp}/retarget-root.XXXXXX.py")"
  cat > "$_rootpy" <<'ROOTPY'
import os, sys
t = sys.argv[1]
SKIP = {'node_modules','dist','build','vendor','coverage','tmp','docs','assets',
        'public','logs','test-results','ai','.git'}
EXT = ('.ts','.tsx','.js','.jsx','.vue','.py','.go','.rb','.php','.java','.cs','.rs','.kt')
roots = []
for d in sorted(os.listdir(t)):
    if d.startswith('.') or d in SKIP: continue
    p = os.path.join(t, d)
    if not os.path.isdir(p): continue
    n = 0
    for root, dirs, files in os.walk(p):
        dirs[:] = [x for x in dirs if not x.startswith('.') and x not in SKIP]
        n += sum(1 for f in files if f.endswith(EXT))
        if n > 4000: break
    if n: roots.append((n, d))
# Every root holding at least 10% of the densest one. A monorepo's code does not live in one
# place: the reference monorepo is apps/ (4,317 files) AND libs/ (1,532) — replacing `src/` with apps/
# alone would point every probe away from a quarter of the codebase. rg/grep/find all accept
# several paths, so the replacement is "apps/ libs/".
roots.sort(reverse=True)
if roots:
    top = roots[0][0]
    keep = [d for n, d in roots if n * 10 >= top][:3]
    print(' '.join(k + '/' for k in keep))
ROOTPY
  NEWROOT="$(python3 "$_rootpy" "$TARGET" 2>/dev/null)"
  rm -f "$_rootpy"
fi
[ -n "$NEWROOT" ] || { echo "could not determine a source root under $TARGET — leaving probes alone (a wrong root is worse than a reported one)" >&2; exit 0; }

echo "=== retarget-probes ==="
echo "  target:  $TARGET"
echo "  src/  →  $NEWROOT"
echo ""

python3 - "$TARGET" "$NEWROOT" "$APPLY" <<'PY'
import os, re, sys
target, newroot, apply_s = sys.argv[1], sys.argv[2], sys.argv[3]
apply_ = apply_s == "1"

# 🔴 BARE `src/` ONLY — the SEARCH ROOT, never an illustrative path.
#
# Two different things wear the same prefix, and only one of them can be mechanically fixed:
#
#   rg "SELECT" src/ | rg -v tenant_id            <- a search root. 108 of these on
#                                                    the reference monorepo. Retargeting it is exact.
#   src/modules/payments/charge.service.ts        <- an EXAMPLE of what a finding looks like.
#                                                    ~125 of these. `apps/modules/payments/…`
#                                                    does not exist either, so rewriting it
#                                                    trades one dead path for another and
#                                                    makes the lie harder to spot.
#
# So the pattern requires `src/` to END the operand — followed by whitespace, a quote, a pipe,
# a backtick, `)` or end-of-line. The deep example paths are left exactly as they are and C2y
# goes on reporting them, which is right: they need a human who knows what the equivalent is.
#
# `src/` must also START its operand — never after `/` or a word character — so a real path
# like `libs/database/src/repository/data-access.ts` is untouched.
PAT = re.compile(r'(?<![\w/.-])src/(?=[\s|`"\')\]]|$)')

dirs = [os.path.join(target, '.claude', d) for d in ('commands', 'agents', 'skills', 'rules')]
files = []
for d in dirs:
    for root, _, fs in os.walk(d):
        if '/backups/' in root:
            continue
        files += [os.path.join(root, f) for f in fs if f.endswith('.md')]

changed = hits = 0
for p in sorted(files):
    try:
        lines = open(p, encoding='utf-8', errors='replace').read().split('\n')
    except OSError:
        continue
    out, fence, touched = [], False, 0
    for line in lines:
        if re.match(r'^\s*(```|~~~)', line):
            fence = not fence; out.append(line); continue
        is_code = fence or re.match(r'^(    |\t)', line)
        if is_code:
            new, n = PAT.subn(newroot, line)
        else:
            # inline `…` spans only
            def repl(m):
                inner, k = PAT.subn(newroot, m.group(1))
                return '`' + inner + '`'
            new = re.sub(r'`([^`]*)`', repl, line)
            n = 1 if new != line else 0
        if n:
            touched += 1
        out.append(new)
    if touched:
        changed += 1; hits += touched
        print("  %-58s %d line(s)" % (os.path.relpath(p, target), touched))
        if apply_:
            open(p, 'w', encoding='utf-8').write('\n'.join(out))

print("")
print("  %d file(s), %d probe line(s) retargeted" % (changed, hits))
if not apply_ and changed:
    print("  Dry run — pass --apply to write.")
PY
