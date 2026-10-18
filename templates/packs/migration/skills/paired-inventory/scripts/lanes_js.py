"""lanes_js.py — Express and Fastify lanes for pair-inventory.py (a Nest app is lanes_node.py's).

Every lane in this module is `partial`: no paired fixture calibrates these stacks yet, so each candidate they
produce is tagged `partial`. Reads are static (rg listing through the core's H, masked text); nothing is imported
or executed. Shared readers, the k8s CronJob reader and the I-MONEY lane come from lanes_common.py (loaded by path).

What it reads
  Router()/express() mounts across files, route and router middleware; fastify register() prefixes,
  preHandler/onRequest hooks; error middleware / setErrorHandler `instanceof` branches; handler bodies;
  node-cron, k8s CronJobs; TS enums; rounding on money paths; TZ from Dockerfile / .env. app.all is one `ANY` row.
What it cannot see: routes built dynamically or through helpers in another file, middleware applied outside the
router, effects one call away from a handler, validation (I-RULES is a gap), ORM scopes (I-SCOPE is a gap), DDL
(I-SCHEMA is a gap). What cannot be read is '?', never guessed.
"""
import importlib.util, os, re, sys

sys.dont_write_bytecode = True          # loading lanes_common must not drop __pycache__ into a repo
_spec = importlib.util.spec_from_file_location('lanes_common', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lanes_common.py'))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)

SCHED_DROP, _R, _args, _constraint, _errkey, _funcs, _guard, _k8s = C.SCHED_DROP, C._R, C._args, C._constraint, C._errkey, C._funcs, C._guard, C._k8s
_lit, _lits, _routes, _row, _src, _status, _t = C._lit, C._lits, C._routes, C._row, C._src, C._status, C._t


# ---------------------------------------------------------------- express / fastify
def _js(h, ctx):
    if 'jsfiles' not in ctx:
        ctx['jsfiles'] = _src(h, ctx, ['*.js', '*.ts', '*.mjs', '*.cjs'])
    return ctx['jsfiles']


def _scan_node(h, ctx):
    fast = ctx['stack'] == 'fastify'
    files = _js(h, ctx)
    fset = set(files)
    routers, alias, imports, defaults, mounts, uses, raw = {}, {}, {}, {}, [], {}, []

    def resolve_path(rel, spec):
        b = os.path.normpath(os.path.join(os.path.dirname(rel), spec))
        for cand in (b, b + '.ts', b + '.js', b[:-3] + '.ts' if b.endswith('.js') else '', b + '/index.ts', b + '/index.js', b + '.mjs'):
            if cand in fset:
                return cand
        return None
    for rel in files:
        t, m, c = _t(h, rel, 'c')
        if not re.search(r'express|fastify|Router\(|\.(?:get|post|route|register)\(', c):
            continue
        for x in re.finditer(r'\b(?:const|let|var)\s+(\w+)\s*(?::[^=\n]+)?=\s*(?:express\.Router|Router|express|fastify|Fastify|require\(\s*["\']express["\']\s*\))\s*\(', c):
            routers[(rel, x.group(1))] = 1
        for x in re.finditer(r'^\s*(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(\w+)\s*;?\s*$', m, re.M):
            alias[(rel, x.group(1))] = x.group(2)
        im = imports.setdefault(rel, {})
        for x in re.finditer(r'import\s+(\w+)?\s*,?\s*(?:\{([^}]*)\})?\s*from\s*["\'](\.[^"\']+)["\']|(?:const|let|var)\s+(?:(\w+)|\{([^}]*)\})\s*=\s*require\(\s*["\'](\.[^"\']+)["\']', c):
            p = resolve_path(rel, x.group(3) or x.group(6))
            if x.group(1) or x.group(4):
                im[x.group(1) or x.group(4)] = (p, 'default')
            for y in re.finditer(r'(\w+)(?:\s+as\s+(\w+)|\s*:\s*(\w+))?', x.group(2) or x.group(5) or ''):
                im[y.group(2) or y.group(3) or y.group(1)] = (p, y.group(1))
        d = re.search(r'export\s+default\s+(?:async\s+)?(?:function\s+)?(\w+)|module\.exports\s*=\s*(\w+)', c)
        if d:
            defaults[rel] = d.group(1) or d.group(2)

    def res(rel, var, d=0):
        if fast:
            return (rel, '*')
        if d > 6 or not rel:
            return None
        if (rel, var) in routers:
            return (rel, var)
        if (rel, var) in alias:
            return res(rel, alias[(rel, var)], d + 1)
        if var in imports.get(rel, {}):
            p, n = imports[rel][var]
            return res(p, defaults.get(p) if n == 'default' else n, d + 1)
        return None

    def mwnames(spans, c):
        return [(re.match(r'\s*([\w.]*)', c[s:e]).group(1) or '?', _lits(c[s:e]), True) for s, e in spans]
    for rel in files:
        t, m, c = _t(h, rel, 'c')
        for x in re.finditer(r'\b(\w+)\.(use|register)\(', m):
            sp = _args(h, m, x.end() - 1)
            if not sp:
                continue
            first = _lit(c[sp[0][0]:sp[0][1]])
            rest = sp[1:] if first is not None else sp
            if x.group(2) == 'register':
                spec = re.search(r'(?:import|require)\(\s*["\'](\.[^"\']+)', c[sp[0][0]:sp[0][1]])
                nm = c[sp[0][0]:sp[0][1]].strip()
                child = resolve_path(rel, spec.group(1)) if spec else imports.get(rel, {}).get(nm, (rel if re.search(r'function\s+%s\b' % re.escape(nm), c) else None,))[0]
                pf = re.search(r'prefix\s*:\s*["\']([^"\']*)', c[sp[-1][0]:sp[-1][1]]) if len(sp) > 1 else None
                if child:
                    mounts.append(((rel, '*'), pf.group(1) if pf else '', (child, '*'), [], x.start()))
                continue
            parent = res(rel, x.group(1)) or (rel, x.group(1))
            pre_mw = []
            for s, e in rest:
                k = res(rel, c[s:e].strip()) if re.match(r'\s*\w+\s*$', c[s:e]) else None
                if k and not fast:
                    mounts.append((parent, first or '', k, list(pre_mw), x.start()))
                else:
                    pre_mw += mwnames([(s, e)], c)
            if first is None and pre_mw and not any(mt[4] == x.start() for mt in mounts):
                uses.setdefault(parent, []).extend((x.start(), n) for n in pre_mw)
        for x in re.finditer(r'\b\w+\.addHook\(\s*["\'](onRequest|preHandler|preValidation)["\']\s*,', c):
            sp = _args(h, m, m.find('(', x.start()))
            uses.setdefault((rel, '*'), []).extend((0, n) for n in mwnames(sp[1:], c))
        for x in re.finditer(r'\b(\w+)\.(get|post|put|patch|delete|options|head|all)\(\s*(?=["\'`])', m):
            raw.append((rel, x, None))
        for x in re.finditer(r'\b(\w+)\.route\(\s*(?=["\'`{])', m):
            raw.append((rel, x, 'route'))

    def pref(key, seen=()):
        ps = [mt for mt in mounts if mt[2] == key]
        if not ps or key in seen:
            return [('', [])]
        return [(pp + mt[1], pm + [n for p, n in uses.get(mt[0], []) if p < mt[4]] + mt[3])
                for mt in ps for pp, pm in pref(mt[0], seen + (key,))]
    out, schema = [], False
    for rel, x, kind in raw:
        t, m, c = _t(h, rel, 'c')
        var = x.group(1)
        key = res(rel, var)
        if not key and not (fast and re.match(r'(fastify|app|server|instance|api|router|f|scope)$', var)) and not (
                var in ('app', 'router') and 'express' in c):
            continue
        key = key or (rel, var)
        items = []
        if kind == 'route' and m[m.find('(', x.start()) + 1:].lstrip().startswith('{'):
            a = m.find('{', x.start())
            o = c[a:h.close(m, a) + 1]
            mt = re.search(r'method\s*:\s*(\[[^\]]*\]|["\'][A-Za-z]+["\'])', o)
            url = re.search(r'(?:url|path)\s*:\s*["\']([^"\']*)', o)
            hooks = [(n, [], True) for v in re.findall(r'(?:preHandler|onRequest|preValidation)\s*:\s*(\[[^\]]*\]|[\w.]+)', o) for n in re.findall(r'[\w.]+', v)]
            schema = schema or 'schema' in o
            if url:
                items.append(([s.upper() for s in _lits(mt.group(1))] if mt else ['GET'], url.group(1), hooks, (a, h.close(m, a))))
        elif kind == 'route':
            a = m.find('(', x.start())
            p = _lit(c[a + 1:h.close(m, a)])
            j = h.close(m, a) + 1
            while p is not None:
                y = re.compile(r'\s*\.(get|post|put|patch|delete|options|head|all)\(').match(m, j)
                if not y:
                    break
                sp = _args(h, m, y.end() - 1)
                items.append(([y.group(1).upper()], p, mwnames(sp[:-1], c), sp[-1] if sp else None))
                j = h.close(m, y.end() - 1) + 1
        else:
            sp = _args(h, m, x.end() - 1)
            if len(sp) < 2:
                continue          # app.get('trust proxy') is a settings getter, not a route
            p, mws, body = _lit(c[sp[0][0]:sp[0][1]]), [], sp[-1]
            for s, e in sp[1:-1]:
                if c[s:e].strip().startswith('{'):
                    schema = schema or 'schema' in c[s:e]
                    mws += [(n, [], True) for v in re.findall(r'(?:preHandler|onRequest|preValidation)\s*:\s*(\[[^\]]*\]|[\w.]+)', c[s:e])
                            for n in re.findall(r'[\w.]+', v)]
                else:
                    mws += mwnames([(s, e)], c)
            items.append(([x.group(2).upper()], p or '', mws, body))
        for meths, p, mws, body in items:
            hname = c[body[0]:body[1]].strip() if body and re.match(r'\s*[\w.]+\s*$', c[body[0]:body[1]]) else 'inline'
            if body and re.match(r'\s*[\w.]+\s*$', c[body[0]:body[1]]):
                fb = [f for f in _funcs(h, rel, 'js') if f[0] == c[body[0]:body[1]].strip().split('.')[-1]]
                body = (fb[0][2], fb[0][3]) if fb else None
            for pp, pm in pref(key):
                inh = [n for q, n in uses.get(key, []) if q < x.start()]
                az = _guard(h, pm + inh + mws, known_none=True)
                for mm in (['ANY'] if meths == ['ALL'] else meths):
                    out.append(_R(mm, pp + p, rel, x.start(), handler=hname, con=_constraint(pp + p), az=az,
                                  body=(rel, 'c', body[0], body[1]) if body else None))
    ctx['schema'] = schema
    return out


def node_err(root, h, ctx):
    out, fast = {}, ctx['stack'] == 'fastify'
    _routes(h, ctx)
    seh = False
    for rel in _js(h, ctx):
        t, m, c = _t(h, rel, 'c')
        for x in re.finditer(r'\(\s*(?:err|error|e)\w*\s*(?::\s*[\w.]+)?\s*,\s*\w+\s*(?::\s*[\w.]+)?\s*,\s*\w+\s*(?::\s*[\w.]+)?\s*,\s*\w+\s*(?::\s*[\w.]+)?\s*\)\s*(?::\s*\w+\s*)?=>\s*\{'
                             r'|function\s*\w*\s*\(\s*(?:err|error)\w*[^,()]*,[^,()]*,[^,()]*,[^,()]*\)\s*\{|\.setErrorHandler\([^{]*\{', m):
            seh = seh or 'setErrorHandler' in x.group(0)
            a, b = x.end() - 1, h.close(m, x.end() - 1)
            for y in re.finditer(r'instanceof\s+([\w.]+)|\.name\s*===?\s*["\'](\w+)["\']|\b\w+\.(validation)\b', c[a:b]):
                i = a + y.start()
                br = m.find('{', i)
                seg = c[i:h.close(m, br)] if 0 <= br < m.find(';', i) else c[i:m.find(';', i)]
                st = _status(seg)
                k = _errkey(h, y.group(1) or y.group(2) or 'Validation')
                out.setdefault(k, _row(h, k, {'status': ','.join(sorted(st)) or '?', 'envelope': 'error handler'}, rel, i))
    if fast and ctx.get('schema') and not seh:
        out.setdefault('validation', {'key': 'validation', 'attrs': {'status': '400', 'envelope': 'FST_ERR_VALIDATION'}, 'at': '-',
                                      'excerpt': 'Fastify schema validation (framework default)'})
    return list(out.values())


def node_enum(root, h, ctx):
    rows = []
    for rel in _js(h, ctx):
        if not rel.endswith('.ts'):
            continue
        t, m, c = _t(h, rel, 'c')
        for x in re.finditer(r'\benum\s+(\w+)\s*\{', m):
            a, b = x.end() - 1, h.close(m, x.end() - 1)
            names, vals, n = [], [], 0
            for y in re.finditer(r'(\w+)\s*(?:=\s*(["\'][^"\']*["\']|-?\d+))?\s*(?:,|$)', c[a + 1:b].strip()):
                v = y.group(2)
                n = int(v) if v and v.lstrip('-').isdigit() else n
                names.append(y.group(1))
                vals.append(v.strip('"\'') if v and not v.lstrip('-').isdigit() else str(n))
                n += 1
            rows.append(_row(h, 'type:' + h.ident(x.group(1), strip=('enum', 'choices', 'type', 'schema')),
                             {'values': ','.join(sorted(set(vals))), 'names': ','.join(names)}, rel, x.start()))
    return rows


def node_sched(root, h, ctx):
    rows = []
    for rel in _js(h, ctx):
        t, m, c = _t(h, rel, 'c')
        for x in re.finditer(r'\bcron\.schedule\(|\bnew\s+CronJob\(', m):
            sp = _args(h, m, x.end() - 1)
            if len(sp) < 2:
                continue
            fn = c[sp[1][0]:sp[1][1]].strip()
            nm = re.search(r'name\s*:\s*["\']([^"\']+)', c[sp[-1][0]:sp[-1][1]])
            tz = re.search(r'timezone\s*:\s*["\']([^"\']+)', c[sp[-1][0]:sp[-1][1]]) or (len(sp) > 4 and re.match(r'\s*["\']([^"\']+)', c[sp[4][0]:sp[4][1]]))
            name = nm.group(1) if nm else fn if re.match(r'[\w.]+$', fn) else None
            if not name:
                h.unparse('I-SCHED', rel, t, x.start(), 'inline job function has no name')
                continue
            rows.append(_row(h, 'job:' + h.tokkey(name.split('.')[-1], SCHED_DROP), {'cron': h.cron(_lit(c[sp[0][0]:sp[0][1]]) or '?'),
                             'tz': tz.group(1) if tz else '', 'overlap': 'yes' if re.search(r'noOverlap\s*:\s*true', c[sp[-1][0]:sp[-1][1]]) else 'no',
                             'target': 'node-cron'}, rel, x.start()))
    return rows + _k8s(h, ctx)


# ---------------------------------------------------------------- registry
STACKS = ('express', 'fastify')
C.SCAN['express'] = _scan_node
C.SCAN['fastify'] = _scan_node
LANES = C.drop_catchall({'express': dict(C.R3, **{'I-ENUM': node_enum, 'I-ERR': node_err, 'I-SIDE': C.lane_side, 'I-SCHED': node_sched, 'I-CONF': C.env_conf}),
    'fastify': dict(C.R3, **{'I-ENUM': node_enum, 'I-ERR': node_err, 'I-SIDE': C.lane_side, 'I-SCHED': node_sched, 'I-CONF': C.env_conf})})
PARTIAL = set((s, l) for s, ls in LANES.items() for l in ls)
GAPS = C.gaps(STACKS)


def detect(root, h):
    return C.detect_stacks(h, STACKS)


# ---------------------------------------------------------------- self-test: one tiny tree per stack, good rows + decoys
_L = C._L

SAMPLES = {
    'express': ({
        'package.json': '{"dependencies": {"express": "4.19.2"}}',
        'Dockerfile': 'FROM node:22\nENV TZ=UTC\n',
        'src/app.js': _L("const express = require('express');", "const ordersRouter = require('./routes/orders');", "const app = express();",
                         "app.use('/api', requireAuth, ordersRouter);", "// app.get('/ghost', h);",
                         "app.use((err, req, res, next) => {", "  if (err instanceof ConflictError) { return res.status(409).json({}); }",
                         "  res.status(500).end();", "});", "app.all('*', (req, res) => res.status(404).end());"),
        'src/routes/orders.js': _L("const router = express.Router();", "router.get('/orders/:id(\\\\d+)', requireRole('admin'), show);",
                                   "router.post('/orders', async (req, res) => { await mailer.sendMail({}); });",
                                   "function show(req, res) { res.json({}); }", "module.exports = router;"),
        'src/jobs.js': "cron.schedule('0 2 * * *', generateInvoices, { timezone: 'Asia/Riyadh' });\n",
        'src/money.js': 'function orderTotal(a) { return Math.round(a * 100) / 100; }\n',
        'src/paging.js': 'function pageCount(n) { return Math.round(n / 2); }\n',
        'src/status.ts': "export enum OrderStatus { Pending = 'pending', Paid = 'paid' }\n",
        'src/status.test-data.ts': "export enum GhostStatus { A = 'a' }\n"},
        [('I-ROUTES', 'GET /api/orders/{}', {'constraint': '1:int'}), ('I-ROUTES', 'ANY /{*}', {'fallback': 'yes'}),
         ('I-AUTHZ', 'GET /api/orders/{}', {'authn': 'required', 'roles': 'admin'}), ('I-AUTHZ', 'POST /api/orders', {'authn': 'required', 'roles': ''}),
         ('I-SIDE', 'POST /api/orders', {'kinds': 'mail'}), ('I-ERR', 'exc:conflict', {'status': '409'}),
         ('I-SCHED', 'job:generate.invoice', {'cron': '0 2 * * *', 'tz': 'Asia/Riyadh'}), ('I-MONEY', 'area:money', {'modes': 'half-up'}),
         ('I-ENUM', 'type:orderstatus', {'values': 'paid,pending'}), ('I-CONF', 'timezone', {'value': 'UTC'})],
        [('I-ROUTES', 'GET /ghost'), ('I-ENUM', 'type:ghoststatus'), ('I-MONEY', 'area:page')]),
    'fastify': ({
        'package.json': '{"dependencies": {"fastify": "4.28.0"}}',
        'src/server.js': _L("import Fastify from 'fastify';", "import ordersRoutes from './orders.js';", "const app = Fastify();",
                            "app.register(ordersRoutes, { prefix: '/v1' });"),
        'src/orders.js': _L("export default async function ordersRoutes(fastify) {", "  fastify.addHook('onRequest', fastify.authenticate);",
                            "  fastify.get('/orders/:id', { schema: {} }, async (req) => ({}));",
                            "  fastify.post('/orders', async (req) => { await fastify.queue.add('x'); });", "}")},
        [('I-ROUTES', 'GET /v1/orders/{}', {}), ('I-AUTHZ', 'POST /v1/orders', {'authn': 'required'}), ('I-SIDE', 'POST /v1/orders', {'kinds': 'job'}),
         ('I-ERR', 'validation', {'status': '400'})],
        [('I-SIDE', 'GET /v1/orders/{}')])}


def self_test(H, tmp):
    return C.run_samples(H, tmp, SAMPLES, detect, LANES)
