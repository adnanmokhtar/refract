#!/usr/bin/env python3
"""model-graph.py — a dbt project's graph, effective configs and data tests, read WITHOUT dbt.
Stdlib only, Python 3.8+, run with `python3 -I -B`.

Why a script and not rg: every incremental, snapshot and data-test verdict depends on the EFFECTIVE
config — the model's own `config()`, else its properties YAML, else the most specific `+key` in
dbt_project.yml, else dbt's default — and on a graph (which parents a model reads, which tests sit on
which column). A grep for `unique_key` cannot tell "unset" from "set two directories up". This script
reads the project once and every data-engineering detector reads its tables. Every row is a
CANDIDATE: the skill reads the code before anything is reported.

Usage:  python3 -I -B model-graph.py <root> [<root> ...] [--out=<dir>] [--manifest=auto|off|<path>]
            [--configs] [--tests] [--edges] [--class=IN,DQ,...] [--json] [--include-packages]
        python3 -I -B model-graph.py --self-test
Reads:  every dbt_project.yml under the roots (dbt_packages/, target/, node_modules/ skipped unless
        --include-packages); per project its model-paths, snapshot-paths, seed-paths, test-paths;
        models `*.sql` (Jinja `config()`, `ref()`, `source()`, `{% if is_incremental() %}` branches,
        raw `from|join schema.table`, dedup windows, CASE literals, final `select *`) and `*.py`
        (`dbt.config/ref/source`); legacy `{% snapshot %}` blocks and YAML snapshots (dbt >= 1.9);
        properties YAML (`models:`, `sources:`, `snapshots:`, `seeds:`, `exposures:`, `unit_tests:`;
        tests under `data_tests:` or `tests:`, config nested or flat, dbt 1.10 `arguments:`);
        dbt_project.yml `models:`/`snapshots:`/`data_tests:`/`tests:`/`sources:` trees; the adapter
        from a committed profiles.yml `type:` or a `dbt-<adapter>` pin; the dbt version from
        `require-dbt-version` or a `dbt-core` pin. --manifest=auto (default) also reads a committed
        target/manifest.json as a CROSS-CHECK: configs and edges that differ go to manifest-diff.tsv
        (a stale manifest is common; the files on disk are the truth for this checkout).
Defaults encoded (dbt docs, accessed 2026-10-19): materialized `view`; on_schema_change `ignore`;
        snapshot hard_deletes `ignore` (>= 1.9; `invalidate_hard_deletes` is the <= 1.8 flag); test
        severity `error`; `append` never deduplicates and ignores unique_key; a NULL in any unique_key
        column never matches; constraints are enforced in full only on Postgres (elsewhere only
        not_null, plus check on Databricks); microbatch needs event_time, begin and batch_size, a
        unique_key on Postgres and a partition_by on BigQuery/Spark/Databricks. An incremental
        strategy left unset prints `adapter-default` — never a guessed name.
Output: stdout — the summary and the candidates (all, or --class); --configs / --tests / --edges add
        those tables; --json prints one JSON document instead. Files under --out (default: a new
        temp dir; an --out inside a scanned root is refused): models.tsv (effective config + the
        source of each value), edges.tsv, tests.tsv, sources.tsv, snapshots.tsv, incremental.tsv,
        candidates.tsv, manifest-diff.tsv, graph.json. Stderr: the ledger (files per kind, YAML or
        SQL not understood).
Exit:   0 graph built · 1 usage · 2 cannot build (a root missing, --out inside a root, a
        dbt_project.yml that does not parse) · 3 self-test failed · 4 no dbt project under the roots
        (the dbt lane is absent: every dbt § prints N/A, never `checked`).
Reads files; writes only under --out.
"""
import ast, json, os, re, shutil, sys, tempfile

SKIP_DIRS = {'node_modules', '.git', '.venv', 'venv', '__pycache__', 'target', 'dbt_packages',
             'dbt_modules', 'logs', '.tox', 'dist', 'build', '.idea', '.vscode', 'site-packages'}
CONFIG_KEYS = {
    'materialized', 'incremental_strategy', 'unique_key', 'on_schema_change', 'full_refresh',
    'partition_by', 'cluster_by', 'incremental_predicates', 'contract', 'access', 'enabled', 'tags',
    'schema', 'database', 'alias', 'persist_docs', 'event_time', 'batch_size', 'begin', 'lookback',
    'concurrent_batches', 'require_partition_filter', 'partitions', 'meta', 'docs', 'grants',
    'post-hook', 'pre-hook', 'post_hook', 'pre_hook', 'sql_header', 'on_configuration_change',
    'strategy', 'updated_at', 'check_cols', 'hard_deletes', 'invalidate_hard_deletes',
    'target_schema', 'target_database', 'quoting', 'transient', 'file_format', 'merge_update_columns',
    'merge_exclude_columns', 'group', 'severity', 'where', 'store_failures', 'error_if', 'warn_if',
    'limit', 'fail_calc', 'freshness', 'loaded_at_field', 'snapshot_meta_column_names',
    'dbt_valid_to_current', 'labels', 'packages', 'submission_method', 'warn_unenforced'}
DICT_CONFIGS = {'contract', 'meta', 'persist_docs', 'partition_by', 'freshness', 'docs', 'grants', 'labels',
                'quoting', 'snapshot_meta_column_names'}
TEST_CFG = ('severity', 'where', 'enabled', 'error_if', 'warn_if', 'store_failures', 'limit',
            'fail_calc', 'tags', 'meta', 'name')
GRAIN_TESTS = {'unique', 'not_null', 'relationships', 'unique_combination_of_columns',
               'dbt_utils.unique_combination_of_columns', 'dbt_constraints.primary_key'}
ROWCOUNT_TESTS = re.compile(r'(expect_table_row_count_to_be_between|expect_table_row_count_to_equal'
                            r'|at_least_one|expect_row_values_to_have_recent_data|row_count|'
                            r'not_empty|has_rows)')
RECON_TESTS = re.compile(r'(equal_rowcount|fewer_rows_than|equality|expect_table_aggregation_to_equal'
                         r'_other_table|expect_table_row_count_to_equal_other_table|reconcil)')
LOADCOL = re.compile(r'(?i)^(?:\w+\.)?"?(_?loaded_at|_etl_\w+|etl_\w+|ingested_at|_ingested_at|inserted_at'
                     r'|_fivetran_synced|_airbyte_extracted_at|_airbyte_emitted_at|_load_ts|load_ts|'
                     r'_loaded_ts|_sdc_batched_at|_sdc_extracted_at|_dlt_load_id|batch_ts)"?$')
NOWFN = re.compile(r'(?i)\b(current_timestamp|current_date|now\s*\(|getdate\s*\(|sysdate|'
                   r'sysdatetime|run_started_at|modules\.datetime\.datetime\.now)')
LOOKBACK = re.compile(r'(?i)(\binterval\b|\bdateadd\s*\(|\bdate_add\s*\(|\bdate_sub\s*\(|'
                      r'\btimestampadd\s*\(|\btimestamp_sub\s*\(|\bdatetime_sub\s*\(|\btimestamp_add'
                      r'\s*\(|\blookback|\bdays\s*=|-\s*\d+\b|var\(\s*[\'"]\w*(lookback|window|'
                      r'days|hours)\w*)')
ROLLUP = re.compile(r'(?i)(_daily|_hourly|_weekly|_monthly|_summary|_rollup|_agg|_aggregated|'
                    r'_totals|_stats)$')
ADAPTERS = ('postgres', 'bigquery', 'snowflake', 'redshift', 'databricks', 'spark', 'duckdb', 'trino',
            'clickhouse', 'synapse', 'fabric', 'sqlserver', 'athena', 'glue', 'materialize', 'oracle')
FIELD = ['project', 'node', 'path', 'line', 'layer', 'materialized', 'incremental_strategy',
         'unique_key', 'on_schema_change', 'full_refresh', 'partition_by', 'incremental_predicates',
         'event_time', 'begin', 'batch_size', 'lookback', 'contract', 'access']


# ----------------------------------------------------------------------------- YAML (subset)
class YMap(dict):
    pass


class YList(list):
    pass


def _strip_comment(s):
    q = None
    i = 0
    while i < len(s):
        ch = s[i]
        if q:
            if q == '"' and ch == '\\':
                i += 2
                continue
            if ch == q:
                if q == "'" and i + 1 < len(s) and s[i + 1] == "'":
                    i += 2
                    continue
                q = None
        elif ch in '"\'' and (i == 0 or s[i - 1] in ' \t:[{,-'):
            q = ch
        elif ch == '#' and (i == 0 or s[i - 1] in ' \t'):
            return s[:i].rstrip()
        i += 1
    return s.rstrip()


_KEY = re.compile(r'^("(?:[^"\\]|\\.)*"|\'(?:[^\']|\'\')*\'|[^\s#\'"{\[\-?][^#]*?|-[^\s][^#]*?|\?\s*\S[^#]*?)'
                  r'\s*:(?:\s+(.*)|)$')


def _split_key(t):
    m = _KEY.match(t)
    if not m:
        return None, None
    k = m.group(1)
    if k[:1] in '"\'':
        k = _scalar(k)
    return str(k), (m.group(2) or '').strip()


def _unquote(s):
    if len(s) >= 2 and s[0] == s[-1] == '"':
        b = s[1:-1]
        return re.sub(r'\\(.)', lambda m: {'n': '\n', 't': '\t'}.get(m.group(1), m.group(1)), b)
    if len(s) >= 2 and s[0] == s[-1] == "'":
        return s[1:-1].replace("''", "'")
    return None


def _scalar(s):
    s = s.strip()
    s = re.sub(r'^(&\w+|!!?\w+)\s+', '', s)
    u = _unquote(s)
    if u is not None:
        return u
    low = s.lower()
    if low in ('true', 'yes', 'on') and s in ('true', 'True', 'TRUE'):
        return True
    if low in ('false',) and s in ('false', 'False', 'FALSE'):
        return False
    if low in ('null', '~', ''):
        return None
    if re.match(r'^[-+]?\d+$', s):
        return int(s)
    if re.match(r'^[-+]?(\d+\.\d*|\.\d+)([eE][-+]?\d+)?$', s):
        return float(s)
    return s


class _Flow(object):
    def __init__(self, s):
        self.s, self.p = s, 0

    def ws(self):
        while self.p < len(self.s) and self.s[self.p] in ' \t\r\n':
            self.p += 1

    def value(self, stops=',]}'):
        self.ws()
        c = self.s[self.p:self.p + 1]
        if c == '{':
            return self.mapping()
        if c == '[':
            return self.seq()
        if c in ('"', "'"):
            return self.quoted()
        return self.plain(stops)

    def quoted(self):
        q, st = self.s[self.p], self.p
        self.p += 1
        while self.p < len(self.s):
            ch = self.s[self.p]
            if q == '"' and ch == '\\':
                self.p += 2
                continue
            if ch == q:
                if q == "'" and self.s[self.p + 1:self.p + 2] == "'":
                    self.p += 2
                    continue
                self.p += 1
                break
            self.p += 1
        return _unquote(self.s[st:self.p])

    def plain(self, stops):
        st, depth, q = self.p, 0, None
        while self.p < len(self.s):
            ch = self.s[self.p]
            if q:
                if ch == q:
                    q = None
            elif depth and ch in '"\'':
                q = ch
            elif ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            elif depth <= 0 and (ch in stops or (ch == ':' and ':' in stops and
                                                 self.s[self.p + 1:self.p + 2] in (' ', ',', '}', ''))):
                break
            self.p += 1
        return _scalar(self.s[st:self.p])

    def mapping(self):
        out = YMap()
        self.p += 1
        while True:
            self.ws()
            if self.p >= len(self.s):
                raise ValueError('unclosed {')
            if self.s[self.p] == '}':
                self.p += 1
                return out
            k = self.value(':,}')
            self.ws()
            v = None
            if self.s[self.p:self.p + 1] == ':':
                self.p += 1
                v = self.value(',}')
            out[str(k)] = v
            self.ws()
            if self.s[self.p:self.p + 1] == ',':
                self.p += 1

    def seq(self):
        out = YList()
        self.p += 1
        while True:
            self.ws()
            if self.p >= len(self.s):
                raise ValueError('unclosed [')
            if self.s[self.p] == ']':
                self.p += 1
                return out
            out.append(self.value(',]'))
            self.ws()
            if self.s[self.p:self.p + 1] == ',':
                self.p += 1


def flow(s):
    f = _Flow(s)
    v = f.value()
    f.ws()
    if f.p < len(f.s):
        raise ValueError('trailing text after flow value')
    return v


def _balanced(s):
    depth, q = 0, None
    for ch in s:
        if q:
            if ch == q:
                q = None
        elif ch in '"\'':
            q = ch
        elif ch in '[{':
            depth += 1
        elif ch in ']}':
            depth -= 1
    return depth <= 0


class Yaml(object):
    """Indentation YAML subset: block maps/seqs, flow values, block scalars, plain continuations.
    Each YMap carries .line and .klines {key: line}; each YList .line and .ilines."""

    def __init__(self, text):
        self.raw = text.replace('\t', '  ').split('\n')
        self.n = len(self.raw)

    def sig(self, i):
        while i < self.n:
            t = self.raw[i].strip()
            if t and not t.startswith('#') and t not in ('---', '...') and not t.startswith('%'):
                return i
            i += 1
        return i

    def ind(self, i):
        s = self.raw[i]
        return len(s) - len(s.lstrip(' '))

    def text(self, i):
        return _strip_comment(self.raw[i]).strip()

    def is_seq(self, i):
        t = self.text(i)
        return t == '-' or t.startswith('- ')

    def parse(self):
        i = self.sig(0)
        if i >= self.n:
            return None
        root, i = self.block(i, self.ind(i))
        while isinstance(root, YMap):
            i = self.sig(i)
            if i >= self.n:
                break
            more, j = self.block(i, self.ind(i))
            if j <= i:
                raise ValueError('line %d not understood' % (i + 1))
            if isinstance(more, YMap):
                root.update(more)
                root.klines.update(more.klines)
            i = j
        return root

    def block(self, i, ind):
        if self.is_seq(i):
            return self.seq(i, ind)
        return self.map(i, ind)

    def after(self, i, rest, ind):
        """Value of `key: rest` (or `- rest`) on line i; returns (value, next line)."""
        if rest[:1] in '&!' and ' ' not in rest:
            rest = ''
        if rest == '':
            j = self.sig(i + 1)
            if j < self.n and (self.ind(j) > ind or (self.ind(j) == ind and self.is_seq(j))):
                return self.block(j, self.ind(j))
            return None, i + 1
        if re.match(r'^[|>][+-]?\d*$', rest):
            return self.block_scalar(i, ind, rest[0])
        if rest[0] in '[{':
            buf, j = rest, i
            while not _balanced(buf) and j + 1 < self.n:
                j += 1
                buf += ' ' + _strip_comment(self.raw[j]).strip()
            try:
                return flow(buf), j + 1
            except (ValueError, IndexError):
                return buf, j + 1
        v = _scalar(rest)
        j = i + 1
        while isinstance(v, str) and _unquote(rest.strip()) is None:
            k = self.sig(j)
            if k >= self.n or self.ind(k) <= ind or self.is_seq(k) or _split_key(self.text(k))[0]:
                break
            v = v + ' ' + self.text(k)
            j = k + 1
        return v, j

    def block_scalar(self, i, ind, style):
        lines, j = [], i + 1
        while j < self.n and (not self.raw[j].strip() or self.ind(j) > ind):
            lines.append(self.raw[j].strip())
            j += 1
        return ('\n' if style == '|' else ' ').join(lines).strip(), j

    def seq(self, i, ind):
        out = YList()
        out.line, out.ilines = i + 1, []
        while True:
            i = self.sig(i)
            if i >= self.n or self.ind(i) != ind or not self.is_seq(i):
                return out, i
            t = self.text(i)
            rest = t[1:].lstrip()
            col = ind + len(t) - len(rest)
            out.ilines.append(i + 1)
            if rest and rest[0] not in '[{' and _split_key(rest)[0] is not None:
                v, i = self.map(i, col, first=rest)
            else:
                v, i = self.after(i, rest, ind)
            out.append(v)

    def map(self, i, ind, first=None):
        out = YMap()
        out.line, out.klines = i + 1, {}
        start = True
        while True:
            if start and first is not None:
                t = first
            else:
                if not start:
                    i = self.sig(i)
                    if i >= self.n or self.ind(i) != ind or self.is_seq(i):
                        return out, i
                t = self.text(i)
            start = False
            k, rest = _split_key(t)
            if k is None:
                raise ValueError('line %d: expected `key:`' % (i + 1))
            if k == '<<':
                v, i = self.after(i, rest, ind)
                if isinstance(v, dict):
                    for kk, vv in v.items():
                        out.setdefault(kk, vv)
                continue
            out.klines[k] = i + 1
            v, i = self.after(i, rest, ind)
            out[k] = v


def load_yaml(text):
    return Yaml(text).parse()


def kline(d, k):
    return getattr(d, 'klines', {}).get(k, '?')


def iline(lst, i, default=0):
    il = getattr(lst, 'ilines', None)
    return il[i] if il and i < len(il) else default


# ----------------------------------------------------------------------------- Jinja / SQL helpers
def _keep_lines(m):
    return re.sub(r'[^\n]', ' ', m.group(0))


def strip_comments(text):
    text = re.sub(r'\{#.*?#\}', _keep_lines, text, flags=re.S)
    out, i, n, q = [], 0, len(text), None
    while i < n:
        ch = text[i]
        if q:
            out.append(ch)
            if ch == q:
                q = None
            i += 1
            continue
        if ch == "'":
            q = ch
            out.append(ch)
            i += 1
            continue
        if text.startswith('--', i):
            j = text.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
            continue
        if text.startswith('/*', i):
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r'[^\n]', ' ', text[i:j]))
            i = j
            continue
        out.append(ch)
        i += 1
    return ''.join(out)


def lineno(text, pos):
    return text.count('\n', 0, pos) + 1


def call_args(text, open_paren):
    """Text between the paren at open_paren and its match (quote-aware); None when unbalanced."""
    depth, q, i = 0, None, open_paren
    while i < len(text):
        ch = text[i]
        if q:
            if ch == '\\':
                i += 2
                continue
            if ch == q:
                q = None
        elif ch in '"\'':
            q = ch
        elif ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
            if depth == 0:
                return text[open_paren + 1:i]
        i += 1
    return None


_JNAMES = {'true': True, 'false': False, 'none': None, 'True': True, 'False': False, 'None': None}


def _lit(node, src):
    if isinstance(node, ast.Constant):
        return node.value
    if isinstance(node, (ast.List, ast.Tuple)):
        return [_lit(e, src) for e in node.elts]
    if isinstance(node, ast.Dict):
        return dict((str(_lit(k, src)), _lit(v, src)) for k, v in zip(node.keys, node.values) if k is not None)
    if isinstance(node, ast.Name):
        return _JNAMES.get(node.id, '<expr:%s>' % node.id)
    seg = ast.get_source_segment(src, node) or type(node).__name__
    return '<expr:%s>' % re.sub(r'\s+', ' ', seg)[:80]


def parse_kwargs(argtext):
    """Jinja/Python call arguments → (kwargs dict, positional list). Never raises."""
    src = 'f(' + argtext + ')'
    try:
        call = ast.parse(src, mode='eval').body
        return (dict((kw.arg, _lit(kw.value, src)) for kw in call.keywords if kw.arg),
                [_lit(a, src) for a in call.args])
    except (SyntaxError, ValueError):
        pass
    kw, pos, parts, depth, q, cur = {}, [], [], 0, None, ''
    for ch in argtext:
        if q:
            cur += ch
            if ch == q:
                q = None
            continue
        if ch in '"\'':
            q = ch
        elif ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            parts.append(cur)
            cur = ''
            continue
        cur += ch
    parts.append(cur)
    for p in parts:
        m = re.match(r'\s*(\w+)\s*=(?!=)\s*(.*)$', p, re.S)
        if m:
            try:
                v = _lit(ast.parse(m.group(2).strip(), mode='eval').body, m.group(2).strip())
            except (SyntaxError, ValueError):
                v = '<expr:%s>' % re.sub(r'\s+', ' ', m.group(2).strip())[:80]
            kw[m.group(1)] = v
        elif p.strip():
            pos.append('<expr:%s>' % p.strip()[:80])
    return kw, pos


_CALL = r'(?<![\w.])(?:dbt\.)?%s\s*\('


def find_calls(text, name):
    for m in re.finditer(_CALL % name, text):
        args = call_args(text, m.end() - 1)
        if args is not None:
            yield m.start(), args


def refs_in(text):
    out = []
    for pos, args in find_calls(text, 'ref'):
        kw, pa = parse_kwargs(args)
        names = [a for a in pa if isinstance(a, str) and not a.startswith('<expr')]
        if names:
            out.append((names[-1], names[0] if len(names) > 1 else '', lineno(text, pos)))
    return out


def sources_in(text):
    out = []
    for pos, args in find_calls(text, 'source'):
        kw, pa = parse_kwargs(args)
        if len(pa) >= 2 and all(isinstance(a, str) and not a.startswith('<expr') for a in pa[:2]):
            out.append((pa[0], pa[1], lineno(text, pos)))
    return out


def configs_in(text):
    """Every `{{ config(...) }}` kwargs merged in order (later wins), with the first line."""
    cfg, line = {}, 0
    for pos, args in find_calls(text, 'config'):
        pre = text[max(0, pos - 12):pos]
        if '{{' not in pre and 'dbt.' not in text[pos:pos + 5]:
            continue
        kw, _ = parse_kwargs(args)
        cfg.update(kw)
        line = line or lineno(text, pos)
    return cfg, line


_TAG = re.compile(r'\{%-?\s*(\w+)\b(.*?)-?%\}', re.S)


def incremental_branches(text):
    """[(start, end)] spans of the `is_incremental()` branch of every if-block (also `not ...`/else)."""
    spans, stack = [], []
    for m in _TAG.finditer(text):
        tag, cond = m.group(1), m.group(2)
        if tag == 'if':
            inc = 'is_incremental' in cond
            neg = inc and re.search(r'\bnot\s+(dbt\.)?is_incremental', cond) is not None
            stack.append({'inc': inc, 'neg': neg, 'start': m.end(), 'in': inc and not neg})
        elif tag in ('elif', 'else') and stack:
            top = stack[-1]
            if top['inc'] and top['in']:
                spans.append((top['start'], m.start()))
            top['in'] = top['inc'] and top['neg'] and tag == 'else'
            top['start'] = m.end()
        elif tag == 'endif' and stack:
            top = stack.pop()
            if top['inc'] and top['in']:
                spans.append((top['start'], m.start()))
    return spans


_CMP = re.compile(r'(\w+\s*\([^()]*\)|[\w."`\[\]]+)\s*(>=|>)(?!>)\s*')


def analyse_branch(text, start, end):
    """Watermark comparisons inside an incremental branch."""
    body = text[start:end]
    rows = []
    for m in _CMP.finditer(body):
        if body[max(0, m.start(2) - 1):m.start(2)] in ('-', '<', '='):
            continue
        lhs = m.group(1).strip('`"[]')
        rhs = body[m.end():m.end() + 400]
        cut = re.compile(r'\s+(?:and|or)\s+|\n|\{%', re.I)
        if rhs.startswith('('):
            inner = call_args(rhs, 0)
            head = '(' + (inner if inner is not None else rhs[1:200]) + ')'
            rhs_t = head + (cut.split(rhs[len(head):], maxsplit=1)[0] if inner is not None else '')
        else:
            rhs_t = cut.split(rhs, maxsplit=1)[0]
        wm = re.search(r'(?i)\bmax\s*\(|\bthis\b|\{\{|\bvar\s*\(|\brun_query|\bstart_date|'
                       r'\bwatermark|\blast_\w+', rhs_t) is not None
        if not wm or re.match(r'^\d', lhs):
            continue
        bare = re.sub(r"'(?:[^']|'')*'", "''", rhs_t)
        rows.append({'line': lineno(text, start + m.start()), 'lhs': lhs, 'op': m.group(2),
                     'rhs': re.sub(r'\s+', ' ', rhs_t)[:120],
                     'lookback': bool(LOOKBACK.search(bare)),
                     'loadcol': any(LOADCOL.match(tok) for tok in re.findall(r'[\w.]+', lhs)),
                     'now': bool(NOWFN.search(body))})
    return rows


def dedup_windows(text):
    out = []
    for m in re.finditer(r'(?i)\brow_number\s*\(\s*\)\s*over\s*\(', text):
        inner = call_args(text, m.end() - 1) or ''
        om = re.search(r'(?is)\border\s+by\s+(.*)$', inner)
        keys = []
        if om:
            depth, cur = 0, ''
            for ch in om.group(1):
                if ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
                if ch == ',' and depth == 0:
                    keys.append(cur)
                    cur = ''
                    continue
                cur += ch
            keys.append(cur)
        keys = [k.strip() for k in keys if k.strip()]
        out.append({'line': lineno(text, m.start()), 'order_keys': len(keys),
                    'order': ', '.join(keys)[:80]})
    for m in re.finditer(r'\.(dropDuplicates|drop_duplicates)\s*\(([^)]*)\)', text):
        out.append({'line': lineno(text, m.start()), 'order_keys': -1, 'order': m.group(1) + '(' + m.group(2)[:60] + ')'})
    return out


_RAW = re.compile(r'(?i)\b(from|join)\s+((?:"[^"]+"|`[^`]+`|\[[^\]]+\]|[a-z_][\w$]*)'
                  r'(?:\.(?:"[^"]+"|`[^`]+`|\[[^\]]+\]|[a-z_][\w$]*)){1,2})')


def raw_relations(text):
    masked = re.sub(r'\{\{.*?\}\}', lambda m: '__jinja__' + re.sub(r'[^\n]', '', m.group(0)), text, flags=re.S)
    masked = re.sub(r'\{%.*?%\}', _keep_lines, masked, flags=re.S)
    masked = re.sub(r"'(?:[^']|'')*'", _keep_lines, masked)
    out = []
    for m in _RAW.finditer(masked):
        rel = m.group(2)
        if re.match(r'(?i)information_schema|pg_catalog|sys\.|__jinja__', rel) or '__jinja__' in rel:
            continue
        head = masked[max(0, m.start() - 60):m.start()]
        if re.search(r'(?i)\b(extract|trim|substring|position|overlay)\s*\([^()]*$', head):
            continue
        out.append((rel.replace('"', '').replace('`', ''), lineno(masked, m.start())))
    return out


def case_literals(text):
    lits = {}
    for m in re.finditer(r"(?i)\bwhen\s+(?:\w+\.)?(\w+)\s*(?:=|in)\s*\(?\s*('(?:[^']|'')*'(?:\s*,\s*'(?:[^']|'')*')*)", text):
        for v in re.findall(r"'((?:[^']|'')*)'", m.group(2)):
            lits.setdefault(m.group(1).lower(), set()).add(v)
    for m in re.finditer(r"(?is)\bcase\s+(?:\w+\.)?(\w+)\s+((?:when\s+'(?:[^']|'')*'\s+then\b.*?)+)(?:else|end)\b", text):
        for v in re.findall(r"(?i)when\s+'((?:[^']|'')*)'", m.group(2)):
            lits.setdefault(m.group(1).lower(), set()).add(v)
    return lits


def final_select_star(text):
    masked = re.sub(r'\{\{.*?\}\}', lambda m: '__jinja__' + re.sub(r'[^\n]', '', m.group(0)), text, flags=re.S)
    masked = re.sub(r'\{%.*?%\}', _keep_lines, masked, flags=re.S)
    ctes = set(x.lower() for x in re.findall(r'(?i)(?:\bwith|,)\s*(\w+)\s+as\s*\(', masked))
    sels = list(re.finditer(r'(?i)\bselect\s+(?:distinct\s+)?((?:\w+\.)?\*)\s+from\s+(\S+)', masked))
    if not sels:
        return None
    m = sels[-1]
    if m.start() != list(re.finditer(r'(?i)\bselect\b', masked))[-1].start():
        return None
    target = m.group(2).strip('();').lower()
    return {'line': lineno(masked, m.start()), 'cte': target in ctes,
            'from': 'an upstream ref()/source()' if target.startswith('__jinja__') else target}


# ----------------------------------------------------------------------------- project model
def walk(root, names=None, exts=None, include_packages=False):
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if (x not in SKIP_DIRS or (include_packages and x in (
            'dbt_packages', 'dbt_modules'))) and not x.startswith('.'))
        for f in sorted(files):
            if (names and f in names) or (exts and os.path.splitext(f)[1] in exts):
                yield os.path.join(d, f)


def read(p, ledger):
    try:
        with open(p, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except OSError as e:
        ledger['unreadable'].append('%s (%s)' % (p, e.strerror))
        return None


def parse_yaml_file(p, ledger):
    t = read(p, ledger)
    if t is None:
        return None
    try:
        return load_yaml(t)
    except (ValueError, IndexError, RecursionError) as e:
        ledger['yaml_not_understood'].append('%s: %s' % (p, e))
        return None


def layer_of(rel):
    parts = [x.lower() for x in rel.replace('\\', '/').split('/')]
    stem = parts[-1]
    for name, pre, dirs in (('staging', ('stg_', 'base_'), ('staging', 'stage', 'base', 'stg')),
                            ('intermediate', ('int_',), ('intermediate', 'int')),
                            ('marts', ('fct_', 'dim_', 'fact_', 'mart_', 'agg_', 'rpt_'),
                             ('marts', 'mart', 'core', 'reporting', 'presentation'))):
        if stem.startswith(pre) or any(p in dirs for p in parts[:-1]):
            return name
    return 'other'


def tests_of(entry):
    t = entry.get('data_tests') if isinstance(entry, dict) else None
    if t is None and isinstance(entry, dict):
        t = entry.get('tests')
    return t if isinstance(t, list) else []


def norm_test(t, item_line):
    """One YAML test entry → (name, config dict, args dict)."""
    if isinstance(t, str):
        return t, {}, {}
    if not isinstance(t, dict) or not t:
        return None, {}, {}
    if 'test_name' in t:
        name, body = t.get('test_name'), t
    else:
        name = next(iter(t))
        body = t[name] if isinstance(t[name], dict) else {}
    cfg = dict((k, body[k]) for k in TEST_CFG if k in body and k != 'name')
    if isinstance(body.get('config'), dict):
        cfg.update(body['config'])
    args = body.get('arguments') if isinstance(body.get('arguments'), dict) else dict(
        (k, v) for k, v in body.items() if k not in TEST_CFG and k not in ('config', 'test_name'))
    return str(name), cfg, args


class Project(object):
    def __init__(self, path, ledger, include_packages):
        self.dir = os.path.dirname(path)
        self.file = path
        self.ledger = ledger
        self.inc_pk = include_packages
        doc = parse_yaml_file(path, ledger)
        if not isinstance(doc, dict):
            raise ValueError('%s does not parse' % path)
        self.doc = doc
        self.name = str(doc.get('name') or os.path.basename(self.dir))
        self.require = doc.get('require-dbt-version')
        self.paths = {}
        for key, default in (('model-paths', ['models']), ('snapshot-paths', ['snapshots']),
                             ('seed-paths', ['seeds']), ('test-paths', ['tests'])):
            v = doc.get(key)
            if v is None and key == 'model-paths':
                v = doc.get('source-paths')
            self.paths[key] = [str(x) for x in (v if isinstance(v, list) else default)]

    def tree_configs(self, section, fqn):
        """dbt_project.yml `section:` tree → {key: (value, source)} for a node fqn [project, dir.., name]."""
        out = {}
        node = self.doc.get(section)
        if not isinstance(node, dict):
            return out
        lv = [(node, section)]
        if isinstance(node, dict):
            path = section
            for part in fqn:
                nxt = node.get(part) if isinstance(node, dict) else None
                if not isinstance(nxt, dict):
                    break
                path = path + '.' + part
                node = nxt
                lv.append((node, path))
        for level, where in lv:
            for k, v in level.items():
                plus = k.startswith('+')
                key = k[1:] if plus else k
                if plus or (key in CONFIG_KEYS and (not isinstance(v, dict) or key in DICT_CONFIGS)):
                    out[key] = (v, 'dbt_project.yml:%s (%s)' % (kline(level, k), where + '.' + k))
        return out


class Graph(object):
    def __init__(self, roots, include_packages=False, manifest='auto'):
        self.roots = roots
        self.ledger = {'files': {}, 'unreadable': [], 'yaml_not_understood': [], 'sql_not_understood': []}
        self.projects, self.nodes, self.sources, self.tests, self.edges = [], {}, {}, [], []
        self.exposures, self.unit_tests, self.singular, self.cands = [], set(), [], []
        self.adapters, self.dbt_version, self.manifest_rows = {}, [], []
        self.include_packages = include_packages
        self.manifest = manifest

    def count(self, kind):
        self.ledger['files'][kind] = self.ledger['files'].get(kind, 0) + 1

    # ------------------------------------------------------------------ discovery
    def build(self):
        for r in self.roots:
            for p in walk(r, names={'dbt_project.yml'}, include_packages=self.include_packages):
                self.count('dbt_project.yml')
                self.projects.append(Project(p, self.ledger, self.include_packages))
        if not self.projects:
            return False
        self.detect_versions()
        for pr in self.projects:
            self.read_project(pr)
        self.resolve()
        if self.manifest != 'off':
            self.cross_check_manifest()
        self.candidates()
        return True

    def detect_versions(self):
        for r in self.roots:
            for p in walk(r, names={'profiles.yml', 'profiles.yaml'}):
                t = read(p, self.ledger) or ''
                for m in re.finditer(r'(?m)^\s*type:\s*["\']?(\w+)', t):
                    if m.group(1).lower() in ADAPTERS:
                        self.adapters.setdefault(m.group(1).lower(), []).append('%s:%d' % (
                            rel(p, self.roots), lineno(t, m.start())))
            pins = {'requirements.txt', 'requirements.in', 'requirements-dev.txt', 'pyproject.toml',
                    'Pipfile', 'Pipfile.lock', 'poetry.lock', 'uv.lock', 'setup.cfg', 'Dockerfile',
                    'constraints.txt'}
            for p in walk(r, names=pins):
                t = read(p, self.ledger) or ''
                for m in re.finditer(r'(?i)\bdbt-(%s)\b' % '|'.join(ADAPTERS), t):
                    self.adapters.setdefault(m.group(1).lower(), []).append('%s:%d' % (
                        rel(p, self.roots), lineno(t, m.start())))
                for m in re.finditer(r'(?i)\bdbt-core\s*(?:==|>=|~=|=|\s+)\s*"?([\d.]+)', t):
                    self.dbt_version.append((m.group(1), '%s:%d' % (rel(p, self.roots), lineno(t, m.start()))))
        for pr in self.projects:
            if pr.require:
                self.dbt_version.append((str(pr.require), rel(pr.file, self.roots) + ' require-dbt-version'))

    def dbt_ge(self, major, minor):
        """True / False / None (unknown) — the lowest pinned or required version."""
        best = None
        for v, _ in self.dbt_version:
            m = re.search(r'(\d+)\.(\d+)', v if isinstance(v, str) else str(v))
            if m:
                t = (int(m.group(1)), int(m.group(2)))
                best = t if best is None or t < best else best
        return None if best is None else best >= (major, minor)

    def adapter(self):
        a = sorted(self.adapters)
        return a[0] if len(a) == 1 else ('+'.join(a) if a else 'unknown')

    # ------------------------------------------------------------------ files
    def read_project(self, pr):
        for mp in pr.paths['model-paths']:
            base = os.path.join(pr.dir, mp)
            for p in walk(base, exts={'.sql', '.py', '.yml', '.yaml'}, include_packages=self.include_packages):
                ext = os.path.splitext(p)[1]
                if ext in ('.yml', '.yaml'):
                    self.read_props(pr, p)
                else:
                    self.read_model(pr, p, base, 'model')
        for sp in pr.paths['snapshot-paths']:
            base = os.path.join(pr.dir, sp)
            for p in walk(base, exts={'.sql', '.yml', '.yaml'}):
                if p.endswith('.sql'):
                    self.read_snapshot_sql(pr, p, base)
                else:
                    self.read_props(pr, p)
        for sp in pr.paths['seed-paths']:
            base = os.path.join(pr.dir, sp)
            for p in walk(base, exts={'.csv', '.yml', '.yaml'}):
                if p.endswith('.csv'):
                    self.count('seed')
                    name = os.path.splitext(os.path.basename(p))[0]
                    self.put('seed.' + name, self.new_node(pr, 'seed', name, p, base))
                else:
                    self.read_props(pr, p)
        for tp in pr.paths['test-paths']:
            base = os.path.join(pr.dir, tp)
            for p in walk(base, exts={'.sql', '.yml', '.yaml'}):
                if p.endswith('.sql'):
                    t = read(p, self.ledger) or ''
                    if re.search(r'\{%-?\s*test\s+\w+\s*\(', t):
                        continue
                    self.count('singular test')
                    c = strip_comments(t)
                    self.singular.append({'path': rel(p, self.roots), 'refs': [r[0] for r in refs_in(c)],
                                          'sources': ['%s.%s' % (s[0], s[1]) for s in sources_in(c)],
                                          'text': c.lower()})
                else:
                    self.read_props(pr, p)

    def new_node(self, pr, kind, name, p, base):
        relp = os.path.relpath(p, base).replace('\\', '/')
        fqn = [pr.name] + relp.split('/')[:-1] + [name]
        return {'kind': kind, 'name': name, 'project': pr.name, 'path': rel(p, self.roots), 'line': 1,
                'fqn': fqn, 'layer': layer_of(relp) if kind == 'model' else kind, 'file_cfg': {},
                'file_cfg_line': 0, 'yml_cfg': {}, 'yml_line': 0, 'refs': [], 'srcs': [], 'raw': [],
                'branches': [], 'has_inc': False, 'dedup': [], 'case': {}, 'star': None, 'lang': '',
                'columns': {}, 'constraints': [], 'access': None, 'versions': None, 'window': False,
                'case_logic': False, 'pr': pr, 'cfg': {}}

    YML_FIELDS = ('yml_cfg', 'yml', 'yml_line', 'columns', 'constraints', 'access', 'versions', 'latest_version',
                  'deprecation_date')

    def put(self, key, fresh):
        """A node read from a SQL/py/csv file keeps what its properties YAML already gave it."""
        old = self.nodes.get(key)
        if old:
            for k in self.YML_FIELDS:
                if k in old:
                    fresh[k] = old[k]
        self.nodes[key] = fresh
        return fresh

    def read_model(self, pr, p, base, kind):
        t = read(p, self.ledger)
        if t is None:
            return
        name = os.path.splitext(os.path.basename(p))[0]
        vm = re.match(r'^(.*)_v(\d+)$', name)
        key = 'model.' + name
        n = self.put(key, self.new_node(pr, kind, name, p, base))
        n['lang'] = p.rsplit('.', 1)[-1]
        if vm:
            n['version_of'], n['version_n'] = vm.group(1), int(vm.group(2))
        self.count('model ' + n['lang'])
        if n['lang'] == 'py':
            self.read_py_model(n, t)
            return
        c = strip_comments(t)
        n['file_cfg'], n['file_cfg_line'] = configs_in(c)
        n['refs'] = refs_in(c)
        n['srcs'] = sources_in(c)
        n['raw'] = raw_relations(c)
        n['has_inc'] = 'is_incremental' in c
        for s, e in incremental_branches(c):
            n['branches'].append({'line': lineno(c, s), 'rows': analyse_branch(c, s, e),
                                  'now': bool(NOWFN.search(c[s:e]))})
        n['dedup'] = dedup_windows(c)
        n['case'] = case_literals(c)
        n['star'] = final_select_star(c)
        n['window'] = re.search(r'(?i)\bover\s*\(', c) is not None
        n['case_logic'] = re.search(r'(?i)\bcase\s+when\b|\bcase\s+\w+\s+when\b', c) is not None

    def read_py_model(self, n, t):
        try:
            tree = ast.parse(t)
        except SyntaxError as e:
            self.ledger['sql_not_understood'].append('%s: %s' % (n['path'], e))
            return
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                attr = node.func.attr
                args = [_lit(a, t) for a in node.args]
                if attr == 'config' and isinstance(node.func.value, ast.Name) and node.func.value.id == 'dbt':
                    n['file_cfg'].update(dict((kw.arg, _lit(kw.value, t)) for kw in node.keywords if kw.arg))
                    n['file_cfg_line'] = n['file_cfg_line'] or node.lineno
                elif attr == 'ref' and args and isinstance(args[-1], str):
                    n['refs'].append((args[-1], args[0] if len(args) > 1 else '', node.lineno))
                elif attr == 'source' and len(args) >= 2:
                    n['srcs'].append((str(args[0]), str(args[1]), node.lineno))
                elif attr in ('dropDuplicates', 'drop_duplicates'):
                    n['dedup'].append({'line': node.lineno, 'order_keys': -1, 'order': attr})
            if isinstance(node, ast.Attribute) and node.attr == 'is_incremental':
                n['has_inc'] = True

    def read_snapshot_sql(self, pr, p, base):
        t = read(p, self.ledger)
        if t is None:
            return
        c = strip_comments(t)
        for m in re.finditer(r'\{%-?\s*snapshot\s+(\w+)\s*-?%\}(.*?)\{%-?\s*endsnapshot\s*-?%\}', c, re.S):
            self.count('snapshot sql')
            n = self.new_node(pr, 'snapshot', m.group(1), p, base)
            body = m.group(2)
            n['file_cfg'], _ = configs_in(body)
            n['file_cfg_line'] = lineno(c, m.start())
            n['line'] = lineno(c, m.start())
            n['refs'], n['srcs'] = refs_in(body), sources_in(body)
            self.put('snapshot.' + m.group(1), n)

    def read_props(self, pr, p):
        doc = parse_yaml_file(p, self.ledger)
        if not isinstance(doc, dict):
            return
        self.count('properties yml')
        r = rel(p, self.roots)
        for kind, key in (('model', 'models'), ('snapshot', 'snapshots'), ('seed', 'seeds')):
            for i, e in enumerate(doc.get(key) or []):
                if not isinstance(e, dict) or not e.get('name'):
                    continue
                name = str(e['name'])
                line = iline(doc[key], i)
                nk = '%s.%s' % (kind, name)
                n = self.nodes.get(nk)
                if n is None:
                    n = self.new_node(pr, kind, name, p, os.path.dirname(p))
                    n['path'], n['yml_only'] = r, True
                    self.nodes[nk] = n
                n['yml'], n['yml_line'] = r, line
                if isinstance(e.get('config'), dict):
                    n['yml_cfg'] = dict(e['config'])
                for k in ('access', 'latest_version', 'deprecation_date'):
                    if k in e:
                        n[k] = e[k]
                if kind == 'snapshot' and e.get('relation'):
                    rr = str(e['relation'])
                    n['refs'], n['srcs'] = refs_in(rr), sources_in(rr)
                    n['line'], n['yml_only'] = line, False
                    self.count('snapshot yml')
                n['versions'] = e.get('versions') if isinstance(e.get('versions'), list) else None
                n['constraints'] = [c for c in (e.get('constraints') or []) if isinstance(c, dict)]
                for t in tests_of(e):
                    self.add_test(nk, '', t, r, line)
                for j, col in enumerate(e.get('columns') or []):
                    if not isinstance(col, dict) or not col.get('name'):
                        continue
                    cn = str(col['name']).lower()
                    cl = iline(e['columns'], j, line)
                    n['columns'][cn] = {'line': cl, 'data_type': col.get('data_type'),
                                        'constraints': [c.get('type') for c in col.get('constraints') or []
                                                        if isinstance(c, dict)],
                                        'meta': col.get('meta')}
                    for t in tests_of(col):
                        self.add_test(nk, cn, t, r, cl)
        for i, s in enumerate(doc.get('sources') or []):
            if not isinstance(s, dict) or not s.get('name'):
                continue
            sline = iline(doc['sources'], i)
            scfg = s.get('config') if isinstance(s.get('config'), dict) else {}
            for j, tb in enumerate(s.get('tables') or []):
                if not isinstance(tb, dict) or not tb.get('name'):
                    continue
                tl = iline(s['tables'], j, sline)
                tcfg = tb.get('config') if isinstance(tb.get('config'), dict) else {}
                key = '%s.%s' % (s['name'], tb['name'])
                fresh, fsrc = None, 'unset'
                for d, where in ((s, 'source'), (scfg, 'source config'), (tb, 'table'), (tcfg, 'table config')):
                    if 'freshness' in d:
                        fresh, fsrc = d['freshness'], where + (' (explicit null)' if d['freshness'] is None else '')
                laf = tcfg.get('loaded_at_field') or tb.get('loaded_at_field') or scfg.get(
                    'loaded_at_field') or s.get('loaded_at_field')
                self.sources[key] = {'path': r, 'line': tl, 'freshness': fresh, 'fresh_src': fsrc,
                                     'loaded_at_field': laf, 'project': pr.name, 'columns': {}}
                self.count('source table')
                for t in tests_of(tb):
                    self.add_test('source.' + key, '', t, r, tl)
                for col in tb.get('columns') or []:
                    if isinstance(col, dict) and col.get('name'):
                        self.sources[key]['columns'][str(col['name']).lower()] = True
                        for t in tests_of(col):
                            self.add_test('source.' + key, str(col['name']).lower(), t, r, tl)
        for i, ex in enumerate(doc.get('exposures') or []):
            if isinstance(ex, dict) and ex.get('name'):
                deps = ' '.join(str(d) for d in ex.get('depends_on') or [])
                pins = [(m.group(1), int(m.group(2)) if m.group(2) else None) for m in re.finditer(
                    r'''\bref\(\s*["']([\w.-]+)["']\s*(?:,\s*v(?:ersion)?\s*=\s*["']?(\d+))?''', deps)]
                self.exposures.append({'name': ex['name'], 'path': r, 'refs': [x[0] for x in refs_in(deps)],
                                       'pins': pins,
                                       'sources': ['%s.%s' % (x[0], x[1]) for x in sources_in(deps)]})
        for u in doc.get('unit_tests') or []:
            if isinstance(u, dict) and u.get('model'):
                self.unit_tests.add(str(u['model']))

    def add_test(self, node, col, t, path, line):
        name, cfg, args = norm_test(t, line)
        if name:
            self.tests.append({'node': node, 'column': col, 'test': name, 'cfg': cfg, 'args': args,
                               'path': path, 'line': line})

    # ------------------------------------------------------------------ resolution
    def resolve(self):
        for key, n in self.nodes.items():
            pr = n['pr']
            if n.get('version_of'):
                # A dbt versioned model: `<name>_v<N>.sql` files, one YAML entry for `<name>` with `versions:`.
                # Each version inherits the base entry's config, columns, access and tests (dbt applies them to
                # every version), then the matching `versions:` item's own config and deprecation_date.
                base = self.nodes.get('model.' + n['version_of'])
                if base and base.get('yml_cfg') and not n['yml_cfg']:
                    n['yml_cfg'], n['yml'] = dict(base['yml_cfg']), base.get('yml')
                    n['columns'] = n['columns'] or base['columns']
                if base:
                    for k in ('access', 'latest_version'):
                        if n.get(k) is None and base.get(k) is not None:
                            n[k] = base[k]
                    for ve in base.get('versions') or []:
                        if isinstance(ve, dict) and str(ve.get('v')) == str(n.get('version_n')):
                            if isinstance(ve.get('config'), dict):
                                n['yml_cfg'] = dict(n['yml_cfg'], **ve['config'])
                            if 'deprecation_date' in ve:
                                n['deprecation_date'] = ve['deprecation_date']
                    if not any(t['node'] == key for t in self.tests):
                        bk = 'model.' + n['version_of']
                        self.tests.extend(dict(t, node=key, inherited=bk) for t in list(self.tests) if t['node'] == bk)
            section = {'model': 'models', 'snapshot': 'snapshots', 'seed': 'seeds'}.get(n['kind'], 'models')
            eff = pr.tree_configs(section, n['fqn'])
            for k, v in n['yml_cfg'].items():
                eff[k] = (v, '%s:%s' % (n.get('yml', '?'), n.get('yml_line') or '?'))
            for k, v in n['file_cfg'].items():
                eff[k] = (v, '%s:%s config()' % (n['path'], n['file_cfg_line'] or '?'))
            if n['kind'] == 'model':
                eff.setdefault('materialized', ('view', 'default'))
                mat = str(eff['materialized'][0]).lower()
                if mat == 'incremental':
                    eff.setdefault('on_schema_change', ('ignore', 'default'))
                    eff.setdefault('incremental_strategy', ('adapter-default', 'default'))
            if n['kind'] == 'snapshot':
                eff.setdefault('hard_deletes', ('ignore', 'default'))
            n['cfg'] = eff
            for parent, pkg, line in n['refs']:
                tgt = self.resolve_ref(parent)
                self.edges.append((key, tgt, 'ref', '%s:%d' % (n['path'], line)))
            for s, t, line in n['srcs']:
                self.edges.append((key, 'source.%s.%s' % (s, t), 'source', '%s:%d' % (n['path'], line)))
            for r_, line in n['raw']:
                self.edges.append((key, 'raw:' + r_, 'raw', '%s:%d' % (n['path'], line)))
        self.test_default = None
        for pr in self.projects:
            for sec in ('data_tests', 'tests'):
                node = pr.doc.get(sec)
                stack = [(node, sec)] if isinstance(node, dict) else []
                while stack:
                    d, where = stack.pop()
                    for k, v in d.items():
                        if k.lstrip('+') == 'severity':
                            self.test_default = (v, 'dbt_project.yml:%s (%s.%s)' % (kline(d, k), where, k))
                        elif isinstance(v, dict):
                            stack.append((v, where + '.' + k))
        for t in self.tests:
            sev = t['cfg'].get('severity')
            if sev is not None:
                t['severity'] = (str(sev).lower(), '%s:%s' % (t['path'], t['line']))
            elif self.test_default:
                t['severity'] = (str(self.test_default[0]).lower(), self.test_default[1])
            else:
                t['severity'] = ('error', 'default')

    def resolve_ref(self, name):
        for kind in ('model', 'seed', 'snapshot'):
            if '%s.%s' % (kind, name) in self.nodes:
                return '%s.%s' % (kind, name)
        return 'unresolved:' + name

    def cross_check_manifest(self):
        seen = set()
        for pr in self.projects:
            mp = self.manifest if self.manifest not in ('auto', 'off') else os.path.join(pr.dir, 'target', 'manifest.json')
            if mp in seen or not os.path.isfile(mp):
                continue
            seen.add(mp)
            try:
                with open(mp, encoding='utf-8') as fh:
                    man = json.load(fh)
            except (OSError, ValueError) as e:
                self.ledger['unreadable'].append('%s (%s)' % (mp, e))
                continue
            meta = man.get('metadata') or {}
            self.manifest_rows.append(('manifest', rel(mp, self.roots), 'generated_at',
                                       str(meta.get('generated_at')), str(meta.get('dbt_version')), ''))
            for uid, node in (man.get('nodes') or {}).items():
                if node.get('resource_type') not in ('model', 'snapshot'):
                    continue
                key = '%s.%s' % (node['resource_type'], node.get('name'))
                mine = self.nodes.get(key)
                if mine is None:
                    self.manifest_rows.append(('missing-on-disk', key, '', '', '', ''))
                    continue
                mc = node.get('config') or {}
                for k in ('materialized', 'incremental_strategy', 'unique_key', 'on_schema_change',
                          'full_refresh', 'hard_deletes', 'event_time'):
                    if k in mc and mc[k] is not None and k in mine['cfg']:
                        a, b = str(mc[k]).lower(), str(mine['cfg'][k][0]).lower()
                        if a != b and not (k == 'incremental_strategy' and b == 'adapter-default'):
                            self.manifest_rows.append(('config-differs', key, k, a, b, mine['cfg'][k][1]))
                deps = set(d.split('.')[-1] for d in (node.get('depends_on') or {}).get('nodes') or [])
                disk = set(e[1].split('.')[-1].split(':')[-1] for e in self.edges if e[0] == key and e[2] != 'raw')
                for d in sorted(deps ^ disk):
                    self.manifest_rows.append(('edge-differs', key, d, 'manifest' if d in deps else '', 'disk' if d in disk else '', ''))

    # ------------------------------------------------------------------ candidates
    def cand(self, cls, sev, node, where, msg, src=''):
        self.cands.append({'class': cls, 'sev': sev, 'node': node, 'where': where, 'msg': msg, 'src': src})

    def tests_on(self, node, col=None):
        return [t for t in self.tests if t['node'] == node and (col is None or t['column'] == col)]

    def candidates(self):
        adapter = self.adapter()
        children = {}
        for c, p, kind, w in self.edges:
            children.setdefault(p, []).append(c)
        exposed = set()
        for ex in self.exposures:
            for r, v in ex.get('pins') or [(x, None) for x in ex['refs']]:
                vers = sorted(nn['version_n'] for nn in self.nodes.values() if nn.get('version_of') == r)
                if not vers:
                    exposed.add('model.' + r)
                    continue
                # an exposure pinned to `v=N` reads that version only; unpinned, it reads latest_version
                # (else the highest): flagging every version of a model was noise on the ones nobody reads
                base = self.nodes.get('model.' + r) or {}
                lv = base.get('latest_version')
                v = v if v is not None else (int(lv) if str(lv).isdigit() else vers[-1])
                exposed.add('model.%s_v%d' % (r, v))
        ge19 = self.dbt_ge(1, 9)
        for key, n in sorted(self.nodes.items()):
            if n['kind'] == 'seed' or n.get('yml_only'):
                continue
            cfg = n['cfg']
            where = '%s:%s' % (n['path'], n['file_cfg_line'] or n.get('line') or 1)
            g = lambda k: cfg.get(k, (None, 'unset'))
            mat = str(g('materialized')[0]).lower()
            strat = str(g('incremental_strategy')[0]).lower()
            uk = g('unique_key')[0]
            if n['kind'] == 'snapshot':
                hd, hsrc = g('hard_deletes')
                inv = g('invalidate_hard_deletes')[0]
                if str(hd).lower() == 'ignore' and inv is not True:
                    self.cand('IN-4', 'high', key, where, 'snapshot keeps hard-deleted rows current: hard_deletes '
                              '`ignore` (%s) and no invalidate_hard_deletes' % hsrc, hsrc)
                elif inv is True and ge19:
                    self.cand('IN-4', 'low', key, where, 'invalidate_hard_deletes is the <= 1.8 flag; dbt >= 1.9 '
                              'reads hard_deletes', g('invalidate_hard_deletes')[1])
                if str(g('check_cols')[0]).lower() == 'all':
                    self.cand('IN-4', 'low', key, where, "check_cols 'all': any audit column change opens a version",
                              g('check_cols')[1])
                continue
            if mat == 'incremental':
                self.incremental_rules(key, n, where, g, strat, uk, adapter)
            if mat not in ('ephemeral',) and n['kind'] == 'model':
                self.test_rules(key, n, where, adapter)
            if mat == 'table' and re.match(r'(?i)(fct|fact)_', n['name']):
                self.cand('CO-3', 'low', key, where, 'fact model rebuilt in full every run (materialized table)',
                          g('materialized')[1])
            if n['kind'] == 'model':
                for r_, line in n['raw']:
                    self.cand('LN-1', 'medium', key, '%s:%d' % (n['path'], line),
                              'hard-coded relation `%s` (not ref()/source())' % r_)
                if n['layer'] in ('marts', 'intermediate') and n['srcs']:
                    self.cand('LN-2', 'low', key, '%s:%d' % (n['path'], n['srcs'][0][2]),
                              '%s model reads source() directly' % n['layer'])
                if n['layer'] == 'staging' and len(set((s[0], s[1]) for s in n['srcs'])) > 1:
                    self.cand('LN-2', 'low', key, '%s:%d' % (n['path'], n['srcs'][1][2]), 'staging model joins sources')
                if key not in children and key not in exposed and n['layer'] != 'marts':
                    self.cand('LN-4', 'low', key, where, 'no model, test or exposure reads it (%s layer)' % n['layer'])
                st = n['star']
                if st and not st['cte'] and n['layer'] in ('marts', 'intermediate'):
                    self.cand('SC-3', 'low', key, '%s:%s' % (n['path'], st['line']),
                              'final select * from %s: shape flows from upstream' % st['from'])
            acc = n.get('access') or g('access')[0]
            contract = g('contract')[0]
            enforced = isinstance(contract, dict) and contract.get('enforced') is True
            if n['kind'] == 'model' and (str(acc).lower() == 'public' or key in exposed) and not enforced:
                self.cand('SC-1', 'medium', key, where, 'published model (%s) has no enforced contract' %
                          ('access: public' if str(acc).lower() == 'public' else 'exposure parent'))
            if enforced and mat == 'incremental' and str(g('on_schema_change')[0]).lower() not in (
                    'append_new_columns', 'fail'):
                self.cand('SC-1', 'medium', key, where, 'enforced contract on an incremental with on_schema_change '
                          '`%s` (%s): dbt requires append_new_columns or fail' % g('on_schema_change'),
                          g('on_schema_change')[1])
            if enforced and (mat in ('ephemeral', 'materialized_view') or n['lang'] == 'py'):
                self.cand('SC-1', 'low', key, where, 'contract on an unsupported materialization (%s)' % (
                    'python' if n['lang'] == 'py' else mat))
        for key, s in sorted(self.sources.items()):
            node = 'source.' + key
            where = '%s:%s' % (s['path'], s['line'])
            f = s['freshness']
            if f is None and 'explicit null' not in s['fresh_src']:
                self.cand('DQ-4', 'medium', node, where, 'source table has no freshness check')
            elif isinstance(f, dict):
                if f.get('warn_after') and not f.get('error_after'):
                    self.cand('DQ-4', 'medium', node, where, 'freshness warn_after without error_after: stale data '
                              'never fails', s['fresh_src'])
                if not s['loaded_at_field']:
                    self.cand('DQ-4', 'low', node, where, 'freshness with no loaded_at_field: dbt falls back to '
                              'warehouse metadata where it can', s['fresh_src'])
            if not any(ROWCOUNT_TESTS.search(t['test']) for t in self.tests_on(node)):
                self.cand('DQ-7', 'low', node, where, 'no row-count test: an empty load passes every column test')
            if not children.get(node):
                self.cand('LN-4', 'low', node, where, 'source declared and never read by a model')
        for t in self.tests:
            self.dq2(t)
        if self.projects and not self.exposures:
            self.cand('LN-3', 'info', 'project', rel(self.projects[0].file, self.roots),
                      'no exposures: readers outside dbt are invisible to the graph')

    def incremental_rules(self, key, n, where, g, strat, uk, adapter):
        osc, osc_src = g('on_schema_change')
        if not n['has_inc'] and strat != 'microbatch' and not uk and strat != 'insert_overwrite':
            self.cand('IN-2', 'high', key, where, 'incremental with no is_incremental() filter and no unique_key: '
                      'every run re-inserts the whole source')
        if strat not in ('insert_overwrite', 'microbatch') and not uk and n['has_inc']:
            self.cand('IN-2', 'high', key, where, 'incremental (strategy %s, %s) with no unique_key: a reprocessed '
                      'row is inserted again' % (strat, g('incremental_strategy')[1]), g('incremental_strategy')[1])
        if strat == 'append' and uk:
            self.cand('IN-2', 'medium', key, where, 'append ignores unique_key %r: no dedup happens' % (uk,),
                      g('incremental_strategy')[1])
        keys = uk if isinstance(uk, list) else ([uk] if isinstance(uk, str) else [])
        for k in keys:
            if not isinstance(k, str) or not re.match(r'^\w+$', k):
                continue
            nn = [t for t in self.tests_on(key, k.lower()) if t['test'] == 'not_null'] or \
                 [1 for c in [n['columns'].get(k.lower())] if c and 'not_null' in (c['constraints'] or [])]
            if not nn:
                self.cand('IN-2', 'medium', key, where, 'unique_key column `%s` has no not_null test: a NULL key never '
                          'matches and the merge inserts a duplicate' % k, g('unique_key')[1])
        for b in n['branches']:
            for r_ in b['rows']:
                w = '%s:%d' % (n['path'], r_['line'])
                if r_['loadcol']:
                    self.cand('IN-3', 'medium', key, w, 'incremental filter on load-time column `%s`' % r_['lhs'])
                if r_['op'] == '>' and not r_['lookback']:
                    self.cand('IN-1', 'high', key, w, "strict '>' on %s vs %s with no lookback: ties and late rows "
                              'are lost' % (r_['lhs'], r_['rhs']))
                elif not r_['lookback'] and not r_['loadcol']:
                    self.cand('IN-1', 'medium', key, w, "'>=' on %s with no lookback: rows arriving later than the "
                              'watermark are lost' % r_['lhs'])
            if b['now']:
                self.cand('IN-3', 'medium', key, '%s:%d' % (n['path'], b['line']),
                          'wall-clock function inside the incremental branch: a replay selects a different window')
        for d in n['dedup']:
            if d['order_keys'] in (0, 1) or d['order_keys'] == -1:
                self.cand('IN-5', 'medium', key, '%s:%d' % (n['path'], d['line']),
                          'dedup with %s: ties pick a different winner per run' % (
                              'one order key (%s)' % d['order'] if d['order_keys'] >= 0 else d['order']))
        if str(osc).lower() == 'ignore':
            self.cand('IN-6', 'medium', key, where, 'on_schema_change `ignore` (%s): new upstream columns never '
                      'arrive' % osc_src, osc_src)
        elif str(osc).lower() == 'sync_all_columns':
            self.cand('IN-6', 'low', key, where, 'on_schema_change sync_all_columns drops columns and changes types '
                      'without a failure', osc_src)
        if strat == 'insert_overwrite' and not g('partition_by')[0] and not g('partitions')[0]:
            self.cand('IN-7', 'medium', key, where, 'insert_overwrite with no partition_by/partitions: read which '
                      'scope the adapter replaces')
        if strat == 'microbatch':
            miss = [k for k in ('event_time', 'begin', 'batch_size') if not g(k)[0]]
            if miss:
                self.cand('IN-9', 'high', key, where, 'microbatch missing %s' % ', '.join(miss))
            for parent, _, line in n['refs']:
                pn = self.nodes.get(self.resolve_ref(parent))
                if pn and not pn['cfg'].get('event_time', (None,))[0]:
                    self.cand('IN-9', 'medium', key, '%s:%d' % (n['path'], line),
                              'parent %s has no event_time: read in full for every batch' % parent)
            if 'postgres' in adapter and not g('unique_key')[0]:
                self.cand('IN-9', 'high', key, where, 'microbatch on Postgres (merge) with no unique_key')
            if any(a in adapter for a in ('bigquery', 'spark', 'databricks')) and not g('partition_by')[0]:
                self.cand('IN-9', 'high', key, where, 'microbatch on %s (insert_overwrite) with no partition_by' % adapter)
        if g('partition_by')[0] and strat in ('merge', 'adapter-default') and uk and not g('incremental_predicates')[0]:
            self.cand('CO-2', 'medium', key, where, 'merge into a partitioned target with no incremental_predicates: '
                      'the merge scans the whole destination')
        if (n['window'] or n['case_logic']) and n['name'] not in self.unit_tests:
            self.cand('DQ-8', 'low', key, where, 'incremental with %s logic and no unit test' % (
                'window' if n['window'] else 'CASE'))
        if not any(ROWCOUNT_TESTS.search(t['test']) for t in self.tests_on(key)):
            self.cand('DQ-7', 'low', key, where, 'incremental with no row-count test: a zero-row run passes')

    def test_rules(self, key, n, where, adapter):
        tests = self.tests_on(key)
        cols_u = set(t['column'] for t in tests if t['test'] == 'unique' and t['cfg'].get('enabled') is not False)
        cols_nn = set(t['column'] for t in tests if t['test'] == 'not_null')
        combo = [t for t in tests if t['test'].endswith('unique_combination_of_columns')
                 or t['test'] == 'dbt_constraints.primary_key']
        pk_enforced = 'postgres' in adapter and isinstance(n['cfg'].get('contract', (None,))[0], dict) and \
            n['cfg']['contract'][0].get('enforced') is True and (
                any('primary_key' in (c['constraints'] or []) for c in n['columns'].values()) or
                any(c.get('type') == 'primary_key' for c in n['constraints']))
        if not ((cols_u & cols_nn) or combo or pk_enforced):
            self.cand('DQ-1', 'medium', key, where, 'no grain test (unique + not_null on one column, or '
                      'unique_combination_of_columns) on a %s model' % n['layer'])
        has_pk_test = bool(cols_u or combo)
        for cn, c in n['columns'].items():
            for ct in c['constraints'] or []:
                if ct in ('primary_key', 'unique', 'foreign_key') and 'postgres' not in adapter:
                    if not (ct != 'foreign_key' and (cn in cols_u or has_pk_test)) and not (
                            ct == 'foreign_key' and self.tests_on(key, cn)):
                        self.cand('SC-1', 'medium', key, '%s:%s' % (n.get('yml'), c['line']),
                                  '%s constraint on `%s` is metadata-only on adapter %s and no data test covers it' % (
                                      ct, cn, adapter))
        for t in tests:
            if t['test'] == 'relationships' and t['column'] and t['column'] not in cols_nn:
                self.cand('DQ-5', 'medium', key, '%s:%s' % (t['path'], t['line']),
                          'relationships on nullable `%s`: NULLs pass by design' % t['column'])
            if t['test'] == 'accepted_values':
                vals = t['args'].get('values') or []
                if vals and all(isinstance(v, (int, float, bool)) for v in vals) and t['args'].get('quote') is not False:
                    self.cand('DQ-5', 'low', key, '%s:%s' % (t['path'], t['line']),
                              'accepted_values with numeric values and no quote: false')
        parents = [key] + [self.resolve_ref(p[0]) for p in n['refs']]
        for col, lits in sorted(n['case'].items()):
            av = [t for p in parents for t in self.tests_on(p, col) if t['test'] == 'accepted_values']
            if not av:
                self.cand('DQ-5', 'medium', key, where, 'CASE branches on `%s` (%s) and no accepted_values pins its '
                          'members: a new value falls into ELSE silently' % (col, ', '.join(sorted(lits))[:60]))
            else:
                allowed = set(str(v) for t in av for v in (t['args'].get('values') or []))
                extra = sorted(lits - allowed)
                if allowed and extra:
                    self.cand('DQ-5', 'low', key, where, 'CASE literal(s) %s on `%s` are not in accepted_values' % (
                        ', '.join(extra)[:60], col))
        if ROLLUP.search(n['name']):
            if not any(RECON_TESTS.search(t['test']) for t in tests) and not any(
                    n['name'] in s['refs'] and (set(s['refs']) - {n['name']} or s['sources']) for s in self.singular):
                self.cand('DQ-6', 'medium', key, where, 'rollup model with no test comparing it with its detail')

    def dq2(self, t):
        w = '%s:%s' % (t['path'], t['line'])
        target = t['node'] + ('.' + t['column'] if t['column'] else '')
        sev, ssrc = t['severity']
        grain = t['test'] in GRAIN_TESTS or t['test'].endswith('unique_combination_of_columns')
        if sev == 'warn' and grain:
            self.cand('DQ-2', 'medium', target, w, '%s with severity warn (%s): the build exits 0 on a failure' % (
                t['test'], ssrc), ssrc)
        wh = t['cfg'].get('where')
        if isinstance(wh, str) and (NOWFN.search(wh) or re.search(r'var\s*\(|\{\{', wh)):
            self.cand('DQ-2', 'medium', target, w, '%s where: %r can select an empty slice' % (t['test'], wh[:60]))
        if t['cfg'].get('enabled') is False:
            self.cand('DQ-2', 'medium', target, w, '%s disabled (enabled: false)' % t['test'])
        for k in ('error_if', 'warn_if'):
            v = t['cfg'].get(k)
            if k == 'error_if' and v is not None and not re.match(r'^\s*(!=\s*0|>\s*0|>=\s*1)\s*$', str(v)):
                self.cand('DQ-2', 'low', target, w, '%s error_if %r: failures below it pass' % (t['test'], v))
        if t['cfg'].get('store_failures') is True and sev == 'warn':
            self.cand('DQ-2', 'info', target, w, 'store_failures records rows; with severity warn nothing fails')


def rel(p, roots):
    ap = os.path.abspath(p)
    for r in roots:
        ar = os.path.abspath(r)
        if ap == ar or ap.startswith(ar.rstrip(os.sep) + os.sep):
            return os.path.relpath(ap, ar).replace('\\', '/') if len(roots) == 1 else os.path.join(
                os.path.basename(ar.rstrip(os.sep)), os.path.relpath(ap, ar)).replace('\\', '/')
    return p


# ----------------------------------------------------------------------------- output
def cell(v):
    if isinstance(v, (dict, list)):
        v = json.dumps(v, sort_keys=True, default=str)
    return str(v).replace('\t', ' ').replace('\n', ' ')


def write_tables(g, out):
    def tsv(name, header, rows):
        with open(os.path.join(out, name), 'w', encoding='utf-8') as fh:
            fh.write('\t'.join(header) + '\n')
            for r in rows:
                fh.write('\t'.join(cell(x) for x in r) + '\n')
    mrows = []
    for key, n in sorted(g.nodes.items()):
        row = [n['project'], key, n['path'], n['file_cfg_line'] or n.get('line') or '', n['layer']]
        for k in FIELD[5:]:
            v = n['cfg'].get(k)
            if k == 'access' and n.get('access') is not None and v is None:
                v = (n['access'], n.get('yml', ''))
            row.append('' if v is None else '%s ← %s' % (cell(v[0]), v[1]))
        mrows.append(row)
    tsv('models.tsv', FIELD, mrows)
    tsv('edges.tsv', ['child', 'parent', 'kind', 'where'], g.edges)
    tsv('tests.tsv', ['node', 'column', 'test', 'severity', 'severity_source', 'where', 'enabled', 'error_if',
                      'warn_if', 'store_failures', 'args', 'at'],
        [[t['node'], t['column'], t['test'], t['severity'][0], t['severity'][1], t['cfg'].get('where', ''),
          t['cfg'].get('enabled', ''), t['cfg'].get('error_if', ''), t['cfg'].get('warn_if', ''),
          t['cfg'].get('store_failures', ''), t['args'], '%s:%s' % (t['path'], t['line'])] for t in g.tests])
    tsv('sources.tsv', ['source', 'freshness', 'freshness_source', 'loaded_at_field', 'at'],
        [[k, s['freshness'], s['fresh_src'], s['loaded_at_field'] or '', '%s:%s' % (s['path'], s['line'])]
         for k, s in sorted(g.sources.items())])
    tsv('snapshots.tsv', ['snapshot', 'at', 'strategy', 'unique_key', 'updated_at', 'check_cols', 'hard_deletes',
                          'invalidate_hard_deletes'],
        [[k, '%s:%s' % (n['path'], n.get('line')), *[('%s ← %s' % (cell(n['cfg'][c][0]), n['cfg'][c][1])
                                                       if c in n['cfg'] else '') for c in
                                                      ('strategy', 'unique_key', 'updated_at', 'check_cols',
                                                       'hard_deletes', 'invalidate_hard_deletes')]]
         for k, n in sorted(g.nodes.items()) if n['kind'] == 'snapshot'])
    tsv('incremental.tsv', ['node', 'at', 'lhs', 'op', 'rhs', 'lookback', 'load_column', 'wall_clock'],
        [[k, '%s:%d' % (n['path'], r['line']), r['lhs'], r['op'], r['rhs'], r['lookback'], r['loadcol'], r['now']]
         for k, n in sorted(g.nodes.items()) for b in n['branches'] for r in b['rows']])
    tsv('candidates.tsv', ['class', 'severity', 'node', 'at', 'evidence', 'config_source'],
        [[c['class'], c['sev'], c['node'], c['where'], c['msg'], c['src']] for c in g.cands])
    tsv('manifest-diff.tsv', ['kind', 'node', 'key', 'manifest', 'disk', 'disk_source'], g.manifest_rows)
    with open(os.path.join(out, 'graph.json'), 'w', encoding='utf-8') as fh:
        json.dump(as_json(g), fh, indent=1, sort_keys=True, default=str)


def as_json(g):
    nodes = {}
    for k, n in g.nodes.items():
        nodes[k] = dict((x, n[x]) for x in ('kind', 'name', 'project', 'path', 'layer', 'lang') if x in n)
        nodes[k]['config'] = dict((c, {'value': v[0], 'source': v[1]}) for c, v in n['cfg'].items())
        nodes[k]['incremental_filters'] = [r for b in n['branches'] for r in b['rows']]
    return {'projects': [{'name': p.name, 'file': rel(p.file, g.roots), 'require_dbt_version': p.require}
                         for p in g.projects],
            'adapters': g.adapters, 'dbt_version': g.dbt_version, 'nodes': nodes,
            'edges': [list(e) for e in g.edges], 'sources': g.sources,
            'tests': [dict((k, t[k]) for k in ('node', 'column', 'test', 'cfg', 'args', 'path', 'line', 'severity'))
                      for t in g.tests],
            'exposures': g.exposures, 'unit_tests': sorted(g.unit_tests), 'candidates': g.cands,
            'manifest_diff': g.manifest_rows, 'ledger': g.ledger}


def report(g, out, classes, show):
    p = print
    p('model-graph — roots: %s · out: %s' % (' '.join(g.roots), out))
    for pr in g.projects:
        p('dbt project %s (%s)%s' % (pr.name, rel(pr.file, g.roots),
                                     ' require-dbt-version %s' % pr.require if pr.require else ''))
    p('adapter: %s %s' % (g.adapter(), ' '.join('%s@%s' % (a, w[0]) for a, w in sorted(g.adapters.items()))))
    p('dbt version: %s' % (', '.join('%s (%s)' % v for v in g.dbt_version) or 'unknown (no pin, no '
                                                                                 'require-dbt-version)'))
    kinds = {}
    for n in g.nodes.values():
        kinds[n['kind']] = kinds.get(n['kind'], 0) + 1
    layers = {}
    for n in g.nodes.values():
        if n['kind'] == 'model':
            layers[n['layer']] = layers.get(n['layer'], 0) + 1
    inc = sum(1 for n in g.nodes.values() if str(n['cfg'].get('materialized', ('',))[0]).lower() == 'incremental')
    p('nodes: %s · %d source tables · %d tests · %d exposures · %d unit-tested models · %d incremental' % (
        ' · '.join('%d %s' % (v, k) for k, v in sorted(kinds.items())), len(g.sources), len(g.tests),
        len(g.exposures), len(g.unit_tests), inc))
    p('layers: %s' % (' · '.join('%s %d' % kv for kv in sorted(layers.items())) or 'none'))
    tl = {}
    for t in g.tests:
        n = g.nodes.get(t['node'])
        lay = n['layer'] if n else 'source'
        tl[lay] = tl.get(lay, 0) + 1
    p('tests per layer: %s' % (' · '.join('%s %d' % kv for kv in sorted(tl.items())) or 'none'))
    ek = {}
    for e in g.edges:
        k = e[2] if not e[1].startswith('unresolved:') else 'unresolved'
        ek[k] = ek.get(k, 0) + 1
    p('edges: %d (%s)' % (len(g.edges), ', '.join('%s %d' % kv for kv in sorted(ek.items()))))
    mr = [r for r in g.manifest_rows if r[0] != 'manifest']
    hdr = [r for r in g.manifest_rows if r[0] == 'manifest']
    p('manifest: %s' % ('; '.join('%s generated_at %s dbt %s — %d difference(s) with the files → manifest-diff.tsv'
                                  % (h[1], h[3], h[4], len(mr)) for h in hdr) if hdr else
                        ('off' if g.manifest == 'off' else 'none committed (static parse only)')))
    cc = {}
    for c in g.cands:
        fam = c['class'].split('-')[0]
        cc[fam] = cc.get(fam, 0) + 1
    p('candidates: %d (%s) → candidates.tsv' % (len(g.cands), ', '.join('%s %d' % kv for kv in sorted(cc.items()))))
    for c in g.cands:
        if not classes or c['class'] in classes or c['class'].split('-')[0] in classes:
            p('[%s] %-7s %s  %s — %s' % (c['class'], c['sev'], c['where'], c['node'], c['msg']))
    if 'configs' in show:
        p('\n# effective configs (value ← source)')
        for key, n in sorted(g.nodes.items()):
            if n['kind'] == 'seed':
                continue
            p('%s  %s' % (key, '  '.join('%s=%s ← %s' % (k, cell(v[0]), v[1]) for k, v in sorted(n['cfg'].items())
                                         if k in FIELD or n['kind'] == 'snapshot')))
    if 'tests' in show:
        p('\n# tests (node · column · test · severity ← source · where)')
        for t in g.tests:
            p('%s  %s  %s  %s ← %s  %s:%s%s' % (t['node'], t['column'] or '-', t['test'], t['severity'][0],
                                                t['severity'][1], t['path'], t['line'],
                                                '  where=%s' % t['cfg']['where'] if 'where' in t['cfg'] else ''))
    if 'edges' in show:
        p('\n# edges (child → parent · kind · at)')
        for e in g.edges:
            p('%s → %s  %s  %s' % e)
    led = g.ledger
    sys.stderr.write('ledger: files %s; unreadable %d; yaml not understood %d; python models not parsed %d\n' % (
        json.dumps(led['files'], sort_keys=True), len(led['unreadable']), len(led['yaml_not_understood']),
        len(led['sql_not_understood'])))
    for k in ('unreadable', 'yaml_not_understood', 'sql_not_understood'):
        for x in led[k]:
            sys.stderr.write('  %s: %s\n' % (k, x))


def inside(child, parent):
    c, p = os.path.realpath(child), os.path.realpath(parent)
    return c == p or c.startswith(p.rstrip(os.sep) + os.sep)


def main(argv):
    if '--self-test' in argv:
        return self_test()
    roots, out, classes, show, js, inc_pk, manifest = [], None, set(), set(), False, False, 'auto'
    for a in argv:
        if a.startswith('--out='):
            out = a[6:]
        elif a.startswith('--class='):
            classes = set(x.strip().upper() for x in a[8:].split(',') if x.strip())
        elif a.startswith('--manifest='):
            manifest = a[11:]
        elif a in ('--configs', '--tests', '--edges'):
            show.add(a[2:])
        elif a == '--json':
            js = True
        elif a == '--include-packages':
            inc_pk = True
        elif a in ('-h', '--help'):
            print(__doc__)
            return 0
        elif a.startswith('-'):
            sys.stderr.write('unknown option %s\n' % a)
            return 1
        else:
            roots.append(a)
    if not roots:
        sys.stderr.write('usage: model-graph.py <root> [<root> ...] [--out=<dir>] (see --help)\n')
        return 1
    for r in roots:
        if not os.path.isdir(r):
            sys.stderr.write('model-graph: root %s is not a directory\n' % r)
            return 2
    if out:
        for r in roots:
            if inside(out, r):
                sys.stderr.write('model-graph: --out %s is inside the scanned root %s — refused (this script never '
                                 'writes into the repo it reads)\n' % (out, r))
                return 2
        os.makedirs(out, exist_ok=True)
    else:
        out = tempfile.mkdtemp(prefix='model-graph.')
    g = Graph(roots, include_packages=inc_pk, manifest=manifest)
    try:
        built = g.build()
    except ValueError as e:
        sys.stderr.write('model-graph: %s\n' % e)
        return 2
    if not built:
        print('model-graph — roots: %s · dbt: absent (no dbt_project.yml under the roots; dbt_packages/ and '
              'target/ skipped) — every dbt § is N/A' % ' '.join(roots))
        return 4
    write_tables(g, out)
    if js:
        json.dump(as_json(g), sys.stdout, indent=1, sort_keys=True, default=str)
        sys.stdout.write('\n')
    else:
        report(g, out, classes, show)
    return 0


# ----------------------------------------------------------------------------- self-test
SAMPLE = {
    'dbt_project.yml': """name: shop
version: '1.0'
require-dbt-version: [">=1.9.0", "<2.0.0"]
model-paths: ["models"]
models:
  shop:
    +materialized: view
    staging:
      +materialized: view
    marts:
      +materialized: table
      events:
        +on_schema_change: append_new_columns   # project-level, by path
data_tests:
  shop:
    +severity: error
""",
    'requirements.txt': "dbt-core==1.9.4\ndbt-snowflake==1.9.1\n",
    'models/staging/_sources.yml': """version: 2
sources:
  - name: raw
    loaded_at_field: _loaded_at
    freshness: {warn_after: {count: 12, period: hour}}
    tables:
      - name: orders
        columns:
          - name: id
            data_tests: [unique, not_null]
      - name: customers
        freshness:
          warn_after: {count: 1, period: day}
          error_after: {count: 2, period: day}
      - name: country_codes
        freshness: null
  - name: app
    tables:
      - name: unused_feed
""",
    'models/staging/stg_shipments.sql': """{{ config(materialized='view') }}
-- staging passthrough
select id, customer_id, status, amount, updated_at, _loaded_at
from {{ source('raw', 'orders') }}
""",
    'models/staging/stg_accounts.sql': """select * from {{ source('raw', 'customers') }} c
join {{ source('raw', 'country_codes') }} k on k.code = c.country
""",
    'models/staging/stg_invoices.sql': """select * from analytics_raw.payments  -- hard-coded
where extract(day from payments.created_at) > 0
""",
    'models/marts/fct_shipments.sql': """{{
  config(
    materialized = 'incremental',
    unique_key = 'order_id',
    incremental_strategy = 'merge',
    partition_by = {'field': 'updated_at', 'data_type': 'timestamp'},
  )
}}
with src as (
  select *, row_number() over (partition by id order by updated_at desc) as rn
  from {{ ref('stg_shipments') }}
)
select id as order_id, customer_id, status,
       case when status = 'paid' then amount when status = 'refunded' then -amount else 0 end as net,
       updated_at
from src where rn = 1
{% if is_incremental() %}
  and updated_at > (select max(updated_at) from {{ this }})
{% endif %}
""",
    'models/marts/events/fct_pageviews.sql': """{{ config(materialized='incremental') }}
select event_id, payload, _loaded_at from {{ ref('stg_shipments') }}
{% if is_incremental() %}
where _loaded_at >= (select coalesce(max(_loaded_at), '1900-01-01') from {{ this }}) - interval '3 days'
{% endif %}
""",
    'models/marts/fct_visits.sql': """{{ config(materialized='incremental', unique_key=['session_id', 'day'],
    incremental_strategy='append', on_schema_change='fail') }}
select session_id, day, count(*) over (partition by session_id) as n from {{ ref('stg_shipments') }}
{% if not is_incremental() %}
where day > '2020-01-01'
{% else %}
where day >= (select max(day) from {{ this }})
{% endif %}
""",
    'models/marts/fct_taps.sql': """{{ config(materialized='incremental', incremental_strategy='microbatch',
    event_time='clicked_at', unique_key=none) }}
select * from {{ ref('stg_shipments') }}
""",
    'models/marts/shipments_daily.sql': """{{ config(materialized='table') }}
select date_trunc('day', updated_at) d, count(*) n from {{ ref('fct_shipments') }} group by 1
""",
    'models/marts/invoices_daily.sql': """select day, sum(amount) from {{ ref('stg_invoices') }} group by 1
""",
    'models/marts/dim_accounts.sql': """select customer_id, name from {{ ref('stg_accounts') }}
""",
    'models/marts/py_scores.py': """def model(dbt, session):
    dbt.config(materialized="incremental", unique_key="customer_id")
    df = dbt.ref("dim_accounts")
    if dbt.is_incremental:
        pass
    return df.dropDuplicates(["customer_id"])
""",
    'models/marts/_marts.yml': """version: 2
models:
  - name: fct_shipments
    access: public
    config:
      contract: {enforced: true}
      on_schema_change: ignore
    columns:
      - name: order_id
        data_type: varchar
        constraints:
          - type: primary_key
        data_tests:
          - unique
          - not_null:
              config:
                severity: warn
      - name: customer_id
        data_tests:
          - relationships:
              arguments:
                to: ref('dim_accounts')
                field: customer_id
      - name: status
        data_tests:
          - accepted_values:
              values: ['paid', 'pending']
          - not_null:
              where: "updated_at > current_date - 1"
  - name: dim_accounts
    data_tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns: [customer_id]
    columns:
      - name: customer_id
        tests:
          - unique:
              enabled: false
  - name: fct_visits
    columns:
      - name: session_id
        constraints: [{type: primary_key}]
        data_tests: [not_null]
      - name: kind
        data_tests:
          - accepted_values:
              values: [1, 2, 3]
              config: {error_if: ">100"}
exposures:
  - name: finance_dashboard
    type: dashboard
    owner: {name: Finance, email: f@example.com}
    depends_on:
      - ref('fct_shipments')
unit_tests:
  - name: t_sessions
    model: fct_visits
    given: []
""",
    'snapshots/orders_snapshot.sql': """{% snapshot orders_snapshot %}
{{ config(target_schema='snapshots', unique_key='id', strategy='timestamp', updated_at='updated_at') }}
select * from {{ source('raw', 'orders') }}
{% endsnapshot %}
""",
    'snapshots/snaps.yml': """snapshots:
  - name: customers_snapshot
    relation: source('raw', 'customers')
    config:
      unique_key: id
      strategy: check
      check_cols: all
      hard_deletes: invalidate
""",
    'tests/assert_shipments_daily_matches.sql': """select 1 from {{ ref('shipments_daily') }} d
join {{ ref('fct_shipments') }} o on true where false
""",
    'seeds/country_map.csv': "code,name\nSA,Saudi Arabia\n",
    # dbt versioned models (_vN files + one YAML entry with versions:) and an exposure pinned to a version
    'models/marts/dim_products_v1.sql': "select customer_id as product_id from {{ ref('stg_accounts') }}\n",
    'models/marts/dim_products_v2.sql': "select customer_id as product_id, 1 as price from {{ ref('stg_accounts') }}\n",
    'models/marts/dim_zones_v1.sql': "select customer_id as zone_id from {{ ref('stg_accounts') }}\n",
    'models/marts/dim_zones_v2.sql': "select customer_id as zone_id, 1 as tier from {{ ref('stg_accounts') }}\n",
    'models/marts/_versions.yml': """models:
  - name: dim_products
    access: public
    latest_version: 2
    config:
      contract: {enforced: true}
    columns:
      - name: product_id
        data_type: int
        data_tests: [unique, not_null]
    versions:
      - v: 1
        deprecation_date: 2026-12-01
      - v: 2
  - name: dim_zones
    latest_version: 2
    columns:
      - name: zone_id
        data_tests: [unique, not_null]
    versions:
      - v: 1
      - v: 2
exposures:
  - name: zone_board
    type: dashboard
    owner: {name: Ops, email: o@example.com}
    depends_on:
      - ref('dim_zones', v=1)
""",
}


def self_test():
    ok, bad = [0], []

    def check(name, cond):
        if cond:
            ok[0] += 1
        else:
            bad.append(name)

    # YAML subset
    y = load_yaml("a: 1\nb:\n  - x\n  - {k: v, l: [1, 2]}\nc: 'it''s'\nd: \"q: \\\"x\\\"\"  # c\ne: |\n  l1\n  l2\nf: null\n")
    check('yaml scalars', y['a'] == 1 and y['c'] == "it's" and y['f'] is None)
    check('yaml seq of flow map', y['b'][1] == {'k': 'v', 'l': [1, 2]})
    check('yaml block scalar', y['e'] == 'l1\nl2')
    check('yaml escaped dq', y['d'] == 'q: "x"')
    y2 = load_yaml("models:\n- name: m\n  columns:\n  - name: c\n    tests:\n      - unique\n")
    check('yaml seq at key indent', y2['models'][0]['columns'][0]['tests'] == ['unique'])
    check('yaml line numbers', y2['models'].ilines == [2] and y2['models'][0].klines['columns'] == 3)
    check('yaml comment not in quotes', load_yaml("w: 'a # b'  # real\n")['w'] == 'a # b')
    check('yaml plain continuation', load_yaml("d: one\n  two\nx: 1\n") == {'d': 'one two', 'x': 1})
    check('flow with ref()', flow("{to: ref('a', 'b'), field: id}") == {'to': "ref('a', 'b')", 'field': 'id'})
    check('yaml multi-line flow', load_yaml("a: {x: 1,\n  y: [2,\n 3]}\n")['a'] == {'x': 1, 'y': [2, 3]})
    # Jinja / SQL
    kw, pa = parse_kwargs("materialized='incremental', unique_key=['a','b'], full_refresh=false, x=var('y')")
    check('kwargs literals', kw['unique_key'] == ['a', 'b'] and kw['full_refresh'] is False)
    check('kwargs expr', str(kw['x']).startswith('<expr:'))
    kw2, _ = parse_kwargs("alias='a' ~ var('s'), unique_key='id'")
    check('kwargs fallback split', kw2.get('unique_key') == 'id')
    check('refs two-arg', refs_in("{{ ref('pkg', 'm') }} {{ ref(\"n\", v=2) }}") == [('m', 'pkg', 1), ('n', '', 1)])
    check('strip comments keeps lines', strip_comments("a -- x\n/* y\n*/ b {# z #}").count('\n') == 2)
    check('quoted -- kept', "'--x'" in strip_comments("select '--x'"))
    br = incremental_branches("{% if not is_incremental() %}A{% else %}B{% endif %}{% if is_incremental() %}"
                              "{% if x %}C{% endif %}D{% endif %}")
    check('branches: not/else and nested', len(br) == 2)
    rows = analyse_branch("where ts > (select max(ts) from {{ this }})", 0, 44)
    check('strict > found', rows and rows[0]['op'] == '>' and not rows[0]['lookback'])
    rows = analyse_branch("where ts >= (select max(ts) from {{ this }}) - interval '2 day'", 0, 64)
    check('lookback found', rows and rows[0]['lookback'])
    check('dedup one key', dedup_windows("row_number() over (partition by a order by b desc)")[0]['order_keys'] == 1)
    check('dedup two keys', dedup_windows("row_number() over (partition by a order by b, coalesce(c, 1))")[0]['order_keys'] == 2)
    check('raw relation', raw_relations("select * from raw.orders join {{ ref('x') }} y on 1=1")[0][0] == 'raw.orders')
    check('raw skips extract', raw_relations("select extract(day from t.created_at) from {{ ref('a') }}") == [])
    check('case literals', case_literals("case when status = 'paid' then 1 when status in ('a','b') then 2 end")
          == {'status': {'paid', 'a', 'b'}})
    st = final_select_star("with final as (select 1) select * from final")
    check('select * from cte', st is not None and st['cte'])
    # project
    tmp = tempfile.mkdtemp(prefix='model-graph-selftest.')
    try:
        root = os.path.join(tmp, 'repo')
        for p, body in SAMPLE.items():
            fp = os.path.join(root, p)
            os.makedirs(os.path.dirname(fp), exist_ok=True)
            with open(fp, 'w', encoding='utf-8') as fh:
                fh.write(body)
        os.makedirs(os.path.join(root, 'dbt_packages', 'x'))
        with open(os.path.join(root, 'dbt_packages', 'x', 'dbt_project.yml'), 'w') as fh:
            fh.write('name: pkg\n')
        g = Graph([root], manifest='off')
        check('build', g.build())
        check('packages skipped', len(g.projects) == 1)
        C = lambda cls, node, frag='': [c for c in g.cands if c['class'] == cls and c['node'] == node and frag in c['msg']]
        check('adapter from pin', g.adapter() == 'snowflake')
        check('dbt >= 1.9', g.dbt_ge(1, 9) is True)
        fo = g.nodes['model.fct_shipments']['cfg']
        check('file config wins', fo['materialized'][0] == 'incremental' and 'config()' in fo['materialized'][1])
        check('yml config over project', fo['on_schema_change'][0] == 'ignore' and '_marts.yml' in fo['on_schema_change'][1])
        fe = g.nodes['model.fct_pageviews']['cfg']
        check('project path config', fe['on_schema_change'][0] == 'append_new_columns' and 'dbt_project.yml' in fe['on_schema_change'][1])
        sc = g.nodes['model.stg_accounts']['cfg']['materialized']
        check('deepest project level', sc[0] == 'view' and 'models.shop.staging.+materialized' in sc[1])
        check('default on_schema_change', g.nodes['model.fct_taps']['cfg']['on_schema_change'] == ('ignore', 'default'))
        check('IN-1 strict', C('IN-1', 'model.fct_shipments', "strict '>'"))
        check('IN-1 not on lookback', not C('IN-1', 'model.fct_pageviews'))
        check('IN-3 load column', C('IN-3', 'model.fct_pageviews', '_loaded_at'))
        check('IN-2 no key', C('IN-2', 'model.fct_pageviews', 'no unique_key'))
        check('IN-2 append ignores key', C('IN-2', 'model.fct_visits', 'append ignores'))
        check('IN-2 nullable key', C('IN-2', 'model.fct_visits', '`day`'))
        check('IN-2 key with not_null not flagged', not C('IN-2', 'model.fct_visits', '`session_id`'))
        check('IN-1 else-branch of not is_incremental', C('IN-1', 'model.fct_visits', "'>='"))
        check('IN-5 one order key', C('IN-5', 'model.fct_shipments', 'one order key'))
        check('IN-5 python dropDuplicates', C('IN-5', 'model.py_scores'))
        check('IN-6 default ignore via yml', C('IN-6', 'model.fct_shipments', 'ignore'))
        check('IN-6 not on append_new_columns', not C('IN-6', 'model.fct_pageviews'))
        check('IN-9 microbatch missing', C('IN-9', 'model.fct_taps', 'begin, batch_size'))
        check('IN-9 parent without event_time', C('IN-9', 'model.fct_taps', 'stg_shipments'))
        check('IN-4 legacy snapshot default', C('IN-4', 'snapshot.orders_snapshot', 'ignore'))
        check('IN-4 yml snapshot handles deletes', not C('IN-4', 'snapshot.customers_snapshot', 'ignore'))
        check('IN-4 check_cols all', C('IN-4', 'snapshot.customers_snapshot', 'check_cols'))
        check('snapshot yml relation edge', any(e[0] == 'snapshot.customers_snapshot' and e[1] == 'source.raw.customers' for e in g.edges))
        check('CO-2 merge partitioned', C('CO-2', 'model.fct_shipments'))
        check('DQ-1 missing grain', C('DQ-1', 'model.fct_pageviews') and not C('DQ-1', 'model.dim_accounts'))
        check('DQ-1 fct_shipments has grain', not C('DQ-1', 'model.fct_shipments'))
        check('DQ-2 warn on not_null', C('DQ-2', 'model.fct_shipments.order_id', 'severity warn'))
        check('DQ-2 where slice', C('DQ-2', 'model.fct_shipments.status', 'where'))
        check('DQ-2 disabled', C('DQ-2', 'model.dim_accounts.customer_id', 'disabled'))
        check('DQ-2 error_if', C('DQ-2', 'model.fct_visits.kind', 'error_if'))
        check('DQ-4 no freshness', C('DQ-4', 'source.app.unused_feed', 'no freshness') and not C('DQ-4', 'source.raw.country_codes'))
        check('DQ-4 warn only (inherited)', C('DQ-4', 'source.raw.orders', 'warn_after'))
        check('DQ-4 table override has error_after', not C('DQ-4', 'source.raw.customers', 'warn_after'))
        check('DQ-5 relationships nullable', C('DQ-5', 'model.fct_shipments', 'relationships'))
        check('DQ-5 case literal not in accepted', C('DQ-5', 'model.fct_shipments', 'refunded'))
        check('DQ-5 numeric accepted_values', C('DQ-5', 'model.fct_visits', 'quote'))
        check('DQ-6 rollup has singular test', not C('DQ-6', 'model.shipments_daily'))
        check('DQ-8 unit test respected', not C('DQ-8', 'model.fct_visits') and C('DQ-8', 'model.fct_shipments'))
        check('LN-1 hard-coded', C('LN-1', 'model.stg_invoices', 'analytics_raw.payments'))
        check('LN-2 staging joins sources', C('LN-2', 'model.stg_accounts'))
        check('LN-4 unused source', C('LN-4', 'source.app.unused_feed') and not C('LN-4', 'source.raw.orders'))
        check('DQ-6 rollup without recon', C('DQ-6', 'model.invoices_daily'))
        check('SC-1 pk metadata-only on snowflake', C('SC-1', 'model.fct_visits', 'metadata-only'))
        check('SC-3 select * in marts', C('SC-3', 'model.fct_taps'))
        check('IN-7/CO-3 quiet', not [c for c in g.cands if c['class'] in ('IN-7', 'CO-3')])
        check('SC-1 constraint metadata-only', C('SC-1', 'model.fct_shipments', 'metadata-only') == [])
        check('SC-1 contract + ignore', C('SC-1', 'model.fct_shipments', 'append_new_columns or fail'))
        check('python model refs', any(e[0] == 'model.py_scores' and e[1] == 'model.dim_accounts' for e in g.edges))
        # versioned models: base tests, access and contract reach every version; an exposure pin picks one
        check('_vN version_of', g.nodes['model.dim_products_v2'].get('version_of') == 'dim_products'
              and g.nodes['model.dim_products_v2'].get('version_n') == 2)
        check('_vN inherits base grain tests (no DQ-1)', not C('DQ-1', 'model.dim_products_v1') and not C('DQ-1', 'model.dim_products_v2'))
        check('_vN inherits access + enforced contract (no SC-1)', not C('SC-1', 'model.dim_products_v2', 'no enforced contract'))
        check('_vN per-version deprecation_date', str(g.nodes['model.dim_products_v1'].get('deprecation_date')) == '2026-12-01')
        check('_vN exposure pin flags the pinned version', C('SC-1', 'model.dim_zones_v1', 'exposure parent'))
        check('_vN exposure pin spares the other version', not C('SC-1', 'model.dim_zones_v2'))
        check('test severity source', [t for t in g.tests if t['test'] == 'unique' and t['node'] == 'model.fct_shipments'][0]['severity'][1].startswith('dbt_project.yml'))
        # manifest cross-check
        os.makedirs(os.path.join(root, 'target'))
        with open(os.path.join(root, 'target', 'manifest.json'), 'w') as fh:
            json.dump({'metadata': {'generated_at': '2026-01-01', 'dbt_version': '1.9.4'},
                       'nodes': {'model.shop.fct_pageviews': {'resource_type': 'model', 'name': 'fct_pageviews',
                                                           'config': {'materialized': 'table'},
                                                           'depends_on': {'nodes': ['model.shop.stg_shipments']}}}}, fh)
        g2 = Graph([root], manifest='auto')
        g2.build()
        check('manifest diff', any(r[0] == 'config-differs' and r[2] == 'materialized' for r in g2.manifest_rows))
        # CLI contracts
        tree = lambda d: sorted(os.path.join(a, f) for a, _, fs in os.walk(d) for f in fs)
        before = tree(root)
        out_in = os.path.join(root, 'out')
        empty = os.path.join(tmp, 'empty')
        os.makedirs(empty)
        devnull = open(os.devnull, 'w')
        so, se = sys.stdout, sys.stderr
        sys.stdout = sys.stderr = devnull
        try:
            check('refuse --out inside root', main([root, '--out=' + out_in]) == 2 and not os.path.exists(out_in))
            check('exit 4 without project', main([empty]) == 4)
            outd = os.path.join(tmp, 'o')
            check('exit 0 with project', main([root, '--out=' + outd, '--manifest=off']) == 0)
            check('tables written', all(os.path.isfile(os.path.join(outd, f)) for f in (
                'models.tsv', 'edges.tsv', 'tests.tsv', 'candidates.tsv', 'graph.json')))
            check('missing root exit 2', main([os.path.join(tmp, 'nope')]) == 2)
            check('usage exit 1', main([]) == 1)
        finally:
            sys.stdout, sys.stderr = so, se
            devnull.close()
        check('nothing written into root', tree(root) == before)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    total = ok[0] + len(bad)
    if bad:
        print('model-graph --self-test: %d/%d OK; FAILED: %s' % (ok[0], total, ', '.join(bad)))
        return 3
    print('model-graph --self-test: %d/%d OK' % (ok[0], total))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
