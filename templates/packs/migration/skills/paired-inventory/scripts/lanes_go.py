"""lanes_go.py — Go (gin, echo, chi, gorilla/mux, net/http) lanes for pair-inventory.py.

Every lane in this module is `partial`: no paired fixture calibrates Go yet, so each candidate it produces is
tagged `partial`. Reads are static (rg listing through the core's H, masked text); nothing is imported or executed.
Shared readers, the k8s CronJob reader and the I-MONEY lane come from lanes_common.py (loaded by path).

What it reads
  gin, echo, chi, gorilla/mux, net/http (1.22 "METHOD /path"), Group/Route/PathPrefix prefixes, Use()/With()
  middleware, handler wrappers; typed const groups; handler bodies; robfig/cron, k8s CronJobs; rounding on money
  paths; TZ from Dockerfile / .env. A methodless pattern is one `ANY` row.
What it cannot see: routes built dynamically or through helpers in another package (a group handed to another
package keeps only a one-call prefix hop), middleware applied outside the router (a handler wrapped at http.Server
level), effects one call away from a handler, Go error mapping (I-ERR is a gap), validation (I-RULES), ORM scopes
(I-SCOPE), DDL (I-SCHEMA). What cannot be read is '?', never guessed.
"""
import importlib.util, os, re, sys

sys.dont_write_bytecode = True          # loading lanes_common must not drop __pycache__ into a repo
_spec = importlib.util.spec_from_file_location('lanes_common', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lanes_common.py'))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)

SCHED_DROP, _R, _args, _constraint, _funcs, _guard, _k8s, _lit = C.SCHED_DROP, C._R, C._args, C._constraint, C._funcs, C._guard, C._k8s, C._lit
_lits, _row, _src, _t = C._lits, C._row, C._src, C._t


# ---------------------------------------------------------------- go
GOV = re.compile(r'\b(\w+)((?:\.(?:With|Use)\((?:[^()\n]|\([^()\n]*\))*\))*)\.(GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD|Any|Get|Post|Put|Patch|Delete|'
                 r'Options|Head|Handle|HandleFunc|Method|MethodFunc)\(\s*(?=")')


def _go(h, ctx):
    if 'gofiles' not in ctx:
        ctx['gofiles'] = _src(h, ctx, ['*.go'])
    return ctx['gofiles']


def _scan_go(h, ctx):
    files, out = _go(h, ctx), []
    groups, ranges, uses = {}, [], {}
    fx = _fnindex(h, ctx, files, 'go')

    def gpre(rel, var, pos, d=0):
        g = groups.get((rel, var))
        if g and g[3] < pos and d < 8:
            pp, pm = gpre(rel, g[0], g[3], d + 1)
            return pp + g[1], pm + g[2] + [n for q, n in uses.get((rel, var), []) if q < pos]
        for rr, a, b, v, p, mw in sorted(ranges, key=lambda r: r[2] - r[1]):
            if rr == rel and a <= pos <= b and v in (None, var):
                return p, mw + [n for q, n in uses.get((rel, var), []) if a <= q < pos]
        return '', [n for q, n in uses.get((rel, var), []) if q < pos and not any(
            rr == rel and a <= q <= b and not a <= pos <= b for rr, a, b, v, p, mw in ranges)]

    def names(c, spans):
        return [(re.match(r'\s*([\w.]*)', c[s:e]).group(1) or '?', _lits(c[s:e]), True) for s, e in spans]
    for rel in files:
        t, m, c = _t(h, rel, 'c')
        for x in re.finditer(r'(\w+)\s*:?=\s*(\w+)\.(Group|PathPrefix)\(\s*"([^"]*)"|\b(\w+)\.(Route)\(\s*"([^"]*)"\s*,\s*func\s*\(\s*(\w+)'
                             r'|\b(\w+)\.Group\(\s*func\s*\(\s*(\w+)|\b(\w+)\.Use\(|\b(\w+)\.Mount\(\s*"([^"]*)"\s*,\s*([\w.]+)\(', c):
            if x.group(1):
                sp = _args(h, m, m.find('(', x.end(3)))
                groups[(rel, x.group(1))] = (x.group(2), x.group(4), names(c, sp[1:]) if x.group(3) == 'Group' else [], x.start())
            elif x.group(5) or x.group(9):
                pp, pm = gpre(rel, x.group(5) or x.group(9), x.start())
                a = m.find('{', x.end())
                ranges.append((rel, a, h.close(m, a), x.group(8) or x.group(10), pp + (x.group(7) or ''), pm))
            elif x.group(11):
                uses.setdefault((rel, x.group(11)), []).extend((x.start(), n) for n in names(c, _args(h, m, x.end() - 1)))
            else:
                f = fx.get(x.group(14).split('.')[-1])
                if f:
                    pp, pm = gpre(rel, x.group(12), x.start())
                    ranges.append((f[0], f[1], f[2], None, pp + x.group(13), pm))
    for rel in files:
        t, m, c = _t(h, rel, 'c')
        echo = 'labstack/echo' in m[:3000] or 'labstack/echo' in c[:3000]
        for x in GOV.finditer(m):
            var, chain, verb = x.group(1), x.group(2), x.group(3)
            sp = _args(h, m, m.find('(', x.end(3)))
            first = _lit(c[sp[0][0]:sp[0][1]]) if sp else None
            if first is None or not re.match(r'(?:[A-Z]+\s+)?(?:[\w.\-]*/|$)', first):
                continue
            meths, rest = None, sp[1:]
            if verb in ('Handle', 'Method', 'MethodFunc') and re.match(r'[A-Z]+$', first) and rest and _lit(c[rest[0][0]:rest[0][1]]) is not None:
                meths, path, rest = [first], _lit(c[rest[0][0]:rest[0][1]]), rest[1:]
            elif verb in ('Handle', 'HandleFunc'):
                y = re.match(r'([A-Z]+)\s+(\S*)$', first)
                meths, path = ([y.group(1)], y.group(2)) if y else (None, first)
                mm = re.compile(r'\s*\.\s*Methods\(([^)]*)\)').match(m, h.close(m, sp[0][0] - 1) + 1) if sp else None
                mc = c[mm.start(1):mm.end(1)] if mm else ''
                meths = meths or [s.upper() for s in _lits(mc)] or ['ANY']
                if '/' in path and not path.startswith('/'):
                    path = path[path.find('/'):]
                path = re.sub(r'\{(\w+)\.\.\.\}', r'*\1', path)
                if path.endswith('/') and '{' not in path[-3:] and meths == ['ANY']:
                    path += '*'
            else:
                meths, path = ['ANY' if verb == 'Any' else verb.upper()], first
            if not rest:
                continue
            hidx = 0 if echo else len(rest) - 1
            hs, he = rest[hidx]
            mws = names(c, [r for k, r in enumerate(rest) if k != hidx])
            inline = c[hs:he].strip().startswith('func')
            mws += [] if inline else [(n, [], True) for n in re.findall(r'([\w.]+)\(\s*[^)\s]', c[hs:he]) if not n.endswith('HandlerFunc')]
            for w in re.finditer(r'\.(?:With|Use)\(', m[x.start(2):x.end(2)]):
                mws += names(c, _args(h, m, x.start(2) + w.end() - 1))
            pp, pm = gpre(rel, var, x.start())
            hn = ['func'] if inline else re.findall(r'[\w.]+(?=\s*\(\s*\))|[\w.]+(?=\s*\)*\s*$)', c[hs:he].strip()) or ['?']
            f = None if inline else fx.get(hn[-1].split('.')[-1])
            body = (f[0], 'c', f[1], f[2]) if f else (rel, 'c', hs, he) if inline else None
            az = _guard(h, pm + mws)
            for mm in meths:
                out.append(_R(mm, pp + path, rel, x.start(), handler=hn[-1], con=_constraint(pp + path), az=az, body=body))
    return out


def go_enum(root, h, ctx):
    rows = []
    for rel in _go(h, ctx):
        t, m, c = _t(h, rel, 'c')
        typed = set(re.findall(r'^type\s+(\w+)\s+(?:string|u?int\d*)\b', m, re.M))
        for x in re.finditer(r'\bconst\s*\(', m):
            a, b = x.end() - 1, h.close(m, x.end() - 1)
            groups, cur, expr, k = {}, None, None, 0
            for ln in c[a + 1:b].split('\n'):
                y = re.match(r'\s*(\w+)(?:\s+(\w+))?(?:\s*=\s*(.+?))?\s*$', ln)
                if not y or not ln.strip():
                    continue
                if y.group(3) is not None:
                    cur, expr = y.group(2), y.group(3)
                elif y.group(2):
                    cur = y.group(2)
                if cur in typed and expr:
                    lv = _lit(expr)
                    v = lv if lv is not None else str(eval_iota(expr, k))
                    groups.setdefault(cur, []).append((y.group(1), v))
                k += 1
            for ty, items in groups.items():
                rows.append(_row(h, 'type:' + h.ident(ty, strip=('enum', 'choices', 'type', 'schema')),
                                 {'values': ','.join(sorted(set(v for _, v in items))), 'names': ','.join(n for n, _ in items)}, rel, x.start()))
    return rows


def eval_iota(expr, k):
    x = re.match(r'\s*iota\s*(?:([+-])\s*(\d+))?\s*$', expr)
    if x:
        return k + (int(x.group(2)) * (1 if x.group(1) == '+' else -1) if x.group(2) else 0)
    return expr.strip() if re.match(r'-?\d+$', expr.strip()) else '?'


def go_sched(root, h, ctx):
    rows = []
    for rel in _go(h, ctx):
        t, m, c = _t(h, rel, 'c')
        ov = 'yes' if re.search(r'SkipIfStillRunning|DelayIfStillRunning', m) else 'no'
        loc = re.search(r'LoadLocation\(\s*"([^"]+)"', c)
        for x in re.finditer(r'\b\w+\.Add(?:Func|Job)\(', m):
            sp = _args(h, m, x.end() - 1)
            spec = _lit(c[sp[0][0]:sp[0][1]]) if sp else None
            fn = c[sp[1][0]:sp[1][1]].strip() if len(sp) > 1 else ''
            if spec is None or not re.match(r'[\w.]+$', fn):
                h.unparse('I-SCHED', rel, t, x.start(), 'job spec or name not a literal/identifier')
                continue
            tz = re.match(r'(?:CRON_)?TZ=(\S+)\s+', spec)
            spec = spec[tz.end():] if tz else spec
            spec = {'@daily': '0 0 * * *', '@midnight': '0 0 * * *', '@hourly': '0 * * * *', '@weekly': '0 0 * * 0', '@monthly': '0 0 1 * *',
                    '@yearly': '0 0 1 1 *', '@annually': '0 0 1 1 *'}.get(spec, spec)
            rows.append(_row(h, 'job:' + h.tokkey(fn.split('.')[-1], SCHED_DROP), {'cron': '?' if spec.startswith('@') else h.cron(spec),
                             'tz': tz.group(1) if tz else loc.group(1) if loc else '', 'overlap': ov, 'target': 'robfig/cron ' + fn}, rel, x.start()))
    return rows + _k8s(h, ctx)


def _fnindex(h, ctx, files, lang):
    k = ('fnx', lang)
    if k not in ctx:
        ix = {}
        for rel in files:
            for f in _funcs(h, rel, lang):
                ix.setdefault(f[0], (rel, f[2], f[3]))
        ctx[k] = ix
    return ctx[k]


# ---------------------------------------------------------------- registry
STACKS = ('go',)
C.SCAN['go'] = _scan_go
LANES = C.drop_catchall({'go': dict(C.R3, **{'I-ENUM': go_enum, 'I-SIDE': C.lane_side, 'I-SCHED': go_sched, 'I-CONF': C.env_conf})})
PARTIAL = set((s, l) for s, ls in LANES.items() for l in ls)
GAPS = C.gaps(STACKS)


def detect(root, h):
    return C.detect_stacks(h, STACKS)


# ---------------------------------------------------------------- self-test: one tiny tree per stack, good rows + decoys
_L = C._L

SAMPLES = {
    'go': ({
        'go.mod': 'module x\n\nrequire (\n\tgithub.com/go-chi/chi/v5 v5.0.12\n\tgithub.com/robfig/cron/v3 v3.0.1\n)\n',
        'main.go': _L('package main', 'func main() {', '\tr := chi.NewRouter()', '\tr.Route("/api", func(r chi.Router) {', '\t\tr.Use(AuthMiddleware)',
                      '\t\tr.Get("/orders/{id:[0-9]+}", getOrder)', '\t\tr.With(RequireRole("admin")).Delete("/orders/{id}", deleteOrder)', '\t})',
                      '\tr.Get("/healthz", health)', '\t// r.Get("/ghost", ghost)', '\tc := cron.New()', '\tc.AddFunc("0 2 * * *", generateInvoices)', '}'),
        'handlers.go': _L('package main', 'func getOrder(w http.ResponseWriter, r *http.Request) {', '\tmailer.Send(msg)', '}',
                          'func lineTotal(p float64) float64 {', '\treturn math.Round(p*100) / 100', '}'),
        'status.go': _L('package main', 'type OrderStatus string', 'const (', '\tPending OrderStatus = "pending"', '\tPaid OrderStatus = "paid"', ')'),
        'main_test.go': 'package main\nfunc TestX() { r.Get("/test-only", h) }\n',
        'deploy/cron.yaml': _L('apiVersion: batch/v1', 'kind: CronJob', 'metadata:', '  name: report-nightly', 'spec:', '  schedule: "0 3 * * *"',
                               '  concurrencyPolicy: Forbid', '---', 'apiVersion: batch/v1', 'kind: CronJob', 'metadata:', '  name: legacy-billing',
                               'spec:', '  schedule: "*/5 * * * *"', '  jobTemplate:', '    spec:', '      template:', '        spec:',
                               '          containers:', '            - name: app', '              image: legacy:1',
                               '              command: ["php", "artisan", "schedule:run"]')},
        [('I-ROUTES', 'GET /api/orders/{}', {'constraint': '1:int', 'handler': 'getOrder'}), ('I-AUTHZ', 'GET /api/orders/{}', {'authn': 'required'}),
         ('I-AUTHZ', 'DELETE /api/orders/{}', {'authn': 'required', 'roles': 'admin'}), ('I-AUTHZ', 'GET /healthz', {'authn': '?'}),
         ('I-SIDE', 'GET /api/orders/{}', {'kinds': 'mail'}), ('I-SCHED', 'job:generate.invoice', {'cron': '0 2 * * *', 'overlap': 'no'}),
         ('I-SCHED', 'job:nightly.report', {'cron': '0 3 * * *', 'overlap': 'yes'}), ('I-MONEY', 'area:line', {'modes': 'half-away'}),
         ('I-ENUM', 'type:orderstatus', {'values': 'paid,pending'})],
        [('I-ROUTES', 'GET /ghost'), ('I-ROUTES', 'GET /test-only'), ('I-SCHED', 'job:billing.legacy')])}


def self_test(H, tmp):
    out = C.run_samples(H, tmp, SAMPLES, detect, LANES)
    root = os.path.join(tmp, 'other-go')            # written by run_samples
    ctx = {'stack': 'go', 'evidence': 'go.mod'}
    go_sched(root, H(root, 'v1'), ctx)
    note = [n for n in ctx.get('notes', []) if 'legacy-billing' in n and 'php' in n]
    out.append(('go I-SCHED k8s CronJob running php artisan skipped with a ledger note', bool(note), str(ctx.get('notes'))))
    return out
