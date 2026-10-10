#!/usr/bin/env bash
# lint-rg-traps.sh — a prescribed file-level search must mean what its author meant.
#
# WHY. Four shapes parse, run, exit 0 and answer a different question, so lint-rg-parses.sh
# (does it parse?) and lint-rg-explicit-path.sh (does it name a path?) both pass them:
#   rg-follow           `rg … -L <pattern>` — in ripgrep `-L` is --follow (follow symlinks), not
#                       grep's files-without-match. The "files missing X" check prints the files
#                       that HAVE X. Measured in batch 3: an `rg -L` printed the matches of a file
#                       that does remove its listener; an old ssr-audit told agents to use
#                       `grep -L`, agents translated it to `rg -L`, and two research passes were bitten.
#   rg-files-pattern    `rg -l "<pat>" --files` / `rg "<pat>" … --files` — with --files ripgrep
#                       searches nothing and treats every positional as a PATH, so the pattern is
#                       a directory that does not exist and the list is empty or the whole tree.
#   grep-l-bre-pipe     `grep -L 'a|b'` / `grep -l …` with no -E/-P — basic regex reads `|` as a
#                       literal pipe, so no file contains it and -L lists every file.
#   table-cell-pipe     a runnable `rg …` in a markdown table cell carrying `\|` — the escape the
#                       table needs reaches ripgrep verbatim as a LITERAL pipe; the alternation the
#                       rendered page shows is not the one a model copying the source runs.
#
# Scope: templates/**/*.md and commands/*.md — fenced lines and inline code spans. A span that only
# NAMES the trap (`rg -L` with no pattern, in prose warning against it) is a mention, not a search.
# Existing hits live in scripts/_rg-traps-baseline.txt (file<TAB>kind<TAB>count): a file may not
# GROW a kind, a NEW file may not carry one, and a fixed file must shrink its row (--record).
#
# Usage:  lint-rg-traps.sh [--repo-root=<dir>] [--record] [--list] [--self-test]
# Exit:   0 clean · 1 a trap grew or appeared · 2 usage
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
MODE=check
for a in "$@"; do
  case "$a" in
    --repo-root=*) REPO_ROOT="${a#*=}" ;;
    --record)      MODE=record ;;
    --list)        MODE=list ;;
    --self-test)   MODE=selftest ;;
    -h|--help)     sed -n '2,27p' "$SELF"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "ERR: python3 required" >&2; exit 2; }

if [ "$MODE" = selftest ]; then
  TD=$(mktemp -d "${TMPDIR:-/tmp}/lint-rg-traps.XXXXXX"); trap 'rm -rf "$TD"' EXIT
  mkdir -p "$TD/templates/x" "$TD/commands" "$TD/scripts"
  : > "$TD/scripts/_rg-traps-baseline.txt"
  ( cd "$TD" && git init -q . )
  p=0; f=0
  try() {  # $1 label $2 expected exit $3 content
    printf '%s\n' "$3" > "$TD/templates/x/a.md"
    bash "$SELF" --repo-root="$TD" >/dev/null 2>&1; rc=$?
    if [ "$rc" = "$2" ]; then p=$((p+1)); else f=$((f+1)); echo "FAIL self-test: $1 (exit $rc, want $2)"; fi
  }
  try "rg -L with a pattern"         1 $'```bash\nrg -L \'removeEventListener\' src/\n```'
  try "rg -l pat --files"            1 $'```\nrg -l "foo.+bar" --files src/\n```'
  try "rg pattern src --files"       1 'Run `rg "templates/.+\.html" src/ --files | xargs grep -l x`.'
  try "grep -L with a BRE pipe"      1 $'```\ngrep -L \'useState|useEffect\' src/*.tsx\n```'
  try "rg in a table cell with \\|" 1 $'| A | `rg -n \'foo\\|bar\' src/` |\n|---|---|'
  try "a mention of rg -L"           0 'Never use `rg -L` (it is `--follow`).'
  try "rg --files-without-match"     0 $'```\nrg -l \'a\' . | xargs -r rg --files-without-match \'b\'\n```'
  try "rg --files with globs"        0 $'```\nrg --files -g \'*.map\' "${ROOTS[@]}" | rg \'\\.map$\'\n```'
  try "grep -LE alternation"         0 $'```\ngrep -LE \'a|b\' src/*.ts\n```'
  try "grep -L with a GNU \\|"       0 $'```\ngrep -L \'a\\|b\' src/*.ts\n```'
  try "a table cell with no rg"      0 $'| A | `a \\| b` |\n|---|---|'
  echo "lint-rg-traps self-test: $p passed, $f failed"
  [ "$f" -eq 0 ]; exit $?
fi

cd "$REPO_ROOT" || exit 2
BASE="scripts/_rg-traps-baseline.txt"
git ls-files -z --cached --others --exclude-standard 'templates/*.md' 'templates/**/*.md' 'commands/*.md' \
  | MODE="$MODE" BASE="$BASE" python3 -c '
import os, re, shlex, sys
mode, base = os.environ["MODE"], os.environ["BASE"]
SEP = {"|", "||", "&&", ";", "&", "(", ")", "|&", "$(", "`"}
RG_VAL = {"-g", "--glob", "--iglob", "-t", "--type", "-T", "--type-not", "-e", "--regexp", "-f", "--file",
          "-m", "--max-count", "-A", "-B", "-C", "--max-depth", "-j", "--threads", "-M", "--max-columns",
          "--type-add", "-r", "--replace", "-E", "--encoding", "--sort", "--sortr", "--color", "--colors",
          "--max-filesize", "--path-separator", "--pre", "--pre-glob", "--engine", "--ignore-file"}
GREP_VAL = {"-e", "-f", "-m", "-A", "-B", "-C", "--include", "--exclude", "--exclude-dir", "-d", "-D"}
REGEXY = re.compile(r"\\\\|[\^+(){}|\[\]]|\.\*|\.\+")

def segments(cmd):
    cmd = cmd.replace("`", " ; ")
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars="|&;()")
        lex.whitespace_split = True
        toks = list(lex)
    except ValueError:
        return []
    out, cur = [], None
    for t in toks:
        if t in SEP or set(t) <= set("|&;()"):
            if cur: out.append(cur)
            cur = None
            continue
        base_t = t.rsplit("/", 1)[-1]
        if base_t in ("rg", "grep", "egrep") and cur is None:
            cur = [base_t]
        elif base_t in ("rg", "grep", "egrep"):
            out.append(cur); cur = [base_t]
        elif cur is not None:
            cur.append(t)
    if cur: out.append(cur)
    return out

def classify_rg(args):
    kinds, pos, follow, files, listy = [], [], False, False, False
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--":
            pos += args[i + 1:]; break
        if a.startswith("--"):
            name = a.split("=", 1)[0]
            if name == "--follow": follow = True
            if name == "--files": files = True
            if name in ("--files-with-matches", "--files-without-match", "--regexp"): listy = True
            if "=" not in a and name in RG_VAL: i += 1
        elif a.startswith("-") and len(a) > 1:
            letters = a[1:]
            if "L" in letters: follow = True
            if "l" in letters or "e" in letters: listy = True
            if letters[-1:] and ("-" + letters[-1]) in RG_VAL: i += 1
        else:
            pos.append(a)
        i += 1
    real = [p for p in pos if not p.startswith("$")]
    if follow and pos and not files:
        kinds.append("rg-follow")
    if files and (listy or any(REGEXY.search(p) for p in real)):
        kinds.append("rg-files-pattern")
    return kinds

def classify_grep(cmd, args):
    ere = cmd == "egrep"
    lflag, pat, i = False, None, 0
    while i < len(args):
        a = args[i]
        if a in ("--extended-regexp", "--perl-regexp", "--fixed-strings"): ere = True
        elif a in ("--files-without-match", "--files-with-matches"): lflag = True
        elif a.startswith("--"): pass
        elif a.startswith("-") and len(a) > 1:
            letters = a[1:]
            if set(letters) & set("EPF"): ere = True
            if set(letters) & set("lL"): lflag = True
            if letters[-1] == "e" and i + 1 < len(args): pat = args[i + 1]; i += 1
            elif ("-" + letters[-1]) in GREP_VAL: i += 1
        elif pat is None:
            pat = a
        i += 1
    if lflag and not ere and pat and re.search(r"(?<!\\)\|", pat):
        return ["grep-l-bre-pipe"]
    return []

def scan(text):
    hits = []
    fence = False
    for n, line in enumerate(text.split("\n"), 1):
        s = line.strip()
        if s.startswith("```") or s.startswith("~~~"):
            fence = not fence
            continue
        spans = re.findall(r"`([^`]+)`", line)
        cands = [re.sub(r"^\$\s+", "", s)] if fence else spans
        if s.startswith("|"):
            for sp in spans:
                if re.match(r"\s*rg\s", sp) and "\\|" in sp:
                    hits.append((n, "table-cell-pipe"))
        for c in cands:
            if not re.search(r"(^|[\s|;&(/`])(rg|e?grep)\s", c):
                continue
            for seg in segments(c):
                ks = classify_rg(seg[1:]) if seg[0] == "rg" else classify_grep(seg[0], seg[1:])
                hits += [(n, k) for k in ks]
    return hits

found = {}
detail = []
for path in sorted(p for p in sys.stdin.read().split("\0") if p):
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for n, k in scan(text):
        found[(path, k)] = found.get((path, k), 0) + 1
        detail.append("%s:%d %s" % (path, n, k))

if mode == "list":
    print("\n".join(detail)); sys.exit(0)
if mode == "record":
    with open(base, "w") as fh:
        fh.write("# Prescribed-search traps counted by scripts/lint-rg-traps.sh, per file and kind. May only shrink.\n")
        fh.write("# Regenerate: bash scripts/lint-rg-traps.sh --record   (after fixing a file, never to admit a new one)\n")
        for (p, k), c in sorted(found.items()):
            fh.write("%s\t%s\t%d\n" % (p, k, c))
    print("recorded %d file/kind row(s) to %s" % (len(found), base)); sys.exit(0)
rec = {}
if os.path.isfile(base):
    for l in open(base, encoding="utf-8"):
        if l.startswith("#") or not l.strip(): continue
        p, k, c = l.rstrip("\n").split("\t")
        rec[(p, k)] = int(c)
bad = []
for key, c in sorted(found.items()):
    if c > rec.get(key, 0):
        lines = [d for d in detail if d.startswith(key[0] + ":") and d.endswith(" " + key[1])]
        bad.append("  %s %s: %d (recorded %d) — %s" % (key[0], key[1], c, rec.get(key, 0), ", ".join(x.split(" ")[0].rsplit(":", 1)[1] for x in lines)))
stale = [k for k in rec if found.get(k, 0) < rec[k]]
total = sum(found.values())
print("rg traps — %d hit(s) in %d file/kind row(s) (recorded %d)" % (total, len(found), sum(rec.values())))
if bad:
    print("FAIL — a prescribed search that answers a different question:")
    print("\n".join(bad))
    print("  fix: files-without-match is `--files-without-match` (never rg -L); --files takes paths and -g globs,")
    print("       never a pattern; grep alternation needs -E; a runnable rg goes in a fenced block, not a table cell.")
    sys.exit(1)
if stale:
    print("FAIL — fixed, but the baseline still admits them (re-record so they cannot come back):")
    print("\n".join("  %s %s: recorded %d, now %d" % (k[0], k[1], rec[k], found.get(k, 0)) for k in sorted(stale)))
    print("  bash scripts/lint-rg-traps.sh --record")
    sys.exit(1)
print("OK — no file grew a trap.")
'
