#!/usr/bin/env python3
"""align-sweep-gate.py — find-and-align's proof ladder (eval § 3.3): the deterministic gates an align fix-run
must pass BEFORE any reviewer reads it. Cheap rejections first; the first FAIL stops the ladder (--all runs
every step). A judge's opinion can turn PASS into pending-review, never FAIL into PASS.

Why a script: the failure modes of a sweep are invisible file by file. Two files fixed two ways (AL-33), a
reordered import in an untouched function (AL-34), a snapshot quietly re-recorded, a token name that does not
exist, a `13px -> --space-3` snap that changes pixels, a boundary rule whose pattern matches nothing — each
diff hunk looks fine alone. These gates read the whole run.

Usage:  python3 -I align-sweep-gate.py ladder   --base-dir=<tree> --patch=<diff> --ledger=<md> [opts]
        python3 -I align-sweep-gate.py ladder   --repo=<git dir> --base=<ref> --ledger=<md> [opts]
        python3 -I align-sweep-gate.py <check>  …same inputs…        (one step: oracle approval diffkind lock-paths
                                                 scope redetect consistency names roundtrip ratchet lock-count vacuous)
        python3 -I align-sweep-gate.py --fix-runs=<dir> [--base-dir=<tree>] [--all]   every run in a fix-runs dir;
                                                 compares each run's <name>.expect when present
        python3 -I align-sweep-gate.py --self-test [--fix-runs=<dir>]
opts:   --all · --json · --run-json=<file> (approvals / coverage / judge, see below) · --judge=<tsv|json>
        · --oracle=<oracle-map out dir> (rule ids for L0) · --tokens=<path to token-map.py>
Nothing is written into <tree> or <repo>: the head tree is a copy under a mktemp -d in $TMPDIR (git archive for
--repo, which never writes the repo; GIT_OPTIONAL_LOCKS=0), removed at exit unless --keep.

INPUT FORMAT — a fix-run is a base tree + a unified diff + the ledger rows the run closes.
  Layout A (benchmarks/fixtures/convention-drift/fix-runs/, base = the fixture root, or --base-dir):
    fix-runs/<name>.patch        unified diff, `--- a/<rel>` / `+++ b/<rel>` (git diff, any -U; /dev/null = add or
                                 delete). Applied to a scratch copy of the base; context is verified (±50 lines).
    fix-runs/<name>.ledger.md    rows in the align-ledger `- id: A<NNN>` form (a blank line ends a row). Fields
                                 read (item 21 of the eval adds the new ones):
        id                       A<NNN>
        al_class | class         AL-05 … AL-34 (legacy class names accepted)
        closure_verb             replace-with-shared | rename | dedupe | remove | … (sets the L4 footprint)
        proof_class              EQ | VC | FN — absent: derived at L8 (round-trips -> EQ, else VC)
        scope                    [a, b] or a list: the files the fix may touch
        evidence                 list of <path>:<line>, BASE numbering: every one must change, nothing else may
        oracle                   <path>[:<line>] "<quote>"  |  <tool>:<rule-id>     (must resolve — L0, AL-01)
        detector_re              Python regex the gate re-runs on the head copy (V-00). Preferred: deterministic
        detector_cmd             argv string run in the head copy, `{files}` = the touched files; output
                                 `path:line[:…]` lines (e.g. `rg -n --no-heading -e '#d92d20' {files}`)
        detector_scope           glob(s) the rule applies to (V-09 `matched N files`); default: evidence files
        canary                   a line that MUST be flagged when planted in a scratch copy (V-09 canary)
        rename                   old->new (the `rename` verb's footprint: lines naming either)
        approval                 <name>@<iso> — a VC row only (V-03b); never filled by an agent
    fix-runs/<name>.json         optional: {"approvals": {"A101": "ana@2026-10-18"}, "coverage": {"base": 81.2,
                                 "head": 80.9}, "judge": [{"id": "A101", "verdict": "PASS|FAIL|pending-review",
                                 "reason": "…"}], "matched": {"A101": 12}}
    fix-runs/<name>.expect       expected verdicts, one per line: `<check> <PASS|FAIL|NOT RUN|PASS-flagged>` and
                                 `verdict <…>`; --fix-runs compares them (the fixture's answer key)
  Layout B (a live run): --repo=<git work tree> --base=<ref> --ledger=ai/align/ledger.md — base = `git archive
    <ref>`, head = a copy of the working tree, diff = `git diff --no-ext-diff -U0 <ref>`.

THE LADDER (stop at the first FAIL; NOT RUN never stops it and never counts as PASS):
  L0  oracle       every row's oracle resolves in BASE: the quote occurs in the file (whitespace-normalised),
                   or the rule id is declared (rules.tsv from --oracle, else a literal hit in a lint config)  V389
  L1  approval     proof_class VC without `approval:` -> FAIL pending-approval; with it -> PASS-flagged    V407
  L3  diffkind     a changed file whose change is whitespace-only, comment-only or token-identical -> FAIL
      lock-paths   any test / spec / snapshot / fixture / lint-config / baseline-config file, or the row's
                   oracle file, in the diff -> FAIL (V-06; snapshots re-recorded inside the fix void the proof) V408
  L4  scope        line level (V-01): every removed line is an evidence line or verb footprint (import lines for
                   replace-with-shared / dedupe; lines naming old or new for rename); a hunk with no removed line
                   adds only footprint; every evidence line is changed; no file outside `scope`            V392
  L5  redetect     the row's detector on the head copy: 0 hits on the changed evidence lines and no hit whose
                   text is new in a touched file (head hits <= base hits - closed sites)                    V391
  L6  consistency  hunks grouped by normalise(before) -> normalise(after); a before-key with > 1 after FAILS
                   (AL-33) unless the afters split by ROLE — text / background / border / graphic / shadow
                   colour, or padding / margin / gap — one after per role (a context-keyed token map)        V393
  L7  names        every `var(--x)` / `--x` the diff adds is declared (token-map --names on base); every import
                   specifier added resolves (relative file, tsconfig alias, workspace or manifest package)  V398
  L8  roundtrip    each literal -> var(--token) pair: the token's value equals the literal in EVERY theme, in the
                   same property family (token-map.py, ui-ux pack). EQ row that does not round-trip -> FAIL
                   (reclassify AL-06); derived VC with no approval -> FAIL pending-approval; without the ui-ux
                   pack: NOT RUN (blocked: token-map.py absent)                                               V397
  L11 ratchet      baseline files (eslint-suppressions.json, .dependency-cruiser-known-violations.json,
                   eslint.seatbelt.tsv, phpstan/psalm/detekt baselines, package_todo.yml, archunit_store/,
                   .importlinter ignore_imports) only shrink, per (file, rule); no suppression comment added
                   (eslint-disable, stylelint-disable, noqa, nolint, @ts-ignore, @ts-expect-error, biome-ignore);
                   no lint severity loosened (AL-30)                                                          V395
  L12 lock-count   test cases and assertions over the whole tree: head >= base; coverage (run json, or
                   coverage-summary.json in both trees) not down (a drop > 5 pp is flagged hard)           V408
  L13 vacuous      each row's detector_scope matches >= 1 base file and, with `canary`, the planted line in a
                   scratch copy is flagged; otherwise the row's class is NOT RUN, not clean (V-09)           V399
  judge            --judge / run json: FAIL or pending-review on a PASS row -> pending-review; PASS on a FAIL
                   row -> `judge-override-refused` (printed, verdict unchanged)
OUTPUT: TSV `# step\tcheck\trow\tverdict\tdetail`, then `verdict\t<PASS|PASS-flagged|FAIL|NOT RUN|pending-review>`.
Exit:   0 PASS / PASS-flagged · 1 FAIL · 2 usage · 3 self-test failed · 4 NOT RUN (no FAIL) or pending-review.
Stdlib only, Python >= 3.8, `python3 -I` safe.
"""
import difflib, importlib.util, json, os, re, shlex, shutil, subprocess, sys, tarfile, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TOKEN_MAP_DEFAULT = os.path.join(HERE, '..', '..', '..', '..', 'ui-ux', 'skills', 'design-token-audit', 'scripts', 'token-map.py')
COPY_SKIP = {'node_modules', '.git', 'dist', 'build', '.next', 'coverage', '.turbo', '.cache', '.venv', 'venv', '__pycache__'}
TEST_PATH = re.compile(r'(?:^|/)(?:__tests__|__snapshots__|tests?|spec|e2e|fixtures?|__fixtures__|__mocks__|testdata)/|'
                       r'\.(?:test|spec|e2e|stories)\.[\w]+$|\.snap$|(?:^|/)[^/]*\.test-data\.|_test\.(?:go|py)$|(?:^|/)test_[^/]+\.py$|'
                       r'(?:^|/)conftest\.py$')
LINT_CONFIG = re.compile(r'(?:^|/)(?:eslint\.config\.[\w]+|\.eslintrc(?:\.[\w]+)?|stylelint\.config\.[\w]+|\.stylelintrc(?:\.[\w]+)?|'
                         r'\.ls-lint\.ya?ml|\.dependency-cruiser\.[\w]+|\.importlinter|ruff\.toml|\.ruff\.toml|\.golangci\.ya?ml|'
                         r'\.spectral\.ya?ml|biome\.jsonc?|\.oxlintrc\.json|sheriff\.config\.ts|tach\.toml)$')
BASELINE = re.compile(r'(?:^|/)(?:eslint-suppressions\.json|\.dependency-cruiser-known-violations\.json|eslint\.seatbelt\.tsv|'
                      r'phpstan-baseline\.neon|psalm-baseline\.xml|detekt-baseline\.xml|package_todo\.yml|\.betterer\.results|'
                      r'\.redocly\.lint-ignore\.yaml)$|(?:^|/)archunit_store/')
SUPPRESS = re.compile(r'eslint-disable|stylelint-disable|#\s*noqa\b|//\s*nolint\b|@ts-ignore|@ts-expect-error|biome-ignore|'
                      r'oxlint-disable|ast-grep-ignore|@SuppressWarnings|#\s*type:\s*ignore|pylint:\s*disable')
IMPORT_LINE = re.compile(r'^\s*(?:import\b|export\s+(?:\*|\{[^}]*\})\s+from\b|from\s+[\w.]+\s+import\b|(?:const|let|var)\s+[\w{}\s,]+=\s*require\(|'
                         r'@import\b|@use\b|using\s+[\w.]+;|use\s+[\w\\]+;)')
LEGACY = {'design-token-drift': 'AL-05', 'stack-specific': 'AL-05', 'reinvented-wrapper': 'AL-11', 'raw-library-component': 'AL-11',
          'i18n-key-drift': 'AL-26', 'permission-gate-drop': 'AL-15', 'default-true-prop': 'AL-15', 'drift': 'AL-16'}
ORDER = ['oracle', 'approval', 'diffkind', 'lock-paths', 'scope', 'redetect', 'consistency', 'names', 'roundtrip', 'ratchet',
         'lock-count', 'vacuous']
STEP = {'oracle': 'L0', 'approval': 'L1', 'diffkind': 'L3', 'lock-paths': 'L3', 'scope': 'L4', 'redetect': 'L5',
        'consistency': 'L6', 'names': 'L7', 'roundtrip': 'L8', 'ratchet': 'L11', 'lock-count': 'L12', 'vacuous': 'L13'}
ENV = dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0', DO_NOT_TRACK='1', CI='true',
           NEXT_TELEMETRY_DISABLED='1', NX_NO_CLOUD='true', TURBO_TELEMETRY_DISABLED='1', STORYBOOK_DISABLE_TELEMETRY='1')


def read(p):
    try:
        with open(p, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except OSError:
        return None


# ---------------------------------------------------------------- ledger
def scalar(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in '\'"':
        return v[1:-1].replace("''", "'") if v[0] == "'" else v[1:-1]
    return v


def split_inline(body):
    """Split a YAML-ish inline list on the commas at depth 0: a brace glob `src/**/*.{ts,tsx}` is ONE item."""
    items, cur, depth, q = [], '', 0, None
    for c in body:
        if q:
            cur += c
            if c == q:
                q = None
            continue
        if c in '\'"':
            q = c
        elif c in '{[(':
            depth += 1
        elif c in '}])':
            depth -= 1
        elif c == ',' and depth == 0:
            items.append(cur); cur = ''
            continue
        cur += c
    items.append(cur)
    return [x for x in items if x.strip()]


def parse_ledger(text):
    rows, cur, key = [], None, None
    for raw in text.split('\n'):
        line = raw.rstrip()
        m = re.match(r'^- id:\s*(A\d+[a-z]?)\s*$', line)
        if m:
            cur = {'id': m.group(1)}
            rows.append(cur)
            key = None
            continue
        if cur is None:
            continue
        if not line.strip():
            cur, key = None, None
            continue
        m = re.match(r'^\s+-\s+(.*)$', line)
        if m and key:
            cur.setdefault(key, [])
            if not isinstance(cur[key], list):
                cur[key] = [cur[key]]
            cur[key].append(scalar(re.sub(r'\s+#.*$', '', m.group(1))))
            continue
        m = re.match(r'^\s+([\w-]+):\s*(.*)$', line)
        if m:
            key, v = m.group(1), m.group(2)
            v = re.sub(r'\s+#\s.*$', '', v) if not v.lstrip().startswith(('"', "'")) else v
            if v.startswith('[') and v.endswith(']'):
                cur[key] = [scalar(x) for x in split_inline(v[1:-1])]
            elif v in ('', '|', '>'):
                cur[key] = []
            else:
                cur[key] = scalar(v)
    for r in rows:
        for k in ('scope', 'evidence', 'detector_scope'):
            if isinstance(r.get(k), str):
                r[k] = [r[k]]
        cls = r.get('al_class') or r.get('class') or ''
        r['al'] = cls if cls.startswith('AL-') else LEGACY.get(cls, cls)
    return rows


# ---------------------------------------------------------------- unified diff
def parse_diff(text):
    """{path: {'old': path|None, 'new': path|None, 'hunks': [{'os','on','ns','nn','lines':[(tag, text, old_ln, new_ln)]}]}}"""
    files, cur, old_path = {}, None, None
    lines = text.split('\n')
    i = 0
    while i < len(lines):
        l = lines[i]
        if l.startswith('--- '):
            old_path = l[4:].split('\t')[0].strip()
            i += 1
            if i < len(lines) and lines[i].startswith('+++ '):
                new_path = lines[i][4:].split('\t')[0].strip()
                o = None if old_path == '/dev/null' else re.sub(r'^[ab]/', '', old_path)
                n = None if new_path == '/dev/null' else re.sub(r'^[ab]/', '', new_path)
                cur = {'old': o, 'new': n, 'hunks': []}
                files[n or o] = cur
            i += 1
            continue
        m = re.match(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', l)
        if m and cur is not None:
            h = {'os': int(m.group(1)), 'on': int(m.group(2) or 1), 'ns': int(m.group(3)), 'nn': int(m.group(4) or 1), 'lines': []}
            cur['hunks'].append(h)
            o = h['os'] if h['on'] else h['os'] + 1
            n = h['ns'] if h['nn'] else h['ns'] + 1
            i += 1
            while i < len(lines) and not lines[i].startswith(('@@ ', '--- ', 'diff --git')):
                t = lines[i]
                if t.startswith('\\'):
                    i += 1; continue
                tag = t[:1] if t[:1] in '+- ' else ' '
                if tag == '-':
                    h['lines'].append(('-', t[1:], o, None)); o += 1
                elif tag == '+':
                    h['lines'].append(('+', t[1:], None, n)); n += 1
                else:
                    if t == '' and i == len(lines) - 1:
                        break
                    h['lines'].append((' ', t[1:], o, n)); o += 1; n += 1
                i += 1
            continue
        i += 1
    return files


def apply_file(base_lines, fd):
    """Apply one file's hunks to its base lines; raises ValueError on a context mismatch."""
    out, pos = [], 0
    for h in fd['hunks']:
        old = [t for tag, t, _, _ in h['lines'] if tag in ' -']
        new = [t for tag, t, _, _ in h['lines'] if tag in ' +']
        start = h['os'] - 1 if h['on'] else h['os']
        found = None
        for delta in [0] + [d for k in range(1, 51) for d in (k, -k)]:
            s = start + delta
            if s < pos or s < 0 or s + len(old) > len(base_lines):
                continue
            if base_lines[s:s + len(old)] == old:
                found = s
                break
        if found is None:
            raise ValueError('hunk @@ -%d context does not match' % h['os'])
        out += base_lines[pos:found] + new
        pos = found + len(old)
    return out + base_lines[pos:]


def copy_tree(src, dst):
    def ign(d, names):
        return [n for n in names if n in COPY_SKIP]
    shutil.copytree(src, dst, ignore=ign, symlinks=True)


def materialise(base_dir, patch_text, work):
    head = os.path.join(work, 'head')
    copy_tree(base_dir, head)
    files = parse_diff(patch_text)
    for path, fd in files.items():
        if fd['new'] is None:
            p = os.path.join(head, fd['old'])
            if os.path.exists(p):
                os.remove(p)
            continue
        src = read(os.path.join(base_dir, fd['old'])) if fd['old'] else ''
        if src is None:
            raise ValueError('patch names %s, absent from the base' % fd['old'])
        trailing = src.endswith('\n')
        lines = src.split('\n')
        if trailing:
            lines = lines[:-1]
        new = apply_file(lines, fd)
        p = os.path.join(head, fd['new'])
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w', encoding='utf-8') as fh:
            fh.write('\n'.join(new) + ('\n' if trailing or not fd['old'] else ''))
    return head, files


def git_inputs(repo, ref, work):
    base = os.path.join(work, 'base')
    os.makedirs(base)
    arc = subprocess.run(['git', '-C', repo, 'archive', '--format=tar', ref], capture_output=True, env=ENV, timeout=600)
    if arc.returncode != 0:
        raise ValueError('git archive %s failed: %s' % (ref, arc.stderr.decode(errors='replace')[:200]))
    tpath = os.path.join(work, 'base.tar')
    with open(tpath, 'wb') as fh:
        fh.write(arc.stdout)
    with tarfile.open(tpath) as tf:
        for mem in tf.getmembers():
            if mem.name.startswith('/') or '..' in mem.name.split('/') or mem.issym() or mem.islnk():
                continue
            tf.extract(mem, base)
    diff = subprocess.run(['git', '-C', repo, 'diff', '--no-color', '--no-ext-diff', '-U0', ref], capture_output=True, text=True,
                          env=ENV, timeout=600)
    if diff.returncode != 0:
        raise ValueError('git diff failed')
    head = os.path.join(work, 'head')
    copy_tree(repo, head)
    return base, head, diff.stdout, parse_diff(diff.stdout)


# ---------------------------------------------------------------- helpers
def norm_ws(s):
    return re.sub(r'\s+', ' ', s or '').strip()


def strip_comments(text, path):
    if path.endswith('.py'):
        text = re.sub(r'#[^\n]*', '', text)
    else:
        text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
        text = re.sub(r'(?<![:\'"])//[^\n]*', '', text)
    return text


TOK = re.compile(r'[A-Za-z_$][\w$-]*|#[0-9A-Fa-f]{3,8}\b|\d+(?:\.\d+)?(?:px|rem|em|ms|s|%)?|\'[^\']*\'|"[^"]*"|`[^`]*`|\S')


def tokens(text):
    return TOK.findall(text)


def load_token_map(path):
    if not path or not os.path.isfile(path):
        return None
    sys.dont_write_bytecode = True                   # no __pycache__ beside the installed skill
    spec = importlib.util.spec_from_file_location('token_map', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def prop_of(line, frag_pos):
    """The CSS / style property that owns the fragment at frag_pos in line."""
    head = line[:frag_pos]
    m = list(re.finditer(r'([A-Za-z-]+)\s*:\s*(?=[^:;{}]*$)', head))
    if m:
        return m[-1].group(1)
    m = list(re.finditer(r'\b([a-z]+(?:-[a-z]+)*)-\[$', head))
    return m[-1].group(1) if m else ''


def pairs_of(files):
    """(path, before_line, after_line, before_frag, after_frag, old_ln, prop) for each modified line."""
    out = []
    for path, fd in files.items():
        for h in fd['hunks']:
            minus = [x for x in h['lines'] if x[0] == '-']
            plus = [x for x in h['lines'] if x[0] == '+']
            pm = [x for x in plus if not IMPORT_LINE.match(x[1])]
            mm = [x for x in minus if not IMPORT_LINE.match(x[1])]
            for (_, b, ob, _), (_, a, _, na) in zip(mm, pm):
                tbm = list(TOK.finditer(b))
                tb, ta = [m.group(0) for m in tbm], tokens(a)
                sm = difflib.SequenceMatcher(None, tb, ta, autojunk=False)
                for op, i1, i2, j1, j2 in sm.get_opcodes():
                    if op == 'equal':
                        continue
                    bf, af = ''.join(tb[i1:i2]), ''.join(ta[j1:j2])
                    if not bf and not af:
                        continue
                    pos = tbm[i1].start() if i1 < len(tbm) else len(b)
                    out.append(dict(path=path, before=b, after=a, bf=bf, af=af, old_ln=ob, prop=prop_of(b, max(pos, 0))))
    return out


def norm_frag(s):
    s = s.strip().strip('\'"`').strip().lower()
    m = re.fullmatch(r'#([0-9a-f]{3})', s)
    if m:
        s = '#' + ''.join(c * 2 for c in m.group(1))
    return re.sub(r'\s+', ' ', s)


# ---------------------------------------------------------------- checks
class Run(object):
    def __init__(self, base, head, files, rows, meta, oracle_dir=None, token_map=None, work=None):
        self.base, self.head, self.files, self.rows, self.meta = base, head, files, rows, meta or {}
        self.oracle_dir, self.tm, self.work = oracle_dir, token_map, work
        self.out = []          # (step, check, row, verdict, detail)
        self._tm_cache = None

    def emit(self, check, row, verdict, detail):
        self.out.append((STEP.get(check, check), check, row, verdict, detail))

    def changed(self):
        return {p: fd for p, fd in self.files.items()}

    def tm_map(self):
        if self._tm_cache is None and self.tm:
            rows, sources, themes = self.tm.build_map(self.base)
            self._tm_cache = (rows, sources, themes)
        return self._tm_cache


def ck_oracle(run):
    rules_ids = set()
    if run.oracle_dir and os.path.isfile(os.path.join(run.oracle_dir, 'rules.tsv')):
        for l in read(os.path.join(run.oracle_dir, 'rules.tsv')).split('\n')[1:]:
            parts = l.split('\t')
            if len(parts) > 4 and parts[4] != 'off':
                rules_ids.add(parts[2])
    for r in run.rows:
        spec = r.get('oracle') or ''
        if not spec:
            run.emit('oracle', r['id'], 'FAIL', 'no oracle cited (AL-01: an invented convention is dropped)')
            continue
        m = re.match(r'^([^\s:"]+?)(?::(\d+))?\s+["“](.+?)["”]\s*$', spec)
        if m:
            src = read(os.path.join(run.base, m.group(1)))
            if src is None:
                run.emit('oracle', r['id'], 'FAIL', 'oracle file absent in base: %s' % m.group(1))
            elif norm_ws(m.group(3)) not in norm_ws(src):
                run.emit('oracle', r['id'], 'FAIL', 'quote absent from %s (AL-01)' % m.group(1))
            else:
                run.emit('oracle', r['id'], 'PASS', 'quote resolves in %s' % m.group(1))
            continue
        rid = re.sub(r'^[\w-]+:', '', spec, count=1) if re.match(r'^(?:eslint|stylelint|ruff|depcruise|ls-lint|spectral|import-linter|tsc):', spec) else spec
        hit = rid in rules_ids
        if not hit and not rules_ids:
            for d, _, fs in os.walk(run.base):
                if any(x in d for x in ('/node_modules', '/.git')):
                    continue
                for f in fs:
                    rp = os.path.relpath(os.path.join(d, f), run.base).replace(os.sep, '/')
                    if LINT_CONFIG.search(rp) or f in ('pyproject.toml', 'package.json'):
                        if re.search(r'[\'"]%s[\'"]|\b%s\b' % (re.escape(rid), re.escape(rid)), read(os.path.join(d, f)) or ''):
                            hit = True
                            break
                if hit:
                    break
        run.emit('oracle', r['id'], 'PASS' if hit else 'FAIL', ('rule %s declared' % rid) if hit else 'rule %s declared nowhere (AL-01)' % rid)


def approval_of(run, r):
    return r.get('approval') or (run.meta.get('approvals') or {}).get(r['id'])


def ck_approval(run):
    for r in run.rows:
        pc = (r.get('proof_class') or '').upper()
        if pc == 'VC':
            ap = approval_of(run, r)
            run.emit('approval', r['id'], 'PASS-flagged' if ap else 'FAIL',
                     ('visible change approved by %s (V-03b)' % ap) if ap else 'VC row with no approval: stop at pending-approval (V-03b)')
        elif pc in ('EQ', 'FN'):
            run.emit('approval', r['id'], 'PASS', '%s row (proof at L8/L10a)' % pc)
        else:
            run.emit('approval', r['id'], 'PASS', 'proof_class absent: derived at L8')


def ck_diffkind(run):
    for path, fd in run.files.items():
        if fd['old'] is None or fd['new'] is None:
            continue
        b = read(os.path.join(run.base, fd['old'])) or ''
        a = read(os.path.join(run.head, fd['new'])) or ''
        if b == a:
            run.emit('diffkind', path, 'FAIL', 'no change')
        elif norm_ws(b) == norm_ws(a):
            run.emit('diffkind', path, 'FAIL', 'whitespace-only change (the formatter owns formatting, P-19)')
        elif tokens(strip_comments(b, path)) == tokens(strip_comments(a, path)):
            run.emit('diffkind', path, 'FAIL', 'comment-only or token-identical change')
        else:
            run.emit('diffkind', path, 'PASS', 'substantive')


def ck_lock_paths(run):
    oracle_files = set()
    for r in run.rows:
        m = re.match(r'^([^\s:"]+?)(?::\d+)?\s+["“]', r.get('oracle') or '')
        if m:
            oracle_files.add(m.group(1))
    bad = False
    for path in run.files:
        why = 'test/snapshot/fixture file' if TEST_PATH.search(path) else 'lint config' if LINT_CONFIG.search(path) else \
            'oracle file of a row' if path in oracle_files else ''
        if why:
            bad = True
            run.emit('lock-paths', path, 'FAIL', '%s edited inside the fix (V-06)' % why)
    if not bad:
        run.emit('lock-paths', '-', 'PASS', 'no test, snapshot, lint-config or oracle file in the diff')


def footprint(r, text):
    verb = (r.get('closure_verb') or '').strip()
    if IMPORT_LINE.match(text) and verb in ('replace-with-shared', 'dedupe', 'rename', 'remove', ''):
        return True
    if verb == 'rename' and r.get('rename'):
        old, _, new = str(r['rename']).partition('->')
        return any(re.search(r'\b%s\b' % re.escape(x.strip()), text) for x in (old, new) if x.strip())
    return False


IMPORT_SRC = re.compile(r'''(?:\bfrom\s+|^\s*import\s*\(?\s*|\brequire\(\s*|@(?:import|use)\s+)['"]([^'"]+)['"]|^\s*from\s+([\w.]+)\s+import\b''')
IMPORT_SPECS = re.compile(r'''^\s*(?:import|export)\s+(?:type\s+)?(.*?)\s*\bfrom\s*['"]|^\s*from\s+[\w.]+\s+import\s+\(?(.*?)\)?\s*$|'''
                          r'''^\s*(?:const|let|var)\s+(.*?)\s*=\s*require''')


def import_source(line):
    m = IMPORT_SRC.search(line)
    return (m.group(1) or m.group(2)) if m else None


def import_specs(line):
    """The bound names of one import line: `import D, { a, b as c } from 'm'` -> {D, a, b as c}."""
    m = IMPORT_SPECS.match(line)
    body = next((g for g in m.groups() if g is not None), '') if m else ''
    return {re.sub(r'\s+', ' ', x).strip() for x in re.split(r'[{},;]', body) if x.strip()}


def import_delta(added, removed):
    """(n_added, n_removed, churn): an added and a removed import line of the same module are one edited import —
    each specifier it gains counts as one added import, each it loses as one removed; the same specifiers in a
    new order are churn. Other lines count one each."""
    add, rem, churn = list(added), list(removed), set()
    n_add = n_rem = 0
    for a in list(add):
        src = import_source(a)
        mate = next((r for r in rem if src and import_source(r) == src), None)
        if mate is None:
            continue
        add.remove(a); rem.remove(mate)
        sa, sr = import_specs(a), import_specs(mate)
        gain, loss = len(sa - sr), len(sr - sa)
        if not gain and not loss:
            churn.add(a)
        n_add += gain; n_rem += loss
    return n_add + len(add), n_rem + len(rem), churn


def ck_scope(run):
    """V-01 line level. Footprint: at most one import added and one removed per row per file; an import removed
    and re-added unchanged is a reorder (churn, P-19), never footprint. An edited import of the same module counts
    the specifiers it gains or loses, so merging the wrapper into an existing import is one added import."""
    ev = {}
    scope = set()
    for r in run.rows:
        for e in r.get('evidence') or []:
            p, _, ln = e.rpartition(':')
            if ln.isdigit():
                ev.setdefault(p, {})[int(ln)] = r
        scope.update(r.get('scope') or [])
        scope.update(e.rpartition(':')[0] for e in r.get('evidence') or [])
    fail = False
    for path, fd in run.files.items():
        rows_here = [r for r in run.rows if path in (r.get('scope') or []) or any(e.rpartition(':')[0] == path for e in r.get('evidence') or [])]
        if path not in scope:
            fail = True
            run.emit('scope', path, 'FAIL', 'file outside every row\'s scope (AL-34)')
            continue
        hits = ev.get(path, {})
        changed_old = set()
        rem_imp = [re.sub(r'\s+', '', x[1]) for h in fd['hunks'] for x in h['lines'] if x[0] == '-' and IMPORT_LINE.match(x[1])]
        add_imp = [re.sub(r'\s+', '', x[1]) for h in fd['hunks'] for x in h['lines'] if x[0] == '+' and IMPORT_LINE.match(x[1])]
        reordered = set(rem_imp) & set(add_imp)
        # a wrapper specifier merged into an import the file already has (`import { A } from 'w'` ->
        # `import { A, B } from 'w'`) is one import change per specifier, not one removed + one added line
        raw = {re.sub(r'\s+', '', x[1]): x[1] for h in fd['hunks'] for x in h['lines'] if x[0] in '+-'}
        n_add, n_rem, merged = import_delta([raw[k] for k in sorted(set(add_imp) - reordered)],
                                            [raw[k] for k in sorted(set(rem_imp) - reordered)])
        merged = {re.sub(r'\s+', '', x) for x in merged}
        reordered |= merged
        if reordered:
            fail = True
            run.emit('scope', path, 'FAIL', 'import reordered or reformatted, not changed (churn, P-19 / AL-34): %s' % sorted(reordered)[0][:60])
        budget = max(1, len(rows_here))
        if n_add > budget or n_rem > budget:
            fail = True
            run.emit('scope', path, 'FAIL', 'import footprint %d added / %d removed exceeds %d per file (AL-34)' % (
                n_add, n_rem, budget))
        for h in fd['hunks']:
            minus = [x for x in h['lines'] if x[0] == '-']
            plus = [x for x in h['lines'] if x[0] == '+']
            for _, t, ol, _ in minus:
                changed_old.add(ol)
                if ol not in hits and not any(footprint(r, t) for r in rows_here):
                    fail = True
                    run.emit('scope', '%s:%d' % (path, ol), 'FAIL', 'removed line is no detector hit and no verb footprint (AL-34): %s' % t.strip()[:60])
            if not [m for m in minus if m[2] in hits]:
                for _, t, _, nl in plus:
                    if not any(footprint(r, t) for r in rows_here):
                        fail = True
                        run.emit('scope', '%s:+%d' % (path, nl), 'FAIL', 'added line outside a hit hunk and not footprint (AL-34): %s' % t.strip()[:60])
        for ln, r in sorted(hits.items()):
            if ln not in changed_old:
                fail = True
                run.emit('scope', '%s:%d' % (path, ln), 'FAIL', '%s evidence line left unchanged (gaps_in != gaps_closed)' % r['id'])
    for p, hits in ev.items():
        if p not in run.files:
            fail = True
            run.emit('scope', p, 'FAIL', 'evidence file not touched by the diff (%d hit lines open)' % len(hits))
    if not fail:
        run.emit('scope', '-', 'PASS', 'every removed line is a hit or footprint; every hit changed')


def detect(run, r, tree, files):
    """Return {path: [(line, text)]} or None when the row records no detector."""
    out = {}
    if r.get('detector_re'):
        try:
            rx = re.compile(r['detector_re'])
        except re.error as e:
            raise ValueError('detector_re does not compile: %s' % e)
        for f in files:
            src = read(os.path.join(tree, f))
            if src is None:
                continue
            for i, line in enumerate(src.split('\n'), 1):
                if rx.search(line):
                    out.setdefault(f, []).append((i, line))
        return out
    if r.get('detector_cmd'):
        argv = []
        for a in shlex.split(r['detector_cmd']):
            argv += list(files) if a == '{files}' else [a]
        try:
            p = subprocess.run(argv, cwd=tree, capture_output=True, text=True, env=dict(ENV, HOME=run.work or tree), timeout=300)
        except (OSError, subprocess.TimeoutExpired) as e:
            raise ValueError('detector_cmd did not run: %s' % e)
        if p.returncode not in (0, 1):
            raise ValueError('detector_cmd exit %d: %s' % (p.returncode, p.stderr[:120]))
        for line in p.stdout.split('\n'):
            m = re.match(r'^(?:\./)?([^:\n]+):(\d+):?(.*)$', line)
            if m:
                out.setdefault(m.group(1), []).append((int(m.group(2)), m.group(3)))
        return out
    return None


def ck_redetect(run):
    touched = sorted(p for p, fd in run.files.items() if fd['new'])
    for r in run.rows:
        evf = sorted({e.rpartition(':')[0] for e in r.get('evidence') or []})
        files = sorted(set(touched) | set(evf))
        try:
            b = detect(run, r, run.base, files)
            h = detect(run, r, run.head, [f for f in files if os.path.exists(os.path.join(run.head, f))])
        except ValueError as e:
            run.emit('redetect', r['id'], 'NOT RUN', str(e))
            continue
        if b is None:
            run.emit('redetect', r['id'], 'NOT RUN', 'no detector_re / detector_cmd recorded in the ledger row')
            continue
        closed = {}
        for e in r.get('evidence') or []:
            p, _, _ = e.rpartition(':')
            closed[p] = closed.get(p, 0) + 1
        bad = []
        for f in files:
            bh, hh = b.get(f, []), h.get(f, [])
            btexts = [norm_ws(t) for _, t in bh]
            new = [(ln, t) for ln, t in hh if norm_ws(t) not in btexts]
            if new:
                bad.append('%s:%d new site in a touched file' % (f, new[0][0]))
            elif len(hh) > len(bh) - closed.get(f, 0):
                bad.append('%s: %d hits remain, %d expected after closing %d' % (f, len(hh), max(len(bh) - closed.get(f, 0), 0), closed.get(f, 0)))
        if bad:
            run.emit('redetect', r['id'], 'FAIL', '; '.join(bad[:3]) + ' (V-00)')
        else:
            run.emit('redetect', r['id'], 'PASS', '0 at ledger sites, 0 new in %d touched files' % len(files))


def family(run, prop, frag=''):
    if run.tm:
        f = run.tm.family_of_prop(prop) if prop else 'other'
        if f == 'other' and frag:
            nv = run.tm.norm_value(frag)
            k = run.tm.value_kind(nv)
            return {'color': 'color', 'length': 'space'}.get(k, f)
        return f
    p = prop.lower()
    return 'color' if 'color' in p or p in ('background', 'fill', 'stroke', 'border') else \
        'space' if re.match(r'(?:margin|padding|gap)', p) else p or 'other'


def role(prop):
    """The context a value plays: text / background / border / graphic / shadow colour, or the spacing property.
    A token map keyed by context (--color-text-danger vs --color-border-danger) may map one literal two ways,
    one per role; within one role a literal has exactly one after."""
    p = re.sub(r'([a-z])([A-Z])', r'\1-\2', prop or '').lower()
    if re.match(r'(?:bg|background)', p):
        return 'background'
    if re.match(r'(?:border|outline|ring|divide)', p):
        return 'border'
    if p in ('fill', 'stroke', 'stop-color', 'flood-color'):
        return 'graphic'
    if 'shadow' in p:
        return 'shadow'
    if p in ('color', 'text', 'caret-color', 'text-decoration-color', 'decoration', 'placeholder', '-webkit-text-fill-color'):
        return 'text'
    m = re.match(r'(padding|margin|gap|inset|top|right|bottom|left|p|m)\b', p)
    return m.group(1) if m else (p or 'other')


def ck_consistency(run):
    groups = {}
    for pr in pairs_of(run.files):
        if not pr['bf'] or not pr['af']:
            continue
        key = norm_frag(pr['bf'])
        groups.setdefault(key, []).append(pr)
    fail = False
    for key, prs in sorted(groups.items()):
        afters = {}
        for pr in prs:
            afters.setdefault(norm_frag(pr['af']), []).append(pr)
        if len(afters) <= 1:
            continue
        fams = {a: {role(p['prop']) for p in ps} for a, ps in afters.items()}
        allf = [f for s in fams.values() for f in s]
        if len(allf) == len(set(allf)):
            run.emit('consistency', key, 'PASS', 'context-keyed by role: %s' % '; '.join('%s for %s' % (a, '/'.join(sorted(f))) for a, f in fams.items()))
            continue
        fail = True
        run.emit('consistency', key, 'FAIL', '%s resolved %d ways (AL-33): %s' % (
            key, len(afters), '; '.join('%s in %s' % (a, ','.join(sorted({p['path'] for p in ps}))) for a, ps in afters.items())))
    if not fail:
        run.emit('consistency', '-', 'PASS', '%d before-keys, one way each' % len(groups))


def declared_imports(tree):
    pk, aliases = set(), []
    for d, dirs, fs in os.walk(tree):
        dirs[:] = [x for x in dirs if x not in COPY_SKIP]
        for f in fs:
            p = os.path.join(d, f)
            if f == 'package.json':
                try:
                    j = json.loads(read(p) or '{}')
                except ValueError:
                    continue
                if j.get('name'):
                    pk.add(j['name'])
                for sec in ('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'):
                    pk.update((j.get(sec) or {}).keys())
            elif re.match(r'tsconfig(?:\.[\w-]+)?\.json$', f) or f == 'jsconfig.json':
                src = read(p) or ''
                bu = re.search(r'"baseUrl"\s*:\s*"([^"]*)"', src)          # paths resolve from baseUrl when set
                anchor = os.path.join(os.path.relpath(d, tree), bu.group(1) if bu else '.')
                for m in re.finditer(r'"([^"]*)\*"\s*:\s*\[\s*"([^"]*)\*"', src):
                    tgt = os.path.normpath(os.path.join(anchor, m.group(2) or '.')).replace(os.sep, '/')
                    # normpath drops the trailing slash of `./src/*`: put it back, or `@/hooks/x` -> `srchooks/x`
                    if m.group(2).endswith('/') or not m.group(2):
                        tgt = '' if tgt == '.' else tgt + '/'
                    aliases.append((m.group(1), tgt))
    return pk, aliases


EXTS = ['', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.mts', '.vue', '.svelte', '.css', '.scss', '.json', '/index.ts', '/index.tsx',
        '/index.js', '/index.mjs']
NODE_BUILTIN = {'fs', 'path', 'os', 'url', 'util', 'crypto', 'http', 'https', 'stream', 'events', 'child_process', 'buffer', 'zlib',
                'assert', 'net', 'tls', 'querystring', 'readline', 'worker_threads', 'module', 'process', 'timers', 'dns'}


def ck_names(run):
    names = None
    if run.tm:
        rows, _, _ = run.tm_map()
        names = {t.name for t in rows}
    pk, aliases = declared_imports(run.base)          # BASE manifests: a package the diff itself adds does not count
    bad, seen = [], 0
    for path, fd in run.files.items():
        for h in fd['hunks']:
            for tag, t, _, nl in h['lines']:
                if tag != '+':
                    continue
                for m in re.finditer(r'var\(\s*(--[\w-]+)', t):
                    seen += 1
                    if names is None:
                        continue
                    if m.group(1) not in names:
                        bad.append('%s:%d %s is not a declared token' % (path, nl, m.group(1)))
                for m in re.finditer(r'''(?:\bfrom\s+|\bimport\s*\(?\s*|\brequire\(\s*)['"]([^'"]+)['"]''', t):
                    spec = m.group(1)
                    seen += 1
                    if spec.startswith('.'):
                        tgt = os.path.normpath(os.path.join(os.path.dirname(path), spec)).replace(os.sep, '/')
                        if not any(os.path.exists(os.path.join(run.head, tgt + e)) for e in EXTS):
                            bad.append('%s:%d import %s resolves to no file' % (path, nl, spec))
                        continue
                    cands = [tgt + spec[len(pre):] for pre, tgt in aliases if pre and spec.startswith(pre)]
                    if cands:                       # one alias may be declared by several tsconfigs: any target counts
                        if not any(os.path.exists(os.path.join(run.head, rest + e)) for rest in cands for e in EXTS):
                            bad.append('%s:%d alias import %s resolves to no file' % (path, nl, spec))
                        continue
                    pkg = '/'.join(spec.split('/')[:2]) if spec.startswith('@') else spec.split('/')[0]
                    if pkg.replace('node:', '') in NODE_BUILTIN or pkg in pk:
                        continue
                    bad.append('%s:%d import %s: package declared nowhere' % (path, nl, spec))
    if bad:
        run.emit('names', '-', 'FAIL', '; '.join(bad[:4]) + ' (V-08: a hallucinated name)')
    elif names is None and seen:
        run.emit('names', '-', 'NOT RUN', 'imports checked; token names blocked (token-map.py absent: ui-ux pack not installed)')
    else:
        run.emit('names', '-', 'PASS', '%d emitted names declared' % seen)


def ck_roundtrip(run):
    tm = run.tm
    for r in run.rows:
        evl = {(e.rpartition(':')[0], int(e.rpartition(':')[2])) for e in r.get('evidence') or [] if e.rpartition(':')[2].isdigit()}
        prs = [p for p in pairs_of(run.files) if (p['path'], p['old_ln']) in evl and re.search(r'var\(\s*--', p['af'])]
        pc = (r.get('proof_class') or '').upper()
        if not prs:
            run.emit('roundtrip', r['id'], 'PASS', 'no literal -> token pair in this row')
            continue
        if tm is None:
            run.emit('roundtrip', r['id'], 'NOT RUN', 'blocked: token-map.py absent (ui-ux pack not installed)')
            continue
        rows, _, themes = run.tm_map()
        pkgs = tm.package_dirs(run.base) if hasattr(tm, 'rows_for') else None
        fails = []
        for p in prs:
            tok = re.search(r'var\(\s*(--[\w-]+)', p['af']).group(1)
            fam = family(run, p['prop'], p['bf'])
            lit = tm.norm_value(p['bf'].strip('\'"`'), fam)
            scoped = rows
            if pkgs is not None:                     # a name two packages declare: the site's own package decides
                prow, _ = tm.rows_for(rows, tm.pkg_of(p['path'], pkgs))
                scoped = prow if any(t.name == tok for t in prow) else rows
            ent = [t for t in scoped if t.name == tok]
            if not ent:
                fails.append('%s undeclared' % tok)
                continue
            for th in themes:
                v = tm.value_in(scoped, tok, th)
                if v != lit:
                    fails.append('%s=%s in %s, literal %s' % (tok, v, th, lit))
                    break
            else:
                tf = ent[0].family
                if fam not in ('other', tf):
                    fails.append('%s is %s, the property is %s (cross-family, P-27)' % (tok, tf, fam))
        if not fails:
            run.emit('roundtrip', r['id'], 'PASS', '%d pairs round-trip in %s' % (len(prs), '+'.join(themes)))
        elif pc == 'VC' and approval_of(run, r):
            run.emit('roundtrip', r['id'], 'PASS-flagged', 'visible change, approved: %s' % '; '.join(fails[:2]))
        elif pc == 'EQ':
            run.emit('roundtrip', r['id'], 'FAIL', 'declared EQ but %s — reclassify AL-06 (V-07)' % '; '.join(fails[:2]))
        else:
            run.emit('roundtrip', r['id'], 'FAIL', 'derived VC (%s) with no approval: pending-approval (V-03b)' % '; '.join(fails[:2]))


def count_json_baseline(text):
    try:
        d = json.loads(text or '{}')
    except ValueError:
        return {}
    out = {}
    if isinstance(d, dict):
        for f, rules in d.items():
            if isinstance(rules, dict):
                for rule, v in rules.items():
                    out[(f, rule)] = v.get('count', 1) if isinstance(v, dict) else (v if isinstance(v, int) else 1)
    elif isinstance(d, list):
        for i, v in enumerate(d):
            out[('item', json.dumps(v, sort_keys=True))] = 1
    return out


def ck_ratchet(run):
    bad = []
    for path, fd in run.files.items():
        if BASELINE.search(path):
            b = read(os.path.join(run.base, fd['old'])) if fd['old'] else ''
            a = read(os.path.join(run.head, fd['new'])) if fd['new'] else ''
            if path.endswith('.json'):
                cb, ca = count_json_baseline(b), count_json_baseline(a)
                grew = [k for k, v in ca.items() if v > cb.get(k, 0)]
                if grew:
                    bad.append('%s grew at %s' % (path, ', '.join('%s %s' % k for k in grew[:3])))
            else:
                plus = sum(1 for h in fd['hunks'] for x in h['lines'] if x[0] == '+')
                minus = sum(1 for h in fd['hunks'] for x in h['lines'] if x[0] == '-')
                if plus > minus:
                    bad.append('%s grew (+%d -%d)' % (path, plus, minus))
        for h in fd['hunks']:
            for tag, t, _, nl in h['lines']:
                if tag == '+' and SUPPRESS.search(t):
                    bad.append('%s:%d adds a suppression: %s' % (path, nl, t.strip()[:50]))
                if tag == '-' and LINT_CONFIG.search(path) and re.search(r'["\']?error["\']?|\b2\b', t):
                    bad.append('%s: a severity removed (rule loosened?)' % path)
    if bad:
        run.emit('ratchet', '-', 'FAIL', '; '.join(bad[:4]) + ' (AL-30)')
    else:
        run.emit('ratchet', '-', 'PASS', 'no baseline grew, no suppression added, no rule loosened')


TESTCASE = re.compile(r'(?:^|[^\w.])(?:it|test)(?:\.(?:each|only|concurrent)[^(]*)?\s*\(|^\s*def test_\w+|@Test\b|^\s*func Test\w+\(', re.M)
ASSERT = re.compile(r'\bexpect\s*\(|\bassert\w*\b|\bshould\.\w+|\bt\.(?:Error|Fatal)f?\(')


def count_tests(tree):
    tc = asr = 0
    for d, dirs, fs in os.walk(tree):
        dirs[:] = [x for x in dirs if x not in COPY_SKIP]
        for f in fs:
            rp = os.path.relpath(os.path.join(d, f), tree).replace(os.sep, '/')
            if TEST_PATH.search(rp) and re.search(r'\.(?:[jt]sx?|mjs|cjs|py|go|java|kt|rb|php|cs)$', f):
                src = read(os.path.join(d, f)) or ''
                tc += len(TESTCASE.findall(src))
                asr += len(ASSERT.findall(src))
    return tc, asr


def coverage_pct(tree):
    for cand in ('coverage/coverage-summary.json', 'coverage-summary.json'):
        p = os.path.join(tree, cand)
        if os.path.isfile(p):
            try:
                return float(json.loads(read(p))['total']['lines']['pct'])
            except (ValueError, KeyError, TypeError):
                return None
    return None


def ck_lock_count(run):
    bt, ba = count_tests(run.base)
    ht, ha = count_tests(run.head)
    cov = run.meta.get('coverage') or {}
    cb = cov.get('base', coverage_pct(run.base))
    ch = cov.get('head', coverage_pct(run.head))
    bad = []
    if ht < bt:
        bad.append('test cases %d -> %d' % (bt, ht))
    if ha < ba:
        bad.append('assertions %d -> %d' % (ba, ha))
    if cb is not None and ch is not None and ch < cb:
        bad.append('coverage %.1f -> %.1f%s' % (cb, ch, ' (> 5 pp: hard)' if cb - ch > 5 else ''))
    if bad:
        run.emit('lock-count', '-', 'FAIL', '; '.join(bad) + ' (V-06)')
    else:
        run.emit('lock-count', '-', 'PASS', 'tests %d->%d, assertions %d->%d%s' % (bt, ht, ba, ha,
                 ', coverage %.1f->%.1f' % (cb, ch) if cb is not None and ch is not None else ', coverage not measured'))


def glob_re(g):
    out, i = '', 0
    while i < len(g):
        if g.startswith('**/', i):
            out += '(?:.*/)?'; i += 3; continue
        if g.startswith('**', i):
            out += '.*'; i += 2; continue
        c = g[i]
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
    return re.compile('^' + out + '(?:/.*)?$')


def tree_files(tree):
    out = []
    for d, dirs, fs in os.walk(tree):
        dirs[:] = [x for x in dirs if x not in COPY_SKIP]
        for f in fs:
            out.append(os.path.relpath(os.path.join(d, f), tree).replace(os.sep, '/'))
    return out


def ck_vacuous(run):
    allf = tree_files(run.base)
    for r in run.rows:
        globs = r.get('detector_scope') or sorted({e.rpartition(':')[0] for e in r.get('evidence') or []})
        n = (run.meta.get('matched') or {}).get(r['id'])
        if n is None:
            rxs = [glob_re(g) for g in globs]
            n = sum(1 for f in allf if any(rx.match(f) for rx in rxs))
        if n == 0:
            run.emit('vacuous', r['id'], 'NOT RUN', 'rule scope %s matched 0 files — vacuous, not clean (V-09)' % ','.join(globs))
            continue
        if r.get('canary') and r.get('detector_re'):
            target = next((f for f in allf if any(glob_re(g).match(f) for g in globs)), None)
            scratch = tempfile.mkdtemp(prefix='canary-', dir=run.work)
            dst = os.path.join(scratch, target)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, 'w') as fh:
                fh.write((read(os.path.join(run.base, target)) or '') + '\n' + r['canary'] + '\n')
            hit = detect(run, r, scratch, [target])
            shutil.rmtree(scratch, ignore_errors=True)
            if not hit or not any(r['canary'].strip() in t or t.strip() == r['canary'].strip() for t in [x[1] for x in hit.get(target, [])]):
                run.emit('vacuous', r['id'], 'NOT RUN', 'canary planted in a scratch copy of %s stayed green (V-09)' % target)
                continue
            run.emit('vacuous', r['id'], 'PASS', 'matched %d files; canary flagged' % n)
        else:
            run.emit('vacuous', r['id'], 'PASS', 'matched %d files' % n)


CHECKS = {'oracle': ck_oracle, 'approval': ck_approval, 'diffkind': ck_diffkind, 'lock-paths': ck_lock_paths, 'scope': ck_scope,
          'redetect': ck_redetect, 'consistency': ck_consistency, 'names': ck_names, 'roundtrip': ck_roundtrip,
          'ratchet': ck_ratchet, 'lock-count': ck_lock_count, 'vacuous': ck_vacuous}


def ladder(run, only=None, run_all=False, judge=None):
    stopped = None
    for name in ORDER:
        if only and name not in only:
            continue
        if stopped and not run_all:
            run.emit(name, '-', 'SKIPPED', 'after FAIL at %s' % stopped)
            continue
        n0 = len(run.out)
        CHECKS[name](run)
        if any(v == 'FAIL' for _, _, _, v, _ in run.out[n0:]) and not stopped:
            stopped = STEP[name]
    verdicts = [v for _, _, _, v, _ in run.out]
    final = 'FAIL' if 'FAIL' in verdicts else 'NOT RUN' if 'NOT RUN' in verdicts else \
        'PASS-flagged' if 'PASS-flagged' in verdicts else 'PASS'
    for j in judge or []:
        jv = str(j.get('verdict', '')).upper().replace('_', '-')
        if final == 'FAIL' and jv == 'PASS':
            run.out.append(('judge', 'judge', j.get('id', '-'), 'judge-override-refused',
                            'a judge cannot turn a deterministic FAIL into PASS: %s' % j.get('reason', '')[:60]))
        elif final in ('PASS', 'PASS-flagged') and jv in ('FAIL', 'PENDING-REVIEW'):
            run.out.append(('judge', 'judge', j.get('id', '-'), 'pending-review', j.get('reason', '')[:80]))
            final = 'pending-review'
        else:
            run.out.append(('judge', 'judge', j.get('id', '-'), 'advisory', j.get('reason', '')[:80]))
    return final


def check_verdict(run, check):
    vs = [v for _, c, _, v, _ in run.out if c == check]
    if not vs:
        return 'absent'
    for v in ('FAIL', 'NOT RUN', 'SKIPPED', 'PASS-flagged'):
        if v in vs:
            return v
    return 'PASS'


def render(run, final, as_json=False):
    if as_json:
        return json.dumps({'steps': [dict(step=s, check=c, row=r, verdict=v, detail=d) for s, c, r, v, d in run.out],
                           'verdict': final}, indent=1)
    lines = ['# step\tcheck\trow\tverdict\tdetail'] + ['\t'.join(str(x) for x in o) for o in run.out]
    lines.append('verdict\t%s' % final)
    return '\n'.join(lines)


EXIT = {'PASS': 0, 'PASS-flagged': 0, 'FAIL': 1, 'NOT RUN': 4, 'pending-review': 4}


def load_judge(path, meta):
    j = list(meta.get('judge') or [])
    if path:
        txt = read(path) or ''
        try:
            d = json.loads(txt)
            j += d if isinstance(d, list) else d.get('judge', [])
        except ValueError:
            for l in txt.split('\n'):
                p = l.split('\t')
                if len(p) >= 2 and not l.startswith('#'):
                    j.append({'id': p[0], 'verdict': p[1], 'reason': p[2] if len(p) > 2 else ''})
    return j


def one_run(base_dir, patch_text, ledger_text, meta, opts, only=None, keep=False):
    work = tempfile.mkdtemp(prefix='align-sweep-', dir=os.environ.get('TMPDIR') or None)
    try:
        head, files = materialise(base_dir, patch_text, work)
        tm = load_token_map(opts.get('tokens') or TOKEN_MAP_DEFAULT)
        run = Run(base_dir, head, files, parse_ledger(ledger_text), meta, opts.get('oracle'), tm, work)
        final = ladder(run, only, bool(opts.get('all')), load_judge(opts.get('judge'), meta))
        return run, final
    finally:
        if not keep:
            shutil.rmtree(work, ignore_errors=True)


def fix_runs(dirpath, base_dir, opts):
    """Run every <name>.patch in a fix-runs dir; compare <name>.expect. Returns (ok, report lines)."""
    names = sorted(f[:-6] for f in os.listdir(dirpath) if f.endswith('.patch'))
    ok, out = True, []
    for n in names:
        patch = read(os.path.join(dirpath, n + '.patch')) or ''
        ledger = read(os.path.join(dirpath, n + '.ledger.md')) or ''
        meta = json.loads(read(os.path.join(dirpath, n + '.json')) or '{}')
        run, final = one_run(base_dir, patch, ledger, meta, dict(opts, all=True))
        exp = read(os.path.join(dirpath, n + '.expect'))
        miss = []
        if exp:
            for l in exp.split('\n'):
                p = l.split(None, 1)
                if len(p) != 2 or l.startswith('#'):
                    continue
                got = final if p[0] == 'verdict' else check_verdict(run, p[0])
                if got != p[1].strip():
                    miss.append('%s expected %s got %s' % (p[0], p[1].strip(), got))
        ok = ok and not miss
        out.append('%s\t%s\t%s' % (n, final, 'expect OK' if exp and not miss else ('; '.join(miss) if miss else 'no .expect')))
        if miss:
            out.append(render(run, final))
    return ok, out


# ---------------------------------------------------------------- CLI
def main(argv):
    if argv and argv[0] == '--self-test':
        fr = next((a.split('=', 1)[1] for a in argv[1:] if a.startswith('--fix-runs=')), None)
        return self_test(fr)
    opts, pos = {}, []
    for a in argv:
        if a.startswith('--') and '=' in a:
            k, v = a[2:].split('=', 1); opts[k] = v
        elif a.startswith('--'):
            opts[a[2:]] = True
        else:
            pos.append(a)
    if opts.get('fix-runs'):
        d = opts['fix-runs']
        base = opts.get('base-dir') or os.path.dirname(os.path.abspath(d.rstrip('/')))
        ok, out = fix_runs(d, base, opts)
        print('\n'.join(out))
        return 0 if ok else 1
    if not pos or (pos[0] != 'ladder' and pos[0] not in CHECKS):
        sys.stderr.write(__doc__.split('\n\n')[2] + '\n'); return 2
    only = None if pos[0] == 'ladder' else [pos[0]]
    meta = json.loads(read(opts['run-json']) or '{}') if opts.get('run-json') else {}
    ledger = read(opts.get('ledger', '')) if opts.get('ledger') else None
    if ledger is None:
        sys.stderr.write('align-sweep-gate: --ledger=<md> required\n'); return 2
    if opts.get('repo'):
        if not opts.get('base'):
            sys.stderr.write('align-sweep-gate: --repo needs --base=<ref>\n'); return 2
        work = tempfile.mkdtemp(prefix='align-sweep-', dir=os.environ.get('TMPDIR') or None)
        try:
            base, head, patch, files = git_inputs(opts['repo'], opts['base'], work)
            run = Run(base, head, files, parse_ledger(ledger), meta, opts.get('oracle'),
                      load_token_map(opts.get('tokens') or TOKEN_MAP_DEFAULT), work)
            final = ladder(run, only, bool(opts.get('all')), load_judge(opts.get('judge'), meta))
        except ValueError as e:
            sys.stderr.write('align-sweep-gate: %s\n' % e); return 2
        finally:
            if not opts.get('keep'):
                shutil.rmtree(work, ignore_errors=True)
    else:
        if not opts.get('base-dir') or not opts.get('patch'):
            sys.stderr.write('align-sweep-gate: --base-dir and --patch (or --repo and --base) required\n'); return 2
        try:
            run, final = one_run(opts['base-dir'], read(opts['patch']) or '', ledger, meta, opts, only, bool(opts.get('keep')))
        except ValueError as e:
            sys.stderr.write('align-sweep-gate: %s\n' % e); return 2
    print(render(run, final, bool(opts.get('json'))))
    return EXIT.get(final, 1)


# ---------------------------------------------------------------- self-test: a synthetic fix-runs fixture (eval § 4.12)
BASE_TREE = {
    'package.json': json.dumps({'name': 'acme', 'dependencies': {'react': '19.0.0'}, 'devDependencies': {'vitest': '3.0.0'}}),
    'tsconfig.json': '{ "compilerOptions": { "paths": { "@/*": ["./src/*"] } } }\n',
    'src/styles/tokens.css': ':root {\n  --color-danger: #d92d20;\n  --color-error: #d92d20;\n  --color-text: #101828;\n'
                             '  --space-2: 8px;\n  --gap-sm: 8px;\n  --space-3: 12px;\n  --font-size-sm: 13px;\n}\n',
    'src/ui/Button.tsx': 'export function Button() { return null }\n',
    'src/a.tsx': "import { useState } from 'react';\nimport { x } from './x';\n\nexport function A() {\n  return <span style={{ color: '#d92d20' }} />;\n}\n\n"
                 "export function untouched() {\n  return 1 + 1;\n}\n",
    'src/b.tsx': "export function B() {\n  return <span style={{ color: '#d92d20', padding: '8px' }} />;\n}\n",
    'src/c.tsx': "export function C() {\n  return <i style={{ color: '#d92d20', borderColor: '#d92d20', padding: '8px', margin: '13px' }} />;\n}\n",
    'src/x.ts': 'export const x = 1;\n',
    'src/ui/dialog.tsx': 'export const Dialog = null;\nexport const DialogContent = null;\n',
    'src/d.tsx': "import { Root as DialogRoot } from '@radix-ui/react-dialog';\nimport { DialogContent } from './ui/dialog';\n\n"
                 "export function D() {\n  return <DialogRoot><DialogContent /></DialogRoot>;\n}\n",
    'src/a.test.tsx': "import { A } from './a';\n\ntest('a', () => {\n  expect(A()).toMatchSnapshot();\n  expect(1).toBe(1);\n});\n",
    'src/__snapshots__/a.test.tsx.snap': 'exports[`a 1`] = `<span style="color: #d92d20" />`;\n',
    'eslint-suppressions.json': json.dumps({'src/a.tsx': {'no-restricted-imports': {'count': 1}}}, indent=1) + '\n',
    'ai/conventions.md': '# Conventions\n\n- Colours come from `src/styles/tokens.css`; never hardcode a hex colour.\n',
}

LEDGER = """- id: {id}
  al_class: AL-05
  closure_verb: replace-with-shared
{extra}  scope: [{scope}]
  evidence:
{evidence}
  oracle: 'ai/conventions.md "never hardcode a hex colour"'
  detector_re: "{rx}"
  detector_scope: [src/**/*.tsx]
"""


def ledger_row(rid, evidence, rx, extra='', scope=None):
    ev = ''.join('    - %s\n' % e for e in evidence)
    sc = ', '.join(sorted(scope or {e.rpartition(':')[0] for e in evidence}))
    return LEDGER.format(id=rid, extra=extra, scope=sc, evidence=ev.rstrip('\n'), rx=rx) + '\n'


def udiff(path, old, new, n=0):
    return ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True), 'a/' + path, 'b/' + path, n=n))


def self_test(external=None):
    bad, tot = [], [0]

    def check(name, cond, extra=''):
        tot[0] += 1
        if not cond:
            bad.append(name + (' — ' + extra if extra else ''))
    base = tempfile.mkdtemp(prefix='align-sweep-selftest-', dir=os.environ.get('TMPDIR') or None)
    try:
        if external:
            dst = os.path.join(base, 'fixture')
            copy_tree(os.path.dirname(os.path.abspath(external.rstrip('/'))), dst)
            ok, out = fix_runs(os.path.join(dst, os.path.basename(external.rstrip('/'))), dst, {})
            print('\n'.join(out))
            check('external fix-runs match their .expect', ok)
        root = os.path.join(base, 'fixture')
        if not external:
            for f, c in BASE_TREE.items():
                p = os.path.join(root, f)
                os.makedirs(os.path.dirname(p), exist_ok=True)
                with open(p, 'w') as fh:
                    fh.write(c)
        else:
            root = os.path.join(base, 'synthetic')
            for f, c in BASE_TREE.items():
                p = os.path.join(root, f)
                os.makedirs(os.path.dirname(p), exist_ok=True)
                with open(p, 'w') as fh:
                    fh.write(c)
        B = BASE_TREE
        sub = lambda path, a, b, count=1: B[path].replace(a, b, count)
        RX = "#d92d20"
        runs = {}
        # run-01: one literal, two tokens across files -> AL-33
        p = udiff('src/a.tsx', B['src/a.tsx'], sub('src/a.tsx', "'#d92d20'", "'var(--color-danger)'")) + \
            udiff('src/b.tsx', B['src/b.tsx'], sub('src/b.tsx', "'#d92d20'", "'var(--color-error)'"))
        runs['run-01'] = (p, ledger_row('A101', ['src/a.tsx:5', 'src/b.tsx:2'], RX, "  proof_class: EQ\n"), {},
                          'consistency FAIL\nscope PASS\nverdict FAIL')
        # run-02: 8px -> --space-2 and --gap-sm (same value, same family) -> AL-33
        p = udiff('src/b.tsx', B['src/b.tsx'], sub('src/b.tsx', "'8px'", "'var(--space-2)'")) + \
            udiff('src/c.tsx', B['src/c.tsx'], sub('src/c.tsx', "'8px'", "'var(--gap-sm)'"))
        runs['run-02'] = (p, ledger_row('A102', ['src/b.tsx:2', 'src/c.tsx:2'], "padding: '8px'", "  proof_class: EQ\n"), {},
                          'consistency FAIL\nverdict FAIL')
        # run-03: churn in an untouched function + reordered imports
        new = sub('src/a.tsx', "'#d92d20'", "'var(--color-danger)'").replace('return 1 + 1;', 'return 2;')
        new = new.replace("import { useState } from 'react';\nimport { x } from './x';\n", "import { x } from './x';\nimport { useState } from 'react';\n")
        runs['run-03'] = (udiff('src/a.tsx', B['src/a.tsx'], new), ledger_row('A103', ['src/a.tsx:5'], RX, "  proof_class: EQ\n"), {},
                          'scope FAIL\nverdict FAIL')
        # run-04: a snapshot update and a weakened assertion in the same run
        p = udiff('src/a.tsx', B['src/a.tsx'], sub('src/a.tsx', "'#d92d20'", "'var(--color-danger)'")) + \
            udiff('src/__snapshots__/a.test.tsx.snap', B['src/__snapshots__/a.test.tsx.snap'], 'exports[`a 1`] = `<span style="color: var(--color-danger)" />`;\n') + \
            udiff('src/a.test.tsx', B['src/a.test.tsx'], B['src/a.test.tsx'].replace('  expect(1).toBe(1);\n', ''))
        runs['run-04'] = (p, ledger_row('A104', ['src/a.tsx:5'], RX, "  proof_class: EQ\n"), {},
                          'lock-paths FAIL\nlock-count FAIL\nverdict FAIL')
        # run-05: EQ swaps on hit lines + import footprint -> PASS
        new = "import { Button } from './ui/Button';\n" + sub('src/a.tsx', "'#d92d20'", "'var(--color-danger)'")
        runs['run-05'] = (udiff('src/a.tsx', B['src/a.tsx'], new), ledger_row('A105', ['src/a.tsx:5'], RX, "  proof_class: EQ\n"), {},
                          'oracle PASS\nscope PASS\nredetect PASS\nconsistency PASS\nnames PASS\nroundtrip PASS\nratchet PASS\n'
                          'lock-count PASS\nvacuous PASS\nverdict PASS')
        # run-06: 13px -> --space-3 snap: VC, no approval -> FAIL; run-06b with approval -> PASS-flagged
        p = udiff('src/c.tsx', B['src/c.tsx'], sub('src/c.tsx', "'13px'", "'var(--space-3)'"))
        runs['run-06'] = (p, ledger_row('A106', ['src/c.tsx:2'], "margin: '13px'"), {}, 'roundtrip FAIL\nverdict FAIL')
        runs['run-06b'] = (p, ledger_row('A106', ['src/c.tsx:2'], "margin: '13px'", "  proof_class: VC\n  approval: ana@2026-10-18T09:00Z\n"), {},
                           'approval PASS-flagged\nroundtrip PASS-flagged\nverdict PASS-flagged')
        # run-07: a rule scope that matches 0 files -> NOT RUN, not clean
        row = ledger_row('A107', ['src/a.tsx:5'], RX, "  proof_class: EQ\n").replace('detector_scope: [src/**/*.tsx]', 'detector_scope: [src/featurez/*]')
        runs['run-07'] = (udiff('src/a.tsx', B['src/a.tsx'], sub('src/a.tsx', "'#d92d20'", "'var(--color-danger)'")), row, {},
                          'vacuous NOT RUN\nverdict NOT RUN')
        # run-08: a token that does not exist
        runs['run-08'] = (udiff('src/a.tsx', B['src/a.tsx'], sub('src/a.tsx', "'#d92d20'", "'var(--color-dangerous)'")),
                          ledger_row('A108', ['src/a.tsx:5'], RX, "  proof_class: EQ\n"), {}, 'names FAIL\nverdict FAIL')
        # run-09: the fix leaves the second site on the same line -> re-detect FAIL
        p = udiff('src/c.tsx', B['src/c.tsx'], sub('src/c.tsx', "color: '#d92d20'", "color: 'var(--color-danger)'"))
        runs['run-09'] = (p, ledger_row('A109', ['src/c.tsx:2'], RX, "  proof_class: EQ\n"), {}, 'redetect FAIL\nverdict FAIL')
        # run-10: a judge says PASS on a FAIL run -> refused; a judge flags a PASS run -> pending-review
        runs['run-10'] = (runs['run-08'][0], runs['run-08'][1], {'judge': [{'id': 'A108', 'verdict': 'PASS', 'reason': 'looks fine'}]},
                          'names FAIL\nverdict FAIL')
        runs['run-11'] = (runs['run-05'][0], runs['run-05'][1], {'judge': [{'id': 'A105', 'verdict': 'pending-review', 'reason': 'odd import'}]},
                          'verdict pending-review')
        # run-12: a suppression added + the suppressions baseline grew -> ratchet FAIL
        new = sub('src/a.tsx', "  return <span style={{ color: '#d92d20' }} />;", "  // eslint-disable-next-line no-restricted-syntax\n  return <span style={{ color: 'var(--color-danger)' }} />;")
        p = udiff('src/a.tsx', B['src/a.tsx'], new) + udiff('eslint-suppressions.json', B['eslint-suppressions.json'],
                                                            B['eslint-suppressions.json'].replace('"count": 1', '"count": 3'))
        runs['run-12'] = (p, ledger_row('A112', ['src/a.tsx:5'], RX, "  proof_class: EQ\n", ['src/a.tsx', 'eslint-suppressions.json']), {},
                          'ratchet FAIL\nverdict FAIL')
        # run-13: an invented oracle quote -> L0 FAIL (AL-01)
        runs['run-13'] = (runs['run-05'][0], runs['run-05'][1].replace('never hardcode a hex colour', 'hex colours are banned in JSX'), {},
                          'oracle FAIL\nverdict FAIL')
        # run-14: whitespace-only change to a hit file -> diffkind FAIL
        runs['run-14'] = (udiff('src/b.tsx', B['src/b.tsx'], B['src/b.tsx'].replace('  return', '    return')),
                          ledger_row('A114', ['src/b.tsx:2'], RX, "  proof_class: EQ\n"), {}, 'diffkind FAIL\nverdict FAIL')
        # run-15: context-keyed mapping (text colour vs border colour, one token per role) is not AL-33
        old = B['src/c.tsx']
        new = old.replace("color: '#d92d20'", "color: 'var(--color-danger)'").replace("borderColor: '#d92d20'", "borderColor: 'var(--color-error)'")
        runs['run-15'] = (udiff('src/c.tsx', old, new), ledger_row('A115', ['src/c.tsx:2'], RX, "  proof_class: EQ\n"), {},
                          'consistency PASS\nredetect PASS\nroundtrip PASS\nverdict PASS')
        # run-16: the run-05 swap with its import written through the tsconfig alias `@/*` -> `./src/*`
        new = "import { Button } from '@/ui/Button';\n" + sub('src/a.tsx', "'#d92d20'", "'var(--color-danger)'")
        runs['run-16'] = (udiff('src/a.tsx', B['src/a.tsx'], new), ledger_row('A116', ['src/a.tsx:5'], RX, "  proof_class: EQ\n"), {},
                          'names PASS\nscope PASS\nverdict PASS')
        # run-17: the raw import dropped and its wrapper merged into the import the file already has (one change)
        new = B['src/d.tsx'].replace("import { Root as DialogRoot } from '@radix-ui/react-dialog';\nimport { DialogContent } from './ui/dialog';\n",
                                     "import { Dialog as DialogRoot, DialogContent } from './ui/dialog';\n")
        runs['run-17'] = (udiff('src/d.tsx', B['src/d.tsx'], new), ledger_row('A117', ['src/d.tsx:1'], '@radix-ui/', "  proof_class: EQ\n"), {},
                          'scope PASS\nredetect PASS\nnames PASS\nverdict PASS')
        # run-18: a brace-glob detector_scope is one glob, not two broken halves (V-09 must not read it as vacuous)
        runs['run-18'] = (runs['run-05'][0], runs['run-05'][1].replace('detector_scope: [src/**/*.tsx]', 'detector_scope: [src/**/*.{ts,tsx}]'), {},
                          'vacuous PASS\nverdict PASS')
        fr = os.path.join(root, 'fix-runs')
        os.makedirs(fr, exist_ok=True)
        for n, (patch, led, meta, exp) in runs.items():
            for ext, content in (('.patch', patch), ('.ledger.md', led), ('.expect', exp + '\n')):
                with open(os.path.join(fr, n + ext), 'w') as fh:
                    fh.write(content)
            if meta:
                with open(os.path.join(fr, n + '.json'), 'w') as fh:
                    json.dump(meta, fh)
        tm_ok = load_token_map(TOKEN_MAP_DEFAULT) is not None
        check('token-map.py (ui-ux) importable from the pack layout', tm_ok)
        before = {f: read(os.path.join(root, f)) for f in BASE_TREE}
        ok, out = fix_runs(fr, root, {})
        for line in out:
            if '\texpect OK' not in line and line.startswith('run-'):
                bad.append(line)
        tot[0] += len(runs)
        check('the base tree was never written', all(read(os.path.join(root, f)) == c for f, c in before.items()))
        # judge refusal is printed
        run, final = one_run(root, runs['run-10'][0], runs['run-10'][1], runs['run-10'][2], {'all': True})
        check('judge-override-refused printed', any(v == 'judge-override-refused' for _, _, _, v, _ in run.out) and final == 'FAIL')
        # cost order: without --all the ladder stops at the first FAIL step
        run, final = one_run(root, runs['run-03'][0], runs['run-03'][1], {}, {})
        check('stops at the first FAIL (later steps SKIPPED)', check_verdict(run, 'redetect') == 'SKIPPED' and final == 'FAIL')
        # without token-map: roundtrip is NOT RUN, never PASS
        run, final = one_run(root, runs['run-05'][0], runs['run-05'][1], {}, {'all': True, 'tokens': '/nonexistent/token-map.py'})
        check('no ui-ux pack -> roundtrip NOT RUN', check_verdict(run, 'roundtrip') == 'NOT RUN' and final == 'NOT RUN')
        # two roles, but one role resolved two ways -> FAIL even though another role differs
        old = B['src/c.tsx']
        new = old.replace("color: '#d92d20', borderColor: '#d92d20'", "color: 'var(--color-danger)', borderColor: 'var(--color-error)'")
        new2 = B['src/b.tsx'].replace("color: '#d92d20'", "color: 'var(--color-error)'")
        run, final = one_run(root, udiff('src/c.tsx', old, new) + udiff('src/b.tsx', B['src/b.tsx'], new2),
                             ledger_row('A116', ['src/c.tsx:2', 'src/b.tsx:2'], RX), {}, {'all': True})
        cv = [d for _, c, _, v, d in run.out if c == 'consistency']
        check('text role resolved two ways across files -> AL-33 FAIL', check_verdict(run, 'consistency') == 'FAIL', str(cv))
        # missing detector -> redetect NOT RUN
        row = runs['run-05'][1].replace('  detector_re: "#d92d20"\n', '')
        run, final = one_run(root, runs['run-05'][0], row, {}, {'all': True})
        check('no detector recorded -> redetect NOT RUN', check_verdict(run, 'redetect') == 'NOT RUN')
        # ledger parse
        rows = parse_ledger(runs['run-18'][1])
        check('ledger: a brace glob in an inline list stays one item', rows and rows[0]['detector_scope'] == ['src/**/*.{ts,tsx}'],
              str(rows and rows[0].get('detector_scope')))
        rows = parse_ledger(runs['run-06b'][1])
        check('ledger: lists, inline lists, quoted oracle', rows and rows[0]['evidence'] == ['src/c.tsx:2'] and rows[0]['scope'] == ['src/c.tsx']
              and rows[0]['oracle'].startswith('ai/conventions.md') and rows[0]['approval'].startswith('ana@'))
    finally:
        shutil.rmtree(base, ignore_errors=True)
    for b in bad:
        sys.stderr.write('  FAIL %s\n' % b)
    print('align-sweep-gate --self-test: %d/%d %s' % (tot[0] - len(bad), tot[0], 'OK' if not bad else 'FAIL'))
    return 0 if not bad else 3


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
