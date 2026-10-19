#!/usr/bin/env python3
"""surface-map.py — feature-surface-scan §1-§5: served routes x client references, page routes x links,
shipped placeholders and dead affordances. Stdlib only, Python 3.8+, run with `python3 -I`.

Why a script and not rg: "this call has no server" is a JOIN. A client writes `http.get('stores')`,
`` fetch(`${API}/orders/${id}`) `` or `<form action="/api/tasks/bulk">`; the server writes
`@Controller('stores') @Get()` under `setGlobalPrefix('api')` and URI versioning, `APIRouter(prefix=)`
under `include_router(prefix=)`, or `app.use('/api', router)`. A per-line grep sees one side; the join
needs both tables, normalised (params, prefixes, versions, trailing slashes) and compared.

Usage:  python3 -I surface-map.py [<root> ...] [--classes=1,2,3,4,5] [--client=http,api,...]
            [--routes-from=<tsv>] [--reasons=<file>] [--include-tests] [--inventory] [--max=N] [--json]
        python3 -I surface-map.py --self-test
Lanes, served routes: NestJS (@Controller + verb decorators, setGlobalPrefix, URI versioning),
  Express / Fastify / Koa / Hono (router vars, app.use / route / register prefixes through relative
  imports), Next.js (app/**/route.*, pages/api/**), SvelteKit (+server.*), FastAPI / Flask (APIRouter
  prefix, include_router, Blueprint url_prefix, register_blueprint), Django (urls.py path / re_path /
  include, DRF router.register), Rails (config/routes.rb: namespace, scope, resources, verbs), Laravel
  (routes/*.php: verbs, resource, apiResource, prefix groups; api.php gets /api), Go (net/http 1.22
  patterns, chi, gin, echo, groups). --routes-from adds rows from any TSV holding `METHOD /path` cells
  (the migration pack's pair-inventory I-ROUTES record, a framework route dump).
Lanes, page routes: React Router / Vue Router / Angular / TanStack objects and <Route> JSX (nested
  `path` composed through `children`), Flutter GoRoute, Next app + pages trees, Nuxt pages,
  SvelteKit +page, Remix / React Router framework flat routes, React Navigation screen names.
  A root catch-all (`*`, `/*`, `[...slug]` at the top) is the not-found boundary and serves nothing.
Lanes, references: fetch / axios / ky / ofetch / $fetch / useFetch / useSWR / dio and member calls
  on client receivers (default http, api, apiClient, httpClient, client, axios, ky, $http, $axios,
  dio, request; add the project's own with --client=); href / to / navigate / router.push|replace /
  redirect / <Navigate> / window.location / context.go|push; <form action> (POST forms join served
  routes, GET forms join pages); navigation.navigate('Screen') against screen names.
Classes (rows):
  FS1  a call whose (method, path) no served route answers after normalisation. `near` names the
       closest served route (method-mismatch, prefix?), `tags` marks gate fetches (permission,
       entitlement, feature, module, plan, can, access) - the fail-open shape.
  FS2  a served route no reference names. `tags`: webhook, callback, oauth, health, metrics, public,
       internal, cron, well-known, writes (non-GET), explained(<reason>) from --reasons.
  FS3  a link / redirect / GET form whose path no page route and no served GET route answers.
  FS4  copy (placeholder phrase in JSX/template text or a UI string), catalog (a placeholder value in
       a locale file), not-implemented (501 / NotImplemented / TODO() bodies, with the enclosing
       route as `handler`), mock-rows (>= 2 literal records returned or held by a function with no
       data call; a record = every value a literal plus a number or a contact / money / date key, so
       column, option and tab configs do not count), mock-import (__mocks__/, mocks/, fixtures/, faker,
       msw worker with gated=yes|no),
       use-mocks (USE_MOCKS=true and kin, env files included).
  FS5  noop-handler, hash-href, literal-disabled, form-no-action (JSX <form> with neither action nor
       onSubmit), flutter-null-handler; `near` names a real handler within 40 lines (PP-FS-3 read).
  CONTROL  test files that look like the project's own route-parity / link gate (run them first).
Output: TSV, one `# KIND` header per kind, or --json. --inventory also prints ROUTE, PAGE, REF rows.
Stderr: the ledger - files per lane, route / page / reference counts, unresolved and external
  references, prefixes stripped, lanes present but not joined (tRPC, RouterModule paths), `join: SUSPECT`
  when over half the calls are unserved and over half the routes uncalled, `calls: blocked` with no
  served routes, `uncalled: N/A` with no client references. Calls from server packages are `outbound`;
  scripts/, tools/, docs/ and design-system docs are not shipped surface.
Exit:   0 no FS1 / FS3 row (the two-ended joins) · 2 at least one FS1 or FS3 row · 1 usage or unreadable
        root · 3 self-test failed. FS2, FS4, FS5 and CONTROL rows are read lists and never set the exit code. Reads files; writes nothing (the self-test uses a temp dir it removes).
"""
import bisect, json, os, re, shutil, sys, tempfile, time

SKIP_DIRS = {'node_modules', 'vendor', 'dist', 'build', 'out', '.next', '.nuxt', '.output', '.svelte-kit',
             '.turbo', 'coverage', '.git', '.venv', 'venv', '__pycache__', 'generated', '__generated__',
             '.dart_tool', 'Pods', 'DerivedData', 'target', '.angular', 'storybook-static', '.cache', 'tmp'}
TEST_DIRS = {'test', 'tests', '__tests__', 'spec', 'specs', 'e2e', 'fixtures', '__fixtures__', 'mocks',
             '__mocks__', 'testdata', 'stories', 'cypress', 'playwright'}
TEST_FILE = re.compile(r'(\.(spec|test|e2e-spec|e2e|stories|story|test-data|fixture|fixtures)\.[^/]+$)|'
                       r'(^|/)(test_[^/]+\.py|[^/]+_test\.(go|py|dart)|conftest\.py)$')
EXT = {'.ts': 'js', '.tsx': 'js', '.js': 'js', '.jsx': 'js', '.mjs': 'js', '.cjs': 'js', '.mts': 'js',
       '.vue': 'vue', '.svelte': 'vue', '.astro': 'vue', '.py': 'py', '.rb': 'rb', '.go': 'go',
       '.dart': 'dart', '.kt': 'kt', '.php': 'php', '.html': 'html', '.htm': 'html', '.jinja': 'html',
       '.jinja2': 'html', '.j2': 'html', '.erb': 'html', '.twig': 'html'}
CATALOG_DIR = re.compile(r'(^|/)(locales?|i18n|l10n|lang|translations|messages|intl)(/|$)')
CATALOG_EXT = ('.json', '.yml', '.yaml', '.arb', '.po')
VERBS = ('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS')
DEFAULT_CLIENTS = ['http', 'api', 'apiClient', 'httpClient', 'client', 'axios', 'ky', '$http', '$axios',
                   'dio', '_dio', 'request', 'this.http', 'this.api', 'this.client']
NOT_SHIPPED = re.compile(r'(?:^|/)(?:scripts|tools|bin|devtools|playground|examples?|docs?|design-system/docs|storybook|\.storybook)(?:/|$)')
PLACEHOLDER = r'(?:coming soon|lorem ipsum|under construction|not (?:yet )?implemented|work in progress|placeholder text)'
PLACEHOLDER_TEXT = re.compile(r'(?i)\b' + PLACEHOLDER + r'\b|(?<![\w-])(?:TODO|TBD|FIXME)(?![\w-])')
PLACEHOLDER_STR = re.compile(r'(?i)\b' + PLACEHOLDER + r'\b')
GATE_WORDS = re.compile(r'(?i)permission|entitlement|feature|module|plan|subscription|(?:^|/)can(?:/|$)|access|role|grant')
EXT_TAGS = [('webhook', r'webhook|hook(?:s)?/'), ('callback', r'callback|return(?:-url)?'), ('oauth', r'oauth|sso|saml'),
            ('health', r'health|healthz|ready|readyz|live|livez|ping|status'), ('metrics', r'metrics|prometheus'),
            ('well-known', r'\.well-known'), ('internal', r'internal|admin/jobs|cron|tasks/run'),
            ('public', r'public|partner|external|/v\d+/')]

# ---------------------------------------------------------------- reading and masking
class F(object):
    __slots__ = ('path', 'rel', 'lang', 'raw', 'code', 'nl', 'test')

    def __init__(self, path, rel, lang, raw, test):
        self.path, self.rel, self.lang, self.raw, self.test = path, rel, lang, raw, test
        self.code = mask(raw, lang)
        self.nl = [i for i, c in enumerate(raw) if c == '\n']

    def line(self, pos):
        return bisect.bisect_left(self.nl, pos) + 1

    def where(self, pos):
        return '%s:%d' % (self.rel, self.line(pos))


def mask(s, lang):
    """Blank comments (never strings), keeping offsets and newlines."""
    out, i, n = list(s), 0, len(s)
    hash_c = lang in ('py', 'rb')
    slash_c = lang in ('js', 'vue', 'go', 'dart', 'kt', 'php')
    html_c = lang in ('html', 'vue')

    def blank(a, b):
        for k in range(a, min(b, n)):
            if out[k] != '\n':
                out[k] = ' '
    while i < n:
        c = s[i]
        if html_c and s.startswith('<!--', i):
            j = s.find('-->', i + 4); j = n if j < 0 else j + 3; blank(i, j); i = j; continue
        if lang == 'html' and (s.startswith('{#', i) or s.startswith('<%#', i)):
            j = s.find('#}' if s[i + 1] == '#' else '%>', i + 2); j = n if j < 0 else j + 2; blank(i, j); i = j; continue
        if lang == 'html':
            i += 1; continue
        if lang == 'py' and s.startswith(('"""', "'''"), i):
            q = s[i:i + 3]; j = s.find(q, i + 3); j = n if j < 0 else j + 3
            k = i - 1
            while k >= 0 and s[k] in ' \t':
                k -= 1
            if k < 0 or s[k] == '\n':          # a docstring / bare string statement is prose
                blank(i, j)
            i = j; continue
        if c in '"\'' or (c == '`' and lang in ('js', 'vue', 'go')):
            i = skip_str(s, i); continue
        if slash_c and s.startswith('//', i) and not (i > 0 and s[i - 1] == ':'):
            j = s.find('\n', i); j = n if j < 0 else j; blank(i, j); i = j; continue
        if slash_c and s.startswith('/*', i):
            j = s.find('*/', i + 2); j = n if j < 0 else j + 2; blank(i, j); i = j; continue
        if hash_c and c == '#' and not (lang == 'rb' and i > 0 and s[i - 1] == '{'):
            j = s.find('\n', i); j = n if j < 0 else j; blank(i, j); i = j; continue
        i += 1
    return ''.join(out)


def skip_str(s, i):
    q, j, n, depth = s[i], i + 1, len(s), 0
    while j < n:
        c = s[j]
        if c == '\\':
            j += 2; continue
        if q == '`' and s.startswith('${', j):
            depth += 1; j += 2; continue
        if q == '`' and depth and c == '}':
            depth -= 1; j += 1; continue
        if c == q and not depth:
            return j + 1
        if c == '\n' and q != '`':
            return j
        j += 1
    return n


def close_of(s, i):
    """Index just past the bracket matching s[i] ('(', '[', '{'), skipping strings."""
    pair = {'(': ')', '[': ']', '{': '}'}
    stack, j, n = [], i, len(s)
    while j < n:
        c = s[j]
        if c in '"\'`':
            j = skip_str(s, j); continue
        if c in pair:
            stack.append(pair[c])
        elif c in ')]}':
            if not stack or stack[-1] != c:
                return j + 1
            stack.pop()
            if not stack:
                return j + 1
        j += 1
    return n


def walk(roots, include_tests, ledger):
    files, controls, catalogs, envs = [], [], [], []
    for root in roots:
        for d, dirs, names in os.walk(root):
            dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS and not (x.startswith('.') and x not in ('.github',)))
            for nm in sorted(names):
                p = os.path.join(d, nm)
                rel = os.path.relpath(p, root) if len(roots) == 1 else p
                rel = rel.replace(os.sep, '/')
                parts = set(rel.split('/')[:-1])
                is_test = bool(parts & TEST_DIRS) or bool(TEST_FILE.search(rel))
                if is_test and re.search(r'(?i)every-call|served-route|route.?parity|routes?-(?:are|is)-(?:used|served)|'
                                         r'route.*(?:used|explained)|unserved|orphan.*route|dead.?link|every-link', nm):
                    controls.append(rel)
                ext = os.path.splitext(nm)[1].lower()
                if nm.startswith('.env') and not nm.endswith(('.example', '.sample', '.template')):
                    envs.append((p, rel)); continue
                if CATALOG_DIR.search(rel) and ext in CATALOG_EXT and not is_test:
                    catalogs.append((p, rel)); continue
                lang = EXT.get(ext)
                if not lang or (is_test and not include_tests):
                    if lang and is_test:
                        ledger['tests skipped'] = ledger.get('tests skipped', 0) + 1
                    continue
                try:
                    with open(p, encoding='utf-8', errors='replace') as fh:
                        raw = fh.read()
                except OSError as e:
                    ledger.setdefault('unreadable', []).append('%s (%s)' % (rel, e.strerror)); continue
                if len(raw) > 2000000 or ('\n' not in raw[:5000] and len(raw) > 20000):
                    ledger['minified skipped'] = ledger.get('minified skipped', 0) + 1; continue
                files.append(F(p, rel, lang, raw, is_test))
    return files, controls, catalogs, envs


# ---------------------------------------------------------------- path normalisation and matching
PARAM_SEG = re.compile(r'^(?::\w+\??|\{[^}]*\}|<[^>]*>|\[[^\]]*\]|\$\w*|\(\?P<\w+>[^)]*\)|\([^)]*\)|\*\w*|\{\}|\{\*\})$')


def canon(path, strip):
    p = re.sub(r'\$\{[^}]*\}', '{}', path.strip())
    p = p.split('?')[0].split('#')[0]
    p = re.sub(r'^\^|\$$', '', p)
    segs = [x for x in p.split('/') if x and x != '.']
    out = []
    for x in segs:
        if x in ('*', '**') or re.match(r'^\[\[?\.\.\.', x) or x.startswith('*') or re.match(r'^\{\w*\*\}$|^\{\*\w*\}$|^:\w+\*$|^\$$', x):
            out.append('{*}'); break
        if PARAM_SEG.match(x) or '{}' in x and x != '{}' and re.fullmatch(r'[\w.-]*\{\}[\w.-]*', x) and x.count('{}') == 1 and x.strip('{}') == '':
            out.append('{}'); continue
        if x.startswith('(') and x.endswith(')'):          # Next route group
            continue
        out.append(x.lower() if not x.startswith('{') else x)
    while out and (out[0] in strip or re.match(r'^v\d+$', out[0])):
        out.pop(0)
    return '/' + '/'.join(out)


def seg_match(a, b):
    """True when two canonical paths can name the same URL; '{}' matches any one segment, '{*}' the rest."""
    x, y = a.strip('/').split('/') if a != '/' else [], b.strip('/').split('/') if b != '/' else []
    i = 0
    while True:
        if i < len(x) and x[i] == '{*}' or i < len(y) and y[i] == '{*}':
            return True
        if i == len(x) or i == len(y):
            return i == len(x) == len(y)
        if x[i] != y[i] and x[i] != '{}' and y[i] != '{}' and not ('{}' in x[i] or '{}' in y[i]):
            return False
        i += 1


class Index(object):
    def __init__(self):
        self.by_len = {}

    def add(self, cpath, item):
        n = 0 if cpath == '/' else cpath.count('/')
        key = -1 if '{*}' in cpath else n
        self.by_len.setdefault(key, []).append((cpath, item))

    def find(self, cpath):
        n = 0 if cpath == '/' else cpath.count('/')
        hits = [it for cp, it in self.by_len.get(n, []) if cp == cpath]
        if hits:
            return hits
        hits = [it for cp, it in self.by_len.get(n, []) if seg_match(cp, cpath)]
        return hits + [it for cp, it in self.by_len.get(-1, []) if seg_match(cp, cpath)]


# ---------------------------------------------------------------- served-route lanes
class Route(object):
    __slots__ = ('method', 'raw', 'cpath', 'file', 'line', 'lane', 'called', 'public', 'view')

    def __init__(self, method, raw, file, line, lane, public=False):
        self.method, self.raw, self.file, self.line, self.lane = method.upper(), raw, file, line, lane
        self.cpath, self.called, self.public, self.view = '', False, public, ''


def lit(s):
    m = re.match(r'\s*(?:r|f|u|b)?([\'"`])((?:\\.|(?!\1).)*)\1', s)
    return m.group(2) if m else None


def lits(s):
    return [m.group(2) for m in re.finditer(r'([\'"`])((?:\\.|(?!\1)[^\n])*)\1', s)]


def join(*parts):
    p = '/'.join(x.strip('/') for x in parts if x is not None and x.strip('/'))
    return '/' + p


def lane_nest(f, out, ctx):
    s = f.code
    if '@Controller' not in s and 'setGlobalPrefix' not in s:
        return
    for m in re.finditer(r'\.setGlobalPrefix\(\s*([\'"`])([^\'"`]+)\1', s):
        ctx['strip'].add(m.group(2).strip('/').split('/')[0].lower())
    if 'RouterModule.register' in s:
        ctx['notes'].add('RouterModule.register present (%s) - its module paths are not composed' % f.rel)
    ctrls = []
    for m in re.finditer(r'@Controller\s*\(', s):
        e = close_of(s, m.end() - 1)
        arg = s[m.end():e - 1]
        pm = re.search(r'path\s*:\s*(\[[^\]]*\]|[\'"`][^\'"`]*[\'"`])', arg)
        src = pm.group(1) if pm else arg
        prefixes = lits(src) if src.strip().startswith('[') or pm is None else lits(src)
        ctrls.append((m.start(), prefixes or ['']))
    if not ctrls:
        return
    starts = [c[0] for c in ctrls]
    for m in re.finditer(r'@(Get|Post|Put|Patch|Delete|All|Head|Options)\s*\(', s):
        i = bisect.bisect_right(starts, m.start()) - 1
        if i < 0:
            continue
        e = close_of(s, m.end() - 1)
        paths = lits(s[m.end():e - 1]) or ['']
        pub = bool(re.search(r'@Public\s*\(|@ApiExcludeEndpoint|@SkipAuth', s[max(0, m.start() - 300):m.start()]))
        for pre in ctrls[i][1]:
            for p in paths:
                verb = m.group(1).upper()
                out.append(Route('ANY' if verb == 'ALL' else verb, join(pre, p), f.rel, f.line(m.start()), 'nest', pub))


SERVER_IMPORT = re.compile(r'from\s+[\'"](?:express|fastify|koa|@koa/router|koa-router|hono|restify|polka|elysia|@hono/[\w-]+)[\'"]|'
                           r'require\(\s*[\'"](?:express|fastify|koa|@koa/router|koa-router|hono|restify|polka)[\'"]\s*\)')
ROUTER_VAR = re.compile(r'(?:const|let|var)\s+(\w+)\s*(?::[^=]+)?=\s*(?:await\s+)?(?:express\.Router|Router|express|new\s+(?:Hono|Router|Koa|Elysia|OpenAPIHono)|'
                        r'fastify|Fastify|createRouter|polka|restify\.createServer)\s*(?:<[^>]*>)?\(')


def lane_express(f, out, ctx, imports):
    s = f.code
    if f.lang != 'js' or not SERVER_IMPORT.search(s):
        return
    rv = set(m.group(1) for m in ROUTER_VAR.finditer(s)) | {'app', 'router', 'server', 'fastify', 'api', 'r', 'routes'}
    for m in re.finditer(r'\b([\w$]+)\s*\.\s*(get|post|put|patch|delete|del|all|options|head)\s*\(\s*([\'"`])(/[^\'"`]*)\3', s):
        if m.group(1) in rv:
            v = m.group(2).upper()
            out.append(Route('DELETE' if v == 'DEL' else ('ANY' if v == 'ALL' else v), m.group(4), f.rel, f.line(m.start()), 'express'))
    for m in re.finditer(r'\.route\(\s*\{', s):
        body = s[m.end() - 1:close_of(s, m.end() - 1)]
        u, me = re.search(r'\burl\s*:\s*[\'"`](/[^\'"`]*)', body), re.search(r'\bmethod\s*:\s*(\[[^\]]*\]|[\'"`]\w+[\'"`])', body)
        if u:
            for v in (lits(me.group(1)) if me else ['GET']):
                out.append(Route(v, u.group(1), f.rel, f.line(m.start()), 'fastify'))
    # mounts: app.use('/api', ordersRouter) · app.route('/x', sub) · fastify.register(plugin, { prefix: '/x' })
    for m in re.finditer(r'\.(?:use|route)\(\s*([\'"`])(/[^\'"`]*)\1\s*,\s*(?:[\w.]+\(\s*\)\s*,\s*)*([\w$]+)', s):
        ctx['mounts'].append((f.rel, m.group(3), m.group(2), imports.get((f.rel, m.group(3)))))
    for m in re.finditer(r'\.register\(\s*([\w$]+)\s*,\s*\{[^}]*\bprefix\s*:\s*([\'"`])(/[^\'"`]*)\2', s):
        ctx['mounts'].append((f.rel, m.group(1), m.group(3), imports.get((f.rel, m.group(1)))))


def js_imports(f, by_rel):
    out = {}
    base = os.path.dirname(f.rel)
    for m in re.finditer(r'import\s+(?:([\w$]+)|\{([^}]*)\})\s+from\s+[\'"](\.[^\'"]+)[\'"]|(?:const|let|var)\s+([\w$]+)\s*=\s*require\(\s*[\'"](\.[^\'"]+)[\'"]', f.code):
        spec = m.group(3) or m.group(5)
        names = [m.group(1) or m.group(4)] if (m.group(1) or m.group(4)) else \
            [x.split(' as ')[-1].strip() for x in (m.group(2) or '').split(',') if x.strip()]
        tgt = os.path.normpath(os.path.join(base, spec)).replace(os.sep, '/')
        hit = None
        for cand in (tgt, tgt + '.ts', tgt + '.js', tgt + '.mjs', tgt + '/index.ts', tgt + '/index.js'):
            if cand in by_rel:
                hit = cand; break
        for nm in names:
            if hit:
                out[(f.rel, nm)] = hit
    return out


def file_route(segs):
    """File-system route segments -> URL path: groups dropped, `index` empty, private/parallel folders skip."""
    out = []
    for x in segs:
        if x.startswith('(') and x.endswith(')') or x == 'index':
            continue
        out.append(x)
    return '/' + '/'.join(out)


def lane_next(f, out, pages, ctx):
    rel = f.rel
    fw, pdir = ctx['fw'](f)
    if not fw:
        return
    tail = os.path.relpath(f.path, pdir).replace(os.sep, '/')
    tail = tail[4:] if tail.startswith('src/') and not tail.startswith('src/routes/') else tail
    noext = re.sub(r'\.(tsx|jsx|ts|js|mjs|vue|mdx|svelte)$', '', tail)
    if tail.startswith('app/') and 'next' in fw:
        segs = tail.split('/')[1:]
        if any(x.startswith('_') or x.startswith('@') for x in segs[:-1]):
            return
        if re.match(r'route\.(ts|js|mjs)$', segs[-1]):
            for v in re.findall(r'export\s+(?:async\s+)?(?:function|const)\s+(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\b', f.code) or ['ANY']:
                out.append(Route(v, file_route(segs[:-1]), rel, 1, 'next-app'))
        elif re.match(r'page\.(tsx|jsx|ts|js|mdx)$', segs[-1]):
            pages.append((file_route(segs[:-1]), rel, 1, 'next-app'))
    elif tail.startswith('app/') and 'expo' in fw and re.search(r'\.(tsx|jsx|ts|js)$', tail):
        segs = noext.split('/')[1:]
        if segs[-1].startswith(('_layout', '+')) or any(x.startswith('_') for x in segs):
            return
        pages.append((file_route(segs), rel, 1, 'expo-router'))
    elif tail.startswith('pages/') and ('next' in fw or 'nuxt' in fw) and re.search(r'\.(tsx|jsx|ts|js|vue|mdx)$', tail):
        segs = noext.split('/')[1:]
        if segs[-1] in ('_app', '_document', '_error', '404', '500'):
            return
        if segs[0] == 'api':
            out.append(Route('ANY', file_route(segs), rel, 1, 'next-pages-api'))
        else:
            pages.append((file_route(segs), rel, 1, 'nuxt' if f.lang == 'vue' else 'next-pages'))
    elif tail.startswith('src/routes/') and 'svelte' in fw:
        segs = tail.split('/')[2:]
        if re.match(r'\+page\.(svelte|ts|js)$', segs[-1]):
            pages.append((file_route(segs[:-1]), rel, 1, 'sveltekit'))
        elif re.match(r'\+server\.(ts|js)$', segs[-1]):
            for v in re.findall(r'export\s+(?:async\s+)?(?:function|const)\s+(GET|POST|PUT|PATCH|DELETE)\b', f.code) or ['ANY']:
                out.append(Route(v, file_route(segs[:-1]), rel, 1, 'sveltekit'))
    elif re.match(r'(?:app|src)/routes/', tail) and 'remix' in fw and re.search(r'\.(tsx|jsx|ts|js)$', tail):
        name = noext.split('/')[2] if noext.count('/') >= 2 else ''
        if not name or name.startswith('_') and '.' not in name and name != '_index':
            return
        segs = [x.rstrip('_') for x in name.split('.') if (not x.startswith('_') or x == '_index') and x != '_index' and x != 'route']
        pages.append(('/' + '/'.join(segs), rel, 1, 'flat-routes'))
        if re.search(r'export\s+(?:async\s+)?(?:function|const)\s+action\b', f.code):
            out.append(Route('POST', '/' + '/'.join(segs), rel, 1, 'route-action'))


PY_ROUTER = re.compile(r'^(\w+)\s*=\s*(APIRouter|Blueprint|FastAPI|Flask)\s*\(', re.M)


def lane_python(f, out, ctx):
    s = f.code
    if f.lang != 'py':
        return
    for m in PY_ROUTER.finditer(s):
        args = s[m.end():close_of(s, m.end() - 1) - 1]
        pm = re.search(r'\b(?:prefix|url_prefix)\s*=\s*(?:r|f)?([\'"])([^\'"]*)\1', args)
        ctx['pyvars'][(f.rel, m.group(1))] = pm.group(2) if pm else ''
    for m in re.finditer(r'^[ \t]*@(\w+)\.(get|post|put|patch|delete|api_route|route|websocket)\s*\(\s*(?:path\s*=\s*)?r?([\'"])([^\'"]*)\3', s, re.M):
        e = close_of(s, s.index('(', m.start()))
        rest = s[m.end():e]
        if m.group(2) in ('route', 'api_route'):
            mm = re.search(r'methods\s*=\s*\[([^\]]*)\]', rest)
            verbs = [x.upper() for x in lits(mm.group(1))] if mm else ['GET']
        else:
            verbs = ['GET' if m.group(2) == 'websocket' else m.group(2).upper()]
        for v in verbs:
            r = Route(v, m.group(4), f.rel, f.line(m.start()), 'fastapi/flask')
            r.cpath = m.group(1)            # router var until prefixes resolve
            out.append(r)
    for m in re.finditer(r'\.(include_router|register_blueprint)\s*\(\s*([\w.]+)', s):
        e = close_of(s, s.index('(', m.start()))
        pm = re.search(r'\b(?:prefix|url_prefix)\s*=\s*r?([\'"])([^\'"]*)\1', s[m.end():e])
        ctx['pyinc'].append((f.rel, m.group(2), pm.group(2) if pm else ''))
    for m in re.finditer(r'^[ \t]*from\s+(\.*[\w.]*)\s+import\s+([^\n(]+|\([^)]*\))', s, re.M):
        for part in m.group(2).strip('() \n').split(','):
            bits = part.strip().split(' as ')
            if bits and bits[0].strip():
                ctx['pyimp'][(f.rel, bits[-1].strip())] = (m.group(1), bits[0].strip())
    if os.path.basename(f.rel) == 'urls.py':
        lane_django(f, out, ctx)


def py_module_file(rel, mod, by_rel):
    base = os.path.dirname(rel)
    dots = len(mod) - len(mod.lstrip('.'))
    name = mod.lstrip('.').replace('.', '/')
    cands = []
    if dots:
        up = base
        for _ in range(dots - 1):
            up = os.path.dirname(up)
        cands.append(os.path.normpath(os.path.join(up, name)).replace(os.sep, '/'))
    cands += [r[:-3] for r in by_rel if r.endswith('/' + name + '.py') or r == name + '.py']
    cands += [r[:-12] for r in by_rel if r.endswith('/' + name + '/__init__.py')]
    for c in cands:
        for x in (c + '.py', c + '/__init__.py'):
            if x in by_rel:
                return x
    return None


def resolve_python(routes, ctx, by_rel):
    prefix = dict(ctx['pyvars'])
    extra = {}
    for rel, ref, pre in ctx['pyinc']:
        tgt = None
        if '.' in ref:
            alias, var = ref.rsplit('.', 1)
            imp = ctx['pyimp'].get((rel, alias))
            mod = (imp[0] + '.' + imp[1]) if imp and imp[0].strip('.') else ((imp[0] + imp[1]) if imp else alias)
            mf = py_module_file(rel, mod, by_rel)
            tgt = (mf, var) if mf else None
        else:
            imp = ctx['pyimp'].get((rel, ref))
            if imp:
                mf = py_module_file(rel, imp[0], by_rel)
                tgt = (mf, imp[1]) if mf else None
            else:
                tgt = (rel, ref)
        if tgt:
            extra.setdefault(tgt, []).append(pre)
        else:
            ctx['notes'].add('include %s in %s not resolved' % (ref, rel))
    for r in routes:
        if r.lane != 'fastapi/flask':
            continue
        key = (r.file, r.cpath)
        pres = extra.get(key, [''])
        r.raw = join(pres[0], prefix.get(key, ''), r.raw) if r.raw else join(pres[0], prefix.get(key, ''))
        r.cpath = ''


def lane_django(f, out, ctx):
    s = f.code
    reg = []
    for m in re.finditer(r'\b(?:re_)?path\s*\(\s*r?([\'"])([^\'"]*)\1\s*,\s*(include\s*\(\s*(?:r?[\'"]([\w.]+)[\'"]|([\w.]+))|[^,)]+)', s):
        p = m.group(2)
        if m.group(0).lstrip().startswith('re_'):
            p = re.sub(r'\(\?P<\w+>[^)]*\)', '{}', p).strip('^$')
        if m.group(4):
            ctx['djinc'].append((f.rel, p, m.group(4)))
        elif m.group(5) and m.group(5).endswith('.urls'):
            reg.append((p, m.group(5).split('.')[0]))
        else:
            r = Route('ANY', '/' + p, f.rel, f.line(m.start()), 'django')
            vm = re.match(r'\s*(?:[\w]+\.)*(\w+)\s*(?:\.as_view\b|$)', m.group(3))
            r.view = vm.group(1) if vm else ''
            out.append(r)
    for m in re.finditer(r'\b(\w+)\.register\(\s*r?([\'"])\^?([^\'"]*)\2(?:\s*,\s*(?:[\w]+\.)*(\w+))?', s):
        pre = ''.join(p for p, var in reg if var == m.group(1))
        r = Route('ANY', join(pre, m.group(3)), f.rel, f.line(m.start()), 'drf')
        r.view = m.group(4) or ''
        out.append(r)                     # expanded into its methods by drf_expand (ANY collection + item when unread)


# DRF / Django class-based views: which methods a registered ViewSet or an as_view() class serves.
DRF_ACTIONS = {'list': ('GET', False), 'create': ('POST', False), 'retrieve': ('GET', True), 'update': ('PUT', True),
               'partial_update': ('PATCH', True), 'destroy': ('DELETE', True)}
DRF_BASES = {'ModelViewSet': ('list', 'create', 'retrieve', 'update', 'partial_update', 'destroy'),
             'ReadOnlyModelViewSet': ('list', 'retrieve'), 'ListModelMixin': ('list',), 'CreateModelMixin': ('create',),
             'RetrieveModelMixin': ('retrieve',), 'UpdateModelMixin': ('update', 'partial_update'),
             'DestroyModelMixin': ('destroy',)}
VIEW_BASES = {'ListAPIView': 'GET', 'CreateAPIView': 'POST', 'ListCreateAPIView': 'GET POST', 'RetrieveAPIView': 'GET',
              'DestroyAPIView': 'DELETE', 'UpdateAPIView': 'PUT PATCH', 'RetrieveUpdateAPIView': 'GET PUT PATCH',
              'RetrieveDestroyAPIView': 'GET DELETE', 'RetrieveUpdateDestroyAPIView': 'GET PUT PATCH DELETE',
              'TemplateView': 'GET', 'RedirectView': 'GET', 'ListView': 'GET', 'DetailView': 'GET', 'FormView': 'GET POST',
              'CreateView': 'GET POST', 'UpdateView': 'GET POST', 'DeleteView': 'GET POST'}
HTTP_DEFS = ('get', 'post', 'put', 'patch', 'delete', 'head', 'options')


def py_classes(by_rel):
    """{name: (bases, {def: decorator text}, rel)} for every Python class, and {function: decorator text}."""
    classes, funcs = {}, {}
    for rel, f in by_rel.items():
        if f.lang != 'py':
            continue
        raw = f.raw
        for m in re.finditer(r'^class\s+(\w+)\s*\(([^)]*)\)\s*:', raw, re.M):
            body = []
            for ln in raw[m.end():].split('\n')[1:]:
                if ln.strip() and not ln[:1].isspace():
                    break
                body.append(ln)
            text = '\n'.join(body)
            ind = min((len(x) - len(x.lstrip()) for x in body if x.strip()), default=4)
            defs, deco = {}, []
            for ln in body:
                if not ln.strip() or len(ln) - len(ln.lstrip()) != ind:
                    continue
                t = ln.strip()
                if t.startswith('@'):
                    deco.append(t)
                elif re.match(r'(?:async\s+)?def\s+\w+', t):
                    defs[re.match(r'(?:async\s+)?def\s+(\w+)', t).group(1)] = '\n'.join(deco)
                    deco = []
                else:
                    deco = []
            bases = [b.strip().split('.')[-1] for b in m.group(2).split(',') if b.strip() and '=' not in b]
            classes.setdefault(m.group(1), (bases, defs, rel, text))
        for m in re.finditer(r'((?:^@[^\n]*\n)+)(?:async\s+)?def\s+(\w+)', raw, re.M):
            funcs.setdefault(m.group(2), m.group(1))
    return classes, funcs


def drf_view(name, classes, depth=0):
    """(standard actions, [(detail, [methods], url_path)], http method defs) or None when the class is not read."""
    if name not in classes or depth > 4:
        return None
    bases, defs, rel, _ = classes[name]
    std, extra, http = set(), [], set()
    for b in bases:
        std |= set(DRF_BASES.get(b, ()))
        http |= set(VIEW_BASES.get(b, '').split())
        sub = drf_view(b, classes, depth + 1)
        if sub:
            std |= sub[0]
            extra += sub[1]
            http |= sub[2]
    for d, deco in defs.items():
        if d in DRF_ACTIONS:
            std.add(d)
        if d in HTTP_DEFS:
            http.add(d.upper())
        am = re.search(r'@action\s*\(([^)]*)\)', deco)
        if am:
            args = am.group(1)
            mm = re.search(r'methods\s*=\s*[\[(]([^\])]*)[\])]', args)
            meths = [x.upper() for x in lits(mm.group(1))] if mm else ['GET']
            up = re.search(r'url_path\s*=\s*r?([\'"])([^\'"]*)\1', args)
            extra.append((bool(re.search(r'detail\s*=\s*True', args)), meths, up.group(2) if up else d))
    return std, extra, http


def drf_expand(routes, by_rel):
    """Give DRF router routes and as_view() / @api_view routes their methods; unread views stay ANY."""
    if not any(r.lane in ('drf', 'django') and r.view for r in routes):
        return
    classes, funcs = py_classes(by_rel)
    out = []
    for r in routes:
        if r.lane == 'drf':
            v = drf_view(r.view, classes) if r.view else None
            if v is None:
                out.append(r)
                out.append(Route('ANY', r.raw.rstrip('/') + '/{}', r.file, r.line, 'drf'))
                continue
            std, extra, http = v
            coll = r.raw.rstrip('/') or '/'
            for a in sorted(std, key=lambda x: list(DRF_ACTIONS).index(x)):
                meth, item = DRF_ACTIONS[a]
                out.append(Route(meth, coll + '/{}' if item else coll, r.file, r.line, 'drf'))
            for detail, meths, up in extra:
                for meth in meths:
                    out.append(Route(meth, join(coll, '{}' if detail else '', up), r.file, r.line, 'drf'))
            continue
        if r.lane == 'django' and r.view:
            meths = set()
            v = drf_view(r.view, classes)
            if v is not None:
                meths = v[2]
            elif r.view in funcs:
                deco = funcs[r.view]
                am = re.search(r'@(?:api_view|require_http_methods)\s*\(\s*[\[(]([^\])]*)[\])]', deco)
                meths = set(x.upper() for x in lits(am.group(1))) if am else set()
                meths |= {'POST'} if '@require_POST' in deco else set()
                meths |= {'GET'} if '@require_GET' in deco else set()
                meths |= {'GET', 'HEAD'} if '@require_safe' in deco else set()
            if meths:
                for meth in sorted(meths):
                    out.append(Route(meth, r.raw, r.file, r.line, 'django'))
                continue
        out.append(r)
    routes[:] = out


def resolve_django(routes, ctx, by_rel):
    drf_expand(routes, by_rel)
    pre = {}
    for rel, p, mod in ctx['djinc']:
        mf = py_module_file(rel, mod, by_rel)
        if mf:
            pre[mf] = (pre.get(rel, '') + '/' + p).replace('//', '/')
    for _ in range(3):
        for rel, p, mod in ctx['djinc']:
            mf = py_module_file(rel, mod, by_rel)
            if mf:
                pre[mf] = join(pre.get(rel, ''), p)
    for r in routes:
        if r.lane in ('django', 'drf') and r.file in pre:
            r.raw = join(pre[r.file], r.raw)


RAILS_ACTIONS = [('GET', ''), ('POST', ''), ('GET', '/{}'), ('PATCH', '/{}'), ('PUT', '/{}'), ('DELETE', '/{}'),
                 ('GET', '/new'), ('GET', '/{}/edit')]
RAILS_NAMES = ['index', 'create', 'show', 'update', 'update', 'destroy', 'new', 'edit']


def lane_rails(f, out, ctx):
    if not f.rel.endswith('config/routes.rb'):
        return
    stack = []
    for no, ln in enumerate(f.code.split('\n'), 1):
        t = ln.strip()
        pre = '/'.join(x for x in stack if x)
        if re.match(r'^end\b', t):
            if stack:
                stack.pop()
            continue
        opens = bool(re.search(r'\bdo(\s*\|[^|]*\|)?\s*$', t))
        m = re.match(r'^(namespace|scope)\s+(?::(\w+)|[\'"]/?([^\'"]*)[\'"]|path:\s*[\'"]/?([^\'"]*)[\'"])', t)
        if m:
            if opens:
                stack.append(m.group(2) or m.group(3) or m.group(4) or '')
            continue
        m = re.match(r'^(resources|resource)\s+:(\w+)(.*)$', t)
        if m:
            only = re.search(r'only:\s*\[([^\]]*)\]|only:\s*:(\w+)', m.group(3))
            exc = re.search(r'except:\s*\[([^\]]*)\]|except:\s*:(\w+)', m.group(3))
            keep = set(re.findall(r'\w+', (only.group(1) or only.group(2)))) if only else set(RAILS_NAMES)
            if exc:
                keep -= set(re.findall(r'\w+', exc.group(1) or exc.group(2)))
            single = m.group(1) == 'resource'
            for (v, suf), nm in zip(RAILS_ACTIONS, RAILS_NAMES):
                if nm in keep and not (single and nm == 'index'):
                    out.append(Route(v, join(pre, m.group(2), suf.replace('/{}', '') if single else suf), f.rel, no, 'rails'))
            if opens:
                stack.append(m.group(2) + ('' if single else '/{}'))
            continue
        m = re.match(r'^(get|post|put|patch|delete|match)\s+[\'"]/?([^\'"]*)[\'"]', t)
        if m:
            out.append(Route('ANY' if m.group(1) == 'match' else m.group(1).upper(), join(pre, m.group(2)), f.rel, no, 'rails'))
        elif re.match(r'^root\b', t):
            out.append(Route('GET', join(pre), f.rel, no, 'rails'))
        if opens and not m:
            stack.append('')


def lane_laravel(f, out, ctx):
    if f.lang != 'php' or '/routes/' not in '/' + f.rel:
        return
    s = f.code
    base = 'api' if f.rel.endswith('routes/api.php') else ''
    if base:
        ctx['strip'].add('api')
    groups = []                 # (end offset, prefix)
    for m in re.finditer(r'Route::(?:prefix\(\s*[\'"]([^\'"]*)[\'"]\s*\)(?:->\w+\([^)]*\))*->group\(|'
                         r'(get|post|put|patch|delete|any|match|apiResource|resource)\(\s*(?:\[[^\]]*\]\s*,\s*)?[\'"]([^\'"]*)[\'"])', s):
        groups = [g for g in groups if g[0] > m.start()]
        pre = '/'.join([base] + [g[1] for g in groups])
        if m.group(1) is not None:
            groups.append((close_of(s, m.end() - 1), m.group(1).strip('/')))
            continue
        kind, p = m.group(2), m.group(3)
        if kind in ('apiResource', 'resource'):
            for (v, suf), nm in zip(RAILS_ACTIONS, RAILS_NAMES):
                if kind == 'apiResource' and nm in ('new', 'edit'):
                    continue
                out.append(Route(v, join(pre, p, suf.replace('/new', '/create')), f.rel, f.line(m.start()), 'laravel'))
        else:
            out.append(Route('ANY' if kind in ('any', 'match') else kind.upper(), join(pre, p), f.rel, f.line(m.start()), 'laravel'))


def lane_go(f, out, ctx):
    if f.lang != 'go':
        return
    s = f.code
    grp = {}
    for m in re.finditer(r'(\w+)\s*:?=\s*(\w+)\.Group\(\s*"([^"]*)"', s):
        grp[m.group(1)] = join(grp.get(m.group(2), ''), m.group(3))
    for m in re.finditer(r'\b(\w+)\.(HandleFunc|Handle)\(\s*"(?:(GET|POST|PUT|PATCH|DELETE)\s+)?(/[^"]*)"', s):
        out.append(Route(m.group(3) or 'ANY', join(grp.get(m.group(1), ''), m.group(4)), f.rel, f.line(m.start()), 'go-net/http'))
    for m in re.finditer(r'\b(\w+)\.(Get|Post|Put|Patch|Delete|GET|POST|PUT|PATCH|DELETE|Any)\(\s*"(/[^"]*)"', s):
        out.append(Route('ANY' if m.group(2) == 'Any' else m.group(2).upper(), join(grp.get(m.group(1), ''), m.group(3)), f.rel, f.line(m.start()), 'go-router'))


def routes_from(path, ledger):
    out = []
    try:
        with open(path, encoding='utf-8', errors='replace') as fh:
            for no, ln in enumerate(fh, 1):
                if ln.startswith('#') or not ln.strip():
                    continue
                cells = ln.rstrip('\n').split('\t')
                for i, c in enumerate(cells):
                    m = re.match(r'^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|ANY|ALL)\s+(/\S*)$', c.strip())
                    if m:
                        out.append(Route(m.group(1), m.group(2), path, no, 'routes-from')); break
                    if c.strip() in VERBS and i + 1 < len(cells) and cells[i + 1].startswith('/'):
                        out.append(Route(c.strip(), cells[i + 1].strip(), path, no, 'routes-from')); break
    except OSError as e:
        ledger.setdefault('unreadable', []).append('%s (%s)' % (path, e.strerror))
    return out


# ---------------------------------------------------------------- page-route lanes
ROUTER_FILE = re.compile(r'createBrowserRouter|createHashRouter|createMemoryRouter|useRoutes\(|RouteObject|<Route\b|'
                         r'createRouter\(|new\s+VueRouter|RouterModule\.for(?:Root|Child)|:\s*Routes\s*=|GoRoute\(|'
                         r'createFileRoute\(|createRoute\(|createRootRoute')


def lane_pages(f, pages, screens):
    s = f.code
    if f.lang not in ('js', 'vue', 'dart'):
        return
    named = re.search(r'(?:^|/)(?:app-)?(?:routes?|router|routing)(?:[.-][\w-]+)?\.(?:t|j)sx?$', f.rel)
    for m in re.finditer(r'<\w+\.Screen\b[^>]*\bname\s*=\s*[\'"](\w+)[\'"]|\bcreate\w*Navigator\b', s):
        if m.group(1):
            screens[m.group(1)] = f.where(m.start())
    if not (ROUTER_FILE.search(s) or named):
        return
    for m in re.finditer(r'createFileRoute\(\s*[\'"`]([^\'"`]+)', s):
        pages.append((m.group(1), f.rel, f.line(m.start()), 'tanstack'))
    stack, i, n = [], 0, len(s)        # frames: [closer, path]
    pathkey = re.compile(r'\bpath\s*[:=]\s*\{?\s*([\'"`])([^\'"`]*)\1')
    while i < n:
        c = s[i]
        if c in '"\'`':
            i = skip_str(s, i); continue
        if c in '({[':
            stack.append([{'(': ')', '{': '}', '[': ']'}[c], None]); i += 1; continue
        if c in ')}]':
            if stack:
                stack.pop()
            i += 1; continue
        if c == '<' and s.startswith('<Route', i) and re.match(r'<Route\b', s[i:i + 7]):
            e = s.find('>', i)
            tag = s[i:e + 1] if e > 0 else ''
            pm = pathkey.search(tag) or re.search(r'\bpath\s*=\s*\{?\s*([\'"`])([^\'"`]*)\1', tag)
            idx = re.search(r'\bindex\b', tag)
            base = '/'.join(fr[1] for fr in stack if fr[1])
            if pm or idx:
                full = pm.group(2) if pm and pm.group(2).startswith('/') else join(base, pm.group(2) if pm else '')
                pages.append((full, f.rel, f.line(i), 'jsx-route'))
            if not tag.endswith('/>') and e > 0:
                stack.append(['</Route>', (pm.group(2) if pm else '')])
            i = e + 1 if e > 0 else i + 1; continue
        if c == '<' and s.startswith('</Route>', i):
            for k in range(len(stack) - 1, -1, -1):
                if stack[k][0] == '</Route>':
                    del stack[k:]; break
            i += 8; continue
        if c == 'p' and s.startswith('path', i) and (i == 0 or not (s[i - 1].isalnum() or s[i - 1] in '_$.')):
            m = pathkey.match(s, i)
            if m and stack:
                fr = stack[-1]
                ancestors = '/'.join(x[1] for x in stack[:-1] if x[1])
                val = m.group(2)
                full = val if val.startswith('/') else join(ancestors, val)
                fr[1] = full if val.startswith('/') else val
                if val.startswith('/'):
                    fr[1] = val
                pages.append((full, f.rel, f.line(i), 'route-object'))
                i = m.end(); continue
        if c == 'i' and s.startswith('index', i) and re.match(r'index\s*:\s*true', s[i:i + 16]):
            pages.append((join('/'.join(x[1] for x in stack[:-1] if x[1])), f.rel, f.line(i), 'route-object'))
        i += 1


# ---------------------------------------------------------------- references
class Ref(object):
    __slots__ = ('kind', 'method', 'raw', 'cpath', 'where', 'status', 'match', 'gate', 'rel')

    def __init__(self, kind, method, raw, where):
        self.kind, self.method, self.raw, self.where = kind, method, raw, where
        self.cpath, self.status, self.match, self.gate, self.rel = '', '', '', False, where.rsplit(':', 1)[0]


def path_literal(s, i):
    """Read the string literal starting at s[i]; return (text, end) with `${...}` kept, or (None, i)."""
    if i >= len(s) or s[i] not in '"\'`':
        return None, i
    e = skip_str(s, i)
    return s[i + 1:e - 1], e


def clean_path(t, relative_ok):
    """Normalise a referenced URL; return (path, status) with status '' | external | unresolved."""
    if t is None:
        return None, 'unresolved'
    t = t.strip()
    t = re.sub(r'^(?:https?:)?//(?:localhost|127\.0\.0\.1)(?::\d+)?', '', t)
    if re.match(r'^\$\{\s*(?:window\.)?(?:location\.(?:origin|href)|document\.baseURI)\s*\}', t):
        return None, 'self-origin'         # the page's own host (a chunk probe, a share link), not the API
    if re.match(r'^(?:https?:|//|mailto:|tel:|sms:|javascript:|data:|blob:)', t):
        return None, 'external'
    while t.startswith('${'):
        e = t.find('}')
        if e < 0:
            return None, 'unresolved'
        t = t[e + 1:]
    if not t or t.startswith('#') or t.startswith('?'):
        return None, 'unresolved' if not t else 'anchor'
    if not t.startswith('/'):
        if not relative_ok or not re.match(r'^[A-Za-z0-9_-]', t):
            return None, 'unresolved'
        t = '/' + t
    if re.search(r'(?:^|/)[\w.-]+\$\{[^}]*\}(?:$|[/?])', t):
        return None, 'unresolved'          # `/api${path}`: the variable carries the rest of the path
    if re.search(r'\.(?:css|js|mjs|png|jpe?g|gif|svg|ico|webp|avif|woff2?|ttf|pdf|xml|txt|json|map|mp4|webm|zip|csv|xlsx)(?:$|\?)', t):
        return None, 'asset'
    return t, ''


def lane_refs(f, refs, clients):
    s = f.code
    if f.lang not in ('js', 'vue', 'dart', 'html', 'kt', 'py'):
        return
    cl = sorted(set(clients), key=len, reverse=True)
    if f.lang in ('js', 'vue', 'dart'):
        recv = '|'.join(re.escape(c) for c in cl)
        pat = re.compile(r'(?<![\w$.])(?:' + recv + r')\s*\.\s*(get|post|put|patch|delete|del|head|postForm|putForm|patchForm|request)\s*(?:<[^()]*?>)?\s*\(\s*', re.S)
        for m in pat.finditer(s):
            t, e = path_literal(s, m.end())
            v = m.group(1).upper().replace('FORM', '')
            v = 'DELETE' if v == 'DEL' else v
            if v == 'REQUEST':
                body = s[m.end():close_of(s, m.end() - 1)]
                mm = re.search(r'\bmethod\s*:\s*[\'"](\w+)', body); um = re.search(r'\burl\s*:\s*([\'"`])', body)
                v = mm.group(1).upper() if mm else 'GET'
                t = path_literal(body, um.start(1))[0] if um else None
            refs.append(_ref('call', v, t, f, m.start(), True))
        bare = re.compile(r'(?<![\w$.])(fetch|ofetch|\$fetch|useFetch|useLazyFetch|useSWR|useSWRImmutable|ky|axios|request)\s*(?:<[^()]*?>)?\s*\(\s*(?=[\'"`])')
        for m in bare.finditer(s):
            t, e = path_literal(s, m.end())
            if t is None or (m.group(1) == 'request' and not t.startswith('/')):
                continue
            body = s[e:close_of(s, m.end() - 1)]
            mm = re.search(r'\bmethod\s*:\s*[\'"](\w+)', body[:600])
            refs.append(_ref('call', mm.group(1).upper() if mm else 'GET', t, f, m.start(), False))
    if f.lang == 'kt' and 'retrofit2' in s:
        for m in re.finditer(r'@(GET|POST|PUT|PATCH|DELETE)\(\s*"([^"]*)"', s):
            refs.append(_ref('call', m.group(1), m.group(2), f, m.start(), True))
    # links, redirects, navigations
    for m in re.finditer(r'(?<![\w-])(?::?(?:href|to)|routerLink)\s*=\s*\{?\s*(?:\'|"|`|"\'|"`)?', s):
        q = s.rfind('=', m.start(), m.end())
        j = q + 1
        while j < len(s) and s[j] in ' \t{':
            j += 1
        if j < len(s) and s[j] == '"' and f.lang in ('vue',) and m.group(0).startswith(':') and j + 1 < len(s) and s[j + 1] in '\'`':
            j += 1
        t, e = path_literal(s, j)
        if t is None or not t.startswith(('/', '${', 'http', '#', 'mailto', 'tel')):
            continue
        tag = s[s.rfind('<', 0, m.start()):m.start()]
        kind = 'redirect' if re.search(r'<(?:Navigate|Redirect)\b', tag) else 'link'
        refs.append(_ref(kind, 'GET', t, f, m.start(), False))
    for m in re.finditer(r'(?<![\w$])(?:navigate|router\.(?:push|replace)|redirect|permanentRedirect|navigateTo|'
                         r'context\.(?:go|push|replace)|GoRouter\.of\(\s*context\s*\)\.(?:go|push)|location\.assign|location\.replace|'
                         r'RedirectResponse|redirect_to|HttpResponseRedirect)\s*\(\s*(?:url\s*=\s*)?', s):
        t, e = path_literal(s, m.end())
        if t is None:
            continue
        if not t.startswith(('/', '${')):
            if m.group(0).startswith('navigate') and re.match(r'^[A-Z]\w*$', t):
                refs.append(_ref('screen', 'GET', t, f, m.start(), False))
            continue
        refs.append(_ref('redirect', 'GET', t, f, m.start(), False))
    for m in re.finditer(r'(?:window\.)?location(?:\.href)?\s*=\s*(?=[\'"`])', s):
        refs.append(_ref('redirect', 'GET', path_literal(s, m.end())[0], f, m.start(), False))
    for m in re.finditer(r'<form\b[^>]*>', s, re.I):
        tag = m.group(0)
        am = re.search(r'\baction\s*=\s*\{?\s*([\'"`])([^\'"`]*)\1', tag)
        mm = re.search(r'\bmethod\s*=\s*[\'"](\w+)', tag, re.I)
        if am and am.group(2).startswith(('/', '{{')) is False and not am.group(2).startswith('${'):
            continue
        if am:
            v = mm.group(1).upper() if mm else 'GET'
            refs.append(_ref('form' if v != 'GET' else 'link', v, am.group(2), f, m.start(), False))


def _ref(kind, method, t, f, pos, relative_ok):
    r = Ref(kind, method, t if t is not None else '', f.where(pos))
    if kind == 'screen':
        r.cpath = t
        return r
    p, st = clean_path(t, relative_ok)
    if '{{' in (t or '') or '{%' in (t or ''):
        p, st = None, 'unresolved'
    r.status = st
    r.cpath = p or ''
    r.gate = bool(t and GATE_WORDS.search(t))
    return r


# ---------------------------------------------------------------- placeholders and dead affordances
def placeholders(files, catalogs, envs, routes, rows):
    by_file = {}
    for r in routes:
        by_file.setdefault(r.file, []).append(r)
    for v in by_file.values():
        v.sort(key=lambda r: r.line)
    for f in files:
        s, ui = f.code, f.lang in ('js', 'vue', 'html', 'dart')
        if ui:
            for m in re.finditer(r'>([^<>{}\n]*)<', s):
                if PLACEHOLDER_TEXT.search(m.group(1)) and m.group(1).strip():
                    rows.append(('FS4', 'copy', f.where(m.start()), m.group(1).strip()[:80], '-'))
            for m in re.finditer(r'(?<![\w$])(?!placeholder\s*=)([\'"`])((?:\\.|(?!\1)[^\n])*)\1', s):
                if PLACEHOLDER_STR.search(m.group(2)) and not re.search(r'placeholder\s*=\s*\{?\s*$', s[max(0, m.start() - 30):m.start()]):
                    rows.append(('FS4', 'copy', f.where(m.start()), m.group(2)[:80], '-'))
        for m in re.finditer(r'\braise\s+NotImplementedError\b|HTTPException\(\s*(?:status_code\s*=\s*)?501\b|\bstatus(?:_code)?\s*[=:(]\s*501\b|'
                             r'\.status\(\s*501\s*\)|HttpStatus\.NOT_IMPLEMENTED\b|\bNotImplementedException\s*\(|\bUnimplementedError\b|'
                             r'\babort\(\s*501\b|head\s+:not_implemented|\bTODO\(\s*\)|\bthrow\s+new\s+Error\(\s*[\'"`](?i:not\s+implemented|todo)', s):
            ln = f.line(m.start())
            h = [r for r in by_file.get(f.rel, []) if r.line <= ln]
            rows.append(('FS4', 'not-implemented', f.where(m.start()), m.group(0)[:60], ('%s %s' % (h[-1].method, h[-1].raw)) if h else '-'))
        mock_rows(f, rows)
        for m in re.finditer(r'(?:\bimport\b[^;\n]*?|\bfrom\s+|\brequire\(\s*)[\'"]([^\'"]*(?:/__mocks__/|(?:^|/)mocks?(?:/|$)|(?:^|/)fixtures?(?:/|$)|@faker-js/faker|^faker$|^@?msw(?:/|$)|mock-?data|/fake[\w-]*)[^\'"]*)[\'"]', s):
            gated = bool(re.search(r'import\.meta\.env\.(?:DEV|MODE)|process\.env\.NODE_ENV|__DEV__|kDebugMode|VITE_\w*(?:MOCK|DEMO)|NEXT_PUBLIC_\w*(?:MOCK|DEMO)', s))
            rows.append(('FS4', 'mock-import', f.where(m.start()), m.group(1), 'gated=%s' % ('yes' if gated else 'no')))
        for m in re.finditer(r'\b(?:setupWorker|worker\.start)\s*\(', s):
            win = s[max(0, m.start() - 400):m.start()]
            gated = bool(re.search(r'import\.meta\.env\.(?:DEV|MODE)|process\.env\.NODE_ENV|__DEV__|VITE_\w*(?:MOCK|DEMO)|NEXT_PUBLIC_\w*(?:MOCK|DEMO)', win))
            rows.append(('FS4', 'mock-import', f.where(m.start()), 'msw ' + m.group(0).rstrip('( '), 'gated=%s' % ('yes' if gated else 'no')))
        for m in re.finditer(r'\b(?:USE_MOCKS?|MOCK_(?:API|DATA|MODE)|ENABLE_MOCKS?|useMocks?)\s*[:=]\s*(?:true|True|1|[\'"](?:true|1)[\'"])', s):
            rows.append(('FS4', 'use-mocks', f.where(m.start()), m.group(0)[:60], '-'))
    for p, rel in envs:
        try:
            with open(p, encoding='utf-8', errors='replace') as fh:
                for no, ln in enumerate(fh, 1):
                    if re.match(r'^\s*\w*(?:USE_MOCKS?|MOCK_(?:API|DATA|MODE)|ENABLE_MOCKS?)\s*=\s*["\']?(?:true|1)\b', ln):
                        rows.append(('FS4', 'use-mocks', '%s:%d' % (rel, no), ln.strip()[:60], '-'))
        except OSError:
            pass
    for p, rel in catalogs:
        try:
            with open(p, encoding='utf-8', errors='replace') as fh:
                for no, ln in enumerate(fh, 1):
                    m = re.match(r'^\s*"?([\w.@-]+)"?\s*:\s*"?(.*?)"?,?\s*$', ln)
                    val = m.group(2) if m else ln
                    if (m or rel.endswith('.po')) and (PLACEHOLDER_STR.search(val) or re.search(r'(?<![\w-])(?:TODO|TBD|FIXME)(?![\w-])|lorem', val)):
                        rows.append(('FS4', 'catalog', '%s:%d' % (rel, no), ((m.group(1) + ' = ') if m else '') + val.strip()[:60], '-'))
        except OSError:
            pass


DATA_CALL = re.compile(r'\bawait\b|\bfetch\(|\baxios\b|\bhttp\.|\bapi\.|\bquery\w*\(|\bexecute\w*\(|\.find\w*\(|\.select\(|prisma\.|\bem\.|'
                       r'[Rr]epo(?:sitory)?\w*\.|\bsession\.|\.objects\.|\bdb\.|useQuery|useSWR|supabase|\.get\(|\.all\(|\bcursor\.|\.filter\(|requests\.|httpx\.|\bdio\b')


LITERAL = re.compile(r'^(?:\'[^\'\n]*\'|"[^"\n]*"|-?\d[\d_.]*|true|false|null|None|True|False|nil|undefined)$')
CONFIG_KEYS = {'key', 'value', 'label', 'id', 'title', 'name', 'icon', 'disabled', 'description', 'type', 'path', 'href', 'to',
               'accessorKey', 'header', 'field', 'width', 'align', 'sortable', 'order', 'span', 'variant', 'color', 'slug',
               'code', 'group', 'kind', 'tab', 'section', 'min', 'max', 'step', 'default', 'placeholder', 'hidden', 'required'}
LAYOUT_KEYS = {'width', 'order', 'span', 'min', 'max', 'step', 'sort', 'weight', 'priority', 'columns', 'rows', 'size', 'flex',
               'minWidth', 'maxWidth', 'colSpan', 'index', 'level', 'depth', 'zIndex', 'delay', 'duration'}
RECORD_KEY = re.compile(r'(?i)email|phone|price|amount|total|balance|date|created|updated|address|company|customer|cents|qty|quantity|stock|revenue|count')


def records(s, a, e):
    """How many elements of the array s[a:e] are data RECORDS: every value a literal, and something a record
    carries (a number outside layout keys, or a contact / money / date key). Column, option and tab configs
    (`{ key, header: t(...) }`, `{ value: 'x', label: 'X' }`) are not records."""
    n, i = 0, a + 1
    while i < e:
        c = s[i]
        if c in '"\'`':
            i = skip_str(s, i); continue
        if c == '{':
            j = close_of(s, i)
            body, pairs, ok = s[i + 1:j - 1], [], True
            depth, start, k = 0, 0, 0
            parts = []
            while k < len(body):
                ch = body[k]
                if ch in '"\'`':
                    k = skip_str(body, k); continue
                if ch in '([{':
                    depth += 1
                elif ch in ')]}':
                    depth -= 1
                elif ch == ',' and depth == 0:
                    parts.append(body[start:k]); start = k + 1
                k += 1
            parts.append(body[start:])
            for part in parts:
                if not part.strip():
                    continue
                kv = re.match(r'\s*[\'"]?([\w$-]+)[\'"]?\s*:\s*(.*?)\s*$', part, re.S)
                if not kv or not LITERAL.match(kv.group(2)):
                    ok = False; break
                pairs.append((kv.group(1), kv.group(2)))
            keys = set(k2 for k2, _ in pairs)
            num = any(re.match(r'^-?\d', v) and k2 not in LAYOUT_KEYS for k2, v in pairs)
            if ok and len(pairs) >= 2 and not keys <= CONFIG_KEYS - {'id'} and (num or any(RECORD_KEY.search(k2) for k2 in keys)):
                n += 1
            i = j; continue
        i += 1
    return n


def mock_rows(f, rows):
    s = f.code
    if f.lang not in ('js', 'vue', 'py', 'rb', 'dart'):
        return
    for m in re.finditer(r'\breturn\s*\[\s*\{|\buseState\s*(?:<[^>]*>)?\(\s*\[\s*\{|(?:const|let|var)\s+(\w*(?i:mock|fake|dummy|sample|stub|demo)\w*)\s*(?::[^=\n]+)?=\s*\[\s*\{', s):
        a = s.index('[', m.start())
        e = close_of(s, a)
        objs = records(s, a, e)
        if objs < 2:
            continue
        ln = f.line(m.start())
        lines = s[:m.start()].split('\n')
        head, k = 0, len(lines) - 1
        ind = len(lines[-1]) - len(lines[-1].lstrip())
        while k >= 0:
            t = lines[k]
            if re.match(r'\s*(?:async\s+)?def\s+\w+|\s*(?:export\s+)?(?:async\s+)?function\b|.*=>\s*\{?\s*$|.*\)\s*(?::[^{]+)?\{\s*$', t) and \
                    (f.lang != 'py' or len(t) - len(t.lstrip()) < ind):
                head = k; break
            k -= 1
        span = '\n'.join(lines[head:]) + s[m.start():a]
        if DATA_CALL.search(span):
            continue
        name = m.group(1) or ('useState' if 'useState' in m.group(0) else 'return')
        todo = 'todo-comment' if re.search(r'(?i)TODO|FIXME|mock|fake|stub', '\n'.join(f.raw.split('\n')[max(0, head):ln])) else '-'
        rows.append(('FS4', 'mock-rows', f.where(m.start()), '%s: %d literal objects' % (name, objs), todo))


def dead(files, rows):
    real = re.compile(r'\bon(?:Click|Press|Submit|Select)\s*=\s*\{(?!\s*\(\s*\)\s*=>\s*(?:\{\s*\}|null|undefined|void 0)\s*\})|@click\s*=\s*"[^"]+"|onPressed:\s*(?!null\b)\S')
    for f in files:
        if f.lang not in ('js', 'vue', 'html', 'dart'):
            continue
        s = f.code
        hits = []
        for m in re.finditer(r'\bon(Click|Press|Submit|Select|Change)\s*=\s*\{\s*(?:\(\s*\w*\s*\)|\w+)\s*=>\s*(?:\{\s*\}|null|undefined|void 0)\s*\}|\bon(?:Click|Press|Submit)\s*=\s*\{\s*noop\s*\}', s):
            hits.append(('noop-handler', m))
        for m in re.finditer(r'<(?:a|Link)\b[^>]*\bhref\s*=\s*[\'"]#[\'"][^>]*>', s):
            if not re.search(r'\bon(?:Click|Press)\b|@click|v-on:click|data-toggle|data-bs-toggle|role\s*=\s*[\'"]tab', m.group(0)):
                hits.append(('hash-href', m))
        for m in re.finditer(r'@click\s*=\s*"\s*(?:\(\s*\)\s*=>\s*\{\s*\})?\s*"', s):
            hits.append(('noop-handler', m))
        for m in re.finditer(r'<(?:button|Button|input|a|IconButton|MenuItem|DropdownMenuItem)\b[^<>]*?\s(?::?disabled(?:\s*=\s*(?:\{\s*true\s*\}|"true"|\'true\'|"disabled"))?)(?=[\s/>])[^<>]*>', s):
            tag = m.group(0)
            if re.search(r'\bdisabled\s*=\s*\{(?!\s*true\s*\})|:disabled\s*=\s*"(?!true")', tag):
                continue
            hits.append(('literal-disabled', m))
        if f.lang in ('js',):
            for m in re.finditer(r'<form\b[^>]*>', s):
                if not re.search(r'\b(?:action|onSubmit|method|hx-post|hx-get)\b', m.group(0)) and '{...' not in m.group(0):
                    hits.append(('form-no-action', m))
        if f.lang == 'dart':
            for m in re.finditer(r'\bon(?:Pressed|Tap)\s*:\s*(?:null\b|\(\)\s*\{\s*\})', s):
                hits.append(('flutter-null-handler', m))
        for kind, m in hits:
            ln = f.line(m.start())
            near = '-'
            for r in real.finditer(s, max(0, m.start() - 2500), min(len(s), m.end() + 2500)):
                rl = f.line(r.start())
                if rl != ln and abs(rl - ln) <= 40:
                    near = 'handler:%d' % rl; break
            rows.append(('FS5', kind, f.where(m.start()), re.sub(r'\s+', ' ', m.group(0))[:70], near))


# ---------------------------------------------------------------- main
def run(roots, opts, emit=True):
    t0, ledger = time.time(), {}
    files, controls, catalogs, envs = walk(roots, opts['tests'], ledger)
    by_rel = {f.rel: f for f in files}
    fw_cache = {}

    def fw(f):
        d = os.path.dirname(f.path)
        while True:
            if d in fw_cache:
                return fw_cache[d]
            pj = os.path.join(d, 'package.json')
            if os.path.isfile(pj):
                try:
                    txt = open(pj, encoding='utf-8', errors='replace').read()
                except OSError:
                    txt = ''
                v = set(k for k, pat in (('next', r'"next"\s*:'), ('nuxt', r'"nuxt"\s*:'), ('svelte', r'"@sveltejs/kit"\s*:'),
                                         ('expo', r'"expo-router"\s*:'),
                                         ('remix', r'"@remix-run/[\w-]+"\s*:|"@react-router/dev"\s*:')) if re.search(pat, txt))
                fw_cache[d] = (v, d)
                return fw_cache[d]
            if any(os.path.abspath(d) == os.path.abspath(r) for r in roots) or os.path.dirname(d) == d:
                fw_cache[d] = (set(), d); return fw_cache[d]
            d = os.path.dirname(d)
    ctx = {'strip': set(), 'notes': set(), 'mounts': [], 'pyvars': {}, 'pyinc': [], 'pyimp': {}, 'djinc': [], 'fw': fw}
    routes, pages, screens, refs, rows = [], [], {}, [], []
    imports = {}
    for f in files:
        if f.lang == 'js':
            imports.update(js_imports(f, by_rel))
    for f in files:
        lane_nest(f, routes, ctx); lane_express(f, routes, ctx, imports); lane_next(f, routes, pages, ctx)
        lane_python(f, routes, ctx); lane_rails(f, routes, ctx); lane_laravel(f, routes, ctx); lane_go(f, routes, ctx)
        lane_pages(f, pages, screens)
        if not f.test and not NOT_SHIPPED.search(f.rel):
            lane_refs(f, refs, DEFAULT_CLIENTS + opts['clients'])
        if '@trpc/' in f.code[:3000]:
            ctx['notes'].add('tRPC present - procedure paths are not joined (read the router keys by hand)')
    resolve_python(routes, ctx, by_rel)
    resolve_django(routes, ctx, by_rel)
    # express mounts: a file mounted at a prefix carries it (one hop, then parents, up to three levels)
    fpre = {}
    for _ in range(3):
        for rel, var, pre, tgt in ctx['mounts']:
            outer = fpre.get(rel, [''])
            if tgt:
                fpre[tgt] = sorted(set(join(o, pre) for o in outer))
            else:
                fpre.setdefault((rel, var), []).append(pre)
    for r in routes:
        if r.lane == 'express' and r.file in fpre:
            r.raw = join(fpre[r.file][0], r.raw)
    if opts['routes_from']:
        routes += routes_from(opts['routes_from'], ledger)
    strip = ctx['strip']
    # A call made by server code goes to another service (a PSP, a carrier, a mailer), not to this
    # app's own routes: it is `outbound`, never FS1. Server code = a file in a package (nearest
    # manifest) that declares backend routes, unless it is browser code (templates, static/, web/).
    manifests = ('package.json', 'pyproject.toml', 'requirements.txt', 'go.mod', 'composer.json', 'Gemfile', 'pubspec.yaml', 'manage.py')
    pk_cache = {}

    def pkg(path):
        d = os.path.dirname(path)
        seen = []
        while True:
            if d in pk_cache:
                v = pk_cache[d]; break
            if any(os.path.isfile(os.path.join(d, m)) for m in manifests) or any(os.path.abspath(d) == os.path.abspath(r) for r in roots) \
                    or os.path.dirname(d) == d:
                v = d; break
            seen.append(d); d = os.path.dirname(d)
        for x in seen:
            pk_cache[x] = v
        pk_cache[d] = v
        return v
    backend = set(pkg(by_rel[r.file].path) for r in routes if r.file in by_rel and r.lane not in ('next-app', 'next-pages-api', 'sveltekit', 'remix', 'remix-action'))
    browser = re.compile(r'(?:^|/)(?:static|public|assets|resources/js|client|frontend|web|www|pages|components|ui)(?:/|$)')
    for ref in refs:
        f = by_rel.get(ref.rel)
        if ref.kind == 'call' and not ref.status and f and f.lang not in ('html', 'vue') and not browser.search(ref.rel) and pkg(f.path) in backend:
            ref.status = 'outbound'
    sidx, pidx = Index(), {}
    for r in routes:
        r.cpath = canon(r.raw, strip)
        sidx.add(r.cpath, r)
    served_pk = set(pkg(by_rel[r.file].path) for r in routes if r.file in by_rel)
    root_splat = 0
    for p, rel, ln, lane in pages:
        c = canon(p, strip)
        if c == '/{*}':
            root_splat += 1; continue
        ix = pidx.setdefault(pkg(by_rel[rel].path) if rel in by_rel else '', Index())
        ix.add(c, (p, rel, ln, lane))
        # `app/[locale]/cart` is reached as `/cart` through the i18n middleware
        if re.match(r'^/?(?:\[\[?|:)(?:locale|lang|lng|language)\]?\]?(?:/|$)', p):
            ix.add('/' + '/'.join(c.split('/')[2:]), (p, rel, ln, lane))
    reasons = []
    if opts['reasons']:
        try:
            for ln in open(opts['reasons'], encoding='utf-8', errors='replace'):
                m = re.match(r'^\s*(?:(GET|POST|PUT|PATCH|DELETE|ANY)\s+)?(/\S*)\s*(.*)$', ln)
                if m and not ln.lstrip().startswith('#'):
                    reasons.append((m.group(1), canon(m.group(2).replace('*', '{*}'), strip), m.group(3).strip() or 'listed'))
        except OSError as e:
            ledger.setdefault('unreadable', []).append('%s (%s)' % (opts['reasons'], e.strerror))
    stat = {}
    for ref in refs:
        if ref.kind == 'screen':
            ref.status = 'screen' if ref.cpath in screens else ('deadlink' if screens else 'unresolved')
        elif ref.status:
            pass
        else:
            ref.cpath = canon(ref.cpath, strip)
            if ref.kind in ('call', 'form'):
                hits = sidx.find(ref.cpath)
                ok = [r for r in hits if r.method in (ref.method, 'ANY') or (ref.method == 'HEAD' and r.method == 'GET')]
                for r in ok:
                    r.called = True
                if ok:
                    ref.status = 'served'
                else:
                    ref.status = 'unserved'
                    ref.match = ('method-mismatch:' + ','.join(sorted(set(r.method for r in hits)))) if hits else '-'
            else:
                f = by_rel.get(ref.rel)
                pk = pkg(f.path) if f else ''
                ph = pidx[pk].find(ref.cpath) if pk in pidx else []
                sv = [r for r in sidx.find(ref.cpath) if r.method in ('GET', 'ANY')]
                for r in sv:
                    r.called = True
                if ph:
                    ref.status = 'page'
                elif sv:
                    ref.status = 'served'
                elif pk in pidx or pk in served_pk:
                    ref.status = 'deadlink'
                else:
                    ref.status = 'no-page-table'      # a link in a package with no route table is not decidable
        stat[ref.status] = stat.get(ref.status, 0) + 1
    want = opts['classes']
    out = []
    links_blocked = not pages and not routes
    calls_blocked = not routes
    if calls_blocked:
        ledger['calls'] = 'blocked (no served-route table under these roots - add the API root or --routes-from)'
    if '1' in want and not calls_blocked:
        for ref in refs:
            if ref.kind in ('call', 'form') and ref.status == 'unserved':
                tags = ','.join(x for x in ('gate-fetch' if ref.gate else '', 'form' if ref.kind == 'form' else '') if x) or '-'
                bm = re.match(r'\$\{\s*([\w.$]+)', ref.raw)
                if bm:
                    tags = (tags + ',' if tags != '-' else '') + 'base=' + bm.group(1)
                out.append(('FS1', ref.method, ref.cpath, ref.raw[:80], ref.where, ref.match, tags))
    joined = [r for r in refs if r.kind in ('call', 'form') and r.status in ('served', 'unserved')]
    unserved = sum(1 for r in joined if r.status == 'unserved')
    uncalled = sum(1 for r in routes if not r.called)
    if len(joined) >= 10 and routes and unserved * 2 > len(joined) and uncalled * 2 > len(routes):
        ledger['join'] = 'SUSPECT (%d/%d calls unserved, %d/%d routes uncalled): a prefix, version or base URL is missing - fix the join before reading FS1/FS2 (precedents/product.md § 9)' % (unserved, len(joined), uncalled, len(routes))
    no_client = not any(r.kind in ('call', 'form') and r.status in ('served', 'unserved') for r in refs)
    if no_client and routes:
        ledger['uncalled'] = 'N/A (no client reference under these roots - FS2 needs the client root too)'
    if '2' in want and not no_client:
        for r in routes:
            if r.called or r.lane == 'routes-from' and False:
                continue
            tags = [t for t, pat in EXT_TAGS if re.search(pat, r.raw, re.I)]
            if r.public:
                tags.append('public')
            if r.method not in ('GET', 'HEAD', 'OPTIONS'):
                tags.append('writes')
            for rm, rc, why in reasons:
                if (rm is None or rm == r.method) and seg_match(rc, r.cpath):
                    tags.append('explained(%s)' % why[:40]); break
            out.append(('FS2', r.method, r.cpath, '%s:%d' % (r.file, r.line), r.lane, ','.join(tags) or '-'))
    if '3' in want and not links_blocked:
        for ref in refs:
            if ref.kind in ('link', 'redirect', 'screen') and ref.status == 'deadlink':
                out.append(('FS3', ref.kind, ref.cpath, ref.raw[:80], ref.where, '-'))
    shipped = [f for f in files if not NOT_SHIPPED.search(f.rel)]
    if '4' in want:
        placeholders(shipped, catalogs, envs, routes, rows)
    if '5' in want:
        dead(shipped, rows)
    out += [r for r in rows if r[0][2] in want]
    ctrl_rows = [('CONTROL', c) for c in controls]
    ledger.update({
        'roots': ', '.join(roots), 'files read': len(files), 'catalog files': len(catalogs), 'env files': len(envs),
        'served routes': '%d (%s)' % (len(routes), ', '.join('%s %d' % (k, v) for k, v in sorted(_count(r.lane for r in routes).items()))),
        'page routes': '%d (%s)%s' % (len(pages) - root_splat, ', '.join('%s %d' % (k, v) for k, v in sorted(_count(p[3] for p in pages).items())),
                                      '; root catch-all ignored: %d' % root_splat if root_splat else ''),
        'screens': len(screens),
        'references': '%d (%s)' % (len(refs), ', '.join('%s %d' % (k, v) for k, v in sorted(_count(r.kind for r in refs).items()))),
        'reference status': ', '.join('%s %d' % (k or 'served', v) for k, v in sorted(stat.items())),
        'prefixes stripped': ', '.join(sorted(strip)) + (' + v<N>' if strip else 'v<N> only'),
        'links': 'blocked (no page-route table and no served routes)' if links_blocked else
                 'per package: its page routes, then any served GET route (no-page-table = not decidable)',
        'controls': len(controls), 'runtime': '%.1fs' % (time.time() - t0)})
    for n in sorted(ctx['notes']):
        ledger.setdefault('notes', []).append(n)
    inv = []
    if opts['inventory']:
        inv += [('ROUTE', r.method, r.raw, r.cpath, '%s:%d' % (r.file, r.line), r.lane) for r in routes]
        inv += [('PAGE', p, canon(p, strip), '%s:%d' % (rel, ln), lane) for p, rel, ln, lane in pages]
        inv += [('REF', r.kind, r.method, r.raw[:80], r.cpath, r.where, r.status or 'served') for r in refs]
    if emit:
        emit_rows(ctrl_rows + out, inv, ledger, opts)
    return out, ctrl_rows, inv, ledger


def _count(it):
    d = {}
    for x in it:
        d[x] = d.get(x, 0) + 1
    return d


HEAD = {'FS1': 'method\tpath\traw\tsite\tnear\ttags', 'FS2': 'method\tpath\tsite\tlane\ttags',
        'FS3': 'kind\tpath\traw\tsite\tnear', 'FS4': 'kind\tsite\tdetail\thandler', 'FS5': 'kind\tsite\tsnippet\tnear',
        'CONTROL': 'file', 'ROUTE': 'method\traw\tpath\tsite\tlane', 'PAGE': 'raw\tpath\tsite\tlane',
        'REF': 'kind\tmethod\traw\tpath\tsite\tstatus'}


def emit_rows(rows, inv, ledger, opts):
    if opts['json']:
        print(json.dumps({'rows': [list(r) for r in rows], 'inventory': [list(r) for r in inv], 'ledger': ledger}, indent=1))
    else:
        cur, shown = None, {}
        for r in inv + rows:
            if r[0] != cur:
                cur = r[0]; print('# %s\t%s' % (cur, HEAD.get(cur, '')))
            shown[cur] = shown.get(cur, 0) + 1
            if opts['max'] and shown[cur] > opts['max'] and cur not in ('ROUTE', 'PAGE', 'REF'):
                continue
            print('\t'.join(str(x) for x in r))
    counts = _count(r[0] for r in rows)
    sys.stderr.write('surface-map ledger\n')
    for k, v in ledger.items():
        if isinstance(v, list):
            for x in v:
                sys.stderr.write('  %-18s %s\n' % (k, x))
        else:
            sys.stderr.write('  %-18s %s\n' % (k, v))
    sys.stderr.write('  %-18s %s\n' % ('rows', ', '.join('%s %d' % (k, v) for k, v in sorted(counts.items())) or 'none'))
    if opts['max']:
        cut = ['%s %d' % (k, v - opts['max']) for k, v in sorted(counts.items()) if v > opts['max']]
        if cut:
            sys.stderr.write('  %-18s %s (--max=%d; rerun without it for all)\n' % ('not printed', ', '.join(cut), opts['max']))


# ---------------------------------------------------------------- self-test
FIX = {
    'api/package.json': '{"dependencies": {"@nestjs/core": "11"}}',
    'api/src/main.ts': "app.setGlobalPrefix('api');\napp.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });\n",
    'api/src/stores.controller.ts': "@Controller('stores')\nexport class S {\n  @Get()\n  list() {}\n  @Get(':id')\n  one() {}\n"
                                    "  @Post(':id/sync')\n  sync() {}\n  @Post('webhooks/shopify')\n  hook() {}\n  @Delete(':id')\n  drop() {}\n}\n",
    'api/src/auth.controller.ts': "@Controller()\nexport class A {\n  @Post('auth/login')\n  login() {}\n"
                                  "  @Get('settings/countries')\n  c() { throw new NotImplementedException(); }\n}\n",
    'web/package.json': '{"dependencies": {"react-router": "7"}}',
    'web/src/app/routes.ts': "export const ROUTES = [\n  { path: '/orders', Component: page('o') },\n  { path: '/orders/:id', Component: page('d') },\n"
                             "  { path: '/settings', children: [ { path: 'billing', Component: x }, { index: true, Component: y } ] },\n  { path: '*', Component: NotFound },\n];\n",
    'web/src/shared/api/use-stores.ts': "export const useStores = () => http.get('stores');\nexport const one = (id) => http.get(`stores/${id}`);\n"
                                        "export const perms = () => http.get('auth/me/permissions');\nexport const sync = (id) => http.get(`stores/${id}/sync`);\n"
                                        "export const login = (b) => http.post<{ a: string; b: string }>('auth/login', b);\n"
                                        "export const ext = () => fetch('https://example.com/x');\n",
    'web/src/features/Nav.tsx': "/** A \"coming soon\" badge renders here. */\nexport const Nav = () => (<nav>\n  <Link to=\"/orders\">Orders</Link>\n"
                                "  <Link to={`/orders/${id}`}>One</Link>\n  <Link to=\"/reports\">Reports</Link>\n  <a href=\"#\">More</a>\n"
                                "  <a href=\"https://docs.example.com\">Docs</a>\n  <Link to=\"/settings/billing\">Billing</Link>\n"
                                "  <p>Coming soon</p>\n  <button onClick={() => {}}>Export</button>\n  <button disabled>Pay</button>\n"
                                "  <input placeholder=\"Coming soon\" />\n</nav>);\n",
    'web/src/features/Confirm.tsx': "export const C = () => (<Dialog>\n  <form onSubmit={() => undefined}>\n    <input />\n  </form>\n"
                                    "  <Button onClick={confirm}>Confirm</Button>\n</Dialog>);\n",
    'web/src/features/use-deals.ts': "export function useDeals() {\n  return [\n    { id: 1, name: 'Acme' },\n    { id: 2, name: 'Globex' },\n  ];\n}\n"
                                     "export async function useReal() {\n  const rows = await http.get('stores');\n  return [ { id: 1, a: 'x' }, { id: 2, a: 'y' } ];\n}\n",
    'web/src/main.tsx': "import { faker } from '@faker-js/faker';\nif (import.meta.env.DEV) { worker.start(); }\n",
    'web/src/locales/en.json': '{\n  "reports": {\n    "title": "Coming soon",\n    "ok": "Reports"\n  }\n}\n',
    'web/src/features/Nav.test.tsx': "http.get('nowhere');\n",
    'web/src/shared/api/every-call-names-a-served-route.test.ts': "// gate\n",
    'crm/app/main.py': "from fastapi import FastAPI\nfrom .routers import pipeline, tasks\napp = FastAPI()\napp.include_router(pipeline.router)\n"
                       "app.include_router(tasks.router, prefix='/v2')\n\n@app.get(\"/healthz\")\ndef h():\n    return {'ok': True}\n",
    'crm/app/routers/pipeline.py': "from fastapi import APIRouter, HTTPException\nrouter = APIRouter(prefix=\"/api/deals\")\n\n@router.get(\"\")\n"
                                "def list_deals():\n    # TODO: read the table\n    return [\n        {\"id\": 1, \"title\": \"A\"},\n        {\"id\": 2, \"title\": \"B\"},\n    ]\n\n"
                                "@router.post(\"/{deal_id}/convert\")\ndef convert(deal_id: int):\n    raise HTTPException(status_code=501, detail=\"x\")\n",
    'crm/app/routers/tasks.py': "from fastapi import APIRouter\nrouter = APIRouter(prefix=\"/api/tasks\")\n\n@router.get(\"/{task_id}\")\ndef one(task_id: int):\n"
                                "    return query('SELECT 1')\n",
    'crm/templates/tasks.html': "<form method=\"post\" action=\"/api/tasks/bulk\">\n<button type=\"submit\">Go</button>\n</form>\n"
                                "<a href=\"/contacts\">Contacts</a>\n<a href=\"/healthz\">h</a>\n{# coming soon #}\n",
    'srv/package.json': '{"dependencies": {"express": "5"}}',
    'srv/app.js': "import express from 'express';\nimport orders from './orders.js';\nconst app = express();\napp.use('/api/orders', orders);\n",
    'srv/orders.js': "import { Router } from 'express';\nconst router = Router();\nrouter.get('/:id', h);\nrouter.post('/', c);\nexport default router;\n",
    'srv/web/client.js': "export const a = () => axios.get('/api/orders/7');\nexport const b = () => axios.put('/api/orders/7');\n",
    'rails/config/routes.rb': "Rails.application.routes.draw do\n  namespace :api do\n    resources :invoices, only: [:index, :show]\n  end\n  get 'up', to: 'h#s'\nend\n",
    'django/proj/urls.py': "from django.urls import path, include\nurlpatterns = [\n    path('shop/', include('shop.urls')),\n]\n",
    'django/shop/urls.py': "from django.urls import path\nurlpatterns = [\n    path('items/<int:pk>/', view),\n]\n",
    'django/shop/static/client.js': "import x from 'y';\nexport const g = () => fetch('/shop/items/3/');\n",
    'drf/core/urls.py': "from django.urls import path, include\nfrom rest_framework.routers import DefaultRouter\n"
                        "from billing.views import InvoiceViewSet, PlanViewSet, ExportView, ping\nrouter = DefaultRouter()\n"
                        "router.register(r'invoices', InvoiceViewSet, basename='invoice')\nrouter.register('plans', PlanViewSet)\n"
                        "urlpatterns = [path('api/', include(router.urls)), path('api/exports/', ExportView.as_view()), path('api/ping/', ping)]\n",
    'drf/billing/views.py': "from rest_framework import viewsets, mixins\nfrom rest_framework.decorators import action, api_view\n"
                            "from rest_framework.views import APIView\n\nclass InvoiceViewSet(viewsets.ModelViewSet):\n"
                            "    @action(detail=True, methods=['post'], url_path='void')\n    def void_invoice(self, request, pk=None):\n        pass\n\n"
                            "class PlanViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):\n    @action(detail=False)\n"
                            "    def featured(self, request):\n        pass\n\nclass ExportView(APIView):\n    def post(self, request):\n        pass\n\n"
                            "    def delete(self, request):\n        pass\n\n@api_view(['GET', 'HEAD'])\ndef ping(request):\n    pass\n",
}


def self_test():
    tmp = tempfile.mkdtemp(prefix='surface-map-')
    fails = []
    try:
        for rel, body in FIX.items():
            p = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, 'w', encoding='utf-8') as fh:
                fh.write(body)
        opts = {'tests': False, 'clients': [], 'routes_from': None, 'reasons': None, 'inventory': False, 'max': 0,
                'json': False, 'classes': set('12345')}
        rows, ctrls, _, ledger = run([tmp], opts, emit=False)

        def has(kind, *parts):
            return any(r[0] == kind and all(any(p in str(c) for c in r) for p in parts) for r in rows)

        def check(cond, what):
            if not cond:
                fails.append(what)
        check(has('FS1', '/auth/me/permissions', 'gate-fetch'), 'FS1 unserved permission fetch (fail-open shape)')
        check(any(r[0] == 'FS1' and r[1] == 'GET' and r[2] == '/stores/{}/sync' and r[5] == 'method-mismatch:POST' for r in rows), 'FS1 method mismatch')
        check(not has('FS1', '/stores', 'use-stores.ts:1'), 'FS1 served wrapper call under global prefix + version')
        check(not has('FS1', 'auth/login'), 'FS1 inline object generic + @Controller() with no argument')
        check(has('FS1', 'POST', '/api/tasks/bulk', 'form'), 'FS1 form action to a missing route')
        check(has('FS1', 'PUT', '/api/orders/7', 'method-mismatch:GET'), 'FS1 express mount method mismatch')
        check(not any(r[0] == 'FS1' and r[1] == 'GET' and 'orders/7' in r[3] for r in rows), 'FS1 express app.use prefix resolved through the import')
        check(not has('FS1', 'shop/items'), 'FS1 django include prefix')
        check(not has('FS1', 'nowhere'), 'tests are skipped')
        check(not has('FS1', 'example.com'), 'external URLs are not unserved')
        check(has('FS2', 'webhook'), 'FS2 uncalled webhook tagged')
        check(has('FS2', 'DELETE', 'writes'), 'FS2 uncalled DELETE tagged writes')
        check(has('FS2', 'rails/config/routes.rb:3', 'rails') and sum(1 for r in rows if r[0] == 'FS2' and r[4] == 'rails') == 3, 'FS2 rails namespace + resources only:')
        check(not has('FS2', 'GET', '/api/tasks/{}'), 'FS2 include_router prefix + param')
        check(has('FS3', '/reports'), 'FS3 link to a missing page despite a root catch-all')
        check(has('FS3', '/contacts'), 'FS3 server-rendered nav link with no route')
        check(not has('FS3', '/orders/{}') and not has('FS3', '/settings/billing') and not has('FS3', '/healthz'), 'FS3 dynamic, nested and served links')
        check(has('FS4', 'copy', 'Nav.tsx:9'), 'FS4 placeholder copy in JSX text')
        check(not has('FS4', 'copy', 'Nav.tsx:1') and not has('FS4', 'copy', 'Nav.tsx:12'), 'FS4 doc comment and placeholder= are not copy')
        check(not has('FS4', 'copy', 'tasks.html:6'), 'FS4 jinja comment is not copy')
        check(has('FS4', 'catalog', 'en.json:3'), 'FS4 catalog value')
        check(has('FS4', 'not-implemented', 'pipeline.py:14', 'POST /api/deals/{deal_id}/convert'), 'FS4 501 on a mounted route')
        check(has('FS4', 'not-implemented', 'auth.controller.ts'), 'FS4 NotImplementedException')
        check(has('FS4', 'mock-rows', 'pipeline.py', 'todo-comment'), 'FS4 python mock rows')
        check(has('FS4', 'mock-rows', 'use-deals.ts:2'), 'FS4 hook mock rows')
        check(not has('FS4', 'mock-rows', 'use-deals.ts:10'), 'FS4 rows after a data call are not mock rows')
        check(has('FS4', 'mock-import', '@faker-js/faker', 'gated=yes'), 'FS4 faker import (gated flag read)')
        check(has('FS5', 'noop-handler', 'Nav.tsx:10'), 'FS5 noop onClick')
        check(has('FS5', 'hash-href', 'Nav.tsx:6'), 'FS5 href="#"')
        check(has('FS5', 'literal-disabled', 'Nav.tsx:11'), 'FS5 literal disabled')
        check(has('FS5', 'noop-handler', 'Confirm.tsx:2', 'handler:5'), 'FS5 no-op submit names the sibling handler (PP-FS-3)')
        check(any('every-call-names-a-served-route' in c[1] for c in ctrls), 'CONTROL project parity test listed')
        check(clean_path('${API_URL}/orders/${id}?x=1', False)[0] == '/orders/${id}?x=1', 'base-URL template stripped')
        check(canon('/api/v1/orders/:id/', {'api'}) == '/orders/{}' and canon('/[...slug]', set()) == '/{*}', 'canon')
        check(seg_match('/orders/{}', '/orders/7') and not seg_match('/orders', '/orders/7'), 'seg_match')
        _, _, inv, _ = run([os.path.join(tmp, 'drf')], dict(opts, inventory=True), emit=False)
        got = set((r[1], r[2].rstrip('/') or '/') for r in inv if r[0] == 'ROUTE')
        want = {('GET', '/api/invoices'), ('POST', '/api/invoices'), ('GET', '/api/invoices/{}'), ('PUT', '/api/invoices/{}'),
                ('PATCH', '/api/invoices/{}'), ('DELETE', '/api/invoices/{}'), ('POST', '/api/invoices/{}/void'),
                ('GET', '/api/plans'), ('GET', '/api/plans/featured'), ('POST', '/api/exports'), ('DELETE', '/api/exports'),
                ('GET', '/api/ping'), ('HEAD', '/api/ping')}
        check(got == want, 'DRF methods: ModelViewSet actions, mixins, @action(methods=, url_path=), APIView defs, @api_view '
                           '(missing %s, extra %s)' % (sorted(want - got), sorted(got - want)))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for x in fails:
        sys.stderr.write('FAIL  %s\n' % x)
    sys.stderr.write('self-test: %d checks failed\n' % len(fails) if fails else 'self-test: all checks passed\n')
    return 3 if fails else 0


def main(argv):
    if '--self-test' in argv:
        return self_test()
    opts = {'tests': False, 'clients': [], 'routes_from': None, 'reasons': None, 'inventory': False, 'max': 0,
            'json': False, 'classes': set('12345')}
    roots = []
    for a in argv:
        if a == '--include-tests':
            opts['tests'] = True
        elif a == '--inventory':
            opts['inventory'] = True
        elif a == '--json':
            opts['json'] = True
        elif a.startswith('--client='):
            opts['clients'] = [x.strip() for x in a.split('=', 1)[1].split(',') if x.strip()]
        elif a.startswith('--routes-from='):
            opts['routes_from'] = a.split('=', 1)[1]
        elif a.startswith('--reasons='):
            opts['reasons'] = a.split('=', 1)[1]
        elif a.startswith('--classes='):
            opts['classes'] = set(re.findall(r'[1-5]', a.split('=', 1)[1]))
        elif a.startswith('--max='):
            opts['max'] = int(a.split('=', 1)[1] or 0)
        elif a in ('-h', '--help'):
            print(__doc__); return 0
        elif a.startswith('-'):
            sys.stderr.write('unknown option %s\n' % a); return 1
        else:
            roots.append(a)
    roots = roots or ['.']
    for r in roots:
        if not os.path.isdir(r):
            sys.stderr.write('not a directory: %s\n' % r); return 1
    rows, _, _, _ = run(roots, opts)
    return 2 if any(r[0] in ('FS1', 'FS3') for r in rows) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
