"""lanes_node.py — NestJS lanes for pair-inventory.py (V2 side of the program's port; also a Nest V1).

Routes, params and decorator blocks come from the backend pack's dto-types.py (called, never copied:
`python3 -I -B dto-types.py --params --decorator-blocks --enums --json .`, plus `--routes` when that build has
it). dto-types.py does not apply three things this module needs; when its output lacks them they are applied
here, and the ledger says which side did it:
  1. the global prefix (`setGlobalPrefix('v1', { exclude: [...] })`), URI versioning and RouterModule paths;
  2. CLASS-level decorators (`@UseGuards`, metadata decorators above `export class`);
  3. enum VALUES (dto-types ENUM rows carry member names only).
Lanes: I-ROUTES (HANDLER rows + 1), I-AUTHZ (APP_GUARD / useGlobalGuards, class + method @UseGuards, metadata
decorators found through their SetMetadata / Reflector.createDecorator / applyDecorators definitions, @Public
opt-out), I-RULES (class-validator PROP blocks followed through @ValidateNested; zod schemas found through the
pipe argument or z.infer<typeof S>; global trim / empty->null pipes), I-ENUM (TS enums with values, string
union types, z.enum, MikroORM @Enum / TypeORM enum columns), I-ERR (ValidationPipe status / exceptionFactory,
custom HttpException subclasses, @Catch filters, auth-guard 401 vs 403), I-SIDE (MikroORM / TypeORM subscribers
and lifecycle hooks, @OnEvent, handlers + one hop: call shapes, not words), I-SCHED (@Cron / @Interval,
BullMQ repeat / upsertJobScheduler, k8s CronJob), I-SCHEMA (database schema-map.py: MikroORM snapshot
+ replay, or the DDL lane), I-SCOPE (MikroORM @Filter default:true, config filters,
TypeORM @DeleteDateColumn), I-MONEY and I-CONF (partial).
Cannot see: routes registered on the raw adapter (fastify.get), dynamic modules that compute paths, guards
bound through a custom provider token, filters resolved at runtime, CronExpression members not derivable from
their name ('?').
"""
import json, os, re, subprocess, sys

STACKS = ('nest',)
PARTIAL = {('nest', 'I-MONEY'), ('nest', 'I-CONF')}
GAPS = {}
HERE = os.path.dirname(os.path.abspath(__file__))
DT_PATHS = [os.path.join(HERE, '..', '..', 'validation-boundary-scan', 'scripts', 'dto-types.py'),
            os.path.join(HERE, '..', '..', '..', '..', 'backend', 'skills', 'validation-boundary-scan', 'scripts', 'dto-types.py')]
ENUM_STRIP = ('enum', 'choices', 'type', 'schema')
NEST_EXC = {'BadRequest': '400', 'Unauthorized': '401', 'Forbidden': '403', 'NotFound': '404', 'MethodNotAllowed': '405',
            'NotAcceptable': '406', 'RequestTimeout': '408', 'Conflict': '409', 'Gone': '410', 'PreconditionFailed': '412',
            'PayloadTooLarge': '413', 'UnsupportedMediaType': '415', 'ImATeapot': '418', 'UnprocessableEntity': '422',
            'InternalServerError': '500', 'NotImplemented': '501', 'BadGateway': '502', 'ServiceUnavailable': '503',
            'GatewayTimeout': '504', 'HttpVersionNotSupported': '505'}
HTTP_STATUS = {'BAD_REQUEST': '400', 'UNAUTHORIZED': '401', 'PAYMENT_REQUIRED': '402', 'FORBIDDEN': '403', 'NOT_FOUND': '404',
               'METHOD_NOT_ALLOWED': '405', 'CONFLICT': '409', 'GONE': '410', 'PRECONDITION_FAILED': '412',
               'PAYLOAD_TOO_LARGE': '413', 'UNSUPPORTED_MEDIA_TYPE': '415', 'UNPROCESSABLE_ENTITY': '422', 'LOCKED': '423',
               'TOO_MANY_REQUESTS': '429', 'INTERNAL_SERVER_ERROR': '500', 'BAD_GATEWAY': '502',
               'SERVICE_UNAVAILABLE': '503', 'GATEWAY_TIMEOUT': '504'}
AUTHISH = re.compile(r'(?i)auth|jwt|session|passport|api.?key|bearer|token|clerk|firebase|cognito|oidc|oauth')
ROLEISH = re.compile(r'(?i)role|perm|polic|casl|abilit|access.?control')
THROTTLE = re.compile(r'(?i)throttl|rate.?limit')
CAT = [('public', re.compile(r'(?i)public|skip.?auth|allow.?anon|anonymous|no.?auth|unauthenticated')),
       ('roles', re.compile(r'(?i)role')),
       ('abilities', re.compile(r'(?i)perm|abilit|polic|scope|\bcan\b|claim|right|privilege|action'))]
KINDS = [('mail', r'(?i)\b\w*(?:mail|mailer|email|smtp|ses|sendgrid|postmark|resend)\w*\.(?:send|sendMail|sendEmail|deliver|queue)\w*\('),
         ('notify', r'(?i)\b\w*notif\w*\.(?:send|notify|create|push|dispatch)\w*\('),
         ('event', r'(?i)\b\w*(?:eventEmitter|emitter|eventBus|events|bus)\.(?:emit|emitAsync|publish|dispatch)\(|\boutbox\w*\.(?:add|insert|create|save|push|enqueue)\w*\('),
         ('webhook', r'(?i)\bwebhook\w*\.(?:send|post|dispatch|deliver|enqueue)\w*\('),
         ('audit', r'(?i)\baudit\w*\.(?:log|record|create|write|insert|save)\w*\('),
         ('activity', r'(?i)\bactivit\w*\.(?:log|record|create)\('),
         ('search', r'(?i)\b(?!(?:url)?searchParams\b)\w*(?:search|meili|elastic|algolia|typesense|opensearch)\w*\.(?:index|add|update|upsert|delete|remove|save)(?:Documents?|Objects?)?\('),
         ('cache', r'(?i)\b\w*(?:cache|redis)\w*\.(?:del|delete|reset|invalidate|evict|unlink|clear)\(')]
HOOKS = {'afterCreate': 'created', 'afterUpdate': 'updated', 'afterDelete': 'deleted', 'afterUpsert': 'saved',
         'beforeCreate': 'creating', 'beforeUpdate': 'updating', 'beforeDelete': 'deleting', 'afterInsert': 'created',
         'afterRemove': 'deleted', 'afterSoftRemove': 'deleted', 'beforeInsert': 'creating', 'beforeRemove': 'deleting',
         'AfterCreate': 'created', 'AfterUpdate': 'updated', 'AfterDelete': 'deleted', 'AfterInsert': 'created',
         'AfterRemove': 'deleted', 'BeforeCreate': 'creating', 'BeforeUpdate': 'updating', 'BeforeDelete': 'deleting'}
MONEY = re.compile(r'(?i)price|total|tax|vat|amount|invoice|order|payment|refund|fee|discount|balance|charge|cost|'
                   r'money|currency|payout|settle|subtotal|commission|sale|pric|credit|wallet|install')
TENANT = re.compile(r'(?i)tenant|team|company|organi[sz]ation|\borg|account|workspace')


def detect(root, h):
    for rel in (['package.json'] if h.exists('package.json') else []) + h.files(['**/package.json']):
        t = h.read(rel)
        m = re.search(r'"@nestjs/core"\s*:\s*"([^"]+)"', t)
        if m:
            return {'nest': '%s @nestjs/core %s' % (rel, m.group(1))}
    return {'nest': ''}


# ---------------------------------------------------------------- TS index
class F(object):
    def __init__(self, h, rel):
        self.rel, self.t = rel, h.read(rel)
        self.m, self.sp = h.masked(rel, 'c')

    def lits(self, a, b):
        return [self.t[s + 1:e - 1] for s, e in self.sp if s >= a and e <= b]


CLASS_RE = re.compile(r'\b(?:export\s+)?(?:default\s+)?(?:abstract\s+)?class\s+(\w+)\s*(?:<[^{]*?>)?\s*'
                      r'(?:extends\s+([\w.]+)\s*(?:<[^{(]*?>)?\s*(\([^{]*?\))?)?\s*(?:implements\s+([^{]+?))?\s*\{')
METH_RE = re.compile(r'(?m)^[ \t]*(?:(?:public|private|protected|static|async|readonly|override)\s+)*'
                     r'(?!(?:if|for|while|switch|catch|return|new|await|super|this|throw|else|do|try|typeof)\b)(\w+)\s*(?:<[^>()]*>)?\s*\(')


def body_start(m, k, end, close):
    last, depth = ')', 0
    while k < end:
        c = m[k]
        if c in ' \t\r\n':
            k += 1
            continue
        if c == '<':
            depth += 1
        elif c == '>' and m[k - 1] != '=':
            depth -= 1
        elif c in '([':
            k = close(m, k) + 1
            last = ')'
            continue
        elif c == '{':
            if depth > 0 or last in ':|&,<':
                k = close(m, k) + 1
                last = '}'
                continue
            return k
        elif c in ';=' and depth <= 0:
            return -1
        last = c
        k += 1
    return -1


def decs_before(m, s, close):
    lo, cands = max(0, s - 4000), []
    for dm in re.finditer(r'@([\w.]+)\s*(\()?', m[lo:s]):
        a = lo + dm.start()
        e = close(m, lo + dm.end() - 1) + 1 if dm.group(2) else lo + dm.end()
        cands.append((a, e, dm.group(1).split('.')[-1]))   # @scoped.OwnerScoped() -> OwnerScoped
    out, cur = [], s
    for a, e, name in reversed(cands):
        if e > cur:
            continue
        if m[e:cur].strip():
            break
        out.append((a, e, name))
        cur = a
    return list(reversed(out))


def index(root, h, ctx):
    if 'ix' in ctx:
        return ctx['ix']
    ix = {'classes': {}, 'files': {}, 'enums': {}, 'byfile': {}}
    for rel in h.files(['*.ts', '*.mts', '*.cts'], excludes=[h.MIGRATIONS]):
        f = F(h, rel)
        ix['files'][rel] = f
        for mt in CLASS_RE.finditer(f.m):
            a = mt.end() - 1
            b = h.close(f.m, a)
            c = {'name': mt.group(1), 'f': f, 'a': a, 'b': b, 'start': mt.start(), 'parent': (mt.group(2) or '').split('.')[-1],
                 'pargs': mt.group(3) or '', 'impl': mt.group(4) or '', 'methods': {}, 'decs': decs_before(f.m, mt.start(), h.close)}
            pos = a + 1
            for mm in METH_RE.finditer(f.m, a + 1, b):
                if mm.start() < pos:
                    continue
                pe = h.close(f.m, mm.end() - 1)
                k = body_start(f.m, pe + 1, b, h.close)
                if k < 0:
                    continue
                e = h.close(f.m, k)
                c['methods'][mm.group(1)] = (k, e, mm.start(1), mm.end() - 1, pe)
                pos = e
            ix['classes'].setdefault(c['name'], c)
            ix['byfile'][(rel, c['name'])] = c
        mod = {'name': '<module>', 'f': f, 'a': 0, 'b': len(f.m), 'start': 0, 'parent': '', 'pargs': '', 'impl': '',
               'methods': {}, 'decs': []}
        for fm in re.finditer(r'(?m)^(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s*\*?\s*(\w+)\s*(?:<[^>()]*>)?\s*\(|'
                              r'^(?:export\s+)?const\s+(\w+)\s*(?::[^=\n]+)?=\s*(?:async\s+)?(?:\([^)]*\)|\w+)\s*(?::[^=\n]+)?=>\s*\{', f.m):
            if fm.group(1):
                pe = h.close(f.m, fm.end() - 1)
                k = body_start(f.m, pe + 1, len(f.m), h.close)
            else:
                pe, k = fm.end() - 1, fm.end() - 1
            if k >= 0:
                mod['methods'][fm.group(1) or fm.group(2)] = (k, h.close(f.m, k), fm.start(), fm.start(), pe)
        if mod['methods']:
            ix['classes'].setdefault('<module>:' + rel, mod)
        for em in re.finditer(r'\b(?:export\s+)?(?:declare\s+)?(?:const\s+)?enum\s+(\w+)\s*\{', f.m):
            a = em.end() - 1
            b = h.close(f.m, a)
            vals, names, n = [], [], -1
            for part in split_top(f.m, a + 1, b, h.close):
                pa, pb = part
                mm = re.match(r'\s*(\w+)\s*(?:=\s*(.+?))?\s*$', f.m[pa:pb], re.S)
                if not mm:
                    continue
                names.append(mm.group(1))
                lt = f.lits(pa, pb)
                if lt:
                    vals.append(lt[0])
                elif mm.group(2) and re.match(r'-?\d+$', mm.group(2).strip()):
                    n = int(mm.group(2).strip())
                    vals.append(str(n))
                else:
                    n += 1
                    vals.append(str(n))
            ix['enums'].setdefault(em.group(1), (vals, names, f, em.start()))
    ctx['ix'] = ix
    return ix


def split_top(m, a, b, close):
    out, s, k = [], a, a
    while k < b:
        c = m[k]
        if c in '([{':
            k = close(m, k) + 1
            continue
        if c == ',':
            out.append((s, k))
            s = k + 1
        k += 1
    if m[s:b].strip():
        out.append((s, b))
    return out


def providers(ix):
    """DI token -> the class a module binds to it (`{ provide: TOKENS.X, useClass: Y }`, `useFactory: (…) => new Y(…)`)."""
    if 'providers' not in ix:
        out = {}
        for f in ix['files'].values():
            for pm in re.finditer(r'\bprovide\s*:\s*([\w.]+)\s*,', f.m):
                nxt = f.m.find('provide', pm.end())
                seg = f.m[pm.end():min(nxt if nxt > 0 else len(f.m), pm.end() + 600)]
                um = re.search(r'\buse(?:Class|Existing)\s*:\s*(\w+)|\buseFactory\s*:[\s\S]*?\bnew\s+([A-Z]\w*)\s*\(', seg)
                if um:
                    out.setdefault(pm.group(1), um.group(1) or um.group(2))
        ix['providers'] = out
    return ix['providers']


def ctor_types(c, ix=None):
    """constructor parameter -> its class: the declared type, or the class a DI token binds (`@Inject(TOKENS.X)`)."""
    f, out = c['f'], {}
    ct = c['methods'].get('constructor')
    if ct:
        pv = providers(ix) if ix else {}
        for pm in re.finditer(r'(?:@Inject\(\s*([\w.]+)\s*\)\s*)?(?:private|protected|public)\s+(?:readonly\s+)?(\w+)\s*[?!]?\s*:\s*(\w+)', f.m[ct[3]:ct[4]]):
            out[pm.group(2)] = pv.get(pm.group(1)) or pm.group(3)
    return out


# ---------------------------------------------------------------- constants (IR-3)
# `@RequireAnyPermission(...RESCUE_LEVELS.view)`, `@Enum({ items: [...STAGES] })`, `z.enum(ORDER_STATUSES)`,
# `{ ...AUTH_MESSAGES.TAKEN }`: a value read through top-level consts — object members, `Object.freeze`, arrays and
# spreads, `as const` / `satisfies`, imports (relative, or a workspace package outside the root) — never guessed.
DECL_RE = re.compile(r'(?m)^(?:export\s+)?(?:declare\s+)?const\s+(\w+)\s*(?::(?:[^=;]|=>)*?)?=(?![=>])\s*')
TAIL_RE = re.compile(r'\s+(?:as\s+const|as\s+[\w.<>\[\], |]+|satisfies\s+[\w.<>\[\], |()]+)\s*$')


class Txt(object):
    """A piece of decorator text, masked, read in the context of the file it came from (for imports)."""
    def __init__(self, h, text, rel):
        self.t, self.rel = text, rel
        self.m, self.sp = h.mask_text(text, 'c')


class Consts(object):
    def __init__(self, ix, h, root):
        self.ix, self.h, self.root, self.defs, self.imps, self.extra, self.local = ix, h, root, {}, {}, {}, {}
        for f in ix['files'].values():
            self.scan(f)

    def scan_local(self, f):
        """A file outside the index (a migration): its consts and class fields (`this.<name>`), visible to it alone."""
        loc = self.local.setdefault(f.rel, {})
        for fm in re.finditer(r'(?m)^[ \t]+(?:(?:private|protected|public|static|readonly)\s+)*(\w+)\s*(?::[^=;\n]+)?=(?![=>])\s*', f.m):
            e = f.m.find(';', fm.end())
            k = fm.end()
            while k < len(f.m) and f.m[k] not in ';\n':
                k = self.h.close(f.m, k) + 1 if f.m[k] in '([{' else k + 1
            loc.setdefault('this.' + fm.group(1), (f, fm.end(), k))
        for dm in DECL_RE.finditer(f.m):
            k = dm.end()
            while k < len(f.m) and f.m[k] != ';' and not (f.m[k] == '\n' and re.match(r'\n(?:export|const|class|import)\b', f.m[k:k + 10])):
                k = self.h.close(f.m, k) + 1 if f.m[k] in '([{' else k + 1
            loc.setdefault(dm.group(1), (f, dm.end(), k))
        self.imps.setdefault(f.rel, {})

    def scan(self, f):
        for dm in DECL_RE.finditer(f.m):
            if f.m[dm.start():dm.start() + 5] in ('expor', 'const', 'decla'):   # not inside a comment or string
                a = dm.end()
                k = a
                while k < len(f.m):
                    c = f.m[k]
                    if c in '([{':
                        k = self.h.close(f.m, k) + 1
                        continue
                    if c == ';' or (c == '\n' and re.match(r'\n[ \t]*(?:export|const|let|function|import|type|interface|class|@)\b', f.m[k:k + 14])):
                        break
                    k += 1
                self.defs.setdefault(dm.group(1), []).append((f, a, k))
        imps = {}
        for im in re.finditer(r'\bimport\s*(?:type\s*)?\{([^}]*)\}\s*from\s*([\'"])([^\'"]+)\2', f.t):
            for part in im.group(1).split(','):
                pm = re.match(r'\s*(?:type\s+)?(\w+)(?:\s+as\s+(\w+))?\s*$', part)
                if pm:
                    imps[pm.group(2) or pm.group(1)] = (im.group(3), pm.group(1))
        for im in re.finditer(r'\bexport\s*(?:\*|\{([^}]*)\})\s*from\s*([\'"])([^\'"]+)\2', f.t):
            imps.setdefault('*', []).append(im.group(3)) if not im.group(1) else None
            for part in (im.group(1) or '').split(','):
                pm = re.match(r'\s*(\w+)(?:\s+as\s+(\w+))?\s*$', part)
                if pm:
                    imps[pm.group(2) or pm.group(1)] = (im.group(3), pm.group(1))
        self.imps[f.rel] = imps

    def target(self, rel, spec):
        """The file an import names: relative to the importer, or a workspace package by its name."""
        if spec.startswith('.'):
            base = os.path.normpath(os.path.join(os.path.dirname(rel), spec))
            base = re.sub(r'\.(?:m?js|jsx)$', '', base)   # ESM imports name the emitted `.js`
            for c in (base, base + '.ts', base + '.tsx', os.path.join(base, 'index.ts')):
                if c in self.ix['files'] or c in self.extra:
                    return [c]
                if c.startswith('..') and os.path.isfile(os.path.join(self.root, c)):
                    return [self.load(c)]
            return []
        return self.package(spec)

    def load(self, rel):
        if rel not in self.extra and rel not in self.ix['files']:
            f = F(self.h, rel)
            self.extra[rel] = f
            self.scan(f)
        return rel

    def package(self, spec):
        """A bare specifier a workspace package answers (pnpm-workspace.yaml / package.json workspaces, up to 3 levels
        above the root): its .ts sources, read-only. A package inside the root is already indexed."""
        if 'pkgs' not in self.__dict__:
            self.pkgs = {}
            d = os.path.abspath(self.root)
            for _ in range(4):
                globs = []
                pw = os.path.join(d, 'pnpm-workspace.yaml')
                if os.path.isfile(pw):
                    globs = re.findall(r'(?m)^\s*-\s*[\'"]?([\w./*\-]+)', open(pw, encoding='utf-8', errors='replace').read())
                pj = os.path.join(d, 'package.json')
                if not globs and os.path.isfile(pj):
                    wm = re.search(r'"workspaces"\s*:\s*(?:\{[^}]*"packages"\s*:\s*)?\[([^\]]*)\]', open(pj, encoding='utf-8', errors='replace').read())
                    globs = re.findall(r'"([^"]+)"', wm.group(1)) if wm else []
                for g in globs:
                    base = g.rstrip('/*').rstrip('/')
                    full = os.path.join(d, base)
                    for sub in ([full] if not g.endswith('*') else [os.path.join(full, x) for x in sorted(os.listdir(full))] if os.path.isdir(full) else []):
                        pk = os.path.join(sub, 'package.json')
                        if os.path.isfile(pk):
                            nm = re.search(r'"name"\s*:\s*"([^"]+)"', open(pk, encoding='utf-8', errors='replace').read())
                            if nm:
                                self.pkgs[nm.group(1)] = sub
                if globs:
                    break
                d = os.path.dirname(d)
        name = '/'.join(spec.split('/')[:2]) if spec.startswith('@') else spec.split('/')[0]
        sub = self.pkgs.get(name)
        if not sub:
            return []
        rels = []
        rr = os.path.abspath(self.root)
        for dp, dn, fn in os.walk(os.path.join(sub, 'src') if os.path.isdir(os.path.join(sub, 'src')) else sub):
            dn[:] = [x for x in dn if x not in ('node_modules', 'dist', 'build', 'test', 'tests', '__tests__')]
            for x in fn:
                if x.endswith('.ts') and not re.search(r'\.(?:spec|test|d)\.ts$', x):
                    rel = os.path.relpath(os.path.join(dp, x), rr)
                    rels.append(rel if rel in self.ix['files'] else self.load(rel))
        return rels

    def find(self, name, rel, depth=0):
        """(file, a, b) of the const `name` as seen from file `rel`: same file, its import, else the only definition."""
        if name in self.local.get(rel, {}):
            return self.local[rel][name]
        defs = self.defs.get(name, [])
        same = [d for d in defs if d[0].rel == rel]
        if same:
            return same[0]
        imp = self.imps.get(rel, {}).get(name)
        if imp and depth < 4:
            for t in self.target(rel, imp[0]):
                hit = self.find(imp[1], t, depth + 1)
                if hit:
                    return hit
        if depth and depth < 4:   # a barrel: `export * from './x'`
            for spec in self.imps.get(rel, {}).get('*', []):
                for t in self.target(rel, spec):
                    hit = self.find(name, t, depth + 1)
                    if hit:
                        return hit
        defs = self.defs.get(name, [])
        return defs[0] if len(defs) == 1 and depth == 0 else None

    def obj(self, f, a, b, d=0):
        """{key: (file, a, b)} of an object literal span (through Object.freeze / defineMessages / spreads)."""
        a, b = trim(f.m, a, b)
        om = re.match(r'(?:Object\.freeze|\w*[dD]efine\w*)\s*\(', f.m[a:b])
        if om:
            p = a + om.end() - 1
            parts = split_top(f.m, p + 1, self.h.close(f.m, p), self.h.close)
            return self.obj(f, parts[-1][0], parts[-1][1], d + 1) if parts else {}
        if f.m[a:a + 1] != '{' or d > 6:
            return {}
        out = {}
        for pa, pb in split_top(f.m, a + 1, self.h.close(f.m, a), self.h.close):
            seg = f.m[pa:pb]
            km = re.match(r'\s*([\'"]?)(\w+)\1\s*:', seg)
            sm = re.match(r'\s*\.\.\.\s*([\w.]+)', f.t[pa:pb])
            if km:
                out[km.group(2)] = (f, pa + km.end(), pb)
            elif sm:
                path = sm.group(1).split('.')
                hit = self.span(path, f.rel, d + 1)
                if hit:
                    out.update(self.obj(*hit, d=d + 1))
            elif re.match(r'\s*(\w+)\s*$', seg):
                nm = seg.strip()
                hit = self.find(nm, f.rel)
                if hit:
                    out[nm] = hit
        return out

    def span(self, path, rel, d=0):
        hit = self.find(path[0], rel)
        for k in path[1:]:
            if not hit:
                return None
            hit = self.obj(*hit, d=d + 1).get(k)
        return hit

    def values(self, f, a, b, d=0):
        """(literal values, fully resolved) of the expression [a, b) in f."""
        if d > 10:
            return [], False
        m = f.m
        a, b = trim(m, a, b)
        tm = TAIL_RE.search(m[a:b])
        while tm:
            b = a + tm.start()
            tm = TAIL_RE.search(m[a:b])
        seg = m[a:b]
        if not seg:
            return [], False
        fm = re.match(r'Object\.freeze\s*\(', seg)
        if fm:
            p = a + fm.end() - 1
            return self.values(f, p + 1, self.h.close(m, p), d + 1)
        if seg[0] in '\'"`':
            if b - a >= 2 and m[b - 1] == seg[0] and m[a + 1:b - 1].strip() == '' and not (seg[0] == '`' and '${' in f.t[a:b]):
                return [f.t[a + 1:b - 1]], True
            return [], False
        if seg[0] == '[':
            e = self.h.close(m, a)
            out, ok = [], True
            for pa, pb in split_top(m, a + 1, e, self.h.close):
                x = m[pa:pb]
                if not x.strip():
                    continue
                off = pa + len(x) - len(x.lstrip())
                if m.startswith('...', off):
                    off += 3
                v, k = self.values(f, off, pb, d + 1)
                out += v
                ok = ok and k
            return out, ok
        rv = re.search(r'\.\s*(?:reverse|slice|concat|sort)\(\s*\)\s*$', m[a:b])   # order-only calls keep the set
        if rv and m[a] == '[':
            return self.values(f, a, a + rv.start(), d + 1)
        pm = re.match(r'([A-Za-z_$][\w$]*)((?:\s*\.\s*[A-Za-z_$][\w$]*)*)\s*$', f.t[a:b])
        if pm:
            path = [pm.group(1)] + re.findall(r'\.\s*([\w$]+)', pm.group(2))
            if path[0] == 'this' and len(path) == 2:
                path = ['this.' + path[1]]
            if len(path) == 2 and path[0] in self.ix['enums']:
                v = enum_member(self.ix, '.'.join(path))
                return ([v], True) if v is not None else ([], False)
            hit = self.span(path, f.rel, d)
            if hit:
                return self.values(*hit, d=d + 1)
            if len(path) == 1 and path[0] in self.ix['enums']:
                return list(self.ix['enums'][path[0]][0]), True
        return [], False

    def args(self, h, text, rel):
        """(values, unresolved count) of every top-level argument of a decorator's argument text."""
        t = Txt(h, text, rel)
        out, bad = [], 0
        for pa, pb in split_top(t.m, 0, len(t.m), h.close):
            x = t.m[pa:pb]
            if not x.strip():
                continue
            off = pa + len(x) - len(x.lstrip())
            if t.m.startswith('...', off):
                off += 3
            v, ok = self.values(t, off, pb)
            out += v
            bad += 0 if ok else 1
        return out, bad


def trim(m, a, b):
    while a < b and m[a] in ' \t\r\n':
        a += 1
    while b > a and m[b - 1] in ' \t\r\n,;':
        b -= 1
    return a, b


def consts(root, h, ctx):
    if 'consts' not in ctx:
        ctx['consts'] = Consts(index(root, h, ctx), h, root)
    return ctx['consts']


def queue_kind(name):
    n = name.lower()
    return ('mail' if re.search(r'mail', n) else 'notify' if re.search(r'notif|sms|push', n) else
            'webhook' if 'webhook' in n else 'audit' if 'audit' in n else 'job')


# A write of one of these entities is the effect itself, whatever the call is named (V1's trigger insert, mirrored).
ENT_KINDS = [(k, re.compile(r'\b(?:new\s+|\.\s*(?:create|insert|insertMany|persist|upsert|nativeInsert)\w*\(\s*)\w*' + w + r'\w*\b'))
             for k, w in (('notify', 'Notification'), ('activity', r'(?:Activit|History)'), ('audit', 'Audit'), ('event', 'Outbox'))]


def impls(ix):
    """type name -> the classes that implement or extend it (a port's adapters)."""
    if 'impls' not in ix:
        out = {}
        for c in ix['classes'].values():
            for t in re.findall(r'\b([A-Z]\w*)', c['impl']) + ([c['parent']] if c['parent'] else []):
                out.setdefault(t, []).append(c)
        ix['impls'] = out
    return ix['impls']


def modfns(ix):
    if 'modfns' not in ix:
        out = {}
        for c in ix['classes'].values():
            if c['name'] == '<module>':
                for n in c['methods']:
                    out.setdefault(n, []).append(c)
        ix['modfns'] = out
    return ix['modfns']


def kinds(ix, c, a, b, hop=1, seen=None):
    """Effect kinds of the code [a, b) of class c: call shapes and entity writes, then `hop` more levels through
    `this.<dep>.<m>()` (the dependency's class, or every adapter of a port type), `this.<m>()` and module functions."""
    seen = set() if seen is None else seen
    if (id(c), a) in seen:
        return set()
    seen.add((id(c), a))
    seg, ks = c['f'].m[a:b], set()
    types = ctor_types(c, ix)
    for k, rx in KINDS:
        if re.search(rx, seg):
            ks.add(k)
    for k, rx in ENT_KINDS:
        if rx.search(seg):
            ks.add(k)
    for qm in re.finditer(r'\b(?:this\.)?(\w+)(?:\(\s*\))?\.add(?:Bulk)?\(\s*([\'"])?', seg):
        if types.get(qm.group(1)) == 'Queue' or re.search(r'(?i)queue', qm.group(1)):
            lt = re.match(r'[\'"]([^\'"]*)', c['f'].t[a + qm.end() - 1:a + qm.end() + 80]) if qm.group(2) else None
            ks.add(queue_kind(qm.group(1) + ' ' + (lt.group(1) if lt else '')))
    if hop:
        for cm in re.finditer(r'\bthis\.(\w+)\.(\w+)\s*\(', seg):
            t = types.get(cm.group(1), '')
            ad = impls(ix).get(t, [])
            for tc in ([ix['classes'][t]] if t in ix['classes'] else []) + (ad if len(ad) <= 3 else []):   # a port's adapters, not a generic interface's
                if cm.group(2) in tc['methods']:
                    mb = tc['methods'][cm.group(2)]
                    ks |= kinds(ix, tc, mb[0], mb[1], hop - 1, seen)
        for cm in re.finditer(r'\bthis\.(\w+)\s*\(', seg):
            if cm.group(1) in c['methods']:
                mb = c['methods'][cm.group(1)]
                ks |= kinds(ix, c, mb[0], mb[1], hop - 1, seen)
        mf = modfns(ix)
        for name in set(re.findall(r'(?<![.\w])([a-z]\w*)\s*\(', seg)):
            hits = mf.get(name, [])
            if len(hits) == 1:   # a module function by a unique name (`recordCaseMove(this.em, …)`)
                mb = hits[0]['methods'][name]
                ks |= kinds(ix, hits[0], mb[0], mb[1], hop - 1, seen)
    return ks


def dec_calls(h, text):
    """[(name, args_text, literals)] for every @Name(args) in a decorator string."""
    m, sp = h.mask_text(text, 'c')
    out = []
    for dm in re.finditer(r'@([\w.]+)\s*(\()?', m):
        e = h.close(m, dm.end() - 1) if dm.group(2) else dm.end()
        a = dm.end()
        out.append((dm.group(1).split('.')[-1], text[a:e], [text[s + 1:x - 1] for s, x in sp if s >= a and x <= e]))
    return out


# ---------------------------------------------------------------- dto-types + app config
def dto(root, h, ctx):
    if 'dt' in ctx:
        return ctx['dt']
    path = os.environ.get('PAIR_INVENTORY_DTO_TYPES') or next((p for p in DT_PATHS if os.path.isfile(p)), None)
    if not path:
        raise h.Blocked('dto-types NOT-RUN (backend pack validation-boundary-scan/scripts/dto-types.py absent)')
    with open(path, encoding='utf-8', errors='replace') as fh:
        has_routes = '--routes' in fh.read()
    cmd = [sys.executable, '-I', '-B', path, '--params', '--decorator-blocks', '--enums', '--json'] + (['--routes'] if has_routes else []) + ['.']
    p = subprocess.run(cmd, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode != 0:
        raise h.Blocked('dto-types exit %d: %s' % (p.returncode, p.stderr.decode('utf-8', 'replace').strip()[-160:]))
    try:
        rows = json.loads(p.stdout.decode('utf-8', 'replace'))['rows']
    except (ValueError, KeyError) as e:
        raise h.Blocked('dto-types output unreadable: %s' % e)
    keep = set(index(root, h, ctx)['files'])
    for r in rows:
        r['file'], _, r['line'] = r.get('at', '').lstrip('./').rpartition(':')
    rows = [r for r in rows if r['file'] in keep]
    hd = [r for r in rows if r['kind'] == 'HANDLER']
    own = {'prefix': not any('mounted' in r for r in hd), 'class': not any('class_decorators' in r for r in hd),
           'values': not any('=' in r.get('values', '') for r in rows if r['kind'] == 'ENUM')}
    ctx.setdefault('notes', []).append('dto-types %s (%s): %s' % (
        'with --routes' if has_routes else 'without --routes', os.path.relpath(path, HERE),
        '; '.join('%s applied by %s' % (k, 'lanes_node' if v else 'dto-types') for k, v in
                  (('global prefix/versioning/RouterModule', own['prefix']), ('class-level decorators', own['class']),
                   ('enum values', own['values'])))))
    ctx['dt'] = (rows, own)
    return ctx['dt']


def app_root(h, rel):
    d = os.path.dirname(rel)
    while d:
        if h.exists(os.path.join(d, 'package.json')):
            return d
        d = os.path.dirname(d)
    return ''


def config(root, h, ctx):
    if 'cfg' in ctx:
        return ctx['cfg']
    ix = index(root, h, ctx)
    apps = {}

    def app(rel):
        return apps.setdefault(app_root(h, rel), {'prefix': '', 'exclude': [], 'version': None, 'guards': [],
                                                   'pipes': [], 'filters': [], 'interceptors': [], 'router': {}})
    for rel, f in ix['files'].items():
        for gm in re.finditer(r'\bsetGlobalPrefix\s*\(', f.m):
            a = gm.end() - 1
            b = h.close(f.m, a)
            lt = f.lits(a, b)
            A = app(rel)
            A['prefix'] = lt[0] if lt else ''
            em = re.search(r'\bexclude\s*:\s*\[', f.m[a:b])
            if em:
                ea = a + em.end() - 1
                A['exclude'] = f.lits(ea, h.close(f.m, ea))
        for vm in re.finditer(r'\benableVersioning\s*\(', f.m):
            a = vm.end() - 1
            seg = f.t[a:h.close(f.m, a)]
            if 'VersioningType.URI' in seg or 'type' not in seg:
                dv = re.search(r"defaultVersion\s*:\s*['\"]([^'\"]+)", seg)
                pf = re.search(r"\bprefix\s*:\s*(false|['\"]([^'\"]*))", seg)
                app(rel)['version'] = (dv.group(1) if dv else None, '' if pf and pf.group(1) == 'false' else (pf.group(2) if pf else 'v'))
        for kind, rx in (('guards', r'useGlobalGuards'), ('pipes', r'useGlobalPipes'), ('filters', r'useGlobalFilters'),
                         ('interceptors', r'useGlobalInterceptors')):
            for um in re.finditer(r'\b%s\s*\(' % rx, f.m):
                a = um.end() - 1
                b = h.close(f.m, a)
                fn = enclosing_fn(ix, rel, um.start())
                if fn and not called(ix, fn):
                    ctx.setdefault('notes', []).append('%s at %s:%d sits in %s(), which nothing calls: not registered'
                                                       % (rx, rel, h.line(f.t, um.start()), fn))
                    continue
                spans = [(f, a, b)]
                for cm in re.finditer(r'\b(?:\w+\.)?(\w+)\s*\(\s*\)', f.m[a:b]):   # useGlobalFilters(...http.globalFilters())
                    for g, ga, gb in fn_bodies(ix, cm.group(1)):
                        spans.append((g, ga, gb))
                for g, ga, gb in spans:
                    for nm in re.finditer(r'\bnew\s+(\w+)\s*\(', g.m[ga:gb]):
                        na = ga + nm.end() - 1
                        app(rel)[kind].append((nm.group(1), g.t[na:h.close(g.m, na) + 1]))
        for pm in re.finditer(r'\bprovide\s*:\s*APP_(GUARD|PIPE|FILTER|INTERCEPTOR)\s*,\s*use(?:Class|Existing)\s*:\s*(\w+)', f.m):
            app(rel)[{'GUARD': 'guards', 'PIPE': 'pipes', 'FILTER': 'filters', 'INTERCEPTOR': 'interceptors'}[pm.group(1)]].append((pm.group(2), ''))
        for rm in re.finditer(r'\bRouterModule\.register\s*\(\s*\[', f.m):
            a = rm.end() - 1
            walk_router(f, h, a, h.close(f.m, a), '', app(rel)['router'])
    mods = {}
    for c in ix['classes'].values():
        for d in c['decs']:
            if d[2] == 'Module':
                cm = re.search(r'\bcontrollers\s*:\s*\[([^\]]*)\]', c['f'].m[d[0]:d[1]])
                if cm:
                    mods[c['name']] = re.findall(r'\w+', cm.group(1))
    for A in apps.values():
        A['ctl_prefix'] = dict((ctl, path) for mod, path in A['router'].items() for ctl in mods.get(mod, []))
    ctx['cfg'] = apps
    return apps


def walk_router(f, h, a, b, base, out):
    for pa, pb in split_top(f.m, a + 1, b, h.close):
        oa = f.m.find('{', pa, pb)
        if oa < 0:
            continue
        ob = h.close(f.m, oa)
        seg = f.m[oa:ob]
        ch = re.search(r'\bchildren\s*:\s*\[', seg)
        head_end = oa + ch.start() if ch else ob
        pm = re.search(r'\bpath\s*:\s*[\'"]', f.m[oa:head_end])
        path = f.lits(oa + pm.start(), head_end)[0] if pm else ''
        full = '/'.join(x.strip('/') for x in (base, path) if x and x.strip('/'))
        mm = re.search(r'\bmodule\s*:\s*(\w+)', f.m[oa:head_end])
        if mm:
            out[mm.group(1)] = full
        if ch:
            ca = oa + ch.end() - 1
            walk_router(f, h, ca, h.close(f.m, ca), full, out)


def enclosing_fn(ix, rel, i):
    mod = ix['classes'].get('<module>:' + rel)
    for name, (a, b, s, _, _) in (mod['methods'].items() if mod else ()):
        if a <= i <= b:
            return name
    return None


def called(ix, name):
    n = 0
    for f in ix['files'].values():
        n += len(re.findall(r'\b%s\s*\(' % re.escape(name), f.m))
        if n > 1:
            return True
    return False


def fn_bodies(ix, name):
    out = []
    for c in ix['classes'].values():
        if c['name'] == '<module>' and name in c['methods']:
            a, b = c['methods'][name][:2]
            out.append((c['f'], a, b))
    return out


def cfg_for(apps, rel):
    best = None
    for k, A in apps.items():
        if (k == '' or rel.startswith(k + '/')) and (best is None or len(k) > len(best[0])):
            best = (k, A)
    return best[1] if best else {'prefix': '', 'exclude': [], 'version': None, 'guards': [], 'pipes': [], 'filters': [],
                                 'interceptors': [], 'router': {}, 'ctl_prefix': {}}


# ---------------------------------------------------------------- routes
def routes(root, h, ctx):
    if 'routes' in ctx:
        return ctx['routes']
    ix, apps = index(root, h, ctx), config(root, h, ctx)
    rows, own = dto(root, h, ctx)
    out = []
    params = {}
    for r in rows:
        if r['kind'] == 'PARAM':
            params.setdefault(r.get('handler'), []).append(r)
    for r in rows:
        if r['kind'] != 'HANDLER' or r.get('verb', '-') in ('-', ''):
            continue
        rel, cls = r['file'], r['handler'].split('.')[0]
        f = ix['files'][rel]
        c = ix['byfile'].get((rel, cls))
        A = cfg_for(apps, rel)
        route = r.get('route', '')
        if 'UNREAD(' in route or 'AMBIGUOUS' in r.get('mounted', ''):
            h.unparse('I-ROUTES', rel, f.t, line_idx(f.t, r['line']), 'route %s %s' % (route[:50], r.get('mounted', '')[:40]))
            continue
        if own['class']:
            cdecs = [(d[2], f.t[d[0]:d[1]]) for d in (c['decs'] if c else [])]
        else:
            cdecs = [(n, '@%s(%s)' % (n, a)) for n, a, _ in dec_calls(h, r.get('class_decorators', ''))]
        if not own['prefix']:
            paths = [x.strip() for x in r['mounted'].split(' | ') if x.strip()]
        else:
            segs = []
            excluded = any(norm(x) == norm(route) or (x.endswith(('(.*)', '*')) and norm(route).startswith(norm(x.rstrip('(.*)*'))))
                           for x in A['exclude'])
            if A['prefix'] and not excluded:
                segs.append(A['prefix'])
            ver = None
            for name, txt in cdecs + [(n, '@%s(%s)' % (n, a)) for n, a, _ in dec_calls(h, r.get('decorators', ''))]:
                vm = re.search(r"(?:version\s*:\s*|^@Version\(\s*)['\"]([^'\"]+)", txt if name in ('Controller', 'Version') else '')
                if vm:
                    ver = vm.group(1)
                if name == 'Version' and 'VERSION_NEUTRAL' in txt:
                    ver = 'NEUTRAL'
            if A['version']:
                ver = ver or A['version'][0]
                if ver and ver != 'NEUTRAL':
                    segs.append(A['version'][1] + ver)
            if cls in A.get('ctl_prefix', {}):
                segs.append(A['ctl_prefix'][cls])
            paths = ['/'.join(x.strip('/') for x in segs + [route] if x and x.strip('/'))]
        verb = r['verb'].upper()
        verb = 'ANY' if verb == 'ALL' else verb
        names = re.findall(r':(\w+)', route)
        cons = []
        for p in params.get(r['handler'], []):
            if p.get('decorator') == 'Param' and p.get('name') in names:
                t = ('int' if 'ParseIntPipe' in p.get('pipes', '') else 'uuid' if 'ParseUUIDPipe' in p.get('pipes', '')
                     else 'in' if 'ParseEnumPipe' in p.get('pipes', '') else None)
                if t:
                    cons.append('%d:%s' % (names.index(p['name']) + 1, t))
        for path in paths:
            npath, opt = h.norm_path(path)
            out.append({'key': '%s %s' % (verb, npath), 'f': f, 'i': line_idx(f.t, r['line']), 'handler': r['handler'],
                        'cls': c, 'meth': r['handler'].split('.')[-1], 'cdecs': cdecs, 'mdecs': r.get('decorators', ''),
                        'opt': str(opt), 'constraint': ','.join(sorted(cons)), 'fallback': npath == '/{*}', 'app': A})
    ctx['routes'] = out
    return out


def norm(p):
    return p.strip('/').lower()


def line_idx(t, line):
    try:
        n = int(line)
    except ValueError:
        return 0
    i = 0
    for _ in range(n - 1):
        i = t.find('\n', i) + 1
        if i == 0:
            return 0
    return i


def lane_routes(root, h, ctx):
    rows = []
    for r in routes(root, h, ctx):
        at = {'handler': r['handler'], 'opt': r['opt'], 'constraint': r['constraint']}
        if r['fallback']:
            at['fallback'] = 'yes'
        rows.append(h.row(r['key'], at, r['f'].rel, r['f'].t, r['i']))
    return rows


# ---------------------------------------------------------------- authz
def meta_decorators(root, h, ctx):
    """name -> (category, [guards]) from SetMetadata / Reflector.createDecorator / applyDecorators definitions."""
    if 'meta' in ctx:
        return ctx['meta']
    ix, consts, out = index(root, h, ctx), {}, {}
    for f in ix['files'].values():
        for cm in re.finditer(r'\bconst\s+(\w+)\s*=\s*[\'"]', f.m):
            lt = f.lits(cm.end() - 1, cm.end() + 200)
            if lt:
                consts[cm.group(1)] = lt[0]
    for f in ix['files'].values():
        for dm in re.finditer(r'\b(?:export\s+)?(?:const\s+(\w+)\s*=|function\s+(\w+)\s*\()', f.m):
            name = dm.group(1) or dm.group(2)
            end = f.m.find('\n\n', dm.end())
            end = len(f.m) if end < 0 else end
            seg = f.m[dm.end():end]
            sm = re.search(r'\bSetMetadata\(\s*(\w+|[\'"])', seg)
            if not (sm or re.match(r'\s*Reflector\.createDecorator\b', seg)):
                continue
            key = (sm.group(1) if sm and sm.group(1) not in '\'"' else (f.lits(dm.end() + sm.start(), dm.end() + sm.end() + 80) or [''])[0]) if sm else name
            label = '%s %s %s' % (name, key, consts.get(key, ''))
            cat = next((c for c, rx in CAT if rx.search(label)), 'other')
            gm = re.search(r'\bUseGuards\(([^)]*)\)', seg)
            out[name] = (cat, re.findall(r'\b([A-Z]\w*)\b', gm.group(1)) if gm else [], key)
    ctx['meta'] = out
    return out


def enum_member(ix, ref):
    m = re.match(r'(\w+)\.(\w+)$', ref.strip())
    if m and m.group(1) in ix['enums']:
        vals, names, _, _ = ix['enums'][m.group(1)]
        if m.group(2) in names:
            return vals[names.index(m.group(2))]
    return None


def classify_guard(name):
    if THROTTLE.search(name):
        return None
    if ROLEISH.search(name):
        return 'role'
    return 'auth' if AUTHISH.search(name) else 'extra'


def gated_guards(root, h, ctx):
    """guard class -> the metadata keys it reads through the Reflector. A global (APP_GUARD) guard that only acts on
    routes carrying its metadata — `@RequireAccountKind` for AccountKindGuard — guards just those routes."""
    if 'gated' not in ctx:
        ix, out = index(root, h, ctx), {}
        for c in ix['classes'].values():
            if c['name'].endswith('Guard'):
                ks = re.findall(r'\breflector\s*\.\s*\w+\s*(?:<[^>()]*>)?\s*\(\s*(\w+)', c['f'].m[c['a']:c['b']])
                if ks:
                    out[c['name']] = set(ks)
        ctx['gated'] = out
    return ctx['gated']


def lane_authz(root, h, ctx):
    ix, meta, C, gated = index(root, h, ctx), meta_decorators(root, h, ctx), consts(root, h, ctx), gated_guards(root, h, ctx)
    rows, unres = [], 0
    for r in routes(root, h, ctx):
        public, roles, abil, declared, keys, bad = False, set(), set(), set(), set(), 0
        mdecs, c = r['mdecs'], r['cls']
        if c and r['meth'] in c['methods']:   # the source text: dto-types shortens long decorator strings
            ns = c['methods'][r['meth']][2]
            mm = re.search(r'(?:\b(?:public|private|protected|static|async|readonly|override)\s+)+$', c['f'].m[max(0, ns - 80):ns])
            ds = decs_before(c['f'].m, ns - (len(mm.group(0)) if mm else 0), h.close)
            if ds:
                mdecs = ' '.join(c['f'].t[a:e] for a, e, _ in ds)
        decs = dec_calls(h, ' '.join(t for _, t in r['cdecs']) + ' ' + mdecs)
        guards = []
        for n, args, lt in decs:
            if n == 'UseGuards':
                guards += re.findall(r'\b([A-Z]\w*(?:\(\s*[\'"][^\'"]*[\'"]\s*\))?)', args)
            elif n in meta or n == 'SetMetadata' or any(rx.search(n) for _, rx in CAT):
                if n not in meta and n != 'SetMetadata':   # @Permissions('x') with no definition in the tree
                    declared.add(n)
                cat, mg, key = meta.get(n, (next((c for c, rx in CAT if rx.search(lt[0] if n == 'SetMetadata' and lt else n)), 'other'), [], n))
                keys.add(key)
                guards += mg
                if n == 'SetMetadata':
                    vals = lt[1:]
                else:   # IR-3: literals, constants, object members, spreads, imported workspace constants
                    vals, b = C.args(h, args, r['f'].rel)
                    bad += b if cat in ('roles', 'abilities') else 0
                if cat == 'public':
                    public = True
                elif cat == 'roles':
                    roles |= set(v.lower() for v in vals)
                elif cat == 'abilities':
                    abil |= set(h.ability(v) for v in vals)
        glob = [g for g, _ in r['app']['guards'] if classify_guard(g) != 'extra' or g not in gated or gated[g] & keys]
        guards = glob + guards
        kinds_ = [classify_guard(g) for g in guards]
        authn = 'required' if 'auth' in kinds_ and not public else 'none'
        unres += 1 if bad else 0
        rows.append(h.row(r['key'], {'authn': authn, 'abilities': '?' if bad else ','.join(sorted(abil)), 'roles': '?' if bad and not roles else ','.join(sorted(roles)),
                                     'extra_guard': 'yes' if 'extra' in kinds_ else 'no', 'mw': ','.join(guards),
                                     'src': ('declared-by-decorator(%s)' % ','.join(sorted(declared))) if declared else 'metadata-def'},
                          r['f'].rel, r['f'].t, r['i']))
    if unres:
        h.notes.append('nest I-AUTHZ: %d route(s) with a permission argument no constant resolves: abilities=? (unread, never diffed)' % unres)
    return rows


# ---------------------------------------------------------------- rules
CV_TYPE = {'IsString': 'string', 'IsInt': 'int', 'IsNumber': 'number', 'IsNumberString': 'string', 'IsDecimal': 'string',
           'IsBoolean': 'bool', 'IsArray': 'array', 'IsObject': 'object', 'IsDate': 'date', 'IsDateString': 'date',
           'IsISO8601': 'date', 'IsEmail': None, 'IsUUID': None, 'IsUrl': None}


def cv_attrs(h, ix, decs):
    at = {'presence': 'required', 'nullable': 'no', 'type': '?', 'format': '', 'max': '', 'min': '', 'in': '', 'regex': ''}
    for n, args, lt in dec_calls(h, decs):
        nums = re.findall(r'-?\d+(?:\.\d+)?', args.replace('_', ''))
        if n == 'IsOptional':
            at['presence'], at['nullable'] = 'optional', 'yes'
        elif n == 'ValidateIf':
            at['presence'] = 'conditional'
        elif n in ('IsNotEmpty', 'ArrayNotEmpty'):
            at['min'] = at['min'] or '1'
        elif n in CV_TYPE and CV_TYPE[n]:
            at['type'] = CV_TYPE[n]
        elif n in ('IsEmail', 'IsUUID', 'IsUrl'):
            at['format'] = {'IsEmail': 'email', 'IsUUID': 'uuid', 'IsUrl': 'url'}[n]
        elif n in ('MaxLength', 'Max', 'ArrayMaxSize') and nums:
            at['max'] = nums[0]
        elif n in ('MinLength', 'Min', 'ArrayMinSize') and nums:
            at['min'] = nums[0]
        elif n == 'Length' and nums:
            at['min'] = nums[0]
            at['max'] = nums[1] if len(nums) > 1 else ''
        elif n == 'IsIn':
            at['in'] = ','.join(sorted(set(lt)))
        elif n == 'IsEnum':
            e = any_enum(ix, h, ix.setdefault('ctx', {}), args.strip(' ()'))
            at['in'] = ','.join(sorted(set(e))) if e is not None else '?'
        elif n == 'Matches':
            rm = re.search(r'/(.+)/[a-z]*', args)
            at['regex'] = rm.group(1) if rm else (lt[0] if lt else '?')
    if at['format'] and at['type'] == '?':
        at['type'] = 'string'
    return at


def cv_fields(h, ix, props, file_, cls, prefix, depth, out):
    plist = props.get((file_, cls)) or next((v for (fl, c), v in props.items() if c == cls), [])
    for p in plist:
        field = p['prop'].split('.', 1)[1]
        at = cv_attrs(h, ix, p.get('decorators', ''))
        typ = (p.get('type') or '').rstrip('?')
        arr = typ.endswith('[]') or typ.startswith('Array<')
        out.append((prefix + field, at, p))
        inner = re.sub(r'^Array<(.+)>$|\[\]$', r'\1', typ)
        if 'ValidateNested' in p.get('decorators', '') and depth < 3 and re.match(r'^\w+$', inner):
            cv_fields(h, ix, props, p['file'], inner, prefix + field + ('.*.' if arr else '.'), depth + 1, out)


def zod_index(ix, h, ctx):
    if 'zod' in ctx:
        return ctx['zod']
    out = {}
    for f in ix['files'].values():
        if 'z.' not in f.m:
            continue
        for zm in re.finditer(r'\b(?:export\s+)?const\s+(\w+)\s*(?::[^=\n]+)?=\s*(?=z\s*\.|\w+\s*\.\s*(?:extend|merge|pick|omit|partial|array)\b)', f.m):
            a = zm.end()
            k = a
            while k < len(f.m) and f.m[k] not in ';':
                if f.m[k] in '([{':
                    k = h.close(f.m, k) + 1
                    continue
                if f.m[k] == '\n' and re.match(r'\n(?:export|const|function|import|type|interface|class)\b', f.m[k:k + 12]):
                    break
                k += 1
            out.setdefault(zm.group(1), (f, a, k))
    ctx['zod'] = out
    return out


def zod_fields(h, ix, zi, f, a, b, prefix, depth, out):
    """Walk a zod expression [a,b); append (field, attrs, (f, idx)) for every object key."""
    m = f.m
    s = a + len(m[a:b]) - len(m[a:b].lstrip())
    calls, k = [], s
    rm = re.match(r'(\w+)', m[s:b])
    if rm and rm.group(1) != 'z' and rm.group(1) in zi and depth < 4:
        g, ga, gb = zi[rm.group(1)]
        rest = m[s + rm.end():b]
        if not re.match(r'\s*\.(?:array)\(', rest):
            zod_fields(h, ix, zi, g, ga, gb, prefix, depth + 1, out)   # the base, then `.extend({...})` below
            s = k = s + rm.end()
    for cm in re.finditer(r'\.\s*(\w+)\s*(\()?', m[s:b]):
        if cm.start() < k - s:
            continue
        if cm.group(2):
            ca = s + cm.end() - 1
            ce = h.close(m, ca)
            calls.append((cm.group(1), ca + 1, ce))
            k = ce + 1
        else:
            calls.append((cm.group(1), None, None))
            k = s + cm.end()
    names = [c[0] for c in calls]
    for name, ca, ce in calls:
        if name in ('object', 'strictObject', 'extend') and ca is not None:
            oa = m.find('{', ca, ce)
            if oa >= 0:
                for pa, pb in split_top(m, oa + 1, h.close(m, oa), h.close):
                    km = re.match(r'\s*([\'"]?)(\w+)\1\s*:', m[pa:pb])
                    if not km:
                        continue
                    key = km.group(2) if not km.group(1) else (f.lits(pa, pa + km.end()) or [km.group(2)])[0]
                    ea = pa + km.end()
                    at = zod_attrs(h, ix, zi, f, ea, pb)
                    out.append((prefix + key, at, (f, pa)))
                    if depth < 3:
                        sub = re.search(r'\bz\s*\.\s*(?:object|strictObject)\(|\bz\s*\.\s*array\(|^\s*(\w+)\s*(?:\.\s*array\(\))?', m[ea:pb])
                        if sub and (at['type'] in ('object', 'array')):
                            inner_a = ea
                            if at['type'] == 'array':
                                am = re.search(r'\bz\s*\.\s*array\(', m[ea:pb])
                                if am:
                                    inner_a = ea + am.end()
                                    inner_b = h.close(m, inner_a - 1)
                                    if re.match(r'\s*z\s*\.\s*(?:object|strictObject)\(|\s*[A-Z]\w*\s*[,)]?$', m[inner_a:inner_b]):
                                        zod_fields(h, ix, zi, f, inner_a, inner_b, prefix + key + '.*.', depth + 1, out)
                                    else:   # z.array(z.enum([...])): the element rule, as Laravel's `roles.*`
                                        el = zod_attrs(h, ix, zi, f, inner_a, inner_b)
                                        el['presence'] = '?'
                                        out.append((prefix + key + '.*', el, (f, inner_a)))
                                elif sub.group(1) and sub.group(1) in zi:
                                    g, ga, gb = zi[sub.group(1)]
                                    zod_fields(h, ix, zi, g, ga, gb, prefix + key + '.*.', depth + 1, out)
                            else:
                                zod_fields(h, ix, zi, f, ea, pb, prefix + key + '.', depth + 1, out)
    return out


def zod_attrs(h, ix, zi, f, a, b):
    m, t = f.m, f.t
    at = {'presence': 'required', 'nullable': 'no', 'type': '?', 'format': '', 'max': '', 'min': '', 'in': '', 'regex': ''}
    seg = m[a:b]
    rm = re.match(r'\s*(\w+)\s*(?:\.|$)', seg)
    if rm and rm.group(1) != 'z' and rm.group(1) in zi and zi[rm.group(1)][1] != a:
        g, ga, gb = zi[rm.group(1)]
        base = zod_attrs(h, ix, zi, g, ga, gb)
        at['type'] = 'array' if re.search(r'\.\s*array\(\)', seg) else base['type']
        at['in'] = base['in']
    depth0 = re.sub(r'\([^()]*\)', lambda x: '(' + ' ' * (len(x.group(0)) - 2) + ')', seg)
    base = re.search(r'\bz\s*\.\s*(?:coerce\s*\.\s*)?(\w+)\s*\(', seg)
    if base:
        n = base.group(1)
        at['type'] = {'string': 'string', 'number': 'number', 'bigint': 'number', 'boolean': 'bool', 'date': 'date',
                      'array': 'array', 'object': 'object', 'strictObject': 'object'}.get(n, at['type'])
        if n in ('enum', 'literal'):
            at['in'] = ','.join(sorted(set(zenum_values(f, h, a + base.end() - 1))))
        elif n == 'nativeEnum':
            ea = a + base.end() - 1
            e = any_enum(ix, h, ix.setdefault('ctx', {}), m[ea + 1:h.close(m, ea)].strip())
            at['in'] = ','.join(sorted(set(e))) if e is not None else '?'
    if at['type'] in ('array',) and base and base.group(1) == 'array':
        tail_a = h.close(m, a + base.end() - 1) + 1
    else:
        tail_a = a
    for cm in re.finditer(r'\.\s*(\w+)\s*\(', m[tail_a:b]):
        n = cm.group(1)
        ca = tail_a + cm.end() - 1
        args = t[ca + 1:h.close(m, ca)]
        nums = re.findall(r'-?\d+(?:\.\d+)?', args.replace('_', ''))
        if n == 'optional' or n == 'default':
            at['presence'] = 'optional'
        elif n == 'nullable':
            at['nullable'] = 'yes'
        elif n == 'nullish':
            at['presence'], at['nullable'] = 'optional', 'yes'
        elif n == 'int':
            at['type'] = 'int'
        elif n in ('email', 'uuid', 'url'):
            at['format'] = n
        elif n in ('datetime', 'date') and at['type'] == 'string':
            at['type'] = 'date'
        elif n in ('max', 'length') and nums and m[tail_a + cm.start() - 1:tail_a + cm.start()] != '':
            at['max'] = nums[0]
            if n == 'length':
                at['min'] = nums[0]
        elif n == 'min' and nums:
            at['min'] = nums[0]
        elif n == 'nonempty':
            at['min'] = '1'
        elif n == 'regex':
            rx = re.search(r'/(.+)/[a-z]*', args)
            at['regex'] = rx.group(1) if rx else '?'
    if at['format'] and at['type'] == '?':
        at['type'] = 'string'
    return at


def named_param(rt, p):
    """A named @Query/@Body param: optional (nothing rejects a missing one), int with ParseIntPipe or a
    Number()/parseInt() cast in the body, clamped by Math.min/Math.max like V1's min()/max()."""
    c, var, pipes = rt['cls'], p.get('param') or '', p.get('pipes', '')
    at = {'presence': 'optional', 'nullable': 'no', 'type': '?', 'format': '', 'max': '', 'min': '', 'in': '', 'regex': '',
          'src': 'hand-read'}
    body, i = '', rt['i']
    if c and rt['meth'] in c['methods']:
        mb = c['methods'][rt['meth']]
        body, i = c['f'].t[mb[3]:mb[1]] + c['f'].t[mb[0]:mb[1]], mb[2]
        dm = re.search(r"@\w+\(\s*['\"]%s['\"][^)]*\)\s*%s\s*(?::\s*([^=,)]+))?(?:=\s*([^,)]+))?" % (re.escape(p['name']), re.escape(var)), body)
        if dm and dm.group(2):
            at['default'] = dm.group(2).strip().strip('\'"')
        if dm and dm.group(1) and dm.group(1).strip().endswith('[]'):
            at['type'] = 'array'
    v = re.escape(var)
    if 'ParseIntPipe' in pipes or re.search(r'\b(?:Number|parseInt)\(\s*%s\s*[,)]|\+%s\b' % (v, v), body):
        at['type'] = 'int'
    elif 'ParseBoolPipe' in pipes:
        at['type'] = 'bool'
    for fn, attr in (('min', 'max'), ('max', 'min')):
        cm = re.search(r'\bMath\.%s\(\s*(?:Number|parseInt)?\(?\s*%s\s*\)?\s*,\s*(-?\d+)\s*\)' % (fn, v), body)
        if cm:   # a clamp coerces, it never rejects (V1's min()/max() the same way)
            at['clamp_' + attr] = cm.group(1)
    return at, i


def lane_rules(root, h, ctx):
    ix = index(root, h, ctx)
    rows_dt, _ = dto(root, h, ctx)
    props = {}
    for r in rows_dt:
        if r['kind'] == 'PROP':
            props.setdefault((r['file'], r['prop'].split('.')[0]), []).append(r)
    zi = zod_index(ix, h, ctx)
    by_route = dict((r['handler'], r) for r in routes(root, h, ctx))
    out = []
    for p in rows_dt:
        if p['kind'] != 'PARAM' or not re.search(r'(?:^|>)(?:Body|Query)$', p.get('decorator', '')):
            continue
        rt = by_route.get(p.get('handler'))
        if not rt:
            continue
        if p.get('name'):   # @Query('per_page') perPage = '25' — read by hand, as V1's $request->input('per_page', 25)
            at, i = named_param(rt, p)
            out.append(h.row('%s %s' % (rt['key'], p['name']), at, rt['f'].rel, rt['f'].t, i))
            continue
        fields = []
        cm = re.match(r'class (\w+)@(.+):\d+', p.get('resolved', ''))
        if p.get('bucket') == 'class' and cm:
            cv_fields(h, ix, props, cm.group(2), cm.group(1), '', 0, fields)
            fields = [(fl, at, (ix['files'].get(pr['file']), line_idx(ix['files'][pr['file']].t, pr['line']) if pr['file'] in ix['files'] else 0)) for fl, at, pr in fields]
        else:
            zm = re.search(r'\b\w*Pipe\(\s*(\w+)\s*\)', p.get('pipes', ''))
            sch = zm.group(1) if zm else None
            if not sch:
                tm = re.match(r'type (\w+)@(.+):\d+', p.get('resolved', ''))
                g = ix['files'].get(tm.group(2)) if tm else None
                im = g and re.search(r'\btype\s+%s\s*=\s*z\.(?:infer|input|output)<\s*typeof\s+(\w+)' % tm.group(1), g.t)
                sch = im.group(1) if im else None
            if sch and sch in zi:
                g, ga, gb = zi[sch]
                zod_fields(h, ix, zi, g, ga, gb, '', 0, fields)
        for field, at, (g, i) in fields:
            out.append(h.row('%s %s' % (rt['key'], field), at, g.rel if g else None, g.t if g else '', i))
    apps = config(root, h, ctx)
    for key, rx, body_rx, opt in (('trim_strings', r'(?i)trim', r'\.trim\(\)', 'trim'),
                                  ('empty_to_null', r'(?i)empty\w*null|nullify|blank\w*null', r"===?\s*''[^;\n]*null|null[^;\n]*===?\s*''|\bnull\b[^;\n]*:\s*\w+\s*===?\s*''", 'emptyToNull')):
        on, at = 'no', None
        for A in apps.values():
            for name, args in A['pipes'] + A['interceptors']:
                c = ix['classes'].get(name)
                body = c['f'].m[c['a']:c['b']] if c else ''
                if (re.search(rx, name) or re.search(body_rx, body)) and not re.search(r'\b%s\s*:\s*false' % opt, args):
                    on, at = 'yes', name
        out.append(h.row('GLOBAL ' + key, {'on': on, 'src': at or 'nest default (no global pipe)'}, None, '', 0))
    return out


# ---------------------------------------------------------------- enums
def entity_table(c):
    for d in c['decs']:
        if d[2] == 'Entity':
            txt = c['f'].t[d[0]:d[1]]
            m = re.search(r"(?:tableName|name)\s*:\s*['\"](\w+)", txt) or re.match(r"@Entity\(\s*['\"](\w+)", txt)
            return m.group(1) if m else c['name']
    return None


def snake(s):
    return re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s).lower()


def any_enum(ix, h, ctx, name):
    """Values of a TS enum, a `const X = z.enum([...])`, or a `const X = [...] as const`, by name; None if unknown."""
    if name in ix['enums']:
        return ix['enums'][name][0]
    cache = ctx.setdefault('enum_any', {})
    if name not in cache:
        cache[name] = None
        for f in ix['files'].values():
            m = re.search(r'\bconst\s+%s\s*(?::[^=]+)?=\s*(z\s*\.\s*enum\s*\(|\[)' % re.escape(name), f.m)
            if m:
                a = m.end() - 1
                cache[name] = zenum_values(f, h, a) if m.group(1) != '[' else f.lits(a, h.close(f.m, a))
                break
    return cache[name]


def zenum_values(f, h, a, C=None):
    """Literals of z.enum(<args at a>): inline, a `const X = [...] as const` it names (same file), or — through the
    resolver — an imported constant, a spread or an object member."""
    b = h.close(f.m, a)
    lt = f.lits(a, b)
    if lt:
        return lt
    im = re.match(r'\(\s*(\w+)\s*\)', f.m[a:b + 1])
    cm = im and re.search(r'\bconst\s+%s\s*(?::[^=]+)?=\s*\[' % im.group(1), f.m)
    if cm:
        ca = cm.end() - 1
        return f.lits(ca, h.close(f.m, ca))
    if C is not None:
        v, ok = C.values(f, a + 1, b)
        return v if ok else []
    return []


def lane_enum(root, h, ctx):
    ix = index(root, h, ctx)
    rows = []
    for name, (vals, names, f, i) in ix['enums'].items():
        rows.append(h.row('type:' + h.ident(name, ENUM_STRIP), {'values': ','.join(sorted(set(vals))), 'names': name}, f.rel, f.t, i))
    C = consts(root, h, ctx)
    for f in ix['files'].values():
        for um in re.finditer(r'\b(?:export\s+)?type\s+(\w+)\s*=\s*((?:\s*\|?\s*[\'"][^\'"\n]*[\'"])+)\s*;', f.t):
            lt = re.findall(r'[\'"]([^\'"\n]*)[\'"]', um.group(2))
            if len(lt) >= 2 and f.m[um.start()] == f.t[um.start()]:
                rows.append(h.row('type:' + h.ident(um.group(1), ENUM_STRIP), {'values': ','.join(sorted(set(lt))), 'names': um.group(1)}, f.rel, f.t, um.start()))
        for zm in re.finditer(r'\bconst\s+(\w+)\s*=\s*z\s*\.\s*enum\s*\(', f.m):
            a = zm.end() - 1
            rows.append(h.row('type:' + h.ident(zm.group(1), ENUM_STRIP), {'values': ','.join(sorted(set(zenum_values(f, h, a, C)))), 'names': zm.group(1)}, f.rel, f.t, zm.start()))
    for c in ix['classes'].values():
        tbl = entity_table(c)
        if not tbl:
            continue
        f = c['f']
        for em in re.finditer(r'@(Enum|Column)\s*\(', f.m[c['a']:c['b']]):
            a = c['a'] + em.end() - 1
            e = h.close(f.m, a)
            txt = f.m[a:e]
            if em.group(1) == 'Column' and not re.search(r"\benum\s*:", txt):
                continue
            pm = re.match(r'[\s\S]*?\)\s*(?:@\w+\([^)]*\)\s*)*(\w+)\s*[!?]?\s*:', f.m[a:c['b']])
            if not pm:
                continue
            ref = re.search(r'(?:=>\s*|enum\s*:\s*|items\s*:\s*(?:\(\)\s*=>\s*)?)(\w+)', txt)
            vals = (ref and any_enum(ix, h, ctx, ref.group(1))) or f.lits(a, e)
            im = re.search(r'\bitems\s*:\s*(?:\(\)\s*=>\s*)?(\[|\w+)', txt)
            if im and (not vals or im.group(1) == '['):   # (b) `items: [...STAGES]`, `items: () => IMPORTED`
                ia = a + im.start(1)
                ib = h.close(f.m, ia) + 1 if im.group(1) == '[' else a + im.end(1)
                v, ok = C.values(f, ia, ib)
                vals = v if ok else ('?' if not vals else vals)
            fn = re.search(r"fieldName\s*:\s*['\"](\w+)", f.t[a:e])
            rows.append(h.row('col:%s.%s' % (h.table(tbl), fn.group(1) if fn else snake(pm.group(1))),
                              {'values': '?' if vals == '?' else ','.join(sorted(set(vals))), 'names': ref.group(1) if ref else 'inline'}, f.rel, f.t, a))
    rows += snapshot_enums(h)
    return rows


def snapshots(h):
    """MikroORM schema snapshots (`.snapshot-<name>.json`, hidden files rg does not list) beside the migrations."""
    out = []
    for d in sorted(set(os.path.dirname(r) for r in h.files(['**/migrations/*.ts', '**/migrations/*.js'], keep=('migrations',)))):
        try:
            out += [os.path.join(d, x) for x in sorted(os.listdir(os.path.join(h.root, d))) if re.match(r'\.snapshot.*\.json$', x)]
        except OSError:
            pass
    return out


def snapshot_enums(h):
    """(a) `col:<table>.<column>` from the snapshot: `enumItems`, and single-column value CHECKs
    (`status IN ('a','b')`, `status = ANY (ARRAY['a'::text, ...])`) — the stored vocabulary V1's CHECK rows compare to."""
    rows = []
    for rel in snapshots(h):
        try:
            d = json.loads(h.read(rel))
        except ValueError:
            h.notes.append('nest I-ENUM: %s unreadable (not JSON)' % rel)
            continue
        t = h.read(rel)
        for tb in d.get('tables', []):
            tn = h.table(tb.get('name', ''))
            for cn, c in (tb.get('columns') or {}).items():
                if c.get('enumItems'):
                    i = t.find('"%s"' % cn, t.find('"name": "%s"' % tb.get('name')))
                    rows.append(h.row('col:%s.%s' % (tn, cn), {'values': ','.join(sorted(set(str(x) for x in c['enumItems']))), 'names': 'snapshot'}, rel, t, max(i, 0)))
            for ch in tb.get('checks') or []:
                ex = ch.get('expression') or ''
                cm = re.match(r'^\(*\s*\(?"?(\w+)"?\)?(?:::\w+)?\s*(?:in\s*\(|=\s*any\s*\(\s*\(?array\s*\[)(.*)$', ex, re.I | re.S)
                if cm and not re.search(r'(?i)\b(?:and|or)\b', ex) and cm.group(1) == (ch.get('columnName') or cm.group(1)):
                    vals = re.findall(r"'([^']*)'", cm.group(2))
                    if vals:
                        i = t.find('"%s"' % ch.get('name', ''))
                        rows.append(h.row('col:%s.%s' % (tn, cm.group(1)), {'values': ','.join(sorted(set(vals))), 'names': 'check:%s' % ch.get('name', '')}, rel, t, max(i, 0)))
    return rows


# ---------------------------------------------------------------- errors
def exc_status(name, txt):
    m = re.match(r'(\w+?)Exception$', name)
    if m and m.group(1) in NEST_EXC:
        return NEST_EXC[m.group(1)]
    m = re.search(r'HttpStatus\.(\w+)', txt or '')
    if m and m.group(1) in HTTP_STATUS:
        return HTTP_STATUS[m.group(1)]
    m = re.search(r'\b([45]\d\d)\b', txt or '')
    return m.group(1) if m else None


def err_key(h, name):
    base = {'NotFoundException': 'not_found', 'UnauthorizedException': 'unauthenticated', 'ForbiddenException': 'forbidden'}
    return base.get(name) or 'exc:' + h.ident(name, ('exception', 'error', 'http'))


def lane_err(root, h, ctx):
    ix, apps = index(root, h, ctx), config(root, h, ctx)
    found, src = {}, {}
    val = set()
    for A in apps.values():
        for name, args in A['pipes']:
            c = ix['classes'].get(name)
            txt = args + (c['f'].t[c['a']:c['b']] if c else '')
            if name == 'ValidationPipe' or (c and c['parent'] == 'ValidationPipe'):
                em = re.search(r'errorHttpStatusCode\s*:\s*(?:HttpStatus\.(\w+)|(\d{3}))', txt)
                fm = re.search(r'exceptionFactory[\s\S]*?new\s+(\w+Exception)\s*\(', txt)
                val.add(HTTP_STATUS.get(em.group(1), '?') if em and em.group(1) else em.group(2) if em else
                        (exc_status(fm.group(1), '') or '?') if fm else '400')
                if c:
                    src['validation'] = (c['f'], c['start'])
            elif re.search(r'(?i)zod|valid', name):
                tm = re.search(r'throw\s+new\s+(\w+)\s*\(([^;]*)', txt)
                val.add(exc_status(tm.group(1), tm.group(2)) or '?' if tm else '?')
    for c in ix['classes'].values():
        if re.search(r'(?i)zod\w*pipe', c['name']) and 'transform' in c['methods']:
            mb = c['methods']['transform']
            tm = re.search(r'throw\s+new\s+(\w+)\s*\(([^;]*)', c['f'].t[mb[0]:mb[1]])
            if tm:
                val.add(exc_status(tm.group(1), tm.group(2)) or '?')
                src.setdefault('validation', (c['f'], c['start']))
    if val:
        found['validation'] = ','.join(sorted(val))
    found['not_found'], found['forbidden'] = '404', '403'
    unauth = set()
    for c in ix['classes'].values():
        if c['name'].endswith('Guard') and classify_guard(c['name']) == 'auth':
            body = c['f'].t[c['a']:c['b']]
            unauth.add('401' if (c['parent'] == 'AuthGuard' or 'UnauthorizedException' in body) else '403')
    if unauth:
        found['unauthenticated'] = ','.join(sorted(unauth))
    for c in ix['classes'].values():
        f = c['f']
        if c['parent'] in ('HttpException',) or re.match(r'\w+Exception$', c['parent']) and c['parent'][:-9] in NEST_EXC:
            sm = re.search(r'super\s*\(([^;]*)\)', f.t[c['a']:c['b']])
            st = exc_status(c['parent'], '') if c['parent'] != 'HttpException' else exc_status('', sm.group(1).split(',')[-1] if sm else '')
            if st:
                k = err_key(h, c['name'])
                found[k], src[k] = st, (f, c['start'])
        for d in c['decs']:
            if d[2] != 'Catch' or 'catch' not in c['methods']:
                continue
            mb = c['methods']['catch']
            body = f.t[mb[0]:mb[1]]
            if re.search(r'\.getStatus\(\)|exception\.status\b', body) and not re.search(r'\.(?:status|code)\(\s*(?:\d|HttpStatus)', body):
                continue
            sm = re.search(r'\.(?:status|code)\(\s*(?:HttpStatus\.(\w+)|(\d{3}))|statusCode\s*:\s*(?:HttpStatus\.(\w+)|(\d{3}))', body)
            st = sm and (HTTP_STATUS.get(sm.group(1) or sm.group(3) or '') or sm.group(2) or sm.group(4))
            for exc in re.findall(r'\b([A-Z]\w+)\b', f.t[d[0]:d[1]].replace('@Catch', '')):
                if st and exc != 'HttpException':
                    k = err_key(h, exc)
                    found[k], src[k] = st, (f, d[0])
    # Errors that carry a machine code are keyed by it, as V1's are (`code:order_not_editable`): a parametric
    # HttpException subclass `new DomainError(409, msg, 'order_not_editable')`, or a built-in with `{ code: '…' }`.
    param = set(c['name'] for c in ix['classes'].values()
                if c['parent'] == 'HttpException' and re.search(r'super\s*\([^;]*,\s*(?!HttpStatus)[a-z]\w*\s*\)', c['f'].m[c['a']:c['b']]))
    for f in ix['files'].values():
        for nm in re.finditer(r'\bnew\s+(\w+)\s*\(', f.m):
            name, a = nm.group(1), nm.end() - 1
            args = f.t[a + 1:h.close(f.m, a)]
            code = re.search(r"\bcode\s*:\s*['\"]([\w.\-]+)['\"]", args)
            if name in param:
                st = re.match(r'\s*(?:HttpStatus\.(\w+)|(\d{3}))', args)
                st = st and (HTTP_STATUS.get(st.group(1) or '') or st.group(2))
                code = code or re.search(r",\s*['\"]([a-z][a-z0-9_.\-]*)['\"]\s*$", args)
            elif code and name.endswith('Exception'):
                st = exc_status(name, args)
            else:
                continue
            if st and code:
                k = 'code:' + code.group(1)
                found[k], src[k] = st, (f, nm.start())
    # IR-8: framework-free domain errors (`new ConflictError({ ...AUTH_MESSAGES.PHONE_TAKEN })`): the status the
    # exception filter maps the class (or its parent) to, the code from the spread catalogue entry or a `code:`
    dom = {}
    for f in ix['files'].values():
        for dm in re.finditer(r'\binstanceof\s+(\w+)\s*\)?[^;]{0,40}?\{[^{}]{0,300}?\bstatus\s*:\s*HttpStatus\.(\w+)', f.m):
            dom.setdefault(dm.group(1), HTTP_STATUS.get(dm.group(2)))
        for dm in re.finditer(r'\[\s*(\w+)\s*,\s*HttpStatus\.(\w+)\s*\]', f.m):
            dom.setdefault(dm.group(1), HTTP_STATUS.get(dm.group(2)))

    def dstatus(name, d=0):
        if name in dom and dom[name]:
            return dom[name]
        c = ix['classes'].get(name)
        return dstatus(c['parent'], d + 1) if c and c['parent'] and d < 5 else None
    if dom:
        C, n_unres = consts(root, h, ctx), 0
        for f in ix['files'].values():
            for nm in re.finditer(r'\bnew\s+(\w+(?:Error|Exception))\s*\(', f.m):
                st = dstatus(nm.group(1))
                if not st:
                    continue
                a = nm.end() - 1
                args = f.t[a + 1:h.close(f.m, a)]
                codes = re.findall(r"\bcode\s*:\s*['\"]([\w.\-]+)['\"]", args)
                for sp in re.findall(r'\.\.\.\s*([A-Z]\w*)\.(\w+)', args):
                    hit = C.find(sp[0], f.rel)
                    dm = hit and re.match(r'\s*\w*[dD]efine\w*\(\s*[\'"](\w+)[\'"]', hit[0].t[hit[1]:hit[2]])
                    if dm:
                        codes.append('%s_%s' % (dm.group(1), sp[1]))
                        continue
                    ent = C.span(list(sp) + ['code'], f.rel)
                    v = C.values(*ent)[0] if ent else []
                    codes += v
                    n_unres += 0 if v else 1
                for code in codes:
                    k = 'code:' + code
                    found.setdefault(k, st)
                    src.setdefault(k, (f, nm.start()))
        if n_unres:
            h.notes.append('nest I-ERR: %d domain-error catalogue spread(s) with no readable code' % n_unres)
    rows = []
    for k, st in sorted(found.items()):
        f, i = src.get(k, (None, 0))
        rows.append(h.row(k, {'status': st, 'src': 'custom' if f else 'framework default'}, f.rel if f else None, f.t if f else '', i))
    return rows


# ---------------------------------------------------------------- side effects
NOUN_STOP = set('activity activities mirror audit log logs story port mikro orm entity entities service use case consumer processor '
                'infrastructure repository repo subscriber recorder writer notification notifications history domain application '
                'interface module shared common event events outbox relay job jobs handler listener command commands query adapter '
                'record records trail feed'.split())


def file_noun(h, rel):
    for w in h.words(os.path.splitext(os.path.basename(rel))[0]):
        if w not in NOUN_STOP and len(w) > 1:
            return h.table(w)
    return None


def ev_key(h, name, entity=None):
    """`order.status_changed` -> `order.updated`; `product.created` -> `product.created`: the (entity, verb) of an
    event, action or method name, in V1's trigger vocabulary (created / updated / deleted)."""
    ws = h.words(name)
    if not ws:
        return None
    ent = entity or h.table(ws[0])
    rest = ws[1:] if not entity else ws
    verb = ('created' if any(re.match(r'creat|add|insert|place|regist|open|submit|issu|new', w) for w in rest) else
            'deleted' if any(re.match(r'delet|remov|purg|destroy', w) for w in rest) else 'updated')
    return '%s.%s' % (ent, verb)


def lane_side(root, h, ctx):
    ix = index(root, h, ctx)
    C = consts(root, h, ctx)
    eff = {}

    def put(key, ks, f, i):
        if ks and key:
            e = eff.setdefault(key, [set(), f, i])
            e[0] |= ks
    tables = dict((c['name'], entity_table(c)) for c in ix['classes'].values() if entity_table(c))
    # consumers: the event types a consumer / processor / listener class reads, and what it does with them
    interested = {}
    for c in ix['classes'].values():
        f = c['f']
        if c['name'] == '<module>' or not (re.search(r'(?:Consumer|Processor|Listener|Handler|Relay|Reaction)$', c['name'])
                                         or any(d[2] in ('Processor', 'EventsHandler') for d in c['decs'])):
            continue
        ck = kinds(ix, c, c['a'], c['b'], 1)
        mod = ix['classes'].get('<module>:' + f.rel)
        for n, mb in (mod['methods'].items() if mod else ()):
            ck |= kinds(ix, mod, mb[0], mb[1], 1)
        for lit in set(x for x in f.lits(0, len(f.t)) if re.match(r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$', x)):
            interested.setdefault(lit, set()).update(ck)
    for c in ix['classes'].values():
        f = c['f']
        if re.search(r'\bEventSubscriber\b|\bEntitySubscriberInterface\b', c['impl']):
            ents = []
            for gm in ('getSubscribedEntities', 'listenTo'):
                if gm in c['methods']:
                    mb = c['methods'][gm]
                    ents = re.findall(r'\b([A-Z]\w*)\b', f.m[mb[0]:mb[1]])
            ents = ents or [re.sub(r'.*<\s*(\w+)\s*>.*', r'\1', c['impl'])] if '<' in c['impl'] else ents or ['*']
            whole = kinds(ix, c, c['a'], c['b'], 1)   # a subscriber buffers in afterCreate and acts on commit
            for meth, (a, b, s_, _, _) in c['methods'].items():
                if meth in HOOKS:
                    for e in ents:
                        put('%s.%s' % (h.table(tables.get(e, e)) if e != '*' else '*', HOOKS[meth]), kinds(ix, c, a, b) | whole, f, s_)
        tbl = tables.get(c['name'])
        for meth, (a, b, s_, _, _) in c['methods'].items():
            pre = f.m[max(0, s_ - 300):s_]
            for dn in re.findall(r'@(\w+)\(', pre[pre.rfind('}') + 1 if '}' in pre else 0:]):
                if dn in HOOKS and tbl:
                    put('%s.%s' % (h.table(tbl), HOOKS[dn]), kinds(ix, c, a, b), f, s_)
            om = re.search(r"@OnEvent\(\s*['\"]([^'\"]+)['\"][^)]*\)\s*(?:@\w+\([^)]*\)\s*)*(?:public\s+|private\s+|async\s+)*$", f.t[max(0, s_ - 300):s_])
            if om:
                put('event:' + h.ident(om.group(1), ('event',)), kinds(ix, c, a, b) or {'listener'}, f, s_)
            seg = f.m[a:b]
            # outbox emits: keyed by the event's (entity, verb), carrying what its consumers do
            for em in re.finditer(r'(?i)\b\w*outbox\w*\s*\.\s*(?:emit|publish|add|enqueue|record|write|push)\w*\s*\(', seg):
                pa = a + em.end() - 1
                parts = split_top(f.m, pa + 1, h.close(f.m, pa), h.close)
                vals, ok = C.values(f, *parts[0]) if parts else ([], False)
                for v in (vals if ok else []):
                    put(ev_key(h, v), {'event'} | interested.get(v, set()), f, pa)
            # activity / audit records: keyed by the action (and the entity when the call names one)
            for am in re.finditer(r'(?i)\b\w*(activit|audit)\w*\s*\.\s*(?:record|log|create|write|append)\w*\s*\(', seg):
                pa = a + am.end() - 1
                body = f.t[pa:h.close(f.m, pa)]
                act = re.search(r"\baction\s*:\s*['\"]([\w.:\-]+)['\"]", body) or re.match(r"\(\s*['\"]([\w.:\-]+)['\"]", body)
                ent = re.search(r"\b(?:entityType|entity|subjectType|resourceType|targetType)\s*:\s*['\"](\w+)['\"]", body)
                if act and not re.search(r'\bEventSubscriber\b', c['impl']):   # a subscriber is keyed by its entity above
                    ent = h.table(ent.group(1)) if ent else None if len(h.words(act.group(1))) > 1 else file_noun(h, f.rel)
                    if ent or len(h.words(act.group(1))) > 1:
                        put(ev_key(h, act.group(1), ent), {am.group(1).lower().replace('activit', 'activity')}, f, pa)
            # entity writes of an activity / notification / audit / outbox row (mirrors, recorders): the file's entity
            wk = set(k for k, rx in ENT_KINDS if rx.search(seg))
            if wk and c['name'] == '<module>' or (wk and not re.search(r'(?:Consumer|Processor|Listener|Relay)$', c['name'])):
                lits = [x for x in f.lits(a, b) if re.match(r'^[a-z]+(?:[_.][a-z]+)+$', x)]
                noun = file_noun(h, f.rel)
                for x in (lits[:3] or [meth]):
                    put(ev_key(h, x, noun) if noun else None, wk, f, s_)
    for r in routes(root, h, ctx):
        c = r['cls']
        if c and r['meth'] in c['methods']:
            mb = c['methods'][r['meth']]
            put(r['key'], kinds(ix, c, mb[0], mb[1], 2), r['f'], r['i'])
    for table, event, kind, rel, i in h.db_objects()['effects']:   # an AFTER trigger that writes the audit row
        put('%s.%s' % (h.table(table), event), {kind}, F(h, rel), i)
    return [h.row(k, {'kinds': ','.join(sorted(v[0]))}, v[1].rel, v[1].t, v[2]) for k, v in sorted(eff.items())]


# ---------------------------------------------------------------- schedule
def cron_expr(name):
    n = name.upper()
    hm = re.match(r'EVERY_DAY_AT_(\d+)(AM|PM)$', n)
    if hm:
        hh = int(hm.group(1)) % 12 + (12 if hm.group(2) == 'PM' else 0)
        return '0 %d * * *' % hh
    for rx, fmt in ((r'EVERY_(\d+)_SECONDS$', '*/{} * * * * *'), (r'EVERY_(\d+)_MINUTES$', '*/{} * * * *'),
                    (r'EVERY_(\d+)_HOURS$', '0 */{} * * *'), (r'EVERY_(\d+)_MONTHS$', '0 0 1 */{} *'),
                    (r'MONDAY_TO_FRIDAY_AT_(\d+)AM$', '0 {} * * 1-5')):
        m = re.match(rx, n)
        if m:
            return fmt.format(m.group(1))
    return {'EVERY_SECOND': '* * * * * *', 'EVERY_MINUTE': '* * * * *', 'EVERY_HOUR': '0 * * * *',
            'EVERY_DAY_AT_MIDNIGHT': '0 0 * * *', 'EVERY_DAY_AT_NOON': '0 12 * * *', 'EVERY_WEEK': '0 0 * * 0',
            'EVERY_WEEKDAY': '0 0 * * 1-5', 'EVERY_WEEKEND': '0 0 * * 0,6', 'EVERY_1ST_DAY_OF_MONTH_AT_MIDNIGHT': '0 0 1 * *',
            'EVERY_1ST_DAY_OF_MONTH_AT_NOON': '0 12 1 * *', 'EVERY_QUARTER': '0 0 1 */3 *', 'EVERY_YEAR': '0 0 1 1 *'}.get(n, '?')


SCHED_ROLE = ('runner', 'consumer', 'processor', 'scheduler', 'service', 'cron', 'tick', 'worker')


def lane_sched(root, h, ctx):
    ix = index(root, h, ctx)
    rows = []
    for c in ix['classes'].values():
        f = c['f']
        for meth, (a, b, s, _, _) in c['methods'].items():
            pre = f.t[max(0, s - 400):s]
            cm = re.search(r'@(Cron|Interval)\(([^@]*?)\)\s*(?:@\w+\([^)]*\)\s*)*(?:public\s+|private\s+|async\s+)*$', pre)
            if not cm:
                continue
            args = cm.group(2)
            lit = re.match(r"\s*['\"]([^'\"]+)['\"]", args)
            ce = re.search(r'CronExpression\.(\w+)', args)
            expr = lit.group(1) if (lit and cm.group(1) == 'Cron') else cron_expr(ce.group(1)) if ce else '?'
            sm = re.match(r'^\s*(\d+)\s+(\S+\s+\S+\s+\S+\s+\S+\s+\S+)\s*$', expr)
            if sm:   # a fixed second offset in Nest's 6-field cron is minute granularity, as pg_cron's 5 fields
                expr = sm.group(2)
            nm = re.search(r"\bname\s*:\s*['\"]([^'\"]+)", args) or (lit if cm.group(1) == 'Interval' and lit else None)
            tz = re.search(r"timeZone\s*:\s*['\"]([^'\"]+)", args)
            body = f.m[a:b]
            ov = 'yes' if re.search(r'waitForCompletion\s*:\s*true', args) or re.search(r'(?i)\b\w*(?:lock|mutex|redlock)\w*\.(?:acquire|lock|using|run)\w*\(|advisory', body) else 'no'
            # IR-7: an unnamed job is keyed by Class.method — the bare method (`prune`) pools unrelated classes
            key = nm.group(1) if nm else '%s %s' % (c['name'], meth)
            rows.append(h.row('job:' + h.tokkey(key, h.SCHED_DROP + SCHED_ROLE),
                              {'cron': h.cron(expr) if expr != '?' else '?', 'tz': tz.group(1) if tz else '',
                               'tz_src': 'decorator' if tz else 'process', 'overlap': ov,
                               'target': '%s.%s' % (c['name'], meth)}, f.rel, f.t, s))
    for f in ix['files'].values():
        for qm in re.finditer(r"\.(?:add|upsertJobScheduler)\(\s*['\"]([^'\"]+)['\"]", f.t):
            a = f.m.find('(', qm.start())
            seg = f.t[a:h.close(f.m, a)]
            pm = re.search(r"(?:pattern|cron)\s*:\s*['\"]([^'\"]+)", seg)
            if pm and ('repeat' in seg or 'upsertJobScheduler' in qm.group(0)):
                tz = re.search(r"\btz\s*:\s*['\"]([^'\"]+)", seg)
                rows.append(h.row('job:' + h.tokkey(qm.group(1), h.SCHED_DROP), {'cron': h.cron(pm.group(1)), 'tz': tz.group(1) if tz else '',
                                                                               'overlap': 'no', 'target': 'bullmq ' + qm.group(1)}, f.rel, f.t, qm.start()))
    rows += k8s_cronjobs(h)
    return rows


def k8s_cronjobs(h):
    rows = []
    for rel in h.files(['*.yaml', '*.yml'], pattern=r'kind:\s*CronJob'):
        t = h.read(rel)
        off = 0
        for doc in re.split(r'(?m)^---\s*$', t):
            if re.search(r'(?m)^kind:\s*CronJob\b', doc) and re.search(r'\bphp\b|\bartisan\b', doc):
                h.notes.append('%s: a CronJob that runs the V1 app (php artisan) is V1 infrastructure, not a V2 job' % rel)
            elif re.search(r'(?m)^kind:\s*CronJob\b', doc):
                nm = re.search(r'(?m)^metadata:\s*\n(?:\s+.*\n)*?\s+name:\s*["\']?([\w.-]+)', doc)
                sc = re.search(r'(?m)^\s+schedule:\s*["\']?([^"\'\n#]+)', doc)
                tz = re.search(r'(?m)^\s+timeZone:\s*["\']?([^"\'\n#]+)', doc)
                ov = 'yes' if re.search(r'concurrencyPolicy:\s*["\']?Forbid', doc) else 'no'
                i = off + (sc.start() if sc else 0)
                rows.append(h.row('job:' + h.tokkey(nm.group(1) if nm else 'cronjob', h.SCHED_DROP),
                                  {'cron': h.cron(sc.group(1).strip()) if sc else '?', 'tz': tz.group(1).strip() if tz else '',
                                   'overlap': ov, 'target': 'k8s CronJob'}, rel, t, i))
            off += len(doc) + 4
    return rows


# ---------------------------------------------------------------- scopes, money, config
def rls_tables(root, h, ctx):
    """IR-5: Postgres RLS a V2's own migrations declare (MikroORM `addSql`, or `.sql`), replayed in file order over
    `up()` only: enable / FORCE / disable, and `create policy … using (<expr>)` / `drop policy`. A template table name
    (`${table}`) is read from its `for (const table of [...])` loop, a const array, or a `table = '…'` class field;
    anything else is counted unresolved. {table: {'enabled', 'forced', 'policies': {name: expr}, 'at': (rel, i)}}"""
    if 'rls' in ctx:
        return ctx['rls']
    C, out, unres = consts(root, h, ctx), {}, [0]
    files = sorted(h.files(['**/migrations/**/*.ts', '**/migrations/**/*.sql', '**/migrations/*.ts', '**/migrations/*.sql'],
                           pattern=r'(?i)row level security|create\s+policy', keep=('migrations',)), key=os.path.basename)

    def sql(rel, text, i):
        q = r'"?(\w+)"?(?:\."?(\w+)"?)?'
        for m in re.finditer(r'(?is)\balter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?' + q + r'\s+(enable|disable|force|no\s+force)\s+row\s+level\s+security', text):
            T = out.setdefault(m.group(2) or m.group(1), {'enabled': False, 'forced': False, 'policies': {}, 'at': (rel, i)})
            act = re.sub(r'\s+', ' ', m.group(3).lower())
            if act in ('enable', 'disable'):
                T['enabled'] = act == 'enable'
            else:
                T['forced'] = act == 'force'
            T['at'] = (rel, i)
        for m in re.finditer(r'(?is)\bcreate\s+policy\s+"?([^"\s]+)"?\s+on\s+' + q + r'(.*?)(?:;|$)', text):
            T = out.setdefault(m.group(3) or m.group(2), {'enabled': False, 'forced': False, 'policies': {}, 'at': (rel, i)})
            um = re.search(r'(?is)\busing\s*\((.*)\)', m.group(4))
            T['policies'][m.group(1)] = um.group(1) if um else m.group(4)
        for m in re.finditer(r'(?is)\bdrop\s+policy\s+(?:if\s+exists\s+)?"?([^"\s]+)"?\s+on\s+' + q, text):
            out.get(m.group(3) or m.group(2), {'policies': {}})['policies'].pop(m.group(1), None)

    for rel in files:
        if rel.endswith('.sql'):
            sql(rel, h.read(rel), 0)
            continue
        f = F(h, rel)
        um = re.search(r'\b(?:async\s+)?up\s*\([^)]*\)\s*(?::\s*[\w<>\s]+)?\{', f.m)
        if not um:
            continue
        ua, ub = um.end() - 1, h.close(f.m, um.end() - 1)
        C.scan_local(f)
        loops = []
        for lm in re.finditer(r'\bfor\s*(\()\s*const\s+(\w+)\s+of\s+', f.m[ua:ub]):
            pa = ua + lm.start(1)
            pe = h.close(f.m, pa)
            vals, ok = C.values(f, ua + lm.end(), pe)
            bo = f.m.find('{', pe)
            if bo > 0:
                loops.append((lm.group(2), vals if ok else None, bo, h.close(f.m, bo)))
        for sa, se in f.sp:
            if not (ua < sa < ub) or not re.search(r'(?i)row level security|policy', f.t[sa:se]):
                continue
            txt = f.t[sa + 1:se - 1]
            var = re.findall(r'\$\{\s*([\w.]+)\s*\}', txt)
            if not var:
                sql(rel, txt, sa)
                continue
            v = var[0]
            lp = next((l for l in loops if l[0] == v and l[2] < sa < l[3]), None)
            names = lp[1] if lp else (C.values(f, *C.local[rel][v][1:])[0] or None) if v in C.local.get(rel, {}) else None
            if not names:
                unres[0] += 1
                continue
            for n in names:
                sql(rel, re.sub(r'\$\{\s*%s\s*\}' % re.escape(v), n, txt), sa)
    if unres[0]:
        h.notes.append('nest I-SCOPE: %d RLS statement(s) in migrations with a computed table name (not read)' % unres[0])
    ctx['rls'] = out
    return out


def lane_scope(root, h, ctx):
    ix = index(root, h, ctx)
    C, rls = consts(root, h, ctx), rls_tables(root, h, ctx)
    glob, alias = [], {}
    for f in ix['files'].values():   # export const OwnerScoped = () => Filter({ name: 'account', ..., default: true })
        for am in re.finditer(r'\bconst\s+(\w+)\s*=\s*\([^)]*\)\s*=>\s*Filter\s*\(', f.m):
            a = am.end() - 1
            alias[am.group(1)] = '@Filter' + f.t[a:h.close(f.m, a) + 1]
    for f in ix['files'].values():
        for fm in re.finditer(r'\bfilters\s*:\s*\{', f.m):
            a = fm.end() - 1
            for km in re.finditer(r'(\w+)\s*:\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}', f.t[a:h.close(f.m, a)]):
                if re.search(r'default\s*:\s*true', km.group(2)):
                    ents = re.findall(r"['\"](\w+)['\"]", re.search(r'entity\s*:\s*(\[[^\]]*\]|[\'"]\w+[\'"])', km.group(2)).group(1)) if 'entity' in km.group(2) else ['*']
                    glob.append((km.group(1), ents))
        for am in re.finditer(r"\baddFilter\(\s*['\"](\w+)['\"]", f.t):
            seg = f.t[am.start():f.t.find(';', am.start())]
            ents = re.findall(r'\[\s*(\w+)', seg) or ['*']
            if not re.search(r',\s*false\s*\)\s*$', seg):
                glob.append((am.group(1), ents))
    rows = []
    for c in ix['classes'].values():
        tbl = entity_table(c)
        if not tbl:
            continue
        names, chain, soft = [], [c], False
        p = ix['classes'].get(c['parent'])
        if p:
            chain.append(p)
        for k in chain:
            for d in k['decs']:
                txt = alias.get(d[2]) or k['f'].t[d[0]:d[1]]
                if (d[2] == 'Filter' or d[2] in alias) and re.search(r'default\s*:\s*true', txt):
                    nm = re.search(r"name\s*:\s*['\"](\w+)", txt)
                    cm = re.search(r'\bname\s*:\s*([\w.]+)', txt)
                    cv = C.args(h, cm.group(1), k['f'].rel)[0] if cm and not nm else []
                    cond = re.search(r'\bcond\s*:[^{]*\{([^}]*)\}', txt)   # `cond: (a) => ({ tenantId: a.tenantId })`
                    names.append(nm.group(1) if nm else cv[0] if cv else
                                 'cond:' + ','.join(re.findall(r'(\w+)\s*:', cond.group(1))) if cond else 'filter')
                if re.match(r'SoftDelet', d[2]):
                    soft = True
            if re.search(r'@DeleteDateColumn\b', k['f'].m[k['a']:k['b']]):
                soft = True
        names += [n for n, ents in glob if '*' in ents or c['name'] in ents]
        soft = soft or any(re.search(r'(?i)soft|deleted|trash', n) for n in names)
        T = rls.pop(tbl, None)
        if T and T['enabled'] and any(TENANT.search(e) for e in T['policies'].values()):
            # FORCE matters: an app that connects as the table owner bypasses a policy that is not forced
            names.append('rls:tenant' if T['forced'] else 'rls:tenant-not-forced')
        rows.append(h.row('table:' + h.table(tbl), {'soft_delete': 'yes' if soft else 'no',
                                                    'tenant': 'yes' if any(TENANT.search(n) and n != 'rls:tenant-not-forced' for n in names) else 'no',
                                                    'scopes': ','.join(sorted(set(names)))}, c['f'].rel, c['f'].t, c['start']))
    for tn, T in sorted(rls.items()):   # a policy-protected table no entity class maps
        if T['enabled'] and T['forced'] and any(TENANT.search(e) for e in T['policies'].values()):
            rel, i = T['at']
            rows.append(h.row('table:' + h.table(tn), {'soft_delete': '?', 'tenant': 'yes', 'scopes': 'rls:tenant'}, rel, h.read(rel), i))
    return rows


ROUND = [(r'\bMath\.round\(', 'half-up'), (r'\bMath\.floor\(', 'floor'), (r'\bMath\.ceil\(', 'ceil'), (r'\bMath\.trunc\(', 'trunc'),
         (r'ROUND_HALF_UP\b', 'half-away'), (r'ROUND_HALF_EVEN\b', 'half-even'), (r'ROUND_DOWN\b', 'trunc'),
         (r'ROUND_HALF_CEIL\b', 'half-up'), (r'ROUND_FLOOR\b', 'floor'), (r'ROUND_CEIL\b', 'ceil'),
         (r'\bIntl\.NumberFormat\b', 'half-away')]


MONEY_OPND = re.compile(r'(?i)pric|amount|cost|fee|charg|discount|tax|vat|cent|money|balance|subtotal|commission|payout|refund|'
                        r'wallet|revenue|profit|margin|salary|fx\b|exchange|currenc|total(?!_?(?:pages?|count|items|rows|records))')


def money_modes(t, m, a, b, fname, rules):
    """(modes, first site) of the rounding calls in [a, b): a floor / ceil / trunc counts only when its line names
    money (pagination, batching and quantity rounding do not), a round / toFixed when its line or the function does."""
    modes, first = set(), None
    fn_money = MONEY_OPND.search(fname or '') is not None
    for rx, md in rules:
        for y in re.finditer(rx, m[a:b]):
            i = a + y.start()
            ls, le = t.rfind('\n', 0, i) + 1, t.find('\n', i)
            line = t[ls:le if le >= 0 else len(t)]
            if MONEY_OPND.search(line) or (fn_money and md not in ('floor', 'ceil', 'trunc')):
                modes.add(md)
                first = i if first is None else min(first, i)
    return modes, first


def ui_app(h, rel, ctx):
    """A file in a browser app (its package.json has react / vue / svelte / next / angular and no @nestjs/core)."""
    root = app_root(h, rel)
    cache = ctx.setdefault('ui_app', {})
    if root not in cache:
        t = h.read(os.path.join(root, 'package.json')) if h.exists(os.path.join(root, 'package.json')) else ''
        cache[root] = '"@nestjs/core"' not in t and re.search(r'"(?:react|vue|svelte|next|@angular/core)"\s*:', t) is not None
    return cache[root]


AREA_TECH = set('mikro port adapter orm infrastructure create get read send process preview load loaded list find fetch handle '
                'compute calc calculate build make run execute apply update upsert sync import export query queries command '
                'my do new'.split())


def money_area(h, cls, rel, meth):
    """(f) The area of a money path: the class/file noun, unless it is a technical or verb word (`MikroXPort`,
    `CreateOrder.execute`, `ReadOrderApi`) — then the first money word of the method, class and file."""
    a = h.area(cls, rel, meth)
    if a[5:] not in AREA_TECH:
        return a
    for src in (meth, cls, os.path.splitext(os.path.basename(rel))[0]):
        for w in h.words(src):
            if w not in AREA_TECH and MONEY_OPND.match(w):
                return 'area:' + h.table(w)
    for src in (cls, os.path.splitext(os.path.basename(rel))[0], meth):
        for w in h.words(src):
            if w not in AREA_TECH and w not in h.ROLE_WORDS and len(w) > 1:
                return 'area:' + h.table(w)
    return a


def lane_money(root, h, ctx):
    """Rounding on money paths, keyed by area. Modes flow up the call graph (a caller of `roundMoney(x, 2)` or
    `this.placement.place()` inherits their modes), and a row is emitted only for the outermost money function:
    one called by another function is a helper, so V1's controller and V2's controller pair on the call target,
    whatever the helpers are named. Browser-app files are display rounding (precedent § 11), counted and left out."""
    ix = index(root, h, ctx)
    sites = {}
    for c in ix['classes'].values():
        f = c['f']
        dec = re.search(r'''from\s+['"](?:decimal\.js|big\.js|bignumber\.js)['"]''', f.t)
        types = ctor_types(c) if c['name'] != '<module>' else {}
        for meth, (a, b, s, _, _) in c['methods'].items():
            rules = ROUND + [(r'\.toFixed\(', 'half-away' if dec else 'float-tofixed')] + \
                ([(r'\.(?:toDecimalPlaces|toDP|round)\((?![^)]*ROUND_)', 'half-away')] if dec else [])
            modes, first = money_modes(f.t, f.m, a, b, '%s %s %s' % (f.rel, c['name'], meth), rules)
            s = first if first is not None else s
            calls = set()
            for cm in re.finditer(r'\bthis\.(\w+)\.(\w+)\s*\(', f.m[a:b]):
                if cm.group(1) in types:
                    calls.add((types[cm.group(1)], cm.group(2)))
            for cm in re.finditer(r'\bthis\.(\w+)\s*\(', f.m[a:b]):
                calls.add((c['name'], cm.group(1)))
            for cm in re.finditer(r'(?<![.\w])(\w+)\s*\(|\b\w+\.(\w+)\s*\(', f.m[a:b]):   # module functions, `money.round(`
                calls.add(('<module>', cm.group(1) or cm.group(2)))
            sites[(c['name'], meth, id(c))] = [c, meth, s, set(modes), calls]
    by_name = {}
    for k, v in sites.items():
        by_name.setdefault((k[0], k[1]), []).append(k)
    for _ in range(4):   # modes flow up the call graph
        for k, v in sites.items():
            for call in v[4]:
                for t in by_name.get(call, ()):
                    if t != k:
                        v[3] |= sites[t][3]
    called = set(t for v in sites.values() for call in v[4] for t in by_name.get(call, ()) if sites[t][3])
    rows, ui_n = [], 0
    for k, (c, meth, s, modes, calls) in sites.items():
        f = c['f']
        if not modes or k in called or not MONEY.search(f.rel + ' ' + c['name'] + ' ' + meth):
            continue
        if ui_app(h, f.rel, ctx):
            ui_n += 1
            continue
        rows.append(h.row(money_area(h, c['name'], f.rel, meth), {'modes': ','.join(sorted(modes)), 'where': '%s.%s' % (c['name'], meth)},
                          f.rel, f.t, s))
    if ui_n:
        h.notes.append('I-MONEY: %d rounding site(s) in browser-app files left out (display rounding)' % ui_n)
    return rows


def lane_conf(root, h, ctx):
    ix = index(root, h, ctx)
    rows, seen = [], set()

    def add(key, val, rel, t, i):
        if key not in seen and val:
            seen.add(key)
            rows.append(h.row(key, {'value': val, 'src': rel}, rel, t, i))
    envs = {}
    for rel in h.files(['**/.env.example', '**/.env.sample']):
        for em in re.finditer(r'(?m)^(\w+)=["\']?([^"\'\s#]*)', h.read(rel)):
            envs.setdefault(em.group(1), em.group(2))
    for f in ix['files'].values():
        for key, rx in (('timezone', r'\b(?:time_?[zZ]one|tz)\s*:\s*process\.env\.(\w+)\s*(?:\?\?|\|\|)\s*[\'"]([^\'"]+)'),
                        ('locale', r'\b(?:locale|defaultLocale|fallbackLng)\s*:\s*process\.env\.(\w+)\s*(?:\?\?|\|\|)\s*[\'"]([^\'"]+)')):
            m = re.search(rx, f.t)
            if m:
                add(key, envs.get(m.group(1)) or m.group(2), f.rel, f.t, m.start())
    for rel in h.files(['**/Dockerfile*', '**/.env.example', '**/.env.sample', '*.yaml', '*.yml'], pattern=r'\bTZ\b|LOCALE|CURRENCY'):
        t = h.read(rel)
        for rx, key in ((r'(?m)^\s*ENV\s+TZ[=\s]+["\']?([\w/+-]+)', 'timezone'), (r'(?m)^TZ=["\']?([\w/+-]+)', 'timezone'),
                        (r'name:\s*TZ\s*\n\s*value:\s*["\']?([\w/+-]+)', 'timezone'),
                        (r'(?m)^(?:DEFAULT_LOCALE|APP_LOCALE|LOCALE|DEFAULT_LANGUAGE)=["\']?(\w+)', 'locale'),
                        (r'(?m)^DEFAULT_CURRENCY=["\']?(\w+)', 'currency')):
            m = re.search(rx, t)
            if m:
                add(key, m.group(1), rel, t, m.start())
    pp, at = set(), None
    rows_dt, _ = dto(root, h, ctx)
    for r in rows_dt:
        if r['kind'] == 'PROP' and re.search(r'\.(?:perPage|pageSize|per_page|page_size|limit|take)$', r['prop']):
            m = re.search(r'initialiser\((\d+)\)', r.get('flags', ''))
            if m:
                pp.add(m.group(1))
                at = at or r
    for f in ix['files'].values():
        for m in re.finditer(r'\b(?:DEFAULT_)?(?:PAGE_SIZE|PER_PAGE|PAGE_LIMIT)\s*=\s*(\d+)', f.t):
            pp.add(m.group(1))
        for m in re.finditer(r'\b(?:per_?page|perPage|page_?size|pageSize|limit)\s*:\s*z\.[^\n]*?\.default\(\s*(\d+)', f.t):
            pp.add(m.group(1))
            at = at or {'file': f.rel, 'line': str(h.line(f.t, m.start()))}
        # i18next `lng` is the language served; `fallbackLng` only fills missing keys (read it only without `lng`)
        m = (re.search(r"\blng\s*:\s*['\"](\w+)", f.t) or re.search(r"\bdefaultLocale\s*:\s*['\"](\w+)", f.t)
             or re.search(r"\bfallbackLng\s*:\s*['\"](\w+)", f.t))
        if m:
            add('locale', m.group(1), f.rel, f.t, m.start())
        m = re.search(r"\bDEFAULT_CURRENCY\s*=\s*['\"](\w+)", f.t)
        if m:
            add('currency', m.group(1), f.rel, f.t, m.start())
    if pp:
        g = ix['files'].get(at['file']) if at else None
        rows.append(h.row('per_page', {'value': ','.join(sorted(pp)), 'src': 'DTO default / PAGE_SIZE const'}, g.rel if g else None,
                          g.t if g else '', line_idx(g.t, at['line']) if g else 0))
    return rows


def lane_schema(root, h, ctx):
    """schema-map DDL + views/trigger-maintained columns + MikroORM `formula:` properties (a derived column)."""
    rows = h.schema_map() + h.schema_extra()
    ix = index(root, h, ctx)
    for c in ix['classes'].values():
        tbl = entity_table(c)
        if not tbl:
            continue
        f = c['f']
        for pm in re.finditer(r'@(?:Property|Formula)\s*\(', f.m[c['a']:c['b']]):
            a = c['a'] + pm.end() - 1
            e = h.close(f.m, a)
            if 'formula' not in f.m[a:e] and not pm.group(0).startswith('@Formula'):
                continue
            fn = re.search(r"fieldName\s*:\s*['\"](\w+)", f.t[a:e])
            nm = re.match(r'\s*(?:@\w+\([^)]*\)\s*)*(\w+)', f.m[e + 1:e + 200])
            col = fn.group(1) if fn else snake(nm.group(1)) if nm else None
            if col:
                rows.append(h.row('derived:%s.%s' % (h.table(tbl), col), {'how': 'formula'}, f.rel, f.t, a))
    return rows


LANES = {'nest': {'I-SCHEMA': lane_schema, 'I-ROUTES': lane_routes, 'I-AUTHZ': lane_authz, 'I-RULES': lane_rules, 'I-ENUM': lane_enum,
                  'I-ERR': lane_err, 'I-SIDE': lane_side, 'I-SCHED': lane_sched, 'I-SCOPE': lane_scope,
                  'I-MONEY': lane_money, 'I-CONF': lane_conf}}


# ---------------------------------------------------------------- self-test (the fold-back cases of a real port)
_ST = {
    'package.json': '{"dependencies": {"@nestjs/core": "11.1.6", "@mikro-orm/core": "6.4.0"}}\n',
    'src/app.module.ts': (
        "import { Module } from '@nestjs/common';\nimport { APP_GUARD } from '@nestjs/core';\n"
        "@Module({ providers: [{ provide: APP_GUARD, useClass: JwtAuthGuard }, { provide: APP_GUARD, useClass: AccountKindGuard }] })\n"
        "export class AppModule {}\n"),
    'src/auth/jwt.guard.ts': "export class JwtAuthGuard extends AuthGuard('jwt') {}\n",
    'src/auth/account-kind.guard.ts': (
        "export class AccountKindGuard implements CanActivate {\n  constructor(private readonly reflector: Reflector) {}\n"
        "  canActivate(ctx: ExecutionContext) {\n    const kinds = this.reflector.getAllAndOverride<string[]>(ACCOUNT_KIND_KEY, [ctx.getHandler()]);\n"
        "    return !kinds || kinds.includes('seller');\n  }\n}\n"),
    'src/auth/decorators.ts': (
        "import { SetMetadata } from '@nestjs/common';\n\nexport const PERMISSIONS_KEY = 'permissions';\n"
        "export const RequirePermission = (...keys: string[]) => SetMetadata(PERMISSIONS_KEY, keys);\n\n"
        "export const ANY_PERMISSIONS_KEY = 'anyPermissions';\n"
        "export const RequireAnyPermission = (...keys: string[]) =>\n  SetMetadata(ANY_PERMISSIONS_KEY, keys);\n\n"
        "export const ACCOUNT_KIND_KEY = 'accountKind';\n"
        "export const RequireAccountKind = (...k: string[]) => SetMetadata(ACCOUNT_KIND_KEY, k);\n"),
    'src/orders/order.permissions.ts': (
        "export const ORDER_PERMISSIONS = Object.freeze({\n  view: 'can_view_orders',\n  edit: 'can_edit_orders',\n});\n\n"
        "export const RESCUE = {\n  view: ['can_view_followup', 'can_rescue_orders'],\n} as const;\n"),
    'src/orders/openers.ts': (
        "import { RESCUE } from './order.permissions.js';\n\n"
        "export const OPENERS = ['can_view_orders', ...RESCUE.view] as const satisfies readonly string[];\n"),
    'src/orders/orders.controller.ts': (
        "import { Controller, Get, Post } from '@nestjs/common';\n"
        "import { RequireAnyPermission, RequirePermission } from '../auth/decorators';\n"
        "import { ORDER_PERMISSIONS } from './order.permissions';\nimport { OPENERS } from './openers';\n\n"
        "@Controller('orders')\nexport class OrdersController {\n  constructor(private readonly place: PlaceOrder) {}\n\n"
        "  @Get()\n  @RequirePermission(ORDER_PERMISSIONS.view)\n  list() {\n    return [];\n  }\n\n"
        "  @Get('open')\n  @RequireAnyPermission(...OPENERS)\n  open() {\n    return [];\n  }\n\n"
        "  @Post()\n  @RequirePermission(ORDER_PERMISSIONS.edit)\n  create() {\n    return this.place.execute();\n  }\n}\n"),
    'src/orders/submit-order.use-case.ts': (
        "export class PlaceOrder {\n  constructor(private readonly outbox: OutboxPort) {}\n\n"
        "  async execute() {\n    await this.outbox.emit(ORDER_EVENTS.CREATED, { id: 1 });\n    return 1;\n  }\n}\n\n"
        "export const ORDER_EVENTS = { CREATED: 'order.created' } as const;\n"),
    'src/orders/order-notification.consumer.ts': (
        "export const INTERESTED: readonly string[] = ['order.created'];\n\n"
        "export class OrderNotificationConsumer {\n  constructor(private readonly em: EntityManager) {}\n\n"
        "  async handle(event: { type: string }) {\n    this.em.create(MerchantNotificationEntity, { type: event.type });\n  }\n}\n"),
    'src/jobs/audit-prune.job.ts': (
        "export class AuditRetentionJob {\n  @Cron('0 0 3 * * *')\n  async prune() {\n    return;\n  }\n}\n"),
    'src/jobs/outbox-retention.job.ts': (
        "export class OutboxRetentionJob {\n  @Cron('0 5 * * *')\n  async prune() {\n    return;\n  }\n}\n"),
    'src/shared/errors.ts': (
        "export class DomainError extends Error {}\nexport class ConflictError extends DomainError {\n"
        "  constructor(text: ErrorText = {}) {\n    super(text.message ?? 'conflict');\n  }\n}\n\n"
        "export function defineMessages(prefix: string, catalog: object) {\n  return catalog;\n}\n"),
    'src/shared/global-errors.filter.ts': (
        "@Catch()\nexport class AllExceptionsFilter {\n  catch(exception: unknown) {\n"
        "    if (exception instanceof ConflictError) {\n      return { status: HttpStatus.CONFLICT };\n    }\n    return { status: 500 };\n  }\n}\n"),
    'src/orders/order.messages.ts': "export const ORDER_MESSAGES = defineMessages('ORDER', {\n  LOCKED: { message: 'locked' },\n});\n",
    'src/orders/lock-order.ts': (
        "import { ORDER_MESSAGES } from './order.messages';\n\n"
        "export function lockOrder() {\n  throw new ConflictError({ ...ORDER_MESSAGES.LOCKED });\n}\n"),
    'src/database/tenant.constants.ts': "export const TENANT_FILTER = 'tenant';\n",
    'src/orders/order.entity.ts': (
        "import { Entity, Enum, Filter, PrimaryKey } from '@mikro-orm/core';\nimport { TENANT_FILTER } from '../database/tenant.constants';\n"
        "import { STAGES } from './stages';\n\n"
        "@Entity({ tableName: 'orders' })\n@Filter({ name: TENANT_FILTER, cond: (a: { tenantId: string }) => ({ tenantId: a.tenantId }), default: true })\n"
        "export class OrderEntity {\n  @PrimaryKey()\n  id!: string;\n\n  @Enum({ items: [...STAGES] })\n  stage!: string;\n}\n"),
    'src/orders/stages.ts': "export const STAGES = ['draft', 'done'] as const;\n",
    'src/invoices/invoice.entity.ts': (
        "import { Entity, PrimaryKey } from '@mikro-orm/core';\n\n@Entity({ tableName: 'invoices' })\n"
        "export class InvoiceEntity {\n  @PrimaryKey()\n  id!: string;\n}\n"),
    'src/migrations/Migration20240101000000.ts': (
        "import { Migration } from '@mikro-orm/migrations';\n\nexport class Migration20240101000000 extends Migration {\n"
        "  private readonly scoped = ['invoices'];\n\n  override async up(): Promise<void> {\n"
        "    for (const table of [...this.scoped].reverse()) {\n"
        "      this.addSql(`alter table \"${table}\" enable row level security;`);\n"
        "      this.addSql(`alter table \"${table}\" force row level security;`);\n"
        "      this.addSql(`create policy \"${table}_tenant_isolation\" on \"${table}\" using (public.app_tenant_visible(tenant_id));`);\n"
        "    }\n  }\n\n  override async down(): Promise<void> {\n"
        "    this.addSql(`alter table \"invoices\" disable row level security;`);\n  }\n}\n"),
    'src/migrations/.snapshot-app.json': (
        '{"tables": [{"name": "returns", "columns": {"decision": {"name": "decision", "enumItems": ["accepted", "disputed"]}},'
        ' "checks": [{"name": "returns_kind_check", "columnName": "kind", "expression": "kind IN (\'a\', \'b\')"}]}]}\n'),
    'packages/contracts/src/vocab.ts': "export const SOURCES = ['team_members', 'orders'] as const;\n",
    'src/reports/source.schema.ts': (
        "import { z } from 'zod';\nimport { SOURCES } from '../../packages/contracts/src/vocab.js';\n\n"
        "export const reportSourceSchema = z.enum(SOURCES);\n"),
}


def self_test(H, tmp):
    root = os.path.join(tmp, 'nest-foldback')
    for rel, body in _ST.items():
        p = os.path.join(root, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w', encoding='utf-8') as f:
            f.write(body)
    out = []

    def rows(fn):
        h, ctx = H(root, 'v2'), {'stack': 'nest'}
        try:
            return dict((r['key'], r['attrs']) for r in fn(root, h, ctx))
        except H.Blocked as e:
            return {'blocked': {'why': str(e)}}
    az = rows(lane_authz)
    out.append(('nest IR-3: object member, Object.freeze, spread of an imported `as const` array (.js import) resolve %s'
                % dict((k, v.get('abilities')) for k, v in az.items()),
                az.get('GET /orders', {}).get('abilities') == 'can.view.orders'
                and az.get('GET /orders/open', {}).get('abilities') == 'can.rescue.orders,can.view.followup,can.view.orders', str(az)[:300]))
    out.append(('nest: a metadata-gated global guard does not guard a route without its metadata',
                az.get('GET /orders', {}).get('extra_guard') == 'no', str(az.get('GET /orders'))))
    sc = rows(lane_scope)
    out.append(('nest IR-5: filter name from a constant; forced RLS policy from a migration loop over a class field -> tenant %s'
                % dict((k, v.get('tenant')) for k, v in sc.items()),
                sc.get('table:order', {}).get('tenant') == 'yes' and sc.get('table:invoice', {}).get('tenant') == 'yes', str(sc)))
    se = rows(lane_side)
    out.append(('nest IR-6: outbox emit keyed by its event, carrying its consumer\'s notification -> %s' % se.get('order.created'),
                se.get('order.created', {}).get('kinds') == 'event,notify', str(se)[:300]))
    sh = rows(lane_sched)
    out.append(('nest IR-7: unnamed jobs keyed by Class.method; a fixed second offset dropped %s' % sorted(sh),
                'job:audit.prune.retention' in sh and 'job:outbox.prune.retention' in sh
                and sh['job:audit.prune.retention'].get('cron') == '0 3 * * *', str(sh)))
    er = rows(lane_err)
    out.append(('nest IR-8: `new ConflictError({ ...ORDER_MESSAGES.LOCKED })` -> code:ORDER_LOCKED %s' % er.get('code:ORDER_LOCKED'),
                er.get('code:ORDER_LOCKED', {}).get('status') == '409', str(sorted(er))))
    en = rows(lane_enum)
    out.append(('nest (a)(b): @Enum items spread, z.enum(imported), snapshot enumItems and value CHECK %s'
                % dict((k, v.get('values')) for k, v in en.items() if k.startswith(('col:', 'type:reportsource'))),
                en.get('col:order.stage', {}).get('values') == 'done,draft' and en.get('col:return.decision', {}).get('values') == 'accepted,disputed'
                and en.get('col:return.kind', {}).get('values') == 'a,b' and en.get('type:reportsource', {}).get('values') == 'orders,team_members',
                str(en)[:400]))
    return out
