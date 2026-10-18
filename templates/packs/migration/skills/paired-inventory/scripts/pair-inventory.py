#!/usr/bin/env python3
"""pair-inventory.py — paired-inventory engine of the migration pack: one lane schema, two extractors, one diff.

A migration class is a difference ("V1 does X here, V2 does Y"). Every static lane is extracted from both
roots into the same normalised schema, then set-diffed into CANDIDATE rows (never findings: the
refute-before-report protocol decides each one). The lane modules beside this file hold the extractors:
lanes_laravel.py (V1 Laravel), lanes_node.py (NestJS via the backend pack's dto-types.py, zod, MikroORM),
lanes_supabase.py (V1 Supabase: SQL migrations replayed, RLS, PostgREST RPC, pg_cron, Deno edge functions),
lanes_ruby.py, lanes_python.py, lanes_java.py, lanes_js.py, lanes_go.py (Rails, Django + FastAPI, Spring, Express/Fastify, Go — tagged
`partial`; shared readers in lanes_common.py).

Usage:
  python3 -I pair-inventory.py --v1=<root> --v2=<root> [--pin=<sha|ref>] [--live-v1] [common]   # paired
  python3 -I pair-inventory.py --v2=<root> --v1-inventory=<dir> [--pin=<sha>] [common]          # solo
  python3 -I pair-inventory.py --record-v1 --v1=<root> --pin=<sha|ref> --out=<dir> [--live-v1]   # record
  python3 -I pair-inventory.py --calibrate --v1=<root> --v2=<root> [--live-v1] [common]          # calibrate
  python3 -I pair-inventory.py --list-lanes | --self-test
common: --lanes=I-ROUTES,... --stack-v1=laravel --stack-v2=nest --pair-map=<tsv> --ledger=<file>
        --out=<dir> --calibration-pair=<v1dir>,<v2dir> --no-builtin-calibration --all
Modes:
  paired   V1 is read from a write-free `git archive <pin>:<subdir>` snapshot extracted under --out (immune to a
           moving checkout). --live-v1 reads the V1 directory in place instead (no git, or an uncommitted
           fixture): printed as `snapshot=live`, and the verdict ceiling drops to GO-UNVERIFIED.
  solo     V2 + the recorded V1 inventory. Freshness, per lane: sha must equal the pin (--pin, else the
           ledger's v1_commit_pinned) or every row is tagged stale-v1-inventory; the extractor hash must equal
           the installed lane module's hash or the lane is blocked; a lane with no record is blocked.
  record   writes <out>/<lane>.tsv (header: sha, root, stack, extractor hash, normaliser, rows). Never into V1.
  calibrate  a known-parity pair must diff to 0 rows per lane; a lane with k > 0 prints
           `blocked (lane <x> asymmetric: k rows on the calibration pair)`. Paired mode runs the built-in
           Laravel->Nest and Supabase->Nest pairs (and --calibration-pair) first and blocks every lane that fails
           one; a stack pair with no calibration pair is tagged `uncalibrated`.
Pair map (<v2>/ai/migration/pair-map.tsv by default; read-only): `lane<TAB>v1-key<TAB>v2-key<TAB>reason`.
  v2-key `-` = intentionally gone; `prefix:/api<TAB>prefix:/v1` rewrites V1 route prefixes in every lane;
  `value:a.b<TAB>value:a:b` maps an attribute vocabulary. A row with no reason is ignored and printed.
  v1-key `-` acknowledges a V2-only key (`lane<TAB>-<TAB><v2-key><TAB>reason`; an I-ROUTES row also covers that
  route's AUTHZ/RULES/SIDE rows). `lane<TAB>key<TAB>key<TAB>ADR-NNN …<TAB>attr=value` accepts exactly that one V2
  attribute value (a further drift still shows; no ADR → ignored). `*` in a key matches any run of characters.
  Every closed row is listed in ledger.txt under `pair-map:` with its reason.
Output: candidates TSV on stdout (`# CANDIDATE` header) and <out>/{v1,v2}/<lane>.tsv, <out>/candidates.tsv;
        the ledger on stderr (stacks, rows per lane per side, rg calls and exit codes, unparsed, writes).
Exit:   0 ran, no candidates · 1 candidates · 2 usage · 3 self-test failed · 4 a requested lane is blocked.
Writes: only under --out (default: a fresh ${TMPDIR} folder) and, with --record-v1, the named --out. Both
        trees are checked for files newer than the run start before exit. Stdlib only; `python3 -I` safe.
"""
import argparse, hashlib, importlib.util, json, os, re, shutil, subprocess, sys, tarfile, tempfile, time

sys.dont_write_bytecode = True          # importing the lane modules must not drop __pycache__ into a repo
HERE = os.path.dirname(os.path.abspath(__file__))
FORMAT, NORMALISER = '1', '1'
MODULES = ('lanes_laravel', 'lanes_node', 'lanes_ruby', 'lanes_python', 'lanes_java', 'lanes_js', 'lanes_go', 'lanes_supabase')
LANES = ['I-ROUTES', 'I-AUTHZ', 'I-RULES', 'I-ENUM', 'I-ERR', 'I-SIDE', 'I-SCHED', 'I-SCOPE', 'I-SCHEMA',
         'I-MONEY', 'I-CONF']
COMPARE = {'I-ROUTES': ('opt', 'constraint'), 'I-AUTHZ': ('authn', 'abilities', 'roles', 'extra_guard'),
           'I-RULES': ('presence', 'nullable', 'type', 'format', 'max', 'min', 'in', 'regex', 'on'),
           'I-ENUM': ('values',), 'I-ERR': ('status',), 'I-SIDE': ('kinds',), 'I-SCHED': ('cron', 'tz', 'overlap'),
           'I-SCOPE': ('soft_delete', 'tenant'), 'I-SCHEMA': ('null', 'numeric', 'ref', 'on_delete'), 'I-MONEY': ('modes',), 'I-CONF': ('value',)}
ROUTE_KEYED = ('I-ROUTES', 'I-AUTHZ', 'I-RULES')
V1_ONLY_ATTR = {'I-ROUTES': ('constraint',)}   # a V2-only param constraint narrows; a lost V1 one widens
V1_GUARD = {('I-SCHEMA', 'null'): 'no'}         # compared only when V1 holds the guarantee (NOT NULL lost)
FUZZY = ('I-SCHED', 'I-MONEY')
ROUTE_RE = re.compile(r'^(GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD|ANY) (/\S*)(.*)$')
EXCLUDE = ['!**/{node_modules,vendor,dist,build,target,.venv,venv,coverage,.next,.nuxt,out,storage,tmp}/**',
           '!**/bootstrap/cache/**',
           '!**/{test,tests,spec,specs,__tests__,__mocks__,mocks,fixtures,__fixtures__,testdata,e2e,cypress}/**',
           '!**/*{.,_,-}{test,spec,e2e-spec}.*', '!**/test_*.py', '!**/*_test.go', '!**/*.test-data.*',
           '!**/*.fixture.*', '!**/*.fixtures.*', '!**/{lang,locales,i18n,translations}/**',
           '!**/resources/lang/**', '!**/database/{seeders,factories}/**', '!**/{docs,doc}/**', '!**/*.min.*',
           '!**/*.d.ts']
MIGRATIONS = '!**/{migrations,migrate,db/migrate,database/migrations}/**'
SM_PATHS = [os.path.join(HERE, '..', '..', 'index-coverage-scan', 'scripts', 'schema-map.py'),
            os.path.join(HERE, '..', '..', '..', '..', 'database', 'skills', 'index-coverage-scan', 'scripts', 'schema-map.py')]


class Blocked(Exception):
    pass


class Usage(Exception):
    pass


def tsv(s):
    return re.sub(r'[\t\r\n]+', ' ', str(s)).strip()


def enc(v):
    return str(v).replace('%', '%25').replace(';', '%3B').replace('=', '%3D').replace('\t', ' ').replace('\n', ' ')


def dec(v):
    return v.replace('%3D', '=').replace('%3B', ';').replace('%25', '%')


def attrs_str(a):
    return ';'.join('%s=%s' % (k, enc(a[k])) for k in sorted(a))


def attrs_parse(s):
    out = {}
    for part in (s.split(';') if s and s != '-' else []):
        k, _, v = part.partition('=')
        out[k] = dec(v)
    return out


def setv(vals):
    """A set attribute: sorted, unique, comma-joined (empty string = the empty set, never 'unread')."""
    return ','.join(sorted(set(v for v in vals if v != '')))


# ---------------------------------------------------------------- helpers handed to every lane module
class H(object):
    """Shared readers. Every lane gets one per (side, root): rg file listing, masking, brace matching."""
    Blocked = Blocked
    EXCLUDE = EXCLUDE
    MIGRATIONS = MIGRATIONS
    SCHED_DROP = ('job', 'jobs', 'command', 'commands', 'task', 'tasks', 'cron', 'run', 'handle', 'handler', 'schedule',
                  'scheduled', 'scheduler', 'worker', 'send', 'process', 'execute', 'perform', 'trigger', 'dispatch', 'do')
    ROLE_WORDS = ('service', 'controller', 'helper', 'util', 'support', 'calculator', 'calc', 'module', 'repository',
                  'repo', 'use', 'case', 'handler', 'manager', 'provider', 'processor', 'job', 'command', 'mapper', 'app',
                  'common', 'lib', 'model', 'models', 'src', 'index')

    @classmethod
    def area(cls, name, rel, fn=''):
        """I-MONEY key: the domain noun of a money path — `InvoiceService` -> invoice, `invoice-totals.ts` -> invoice,
        `Money.php` -> money. Tried in order: the class name, the file's basename, its folder, the function name;
        role words (service, controller, helper, handler, job, ...) and one-letter words are skipped."""
        srcs = [name if name and not name.startswith('<') else '', os.path.splitext(os.path.basename(rel))[0],
                os.path.basename(os.path.dirname(rel)), fn]
        for src in srcs:
            for w in cls.words(src):
                w = singular(w)
                if len(w) > 1 and w not in cls.ROLE_WORDS:
                    return 'area:' + w
        return 'area:root'

    def __init__(self, root, side):
        self.root, self.side = os.path.abspath(root), side
        self._text, self._mask = {}, {}
        self.rg_calls, self.rg_errors, self.notes, self.unparsed = 0, [], [], []

    def files(self, includes, pattern=None, excludes=(), keep=()):
        """rg --files (or -l <pattern>) from the root, path `.`; includes first, exclusions last.
        `keep` drops default exclusions that contain any of the given words (e.g. 'migrations').
        Exit 2 raises Blocked: a failed listing is never zero files."""
        if not shutil.which('rg'):
            raise Blocked('rg not installed')
        ex = [e for e in EXCLUDE if not any(k in e for k in keep)] + list(excludes)
        cmd = ['rg', '--no-ignore', '--no-config']
        cmd += ['-l'] if pattern else ['--files']
        for g in includes:
            cmd += ['-g', g]
        for g in ex:
            cmd += ['-g', g]
        if pattern:
            cmd += ['-e', pattern]
        cmd += ['--', '.']
        self.rg_calls += 1
        p = subprocess.run(cmd, cwd=self.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if p.returncode == 2:
            msg = p.stderr.decode('utf-8', 'replace').strip().splitlines()
            self.rg_errors.append(' '.join(cmd[-6:]) + ' -> ' + (msg[0] if msg else 'exit 2'))
            raise Blocked('rg exit 2 (%s)' % (msg[0] if msg else 'no message'))
        if p.returncode not in (0, 1):
            raise Blocked('rg exit %d' % p.returncode)
        out = [l[2:] if l.startswith('./') else l for l in p.stdout.decode('utf-8', 'replace').splitlines() if l]
        return sorted(set(out))

    def schema_map(self, lane=None):
        """I-SCHEMA rows from the database pack's schema-map.py (called, never copied): `col:<table>.<column>`
        (null, numeric(p,s)), `unique:<table>(<cols>)`, `fk:<table>(<cols>)` (ref, on_delete)."""
        path = os.environ.get('PAIR_INVENTORY_SCHEMA_MAP') or next((p for p in SM_PATHS if os.path.isfile(p)), None)
        if not path:
            raise Blocked('schema-map NOT-RUN (database pack index-coverage-scan schema-map.py absent)')
        cmd = [sys.executable, '-I', '-B', path, '.'] + (['--lane=' + lane] if lane else [])
        p = subprocess.run(cmd, cwd=self.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           env=dict(os.environ, GIT_OPTIONAL_LOCKS='0'))
        if p.returncode != 0:
            raise Blocked('schema-map exit %d: %s' % (p.returncode, p.stderr.decode('utf-8', 'replace').strip()[-160:]))
        sql = p.stdout.decode('utf-8', 'replace')
        head = [l[3:] for l in sql.splitlines() if l.startswith('-- schema-map lane=')]
        self.notes.append('schema-map (%s): %s' % (self.side, head[0][:140] if head else 'no lane line'))
        rows, src = [], ('-', 0)
        q = r'"([^"]+)"'

        def col(t, c, d, at, line):
            num = re.search(r'\bnumeric\((\d+),\s*(\d+)\)', d)
            rows.append({'key': 'col:%s.%s' % (self.table(t), c), 'attrs': {
                'null': 'no' if re.search(r'\bnot null\b|\bprimary key\b|\bserial\b', d) else 'yes',
                'numeric': '%s,%s' % num.groups() if num else '',
                'type': re.split(r' not null| null| default| primary| references| unique', d)[0].strip()},
                'at': at, 'excerpt': tsv(line)[:120]})
            if re.search(r'\bunique\b', d):
                rows.append({'key': 'unique:%s(%s)' % (self.table(t), c), 'attrs': {'where': ''}, 'at': at, 'excerpt': tsv(line)[:120]})
            rm = re.search(r'\breferences %s(?: \([^)]*\))?(.*)' % q, d)
            if rm:
                fk(t, c, rm.group(1), rm.group(2), at, line)

        def fk(t, cols, ref, rest, at, line):
            od = re.search(r'on delete (cascade|set null|restrict|no action|set default)', rest)
            rows.append({'key': 'fk:%s(%s)' % (self.table(t), ','.join(x.strip().strip('"') for x in cols.split(','))),
                         'attrs': {'ref': self.table(ref), 'on_delete': od.group(1) if od else ''}, 'at': at,
                         'excerpt': tsv(line)[:120]})

        def uniq(t, cols, extra, at, line):
            cols = ','.join(sorted(x.strip().strip('"') for x in cols.split(',')))
            rows.append({'key': 'unique:%s(%s)' % (self.table(t), cols), 'attrs': {'where': tsv(extra.strip())[:60]},
                         'at': at, 'excerpt': tsv(line)[:120]})
        n = 0
        for line in sql.splitlines():
            n += 1
            m = re.match(r'-- @src (.+):(\d+)$', line)
            if m:
                src, n = (m.group(1), int(m.group(2))), -1
                continue
            at = '%s:%d' % (src[0], src[1] + max(n, 0))
            low = line.replace("\\'", "'")
            for cm in re.finditer(r'alter table %s add column %s ([^;]+?)\s*;' % (q, q), low):
                col(cm.group(1), cm.group(2), cm.group(3), at, line)
            for um in re.finditer(r'alter table %s add constraint %s unique \(([^)]*)\)' % (q, q), low):
                uniq(um.group(1), um.group(3), '', at, line)
            for um in re.finditer(r'create unique index (?:if not exists )?%s on %s \(([^)]*)\)([^;]*);' % (q, q), low):
                uniq(um.group(2), um.group(3), um.group(4), at, line)
            for fm in re.finditer(r'alter table %s add constraint %s foreign key \(([^)]*)\) references %s \(([^)]*)\)([^;]*);' % (q, q, q), low):
                fk(fm.group(1), fm.group(3), fm.group(4), fm.group(6), at, line)
            for tm in re.finditer(r'create table (?:if not exists )?%s \((.*)\)\s*;' % q, low):
                parts, depth, cur = [], 0, ''
                for ch in tm.group(2):
                    depth += (ch == '(') - (ch == ')')
                    if ch == ',' and depth == 0:
                        parts.append(cur.strip())
                        cur = ''
                    else:
                        cur += ch
                parts.append(cur.strip())
                for part in parts:
                    pm = re.match(r'(?:constraint %s )?unique \(([^)]*)\)' % q, part)
                    fm = re.match(r'(?:constraint %s )?foreign key \(([^)]*)\) references %s(?: \([^)]*\))?(.*)' % (q, q), part)
                    cm = re.match(r'%s (.+)$' % q, part)
                    if pm:
                        uniq(tm.group(1), pm.group(2), '', at, line)
                    elif fm:
                        fk(tm.group(1), fm.group(2), fm.group(3), fm.group(4), at, line)
                    elif cm and not re.match(r'(?:constraint|primary key|check)\b', part):
                        col(tm.group(1), cm.group(1), cm.group(2), at, line)
        return rows

    def db_objects(self):
        """Views and triggers declared in migrations or .sql files (any stack): `views` [(name, rel, i)];
        `derived` [(table, column, how, rel, i)] for a column a trigger maintains (`UPDATE orders SET line_count =`,
        `SET NEW.total =`); `effects` [(table, event, kind, rel, i)] for a trigger that inserts into an audit /
        activity / outbox table. A trigger that runs a function is read through that function's body."""
        if hasattr(self, '_dbo'):
            return self._dbo
        rx = r'(?i)create\s+(?:or\s+replace\s+)?(?:trigger|view|function)\b'
        files = self.files(['**/{migrations,migrate,database/migrations,db}/**', '*.sql'], pattern=rx, keep=('migrations',))
        texts = dict((rel, self.read(rel)) for rel in files)
        funcs = {}
        for rel, t in texts.items():
            for fm in re.finditer(r'(?is)create\s+(?:or\s+replace\s+)?function\s+(\w+)\s*\(.*?\$\$(.*?)\$\$', t):
                funcs[fm.group(1).lower()] = fm.group(2)
        views, derived, effects = [], [], []
        ev = {'insert': 'created', 'update': 'updated', 'delete': 'deleted'}
        q = r'[`"]?(\w+)[`"]?'
        for rel, t in texts.items():
            for vm in re.finditer(r'(?i)create\s+(?:or\s+replace\s+)?(?:materialized\s+)?view\s+(?:if\s+not\s+exists\s+)?' + q, t):
                views.append((vm.group(1).lower(), rel, vm.start()))
            for tm in re.finditer(r'(?is)create\s+trigger\s+' + q + r'\s+(?:before|after)\s+(insert|update|delete)(?:\s+or\s+\w+)*\s+on\s+' + q + r'(.{0,800}?)(?:;|\n\s*SQL\b|$)', t):
                table, event, bodyt = tm.group(3).lower(), tm.group(2).lower(), tm.group(4)
                fx = re.search(r'(?i)execute\s+(?:function|procedure)\s+(\w+)\s*\(', bodyt)
                if fx:
                    bodyt += ' ' + funcs.get(fx.group(1).lower(), '')
                for um in re.finditer(r'(?i)\bupdate\s+' + q + r'\s+set\s+' + q + r'\s*=', bodyt):
                    derived.append((um.group(1).lower(), um.group(2).lower(), 'trigger', rel, tm.start()))
                for um in re.finditer(r'(?i)\bset\s+new\.' + q + r'\s*=', bodyt):
                    derived.append((table, um.group(1).lower(), 'trigger', rel, tm.start()))
                for im in re.finditer(r'(?i)\binsert\s+into\s+' + q, bodyt):
                    tgt = im.group(1).lower()
                    kind = 'audit' if 'audit' in tgt else 'activity' if re.search(r'activit|history|_log', tgt) else 'event' if 'outbox' in tgt else None
                    if kind:
                        effects.append((table, ev[event], kind, rel, tm.start()))
        self._dbo = {'views': views, 'derived': derived, 'effects': effects, 'texts': texts}
        return self._dbo

    def schema_extra(self):
        """I-SCHEMA rows beyond schema-map: `view:<name>` and `derived:<table>.<column>` (presence is the parity)."""
        d, rows = self.db_objects(), []
        for name, rel, i in d['views']:
            rows.append(self.row('view:' + name, {'how': 'view'}, rel, d['texts'][rel], i))
        for table, col, how, rel, i in d['derived']:
            rows.append(self.row('derived:%s.%s' % (self.table(table), col), {'how': how}, rel, d['texts'][rel], i))
        return rows

    def exists(self, rel):
        return os.path.isfile(os.path.join(self.root, rel))

    def read(self, rel):
        if rel not in self._text:
            try:
                with open(os.path.join(self.root, rel), 'rb') as f:
                    self._text[rel] = f.read(4000000).decode('utf-8', 'replace')
            except (IOError, OSError):
                self._text[rel] = ''
        return self._text[rel]

    def masked(self, rel, lang):
        """(masked, string spans). Comments and string bodies become spaces; quotes and newlines stay, so an
        index in the masked text is the same index in the original."""
        k = (rel, lang)
        if k not in self._mask:
            self._mask[k] = mask(self.read(rel), lang)
        return self._mask[k]

    @staticmethod
    def close(m, i):
        return close(m, i)

    @staticmethod
    def mask_text(text, lang):
        return mask(text, lang)

    @staticmethod
    def cron(expr):
        return cron(expr)

    @staticmethod
    def line(text, i):
        return text.count('\n', 0, i) + 1

    @staticmethod
    def excerpt(text, i):
        a = text.rfind('\n', 0, i) + 1
        b = text.find('\n', i)
        return tsv(text[a:b if b >= 0 else len(text)])[:120]

    def at(self, rel, text, i):
        return '%s:%d' % (rel, self.line(text, i))

    @staticmethod
    def lits(text, spans, a, b):
        return [text[s + 1:e - 1] for s, e in spans if s >= a and e <= b]

    @staticmethod
    def words(name):
        s = re.sub(r'([a-z0-9])([A-Z])', r'\1 \2', re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1 \2', name or ''))
        return [w for w in re.split(r'[^A-Za-z0-9]+', s.lower()) if w]

    @classmethod
    def tokkey(cls, name, drop=()):
        """Order-free word key: `invoices:generate` == `generateInvoices` == `GenerateInvoicesJob`."""
        ws = sorted(set(singular(w) for w in cls.words(name) if w not in drop))
        return '.'.join(ws)

    @classmethod
    def ident(cls, name, strip=()):
        w = cls.words(name)
        while w and w[-1] in strip:
            w = w[:-1]
        return ''.join(w)

    @staticmethod
    def ability(s):
        return re.sub(r'[._:\-/ ]+', '.', (s or '').strip().lower()).strip('.')

    @staticmethod
    def norm_path(p):
        return norm_path(p)

    @staticmethod
    def table(name):
        return singular(re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', name or '').lower().split('.')[-1])

    def row(self, key, attrs, rel, text, i):
        return {'key': key, 'attrs': attrs, 'at': self.at(rel, text, i) if rel else '-',
                'excerpt': self.excerpt(text, i) if text else '-'}

    def unparse(self, lane, rel, text, i, why):
        self.unparsed.append('%s %s %s (%s)' % (lane, self.at(rel, text, i), self.excerpt(text, i)[:60], why))


def singular(w):
    if len(w) > 4 and w.endswith('ies'):
        return w[:-3] + 'y'
    if len(w) > 4 and re.search(r'(ss|x|ch|sh)es$', w):
        return w[:-2]
    if len(w) > 3 and w.endswith('s') and not w.endswith(('ss', 'us', 'is')):
        return w[:-1]
    return w


CRON_LIM = [(0, 59), (0, 23), (1, 31), (1, 12), (0, 7)]
DOW = dict((d, str(i)) for i, d in enumerate(('sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat')))
MON = dict((m, str(i + 1)) for i, m in enumerate(('jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct',
                                                   'nov', 'dec')))


def cron(expr):
    """Canonical cron: a 6-field expression with second 0 drops it; steps over a full range become explicit lists
    (`*/30` == `0,30`), `0-23/1` == `*`, leading zeros go, Sunday 7 == 0. Unreadable -> '?'."""
    f = (expr or '').lower().split()
    sec = None
    if len(f) == 6:
        sec, f = f[0], f[1:]
        if sec in ('0', '00'):
            sec = None
    if len(f) != 5:
        return '?'
    out = []
    for i, (x, (lo, hi)) in enumerate(zip(f, CRON_LIM)):
        for k, v in (DOW if i == 4 else MON if i == 3 else {}).items():
            x = re.sub(r'\b%s\b' % k, v, x)
        x = re.sub(r'\b0+(\d)', r'\1', x)
        m = re.match(r'^(?:\*|%d-%d)(?:/(\d+))?$' % (lo, hi if i != 4 else 6), x) or (i == 4 and re.match(r'^0-7(?:/(\d+))?$', x))
        if m:
            step = int(m.group(1) or 1)
            x = '*' if step == 1 else ','.join(str(v) for v in range(lo, (hi if i != 4 else 6) + 1, step))
        if i == 4:
            x = ','.join(sorted(set('0' if p == '7' else p for p in x.split(',')), key=lambda p: (len(p), p)))
        out.append(x)
    return ((sec + ' ') if sec else '') + ' '.join(out)


def norm_path(p):
    """`/orders/{order?}/`, `orders/:id`, `<int:pk>`, `(?P<id>\\d+)` -> `/orders/{}`; returns (path, opt count)."""
    p = re.sub(r'\{\*\w*\}', '\x00', (p or '').strip())   # {*}, {*splat} -> one wildcard token
    opt = len(re.findall(r'\{\w+\?\}|:\w+\?', p))
    p = re.sub(r'\(\?P<\w+>[^)]*\)', '{}', p)
    p = re.sub(r'<(?:\w+:)?\w+>', '{}', p)
    p = re.sub(r'\{\*?\w*(?::[^}]*)?\??\}', '{}', p)
    p = re.sub(r'(?<=/):\w+\??(?:\([^)]*\))?', '{}', '/' + p.lstrip('/'))
    p = re.sub(r'(?<=/)\*\w*', '{*}', p)
    p = re.sub(r'\(\.:format\)|\.:format', '', p)
    p = re.sub(r'[$^]', '', p)
    p = re.sub(r'/+', '/', p.replace('\x00', '{*}')).rstrip('/').lower() or '/'
    return p, opt


def mask(text, lang):
    """Blank comments and string bodies (quotes and newlines kept). lang: c (JS/TS/Java/Go), php, py, rb."""
    out, spans, i, n = list(text), [], 0, len(text)
    hashc = lang in ('php', 'py', 'rb')
    slash = lang in ('c', 'php')

    def blank(a, b):
        for j in range(a, b):
            if out[j] != '\n':
                out[j] = ' '
    while i < n:
        c = text[i]
        if slash and c == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            j = n if j < 0 else j
            blank(i, j); i = j
        elif slash and c == '/' and i + 1 < n and text[i + 1] == '*':
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            blank(i, j); i = j
        elif hashc and c == '#' and not (lang == 'php' and i + 1 < n and text[i + 1] == '['):
            j = text.find('\n', i)
            j = n if j < 0 else j
            blank(i, j); i = j
        elif lang == 'py' and text.startswith(('"""', "'''"), i):
            q = text[i:i + 3]
            j = text.find(q, i + 3)
            j = n if j < 0 else j + 3
            blank(i + 3, j - 3); spans.append((i + 2, j - 2)); i = j
        elif c in '"\'' or (c == '`' and lang == 'c'):
            j = i + 1
            while j < n and text[j] != c:
                if text[j] == '\\':
                    j += 1
                elif text[j] == '\n' and c != '`' and lang in ('c', 'py'):
                    break
                j += 1
            j = min(j + 1, n)
            blank(i + 1, j - 1); spans.append((i, j)); i = j
        else:
            i += 1
    return ''.join(out), spans


PAIRS = {'(': ')', '[': ']', '{': '}'}


def close(m, i):
    """Index of the bracket closing m[i] (masked text), or len(m)-1 when unbalanced."""
    st = []
    for j in range(i, len(m)):
        c = m[j]
        if c in PAIRS:
            st.append(PAIRS[c])
        elif c in ')]}':
            if st and st[-1] == c:
                st.pop()
                if not st:
                    return j
            elif st:
                st.pop()
    return len(m) - 1


# ---------------------------------------------------------------- registry
LOAD_ERRORS = []


def load_modules():
    mods = {}
    del LOAD_ERRORS[:]
    for name in MODULES:
        path = os.path.join(HERE, name + '.py')
        if not os.path.isfile(path):
            LOAD_ERRORS.append('%s.py absent: its stacks are not detected' % name)
            continue
        spec = importlib.util.spec_from_file_location(name, path)
        mod = importlib.util.module_from_spec(spec)
        try:
            spec.loader.exec_module(mod)
        except Exception as e:   # one broken lane module must not hide the others; the run exits 4
            LOAD_ERRORS.append('%s.py failed to load (%s: %s): its stacks are not detected' % (name, type(e).__name__, e))
            continue
        hs = hashlib.sha256()
        with open(path, 'rb') as f:
            body = f.read()
        hs.update(body)
        common = os.path.join(HERE, 'lanes_common.py')
        if b'lanes_common.py' in body and os.path.isfile(common):   # a shared-helper edit re-stales every record
            with open(common, 'rb') as f:
                hs.update(f.read())
        for dep in getattr(mod, 'DEPENDS', ()):   # a sibling lane module this one loads (lanes_supabase reads zod through lanes_node)
            dp = os.path.join(HERE, dep)
            if os.path.isfile(dp):
                with open(dp, 'rb') as f:
                    hs.update(f.read())
        mod.HASH = hs.hexdigest()[:16]
        mods[name] = mod
    return mods


def detect(mods, root, forced):
    """[(stack, module, evidence)] for one root."""
    found = []
    for name, mod in mods.items():
        h = H(root, 'detect')
        for stack, ev in sorted(mod.detect(root, h).items()):
            if ev and (not forced or stack in forced):
                found.append((stack, mod, ev))
    if forced:
        known = set(s for m in mods.values() for s in m.STACKS)
        for s in forced:
            if s not in known:
                raise Usage('unknown stack %s (known: %s)' % (s, ', '.join(sorted(known))))
            if not any(f[0] == s for f in found):
                mod = [m for m in mods.values() if s in m.STACKS][0]
                found.append((s, mod, 'forced by --stack (not detected)'))
    return found


def extract(mods, root, side, stacks, lanes):
    """{lane: {'rows': {key: row}, 'status': str, 'partial': bool, 'stacks': [...]}} plus side ledger."""
    res, led = {}, {'rg_calls': 0, 'rg_errors': [], 'unparsed': [], 'notes': [], 'dups': 0}
    hs = {}
    for stack, mod, ev in stacks:
        hs[stack] = H(root, side)
    ctxs = dict((s, {'stack': s, 'evidence': ev}) for s, _, ev in stacks)
    for lane in lanes:
        rows, status, partial, used = {}, None, False, []
        for stack, mod, ev in stacks:
            fn = mod.LANES.get(stack, {}).get(lane)
            if fn is None:
                continue
            used.append(stack)
            partial = partial or (stack, lane) in mod.PARTIAL
            try:
                for r in fn(root, hs[stack], ctxs[stack]):
                    r['lane'] = lane
                    if r['key'] in rows:
                        led['dups'] += 1
                        merge(rows[r['key']], r)
                    else:
                        rows[r['key']] = r
            except Blocked as e:
                status = 'blocked (%s %s: %s)' % (side, stack, e)
        if not used:
            reason = 'no %s lane for %s' % (lane, '+'.join(s for s, _, _ in stacks) or 'an undetected stack')
            for stack, mod, ev in stacks:
                why = getattr(mod, 'GAPS', {}).get((stack, lane))
                if why:
                    reason = why
            status = 'blocked (gap — %s: %s)' % (side, reason)
        res[lane] = {'rows': rows, 'status': status, 'partial': partial, 'stacks': used}
    for h in hs.values():
        led['rg_calls'] += h.rg_calls
        led['rg_errors'] += h.rg_errors
        led['unparsed'] += h.unparsed
        led['notes'] += h.notes
    for c in ctxs.values():
        led['notes'] += c.get('notes', [])
    return res, led


def merge(a, b):
    """Two rows with one key (a route registered twice, an effect from an observer AND a trait): set attrs union."""
    for k, v in b['attrs'].items():
        if k not in a['attrs'] or a['attrs'][k] == '?':
            a['attrs'][k] = v
        elif k in ('kinds', 'abilities', 'roles', 'values', 'modes', 'value', 'status') and v != '?':
            a['attrs'][k] = setv(a['attrs'][k].split(',') + v.split(','))
    a['at'] += ' +' + b['at'] if b['at'] not in a['at'] else ''


# ---------------------------------------------------------------- pair map + diff
def read_pair_map(path):
    rules, ignored = [], []
    if not path or not os.path.isfile(path):
        return rules, ignored
    with open(path, encoding='utf-8', errors='replace') as f:
        for n, line in enumerate(f, 1):
            if not line.strip() or line.startswith('#'):
                continue
            c = [x.strip() for x in line.rstrip('\n').split('\t')]
            if c[0] == 'lane':
                continue
            if len(c) < 4 or not c[3]:
                ignored.append('%s:%d no reason: %s' % (path, n, tsv(line)[:80]))
                continue
            attr = c[4] if len(c) > 4 else ''
            if attr and (not re.search(r'\bADR-\d+', c[3]) or '=' not in attr):
                ignored.append('%s:%d an attribute change needs `attr=value` and an ADR-NNN reason: %s' % (path, n, tsv(line)[:80]))
                continue
            rules.append({'lane': c[0], 'v1': c[1], 'v2': c[2], 'reason': c[3], 'attr': attr})
    return rules, ignored


def apply_map(lane, rows, rules, info=None):
    """Rewrite V1 keys/values so they speak V2's vocabulary. Returns (rows, removed {key: reason}).
    An I-ROUTES rename or removal also applies to every row keyed by that route (I-AUTHZ, I-RULES `<route> <field>`,
    I-SIDE handler rows); `*` rows apply to every lane. A glob rename (`col:*.user_id ⇥ col:*.tenant_id`) carries
    each `*` capture into the V2 pattern, and a `col:` rename also renames that column inside the table's
    `unique:`/`fk:` keys. `info` (a dict) receives `renamed` (the keys an explicit map row produced) and `collided`
    {key: [v1 keys]}: two V1 keys mapped onto one key are merged, never overwritten — a differing attribute
    becomes the comma set of both values, so the diff still shows it (IR-2)."""
    out, gone = {}, {}
    info = {} if info is None else info
    renamed, collided, origin = info.setdefault('renamed', set()), info.setdefault('collided', {}), {}
    pre = [(r['v1'][7:].rstrip('/'), r['v2'][7:].rstrip('/')) for r in rules if r['v1'].startswith('prefix:')]
    keys = dict((r['v1'], r) for r in rules if r['lane'] in (lane, '*') and r['v1'] != '-' and '*' not in r['v1']
                and not r['v1'].startswith(('prefix:', 'value:')))
    rkeys = dict((r['v1'], r) for r in rules if r['lane'] == 'I-ROUTES' and ROUTE_RE.match(r['v1']))
    vals = [(r['v1'][6:], r['v2'][6:]) for r in rules if r['lane'] in (lane, '*') and r['v1'].startswith('value:')]
    globs = [r for r in rules if r['lane'] in (lane, '*') and '*' in r['v1'] and r['v2'] != '-' and not r['attr']
             and r['v2'].count('*') == r['v1'].count('*') and not r['reason'].startswith('moved-to')]
    colren = [r for r in globs + list(keys.values()) if r['v1'].startswith('col:') and r['v2'].startswith('col:')
              and not r['attr'] and r['v1'].count('*') == r['v2'].count('*')]
    for k, row in rows.items():
        nk = k
        m = ROUTE_RE.match(k)
        if m:
            for a, b in pre:
                p = m.group(2)
                if p == a or p.startswith(a + '/'):
                    nk = '%s %s%s' % (m.group(1), (b + p[len(a):]) or '/', m.group(3))
                    break
            m = ROUTE_RE.match(nk)
            route = '%s %s' % (m.group(1), m.group(2))
            r = rkeys.get(route)
            if r and nk not in keys:
                if r['v2'] == '-' or r['reason'].startswith('moved-to'):
                    gone[k] = r['reason']
                    continue
                if ROUTE_RE.match(r['v2']):
                    nk = r['v2'] + m.group(3)
                    renamed.add(nk)
        if nk in keys:
            if keys[nk]['v2'] == '-' or keys[nk]['reason'].startswith('moved-to'):
                gone[k] = keys[nk]['reason']
                continue
            nk = keys[nk]['v2']
            renamed.add(nk)
        else:
            gr = next((r for r in globs if kmatch(r['v1'], nk)), None)
            cm = re.match(r'(unique|fk):([^(]+)\((.*)\)$', nk)
            if gr:
                nk = glob_sub(gr['v1'], gr['v2'], nk)
                renamed.add(nk)
            elif cm and colren:
                cols = []
                for c in cm.group(3).split(','):
                    ck = 'col:%s.%s' % (cm.group(2), c)
                    cr = next((r for r in colren if kmatch(r['v1'], ck)), None)
                    cols.append(glob_sub(cr['v1'], cr['v2'], ck).split('.', 1)[-1] if cr else c)
                nk2 = '%s:%s(%s)' % (cm.group(1), cm.group(2), ','.join(sorted(cols) if cm.group(1) == 'unique' else cols))
                if nk2 != nk:
                    nk = nk2
                    renamed.add(nk)
        g = next((r for r in rules if r['lane'] in (lane, '*') and '*' in r['v1'] and r['v2'] == '-' and kmatch(r['v1'], nk)), None)
        if g:
            gone[k] = g['reason']
            continue
        if vals:
            row = dict(row, attrs=dict(row['attrs']))
            for ak, av in row['attrs'].items():
                parts = av.split(',')
                parts = [dict(vals).get(x, x) for x in parts]
                row['attrs'][ak] = setv(parts) if ',' in av or len(parts) > 1 else parts[0]
        if nk in out:   # IR-2: two V1 keys landed on one key — merged and ledgered, never overwritten
            a = out[nk] = dict(out[nk], attrs=dict(out[nk]['attrs']))
            for ak, av in row['attrs'].items():
                bv = a['attrs'].get(ak)
                if bv is None or bv == '?':
                    a['attrs'][ak] = av
                elif av != '?' and av != bv:
                    a['attrs'][ak] = setv(bv.split(',') + av.split(','))
            a['at'] += '' if row['at'] in a['at'] else ' +' + row['at']
            collided.setdefault(nk, [origin[nk]]).append(k)
            continue
        origin[nk] = k
        out[nk] = row
    return out, gone


def glob_sub(pat, rep, key):
    """`col:*.user_id` -> `col:*.tenant_id` turns `col:orders.user_id` into `col:orders.tenant_id` (captures in order)."""
    m = re.match('^' + '(.*)'.join(re.escape(x) for x in pat.split('*')) + '$', key)
    if not m:
        return key
    parts = rep.split('*')
    return parts[0] + ''.join(g + q for g, q in zip(m.groups(), parts[1:]))


def kmatch(pat, key):
    """A pair-map key, where `*` matches any run of characters (`col:*.legacy_id`, `unique:*(legacy_id)`)."""
    return pat == key or ('*' in pat and re.match('^' + '.*'.join(re.escape(x) for x in pat.split('*')) + '$', key) is not None)


def acknowledge(lane, cands, rules, gone):
    """IR-1 rows that close a candidate after the diff:
    `lane ⇥ - ⇥ <v2-key> ⇥ reason` acknowledges a V2-only key (an I-ROUTES row covers that route's AUTHZ/RULES/SIDE rows);
    `lane ⇥ <key> ⇥ <key> ⇥ ADR-NNN … ⇥ attr=value` accepts exactly that V2 value of one attribute.
    `*` globs; a V1 key that is mapped away (`-` in the V2 column) is handled in apply_map."""
    out = []
    for c in cands:
        m = ROUTE_RE.match(c['key'])
        route = '%s %s' % (m.group(1), m.group(2)) if m else None
        hit = None
        for r in rules:
            same = r['lane'] in (lane, '*') or (r['lane'] == 'I-ROUTES' and route and lane in ROUTE_KEYED + ('I-SIDE',))
            if not same:
                continue
            if c['diff'] == 'V2-ONLY' and r['v1'] == '-' and not r['attr']:
                k = route if (r['lane'] == 'I-ROUTES' and lane != 'I-ROUTES') else c['key']
                if k and kmatch(r['v2'], k):
                    hit = 'acknowledged V2-only (%s)' % r['reason']
            elif c['diff'] == 'CHANGED' and r['attr'] and r['lane'] in (lane, '*'):
                an, _, av = r['attr'].partition('=')
                if an == c['attr'] and kmatch(r['v2'], c['key']) and setv(av.split(',')) == setv(c['v2'].split(',')):
                    hit = 'accepted %s=%s (%s)' % (an, av, r['reason'])
            if hit:
                break
        if hit:
            gone['%s %s%s' % (c['diff'], c['key'], (' ' + c['attr']) if c['attr'] != '-' else '')] = hit
        else:
            out.append(c)
    return out


def fuzzy(lane, r1, r2):
    """I-SCHED / I-MONEY keys are word sets (`job:report.send.weekly`); a V1 key with no exact twin pairs with the
    one V2 key whose words overlap it best (Jaccard >= 0.5, unique, mutual). Returns {v1 key: v2 key}."""
    if lane not in FUZZY:
        return {}
    o1 = [k for k in r1 if k not in r2]
    o2 = [k for k in r2 if k not in r1]
    def words(k):   # an I-MONEY row also brings its function's words (`area:pricing` creditFor == `area:credit` creditFor)
        row = r1.get(k) or r2.get(k)
        fn = (row or {}).get('attrs', {}).get('where', '').split('.')[-1].split('::')[-1]
        return (set(re.split(r'[.:]', k.split(':', 1)[-1])) | set(singular(w) for w in H.words(fn))) - {''}

    def best(k, pool):
        sc = sorted(((len(words(k) & words(x)) / float(len(words(k) | words(x)) or 1), x) for x in pool), reverse=True)
        if sc and sc[0][0] >= 0.5 and (len(sc) == 1 or sc[1][0] < sc[0][0]):
            return sc[0][1]
        return None
    out = {}
    for k in o1:
        b = best(k, o2)
        if b and best(b, o1) == k:
            out[k] = b
    return out


def diff(lane, r1, r2, show_all=False):
    cands = []
    fz = fuzzy(lane, r1, r2)
    r2 = dict(r2)
    for k, b in fz.items():
        r2[k] = dict(r2.pop(b), fuzzy=b)
    for k in sorted(set(r1) | set(r2)):
        a, b = r1.get(k), r2.get(k)
        if a and not b:
            cands.append(cand(lane, 'V1-ONLY', k, '-', a, None))
        elif b and not a:
            cands.append(cand(lane, 'V2-ONLY', k, '-', None, b))
        else:
            changed = False
            for at in COMPARE.get(lane, ()):
                x, y = a['attrs'].get(at), b['attrs'].get(at)
                if x is None and y is None or x == '?' or y == '?':
                    continue
                if at in V1_ONLY_ATTR.get(lane, ()) and not x:
                    continue
                if (lane, at) in V1_GUARD and x != V1_GUARD[(lane, at)]:
                    continue
                if (x or '') != (y or ''):
                    cands.append(cand(lane, 'CHANGED', k, at, a, b, x or '', y or ''))
                    changed = True
            if show_all and not changed:
                cands.append(cand(lane, 'MATCH', k, '-', a, b))
            if b.get('fuzzy'):
                for c in cands:
                    if c['key'] == k:
                        c['tags'].append('paired-by-name(%s)' % b['fuzzy'])
    return cands


def collapse_tables(cands, rows2):
    """A V1 table with no V2 row at all is one candidate (`table:<t>`, cols=n), not one per column, index and FK."""
    tab = lambda k: re.match(r'(?:col|unique|fk):([^.(]+)', k).group(1) if re.match(r'(?:col|unique|fk):', k) else None
    v2t = set(tab(k) for k in rows2)
    out, seen = [], {}
    for c in cands:
        t = tab(c['key'])
        if c['diff'] == 'V1-ONLY' and t and t not in v2t:
            if t not in seen:
                seen[t] = dict(c, key='table:' + t, attr='-', v1='', tags=list(c['tags']))
                out.append(seen[t])
            seen[t]['v1'] = 'rows=%d' % (int(seen[t]['v1'][5:] or 0) + 1)
        else:
            out.append(c)
    return out


def cand(lane, kind, key, attr, a, b, x=None, y=None):
    if x is None:
        x = attrs_str(a['attrs']) if a else '-'
        y = attrs_str(b['attrs']) if b else '-'
    return {'lane': lane, 'diff': kind, 'key': key, 'attr': attr, 'v1': x, 'v2': y,
            'v1_at': a['at'] if a else '-', 'v2_at': b['at'] if b else '-', 'tags': [],
            'excerpt': (a or b)['excerpt']}


def suffix_pairs(v1only, v2only, k=10):
    """The 10 nearest (V1-ONLY, V2-ONLY) route pairs by shared path-segment suffix — what a prefix row fixes."""
    out = []
    for a in v1only:
        ma = ROUTE_RE.match(a)
        if not ma:
            continue
        sa = ma.group(2).split('/')
        best, bs = None, 0
        for b in v2only:
            mb = ROUTE_RE.match(b)
            if not mb or mb.group(1) != ma.group(1):
                continue
            sb = mb.group(2).split('/')
            n = 0
            while n < min(len(sa), len(sb)) and sa[-1 - n] == sb[-1 - n]:
                n += 1
            if n > bs:
                best, bs = b, n
        if best:
            out.append((bs, a, best))
    out.sort(key=lambda t: (-t[0], t[1]))
    return out[:k]


def prefix_hint(pairs):
    cnt = {}
    for n, a, b in pairs:
        pa, pb = ROUTE_RE.match(a).group(2).split('/'), ROUTE_RE.match(b).group(2).split('/')
        x = '/'.join(pa[:len(pa) - n]) or '/'
        y = '/'.join(pb[:len(pb) - n]) or '/'
        cnt[(x, y)] = cnt.get((x, y), 0) + 1
    if not cnt:
        return None
    (x, y), _ = max(cnt.items(), key=lambda kv: kv[1])
    return 'I-ROUTES\tprefix:%s\tprefix:%s\t<ADR-NNN or reason>' % (x, y)


# ---------------------------------------------------------------- snapshot, records, freshness
def git(args, cwd=None):
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0')
    p = subprocess.run(['git'] + args, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return p.returncode, p.stdout.decode('utf-8', 'replace').strip(), p.stderr.decode('utf-8', 'replace').strip()


def resolve_pin(v1, pin, live=False):
    """(sha, kind): a commit (archived at <sha>:<subdir>) or a tree (archived as is). In --live-v1 mode a hex pin
    that does not resolve (an uncommitted tree hash) is kept verbatim as the label recorded in the headers."""
    for kind in ('commit', 'tree'):
        rc, sha, err = git(['-C', v1, 'rev-parse', '--verify', '--quiet', '%s^{%s}' % (pin, kind)])
        if not rc and re.match(r'^[0-9a-f]{40}$', sha):
            return sha, kind
    if live and re.match(r'^[0-9a-f]{7,40}$', pin):
        return pin, 'label'
    raise Usage('pin %s does not resolve in %s; pass --live-v1 to read the directory in place' % (pin, v1))


def snapshot(v1, sha, dst, kind='commit'):
    """`git archive <sha>:<subdir>` streamed into dst. Write-free on V1 (GIT_OPTIONAL_LOCKS=0; archive takes no
    lock and touches no index). Skips symlinks, devices, `..` paths, node_modules/vendor and files > 2 MB."""
    rc, prefix, err = git(['-C', v1, 'rev-parse', '--show-prefix'])
    rc2, top, _ = git(['-C', v1, 'rev-parse', '--show-toplevel'])
    if rc or rc2:
        raise Usage('not a git tree: %s (%s); pass --live-v1' % (v1, err))
    tree = '%s:%s' % (sha, prefix.rstrip('/')) if kind == 'commit' else sha
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0')
    # run from the top level: from a subdirectory, git archive also filters by the current path
    p = subprocess.Popen(['git', '-C', top, 'archive', '--format=tar', tree], stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, env=env)
    n = skipped = 0
    os.makedirs(dst)
    with tarfile.open(fileobj=p.stdout, mode='r|') as tf:
        for mem in tf:
            name = mem.name
            if (not mem.isfile() or name.startswith('/') or '..' in name.split('/') or mem.size > 2000000
                    or re.search(r'(^|/)(node_modules|vendor)/', name)):
                skipped += 0 if mem.isdir() else 1
                continue
            target = os.path.join(dst, name)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            src = tf.extractfile(mem)
            with open(target, 'wb') as f:
                shutil.copyfileobj(src, f)
            n += 1
    err = p.stderr.read().decode('utf-8', 'replace').strip()
    if p.wait() != 0:
        raise Usage('git archive %s failed: %s' % (tree, err))
    if n == 0:
        raise Usage('git archive %s extracted 0 files (is the subdirectory committed at the pin?)' % tree)
    return n, skipped, tree


def ledger_pin(path):
    if path and os.path.isfile(path):
        with open(path, encoding='utf-8', errors='replace') as f:
            m = re.search(r'v1_commit_pinned\s*:\s*["\']?([0-9a-f]{7,40})', f.read())
        if m:
            return m.group(1)
    return None


def write_lane(path, lane, side, sha, root, stacks, mods_used, rows):
    hashes = '+'.join('%s.py@sha256:%s' % (m.__name__, m.HASH) for m in mods_used) or '-'
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write('# pair-inventory %s · lane=%s · side=%s · sha=%s · root=%s · stack=%s\n'
                % (FORMAT, lane, side, sha or '-', root, '+'.join(stacks) or '-'))
        f.write('# extractor=%s · normaliser=%s · generated=%s · rows=%d\n'
                % (hashes, NORMALISER, time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), len(rows)))
        f.write('# lane\tkey\tattrs\tat\texcerpt\n')
        for k in sorted(rows):
            r = rows[k]
            f.write('\t'.join([lane, tsv(k), attrs_str(r['attrs']) or '-', tsv(r['at']), tsv(r['excerpt'])]) + '\n')


def read_lane(path):
    head, rows = {}, {}
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('# pair-inventory') or line.startswith('# extractor='):
                for part in line[2:].split(' · '):
                    k, _, v = part.partition('=')
                    head[k.strip()] = v.strip()
                continue
            if not line or line.startswith('#'):
                continue
            c = line.split('\t')
            if len(c) >= 5:
                rows[c[1]] = {'key': c[1], 'attrs': attrs_parse(c[2]), 'at': c[3], 'excerpt': c[4], 'lane': c[0]}
    return head, rows


def newer_than(stamp, roots):
    """Files under the roots modified after the run started (node_modules/vendor not walked)."""
    t, hits = os.stat(stamp).st_mtime, []
    for r in roots:
        for d, dirs, files in os.walk(r):
            dirs[:] = [x for x in dirs if x not in ('node_modules', 'vendor')]
            for fn in files:
                p = os.path.join(d, fn)
                try:
                    if os.lstat(p).st_mtime > t:
                        hits.append(p)
                except OSError:
                    pass
    return hits


# ---------------------------------------------------------------- runs
def run_pair(mods, v1, v2, a, lanes, rules, led):
    """Paired extraction + diff. Returns {lane: lane-result} with candidates."""
    s1 = detect(mods, v1, a.stack_v1)
    s2 = detect(mods, v2, a.stack_v2)
    e1, l1 = extract(mods, v1, 'v1', s1, lanes)
    e2, l2 = extract(mods, v2, 'v2', s2, lanes)
    return finish(lanes, e1, e2, rules, s1, s2, l1, l2, led, a.all)


def finish(lanes, e1, e2, rules, s1, s2, l1, l2, led, show_all):
    out = {}
    led['det'] = {'v1': s1, 'v2': s2}
    led.setdefault('sides', []).extend([l1, l2])
    led['stacks_v1'] = ['%s (%s)' % (s, ev) for s, _, ev in s1]
    led['stacks_v2'] = ['%s (%s)' % (s, ev) for s, _, ev in s2]
    route_halt, joined = None, set()
    for lane in lanes:
        a, b = e1[lane], e2[lane]
        st = a['status'] or b['status']
        if not a['rows'] and not b['rows'] and not st:
            out[lane] = dict(status='N/A (no %s surface on either side)' % lane, cands=[], n1=0, n2=0, gone={},
                             partial=a['partial'] or b['partial'], rows1={}, rows2={})
            continue
        info = {}
        r1, gone = apply_map(lane, a['rows'], rules, info)
        if lane == 'I-SCHED':   # a job with no zone runs in its process/app zone: each side's I-CONF timezone, when read
            r1 = dict(r1)
            b = dict(b, rows=dict(b['rows']))
            for rows, conf in ((r1, e1.get('I-CONF')), (b['rows'], e2.get('I-CONF'))):
                tz = ((conf or {}).get('rows', {}).get('timezone') or {}).get('attrs', {}).get('value', '')
                for k, r in list(rows.items()):
                    if tz and r['attrs'].get('tz', None) == '':
                        rows[k] = dict(r, attrs=dict(r['attrs'], tz=tz, tz_src='process (I-CONF timezone)'))
        cands = [] if st else diff(lane, r1, b['rows'], show_all)
        if lane == 'I-SCHEMA':
            cands = collapse_tables(cands, b['rows'])
            led.setdefault('hints', []).extend(rename_hints(cands))
        cands = acknowledge(lane, cands, rules, gone)
        for c in cands:   # IR-2: a merged collision is a reviewable fact on the row, and in the ledger
            if c['key'] in info['collided']:
                c['tags'].append('collided(%s)' % ' + '.join(info['collided'][c['key']]))
        if lane == 'I-ROUTES' and not st:
            # IR-1: prefix sanity is judged over the keys no explicit pair-map row addresses. Keys a rename row
            # addresses join by that row (a route-join); only the unaddressed remainder can hold the halt.
            acked = set(c2['key'] for c2 in diff(lane, r1, b['rows']) if c2['diff'] == 'V2-ONLY') - set(c['key'] for c in cands if c['diff'] == 'V2-ONLY')
            joined = set(k for k in info['renamed'] if ROUTE_RE.match(k))
            u1 = [k for k in r1 if k not in joined]
            u2 = [k for k in b['rows'] if k not in joined and k not in acked]
            o1 = [c['key'] for c in cands if c['diff'] == 'V1-ONLY' and c['key'] not in joined]
            o2 = [c['key'] for c in cands if c['diff'] == 'V2-ONLY' and c['key'] not in joined]
            if len(u1) >= 4 and len(u2) >= 4 and len(o1) * 2 > len(u1) and len(o2) * 2 > len(u2):
                pairs = suffix_pairs(o1, o2)
                route_halt = (len(o1), len(u1), len(o2), len(u2), pairs, prefix_hint(pairs), len(joined))
                if joined:
                    st = ('checked · route-join (%d V1 keys joined by pair-map rows; prefix sanity still fails over the rest: '
                          '%d/%d unaddressed V1 keys V1-ONLY and %d/%d V2 keys V2-ONLY — not diffed, Live, unreviewed)'
                          % ((len(joined),) + route_halt[:4]))
                    cands = [c for c in cands if c['key'] in joined]
                else:
                    st = 'blocked (prefix sanity: %d/%d V1 keys V1-ONLY and %d/%d V2 keys V2-ONLY — the normaliser, not the port; add a pair-map prefix row)' % route_halt[:4]
                    cands = []
        if lane == 'I-SIDE' and route_halt and joined and not st:   # route-keyed effects of unaddressed routes cannot pair
            keep = [c for c in cands if not route_of(c['key']) or route_of(c['key']) in joined]
            if len(keep) < len(cands):
                st = 'checked · route-join (%d route-keyed rows of unaddressed routes not diffed)' % (len(cands) - len(keep))
            cands = keep
        if lane in ROUTE_KEYED and lane != 'I-ROUTES' and route_halt and not st:
            if joined:
                cands = [c for c in cands if route_of(c['key']) in joined]
                st = 'checked · route-join (rows of the %d pair-map-joined routes; the unaddressed routes are not diffed)' % len(joined)
            else:
                st, cands = 'blocked (route keys failed the I-ROUTES prefix sanity halt)', []
        out[lane] = dict(status=st, cands=cands, n1=len(a['rows']), n2=len(b['rows']), gone=gone,
                         partial=a['partial'] or b['partial'], rows1=a['rows'], rows2=b['rows'], collided=info['collided'])
    led['route_halt'] = route_halt
    return out


def route_of(key):
    m = ROUTE_RE.match(key)
    return '%s %s' % (m.group(1), m.group(2)) if m else None


def rename_hints(cands):
    """IR-10: a V1-ONLY and a V2-ONLY `unique:`/`fk:` key on one table that differ in exactly one column suggest a
    column rename (`col:<t>.user_id ⇥ col:<t>.tenant_id`); the same pair on 3+ tables suggests one glob row. The
    engine never applies a suggestion — only a pair-map row with a reason does."""
    o1, o2, cnt = {}, {}, {}
    for c in cands:
        m = re.match(r'(unique|fk):([^(]+)\((.*)\)$', c['key'])
        if m and c['diff'] in ('V1-ONLY', 'V2-ONLY'):
            (o1 if c['diff'] == 'V1-ONLY' else o2).setdefault((m.group(1), m.group(2)), []).append(set(m.group(3).split(',')))
    for k, sets1 in o1.items():
        for s1 in sets1:
            for s2 in o2.get(k, []):
                x, y = s1 - s2, s2 - s1
                if len(s1) == len(s2) and len(x) == 1 and len(y) == 1:
                    cnt.setdefault((list(x)[0], list(y)[0]), set()).add(k[1])
    out = []
    for (x, y), ts in sorted(cnt.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        if len(ts) >= 3:
            out.append('I-SCHEMA\tcol:*.%s\tcol:*.%s\t<ADR-NNN or reason>   (one column differs on %d tables: %s)' % (x, y, len(ts), ','.join(sorted(ts)[:4])))
        else:
            out += ['I-SCHEMA\tcol:%s.%s\tcol:%s.%s\t<ADR-NNN or reason>' % (t, x, t, y) for t in sorted(ts)]
    return out[:15]


def calibrate(mods, v1, v2, a, lanes, rules, led):
    """A known-parity pair: every lane must diff to 0. Returns {lane: (k, cands)}."""
    sub = {}
    res = run_pair(mods, v1, v2, a, lanes, rules, sub)
    return dict((l, (len(r['cands']), r['cands'], r['status'])) for l, r in res.items())


def builtin_pair(dst, cal=None):
    cal = cal or CALIBRATION
    for side in ('v1', 'v2'):
        for rel, body in cal[side].items():
            p = os.path.join(dst, side, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, 'w', encoding='utf-8') as f:
                f.write(body)
    return os.path.join(dst, 'v1'), os.path.join(dst, 'v2')


def print_ledger(led, res, w=None):
    w = w or sys.stderr.write
    w('pair-inventory %s · mode=%s · %s\n' % (FORMAT, led['mode'], ' · '.join(led.get('head', []))))
    w('  stacks: v1 %s · v2 %s\n' % ('; '.join(led.get('stacks_v1', [])) or '-', '; '.join(led.get('stacks_v2', [])) or '-'))
    for c in led.get('calibration', []):
        w('  calibration: %s\n' % c)
    w('  %-9s %7s %7s %7s %7s %7s  %s\n' % ('lane', 'v1 rows', 'v2 rows', 'V1-ONLY', 'V2-ONLY', 'CHANGED', 'status'))
    for lane, r in res.items():
        k = lambda d: sum(1 for c in r['cands'] if c['diff'] == d)
        st = r['status'] or ('checked' + (' · partial' if r['partial'] else '') + (' · %s' % ','.join(sorted(set(t for c in r['cands'] for t in c['tags']))) if any(c['tags'] for c in r['cands']) else ''))
        w('  %-9s %7s %7s %7d %7d %7d  %s\n' % (lane, r['n1'], r['n2'], k('V1-ONLY'), k('V2-ONLY'), k('CHANGED'), st))
        for g, why in sorted(r['gone'].items()):
            w('      pair-map: %s -> %s\n' % (g, why if why.startswith(('acknowledged', 'accepted')) else 'mapped away (%s)' % why))
        for k, srcs in sorted((r.get('collided') or {}).items()):
            w('      pair-map collision: %s <- %s (merged; differing attributes kept as the set of both)\n' % (k, ' + '.join(srcs)))
    for x in led.get('hints', []):
        w('  suggested pair-map row (column rename; add only with a reason): %s\n' % x)
    rh = led.get('route_halt')
    if rh:
        w('  prefix sanity halt%s — nearest pairs by path suffix (shared segments, V1 key -> V2 key):\n'
          % (' over the %d/%d unaddressed keys (route-join on the %d mapped ones)' % (rh[1], rh[3], rh[6]) if len(rh) > 6 and rh[6] else ''))
        for n, a, b in rh[4]:
            w('      %d  %s  ->  %s\n' % (n, a, b))
        if rh[5]:
            w('    suggested pair-map row: %s\n' % rh[5])
    for s in led.get('sides', []):
        pass
    calls = sum(s['rg_calls'] for s in led.get('sides', []))
    errs = [e for s in led.get('sides', []) for e in s['rg_errors']]
    w('  rg: %d calls, %d exit-2%s\n' % (calls, len(errs), (': ' + '; '.join(errs[:3])) if errs else ''))
    unp = [u for s in led.get('sides', []) for u in s['unparsed']]
    w('  unparsed: %d%s\n' % (len(unp), ''.join('\n      ' + u for u in unp[:12]) + ('\n      ... %d more (see <out>/ledger.txt)' % (len(unp) - 12) if len(unp) > 12 else '')))
    dups = sum(s['dups'] for s in led.get('sides', []))
    if dups:
        w('  merged duplicate keys: %d\n' % dups)
    for s in led.get('sides', []):
        for n in sorted(set(s['notes'])):
            w('  note: %s\n' % n)
    for i in led.get('ignored', []):
        w('  pair-map row ignored (no reason): %s\n' % i)
    for x in led.get('tail', []):
        w('  %s\n' % x)


def emit(res, out_dir, show):
    cols = ['lane', 'diff', 'key', 'attr', 'v1', 'v2', 'v1_at', 'v2_at', 'tags', 'excerpt']
    lines = ['# CANDIDATE\t' + '\t'.join(cols)]
    n = 0
    for lane, r in res.items():
        for c in r['cands']:
            if c['diff'] != 'MATCH':
                n += 1
            lines.append('\t'.join(['CANDIDATE' if c['diff'] != 'MATCH' else 'MATCH', lane] + [tsv(c['diff']), tsv(c['key']), tsv(c['attr']), tsv(c['v1']),
                                    tsv(c['v2']), tsv(c['v1_at']), tsv(c['v2_at']), ','.join(c['tags']) or '-', tsv(c['excerpt'])]))
    body = '\n'.join(lines) + '\n'
    if out_dir:
        with open(os.path.join(out_dir, 'candidates.tsv'), 'w', encoding='utf-8') as f:
            f.write(body)
    if show:
        sys.stdout.write(body)
    return n


def main(argv):
    ap = argparse.ArgumentParser(prog='pair-inventory.py', add_help=True)
    for o in ('v1', 'v2', 'v1-inventory', 'pin', 'ledger', 'pair-map', 'lanes', 'stack-v1', 'stack-v2', 'out',
              'calibration-pair'):
        ap.add_argument('--' + o)
    for f in ('record-v1', 'calibrate', 'live-v1', 'all', 'self-test', 'list-lanes', 'no-builtin-calibration'):
        ap.add_argument('--' + f, action='store_true')
    a = ap.parse_args(argv)
    a.stack_v1 = [s for s in (a.stack_v1 or '').split(',') if s]
    a.stack_v2 = [s for s in (a.stack_v2 or '').split(',') if s]
    if a.self_test:
        return self_test()
    mods = load_modules()
    if a.list_lanes:
        for name, m in mods.items():
            for st in m.STACKS:
                ls = sorted(m.LANES.get(st, {}), key=LANES.index)
                sys.stdout.write('%-8s %-14s sha256:%s  %s\n' % (st, name, m.HASH, ' '.join(
                    l + ('(partial)' if (st, l) in m.PARTIAL else '') for l in ls)))
        return 0
    try:
        return run(mods, a)
    except Usage as e:
        sys.stderr.write('pair-inventory: %s\n' % e)
        return 2


def run(mods, a):
    lanes = [l.strip() for l in (a.lanes or ','.join(LANES)).split(',') if l.strip()]
    bad = [l for l in lanes if l not in LANES]
    if bad:
        raise Usage('unknown lane %s (lanes: %s)' % (','.join(bad), ','.join(LANES)))
    for p in (a.v1, a.v2, a.v1_inventory):
        if p and not os.path.isdir(p):
            raise Usage('no such directory: %s' % p)
    mode = 'record' if a.record_v1 else 'calibrate' if a.calibrate else 'solo' if a.v1_inventory else 'paired' if (a.v1 and a.v2) else None
    if not mode or (mode == 'record' and not (a.v1 and a.out)) or (mode == 'solo' and not a.v2):
        raise Usage('need --v1 and --v2 (paired), --v2 and --v1-inventory (solo), or --record-v1 --v1 --pin --out')
    roots = [os.path.abspath(p) for p in (a.v1, a.v2) if p]
    if a.out:
        out = os.path.abspath(a.out)
        for r in roots:   # record mode's --out may be V2's ai/migration/v1-inventory (V2 is not read in record)
            if (out + os.sep).startswith(r + os.sep):
                raise Usage('--out %s is inside %s: the engine never writes into an audited tree' % (out, r))
        os.makedirs(out, exist_ok=True)
    else:
        out = tempfile.mkdtemp(prefix='pair-inventory.', dir=os.environ.get('TMPDIR') or None)
    run_dir = tempfile.mkdtemp(prefix='run.', dir=out)
    stamp = os.path.join(run_dir, 'stamp')
    open(stamp, 'w').close()
    time.sleep(0.01)
    led = {'mode': mode, 'head': [], 'tail': ['module error: ' + e for e in LOAD_ERRORS], 'explicit': bool(a.lanes)}
    v2 = os.path.abspath(a.v2) if a.v2 else None
    ledger_file = a.ledger or (os.path.join(v2, 'ai', 'migration', 'ledger.md') if v2 else None)
    rules, led['ignored'] = read_pair_map(a.pair_map or (os.path.join(v2, 'ai', 'migration', 'pair-map.tsv') if v2 else None))
    pin = a.pin or ledger_pin(ledger_file)
    v1, sha = None, None
    if a.v1:
        v1 = os.path.abspath(a.v1)
        if a.live_v1:
            led['head'].append('v1=%s (snapshot=live: read in place, verdict ceiling GO-UNVERIFIED)' % v1)
            sha = resolve_pin(v1, pin, True)[0] if pin else '-'
        else:
            if not pin:
                raise Usage('no V1 pin: pass --pin=<sha|ref> or set v1_commit_pinned in the ledger (or --live-v1)')
            sha, kind = resolve_pin(v1, pin)
            snap = os.path.join(run_dir, 'v1')
            n, skipped, tree = snapshot(v1, sha, snap, kind)
            led['head'].append('v1=%s @ %s %s (git archive %s -> %s: %d files, %d skipped)' % (v1, kind, sha[:12], tree, snap, n, skipped))
            v1 = snap
    led.setdefault('sha', {})['v1'] = sha or '-'
    led.setdefault('root', {})['v1'] = a.v1 or '-'
    if v2:
        rc, v2sha, _ = git(['-C', v2, 'rev-parse', 'HEAD'])
        led.setdefault('sha', {})['v2'] = v2sha if not rc and re.match(r'^[0-9a-f]{40}$', v2sha) else '-'
        led.setdefault('root', {})['v2'] = a.v2
        led['head'].append('v2=%s (live, read-only, HEAD %s)' % (v2, led['sha']['v2'][:12]))
    led['head'].append('out=%s' % out)

    if mode == 'record':
        s1 = detect(mods, v1, a.stack_v1)
        e1, l1 = extract(mods, v1, 'v1', s1, lanes)
        led['sides'] = [l1]
        led['stacks_v1'] = ['%s (%s)' % (s, ev) for s, _, ev in s1]
        res = {}
        for lane in lanes:
            r = e1[lane]
            used = [m for s, m, _ in s1 if lane in m.LANES.get(s, {})]
            if not r['status']:
                write_lane(os.path.join(out, lane + '.tsv'), lane, 'v1', sha, a.v1, [s for s, _, _ in s1], used, r['rows'])
            res[lane] = dict(status=r['status'] or 'recorded -> %s' % os.path.join(out, lane + '.tsv'), cands=[],
                             n1=len(r['rows']), n2='-', gone={}, partial=r['partial'])
        led['tail'].append('writes: %d lane files under %s (record mode, the one write)' % (sum(1 for r in res.values() if r['status'].startswith('recorded')), out))
        return close_run(led, res, stamp, roots, out, run_dir, False)

    if mode == 'solo':
        s2 = detect(mods, v2, a.stack_v2)
        e2, l2 = extract(mods, v2, 'v2', s2, lanes)
        e1 = {}
        for lane in lanes:
            path = os.path.join(a.v1_inventory, lane + '.tsv')
            st, tags, rows = None, [], {}
            if not os.path.isfile(path):
                st = 'blocked (no V1 tree, no recorded %s)' % lane
            else:
                head, rows = read_lane(path)
                for part in head.get('extractor', '-').split('+'):
                    mm = re.match(r'(\w+)\.py@sha256:(\w+)', part)
                    if not mm or mm.group(1) not in mods or mods[mm.group(1)].HASH != mm.group(2):
                        st = 'blocked (extractor changed since record; re-record: %s)' % part
                if head.get('normaliser') != NORMALISER:
                    st = st or 'blocked (normaliser %s recorded, %s installed; re-record)' % (head.get('normaliser'), NORMALISER)
                if head.get('rows', '').isdigit() and int(head['rows']) != len(rows):
                    st = st or 'blocked (record truncated: header rows=%s, read %d)' % (head['rows'], len(rows))
                if not pin or not head.get('sha', '-').startswith(pin[:7]) and not pin.startswith(head.get('sha', '-')[:12]):
                    tags.append('stale-v1-inventory(%s vs pin %s)' % (head.get('sha', '-')[:12], (pin or 'none')[:12]))
            e1[lane] = {'rows': rows, 'status': st, 'partial': False, 'stacks': [], 'tags': tags}
        res = finish(lanes, e1, e2, rules, [], s2, {'rg_calls': 0, 'rg_errors': [], 'unparsed': [], 'notes': [], 'dups': 0}, l2, led, a.all)
        for lane, r in res.items():
            for c in r['cands']:
                c['tags'] = ['solo'] + e1[lane].get('tags', [])
        led['tail'].append('solo: verdict ceiling GO-UNVERIFIED; drop classes stay Unconfirmed-solo (settle with --v1=<path>)')
        return close_run(led, res, stamp, roots, out, run_dir, True)

    # paired / calibrate
    if mode == 'calibrate':
        res = run_pair(mods, v1, v2, a, lanes, rules, led)
        for lane, r in res.items():
            if r['cands'] and not r['status']:
                r['status'] = 'blocked (lane %s asymmetric: %d rows on the calibration pair)' % (lane, len(r['cands']))
            elif not r['status']:
                r['status'] = 'calibrated (0 rows)'
        return close_run(led, res, stamp, roots, out, run_dir, True)

    res = run_pair(mods, v1, v2, a, lanes, rules, led)
    s1 = [s for s, _, _ in detect(mods, v1, a.stack_v1)]
    s2 = [s for s, _, _ in detect(mods, v2, a.stack_v2)]
    pairs = []
    if 'laravel' in s1 and 'nest' in s2 and not a.no_builtin_calibration:
        b1, b2 = builtin_pair(os.path.join(run_dir, 'calibration'))
        pairs.append(('built-in laravel->nest', b1, b2))
    if 'supabase' in s1 and 'nest' in s2 and not a.no_builtin_calibration:
        b1, b2 = builtin_pair(os.path.join(run_dir, 'calibration-supabase'), CALIBRATION_SUPABASE)
        pairs.append(('built-in supabase->nest', b1, b2))
    if a.calibration_pair:
        c1, _, c2 = a.calibration_pair.partition(',')
        if not (os.path.isdir(c1) and os.path.isdir(c2)):
            raise Usage('--calibration-pair needs <v1dir>,<v2dir>')
        pairs.append(('--calibration-pair', c1, c2))
    failed = {}
    for label, c1, c2 in pairs:
        cal = calibrate(mods, c1, c2, a, lanes, [], led)
        bad = ['%s %d' % (l, k) for l, (k, _, st) in cal.items() if k]
        led.setdefault('calibration', []).append('%s: %s' % (label, ('asymmetric: ' + ', '.join(bad)) if bad else '0 rows on every lane'))
        for l, (k, _, _) in cal.items():
            if k:
                failed[l] = failed.get(l, 0) + k
    for lane, r in res.items():
        if lane in failed and not r['status']:
            r['status'] = 'blocked (lane %s asymmetric: %d rows on the calibration pair)' % (lane, failed[lane])
            r['cands'] = []
        elif not pairs:
            for c in r['cands']:
                c['tags'].append('uncalibrated')
        if r['partial']:
            for c in r['cands']:
                c['tags'].append('partial')
    if not pairs:
        led.setdefault('calibration', []).append('none for %s -> %s: every candidate tagged uncalibrated (pass --calibration-pair)' % ('+'.join(s1), '+'.join(s2)))
    if a.live_v1:
        for r in res.values():
            for c in r['cands']:
                c['tags'].append('live-v1')
    return close_run(led, res, stamp, roots, out, run_dir, True)


def close_run(led, res, stamp, roots, out, run_dir, write_sides):
    if write_sides:
        for lane, r in res.items():
            for side, key in (('v1', 'rows1'), ('v2', 'rows2')):
                if r.get(key):
                    det = led.get('det', {}).get(side, [])
                    used = [m for st, m, _ in det if lane in m.LANES.get(st, {})]
                    write_lane(os.path.join(out, side, lane + '.tsv'), lane, side, led.get('sha', {}).get(side, '-'),
                               led.get('root', {}).get(side, '-'), [st for st, _, _ in det], used, r[key])
    n = emit(res, out, True)
    newer = newer_than(stamp, [r for r in roots if not (r + os.sep).startswith(run_dir + os.sep)])
    led['tail'].append('write check: %d files newer than the run start under %s%s' % (
        len(newer), ', '.join(roots) or '-', (' — ' + ', '.join(newer[:5])) if newer else ''))
    blocked = [l for l, r in res.items() if (r['status'] or '').startswith('blocked') and (led.get('explicit') or 'blocked (gap' not in r['status'])]
    rc = 4 if (newer or LOAD_ERRORS or blocked) else 1 if n else 0
    led['tail'].append('exit %d: %s' % (rc, (   # the reason, so a caller never reads an exit code without it
        'write check hit' if newer else 'a lane module failed to load' if LOAD_ERRORS else
        'blocked lane(s) %s — read the ledger before any row; every route-keyed or blocked lane is BLOCKED, not 0 rows'
        % ','.join(blocked) if blocked else
        '%d candidate row(s) — candidates, not a failure: each needs the refute pass' % n if n else 'ran, no candidates')))
    print_ledger(led, res)
    with open(os.path.join(out, 'ledger.txt'), 'w', encoding='utf-8') as f:
        print_ledger(led, res, f.write)
    return rc


# ---------------------------------------------------------------- built-in calibration pair (Laravel 11 -> Nest 11)
# Parity-clean by construction: every lane must diff to 0 rows. Self-test seeds are single-site edits of it.
CALIBRATION = {'v1': {
    'composer.json': '{"require": {"php": "^8.3", "laravel/framework": "^11.0", "spatie/laravel-permission": "^6.0"}}\n',
    'composer.lock': '{"packages": [{"name": "laravel/framework", "version": "v11.31.0"}]}\n',
    'artisan': '#!/usr/bin/env php\n',
    '.env.example': 'APP_TIMEZONE=Asia/Riyadh\n',
    'config/app.php': "<?php\nreturn [\n    'timezone' => env('APP_TIMEZONE', 'UTC'),\n    'locale' => 'en',\n];\n",
    'bootstrap/app.php': (
        "<?php\nuse Illuminate\\Foundation\\Application;\nuse App\\Exceptions\\OrderLockedException;\n"
        "return Application::configure(basePath: dirname(__DIR__))\n"
        "    ->withRouting(web: __DIR__.'/../routes/web.php', api: __DIR__.'/../routes/api.php', apiPrefix: 'api')\n"
        "    ->withMiddleware(function ($middleware) {\n        $middleware->alias(['admin' => \\App\\Http\\Middleware\\EnsureAdmin::class]);\n    })\n"
        "    ->withExceptions(function ($exceptions) {\n"
        "        $exceptions->render(function (OrderLockedException $e) {\n            return response()->json(['message' => 'locked'], 409);\n        });\n"
        "    })->create();\n"),
    'routes/api.php': (
        "<?php\nuse Illuminate\\Support\\Facades\\Route;\nuse App\\Http\\Controllers\\OrderController;\n"
        "use App\\Http\\Controllers\\InvoiceController;\n\n"
        "Route::middleware('auth:sanctum')->group(function () {\n"
        "    Route::get('/orders', [OrderController::class, 'index'])->middleware('can:orders.view');\n"
        "    Route::post('/orders', [OrderController::class, 'store'])->middleware('can:orders.create');\n"
        "    Route::get('/orders/{order}', [OrderController::class, 'show'])->whereNumber('order')->middleware('can:orders.view');\n"
        "    Route::prefix('admin')->middleware(['admin', 'role:admin'])->group(function () {\n"
        "        Route::delete('/orders/{order}', [OrderController::class, 'destroy'])->whereNumber('order');\n"
        "    });\n"
        "    Route::apiResource('invoices', InvoiceController::class)->only(['index', 'show']);\n"
        "});\n"),
    'routes/web.php': "<?php\nuse Illuminate\\Support\\Facades\\Route;\nRoute::get('/health', fn () => ['ok' => true]);\n",
    'routes/console.php': (
        "<?php\nuse Illuminate\\Support\\Facades\\Schedule;\n"
        "Schedule::command('invoices:generate')->dailyAt('02:00')->timezone('Asia/Riyadh')->withoutOverlapping();\n"),
    'app/Http/Controllers/OrderController.php': (
        "<?php\nnamespace App\\Http\\Controllers;\nuse App\\Http\\Requests\\StoreOrderRequest;\nuse App\\Models\\Order;\n"
        "use App\\Services\\OrderService;\nuse Illuminate\\Support\\Facades\\Mail;\n\n"
        "class OrderController extends Controller\n{\n"
        "    public function __construct(private OrderService $orders) {}\n"
        "    public function index() { return Order::query()->paginate(); }\n"
        "    public function store(StoreOrderRequest $request)\n    {\n"
        "        $order = $this->orders->place($request->validated());\n"
        "        Mail::to($request->user())->send(new \\App\\Mail\\OrderPlaced($order));\n"
        "        return $order;\n    }\n"
        "    public function show(Order $order) { return $order; }\n"
        "    public function destroy(Order $order) { $order->delete(); return response()->noContent(); }\n}\n"),
    'app/Http/Controllers/InvoiceController.php': (
        "<?php\nnamespace App\\Http\\Controllers;\nuse App\\Models\\Invoice;\n"
        "class InvoiceController extends Controller\n{\n"
        "    public function index() { return Invoice::all(); }\n    public function show(Invoice $invoice) { return $invoice; }\n}\n"),
    'app/Http/Requests/StoreOrderRequest.php': (
        "<?php\nnamespace App\\Http\\Requests;\nuse App\\Enums\\OrderStatus;\nuse Illuminate\\Foundation\\Http\\FormRequest;\n"
        "use Illuminate\\Validation\\Rule;\n\n"
        "class StoreOrderRequest extends FormRequest\n{\n    public function authorize(): bool { return true; }\n"
        "    public function rules(): array\n    {\n        return [\n"
        "            'customer_email' => 'required|email|max:255',\n"
        "            'note' => ['nullable', 'string', 'max:500'],\n"
        "            'status' => ['required', Rule::enum(OrderStatus::class)],\n"
        "            'lines' => ['required', 'array', 'min:1'],\n"
        "            'lines.*.qty' => ['required', 'integer', 'min:1'],\n        ];\n    }\n}\n"),
    'app/Enums/OrderStatus.php': (
        "<?php\nnamespace App\\Enums;\n\nenum OrderStatus: string\n{\n    case Pending = 'pending';\n"
        "    case Paid = 'paid';\n    case Cancelled = 'cancelled';\n}\n"),
    'app/Models/Order.php': (
        "<?php\nnamespace App\\Models;\nuse App\\Enums\\OrderStatus;\nuse App\\Models\\Scopes\\TenantScope;\n"
        "use App\\Observers\\OrderObserver;\nuse Illuminate\\Database\\Eloquent\\Attributes\\ObservedBy;\n"
        "use Illuminate\\Database\\Eloquent\\Attributes\\ScopedBy;\nuse Illuminate\\Database\\Eloquent\\Model;\n"
        "use Illuminate\\Database\\Eloquent\\SoftDeletes;\n\n"
        "#[ObservedBy([OrderObserver::class])]\n#[ScopedBy([TenantScope::class])]\n"
        "class Order extends Model\n{\n    use SoftDeletes;\n\n"
        "    protected $casts = ['status' => OrderStatus::class, 'total' => 'decimal:2'];\n}\n"),
    'app/Models/Invoice.php': (
        "<?php\nnamespace App\\Models;\nuse Illuminate\\Database\\Eloquent\\Model;\n\n"
        "class Invoice extends Model\n{\n    protected $table = 'invoices';\n}\n"),
    'app/Observers/OrderObserver.php': (
        "<?php\nnamespace App\\Observers;\nuse App\\Models\\Order;\nuse App\\Jobs\\SyncOrderToErp;\n\n"
        "class OrderObserver\n{\n    public function created(Order $order): void\n    {\n"
        "        SyncOrderToErp::dispatch($order->id);\n        $this->audit->log('order.created', $order->id);\n    }\n}\n"),
    'app/Jobs/SyncOrderToErp.php': "<?php\nnamespace App\\Jobs;\nclass SyncOrderToErp implements \\Illuminate\\Contracts\\Queue\\ShouldQueue {}\n",
    'app/Exceptions/OrderLockedException.php': "<?php\nnamespace App\\Exceptions;\nclass OrderLockedException extends \\RuntimeException {}\n",
    'database/migrations/2024_01_01_000001_create_orders_table.php': (
        "<?php\nuse Illuminate\\Database\\Migrations\\Migration;\nuse Illuminate\\Database\\Schema\\Blueprint;\n"
        "use Illuminate\\Support\\Facades\\Schema;\n\nreturn new class extends Migration {\n    public function up(): void\n    {\n"
        "        Schema::create('orders', function (Blueprint $table) {\n            $table->id();\n"
        "            $table->string('number', 20)->unique();\n            $table->decimal('total', 12, 2);\n"
        "            $table->foreignId('invoice_id')->nullable()->constrained()->nullOnDelete();\n"
        "            $table->softDeletes();\n        });\n    }\n};\n"),
    'app/Services/OrderService.php': (
        "<?php\nnamespace App\\Services;\n\nclass OrderService\n{\n    public function place(array $data) { return $data; }\n"
        "    public function lineTotal(float $price, int $qty): float\n    {\n        return round($price * $qty, 2);\n    }\n}\n"),
}, 'v2': {
    'package.json': '{"dependencies": {"@nestjs/core": "11.1.6", "@nestjs/common": "11.1.6", "@mikro-orm/core": "6.4.0", "decimal.js": "10.4.3"}}\n',
    'Dockerfile': 'FROM node:22-alpine\nENV TZ=Asia/Riyadh\n',
    '.env.example': 'DEFAULT_LOCALE=en\n',
    'src/common/page-query.dto.ts': (
        "import { IsInt, IsOptional, Max } from 'class-validator';\n\nexport class PageQueryDto {\n"
        "  @IsOptional()\n  @IsInt()\n  @Max(100)\n  perPage = 15;\n}\n"),
    'src/main.ts': (
        "import { NestFactory } from '@nestjs/core';\nimport { ValidationPipe } from '@nestjs/common';\n"
        "import { AppModule } from './app.module';\n\nasync function bootstrap() {\n"
        "  const app = await NestFactory.create(AppModule);\n"
        "  app.setGlobalPrefix('api', { exclude: ['health'] });\n"
        "  app.useGlobalPipes(new TrimStringsPipe(), new EmptyStringsToNullPipe(), new ValidationPipe({ whitelist: true, errorHttpStatusCode: 422 }));\n"
        "  await app.listen(3000);\n}\nbootstrap();\n"),
    'src/app.module.ts': (
        "import { Module } from '@nestjs/common';\nimport { APP_GUARD } from '@nestjs/core';\n"
        "import { JwtAuthGuard } from './auth/jwt-auth.guard';\n\n"
        "@Module({ providers: [{ provide: APP_GUARD, useClass: JwtAuthGuard }] })\nexport class AppModule {}\n"),
    'src/auth/decorators.ts': (
        "import { SetMetadata } from '@nestjs/common';\n\nexport const IS_PUBLIC_KEY = 'isPublic';\n"
        "export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);\nexport const PERMISSIONS_KEY = 'permissions';\n"
        "export const Permissions = (...p: string[]) => SetMetadata(PERMISSIONS_KEY, p);\n"
        "export const ROLES_KEY = 'roles';\nexport const Roles = (...r: string[]) => SetMetadata(ROLES_KEY, r);\n"),
    'src/health.controller.ts': (
        "import { Controller, Get } from '@nestjs/common';\nimport { Public } from './auth/decorators';\n\n"
        "@Controller('health')\nexport class HealthController {\n  @Public()\n  @Get()\n  check() {\n    return { ok: true };\n  }\n}\n"),
    'src/orders/orders.controller.ts': (
        "import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Query, UseGuards } from '@nestjs/common';\n"
        "import { Permissions, Roles } from '../auth/decorators';\nimport { AdminGuard } from '../auth/admin.guard';\n"
        "import { CreateOrderDto } from './dto/create-order.dto';\nimport { OrdersService } from './orders.service';\n\n"
        "@Controller('orders')\nexport class OrdersController {\n  constructor(private readonly orders: OrdersService) {}\n\n"
        "  @Get()\n  @Permissions('orders.view')\n  list(@Query('page') page = '1') {\n    return this.orders.list(Math.max(Number(page), 1));\n  }\n\n"
        "  @Post()\n  @Permissions('orders.create')\n  create(@Body() dto: CreateOrderDto) {\n    return this.orders.place(dto);\n  }\n\n"
        "  @Get(':id')\n  @Permissions('orders.view')\n  find(@Param('id', ParseIntPipe) id: number) {\n    return this.orders.find(id);\n  }\n}\n\n"
        "@Controller('admin/orders')\n@UseGuards(AdminGuard)\n@Roles('admin')\nexport class AdminOrdersController {\n"
        "  @Delete(':id')\n  remove(@Param('id', ParseIntPipe) id: number) {\n    return id;\n  }\n}\n"),
    'src/auth/jwt-auth.guard.ts': (
        "import { Injectable } from '@nestjs/common';\nimport { AuthGuard } from '@nestjs/passport';\n\n"
        "@Injectable()\nexport class JwtAuthGuard extends AuthGuard('jwt') {}\n"),
    'src/auth/admin.guard.ts': (
        "import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';\n\n@Injectable()\n"
        "export class AdminGuard implements CanActivate {\n  canActivate(ctx: ExecutionContext): boolean {\n"
        "    return ctx.switchToHttp().getRequest().user?.isAdmin === true;\n  }\n}\n"),
    'src/orders/orders.service.ts': (
        "import { Injectable } from '@nestjs/common';\nimport Decimal from 'decimal.js';\n\n@Injectable()\n"
        "export class OrdersService {\n  constructor(private readonly mailer: MailerService) {}\n\n"
        "  async place(dto: unknown) {\n    await this.mailer.send({ template: 'order-placed' });\n    return dto;\n  }\n"
        "  list(page = 1) {\n    return [page];\n  }\n  find(id: number) {\n    return id;\n  }\n"
        "  lineTotal(price: number, qty: number): number {\n"
        "    return new Decimal(price).times(qty).toDecimalPlaces(2, Decimal.ROUND_HALF_UP).toNumber();\n  }\n}\n"),
    'src/orders/dto/create-order.dto.ts': (
        "import { IsEmail, MaxLength, IsOptional, IsString, IsEnum, IsArray, ArrayMinSize, ValidateNested, IsInt, Min } from 'class-validator';\n"
        "import { Type } from 'class-transformer';\nimport { OrderStatus } from '../order-status.enum';\n\n"
        "export class LineDto {\n  @IsInt()\n  @Min(1)\n  qty!: number;\n}\n\n"
        "export class CreateOrderDto {\n  @IsEmail()\n  @MaxLength(255)\n  customer_email!: string;\n\n"
        "  @IsOptional()\n  @IsString()\n  @MaxLength(500)\n  note?: string | null;\n\n"
        "  @IsEnum(OrderStatus)\n  status!: OrderStatus;\n\n"
        "  @IsArray()\n  @ArrayMinSize(1)\n  @ValidateNested({ each: true })\n  @Type(() => LineDto)\n  lines!: LineDto[];\n}\n"),
    'src/orders/order-status.enum.ts': (
        "export enum OrderStatus {\n  Pending = 'pending',\n  Paid = 'paid',\n  Cancelled = 'cancelled',\n}\n"),
    'src/orders/order.entity.ts': (
        "import { Entity, Enum, Filter, PrimaryKey, Property } from '@mikro-orm/core';\nimport { OrderStatus } from './order-status.enum';\n\n"
        "@Entity({ tableName: 'orders' })\n@Filter({ name: 'softDelete', cond: { deletedAt: null }, default: true })\n"
        "@Filter({ name: 'tenant', cond: (args) => ({ tenantId: args.tenantId }), default: true })\n"
        "export class Order {\n  @PrimaryKey()\n  id!: number;\n\n  @Enum(() => OrderStatus)\n  status!: OrderStatus;\n\n"
        "  @Property({ nullable: true })\n  deletedAt?: Date;\n}\n"),
    'src/orders/order.subscriber.ts': (
        "import { EventArgs, EventSubscriber } from '@mikro-orm/core';\nimport { Order } from './order.entity';\n\n"
        "export class OrderSubscriber implements EventSubscriber<Order> {\n"
        "  getSubscribedEntities() {\n    return [Order];\n  }\n\n"
        "  async afterCreate(args: EventArgs<Order>) {\n    await this.erpQueue.add('sync-order', { id: args.entity.id });\n"
        "    await this.audit.log('order.created', args.entity.id);\n  }\n}\n"),
    'src/orders/order-locked.exception.ts': (
        "import { HttpException } from '@nestjs/common';\n\nexport class OrderLockedException extends HttpException {\n"
        "  constructor() {\n    super('locked', 409);\n  }\n}\n"),
    'src/invoices/invoices.controller.ts': (
        "import { Controller, Get, Param } from '@nestjs/common';\n\n@Controller('invoices')\nexport class InvoicesController {\n"
        "  @Get()\n  list() {\n    return [];\n  }\n\n  @Get(':invoice')\n  find(@Param('invoice') invoice: string) {\n    return invoice;\n  }\n}\n"),
    'src/invoices/invoice.entity.ts': (
        "import { Entity, PrimaryKey } from '@mikro-orm/core';\n\n@Entity({ tableName: 'invoices' })\nexport class Invoice {\n"
        "  @PrimaryKey()\n  id!: number;\n}\n"),
    'src/migrations/Migration20240101000000.ts': (
        "import { Migration } from '@mikro-orm/migrations';\n\nexport class Migration20240101000000 extends Migration {\n"
        "  async up(): Promise<void> {\n"
        "    this.addSql('create table \"orders\" (\"id\" bigserial primary key, \"number\" varchar(20) not null, \"total\" numeric(12,2) not null, \"invoice_id\" bigint null, \"deleted_at\" timestamptz null);');\n"
        "    this.addSql('alter table \"orders\" add constraint \"orders_number_unique\" unique (\"number\");');\n"
        "    this.addSql('alter table \"orders\" add constraint \"orders_invoice_id_foreign\" foreign key (\"invoice_id\") references \"invoices\" (\"id\") on delete set null;');\n"
        "  }\n}\n"),
    'src/invoices/invoices.scheduler.ts': (
        "import { Injectable } from '@nestjs/common';\nimport { Cron } from '@nestjs/schedule';\n\n@Injectable()\n"
        "export class InvoicesScheduler {\n  @Cron('0 2 * * *', { name: 'invoices:generate', timeZone: 'Asia/Riyadh', waitForCompletion: true })\n"
        "  async generateInvoices() {\n    return;\n  }\n}\n"),
}}


# ---------------------------------------------------------------- built-in calibration pair (Supabase -> Nest 11)
# The same rules over a Supabase V1 (SQL migrations replayed, RLS, PostgREST RPC, pg_cron, one edge function) and a
# Nest V2 that serves the same surface. Parity-clean by construction: every lane must diff to 0 rows.
_SB_MIG = """create type public.order_status as enum ('pending', 'paid');
alter type public.order_status add value 'cancelled';

create table public.invoices (
  id bigserial primary key,
  user_id uuid not null,
  kind text not null default 'standard' check (kind in ('standard', 'credit'))
);

create table public.orders (
  id bigserial primary key,
  workspace_id uuid not null,
  number varchar(20) not null,
  status public.order_status not null default 'pending',
  total numeric(12,2) not null,
  invoice_id bigint references public.invoices (id) on delete set null,
  deleted_at timestamptz
);
alter table public.orders add constraint orders_number_unique unique (number);

create table public.audit_logs (
  id bigserial primary key,
  entity text not null,
  entity_id bigint not null
);

alter table public.orders enable row level security;
alter table public.invoices enable row level security;
alter table public.audit_logs enable row level security;

create or replace function public.has_workspace_permission(_ws uuid, _perm text) returns boolean
language sql stable security definer as $$ select auth.uid() is not null and _perm is not null and _ws is not null $$;
revoke execute on function public.has_workspace_permission(uuid, text) from public, anon, authenticated;

create policy "orders read" on public.orders for select to authenticated
  using (deleted_at is null and public.has_workspace_permission(workspace_id, 'orders.view'));
create policy "invoices read" on public.invoices for select to authenticated using (auth.uid() = user_id);

create or replace function public.order_total(p_price numeric, p_qty integer) returns numeric
language plpgsql stable as $$
begin
  if p_price is null then
    raise exception 'price_required' using errcode = '22023';
  end if;
  if p_qty is null or p_qty < 1 then
    raise exception 'qty_too_small';
  end if;
  return round(p_price * p_qty, 2);
end;
$$;
revoke execute on function public.order_total(numeric, integer) from public, anon;
grant execute on function public.order_total(numeric, integer) to authenticated;

create or replace function public.log_order_created() returns trigger language plpgsql security definer as $$
begin
  insert into public.audit_logs (entity, entity_id) values ('order', new.id);
  return new;
end;
$$;
create trigger orders_audit after insert on public.orders for each row execute function public.log_order_created();

create or replace function public.generate_invoices() returns void language sql as $$ select 1 $$;
revoke execute on function public.generate_invoices() from public, anon, authenticated;
select cron.schedule('invoices-generate', '0 2 * * *', $$select public.generate_invoices()$$);

alter database postgres set timezone to 'Asia/Riyadh';
"""
_SB_ZOD = """export const CreateOrder = z.object({
  customer_email: z.string().email().max(255),
  note: z.string().max(500).nullish(),
  status: z.enum(['pending', 'paid', 'cancelled']),
});
"""
CALIBRATION_SUPABASE = {'v1': {
    'supabase/config.toml': 'project_id = "calibration"\n\n[api]\nmax_rows = 1000\n\n[functions.create-order]\nverify_jwt = true\n',
    'supabase/migrations/20240101000000_init.sql': _SB_MIG,
    'supabase/functions/_shared/enforce-permission.ts': (
        "import { createClient } from 'npm:@supabase/supabase-js@2';\n\n"
        "export async function enforcePermission(req: Request, permKey: string): Promise<Response | null> {\n"
        "  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {\n"
        "    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },\n  });\n"
        "  const { error } = await supabase.rpc('enforce_permission', { _perm: permKey });\n"
        "  return error ? new Response(null, { status: 403 }) : null;\n}\n"),
    'supabase/functions/create-order/index.ts': (
        "import { createClient } from 'npm:@supabase/supabase-js@2';\nimport { z } from 'npm:zod@3';\n"
        "import { enforcePermission } from '../_shared/enforce-permission.ts';\n\n" + _SB_ZOD + "\n"
        "function json(body: unknown, status: number) {\n"
        "  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });\n}\n\n"
        "Deno.serve(async (req) => {\n  if (req.method === 'OPTIONS') return new Response('ok');\n"
        "  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {\n"
        "    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },\n  });\n"
        "  const { data: { user } } = await supabase.auth.getUser();\n"
        "  if (!user) return json({ message: 'Unauthorized' }, 401);\n"
        "  const denied = await enforcePermission(req, 'orders.create');\n  if (denied) return denied;\n"
        "  const parsed = CreateOrder.safeParse(await req.json());\n"
        "  if (!parsed.success) return json({ message: 'invalid' }, 400);\n"
        "  const { data: existing } = await supabase.from('orders').select('id').eq('number', 'x').maybeSingle();\n"
        "  if (existing) return json({ error: 'order_locked' }, 409);\n"
        "  await fetch('https://api.resend.com/emails', { method: 'POST', body: JSON.stringify({ to: parsed.data.customer_email }) });\n"
        "  return json({ ok: true }, 201);\n});\n"),
}, 'v2': {
    'package.json': '{"dependencies": {"@nestjs/core": "11.1.6", "@nestjs/common": "11.1.6", "@mikro-orm/core": "6.4.0", "decimal.js": "10.4.3", "zod": "3.23.8"}}\n',
    'Dockerfile': 'FROM node:22-alpine\nENV TZ=Asia/Riyadh\n',
    'src/main.ts': (
        "import { NestFactory } from '@nestjs/core';\nimport { AppModule } from './app.module';\n\n"
        "async function bootstrap() {\n  const app = await NestFactory.create(AppModule);\n  await app.listen(3000);\n}\nbootstrap();\n"),
    'src/app.module.ts': (
        "import { Module } from '@nestjs/common';\nimport { APP_GUARD } from '@nestjs/core';\n"
        "import { JwtAuthGuard } from './auth/jwt-auth.guard';\n\n"
        "@Module({ providers: [{ provide: APP_GUARD, useClass: JwtAuthGuard }] })\nexport class AppModule {}\n"),
    'src/auth/decorators.ts': (
        "import { SetMetadata } from '@nestjs/common';\n\nexport const PERMISSIONS_KEY = 'permissions';\n"
        "export const Permissions = (...p: string[]) => SetMetadata(PERMISSIONS_KEY, p);\n"),
    'src/auth/jwt-auth.guard.ts': (
        "import { Injectable } from '@nestjs/common';\nimport { AuthGuard } from '@nestjs/passport';\n\n"
        "@Injectable()\nexport class JwtAuthGuard extends AuthGuard('jwt') {}\n"),
    'src/common/zod-validation.pipe.ts': (
        "import { BadRequestException, PipeTransform } from '@nestjs/common';\nimport { ZodSchema } from 'zod';\n\n"
        "export class ZodValidationPipe implements PipeTransform {\n  constructor(private readonly schema: ZodSchema) {}\n\n"
        "  transform(value: unknown) {\n    const r = this.schema.safeParse(value);\n    if (!r.success) {\n"
        "      throw new BadRequestException('invalid');\n    }\n    return r.data;\n  }\n}\n"),
    'src/common/pagination.ts': 'export const DEFAULT_PAGE_SIZE = 1000;\n',
    'src/orders/create-order.schema.ts': "import { z } from 'zod';\n\n" + _SB_ZOD + "export type CreateOrderInput = z.infer<typeof CreateOrder>;\n",
    'src/orders/create-order.controller.ts': (
        "import { Body, Controller, Post } from '@nestjs/common';\nimport { Permissions } from '../auth/decorators';\n"
        "import { ZodValidationPipe } from '../common/zod-validation.pipe';\nimport { CreateOrder, CreateOrderInput } from './create-order.schema';\n"
        "import { OrdersService } from './orders.service';\n\n"
        "@Controller('functions/v1/create-order')\nexport class CreateOrderController {\n"
        "  constructor(private readonly orders: OrdersService) {}\n\n"
        "  @Post()\n  @Permissions('orders.create')\n  create(@Body(new ZodValidationPipe(CreateOrder)) body: CreateOrderInput) {\n"
        "    return this.orders.place(body);\n  }\n}\n"),
    'src/rest/order-total.dto.ts': (
        "import { IsInt, IsNumber, Min } from 'class-validator';\n\nexport class OrderTotalDto {\n"
        "  @IsNumber()\n  p_price!: number;\n\n  @IsInt()\n  @Min(1)\n  p_qty!: number;\n}\n"),
    'src/rest/rest.controller.ts': (
        "import { BadRequestException, Body, Controller, Get, Post } from '@nestjs/common';\nimport { Permissions } from '../auth/decorators';\n"
        "import { OrderTotalDto } from './order-total.dto';\n\n"
        "@Controller('rest/v1')\nexport class RestController {\n"
        "  @Get('orders')\n  @Permissions('orders.view')\n  listOrders() {\n    return [];\n  }\n\n"
        "  @Get('invoices')\n  listInvoices() {\n    return [];\n  }\n\n"
        "  @Post('rpc/order_total')\n  orderTotal(@Body() dto: OrderTotalDto) {\n"
        "    if (dto.p_price == null) {\n      throw new BadRequestException({ code: 'price_required' });\n    }\n"
        "    if (dto.p_qty < 1) {\n      throw new BadRequestException({ code: 'qty_too_small' });\n    }\n    return dto;\n  }\n}\n"),
    'src/orders/orders.service.ts': (
        "import { ConflictException, Injectable } from '@nestjs/common';\nimport Decimal from 'decimal.js';\n\n@Injectable()\n"
        "export class OrdersService {\n  constructor(private readonly mailer: MailerService) {}\n\n"
        "  async place(dto: { customer_email: string }) {\n    if (dto.customer_email === 'locked') {\n"
        "      throw new ConflictException({ code: 'order_locked' });\n    }\n"
        "    await this.mailer.send({ template: 'order-placed' });\n    return dto;\n  }\n\n"
        "  lineTotal(price: number, qty: number): number {\n"
        "    return new Decimal(price).times(qty).toDecimalPlaces(2, Decimal.ROUND_HALF_UP).toNumber();\n  }\n}\n"),
    'src/orders/order-status.enum.ts': "export enum OrderStatus {\n  Pending = 'pending',\n  Paid = 'paid',\n  Cancelled = 'cancelled',\n}\n",
    'src/orders/order.entity.ts': (
        "import { Entity, Enum, Filter, PrimaryKey, Property } from '@mikro-orm/core';\nimport { OrderStatus } from './order-status.enum';\n\n"
        "@Entity({ tableName: 'orders' })\n@Filter({ name: 'softDelete', cond: { deletedAt: null }, default: true })\n"
        "@Filter({ name: 'workspace', cond: (args) => ({ workspaceId: args.workspaceId }), default: true })\n"
        "export class Order {\n  @PrimaryKey()\n  id!: number;\n\n  @Enum(() => OrderStatus)\n  status!: OrderStatus;\n\n"
        "  @Property({ nullable: true })\n  deletedAt?: Date;\n}\n"),
    'src/invoices/invoice.entity.ts': (
        "import { Entity, Enum, Filter, PrimaryKey } from '@mikro-orm/core';\n\n@Entity({ tableName: 'invoices' })\n"
        "@Filter({ name: 'account', cond: (args) => ({ userId: args.userId }), default: true })\n"
        "export class Invoice {\n  @PrimaryKey()\n  id!: number;\n\n  @Enum({ items: ['standard', 'credit'] })\n  kind!: string;\n}\n"),
    'src/audit/audit-log.entity.ts': (
        "import { Entity, PrimaryKey } from '@mikro-orm/core';\n\n@Entity({ tableName: 'audit_logs' })\n"
        "export class AuditLog {\n  @PrimaryKey()\n  id!: number;\n}\n"),
    'src/orders/order.subscriber.ts': (
        "import { EventArgs, EventSubscriber } from '@mikro-orm/core';\nimport { Order } from './order.entity';\n\n"
        "export class OrderSubscriber implements EventSubscriber<Order> {\n  getSubscribedEntities() {\n    return [Order];\n  }\n\n"
        "  async afterCreate(args: EventArgs<Order>) {\n    await this.audit.log('order.created', args.entity.id);\n  }\n}\n"),
    'src/invoices/invoices.scheduler.ts': (
        "import { Injectable } from '@nestjs/common';\nimport { Cron } from '@nestjs/schedule';\n\n@Injectable()\n"
        "export class InvoicesScheduler {\n  @Cron('0 2 * * *', { name: 'invoices-generate', timeZone: 'UTC', waitForCompletion: true })\n"
        "  async generateInvoices() {\n    return;\n  }\n}\n"),
    'src/migrations/Migration20240101000000.ts': (
        "import { Migration } from '@mikro-orm/migrations';\n\nexport class Migration20240101000000 extends Migration {\n"
        "  async up(): Promise<void> {\n"
        "    this.addSql('create table \"invoices\" (\"id\" bigserial primary key, \"user_id\" uuid not null, \"kind\" text not null);');\n"
        "    this.addSql('create table \"orders\" (\"id\" bigserial primary key, \"workspace_id\" uuid not null, \"number\" varchar(20) not null, \"status\" text not null, \"total\" numeric(12,2) not null, \"invoice_id\" bigint null, \"deleted_at\" timestamptz null);');\n"
        "    this.addSql('alter table \"orders\" add constraint \"orders_number_unique\" unique (\"number\");');\n"
        "    this.addSql('alter table \"orders\" add constraint \"orders_invoice_id_foreign\" foreign key (\"invoice_id\") references \"invoices\" (\"id\") on delete set null;');\n"
        "    this.addSql('create table \"audit_logs\" (\"id\" bigserial primary key, \"entity\" text not null, \"entity_id\" bigint not null);');\n"
        "  }\n}\n"),
}}

SEEDS_SUPABASE = [  # (lane, side, file, old, new, expected diff, expected attr) — single-site edits of the clean Supabase pair
    ('I-ROUTES', 'v2', 'src/rest/rest.controller.ts', "@Post('rpc/order_total')", "@Post('rpc/order_totals')", 'V1-ONLY', '-'),
    ('I-AUTHZ', 'v2', 'src/rest/rest.controller.ts', "  @Get('orders')\n  @Permissions('orders.view')\n", "  @Get('orders')\n", 'CHANGED', 'abilities'),
    ('I-AUTHZ', 'v1', 'supabase/migrations/20240101000000_init.sql', "revoke execute on function public.order_total(numeric, integer) from public, anon;\n", '', 'CHANGED', 'authn'),
    ('I-RULES', 'v2', 'src/orders/create-order.schema.ts', '.max(255)', '.max(500)', 'CHANGED', 'max'),
    ('I-RULES', 'v1', 'supabase/migrations/20240101000000_init.sql', 'if p_qty is null or p_qty < 1 then', 'if p_qty is null or p_qty < 0 then', 'CHANGED', 'min'),
    ('I-ENUM', 'v2', 'src/orders/order-status.enum.ts', "  Cancelled = 'cancelled',\n", '', 'CHANGED', 'values'),
    ('I-ENUM', 'v1', 'supabase/migrations/20240101000000_init.sql', "alter type public.order_status add value 'cancelled';\n", '', 'CHANGED', 'values'),
    ('I-ERR', 'v2', 'src/orders/orders.service.ts', "new ConflictException({ code: 'order_locked' })", "new BadRequestException({ code: 'order_locked' })", 'CHANGED', 'status'),
    ('I-ERR', 'v1', 'supabase/migrations/20240101000000_init.sql', "'price_required' using errcode = '22023'", "'price_required' using errcode = 'PT422'", 'CHANGED', 'status'),
    ('I-SIDE', 'v2', 'src/orders/orders.service.ts', "    await this.mailer.send({ template: 'order-placed' });\n", '', 'V1-ONLY', '-'),
    ('I-SIDE', 'v2', 'src/orders/order.subscriber.ts', "    await this.audit.log('order.created', args.entity.id);\n", '', 'V1-ONLY', '-'),
    ('I-SCHED', 'v2', 'src/invoices/invoices.scheduler.ts', "'0 2 * * *'", "'0 3 * * *'", 'CHANGED', 'cron'),
    ('I-SCHED', 'v1', 'supabase/migrations/20240101000000_init.sql', "alter database postgres", "select cron.unschedule('invoices-generate');\nalter database postgres", 'V2-ONLY', '-'),
    ('I-SCOPE', 'v2', 'src/orders/order.entity.ts', "@Filter({ name: 'workspace', cond: (args) => ({ workspaceId: args.workspaceId }), default: true })\n", '', 'CHANGED', 'tenant'),
    ('I-SCOPE', 'v1', 'supabase/migrations/20240101000000_init.sql', "using (deleted_at is null and public.has", "using (public.has", 'CHANGED', 'soft_delete'),
    ('I-SCHEMA', 'v2', 'src/migrations/Migration20240101000000.ts', '"total" numeric(12,2) not null', '"total" numeric(12,2) null', 'CHANGED', 'null'),
    ('I-SCHEMA', 'v1', 'supabase/migrations/20240101000000_init.sql', "alter database postgres", "alter table public.orders drop constraint orders_number_unique;\nalter database postgres", 'V2-ONLY', '-'),
    ('I-MONEY', 'v2', 'src/orders/orders.service.ts', 'new Decimal(price).times(qty).toDecimalPlaces(2, Decimal.ROUND_HALF_UP).toNumber()',
     'Math.round(price * qty * 100) / 100', 'CHANGED', 'modes'),
    ('I-CONF', 'v2', 'Dockerfile', 'ENV TZ=Asia/Riyadh', 'ENV TZ=UTC', 'CHANGED', 'value'),
    ('I-ROUTES', 'v1', 'supabase/migrations/20240101000000_init.sql', 'to authenticated using (auth.uid() = user_id)',
     'to authenticated using (false)', 'V2-ONLY', '-'),
]


# ---------------------------------------------------------------- self-test
SEEDS = [  # (lane, file, old, new, expected diff, expected attr) — each a single-site edit of the clean V2
    ('I-ROUTES', 'src/invoices/invoices.controller.ts', "  @Get(':invoice')", "  @Get(':invoice/x')", 'V1-ONLY', '-'),
    ('I-ROUTES', 'src/orders/orders.controller.ts', "@Param('id', ParseIntPipe) id: number) {\n    return this.orders",
     "@Param('id') id: number) {\n    return this.orders", 'CHANGED', 'constraint'),
    ('I-AUTHZ', 'src/orders/orders.controller.ts', "  @Post()\n  @Permissions('orders.create')", "  @Post()", 'CHANGED', 'abilities'),
    ('I-AUTHZ', 'src/orders/orders.controller.ts', "@UseGuards(AdminGuard)\n", '', 'CHANGED', 'extra_guard'),
    ('I-AUTHZ', 'src/orders/orders.controller.ts', "  @Get()\n  @Permissions('orders.view')\n  list",
     "  @Get()\n  @Public()\n  @Permissions('orders.view')\n  list", 'CHANGED', 'authn'),
    ('I-RULES', 'src/orders/dto/create-order.dto.ts', '@MaxLength(255)', '@MaxLength(500)', 'CHANGED', 'max'),
    ('I-RULES', 'src/main.ts', 'new TrimStringsPipe(), ', '', 'CHANGED', 'on'),
    ('I-ENUM', 'src/orders/order-status.enum.ts', "  Cancelled = 'cancelled',\n", '', 'CHANGED', 'values'),
    ('I-ERR', 'src/main.ts', ', errorHttpStatusCode: 422', '', 'CHANGED', 'status'),
    ('I-ERR', 'src/orders/order-locked.exception.ts', "super('locked', 409)", "super('locked', 400)", 'CHANGED', 'status'),
    ('I-SIDE', 'src/orders/orders.service.ts', "    await this.mailer.send({ template: 'order-placed' });\n", '', 'V1-ONLY', '-'),
    ('I-SIDE', 'src/orders/order.subscriber.ts', "    await this.audit.log('order.created', args.entity.id);\n", '', 'CHANGED', 'kinds'),
    ('I-SCHED', 'src/invoices/invoices.scheduler.ts', "'0 2 * * *'", "'0 3 * * *'", 'CHANGED', 'cron'),
    ('I-SCHED', 'src/invoices/invoices.scheduler.ts', ", waitForCompletion: true", '', 'CHANGED', 'overlap'),
    ('I-SCOPE', 'src/orders/order.entity.ts', "@Filter({ name: 'softDelete', cond: { deletedAt: null }, default: true })\n", '', 'CHANGED', 'soft_delete'),
    ('I-SCOPE', 'src/orders/order.entity.ts', "@Filter({ name: 'tenant', cond: (args) => ({ tenantId: args.tenantId }), default: true })\n", '', 'CHANGED', 'tenant'),
    ('I-SCHEMA', 'src/migrations/Migration20240101000000.ts', "    this.addSql('alter table \"orders\" add constraint \"orders_number_unique\" unique (\"number\");');\n", '', 'V1-ONLY', '-'),
    ('I-SCHEMA', 'src/migrations/Migration20240101000000.ts', '"total" numeric(12,2) not null', '"total" numeric(12,2) null', 'CHANGED', 'null'),
    ('I-MONEY', 'src/orders/orders.service.ts', 'new Decimal(price).times(qty).toDecimalPlaces(2, Decimal.ROUND_HALF_UP).toNumber()',
     'Math.round(price * qty * 100) / 100', 'CHANGED', 'modes'),
    ('I-CONF', 'Dockerfile', 'ENV TZ=Asia/Riyadh', 'ENV TZ=UTC', 'CHANGED', 'value'),
]


def self_test():
    fails, t0 = [], time.time()
    tmp = tempfile.mkdtemp(prefix='pair-inventory-selftest.', dir=os.environ.get('TMPDIR') or None)
    devnull = open(os.devnull, 'w')
    real_out, real_err = sys.stdout, sys.stderr

    def check(name, ok, info=''):
        real_out.write('  %s %s%s\n' % ('ok  ' if ok else 'FAIL', name, (' — ' + info) if (info and not ok) else ''))
        if not ok:
            fails.append(name)

    def quiet(fn, *args):
        sys.stdout, sys.stderr = devnull, devnull
        try:
            return fn(*args)
        finally:
            sys.stdout, sys.stderr = real_out, real_err
    try:
        mods = load_modules()
        check('lane modules load (%s)' % ', '.join(sorted(mods)), set(mods) == set(MODULES))
        v1, v2 = builtin_pair(os.path.join(tmp, 'pair'))
        args = argparse.Namespace(stack_v1=[], stack_v2=[], all=False)
        led = {}
        cal = quiet(calibrate, mods, v1, v2, args, LANES, [], led)
        for lane in LANES:
            k, cands, st = cal[lane]
            want_blocked = False
            ok = (k == 0 and not st) if not want_blocked else (st or '').startswith('blocked')
            check('calibration %s -> %s' % (lane, st or '0 rows'), ok, '; '.join('%s %s %s %s|%s' % (c['diff'], c['key'], c['attr'], c['v1'], c['v2']) for c in cands[:4]))
        s1 = detect(mods, v1, [])
        e1, _ = quiet(extract, mods, v1, 'v1', s1, LANES)
        counts = dict((l, len(e1[l]['rows'])) for l in LANES)
        check('v1 lanes non-empty %s' % counts, all(counts[l] for l in LANES))
        for lane, rel, old, new, want, attr in SEEDS:
            sv2 = os.path.join(tmp, 'seed', lane + '-' + str(SEEDS.index((lane, rel, old, new, want, attr))))
            shutil.copytree(v2, sv2)
            p = os.path.join(sv2, rel)
            with open(p, encoding='utf-8') as f:
                body = f.read()
            if old not in body:
                check('seed %s %s' % (lane, attr), False, 'seed text not found in %s' % rel)
                continue
            with open(p, 'w', encoding='utf-8') as f:
                f.write(body.replace(old, new, 1))
            r = quiet(calibrate, mods, v1, sv2, args, [lane], [], {})
            k, cands, st = r[lane]
            hit = [c for c in cands if c['diff'] == want and c['attr'] == attr]
            check('seed %s %s %s -> %d candidate(s)' % (lane, want, attr, k), bool(hit) and not st,
                  '; '.join('%s %s %s' % (c['diff'], c['key'], c['attr']) for c in cands[:4]) or st)
        # the built-in Supabase -> Nest pair: 0 rows on every lane, then single-site seeds on either side
        sv1, sv2 = builtin_pair(os.path.join(tmp, 'pair-supabase'), CALIBRATION_SUPABASE)
        cal = quiet(calibrate, mods, sv1, sv2, args, LANES, [], {})
        for lane in LANES:
            k, cands, st = cal[lane]
            check('supabase->nest calibration %s -> %s' % (lane, st or '0 rows'), k == 0 and not st,
                  '; '.join('%s %s %s %s|%s' % (c['diff'], c['key'], c['attr'], c['v1'], c['v2']) for c in cands[:4]))
        e1s, _ = quiet(extract, mods, sv1, 'v1', detect(mods, sv1, []), LANES)
        counts = dict((l, len(e1s[l]['rows'])) for l in LANES)
        check('supabase v1 lanes non-empty %s' % counts, all(counts[l] for l in LANES))
        for i, (lane, side, rel, old, new, want, attr) in enumerate(SEEDS_SUPABASE):
            d = os.path.join(tmp, 'seed-supabase', str(i))
            shutil.copytree(sv1, os.path.join(d, 'v1'))
            shutil.copytree(sv2, os.path.join(d, 'v2'))
            p = os.path.join(d, side, rel)
            with open(p, encoding='utf-8') as f:
                body = f.read()
            if old not in body:
                check('supabase seed %s %s %s' % (lane, side, attr), False, 'seed text not found in %s' % rel)
                continue
            with open(p, 'w', encoding='utf-8') as f:
                f.write(body.replace(old, new, 1))
            r = quiet(calibrate, mods, os.path.join(d, 'v1'), os.path.join(d, 'v2'), args, [lane], [], {})
            k, cands, st = r[lane]
            hit = [c for c in cands if c['diff'] == want and c['attr'] == attr]
            check('supabase seed %s (%s edit) %s %s -> %d candidate(s)' % (lane, side, want, attr, k), bool(hit) and not st,
                  '; '.join('%s %s %s' % (c['diff'], c['key'], c['attr']) for c in cands[:4]) or st)
        # prefix sanity: a V2 that mounts everything under another prefix halts I-ROUTES, a prefix row fixes it
        pv2 = os.path.join(tmp, 'prefix-v2')
        shutil.copytree(v2, pv2)
        mp = os.path.join(pv2, 'src', 'main.ts')
        with open(mp, encoding='utf-8') as f:
            body = f.read()
        with open(mp, 'w', encoding='utf-8') as f:
            f.write(body.replace("setGlobalPrefix('api'", "setGlobalPrefix('v2'"))
        r = quiet(calibrate, mods, v1, pv2, args, ['I-ROUTES', 'I-AUTHZ'], [], {})
        check('prefix sanity halts I-ROUTES and blocks I-AUTHZ', 'prefix sanity' in (r['I-ROUTES'][2] or '') and 'prefix sanity' in (r['I-AUTHZ'][2] or ''), str(r['I-ROUTES'][:1]) + str(r['I-ROUTES'][2]))
        rules = [{'lane': 'I-ROUTES', 'v1': 'prefix:/api', 'v2': 'prefix:/v2', 'reason': 'ADR-001'}]
        r = quiet(calibrate, mods, v1, pv2, args, ['I-ROUTES'], rules, {})
        check('pair-map prefix row -> 0 rows', r['I-ROUTES'][0] == 0 and not r['I-ROUTES'][2], str(r['I-ROUTES']))
        pm = os.path.join(tmp, 'pm.tsv')
        with open(pm, 'w') as f:
            f.write('I-ROUTES\tGET /api/orders\tGET /api/o\t\nI-ROUTES\tDELETE /api/admin/orders/{}\t-\tADR-002\n')
        rl, ign = read_pair_map(pm)
        check('pair-map row without a reason is ignored and printed', len(rl) == 1 and len(ign) == 1)
        # IR-1: a V2-only key acknowledged (one I-ROUTES row covers the route's AUTHZ row too), an ADR-backed value accepted
        av2 = os.path.join(tmp, 'ack-v2')
        shutil.copytree(v2, av2)
        for rel, old, new in (('src/invoices/invoices.controller.ts', "  @Get(':invoice')", "  @Get('extra')\n  extra() {\n    return 1;\n  }\n\n  @Get(':invoice')"),
                              ('src/orders/order-status.enum.ts', "  Cancelled = 'cancelled',\n", '')):
            with open(os.path.join(av2, rel), encoding='utf-8') as f:
                body = f.read()
            with open(os.path.join(av2, rel), 'w', encoding='utf-8') as f:
                f.write(body.replace(old, new, 1))
        r0 = quiet(calibrate, mods, v1, av2, args, ['I-ROUTES', 'I-AUTHZ', 'I-ENUM'], [], {})
        with open(pm, 'w') as f:
            f.write('I-ROUTES\t-\tGET /api/invoices/extra\tADR-0002\n*\t*\t*\tADR-0003 drop cancelled\tvalues=paid,pending\n'
                    'I-ENUM\t*\t*\trename\tvalues=paid\n')
        rl, ign = read_pair_map(pm)
        r1 = quiet(calibrate, mods, v1, av2, args, ['I-ROUTES', 'I-AUTHZ', 'I-ENUM'], rl, {})
        check('IR-1: V2-only ack + ADR-backed attr row close %s rows; an attr row without an ADR is ignored'
              % sum(r0[l][0] for l in r0), sum(r0[l][0] for l in r0) >= 4 and all(r1[l][0] == 0 for l in r1) and len(ign) == 1,
              str(dict((l, r1[l][0]) for l in r1)))
        # IR-1: explicit rename rows address keys -> route-join on them; the unaddressed remainder keeps the halt
        jr = [{'lane': 'I-ROUTES', 'v1': 'GET /api/orders', 'v2': 'GET /v2/invoices', 'reason': 'ADR-010', 'attr': ''},
              {'lane': 'I-ROUTES', 'v1': 'GET /api/invoices', 'v2': 'GET /v2/nothing', 'reason': 'ADR-011', 'attr': ''}]
        r0 = quiet(calibrate, mods, v1, pv2, args, ['I-ROUTES', 'I-AUTHZ'], [], {})
        r1 = quiet(calibrate, mods, v1, pv2, args, ['I-ROUTES', 'I-AUTHZ'], jr, {})
        ok = ((r0['I-ROUTES'][2] or '').startswith('blocked') and (r1['I-ROUTES'][2] or '').startswith('checked · route-join')
              and [(c['diff'], c['key']) for c in r1['I-ROUTES'][1]] == [('V1-ONLY', 'GET /v2/nothing')]
              and any(c['key'] == 'GET /v2/invoices' and c['attr'] == 'abilities' for c in r1['I-AUTHZ'][1])
              and all(route_of(c['key']) in ('GET /v2/invoices', 'GET /v2/nothing') for c in r1['I-AUTHZ'][1]))
        check('IR-1: rename rows join their routes past the prefix halt (before: %s)' % (r0['I-ROUTES'][2] or '')[:40], ok,
              '%s | %s | %s' % (r1['I-ROUTES'][2], r1['I-ROUTES'][1][:3], [(c['key'], c['attr']) for c in r1['I-AUTHZ'][1]]))
        # IR-2: two V1 keys renamed onto one V2 key are merged and tagged, never overwritten
        cr = [{'lane': 'I-ROUTES', 'v1': 'GET /api/orders', 'v2': 'GET /api/invoices', 'reason': 'ADR-012', 'attr': ''}]
        rc2 = quiet(calibrate, mods, v1, v2, args, ['I-AUTHZ'], cr, {})
        hit = [c for c in rc2['I-AUTHZ'][1] if c['key'] == 'GET /api/invoices' and any(t.startswith('collided(') for t in c['tags'])]
        check('IR-2: a map collision is merged (abilities %s) and tagged collided' % (hit[0]['v1'] if hit else '-'),
              bool(hit) and 'orders.view' in hit[0]['v1'], str(rc2['I-AUTHZ'][1][:3]))
        # IR-10: a glob column rename carries its capture and renames the column inside unique/fk keys; hints suggest it
        rows = {'col:order.user_id': {'key': 'col:order.user_id', 'attrs': {'null': 'no'}, 'at': 'a:1', 'excerpt': ''},
                'unique:order(number,user_id)': {'key': 'unique:order(number,user_id)', 'attrs': {}, 'at': 'a:2', 'excerpt': ''},
                'fk:order(user_id)': {'key': 'fk:order(user_id)', 'attrs': {'ref': 'user'}, 'at': 'a:3', 'excerpt': ''}}
        mr, _ = apply_map('I-SCHEMA', rows, [{'lane': 'I-SCHEMA', 'v1': 'col:*.user_id', 'v2': 'col:*.tenant_id', 'reason': 'ADR-013', 'attr': ''}])
        hints = rename_hints([{'diff': 'V1-ONLY', 'key': 'unique:%s(user_id,x)' % t} for t in 'abc'] +
                             [{'diff': 'V2-ONLY', 'key': 'unique:%s(tenant_id,x)' % t} for t in 'abc'])
        check('IR-10: glob column rename -> %s; hint %s' % (sorted(mr), hints[:1]),
              sorted(mr) == ['col:order.tenant_id', 'fk:order(tenant_id)', 'unique:order(number,tenant_id)']
              and hints and hints[0].startswith('I-SCHEMA\tcol:*.user_id\tcol:*.tenant_id'))
        # rg exit 2 is BLOCKED, never zero files
        try:
            H(v1, 'v1').files(['*.php'], pattern='x(')
            check('rg exit 2 -> Blocked', False, 'no exception')
        except Blocked:
            check('rg exit 2 -> Blocked', True)
        # write-free snapshot at a pinned SHA, immune to a moving checkout; record -> solo round trip
        if shutil.which('git'):
            groot = os.path.join(tmp, 'git-repo')     # V1 in a subdirectory of its repo (the archive must not filter it)
            gv1 = os.path.join(groot, 'legacy', 'v1')
            shutil.copytree(v1, gv1)
            env = dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t',
                       GIT_COMMITTER_EMAIL='t@t', GIT_CONFIG_NOSYSTEM='1', HOME=tmp)
            for c in (['init', '-q'], ['add', '-A'], ['commit', '-q', '-m', 'v1']):
                subprocess.run(['git', '-C', groot] + c, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            rc, sha, _ = git(['-C', gv1, 'rev-parse', 'HEAD'])
            with open(os.path.join(gv1, 'routes', 'api.php'), 'a') as f:
                f.write("Route::get('/uncommitted', fn () => 1);\n")
            outp = os.path.join(tmp, 'out-paired')
            rc = quiet(main, ['--v1=' + gv1, '--v2=' + v2, '--pin=' + sha, '--out=' + outp])
            with open(os.path.join(outp, 'candidates.tsv')) as f:
                cands = [l for l in f if l.startswith('CANDIDATE')]
            check('paired via git archive at the pin: 0 candidates, uncommitted V1 edit invisible (exit %s)' % rc, rc == 0 and not cands, ''.join(cands[:3]))
            with open(os.path.join(outp, 'ledger.txt')) as f:
                lt = f.read()
            check('write check prints 0 newer files', 'write check: 0 files' in lt, lt[-300:])
            check('the ledger prints the exit reason', 'exit 0: ran, no candidates' in lt, lt[-300:])
            rec = os.path.join(tmp, 'v1-inventory')
            rc = quiet(main, ['--record-v1', '--v1=' + gv1, '--pin=' + sha, '--out=' + rec])
            check('record writes one TSV per lane (exit %s)' % rc, len([x for x in os.listdir(rec) if x.endswith('.tsv')]) >= 10)
            outs = os.path.join(tmp, 'out-solo')
            rc = quiet(main, ['--v2=' + v2, '--v1-inventory=' + rec, '--pin=' + sha, '--out=' + outs, '--lanes=I-ROUTES,I-AUTHZ,I-ENUM'])
            check('solo with a fresh record: 0 candidates (exit %s)' % rc, rc == 0)
            os.remove(os.path.join(rec, 'I-ENUM.tsv'))
            ip = os.path.join(rec, 'I-AUTHZ.tsv')
            with open(ip) as f:
                body = f.read()
            with open(ip, 'w') as f:
                f.write(re.sub(r'sha256:\w+', 'sha256:0000000000000000', body, 1))
            outs = os.path.join(tmp, 'out-solo2')
            rc = quiet(main, ['--v2=' + v2, '--v1-inventory=' + rec, '--pin=' + '0' * 40, '--out=' + outs, '--lanes=I-ROUTES,I-AUTHZ,I-ENUM'])
            with open(os.path.join(outs, 'ledger.txt')) as f:
                lt = f.read()
            check('solo: old extractor hash -> blocked; absent lane -> blocked (exit %s)' % rc,
                  rc == 4 and 'extractor changed since record' in lt and 'no recorded I-ENUM' in lt, lt[:600])
            sv2 = os.path.join(tmp, 'solo-seed-v2')
            shutil.copytree(v2, sv2)
            with open(os.path.join(sv2, 'src/invoices/invoices.controller.ts')) as f:
                body = f.read()
            with open(os.path.join(sv2, 'src/invoices/invoices.controller.ts'), 'w') as f:
                f.write(body.replace("@Get(':invoice')", "@Get(':invoice/x')"))
            outs = os.path.join(tmp, 'out-solo3')
            rc = quiet(main, ['--v2=' + sv2, '--v1-inventory=' + rec, '--pin=' + '1' * 40, '--out=' + outs, '--lanes=I-ROUTES'])
            with open(os.path.join(outs, 'candidates.tsv')) as f:
                c = f.read()
            check('solo: stale sha tags rows stale-v1-inventory (exit %s)' % rc, rc == 1 and 'stale-v1-inventory' in c and 'solo' in c, c[:300])
            rc = quiet(main, ['--v1=' + gv1, '--v2=' + v2, '--pin=' + sha, '--out=' + os.path.join(gv1, 'out')])
            check('--out inside an audited tree is refused (exit %s)' % rc, rc == 2 and not os.path.exists(os.path.join(gv1, 'out')))
        else:
            check('git present for the snapshot tests', False, 'git not installed')
        for name, m in mods.items():
            st = getattr(m, 'self_test', None)
            if st:
                for label, ok, info in st(H, tmp):
                    check('%s: %s' % (name, label), ok, info)
    except Exception as e:  # a crash is a failed self-test, with the cause printed
        import traceback
        traceback.print_exc()
        fails.append('crash: %r' % e)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        devnull.close()
    real_out.write('pair-inventory self-test: %s (%d failed, %.1fs)\n' % ('PASS' if not fails else 'FAIL', len(fails), time.time() - t0))
    return 3 if fails else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
