#!/usr/bin/env python3
"""kn_common.py — the shared reader under the five learning detectors (knowledge-refs.py,
knowledge-facts.py, sink-audit.py, adr-index.py, load-budget.py). Not run on its own.

What every engine needs and must agree on, so one place decides it:
  - the census: `git ls-files` (case-sensitive, so a case-only rename is seen on macOS — P-11),
    with an os.walk fallback that the ledger prints as `census=find` (no git) or `census=find-untracked` (the root
    is an untracked subtree: `git ls-files` lists nothing, so the walk is the census and no history lane runs);
  - the knowledge CORPUS and its scope: history files dropped (P-3), memory sinks handed to
    memory-hygiene-scan, pack-installed bodies read only inside their live anchor region (P-10),
    HTML block comments marked as not loaded (P-21), ADR Context sections treated as history;
  - path resolution in a fixed order: exact, relative to the citing file, tsconfig/jsconfig
    `paths` (JSONC read by a string-aware scanner — a `/*` inside `"@/*"` is not a comment),
    workspace package names, extension-less, unique tracked suffix (P-6), then on-disk-but-
    untracked (P-1, P-25), matched case-exactly (P-11);
  - the ADR home (KN-29) and the manifest/lockfile facts.

Safety: stdlib only, Python >= 3.8, `python3 -I` safe. Reads files and runs read-only git with
GIT_OPTIONAL_LOCKS=0 (no index refresh, no lock file). Never writes under the scanned root: the
importing engines set sys.dont_write_bytecode before importing this module, so no __pycache__
lands in an installed .claude/skills/ directory of the scanned repository.
"""
import json
import os
import re
import subprocess
import sys
import unicodedata

GIT_ENV = dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0', LC_ALL='C', GIT_PAGER='cat')

SKIP_DIRS = {'node_modules', '.git', 'dist', 'build', 'out', '.next', '.nuxt', '.output', '.svelte-kit', 'coverage',
             'vendor', 'third_party', '.turbo', '.cache', '.venv', 'venv', '__pycache__', 'target', '.gradle',
             '.dart_tool', 'Pods', '__generated__', 'generated', '.idea', '.vscode', 'storybook-static'}

CONTEXT_NAMES = ('CLAUDE.md', 'CLAUDE.local.md', 'AGENTS.md', 'GEMINI.md')
# P-3: dated records are not drift.
HISTORY_RE = re.compile(r'^(?:ai/(?:audits|incidents|runs|archive|_archive|migration)/'
                        r'|ai/dynamic/(?:changelog|interaction-log)\.md$'
                        r'|(?:.*/)?_?history\.md$'
                        r'|(?:.*/)?CHANGELOG[^/]*$)', re.I)
# P-8: a line or file that describes ANOTHER codebase (a V1 being ported, a legacy system) names that
# codebase's paths and symbols on purpose; they never resolved here.
FOREIGN_LINE = re.compile(r"(?<![\w/.-])(?:[vV]1|legacy|Legacy|old (?:app|system|codebase|repo)|upstream repo|the other repo)(?![\w/.-])")
FOREIGN_FILE = re.compile(r'(?:^|/)(?:v1|legacy|old)[-_][^/]*\.md$|(?:^|/)(?:v1|legacy)/', re.I)
# Memory sinks: memory-hygiene-scan owns every citation inside an entry (KN-20).
SINK_RE = re.compile(r'^ai/(?:dynamic|failures|evals)/')
PACK_BODY_DIRS = ('.claude/agents/', '.claude/commands/', '.claude/skills/', '.claude/templates/')
START = '<!-- project-specific:start -->'
END = '<!-- project-specific:end -->'
FENCE_RE = re.compile(r'^\s*(```|~~~)')


def git(root, *args, **kw):
    """(rc, stdout text). rc 127 when git is absent. Read-only commands only."""
    try:
        p = subprocess.run(['git', '-C', root, '-c', 'core.quotepath=off', '-c', 'core.fsmonitor=false'] + list(args), stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, env=GIT_ENV, timeout=kw.get('timeout', 120))
    except (OSError, subprocess.TimeoutExpired):
        return 127, ''
    return p.returncode, p.stdout.decode('utf-8', 'replace')


def read_text(path, limit=8 * 1024 * 1024):
    try:
        with open(path, encoding='utf-8', errors='replace') as fh:
            return fh.read(limit)
    except OSError:
        return None


def strip_jsonc(raw):
    """Remove // and /* */ comments outside string literals (a regex would read the `/*` in
    `"@/*"` as a comment and swallow the whole compilerOptions object)."""
    out, i, n = [], 0, len(raw)
    while i < n:
        c = raw[i]
        if c == '"':
            j = i + 1
            while j < n:
                if raw[j] == '\\':
                    j += 2
                    continue
                if raw[j] == '"':
                    break
                j += 1
            out.append(raw[i:j + 1])
            i = j + 1
            continue
        if c == '/' and i + 1 < n and raw[i + 1] == '/':
            while i < n and raw[i] != '\n':
                i += 1
            continue
        if c == '/' and i + 1 < n and raw[i + 1] == '*':
            e = raw.find('*/', i + 2)
            i = n if e < 0 else e + 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def split_lines(text):
    """The file's lines: a final newline ends the last line, it does not start an empty one (`a\\nb\\n` is 2 lines,
    as `wc -l` and an editor count them; text.split('\\n') would say 3)."""
    ls = text.split('\n')
    if ls and ls[-1] == '':
        ls.pop()
    return ls


def read_jsonc(path):
    raw = read_text(path)
    if raw is None:
        return None
    try:
        return json.loads(re.sub(r',(\s*[}\]])', r'\1', strip_jsonc(raw)))
    except ValueError:
        return None


class Repo(object):
    """Census + resolution for one scanned root. Never writes."""

    def __init__(self, root):
        self.root = os.path.abspath(root)
        self.files, self.census = self._census()
        self.fset = set(self.files)
        self.dset = set()
        for f in self.files:
            d = os.path.dirname(f)
            while d and d not in self.dset:
                self.dset.add(d)
                d = os.path.dirname(d)
        self._suffix = None
        self._lines = {}
        self._aliases = None
        self._members = None
        self._ignored = {}
        self._dirs = {}
        self.has_git = self.census == 'git'

    # ---------------------------------------------------------------- census
    def _census(self):
        rc, out = git(self.root, 'ls-files', '-z')
        listed = [p for p in out.split('\0') if p] if rc == 0 else []
        if listed:
            return listed, 'git'
        # rc 0 with nothing listed: the root is an untracked subtree of an enclosing repository (or a repo with no
        # commit staged yet). git knows nothing here, and `git log` would answer for the enclosing repository with
        # paths relative to ITS root: take the walk, and no history lane (census=find-untracked).
        files = []
        for d, dn, fn in os.walk(self.root):
            dn[:] = [x for x in dn if x not in SKIP_DIRS]
            for f in fn:
                files.append(os.path.relpath(os.path.join(d, f), self.root).replace(os.sep, '/'))
        return sorted(files), 'find-untracked' if rc == 0 else 'find'

    def exists_on_disk(self, rel):
        """Case-exact: on a case-insensitive filesystem (APFS, NTFS) os.path.exists finds `apiClient.ts` for
        `ApiClient.ts`, so a case-only rename would read as present (P-11). Every component must appear verbatim
        in its parent's listing (NFC-compared: APFS may hand back NFD names)."""
        if not os.path.exists(os.path.join(self.root, rel)):
            return False
        cur = self.root
        for part in rel.replace(os.sep, '/').split('/'):
            if part in ('', '.'):
                continue
            if part == '..':
                cur = os.path.dirname(cur)
                continue
            if unicodedata.normalize('NFC', part) not in self._listing(cur):
                return False
            cur = os.path.join(cur, part)
        return True

    def _listing(self, d):
        if d not in self._dirs:
            try:
                self._dirs[d] = set(unicodedata.normalize('NFC', x) for x in os.listdir(d))
            except OSError:
                self._dirs[d] = set()
        return self._dirs[d]

    def lines(self, rel):
        if rel not in self._lines:
            t = read_text(os.path.join(self.root, rel))
            self._lines[rel] = None if t is None else split_lines(t)
        return self._lines[rel]

    def head_sha(self):
        rc, out = git(self.root, 'rev-parse', 'HEAD')
        return out.strip() if rc == 0 else ''

    # ---------------------------------------------------------------- suffix index (P-6)
    def suffix_hits(self, cand):
        if self._suffix is None:
            idx = {}
            for coll in (self.files, self.dset):
                for f in coll:
                    parts = f.split('/')
                    for k in range(1, len(parts) + 1):
                        idx.setdefault('/'.join(parts[-k:]), set()).add(f)
            self._suffix = idx
        return sorted(self._suffix.get(cand, ()))

    def ignored(self, rels):
        """Subset of rels git would ignore (P-1, P-25). Empty without git."""
        todo = [r for r in rels if r not in self._ignored]
        if todo and self.has_git:
            try:
                p = subprocess.run(['git', '-C', self.root, '-c', 'core.fsmonitor=false', 'check-ignore', '--stdin', '-z'],
                                   input='\0'.join(todo).encode(), stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=GIT_ENV, timeout=60)
                hit = set(x for x in p.stdout.decode('utf-8', 'replace').split('\0') if x)
            except (OSError, subprocess.TimeoutExpired):
                hit = set()
            for r in todo:
                self._ignored[r] = r in hit
        return set(r for r in rels if self._ignored.get(r))

    # ---------------------------------------------------------------- tsconfig paths + workspaces
    def aliases(self):
        """[(prefix, suffix, [repo-relative target templates])], longest prefix first, from every
        tracked tsconfig*/jsconfig (`extends` followed for relative bases, depth <= 4)."""
        if self._aliases is not None:
            return self._aliases
        rules = []
        for f in self.files:
            b = os.path.basename(f)
            if not (b.startswith('tsconfig') or b.startswith('jsconfig')) or not b.endswith('.json'):
                continue
            if '/node_modules/' in '/' + f:
                continue
            paths, base = self._paths_of(os.path.join(self.root, f), 0)
            if not paths:
                continue
            for key, tgts in paths.items():
                if not isinstance(tgts, list) or key.count('*') > 1:
                    continue
                pre, _, suf = key.partition('*')
                tmpl = []
                for t in tgts:
                    if isinstance(t, str) and t.count('*') <= 1:
                        r = os.path.relpath(os.path.normpath(os.path.join(base, t)), self.root).replace(os.sep, '/')
                        if not r.startswith('..'):
                            tmpl.append(r)
                if tmpl:
                    rules.append((pre, suf if '*' in key else '', tmpl, '*' in key))
        rules.sort(key=lambda r: len(r[0]), reverse=True)
        self._aliases = rules
        return rules

    def _paths_of(self, cfg_file, depth):
        cfg = read_jsonc(cfg_file)
        if not isinstance(cfg, dict) or depth > 4:
            return None, None
        here = os.path.dirname(cfg_file)
        co = cfg.get('compilerOptions') if isinstance(cfg.get('compilerOptions'), dict) else {}
        if isinstance(co.get('paths'), dict):
            base = os.path.normpath(os.path.join(here, co['baseUrl'])) if isinstance(co.get('baseUrl'), str) else here
            return co['paths'], base
        ext = cfg.get('extends')
        for e in ([ext] if isinstance(ext, str) else ext if isinstance(ext, list) else []):
            if isinstance(e, str) and e.startswith('.'):
                c = os.path.normpath(os.path.join(here, e))
                for cand in (c, c + '.json'):
                    if os.path.isfile(cand):
                        p, b = self._paths_of(cand, depth + 1)
                        if p:
                            return p, b
        return None, None

    def members(self):
        """{package name: member dir} for every tracked package.json outside node_modules."""
        if self._members is not None:
            return self._members
        m = {}
        for f in self.files:
            if os.path.basename(f) != 'package.json' or '/node_modules/' in '/' + f:
                continue
            pj = read_jsonc(os.path.join(self.root, f))
            if isinstance(pj, dict) and isinstance(pj.get('name'), str):
                m[pj['name']] = os.path.dirname(f)
        self._members = m
        return m

    # ---------------------------------------------------------------- resolution
    EXTS = ('.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.mts', '.cts', '.py', '.md', '.json', '.vue', '.svelte',
            '.go', '.rb', '.php', '.java', '.kt', '.cs', '.yml', '.yaml', '.sql', '.sh')

    def _hit(self, p):
        p = p.rstrip('/')
        if p in self.fset or p in self.dset:
            return p
        if not os.path.splitext(p)[1] or os.path.splitext(p)[1] not in self.EXTS:
            for e in self.EXTS:
                if p + e in self.fset:
                    return p + e
            for e in ('/index.ts', '/index.tsx', '/index.js', '/__init__.py'):
                if p + e in self.fset:
                    return p + e
        return None

    def resolve(self, cand, from_file):
        """(status, target, n). status: exact | relative | alias | package | abbrev | ambiguous |
        untracked | ignored | dead."""
        c = cand.strip()
        if c.startswith('./'):
            c = c[2:]
        c = c.rstrip('/')
        if not c:
            return 'dead', None, 0
        if c.startswith('/'):
            c2 = c.lstrip('/')
            h = self._hit(c2)
            if h:
                return 'exact', h, 1
            c = c2
        h = self._hit(c)
        if h:
            return 'exact', h, 1
        rel = os.path.normpath(os.path.join(os.path.dirname(from_file), c)).replace(os.sep, '/')
        if not rel.startswith('..'):
            h = self._hit(rel)
            if h:
                return 'relative', h, 1
        for pre, suf, tmpl, wild in self.aliases():
            if wild:
                if not (c.startswith(pre) and c.endswith(suf)) or len(c) < len(pre) + len(suf):
                    continue
                star = c[len(pre):len(c) - len(suf)] if suf else c[len(pre):]
                outs = [t.replace('*', star) for t in tmpl]
            else:
                if c != pre:
                    continue
                outs = tmpl
            for o in outs:
                h = self._hit(o)
                if h:
                    return 'alias', h, 1
            break
        if c.startswith('@') or '/' in c:
            mem = self.members()
            parts = c.split('/')
            for k in (2, 1):
                name = '/'.join(parts[:k])
                if name in mem:
                    sub = '/'.join(parts[k:])
                    for base in ([mem[name] + '/src', mem[name]] if sub else [mem[name]]):
                        h = self._hit((base + '/' + sub).strip('/') if sub else base)
                        if h:
                            return 'package', h, 1
        hits = self.suffix_hits(c)
        if not hits and not os.path.splitext(c)[1]:
            for e in self.EXTS:
                hits = self.suffix_hits(c + e)
                if hits:
                    break
        if len(hits) == 1:
            return 'abbrev', hits[0], 1
        if len(hits) > 1:
            return 'ambiguous', None, len(hits)
        for p in (c, rel):
            if p and not p.startswith('..') and self.exists_on_disk(p):
                return 'untracked', p, 1
        return 'dead', None, 0

    # ---------------------------------------------------------------- git history (DOCER, ReCite)
    def history_index(self):
        """{old path: ('D', sha) | ('R', new path)} from ONE `git log --name-status -M --diff-filter=DR`
        pass, newest first (the latest removal wins). A path never deleted or renamed and absent at HEAD
        never existed in this history (DOCER: such a reference never resolved)."""
        if getattr(self, '_hist', None) is not None:
            return self._hist
        gone = {}
        if self.has_git:
            rc, out = git(self.root, 'log', '-M', '--diff-filter=DR', '--name-status', '--format=@@@%H', timeout=600)
            sha = ''
            for line in out.split('\n'):
                if line.startswith('@@@'):
                    sha = line[3:13]
                    continue
                f = line.split('\t')
                if len(f) >= 2 and f[0] == 'D' and f[1] not in gone:
                    gone[f[1]] = ('D', sha)
                elif len(f) == 3 and f[0].startswith('R') and f[1] not in gone:
                    gone[f[1]] = ('R', f[2])
        self._hist = gone
        self._hist_base = {}
        for k in gone:
            self._hist_base.setdefault(os.path.basename(k), []).append(k)
        return gone

    def path_history(self, cand):
        """For a dead path: ('RENAMED', successor) | ('DELETED', sha) | ('NEVER-EXISTED', '') |
        ('NO-HISTORY', '') without git. A successor renamed again is followed up to 5 hops."""
        if not self.has_git:
            return 'NO-HISTORY', ''
        gone = self.history_index()
        spec = rel_body(cand)
        keys = [spec] if spec in gone else [k for k in self._hist_base.get(os.path.basename(spec), [])
                                             if k.endswith('/' + spec)]
        if not keys:
            # a directory: any removed path under it
            pre = spec + '/'
            under = [k for k in gone if k.startswith(pre) or ('/' + pre) in k]
            if not under:
                return 'NEVER-EXISTED', ''
            news = set(gone[k][1].rsplit('/', 1)[0] for k in under if gone[k][0] == 'R')
            return ('RENAMED', sorted(news)[0]) if len(news) == 1 else ('DELETED', gone[under[0]][1] if gone[under[0]][0] == 'D' else 'several')
        k = keys[0]
        kind, what = gone[k]
        hops = 0
        while kind == 'R' and what not in self.fset and what in gone and hops < 5:
            kind, nxt = gone[what]
            if kind == 'R':
                what = nxt
            hops += 1
        if kind == 'R':
            return 'RENAMED', what
        return 'DELETED', what

    def top_dirs(self):
        return set(f.split('/')[0] for f in self.files if '/' in f)


# -------------------------------------------------------------------- corpus and regions
def rel_body(c):
    """`./x/` -> `x`; a dotfile keeps its dot (str.lstrip('./') would turn `.claude/x` into `claude/x`)."""
    c = c.strip()
    while c.startswith('./'):
        c = c[2:]
    return c.lstrip('/').rstrip('/')


def frontmatter(lines):
    """{key: value} of a leading --- block (flat keys only)."""
    fm = {}
    if lines and lines[0].strip() == '---':
        for i in range(1, min(len(lines), 80)):
            if lines[i].strip() == '---':
                break
            m = re.match(r'^([A-Za-z_][\w-]*):\s*(.*)$', lines[i])
            if m:
                fm[m.group(1)] = m.group(2).strip()
    return fm


def is_pack_body(rel, lines):
    """P-10: an installed pack artifact (agent, command, skill, pack template, or a file whose
    frontmatter names its `pack:`) makes project claims only inside its live anchor region."""
    if rel.startswith(PACK_BODY_DIRS):
        return True
    return 'pack' in frontmatter(lines or [])


def anchor_scan(lines):
    """Column-0 markers outside fences. Returns (regions [(start, end) 1-based inclusive],
    problems [(line, kind)]) where kind is nested-start | start-without-end | end-without-start."""
    regions, problems, fence, open_at = [], [], False, None
    for i, l in enumerate(lines or [], 1):
        if FENCE_RE.match(l):
            fence = not fence
            continue
        if fence:
            continue
        if l.startswith(START):
            if open_at is not None:
                problems.append((i, 'nested-start'))
            else:
                open_at = i
        elif l.startswith(END):
            if open_at is None:
                problems.append((i, 'end-without-start'))
            else:
                regions.append((open_at, i))
                open_at = None
    if open_at is not None:
        problems.append((open_at, 'start-without-end'))
    return regions, problems


def live_lines(rel, lines, pack_body):
    """{line number: in_fence} for the lines that make live project claims in this file.
    Drops HTML block comments (not injected, P-21), ADR Context sections (history, P-3) and, for a
    pack body, everything outside the live anchor regions (P-10)."""
    keep = {}
    if lines is None:
        return keep
    allowed = None
    if pack_body:
        regions, _ = anchor_scan(lines)
        allowed = set()
        for a, b in regions:
            allowed.update(range(a + 1, b))
    fence, comment, context = False, False, False
    is_adr = bool(re.search(r'(^|/)(decisions|adrs?)/\d{3,4}-[^/]+\.md$', rel))
    for i, l in enumerate(lines, 1):
        if FENCE_RE.match(l):
            fence = not fence
            continue
        if not fence:
            s = l.strip()
            if comment:
                if '-->' in s:
                    comment = False
                continue
            if s.startswith('<!--') and '-->' not in s:
                comment = True
                continue
            if s.startswith('<!--') and s.endswith('-->'):
                continue
            if is_adr and re.match(r'^#{1,3}\s', l):
                context = bool(re.match(r'^#{1,3}\s*(context|background|problem|context and problem statement)\b', l, re.I))
            if context:
                continue
        if allowed is not None and i not in allowed:
            continue
        keep[i] = fence
    return keep


def corpus(repo, explicit=None):
    """[(rel, scope)] where scope is live | history | sink | pack-body | context. `explicit` (a list
    of repo-relative paths) replaces discovery — documentation passes its own corpus (O-1)."""
    out, seen = [], set()

    def add(rel):
        if rel in seen or not rel.endswith(('.md', '.mdc', '.markdown')) and os.path.basename(rel) not in CONTEXT_NAMES:
            return
        seen.add(rel)
        out.append(rel)

    if explicit is not None:
        for r in explicit:
            add(r)
    else:
        for f in repo.files:
            b = os.path.basename(f)
            if '/node_modules/' in '/' + f:
                continue
            if b in CONTEXT_NAMES or f == '.github/copilot-instructions.md' or f.startswith(
                    ('.github/instructions/', '.cursor/rules/', 'ai/', '.claude/rules/', '.claude/agents/',
                     '.claude/commands/', '.claude/skills/')) or re.match(r'^\.claude/(codebase-profile|_extracted-[\w-]+)\.md$', f):
                add(f)
        # Loaded files that are present but untracked (CLAUDE.local.md, a gitignored .claude/ tree).
        for name in CONTEXT_NAMES:
            if repo.exists_on_disk(name):
                add(name)
        for d in ('ai', '.claude/rules', '.claude/agents', '.claude/commands', '.claude/skills', '.cursor/rules'):
            top = os.path.join(repo.root, d)
            if not os.path.isdir(top):
                continue
            for dp, dn, fn in os.walk(top):
                dn[:] = [x for x in dn if x not in SKIP_DIRS]
                for f in fn:
                    add(os.path.relpath(os.path.join(dp, f), repo.root).replace(os.sep, '/'))
        for f in ('.claude/codebase-profile.md',):
            if repo.exists_on_disk(f):
                add(f)
    res = []
    for rel in sorted(out):
        if HISTORY_RE.match(rel):
            res.append((rel, 'history'))
        elif os.path.basename(rel).startswith('_template'):
            res.append((rel, 'template'))                    # placeholders by design (P-4)
        elif SINK_RE.match(rel):
            res.append((rel, 'sink'))
        else:
            res.append((rel, 'pack-body' if is_pack_body(rel, repo.lines(rel)) else 'live'))
    return res


def loaded_every_session(rel):
    """Files a session loads without being asked (severity one notch up)."""
    return rel in ('CLAUDE.md', '.claude/CLAUDE.md', 'CLAUDE.local.md', 'AGENTS.md', 'ai/_session-digest.md') \
        or rel.startswith('.claude/rules/')


# -------------------------------------------------------------------- ADR home (KN-29)
ADR_FILE = re.compile(r'^(\d{3,5})-[^/]+\.md$')
ADR_CANDIDATES = ('docs/decisions', 'docs/adr', 'docs/adrs', 'doc/adr', 'doc/decisions', 'adr', 'adrs', 'decisions',
                  'architecture/decisions', 'docs/architecture/decisions', 'ai/decisions')


def adr_home(repo):
    """(home or None, how, {dir: count}). The directory with most NNNN-*.md among the candidates
    and any other dir holding them, unless an index file declares its home."""
    counts = {}
    for f in repo.files:
        d, b = os.path.dirname(f), os.path.basename(f)
        if ADR_FILE.match(b) and (d in ADR_CANDIDATES or re.search(r'(^|/)(decisions|adrs?)$', d)):
            if '/node_modules/' in '/' + f:
                continue
            counts[d] = counts.get(d, 0) + 1
    for idx in ('ai/_decision-index.md', 'docs/decisions/README.md', 'ai/decisions/README.md'):
        ls = repo.lines(idx) if idx in repo.fset else None
        for l in (ls or [])[:40]:
            m = re.search(r'`((?:[\w.-]+/)*(?:decisions|adrs?))/?`', l)
            if m and m.group(1) in counts and re.search(r'\b(every|home|live|lives|ledger|all)\b', l, re.I):
                return m.group(1), 'declared in ' + idx, counts
    if not counts:
        return None, 'none', counts
    home = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
    return home, 'most NNNN-*.md files', counts


def adr_ids(repo, home):
    ids = {}
    if not home:
        return ids
    for f in repo.files:
        if os.path.dirname(f) == home:
            m = ADR_FILE.match(os.path.basename(f))
            if m:
                ids[int(m.group(1))] = f
    return ids


# -------------------------------------------------------------------- manifests and lockfiles
def lock_versions(repo):
    """({package: set(versions)}, [lockfile labels], {package: [manifest files]}).
    Lockfiles: pnpm-lock.yaml (v6-9), package-lock.json (v2/3), yarn.lock (v1 + berry), poetry.lock,
    uv.lock, go.mod (+ go.sum not needed), Gemfile.lock, composer.lock. Manifests: package.json,
    pyproject.toml, requirements*.txt, go.mod, Gemfile, composer.json."""
    vers, labels, decl = {}, [], {}

    def addv(name, v):
        m = re.match(r'v?(\d+(?:\.\d+){0,2})', v or '')
        if name and m:
            vers.setdefault(name, set()).add(m.group(1))

    for f in repo.files:
        if '/node_modules/' in '/' + f or '/vendor/' in '/' + f:
            continue
        b = os.path.basename(f)
        p = os.path.join(repo.root, f)
        if b == 'pnpm-lock.yaml':
            labels.append(f)
            for l in (read_text(p, 64 * 1024 * 1024) or '').split('\n'):
                m = re.match(r"^\s{2}['\"]?/?((?:@[^/@\s'\"]+/)?[^@\s/'\"(]+)@(\d[^('\":\s]*)", l)
                if m:
                    addv(m.group(1), m.group(2))
                    continue
        elif b == 'package-lock.json':
            labels.append(f)
            j = read_jsonc(p) or {}
            for k, v in (j.get('packages') or {}).items():
                if isinstance(v, dict) and 'node_modules/' in k:
                    addv(k.rsplit('node_modules/', 1)[1], v.get('version'))
        elif b == 'yarn.lock':
            labels.append(f)
            cur = []
            for l in (read_text(p, 64 * 1024 * 1024) or '').split('\n'):
                if l and not l.startswith((' ', '#')):
                    cur = [re.sub(r'^"?((?:@[^/@]+/)?[^@"]+)@.*$', r'\1', s.strip().strip('"'))
                           for s in l.rstrip(':').split(',')]
                m = re.match(r'^\s+version:?\s+"?(\d[^"\s]*)', l)
                if m:
                    for n in cur:
                        addv(n, m.group(1))
        elif b in ('poetry.lock', 'uv.lock'):
            labels.append(f)
            name = None
            for l in (read_text(p) or '').split('\n'):
                m = re.match(r'^name\s*=\s*"([^"]+)"', l)
                if m:
                    name = m.group(1).lower()
                m = re.match(r'^version\s*=\s*"([^"]+)"', l)
                if m and name:
                    addv(name, m.group(1))
                    name = None
        elif b == 'go.mod':
            labels.append(f)
            for l in (read_text(p) or '').split('\n'):
                m = re.match(r'^\s*(?:require\s+)?([\w.\-/]+\.[\w.\-/]+)\s+(v[\d.]+)', l)
                if m:
                    addv(m.group(1), m.group(2))
                    decl.setdefault(m.group(1), []).append(f)
                m = re.match(r'^go\s+(\d+\.\d+)', l)
                if m:
                    addv('go', m.group(1))
        elif b == 'Gemfile.lock':
            labels.append(f)
            for l in (read_text(p) or '').split('\n'):
                m = re.match(r'^    ([\w.-]+) \(([\d.]+)', l)
                if m:
                    addv(m.group(1), m.group(2))
        elif b == 'composer.lock':
            labels.append(f)
            j = read_jsonc(p) or {}
            for pk in (j.get('packages') or []) + (j.get('packages-dev') or []):
                if isinstance(pk, dict):
                    addv(pk.get('name'), pk.get('version'))
        if b == 'package.json':
            j = read_jsonc(p)
            if isinstance(j, dict):
                for sec in ('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'):
                    for n in (j.get(sec) or {}):
                        decl.setdefault(n, []).append(f)
        elif b == 'pyproject.toml' or re.match(r'^requirements[\w.-]*\.txt$', b):
            for l in (read_text(p) or '').split('\n'):
                m = re.match(r'^\s*["\']?([A-Za-z][\w.-]+)(?:\[[^\]]*\])?\s*(?:[=<>~!]=?|["\',]|$)', l)
                if m and not re.match(r'^\s*(name|version|description|requires|readme|license|authors|python)\b', l):
                    decl.setdefault(m.group(1).lower(), []).append(f)
        elif b in ('Gemfile',):
            for l in (read_text(p) or '').split('\n'):
                m = re.match(r"^\s*gem\s+['\"]([\w.-]+)", l)
                if m:
                    decl.setdefault(m.group(1), []).append(f)
        elif b == 'composer.json':
            j = read_jsonc(p)
            if isinstance(j, dict):
                for sec in ('require', 'require-dev'):
                    for n in (j.get(sec) or {}):
                        decl.setdefault(n, []).append(f)
    return vers, labels, decl


QUIET = False


def ledger(msg):
    if QUIET:
        return
    sys.stderr.write(msg.rstrip('\n') + '\n')
