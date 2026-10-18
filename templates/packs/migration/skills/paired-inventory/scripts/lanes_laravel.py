"""lanes_laravel.py — V1 Laravel lanes for pair-inventory.py (PHP-free static reader; nothing is booted).

Reads, from the git-archive snapshot of the pinned SHA:
  I-ROUTES  routes/{web,api}.php + includes: Route:: facade chains by brace depth (group / prefix / middleware /
            controller / name / where*), resource + apiResource expanded (only/except), match/any/fallback;
            entry points from bootstrap/app.php withRouting (apiPrefix) or RouteServiceProvider, else the defaults.
  I-AUTHZ   route + group middleware (auth*, can:, spatie role:/permission:), aliases, controller __construct /
            HasMiddleware middleware, $this->authorize / Gate:: / authorizeResource, FormRequest authorize().
  I-RULES   FormRequest rules(), $request->validate, Validator::make (string and array forms, Rule::in / enum);
            global TrimStrings / ConvertEmptyStringsToNull (on by default from Laravel 11 unless removed).
  I-ENUM    PHP 8.1 enums (backed values), $casts enum columns, migration ->enum() columns.
  I-ERR     framework defaults (422 validation, 404, 401, 403) + withExceptions / Handler render + exception
            classes with a status (render(), Symfony HttpException subclasses).
  I-SIDE    observers (#[ObservedBy], ::observe, $observers), booted() closures, LogsActivity / Searchable traits,
            $dispatchesEvents + listeners, route handlers — call shapes, one hop into $this->service->method().
  I-SCHED   routes/console.php Schedule::, Console Kernel schedule(), withSchedule; frequency helpers -> cron.
  I-SCOPE   SoftDeletes, global scopes (#[ScopedBy], addGlobalScope, tenant traits) per table.
  I-SCHEMA  database schema-map.py --lane=laravel (Blueprint replay) -> col / unique / fk rows.
  I-MONEY   (partial) round / number_format / bc* / floor / ceil / brick RoundingMode on money-named methods.
  I-CONF    (partial) config/app.php timezone + locale (.env.example wins), paginate() default 15 / $perPage.
Cannot see: routes registered in vendor packages, macros, dynamic route files, closures' runtime middleware,
policies resolved at runtime, events fired through string names built at runtime. Version gates come from
composer.lock only (no lock -> UNREAD).
"""
import json, os, re

STACKS = ('laravel',)
PARTIAL = {('laravel', 'I-MONEY'), ('laravel', 'I-CONF')}
GAPS = {}
ALL = 'ANY'
ENUM_STRIP = ('enum', 'choices', 'type', 'schema')
EVENTS = ('created', 'updated', 'deleted', 'saved', 'creating', 'updating', 'deleting', 'saving', 'restored',
          'forceDeleted')
RES = [('index', 'GET', ''), ('create', 'GET', '/create'), ('store', 'POST', ''), ('show', 'GET', '/{x}'),
       ('edit', 'GET', '/{x}/edit'), ('update', 'PUT', '/{x}'), ('update', 'PATCH', '/{x}'), ('destroy', 'DELETE', '/{x}')]
RES_ABILITY = {'index': 'viewany', 'show': 'view', 'create': 'create', 'store': 'create', 'edit': 'update',
               'update': 'update', 'destroy': 'delete'}
WHERE = {'whereNumber': 'int', 'whereAlpha': 'alpha', 'whereAlphaNumeric': 'alnum', 'whereUuid': 'uuid',
         'whereUlid': 'ulid', 'whereIn': 'in'}
NON_GUARD = re.compile(r'^(throttle|bindings|substitutebindings|cache\.headers|cors|handlecors|csrf|verifycsrftoken|'
                       r'encryptcookies|startsession|sharederrorsfromsession|addqueuedcookiestoresponse|trimstrings|'
                       r'convertemptystringstonull|api|web|json|forcejson\w*|setlocale|localize\w*)\b', re.I)
SYMFONY = {'BadRequest': '400', 'Unauthorized': '401', 'AccessDenied': '403', 'NotFound': '404',
           'MethodNotAllowed': '405', 'NotAcceptable': '406', 'Conflict': '409', 'Gone': '410', 'LengthRequired': '411',
           'PreconditionFailed': '412', 'UnsupportedMediaType': '415', 'UnprocessableEntity': '422', 'Locked': '423',
           'TooManyRequests': '429', 'ServiceUnavailable': '503'}
KINDS = [('mail', r'\bMail::\w+\('), ('notify', r'->notify(?:Now)?\(|\bNotification::(?:send\w*|route)\('),
         ('event', r'\bevent\(|\bEvent::dispatch\('), ('job', r'\bdispatch(?:_sync)?\(\s*new\b|\bBus::(?:dispatch\w*|chain|batch)\(|\bQueue::push\w*\('),
         ('webhook', r'(?i)\bwebhook\w*(?:->|::)\w*(?:send|post|dispatch|deliver|call|create)\w*\('),
         ('audit', r"(?i)\b\w*audit\w*(?:->|::)(?:log|record|create|write|insert)\w*\("),
         ('activity', r'\bactivity\(\)'), ('search', r'->(?:un)?searchable\(\)'),
         ('cache', r'\bCache::(?:forget|flush|put|forever|tags)\(|\bcache\(\)->forget\(')]
MONEY = re.compile(r'(?i)price|total|tax|vat|amount|invoice|order|payment|refund|fee|discount|balance|charge|cost|'
                   r'money|currency|payout|settle|subtotal|commission|sale|pric|credit|wallet|install')


def detect(root, h):
    cj = h.read('composer.json') if h.exists('composer.json') else ''
    if 'laravel/framework' in cj:
        v = version(h)
        return {'laravel': 'composer.json laravel/framework %s' % (('%s (composer.lock)' % v) if v else '(no composer.lock: version UNREAD)')}
    if h.exists('artisan') and (h.exists('routes/web.php') or h.exists('routes/api.php')):
        return {'laravel': 'artisan + routes/*.php (no composer.json)'}
    return {'laravel': ''}


def version(h):
    try:
        for p in json.loads(h.read('composer.lock') or '{}').get('packages', []):
            if p.get('name') == 'laravel/framework':
                return p.get('version')
    except ValueError:
        return None
    return None


def major(h):
    m = re.match(r'v?(\d+)', version(h) or '')
    return int(m.group(1)) if m else None


# ---------------------------------------------------------------- PHP index
class F(object):
    def __init__(self, h, rel):
        self.rel, self.t = rel, h.read(rel)
        self.m, self.sp = h.masked(rel, 'php')

    def lits(self, a, b):
        return [self.t[s + 1:e - 1] for s, e in self.sp if s >= a and e <= b]

    def lit(self, a, b):
        l = self.lits(a, b)
        return l[0] if l else None

    def classrefs(self, a, b):
        return [x.split('\\')[-1] for x in re.findall(r'([\w\\]+)::class', self.m[a:b])]


def index(root, h, ctx):
    if 'ix' in ctx:
        return ctx['ix']
    ix = {'classes': {}, 'files': {}, 'fqn': {}}
    for rel in h.files(['*.php'], excludes=[h.MIGRATIONS, '!**/*.blade.php']):
        f = F(h, rel)
        ix['files'][rel] = f
        for mt in re.finditer(r'\b(?:(?:final|abstract|readonly)\s+)*(class|enum|trait)\s+(\w+)'
                              r'(?:\s*:\s*(string|int))?(?:\s+extends\s+([\w\\]+))?(?:\s+implements\s+[\w\\,\s]+)?\s*\{', f.m):
            a = mt.end() - 1
            b = h.close(f.m, a)
            c = {'name': mt.group(2), 'kind': mt.group(1), 'f': f, 'a': a, 'b': b, 'start': mt.start(),
                 'parent': (mt.group(4) or '').split('\\')[-1], 'methods': {}, 'traits': [], 'props': {}}
            pos, outside = a + 1, list(f.m[a + 1:b])
            for fm in re.finditer(r'\bfunction\s+&?\s*(\w+)\s*\(', f.m[a + 1:b]):
                s = a + 1 + fm.start()
                if s < pos:
                    continue
                pe = h.close(f.m, a + fm.end())
                k = pe + 1
                while k < b and f.m[k] not in '{;':
                    k += 1
                if k < b and f.m[k] == '{':
                    e = h.close(f.m, k)
                    c['methods'][fm.group(1)] = (pe, k, e, a + 1 + fm.start(), pe)
                    for j in range(k - a - 1, e - a):
                        if 0 <= j < len(outside) and outside[j] != '\n':
                            outside[j] = ' '
                    pos = e
            out = ''.join(outside)
            for um in re.finditer(r'(?m)^\s*use\s+([\w\\,\s]+?)\s*[;{]', out):
                c['traits'] += [x.strip().split('\\')[-1] for x in um.group(1).split(',') if x.strip()]
            for pm in re.finditer(r'(?:public|protected|private|var)\s+(?:static\s+)?(?:readonly\s+)?(?:\??[\w\\|]+\s+)?\$(\w+)\s*=\s*', out):
                va = a + 1 + pm.end()
                vb = va
                while vb < b and f.m[vb] != ';':
                    vb = h.close(f.m, vb) + 1 if f.m[vb] in '([{' else vb + 1
                c['props'][pm.group(1)] = (va, vb)
            ns = re.search(r'\bnamespace\s+([\w\\]+)\s*;', f.m)
            c['fqn'] = (ns.group(1) + '\\' if ns else '') + c['name']
            ix['fqn'].setdefault(c['fqn'], c)
            ix['classes'].setdefault(c['name'], c)
    ctx['ix'] = ix
    return ix


def body(c, meth):
    m = c['methods'].get(meth)
    return (m[1], m[2]) if m else None


def promoted_types(c):
    """$this->x property -> class, from constructor promotion, typed properties, and $this->x = $param."""
    f, out = c['f'], {}
    ctor = c['methods'].get('__construct')
    if ctor:
        sig = f.m[ctor[3]:ctor[1]]
        for pm in re.finditer(r'(?:private|protected|public)\s+(?:readonly\s+)?\??([\w\\]+)\s+\$(\w+)', sig):
            out[pm.group(2)] = pm.group(1).split('\\')[-1]
        for pm in re.finditer(r'\??([\w\\]+)\s+\$(\w+)', sig):
            pv = re.search(r'\$this->(\w+)\s*=\s*\$%s\b' % pm.group(2), f.m[ctor[1]:ctor[2]])
            if pv:
                out[pv.group(1)] = pm.group(1).split('\\')[-1]
    for pm in re.finditer(r'(?:private|protected|public)\s+(?:readonly\s+)?\??([A-Z][\w\\]*)\s+\$(\w+)\s*;', f.m[c['a']:c['b']]):
        out.setdefault(pm.group(2), pm.group(1).split('\\')[-1])
    return out


def kinds(ix, c, a, b, hop=1):
    f, ks = c['f'], set()
    seg = f.m[a:b]
    for k, rx in KINDS:
        if re.search(rx, seg):
            ks.add(k)
    if re.search(r"\bDB::table\(\s*['\"]\w*audit\w*['\"]\s*\)\s*->\s*insert", c['f'].t[a:b]):   # the table name is a literal
        ks.add('audit')
    for dm in re.finditer(r'\b([A-Z]\w*)::dispatch(?:Sync|Now|If|Unless|AfterResponse)?\(', seg):
        if dm.group(1) in ('Event', 'Bus', 'Queue'):
            continue
        cc = ix['classes'].get(dm.group(1))
        path = cc['f'].rel if cc else ''
        ks.add('event' if ('/Events/' in '/' + path or dm.group(1).endswith('Event')) else 'job')
    if hop:
        types = promoted_types(c)
        for cm in re.finditer(r'\$this->(\w+)->(\w+)\(', seg):
            tc = ix['classes'].get(types.get(cm.group(1), ''))
            if tc and cm.group(2) in tc['methods']:
                ba = body(tc, cm.group(2))
                ks |= kinds(ix, tc, ba[0], ba[1], 0)
        for sm in re.finditer(r'\b([A-Z]\w*)::(\w+)\(', seg):
            tc = ix['classes'].get(sm.group(1))
            if tc and tc['kind'] == 'class' and sm.group(2) in tc['methods'] and sm.group(2) != 'dispatch':
                ba = body(tc, sm.group(2))
                ks |= kinds(ix, tc, ba[0], ba[1], 0)
    return ks


# ---------------------------------------------------------------- routes
def entries(root, h, ix):
    """[(file, prefix, groups, block)] — the route files and the prefix/middleware they are mounted with."""
    out = []
    ba = 'bootstrap/app.php'
    if h.exists(ba) and 'withRouting' in h.read(ba):
        f = F(h, ba)
        w = f.m.find('withRouting')
        p = f.m.find('(', w)
        e = h.close(f.m, p)
        seg = f.t[p:e]
        apre = re.search(r"apiPrefix\s*:\s*'([^']*)'", seg)
        for name, pre, grp in (('web', '', 'web'), ('api', apre.group(1) if apre else 'api', 'api')):
            mm = re.search(r"\b%s\s*:\s*__DIR__\s*\.\s*'([^']+)'" % name, seg)
            if mm:
                out.append((os.path.normpath(os.path.join('bootstrap', mm.group(1).lstrip('/'))), pre, [grp]))
        then = re.search(r'\bthen\s*:\s*function\s*\([^)]*\)\s*\{', f.m[p:e])
        if then:
            a = p + then.end() - 1
            out.append((ba, '', [], (a + 1, h.close(f.m, a))))
        return out
    rsp = 'app/Providers/RouteServiceProvider.php'
    if h.exists(rsp) and 'group(' in h.read(rsp):
        f = F(h, rsp)
        out.append((rsp, '', [], (0, len(f.m))))
        return out
    for rel, pre, grp in (('routes/web.php', '', 'web'), ('routes/api.php', 'api', 'api')):
        if h.exists(rel):
            out.append((rel, pre, [grp]))
    return out


def chains(f, h, a, b):
    i, pat = a, re.compile(r'\bRoute\s*::\s*(\w+)\s*\(')
    while True:
        mt = pat.search(f.m, i, b)
        if not mt:
            return
        calls, name, p = [], mt.group(1), mt.end() - 1
        while True:
            e = h.close(f.m, p)
            calls.append((name, p + 1, e))
            mm = re.compile(r'\s*->\s*(\w+)\s*\(').match(f.m, e + 1)
            if not mm:
                break
            name, p = mm.group(1), mm.end() - 1
        yield mt.start(), calls
        i = e + 1


def mw_list(f, a, b):
    return f.lits(a, b) + f.classrefs(a, b)


def file_uses(f):
    if not hasattr(f, 'uses'):
        f.uses = {}
        for um in re.finditer(r'(?m)^\s*use\s+\\?([\w\\]+)(?:\s+as\s+(\w+))?\s*;', f.m):
            f.uses[um.group(2) or um.group(1).split('\\')[-1]] = um.group(1)
    return f.uses


def routes(root, h, ctx):
    if 'routes' in ctx:
        return ctx['routes']
    ix = index(root, h, ctx)
    out, seen = [], set()
    pats = {}
    for c in ix['classes'].values():
        for pm in re.finditer(r"\bRoute::pattern\(\s*'(\w+)'\s*,\s*'([^']+)'", c['f'].t):
            pats[pm.group(1)] = pm.group(2)

    def block(f, a, b, loc, depth=0):
        for start, calls in chains(f, h, a, b):
            l = dict(loc, mw=list(loc['mw']), without=list(loc['without']), where=dict(loc['where']), prefix=list(loc['prefix']))
            reg, only, exc, grp = None, None, None, None
            for name, ca, cb in calls:
                if name == 'prefix':
                    l['prefix'].append(f.lit(ca, cb) or '')
                elif name == 'middleware':
                    l['mw'] += mw_list(f, ca, cb)
                elif name == 'withoutMiddleware':
                    l['without'] += mw_list(f, ca, cb)
                elif name == 'can':
                    l['mw'].append('can:' + ','.join(f.lits(ca, cb)))
                elif name == 'controller':
                    l['controller'] = (f.classrefs(ca, cb) or [None])[0]
                elif name in WHERE:
                    for p in f.lits(ca, cb)[:1]:
                        l['where'][p] = WHERE[name]
                elif name == 'where':
                    lt = f.lits(ca, cb)
                    for k, v in zip(lt[::2], lt[1::2]):
                        l['where'][k] = 'int' if v in (r'[0-9]+', r'\d+') else 're'
                elif name in ('only', 'except'):
                    if name == 'only':
                        only = f.lits(ca, cb)
                    else:
                        exc = f.lits(ca, cb)
                elif name == 'group':
                    grp = (ca, cb)
                elif name in ('get', 'post', 'put', 'patch', 'delete', 'options', 'any', 'match', 'resource',
                              'apiResource', 'resources', 'apiResources', 'fallback', 'view', 'redirect',
                              'permanentRedirect'):
                    reg = (name, ca, cb)
                elif name in ('name', 'as', 'domain', 'scopeBindings', 'withoutScopedBindings', 'names',
                              'parameters', 'missing', 'withTrashed', 'shallow', 'lazy', 'middlewareFor'):
                    pass
                elif name == 'singleton':
                    h.unparse('I-ROUTES', f.rel, f.t, start, 'Route::singleton not expanded')
            if grp:
                ga, gb = grp
                arr = re.match(r'\s*\[', f.m[ga:gb])
                if arr:
                    aa = ga + arr.end() - 1
                    ab = h.close(f.m, aa)
                    for km in re.finditer(r"'(\w+)'\s*=>", f.t[aa:ab]):
                        va = aa + km.end()
                        vb = va
                        while vb < ab and f.m[vb] != ',':
                            vb = h.close(f.m, vb) + 1 if f.m[vb] in '([{' else vb + 1
                        k = km.group(1)
                        if k == 'prefix':
                            l['prefix'].append(f.lit(va, vb) or '')
                        elif k == 'middleware':
                            l['mw'] += mw_list(f, va, vb)
                        elif k == 'controller':
                            l['controller'] = (f.classrefs(va, vb) or [None])[0]
                cl = re.search(r'\bfunction\s*\([^)]*\)\s*(?:use\s*\([^)]*\)\s*)?(?::\s*\w+\s*)?\{', f.m[ga:gb])
                if cl:
                    oa = ga + cl.end() - 1
                    block(f, oa + 1, h.close(f.m, oa), l, depth + 1)
                else:
                    inc = re.search(r"(?:base_path\(\s*'([^']+)'|__DIR__\s*\.\s*'([^']+)')", f.t[ga:gb])
                    lt = f.lits(ga, gb)
                    path = inc and (inc.group(1) or os.path.normpath(os.path.join(os.path.dirname(f.rel), inc.group(2).lstrip('/'))))
                    path = path or (lt[0] if lt and lt[0].endswith('.php') else None)
                    if path and h.exists(path) and path not in seen and depth < 8:
                        seen.add(path)
                        g = ix['files'].get(path) or F(h, path)
                        block(g, 0, len(g.m), l, depth + 1)
                    elif path:
                        h.unparse('I-ROUTES', f.rel, f.t, start, 'route include %s not found' % path)
                continue
            if reg:
                emit(f, start, reg, l, only, exc)

    def emit(f, start, reg, l, only, exc):
        name, ca, cb = reg
        lt = f.lits(ca, cb)
        if name in ('resource', 'apiResource', 'resources', 'apiResources'):
            pairs = []
            if name.endswith('s'):
                for km in re.finditer(r"'([\w./-]+)'\s*=>\s*([\w\\]+)::class", f.t[ca:cb]):
                    pairs.append((km.group(1), km.group(2).split('\\')[-1]))
            else:
                pairs.append((lt[0] if lt else '', (f.classrefs(ca, cb) or ['?'])[0]))
                opt = re.search(r"'(only|except)'\s*=>\s*\[([^\]]*)\]", f.t[ca:cb])
                if opt:
                    vals = re.findall(r"'(\w+)'", opt.group(2))
                    only, exc = (vals, exc) if opt.group(1) == 'only' else (only, vals)
            for res, ctl in pairs:
                segs = res.split('.')
                base = '/'.join(s + ('/{%s}' % s.rstrip('s') if i < len(segs) - 1 else '') for i, s in enumerate(segs))
                for act, verb, suf in RES:
                    if name.startswith('api') and act in ('create', 'edit'):
                        continue
                    if (only and act not in only) or (exc and act in exc):
                        continue
                    add(f, start, verb, base + suf, '%s@%s' % (ctl, act), l, ctl, act)
            return
        if name == 'fallback':
            add(f, start, ALL, '{*}', 'fallback', l, None, None, fallback=True)
            return
        if name == 'match':
            verbs = [v.upper() for v in re.findall(r"'(\w+)'", f.t[ca:h.close(f.m, f.m.find('[', ca)) if '[' in f.m[ca:cb] else ca])]
            lt = lt[len(verbs):]
        else:
            verbs = [ALL] if name == 'any' else ['GET'] if name in ('view', 'redirect', 'permanentRedirect') else [name.upper()]
        path = lt[0] if lt else ''
        ctl = act = None
        rest = f.m[ca:cb]
        am = re.search(r'\[\s*([\w\\]+)::class\s*,\s*\'', rest)
        if am:
            ctl, act = am.group(1).split('\\')[-1], (lt[1] if len(lt) > 1 else None)
        elif len(lt) > 1 and '@' in lt[1]:
            ctl, act = lt[1].split('@', 1)
            ctl = ctl.split('\\')[-1]
        elif f.classrefs(ca, cb):
            ctl, act = f.classrefs(ca, cb)[0], '__invoke'
        elif len(lt) > 1 and l.get('controller'):
            ctl, act = l['controller'], lt[1]
        handler = ('%s@%s' % (ctl, act)) if ctl else ('closure' if re.search(r'\b(?:function|fn)\b', rest) else name)
        for v in verbs:
            add(f, start, v, path, handler, l, ctl, act)

    def add(f, start, verb, path, handler, l, ctl, act, fallback=False):
        raw = '/'.join(s.strip('/') for s in l['prefix'] + [path] if s and s.strip('/'))
        params = re.findall(r'\{(\w+)\??\}', raw)
        cons = []
        for i, p in enumerate(params):
            t = l['where'].get(p) or ('int' if pats.get(p) in (r'[0-9]+', r'\d+') else 're' if p in pats else None)
            if t:
                cons.append('%d:%s' % (i + 1, t))
        npath, opt = h.norm_path(raw)
        uses = file_uses(f)    # `use App\Http\Controllers\Admin\UserController as AdminUserController;`
        ctl_c = (ix['fqn'].get(uses[ctl]) if ctl in uses else None) or (ix['classes'].get(ctl) if ctl else None)
        out.append({'key': '%s %s' % (verb, npath), 'verb': verb, 'path': npath, 'f': f, 'i': start,
                    'handler': handler, 'ctl': ctl, 'ctl_c': ctl_c, 'act': act, 'mw': [m for m in l['mw'] if m not in l['without']],
                    'opt': str(opt), 'constraint': ','.join(cons), 'fallback': fallback})

    for ent in entries(root, h, ix):
        rel, pre, grp = ent[0], ent[1], ent[2]
        if not h.exists(rel):
            continue
        f = ix['files'].get(rel) or F(h, rel)
        a, b = ent[3] if len(ent) > 3 else (0, len(f.m))
        seen.add(rel)
        block(f, a, b, {'prefix': [pre], 'mw': list(grp), 'without': [], 'where': {}, 'controller': None})
    ctx['routes'] = out
    return out


def lane_routes(root, h, ctx):
    rows = []
    for r in routes(root, h, ctx):
        at = {'handler': r['handler'], 'opt': r['opt'], 'constraint': r['constraint']}
        if r['fallback']:
            at['fallback'] = 'yes'
        rows.append(h.row(r['key'], at, r['f'].rel, r['f'].t, r['i']))
    return rows


# ---------------------------------------------------------------- authz
def aliases(root, h, ix):
    al, groups = {}, {'api': [], 'web': []}
    for rel in ('bootstrap/app.php', 'app/Http/Kernel.php'):
        if not h.exists(rel):
            continue
        f = ix['files'].get(rel) or F(h, rel)
        for km in re.finditer(r"'([\w.\-]+)'\s*=>\s*\\?([\w\\]+)::class", f.t):
            al[km.group(1)] = km.group(2).split('\\')[-1]
        for gm in re.finditer(r"(?:\$middleware->(api|web)\(\s*(?:append|prepend)\s*:|appendToGroup\(\s*'(api|web)'\s*,|'(api|web)'\s*=>)\s*\[", f.m):
            a = gm.end() - 1
            groups[gm.group(1) or gm.group(2) or gm.group(3)] += mw_list(f, a, h.close(f.m, a))
    return al, groups


def guards_of(mw, al, groups):
    authn, abil, roles, extra = 'none', set(), set(), 'no'
    flat = []
    for m in mw:
        flat += groups.get(m, []) if m in groups else [m]
        if m in groups:
            flat.append(m)
    for m in flat:
        name, _, arg = m.partition(':')
        cls = al.get(name, name)
        if re.match(r'^(auth(\.basic|\.session)?|Authenticate\w*)$', name) or re.search(r'Authenticate', cls):
            authn = 'required'
        elif name == 'can':
            parts = arg.split(',')
            abil.add(parts[0] + ('.' + parts[1].lstrip('$') if len(parts) > 1 and parts[1] else ''))
        elif name in ('permission', 'role', 'role_or_permission'):
            for x in re.split(r'[|]', arg):
                (roles if name == 'role' else abil).add(x)
        elif not NON_GUARD.match(name) and not NON_GUARD.match(cls):
            extra = 'yes'
    return authn, abil, roles, extra


def ctl_mw(c, act):
    """Controller-level middleware for one action: __construct $this->middleware()->only/except, HasMiddleware."""
    f, out = c['f'], []
    ctor = c['methods'].get('__construct')
    if ctor:
        for mm in re.finditer(r'\$this->middleware\(', f.m[ctor[1]:ctor[2]]):
            a = ctor[1] + mm.end() - 1
            e = f.m.find(';', a)
            names = f.lits(a, f.m.find(')', a) + 1)
            seg = f.t[a:e]
            om = re.search(r'->(only|except)\(\s*\[?([^\])]*)', seg)
            acts = re.findall(r"'(\w+)'", om.group(2)) if om else None
            if acts is None or (om.group(1) == 'only') == (act in acts):
                out += names[:1]
    sm = c['methods'].get('middleware')
    if sm:
        seg = f.m[sm[1]:sm[2]]
        for nm in re.finditer(r"new\s+Middleware\(", seg):
            a = sm[1] + nm.end() - 1
            e = f.m.find(')', a)
            txt = f.t[a:e + 1]
            lt = f.lits(a, e + 1)
            om = re.search(r'\b(only|except)\s*:\s*\[([^\]]*)\]', txt)
            acts = re.findall(r"'(\w+)'", om.group(2)) if om else None
            if lt and (acts is None or (om.group(1) == 'only') == (act in acts)):
                out.append(lt[0])
        stripped = re.sub(r'new\s+Middleware\([^)]*\)', '', f.t[sm[1]:sm[2]])
        out += re.findall(r"^\s*'([\w:.,|\-]+)'\s*,?\s*$", stripped, re.M)
    return out


def body_abilities(c, act, rq):
    f, ab = c['f'], set()
    ba = body(c, act) if act else None
    if ba:
        seg = f.t[ba[0]:ba[1]]
        for am in re.finditer(r"\$this->authorize\(\s*'([\w.\-:]+)'\s*(?:,\s*\$?(\w+))?", seg):
            ab.add(am.group(1) + ('.' + am.group(2).lower() if am.group(2) else ''))
        for am in re.finditer(r"\bGate::(?:authorize|allows|denies|check|inspect)\(\s*'([\w.\-:]+)'", seg):
            ab.add(am.group(1))
        for am in re.finditer(r"->can(?:not)?\(\s*'([\w.\-:]+)'", seg):
            ab.add(am.group(1))
    ctor = c['methods'].get('__construct')
    if ctor and act in RES_ABILITY:
        am = re.search(r"authorizeResource\(\s*([\w\\]+)::class(?:\s*,\s*'(\w+)')?", f.t[ctor[1]:ctor[2]])
        if am:
            ab.add('%s.%s' % (RES_ABILITY[act], (am.group(2) or am.group(1).split('\\')[-1]).lower()))
    if rq:
        au = body(rq, 'authorize')
        if au:
            for am in re.finditer(r"->can\(\s*'([\w.\-:]+)'", rq['f'].t[au[0]:au[1]]):
                ab.add(am.group(1))
    return ab


def form_request(ix, c, act):
    m = c['methods'].get(act) if c and act else None
    if not m:
        return None
    sig = c['f'].m[m[3]:m[4]]
    for tm in re.finditer(r'([A-Z]\w*)\s+\$\w+', sig):
        rc = ix['classes'].get(tm.group(1))
        if rc and 'rules' in rc['methods']:
            return rc
    return None


def lane_authz(root, h, ctx):
    ix = index(root, h, ctx)
    al, groups = aliases(root, h, ix)
    rows = []
    for r in routes(root, h, ctx):
        c = r['ctl_c']
        mw = list(r['mw']) + (ctl_mw(c, r['act']) if c else [])
        authn, abil, roles, extra = guards_of(mw, al, groups)
        if c:
            abil |= body_abilities(c, r['act'], form_request(ix, c, r['act']))
        rows.append(h.row(r['key'], {'authn': authn, 'abilities': ','.join(sorted(h.ability(x) for x in abil)),
                                     'roles': ','.join(sorted(x.lower() for x in roles)), 'extra_guard': extra,
                                     'mw': ','.join(mw)}, r['f'].rel, r['f'].t, r['i']))
    return rows


# ---------------------------------------------------------------- rules
def enum_values(ix, name):
    c = ix['classes'].get(name)
    if not c or c['kind'] != 'enum':
        return None
    f, vals = c['f'], []
    for cm in re.finditer(r'\bcase\s+(\w+)\s*(?:=\s*([^;]+))?;', f.m[c['a']:c['b']]):
        a = c['a'] + cm.start(2) if cm.group(2) else None
        v = f.lit(a, c['a'] + cm.end()) if a else None
        vals.append(v if v is not None else (cm.group(2).strip() if cm.group(2) else cm.group(1)))
    return vals


def rule_attrs(tokens, ix):
    at = {'presence': 'optional', 'nullable': 'no', 'type': '?', 'format': '', 'max': '', 'min': '', 'in': '', 'regex': ''}
    tl = [t.split(':', 1)[0] for t in tokens]
    if 'required' in tl or 'present' in tl:
        at['presence'] = 'required'
    if any(t.startswith(('required_', 'present_', 'prohibited', 'exclude_')) for t in tl):
        at['presence'] = 'conditional'
    if 'sometimes' in tl and at['presence'] == 'required':
        at['presence'] = 'optional'
    if 'nullable' in tl:
        at['nullable'] = 'yes'
    for t in tokens:
        n, _, arg = t.partition(':')
        if n in ('string', 'array', 'date', 'file', 'json'):
            at['type'] = {'json': 'string'}.get(n, n)
        elif n in ('integer', 'int'):
            at['type'] = 'int'
        elif n in ('numeric', 'decimal'):
            at['type'] = 'number'
        elif n in ('boolean', 'bool', 'accepted'):
            at['type'] = 'bool'
        elif n in ('image', 'mimes', 'mimetypes'):
            at['type'] = 'file'
        elif n in ('date_format',):
            at['type'] = 'date'
        elif n in ('email', 'uuid', 'url', 'ulid'):
            at['format'] = n
        elif n in ('max', 'min', 'size'):
            for k in (('max', 'min') if n == 'size' else (n,)):
                at[k] = arg
        elif n == 'between':
            at['min'], _, at['max'] = arg.partition(',')
        elif n == 'in':
            at['in'] = ','.join(sorted(set(x.strip('"\'') for x in arg.split(','))))
        elif n == 'regex':
            at['regex'] = re.sub(r'^/(.*)/[a-z]*$', r'\1', arg)
        elif n == '@enum':
            v = enum_values(ix, arg)
            at['in'] = ','.join(sorted(v)) if v is not None else '?'
    if at['format'] and at['type'] == '?':
        at['type'] = 'string'
    if at['presence'] == 'required' and at['type'] in ('string', 'array') and not (at['min'] or at['format'] or at['in']):
        at['min'] = '1'   # `required` rejects '' and [] (and ConvertEmptyStringsToNull turns '' into null first)
    return at


def rules_array(f, h, ix, a, b):
    """[(field, tokens, idx)] from a PHP rules array literal [a,b] (a at '[')."""
    out = []
    for km in re.finditer(r"'([\w.*\-]+)'\s*=>", f.t[a:b]):
        if f.m[a + km.start()] != "'":
            continue
        va = a + km.end()
        vb = va
        while vb < b and f.m[vb] != ',':
            vb = h.close(f.m, vb) + 1 if f.m[vb] in '([{' else vb + 1
        seg_m = f.m[va:vb]
        toks = []
        if re.match(r'\s*\[', seg_m):
            for x in f.lits(va, vb):
                toks += x.split('|')
        else:
            lt = f.lits(va, vb)
            toks += lt[0].split('|') if lt else []
        for em in re.finditer(r'(?:Rule::enum|new\s+(?:[\w\\]*\\)?Enum)\(\s*([\w\\]+)::class', seg_m):
            toks.append('@enum:' + em.group(1).split('\\')[-1])
        im = re.search(r'Rule::in\(', seg_m)
        if im:
            ia = va + im.end() - 1
            toks.append('in:' + ','.join(f.lits(ia, h.close(f.m, ia))))
        if re.search(r'Rule::unique\(', seg_m):
            toks.append('unique')
        out.append((km.group(1), [t for t in toks if t], a + km.start()))
    return out


READ = re.compile(r"\$request->(input|query|integer|get|boolean|string|array|float)\(\s*'(\w+)'\s*(?:,\s*([^)]*))?\)")


def hand_reads(f, a, b):
    """Query/body params a handler reads by hand (no rule): `min((int) $request->input('per_page', 25), 100)` is
    optional, int, `clamp_max=100` (coerced, never rejected, so not the compared `max`). A paginator reads `page`
    (int, `clamp_min=1`: below 1 becomes 1)."""
    out, t = [], f.t
    for m in READ.finditer(t, a, b):
        if f.m[m.start()] != '$':
            continue
        pre, post = t[max(a, m.start() - 24):m.start()], t[m.end():m.end() + 24]
        typ = {'integer': 'int', 'boolean': 'bool', 'array': 'array', 'float': 'number', 'string': 'string'}.get(m.group(1), '?')
        typ = 'int' if re.search(r'\(int\)\s*$', pre) else 'array' if re.search(r'\(array\)\s*$', pre) else typ
        at = {'presence': 'optional', 'nullable': 'no', 'type': typ, 'format': '', 'max': '', 'min': '', 'in': '', 'regex': '',
              'src': 'hand-read', 'default': (m.group(3) or '').strip()}
        w = re.search(r'\b(min|max)\(\s*(?:\(\w+\)\s*)?$', pre)
        lim = re.match(r'\s*,\s*(-?\d+)\s*\)', post)
        if w and lim:   # a clamp coerces, it never rejects: kept beside, not in, the compared min/max
            at['clamp_max' if w.group(1) == 'min' else 'clamp_min'] = lim.group(1)
        out.append((m.group(2), at, m.start()))
    if re.search(r'->(?:paginate|simplePaginate)\(', f.m[a:b]) and not any(x[0] == 'page' for x in out):
        i = a + re.search(r'->(?:paginate|simplePaginate)\(', f.m[a:b]).start()
        out.append(('page', {'presence': 'optional', 'nullable': 'no', 'type': 'int', 'format': '', 'max': '', 'min': '',
                             'in': '', 'regex': '', 'src': 'paginator', 'clamp_min': '1'}, i))
    return out


def lane_rules(root, h, ctx):
    ix = index(root, h, ctx)
    rows = []
    for r in routes(root, h, ctx):
        c = r['ctl_c']
        if not c:
            continue
        srcs = []
        rq = form_request(ix, c, r['act'])
        if rq:
            rb = body(rq, 'rules')
            m = re.search(r'\breturn\s*\[', rq['f'].m[rb[0]:rb[1]])
            if m:
                a = rb[0] + m.end() - 1
                srcs.append((rq['f'], a, h.close(rq['f'].m, a)))
        ba = body(c, r['act'])
        if ba:
            for vm in re.finditer(r'(?:->validate\(|Validator::make\([^,]+,|\$this->validate\([^,]+,)\s*\[', c['f'].m[ba[0]:ba[1]]):
                a = ba[0] + vm.end() - 1
                srcs.append((c['f'], a, h.close(c['f'].m, a)))
        seen = set()
        for f, a, b in srcs:
            for field, toks, i in rules_array(f, h, ix, a, b):
                seen.add(field)
                at = rule_attrs(toks, ix)
                if field.endswith('.*'):
                    at['presence'] = '?'   # an element rule: presence is the array's, not the element's
                rows.append(h.row('%s %s' % (r['key'], field), at, f.rel, f.t, i))
        if ba:
            for field, at, i in hand_reads(c['f'], ba[0], ba[1]):
                if field not in seen:
                    seen.add(field)
                    rows.append(h.row('%s %s' % (r['key'], field), at, c['f'].rel, c['f'].t, i))
    mj = major(h)
    ba = h.read('bootstrap/app.php') if h.exists('bootstrap/app.php') else ''
    kern = h.read('app/Http/Kernel.php') if h.exists('app/Http/Kernel.php') else ''
    for key, cls in (('trim_strings', 'TrimStrings'), ('empty_to_null', 'ConvertEmptyStringsToNull')):
        if kern and re.search(r'protected\s+\$middleware\s*=', kern):
            on = 'yes' if re.search(r'\b%s::class' % cls, kern.split('$middlewareGroups')[0]) else 'no'
            src, txt = 'app/Http/Kernel.php', kern
        elif mj is not None and mj >= 11:
            on = 'no' if re.search(r'->remove\(\s*\[?[^)]*\b%s::class' % cls, ba) else 'yes'
            src, txt = 'bootstrap/app.php', ba
        else:
            on, src, txt = '?', None, ''
        pos = max(txt.find('withMiddleware') if src == 'bootstrap/app.php' else txt.find('$middleware'), 0)
        rows.append(h.row('GLOBAL ' + key, {'on': on, 'src': 'laravel %s default' % (mj or '?')}, src, txt, pos))
    return rows


# ---------------------------------------------------------------- enums
def model_table(c):
    p = c['props'].get('table')
    if p:
        v = c['f'].lit(*p)
        if v:
            return v
    return c['name']


def is_model(ix, c, depth=0):
    if c['parent'] in ('Model', 'Authenticatable', 'Pivot', 'User'):
        return True
    p = ix['classes'].get(c['parent'])
    return bool(p and depth < 4 and p is not c and is_model(ix, p, depth + 1))


def lane_enum(root, h, ctx):
    ix = index(root, h, ctx)
    rows = []
    for c in ix['classes'].values():
        if c['kind'] == 'enum':
            vals = enum_values(ix, c['name'])
            rows.append(h.row('type:' + h.ident(c['name'], ENUM_STRIP),
                              {'values': ','.join(sorted(set(vals))), 'names': c['name']}, c['f'].rel, c['f'].t, c['start']))
        elif c['kind'] == 'class' and is_model(ix, c) and 'casts' in c['props']:
            f = c['f']
            a, b = c['props']['casts']
            for cm in re.finditer(r"'(\w+)'\s*=>\s*([\w\\]+)::class", f.t[a:b]):
                vals = enum_values(ix, cm.group(2).split('\\')[-1])
                if vals is not None:
                    rows.append(h.row('col:%s.%s' % (h.table(model_table(c)), cm.group(1)),
                                      {'values': ','.join(sorted(set(vals))), 'names': cm.group(2).split('\\')[-1]}, f.rel, f.t, a + cm.start()))
    for rel in h.files(['**/database/migrations/*.php'], keep=('migrations',)):
        f = F(h, rel)
        for sm in re.finditer(r"Schema::(?:create|table)\(\s*'(\w+)'", f.t):
            fa = f.m.find('{', sm.end())
            fb = h.close(f.m, fa) if fa > 0 else fa
            for em in re.finditer(r"->enum\(\s*'(\w+)'\s*,\s*\[", f.m[fa:fb]):
                a = fa + em.end() - 1
                rows.append(h.row('col:%s.%s' % (h.table(sm.group(1)), em.group(1)),
                                  {'values': ','.join(sorted(set(f.lits(a, h.close(f.m, a))))), 'names': 'migration'}, rel, f.t, fa + em.start()))
    return rows


# ---------------------------------------------------------------- errors
def status_in(seg):
    m = re.search(r'(?:->json\([^;]*?,\s*|response\([^;]*?,\s*|abort\(\s*|setStatusCode\(\s*|status\s*:\s*)(\d{3})\b', seg)
    if m:
        return m.group(1)
    m = re.search(r'Response::HTTP_(\w+)', seg)
    return {'UNPROCESSABLE_ENTITY': '422', 'CONFLICT': '409', 'NOT_FOUND': '404', 'FORBIDDEN': '403', 'BAD_REQUEST': '400',
            'UNAUTHORIZED': '401', 'TOO_MANY_REQUESTS': '429', 'GONE': '410', 'LOCKED': '423'}.get(m.group(1)) if m else None


def code_key(seg):
    """An error that renders a machine `code` is keyed by it (`code:order_not_editable`): V2 often throws one
    parametric error class (`new DomainError(409, msg, 'order_not_editable')`) where V1 had one class per error."""
    m = re.search(r"'(?:code|error_code)'\s*=>\s*'([\w.\-]+)'", seg)
    return 'code:' + m.group(1) if m else None


def err_key(h, cls):
    base = {'ValidationException': 'validation', 'ModelNotFoundException': 'not_found', 'NotFoundHttpException': 'not_found',
            'AuthenticationException': 'unauthenticated', 'AuthorizationException': 'forbidden',
            'AccessDeniedHttpException': 'forbidden'}
    return base.get(cls) or 'exc:' + h.ident(cls, ('exception', 'error', 'http'))


def lane_err(root, h, ctx):
    ix = index(root, h, ctx)
    found = {'validation': '422', 'not_found': '404', 'forbidden': '403'}
    src = {}
    if any(guards_of(r['mw'], {}, {})[0] == 'required' for r in routes(root, h, ctx)):
        found['unauthenticated'] = '401'
    for rel in ('bootstrap/app.php', 'app/Exceptions/Handler.php'):
        if not h.exists(rel):
            continue
        f = ix['files'].get(rel) or F(h, rel)
        for cm in re.finditer(r'function\s*\(\s*\\?([\w\\]*(?:Exception|Error|Throwable))\s+\$\w+[^)]*\)\s*(?:use\s*\([^)]*\)\s*)?(?::\s*[\w\\?]+\s*)?\{', f.m):
            a = cm.end() - 1
            seg = f.t[a:h.close(f.m, a)]
            st = status_in(seg)
            if st:
                k = code_key(seg) or err_key(h, cm.group(1).split('\\')[-1])
                found[k], src[k] = st, (f, cm.start())
        for im in re.finditer(r'instanceof\s+\\?([\w\\]+)\s*\)', f.m):
            a = f.m.find('{', im.end())
            seg = f.t[a:h.close(f.m, a)] if a > 0 else ''
            st = status_in(seg) if a > 0 else None
            if st:
                k = code_key(seg) or err_key(h, im.group(1).split('\\')[-1])
                found[k], src[k] = st, (f, im.start())
    for c in ix['classes'].values():
        if c['kind'] != 'class' or not re.search(r'Exception$|Error$', c['name']):
            continue
        st = None
        if 'render' in c['methods']:
            st = status_in(c['f'].t[slice(*body(c, 'render'))])
        pm = re.match(r'(\w+?)HttpException$', c['parent'])
        if not st and pm and pm.group(1) in SYMFONY:
            st = SYMFONY[pm.group(1)]
        if not st and c['parent'] == 'HttpException':
            mm = re.search(r'parent::__construct\(\s*(\d{3})', c['f'].t[c['a']:c['b']])
            st = mm.group(1) if mm else None
        k = code_key(c['f'].t[c['a']:c['b']]) or err_key(h, c['name'])
        if st and k not in src:
            found[k], src[k] = st, (c['f'], c['start'])
    rows = []
    for k, st in sorted(found.items()):
        f, i = src.get(k, (None, 0))
        rows.append(h.row(k, {'status': st, 'envelope': 'errors-map' if k == 'validation' else '-',
                              'src': 'custom' if f else 'framework default'}, f.rel if f else None, f.t if f else '', i))
    return rows


# ---------------------------------------------------------------- side effects
def lane_side(root, h, ctx):
    ix = index(root, h, ctx)
    eff = {}

    def put(key, ks, f, i):
        if ks:
            e = eff.setdefault(key, [set(), f, i])
            e[0] |= ks
    observers = {}
    for c in ix['classes'].values():
        f = c['f']
        if c['kind'] == 'class' and is_model(ix, c):
            pre = f.m[max(0, c['start'] - 600):c['start']]
            for am in re.finditer(r'#\[ObservedBy\((.*?)\)\]', pre):
                for o in re.findall(r'([\w\\]+)::class', am.group(1)):
                    observers.setdefault(c['name'], []).append(o.split('\\')[-1])
            tbl = h.table(model_table(c))
            for t, k in (('LogsActivity', 'activity'), ('Searchable', 'search')):
                if t in c['traits']:
                    for ev in ('created', 'updated', 'deleted'):
                        put('%s.%s' % (tbl, ev), {k}, f, c['start'])
            for bm in ('booted', 'boot'):
                bb = body(c, bm)
                if bb:
                    for cm in re.finditer(r'static::(\w+)\(\s*(?:function|fn)\b', f.m[bb[0]:bb[1]]):
                        a = f.m.find('{', bb[0] + cm.end())
                        if cm.group(1) in EVENTS and 0 < a < bb[1]:
                            put('%s.%s' % (tbl, cm.group(1).lower()), kinds(ix, c, a, h.close(f.m, a)), f, bb[0] + cm.start())
            if 'dispatchesEvents' in c['props']:
                a, b = c['props']['dispatchesEvents']
                for em in re.finditer(r"'(\w+)'\s*=>\s*([\w\\]+)::class", f.t[a:b]):
                    put('%s.%s' % (tbl, em.group(1)), {'event'}, f, a + em.start())
        for om in re.finditer(r'\b([A-Z]\w*)::observe\(\s*([\w\\]+)::class', f.m):
            observers.setdefault(om.group(1), []).append(om.group(2).split('\\')[-1])
        if 'observers' in c['props']:
            a, b = c['props']['observers']
            for om in re.finditer(r'([\w\\]+)::class\s*=>\s*\[?\s*([\w\\]+)::class', f.t[a:b]):
                observers.setdefault(om.group(1).split('\\')[-1], []).append(om.group(2).split('\\')[-1])
    for model, obs in observers.items():
        mc = ix['classes'].get(model)
        tbl = h.table(model_table(mc) if mc else model)
        for o in obs:
            oc = ix['classes'].get(o)
            for ev in (EVENTS if oc else ()):
                ob = body(oc, ev)
                if ob:
                    put('%s.%s' % (tbl, ev.lower()), kinds(ix, oc, ob[0], ob[1]), oc['f'], oc['methods'][ev][3])
    listen = {}
    for c in ix['classes'].values():
        if 'listen' in c['props']:
            a, b = c['props']['listen']
            f = c['f']
            for lm in re.finditer(r'([\w\\]+)::class\s*=>\s*\[', f.t[a:b]):
                la = a + lm.end() - 1
                listen.setdefault(lm.group(1).split('\\')[-1], []).extend(f.classrefs(la, h.close(f.m, la)))
        hb = body(c, 'handle')
        if hb and '/Listeners/' in '/' + c['f'].rel:
            sig = c['f'].m[c['methods']['handle'][3]:c['methods']['handle'][4]]
            em = re.search(r'\(\s*([A-Z]\w*)\s+\$', sig)
            if em:
                listen.setdefault(em.group(1), []).append(c['name'])
    for ev, ls in listen.items():
        for l in set(ls):
            lc = ix['classes'].get(l)
            hb = body(lc, 'handle') if lc else None
            if hb:
                put('event:' + h.ident(ev, ('event',)), kinds(ix, lc, hb[0], hb[1]) or {'listener'}, lc['f'], lc['start'])
    for r in routes(root, h, ctx):
        c = r['ctl_c']
        ba = body(c, r['act']) if c and r['act'] else None
        if ba:
            put(r['key'], kinds(ix, c, ba[0], ba[1]), r['f'], r['i'])
    for table, event, kind, rel, i in h.db_objects()['effects']:   # an AFTER trigger that writes the audit row
        put('%s.%s' % (h.table(table), event), {kind}, F(h, rel), i)
    return [h.row(k, {'kinds': ','.join(sorted(v[0]))}, v[1].rel, v[1].t, v[2]) for k, v in sorted(eff.items())]


# ---------------------------------------------------------------- schedule
FREQ = {'everySecond': '* * * * * *', 'everyMinute': '* * * * *', 'everyTwoMinutes': '*/2 * * * *',
        'everyThreeMinutes': '*/3 * * * *', 'everyFourMinutes': '*/4 * * * *', 'everyFiveMinutes': '*/5 * * * *',
        'everyTenMinutes': '*/10 * * * *', 'everyFifteenMinutes': '*/15 * * * *', 'everyThirtyMinutes': '0,30 * * * *',
        'hourly': '0 * * * *', 'everyTwoHours': '0 */2 * * *', 'everyThreeHours': '0 */3 * * *',
        'everyFourHours': '0 */4 * * *', 'everySixHours': '0 */6 * * *', 'daily': '0 0 * * *', 'weekly': '0 0 * * 0',
        'monthly': '0 0 1 * *', 'quarterly': '0 0 1 1-12/3 *', 'yearly': '0 0 1 1 *'}


def sched_cron(chain, lits):
    cr, tz, ov = None, '', 'no'
    for name, args in chain:
        a = lits(args)
        if name in FREQ:
            cr = FREQ[name].split()
        elif name == 'cron' and a:
            cr = a[0].split()
        elif name in ('dailyAt', 'at') and a:
            hh, _, mm = a[0].partition(':')
            cr = (cr if name == 'at' and cr else ['0', '0', '*', '*', '*'])
            cr[0], cr[1] = str(int(mm or 0)), str(int(hh))
        elif name == 'hourlyAt':
            n = re.findall(r'\d+', args)
            cr = [n[0] if n else '0', '*', '*', '*', '*']
        elif name == 'twiceDaily':
            n = re.findall(r'\d+', args) or ['1', '13']
            cr = ['0', ','.join(n[:2]), '*', '*', '*']
        elif name in ('weeklyOn', 'monthlyOn'):
            n = re.findall(r'\d+', args)
            t = (a[0] if a else '0:0').partition(':')
            cr = [str(int(t[2] or 0)), str(int(t[0] or 0)), n[0] if name == 'monthlyOn' and n else '*', '*',
                  n[0] if name == 'weeklyOn' and n else '*']
        elif name == 'weekdays' and cr:
            cr[4] = '1-5'
        elif name == 'weekends' and cr:
            cr[4] = '0,6'
        elif name in ('timezone',) and a:
            tz = a[0]
        elif name == 'withoutOverlapping':
            ov = 'yes'
    return (' '.join(cr) if cr else '?'), tz, ov


def lane_sched(root, h, ctx):
    ix = index(root, h, ctx)
    rows, files = [], []
    for rel in ('routes/console.php', 'app/Console/Kernel.php', 'bootstrap/app.php'):
        if h.exists(rel):
            files.append(ix['files'].get(rel) or F(h, rel))
    for f in files:
        for sm in re.finditer(r'(?:\$schedule\s*->|Schedule\s*::)\s*(command|job|call|exec)\s*\(', f.m):
            p = sm.end() - 1
            e = h.close(f.m, p)
            target, args0 = sm.group(1), (p + 1, e)
            chain = []
            while True:
                mm = re.compile(r'\s*->\s*(\w+)\s*\(').match(f.m, e + 1)
                if not mm:
                    break
                p = mm.end() - 1
                e = h.close(f.m, p)
                chain.append((mm.group(1), f.t[p + 1:e]))
            lt = f.lits(*args0)
            refs = f.classrefs(*args0) or re.findall(r'new\s+([\w\\]+)', f.m[args0[0]:args0[1]])
            name = dict(chain).get('name')
            if target == 'command' and lt:
                nm = lt[0].split()[0]
            elif refs:
                cc = ix['classes'].get(refs[0].split('\\')[-1])
                sig = cc and cc['props'].get('signature')
                nm = (cc['f'].lit(*sig) or '').split()[0] if sig else refs[0].split('\\')[-1]
            else:
                nm = (re.findall(r"'([^']+)'", name)[0] if name else 'call@%d' % h.line(f.t, sm.start()))
            cr, tz, ov = sched_cron(chain, lambda s: re.findall(r"'([^']*)'", s))
            rows.append(h.row('job:' + h.tokkey(nm, h.SCHED_DROP),
                              {'cron': h.cron(cr) if cr != '?' else '?', 'tz': tz, 'overlap': ov, 'target': nm}, f.rel, f.t, sm.start()))
    return rows


# ---------------------------------------------------------------- scopes
TENANT = re.compile(r'(?i)tenant|team|company|organi[sz]ation|\borg|account|workspace')


def lane_scope(root, h, ctx):
    ix = index(root, h, ctx)
    rows = []
    for c in ix['classes'].values():
        if c['kind'] != 'class' or not is_model(ix, c):
            continue
        f, traits, scopes, p = c['f'], list(c['traits']), [], ix['classes'].get(c['parent'])
        if p:
            traits += p['traits']
        pre = f.m[max(0, c['start'] - 600):c['start']]
        for am in re.finditer(r'#\[ScopedBy\((.*?)\)\]', pre):
            scopes += [x.split('\\')[-1] for x in re.findall(r'([\w\\]+)::class', am.group(1))]
        for bm in ('booted', 'boot'):
            bb = body(c, bm)
            if bb:
                for gm in re.finditer(r"addGlobalScope\(\s*(?:new\s+([\w\\]+)|'(\w+)'|([\w\\]+)::class)", f.t[bb[0]:bb[1]]):
                    scopes.append((gm.group(1) or gm.group(2) or gm.group(3)).split('\\')[-1])
        tenant = any(TENANT.search(x) for x in scopes + [t for t in traits if t != 'SoftDeletes'])
        rows.append(h.row('table:' + h.table(model_table(c)),
                          {'soft_delete': 'yes' if 'SoftDeletes' in traits else 'no', 'tenant': 'yes' if tenant else 'no',
                           'scopes': ','.join(sorted(set(scopes)))}, f.rel, f.t, c['start']))
    return rows


# ---------------------------------------------------------------- money, config
ROUND = [(r'\bround\s*\([^;]*PHP_ROUND_HALF_EVEN', 'half-even'), (r'\bround\s*\([^;]*PHP_ROUND_HALF_DOWN', 'half-down'),
         (r'\bround\s*\((?![^;]*PHP_ROUND_HALF_(?:EVEN|DOWN|ODD))', 'half-away'), (r'\bnumber_format\s*\(', 'half-away'),
         (r'\bbc(?:add|sub|mul|div|pow|sqrt|mod)\s*\(', 'trunc'), (r'\bfloor\s*\(', 'floor'), (r'\bceil\s*\(', 'ceil'),
         (r'RoundingMode::HALF_UP\b', 'half-away'), (r'RoundingMode::HALF_EVEN\b', 'half-even'),
         (r'RoundingMode::DOWN\b', 'trunc'), (r'\bintdiv\s*\(', 'trunc')]


def lane_money(root, h, ctx):
    """Rounding on money paths, keyed by area. Modes flow up the call graph (`$this->pricing->lineNet()`,
    `Money::allocate()`, `$this->round()`), and only the outermost money method is a row: a method another method
    calls is a helper, so the pairing follows the call target, not helper or file names."""
    ix = index(root, h, ctx)
    sites = {}
    for c in ix['classes'].values():
        types = promoted_types(c)
        for meth, (pe, a, b, s, _) in c['methods'].items():
            seg = c['f'].m[a:b]
            modes = set(m for rx, m in ROUND if re.search(rx, seg))
            calls = set()
            for cm in re.finditer(r'\$this->(\w+)->(\w+)\s*\(', seg):
                if cm.group(1) in types:
                    calls.add((types[cm.group(1)], cm.group(2)))
            for cm in re.finditer(r'\$this->(\w+)\s*\(', seg):
                calls.add((c['name'], cm.group(1)))
            for cm in re.finditer(r'\b([A-Z]\w*)::(\w+)\s*\(', seg):
                calls.add((cm.group(1), cm.group(2)))
            sites[(c['name'], meth)] = [c, meth, s, set(modes), calls]
    for _ in range(4):
        for k, v in sites.items():
            for call in v[4]:
                if call in sites and call != k:
                    v[3] |= sites[call][3]
    called = set(call for v in sites.values() for call in v[4] if call in sites and sites[call][3])
    rows = []
    for k, (c, meth, s, modes, calls) in sites.items():
        if modes and k not in called and MONEY.search(c['f'].rel + ' ' + c['name'] + ' ' + meth):
            rows.append(h.row(h.area(c['name'], c['f'].rel, meth), {'modes': ','.join(sorted(modes)), 'where': '%s::%s' % (c['name'], meth)},
                              c['f'].rel, c['f'].t, s))
    return rows


def env_default(h, var):
    env = h.read('.env.example') if h.exists('.env.example') else ''
    m = re.search(r'(?m)^%s=["\']?([^"\'\s#]*)' % var, env)
    return m.group(1) if m and m.group(1) else None


def lane_conf(root, h, ctx):
    ix = index(root, h, ctx)
    rows = []
    if h.exists('config/app.php'):
        f = ix['files'].get('config/app.php') or F(h, 'config/app.php')
        for key in ('timezone', 'locale'):
            m = re.search(r"'%s'\s*=>\s*(?:env\(\s*'(\w+)'\s*,\s*'([^']*)'\s*\)|'([^']*)')" % key, f.t)
            if m:
                val = (env_default(h, m.group(1)) if m.group(1) else None) or m.group(2) or m.group(3)
                rows.append(h.row(key, {'value': val, 'src': 'config/app.php' + (' + .env.example' if m.group(1) and env_default(h, m.group(1)) else '')}, f.rel, f.t, m.start()))
    pp, at, fixed = set(), None, 0
    for c in ix['classes'].values():
        f = c['f']
        for m in re.finditer(r'->(?:paginate|simplePaginate|cursorPaginate)\(', f.m[c['a']:c['b']]):
            p = c['a'] + m.end() - 1
            arg = f.t[p + 1:h.close(f.m, p)].strip()
            rd = re.search(r"'per_page'\s*,\s*(\d+)", arg)
            if not rd and re.match(r'\$\w+$', arg):   # $perPage = min((int) $request->input('per_page', 25), 100);
                rd = re.search(r"\%s\s*=[^;]*'per_page'\s*,\s*(\d+)" % arg, f.t[c['a']:c['b']])
            if rd:
                val = rd.group(1)
            elif not arg:   # Eloquent: the model's $perPage, else 15
                mm = re.search(r'\b([A-Z]\w*)::(?:query\(\)|with\(|where\(|latest\(|orderBy\()', f.m[max(c['a'], p - 400):p])
                mc = ix['classes'].get(mm.group(1)) if mm else None
                pv = mc and mc['props'].get('perPage')
                val = (re.search(r'\d+', mc['f'].m[slice(*pv)]).group(0) if pv else '15') if mc or not mm else '15'
            else:
                fixed += 1   # paginate(50): a fixed page size on one route, not a client-tunable default
                continue
            pp.add(val)
            at = at or (f, c['a'] + m.start())
    if fixed:
        h.notes.append('I-CONF per_page: %d fixed paginate(<n>) call(s) left out (a route default, read in I-RULES/SP §9)' % fixed)
    if pp:
        rows.append(h.row('per_page', {'value': ','.join(sorted(pp)), 'src': 'per_page request default / paginate() ($perPage, else Eloquent 15)'}, at[0].rel, at[0].t, at[1]))
    return rows


def lane_schema(root, h, ctx):
    return h.schema_map('laravel') + h.schema_extra()


LANES = {'laravel': {'I-SCHEMA': lane_schema, 'I-ROUTES': lane_routes, 'I-AUTHZ': lane_authz, 'I-RULES': lane_rules, 'I-ENUM': lane_enum,
                     'I-ERR': lane_err, 'I-SIDE': lane_side, 'I-SCHED': lane_sched, 'I-SCOPE': lane_scope,
                     'I-MONEY': lane_money, 'I-CONF': lane_conf}}
