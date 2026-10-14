#!/usr/bin/env python3
"""dto-types.py — validation-boundary-scan (and http-contract-scan § 1): NestJS param types and decorator blocks.

Why a script and not rg: "the pipe sees no class" is a two-step question — the declared type of
`@Body() dto: X`, then what X IS (class, interface, type alias, enum) after following imports, barrel
re-exports, default exports and tsconfig path aliases. "`@ValidateNested` without `@Type`" and "`@Post`
without `@HttpCode`" are properties of a decorator BLOCK that spans lines. A line grep answers neither,
and `-A<n> | rg -v` answers both wrong. Comments and string literals are masked before any match, so a
JSDoc line that mentions `@Body()` is never a row.

Usage:  python3 -I dto-types.py [--params] [--decorator-blocks] [--enums] [--flagged] [--json]
            [--include-tests] [--action-words=a,b,...] <dir|file> ...
        python3 -I dto-types.py --self-test
Modes (default --params):
  --params            PARAM rows: every @Body/@Query/@Param (+ @MessageBody/@Payload/@Args), named or not.
                      bucket   class | interface | type-alias | enum | array | mapped (Partial/Pick/Omit/
                               Record/...) | union-nullable (X | null / undefined) | union | intersection |
                               primitive | literal | builtin (Date, Buffer) | any-unknown-object |
                               schema-inferred (z.infer<typeof S>, yup.InferType) |
                               inline-object | untyped | other | UNRESOLVED
                      metatype what TypeScript emits as design:paramtypes for that type — the value Nest's
                               ValidationPipe reads (it validates a user class; it skips String, Boolean,
                               Number, Array, Object, Buffer, Date). X | null is Object under
                               strictNullChecks and X without it; when the tsconfig chain cannot be read the
                               column says UNREAD — never a guess.
  --decorator-blocks  PROP rows (each decorated class property, decorators read across lines) with flags:
                        validate-nested-no-type, type-no-validate-nested(child=X validators=N),
                        optional-admits-null (@IsOptional, type without null), no-each(<IsX>) (@Is*/@Matches/
                        @Length... on an array type without each: true), array-no-max.
                      HANDLER rows (each route method) with flags: post-no-httpcode (no @HttpCode and no
                        @Res/@Response/@Next param), res / res-passthrough, httpcode=<arg>,
                        action=<word>@<segment> (whole path segment, or its last -/_ word),
                        returns-nullable, 204-returns(<type>).
  --enums             ENUM rows: numeric | string | mixed (for @IsEnum on numeric enums).
  --flagged           only rows that carry a flag (PARAM: metatype is not a user class).
Output: TSV (one `# KIND\tcolumns` header per kind) or --json; file:line on every row.
Stderr: the ledger — files, tsconfigs (extends unread, strictNullChecks), raw-grep vs parsed param counts
        (every raw hit the parser did not turn into a row is an UNPARSED row), resolution rate, unresolved
        reasons, runtime.
Exit:   0 ran · 2 usage · 3 self-test failed. Stdlib only; reads files, writes nothing (the self-test writes
        a temp dir and removes it). Node, tsc and node_modules are not needed.
"""
import bisect, json, os, re, shutil, sys, tempfile, time

TS_EXT = ('.ts', '.tsx', '.mts', '.cts')
SKIP_DIRS = {'node_modules', 'dist', 'build', '.git', 'coverage', '.next', 'out', '.turbo', '.nx', '.cache'}
TEST_DIRS = {'test', 'tests', '__tests__', '__mocks__', 'e2e'}
TEST_FILE = re.compile(r'\.(spec|test|e2e-spec|e2e)\.[mc]?tsx?$')
PARAM_DECS = ('Body', 'Query', 'Param', 'MessageBody', 'Payload', 'Args')
RAW_PARAM = re.compile(r'@(Body|Query|Param|MessageBody|Payload|Args)\s*\(')
VERBS = {'Get', 'Post', 'Put', 'Patch', 'Delete', 'All', 'Options', 'Head', 'Search'}
ACTION_WORDS = ('search login logout verify refresh calculate quote preview validate check test resolve '
                'approve reject post send resend export import').split()
SKIPPED_META = {'String', 'Boolean', 'Number', 'Array', 'Object', 'Buffer', 'Date'}
PRIM = {'string': 'String', 'number': 'Number', 'boolean': 'Boolean', 'bigint': 'BigInt', 'symbol': 'Symbol'}
OBJ = {'any', 'unknown', 'object', 'Object', '{}', 'never', 'void', 'null', 'undefined'}
BUILTIN = {'Date': 'Date', 'Buffer': 'Buffer', 'Map': 'Map', 'Set': 'Set', 'String': 'String', 'Number': 'Number',
           'Boolean': 'Boolean', 'Function': 'Function', 'Promise': 'Promise', 'Uint8Array': 'Uint8Array'}
MAPPED = {'Partial', 'Pick', 'Omit', 'Record', 'Required', 'Readonly', 'NonNullable', 'Exclude', 'Extract',
          'ReturnType', 'InstanceType', 'Awaited', 'Parameters', 'DeepPartial'}
MODS = {'public', 'private', 'protected', 'readonly', 'static', 'abstract', 'declare', 'override', 'async',
        'accessor', 'get', 'set'}
VALIDATOR = re.compile(r'^(Is[A-Z]\w*|Min|Max|Length|MinLength|MaxLength|Matches|Contains|NotContains|Equals|'
                       r'NotEquals|Array\w+|ValidateNested|ValidateIf|Validate|Allow|Not\w+)$')
EACH_NEEDED = re.compile(r'^(Is[A-Z]\w*|Min|Max|Length|MinLength|MaxLength|Matches|Contains|NotContains|Equals|'
                         r'NotEquals)$')
EACH_EXEMPT = {'IsArray', 'IsOptional', 'IsDefined', 'IsEmpty', 'IsNotEmpty', 'IsNotEmptyObject'}
TRANSFORM_BUILTIN = {'Number', 'String', 'Boolean', 'Date', 'Object', 'Array', 'BigInt'}
SCHEMA_INFER = re.compile(r'^(z\.(infer|input|output|TypeOf)|yup\.(InferType|Asserts)|v\.(InferOutput|InferInput)|'
                          r'Static|InferType|Infer|InferOutput|InferInput)$')
IDENT = re.compile(r'#?[A-Za-z_$][\w$]*')
DEC = re.compile(r'@([A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*)')
BR = re.compile(r'[()\[\]{}]')
INTERESTING = re.compile(r'[/\'"`]')
NOT_NL = re.compile(r'[^\n]')
RX_PREV = set('(,=:[!&|?{};+-*%<>~^')
RX_WORDS = {'return', 'typeof', 'case', 'do', 'else', 'in', 'of', 'new', 'delete', 'void', 'throw', 'yield',
            'await', 'instanceof'}


# ---------------------------------------------------------------- masking: comments, strings, templates, regexes
def _skip_str(s, i):
    q, j, n = s[i], i + 1, len(s)
    while j < n:
        c = s[j]
        if c == '\\':
            j += 2; continue
        if c == q:
            return j + 1
        if c == '\n':
            return j
        j += 1
    return n


def _skip_tpl(s, i):
    j, n = i + 1, len(s)
    while j < n:
        c = s[j]
        if c == '\\':
            j += 2; continue
        if c == '`':
            return j + 1
        if c == '$' and s.startswith('{', j + 1):
            j, depth = j + 2, 1
            while j < n and depth:
                c = s[j]
                if c in '\'"':
                    j = _skip_str(s, j); continue
                if c == '`':
                    j = _skip_tpl(s, j); continue
                if s.startswith('//', j):
                    k = s.find('\n', j); j = n if k < 0 else k; continue
                if s.startswith('/*', j):
                    k = s.find('*/', j + 2); j = n if k < 0 else k + 2; continue
                depth += c == '{'
                depth -= c == '}'
                j += 1
            continue
        j += 1
    return n


def _regex_ok(buf, i):
    k = i - 1
    while k >= 0 and buf[k] in ' \t\r\n':
        k -= 1
    if k < 0 or buf[k] in RX_PREV:
        return True
    if buf[k].isalnum() or buf[k] in '_$':
        j = k
        while j >= 0 and (buf[j].isalnum() or buf[j] in '_$'):
            j -= 1
        return ''.join(buf[j + 1:k + 1]) in RX_WORDS
    return False


def _scan_regex(s, i):
    j, n, cls = i + 1, len(s), False
    while j < n:
        c = s[j]
        if c == '\n':
            return -1
        if c == '\\':
            j += 2; continue
        if cls:
            cls = c != ']'
        elif c == '[':
            cls = True
        elif c == '/':
            j += 1
            while j < n and s[j].isalnum():
                j += 1
            return j
        j += 1
    return -1


def mask(s):
    """Same length, same newlines: comments, string/template interiors and regex literals become spaces."""
    buf, n, i = list(s), len(s), 0
    def blank(a, b):
        if b > a:
            buf[a:b] = NOT_NL.sub(' ', s[a:b])
    while True:
        mo = INTERESTING.search(s, i)
        if not mo:
            break
        i, c = mo.start(), mo.group()
        if c == '/':
            if s.startswith('//', i):
                j = s.find('\n', i); j = n if j < 0 else j; blank(i, j); i = j; continue
            if s.startswith('/*', i):
                k = s.find('*/', i + 2); j = n if k < 0 else k + 2; blank(i, j); i = j; continue
            if _regex_ok(buf, i):
                j = _scan_regex(s, i)
                if j > 0:
                    blank(i, j); i = j; continue
            i += 1; continue
        j = _skip_str(s, i) if c in '\'"' else _skip_tpl(s, i)
        blank(i + 1, j - 1 if j <= n and s[j - 1:j] == c else j)
        i = j
    return ''.join(buf)


# ---------------------------------------------------------------- small scanners over masked text
def match(m, i):
    d = 0
    for mo in BR.finditer(m, i):
        if mo.group() in '([{':
            d += 1
        else:
            d -= 1
            if d == 0:
                return mo.start()
    return len(m)


def match_angle(m, i):
    d, j = 0, i
    while j < len(m):
        c = m[j]
        if c == '<':
            d += 1
        elif c == '>' and m[j - 1] != '=':
            d -= 1
            if d == 0:
                return j
        elif c in '([{':
            j = match(m, j)
        j += 1
    return len(m)


def skip_ws(m, i, end, chars=' \t\r\n'):
    while i < end and m[i] in chars:
        i += 1
    return i


def _prev_ns(m, lo, j):
    k = j - 1
    while k >= lo and m[k] in ' \t\r\n':
        k -= 1
    return m[k] if k >= lo else ''


def _next_ns(m, j, end):
    k = skip_ws(m, j, end)
    return m[k:k + 2] if k < end else ''


def scan_type(m, i, end, stops, brace_stops=False, nl_ends=False):
    d, j = 0, i
    while j < end:
        c = m[j]
        if d == 0:
            if c in stops and not (c == '=' and m[j + 1:j + 2] == '>'):
                return j
            if c == '{' and brace_stops and _prev_ns(m, i, j) not in ('', '|', '&', ':', ',', '<', '(') \
                    and not (_prev_ns(m, i, j) == '>' and m[:j].rstrip().endswith('=>')):
                return j
            if c == '\n' and nl_ends and _prev_ns(m, i, j) not in ('', '|', '&', ',', ':', '=', '(', '<', '.', '?') \
                    and _next_ns(m, j, end)[:1] not in ('|', '&', '.', '?', ':', ',', '>', ')', ']') \
                    and _next_ns(m, j, end) != '=>':
                return j
        if c in '([{<':
            d += 1
        elif c in ')]}' or (c == '>' and m[j - 1] != '='):
            d -= 1
            if d < 0:
                return j
        j += 1
    return j


def scan_expr(m, i, end):
    d, j = 0, i
    while j < end:
        c = m[j]
        if d == 0 and (c == ';' or c == '}'):
            return j
        if d == 0 and c == '\n' and _prev_ns(m, i, j) not in tuple('=([{,+-*/%&|^!?:<>.') \
                and _next_ns(m, j, end)[:1] not in tuple('.?:+*/%&|^,=<>)]'):
            return j
        if c in '([{':
            d += 1
        elif c in ')]}':
            d -= 1
        j += 1
    return j


def split_top(t, sep):
    parts, d, cur = [], 0, 0
    for k, ch in enumerate(t):
        if ch in '([{<':
            d += 1
        elif ch in ')]}' or (ch == '>' and t[k - 1:k] != '='):
            d -= 1
        elif ch == sep and d == 0:
            parts.append(t[cur:k]); cur = k + 1
    parts.append(t[cur:])
    return [p.strip() for p in parts if p.strip()]


def norm(t):
    return re.sub(r'\s+', ' ', t).strip()


# ---------------------------------------------------------------- source files and their module tables
class Dec:
    __slots__ = ('name', 'start', 'end', 'line', 'args', 'margs')


class Src:
    def __init__(self, path):
        self.path = path
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                self.s = fh.read()
        except OSError:
            self.s = ''
        self.m = mask(self.s)
        self.nl = [mo.start() for mo in re.finditer('\n', self.s)]
        self._mod = self._classes = None

    def line(self, i):
        return bisect.bisect_left(self.nl, i) + 1

    def dec(self, i):
        mo = DEC.match(self.m, i)
        if not mo:
            return None
        d = Dec(); d.name = mo.group(1).split('.')[-1]; d.start = i; d.line = self.line(i)
        k = skip_ws(self.m, mo.end(), len(self.m))
        d.args = d.margs = None; d.end = mo.end()
        if k < len(self.m) and self.m[k] == '(':
            e = match(self.m, k); d.args, d.margs, d.end = self.s[k + 1:e], self.m[k + 1:e], e + 1
        return d

    # module table: imports, exports, star exports, declarations
    def mod(self):
        if self._mod is None:
            self._mod = parse_module(self)
        return self._mod

    def classes(self):
        if self._classes is None:
            self._classes = parse_classes(self) if '@' in self.m or 'class' in self.m else []
        return self._classes


IMPORT = re.compile(r'\bimport\s+(type\s+)?([\w$*{}\s,]*?)\s*\bfrom\s*([\'"])')
IMPORT_EQ = re.compile(r'\bimport\s+([A-Za-z_$][\w$]*)\s*=\s*require\s*\(\s*([\'"])')
EXPORT_LIST = re.compile(r'\bexport\s+(type\s+)?\{([^}]*)\}(?:\s*from\s*([\'"]))?')
EXPORT_STAR = re.compile(r'\bexport\s*\*\s*(?:as\s+([A-Za-z_$][\w$]*)\s*)?from\s*([\'"])')
EXPORT_DEF_DECL = re.compile(r'\bexport\s+default\s+(?:abstract\s+)?(class|function|interface)\b\s*\*?\s*([A-Za-z_$][\w$]*)?')
EXPORT_DEF_ID = re.compile(r'\bexport\s+default\s+([A-Za-z_$][\w$]*)\s*(?:;|$)', re.M)
DECL = re.compile(r'^([ \t]*)(export[ \t]+)?(?:default[ \t]+)?(?:declare[ \t]+)?(?:abstract[ \t]+)?'
                  r'(class|interface|type|const[ \t]+enum|enum|namespace|function|const|let|var)\b[ \t]*\*?[ \t]*'
                  r'([A-Za-z_$][\w$]*)', re.M)


def _spec(src, q_end):
    q = src.m[q_end - 1]
    e = src.m.find(q, q_end)
    return src.s[q_end:e] if e >= 0 else ''


def parse_module(src):
    m = src.m
    imports, tonly, exports, stars, decls = {}, set(), {}, [], {}
    for mo in IMPORT.finditer(m):
        spec, clause, t = _spec(src, mo.end()), mo.group(2).strip(), bool(mo.group(1))
        braces = re.search(r'\{([^}]*)\}', clause)
        for part in re.sub(r'\{[^}]*\}', '', clause).split(','):
            part = part.strip()
            ns = re.fullmatch(r'\*\s*as\s+([\w$]+)', part)
            if ns:
                imports[ns.group(1)] = (spec, '*')
            elif re.fullmatch(r'[\w$]+', part):
                imports[part] = (spec, 'default')
                if t:
                    tonly.add(part)
        for item in (braces.group(1).split(',') if braces else []):
            item, ti = item.strip(), t
            if item.startswith('type '):
                item, ti = item[5:].strip(), True
            it = re.fullmatch(r'([\w$]+)(?:\s+as\s+([\w$]+))?', item)
            if it:
                local = it.group(2) or it.group(1)
                imports[local] = (spec, it.group(1))
                if ti:
                    tonly.add(local)
    for mo in IMPORT_EQ.finditer(m):
        imports[mo.group(1)] = (_spec(src, mo.end()), '=')
    for mo in EXPORT_LIST.finditer(m):
        spec = _spec(src, mo.end()) if mo.group(3) else None
        for item in mo.group(2).split(','):
            item = item.strip()
            if item.startswith('type '):
                item = item[5:].strip()
            it = re.fullmatch(r'([\w$]+)(?:\s+as\s+([\w$]+))?', item)
            if it:
                exports[it.group(2) or it.group(1)] = ('from', spec, it.group(1)) if spec is not None else ('local', it.group(1))
    for mo in EXPORT_STAR.finditer(m):
        spec = _spec(src, mo.end())
        if mo.group(1):
            exports[mo.group(1)] = ('ns', spec)
        else:
            stars.append(spec)
    for mo in EXPORT_DEF_DECL.finditer(m):
        exports['default'] = ('local', mo.group(2)) if mo.group(2) else ('anon', mo.start())
    for mo in EXPORT_DEF_ID.finditer(m):
        if mo.group(1) not in ('class', 'function', 'abstract', 'async', 'interface', 'enum', 'new'):
            exports['default'] = ('local', mo.group(1))
    for mo in DECL.finditer(m):
        kind = re.sub(r'\s+', ' ', mo.group(3))
        kind = 'enum' if kind == 'const enum' else 'value' if kind in ('const', 'let', 'var', 'function') else kind
        top, name = mo.group(1) == '', mo.group(4)
        if name in decls and decls[name][4] and not top:
            continue
        decls[name] = (kind, mo.start(), mo.end(), bool(mo.group(2)), top)
    return {'imports': imports, 'tonly': tonly, 'exports': exports, 'stars': stars, 'decls': decls}


# ---------------------------------------------------------------- classes, members, params
class Member:
    __slots__ = ('kind', 'name', 'line', 'decs', 'opt', 'type', 'mtype', 'params', 'rtype', 'init')


class Param:
    __slots__ = ('decs', 'name', 'type', 'mtype', 'opt')


class Cls:
    __slots__ = ('name', 'line', 'start', 'header', 'decs', 'members')


CLASS = re.compile(r'(?<![\w$.])class\s+(?:([A-Za-z_$][\w$]*)\s*)?')


def class_decs(src, lo, kw):
    decs, k = [], lo
    for mo in DEC.finditer(src.m, lo, kw):
        if mo.start() < k:
            continue
        d = src.dec(mo.start())
        if d and d.end <= kw:
            decs.append(d); k = d.end
    chain, nxt = [], kw
    for d in reversed(decs):
        if re.fullmatch(r'(\s|export|default|abstract|declare)*', src.m[d.end:nxt]):
            chain.insert(0, d); nxt = d.start
        else:
            break
    return chain


def parse_classes(src):
    m, out, pos = src.m, [], 0
    for mo in CLASS.finditer(m):
        if mo.start() < pos:
            continue
        j, d = mo.end(), 0
        while j < len(m):
            c = m[j]
            if c == '(':
                d += 1
            elif c == ')':
                d -= 1
            elif d == 0 and c in '{;':
                break
            j += 1
        if j >= len(m) or m[j] != '{':
            continue
        be = match(m, j)
        c = Cls(); c.name = mo.group(1) or 'default'; c.line = src.line(mo.start()); c.start = mo.start()
        c.header = norm(src.s[mo.end():j]); c.decs = class_decs(src, pos, mo.start())
        c.members = parse_members(src, j + 1, be)
        out.append(c); pos = be
    return out


def parse_members(src, b0, b1):
    m, s, i, out = src.m, src.s, b0, []
    while True:
        i = skip_ws(m, i, b1, ' \t\r\n;,')
        if i >= b1:
            break
        start, decs = i, []
        while i < b1 and m[i] == '@':
            d = src.dec(i)
            if not d:
                break
            decs.append(d); i = skip_ws(m, d.end, b1)
        while True:
            mo = IDENT.match(m, i)
            if mo and mo.group() in MODS:
                k = skip_ws(m, mo.end(), b1)
                if k < b1 and (m[k].isalpha() or m[k] in '_$[#*\'"'):
                    i = k; continue
            break
        if i < b1 and m[i] == '*':
            i = skip_ws(m, i + 1, b1)
        if i >= b1:
            break
        c = m[i]
        if c == '[':
            e = match(m, i); name = s[i:e + 1]; i = e + 1
        elif c in '\'"':
            e = m.find(c, i + 1); e = b1 if e < 0 else e; name = s[i + 1:e]; i = e + 1
        else:
            mo = IDENT.match(m, i)
            if not mo:
                i = max(i + 1, start + 1); continue
            name, i = mo.group(), mo.end()
        mem = Member(); mem.kind = 'prop'; mem.name = name; mem.line = src.line(i - 1); mem.decs = decs
        mem.opt, mem.type, mem.mtype, mem.params, mem.rtype, mem.init = False, '', '', [], '', False
        i = skip_ws(m, i, b1)
        if i < b1 and m[i] in '?!':
            mem.opt = m[i] == '?'; i = skip_ws(m, i + 1, b1)
        if i < b1 and m[i] == '<':
            i = skip_ws(m, match_angle(m, i) + 1, b1)
        if i < b1 and m[i] == '(':
            pe = match(m, i)
            mem.kind, mem.params = 'method', parse_params(src, i + 1, pe)
            j = skip_ws(m, pe + 1, b1)
            if j < b1 and m[j] == ':':
                k = skip_ws(m, j + 1, b1); e = scan_type(m, k, b1, ';}', brace_stops=True)
                mem.rtype = norm(s[k:e]); j = e
            j = skip_ws(m, j, b1)
            if j < b1 and m[j] == '{':
                j = match(m, j) + 1
            out.append(mem); i = j; continue
        if i < b1 and m[i] == ':':
            k = skip_ws(m, i + 1, b1); e = scan_type(m, k, b1, ';=}', nl_ends=True)
            mem.type, mem.mtype = norm(s[k:e]), norm(m[k:e]); i = e
        if i < b1 and m[i] == '=' and m[i + 1:i + 2] != '>':
            mem.init = True; i = scan_expr(m, i + 1, b1)
        out.append(mem)
        if i <= start:
            i = start + 1
    return out


def parse_params(src, a, b):
    m, s, out, segs, d, cur = src.m, src.s, [], [], 0, a
    for j in range(a, b):
        c = m[j]
        if c in '([{<':
            d += 1
        elif c in ')]}' or (c == '>' and m[j - 1] != '='):
            d -= 1
        elif c == ',' and d == 0:
            segs.append((cur, j)); cur = j + 1
    segs.append((cur, b))
    for pa, pb in segs:
        i = skip_ws(m, pa, pb)
        if i >= pb:
            continue
        p = Param(); p.decs, p.name, p.type, p.mtype, p.opt = [], '', '', '', False
        while i < pb and m[i] == '@':
            dd = src.dec(i)
            if not dd:
                break
            p.decs.append(dd); i = skip_ws(m, dd.end, pb)
        while True:
            mo = IDENT.match(m, i)
            if mo and mo.group() in ('public', 'private', 'protected', 'readonly', 'override'):
                i = skip_ws(m, mo.end(), pb); continue
            break
        if m.startswith('...', i):
            i += 3
        if i < pb and m[i] in '{[':
            e = match(m, i); p.name = norm(s[i:e + 1]); i = e + 1
        else:
            mo = IDENT.match(m, i)
            p.name = mo.group() if mo else ''
            i = mo.end() if mo else i
        i = skip_ws(m, i, pb)
        if i < pb and m[i] == '?':
            p.opt = True; i = skip_ws(m, i + 1, pb)
        if i < pb and m[i] == ':':
            k = skip_ws(m, i + 1, pb); e = scan_type(m, k, pb, '=')
            p.type, p.mtype = norm(s[k:e]), norm(m[k:e])
        out.append(p)
    return out


# ---------------------------------------------------------------- tsconfig (JSONC) and module resolution
def strip_jsonc(t):
    out, i, n = [], 0, len(t)
    while i < n:
        c = t[i]
        if c == '"':
            j = i + 1
            while j < n and t[j] != '"':
                j += 2 if t[j] == '\\' else 1
            out.append(t[i:j + 1]); i = j + 1; continue
        if t.startswith('//', i):
            j = t.find('\n', i); i = n if j < 0 else j; continue
        if t.startswith('/*', i):
            j = t.find('*/', i + 2); i = n if j < 0 else j + 2; continue
        if c == ',':
            k = i + 1
            while k < n and t[k] in ' \t\r\n':
                k += 1
            if k < n and t[k] in '}]':
                i += 1; continue
            if t.startswith('//', k) or t.startswith('/*', k):
                rest = strip_jsonc(t[k:]).lstrip()
                if rest[:1] in ('}', ']'):
                    i += 1; continue
        out.append(c); i += 1
    return ''.join(out)


class World:
    def __init__(self, roots):
        self.srcs, self.cfg_by_dir, self.cfgs, self.file_cache, self.pkgs = {}, {}, {}, {}, None
        self.roots = [os.path.abspath(r) for r in roots]

    def src(self, path):
        if path not in self.srcs:
            self.srcs[path] = Src(path)
        return self.srcs[path]

    # tsconfig
    def load_cfg(self, path, seen=()):
        if path in self.cfgs:
            return self.cfgs[path]
        cfg = {'baseUrl': None, 'paths': None, 'paths_dir': None, 'strict': None, 'snc': None, 'notes': [],
               'file': path}
        try:
            with open(path, encoding='utf-8') as fh:
                data = json.loads(strip_jsonc(fh.read()))
        except (OSError, ValueError) as e:
            cfg['notes'].append('unparseable %s (%s)' % (path, type(e).__name__)); self.cfgs[path] = cfg; return cfg
        d = os.path.dirname(path)
        ext = data.get('extends')
        for e in (ext if isinstance(ext, list) else [ext] if ext else []):
            p = self._ext_path(e, d)
            if p and p not in seen:
                par = self.load_cfg(p, seen + (path,))
                for k in ('baseUrl', 'paths', 'paths_dir', 'strict', 'snc'):
                    if par[k] is not None:
                        cfg[k] = par[k]
                cfg['notes'] += par['notes']
            else:
                cfg['notes'].append('extends %s not found (from %s)' % (e, path))
        co = data.get('compilerOptions') or {}
        if 'baseUrl' in co:
            cfg['baseUrl'] = os.path.normpath(os.path.join(d, co['baseUrl']))
        if isinstance(co.get('paths'), dict):
            cfg['paths'], cfg['paths_dir'] = co['paths'], d
        if 'strict' in co:
            cfg['strict'] = bool(co['strict'])
        if 'strictNullChecks' in co:
            cfg['snc'] = bool(co['strictNullChecks'])
        self.cfgs[path] = cfg
        return cfg

    def _ext_path(self, e, d):
        cands = [os.path.join(d, e)] if e.startswith('.') or os.path.isabs(e) else \
            [os.path.join(a, 'node_modules', e) for a in self._ancestors(d)]
        for c in cands:
            for x in (c, c + '.json', os.path.join(c, 'tsconfig.json')):
                if os.path.isfile(x):
                    return os.path.normpath(x)
        return None

    @staticmethod
    def _ancestors(d):
        while True:
            yield d
            p = os.path.dirname(d)
            if p == d:
                return
            d = p

    def cfg_for(self, path):
        d = os.path.dirname(path)
        walked = []
        for a in self._ancestors(d):
            if a in self.cfg_by_dir:
                cfg = self.cfg_by_dir[a]; break
            walked.append(a)
            if os.path.isfile(os.path.join(a, 'tsconfig.json')):
                cfg = self.load_cfg(os.path.join(a, 'tsconfig.json')); break
        else:
            cfg = None
        for a in walked:
            self.cfg_by_dir[a] = cfg
        return cfg

    def strict(self, path):
        cfg = self.cfg_for(path)
        if cfg is None:
            return 'UNREAD'
        v = cfg['snc'] if cfg['snc'] is not None else cfg['strict']
        if v is None:
            return 'UNREAD' if any(n.startswith('extends') or n.startswith('unparseable') for n in cfg['notes']) else 'off'
        return 'on' if v else 'off'

    # files
    def try_file(self, base):
        if base in self.file_cache:
            return self.file_cache[base]
        root, ext = os.path.splitext(base)
        cands = []
        if ext in ('.js', '.mjs', '.cjs', '.jsx'):
            cands += [root + e for e in ('.ts', '.tsx', '.d.ts', '.mts', '.cts')]
        if ext in TS_EXT:
            cands.append(base)
        cands += [base + e for e in ('.ts', '.tsx', '.d.ts', '.mts', '.cts')]
        cands += [os.path.join(base, 'index' + e) for e in ('.ts', '.tsx', '.d.ts')]
        hit = next((c for c in cands if os.path.isfile(c)), None)
        if hit is None and os.path.isfile(os.path.join(base, 'package.json')):
            hit = self._pkg_entry(base)
        self.file_cache[base] = hit
        return hit

    def _pkg_entry(self, d):
        try:
            with open(os.path.join(d, 'package.json'), encoding='utf-8') as fh:
                pj = json.load(fh)
        except (OSError, ValueError):
            return None
        for k in ('types', 'typings', 'main', 'module'):
            v = pj.get(k)
            if isinstance(v, str):
                for c in (os.path.join(d, v),):
                    root = os.path.splitext(c)[0]
                    for x in (c, root + '.ts', root + '.d.ts', os.path.join(c, 'index.ts')):
                        if os.path.isfile(x) and x.endswith(('.ts', '.tsx', '.d.ts', '.mts', '.cts')):
                            return x
        for x in ('src/index.ts', 'index.ts', 'index.d.ts'):
            if os.path.isfile(os.path.join(d, x)):
                return os.path.join(d, x)
        return None

    def workspace_pkgs(self):
        if self.pkgs is None:
            self.pkgs, tops = {}, set()
            for r in self.roots:
                top = os.path.dirname(r) if os.path.isfile(r) else r
                for a in self._ancestors(top):
                    if any(os.path.exists(os.path.join(a, x)) for x in ('pnpm-workspace.yaml', 'lerna.json', 'nx.json',
                                                                       'turbo.json', 'rush.json', '.git')):
                        top = a; break
                tops.add(top)
            for t in tops:
                for dp, dns, fns in os.walk(t):
                    dns[:] = [x for x in dns if x not in SKIP_DIRS and not x.startswith('.')]
                    if 'package.json' in fns:
                        try:
                            with open(os.path.join(dp, 'package.json'), encoding='utf-8') as fh:
                                nm = json.load(fh).get('name')
                            if isinstance(nm, str):
                                self.pkgs.setdefault(nm, dp)
                        except (OSError, ValueError, AttributeError):
                            pass
        return self.pkgs

    def resolve_module(self, spec, from_path):
        if not spec:
            return None
        if spec.startswith('.') or os.path.isabs(spec):
            return self.try_file(os.path.normpath(os.path.join(os.path.dirname(from_path), spec)))
        cfg = self.cfg_for(from_path)
        if cfg and cfg['paths']:
            base = cfg['baseUrl'] or cfg['paths_dir']
            pats = sorted(cfg['paths'].items(), key=lambda kv: (('*' in kv[0]), -len(kv[0].split('*')[0])))
            for pat, targets in pats:
                if '*' in pat:
                    pre, _, suf = pat.partition('*')
                    if not (spec.startswith(pre) and spec.endswith(suf) and len(spec) >= len(pre) + len(suf)):
                        continue
                    star = spec[len(pre):len(spec) - len(suf)]
                elif pat != spec:
                    continue
                else:
                    star = ''
                for t in targets if isinstance(targets, list) else [targets]:
                    hit = self.try_file(os.path.normpath(os.path.join(base, t.replace('*', star))))
                    if hit:
                        return hit
        if cfg and cfg['baseUrl']:
            hit = self.try_file(os.path.normpath(os.path.join(cfg['baseUrl'], spec)))
            if hit:
                return hit
        parts = spec.split('/')
        name = '/'.join(parts[:2]) if spec.startswith('@') else parts[0]
        sub = spec[len(name):].lstrip('/')
        pk = self.workspace_pkgs().get(name)
        dirs = ([pk] if pk else []) + [os.path.join(a, 'node_modules', name)
                                      for a in self._ancestors(os.path.dirname(from_path))]
        for d in dirs:
            if os.path.isdir(d):
                hit = self.try_file(os.path.join(d, sub)) if sub else (self._pkg_entry(d) or self.try_file(os.path.join(d, 'index')))
                if hit is None and sub:
                    hit = self.try_file(os.path.join(d, 'src', sub))
                if hit:
                    return hit
        return None

    # names
    def resolve_name(self, src, name, depth=0):
        """-> ('ok', kind, src, decl_start, decl_end, typeonly) | ('unresolved', reason)"""
        if depth > 24:
            return ('unresolved', 'cycle:' + name)
        mod = src.mod()
        if '.' in name:
            head, rest = name.split('.', 1)
            imp = mod['imports'].get(head)
            if imp and imp[1] == '*':
                tgt = self.resolve_module(imp[0], src.path)
                if not tgt:
                    return ('unresolved', 'module-not-found:' + imp[0])
                return self.resolve_export(self.src(tgt), rest, depth + 1)
            if imp:
                return ('unresolved', 'qualified:' + name)
            if head in mod['decls'] and mod['decls'][head][0] == 'namespace':
                return ('unresolved', 'namespace-member:' + name)
            return ('unresolved', 'qualified:' + name)
        dcl = mod['decls'].get(name)
        imp = mod['imports'].get(name)
        if dcl and (dcl[4] or not imp):
            return ('ok', dcl[0], src, dcl[1], dcl[2], False)
        if imp:
            tgt = self.resolve_module(imp[0], src.path)
            if not tgt:
                return ('unresolved', 'module-not-found:' + imp[0])
            r = self.resolve_export(self.src(tgt), imp[1], depth + 1)
            if r[0] == 'ok' and name in mod['tonly']:
                r = r[:5] + (True,)
            return r
        return ('unresolved', 'not-declared:' + name)

    def resolve_export(self, src, name, depth):
        if depth > 24:
            return ('unresolved', 'cycle:' + name)
        mod = src.mod()
        e = mod['exports'].get(name)
        if e:
            if e[0] == 'local':
                return self.resolve_name(src, e[1], depth + 1)
            if e[0] == 'anon':
                return ('ok', 'class', src, e[1], e[1], False)
            if e[0] == 'from':
                tgt = self.resolve_module(e[1], src.path)
                if not tgt:
                    return ('unresolved', 'module-not-found:' + e[1])
                return self.resolve_export(self.src(tgt), e[2], depth + 1)
            return ('unresolved', 'namespace-export:' + name)
        dcl = mod['decls'].get(name)
        if dcl and dcl[3]:
            return ('ok', dcl[0], src, dcl[1], dcl[2], False)
        if name != 'default':
            for st in mod['stars']:
                tgt = self.resolve_module(st, src.path)
                if tgt:
                    r = self.resolve_export(self.src(tgt), name, depth + 1)
                    if r[0] == 'ok':
                        return r
        return ('unresolved', 'not-exported:%s@%s' % (name, os.path.basename(src.path)))

    def alias_rhs(self, src, dend):
        m = src.m
        i = skip_ws(m, dend, len(m))
        if i < len(m) and m[i] == '<':
            i = skip_ws(m, match_angle(m, i) + 1, len(m))
        if i >= len(m) or m[i] != '=':
            return ''
        k = skip_ws(m, i + 1, len(m))
        return norm(m[k:scan_type(m, k, len(m), ';', nl_ends=True)])

    def enum_kind(self, src, dend):
        m = src.m
        b = m.find('{', dend)
        if b < 0:
            return 'mixed', ''
        e = match(m, b)
        kinds, names = set(), []
        for item in split_top(m[b + 1:e], ','):
            nm, _, val = item.partition('=')
            names.append(nm.strip())
            val = val.strip()
            kinds.add('numeric' if not val or re.fullmatch(r'-?[\d_.xXa-fA-F]+|[\w.]+\s*[<|&+*-].*', val)
                      else 'string' if val[:1] in '\'"`' else 'mixed')
        k = kinds.pop() if len(kinds) == 1 else 'mixed'
        return k, ','.join(names)

    # types
    def classify(self, src, t, strict, depth=0):
        """t is masked type text. -> (bucket, metatype, [resolution strings], bucket_certain)"""
        t = t.strip()
        while t.startswith('(') and match(t, 0) == len(t) - 1:
            t = t[1:-1].strip()
        if t.startswith('|') or t.startswith('&'):
            t = t[1:].strip()
        if not t:
            return ('untyped', 'Object', [], True)
        parts = split_top(t, '|')
        if len(parts) > 1:
            nn = [p for p in parts if p not in ('null', 'undefined')]
            subs = [self.classify(src, p, strict, depth + 1) for p in nn]
            res = [r for sb in subs for r in sb[2]]
            certain = True
            if len(nn) == 1:
                inner = subs[0]
                meta = 'Object' if strict == 'on' or inner[1] == 'Object' else inner[1] if strict == 'off' \
                    else 'UNREAD(strictNullChecks)'
                return ('union-nullable(%s)' % inner[0], meta, res, certain)
            metas = {sb[1] for sb in subs}
            if len(nn) < len(parts) and strict != 'off':
                meta = 'Object' if strict == 'on' else 'UNREAD(strictNullChecks)'
            elif len(metas) == 1 and not any(sb[0] == 'UNRESOLVED' for sb in subs):
                meta = metas.pop()
            elif any(sb[0] == 'UNRESOLVED' for sb in subs) and len(metas - {'UNREAD'}) <= 1:
                meta, certain = 'UNREAD', True
            else:
                meta = 'Object'
            return ('union', meta, res, certain)
        parts = split_top(t, '&')
        if len(parts) > 1:
            subs = [self.classify(src, p, strict, depth + 1) for p in parts]
            metas = {sb[1] for sb in subs}
            return ('intersection', metas.pop() if len(metas) == 1 else 'Object', [r for sb in subs for r in sb[2]], True)
        if t.endswith('[]') and match(t, len(t) - 2) == len(t) - 1:
            sb = self.classify(src, t[:-2], strict, depth + 1)
            return ('array', 'Array', sb[2], True)
        am = re.match(r'(?:Readonly)?Array\s*<(.*)>$', t, re.S)
        if am:
            return ('array', 'Array', self.classify(src, am.group(1), strict, depth + 1)[2], True)
        if t[0] == '{':
            return ('inline-object', 'Object', [], True)
        if t[0] == '[':
            return ('array', 'Array', [], True)
        if t[0] in '\'"`':
            return ('literal', 'String', [], True)
        if re.fullmatch(r'-?\d[\d_.]*n?', t):
            return ('literal', 'Number', [], True)
        if t in ('true', 'false'):
            return ('literal', 'Boolean', [], True)
        if t in PRIM:
            return ('primitive', PRIM[t], [], True)
        if t in OBJ:
            return ('any-unknown-object', 'Object', [], True)
        if re.match(r'(typeof|keyof|infer|unique)\b', t) or '=>' in t:
            return ('other', 'Function' if '=>' in t and not t.startswith(('typeof', 'keyof')) else 'Object', [], True)
        nm = re.fullmatch(r'([A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*)\s*(<.*>)?', t, re.S)
        if not nm:
            return ('other', 'UNREAD', [], True)
        name, args = nm.group(1), nm.group(2)
        if SCHEMA_INFER.match(name):  # z.infer<typeof S>, yup.InferType<...>: a schema type, no class to validate
            return ('schema-inferred', 'UNREAD(schema)', [], True)
        if name in MAPPED:
            inner = split_top(args[1:-1], ',') if args else []
            res = self.classify(src, inner[0], strict, depth + 1)[2] if inner and name != 'Record' else []
            return ('mapped', 'Object', res, True)
        if name in BUILTIN and name not in src.mod()['decls'] and name not in src.mod()['imports']:
            return ('builtin', BUILTIN[name], [], True)
        r = self.resolve_name(src, name)
        if r[0] != 'ok':
            return ('UNRESOLVED', 'UNREAD', ['UNRESOLVED %s' % r[1]], False)
        kind, dsrc, dstart, dend, tonly = r[1], r[2], r[3], r[4], r[5]
        dn = re.search(r'([A-Za-z_$][\w$]*)$', dsrc.m[dstart:dend])
        dn = dn.group(1) if dn and dend > dstart else 'default'
        loc = '%s %s@%s:%d%s' % (kind, dn, disp(dsrc.path), dsrc.line(dstart), '' if dn == name else ' (as %s)' % name)
        if kind == 'class':
            return ('class', 'UNREAD(import type)' if tonly else name, [loc + (' import-type' if tonly else '')], True)
        if kind == 'interface':
            return ('interface', 'Object', [loc], True)
        if kind == 'enum':
            ek = self.enum_kind(dsrc, dend)[0]
            return ('enum', {'numeric': 'Number', 'string': 'String'}.get(ek, 'Object'), [loc], True)
        if kind == 'type':
            rhs = self.alias_rhs(dsrc, dend)
            sb = self.classify(dsrc, rhs, strict, depth + 1) if rhs and depth < 8 else ('other', 'Object', [], True)
            # design:paramtypes for an alias comes from the checker's resolved type: primitive-like and array
            # aliases keep String/Number/Boolean/Array, object-like ones are Object; anything else is not guessed
            objlike = sb[0] in ('class', 'interface', 'inline-object', 'mapped', 'any-unknown-object') or \
                (sb[0] == 'type-alias' and sb[1] == 'Object')
            meta = sb[1] if sb[1] in ('String', 'Number', 'Boolean', 'Array') else 'Object' if objlike else 'UNREAD'
            return ('type-alias', meta, [loc + ' =' + sb[0]] + sb[2], True)
        return ('other', 'UNREAD', [loc], True)


# ---------------------------------------------------------------- scanning
CWD = os.getcwd()
ROOTS_DISPLAY = []


def disp(p):
    for absr, given in ROOTS_DISPLAY:
        if p == absr or p.startswith(absr + os.sep):
            return os.path.normpath(os.path.join(given, os.path.relpath(p, absr))) if p != absr else given
    rel = os.path.relpath(p, CWD)
    return p if rel.startswith('..' + os.sep + '..') else rel


def list_files(roots, include_tests):
    out = []
    for r in roots:
        if os.path.isfile(r):
            out.append(os.path.abspath(r)); continue
        for dp, dns, fns in os.walk(r):
            dns[:] = sorted(x for x in dns if x not in SKIP_DIRS and (include_tests or x not in TEST_DIRS))
            for f in sorted(fns):
                if f.endswith(TS_EXT) and not f.endswith('.d.ts') and (include_tests or not TEST_FILE.search(f)):
                    out.append(os.path.abspath(os.path.join(dp, f)))
    return out


def literals(text):
    return [mo.group(2) for mo in re.finditer(r'([\'"`])((?:\\.|(?!\1).)*)\1', text or '')]


def route_paths(d):
    if d is None or d.args is None or not d.margs.strip():
        return ['']
    a = d.args
    pm = re.search(r'\bpath\s*:\s*(\[[^\]]*\]|[\'"`][^\'"`]*[\'"`])', a)
    if pm:
        return literals(pm.group(1)) or ['UNREAD(%s)' % norm(a)]
    if d.margs.strip()[:1] == '{':
        return ['']
    lits = literals(a)
    if lits and re.fullmatch(r'\s*(\[\s*)?([\'"`][^\'"`]*[\'"`]\s*,?\s*)+\]?\s*', a):
        return lits
    return ['UNREAD(%s)' % norm(a)]


def join_route(a, b):
    return '/'.join(x.strip('/') for x in (a, b) if x and x.strip('/'))


def action_word(route, words):
    hit = None
    for seg in route.split('/'):
        if not seg or seg.startswith(':') or seg.startswith('UNREAD'):
            continue
        last = re.split(r'[-_]', seg)[-1]
        for w in words:
            if seg == w or (last == w and len(seg) > len(w)):
                hit = '%s@%s' % (w, seg)
    return hit


def dec_text(decs):
    return ' '.join('@%s%s' % (d.name, '' if d.args is None else '(%s)' % (norm(d.args)[:80])) for d in decs)


def scan(roots, modes, include_tests=False, words=ACTION_WORDS):
    t0 = time.time()
    world = World(roots)
    ROOTS_DISPLAY[:] = sorted(((os.path.abspath(r), r) for r in roots), key=lambda x: -len(x[0]))
    files = list_files(roots, include_tests)
    rows, raw, seen_params, method_level = [], [], set(), set()
    cls_index = {}
    for f in files:
        src = world.src(f)
        for mo in RAW_PARAM.finditer(src.m):
            raw.append((f, src.line(mo.start()), mo.group(1)))
        if '@' not in src.m and 'enum' not in src.m:
            continue
        strict = world.strict(f)
        if 'enums' in modes:
            for name, dcl in src.mod()['decls'].items():
                if dcl[0] == 'enum':
                    k, names = world.enum_kind(src, dcl[2])
                    rows.append({'kind': 'ENUM', 'at': '%s:%d' % (disp(f), src.line(dcl[1])), 'name': name,
                                 'enum': k, 'members': names[:120], 'flags': '' if k == 'string' else k})
        if '@' not in src.m:
            continue
        for c in src.classes():
            cls_index.setdefault(c.name, []).append((src, c))
            ctrl = next((d for d in c.decs if d.name == 'Controller'), None)
            prefixes = route_paths(ctrl) if ctrl else ['']
            for mem in c.members:
                for d in mem.decs:
                    if d.name in PARAM_DECS:  # GraphQL's method-level @Query(() => T) is not a param
                        method_level.add((f, d.line))
                if mem.kind == 'method':
                    vd = next((d for d in mem.decs if d.name in VERBS), None)
                    routes = [join_route(p, q) for p in prefixes for q in route_paths(vd)] if vd else []
                    verb = vd.name.upper() if vd else ''
                    if 'params' in modes:
                        for p in mem.params:
                            for d in p.decs:
                                if d.name not in PARAM_DECS:
                                    continue
                                lits = literals(d.args) if d.args else []
                                named = lits[0] if lits and re.match(r'\s*[\'"`]', d.args or '') else ''
                                pipes = norm(d.args[d.args.find(',') + 1:]) if named and ',' in (d.args or '') else \
                                    (norm(d.args) if d.args and not named else '')
                                b, meta, res, certain = world.classify(src, p.mtype, strict)
                                seen_params.add((f, d.line))
                                rows.append({'kind': 'PARAM', 'at': '%s:%d' % (disp(f), d.line), 'decorator': d.name,
                                             'name': named, 'param': p.name, 'type': p.type or '-', 'bucket': b,
                                             'metatype': meta, 'resolved': '; '.join(res) or '-', 'pipes': pipes or '-',
                                             'route': ('%s %s' % (verb, ' | '.join(routes) or '/')) if vd else '-',
                                             'handler': '%s.%s' % (c.name, mem.name), 'strict': strict,
                                             'flags': '' if b == 'class' and not meta.startswith('UNREAD') else b})
                    if vd and 'blocks' in modes:
                        flags = []
                        hc = next((d for d in mem.decs if d.name == 'HttpCode'), None)
                        resd = [d for p in mem.params for d in p.decs if d.name in ('Res', 'Response', 'Next')]
                        if resd:
                            flags.append('res-passthrough' if all(re.search(r'passthrough\s*:\s*true', d.args or '')
                                                                  for d in resd) else 'res')
                        if hc:
                            flags.append('httpcode=%s' % norm(hc.args or ''))
                        elif verb == 'POST' and not resd:
                            flags.append('post-no-httpcode')
                        aw = [action_word(r, words) for r in routes]
                        aw = [a for a in aw if a]
                        if aw:
                            flags.append('action=' + aw[-1])
                        pm = re.fullmatch(r'Promise\s*<(.*)>', mem.rtype, re.S)
                        if any(x in ('null', 'undefined') for x in split_top(pm.group(1) if pm else mem.rtype, '|')):
                            flags.append('returns-nullable')
                        if hc and re.search(r'\b(204|NO_CONTENT)\b', hc.args or '') and mem.rtype and \
                                not re.fullmatch(r'(Promise\s*<\s*)?void(\s*>)?', mem.rtype):
                            flags.append('204-returns(%s)' % mem.rtype)
                        rows.append({'kind': 'HANDLER', 'at': '%s:%d' % (disp(f), vd.line),
                                     'handler': '%s.%s' % (c.name, mem.name), 'verb': verb,
                                     'route': ' | '.join(routes) or '/', 'returns': mem.rtype or '-',
                                     'flags': ' '.join(flags), 'decorators': dec_text(mem.decs)})
                elif 'blocks' in modes and mem.decs:
                    rows.append(prop_row(world, src, c, mem, strict))
    if 'params' in modes:
        for f, ln, dn in raw:
            if (f, ln) not in seen_params and (f, ln) not in method_level:
                rows.append({'kind': 'UNPARSED', 'at': '%s:%d' % (disp(f), ln), 'decorator': dn,
                             'text': norm(world.src(f).s.split('\n')[ln - 1])[:160], 'flags': 'unparsed'})
    ledger = make_ledger(world, files, rows, raw, time.time() - t0)
    ledger['method_level_decorators'] = len(method_level)
    return rows, ledger


def prop_row(world, src, c, mem, strict):
    names = {d.name for d in mem.decs}
    flags = []
    is_arr = bool(re.search(r'\[\]\s*(\|\s*(null|undefined)\s*)*$|^(Readonly)?Array\s*<', mem.mtype))
    if 'ValidateNested' in names and 'Type' not in names:
        flags.append('validate-nested-no-type')
    td = next((d for d in mem.decs if d.name == 'Type'), None)
    if td and 'ValidateNested' not in names:
        tm = re.search(r'=>\s*([A-Za-z_$][\w$.]*)', td.margs or '')
        if tm and tm.group(1) not in TRANSFORM_BUILTIN:
            flags.append('type-no-validate-nested(child=%s)' % child_info(world, src, tm.group(1)))
    if 'IsOptional' in names and not re.search(r'\bnull\b', mem.mtype):
        flags.append('optional-admits-null')
    if is_arr:
        for d in mem.decs:
            if EACH_NEEDED.match(d.name) and d.name not in EACH_EXEMPT and \
                    not re.search(r'\beach\s*:\s*true', d.margs or ''):
                flags.append('no-each(%s)' % d.name)
        if any(VALIDATOR.match(n) for n in names) and 'ArrayMaxSize' not in names:
            flags.append('array-no-max')
    return {'kind': 'PROP', 'at': '%s:%d' % (disp(src.path), mem.line), 'prop': '%s.%s' % (c.name, mem.name),
            'type': (mem.type or '-') + ('?' if mem.opt else ''), 'flags': ' '.join(flags),
            'decorators': dec_text(mem.decs)}


def child_info(world, src, name):
    r = world.resolve_name(src, name)
    if r[0] != 'ok':
        return '%s UNRESOLVED %s' % (name, r[1])
    if r[1] != 'class':
        return '%s %s' % (name, r[1])
    csrc = r[2]
    for c in csrc.classes():
        if c.start == r[3] or (r[3] <= c.start < r[4] + 40):
            n = sum(1 for mem in c.members for d in mem.decs if VALIDATOR.match(d.name))
            ext = ' extends' if re.search(r'\bextends\b', c.header) else ''
            return '%s validators=%d%s' % (name, n, ext)
    return '%s validators=UNREAD' % name


def make_ledger(world, files, rows, raw, secs):
    params = [r for r in rows if r['kind'] == 'PARAM']
    unparsed = [r for r in rows if r['kind'] == 'UNPARSED']
    by_dec, by_bucket, reasons = {}, {}, {}
    for r in params:
        by_dec[r['decorator']] = by_dec.get(r['decorator'], 0) + 1
        key = r['decorator'] + ':' + r['bucket']
        by_bucket[key] = by_bucket.get(key, 0) + 1
        for x in r['resolved'].split('; '):
            if x.startswith('UNRESOLVED'):
                rs = x.split(' ', 1)[1].split(':')[0]
                reasons[rs] = reasons.get(rs, 0) + 1
    unres = sum(1 for r in params if r['bucket'] == 'UNRESOLVED')
    named = [r for r in params if r['resolved'] != '-']
    named_unres = sum(1 for r in named if 'UNRESOLVED' in r['resolved'])
    cfgs = sorted({c['file'] for c in world.cfgs.values()})
    notes = sorted({n for c in world.cfgs.values() for n in c['notes']})
    stricts = {}
    for r in params:
        stricts[r['strict']] = stricts.get(r['strict'], 0) + 1
    return {'files': len(files), 'modules_loaded': len(world.srcs), 'tsconfigs': [disp(c) for c in cfgs],
            'tsconfig_notes': notes, 'strictNullChecks': stricts, 'raw_param_hits': len(raw),
            'params': len(params), 'unparsed': len(unparsed), 'by_decorator': by_dec, 'by_bucket': by_bucket,
            'bucket_unresolved': unres,
            'resolution_rate': round(100.0 * (len(params) - unres) / len(params), 2) if params else None,
            'named_types': len(named), 'named_unresolved': named_unres,
            'named_resolution_rate': round(100.0 * (len(named) - named_unres) / len(named), 2) if named else None,
            'unresolved_reasons': reasons, 'seconds': round(secs, 2)}


COLS = {'PARAM': ['at', 'decorator', 'name', 'param', 'type', 'bucket', 'metatype', 'resolved', 'pipes', 'route', 'handler'],
        'PROP': ['at', 'prop', 'type', 'flags', 'decorators'],
        'HANDLER': ['at', 'handler', 'verb', 'route', 'returns', 'flags', 'decorators'],
        'ENUM': ['at', 'name', 'enum', 'members'],
        'UNPARSED': ['at', 'decorator', 'text']}


def emit(rows, ledger, as_json, flagged):
    if flagged:
        rows = [r for r in rows if r.get('flags')]
    if as_json:
        json.dump({'rows': rows, 'ledger': ledger}, sys.stdout, indent=1); sys.stdout.write('\n')
    else:
        for kind in ('PARAM', 'HANDLER', 'PROP', 'ENUM', 'UNPARSED'):
            ks = [r for r in rows if r['kind'] == kind]
            if ks:
                print('# %s\t%s' % (kind, '\t'.join(COLS[kind])))
                for r in ks:
                    print('\t'.join([kind] + [str(r.get(c, '')) if r.get(c, '') != '' else '-' for c in COLS[kind]]))
    L = ledger
    w = sys.stderr.write
    w('dto-types: %d files, %d modules read, %.2fs\n' % (L['files'], L['modules_loaded'], L['seconds']))
    tc = L['tsconfigs']
    w('  tsconfig: %d read%s%s\n' % (len(tc), ': ' if tc else ' (none found)', ', '.join(tc[:5]) + (' ...' if len(tc) > 5 else '')))
    for n in L['tsconfig_notes'][:5]:
        w('  tsconfig note: %s\n' % n)
    if len(L['tsconfig_notes']) > 5:
        w('  tsconfig notes: %d more (--json lists all)\n' % (len(L['tsconfig_notes']) - 5))
    if L['params'] or L['raw_param_hits']:
        w('  params: %d parsed / %d raw @Body|@Query|@Param|@MessageBody|@Payload|@Args hits (%d method-level, e.g. '
          'GraphQL @Query(() => T); %d UNPARSED) %s\n' % (L['params'], L['raw_param_hits'], L.get('method_level_decorators', 0),
                                                         L['unparsed'], json.dumps(L['by_decorator'], sort_keys=True)))
        w('  strictNullChecks per param: %s\n' % json.dumps(L['strictNullChecks'], sort_keys=True))
        w('  buckets: %s\n' % json.dumps(L['by_bucket'], sort_keys=True))
        w('  resolution: %s%% of params bucketed (%d UNRESOLVED); named types %d, every name resolved in %s%% '
          '(%d with an UNRESOLVED name)\n' % (L['resolution_rate'], L['bucket_unresolved'], L['named_types'],
                                              L['named_resolution_rate'], L['named_unresolved']))
        if L['unresolved_reasons']:
            w('  unresolved reasons: %s\n' % json.dumps(L['unresolved_reasons'], sort_keys=True))


# ---------------------------------------------------------------- self-test
FIX = {
    'tsconfig.base.json': '{\n  // base: strict on\n  "compilerOptions": { "strict": true, /* trailing */ },\n}\n',
    'tsconfig.json': '{\n  "extends": "./tsconfig.base.json",\n  "compilerOptions": {\n    "baseUrl": ".",\n'
                     '    "paths": { "@app/*": ["src/*"], /* a comment */ "@dto": ["src/dto/index.ts"] },\n'
                     '    "outDir": "dist/*not-a-comment*/x", // the /* inside the string above is not a comment\n'
                     '  },\n}\n',
    'src/dto/item.dto.ts': 'import { IsUUID } from "class-validator";\nexport class ItemDto {\n  @IsUUID() id!: string;\n}\n',
    'src/dto/create.dto.ts': (
        "import { IsOptional, IsString, IsUUID, ValidateNested, ArrayMaxSize } from 'class-validator';\n"
        "import { Type } from 'class-transformer';\n"
        "import { ItemDto } from './item.dto.js';\n"
        "/** doctrine: always pair @ValidateNested() with @Type(() => ItemDto) */\n"
        "export class CreateDto {\n"
        "  @ValidateNested({ each: true }) @Type(() => ItemDto) @ArrayMaxSize(5)\n"
        "  items!: ItemDto[];\n"
        "  @ValidateNested()\n"
        "  child!: ItemDto;\n"
        "  @Type(() => ItemDto)\n"
        "  orders!: ItemDto[];\n"
        "  @IsString({\n    each: true,\n  })\n  @ArrayMaxSize(10)\n  tags!: string[];\n"
        "  @IsUUID('4')\n  ids!: string[];\n"
        "  @IsOptional() @IsString() name?: string;\n"
        "  @IsOptional() @IsString() note?: string | null;\n"
        "  handler = (x: number) => {\n    return x;\n  };\n"
        "  @Type(() => Number) n!: number;\n"
        "  label = '@Type(() => ItemDto) @ValidateNested()';\n"
        "}\n"
        "export class Wrapper<T> { data!: T; }\n"),
    'src/dto/thing.ts': 'export class Thing {}\nexport default class DefaultDto {}\n',
    'src/dto/index.ts': "export * from './create.dto';\nexport { Thing as AliasDto } from './thing';\n"
                        "export { default as DefaultDto } from './thing';\n",
    'src/types.ts': ('export interface IFoo { a: string }\nexport type TAlias = { a: string };\n'
                     'export type Ids = string[];\nexport enum Color { Red, Green }\n'
                     "export enum Mode { A = 'a', B = 'b' }\n"
                     "export const KINDS = ['a', 'b'] as const;\nexport type Kind = (typeof KINDS)[number];\n"),
    'src/items.controller.ts': (
        "import { Body, Controller, Get, HttpCode, Param, Patch, Post, Put, Query, Res } from '@nestjs/common';\n"
        "import type { Response } from 'express';\n"
        "import { CreateDto, AliasDto, Wrapper } from '@app/dto';\n"
        "import DefaultDto from './dto/thing';\n"
        "import * as ns from './dto/create.dto.js';\n"
        "import { z } from 'zod';\nconst Q = z.object({ a: z.string() });\n"
        "import { IFoo, TAlias, Ids, Color, Kind } from './types';\n"
        "import { Missing } from '@scope/absent-package';\n"
        "const RE = /\\/\\/@Body\\(\\)/g;\n"
        "// @Body() dto: Fake  <- a comment, never a row\n"
        "const S = '@Body() fake: Fake';\n"
        "const T = `x ${'@Query() qq: Q'} y`;\n"
        "@Controller('items')\n"
        "export class ItemsController {\n"
        "  @Post()\n  create(@Body() dto: CreateDto) { return dto; }\n"
        "  @Post('otp/verify')\n  verify(@Body() dto: AliasDto | null) { return 1; }\n"
        "  @Post('checkout')\n  checkout(@Body() dto: ns.CreateDto) { return 1; }\n"
        "  @Post('parties/:id/delete-check') @HttpCode(200)\n  dc(@Param('id') id: string) { return 1; }\n"
        "  @Post('raw')\n  raw(@Res() res: Response) { res.send(); }\n"
        "  @Get(':id')\n  get(@Param('id') id: string, @Query() q: Partial<CreateDto>): Promise<CreateDto | null> {\n"
        "    return null as any;\n  }\n"
        "  @Put()\n  put(@Body() body: IFoo[]) {}\n"
        "  @Patch()\n  patch(@Body() b: TAlias, @Query('ids') ids: Ids, @Query('c') c: Color) {}\n"
        "  @Post('import')\n  imp(\n    @Body()\n    dto: DefaultDto,\n  ) {}\n"
        "  @Post('g')\n  g(@Body() dto: Wrapper<CreateDto>, @Body('x') x: Missing, @Body('y') y: NotDeclaredAnywhere) {}\n"
        "  @Post('u')\n  u(@Body() untyped, @Body() both: CreateDto | AliasDto, @Body() inline: { a: string }) {}\n"
        "  @Get('k/:kind')\n  k(@Param('kind') kind: Kind): Promise<{ url: string | null }> { return null as any; }\n"
        "  @Get('z')\n  zz(@Query() zq: z.infer<typeof Q>) {}\n"
        "}\n"),
}

WANT = [  # (kind, at-suffix, field, expected substring)
    ('PARAM', 'items.controller.ts:17', 'bucket', 'class'),
    ('PARAM', 'items.controller.ts:17', 'resolved', 'class CreateDto@'),
    ('PARAM', 'items.controller.ts:19', 'bucket', 'union-nullable(class)'),
    ('PARAM', 'items.controller.ts:19', 'metatype', 'Object'),
    ('PARAM', 'items.controller.ts:19', 'resolved', 'class Thing@'),
    ('PARAM', 'items.controller.ts:21', 'resolved', 'class CreateDto@'),
    ('PARAM', 'items.controller.ts:23', 'bucket', 'primitive'),
    ('PARAM', 'items.controller.ts:23', 'name', 'id'),
    ('PARAM', 'items.controller.ts:27', 'bucket', 'mapped'),
    ('PARAM', 'items.controller.ts:31', 'bucket', 'array'),
    ('PARAM', 'items.controller.ts:31', 'resolved', 'interface IFoo@'),
    ('PARAM', 'items.controller.ts:33', 'bucket', 'type-alias'),
    ('PARAM', 'items.controller.ts:33', 'metatype', 'Object'),
    ('PARAM', 'items.controller.ts:36', 'resolved', 'class DefaultDto@'),
    ('PARAM', 'items.controller.ts:40', 'bucket', 'class'),
    ('PARAM', 'items.controller.ts:40', 'metatype', 'Wrapper'),
    ('PARAM', 'items.controller.ts:42', 'bucket', 'untyped'),
    ('HANDLER', 'items.controller.ts:16', 'flags', 'post-no-httpcode'),
    ('HANDLER', 'items.controller.ts:18', 'flags', 'action=verify@verify'),
    ('HANDLER', 'items.controller.ts:18', 'route', 'items/otp/verify'),
    ('HANDLER', 'items.controller.ts:22', 'flags', 'action=check@delete-check'),
    ('HANDLER', 'items.controller.ts:22', 'flags', 'httpcode=200'),
    ('HANDLER', 'items.controller.ts:24', 'flags', 'res'),
    ('HANDLER', 'items.controller.ts:26', 'flags', 'returns-nullable'),
    ('PROP', 'create.dto.ts:9', 'flags', 'validate-nested-no-type'),
    ('PROP', 'create.dto.ts:11', 'flags', 'type-no-validate-nested(child=ItemDto validators=1)'),
    ('PROP', 'create.dto.ts:18', 'flags', 'no-each(IsUUID)'),
    ('PROP', 'create.dto.ts:19', 'flags', 'optional-admits-null'),
    ('ENUM', 'types.ts:4', 'enum', 'numeric'),
    ('ENUM', 'types.ts:5', 'enum', 'string'),
]
QUIET = [  # (kind, at-suffix, field, substring that must NOT appear) — the decoys
    ('HANDLER', 'items.controller.ts:20', 'flags', 'action='),            # checkout is not "check"
    ('HANDLER', 'items.controller.ts:22', 'flags', 'post-no-httpcode'),   # has @HttpCode
    ('HANDLER', 'items.controller.ts:24', 'flags', 'post-no-httpcode'),   # has @Res
    ('PROP', 'create.dto.ts:7', 'flags', 'validate-nested-no-type'),      # paired
    ('PROP', 'create.dto.ts:7', 'flags', 'array-no-max'),
    ('PROP', 'create.dto.ts:16', 'flags', 'no-each'),                     # each: true across lines
    ('PROP', 'create.dto.ts:20', 'flags', 'optional-admits-null'),        # | null declared
    ('PROP', 'create.dto.ts:24', 'flags', 'type-no-validate-nested'),     # @Type(() => Number) is a transform
    ('HANDLER', 'items.controller.ts:43', 'flags', 'returns-nullable'),   # | null nested in an object field
]


def self_test():
    d = tempfile.mkdtemp(prefix='dto-types-')
    try:
        for rel, text in FIX.items():
            p = os.path.join(d, rel); os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, 'w', encoding='utf-8') as fh:
                fh.write(text)
        rows, ledger = scan([d], {'params', 'blocks', 'enums'})
        def find(kind, at):
            return [r for r in rows if r['kind'] == kind and r['at'].endswith(at)]
        bad, total = 0, 0
        for kind, at, field, want in WANT:
            total += 1
            got = [r.get(field, '') for r in find(kind, at)]
            ok = any(want in g for g in got)
            bad += not ok
            print('  %s %s %s %s ~ %r%s' % ('ok  ' if ok else 'FAIL', kind, at, field, want, '' if ok else ' (got %r)' % got))
        for kind, at, field, nope in QUIET:
            total += 1
            got = [r.get(field, '') for r in find(kind, at)]
            ok = bool(got) and not any(nope in g for g in got)
            bad += not ok
            print('  %s %s %s %s !~ %r%s' % ('ok  ' if ok else 'FAIL', kind, at, field, nope, '' if ok else ' (got %r)' % got))
        checks = [
            ('no row from a comment, string, template or regex',
             not any(r['kind'] == 'PARAM' and (r['param'] in ('fake', 'qq') or 'Fake' in r['type']) for r in rows)),
            ('every raw hit parsed (0 UNPARSED)', ledger['unparsed'] == 0),
            ('params counted = 19', ledger['params'] == 19),
            ('UNRESOLVED module-not-found for @scope/absent-package',
             any('module-not-found:@scope/absent-package' in r.get('resolved', '') for r in rows)),
            ('UNRESOLVED not-declared, never guessed',
             any(r.get('bucket') == 'UNRESOLVED' and 'not-declared:NotDeclaredAnywhere' in r['resolved'] for r in rows)),
            ('union of two classes -> union/Object',
             any(r.get('param') == 'both' and r['bucket'] == 'union' and r['metatype'] == 'Object' for r in rows)),
            ('inline object -> inline-object', any(r.get('param') == 'inline' and r['bucket'] == 'inline-object' for r in rows)),
            ('type Ids = string[] -> type-alias/Array',
             any(r.get('param') == 'ids' and r['bucket'] == 'type-alias' and r['metatype'] == 'Array' for r in rows)),
            ('alias of (typeof X)[number] -> metatype UNREAD, never guessed',
             any(r.get('param') == 'kind' and r['bucket'] == 'type-alias' and r['metatype'] == 'UNREAD' for r in rows)),
            ('z.infer<typeof S> -> schema-inferred, not UNRESOLVED',
             any(r.get('param') == 'zq' and r['bucket'] == 'schema-inferred' for r in rows)),
            ('numeric enum param -> enum/Number',
             any(r.get('param') == 'c' and r['bucket'] == 'enum' and r['metatype'] == 'Number' for r in rows)),
            ('strictNullChecks read through extends (on)', ledger['strictNullChecks'] == {'on': 19}),
            ('the /* inside a tsconfig string did not eat the alias table', ledger['tsconfig_notes'] == []),
            ('arrow-function property did not swallow the class', any(r['kind'] == 'PROP' and r['prop'] == 'CreateDto.n' for r in rows)),
        ]
        for name, ok in checks:
            total += 1; bad += not ok
            print('  %s %s' % ('ok  ' if ok else 'FAIL', name))
        print('dto-types --self-test: %d/%d %s' % (total - bad, total, 'OK' if not bad else 'FAIL'))
        return 0 if not bad else 3
    finally:
        shutil.rmtree(d, ignore_errors=True)


def main(argv):
    if argv == ['--self-test']:
        return self_test()
    modes, roots, as_json, flagged, tests, words = set(), [], False, False, False, ACTION_WORDS
    for a in argv:
        if a == '--params':
            modes.add('params')
        elif a == '--decorator-blocks':
            modes.add('blocks')
        elif a == '--enums':
            modes.add('enums')
        elif a == '--json':
            as_json = True
        elif a == '--flagged':
            flagged = True
        elif a == '--include-tests':
            tests = True
        elif a.startswith('--action-words='):
            words = [w for w in a.split('=', 1)[1].split(',') if w]
        elif a.startswith('-'):
            sys.stderr.write('unknown option %s\n' % a); return 2
        else:
            roots.append(a)
    if not roots or not all(os.path.exists(r) for r in roots):
        sys.stderr.write(__doc__[__doc__.index('Usage:'):__doc__.index('Modes')]); return 2
    rows, ledger = scan(roots, modes or {'params'}, tests, words)
    emit(rows, ledger, as_json, flagged)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
