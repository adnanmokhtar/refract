#!/usr/bin/env python3
"""status-graph.py — lifecycle-scan §1-§3 and §6: the lifecycle graph a status column implements.
Stdlib only, Python 3.8+, run with `python3 -I -B`.

Why a script and not rg: "this state is unreachable" and "this state is a trap" are properties of a
GRAPH, and the graph is spread over three kinds of files: the declaration (an enum, a string union, a
const array, a DB CHECK list or enum type), the declared edges (a transition table, an FSM library
config) and the writes (`order.status = 'paid'`, `{ status: 'paid' }` in an update payload, a
lowercase multi-line `update orders set status = 'paid' where status = 'pending'`). A per-line grep
sees one of the three. This script joins them per machine and prints the graph, the reachability and
terminality report and the unguarded writes. Every row is a CANDIDATE: the skill reads it.

Usage:  python3 -I -B status-graph.py <root> [<root> ...] [--out=<dir>] [--declared=<file>]
            [--machine=<key>] [--lookback=15] [--include-tests] [--all]
        python3 -I -B status-graph.py --self-test
Lanes, declarations: TS/JS `enum XStatus {}`, `type XStatus = 'a' | 'b'`, `const X_STATUSES = [...]`
  (+ `type X = (typeof X_STATUSES)[number]`), `const XStatus = { A: 'a' } as const`; Python
  `class XStatus(TextChoices|Enum|StrEnum…)`; Rails `enum status: {…}` / `enum :status, […]`, AASM
  `state :x`; PHP `enum XStatus: string { case A = 'a'; }`, spatie state classes; Java / Kotlin / C#
  `enum XStatus { A, B }`; Go `type XStatus string` + typed consts; SQL `create type x_status as enum`,
  `check (status in (...))`, column `default 'x'` (also inside migration code strings).
Lanes, declared edges: transition tables (`*TRANSITIONS*`, `*REVERSALS*`, `ALLOWED_*`, `NEXT_*`
  objects / dicts / hashes of lists; `[]` = declared terminal), XState `states:` blocks (`target`,
  `type: 'final'`), AASM `transitions from:/to:`, django-fsm `@transition(source=, target=)`, Python
  `transitions` (`add_transition`, trigger/source/dest dicts), spatie `allowTransition(A::class,
  B::class)`, Spring Statemachine `.source(S.A).target(S.B)`, stateless `.Configure(S.A).Permit(t,
  S.B)`, looplab/fsm `{Src: []string{..}, Dst: ".."}`.
Lanes, writes: member assignment (`x.status = `, `$x->status = `, `self.status = `), object / hash /
  array keys in create and update payloads (`{ status: 'paid' }`, `'status' => 'paid'`, `status:
  :paid`), Python kwargs (`.update(status='paid')`), setters (`setStatus(S.PAID)`), Rails
  `update_column(:status, …)`, SQL `update <t> set status = '<s>'` (case-insensitive, multi-line,
  its WHERE read as the guard). A key inside `where:` / `filter(` / `find…(` / a type union is a
  predicate, not a write. Writes under migrations/ or seeds/ are kept and tagged.
Guard: the write's own SQL WHERE, or a comparison on the status field, an `includes(x.status)`, a
  transition-table name or a `canTransition`/`assertTransition`-style call within --lookback lines
  above it. No guard = from `*` (unguarded).
Machines: one per normalised key (OrderStatus, ORDER_STATUSES, order_status, table orders → order);
  sources with different state sets are reported as set drift. A write is attributed by its enum
  member, its receiver / table / entity hint, then by which machine declares its literal; several
  candidates → `ambiguous` (ranked by same file, directory, module first). A literal a named machine
  does not declare → `written but not declared`. Writes no declaration covers are grouped by entity
  into an `implied` machine: its state set is declared nowhere, so LC-1 is N/A there.
Output: the report on stdout (machines with an edge, a write or a default; the rest on one
  `declared only` line unless --all); `states.tsv`, `edges.tsv`, `writes.tsv`, `report.txt` under --out
  (default: a new temp dir; an --out inside a scanned root is refused). Stderr: the ledger — files per
  lane, unreadable files, declarations not understood.
Exit:   0 the graph was built (findings or not) · 1 usage · 2 cannot build a graph: a root is missing,
        --out is inside a root, no source file was read, or writes exist and no machine could be
        built from them (an empty graph is never printed as clean) · 3 self-test failed.
Reads files; writes only under --out.
"""
import os, re, sys, tempfile, shutil, collections

SKIP_DIRS = {'node_modules', 'vendor', 'dist', 'build', 'out', '.next', '.nuxt', '.output', '.turbo',
             'coverage', '.git', '.venv', 'venv', '__pycache__', 'generated', '__generated__', 'target',
             '.angular', 'storybook-static', '.cache', 'tmp', 'docs', 'ai', '.claude', 'locales', 'locale',
             'i18n', 'translations', 'l10n', 'Pods', '.dart_tool', 'bin', 'obj'}
TEST_DIRS = {'test', 'tests', '__tests__', 'spec', 'specs', 'e2e', 'fixtures', '__fixtures__', 'mocks',
             '__mocks__', 'testdata', 'stories', 'cypress', 'playwright'}
TEST_FILE = re.compile(r'(\.(spec|test|e2e-spec|e2e|stories|story|test-data|fixture|fixtures)\.[^/]+$)|'
                       r'(^|/)(test_[^/]+\.py|[^/]+_test\.(go|py)|conftest\.py|[^/]+Tests?\.(java|kt|cs))$')
EXT = {'.ts': 'js', '.tsx': 'js', '.js': 'js', '.jsx': 'js', '.mjs': 'js', '.cjs': 'js', '.mts': 'js',
       '.cts': 'js', '.vue': 'js', '.py': 'py', '.rb': 'rb', '.php': 'php', '.java': 'jvm', '.kt': 'jvm',
       '.go': 'go', '.cs': 'cs', '.sql': 'sql', '.prisma': 'sql'}
MIGRATION = re.compile(r'(^|/)(migrations?|db/migrate|alembic/versions|Migrations)(/|$)')
SEED = re.compile(r'(^|/)(seeds?|seeders?|fixtures?)(/|$)|(^|/)seed[^/]*\.\w+$')
TERMINAL_WORDS = re.compile(r'(?i)^(?:\w+_)?(delivered|completed?|done|closed|cancell?ed|refunded|rejected|failed|'
                            r'expired|archived|deleted|void(?:ed)?|settled|fulfilled|finali[sz]ed|reversed|abandoned|'
                            r'lost|succeeded|terminated|revoked|churned|written_off|resolved|declined|dead)(?:_\w+)?$')
# States that END a lifecycle when nothing leaves them, but that many machines leave on purpose (order paid → shipped):
# terminal for LC-2 when the graph shows no outgoing edge, never a "reopen" source (django-fsm has no terminal marker).
SOFT_TERMINAL = re.compile(r'(?i)^(?:\w+_)?(paid|credited|approved)(?:_\w+)?$')
# The object literal a key sits in is a response body (no spread of an entity into it): `return { … status: … }`,
# `res.json({ …`, `reply.send({ …`, `JsonResponse({ …`, `jsonify({ …`.
RESPONSE_OBJ = re.compile(r'(?:\breturn\s*\(?\s*|\b(?:res|reply|response|ctx)\s*(?:\.status\([^)]*\))?\s*\.(?:json|send|body)\s*\(\s*|'
                          r'\b(?:JsonResponse|jsonify|Response|Json)\s*\(\s*|\bNextResponse\.json\s*\(\s*)\{(?![^}]*\.\.\.)[^}]*$')
GENERIC_RECV = {'this', 'self', 'row', 'r', 'x', 'o', 'e', 'item', 'entity', 'record', 'data', 'existing', 'current',
                'obj', 'object', 'model', 'doc', 'it', 'instance', 'target', 'updated', 'result', 'entry', 'value', 'v', 's',
                't', 'm', 'n', 'p', 'u', 'next', 'prev', 'fresh', 'saved', 'found', 'loaded', 'agg', 'aggregate', 'state'}
GENERIC_DIRS = {'src', 'lib', 'app', 'apps', 'api', 'services', 'service', 'domain', 'infrastructure', 'application',
                'models', 'model', 'controllers', 'routes', 'handlers', 'use-cases', 'usecases', 'commands', 'core', 'server'}
STATE_NAME = r'\w*(?:Status|State|Phase|Stage|STATUS|STATE|PHASE|STAGE)\w*'
FIELD = (r'_?(?:status|state|phase|stage|[a-z]\w*_(?:status|state|phase|stage)|[a-z]\w*(?:Status|State|Phase|Stage))')
NOT_FIELD = re.compile(r'^(?:useState|setState|getState|prevState|initialState|nextState|readyState|'
                       r'ngState|routerState|formState|uiState|viewState|loadingState|httpStatus|statusCode|'
                       r'responseStatus|exitStatus|healthStatus|appState)$')
LIT = r"""(?:'([\w\-. ]{1,64})'|"([\w\-. ]{1,64})"|:([a-z_]\w{0,63})\b|([A-Z]\w*)(?:\.|::)([A-Za-z_]\w*)\b)"""
PREDICATE_CTX = re.compile(r'(?i)\bwhere\b|\bfilter(?:_by|By)?\s*\(|\bfilters?\s*[:=]|\bfind\w*\s*\(|\bcount\s*\(|'
                           r'\bexists?\s*\(|\$in\b|\$ne\b|\bexclude\s*\(|\bwhere_not\b|\bnot\s*\(|\bquery\s*[:(]|'
                           r'\bexpect\s*\(|\btoBe\w*\(|\bmatch(?:es|ing)?\b|\bselect\s*\(|\bhaving\b|\bget\s*\(|'
                           r'\bfirst\s*\(|\btake\s*\(|\bsearch\b|\bparams\b|\bcriteria\b|\bQ\(')
GUARD_FN = re.compile(r'(?i)\b(can_?transition\w*|assert_?transition\w*|ensure_?transition\w*|transition_?to|'
                      r'allowed_?transitions?|is_?allowed\w*|guard\w*|may_?transition\w*|validate_?transition\w*|'
                      r'next_?statuses|can_?move\w*|assert_?status\w*|ensure_?status\w*|require_?status\w*)\b')
FN_START = re.compile(r'^\s*(?:export\s+)?(?:(?:public|private|protected|static|async|override|internal|suspend|final|abstract)\s+)*(?:def\s+\w+|function\b|func\b|fun\s+\w+|(?!(?:if|for|while|switch|catch|with|elif|else|return|await|new)\b)[A-Za-z_]\w*\s*(?:<[^>]*>)?\s*\([^)]*\)\s*(?::\s*[^{=;]+)?\s*\{|(?:const|let)\s+\w+\s*=\s*(?:async\s*)?\([^)]*\)\s*(?::[^=]+)?=>)')
CMP = re.compile(r'(?:===|!==|==|!=|<>|\bin\b|\bnot in\b|\bIN\b|\bNOT IN\b|\.includes\(|\.include\?|in_array\(|\bis\b|\bcase\b|\bwhen\b)')


def norm_key(name):
    s = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', name or '').lower()
    s = re.sub(r'^(?:e_|enum_)', '', s)
    s = re.sub(r'_?(?:statuses|status|states|state|phases|phase|stages|stage|enum|type|kind|values|list|all)$', '', s)
    s = re.sub(r'_?(?:statuses|status|states|state|phases|phase|stages|stage)$', '', s)
    s = re.sub(r'[^a-z0-9]', '', s)
    if s.endswith('ies'):
        s = s[:-3] + 'y'
    elif s.endswith('sses') or s.endswith('xes'):
        s = s[:-2]
    elif s.endswith('s') and not s.endswith('ss'):
        s = s[:-1]
    return s


def snake(s):
    return re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s).lower()


def lineno(text, idx):
    return text.count('\n', 0, idx) + 1


def balanced(text, i, open_ch, close_ch, limit=200000):
    """Return the index just past the bracket matching text[i]; -1 when unbalanced."""
    depth, q, j, n = 0, None, i, min(len(text), i + limit)
    while j < n:
        c = text[j]
        if q:
            if c == '\\':
                j += 2
                continue
            if c == q:
                q = None
        elif c in '\'"`':
            q = c
        elif c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    return -1


def lits(s):
    out = []
    for m in re.finditer(r"""'([\w\-. ]{1,64})'|"([\w\-. ]{1,64})"|:([a-z_]\w{0,63})\b|%[iw]\[([^\]]*)\]""", s):
        if m.group(4) is not None:
            out.extend(m.group(4).split())
        else:
            out.append(m.group(1) or m.group(2) or m.group(3))
    return out


class Graph:
    def __init__(self):
        self.machines = collections.OrderedDict()   # key -> dict
        self.enum_members = {}                      # EnumName -> {member: value}
        self.alias = {}                             # type/enum name -> machine key
        self.tables = set()                         # transition-table identifiers seen
        self.writes = []
        self.unparsed = []
        self.const_lists = {}                       # IDENT -> [states] (for table values)
        self.subsets = []                           # const lists that are subsets of a machine
        self.maps = {}                              # IDENT -> [raw state values] of a lookup map

    def machine(self, key):
        if key not in self.machines:
            self.machines[key] = {'states': collections.OrderedDict(), 'sources': [], 'sets': [],
                                  'initial': [], 'edges': [], 'terminal_declared': set()}
        return self.machines[key]

    def declare(self, name, states, where, kind):
        states = [s for s in states if s]
        if not states:
            self.unparsed.append((where, kind, name))
            return None
        key = norm_key(name) or name.lower()
        m = self.machine(key)
        for s in states:
            m['states'].setdefault(s, where)
        m['sources'].append('%s %s @ %s' % (kind, name, where))
        m.setdefault('files', set()).add(where.rsplit(':', 1)[0])
        m['sets'].append((kind + ' ' + name, where, tuple(states)))
        self.alias[name] = key
        return key


def walk(roots, include_tests):
    for root in roots:
        for dp, dns, fns in os.walk(root):
            rel = os.path.relpath(dp, root)
            parts = set(rel.replace('\\', '/').split('/'))
            dns[:] = [d for d in dns if d not in SKIP_DIRS and (include_tests or d not in TEST_DIRS)]
            if not include_tests and parts & TEST_DIRS:
                continue
            for fn in fns:
                ext = os.path.splitext(fn)[1]
                if ext not in EXT:
                    continue
                p = os.path.join(dp, fn)
                relp = os.path.relpath(p, root).replace('\\', '/')
                if not include_tests and TEST_FILE.search(relp):
                    continue
                yield root, p, relp, EXT[ext]


# ---------------------------------------------------------------- declarations
def parse_decls(g, text, where_file, lane):
    W = lambda i: '%s:%d' % (where_file, lineno(text, i))
    if lane == 'js':
        for m in re.finditer(r'\benum\s+(' + STATE_NAME + r')\s*\{', text):
            end = balanced(text, m.end() - 1, '{', '}')
            if end < 0:
                g.unparsed.append((W(m.start()), 'ts-enum', m.group(1)))
                continue
            body, mem = text[m.end():end - 1], {}
            for mm in re.finditer(r'(\w+)\s*(?:=\s*(?:\'([^\']*)\'|"([^"]*)"|[^,}\n]+))?\s*(?:,|$)', body, re.M):
                v = mm.group(2) if mm.group(2) is not None else mm.group(3)
                mem[mm.group(1)] = v if v is not None else mm.group(1)
            g.enum_members[m.group(1)] = mem
            g.declare(m.group(1), list(mem.values()), W(m.start()), 'enum')
        for m in re.finditer(r'\btype\s+(' + STATE_NAME + r')\s*=\s*((?:\s*\|?\s*[\'"][\w\-. ]+[\'"])+)', text):
            g.declare(m.group(1), lits(m.group(2)), W(m.start()), 'union')
        for m in re.finditer(r'\b(?:const|let|var)\s+(' + STATE_NAME + r')\s*(?::[^=\n]+)?=\s*\[', text):
            end = balanced(text, m.end() - 1, '[', ']')
            body = text[m.end():end - 1] if end > 0 else ''
            if end < 0 or re.search(r'[{(]', body):
                continue
            g.pending_consts.append((m.group(1), body, W(m.start())))
        for m in re.finditer(r'\b(?:const|let)\s+([A-Z][A-Z0-9_]{2,})\s*(?::[^=\n]+)?=\s*\[', text):
            if re.match(STATE_NAME + '$', m.group(1)):
                continue
            end = balanced(text, m.end() - 1, '[', ']')
            body = text[m.end():end - 1] if end > 0 else ''
            if end > 0 and not re.search(r'[{(]', body) and len(body) < 4000:
                g.pending_consts.append((m.group(1), body, W(m.start())))
        for m in re.finditer(r'\btype\s+(\w+)\s*=\s*\(\s*typeof\s+(\w+)\s*\)\s*\[\s*number\s*\]', text):
            if re.match(STATE_NAME + '$', m.group(2)):
                g.alias.setdefault(m.group(1), norm_key(m.group(2)))
        for m in re.finditer(r'\bconst\s+(' + STATE_NAME + r')\s*=\s*\{', text):
            end = balanced(text, m.end() - 1, '{', '}')
            body = text[m.end():end - 1] if end > 0 else ''
            pairs = re.findall(r'(\w+)\s*:\s*[\'"]([\w\-. ]+)[\'"]\s*,?', body)
            if end > 0 and pairs and not re.search(r'[\[(]', body):
                g.enum_members[m.group(1)] = dict(pairs)
                g.declare(m.group(1), [v for _, v in pairs], W(m.start()), 'object')
    elif lane == 'py':
        for m in re.finditer(r'^class\s+(' + STATE_NAME + r')\s*\(([^)]*\b(?:TextChoices|IntegerChoices|Choices|Enum|StrEnum|IntEnum)\b[^)]*)\)\s*:', text, re.M):
            mem, j = {}, m.end()
            for line in text[j:].split('\n')[1:]:
                if line.strip() == '' or line.lstrip().startswith('#'):
                    continue
                if not line.startswith((' ', '\t')):
                    break
                mm = re.match(r'\s+([A-Z_][A-Z0-9_]*)\s*=\s*\(?\s*(?:\'([^\']*)\'|"([^"]*)"|(auto\(\)|\d+))', line)
                if mm:
                    v = mm.group(2) if mm.group(2) is not None else mm.group(3)
                    mem[mm.group(1)] = v if v is not None else mm.group(1).lower()
            g.enum_members[m.group(1)] = mem
            g.declare(m.group(1), list(mem.values()), W(m.start()), 'enum')
    elif lane == 'rb':
        model = os.path.splitext(os.path.basename(where_file))[0]
        for m in re.finditer(r'\benum\s+:?(\w+)\s*(?::|,)\s*(\{[^}]*\}|\[[^\]]*\]|%i\[[^\]]*\])', text):
            body = m.group(2)
            states = re.findall(r'(\w+)\s*:', body) if body.startswith('{') else lits(body) or re.findall(r':(\w+)', body)
            field = m.group(1)
            g.declare(model if field in ('status', 'state') else field, states, W(m.start()), 'enum')
        aasm = re.search(r'\baasm\b[^\n]*\bdo\b', text)
        if aasm:
            states = [s.group(1) for s in re.finditer(r'^\s*state\s+:(\w+)', text, re.M)]
            extra = [x for s in re.finditer(r'^\s*state\s+((?::\w+\s*,\s*)+:\w+)', text, re.M) for x in re.findall(r':(\w+)', s.group(1))]
            key = g.declare(model, states + extra, W(aasm.start()), 'aasm')
            if key:
                for s in re.finditer(r'^\s*state\s+:(\w+)[^\n]*initial:\s*true', text, re.M):
                    g.machine(key)['initial'].append((s.group(1), W(s.start()), 'aasm initial'))
                for ev in re.finditer(r'^\s*event\s+:(\w+)', text, re.M):
                    end = text.find('\n  end', ev.end())
                    seg = text[ev.end(): end if end > 0 else ev.end() + 2000]
                    for t in re.finditer(r'transitions\s+from:\s*(\[[^\]]*\]|:\w+)\s*,\s*to:\s*:(\w+)', seg):
                        for f in re.findall(r':(\w+)', t.group(1)):
                            g.machine(key)['edges'].append((f, t.group(2), 'fsm', 'aasm :' + ev.group(1), W(ev.start()), ''))
    elif lane == 'php':
        for m in re.finditer(r'\benum\s+(' + STATE_NAME + r')\s*(?::\s*\w+)?\s*\{', text):
            end = balanced(text, m.end() - 1, '{', '}')
            body = text[m.end():end - 1] if end > 0 else ''
            mem = {a: (b or c or a) for a, b, c in re.findall(r'\bcase\s+(\w+)\s*(?:=\s*(?:\'([^\']*)\'|"([^"]*)"))?\s*;', body)}
            g.enum_members[m.group(1)] = mem
            g.declare(m.group(1), list(mem.values()), W(m.start()), 'enum')
    elif lane in ('jvm', 'cs'):
        for m in re.finditer(r'\benum\s+(?:class\s+)?(' + STATE_NAME + r')\s*(?:\([^)]*\))?\s*(?::\s*[\w.<>, ]+)?\s*\{', text):
            end = balanced(text, m.end() - 1, '{', '}')
            body = text[m.end():end - 1] if end > 0 else ''
            body = body.split(';')[0]
            body = re.sub(r'\([^)]*\)|\{[^}]*\}|//[^\n]*|/\*.*?\*/|@\w+', '', body, flags=re.S)
            mem = [x.strip() for x in re.split(r',', body) if re.match(r'^\s*[A-Za-z_]\w*\s*(=\s*\d+\s*)?$', x)]
            mem = [re.sub(r'\s*=.*', '', x) for x in mem]
            g.enum_members[m.group(1)] = {x: x for x in mem}
            g.declare(m.group(1), mem, W(m.start()), 'enum')
    elif lane == 'go':
        for m in re.finditer(r'^type\s+(' + STATE_NAME + r')\s+string\b', text, re.M):
            name = m.group(1)
            mem = dict(re.findall(r'^\s*(\w+)\s+' + re.escape(name) + r'\s*=\s*"([^"]*)"', text, re.M))
            g.enum_members[name] = mem
            for k, v in mem.items():
                g.enum_members.setdefault('', {})[k] = v
            g.declare(name, list(mem.values()), W(m.start()), 'const')
    # SQL shapes: in .sql files and inside migration / schema code strings
    if lane == 'sql' or MIGRATION.search(where_file) or re.search(r'(?i)\bcreate\s+table\b|\bcheck\s*\(', text):
        for m in re.finditer(r'(?i)\bcreate\s+type\s+"?(?:\w+"?\.)?"?(\w+)"?\s+as\s+enum\s*\(([^)]*)\)', text):
            g.declare(m.group(1), lits(m.group(2)), W(m.start()), 'db-enum')
        for m in re.finditer(r'(?i)\bcheck\s*\(\s*\(?\s*"?(\w*(?:status|state|phase|stage)\w*)"?\s*(?:::\w+\s*)?\)?\s+(?:in\s*\(([^)]*)\)|=\s*any\s*\(\s*(?:array\s*)?\[([^\]]*)\])', text):
            tbl = None
            for t in re.finditer(r'(?i)\b(?:create\s+table(?:\s+if\s+not\s+exists)?|alter\s+table(?:\s+only)?(?:\s+if\s+exists)?)\s+"?(?:\w+"?\.)?"?(\w+)"?', text[max(0, m.start() - 6000):m.start()]):
                tbl = t.group(1)
            col = m.group(1)
            name = tbl if col.lower() in ('status', 'state', 'phase', 'stage') and tbl else col
            g.declare(name or col, lits(m.group(2) or m.group(3) or ''), W(m.start()), 'db-check')
        for m in re.finditer(r'(?i)"?(\w*(?:status|state))"?\s+(?:varchar|character varying|text|\w*enum\w*|\w+_status|\w+_state)[^,\n]{0,80}?\bdefault\s+\'(\w+)\'', text):
            tbl = None
            for t in re.finditer(r'(?i)\b(?:create|alter)\s+table(?:\s+if\s+not\s+exists)?\s+"?(?:\w+"?\.)?"?(\w+)"?', text[max(0, m.start() - 6000):m.start()]):
                tbl = t.group(1)
            col = m.group(1)
            key = norm_key(tbl if col.lower() in ('status', 'state') and tbl else col)
            if key:
                g.machine(key)['initial'].append((m.group(2), W(m.start()), 'db default'))


def resolve_consts(g):
    """Second pass over const arrays: literals, enum members (`S.A`) and spreads of other arrays (`...X`)."""
    todo = list(g.pending_consts)
    for _ in range(4):
        left = []
        for name, body, where in todo:
            body_nc = re.sub(r'//[^\n]*|/\*.*?\*/', '', body, flags=re.S)
            states, ok = lits(body_nc), True
            for em in re.finditer(r'\b([A-Z]\w*)\.([A-Za-z_]\w*)\b', body_nc):
                if em.group(1) in g.enum_members:
                    states.append(g.enum_members[em.group(1)].get(em.group(2), em.group(2)))
                else:
                    ok = False
            for sp in re.finditer(r'\.\.\.\s*([A-Za-z_]\w*)', body_nc):
                if sp.group(1) in g.const_lists:
                    states.extend(g.const_lists[sp.group(1)])
                else:
                    ok = False
            if ok:
                g.const_lists[name] = list(dict.fromkeys(states))
            else:
                left.append((name, body, where))
        if len(left) == len(todo):
            break
        todo = left
    for name, body, where in todo:
        if re.match(STATE_NAME + '$', name):
            g.unparsed.append((where, 'const', name))
    for name, body, where in g.pending_consts:
        if name in g.const_lists and re.match(STATE_NAME + '$', name):
            g.declare(name, g.const_lists[name], where, 'const')


def prune_subsets(g):
    """A const array or union whose states are a strict subset of another machine's is a filter list
    (CONFIRMED_STATUSES, TERMINAL_STATUSES), not a machine: kept for guards, dropped as a machine."""
    sets = {k: set(M['states']) for k, M in g.machines.items()}
    for k, M in list(g.machines.items()):
        kinds = {src[0].split(' ')[0] for src in M['sets']}
        if not kinds <= {'const', 'union'}:
            continue
        if any(k != o and sets[k] < sets[o] for o in sets):
            g.subsets.append(k)
            del g.machines[k]
            for name, key in list(g.alias.items()):
                if key == k:
                    del g.alias[name]


# ---------------------------------------------------------------- declared edges
TABLE_NAME = r'(\w*(?:TRANSITION|Transition|transition|REVERSAL|Reversal|reversal|ALLOWED_\w+|allowed[A-Z]\w*|NEXT_\w+|next[A-Z]\w*Status\w*)\w*)'


def resolve(g, token):
    token = token.strip()
    if token[:1] in '[(' and token[-1:] in '])' and len(token) >= 2:
        # a list of literals, enum members (`[S.A, S.B]`, django-fsm `source=[...]`) or const names
        out = []
        for part in token[1:-1].split(','):
            if part.strip():
                out.extend(resolve(g, part))
        return list(dict.fromkeys(out))
    if token in g.const_lists:
        return g.const_lists[token]
    mm = re.match(r'(\w+)(?:\.|::)(\w+)$', token)
    if mm and mm.group(1) in g.enum_members:
        return [g.enum_members[mm.group(1)].get(mm.group(2), mm.group(2))]
    return lits(token)


def parse_edges(g, text, where_file, lane):
    W = lambda i: '%s:%d' % (where_file, lineno(text, i))
    for m in re.finditer(r'\b(?:const|let|var|export\s+const)?\s*' + TABLE_NAME + r'\s*(?::[^=\n]{0,120})?=\s*(?:\w+\()?\s*\{', text):
        name = m.group(1)
        end = balanced(text, m.end() - 1, '{', '}')
        if end < 0:
            g.unparsed.append((W(m.start()), 'table', name))
            continue
        body = text[m.end():end - 1]
        rows = []
        # keys: 'a' / "a" / a / :a / S.A / S::A, and a TS computed key `[S.A]`
        for e in re.finditer(r"""(?:^|[,{\s])(?:'([\w\-. ]+)'|"([\w\-. ]+)"|\[\s*([A-Za-z_]\w*)(?:\.|::)(\w+)\s*\]|:?([A-Za-z_]\w*)(?:(?:\.|::)(\w+))?)\s*(?::|=>)\s*(\[[^\]]*\]|%[iw]\[[^\]]*\]|[A-Za-z_][\w.:]*)""", body):
            en, mem = (e.group(3), e.group(4)) if e.group(3) else (e.group(5), e.group(6))
            src = e.group(1) or e.group(2) or (g.enum_members.get(en, {}).get(mem, mem) if mem else en)
            rows.append((src, e.group(7), m.end() + e.start()))
        if not rows:
            continue
        g.tables.add(name)
        tag = 'reversal' if re.search(r'(?i)revers|back|undo', name) else ''
        g.pending_tables.append((name, rows, tag, W, text))
    if lane == 'js':
        for m in re.finditer(r'\b(?:createMachine|Machine|setup\([^)]*\)\s*\.createMachine)\s*\(\s*\{', text):
            end = balanced(text, m.end() - 1, '{', '}')
            if end < 0:
                g.unparsed.append((W(m.start()), 'xstate', ''))
                continue
            block = text[m.end() - 1:end]
            mid = re.search(r'\bid\s*:\s*[\'"](\w+)[\'"]', block)
            st = re.search(r'\bstates\s*:\s*\{', block)
            if not st:
                continue
            s_end = balanced(block, st.end() - 1, '{', '}')
            body, pos, states, edges, final = block[st.end():s_end - 1], 0, [], [], set()
            for km in re.finditer(r'(?m)(?:^|[,{])\s*[\'"]?(\w+)[\'"]?\s*:\s*\{', body):
                if km.start() < pos:
                    continue
                v_end = balanced(body, km.end() - 1, '{', '}')
                if v_end < 0:
                    break
                val, pos = body[km.end():v_end - 1], v_end
                states.append(km.group(1))
                if re.search(r'\btype\s*:\s*[\'"]final', val):
                    final.add(km.group(1))
                for t in re.finditer(r'\btarget\s*:\s*[\'"]\.?#?([\w.]+)[\'"]|\b\w+\s*:\s*[\'"]\.?#?([\w.]+)[\'"]', val):
                    tgt = (t.group(1) or t.group(2)).split('.')[-1]
                    if t.group(2) and re.match(r'\s*(?:type|id|initial|description|tags?)\b', val[t.start():]):
                        continue
                    edges.append((km.group(1), tgt))
            key = g.declare((mid.group(1) if mid else os.path.splitext(os.path.basename(where_file))[0]) + 'State', states, W(m.start()), 'xstate')
            if key:
                M = g.machine(key)
                M['terminal_declared'] |= final
                ini = re.search(r'\binitial\s*:\s*[\'"](\w+)[\'"]', block)
                if ini:
                    M['initial'].append((ini.group(1), W(m.start()), 'xstate initial'))
                for a, b in edges:
                    if b in M['states']:
                        M['edges'].append((a, b, 'fsm', 'xstate', W(m.start()), ''))
    if lane == 'py':
        for m in re.finditer(r'@transition\s*\(([^)]*)\)', text):
            args = m.group(1)
            src = re.search(r'source\s*=\s*(\[[^\]]*\]|\'[^\']*\'|"[^"]*"|[\w.]+)', args)
            tgt = re.search(r'target\s*=\s*(\'[^\']*\'|"[^"]*"|[\w.]+)', args)
            if src and tgt:
                g.pending_fsm.append((resolve(g, src.group(1)) or ['*'], (resolve(g, tgt.group(1)) or [''])[0], 'django-fsm', W(m.start())))
        for m in re.finditer(r'add_transition\s*\(\s*[\'"]\w+[\'"]\s*,\s*(\[[^\]]*\]|[\'"][^\'"]*[\'"])\s*,\s*[\'"](\w+)[\'"]', text):
            g.pending_fsm.append((lits(m.group(1)), m.group(2), 'transitions', W(m.start())))
        for m in re.finditer(r'[\'"]source[\'"]\s*:\s*(\[[^\]]*\]|[\'"][^\'"]*[\'"])\s*,\s*[\'"]dest[\'"]\s*:\s*[\'"](\w+)[\'"]', text):
            g.pending_fsm.append((lits(m.group(1)), m.group(2), 'transitions', W(m.start())))
    if lane == 'php':
        for m in re.finditer(r'allowTransition\s*\(\s*(\w+)::class\s*,\s*(\w+)::class', text):
            g.pending_fsm.append(([snake(m.group(1))], snake(m.group(2)), 'spatie', W(m.start())))
        for m in re.finditer(r'\bclass\s+(\w+)\s+extends\s+(\w+State)\b', text):
            g.declare(m.group(2), [snake(m.group(1))], W(m.start()), 'spatie')
    if lane in ('jvm', 'cs'):
        for m in re.finditer(r'\.source\(\s*(\w+)\.(\w+)\s*\)\s*\.target\(\s*(\w+)\.(\w+)\s*\)', text):
            g.pending_fsm.append(([m.group(2)], m.group(4), 'spring-statemachine', W(m.start())))
        for m in re.finditer(r'\.Configure\(\s*(\w+)\.(\w+)\s*\)((?:\s*\.(?:Permit|PermitIf|PermitReentry)\w*\([^)]*\))+)', text):
            for t in re.finditer(r'\.Permit\w*\([^,)]*,\s*\w+\.(\w+)', m.group(3)):
                g.pending_fsm.append(([m.group(2)], t.group(1), 'stateless', W(m.start())))
    if lane == 'go':
        for m in re.finditer(r'\{\s*Name\s*:\s*"\w+"\s*,\s*Src\s*:\s*\[\]string\{([^}]*)\}\s*,\s*Dst\s*:\s*"(\w+)"', text):
            g.pending_fsm.append((lits(m.group(1)), m.group(2), 'looplab/fsm', W(m.start())))


def place_by_overlap(g, names, hint=''):
    best, score = None, 0
    hk = norm_key(hint) if hint else ''
    for k, M in g.machines.items():
        s = sum(1 for n in names if n in M['states'])
        if hk and (k == hk or k.startswith(hk) or hk.startswith(k)):
            s += 0.5
        if s > score:
            best, score = k, s
    return best


def finish_edges(g):
    for name, rows, tag, W, text in g.pending_tables:
        froms = [r[0] for r in rows]
        allto = [x for r in rows for x in resolve(g, r[1])]
        key = place_by_overlap(g, froms + allto, re.sub(r'(?i)_?(transitions?|reversals?|allowed|next)_?', '', name))
        if not key:
            key = g.declare(name, list(dict.fromkeys(froms + allto)), W(rows[0][2]), 'table-implied')
        M = g.machine(key)
        for src, val, idx in rows:
            tgts = resolve(g, val)
            if not tgts and re.match(r'^\[\s*\]$', val.strip()):
                M['terminal_declared'].add(src)
                continue
            if not tgts and re.match(r'^[A-Za-z_]\w*$', val.strip()) and val.strip() not in g.const_lists:
                M['edges'].append((src, '?' + val.strip(), 'table', name, W(idx), 'unresolved'))
                continue
            for t in tgts:
                M['edges'].append((src, t, 'table', name, W(idx), tag))
    for froms, to, lib, where in g.pending_fsm:
        key = place_by_overlap(g, [f for f in froms if f != '*'] + [to])
        if not key:
            continue
        for f in froms:
            g.machine(key)['edges'].append((f, to, 'fsm', lib, where, ''))


# ---------------------------------------------------------------- writes
def collect_maps(g, text):
    """Lookup maps whose values are states (`CARRIER_STATUS_MAP = {"RTO": ShipmentStatus.RETURNED, …}`): a write
    `x.status = CARRIER_STATUS_MAP[…]` writes each of its values. Scalar values only (a list value is a table)."""
    for m in re.finditer(r'(?m)^\s*(?:export\s+)?(?:(?:const|let|var)\s+)?([A-Za-z_]\w*)\s*(?::[^=\n]{0,120})?=\s*(?:Object\.freeze\()?\{', text):
        if re.match(TABLE_NAME + '$', m.group(1)):
            continue
        end = balanced(text, m.end() - 1, '{', '}')
        if end < 0 or end - m.end() > 8000:
            continue
        body = re.sub(r'//[^\n]*|#[^\n]*', '', text[m.end():end - 1])
        pairs = re.findall(r"""(?:'[^'\n]*'|"[^"\n]*"|[\w.\[\]]+)\s*(?::|=>)\s*('[\w\-. ]{1,64}'|"[\w\-. ]{1,64}"|[A-Z]\w*(?:\.|::)\w+)\s*,?""", body)
        rest = re.sub(r"""(?:'[^'\n]*'|"[^"\n]*"|[\w.\[\]]+)\s*(?::|=>)\s*('[\w\-. ]{1,64}'|"[\w\-. ]{1,64}"|[A-Z]\w*(?:\.|::)\w+)\s*,?""", '', body)
        if len(pairs) >= 2 and not rest.strip():
            g.maps[m.group(1)] = list(dict.fromkeys(pairs))


def map_values(g, name):
    out = []
    for tok in g.maps.get(name, []):
        mm = re.match(r'([A-Z]\w*)(?:\.|::)(\w+)$', tok)
        if mm:
            v, enum = value_of(g, (None, None, None, mm.group(1), mm.group(2)))
        else:
            v, enum = tok[1:-1], None
        if v:
            out.append((v, enum))
    return list(dict.fromkeys(out))


def value_of(g, m_lit):
    a, b, c, enum, member = m_lit
    if enum:
        mem = g.enum_members.get(enum)
        if mem is not None:
            return mem.get(member, member), enum
        if enum in g.alias:
            return member, enum
        return None, None
    return (a or b or c), None


def parse_writes(g, text, root_rel, lane, lookback):
    lines = text.split('\n')
    tag = 'migration' if MIGRATION.search(root_rel) else ('seed' if SEED.search(root_rel) else '')
    path_hint = root_rel.lower()

    def cmp_states(L, fld, recv=''):
        out, f = set(), r'(?P<f>' + re.escape(fld) + r')'
        own = (recv or '').split('.')[-1].lstrip('$')

        def mine(m):
            # A comparison on ANOTHER receiver's field (`payout.status != X` above `settlement.status = Y`) guards
            # nothing here; a bare field or the same receiver does.
            if not own:
                return True
            r = re.search(r'([\w$]+)\s*(?:\?\.|\.|->)\s*$', L[:m.start('f')])
            if not r:
                return True
            other = r.group(1).lstrip('$')
            return other == own or (other in ('this', 'self') and own in ('this', 'self'))
        for m in re.finditer(r'\b' + f + r'\b\s*(?:===|!==|==|!=|<>)\s*' + LIT, L):
            if mine(m):
                v, _ = value_of(g, m.groups()[1:6])
                out.add(v)
        for m in re.finditer(LIT + r'\s*(?:===|!==|==|!=)\s*[\w$.?]*\b' + f + r'\b', L):
            if mine(m):
                v, _ = value_of(g, m.groups()[0:5])
                out.add(v)
        for m in re.finditer(r'\[([^\]]*)\]\s*\.includes\(\s*[\w$.?]*\b' + f + r'\b', L):
            if mine(m):
                out.update(resolve(g, '[' + m.group(1) + ']'))
        for m in re.finditer(r'\b([A-Za-z_]\w*)\s*\.(?:includes|has|include\?)\(\s*[\w$.?]*\b' + f + r'\b', L):
            if mine(m):
                out.update(g.const_lists.get(m.group(1), []))
        for m in re.finditer(r'(?i)\b' + f + r'\b"?\s*(?:__in\s*=|\bnot\s+in\b|\bin\b)\s*[(\[](?P<v>[^)\]]*)[)\]]', L):
            if mine(m):
                out.update(resolve(g, '[' + m.group('v') + ']'))
        for m in re.finditer(r'in_array\(\s*\$[\w>-]*' + f + r'\b\s*,\s*\[([^\]]*)\]', L):
            out.update(lits(m.group(2)))
        out.discard(None)
        return out

    def guard_for(ln, field_name, sql_where=None, recv=''):
        fs, kind = set(), ''
        if sql_where:
            fs = cmp_states(sql_where, field_name) | {x for gm in re.finditer(r'(?i)"?' + re.escape(field_name) + r'"?\s*(?:=|<>|!=)\s*\'([\w\-. ]+)\'', sql_where) for x in [gm.group(1)]}
            if fs:
                return 'where:' + '|'.join(sorted(fs))
        lo = max(0, ln - lookback)
        for j in range(ln, lo - 1, -1):
            L = lines[j]
            if any(t in L for t in g.tables):
                kind = 'table'
            if GUARD_FN.search(L):
                kind = kind or 'fn'
            fs |= cmp_states(L, field_name, recv)
            if FN_START.search(L):
                break   # the enclosing function starts here: a guard above it guards another function
        if fs:
            return 'cmp:' + '|'.join(sorted(fs))
        return kind or ''

    offs = [0]
    for L0 in lines:
        offs.append(offs[-1] + len(L0) + 1)

    def predicate_arg(pos):
        """True when pos sits in an argument of an update call that is NOT its last argument: the WHERE object of
        `nativeUpdate(Entity, where, data)`, `update(criteria, data)`, `updateOne(filter, update)`."""
        lo = max(0, pos - 600)
        for c in reversed(list(re.finditer(r'\b(?:nativeUpdate|update(?:One|Many|All|_one|_many|_all)?|findOneAndUpdate|findByIdAndUpdate)\s*\(', text[lo:pos]))):
            op = lo + c.end() - 1
            end = balanced(text, op, '(', ')')
            if end < 0 or end <= pos:
                continue
            depth, q, j, commas = 0, None, op + 1, []
            while j < end - 1:
                ch = text[j]
                if q:
                    if ch == '\\':
                        j += 2
                        continue
                    if ch == q:
                        q = None
                elif ch in '\'"`':
                    q = ch
                elif ch in '([{':
                    depth += 1
                elif ch in ')]}':
                    depth -= 1
                elif ch == ',' and depth == 0:
                    commas.append(j)
                j += 1
            if commas and not text[commas[-1] + 1:end - 1].strip():
                commas.pop()                             # a trailing comma
            return sum(1 for x in commas if x < pos) < len(commas)
        return False

    def record(ln, field_name, recv, val, enum, kind, guard, hint=''):
        g.writes.append({'file': '%s:%d' % (root_rel, ln + 1), 'field': field_name.lstrip('_'), 'recv': recv or '', 'to': val,
                         'enum': enum or '', 'kind': kind, 'guard': guard, 'tag': tag, 'hint': hint, 'path': path_hint})

    # SQL updates (multi-line, case-insensitive), inside strings or .sql files
    for m in re.finditer(r'(?is)\bupdate\s+"?(?:\w+"?\.)?"?(\w+)"?\s+(?:as\s+\w+\s+|\w+\s+)?set\b(.{0,400}?)(?:;|`|\)\s*;|$|\bwhere\b(.{0,400}?)(?:;|`|\n\s*\n|$))', text):
        setc = m.group(2) or ''
        for sm in re.finditer(r'(?i)(?:^|[\s,.])"?(' + FIELD + r')"?\s*=\s*\'([\w\-. ]+)\'', setc):
            ln = lineno(text, m.start()) - 1
            record(ln, sm.group(1), m.group(1), sm.group(2), None, 'sql', guard_for(ln, sm.group(1), m.group(3) or ''), hint=m.group(1))
    if lane == 'sql':
        return
    for i, L in enumerate(lines):
        s = L.strip()
        if not s or s.startswith(('//', '#', '*', '/*', '--')) or 'import ' in s[:7]:
            continue
        # member assignment
        for m in re.finditer(r'(?:([\w$]+(?:\.[\w$]+)*)(?:\?\.|\.|->))(' + FIELD + r')\s*=(?![=>~])\s*' + LIT, L):
            fld = m.group(2)
            if NOT_FIELD.match(fld):
                continue
            val, enum = value_of(g, m.groups()[2:7])
            if val:
                record(i, fld, m.group(1), val, enum, 'assign', guard_for(i, fld, recv=m.group(1)))
        # member assignment through a lookup map: every value of the map is a target
        for m in re.finditer(r'(?:([\w$]+(?:\.[\w$]+)*)(?:\?\.|\.|->))(' + FIELD + r')\s*=(?![=>~])\s*([A-Za-z_]\w*)\s*(?:\[|\?\.\[|\.get\()', L):
            if NOT_FIELD.match(m.group(2)) or m.group(3) not in g.maps:
                continue
            gd = guard_for(i, m.group(2), recv=m.group(1))
            for val, enum in map_values(g, m.group(3)):
                record(i, m.group(2), m.group(1), val, enum, 'map', gd)
        # setters
        for m in re.finditer(r'\.set(Status|State|Phase|Stage|\w+Status|\w+State)\(\s*' + LIT + r'\s*\)', L):
            val, enum = value_of(g, m.groups()[1:6])
            if val:
                record(i, m.group(1)[0].lower() + m.group(1)[1:], '', val, enum, 'setter', guard_for(i, 'status'))
        # rails update_column / update_attribute
        for m in re.finditer(r'\bupdate_(?:column|attribute)\(\s*:(' + FIELD + r')\s*,\s*' + LIT, L):
            val, enum = value_of(g, m.groups()[1:6])
            if val:
                record(i, m.group(1), '', val, enum, 'rails', guard_for(i, m.group(1)))
        # defaults: a class property, a model field default, an ORM column default
        for m in re.finditer(r'^\s+(?:(?:public|private|protected|readonly|declare)\s+)*(' + FIELD + r')\s*[!?]?\s*(?::\s*[\w.|\' ]+?)?\s*=\s*' + LIT + r'\s*;?\s*$', L):
            if lane in ('js', 'jvm', 'cs', 'php') and not NOT_FIELD.match(m.group(1)):
                val, enum = value_of(g, m.groups()[1:6])
                if val:
                    record(i, m.group(1), '', val, enum, 'default', '', os.path.splitext(os.path.basename(root_rel))[0].split('.')[0])
        for m in re.finditer(r'\b(' + FIELD + r')\s*=\s*(?:models\.\w+|Column|mapped_column|sa\.Column|Field)\([^\n]*?\bdefault\s*=\s*' + LIT, L):
            val, enum = value_of(g, m.groups()[1:6])
            if val:
                record(i, m.group(1), '', val, enum, 'default', '', os.path.splitext(os.path.basename(root_rel))[0])
        for m in re.finditer(r'@(?:Property|Column|Enum)\([^\n]*\bdefault\s*:\s*' + LIT, L):
            nxt = re.match(r'\s*(?:(?:public|private|protected|readonly|declare)\s+)*(' + FIELD + r')\s*[!?]?\s*[:=;]', lines[i + 1] if i + 1 < len(lines) else '')
            val, enum = value_of(g, m.groups()[0:5])
            if val and nxt and not NOT_FIELD.match(nxt.group(1)):
                record(i, nxt.group(1), '', val, enum, 'default', '', os.path.splitext(os.path.basename(root_rel))[0].split('.')[0])
        is_default = False
        # object / hash / dict keys, python kwargs
        keys = list(re.finditer(r"""(?:(?<![\w.$])|['"])(""" + FIELD + r""")['"]?\s*(?::(?!:)|=>|=(?![=>]))\s*""" + LIT, L))
        for n, m in enumerate(keys):
            fld = m.group(1)
            if NOT_FIELD.match(fld):
                continue
            pre = L[:m.start()]
            after = L[m.end():m.end() + 8]
            if re.search(r'^\s*\|', after) or re.search(r'\btype\s+\w+\s*=|\binterface\b|\|\s*$', pre) or re.search(r':\s*[\'"][^\'"]*[\'"]\s*\|', L[m.start():]):
                continue
            if lane == 'py' and re.search(r'(?<![\w.])' + re.escape(fld) + r'\s*=', m.group(0)) and not re.search(r'[(,]\s*$', pre):
                continue   # a python assignment statement, not a kwarg (member assignment handled above)
            sep = re.match(r"""['"]?""" + FIELD + r"""['"]?\s*(:|=>|=)""", m.group(0))
            if lane != 'py' and sep and sep.group(1) == '=':
                continue   # an assignment statement (member assignments and defaults are read above), not a payload key
            ctx = ' '.join(lines[max(0, i - 3):i]) + ' ' + pre
            last_where = max(ctx.rfind('where'), ctx.rfind('filter'), ctx.rfind('find'))
            last_data = max(ctx.rfind('data'), ctx.rfind('set:'), ctx.rfind('values'), ctx.rfind('update'), ctx.rfind('create'), ctx.rfind('insert'), ctx.rfind('assign'), ctx.rfind('save'), ctx.rfind('persist'))
            val, enum = value_of(g, m.groups()[1:6])
            if not val:
                continue
            if len(keys) > 1 and n < len(keys) - 1 and re.search(r'native(?:Update|Delete)|update(?:Many)?\s*\(|\.where\(', ' '.join(lines[max(0, i - 2):i + 1])):
                continue   # the first status key of an update(where, data) call is the predicate
            if predicate_arg(offs[i] + m.start(1)):
                continue   # the key sits in the WHERE argument (the data argument may carry no status at all)
            if PREDICATE_CTX.search(ctx) and last_where > last_data:
                continue
            if re.search(r'\b(?:if|while|return|case|when)\b[^\n]*(?:===|!==|==|!=)', pre):
                continue
            if RESPONSE_OBJ.search(ctx):
                continue   # `return { status: 'queued' }`, `res.json({ status })`: a response body, not a write
            hint = ''
            hm = re.search(r'(?:nativeUpdate|create|insert|update|upsert|assign|persist|save|new)\s*\(\s*(?:new\s+)?([A-Z]\w*)|\b([A-Z]\w*)(?:\.objects|::where|\.where|\.create|::create)|prisma\.(\w+)\.', ' '.join(lines[max(0, i - 4):i + 1]))
            if hm:
                hint = hm.group(1) or hm.group(2) or hm.group(3)
            if len(keys) > 1 and n == len(keys) - 1:
                prior = sorted(set(filter(None, (value_of(g, k.groups()[1:6])[0] for k in keys[:-1] if k.group(1) == fld))))
                guard = ('cmp:' + '|'.join(prior)) if prior else guard_for(i, fld)
            else:
                guard = guard_for(i, fld)
            record(i, fld, '', val, enum, 'default' if is_default else 'payload', guard, hint)


def attribute(g):
    by_state = collections.defaultdict(set)
    for k, M in g.machines.items():
        for s in M['states']:
            by_state[s].add(k)
    for w in g.writes:
        cands = set()
        if w['enum'] and w['enum'] in g.alias:
            cands = {g.alias[w['enum']]}
        else:
            prefix = re.sub(r'(?i)_?(status|state|phase|stage)$', '', w['field'])
            recv = w['recv'].split('.')[-1] if w['recv'] else ''
            hints = [prefix, recv + prefix] if prefix else [w['hint'], recv]
            hk = {norm_key(h) for h in hints if h and norm_key(h)}
            named = {k for k in g.machines if k in hk}
            have = by_state.get(w['to'], set())
            if not named and not prefix:
                # A named receiver or entity (`article.status = 'draft'`, `create(Article, …)`) that no machine matches
                # does not borrow a machine through its literal alone: only a related machine may take it.
                subj = recv.lstrip('$_') if recv else ('' if w['recv'] else w['hint'])
                spec = norm_key(subj) if subj and subj.lower() not in GENERIC_RECV else ''
                if spec:
                    have = {k for k in have if spec == k or (min(len(spec), len(k)) >= 3 and (spec in k or k in spec))}
            cands = (named & have) or (have if not named else set())
            if not cands and named:
                w['note'] = 'undeclared-in-%s' % sorted(named)[0]
            if len(cands) > 1:
                wf = w['file'].rsplit(':', 1)[0]
                wd, wm = os.path.dirname(wf), '/'.join(wf.split('/')[:2])

                def rank(k):
                    fs = g.machines[k].get('files', set())
                    r = 3 if wf in fs else 2 if any(os.path.dirname(f) == wd for f in fs) else 1 if any('/'.join(f.split('/')[:2]) == wm for f in fs) else 0
                    return r + (0.5 if k in re.sub(r'[^a-z0-9]', '', w['path']) else 0)
                ranked = sorted(cands, key=rank, reverse=True)
                if rank(ranked[0]) > rank(ranked[1]):
                    cands = {ranked[0]}
        if len(cands) == 1:
            w['machine'] = next(iter(cands))
            w['map'] = 'enum' if w['enum'] else 'unique'
        elif len(cands) > 1:
            w['machine'] = ','.join(sorted(cands))
            w['map'] = 'ambiguous'
            for k in cands:
                g.machine(k).setdefault('amb_targets', set()).add(w['to'])
        else:
            w['machine'] = ''
            w['map'] = 'undeclared'
        if w['map'] in ('enum', 'unique') and w['kind'] == 'default':
            g.machine(w['machine'])['initial'].append((w['to'], w['file'], 'default'))
            continue
        if w['map'] in ('enum', 'unique'):
            M = g.machine(w['machine'])
            frm = w['guard'].split(':', 1)[1].split('|') if w['guard'].startswith(('cmp:', 'where:')) else ['*']
            for f in frm:
                if f == w['to']:
                    continue
                M['edges'].append((f, w['to'], 'write' + ('-' + w['tag'] if w['tag'] else ''), w['guard'] or 'unguarded', w['file'], w['field']))


def imply(g):
    """Writes no declaration lists, grouped by entity: a machine implied from its writes (the state set is undeclared)."""
    groups = collections.OrderedDict()
    for w in g.writes:
        if w['map'] != 'undeclared' or w.get('note'):
            continue
        prefix = re.sub(r'(?i)_?(status|state|phase|stage)$', '', w['field'])
        fpath = w['file'].rsplit(':', 1)[0]
        base = os.path.basename(os.path.dirname(fpath))
        if base.lower() in GENERIC_DIRS or not base:
            base = re.split(r'[.\-_]', os.path.basename(fpath))[0]
        key = norm_key(prefix) or norm_key(w['hint']) or norm_key(w['recv'].split('.')[-1] if w['recv'] and w['recv'] not in ('this', 'self', 'row', 'r', 'x', 'o', 'e', 'item', 'entity', 'record', 'data') else '') or norm_key(base) or 'unnamed'
        groups.setdefault(key, []).append(w)
    for key, ws in groups.items():
        k = key if key not in g.machines else key + '~implied'
        M = g.machine(k)
        M['implied'] = True
        M['sources'].append('implied from %d writes (no declaration lists these states)' % len(ws))
        for w in ws:
            M['states'].setdefault(w['to'], w['file'])
            M.setdefault('files', set()).add(w['file'].rsplit(':', 1)[0])
            w['machine'], w['map'] = k, 'implied'
            if w['kind'] == 'default':
                M['initial'].append((w['to'], w['file'], 'default'))
                continue
            frm = w['guard'].split(':', 1)[1].split('|') if w['guard'].startswith(('cmp:', 'where:')) else ['*']
            for f in frm:
                if f != w['to']:
                    M['edges'].append((f, w['to'], 'write' + ('-' + w['tag'] if w['tag'] else ''), w['guard'] or 'unguarded', w['file'], w['field']))
                    if f != '*':
                        M['states'].setdefault(f, w['file'])


def report(g, declared_edges, machine_filter):
    out, quiet = [], []
    for k, M in g.machines.items():
        if machine_filter and k != machine_filter:
            continue
        if not machine_filter and not SHOW_ALL[0] and not M['edges'] and not M['initial']:
            quiet.append(k)
            continue
        states = list(M['states'])
        edges = [e for e in M['edges'] if not e[1].startswith('?')]
        targets = {e[1] for e in edges if not e[2].startswith('write-')}
        mig_targets = {e[1] for e in edges if e[2].startswith('write-')}
        inits = {i[0] for i in M['initial']}
        if not inits and states:
            first = M['sets'][0][2][0] if M['sets'] else states[0]
            inits = {first}
            init_note = '%s (first declared member; no default found — unconfirmed)' % first
        else:
            init_note = ', '.join('%s (%s @ %s)' % (i[0], i[2], i[1]) for i in M['initial'])
        unguarded = [e for e in edges if e[0] == '*' and e[2].startswith('write')]
        out_from = collections.defaultdict(set)
        for e in edges:
            if e[0] != '*':
                out_from[e[0]].add(e[1])
        n_tab = sum(1 for e in edges if e[2] in ('table', 'fsm'))
        n_wr = sum(1 for e in edges if e[2].startswith('write'))
        amb_t = M.get('amb_targets', set())
        unreach = [s for s in states if s not in targets and s not in inits and s not in mig_targets and s not in amb_t]
        only_amb = [s for s in states if s not in targets and s not in inits and s not in mig_targets and s in amb_t]
        only_mig = [s for s in states if s not in targets and s not in inits and s in mig_targets]
        undeclared = [w for w in g.writes if w['map'] == 'undeclared' and w.get('note') == 'undeclared-in-' + k]
        no_out = [s for s in states if not out_from.get(s)]
        terminal = [s for s in no_out if s in M['terminal_declared'] or TERMINAL_WORDS.match(s) or SOFT_TERMINAL.match(s)]
        traps = [s for s in no_out if s not in terminal]
        reopen = sorted({(e[0], e[1], e[3]) for e in edges if e[0] in M['terminal_declared'] or (TERMINAL_WORDS.match(e[0]) and e[0] != '*')})
        if not (n_tab or n_wr or unguarded):
            trap_line = 'undetermined (no edge source found: no table, no FSM config, no write attributed)'
        elif unguarded and not n_tab:
            trap_line = 'undetermined (%d unguarded writes: any state may leave)' % len(unguarded)
        else:
            trap_line = ', '.join(traps) or 'none'
        out.append('## machine %s' % k)
        out.append('sources: ' + ' · '.join(M['sources']))
        if M.get('implied'):
            out.append('implied: the state set is declared nowhere (no enum, union, CHECK or table) — LC-1 cannot be judged; the set is the writes')
            unreach_override = True
        else:
            unreach_override = False
        if len({s[2] for s in M['sets']}) > 1:
            base = set(M['sets'][0][2])
            for name, where, st in M['sets'][1:]:
                d1, d2 = sorted(base - set(st)), sorted(set(st) - base)
                if d1 or d2:
                    out.append('set drift: %s vs %s @ %s — only first: %s · only second: %s' % (M['sets'][0][0], name, where, ', '.join(d1) or '-', ', '.join(d2) or '-'))
        out.append('states (%d): %s' % (len(states), ', '.join(states)))
        out.append('initial: %s' % init_note)
        out.append('edges: declared %d (table/fsm) · writes %d (unguarded %d)' % (n_tab, n_wr, len(unguarded)))
        out.append('LC-1 unreachable (declared, never a target, not initial): %s' % ('N/A (implied machine)' if unreach_override else (', '.join(unreach) or 'none')))
        if only_amb:
            out.append('LC-1 reached only by an ambiguous write (read it): %s' % ', '.join(only_amb))
        if only_mig:
            out.append('LC-1 reached only by a migration or seed write: %s' % ', '.join(only_mig))
        if undeclared:
            out.append('LC-1 written but not declared: %s' % '; '.join('%s @ %s' % (w['to'], w['file']) for w in undeclared[:12]))
        out.append('LC-2 terminal (no outgoing; declared [] / final / terminal name): %s' % (', '.join(terminal) or 'none'))
        out.append('LC-2 traps (no outgoing, not terminal): %s' % trap_line)
        if states and not terminal and not traps and n_tab:
            out.append('LC-2 no terminal state: every state has an outgoing edge')
        if reopen:
            out.append('reopen (edges leaving a terminal state): %s' % '; '.join('%s→%s (%s)' % r for r in reopen[:12]))
        if unguarded:
            out.append('unguarded writes: %s' % '; '.join('→%s @ %s' % (e[1], e[4]) for e in unguarded[:15]) + (' …+%d' % (len(unguarded) - 15) if len(unguarded) > 15 else ''))
        unres = [e for e in M['edges'] if e[1].startswith('?')]
        if unres:
            out.append('unresolved table values: %s' % ', '.join(sorted({e[1][1:] for e in unres})))
        if declared_edges is not None:
            if any(sec for sec, _, _ in declared_edges):
                # sections name their machine: an Order edge is never an LC-3 row on payment because both know `paid`
                mine = [(a, b) for sec, a, b in declared_edges if sec is None or section_matches(sec, k)]
            else:
                mine = [(a, b) for _, a, b in declared_edges]
            dec = {(a, b) for a, b in mine if a in M['states'] or b in M['states']}
            built = {(e[0], e[1]) for e in edges if e[0] != '*' and (e[2] in ('table', 'fsm') or e[3].startswith(('cmp:', 'where:')))}
            if dec:
                out.append('LC-3 declared, not built: %s' % (', '.join('%s→%s' % x for x in sorted(dec - built)) or 'none'))
                out.append('LC-3 built, not declared: %s' % (', '.join('%s→%s' % x for x in sorted(built - dec)) or 'none'))
                ds = {x for e in dec for x in e} - set(M['states'])
                if ds:
                    out.append('LC-3 declared states missing from the code: %s' % ', '.join(sorted(ds)))
        out.append('')
    if g.subsets:
        out.append('subset lists (filters of a larger machine, used as guards, not machines): %d — %s%s' % (
            len(g.subsets), ', '.join(g.subsets[:30]), ' …' if len(g.subsets) > 30 else ''))
    if quiet:
        out.append('declared only (no table, no FSM, no attributed write, no default): %d machines — %s%s' % (
            len(quiet), ', '.join(quiet[:40]), ' …' if len(quiet) > 40 else ''))
    amb = [w for w in g.writes if w['map'] == 'ambiguous']
    und = [w for w in g.writes if w['map'] == 'undeclared' and not w.get('note')]
    out.append('writes: %d total · attributed %d · ambiguous %d · implied %d · undeclared in a declared machine %d' % (
        len(g.writes), sum(1 for w in g.writes if w['map'] in ('enum', 'unique')), len(amb),
        sum(1 for w in g.writes if w['map'] == 'implied'), sum(1 for w in g.writes if w.get('note'))))
    if amb:
        out.append('ambiguous: ' + '; '.join('%s→%s [%s]' % (w['file'], w['to'], w['machine']) for w in amb[:10]))
    return '\n'.join(out)


SECTION_NOISE = {'lifecycle', 'lifecycles', 'flow', 'flows', 'state', 'states', 'status', 'statuses', 'machine', 'machines',
                 'workflow', 'workflows', 'diagram', 'transitions', 'the', 'of', 'and', 'an', 'a'}


def section_key(heading):
    words = [w for w in re.findall(r'[A-Za-z][\w-]*', heading) if w.lower() not in SECTION_NOISE]
    return norm_key('_'.join(words)) if words else ''


def section_matches(sec, k):
    k = k.split('~')[0]
    return sec == k or (min(len(sec), len(k)) >= 3 and (k.startswith(sec) or sec.startswith(k)))


def parse_declared(path):
    """[(section key or None, from, to)]: a `## <Machine>` heading scopes the edges under it to that machine."""
    edges, sec = [], None
    for line in open(path, encoding='utf-8', errors='replace'):
        h = re.match(r'^(#{1,6})\s+(.*)', line)
        if h:
            sec = (section_key(h.group(2)) or None) if len(h.group(1)) >= 2 else None
            continue
        if not re.search(r'→|->|-->|=>', line):
            continue
        chain = re.split(r'\s*(?:-->|→|->|=>)\s*', re.sub(r'[`*|]', ' ', line.strip()))
        chain = [re.findall(r'[A-Za-z_][\w-]*', c) for c in chain]
        for a, b in zip(chain, chain[1:]):
            for x in (a[-1:] or []):
                for y in b[:1] + b[1:] if len(b) <= 4 else b[:1]:
                    edges.append((sec, x, y))
    return edges


def run(roots, out_dir, declared, machine, lookback, include_tests, quiet=False):
    for r in roots:
        if not os.path.isdir(r):
            sys.stderr.write('status-graph: root not found: %s\n' % r)
            return 2, ''
    absout = os.path.realpath(out_dir) if out_dir else None
    for r in roots:
        if absout and (absout + os.sep).startswith(os.path.realpath(r) + os.sep):
            sys.stderr.write('status-graph: --out %s is inside the scanned root %s — refused\n' % (out_dir, r))
            return 2, ''
    g = Graph()
    g.pending_tables, g.pending_fsm, g.pending_consts = [], [], []
    files, lanes, unreadable = [], collections.Counter(), 0
    for root, p, rel, lane in walk(roots, include_tests):
        try:
            with open(p, encoding='utf-8') as fh:
                text = fh.read()
        except (UnicodeDecodeError, OSError):
            unreadable += 1
            continue
        if len(text) > 2000000:
            unreadable += 1
            continue
        files.append((rel, lane, text))
        lanes[lane] += 1
    if not files:
        sys.stderr.write('status-graph: no source file read under %s — cannot build a graph\n' % ' '.join(roots))
        return 2, ''
    for rel, lane, text in files:
        parse_decls(g, text, rel, lane)
    resolve_consts(g)
    prune_subsets(g)
    for rel, lane, text in files:
        parse_edges(g, text, rel, lane)
    finish_edges(g)
    for rel, lane, text in files:
        if lane != 'sql' and re.search(r'(?i)status|state|phase|stage', text):
            collect_maps(g, text)
    for rel, lane, text in files:
        if re.search(r'(?i)\b(?:status|state|phase|stage)\b|Status\b|State\b', text):
            parse_writes(g, text, rel, lane, lookback)
    attribute(g)
    imply(g)
    sys.stderr.write('status-graph: files %d (%s) · unreadable %d · machines %d · writes %d · not understood %d\n' % (
        len(files), ', '.join('%s %d' % kv for kv in sorted(lanes.items())), unreadable, len(g.machines), len(g.writes), len(g.unparsed)))
    for u in g.unparsed[:20]:
        sys.stderr.write('  not understood: %s %s %s\n' % u)
    if not g.machines and g.writes:
        sys.stderr.write('status-graph: %d status writes but no declaration parsed — the graph cannot be built (read the declarations by hand)\n' % len(g.writes))
        return 2, ''
    dec = None
    if declared:
        try:
            dec = parse_declared(declared)
        except OSError:
            sys.stderr.write('status-graph: --declared unreadable: %s\n' % declared)
            return 2, ''
    rep = report(g, dec, machine)
    if out_dir is None:
        out_dir = tempfile.mkdtemp(prefix='status-graph.')
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, 'states.tsv'), 'w') as fh:
        fh.write('machine\tstate\tsource\n')
        for k, M in g.machines.items():
            for s, w in M['states'].items():
                fh.write('%s\t%s\t%s\n' % (k, s, w))
    with open(os.path.join(out_dir, 'edges.tsv'), 'w') as fh:
        fh.write('machine\tfrom\tto\tkind\tguard_or_source\tsite\tnote\n')
        for k, M in g.machines.items():
            for e in M['edges']:
                fh.write('%s\t%s\n' % (k, '\t'.join(e)))
    with open(os.path.join(out_dir, 'writes.tsv'), 'w') as fh:
        fh.write('site\tfield\tto\tmachine\tmap\tguard\tkind\ttag\n')
        for w in g.writes:
            fh.write('\t'.join([w['file'], w['field'], w['to'], w['machine'], w['map'], w['guard'] or 'unguarded', w['kind'], w['tag']]) + '\n')
    with open(os.path.join(out_dir, 'report.txt'), 'w') as fh:
        fh.write(rep + '\n')
    if not quiet:
        print(rep)
        print('out: %s' % out_dir)
    return 0, rep


SELF = {
    'api/src/orders/order.vocab.ts': """
export const ORDER_STATUSES = ['created', 'paid', 'shipped', 'delivered', 'cancelled', 'legacy_hold'] as const;
export type OrderStatus = (typeof ORDER_STATUSES)[number];
export const ORDER_TRANSITIONS: Record<string, readonly string[]> = {
  created: ['paid', 'cancelled'],
  paid: ['shipped', 'cancelled'],
  shipped: ['delivered'],
  delivered: [],
  cancelled: [],
};
""",
    'api/src/orders/order.service.ts': """
import { ORDER_TRANSITIONS } from './order.vocab';
export class OrderService {
  async pay(order) {
    if (order.status !== 'created') throw new Error('illegal');
    order.status = 'paid';
  }
  async list() { return this.repo.find({ where: { status: 'shipped' } }); }
  type X = { status: 'paid' | 'created' };
  async ship(id) { await this.em.nativeUpdate(Order, { id, status: 'paid' }, { status: 'shipped' }); }
  async force(order) { order.status = 'cancelled'; }
  async ghost(order) { order.status = 'teleported'; }
  async editNote(id) { await this.em.nativeUpdate(Order, { id, status: 'created' }, { note: 'x' }); }
}
""",
    'api/src/help/article.service.ts': """
export class ArticleService {
  async archive(article) { article.status = 'shipped'; }
}
""",
    'api/src/exports/exports.controller.ts': """
export class ExportsController {
  start() { return { id: 'exp_1', status: 'queued' }; }
  poll(res) { res.json({ id: 'exp_1', status: 'finished' }); }
}
""",
    'api/src/refunds/refund.ts': """
export enum RefundStatus { Requested = 'requested', Approved = 'approved', Settled = 'settled', Rejected = 'rejected' }
export const REFUND_TRANSITIONS: Record<RefundStatus, RefundStatus[]> = {
  [RefundStatus.Requested]: [RefundStatus.Approved, RefundStatus.Rejected],
  [RefundStatus.Approved]: [RefundStatus.Settled],
  [RefundStatus.Settled]: [],
  [RefundStatus.Rejected]: [],
};
""",
    'py/claims/models.py': """
from django.db import models
class ClaimStatus(models.TextChoices):
    OPEN = 'open', 'Open'
    APPROVED = 'approved', 'Approved'
    CREDITED = 'credited', 'Credited'
    PAID = 'paid', 'Paid'
def approve(c):
    if c.status != ClaimStatus.OPEN:
        return
    c.status = ClaimStatus.APPROVED
def credit(c):
    if c.status != ClaimStatus.OPEN:
        return
    c.status = ClaimStatus.CREDITED
def pay(c):
    if c.status != ClaimStatus.OPEN:
        return
    c.status = ClaimStatus.PAID
""",
    'py/payouts/settle.py': """
class PayoutStatus(models.TextChoices):
    REQUESTED = 'requested', 'Requested'
    PROCESSING = 'processing', 'Processing'
    SENT = 'sent', 'Sent'
class BatchStatus(models.TextChoices):
    OPEN = 'open_window', 'Open'
    SETTLED = 'settled_window', 'Settled'
def confirm(payout):
    if payout.status != PayoutStatus.PROCESSING:
        return
    payout.status = PayoutStatus.SENT
    settlement = payout.settlement
    settlement.status = BatchStatus.SETTLED
""",
    'py/shipping/webhooks.py': """
CARRIER_STATUS_MAP = {
    'HOLD': 'held',
    'RTO': 'returned',
}
def on_update(shipment, p):
    shipment.status = CARRIER_STATUS_MAP[p['s']]
""",
    'api/src/payments/payment.entity.ts': """
export enum PaymentStatus { Pending = 'pending', Captured = 'captured', Failed = 'failed', Stuck = 'stuck' }
export class Payment {
  status: PaymentStatus = PaymentStatus.Pending;
  fail() { if (this._status !== PaymentStatus.Pending) throw new Error('x'); this._status = PaymentStatus.Failed; }
}
""",
    'api/src/payments/payment.webhook.ts': """
export async function onEvent(p) {
  p.status = PaymentStatus.Captured;
  p.status = PaymentStatus.Stuck;
}
""",
    'api/src/reports/daily.sql': """
update shipments
   set status = 'returned'
 where status in ('in_transit', 'held');
""",
    'api/migrations/001_create_shipments.sql': """
create table shipments (id bigint, status text not null default 'in_transit' check (status in ('in_transit', 'held', 'returned', 'lost')));
""",
    'py/billing/models.py': """
from django.db import models
class InvoiceStatus(models.TextChoices):
    DRAFT = 'draft', 'Draft'
    ISSUED = 'issued', 'Issued'
    VOID = 'void', 'Void'
class Invoice(models.Model):
    status = models.CharField(max_length=16, choices=InvoiceStatus.choices, default=InvoiceStatus.DRAFT)
    @transition(field=status, source='draft', target='issued')
    def issue(self): pass
    @transition(field=status, source=[InvoiceStatus.ISSUED, InvoiceStatus.VOID], target=InvoiceStatus.DRAFT)
    def reopen(self): pass
def void_it(inv):
    Invoice.objects.filter(pk=inv.pk, status='issued').update(status='void')
""",
    'rb/app/models/subscription.rb': """
class Subscription < ApplicationRecord
  include AASM
  aasm column: :state do
    state :trialing, initial: true
    state :active, :past_due, :canceled
    event :activate do
      transitions from: :trialing, to: :active
    end
    event :cancel do
      transitions from: [:active, :past_due], to: :canceled
    end
  end
end
""",
    'api/src/carts/cart.machine.ts': """
export const cartMachine = createMachine({
  id: 'cart',
  initial: 'open',
  states: {
    open: { on: { CHECKOUT: 'checkout', ABANDON: 'abandoned' } },
    checkout: { on: { PAY: { target: 'paid' } } },
    paid: { type: 'final' },
    abandoned: { type: 'final' },
    limbo: {},
  },
});
""",
    'api/src/orders/order.service.spec.ts': "order.status = 'teleported_in_test';",
}

DECLARED = "created → paid → shipped → delivered\npaid -> refunded\n"
DECLARED_SECTIONS = "# Flows\n\n## Order lifecycle\n- created → paid → shipped → delivered\n- paid -> refunded\n\n## Shipment\n- in_transit -> returned\n"


def self_test():
    tmp = tempfile.mkdtemp(prefix='status-graph-selftest.')
    ok, total = 0, 0
    try:
        root = os.path.join(tmp, 'repo')
        for rel, body in SELF.items():
            p = os.path.join(root, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, 'w') as fh:
                fh.write(body)
        dec = os.path.join(tmp, 'flows.md')
        with open(dec, 'w') as fh:
            fh.write(DECLARED)
        dec2 = os.path.join(tmp, 'flows-sections.md')
        with open(dec2, 'w') as fh:
            fh.write(DECLARED_SECTIONS)
        out = os.path.join(tmp, 'out')
        code, rep = run([root], out, dec, None, 15, False, quiet=True)

        def check(name, cond):
            nonlocal ok, total
            total += 1
            ok += 1 if cond else 0
            if not cond:
                sys.stderr.write('FAIL %s\n' % name)
        sec = {}
        cur = None
        for line in rep.split('\n'):
            if line.startswith('## machine '):
                cur = line[11:]
                sec[cur] = []
            elif cur:
                sec[cur].append(line)
        S = {k: '\n'.join(v) for k, v in sec.items()}
        check('exit 0', code == 0)
        check('order machine from const + table', 'order' in S and 'legacy_hold' in S['order'])
        check('LC-1 unreachable legacy_hold', re.search(r'LC-1 unreachable[^\n]*legacy_hold', S.get('order', '')) is not None)
        check('table [] = declared terminal', re.search(r'LC-2 terminal[^\n]*delivered[^\n]*cancelled|LC-2 terminal[^\n]*cancelled', S.get('order', '')) is not None)
        check('guarded assignment is not unguarded', '→paid' not in re.sub(r'(?s).*unguarded writes: ', '', S.get('order', '')).split('\n')[0] or 'unguarded writes' not in S.get('order', ''))
        check('unguarded write listed', re.search(r'unguarded writes:[^\n]*→cancelled', S.get('order', '')) is not None)
        check('where-key is a predicate, not a write', not any(w['file'].endswith('order.service.ts:9') for w in WRITES_SEEN[0]))
        check('nativeUpdate data key guarded by its where key', any(w['to'] == 'shipped' and w['guard'] == 'cmp:paid' for w in WRITES_SEEN[0]))
        check('type union is not a write', not any(w['to'] == 'created' and w['kind'] == 'payload' for w in WRITES_SEEN[0]))
        check('undeclared state written', re.search(r'written but not declared[^\n]*teleported', S.get('order', '')) is not None)
        check('test file excluded', not any('teleported_in_test' == w['to'] for w in WRITES_SEEN[0]))
        check('ts enum machine + entity default initial', 'payment' in S and re.search(r'initial: pending', S.get('payment', '')) is not None)
        check('private backing field write, guarded by enum compare', any(w['to'] == 'failed' and w['guard'] == 'cmp:pending' for w in WRITES_SEEN[0]))
        check('unguarded enum writes listed', 'unguarded writes' in S.get('payment', ''))
        check('sql lowercase multi-line update with where guard', any(w['to'] == 'returned' and w['guard'].startswith('where:') and 'held' in w['guard'] for w in WRITES_SEEN[0]))
        check('db check machine + default', 'shipment' in S and 'initial: in_transit' in S.get('shipment', ''))
        check('LC-1 lost unreachable', re.search(r'LC-1 unreachable[^\n]*lost', S.get('shipment', '')) is not None)
        check('django TextChoices + fsm edge + default', 'invoice' in S and re.search(r'declared [1-9]', S.get('invoice', '')) is not None and 'initial: draft (default' in S.get('invoice', ''))
        check('django filter().update() guard', any(w['to'] == 'void' and 'issued' in w['guard'] for w in WRITES_SEEN[0]))
        check('aasm machine with initial and edges', 'subscription' in S and 'initial: trialing' in S.get('subscription', '') and re.search(r'declared [3-9]', S.get('subscription', '')) is not None)
        check('aasm past_due trap-or-unreachable', re.search(r'LC-1 unreachable[^\n]*past_due', S.get('subscription', '')) is not None)
        check('xstate states, final, trap', 'cart' in S and 'states (5): open, checkout, paid, abandoned, limbo' in S.get('cart', '') and re.search(r'LC-2 traps[^\n]*limbo', S.get('cart', '')) is not None and re.search(r'LC-1 unreachable[^\n]*limbo', S.get('cart', '')) is not None)
        check('LC-3 declared not built paid→refunded', re.search(r'LC-3 declared, not built[^\n]*paid→refunded', S.get('order', '')) is not None)
        check('LC-3 declared state missing', re.search(r'LC-3 declared states missing[^\n]*refunded', S.get('order', '')) is not None)
        W = WRITES_SEEN[0]
        E = open(os.path.join(out, 'edges.tsv')).read()
        check('TS computed enum keys in a transition table', re.search(r'declared 3 ', S.get('refund', '')) is not None
              and re.search(r'LC-2 terminal[^\n]*settled', S.get('refund', '')) is not None)
        check('django-fsm source=[A, B] read as both sources', '\tissued\tdraft\tfsm' in E and '\tvoid\tdraft\tfsm' in E and '\t*\tdraft\tfsm' not in E)
        check('another receiver\'s comparison is not the guard', any(w['to'] == 'settled_window' and w['guard'] == '' for w in W)
              and any(w['to'] == 'sent' and w['guard'] == 'cmp:processing' for w in W))
        check('a status key in the WHERE argument is not a write', not any(w['to'] == 'created' and w['file'].endswith('order.service.ts:13') for w in W))
        check('a literal alone does not attribute another entity\'s write', any(w['to'] == 'shipped' and w['file'].startswith('api/src/help/') and w['machine'] != 'order' for w in W))
        check('map-driven write resolves the map\'s values', {w['to'] for w in W if w['file'].startswith('py/shipping/webhooks.py') and w['machine'] == 'shipment'} == {'held', 'returned'})
        check('paid / credited / approved with no outgoing edge are terminal, not traps', re.search(r'LC-2 terminal[^\n]*approved[^\n]*credited[^\n]*paid', S.get('claim', '')) is not None
              and re.search(r'LC-2 traps[^\n]*: none', S.get('claim', '')) is not None)
        check('paid with outgoing edges is no reopen', not re.search(r'reopen[^\n]*paid→', S.get('order', '')))
        check('a response object is not a write', not any(w['to'] in ('queued', 'finished') for w in W))
        code6, rep6 = run([root], os.path.join(tmp, 'o6'), dec2, None, 15, False, quiet=True)
        S6 = dict((b.split('\n', 1)[0], b) for b in rep6.split('## machine ')[1:])
        check('--declared edges scoped to their ## section', 'LC-3' not in S6.get('cart', 'x') and 'LC-3' not in S6.get('payment', 'x')
              and re.search(r'LC-3 declared, not built[^\n]*paid→refunded', S6.get('order', '')) is not None
              and re.search(r'LC-3 built, not declared[^\n]*held→returned', S6.get('shipment', '')) is not None)
        for f in ('states.tsv', 'edges.tsv', 'writes.tsv', 'report.txt'):
            check('out file ' + f, os.path.isfile(os.path.join(out, f)))
        code2, _ = run([root], os.path.join(root, 'inside'), None, None, 15, False, quiet=True)
        check('--out inside root refused (exit 2)', code2 == 2 and not os.path.exists(os.path.join(root, 'inside')))
        empty = os.path.join(tmp, 'empty')
        os.makedirs(empty)
        code3, _ = run([empty], os.path.join(tmp, 'o3'), None, None, 15, False, quiet=True)
        check('empty root exit 2', code3 == 2)
        nod = os.path.join(tmp, 'nodecl')
        os.makedirs(nod)
        with open(os.path.join(nod, 'x.ts'), 'w') as fh:
            fh.write("export function f(o) { o.status = 'paid'; }\n")
        code4, _4 = run([nod], os.path.join(tmp, 'o4'), None, None, 15, False, quiet=True)
        check('writes without declarations: implied machine, exit 0', code4 == 0 and 'implied' in _4)
        code5, _ = run([os.path.join(tmp, 'missing')], None, None, None, 15, False, quiet=True)
        check('missing root exit 2', code5 == 2)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print('self-test: %d/%d passed' % (ok, total))
    return 0 if ok == total else 3


WRITES_SEEN = [[]]
SHOW_ALL = [False]
_orig_attribute = attribute


def attribute(g):  # noqa: F811 — keep the writes for the self-test's assertions
    _orig_attribute(g)
    WRITES_SEEN[0] = g.writes


def main(argv):
    if '--self-test' in argv:
        return self_test()
    roots, out, dec, mach, lb, tests = [], None, None, None, 15, False
    for a in argv:
        if a.startswith('--out='):
            out = a[6:]
        elif a.startswith('--declared='):
            dec = a[11:]
        elif a.startswith('--machine='):
            mach = a[10:]
        elif a.startswith('--lookback='):
            try:
                lb = int(a[11:])
            except ValueError:
                sys.stderr.write('bad --lookback\n')
                return 1
        elif a == '--all':
            SHOW_ALL[0] = True
        elif a == '--include-tests':
            tests = True
        elif a in ('-h', '--help'):
            print(__doc__)
            return 0
        elif a.startswith('-'):
            sys.stderr.write('unknown option: %s\n' % a)
            return 1
        else:
            roots.append(a)
    if not roots:
        sys.stderr.write('usage: status-graph.py <root> [...] [--out=<dir>] [--declared=<file>] [--machine=<key>] | --self-test\n')
        return 1
    code, _ = run(roots, out, dec, mach, lb, tests)
    return code


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
