#!/usr/bin/env python3
"""dto-types.py — validation-boundary-scan (and http-contract-scan § 1): NestJS param types and decorator blocks.

Why a script and not rg: "the pipe sees no class" is a two-step question — the declared type of
`@Body() dto: X`, then what X IS (class, interface, type alias, enum) after following imports, barrel
re-exports, default exports and tsconfig path aliases. "`@ValidateNested` without `@Type`" and "`@Post`
without `@HttpCode`" are properties of a decorator BLOCK that spans lines. A line grep answers neither,
and `-A<n> | rg -v` answers both wrong. Comments and string literals are masked before any match, so a
JSDoc line that mentions `@Body()` is never a row.

Usage:  python3 -I dto-types.py [--params] [--decorator-blocks] [--enums] [--routes] [--flagged] [--json]
            [--include-tests] [--action-words=a,b,...] <dir|file> ...
        python3 -I dto-types.py --self-test
Modes (default --params):
  --params            PARAM rows: every @Body/@Query/@Param (+ @MessageBody/@Payload/@Args), named or not.
                      bucket   class | interface | type-alias | enum | array | mapped (Partial/Pick/Omit/
                               Record/...) | union-nullable (X | null / undefined) | union | intersection |
                               primitive | literal | builtin (Date, Buffer) | any-unknown-object |
                               schema-inferred (z.infer<typeof S>, yup.InferType) |
                               inline-object | untyped | other | UNRESOLVED |
                               custom-pipe(<Pipe>) | custom-pipe(none) (project param decorators, below)
                      metatype what TypeScript emits as design:paramtypes for that type — the value Nest's
                               ValidationPipe reads (it validates a user class; it skips String, Boolean,
                               Number, Array, Object, Buffer, Date). X | null is Object under
                               strictNullChecks and X without it; when the tsconfig chain cannot be read the
                               column says UNREAD — never a guess.
                      Project param decorators are followed to their declaration (imports, barrels, aliases).
                      A const/function that calls Nest's Body()/Query()/Param() with a pipe —
                      `(schema) => (t, k, i) => Body(new ContractPipe(schema))(t, k, i)` — is a wrapper: its
                      params bucket custom-pipe(<Pipe>), decorator `Name>Body`, pipes `Pipe(<call args>)`;
                      a wrapper with no pipe buckets by the param's type, as @Body would. A
                      createParamDecorator whose factory reads `.body` / `.query` / `.params` buckets
                      custom-pipe(<Pipe>) when the call site passes a pipe, else custom-pipe(none), flagged
                      (ValidationPipe skips custom decorators unless validateCustomDecorators is set); one
                      that reads only `.user` is no row. The ledger lists each decorator with its count.
  --decorator-blocks  PROP rows (each decorated class property, decorators read across lines) with flags:
                        validate-nested-no-type, type-no-validate-nested(child=X validators=N),
                        initialiser(<expr>) (a property default: class-transformer applies it to an omitted
                        field, so an Update/Patch DTO resets the column — HC5c),
                        optional-admits-null (@IsOptional, type without null), no-each(<IsX>) (@Is*/@Matches/
                        @Length... on an array type without each: true), array-no-max.
                      HANDLER rows (each route method) with flags: post-no-httpcode (no @HttpCode and no
                        @Res/@Response/@Next param), res / res-passthrough, and beside either
                        res-status(<arg>) or res-no-status (does the body call <res>.status( / .code( or set
                        .statusCode — HC1b), httpcode=<arg>,
                        action=<word>@<segment> (whole path segment, or its last -/_ word),
                        returns-nullable, 204-returns(<type>).
  --enums             ENUM rows: numeric | string | mixed (for @IsEnum on numeric enums).
  --routes            Where Nest mounts each handler (the migration pack's paired route lane reads this). HANDLER
                      rows (no PROP rows unless --decorator-blocks) gain three columns: mounted (every full path:
                      URI version segment, RouterModule path, controller and method paths, then the app's
                      setGlobalPrefix unless an `exclude` entry matches the unversioned path and the method),
                      version (uri|header|media_type|custom:<v,...>, `-` when enableVersioning is absent) and
                      class_decorators (the controller's own decorators: class-level @UseGuards, @Roles, ...).
                      A prefix or versioning call applies to the files under the nearest package.json directory
                      that holds it (never above the scan root): scan the bootstrap with the controllers.
                      ENUM rows (implied) gain values: member=value (numeric members auto-increment).
                      Rules follow @nestjs/core RoutePathFactory (master, read 2026-10-18).
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
EXPORT_STAR = re.compile(r'\bexport\s*(?:type\s+)?\*\s*(?:as\s+([A-Za-z_$][\w$]*)\s*)?from\s*([\'"])')
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
    __slots__ = ('kind', 'name', 'line', 'decs', 'opt', 'type', 'mtype', 'params', 'rtype', 'init', 'body')


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
        mem.opt, mem.type, mem.mtype, mem.params, mem.rtype, mem.init, mem.body = False, '', '', [], '', '', None
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
                e = match(m, j); mem.body = (j + 1, e); j = e + 1
            out.append(mem); i = j; continue
        if i < b1 and m[i] == ':':
            k = skip_ws(m, i + 1, b1); e = scan_type(m, k, b1, ';=}', nl_ends=True)
            mem.type, mem.mtype = norm(s[k:e]), norm(m[k:e]); i = e
        if i < b1 and m[i] == '=' and m[i + 1:i + 2] != '>':
            e = scan_expr(m, i + 1, b1); mem.init = norm(s[i + 1:e]) or '?'; i = e
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
        self.customs, self.wrappers = {}, {}
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

    # project param decorators that wrap @Body/@Query with a pipe, or read the request in createParamDecorator
    def custom_param(self, src, name):
        """-> None (not a request-input decorator) | dict(via, pipe, form, at, name)."""
        key = (src.path, name)
        if key not in self.customs:
            r = self.resolve_name(src, name)
            self.customs[key] = self._wrapper_info(r[2], r[3]) if r[0] == 'ok' and r[1] == 'value' else None
        return self.customs[key]

    def _wrapper_info(self, dsrc, dstart):
        ck = (dsrc.path, dstart)
        if ck in self.wrappers:
            return self.wrappers[ck]
        mod = dsrc.mod()
        tops = sorted(v[1] for v in mod['decls'].values() if v[4] and v[1] > dstart)
        end = tops[0] if tops else len(dsrc.m)
        m, info = dsrc.m, None
        nest = {loc: imp[1] for loc, imp in mod['imports'].items()
                if imp[0].startswith('@nestjs/') and imp[1] in PARAM_DECS + ('createParamDecorator',)}
        nm = re.search(r'([A-Za-z_$][\w$]*)', m[dstart:end][len(re.match(r'\s*(?:export\s+)?(?:const|let|var|function)\s*\*?\s*', m[dstart:end]).group(0)):])
        calls = [mo for mo in re.finditer(r'(?<![@\w$.])([A-Za-z_$][\w$]*)\s*\(', m[dstart:end])
                 if nest.get(mo.group(1)) in PARAM_DECS]
        for mo in calls:
            a = dstart + mo.end() - 1
            e = match(m, a)
            args = m[a + 1:e]
            rest = re.sub(r'^\s*([\'"`])\s*\1\s*,?', '', args) if re.match(r'\s*[\'"`]', args) else args
            if not rest.strip():
                if info is None:
                    info = {'via': nest[mo.group(1)], 'pipe': None, 'form': 'wrapper'}
                continue
            pm = re.search(r'\bnew\s+([A-Za-z_$][\w$.]*)', rest) or re.search(r'\b([A-Za-z_$][\w$]*Pipe)\b', rest)
            info = {'via': nest[mo.group(1)], 'form': 'wrapper',
                    'pipe': pm.group(1) if pm else 'expr:' + norm(dsrc.s[a + 1:e])[:40]}
            break
        if info is None and any(v == 'createParamDecorator' for v in nest.values()) and \
                re.search(r'(?<![@\w$.])(%s)\s*\(' % '|'.join(re.escape(k) for k, v in nest.items()
                                                       if v == 'createParamDecorator'), m[dstart:end]):
            for prop, via in (('body', 'Body'), ('query', 'Query'), ('params', 'Param')):
                if re.search(r'\.\s*%s\b' % prop, m[dstart:end]) or \
                        re.search(r'\[\s*[\'"]%s[\'"]\s*\]' % prop, dsrc.s[dstart:end]):
                    info = {'via': via, 'pipe': None, 'form': 'createParamDecorator'}
                    break
        if info:
            info['at'] = '%s:%d' % (disp(dsrc.path), dsrc.line(dstart))
            info['name'] = nm.group(1) if nm else '?'
        self.wrappers[ck] = info
        return info

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


# ---------------------------------------------------------------- --routes: where Nest actually mounts a handler
# Order and rules follow @nestjs/core RoutePathFactory.create (master, read 2026-10-18): URI version segment,
# then the RouterModule path, the controller path, the method path; the global prefix last, unless an `exclude`
# entry matches the path WITHOUT its version segment (and the method, when the entry names one). The version is
# the method's @Version, else the controller's, else enableVersioning's defaultVersion; VERSION_NEUTRAL adds
# no segment; the URI prefix is 'v' unless `prefix` says otherwise (`false` = none). Older majors are [K?].
PREFIX_CALL = re.compile(r'\.\s*setGlobalPrefix\s*\(')
VERSIONING_CALL = re.compile(r'\.\s*enableVersioning\s*\(')
ROUTER_CALL = re.compile(r'\bRouterModule\s*\.\s*(register|forRoutes)\s*\(')
IDENT_ONLY = re.compile(r'[A-Za-z_$][\w$]*')


def top_spans(m, a, b):
    out, d, cur = [], 0, a
    for k in range(a, b):
        ch = m[k]
        if ch in '([{':
            d += 1
        elif ch in ')]}':
            d -= 1
        elif ch == ',' and d == 0:
            out.append((cur, k)); cur = k + 1
    out.append((cur, b))
    return [(i, j) for i, j in out if m[i:j].strip()]


def lit(s):
    mo = re.fullmatch(r'\s*([\'"`])((?:\\.|(?!\1).)*)\1\s*', s or '', re.S)
    return mo.group(2) if mo else None


def obj_fields(s, m):
    """Top-level `key: value` pairs of the first object literal in s (m = its masked twin, same length)."""
    b = m.find('{')
    if b < 0:
        return {}
    e, out = match(m, b), {}
    for i, j in top_spans(m, b + 1, e):
        mo = re.match(r'\s*([A-Za-z_$][\w$]*|[\'"][^\'"\n]*[\'"])\s*:', m[i:j])
        if mo:
            key = s[i:i + mo.end()].strip()[:-1].strip().strip('\'"')
            out[key] = (s[i + mo.end():j], m[i + mo.end():j])
        elif IDENT_ONLY.fullmatch(m[i:j].strip()):
            out[m[i:j].strip()] = (m[i:j], m[i:j])
    return out


def array_items(s, m):
    b = m.find('[')
    if b < 0 or m[:b].strip():
        return []
    return [(s[i:j], m[i:j]) for i, j in top_spans(m, b + 1, match(m, b))]


def versions_of(s, m):
    t = m.strip()
    if t.startswith('['):
        return [v for es, em in array_items(s, m) for v in versions_of(es, em)]
    if re.search(r'\bVERSION_NEUTRAL\b', t):
        return ['NEUTRAL']
    v = lit(s) if t[:1] in '\'"`' else None
    if v is not None:
        return [v]
    if re.fullmatch(r'\d+', t):
        return [t]
    return ['UNREAD(%s)' % norm(s)[:40]]


def excl_match(pattern, path):
    p = pattern.strip().strip('/')
    p = re.sub(r'\{\*\w*\}|\(\.\*\)|\*\w*', 'QQSTARQQ', p)
    p = re.sub(r':\w+\??', 'QQPARAMQQ', p)
    rx = re.escape(p).replace('QQSTARQQ', '.*').replace('QQPARAMQQ', '[^/]+')
    return re.fullmatch(rx + '/?', path.strip('/')) is not None


def app_root(f, roots):
    """The nearest directory holding a package.json, never above the scan root that contains f."""
    top = next((r for r in sorted(roots, key=len, reverse=True) if f == r or f.startswith(r + os.sep)), None)
    if top is None or os.path.isfile(top):
        return os.path.dirname(f) if top is None else os.path.dirname(top)
    d = os.path.dirname(f)
    while d.startswith(top) and len(d) >= len(top):
        if os.path.isfile(os.path.join(d, 'package.json')) or d == top:
            return d
        d = os.path.dirname(d)
    return top


def mount_table(world, files, roots):
    """-> {'apps': {root: cfg}, 'module_paths': {Module: [(path, at)]}, 'ctrl_modules': {Ctrl: [Module]}, 'notes': [...]}"""
    absr = [os.path.abspath(r) for r in roots]
    apps, mod_paths, ctrl_mods, notes = {}, {}, {}, []
    for f in files:
        src = world.src(f)
        m = src.m
        if 'setGlobalPrefix' in m or 'enableVersioning' in m:
            root = app_root(f, absr)
            cfg = apps.setdefault(root, {'prefix': None, 'prefix_at': [], 'exclude': [], 'versioning': None,
                                         'versioning_at': None, 'notes': []})
            for mo in PREFIX_CALL.finditer(m):
                k = mo.end() - 1; e = match(m, k); s_, m_ = src.s[k + 1:e], m[k + 1:e]
                sp = top_spans(m_, 0, len(m_))
                if not sp:
                    continue
                at = '%s:%d' % (disp(f), src.line(mo.start()))
                v = lit(s_[sp[0][0]:sp[0][1]])
                v = v.strip('/') if v is not None else 'UNREAD(%s)' % norm(s_[sp[0][0]:sp[0][1]])[:40]
                if cfg['prefix'] is not None and cfg['prefix'] != v:
                    cfg['notes'].append('two global prefixes in one app (%s, %s) — mounted shows AMBIGUOUS' % (cfg['prefix'], v))
                    v = 'AMBIGUOUS'
                cfg['prefix'] = v; cfg['prefix_at'].append(at)
                if len(sp) > 1:
                    opts = obj_fields(s_[sp[1][0]:sp[1][1]], m_[sp[1][0]:sp[1][1]])
                    if 'exclude' in opts:
                        for es, em in array_items(*opts['exclude']):
                            if em.strip().startswith('{'):
                                o = obj_fields(es, em)
                                p = lit(o['path'][0]) if 'path' in o else None
                                mm = re.search(r'RequestMethod\s*\.\s*([A-Z]+)', o['method'][1]) if 'method' in o else None
                                meth = mm.group(1) if mm else 'ALL'
                            else:
                                p, meth = lit(es), 'ALL'
                            if p is None:
                                cfg['notes'].append('exclude entry not a literal: %s' % norm(es)[:60])
                            else:
                                cfg['exclude'].append((p, meth))
            for mo in VERSIONING_CALL.finditer(m):
                k = mo.end() - 1; e = match(m, k); s_, m_ = src.s[k + 1:e], m[k + 1:e]
                o = obj_fields(s_, m_)
                tm = re.search(r'VersioningType\s*\.\s*([A-Z_]+)', o['type'][1]) if 'type' in o else None
                ver = {'type': tm.group(1) if tm else ('URI' if not m_.strip() else 'UNREAD'), 'prefix': 'v',
                       'default': None}
                if 'prefix' in o:
                    pv = o['prefix'][1].strip()
                    ver['prefix'] = '' if pv == 'false' else (lit(o['prefix'][0]) if lit(o['prefix'][0]) is not None
                                                             else 'UNREAD')
                if 'defaultVersion' in o:
                    ver['default'] = versions_of(*o['defaultVersion'])
                cfg['versioning'] = ver; cfg['versioning_at'] = '%s:%d' % (disp(f), src.line(mo.start()))
        if 'RouterModule' in m:
            for mo in ROUTER_CALL.finditer(m):
                k = mo.end() - 1; e = match(m, k); s_, m_ = src.s[k + 1:e], m[k + 1:e]
                at = '%s:%d' % (disp(f), src.line(mo.start()))
                if IDENT_ONLY.fullmatch(m_.strip()):
                    dm = re.search(r'\b(?:const|let|var)\s+%s\b[^=;]*=\s*\[' % re.escape(m_.strip()), m)
                    if not dm:
                        notes.append('RouterModule.%s(%s) at %s: routes not declared in this file — UNREAD'
                                     % (mo.group(1), m_.strip(), at)); continue
                    b = dm.end() - 1; e2 = match(m, b); s_, m_ = src.s[b:e2 + 1], m[b:e2 + 1]
                _router_walk(s_, m_, '', mod_paths, at)
        if '@' in m and 'Module' in m:
            for c in src.classes():
                d = next((x for x in c.decs if x.name == 'Module' and x.args), None)
                if d is None:
                    continue
                o = obj_fields(d.args, d.margs)
                if 'controllers' in o:
                    for es, em in array_items(*o['controllers']):
                        if IDENT_ONLY.fullmatch(em.strip()):
                            ctrl_mods.setdefault(em.strip(), []).append(c.name)
    return {'apps': apps, 'module_paths': mod_paths, 'ctrl_modules': ctrl_mods, 'notes': notes}


def _router_walk(s, m, parent, out, at):
    for es, em in array_items(s, m):
        t = em.strip()
        if t.startswith('{'):
            o = obj_fields(es, em)
            p = lit(o['path'][0]) if 'path' in o else ''
            full = join_route(parent, p if p is not None else 'UNREAD(%s)' % norm(o['path'][0])[:30])
            if 'module' in o and IDENT_ONLY.fullmatch(o['module'][1].strip()):
                out.setdefault(o['module'][1].strip(), []).append((full, at))
            if 'children' in o:
                _router_walk(o['children'][0], o['children'][1], full, out, at)
        elif IDENT_ONLY.fullmatch(t):
            out.setdefault(t, []).append((parent, at))


def mount(table, f, ctrl, cls_ver, meth_ver, verb, rel_routes):
    """-> (mounted paths, version column) for one handler."""
    fa = os.path.abspath(f)
    cfg = None
    for root in sorted(table['apps'], key=len, reverse=True):
        if fa.startswith(root + os.sep):
            cfg = table['apps'][root]; break
    mpaths = [p for mod in table['ctrl_modules'].get(ctrl, []) for p, _ in table['module_paths'].get(mod, [])] or ['']
    ver = cfg['versioning'] if cfg else None
    versions, vcol = [None], '-'
    if ver:
        vs = meth_ver or cls_ver or ver['default']
        if vs:
            vcol = '%s:%s' % (ver['type'].lower(), ','.join(vs))
            if ver['type'] == 'URI':
                versions = [None if v == 'NEUTRAL' else v for v in vs]
    out = []
    for v in versions:
        vseg = '%s%s' % (ver['prefix'], v) if v is not None else ''
        for mp in mpaths:
            for r in rel_routes:
                unversioned = join_route(mp, r)
                path = join_route(vseg, unversioned)
                pre = cfg['prefix'] if cfg else None
                if pre and not any(excl_match(p, unversioned) and meth in ('ALL', verb) for p, meth in cfg['exclude']):
                    path = join_route(pre, path)
                out.append('/' + path)
    return out, vcol


def scan(roots, modes, include_tests=False, words=ACTION_WORDS):
    t0 = time.time()
    world = World(roots)
    ROOTS_DISPLAY[:] = sorted(((os.path.abspath(r), r) for r in roots), key=lambda x: -len(x[0]))
    files = list_files(roots, include_tests)
    rows, raw, seen_params, method_level, custom_used = [], [], set(), set(), {}
    cls_index = {}
    table = mount_table(world, files, roots) if 'routes' in modes else None
    for f in files:
        src = world.src(f)
        for mo in RAW_PARAM.finditer(src.m):
            raw.append((f, src.line(mo.start()), mo.group(1)))
        if '@' not in src.m and 'enum' not in src.m:
            continue
        strict = world.strict(f)
        if 'enums' in modes or 'routes' in modes:
            for name, dcl in src.mod()['decls'].items():
                if dcl[0] == 'enum':
                    k, names = world.enum_kind(src, dcl[2])
                    row = {'kind': 'ENUM', 'at': '%s:%d' % (disp(f), src.line(dcl[1])), 'name': name,
                           'enum': k, 'members': names[:120], 'flags': '' if k == 'string' else k}
                    if 'routes' in modes:
                        row['values'] = enum_values(src, dcl[2])
                    rows.append(row)
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
                                cu = None
                                if d.name not in PARAM_DECS:
                                    cu = world.custom_param(src, d.name) if d.name[:1].isupper() else None
                                    if not cu:
                                        continue
                                    custom_used.setdefault(d.name, cu)
                                lits = literals(d.args) if d.args else []
                                named = lits[0] if lits and re.match(r'\s*[\'"`]', d.args or '') else ''
                                pipes = norm(d.args[d.args.find(',') + 1:]) if named and ',' in (d.args or '') else \
                                    (norm(d.args) if d.args and not named else '')
                                b, meta, res, certain = world.classify(src, p.mtype, strict)
                                flag = '' if b == 'class' and not meta.startswith('UNREAD') else b
                                decname = d.name
                                if cu:
                                    decname = '%s>%s' % (d.name, cu['via'])
                                    pipe = cu['pipe']
                                    if cu['form'] == 'createParamDecorator' or pipe is None or pipe.startswith('expr:'):
                                        um = re.search(r'\bnew\s+([A-Za-z_$][\w$.]*)', d.margs or '') or \
                                            re.search(r'\b([A-Za-z_$][\w$]*Pipe)\b', d.margs or '')
                                        pipe = um.group(1) if um else pipe
                                    if pipe:
                                        b, flag = 'custom-pipe(%s)' % pipe, ''
                                        pipes = '%s(%s)' % (pipe, norm(d.args or '')[:80]) if pipe == cu['pipe'] else pipes
                                    elif cu['form'] == 'createParamDecorator':
                                        b = flag = 'custom-pipe(none)'
                                    res = res + ['via %s %s@%s' % (cu['form'], cu['name'], cu['at'])]
                                seen_params.add((f, d.line))
                                rows.append({'kind': 'PARAM', 'at': '%s:%d' % (disp(f), d.line), 'decorator': decname,
                                             'name': named, 'param': p.name, 'type': p.type or '-', 'bucket': b,
                                             'metatype': meta, 'resolved': '; '.join(res) or '-', 'pipes': pipes or '-',
                                             'route': ('%s %s' % (verb, ' | '.join(routes) or '/')) if vd else '-',
                                             'handler': '%s.%s' % (c.name, mem.name), 'strict': strict,
                                             'flags': flag})
                    if vd and ('blocks' in modes or 'routes' in modes):
                        flags = []
                        hc = next((d for d in mem.decs if d.name == 'HttpCode'), None)
                        resd = [d for p in mem.params for d in p.decs if d.name in ('Res', 'Response', 'Next')]
                        if resd:
                            flags.append('res-passthrough' if all(re.search(r'passthrough\s*:\s*true', d.args or '')
                                                                  for d in resd) else 'res')
                            flags.append(res_status(src, mem))
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
                        hrow = {'kind': 'HANDLER', 'at': '%s:%d' % (disp(f), vd.line),
                                'handler': '%s.%s' % (c.name, mem.name), 'verb': verb,
                                'route': ' | '.join(routes) or '/', 'returns': mem.rtype or '-',
                                'flags': ' '.join(flags), 'decorators': dec_text(mem.decs)}
                        if table is not None:
                            cv = None
                            if ctrl is not None and ctrl.args and ctrl.margs.strip()[:1] == '{':
                                co = obj_fields(ctrl.args, ctrl.margs)
                                cv = versions_of(*co['version']) if 'version' in co else None
                            mvd = next((d for d in mem.decs if d.name == 'Version' and d.args), None)
                            mv = versions_of(mvd.args, mvd.margs) if mvd else None
                            mounted, vcol = mount(table, f, c.name, cv, mv, verb, routes or [''])
                            hrow.update({'mounted': ' | '.join(mounted), 'version': vcol,
                                         'class_decorators': dec_text(c.decs)})
                        rows.append(hrow)
                elif 'blocks' in modes and mem.decs:
                    rows.append(prop_row(world, src, c, mem, strict))
    if 'params' in modes and custom_used:
        crx = re.compile(r'@(%s)\s*\(' % '|'.join(re.escape(k) for k in sorted(custom_used)))
        for f in files:
            src = world.srcs.get(f)
            if src is not None and '@' in src.m:
                for mo in crx.finditer(src.m):
                    raw.append((f, src.line(mo.start()), mo.group(1)))
    if 'params' in modes:
        for f, ln, dn in raw:
            if (f, ln) not in seen_params and (f, ln) not in method_level:
                rows.append({'kind': 'UNPARSED', 'at': '%s:%d' % (disp(f), ln), 'decorator': dn,
                             'text': norm(world.src(f).s.split('\n')[ln - 1])[:160], 'flags': 'unparsed'})
    ledger = make_ledger(world, files, rows, raw, time.time() - t0)
    if table is not None:
        hs = [r for r in rows if r['kind'] == 'HANDLER']
        ledger['mount'] = {
            'apps': [{'root': disp(k), 'prefix': v['prefix'], 'prefix_at': v['prefix_at'],
                      'exclude': ['%s%s' % (p, '' if m_ == 'ALL' else ' ' + m_) for p, m_ in v['exclude']],
                      'versioning': v['versioning'], 'versioning_at': v['versioning_at'], 'notes': v['notes']}
                     for k, v in sorted(table['apps'].items())],
            'router_module_paths': {k: sorted({p for p, _ in v}) for k, v in sorted(table['module_paths'].items())},
            'controllers_in_modules': len(table['ctrl_modules']),
            'handlers': len(hs),
            'handlers_prefixed': sum(1 for r in hs if any(
                a['prefix'] and a['prefix'] != 'AMBIGUOUS' and x.startswith('/' + a['prefix'].strip('/') + '/')
                or x == '/' + (a['prefix'] or '').strip('/') for a in [
                    {'prefix': v['prefix']} for v in table['apps'].values()] for x in r['mounted'].split(' | '))),
            'notes': table['notes']}
    ledger['method_level_decorators'] = len(method_level)
    ledger['custom_param_decorators'] = {
        k: {'via': v['via'], 'form': v['form'], 'at': v['at'],
            'pipe': v['pipe'] or ('(at the call site)' if v['form'] == 'createParamDecorator' else 'none (global pipes only)'),
            'params': sum(1 for r in rows if r['kind'] == 'PARAM' and r['decorator'].startswith(k + '>'))}
        for k, v in sorted(custom_used.items())}
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
    if mem.init and any(VALIDATOR.match(n) for n in names):  # a DTO field; an ORM entity's default is no row
        flags.append('initialiser(%s)' % mem.init[:40].replace(' ', ''))
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


def res_status(src, mem):
    """HC1b: does a handler holding @Res/@Response set its own status in its body? res-status(<arg>) | res-no-status."""
    names = [p.name for p in mem.params if any(d.name in ('Res', 'Response') for d in p.decs) and re.fullmatch(r'[\w$]+', p.name)]
    if not mem.body or not names:
        return 'res-no-status' if mem.body else 'res-status(UNREAD)'
    body = src.m[mem.body[0]:mem.body[1]]
    hits = []
    for mo in re.finditer(r'\b(?:%s)\s*(?:\.\s*raw\s*)?\.\s*(?:status|code)\s*\(' % '|'.join(map(re.escape, names)), body):
        a = mem.body[0] + mo.end() - 1
        hits.append(norm(src.s[a + 1:match(src.m, a)])[:24] or '?')
    for mo in re.finditer(r'\b(?:%s)\s*(?:\.\s*raw\s*)?\.\s*statusCode\s*=(?!=)' % '|'.join(map(re.escape, names)), body):
        k = mem.body[0] + mo.end()
        hits.append(norm(src.s[k:scan_expr(src.m, k, mem.body[1])])[:24] or '?')
    return 'res-status(%s)' % ','.join(dict.fromkeys(h.replace(' ', '') for h in hits)) if hits else 'res-no-status'


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


def enum_values(src, dend):
    """member=value per member, read from the source text (the masked twin hides string values)."""
    m = src.m
    b = m.find('{', dend)
    if b < 0:
        return ''
    out, nxt = [], 0
    for i, j in top_spans(m, b + 1, match(m, b)):
        nm, eq, _ = m[i:j].partition('=')
        name = src.s[i:i + len(nm)].strip().strip('\'"')
        if not eq:
            out.append('%s=%s' % (name, nxt if nxt is not None else 'UNREAD')); nxt = nxt + 1 if nxt is not None else None
            continue
        raw = src.s[i + len(nm) + 1:j].strip()
        sv = lit(raw)
        if sv is not None:
            out.append('%s=%s' % (name, sv)); nxt = None
        elif re.fullmatch(r'-?\d+', raw):
            out.append('%s=%s' % (name, raw)); nxt = int(raw) + 1
        else:
            out.append('%s=expr(%s)' % (name, norm(raw)[:30])); nxt = None
    return ','.join(out)[:400]


COLS = {'PARAM': ['at', 'decorator', 'name', 'param', 'type', 'bucket', 'metatype', 'resolved', 'pipes', 'route', 'handler'],
        'PROP': ['at', 'prop', 'type', 'flags', 'decorators'],
        'HANDLER': ['at', 'handler', 'verb', 'route', 'returns', 'flags', 'decorators'],
        'ENUM': ['at', 'name', 'enum', 'members'],
        'UNPARSED': ['at', 'decorator', 'text']}


ROUTE_COLS = {'HANDLER': ['mounted', 'version', 'class_decorators'], 'ENUM': ['values']}


def emit(rows, ledger, as_json, flagged, routes=False):
    if flagged:
        rows = [r for r in rows if r.get('flags')]
    if as_json:
        json.dump({'rows': rows, 'ledger': ledger}, sys.stdout, indent=1); sys.stdout.write('\n')
    else:
        for kind in ('PARAM', 'HANDLER', 'PROP', 'ENUM', 'UNPARSED'):
            ks = [r for r in rows if r['kind'] == kind]
            if ks:
                cols = COLS[kind] + (ROUTE_COLS.get(kind, []) if routes else [])
                print('# %s\t%s' % (kind, '\t'.join(cols)))
                for r in ks:
                    print('\t'.join([kind] + [str(r.get(c, '')) if r.get(c, '') != '' else '-' for c in cols]))
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
          'GraphQL @Query(() => T); %d UNPARSED; custom decorators included) %s\n' % (L['params'], L['raw_param_hits'], L.get('method_level_decorators', 0),
                                                         L['unparsed'], json.dumps(L['by_decorator'], sort_keys=True)))
        for k, v in sorted(L.get('custom_param_decorators', {}).items()):
            w('  custom param decorator: @%s -> @%s through %s (%s at %s): %d params\n'
              % (k, v['via'], v['pipe'], v['form'], v['at'], v['params']))
        w('  strictNullChecks per param: %s\n' % json.dumps(L['strictNullChecks'], sort_keys=True))
        w('  buckets: %s\n' % json.dumps(L['by_bucket'], sort_keys=True))
        w('  resolution: %s%% of params bucketed (%d UNRESOLVED); named types %d, every name resolved in %s%% '
          '(%d with an UNRESOLVED name)\n' % (L['resolution_rate'], L['bucket_unresolved'], L['named_types'],
                                              L['named_resolution_rate'], L['named_unresolved']))
        if L['unresolved_reasons']:
            w('  unresolved reasons: %s\n' % json.dumps(L['unresolved_reasons'], sort_keys=True))
    if 'mount' in L:
        M = L['mount']
        if not M['apps']:
            w('  mount: no setGlobalPrefix / enableVersioning call in the scanned files — routes are mounted as written '
              '(scan the bootstrap too, or the prefix is UNREAD)\n')
        for a in M['apps']:
            w('  mount: app %s prefix=%s%s exclude=%s versioning=%s%s\n' % (
                a['root'], a['prefix'], ' (%s)' % ', '.join(a['prefix_at']) if a['prefix_at'] else '',
                json.dumps(a['exclude']), json.dumps(a['versioning'], sort_keys=True),
                ' (%s)' % a['versioning_at'] if a['versioning_at'] else ''))
            for n in a['notes']:
                w('  mount note: %s\n' % n)
        if M['router_module_paths']:
            w('  mount: RouterModule paths %s; %d controllers listed in @Module\n'
              % (json.dumps(M['router_module_paths'], sort_keys=True), M['controllers_in_modules']))
        for n in M['notes']:
            w('  mount note: %s\n' % n)
        w('  mount: %d handlers, %d under a global prefix\n' % (M['handlers'], M['handlers_prefixed']))


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
    'src/shared/contract.pipe.ts': (
        "import { Body, createParamDecorator, type ExecutionContext, type PipeTransform, Query } from '@nestjs/common';\n"
        "export class ContractPipe implements PipeTransform {\n  constructor(readonly schema: unknown) {}\n"
        "  transform(v: unknown) { return v; }\n}\n"
        "/** wraps @Body() with the contract pipe; a comment that says Body(new FakePipe()) is not a call */\n"
        "export const ContractBody =\n  (schema: unknown): ParameterDecorator =>\n  (target, key, index) => {\n"
        "    Body(new ContractPipe(schema))(target, key, index);\n  };\n"
        "export const ContractQuery = (schema: unknown): ParameterDecorator => (t, k, i) => {\n"
        "  Query(new ContractPipe(schema))(t, k, i);\n};\n"
        "export const PlainBody = () => Body();\n"
        "export const RawBody = createParamDecorator((_d: unknown, ctx: ExecutionContext) =>\n"
        "  ctx.switchToHttp().getRequest().body);\n"
        "export const CurrentUser = createParamDecorator((_d: unknown, ctx: ExecutionContext) =>\n"
        "  ctx.switchToHttp().getRequest().user);\n"),
    'src/shared/index.ts': "export * from './contract.pipe';\nexport type * from './wire.js';\n",
    'src/shared/wire.ts': "export type WireInput = { a: string };\n",
    'src/dto/update.dto.ts': (
        "import { IsIn, IsOptional, IsString } from 'class-validator';\n"
        "export class UpdateThingDto {\n"
        "  @IsOptional() @IsIn(['a', 'b'])\n  status?: string = 'a';\n"
        "  @IsOptional() @IsString() @Length(1, 5) title?: string;\n"
        "  @Property() count: number = 0;\n"
        "}\n"),
    'src/contract.controller.ts': (
        "import { Controller, Get, Post, Res } from '@nestjs/common';\n"
        "import type { FastifyReply } from 'fastify';\n"
        "import { ContractBody, ContractQuery, PlainBody, RawBody, CurrentUser, type WireInput } from '@app/shared';\n"
        "import { CreateDto } from '@app/dto';\n"
        "import { UpdateThingDto } from './dto/update.dto';\n"
        "type CreateInput = { a: string };\n"
        "@Controller('c')\n"
        "export class ContractController {\n"
        "  @Post()\n  create(@ContractBody(createSchema) dto: CreateInput, @CurrentUser() user: unknown) {}\n"
        "  @Get()\n  list(@ContractQuery(listSchema) q: CreateInput, @ContractBody(wireSchema) w: WireInput) {}\n"
        "  @Post('raw')\n  raw(@RawBody() r: CreateDto, @RawBody(new ParseThingPipe()) r2: CreateDto) {}\n"
        "  @Post('plain')\n  plain(@PlainBody() p: UpdateThingDto) {}\n"
        "  @Post('login')\n  login(@Res({ passthrough: true }) res: FastifyReply) {\n"
        "    res.status(200);\n    return {};\n  }\n"
        "  @Post('verify')\n  verify(@Res({ passthrough: true }) reply: FastifyReply) {\n"
        "    const status = 'res.status(500)';\n    return {};\n  }\n"
        "  @Post('refresh')\n  refresh(@Res({ passthrough: true }) res: FastifyReply) {\n"
        "    res.raw.statusCode = 202;\n    return {};\n  }\n"
        "}\n"),
    # --routes: the bootstrap, RouterModule, versioning and a second app with its own prefix
    'src/main.ts': (
        "import { NestFactory } from '@nestjs/core';\n"
        "import { RequestMethod, VersioningType } from '@nestjs/common';\n"
        "const doc = \"app.setGlobalPrefix('nope')\";\n"
        "// app.setGlobalPrefix('commented');\n"
        "async function boot() {\n  const app = await NestFactory.create(AppModule);\n"
        "  app.setGlobalPrefix('api', {\n    exclude: ['health', { path: 'status/:id', method: RequestMethod.GET },"
        " 'hooks/{*splat}'],\n  });\n"
        "  app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });\n}\n"),
    'src/app.routes.ts': (
        "import { Module } from '@nestjs/common';\nimport { RouterModule, Routes } from '@nestjs/core';\n"
        "const routes: Routes = [\n  { path: 'admin', module: AdminModule, children: [\n"
        "    { path: 'reports', module: ReportsModule },\n    AuditModule,\n  ] },\n];\n"
        "@Module({ imports: [RouterModule.register(routes)], controllers: [HealthController, StatusController, HooksController] })\n"
        "export class AppModule {}\n"
        "@Module({ controllers: [AdminUsersController] })\nexport class AdminModule {}\n"
        "@Module({ controllers: [ReportsController] })\nexport class ReportsModule {}\n"
        "@Module({ controllers: [AuditController] })\nexport class AuditModule {}\n"),
    'src/routes.controller.ts': (
        "import { Controller, Get, Post, UseGuards, Version, VERSION_NEUTRAL } from '@nestjs/common';\n"
        "@Controller('health')\nexport class HealthController {\n  @Get()\n  h() {}\n}\n"
        "@Controller('status')\nexport class StatusController {\n  @Get(':id')\n  g() {}\n  @Post(':id')\n  p() {}\n}\n"
        "@Controller('hooks')\nexport class HooksController {\n  @Post('psp')\n  psp() {}\n}\n"
        "@UseGuards(AdminGuard)\n@Roles('admin')\n@Controller({ path: 'users', version: ['1', '2'] })\n"
        "export class AdminUsersController {\n  @Get()\n  list() {}\n"
        "  @Version(VERSION_NEUTRAL)\n  @Get('ping')\n  ping() {}\n}\n"
        "@Controller('daily')\nexport class ReportsController {\n  @Get()\n  d() {}\n}\n"
        "@Controller('audit')\nexport class AuditController {\n  @Version('3')\n  @Get()\n  a() {}\n}\n"),
    'apps/admin/package.json': '{ "name": "admin" }\n',
    'apps/admin/src/main.ts': "export async function boot(app: any) {\n  app.setGlobalPrefix('/backoffice/');\n}\n",
    'apps/admin/src/x.controller.ts': (
        "import { Controller, Get } from '@nestjs/common';\n"
        "@Controller('x')\nexport class XController {\n  @Get()\n  x() {}\n}\n"),
}

ROUTE_WANT = [  # --routes: (handler, field, expected exact value)
    ('HealthController.h', 'mounted', '/v1/health'),                  # excluded from the prefix, still versioned
    ('StatusController.g', 'mounted', '/v1/status/:id'),              # exclude names GET + a :param pattern
    ('StatusController.p', 'mounted', '/api/v1/status/:id'),          # POST is not the excluded method
    ('HooksController.psp', 'mounted', '/v1/hooks/psp'),              # {*splat} wildcard exclude
    ('AdminUsersController.list', 'mounted', '/api/v1/admin/users | /api/v2/admin/users'),
    ('AdminUsersController.list', 'version', 'uri:1,2'),
    ('AdminUsersController.ping', 'mounted', '/api/admin/users/ping'),  # VERSION_NEUTRAL: no segment
    ('ReportsController.d', 'mounted', '/api/v1/admin/reports/daily'),  # RouterModule child path
    ('AuditController.a', 'mounted', '/api/v3/admin/audit'),          # bare child module inherits the parent path
    ('XController.x', 'mounted', '/backoffice/x'),                    # its own app: own prefix, no versioning
    ('XController.x', 'version', '-'),
    ('ItemsController.create', 'mounted', '/api/v1/items'),
    ('ItemsController.verify', 'route', 'items/otp/verify'),          # the relative route column is unchanged
]

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
    # project param decorators: a wrapper around Body()/Query() with a pipe, createParamDecorator over req.body
    ('PARAM', 'contract.controller.ts:10', 'bucket', 'custom-pipe(ContractPipe)'),
    ('PARAM', 'contract.controller.ts:10', 'decorator', 'ContractBody>Body'),
    ('PARAM', 'contract.controller.ts:10', 'pipes', 'ContractPipe(createSchema)'),
    ('PARAM', 'contract.controller.ts:10', 'resolved', 'via wrapper ContractBody@'),
    ('PARAM', 'contract.controller.ts:12', 'decorator', 'ContractQuery>Query'),
    ('PARAM', 'contract.controller.ts:12', 'bucket', 'custom-pipe(ContractPipe)'),
    ('PARAM', 'contract.controller.ts:14', 'flags', 'custom-pipe(none)'),
    ('PARAM', 'contract.controller.ts:14', 'bucket', 'custom-pipe(ParseThingPipe)'),
    ('PARAM', 'contract.controller.ts:16', 'decorator', 'PlainBody>Body'),
    ('PARAM', 'contract.controller.ts:16', 'bucket', 'class'),
    ('HANDLER', 'contract.controller.ts:17', 'flags', 'res-status(200)'),
    ('HANDLER', 'contract.controller.ts:22', 'flags', 'res-no-status'),
    ('HANDLER', 'contract.controller.ts:27', 'flags', 'res-status(202)'),
    ('PROP', 'update.dto.ts:4', 'flags', "initialiser('a')"),
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
    ('PARAM', 'contract.controller.ts:10', 'flags', 'custom-pipe'),       # a named pipe validates: not a flag
    ('HANDLER', 'contract.controller.ts:22', 'flags', 'res-status'),      # 'res.status(500)' is a string
    ('PROP', 'update.dto.ts:5', 'flags', 'initialiser'),
    ('PROP', 'update.dto.ts:6', 'flags', 'initialiser'),                  # an ORM default, no validator
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
            ('params counted = 25', ledger['params'] == 25),
            ('export type * re-export resolved (TS 5.0)',
             any(r.get('param') == 'w' and 'type WireInput@' in r['resolved'] for r in rows)),
            ('createParamDecorator over request.user is not a request-input row',
             not any(r['kind'] == 'PARAM' and r['param'] == 'user' for r in rows)),
            ('custom decorators ledgered with their pipe',
             ledger['custom_param_decorators'].get('ContractBody', {}).get('pipe') == 'ContractPipe'
             and ledger['custom_param_decorators'].get('RawBody', {}).get('params') == 2
             and ledger['custom_param_decorators'].get('ContractBody', {}).get('params') == 2),
            ('a comment naming Body(new FakePipe()) is not the wrapper\'s pipe',
             not any('FakePipe' in r.get('bucket', '') for r in rows)),
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
            ('strictNullChecks read through extends (on)', ledger['strictNullChecks'] == {'on': 25}),
            ('the /* inside a tsconfig string did not eat the alias table', ledger['tsconfig_notes'] == []),
            ('arrow-function property did not swallow the class', any(r['kind'] == 'PROP' and r['prop'] == 'CreateDto.n' for r in rows)),
        ]
        rrows, rledger = scan([d], {'routes'})
        for h, field, want in ROUTE_WANT:
            total += 1
            got = [r.get(field, '') for r in rrows if r['kind'] == 'HANDLER' and r['handler'] == h]
            ok = want in got
            bad += not ok
            print('  %s --routes %s %s == %r%s' % ('ok  ' if ok else 'FAIL', h, field, want, '' if ok else ' (got %r)' % got))
        def hrow(h):
            return next((r for r in rrows if r['kind'] == 'HANDLER' and r['handler'] == h), {})
        apps = {a['root'].replace(os.sep, '/').rsplit('/', 2)[-2:][-1]: a for a in rledger['mount']['apps']}
        checks += [
            ('--routes: class-level @UseGuards / @Roles on the HANDLER row',
             '@UseGuards(AdminGuard)' in hrow('AdminUsersController.list').get('class_decorators', '')
             and "@Roles('admin')" in hrow('AdminUsersController.list').get('class_decorators', '')),
            ('--routes: a prefix in a comment or a string is not read (one prefix, not AMBIGUOUS)',
             any(a['prefix'] == 'api' for a in rledger['mount']['apps'])
             and not any(a['prefix'] in ('nope', 'commented', 'AMBIGUOUS') for a in rledger['mount']['apps'])),
            ('--routes: two apps, each with its own prefix', sorted(a['prefix'] for a in rledger['mount']['apps']) == ['api', 'backoffice']),
            ('--routes: no PROP rows without --decorator-blocks', not any(r['kind'] == 'PROP' for r in rrows)),
            ('--routes: ENUM member=value, numeric auto-increment',
             any(r['kind'] == 'ENUM' and r.get('values') == 'Red=0,Green=1' for r in rrows)),
            ('--routes: ENUM member=value, string values read from the source text',
             any(r['kind'] == 'ENUM' and r.get('values') == 'A=a,B=b' for r in rrows)),
            ('--routes: RouterModule paths ledgered',
             rledger['mount']['router_module_paths'].get('ReportsModule') == ['admin/reports']
             and rledger['mount']['router_module_paths'].get('AuditModule') == ['admin']),
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
        elif a == '--routes':
            modes.add('routes')
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
    emit(rows, ledger, as_json, flagged, 'routes' in modes)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
