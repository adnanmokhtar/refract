#!/usr/bin/env python3
"""name-check.py — naming-layout-scan § 1 (AL-16 files and directories), § 2 (AL-17 identifiers) and § 4 (AL-19
placement): every name checked against a rule the ORACLE declares, never against a taste.

Why a script and not rg: a file name is a finding only against a declared rule for ITS scope (ls-lint's
nearest directory key, a check-file glob, a doc bullet such as "Hook files are camelCase and start with
`use`"), and only when no framework mandates the name (`page.tsx`, `[id].tsx`, `0003_auto.py`). Both need a
rule table and a path model, not a regex.

Usage:  rg --files "${ROOTS[@]}" | python3 -I name-check.py <root> --files=- [--oracle=<oracle-map out dir>] [--all] [--json]
        python3 -I name-check.py <root> --files=<list file> [--oracle=<dir>] [--rule=<spec>]… [--skeleton] [--all] [--json]
        python3 -I name-check.py <root> --census            concern<TAB>shape<TAB>path rows for `oracle-map.py propose`
        python3 -I name-check.py --self-test
File list: `--files=-` reads it from stdin, `--files=<path>` from a file (root-relative or absolute paths, one
per line; the caller's rg owns the exclusions). Without --files, a walk of <root> that skips node_modules,
build output, vendored and generated trees (P-16). Stdin is NEVER read implicitly: an agent or CI shell
hands the process an open, non-terminal stdin that never closes, and the old "read stdin when it is not a
terminal" rule hung there until the caller's timeout (measured 2026-10-18: a 120 s timeout on `--census`).
--oracle: the directory oracle-map.py --out wrote. Without it, the sibling
  ../../convention-oracle/scripts/oracle-map.py is imported and run in memory (the align pack ships both);
  when that file is absent too, only --rule specs are checked and the summary says `oracle: NOT RUN`.
--rule=<glob>=<case>[;prefix=use][;suffix=.store.ts][;kind=file|dir][;export] — an explicit rule (tests, or a
  rule the skill read by hand). <case> pascal|camel|kebab|snake|screaming|flat. `export` = the file's stem
  must equal its exported component/function name.
--skeleton: § 4 placement — declared module paths in ai/modules.md / ai/architecture.md (root-relative OR
  relative to the nearest heading that is or carries a path, `## apps/web (`apps/web/src/`)`: both catalog
  forms; a backticked cell with or without its trailing slash) must exist as a directory, a file stem, or on
  disk; a lint rule id that only looks like a path is skipped; a co-location rule
  ("tests are co-located") flags __tests__/ trees, a separate-tests rule flags co-located *.test.*; a barrel
  rule ("each feature exposes an index.ts") flags feature directories without one.
--census: for AL-02 (split, no declared winner) — the case of every file stem, grouped by category
  (`file-case:<dir role>/*<ext>`, `hook-file-case`), for oracle-map.py propose. No rule needed, no verdict.
  A one-word lowercase stem (`orders.ts`) fits kebab, camel and snake at once, so it does not vote.

RULE SOURCES (each rule carries the oracle's tag; see oracle-map.py):
  ls-lint (.ls-lint.yml dir keys, `.dir`, extensions; a deeper key overrides its parents for the subtree —
  the ls-lint trap), eslint check-file/filename-naming-convention and folder-naming-convention (glob ->
  CASE), unicorn/filename-case (case / cases; checks directories on v >= 65 — the gate oracle-map prints),
  @typescript-eslint/naming-convention (typeLike / class / interface / typeAlias / enum format, function
  format, variable `types: ['boolean']` prefix), Ruff N (N801 class CapWords, N802 function lower, N999
  module), and doc bullets that name a SUBJECT (component / hook / store / test / Python / directories /
  files under `<path>`) and a CASE, PREFIX ("start with `use`"), SUFFIX ("end in `.store.ts`") or an EXPORT
  match ("match the exported component name").
  enforced / written rows -> verdict `candidate`; generated (T2g) rows -> `unconfirmed` (ratify the oracle
  line first, P-28); contested rows -> no rule, printed as `contested (AL-02) — skipped`.

EXEMPT (P-13 framework-mandated, P-15 wire names, P-16 generated):
  Next/App Router page|layout|loading|error|global-error|not-found|template|default|route|middleware|
  instrumentation|opengraph-image|twitter-image|icon|apple-icon|sitemap|robots|manifest; pages/_app,
  _document, _error, 404, 500; route segments [id] [...slug] [[...x]] (group) @slot _private; Remix /
  TanStack $param, _index, __root, route files with dots; SvelteKit +page +layout +error +server
  hooks.server; Nuxt app.vue error.vue layouts/default.vue; Vue SFC App.vue; index.* barrels; __init__.py
  __main__.py conftest.py manage.py settings.py wsgi.py asgi.py urls.py apps.py admin.py models.py;
  Django/Alembic/Prisma/TypeORM/Knex timestamped or numbered migrations; Nest role files
  (*.module|controller|service|dto|entity|guard|pipe|interceptor|filter|resolver|gateway|strategy|decorator.ts)
  whose stem is kebab (the Nest CLI's own convention) against a non-kebab rule; Angular *.component|
  directive|service|module|pipe.ts likewise; *.d.ts, *.config.*, dotfiles, Dockerfile, Makefile, README,
  LICENSE, CHANGELOG, package.json, go.mod, Go *_test.go, Storybook .storybook/; generated/vendored paths.
  Symbols: names bound by a wire contract (@Expose, @JsonProperty, @SerializedName, @Column({ name }),
  alias=, db_column=, Field(alias=)) are never AL-17 rows.

OUTPUT: TSV `# class site subject rule expected actual tag oracle verdict note` (or --json). verdict
  candidate | unconfirmed | advisory | exempt (exempt rows only with --all). advisory = class AL-04: a doc rule
  that >= 80% of >= 5 matched files break describes a codebase that moved on (P-18), so it is not N renames. One
  site broken the same way under several rules is one row (`also N<k>` in the note). ls-lint `a | b` cases are
  alternatives; contested doc rows make no rule. Stderr: one line per rule —
  `rule N11 (<oracle source>): matched N files · k candidates · e exempt` — and `NOT RUN (vacuous: matched 0
  files)` for a rule whose scope matched nothing (V-09: a vacuous rule is not a clean one).
Exit: 0 no candidate · 1 at least one candidate/unconfirmed row · 2 usage · 3 self-test failed.
Stdlib only, Python >= 3.8, `python3 -I` safe; reads files, never writes into <root> (the self-test writes a
mktemp -d tree under $TMPDIR and removes it).
"""
import importlib.util, json, os, re, shutil, sys, tempfile

SKIP_DIRS = {'node_modules', '.git', 'dist', 'build', 'out', '.next', '.nuxt', '.output', '.svelte-kit', 'coverage',
             'vendor', 'third_party', '.turbo', '.cache', 'storybook-static', '.venv', 'venv', '__pycache__', 'target',
             '.gradle', '.dart_tool', 'Pods', '__generated__', 'generated', '.idea', '.vscode'}
CASES = {
    'pascal': re.compile(r'^[A-Z][A-Za-z0-9]*$'),
    'camel': re.compile(r'^[a-z][A-Za-z0-9]*$'),
    'kebab': re.compile(r'^[a-z0-9]+(?:-[a-z0-9]+)*$'),
    'snake': re.compile(r'^[a-z0-9]+(?:_[a-z0-9]+)*$'),
    'screaming': re.compile(r'^[A-Z0-9]+(?:_[A-Z0-9]+)*$'),
    'flat': re.compile(r'^[a-z0-9]+$'),
}
CASE_WORDS = [(r'pascal[\s_-]?case|PASCAL_CASE|pascalcase', 'pascal'), (r'camel[\s_-]?case|CAMEL_CASE|camelcase', 'camel'),
              (r'kebab[\s_-]?case|KEBAB_CASE|kebabcase|dash-case', 'kebab'), (r'screaming[\s_-]?snake|SCREAMING_SNAKE_CASE|screamingsnakecase', 'screaming'),
              (r'snake[\s_-]?case|SNAKE_CASE|snakecase', 'snake'), (r'FLAT_CASE|flat[\s_-]?case|lowercase', 'flat')]
ROLE_SUFFIX = re.compile(r'\.(?:module|controller|service|dto|entity|guard|pipe|interceptor|filter|resolver|gateway|strategy|'
                         r'decorator|middleware|component|directive|spec|test|stories|story|e2e|d|config|schema|model|store|'
                         r'routes?|types?|utils?|constants?|hooks?|styles?|module\.css)$')
NEXT_FILES = re.compile(r'^(?:page|layout|loading|error|global-error|not-found|template|default|route|middleware|instrumentation|'
                        r'opengraph-image|twitter-image|icon|apple-icon|sitemap|robots|manifest|head)$')
GENERIC_EXEMPT = re.compile(r'^(?:index|main|App|app|__init__|__main__|conftest|manage|settings|wsgi|asgi|urls|apps|admin|models|'
                            r'views|setup|vite-env|next-env|env|Dockerfile|Makefile|Procfile|README|LICENSE|CHANGELOG|CONTRIBUTING|'
                            r'SECURITY|CODEOWNERS|package|tsconfig|jsconfig|go|Cargo|Gemfile|Rakefile|Podfile|_app|_document|_error|'
                            r'404|500|_layout|_index|__root|\+page|\+layout|\+error|\+server|\+page\.server|\+layout\.server|hooks\.server)$')
NEST_ROLE = re.compile(r'\.(?:module|controller|service|dto|entity|guard|pipe|interceptor|filter|resolver|gateway|strategy|decorator|'
                       r'component|directive)\.ts$')


def case_ok(case, name):
    """`case` may be one case or alternatives `camel|kebab` (ls-lint `camelCase | kebab-case`): any one fits."""
    return any(CASES[c].match(name) for c in case.split('|'))


def case_of(stem):
    for name in ('pascal', 'camel', 'kebab', 'snake', 'screaming'):
        if CASES[name].match(stem):
            if name in ('camel', 'kebab', 'snake') and CASES['flat'].match(stem):
                return 'flat'
            return name
    return 'mixed'


def stem_of(base):
    s = base
    for _ in range(3):
        root, ext = os.path.splitext(s)
        if not ext:
            break
        s = root
        if not ROLE_SUFFIX.search(s) and '.' not in s:
            break
        m = ROLE_SUFFIX.search(s)
        if m:
            s = s[:m.start()]
            break
    return s.split('.')[0] if s else base


def exempt(path, kind='file'):
    """P-13 / P-16 reason, or ''."""
    parts = path.split('/')
    base = parts[-1]
    low = path.lower()
    if base.startswith('.') or any(p.startswith('.') and p not in ('.',) for p in parts[:-1] if p not in ('.github',)):
        return 'dotfile'
    if re.search(r'(?:^|/)(?:migrations?|alembic/versions|prisma/migrations|db/migrate|database/migrations)/', low):
        return 'P-13 migration'
    if re.match(r'^\d{3,}[_-]|^\d{10,}', base):
        return 'P-13 numbered/timestamped migration'
    if re.search(r'\.gen\.|(?:^|/)(?:__generated__|generated|vendor|third_party)/|\.pb\.|_pb2\.py$', low):
        return 'P-16 generated/vendored'
    if kind == 'dir':
        if re.match(r'^(?:\(.*\)|\[.*\]|@[\w-]+|_[\w-]+|__\w+__)$', base):
            return 'P-13 route segment / private dir'
        return ''
    st = base.split('.')[0]
    if re.match(r'^(?:\[.*\]|\$.*|\(.*\)|\+.*|_index|__root)', base) or '$' in base:
        return 'P-13 route file'
    if (re.search(r'(?:^|/)(?:app|src/app)/', path) or '/app/' in '/' + path) and NEXT_FILES.match(st):
        return 'P-13 Next app router file'
    if re.search(r'(?:^|/)pages/', path) and re.match(r'^(?:_app|_document|_error|404|500)$', st):
        return 'P-13 Next pages file'
    if re.search(r'(?:^|/)routes/', path) and '.' in base.rsplit('.', 1)[0]:
        return 'P-13 flat route file'
    if GENERIC_EXEMPT.match(st) or GENERIC_EXEMPT.match(base.rsplit('.', 1)[0]):
        return 'P-13 framework/tool name'
    if re.search(r'\.d\.ts$|\.config\.\w+$|(?:^|/)\.storybook/', path):
        return 'P-13 tool file'
    if base.endswith('_test.go'):
        return 'P-13 go test'
    if re.search(r'(?:^|/)layouts/default\.vue$|(?:^|/)(?:app|error)\.vue$', path):
        return 'P-13 Nuxt file'
    return ''


# ---------------------------------------------------------------- rules
class Rule(object):
    def __init__(self, rid, kind, scope, case=None, prefix=None, suffix=None, export=False, tag='written', oracle='', note=''):
        self.id, self.kind, self.scope = rid, kind, scope          # scope: callable(path) -> bool
        self.case, self.prefix, self.suffix, self.export = case, prefix, suffix, export
        self.tag, self.oracle, self.note = tag, oracle, note
        self.matched, self.cands, self.exempt = 0, 0, 0
        self.desc = ''
        self.origin = 'config'


def glob_re(g):
    out, i = '', 0
    g = g[2:] if g.startswith('./') else g
    while i < len(g):
        c = g[i]
        if g.startswith('**/', i):
            out += '(?:.*/)?'; i += 3; continue
        if g.startswith('**', i):
            out += '.*'; i += 2; continue
        if c == '*':
            out += '[^/]*'
        elif c == '?':
            out += '[^/]'
        elif c == '{':
            j = g.find('}', i)
            if j > 0:
                out += '(?:' + '|'.join(re.escape(x) for x in g[i + 1:j].split(',')) + ')'; i = j + 1; continue
            out += re.escape(c)
        else:
            out += re.escape(c)
        i += 1
    return re.compile('^' + out + '$')


def word_case(text):
    for rx, name in CASE_WORDS:
        if re.search(rx, text, re.I if name != 'screaming' else 0):
            return name
    return None


COMPONENT_FILE = lambda p: p.endswith(('.tsx', '.jsx', '.vue', '.svelte'))
SUBJECTS = [
    (r'\bcomponent files?\b|\bcomponents? are\b', lambda p: p.endswith(('.tsx', '.jsx', '.vue', '.svelte')) and '/components/' in '/' + p),
    (r'\bhook files?\b|\bhooks? are\b', lambda p: re.match(r'^use[A-Z-]|^use$', os.path.basename(p), re.I) is not None or '/hooks/' in '/' + p),
    (r'\bstore files?\b|\bstores? (?:are|end)\b', lambda p: '/stores/' in '/' + p or 'store' in os.path.basename(p).lower()),
    (r'\btest files?\b|\btests? are named\b', lambda p: re.search(r'\.(?:test|spec)\.', p) is not None),
    (r'\bpython (?:modules?|files?)\b', lambda p: p.endswith('.py')),
    (r'\b(?:directories|folders|directory names|folder names)\b', None),
]


def doc_rules(docs, rid0):
    rules = []
    n = rid0
    for d in docs:
        q = d.get('quote', '')
        if d.get('tag') in ('off', 'inactive', 'contested'):
            continue                                       # a contested row is AL-02 (convention-oracle § 2): never a naming rule
        case = word_case(q)
        pm = re.search(r'(?:start|begin)s? with\s+`?([\w$-]+)`?|prefix(?:ed)?(?: with)?\s+`([\w$-]+)`', q, re.I)
        sm = re.search(r'end(?:s)? (?:in|with)\s+`([\w.$-]+)`|suffix(?:ed)?(?: with)?\s+`([\w.$-]+)`', q, re.I)
        exp = re.search(r'match(?:es)? (?:the|its) export', q, re.I)
        if not (case or pm or sm or exp):
            continue
        scope, kind = None, 'file'
        for rx, fn in SUBJECTS:
            if re.search(rx, q, re.I):
                scope = fn
                kind = 'dir' if fn is None else 'file'
                break
        um = re.search(r'(?:under|in|inside|within)\s+`([\w.-]*/[\w./-]*)`', q)   # a directory: it has a slash
        if um:
            pre = um.group(1).strip('/') + '/'
            inner = scope
            if inner is SUBJECTS[0][1]:                    # "component files under `<dir>`": the dir replaces /components/
                inner = COMPONENT_FILE
            # The subject filter AND the directory, both. (An `or` here once let "Component files under apps/web/src/"
            # judge every .ts module under the directory as a component: 46 false rows on convention-drift.)
            scope = (lambda pre, inner: lambda p: (p.startswith(pre) or ('/' + pre) in ('/' + p)) and (inner is None or inner(p)))(pre, inner)
            if kind == 'file' and inner is None and re.search(r'\bmodules?\b|\bfiles?\b', q, re.I) and re.search(r'non-component', q, re.I):
                scope = (lambda pre: lambda p: (p.startswith(pre) or ('/' + pre) in '/' + p) and not p.endswith(('.tsx', '.jsx')))(pre)
        if scope is None and kind == 'file':
            continue                                       # a case word with no subject is not a rule
        if kind == 'dir' and scope is None:
            scope = lambda p: True
        n += 1
        pre_ = (pm.group(1) or pm.group(2)) if pm else None
        suf_ = (sm.group(1) or sm.group(2)) if sm else None
        r = Rule('N%d' % n, kind, scope, case, pre_, suf_, bool(exp), d.get('tag', 'written'), d.get('source', ''))
        r.desc = q[:80]
        r.origin = 'doc'
        rules.append(r)
    return rules, n


def config_rules(rules_rows, rid0):
    out, n = [], rid0
    for r in rules_rows:
        tool, rule, opts, tag = r.get('tool'), r.get('rule', ''), r.get('options', ''), r.get('tag', 'enforced')
        if tag == 'off':
            continue
        base = r.get('source', '').split(':')[0].rsplit('/', 1)[0] if '/' in r.get('source', '') else ''
        if tool == 'ls-lint':
            m = re.match(r'^(\S+) (\S+)$', rule)
            if not m:
                continue
            d, ext = m.group(1), m.group(2)
            # `camelCase | kebab-case` is an alternative: a name passes when it fits ANY of them (ls-lint's own `|`)
            alts = [word_case(a) or ('flat' if 'lowercase' in a else None) for a in opts.split('|')]
            alts = [a for i, a in enumerate(alts) if a and a not in alts[:i]]
            if not alts:
                continue
            case = '|'.join(alts)
            pre = '/'.join(x for x in [base, d if d != '.' else ''] if x)
            n += 1
            if ext == '.dir':
                scope = (lambda pre: lambda p: p.startswith(pre + '/') if pre else True)(pre)
                out.append(Rule('N%d' % n, 'dir', scope, case, tag=tag, oracle=r.get('source', ''), note='ls-lint'))
            else:
                scope = (lambda pre, ext: lambda p: (p.startswith(pre + '/') if pre else True) and p.endswith(ext))(pre, ext)
                out.append(Rule('N%d' % n, 'file', scope, case, tag=tag, oracle=r.get('source', ''), note='ls-lint'))
        elif tool == 'eslint' and rule in ('check-file/filename-naming-convention', 'check-file/folder-naming-convention', 'unicorn/filename-case',
                                          '@typescript-eslint/naming-convention'):
            try:
                val = json.loads(opts) if opts else []
            except ValueError:
                val = []
            o = val[0] if val else {}
            if rule.startswith('check-file/') and isinstance(o, dict):
                for g, c in o.items():
                    case = word_case(str(c))
                    if not case:
                        continue
                    n += 1
                    rx = glob_re(g)
                    kind = 'dir' if 'folder' in rule else 'file'
                    out.append(Rule('N%d' % n, kind, (lambda rx, base: lambda p: rx.match(p[len(base) + 1:] if base and p.startswith(base + '/') else p) is not None)(rx, base),
                                    case, tag=tag, oracle=r.get('source', ''), note=rule))
            elif rule == 'unicorn/filename-case' and isinstance(o, dict):
                cases = [o.get('case')] if o.get('case') else [k for k, v in (o.get('cases') or {}).items() if v]
                case = word_case(re.sub(r'Case$', ' case', cases[0])) if cases else 'kebab'
                n += 1
                out.append(Rule('N%d' % n, 'file', lambda p: p.endswith(('.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs')),
                                case, tag=tag, oracle=r.get('source', ''), note=rule))
            elif rule == '@typescript-eslint/naming-convention':
                for sel in val if isinstance(val, list) else []:
                    if not isinstance(sel, dict):
                        continue
                    fmt = (sel.get('format') or [None])[0]
                    n += 1
                    out.append(Rule('N%d' % n, 'symbol', lambda p: p.endswith(('.ts', '.tsx', '.mts', '.cts')), word_case(str(fmt)) if fmt else None,
                                    prefix='|'.join(sel.get('prefix') or []) or None, tag=tag, oracle=r.get('source', ''),
                                    note='ts:%s%s' % (sel.get('selector'), ':' + ','.join(sel.get('types')) if sel.get('types') else '')))
        elif tool == 'ruff' and re.match(r'^N(?:80[12]|999)?$', rule):
            n += 1
            out.append(Rule('N%d' % n, 'symbol', lambda p: p.endswith('.py'), 'snake', tag=tag, oracle=r.get('source', ''),
                            note='ruff:%s' % rule))
    return out, n


def parse_rule_spec(spec, n):
    glob, _, rest = spec.partition('=')
    parts = rest.split(';')
    case = parts[0] if parts[0] in CASES else None
    kw = dict(p.split('=', 1) if '=' in p else (p, True) for p in parts[1:])
    rx = glob_re(glob)
    return Rule('N%d' % n, kw.get('kind', 'file'), lambda p: rx.match(p) is not None, case, kw.get('prefix'), kw.get('suffix'),
                bool(kw.get('export')), 'enforced', '--rule ' + spec)


# ---------------------------------------------------------------- checks
EXPORT_RX = re.compile(r'^export\s+(?:default\s+)?(?:async\s+)?(?:function\*?\s+([A-Za-z_$][\w$]*)|(?:const|let|class)\s+([A-Za-z_$][\w$]*))', re.M)
WIRE = re.compile(r'@(?:Expose|JsonProperty|SerializedName|JsonPropertyName)\b|@Column\(\s*\{[^}]*\bname\s*:|\balias\s*=|\bdb_column\s*=|Field\(\s*alias')


def read(p):
    try:
        with open(p, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except OSError:
        return ''


def check_files(root, files, rules):
    rows = []
    dirs = sorted({'/'.join(f.split('/')[:i]) for f in files for i in range(1, f.count('/') + 1)})
    for r in rules:
        if r.kind == 'dir':
            for d in dirs:
                if not r.scope(d + '/'):
                    continue
                base = d.split('/')[-1]
                ex = exempt(d, 'dir')
                r.matched += 1
                if ex:
                    r.exempt += 1
                    rows.append(row('AL-16', d + '/', 'dir', r, r.case, base, 'exempt', ex))
                    continue
                if r.case and not case_ok(r.case, base):
                    r.cands += 1
                    rows.append(row('AL-16', d + '/', 'dir', r, r.case, case_of(base), None, ''))
            continue
        if r.kind != 'file':
            continue
        for f in files:
            if not r.scope(f):
                continue
            base = os.path.basename(f)
            st = stem_of(base)
            r.matched += 1
            ex = exempt(f)
            if not ex and NEST_ROLE.search(base) and r.case and 'kebab' not in r.case.split('|') and CASES['kebab'].match(st):
                ex = 'P-13 Nest/Angular role file in the CLI\'s kebab case'
            if ex:
                r.exempt += 1
                rows.append(row('AL-16', f, 'file', r, r.case or '-', st, 'exempt', ex))
                continue
            problems = []
            if r.case and not case_ok(r.case, st):
                problems.append((r.case, case_of(st)))
            if r.prefix and not any(st.startswith(p) for p in r.prefix.split('|')):
                problems.append(('prefix ' + r.prefix, st))
            if r.suffix and not base.endswith(r.suffix):
                problems.append(('suffix ' + r.suffix, base))
            for exp_, act in problems:
                r.cands += 1
                rows.append(row('AL-16', f, 'file', r, exp_, act, None, ''))
            if r.export and f.endswith(('.tsx', '.jsx', '.ts', '.js', '.vue', '.svelte')):
                src = read(os.path.join(root, f))
                names = [(m.group(1) or m.group(2), src.count('\n', 0, m.start()) + 1) for m in EXPORT_RX.finditer(src)]
                if names and not any(nm == st for nm, _ in names):
                    nm, ln = names[0]
                    r.cands += 1
                    rows.append(row('AL-16', '%s:%d' % (f, ln), 'file', r, 'stem == export %s' % nm, st, None, 'export-matches-file'))
    return rows


SYM_TS = re.compile(r'^\s*(?:export\s+)?(?:default\s+)?(?:(class|interface|type|enum)\s+([A-Za-z_$][\w$]*)|'
                    r'(?:async\s+)?function\s+([A-Za-z_$][\w$]*)|(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*(?::\s*boolean\b|=\s*(?:true|false)\b))')
SYM_PY = re.compile(r'^\s*(?:(class)\s+([A-Za-z_]\w*)|def\s+([A-Za-z_]\w*))')


def check_symbols(root, files, rules):
    rows = []
    for r in rules:
        if r.kind != 'symbol':
            continue
        for f in files:
            if not r.scope(f) or exempt(f):
                continue
            r.matched += 1
            lines = read(os.path.join(root, f)).split('\n')
            for ln, line in enumerate(lines, 1):
                prev = lines[ln - 2] if ln > 1 else ''
                if WIRE.search(line) or WIRE.search(prev):
                    continue                                    # P-15 wire name
                if f.endswith('.py'):
                    m = SYM_PY.match(line)
                    if not m:
                        continue
                    if m.group(1):
                        name, want = m.group(2), 'pascal'
                    else:
                        name, want = m.group(3), 'snake'
                        if name.startswith('__') and name.endswith('__'):
                            continue
                        name = name.lstrip('_')
                    if not name or (want == 'pascal' and r.note == 'ruff:N802') or (want == 'snake' and r.note == 'ruff:N801'):
                        continue
                    if not CASES[want].match(name) and not (want == 'snake' and CASES['flat'].match(name.lower()) and name.islower()):
                        r.cands += 1
                        rows.append(row('AL-17', '%s:%d' % (f, ln), 'class' if want == 'pascal' else 'function', r, want, case_of(name), None, name))
                    continue
                m = SYM_TS.match(line)
                if not m:
                    continue
                note = r.note or ''
                if m.group(1):
                    name, sel = m.group(2), {'class': 'class', 'interface': 'interface', 'type': 'typeAlias', 'enum': 'enum'}[m.group(1)]
                elif m.group(3):
                    name, sel = m.group(3), 'function'
                else:
                    name, sel = m.group(4), 'variable:boolean'
                want_sel = note.split(':', 1)[1] if note.startswith('ts:') else ''
                fits = (want_sel == sel or (want_sel == 'typeLike' and sel in ('class', 'interface', 'typeAlias', 'enum')) or
                        (want_sel == 'variable:boolean' and sel == 'variable:boolean') or (want_sel == 'variable' and sel.startswith('variable')) or
                        (note.startswith('doc-boolean') and sel == 'variable:boolean'))
                if not fits:
                    continue
                bad = []
                if r.prefix:
                    pre = [p for p in r.prefix.split('|') if name.startswith(p) and name[len(p):len(p) + 1].isupper()]
                    if not pre:
                        bad.append(('prefix ' + r.prefix, name))
                    rest = name[len(pre[0]):] if pre else name
                else:
                    rest = name
                if r.case and not case_ok(r.case, rest if r.prefix else name) and not (r.prefix and CASES['pascal'].match(rest)):
                    bad.append((r.case, case_of(name)))
                for exp_, act in bad:
                    r.cands += 1
                    rows.append(row('AL-17', '%s:%d' % (f, ln), sel, r, exp_, act, None, name))
    return rows


def row(cls, site, subject, r, expected, actual, verdict, note):
    if verdict is None:
        verdict = 'unconfirmed' if r.tag == 'generated' else 'candidate'
    return dict(**{'class': cls}, site=site, subject=subject, rule=r.id, expected=expected, actual=actual, tag=r.tag,
                oracle=r.oracle, verdict=verdict, note=note)


def skeleton(root, files, docs, rule_names=()):
    rows = []
    fileset = set(files)
    dirs = {'/'.join(f.split('/')[:i]) for f in files for i in range(1, f.count('/') + 1)}
    heading_path = {}
    for path in ('ai/modules.md', 'ai/architecture.md'):
        if not os.path.isfile(os.path.join(root, path)):
            continue
        stack, hp = [], {}                             # (level, path-or-'') per open heading
        for i, line in enumerate(read(os.path.join(root, path)).split('\n'), 1):
            h = re.match(r'^(#{1,6})\s+(.*?)\s*$', line)
            if h:
                lvl, txt = len(h.group(1)), h.group(2)
                # section-rooted: `## apps/web/` · `## apps/web (`apps/web/src/`)` · `## apps/api — NestJS …`
                pm = re.search(r'`((?:[\w@.-]+/)+[\w@.-]*)`', txt) or re.match(r'^((?:[\w.-]+/)+[\w.-]*)(?:\s|$)', txt)
                while stack and stack[-1][0] >= lvl:
                    stack.pop()
                stack.append((lvl, pm.group(1).strip('/') if pm and '/' in pm.group(1) else ''))
            cur = next((p for _, p in reversed(stack) if p), '')
            hp[i] = cur
        heading_path[path] = hp
    for path, hp in heading_path.items():
        for i, line in enumerate(read(os.path.join(root, path)).split('\n'), 1):
            if re.match(r'^#{1,6}\s', line):
                continue                               # a heading's own path is the root, not a module claim
            # a directory claim: `features/orders/` or `features/orders` (no trailing slash: a table cell); never a
            # file (`x.ts`), a package specifier (`@scope/pkg`), a glob, a route (`/api/v1`) or a placeholder (`<x>`)
            for m in re.finditer(r'`((?:[\w.-]+/)+[\w-]*)`', line):
                p = m.group(1).strip('/')
                if '*' in p or '{' in p or '/' not in m.group(1).rstrip('/') and not m.group(1).endswith('/'):
                    continue
                if re.search(r'\.[A-Za-z]\w{0,4}$', p.rsplit('/', 1)[-1]):
                    continue
                if p in rule_names:
                    continue                           # `plugin/rule-name` is a lint rule id, not a directory
                cands = [p] + ([hp.get(i, '') + '/' + p] if hp.get(i) else [])
                stems = set() if m.group(1).endswith('/') else {f.rsplit('.', 1)[0] for f in files if '.' in f.rsplit('/', 1)[-1]}
                if not any(c in dirs or c in stems or os.path.isdir(os.path.join(root, c)) for c in cands) \
                        and not any(d_.endswith('/' + p) for d_ in dirs) and not any(st.endswith('/' + p) for st in stems):
                    # absent root-relative, heading-relative AND as the tail of any directory (a prose mention such
                    # as "nothing outside `domain/`" names a directory that exists deeper)
                    rows.append({'class': 'AL-19', 'site': '%s:%d' % (path, i), 'subject': 'module', 'rule': 'skeleton',
                                 'expected': 'declared path exists', 'actual': p + '/ absent', 'tag': 'written',
                                 'oracle': '%s:%d' % (path, i), 'verdict': 'candidate', 'note': 'root-, heading- and tail-relative forms tried'})
    for d in docs:
        q, tag = d.get('quote', ''), d.get('tag')
        if tag in ('contested', 'off', 'inactive'):
            continue
        verdict = 'unconfirmed' if tag == 'generated' else 'candidate'
        if re.search(r'co-?locat', q, re.I) and re.search(r'\btests?\b|\bspecs?\b', q, re.I):
            for f in files:
                if '/__tests__/' in '/' + f:
                    rows.append({'class': 'AL-19', 'site': f, 'subject': 'test placement', 'rule': 'colocate', 'expected': 'co-located',
                                 'actual': '__tests__/', 'tag': tag, 'oracle': d['source'], 'verdict': verdict, 'note': ''})
        elif re.search(r'__tests__', q) and re.search(r'\btests?\b', q, re.I):
            for f in files:
                if re.search(r'\.(?:test|spec)\.', f) and '/__tests__/' not in '/' + f:
                    rows.append({'class': 'AL-19', 'site': f, 'subject': 'test placement', 'rule': 'tests-dir', 'expected': '__tests__/',
                                 'actual': 'co-located', 'tag': tag, 'oracle': d['source'], 'verdict': verdict, 'note': ''})
        m = re.search(r'(?:each|every)\s+(?:feature|module)[^.]*\b(?:index\.(?:ts|js|py)|__init__\.py)', q, re.I)
        if m:
            bm = re.search(r'`([\w./-]+)/(?:\*|<[\w-]+>)/?`', q)
            parent = bm.group(1).strip('/') if bm else None
            barrel = re.search(r'(index\.(?:ts|js)|__init__\.py)', q).group(1)
            for dd in sorted(dirs):
                par = dd.rsplit('/', 1)[0] if '/' in dd else ''
                if (parent and par.endswith(parent)) or (not parent and re.search(r'(?:^|/)(?:features|modules)$', par)):
                    if dd + '/' + barrel not in fileset and not any(x.startswith(dd + '/index.') for x in fileset):
                        rows.append({'class': 'AL-19', 'site': dd + '/', 'subject': 'barrel', 'rule': 'barrel', 'expected': barrel,
                                     'actual': 'absent', 'tag': tag, 'oracle': d['source'], 'verdict': verdict, 'note': ''})
    return rows


def census(files):
    out = []
    for f in files:
        if exempt(f):
            continue
        base = os.path.basename(f)
        ext = os.path.splitext(base)[1]
        if ext not in ('.ts', '.tsx', '.js', '.jsx', '.vue', '.svelte', '.py', '.go', '.dart', '.rb', '.css', '.scss'):
            continue
        st = stem_of(base)
        if case_of(st) == 'flat':
            continue                                   # one lowercase word fits kebab, camel and snake: it does not vote
        parts = f.split('/')[:-1]
        role = next((p for p in reversed(parts) if p in ('components', 'hooks', 'lib', 'utils', 'stores', 'services', 'pages', 'views',
                                                          'routes', 'features', 'modules', 'api', 'models', 'composables')), 'other')
        if re.match(r'^use[A-Z-]', st) or re.match(r'^use-', st):
            out.append(('hook-file-case', case_of(st), f))
        out.append(('file-case:%s/*%s' % (role, ext), case_of(st), f))
    return out


# ---------------------------------------------------------------- driver
def load_oracle(root, odir):
    if odir:
        res = {}
        for name in ('rules', 'docs'):
            p = os.path.join(odir, name + '.tsv')
            recs = []
            if os.path.isfile(p):
                lines = read(p).rstrip('\n').split('\n')
                cols = lines[0][2:].split('\t') if lines else []
                recs = [dict(zip(cols, l.split('\t'))) for l in lines[1:] if l and not l.startswith('#')]
            res[name] = recs
        return res, 'oracle dir %s' % odir
    sib = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'convention-oracle', 'scripts', 'oracle-map.py')
    if not os.path.isfile(sib):
        return {'rules': [], 'docs': []}, 'NOT RUN (no oracle map and no sibling oracle-map.py)'
    sys.dont_write_bytecode = True                   # no __pycache__ beside the installed skill
    spec = importlib.util.spec_from_file_location('oracle_map', sib)
    om = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(om)
    t = om.tables(om.build(root))
    return {'rules': t['rules'], 'docs': t['docs']}, 'built in memory by oracle-map.py'


def list_files(root):
    out = []
    for d, dirs, fs in os.walk(root):
        rd = os.path.relpath(d, root).replace(os.sep, '/')
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS and not (x.startswith('.') and x not in ('.github', '.storybook')))
        for f in sorted(fs):
            out.append(f if rd == '.' else rd + '/' + f)
    return out


COLS = ['class', 'site', 'subject', 'rule', 'expected', 'actual', 'tag', 'oracle', 'verdict', 'note']


def run(root, files, oracle_dir=None, specs=(), want_skeleton=False):
    oracle, how = load_oracle(root, oracle_dir)
    rules, n = doc_rules(oracle.get('docs', []), 0)
    cr, n = config_rules(oracle.get('rules', []), n)
    rules += cr
    for s in specs:
        n += 1
        rules.append(parse_rule_spec(s, n))
    for d in oracle.get('docs', []):
        q = d.get('quote', '')
        if d.get('tag') in ('off', 'inactive', 'contested'):
            continue
        if re.search(r'\bbooleans?\b', q, re.I) and re.search(r'`(is|has|should|can)`', q):
            n += 1
            pre = '|'.join(re.findall(r'`(is|has|should|can|did|will)`', q))
            r = Rule('N%d' % n, 'symbol', lambda p: p.endswith(('.ts', '.tsx', '.js', '.jsx')), None, pre, tag=d.get('tag', 'written'),
                     oracle=d.get('source', ''), note='doc-boolean')
            rules.append(r)
    contested = [d for d in oracle.get('docs', []) if d.get('tag') == 'contested']
    rows = check_files(root, files, rules) + check_symbols(root, files, rules)
    if want_skeleton:
        rows += skeleton(root, files, oracle.get('docs', []), {r.get('rule', '') for r in oracle.get('rules', [])})
    return settle(rows, rules), rules, how, contested


AL04_FILES, AL04_SHARE = 5, 0.8


def settle(rows, rules):
    """Two passes over the raw rows. (1) A DOC rule that most of its own scope breaks (>= 80% of >= 5 matched files)
    describes a codebase that moved on: its rows become AL-04 advisories (doc stale? P-18), never N rename rows.
    (2) One site broken the same way under several rules (the doc, check-file and ls-lint all saying PascalCase)
    is ONE row; the other rule ids go in the note."""
    by_rule = {r.id: r for r in rules}
    files_by_rule = {}
    for x in rows:
        if x['verdict'] in ('candidate', 'unconfirmed'):
            files_by_rule.setdefault(x['rule'], set()).add(site_file(x['site']))
    stale = set()
    for rid, fs in files_by_rule.items():
        r = by_rule.get(rid)
        if r is not None and r.origin == 'doc' and r.matched >= AL04_FILES and len(fs) >= AL04_SHARE * r.matched:
            stale.add(rid)
            r.stale = (len(fs), r.matched)
    out, seen = [], {}
    for x in rows:
        if x['rule'] in stale and x['verdict'] in ('candidate', 'unconfirmed'):
            k, m = by_rule[x['rule']].stale
            x = dict(x, verdict='advisory', note=('AL-04 candidate: %d/%d files follow the other shape — doc stale? (P-18) %s'
                                                   % (k, m, x.get('note', ''))).strip())
            x['class'] = 'AL-04'
        key = (x['class'], x['site'], str(x['expected']).lower(), x['verdict'])
        if key in seen:
            prev = seen[key]
            prev['note'] = (prev.get('note', '') + ' also ' + x['rule']).strip()
            continue
        seen[key] = x
        out.append(x)
    return out


def parse_file_list(root, data):
    """Root-relative paths from a newline list of root-relative or absolute paths; paths outside root drop."""
    ra = os.path.realpath(root)
    out = []
    for l in data.split('\n'):
        l = l.strip()
        if not l:
            continue
        j = os.path.join(root, l)
        p = os.path.realpath(l) if os.path.isabs(l) else os.path.realpath(j) if os.path.exists(j) else os.path.realpath(l)
        if p.startswith(ra + os.sep):
            out.append(os.path.relpath(p, ra).replace(os.sep, '/'))
    return out


def site_file(site):
    """The file (or directory) a row's site names: `a/b.ts:12` -> `a/b.ts`, `a/dir/` -> `a/dir/`."""
    return re.sub(r':\d+$', '', site)


def main(argv):
    if argv == ['--self-test']:
        return self_test()
    if not argv or argv[0].startswith('-') or not os.path.isdir(argv[0]):
        sys.stderr.write(__doc__.split('\n\n')[2] + '\n'); return 2
    root = argv[0]
    opts, specs = {}, []
    for a in argv[1:]:
        if a.startswith('--rule='):
            specs.append(a[7:])
        elif a.startswith('--') and '=' in a:
            k, v = a[2:].split('=', 1); opts[k] = v
        elif a.startswith('--'):
            opts[a[2:]] = True
        else:
            sys.stderr.write('name-check: unexpected %s\n' % a); return 2
    src = opts.get('files')
    if src is True or src == '':
        sys.stderr.write('name-check: --files needs a value: --files=- (stdin) or --files=<list file>\n'); return 2
    if src:
        try:
            data = sys.stdin.read() if src == '-' else open(src, encoding='utf-8', errors='replace').read()
        except OSError as e:
            sys.stderr.write('name-check: cannot read --files=%s: %s\n' % (src, e)); return 2
        files = parse_file_list(root, data)
        if not files:
            sys.stderr.write('name-check: --files=%s gave 0 paths under %s — NOT RUN (an empty list is not a clean tree)\n' % (src, root))
            return 2
    else:
        files = list_files(root)
    if opts.get('census'):
        print('# concern\tshape\tpath')
        for c, s, f in census(files):
            print('%s\t%s\t%s' % (c, s, f))
        return 0
    rows, rules, how, contested = run(root, files, opts.get('oracle'), specs, bool(opts.get('skeleton')))
    sys.stderr.write('name-check: %d files · oracle: %s · %d naming rules\n' % (len(files), how, len(rules)))
    open_rows = [r for r in rows if r['verdict'] in ('candidate', 'unconfirmed')]
    per_rule = {}
    for x in rows:
        if x['verdict'] in ('candidate', 'unconfirmed', 'advisory'):
            for rid in [x['rule']] + re.findall(r'\balso (N\d+)', x.get('note', '')):
                per_rule.setdefault(rid, set()).add(site_file(x['site']))
    for r in rules:
        if r.matched == 0:
            sys.stderr.write('  rule %s (%s, %s): NOT RUN (vacuous: matched 0 files)\n' % (r.id, r.oracle, r.note or r.desc[:40]))
        else:
            # Candidates are ROWS: one file can carry two (its case and its export name). The distinct-file count
            # is the denominator convention-oracle § 4 (AL-04, stale doc) divides by `matched`, never the row count.
            sys.stderr.write('  rule %s (%s, %s%s%s%s): matched %d %s · %d candidates in %d %s · %d exempt\n' % (
                r.id, r.oracle, r.kind, ' case=' + r.case if r.case else '', ' prefix=' + r.prefix if r.prefix else '',
                ' export' if r.export else '', r.matched, 'dirs' if r.kind == 'dir' else 'files', r.cands,
                len(per_rule.get(r.id, ())), 'dirs' if r.kind == 'dir' else 'files', r.exempt))
            if getattr(r, 'stale', None):
                sys.stderr.write('    -> AL-04 candidate: %d/%d files break this doc rule; its rows are advisories (doc stale? P-18), not renames\n' % r.stale)
    sys.stderr.write('name-check: %d open rows in %d distinct files\n' % (len(open_rows), len({site_file(x['site']) for x in open_rows})))
    for d in contested:
        sys.stderr.write('  contested (AL-02) — skipped: %s %s\n' % (d.get('source'), d.get('quote', '')[:60]))
    shown = [r for r in rows if opts.get('all') or r['verdict'] != 'exempt']
    if opts.get('json'):
        print(json.dumps(shown, indent=1))
    else:
        print('# ' + '\t'.join(COLS))
        for r in shown:
            print('\t'.join(str(r.get(c, '')) for c in COLS))
    return 1 if any(r['verdict'] in ('candidate', 'unconfirmed') for r in rows) else 0


# ---------------------------------------------------------------- self-test
def self_test():
    base = tempfile.mkdtemp(prefix='name-check-', dir=os.environ.get('TMPDIR') or None)
    root = os.path.join(base, 'repo')
    W = {
        'ai/conventions.md': '# Conventions\n\n## Files and naming\n\n- Component files are PascalCase and match the exported component name exactly.\n'
                             '- Hook files are camelCase and start with `use`: `useOrders.ts`.\n- Non-component modules under `src/lib/` are kebab-case.\n'
                             '- Booleans start with `is` or `has`.\n- Tests are co-located with the code they test.\n'
                             '- Each feature module exposes an `index.ts` under `src/features/<name>/`.\n'
                             '<!-- refine-enriched:start -->\n- Store files end in `.store.ts`.\n<!-- refine-enriched:end -->\n',
        'ai/modules.md': '# Modules\n\n## `src/`\n\n| module | path |\n|---|---|\n| orders | `features/orders/` |\n| ghosts | `features/ghosts/` |\n',
        '.ls-lint.yml': 'ls:\n  src/features:\n    .dir: kebab-case\n',
        'src/components/ShipmentsToolbar.tsx': 'export function ShipmentsToolbar() { return null }\n',
        'src/components/invoicelist.tsx': "import x from 'y'\n\nexport function InvoiceList() {\n  const loading = true;\n  const isOpen = false;\n  return null }\n",
        'src/components/Row.tsx': 'export const Rows = () => null\n',
        'src/hooks/useOrders.ts': 'export function useOrders() {}\n',
        'src/hooks/fetch-orders.ts': 'export function useFetch() {}\n',
        'src/lib/api-client.ts': 'export const a = 1\n',
        'src/lib/i18nHelpers.ts': 'export const b = 1\n',
        'src/features/orders/index.ts': 'export {}\n',
        'src/features/OrderHistory/index.ts': 'export {}\n',
        'src/features/refunds/api.ts': 'export {}\n',
        'src/features/refunds/__tests__/api.test.ts': 'test("x", () => {})\n',
        'src/stores/basket-store.ts': 'export {}\n',
        'app/[locale]/(shop)/page.tsx': 'export default function Page() {}\n',
        'src/components/app/layout.tsx': 'export default function L() {}\n',
        'api/orders/orders.module.ts': 'export class OrdersModule {}\n',
        'api/orders/dto/create-shipment.dto.ts': "export class CreateShipmentDto {\n  @Expose({ name: 'created_at' })\n  created_at: string;\n}\n",
        'svc/app/migrations/0003_auto_20240101.py': 'x = 1\n',
        'svc/app/summary.py': 'def BuildDigest():\n    pass\n\nclass digest_row:\n    pass\n',
        'svc/pyproject.toml': '[tool.ruff.lint]\nselect = ["N"]\n',
    }
    for f, c in W.items():
        p = os.path.join(root, f)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w') as fh:
            fh.write(c)
    bad, tot = [], [0]

    def check(name, cond):
        tot[0] += 1
        if not cond:
            bad.append(name)
    try:
        files = list_files(root)
        rows, rules, how, contested = run(root, files, None, ['api/**/*.ts=pascal'], True)
        S = {}
        for r in rows:
            S.setdefault(r['site'].split(':')[0], []).append(r)
        def has(site, verdict='candidate', expected=None):
            return any(r['verdict'] == verdict and (expected is None or expected in str(r['expected'])) for r in S.get(site, []))
        check('oracle built from sibling oracle-map.py', 'built in memory' in how)
        check('invoicelist.tsx not PascalCase', has('src/components/invoicelist.tsx', expected='pascal'))
        check('invoicelist export mismatch cites the export line', any(r['site'] == 'src/components/invoicelist.tsx:3' for r in rows))
        check('Row.tsx exports Rows -> export mismatch', has('src/components/Row.tsx', expected='stem == export'))
        check('ShipmentsToolbar clean', not has('src/components/ShipmentsToolbar.tsx'))
        check('hook without use prefix (fetch-orders.ts)', has('src/hooks/fetch-orders.ts', expected='prefix use'))
        check('useOrders clean', not has('src/hooks/useOrders.ts'))
        check('lib camel file vs kebab', has('src/lib/i18nHelpers.ts', expected='kebab'))
        check('lib kebab clean', not has('src/lib/api-client.ts'))
        check('ls-lint dir rule OrderHistory', has('src/features/OrderHistory/', expected='kebab'))
        check('generated store rule -> unconfirmed', has('src/stores/basket-store.ts', verdict='unconfirmed'))
        check('Next route files exempt', not has('app/[locale]/(shop)/page.tsx') and not has('src/components/app/layout.tsx'))
        check('Nest role file exempt from pascal rule (kebab stem)', has('api/orders/orders.module.ts', verdict='exempt'))
        check('dto with kebab stem exempt', has('api/orders/dto/create-shipment.dto.ts', verdict='exempt'))
        check('Django migration exempt', not has('svc/app/migrations/0003_auto_20240101.py'))
        check('ruff N: def BuildDigest', any(r['site'] == 'svc/app/summary.py:1' and r['class'] == 'AL-17' for r in rows))
        check('ruff N: class digest_row', any(r['site'] == 'svc/app/summary.py:4' and r['class'] == 'AL-17' for r in rows))
        check('boolean prefix: loading flagged, isOpen clean', any(r['site'] == 'src/components/invoicelist.tsx:4' for r in rows)
              and not any(r['site'] == 'src/components/invoicelist.tsx:5' for r in rows))
        check('wire name (@Expose) not an AL-17 row', not any(r['site'].startswith('api/orders/dto/') and r['class'] == 'AL-17' for r in rows))
        check('co-location: __tests__ flagged', has('src/features/refunds/__tests__/api.test.ts'))
        check('barrel missing for refunds', has('src/features/refunds/'))
        check('skeleton: ghosts module absent (heading-relative form)', any(r['rule'] == 'skeleton' and 'features/ghosts' in r['actual'] for r in rows)
              and not any(r['rule'] == 'skeleton' and 'features/orders/ ' in r['actual'] for r in rows))
        # IR-8 (measured 2026-10-18 on a real monorepo): a section-rooted heading `## web (`src/`)`, table cells with no
        # trailing slash, a file stem cited as a module, and a lint rule id that only looks like a path
        arch = os.path.join(root, 'ai/architecture.md')
        with open(arch, 'w') as fh:
            fh.write('# Architecture\n\n## web (`src/`)\n\n### Slices\n\n| slice | path |\n|---|---|\n| orders | `features/orders` |\n'
                     '| phantom | `features/phantom` |\n\nHelpers live in `lib/i18nHelpers`; the wall is `acme/no-legacy`.\n\n## Other\n\n'
                     'Nothing under `features/refunds` here.\n')
        sk = skeleton(root, sorted(W) + ['ai/architecture.md'], [], {'acme/no-legacy'})
        got = sorted(r['actual'] for r in sk if r['rule'] == 'skeleton' and r['site'].startswith('ai/architecture.md'))
        check('skeleton IR-8: slashless cell under a section-rooted heading is checked; stems, existing dirs and rule ids are not rows',
              got == ['features/phantom/ absent'])
        os.remove(arch)
        vac = [r for r in rules if r.matched == 0]
        check('every rule matched files (no vacuous rule in the fixture)', not [r for r in vac if r.note != 'doc-boolean'])
        cen = census(files)
        check('census emits hook-file-case', any(c == 'hook-file-case' for c, _, _ in cen))
        check('case_of', case_of('InvoiceList') == 'pascal' and case_of('orders') == 'flat' and case_of('use-orders') == 'kebab'
              and case_of('useOrders') == 'camel' and case_of('get_report') == 'snake')
        check('stem_of strips role suffix', stem_of('orders.controller.ts') == 'orders' and stem_of('Button.stories.tsx') == 'Button')
        # Regressions measured on benchmarks/fixtures/convention-drift (2026-10-18): 74 rows, 11 true, before these fixes.
        dr, _ = doc_rules([{'quote': 'Component files under `src/app/` are PascalCase.', 'tag': 'written', 'source': 'c.md:1'}], 0)
        check('doc rule under <dir> keeps its subject (a .ts module is not a component)',
              len(dr) == 1 and dr[0].scope('src/app/Foo.tsx') and not dr[0].scope('src/app/lib/api.ts') and not dr[0].scope('lib/Foo.tsx'))
        dc, _ = doc_rules([{'quote': 'Hook files are camelCase.', 'tag': 'contested', 'source': 'c.md:2'}], 0)
        check('a contested doc row makes no naming rule (AL-02, not AL-16)', dc == [])
        lr, _ = config_rules([{'tool': 'ls-lint', 'rule': 'src .ts', 'options': 'camelCase | kebab-case', 'tag': 'enforced',
                               'source': '.ls-lint.yml:3'}], 0)
        check('ls-lint `camelCase | kebab-case` is an alternative', len(lr) == 1 and lr[0].case == 'camel|kebab'
              and not check_files(root, ['src/use-cart.ts', 'src/useCart.ts'], lr) and check_files(root, ['src/Cart_x.ts'], lr))
        fr, _ = config_rules([{'tool': 'eslint', 'rule': 'check-file/folder-naming-convention', 'options': '[{"src/features/*/": "KEBAB_CASE"}]',
                               'tag': 'enforced', 'source': 'eslint.config.mjs:5'}], 0)
        frows = check_files(root, ['src/features/OrderHistory/index.ts', 'src/features/orders/index.ts'], fr)
        check('check-file folder glob `features/*/` matches directories', len(fr) == 1 and fr[0].matched == 2
              and [x['site'] for x in frows] == ['src/features/OrderHistory/'])
        sr, _ = doc_rules([{'quote': 'Store files end in `.store.ts`.', 'tag': 'written', 'source': 'c.md:3'}], 0)
        sf = ['src/stores/%s-store.ts' % x for x in ('a', 'b', 'c', 'd', 'e')]
        settled = settle(check_files(root, sf, sr), sr)
        check('a doc rule 5/5 files break -> AL-04 advisories, not renames', len(settled) == 5
              and all(x['class'] == 'AL-04' and x['verdict'] == 'advisory' for x in settled))
        d1, _ = doc_rules([{'quote': 'Component files under `src/` are PascalCase.', 'tag': 'written', 'source': 'c.md:4'}], 0)
        d2, _ = config_rules([{'tool': 'ls-lint', 'rule': 'src .tsx', 'options': 'PascalCase', 'tag': 'enforced', 'source': '.ls-lint.yml:5'}], 1)
        both = d1 + d2
        dd = settle(check_files(root, ['src/itemRow.tsx', 'src/A.tsx', 'src/B.tsx', 'src/C.tsx', 'src/D.tsx'], both), both)
        check('one site broken under two rules is one row', len(dd) == 1 and 'also N2' in dd[0]['note'])
        import subprocess
        me = os.path.abspath(__file__)
        # An open stdin that never closes (an agent shell): without --files the run must walk the root, not block.
        pr = subprocess.Popen([sys.executable, '-I', me, root, '--census'], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE)
        try:
            pr.wait(timeout=30)                       # the census of this fixture fits the pipe buffer
            out = pr.stdout.read()
            check('no --files: stdin never read (an open pipe does not hang)', pr.returncode == 0 and b'hook-file-case' in out)
        except subprocess.TimeoutExpired:
            pr.kill()
            check('no --files: stdin never read (an open pipe does not hang)', False)
        finally:
            if pr.stdin:
                pr.stdin.close()
        rp = subprocess.run([sys.executable, '-I', me, root, '--files=-', '--rule=src/components/*.tsx=pascal'],
                            input=b'src/components/invoicelist.tsx\nsrc/components/ShipmentsToolbar.tsx\n', stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=60)
        err = rp.stderr.decode()
        check('--files=- reads exactly the piped list', 'name-check: 2 files' in err)
        check('distinct-file count printed per rule and in total', ' in 1 files' in err and 'distinct files' in err)
        re_ = subprocess.run([sys.executable, '-I', me, root, '--files=-'], input=b'', stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, timeout=60)
        check('--files=- with an empty list is NOT RUN (exit 2), never a clean tree', re_.returncode == 2 and b'NOT RUN' in re_.stderr)
    finally:
        shutil.rmtree(base, ignore_errors=True)
    for b in bad:
        sys.stderr.write('  FAIL %s\n' % b)
    print('name-check --self-test: %d/%d %s' % (tot[0] - len(bad), tot[0], 'OK' if not bad else 'FAIL'))
    return 0 if not bad else 3


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
