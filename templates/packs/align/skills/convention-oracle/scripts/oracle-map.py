#!/usr/bin/env python3
"""oracle-map.py — convention-oracle § 0: one row per convention rule the project DECLARES, tagged by where
the declaration comes from, so no align detector ever enforces a rule nobody wrote (AL-01) or a majority a
setup run wrote down (T2g).

Why a script and not rg: whether a rule is a Finding depends on WHERE it is declared and HOW STRONGLY. A rule
at `error` in the flat config that CI lints is law; the same sentence inside `<!-- refine-enriched -->` is a
sampled majority a setup run wrote; a category under `## Unsettled conventions` is a live split. A grep sees
three identical sentences.

Usage:  python3 -I oracle-map.py <root> [--out=<dir>] [--age-buckets] [--docs=<relpath>,…] [--json]
        python3 -I oracle-map.py <root> propose  [--sites=<tsv>|-] [--oracle=<dir>] [--min-sites=30]
                                               [--min-share=0.75] [--newest=20]
        python3 -I oracle-map.py <root> quotes   --candidates=<json|tsv> [--oracle=<dir>]
        python3 -I oracle-map.py --self-test
<root> is read only. --out must be outside <root> (default: a fresh mktemp -d under $TMPDIR, printed on
stderr). Git is read with GIT_OPTIONAL_LOCKS=0 and never written.

TAGS (column `tag`) — the four oracle strengths, plus two non-oracle states:
  enforced   T1: a rule at `error` in the resolved-by-static-parse config for that scope, and CI lints the
             scope (or the repo has no CI file at all: `ci=unknown`). ESLint flat config, stylelint, ls-lint,
             depcruise `forbidden`, eslint-plugin-boundaries, import-linter contracts, Ruff `select` and
             banned-api, tsconfig compiler flags, .editorconfig IDE1006, Spectral, golangci depguard.
  written    T2: human prose — ai/conventions.md, ai/architecture.md, ai/modules.md OUTSIDE the
             refine-enriched markers, accepted ADRs, CONTRIBUTING, design-system docs, ai/glossary.md,
             ai/_convention-cheatsheet.md, ai/core/invariants.md, and the MUST / never lines of CLAUDE.md and
             ai/patterns/*.md.
             Also a config rule that is declared but not enforced: `warn` (tier T1-warn), or `error` in a
             scope CI never lints (tier T1-noci). Both are AL-03 candidates, and still oracles.
  generated  T2g: a line inside <!-- refine-enriched:start/end -->, any line carrying [inferred:] /
             [unconfirmed] / [SAMPLED, and every line of .claude/codebase-profile.md, _extracted-*.md and
             _refine-extract.md. A PROPOSAL until a human ratifies it (P-28): never a Finding by itself.
  contested  `[CONTESTED: A n/N, B m/N]` rows and every table row under `## Unsettled conventions`. A T2g row
             whose words name a contested category is re-tagged contested (P-29): AL-02 report, never drift.
  off        a rule set to `off`/0 — no convention; listed for AL-31 (per-package drift) only.
  inactive   an ADR whose status is proposed / draft / rejected / superseded / deprecated.

OUTPUT FILES (TSV, one `# columns` header line each; --json prints them as one object instead):
  rules.tsv     id tool rule severity tag tier scope ignores matched ci options source
                (scope globs are shown prefixed with the config file's directory; `matched` = files they match — `0` is a vacuous rule, V-09; `ci` yes = CI lints the
                whole scope, partial = part of it (tag stays enforced), no = never (tier T1-noci), unknown = no CI)
  docs.tsv      id tag tier kind section provenance source quote
                (kind normative|bullet|table|contested|unsettled|glossary|adr-decision — a bullet and its indented
                continuation lines are one row, quoted joined; in ai/conventions.md and CONTRIBUTING every bullet is
                a rule, elsewhere only under a naming/layering/tokens/… heading; provenance found|inferred|
                unconfirmed|sampled|plain; ADR rows carry `adr=<status>@<date>` and `frozen-until=<date>`)
  wrappers.tsv  raw wrapper kind source message import_names except type_imports
                (no-restricted-imports "use X", Ruff banned-api msg; a negated or article phrase names no wrapper.
                import_names: `a,b` importNames · `/re/` importNamePattern · `!a,b` / `!/re/` the allow forms; except:
                the group's `!x` entries, never rows of their own; type_imports `allowed` = allowTypeImports. A const
                (`group: FEATURE_IMPORTS`, `message: ADR_TEXT`) resolves when the file defines it, else `<NAME>` + a gate)
  exports.tsv   package subpath target kind source   (package.json exports/main; tsconfig paths = kind alias)
  versions.tsv  package major version source manifest declared
                (precedence: node_modules/<pkg>/package.json > pnpm-lock v6-v9 > package-lock > yarn v1/berry >
                bun.lock > manifest range; Python: poetry.lock/uv.lock > == pins; Go: go.mod)
  gates.tsv     gate subject verdict detail source   (version gates — ESLint >= 10 flat-only and a stale
                .eslintrc = AL-31; boundaries v6 `dependencies` / v7 `policies` + renamed rules = AL-30
                rebaseline; unicorn >= 65 filename-case checks directories; TS 7 without
                @typescript/typescript6 = typed rules NOT RUN; jsx-a11y / import / react on ESLint 10 = name
                the -x forks; config parse limits = static!=resolved)
  ci.tsv        source tool target command          (GitHub/GitLab/Azure/Circle/Bitbucket `run:` / `script:` steps
                and their `|` blocks; `npm run lint` resolved through package.json scripts, and `turbo run x`,
                `pnpm -r x`, `nx run-many -t x`, `--filter <pkg>` expanded to each package's own script, run in its
                directory; tool `test` = a test runner, for specs.tsv; target `.` = the whole package)
  exceptions.tsv  site tool rules scope reason_kind resolves in_oracle cluster reason
                (inline reasons: eslint-disable / stylelint-disable `-- reason`, # noqa, //nolint, biome-ignore,
                ast-grep-ignore, @ts-expect-error — only at the start of a comment, so prose that names a directive
                is no row. Test trees count where a CI lint step covers them. reason_kind adr|ticket|text|none; an
                ADR id resolves only when its file exists; `-- see above` takes the comment above (or the last
                reason given); cluster = how many disables of that rule share the resolved reason (P-26 when > 5))
  specs.tsv     spec kind ci title                  (a test that reads the source tree and asserts a shape: enforcement
                when CI runs it; kind ratchet = a name with only-falls / ratchet / ceiling, or a CEILING-style const)
  ages.tsv      path first_added                    (--age-buckets: one `git log --diff-filter=A` pass;
                `# history-blind (<reason>)` when the history cannot date the files: <= 1 commit, one date, or
                >= 90% of the live files first added on one day — an imported or squashed history)
Stdout: the summary — `oracle: T1 n · T1-warn n · T1-noci n · T2 n · T2g n (unratified) · contested n`, the
version gates, vacuous rules, and the out dir.

propose — the AL-02 proposal channel (§ 3.1). Input TSV rows `concern<TAB>shape<TAB>path[:line]` (any
  detector's census; name-check.py --census emits it). Per concern: counts, the top shape's share, and the
  newest-N files' share (first-add dates from git). Verdict:
    proposed canonical: <shape> (k/n = 0.83, newest 20 files 19/20) — ratify?   n >= 30 AND share >= 0.75
                                                AND (newest share >= 0.75, or history-blind: whole-tree only)
    undetermined — ask                          below the floor
    contested — ask (<source>)                  the concern names a contested row
  Every concern prints `ledger_rows: 0`. A majority is NEVER a Finding (P-01); the floor only decides whether
  the report proposes a canonical shape or asks.
quotes — the AL-01 meta-check. Each candidate's `oracle` (`path:line "quote"`, `path "quote"`, or a rule id
  such as `eslint:no-restricted-imports`) must resolve: the quote occurs in that file (whitespace-normalised),
  or the rule id is a rules.tsv row — the block whose scope holds the candidate's site, when the id is declared
  more than once (none holds it: dropped). Verdicts: kept (enforced|written) · unconfirmed (generated — ratify
  <source>) · contested (AL-02) · dropped (quote absent / no oracle). Last line: `AL-01: k candidate rows dropped`.

Exit: 0 ran · 1 (quotes) at least one candidate dropped · 2 usage, or an internal error (the traceback is
on stderr and the map was NOT built) · 3 self-test failed. A config file the reader cannot parse is a
`static!=resolved … parser error` gate row, never a crash.
Stdlib only, Python >= 3.8 (a small TOML reader stands in for tomllib), `python3 -I` safe.
Static parse limits: spreads, imported presets and computed values are not expanded — each prints a
`static!=resolved` gate row; when the project's own ESLint is installed, `eslint --print-config <file>` is
the resolved truth (run by the skill, not by this script, which executes nothing from the repo).
"""
import copy, json, os, re, shlex, shutil, subprocess, sys, tempfile, traceback

SKIP_DIRS = {'node_modules', '.git', 'dist', 'build', 'out', '.next', '.nuxt', '.output', '.svelte-kit', 'coverage',
             'vendor', 'third_party', '.turbo', '.cache', 'storybook-static', '.venv', 'venv', '__pycache__', 'target',
             '.gradle', '.dart_tool', 'Pods', '.idea', '.vscode', '.pytest_cache', '.mypy_cache', '.ruff_cache'}
TEST_DIR = re.compile(r'(?:^|/)(?:test|tests|__tests__|e2e|fixtures|__fixtures__|__mocks__|mocks|testdata|stories)/')
CODE_EXT = ('.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.mts', '.cts', '.vue', '.svelte', '.astro', '.py', '.go',
            '.css', '.scss', '.less', '.java', '.kt', '.cs', '.rb', '.php', '.dart', '.swift')
JS_LINT_EXT = ('.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.mts', '.cts', '.vue', '.svelte', '.astro')
NORMATIVE = re.compile(r'\b(?:MUST(?: NOT)?|SHALL(?: NOT)?|must(?: not)?|shall|never|Never|NEVER|always|Always|ALWAYS|'
                       r'only|Only|do not|Do not|don\'t|Don\'t|required|forbidden|not allowed|is the only|are never|'
                       r'prefer|Prefer|avoid|Avoid)\b')
RULE_SECTIONS = re.compile(r'naming|layer|layering|token|convention|file|structure|import|boundar|styl|i18n|'
                           r'internationali|accessib|a11y|error|permission|module|folder|layout|component|api', re.I)
ADR_DIRS = ('docs/adr', 'doc/adr', 'docs/adrs', 'adr', 'adrs', 'docs/decisions', 'ai/decisions', 'docs/architecture/decisions',
            'architecture/decisions', 'decisions')
GENERATED_DOCS = re.compile(r'(?:^|/)\.claude/(?:codebase-profile|_extracted-[\w-]+|_refine-extract)\.md$')


# ---------------------------------------------------------------- small readers
def rel(root, p):
    return os.path.relpath(p, root).replace(os.sep, '/')


def read(p):
    try:
        with open(p, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except OSError:
        return ''


def list_files(root):
    out = []
    for d, dirs, files in os.walk(root):
        rd = rel(root, d)
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS and not (x.startswith('.') and x not in
                         ('.github', '.claude', '.storybook', '.circleci', '.gitlab', '.refract-fixture')))
        for f in sorted(files):
            out.append(f if rd == '.' else rd + '/' + f)
    return out


def strip_jsonc(src):
    """Remove // and /* */ comments OUTSIDE strings (a `/*` inside a JSON string is data: the tsconfig
    "paths": {"@/*": …} lesson) and trailing commas."""
    out, i, n, q = [], 0, len(src), None
    while i < n:
        c = src[i]
        if q:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(src[i + 1]); i += 2; continue
            if c == q:
                q = None
            i += 1; continue
        if c == '"':
            q = c; out.append(c); i += 1; continue
        if src.startswith('//', i):
            j = src.find('\n', i); i = n if j < 0 else j; continue
        if src.startswith('/*', i):
            j = src.find('*/', i + 2); i = n if j < 0 else j + 2; continue
        out.append(c); i += 1
    return re.sub(r',(\s*[}\]])', r'\1', ''.join(out))


def load_jsonc(src):
    try:
        return json.loads(strip_jsonc(src))
    except ValueError:
        return None


def toml_lite(src):
    """Enough TOML for pyproject/ruff.toml: [a.b] tables, [[arrays]], key = string|number|bool|array|inline
    table, multi-line arrays, quoted keys. Returns nested dicts."""
    root, cur = {}, None
    cur = root
    lines = src.split('\n')
    i = 0

    def setp(d, path):
        for k in path:
            d = d.setdefault(k, {})
        return d

    def keypath(s):
        return [k.strip().strip('"\'') for k in re.findall(r'"[^"]*"|\'[^\']*\'|[^.]+', s.strip())]

    while i < len(lines):
        line = re.sub(r'\s+#.*$', '', lines[i]).strip() if not lines[i].strip().startswith('#') else ''
        i += 1
        if not line:
            continue
        m = re.match(r'^\[\[(.+)\]\]$', line)
        if m:
            path = keypath(m.group(1))
            parent = setp(root, path[:-1])
            parent.setdefault(path[-1], []).append({})
            cur = parent[path[-1]][-1]
            continue
        m = re.match(r'^\[(.+)\]$', line)
        if m:
            cur = setp(root, keypath(m.group(1)))
            continue
        m = re.match(r'^((?:"[^"]+"|\'[^\']+\'|[\w-]+)(?:\s*\.\s*(?:"[^"]+"|\'[^\']+\'|[\w-]+))*)\s*=\s*(.*)$', line)
        if not m:
            continue
        val = m.group(2)
        depth = val.count('[') - val.count(']') + val.count('{') - val.count('}')
        while depth > 0 and i < len(lines):
            nxt = re.sub(r'\s+#.*$', '', lines[i]); i += 1
            if nxt.strip().startswith('#'):
                continue
            val += ' ' + nxt.strip()
            depth = val.count('[') - val.count(']') + val.count('{') - val.count('}')
        kp = keypath(m.group(1))
        setp(cur, kp[:-1])[kp[-1]] = toml_value(val.strip())
    return root


def toml_value(v):
    if v.startswith(('"""', "'''")):
        return v[3:-3]
    if v[:1] in '"\'':
        return v[1:-1] if len(v) > 1 else ''
    if v in ('true', 'false'):
        return v == 'true'
    if v.startswith('['):
        items, depth, cur, q = [], 0, '', None
        for c in v[1:-1]:
            if q:
                cur += c
                if c == q: q = None
                continue
            if c in '"\'':
                q = c; cur += c; continue
            if c in '[{': depth += 1
            if c in ']}': depth -= 1
            if c == ',' and depth == 0:
                if cur.strip(): items.append(toml_value(cur.strip()))
                cur = ''; continue
            cur += c
        if cur.strip():
            items.append(toml_value(cur.strip()))
        return items
    if v.startswith('{'):
        out = {}
        for part in re.findall(r'("[^"]+"|[\w.-]+)\s*=\s*("[^"]*"|\'[^\']*\'|\[[^\]]*\]|[^,}]+)', v):
            out[part[0].strip('"')] = toml_value(part[1].strip())
        return out
    try:
        return float(v) if '.' in v else int(v)
    except ValueError:
        return v


def yaml_lite(src):
    """Indentation YAML subset: nested maps of scalars, lists of scalars/maps. Enough for .ls-lint.yml,
    .spectral.yaml, .golangci.yml and .stylelintrc.yml. Anchors, flow maps and multi-docs are not read."""
    root = {}
    stack = [(-1, root)]
    last_key = {}
    for raw in src.split('\n'):
        if not raw.strip() or raw.lstrip().startswith('#') or raw.strip() == '---':
            continue
        ind = len(raw) - len(raw.lstrip(' '))
        line = re.sub(r'\s+#.*$', '', raw.strip())
        while stack and ind <= stack[-1][0] and len(stack) > 1:
            stack.pop()
        parent = stack[-1][1]
        if line.startswith('- '):
            item = line[2:].strip()
            if isinstance(parent, dict):
                k = last_key.get(id(parent))
                if k is None:
                    continue
                if not isinstance(parent.get(k), list):
                    parent[k] = []
                lst = parent[k]
            else:
                lst = parent
            m = re.match(r'^([^:]+):\s*(.*)$', item)
            if m and not item.startswith(('"', "'")):
                d = {m.group(1).strip().strip('"\''): yscalar(m.group(2))}
                lst.append(d)
                stack.append((ind + 1, d)); last_key[id(d)] = m.group(1).strip().strip('"\'')
            else:
                lst.append(yscalar(item))
            continue
        m = re.match(r'^("[^"]*"|\'[^\']*\'|[^:]+?):\s*(.*)$', line)
        if not m or not isinstance(parent, dict):
            continue
        k, v = m.group(1).strip().strip('"\''), m.group(2).strip()
        last_key[id(parent)] = k
        if v == '' or v in ('|', '>'):
            d = {}
            parent[k] = d
            stack.append((ind, d))
        elif v.startswith('['):
            parent[k] = [yscalar(x) for x in re.findall(r'"[^"]*"|\'[^\']*\'|[^,\[\]\s][^,\[\]]*', v[1:-1])]
        else:
            parent[k] = yscalar(v)
    return root


def yscalar(v):
    v = v.strip()
    if v[:1] in '"\'' and v[-1:] == v[:1]:
        return v[1:-1]
    if v in ('true', 'false'):
        return v == 'true'
    if re.fullmatch(r'-?\d+', v):
        return int(v)
    return v


# ---------------------------------------------------------------- JS object literal reader (positions kept)
JS_TOK = re.compile(r'''\s+|//[^\n]*|/\*.*?\*/|("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)|'''
                    r'''(/(?![*/])(?:\\.|\[(?:\\.|[^\]\\])*\]|[^/\\\n])+/[gimsuyd]*)|'''
                    r'''(-?\d+\.?\d*(?:e-?\d+)?)|([A-Za-z_$][\w$]*)|(\.\.\.|=>|[{}\[\](),:;=?<>!&|+\-*/.%])''', re.S)


def js_tokens(src):
    out, pos = [], 0
    while pos < len(src):
        m = JS_TOK.match(src, pos)
        if not m:
            out.append(('p', src[pos], pos)); pos += 1; continue
        start, pos = pos, m.end()
        if m.group(1) is not None:
            s = m.group(1)
            out.append(('s', None if s[0] == '`' and '${' in s else s[1:-1], start))
        elif m.group(2) is not None:
            prev = out[-1] if out else None
            if prev is None or prev[0] == 'p' and prev[1] in '(,=:[!&|?{};' or prev[:2] == ('i', 'return'):
                out.append(('r', m.group(2), start))
            else:                                       # a division, not a regex literal
                out.append(('p', '/', start)); pos = start + 1
        elif m.group(3) is not None:
            out.append(('n', m.group(3), start))
        elif m.group(4) is not None:
            out.append(('i', m.group(4), start))
        elif m.group(5) is not None:
            out.append(('p', m.group(5), start))
    return out


class Dyn(object):
    """An unresolved JS expression (identifier, call, spread source)."""
    def __init__(self, text):
        self.text = text

    def __repr__(self):
        return '<%s>' % self.text


def skip_expr(toks, i):
    """Index of the `,` / `;` / closing bracket that ends the expression starting at i (depth 0)."""
    depth = 0
    while i < len(toks):
        kk, vv = toks[i][:2]
        if kk == 'p' and vv in '([{':
            depth += 1
        elif kk == 'p' and vv in ')]}':
            if depth == 0:
                break
            depth -= 1
        elif kk == 'p' and vv in ',;' and depth == 0:
            break
        i += 1
    return i


def js_value(toks, i, src='', env=None):
    """One JS value. `env` maps a top-level const name to its already-read value: `group: FEATURE_APP_IMPORTS`
    and `message: ADR_0010_DOMAIN` resolve to the array and the string (a const the reader cannot read stays a
    Dyn, named). A literal followed by a call chain (`[...].map(…)`) is a Dyn, never the bare literal."""
    if i >= len(toks):
        return None, i
    k, v, pos = toks[i]
    if (k, v) in (('p', '{'), ('p', '[')):
        val, j = js_literal(toks, i, src, env)
        if j < len(toks) and toks[j][:2] in (('p', '.'), ('p', '('), ('p', '?')):
            e = skip_expr(toks, j)
            return Dyn(''.join(str(t[1]) for t in toks[i:e])[:80]), e
        return val, j
    end_ok = lambda j: j >= len(toks) or toks[j][:2] in (('p', ','), ('p', '}'), ('p', ']'), ('p', ';'), ('p', ')'))
    if k == 'i' and env and v in env and end_ok(i + 1):
        return copy.deepcopy(env[v]), i + 1
    return js_scalar(toks, i, src)


def js_literal(toks, i, src='', env=None):
    k, v, pos = toks[i]
    if (k, v) == ('p', '{'):
        d, i = {}, i + 1
        while i < len(toks) and toks[i][:2] != ('p', '}'):
            k2, v2 = toks[i][:2]
            if (k2, v2) == ('p', '...'):
                val, i = js_value(toks, i + 1, src, env)
                if isinstance(val, dict):            # a spread of a const object: its keys, in order
                    for kk, vv in val.items():
                        if kk == '...':
                            d.setdefault('...', []).extend(vv)
                        else:
                            d[kk] = vv
                else:
                    d.setdefault('...', []).append(val)
            elif k2 in ('i', 's', 'n') and i + 1 < len(toks) and toks[i + 1][:2] == ('p', ':'):
                val, i = js_value(toks, i + 2, src, env)
                d[str(v2)] = val
            elif (k2, v2) == ('p', '['):
                depth, j = 0, i
                while j < len(toks):
                    if toks[j][:2] == ('p', '['): depth += 1
                    elif toks[j][:2] == ('p', ']'):
                        depth -= 1
                        if depth == 0: break
                    j += 1
                key = ''.join(str(t[1]) for t in toks[i + 1:j])
                i = j + 1
                if i < len(toks) and toks[i][:2] == ('p', ':'):
                    val, i = js_value(toks, i + 1, src, env)
                    d['[' + key + ']'] = val
            else:
                i += 1
                continue
            if i < len(toks) and toks[i][:2] == ('p', ','):
                i += 1
        return d, i + 1
    arr, i = [], i + 1
    while i < len(toks) and toks[i][:2] != ('p', ']'):
        if toks[i][:2] == ('p', '...'):
            val, i = js_value(toks, i + 1, src, env)
            if isinstance(val, list):                # `...BASE_GROUP` / `...['a', 'b']`: the elements themselves
                arr.extend(val)
            else:
                arr.append(Dyn('...' + (val.text if isinstance(val, Dyn) else 'spread')))
        else:
            val, i = js_value(toks, i, src, env)
            arr.append(val)
        if i < len(toks) and toks[i][:2] == ('p', ','):
            i += 1
    return arr, i + 1


def js_scalar(toks, i, src=''):
    k, v, pos = toks[i]
    end_ok = lambda j: j >= len(toks) or toks[j][:2] in (('p', ','), ('p', '}'), ('p', ']'), ('p', ';'), ('p', ')'))
    if k in ('s', 'n', 'r') and end_ok(i + 1):
        return (v if k != 'n' else (float(v) if '.' in v else int(v))), i + 1
    if k == 'i' and v in ('true', 'false', 'null', 'undefined') and end_ok(i + 1):
        return {'true': True, 'false': False}.get(v), i + 1
    start = i
    i = skip_expr(toks, i)
    text = ''.join(str(t[1]) if t[0] != 's' else repr(t[1]) for t in toks[start:i])[:80]
    return Dyn(text), i


def js_consts(toks, src=''):
    """`const NAME = <literal>` anywhere in the file, in source order (a later const may use an earlier one).
    Destructuring and computed values are not read: their names stay Dyn and print a static!=resolved row."""
    env = {}
    for i in range(len(toks) - 3):
        if toks[i][:2] in (('i', 'const'), ('i', 'let'), ('i', 'var')) and toks[i + 1][0] == 'i' \
                and toks[i + 2][:2] == ('p', '=') and toks[i + 1][1] not in env:
            val, _ = js_value(toks, i + 3, src, env)
            if not isinstance(val, Dyn):
                env[toks[i + 1][1]] = val
    return env


def line_of(src, pos):
    return src.count('\n', 0, pos) + 1


# ---------------------------------------------------------------- globs
def glob_re(g):
    g = g.strip().lstrip('./') if g.startswith('./') else g.strip()
    out, i = '', 0
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
    return re.compile('^' + out + ('(?:/.*)?$' if not re.search(r'[*?.]', g.split('/')[-1]) else '$'))


def match_count(files, base, globs, ignores=(), ext=None):
    """Files (root-relative) under `base` that match any glob (relative to base) and no ignore."""
    inc = [glob_re(g) for g in globs if isinstance(g, str)] if globs else None
    exc = [glob_re(g) for g in ignores if isinstance(g, str)]
    n = 0
    for f in files:
        if base and not f.startswith(base + '/'):
            continue
        r = f[len(base) + 1:] if base else f
        if ext and not r.endswith(ext):
            continue
        if inc is not None and not any(rx.match(r) for rx in inc):
            continue
        if any(rx.match(r) for rx in exc):
            continue
        n += 1
    return n


# ---------------------------------------------------------------- versions
def parse_versions(root, files):
    rows = {}

    def put(pkg, ver, source, manifest='', declared='', prio=0):
        if not ver:
            return
        cur = rows.get(pkg)
        if cur is None or prio > cur['prio']:
            rows[pkg] = dict(package=pkg, version=ver, source=source, manifest=manifest or (cur or {}).get('manifest', ''),
                             declared=declared or (cur or {}).get('declared', ''), prio=prio)
        elif declared and not cur['declared']:
            cur['declared'], cur['manifest'] = declared, manifest
    for f in files:
        base = os.path.basename(f)
        p = os.path.join(root, f)
        if base == 'package.json' and '/node_modules/' not in '/' + f:
            d = load_jsonc(read(p)) or {}
            for sec in ('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'):
                for name, rng in (d.get(sec) or {}).items():
                    if not isinstance(rng, str):
                        continue
                    m = re.search(r'(\d+(?:\.\d+){0,2})', rng) if not rng.startswith(('workspace:', 'file:', 'link:')) else None
                    put(name, m.group(1) if m else '', 'manifest-range', f, rng, 1)
                    if name not in rows:
                        rows[name] = dict(package=name, version='', source='manifest-range', manifest=f, declared=rng, prio=0)
                    elif not rows[name]['declared']:
                        rows[name]['declared'], rows[name]['manifest'] = rng, f
        elif base == 'pnpm-lock.yaml':
            src = read(p)
            for m in re.finditer(r'^ {6}([\'"]?[@\w./-]+[\'"]?):\n {8}specifier: *([^\n]*)\n {8}version: *([^\s(\n]+)', src, re.M):
                put(m.group(1).strip('\'"'), m.group(3), 'pnpm-lock', '', m.group(2), 3)
            for m in re.finditer(r'^ {2}[\'"]?/?(@?[\w.-]+(?:/[\w.-]+)?)[@/](\d+\.\d+\.\d+[\w.+-]*)', src, re.M):
                if m.group(1) not in rows or rows[m.group(1)]['prio'] < 2:
                    put(m.group(1), m.group(2), 'pnpm-lock', prio=2)
        elif base == 'package-lock.json':
            d = load_jsonc(read(p)) or {}
            for k, v in (d.get('packages') or {}).items():
                if k.startswith('node_modules/') and k.count('node_modules/') == 1 and isinstance(v, dict):
                    put(k[len('node_modules/'):], v.get('version', ''), 'package-lock', prio=3)
            for k, v in (d.get('dependencies') or {}).items():
                if isinstance(v, dict):
                    put(k, v.get('version', ''), 'package-lock', prio=2)
        elif base == 'yarn.lock':
            src = read(p)
            for m in re.finditer(r'^"?(@?[^@\s"]+)@[^\n]*:\n(?:[ \t]+[^\n]*\n)*?[ \t]+version:? "?([\d][^"\s]*)"?', src, re.M):
                put(m.group(1), m.group(2), 'yarn.lock', prio=3)
        elif base in ('bun.lock',):
            for m in re.finditer(r'"(@?[\w./-]+)": \["\1@(\d[^"]*)"', read(p)):
                put(m.group(1), m.group(2), 'bun.lock', prio=3)
        elif base in ('poetry.lock', 'uv.lock'):
            for m in re.finditer(r'^name = "([^"]+)"\s*\nversion = "([^"]+)"', read(p), re.M):
                put(m.group(1).lower(), m.group(2), base, prio=3)
        elif base == 'pyproject.toml' or re.match(r'requirements[\w.-]*\.txt$', base):
            for m in re.finditer(r'["\s^]([A-Za-z0-9_.-]+)(?:\[[^\]]*\])?\s*==\s*([\w.]+)', read(p)):
                put(m.group(1).lower(), m.group(2), 'pin', f, '==' + m.group(2), 2)
        elif base == 'go.mod':
            for m in re.finditer(r'^\s*(?:require\s+)?([\w./-]+\.[\w./-]+)\s+(v[\d.]+[\w.+-]*)', read(p), re.M):
                put(m.group(1), m.group(2), 'go.mod', f, m.group(2), 3)
    for name in list(rows):
        pj = os.path.join(root, 'node_modules', name, 'package.json')
        if os.path.isfile(pj):
            d = load_jsonc(read(pj)) or {}
            put(name, d.get('version', ''), 'node_modules', prio=4)
    for r in rows.values():
        m = re.match(r'v?(\d+)', r['version'] or '')
        r['major'] = int(m.group(1)) if m else ''
    return rows


def major(versions, name):
    r = versions.get(name)
    return r['major'] if r and r['major'] != '' else None


# ---------------------------------------------------------------- CI
CI_FILES = re.compile(r'^(?:\.github/workflows/[^/]+\.ya?ml|\.gitlab-ci\.yml|azure-pipelines\.yml|\.circleci/config\.yml|'
                      r'bitbucket-pipelines\.yml|\.gitlab/ci/[^/]+\.ya?ml)$')
LINT_TOOLS = [('eslint', r'\beslint\b'), ('stylelint', r'\bstylelint\b'), ('ls-lint', r'\bls-lint\b'),
              ('depcruise', r'\b(?:depcruise|dependency-cruiser)\b'), ('import-linter', r'\blint-imports\b'),
              ('ruff', r'\bruff\s+check\b|\bruff\b'), ('golangci-lint', r'\bgolangci-lint\b'),
              ('spectral', r'\bspectral\s+lint\b'), ('tsc', r'\btsc\b|\bvue-tsc\b|\btypecheck\b|\btype-check\b'),
              ('biome', r'\bbiome\s+(?:check|lint|ci)\b'), ('oxlint', r'\boxlint\b'),
              ('test', r'\b(?:vitest|jest|mocha|ava|pytest|playwright\s+test|go\s+test|cargo\s+test|node\s+--test)\b')]
VALUE_OPTS = {'-c', '--config', '-p', '--project', '-f', '--format', '--ext', '--max-warnings', '-o', '--output-file',
              '--cache-location', '--ignore-path', '--rulesdir', '--resolve-plugins-relative-to', '--parser', '--env',
              '--plugin', '--rule', '--global', '--concurrency', '--filter', '-F', '--stats', '--config-file',
              '--output-format', '--select', '--ignore', '--reporter', '--coverage.reporter', '--shard', '--workspace',
              '-w', '--testPathPattern', '--outDir', '--tsBuildInfoFile', '--cache-strategy', '--max-old-space-size'}
RUNNER_SKIP = {'install', 'i', 'ci', 'add', 'remove', 'exec', 'dlx', 'x', 'audit', 'outdated', 'publish', 'pack', 'link',
               'config', 'init', 'create', 'store', 'fetch', 'prune', 'dedupe', 'why', 'list', 'ls', 'version'}


def workspace_packages(root, files):
    """dir -> (name, scripts, nx targets) for every package.json / project.json outside node_modules ('' = root)."""
    out = {}
    for f in files:
        b = os.path.basename(f)
        if b not in ('package.json', 'project.json') or '/node_modules/' in '/' + f:
            continue
        d = load_jsonc(read(os.path.join(root, f))) or {}
        if not isinstance(d, dict):
            continue
        k = f.rsplit('/', 1)[0] if '/' in f else ''
        name, scripts, targets = out.get(k, ('', {}, {}))
        if b == 'package.json':
            name, scripts = d.get('name') or name, d.get('scripts') if isinstance(d.get('scripts'), dict) else {}
        else:
            name, targets = name or d.get('name') or '', d.get('targets') if isinstance(d.get('targets'), dict) else {}
        out[k] = (name, scripts, targets)
    return out


def _sel(pkgs, sel):
    """Package dirs a --filter / -w / nx project selector names (exact name, `./dir`, `{dir}`, a trailing `*`)."""
    sel = sel.strip('"\'')
    if sel.startswith(('...', '[')) or not sel:
        return list(pkgs)
    s2 = sel.strip('{}').lstrip('./').rstrip('/')
    rx = re.compile('^' + re.escape(s2).replace(r'\*', '.*') + '$')
    return [d for d, (n, _, _) in pkgs.items() if rx.match(n or '\0') or (d and rx.match(d))]


def expand_cmd(cmd, wd, pkgs, depth=0, seen=None):
    """A CI command, as the (working dir, leaf command) pairs it runs. `npm run x` / `pnpm x` resolve through the
    package's scripts; `turbo run x`, `pnpm -r x`, `npm -ws run x`, `yarn workspaces foreach run x`, `lerna run x`
    and `nx run-many -t x` / `nx affected -t x` run x in EVERY workspace package that has it (measured 2026-10-18 on a
    real monorepo: `pnpm run lint` -> `turbo run lint` -> each package's `eslint "src/**/*.ts" …`; read as one root
    command it matched no linter, and 31 rules lost their CI proof); `--filter` / `-F` / `-w` / `yarn workspace <n>`
    narrow it. Depth-bounded; a cycle is cut."""
    seen = seen if seen is not None else set()
    out = []
    for part in re.split(r'\s*(?:&&|\|\||;|\n)\s*', cmd or ''):
        part = part.strip()
        if not part or depth > 5:
            continue
        cdm = re.match(r'^cd\s+["\']?([\w./-]+)["\']?$', part)
        if cdm:                                        # `cd apps/api && pnpm lint`: later parts run there
            wd = os.path.normpath(os.path.join(wd or '.', cdm.group(1))).replace(os.sep, '/').lstrip('./') if cdm.group(1) not in ('.', './') else wd
            wd = '' if wd in ('.', '') else wd
            continue
        try:
            tk = shlex.split(part, comments=True)
        except ValueError:
            tk = part.split()
        while tk and re.match(r'^[A-Z_][A-Z0-9_]*=', tk[0]):
            tk = tk[1:]
        while tk and tk[0] in ('cross-env', 'dotenv', '--', 'npx', 'bunx', 'time', 'env'):
            tk = tk[1:]
        if not tk:
            continue
        runner, rest = os.path.basename(tk[0]), tk[1:]
        flags = [t for t in rest if t.startswith('-')]
        words = [t for i, t in enumerate(rest) if not t.startswith('-') and not (i and rest[i - 1] in VALUE_OPTS)]
        opt = lambda *names: [v for i, t in enumerate(rest) for v in ([t.split('=', 1)[1]] if '=' in t and t.split('=', 1)[0] in names
                              else [rest[i + 1]] if t in names and i + 1 < len(rest) else [])]
        tasks, dirs = [], None
        if runner == 'turbo':
            tasks = [w for w in (words[1:] if words[:1] == ['run'] else words) if w != 'run']
            dirs = [d for fl in opt('--filter', '-F') for d in _sel(pkgs, fl)] or [d for d in pkgs if d]
        elif runner in ('nx',) and words[:1] in (['run-many'], ['affected']):
            tasks = [t for v in opt('-t', '--target', '--targets') for t in v.split(',')]
            proj = [d for v in opt('-p', '--projects') for x in v.split(',') for d in _sel(pkgs, x)]
            dirs = proj or [d for d in pkgs if d]
        elif runner == 'nx' and words[:1] == ['run'] and len(words) > 1 and ':' in words[1]:
            pj, t = words[1].split(':', 1)
            tasks, dirs = [t.split(':')[0]], _sel(pkgs, pj)
        elif runner == 'lerna' and words[:1] == ['run']:
            tasks, dirs = words[1:2], [d for d in pkgs if d]
        elif runner in ('npm', 'pnpm', 'yarn', 'bun'):
            ws = [w for w in words]
            if runner == 'yarn' and ws[:2] == ['workspaces', 'foreach']:
                ws = [w for w in ws[2:] if w != 'run']
                tasks, dirs = ws[:1], [d for d in pkgs if d]
            elif runner == 'yarn' and ws[:1] == ['workspace'] and len(ws) > 2:
                tasks, dirs = [w for w in ws[2:] if w != 'run'][:1], _sel(pkgs, ws[1])
            else:
                ws = [w for w in ws if w != 'run']
                if not ws or ws[0] in RUNNER_SKIP:
                    if ws[:1] == ['exec'] and len(ws) > 1:      # `pnpm --filter @x/api exec jest …` runs in that package
                        for d in [d for v in opt('--filter', '-F', '-w', '--workspace') for d in _sel(pkgs, v)] or [wd]:
                            out += expand_cmd(' '.join(shlex.quote(t) for t in rest[rest.index('exec') + 1:]), d, pkgs, depth + 1, seen)
                    continue
                tasks = ws[:1]
                if set(flags) & {'-r', '--recursive', '-ws', '--workspaces'}:
                    dirs = [d for d in pkgs if d]
                elif opt('--filter', '-F', '-w', '--workspace'):
                    dirs = [d for v in opt('--filter', '-F', '-w', '--workspace') for d in _sel(pkgs, v)]
                else:
                    dirs = [wd]
        if dirs is None:
            out.append((wd, part))
            continue
        for d in dirs:
            name, scripts, targets = pkgs.get(d, ('', {}, {}))
            for t in tasks:
                key = (d, t)
                if key in seen:
                    continue
                seen.add(key)
                if isinstance(scripts.get(t), str):
                    out += expand_cmd(scripts[t], d, pkgs, depth + 1, seen)
                elif isinstance(targets.get(t), dict):
                    tg = targets[t]
                    ex = str(tg.get('executor', ''))
                    if re.search(r'eslint|linter', ex):
                        out.append((d, 'eslint ' + ' '.join((tg.get('options') or {}).get('lintFilePatterns') or ['.'])))
                    elif isinstance((tg.get('options') or {}).get('command'), str):
                        out += expand_cmd(tg['options']['command'], d, pkgs, depth + 1, seen)
                    elif re.search(r'jest|vitest|playwright', ex):
                        out.append((d, ex.split(':')[0].split('/')[-1]))
                    elif re.search(r'tsc|typescript', ex):
                        out.append((d, 'tsc'))
    return out


def arg_prefix(a):
    """The static directory a CLI path argument names: `"src/**/*.ts"` -> src, `./apps/web` -> apps/web."""
    segs = []
    for seg in a.split('/'):
        if re.search(r'[*?{\[]', seg):
            break
        segs.append(seg)
    return '/'.join(segs)


def ci_steps(src):
    """(line, command, working-directory) per CI command: inline `run:` / `script:` / `command:` values, their `|`
    / `>` block scalars, and `- cmd` items under a `script:`-like key. `working-directory:` binds to its own step."""
    lines = src.split('\n')
    steps, i, key_ind, in_script = [], 0, None, False
    step_wd, step_ind = {}, None
    cur_step = 0
    for ln, raw in enumerate(lines, 1):
        ind = len(raw) - len(raw.lstrip())
        m = re.match(r'^(\s*)-\s+\S', raw)
        if m and (step_ind is None or ind <= step_ind) and not in_script:
            step_ind, cur_step = ind, ln
        wm = re.search(r'\bworking-directory:\s*["\']?([\w./-]+)', raw)
        if wm:
            step_wd[cur_step] = wm.group(1).strip('/').lstrip('./') if wm.group(1) not in ('.', './') else ''
    i = 0
    cur_step, step_ind = 0, None
    while i < len(lines):
        raw = lines[i]; ln = i + 1; i += 1
        ind = len(raw) - len(raw.lstrip())
        if re.match(r'^(\s*)-\s+\S', raw) and (step_ind is None or ind <= step_ind):
            step_ind, cur_step = ind, ln
        body = raw.strip()
        if body.startswith('#'):
            continue
        km = re.match(r'^(?:-\s+)?(run|script|command|before_script|after_script|scripts?)\s*:\s*(.*)$', body)
        if km:
            val = km.group(2).strip()
            if val in ('|', '>', '|-', '>-', '|+', '>+'):
                blk = []
                while i < len(lines) and (not lines[i].strip() or len(lines[i]) - len(lines[i].lstrip()) > ind):
                    if lines[i].strip() and not lines[i].strip().startswith('#'):
                        blk.append((i + 1, lines[i].strip()))
                    i += 1
                text = re.sub(r'\\\n', ' ', '\n'.join(bt for _, bt in blk))   # a trailing backslash continues the line
                if text.strip():
                    steps.append((blk[0][0], text, cur_step))   # one block, so a `cd` line carries to the next ones
            elif val and not val.startswith('['):
                steps.append((ln, val.strip('"\''), cur_step))
            elif not val:
                key_ind, in_script = ind, km.group(1) in ('script', 'before_script', 'after_script', 'scripts')
            continue
        if in_script:
            if body and ind <= key_ind and not body.startswith('-'):
                in_script = False
            elif body.startswith('- '):
                steps.append((ln, body[2:].strip().strip('"\''), cur_step))
                continue
            elif body and ind <= key_ind:
                in_script = False
    return [(ln, c, step_wd.get(st, '')) for ln, c, st in steps]


def parse_ci(root, files):
    rows = []
    pkgs = workspace_packages(root, files)
    for f in files:
        if not CI_FILES.match(f):
            continue
        for ln, cmd, wd in ci_steps(read(os.path.join(root, f))):
            for pwd, leaf in expand_cmd(cmd, wd, pkgs):
                for tool, rx in LINT_TOOLS:
                    tm = re.search(rx, leaf)
                    if not tm:
                        continue
                    try:
                        tk = shlex.split(leaf[tm.end():], comments=True)
                    except ValueError:
                        tk = leaf[tm.end():].split()
                    args = []
                    for k, a in enumerate(tk):
                        if a in ('&&', '||', '|', ';'):
                            break
                        if a.startswith('-') or (k and tk[k - 1] in VALUE_OPTS) or a in ('check', 'lint', 'run', 'ci', 'test', 'format'):
                            continue
                        if tool in ('tsc', 'test') or re.search(r'(?:^|/)[\w.-]+\.(?:json|c?js|mjs|ya?ml|toml)$', a):
                            continue                   # a config file or a test-name filter is no lint target
                        args.append(a)
                    tg = [os.path.normpath(os.path.join(pwd or '.', arg_prefix(a) or '.')).replace(os.sep, '/') for a in args] or \
                         [pwd or '.']
                    target = ','.join(sorted(set(t if t != '.' else '.' for t in tg)))
                    rows.append(dict(source='%s:%d' % (f, ln), tool=tool, target=target,
                                     command=(('(%s) ' % pwd) if pwd else '') + leaf[:100]))
                    break
    return rows


def scope_prefixes(base, globs):
    """The static directory prefix of each scope glob ('' = the whole repo)."""
    out = []
    for g in globs or ['**']:
        parts = str(g)[2:].split('/') if str(g).startswith('./') else str(g).split('/')
        segs = []
        for k, seg in enumerate(parts):
            if re.search(r'[*?{\[]', seg) or (k == len(parts) - 1 and '.' in seg):
                break
            segs.append(seg)
        out.append('/'.join(x for x in [base] + segs if x))
    return out


def ci_covers(ci_rows, tool, prefixes, any_ci):
    """yes = CI lints every scope prefix; partial = CI lints part of the scope; no; unknown = no CI file."""
    if not any_ci:
        return 'unknown'
    targets = [t.strip().strip('/') for r in ci_rows if r['tool'] == tool for t in r['target'].split(',')]
    full = 0
    part = False
    for pre in prefixes:
        if any(t in ('.', '') or pre == t or pre.startswith(t + '/') for t in targets):
            full += 1
        elif any(t.startswith(pre + '/') or not pre for t in targets if t not in ('.', '')):
            part = True
    if prefixes and full == len(prefixes):
        return 'yes'
    return 'partial' if full or part else 'no'


# ---------------------------------------------------------------- configs
SEV = {'error': 'error', '2': 'error', 2: 'error', 'warn': 'warn', '1': 'warn', 1: 'warn', 'off': 'off', '0': 'off', 0: 'off'}


def sev_of(v):
    if isinstance(v, list):
        v = v[0] if v else None
    if v is True:
        return 'error'
    return SEV.get(v, '?') if isinstance(v, (str, int, float)) and not isinstance(v, bool) else '?'   # a dict or Dyn: no severity


class Ctx(object):
    def __init__(self, root, files):
        self.root, self.files = root, files
        self.rules, self.wrappers, self.exports, self.gates = [], [], [], []
        self.n = 0

    def rule(self, tool, rule, sev, base, files_globs, ignores, options, source, matched=None, ext=JS_LINT_EXT):
        self.n += 1
        if matched is None:
            matched = match_count(self.files, base, files_globs, ignores, ext)
        pre = (base + '/') if base else ''
        self.rules.append(dict(id='R%d' % self.n, tool=tool, rule=rule, severity=sev, base=base, globs=list(files_globs or []),
                               scope=','.join(g if g.startswith('^') else pre + g for g in files_globs if isinstance(g, str))
                               if files_globs else (base or '.') + '/**',
                               ignores=','.join(i for i in ignores if isinstance(i, str)), matched=matched,
                               options=options, source=source))

    def gate(self, gate, subject, verdict, detail, source):
        self.gates.append(dict(gate=gate, subject=subject, verdict=verdict, detail=detail, source=source))


def opt_text(v):
    if isinstance(v, list) and len(v) > 1:
        try:
            return json.dumps(v[1:], default=lambda o: repr(o))[:160]
        except (TypeError, ValueError):
            return '?'
    return ''


WRAP_VERB = re.compile(r'\b(?:use|Use|import from|Import from|go through|Go through|via|through)\s+([`\'"]?)(@?[\w./-]+(?:/[\w.-]+)*)\1?')
WRAP_NOT = re.compile(r'(?:\bnot|\bnever|n\'t|\bno|\bnor|\bwithout)\s+(?:\w+\s+)?$', re.I)
WRAP_STOP = {'a', 'an', 'the', 'this', 'that', 'these', 'those', 'it', 'its', 'their', 'them', 'one', 'our', 'your', 'each', 'any',
             'every', 'some', 'here', 'there', 'instead', 'only', 'directly', 'case', 'cases', 'when', 'if'}


def wrapper_of(msg):
    """The wrapper a restriction message names ("Use @acme/http instead", "go through `shared/api/client.ts`").
    A negated verb ("Views must not use react-query directly") names the BANNED thing, an article ("go through a
    ViewModel") names nothing, and a bare lowercase word is English, not a module: only a quoted token or one that
    looks like code (a path, a scope, a dot, camelCase, a hyphen) is a wrapper."""
    for m in WRAP_VERB.finditer(msg or ''):
        if WRAP_NOT.search(msg[max(0, m.start() - 24):m.start()]):
            continue
        w = m.group(2).rstrip('.,;:')
        if w.lower() in WRAP_STOP or not w:
            continue
        if m.group(1) or re.search(r'[/@.]|[a-z][A-Z]|^[A-Z][a-z0-9]+[A-Z]|\w-\w', w):
            return w
    return ''


def restricted_imports(ctx, rule, val, source):
    """One wrappers.tsv row per restricted specifier. ESLint's own narrowing travels with it (core
    no-restricted-imports, read 2026-10-18): `importNames` / `importNamePattern` (only those names are banned),
    `allowImportNames` / `allowImportNamePattern` (every other name is), `allowTypeImports`, and a `!` entry of a
    `group`, which re-includes what the earlier entries matched (gitignore order). A `!` entry is never a row of
    its own: it lands in the `except` column of the rows it narrows."""
    if not isinstance(val, list):
        return
    for opt in val[1:]:
        entries = []
        if isinstance(opt, Dyn):
            ctx.gate('static!=resolved', opt.text[:60], 'restriction option not resolved', 'run eslint --print-config', source)
        elif isinstance(opt, str):
            entries.append(dict(name=opt))
        elif isinstance(opt, dict) and ('name' in opt and 'paths' not in opt and 'patterns' not in opt):
            entries.append(opt)                        # the array form: ['error', { name, importNames, message }]
        elif isinstance(opt, dict):
            for p in opt.get('paths') or []:
                entries.append(p if isinstance(p, dict) else dict(name=p))
            pats = opt.get('patterns') or []
            pats = pats if isinstance(pats, list) else [pats]
            str_neg = [p[1:] for p in pats if isinstance(p, str) and p.startswith('!')]   # the gitignore-list form
            for p in pats:
                if isinstance(p, dict):
                    grp = p.get('group') or p.get('regex') or []
                    grp = grp if isinstance(grp, list) else [grp]
                    neg = [g[1:] for g in grp if isinstance(g, str) and g.startswith('!')]
                    for g in grp:
                        if not (isinstance(g, str) and g.startswith('!')):
                            entries.append(dict(p, name=g, pattern=True, regex=bool(p.get('regex')), negated=neg))
                elif isinstance(p, str) and not p.startswith('!'):
                    entries.append(dict(name=p, pattern=True, negated=str_neg))
        for e in entries:
            msg = e.get('message') or ''
            if not isinstance(msg, str):               # a const the static reader could not resolve: name it, never crash
                name = msg.text if isinstance(msg, Dyn) else repr(msg)
                ctx.gate('static!=resolved', name, 'message not resolved', 'the wrapper column stays empty', source)
                msg = '<%s>' % name
            raw = e.get('name')
            if not isinstance(raw, str):
                name = raw.text if isinstance(raw, Dyn) else repr(raw)
                ctx.gate('static!=resolved', name, 'restricted specifier not resolved', 'no row for it', source)
                continue
            names = ''
            if e.get('importNames'):
                names = ','.join(str(x) for x in e['importNames'] if isinstance(x, str))
            elif isinstance(e.get('importNamePattern'), str):
                names = '/%s/' % e['importNamePattern']
            elif e.get('allowImportNames'):
                names = '!' + ','.join(str(x) for x in e['allowImportNames'] if isinstance(x, str))
            elif isinstance(e.get('allowImportNamePattern'), str):
                names = '!/%s/' % e['allowImportNamePattern']
            row = dict(raw=raw, wrapper=wrapper_of(msg), kind='regex' if e.get('regex') else 'pattern' if e.get('pattern')
                       else 'path', source=source, message=msg[:120], import_names=names,
                       type_imports='allowed' if e.get('allowTypeImports') else '')
            row['except'] = ','.join(x for x in e.get('negated') or [] if isinstance(x, str))
            ctx.wrappers.append(row)


def parse_eslint_flat(ctx, f, versions):
    src = read(os.path.join(ctx.root, f))
    base = f.rsplit('/', 1)[0] if '/' in f else ''
    toks = js_tokens(src)
    env = js_consts(toks, src)
    global_ignores = []
    for m in re.finditer(r'([\w$]+(?:\.[\w$]+)*\.configs(?:\.[\w$-]+|\[[\'"][\w/-]+[\'"]\])+)', src):
        ctx.gate('static!=resolved', m.group(1), 'preset not expanded', 'its rules are not rows; run eslint --print-config',
                 '%s:%d' % (f, line_of(src, m.start())))
    # every object literal that holds `rules:` or is an ignores-only object
    for i, t in enumerate(toks):
        if t[:2] == ('i', 'ignores') and i + 2 < len(toks) and toks[i + 1][:2] == ('p', ':'):
            j, depth = i - 1, 0
            while j >= 0:
                if toks[j][:2] == ('p', '}'): depth += 1
                elif toks[j][:2] == ('p', '{'):
                    if depth == 0: break
                    depth -= 1
                j -= 1
            if j >= 0:
                obj, _ = js_value(toks, j, src, env)
                if isinstance(obj, dict) and set(k for k in obj if k != 'name') == {'ignores'}:
                    global_ignores += [x for x in obj.get('ignores') or [] if isinstance(x, str)]
    bver = major(versions, 'eslint-plugin-boundaries')
    for i, t in enumerate(toks):
        if t[:2] != ('i', 'rules') or i + 2 >= len(toks) or toks[i + 1][:2] != ('p', ':'):
            continue
        j, depth = i - 1, 0
        while j >= 0:
            if toks[j][:2] == ('p', '}'): depth += 1
            elif toks[j][:2] == ('p', '{'):
                if depth == 0: break
                depth -= 1
            j -= 1
        obj, _ = js_value(toks, j, src, env) if j >= 0 else ({}, 0)
        if not isinstance(obj, dict) or not isinstance(obj.get('rules'), dict):
            continue
        named = [v for k, v in obj['rules'].items() if k != '...']
        if named and all(sev_of(v) == '?' for v in named):
            continue                                   # a plugin's rule MAP (`{ rules: { 'x': impl } }`), not config
        globs = [g for g in (obj.get('files') or []) if isinstance(g, str)]
        flat = []
        for g in globs if globs else []:
            flat.append(g)
        ign = [g for g in (obj.get('ignores') or []) if isinstance(g, str)] + global_ignores
        for spread in obj['rules'].get('...', []):
            ctx.gate('static!=resolved', spread.text if isinstance(spread, Dyn) else 'spread', 'rules spread not expanded',
                     'run eslint --print-config', '%s:%d' % (f, line_of(src, t[2])))
        rules_src = src[t[2]:]
        for name, val in obj['rules'].items():
            if name == '...':
                continue
            pos = rules_src.find(name)
            ln = line_of(src, t[2] + pos) if pos >= 0 else line_of(src, t[2])
            sev = sev_of(val)
            ctx.rule('eslint', name, sev, base, flat, ign, opt_text(val), '%s:%d' % (f, ln))
            if name in ('no-restricted-imports', '@typescript-eslint/no-restricted-imports'):
                restricted_imports(ctx, name, val if isinstance(val, list) else [val], '%s:%d' % (f, ln))
                if name.startswith('@typescript-eslint/'):
                    ctx.gate('deprecated-rule', name, 'use core no-restricted-imports (allowTypeImports)', '', '%s:%d' % (f, ln))
            if name.startswith('boundaries/') and bver is not None:
                renamed = {'boundaries/element-types': 'boundaries/dependencies', 'boundaries/no-unknown': 'boundaries/no-unknown-dependencies',
                           'boundaries/no-ignored': 'boundaries/no-ignored-dependencies'}
                if bver >= 6 and name == 'boundaries/element-types':
                    ctx.gate('boundaries-rename', name, 'renamed -> boundaries/dependencies (v%d)' % bver,
                             'old disable comments become unused directives: AL-30 rebaseline, not drift', '%s:%d' % (f, ln))
                elif bver >= 7 and name in renamed:
                    ctx.gate('boundaries-rename', name, 'renamed -> %s (v%d)' % (renamed[name], bver), 'AL-30 rebaseline', '%s:%d' % (f, ln))
                if bver >= 7 and name == 'boundaries/dependencies' and isinstance(val, list) and len(val) > 1 \
                        and isinstance(val[1], dict) and 'rules' in val[1] and 'policies' not in val[1]:
                    ctx.gate('boundaries-option', name, 'v%d reads `policies`, config has `rules`' % bver, 'AL-31', '%s:%d' % (f, ln))
            if name == 'unicorn/filename-case' and (major(versions, 'eslint-plugin-unicorn') or 0) >= 65:
                ctx.gate('unicorn-dirs', name, 'checks directories too (v>=65)', 'expect a count jump; checkDirectories:false opts out', '%s:%d' % (f, ln))
    # boundaries element patterns (V-09: a pattern that matches 0 files makes every policy vacuous). `mode`
    # (README v5.0.1, read 2026-10-18): `folder` is the default and works "like adding **/* to the given pattern";
    # folder and file modes match from the right side of the path; `full` matches the whole path only.
    for m in re.finditer(r'[\'"]boundaries/elements[\'"]\s*:', src):
        k = next((ix for ix, tt in enumerate(toks) if tt[2] >= m.end()), None)
        if k is None:
            continue
        val, _ = js_value(toks, k, src)
        for el in val if isinstance(val, list) else []:
            if isinstance(el, dict):
                pats = el.get('pattern')
                pats = pats if isinstance(pats, list) else [pats]
                pats = [p for p in pats if isinstance(p, str)]
                mode = el.get('mode') if el.get('mode') in ('file', 'full') else 'folder'
                rxs = [glob_re(p.rstrip('/') + '/**' if mode == 'folder' else p) for p in pats]
                n = sum(1 for fl in ctx.files if any(rx.match(fl[len(base) + 1:] if base else fl) or
                                                     (mode != 'full' and re.match('^(?:.*/)?' + rx.pattern.lstrip('^'), fl))
                                                     for rx in rxs))
                ctx.rule('eslint', 'boundaries/element:%s' % el.get('type', '?'), 'element', base, pats, [], '',
                         '%s:%d' % (f, line_of(src, m.start())), matched=n)


def parse_eslintrc(ctx, f, versions):
    src = read(os.path.join(ctx.root, f))
    base = f.rsplit('/', 1)[0] if '/' in f else ''
    ev = major(versions, 'eslint')
    if ev is not None and ev >= 10:
        ctx.gate('eslintrc-dead', f, 'ESLint %d reads flat config only' % ev, 'AL-31: dead config beside the flat one', f + ':1')
        return
    data = None
    if f.endswith(('.json', '.eslintrc')):
        data = load_jsonc(src)
    elif f.endswith(('.yml', '.yaml')):
        data = yaml_lite(src)
    elif f.endswith(('.js', '.cjs')):
        toks = js_tokens(src)
        for i, t in enumerate(toks):
            if t[:2] == ('p', '{'):
                data, _ = js_value(toks, i, src)
                break
    if not isinstance(data, dict):
        ctx.gate('static!=resolved', f, 'unreadable legacy config', '', f + ':1')
        return
    for name, val in (data.get('rules') or {}).items():
        ln = next((n for n, l in enumerate(src.split('\n'), 1) if name in l), 1)
        ctx.rule('eslint', name, sev_of(val), base, [], data.get('ignorePatterns') or [], opt_text(val), '%s:%d' % (f, ln))
        if name == 'no-restricted-imports':
            restricted_imports(ctx, name, val if isinstance(val, list) else [val], '%s:%d' % (f, ln))


def parse_stylelint(ctx, f):
    src = read(os.path.join(ctx.root, f))
    base = f.rsplit('/', 1)[0] if '/' in f else ''
    data = None
    if f.endswith(('.json', '.stylelintrc')):
        data = load_jsonc(src)
    elif f.endswith(('.yml', '.yaml')):
        data = yaml_lite(src)
    else:
        toks = js_tokens(src)
        for i, t in enumerate(toks):
            if t[:2] == ('i', 'rules') and i + 2 < len(toks) and toks[i + 1][:2] == ('p', ':'):
                val, _ = js_value(toks, i + 2, src)
                data = {'rules': val}
                break
    for name, val in ((data or {}).get('rules') or {}).items():
        if val is None or val is False:
            sev = 'off'
        elif isinstance(val, list) and len(val) > 1 and isinstance(val[-1], dict) and val[-1].get('severity'):
            sev = 'warn' if val[-1]['severity'] == 'warning' else 'error'
        else:
            sev = 'error'                              # stylelint's default severity is error
        ln = next((n for n, l in enumerate(src.split('\n'), 1) if name in l), 1)
        ctx.rule('stylelint', name, sev, base, [], [], opt_text(val if isinstance(val, list) else [None, val]),
                 '%s:%d' % (f, ln), ext=('.css', '.scss', '.less', '.vue', '.svelte'))


def parse_lslint(ctx, f):
    src = read(os.path.join(ctx.root, f))
    data = yaml_lite(src)
    base = f.rsplit('/', 1)[0] if '/' in f else ''
    ign = [i for i in (data.get('ignore') or []) if isinstance(i, str)]

    def walk(node, path):
        for k, v in (node or {}).items():
            if isinstance(v, dict):
                walk(v, path + [k])
            else:
                d = '/'.join(path) or '.'
                ln = next((n for n, l in enumerate(src.split('\n'), 1) if re.match(r'\s*%s\s*:' % re.escape(k), l)), 1)
                ext = None if k == '.dir' else ((k,) if k.startswith('.') else None)
                n = match_count(ctx.files, (base + '/' + d).strip('/') if d != '.' else base,
                                ['**'] if d == '.' or '*' not in d else [d + '/**'], ign, ext)
                ctx.rule('ls-lint', '%s %s' % (d, k), 'error', base, [d + '/**' if d != '.' else '**'], ign, str(v),
                         '%s:%d' % (f, ln), matched=n)
    walk(data.get('ls'), [])


def parse_depcruise(ctx, f):
    src = read(os.path.join(ctx.root, f))
    base = f.rsplit('/', 1)[0] if '/' in f else ''
    data = load_jsonc(src) if f.endswith('.json') else None
    if data is None:
        toks = js_tokens(src)
        for i, t in enumerate(toks):
            if t[:2] == ('i', 'forbidden') and i + 2 < len(toks) and toks[i + 1][:2] == ('p', ':'):
                val, _ = js_value(toks, i + 2, src)
                data = {'forbidden': val}
                break
    for r in (data or {}).get('forbidden') or []:
        if not isinstance(r, dict):
            continue
        frm = (r.get('from') or {}).get('path')
        to = (r.get('to') or {}).get('path')
        ln = next((n for n, l in enumerate(src.split('\n'), 1) if str(r.get('name')) in l), 1)
        n = None
        if isinstance(frm, str):
            try:
                rx = re.compile(frm)
                n = sum(1 for fl in ctx.files if (not base or fl.startswith(base + '/')) and rx.search(fl[len(base) + 1:] if base else fl))
            except re.error:
                n = None
        ctx.rule('depcruise', 'forbidden:%s' % r.get('name', '?'), SEV.get(r.get('severity', 'warn'), 'warn'), base,
                 [str(frm or '')], [], 'to=%s' % to, '%s:%d' % (f, ln), matched=n if n is not None else '')
        if isinstance(to, str) and 'node_modules/' in to:
            for lib in re.findall(r'node_modules/\(?([@\w|/.-]+)\)?', to):
                for one in lib.split('|'):
                    ctx.wrappers.append(dict(raw=one, wrapper='', kind='ban', source='%s:%d' % (f, ln), message=str(r.get('comment', ''))[:120]))


def parse_python(ctx, f, ci_rows, any_ci):
    src = read(os.path.join(ctx.root, f))
    base = f.rsplit('/', 1)[0] if '/' in f else ''
    data = toml_lite(src)
    ruff = (data.get('tool') or {}).get('ruff') if f.endswith('pyproject.toml') else data
    if isinstance(ruff, dict) and (ruff or f.endswith(('ruff.toml', '.ruff.toml'))):
        lint = ruff.get('lint') if isinstance(ruff.get('lint'), dict) else {}
        def opt(k):
            return lint.get(k, ruff.get(k)) or []
        for code in list(opt('select')) + list(opt('extend-select')):
            ln = next((n for n, l in enumerate(src.split('\n'), 1) if '"%s"' % code in l or "'%s'" % code in l), 1)
            ctx.rule('ruff', str(code), 'error', base, [], [], '', '%s:%d' % (f, ln), ext=('.py',))
        for code in list(opt('ignore')) + list(opt('extend-ignore')):
            ln = next((n for n, l in enumerate(src.split('\n'), 1) if '"%s"' % code in l), 1)
            ctx.rule('ruff', str(code), 'off', base, [], [], 'ignored', '%s:%d' % (f, ln), ext=('.py',))
        tidy = (lint.get('flake8-tidy-imports') or ruff.get('flake8-tidy-imports') or {})
        for mod, spec in (tidy.get('banned-api') or {}).items():
            msg = spec.get('msg', '') if isinstance(spec, dict) else str(spec)
            ln = next((n for n, l in enumerate(src.split('\n'), 1) if mod in l), 1)
            ctx.wrappers.append(dict(raw=mod, wrapper=wrapper_of(msg), kind='banned-api', source='%s:%d' % (f, ln), message=msg[:120]))
            ctx.rule('ruff', 'TID251:%s' % mod, 'error', base, [], [], msg[:80], '%s:%d' % (f, ln), ext=('.py',))
    il = (data.get('tool') or {}).get('importlinter') if f.endswith('pyproject.toml') else None
    if isinstance(il, dict):
        for c in il.get('contracts') or []:
            if isinstance(c, dict):
                ctx.rule('import-linter', '%s:%s' % (c.get('type', '?'), c.get('name', '?')), 'error', base, [], [], '', f + ':1', ext=('.py',))


def parse_importlinter_ini(ctx, f):
    src = read(os.path.join(ctx.root, f))
    base = f.rsplit('/', 1)[0] if '/' in f else ''
    for m in re.finditer(r'^\[importlinter:contract:([^\]]+)\]\s*\n((?:(?!\[)[^\n]*\n?)*)', src, re.M):
        body = m.group(2)
        tm = re.search(r'^type\s*=\s*(\S+)', body, re.M)
        nm = re.search(r'^name\s*=\s*(.+)$', body, re.M)
        ctx.rule('import-linter', '%s:%s' % (tm.group(1) if tm else '?', (nm.group(1) if nm else m.group(1)).strip()), 'error', base,
                 [], [], '', '%s:%d' % (f, line_of(src, m.start())), ext=('.py',))


def parse_tsconfig(ctx, f):
    src = read(os.path.join(ctx.root, f))
    base = f.rsplit('/', 1)[0] if '/' in f else ''
    data = load_jsonc(src)
    if not isinstance(data, dict):
        ctx.gate('static!=resolved', f, 'tsconfig unreadable', '', f + ':1')
        return
    co = data.get('compilerOptions') or {}
    for flag in ('strict', 'noImplicitAny', 'strictNullChecks', 'noUncheckedIndexedAccess', 'verbatimModuleSyntax',
                 'noUnusedLocals', 'noUnusedParameters', 'exactOptionalPropertyTypes', 'noImplicitReturns'):
        if flag in co:
            ln = next((n for n, l in enumerate(src.split('\n'), 1) if '"%s"' % flag in l), 1)
            ctx.rule('tsc', flag, 'error' if co[flag] is True else 'off', base, data.get('include') or [],
                     data.get('exclude') or [], '', '%s:%d' % (f, ln), ext=('.ts', '.tsx', '.mts', '.cts'))
    for alias, targets in (co.get('paths') or {}).items():
        ctx.exports.append(dict(package=alias, subpath='', target=','.join(targets) if isinstance(targets, list) else str(targets),
                                kind='alias', source=f))
    if data.get('extends'):
        ctx.gate('static!=resolved', f, 'extends %s not followed' % data['extends'], 'run tsc --showConfig', f + ':1')


def parse_misc(ctx, f):
    src = read(os.path.join(ctx.root, f))
    base = f.rsplit('/', 1)[0] if '/' in f else ''
    b = os.path.basename(f)
    if b == '.editorconfig':
        for ln, line in enumerate(src.split('\n'), 1):
            m = re.match(r'\s*(dotnet_diagnostic\.IDE1006\.severity|dotnet_naming_rule\.[\w.]+\.severity)\s*=\s*(\w+)', line)
            if m:
                ctx.rule('editorconfig', m.group(1), {'error': 'error', 'warning': 'warn', 'suggestion': 'warn', 'none': 'off',
                                                      'silent': 'off'}.get(m.group(2), m.group(2)), base, [], [], '',
                         '%s:%d' % (f, ln), ext=('.cs',))
        if re.search(r'dotnet_naming_rule', src) and not re.search(r'IDE1006\.severity\s*=\s*error', src):
            ctx.gate('ide1006', f, 'naming rules present; only IDE1006 severity is enforced at build', 'AL-03 candidate', f + ':1')
    elif b in ('.spectral.yaml', '.spectral.yml', '.spectral.json'):
        data = load_jsonc(src) if b.endswith('json') else yaml_lite(src)
        for name, val in ((data or {}).get('rules') or {}).items():
            sev = val.get('severity', 'warn') if isinstance(val, dict) else val
            ln = next((n for n, l in enumerate(src.split('\n'), 1) if name in l), 1)
            ctx.rule('spectral', name, {'error': 'error', 'warn': 'warn', 'info': 'warn', 'hint': 'warn', 'off': 'off',
                                        False: 'off', True: 'warn'}.get(sev, 'warn'), base, [], [], '', '%s:%d' % (f, ln),
                     ext=('.yaml', '.yml', '.json'))
    elif re.match(r'\.golangci\.ya?ml$', b):
        data = yaml_lite(src)
        en = ((data.get('linters') or {}).get('enable') or [])
        for lin in en:
            ln = next((n for n, l in enumerate(src.split('\n'), 1) if str(lin) in l), 1)
            ctx.rule('golangci-lint', str(lin), 'error', base, [], [], '', '%s:%d' % (f, ln), ext=('.go',))


def parse_exports(ctx, f):
    d = load_jsonc(read(os.path.join(ctx.root, f))) or {}
    name = d.get('name')
    if not name:
        return
    ex = d.get('exports')
    if isinstance(ex, str):
        ctx.exports.append(dict(package=name, subpath='.', target=ex, kind='exports', source=f))
    elif isinstance(ex, dict):
        for k, v in ex.items():
            if k.startswith('.'):
                ctx.exports.append(dict(package=name, subpath=k, target=json.dumps(v) if not isinstance(v, str) else v,
                                        kind='exports', source=f))
    elif d.get('main') or d.get('module'):
        ctx.exports.append(dict(package=name, subpath='.', target=d.get('module') or d.get('main'), kind='main', source=f))


# ---------------------------------------------------------------- docs
GENERIC = {'file', 'files', 'with', 'from', 'that', 'this', 'naming', 'name', 'names', 'style', 'styles', 'convention',
           'conventions', 'shape', 'shapes', 'pattern', 'patterns', 'case', 'usage', 'format', 'option', 'kind', 'type'}
ADR_META = re.compile(r'(?i)^(?:[-*+]\s+)?(?:\*\*)?(?:status|date|deciders?|decided|accepted|authors?|owners?|supersedes|'
                      r'superseded[ -]by|amends|amended[ -]by|tags|consulted|informed|technical story|ticket|issue)(?:\*\*)?\s*[:|]')
MARK_START = re.compile(r'<!--\s*refine-enriched:start\s*-->')
MARK_END = re.compile(r'<!--\s*refine-enriched:end\s*-->')


def adr_meta(src):
    status, date = '', ''
    m = re.search(r'(?im)^\s*(?:[-*]\s*)?(?:\*\*)?status(?:\*\*)?\s*[:|]\s*\**\s*([A-Za-z]+)', src) or \
        re.search(r'(?im)^##\s*status\s*\n+\s*([A-Za-z]+)', src)
    if m:
        status = m.group(1).lower()
    m = re.search(r'(?im)^\s*(?:[-*]\s*)?(?:\*\*)?(?:status|date|decided|accepted)\b[^\n]*?(\d{4}-\d{2}-\d{2})', src)
    if m:
        date = m.group(1)
    frozen = re.search(r'(?i)(?:frozen|until|deleted (?:on|after|by)|removal (?:on|by))[^\n]{0,40}?(\d{4}-\d{2}-\d{2})', src)
    return status, date, frozen.group(1) if frozen else ''


def doc_files(root, files, extra):
    out = []
    for f in files:
        low = f.lower()
        if not low.endswith('.md'):
            continue
        if low in ('ai/conventions.md', 'ai/architecture.md', 'ai/modules.md', 'ai/glossary.md', 'contributing.md',
                   '.github/contributing.md', 'docs/contributing.md', 'claude.md', 'ai/_convention-cheatsheet.md',
                   'ai/core/invariants.md') or GENERATED_DOCS.search(f) or re.match(r'ai/patterns/[^/]+\.md$', low):
            out.append((f, 'doc'))      # CLAUDE.md, the cheatsheet, invariants and ai/patterns/ are where agents read rules
        elif any(low.startswith(d + '/') for d in ADR_DIRS) and re.search(r'/(?:adr-?)?\d{3,4}[-_]', '/' + low.rsplit('/', 1)[-1] if False else '/' + os.path.basename(low)):
            out.append((f, 'adr'))
        elif re.search(r'(?:^|/)docs/[^/]*(?:design-system|tokens|style-?guide|conventions|naming|glossary)[^/]*\.md$', low):
            out.append((f, 'doc'))
    for e in extra:
        if e in files and (e, 'doc') not in out:
            out.append((e, 'doc'))
    return out


def parse_docs(root, docs):
    rows, n = [], 0
    for f, kind in docs:
        src = read(os.path.join(root, f))
        lines = src.split('\n')
        generated_file = bool(GENERATED_DOCS.search(f))
        status, date, frozen = adr_meta(src) if kind == 'adr' else ('', '', '')
        in_marker, section, in_unsettled, in_decision = False, '', False, False
        glossary = f.lower().endswith('glossary.md')
        normative_only = bool(re.search(r'(?i)^(?:claude\.md|ai/patterns/)', f))   # how-to prose: only its MUST / never lines
        rulebook = bool(re.search(r'(?i)(?:^|/)(?:ai/conventions|ai/_convention-cheatsheet|ai/core/invariants|contributing|'
                                  r'docs/[^/]*conventions[^/]*)\.md$', f)) or generated_file
        # a bullet and its indented continuation lines are one rule (quote joined; source = the bullet's line)
        logical, i = [], 0
        while i < len(lines):
            line = lines[i]
            j = i + 1
            if re.match(r'^\s*[-*+]\s+\S|^\s*\d+[.)]\s+\S', line):
                ind = len(line) - len(line.lstrip())
                while j < len(lines) and lines[j].strip() and not re.match(r'^\s*(?:[-*+]|\d+[.)])\s+|^\s*#|^\s*\||^\s*<!--', lines[j]) \
                        and len(lines[j]) - len(lines[j].lstrip()) > ind:
                    line = line.rstrip() + ' ' + lines[j].strip()
                    j += 1
            logical.append((i + 1, line))
            i = j
        for ln, line in logical:
            if MARK_START.search(line):
                in_marker = True; continue
            if MARK_END.search(line):
                in_marker = False; continue
            h = re.match(r'^(#{1,6})\s+(.*)$', line)
            if h:
                section = h.group(2).strip()
                in_unsettled = bool(re.match(r'(?i)unsettled conventions', section))
                in_decision = bool(re.match(r'(?i)decision\b', section))
                continue
            s = line.strip()
            if not s or s.startswith(('>', '<!--')) or re.match(r'^\|?\s*:?-{3,}', s):
                continue
            if s.startswith('|') and re.match(r'(?i)^\|\s*(?:category|rule|term|layer|name|convention)\s*\|', s):
                continue                               # a table header row
            if kind == 'adr' and ADR_META.match(s):
                continue                               # ADR front matter (Status / Date / Deciders), not a rule
            prov = 'found' if '[found:' in s else 'inferred' if '[inferred:' in s else 'unconfirmed' if '[unconfirmed' in s \
                else 'sampled' if '[SAMPLED' in s else 'plain'
            if '[CONTESTED:' in s:
                rk, tag, tier = 'contested', 'contested', 'contested'
            elif in_unsettled and s.startswith('|'):
                rk, tag, tier = 'unsettled', 'contested', 'contested'
            elif glossary and (s.startswith('|') or re.match(r'^[-*]\s+\S', s)):
                rk, tag, tier = 'glossary', 'written', 'T2'
            elif kind == 'adr' and (in_decision or NORMATIVE.search(s)) and not s.startswith('|'):
                rk = 'adr-decision'
                tag, tier = ('written', 'T2') if status in ('', 'accepted', 'approved', 'adopted', 'decided') else ('inactive', 'inactive')
            elif NORMATIVE.search(s) or not normative_only and ((s.startswith('|') and RULE_SECTIONS.search(section)) or
                    (re.match(r'^(?:[-*+]|\d+[.)])\s', s) and (rulebook or RULE_SECTIONS.search(section)))):
                rk = 'table' if s.startswith('|') else 'normative' if NORMATIVE.search(s) else 'bullet'
                tag, tier = 'written', 'T2'
            else:
                continue
            if tag == 'written' and (in_marker or generated_file or prov in ('inferred', 'unconfirmed', 'sampled')):
                tag, tier = 'generated', 'T2g'
            n += 1
            note = ''
            if kind == 'adr':
                note = 'adr=%s@%s' % (status or '-', date or '-') + (' frozen-until=%s' % frozen if frozen else '')
            rows.append(dict(id='D%d' % n, tag=tag, tier=tier, kind=rk, section=section[:60] + (' ' + note if note else ''),
                             provenance=prov, source='%s:%d' % (f, ln), quote=s[:400]))
    # P-29: a T2g row naming a contested category is contested
    cats = []
    for r in rows:
        if r['tag'] != 'contested':
            continue
        q = r['quote']
        cat = q.split('|')[1] if r['kind'] == 'unsettled' and q.count('|') >= 2 else re.sub(r'\[CONTESTED:[^\]]*\]', '', q)
        words = [w.lower() for w in re.findall(r'[A-Za-z]{4,}', cat) if w.lower() not in GENERIC]
        if words:
            cats.append((set(words[:4]), r['source']))
    for r in rows:
        if r['tag'] in ('generated', 'written'):
            ws = set(w.lower() for w in re.findall(r'[A-Za-z]{4,}', r['quote']))
            for cw, src_ in cats:
                if cw and cw <= ws:
                    if r['tag'] == 'generated':
                        r['tag'], r['tier'] = 'contested', 'contested'
                    r['section'] += ' contested-by=%s' % src_
                    break
    return rows


# ---------------------------------------------------------------- inline reasons
SUPP = [('eslint', re.compile(r'eslint-disable(?P<kind>-next-line|-line)?(?:\s+(?P<rules>[^*\n]*?))?(?:\s+--\s+(?P<reason>[^\n*]*?))?\s*(?:\*/|-->|$)')),
        ('stylelint', re.compile(r'stylelint-disable(?P<kind>-next-line|-line)?(?:\s+(?P<rules>[^*\n]*?))?(?:\s+--\s+(?P<reason>[^\n*]*?))?\s*(?:\*/|$)')),
        ('ruff', re.compile(r'#\s*noqa(?::\s*(?P<rules>[A-Z]+\d+(?:\s*,\s*[A-Z]+\d+)*))?(?P<kind>)(?:\s*(?:#|--|-)?\s*(?P<reason>.*))?$')),
        ('golangci', re.compile(r'//\s*nolint(?::(?P<rules>[\w,-]+))?(?P<kind>)(?:\s*//\s*(?P<reason>.*))?$')),
        ('biome', re.compile(r'biome-ignore(?P<kind>)\s+(?P<rules>[\w/-]+)(?:\s*:\s*(?P<reason>.*))?$')),
        ('ast-grep', re.compile(r'ast-grep-ignore(?P<kind>)(?::\s*(?P<rules>[\w, -]+))?(?:\s+--\s+(?P<reason>.*))?$')),
        ('tsc', re.compile(r'@ts-(?P<rules>expect-error|ignore)(?P<kind>)\s*(?::|--)?\s*(?P<reason>.*)$'))]


def reason_kind(reason, adr_ids):
    r = (reason or '').strip().strip('*/').strip()
    if not r:
        return 'none', 'n/a'
    m = re.search(r'\bADR[- ]?0*(\d+)\b', r, re.I)
    if m:
        return 'adr', 'yes' if int(m.group(1)) in adr_ids else 'no'
    if re.search(r'\b[A-Z][A-Z0-9]+-\d+\b|#\d{2,}\b|https?://', r):
        return 'ticket', 'n/a'
    if len(re.sub(r'\W', '', r)) >= 3:
        return 'text', 'n/a'
    return 'none', 'n/a'


BACKREF = re.compile(r'(?i)\bsee\s+(?:above|previous|prior|the comment above)\b|^(?:as|per|same(?:\s+as)?)\s+(?:above|previous|before)\b|'
                     r'^\(?above\)?\.?$|^ditto\b')
COMMENT_OPEN = re.compile(r'(?://+|/\*+!?|<!--|\{/\*+)\s*$')


def comment_text(line):
    """The prose of a comment-only line ('' when the line is code or a directive)."""
    m = re.match(r'^\s*(?://+|#+|/?\*+|<!--|\{/\*+)\s?(.*?)\s*(?:\*/\}?|-->)?\s*$', line)
    if not m or re.search(r'eslint-disable|stylelint-disable|noqa|nolint|biome-ignore|ast-grep-ignore|@ts-(?:expect-error|ignore)', line):
        return ''
    return m.group(1).strip()


def linted_by_ci(ci_rows, any_ci, f):
    """A test file's disables count only where CI lints that tree (`apps/api/test` in a package's `eslint
    "test/**/*.ts"`); with no CI file at all, test trees stay out, as before."""
    if not any_ci:
        return False
    for r in ci_rows:
        if r['tool'] in ('tsc', 'test'):
            continue
        for t in r['target'].split(','):
            t = t.strip().strip('/')
            if t in ('.', '') or f == t or f.startswith(t + '/'):
                return True
    return False


def parse_exceptions(root, files, adr_ids, rule_ids, ci_rows=(), any_ci=False):
    rows = []
    for f in files:
        if not f.endswith(CODE_EXT):
            continue
        if (TEST_DIR.search(f) or re.search(r'\.(?:test|spec|stories)\.', f)) and not linted_by_ci(ci_rows, any_ci, f):
            continue
        lines = read(os.path.join(root, f)).split('\n')
        last_reason = ''
        for ln, line in enumerate(lines, 1):
            if not re.search(r'eslint-disable|stylelint-disable|noqa|nolint|biome-ignore|ast-grep-ignore|@ts-(?:expect-error|ignore)', line):
                continue
            for tool, rx in SUPP:
                m = rx.search(line)
                if not m:
                    continue
                if tool not in ('ruff', 'golangci') and not COMMENT_OPEN.search(line[:m.start()]):
                    break                              # prose that NAMES a directive (a config comment, a doc string)
                rules = re.sub(r'\s+', '', (m.group('rules') or '').strip().rstrip('*/').strip()) or '*'
                kind = (m.group('kind') or '').lstrip('-') or ('file' if tool in ('eslint', 'stylelint') and '/*' in line
                                                                and ln <= 5 and 'next-line' not in line else 'line')
                if tool in ('eslint', 'stylelint') and m.group('kind') is None and '/*' in line and ln > 5:
                    kind = 'block'
                reason = (m.group('reason') or '').strip()
                shown = reason
                if reason and BACKREF.search(reason):  # `-- see above`: the reason is the comment just above, or the last one given
                    above, k, skipped = [], ln - 2, 0
                    while k >= 0 and len(above) < 4:
                        c = comment_text(lines[k])
                        if c:
                            above.insert(0, c)
                        elif above or skipped >= 2 or not lines[k].strip():
                            break
                        else:
                            skipped += 1                # a statement head between the comment and the directive
                        k -= 1
                    rest = BACKREF.sub('', reason).strip(' ,;:.-')
                    resolved = ' '.join(above) or last_reason or rest
                    shown = ('%s -> %s' % (reason, resolved)) if resolved else reason
                    reason = resolved
                    last_reason = resolved or last_reason
                elif reason:
                    last_reason = reason
                rk, res = reason_kind(reason, adr_ids)
                inor = 'yes' if any(r in rule_ids for r in rules.split(',')) else 'no'
                rows.append(dict(site='%s:%d' % (f, ln), tool=tool, rules=rules, scope=kind, reason_kind=rk, resolves=res,
                                 in_oracle=inor, cluster=0, reason=shown[:100], key=reason.lower()))
                break
    groups = {}
    for r in rows:
        if r['reason_kind'] != 'none':
            for rule in r['rules'].split(','):
                groups.setdefault((rule, r['key']), []).append(r)    # the RESOLVED reason: `see above` is not one string
    for g in groups.values():
        for r in g:
            r['cluster'] = max(r['cluster'], len(g))
    return rows


# ---------------------------------------------------------------- structural specs (tests that enforce a convention)
SPEC_READS = re.compile(r'\b(?:readFileSync|readdirSync|readdir|globSync|fast-glob|fg\.(?:sync|glob)|tinyglobby|ts-morph|new Project\(|'
                        r'ArchRuleDefinition|archunit|Konsist|import_linter|ast\.parse\(|os\.walk\(|pathlib|filepath\.Walk)')
SPEC_RATCHET = re.compile(r'(?:only-falls?|ratchet|ceiling|baseline)', re.I)
SPEC_CEIL = re.compile(r'\b[A-Z][A-Z0-9_]*(?:CEILING|BASELINE|BUDGET|MAX_ALLOWED)S?\b\s*(?::[^=]+)?=')


def parse_specs(root, files, ci_rows, any_ci):
    """A test that reads the source tree and asserts a shape (`*-only-falls.spec.ts`, an ArchUnit rule, a layout
    spec) is enforcement when CI runs the test task: a doc rule it asserts is not AL-03. `kind` ratchet = it holds a
    count that may only fall (name or a CEILING / BASELINE const), the input of convention-ratchet-scan § 2c."""
    rows = []
    tests = [r for r in ci_rows if r['tool'] == 'test']
    for f in files:
        if not (re.search(r'\.(?:spec|test)\.[cm]?[jt]sx?$|(?:^|/)test_[^/]+\.py$|_test\.(?:py|go)$|(?:Test|Tests|Spec)\.(?:java|kt)$', f)):
            continue
        src = read(os.path.join(root, f))
        if not SPEC_READS.search(src):
            continue
        ratchet = bool(SPEC_RATCHET.search(os.path.basename(f)) or SPEC_CEIL.search(src))
        t = re.search(r'\b(?:describe|test|it)\s*\(\s*([\'"`])(.{3,120}?)\1', src)
        if not any_ci:
            ci = 'unknown'
        else:
            ci = 'yes' if any(tt in ('.', '') or f.startswith(tt + '/') for r in tests for tt in r['target'].split(',')) else 'no'
        rows.append(dict(spec=f, kind='ratchet' if ratchet else 'structural', ci=ci, title=(t.group(2) if t else '')[:120]))
    return rows


# ---------------------------------------------------------------- git ages
def git_ages(root):
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0')
    try:
        top = subprocess.run(['git', '-C', root, 'rev-parse', '--show-toplevel'], capture_output=True, text=True, env=env, timeout=30)
        if top.returncode != 0:
            return {}, 'history-blind (not a git work tree)'
        cnt = subprocess.run(['git', '-C', root, 'rev-list', '--count', 'HEAD', '--', '.'], capture_output=True, text=True, env=env, timeout=60)
        if cnt.returncode != 0 or int(cnt.stdout.strip() or 0) <= 1:
            return {}, 'history-blind (<= 1 commit touches this root)'
        log = subprocess.run(['git', '-C', root, 'log', '--diff-filter=A', '--name-only', '--format=%x00%as', '--relative', '--', '.'],
                             capture_output=True, text=True, env=env, timeout=300)
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return {}, 'history-blind (git unavailable)'
    ages, date = {}, ''
    for line in log.stdout.split('\n'):
        if line.startswith('\x00'):
            date = line[1:].strip()
        elif line.strip():
            ages[line.strip()] = date                 # later lines are older: the last one is the first add
    if len(set(ages.values())) <= 1:
        return ages, 'history-blind (one add date for every file)'
    live = [d for p, d in ages.items() if os.path.exists(os.path.join(root, p))] or list(ages.values())
    cnt = {}
    for d in live:
        cnt[d] = cnt.get(d, 0) + 1
    top, k = max(cnt.items(), key=lambda kv: kv[1])
    if k >= 0.9 * len(live):     # an imported or squashed history: "newest" would sample one day's import (measured
        return ages, 'history-blind (%d of %d files first-added on %s: an import or squash)' % (k, len(live), top)   # 2026-10-18)
    return ages, 'dated'


# ---------------------------------------------------------------- build
def safe(ctx, f, fn, *args):
    """One config the reader cannot parse is a gate row, never a crash of the whole map (a crash exited 1, which
    the `quotes` contract reserves for `rows dropped`, and printed no row at all)."""
    try:
        fn(ctx, f, *args)
    except Exception as e:                             # noqa: BLE001 — any reader bug in any config file
        ctx.gate('static!=resolved', f, 'parser error (%s: %s)' % (type(e).__name__, str(e)[:80]),
                 'its rules are not rows; run the tool\'s own print-config', f + ':1')


def build(root, extra_docs=(), age=False):
    files = list_files(root)
    versions = parse_versions(root, files)
    ci_rows = parse_ci(root, files)
    any_ci = any(CI_FILES.match(f) for f in files)
    ctx = Ctx(root, files)
    ev = major(versions, 'eslint')
    flat = [f for f in files if re.search(r'(?:^|/)eslint\.config\.(?:js|mjs|cjs|ts|mts|cts)$', f)]
    legacy = [f for f in files if re.search(r'(?:^|/)\.eslintrc(?:\.(?:json|js|cjs|yml|yaml))?$', f)]
    for f in flat:
        safe(ctx, f, parse_eslint_flat, versions)
    for f in legacy:
        if flat and (ev is None or ev >= 9):
            ctx.gate('eslintrc-dead' if ev is None or ev >= 10 else 'eslintrc-shadowed', f,
                     'flat config present; ESLint %s does not read %s' % (ev if ev is not None else '?', os.path.basename(f)),
                     'AL-31 candidate', f + ':1')
            continue
        safe(ctx, f, parse_eslintrc, versions)
    for f in files:
        b = os.path.basename(f)
        if re.match(r'(?:\.stylelintrc(?:\.(?:json|ya?ml|js|cjs|mjs))?|stylelint\.config\.(?:js|cjs|mjs|ts))$', b):
            safe(ctx, f, parse_stylelint)
        elif b in ('.ls-lint.yml', '.ls-lint.yaml'):
            safe(ctx, f, parse_lslint)
        elif re.match(r'\.dependency-cruiser\.(?:js|cjs|mjs|json)$', b):
            safe(ctx, f, parse_depcruise)
        elif b in ('pyproject.toml', 'ruff.toml', '.ruff.toml'):
            safe(ctx, f, parse_python, ci_rows, any_ci)
        elif b in ('.importlinter', 'setup.cfg') and 'importlinter' in read(os.path.join(root, f)):
            safe(ctx, f, parse_importlinter_ini)
        elif re.match(r'tsconfig(?:\.[\w-]+)?\.json$', b):
            safe(ctx, f, parse_tsconfig)
        elif b in ('.editorconfig', '.spectral.yaml', '.spectral.yml', '.spectral.json') or re.match(r'\.golangci\.ya?ml$', b):
            safe(ctx, f, parse_misc)
        elif b == 'package.json':
            safe(ctx, f, parse_exports)
    # version gates
    if ev is not None:
        ctx.gate('eslint-major', 'eslint', 'v%d' % ev, 'flat config only' if ev >= 10 else 'flat or eslintrc',
                 versions['eslint']['source'])
        if ev >= 10:
            for plug, fork in (('eslint-plugin-jsx-a11y', 'eslint-plugin-jsx-a11y-x'), ('eslint-plugin-import', 'eslint-plugin-import-x'),
                               ('eslint-plugin-react', None)):
                if plug in versions:
                    ctx.gate('peer<=9', plug, 'peers ESLint <= 9 on ESLint %d' % ev,
                             'use %s' % fork if fork else 'check its peer range before proposing a rule', versions[plug]['source'])
    tv = major(versions, 'typescript')
    if tv is not None and tv >= 7 and '@typescript/typescript6' not in versions:
        ctx.gate('ts7-no-api', 'typescript', 'typed lint rules and ts-morph NOT RUN', 'alias typescript to @typescript/typescript6',
                 versions['typescript']['source'])
    bv = major(versions, 'eslint-plugin-boundaries')
    if bv is not None:
        ctx.gate('boundaries-major', 'eslint-plugin-boundaries', 'v%d' % bv,
                 'rule boundaries/dependencies, option policies' if bv >= 7 else 'rule boundaries/dependencies, option rules'
                 if bv >= 6 else 'rule boundaries/element-types', versions['eslint-plugin-boundaries']['source'])
    # tags
    for r in ctx.rules:
        tool_ci = {'tsc': 'tsc'}.get(r['tool'], r['tool'])
        prefixes = scope_prefixes(r['base'], r['globs'] if r['tool'] in ('eslint', 'ls-lint') else [])
        r['ci'] = ci_covers(ci_rows, tool_ci, prefixes, any_ci)
        if r['severity'] == 'off':
            r['tag'], r['tier'] = 'off', 'off'
        elif r['severity'] == 'warn':
            r['tag'], r['tier'] = 'written', 'T1-warn'
        elif r['severity'] == 'element':
            r['tag'], r['tier'] = 'enforced' if r['ci'] != 'no' else 'written', 'T1' if r['ci'] != 'no' else 'T1-noci'
        elif r['ci'] == 'no':
            r['tag'], r['tier'] = 'written', 'T1-noci'
        else:
            r['tag'], r['tier'] = 'enforced', 'T1'
    docs = parse_docs(root, doc_files(root, files, extra_docs))
    adr_ids = set()
    for f in files:
        m = re.search(r'(?:^|/)(?:adr-?)?0*(\d{1,4})[-_][^/]*\.md$', f, re.I)
        if m and any(f.lower().startswith(d + '/') for d in ADR_DIRS):
            adr_ids.add(int(m.group(1)))
    rule_ids = set(r['rule'] for r in ctx.rules)
    exceptions = parse_exceptions(root, files, adr_ids, rule_ids, ci_rows, any_ci)
    specs = parse_specs(root, files, ci_rows, any_ci)
    ages, hist = git_ages(root) if age else ({}, '')
    return dict(files=files, versions=versions, ci=ci_rows, any_ci=any_ci, ctx=ctx, docs=docs, exceptions=exceptions,
                specs=specs, ages=ages, history=hist)


COLS = {
    'rules': ['id', 'tool', 'rule', 'severity', 'tag', 'tier', 'scope', 'ignores', 'matched', 'ci', 'options', 'source'],
    'docs': ['id', 'tag', 'tier', 'kind', 'section', 'provenance', 'source', 'quote'],
    'wrappers': ['raw', 'wrapper', 'kind', 'source', 'message', 'import_names', 'except', 'type_imports'],
    'exports': ['package', 'subpath', 'target', 'kind', 'source'],
    'versions': ['package', 'major', 'version', 'source', 'manifest', 'declared'],
    'gates': ['gate', 'subject', 'verdict', 'detail', 'source'],
    'ci': ['source', 'tool', 'target', 'command'],
    'exceptions': ['site', 'tool', 'rules', 'scope', 'reason_kind', 'resolves', 'in_oracle', 'cluster', 'reason'],
    'specs': ['spec', 'kind', 'ci', 'title'],
}


def tables(m):
    ctx = m['ctx']
    return {'rules': ctx.rules, 'docs': m['docs'], 'wrappers': ctx.wrappers, 'exports': ctx.exports,
            'versions': sorted(m['versions'].values(), key=lambda r: r['package']), 'gates': ctx.gates, 'ci': m['ci'],
            'exceptions': m['exceptions'], 'specs': m.get('specs', [])}


def tsv(cols, recs):
    out = ['# ' + '\t'.join(cols)]
    for r in recs:
        out.append('\t'.join(str(r.get(c, '')).replace('\t', ' ').replace('\n', ' ') for c in cols))
    return '\n'.join(out) + '\n'


def summary(m):
    ctx = m['ctx']
    cnt = {}
    for r in ctx.rules:
        cnt[r['tier']] = cnt.get(r['tier'], 0) + 1
    for r in m['docs']:
        cnt[r['tier']] = cnt.get(r['tier'], 0) + 1
    lines = ['oracle: T1 %d · T1-warn %d · T1-noci %d · T2 %d · T2g %d (unratified) · contested %d · off %d · inactive %d' % tuple(
        cnt.get(k, 0) for k in ('T1', 'T1-warn', 'T1-noci', 'T2', 'T2g', 'contested', 'off', 'inactive'))]
    tools = {}
    for r in ctx.rules:
        tools[r['tool']] = tools.get(r['tool'], 0) + 1
    lines.append('config rules by tool: ' + (' · '.join('%s %d' % kv for kv in sorted(tools.items())) or 'none'))
    lines.append('docs: %d rows from %d files · wrappers %d · exports %d · ci lint steps %d%s · exceptions %d (reasonless %d)' % (
        len(m['docs']), len({d['source'].rsplit(':', 1)[0] for d in m['docs']}), len(ctx.wrappers), len(ctx.exports),
        len(m['ci']), '' if m['any_ci'] else ' (no CI file: ci=unknown)', len(m['exceptions']),
        sum(1 for e in m['exceptions'] if e['reason_kind'] == 'none')))
    sp = m.get('specs', [])
    lines.append('structural specs: %d (%d ratchets) · CI runs them: %d yes, %d no, %d unknown' % (
        len(sp), sum(1 for r in sp if r['kind'] == 'ratchet'), sum(1 for r in sp if r['ci'] == 'yes'),
        sum(1 for r in sp if r['ci'] == 'no'), sum(1 for r in sp if r['ci'] == 'unknown')))
    vac = [r for r in ctx.rules if r['matched'] == 0 and r['tag'] != 'off']
    lines.append('vacuous (matched 0 files): %d%s' % (len(vac), ''.join('\n  %s %s %s (%s)' % (r['id'], r['tool'], r['rule'], r['source']) for r in vac[:10])))
    for g in ctx.gates:
        lines.append('gate %s: %s — %s %s (%s)' % (g['gate'], g['subject'], g['verdict'], g['detail'], g['source']))
    if m['history']:
        lines.append('ages: %s (%d files dated)' % (m['history'], len(m['ages'])))
    return '\n'.join(lines)


def write_out(m, out):
    os.makedirs(out, exist_ok=True)
    for name, recs in tables(m).items():
        with open(os.path.join(out, name + '.tsv'), 'w') as fh:
            fh.write(tsv(COLS[name], recs))
    if m['history']:
        with open(os.path.join(out, 'ages.tsv'), 'w') as fh:
            fh.write('# path\tfirst_added\n')
            if m['history'] != 'dated':
                fh.write('# %s\n' % m['history'])
            for p, d in sorted(m['ages'].items()):
                fh.write('%s\t%s\n' % (p, d))


def load_out(out):
    res = {}
    for name in COLS:
        p = os.path.join(out, name + '.tsv')
        recs = []
        if os.path.isfile(p):
            lines = read(p).rstrip('\n').split('\n')
            cols = lines[0][2:].split('\t') if lines else []
            for l in lines[1:]:
                if l and not l.startswith('#'):
                    recs.append(dict(zip(cols, l.split('\t'))))
        res[name] = recs
    return res


# ---------------------------------------------------------------- propose (AL-02) and quotes (AL-01)
def propose(root, sites_text, oracle, min_sites, min_share, newest):
    concerns = {}
    for line in sites_text.split('\n'):
        if not line.strip() or line.startswith('#'):
            continue
        parts = line.split('\t')
        if len(parts) < 3:
            continue
        concerns.setdefault(parts[0], []).append((parts[1], parts[2].split(':')[0]))
    ages, hist = git_ages(root)
    contested = [d for d in oracle.get('docs', []) if d.get('tag') == 'contested']
    contested.sort(key=lambda d: d.get('kind') not in ('unsettled', 'contested'))   # cite the split itself, not a P-29 re-tag
    out = []
    for c, sites in sorted(concerns.items()):
        n = len(sites)
        cnt = {}
        for shape, _ in sites:
            cnt[shape] = cnt.get(shape, 0) + 1
        top, k = max(cnt.items(), key=lambda kv: (kv[1], kv[0]))
        share = k / float(n)
        cwords = set(w.lower() for w in re.findall(r'[A-Za-z]{4,}', c)) - GENERIC   # 'file-case:api/*.ts' names no category
        hit = next((d for d in contested if cwords and cwords <= set(w.lower() for w in re.findall(r'[A-Za-z]{4,}', d.get('quote', '')))), None)
        line = '%s: n=%d · %s' % (c, n, ' · '.join('%s %d' % kv for kv in sorted(cnt.items(), key=lambda kv: -kv[1])))
        if hist == 'dated':
            files = sorted({p for _, p in sites}, key=lambda p: ages.get(p, ''), reverse=True)[:newest]
            fshape = {}
            for shape, p in sites:
                if p in files:
                    fshape.setdefault(p, shape)
            nk = sum(1 for p in files if fshape.get(p) == top)
            recent = 'newest %d files %d/%d' % (len(files), nk, len(files))
            recent_ok = len(files) > 0 and nk / float(len(files)) >= min_share
        else:
            recent, recent_ok = 'whole-tree only, %s' % (hist or 'history-blind'), True
        if hit:
            verdict = 'contested — ask (%s)' % hit['source']
        elif n >= min_sites and share >= min_share and recent_ok:
            verdict = 'proposed canonical: %s (k/n = %d/%d = %.2f, %s) — ratify?' % (top, k, n, share, recent)
        else:
            verdict = 'undetermined — ask (k/n = %d/%d = %.2f, %s; floor %d sites, %.2f share)' % (k, n, share, recent, min_sites, min_share)
        out.append('%s\n  %s\n  ledger_rows: 0' % (line, verdict))
    return '\n'.join(out) if out else 'propose: no sites read'


def resolve_quote(root, oracle, spec, site=''):
    spec = (spec or '').strip()
    m = re.match(r'^([^\s:"]+?)(?::(\d+))?\s+["“](.+?)["”]\s*$', spec)
    if m:
        path, quote = m.group(1), m.group(3)
        p = os.path.join(root, path)
        if not os.path.isfile(p):
            return 'dropped', 'oracle file absent: %s' % path
        norm = lambda s: re.sub(r'\s+', ' ', s).strip()
        if norm(quote) not in norm(read(p)):
            return 'dropped', 'quote absent from %s' % path
        doc = next((d for d in oracle.get('docs', []) if d['source'].split(':')[0] == path and norm(quote) in norm(d['quote'])), None)
        if doc and doc['tag'] == 'generated':
            return 'unconfirmed', 'generated (T2g) — ratify %s' % doc['source']
        if doc and doc['tag'] == 'contested':
            return 'contested', 'AL-02 (%s)' % doc['source']
        return 'kept', 'written (%s)' % (doc['source'] if doc else path)
    rid = re.sub(r'^(?:eslint|stylelint|ruff|depcruise|ls-lint|tsc|spectral|import-linter):', '', spec)
    cands = [r for r in oracle.get('rules', []) if r['rule'] == rid or r['rule'] == 'forbidden:' + rid]
    if not cands:
        return 'dropped', 'no oracle (rule id not declared)' if spec else 'no oracle cited'
    probe = site_probe(site)
    if probe and len(cands) > 1:
        # one rule id, several blocks: cite the block whose scope holds the SITE (measured 2026-10-18: a domain-layer
        # row resolved to the shared/ block's line, because the first block with that id won)
        inside = [r for r in cands if rule_holds(r, probe)]
        if not inside:
            return 'dropped', 'rule %s declared %d times, no scope holds %s' % (rid, len(cands), probe[0])
        cands = inside
    rank = {'enforced': 0, 'written': 1, 'off': 2}
    spec_len = lambda r: max([len(re.split(r'[*?{\[]', g, 1)[0]) for g in (r.get('scope') or '').split(',')] or [0])
    rule = sorted(cands, key=lambda r: (rank.get(r['tag'], 3), -spec_len(r)))[0]     # the most specific block
    if rule['tag'] == 'off':
        return 'dropped', 'rule is off (%s)' % rule['source']
    return 'kept', '%s %s (%s)' % (rule['tag'], rule['tier'], rule['source'])


def site_probe(site):
    """Concrete paths a candidate's site text stands for: `a/b.ts:12` -> [a/b.ts]; a directory or glob summary
    (`apps/api/src/modules/*/domain (21 rows)`) -> a file under it per common extension."""
    m = re.search(r'(?:^|\s)((?:[\w@.-]+|\*\*?)(?:/(?:[\w@.{},|-]+|\*\*?))+)', site or '')
    if not m:
        return []
    p = m.group(1).split(':')[0]
    p = re.sub(r'(\w[\w-]*)\|[\w|-]+', r'\1', p)                 # pages|components -> pages
    p = re.sub(r'\*\*?', 'x', re.sub(r'\{([^,}]*)[^}]*\}', r'\1', p))
    if re.search(r'\.\w{1,5}$', p.rsplit('/', 1)[-1]):
        return [p]
    return [p + suf for suf in ('/x/f.ts', '/x/f.tsx', '/f.ts', '/f.tsx', '/x/f.py', '/f.py', '/x/f.css', '/f.vue')]


def rule_holds(r, probe):
    scope = r.get('scope') or ''
    globs = [g for g in re.split(r',(?![^{]*\})', scope) if g]
    ign = [glob_re(g) for g in re.split(r',(?![^{]*\})', r.get('ignores') or '') if g]
    for p in probe:
        if any(rx.match(p) for rx in ign):
            continue
        for g in globs or ['**']:
            g = g[2:] if g.startswith('./') else g
            try:
                if g.startswith('^') and re.search(g, p) or not g.startswith('^') and glob_re(g).match(p):
                    return True
            except re.error:
                return True
    return False


def quotes(root, cand_path, oracle):
    raw = read(cand_path) if cand_path != '-' else sys.stdin.read()
    cands = []
    try:
        data = json.loads(raw)
        cands = data if isinstance(data, list) else data.get('candidates', [])
    except ValueError:
        lines = [l for l in raw.split('\n') if l.strip()]
        cols = lines[0].lstrip('# ').split('\t') if lines else []
        cands = [dict(zip(cols, l.split('\t'))) for l in lines[1:] if not l.startswith('#')]
    out, dropped = [], 0
    for i, c in enumerate(cands, 1):
        verdict, why = resolve_quote(root, oracle, c.get('oracle', ''), c.get('site', ''))
        dropped += verdict == 'dropped'
        out.append('%s\t%s\t%s\t%s' % (c.get('id', 'C%d' % i), verdict, why, c.get('site', c.get('evidence', ''))))
    print('# id\tverdict\twhy\tsite')
    print('\n'.join(out))
    print('AL-01: %d candidate rows dropped (of %d)' % (dropped, len(cands)))
    return 1 if dropped else 0


# ---------------------------------------------------------------- CLI
def main(argv):
    try:
        return main_(argv)
    except Exception:                                  # noqa: BLE001 — exit 2 with the cause, never exit 1 silently
        sys.stderr.write(traceback.format_exc())
        sys.stderr.write('oracle-map: internal error (exit 2): the map was NOT built; every align class reading it is blocked\n')
        return 2


def main_(argv):
    if argv == ['--self-test']:
        return self_test()
    if not argv or argv[0].startswith('-'):
        sys.stderr.write(__doc__.split('\n\n')[2] + '\n'); return 2
    root = argv[0]
    if not os.path.isdir(root):
        sys.stderr.write('oracle-map: %s is not a directory\n' % root); return 2
    sub = argv[1] if len(argv) > 1 and not argv[1].startswith('-') else 'build'
    opts = {}
    for a in argv[1 + (sub != 'build'):]:
        if a.startswith('--') and '=' in a:
            k, v = a[2:].split('=', 1); opts[k] = v
        elif a.startswith('--'):
            opts[a[2:]] = True
        else:
            sys.stderr.write('oracle-map: unexpected %s\n' % a); return 2
    root_abs = os.path.realpath(root)
    if sub == 'build':
        m = build(root, [d for d in str(opts.get('docs', '')).split(',') if d], bool(opts.get('age-buckets')))
        if opts.get('json'):
            t = tables(m)
            t['summary'] = summary(m)
            print(json.dumps(t, indent=1, default=str))
            return 0
        out = opts.get('out')
        if not out or out is True:
            out = tempfile.mkdtemp(prefix='oracle-map-', dir=os.environ.get('TMPDIR') or None)
        out_abs = os.path.realpath(out)
        if out_abs == root_abs or out_abs.startswith(root_abs + os.sep):
            sys.stderr.write('oracle-map: --out must be outside the scanned root (never write into the repo)\n'); return 2
        write_out(m, out)
        print(summary(m))
        print('out: %s' % out)
        return 0
    oracle = load_out(opts['oracle']) if opts.get('oracle') else tables(build(root))
    if sub == 'propose':
        src = opts.get('sites', '-')
        text = sys.stdin.read() if src in ('-', True) else read(src)
        print(propose(root, text, oracle, int(opts.get('min-sites', 30)), float(opts.get('min-share', 0.75)), int(opts.get('newest', 20))))
        return 0
    if sub == 'quotes':
        if not opts.get('candidates'):
            sys.stderr.write('oracle-map quotes: --candidates=<json|tsv|-> required\n'); return 2
        return quotes(root, opts['candidates'], oracle)
    sys.stderr.write('oracle-map: unknown subcommand %s\n' % sub); return 2


# ---------------------------------------------------------------- self-test
def self_test():
    base = tempfile.mkdtemp(prefix='oracle-map-', dir=os.environ.get('TMPDIR') or None)
    root = os.path.join(base, 'repo')
    W = {
        'package.json': json.dumps({'name': 'acme', 'private': True, 'scripts': {'lint': 'eslint apps/web'},
                                    'devDependencies': {'eslint': '^10.0.0', 'typescript': '^7.0.0', 'eslint-plugin-boundaries': '^7.0.0',
                                                        'eslint-plugin-jsx-a11y': '6.10.2'}}),
        'pnpm-lock.yaml': "lockfileVersion: '9.0'\n\nimporters:\n\n  .:\n    devDependencies:\n      eslint:\n        specifier: ^10.0.0\n"
                          "        version: 10.1.0(jiti@2.4.2)\n      typescript:\n        specifier: ^7.0.0\n        version: 7.0.2\n"
                          "      eslint-plugin-boundaries:\n        specifier: ^7.0.0\n        version: 7.2.0(eslint@10.1.0)\n\npackages:\n\n  eslint@10.1.0:\n    resolution: {}\n",
        'node_modules/eslint-plugin-boundaries/package.json': json.dumps({'name': 'eslint-plugin-boundaries', 'version': '7.3.1'}),
        'eslint.config.mjs': "import js from '@eslint/js';\nexport default [\n  { ignores: ['**/dist/**'] },\n  js.configs.recommended,\n"
                             "  {\n    files: ['apps/web/**/*.{ts,tsx}'],\n    settings: { 'boundaries/elements': [{ type: 'featurez', pattern: 'src/featurez/*' },\n"
                             "      { type: 'feature', pattern: 'apps/web/src/features/*' }, { type: 'full', pattern: 'src/features/*', mode: 'full' }] },\n"
                             "    rules: {\n      'no-restricted-imports': ['error', { paths: [{ name: 'ky', message: 'Use @acme/http instead.' },\n"
                             "        { name: 'dayjs', message: 'dayjs is banned; use @acme/format.' }],\n"
                             "        patterns: [{ group: ['@radix-ui/*'], message: 'use @acme/ui' }] }],\n"
                             "      'boundaries/element-types': [2, { default: 'disallow' }],\n      eqeqeq: 'warn',\n"
                             "      'no-console': 'off',\n      // 'no-alert': 'error',\n    },\n  },\n  {\n    files: ['services/**/*.ts'],\n"
                             "    rules: { 'no-restricted-imports': ['error', 'moment'] },\n  },\n];\n",
        '.eslintrc.json': '{ "rules": { "semi": "error" } }',
        'tsconfig.json': '{\n  // comment\n  "compilerOptions": {\n    "strict": true,\n    "paths": { "@/*": ["./src/*"] }\n  }\n}\n',
        '.ls-lint.yml': 'ls:\n  apps/web/src:\n    .dir: kebab-case\n    .tsx: PascalCase\nignore:\n  - node_modules\n',
        '.github/workflows/ci.yml': 'jobs:\n  lint:\n    steps:\n      - run: npm run lint\n      - run: ruff check services/py\n',
        'apps/web/src/OrderRow.tsx': "// eslint-disable-next-line no-restricted-imports -- ADR-0007 pdf stream\nimport ky from 'ky';\n"
                                     "// eslint-disable-next-line no-restricted-imports\nimport ky2 from 'ky';\n",
        'apps/web/src/features/cart/Cart.tsx': "export const Cart = 1;\n",
        'apps/web/src/a.ts': "/* eslint-disable no-restricted-imports -- ADR-0099 gone */\nexport const a = 1;\n",
        'services/api/main.ts': "export const x = 1;\n",
        'services/py/pyproject.toml': '[tool.ruff]\nline-length = 100\n\n[tool.ruff.lint]\nselect = [\n  "E",\n  "N",\n  "TID",\n]\n'
                                      'extend-ignore = ["TID251"]\n\n[tool.ruff.lint.flake8-tidy-imports.banned-api]\n'
                                      '"requests".msg = "use app.http_client"\n',
        'services/py/app/x.py': "import requests  # noqa: TID251\nimport os  # noqa: E401 legacy shim kept per ORD-12\n",
        'ai/conventions.md': '# Conventions\n\n## Naming\n\n- Component files are PascalCase. Never kebab.\n'
                             '<!-- refine-enriched:start -->\n- Hook files are camelCase and always start with `use` [inferred: sampled 10/40 files]\n'
                             '- Stores must end in `.store.ts`.\n\n## Unsettled conventions\n\n| Category | Option A | Option B | Observation |\n'
                             '|---|---|---|---|\n| hook file naming | kebab-case `use-x.ts` — 5 | camelCase `useX.ts` — 4 | split |\n<!-- refine-enriched:end -->\n',
        '.claude/_extracted-codebase.md': '## Conventions\n- toast style [CONTESTED: toast.error 6/11, notify 5/11]\n',
        'docs/adr/0007-raw-http-for-pdf.md': '# ADR 0007\n\nStatus: accepted (2026-01-02)\n\n## Decision\n\nPDF streaming uses raw ky.\n',
        'docs/adr/0009-freeze-legacy.md': '# ADR 0009\n\nStatus: accepted\n\n## Decision\n\nlegacy-reports is frozen until 2027-03-31.\n',
        'docs/adr/0010-proposal.md': '# ADR 0010\n\nStatus: proposed\n\n## Decision\n\nAll forms must use zod.\n',
        'docs/adr/0011-css-modules.md': '# ADR-0011 — CSS Modules over styled-components\n\n- Status: Accepted\n- Date: 2026-03-01\n\n'
                                        '## Decision\n\nNew components use CSS Modules.\n',
        'packages/http/package.json': json.dumps({'name': '@acme/http', 'exports': {'.': './src/index.ts', './retry': './src/retry.ts'}}),
        '.dependency-cruiser.cjs': "module.exports = { forbidden: [ { name: 'no-moment', severity: 'error', from: { path: '^apps' }, "
                                   "to: { path: 'node_modules/(moment|dayjs)' } } ] };\n",
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
        m = build(root, (), False)
        t = tables(m)
        R = {(r['tool'], r['rule'], r['source'].split(':')[0]): r for r in t['rules']}
        V = m['versions']
        check('eslint version from pnpm-lock v9', V['eslint']['version'] == '10.1.0' and V['eslint']['source'] == 'pnpm-lock')
        check('boundaries version from node_modules wins', V['eslint-plugin-boundaries']['version'] == '7.3.1')
        nri = next((r for r in t['rules'] if r['rule'] == 'no-restricted-imports' and r['scope'].startswith('apps/web')), None)
        check('flat rule read with files scope', nri is not None and nri['scope'] == 'apps/web/**/*.{ts,tsx}')
        check('CI lints apps/web -> enforced', nri is not None and nri['tag'] == 'enforced' and nri['ci'] == 'yes')
        svc = [r for r in t['rules'] if r['rule'] == 'no-restricted-imports' and r['scope'].startswith('services')]
        check('services rule not linted in CI -> written T1-noci', svc and svc[0]['tier'] == 'T1-noci')
        check('warn -> written T1-warn', R.get(('eslint', 'eqeqeq', 'eslint.config.mjs'), {}).get('tier') == 'T1-warn')
        check('off -> off', R.get(('eslint', 'no-console', 'eslint.config.mjs'), {}).get('tag') == 'off')
        check('commented rule is not a row', ('eslint', 'no-alert', 'eslint.config.mjs') not in R)
        check('wrapper from message', any(w['raw'] == 'ky' and w['wrapper'] == '@acme/http' for w in t['wrappers']))
        check('pattern wrapper', any(w['raw'] == '@radix-ui/*' and w['wrapper'] == '@acme/ui' for w in t['wrappers']))
        check('ruff banned-api wrapper', any(w['raw'] == 'requests' and w['wrapper'] == 'app.http_client' for w in t['wrappers']))
        check('depcruise ban', any(w['raw'] == 'moment' and w['kind'] == 'ban' for w in t['wrappers']))
        G = {(g['gate'], g['subject']) for g in t['gates']}
        check('eslintrc dead on v10', ('eslintrc-dead', '.eslintrc.json') in G)
        check('preset not expanded', any(g[0] == 'static!=resolved' and 'js.configs.recommended' in g[1] for g in G))
        check('boundaries rename gate', ('boundaries-rename', 'boundaries/element-types') in G)
        check('TS7 typed lint NOT RUN', ('ts7-no-api', 'typescript') in G)
        check('jsx-a11y fork named', ('peer<=9', 'eslint-plugin-jsx-a11y') in G)
        el = [r for r in t['rules'] if r['rule'].startswith('boundaries/element:')]
        check('vacuous boundaries element matched 0', el and el[0]['matched'] == 0)
        elm = {r['rule']: r['matched'] for r in el}
        check('boundaries folder element (default mode) counts files under it', elm.get('boundaries/element:feature') == 1)
        check('boundaries mode full is not right-side matched', elm.get('boundaries/element:full') == 0)
        check('"use X." message drops the period', any(w['raw'] == 'dayjs' and w['wrapper'] == '@acme/format' for w in t['wrappers']))
        check('ADR Status/Date bullets are not rule rows',
              not any(re.match(r'- (?:Status|Date):', d['quote']) for d in t['docs'])
              and any('New components use CSS Modules' in d['quote'] and 'adr=accepted@2026-03-01' in d['section'] for d in t['docs']))
        check('tsconfig strict read; CI runs no tsc -> T1-noci', R.get(('tsc', 'strict', 'tsconfig.json'), {}).get('tier') == 'T1-noci')
        check('tsconfig alias survives "/*" in a string (JSONC)', any(e['package'] == '@/*' and e['kind'] == 'alias' for e in t['exports']))
        check('ADR date from the status line', any('adr=accepted@2026-01-02' in d['section'] for d in t['docs']))
        check('workspace exports', any(e['package'] == '@acme/http' and e['subpath'] == './retry' for e in t['exports']))
        check('ls-lint rule', any(r['tool'] == 'ls-lint' and '.tsx' in r['rule'] for r in t['rules']))
        check('ruff select N + TID251 off', R.get(('ruff', 'N', 'services/py/pyproject.toml'), {}).get('tag') == 'enforced'
              and R.get(('ruff', 'TID251', 'services/py/pyproject.toml'), {}).get('tag') == 'off')
        D = {d['quote'][:30]: d for d in t['docs']}
        hum = [d for d in t['docs'] if 'Component files are PascalCase' in d['quote']]
        check('human line written T2', hum and hum[0]['tag'] == 'written')
        gen = [d for d in t['docs'] if 'Stores must end' in d['quote']]
        check('marker line generated T2g', gen and gen[0]['tag'] == 'generated')
        hook = [d for d in t['docs'] if 'Hook files are camelCase' in d['quote']]
        check('generated line naming a contested category -> contested (P-29)', hook and hook[0]['tag'] == 'contested')
        check('unsettled row contested', any(d['kind'] == 'unsettled' and 'hook file naming' in d['quote'] for d in t['docs']))
        check('CONTESTED row contested', any(d['kind'] == 'contested' and 'toast' in d['quote'] for d in t['docs']))
        check('accepted ADR written', any('raw ky' in d['quote'] and d['tag'] == 'written' for d in t['docs']))
        check('proposed ADR inactive', any('zod' in d['quote'] and d['tag'] == 'inactive' for d in t['docs']))
        check('ADR frozen-until captured', any('frozen-until=2027-03-31' in d['section'] for d in t['docs']))
        E = {e['site']: e for e in t['exceptions']}
        check('reasoned disable -> adr resolves', E.get('apps/web/src/OrderRow.tsx:1', {}).get('resolves') == 'yes')
        check('reasonless disable -> none', E.get('apps/web/src/OrderRow.tsx:3', {}).get('reason_kind') == 'none')
        check('file-level disable with dead ADR', E.get('apps/web/src/a.ts:1', {}).get('scope') == 'file'
              and E.get('apps/web/src/a.ts:1', {}).get('resolves') == 'no')
        check('noqa ticket reason', E.get('services/py/app/x.py:2', {}).get('reason_kind') == 'ticket')
        orc = t
        check('quote kept (human)', resolve_quote(root, orc, 'ai/conventions.md:5 "Component files are PascalCase"')[0] == 'kept')
        check('quote absent dropped (AL-01)', resolve_quote(root, orc, 'ai/conventions.md "hooks should return objects"')[0] == 'dropped')
        check('generated quote unconfirmed', resolve_quote(root, orc, 'ai/conventions.md "Stores must end in"')[0] == 'unconfirmed')
        check('rule id kept', resolve_quote(root, orc, 'eslint:no-restricted-imports')[0] == 'kept')
        check('unknown rule dropped', resolve_quote(root, orc, 'eslint:no-such-rule')[0] == 'dropped')
        sites = ''.join('props-style\ttype\tsrc/f%d.ts\n' % i for i in range(34)) + ''.join('props-style\tinterface\tsrc/g%d.ts\n' % i for i in range(6))
        out = propose(root, sites, orc, 30, 0.75, 20)
        check('floor met -> proposed canonical, 0 rows', 'proposed canonical: type' in out and 'ledger_rows: 0' in out)
        out = propose(root, ''.join('dialog\tA\tf%d\n' % i for i in range(6)) + ''.join('dialog\tB\tg%d\n' % i for i in range(5)), orc, 30, 0.75, 20)
        check('below floor -> undetermined', 'undetermined — ask' in out)
        out = propose(root, ''.join('hook file naming\tkebab\tf%d\n' % i for i in range(40)), orc, 30, 0.75, 20)
        check('contested concern -> ask', 'contested — ask' in out)
        out = propose(root, ''.join('file-case:api/*.ts\tkebab\tf%d\n' % i for i in range(40)), orc, 30, 0.75, 20)
        check('generic words (file, case) never match a contested row', 'contested' not in out and 'proposed canonical: kebab' in out)
        # ---- real-repo shapes (measured 2026-10-18 on a NestJS + React monorepo); each case failed before its fix
        r2 = os.path.join(base, 'mono')
        W2 = {
            'package.json': json.dumps({'name': 'mono', 'private': True, 'scripts': {'lint': 'turbo run lint', 'test': 'turbo run test'},
                                        'devDependencies': {'eslint': '^10.0.0'}}),
            'apps/api/package.json': json.dumps({'name': '@m/api', 'scripts': {'lint': 'eslint "src/**/*.ts" "test/**/*.ts" --config ../../eslint.config.mjs',
                                                                            'test': 'jest --coverage'}}),
            'apps/web/package.json': json.dumps({'name': '@m/web', 'scripts': {'lint': 'eslint "src/**/*.{ts,tsx}"'}}),
            '.github/workflows/ci.yml': 'jobs:\n  ci:\n    steps:\n      - name: typecheck\n      - run: pnpm run lint\n'
                                        '      - run: pnpm run test\n      - name: e2e\n        run: |\n          export X=1\n'
                                        '          pnpm --filter @m/api exec jest \\\n            --config jest.e2e.cjs\n',
            'eslint.config.mjs': "import { ADR_TEXT } from './adr.mjs';\nconst FEATURE_UP = ['@/widgets/**', '@/app/**', '!@/app/view-registry'];\n"
                                 "const USE_UI = 'Use `@m/ui` for every primitive.';\n"
                                 "const localPlugin = { rules: { 'no-px': noPx, 'ratchet': ratchetRule } };\n"
                                 "export default [\n  { plugins: { local: localPlugin } },\n"
                                 "  { files: ['apps/web/src/features/**/*.tsx'], rules: { 'no-restricted-imports': ['error', { patterns: [\n"
                                 "    { group: FEATURE_UP, message: 'FSD: features/ must not import widgets/ or app/.' },\n"
                                 "    { group: ['@radix-ui/*'], message: USE_UI },\n"
                                 "    { group: ['@/**', './**'], importNamePattern: '^fetch[A-Z]', message: 'a fetch* function is transport - go through a ViewModel (model/use-*).' },\n"
                                 "    { group: ['./api/*'], allowTypeImports: true, message: 'Views must not use react-query directly' },\n"
                                 "  ] }] } },\n"
                                 "  { files: ['apps/api/src/**/domain/**/*.ts'], rules: { 'no-restricted-imports': ['error', {\n"
                                 "    patterns: [{ group: ['@m/contracts/*', '!@m/contracts/vocab'], message: ADR_TEXT }],\n"
                                 "    paths: [{ name: 'node:crypto', importNames: ['timingSafeEqual'], message: 'Use constantTimeEqual from shared/crypto' }] }] } },\n"
                                 "  { files: ['apps/api/src/**/*.ts'], rules: { 'no-restricted-imports': ['error', 'lodash'] } },\n"
                                 "  { files: ['apps/api/src/**/*.ts'], rules: { '@typescript-eslint/no-restricted-imports': ['error', ...['crypto'].map((n) => ({ name: n }))] } },\n"
                                 "];\n// A reason is required: see `eslint-disable-next-line <rule> -- <why>` in CONTRIBUTING.\n",
            'apps/api/test/unit/layers-only-fall.spec.ts': "import { readFileSync } from 'node:fs';\nconst CEILING = 12;\n"
                                                           "describe('cross-layer imports only fall', () => { it('holds', () => { readFileSync('x'); }); });\n"
                                                           "// eslint-disable-next-line no-restricted-imports -- fixture reads the wall it tests\nimport 'lodash';\n",
            'apps/api/scripts/repair.ts': "// Every tenant's rows, on purpose: the repair is platform-wide.\nconst rows = (em) =>\n"
                                          "  // eslint-disable-next-line no-restricted-syntax -- platform-wide read, see above\n  em.run();\n"
                                          "// eslint-disable-next-line no-restricted-syntax -- see above\nem.run();\n",
            'apps/api/src/x.ts': "export const x = 1;\n",
            'apps/web/src/features/a/b.tsx': "export const b = 1;\n",
            'CLAUDE.md': '# Project\n\nSome context.\n\n## Rules\n\n- Never import a sibling feature\'s internals.\n- The repo has three apps.\n',
            'ai/patterns/forms.md': '# Forms\n\nA form has a schema.\n\n## Component\n\n- Every form MUST use `useEntityForm`.\n- Fields sit in a grid.\n',
        }
        for f, c in W2.items():
            pth = os.path.join(r2, f)
            os.makedirs(os.path.dirname(pth), exist_ok=True)
            with open(pth, 'w') as fh:
                fh.write(c)
        m2 = build(r2, (), False)
        t2 = tables(m2)
        WR = t2['wrappers']
        CI = [(c['tool'], c['target']) for c in t2['ci']]
        check('IR-1 an imported message const renders <NAME> and a gate row, never a crash',
              any(w['message'] == '<ADR_TEXT>' for w in WR) and any(g['subject'] == 'ADR_TEXT' for g in t2['gates']))
        check('IR-2 turbo run lint expands to each package script (target per package)',
              ('eslint', 'apps/api/src,apps/api/test') in CI and ('eslint', 'apps/web/src') in CI)
        check('IR-2 the expanded rule is enforced, not T1-noci', all(r['tier'] == 'T1' for r in t2['rules'] if r['tool'] == 'eslint' and r['severity'] == 'error'))
        check('IR-2 pnpm --filter <pkg> exec jest in a run: | block -> test row for that package', ('test', 'apps/api') in CI)
        check('IR-2 a step NAMED typecheck is not a tsc command', not any(c[0] == 'tsc' for c in CI))
        check('IR-3 a plugin rule map is not config', not any(r['rule'] in ('no-px', 'ratchet') for r in t2['rules']))
        check('IR-4 importNamePattern travels with the row', any(w['raw'] == '@/**' and w['import_names'] == '/^fetch[A-Z]/' for w in WR))
        check('IR-4 importNames travels with the row', any(w['raw'] == 'node:crypto' and w['import_names'] == 'timingSafeEqual' for w in WR))
        check('IR-4 allowTypeImports travels with the row', any(w['raw'] == './api/*' and w['type_imports'] == 'allowed' for w in WR))
        check('IR-5 a ! entry is no row; it narrows its group', not any(w['raw'].startswith('!') for w in WR)
              and any(w['raw'] == '@m/contracts/*' and w['except'] == '@m/contracts/vocab' for w in WR))
        check('IR-6 a const array group resolves', any(w['raw'] == '@/app/**' and w['except'] == '@/app/view-registry' for w in WR))
        check('IR-6 a const string message resolves (and names its wrapper)', any(w['raw'] == '@radix-ui/*' and w['wrapper'] == '@m/ui' for w in WR))
        check('IR-6 a spread mapped call is a gate, not rows', not any(w['raw'] == 'crypto' for w in WR)
              and any('restriction option not resolved' in g['verdict'] for g in t2['gates']))
        check('IR-7 a negated verb or an article is no wrapper', all(w['wrapper'] == '' for w in WR if w['raw'] in ('./api/*', '@/**')))
        E2 = {e['site']: e for e in t2['exceptions']}
        check('IR-13 a disable in a CI-linted test tree is a row', 'apps/api/test/unit/layers-only-fall.spec.ts:4' in E2)
        check('IR-13 config prose that names a directive is no row', not any(k.startswith('eslint.config.mjs') for k in E2))
        check('IR-14 `see above` reads the comment above, not the literal words',
              'platform-wide' in E2.get('apps/api/scripts/repair.ts:3', {}).get('reason', '') and
              'Every tenant' in E2.get('apps/api/scripts/repair.ts:3', {}).get('reason', '') and
              E2.get('apps/api/scripts/repair.ts:5', {}).get('reason_kind') == 'text')
        check('IR-16 a rule id resolves to the block whose scope holds the site',
              'eslint.config.mjs:13' in resolve_quote(r2, t2, 'eslint:no-restricted-imports', 'apps/api/src/orders/domain/x.ts:1')[1]
              and resolve_quote(r2, t2, 'eslint:no-restricted-imports', 'packages/other/src/x.ts:1')[0] == 'dropped')
        check('IR-17 CLAUDE.md and ai/patterns normative lines are T2 rows; their plain bullets are not',
              any('Never import a sibling' in d['quote'] for d in t2['docs']) and any('MUST use' in d['quote'] for d in t2['docs'])
              and not any('three apps' in d['quote'] or 'grid' in d['quote'] for d in t2['docs']))
        check('IR-17 a source-reading spec is a structural spec, kind ratchet, CI yes',
              any(sp['spec'].endswith('layers-only-fall.spec.ts') and sp['kind'] == 'ratchet' and sp['ci'] == 'yes' for sp in t2['specs']))
        saved = globals()['parse_ci']
        globals()['parse_ci'] = lambda *a: 1 / 0
        try:
            sys.stderr, keep = open(os.devnull, 'w'), sys.stderr
            rc = main([r2, '--out=' + os.path.join(base, 'o2')])
        finally:
            sys.stderr.close(); sys.stderr = keep
            globals()['parse_ci'] = saved
        check('IR-1 an internal error exits 2 (1 is reserved for quotes dropping rows)', rc == 2)
        gitdir = os.path.join(base, 'hist')
        if shutil.which('git'):
            env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1', GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t',
                       GIT_COMMITTER_NAME='t', GIT_COMMITTER_EMAIL='t@t')
            os.makedirs(gitdir)
            subprocess.run(['git', 'init', '-q', gitdir], env=env, capture_output=True)
            for i in range(10):
                open(os.path.join(gitdir, 'f%d.ts' % i), 'w').write('x')
            subprocess.run(['git', '-C', gitdir, 'add', '-A'], env=env, capture_output=True)
            subprocess.run(['git', '-C', gitdir, 'commit', '-qm', 'import'], env=dict(env, GIT_AUTHOR_DATE='2026-01-01T00:00:00'), capture_output=True)
            open(os.path.join(gitdir, 'late.ts'), 'w').write('y')
            subprocess.run(['git', '-C', gitdir, 'add', '-A'], env=env, capture_output=True)
            subprocess.run(['git', '-C', gitdir, 'commit', '-qm', 'late'], env=dict(env, GIT_AUTHOR_DATE='2026-02-01T00:00:00'), capture_output=True)
            check('IR-10 10 of 11 files added on one day is history-blind (an import), not dated', git_ages(gitdir)[1].startswith('history-blind (10 of 11'))
        outdir = os.path.join(base, 'out')
        write_out(m, outdir)
        back = load_out(outdir)
        check('tsv round trip', len(back['rules']) == len(t['rules']) and len(back['docs']) == len(t['docs']))
        check('never wrote into the root', not any(x.endswith('.tsv') for x in list_files(root)))
        rc = main([root, '--out=' + os.path.join(root, 'o')])
        check('--out inside root refused', rc == 2 and not os.path.exists(os.path.join(root, 'o')))
    finally:
        shutil.rmtree(base, ignore_errors=True)
    for b in bad:
        sys.stderr.write('  FAIL %s\n' % b)
    print('oracle-map --self-test: %d/%d %s' % (tot[0] - len(bad), tot[0], 'OK' if not bad else 'FAIL'))
    return 0 if not bad else 3


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
