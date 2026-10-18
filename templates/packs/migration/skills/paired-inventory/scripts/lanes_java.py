"""lanes_java.py — Spring (Boot, Java/Kotlin) lanes for pair-inventory.py.

Every lane in this module is `partial`: no paired fixture calibrates Spring yet, so each candidate it produces is
tagged `partial`. Reads are static (rg listing through the core's H, masked text); nothing is imported or executed.
Shared readers, the k8s CronJob reader and the I-MONEY lane come from lanes_common.py (loaded by path).

What it reads
  @RequestMapping + @Get/Post/...Mapping, @PathVariable types; @PreAuthorize/@Secured/@RolesAllowed,
  SecurityFilterChain requestMatchers (Boot's default is authenticate-everything when spring-security is a
  dependency); enums (+ ordinal storage); @ExceptionHandler/@ResponseStatus; JPA lifecycle callbacks,
  @EntityListeners, @EventListener, handler bodies; @Scheduled, k8s CronJobs; @Where/@SQLRestriction/@SQLDelete/
  @Filter/@TenantId; application.yml/.properties; rounding on money paths.
What it cannot see: routes built dynamically, filters registered outside the SecurityFilterChain, effects one call
away from a handler or callback, validation (I-RULES is a gap), DDL (I-SCHEMA is a gap). What cannot be read is
'?', never guessed.
"""
import importlib.util, os, re, sys

sys.dont_write_bytecode = True          # loading lanes_common must not drop __pycache__ into a repo
_spec = importlib.util.spec_from_file_location('lanes_common', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lanes_common.py'))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)

SCHED_DROP, TENANT, _R, _constraint, _dirs, _errkey, _jclasses = C.SCHED_DROP, C.TENANT, C._R, C._constraint, C._dirs, C._errkey, C._jclasses
_k8s, _kinds, _lits, _merged, _route_side, _row, _src, _status = C._k8s, C._kinds, C._lits, C._merged, C._route_side, C._row, C._src, C._status
_t, env_conf = C._t, C.env_conf


# ---------------------------------------------------------------- spring
def _java(h, ctx):
    if 'jfiles' not in ctx:
        ctx['jfiles'] = _src(h, ctx, ['*.java', '*.kt'])
    return ctx['jfiles']


def _jmethod(h, m, j):
    """From index j (after an annotation), skip further annotations; -> (name, name_i, params_a, body_a, body_b, decl_end)."""
    while True:
        y = re.compile(r'\s*@[\w.]+').match(m, j)
        if not y:
            break
        j = y.end()
        if re.compile(r'\s*\(').match(m, j):
            j = h.close(m, m.find('(', j)) + 1
    y = re.compile(r'[^;{}()=]*?(\w+)\s*\(').match(m, j)
    if not y:
        return None
    pa = y.end() - 1
    pb = h.close(m, pa)
    z = re.compile(r'[^;{}]*?([;{])').match(m, pb + 1)
    ba = z.end() - 1 if z and z.group(1) == '{' else None
    return y.group(1), y.start(1), pa, pb, ba, h.close(m, ba) if ba is not None else pb


def _jpaths(args):
    a = re.sub(r'\b(?:produces|consumes|params|headers|name)\s*=\s*(?:\{[^}]*\}|"[^"]*"|[\w.]+)', '', args or '')
    return re.findall(r'"([^"]*)"', a) or ['']


def _jann(c, m, i):
    q = max(m.rfind(';', 0, i), m.rfind('}', 0, i), m.rfind('{', 0, i)) + 1
    return c[q:i]


def _scan_spring(h, ctx):
    out, chain, sec = [], [], False
    for d in _dirs(h, ctx):
        for f in ('pom.xml', 'build.gradle', 'build.gradle.kts'):
            sec = sec or bool(re.search(r'spring-boot-starter-security|spring-security', h.read(os.path.join(d, f)) if h.exists(os.path.join(d, f)) else ''))
    for rel in _java(h, ctx):
        t, m, c = _t(h, rel, 'c')
        if 'SecurityFilterChain' in m or 'HttpSecurity' in m:
            for x in re.finditer(r'\.(?:requestMatchers|antMatchers|mvcMatchers)\(([^)]*)\)\s*\.\s*(\w+)\(([^)]*)\)|anyRequest\(\)\s*\.\s*(\w+)\(([^)]*)\)', c):
                chain.append((x.group(1) or '"/**"', x.group(2) or x.group(4), x.group(3) or x.group(5) or ''))
    for rel in _java(h, ctx):
        t, m, c = _t(h, rel, 'c')
        if 'Mapping' not in m:
            continue
        for cl in _jclasses(h, rel):
            if not re.search(r'@(Rest)?Controller\b', cl['ann']):
                continue
            cm = re.search(r'@RequestMapping\s*(?:\(([^)]*)\))?', cl['ann'])
            cpaths = _jpaths(cm.group(1)) if cm else ['']
            for x in re.finditer(r'@(Get|Post|Put|Patch|Delete|Request)Mapping\b', m[cl['a']:cl['b']]):
                i = cl['a'] + x.start()
                j = cl['a'] + x.end()
                args = c[j + 1:h.close(m, j)] if re.compile(r'\s*\(').match(m, j) else ''
                if args:
                    j = h.close(m, m.find('(', j)) + 1
                mt = _jmethod(h, m, j)
                if not mt or [k for k in _jclasses(h, rel) if cl['a'] < k['i'] < cl['b'] and k['a'] < i < k['b']]:
                    continue
                name, ni, pa, pb, ba, bb = mt
                ann = _jann(c, m, i) + c[i:ni]
                meths = [x.group(1).upper()] if x.group(1) != 'Request' else (re.findall(r'RequestMethod\.(\w+)', args) or ['ANY'])
                types = {}
                for y in re.finditer(r'@PathVariable\s*(?:\(\s*(?:(?:value|name)\s*=\s*)?"(\w+)"[^)]*\))?\s*(?:final\s+)?(?:([\w.<>]+)\s+(\w+)|(\w+)\s*:\s*(\w+))', c[pa:pb]):
                    ty, nm = (y.group(2), y.group(3)) if y.group(2) else (y.group(5), y.group(4))
                    types[y.group(1) or nm] = 'int' if ty in ('Long', 'long', 'Integer', 'int', 'Short', 'short', 'BigInteger') else 'uuid' if ty == 'UUID' else ''
                az = _spring_az(h, ann if re.search(r'@(PreAuthorize|Secured|RolesAllowed|PermitAll|DenyAll)', ann) else cl['ann'], sec, chain)
                for cp in cpaths:
                    for mp in _jpaths(args):
                        raw = '/' + cp.strip('/') + '/' + mp.strip('/')
                        for mm in meths:
                            a2 = dict(az)
                            if a2['authn'] == '@chain':
                                a2['authn'], rl = _chain(chain, h.norm_path(raw)[0], mm, sec)
                                a2['roles'] = a2['roles'] or rl
                            out.append(_R(mm, raw, rel, ni, handler='%s.%s' % (cl['name'], name), con=_constraint(raw, types), az=a2,
                                          body=(rel, 'c', ba, bb) if ba else None))
    return out


def _spring_az(h, ann, sec, chain):
    roles, ab, authn, extra = set(), set(), None, False
    pa = re.search(r'@PreAuthorize\(\s*"((?:[^"\\]|\\.)*)"', ann)
    if pa:
        e = pa.group(1)
        roles |= set(r.lower().replace('role_', '') for g in re.findall(r'has(?:Any)?Role\(([^)]*)\)', e) for r in _lits(g))
        ab |= set(h.ability(a) for g in re.findall(r'has(?:Any)?Authority\(([^)]*)\)', e) for a in _lits(g))
        authn = 'none' if 'permitAll' in e and not roles else 'required' if (roles or ab or 'isAuthenticated' in e or 'isFullyAuthenticated' in e) else None
        extra = bool(re.search(r'@\w+\.|#\w+', e))
    for g in re.findall(r'@(?:Secured|RolesAllowed)\(([^)]*)\)', ann):
        roles |= set(r.lower().replace('role_', '') for r in _lits(g))
        authn = 'required'
    if '@PermitAll' in ann:
        authn = 'none'
    return {'authn': authn or '@chain', 'roles': ','.join(sorted(roles)), 'abilities': ','.join(sorted(ab)),
            'extra_guard': 'yes' if extra else 'no', 'mw': ' '.join(re.findall(r'@(PreAuthorize|Secured|RolesAllowed|PermitAll)', ann))}


def _chain(chain, path, meth, sec):
    if not sec:
        return 'none', ''
    if not chain:
        return 'required', ''
    for pats, verdict, args in chain:
        hm = re.search(r'HttpMethod\.(\w+)', pats)
        if hm and hm.group(1) != meth:
            continue
        for p in _lits(pats):
            rx = re.escape(p.lower()).replace(r'/\*\*', '(/.*)?').replace(r'\*\*', '.*').replace(r'\*', '[^/]*')
            rx = re.sub(r'\\\{[^}]*\\\}', '[^/]+', rx)
            if re.match(rx + '$', path):
                if verdict == 'permitAll':
                    return 'none', ''
                return ('required', ','.join(sorted(r.lower().replace('role_', '') for r in _lits(args))) if 'Role' in verdict else '')
    return '?', ''


def spring_enum(root, h, ctx):
    rows, ents = [], [rel for rel in _java(h, ctx) if '@Entity' in _t(h, rel, 'c')[1]]
    for rel in _java(h, ctx):
        t, m, c = _t(h, rel, 'c')
        for cl in _jclasses(h, rel):
            if cl['kind'] != 'enum':
                continue
            body = m[cl['a'] + 1:cl['b']]
            d, cut = 0, len(body)
            for k, ch in enumerate(body):
                d += ch in '({['
                d -= ch in ')}]'
                if ch == ';' and d == 0:
                    cut = k
                    break
            names = [n for n in re.findall(r'(?:^|,)\s*(?:@\w+\s*)*([A-Z][A-Za-z0-9_]*)', re.sub(r'\([^()]*\)|\{[^{}]*\}', '', body[:cut]))]
            store = set()
            for e in ents:
                ec, em = _t(h, e, 'c')[2], _t(h, e, 'c')[1]
                for y in re.finditer(r'\b%s\s+\w+\s*[;=]|\w+\s*:\s*%s\b' % (cl['name'], cl['name']), em):
                    a = _jann(ec, em, y.start())
                    store.add('string' if 'STRING' in a else 'converter' if '@Convert' in a else 'ordinal')
            rows.append(_row(h, 'type:' + h.ident(cl['name'], strip=('enum', 'choices', 'type', 'schema')),
                             {'values': ','.join(sorted(set(names))), 'names': ','.join(names),
                              'ordinal': 'yes' if 'ordinal' in store else 'no' if store else ''}, rel, cl['i']))
    return rows


def spring_err(root, h, ctx):
    out = {}
    for rel in _java(h, ctx):
        t, m, c = _t(h, rel, 'c')
        for cl in _jclasses(h, rel):
            rs = re.search(r'@ResponseStatus\(([^)]*)\)', cl['ann'])
            if rs and re.search(r'Exception|Error', cl['name']):
                out.setdefault(_errkey(h, cl['name']), _row(h, _errkey(h, cl['name']), {'status': ','.join(sorted(_status(rs.group(1)))) or '?',
                                                                                        'envelope': '@ResponseStatus'}, rel, cl['i']))
        for x in re.finditer(r'@ExceptionHandler\s*(?:\(([^)]*)\))?', m):
            args = c[x.start():h.close(m, x.end() - 1) + 1] if x.group(1) is not None else ''
            mt = _jmethod(h, m, x.end())
            if not mt:
                continue
            names = re.findall(r'(\w+)(?:\.class|::class)', args) or re.findall(r'(\w+(?:Exception|Error))\s+\w+', c[mt[2]:mt[3]])
            ann = _jann(c, m, x.start()) + c[x.start():mt[1]]
            st = _status(' '.join(re.findall(r'@ResponseStatus\(([^)]*)\)', ann))) or (_status(c[mt[4]:mt[5]]) if mt[4] else set())
            for n in names:
                out[_errkey(h, n)] = _row(h, _errkey(h, n), {'status': ','.join(sorted(st)) or '?', 'envelope': mt[0]}, rel, x.start())
    out.setdefault('validation', {'key': 'validation', 'attrs': {'status': '400', 'envelope': 'MethodArgumentNotValidException'},
                                  'at': '-', 'excerpt': 'Spring MVC default (DefaultHandlerExceptionResolver)'})
    return list(out.values())


JPA = {'PostPersist': 'created', 'PostUpdate': 'updated', 'PostRemove': 'deleted', 'PrePersist': 'creating', 'PreUpdate': 'updating',
       'PreRemove': 'deleting'}


def spring_side(root, h, ctx):
    rows, listeners = [], {}
    for rel in _java(h, ctx):
        for cl in _jclasses(h, rel):
            el = re.search(r'@EntityListeners\(([^)]*)\)', cl['ann'])
            if el:
                for n in re.findall(r'(\w+)(?:\.class|::class)', el.group(1)):
                    listeners[n] = cl['name']
    for rel in _java(h, ctx):
        t, m, c = _t(h, rel, 'c')
        for cl in _jclasses(h, rel):
            ent = cl['name'] if '@Entity' in cl['ann'] else listeners.get(cl['name'])
            for x in re.finditer(r'@(PostPersist|PostUpdate|PostRemove|PrePersist|PreUpdate|PreRemove|TransactionalEventListener|EventListener)\b',
                                 m[cl['a']:cl['b']]):
                mt = _jmethod(h, m, cl['a'] + x.end() + (h.close(m, m.find('(', cl['a'] + x.end())) + 1 - cl['a'] - x.end()
                                                         if re.compile(r'\s*\(').match(m, cl['a'] + x.end()) else 0))
                if not mt or not mt[4]:
                    continue
                ks = _kinds(m, mt[4], mt[5])
                if x.group(1) in JPA and ent and ks:
                    rows.append(_row(h, '%s.%s' % (h.table(ent), JPA[x.group(1)]), {'kinds': ','.join(sorted(ks))}, rel, cl['a'] + x.start()))
                elif x.group(1) not in JPA and ks:
                    pt = re.search(r'(\w+)\s+\w+\s*\)|\w+\s*:\s*(\w+)\s*\)', c[mt[2]:mt[3] + 1])
                    rows.append(_row(h, 'event:' + h.ident(pt and (pt.group(1) or pt.group(2)) or mt[0], strip=('event',)),
                                     {'kinds': ','.join(sorted(ks))}, rel, cl['a'] + x.start()))
    return _merged(rows) + _route_side(h, ctx)


def spring_sched(root, h, ctx):
    rows = []
    for rel in _java(h, ctx):
        t, m, c = _t(h, rel, 'c')
        for x in re.finditer(r'@Scheduled\s*\(', m):
            args = c[x.end():h.close(m, x.end() - 1)]
            mt = _jmethod(h, m, h.close(m, x.end() - 1) + 1)
            cr, zn = re.search(r'cron\s*=\s*"([^"]*)"', args), re.search(r'zone\s*=\s*"([^"]*)"', args)
            ann = _jann(c, m, x.start()) + (c[x.start():mt[1]] if mt else '')
            rows.append(_row(h, 'job:' + h.tokkey(mt[0] if mt else 'scheduled', SCHED_DROP),
                             {'cron': h.cron(cr.group(1)) if cr and '${' not in cr.group(1) else '?', 'tz': zn.group(1) if zn else '',
                              'overlap': 'yes' if '@SchedulerLock' in ann else '?', 'target': '@Scheduled ' + (mt[0] if mt else '')}, rel, x.start()))
    return rows + _k8s(h, ctx)


def spring_scope(root, h, ctx):
    rows = []
    for rel in _java(h, ctx):
        t, m, c = _t(h, rel, 'c')
        for cl in _jclasses(h, rel):
            a = cl['ann']
            if '@Entity' not in a:
                continue
            w = ' '.join(re.findall(r'@(?:Where|SQLRestriction)\(([^)]*)\)', a))
            f = re.findall(r'@Filter\(\s*name\s*=\s*"(\w+)"', a)
            tb = re.search(r'@Table\(\s*name\s*=\s*"(\w+)"', a)
            soft = bool(re.search(r'(?i)delet|archiv|active', w) or '@SQLDelete' in a or any(re.search(r'(?i)delet', n) for n in f))
            ten = bool(TENANT.search(w + ' '.join(f)) or '@TenantId' in m[cl['a']:cl['b']])
            rows.append(_row(h, 'table:' + h.table(tb.group(1) if tb else cl['name']), {'soft_delete': 'yes' if soft else 'no',
                             'tenant': 'yes' if ten else 'no', 'scopes': (w + ' ' + ','.join(f)).strip()[:80]}, rel, cl['i']))
    return rows


def _yflat(t):
    out, st = {}, []
    for ln in t.split('\n'):
        x = re.match(r'^(\s*)([\w.\-\[\]]+)\s*[:=]\s*(.*?)\s*(?:\s#.*)?$', ln)
        if not x or ln.lstrip().startswith(('#', '-')):
            continue
        ind = len(x.group(1))
        while st and st[-1][0] >= ind:
            st.pop()
        key = '.'.join([s[1] for s in st] + [x.group(2)])
        if x.group(3):
            out[re.sub(r'[-_]', '', key.lower())] = x.group(3).strip('"\'')
        else:
            st.append((ind, x.group(2)))
    return out


def spring_conf(root, h, ctx):
    rows = []
    for rel in _src(h, ctx, ['application.properties', 'application.yml', 'application.yaml']):
        f = _yflat(h.read(rel))
        for k, name in (('spring.jackson.timezone', 'timezone'), ('spring.web.locale', 'locale'), ('spring.mvc.locale', 'locale'),
                        ('spring.data.web.pageable.defaultpagesize', 'per_page')):
            if k.replace('-', '') in f:
                rows.append(_row(h, name, {'value': f[k.replace('-', '')]}, rel, h.read(rel).find(k.split('.')[-1][:6])))
    return rows + env_conf(root, h, ctx)


# ---------------------------------------------------------------- registry
STACKS = ('spring',)
C.SCAN['spring'] = _scan_spring
LANES = C.drop_catchall({'spring': dict(C.R3, **{'I-ENUM': spring_enum, 'I-ERR': spring_err, 'I-SIDE': spring_side, 'I-SCHED': spring_sched,
                         'I-SCOPE': spring_scope, 'I-CONF': spring_conf})})
PARTIAL = set((s, l) for s, ls in LANES.items() for l in ls)
GAPS = C.gaps(STACKS)


def detect(root, h):
    return C.detect_stacks(h, STACKS)


# ---------------------------------------------------------------- self-test: one tiny tree per stack, good rows + decoys
_L = C._L

SAMPLES = {
    'spring': ({
        'pom.xml': _L('<parent><artifactId>spring-boot-starter-parent</artifactId><version>3.3.0</version></parent>',
                      '<dependency><artifactId>spring-boot-starter-security</artifactId></dependency>'),
        'src/main/resources/application.yml': _L('spring:', '  jackson:', '    time-zone: Asia/Riyadh'),
        'src/main/java/a/OrderController.java': _L('@RestController', '@RequestMapping("/api/orders")', 'public class OrderController {',
                                                   '    @GetMapping("/{id}")', '    @PreAuthorize("hasRole(\'ADMIN\')")',
                                                   '    public Order show(@PathVariable Long id) { return null; }', '    @PostMapping',
                                                   '    public Order create(@RequestBody Order o) { publisher.publishEvent(new OrderPlaced(o)); return o; }',
                                                   '    // @GetMapping("/ghost")', '}'),
        'src/main/java/a/SecurityConfig.java': _L('class SecurityConfig { SecurityFilterChain chain(HttpSecurity http) {',
                                                  '  http.authorizeHttpRequests(a -> a.requestMatchers("/api/public/**").permitAll().anyRequest().authenticated());',
                                                  '  return http.build(); } }'),
        'src/main/java/a/OrderStatus.java': 'public enum OrderStatus { PENDING, PAID("p"); OrderStatus() {} OrderStatus(String s) {} }\n',
        'src/main/java/a/Order.java': _L('@Entity', '@Table(name = "orders")', '@SQLDelete(sql = "update orders set deleted_at = now() where id = ?")',
                                         'public class Order {', '    private OrderStatus status;', '    @PostPersist',
                                         '    public void after() { mailSender.send(msg); }', '}'),
        'src/main/java/a/ApiErrors.java': _L('@RestControllerAdvice', 'public class ApiErrors {', '    @ExceptionHandler(OrderLockedException.class)',
                                             '    @ResponseStatus(HttpStatus.CONFLICT)', '    public Map<String, String> locked() { return null; }', '}'),
        'src/main/java/a/Jobs.java': _L('public class Jobs {', '    @Scheduled(cron = "0 0 2 * * *", zone = "Asia/Riyadh")', '    public void generateInvoices() {}',
                                        '    public BigDecimal lineTotal(BigDecimal p) { return p.setScale(2, RoundingMode.HALF_EVEN); }', '}'),
        'src/test/java/a/OrderControllerTest.java': '@RestController class T { @GetMapping("/test-only") public void t() {} }\n'},
        [('I-ROUTES', 'GET /api/orders/{}', {'constraint': '1:int', 'handler': 'OrderController.show'}), ('I-ROUTES', 'POST /api/orders', {}),
         ('I-AUTHZ', 'GET /api/orders/{}', {'authn': 'required', 'roles': 'admin'}), ('I-AUTHZ', 'POST /api/orders', {'authn': 'required'}),
         ('I-ENUM', 'type:orderstatus', {'values': 'PAID,PENDING', 'ordinal': 'yes'}), ('I-ERR', 'exc:orderlocked', {'status': '409'}),
         ('I-SIDE', 'order.created', {'kinds': 'mail'}), ('I-SIDE', 'POST /api/orders', {'kinds': 'event'}),
         ('I-SCHED', 'job:generate.invoice', {'cron': '0 2 * * *', 'tz': 'Asia/Riyadh'}), ('I-SCOPE', 'table:order', {'soft_delete': 'yes'}),
         ('I-MONEY', 'area:line', {'modes': 'half-even'}), ('I-CONF', 'timezone', {'value': 'Asia/Riyadh'})],
        [('I-ROUTES', 'GET /api/orders/ghost'), ('I-ROUTES', 'GET /test-only')])}


def self_test(H, tmp):
    return C.run_samples(H, tmp, SAMPLES, detect, LANES)
