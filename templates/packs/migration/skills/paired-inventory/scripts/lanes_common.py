"""lanes_common.py — shared readers for the per-stack lane modules of pair-inventory.py.

Not a lane module: no STACKS / LANES, and the core never loads it. lanes_ruby, lanes_python, lanes_java, lanes_js
and lanes_go each load it by path (importlib.util.spec_from_file_location, never sys.path: `python3 -I` safe) and
keep their own copy. Reads are static (rg listing through the core's H, masked text); nothing is imported or
executed. Manifests are found anywhere under the root (a Django or Go service in a monorepo subfolder is read in
place) and each stack reads only the files under its own manifests' folders.

What lives here: masked-text / block / function readers, manifest detection for every stack these modules cover
(one pass, so `ctx['found']` keeps one order across modules), route rows (I-ROUTES / I-AUTHZ / I-RULES / route
I-SIDE) over each stack's scanner in SCAN, the I-AUTHZ name classifier, the k8s CronJob reader (I-SCHED, read once
per root, not at all beside a Nest app because lanes_node reads them, and never a CronJob whose container runs
`php` / `artisan`: that is the V1 Laravel scheduler, noted in the ledger), rounding on money paths (I-MONEY),
Dockerfile / .env TZ (I-CONF), GAPS, and the self-test driver. Every cron goes through the core's h.cron().
The core hashes each lane module's own file: an edit here does not change the per-module extractor hash.
"""
import json, os, re

ORDER = ('rails', 'django', 'spring', 'express', 'fastify', 'fastapi', 'go')   # manifest order: the first found reads k8s CronJobs
ALL = ('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS')
AUTHN = re.compile(r'auth|jwt|session|passport|login|current_?user|token|principal|bearer|signed_?in', re.I)
ROLEW = re.compile(r'role|admin|staff', re.I)
PERMW = re.compile(r'perm|\bcan|can[A-Z_]|abilit|scope|polic', re.I)
PLAIN = re.compile(r'(?:^|\.)(?:json|urlencoded|raw|text|static|bodyParser|multer|cors|helmet|compression|morgan|logger|Recovery|'
                   r'Recoverer|RequestID|RealIP|cookieParser)\b|log(?:ger|ging)?$|upload|throttl|rate_?limit|limiter|^get_db$|^get_session$', re.I)
TENANT = re.compile(r'tenant|team|company|org|account', re.I)
SCHED_DROP = ('job', 'jobs', 'command', 'task', 'tasks', 'cron', 'run', 'handle', 'handler', 'schedule', 'scheduled',
              'worker')
STATUS = {'ok': 200, 'created': 201, 'accepted': 202, 'nocontent': 204, 'badrequest': 400, 'unauthorized': 401,
          'paymentrequired': 402, 'forbidden': 403, 'notfound': 404, 'methodnotallowed': 405, 'conflict': 409,
          'gone': 410, 'preconditionfailed': 412, 'unprocessableentity': 422, 'unprocessablecontent': 422,
          'toomanyrequests': 429, 'internalservererror': 500, 'serviceunavailable': 503}
KINDS = [(k, re.compile(p, re.I)) for k, p in (
    ('mail', r'\.deliver_(?:later|now)\b|\bsend_(?:mass_)?mail\(|\bEmailMessage\(|\b\w*mail\w*\.(?:send|deliver)\w*\('),
    ('job', r'\.perform_(?:later|async|in|at)\b|\.delay\(|\.apply_async\(|\b\w*queue\w*\.(?:add|enqueue|push)\w*\(|\.enqueue\('),
    ('event', r'ActiveSupport::Notifications\.instrument|\bpublish_?event\(|\.publishEvent\(|\b\w+\.send(?:_robust)?\(\s*sender\s*=|'
              r'\b\w*(?:event|emitter|bus)\w*\.(?:emit|publish|dispatch)\w*\('),
    ('webhook', r'\b\w*webhook\w*\.(?:send|post|dispatch|deliver)\w*\('),
    ('audit', r'\b\w*audit\w*\.(?:log|record|create|write)\w*\(|\bAuditLog\.objects\.create\('),
    ('notify', r'\.notify(?:_now|_later)?\(|\b\w*notif\w*\.(?:send|deliver|notify)\w*\(|\bsend_?(?:sms|push)\w*\('),
    ('search', r'\b\w*search\w*\.(?:index|reindex|upsert)\w*\('),
    ('cache', r'\b\w*cache\w*\.(?:delete|forget|invalidate|evict|clear|del)\w*\(|@CacheEvict'))]
MONEY = ('price', 'total', 'tax', 'vat', 'amount', 'invoice', 'order', 'payment', 'refund', 'fee', 'discount', 'balance',
         'charge', 'cost', 'money', 'currenc', 'payout', 'settle')
RMODE = {'HALF_UP': 'half-away', 'HALF_EVEN': 'half-even', 'DOWN': 'trunc', 'FLOOR': 'floor', 'CEILING': 'ceil'}
KW = {'if', 'for', 'while', 'switch', 'catch', 'return', 'function', 'new', 'else', 'do', 'try', 'typeof', 'await', 'super'}
LANGC = {'py': 'py', 'rb': 'rb'}


# ---------------------------------------------------------------- shared readers
def _cache(h):
    if not hasattr(h, '_oth'):
        h._oth = {}
    return h._oth


def _t(h, rel, lang):
    """(original, masked, comment-free) text; same indices in all three. Docstrings stay blank in the third."""
    k, cache = ('t', rel, lang), _cache(h)
    if k not in cache:
        t = h.read(rel)
        m, sp = h.masked(rel, LANGC.get(lang, 'c'))
        c = list(m)
        for s, e in sp:
            if t[max(0, s - 2):s + 1] not in ('"""', "'''"):
                c[s:e] = t[s:e]
        cache[k] = (t, m, ''.join(c))
    return cache[k]


def _row(h, key, attrs, rel, i):
    return h.row(key, attrs, rel, h.read(rel), i)


def _args(h, m, a):
    """Top-level argument spans [(s, e)] of the call whose '(' / '[' / '{' is at m[a]."""
    b, out, d, s = h.close(m, a), [], 0, a + 1
    for j in range(a + 1, b):
        ch = m[j]
        if ch in '([{':
            d += 1
        elif ch in ')]}':
            d -= 1
        elif ch == ',' and d == 0:
            out.append((s, j))
            s = j + 1
    if m[s:b].strip():
        out.append((s, b))
    return out


def _lit(s):
    x = re.match(r'\s*[rRbBuUfF]{0,2}(["\'`])(.*)\1\s*$', s or '', re.S)
    return x.group(2) if x else None


def _lits(s):
    return [a or b for a, b in re.findall(r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'', s or '')]


def _kw(c, m, spans, name, sep='='):
    for s, e in spans:
        x = re.match(r'\s*%s\s*%s\s*' % (name, sep), m[s:e])
        if x and m[s + x.end():s + x.end() + 1] != '=':
            return c[s + x.end():e].strip()
    return None


def _kinds(m, a, b):
    seg = m[a:b]
    return set(k for k, rx in KINDS if rx.search(seg))


def _status(s):
    out = set()
    for x in re.finditer(r'HTTP_(\d{3})|(?:status(?:_?code)?|\.code|WriteHeader|head|super)\s*[=:(]?\s*\(?\s*(?:\w+\s*,\s*)?([1-5]\d\d)\b'
                         r'|(?:HttpStatus\.|HTTPStatus\.|http\.Status|status:\s*:|head\s*\(?\s*:)([A-Za-z_]+)', s or ''):
        v = x.group(1) or x.group(2) or STATUS.get(re.sub(r'[^a-z]', '', (x.group(3) or '').lower()))
        if v:
            out.add(str(v))
    for k, v in (('badRequest', 400), ('notFound', 404), ('unprocessableEntity', 422), ('noContent', 204)):
        if re.search(r'ResponseEntity\s*\.\s*%s\(' % k, s or ''):
            out.add(str(v))
    return out


def _errkey(h, name):
    n = re.split(r'[.:]', name)[-1]
    if re.search(r'NotValid|Validation|RecordInvalid|ZodError|ConstraintViolation|BindException', n):
        return 'validation'
    if re.search(r'NotFound|DoesNotExist|Http404', n):
        return 'not_found'
    if re.search(r'NotAuthenticated|Unauthenticated|AuthenticationFailed|AuthenticationException|Unauthorized', n):
        return 'unauthenticated'
    if re.search(r'PermissionDenied|AccessDenied|NotAuthorized|Forbidden', n):
        return 'forbidden'
    if n in ('Exception', 'Throwable', 'RuntimeException', 'Error', 'StandardError', 'BaseException'):
        return 'exc:'          # a catch-all: not a mapping of one error class (dropped by _noall)
    return 'exc:' + h.ident(n, strip=('exception', 'error'))


def _retype(rx):
    rx = (rx or '').replace('\\\\', '\\').strip().strip('^$')
    if rx in (r'\d+', '[0-9]+', r'\d{1,}', '[0-9]{1,}', 'int'):
        return 'int'
    if rx in ('[a-zA-Z]+', '[A-Za-z]+', '[a-z]+'):
        return 'alpha'
    if rx in ('[a-zA-Z0-9]+', '[A-Za-z0-9]+', '[a-z0-9]+'):
        return 'alnum'
    if re.search(r'\{8\}', rx) or rx == 'uuid':
        return 'uuid'
    return '' if rx in ('', 'path', 'str', 'string', '[^/.]+', '[^/]+') else 're'


PARAM = re.compile(r'<(?:(\w+):)?(\w+)>|\(\?P<(\w+)>((?:[^()]|\([^()]*\))*)\)|\{(\w+)(?::((?:[^{}]|\{[^}]*\})*))?\}'
                   r'|(?<=/):(\w+)(?:\(((?:[^()]|\([^()]*\))*)\))?')


def _constraint(raw, types=None):
    out, n = set(), 0
    for x in PARAM.finditer(raw or ''):
        n += 1
        if x.group(2):
            name, ty = x.group(2), {'int': 'int', 'uuid': 'uuid', 'slug': 'slug'}.get(x.group(1) or '', '')
        elif x.group(3):
            name, ty = x.group(3), _retype(x.group(4))
        elif x.group(5):
            name, ty = x.group(5), _retype(x.group(6))
        else:
            name, ty = x.group(7), _retype(x.group(8))
        ty = ty or (types or {}).get(name, '')
        if ty:
            out.add('%d:%s' % (n, ty))
    return ','.join(sorted(out))


def _guard(h, mws, known_none=False):
    """mws: [(name, literals, route_level)] -> I-AUTHZ attrs. Names decide: auth / role / permission / other."""
    authn, roles, ab, extra = False, set(), set(), False
    for name, lits, guard in mws:
        a, r, p = bool(AUTHN.search(name)), bool(ROLEW.search(name)), bool(PERMW.search(name)) or name.endswith(' Security')
        authn = authn or a
        if r:
            roles |= set(l.lower() for l in lits) or ({'admin'} if 'admin' in name.lower() else set())
        if p:
            ab |= set(h.ability(l) for l in lits)
        if guard and not (a or r or p) and not PLAIN.search(name):
            extra = True
    return {'authn': 'required' if authn else ('none' if known_none else '?'), 'roles': ','.join(sorted(roles)),
            'abilities': ','.join(sorted(ab)), 'extra_guard': 'yes' if extra else 'no',
            'mw': ','.join(sorted(set(n for n, _, _ in mws)))}


# ---------------------------------------------------------------- detection
def _pydep(t, name):
    x = re.search(r'(?im)(?:^|["\'])%s(?![\w-])\s*(?:\[[^\]\n]*\])?\s*(?:(?:[=~<>!]=?|=\s*["\'][\^~>=<]*)\s*v?(\d[\w.]*))?'
                  % re.escape(name), t)
    if not x:
        return None
    y = re.search(r'name = "%s"\s*\nversion = "([^"]+)"' % re.escape(name), t, re.I)
    return x.group(1) or (y.group(1) if y else '')



def _manifests(h):
    cache = _cache(h)
    if 'man' in cache:
        return cache['man']
    out = dict((s, {}) for s in ORDER)
    for rel in h.files(['**/Gemfile', '**/Gemfile.lock', '**/requirements*.txt', '**/pyproject.toml', '**/poetry.lock',
                        '**/Pipfile', '**/pom.xml', '**/build.gradle', '**/build.gradle.kts', '**/package.json', '**/go.mod']):
        d, base, t = os.path.dirname(rel), os.path.basename(rel), h.read(rel)
        found = []
        if base.startswith('Gemfile'):
            x = re.search(r'^    rails \(([^)]+)\)', t, re.M) or re.search(r'''^\s*gem\s+['"]rails['"](?:\s*,\s*['"]([^'"]+))?''', t, re.M)
            if x:
                found.append(('rails', 'rails ' + (x.group(1) or '?')))
        elif base.endswith(('.txt', '.toml', '.lock')) or base == 'Pipfile':
            for s in ('django', 'fastapi'):
                v = _pydep(t, s)
                if v is not None:
                    found.append((s, '%s %s' % (s, v or '?')))
        elif base == 'pom.xml' or base.startswith('build.gradle'):
            if re.search(r'spring-boot|org\.springframework\.boot', t):
                x = re.search(r'spring-boot-starter-parent</artifactId>\s*<version>([^<]+)|org\.springframework\.boot["\']?\)?\s*version\s*["\']([^"\']+)', t)
                found.append(('spring', 'spring-boot ' + ((x.group(1) or x.group(2)) if x else '?')))
        elif base == 'package.json':
            try:
                j = json.loads(t)
                deps = dict(j.get('devDependencies') or {}, **(j.get('dependencies') or {}))
            except (ValueError, AttributeError):
                deps = {}
            if '@nestjs/core' in deps:
                cache['nest'] = True
            else:
                found += [(s, '%s %s' % (s, deps[s])) for s in ('express', 'fastify') if s in deps]
        elif base == 'go.mod':
            x = re.search(r'github\.com/(gin-gonic/gin|labstack/echo|go-chi/chi|gorilla/mux)\S*\s+(v[\w.\-]+)', t)
            if x:
                found.append(('go', '%s %s' % (x.group(1).split('/')[1], x.group(2))))
            elif h.files([(d + '/' if d else '') + '**/*.go'], pattern=r'http\.(NewServeMux|HandleFunc|Handle)\('):
                g = re.search(r'^go\s+(\S+)', t, re.M)
                found.append(('go', 'net/http go' + (g.group(1) if g else '?')))
        for s, ev in found:
            if d not in out[s] or out[s][d].endswith('?'):
                out[s][d] = '%s %s' % (rel, ev)
    cache['man'] = out
    return out


def detect_stacks(h, stacks):
    return dict((s, '; '.join(v[d] for d in sorted(v))) for s, v in _manifests(h).items() if s in stacks)


def _dirs(h, ctx):
    if 'dirs' not in ctx:
        man = _manifests(h)
        ctx['found'] = [s for s in ORDER if man[s]]
        ds = sorted(man.get(ctx['stack'], {})) or ['']
        ctx['dirs'] = [d for d in ds if not any(p != d and (p == '' or d.startswith(p + '/')) for p in ds)]
    return ctx['dirs']


def _src(h, ctx, globs, pattern=None, keep=()):
    inc = [(d + '/' if d else '') + '**/' + g for d in _dirs(h, ctx) for g in globs]
    return h.files(inc, pattern=pattern, keep=keep)


# ---------------------------------------------------------------- blocks and functions
_PYB = re.compile(r'^([ \t]*)(?:async[ \t]+)?(def|class)[ \t]+(\w+)', re.M)
_RBB = re.compile(r'^([ \t]*)(def|class|module)[ \t]+((?:self\.)?[\w:]+[!?=]?)', re.M)
_LN = re.compile(r'\n([ \t]*)(?=\S)')
FN = {'go': re.compile(r'^func[ \t]+(?:\([^)]*\)[ \t]*)?(\w+)[ \t]*(?:\[[^\]]*\])?(?=\()', re.M),
      'java': re.compile(r'(?:\b(?:public|private|protected|static|final|synchronized|abstract|default|override|suspend|open|internal|fun)\s+)+'
                         r'(?:<[^>]*>\s*)?(?:[\w<>\[\],.?]+\s+)?(\w+)\s*(?=\()'),
      'js': re.compile(r'\bfunction\s*\*?\s*(\w+)\s*(?=\()|\b(?:const|let|var)\s+(\w+)\s*(?::[^=\n]+)?=\s*(?:async\s*)?(?:function\b\s*\w*\s*)?(?=\()'
                       r'|^[ \t]*(?:(?:public|private|protected|static|async|readonly|override)\s+)*(\w+)\s*(?=\([^)\n]*\)\s*(?::[^{\n;]+)?\{)', re.M)}


def _blocks(h, rel, lang):
    """[(kind, name, start, body_start, end, indent, parent_class)] for py (def/class) and rb (def/class/module)."""
    k, cache = ('blk', rel, lang), _cache(h)
    if k in cache:
        return cache[k]
    t, m, c = _t(h, rel, lang)
    out = []
    for x in (_PYB if lang == 'py' else _RBB).finditer(m):
        ind, j = len(x.group(1)), x.end()
        if lang == 'py':
            if m[j:j + 1] == '(':
                j = h.close(m, j) + 1
            j = m.find(':', j)
            j = len(m) if j < 0 else j + 1
        else:
            j = m.find('\n', j)
            j = len(m) if j < 0 else j
        end = len(m)
        for y in _LN.finditer(m, j):
            if len(y.group(1)) <= ind and (lang == 'py' or m.startswith('end', y.end())):
                end = y.start() if lang == 'py' else y.end() + 3
                break
        out.append([x.group(2), x.group(3), x.start() + len(x.group(1)), j, end, ind, None])
    for b in out:
        par = [p for p in out if p[0] in ('class', 'module') and p[2] < b[2] < p[4] and p[5] < b[5]]
        b[6] = par[-1][1] if par else None
    cache[k] = out
    return out


def _funcs(h, rel, lang):
    """[(name, start, body_a, body_b)] — py/rb by indentation, others by braces."""
    k, cache = ('fn', rel, lang), _cache(h)
    if k in cache:
        return cache[k]
    out = []
    if lang in ('py', 'rb'):
        out = [(b[1].replace('self.', ''), b[2], b[3], b[4]) for b in _blocks(h, rel, lang) if b[0] == 'def']
    else:
        t, m, c = _t(h, rel, 'c')
        for x in FN[lang].finditer(m):
            name = next(g for g in x.groups() if g)
            p = m.find('(', x.end())
            if name in KW or p < 0 or p - x.end() > 40:
                continue
            q = h.close(m, p)
            w = re.compile(r'[^;{}=]*?(?:(=>)\s*(\{)?|(\{))').match(m, q + 1)
            if not w or w.end() - q > 240:
                continue
            if w.group(2) or w.group(3):
                out.append((name, x.start(), w.end() - 1, h.close(m, w.end() - 1)))
            else:
                e = m.find('\n', w.end())
                out.append((name, x.start(), w.end(), len(m) if e < 0 else e))
    cache[k] = out
    return out


# ---------------------------------------------------------------- route lanes (shared)
SCAN = {}          # stack -> route scanner; each stack module fills its own copy of this module
def _routes(h, ctx):
    if 'routes' not in ctx:
        ctx['routes'] = SCAN[ctx['stack']](h, ctx)
    return ctx['routes']


def _R(meth, raw, rel, i, handler='', con='', opt=None, az=None, body=None, rules=None):
    return {'m': meth, 'raw': raw, 'rel': rel, 'i': i, 'handler': handler, 'con': con, 'opt': opt, 'az': az,
            'body': body, 'rules': rules or []}


def _rkey(h, r):
    p, o = h.norm_path(r['raw'])
    return '%s %s' % (r['m'], p), str(o if r['opt'] is None else r['opt'])


def lane_routes(root, h, ctx):
    out = []
    for r in _routes(h, ctx):
        k, o = _rkey(h, r)
        a = {'handler': r['handler'], 'opt': o, 'constraint': r['con']}
        if k == 'ANY /{*}':
            a['fallback'] = 'yes'
        out.append(_row(h, k, a, r['rel'], r['i']))
    return out


def lane_authz(root, h, ctx):
    q = {'authn': '?', 'abilities': '?', 'roles': '?', 'extra_guard': '?', 'mw': ''}
    return [_row(h, _rkey(h, r)[0], r['az'] or q, r['rel'], r['i']) for r in _routes(h, ctx)]


def lane_rules(root, h, ctx):
    return [_row(h, _rkey(h, r)[0] + ' ' + f, a, r['rel'], r['i']) for r in _routes(h, ctx) for f, a in r['rules']]


def _route_side(h, ctx):
    out = []
    for r in _routes(h, ctx):
        if r['body']:
            rel, lang, a, b = r['body']
            ks = _kinds(_t(h, rel, lang)[1], a, b)
            if ks:
                out.append(_row(h, _rkey(h, r)[0], {'kinds': ','.join(sorted(ks))}, r['rel'], r['i']))
    return out


def lane_side(root, h, ctx):
    return _route_side(h, ctx)


def _merged(rows):
    out = {}
    for r in rows:
        if r['key'] in out:
            k = out[r['key']]['attrs']
            k['kinds'] = ','.join(sorted(set(k['kinds'].split(',')) | set(r['attrs']['kinds'].split(','))))
        else:
            out[r['key']] = r
    return list(out.values())


def _jclasses(h, rel):
    k, cache = ('jc', rel), _cache(h)
    if k not in cache:
        t, m, c = _t(h, rel, 'c')
        out = []
        for x in re.finditer(r'\b(enum\s+class|class|interface|enum|record)\s+(\w+)', m):
            a = m.find('{', x.end())
            if a < 0:
                continue
            q = max(m.rfind(';', 0, x.start()), m.rfind('}', 0, x.start()), m.rfind('{', 0, x.start())) + 1
            out.append({'kind': x.group(1).split()[0], 'name': x.group(2), 'i': x.start(), 'a': a, 'b': h.close(m, a), 'ann': c[q:x.start()]})
        cache[k] = out
    return cache[k]


# ---------------------------------------------------------------- every stack: k8s CronJobs, money, TZ
def _v1_command(doc):
    """The `php` / `artisan` token a CronJob container's command/args run (the V1 Laravel app), else ''. A `bin/rails`
    or `manage.py` of another root looks like any V2 command, so only PHP is detectable."""
    lines = doc.split('\n')
    for k, ln in enumerate(lines):
        x = re.match(r'^([ \t]*(?:-[ \t]+)?)(command|args)[ \t]*:[ \t]*(.*)$', ln)
        if not x:
            continue
        col, val = len(x.group(1)), [x.group(3)]
        for nx in lines[k + 1:]:
            s = nx.lstrip()
            ind = len(nx) - len(s)
            if s and not s.startswith('#') and (ind < col or (ind == col and not s.startswith('-'))):
                break
            val.append(nx)
        y = re.search(r'(?:^|[\s"\'\[,/])(php[\d.]*|artisan)(?=$|[\s"\',\]])', ' '.join(re.sub(r'(?:^|\s)#.*', '', v) for v in val))
        if y:
            return y.group(1)
    return ''


def _k8s(h, ctx):
    _dirs(h, ctx)
    if _cache(h).get('nest') or (ctx['found'] and ctx['stack'] in ctx['found'] and ctx['found'][0] != ctx['stack']):
        return []          # one reader per root: lanes_node reads them beside a Nest app, else the first stack found
    rows = []
    for rel in h.files(['**/*.yaml', '**/*.yml'], pattern=r'kind:\s*CronJob'):
        t, off = h.read(rel), 0
        for doc in re.split(r'(?m)^---\s*$', t):
            if re.search(r'(?m)^kind:\s*CronJob\b', doc):
                nm = re.search(r'(?m)^metadata:\s*\n(?:\s+.*\n)*?\s+name:\s*["\']?([\w.-]+)', doc)
                sc = re.search(r'(?m)^\s+schedule:\s*["\']?([^"\'\n#]+)', doc)
                tz = re.search(r'(?m)^\s+timeZone:\s*["\']?([^"\'\n#]+)', doc)
                v1 = _v1_command(doc)
                if v1:
                    ctx.setdefault('notes', []).append('k8s CronJob %s (%s) skipped: its container runs `%s`, the V1 app\'s scheduler'
                                                       % (nm.group(1) if nm else '?', rel, v1))
                else:
                    rows.append(h.row('job:' + h.tokkey(nm.group(1) if nm else 'cronjob', SCHED_DROP),
                                      {'cron': h.cron(sc.group(1).strip()) if sc else '?', 'tz': tz.group(1).strip() if tz else '',
                                       'overlap': 'yes' if re.search(r'concurrencyPolicy:\s*["\']?Forbid', doc) else 'no', 'target': 'k8s CronJob'},
                                      rel, t, off + (sc.start() if sc else 0)))
            off += len(doc) + 4
    return rows


MONEYRX = {
    'py': [(r'(?<![\w.])round\(', 'half-even'), (r'\.quantize\(', 'Q'), (r'\bmath\.floor\(', 'floor'), (r'\bmath\.ceil\(', 'ceil'),
           (r'\bmath\.trunc\(', 'trunc')],
    'rb': [(r'\.round\b(?:\s*\(([^)\n]*)\))?', 'R'), (r'\.floor\b', 'floor'), (r'\.ceil\b', 'ceil'), (r'\.truncate\b', 'trunc')],
    'java': [(r'RoundingMode\.(\w+)', 'M'), (r'BigDecimal\.ROUND_(\w+)', 'M'), (r'\bMath\.round\(', 'half-up'), (r'\bMath\.floor\(', 'floor'),
             (r'\bMath\.ceil\(', 'ceil')],
    'go': [(r'\bmath\.Round\(', 'half-away'), (r'\bmath\.RoundToEven\(', 'half-even'), (r'\bmath\.Floor\(', 'floor'), (r'\bmath\.Ceil\(', 'ceil'),
           (r'\bmath\.Trunc\(', 'trunc'), (r'\.RoundBank\(', 'half-even'), (r'(?<!math)\.Round\(', 'half-away')],
    'js': [(r'\bMath\.round\(', 'half-up'), (r'\.toFixed\(', 'F'), (r'ROUND_HALF_UP|roundHalfUp', 'half-away'),
           (r'ROUND_HALF_EVEN|roundHalfEven', 'half-even'), (r'\bIntl\.NumberFormat\b', 'half-away'), (r'\bMath\.floor\(', 'floor'),
           (r'\bMath\.ceil\(', 'ceil'), (r'\bMath\.trunc\(', 'trunc')]}
MLANG = {'rails': ('rb', ['*.rb']), 'django': ('py', ['*.py']), 'fastapi': ('py', ['*.py']), 'spring': ('java', ['*.java', '*.kt']),
         'express': ('js', ['*.js', '*.ts', '*.mjs', '*.cjs']), 'fastify': ('js', ['*.js', '*.ts', '*.mjs', '*.cjs']), 'go': ('go', ['*.go'])}


def _money_path(h, *names):
    return any(w.startswith(MONEY) for n in names for w in h.words(n))


def lane_money(root, h, ctx):
    lang, globs = MLANG[ctx['stack']]
    rows = []
    for rel in _src(h, ctx, globs, keep=()):
        t, m, c = _t(h, rel, lang)
        if not re.search('|'.join(r for r, _ in MONEYRX[lang]), m):
            continue
        dec = re.search(r'decimal\.js|big\.js|bignumber\.js', c) is not None
        ctxr = re.search(r'getcontext\(\)\.rounding\s*=\s*(?:decimal\.)?ROUND_(\w+)', m)
        cls = [(b[2], b[4], b[1]) for b in _blocks(h, rel, lang) if b[0] == 'class'] if lang in ('py', 'rb') else \
            [(k['a'], k['b'], k['name']) for k in _jclasses(h, rel)] if lang == 'java' else []
        for name, s, a, b in _funcs(h, rel, lang):
            if not _money_path(h, name, os.path.basename(rel).split('.')[0], *[n for x, y, n in cls if x < s < y]):
                continue
            modes = set()
            for rx, md in MONEYRX[lang]:
                for x in re.finditer(rx, m[a:b]):
                    if md == 'Q':
                        q = m[a + x.end() - 1:h.close(m, a + x.end() - 1) + 1]
                        r = re.search(r'ROUND_(\w+)', q) or ctxr
                        modes.add(RMODE.get(r.group(1), '?') if r else 'half-even')
                    elif md == 'R':
                        g = x.group(1) or ''
                        modes.add('half-even' if re.search(r'half:\s*:even|HALF_EVEN|:banker', g) else '?' if re.search(r'half:\s*:down', g)
                                  else 'trunc' if re.search(r'ROUND_DOWN|:truncate', g) else 'half-away')
                    elif md == 'M':
                        modes.add(RMODE.get(x.group(1), '?'))
                    elif md == 'F':
                        modes.add('half-away' if dec else 'float-tofixed')
                    else:
                        modes.add(md)
            if modes:
                owner = ([n for x, y, n in cls if x < s < y] or ['<module>'])[-1]
                rows.append(_row(h, h.area(owner, rel, name), {'modes': ','.join(sorted(modes)), 'where': '%s.%s' % (owner, name)}, rel, s))
    return rows


def env_conf(root, h, ctx):
    rows = []
    for rel in _src(h, ctx, ['Dockerfile*', '*.Dockerfile']):
        t = h.read(rel)
        for x in re.finditer(r'^\s*ENV\s+TZ[=\s]+["\']?([\w/+\-]+)|-Duser\.timezone=([\w/+\-]+)', t, re.M):
            rows.append(_row(h, 'timezone', {'value': x.group(1) or x.group(2)}, rel, x.start()))
    for d in _dirs(h, ctx):
        for f in ('.env', '.env.example'):
            rel = os.path.join(d, f)
            if h.exists(rel):
                for x in re.finditer(r'^TZ=["\']?([\w/+\-]+)', h.read(rel), re.M):
                    rows.append(_row(h, 'timezone', {'value': x.group(1)}, rel, x.start()))
    return rows

# ---------------------------------------------------------------- registry helpers
R3 = {'I-ROUTES': lane_routes, 'I-AUTHZ': lane_authz, 'I-MONEY': lane_money}


def drop_catchall(lanes):
    """I-ERR: a catch-all handler (key `exc:`) maps no one error class — dropped from every stack's I-ERR rows."""
    for s in lanes:
        if 'I-ERR' in lanes[s]:
            lanes[s]['I-ERR'] = (lambda f: lambda root, h, ctx: [r for r in f(root, h, ctx) if r['key'] != 'exc:'])(lanes[s]['I-ERR'])
    return lanes


def gaps(stacks):
    return dict([((s, 'I-SCHEMA'), 'no DDL lane for %s (partial stack; run the database pack on both roots)' % s) for s in stacks]
                + [((s, 'I-RULES'), 'validation rules for %s are not joined to routes (partial stack; FastAPI Pydantic bodies only)' % s)
                   for s in stacks if s != 'fastapi']
                + [((s, 'I-SCOPE'), 'no ORM scope lane for %s (partial stack)' % s) for s in stacks if s in ('fastapi', 'express', 'fastify', 'go')]
                + [((s, 'I-ERR'), 'no error-mapping lane for Go (partial stack: handlers write statuses inline)') for s in stacks if s == 'go'])


# ---------------------------------------------------------------- self-test driver: one tiny tree per stack, good rows + decoys
def _L(*lines):
    return '\n'.join(lines) + '\n'


def run_samples(H, tmp, samples, detect, lanes):
    out = []
    for stack, (files, want, absent) in sorted(samples.items()):
        root = os.path.join(tmp, 'other-' + stack)
        for rel, body in files.items():
            p = os.path.join(root, rel)
            if not os.path.isdir(os.path.dirname(p)):
                os.makedirs(os.path.dirname(p))
            with open(p, 'w') as f:
                f.write(body)
        ev = detect(root, H(root, 'detect'))
        out.append(('%s detected (%s)' % (stack, ev.get(stack) or '-'), bool(ev.get(stack)), str(ev)))
        h, ctx, rows = H(root, 'v1'), {'stack': stack, 'evidence': ev.get(stack)}, {}
        for lane, fn in lanes[stack].items():
            try:
                rows[lane] = dict((r['key'], r['attrs']) for r in fn(root, h, ctx))
            except Exception as e:  # a crash is a failed check, never a silent pass
                rows[lane] = {}
                out.append(('%s %s runs' % (stack, lane), False, repr(e)))
        for lane, key, attrs in want:
            got = rows.get(lane, {}).get(key)
            bad = dict((k, (got or {}).get(k)) for k, v in attrs.items() if (got or {}).get(k) != v)
            out.append(('%s %s %s %s' % (stack, lane, key, attrs or ''), got is not None and not bad,
                        'missing (have: %s)' % ', '.join(sorted(rows.get(lane, {}))[:8]) if got is None else 'got %s' % bad))
        for lane, key in absent:
            out.append(('%s %s decoy %s absent' % (stack, lane, key), key not in rows.get(lane, {}), 'decoy row present'))
    return out
