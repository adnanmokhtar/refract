#!/usr/bin/env python3
"""algo-sites.py — complexity and recursion candidates with the cap on each collection resolved.
Stdlib only, Python 3.8+, run with `python3 -I -B`. Read-only and offline: it never writes the
scanned tree; output goes to stdout, or to --out (refused inside a scanned root).

Why a script and not rg: on a real NestJS + React monorepo, a one-line grep for a linear lookup
inside a callback returned 97 hits, a nested-loop grep 264, a sort-in-callback grep 31 and a naive
self-call grep 179 — and every one was refuted by the same two reads: what bounds each collection
(a schema `.max(N)`, a `limit:`/`take:`, `Math.min(…, N)`, `.slice(0, N)`, a constant) and whether
a recursion carries a depth or cycle guard. This script does those two reads first, so a reader opens
the short list instead of the long one. Every row is a CANDIDATE: complexity-scan reads the code
before anything is reported, and the cap a row cites is checked in the file it names.

Usage:  python3 -I -B algo-sites.py --repo=<dir> [--roots=a,b,...] [--tsv] [--only-open] [--all]
            [--budget=1000000] [--out=<file>]                       # CX-1…CX-5 sites (default mode)
        python3 -I -B algo-sites.py --repo=<dir> [--roots=...] --recursion [--tsv] [--out=<file>]
        python3 -I -B algo-sites.py --self-test
Lanes:  JS/TS (.js .jsx .mjs .cjs .ts .tsx .mts .cts, and the <script> blocks of .vue/.svelte) by a
        masking scanner (strings, comments, template text and regex literals blanked; brackets
        matched); Python by `ast`. Go, JVM, .NET, Ruby, PHP, Rust and Swift files are COUNTED, not
        parsed: the skill's greps cover them, and the summary prints the count so a lane is never
        silently empty.
Columns (sites):     file line class receiver kind loop_line n_cap n_src m_cap m_src ops budget hint
        class   CX-1 lookup in a loop · CX-2 copy-per-iteration accumulator · CX-3 O(n) container op in
                a loop · CX-4 loop-invariant work per iteration · CX-5 nested loops joining two
                collections
        kind    array? (unresolved, assume a list) · list · accumulator (grows with the loop) ·
                derived (a copy built per iteration: [...set], Object.keys(o), Array.from) · set ·
                string · const (ALL_CAPS or a literal ≤ 50)
        n / m   the outer loop's collection and the inner receiver; cap = an integer or `?`; src =
                where the cap came from (literal, slice, limit, min, const:<NAME>, schema:<file:line>,
                guard, param, unknown)
        hint    uncapped (read it) · over-budget (both caps known, n·m > budget) · below-budget ·
                const-small · set · string — and with --all also loop-var / per-element
Columns (recursion): file line class subject calls depth_guard cycle_guard memo walks hint
        RC rows: subject = the function; calls = self-call sites; walks = what it recurses over.
        hint    RC-1? (depth from input, no guard) · RC-2? (parent/next/cause walk, no cycle guard) ·
                RC-3? (≥ 2 self-calls on moving arguments — n − 1, i + 1, a slice, a half — no memo) ·
                json-tree (recurses over parsed JSON: precedents/algorithms.md § 12) · guarded · memo
        RC-4 rows (loops with no condition): subject = the loop form; calls = break/return count;
                depth_guard = the progress variable; cycle_guard = the cursor compare (strict |
                non-strict | ?); memo = short-page exit (yes | no); hint = keyset (progress variable,
                short-page exit, cursor not `>=`) · no-exit · read
Exit:   0 scanned (zero rows is a valid result — the summary prints `# scanned files: N`) · 1 usage ·
        2 a root is missing or unreadable, or --out points inside a scanned root.
"""
import ast
import bisect
import os
import re
import shutil
import sys
import tempfile

SKIP_DIRS = {
    'node_modules', 'dist', 'build', '.next', '.nuxt', 'out', 'coverage', 'vendor', '.venv', 'venv',
    'target', '__pycache__', '.git', 'generated', '__generated__', '.turbo', '.cache',
    'test', 'tests', '__tests__', 'spec', 'e2e', '__mocks__', 'mocks', 'fixtures', '__fixtures__',
    'testdata', 'seeds', 'seeders', 'migrations', 'locales', 'locale', 'i18n', 'translations', 'docs',
}
SKIP_FILE = re.compile(r'(\.d\.ts$|\.min\.js$|\.(test|spec|e2e-spec|stories|fuzz-spec|fuzz|bench|test-data|fixture)\.'
                       r'|^test_.*\.py$|_test\.py$|^conftest\.py$)')
JS_EXT = ('.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx', '.mts', '.cts')
SFC_EXT = ('.vue', '.svelte')
OTHER_EXT = {'.go': 'go', '.java': 'jvm', '.kt': 'jvm', '.scala': 'jvm', '.cs': 'dotnet', '.rb': 'ruby',
             '.php': 'php', '.rs': 'rust', '.swift': 'swift'}
BUDGET = 1000000

# ----------------------------------------------------------------------------------------------
# JS / TS masking: strings, comments, template text and regex literals become spaces (newlines are
# kept, so offsets map to the same line); code inside `${…}` stays code.
REGEX_PREV = set('(,=:[!&|?{};+-*%~^')
REGEX_WORDS = {'return', 'typeof', 'case', 'do', 'else', 'in', 'of', 'yield', 'await', 'void', 'delete'}


def mask_js(src):
    out = list(src)
    n = len(src)
    i = 0
    stack = []          # brace depth at which each open template's `${` started
    depth = 0
    prev = ''           # last significant code char
    word = ''           # last identifier token

    def blank(a, b):
        for k in range(a, min(b, n)):
            if out[k] != '\n':
                out[k] = ' '

    def scan_template(j):
        # j is just after a backtick or a `}` that closes `${`: blank text until ` or ${
        while j < n:
            ch = src[j]
            if ch == '\\':
                blank(j, j + 2)
                j += 2
                continue
            if ch == '`':
                return j + 1, False
            if ch == '$' and j + 1 < n and src[j + 1] == '{':
                return j + 2, True
            blank(j, j + 1)
            j += 1
        return n, False

    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
            continue
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            blank(i, j)
            i = j
            continue
        if c in '\'"':
            j = i + 1
            while j < n and src[j] != c and src[j] != '\n':
                j += 2 if src[j] == '\\' else 1
            blank(i + 1, j)
            i = j + 1
            prev, word = c, ''
            continue
        if c == '`':
            j, opened = scan_template(i + 1)
            if opened:
                stack.append(depth)
            i = j
            prev, word = '`', ''
            continue
        if c == '/' and (prev == '' or prev in REGEX_PREV or word in REGEX_WORDS):
            j = i + 1
            in_cls = False
            ok = False
            while j < n and src[j] != '\n':
                ch = src[j]
                if ch == '\\':
                    j += 2
                    continue
                if ch == '[':
                    in_cls = True
                elif ch == ']':
                    in_cls = False
                elif ch == '/' and not in_cls:
                    ok = True
                    break
                j += 1
            if ok and j > i + 1:
                blank(i + 1, j)
                j += 1
                while j < n and (src[j].isalpha()):
                    j += 1
                i = j
                prev, word = '/', ''
                continue
        if c == '{':
            depth += 1
        elif c == '}':
            if stack and stack[-1] == depth:
                stack.pop()
                j, opened = scan_template(i + 1)
                if opened:
                    stack.append(depth)
                i = j
                prev, word = '`', ''
                continue
            depth -= 1
        if c.isalnum() or c in '_$':
            j = i
            while j < n and (src[j].isalnum() or src[j] in '_$'):
                j += 1
            word = src[i:j]
            prev = 'a'
            i = j
            continue
        if not c.isspace():
            prev, word = c, ''
        i += 1
    return ''.join(out)


def sfc_scripts(src):
    """Keep only <script> block bodies of a .vue/.svelte file (everything else becomes spaces)."""
    out = [ch if ch == '\n' else ' ' for ch in src]
    for m in re.finditer(r'<script\b[^>]*>(.*?)</script>', src, re.S | re.I):
        a, b = m.span(1)
        out[a:b] = list(src[a:b])
    return ''.join(out)


def pair_table(masked):
    pairs = {}
    stack = []
    for i, ch in enumerate(masked):
        if ch in '([{':
            stack.append(i)
        elif ch in ')]}':
            if stack:
                o = stack.pop()
                pairs[o] = i
                pairs[i] = o
    return pairs


class Src:
    def __init__(self, path, rel, text, masked):
        self.path, self.rel, self.text, self.m = path, rel, text, masked
        self.pairs = pair_table(masked)
        self.nl = [i for i, ch in enumerate(text) if ch == '\n']

    def line(self, off):
        return bisect.bisect_right(self.nl, off - 1) + 1


IDENT = r'[A-Za-z_$][\w$]*'
CB_LOOP = re.compile(r'\.\s*(map|forEach|filter|some|every|reduce|reduceRight|flatMap|find|findIndex|findLast'
                     r'|findLastIndex|sort|toSorted)\s*\(')
LOOKUP = re.compile(r'\.\s*(includes|indexOf|lastIndexOf|find|findIndex|findLast|findLastIndex|some|filter|every)\s*\(')
STRINGY = re.compile(r'(?i)(text|name|title|label|phrase|reason|message|str|string|lower|upper|raw|scan|path|url|uri|'
                     r'slug|line|query|search|haystack|needle|word|email|phone|body|content|html|sql|desc|description|'
                     r'prefix|suffix|href|hostname|host|origin|mime|mimetype|ua|agent|cookie|sample|header)$')


def skip_ws_back(m, j):
    while j >= 0 and m[j] in ' \t\r\n':
        j -= 1
    return j


def receiver_before(s, dot):
    """The expression a `.method(` is called on: identifiers, `.`, `?.`, `!`, calls and indexes."""
    m = s.m
    j = skip_ws_back(m, dot - 1)
    if j >= 0 and m[j] == '?':
        j -= 1
    end = j + 1
    while j >= 0:
        ch = m[j]
        if ch in ')]':
            o = s.pairs.get(j)
            if o is None:
                break
            j = o - 1
            if m[j + 1] == '[' and (j < 0 or not (m[j].isalnum() or m[j] in '_$)]?.!')):
                # an array literal `[ … ]` ends the walk
                j -= 0
                return m[o:end].strip(), o
            continue
        if ch == '!' and j > 0 and (m[j - 1].isalnum() or m[j - 1] in '_$)]'):
            j -= 1
            continue
        if ch.isalnum() or ch in '_$':
            k = j
            while k >= 0 and (m[k].isalnum() or m[k] in '_$'):
                k -= 1
            j2 = skip_ws_back(m, k)
            if j2 >= 0 and m[j2] == '.':
                j = j2 - 1
                if j >= 0 and m[j] == '?':
                    j -= 1
                j = skip_ws_back(m, j)
                continue
            word = m[k + 1:j + 1]
            if word == 'new':
                return m[k + 1:end].strip(), k + 1
            # `new X(...)` before the identifier
            j3 = skip_ws_back(m, k)
            if j3 >= 2 and m[j3 - 2:j3 + 1] == 'new' and (j3 - 3 < 0 or not (m[j3 - 3].isalnum() or m[j3 - 3] in '_$')):
                return m[j3 - 2:end].strip(), j3 - 2
            return m[k + 1:end].strip(), k + 1
        break
    return m[j + 1:end].strip(), j + 1


def root_of(expr):
    e = expr.strip()
    if e.startswith('this.'):
        mm = re.match(r'this\.(' + IDENT + ')', e)
        return 'this.' + mm.group(1) if mm else 'this'
    mm = re.match(IDENT, e)
    return mm.group(0) if mm else ''


def idents(expr):
    return set(re.findall(IDENT, expr))


class Loop:
    __slots__ = ('kind', 'head', 'b0', 'b1', 'vars', 'coll', 'acc')

    def __init__(self, kind, head, b0, b1, vars_, coll, acc=None):
        self.kind, self.head, self.b0, self.b1, self.vars, self.coll, self.acc = kind, head, b0, b1, vars_, coll, acc


def stmt_end(s, k):
    """End of a single statement starting at k (an unbraced loop body)."""
    m = s.m
    j = k
    while j < len(m):
        ch = m[j]
        if ch in '([{':
            j = s.pairs.get(j, j) + 1
            continue
        if ch in ';\n' or ch in ')]}':
            return j
        j += 1
    return j


def body_after(s, close):
    m = s.m
    k = close + 1
    while k < len(m) and m[k] in ' \t\r\n':
        k += 1
    if k < len(m) and m[k] == '{' and k in s.pairs:
        return k, s.pairs[k]
    return k, stmt_end(s, k)


def arrow_params(s, p):
    """Parameter names of the callback that starts just after the `(` at p."""
    m = s.m
    t = m[p + 1:p + 400]
    t2 = re.sub(r'^\s*async\s+', '', t)
    off = p + 1 + (len(t) - len(t2))
    mm = re.match(r'\s*function\b[^(]*\(', t2)
    if mm:
        o = off + mm.end() - 1
        c = s.pairs.get(o)
        return [x for x in re.findall(IDENT, m[o + 1:c]) if x not in ('number', 'string', 'any', 'unknown')] if c else []
    mm = re.match(r'\s*\(', t2)
    if mm:
        o = off + mm.end() - 1
        c = s.pairs.get(o)
        if c and re.match(r'\s*(:\s*[^=]+?)?=>', m[c + 1:c + 200]):
            inner = re.sub(r':\s*[^,=]+', '', m[o + 1:c])
            return re.findall(IDENT, inner)
        return []
    mm = re.match(r'\s*(' + IDENT + r')\s*=>', t2)
    return [mm.group(1)] if mm else []


def find_loops(s):
    m = s.m
    loops = []
    for mm in re.finditer(r'\bfor\s*(?:await\s*)?\(', m):
        p = mm.end() - 1
        c = s.pairs.get(p)
        if c is None:
            continue
        head = m[p + 1:c]
        b0, b1 = body_after(s, c)
        h = re.match(r'\s*(?:const|let|var)\s+(.+?)\s+(of|in)\s+(.+)$', head, re.S)
        if h:
            loops.append(Loop('for-' + h.group(2), mm.start(), b0, b1, idents(h.group(1)), h.group(3).strip()))
            continue
        parts = head.split(';')
        if len(parts) == 3:
            v = re.match(r'\s*(?:let|var|const)?\s*(' + IDENT + ')', parts[0])
            cl = re.search(r'<=?\s*([\w$.]+?)\.length\b', parts[1])
            cn = re.search(r'<=?\s*([\w$.]+)', parts[1])
            coll = cl.group(1) if cl else (('#' + cn.group(1)) if cn else '')
            loops.append(Loop('for-c' if parts[0].strip() or parts[1].strip() else 'for-ever', mm.start(), b0, b1,
                              {v.group(1)} if v else set(), coll))
    for mm in re.finditer(r'\bwhile\s*\(', m):
        p = mm.end() - 1
        c = s.pairs.get(p)
        if c is None:
            continue
        j = skip_ws_back(m, mm.start() - 1)
        if j >= 0 and m[j] == '}':
            o = s.pairs.get(j)
            if o is not None and re.search(r'\bdo\s*$', m[max(0, o - 10):o]):
                continue
        cond = m[p + 1:c]
        b0, b1 = body_after(s, c)
        cl = re.match(r'\s*!?\s*\(?\s*([\w$.]+?)\.length\b', cond)
        loops.append(Loop('while', mm.start(), b0, b1, set(), cl.group(1) if cl else ''))
    for mm in re.finditer(r'\bdo\s*\{', m):
        o = mm.end() - 1
        c = s.pairs.get(o)
        if c is not None:
            loops.append(Loop('do', mm.start(), o, c, set(), ''))
    for mm in CB_LOOP.finditer(m):
        p = mm.end() - 1
        c = s.pairs.get(p)
        if c is None:
            continue
        recv, _ = receiver_before(s, mm.start())
        params = arrow_params(s, p)
        meth = mm.group(1)
        acc = None
        if meth in ('reduce', 'reduceRight') and params:
            acc = params[0]
        loops.append(Loop('cb:' + meth, mm.start(), p, c, set(params), recv, acc))
    return loops


def enclosing(loops, pos):
    best = None
    for lp in loops:
        if lp.b0 < pos < lp.b1 and (best is None or lp.b1 - lp.b0 < best.b1 - best.b0):
            best = lp
    return best


def all_enclosing(loops, pos):
    return [lp for lp in loops if lp.b0 < pos < lp.b1]


# ----------------------------------------------------------------------------------------------
# Caps: constants and schema maxima indexed once over the scanned roots.
NUM = r'(\d[\d_]*)'
CONST_NUM = re.compile(r'^\s*(?:export\s+)?(?:const|let|var|static\s+readonly|readonly|public\s+static\s+final\s+\w+|'
                       r'private\s+static\s+final\s+\w+|static\s+final\s+\w+|const)?\s*([A-Z][A-Z0-9_]*)\s*(?::\s*\w+)?\s*'
                       r'(?::=|=)\s*' + NUM + r'\s*(?:as\s+const)?\s*[;,]?\s*(?://.*|#.*)?$', re.M)
CONST_ARR = re.compile(r'(?:const|let|var)\s+([A-Z][A-Z0-9_]*)\s*(?::[^=]+)?=\s*(?:Object\.freeze\(\s*)?\[')
SCHEMA_MAX = [
    re.compile(r'\b(' + IDENT + r')\s*:\s*z\s*\.\s*array\([^\n]*?\)\s*(?:\.\w+\([^()\n]*\)\s*)*?\.max\(\s*([\w.]+)\s*\)'),
    re.compile(r'@ArrayMaxSize\(\s*([\w.]+)\s*\)[\s\S]{0,200}?\b(?:readonly\s+)?(' + IDENT + r')\s*[!?]?\s*:'),
    re.compile(r'\b(' + IDENT + r')\s*:\s*[^\n]*?\bmax_?[Ii]tems\s*[:=]\s*([\w.]+)'),
    re.compile(r'\b(' + IDENT + r')\s*:\s*[^\n]*?\b(?:conlist|Field)\([^\n]*?\bmax_(?:length|items)\s*=\s*([\w.]+)'),
]


class Index:
    def __init__(self):
        self.consts = {}     # NAME -> set(values)
        self.arrays = {}     # NAME -> length
        self.schema = {}     # field -> (cap_expr, rel:line)

    def add(self, rel, text, masked=None):
        for mm in CONST_NUM.finditer(text):
            self.consts.setdefault(mm.group(1), set()).add(int(mm.group(2).replace('_', '')))
        if masked is not None:
            pairs = None
            for mm in CONST_ARR.finditer(masked):
                o = mm.end() - 1
                if pairs is None:
                    pairs = pair_table(masked)
                c = pairs.get(o)
                if c is None:
                    continue
                body = masked[o + 1:c]
                if '...' in body:
                    continue
                n = count_items(body, pairs, o + 1)
                self.arrays[mm.group(1)] = n
        for k, rx in enumerate(SCHEMA_MAX):
            for mm in rx.finditer(text):
                field, cap = (mm.group(2), mm.group(1)) if k == 1 else (mm.group(1), mm.group(2))
                line = text.count('\n', 0, mm.start()) + 1
                self.schema.setdefault(field, (cap, '%s:%d' % (rel, line)))

    def value(self, tok, local=None):
        tok = tok.strip().replace('_', '') if re.match(r'^\d[\d_]*$', tok.strip()) else tok.strip()
        if re.match(r'^\d+$', tok):
            return int(tok), 'literal'
        name = tok.split('.')[-1]
        if local and name in local:
            return local[name], 'const:' + name
        vals = self.consts.get(name)
        if vals and len(vals) == 1:
            return next(iter(vals)), 'const:' + name
        return None, ''


def count_items(body, pairs, base):
    if not body.strip():
        return 0
    n, depth, i = 1, 0, 0
    while i < len(body):
        ch = body[i]
        if ch in '([{':
            j = pairs.get(base + i)
            if j is not None:
                i = j - base + 1
                continue
        if ch == ',':
            rest = body[i + 1:].strip()
            if rest:
                n += 1
        i += 1
    return n


def decl_init(s, name, pos):
    """The nearest `const|let|var NAME = <init>` before pos (or anywhere): (type, init_text, init_masked, off)."""
    m = s.m
    best = None
    rx = re.compile(r'\b(?:const|let|var)\s+' + re.escape(name) + r'\s*(?::\s*([^=;\n]+?))?\s*=(?!=)\s*')
    for mm in rx.finditer(m):
        if best is None or mm.start() < pos:
            best = mm
        if mm.start() > pos:
            break
    if best is None:
        rx2 = re.compile(r'(?:\bthis\.|^[ \t]*(?:(?:private|public|protected|readonly|static)\s+)*)' + re.escape(name.replace('this.', ''))
                         + r'\s*(?::\s*([^=;\n]+?))?\s*=(?!=)\s*', re.M)
        best = next(iter(rx2.finditer(m)), None)
        if best is None:
            pm = re.search(r'[(,]\s*(?:(?:readonly|public|private|protected)\s+)*' + re.escape(name)
                           + r'\s*\??\s*:\s*([^,)=]+)', m)
            if pm:
                return pm.group(1).strip(), '', '', pm.start(), True
            return None, None, None, -1, False
    k = best.end()
    e = stmt_end(s, k)
    return (best.group(1) or '').strip(), s.text[k:e], m[k:e], k, False


def resolve(s, expr, pos, idx, local_consts, depth=0):
    """(kind, cap, src) for a collection expression."""
    e = expr.strip()
    if not e:
        return 'array?', None, 'unknown'
    uw = re.match(r'^\(\s*([\w$.!?]+)\s+as\b[^()]*\)$', e)
    if uw:
        e = uw.group(1)
    if e.startswith('#'):
        v, src = idx.value(e[1:], local_consts)
        return 'array?', v, src or 'unknown'
    if e[0] in '\'"`':
        return 'string', None, 'literal'
    if e.startswith('['):
        if e.startswith('[...') or e.startswith('[ ...'):
            return 'derived', None, 'spread'
        body = e[1:-1] if e.endswith(']') else e[1:]
        n = len([x for x in body.split(',') if x.strip()])
        return ('const' if n <= 50 else 'array?'), n, 'literal'
    if re.match(r'(Array\.from|Object\.(keys|values|entries))\s*\(', e):
        return 'derived', None, 'copy'
    if re.match(r'new\s+(Set|Map|WeakSet|WeakMap)\b', e):
        return 'set', None, 'new'
    if re.search(r'\.(toLowerCase|toUpperCase|trim|trimStart|trimEnd|normalize|toString|join)\(\s*[^)]*\)\s*$', e) or re.match(r'String\(', e):
        return 'string', None, 'expr'
    if re.search(r'\.(keys|values|entries)\(\)\s*$', e):
        return 'derived', None, 'iterator'
    root = root_of(e)
    last = re.sub(r'\(.*$', '', e).split('.')[-1].rstrip('!?')
    # a call chain on a capped collection: cap of the root through slice/filter/map
    sl = re.search(r'\.slice\(\s*0\s*,\s*([\w.]+)\s*\)', e)
    if sl:
        v, src = idx.value(sl.group(1), local_consts)
        if v is not None:
            return 'list', v, 'slice' if src == 'literal' else src
    if re.match(r'^[A-Z][A-Z0-9_]+$', last):
        n = idx.arrays.get(last)
        return 'const', n, 'const:' + last
    if last in idx.schema:
        cap_expr, where = idx.schema[last]
        v, _ = idx.value(cap_expr, local_consts)
        if v is not None:
            return 'array?', v, 'schema:' + where
    name = root
    if not name or name == 'this':
        return 'array?', None, 'unknown'
    gm = re.search(r'\bif\s*\(\s*(?:this\.)?' + re.escape(name.replace('this.', '')) + r'\.length\s*(?:>=|>)\s*([\w.]+)', s.m)
    if gm:
        v, src = idx.value(gm.group(1), local_consts)
        if v is not None and v >= 2:
            return 'list', v, 'guard'
    typ, init, init_m, off, is_param = decl_init(s, name, pos)
    if typ is None and init is None:
        return ('string', None, 'name') if STRINGY.search(last) else ('array?', None, 'unknown')
    if typ:
        if re.search(r'\b(Readonly)?(Set|Map|WeakSet|WeakMap)\s*<|\bRecord\s*<', typ):
            return 'set', None, 'type'
        if re.match(r'string\b(?!\s*\[)', typ):
            return 'string', None, 'type'
    if is_param:
        if STRINGY.search(last):
            return 'string', None, 'name'
        return 'array?', None, 'param'
    it = (init or '').strip()
    itm = (init_m or '').strip()
    if re.match(r'new\s+(Set|Map|WeakSet|WeakMap)\b', itm):
        return 'set', None, 'new'
    if itm[:1] in '\'"`' or re.search(r'\.(join|toLowerCase|toUpperCase|trim|toString)\(\s*[^)]*\)\s*;?$', itm) or re.match(r'(String\(|JSON\.stringify\()', itm):
        return 'string', None, 'init'
    if itm.startswith('[') and itm.rstrip(';').endswith(']') and '...' not in itm:
        n = len([x for x in itm.rstrip(';')[1:-1].split(',') if x.strip()])
        bare = re.escape(name.replace('this.', ''))
        if re.search(r'\b' + bare + r'\s*\.\s*(push|unshift|splice|concat)\s*\(|\b' + bare + r'\s*\[[^\]]*\]\s*=(?!=)|\b' + bare + r'\s*=\s*\[\s*\.\.\.', s.m):
            return 'list', None, 'mutated'
        return ('const' if n <= 50 and re.match(r'^[A-Z]', name) else 'list'), (n if n else None), 'literal'
    for rx, tag in ((r'\.slice\(\s*0\s*,\s*([\w.]+)\s*\)', 'slice'), (r'\bMath\.min\([^)]*?,\s*([\w.]+)\s*\)', 'min'),
                    (r'\b(?:take|limit|first|perPage|pageSize|size|max)\s*:\s*([\w.]+)', 'limit'),
                    (r'\.(?:limit|take|first)\(\s*([\w.]+)\s*\)', 'limit'), (r'(?i)\bLIMIT\s+(\d+|\$\{\s*[\w.]+\s*\})', 'limit')):
        mm = re.search(rx, it)
        if mm:
            tok = mm.group(1).strip('${} ')
            v, src = idx.value(tok, local_consts)
            if v is not None:
                return 'list', v, tag if src == 'literal' else tag + ':' + src.replace('const:', '')
    if depth < 3:
        ch = re.match(r'([\w$.]+?)\s*\.\s*(filter|map|slice|concat|flat|flatMap|sort|toSorted|reverse)\s*\(', itm)
        if ch and root_of(ch.group(1)) != name:
            k, v, src = resolve(s, ch.group(1), off, idx, local_consts, depth + 1)
            if v is not None or k in ('set', 'string', 'const'):
                return ('list' if k == 'array?' else k), v, src
        if re.match(r'^[\w$.]+$', itm.rstrip(';')) and root_of(itm) != name:
            return resolve(s, itm.rstrip(';'), off, idx, local_consts, depth + 1)
    if STRINGY.search(last):
        return 'string', None, 'name'
    return 'array?', None, 'unknown'


def local_constants(text):
    out = {}
    for mm in CONST_NUM.finditer(text):
        out[mm.group(1)] = int(mm.group(2).replace('_', ''))
    return out


def hint_for(kind, n, m, budget, grows=False):
    if kind == 'set':
        return 'set'
    if kind == 'string':
        return 'string'
    if kind == 'const':
        return 'const-small'
    if grows:
        m = n
    if not grows and ((n is not None and n <= 50) or (m is not None and m <= 50)):
        return 'const-small'      # one side is capped at <= 50: linear in the other
    if n is None or m is None:
        return 'uncapped'
    return 'over-budget' if n * m > budget else 'below-budget'


def fmt(v):
    return '?' if v is None else str(v)


def js_sites(s, idx, budget, show_all):
    rows = []
    loops = find_loops(s)
    if not loops:
        return rows
    lc = local_constants(s.text)
    m = s.m

    def outer_cap(lp):
        if lp is None or not lp.coll:
            return None, 'unknown', ''
        k, v, src = resolve(s, lp.coll, lp.head, idx, lc)
        return v, src, k

    def add(cls, pos, recv, kind, lp, m_cap, m_src, grows=False):
        n_cap, n_src, n_kind = outer_cap(lp)
        hint = hint_for(kind, n_cap, m_cap, budget, grows)
        if n_kind == 'const' and hint in ('uncapped', 'over-budget') and not grows:
            hint = 'const-small'      # the loop runs over a constant: linear in the inner size
        mc = n_cap if grows else m_cap
        ops = (n_cap * mc) if (n_cap is not None and mc is not None) else None
        rows.append((s.rel, s.line(pos), cls, re.sub(r'\s+', ' ', recv)[:60] or '-', kind, s.line(lp.head) if lp else 0,
                     fmt(n_cap), n_src, fmt(mc), 'grows' if grows else m_src, fmt(ops), str(budget), hint))

    # CX-1: a linear lookup inside a loop or per-element callback
    for mm in LOOKUP.finditer(m):
        pos = mm.start()
        encl = all_enclosing(loops, pos)
        if not encl:
            continue
        lp = min(encl, key=lambda x: x.b1 - x.b0)
        recv, _ = receiver_before(s, pos)
        if not recv:
            continue
        loopvars = set()
        accs = set()
        for x in encl:
            loopvars |= x.vars
            if x.acc:
                accs.add(x.acc)
        root = root_of(recv)
        if root in accs:
            add('CX-1', pos, recv, 'accumulator', lp, None, 'grows', grows=True)
            continue
        if root in loopvars:
            if show_all:
                rows.append((s.rel, s.line(pos), 'CX-1', recv[:60], 'element', s.line(lp.head), '?', '-', '?', '-', '?', str(budget), 'loop-var'))
            continue
        if idents(recv) & loopvars:
            if show_all:
                rows.append((s.rel, s.line(pos), 'CX-1', recv[:60], 'element', s.line(lp.head), '?', '-', '?', '-', '?', str(budget), 'per-element'))
            continue
        arg = s.text[mm.end():mm.end() + 120].lstrip()
        if mm.group(1) in ('find', 'findIndex', 'findLast', 'findLastIndex', 'some', 'filter', 'every') \
                and re.match(r'[{\[\'"`]|[A-Z][\w$]*\s*,', arg):
            continue          # an ORM / repository call (`em.find(Entity, {…})`), not an array scan — database's N+1 class
        kind, cap, src = resolve(s, recv, pos, idx, lc)
        lit = re.match(r'([\'"`])((?:\\.|(?!\1).)*)\1\s*[,)]', arg)
        if kind == 'array?' and lit and (re.search(r'[^\w-]', lit.group(2)) or STRINGY.search(recv.split('.')[-1])):
            kind = 'string'   # a substring test: `rest.indexOf('\\n')`
        bare = re.escape(recv.replace('this.', ''))
        if kind in ('array?', 'list') and re.search(r'(?:\bthis\.)?\b' + bare + r'\s*\.\s*(push|unshift)\s*\(', m[lp.b0:lp.b1]):
            add('CX-1', pos, recv, 'accumulator', lp, None, 'grows', grows=True)
            continue
        add('CX-1', pos, recv, kind, lp, cap, src)

    # CX-2: copy-per-iteration accumulation
    for lp in loops:
        body = m[lp.b0:lp.b1]
        if lp.acc:
            a = re.escape(lp.acc)
            for mm in re.finditer(r'(?:\{\s*\.\.\.' + a + r'\b|\[\s*\.\.\.' + a + r'\b|(?<![\w$.])' + a
                                  + r'\s*\.\s*concat\(|Object\.assign\(\s*\{\s*\}\s*,\s*' + a + r'\b)', body):
                add('CX-2', lp.b0 + mm.start(), lp.acc, 'accumulator', lp, None, 'grows', grows=True)
        for mm in re.finditer(r'\b(' + IDENT + r')\s*=\s*(?:\[\s*\.\.\.\1\b|\{\s*\.\.\.\1\b|\1\s*\.\s*concat\(|Object\.assign\(\s*\{\s*\}\s*,\s*\1\b)', body):
            pos = lp.b0 + mm.start()
            if enclosing(loops, pos) is lp:
                add('CX-2', pos, mm.group(1), 'accumulator', lp, None, 'grows', grows=True)

    # CX-3: O(n) per-operation container use inside a loop
    for mm in re.finditer(r'\.\s*(shift|unshift)\s*\(|\.\s*splice\s*\(\s*0\s*,', m):
        pos = mm.start()
        lp = enclosing(loops, pos)
        if lp is None:
            continue
        recv, _ = receiver_before(s, pos)
        kind, cap, src = resolve(s, recv, pos, idx, lc)
        if kind == 'set':
            continue
        same = lp.coll and root_of(lp.coll) == root_of(recv)
        if same or src in ('unknown', 'param', 'new'):
            add('CX-3', pos, recv, 'list' if kind == 'array?' else kind, lp, cap, src, grows=(same and cap is None))
        else:
            add('CX-3', pos, recv, 'list' if kind == 'array?' else kind, lp, cap, src)

    # CX-4: loop-invariant work per iteration (sort / clone / Set build / key list / RegExp)
    for mm in re.finditer(r'\.\s*(sort|toSorted)\s*\(|\bnew\s+(Set|Map|RegExp|Intl\.\w+)\s*\(|\bstructuredClone\s*\(|'
                          r'JSON\.parse\(\s*JSON\.stringify\s*\(|\bObject\.(keys|values|entries)\s*\(|\bArray\.from\s*\(', m):
        pos = mm.start()
        encl = all_enclosing(loops, pos)
        if not encl:
            continue
        lp = min(encl, key=lambda x: x.b1 - x.b0)
        if mm.group(1):
            subj, _ = receiver_before(s, pos)
        else:
            o = m.find('(', pos)
            c = s.pairs.get(o)
            subj = m[o + 1:c] if c else ''
            if mm.group(0).startswith('JSON'):
                o2 = m.find('(', o + 1)
                c2 = s.pairs.get(o2)
                subj = m[o2 + 1:c2] if c2 else subj
        subj = subj.strip()
        if not subj or not re.match(r'^[\w$.!?]+(\.slice\(\s*\))?$', subj):
            continue
        loopvars = set()
        for x in encl:
            loopvars |= x.vars
            if x.acc:
                loopvars.add(x.acc)
        if idents(subj) & loopvars:
            continue
        root = root_of(subj)
        if re.search(r'\b(?:const|let|var)\s+' + re.escape(root) + r'\b', m[lp.b0:pos]):
            continue          # declared inside the loop body: per-iteration data, not invariant
        if lp.kind == 'cb:sort' or (lp.coll and root_of(lp.coll) == root):
            continue          # the loop's own collection
        kind, cap, src = resolve(s, subj, pos, idx, lc)
        add('CX-4', pos, subj + ' · ' + (mm.group(1) or mm.group(2) or mm.group(0).split('(')[0]), 'list' if kind in ('array?', 'derived') else kind,
            lp, cap, src)

    # CX-5: an explicit loop nested in a loop over another collection, joining on keys
    for inner in loops:
        if inner.kind not in ('for-of', 'cb:forEach', 'cb:map', 'cb:flatMap') or not inner.coll:
            continue
        encl = [x for x in loops if x is not inner and x.b0 < inner.head < x.b1 and x.vars]
        if not encl:
            continue
        outer = min(encl, key=lambda x: x.b1 - x.b0)
        if idents(inner.coll) & outer.vars:
            continue
        ib = m[inner.b0:inner.b1]
        ov = '|'.join(re.escape(v) for v in outer.vars)
        iv = '|'.join(re.escape(v) for v in inner.vars) or r'\b\B'
        if not re.search(r'\b(?:' + ov + r')\b[\w$.?!]*\s*[!=]==?\s*\b(?:' + iv + r')\b|\b(?:' + iv + r')\b[\w$.?!]*\s*[!=]==?\s*\b(?:' + ov + r')\b', ib):
            continue
        kind, cap, src = resolve(s, inner.coll, inner.head, idx, lc)
        add('CX-5', inner.head, inner.coll, 'list' if kind in ('array?', 'derived') else kind, outer, cap, src)
    return rows


# ----------------------------------------------------------------------------------------------
# Python sites via ast
PY_LIST_ANN = re.compile(r'^(list|List|Sequence|tuple|Tuple|Iterable|MutableSequence|deque)\b')
PY_SET_ANN = re.compile(r'^(set|Set|frozenset|FrozenSet|dict|Dict|Mapping|MutableMapping|AbstractSet|Counter|DefaultDict)\b')


def py_kind_of_value(v):
    if isinstance(v, (ast.List, ast.ListComp)):
        n = len(v.elts) if isinstance(v, ast.List) and v.elts else None
        return 'list', n
    if isinstance(v, ast.Tuple):
        return 'list', len(v.elts)
    if isinstance(v, (ast.Set, ast.SetComp, ast.Dict, ast.DictComp)):
        return 'set', None
    if isinstance(v, (ast.JoinedStr,)) or (isinstance(v, ast.Constant) and isinstance(v.value, str)):
        return 'string', None
    if isinstance(v, ast.Call):
        f = v.func
        name = f.id if isinstance(f, ast.Name) else (f.attr if isinstance(f, ast.Attribute) else '')
        if name in ('set', 'frozenset', 'dict', 'defaultdict', 'Counter', 'OrderedDict'):
            return 'set', None
        if name in ('list', 'sorted'):
            return 'list', None
        if name in ('lower', 'upper', 'strip', 'join', 'format', 'str', 'casefold', 'read', 'decode'):
            return 'string', None
    if isinstance(v, ast.Subscript):
        sl = v.slice
        if isinstance(sl, getattr(ast, 'Index', ())):  # Python 3.8
            sl = sl.value
        if isinstance(sl, ast.Slice) and sl.lower is None and sl.upper is not None:
            return 'list', ('slice', sl.upper)
    return None, None


def py_expr_root(e):
    while isinstance(e, (ast.Attribute, ast.Subscript, ast.Call)):
        e = e.func if isinstance(e, ast.Call) else e.value
    return e.id if isinstance(e, ast.Name) else ''


def py_names(e):
    return {n.id for n in ast.walk(e) if isinstance(n, ast.Name)}


def py_src(e):
    try:
        return ast.unparse(e)  # 3.9+
    except Exception:
        return py_expr_root(e) or '?'


class PyScope:
    def __init__(self, parent=None):
        self.kinds = {}
        self.caps = {}
        self.parent = parent

    def get(self, name):
        s = self
        while s:
            if name in s.kinds:
                return s.kinds[name], s.caps.get(name)
            s = s.parent
        return None, None


def py_cap_value(node, mod_consts):
    if isinstance(node, ast.Constant) and isinstance(node.value, int):
        return node.value, 'literal'
    if isinstance(node, ast.Name) and node.id in mod_consts:
        return mod_consts[node.id], 'const:' + node.id
    return None, ''


def py_sites(rel, text, idx, budget, show_all):
    rows = []
    try:
        tree = ast.parse(text)
    except (SyntaxError, ValueError):
        return rows, False
    mod_consts = {}
    mod_scope = PyScope()
    for st in tree.body:
        if isinstance(st, ast.Assign) and len(st.targets) == 1 and isinstance(st.targets[0], ast.Name):
            nm = st.targets[0].id
            v = st.value
            if isinstance(v, ast.Constant) and isinstance(v.value, int) and not isinstance(v.value, bool):
                mod_consts[nm] = v.value
            k, n = py_kind_of_value(v)
            if k:
                mod_scope.kinds[nm] = 'const' if (k == 'list' and nm.isupper() and isinstance(n, int) and n <= 50) else k
                mod_scope.caps[nm] = n if isinstance(n, int) else None

    def resolve_py(e, scope):
        if isinstance(e, (ast.List, ast.Tuple)):
            n = len(e.elts)
            return ('const' if n <= 50 else 'list'), n, 'literal'
        if isinstance(e, (ast.Set, ast.Dict, ast.SetComp, ast.DictComp)):
            return 'set', None, 'literal'
        if isinstance(e, ast.Constant) and isinstance(e.value, str):
            return 'string', None, 'literal'
        if isinstance(e, ast.Call) and isinstance(e.func, ast.Attribute) and e.func.attr in ('values', 'keys', 'items'):
            return ('set' if e.func.attr == 'keys' else 'derived'), None, 'view'
        if isinstance(e, ast.Call) and isinstance(e.func, ast.Name) and e.func.id in ('list', 'tuple'):
            return 'derived', None, 'copy'
        name = e.id if isinstance(e, ast.Name) else (e.attr if isinstance(e, ast.Attribute) else '')
        if isinstance(e, ast.Name):
            k, cap = scope.get(e.id)
            if k:
                if isinstance(cap, tuple) and cap[0] == 'slice':
                    v, src = py_cap_value(cap[1], mod_consts)
                    return k, v, ('slice' if src == 'literal' else src) if v is not None else 'unknown'
                if k == 'const':
                    return k, cap, 'const:' + e.id
                return k, cap if isinstance(cap, int) else None, 'literal' if isinstance(cap, int) else 'unknown'
        if name and re.match(r'^[A-Z][A-Z0-9_]+$', name):
            return 'const', None, 'const:' + name
        if name in idx.schema:
            cap_expr, where = idx.schema[name]
            v, _ = idx.value(cap_expr, mod_consts)
            if v is not None:
                return 'list?', v, 'schema:' + where
        if name and STRINGY.search(name):
            return 'string', None, 'name'
        return 'list?', None, 'unknown'

    def add(cls, node, recv, kind, loop, m_cap, m_src, grows=False):
        n_kind, n_cap, n_src = resolve_py(loop['coll'], loop['scope']) if loop['coll'] is not None else (None, None, 'unknown')
        if n_kind in ('const',) and n_cap is None:
            n_src = n_src
        hint = hint_for(kind, n_cap, m_cap, budget, grows)
        mc = n_cap if grows else m_cap
        ops = n_cap * mc if (n_cap is not None and mc is not None) else None
        rows.append((rel, node.lineno, cls, recv[:60], kind, loop['line'], fmt(n_cap), n_src, fmt(mc),
                     'grows' if grows else m_src, fmt(ops), str(budget), hint))

    def visit_body(stmts, scope, loops):
        for st in stmts:
            visit(st, scope, loops)

    def note_assign(st, scope):
        if isinstance(st, ast.Assign):
            for t in st.targets:
                if isinstance(t, ast.Name):
                    k, n = py_kind_of_value(st.value)
                    if k:
                        if k == 'list' and re.match(r'^[A-Z][A-Z0-9_]+$', t.id) and isinstance(n, int) and n <= 50:
                            k = 'const'
                        scope.kinds[t.id] = k
                        scope.caps[t.id] = n if (k == 'const' or isinstance(n, tuple)) else None
        if isinstance(st, ast.AnnAssign) and isinstance(st.target, ast.Name):
            ann = py_src(st.annotation)
            if PY_SET_ANN.match(ann):
                scope.kinds[st.target.id] = 'set'
            elif PY_LIST_ANN.match(ann):
                scope.kinds[st.target.id] = 'list'
            elif ann == 'str':
                scope.kinds[st.target.id] = 'string'

    def check_expr(node, scope, loops):
        if not loops:
            return
        loop = loops[-1]
        lv = set()
        for lp in loops:
            lv |= lp['vars']
        for n in ast.walk(node):
            if isinstance(n, ast.Compare):
                for op, right in zip(n.ops, n.comparators):
                    if isinstance(op, (ast.In, ast.NotIn)):
                        if py_names(right) & lv and not isinstance(right, ast.Call):
                            continue
                        if isinstance(right, (ast.Name, ast.Attribute, ast.Call, ast.List, ast.Tuple, ast.Set)):
                            if isinstance(right, ast.Call) and not (isinstance(right.func, ast.Attribute) and right.func.attr in ('values', 'keys', 'items')) \
                                    and not (isinstance(right.func, ast.Name) and right.func.id in ('list', 'tuple')):
                                continue
                            if py_names(right) & lv:
                                continue
                            k, cap, src = resolve_py(right, scope)
                            add('CX-1', n, py_src(right), k, loop, cap, src)
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute):
                recv = n.func.value
                attr = n.func.attr
                if py_names(recv) & lv:
                    continue
                if attr in ('index', 'count', 'remove'):
                    k, cap, src = resolve_py(recv, scope)
                    if k in ('list', 'list?', 'const', 'derived'):
                        add('CX-3' if attr == 'remove' else 'CX-1', n, py_src(recv) + '.' + attr, k, loop, cap, src)
                elif attr == 'pop' and n.args and isinstance(n.args[0], ast.Constant) and n.args[0].value == 0:
                    k, cap, src = resolve_py(recv, scope)
                    same = loop['coll'] is not None and py_expr_root(loop['coll']) == py_expr_root(recv)
                    add('CX-3', n, py_src(recv) + '.pop(0)', 'list' if k in ('list?', None) else k, loop, cap, src, grows=same or loop['while'] == py_expr_root(recv))
                elif attr == 'insert' and n.args and isinstance(n.args[0], ast.Constant) and n.args[0].value == 0:
                    k, cap, src = resolve_py(recv, scope)
                    add('CX-3', n, py_src(recv) + '.insert(0)', 'list', loop, cap, src, grows=True)
                elif attr == 'sort':
                    k, cap, src = resolve_py(recv, scope)
                    add('CX-4', n, py_src(recv) + '.sort', 'list' if k in ('list?', None) else k, loop, cap, src)
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id in ('sorted', 'deepcopy', 'set', 'frozenset') and n.args:
                a0 = n.args[0]
                if isinstance(a0, (ast.Name, ast.Attribute)) and not (py_names(a0) & lv):
                    k, cap, src = resolve_py(a0, scope)
                    add('CX-4', n, n.func.id + '(' + py_src(a0) + ')', 'list' if k in ('list?', None) else k, loop, cap, src)

    def visit(st, scope, loops):
        note_assign(st, scope)
        if isinstance(st, (ast.FunctionDef, ast.AsyncFunctionDef)):
            fs = PyScope(scope)
            for a in st.args.args + st.args.kwonlyargs:
                if a.annotation is not None:
                    ann = py_src(a.annotation)
                    if PY_SET_ANN.match(ann):
                        fs.kinds[a.arg] = 'set'
                    elif PY_LIST_ANN.match(ann):
                        fs.kinds[a.arg] = 'list'
                    elif ann == 'str':
                        fs.kinds[a.arg] = 'string'
            visit_body(st.body, fs, [])
            return
        if isinstance(st, ast.ClassDef):
            visit_body(st.body, PyScope(scope), [])
            return
        if isinstance(st, (ast.For, ast.AsyncFor)):
            check_expr(st.iter, scope, loops)
            lp = {'vars': py_names(st.target), 'coll': st.iter, 'line': st.lineno, 'scope': scope, 'while': ''}
            if loops and isinstance(st.iter, (ast.Name, ast.Attribute)):
                outer = loops[-1]
                if not (py_names(st.iter) & outer['vars']):
                    for n in ast.walk(ast.Module(body=st.body, type_ignores=[])):
                        if isinstance(n, ast.Compare) and len(n.ops) == 1 and isinstance(n.ops[0], (ast.Eq, ast.Is)):
                            l, r = py_names(n.left), py_names(n.comparators[0])
                            if (l & outer['vars'] and r & lp['vars']) or (r & outer['vars'] and l & lp['vars']):
                                k, cap, src = resolve_py(st.iter, scope)
                                add('CX-5', st, py_src(st.iter), 'list' if k in ('list?', 'derived') else k, outer, cap, src)
                                break
            visit_body(st.body, scope, loops + [lp])
            visit_body(st.orelse, scope, loops)
            return
        if isinstance(st, ast.While):
            root = ''
            t = st.test
            if isinstance(t, ast.Name):
                root = t.id
            elif isinstance(t, ast.Call) and isinstance(t.func, ast.Name) and t.func.id == 'len' and t.args:
                root = py_expr_root(t.args[0])
            lp = {'vars': set(), 'coll': ast.Name(id=root, ctx=ast.Load()) if root else None, 'line': st.lineno, 'scope': scope, 'while': root}
            visit_body(st.body, scope, loops + [lp])
            return
        if isinstance(st, ast.Assign) and loops and len(st.targets) == 1 and isinstance(st.targets[0], ast.Name):
            nm = st.targets[0].id
            v = st.value
            if isinstance(v, ast.BinOp) and isinstance(v.op, ast.Add) and isinstance(v.left, ast.Name) and v.left.id == nm \
                    and isinstance(v.right, (ast.List, ast.Tuple, ast.ListComp)):
                add('CX-2', st, nm, 'accumulator', loops[-1], None, 'grows', grows=True)
            elif isinstance(v, ast.Dict) and any(k is None and isinstance(val, ast.Name) and val.id == nm for k, val in zip(v.keys, v.values)):
                add('CX-2', st, nm, 'accumulator', loops[-1], None, 'grows', grows=True)
            elif isinstance(v, ast.List) and v.elts and isinstance(v.elts[0], ast.Starred) and isinstance(v.elts[0].value, ast.Name) and v.elts[0].value.id == nm:
                add('CX-2', st, nm, 'accumulator', loops[-1], None, 'grows', grows=True)
        for field in ('body', 'orelse', 'finalbody', 'handlers'):
            sub = getattr(st, field, None)
            if isinstance(sub, list) and sub and isinstance(sub[0], (ast.stmt, ast.excepthandler)):
                for x in sub:
                    if isinstance(x, ast.excepthandler):
                        visit_body(x.body, scope, loops)
                    else:
                        visit(x, scope, loops)
        if isinstance(st, (ast.With, ast.AsyncWith, ast.If, ast.Try)):
            if isinstance(st, ast.If):
                check_expr(st.test, scope, loops)
            return
        check_expr(st, scope, loops)
        # comprehensions: their generators are loops
        for n in ast.walk(st):
            if isinstance(n, (ast.ListComp, ast.SetComp, ast.GeneratorExp, ast.DictComp)):
                for g in n.generators:
                    lp = {'vars': py_names(g.target), 'coll': g.iter, 'line': n.lineno, 'scope': scope, 'while': ''}
                    for cond in g.ifs:
                        check_expr(cond, scope, loops + [lp])
                    elt = n.elt if not isinstance(n, ast.DictComp) else n.value
                    check_expr(elt, scope, loops + [lp])
    visit_body(tree.body, mod_scope, [])
    # sum(lists, []) anywhere
    for n in ast.walk(tree):
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == 'sum' and len(n.args) == 2 \
                and isinstance(n.args[1], ast.List) and not n.args[1].elts:
            rows.append((rel, n.lineno, 'CX-2', 'sum(…, [])', 'accumulator', n.lineno, '?', 'unknown', '?', 'grows', '?', str(budget), 'uncapped'))
    # dedupe (comprehension walk can visit a node twice)
    seen = set()
    out = []
    for r in rows:
        k = (r[1], r[2], r[3])
        if k not in seen:
            seen.add(k)
            out.append(r)
    return out, True


# ----------------------------------------------------------------------------------------------
# Recursion and unbounded loops
DEPTH_W = re.compile(r'(?i)\b(depth|level|maxDepth|max_depth|remaining|hops|ttl|maxLevel|max_level|limit|attempts?|retries|tries)\b')
CYCLE_W = re.compile(r'(?i)\b(visited|seen|ancestors|onPath|on_path|inStack|in_stack|WeakSet|parents|path\.has|stack\.has)\b')
MEMO_W = re.compile(r'(?i)\b(memo\w*|cache\w*|lru_cache|functools\.cache)\b')
PARENT_W = re.compile(r'\.(parent|parentId|parent_id|next|cause|prev|owner|manager|referrer)\b')
JSON_W = re.compile(r'Array\.isArray\(|Object\.(values|entries|keys)\(|typeof\s+\w+\s*===?\s*[\'"]object|isinstance\(\s*\w+\s*,\s*\(?(dict|list)')
CHILD_W = re.compile(r'\.(children|nodes|items|edges|replies|subtree|left|right|elements|members|fields|properties)\b')
SHRINK_W = re.compile(r'\b\w+\s*[-+]\s*[12]\b|\.slice\(|\[1:\]|\[:-1\]|\b\w+\s*//\s*2|\b\w+\s*/\s*2')

FN_JS = re.compile(r'\bfunction\s*\*?\s*(' + IDENT + r')\s*(?:<[^>]*>)?\s*\(|'
                   r'\b(?:const|let|var)\s+(' + IDENT + r')\s*(?::[^=]+)?=\s*(?:async\s*)?(?:function\b[^(]*\(|\([^()]*\)\s*(?::\s*[^=;{]+?)?\s*=>|' + IDENT + r'\s*=>)|'
                   r'^[ \t]*(?:(?:public|private|protected|static|async|override|readonly|get|set)\s+)*(?!(?:if|for|while|switch|catch|return|function|constructor|super|new|else|do|try|await|typeof)\b)(' + IDENT
                   + r')\s*(?:<[^>\n]*>)?\s*\([^;{}]*?\)\s*(?::\s*[^{;=]+?)?\s*\{', re.M)


def js_recursion(s):
    rows = []
    m = s.m
    for mm in FN_JS.finditer(m):
        name = mm.group(1) or mm.group(2) or mm.group(3)
        method = bool(mm.group(3))
        k = mm.end()
        if mm.group(3):
            b0 = mm.end() - 1
        else:
            j = k
            if mm.group(1) or (mm.group(2) and re.search(r'function\b[^(]*\($', mm.group(0))):
                o = k - 1
                c = s.pairs.get(o)
                if c is None:
                    continue
                j = c + 1
            while j < len(m) and m[j] in ' \t\r\n:':
                if m[j] == ':':
                    t = re.match(r':\s*[^{=;]+', m[j:])
                    j += t.end() if t else 1
                    continue
                j += 1
            if j < len(m) and m[j] == '{':
                b0 = j
            else:
                b0 = j - 1
        b1 = s.pairs.get(b0) if b0 < len(m) and m[b0] == '{' else stmt_end(s, b0 + 1)
        if b1 is None:
            continue
        body = m[b0 + 1:b1]
        nm = re.escape(name)
        if method:
            calls = len(re.findall(r'\b(?:this|self)\s*\.\s*' + nm + r'\s*\(', body))
            calls += len(re.findall(r'\.\s*(?:map|forEach|flatMap|filter|some|every)\s*\(\s*this\.' + nm + r'\b', body))
        else:
            calls = len(re.findall(r'(?<![\w$.])' + nm + r'\s*\(', body))
            calls += len(re.findall(r'\.\s*(?:map|forEach|flatMap|filter|some|every|reduce)\s*\(\s*' + nm + r'\s*[,)]', body))
        if not calls:
            continue
        head = s.text[mm.start():b0 + 1]
        raw = s.text[b0 + 1:b1]
        dg = 'yes' if DEPTH_W.search(head) or DEPTH_W.search(raw) else 'no'
        cg = 'yes' if CYCLE_W.search(head) or CYCLE_W.search(raw) else 'no'
        memo = 'yes' if MEMO_W.search(raw) or re.search(r'\b(memoize|memo|useMemo|useCallback)\s*\(', head) else 'no'
        walks = ','.join(sorted(set(x.group(1) for x in PARENT_W.finditer(raw)) | set(x.group(1) for x in CHILD_W.finditer(raw))))
        if JSON_W.search(raw):
            walks = (walks + ',' if walks else '') + 'json'
        rows.append((s.rel, s.line(mm.start()), name, calls, dg, cg, memo, walks or '-', raw))
    return [classify_rec(r) for r in rows]


def classify_rec(r):
    rel, line, name, calls, dg, cg, memo, walks, raw = r
    parent = any(w in walks.split(',') for w in ('parent', 'parentId', 'parent_id', 'next', 'cause', 'prev', 'owner', 'manager', 'referrer'))
    if memo == 'yes':
        hint, cls = 'memo', 'RC-3'
    elif calls >= 2 and SHRINK_W.search(raw) and 'json' not in walks and not CHILD_W.search(raw):
        hint, cls = 'RC-3?', 'RC-3'
    elif dg == 'yes' and cg == 'yes':
        hint, cls = 'guarded', 'RC-1'
    elif parent and cg == 'no':
        hint, cls = 'RC-2?', 'RC-2'
    elif 'json' in walks and dg == 'no':
        hint, cls = 'json-tree', 'RC-1'
    elif dg == 'yes':
        hint, cls = 'guarded', 'RC-1'
    else:
        hint, cls = 'RC-1?', 'RC-1'
    return (rel, line, cls, name, str(calls), dg, cg, memo, walks, hint)


def loop_progress(rel, line, form, body_raw, cond_exit=False):
    exits = len(re.findall(r'\b(break|return|throw)\b', body_raw)) + (1 if cond_exit else 0)
    pv = re.search(r'\b(' + IDENT + r')\s*=\s*[\w$.]+\[\s*[\w$.]+\.length\s*-\s*1\s*\]\s*[.?]|\b(' + IDENT + r')\s*=\s*[\w$.]+\.at\(\s*-1\s*\)|'
                   r'\b(' + IDENT + r')\s*=\s*\w+\[-1\]|\b(\w*(?:cursor|after|last\w*|offset|page|skip|since)\w*)\s*(?:=|\+=)', body_raw, re.I)
    prog = next((g for g in pv.groups() if g), '-') if pv else '-'
    strict = '?'
    if re.search(r'\$gte\b|\bgte\(|>=\s*[\w$:?]|>=\s*\$\d|__gte\b', body_raw):
        strict = 'non-strict'
    elif re.search(r'\$gt\b|\bgt\(|[^=>]>\s*(?:[:$?]|\$\{)|__gt\b|>\s*\$\d', body_raw):
        strict = 'strict'
    short = 'yes' if re.search(r'\.length\s*<\s*[\w$.]+|\.length\s*===?\s*0|!\s*\w+\.length\b|len\(\w+\)\s*<\s*\w+|if\s+not\s+\w+\s*:', body_raw) else 'no'
    if exits == 0:
        hint = 'no-exit'
    elif prog != '-' and short == 'yes' and strict != 'non-strict':   # a `>=` cursor can stall on a tie: read it (§ 15)
        hint = 'keyset'
    else:
        hint = 'read'
    return (rel, line, 'RC-4', form, str(exits), prog, strict, short, '-', hint)


def js_loops_rc4(s):
    rows = []
    m = s.m
    for mm in re.finditer(r'\bfor\s*\(\s*;\s*;\s*\)|\bwhile\s*\(\s*(?:true|1|!0)\s*\)', m):
        c = mm.end() - 1
        b0, b1 = body_after(s, c)
        rows.append(loop_progress(s.rel, s.line(mm.start()), re.sub(r'\s+', '', mm.group(0)), s.text[b0:b1]))
    for mm in re.finditer(r'\bdo\s*\{', m):
        o = mm.end() - 1
        c = s.pairs.get(o)
        if c is None:
            continue
        tail = re.match(r'\s*while\s*\(\s*(' + IDENT + r')\s*\)', m[c + 1:c + 80])
        if tail:
            rows.append(loop_progress(s.rel, s.line(mm.start()), 'do…while(' + tail.group(1) + ')', s.text[o:c], cond_exit=True))
    return rows


def py_recursion(rel, text):
    rows = []
    try:
        tree = ast.parse(text)
    except (SyntaxError, ValueError):
        return rows
    lines = text.split('\n')
    for fn in ast.walk(tree):
        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            calls = 0
            for n in ast.walk(fn):
                if isinstance(n, ast.Call):
                    f = n.func
                    if (isinstance(f, ast.Name) and f.id == fn.name) or (isinstance(f, ast.Attribute) and f.attr == fn.name
                                                                         and isinstance(f.value, ast.Name) and f.value.id in ('self', 'cls')):
                        calls += 1
                    elif isinstance(f, ast.Name) and f.id in ('map', 'filter') and n.args and isinstance(n.args[0], ast.Name) and n.args[0].id == fn.name:
                        calls += 1
            if not calls:
                continue
            end = getattr(fn, 'end_lineno', fn.lineno + 50)
            raw = '\n'.join(lines[fn.lineno - 1:end])
            decos = ' '.join(py_src(d) for d in fn.decorator_list)
            args = ' '.join(a.arg for a in fn.args.args + fn.args.kwonlyargs)
            dg = 'yes' if DEPTH_W.search(args) or re.search(r'getrecursionlimit|\bdepth\b', raw) else 'no'
            cg = 'yes' if CYCLE_W.search(raw) else 'no'
            memo = 'yes' if re.search(r'\b(cache|lru_cache|memoize)\b', decos) or MEMO_W.search(raw) else 'no'
            walks = ','.join(sorted(set(x.group(1) for x in PARENT_W.finditer(raw)) | set(x.group(1) for x in CHILD_W.finditer(raw))))
            if JSON_W.search(raw):
                walks = (walks + ',' if walks else '') + 'json'
            rows.append(classify_rec((rel, fn.lineno, fn.name, calls, dg, cg, memo, walks or '-', raw)))
        if isinstance(fn, ast.While) and isinstance(fn.test, ast.Constant) and fn.test.value in (True, 1):
            end = getattr(fn, 'end_lineno', fn.lineno + 50)
            rows.append(loop_progress(rel, fn.lineno, 'while True', '\n'.join(lines[fn.lineno:end])))
    return rows


# ----------------------------------------------------------------------------------------------
def iter_files(repo, roots):
    for r in roots:
        base = os.path.join(repo, r)
        if os.path.isfile(base):
            yield base, os.path.relpath(base, repo)
            continue
        for dp, dns, fns in os.walk(base):
            dns[:] = sorted(d for d in dns if d not in SKIP_DIRS and not d.startswith('.'))
            for f in sorted(fns):
                if SKIP_FILE.search(f):
                    continue
                p = os.path.join(dp, f)
                yield p, os.path.relpath(p, repo)


def load(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except OSError:
        return None


def scan(repo, roots, mode, budget=BUDGET, show_all=False):
    files = []
    other = {}
    for p, rel in iter_files(repo, roots):
        ext = os.path.splitext(p)[1].lower()
        if ext in JS_EXT or ext in SFC_EXT or ext == '.py':
            files.append((p, rel, ext))
        elif ext in OTHER_EXT:
            other[OTHER_EXT[ext]] = other.get(OTHER_EXT[ext], 0) + 1
    idx = Index()
    srcs = []
    for p, rel, ext in files:
        text = load(p)
        if text is None or len(text) > 2000000:
            continue
        if ext == '.py':
            idx.add(rel, text)
            srcs.append((rel, ext, text, None))
        else:
            body = sfc_scripts(text) if ext in SFC_EXT else text
            masked = mask_js(body)
            idx.add(rel, body, masked)
            srcs.append((rel, ext, body, Src(p, rel, body, masked)))
    rows, rec, unparsed = [], [], 0
    for rel, ext, text, s in srcs:
        if mode == 'sites':
            if ext == '.py':
                r, ok = py_sites(rel, text, idx, budget, show_all)
                unparsed += 0 if ok else 1
                rows.extend(r)
            else:
                rows.extend(js_sites(s, idx, budget, show_all))
        else:
            if ext == '.py':
                rec.extend(py_recursion(rel, text))
            else:
                rec.extend(js_recursion(s))
                rec.extend(js_loops_rc4(s))
    rows.sort(key=lambda r: (r[0], r[1], r[2]))
    rec.sort(key=lambda r: (r[0], r[1], r[2]))
    return rows, rec, len(srcs), other, unparsed


SITE_HDR = ('file', 'line', 'class', 'receiver', 'kind', 'loop_line', 'n_cap', 'n_src', 'm_cap', 'm_src', 'ops', 'budget', 'hint')
REC_HDR = ('file', 'line', 'class', 'subject', 'calls', 'depth_guard', 'cycle_guard', 'memo', 'walks', 'hint')
OPEN = {'uncapped', 'over-budget', 'RC-1?', 'RC-2?', 'RC-3?', 'no-exit', 'read'}


def emit(rows, hdr, tsv, only_open, out):
    lines = []
    if tsv:
        lines.append('\t'.join(hdr))
    for r in rows:
        if only_open and r[-1] not in OPEN:
            continue
        lines.append('\t'.join(str(x) for x in r) if tsv else '%s:%s  %s  %s' % (r[0], r[1], r[2], '  '.join(str(x) for x in r[3:])))
    out.write('\n'.join(lines) + ('\n' if lines else ''))


def main(argv):
    opts = {'repo': '.', 'roots': '', 'budget': str(BUDGET), 'out': ''}
    flags = set()
    for a in argv:
        if a.startswith('--') and '=' in a:
            k, v = a[2:].split('=', 1)
            if k not in opts:
                print('unknown option: ' + a, file=sys.stderr)
                return 1
            opts[k] = v
        elif a in ('--tsv', '--only-open', '--all', '--recursion', '--self-test'):
            flags.add(a[2:])
        else:
            print('unknown argument: ' + a + '\n' + __doc__.split('\n\n')[2], file=sys.stderr)
            return 1
    if 'self-test' in flags:
        return self_test()
    repo = opts['repo']
    roots = [r for r in opts['roots'].split(',') if r] or ['.']
    if not os.path.isdir(repo):
        print('blocked: repo not found: ' + repo, file=sys.stderr)
        return 2
    for r in roots:
        if not os.path.exists(os.path.join(repo, r)) or not os.access(os.path.join(repo, r), os.R_OK):
            print('blocked: root not found or unreadable: ' + r, file=sys.stderr)
            return 2
    try:
        budget = int(opts['budget'])
    except ValueError:
        print('--budget must be an integer', file=sys.stderr)
        return 1
    out = sys.stdout
    if opts['out']:
        o = os.path.realpath(opts['out'])
        for r in roots:
            if o.startswith(os.path.realpath(os.path.join(repo, r)) + os.sep):
                print('blocked: --out is inside a scanned root (this script never writes the scanned tree)', file=sys.stderr)
                return 2
        out = open(o, 'w', encoding='utf-8')
    mode = 'rec' if 'recursion' in flags else 'sites'
    rows, rec, n, other, unparsed = scan(repo, roots, mode, budget, 'all' in flags)
    data = rows if mode == 'sites' else rec
    emit(data, SITE_HDR if mode == 'sites' else REC_HDR, 'tsv' in flags, 'only-open' in flags, out)
    counts = {}
    for r in data:
        counts[r[-1]] = counts.get(r[-1], 0) + 1
    print('# scanned files: %d (js/ts + py)%s · not parsed: %s · rows: %d · by hint: %s' % (
        n, (' · python syntax errors: %d' % unparsed) if unparsed else '',
        ', '.join('%s %d' % kv for kv in sorted(other.items())) or 'none', len(data),
        ', '.join('%s %d' % kv for kv in sorted(counts.items())) or 'none'), file=sys.stderr)
    if out is not sys.stdout:
        out.close()
    return 0


# ----------------------------------------------------------------------------------------------
# Self-test: each case line carries `@expect <class> <hint>` or `@none` in a comment (comments are
# masked, so the marker never feeds the scanner). Run in a temp dir; nothing else is written.
CASES = {
    'svc/lookup.ts': r'''
const OPEN_SHIPMENTS_MAX_LIMIT = 800;
const BIG = 5000;
const ROLES = ['admin', 'owner', 'staff'];
export async function poll(repo) {
  const read = await repo.find({}, { limit: OPEN_SHIPMENTS_MAX_LIMIT });
  const finished = await repo.done({}, { limit: OPEN_SHIPMENTS_MAX_LIMIT });
  return read.filter((s) => !finished.includes(s)); // @expect CX-1 below-budget
}
export async function pollBig(repo) {
  const read = await repo.find({}, { take: BIG });
  const finished = await repo.done({}, { take: BIG });
  return read.filter((s) => !finished.includes(s)); // @expect CX-1 over-budget
}
export function pick(orders, ids) {
  return orders.filter((o) => ids.includes(o.id)); // @expect CX-1 uncapped
}
export function pickSet(orders, ids) {
  const wanted = new Set(ids);
  return orders.filter((o) => wanted.has(o.id)); // @none
}
export function staff(users) {
  return users.filter((u) => ROLES.includes(u.role)); // @expect CX-1 const-small
}
export function byName(rows, q) {
  return rows.filter((r) => r.name.includes(q)); // @none
}
export function words(items) {
  const title = 'Quarterly report';
  return items.map((i) => title.includes(i)); // @expect CX-1 string
}
export function dedupe(orders) {
  const seen = [];
  for (const o of orders) {
    if (seen.indexOf(o.id) === -1) seen.push(o.id); // @expect CX-1 uncapped
  }
  return seen;
}
export function uniq(xs) {
  return xs.reduce((acc, x) => (acc.includes(x) ? acc : [...acc, x]), []); // @expect CX-2 uncapped
}
export function index(xs) {
  return xs.reduce((acc, x) => ({ ...acc, [x.id]: x }), {}); // @expect CX-2 uncapped
}
export function gather(xs) {
  let out = [];
  for (const x of xs) {
    out = [...out, x]; // @expect CX-2 uncapped
  }
  let all = [];
  for (const x of xs) {
    all = all.concat(x.items); // @expect CX-2 uncapped
  }
  return [out, all];
}
const s = `items.includes(x) inside a template`; // @none
// ids.includes(o.id) inside a comment  @none
export function re(lines) {
  for (const l of lines) {
    if (/\.includes\(/.test(l)) return true; // @none
  }
}
export function rank(xs) {
  const ORDER = ['low', 'mid', 'high'];
  return xs.sort((a, b) => ORDER.indexOf(a.k) - ORDER.indexOf(b.k)); // @expect CX-1 const-small
}
export function inSpread(rows, tags) {
  const set = new Set(tags);
  return rows.filter((r) => [...set].includes(r.tag)); // @expect CX-1 uncapped
}
''',
    'svc/queue.ts': r'''
const MAX_WAITING = 100;
export function bfs(start) {
  const queue = [start];
  while (queue.length) {
    const n = queue.shift(); // @expect CX-3 uncapped
    for (const c of n.children) queue.push(c);
  }
}
export function drain(waiting) {
  if (waiting.length >= MAX_WAITING) throw new Error('full');
  while (waiting.length) {
    waiting.shift()(); // @expect CX-3 below-budget
  }
}
''',
    'svc/invariant.ts': r'''
export function price(users, rates, allowed, pattern) {
  for (const u of users) {
    const sorted = rates.slice().sort(cmp); // @expect CX-4 uncapped
    const s = new Set(allowed); // @expect CX-4 uncapped
    const r = new RegExp(pattern); // @expect CX-4 uncapped
    const own = u.tags.map((t) => t.k).sort(); // @none
  }
}
export function join(as, bs) {
  for (const a of as) {
    for (const b of bs) { // @expect CX-5 uncapped
      if (a.id === b.aId) a.b = b;
    }
  }
}
export function lines(orders) {
  for (const o of orders) {
    for (const l of o.lines) { // @none
      if (l.sku === o.sku) l.ok = true;
    }
  }
}
''',
    'svc/schema.ts': r'''
import { z } from 'zod';
const RosterInput = z.object({ memberUserIds: z.array(z.string()).max(500) });
export async function roster(em, input) {
  const rows = await em.find('M', {}, { limit: 200 });
  const onRoster = rows.map((r) => r.id);
  return input.memberUserIds.filter((id) => !onRoster.includes(id)); // @expect CX-1 below-budget
}
''',
    'svc/walk.ts': r'''
export function walk(node) { // @expect RC-1 RC-1?
  for (const c of node.children) walk(c);
}
export function walkSafe(node, depth = 0, seen = new Set()) { // @expect RC-1 guarded
  if (depth > 64 || seen.has(node)) return;
  seen.add(node);
  for (const c of node.children) walkSafe(c, depth + 1, seen);
}
export function fib(n) { // @expect RC-3 RC-3?
  return n < 2 ? n : fib(n - 1) + fib(n - 2);
}
const memo = new Map();
export function fibm(n) { // @expect RC-3 memo
  if (memo.has(n)) return memo.get(n);
  const v = n < 2 ? n : fibm(n - 1) + fibm(n - 2);
  memo.set(n, v);
  return v;
}
export function rootOf(n) { // @expect RC-2 RC-2?
  return n.parent ? rootOf(n.parent) : n;
}
export function canon(v) { // @expect RC-1 json-tree
  if (Array.isArray(v)) return v.map(canon);
  if (v && typeof v === 'object') return Object.keys(v).sort().map((k) => [k, canon(v[k])]);
  return v;
}
export class Visitor {
  visit(node) { // @expect RC-1 RC-1?
    for (const c of node.children) this.visit(c);
  }
}
export async function every(em, fn) {
  let after = '';
  for (;;) { // @expect RC-4 keyset
    const rows = await em.find('E', { id: { $gt: after } }, { limit: 500, orderBy: { id: 'asc' } });
    for (const r of rows) await fn(r);
    if (rows.length < 500) break;
    after = rows[rows.length - 1].id;
  }
}
export async function sinceStall(em, fn) {
  let after = new Date(0);
  for (;;) { // @expect RC-4 read
    const rows = await em.find('E', { updatedAt: { $gte: after } }, { limit: 500 });
    if (!rows.length) break;
    for (const r of rows) await fn(r);
    after = rows[rows.length - 1].updatedAt;
  }
}
export function splits(i) { // @expect RC-3 RC-3?
  return i >= LIMIT ? 1 : splits(i + 1) + splits(i + 2);
}
export function spin() {
  while (true) { // @expect RC-4 no-exit
    tick();
  }
}
''',
    'worker/sites.py': r'''
from functools import lru_cache
ROLES = ('a', 'b')
LIMIT = 100


def dedupe(items):
    seen_list = []
    for x in items:
        if x in seen_list:  # @expect CX-1 uncapped
            continue
        seen_list.append(x)


def allowed_only(items):
    allowed = {'a', 'b'}
    return [x for x in items if x in allowed]  # @expect CX-1 set


def staff(users):
    return [u for u in users if u.role in ROLES]  # @expect CX-1 const-small


def drain(q):
    while q:
        n = q.pop(0)  # @expect CX-3 uncapped


def flat(lists):
    return sum(lists, [])  # @expect CX-2 uncapped


def acc_copy(rows):
    acc = []
    for r in rows:
        acc = acc + [r]  # @expect CX-2 uncapped
    return acc


def per_user(users, prices):
    for u in users:
        s = sorted(prices)  # @expect CX-4 uncapped


def join(A, B):
    for a in A:
        for b in B:  # @expect CX-5 uncapped
            if a.id == b.a_id:
                a.b = b


def param_list(xs, items: list):
    for x in xs:
        if x in items:  # @expect CX-1 uncapped
            pass


def capped(q, other_q):
    rows = q[:100]
    other = other_q[:LIMIT]
    for r in rows:
        if r in other:  # @expect CX-1 below-budget
            pass


def words(ws, s):
    text = s.lower()
    for w in ws:
        if w in text:  # @expect CX-1 string
            pass


def walk(node):  # @expect RC-1 RC-1?
    for c in node.children:
        walk(c)


@lru_cache(maxsize=None)
def fib(n):  # @expect RC-3 memo
    return n if n < 2 else fib(n - 1) + fib(n - 2)


def page_all(fetch):
    cursor = None
    while True:  # @expect RC-4 keyset
        rows = fetch(after=cursor, limit=500)
        if not rows:
            break
        cursor = rows[-1].id
''',
}


def self_test():
    tmp = tempfile.mkdtemp(prefix='algo-sites-selftest-', dir=os.environ.get('TMPDIR') or None)
    failures = []
    checked = 0
    try:
        for rel, body in CASES.items():
            p = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, 'w', encoding='utf-8') as fh:
                fh.write(body.lstrip('\n'))
        rows, _, n, _, _ = scan(tmp, ['.'], 'sites')
        _, rec, _, _, _ = scan(tmp, ['.'], 'rec')
        got = {}
        for r in rows + rec:
            got.setdefault((r[0], int(r[1])), []).append((r[2], r[-1]))
        for rel, body in CASES.items():
            for i, line in enumerate(body.lstrip('\n').split('\n'), 1):
                mm = re.search(r'@expect\s+(\S+)\s+(\S+)', line)
                here = got.get((rel, i), [])
                if mm:
                    checked += 1
                    if (mm.group(1), mm.group(2)) not in here:
                        failures.append('%s:%d expected %s %s, got %s' % (rel, i, mm.group(1), mm.group(2), here or 'nothing'))
                elif '@none' in line:
                    checked += 1
                    bad = [h for h in here if h[1] not in ('set', 'string', 'const-small', 'below-budget')]
                    if bad:
                        failures.append('%s:%d expected no open row, got %s' % (rel, i, bad))
        # usage and exit codes
        checked += 1
        if main(['--repo=' + tmp, '--roots=does-not-exist']) != 2:
            failures.append('a missing root must exit 2')
        checked += 1
        if main(['--repo=' + tmp, '--out=' + os.path.join(tmp, 'svc', 'x.tsv')]) != 2:
            failures.append('--out inside a scanned root must exit 2')
        checked += 1
        if main(['--bogus']) != 1:
            failures.append('an unknown argument must exit 1')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in failures:
        print('FAIL ' + f)
    print('algo-sites self-test: %d/%d passed' % (checked - len(failures), checked))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
