"""lanes_supabase.py — Supabase lanes for pair-inventory.py: the Postgres migrations replayed in order, what PostgREST
exposes, RLS, pg_cron and the Deno edge functions (the V1 side of a Supabase -> NestJS port).

Reads, under the Supabase folder (the one holding config.toml, migrations/ and functions/), statically:
  I-SCHEMA  migrations/*.sql replayed in filename order (comments, '' / E'' strings and $tag$ bodies masked):
            CREATE / ALTER / DROP TABLE; ADD / DROP / RENAME / ALTER COLUMN (TYPE, SET / DROP NOT NULL); column and
            table constraints (PRIMARY KEY, UNIQUE, FOREIGN KEY … ON DELETE, CHECK) under Postgres' default names;
            DROP / RENAME CONSTRAINT; CREATE / DROP UNIQUE INDEX (its WHERE kept); views; GENERATED columns and
            trigger-maintained columns (`NEW.c := …`, timestamp touches left out); DDL inside DO blocks, and an
            EXECUTE of a plain literal. Rows are the LAST state: col / unique / fk / view / derived.
  I-ENUM    CREATE TYPE … AS ENUM + ALTER TYPE ADD / RENAME VALUE, and the columns typed by it; single-column CHECKs
            that are a value list (IN (…), = ANY (ARRAY[…]), an OR of equalities); TS enums, string unions and
            z.enum consts in the functions.
  I-ROUTES  edge functions: POST /functions/v1/<name> (the invocation shape), the methods a function restricts
            itself to, sub-paths it branches on (`req.method === 'GET' && route === '/x'`) and body dispatch
            (`switch (action)`, `action === 'x'` -> `…?action=x`). PostgREST: POST /rest/v1/rpc/<fn> for every live
            public function an API role may EXECUTE (trigger functions left out); GET / POST / PATCH / DELETE
            /rest/v1/<table> for each command an API role reaches (RLS off, or a policy that grants it).
  I-AUTHZ   edge functions: auth.getUser / getClaims (in the file or one hop into a _shared helper) -> authn
            required; verify_jwt (config.toml, default true) is carried and never counted as authn, because the
            public anon key is a JWT that passes it; shared-secret, signature and API-key checks -> extra_guard;
            permission and role literals. RPC: EXECUTE grants (REVOKE / GRANT replayed), `auth.uid() IS NULL`
            guards, permission and role calls. Tables: RLS on / off, the permissive policies per command and role.
  I-SCOPE   table:<t> for every table: tenant = every SELECT policy an API role reaches carries an ownership,
            workspace or permission predicate; soft_delete = every one filters `deleted_at IS NULL`.
  I-RULES   (partial) RPC parameters (DEFAULT -> optional; the type) and the RAISE guards on them (IS NULL, < n,
            length, NOT IN); zod schemas a function parses; fields destructured from the request body and the 4xx
            guards on them; single-column CHECK constraints as `check:<table>.<column>` (the Nest lane reads no
            DDL CHECK: such a row is V1-ONLY until mapped); GLOBAL trim_strings / empty_to_null = no.
  I-ERR     PostgREST defaults (validation 400, not_found 404, forbidden 403, unauthenticated 401); RAISE with a
            machine-code message, status from its ERRCODE through PostgREST's SQLSTATE table (P0001 400,
            23503 / 23505 409, 42501 403, PTxyz xyz, other P0 500, the rest 400); edge-function error bodies
            `{ error | code: '<code>' }` with their status.
  I-SIDE    triggers (<table>.<event>) through their live function + one call hop: audit / activity / outbox /
            notification / queue inserts, net.http_* (webhook), pg_notify (event); RPC bodies; edge functions
            (mail, notify, webhook, audit, activity, job, event; storage rides along as also=storage).
  I-SCHED   pg_cron cron.schedule / unschedule replayed (the last definition of a name wins): canonical cron,
            tz = cron.timezone (pg_cron's default GMT, printed UTC), overlap yes (one instance of a job at a time).
  I-MONEY   (partial) round / trunc / floor / ceil / ::numeric(p,s) in money-named live SQL functions; Math.round /
            toFixed / decimal.js in functions; the outermost function only (modes flow up the call graph).
  I-CONF    (partial) timezone from ALTER DATABASE / ROLE SET timezone, else the AT TIME ZONE literals live
            functions use; per_page from config.toml [api] max_rows (a cap: a list with no limit returns up to it).
Shared readers come from lanes_common.py and the zod reader from lanes_node.py (both loaded by path, never through
sys.path: `python3 -I` safe). Cannot see: DDL built with EXECUTE format(…) (counted unparsed), SQL applied outside
migrations/ (noted), dashboard settings, privileges the platform grants outside the migrations (anon and
authenticated are assumed to hold EXECUTE and table privileges until a REVOKE says otherwise), routes a function
builds from URL parts it computes, effects more than one call away. What cannot be read is '?', never guessed.
"""
import importlib.util, os, re, sys

sys.dont_write_bytecode = True          # loading the helpers must not drop __pycache__ into a repo
HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(name + '_for_supabase', os.path.join(HERE, name + '.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


C = _load('lanes_common')
N = _load('lanes_node')
DEPENDS = ('lanes_node.py',)            # the core hashes it into this module's extractor hash

STACKS = ('supabase',)
PARTIAL = {('supabase', 'I-RULES'), ('supabase', 'I-MONEY'), ('supabase', 'I-CONF')}
GAPS = {}
ENUM_STRIP = ('enum', 'choices', 'type', 'schema')
SYS = {'auth', 'storage', 'realtime', '_realtime', 'supabase_functions', 'supabase_migrations', 'extensions', 'cron', 'net',
       'vault', 'graphql', 'graphql_public', 'pgsodium', 'pgsodium_masks', 'pg_catalog', 'information_schema', 'pgbouncer',
       'pgmq', '_analytics', 'pg_temp'}
API = {'public', 'anon', 'authenticated'}
CMDS = (('select', 'GET'), ('insert', 'POST'), ('update', 'PATCH'), ('delete', 'DELETE'))
LOW = dict((i, i + 32) for i in range(65, 91))      # ASCII-only lower: indices never move
IDENT = r'(?:"[^"]+"|[a-z_][\w$]*)'
QN = r'(?:%s(?:\s*\.\s*%s)?)' % (IDENT, IDENT)
SQLSTATE = {'raise_exception': 'P0001', 'no_data_found': 'P0002', 'too_many_rows': 'P0003', 'assert_failure': 'P0004',
            'check_violation': '23514', 'unique_violation': '23505', 'foreign_key_violation': '23503',
            'not_null_violation': '23502', 'restrict_violation': '23001', 'exclusion_violation': '23P01',
            'insufficient_privilege': '42501', 'invalid_parameter_value': '22023', 'data_exception': '22000',
            'invalid_text_representation': '22P02', 'numeric_value_out_of_range': '22003', 'division_by_zero': '22012',
            'string_data_right_truncation': '22001', 'invalid_datetime_format': '22007', 'null_value_not_allowed': '22004',
            'lock_not_available': '55P03', 'object_not_in_prerequisite_state': '55000', 'feature_not_supported': '0A000',
            'serialization_failure': '40001', 'deadlock_detected': '40P01', 'invalid_authorization_specification': '28000',
            'undefined_function': '42883', 'undefined_table': '42P01', 'query_canceled': '57014', 'internal_error': 'XX000',
            'duplicate_object': '42710', 'read_only_sql_transaction': '25006', 'program_limit_exceeded': '54000',
            'invalid_transaction_state': '25000', 'cardinality_violation': '21000', 'invalid_input_value': '22023'}
EVENT = {('after', 'insert'): 'created', ('after', 'update'): 'updated', ('after', 'delete'): 'deleted',
         ('instead', 'insert'): 'created', ('instead', 'update'): 'updated', ('instead', 'delete'): 'deleted',
         ('before', 'insert'): 'creating', ('before', 'update'): 'updating', ('before', 'delete'): 'deleting'}
TYPES = {'int': 'integer', 'int4': 'integer', 'int8': 'bigint', 'int2': 'smallint', 'bool': 'boolean', 'varchar': 'character varying',
         'timestamptz': 'timestamp with time zone', 'timestamp': 'timestamp without time zone', 'decimal': 'numeric',
         'float8': 'double precision', 'float4': 'real', 'char': 'character', 'timetz': 'time with time zone'}
WIRE = [(r'^(?:small|big)?int|^integer|serial$', 'int'), (r'^(?:numeric|decimal|real|double|money|float)', 'number'),
        (r'^bool', 'bool'), (r'^(?:timestamp|date|time)', 'date'), (r'\[\]$|^anyarray', 'array'), (r'^jsonb?$', '?'),
        (r'^(?:text|character|varchar|citext|uuid|inet|name|bpchar)', 'string')]
MONEY = re.compile(r'(?i)price|total|tax|vat|amount|invoice|order|payment|refund|fee|discount|balance|charge|cost|money|currenc|'
                   r'payout|settle|subtotal|commission|sale|pric|credit|wallet|install')
VERBS = ('get', 'calc', 'calculate', 'compute', 'recompute', 'recalc', 'recalculate', 'apply', 'update', 'set', 'create', 'process',
         'handle', 'do', 'make', 'build', 'fn', 'sp', 'tg', 'trg', 'trigger', 'on', 'before', 'after', 'refresh', 'sync', 'generate',
         'insert', 'upsert', 'add', 'admin', 'api', 'run', 'fetch', 'send', 'post', 'manage', 'action', 'v2', 'new', 'auto',
         'change', 'activate', 'deactivate', 'backfill', 'bulk', 'assign', 'check', 'convert', 'submit', 'reconcile', 'validate', 'mark')
TS_ROUND = N.ROUND
SCOPE_RX = re.compile(r'auth\.(?:uid|jwt|role|email)\s*\(|\bperm\w*\s*\(|has_role|is_?admin|workspace|tenant|\borg\w*_id\b|'
                      r'organi[sz]ation|\bstore_id\b|\baccount_id\b|\bteam\w*|company|merchant_id|member')
SOFT_RX = re.compile(r'\bdeleted_at\s+is\s+null|\barchived_at\s+is\s+null|\bis_deleted\s*=\s*false|\bnot\s+(?:\w+\.)?is_deleted\b|'
                     r'\bdeleted\s*=\s*false')
USER_RX = re.compile(r'auth\.(?:uid|jwt|role|email)\s*\(|\bauthenticated\b|\b\w*(?:perm|access|allow|abilit|authori)\w*\s*\(|has_role|is_?admin|current_user_id')


# ---------------------------------------------------------------- SQL scanner
TOK = re.compile(r"--|/\*|(?<![\w$])[eE]'|'|\"|\$(?:[A-Za-z_]\w*)?\$|;")
_STR = re.compile(r"''|'")
_ESTR = re.compile(r"\\.|''|'", re.S)


def scan(t):
    """(comment-free text, masked text, statements [(a, b)], dollar bodies [(a, b)], strings [(a, b)]).
    Comments are blanked in both; string and $tag$ bodies are blanked in the masked text only. Same indices."""
    n, cs, ms, stmts, dol, strs = len(t), [], [], [], [], []
    i = start = 0
    while True:
        x = TOK.search(t, i)
        if not x:
            cs.append(t[i:])
            ms.append(t[i:])
            break
        j, g = x.start(), x.group(0)
        cs.append(t[i:j])
        ms.append(t[i:j])
        if g == ';':
            cs.append(';')
            ms.append(';')
            stmts.append((start, j + 1))
            start = i = j + 1
            continue
        if g == '--' or g == '/*':
            e = t.find('\n', j) if g == '--' else t.find('*/', j + 2)
            e = n if e < 0 else (e if g == '--' else e + 2)
            cs.append(' ' * (e - j))
            ms.append(' ' * (e - j))
        elif g[-1] == "'":
            rx, k, e = (_ESTR if len(g) == 2 else _STR), x.end(), n
            for y in rx.finditer(t, k):
                if y.group(0) == "'":
                    e = y.end()
                    break
            cs.append(t[j:e])
            ms.append(g + ' ' * (e - j - len(g) - 1) + "'" if e - j > len(g) and t[e - 1] == "'" else g + ' ' * (e - j - len(g)))
            strs.append((j, e))
        elif g == '"':
            e = t.find('"', j + 1)
            e = n if e < 0 else e + 1
            cs.append(t[j:e])
            ms.append(t[j:e])
        else:
            e0 = t.find(g, x.end())
            if e0 < 0:
                e = e0 = n
                ms.append(g + ' ' * (n - x.end()))
            else:
                e = e0 + len(g)
                ms.append(g + ' ' * (e0 - x.end()) + g)
            cs.append(t[j:e])
            dol.append((x.end(), e0))
        i = e
    if t[start:].strip() and ''.join(ms)[start:].strip():
        stmts.append((start, n))
    return ''.join(cs), ''.join(ms), stmts, dol, strs


class Src(object):
    """One scanned text: a migration file, or a DO / EXECUTE body inside one (off = its start in the file)."""

    def __init__(self, rel, ft, t, off=0):
        self.rel, self.ft, self.t, self.off = rel, ft, t, off
        self.c, self.m, self.stmts, self.dol, self.strs = scan(t)
        self.ml = self.m.translate(LOW)

    def lit(self, s, e):
        q = self.t[s:e]
        if q[:1] in 'eE':
            return re.sub(r'\\(.)', r'\1', q[2:-1]).replace("''", "'")
        return q[1:-1].replace("''", "'")

    def lits(self, a, b):
        out = [self.lit(s, e) for s, e in self.strs if s >= a and e <= b]
        out += [self.t[s:e] for s, e in self.dol if s >= a and e <= b]
        return out

    def body(self, a, b):
        for s, e in self.dol:
            if a <= s < b:
                return s, e
        return None

    def at(self, i):
        return (self.rel, self.off + i)


PAIRS = {'(': ')', '[': ']', '{': '}'}


def _close(m, i):
    """Index of the bracket closing m[i] (masked text; (), [] and {} nest), or len(m) - 1 when unbalanced."""
    st = []
    for j in range(i, len(m)):
        ch = m[j]
        if ch in PAIRS:
            st.append(PAIRS[ch])
        elif ch in ')]}':
            if st and st[-1] == ch:
                st.pop()
                if not st:
                    return j
            elif st:
                st.pop()
    return len(m) - 1


def blank_lits(s):
    """SQL literals blanked in place (indices kept)."""
    return re.sub(r"'(?:[^']|'')*'", lambda x: "'" + ' ' * (len(x.group(0)) - 2) + "'", s or '')


def split_top(m, a, b):
    out, d, s = [], 0, a
    while s < b and m[s] in ' \t\r\n':
        s += 1
    for j in range(a, b):
        ch = m[j]
        if ch in '([':
            d += 1
        elif ch in ')]':
            d -= 1
        elif ch == ',' and d == 0:
            out.append((s, j))
            s = j + 1
            while s < b and m[s] in ' \t\r\n':   # a part starts at its first character, so its row cites its own line
                s += 1
    if m[s:b].strip():
        out.append((s, b))
    return out


def flat(s):
    """Blank everything inside parentheses (keeps the parens): keyword searches at depth 0 only."""
    out, d = [], 0
    for ch in s:
        if ch == '(':
            out.append(ch if d == 0 else ' ')
            d += 1
        elif ch == ')':
            d -= 1
            out.append(ch if d == 0 else ' ')
        else:
            out.append(ch if d == 0 else ' ')
    return ''.join(out)


def ident(s):
    s = (s or '').strip()
    return s[1:-1].lower() if s.startswith('"') else s.lower()


def qname(s):
    parts = [a or b for a, b in re.findall(r'"([^"]+)"|([A-Za-z_][\w$]*)', s or '')]
    parts = [p.lower() for p in parts]
    if len(parts) > 1 and parts[0] == 'public':
        parts = parts[1:]
    return '.'.join(parts)


def schema_of(name):
    return name.split('.')[0] if '.' in name else 'public'


def ntype(s):
    s = re.sub(r'\s+', ' ', re.sub(r'"', '', (s or '').strip().lower()))
    s = re.sub(r'^public\.', '', s)
    arr = s.endswith('[]')
    base = re.sub(r'\s*\[\]$', '', s)
    base = TYPES.get(base, base)
    return base + ('[]' if arr else '')


def sigtype(s):
    return re.sub(r'\s*\([^)]*\)', '', ntype(s))


def wire(typ, enums):
    t = ntype(typ)
    if sigtype(t).split('.')[-1] in enums:
        return 'string'
    for rx, w in WIRE:
        if re.search(rx, t):
            return w
    return '?'


def strip_lits(s):
    return re.sub(r"'(?:[^']|'')*'", "''", s or '')


# ---------------------------------------------------------------- the replay
class DB(object):
    def __init__(self):
        self.tables, self.indexes, self.types, self.funcs = {}, {}, {}, {}
        self.policies, self.triggers, self.views, self.cron = {}, {}, {}, {}
        self.tz, self.cron_tz, self.domains = [], None, 0
        self.default_exec = set(['public', 'anon', 'authenticated', 'service_role'])
        self.default_tbl = set(['anon', 'authenticated', 'service_role'])
        self.implicit, self.dyn, self.cron_in_fn, self.unknown_drop = set(), 0, 0, 0


def _table(db, name, S, i, implicit=False):
    if name not in db.tables:
        if implicit:
            db.implicit.add(name)
        db.tables[name] = {'cols': {}, 'cons': {}, 'rls': False, 'at': S.at(i), 'part': False,
                           'grants': dict((r, set(['select', 'insert', 'update', 'delete'])) for r in db.default_tbl),
                           'disabled': set()}
    return db.tables[name]


def defname(t, cols, suf):
    base = t.split('.')[-1]
    return ('%s_%s_%s' % (base, '_'.join(cols), suf))[:63] if cols else '%s_%s' % (base, suf)


def expr_cols(T, expr):
    seen = []
    for w in re.findall(r'"?([a-z_]\w*)"?', strip_lits(expr).translate(LOW)):
        if w in T['cols'] and w not in seen:
            seen.append(w)
    return seen


def colnames(S, a, e):
    out = []
    for pa, pb in split_top(S.ml, a + 1, e):
        seg = S.ml[pa:pb].strip()
        x = re.match(r'(%s)(?:\s+(?:asc|desc|nulls\s+\w+|[a-z_]+_ops|collate\s+\S+))*\s*$' % IDENT, seg)
        out.append(ident(x.group(1)) if x else '(' + ' '.join(S.c[pa:pb].lower().split()) + ')')
    return out


R_CON = re.compile(r'\s*(?:constraint\s+(%s)\s+)?(primary\s+key|unique|foreign\s+key|check|exclude)\b' % IDENT, re.S)


def con_elem(db, h, S, tname, pa, pb):
    x = R_CON.match(S.ml, pa, pb)
    if not x:
        return False
    T = db.tables[tname]
    kind, j, name = x.group(2).split()[0], x.end(), ident(x.group(1)) if x.group(1) else None
    if kind in ('primary', 'unique'):
        ui = re.match(r'\s*using\s+index\s+(%s)' % IDENT, S.ml[j:pb])
        if ui:
            ix = db.indexes.pop(ident(ui.group(1)), None)
            cols = ix['cols'] if ix else []
        else:
            p = S.ml.find('(', j, pb)
            if p < 0:
                h.unparse('I-SCHEMA', S.rel, S.ft, S.off + pa, 'constraint without a column list')
                return True
            cols = colnames(S, p, _close(S.ml, p))
        k = 'p' if kind == 'primary' else 'u'
        T['cons'][name or defname(tname, [] if k == 'p' else cols, 'pkey' if k == 'p' else 'key')] = {
            'k': k, 'cols': cols, 'at': S.at(pa), 'auto': not name}
    elif kind == 'foreign':
        p = S.ml.find('(', j, pb)
        e = _close(S.ml, p)
        cols = colnames(S, p, e)
        rm = re.match(r'\s*references\s+(%s)\s*(\([^)]*\))?' % QN, S.ml[e + 1:pb])
        if not rm:
            h.unparse('I-SCHEMA', S.rel, S.ft, S.off + pa, 'foreign key without references')
            return True
        rest = flat(S.ml[e + 1 + rm.end():pb])
        od = re.search(r'\bon\s+delete\s+(cascade|set\s+null|set\s+default|restrict|no\s+action)', rest)
        T['cons'][name or defname(tname, cols, 'fkey')] = {
            'k': 'f', 'cols': cols, 'ref': qname(rm.group(1)), 'ondelete': ' '.join(od.group(1).split()) if od else '',
            'at': S.at(pa), 'auto': not name}
    elif kind == 'check':
        p = S.ml.find('(', j, pb)
        e = _close(S.ml, p)
        expr = S.c[p + 1:e]
        cols = expr_cols(T, expr)
        T['cons'][name or defname(tname, cols, 'check')] = {'k': 'c', 'cols': cols, 'expr': expr, 'at': S.at(pa),
                                                            'auto': not name}
    return True


R_COL = re.compile(r'\s*(%s)\s+' % IDENT, re.S)
COLKW = re.compile(r'\b(not\s+null|null|default|primary\s+key|unique|references|check|constraint|generated|collate)\b')


def col_elem(db, h, S, tname, pa, pb, ifne=False):
    x = R_COL.match(S.ml, pa, pb)
    if not x:
        h.unparse('I-SCHEMA', S.rel, S.ft, S.off + pa, 'column definition')
        return
    T, name = db.tables[tname], ident(x.group(1))
    if ifne and name in T['cols']:
        return
    rm, rc = S.ml[x.end():pb], S.c[x.end():pb]
    fl = flat(rm)
    km = COLKW.search(fl)
    typ = ntype(rc[:km.start() if km else len(rc)])
    notnull = bool(re.search(r'\bnot\s+null\b|\bprimary\s+key\b|\bgenerated\s+(?:always|by\s+default)\s+as\s+identity', fl)) or \
        bool(re.search(r'serial$', typ))
    gen = bool(re.search(r'\bgenerated\s+always\s+as\s*\((?!.*identity)', fl)) and 'identity' not in fl
    T['cols'][name] = {'type': typ, 'notnull': notnull, 'gen': gen, 'at': S.at(pa)}
    cname = None
    for cm in re.finditer(r'\bconstraint\s+(%s)\s+(\w+)|\b(primary\s+key|unique|references|check)\b' % IDENT, fl):
        if cm.group(1):
            cname = ident(cm.group(1))
            kw = cm.group(2)
            pos = cm.start(2)
        else:
            kw, pos = cm.group(3).split()[0], cm.start(3)
        if kw == 'primary':
            T['cons'][cname or defname(tname, [], 'pkey')] = {'k': 'p', 'cols': [name], 'at': S.at(pa), 'auto': not cname}
        elif kw == 'unique':
            T['cons'][cname or defname(tname, [name], 'key')] = {'k': 'u', 'cols': [name], 'at': S.at(pa), 'auto': not cname}
        elif kw == 'references':
            r = re.match(r'references\s+(%s)' % QN, fl[pos:])
            od = re.search(r'\bon\s+delete\s+(cascade|set\s+null|set\s+default|restrict|no\s+action)', fl[pos:])
            if r:
                T['cons'][cname or defname(tname, [name], 'fkey')] = {
                    'k': 'f', 'cols': [name], 'ref': qname(r.group(1)), 'ondelete': ' '.join(od.group(1).split()) if od else '',
                    'at': S.at(pa), 'auto': not cname}
        elif kw == 'check':
            p = rm.find('(', pos)
            if p >= 0:
                e = _close(rm, p)
                T['cons'][cname or defname(tname, [name], 'check')] = {'k': 'c', 'cols': [name], 'expr': rc[p + 1:e],
                                                                       'at': S.at(pa), 'auto': not cname}
        if kw != 'constraint':
            cname = None


def drop_con(db, T, tname, name):
    if name in T['cons']:
        del T['cons'][name]
        return True
    suf = name.rsplit('_', 1)[-1]
    cands = [k for k, v in T['cons'].items() if v.get('auto') and k.endswith('_' + suf) and all(c in name for c in v['cols'])]
    if len(cands) == 1:
        del T['cons'][cands[0]]
        return True
    return False


def drop_col(db, tname, col):
    T = db.tables[tname]
    T['cols'].pop(col, None)
    for k in [k for k, v in T['cons'].items() if col in v['cols']]:
        del T['cons'][k]
    for k in [k for k, v in db.indexes.items() if v['table'] == tname and col in v['cols']]:
        del db.indexes[k]


def rename_table(db, old, new):
    db.tables[new] = db.tables.pop(old)
    for T in db.tables.values():
        for v in T['cons'].values():
            if v.get('ref') == old:
                v['ref'] = new
    for v in db.indexes.values():
        if v['table'] == old:
            v['table'] = new
    for d in (db.policies, db.triggers):
        for k in [k for k in d if k[0] == old]:
            d[(new, k[1])] = d.pop(k)


R_ALT = re.compile(r'alter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?(%s)\s*\*?\s*' % QN, re.S)
IGNORE_ACT = re.compile(r'owner\s+to|set\s+schema|set\s*\(|reset\s*\(|replica\s+identity|attach\s+partition|detach\s+partition|'
                        r'validate\s+constraint|cluster\s+on|set\s+without|set\s+(?:logged|unlogged)|inherit\b|no\s+inherit|'
                        r'alter\s+constraint|set\s+tablespace|(?:enable|disable)\s+rule|of\s|not\s+of|set\s+access')


def alter_table(db, h, S, a, b, x):
    tname = qname(x.group(1))
    if tname not in db.tables:
        if tname in db.views or schema_of(tname) in SYS:
            return
        _table(db, tname, S, a, implicit=True)
    T = db.tables[tname]
    end = b - 1 if S.ml[b - 1:b] == ';' else b
    for pa, pb in split_top(S.ml, x.end(), end):
        k = pa + len(S.ml[pa:pb]) - len(S.ml[pa:pb].lstrip())
        s = S.ml[k:pb]
        y = re.match(r'add\s+(?=constraint\s|primary\s+key|unique\b|foreign\s+key|check\b|exclude\b)', s)
        if y:
            con_elem(db, h, S, tname, k + y.end(), pb)
            continue
        y = re.match(r'add\s+(?:column\s+)?(if\s+not\s+exists\s+)?', s)
        if y:
            col_elem(db, h, S, tname, k + y.end(), pb, bool(y.group(1)))
            continue
        y = re.match(r'drop\s+constraint\s+(?:if\s+exists\s+)?(%s)' % IDENT, s)
        if y:
            if not drop_con(db, T, tname, ident(y.group(1))) and 'if exists' not in s[:30]:
                db.unknown_drop += 1
            continue
        y = re.match(r'drop\s+(?:column\s+)?(?:if\s+exists\s+)?(%s)' % IDENT, s)
        if y and not re.match(r'drop\s+(?:not\s+null|default|expression|identity)', s):
            drop_col(db, tname, ident(y.group(1)))
            continue
        y = re.match(r'alter\s+(?:column\s+)?(%s)\s+' % IDENT, s)
        if y:
            col, r = ident(y.group(1)), s[y.end():]
            cd = T['cols'].get(col)
            if cd is None:
                cd = T['cols'][col] = {'type': '?', 'notnull': False, 'gen': False, 'at': S.at(k)}
            if re.match(r'set\s+not\s+null', r):
                cd['notnull'] = True
            elif re.match(r'drop\s+not\s+null', r):
                cd['notnull'] = False
            elif re.match(r'(?:set\s+data\s+)?type\s+', r):
                tm = re.match(r'(?:set\s+data\s+)?type\s+', r)
                rest = S.c[k + y.end() + tm.end():pb]
                um = re.search(r'\busing\b|\bcollate\b', flat(rest.translate(LOW)))
                cd['type'] = ntype(rest[:um.start() if um else len(rest)])
            elif re.match(r'drop\s+expression', r):
                cd['gen'] = False
            elif re.match(r'add\s+generated', r):
                cd['notnull'] = True
            elif not re.match(r'(?:set|drop)\s+default|set\s+statistics|set\s+storage|set\s*\(|reset\s*\(|drop\s+identity|set\s+generated|set\s+compression|restart', r):
                h.unparse('I-SCHEMA', S.rel, S.ft, S.off + k, 'alter column action')
            continue
        y = re.match(r'rename\s+constraint\s+(%s)\s+to\s+(%s)' % (IDENT, IDENT), s)
        if y:
            v = T['cons'].pop(ident(y.group(1)), None)
            if v:
                v['auto'] = False
                T['cons'][ident(y.group(2))] = v
            continue
        y = re.match(r'rename\s+to\s+(%s)' % IDENT, s)
        if y:
            new = ident(y.group(1)) if schema_of(tname) == 'public' else '%s.%s' % (schema_of(tname), ident(y.group(1)))
            rename_table(db, tname, new)
            tname, T = new, db.tables[new]
            continue
        y = re.match(r'rename\s+(?:column\s+)?(%s)\s+to\s+(%s)' % (IDENT, IDENT), s)
        if y:
            o, n = ident(y.group(1)), ident(y.group(2))
            if o in T['cols']:
                T['cols'][n] = T['cols'].pop(o)
            for v in T['cons'].values():
                v['cols'] = [n if c == o else c for c in v['cols']]
                if v.get('expr'):
                    v['expr'] = re.sub(r'(?i)(?<![\w.])"?%s"?(?!\w)' % re.escape(o), n, v['expr'])
            for v in db.indexes.values():
                if v['table'] == tname:
                    v['cols'] = [n if c == o else c for c in v['cols']]
            continue
        y = re.match(r'(enable|disable|force|no\s+force)\s+row\s+level\s+security', s)
        if y:
            if y.group(1) in ('enable', 'disable'):
                T['rls'] = y.group(1) == 'enable'
            continue
        y = re.match(r'(enable|disable)\s+(?:always\s+|replica\s+)?trigger\s+(%s)' % IDENT, s)
        if y:
            tg = ident(y.group(2))
            if y.group(1) == 'disable':
                T['disabled'].add(tg)
            else:
                T['disabled'].discard(tg)
            continue
        if IGNORE_ACT.match(s) or not s.strip():
            continue
        h.unparse('I-SCHEMA', S.rel, S.ft, S.off + k, 'alter table action')


def parse_args(S, p, e):
    """[(name, type, has_default, mode)] of a function's argument list in S.ml[p] .. S.ml[e]."""
    out = []
    for pa, pb in split_top(S.ml, p + 1, e):
        seg, segc = S.ml[pa:pb], S.c[pa:pb]
        dm = re.search(r'\bdefault\b|=', flat(seg))
        has_def = bool(dm)
        if dm:
            seg, segc = seg[:dm.start()], segc[:dm.start()]
        toks = segc.split()
        mode = 'in'
        if toks and toks[0].lower() in ('in', 'out', 'inout', 'variadic'):
            mode = toks[0].lower()
            toks = toks[1:]
        if not toks:
            continue
        multi = len(toks) > 1 and toks[0].lower() in ('double', 'character', 'timestamp', 'time', 'bit', 'interval') and \
            toks[1].lower() in ('precision', 'varying', 'with', 'without', 'zone')
        if len(toks) == 1 or multi:
            out.append(('', ntype(' '.join(toks)), has_def, mode))
        else:
            out.append((ident(toks[0]), ntype(' '.join(toks[1:])), has_def, mode))
    return out


def sig_of(args):
    return tuple(sigtype(t) for n, t, d, mo in args if mo in ('in', 'inout', 'variadic'))


def sig_from(S, a, b):
    """Signature in a DROP / GRANT / ALTER list entry: `f(uuid, text)` or `f(p_id uuid)`; None without parens."""
    p = S.ml.find('(', a, b)
    if p < 0:
        return None
    return sig_of(parse_args(S, p, _close(S.ml, p)))


def funcs_named(db, name, sig):
    ks = [k for k in db.funcs if k[0] == name]
    if sig is None:
        return ks
    exact = [k for k in ks if k[1] == sig]
    return exact or [k for k in ks if len(k[1]) == len(sig)][:1]


R_FN = re.compile(r'create\s+(?:or\s+replace\s+)?(function|procedure)\s+(%s)\s*\(' % QN, re.S)


def create_function(db, h, S, a, b, x):
    name = qname(x.group(2))
    p = x.end() - 1
    e = _close(S.ml, p)
    args = parse_args(S, p, e)
    bd = S.body(e, b)
    if bd:
        body, ba = S.t[bd[0]:bd[1]], bd[0]
    else:
        am = re.search(r"\bas\s+'", S.ml[e:b])
        sp = [(s0, e0) for s0, e0 in S.strs if am and s0 == e + am.end() - 1]
        body, ba = (S.lit(*sp[0]), sp[0][0] + 1) if sp else ('', e)
    rest = S.ml[e:b]
    rm = re.search(r'\breturns\s+(setof\s+)?(%s)' % QN, rest)
    lang = re.search(r'\blanguage\s+[\'"]?(\w+)', rest)
    vol = re.search(r'\b(immutable|stable|volatile)\b', rest)
    key = (name, sig_of(args))
    old = db.funcs.get(key)
    db.funcs[key] = {
        'name': name, 'sig': key[1], 'args': args, 'returns': qname(rm.group(2)) if rm else ('void' if x.group(1) == 'procedure' else '?'),
        'lang': lang.group(1) if lang else '?',
        'secdef': bool(re.search(r'\bsecurity\s+definer\b', rest)),
        'vol': vol.group(1) if vol else 'volatile',
        'body': body, 'ba': ba, 'rel': S.rel, 'off': S.off, 'at': S.at(a), 'kind': x.group(1),
        'grants': set(old['grants']) if old else set(db.default_exec)}


def drop_functions(db, S, a, b, j):
    for pa, pb in split_top(S.ml, j, b - 1 if S.ml[b - 1:b] == ';' else b):
        seg = S.ml[pa:pb]
        nm = re.match(r'\s*(%s)' % QN, seg)
        if not nm:
            continue
        for k in funcs_named(db, qname(nm.group(1)), sig_from(S, pa, pb)):
            del db.funcs[k]


R_GRANT = re.compile(r'(grant|revoke)\s+(?:grant\s+option\s+for\s+)?(.+?)\s+on\s+(.+?)\s+(to|from)\s+(.+)$', re.S)


def grant(db, S, a, b, x):
    end = b - 1 if S.ml[b - 1:b] == ';' else b
    privs = set(p.strip().split()[0] for p in x.group(2).split(',') if p.strip())
    roles = set(ident(r.strip().split()[0]) for r in re.split(r',', re.sub(r'\b(?:with\s+grant\s+option|granted\s+by\s+\S+|cascade|restrict)\b', '', x.group(5))) if r.strip())
    roles = set('public' if r == 'public' else r for r in roles)
    on, on_a = x.group(3), x.start(3)
    add = x.group(1) == 'grant'

    def apply(s):
        s |= roles if add else set()
        if not add:
            s -= roles
    am = re.match(r'all\s+(functions|tables|routines|procedures)\s+in\s+schema\s+(%s)' % IDENT, on)
    if am:
        if am.group(1) == 'tables':
            for tn, T in db.tables.items():
                if schema_of(tn) == ident(am.group(2)):
                    for r in roles:
                        g = T['grants'].setdefault(r, set())
                        ps = set(['select', 'insert', 'update', 'delete']) if privs & {'all'} else privs
                        if add:
                            g |= ps
                        else:
                            g -= ps
        elif privs & {'execute', 'all'}:
            for k, f in db.funcs.items():
                if schema_of(k[0]) == ident(am.group(2)):
                    apply(f['grants'])
        return
    fm = re.match(r'(function|procedure|routine)s?\s+', on)
    if fm:
        if privs & {'execute', 'all'}:
            for pa, pb in split_top(S.ml, on_a + fm.end(), x.start(4)):
                nm = re.match(r'\s*(%s)' % QN, S.ml[pa:pb])
                if nm:
                    for k in funcs_named(db, qname(nm.group(1)), sig_from(S, pa, pb)):
                        apply(db.funcs[k]['grants'])
        return
    if re.match(r'(sequence|schema|database|type|domain|foreign|language|large|tablespace|all\s+sequences)\b', on):
        return
    tm = re.match(r'(?:table\s+)?(.+)$', on, re.S)
    ps = set(['select', 'insert', 'update', 'delete']) if privs & {'all'} else privs & {'select', 'insert', 'update', 'delete'}
    if not ps:
        return
    for nm in re.findall(QN, tm.group(1)):
        T = db.tables.get(qname(nm))
        if T is None:
            continue
        for r in roles:
            g = T['grants'].setdefault(r, set())
            if add:
                g |= ps
            else:
                g -= ps


R_POL = re.compile(r'create\s+policy\s+(%s)\s+on\s+(%s)' % (IDENT, QN), re.S)
R_POLCL = re.compile(r'\s*(?:(as)\s+(permissive|restrictive)|(for)\s+(all|select|insert|update|delete)|(to)\s+|(using)\s*\(|(with)\s+check\s*\()', re.S)


def policy_clauses(S, pos, b, P):
    while pos < b:
        y = R_POLCL.match(S.ml, pos, b)
        if not y:
            break
        if y.group(1):
            P['permissive'] = y.group(2) == 'permissive'
            pos = y.end()
        elif y.group(3):
            P['cmd'] = y.group(4)
            pos = y.end()
        elif y.group(5):
            z = re.search(r'\s(?:using|with\s+check)\b|;|$', S.ml[y.end():b])
            P['roles'] = set(ident(r) for r in S.ml[y.end():y.end() + z.start()].split(',') if r.strip())
            pos = y.end() + z.start()
        else:
            p = y.end() - 1
            e = _close(S.ml, p)
            P['using' if y.group(6) else 'check'] = S.c[p + 1:e]
            pos = e + 1


R_TRG = re.compile(r'create\s+(?:or\s+replace\s+)?(?:constraint\s+)?trigger\s+(%s)\s+(before|after|instead\s+of)\s+(.+?)\s+on\s+(%s)'
                   r'(.*?)\bexecute\s+(?:function|procedure)\s+(%s)\s*\(' % (IDENT, QN, QN), re.S)


def cron_call(db, h, S, a, b):
    for y in re.finditer(r'\bcron\s*\.\s*(schedule|unschedule|schedule_in_database|alter_job)\s*\(', S.ml[a:b]):
        p = a + y.end() - 1
        e = _close(S.ml, p)
        args, raws, named = [], [], {}
        for pa, pb in split_top(S.ml, p + 1, e):
            seg = S.ml[pa:pb]
            nm = re.match(r'\s*(\w+)\s*(?::=|=>)\s*', seg)
            s0 = pa + (nm.end() if nm else 0)
            lit = [S.lit(s, t) for s, t in S.strs if s0 <= s < pb] + [S.t[s:t] for s, t in S.dol if s0 <= s < pb]
            plain = re.match(r"\s*(?:e?'|\$)", S.ml[s0:pb])
            args.append(lit[0] if (lit and plain) else None)
            raws.append(S.t[s0:pb])
            if nm:
                named[nm.group(1)] = (args[-1], S.t[s0:pb])
        fn = y.group(1)
        if fn == 'alter_job':   # `cron.alter_job((select jobid … where jobname = 'x'), schedule := '…', active := false)`
            jm = re.search(r"jobname\s*=\s*'([^']+)'", S.c[p:e].translate(LOW))
            name = jm.group(1) if jm else None
            if name is None:
                h.unparse('I-SCHED', S.rel, S.ft, S.off + a + y.start(), 'cron.alter_job of a computed job')
                continue
            J = db.cron.setdefault(name, {'sched': '?', 'cmd': '?', 'at': S.at(a + y.start()), 'named': True,
                                          'note': 'altered, never scheduled by a migration (created outside them)'})
            if named.get('schedule', (None,))[0]:
                J['sched'] = named['schedule'][0]
            if 'command' in named:
                J['cmd'] = named['command'][0] or named['command'][1]
            if re.match(r'\s*false\b', named.get('active', (None, ''))[1] or '', re.I):
                db.cron.pop(name, None)
            continue
        if fn == 'unschedule':
            name = args[0] if args else None
            names = [name] if name is not None else []
            if name is None:
                jm = re.search(r"jobname\s*(?:=\s*'([^']+)'|in\s*\(([^)]*)\))", S.c[a:b].translate(LOW))
                names = ([jm.group(1)] if jm.group(1) else re.findall(r"'([^']+)'", jm.group(2))) if jm else []
            for name in names:
                db.cron.pop(name, None)
            if not names:
                h.unparse('I-SCHED', S.rel, S.ft, S.off + a + y.start(), 'cron.unschedule of a computed job')
        elif fn in ('schedule', 'schedule_in_database'):
            if len(args) == 2:
                args, raws = [None] + args, [''] + raws
            if len(args) >= 3 and args[1] is not None and args[2] is None and args[0] is not None:
                args[2] = raws[2]   # `format($q$…$q$, v_url)`: the job and its schedule are literal; the command is read as text
            if len(args) < 3 or args[1] is None or args[2] is None:
                h.unparse('I-SCHED', S.rel, S.ft, S.off + a + y.start(), 'cron.schedule with a computed argument')
                continue
            name = args[0] or ('cmd:' + ' '.join(args[2].split())[:60])
            db.cron[name] = {'sched': args[1], 'cmd': args[2], 'at': S.at(a + y.start()), 'named': args[0] is not None}


DDL_HEAD = re.compile(r'\s*((?:create|alter|drop|grant|revoke)\b|(?:perform|select)\s+cron\s*\.|execute\b)')
DDL_IN_DO = re.compile(r'(?:^|\b(?:then|else|loop|begin|declare|do)\b|;)\s*((?:create|alter|drop|grant|revoke)\b|(?:perform|select)\s+cron\s*\.|execute\b)', re.S)


def do_block(db, h, S, a, b, depth):
    bd = S.body(a, b)
    if not bd or depth > 3:
        return
    sub = Src(S.rel, S.ft, S.t[bd[0]:bd[1]], S.off + bd[0])
    for sa, sb in sub.stmts:
        y0 = DDL_HEAD.match(sub.ml, sa, sb)
        for y in ([y0] if y0 else DDL_IN_DO.finditer(sub.ml, sa, sb)):
            k = y.start(1)
            if sub.ml.startswith('execute', k):
                q = re.match(r"execute\s+(e?')", sub.ml[k:sb])
                sp = [(s0, e0) for s0, e0 in sub.strs if q and s0 == k + q.start(1)]
                if sp and sub.ml[sp[0][1]:sb].strip(' ;\n\t') == '':
                    lit = sub.lit(*sp[0])
                    inner = Src(S.rel, S.ft, lit, sub.off + sp[0][0] + 1)
                    for ia, ib in inner.stmts:
                        stmt(db, h, inner, ia, ib, depth + 1)
                elif re.search(r'\b(?:alter|create|drop)\s+(?:table|index|policy|trigger|type|function)', sub.c[k:sb].translate(LOW)):
                    db.dyn += 1
                    h.unparse('I-SCHEMA', S.rel, S.ft, sub.off + k, 'dynamic DDL (EXECUTE of a computed string)')
            else:
                stmt(db, h, sub, k, sb, depth + 1)
            break


def stmt(db, h, S, a, b, depth=0):
    ml = S.ml
    k = a + len(ml[a:b]) - len(ml[a:b].lstrip())
    w = ml[k:k + 12]
    if w.startswith('create'):
        x = re.compile(r'create\s+(?:(?:global|local)\s+)?(?:temp(?:orary)?\s+|unlogged\s+)?table\s+(?:if\s+not\s+exists\s+)?(%s)\s*' % QN, re.S).match(ml, k, b)
        if x:
            tname = qname(x.group(1))
            if re.match(r'partition\s+of\b', ml[x.end():b]):
                _table(db, tname, S, k)['part'] = True
                return
            if not ml.startswith('(', x.end()):
                return              # CREATE TABLE … AS / OF type: no column list to read
            if 'if not exists' in ml[k:x.start(1)] and tname in db.tables and tname not in db.implicit:
                return
            db.tables.pop(tname, None)
            db.implicit.discard(tname)
            _table(db, tname, S, k)
            e = _close(ml, x.end())
            for pa, pb in split_top(ml, x.end() + 1, e):
                if re.match(r'\s*like\s', ml[pa:pb]):
                    lm = re.match(r'\s*like\s+(%s)' % QN, ml[pa:pb])
                    src = db.tables.get(qname(lm.group(1))) if lm else None
                    if src:
                        for cn, cd in src['cols'].items():
                            db.tables[tname]['cols'][cn] = dict(cd)
                    continue
                if not con_elem(db, h, S, tname, pa, pb):
                    col_elem(db, h, S, tname, pa, pb)
            return
        x = R_FN.match(ml, k, b)
        if x:
            create_function(db, h, S, a, b, x)
            return
        x = R_POL.match(ml, k, b)
        if x:
            tname = qname(x.group(2))
            P = {'name': ident(x.group(1)), 'permissive': True, 'cmd': 'all', 'roles': set(['public']), 'using': None,
                 'check': None, 'at': S.at(k)}
            policy_clauses(S, x.end(), b, P)
            db.policies[(tname, P['name'])] = P
            return
        x = R_TRG.match(ml, k, b)
        if x:
            evs = [e.split()[0] for e in re.split(r'\bor\b', x.group(3)) if e.strip()]
            db.triggers[(qname(x.group(4)), ident(x.group(1)))] = {
                'timing': x.group(2).split()[0], 'events': evs, 'func': qname(x.group(6)), 'at': S.at(k),
                'row': bool(re.search(r'for\s+each\s+row', x.group(5)))}
            return
        x = re.compile(r'create\s+(unique\s+)?index\s+(?:concurrently\s+)?(if\s+not\s+exists\s+)?(?:(%s)\s+)?on\s+(?:only\s+)?(%s)\s*(?:using\s+\w+\s*)?\(' % (IDENT, QN), re.S).match(ml, k, b)
        if x:
            iname = ident(x.group(3)) if x.group(3) else 'anon:%s:%d' % (S.rel, S.off + k)
            if x.group(2) and iname in db.indexes:
                return
            p = x.end() - 1
            e = _close(ml, p)
            wm = re.search(r'\bwhere\b', ml[e:b])
            db.indexes[iname] = {'table': qname(x.group(4)), 'cols': colnames(S, p, e), 'unique': bool(x.group(1)),
                                 'where': ' '.join(S.c[e + wm.end():b].strip(' ;\n').split()) if wm else '', 'at': S.at(k)}
            return
        x = re.compile(r'create\s+type\s+(%s)\s+as\s+enum\s*\(' % QN, re.S).match(ml, k, b)
        if x:
            p = x.end() - 1
            db.types[qname(x.group(1))] = {'values': S.lits(p, _close(ml, p)), 'at': S.at(k)}
            return
        x = re.compile(r'create\s+(?:or\s+replace\s+)?(?:temp(?:orary)?\s+)?(?:recursive\s+)?(materialized\s+)?view\s+(?:if\s+not\s+exists\s+)?(%s)' % QN, re.S).match(ml, k, b)
        if x:
            db.views[qname(x.group(2))] = S.at(k)
            return
        if re.match(r'create\s+domain\b', ml[k:b]):
            db.domains += 1
        return
    if w.startswith('alter'):
        x = R_ALT.match(ml, k, b)
        if x:
            alter_table(db, h, S, k, b, x)
            return
        x = re.compile(r'alter\s+type\s+(%s)\s+(add\s+value|rename\s+value|rename\s+to)\b' % QN, re.S).match(ml, k, b)
        if x:
            T = db.types.get(qname(x.group(1)))
            lt = S.lits(x.end(), b)
            if T is None:
                return
            if x.group(2).startswith('add') and lt:
                if lt[0] not in T['values']:
                    T['values'].append(lt[0])
            elif x.group(2) == 'rename value' and len(lt) >= 2:
                T['values'] = [lt[1] if v == lt[0] else v for v in T['values']]
            elif x.group(2) == 'rename to':
                nm = re.match(r'\s*(%s)' % IDENT, ml[x.end():b])
                db.types[ident(nm.group(1))] = db.types.pop(qname(x.group(1)))
            return
        x = re.compile(r'alter\s+(?:function|procedure|routine)\s+(%s)' % QN, re.S).match(ml, k, b)
        if x:
            j = x.end()
            sig = None
            if ml[j:j + 40].lstrip().startswith('('):
                p = ml.find('(', j)
                e = _close(ml, p)
                sig, j = sig_of(parse_args(S, p, e)), e + 1
            rest = ml[j:b]
            for key in funcs_named(db, qname(x.group(1)), sig):
                f = db.funcs[key]
                sm = re.search(r'\bsecurity\s+(definer|invoker)\b', rest)
                if sm:
                    f['secdef'] = sm.group(1) == 'definer'
                rn = re.search(r'\brename\s+to\s+(%s)' % IDENT, rest)
                if rn:
                    db.funcs[(ident(rn.group(1)), key[1])] = dict(db.funcs.pop(key), name=ident(rn.group(1)))
            return
        x = re.compile(r'alter\s+policy\s+(%s)\s+on\s+(%s)\s*' % (IDENT, QN), re.S).match(ml, k, b)
        if x:
            key = (qname(x.group(2)), ident(x.group(1)))
            P = db.policies.get(key)
            if P is None:
                return
            rn = re.match(r'rename\s+to\s+(%s)' % IDENT, ml[x.end():b])
            if rn:
                db.policies[(key[0], ident(rn.group(1)))] = dict(db.policies.pop(key), name=ident(rn.group(1)))
            else:
                policy_clauses(S, x.end(), b, P)
            return
        x = re.compile(r'alter\s+index\s+(?:if\s+exists\s+)?(%s)\s+rename\s+to\s+(%s)' % (QN, IDENT), re.S).match(ml, k, b)
        if x:
            old = qname(x.group(1)).split('.')[-1]
            if old in db.indexes:
                db.indexes[ident(x.group(2))] = db.indexes.pop(old)
            return
        x = re.compile(r'alter\s+(?:materialized\s+)?view\s+(?:if\s+exists\s+)?(%s)\s+rename\s+to\s+(%s)' % (QN, IDENT), re.S).match(ml, k, b)
        if x:
            old = qname(x.group(1))
            if old in db.views:
                db.views[ident(x.group(2))] = db.views.pop(old)
            return
        x = re.compile(r"alter\s+(database|role|user|system)\s+(?:\S+\s+)?(?:in\s+database\s+\S+\s+)?set\s+(\"?timezone\"?|time\s+zone|cron\s*\.\s*timezone)\s*(?:to|=)?\s*", re.S).match(ml, k, b)
        if x:
            lt = S.lits(x.end(), b)
            if lt:
                if 'cron' in x.group(2):
                    db.cron_tz = lt[0]
                elif x.group(1) in ('database', 'system'):
                    db.tz.append((lt[0], S.at(k)))
            return
        x = re.compile(r'alter\s+default\s+privileges\b.*?\b(grant|revoke)\s+(.+?)\s+on\s+(functions|routines|tables)\s+(to|from)\s+(.+)$', re.S).match(ml, k, b - 1 if ml[b - 1:b] == ';' else b)
        if x:
            roles = set(ident(r.strip().split()[0]) for r in x.group(5).split(',') if r.strip())
            tgt = db.default_exec if x.group(3) != 'tables' else db.default_tbl
            if x.group(1) == 'grant':
                tgt |= roles
            else:
                tgt -= roles
        return
    if w.startswith('drop'):
        y = re.match(r'drop\s+(table|index|type|view|materialized\s+view|function|procedure|routine|policy|trigger)\s+'
                     r'(?:concurrently\s+)?(?:if\s+exists\s+)?', ml[k:b])
        if not y:
            return
        kind, j = y.group(1), k + y.end()
        end = b - 1 if ml[b - 1:b] == ';' else b
        if kind in ('function', 'procedure', 'routine'):
            drop_functions(db, S, k, b, j)
            return
        if kind in ('policy', 'trigger'):
            z = re.match(r'(%s)\s+on\s+(%s)' % (IDENT, QN), ml[j:end])
            if z:
                (db.policies if kind == 'policy' else db.triggers).pop((qname(z.group(2)), ident(z.group(1))), None)
            return
        names = [qname(n) for n in re.findall(QN, re.sub(r'\b(?:cascade|restrict)\b', '', ml[j:end]))]
        for nm in names:
            if kind == 'table':
                if nm in db.tables:
                    del db.tables[nm]
                    for d in (db.policies, db.triggers):
                        for kk in [kk for kk in d if kk[0] == nm]:
                            del d[kk]
                    for kk in [kk for kk, v in db.indexes.items() if v['table'] == nm]:
                        del db.indexes[kk]
                    for T in db.tables.values():
                        for kk in [kk for kk, v in T['cons'].items() if v.get('ref') == nm]:
                            del T['cons'][kk]
            elif kind == 'index':
                db.indexes.pop(nm.split('.')[-1], None)
            elif kind == 'type':
                db.types.pop(nm, None)
            else:
                db.views.pop(nm, None)
        return
    if w.startswith('grant') or w.startswith('revoke'):
        x = R_GRANT.match(ml, k, b - 1 if ml[b - 1:b] == ';' else b)
        if x:
            grant(db, S, k, b, x)
        return
    if re.match(r'do\b', w):
        do_block(db, h, S, k, b, depth)
        return
    if re.match(r'(select|perform)\b', w) and 'cron' in ml[k:b]:
        cron_call(db, h, S, k, b)


def base_dir(h, ctx):
    if 'base' not in ctx:
        ctx['base'] = _base(h)
    return ctx['base']


def _base(h):
    hits = h.files(['**/supabase/config.toml', 'config.toml', '**/supabase/migrations/*.sql', '**/supabase/functions/*/index.ts',
                    'migrations/*.sql', 'functions/*/index.ts'])
    cands = set()
    for rel in hits:
        parts = rel.split('/')
        if 'supabase' in parts:
            cands.add('/'.join(parts[:len(parts) - 1 - parts[::-1].index('supabase')] + ['supabase']))
        elif rel == 'config.toml' and re.search(r'(?m)^\s*(?:project_id\s*=|\[functions\.|\[api\]|\[db\])', h.read(rel)):
            cands.add('')
    return min(cands, key=lambda d: (d.count('/'), d)) if cands else None


def _pre(base):
    return (base + '/') if base else ''


def replay(h, ctx):
    if 'db' in ctx:
        return ctx['db']
    base = base_dir(h, ctx)
    db = DB()
    files = sorted(h.files([_pre(base) + 'migrations/*.sql']), key=lambda r: os.path.basename(r))
    for rel in files:
        t = h.read(rel)
        S = Src(rel, t, t)
        for a, b in S.stmts:
            stmt(db, h, S, a, b)
    db.files = files
    other = [r for r in h.files([_pre(base) + '**/*.sql']) if r not in set(files) and not r.endswith('seed.sql')]
    if other:
        ctx.setdefault('notes', []).append('supabase: %d .sql file(s) outside migrations/ not replayed (applied by hand?): %s'
                                           % (len(other), ', '.join(other[:3])))
    if db.implicit:
        ctx.setdefault('notes', []).append('supabase: %d table(s) altered but never created by a migration (columns partial): %s'
                                           % (len(db.implicit), ', '.join(sorted(db.implicit)[:5])))
    if db.unknown_drop:
        ctx.setdefault('notes', []).append('supabase: %d DROP CONSTRAINT of a name the replay never saw (default-name drift)' % db.unknown_drop)
    ctx['db'] = db
    return db


# ---------------------------------------------------------------- SQL readers on live objects
def fsrc(f):
    if 'S' not in f:
        f['S'] = Src(f['rel'], '', f['body'], f['off'] + f['ba'])
        f['bl'] = f['S'].c.translate(LOW)
    return f['S']


def deny(P, cmd='select'):
    """A policy whose expression is literally false grants nothing (`USING (false)`, the 'block anon' idiom)."""
    e = (P['check'] if cmd == 'insert' and P['check'] is not None else P['using']) or ''
    return bool(re.match(r'^\s*\(*\s*false\s*\)*\s*$', e.translate(LOW)))


def live_tables(db):
    return [(n, T) for n, T in db.tables.items() if schema_of(n) not in SYS and not T['part']]


def fn_index(db):
    out = {}
    for k, f in db.funcs.items():
        out.setdefault(f['name'].split('.')[-1], []).append(f)
    return out


def needs_user(expr, fidx, hop=True):
    e = (expr or '').translate(LOW)
    if USER_RX.search(e):
        return True
    if hop:
        for nm in set(re.findall(r'\b([a-z_]\w*)\s*\(', strip_lits(e))):
            for f in fidx.get(nm, ()):
                fsrc(f)
                if needs_user(f['bl'], fidx, False):
                    return True
    return False


def perm_lits(text):
    """Permission keys: string literals inside a call whose name holds perm / access / allow / abilit / authori
    (has_workspace_permission(ws, 'can_x'), chat_user_has_access(uid, 'can_x'), ARRAY['a','b'] arguments)."""
    out, t = set(), text or ''
    tl = blank_lits(t).translate(LOW)
    for y in re.finditer(r'\b\w*(?:perm|access|allow|abilit|authori)\w*\s*\(', tl):
        p = y.end() - 1
        e = _close(tl, p)
        for v in re.findall(r"'((?:[^']|'')*)'", t[p:e]):
            if re.match(r'^[a-z][a-z0-9_.:\-]*$', v):
                out.add(v)
    return out


def role_lits(text):
    t = (text or '').translate(LOW)
    out = set(re.findall(r"has_role\s*\([^;]*?'([a-z_]\w*)'", t))
    out |= set(re.findall(r"(?:->>|->)\s*'(?:role|user_role|app_role)'\)?\s*(?:=|in\s*\()\s*'(\w+)'", t))
    if re.search(r'\bis_super_?admin\s*\(', t):
        out.add('super_admin')
    if re.search(r'\bis_?admin\s*\(', t):
        out.add('admin')
    return out


def guard_rules(f):
    """{arg: {attr: value}} from `IF <cond> THEN RAISE` guards on a function's parameters."""
    S = fsrc(f)
    out = {}
    names = dict((n, t) for n, t, d, mo in f['args'] if n)
    for y in re.finditer(r'\bif\s+(.+?)\s+then\s+raise\b', S.ml.translate(LOW), re.S):
        cond = S.c.translate(LOW)[y.start(1):y.end(1)]
        for n, t in names.items():
            r = out.setdefault(n, {})
            v = re.escape(n)
            isint = wire(t, ()) == 'int'
            if re.search(r'\b%s\s+is\s+null\b' % v, cond):
                r['nullable'] = 'no'
            for op, num in re.findall(r'\b%s\s*(<=|<|>=|>)\s*(-?\d+(?:\.\d+)?)\b' % v, cond):
                x = float(num)
                if op in ('<', '<='):
                    r['min'] = ('%d' % (x + 1) if op == '<=' else '%d' % x) if isint else (('>' + num) if op == '<=' else num)
                else:
                    r['max'] = ('%d' % (x - 1) if op == '>=' else '%d' % x) if isint else (('<' + num) if op == '>=' else num)
            lm = re.search(r'\b(?:char_)?length\s*\(\s*(?:b?trim\s*\(\s*)?%s\s*\)?\s*\)\s*(>|<|=)\s*(\d+)' % v, cond)
            if lm:
                if lm.group(1) == '>':
                    r['max'] = lm.group(2)
                elif lm.group(1) == '<':
                    r['min'] = lm.group(2)
                elif lm.group(2) == '0':
                    r['min'] = '1'
            nm = re.search(r"\b%s\s+not\s+in\s*\(([^)]*)\)" % v, cond)
            if nm:
                r['in'] = ','.join(sorted(set(re.findall(r"'((?:[^']|'')*)'", nm.group(1)))))
    return dict((k, v) for k, v in out.items() if v)


def sql_kinds(bl, fidx, hop=1, seen=None):
    ks = set()
    for tgt in re.findall(r'\binsert\s+into\s+(%s)' % QN, strip_lits(bl)):
        n = qname(tgt).split('.')[-1]
        k = ('audit' if 'audit' in n else 'notify' if 'notif' in n else 'event' if re.search(r'outbox|_events?$|^events?_', n)
             else 'job' if re.search(r'queue|^jobs?$|_jobs?$', n) else 'mail' if re.search(r'mail', n)
             else 'activity' if re.search(r'activit|histor|trail|(?:status|change|field|diff)_?logs?$', n) else None)
        if k:
            ks.add(k)
    if re.search(r'\bnet\s*\.\s*http_(?:post|get|request|delete)\s*\(|\bhttp_post\s*\(|\bextensions\s*\.\s*http\s*\(', bl):
        ks.add('webhook')
    if re.search(r'\bpg_notify\s*\(|\brealtime\s*\.\s*(?:send|broadcast)', bl):
        ks.add('event')
    if re.search(r'\bpgmq\s*\.\s*send', bl):
        ks.add('job')
    if hop:
        seen = seen or set()
        for nm in set(re.findall(r'\b(?:perform|select|:=|=)\s*(?:public\s*\.\s*)?([a-z_]\w*)\s*\(', strip_lits(bl))):
            for f in fidx.get(nm, ()):
                if id(f) in seen:
                    continue
                seen.add(id(f))
                fsrc(f)
                ks |= sql_kinds(f['bl'], fidx, hop - 1, seen)
    return ks


def sql_err(h, db, rows):
    free = 0
    for f in db.funcs.values():
        S = fsrc(f)
        ml = S.ml.translate(LOW)
        for y in re.finditer(r'\braise\s+(exception\b|sqlstate\s+|(?!notice|warning|info|log|debug)([a-z_]\w*)\b)?', ml):
            j = y.end()
            semi = ml.find(';', j)
            semi = len(ml) if semi < 0 else semi
            seg_m, seg_c = ml[j:semi], S.c[j:semi]
            code = None
            if y.group(1) and y.group(1).startswith('sqlstate'):
                lt = S.lits(j, semi)
                code = lt[0].upper() if lt else None
                msg = lt[1] if len(lt) > 1 else ''
            else:
                if y.group(2):
                    code = SQLSTATE.get(y.group(2))
                lt = [(s, e) for s, e in S.strs if j <= s < semi]
                msg = S.lit(*lt[0]) if lt and S.ml[j:lt[0][0]].strip() == '' else ''
            um = re.search(r'\busing\b', seg_m)
            if um:
                for om in re.finditer(r'\b(errcode|message)\s*=\s*', seg_m[um.end():]):
                    p = j + um.end() + om.end()
                    lt = [(s, e) for s, e in S.strs if s == p or (s > p and S.ml[p:s].strip() == '')]
                    val = S.lit(*lt[0]) if lt else re.match(r'[a-z_]\w*', ml[p:p + 40]).group(0) if re.match(r'[a-z_]\w*', ml[p:p + 40]) else ''
                    if om.group(1) == 'errcode':
                        code = SQLSTATE.get(val.lower(), val.upper()) if val else code
                    elif not msg:
                        msg = val
            ck = None
            cm = re.match(r'^([A-Za-z][A-Za-z0-9]*(?:[_.\-][A-Za-z0-9]+)+)(?=$|\s*:)', msg.strip())
            if cm and (cm.group(1).islower() or cm.group(1).isupper()):
                ck = cm.group(1)
            if not ck:
                free += 1
                continue
            st = pgrst_status(code)
            rows.setdefault('code:' + ck, [set(), f['rel'], f['off'] + f['ba'] + y.start(), 'raise in %s' % f['name']])[0].add(st)
    if free:
        h.notes.append('supabase I-ERR: %d RAISE site(s) with a free-text message (status by ERRCODE, not keyed)' % free)


def pgrst_status(code):
    c = (code or 'P0001').upper()
    if re.match(r'^PT\d{3}$', c):
        return c[2:]
    if c in ('23503', '23505'):
        return '409'
    if c == '42501':
        return '403'
    if c in ('42883', '42P01'):
        return '404'
    if c == 'P0001':
        return '400'
    if c == '25006':
        return '405'
    if c[:2] in ('08', '53'):
        return '503'
    if c[:2] == '54':
        return '413'
    if c[:2] in ('0L', '0P', '28'):
        return '403'
    if c[:2] in ('09', '25', '2D', '38', '39', '3B', '40', '55', '57', '58', 'F0', 'HV', 'P0', 'XX'):
        return '500'
    return '400'


# ---------------------------------------------------------------- edge functions
class F(object):
    def __init__(self, h, rel):
        self.rel, self.t = rel, h.read(rel)
        self.m, self.sp = h.masked(rel, 'c')

    def lits(self, a, b):
        return [self.t[s + 1:e - 1] for s, e in self.sp if s >= a and e <= b]


AUTH_RX = re.compile(r'\bauth\s*\.\s*getUser\s*\(|\bgetClaims\s*\(|\bauth\s*\.\s*getSession\s*\(|\bjwtVerify\s*\(|\bverifyJWT\s*\(')
SECRET_RX = re.compile(r'timingSafeEqual|createHmac|\bhmac\b|crypto\.subtle\.(?:verify|importKey)|'
                       r'[!=]==?\s*Deno\.env\.get\(\s*[\'"]\w*(?:SECRET|TOKEN|KEY|PASSWORD)\w*[\'"]|'
                       r'\b\w*(?:[sS]ecret|SECRET|serviceKey|ServiceKey|apiKey|ApiKey|API_KEY)\w*\s*[!=]==?\s*\w|'
                       r'[!=]==?\s*\w*(?:[sS]ecret|SECRET|serviceKey|ServiceKey|API_KEY)\w*\b|'
                       r'[!=]==?\s*[A-Z][A-Z0-9_]*(?:KEY|SECRET|TOKEN|PASSWORD)\b|\b[A-Z][A-Z0-9_]*(?:KEY|SECRET|TOKEN|PASSWORD)\s*[!=]==?|'
                       r'\bheaders\.get\(\s*[\'"]x-[\w-]+[\'"]\s*\)\s*(?:\|\|\s*[\'"]{2}\s*\)?\s*)?[!=]==?|'
                       r'\bverify\w*(?:Signature|Webhook|Hmac)\w*\s*\(|\bauthenticateApiRequest\s*\(|\bisWorkerAuthorized\s*\(')
EF_KINDS = [('mail', r'(?i)api\.resend\.com|sendgrid|postmark|mailgun|\bsmtp|\b\w*(?:mail|email)\w*\.send\w*\(|\bsend\w*E?mail\w*\('),
            ('notify', r'(?i)graph\.facebook\.com[^\'"`]*/messages|\bsend\w*(?:whatsapp|sms|push|notification)\w*\(|'
                       r'\.from\(\s*[\'"]\w*notification\w*[\'"]\s*\)\s*\.(?:insert|upsert)\('),
            ('webhook', r'(?i)\b\w*webhook\w*\.(?:send|post|dispatch|deliver)\w*\(|\bfetch\(\s*\w*webhook\w*'),
            ('audit', r'(?i)\.from\(\s*[\'"]\w*audit\w*[\'"]\s*\)\s*\.(?:insert|upsert)\(|\baudit\w*\.(?:log|record|create|write)\w*\(|\blogAudit\w*\('),
            ('activity', r'(?i)\.from\(\s*[\'"]\w*(?:activit|histor|trail|(?:status|change|field|diff)_?logs?\b)\w*[\'"]\s*\)\s*\.(?:insert|upsert)\('),
            ('job', r'(?i)\.from\(\s*[\'"]\w*(?:queue|jobs?\b)\w*[\'"]\s*\)\s*\.(?:insert|upsert)\(|\.rpc\(\s*[\'"]\w*(?:enqueue|queue)\w*[\'"]|pgmq'),
            ('event', r'(?i)\.from\(\s*[\'"]\w*(?:outbox|events?)\b\w*[\'"]\s*\)\s*\.(?:insert|upsert)\(|\.channel\([^)]*\)\s*\.send\(')]
CODE_RX = re.compile(r'^[a-z][a-z0-9]*(?:[_.\-][a-z0-9]+)*$|^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+$')


def edge(h, ctx):
    if 'edge' in ctx:
        return ctx['edge']
    base = base_dir(h, ctx)
    pre = _pre(base)
    cfg = {}
    if h.exists(pre + 'config.toml'):
        cur = None
        for line in h.read(pre + 'config.toml').splitlines():
            sm = re.match(r'\s*\[functions\.["\']?([\w\-]+)["\']?\]', line)
            if sm:
                cur = cfg.setdefault(sm.group(1), {})
                continue
            if re.match(r'\s*\[', line):
                cur = None
                continue
            vm = re.match(r'\s*(verify_jwt|entrypoint)\s*=\s*["\']?([^"\'\s#]+)', line)
            if cur is not None and vm:
                cur[vm.group(1)] = vm.group(2)
    files = h.files([pre + 'functions/**/*.ts', pre + 'functions/**/*.tsx', pre + 'functions/**/*.js', pre + 'functions/**/*.mjs'])
    fs = dict((rel, F(h, rel)) for rel in files)
    shared = {}
    for rel, f in fs.items():
        for em in re.finditer(r'\bexport\s+(?:async\s+)?function\s+(\w+)\s*(?:<[^>]*>)?\s*\(|\bexport\s+const\s+(\w+)\s*=\s*(?:async\s+)?(?:\([^)]*\)|\w+)\s*(?::[^=]+)?=>', f.m):
            name = em.group(1) or em.group(2)
            p = f.m.find('{', em.end())
            if p < 0:
                continue
            shared[(rel, name)] = (em.start(), _close(f.m, p) + 1)
    fns = []
    for rel in files:
        parts = rel[len(pre):].split('/')
        if len(parts) != 3 or parts[0] != 'functions' or parts[1].startswith(('_', '.')) or not re.match(r'index\.(?:ts|tsx|js|mjs)$', parts[2]):
            continue
        name = parts[1]
        c = cfg.get(name, {})
        fns.append({'name': name, 'f': fs[rel], 'verify_jwt': c.get('verify_jwt', 'true')})
    for name, c in cfg.items():
        ep = c.get('entrypoint')
        if ep and not any(x['name'] == name for x in fns):
            rel = os.path.normpath(os.path.join(base or '.', ep)).lstrip('./') if ep.startswith('.') else ep
            if rel in fs:
                fns.append({'name': name, 'f': fs[rel], 'verify_jwt': c.get('verify_jwt', 'true')})
    for fn in fns:
        f = fn['f']
        imps = {}
        for im in re.finditer(r'\bimport\s*\{([^}]*)\}\s*from\s*([\'"])([^\'"]+)\2', f.t):
            target = os.path.normpath(os.path.join(os.path.dirname(f.rel), im.group(3)))
            for part in im.group(1).split(','):
                pm = re.match(r'\s*(?:type\s+)?(\w+)(?:\s+as\s+(\w+))?\s*$', part)
                if pm:
                    imps[pm.group(2) or pm.group(1)] = (target, pm.group(1))
        fn['imports'] = imps
        fn['blocks'] = ef_blocks(f)
    ctx['edge'] = {'fns': fns, 'files': fs, 'shared': shared}
    return ctx['edge']


def if_block(f, i):
    """The body range of the `if (…)` whose condition holds index i (the braces, or one statement)."""
    q = f.m.rfind('if', max(0, i - 400), i)
    while q >= 0:
        y = re.match(r'if\s*\(', f.m[q:q + 40])
        if y and (q == 0 or not re.match(r'\w', f.m[q - 1])):
            p = q + y.end() - 1
            e = _close(f.m, p)
            if e > i:
                k = e + 1
                while k < len(f.m) and f.m[k] in ' \t\r\n':
                    k += 1
                if f.m[k:k + 1] == '{':
                    return q, _close(f.m, k) + 1
                s = f.m.find(';', k)
                return q, (s + 1 if s >= 0 else len(f.m))
        q = f.m.rfind('if', max(0, i - 400), q)
    return None


def ef_blocks(f):
    """[(kind, value, method, a, b)]: action branches (`switch (action)` cases, `action === 'x'` ifs) and sub-path
    branches (`req.method === 'GET' && route === '/x'`)."""
    out, t, m = [], f.t, f.m
    for y in re.finditer(r'\breq\.method\s*===?\s*([\'"])(\w+)\1\s*&&\s*[\w.]+\s*===?\s*([\'"])(/[^\'"]*)\3|'
                         r'\b[\w.]+\s*===?\s*([\'"])(/[^\'"]*)\5\s*&&\s*req\.method\s*===?\s*([\'"])(\w+)\7', t):
        if m[y.start():y.start() + 3] != t[y.start():y.start() + 3]:
            continue
        rng = if_block(f, y.start())
        if rng:
            out.append(('path', y.group(4) or y.group(6), (y.group(2) or y.group(8)).upper(), rng[0], rng[1]))
    for y in re.finditer(r'\bswitch\s*\(\s*(?:\w+\.)*(?:action|op|operation)\s*\)\s*\{', m):
        p = y.end() - 1
        e = _close(m, p)
        cases = [(c.start(), t[c.start(1) + 1:c.end(1) - 1]) for c in re.finditer(r'\bcase\s+([\'"][^\'"\n]*[\'"])\s*:', t[:e]) if c.start() > p]
        cases = [(i, v) for i, v in cases if m[i:i + 4] == 'case']
        stops = sorted([i for i, _ in cases] + [p + x.start() for x in re.finditer(r'\bdefault\s*:', m[p:e])] + [e])
        for i, v in cases:
            nxt = min([s for s in stops if s > i] or [e])
            out.append(('action', v, None, i, nxt))
    for y in re.finditer(r'\b(?:\w+\.)?(?:action|op|operation)\s*===?\s*([\'"])([\w.:\-]+)\1', t):
        if m[y.start():y.start() + 2] != t[y.start():y.start() + 2]:
            continue
        rng = if_block(f, y.start())
        if rng:
            mm = re.search(r'req\.method\s*===?\s*[\'"](\w+)[\'"]', t[rng[0]:y.start()])
            out.append(('action', y.group(2), mm.group(1).upper() if mm else None, rng[0], rng[1]))
    return out


def ef_routes(fn):
    f, base = fn['f'], '/functions/v1/' + fn['name'].lower()
    t = f.t
    allowed = set(x.upper() for x in re.findall(r'\breq\.method\s*!==?\s*[\'"](\w+)[\'"]', t))
    paths = [b for b in fn['blocks'] if b[0] == 'path']
    branched = set(x.upper() for x in re.findall(r'\breq\.method\s*===?\s*[\'"](\w+)[\'"]', t)) - {'OPTIONS', 'HEAD'}
    out = []
    if paths:
        for _, v, meth, a, b in paths:
            out.append(('%s %s%s' % (meth, base, v.rstrip('/').lower()), a, b, 'path'))
        return out, 'branched'
    acts = {}
    for _, v, meth, a, b in [x for x in fn['blocks'] if x[0] == 'action']:
        acts.setdefault(v, []).append((meth, a, b))
    if len(acts) >= 2:
        for v, rs in acts.items():
            meth = next((mm for mm, _, _ in rs if mm), None) or (list(allowed)[0] if len(allowed) == 1 else 'POST')
            out.append(('%s %s?action=%s' % (meth, base, v.lower()), rs[0][1], rs[-1][2], 'action'))
        return out, 'dispatch'
    meths = (allowed - {'OPTIONS', 'HEAD'}) or ((branched | {'POST'}) if branched else {'POST'})
    for mth in sorted(meths):
        out.append(('%s %s' % (mth, base), 0, len(t), 'base'))
    return out, ','.join(sorted(allowed)) if allowed else 'any'


def ef_segment(fn, a, b, kind):
    """The text a route answers with: its own block plus the file outside every other block. For a branched or
    dispatched route (IR-4), a top-level function of the file counts only when that text calls it (transitively):
    the `/token` branch is not authenticated by the `getUser` inside a helper only `/consent` calls."""
    f = fn['f']
    if kind == 'base':
        return f.t, f.m
    t, m = list(f.t), list(f.m)
    for _, v, _, x, y in fn['blocks']:
        if (x, y) != (a, b) and not (x <= a and b <= y):
            for j in range(x, y):
                t[j] = ' '
                m[j] = ' '
    tops = []
    for y in re.finditer(r'(?m)^(?:export\s+)?(?:async\s+)?function\s+(\w+)\s*(?:<[^>]*>)?\s*\(|^(?:export\s+)?const\s+(\w+)\s*=\s*(?:async\s+)?(?:\([^)]*\)|\w+)\s*(?::[^=\n]+)?=>\s*\{', f.m):
        p = f.m.find('{', y.end() - 1 if y.group(2) else y.end())
        if p >= 0:
            tops.append((y.group(1) or y.group(2), y.start(), _close(f.m, p) + 1))
    # a regex literal can unbalance the masked braces: a top-level function never runs past the next one, nor
    # into the request handler
    hs = [x.start() for x in re.finditer(r'(?m)^(?:export\s+default\s+|Deno\.)?serve\s*\(|^Deno\.serve\s*\(', f.m)]
    starts = sorted([x for _, x, _ in tops] + hs)
    tops = [(nm, x, min([z] + [q for q in starts if q > x])) for nm, x, z in tops]
    if tops:
        live = set()
        rest = ''.join(m)
        for nm, x, z in tops:
            rest = rest[:x] + ' ' * (z - x) + rest[z:]
        todo = [rest]
        while todo:
            txt = todo.pop()
            for nm, x, z in tops:
                if nm not in live and re.search(r'(?<![.\w])%s\s*\(' % re.escape(nm), txt):
                    live.add(nm)
                    todo.append(f.m[x:z])
        for nm, x, z in tops:
            if nm not in live:
                for j in range(x, z):
                    t[j] = ' ' if t[j] != '\n' else '\n'
                    m[j] = ' ' if m[j] != '\n' else '\n'
    return ''.join(t), ''.join(m)


def ef_hops(E, fn, seg, depth=3):
    """Bodies of the _shared helpers the segment calls, by imported name, then the helpers those call (same file
    first, else any _shared export of that name), up to `depth` hops."""
    out, seen, todo = [], set(), []
    for local, (target, name) in fn['imports'].items():
        if re.search(r'\b%s\s*\(' % re.escape(local), seg):
            rel = target if target.endswith(('.ts', '.js')) else target + '.ts'
            if (rel, name) in E['shared']:
                todo.append((rel, name, 1))
    if 'by_name' not in E:
        E['by_name'] = {}
        for (rel, name) in E['shared']:
            E['by_name'].setdefault(name, []).append(rel)
    while todo:
        rel, name, d = todo.pop(0)
        if (rel, name) in seen:
            continue
        seen.add((rel, name))
        a, b = E['shared'][(rel, name)]
        body = E['files'][rel].t[a:b]
        out.append((name, body))
        if d < depth:
            for cn in set(re.findall(r'(?<![.\w])(\w+)\s*\(', E['files'][rel].m[a:b])) - {name}:
                rels = E['by_name'].get(cn, [])
                for r2 in ([rel] if rel in rels else rels[:1]):
                    todo.append((r2, cn, d + 1))
    return out


def ef_authz(h, E, fn, seg):
    hops = ef_hops(E, fn, seg)
    allt = seg + '\n'.join(b for _, b in hops)
    authn = 'required' if AUTH_RX.search(allt) or any(re.search(r'(?i)verify\w*jwt|jwt\w*verify|resolveCaller|requireUser|requireAuth|getUser|authenticat', n) for n, _ in hops) else 'none'   # signJWT mints, it does not check
    extra = 'yes' if SECRET_RX.search(allt) else 'no'
    roles = set()
    for rx in (r'\.rpc\(\s*[\'"]has_role[\'"]\s*,\s*\{[^}]*?[\'"](\w+)[\'"]\s*,?\s*\}', r'\brole\s*[!=]==?\s*[\'"](\w+)[\'"]',
               r'\.eq\(\s*[\'"]role[\'"]\s*,\s*[\'"](\w+)[\'"]'):
        roles |= set(x.lower() for x in re.findall(rx, allt))
    if re.search(r'\b(?:verify|require|ensure|check)\w*Admin\w*\s*\(|\.rpc\(\s*[\'"]is_admin[\'"]', allt):
        roles.add('admin')
    abil = set()
    for y in re.finditer(r'\b(\w*[Pp]erm\w*)\s*\(|\.rpc\(\s*[\'"](\w*perm\w*)[\'"]', allt):
        p = allt.find('(', y.start() if y.group(1) else y.start() + 4)
        e = _close(allt, p)
        for v in re.findall(r'[\'"]([a-z][a-z0-9_.:\-]*)[\'"]', allt[p:e]):
            if v != (y.group(2) or '') and v not in ('authorization',):
                abil.add(v)
    return {'authn': authn, 'extra_guard': extra, 'roles': ','.join(sorted(roles)), 'abilities': ','.join(sorted(set(h.ability(a) for a in abil))),
            'mw': ','.join(sorted(n for n, _ in hops)), 'verify_jwt': 'yes' if fn['verify_jwt'] != 'false' else 'no'}


def ef_kinds(E, fn, seg):
    allt = seg + '\n'.join(b for _, b in ef_hops(E, fn, seg))
    ks = set(k for k, rx in EF_KINDS if re.search(rx, allt))
    for y in re.finditer(r'\bfunctions\s*\.\s*invoke\(\s*[\'"]([\w\-]+)[\'"]|/functions/v1/([\w\-]+)', allt):
        n = (y.group(1) or y.group(2)).lower()
        k = 'mail' if 'mail' in n else 'notify' if re.search(r'whatsapp|sms|notif|push', n) else 'webhook' if 'webhook' in n else None
        if k:
            ks.add(k)
    also = 'storage' if re.search(r'\.storage\s*\.\s*from\([^)]*\)\s*\.\s*(?:upload|remove|move|copy|update)\(', allt) else ''
    return ks, also


# ---------------------------------------------------------------- routes (one list, every route-keyed lane)
def routes(h, ctx):
    if 'routes' in ctx:
        return ctx['routes']
    db, out, hidden = replay(h, ctx), [], 0
    E = edge(h, ctx)
    for fn in E['fns']:
        rs, meths = ef_routes(fn)
        for key, a, b, kind in rs:
            out.append({'key': key, 'type': 'edge', 'fn': fn, 'a': a, 'b': b, 'kind': kind, 'methods': meths,
                        'rel': fn['f'].rel, 'i': a})
    for k, f in sorted(db.funcs.items()):
        if schema_of(f['name']) != 'public' or f['kind'] != 'function' or f['returns'] in ('trigger', 'event_trigger'):
            continue
        if not (f['grants'] & API):
            hidden += 1
            continue
        out.append({'key': 'POST /rest/v1/rpc/%s' % f['name'].lower(), 'type': 'rpc', 'f': f, 'rel': f['rel'], 'i': f['at'][1]})
    fidx = fn_index(db)
    for tn, T in live_tables(db):
        if schema_of(tn) != 'public':
            continue
        for cmd, meth in CMDS:
            roles = set(r for r, ps in T['grants'].items() if cmd in ps) & API
            if not roles:
                continue
            if T['rls']:
                pols = [P for (pt, pn), P in sorted(db.policies.items()) if pt == tn and P['permissive'] and P['cmd'] in ('all', cmd)
                        and (P['roles'] & roles or 'public' in P['roles']) and not deny(P, cmd)]
                if not pols:
                    continue
            else:
                pols = []
            out.append({'key': '%s /rest/v1/%s' % (meth, tn), 'type': 'table', 'table': tn, 'cmd': cmd, 'pols': pols,
                        'restrict': [P for (pt, pn), P in db.policies.items() if pt == tn and not P['permissive'] and P['cmd'] in ('all', cmd)],
                        'rls': T['rls'], 'rel': T['at'][0], 'i': T['at'][1], 'fidx': fidx})
    if hidden:
        ctx.setdefault('notes', []).append('supabase I-ROUTES: %d public function(s) no API role may EXECUTE (service_role only) left out' % hidden)
    if db.views:
        ctx.setdefault('notes', []).append('supabase I-ROUTES: %d view(s) PostgREST also serves are not route rows' % len(db.views))
    ctx['routes'] = out
    return out


def _r(h, key, attrs, at):
    rel, i = at
    return h.row(key, attrs, rel, h.read(rel), i) if rel else h.row(key, attrs, None, '', 0)


def _merge_rows(rows):
    out = {}
    for r in rows:
        k = r['key']
        if k not in out:
            out[k] = r
            continue
        a = out[k]['attrs']
        for x, v in r['attrs'].items():
            if x in ('abilities', 'roles', 'values', 'kinds', 'status', 'modes', 'value') and a.get(x) not in (None, '?') and v != '?':
                a[x] = ','.join(sorted(set(p for p in (a[x] + ',' + v).split(',') if p)))
            elif x == 'authn' and v == 'none':
                a[x] = 'none'
            elif x not in a:
                a[x] = v
    return list(out.values())


def lane_routes(root, h, ctx):
    rows = []
    for r in routes(h, ctx):
        at = {'opt': '0', 'constraint': '', 'via': r['type']}
        if r['type'] == 'edge':
            at.update(handler='functions/%s' % r['fn']['name'], methods=r['methods'])
        elif r['type'] == 'rpc':
            at.update(handler=r['f']['name'], get='yes' if r['f']['vol'] in ('stable', 'immutable') else 'no')
        rows.append(_r(h, r['key'], at, (r['rel'], r['i'])))
    return _merge_rows(rows)


def lane_authz(root, h, ctx):
    E, db, rows = edge(h, ctx), replay(h, ctx), []
    fidx = fn_index(db)
    for r in routes(h, ctx):
        if r['type'] == 'edge':
            seg, _ = ef_segment(r['fn'], r['a'], r['b'], r['kind'])
            at = ef_authz(h, E, r['fn'], seg)
            at['src'] = 'edge function'
        elif r['type'] == 'rpc':
            f = r['f']
            fsrc(f)
            bl = f['bl']
            uv = re.findall(r'\b(\w+)\s*:=\s*auth\.uid\(\)', bl)
            guard = re.search(r'auth\.uid\(\)\s+is\s+(?:not\s+)?null|auth\.role\(\)\s*(?:<>|!=|=)\s*\'(?:authenticated|anon)\'', bl) or \
                any(re.search(r'\b%s\s+is\s+null' % re.escape(v), bl) for v in uv)
            abil = perm_lits(f['S'].c)
            at = {'authn': 'required' if (not (f['grants'] & {'public', 'anon'}) or guard or abil) else 'none',
                  'abilities': ','.join(sorted(h.ability(a) for a in abil)), 'roles': ','.join(sorted(role_lits(bl))),
                  'extra_guard': 'no', 'security': 'definer' if f['secdef'] else 'invoker',
                  'grants': ','.join(sorted(f['grants'] & (API | {'service_role'}))), 'src': 'rpc'}
        else:
            exprs = []
            open_ = not r['rls']
            for P in r['pols']:
                e = (P['check'] or P['using'] or '') if r['cmd'] == 'insert' else ((P['using'] or '') + ' ' + (P['check'] or '')) \
                    if r['cmd'] == 'update' else (P['using'] or '')
                exprs.append(e)
                if (P['roles'] & {'public', 'anon'}) and not needs_user(e, fidx):
                    open_ = True
            exprs += [(P['using'] or '') + ' ' + (P['check'] or '') for P in r['restrict']]
            joined = ' '.join(exprs)
            at = {'authn': 'none' if open_ else 'required', 'abilities': ','.join(sorted(h.ability(a) for a in perm_lits(joined))),
                  'roles': ','.join(sorted(role_lits(joined))), 'extra_guard': 'no',
                  'src': 'rls-disabled' if not r['rls'] else 'rls:' + ','.join(sorted(P['name'] for P in r['pols']))[:120]}
        rows.append(_r(h, r['key'], at, (r['rel'], r['i'])))
    return _merge_rows(rows)


def lane_scope(root, h, ctx):
    db, rows = replay(h, ctx), []
    fidx = fn_index(db)
    for tn, T in live_tables(db):
        sel = [P for (pt, pn), P in sorted(db.policies.items()) if pt == tn and P['permissive'] and P['cmd'] in ('all', 'select')
               and P['roles'] & (API | {'public'}) and not deny(P)]
        rsel = [P for (pt, pn), P in db.policies.items() if pt == tn and not P['permissive'] and P['cmd'] in ('all', 'select')]
        if not T['rls']:
            tenant, soft, sc = 'no', 'no', ['rls:off']
        elif not sel:
            tenant, soft, sc = 'no', 'no', ['rls:no-select-policy']
        else:
            kinds = []
            for P in sel:
                e = (P['using'] or 'true').translate(LOW)
                kinds.append('open' if re.match(r'^\s*\(*\s*true\s*\)*\s*$', e) or not needs_user(e, fidx) and not SCOPE_RX.search(e)
                             else 'scoped')
            tenant = 'yes' if all(k == 'scoped' for k in kinds) else 'no'
            soft = 'yes' if all(SOFT_RX.search((P['using'] or '').translate(LOW)) for P in sel) else 'no'
            sc = sorted(set('rls:' + k for k in kinds))
        if any(SOFT_RX.search((P['using'] or '').translate(LOW)) for P in rsel):
            soft = 'yes'
        rows.append(_r(h, 'table:' + h.table(tn), {'soft_delete': soft, 'tenant': tenant, 'scopes': ','.join(sc)}, T['at']))
    return rows


def lane_schema(root, h, ctx):
    db, rows = replay(h, ctx), {}

    def add(key, attrs, at):
        if key not in rows:
            rows[key] = _r(h, key, attrs, at)
    for tn, T in live_tables(db):
        tk = h.table(tn)
        pk = set(c for v in T['cons'].values() if v['k'] == 'p' for c in v['cols'])
        for c, cd in T['cols'].items():
            num = re.search(r'\b(?:numeric|decimal)\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)', cd['type'])
            add('col:%s.%s' % (tk, c), {'null': 'no' if cd['notnull'] or c in pk else 'yes', 'numeric': '%s,%s' % num.groups() if num else '',
                                        'type': cd['type']}, cd['at'])
            if cd['gen']:
                add('derived:%s.%s' % (tk, c), {'how': 'generated'}, cd['at'])
        for name, v in T['cons'].items():
            if v['k'] == 'u':
                add('unique:%s(%s)' % (tk, ','.join(sorted(v['cols']))), {'where': ''}, v['at'])
            elif v['k'] == 'f':
                add('fk:%s(%s)' % (tk, ','.join(v['cols'])), {'ref': h.table(v['ref']), 'on_delete': v['ondelete']}, v['at'])
    for name, ix in db.indexes.items():
        if ix['unique'] and ix['table'] in db.tables and schema_of(ix['table']) not in SYS:
            add('unique:%s(%s)' % (h.table(ix['table']), ','.join(sorted(ix['cols']))), {'where': ' '.join(ix['where'].split())[:60]}, ix['at'])
    for name, at in db.views.items():
        if schema_of(name) not in SYS:
            add('view:' + name.split('.')[-1], {'how': 'view'}, at)
    fidx = fn_index(db)
    for (tn, tg), G in db.triggers.items():
        T = db.tables.get(tn)
        if T is None or tg in T['disabled'] or schema_of(tn) in SYS:
            continue
        for f in fidx.get(G['func'].split('.')[-1], ()):
            fsrc(f)
            bl = f['bl']
            if G['timing'] == 'before':
                for y in re.finditer(r'\bnew\s*\.\s*(\w+)\s*:?=\s*([^;]+);', bl):
                    val = y.group(2).strip()
                    if re.match(r'^(?:now\(\)|current_timestamp|clock_timestamp\(\)|statement_timestamp\(\)|transaction_timestamp\(\)|'
                                r'timezone\([^;]*now\(\)\)|\(?now\(\)\s*at\s+time\s+zone[^;]*|null|old\s*\.\s*\w+|coalesce\(\s*new\s*\.\s*%s\b.*)$' % re.escape(y.group(1)), val):
                        continue
                    if y.group(1) in T['cols']:
                        add('derived:%s.%s' % (h.table(tn), y.group(1)), {'how': 'trigger'}, G['at'])
            for y in re.finditer(r'\bupdate\s+(%s)\s+set\s+(\w+)\s*=' % QN, strip_lits(bl)):
                tgt = qname(y.group(1))
                if tgt in db.tables and y.group(2) in db.tables[tgt]['cols']:
                    add('derived:%s.%s' % (h.table(tgt), y.group(2)), {'how': 'trigger'}, G['at'])
    return list(rows.values())


def check_values(T, v):
    """A single-column CHECK that is a value list -> (column, values), else None."""
    expr = v.get('expr') or ''
    if len(v['cols']) != 1:
        return None
    col = v['cols'][0]
    sk = strip_lits(expr).translate(LOW)
    if re.search(r'<|>|~|\blike\b|\blength\b|\bnot\b|\bbetween\b|\band\b', sk):
        return None
    if not re.search(r'\bin\s*\(|=\s*any\s*\(|=\s*\'', sk):
        return None
    words = set(re.findall(r'[a-z_]\w*', sk)) - {'in', 'any', 'array', 'text', 'varchar', 'character', 'varying', 'is', 'null', 'or',
                                                 'int', 'integer', 'bigint', 'smallint', 'numeric', 'citext', 'name', 'bpchar'}
    if words != {col}:
        return None
    vals = re.findall(r"'((?:[^']|'')*)'", expr)
    return (col, sorted(set(x.replace("''", "'") for x in vals))) if vals else None


def lane_enum(root, h, ctx):
    db, rows = replay(h, ctx), []
    enums = dict((n.split('.')[-1], T) for n, T in db.types.items())
    for name, T in db.types.items():
        rows.append(_r(h, 'type:' + h.ident(name.split('.')[-1], ENUM_STRIP), {'values': ','.join(sorted(set(T['values']))), 'names': name}, T['at']))
    for tn, Tb in live_tables(db):
        tk = h.table(tn)
        for c, cd in Tb['cols'].items():
            en = sigtype(cd['type']).replace('[]', '').split('.')[-1]
            if en in enums:
                rows.append(_r(h, 'col:%s.%s' % (tk, c), {'values': ','.join(sorted(set(enums[en]['values']))), 'names': en}, cd['at']))
        for cn, v in Tb['cons'].items():
            if v['k'] != 'c':
                continue
            cv = check_values(Tb, v)
            if cv:
                rows.append(_r(h, 'col:%s.%s' % (tk, cv[0]), {'values': ','.join(cv[1]), 'names': 'check:' + cn}, v['at']))
    E = edge(h, ctx)
    for f in E['files'].values():
        for em in re.finditer(r'\b(?:export\s+)?(?:const\s+)?enum\s+(\w+)\s*\{', f.m):
            p = em.end() - 1
            vals = f.lits(p, _close(f.m, p))
            if vals:
                rows.append(_r(h, 'type:' + h.ident(em.group(1), ENUM_STRIP), {'values': ','.join(sorted(set(vals))), 'names': em.group(1)}, (f.rel, em.start())))
        for um in re.finditer(r'\b(?:export\s+)?type\s+(\w+)\s*=\s*((?:\s*\|?\s*[\'"][^\'"\n]*[\'"])+)\s*;', f.t):
            lt = re.findall(r'[\'"]([^\'"\n]*)[\'"]', um.group(2))
            if len(lt) >= 2 and f.m[um.start()] == f.t[um.start()]:
                rows.append(_r(h, 'type:' + h.ident(um.group(1), ENUM_STRIP), {'values': ','.join(sorted(set(lt))), 'names': um.group(1)}, (f.rel, um.start())))
        for zm in re.finditer(r'\bconst\s+(\w+)\s*=\s*z\s*\.\s*enum\s*\(', f.m):
            p = zm.end() - 1
            rows.append(_r(h, 'type:' + h.ident(zm.group(1), ENUM_STRIP), {'values': ','.join(sorted(set(f.lits(p, _close(f.m, p))))), 'names': zm.group(1)}, (f.rel, zm.start())))
    return _merge_rows(rows)


def check_rule(T, v):
    expr = (v.get('expr') or '').translate(LOW)
    at = {'presence': '?', 'nullable': '?', 'type': '?', 'format': '', 'max': '', 'min': '', 'in': '', 'regex': '',
          'expr': ' '.join(expr.split())[:120], 'src': 'db-check'}
    c = re.escape(v['cols'][0])
    for op, num in re.findall(r'\(?\b%s\b\)?\s*(>=|>|<=|<)\s*\(?(-?\d+(?:\.\d+)?)' % c, expr):
        if op == '>=':
            at['min'] = num
        elif op == '>':
            at['min'] = '>' + num
        elif op == '<=':
            at['max'] = num
        else:
            at['max'] = '<' + num
    bm = re.search(r'\b%s\b\s+between\s+(-?\d+(?:\.\d+)?)\s+and\s+(-?\d+(?:\.\d+)?)' % c, expr)
    if bm:
        at['min'], at['max'] = bm.group(1), bm.group(2)
    lm = re.search(r'\b(?:char_|octet_)?length\s*\(\s*(?:b?trim\s*\(\s*)?\(?%s\)?(?:\s*\)\s*)?\s*\)\s*(<=|<|>=|>)\s*(\d+)' % c, expr)
    if lm:
        at['type'] = 'string'
        n = int(lm.group(2))
        if lm.group(1) in ('<=', '<'):
            at['max'] = str(n if lm.group(1) == '<=' else n - 1)
        else:
            at['min'] = str(n if lm.group(1) == '>=' else n + 1)
    if re.search(r"\b%s\b\s*(?:<>|!=)\s*''|b?trim\s*\(\s*%s\s*\)\s*(?:<>|!=)\s*''" % (c, c), expr):
        at['min'] = at['min'] or '1'
    rm = re.search(r"\b%s\b\s*~\*?\s*'((?:[^']|'')*)'" % c, v.get('expr') or '')
    if rm:
        at['regex'] = rm.group(1)
    return at


def ef_rules(h, E, fn, rts):
    """[(route key, field, attrs, at)] from zod schemas a function parses and fields destructured from its body."""
    out, f = [], fn['f']
    ix = {'files': dict((r, N.F(h, r)) for r in [f.rel] + sorted(set(t for t, _ in fn['imports'].values() if t in E['files']))), 'enums': {},
          'classes': {}}
    zi = N.zod_index(ix, h, {})
    nf = ix['files'][f.rel]
    for y in re.finditer(r'\b(\w+)\s*\.\s*(?:safe)?[pP]arse(?:Async)?\s*\(', f.m):
        if y.group(1) not in zi:
            continue
        g, ga, gb = zi[y.group(1)]
        fields = []
        N.zod_fields(h, ix, zi, g, ga, gb, '', 0, fields)
        for key, a, b, kind in rts:
            if kind == 'base' or a <= y.start() < b or not any(x[3] <= y.start() < x[4] for x in fn['blocks']):
                for field, at, (gf, i) in fields:
                    out.append((key, field, at, (gf.rel, i)))
    bodies = set(re.findall(r'\b(?:const|let)\s+(\w+)\s*(?::[^=]+)?=\s*await\s+(?:req|request)\.json\(\)', f.t))
    for y in re.finditer(r'\b(?:const|let)\s*\{', f.m):
        p = y.end() - 1
        e = _close(f.m, p)
        rhs = re.match(r'\s*\}?\s*(?::[^=]+)?=\s*(?:await\s+(?:req|request)\.json\(\)|(\w+)\s*(?:as\s+\w+\s*)?;)', f.m[e:e + 120])
        if not rhs or (rhs.group(1) and rhs.group(1) not in bodies):
            continue
        names = []
        for pa, pb in split_top(f.m, p + 1, e):
            seg = f.t[pa:pb].strip()
            nm = re.match(r'(\w+)\s*(?::\s*(\w+))?\s*(=)?', seg)
            if nm and not seg.startswith('...'):
                names.append((nm.group(1), nm.group(2) or nm.group(1), bool(nm.group(3))))
        for field, var, dflt in names:
            at = {'presence': 'optional', 'nullable': 'yes', 'type': '?', 'format': '', 'max': '', 'min': '', 'in': '', 'regex': '', 'src': 'hand-read'}
            v = re.escape(var)
            for g in re.finditer(r'\bif\s*\(([^{};]*?)\)\s*\{?\s*(?:return|throw)[^;]{0,240}?(?:status\s*:\s*4\d\d|,\s*4\d\d\s*\))', f.t[e:]):
                cond = g.group(1)
                if re.search(r'!\s*%s\b(?!\s*\.)' % v, cond) or re.search(r'\b%s\s*===?\s*(?:undefined|null)' % v, cond):
                    at['presence'], at['nullable'] = 'required', 'no'
                tm = re.search(r'typeof\s+%s\s*!==?\s*[\'"](\w+)[\'"]' % v, cond)
                if tm:
                    at['presence'], at['nullable'] = 'required', 'no'
                    at['type'] = {'number': 'number', 'boolean': 'bool', 'object': 'object'}.get(tm.group(1), tm.group(1))
                if re.search(r'!\s*Array\.isArray\(\s*%s\s*\)' % v, cond):
                    at['presence'], at['nullable'], at['type'] = 'required', 'no', 'array'
            if dflt:
                at['presence'] = 'optional'
            for key, a, b, kind in rts:
                if kind == 'base' or a <= y.start() < b or not any(x[3] <= y.start() < x[4] for x in fn['blocks']):
                    out.append((key, field, at, (f.rel, y.start())))
    return out


def lane_rules(root, h, ctx):
    db, E, rows = replay(h, ctx), edge(h, ctx), []
    enums = set(n.split('.')[-1] for n in db.types)
    by_fn = {}
    for r in routes(h, ctx):
        if r['type'] == 'rpc':
            f = r['f']
            g = guard_rules(f)
            for n, t, d, mo in f['args']:
                if not n or mo == 'out':
                    continue
                at = {'presence': 'optional' if d else 'required', 'nullable': 'yes', 'type': wire(t, enums), 'format': 'uuid' if sigtype(t) == 'uuid' else '',
                      'max': '', 'min': '', 'in': '', 'regex': '', 'src': 'rpc-param'}
                at.update(g.get(n, {}))
                rows.append(_r(h, '%s %s' % (r['key'], n), at, f['at']))
        elif r['type'] == 'edge':
            by_fn.setdefault(r['fn']['name'], (r['fn'], []))[1].append((r['key'], r['a'], r['b'], r['kind']))
    for name, (fn, rts) in by_fn.items():
        for key, field, at, where in ef_rules(h, E, fn, rts):
            rows.append(_r(h, '%s %s' % (key, field), at, where))
    for tn, T in live_tables(db):
        for cn, v in T['cons'].items():
            if v['k'] == 'c' and len(v['cols']) == 1 and not check_values(T, v):
                rows.append(_r(h, 'check:%s.%s' % (h.table(tn), v['cols'][0]), check_rule(T, v), v['at']))
    for key in ('trim_strings', 'empty_to_null'):
        rows.append(h.row('GLOBAL ' + key, {'on': 'no', 'src': 'postgrest / deno default (no input normalisation)'}, None, '', 0))
    return _merge_rows(rows)


def lane_err(root, h, ctx):
    db, E = replay(h, ctx), edge(h, ctx)
    found = {}
    sql_err(h, db, found)
    free = 0
    for f in E['files'].values():
        t, m = f.t, f.m
        for y in re.finditer(r'\b(error|code)\s*:\s*([\'"])([^\'"\n]{1,60})\2', t):
            if m[y.start():y.start() + 2] != t[y.start():y.start() + 2]:
                continue
            ob = m.rfind('{', 0, y.start())
            oe = _close(m, ob) if ob >= 0 else y.end()
            obj = t[ob:oe + 1]
            cm = re.search(r'\bcode\s*:\s*([\'"])([^\'"\n]+)\1', obj)
            if y.group(1) == 'error' and cm:
                continue
            val = y.group(3)
            if not CODE_RX.match(val):
                free += 1
                continue
            semi = m.find(';', oe)
            win = t[oe:semi if semi >= 0 else len(t)][:300]
            sm = re.search(r'\bstatus\s*:\s*(\d{3})\b|^\s*\}?\s*\)?\s*,\s*(\d{3})\s*\)', win)
            if not sm:
                continue
            found.setdefault('code:' + val, [set(), f.rel, y.start(), 'edge'])[0].add(sm.group(1) or sm.group(2))
    if free:
        h.notes.append('supabase I-ERR: %d edge-function error body/ies with a free-text message (not keyed)' % free)
    rows = []
    for k, (st, rel, i, src) in sorted(found.items()):
        rows.append(h.row(k, {'status': ','.join(sorted(st)), 'src': src}, rel, h.read(rel), i))
    for k, st, why in (('validation', '400', 'postgrest default (22xxx / bad JSON -> 400)'), ('not_found', '404', 'postgrest default (42883 / 42P01 -> 404; a .single() miss is 406)'),
                       ('forbidden', '403', 'postgrest default (42501 authenticated -> 403)'), ('unauthenticated', '401', 'postgrest default (42501 anon / bad JWT -> 401)')):
        rows.append(h.row(k, {'status': st, 'src': why}, None, '', 0))
    return rows


def lane_side(root, h, ctx):
    db, E, rows = replay(h, ctx), edge(h, ctx), []
    fidx = fn_index(db)
    for (tn, tg), G in sorted(db.triggers.items()):
        T = db.tables.get(tn)
        if T is None or tg in T['disabled'] or schema_of(tn) in SYS:
            continue
        ks = set()
        for f in fidx.get(G['func'].split('.')[-1], ()):
            fsrc(f)
            ks |= sql_kinds(f['bl'], fidx)
        if not ks:
            continue
        for ev in G['events']:
            name = EVENT.get((G['timing'], ev))
            if name:
                rows.append(_r(h, '%s.%s' % (h.table(tn), name), {'kinds': ','.join(sorted(ks)), 'via': 'trigger ' + tg}, G['at']))
    for r in routes(h, ctx):
        if r['type'] == 'rpc':
            fsrc(r['f'])
            ks = sql_kinds(r['f']['bl'], fidx)
            if ks:
                rows.append(_r(h, r['key'], {'kinds': ','.join(sorted(ks))}, (r['rel'], r['i'])))
        elif r['type'] == 'edge':
            seg, _ = ef_segment(r['fn'], r['a'], r['b'], r['kind'])
            ks, also = ef_kinds(E, r['fn'], seg)
            if ks:
                at = {'kinds': ','.join(sorted(ks))}
                if also:
                    at['also'] = also
                rows.append(_r(h, r['key'], at, (r['rel'], r['i'])))
    return _merge_rows(rows)


def lane_sched(root, h, ctx):
    db, rows = replay(h, ctx), []
    efs = set(fn['name'].lower() for fn in edge(h, ctx)['fns'])
    fidx, dead = fn_index(db), 0
    for name, J in sorted(db.cron.items()):
        cmd = (J['cmd'] or '?').translate(LOW)
        em = re.search(r'/functions/v1/([\w\-]+)', cmd)
        sm = re.search(r'\b(?:select|perform|call)\s+(?:public\s*\.\s*)?([a-z_]\w*)\s*\(', cmd)
        target = ('edge:' + em.group(1)) if em else ('sql:' + sm.group(1)) if sm else '?' if cmd == '?' else 'sql'
        key = name if J['named'] else (em.group(1) if em else sm.group(1) if sm else name)
        sched = J['sched'].strip()
        # liveness of the target (not compared; read by the detector): a deleted edge function, a missing or
        # overloaded SQL function errors on every run, so the job is dead in V1
        live = ('no' if target.startswith('edge:') and target[5:] not in efs else
                'no' if target.startswith('sql:') and not fidx.get(target[4:]) else
                'ambiguous' if target.startswith('sql:') and len(fidx.get(target[4:], ())) > 1 else
                '?' if target == '?' else 'yes')
        dead += live != 'yes'
        rows.append(_r(h, 'job:' + h.tokkey(key, h.SCHED_DROP),
                       {'cron': h.cron(sched) if not re.search(r'second|\$', sched) else '?', 'tz': db.cron_tz or 'UTC', 'overlap': 'yes',
                        'target': target, 'name': name[:60], 'target_live': live}, J['at']))
    if dead:
        h.notes.append('supabase I-SCHED: %d job(s) whose target is missing, overloaded or unread (target_live != yes): dead-in-V1 candidates' % dead)
    return rows


def area_of(h, *names):
    for n in names:   # (f) the money word of the name first (`my_wallet_balance` -> wallet), then its first noun
        mw = [w for w in h.words(n) if w not in VERBS and N.MONEY_OPND.match(w)]
        if mw:
            return 'area:' + h.table(mw[0])
    for n in names:
        ws = [w for w in h.words(n) if w not in VERBS]
        if ws:
            a = h.area(' '.join(ws), '', '')
            if a != 'area:root':
                return a
    return 'area:root'


def lane_money(root, h, ctx):
    db, E = replay(h, ctx), edge(h, ctx)
    fidx = fn_index(db)
    sites = {}
    for k, f in db.funcs.items():
        S = fsrc(f)
        ml = S.ml.translate(LOW)
        rules = [(r'\bround\s*\((?![^;]*?::\s*(?:float|double|real))', 'half-away'), (r'\bround\s*\((?=[^;]*?::\s*(?:float|double|real))', 'half-even'),
                 (r'\btrunc\s*\(', 'trunc'), (r'\bfloor\s*\(', 'floor'), (r'\bceil(?:ing)?\s*\(', 'ceil'),
                 (r'::\s*(?:numeric|decimal)\s*\(\s*\d+\s*,\s*\d+\s*\)', 'half-away')]
        modes, first = N.money_modes(ml, ml, 0, len(ml), f['name'], rules)   # (f): money operands only
        calls = set(re.findall(r'\b([a-z_]\w*)\s*\(', ml)) & set(fidx)
        at = (f['at'][0], S.off + first) if first is not None and getattr(S, 'off', None) is not None else f['at']
        sites[('sql', f['name'], k[1])] = [f['name'], modes, set(('sql', c) for c in calls), at, 'sql.' + f['name'], f['name']]
    names = {}
    for f in E['files'].values():
        dec = re.search(r'''from\s+['"][^'"]*(?:decimal\.js|big\.js|bignumber\.js)[^'"]*['"]''', f.t)
        fnm = [(y.group(1) or y.group(2), y.start()) for y in re.finditer(
            r'\bfunction\s+(\w+)\s*(?:<[^>]*>)?\s*\(|\b(?:const|let)\s+(\w+)\s*=\s*(?:async\s+)?(?:\([^)]*\)|\w+)\s*(?::[^=]+)?=>', f.m)]
        spans = []
        for nm, s in fnm:
            p = f.m.find('{', s)
            if p >= 0:
                spans.append((nm, s, _close(f.m, p)))
        dm = re.search(r'\bDeno\.serve\s*\(|\bserve\s*\(', f.m)
        if dm:
            spans.append(('<handler>', dm.start(), _close(f.m, f.m.find('(', dm.start()))))
        for nm, a, b in spans:
            rules = TS_ROUND + [(r'\.toFixed\(', 'half-away' if dec else 'float-tofixed')] + \
                ([(r'\.(?:toDecimalPlaces|toDP|round)\((?![^)]*ROUND_)', 'half-away')] if dec else [])
            modes, first = N.money_modes(f.t, f.m, a, b, '%s %s' % (f.rel, nm), rules)
            calls = set(('ts', c) for c in re.findall(r'(?<![.\w])(\w+)\s*\(', f.m[a:b]) if c != nm)
            folder = os.path.basename(os.path.dirname(f.rel))
            stem = os.path.splitext(os.path.basename(f.rel))[0]
            sites[('ts', f.rel, nm, a)] = [nm, modes, calls, (f.rel, first if first is not None else a), '%s.%s' % (folder if stem == 'index' else stem, nm),
                                           (folder if stem == 'index' else stem) + ' ' + (nm if nm != '<handler>' else '')]
            names.setdefault(('ts', nm), []).append(('ts', f.rel, nm, a))
    for k, v in sites.items():
        if k[0] == 'sql':
            names.setdefault(('sql', v[0].split('.')[-1]), []).append(k)
    for _ in range(4):
        for k, v in sites.items():
            for call in v[2]:
                for t in names.get(call, ()):
                    if t != k:
                        v[1] |= sites[t][1]
    called = set(t for v in sites.values() for call in v[2] for t in names.get(call, ()) if sites[t][1])
    rows = []
    for k, (nm, modes, calls, at, where, label) in sites.items():
        if not modes or k in called or not MONEY.search(label + ' ' + where):
            continue
        rows.append(_r(h, area_of(h, label, where), {'modes': ','.join(sorted(modes)), 'where': where}, at))
    return _merge_rows(rows)


def lane_conf(root, h, ctx):
    db, rows = replay(h, ctx), []
    base = base_dir(h, ctx)
    if db.tz:
        v, at = db.tz[-1]
        rows.append(_r(h, 'timezone', {'value': v, 'src': 'ALTER DATABASE SET timezone'}, at))
    else:
        zones, first = {}, None
        for f in db.funcs.values():
            S = fsrc(f)
            for y in re.finditer(r"\bat\s+time\s+zone\s+'([A-Za-z_]+/[A-Za-z_/+\-]+)'", S.c, re.I):
                zones[y.group(1)] = zones.get(y.group(1), 0) + 1
                first = first or (f['rel'], f['off'] + f['ba'] + y.start())
        if zones:
            rows.append(_r(h, 'timezone', {'value': ','.join(sorted(zones)), 'src': 'AT TIME ZONE literals in live functions (%d sites)' % sum(zones.values())}, first))
    cfg = _pre(base) + 'config.toml'
    if h.exists(cfg):
        t = h.read(cfg)
        sec = re.search(r'(?ms)^\s*\[api\]\s*$(.*?)(?=^\s*\[|\Z)', t)
        mm = sec and re.search(r'(?m)^\s*max_rows\s*=\s*(\d+)', sec.group(1))
        if mm:
            rows.append(h.row('per_page', {'value': mm.group(1), 'src': 'config.toml [api] max_rows (a cap)'}, cfg, t, sec.start(1) + mm.start()))
    return rows


def detect(root, h):
    b = _base(h)
    if b is None:
        return {'supabase': ''}
    pre = _pre(b)
    nm = len(h.files([pre + 'migrations/*.sql']))
    nf = len([r for r in h.files([pre + 'functions/*/index.ts', pre + 'functions/*/index.js']) if not r.split('/')[-2].startswith('_')])
    if not nm and not nf:
        return {'supabase': ''}
    return {'supabase': '%s · %d migration(s) · %d edge function(s)' % (pre + 'config.toml' if h.exists(pre + 'config.toml') else (b or '.'), nm, nf)}


LANES = {'supabase': {'I-SCHEMA': lane_schema, 'I-ROUTES': lane_routes, 'I-AUTHZ': lane_authz, 'I-RULES': lane_rules, 'I-ENUM': lane_enum,
                      'I-ERR': lane_err, 'I-SIDE': lane_side, 'I-SCHED': lane_sched, 'I-SCOPE': lane_scope, 'I-MONEY': lane_money,
                      'I-CONF': lane_conf}}


# ---------------------------------------------------------------- self-test: one tree, replay-order cases + decoys
_L = C._L
SAMPLES = {'supabase': ({
    'supabase/config.toml': _L('project_id = "sample"', '', '[api]', 'max_rows = 500', '', '[functions.hook]', 'verify_jwt = false'),
    'supabase/migrations/20240101000000_init.sql': _L(
        "-- a comment with ; and 'quotes' that must not split anything",
        "create type public.ticket_state as enum ('open', 'closed');",
        "create table public.tickets (",
        "  id uuid primary key default gen_random_uuid(),",
        "  account_id uuid not null references public.accounts (id) on delete cascade,",
        "  title text not null check (char_length(title) <= 200),",
        "  qty integer not null check (qty > 0),",
        "  priority text not null constraint tickets_priority_chk check (priority = any (array['low'::text, 'high'::text])),",
        "  state public.ticket_state not null default 'open',",
        "  legacy_code text,",
        "  amount numeric(12,2) not null,",
        "  total numeric(12,2) generated always as (amount * 2) stored,",
        "  deleted_at timestamptz",
        ");",
        "create table public.accounts (id uuid primary key, name text unique);",
        "create unique index tickets_title_uq on public.tickets (lower(title)) where deleted_at is null;",
        "alter table public.tickets enable row level security;",
        "create policy \"tickets read\" on public.tickets for select to authenticated",
        "  using (deleted_at is null and public.has_workspace_permission(account_id, 'can_view_tickets'));",
        "create policy \"tickets insert\" on public.tickets for insert to authenticated with check (auth.uid() is not null);",
        "create or replace function public.close_ticket(p_id uuid, p_reason text default null) returns void",
        "language plpgsql security definer as $$",
        "begin",
        "  if p_id is null then raise exception 'ticket_required' using errcode = '22023'; end if;",
        "  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '42501'; end if;",
        "  update public.tickets set state = 'closed' where id = p_id;",
        "end; $$;",
        "create or replace function public.notify_ticket() returns trigger language plpgsql as $$",
        "begin perform net.http_post(url := 'https://example.test/hook'); return new; end; $$;",
        "create trigger tickets_notify after update on public.tickets for each row execute function public.notify_ticket();",
        "select cron.schedule('old-job', '0 1 * * *', $$select 1$$);",
        "select cron.schedule('tickets-sweep', '*/30 * * * *', $$select public.sweep_tickets()$$);",
        "do $$ begin",
        "  if not exists (select 1 from information_schema.columns where column_name = 'note') then",
        "    alter table public.tickets add column note text;",
        "  end if;",
        "  execute 'alter table public.tickets add column origin text not null default ''web''';",
        "end $$;",
        "create or replace function public.ticket_fee_total(p_amount numeric) returns numeric language sql as $$ select round(p_amount * 1.15, 2) $$;",
        "create or replace function public.my_wallet_balance(v_balance numeric) returns numeric language sql as $$ select round(v_balance, 2) $$;",
        "create or replace function public.invoice_page_count(p_total_rows int) returns int language sql as $$ select ceil(p_total_rows / 50.0)::int $$;",
        "alter database postgres set timezone to 'Africa/Cairo';"),
    'supabase/migrations/20240102000000_later.sql': _L(
        "alter type public.ticket_state add value if not exists 'pending';",
        "alter type public.ticket_state rename value 'closed' to 'resolved';",
        "alter table public.tickets drop column legacy_code;",
        "alter table public.tickets rename column title to subject;",
        "alter table public.tickets drop constraint tickets_qty_check;",
        "drop policy if exists \"tickets insert\" on public.tickets;",
        "create or replace function public.notify_ticket() returns trigger language plpgsql as $$",
        "begin insert into public.audit_log (entity) values ('ticket'); return new; end; $$;",
        "revoke execute on function public.ticket_fee_total(numeric) from public, anon, authenticated;",
        "select cron.unschedule(jobid) from cron.job where jobname = 'old-job';"),
    'supabase/functions/hook/index.ts': _L(
        "import { requireUser } from '../_shared/auth.ts';",
        "Deno.serve(async (req) => {",
        "  if (req.method === 'OPTIONS') return new Response('ok');",
        "  const sig = req.headers.get('x-signature');",
        "  if (sig !== Deno.env.get('HOOK_SECRET')) return json({ code: 'bad_signature' }, 401);",
        "  const body = await req.json();",
        "  const { ticket_id, note = '' } = body;",
        "  if (!ticket_id) return json({ error: 'ticket_id_required' }, 400);",
        "  switch (body.action) {",
        "    case 'close': {",
        "      await requireUser(req);",
        "      const denied = await enforcePermission(req, 'can_close_tickets');",
        "      return json({ ok: true }, 200);",
        "    }",
        "    case 'ping':",
        "      return json({ error: 'Something failed' }, 500);",
        "  }",
        "});"),
    'supabase/functions/_shared/auth.ts': _L(
        "export async function requireUser(req: Request) {",
        "  const { data } = await client(req).auth.getUser();",
        "  return data.user;",
        "}"),
    'supabase/functions/order-pricing/index.ts': _L(
        "function lineTotal(price: number, qty: number) { return Math.round(price * qty * 100) / 100; }",
        "Deno.serve(async (req) => {",
        "  const { price, qty } = await req.json();",
        "  return new Response(JSON.stringify({ total: lineTotal(price, qty) }));",
        "});"),
    'supabase/functions/_shared/jwt.ts': "export function signJWT(sub: string) { return sub; }\n",
    'supabase/functions/oauth/index.ts': _L(   # IR-4: authn per branch, a helper only `/consent` calls
        "import { signJWT } from '../_shared/jwt.ts';",
        "async function currentUser(req: Request) {",
        "  const { data } = await client(req).auth.getUser();",
        "  return data.user;",
        "}",
        "Deno.serve(async (req) => {",
        "  const route = new URL(req.url).pathname.replace('/oauth', '');",
        "  if (req.method === 'GET' && route === '/.well-known') {",
        "    return new Response(signJWT('issuer'));",
        "  }",
        "  if (req.method === 'POST' && route === '/consent') {",
        "    const u = await currentUser(req);",
        "    if (!u) return new Response(null, { status: 401 });",
        "    return new Response('ok');",
        "  }",
        "});"),
    'supabase/migrations/20240103000000_cron.sql': _L(
        "do $$ begin",
        "  perform cron.schedule('drain-webhook-events', '* * * * *', format($q$select net.http_post(url := %L)$q$, 'https://x'));",
        "end $$;",
        "select cron.alter_job((select jobid from cron.job where jobname = 'nightly-cleanup'), schedule := '0 4 * * *');"),
    'supabase/strict/applied-by-hand.sql': "create table public.ghost (id int);\n",
}, [
    ('I-SCHEMA', 'col:ticket.subject', {'null': 'no'}),
    ('I-SCHEMA', 'col:ticket.note', {'null': 'yes'}),
    ('I-SCHEMA', 'col:ticket.origin', {'null': 'no'}),
    ('I-SCHEMA', 'col:ticket.amount', {'numeric': '12,2'}),
    ('I-SCHEMA', 'fk:ticket(account_id)', {'ref': 'account', 'on_delete': 'cascade'}),
    ('I-SCHEMA', 'unique:account(name)', {}),
    ('I-SCHEMA', 'unique:ticket((lower(title)))', {}),
    ('I-SCHEMA', 'derived:ticket.total', {'how': 'generated'}),
    ('I-ENUM', 'type:ticketstate', {'values': 'open,pending,resolved'}),
    ('I-ENUM', 'col:ticket.state', {'values': 'open,pending,resolved'}),
    ('I-ENUM', 'col:ticket.priority', {'values': 'high,low'}),
    ('I-ROUTES', 'POST /rest/v1/rpc/close_ticket', {'via': 'rpc'}),
    ('I-ROUTES', 'GET /rest/v1/tickets', {'via': 'table'}),
    ('I-ROUTES', 'POST /functions/v1/hook?action=close', {}),
    ('I-ROUTES', 'POST /functions/v1/hook?action=ping', {}),
    ('I-ROUTES', 'POST /functions/v1/order-pricing', {'methods': 'any'}),
    ('I-AUTHZ', 'GET /rest/v1/tickets', {'authn': 'required', 'abilities': 'can.view.tickets'}),
    ('I-AUTHZ', 'POST /rest/v1/rpc/close_ticket', {'authn': 'required', 'security': 'definer'}),
    ('I-AUTHZ', 'POST /functions/v1/hook?action=close', {'authn': 'required', 'abilities': 'can.close.tickets', 'extra_guard': 'yes', 'verify_jwt': 'no'}),
    ('I-AUTHZ', 'POST /functions/v1/hook?action=ping', {'authn': 'none', 'abilities': '', 'extra_guard': 'yes'}),
    ('I-AUTHZ', 'POST /functions/v1/order-pricing', {'authn': 'none', 'extra_guard': 'no', 'verify_jwt': 'yes'}),
    ('I-SCOPE', 'table:ticket', {'tenant': 'yes', 'soft_delete': 'yes'}),
    ('I-SCOPE', 'table:account', {'tenant': 'no', 'scopes': 'rls:off'}),
    ('I-RULES', 'POST /rest/v1/rpc/close_ticket p_id', {'presence': 'required', 'nullable': 'no', 'format': 'uuid'}),
    ('I-RULES', 'POST /rest/v1/rpc/close_ticket p_reason', {'presence': 'optional', 'type': 'string'}),
    ('I-RULES', 'POST /functions/v1/hook?action=close ticket_id', {'presence': 'required'}),
    ('I-RULES', 'POST /functions/v1/hook?action=close note', {'presence': 'optional'}),
    ('I-RULES', 'check:ticket.subject', {'max': '200', 'type': 'string'}),
    ('I-RULES', 'GLOBAL trim_strings', {'on': 'no'}),
    ('I-ERR', 'code:ticket_required', {'status': '400'}),
    ('I-ERR', 'code:not_authenticated', {'status': '403'}),
    ('I-ERR', 'code:bad_signature', {'status': '401'}),
    ('I-ERR', 'code:ticket_id_required', {'status': '400'}),
    ('I-SIDE', 'ticket.updated', {'kinds': 'audit'}),
    ('I-SCHED', 'job:sweep.ticket', {'cron': '0,30 * * * *', 'tz': 'UTC', 'overlap': 'yes'}),
    ('I-SCHED', 'job:drain.event.webhook', {'cron': '* * * * *'}),     # PERFORM cron.schedule(…, format(…))
    ('I-SCHED', 'job:cleanup.nightly', {'cron': '0 4 * * *', 'target': '?'}),   # only in cron.alter_job
    ('I-AUTHZ', 'GET /functions/v1/oauth/.well-known', {'authn': 'none'}),  # IR-4: signJWT mints, a helper /consent calls
    ('I-AUTHZ', 'POST /functions/v1/oauth/consent', {'authn': 'required'}),
    ('I-MONEY', 'area:pricing', {'modes': 'half-up'}),   # the money word of `order-pricing`, not its first word
    ('I-MONEY', 'area:wallet', {'modes': 'half-away'}),  # `my_wallet_balance`: keyed by its money word, not `my`
    ('I-CONF', 'timezone', {'value': 'Africa/Cairo'}),
    ('I-CONF', 'per_page', {'value': '500'}),
], [
    ('I-SCHEMA', 'col:ticket.legacy_code'),         # dropped by the later migration
    ('I-SCHEMA', 'col:ticket.title'),               # renamed
    ('I-SCHEMA', 'col:ghost.id'),                   # .sql outside migrations/: noted, not replayed
    ('I-RULES', 'check:ticket.qty'),                # its default-named CHECK dropped
    ('I-ENUM', 'col:ticket.title'),                 # a length CHECK is a rule, not a vocabulary
    ('I-ROUTES', 'POST /rest/v1/tickets'),          # its only INSERT policy dropped
    ('I-ROUTES', 'POST /rest/v1/rpc/ticket_fee_total'),   # EXECUTE revoked from every API role
    ('I-ROUTES', 'POST /rest/v1/rpc/notify_ticket'),      # a trigger function is not an RPC
    ('I-SCHED', 'job:old'),                         # unscheduled through cron.job
    ('I-ERR', 'code:Something failed'),             # free text is not a code
    ('I-SIDE', 'POST /functions/v1/hook?action=ping'),
    ('I-MONEY', 'area:invoice'),                    # ceil over a row count is pagination, not money
    ('I-MONEY', 'area:my'),
])}


def self_test(H, tmp):
    out = C.run_samples(H, tmp, SAMPLES, detect, LANES)
    root = os.path.join(tmp, 'other-supabase')
    h = H(root, 'v1')
    ctx = {'stack': 'supabase'}
    lane_schema(root, h, ctx)
    w = (ctx.get('notes') or []) + h.notes
    out.append(('supabase: a .sql outside migrations/ is noted, not replayed', any('outside migrations/' in n for n in w), str(w)))
    S = Src('x.sql', '', "select 'a;b' as x; create function f() returns int as $f$ select 1; $f$ language sql; -- tail ; comment\n")
    out.append(('supabase: scanner splits on ; outside strings, $tag$ bodies and comments (%d statements)' % len(S.stmts),
                len(S.stmts) == 2 and len(S.m) == len(S.t) and len(S.c) == len(S.t), str(S.stmts)))
    out.append(('supabase: PostgREST SQLSTATE map', [pgrst_status(c) for c in ('P0001', '23505', '42501', 'PT402', 'P0002', '23514')] ==
                ['400', '409', '403', '402', '500', '400'], ''))
    return out
