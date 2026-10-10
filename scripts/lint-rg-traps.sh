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
#   rg-glob-order       an INCLUDE glob placed after an EXCLUSION glob in one rg command (or in one
#                       array definition). Measured on ripgrep 15.2.0 (2026-10-10): for a path several
#                       globs match, the LAST matching glob wins, so
#                         X=(-g '!**/*.spec.*' -g '!tests/**'); CODE=(-g '*.ts')
#                         rg -n PAT "${X[@]}" "${CODE[@]}" .     # re-includes every spec file, and files directly in tests/
#                       (a directory matching `!**/D/**` is pruned before its subdirectories are walked, so
#                       only files sitting directly in D/ come back; a file-name exclusion fails at any depth).
#                       Includes first, exclusions last. Every --iglob is matched AFTER every -g/--glob
#                       whatever its argv position (ripgrep adds -g globs, then iglobs, to one override
#                       set), so `--iglob 'Dockerfile*' … -g '!**/vendor/**'` re-includes vendor/.
#                       -t/-T and --glob-case-insensitive do not change the order (globs beat types).
#                       Arrays resolve to their definition — latest earlier one in the file, else any
#                       one in the file, nested "${Y[@]}" included; an UNRESOLVED name falls back to a
#                       fixed, deliberately small name list: X, EXCL*, SKIP* hold exclusions; CODE, SRC,
#                       INCL*, GLOBS_IN hold includes; any other unresolved name is ignored. An order
#                       fault wholly inside one array is reported once, at its definition line.
#
# Scope: templates/**/*.md and commands/*.md — fenced lines and inline code spans. A span that only
# NAMES the trap (`rg -L` with no pattern, in prose warning against it) is a mention, not a search.
# rg-glob-order reads fenced blocks only (lines joined across `\` and open parens/quotes), plus every
# templates/**/*.sh file whole.
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
    -h|--help)     sed -n '2,43p' "$SELF"; exit 0 ;;
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
  try() {  # $1 label $2 expected exit $3 content [$4 file name, default a.md]
    rm -f "$TD"/templates/x/*; printf '%s\n' "$3" > "$TD/templates/x/${4:-a.md}"
    out=$(bash "$SELF" --repo-root="$TD" 2>&1); rc=$?
    # a crash also exits 1: a red case must be red for a counted trap, not a traceback
    if [ "$rc" = 1 ] && ! printf '%s\n' "$out" | grep -q '^FAIL'; then rc=crash; fi
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
  # rg-glob-order — positives
  try "glob-order: literal excl then incl"  1 $'```bash\nrg -n PAT -g \'!**/*.spec.*\' -g \'*.ts\' .\n```'
  try "glob-order: --glob= forms"           1 $'```\nrg --glob=\'!tests/**\' --glob=\'*.ts\' PAT .\n```'
  try "glob-order: attached -g form"        1 $'```\nrg -n PAT -g\'!vendor/**\' -g\'*.go\' .\n```'
  try "glob-order: resolved arrays"         1 $'```bash\nV=(-g \'!**/*.spec.*\' -g \'!tests/**\'); C=(-g \'*.ts\')\nrg -n PAT "${V[@]}" "${C[@]}" .\n```'
  try "glob-order: array from earlier block" 1 $'```bash\nV=(-g \'!tests/**\')\n```\ntext\n```bash\nrg -n PAT "${V[@]}" -g \'*.ts\' .\n```'
  try "glob-order: names by heuristic"      1 $'```bash\nrg -n PAT "${EXCLUDES[@]}" "${SRC[@]}" .\n```'
  try "glob-order: multi-line array def"    1 $'```bash\nX=(-g \'!**/node_modules/**\'\n   -g \'!**/dist/**\')\nCFG=("${X[@]}" -g \'*.tf\')\n```'
  try "glob-order: \\ continuation"          1 $'```bash\nrg -n PAT \\\n  -g \'!vendor/**\' \\\n  -g \'*.go\' .\n```'
  try "glob-order: iglob incl beats -g excl" 1 $'```\nrg PAT --iglob \'*.ts\' -g \'!tests/**\' .\n```'
  try "glob-order: += appends an include"   1 $'```bash\nV=(-g \'!tests/**\')\nV+=(-g \'*.ts\')\n```'
  try "glob-order: in a .sh script"         1 $'#!/usr/bin/env bash\nX=(-g \'!tests/**\')\nrg -n x "${X[@]}" -g \'*.py\' .' a.sh
  # rg-glob-order — negatives
  try "glob-order: exclusions only"         0 $'```\nrg -n PAT -g \'!a/**\' -g \'!b/**\' .\n```'
  try "glob-order: include first"           0 $'```\nrg -n PAT -g \'*.ts\' -g \'!**/*.spec.*\' -g \'!tests/**\' .\n```'
  try "glob-order: arrays include first"    0 $'```bash\nX=(-g \'!tests/**\'); CODE=(-g \'*.ts\' -g \'!*.d.ts\')\nrg -n PAT "${CODE[@]}" "${X[@]}" .\n```'
  try "glob-order: -g incl, iglob excl"     0 $'```\nrg PAT --iglob \'!**/*.spec.*\' -g \'*.ts\' .\n```'
  try "glob-order: -t with ! globs"         0 $'```\nrg -n PAT -g \'!tests/**\' -t ts .\n```'
  try "glob-order: unknown array name"      0 $'```bash\nrg -n PAT "${ROOTS[@]}" -g \'*.ts\' .\n```'
  try "glob-order: definition beats name"   0 $'```bash\nX=(-g \'*.ts\')\nrg -n PAT "${X[@]}" -g \'*.js\' .\n```'
  try "glob-order: exclusion re-asserted"   0 $'```bash\nCI=(-g \'*.yml\' -g \'!**/{vendor,fixtures}/**\'); SH=(-g \'*.sh\' -g \'!**/{vendor,tests,fixtures}/**\')\nrg --files "${CI[@]}" "${SH[@]}" .\n```'
  try "glob-order: \$( ) inside an array"    0 $'```bash\nROOTS=( $(rg -l x -g \'**/package.json\' -g \'!**/node_modules/**\' . | xargs -n1 dirname) )\nrg -n PAT -g \'*.ts\' -g \'!**/node_modules/**\' "${ROOTS[@]}"\n```'
  try "glob-order: bare-name dir prune"     0 $'```\nrg --files -g \'!.git\' -g \'*.{js,ts}\' -g \'!**/vendor/**\' .\n```'
  try "glob-order: anchored, disjoint dir"   0 $'```\nrg -n PAT -g \'!**/node_modules/**\' --hidden -g \'.github/workflows/*\' .\n```'
  try "glob-order: bare name, include hits it" 1 $'```\nrg --files -g \'!package-lock.json\' -g \'*.json\' .\n```'
  try "glob-order: anchored include inside excl" 1 $'```\nrg -n PAT -g \'!**/vendor/**\' -g \'lib/vendor/*.go\' .\n```'
  try "glob-order: prose, not fenced"       0 "Never write rg -g '!a/**' -g '*.ts' — includes go first."
  echo "lint-rg-traps self-test: $p passed, $f failed"
  [ "$f" -eq 0 ]; exit $?
fi

cd "$REPO_ROOT" || exit 2
BASE="scripts/_rg-traps-baseline.txt"
git ls-files -z --cached --others --exclude-standard 'templates/*.md' 'templates/**/*.md' 'commands/*.md' \
    'templates/*.sh' 'templates/**/*.sh' \
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

# ---- rg-glob-order ----------------------------------------------------------------------------
# Unresolved array names only: a resolved definition always wins over the name.
EXC_NAME = re.compile(r"(X|EXCL\w*|SKIP\w*)")
INC_NAME = re.compile(r"(CODE|SRC|INCL\w*|GLOBS_IN)")
ARR_REF = re.compile(r"\$\{([A-Za-z_]\w*)\[[@*]\]\}")
DEF_TOK = re.compile(r"([A-Za-z_]\w*)(\+?)=")
SHORT_VAL = set("gtTefmABCjMrEd")   # rg short flags that take a value

def open_state(text):
    # Paren depth and open-quote state of a shell fragment; a # at a word start is a comment.
    depth, q, prev, i = 0, None, " ", 0
    while i < len(text):
        c = text[i]
        if q:
            if c == "\\" and q == "\"": i += 1
            elif c == q: q = None
        elif c == "\\": i += 1
        elif c in "\"\x27": q = c
        elif c == "#" and prev in " \t\n;|&(":
            j = text.find("\n", i)
            if j < 0: break
            i = j; c = "\n"
        elif c == "(": depth += 1
        elif c == ")": depth -= 1
        prev = c; i += 1
    return depth, q is not None

def logical_lines(phys):
    # phys: [(lineno, text)] -> [(first lineno, joined text)]; joins `\` continuations and open
    # parens/quotes, but falls back to single lines past 60 physical lines (a heredoc, a stray quote).
    out, buf = [], []
    for n, t in phys:
        buf.append((n, t))
        joined = "\n".join(x[1].rstrip()[:-1] if x[1].rstrip().endswith("\\") else x[1] for x in buf)
        depth, inq = open_state(joined)
        if (t.rstrip().endswith("\\") or depth > 0 or inq) and len(buf) < 60:
            continue
        if len(buf) >= 60 and (depth > 0 or inq):
            out += buf
        else:
            out.append((buf[0][0], joined))
        buf = []
    out += buf
    return out

def toks_of(cmd):
    try:
        lex = shlex.shlex(cmd.replace("`", " ; "), posix=True, punctuation_chars="|&;()")
        lex.whitespace_split = True
        return list(lex)
    except ValueError:
        return []

class Ctx:
    def __init__(self, final):
        self.table, self.final = {}, final
    def expand(self, name):
        # -> list of (kind, flavor, pattern) or None when unknown
        if name in self.table: return self.table[name]
        if name in self.final: return self.final[name]
        if EXC_NAME.fullmatch(name): return [("exc", "g", "!<%s by name>" % name)]
        if INC_NAME.fullmatch(name): return [("inc", "g", "<%s by name>" % name)]
        return None

def glob_items(args, ctx):
    # -> [(kind, flavor, pattern, origin)]; origin = array name, or a unique id per literal glob
    items, i = [], 0
    def lit(pat, flav):
        if pat is None or (pat.startswith("$") and not pat.startswith("!")): return
        items.append(("exc" if pat.startswith("!") else "inc", flav, pat, "#%d" % len(items)))
    while i < len(args):
        a = args[i]
        if a == "--": break
        m = ARR_REF.fullmatch(a)
        if m:
            for k, f, p in (ctx.expand(m.group(1)) or []):
                items.append((k, f, p, m.group(1)))
        elif a in ("-g", "--glob", "--iglob"):
            lit(args[i + 1] if i + 1 < len(args) else None, "i" if a == "--iglob" else "g"); i += 1
        elif a.startswith("--glob=") or a.startswith("--iglob="):
            lit(a.split("=", 1)[1], "i" if a.startswith("--iglob") else "g")
        elif a.startswith("--"):
            if "=" not in a and a in RG_VAL: i += 1
        elif a.startswith("-") and len(a) > 1:
            letters = a[1:]
            for j, ch in enumerate(letters):
                if ch in SHORT_VAL:
                    rest = letters[j + 1:]
                    val = rest if rest else (args[i + 1] if i + 1 < len(args) else None)
                    if not rest: i += 1
                    if ch == "g": lit(val, "g")
                    break
        i += 1
    return items

def braces(p, cap=512):
    # {a,b} expansion, nested; the set a glob stands for when comparing exclusions
    depth, start = 0, -1
    for k, c in enumerate(p):
        if c == "{":
            if depth == 0: start = k
            depth += 1
        elif c == "}" and depth:
            depth -= 1
            if depth == 0:
                parts, d, last = [], 0, start + 1
                for m in range(start + 1, k):
                    if p[m] == "{": d += 1
                    elif p[m] == "}": d -= 1
                    elif p[m] == "," and d == 0: parts.append(p[last:m]); last = m + 1
                parts.append(p[last:k])
                out = set()
                for part in parts:
                    out |= braces(p[:start] + part + p[k + 1:], cap)
                    if len(out) > cap: return {p}
                return out
    return {p}

WILD = re.compile(r"[*?\[{]")
def may_overlap(exc, inc):
    # False only where no path can match both (measured): (1) a bare-name exclusion `!name` / `!name/`
    # prunes that directory, so an include that cannot match the name itself never sees inside it;
    # (2) `!**/D/**` or `!P/**` vs a root-anchored include whose directory part is literal and avoids D/P.
    if "<" in exc or "<" in inc: return True        # an array known only by its name
    for e in braces(exc[1:]):
        for x in braces(inc):
            if not overlap1(e, x): continue
            return True
    return False

def overlap1(e, x):
    import fnmatch
    xparts = x.lstrip("/").split("/")
    name = e.rstrip("/")
    if name and "/" not in name and not WILD.search(name):
        return fnmatch.fnmatchcase(name, xparts[-1]) or "**" in xparts[-1]
    anchored = "/" in x.rstrip("/") and not x.startswith("**") and "**" not in x
    if not anchored or any(WILD.search(c) for c in xparts[:-1]): return True
    m = re.fullmatch(r"\*\*/([^/*?\[{]+)/\*\*", e)
    if m: return m.group(1) in xparts[:-1]
    m = re.fullmatch(r"([^*?\[{]+)/\*\*", e)
    if m:
        pp = m.group(1).strip("/").split("/")
        return xparts[:len(pp)] == pp and len(xparts) > len(pp)
    return True

def order_fault(items):
    # ripgrep matches every -g/--glob, then every --iglob; the LAST matching glob wins. A fault is an
    # include matched after an exclusion from a DIFFERENT origin (one origin is reported at its own
    # definition) that no exclusion after the include re-asserts (brace sets compared exactly).
    eff = [x for x in items if x[1] == "g"] + [x for x in items if x[1] == "i"]
    via = lambda y: "" if y[3].startswith("#") else " (via %s)" % y[3]
    for xi, x in enumerate(eff):
        if x[0] != "inc": continue
        later = set()
        for y in eff[xi + 1:]:
            if y[0] == "exc": later |= braces(y[2])
        bad = [e for e in eff[:xi] if e[0] == "exc" and e[3] != x[3] and not braces(e[2]) <= later
               and may_overlap(e[2], x[2])]
        if bad:
            more = " (+%d more)" % (len(bad) - 1) if len(bad) > 1 else ""
            return "include %s%s after exclusion %s%s%s" % (x[2], via(x), bad[0][2], via(bad[0]), more)
    return None

def array_defs(toks):
    # -> [(name, is_append, elems)] for NAME=( … ) / NAME+=( … ); rg commands come from rg_cmds
    defs, i = [], 0
    while i < len(toks):
        m = DEF_TOK.fullmatch(toks[i])
        if m and i + 1 < len(toks) and toks[i + 1].startswith("(") and set(toks[i + 1]) <= set("();|&"):
            depth, j, elems = toks[i + 1].count("(") - toks[i + 1].count(")"), i + 2, []
            while j < len(toks) and depth > 0:
                t = toks[j]
                if set(t) <= set("();|&"):
                    if "(" in t and elems and elems[-1] in ("$", "<", ">"): elems.pop()
                    depth += t.count("(") - t.count(")")
                    if depth <= 0: break
                elif depth == 1:   # $( … ) / <( … ) inside the array is a command, not an element
                    elems.append(t)
                j += 1
            defs.append((m.group(1), m.group(2) == "+", elems))
            i = j + 1; continue
        i += 1
    return defs

def rg_cmds(toks):
    out, cur = [], None
    for t in toks:
        if set(t) <= set("|&;()"):
            if cur is not None: out.append(cur)
            cur = None; continue
        if t.rsplit("/", 1)[-1] == "rg":
            if cur is not None: out.append(cur)
            cur = []
        elif cur is not None:
            cur.append(t)
    if cur is not None: out.append(cur)
    return out

def code_blocks(path, text):
    lines = text.split("\n")
    if path.endswith(".sh"):
        return [list(enumerate(lines, 1))]
    blocks, cur = [], None
    for n, line in enumerate(lines, 1):
        s = line.strip()
        if s.startswith("```") or s.startswith("~~~"):
            if cur is None: cur = []
            else: blocks.append(cur); cur = None
            continue
        if cur is not None: cur.append((n, line))
    return blocks

def scan_glob_order(path, text):
    lls = [ll for b in code_blocks(path, text) for ll in logical_lines(b)]
    parsed = [(n, toks_of(t)) for n, t in lls]
    # pass 1: every definition in the file, in order (the fallback for a use before its definition)
    ctx0 = Ctx({})
    for n, toks in parsed:
        for name, app, elems in array_defs(toks):
            got = [(k, f, p) for k, f, p, o in glob_items(elems, ctx0)]
            ctx0.table[name] = (ctx0.table.get(name, []) if app else []) + got
    final = ctx0.table
    # pass 2: in order, latest earlier definition wins
    ctx, hits = Ctx(final), []
    for n, toks in parsed:
        for name, app, elems in array_defs(toks):
            items = glob_items(elems, ctx)
            if app and name in ctx.table:
                items = [(k, f, p, name) for k, f, p in ctx.table[name]] + items
            why = order_fault(items)
            if why: hits.append((n, "rg-glob-order", "%s=( … ): %s" % (name, why)))
            ctx.table[name] = [(k, f, p) for k, f, p, o in items]
        for args in rg_cmds(toks):
            why = order_fault(glob_items(args, ctx))
            if why: hits.append((n, "rg-glob-order", "rg: " + why))
    return hits

found = {}
detail = []
for path in sorted(p for p in sys.stdin.read().split("\0") if p):
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    hits = [] if path.endswith(".sh") else [(n, k, "") for n, k in scan(text)]
    hits += scan_glob_order(path, text)
    for n, k, why in hits:
        found[(path, k)] = found.get((path, k), 0) + 1
        detail.append(("%s:%d %s" % (path, n, k), why))

if mode == "list":
    print("\n".join(d + ("  — " + w if w else "") for d, w in detail)); sys.exit(0)
detail = [d for d, w in detail]
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
    print("       never a pattern; grep alternation needs -E; a runnable rg goes in a fenced block, not a table cell;")
    print("       rg globs: the last matching glob wins, so includes first, exclusions last (--iglob is always last).")
    sys.exit(1)
if stale:
    print("FAIL — fixed, but the baseline still admits them (re-record so they cannot come back):")
    print("\n".join("  %s %s: recorded %d, now %d" % (k[0], k[1], rec[k], found.get(k, 0)) for k in sorted(stale)))
    print("  bash scripts/lint-rg-traps.sh --record")
    sys.exit(1)
print("OK — no file grew a trap.")
'
