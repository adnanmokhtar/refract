#!/usr/bin/env python3
"""knowledge-facts.py — knowledge-fact-scan §1-§7: does what the AI knowledge layer CLAIMS about this
project (engine, driver, id scheme, framework major, runtime, package manager, counts, module map,
derived copies, citations) still match the manifests, the lockfile and the files it was derived from?

Why a script: a stale fact multiplied by derivation is the costliest knowledge defect measured on a
real NestJS + React monorepo — one anchor bullet saying "MikroORM (MySQL)" and "ULID PKs" sat in 177
installed agents, commands and skills while the lockfile resolved `@mikro-orm/postgresql` and
`uuidv7`, and the profile those bullets cite by line had been corrected. Every identifier in the
stale bullet still resolved, so a reference checker passes it. Only a typed comparison against the
lockfile (§1), a citation-window check (§6) and grouping by root cause (§7) find it — as ONE finding
with 177 sites, not 177 findings.

Usage:  python3 -I knowledge-facts.py <root> [--classes=1,2,3,4,5,6,7] [--only=<file>:<line>]
                  [--corpus=<list file>|-] [--expand] [--json]
        python3 -I knowledge-facts.py --self-test
Classes: 1 fact vs manifest/lockfile (KN-07) · 2 count/range claims (KN-08) · 3 module map vs member
dirs (KN-09) · 4 one key, two values across loaded files (KN-11: engine, id scheme, ORM, framework,
Node, package manager, and the port a named service listens on) · 5 derived file vs its source
(KN-13: decision index vs ADR files, anchors vs the profile, a declared derivation sha) · 6 citation
no longer supports the claim (KN-14). §7 (KN-12, one fact in N copies) is the grouping every row
gets: identical claims collapse to one row with `sites=N` unless --expand; class 7 also hashes every
normalised paragraph of the live corpus, so a correct paragraph copied verbatim into two files is one
row with 2 sites (generated per-tool files and derived files are skipped: P-17, §5 owns them).

Truth sources, read from disk (never from memory): pnpm-lock.yaml, package-lock.json, yarn.lock,
poetry.lock, uv.lock, go.mod, Gemfile.lock, composer.lock; manifests (package.json, pyproject,
requirements*.txt, Gemfile, composer.json); .nvmrc / .node-version / .tool-versions / engines.node /
volta; .python-version / requires-python; compose `image:` lines; Prisma `provider`. A key with no
truth source is UNREAD (ledger line), never "consistent". Majors only: `engines >=18` is satisfied by
Node 22, and "React 18+" by 19.

Precedents applied in code: P-14 (history-marked facts: "not MySQL", "was X, now Y", "v1's", an
arrow `MySQL → Postgres`) · multi-value capability lines ("Postgres / MySQL / Mongo") · P-3 history
files · P-10 pack-generic bodies (anchor region only) · P-9 environment-named values · counts with
"about/~/over/at least" or "as of" · a derived file whose declared sha has no source change since.

OUTPUT: TSV `# § class sev site key claim truth verdict sites note` (or --json). verdict candidate |
unconfirmed. Stderr: the ledger (lockfiles read, truth per key, claims per key, UNREAD keys).
Exit: 0 none · 1 rows · 2 blocked (no such root) · 3 self-test failed. Stdlib only, Python >= 3.8,
`python3 -I` safe; read-only git with GIT_OPTIONAL_LOCKS=0; writes nothing under <root>.
"""
import sys
sys.dont_write_bytecode = True
import json
import os
import re
import shutil
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (HERE, os.path.normpath(os.path.join(HERE, '..', '..', 'knowledge-ref-scan', 'scripts'))):
    if os.path.isfile(os.path.join(_p, 'kn_common.py')) and _p not in sys.path:
        sys.path.insert(0, _p)
try:
    import kn_common as K  # noqa: E402
except ImportError:
    sys.stderr.write('blocked: kn_common.py not found (knowledge-ref-scan/scripts, learning pack)\n')
    sys.exit(2)

# ------------------------------------------------------------------ typed fact dictionary
ENGINE_DRIVERS = {
    'postgres': ['pg', 'postgres', '@mikro-orm/postgresql', 'pg-promise', '@neondatabase/serverless', 'psycopg',
                 'psycopg2', 'psycopg2-binary', 'asyncpg', 'github.com/jackc/pgx/v5', 'github.com/jackc/pgx/v4',
                 'github.com/lib/pq', 'gorm.io/driver/postgres', '@prisma/adapter-pg', '@vercel/postgres'],
    'mysql': ['mysql', 'mysql2', '@mikro-orm/mysql', 'mysqlclient', 'pymysql', 'aiomysql',
              'github.com/go-sql-driver/mysql', 'gorm.io/driver/mysql', '@prisma/adapter-planetscale'],
    'mariadb': ['mariadb', '@mikro-orm/mariadb'],
    'sqlite': ['sqlite3', 'better-sqlite3', '@mikro-orm/sqlite', '@mikro-orm/better-sqlite', '@libsql/client',
               'gorm.io/driver/sqlite', 'github.com/mattn/go-sqlite3'],
    'mongodb': ['mongodb', 'mongoose', '@mikro-orm/mongodb', 'pymongo', 'motor', 'go.mongodb.org/mongo-driver'],
    'sqlserver': ['mssql', 'tedious', '@mikro-orm/mssql', 'gorm.io/driver/sqlserver'],
}
ENGINE_WORD = [('postgres', r'Postgre(?:SQL|s)'), ('mysql', r'MySQL'), ('mariadb', r'MariaDB'), ('sqlite', r'SQLite'),
               ('mongodb', r'Mongo(?:DB)?'), ('sqlserver', r'(?:MS\s?)?SQL\s?Server|MSSQL')]
IMAGE_ENGINE = [('postgres', r'postgres|postgis|timescale'), ('mysql', r'mysql'), ('mariadb', r'mariadb'),
                ('mongodb', r'mongo')]
ID_LIBS = {'ulid': ['ulid', 'ulidx', 'ulid-generator', 'python-ulid', 'ulid-py', 'github.com/oklog/ulid/v2'],
           'uuidv7': ['uuidv7', 'uuid6', 'uuid-utils', 'uuid_utils', 'github.com/gofrs/uuid/v5'],
           'cuid': ['cuid', '@paralleldrive/cuid2'], 'nanoid': ['nanoid'], 'snowflake': ['snowflake-id', '@sapphire/snowflake']}
ID_WORD = [('ulid', r'ULIDs?'), ('uuidv7', r'UUID\s?v?7s?'), ('uuidv4', r'UUID\s?v?4s?'), ('cuid', r'CUID2?s?'),
           ('nanoid', r'nanoids?'), ('snowflake', r'[Ss]nowflake IDs?')]
FRAMEWORKS = [('react', r'React(?!\s*(?:Router|Native|Query|Hook))', ['react']), ('nestjs', r'Nest(?:JS)?', ['@nestjs/core']),
              ('next', r'Next(?:\.js)?', ['next']), ('vue', r'Vue(?:\.js)?', ['vue']), ('angular', r'Angular', ['@angular/core']),
              ('vite', r'Vite', ['vite']), ('fastify', r'Fastify', ['fastify']), ('express', r'Express', ['express']),
              ('typescript', r'TypeScript', ['typescript']), ('mikro-orm', r'MikroORM', ['@mikro-orm/core']),
              ('prisma', r'Prisma', ['prisma', '@prisma/client']), ('tailwind', r'Tailwind(?:\s?CSS)?', ['tailwindcss']),
              ('django', r'Django', ['django']), ('rails', r'Rails', ['rails']), ('laravel', r'Laravel', ['laravel/framework']),
              ('react-router', r'React Router', ['react-router', 'react-router-dom']), ('jest', r'Jest', ['jest']),
              ('vitest', r'Vitest', ['vitest']), ('svelte', r'Svelte', ['svelte']), ('eslint', r'ESLint', ['eslint']),
              ('tanstack-query', r'TanStack Query', ['@tanstack/react-query', '@tanstack/vue-query'])]
ORMS = [('mikro-orm', r'MikroORM', ['@mikro-orm/core']), ('typeorm', r'TypeORM', ['typeorm']),
        ('prisma', r'Prisma', ['prisma', '@prisma/client']), ('sequelize', r'Sequelize', ['sequelize']),
        ('drizzle', r'Drizzle', ['drizzle-orm']), ('mongoose', r'Mongoose', ['mongoose']),
        ('sqlalchemy', r'SQLAlchemy', ['sqlalchemy']), ('gorm', r'GORM', ['gorm.io/gorm'])]
PMS = [('pnpm', r'pnpm'), ('npm', r'npm'), ('yarn', r'[Yy]arn'), ('bun', r'[Bb]un')]
# P-14: history / contrast words in the clause BEFORE the claim; an arrow AFTER it.
NEG_BEFORE = re.compile(r'(?:\b(?:not|no longer|never|instead of|rather than|was|were|formerly|previously|legacy|old|'
                        r'v1|v1\'s|from|replac\w*|migrat\w*|supersed\w*|unlike|vs\.?|versus|than|retired|dropped|removed|'
                        r'deprecated|ported|porting|until|said|says|saying|stale|wrong|outdated|earlier|older|once|used to)\b'
                        r'|\bNOT\b|~~)[^.;|()\n]{0,48}$', re.I)
ARROW_AFTER = re.compile(r'^[^.;|\n]{0,40}(?:→|->|=>|\bto\b\s+(?:Postgre|MySQL|UUID|ULID))')
APPROX = re.compile(r'(?:\b(?:about|around|roughly|nearly|approximately|over|past|more than|at least|some|up to|almost|'
                    r'last|first|top|recent|next|newest|oldest|ca\.)\s*|[~≈><≥≤]\s*)$', re.I)
# KN-11 port key: `<service> listens|runs|serves|binds on port NNNN` (the noun phrase before the verb names the key).
PORT_RE = re.compile(r'\b(listens|runs|serves|binds|is served|is exposed|is reachable|starts)\s+on\s+(port\s+|(?:localhost|127\.0\.0\.1)?:)?'
                     r'`?(\d{2,5})\b(?!\.\d)', re.I)
ENV_WORD = re.compile(r'\b(dev|development|prod|production|staging|stage|test|testing|e2e|ci|local|preview|qa|uat|sandbox)\b', re.I)
PORT_STOP = {'the', 'a', 'an', 'our', 'its', 'this', 'that', 'and', 'then', 'which', 'it', 'always', 'still', 'now', 'by',
             'default', 'locally', 'also'}
COUNT_RE = re.compile(r'(?<![\w.,#/-])(\d{1,4})(\+?)\s+(ADRs?|decisions|agents|commands|skills|rules|packages|apps|'
                      r'workspaces|workspace members|modules)\b', re.I)
RANGE_RE = re.compile(r'\b(\d{4})\s*(?:–|—|-|\.\.|to)\s*(\d{4})\b')
CITE_RE = re.compile(r'`?((?:\.{0,2}/)?(?:[\w@.()\[\]+-]+/)*[\w@.()\[\]+-]+\.[A-Za-z0-9]{1,6}):(\d+)(?:[-–](\d+))?`?')


def majors(vs):
    out = set()
    for v in vs or ():
        m = re.match(r'(\d+)', v)
        if m:
            out.add(int(m.group(1)))
    return out


class Truth(object):
    def __init__(self, repo):
        self.repo = repo
        self.vers, self.lockfiles, self.decl = K.lock_versions(repo)
        self.present = set(self.vers) | set(self.decl)
        self.keys = {}
        eng = set(e for e, drivers in ENGINE_DRIVERS.items() if any(d in self.present for d in drivers))
        for f in repo.files:
            b = os.path.basename(f)
            if re.match(r'^(docker-)?compose[\w.-]*\.ya?ml$', b) or b == 'docker-compose.yml':
                for l in repo.lines(f) or []:
                    m = re.match(r'^\s*image:\s*["\']?(?:[\w.-]+/)*([\w.-]+)[:@]?', l)
                    if m:
                        for e, rx in IMAGE_ENGINE:
                            if re.match(r'^(?:' + rx + r')$', m.group(1)):
                                eng.add(e)
            elif b == 'schema.prisma':
                for l in repo.lines(f) or []:
                    m = re.match(r'^\s*provider\s*=\s*"(postgresql|mysql|sqlite|mongodb|sqlserver)"', l)
                    if m:
                        eng.add({'postgresql': 'postgres'}.get(m.group(1), m.group(1)))
        self.keys['engine'] = eng
        ids = set(k for k, libs in ID_LIBS.items() if any(x in self.present for x in libs))
        if 'uuid' in self.present and not ids:
            ids = {'uuidv4', 'uuidv7'}                     # the uuid package does both since v10: not a contradiction
        self.keys['id'] = ids
        self.keys['orm'] = set(k for k, _, pk in ORMS if any(p in self.present for p in pk))
        pm = set()
        for f, k in (('pnpm-lock.yaml', 'pnpm'), ('package-lock.json', 'npm'), ('yarn.lock', 'yarn'),
                     ('bun.lockb', 'bun'), ('bun.lock', 'bun')):
            if f in repo.fset:
                pm.add(k)
        pj = K.read_jsonc(os.path.join(repo.root, 'package.json')) if 'package.json' in repo.fset else None
        if isinstance(pj, dict) and isinstance(pj.get('packageManager'), str):
            pm = {pj['packageManager'].split('@')[0]}
        self.keys['pm'] = pm
        self.fw = {}
        for k, _, pkgs in FRAMEWORKS:
            ms = set()
            for p in pkgs:
                ms |= majors(self.vers.get(p))
            if ms:
                self.fw[k] = ms
        self.node = self._node(pj)

    def _node(self, pj):
        """('pin', major, file) | ('range', spec, file) | None."""
        for f in ('.nvmrc', '.node-version'):
            if f in self.repo.fset:
                m = re.search(r'(\d+)', (self.repo.lines(f) or [''])[0])
                if m:
                    return ('pin', int(m.group(1)), f)
        if '.tool-versions' in self.repo.fset:
            for l in self.repo.lines('.tool-versions') or []:
                m = re.match(r'^\s*(?:nodejs|node)\s+v?(\d+)', l)
                if m:
                    return ('pin', int(m.group(1)), '.tool-versions')
        if isinstance(pj, dict):
            v = (pj.get('volta') or {}).get('node') if isinstance(pj.get('volta'), dict) else None
            if isinstance(v, str) and re.match(r'\d+', v):
                return ('pin', int(re.match(r'(\d+)', v).group(1)), 'package.json volta')
            e = (pj.get('engines') or {}).get('node') if isinstance(pj.get('engines'), dict) else None
            if isinstance(e, str):
                return ('range', e, 'package.json engines.node')
        return None

    def node_ok(self, major, plus):
        if not self.node:
            return None
        kind, v, _ = self.node
        if kind == 'pin':
            return v >= major if plus else v == major
        for part in re.split(r'\|\|', v):
            lo = re.search(r'>=?\s*(\d+)', part)
            car = re.search(r'[\^~]\s*(\d+)|^\s*(\d+)(?:\.x|\.\*)?\s*$', part)
            if lo and major >= int(lo.group(1)):
                lt = re.search(r'<\s*(\d+)', part)
                if not lt or major < int(lt.group(1)):
                    return True
            if car and int(car.group(1) or car.group(2)) == major:
                return True
        return False


def claims_in(text):
    """[(key, value, start, plus)] typed claims in one line, before the P-14 filter."""
    out = []
    for k, rx in ENGINE_WORD:
        for m in re.finditer(r'\b(?:' + rx + r')\b', text):
            out.append(('engine', k, m.start(), False))
    for k, rx in ID_WORD:
        for m in re.finditer(r'\b(?:' + rx + r')(?![\w-])', text):
            out.append(('id', k, m.start(), False))
    for k, rx, _ in ORMS:
        for m in re.finditer(r'\b(?:' + rx + r')\b', text):
            out.append(('orm', k, m.start(), False))
    for k, rx, _ in FRAMEWORKS:
        for m in re.finditer(r'\b(?:' + rx + r')\s?v?(\d{1,2})(?:\.\d+)*(\+|\s*or (?:later|newer)|\s*and up)?(?![\w.%])', text):
            out.append(('fw:' + k, int(m.group(1)), m.start(), bool(m.group(2))))
    for m in re.finditer(r'\bNode(?:\.js)?\s?v?(\d{2})(\+|\s*or (?:later|newer))?(?![\w.])', text):
        out.append(('node', int(m.group(1)), m.start(), bool(m.group(2))))
    for m in PORT_RE.finditer(text):
        if not m.group(2) and m.group(1).lower() not in ('listens', 'binds'):
            continue                                     # "runs on 5173" with no `port` word is too loose
        words = re.findall(r'[A-Za-z][\w.-]*', re.split(r'[;:,.()]', text[:m.start()])[-1])[-3:]
        while words and words[0].lower() in PORT_STOP:
            words.pop(0)
        subj = ' '.join(w.lower() for w in words if w.lower() not in PORT_STOP)
        after = re.split(r'[;,.()]', text[m.end():])[0][:40]
        if not subj or ENV_WORD.search(subj) or ENV_WORD.search(text[:m.start()][-40:]) or ENV_WORD.search(after):
            continue                                     # P-9: an environment-named value is not a contradiction
        out.append(('port:' + subj, int(m.group(3)), m.start(), False))
    if re.search(r'package manager|workspaces?\b|monorepo|lockfile', text, re.I):
        for k, rx in PMS:
            for m in re.finditer(r'(?<![\w/@-])' + rx + r'(?![\w/-])', text):
                out.append(('pm', k, m.start(), False))
    return out


def live_claims(text):
    """P-14 and capability-list filters. Returns [(key, value, plus)] that are live claims."""
    raw = claims_in(text)
    per_key = {}
    for k, v, s, p in raw:
        per_key.setdefault(k, set()).add(v)
    out = []
    for k, v, s, p in raw:
        if len(per_key[k]) > 1:
            continue                                     # "Postgres / MySQL / Mongo": a capability list, or a correction
        if NEG_BEFORE.search(text[:s]) or ARROW_AFTER.match(text[s:]):
            continue
        if k == 'node' and re.search(r'\b(dev|prod|production|staging|test|ci)\b', text[:s][-30:], re.I):
            continue
        out.append((k, v, p))
    return out


def norm(text):
    t = re.sub(r'\s+', ' ', re.sub(r'^[>\s*#|-]+', '', text)).strip().lower()
    return t[:200]


def scan(root, classes=(1, 2, 3, 4, 5, 6, 7), only=None, corpus_list=None, expand=False):
    repo = K.Repo(root)
    truth = Truth(repo)
    files = K.corpus(repo, corpus_list)
    scan_files = [(r, s) for r, s in files if s in ('live', 'pack-body')]
    K.ledger('census=%s files=%d · corpus %d (scanned %d live/anchor files; history and sinks excluded)'
             % (repo.census, len(repo.files), len(files), len(scan_files)))
    K.ledger('lockfiles: %s' % (', '.join(truth.lockfiles) if truth.lockfiles else 'UNREAD (no lockfile: majors not checked)'))
    for k in ('engine', 'id', 'orm', 'pm'):
        K.ledger('truth %-6s %s' % (k, ', '.join(sorted(truth.keys[k])) or 'UNREAD'))
    K.ledger('truth node   %s' % (('%s %s (%s)' % truth.node) if truth.node else 'UNREAD'))
    K.ledger('truth fw     %s' % ', '.join('%s %s' % (k, '/'.join(str(x) for x in sorted(v))) for k, v in sorted(truth.fw.items())))
    rows, stats = [], {}
    home, how, _ = K.adr_home(repo)
    ids = K.adr_ids(repo, home)
    facts = []                                          # (key, value, rel, ln, text) for §4

    def bump(k, n=1):
        stats[k] = stats.get(k, 0) + n

    def row(sec, kn, sev, rel, ln, key, claim, tr, verdict, note='', group=None):
        rows.append({'sec': sec, 'kn': kn, 'sev': sev, 'site': '%s:%d' % (rel, ln), 'key': key, 'claim': claim,
                     'truth': tr, 'verdict': verdict, 'note': note, 'group': group or (sec, key, claim, note)})

    def sev(rel, base):
        return {'L': 'M', 'M': 'H', 'H': 'H'}[base] if (K.loaded_every_session(rel) or rel.startswith(K.PACK_BODY_DIRS)) else base

    for rel, scope in scan_files:
        if only and rel != only[0]:
            continue
        lines = repo.lines(rel) or []
        live = K.live_lines(rel, lines, scope == 'pack-body')
        for ln, in_fence in sorted(live.items()):
            if only and ln != only[1]:
                continue
            text = lines[ln - 1]
            if in_fence:
                continue
            for k, v, plus in live_claims(text):
                bump('claims ' + k.split(':')[0])
                facts.append((k, v, rel, ln, text))
                if 1 not in classes:
                    continue
                if k in ('engine', 'id', 'orm', 'pm'):
                    t = truth.keys[k]
                    if not t:
                        bump('UNREAD ' + k)
                        continue
                    if v not in t and not (k == 'id' and v == 'uuidv4' and 'uuidv7' in t and 'uuid' in truth.present):
                        row(1, 'KN-07', sev(rel, 'M') if k != 'pm' else 'M', rel, ln, k, v, '/'.join(sorted(t)), 'candidate',
                            'source wins: %s' % src_label(truth, k), group=(1, k, v, norm(text)))
                elif k.startswith('fw:'):
                    t = truth.fw.get(k[3:])
                    if not t:
                        bump('UNREAD ' + k)
                        continue
                    ok = any(m >= v for m in t) if plus else v in t
                    if not ok:
                        row(1, 'KN-07', sev(rel, 'M'), rel, ln, k[3:] + ' major', '%d%s' % (v, '+' if plus else ''),
                            '/'.join(str(x) for x in sorted(t)), 'candidate', 'lockfile major', group=(1, k, v, norm(text)))
                elif k == 'node':
                    ok = truth.node_ok(v, plus)
                    if ok is None:
                        bump('UNREAD node')
                    elif not ok:
                        row(1, 'KN-07', sev(rel, 'M'), rel, ln, 'node major', str(v), '%s %s' % truth.node[1:],
                            'candidate', 'pin or engines range', group=(1, k, v, norm(text)))
            # §2 counts and ranges
            if 2 in classes:
                for m in RANGE_RE.finditer(text):
                    a, b = int(m.group(1)), int(m.group(2))
                    if not ids or not re.search(r'ADR|decision', text, re.I) or b < a or b > 9000:
                        continue
                    if re.search(r'\bas of\b', text, re.I):
                        continue
                    mx = max(ids)
                    bump('range claims')
                    if b < mx:
                        row(2, 'KN-08', sev(rel, 'L'), rel, ln, 'ADR range', '%04d–%04d' % (a, b),
                            '%04d–%04d on disk (%d files in %s)' % (min(ids), mx, len(ids), home), 'candidate')
                for m in COUNT_RE.finditer(text):
                    n, plus, what = int(m.group(1)), m.group(2), m.group(3).lower()
                    if APPROX.search(text[:m.start()]) or re.search(r'\bas of\b|\bof\s+\d', text, re.I) or \
                            re.search(r'\d\s*/\s*$', text[:m.start()]):
                        continue
                    if not count_scoped(text[max(0, m.start() - 48):m.end() + 48], what):
                        continue                         # "168 rules" of a business domain is not .claude/rules
                    actual = count_of(repo, what, ids)
                    if actual is None:
                        continue
                    bump('count claims')
                    if (plus and actual < n) or (not plus and actual != n):
                        row(2, 'KN-08', sev(rel, 'L'), rel, ln, what, '%d%s' % (n, plus), str(actual), 'candidate',
                            'counted from the tree')
            # §6 citation entailment
            if 6 in classes or 5 in classes:
                for m in CITE_RE.finditer(text):
                    target, a = m.group(1), int(m.group(2))
                    b = int(m.group(3)) if m.group(3) else a
                    st, tgt, _ = repo.resolve(target, rel)
                    if st not in ('exact', 'relative', 'alias', 'package', 'abbrev'):
                        continue                         # a dead file is knowledge-ref-scan §1
                    bump('citations')
                    tl = repo.lines(tgt) or []
                    claim = claim_text(text, m)
                    anchor = scope == 'pack-body'
                    sec, kn = (5, 'KN-13') if anchor and tgt.startswith('.claude/') else (6, 'KN-14')
                    if sec not in classes:
                        continue
                    if a > len(tl):
                        row(sec, kn, sev(rel, 'M'), rel, ln, 'citation', '%s:%d' % (tgt, a), 'file has %d lines' % len(tl),
                            'candidate', 'cited line past EOF', group=(sec, tgt, a, 'eof'))
                        continue
                    window = '\n'.join(tl[max(0, a - 4):min(len(tl), b + 3)])
                    typed = set((k, v) for k, v, _ in live_claims(claim) if not k.startswith(('fw:', 'port:')) and k != 'node')
                    wclaims = live_claims_all(window)
                    missing = [(k, v) for k, v in typed if not mentions(window, k, v)]
                    conflict = [(k, v) for k, v in missing if wclaims.get(k)]
                    is_doc = tgt.endswith(('.md', '.mdc', '.markdown', '.txt'))
                    if conflict:
                        wt = sorted(set(str(x) for k, _ in conflict for x in wclaims.get(k, ())))
                        wrong = [v for k, v in conflict if truth.keys.get(k) and v not in truth.keys[k]]
                        row(sec, kn, sev(rel, 'M') if wrong else 'L', rel, ln, 'citation',
                            '%s:%d says %s' % (tgt, a, '/'.join(sorted(str(v) for _, v in conflict))),
                            'window ±3 says ' + '/'.join(wt), 'candidate' if wrong else 'unconfirmed',
                            ('derived copy stale vs its source' if sec == 5 else 'citation no longer supports the claim')
                            if wrong else 'claim agrees with the lockfile; only the citation moved',
                            group=(sec, tgt, a, tuple(sorted(str(v) for _, v in conflict))))
                        continue
                    if missing and is_doc:
                        right = all(truth.keys.get(k) and v in truth.keys[k] for k, v in missing)
                        row(sec, kn, 'L', rel, ln, 'citation', '%s:%d says %s' % (tgt, a, '/'.join(sorted(str(v) for _, v in missing))),
                            'window ±3 says neither', 'unconfirmed',
                            'claim agrees with the lockfile; the cited line does not carry it' if right else 'R3 trap: an aggregate claim may cite several spans',
                            group=(sec, tgt, a, tuple(sorted(str(v) for _, v in missing))))
                        continue
                    idents = [x for x in re.findall(r'`([A-Za-z_][\w]*(?:\(\))?)`', claim) if len(x) > 3][:6]
                    if not typed and len(idents) >= 2 and not any(re.search(r'\b' + re.escape(i.rstrip('()')) + r'\b', window)
                                                                  for i in idents):
                        row(sec, kn, 'L', rel, ln, 'citation', '%s:%d' % (tgt, a), '0 of %d named identifiers in ±3 lines' % len(idents),
                            'unconfirmed', 'R3 trap: an aggregate claim may cite several spans',
                            group=(sec, tgt, a, 'ident'))
    # §3 module map: present-not-listed (listed-not-present is knowledge-ref-scan §1).
    if 3 in classes and not only:
        maps = [f for f in ('ai/modules.md', 'ai/architecture.md') if f in repo.fset or repo.exists_on_disk(f)]
        if maps:
            text = '\n'.join('\n'.join(repo.lines(f) or []) for f in maps).lower()
            mods = {}
            for f in repo.files:
                m = re.match(r'^((?:apps|packages|services|libs)/[^/]+/src/(?:modules|features)/([^/]+))/', f) or \
                    re.match(r'^((?:src)/(?:modules|features)/([^/]+))/', f)
                if m:
                    mods.setdefault((m.group(1), m.group(2)), 0)
                    mods[(m.group(1), m.group(2))] += 1
            bump('module dirs (>=5 files)', sum(1 for v in mods.values() if v >= 5))
            for (d, name), n in sorted(mods.items()):
                if n < 5:
                    continue
                if not re.search(r'(?<![\w-])' + re.escape(name.lower()) + r'(?![\w-])', text):
                    row(3, 'KN-09', 'M', maps[0], 1, 'module', d, '%d tracked files' % n, 'candidate',
                        'present, not listed in %s' % ' / '.join(maps))
        else:
            K.ledger('§3 N/A (no ai/modules.md or ai/architecture.md)')
    # §4 one key, two values across loaded files.
    if 4 in classes and not only:
        by_key = {}
        for k, v, rel, ln, text in facts:
            by_key.setdefault(k, {}).setdefault(v, []).append('%s:%d' % (rel, ln))
        for k, vals in sorted(by_key.items()):
            if len(vals) < 2:
                continue
            tr = truth.keys.get(k) if k in truth.keys else truth.fw.get(k[3:]) if k.startswith('fw:') else None
            parts = ['%s ×%d (%s)' % (v, len(s), s[0]) for v, s in sorted(vals.items(), key=lambda kv: -len(kv[1]))]
            first = sorted(vals.items(), key=lambda kv: len(kv[1]))[0][1][0]
            rel, _, ln = first.rpartition(':')
            row(4, 'KN-11', 'H' if k in ('engine', 'id') else 'M', rel, int(ln), k, ' vs '.join(parts),
                '/'.join(str(x) for x in sorted(tr)) if tr else 'no manifest truth',
                'candidate', 'same key, different values in loaded files' + ('; the off-truth sites are §1 rows' if tr else ''))
    # §5 derived files: the decision index vs the ADR home, and declared derivation points.
    if 5 in classes and not only:
        for idx in [f for f, _ in files if re.search(r'(^|/)_?decision-index\.md$', f)]:
            cited = set(int(x) for x in re.findall(r'(?<![\d])(\d{4})-[a-z]', '\n'.join(repo.lines(idx) or [])))
            cited |= set(int(x) for x in re.findall(r'\bADR-(\d{4})\b', '\n'.join(repo.lines(idx) or [])))
            if not ids:
                continue
            missing = sorted(set(ids) - cited)
            extra = sorted(cited - set(ids))
            bump('index rows', len(cited))
            if missing:
                row(5, 'KN-13', 'M', idx, 1, 'decision index', 'missing %d ADR(s): %s' % (len(missing), ', '.join('%04d' % i for i in missing[:12])),
                    '%d files in %s' % (len(ids), home), 'candidate', 'regenerate the index; never hand-edit a derived file')
            if extra:
                row(5, 'KN-13', 'M', idx, 1, 'decision index', 'rows with no file: %s' % ', '.join('%04d' % i for i in extra[:12]),
                    '%d files in %s' % (len(ids), home), 'candidate')
        for rel, scope in scan_files:
            for ln, l in enumerate((repo.lines(rel) or [])[:40], 1):
                m = re.search(r'(?:derived(?:_at)?|re-derived)\b[^\n]{0,60}?\b([0-9a-f]{7,40})\b', l, re.I)
                if not m or not repo.has_git:
                    continue
                sha = m.group(1)
                srcs = derivation_sources(repo, rel)
                rc, out = K.git(repo.root, 'rev-list', '--count', sha + '..HEAD', '--', *srcs) if srcs else (1, '')
                bump('derivation points')
                # Grouped per derived file: two files that declare one sha have their own sources and their own truth.
                if rc != 0:
                    row(5, 'KN-13', 'L', rel, ln, 'derived at', sha, 'sha not in history', 'unconfirmed',
                        group=(5, 'derived at', rel, sha))
                elif out.strip() not in ('', '0'):
                    row(5, 'KN-13', 'M', rel, ln, 'derived at', sha, '%s commit(s) touched %s since' % (out.strip(), ', '.join(srcs[:3])),
                        'unconfirmed', 're-derive, then compare bytes (not mtimes)', group=(5, 'derived at', rel, sha))
                break
    # §7 verbatim copies: one normalised paragraph in two or more live files (a correct paragraph drifts the day one
    # copy is edited). Generated per-tool files (P-17) and derived files (§5) are copies by design.
    if 7 in classes and not only:
        paras = {}
        for rel, scope in scan_files:
            if scope != 'live':
                continue
            lines = repo.lines(rel) or []
            if is_generated(lines):
                bump('§7 generated/derived files skipped')
                continue
            for start, text in paragraphs(rel, lines):
                paras.setdefault(text, []).append((rel, start))
        for text, sites in sorted(paras.items(), key=lambda kv: kv[1][0]):
            if len(set(r for r, _ in sites)) < 2:
                continue
            bump('§7 copied paragraphs')
            for rel, start in sites:
                row(7, 'KN-12', 'L', rel, start, 'paragraph', text[:60] + ('…' if len(text) > 60 else ''),
                    '%d copies, %d chars' % (len(sites), len(text)), 'unconfirmed',
                    'copies: %s; keep one and point to it, the copies drift the day one is edited'
                    % ', '.join('%s:%d' % x for x in sites), group=(7, text))
    for k in sorted(stats):
        K.ledger('  %-28s %d' % (k, stats[k]))
    return group(rows, expand)


def src_label(truth, k):
    if k == 'engine':
        return 'drivers/images in manifests'
    if k == 'pm':
        return 'lockfile / packageManager'
    return ', '.join(truth.lockfiles) or 'manifests'


GENERATED_RE = re.compile(r'\b(?:generated|derived(?:_at)?|re-derived|auto-populated)\b[^\n]{0,80}?(?:\bfrom\b|\bat\b|\bby\b)'
                          r'|do not edit|don\'t edit|edit [^\n]{1,40} not this file', re.I)
PARA_MIN = 80


def is_generated(lines):
    """P-17 / §5: a file that says it was generated or derived from a source (first 12 lines)."""
    return any(GENERATED_RE.search(l) for l in lines[:12])


def paragraphs(rel, lines):
    """[(first line, normalised text)] for each prose paragraph or list item (outside fences, headings, tables
    and HTML comments) of at least PARA_MIN normalised characters."""
    live = K.live_lines(rel, lines, False)
    out, cur, start = [], [], None
    for ln in range(1, len(lines) + 2):
        l = lines[ln - 1] if ln <= len(lines) else ''
        brk = ln > len(lines) or ln not in live or live[ln] or not l.strip() or \
            l.lstrip().startswith(('#', '|', '```', '~~~', '<!--')) or re.match(r'^\s*(?:[-*+]|\d+\.)\s', l)
        if brk and cur:
            t = ' '.join(norm(x) for x in cur).strip()
            t = re.sub(r'\s+', ' ', t)
            if len(t) >= PARA_MIN:
                out.append((start, t))
            cur, start = [], None
        if ln > len(lines) or ln not in live or live[ln] or not l.strip() or l.lstrip().startswith(('#', '|', '```', '~~~', '<!--')):
            continue
        if start is None:
            start = ln
        cur.append(l)
    return out


def live_claims_all(window):
    """{key: set(values)} a window states, P-14 lines dropped, capability lists kept."""
    out = {}
    for line in window.split('\n'):
        for k, v, s_, p in claims_in(line):
            if NEG_BEFORE.search(line[:s_]):
                continue
            out.setdefault(k, set()).add(v)
    return out


def mentions(window, k, v):
    w = window.lower()
    pats = {'engine': dict(ENGINE_WORD), 'id': dict(ID_WORD)}
    if k in pats:
        return re.search(r'\b(?:' + pats[k][v] + r')', window, re.I) is not None
    if k == 'orm':
        return re.search(r'\b(?:' + dict((a, b) for a, b, _ in ORMS)[v] + r')\b', window, re.I) is not None
    return str(v).lower() in w


def claim_text(text, m):
    """The bullet's claim: the sentence that carries the citation (both sides), without the citation."""
    t = text[:m.start()] + text[m.end():]
    return t


def count_scoped(text, what):
    """A count is checkable only when the line names WHICH set it counts (P: generic nouns such as
    'rules', 'workspaces' or 'packages' mean business rules, tenants and npm packages in prose)."""
    w = what.lower().rstrip('s')
    if w in ('adr', 'decision'):
        return bool(re.search(r'\bADRs?\b|decisions/', text))
    if w in ('agent', 'command', 'skill', 'rule'):
        return '.claude' in text
    if w in ('package', 'app', 'workspace', 'workspace member'):
        return bool(re.search(r'`?(?:apps|packages)/`?|pnpm-workspace|workspace members|monorepo (?:has|with)', text))
    if w == 'module':
        return bool(re.search(r'src/modules|modules/`|`modules/', text))
    return False


def count_of(repo, what, ids):
    def n_files(d, ext='.md', dirs=False):
        p = os.path.join(repo.root, d)
        if not os.path.isdir(p):
            return None
        if dirs:
            return sum(1 for x in os.listdir(p) if os.path.isdir(os.path.join(p, x)))
        return sum(1 for x in os.listdir(p) if x.endswith(ext) and not x.startswith(('_', 'README')))
    w = what.rstrip('s')
    if w in ('adr', 'decision'):
        return len(ids) if ids else None
    if w == 'agent':
        return n_files('.claude/agents')
    if w == 'command':
        return n_files('.claude/commands')
    if w == 'skill':
        return n_files('.claude/skills', dirs=True)
    if w == 'rule':
        return n_files('.claude/rules')
    if w in ('package', 'app', 'workspace', 'workspace member'):
        mem = [d for d in repo.members().values() if d]
        if not mem:
            return None
        if w == 'app':
            return sum(1 for d in mem if d.startswith('apps/')) or None
        if w == 'package':
            return sum(1 for d in mem if d.startswith('packages/')) or None
        return len(mem)
    if w == 'module':
        mods = set()
        for f in repo.files:
            m = re.match(r'^((?:apps|packages|services|libs)/[^/]+/)?src/modules/([^/]+)/', f)
            if m:
                mods.add((m.group(1), m.group(2)))
        roots = set(r for r, _ in mods)
        return len(mods) if mods and len(roots) == 1 else None
    return None


def derivation_sources(repo, rel):
    known = {'ai/_convention-cheatsheet.md': ['ai/conventions.md'], 'ai/_decision-index.md': [],
             'ai/_session-digest.md': ['.claude/codebase-profile.md', 'ai/conventions.md']}
    if rel in known and known[rel]:
        return [s for s in known[rel] if s in repo.fset]
    out = []
    for l in repo.lines(rel) or []:
        for m in re.finditer(r'`([\w./@-]+\.[A-Za-z]{1,5})`', l):
            st, tgt, _ = repo.resolve(m.group(1), rel)
            if st in ('exact', 'relative', 'abbrev') and tgt not in out and tgt != rel:
                out.append(tgt)
    return out[:40]


def group(rows, expand):
    order = {'H': 0, 'M': 1, 'L': 2}
    if expand:
        for r in rows:
            r['sites'] = 1
            r.pop('group', None)
        return rows
    out, idx = [], {}
    for r in rows:
        key = r.pop('group')
        if key in idx:
            g = idx[key]
            g['sites'] += 1
            g['_all'].append(r['site'])
            if order[r['sev']] < order[g['sev']]:
                g['sev'] = r['sev']
        else:
            g = dict(r)
            g['sites'] = 1
            g['_all'] = [r['site']]
            idx[key] = g
            out.append(g)
    for g in out:
        if g['sites'] > 1 and g['sec'] != 7:             # a §7 row names its copies already
            dirs = {}
            for s in g['_all']:
                d = s.split('/')[1] if s.startswith('.claude/') else s.split('/')[0]
                dirs[d] = dirs.get(d, 0) + 1
            g['note'] = (g['note'] + '; ' if g['note'] else '') + 'KN-12 one fact, %d copies (%s)' % (
                g['sites'], ', '.join('%s %d' % kv for kv in sorted(dirs.items(), key=lambda kv: -kv[1])))
        g.pop('_all', None)
    return out


def emit(rows, as_json):
    if as_json:
        print(json.dumps(rows, indent=1, default=str))
        return
    print('# §\tclass\tsev\tsite\tkey\tclaim\ttruth\tverdict\tsites\tnote')
    for r in sorted(rows, key=lambda r: (r['sec'], {'H': 0, 'M': 1, 'L': 2}[r['sev']], -r['sites'], r['site'])):
        print('\t'.join(str(r[k]) for k in ('sec', 'kn', 'sev', 'site', 'key', 'claim', 'truth', 'verdict', 'sites', 'note')))


# ------------------------------------------------------------------ self-test
def _w(root, rel, text):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p) or root, exist_ok=True)
    with open(p, 'w') as fh:
        fh.write(text)


def self_test():
    K.QUIET = True
    tmp = tempfile.mkdtemp(prefix='kn-facts-selftest.')
    fails = []
    try:
        root = os.path.join(tmp, 'repo')
        os.makedirs(root)
        env = dict(K.GIT_ENV, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1', HOME=tmp)
        git = lambda *a: subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@t', '-c', 'commit.gpgsign=false'] + list(a),
                                        cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        _w(root, 'package.json', '{"name":"mono","packageManager":"pnpm@9.1.0","engines":{"node":">=20"}}')
        _w(root, 'pnpm-lock.yaml', "lockfileVersion: '9.0'\npackages:\n  '@mikro-orm/postgresql@6.6.16':\n    resolution: {}\n"
                                   "  '@mikro-orm/core@6.6.16':\n    resolution: {}\n  react@19.2.0:\n    resolution: {}\n"
                                   "  uuidv7@1.2.1:\n    resolution: {}\n")
        _w(root, 'apps/api/package.json', '{"name":"@acme/api","dependencies":{"@mikro-orm/postgresql":"^6.6.16","uuidv7":"^1"}}')
        _w(root, 'apps/web/package.json', '{"name":"@acme/web","dependencies":{"react":"^19.2.0"}}')
        for i in range(1, 9):
            _w(root, 'docs/decisions/%04d-d%d.md' % (i, i), '# %d\nStatus: Accepted\n' % i)
        for m in ('orders', 'billing', 'catalog'):
            for j in range(6):
                _w(root, 'apps/api/src/modules/%s/f%d.ts' % (m, j), 'x\n')
        _w(root, 'ai/conventions.md', '# Conventions\n- MUST use the outbox\n')
        _w(root, '.claude/codebase-profile.md', '\n'.join(['# Profile', '', '## Data', '', '- **ORM**: MikroORM (Postgres 16) with UUIDv7 PKs.', '']))
        git('init', '-q')
        git('add', '-A')
        git('commit', '-q', '-m', 'one')
        base = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=root, env=env, stdout=subprocess.PIPE).stdout.decode().strip()
        _w(root, 'ai/conventions.md', '# Conventions\n- MUST use the outbox\n- MUST pin lock_timeout\n')
        git('add', '-A')
        git('commit', '-q', '-m', 'two')
        anchor = '\n'.join(['---', 'name: a%d', 'pack: backend', '---', 'Generic: works with Postgres, MySQL or MongoDB and ULID or UUID.',
                            '<!-- project-specific:start -->',
                            '> - **Data access** (`.claude/codebase-profile.md:5`): MikroORM (MySQL) with ULID PKs.',
                            '<!-- project-specific:end -->', ''])
        for i in range(3):
            _w(root, '.claude/agents/a%d.md' % i, anchor % i)
        _w(root, 'CLAUDE.md', '\n'.join([
            '# Project',
            'pnpm monorepo on React 18 and Node 22.',                              # 2: React 18 (KN-07); node ok (>=20); pm ok
            'Database: Postgres 16, not MySQL; UUIDv7, not ULID.',                 # 3: decoy P-14
            'Every file in `docs/decisions/` (0001–0006) has a row.',             # 4: KN-08 range
            'The API has 3 modules and about 30 services.',                        # 5: count ok (3) and approx decoy
            'Package manager: npm workspaces.',                                    # 6: KN-07 pm; KN-11 vs line 2
            'Profile line: `.claude/codebase-profile.md:5` says MikroORM (Postgres 16).',  # 7: citation ok
            'Data: `.claude/codebase-profile.md:99` (gone).',                      # 8: past EOF
            'Last profile line: `.claude/codebase-profile.md:6` (5 lines).',      # 9: past EOF by one (a final newline is no line)
            'The API listens on port 3000 behind the proxy.',                     # 10: KN-11 port vs AGENTS.md:5
            'In production the API listens on port 8080.',                        # 11: decoy P-9 environment-named
            '',
            'Every query runs inside the tenant scope: the filter is global middleware that keeps the tenant id in',
            'async local storage, and background jobs call withTenant() before they touch the database.',  # 13: KN-12 copy
            '']))
        _w(root, 'ai/architecture.md', '# Architecture\n\nEvery query runs inside the tenant  scope: the filter is global middleware that '
                                       'keeps the tenant id in\nasync local storage, and background jobs call withTenant() before they '
                                       'touch the database.\n')
        _w(root, '.github/copilot-instructions.md', '<!-- Generated by apply-adapter-sync.sh from CLAUDE.md. Edit CLAUDE.md, not this file. -->\n'
                                                    'Every query runs inside the tenant scope: the filter is global middleware that keeps the '
                                                    'tenant id in async local storage, and background jobs call withTenant() before they touch '
                                                    'the database.\n')
        _w(root, 'AGENTS.md', 'Runs on Node 18 in production pins.\nThe API has 12 modules under `apps/api/src/modules/`.\n168 rules and ~25 commands.\n'
                              'It ran out of memory with 9 agents running full suites at once on a small laptop overnight; notes in `.claude/`.\n'
                              'The API listens on port 4000; the web dev server runs on 5173.\nPorts by environment: dev API 3000, e2e API 3100, staging API 8080.\n')   # node 18 < 20 -> KN-07; 12 modules KN-08; 5 port
        _w(root, 'ai/_decision-index.md', '# Index\n| 0001-d1 | x |\n| 0002-d2 | x |\n| 0003-d3 | x |\n| 0004-d4 | x |\n| 0005-d5 | x |\n| 0006-d6 | x |\n')
        _w(root, 'ai/_convention-cheatsheet.md', '# Cheatsheet\nDerived against `main` at `%s`.\n- MUST use the outbox\n' % base[:10])
        _w(root, 'ai/_session-digest.md', '# Digest\nDerived against `main` at `%s`.\n' % base[:10])   # same sha, its own sources
        _w(root, 'ai/modules.md', '# Modules\n- `orders` — orders\n- `billing` — money\n')
        rows = scan(root, expand=True)
        keyset = set((r['kn'], r['site'], r['key']) for r in rows)

        def want(kn, site, key, label):
            if (kn, site, key) not in keyset:
                fails.append('missing %s: %s %s %s' % (label, kn, site, key))

        def deny(pred, label):
            bad = [r for r in rows if pred(r)]
            if bad:
                fails.append('false row %s: %s' % (label, bad[0]))

        for i in range(3):
            want('KN-07', '.claude/agents/a%d.md:7' % i, 'engine', 'anchor MySQL vs lockfile')
            want('KN-07', '.claude/agents/a%d.md:7' % i, 'id', 'anchor ULID vs uuidv7')
            want('KN-13', '.claude/agents/a%d.md:7' % i, 'citation', 'anchor stale vs the cited profile line')
        want('KN-07', 'CLAUDE.md:2', 'react major', 'React 18 vs lock 19')
        want('KN-07', 'AGENTS.md:1', 'node major', 'Node 18 vs engines >=20')
        want('KN-07', 'CLAUDE.md:6', 'pm', 'npm vs pnpm')
        want('KN-08', 'CLAUDE.md:4', 'ADR range', '0006 vs 0008 on disk')
        want('KN-08', 'AGENTS.md:2', 'modules', '12 modules vs 3')
        want('KN-14', 'CLAUDE.md:8', 'citation', 'cited line past EOF')
        want('KN-09', 'ai/modules.md:1', 'module', 'catalog dir unlisted')
        want('KN-13', 'ai/_decision-index.md:1', 'decision index', 'index missing 0007-0008')
        want('KN-13', 'ai/_convention-cheatsheet.md:2', 'derived at', 'source changed since derivation sha')
        want('KN-11', [r['site'] for r in rows if r['kn'] == 'KN-11' and r['key'] == 'engine'][0] if
             [r for r in rows if r['kn'] == 'KN-11' and r['key'] == 'engine'] else 'none', 'engine', 'MySQL vs Postgres across files')
        want('KN-14', 'CLAUDE.md:9', 'citation', 'cited line one past the last line (a final newline is not a line)')
        want('KN-11', 'AGENTS.md:5', 'port:api', 'one port stated two ways')
        if not [r for r in rows if r['kn'] == 'KN-11' and r['key'] == 'port:api' and '4000' in r['claim'] and '3000' in r['claim']]:
            fails.append('KN-11 port row does not name both values: %s' % [r for r in rows if r['kn'] == 'KN-11'])
        deny(lambda r: r['kn'] == 'KN-11' and ('8080' in r['claim'] or '3100' in r['claim']), 'P-9 environment-named port')
        want('KN-12', 'CLAUDE.md:13', 'paragraph', 'a verbatim paragraph in two loaded files')
        want('KN-12', 'ai/architecture.md:3', 'paragraph', 'the other copy (--expand)')
        deny(lambda r: r['site'].startswith('.github/copilot-instructions.md'), 'P-17 generated per-tool copy')
        want('KN-13', 'ai/_session-digest.md:2', 'derived at', 'a second derived file at the same sha')
        deny(lambda r: r['site'] in ('CLAUDE.md:3', 'CLAUDE.md:5', 'CLAUDE.md:7', 'CLAUDE.md:11', 'AGENTS.md:3', 'AGENTS.md:4', 'AGENTS.md:6'),
             'P-14 / approx / unscoped count (P-28) / supporting citation')
        deny(lambda r: r['site'].endswith(':5') and r['site'].startswith('.claude/agents'), 'P-10 capability line in generic body')
        deny(lambda r: r['kn'] == 'KN-07' and r['site'] == 'CLAUDE.md:2' and r['key'] in ('node major', 'pm'), 'node 22 >=20 / pnpm')
        deny(lambda r: r['kn'] == 'KN-09' and 'catalog' not in r['claim'], 'listed module flagged')
        grouped = scan(root)
        g = [r for r in grouped if r['kn'] == 'KN-07' and r['key'] == 'engine' and r['sites'] == 3]
        if not g:
            fails.append('KN-12 grouping: 3 identical anchor copies did not collapse to one row with 3 sites')
        dg = sorted(r['site'] for r in grouped if r['kn'] == 'KN-13' and r['key'] == 'derived at')
        if dg != ['ai/_convention-cheatsheet.md:2', 'ai/_session-digest.md:2']:
            fails.append('two derived files at one sha merged into one group (each has its own sources): %s' % dg)
        pg = [r for r in grouped if r['kn'] == 'KN-12' and r['key'] == 'paragraph']
        if len(pg) != 1 or pg[0]['sites'] != 2 or 'ai/architecture.md:3' not in pg[0]['note']:
            fails.append('KN-12 paragraph copies not one row with 2 sites naming the other copy: %s' % pg)
        one = scan(root, only=('CLAUDE.md', 2), expand=True)
        if [r['site'] for r in one] != ['CLAUDE.md:2']:
            fails.append('--only did not isolate CLAUDE.md:2: %s' % [r['site'] for r in one])
        _w(root, 'CLAUDE.md', '# Project\npnpm monorepo on React 19 and Node 22.\n')
        if scan(root, only=('CLAUDE.md', 2), expand=True):
            fails.append('fixed line still fires')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        sys.stderr.write('self-test FAIL: %s\n' % f)
    print('knowledge-facts.py --self-test %s' % ('OK' if not fails else 'FAILED (%d)' % len(fails)))
    return 0 if not fails else 3


def main(argv):
    classes, only, corp, expand, as_json, root = (1, 2, 3, 4, 5, 6, 7), None, None, False, False, None
    for a in argv:
        if a == '--self-test':
            return self_test()
        elif a.startswith('--classes='):
            classes = tuple(int(x) for x in a.split('=', 1)[1].split(',') if x.strip())
        elif a.startswith('--only='):
            f, _, l = a.split('=', 1)[1].rpartition(':')
            if not l.isdigit():
                sys.stderr.write('--only needs <file>:<line>\n')
                return 2
            only = (f, int(l))
        elif a.startswith('--corpus='):
            src = a.split('=', 1)[1]
            txt = sys.stdin.read() if src == '-' else (K.read_text(src) or '')
            corp = [x.strip() for x in txt.split('\n') if x.strip()]
        elif a == '--expand':
            expand = True
        elif a == '--json':
            as_json = True
        elif a.startswith('-'):
            sys.stderr.write('unknown option %s\n' % a)
            return 2
        else:
            root = a
    if not root or not os.path.isdir(root):
        sys.stderr.write('usage: knowledge-facts.py <root> [options] | --self-test (blocked: no such root)\n')
        return 2
    rows = scan(root, classes, only, corp, expand)
    emit(rows, as_json)
    return 1 if rows else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
