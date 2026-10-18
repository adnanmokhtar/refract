#!/usr/bin/env python3
"""schema-map.py — the schema after the last migration, as one DDL file the database pack's parsers read.

Why a script: two shapes defeat a per-file DDL regex. (1) A migration that builds its DDL in code —
`alter table "${this.table}"`, `for (const [table, column] of this.columns) { … }` — names no table a
regex can read, so its indexes, FKs and type changes vanish from the map (a real NestJS + React
monorepo had 125 such files; the per-file parsers printed 86 stale FK rows and kept a column that a
loop had converted to numeric as float). (2) A MikroORM repo already commits the exact schema:
`migrations/.snapshot-<db>.json`, written by `migration:create`. It is current only up to the
migration it was generated with; files written by hand after it are not in it. This script finds
that horizon, takes the snapshot as the schema there, replays only the later migrations on top, and
prints the result as plain DDL with `-- @src <file>:<line>` markers so every object still cites
where it came from.

Lanes:
  mikro-orm-snapshot  a `.snapshot-*.json` beside the migrations: snapshot + replay of the later files.
  laravel             no snapshot, and `.php` migrations that call `Schema::` (Laravel Blueprint): each up()
                      replayed in filename order onto `database/schema/*-schema.sql` when `schema:dump` left one —
                      Schema::create/table/drop/dropIfExists/rename, every `$table->` column type with nullable,
                      default, unique, index, primary, unsigned, change(); foreignId()->constrained() (the
                      target inferred by plural when unnamed, counted), foreign()->references()->on(), the
                      on-delete/on-update helpers; enum/set as varchar(255) + the same `<t>_<c>_check` CHECK the
                      snapshot lane emits; decimal(p,s) as numeric(p,s) (Laravel's default 8,2); softDeletes,
                      timestamps, morphs, drops and renames; DB::statement('<sql>') through the DDL reader.
                      Comments and down() are dropped; `-- @src` cites each statement's line.
  ddl                 no snapshot: every migration file's up() body (down()/downgrade dropped), with
                      `${…}` names resolved from same-file string constants and loops unrolled.
Horizon (snapshot lane): `git` = migrations added after the last commit that touched the snapshot;
  `content` = the last migration that creates an object the snapshot holds (and no earlier file
  created). The replay starts after the EARLIER of the two: replaying a file the snapshot already
  holds is harmless, skipping one that it lacks is not.

Usage:  schema-map.py <repo-root> [--emit=sql|summary] [--snapshot=<path>] [--lane=ddl|laravel] [--entities]
        schema-map.py --self-test
  --emit=sql      (default) the DDL on stdout; header lines are `-- schema-map …` comments.
  --emit=summary  the lane, the horizon, the replay list and the unresolved `${…}` count only.
  --lane=ddl      ignore a snapshot (cross-check the replay against the full migration history).
  --lane=laravel  force the Blueprint lane (a repo with both a snapshot and PHP migrations: the V1 side
                  of a port read from the same checkout).
  --entities      schema-diff's static mode: MikroORM entity decorators vs the replayed schema.
                  Rows: MISSING-TABLE / MISSING-COLUMN / NULLABLE / GHOST-COLUMN / GHOST-TABLE /
                  MISSING-INDEX, each with its file:line. A candidate list, never a verdict.
Exit: 0 ran · 2 usage · 3 self-test failed. Stdlib only. Reads files and runs read-only git
(GIT_OPTIONAL_LOCKS=0: log, diff --name-only, ls-files); writes nothing (the self-test writes a temp dir).
"""
import json, os, re, subprocess, sys, tempfile

SKIP = {'node_modules', 'vendor', 'dist', 'build', 'target', '.git', '.venv', 'coverage', 'test', 'tests',
        '__tests__', 'spec', 'e2e', '__mocks__', 'mocks', 'fixtures', '__fixtures__', 'testdata', '.next', 'tmp'}
MIGDIR = re.compile(r'(^|/)(migrations?|migrate|alembic|versions|db)(/|$)', re.I)
MIGEXT = re.compile(r'\.(sql|ts|js|mjs|cjs|py)$')
DOWN = re.compile(r'(?m)^\s*(?:public\s+|override\s+)*(?:async\s+)?(?:def\s+|function\s+)?(?:down|downgrade)\s*(?:[(:]|$)'
                  r'|\bexports\.down\b|^--\s*\+(?:goose|migrate)\s+Down')
Q = r'[\\"`\[]*(?:\w+[\\"`\]]*\.[\\"`\[]*)?(\w+)[\\"`\]]*'          # [schema.]name, quotes stripped


def bal(s, i, o='(', c=')'):
    """Index of the bracket closing the one at s[i] (or len(s)-1)."""
    d = 0
    for j in range(i, len(s)):
        if s[j] == o: d += 1
        elif s[j] == c:
            d -= 1
            if d == 0: return j
    return len(s) - 1


def split(s):
    out, d, cur = [], 0, ''
    for ch in s:
        d += (ch in '([') - (ch in ')]')
        if ch == ',' and d == 0: out.append(cur); cur = ''
        else: cur += ch
    return [x.strip() for x in out + [cur] if x.strip()]


def unq(s): return re.sub(r'[\\"`\[\]]', '', s.strip()).split('.')[-1].lower()


def names(s): return [unq(x) if re.fullmatch(r'[\\"`\[\]\w.]+', x.strip()) else '(' + ' '.join(x.split()) + ')' for x in split(s)]


# ------------------------------------------------------------------ JS literal values (for ${…})
class JS:
    """A tiny reader for the literals migrations loop over: strings, numbers, arrays, objects, and
    identifiers already known (`this.x`, `x`). Anything else raises ValueError."""
    def __init__(self, s, env): self.s, self.i, self.env = s, 0, env
    def ws(self):
        while self.i < len(self.s):
            if self.s[self.i].isspace(): self.i += 1
            elif self.s.startswith('//', self.i):
                j = self.s.find('\n', self.i); self.i = j if j >= 0 else len(self.s)
            elif self.s.startswith('/*', self.i):
                j = self.s.find('*/', self.i + 2); self.i = j + 2 if j >= 0 else len(self.s)
            else: break
    def val(self):
        self.ws(); c = self.s[self.i:self.i + 1]
        if c in ('"', "'", '`'):
            j = self.i + 1
            while j < len(self.s) and self.s[j] != c: j += 2 if self.s[j] == '\\' else 1
            v = self.s[self.i + 1:j]
            if c == '`' and '${' in v: raise ValueError('template')
            self.i = j + 1; return v
        if c == '[':
            self.i += 1; out = []
            while True:
                self.ws()
                if self.s[self.i:self.i + 1] == ']': self.i += 1; return out
                out.append(self.val()); self.ws()
                if self.s[self.i:self.i + 1] == ',': self.i += 1
        if c == '{':
            self.i += 1; out = {}
            while True:
                self.ws()
                if self.s[self.i:self.i + 1] == '}': self.i += 1; return out
                m = re.compile(r'["\']?(\w+)["\']?\s*(:)?').match(self.s, self.i)
                if not m: raise ValueError('key')
                self.i = m.end()
                out[m.group(1)] = self.val() if m.group(2) else self.env[m.group(1)]
                self.ws()
                if self.s[self.i:self.i + 1] == ',': self.i += 1
        m = re.compile(r'-?\d+(?:\.\d+)?|(?:this\.)?\w+').match(self.s, self.i)
        if not m: raise ValueError('value')
        self.i = m.end(); w = m.group(0)
        if re.fullmatch(r'-?\d+(?:\.\d+)?', w): return w
        k = w[5:] if w.startswith('this.') else w
        if k in self.env: return self.env[k]
        raise ValueError('unknown ' + w)
    def full(self):
        v = self.val(); self.ws()
        if self.s[self.i:].strip(' ;\n').replace('as const', '').strip(): raise ValueError('trailing')
        return v


def resolve(src, rel, line0=1, full=None):
    """`${this.x}` / `${x}` / `${o.p}` replaced from same-file literals; `for (… of LIST) { … }` and
    `LIST.forEach/map((…) => …)` bodies unrolled once per element and appended with `-- @src` markers.
    Constants are read from `full` (the whole file: a module-level list may sit below down()).
    Returns (text, unresolved_count)."""
    env, full = {}, full or src
    for m in re.finditer(r'(?:\b(?:const|let|var|readonly|private|protected|public|static)\s+)+(\w+)\s*(?::\s*[^=;{}]{1,400}?)?=\s*(?=[\[{\'"`])', full):
        rest = full[m.end():]; c = rest[:1]
        try:
            if c in ('"', "'", '`', '[', '{'):
                end = bal(rest, 0, c, {'[': ']', '{': '}'}[c]) + 1 if c in '[{' else rest.find(c, 1) + 1
                env[m.group(1)] = JS(rest[:end], env).full()
        except (ValueError, IndexError, KeyError):
            pass
    def sub(text, local):
        def one(mm):
            path = mm.group(1).strip()
            path = path[5:] if path.startswith('this.') else path
            v = local
            for part in path.split('.'):
                if isinstance(v, dict) and part in v: v = v[part]
                else: return mm.group(0)
            return v if isinstance(v, str) else mm.group(0)
        return re.sub(r'\$\{\s*((?:this\.)?\w+(?:\.\w+)*)\s*\}', one, text)
    def bind(pat, el):
        pat = pat.strip()
        if pat.startswith('['):
            ns = [x.strip() for x in pat[1:-1].split(',')]
            return {n: v for n, v in zip(ns, el)} if isinstance(el, (list, tuple)) else None
        if pat.startswith('{'):
            ns = [x.split(':')[-1].strip() for x in pat[1:-1].split(',') if x.strip()]
            return {n: el.get(n) for n in ns} if isinstance(el, dict) else None
        return {pat: el}
    extra, spans = [], []
    loops = [(m, 'for') for m in re.finditer(r'\bfor\s*\(\s*(?:const|let|var)\s+(\w+|\[[^\]]*\]|\{[^}]*\})\s+of\s+', src)] + \
            [(m, 'fn') for m in re.finditer(r'(\[[^\[\]]*\]|(?:this\.)?\w+)\s*\.(?:forEach|map|flatMap)\(\s*(?:async\s*)?\(?\s*(\w+|\[[^\]]*\]|\{[^}]*\})\s*\)?\s*=>', src)]
    for m, kind in loops:
        try:
            if kind == 'for':
                hdr_end = bal(src, src.rfind('(', 0, m.end()))
                lst = JS(src[m.end():hdr_end], env).full(); pat = m.group(1)
                k = hdr_end + 1
                while k < len(src) and src[k].isspace(): k += 1
                if src[k:k + 1] != '{': continue
                b0, b1 = k + 1, bal(src, k, '{', '}')
            else:
                lst = JS(m.group(1), env).full(); pat = m.group(2)
                op = src.find('(', m.start() + len(m.group(1)))
                b0, b1 = m.end(), bal(src, op)
        except (ValueError, IndexError, KeyError):
            continue
        if not isinstance(lst, list): continue
        body = src[b0:b1]
        if not re.search(r'(?i)\b(create|alter|drop)\b', body): continue
        bl = line0 + src.count('\n', 0, b0); spans.append((b0, b1))
        for el in lst:
            loc = bind(pat, el)
            if loc is None: continue
            loc = dict(env, **{k: v for k, v in loc.items() if v is not None})
            extra.append('\n-- @src %s:%d\n%s\n' % (rel, bl, sub(body, loc)))
    out = sub(src, env); rest = src
    for b0, b1 in sorted(spans, reverse=True): rest = rest[:b0] + rest[b1:]
    unresolved = len(re.findall(r'(?i)\b(?:table|index|constraint|on|references|column)\s+(?:if\s+(?:not\s+)?exists\s+)?["`]?\$\{', sub(rest, env)))
    return out + ''.join(extra), unresolved


# ------------------------------------------------------------------ the model
def new_model(): return {}


def tab(M, t): return M.setdefault(t, {'cols': {}, 'idx': {}, 'fks': {}, 'chk': {}, 'at': ''})


def coldef(spec):
    m = re.match(r'(?is)\s*((?:double\s+precision\b|character\s+varying\b|timestamp(?:\s*\(\d\))?(?:\s+with(?:out)?\s+time\s+zone)?\b|[\w.]+)(?:\s*\([^)]*\))?(?:\s*\[\])?)(.*)', spec)
    if not m: return None
    rest = m.group(2)
    d = re.search(r'(?is)\bdefault\s+((?:\'[^\']*\'|\([^()]*\)|[^\s,])+(?:\s*::\s*[\w ]+)?)', rest)
    return {'type': ' '.join(m.group(1).lower().split()), 'nullable': not re.search(r'(?i)\bnot\s+null\b|\bprimary\s+key\b', rest),
            'default': d.group(1) if d else None, 'rest': rest}


def apply(M, text, rel, line0=1, counts=None):
    """Apply up()-side DDL in `text` to model M. `-- @src` markers in text override rel/line."""
    counts = counts if counts is not None else {'applied': 0, 'unparsed': 0}
    def at(pos):
        k = text.rfind('-- @src ', 0, pos)
        if k < 0: return '%s:%d' % (rel, line0 + text.count('\n', 0, pos))
        e = text.find('\n', k); p, _, l = text[k + 8:e].rpartition(':')
        return '%s:%d' % (p, int(l) + text.count('\n', e + 1, pos))
    def fk(t, n, cols, rest, a):
        r = re.match(r'(?is)\s*references\s+' + Q + r'\s*(?:\(([^)]*)\))?(.*)', rest)
        if not r: return
        od = re.search(r'(?i)\bon\s+delete\s+(set\s+null|set\s+default|no\s+action|restrict|cascade)', r.group(3))
        ou = re.search(r'(?i)\bon\s+update\s+(set\s+null|set\s+default|no\s+action|restrict|cascade)', r.group(3))
        T = tab(M, t); n = n or '%s_%s_fkey' % (t, '_'.join(cols))
        T['fks'][n] = {'cols': cols, 'ref': r.group(1).lower(), 'refcols': names(r.group(2) or 'id'),
                       'del': (od.group(1).lower() if od else ''), 'upd': (ou.group(1).lower() if ou else ''), 'at': a}
    def item(t, s, a):
        T = tab(M, t)
        k = re.match(r'(?is)(?:constraint\s+(\S+)\s+)?(primary\s+key|unique(?:\s+nulls\s+not\s+distinct)?)\s*\(([^)]*)\)', s)
        if k:
            n = unq(k.group(1)) if k.group(1) else '%s_%s_%s' % (t, '_'.join(names(k.group(3))), 'pkey' if 'primary' in k.group(2).lower() else 'key')
            T['idx'][n] = {'cols': names(k.group(3)), 'unique': True, 'primary': 'primary' in k.group(2).lower(), 'constraint': True, 'expr': None, 'at': a}; return
        k = re.match(r'(?is)(?:constraint\s+(\S+)\s+)?foreign\s+key\s*\(([^)]*)\)(.*)', s)
        if k: fk(t, unq(k.group(1)) if k.group(1) else None, names(k.group(2)), k.group(3), a); return
        k = re.match(r'(?is)(?:constraint\s+(\S+)\s+)?check\s*\((.*)\)', s)
        if k: T['chk'][unq(k.group(1)) if k.group(1) else '%s_check_%d' % (t, len(T['chk']))] = {'expr': k.group(2), 'at': a}; return
        k = re.match(r'(?is)[\\"`\[]*(\w+)[\\"`\]]*\s+(.*)', s)
        if k and k.group(1).lower() not in ('key', 'index', 'unique', 'primary', 'constraint', 'like', 'exclude'):
            c = k.group(1).lower(); d = coldef(k.group(2))
            if not d: return
            T['cols'][c] = {'type': d['type'], 'nullable': d['nullable'], 'default': d['default'], 'at': a}
            if re.search(r'(?i)\bprimary\s+key\b', d['rest']): T['idx']['%s_pkey' % t] = {'cols': [c], 'unique': True, 'primary': True, 'constraint': True, 'expr': None, 'at': a}
            elif re.search(r'(?i)\bunique\b', d['rest']): T['idx']['%s_%s_key' % (t, c)] = {'cols': [c], 'unique': True, 'primary': False, 'constraint': True, 'expr': None, 'at': a}
            r = re.search(r'(?is)\breferences\b.*', d['rest'])
            if r: fk(t, None, [c], r.group(0), a)
    def drop_named(n):
        for T in M.values():
            for key in ('idx', 'fks', 'chk'): T[key].pop(n, None)
    pat = re.compile(r'(?is)\b(create\s+(?:unlogged\s+|temp(?:orary)?\s+)?table|alter\s+table|create\s+(?:unique\s+)?index|drop\s+index|drop\s+table|alter\s+index)\b')
    for m in pat.finditer(text):
        if re.match(r'\s*(?:\*|//|/\*|--|#)', text[text.rfind('\n', 0, m.start()) + 1:m.start()]): continue   # prose in a comment
        kw = ' '.join(m.group(1).lower().split()); a = at(m.start()); seg = text[m.start():]
        stop = re.search(r';|`', seg); seg = seg[:stop.start()] if stop else seg[:4000]
        done = False
        if kw.startswith('create') and kw.endswith('table'):
            h = re.match(r'(?is)create\s+(?:unlogged\s+|temp(?:orary)?\s+)?table\s+(if\s+not\s+exists\s+)?' + Q + r'\s*\(', text[m.start():])
            if h:
                t = h.group(2).lower()
                if not (h.group(1) and t in M):
                    M[t] = {'cols': {}, 'idx': {}, 'fks': {}, 'chk': {}, 'at': a}
                    o = m.start() + h.end() - 1
                    for s in split(text[o + 1:bal(text, o)]): item(t, s, a)
                done = True
        elif kw == 'alter table':
            h = re.match(r'(?is)alter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?' + Q + r'\s+(.*)', seg)
            if h:
                t = h.group(1).lower(); done = True
                for act in split(h.group(2)):
                    x = re.match(r'(?is)add\s+(?:column\s+)?(?:if\s+not\s+exists\s+)?(?!constraint\b|primary\b|unique\b|foreign\b|check\b)(.*)', act)
                    if x: item(t, x.group(1), a); continue
                    x = re.match(r'(?is)add\s+(.*)', act)
                    if x: item(t, x.group(1), a); continue
                    x = re.match(r'(?is)drop\s+column\s+(?:if\s+exists\s+)?' + Q, act)
                    if x: tab(M, t)['cols'].pop(x.group(1).lower(), None); continue
                    x = re.match(r'(?is)drop\s+constraint\s+(?:if\s+exists\s+)?' + Q, act)
                    if x:
                        for key in ('idx', 'fks', 'chk'): tab(M, t)[key].pop(x.group(1).lower(), None)
                        continue
                    x = re.match(r'(?is)alter\s+(?:column\s+)?' + Q + r'\s+(?:set\s+data\s+)?type\s+(.+?)(?:\s+using\b.*|\s+collate\b.*)?$', act)
                    if x and x.group(1).lower() in tab(M, t)['cols']:
                        M[t]['cols'][x.group(1).lower()]['type'] = ' '.join(x.group(2).lower().split()); M[t]['cols'][x.group(1).lower()]['at'] = a; continue
                    x = re.match(r'(?is)alter\s+(?:column\s+)?' + Q + r'\s+(set|drop)\s+not\s+null', act)
                    if x and x.group(1).lower() in tab(M, t)['cols']: M[t]['cols'][x.group(1).lower()]['nullable'] = x.group(2).lower() == 'drop'; continue
                    x = re.match(r'(?is)alter\s+(?:column\s+)?' + Q + r'\s+set\s+default\s+(.+)', act)
                    if x and x.group(1).lower() in tab(M, t)['cols']: M[t]['cols'][x.group(1).lower()]['default'] = x.group(2).strip(); continue
                    x = re.match(r'(?is)alter\s+(?:column\s+)?' + Q + r'\s+drop\s+default', act)
                    if x and x.group(1).lower() in tab(M, t)['cols']: M[t]['cols'][x.group(1).lower()]['default'] = None; continue
                    x = re.match(r'(?is)rename\s+(?:column\s+)?' + Q + r'\s+to\s+' + Q, act)
                    if x and not re.match(r'(?i)rename\s+to\b', act) and x.group(1).lower() in tab(M, t)['cols']:
                        M[t]['cols'][x.group(2).lower()] = M[t]['cols'].pop(x.group(1).lower()); continue
                    x = re.match(r'(?is)rename\s+to\s+' + Q, act)
                    if x and t in M: M[x.group(1).lower()] = M.pop(t); t = x.group(1).lower(); continue
                    if re.match(r'(?is)(validate|enable|disable|force|no\s+force|owner|set\s+\(|reset|alter\s+(?:column\s+)?\S+\s+set\s+statistics|replica|cluster|inherit|attach|detach)', act): continue
                    counts['unparsed'] += 1
        elif kw.endswith('index') and kw.startswith('create'):
            h = re.match(r'(?is)create\s+(unique\s+)?index\s+(?:concurrently\s+)?(?:if\s+not\s+exists\s+)?(?:' + Q + r'\s+)?on\s+(?:only\s+)?' + Q + r'\s*(?:using\s+(\w+)\s*)?\(', text[m.start():])
            if h:
                o = m.start() + h.end() - 1; e = bal(text, o); tail = re.split(r';|`', text[e + 1:e + 400])[0]
                n = (h.group(2) or '%s_%d_idx' % (h.group(3), len(tab(M, h.group(3).lower())['idx']))).lower()
                inc = re.match(r'(?is)\s*include\s*\(([^)]*)\)', tail); wh = re.search(r'(?is)\bwhere\b(.*)', tail)
                tab(M, h.group(3).lower())['idx'][n] = {'cols': names(text[o + 1:e]), 'unique': bool(h.group(1)), 'primary': False, 'constraint': False,
                    'expr': None, 'method': (h.group(4) or '').lower(), 'include': names(inc.group(1)) if inc else [], 'where': ' '.join(wh.group(1).split()) if wh else '', 'at': a}
                done = True
        elif kw == 'drop index':
            for n in re.findall(Q, re.sub(r'(?is)^drop\s+index\s+(?:concurrently\s+)?(?:if\s+exists\s+)?|\s+(?:cascade|restrict)\s*$', '', seg))[:8]: drop_named(n.lower())
            done = True
        elif kw == 'drop table':
            for n in re.findall(Q, re.sub(r'(?is)^drop\s+table\s+(?:if\s+exists\s+)?|\s+(?:cascade|restrict)\s*$', '', seg))[:8]: M.pop(n.lower(), None)
            done = True
        elif kw == 'alter index':
            h = re.match(r'(?is)alter\s+index\s+(?:if\s+exists\s+)?' + Q + r'\s+rename\s+to\s+' + Q, seg)
            if h:
                for T in M.values():
                    if h.group(1).lower() in T['idx']: T['idx'][h.group(2).lower()] = T['idx'].pop(h.group(1).lower())
            done = True
        counts['applied' if done else 'unparsed'] += 1
    return counts


def created(text):
    """Objects an up() body creates: ('table', t) / ('name', index-or-constraint) / ('col', t, c)."""
    out = set()
    for m in re.finditer(r'(?is)create\s+(?:unlogged\s+)?table\s+(?:if\s+not\s+exists\s+)?' + Q, text): out.add(('table', m.group(1).lower()))
    for m in re.finditer(r'(?is)create\s+(?:unique\s+)?index\s+(?:concurrently\s+)?(?:if\s+not\s+exists\s+)?' + Q + r'\s+on\b', text): out.add(('name', m.group(1).lower()))
    for m in re.finditer(r'(?is)\badd\s+constraint\s+' + Q, text): out.add(('name', m.group(1).lower()))
    for m in re.finditer(r'(?is)alter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?' + Q + r'\s+add\s+(?:column\s+)?(?:if\s+not\s+exists\s+)?(?!constraint\b|primary\b|unique\b|foreign\b|check\b)' + Q, text):
        out.add(('col', m.group(1).lower(), m.group(2).lower()))
    return out


def holds(M, o):
    if o[0] == 'table': return o[1] in M
    if o[0] == 'col': return o[1] in M and o[2] in M[o[1]]['cols']
    return any(o[1] in T['idx'] or o[1] in T['fks'] or o[1] in T['chk'] for T in M.values())


# ------------------------------------------------------------------ the snapshot
def load_snapshot(path, rel):
    raw = open(path, encoding='utf-8').read(); d = json.loads(raw)
    lines = [0] + [i + 1 for i, ch in enumerate(raw) if ch == '\n']
    import bisect
    lno = lambda pos: bisect.bisect_right(lines, pos)
    tpos = [(mm.start(), mm.group(1)) for mm in re.finditer(r'"name":\s*"([^"]+)",\s*\n\s*"schema"', raw)]
    M = {}
    for k, tb in enumerate(d.get('tables', [])):
        t = tb['name'].lower()
        lo = tpos[k - 1][0] if k and k - 1 < len(tpos) else 0
        nm = tpos[k][0] if k < len(tpos) else len(raw)
        hi = tpos[k + 1][0] if k + 1 < len(tpos) else len(raw)
        def find(pat, a, b):
            mm = re.compile(pat).search(raw, a, b)
            return '%s:%d' % (rel, lno(mm.start()) if mm else lno(nm))
        T = M[t] = {'cols': {}, 'idx': {}, 'fks': {}, 'chk': {}, 'at': '%s:%d' % (rel, lno(nm))}
        for c in tb.get('columns', {}).values():
            T['cols'][c['name'].lower()] = {'type': c['type'].lower(), 'nullable': bool(c.get('nullable')), 'default': c.get('default'),
                                            'at': find(r'"%s":\s*\{' % re.escape(c['name']), lo, nm)}
            if c.get('enumItems'):                     # MikroORM folds a `col IN (…)` CHECK into enumItems: give it back as a CHECK
                T['chk']['%s_%s_check' % (t, c['name'].lower())] = {'expr': '"%s" in (%s)' % (c['name'], ', '.join("'%s'" % str(x).replace("'", "''") for x in c['enumItems'])),
                                                                    'at': T['cols'][c['name'].lower()]['at']}
        for i in tb.get('indexes', []):
            e = i.get('expression'); n = i['keyName'].lower(); a = find(r'"keyName":\s*"%s"' % re.escape(i['keyName']), nm, hi)
            T['idx'][n] = {'cols': [x.lower() for x in i.get('columnNames', [])], 'unique': bool(i.get('unique')), 'primary': bool(i.get('primary')),
                           'constraint': bool(i.get('constraint')), 'expr': e, 'at': a}
        for n, f in tb.get('foreignKeys', {}).items():
            T['fks'][n.lower()] = {'cols': [x.lower() for x in f['columnNames']], 'ref': f['referencedTableName'].split('.')[-1].lower(),
                                   'refcols': [x.lower() for x in f['referencedColumnNames']], 'del': (f.get('deleteRule') or '').lower(),
                                   'upd': (f.get('updateRule') or '').lower(), 'at': find(r'"constraintName":\s*"%s"' % re.escape(f['constraintName']), nm, hi)}
        for c in tb.get('checks', []):
            T['chk'][c['name'].lower()] = {'expr': c.get('expression') or re.sub(r'(?is)^check\s*\((.*)\)$', r'\1', c.get('definition') or ''),
                                          'at': find(r'"name":\s*"%s"' % re.escape(c['name']), nm, hi)}
    return M


def emit(M):
    out = []
    qi = lambda x: x if x.startswith('(') else '"%s"' % x
    for t in sorted(M):
        T = M[t]
        out.append('-- @src %s\ncreate table "%s" (\n);' % (T['at'] or '?:0', t))
        for c, d in T['cols'].items():
            out.append('-- @src %s\nalter table "%s" add column "%s" %s%s%s;' % (d['at'], t, c, d['type'], '' if d['nullable'] else ' not null',
                                                                                (' default ' + str(d['default'])) if d['default'] not in (None, '') else ''))
        for n, i in T['idx'].items():
            if i.get('expr'):
                out.append('-- @src %s\n%s;' % (i['at'], i['expr'].rstrip(';')))
            elif i['constraint'] or i['primary']:
                out.append('-- @src %s\nalter table "%s" add constraint "%s" %s (%s);' % (i['at'], t, n, 'primary key' if i['primary'] else 'unique', ', '.join(map(qi, i['cols']))))
            else:
                out.append('-- @src %s\ncreate %sindex "%s" on "%s"%s (%s)%s%s;' % (i['at'], 'unique ' if i['unique'] else '', n, t,
                           (' using ' + i['method']) if i.get('method') and i['method'] != 'btree' else '', ', '.join(map(qi, i['cols'])),
                           (' include (%s)' % ', '.join(map(qi, i['include']))) if i.get('include') else '', (' where ' + i['where']) if i.get('where') else ''))
        for n, f in T['fks'].items():
            out.append('-- @src %s\nalter table "%s" add constraint "%s" foreign key (%s) references "%s" (%s)%s%s;' % (
                f['at'], t, n, ', '.join(map(qi, f['cols'])), f['ref'], ', '.join(map(qi, f['refcols'])),
                (' on update ' + f['upd']) if f['upd'] else '', (' on delete ' + f['del']) if f['del'] else ''))
        for n, c in T['chk'].items():
            out.append('-- @src %s\nalter table "%s" add constraint "%s" check (%s);' % (c['at'], t, n, c['expr']))
    return '\n'.join(out) + '\n'


# ------------------------------------------------------------------ the laravel lane (Blueprint migrations)
LV_CALL = re.compile(r'\bSchema::(?:connection\s*\([^()]*\)\s*->\s*)?(create|table|drop|dropIfExists|rename)\s*\(')
LV_DB = re.compile(r'\bDB::(?:connection\s*\([^()]*\)\s*->\s*)?(statement|unprepared)\s*\(')


def php_mask(t):
    """(clean, masked): comments become spaces in both (same length, newlines kept); string interiors also
    become spaces in `masked`, so brackets and `;` inside a default('a;b') never split a statement."""
    c, m, i, n = list(t), list(t), 0, len(t)
    def blank(buf, a, b):
        for k in range(a, b):
            if buf[k] != '\n': buf[k] = ' '
    while i < n:
        ch = t[i]
        if ch in '\'"':
            j = i + 1
            while j < n and t[j] != ch: j += 2 if t[j] == '\\' else 1
            blank(m, i + 1, min(j, n)); i = j + 1; continue
        if t.startswith('//', i) or (ch == '#' and not t.startswith('#[', i)):
            j = t.find('\n', i); j = n if j < 0 else j; blank(c, i, j); blank(m, i, j); i = j; continue
        if t.startswith('/*', i):
            j = t.find('*/', i + 2); j = n if j < 0 else j + 2; blank(c, i, j); blank(m, i, j); i = j; continue
        i += 1
    return ''.join(c), ''.join(m)


def php_args(clean, masked, a, b):
    """Top-level argument spans of the call whose parens are masked[a] .. masked[b] -> clean texts."""
    out, d, cur = [], 0, a + 1
    for k in range(a + 1, b):
        ch = masked[k]
        if ch in '([{': d += 1
        elif ch in ')]}': d -= 1
        elif ch == ',' and d == 0: out.append(clean[cur:k]); cur = k + 1
    out.append(clean[cur:b])
    return [x.strip() for x in out if x.strip()]


def php_val(s):
    """A PHP literal -> str / list / None (null); anything else -> ('expr', text)."""
    s = (s or '').strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in '\'"': return s[1:-1].replace("\\'", "'")
    if re.fullmatch(r'-?\d+(?:\.\d+)?', s) or s.lower() in ('true', 'false'): return s.lower()
    if s.lower() == 'null': return None
    am = re.fullmatch(r'(?is)(?:array\s*\((.*)\)|\[(.*)\])', s)
    if am:
        inner = am.group(1) if am.group(1) is not None else am.group(2)
        _, mk = php_mask(inner)
        parts, d, cur = [], 0, 0
        for k, ch in enumerate(mk):
            if ch in '([{': d += 1
            elif ch in ')]}': d -= 1
            elif ch == ',' and d == 0: parts.append(inner[cur:k]); cur = k + 1
        parts.append(inner[cur:])
        return [php_val(x) for x in parts if x.strip()]
    rm = re.fullmatch(r'(?is)(?:DB::)?raw\s*\(\s*([\'"])(.*)\1\s*\)|DB::raw\s*\(\s*([\'"])(.*)\3\s*\)', s)
    if rm: return ('raw', rm.group(2) if rm.group(2) is not None else rm.group(4))
    return ('expr', ' '.join(s.split())[:60])


def plural(w):
    if re.search(r'[^aeiou]y$', w): return w[:-1] + 'ies'
    if re.search(r'(s|x|z|ch|sh)$', w): return w + 'es'
    return w + 's'


def lv_name(t, cols, kind):
    return re.sub(r'[-.]', '_', ('%s_%s_%s' % (t, '_'.join(cols), kind)).lower())


def lv_cols(v):
    v = php_val(v) if isinstance(v, str) else v
    return [x.lower() for x in (v if isinstance(v, list) else [v]) if isinstance(x, str)]


# column methods -> (type builder over the args after the name, implicit modifiers)
def _len(a, k, dflt): return a[k] if len(a) > k and re.fullmatch(r'\d+', a[k] or '') else dflt
LV_TYPES = {
    'id': lambda a: 'bigint unsigned', 'bigIncrements': lambda a: 'bigint unsigned', 'increments': lambda a: 'integer unsigned',
    'mediumIncrements': lambda a: 'mediumint unsigned', 'smallIncrements': lambda a: 'smallint unsigned', 'tinyIncrements': lambda a: 'tinyint unsigned',
    'foreignId': lambda a: 'bigint unsigned', 'foreignUuid': lambda a: 'uuid', 'foreignUlid': lambda a: 'char(26)',
    'bigInteger': lambda a: 'bigint', 'integer': lambda a: 'integer', 'mediumInteger': lambda a: 'mediumint',
    'smallInteger': lambda a: 'smallint', 'tinyInteger': lambda a: 'tinyint',
    'unsignedBigInteger': lambda a: 'bigint unsigned', 'unsignedInteger': lambda a: 'integer unsigned',
    'unsignedMediumInteger': lambda a: 'mediumint unsigned', 'unsignedSmallInteger': lambda a: 'smallint unsigned',
    'unsignedTinyInteger': lambda a: 'tinyint unsigned', 'boolean': lambda a: 'boolean',
    'string': lambda a: 'varchar(%s)' % _len(a, 0, '255'), 'char': lambda a: 'char(%s)' % _len(a, 0, '255'),
    'text': lambda a: 'text', 'tinyText': lambda a: 'tinytext', 'mediumText': lambda a: 'mediumtext', 'longText': lambda a: 'longtext',
    'decimal': lambda a: 'numeric(%s,%s)' % (_len(a, 0, '8'), _len(a, 1, '2')),
    'unsignedDecimal': lambda a: 'numeric(%s,%s) unsigned' % (_len(a, 0, '8'), _len(a, 1, '2')),
    'float': lambda a: 'float(%s)' % _len(a, 0, '53'), 'double': lambda a: 'double precision',
    'date': lambda a: 'date', 'time': lambda a: 'time without time zone', 'timeTz': lambda a: 'time with time zone',
    'dateTime': lambda a: 'timestamp without time zone', 'dateTimeTz': lambda a: 'timestamp with time zone',
    'timestamp': lambda a: 'timestamp without time zone', 'timestampTz': lambda a: 'timestamp with time zone',
    'year': lambda a: 'year', 'json': lambda a: 'json', 'jsonb': lambda a: 'jsonb', 'uuid': lambda a: 'uuid',
    'ulid': lambda a: 'char(26)', 'binary': lambda a: 'binary', 'ipAddress': lambda a: 'varchar(45)',
    'macAddress': lambda a: 'varchar(17)', 'enum': lambda a: 'varchar(255)', 'set': lambda a: 'varchar(255)',
}
LV_PK = {'id', 'bigIncrements', 'increments', 'mediumIncrements', 'smallIncrements', 'tinyIncrements'}
LV_FK_ON = {'cascadeOnDelete': ('del', 'cascade'), 'restrictOnDelete': ('del', 'restrict'), 'nullOnDelete': ('del', 'set null'),
            'noActionOnDelete': ('del', 'no action'), 'cascadeOnUpdate': ('upd', 'cascade'), 'restrictOnUpdate': ('upd', 'restrict'),
            'nullOnUpdate': ('upd', 'set null'), 'noActionOnUpdate': ('upd', 'no action')}


def lv_chain(clean, masked, i, end):
    """`$table->a(..)->b(..)` starting at the `->` after the variable -> ([(method, [args])], end offset)."""
    out = []
    while True:
        mm = re.compile(r'\s*->\s*(\w+)\s*\(').match(masked, i, end)
        if not mm: return out, i
        o = mm.end() - 1; e = bal(masked, o)
        out.append((mm.group(1), php_args(clean, masked, o, e))); i = e + 1


def lv_default(v):
    if v is None: return 'null'
    if isinstance(v, tuple): return v[1] if v[0] == 'raw' else 'UNREAD(%s)' % v[1]
    if isinstance(v, list): return 'UNREAD(array)'
    return v if re.fullmatch(r'-?\d+(?:\.\d+)?|true|false', v) else "'%s'" % v.replace("'", "''")


def lv_apply(M, t, chain, a, create, notes):
    """One `$table->…` statement against table t."""
    T = tab(M, t)
    name, args = chain[0]
    mods = {k: v for k, v in chain[1:]}
    col = php_val(args[0]) if args else ('id' if name == 'id' else None)
    col = col.lower() if isinstance(col, str) else col
    def fk(cols, ref, refcols, n, ch):
        f = {'cols': cols, 'ref': ref, 'refcols': refcols, 'del': '', 'upd': '', 'at': a}
        for k, v in ch:
            if k in LV_FK_ON: f[LV_FK_ON[k][0]] = LV_FK_ON[k][1]
            elif k in ('onDelete', 'onUpdate') and v:
                f['del' if k == 'onDelete' else 'upd'] = str(php_val(v[0])).lower()
            elif k == 'references' and v: f['refcols'] = lv_cols(v[0])
            elif k == 'on' and v: f['ref'] = str(php_val(v[0])).lower()
        T['fks'][n] = f
    if name in LV_TYPES and isinstance(col, str):
        if 'change' in mods and col in T['cols']:
            d = T['cols'][col]
        else:
            d = T['cols'][col] = {'type': '', 'nullable': False, 'default': None, 'at': a}
        d['type'] = LV_TYPES[name](args[1:]) if name != 'id' else 'bigint unsigned'
        if 'unsigned' in mods and 'unsigned' not in d['type']: d['type'] += ' unsigned'
        d['nullable'] = 'nullable' in mods and mods['nullable'] != ['false']   # change() restates every modifier (Laravel 11+)
        d['default'] = lv_default(php_val(mods['default'][0]) if mods['default'] else None) if 'default' in mods else None
        if 'useCurrent' in mods: d['default'] = 'CURRENT_TIMESTAMP'
        for g in ('storedAs', 'virtualAs'):
            if g in mods: d['default'] = 'generated(%s)' % (' '.join((mods[g] or [''])[0].split())[:60]); notes['generated'] += 1
        d['at'] = a
        if name in ('enum', 'set'):
            vals = php_val(args[1]) if len(args) > 1 else []
            expr = ', '.join("'%s'" % str(x).replace("'", "''") for x in vals) if isinstance(vals, list) else 'UNREAD(%s)' % vals[1]
            T['chk']['%s_%s_check' % (t, col)] = {'expr': '"%s" in (%s)' % (col, expr), 'at': a}
        if name in LV_PK or 'primary' in mods:
            T['idx']['%s_pkey' % t] = {'cols': [col], 'unique': True, 'primary': True, 'constraint': True, 'expr': None, 'at': a}
        if 'unique' in mods:
            n = str(php_val(mods['unique'][0])).lower() if mods['unique'] else lv_name(t, [col], 'unique')
            T['idx'][n] = {'cols': [col], 'unique': True, 'primary': False, 'constraint': True, 'expr': None, 'at': a}
        if 'index' in mods:
            n = str(php_val(mods['index'][0])).lower() if mods['index'] else lv_name(t, [col], 'index')
            T['idx'][n] = {'cols': [col], 'unique': False, 'primary': False, 'constraint': False, 'expr': None, 'at': a}
        if 'constrained' in mods:
            ca = mods['constrained']
            ref = str(php_val(ca[0])).lower() if ca and php_val(ca[0]) is not None else plural(re.sub(r'_id$', '', col))
            rc = [str(php_val(ca[1])).lower()] if len(ca) > 1 else ['id']
            if not ca: notes['inferred_ref'] += 1
            fk([col], ref, rc, lv_name(t, [col], 'foreign'), chain[1:])
        return True
    if name in ('timestamps', 'nullableTimestamps', 'timestampsTz'):
        ty = 'timestamp with time zone' if name == 'timestampsTz' else 'timestamp without time zone'
        for c in ('created_at', 'updated_at'): T['cols'][c] = {'type': ty, 'nullable': True, 'default': None, 'at': a}
        return True
    if name in ('softDeletes', 'softDeletesTz', 'softDeletesDatetime'):
        c = col if isinstance(col, str) else 'deleted_at'
        T['cols'][c] = {'type': 'timestamp with time zone' if name == 'softDeletesTz' else 'timestamp without time zone',
                        'nullable': True, 'default': None, 'at': a}
        return True
    if name == 'rememberToken':
        T['cols']['remember_token'] = {'type': 'varchar(100)', 'nullable': True, 'default': None, 'at': a}; return True
    if name in ('morphs', 'nullableMorphs', 'uuidMorphs', 'nullableUuidMorphs', 'ulidMorphs') and isinstance(col, str):
        nul = name.startswith('nullable')
        T['cols'][col + '_type'] = {'type': 'varchar(255)', 'nullable': nul, 'default': None, 'at': a}
        T['cols'][col + '_id'] = {'type': 'uuid' if 'Uuid' in name else 'char(26)' if 'ulid' in name else 'bigint unsigned', 'nullable': nul, 'default': None, 'at': a}
        T['idx'][lv_name(t, [col + '_type', col + '_id'], 'index')] = {'cols': [col + '_type', col + '_id'], 'unique': False, 'primary': False, 'constraint': False, 'expr': None, 'at': a}
        return True
    if name in ('primary', 'unique', 'index', 'fullText', 'spatialIndex') and args:
        cols = lv_cols(args[0]); kind = {'fullText': 'fulltext', 'spatialIndex': 'spatialindex'}.get(name, name)
        n = str(php_val(args[1])).lower() if len(args) > 1 and isinstance(php_val(args[1]), str) else ('%s_pkey' % t if name == 'primary' else lv_name(t, cols, kind))
        T['idx'][n] = {'cols': cols, 'unique': name in ('primary', 'unique'), 'primary': name == 'primary', 'constraint': name in ('primary', 'unique'),
                       'expr': None, 'method': name.lower() if name in ('fullText', 'spatialIndex') else '', 'at': a}
        return True
    if name == 'foreign' and args:
        cols = lv_cols(args[0])
        n = str(php_val(args[1])).lower() if len(args) > 1 and isinstance(php_val(args[1]), str) else lv_name(t, cols, 'foreign')
        fk(cols, '', ['id'], n, chain[1:]); return True
    if name == 'dropColumn' and args:
        for c in [x for v in args for x in lv_cols(v)]: T['cols'].pop(c, None)
        return True
    if name == 'renameColumn' and len(args) > 1:
        o, nw = str(php_val(args[0])).lower(), str(php_val(args[1])).lower()
        if o in T['cols']: T['cols'][nw] = T['cols'].pop(o)
        return True
    if name in ('dropUnique', 'dropIndex', 'dropPrimary', 'dropForeign', 'dropFullText') :
        v = php_val(args[0]) if args else None
        kind = {'dropUnique': 'unique', 'dropIndex': 'index', 'dropForeign': 'foreign', 'dropFullText': 'fulltext'}.get(name)
        n = v.lower() if isinstance(v, str) else ('%s_pkey' % t if name == 'dropPrimary' else lv_name(t, lv_cols(v), kind) if isinstance(v, list) else None)
        if n:
            for key in ('idx', 'fks', 'chk'): T[key].pop(n, None)
        return True
    if name == 'renameIndex' and len(args) > 1:
        o, nw = str(php_val(args[0])).lower(), str(php_val(args[1])).lower()
        if o in T['idx']: T['idx'][nw] = T['idx'].pop(o)
        return True
    if name in ('dropSoftDeletes', 'dropSoftDeletesTz'): T['cols'].pop(col if isinstance(col, str) else 'deleted_at', None); return True
    if name in ('dropTimestamps', 'dropTimestampsTz'):
        for c in ('created_at', 'updated_at'): T['cols'].pop(c, None)
        return True
    if name in ('dropMorphs',) and isinstance(col, str):
        for c in (col + '_type', col + '_id'): T['cols'].pop(c, None)
        return True
    if name in ('engine', 'charset', 'collation', 'comment', 'temporary'): return True
    return False


def lv_file(M, path, rel, counts, notes):
    raw = open(path, encoding='utf-8', errors='replace').read()
    clean, masked = php_mask(raw)
    dn = DOWN.search(masked)
    stop = dn.start() if dn else len(masked)
    line = lambda pos: raw.count('\n', 0, pos) + 1
    for mo in sorted(list(LV_CALL.finditer(masked, 0, stop)) + list(LV_DB.finditer(masked, 0, stop)), key=lambda x: x.start()):
        o = mo.end() - 1; e = bal(masked, o); args = php_args(clean, masked, o, e); a = '%s:%d' % (rel, line(mo.start()))
        kind = mo.group(1)
        if kind in ('statement', 'unprepared'):
            sql = php_val(args[0]) if args else None
            if isinstance(sql, str): apply(M, sql, rel, line(mo.start()), counts)
            else: counts['unparsed'] += 1
            continue
        t = php_val(args[0]) if args else None
        if not isinstance(t, str): counts['unparsed'] += 1; notes['unread_table'] += 1; continue
        t = t.lower()
        if kind in ('drop', 'dropIfExists'): M.pop(t, None); counts['applied'] += 1; continue
        if kind == 'rename':
            nw = php_val(args[1]) if len(args) > 1 else None
            if isinstance(nw, str) and t in M: M[nw.lower()] = M.pop(t)
            counts['applied'] += 1; continue
        if kind == 'create':
            M[t] = {'cols': {}, 'idx': {}, 'fks': {}, 'chk': {}, 'at': a}
        pv = re.search(r'(?:function|fn)\s*\(\s*(?:\??[\w\\]+\s+)?\$(\w+)', masked[o:e])
        var = pv.group(1) if pv else 'table'
        k = o
        for sm in re.compile(r'\$%s\b(?=\s*->)' % var).finditer(masked, o, e):
            if sm.start() < k: continue
            ch, k = lv_chain(clean, masked, sm.end(), e)
            if not ch: continue
            sa = '%s:%d' % (rel, line(sm.start()))
            if lv_apply(M, t, ch, sa, kind == 'create', notes): counts['applied'] += 1
            else: counts['unparsed'] += 1; notes['unknown'].add(ch[0][0])


def lv_migrations(root):
    out = []
    for p in walk(root):
        r = os.path.relpath(p, root)
        if p.endswith('.php') and MIGDIR.search(os.path.dirname(r)):
            try: t = open(p, encoding='utf-8', errors='replace').read()
            except OSError: continue
            if 'Schema::' in t: out.append(p)
    return sorted(out, key=os.path.basename)


def lv_dump(root):
    """`php artisan schema:dump` output: database/schema/<connection>-schema.sql, the history before the oldest migration."""
    d = os.path.join(root, 'database', 'schema')
    return sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith('-schema.sql')) if os.path.isdir(d) else []


def lv_dump_text(sql):
    """MySQL dump index lines inside CREATE TABLE as statements apply() reads."""
    out = []
    for m in re.finditer(r'(?is)create\s+table\s+`?(\w+)`?\s*\(', sql):
        body = sql[m.end() - 1:bal(sql, m.end() - 1)]
        for km in re.finditer(r'(?im)^\s*(unique\s+)?key\s+`?(\w+)`?\s*\(([^)]*(?:\([^)]*\)[^)]*)*)\)', body):
            cols = re.sub(r'\(\d+\)', '', km.group(3))
            out.append('create %sindex "%s" on "%s" (%s);' % ('unique ' if km.group(1) else '', km.group(2), m.group(1), cols))
    return re.sub(r'(?im)^\s*(?:unique\s+)?key\s+`?\w+`?\s*\(.*$', '', sql) + '\n' + '\n'.join(out)


def run_laravel(root, rel):
    M, counts = {}, {'applied': 0, 'unparsed': 0}
    notes = {'inferred_ref': 0, 'generated': 0, 'unread_table': 0, 'unknown': set()}
    dumps = lv_dump(root)
    for p in dumps:
        apply(M, lv_dump_text(open(p, encoding='utf-8', errors='replace').read()), rel(p), 1, counts)
    migs = lv_migrations(root)
    for p in migs: lv_file(M, p, rel(p), counts, notes)
    hdr = ['covers %s' % rel(p) for p in dumps + migs] + [
        'lane=laravel: %d Blueprint migration file(s)%s; tables=%d columns=%d fks=%d indexes=%d checks=%d' % (
            len(migs), ' after schema dump %s' % ', '.join(rel(p) for p in dumps) if dumps else '', len(M),
            sum(len(T['cols']) for T in M.values()), sum(len(T['fks']) for T in M.values()),
            sum(len(T['idx']) for T in M.values()), sum(len(T['chk']) for T in M.values())),
        'laravel: %d statement(s) applied, %d not understood%s; %d constrained() target(s) inferred by plural (read them); '
        '%d generated column(s); %d table name(s) not a literal' % (
            counts['applied'], counts['unparsed'], ' (%s)' % ', '.join(sorted(notes['unknown']))[:200] if notes['unknown'] else '',
            notes['inferred_ref'], notes['generated'], notes['unread_table']),
        'laravel: types are the Blueprint method mapped to SQL (decimal -> numeric(p,s), enum -> varchar(255) + CHECK, '
        'dateTime -> timestamp without time zone); the engine-specific type is the driver\'s — read config/database.php']
    return M, hdr


# ------------------------------------------------------------------ repo walking
def git(root, *args):
    try:
        r = subprocess.run(['git', '-C', root] + list(args), capture_output=True, text=True, timeout=60,
                           env=dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0'))
        return r.stdout if r.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def walk(root):
    for dp, dns, fns in os.walk(root):
        dns[:] = sorted(d for d in dns if d not in SKIP)
        for f in sorted(fns): yield os.path.join(dp, f)


def up_text(p, both=False):
    t = open(p, encoding='utf-8', errors='replace').read().replace('\\"', '"')
    dn = DOWN.search(t)
    return (t[:dn.start()] if dn else t, t) if both else (t[:dn.start()] if dn else t)


def migrations_in(root, d):
    fs = [p for p in walk(d) if MIGEXT.search(p) and not re.search(r'\.(spec|test|d)\.\w+$', p) and not os.path.basename(p).startswith('.')]
    return sorted(fs, key=lambda p: os.path.basename(p))


def run(root, mode, snap=None, lane=None):
    root = os.path.abspath(root); rel = lambda p: os.path.relpath(p, root)
    if lane in ('ddl', 'laravel'): snap = None
    elif not snap:
        cands = [p for p in walk(root) if re.match(r'\.snapshot-.*\.json$', os.path.basename(p))]
        snap = cands[0] if cands else None
    hdr, unres, resolved_files = [], 0, 0
    if snap:
        mdir = os.path.dirname(snap); migs = migrations_in(root, mdir)
        M = load_snapshot(snap, rel(snap))
        texts = {}
        for p in migs:
            raw, full = up_text(p, True); txt, u = resolve(raw, rel(p), 1, full); texts[p] = (txt, u)
        # content horizon
        seen, hz_c = set(), None
        for k, p in enumerate(migs):
            objs = created(texts[p][0])
            if any(holds(M, o) for o in objs - seen): hz_c = k
            seen |= objs
        # git horizon
        hz_g, gitline = None, 'git: not a git checkout (or git absent)'
        log = git(root, 'log', '-1', '--format=%H %h %cs', '--', rel(snap))
        if log and log.strip():
            full, short, day = log.split()
            added = set((git(root, 'diff', '--name-only', '--diff-filter=A', full, 'HEAD', '--', rel(mdir)) or '').split())
            added |= set((git(root, 'ls-files', '--others', '--exclude-standard', '--', rel(mdir)) or '').split())
            after = [k for k, p in enumerate(migs) if rel(p) in added]
            hz_g = (min(after) - 1) if after else len(migs) - 1
            gitline = 'git: snapshot last committed %s (%s); %d migration file(s) added after it' % (short, day, len(after))
        cand = [h for h in (hz_g, hz_c) if h is not None]
        hz = min(cand) if cand else -1
        replay = migs[hz + 1:]
        counts = {'applied': 0, 'unparsed': 0}
        for p in replay:
            apply(M, texts[p][0], rel(p), 1, counts)
            unres += texts[p][1]
        name = lambda k: os.path.basename(migs[k]) if k is not None and 0 <= k < len(migs) else 'none'
        hdr = ['covers %s/' % rel(mdir),
               'lane=mikro-orm-snapshot snapshot=%s tables=%d columns=%d fks=%d indexes=%d checks=%d' % (
                   rel(snap), len(M), sum(len(T['cols']) for T in M.values()), sum(len(T['fks']) for T in M.values()),
                   sum(len(T['idx']) for T in M.values()), sum(len(T['chk']) for T in M.values())),
               'horizon %s' % gitline,
               'horizon content: %s (the last migration creating an object the snapshot holds)' % name(hz_c),
               'replay: %d of %d migration file(s), from the earlier horizon: %s' % (len(replay), len(migs), ' '.join(os.path.basename(p) for p in replay) or '-'),
               'replayed: %d statement(s) applied, %d not understood (read those files); %d unresolved ${...} name(s) in replayed files' % (counts['applied'], counts['unparsed'], unres)]
        body = emit(M)
    elif lane == 'laravel' or (lane is None and lv_migrations(root)):
        M, hdr = run_laravel(root, rel)
        if lane is None: hdr[-3] = hdr[-3].replace('lane=laravel:', 'lane=laravel (no .snapshot-*.json; Blueprint migrations found):', 1)
        body = emit(M)
    else:
        parts, covers, n = [], [], 0
        for p in walk(root):
            r = rel(p)
            if not (MIGEXT.search(p) and MIGDIR.search(os.path.dirname(r))) or re.search(r'\.(spec|test|d)\.\w+$', p): continue
            raw, full = up_text(p, True)
            if not re.search(r'(?i)\b(create|alter|drop)\s+(?:unique\s+)?(table|index)\b', raw): continue
            n += 1; txt, u = resolve(raw, r, 1, full); unres += u
            if txt != raw: resolved_files += 1
            parts.append('-- @src %s:1\n%s' % (r, txt)); covers.append('covers ' + r)
        hdr = covers + ['lane=ddl%s: %d migration file(s) with DDL, %d had ${...} names resolved or loops unrolled; %d unresolved ${...} name(s) remain' % (' (forced)' if lane == 'ddl' else ' (no .snapshot-*.json)', n, resolved_files, unres)]
        body = '\n'.join(parts) + '\n'
        M = None
    if mode == 'summary':
        print('\n'.join('# schema-map ' + h for h in hdr if not h.startswith('covers ')))
    else:
        sys.stdout.write(''.join('-- schema-map %s\n' % h for h in hdr) + body)
    return M


# ------------------------------------------------------------------ entities (schema-diff static mode)
def entities(root, M):
    snake = lambda n: re.sub(r'(?<=[a-z0-9])([A-Z])', r'_\1', n).lower()
    classes = {}
    for p in walk(root):
        if not p.endswith('.ts') or re.search(r'\.(spec|e2e-spec|test|d)\.ts$', p) or MIGDIR.search(os.path.relpath(os.path.dirname(p), root)): continue
        t = open(p, encoding='utf-8', errors='replace').read()
        if '@mikro-orm' not in t: continue
        for m in re.finditer(r'(?m)^(?:export\s+)?(?:abstract\s+)?class\s+(\w+)(?:<[^>{]*>)?(?:\s+extends\s+(\w+))?[^{]*\{', t):
            seg = t[max(0, m.start() - 4000):m.start()]; cut = max(seg.rfind('}\n'), seg.rfind(';\n')); decos = seg[cut + 1:] if cut >= 0 else seg
            body = t[m.end():bal(t, m.end() - 1, '{', '}')]
            ent = re.search(r'@Entity\(\s*\{[^}]*tableName:\s*[\'"](\w+)[\'"]', decos); bare = re.search(r'@Entity\(\s*\)', decos)
            if not ent:                                              # tableName: SOME_CONST, a same-file string constant
                ref = re.search(r'@Entity\(\s*\{[^}]*tableName:\s*(\w+)\b', decos)
                ent = ref and re.search(r'\bconst\s+%s\s*(?::\s*\w+\s*)?=\s*[\'"](\w+)[\'"]' % ref.group(1), t)
            props = []
            for pm in re.finditer(r'@(Property|ManyToOne|OneToOne|Enum|PrimaryKey|OneToMany|ManyToMany|Formula|Embedded)\(', body):
                a = pm.end() - 1; b = bal(body, a); args = body[a + 1:b]
                nm = re.match(r'\s*(?:(?:@\w+\((?:[^()]|\([^()]*\))*\)|//[^\n]*|/\*.*?\*/)\s*)*(?:public\s+|readonly\s+|declare\s+|override\s+)*(\w+)\s*[!?]?\s*[:=;]', body[b + 1:b + 400], re.S)
                if nm: props.append((pm.group(1), nm.group(1), args, '%s:%d' % (os.path.relpath(p, root), t.count('\n', 0, m.end() + pm.start()) + 1)))
            idx = [(im.group(1), re.search(r'name:\s*[\'"](\w+)[\'"]', (decos + body)[im.end():bal(decos + body, im.end() - 1)]))
                   for im in re.finditer(r'@(Index|Unique)\(', decos + body)]
            classes[m.group(1)] = dict(table=ent.group(1).lower() if ent else (snake(m.group(1).replace('Entity', '')) if bare else None), parent=m.group(2),
                                       props=props, idx=[(k, n.group(1).lower()) for k, n in idx if n], at='%s:%d' % (os.path.relpath(p, root), t.count('\n', 0, m.start()) + 1))
    def chain(c):
        seen = []
        while c in classes and c not in [x['at'] for x in seen]:
            seen.append(classes[c]); c = classes[c]['parent']
        return seen
    rows, mapped = [], set()
    for n, c in sorted(classes.items(), key=lambda x: x[1]['table'] or ''):
        tb = c['table']
        if not tb: continue
        mapped.add(tb)
        if tb not in M: rows.append(('MISSING-TABLE', tb, '', c['at'], 'entity %s maps a table the schema does not have' % n)); continue
        cols = {}
        for cc in chain(n):
            for kind, prop, args, at in cc['props']:
                if kind in ('OneToMany', 'ManyToMany', 'Formula', 'Embedded') or re.search(r'persist:\s*false', args): continue
                nm = re.search(r'\b(?:name|fieldName):\s*[\'"](\w+)[\'"]', args) or re.search(r'joinColumn:\s*[\'"](\w+)[\'"]', args)
                col = nm.group(1).lower() if nm else snake(prop) + ('_id' if kind in ('ManyToOne', 'OneToOne') else '')
                cols.setdefault(col, (prop, bool(re.search(r'nullable:\s*true', args)), at, kind))
        sc = M[tb]['cols']
        for col, (prop, nul, at, kind) in cols.items():
            if col not in sc: rows.append(('MISSING-COLUMN', tb, col, at, 'entity %s.%s' % (n, prop)))
            elif kind != 'PrimaryKey' and nul != sc[col]['nullable']: rows.append(('NULLABLE', tb, col, at, 'entity nullable=%s, schema nullable=%s (%s)' % (nul, sc[col]['nullable'], sc[col]['at'])))
        for col, d in sc.items():
            if col not in cols: rows.append(('GHOST-COLUMN', tb, col, d['at'], 'schema column (%s%s) no entity property maps' % (d['type'], '' if d['nullable'] else ' not null')))
        for kind, iname in [x for cc in chain(n) for x in cc['idx']]:
            if iname not in M[tb]['idx'] and iname not in M[tb]['fks']: rows.append(('MISSING-INDEX', tb, iname, c['at'], '@%s declared, not in the schema' % kind))
    for tb in sorted(set(M) - mapped): rows.append(('GHOST-TABLE', tb, '', M[tb]['at'], 'no @Entity maps it (%d columns)' % len(M[tb]['cols'])))
    print('# entities: %d mapped classes vs %d schema tables' % (len(mapped), len(M)))
    for r in rows: print('\t'.join(r))


# ------------------------------------------------------------------ self-test
SELF = {
    'apps/api/src/migrations/Migration20260101000000.ts':
        "export class Migration20260101000000 extends Migration {\n  override async up() {\n"
        "    this.addSql(`create table \"orders\" (\"id\" uuid primary key, \"tenant_id\" uuid not null, \"total\" double precision);`);\n  }\n}\n",
    'apps/api/src/migrations/Migration20260102000000.ts':
        "export class Migration20260102000000 extends Migration {\n  private readonly table = 'order_items';\n"
        "  private readonly columns = [\n    ['orders', 'total'],\n  ] as const;\n  override async up() {\n"
        "    this.addSql(`create table \"${this.table}\" (\"id\" uuid primary key, \"order_id\" uuid not null, \"tenant_id\" uuid not null);`);\n"
        "    this.addSql(`create index \"${this.table}_order_idx\" on \"${this.table}\" (\"order_id\");`);\n"
        "    for (const [table, column] of this.columns) {\n      this.addSql(`alter table \"${table}\" alter column \"${column}\" type numeric(14,4) using \"${column}\"::numeric;`);\n    }\n"
        "  }\n  override async down() {\n    this.addSql(`drop table \"${this.table}\";`);\n  }\n}\n",
    'apps/api/src/migrations/Migration20260103000000.ts':
        "export class Migration20260103000000 extends Migration {\n  override async up() {\n"
        "    this.addSql(`alter table \"order_items\" add constraint \"order_items_order_fk\" foreign key (\"tenant_id\", \"order_id\") references \"orders\" (\"tenant_id\", \"id\") on delete cascade;`);\n"
        "    this.addSql(`create unique index \"orders_tenant_email_unique\" on \"orders\" (\"tenant_id\", lower(btrim(\"email\")));`);\n"
        "    this.addSql(`alter table \"orders\" add column \"email\" text, add column \"note\" text;`);\n  }\n}\n",
    'apps/api/src/migrations/Migration20260104000000.ts':
        "export class Migration20260104000000 extends Migration {\n  override async up() {\n"
        "    this.addSql(`alter table \"order_items\" drop constraint \"order_items_order_fk\";`);\n"
        "    this.addSql(`alter table \"orders\" drop column \"note\";`);\n    this.addSql(`drop table if exists \"legacy\";`);\n"
        "    this.addSql(`create index \"orders_created_idx\" on \"orders\" (\"created_at\") include (\"status\") where \"status\" = 'pending';`);\n"
        "    for (const [name] of COVERED) {\n      this.addSql(`drop index if exists \"${name}\";`);\n    }\n  }\n"
        "  override async down() {}\n}\nconst COVERED = [\n  ['order_items_order_idx', 'order_items'],\n] as const;\n",
}
SNAP = {'namespaces': ['public'], 'name': 'app', 'nativeEnums': {}, 'tables': [
    {'columns': {'id': {'name': 'id', 'type': 'uuid', 'nullable': False, 'default': None},
                 'tenant_id': {'name': 'tenant_id', 'type': 'uuid', 'nullable': False, 'default': None},
                 'total': {'name': 'total', 'type': 'numeric(14,4)', 'nullable': True, 'default': None},
                 'status': {'name': 'status', 'type': 'varchar(16)', 'nullable': False, 'default': "'new'", 'enumItems': ['new', 'paid'], 'mappedType': 'enum'}},
     'name': 'orders', 'schema': 'public', 'indexes': [{'columnNames': ['id'], 'keyName': 'orders_pkey', 'unique': True, 'primary': True, 'constraint': True}],
     'checks': [], 'foreignKeys': {}, 'nativeEnums': {}, 'comment': None},
    {'columns': {'id': {'name': 'id', 'type': 'uuid', 'nullable': False, 'default': None},
                 'order_id': {'name': 'order_id', 'type': 'uuid', 'nullable': False, 'default': None},
                 'tenant_id': {'name': 'tenant_id', 'type': 'uuid', 'nullable': False, 'default': None}},
     'name': 'order_items', 'schema': 'public',
     'indexes': [{'columnNames': ['order_id'], 'keyName': 'order_items_order_idx', 'unique': False, 'primary': False, 'constraint': False}],
     'checks': [], 'foreignKeys': {}, 'nativeEnums': {}, 'comment': None},
    {'columns': {'id': {'name': 'id', 'type': 'int4', 'nullable': False, 'default': None}}, 'name': 'legacy', 'schema': 'public',
     'indexes': [], 'checks': [], 'foreignKeys': {}, 'nativeEnums': {}, 'comment': None}]}

LV = {
    'database/migrations/2024_01_01_000000_create_users_table.php':
        "<?php\nuse Illuminate\\Database\\Migrations\\Migration;\nuse Illuminate\\Database\\Schema\\Blueprint;\n"
        "use Illuminate\\Support\\Facades\\Schema;\n\nreturn new class extends Migration\n{\n    public function up(): void\n    {\n"
        "        Schema::create('users', function (Blueprint $table) {\n            $table->id();\n"
        "            $table->string('email')->unique();\n            $table->string('name', 120)->nullable();\n"
        "            $table->rememberToken();\n            $table->timestamps();\n            $table->softDeletes();\n        });\n"
        "        // Schema::create('ghost', function (Blueprint $table) { $table->id(); });\n    }\n\n"
        "    public function down(): void\n    {\n        Schema::dropIfExists('users');\n    }\n};\n",
    'database/migrations/2024_01_02_000000_create_orders_table.php':
        "<?php\nreturn new class extends Migration {\n    public function up(): void {\n"
        "        Schema::create('orders', function (Blueprint $t) {\n            $t->id();\n"
        "            $t->foreignId('user_id')->constrained()->cascadeOnDelete();\n"
        "            $t->foreignId('tenant_id')->constrained('tenants');\n"
        "            $t->decimal('total', 12, 2)->default(0);\n            $t->decimal('tax');\n"
        "            $t->enum('status', ['new', 'paid'])->default('new');\n"
        "            $t->string('note')->nullable();\n            $t->string('url')->default('http://x.test/a;b)');  # a ; ) and // in a string\n"
        "            $t->unique(['tenant_id', 'user_id']);\n            $t->index('status', 'orders_status_ix');\n"
        "            $t->timestamps();\n            $t->softDeletes();\n        });\n"
        "        Schema::create('payments', fn (Blueprint $table) => $table->uuid('id')->primary());\n"
        "    }\n    public function down(): void { Schema::drop('orders'); }\n};\n",
    'database/migrations/2024_02_01_000000_alter_orders.php':
        "<?php\nreturn new class extends Migration {\n    public function up(): void {\n"
        "        Schema::table('orders', function (Blueprint $table) {\n"
        "            $table->string('note', 500)->change();\n            $table->dropColumn('tax');\n"
        "            $table->renameColumn('total', 'grand_total');\n            $table->dropUnique(['tenant_id', 'user_id']);\n"
        "            $table->foreignId('coupon_id')->nullable()->constrained('coupons', 'code')->nullOnDelete();\n"
        "            $table->foreign('user_id', 'orders_owner_fk')->references('id')->on('users')->onDelete('restrict');\n"
        "        });\n        Schema::dropIfExists('payments');\n"
        "        DB::statement('create index orders_note_idx on orders (note)');\n    }\n};\n",
}


def self_test():
    fails, n = [], [0]
    def ok(cond, msg):
        n[0] += 1
        if not cond: fails.append(msg)
    d = tempfile.mkdtemp(prefix='schema-map-')
    for r, txt in SELF.items():
        p = os.path.join(d, r); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w').write(txt)
    # 1. resolver: scalar fields and a tuple loop
    txt, u = resolve(up_text(os.path.join(d, 'apps/api/src/migrations/Migration20260102000000.ts')), 'm2.ts')
    ok('create table "order_items"' in txt, 'resolve: ${this.table} not replaced')
    ok('alter table "orders" alter column "total" type numeric(14,4)' in txt, 'resolve: tuple loop not unrolled')
    ok('drop table' not in txt, 'resolve: down() body kept')
    ok(u == 0, 'resolve: %d unresolved' % u)
    # 2. ddl lane (no snapshot): the order and the drops are applied by the model
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf): run(d, 'sql')
    sql = buf.getvalue()
    ok('lane=ddl' in sql and '-- @src apps/api/src/migrations/Migration20260102000000.ts:1' in sql, 'ddl lane: header or marker missing')
    M = {}
    for p in migrations_in(d, os.path.join(d, 'apps/api/src/migrations')):
        apply(M, resolve(up_text(p), p)[0], p)
    ok(M['orders']['cols']['total']['type'].startswith('numeric'), 'apply: loop type change lost (%s)' % M['orders']['cols']['total']['type'])
    ok('order_items_order_fk' not in M['order_items']['fks'], 'apply: dropped FK still present')
    ok('note' not in M['orders']['cols'] and 'email' in M['orders']['cols'], 'apply: add/drop column wrong')
    ok(M['orders']['idx']['orders_tenant_email_unique']['cols'] == ['tenant_id', '(lower(btrim("email")))'], 'apply: nested expression index cols %r' % M['orders']['idx'].get('orders_tenant_email_unique'))
    ix = M['orders']['idx']['orders_created_idx']
    ok(ix['include'] == ['status'] and 'pending' in ix['where'], 'apply: include/where not captured %r' % ix)
    # 3. snapshot lane: horizon = Migration20260102 by content (order_items_order_idx is in the snapshot), replay 03 + 04
    json.dump(SNAP, open(os.path.join(d, 'apps/api/src/migrations/.snapshot-app.json'), 'w'), indent=2)
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf): M2 = run(d, 'sql')
    out = buf.getvalue()
    ok('horizon content: Migration20260102000000.ts' in out, 'snapshot: content horizon wrong:\n' + out[:600])
    ok('replay: 2 of 4' in out, 'snapshot: replay count wrong')
    ok('legacy' not in M2, 'snapshot: replayed drop table not applied')
    ok('order_items_order_fk' not in M2['order_items']['fks'], 'snapshot: replayed drop constraint not applied')
    ok(M2['orders']['cols']['total']['type'] == 'numeric(14,4)', 'snapshot: column type from the snapshot lost')
    ok('alter table "orders" add constraint "orders_status_check" check ("status" in (\'new\', \'paid\'));' in out, 'emit: enumItems not returned as a CHECK')
    ok('order_items_order_idx' not in M2['order_items']['idx'], 'snapshot: loop over a module-level list below down() not replayed')
    ok(re.search(r'-- @src apps/api/src/migrations/\.snapshot-app\.json:\d+\nalter table "orders" add column "total" numeric\(14,4\);', out), 'emit: snapshot column line missing')
    ok('-- @src apps/api/src/migrations/Migration20260104000000.ts:' in out, 'emit: replayed object without its migration marker')
    # 4. entities
    ent = os.path.join(d, 'apps/api/src/orders/order.entity.ts'); os.makedirs(os.path.dirname(ent), exist_ok=True)
    open(ent, 'w').write("import { Entity, Property } from '@mikro-orm/core';\nconst ORDERS = 'orders';\n@Entity({ tableName: ORDERS })\nexport class OrderEntity {\n"
                         "  @PrimaryKey() id!: string;\n  @Property() tenantId!: string;\n  @Property() email!: string;\n  @Property() placedAt!: Date;\n"
                         "  @Property({ type: 'string' })\n  // prettier-ignore\n  status = 'new';\n}\n")
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf): entities(d, M2)
    eo = buf.getvalue()
    ok('MISSING-COLUMN\torders\tplaced_at' in eo, 'entities: missing column not reported')
    ok('NULLABLE\torders\temail' in eo, 'entities: nullability drift not reported')
    ok('GHOST-COLUMN\torders\ttotal' in eo and 'GHOST-TABLE\torder_items' in eo, 'entities: ghost rows missing')
    ok('GHOST-COLUMN\torders\tstatus' not in eo and 'MISSING-TABLE' not in eo, 'entities: a const tableName or a commented property misread:\n' + eo)
    # 5. laravel lane: Blueprint migrations in their own repo
    d2 = tempfile.mkdtemp(prefix='schema-map-lv-')
    for r, txt in LV.items():
        p = os.path.join(d2, r); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w').write(txt)
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf): L = run(d2, 'sql')
    lo = buf.getvalue()
    import shutil; shutil.rmtree(d2, ignore_errors=True)
    ok('lane=laravel (no .snapshot-*.json; Blueprint migrations found): 3 Blueprint' in lo, 'laravel: lane not chosen:\n' + lo[:400])
    ok(set(L) == {'users', 'orders'}, 'laravel: tables %r (a commented Schema::create, a dropIfExists or a down() leaked)' % sorted(L))
    U, O = L.get('users', {'cols': {}, 'idx': {}}), L.get('orders', {'cols': {}, 'idx': {}, 'fks': {}, 'chk': {}})
    ok(U['idx'].get('users_email_unique', {}).get('constraint') and U['idx'].get('users_pkey', {}).get('primary'), 'laravel: ->unique() / id() pk %r' % U['idx'])
    ok(U['cols'].get('deleted_at', {}).get('nullable') is True and U['cols'].get('email', {}).get('nullable') is False
       and U['cols'].get('name', {}).get('type') == 'varchar(120)', 'laravel: softDeletes / nullable / string(len) %r' % U['cols'])
    ok(O['fks'].get('orders_user_id_foreign', {}).get('ref') == 'users' and O['fks']['orders_user_id_foreign'].get('del') == 'cascade',
       'laravel: foreignId()->constrained()->cascadeOnDelete() %r' % O['fks'])
    ok(O['fks'].get('orders_tenant_id_foreign', {}).get('ref') == 'tenants', 'laravel: constrained(table)')
    ok(O['fks'].get('orders_coupon_id_foreign', {}).get('refcols') == ['code'] and O['fks']['orders_coupon_id_foreign']['del'] == 'set null'
       and O['cols'].get('coupon_id', {}).get('nullable') is True, 'laravel: constrained(table, column)->nullOnDelete() %r' % O['fks'].get('orders_coupon_id_foreign'))
    ok(O['fks'].get('orders_owner_fk', {}).get('del') == 'restrict' and O['fks']['orders_owner_fk']['ref'] == 'users', 'laravel: foreign()->references()->on()->onDelete()')
    ok(O['cols'].get('grand_total', {}).get('type') == 'numeric(12,2)' and O['cols']['grand_total']['default'] == '0' and 'total' not in O['cols'],
       'laravel: decimal(p,s) + renameColumn %r' % O['cols'].get('grand_total'))
    ok('tax' not in O['cols'], 'laravel: dropColumn')
    ok(O['chk'].get('orders_status_check', {}).get('expr') == '"status" in (\'new\', \'paid\')' and O['cols']['status']['default'] == "'new'",
       'laravel: enum -> CHECK %r' % O['chk'])
    ok(O['cols'].get('note', {}).get('type') == 'varchar(500)' and O['cols']['note']['nullable'] is False,
       'laravel: change() restates modifiers (nullable dropped) %r' % O['cols'].get('note'))
    ok(O['cols'].get('url', {}).get('default') == "'http://x.test/a;b)'", 'laravel: a ; ) or // inside a string split the statement %r' % O['cols'].get('url'))
    ok('orders_tenant_id_user_id_unique' not in O['idx'] and O['idx'].get('orders_status_ix', {}).get('cols') == ['status'], 'laravel: dropUnique / named index %r' % O['idx'])
    ok('orders_note_idx' in O['idx'], 'laravel: DB::statement DDL not applied')
    ok('alter table "orders" add constraint "orders_user_id_foreign" foreign key ("user_id") references "users" ("id") on delete cascade;' in lo
       and 'alter table "orders" add constraint "orders_status_check" check ("status" in (\'new\', \'paid\'));' in lo
       and '-- @src database/migrations/2024_01_02_000000_create_orders_table.php:6\n' in lo, 'laravel: DDL output or @src line\n' + lo[-900:])
    print('schema-map --self-test: %s (%d/%d checks)' % ('OK' if not fails else 'FAIL', n[0] - len(fails), n[0]))
    for f in fails: print('  FAIL ' + f)
    return 0 if not fails else 3


def main(argv):
    if '--self-test' in argv: return self_test()
    pos = [a for a in argv if not a.startswith('--')]
    opt = dict(a[2:].split('=', 1) if '=' in a else (a[2:], '1') for a in argv if a.startswith('--'))
    if len(pos) != 1 or not os.path.isdir(pos[0]) or opt.get('emit', 'sql') not in ('sql', 'summary'):
        sys.stderr.write(__doc__.split('\n\n')[-2] + '\n'); return 2
    if 'entities' in opt:
        M = run(pos[0], 'summary', opt.get('snapshot'))
        if M is None: print('# entities: no .snapshot-*.json — the static entity diff needs the MikroORM snapshot lane'); return 0
        entities(pos[0], M); return 0
    run(pos[0], opt.get('emit', 'sql'), opt.get('snapshot'), opt.get('lane'))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except BrokenPipeError:                      # `| head` closed the pipe: not an error
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno()); sys.exit(0)
