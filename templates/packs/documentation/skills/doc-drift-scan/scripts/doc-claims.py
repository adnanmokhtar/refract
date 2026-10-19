#!/usr/bin/env python3
"""doc-claims.py - the claims engine of the documentation pack (stdlib only, Python >= 3.8).

Extracts every checkable claim that a project's HUMAN docs make (README, CONTRIBUTING, docs/**,
package READMEs, runbooks, ADR metadata, changelogs, translations) and resolves each one against
its oracle: the tree, the manifests, the env schema, the committed spec and the router, the deploy
manifests, git history, or another doc. It never writes inside the scanned repo.

  python3 -I doc-claims.py <repo> [--lanes=<a,b>] [--docs=<path,...>] [--class=<id,...>]
          [--claim=<value>] [--recheck=<row-id>] [--all] [--check] [--out=<dir>]
          [--fences=<dir>] [--no-git] [--self-test]

stdout  one TSV row per candidate: id, status, class, surface, doc, line, claim, detail.
        status: MISS (resolves to nothing) | WRONG (resolves to something else) | CHECK (ambiguous:
        read it). --all adds `ok` and `skip(<precedent>)` rows.
stderr  the ledger: scope, renderer, oracles, one line per lane (ran / N/A / blocked), exit reason.
exit    0 no candidate | 1 candidates | 2 blocked (bad arguments, an output dir inside the repo, or
        a lane that raised: its classes are blocked, never clean).

Lanes and classes (ids from the documentation research catalog):
  links DL-1/DL-2 (DL-3 counted, offline)   paths DR-1   symbols DR-2/DR-5   scripts DR-3
  flags DR-4   versions DS-2   tools DS-3   env DE-1/DE-2/DE-3   endpoints DA-1   specex DA-2
  embeds DC-3   breaking DH-1   changelog DH-2   resources DK-2   linksin DK-3   adr DX-1/2/3
  i18n DI-1/2/3   placeholders DF-1   nav DF-2   gates DL-4
  DR-1/DR-3/DR-4 rows inside a runbook are printed as DK-1.
Scope (precedents/documentation.md): agent-facing knowledge (ai/** except ai/runbooks and
ai/decisions, CLAUDE.md, AGENTS.md) is routed to the learning pack; tool config dirs are § 2;
dated records (audits, postmortems, changelog bodies, ADR bodies) are § 1; versioned docs § 12;
test data § 27. Every skip is counted in the ledger, never silent.
"""
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from collections import Counter, defaultdict
from urllib.parse import unquote

ENGINE = 'doc-claims 1.0'
LANES = ['links', 'paths', 'symbols', 'scripts', 'flags', 'versions', 'tools', 'env', 'endpoints',
         'specex', 'embeds', 'breaking', 'changelog', 'resources', 'linksin', 'adr', 'i18n',
         'placeholders', 'nav', 'gates']
SKIP_DIRS = {'node_modules', '.git', 'dist', 'build', 'coverage', '.turbo', '.next', '.nuxt',
             '.svelte-kit', '.output', 'vendor', '.venv', 'venv', 'target', '__pycache__',
             '.pnpm-store', '.cache', '.docusaurus', '_build', '.tox', '.mypy_cache',
             '.pytest_cache', '.gradle', 'obj', 'Pods', '.dart_tool', '.idea', '.yarn', '.nox',
             'site-packages', 'storybook-static', '.vercel', '.serverless', '.terraform'}
DOC_EXT = ('.md', '.mdx', '.markdown', '.rst')
CODE_EXT = ('.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.mts', '.cts', '.py', '.go', '.rs',
            '.java', '.kt', '.kts', '.rb', '.php', '.cs', '.dart', '.ex', '.exs', '.scala', '.swift',
            '.vue', '.svelte', '.sh', '.bash')
CONF_EXT = ('.json', '.yml', '.yaml', '.toml', '.ini', '.cfg', '.conf', '.env', '.properties', '.xml',
            '.gradle', '.tf', '.hcl', '.sql', '.prisma', '.graphql', '.proto', '.lock', '.txt',
            '.html', '.css', '.scss', '.svg', '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.pdf')
TEST_PATH = re.compile(r'(^|/)(test|tests|__tests__|spec|specs|e2e|__mocks__|mocks|fixtures|__fixtures__|'
                       r'testdata|test-data|__snapshots__)/|\.(spec|test|e2e-spec|stories)\.\w+$|(^|/)(test_[^/]*|[^/]*_test)\.\w+$')
AGENT_FILE = re.compile(r'(^|/)(CLAUDE|AGENTS|GEMINI|CODEX)(\.local)?\.md$', re.I)
TOOL_DIR = re.compile(r'^(\.claude|\.opencode|\.cursor|\.windsurf|\.continue|\.aider[^/]*|\.codex|\.gemini|\.kiro|'
                      r'\.github/(copilot[^/]*|instructions|prompts|chatmodes|agents))(/|$)')
AI_KEEP = re.compile(r'^ai/(runbooks|decisions)/')
DATED = re.compile(r'(^|/)(audits?|postmortems?|post-mortems?|incidents?|retros?|retrospectives?|runs|'
                   r'dynamic|meeting-notes|minutes)/|(^|/)(CHANGELOG|HISTORY|RELEASES|NEWS|RELEASE[-_]NOTES)[^/]*$', re.I)
VERSIONED = re.compile(r'(^|/)(versioned_docs|versioned_sidebars)/|(^|/)docs/(v\d+(\.\d+)*|\d+\.\d+(\.\d+)?)/')
CHANGELOG_NAME = re.compile(r'(^|/)(CHANGELOG|HISTORY|RELEASES|NEWS)(\.\w+)?\.(md|mdx|markdown|rst)$', re.I)
ADR_DIR = re.compile(r'(^|/)(adr|adrs|decisions|decision-records|architecture-decisions|architecture/decisions|'
                     r'architecture-decision-records)/')
ADR_FILE = re.compile(r'(?:^|/)(?:adr[-_]?)?(\d{3,5})[-_][^/]+\.(md|mdx|rst)$', re.I)
RUNBOOK_PATH = re.compile(r'(^|/)(runbooks?|playbooks?|incident-response|on-?call|sop)(/|[-_.][^/]*\.(md|mdx|rst)$)|'
                          r'(^|/)(RUNBOOK|PLAYBOOK)[^/]*\.(md|mdx|rst)$', re.I)
PRIMARY = re.compile(r'(^|/)(README|CONTRIBUTING|INSTALL|INSTALLATION|QUICKSTART|GETTING[-_]STARTED|SETUP|'
                     r'DEVELOPMENT|DEVELOPING|HACKING)[^/]*\.(md|mdx|rst|markdown)$|(^|/)(quickstart|getting-started|'
                     r'installation|install|setup|tutorials?)(/|[^/]*\.(md|mdx|rst)$)|(^|/)(api|api[-_]reference|'
                     r'reference|sdk|config|configuration|env|environment)(/|[-_.][^/]*\.(md|mdx|rst)$|\.(md|mdx|rst)$)|'
                     r'(^|/)(openapi|swagger)[^/]*\.(json|ya?ml)$', re.I)
LOCALES = set('af ar az be bg bn bs ca cs cy da de el en eo es et eu fa fi fr ga gl gu he hi hr hu hy id is '
              'it ja ka kk km kn ko ky lo lt lv mk ml mn mr ms my nb ne nl nn no pa pl ps pt ro ru si sk sl '
              'sq sr sv sw ta te th tl tr uk ur uz vi zh'.split())
LOCALE_RE = re.compile(r'^([a-z]{2})([-_][A-Za-z]{2,4})?$')
PM_BUILTIN = {
    'pnpm': set('add audit bin cat-file cat-index config create dedupe deploy dlx doctor env exec fetch find-hash '
                'help i import init install install-test it licenses link list ll ln ls outdated pack patch '
                'patch-commit patch-remove prune publish rb rebuild recursive remove rm root run self-update '
                'server setup store un uninstall unlink up update why x approve-builds ignored-builds'.split()),
    'npm': set('access adduser audit bugs cache ci completion config dedupe deprecate diff dist-tag docs doctor '
               'edit exec explain explore find-dupes fund get help hook i init install install-ci-test '
               'install-test link ll login logout ls org outdated owner pack ping pkg prefix profile prune '
               'publish query rebuild repo root search set shrinkwrap star stars team token uninstall unpublish '
               'unstar update version view whoami x add rm un'.split()),
    'yarn': set('add audit autoclean bin cache config create dedupe dlx exec explain generate-lock-entry global '
                'help import info init install licenses link list login logout node outdated owner pack patch '
                'plugin policies prune publish rebuild remove search set stage tag team unlink unplug up upgrade '
                'upgrade-interactive version versions why workspace workspaces'.split()),
    'bun': set('add audit build create exec i init install link outdated patch pm publish remove repl rm '
               'test update upgrade x why'.split()),
}
SCRIPT_ALIAS = {'npm': {'test', 'start', 'stop', 'restart', 't', 'tst'}, 'pnpm': {'test', 'start', 't', 'tst'},
                'yarn': {'test', 'start'}, 'bun': set()}
KNOWN_BIN = {'typescript': 'tsc', '@nestjs/cli': 'nest', '@playwright/test': 'playwright', '@angular/cli': 'ng',
             '@mikro-orm/cli': 'mikro-orm', 'sequelize-cli': 'sequelize', '@biomejs/biome': 'biome',
             '@changesets/cli': 'changeset', 'dependency-cruiser': 'depcruise', '@redocly/cli': 'redocly',
             '@stoplight/spectral-cli': 'spectral', '@microsoft/api-extractor': 'api-extractor',
             'dotenv-cli': 'dotenv', '@storybook/cli': 'sb', 'storybook': 'storybook', 'vitest': 'vitest',
             'jest': 'jest', 'ts-node': 'ts-node', 'tsx': 'tsx', 'prisma': 'prisma', 'drizzle-kit': 'drizzle-kit'}
SHELL_LANGS = {'', 'bash', 'sh', 'shell', 'zsh', 'console', 'shell-session', 'shellsession', 'terminal', 'fish',
               'powershell', 'ps1', 'pwsh', 'cmd', 'bat', 'sh-session'}
PLATFORM_ENV = re.compile(r'^(CI|PATH|HOME|USER|SHELL|PWD|TERM|TZ|LANG|LC_\w+|NODE_ENV|NODE_OPTIONS|PORT|HOST|'
                          r'HOSTNAME|DEBUG|GITHUB_\w+|RUNNER_\w+|GITLAB_\w+|CI_\w+|BUILDKITE\w*|CIRCLE\w*|AWS_\w+|'
                          r'AZURE_\w+|GOOGLE_\w+|GCP_\w+|GCLOUD_\w+|ARM_\w+|DOCKER_\w+|COMPOSE_\w+|KUBECONFIG|'
                          r'HELM_\w+|NPM_\w+|PNPM_\w+|YARN_\w+|COREPACK_\w+|PYTHON\w*|PIP_\w+|UV_\w+|POETRY_\w+|'
                          r'VIRTUAL_ENV|GO\w+|CARGO_\w+|RUST\w+|JAVA_HOME|GRADLE_\w+|MAVEN_\w+|DOTNET_\w+|'
                          r'DO_NOT_TRACK|\w*TELEMETRY\w*|NEXT_TELEMETRY_DISABLED|TURBO_\w+|VERCEL_\w*|NETLIFY\w*|'
                          r'HEROKU_\w+|CF_\w+|CLOUDFLARE_\w+|ANTHROPIC_\w+|OPENAI_\w+|GH_TOKEN|GITHUB_TOKEN|'
                          r'SSH_\w+|XDG_\w+|TMPDIR|EDITOR|VISUAL|PAGER|NO_COLOR|FORCE_COLOR|HTTPS?_PROXY|NO_PROXY|'
                          r'SENTRY_AUTH_TOKEN|CODECOV_TOKEN|NX_\w+|STORYBOOK_\w+|PLAYWRIGHT_\w+|PUPPETEER_\w+)$')


# ----------------------------------------------------------------------------- utilities

class Ctx(object):
    pass


def sh(ctx, args, timeout=90):
    """Read-only git call. Returns stdout text or None."""
    if not ctx.git:
        return None
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0', LC_ALL='C')
    try:
        p = subprocess.run(['git', '-C', ctx.root, '--no-pager'] + args, stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, env=env, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None
    if p.returncode != 0:
        return None
    return p.stdout.decode('utf-8', 'replace')


def read(ctx, rel):
    if rel in ctx.cache:
        return ctx.cache[rel]
    try:
        with open(os.path.join(ctx.root, rel), 'r', encoding='utf-8', errors='replace') as fh:
            t = fh.read(4000000)
    except (OSError, ValueError):
        t = ''
    ctx.cache[rel] = t
    return t


def rid(cls, doc, claim):
    return hashlib.sha1(('%s|%s|%s' % (cls, doc, claim)).encode('utf-8')).hexdigest()[:10]


def add(ctx, status, cls, doc, line, claim, detail='', surface=None):
    if ctx.only_docs is not None and doc and doc not in ctx.only_docs and not cls.startswith(('DE-2', 'DL-4', 'DK-3', 'DH-')):
        return
    if cls in ('DR-1', 'DR-3', 'DR-4') and doc in ctx.runbooks:
        cls = 'DK-1'
    if surface is None:
        surface = 'primary' if (doc and (PRIMARY.search(doc) or doc in ctx.runbooks)) else 'secondary'
    if doc in ctx.generated:
        detail = (detail + ' ' if detail else '') + '(generated doc: fix the source, § 17)'
    ctx.rows.append([rid(cls, doc, claim), status, cls, surface, doc, str(line), claim.replace('\t', ' '),
                     detail.replace('\t', ' ').replace('\n', ' ')])


def skip(ctx, cls, doc, line, claim, prec):
    ctx.skips[(cls, prec)] += 1
    if ctx.show_all:
        add(ctx, 'skip(%s)' % prec, cls, doc, line, claim)


def ok(ctx, cls, doc, line, claim, detail=''):
    if cls in ('DR-1', 'DR-3', 'DR-4') and doc in ctx.runbooks:
        ctx.oks['DK-1'] += 1
    ctx.oks[cls] += 1
    if ctx.show_all:
        add(ctx, 'ok', cls, doc, line, claim, detail)


def parse_version(s):
    m = re.match(r'\D*(\d+)(?:\.(\d+))?(?:\.(\d+))?', s or '')
    if not m:
        return None
    return tuple(int(x) for x in m.groups() if x is not None)


def semver_key(v):
    m = re.match(r'v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?', v)
    if not m:
        return None
    pre = m.group(4)
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)), 0 if pre else 1, pre or '')


# ----------------------------------------------------------------------------- tree index

def build_index(ctx):
    ctx.files, ctx.dirs = set(), set()
    ctx.by_base = defaultdict(list)
    for d, dirs, files in os.walk(ctx.root):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS and not os.path.islink(os.path.join(d, x)))
        rd = os.path.relpath(d, ctx.root)
        rd = '' if rd == '.' else rd
        if rd:
            ctx.dirs.add(rd)
            ctx.by_base[os.path.basename(rd)].append(rd)
        for f in files:
            r = (rd + '/' + f) if rd else f
            ctx.files.add(r)
            ctx.by_base[f].append(r)
    ctx.lower = {}
    for p in ctx.files | ctx.dirs:
        ctx.lower.setdefault(p.lower(), p)
    ctx.top = set(p for p in ctx.files | ctx.dirs if '/' not in p)
    man = ('package.json', 'pyproject.toml', 'go.mod', 'Cargo.toml', 'composer.json', 'pom.xml', 'build.gradle',
           'build.gradle.kts', 'Gemfile', 'mix.exs', 'pubspec.yaml', 'setup.py', 'deno.json')
    ctx.pkg_roots = sorted(set(os.path.dirname(f) for f in ctx.files if os.path.basename(f) in man
                               and os.path.dirname(f) and not TEST_PATH.search(f + '/')))


def exists(ctx, rel):
    return rel in ctx.files or rel in ctx.dirs or rel == ''


def code_files(ctx, exts=CODE_EXT, tests=False):
    for f in sorted(ctx.files):
        if f.endswith(exts) and (tests or not TEST_PATH.search(f)) and not TOOL_DIR.match(f):
            yield f


# ----------------------------------------------------------------------------- doc scope

def classify(ctx, rel):
    """Return (kind, reason). kind in doc/adr/changelog/skip."""
    if TOOL_DIR.match(rel):
        return 'skip', '§2'
    if AGENT_FILE.search(rel) or (rel.startswith('ai/') and not AI_KEEP.match(rel)):
        return 'skip', 'learning'
    if TEST_PATH.search(rel):
        return 'skip', '§27'
    if re.search(r'(^|/)_?template[^/]*\.(md|mdx|rst)$', rel, re.I):
        return 'skip', '§6'
    if CHANGELOG_NAME.search(rel):
        return 'changelog', ''
    if ADR_DIR.search(rel) and ADR_FILE.search(rel):
        return 'adr', ''
    if DATED.search(rel):
        return 'skip', '§1'
    if VERSIONED.search(rel):
        return 'skip', '§12'
    return 'doc', ''


def detect_renderer(ctx):
    ctx.renderers = []   # (root_dir, name, info)
    for f in sorted(ctx.files):
        b, d = os.path.basename(f), os.path.dirname(f)
        if b in ('mkdocs.yml', 'mkdocs.yaml'):
            t = read(ctx, f)
            m = re.search(r'^docs_dir:\s*["\']?([^"\'\n#]+)', t, re.M)
            root = os.path.normpath(os.path.join(d, (m.group(1).strip() if m else 'docs')))
            ctx.renderers.append((root, 'mkdocs', {'config': f, 'unicode': 'pymdownx.slugs' in t}))
        elif re.match(r'docusaurus\.config\.(js|ts|mjs|cjs)$', b):
            ctx.renderers.append((os.path.join(d, 'docs') if d else 'docs', 'docusaurus', {'config': f}))
        elif b == 'conf.py' and re.search(r'\bextensions\s*=|sphinx', read(ctx, f)):
            ctx.renderers.append((d, 'sphinx', {'config': f}))
        elif b == 'book.toml':
            m = re.search(r'^\s*src\s*=\s*["\']([^"\']+)', read(ctx, f), re.M)
            ctx.renderers.append((os.path.normpath(os.path.join(d, m.group(1) if m else 'src')), 'mdbook', {'config': f}))
        elif re.search(r'(^|/)\.vitepress/config\.(js|ts|mjs|mts)$', f):
            ctx.renderers.append((os.path.dirname(d), 'vitepress', {'config': f}))
        elif b in ('hugo.toml', 'hugo.yaml', 'hugo.json'):
            ctx.renderers.append((os.path.join(d, 'content') if d else 'content', 'hugo', {'config': f}))
    ctx.renderers.sort(key=lambda r: -len(r[0]))


def renderer_for(ctx, rel):
    for root, name, info in ctx.renderers:
        if root in ('', '.') or rel == root or rel.startswith(root.rstrip('/') + '/'):
            return name, info, root
    return 'github', {}, ''


# ----------------------------------------------------------------------------- markdown model

FENCE_OPEN = re.compile(r'^( {0,3})(`{3,}|~{3,})\s*([^`\s{]*)\s*(.*)$')
INLINE = re.compile(r'(`+)(.+?)\1')


def md_lines(text):
    """Yield (lineno, line, state, lang, info). state: 'text' | 'open' | 'code' | 'close' | 'front' | 'comment'."""
    lines = text.split('\n')
    in_f, fch, flen, lang, info = False, '', 0, '', ''
    in_c = False
    start = 0
    if lines and lines[0].strip() == '---':
        for j in range(1, min(len(lines), 200)):
            if lines[j].strip() in ('---', '...'):
                for k in range(0, j + 1):
                    yield k + 1, lines[k], 'front', '', ''
                start = j + 1
                break
    for i in range(start, len(lines)):
        line = lines[i]
        n = i + 1
        if in_f:
            s = line.strip()
            if s and s[0] == fch and set(s) <= {fch} and len(s) >= flen:
                in_f = False
                yield n, line, 'close', lang, info
            else:
                yield n, line, 'code', lang, info
            continue
        if in_c:
            yield n, line, 'comment', '', ''
            if '-->' in line:
                in_c = False
            continue
        m = FENCE_OPEN.match(line)
        if m and not (m.group(2)[0] == '`' and '`' in m.group(4)):
            in_f, fch, flen = True, m.group(2)[0], len(m.group(2))
            lang, info = m.group(3).lower(), m.group(4).strip()
            yield n, line, 'open', lang, info
            continue
        if '<!--' in line and '-->' not in line.split('<!--', 1)[1]:
            in_c = True
            yield n, line, 'comment', '', ''
            continue
        yield n, line, 'text', '', ''


def rst_lines(text):
    """Minimal RST adapter: code blocks become 'code' with their language."""
    lines = text.split('\n')
    in_b, ind, lang = False, 0, ''
    for i, line in enumerate(lines, 1):
        if in_b:
            if line.strip() == '' or (len(line) - len(line.lstrip())) > ind:
                yield i, line, 'code', lang, ''
                continue
            in_b = False
        m = re.match(r'^(\s*)\.\.\s+(?:code-block|code|sourcecode)::\s*(\S*)', line)
        if m:
            in_b, ind, lang = True, len(m.group(1)), m.group(2).lower()
            yield i, line, 'open', lang, ''
            continue
        if line.rstrip().endswith('::') and not line.strip().startswith('..'):
            in_b, ind, lang = True, len(line) - len(line.lstrip()), ''
            yield i, line, 'text', '', ''
            continue
        yield i, line, 'text', '', ''


def doc_lines(ctx, rel):
    key = ('lines', rel)
    if key not in ctx.cache:
        t = read(ctx, rel)
        ctx.cache[key] = list(rst_lines(t) if rel.endswith('.rst') else md_lines(t))
    return ctx.cache[key]


def inline_spans(line):
    return [m.group(2).strip() for m in INLINE.finditer(line)]


def strip_inline(line):
    return INLINE.sub(lambda m: ' ' * len(m.group(0)), line)


def fences(ctx, rel):
    """Return list of (start_line, lang, info, [lines])."""
    out, cur = [], None
    for n, line, st, lang, info in doc_lines(ctx, rel):
        if st == 'open':
            cur = (n, lang, info, [])
        elif st == 'code' and cur is not None:
            cur[3].append(line)
        elif st == 'close' and cur is not None:
            out.append(cur)
            cur = None
    if cur is not None and rel.endswith('.rst'):
        out.append(cur)
    return out


# ----------------------------------------------------------------------------- slugs and anchors

def clean_heading(h):
    h = re.sub(r'\s*\{[:#][^}]*\}\s*$', '', h)
    h = re.sub(r'<[^>]+>', '', h)
    h = re.sub(r'!?\[([^\]]*)\]\([^)]*\)', r'\1', h)
    h = h.replace('`', '').replace('**', '').replace('__', '')
    h = re.sub(r'(?<!\w)\*(?!\s)|(?<!\s)\*(?!\w)', '', h)
    return h.strip()


def slug_github(h):
    out = []
    for ch in h.lower():
        if ch == ' ':
            out.append('-')
        elif ch in '-_' or unicodedata.category(ch)[0] in ('L', 'N', 'M'):
            out.append(ch)
    return ''.join(out)


def slug_mkdocs(h, uni=False):
    if not uni:
        h = unicodedata.normalize('NFKD', h).encode('ascii', 'ignore').decode('ascii')
    h = re.sub(r'[^\w\s-]', '', h, flags=re.U).strip().lower()
    return re.sub(r'[-\s]+', '-', h)


def anchors_of(ctx, rel):
    key = ('anchors', rel)
    if key in ctx.cache:
        return ctx.cache[key]
    name, info, _ = renderer_for(ctx, rel)
    seen = Counter()
    a = set(['top'])
    for n, line, st, _, _ in doc_lines(ctx, rel):
        if st == 'front':
            m = re.match(r'^\s*(?:id|slug):\s*["\']?([\w-]+)', line)
            continue
        if st != 'text':
            continue
        for m in re.finditer(r'<a\s+[^>]*?(?:name|id)\s*=\s*["\']([^"\']+)["\']|\sid\s*=\s*["\']([^"\']+)["\']', line):
            a.add(m.group(1) or m.group(2))
        m = re.match(r'^(#{1,6})\s+(.*?)\s*#*\s*$', line)
        if not m and rel.endswith('.rst'):
            continue
        if m:
            raw = m.group(2)
            cid = re.search(r'\{\s*:?\s*#([\w-]+)[^}]*\}\s*$', raw)
            if cid:
                a.add(cid.group(1))
            text = clean_heading(raw)
            if name == 'mkdocs':
                base = slug_mkdocs(text, info.get('unicode'))
                k = seen[base]
                seen[base] += 1
                a.add(base if k == 0 else '%s_%d' % (base, k))
            else:
                base = slug_github(text)
                k = seen[base]
                seen[base] += 1
                a.add(base if k == 0 else '%s-%d' % (base, k))
    # setext headings
    lines = read(ctx, rel).split('\n')
    for i in range(1, len(lines)):
        if re.match(r'^(=+|-+)\s*$', lines[i]) and lines[i - 1].strip() and not lines[i - 1].startswith(('#', '|', '-', '*')):
            a.add(slug_github(clean_heading(lines[i - 1])))
    ctx.cache[key] = a
    return a


# ----------------------------------------------------------------------------- corpus

def build_corpus(ctx):
    ctx.docs = []          # (rel, kind)
    ctx.scope_skips = Counter()
    ctx.runbooks = set()
    ctx.generated = set()
    for f in sorted(ctx.files):
        if not f.endswith(DOC_EXT):
            continue
        kind, why = classify(ctx, f)
        if kind == 'skip':
            ctx.scope_skips[why] += 1
            continue
        ctx.docs.append((f, kind))
        head = read(ctx, f)[:1500]
        if re.search(r'(?i)(auto-?generated|generated by|do not edit|this file is generated)', head[:600]):
            ctx.generated.add(f)
        if kind == 'doc' and (RUNBOOK_PATH.search(f) or re.search(r'(?im)^type:\s*runbook\b', head) or
                              len(re.findall(r'(?im)^#{1,4}\s*(rollback|mitigation|escalation|diagnos\w*|recovery)\b',
                                             read(ctx, f))) >= 2):
            ctx.runbooks.add(f)
    ctx.claim_docs = [d for d, k in ctx.docs if k == 'doc' and (ctx.only_docs is None or d in ctx.only_docs)]


# ----------------------------------------------------------------------------- git helpers

def git_history(ctx):
    if hasattr(ctx, 'renames'):
        return
    ctx.renames, ctx.deleted = {}, {}
    out = sh(ctx, ['log', '-M', '--diff-filter=RD', '--name-status', '--format=@%h', '-n', '4000'])
    if out is None:
        return
    sha = ''
    for line in out.split('\n'):
        if line.startswith('@'):
            sha = line[1:]
            continue
        parts = line.split('\t')
        if len(parts) == 3 and parts[0].startswith('R'):
            ctx.renames.setdefault(parts[1], (parts[2], sha))
        elif len(parts) == 2 and parts[0] == 'D':
            ctx.deleted.setdefault(parts[1], sha)


def history_note(ctx, p):
    git_history(ctx)
    p = p.rstrip('/')
    if p in ctx.renames:
        new, sha = ctx.renames[p]
        return 'renamed -> %s (%s)' % (new, sha)
    for old, (new, sha) in ctx.renames.items():
        if old.endswith('/' + p) or old.startswith(p + '/'):
            if old.startswith(p + '/'):
                return 'dir renamed -> %s (%s)' % (new[:len(new) - (len(old) - len(p))] or new, sha)
            return 'renamed -> %s (%s)' % (new, sha)
    if p in ctx.deleted:
        return 'deleted in %s' % ctx.deleted[p]
    for old, sha in ctx.deleted.items():
        if old.startswith(p + '/') or old.endswith('/' + p):
            return 'deleted in %s' % sha
    return ''


def gitignored(ctx, paths):
    if not paths or not ctx.git:
        return set()
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0', LC_ALL='C')
    try:
        p = subprocess.run(['git', '-C', ctx.root, 'check-ignore', '--stdin'], input='\n'.join(paths).encode('utf-8'),
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return set()
    return set(x for x in p.stdout.decode('utf-8', 'replace').split('\n') if x)


# ----------------------------------------------------------------------------- lane: links (DL-1, DL-2)

LINK = re.compile(r'(!?)\[((?:[^\[\]]|\[[^\]]*\])*)\]\(\s*<?([^)\s>]*)>?(?:\s+["\'(][^)]*)?\)')
REFDEF = re.compile(r'^\s{0,3}\[([^\]^][^\]]*)\]:\s*<?(\S+?)>?(?:\s+["\'(].*)?$')
HTMLREF = re.compile(r'<(?:a|img|source|link|iframe)\b[^>]*?\s(?:href|src)\s*=\s*["\']([^"\']+)["\']', re.I)
RSTLINK = re.compile(r'`[^`<]*<([^>`]+)>`_{1,2}')


def link_targets(ctx, rel):
    out = []
    for n, line, st, _, _ in doc_lines(ctx, rel):
        if st != 'text':
            continue
        s = strip_inline(line)
        for m in LINK.finditer(s):
            out.append((n, m.group(3)))
        m = REFDEF.match(s)
        if m:
            out.append((n, m.group(2)))
        for m in HTMLREF.finditer(s):
            out.append((n, m.group(1)))
        if rel.endswith('.rst'):
            for m in RSTLINK.finditer(line):
                out.append((n, m.group(1)))
    return out


def resolve_target(ctx, rel, target):
    """-> (status, dest, frag, detail). status ok/MISS/CHECK/ext/skip:<prec>."""
    t = target.strip()
    if not t or t.startswith(('{{', '{%', '${', '<', '%7B')):
        return 'skip:§6', None, '', ''
    if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', t) or t.startswith('//'):
        return 'ext', None, '', ''
    path, _, frag = t.partition('#')
    path = unquote(path.split('?')[0])
    if re.search(r'[{}$*]|\.\.\.', path):
        return 'skip:§6', None, '', ''
    name, info, rroot = renderer_for(ctx, rel)
    if not path:
        return 'ok', rel, frag, ''
    cands = []
    if path.startswith('/'):
        p = path.lstrip('/')
        cands = [p] + ([os.path.normpath(os.path.join(rroot, p))] if rroot else []) + \
                [os.path.normpath(os.path.join(s, p)) for s in ('static', 'public') if s in ctx.dirs]
    else:
        cands = [os.path.normpath(os.path.join(os.path.dirname(rel), path))]
    for c in cands:
        if c.startswith('..'):
            return 'CHECK', None, frag, 'resolves outside the repo'
        variants = [c]
        if name != 'github' or rel.endswith('.mdx'):
            variants += [c + '.md', c + '.mdx', c + '/index.md', c + '/README.md', c + '/index.mdx', c + '/_index.md']
            if c.endswith('.html'):
                variants += [c[:-5] + '.md', c[:-5] + '.rst', c[:-5] + '.mdx']
        if name == 'sphinx':
            variants += [c + '.rst', c + '.md']
        for v in variants:
            if exists(ctx, v.rstrip('/')):
                return 'ok', v.rstrip('/'), frag, ''
    c = cands[0].rstrip('/')
    low = ctx.lower.get(c.lower())
    if low:
        return 'CHECK', low, frag, 'case differs: %s exists (breaks on case-sensitive file systems)' % low
    if path.startswith('/') and name != 'github':
        return 'CHECK', None, frag, 'site-root link under %s: check the built route' % name
    return 'MISS', c, frag, ''


def lane_links(ctx):
    ext = 0
    misses = []
    for rel, kind in ctx.docs:
        if ctx.only_docs is not None and rel not in ctx.only_docs:
            continue
        for n, target in link_targets(ctx, rel):
            st, dest, frag, detail = resolve_target(ctx, rel, target)
            if st == 'ext':
                ext += 1
                continue
            if kind in ('adr', 'changelog') and not (dest or target).split('#')[0].endswith(DOC_EXT + ('/',)) and st != 'ok':
                skip(ctx, 'DL-1', rel, n, target, '§1')
                continue
            if st.startswith('skip'):
                skip(ctx, 'DL-1', rel, n, target, st.split(':')[1])
                continue
            if st == 'MISS':
                misses.append((rel, n, target, dest))
                continue
            if st == 'CHECK':
                add(ctx, 'CHECK', 'DL-1', rel, n, target, detail)
                continue
            ok(ctx, 'DL-1', rel, n, target)
            if frag:
                if re.match(r'^L\d+(-L?\d+)?$', frag) or not dest.endswith(DOC_EXT):
                    skip(ctx, 'DL-2', rel, n, target, '§10')
                    continue
                rname = renderer_for(ctx, dest)[0]
                anc = anchors_of(ctx, dest)
                f = unquote(frag)
                if f in anc or f.lower() in anc or f.lower().replace(' ', '-') in anc:
                    ok(ctx, 'DL-2', rel, n, target)
                elif rname == 'sphinx' or dest.endswith(('.rst', '.mdx')):
                    add(ctx, 'CHECK', 'DL-2', rel, n, target, 'anchor not among %s headings; renderer may define it' % rname)
                else:
                    near = [x for x in anc if x.startswith(f.lower()[:6])][:2]
                    add(ctx, 'MISS', 'DL-2', rel, n, target, 'no heading slug "%s" in %s (%s slugger)%s' %
                        (f, dest, rname, ('; near: ' + ', '.join(near)) if near else ''))
    ign = set(i.rstrip('/') for i in gitignored(ctx, [m[3] for m in misses if m[3]] + [m[3] + '/' for m in misses if m[3]]))
    for rel, n, target, dest in misses:
        if dest in ign:
            skip(ctx, 'DL-1', rel, n, target, '§4')
        else:
            hn = history_note(ctx, dest) if ctx.git else ''
            add(ctx, 'MISS', 'DL-1', rel, n, target, ('%s does not exist' % dest) + ('; ' + hn if hn else ''))
    ctx.notes['DL-3'] = 'N/A (offline by default: %d external links counted, not fetched; run the lychee online lane with --network)' % ext


# ----------------------------------------------------------------------------- lane: paths (DR-1)

COMMON_DIRS = set('src app apps packages libs lib cmd internal pkg scripts deploy docs config configs tests test '
                  'services service server client web api infra infrastructure tools bin public static assets '
                  'charts helm k8s kubernetes terraform migrations db database prisma ops .github'.split())
PATH_EXT = re.compile(r'\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|java|kt|rb|php|cs|dart|vue|svelte|sh|md|mdx|rst|json|ya?ml|'
                      r'toml|ini|cfg|conf|env|example|sql|prisma|graphql|proto|lock|txt|html|css|scss|tf|hcl|xml|'
                      r'gradle|kts|dockerfile|properties)$', re.I)


def path_claim(ctx, tok):
    t = tok.strip().strip('"\'')
    t = re.sub(r'[.,;:]+$', '', t)
    t = re.sub(r':\d+(:\d+)?(-\d+)?$', '', t)
    t = re.sub(r'#L\d+(-L?\d+)?$', '', t)
    if not t or len(t) > 200 or re.search(r'\s', t) or t.startswith(('http:', 'https:', '//', '~', '$', '-', '@', 'node_modules')):
        return None
    if re.search(r'[*?{}\[\]<>|$%=…,()\'"`\\]', t) or '...' in t or '//' in t:
        return None
    if t.startswith('./'):
        t = t[2:]
    if t.startswith('/'):
        if t[1:].split('/')[0] not in ctx.top:
            return None
        t = t[1:]
    if '/' not in t:
        if (t.startswith('.env') or re.match(r'^\.?[\w-]+(\.[\w-]+)*\.(md|json|ya?ml|toml|lock|sh|example|cfg|ini|conf)$', t)) \
                and not re.match(r'^(package\.json|tsconfig\.json)$', t):
            return ('bare', t)
        return None
    segs = t.rstrip('/').split('/')
    if len(segs) == 2 and segs[0].lower() in K8S_KIND and not exists(ctx, t):
        return None   # deploy/api, svc/web: a kubectl resource reference, read by DK-2
    if any(s in ('', '.', '..') for s in segs[1:]) or not all(re.match(r'^[\w.@+-]+$', s) for s in segs):
        return None
    if segs[0] in ctx.top or segs[0] in COMMON_DIRS or PATH_EXT.search(segs[-1]):
        if re.match(r'^[a-z]+/[a-z.+-]+$', t) and not PATH_EXT.search(segs[-1]) and segs[0] not in ctx.top:
            return None   # mime types, owner/repo
        return ('path', t)
    return None


def resolve_path(ctx, rel, p):
    """-> (status, detail)"""
    p = p.rstrip('/')
    if exists(ctx, p):
        return 'ok', ''
    d = os.path.dirname(rel)
    if exists(ctx, os.path.normpath(os.path.join(d, p))):
        return 'ok', 'doc dir'
    for pr in ctx.pkg_roots:
        if exists(ctx, pr + '/' + p):
            return 'ok', 'package root %s' % pr
    base = os.path.basename(p)
    hits = [x for x in ctx.by_base.get(base, []) if x == p or x.endswith('/' + p)]
    if len(hits) == 1:
        return 'ok', 'unique suffix %s' % hits[0]
    if len(hits) > 5:
        return 'pattern', '%d paths end with it: a per-module layout name (§ 3)' % len(hits)
    if len(hits) > 1:
        return 'CHECK', 'ambiguous: %d paths end with it (%s)' % (len(hits), ', '.join(sorted(hits)[:3]))
    low = ctx.lower.get(p.lower())
    if low:
        return 'CHECK', 'case differs: %s' % low
    return 'MISS', ''


def lane_paths(ctx):
    pending = []
    for rel in ctx.claim_docs:
        for n, line, st, lang, info in doc_lines(ctx, rel):
            toks = []
            if st == 'text':
                toks = inline_spans(line)
            elif st == 'code' and lang in SHELL_LANGS:
                for m in re.finditer(r'(?:^|\s)(?:-f|--file|--env-file|-c|--config|cat|source|\.|bash|sh|python3?|node|tsx|'
                                     r'ts-node|deno run|bun|kubectl apply -f|helm (?:install|upgrade) \S+)\s+(\S+)', line):
                    toks.append(m.group(1))
            for tok in toks:
                c = path_claim(ctx, tok)
                if not c:
                    continue
                kind, p = c
                if kind == 'bare':
                    if ctx.by_base.get(p) or exists(ctx, p):
                        ok(ctx, 'DR-1', rel, n, p)
                    else:
                        pending.append((rel, n, p, line, 'bare'))
                    continue
                if re.search(r'(?i)auto-?populated by|generated by', line) and p.startswith('scripts/'):
                    skip(ctx, 'DR-1', rel, n, p, '§20')
                    continue
                stt, det = resolve_path(ctx, rel, p)
                if stt == 'pattern':
                    skip(ctx, 'DR-1', rel, n, p, '§3')
                elif re.search(r'(^|/)(dist|build|out|coverage|target|\.next|\.turbo|node_modules)(/|$)', p) and stt != 'ok':
                    skip(ctx, 'DR-1', rel, n, p, '§4')
                elif stt == 'ok':
                    ok(ctx, 'DR-1', rel, n, p, det)
                elif stt == 'CHECK':
                    add(ctx, 'CHECK', 'DR-1', rel, n, p, det)
                else:
                    pending.append((rel, n, p, line, 'path'))
    probe = []
    for x in pending:
        for q in (x[2], os.path.normpath(os.path.join(os.path.dirname(x[0]), x[2]))):
            probe += [q.rstrip('/'), q.rstrip('/') + '/']
    ign = set(i.rstrip('/') for i in gitignored(ctx, probe))
    for rel, n, p, line, kind in pending:
        if p.rstrip('/') in ign or os.path.normpath(os.path.join(os.path.dirname(rel), p)) in ign:
            skip(ctx, 'DR-1', rel, n, p, '§4')
        elif re.search(r'(?i)\b(generat\w*|creat\w*|writ\w*|output\w*|produc\w*|will be|is written|appears)\b', line):
            add(ctx, 'CHECK', 'DR-1', rel, n, p, 'missing, but the line says a command produces it (§ 5): is the producer still there?')
        elif kind == 'bare':
            add(ctx, 'CHECK', 'DR-1', rel, n, p, 'no file with this name anywhere in the tree')
        else:
            add(ctx, 'MISS', 'DR-1', rel, n, p, 'not under the root, the doc dir, %d package roots or as a unique suffix%s' %
                (len(ctx.pkg_roots), ('; ' + history_note(ctx, p)) if ctx.git and history_note(ctx, p) else ''))


# ----------------------------------------------------------------------------- source identifiers (DR-2, DR-5)

def source_idents(ctx):
    if hasattr(ctx, 'idents'):
        return
    ctx.idents = set()
    ctx.deprecated = {}
    dep = re.compile(r'(@deprecated\b|#\[deprecated|//\s*Deprecated:|@Deprecated\b|DeprecationWarning|'
                     r'warnings\.deprecated|@typing_extensions\.deprecated|\[Obsolete)')
    for f in sorted(ctx.files):
        if f.endswith(('.yml', '.yaml', '.json', '.toml', '.tf', '.hcl', '.proto', '.graphql', '.prisma', '.sql')) and \
                not f.endswith(('package-lock.json', 'pnpm-lock.yaml', 'yarn.lock')) and not TOOL_DIR.match(f):
            ctx.idents.update(re.findall(r'[A-Za-z_$][\w$]*', read(ctx, f)))
    for f in code_files(ctx):
        t = read(ctx, f)
        ctx.idents.update(re.findall(r'[A-Za-z_$][\w$]*', t))
        if dep.search(t):
            lines = t.split('\n')
            for i, l in enumerate(lines):
                if not dep.search(l):
                    continue
                done = False
                for j in range(i, min(i + 8, len(lines))):
                    if j == i and l.strip().startswith(('//', '*', '/*', '#', '@', '[')):
                        continue
                    body = re.sub(r'^\s*(?:(?:export|default|public|private|protected|internal|static|async|abstract|override|readonly|final|'
                                  r'pub(?:\([^)]*\))?|function\*?|class|interface|type|enum|const|let|var|def|func|fn|struct|trait|val|'
                                  r'object|unsafe|extern|open|data|sealed|suspend)\s+)+', '', lines[j])
                    m1 = re.match(r'^(?:\([^)]*\)\s*)?([A-Za-z_$][\w$]*)\s*[(<:={]', body) if body != lines[j] else None
                    names = [m1.group(1)] if m1 else []
                    m2 = re.match(r'^\s*(?:readonly\s+)?([A-Za-z_$][\w$]*)\s*[(?:]', lines[j])
                    if m2:
                        names.append(m2.group(1))
                    for nm in names:
                        if nm not in DECL_KW:
                            ctx.deprecated.setdefault(nm, '%s:%d' % (f, j + 1))
                            done = True
                            break
                    if done or (lines[j].strip() and not lines[j].strip().startswith(('//', '*', '/*', '#', '@', '['))):
                        break


DECL_KW = set('function class interface type enum const let var def func fn struct trait public private protected static export async val object return if readonly abstract override default new await get set'.split())
PROJECT_SHAPE = re.compile(r'[a-z0-9](Service|Controller|Module|Processor|Repository|Repo|Handler|Guard|Subscriber|Listener|'
                           r'Consumer|Producer|Job|Worker|Dto|DTO|Input|Output|Entity|Store|Provider|Factory|Adapter|Gateway|'
                           r'Resolver|Middleware|Interceptor|Pipe|Component|Page|Screen|ViewModel|UseCase|Mapper|Serializer|'
                           r'Validator|Command|Query|Policy|Scheduler|Cron|Saga|Projector|Port)$')
SYMBOL = re.compile(r'^(?:new\s+)?([A-Za-z_$][\w$]*(?:(?:\.|::|#)[A-Za-z_$][\w$]*)*)(\(\))?$')


def lane_symbols(ctx):
    source_idents(ctx)
    for rel in ctx.claim_docs:
        for n, line, st, _, _ in doc_lines(ctx, rel):
            if st != 'text':
                continue
            for tok in inline_spans(line):
                m = SYMBOL.match(tok.strip())
                if not m:
                    continue
                name, call = m.group(1), m.group(2)
                parts = re.split(r'\.|::|#', name)
                last = parts[-1]
                camel = re.match(r'^[a-z]+[A-Z]\w*$', last) or re.match(r'^[A-Z][a-z0-9]+[A-Z]\w*$', last)
                if not (call or camel or len(parts) > 1) or len(last) < 4 or last.isupper():
                    continue
                if last in ctx.deprecated and not re.search(r'(?i)deprecat|legacy|\bold\b|instead|replac|migrat|remov|sunset', line):
                    add(ctx, 'WRONG', 'DR-5', rel, n, tok, '%s is marked deprecated at %s; the doc presents it as current' % (last, ctx.deprecated[last]))
                    continue
                if last in ctx.idents:
                    ok(ctx, 'DR-2', rel, n, tok)
                    continue
                owned = (len(parts) > 1 and parts[0] in ctx.idents and parts[0][:1].isalpha() and parts[0] not in ('this', 'self')) or \
                    bool(PROJECT_SHAPE.search(last))
                if owned:
                    add(ctx, 'MISS', 'DR-2', rel, n, tok, '"%s" is defined nowhere in the source%s' %
                        (last, ' (its receiver %s is the project\'s)' % parts[0] if len(parts) > 1 and parts[0] in ctx.idents else ''))
                else:
                    skip(ctx, 'DR-2', rel, n, tok, '§9')


# ----------------------------------------------------------------------------- manifests (DR-3, DR-4)

def load_manifests(ctx):
    if hasattr(ctx, 'pkgs'):
        return
    ctx.pkgs = {}            # dir -> dict(name, scripts, deps, bins)
    for f in sorted(ctx.files):
        if os.path.basename(f) != 'package.json' or TEST_PATH.search(f):
            continue
        try:
            d = json.loads(read(ctx, f) or '{}')
        except ValueError:
            continue
        if not isinstance(d, dict):
            continue
        deps = set()
        for k in ('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'):
            if isinstance(d.get(k), dict):
                deps |= set(d[k])
        bins = d.get('bin') or {}
        if isinstance(bins, str):
            bins = {(d.get('name') or '').split('/')[-1]: bins}
        ctx.pkgs[os.path.dirname(f)] = {'name': d.get('name') or '', 'scripts': set((d.get('scripts') or {}).keys()),
                                        'script_cmds': d.get('scripts') or {}, 'deps': deps,
                                        'bins': bins if isinstance(bins, dict) else {}, 'pm': d.get('packageManager') or '',
                                        'engines': d.get('engines') or {}, 'raw': d}
    ctx.all_scripts = set()
    ctx.all_bins = set()
    for p in ctx.pkgs.values():
        ctx.all_scripts |= p['scripts']
        for dep in p['deps']:
            ctx.all_bins.add(dep.split('/')[-1])
            if dep in KNOWN_BIN:
                ctx.all_bins.add(KNOWN_BIN[dep])
        ctx.all_bins |= set(p['bins'])
    ctx.make = defaultdict(set)
    ctx.just = defaultdict(set)
    ctx.task = defaultdict(set)
    ctx.poe, ctx.composer, ctx.tox, ctx.pyscripts = set(), set(), set(), {}
    for f in sorted(ctx.files):
        b, d = os.path.basename(f), os.path.dirname(f)
        if TEST_PATH.search(f):
            continue
        if b in ('Makefile', 'makefile', 'GNUmakefile') or b.endswith('.mk'):
            t = read(ctx, f)
            for m in re.finditer(r'^([A-Za-z0-9_.%/-]+(?:\s+[A-Za-z0-9_.%/-]+)*)\s*::?(?!=)', t, re.M):
                for x in m.group(1).split():
                    ctx.make[d].add(x)
            for m in re.finditer(r'^\.PHONY\s*:\s*(.+)$', t, re.M):
                ctx.make[d] |= set(m.group(1).split())
        elif b.lower() in ('justfile', '.justfile'):
            for m in re.finditer(r'^@?([A-Za-z0-9_-]+)(?:\s+[^:\n]*)?:(?!=)', read(ctx, f), re.M):
                ctx.just[d].add(m.group(1))
        elif re.match(r'^Taskfile(\.dist)?\.ya?ml$', b):
            t = read(ctx, f)
            sec = re.search(r'^tasks:\s*\n((?:[ \t]+.*\n?|\s*\n)*)', t, re.M)
            if sec:
                ind = re.search(r'^([ \t]+)\S', sec.group(1), re.M)
                if ind:
                    for m in re.finditer(r'^%s([\w:.-]+)\s*:' % re.escape(ind.group(1)), sec.group(1), re.M):
                        ctx.task[d].add(m.group(1))
        elif b == 'pyproject.toml':
            t = read(ctx, f)
            for sec, dest in (('tool.poe.tasks', 'poe'), ('project.scripts', 'py'), ('tool.poetry.scripts', 'py')):
                m = re.search(r'^\[%s\]\s*\n(.*?)(?=^\[|\Z)' % re.escape(sec), t, re.M | re.S)
                if m:
                    for k in re.finditer(r'^\s*["\']?([\w.-]+)["\']?\s*=\s*["\']?([^"\'\n]*)', m.group(1), re.M):
                        if dest == 'poe':
                            ctx.poe.add(k.group(1))
                        else:
                            ctx.pyscripts[k.group(1)] = (d, k.group(2))
                for k in re.finditer(r'^\[%s\.([\w.-]+)\]' % re.escape(sec), t, re.M):
                    if dest == 'poe':
                        ctx.poe.add(k.group(1))
        elif b == 'composer.json':
            try:
                ctx.composer |= set((json.loads(read(ctx, f)).get('scripts') or {}).keys())
            except (ValueError, AttributeError):
                pass
        elif b == 'tox.ini':
            t = read(ctx, f)
            ctx.tox |= set(re.findall(r'^\[testenv:([^\]]+)\]', t, re.M))
            m = re.search(r'^envlist\s*=\s*(.+(?:\n\s+.+)*)', t, re.M)
            if m:
                ctx.tox |= set(x.strip() for x in re.split(r'[,\s]+', m.group(1)) if x.strip())


def pkg_for_filter(ctx, filt):
    filt = filt.strip('"\'')
    if filt.startswith('./') or filt.startswith(tuple(ctx.top)):
        p = os.path.normpath(filt.lstrip('./').rstrip('/').rstrip('...'))
        if p in ctx.pkgs:
            return [p]
    if '*' in filt or filt.startswith(('...', '!', '{', '[')):
        return None
    hits = [d for d, p in ctx.pkgs.items() if p['name'] == filt or p['name'].endswith('/' + filt) or os.path.basename(d) == filt]
    return hits or None


def split_commands(line):
    line = re.sub(r'^\s*(?:\$|>|%|PS[^>]*>|❯|➜\s+\S+)\s+', '', line)
    line = re.sub(r'\s+#\s.*$', '', line)
    return [c.strip() for c in re.split(r'\s*(?:&&|\|\||;|\|)\s*', line) if c.strip()]


def tokens(cmd):
    try:
        return shlex.split(cmd, comments=False, posix=True)
    except ValueError:
        return cmd.split()


def commands_in(ctx, rel):
    """Yield (line, cmd, cwd) for every command a reader is told to run: shell fences and code spans."""
    cwd = ''
    infence = False
    for n, line, st, lang, info in doc_lines(ctx, rel):
        if st == 'open':
            infence = lang in SHELL_LANGS
            cwd = ''
            continue
        if st == 'code' and infence:
            if re.match(r'^\s*#', line):
                continue
            for c in split_commands(line):
                t = tokens(c)
                if len(t) >= 2 and t[0] == 'cd':
                    nd = os.path.normpath(os.path.join(cwd, t[1])) if not t[1].startswith(('/', '~', '$')) else ''
                    cwd = nd if nd in ctx.dirs else ''
                    continue
                yield n, c, cwd
        elif st == 'text':
            for sp in inline_spans(line):
                if re.match(r'^(?:\$\s+)?(?:pnpm|npm|yarn|bun|npx|turbo|make|just|task|poe|composer|tox|node|tsx|ts-node|'
                            r'python3?|uv|poetry|go|cargo|bash|sh|\./)\b', sp):
                    for c in split_commands(sp):
                        yield n, c, ''


def check_script(ctx, rel, n, cmd, cwd):
    """Resolve one command against the task oracles. Returns True when it was a task claim."""
    t = tokens(cmd)
    if not t:
        return False
    while t and re.match(r'^[A-Z_][A-Z0-9_]*=', t[0]):
        t = t[1:]
    if not t:
        return False
    tool = t[0]
    if tool in ('npx', 'pnpx') and len(t) > 1 and t[1] == 'turbo':
        tool, t = 'turbo', t[1:]
    if tool in ('pnpm', 'npm', 'yarn', 'bun'):
        load_manifests(ctx)
        rest = t[1:]
        target = None
        recursive = False
        i = 0
        while i < len(rest):
            a = rest[i]
            if a in ('--filter', '-F', '-C', '--dir', '--prefix', '-w', '--workspace') and i + 1 < len(rest) and a not in ('-w',) or \
                    (tool == 'npm' and a == '-w' and i + 1 < len(rest)):
                if a in ('-C', '--dir', '--prefix'):
                    target = [os.path.normpath(os.path.join(cwd, rest[i + 1]))]
                else:
                    target = pkg_for_filter(ctx, rest[i + 1])
                i += 2
                continue
            if a.startswith('--filter='):
                target = pkg_for_filter(ctx, a.split('=', 1)[1])
                i += 1
                continue
            if a in ('-r', '--recursive', '--parallel', '-s', '--silent', '--if-present', '-w', '--workspace-root',
                     '--stream', '--aggregate-output', '--frozen-lockfile', '-y', '--yes'):
                recursive = recursive or a in ('-r', '--recursive')
                i += 1
                continue
            break
        rest = rest[i:]
        if tool == 'yarn' and rest[:1] == ['workspace'] and len(rest) >= 3:
            target = pkg_for_filter(ctx, rest[1])
            rest = rest[2:]
        if not rest:
            return False
        explicit = rest[0] in ('run', 'run-script')
        if explicit:
            rest = rest[1:]
            if not rest:
                return False
        s = rest[0]
        if s.startswith('-') or not re.match(r'^[\w:@./-]+$', s):
            return False
        if not explicit and s in PM_BUILTIN.get(tool, set()) and s not in SCRIPT_ALIAS.get(tool, set()):
            if tool in ('pnpm', 'yarn') and s in ('turbo',):
                pass
            return False
        if not explicit and tool == 'npm' and s not in SCRIPT_ALIAS['npm']:
            return False
        if tool == 'pnpm' and s == 'turbo' or (tool in ('pnpm', 'yarn', 'bun') and s == 'exec'):
            return False
        pool = None
        if target:
            pool = set()
            for d in target:
                pool |= ctx.pkgs.get(d, {}).get('scripts', set())
        elif cwd and cwd in ctx.pkgs:
            pool = ctx.pkgs[cwd]['scripts']
        if pool is not None and s in pool:
            ok(ctx, 'DR-3', rel, n, '%s %s' % (tool, s))
        elif s in ctx.all_scripts:
            root = ctx.pkgs.get('', {}).get('scripts', set())
            if pool is None and not recursive and ctx.pkgs.get('') is not None and s not in root and len(ctx.pkgs) > 1:
                where = [d for d, p in ctx.pkgs.items() if s in p['scripts']][:3]
                add(ctx, 'CHECK', 'DR-3', rel, n, '%s %s' % (tool, s), 'not a root script; defined only in %s (needs --filter or cd)' % ', '.join(where))
            elif pool is not None and s not in pool:
                add(ctx, 'WRONG', 'DR-3', rel, n, '%s %s' % (tool, s), 'the targeted package has no such script; it exists in %s' %
                    ', '.join([d or '.' for d, p in ctx.pkgs.items() if s in p['scripts']][:3]))
            else:
                ok(ctx, 'DR-3', rel, n, '%s %s' % (tool, s))
        elif not explicit and tool in ('pnpm', 'yarn', 'bun') and s in ctx.all_bins:
            ok(ctx, 'DR-3', rel, n, '%s %s' % (tool, s), 'a dependency bin')
        elif not ctx.pkgs:
            return False
        else:
            add(ctx, 'MISS', 'DR-3', rel, n, '%s %s' % (tool, s), 'no package.json script "%s" in %d manifests%s' %
                (s, len(ctx.pkgs), '; script names: ' + ', '.join(sorted(x for x in ctx.all_scripts if x[:3] == s[:3])[:4])
                 if [x for x in ctx.all_scripts if x[:3] == s[:3]] else ''))
        return True
    if tool == 'turbo':
        load_manifests(ctx)
        r = [x for x in t[1:] if not x.startswith('-')]
        if r[:1] == ['run']:
            r = r[1:]
        tj = read(ctx, 'turbo.json') if 'turbo.json' in ctx.files else ''
        for s in r[:3]:
            if s in ctx.all_scripts or re.search(r'["\']%s["\']\s*:' % re.escape(s), tj):
                ok(ctx, 'DR-3', rel, n, 'turbo ' + s)
            else:
                add(ctx, 'MISS', 'DR-3', rel, n, 'turbo ' + s, 'no workspace script or turbo.json task "%s"' % s)
        return True
    oracle = {'make': ctx.make if hasattr(ctx, 'make') else None}
    load_manifests(ctx)
    if tool in ('make', 'gmake'):
        d = cwd
        args = t[1:]
        tg = []
        i = 0
        while i < len(args):
            a = args[i]
            if a in ('-C', '--directory') and i + 1 < len(args):
                d = os.path.normpath(os.path.join(cwd, args[i + 1]))
                i += 2
                continue
            if a.startswith('-') or '=' in a:
                i += 1
                continue
            tg.append(a)
            i += 1
        if not ctx.make:
            return False
        targets = ctx.make.get(d)
        for x in tg[:4]:
            if not re.match(r'^[\w./-]+$', x):
                continue
            if targets is None:
                add(ctx, 'MISS', 'DR-3', rel, n, 'make ' + x, 'no Makefile in %s' % (d or 'the repo root'))
            elif x in targets or '%' in targets:
                ok(ctx, 'DR-3', rel, n, 'make ' + x)
            else:
                add(ctx, 'MISS', 'DR-3', rel, n, 'make ' + x, 'no target "%s" in %s' % (x, os.path.join(d, 'Makefile')))
        return True
    if tool == 'just' and ctx.just:
        recs = ctx.just.get(cwd, set()) | ctx.just.get('', set())
        for x in [a for a in t[1:] if not a.startswith('-')][:1]:
            if x in recs:
                ok(ctx, 'DR-3', rel, n, 'just ' + x)
            else:
                add(ctx, 'MISS', 'DR-3', rel, n, 'just ' + x, 'no recipe "%s" in the justfile' % x)
        return True
    if tool == 'task' and ctx.task:
        recs = ctx.task.get(cwd, set()) | ctx.task.get('', set())
        for x in [a for a in t[1:] if not a.startswith('-')][:2]:
            if x in recs:
                ok(ctx, 'DR-3', rel, n, 'task ' + x)
            else:
                add(ctx, 'MISS', 'DR-3', rel, n, 'task ' + x, 'no task "%s" in Taskfile' % x)
        return True
    if tool == 'poe' or (tool in ('poetry', 'uv') and t[1:3] in (['run', 'poe'],)):
        r = [a for a in t[1:] if not a.startswith('-') and a not in ('run', 'poe')]
        if r and ctx.poe:
            (ok if r[0] in ctx.poe else (lambda c, *a: add(c, 'MISS', *a, detail='no [tool.poe.tasks] entry')))(ctx, 'DR-3', rel, n, 'poe ' + r[0])
        return bool(r)
    if tool == 'composer' and ctx.composer:
        r = [a for a in t[1:] if not a.startswith('-')]
        if r and r[0] in ('run', 'run-script') and len(r) > 1:
            r = r[1:]
        builtin = set('install update require remove dump-autoload dumpautoload create-project init show outdated '
                      'validate diagnose self-update global config exec why depends prohibits audit fund status '
                      'archive check-platform-reqs bump licenses search suggests clear-cache list help run'.split())
        if r and r[0] not in builtin:
            (ok if r[0] in ctx.composer else (lambda c, *a: add(c, 'MISS', *a, detail='no composer.json script')))(ctx, 'DR-3', rel, n, 'composer ' + r[0])
        return bool(r)
    if tool == 'tox' and ctx.tox:
        if '-e' in t:
            for e in t[t.index('-e') + 1].split(',') if t.index('-e') + 1 < len(t) else []:
                if e in ctx.tox or re.match(r'^py\d*$', e):
                    ok(ctx, 'DR-3', rel, n, 'tox -e ' + e)
                else:
                    add(ctx, 'MISS', 'DR-3', rel, n, 'tox -e ' + e, 'no tox env "%s"' % e)
        return True
    return False


def lane_scripts(ctx):
    load_manifests(ctx)
    for rel in ctx.claim_docs + sorted(ctx.runbooks - set(ctx.claim_docs)):
        for n, cmd, cwd in commands_in(ctx, rel):
            check_script(ctx, rel, n, cmd, cwd)


# ----------------------------------------------------------------------------- lane: flags (DR-4)

THIRD_PARTY = set('kubectl helm docker docker-compose podman git gh aws gcloud az terraform tofu pulumi curl wget '
                  'psql mysql redis-cli mongo mongosh jq yq ssh scp rsync systemctl journalctl brew apt apt-get yum '
                  'dnf choco winget sudo openssl kind minikube k9s stern argocd flux vault consul nomad sentry-cli '
                  'stripe firebase vercel netlify heroku fly flyctl wrangler supabase eas expo xcrun adb gradle mvn '
                  'dotnet pip pip3 pipx conda cargo rustup go gofmt npm pnpm yarn npx bun deno tsc eslint prettier '
                  'vitest jest playwright cypress pytest ruff mypy black isort tox nox make just task poetry uv '
                  'mkdocs sphinx-build lychee markdownlint-cli2 rumdl vale oasdiff spectral redocly typedoc nest '
                  'prisma mikro-orm typeorm knex turbo nx lerna changeset semantic-release commitlint husky'.split())


def flag_tokens(t):
    out = []
    for a in t:
        m = re.match(r'^(--[a-z][a-z0-9-]*[a-z0-9])(?:=.*)?$', a)
        if m and m.group(1) not in ('--help', '--version', '--'):
            out.append(m.group(1))
    return out


def flag_in(text, flag):
    name = flag[2:]
    names = [name] + ([name[3:]] if name.startswith('no-') else [])
    for nm in names:
        snake = nm.replace('-', '_')
        camel = re.sub(r'-([a-z0-9])', lambda m: m.group(1).upper(), nm)
        if ('--' + nm) in text or re.search(r'["\'`]%s["\'`]' % re.escape(nm), text) or \
                re.search(r'\b%s\b' % re.escape(snake), text) or re.search(r'\b%s\b' % re.escape(camel), text):
            return True
    return False


def script_sources(ctx, path):
    """The script file plus the same-directory and one-hop relative imports."""
    out = [path]
    t = read(ctx, path)
    d = os.path.dirname(path)
    for m in re.finditer(r'(?:from\s+|require\(\s*|import\s*\(?\s*)["\'](\.{1,2}/[^"\']+)["\']', t):
        base = os.path.normpath(os.path.join(d, m.group(1)))
        for ext in ('', '.ts', '.js', '.mjs', '.cjs', '.py', '/index.ts', '/index.js'):
            if base + ext in ctx.files:
                out.append(base + ext)
                break
    for m in re.finditer(r'^\s*from\s+\.?([\w.]+)\s+import|^\s*import\s+([\w.]+)', t, re.M):
        mod = (m.group(1) or m.group(2)).replace('.', '/')
        for cand in (os.path.join(d, mod + '.py'), mod + '.py'):
            if cand in ctx.files:
                out.append(cand)
    return out


def lane_flags(ctx):
    load_manifests(ctx)
    bins = {}
    for d, p in ctx.pkgs.items():
        for b, f in p['bins'].items():
            if b:
                bins[b] = d
    for name, (d, target) in ctx.pyscripts.items():
        bins[name] = d
    for rel in ctx.claim_docs + sorted(ctx.runbooks - set(ctx.claim_docs)):
        for n, cmd, cwd in commands_in(ctx, rel):
            t = tokens(cmd)
            while t and re.match(r'^[A-Z_][A-Z0-9_]*=', t[0]):
                t = t[1:]
            if not t:
                continue
            flags = flag_tokens(t[1:])
            if not flags:
                continue
            src = None
            label = t[0]
            if t[0] in ('node', 'tsx', 'ts-node', 'python', 'python3', 'bash', 'sh', 'bun', 'deno') or t[0].startswith('./'):
                script = t[0] if t[0].startswith('./') else next((a for a in t[1:] if not a.startswith('-') and a != 'run'), None)
                if t[0] in ('python', 'python3') and len(t) > 2 and t[1] == '-m':
                    script = t[2].replace('.', '/') + '.py'
                if not script:
                    continue
                c = path_claim(ctx, script)
                p = os.path.normpath(os.path.join(cwd, script.lstrip('./'))) if c else None
                if p and p not in ctx.files:
                    st, det = resolve_path(ctx, rel, c[1])
                    if st == 'ok' and det.startswith(('package root', 'unique suffix', 'doc dir')):
                        cand = det.split(' ', 2)[-1] if det.startswith('unique') else None
                        p = cand if cand in ctx.files else next((pr + '/' + c[1] for pr in ctx.pkg_roots if pr + '/' + c[1] in ctx.files), None)
                if not p or p not in ctx.files:
                    continue
                src = script_sources(ctx, p)
                label = p
            elif t[0] in bins:
                d = bins[t[0]]
                src = [f for f in code_files(ctx) if f.startswith(d + '/') or not d][:400]
                label = 'bin %s (%s)' % (t[0], d or '.')
            elif t[0] == 'go' and len(t) > 2 and t[1] == 'run' and t[2].startswith('./'):
                d = os.path.normpath(os.path.join(cwd, t[2]))
                src = [f for f in ctx.files if os.path.dirname(f) == d and f.endswith('.go')]
                label = d
            else:
                if t[0] in THIRD_PARTY or re.match(r'^[a-z][\w-]*$', t[0]):
                    for fl in flags:
                        skip(ctx, 'DR-4', rel, n, '%s %s' % (t[0], fl), '§19')
                continue
            text = '\n'.join(read(ctx, f) for f in src)
            for fl in flags:
                if flag_in(text, fl):
                    ok(ctx, 'DR-4', rel, n, '%s %s' % (label, fl))
                else:
                    add(ctx, 'MISS', 'DR-4', rel, n, '%s %s' % (t[0] if t[0] in bins else label, fl),
                        'flag not declared in %s (%d file%s read)' % (label, len(src), '' if len(src) == 1 else 's'))


# ----------------------------------------------------------------------------- lane: versions (DS-2) and tools (DS-3)

RUNTIMES = [('node', r'node(?:\.js|js)?'), ('python', r'python'), ('go', r'go(?:lang)?'), ('rust', r'rust'),
            ('java', r'(?:java|jdk|openjdk)'), ('ruby', r'ruby'), ('php', r'php'), ('pnpm', r'pnpm'),
            ('yarn', r'yarn'), ('postgres', r'postgres(?:ql)?'), ('mysql', r'mysql'), ('redis', r'redis'),
            ('mongo', r'mongo(?:db)?'), ('dotnet', r'\.net'), ('deno', r'deno'), ('bun', r'bun')]
MINOR_SIG = {'python', 'go', 'ruby', 'php'}


def interval(spec):
    """'>=22.12' -> ((22,12),None); '^20 || ^22' -> [((20,),(21,)),((22,),(23,))]; '22' -> ((22,),(23,))."""
    out = []
    for part in re.split(r'\|\|', spec or ''):
        part = part.strip()
        if not part:
            continue
        lo = hi = None
        for m in re.finditer(r'(>=|>|<=|<|\^|~|=)?\s*v?(\d+(?:\.\d+){0,2})(\.x|\.\*)?', part):
            op, v = m.group(1) or '', parse_version(m.group(2))
            if op in ('>=', '>'):
                lo = v
            elif op in ('<', '<='):
                hi = v
            else:
                lo = v
                hi = (v[0] + 1,) if op in ('^', '') or m.group(3) or len(v) == 1 else (v[0], v[1] + 1)
        if lo:
            out.append((lo, hi))
    return out


def pins(ctx):
    if hasattr(ctx, 'pinset'):
        return ctx.pinset
    P = defaultdict(list)     # runtime -> [(lo, hi, source)]

    def addpin(rt, spec, src):
        for lo, hi in interval(spec):
            P[rt].append((lo, hi, src))
    for f in ('.nvmrc', '.node-version'):
        if f in ctx.files:
            v = read(ctx, f).strip().lstrip('v')
            if re.match(r'^\d', v):
                addpin('node', v.split('.')[0], f)
    if '.python-version' in ctx.files:
        v = read(ctx, '.python-version').strip().split('\n')[0]
        m = re.match(r'^(\d+\.\d+)', v)
        if m:
            P['python'].append((parse_version(m.group(1)), parse_version(m.group(1))[:1] + (parse_version(m.group(1))[1] + 1,), '.python-version'))
    if '.tool-versions' in ctx.files:
        for m in re.finditer(r'^(nodejs|python|golang|rust|java|ruby|php|pnpm|yarn)\s+(\S+)', read(ctx, '.tool-versions'), re.M):
            rt = {'nodejs': 'node', 'golang': 'go'}.get(m.group(1), m.group(1))
            v = parse_version(m.group(2))
            if v:
                P[rt].append((v[:2] if rt in MINOR_SIG else v[:1], (v[0], v[1] + 1) if rt in MINOR_SIG and len(v) > 1 else (v[0] + 1,), '.tool-versions'))
    load_manifests(ctx)
    for d, p in ctx.pkgs.items():
        src = (d + '/' if d else '') + 'package.json'
        eng = p['engines'] if isinstance(p['engines'], dict) else {}
        for k in ('node', 'pnpm', 'yarn'):
            if isinstance(eng.get(k), str):
                addpin(k, eng[k], src + ' engines.' + k)
        m = re.match(r'^(pnpm|yarn|npm|bun)@(\d+)', p['pm'] or '')
        if m:
            P[m.group(1)].append(((int(m.group(2)),), (int(m.group(2)) + 1,), src + ' packageManager'))
        vol = p['raw'].get('volta') if isinstance(p['raw'].get('volta'), dict) else {}
        if vol.get('node'):
            addpin('node', str(vol['node']).split('.')[0], src + ' volta')
    for f in sorted(ctx.files):
        b = os.path.basename(f)
        if TEST_PATH.search(f):
            continue
        if b == 'pyproject.toml':
            m = re.search(r'^requires-python\s*=\s*["\']([^"\']+)', read(ctx, f), re.M)
            if m:
                for lo, hi in interval(m.group(1)):
                    P['python'].append((lo, hi, f + ' requires-python'))
        elif b == 'go.mod':
            m = re.search(r'^go\s+(\d+\.\d+)', read(ctx, f), re.M)
            if m:
                v = parse_version(m.group(1))
                P['go'].append((v, None, f + ' go'))
        elif b in ('rust-toolchain', 'rust-toolchain.toml'):
            m = re.search(r'(\d+\.\d+)', read(ctx, f))
            if m:
                P['rust'].append((parse_version(m.group(1)), None, f))
        elif b == 'composer.json':
            m = re.search(r'"php"\s*:\s*"([^"]+)"', read(ctx, f))
            if m:
                for lo, hi in interval(m.group(1)):
                    P['php'].append((lo, hi, f + ' require.php'))
        elif b in ('.ruby-version',):
            v = parse_version(read(ctx, f))
            if v:
                P['ruby'].append((v[:2], (v[0], v[1] + 1) if len(v) > 1 else None, f))
        if re.search(r'(^|/)(Dockerfile[^/]*|[^/]*\.dockerfile|docker-compose[^/]*\.ya?ml|compose[^/]*\.ya?ml)$', f) or \
                (f.startswith('.github/workflows/') and f.endswith(('.yml', '.yaml'))):
            t = read(ctx, f)
            for m in re.finditer(r'(?:FROM|image:)\s+["\']?(?:[\w.-]+/)*(node|python|golang|rust|ruby|php|postgres|postgis|mysql|mariadb|redis|mongo|bitnami/postgresql)[:@](\d+(?:\.\d+)?)', t):
                rt = {'golang': 'go', 'postgis': 'postgres', 'bitnami/postgresql': 'postgres', 'mariadb': 'mysql'}.get(m.group(1), m.group(1))
                v = parse_version(m.group(2))
                if rt == 'postgres' and m.group(1) == 'postgis':
                    continue
                P[rt].append((v[:2] if rt in MINOR_SIG else v[:1], None if rt in ('postgres', 'mysql', 'redis', 'mongo') and False else
                              ((v[0], v[1] + 1) if rt in MINOR_SIG and len(v) > 1 else (v[0] + 1,)), f))
            for m in re.finditer(r'(node|python|go)-version:\s*\[?([^\]\n]+)', t):
                rt = m.group(1)
                for v in re.findall(r'["\']?(\d+(?:\.\d+)?)', m.group(2)):
                    pv = parse_version(v)
                    P[rt].append((pv[:2] if rt in MINOR_SIG else pv[:1], (pv[0], pv[1] + 1) if rt in MINOR_SIG and len(pv) > 1 else (pv[0] + 1,), f + ' CI'))
    ctx.pinset = P
    return P


def admits(pinlist, v):
    for lo, hi, src in pinlist:
        if tuple(v[:len(lo)]) >= lo and (hi is None or tuple(v[:len(hi)]) < hi):
            return True
    return False


def lane_versions(ctx):
    P = pins(ctx)
    pat = re.compile(r'(?<![\w/@.-])(%s)(?:\s*(?:v(?:ersion)?\s*)?(>=|≥|=>|\^|~|>)\s*|\s+v?|\s*v(?:ersion)?\s*)v?(\d{1,2}(?:\.\d{1,2})?)(?:\.\d+)?'
                     r'(\.x|\+|\s+or\s+(?:later|newer|higher|above)|\s+and\s+(?:up|above|later))?(?![\w.]*[/@-]\w)' %
                     '|'.join(p for _, p in RUNTIMES), re.I)
    names = [n for n, _ in RUNTIMES]
    for rel in ctx.claim_docs:
        for n, line, st, lang, info in doc_lines(ctx, rel):
            if st not in ('text', 'code') or (st == 'code' and lang not in ('', 'text', 'txt')):
                continue
            if re.search(r'(?i)\b(upgrad\w*|migrat\w*|previous|deprecated|EOL|end[- ]of[- ]life|dropped|no longer|used to|was)\b', line):
                continue
            for m in pat.finditer(line):
                word = m.group(1).lower()
                rt = next(nm for nm, p in RUNTIMES if re.fullmatch(p, word, re.I))
                v = parse_version(m.group(3))
                if rt not in P or not P[rt]:
                    skip(ctx, 'DS-2', rel, n, m.group(0).strip(), 'no-pin')
                    continue
                if rt == 'java' and v[0] < 8:
                    continue
                claim = m.group(0).strip()
                plus = bool(m.group(2) or m.group(4))
                sig = v[:2] if rt in MINOR_SIG and len(v) > 1 else v[:1]
                pl = P[rt]
                srcs = sorted(set(s for _, _, s in pl))[:3]
                if admits(pl, sig) or (plus and any(lo[:len(sig)] >= sig and (hi is None or True) and not
                                                    any(tuple(sig) < l2[:len(sig)] for l2, _, _ in pl if l2 > lo) for lo, hi, _ in pl) and False):
                    ok(ctx, 'DS-2', rel, n, claim)
                    continue
                if plus and admits(pl, tuple(x + 0 for x in sig)) is False and all(lo[:len(sig)] > tuple(sig) for lo, _, _ in pl):
                    add(ctx, 'WRONG', 'DS-2', rel, n, claim, 'the doc admits %s %s but every pin starts higher (%s)' %
                        (rt, '.'.join(map(str, sig)), '; '.join(srcs)))
                elif plus and any(admits([(lo, hi, s)], lo) and lo[:len(sig)] >= tuple(sig) for lo, hi, s in pl):
                    ok(ctx, 'DS-2', rel, n, claim, 'range includes the pin')
                else:
                    add(ctx, 'WRONG', 'DS-2', rel, n, claim, '%s %s is outside every pin (%s)' % (rt, '.'.join(map(str, sig)), '; '.join(srcs)))


def lane_tools(ctx):
    locks = {'pnpm': 'pnpm-lock.yaml', 'yarn': 'yarn.lock', 'npm': 'package-lock.json', 'bun': ('bun.lockb', 'bun.lock')}
    have = [pm for pm, f in locks.items() if any(x in ctx.files for x in ((f,) if isinstance(f, str) else f))]
    load_manifests(ctx)
    m = re.match(r'^(pnpm|yarn|npm|bun)@', ctx.pkgs.get('', {}).get('pm', '') or '')
    pm = m.group(1) if m else (have[0] if len(have) == 1 else None)
    py = 'uv' if 'uv.lock' in ctx.files else ('poetry' if 'poetry.lock' in ctx.files else None)
    if not pm and not py:
        ctx.notes['DS-3'] = 'N/A (no lockfile or packageManager pin)'
        return
    for rel in ctx.claim_docs:
        for n, cmd, cwd in commands_in(ctx, rel):
            t = tokens(cmd)
            if not t:
                continue
            if pm and t[0] in ('npm', 'yarn', 'pnpm', 'bun') and t[0] != pm:
                rest = [a for a in t[1:] if not a.startswith('-')]
                act = rest[0] if rest else ('install' if t[0] == 'yarn' else '')
                if t[0] == 'npm' and act in ('install', 'i', 'ci') and len(rest) > 1:
                    continue      # installing a named package: consumer docs
                if t[0] == 'npm' and act in ('install', 'i') and '-g' in t:
                    continue
                if act in ('install', 'i', 'ci', 'run', 'add', '') or (act and act in ctx.all_scripts):
                    add(ctx, 'WRONG', 'DS-3', rel, n, ' '.join(t[:3]), 'the repo pins %s (%s); this command uses %s' %
                        (pm, 'packageManager' if m else '%s lockfile' % pm, t[0]))
            elif py and t[0] in ('pip', 'pip3') and t[1:2] == ['install'] and '-r' in t:
                req = t[t.index('-r') + 1] if t.index('-r') + 1 < len(t) else ''
                if req and req not in ctx.files and os.path.normpath(os.path.join(cwd, req)) not in ctx.files:
                    add(ctx, 'WRONG', 'DS-3', rel, n, ' '.join(t[:4]), '%s does not exist; the repo locks with %s' % (req, py))
            elif t[0] == 'docker-compose':
                add(ctx, 'CHECK', 'DS-3', rel, n, 'docker-compose', 'Compose v1 binary; v2 is `docker compose` (does the reader have v1?)')


# ----------------------------------------------------------------------------- lane: env (DE-1, DE-2, DE-3)

ENVTOK = re.compile(r'(?<![\w.])\$?\{?([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\}?(?![\w(])')
ENVREAD = re.compile(r'process\.env\.([A-Z]\w+)|process\.env\[\s*["\']([A-Z]\w+)|import\.meta\.env\.([A-Z]\w+)|'
                     r'Deno\.env\.get\(\s*["\']([A-Z]\w+)|os\.(?:getenv|environ\.get)\(\s*["\']([A-Z]\w+)|'
                     r'os\.environ\[\s*["\']([A-Z]\w+)|\bgetenv\(\s*["\']([A-Z]\w+)|\benv\(\s*["\']([A-Z]\w+)|'
                     r'ENV(?:\.fetch\(|\[)\s*["\']([A-Z]\w+)|System\.getenv\(\s*"([A-Z]\w+)|os\.Getenv\(\s*"([A-Z]\w+)|'
                     r'os\.LookupEnv\(\s*"([A-Z]\w+)|env::var\(\s*"([A-Z]\w+)|GetEnvironmentVariable\(\s*"([A-Z]\w+)|'
                     r'(?:configService|config|cfg|this\.config)\.(?:get|getOrThrow)(?:<[^>]*>)?\(\s*["\']([A-Z]\w+)|'
                     r'\$\{([A-Z][A-Z0-9_]+)(?::[^}]*)?\}|\benv\.([A-Z][A-Z0-9_]+)\b|\b(?:str|num|bool|port|url|host|email|json)\(\s*\)|'
                     r'envconfig:"([A-Z]\w+)"|__ENV\.([A-Z]\w+)|Field\([^)]*(?:alias|validation_alias)\s*=\s*["\']([A-Z]\w+)')
SCHEMA_KEY = re.compile(r'^\s*["\']?([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)["\']?\s*:\s*(z\.|Joi\.|joi\.|str\(|num\(|bool\(|port\(|url\(|'
                        r'host\(|email\(|json\(|envalid\.|v\.|t\.|yup\.|S\.|Type\.|type\(|string\(|number\(|boolean\(|'
                        r'wholeNumber\(|\w+Schema\b)(.*)$')


def env_oracle(ctx):
    if hasattr(ctx, 'env_read'):
        return
    ctx.env_read, ctx.env_example, ctx.env_deploy, ctx.env_mention = {}, {}, {}, set()
    ctx.env_schema = {}   # name -> dict(required, default, enum, at)
    for f in sorted(ctx.files):
        b = os.path.basename(f)
        if b.startswith('.env') and re.search(r'example|sample|template|defaults|dist|tmpl', b) or \
                re.match(r'^(env|dotenv)[.-](example|sample|template)', b) or b.endswith('.env.example'):
            for i, line in enumerate(read(ctx, f).split('\n'), 1):
                m = re.match(r'^\s*#?\s*(?:export\s+)?([A-Z][A-Z0-9_]+)\s*=', line)
                if m:
                    ctx.env_example.setdefault(m.group(1), '%s:%d' % (f, i))
    for f in code_files(ctx, tests=True):
        t = read(ctx, f)
        for m in ENVREAD.finditer(t):
            g = next((x for x in m.groups() if x), None)
            if g:
                ctx.env_read.setdefault(g, f)
        if re.search(r'z\.object|cleanEnv|createEnv|BaseSettings|Joi\.object|envalid|envSchema|registerAs|EnvSchema', t):
            lines = t.split('\n')
            for i, line in enumerate(lines):
                m = SCHEMA_KEY.match(line)
                if m:
                    chain = m.group(3)
                    j = i + 1
                    while j < len(lines) and j < i + 6 and re.match(r'^\s*\.', lines[j]):
                        chain += lines[j].strip()
                        j += 1
                    dm = re.search(r'\.default\(\s*([^)]*?)\s*\)|default:\s*([^,}]+)', chain)
                    em = re.search(r'z\.enum\(\s*\[([^\]]*)\]|choices:\s*\[([^\]]*)\]|\.valid\(([^)]*)\)', m.group(2) + chain)
                    req = not re.search(r'\.optional\(|\.default\(|default:|\.catch\(|\.nullish\(|devDefault', chain)
                    ctx.env_schema[m.group(1)] = {
                        'required': req, 'default': (dm.group(1) or dm.group(2)).strip().strip('"\'`') if dm else None,
                        'enum': [x.strip().strip('"\'`') for x in (em.group(1) or em.group(2) or em.group(3)).split(',') if x.strip()] if em else None,
                        'at': '%s:%d' % (f, i + 1)}
                    ctx.env_read.setdefault(m.group(1), f)
            if 'BaseSettings' in t:
                pref = re.search(r'env_prefix\s*=\s*["\'](\w*)["\']', t)
                pre = pref.group(1).upper() if pref else ''
                for i, line in enumerate(lines):
                    m = re.match(r'^    ([a-z][a-z0-9_]+)\s*:\s*([\w\[\], .|]+?)\s*(?:=\s*(.+))?$', line)
                    if m:
                        name = pre + m.group(1).upper()
                        lit = re.match(r'Literal\[(.+)\]', m.group(2))
                        dflt = m.group(3).strip().strip('"\'') if m.group(3) and not m.group(3).startswith('Field(') else None
                        ctx.env_schema[name] = {'required': m.group(3) is None, 'default': dflt,
                                                'enum': [x.strip().strip('"\'') for x in lit.group(1).split(',')] if lit else None,
                                                'at': '%s:%d' % (f, i + 1)}
                        ctx.env_read.setdefault(name, f)
    for f in sorted(ctx.files):
        if f.endswith(('.yml', '.yaml', '.toml', '.tf', '.hcl', '.json')) or re.search(r'(^|/)(Dockerfile[^/]*|Procfile|Makefile|[^/]*\.sh)$', f):
            if TEST_PATH.search(f) or f.endswith(('package-lock.json', 'pnpm-lock.yaml')) or f.endswith(DOC_EXT):
                continue
            t = read(ctx, f)
            for m in re.finditer(r'\b([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\b', t):
                ctx.env_deploy.setdefault(m.group(1), f)
    ctx.env_const = set()
    for f in code_files(ctx, tests=True):
        t = read(ctx, f)
        ctx.env_mention.update(re.findall(r'\b([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\b', t))
        ctx.env_const.update(re.findall(r'(?:\b(?:const|let|var|final|static|val|readonly)\s+(?:[\w<>]+\s+)?|^\s*|#define\s+)([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\s*(?::\s*[\w<>\[\]]+\s*)?=(?!=)', t, re.M))
        ctx.env_const.update(re.findall(r'^\s*([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\s*,?\s*$|\benum\b[^{]*\{[^}]*\b([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\b', t, re.M) and [])


def lane_env(ctx):
    env_oracle(ctx)
    documented = set()
    for rel in ctx.claim_docs + sorted(ctx.runbooks - set(ctx.claim_docs)):
        table_env = False
        cols = []
        for n, line, st, lang, info in doc_lines(ctx, rel):
            if st == 'text' and line.lstrip().startswith('|'):
                cells = [c.strip().lower() for c in line.strip().strip('|').split('|')]
                if any(re.search(r'\b(variable|env|environment|name|key|setting)\b', c) for c in cells) and not table_env \
                        and not re.search(r'[A-Z]_[A-Z]', line):
                    table_env, cols = True, cells
                    continue
            elif st == 'text' and not line.strip():
                table_env = False
            ctx_ok = table_env or re.search(r'(?i)\benv\b|\.env|environment|variable|\bexport\s|\bset\s|\bsecret|config(?:ure|uration)?\b', line)
            toks = []
            if st == 'text':
                for sp in inline_spans(line):
                    m = re.match(r'^\$?\{?([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\}?(?:=.*)?$', sp)
                    if m:
                        toks.append(m.group(1))
                if table_env and line.lstrip().startswith('|'):
                    first = line.strip().strip('|').split('|')[0]
                    m = re.match(r'^\s*`?([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)`?\s*$', first)
                    if m and m.group(1) not in toks:
                        toks.append(m.group(1))
            elif st == 'code' and lang in SHELL_LANGS | {'env', 'dotenv', 'properties', 'ini'}:
                m = re.match(r'^\s*(?:export\s+|set\s+|\$env:)?([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\s*=', line)
                if m:
                    toks.append(m.group(1))
                    ctx_ok = True
            if not toks or not ctx_ok:
                continue
            for v in sorted(set(toks), key=toks.index):
                documented.add(v)
                if PLATFORM_ENV.match(v):
                    skip(ctx, 'DE-1', rel, n, v, '§8')
                    continue
                where = ctx.env_read.get(v)
                if where:
                    ok(ctx, 'DE-1', rel, n, v, 'read in ' + where)
                    sch = ctx.env_schema.get(v)
                    if sch and st == 'text':
                        dflt = None
                        if table_env and cols:
                            cells = [c.strip() for c in line.strip().strip('|').split('|')]
                            for ci, h in enumerate(cols):
                                if 'default' in h and ci < len(cells):
                                    dflt = cells[ci].strip('` ')
                        mm = re.search(r'(?i)default(?:s)?(?:\s+(?:is|to|value(?: is)?))?\s*[:=]?\s*`([^`]+)`', line)
                        if mm:
                            dflt = mm.group(1)
                        if dflt and dflt not in ('-', '—', '', 'none', 'n/a') and sch['default'] is not None and \
                                dflt.strip('"\'').lower() != sch['default'].lower():
                            add(ctx, 'WRONG', 'DE-3', rel, n, '%s default %s' % (v, dflt), 'schema default is %s (%s)' % (sch['default'], sch['at']))
                        if sch['enum']:
                            after = line.split(v, 1)[1] if v in line else line
                            vals = [x for x in re.findall(r'`([a-z][\w.-]*)`', after.split('. ')[0])]
                            if vals and set(vals) & set(sch['enum']) and set(vals) - set(sch['enum']):
                                add(ctx, 'WRONG', 'DE-3', rel, n, '%s values %s' % (v, '|'.join(vals)),
                                    'schema allows %s (%s)' % ('|'.join(sch['enum']), sch['at']))
                elif v in ctx.env_example:
                    add(ctx, 'CHECK', 'DE-1', rel, n, v, 'in %s but no code reads it (env-diff owns the example file)' % ctx.env_example[v])
                elif v in ctx.env_deploy:
                    ok(ctx, 'DE-1', rel, n, v, 'set in ' + ctx.env_deploy[v])
                elif v in ctx.env_const:
                    skip(ctx, 'DE-1', rel, n, v, '§9')
                elif v in ctx.env_mention:
                    add(ctx, 'CHECK', 'DE-1', rel, n, v, 'named in code but not read as an env var (constant? § 9)')
                else:
                    add(ctx, 'MISS', 'DE-1', rel, n, v, 'nothing reads it: no env read, schema, .env example or deploy file names it')
    for v, sch in sorted(ctx.env_schema.items()):
        if sch['required'] and v not in documented and v not in ctx.env_example and not PLATFORM_ENV.match(v):
            mentioned = any(v in read(ctx, d) for d, _ in ctx.docs)
            if not mentioned:
                at_f, _, at_n = sch['at'].rpartition(':')
                add(ctx, 'MISS', 'DE-2', at_f, int(at_n) if at_n.isdigit() else 0, v,
                    'required by %s, no default, in no doc and no .env example (env-diff corroborates the example half)' % sch['at'],
                    surface='primary')
    if not ctx.env_read and not ctx.env_schema:
        ctx.notes['DE-1'] = 'N/A (no env read or schema found in code)'


# ----------------------------------------------------------------------------- lane: endpoints (DA-1) and spec examples (DA-2)

def norm_route(p):
    p = re.sub(r'\{[^}]+\}|:[A-Za-z_]\w*|<[^>]+>|\[[^\]]+\]|\*', '{}', p.split('?')[0])
    p = re.sub(r'/+', '/', '/' + p.strip('/'))
    return p.rstrip('/') or '/'


def load_specs(ctx):
    if hasattr(ctx, 'spec_ops'):
        return
    ctx.spec_ops, ctx.spec_files, ctx.spec_docs, ctx.spec_deprecated = defaultdict(set), [], [], set()
    for f in sorted(ctx.files):
        if TEST_PATH.search(f) or not re.search(r'(openapi|swagger|api-spec|api)[^/]*\.(json|ya?ml)$', f, re.I):
            continue
        t = read(ctx, f)
        if not re.search(r'["\']?(openapi|swagger)["\']?\s*:', t[:4000]):
            continue
        ctx.spec_files.append(f)
        if f.endswith('.json'):
            try:
                d = json.loads(t)
            except ValueError:
                continue
            ctx.spec_docs.append((f, d))
            base = ''
            for s in d.get('servers') or []:
                m = re.match(r'^(?:https?://[^/]+)?(/[^\s]*)', s.get('url', '') if isinstance(s, dict) else '')
                if m:
                    base = m.group(1).rstrip('/')
            for p, ops in (d.get('paths') or {}).items():
                if not isinstance(ops, dict):
                    continue
                for meth, op in ops.items():
                    if meth.lower() in ('get', 'post', 'put', 'patch', 'delete', 'head', 'options'):
                        ctx.spec_ops[norm_route(p)].add(meth.upper())
                        if base:
                            ctx.spec_ops[norm_route(base + p)].add(meth.upper())
                        if isinstance(op, dict) and op.get('deprecated'):
                            ctx.spec_deprecated.add((meth.upper(), norm_route(p)))
        else:
            m = re.search(r'^paths:\s*\n(.*?)(?=^\S|\Z)', t, re.M | re.S)
            if m:
                cur = None
                for line in m.group(1).split('\n'):
                    pm = re.match(r'^  ["\']?(/[^"\':]*)["\']?\s*:', line)
                    if pm:
                        cur = norm_route(pm.group(1))
                        ctx.spec_ops[cur]
                        continue
                    mm = re.match(r'^    (get|post|put|patch|delete|head|options)\s*:', line)
                    if mm and cur:
                        ctx.spec_ops[cur].add(mm.group(1).upper())


def load_router(ctx):
    if hasattr(ctx, 'routes'):
        return
    ctx.routes = defaultdict(set)
    ctx.prefixes = set(['/api'])
    for f in code_files(ctx, exts=('.ts', '.js', '.mjs', '.py', '.go', '.java', '.kt', '.php', '.rb', '.cs')):
        t = read(ctx, f)
        for m in re.finditer(r'setGlobalPrefix\(\s*["\'`]([^"\'`]+)', t):
            ctx.prefixes.add('/' + m.group(1).strip('/'))
        cm = re.search(r'@Controller\(\s*(?:\{[^}]*path\s*:\s*)?["\'`]([^"\'`]*)', t)
        ctl = cm.group(1) if cm else ''
        for m in re.finditer(r'@(Get|Post|Put|Patch|Delete|Head|Options|All)\(\s*(?:["\'`]([^"\'`]*)["\'`])?\s*\)', t):
            ctx.routes[norm_route(ctl + '/' + (m.group(2) or ''))].add(m.group(1).upper())
        rp = re.search(r'APIRouter\([^)]*prefix\s*=\s*["\']([^"\']+)', t)
        for m in re.finditer(r'@(?:app|router|api|bp|blueprint|\w+_router)\.(get|post|put|patch|delete|route|api_route)\(\s*["\']([^"\']+)', t):
            ctx.routes[norm_route((rp.group(1) if rp else '') + m.group(2))].add(m.group(1).upper())
        for m in re.finditer(r'\b(?:app|router|server|fastify|api|r|e|g|mux|routes?)\.(get|post|put|patch|delete|GET|POST|PUT|PATCH|DELETE|Get|Post|Put|Patch|Delete|HandleFunc|Handle|route)\(\s*["\'`](/[^"\'`]*)', t):
            ctx.routes[norm_route(m.group(2))].add(m.group(1).upper())
        cr = re.search(r'@RequestMapping\(\s*(?:value\s*=\s*|path\s*=\s*)?["\']([^"\']*)', t)
        for m in re.finditer(r'@(Get|Post|Put|Patch|Delete|Request)Mapping\(\s*(?:value\s*=\s*|path\s*=\s*)?["\']([^"\']*)', t):
            ctx.routes[norm_route((cr.group(1) if cr and m.group(1) != 'Request' else '') + '/' + m.group(2))].add(m.group(1).upper())
        for m in re.finditer(r'Route::(get|post|put|patch|delete|any|match)\(\s*["\']([^"\']+)', t):
            ctx.routes[norm_route(m.group(2))].add(m.group(1).upper())


def route_known(ctx, method, path):
    """-> (source, method_ok, methods, exact) or None. Exact matches first (spec, then router); a router
    suffix match (the doc path ends with a mounted route of >= 2 static segments) is never exact."""
    cands = [path]
    for pre in sorted(ctx.prefixes, key=len, reverse=True):
        if path.startswith(pre + '/'):
            cands.append(path[len(pre):])
        m = re.match(r'^(%s)?/v\d+(/.*)$' % re.escape(pre), path)
        if m:
            cands.append(m.group(2))
    for c in cands:
        if c in ctx.spec_ops:
            ms = ctx.spec_ops[c]
            return ('spec', method in ms or not ms, ms, True)
    any_ms = set()
    for c in cands:
        if c in ctx.routes:
            any_ms |= ctx.routes[c]
    if any_ms:
        return ('router', bool(any_ms & {method, 'ALL', 'ROUTE', 'HANDLEFUNC', 'HANDLE', 'REQUEST', 'API_ROUTE'}), any_ms, True)
    for c in cands:
        for r, ms in ctx.routes.items():
            if len([x for x in r.split('/') if x and x != '{}']) >= 2 and c.endswith(r):
                return ('router', bool(ms & {method, 'ALL', 'ROUTE', 'HANDLEFUNC', 'HANDLE', 'REQUEST', 'API_ROUTE'}), ms, False)
    return None


def app_ports(ctx):
    if hasattr(ctx, 'ports'):
        return ctx.ports
    ctx.ports = set()
    for f in sorted(ctx.files):
        b = os.path.basename(f)
        if TEST_PATH.search(f):
            continue
        if b.startswith('Dockerfile') or b.endswith('.dockerfile'):
            ctx.ports |= set(re.findall(r'^EXPOSE\s+(\d+)', read(ctx, f), re.M))
        elif b.startswith('.env') and 'example' in b:
            ctx.ports |= set(re.findall(r'^\s*\w*PORT\s*=\s*(\d+)', read(ctx, f), re.M))
    for f in code_files(ctx, exts=('.ts', '.js', '.mjs', '.py', '.go')):
        ctx.ports |= set(re.findall(r'\.listen\(\s*(?:[\w.]+\s*\?\?\s*|[\w.]+\s*\|\|\s*)?(\d{4,5})', read(ctx, f)))
        ctx.ports |= set(re.findall(r'\bPORT\b[^\n]{0,40}?(?:default\(|\?\?|\|\||=)\s*["\']?(\d{4,5})', read(ctx, f)))
    return ctx.ports


ILLUSTRATIVE = re.compile(r'(?i)\b(e\.g\.|for example|for instance|such as|like this|adapt|imagine|suppose|example|'
                          r'building|build a|add(?:ing)? a|create a new|new endpoint|recipe|template|hypothetical)\b')


def lane_endpoints(ctx):
    load_specs(ctx)
    load_router(ctx)
    if not ctx.spec_ops and not ctx.routes:
        ctx.notes['DA-1'] = 'N/A (no committed OpenAPI spec and no router declarations found)'
        return
    pat = re.compile(r'^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+(/[\w/{}:<>.\-\[\]*]*)')
    curl = re.compile(r'curl\b[^\n]*?(?:-X\s*(GET|POST|PUT|PATCH|DELETE)\b[^\n]*?)?["\']?(?:https?://)?(?:localhost|127\.0\.0\.1|0\.0\.0\.0|\$\{?\w+\}?|\{\{\s*\w+\s*\}\})(?::(\d+))?(/[\w/{}:.\-]*)')
    ports = app_ports(ctx)
    fwd = set()
    for rel in ctx.claim_docs:
        for n, line, st, lang, info in doc_lines(ctx, rel):
            claims = []
            if st == 'text':
                for sp in inline_spans(line):
                    m = pat.match(sp)
                    if m:
                        claims.append((m.group(1), m.group(2)))
                for m in re.finditer(r'\|\s*`?(GET|POST|PUT|PATCH|DELETE)`?\s*\|\s*`?(/[\w/{}:.\-]*)`?\s*\|', line):
                    claims.append((m.group(1), m.group(2)))
            elif st == 'code':
                m = pat.match(line.strip())
                if m and (lang in ('http', 'rest', '') or 'HTTP/' in line):
                    claims.append((m.group(1), m.group(2)))
                pf = re.search(r'port-forward\s+\S+\s+(\d+):', line)
                if pf:
                    fwd.add(pf.group(1))
                for m in curl.finditer(line):
                    if m.group(2) and ((ports and m.group(2) not in ports) or m.group(2) in fwd):
                        skip(ctx, 'DA-1', rel, n, '%s %s' % (m.group(1) or 'GET', m.group(3)), '§19')
                        continue
                    claims.append((m.group(1) or 'GET', m.group(3)))
            elif st == 'open':
                fwd = set()
            for meth, p in claims:
                q = norm_route(p)
                segs = [s for s in q.split('/') if s and s != '{}']
                if '...' in p or '…' in p:
                    skip(ctx, 'DA-1', rel, n, '%s %s' % (meth, p), '§6')
                    continue
                if not segs or all(len(s) <= 1 or s in ('foo', 'bar', 'baz', 'example', 'path', 'resource', 'x', 'items') for s in segs):
                    skip(ctx, 'DA-1', rel, n, '%s %s' % (meth, p), '§6')
                    continue
                if re.search(r'(?i)^/(metrics|health\w*|ready\w*|live\w*|ping|status)$', q):
                    skip(ctx, 'DA-1', rel, n, '%s %s' % (meth, p), '§7')
                    continue
                r = route_known(ctx, meth, q)
                claim = '%s %s' % (meth, p)
                illus = ILLUSTRATIVE.search(line)
                if r is None and illus:
                    add(ctx, 'CHECK', 'DA-1', rel, n, claim, 'not served, but the line reads as an illustration or a how-to (§ 6)')
                elif r is not None and not r[1] and (illus or not r[3]):
                    add(ctx, 'CHECK', 'DA-1', rel, n, claim, 'served by %s for %s%s' % (r[0], ','.join(sorted(r[2])), ' (suffix match only)' if not r[3] else ' (the line reads as a how-to, § 6)'))
                elif r is None:
                    near = sorted(x for x in list(ctx.spec_ops) + list(ctx.routes) if segs and segs[-1][:5] in x)[:2]
                    add(ctx, 'MISS', 'DA-1', rel, n, claim, 'no spec path%s and no router declaration matches%s' %
                        (' (' + ', '.join(ctx.spec_files[:2]) + ')' if ctx.spec_files else '', '; near: ' + ', '.join(near) if near else ''))
                elif not r[1]:
                    add(ctx, 'WRONG', 'DA-1', rel, n, claim, 'path served by %s for %s, not %s' % (r[0], ','.join(sorted(r[2])), meth))
                elif (meth, q) in ctx.spec_deprecated:
                    add(ctx, 'WRONG', 'DR-5', rel, n, claim, 'the spec marks this operation deprecated: true')
                else:
                    ok(ctx, 'DA-1', rel, n, claim, r[0])


def check_example(schema, ex, comps, depth=0):
    """Tiny JSON-Schema subset check: type, enum, required, properties, items, $ref. Returns a problem or None."""
    if depth > 12 or not isinstance(schema, dict):
        return None
    if '$ref' in schema:
        ref = schema['$ref'].split('/')[-1]
        return check_example(comps.get(ref, {}), ex, comps, depth + 1)
    for k in ('allOf',):
        for s in schema.get(k) or []:
            p = check_example(s, ex, comps, depth + 1)
            if p:
                return p
    if 'enum' in schema and ex not in schema['enum']:
        return 'value %r not in enum %s' % (ex, schema['enum'][:6])
    t = schema.get('type')
    types = {'string': str, 'integer': int, 'number': (int, float), 'boolean': bool, 'object': dict, 'array': list}
    if isinstance(t, str) and t in types:
        if (t in ('integer', 'number') and isinstance(ex, bool)) or not isinstance(ex, types[t]):
            if not (ex is None and schema.get('nullable')):
                return 'expected %s, got %s' % (t, type(ex).__name__)
    if isinstance(ex, dict):
        for r in schema.get('required') or []:
            if r not in ex:
                return 'required property "%s" missing' % r
        for k, v in ex.items():
            sub = (schema.get('properties') or {}).get(k)
            if sub:
                p = check_example(sub, v, comps, depth + 1)
                if p:
                    return '%s: %s' % (k, p)
    if isinstance(ex, list) and isinstance(schema.get('items'), dict):
        for v in ex[:20]:
            p = check_example(schema['items'], v, comps, depth + 1)
            if p:
                return '[]: ' + p
    return None


def lane_specex(ctx):
    load_specs(ctx)
    if not ctx.spec_files:
        ctx.notes['DA-2'] = 'N/A (no committed OpenAPI spec)'
        return
    if not ctx.spec_docs:
        ctx.notes['DA-2'] = 'NOT-RUN (YAML spec: run the Redocly or Spectral lane; the engine validates JSON specs only)'
        return
    for f, d in ctx.spec_docs:
        comps = (d.get('components') or {}).get('schemas') or (d.get('definitions') or {})

        def walk(node, path):
            if isinstance(node, dict):
                sch = node.get('schema')
                exs = []
                if 'example' in node:
                    exs.append(('example', node['example']))
                if isinstance(node.get('examples'), dict):
                    for k, v in node['examples'].items():
                        if isinstance(v, dict) and 'value' in v:
                            exs.append(('examples.' + k, v['value']))
                for name, ex in exs:
                    where = '%s %s' % (path, name)
                    if ex in ('string', 'example', 'test', 'foo', 'bar', 0) and not isinstance(ex, bool):
                        add(ctx, 'CHECK', 'DA-2', f, 0, where, 'placeholder example %r' % (ex,))
                    if isinstance(sch, dict):
                        p = check_example(sch, ex, comps)
                        if p:
                            add(ctx, 'WRONG', 'DA-2', f, 0, where, 'example does not validate against its schema: ' + p)
                        else:
                            ok(ctx, 'DA-2', f, 0, where)
                for k, v in node.items():
                    if k not in ('example', 'examples'):
                        walk(v, path + '/' + str(k))
            elif isinstance(node, list):
                for i, v in enumerate(node[:200]):
                    walk(v, path + '/' + str(i))
        walk(d.get('paths') or {}, '#/paths')


# ----------------------------------------------------------------------------- lane: embeds (DC-3)

def lane_embeds(ctx):
    load_manifests(ctx)
    uses_embedme = any('embedme' in p['deps'] or any('embedme' in str(c) for c in p['script_cmds'].values()) for p in ctx.pkgs.values())
    found = 0
    for rel in ctx.claim_docs:
        d = os.path.dirname(rel)
        for start, lang, info, body in fences(ctx, rel):
            m = re.search(r'\bfile=["\']?([^\s"\'#]+)(?:#L(\d+)(?:-L?(\d+))?)?', info)
            first = body[0].strip() if body else ''
            em = re.match(r'^(?://|#|<!--|--)\s*([\w./-]+\.\w+)(?:#L(\d+)(?:-L?(\d+))?)?\s*(?:-->)?$', first) if uses_embedme else None
            for mm, committed in ((m, False), (em, True)):
                if not mm:
                    continue
                found += 1
                src = os.path.normpath(os.path.join(d, mm.group(1))) if not committed else mm.group(1)
                if src not in ctx.files:
                    alt = os.path.normpath(os.path.join(d, mm.group(1)))
                    src = alt if alt in ctx.files else src
                claim = mm.group(1) + ('#L%s-L%s' % (mm.group(2), mm.group(3) or mm.group(2)) if mm.group(2) else '')
                if src not in ctx.files:
                    add(ctx, 'MISS', 'DC-3', rel, start, claim, 'embedded source file does not exist')
                    continue
                lines = read(ctx, src).split('\n')
                if mm.group(2):
                    a, b = int(mm.group(2)), int(mm.group(3) or mm.group(2))
                    if b > len(lines):
                        add(ctx, 'WRONG', 'DC-3', rel, start, claim, 'line range beyond EOF (%d lines)' % len(lines))
                        continue
                    region = lines[a - 1:b]
                else:
                    region = lines
                if committed:
                    norm = lambda xs: [x.rstrip() for x in xs if x.strip()]
                    if norm(body[1:]) != norm(region):
                        add(ctx, 'WRONG', 'DC-3', rel, start, claim, 'committed snippet differs from %s (embedme --verify would fail)' % src)
                    else:
                        ok(ctx, 'DC-3', rel, start, claim)
                else:
                    ok(ctx, 'DC-3', rel, start, claim, 'build-time import; range exists')
        for n, line, st, _, _ in doc_lines(ctx, rel):
            for m in re.finditer(r'--8<--\s*["\']([^"\']+)["\']|!!raw-loader!([^\'"\s]+)|^\s*\.\.\s+literalinclude::\s*(\S+)', line):
                found += 1
                p = m.group(1) or m.group(2) or m.group(3)
                p2 = os.path.normpath(os.path.join(d, p))
                if p2 in ctx.files or p in ctx.files or any(pr + '/' + p in ctx.files for pr in ['docs'] + ctx.pkg_roots):
                    ok(ctx, 'DC-3', rel, n, p)
                else:
                    add(ctx, 'MISS', 'DC-3', rel, n, p, 'embedded file does not exist (snippet, raw-loader or literalinclude)')
    if not found:
        ctx.notes['DC-3'] = 'N/A (no embed markers: no embedme, file=, --8<--, raw-loader or literalinclude)'


# ----------------------------------------------------------------------------- lane: changelog (DH-2) and breaking (DH-1)

CL_HEAD = re.compile(r'^#{1,3}\s+\[?(Unreleased|v?\d+\.\d+\.\d+(?:-[\w.]+)?)\]?(?:\([^)]*\))?\s*(?:[-–—]\s*|\()?\s*(\S+?)?\)?\s*$', re.I)


def changelog_sections(ctx, rel):
    secs = []
    for n, line, st, _, _ in doc_lines(ctx, rel):
        if st != 'text':
            continue
        m = CL_HEAD.match(line)
        if m:
            secs.append({'v': m.group(1), 'date': m.group(2) or '', 'line': n, 'text': []})
        elif secs:
            secs[-1]['text'].append(line)
    return secs


def generator(ctx):
    g = []
    if '.release-please-manifest.json' in ctx.files or any(re.search(r'release-please-config\.json$', f) for f in ctx.top):
        g.append('release-please')
    if '.changeset/config.json' in ctx.files:
        g.append('changesets')
    if 'cliff.toml' in ctx.files:
        g.append('git-cliff')
    if any(f.startswith('.releaserc') for f in ctx.top) or ctx.pkgs.get('', {}).get('raw', {}).get('release'):
        g.append('semantic-release')
    return g


def lane_changelog(ctx):
    load_manifests(ctx)
    cls = [d for d, k in ctx.docs if k == 'changelog' and (ctx.only_docs is None or d in ctx.only_docs)]
    if not cls:
        ctx.notes['DH-2'] = 'N/A (no CHANGELOG)'
        return
    gen = generator(ctx)
    for rel in cls:
        secs = changelog_sections(ctx, rel)
        if not secs:
            continue
        t = read(ctx, rel)
        refs = dict((m.group(1).lower(), (m.group(2), t[:m.start()].count('\n') + 1))
                    for m in re.finditer(r'^\[([^\]]+)\]:\s*(\S+)', t, re.M))
        seen = {}
        prev = None
        dated = sum(1 for s in secs if s['date'])
        for s in secs:
            v = s['v']
            if v.lower() == 'unreleased':
                if prev is not None:
                    add(ctx, 'WRONG', 'DH-2', rel, s['line'], v, '[Unreleased] is not the first section')
                continue
            key = semver_key(v)
            if v.lstrip('v') in seen:
                add(ctx, 'WRONG', 'DH-2', rel, s['line'], v, 'duplicate version (also at line %d)' % seen[v.lstrip('v')])
            seen[v.lstrip('v')] = s['line']
            if prev and key and prev[0] and key >= prev[0]:
                add(ctx, 'WRONG', 'DH-2', rel, s['line'], v, 'versions not in descending order (%s follows %s)' % (v, prev[1]))
            if key:
                prev = (key, v)
            d = s['date'].strip('()')
            if d and not re.match(r'^\d{4}-\d{2}-\d{2}$', d):
                add(ctx, 'WRONG', 'DH-2', rel, s['line'], '%s %s' % (v, d), 'date is not ISO 8601 (YYYY-MM-DD)')
            elif not d and dated * 2 > len(secs) and 'changesets' not in gen:
                add(ctx, 'MISS', 'DH-2', rel, s['line'], v, 'no release date, while %d of %d sections carry one' % (dated, len(secs)))
            if refs and '[' in t.split('\n')[s['line'] - 1] and v.lower() not in refs and v.lstrip('v').lower() not in refs:
                add(ctx, 'MISS', 'DH-2', rel, s['line'], v, 'no link reference [%s]: while other versions have compare links' % v)
        heads = set(s['v'].lower().lstrip('v') for s in secs)
        for k, (url, ln) in refs.items():
            if re.match(r'^v?\d+\.\d+\.\d+', k) and k.lstrip('v') not in heads:
                add(ctx, 'MISS', 'DH-2', rel, ln, '[%s]' % k, 'link reference for a version with no section')
        ur = refs.get('unreleased')
        rel_vs = [s['v'] for s in secs if semver_key(s['v'])]
        if ur and rel_vs:
            m = re.search(r'compare/v?([\w.\-]+?)\.\.\.', ur[0])
            if m and m.group(1).lstrip('v') != rel_vs[0].lstrip('v'):
                add(ctx, 'WRONG', 'DH-2', rel, ur[1], '[Unreleased]', 'compare base %s is not the latest release %s' % (m.group(1), rel_vs[0]))
    ctx.notes['DH-2.gen'] = 'generator: %s' % (', '.join(gen) if gen else 'none (hand-written)')


BREAK_SIGNAL = re.compile(r'(?i)\b(break(s|ing)?|remov(e|ed|es|al)|drop(s|ped)?|delet(e|ed|es)|renam(e|ed|es)|replac(e|ed|es)|'
                          r'no longer|deprecat\w*|migrat\w*|instead|must now|now requires?|incompatib\w*)\b')
BREAK_HEAD = re.compile(r'(?i)^#{2,6}\s*(breaking|removed|deprecated|migration|upgrade)')


def announced(desc, lines):
    """A breaking commit is announced when ONE line of the release section names it: at least half of the
    subject's words of four or more letters, as whole words (a trailing s ignored), at least two of them when the
    subject has two or more, and the line (or its sub-heading) carries a breaking or removal signal. A vote over the
    whole section let one unrelated bullet ('order pages load faster with fewer query params') clear 'drop the page
    param'."""
    stem = lambda w: w[:-1] if len(w) > 4 and w.endswith('s') else w
    words = set(stem(w) for w in re.findall(r'[a-z0-9_-]{4,}', desc.lower()))
    if not words:
        return False
    need = max(min(2, len(words)), (len(words) + 1) // 2)
    head_signal = False
    for line in lines:
        if BREAK_HEAD.match(line.strip()):
            head_signal = True
            continue
        if re.match(r'^#{1,6}\s', line.strip()):
            head_signal = False
            continue
        toks = set(stem(t) for t in re.findall(r'[a-z0-9_-]+', line.lower()))
        if len(words & toks) >= need and (head_signal or BREAK_SIGNAL.search(line)):
            return True
    return False


def lane_breaking(ctx):
    if not ctx.git:
        ctx.notes['DH-1'] = 'N/A (not a git repo or --no-git)'
        return
    tags = [x for x in (sh(ctx, ['tag', '--list', '--sort=-creatordate']) or '').split('\n') if re.search(r'\d+\.\d+\.\d+', x)]
    if not tags:
        ctx.notes['DH-1'] = 'N/A (no release tags: nothing has shipped to announce)'
        return
    load_manifests(ctx)
    gen = generator(ctx)
    cls = [d for d, k in ctx.docs if k == 'changelog']
    root_cl = next((c for c in cls if '/' not in c), cls[0] if cls else None)
    ranges = [(tags[0], 'HEAD', None)] + [(tags[i + 1], tags[i], tags[i]) for i in range(min(len(tags) - 1, 10))]
    for base, head, ver in ranges:
        out = sh(ctx, ['log', '--format=%h%x1f%s%x1f%b%x1e', '%s..%s' % (base, head)])
        if not out:
            continue
        for rec in out.split('\x1e'):
            parts = rec.strip().split('\x1f')
            if len(parts) < 2:
                continue
            sha, subj, body = parts[0], parts[1], parts[2] if len(parts) > 2 else ''
            if not (re.match(r'^\w+(\([^)]*\))?!:', subj) or re.search(r'(?m)^BREAKING[ -]CHANGE:', body)):
                continue
            desc = re.sub(r'^\w+(\([^)]*\))?!?:\s*', '', subj)
            claim = '%s %s' % (sha, desc[:80])
            pkg = None
            m = re.match(r'^(.+)@(\d+\.\d+\.\d+.*)$', ver or '')
            cl = root_cl
            if m:
                pkg = m.group(1)
                d = next((d for d, p in ctx.pkgs.items() if p['name'] == pkg), None)
                cl = (d + '/CHANGELOG.md') if d is not None and (d + '/CHANGELOG.md') in ctx.files else root_cl
            if not cl:
                add(ctx, 'MISS', 'DH-1', '', 0, claim, 'breaking commit in %s..%s and no CHANGELOG in the repo' % (base, head))
                continue
            if ver is None and gen:
                skip(ctx, 'DH-1', cl, 0, claim, '§17')
                continue
            secs = changelog_sections(ctx, cl)
            want = 'unreleased' if ver is None else re.sub(r'^.*@|^v', '', ver)
            sec = next((s for s in secs if s['v'].lower().lstrip('v') == want.lower()), None)
            if sec is None:
                add(ctx, 'MISS', 'DH-1', cl, 0, claim, 'breaking change in %s..%s; %s has no %s section' % (base, head, cl, want))
                continue
            text = '\n'.join(sec['text']).lower()
            hit = sha[:7] in text or announced(desc, sec['text'])
            if hit:
                ok(ctx, 'DH-1', cl, sec['line'], claim)
            else:
                add(ctx, 'MISS', 'DH-1', cl, sec['line'], claim, 'breaking commit not announced in the %s section (Keep a Changelog allows adding it, § 25)' % sec['v'])


# ----------------------------------------------------------------------------- lane: resources (DK-2)

K8S_KIND = {'deploy': 'Deployment', 'deployment': 'Deployment', 'deployments': 'Deployment', 'sts': 'StatefulSet',
            'statefulset': 'StatefulSet', 'statefulsets': 'StatefulSet', 'ds': 'DaemonSet', 'daemonset': 'DaemonSet',
            'cronjob': 'CronJob', 'cronjobs': 'CronJob', 'cj': 'CronJob', 'job': 'Job', 'jobs': 'Job', 'svc': 'Service',
            'service': 'Service', 'services': 'Service', 'cm': 'ConfigMap', 'configmap': 'ConfigMap', 'secret': 'Secret',
            'secrets': 'Secret', 'ing': 'Ingress', 'ingress': 'Ingress', 'hpa': 'HorizontalPodAutoscaler',
            'pdb': 'PodDisruptionBudget', 'ns': 'Namespace', 'namespace': 'Namespace', 'pvc': 'PersistentVolumeClaim'}


def k8s_metadata(doc):
    """name and namespace from the top-level metadata block, read line by line (no backtracking regex)."""
    out, inmeta, ind = {}, False, None
    for line in doc.split('\n'):
        if not inmeta:
            if re.match(r'^metadata:\s*$', line):
                inmeta = True
            continue
        if line.strip() == '' or line.lstrip().startswith('#'):
            continue
        lead = len(line) - len(line.lstrip())
        if lead == 0:
            break
        if ind is None:
            ind = lead
        if lead != ind:
            continue
        m = re.match(r'^\s+(name|namespace):\s*["\']?([^"\'#\n]+?)["\']?\s*(?:#.*)?$', line)
        if m:
            out.setdefault(m.group(1), m.group(2).strip())
    return out


def resource_oracle(ctx):
    if hasattr(ctx, 'k8s'):
        return
    ctx.k8s, ctx.k8s_ns, ctx.compose, ctx.alerts, ctx.helm_charts = defaultdict(set), set(), set(), set(), False
    ctx.queues, ctx.templated = set(), False
    ctx.helm_releases = set()
    for f in sorted(ctx.files):
        if f.endswith(DOC_EXT + ('.sh', '.yml', '.yaml', '.mk')) or os.path.basename(f) in ('Makefile', 'justfile', 'helmfile.yaml'):
            t = read(ctx, f)
            if 'helm' not in t:
                continue
            for m in re.finditer(r'helm\s+(?:upgrade\s+(?:--install\s+|-i\s+)?|install\s+)(?:--[\w-]+(?:[= ]\S+)?\s+)*([a-z0-9][-a-z0-9]*)\s+(?:oci://)?([\w./-]+)', t):
                ctx.helm_releases.add(m.group(1))
                ctx.helm_releases.add(m.group(2).rstrip('/').split('/')[-1])
            ctx.helm_releases |= set(x.split('/')[-1] for x in re.findall(r'^\s*chart:\s*["\']?([\w./-]+)', t, re.M))
            if os.path.basename(f).startswith('helmfile'):
                ctx.helm_releases |= set(re.findall(r'^\s*-\s*name:\s*["\']?([a-z0-9][-a-z0-9]*)', t, re.M))
    for f in sorted(ctx.files):
        if TEST_PATH.search(f):
            continue
        if f.endswith(('.yml', '.yaml')):
            t = read(ctx, f)
            if '/templates/' in f and '{{' in t:
                ctx.helm_charts = True
            if os.path.basename(f) == 'Chart.yaml':
                ctx.helm_charts = True
            if re.search(r'(^|/)(docker-)?compose[^/]*\.ya?ml$', f):
                m = re.search(r'^services:\s*\n((?:[ \t]+.*\n?|\s*\n)*)', t, re.M)
                if m:
                    ind = re.search(r'^([ \t]+)\S', m.group(1), re.M)
                    if ind:
                        ctx.compose |= set(re.findall(r'^%s([\w.-]+)\s*:' % re.escape(ind.group(1)), m.group(1), re.M))
            if 'kind:' not in t or 'metadata:' not in t:
                ctx.alerts |= set(re.findall(r'^\s*-?\s*alert:\s*["\']?([\w:.-]+)', t, re.M))
                continue
            for doc in re.split(r'^---\s*$', t, flags=re.M):
                km = re.search(r'^kind:\s*(\w+)', doc, re.M)
                meta = k8s_metadata(doc)
                if km and meta.get('name'):
                    name = meta['name']
                    if '{{' in name or '$' in name:
                        ctx.templated = True
                    ctx.k8s[km.group(1)].add(name)
                    if meta.get('namespace'):
                        ctx.k8s_ns.add(meta['namespace'])
                    if km.group(1) == 'Namespace':
                        ctx.k8s_ns.add(name)
            if re.search(r'kustomization\.ya?ml$', f) and re.search(r'^name(Prefix|Suffix):', t, re.M):
                ctx.templated = True
            ctx.alerts |= set(re.findall(r'^\s*-?\s*alert:\s*["\']?([\w:.-]+)', t, re.M))
    for f in code_files(ctx):
        t = read(ctx, f)
        ctx.queues |= set(re.findall(r'new\s+(?:Queue|Worker|QueueEvents)\(\s*["\'`]([\w.:-]+)', t))
        ctx.queues |= set(re.findall(r'@Processor\(\s*["\'`]([\w.:-]+)', t))
        ctx.queues |= set(re.findall(r'registerQueue\(\s*\{\s*name\s*:\s*["\'`]([\w.:-]+)', t))
        ctx.queues |= set(re.findall(r'\b[A-Z][A-Z0-9_]*QUEUE\w*\s*=\s*["\'`]([\w.:-]+)', t))


KUBECTL_VALUE_FLAGS = set('-n --namespace -l --selector --field-selector -o --output -c --container --context --cluster '
                          '--user --since --tail -f --filename -p --patch --type --replicas --timeout --to-revision '
                          '--from-literal --from-file --from-env-file --image --port --sort-by --template -k '
                          '--kustomize --as --kubeconfig --server --token -L --label-columns --for --from'.split())
K8S_NAME = re.compile(r'^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$')


def kubectl_claim(ctx, rel, n, t, have_k8s, created):
    args = t[1:]
    ns, pos, i = None, [], 0
    while i < len(args):
        a = args[i]
        if a in KUBECTL_VALUE_FLAGS and i + 1 < len(args):
            if a in ('-n', '--namespace'):
                ns = args[i + 1]
            i += 2
            continue
        if a.startswith('--namespace='):
            ns = a.split('=', 1)[1]
        if not a.startswith('-'):
            pos.append(a)
        i += 1
    if not pos:
        return
    verb = pos[0]
    if verb in ('create', 'run', 'apply', 'kustomize', 'diff', 'expose', 'replace', 'config', 'version', 'api-resources', 'cluster-info', 'auth', 'wait', 'cp', 'krew', 'plugin'):
        nm = pos[-1] if len(pos) >= 2 else None
        if verb == 'create' and len(pos) >= 3:
            nm = pos[3] if pos[1] in ('secret', 'configmap', 'cm', 'service', 'svc') and len(pos) >= 4 else pos[2]
        if nm and K8S_NAME.match(nm):
            created.add(nm)
        return
    rest = [a for a in pos[1:] if a not in ('restart', 'status', 'undo', 'history', 'pause', 'resume', 'image', 'env', 'resources')]
    kind = name = None
    if rest and '/' in rest[0]:
        k, _, name = rest[0].partition('/')
        kind = K8S_KIND.get(k.lower())
    elif len(rest) >= 2 and rest[0].lower() in K8S_KIND:
        kind, name = K8S_KIND[rest[0].lower()], rest[1]
    rels = ctx.helm_releases
    if ns and K8S_NAME.match(ns):
        claim = 'namespace ' + ns
        if not have_k8s:
            skip(ctx, 'DK-2', rel, n, claim, '§19')
        elif ns in ctx.k8s_ns or ns in ('default', 'kube-system', 'kube-public') or ns in rels:
            ok(ctx, 'DK-2', rel, n, claim)
        elif ctx.templated or ctx.helm_charts or rels:
            add(ctx, 'CHECK', 'DK-2', rel, n, claim, 'no plain manifest declares it; Helm or kustomize may')
        else:
            add(ctx, 'MISS', 'DK-2', rel, n, claim, 'no manifest declares this namespace')
    if not (kind and name and K8S_NAME.match(name)) or kind == 'Namespace':
        return
    claim = '%s/%s' % (kind, name)
    if not have_k8s or name in created:
        skip(ctx, 'DK-2', rel, n, claim, '§19' if not have_k8s else 'created-in-doc')
    elif name in ctx.k8s.get(kind, set()) or (kind == 'HorizontalPodAutoscaler' and name.startswith('keda-hpa-') and name[9:] in ctx.k8s.get('ScaledObject', set())):
        ok(ctx, 'DK-2', rel, n, claim)
    elif kind == 'Secret' and not ctx.k8s.get('Secret') and not ctx.k8s.get('ExternalSecret') and not ctx.k8s.get('SealedSecret'):
        skip(ctx, 'DK-2', rel, n, claim, '§19')
    elif any(len(r) > 3 and (name == r or name.startswith(r + '-') or name.endswith('-' + r) or ('-' + r + '-') in name) for r in rels):
        skip(ctx, 'DK-2', rel, n, claim, '§19')
    elif ctx.templated or ctx.helm_charts:
        add(ctx, 'CHECK', 'DK-2', rel, n, claim, 'no plain manifest names it; Helm or kustomize names are templated')
    else:
        other = sorted(ctx.k8s.get(kind, set()))[:4]
        add(ctx, 'MISS', 'DK-2', rel, n, claim, 'no %s named %s in the manifests (%s: %s)' % (kind, name, kind, ', '.join(other) or 'none'))


def lane_resources(ctx):
    resource_oracle(ctx)
    have_k8s = any(ctx.k8s.values())
    if not ctx.runbooks:
        ctx.notes['DK-2'] = 'N/A (no runbook found: by path, front matter or Rollback/Mitigation headings)'
        return
    for rel in sorted(ctx.runbooks):
        if ctx.only_docs is not None and rel not in ctx.only_docs:
            continue
        created = set()
        for n, cmd, cwd in commands_in(ctx, rel):
            t = tokens(cmd)
            if not t:
                continue
            if t[0] == 'kubectl':
                kubectl_claim(ctx, rel, n, t, have_k8s, created)
            elif t[0] in ('docker', 'docker-compose') and (t[0] == 'docker-compose' or t[1:2] == ['compose']):
                args = t[2:] if t[0] == 'docker' else t[1:]
                if not args or not ctx.compose:
                    continue
                verb = args[0]
                if verb in ('up', 'restart', 'logs', 'exec', 'stop', 'start', 'run', 'rm', 'kill', 'pull', 'build'):
                    svcs = [a for a in args[1:] if not a.startswith('-') and re.match(r'^[\w.-]+$', a)]
                    if verb in ('exec', 'run'):
                        svcs = svcs[:1]
                    for s in svcs[:3]:
                        if s in ctx.compose:
                            ok(ctx, 'DK-2', rel, n, 'compose ' + s)
                        else:
                            add(ctx, 'MISS', 'DK-2', rel, n, 'compose ' + s, 'no compose service %s (services: %s)' % (s, ', '.join(sorted(ctx.compose)[:6])))
        for n, line, st, _, _ in doc_lines(ctx, rel):
            if st != 'text':
                continue
            if ctx.alerts and re.search(r'(?i)\balert', line):
                for sp in inline_spans(line):
                    if re.match(r'^[A-Z][A-Za-z0-9]+(?:[A-Z][a-z0-9]+)+$', sp):
                        if sp in ctx.alerts:
                            ok(ctx, 'DK-2', rel, n, 'alert ' + sp)
                        else:
                            add(ctx, 'MISS', 'DK-2', rel, n, 'alert ' + sp, 'no alert rule named %s in the rule files' % sp)
            if ctx.queues and re.search(r'(?i)\bqueue', line):
                for sp in inline_spans(line):
                    if re.match(r'^[a-z][\w.:-]+$', sp) and not sp.startswith(('http', 'npm')) and '/' not in sp:
                        if sp in ctx.queues:
                            ok(ctx, 'DK-2', rel, n, 'queue ' + sp)
                        elif re.search(r'[-.:]', sp):
                            add(ctx, 'MISS', 'DK-2', rel, n, 'queue ' + sp, 'no queue declared with this name (%s)' % ', '.join(sorted(ctx.queues)[:5]))
    if not have_k8s and not ctx.compose:
        ctx.notes['DK-2.k8s'] = 'no in-repo manifests: kubectl names are UNVERIFIED (live-infra, § 19)'


# ----------------------------------------------------------------------------- lane: linksin (DK-3)

def own_repo(ctx):
    url = (sh(ctx, ['config', '--get', 'remote.origin.url']) or '').strip()
    m = re.search(r'(?:github\.com|gitlab\.com|bitbucket\.org)[:/]([^/]+/[^/.]+?)(?:\.git)?$', url)
    return m.group(1) if m else None


def lane_linksin(ctx):
    slug = own_repo(ctx)
    found = 0
    srcs = [f for f in sorted(ctx.files) if f.endswith(('.yml', '.yaml', '.json')) and not TEST_PATH.search(f)
            and not f.endswith(('package-lock.json', 'pnpm-lock.yaml'))] + list(code_files(ctx))
    for f in srcs:
        if re.search(r'(^|/)(migrations?|db/migrate|seeds?|seeders)/', f):
            continue
        t = read(ctx, f)
        if 'runbook' not in t and 'docs/' not in t and '.md' not in t:
            continue
        for m in re.finditer(r'(?:runbook_url|runbook|runbookUrl|docs_url|help_url)\s*[:=]\s*["\']?([^\s"\']+)|'
                             r'["\'`]((?:\./)?(?:docs?|runbooks?|ai/runbooks)/[\w./-]+\.mdx?(?:#[\w-]+)?)["\'`]|'
                             r'https?://(?:github\.com|gitlab\.com)/([^/\s"\']+/[^/\s"\']+)/(?:-/)?blob/[^/\s"\']+/([^\s"\'#)]+)(#[\w-]+)?', t):
            line = t[:m.start()].count('\n') + 1
            if m.group(1):
                u = m.group(1)
                bm = re.match(r'https?://(?:github\.com|gitlab\.com)/([^/]+/[^/]+)/(?:-/)?blob/[^/]+/([^#]+)(#[\w-]+)?', u)
                if bm:
                    repo, p, frag = bm.group(1), bm.group(2), (bm.group(3) or '')[1:]
                elif not re.match(r'^[a-z]+:', u) and re.search(r'\.mdx?(#|$)', u):
                    repo, p, frag = slug, u.split('#')[0].lstrip('./'), u.partition('#')[2]
                else:
                    continue
            elif m.group(2):
                repo, p, frag = slug, m.group(2).split('#')[0].lstrip('./'), m.group(2).partition('#')[2]
            else:
                repo, p, frag = m.group(3), m.group(4), (m.group(5) or '')[1:]
            if '{{' in p or '$' in p:
                continue
            if slug and repo and repo.lower() != slug.lower():
                continue
            if not slug and m.group(3):
                continue
            found += 1
            claim = p + ('#' + frag if frag else '')
            if p not in ctx.files:
                add(ctx, 'MISS', 'DK-3', f, line, claim, 'link into the docs from %s resolves to no file' % f)
            elif frag and p.endswith(DOC_EXT) and frag not in anchors_of(ctx, p) and not re.match(r'^L\d+', frag):
                add(ctx, 'MISS', 'DK-3', f, line, claim, 'file exists, anchor "%s" does not' % frag)
            else:
                ok(ctx, 'DK-3', f, line, claim)
    if not found:
        ctx.notes['DK-3'] = 'N/A (no runbook_url or in-repo doc link in code, alerts or config)'


# ----------------------------------------------------------------------------- lane: adr (DX-1, DX-2, DX-3)

def adr_status(text):
    fm = re.match(r'^---\s*\n(.*?)\n---', text, re.S)
    if fm:
        m = re.search(r'^status:\s*["\']?([^"\'\n]+)', fm.group(1), re.M | re.I)
        if m:
            return m.group(1).strip()
    for pat in (r'^\s*(?:[-*]\s*)?(?:\*\*|__)?Status(?:\*\*|__)?\s*(?::\s*(?:\*\*|__)?|\|\s*)\s*([^\n|]+)',
                r'^#{1,4}\s*Status\s*\n+\s*(?:[-*]\s*)?([^\n]+)'):
        m = re.search(pat, text, re.M | re.I)
        if m:
            return re.sub(r'[*_`]', '', m.group(1)).strip()
    return None


def adr_refs(s):
    """Ids from links or ADR-n tokens only - never a bare date (§ 26)."""
    ids = set()
    for m in re.finditer(r'\]\(([^)]*?)(\d{3,5})[-_][^)]*\)|\bADR[-_ ]?0*(\d{1,5})\b|\[0*(\d{1,5})\]\(', s):
        g = m.group(2) or m.group(3) or m.group(4)
        if g:
            ids.add(int(g))
    return ids


def lane_adr(ctx):
    adrs = defaultdict(list)
    for rel, kind in ctx.docs:
        if kind == 'adr':
            m = ADR_FILE.search(rel)
            adrs[(os.path.dirname(rel), int(m.group(1)))].append(rel)
    if not adrs:
        ctx.notes['DX-1'] = 'N/A (no ADR directory: adr/, adrs/, decisions/, architecture/decisions/)'
        return
    dirs = sorted(set(d for d, _ in adrs))
    for d in dirs:
        vocab = set(['proposed', 'accepted', 'rejected', 'deprecated', 'superseded', 'draft'])
        vsrc = None
        for tf in sorted(ctx.files):
            if (os.path.dirname(tf) == d and re.search(r'(template|0000)[^/]*\.md$', tf, re.I)) or \
                    re.search(r'(^|/)adr-template\.md$', tf):
                tt = read(ctx, tf)
                m = re.search(r'(?i)status[^\n]*?((?:proposed|accepted|draft|rejected)[^\n]*)', tt)
                life = re.search(r'(?is)status lifecycle.*?```(.*?)```', tt)
                words = set()
                if m:
                    words |= set(w.lower() for w in re.findall(r'[A-Za-z]+', m.group(1)) if len(w) > 3)
                if life:
                    words |= set(w.lower() for w in re.findall(r'^\s*([A-Z][a-z]+)\b', life.group(1), re.M))
                if words & {'proposed', 'accepted'}:
                    vocab |= words
                    vsrc = vsrc or tf
        info = {}
        for (dd, num), files in sorted(adrs.items()):
            if dd != d:
                continue
            if len(files) > 1:
                add(ctx, 'WRONG', 'DX-3', files[1], 1, '%04d' % num, 'number %04d is used by %d files: %s' % (num, len(files), ', '.join(files)))
            rel = files[0]
            t = read(ctx, rel)
            st = adr_status(t)
            first = (st or '').split()[0].lower().strip('.:,;') if st else ''
            sup_line = ' '.join(l for l in t.split('\n') if re.search(r'(?i)\bsupersed', l))
            sby = set()
            sups = set()
            partial = set()
            for l in t.split('\n'):
                if re.search(r'(?i)superseded\s+by', l):
                    sby |= adr_refs(l)
                elif re.search(r'(?i)\bsupersedes?\b|\breplaces\b', l):
                    if re.search(r'(?i)\b(clause|section|part|partially|in part|half|paragraph|amends?)\b', l):
                        partial.update(adr_refs(l))
                    else:
                        sups |= adr_refs(l)
            info[num] = {'rel': rel, 'status': st, 'first': first, 'sby': sby - {num}, 'sups': sups - {num}, 'partial': partial - {num}}
            if not st:
                add(ctx, 'MISS', 'DX-2', rel, 1, '%04d status' % num, 'no Status in any recognised form (front matter, Status:, ## Status)')
            elif first not in vocab:
                add(ctx, 'WRONG' if vsrc else 'CHECK', 'DX-2', rel, 1, '%04d status "%s"' % (num, st[:40]),
                    'status outside the vocabulary of %s (%s)' % (vsrc or 'MADR/Nygard, an open set', '|'.join(sorted(vocab))))
            tm = re.search(r'^#\s+(?:ADR[-\s]?)?0*(\d+)\b', t, re.M)
            if tm and int(tm.group(1)) != num:
                add(ctx, 'WRONG', 'DX-3', rel, 1, '%04d title %s' % (num, tm.group(1)), 'file number %04d, title number %s' % (num, tm.group(1)))
        for num, a in sorted(info.items()):
            for tgt in sorted(a['sby']):
                if tgt not in info:
                    add(ctx, 'MISS', 'DX-1', a['rel'], 1, '%04d superseded by %04d' % (num, tgt), 'target ADR %04d does not exist' % tgt)
                elif num not in info[tgt]['sups'] and num not in info[tgt]['partial']:
                    add(ctx, 'MISS', 'DX-1', info[tgt]['rel'], 1, '%04d supersedes %04d' % (tgt, num), 'one-way: %04d says superseded by %04d, %04d does not say Supersedes' % (num, tgt, tgt))
                else:
                    ok(ctx, 'DX-1', a['rel'], 1, '%04d<->%04d' % (num, tgt))
            for tgt in sorted(a['sups']):
                if tgt not in info:
                    add(ctx, 'MISS', 'DX-1', a['rel'], 1, '%04d supersedes %04d' % (num, tgt), 'superseded ADR %04d does not exist' % tgt)
                elif not info[tgt]['first'].startswith('supersed') and a['first'] in ('accepted', 'approved'):
                    add(ctx, 'WRONG', 'DX-1', info[tgt]['rel'], 1, '%04d status %s' % (tgt, info[tgt]['first'] or 'none'),
                        '%04d (accepted) supersedes it, but it still reads "%s"' % (num, info[tgt]['status']))
        idx = [f for f in (d + '/README.md', d + '/index.md', d + '/_index.md', 'ai/_decision-index.md') if f in ctx.files]
        if d != 'ai/decisions':
            idx = [f for f in idx if f != 'ai/_decision-index.md']
        for f in idx[:1]:
            rows = {}
            cols = []
            for n, line, st, _, _ in doc_lines(ctx, f):
                if st != 'text' or not line.lstrip().startswith('|'):
                    continue
                cells = [c.strip() for c in line.strip().strip('|').split('|')]
                if any(c.lower() == 'status' for c in cells):
                    cols = [c.lower() for c in cells]
                    continue
                m = re.search(r'\b0*(\d{1,5})\b', cells[0] if cells else '') or re.search(r'\]\([^)]*?(\d{3,5})[-_]', line)
                if m:
                    num = int(m.group(1))
                    stc = cells[cols.index('status')] if 'status' in cols and cols.index('status') < len(cells) else None
                    rows[num] = (n, re.sub(r'[*_`]', '', stc).strip() if stc else None)
            if len(rows) < 2:
                continue
            for num, (n, stc) in sorted(rows.items()):
                if num not in info:
                    add(ctx, 'MISS', 'DX-2', f, n, '%04d' % num, 'index row for an ADR file that does not exist')
                elif stc and info[num]['first'] and stc.split()[0].lower().strip('.:,') != info[num]['first']:
                    add(ctx, 'WRONG', 'DX-2', f, n, '%04d %s' % (num, stc[:30]), 'index says "%s", %s says "%s"' % (stc, info[num]['rel'], info[num]['status']))
                else:
                    ok(ctx, 'DX-2', f, n, '%04d' % num)
            for num in sorted(set(info) - set(rows)):
                add(ctx, 'MISS', 'DX-2', f, 0, '%04d' % num, 'ADR %s is not in the index' % info[num]['rel'])


# ----------------------------------------------------------------------------- lane: i18n (DI-1, DI-2, DI-3)

def locale_pairs(ctx):
    """-> (locales, [(src, translation, locale)], how)."""
    pairs, locs, how = [], set(), []
    docs = set(d for d, _ in ctx.docs)
    for root, name, info in ctx.renderers:
        if name == 'docusaurus':
            t = read(ctx, info['config'])
            m = re.search(r'locales\s*:\s*\[([^\]]*)\]', t)
            dm = re.search(r'defaultLocale\s*:\s*["\'`]([\w-]+)', t)
            if m:
                ls = set(re.findall(r'["\'`]([\w-]+)["\'`]', m.group(1))) - {dm.group(1) if dm else 'en'}
                base = os.path.dirname(info['config'])
                for lc in ls:
                    locs.add(lc)
                    for s in docs:
                        if s.startswith(root + '/'):
                            tr = os.path.join(base, 'i18n', lc, 'docusaurus-plugin-content-docs', 'current', s[len(root) + 1:])
                            pairs.append((s, tr, lc))
                how.append('docusaurus i18n.locales')
        if name == 'mkdocs':
            t = read(ctx, info['config'])
            ls = set(re.findall(r'^\s*-\s*locale:\s*["\']?([\w-]+)', t, re.M))
            dflt = set(re.findall(r'^\s*-\s*locale:\s*["\']?([\w-]+)["\']?\s*\n\s*default:\s*true', t, re.M))
            ls -= dflt or {'en'}
            if ls:
                how.append('mkdocs-static-i18n')
                for lc in ls:
                    locs.add(lc)
                    for s in docs:
                        if s.startswith(root + '/') and not re.search(r'\.[a-z]{2}(-\w+)?\.md$', s) and not s[len(root) + 1:].split('/')[0] in ls:
                            sub = s[len(root) + 1:]
                            folder = os.path.join(root, lc, sub)
                            suffix = os.path.join(root, re.sub(r'\.md$', '.%s.md' % lc, sub))
                            pairs.append((s, suffix if suffix in ctx.files or folder not in ctx.files and any(x.endswith('.%s.md' % lc) for x in docs) else folder, lc))
    if not pairs:
        for d in sorted(ctx.dirs):
            parent, base = os.path.dirname(d), os.path.basename(d)
            m = LOCALE_RE.match(base)
            if not m or m.group(1) not in LOCALES or (m.group(2) and False):
                continue
            src = set(x[len(parent) + 1:] if parent else x for x in docs if os.path.dirname(x) == parent or x.startswith(parent + '/' if parent else ''))
            src = set(x for x in src if not LOCALE_RE.match(x.split('/')[0] or '') or x.split('/')[0] not in LOCALES)
            tr = set(x[len(d) + 1:] for x in docs if x.startswith(d + '/'))
            if len(tr) >= 1 and len(src & tr) >= 1 and parent.split('/')[0] in ('docs', 'doc', 'documentation', '') + tuple(ctx.top):
                locs.add(base)
                how.append('folder %s/' % d)
                top_src = [x for x in src if not x.split('/')[0] in LOCALES and x.endswith(DOC_EXT)]
                for s in sorted(top_src):
                    full = (parent + '/' + s) if parent else s
                    if parent == '' and '/' in s:
                        continue
                    pairs.append((full, d + '/' + s, base))
        for s in docs:
            m = re.match(r'^(.*?)([-_.])([a-z]{2}(?:[-_][A-Za-z]{2})?)\.(md|mdx)$', s)
            if m and m.group(3).split('-')[0].split('_')[0] in LOCALES and (m.group(1) + '.' + m.group(4)) in docs and os.path.basename(m.group(1)).isupper():
                pairs.append((m.group(1) + '.' + m.group(4), s, m.group(3)))
                locs.add(m.group(3))
                how.append('suffix ' + s)
    return locs, pairs, how


def code_multiset(ctx, rel):
    out = Counter()
    for start, lang, info, body in fences(ctx, rel):
        keep = [l.rstrip() for l in body if l.strip() and not re.match(r'^\s*(#|//|--|/\*|\*)', l)]
        keep = [re.sub(r'(["\'])(?:(?!\1).)*\1', '""', l) for l in keep]
        out['\n'.join(keep)] += 1
    return out


def code_key(body):
    keep = [l.rstrip() for l in body if l.strip() and not re.match(r'^\s*(#|//|--|/\*|\*)', l)]
    return [(l, re.sub(r'(["\'])(?:(?!\1).)*\1', '""', l)) for l in keep]


def block_site(ctx, rel, block, src_lines):
    """(line, text) of the first line of the fence whose normalised form is `block` that no source fence has;
    the fence's first body line when every line exists somewhere in the source."""
    for start, lang, info, body in fences(ctx, rel):
        pairs = code_key(body)
        if '\n'.join(k for _, k in pairs) != block:
            continue
        for off, l in enumerate(body):
            if l.strip() and not re.match(r'^\s*(#|//|--|/\*|\*)', l):
                k = re.sub(r'(["\'])(?:(?!\1).)*\1', '""', l.rstrip())
                if k not in src_lines:
                    return start + 1 + off, l.strip()[:70]
        first = next((i for i, l in enumerate(body) if l.strip()), 0)
        return start + 1 + first, (body[first].strip()[:70] if body else '')
    return 0, block.split('\n')[0][:70]


def link_multiset(ctx, rel):
    out = Counter()
    for n, tgt in link_targets(ctx, rel):
        out[tgt.split('#')[0]] += 1
    return out


def lane_i18n(ctx):
    locs, pairs, how = locale_pairs(ctx)
    if not pairs:
        ctx.notes['DI-1'] = 'N/A (no declared locale and no docs/<locale>/ or README.<lc>.md translations)'
        return
    policy = any(re.search(r'(?i)(translation|locali[sz]ation|l10n)[^\n]{0,80}(policy|may lag|may be out of date|outdated|behind the)', read(ctx, d))
                 for d, _ in ctx.docs)
    ctx.notes['DI.how'] = 'locales %s via %s%s' % (','.join(sorted(locs)), '; '.join(sorted(set(how))[:3]), '; a lag policy is declared (§ 11)' if policy else '')
    n_commits = (sh(ctx, ['rev-list', '--count', 'HEAD']) or '').strip() if ctx.git else ''
    one_commit = n_commits.isdigit() and int(n_commits) <= 1
    blind = 0
    for src, tr, lc in pairs:
        if ctx.only_docs is not None and src not in ctx.only_docs and tr not in ctx.only_docs:
            continue
        if tr not in ctx.files:
            if policy:
                skip(ctx, 'DI-1', src, 0, '%s -> %s' % (lc, tr), '§11')
            else:
                add(ctx, 'MISS', 'DI-1', src, 0, '%s -> %s' % (lc, tr), 'no %s translation of this page' % lc)
            continue
        ttext = read(ctx, tr)
        banner = re.search(r'(?i)outdated|out of date|not (?:be )?up to date|translation may|older than the (?:english|source)|^outdated:\s*true', ttext[:3000])
        marker = re.search(r'(?:source[-_ ]?commit|translated[-_]from[-_]sha|source[-_]sha|translation[-_]of[-_]commit)\s*[:=]\s*["\']?([0-9a-f]{7,40})', ttext)
        if ctx.git:
            if marker:
                newer = sh(ctx, ['log', '--format=%h', '%s..HEAD' % marker.group(1), '--', src])
                if newer is None:
                    add(ctx, 'CHECK', 'DI-2', tr, 0, '%s@%s' % (src, marker.group(1)), 'source-commit marker does not resolve in this history')
                elif newer.strip():
                    if banner:
                        skip(ctx, 'DI-2', tr, 0, src, '§11')
                    else:
                        add(ctx, 'MISS', 'DI-2', tr, 0, '%s@%s' % (src, marker.group(1)), '%d commit(s) changed the source since the marker' % len(newer.split()))
                else:
                    ok(ctx, 'DI-2', tr, 0, src)
            else:
                a = (sh(ctx, ['log', '-1', '--format=%ct', '--', src]) or '').strip()
                b = (sh(ctx, ['log', '-1', '--format=%ct', '--', tr]) or '').strip()
                if one_commit or (a and b and a == b):
                    blind += 1      # one commit, or the pair committed together: time cannot order them
                elif a and b and int(a) > int(b):
                    if banner:
                        skip(ctx, 'DI-2', tr, 0, src, '§11')
                    else:
                        add(ctx, 'CHECK', 'DI-2', tr, 0, src, 'source committed after the translation (%d days later); no source-commit marker' % ((int(a) - int(b)) // 86400))
                elif a and b:
                    ok(ctx, 'DI-2', tr, 0, src)
        cs, ct = code_multiset(ctx, src), code_multiset(ctx, tr)
        src_lines = set(l for b in cs for l in b.split('\n'))
        for block in sorted(set(ct) - set(cs)):
            n, first = block_site(ctx, tr, block, src_lines)
            add(ctx, 'WRONG', 'DI-3', tr, n, first or '(fence)', 'code block differs from the source %s (the reader runs the translated copy)' % src)
        ls_, lt = link_multiset(ctx, src), link_multiset(ctx, tr)
        for tgt in sorted(set(lt) - set(ls_)):
            if tgt and not re.match(r'^[a-z]+:', tgt):
                st, dest, _, _ = resolve_target(ctx, tr, tgt)
                srcdest = set(resolve_target(ctx, src, x)[1] for x in ls_)
                if dest not in srcdest:
                    n = next((ln for ln, t in link_targets(ctx, tr) if t.split('#')[0] == tgt), 0)
                    add(ctx, 'WRONG', 'DI-3', tr, n, tgt, 'link target not in the source page %s%s' % (src, ' (and it does not resolve)' if st == 'MISS' else ''))
    if blind:
        compared = ctx.oks['DI-2'] + sum(1 for r in ctx.rows if r[2] == 'DI-2' and r[1] in ('MISS', 'WRONG', 'CHECK'))
        why = 'one commit' if one_commit else 'each pair committed together'
        if compared:
            ctx.notes['DI.blind'] = 'DI-2 history-blind on %d pair(s) (%s)' % (blind, why)
        else:
            ctx.notes['DI-2'] = 'history-blind (%d pair(s): %s, so commit time cannot order a page and its translation; ' \
                                'a source-commit marker or a real history settles it)' % (blind, why)


# ----------------------------------------------------------------------------- lane: placeholders (DF-1), nav (DF-2), gates (DL-4)

def lane_placeholders(ctx):
    pat = re.compile(r'\bTBD\b|\bTODO\b|\bFIXME\b|\bXXX\b|(?i:lorem ipsum)|(?i:\bcoming soon\b)|<(?i:insert|fill in|add)[^>]*>|\[(?i:insert|fill in)[^\]]*\]')
    for rel in ctx.claim_docs:
        if re.search(r'(?i)(^|/)(todo|roadmap|backlog|changelog)[^/]*\.md$', rel):
            continue
        for n, line, st, _, _ in doc_lines(ctx, rel):
            if st != 'text':
                continue
            s = strip_inline(line)
            s = re.sub(r'\]\([^)]*\)', ']', s)
            m = pat.search(s)
            if m:
                add(ctx, 'MISS', 'DF-1', rel, n, m.group(0), 'placeholder in published prose')


def lane_nav(ctx):
    did = False
    linked = set()
    for rel, _ in ctx.docs:
        for n, tgt in link_targets(ctx, rel):
            st, dest, _, _ = resolve_target(ctx, rel, tgt)
            if dest:
                linked.add(dest)
    for root, name, info in ctx.renderers:
        cfg = info.get('config', '')
        if name == 'mkdocs':
            t = read(ctx, cfg)
            m = re.search(r'^nav:\s*\n((?:[ \t-].*\n?|\s*\n)*)', t, re.M)
            if not m:
                continue
            did = True
            navf = set()
            base = t[:m.start()].count('\n')
            for i, line in enumerate(m.group(1).split('\n')):
                for f in re.findall(r'(?:^|:\s*|-\s+)["\']?([\w./ -]+?\.(?:md|ipynb))["\']?\s*$', line):
                    p = os.path.normpath(os.path.join(root, f.strip()))
                    navf.add(p)
                    if p not in ctx.files:
                        add(ctx, 'MISS', 'DF-2', cfg, base + i + 2, f.strip(), 'nav entry to a missing page under %s/' % root)
            nin = re.findall(r'^\s+([^\s#][^\n]*)$', (re.search(r'^not_in_nav:\s*\|?\s*\n((?:\s+.*\n?)*)', t, re.M) or re.match('', '')).group(1) if re.search(r'^not_in_nav:', t, re.M) else '', re.M)
            for d, _ in ctx.docs:
                if d.startswith(root + '/') and d.endswith('.md') and d not in navf and d not in linked and \
                        not any(re.search(fnmatch_re(p.strip()), d[len(root) + 1:]) for p in nin if p.strip()):
                    add(ctx, 'MISS', 'DF-2', d, 0, d, 'orphan: in no nav entry, no not_in_nav pattern, linked from no page')
        elif name == 'mdbook':
            s = root + '/SUMMARY.md'
            if s not in ctx.files:
                continue
            did = True
            inside = set(dest for n, tgt in link_targets(ctx, s) for st, dest, _, _ in [resolve_target(ctx, s, tgt)] if dest)
            for d, _ in ctx.docs:
                if d.startswith(root + '/') and d != s and d not in inside and d not in linked:
                    add(ctx, 'MISS', 'DF-2', d, 0, d, 'orphan: not in SUMMARY.md and linked from no page')
        elif name == 'docusaurus':
            base = os.path.dirname(cfg)
            for f in sorted(ctx.files):
                if os.path.dirname(f) == base and re.match(r'sidebars\.(js|ts|json|cjs|mjs)$', os.path.basename(f)):
                    did = True
                    t = read(ctx, f)
                    ids = set()
                    for d, _ in ctx.docs:
                        if d.startswith(root + '/'):
                            ids.add(re.sub(r'\.(md|mdx)$', '', d[len(root) + 1:]))
                            fm = re.search(r'^id:\s*["\']?([\w-]+)', read(ctx, d)[:500], re.M)
                            if fm:
                                ids.add(os.path.join(os.path.dirname(d[len(root) + 1:]), fm.group(1)))
                    for m in re.finditer(r'(?:id\s*:\s*|^\s*|[\[,]\s*)["\']([\w./-]+)["\']\s*(?=[,\]\n}])', t, re.M):
                        v = m.group(1)
                        if v in ('doc', 'category', 'link', 'autogenerated', 'html', 'ref', 'generated-index') or '/' not in v and v not in ids and not any(i.endswith('/' + v) for i in ids):
                            if v in ('doc', 'category', 'link', 'autogenerated', 'html', 'ref', 'generated-index'):
                                continue
                        if v not in ids and not any(i.endswith('/' + v) or i == v for i in ids):
                            add(ctx, 'MISS', 'DF-2', f, t[:m.start()].count('\n') + 1, v, 'sidebar doc id resolves to no page under %s/' % root)
        elif name == 'sphinx':
            did = True
            tocd = set()
            for d, _ in ctx.docs:
                if not d.startswith((root + '/') if root else ''):
                    continue
                inblock = False
                for n, line, st, lang, _ in doc_lines(ctx, d):
                    if re.match(r'^\s*\.\.\s+toctree::|^```\{toctree\}', line):
                        inblock = True
                        continue
                    if inblock:
                        if re.match(r'^\s*:', line) or not line.strip():
                            if not line.strip() and tocd:
                                pass
                            continue
                        if not line.startswith((' ', '\t')) and not d.endswith('.md'):
                            inblock = False
                            continue
                        if line.strip().startswith('```'):
                            inblock = False
                            continue
                        e = re.sub(r'^.*<([^>]+)>\s*$', r'\1', line.strip())
                        if re.match(r'^[a-z]+://', e) or e == 'self':
                            continue
                        p = os.path.normpath(os.path.join(os.path.dirname(d) if not e.startswith('/') else root, e.lstrip('/')))
                        hit = next((p + x for x in ('.rst', '.md', '', '.ipynb') if p + x in ctx.files), None)
                        if '*' in e:
                            continue
                        if hit:
                            tocd.add(hit)
                        else:
                            add(ctx, 'MISS', 'DF-2', d, n, e, 'toctree entry resolves to no document')
    if not did:
        ctx.notes['DF-2'] = 'N/A (no docs site nav: no mkdocs nav, SUMMARY.md, sidebars or toctree)'


def fnmatch_re(p):
    return '^' + re.escape(p.strip('/')).replace(r'\*\*', '.*').replace(r'\*', '[^/]*') + ('$' if not p.endswith('/') else '')


def lane_gates(ctx):
    found = 0
    ci = [f for f in sorted(ctx.files) if re.search(r'^\.github/workflows/[^/]+\.ya?ml$|(^|/)\.gitlab-ci\.ya?ml$|^\.circleci/config\.ya?ml$|'
                                                       r'(^|/)(azure-pipelines|bitbucket-pipelines|\.?buildkite[^/]*)\.ya?ml$|^Jenkinsfile$', f)]
    runners = ci + [f for f in sorted(ctx.files) if os.path.basename(f) in ('Makefile', 'package.json', 'tox.ini', 'noxfile.py', 'lefthook.yml', '.pre-commit-config.yaml', 'justfile', 'Taskfile.yml')
                    and not TEST_PATH.search(f)]
    for f in runners:
        t = read(ctx, f)
        lines = t.split('\n')
        for i, line in enumerate(lines, 1):
            def g(claim, why):
                add(ctx, 'MISS', 'DL-4', f, i, claim, why)
            if re.search(r'\bmkdocs\s+build\b', line) and not re.search(r'--strict|\s-s\b', line):
                cfg = next((r[2]['config'] for r in ctx.renderers if r[1] == 'mkdocs'), None)
                if not cfg or not re.search(r'^strict:\s*true', read(ctx, cfg), re.M):
                    found += 1
                    g('mkdocs build', 'no --strict and no strict: true: broken links and nav warnings exit 0')
            if re.search(r'\bsphinx-build\b', line) and not re.search(r'\s-W\b|--fail-on-warning|-W\s', line):
                found += 1
                g('sphinx-build', 'no -W: every warning (broken refs, missing toctree docs) exits 0')
            if re.search(r'\bSPHINXOPTS\s*\??=', line) and '-W' not in line:
                found += 1
                g('SPHINXOPTS', 'SPHINXOPTS without -W: the docs build cannot fail on a warning')
            if re.search(r'\bremark\b(?![-\w])', line) and not re.search(r'--frail|-f\b', line) and re.search(r'\bremark\s+[.\w"\']', line):
                found += 1
                g('remark', 'remark without --frail exits 0 on lint warnings, broken links included')
            if re.search(r'\b(lychee|markdown-link-check|markdownlint(-cli2)?|rumdl|vale)\b[^\n]*\|\|\s*(true|:|exit 0)', line):
                found += 1
                g(re.search(r'\b(lychee|markdown-link-check|markdownlint(?:-cli2)?|rumdl|vale)\b', line).group(1) + ' || true', 'the exit code is discarded')
            if re.search(r'\boasdiff\b[^\n]*\bbreaking\b', line) and '--fail-on' not in line:
                found += 1
                g('oasdiff breaking', 'no --fail-on: oasdiff exits 0 even when breaking changes are found')
            if re.search(r'openapi-diff', line) and not re.search(r'--fail-on-(incompatible|changed)', line) and re.search(r'\.ya?ml|\.json', line):
                found += 1
                g('openapi-diff', 'no --fail-on-incompatible / --fail-on-changed: both default to false, a silent pass')
            if re.search(r'\btypedoc\b', line) and not re.search(r'treat(Validation)?WarningsAsErrors', line) and not re.search(r'^\s*"?[\w:-]+"?\s*:\s*"?typedoc"?\s*,?$', line):
                tj = [x for x in ctx.files if os.path.basename(x) in ('typedoc.json', 'typedoc.jsonc')]
                if not any(re.search(r'treat(Validation)?WarningsAsErrors"\s*:\s*true', read(ctx, x)) for x in tj):
                    found += 1
                    g('typedoc', 'TypeDoc exits 0 on validation warnings unless treatValidationWarningsAsErrors / treatWarningsAsErrors is set')
            if re.search(r'\bspectral\s+lint\b', line) and not any(os.path.basename(x).startswith('.spectral') for x in ctx.files) and '--ruleset' not in line:
                found += 1
                g('spectral lint', 'no ruleset found: Spectral lints nothing (a silent pass)')
        if f in ci:
            for m in re.finditer(r'uses:\s*lycheeverse/lychee-action@(\S+)((?:\n[ \t]+.*)*)', t):
                found += 1
                blk = m.group(2)
                ln = t[:m.start()].count('\n') + 1
                if re.search(r'^\s+fail:\s*false', blk, re.M):
                    add(ctx, 'MISS', 'DL-4', f, ln, 'lychee-action fail: false', 'the link check reports and never fails the job')
                elif re.search(r'^\s+continue-on-error:\s*true', blk, re.M) or re.search(r'continue-on-error:\s*true', t[max(0, m.start() - 300):m.start()]):
                    add(ctx, 'MISS', 'DL-4', f, ln, 'lychee-action continue-on-error', 'the step may fail without failing the job')
                elif re.match(r'v1', m.group(1)) and not re.search(r'^\s+fail:\s*true', blk, re.M):
                    add(ctx, 'CHECK', 'DL-4', f, ln, 'lychee-action@' + m.group(1), 'v1 without fail: true: confirm the action fails on broken links')
                elif '--offline' not in blk and '--include-fragments' not in blk:
                    add(ctx, 'CHECK', 'DL-4', f, ln, 'lychee-action@' + m.group(1), 'online run with no --include-fragments: anchors are not checked')
                else:
                    ok(ctx, 'DL-4', f, ln, 'lychee-action')
            for m in re.finditer(r'uses:\s*oasdiff/oasdiff-action/breaking@\S+((?:\n[ \t]+.*)*)', t):
                found += 1
                if 'fail-on' not in m.group(1):
                    add(ctx, 'MISS', 'DL-4', f, t[:m.start()].count('\n') + 1, 'oasdiff-action breaking', 'no fail-on: the action reports breaking changes and passes')
    for root, name, info in ctx.renderers:
        cfg = info.get('config', '')
        t = read(ctx, cfg)
        if name == 'docusaurus':
            found += 1
            for key, dflt in (('onBrokenLinks', 'throw'), ('onBrokenAnchors', 'warn'), ('onBrokenMarkdownLinks', 'warn')):
                m = re.search(r'%s\s*:\s*["\'`](\w+)' % key, t)
                val = m.group(1) if m else dflt
                ln = t[:m.start()].count('\n') + 1 if m else 0
                if val != 'throw':
                    add(ctx, 'MISS', 'DL-4', cfg, ln, '%s: %s%s' % (key, val, '' if m else ' (default)'), 'a broken %s does not fail the build' % key[8:].lower())
                else:
                    ok(ctx, 'DL-4', cfg, ln, key)
        elif name == 'mkdocs':
            found += 1
            if not re.search(r'^strict:\s*true', t, re.M):
                ci_strict = any(re.search(r'mkdocs\s+build[^\n]*(--strict|\s-s\b)', read(ctx, f)) for f in runners)
                if not ci_strict:
                    add(ctx, 'MISS', 'DL-4', cfg, 0, 'strict', 'no strict: true and no `mkdocs build --strict` in CI: warnings pass')
            m = re.search(r'^\s+anchors:\s*(\w+)', t, re.M)
            if not m or m.group(1) == 'info':
                add(ctx, 'MISS', 'DL-4', cfg, t[:m.start()].count('\n') + 1 if m else 0, 'validation.links.anchors: %s' % (m.group(1) if m else 'info (default)'),
                    'missing anchors are info-level and never fail, even under --strict (MkDocs 1.6)')
        elif name == 'mdbook':
            found += 1
            if '[output.linkcheck]' in t or '[output.linkcheck2]' in t:
                m = re.search(r'warning-policy\s*=\s*["\'](\w+)', t)
                if not m or m.group(1) != 'error':
                    add(ctx, 'MISS', 'DL-4', cfg, 0, 'linkcheck warning-policy %s' % (m.group(1) if m else 'warn (default)'), 'broken links exit 0')
    if not found:
        ctx.notes['DL-4'] = 'N/A (no docs build or docs gate in CI, scripts or a site config)'


# ----------------------------------------------------------------------------- fences mode

EXT = {'ts': 'ts', 'typescript': 'ts', 'tsx': 'tsx', 'js': 'js', 'javascript': 'js', 'jsx': 'jsx', 'mjs': 'mjs',
       'py': 'py', 'python': 'py', 'python3': 'py', 'pycon': 'pycon', 'go': 'go', 'golang': 'go', 'rust': 'rs',
       'rs': 'rs', 'java': 'java', 'kotlin': 'kt', 'kt': 'kt', 'cs': 'cs', 'csharp': 'cs', 'rb': 'rb', 'ruby': 'rb',
       'php': 'php', 'dart': 'dart', 'elixir': 'ex', 'ex': 'ex', 'swift': 'swift', 'sh': 'sh', 'bash': 'sh',
       'shell': 'sh', 'console': 'txt', 'json': 'json', 'yaml': 'yaml', 'yml': 'yaml', 'toml': 'toml', 'sql': 'sql'}


def classify_fence(lang, info, body, rel, prev_line):
    text = '\n'.join(body)
    if re.search(r'\b(ignore|no_run|compile_fail|notest|nocompile|skip)\b|test=["\']skip', info) or \
            re.search(r'(?i)<!--\s*(skip|no-?test|eslint-skip|doctest:\s*skip)', prev_line):
        return 'skip-marked', '§14 the fence is marked not to run'
    if lang in ('pseudo', 'pseudocode', 'text', 'txt', 'plain', 'plaintext', 'diff', 'patch', 'output', 'log', 'mermaid', 'dot', 'plantuml', 'ascii'):
        return 'not-code', '§14 %s fence' % lang
    if lang in SHELL_LANGS:
        if re.search(r'(?m)^\s*\$\s', text) and lang in ('console', 'shell-session', 'sh-session', 'terminal'):
            return 'transcript', '§14 shell transcript'
        return 'shell', 'commands: resolved by doc-drift-scan, run by quickstart-verify'
    if lang in ('json', 'yaml', 'yml', 'toml', 'ini', 'env', 'dotenv', 'xml', 'html', 'css', 'scss', 'graphql', 'sql', 'http', 'proto', 'dockerfile', 'hcl', 'terraform'):
        return 'config', 'data or config fence'
    if re.search(r'(?m)^\s*>>>\s', text) or lang == 'pycon':
        return 'doctest', 'DC-2: >>> prompts'
    if re.search(r'(?m)^\s*(\.\.\.|…|//\s*\.\.\.|#\s*\.\.\.|/\*\s*\.\.\.\s*\*/|<\.\.\.>)\s*$', text) or '// ...' in text or '# ...' in text:
        return 'excerpt', '§14 excerpt (... marker)'
    if lang in ('go', 'golang'):
        return ('candidate', 'package clause') if re.search(r'(?m)^package\s+\w+', text) else ('fragment', '§14 no package clause')
    if lang in ('rust', 'rs'):
        return ('candidate', 'rustdoc doctest') if 'fn main' in text or rel.startswith(('src/', 'book/')) else ('fragment', '§14 no fn main')
    if lang in ('java', 'kotlin', 'kt'):
        return ('candidate', 'class declaration') if re.search(r'\b(class|object|fun main)\s+\w+', text) else ('fragment', '§14 no class')
    if lang in ('ts', 'typescript', 'tsx', 'js', 'javascript', 'jsx', 'mjs'):
        if 'twoslash' in info:
            return 'candidate', 'twoslash-marked'
        if re.search(r'(?m)^\s*(import\s|export\s|const\s+\w+\s*=\s*require\()', text):
            return 'candidate', 'self-contained module (imports)'
        return 'fragment', '§14 no import: a statement excerpt'
    if lang in ('py', 'python', 'python3'):
        return 'candidate', 'python (py_compile; import check when it imports)'
    if lang in EXT:
        return 'fragment', 'no compile lane for %s' % lang
    return 'unknown', 'unlabelled or unknown language'


def write_fences(ctx, outdir):
    os.makedirs(outdir, exist_ok=True)
    kinds = Counter()
    with open(os.path.join(outdir, 'fences.tsv'), 'w', encoding='utf-8') as fh:
        fh.write('file\tdoc\tline\tlang\tkind\treason\tinfo\n')
        for rel in ctx.claim_docs + [d for d, k in ctx.docs if k == 'changelog' and False]:
            lines = read(ctx, rel).split('\n')
            for start, lang, info, body in fences(ctx, rel):
                prev = lines[start - 2] if start >= 2 else ''
                kind, why = classify_fence(lang, info, body, rel, prev)
                kinds[kind] += 1
                name = '%s__L%d.%s' % (rel.replace('/', '__'), start, EXT.get(lang, 'txt'))
                with open(os.path.join(outdir, name), 'w', encoding='utf-8') as out:
                    out.write('\n'.join(body) + '\n')
                fh.write('\t'.join([name, rel, str(start), lang or '-', kind, why, info.replace('\t', ' ')]) + '\n')
    return kinds


# ----------------------------------------------------------------------------- driver

LANE_FN = {'links': lane_links, 'paths': lane_paths, 'symbols': lane_symbols, 'scripts': lane_scripts,
           'flags': lane_flags, 'versions': lane_versions, 'tools': lane_tools, 'env': lane_env,
           'endpoints': lane_endpoints, 'specex': lane_specex, 'embeds': lane_embeds, 'breaking': lane_breaking,
           'changelog': lane_changelog, 'resources': lane_resources, 'linksin': lane_linksin, 'adr': lane_adr,
           'i18n': lane_i18n, 'placeholders': lane_placeholders, 'nav': lane_nav, 'gates': lane_gates}
LANE_CLASSES = {'links': 'DL-1 DL-2 DL-3', 'paths': 'DR-1', 'symbols': 'DR-2 DR-5', 'scripts': 'DR-3', 'flags': 'DR-4',
                'versions': 'DS-2', 'tools': 'DS-3', 'env': 'DE-1 DE-2 DE-3', 'endpoints': 'DA-1', 'specex': 'DA-2',
                'embeds': 'DC-3', 'breaking': 'DH-1', 'changelog': 'DH-2', 'resources': 'DK-2', 'linksin': 'DK-3',
                'adr': 'DX-1 DX-2 DX-3', 'i18n': 'DI-1 DI-2 DI-3', 'placeholders': 'DF-1', 'nav': 'DF-2', 'gates': 'DL-4'}


def inside(child, parent):
    child, parent = os.path.realpath(child), os.path.realpath(parent)
    return child == parent or child.startswith(parent.rstrip('/') + '/')


def scan(root, lanes=None, show_all=False, only_docs=None, git=True):
    ctx = Ctx()
    ctx.root = os.path.realpath(root)
    ctx.cache, ctx.rows, ctx.notes = {}, [], {}
    ctx.skips, ctx.oks = Counter(), Counter()
    ctx.show_all = show_all
    ctx.only_docs = only_docs
    ctx.git = git and os.path.exists(os.path.join(ctx.root, '.git')) and shutil.which('git') is not None
    ctx.blocked = {}
    build_index(ctx)
    detect_renderer(ctx)
    build_corpus(ctx)
    for lane in (LANES if lanes is None else lanes):
        try:
            LANE_FN[lane](ctx)
        except Exception as e:  # a lane that raises is blocked, never clean
            ctx.blocked[lane] = '%s: %s' % (type(e).__name__, str(e)[:160])
    return ctx


def ledger(ctx, lanes, out):
    w = lambda s: out.write(s + '\n')
    kinds = Counter(k for _, k in ctx.docs)
    w('%s - root=%s' % (ENGINE, ctx.root))
    w('corpus: %d docs in scope (doc %d, adr %d, changelog %d; runbooks %d; generated %d) - skipped %s' % (
        len(ctx.docs), kinds['doc'], kinds['adr'], kinds['changelog'], len(ctx.runbooks), len(ctx.generated),
        ', '.join('%s %d' % ({'learning': '-> learning (agent-facing knowledge, knowledge-ref-scan)'}.get(k, k), v)
                  for k, v in sorted(ctx.scope_skips.items())) or 'none'))
    w('renderer: %s' % (', '.join('%s (%s)' % (n, r or '.') for r, n, _ in ctx.renderers) or 'github (plain repo docs)'))
    w('roots: %d package roots%s; git: %s' % (len(ctx.pkg_roots), (' (' + ', '.join(ctx.pkg_roots[:6]) + (' ...' if len(ctx.pkg_roots) > 6 else '') + ')') if ctx.pkg_roots else '',
                                            'yes' if ctx.git else 'no (DH-1, DI-2 and rename lookups N/A)'))
    cand = Counter((r[2], r[1]) for r in ctx.rows if r[1] in ('MISS', 'WRONG', 'CHECK'))
    for lane in lanes:
        cls = LANE_CLASSES[lane].split()
        if lane in ctx.blocked:
            w('lane %-12s blocked (%s) - %s' % (lane, ctx.blocked[lane], ' '.join(cls)))
            continue
        parts = []
        for c in cls:
            note = ctx.notes.get(c)
            n_ok = ctx.oks[c]
            n_c = sum(v for (k, s), v in cand.items() if k == c)
            n_s = sum(v for (k, p), v in ctx.skips.items() if k == c)
            if note and not n_ok and not n_c:
                parts.append('%s %s' % (c, note))
            elif c == 'DK-1' and not (n_ok or n_c):
                continue
            else:
                sk = ', '.join('%s %d' % (p, v) for (k, p), v in sorted(ctx.skips.items()) if k == c)
                parts.append('%s checked (%d claims -> %d candidates%s)' % (c, n_ok + n_c + n_s, n_c, '; skip ' + sk if sk else ''))
        extra = [v for k, v in ctx.notes.items() if '.' in k and k.split('.')[0] in [x.split('-')[0] + '-' + x.split('-')[1] if '-' in x else x for x in cls] + [c.split('-')[0] for c in cls]]
        w('lane %-12s ran - %s%s' % (lane, ' | '.join(parts), (' | ' + '; '.join(extra)) if extra else ''))
    if any(l in lanes for l in ('paths', 'scripts', 'flags')):
        n_c = sum(v for (k, s), v in cand.items() if k == 'DK-1')
        w('runbooks          DK-1 checked (%d runbook command, path and flag claims -> %d candidates) in %d runbooks' % (ctx.oks['DK-1'] + n_c, n_c, len(ctx.runbooks)))


def self_test():
    tmp = tempfile.mkdtemp(prefix='doc-claims-selftest.')
    files = {
        'package.json': json.dumps({'name': 'root', 'packageManager': 'pnpm@10.2.0', 'engines': {'node': '>=22'},
                                    'scripts': {'dev': 'x', 'build': 'x', 'db:reset': 'x'}, 'devDependencies': {'vitest': '1'}}),
        'pnpm-lock.yaml': 'lockfileVersion: 9\n', '.nvmrc': '22\n', 'pnpm-workspace.yaml': 'packages: [apps/*]\n',
        'apps/api/package.json': json.dumps({'name': '@x/api', 'scripts': {'start:dev': 'x'}, 'bin': {'apicli': 'bin/cli.js'}}),
        'apps/api/src/main.ts': 'const port = process.env.API_PORT;\napp.setGlobalPrefix("api");\nexport const MAX_RETRIES = 3;\n',
        'apps/api/src/config/env.ts': 'export const env = z.object({\n  RETRY_LIMIT: z.coerce.number().default(3),\n  LOG_FORMAT: z.enum(["json", "pretty"]).default("json"),\n  DATABASE_URL: z.string(),\n  SECRET_SAUCE: z.string(),\n});\n',
        'apps/api/src/orders.service.ts': 'export class OrdersService {\n  list() {}\n}\n',
        'apps/api/src/orders.controller.ts': '@Controller("orders")\nexport class C {\n  @Post(":id/cancel") cancel() {}\n  @Get() list() {}\n}\n/** @deprecated use listOrders */\nexport function getOrders() {}\nexport function listOrders() {}\n',
        'apps/api/bin/cli.js': 'program.option("--import <f>").option("--dry-run");\n',
        'apps/api/README.md': 'Run `src/main.ts` locally.\n',
        'scripts/restore.sh': 'case "$1" in --target) ;; esac\n',
        'Makefile': 'db-restore:\n\techo\n',
        '.env.example': 'API_PORT=3000\nDATABASE_URL=postgres://\n',
        'deploy/k8s/cron.yaml': 'apiVersion: batch/v1\nkind: CronJob\nmetadata:\n  name: reports-daily\n  namespace: app\n',
        'docker-compose.yml': 'services:\n  api:\n    image: node:22\n  db:\n    image: postgres:16\n',
        'README.md': ('# Project\n\nNeeds Node 20+ and Postgres 16.\n\n```bash\npnpm install\npnpm dev:all\nnpm install\n'
                      'node scripts/restore.sh --target x --legacy\napicli --import a --legacy-import\n```\n\n'
                      'See [setup](docs/setup.md#install-steps) and [gone](docs/gone.md) and [ok](docs/setup.md#running-it).\n'
                      'The file `apps/api/src/gone.ts` and `src/main.ts`. Set `RETRY_LIMIT` env (default `5`).\n'
                      'Env `LOG_FORMAT`: `json` or `text`. Env `GHOST_VAR` is set at deploy.\nThe env loader retries `MAX_RETRIES` times.\n'
                      'Call `POST /orders/{id}/void` and `POST /api/orders/{id}/cancel` and `GET /metrics`.\n'
                      'Use `getOrders()` today. TBD: write more. See https://example.com.\n'
                      'The `RefundProcessor` retries; `OrdersService.cancelAll()` cancels; `Math.ceil()` rounds; `OrdersService.list()` lists.\n'),
        'docs/setup.md': '# Setup\n\n## Running it\n\nok\n\n## Running it\n\ndup\n\n## مرحبا بالعالم\n',
        'docs/ar/setup.md': '# الإعداد\n\n```bash\npnpm dev:all\n```\n\n[x](../old-name.md)\n',
        'docs/runbooks/restore.md': '# Restore\n\n## Rollback\n\n```bash\nkubectl -n app get cronjob reports-nightly\nmake restore-db\nkubectl --context prod get pods\n```\n\n## Mitigation\n',
        'docs/adr/0001-use-pg.md': '# 1. Use PG\n\nStatus: Superseded by [0002](0002-use-pg16.md)\n',
        'docs/adr/0002-use-pg16.md': '# 2. Use PG16\n\nStatus: Accepted\n',
        'docs/adr/0003-x.md': '# 3. X\n\nStatus: Accepted\n\nSupersedes [0009](0009-nope.md). Superseded 2026-09-23 note.\n',
        'docs/adr/0004-y.md': '# 4. Y\n\nStatus: Wishful\n',
        'docs/adr/README.md': '| ADR | Title | Status |\n|---|---|---|\n| [0001](0001-use-pg.md) | a | Superseded |\n| [0002](0002-use-pg16.md) | b | Proposed |\n| [0003](0003-x.md) | c | Accepted |\n',
        'docs/v1/old.md': 'Run `pnpm legacy-cmd` and see `apps/old/x.ts`.\n',
        'ai/audits/2026-01.md': 'Missing `apps/api/src/deleted.ts`.\n',
        '.claude/commands/x.md': 'See `nowhere/path.ts`.\n',
        'CLAUDE.md': 'See `apps/api/src/agent-only.ts`.\n',
        'CHANGELOG.md': '# Changelog\n\n## [Unreleased]\n\n## [1.1.0] - 2026-02-01\n\n## [1.2.0] - 2026-03-01\n\n## [1.0.0] - 01/01/2026\n\n[1.1.0]: https://x/compare/v1.0.0...v1.1.0\n',
        'mkdocs.yml': 'site_name: x\nnav:\n  - Setup: setup.md\n  - Gone: missing.md\n',
        '.github/workflows/docs.yml': 'jobs:\n  d:\n    steps:\n      - run: mkdocs build\n      - uses: lycheeverse/lychee-action@v2\n        with:\n          fail: false\n      - run: oasdiff breaking a.yaml b.yaml\n',
        'alerts/rules.yml': 'groups:\n- name: x\n  rules:\n  - alert: ApiDown\n    annotations:\n      runbook_url: docs/runbooks/missing.md\n',
    }
    for p, c in files.items():
        full = os.path.join(tmp, p)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, 'w', encoding='utf-8') as fh:
            fh.write(c)
    ctx = scan(tmp, git=False)
    got = set((r[2], r[6]) for r in ctx.rows if r[1] in ('MISS', 'WRONG', 'CHECK'))
    want = [('DR-3', 'pnpm dev:all'), ('DK-1', 'make restore-db'), ('DS-3', 'npm install'), ('DR-4', 'scripts/restore.sh --legacy'),
            ('DR-4', 'apicli --legacy-import'), ('DL-1', 'docs/gone.md'), ('DL-2', 'docs/setup.md#install-steps'),
            ('DR-1', 'apps/api/src/gone.ts'), ('DE-3', 'RETRY_LIMIT default 5'), ('DE-3', 'LOG_FORMAT values json|text'),
            ('DE-1', 'GHOST_VAR'), ('DE-2', 'SECRET_SAUCE'), ('DA-1', 'POST /orders/{id}/void'), ('DR-5', 'getOrders()'),
            ('DF-1', 'TBD'), ('DS-2', 'Node 20+'), ('DK-2', 'CronJob/reports-nightly'), ('DX-1', '0003 supersedes 0009'),
            ('DX-2', '0004 status "Wishful"'), ('DX-2', '0002 Proposed'), ('DX-2', '0004'), ('DH-2', '1.0.0 01/01/2026'),
            ('DH-2', '1.2.0'), ('DI-3', '../old-name.md'), ('DF-2', 'missing.md'), ('DL-4', 'mkdocs build'),
            ('DL-4', 'lychee-action fail: false'), ('DL-4', 'oasdiff breaking'), ('DK-3', 'docs/runbooks/missing.md'),
            ('DH-2', '1.2.0'), ('DR-2', 'RefundProcessor'), ('DR-2', 'OrdersService.cancelAll()')]
    decoys = [('DR-1', 'src/main.ts'), ('DL-2', 'docs/setup.md#running-it'), ('DE-1', 'MAX_RETRIES'), ('DA-1', 'GET /metrics'),
              ('DA-1', 'POST /api/orders/{id}/cancel'), ('DR-3', 'pnpm legacy-cmd'), ('DR-1', 'apps/api/src/deleted.ts'),
              ('DR-1', 'nowhere/path.ts'), ('DR-1', 'apps/api/src/agent-only.ts'), ('DK-2', 'namespace app'),
              ('DX-1', '0003 supersedes 2026'), ('DR-3', 'pnpm install'), ('DR-2', 'Math.ceil()'), ('DR-2', 'OrdersService.list()')]
    fails = [('missing', w) for w in want if w not in got] + [('decoy flagged', d) for d in decoys if d in got]
    # row shape: DE-2 carries the schema's file:line; DI-3 points at the differing line, never line 0
    shape = dict(((r[2], r[6]), r) for r in ctx.rows)
    de2 = shape.get(('DE-2', 'SECRET_SAUCE'))
    if not de2 or (de2[4], de2[5], de2[3]) != ('apps/api/src/config/env.ts', '5', 'primary'):
        fails.append(('DE-2 row not at the schema line (primary)', de2 and de2[3:6]))
    di3 = shape.get(('DI-3', '../old-name.md'))
    if not di3 or di3[5] != '7':
        fails.append(('DI-3 link row not at its line 7', di3 and di3[5]))
    di3c = shape.get(('DI-3', 'pnpm dev:all'))
    if not di3c or di3c[5] != '4':
        fails.append(('DI-3 code row not at the differing line 4', di3c and di3c[5]))
    shutil.rmtree(tmp, ignore_errors=True)
    n_git = git_self_test(fails)
    if ctx.blocked:
        fails += [('lane blocked', (k, v)) for k, v in ctx.blocked.items()]
    for kind, item in fails:
        sys.stderr.write('self-test FAIL %s: %s\n' % (kind, item))
    total = len(want) + len(decoys) + 3 + n_git
    sys.stderr.write('self-test: %d/%d passed\n' % (total - len([f for f in fails if f[0] != 'lane blocked']), total))
    return 1 if fails else 0


def git_self_test(fails):
    """History lanes (DH-1 announced test, DI-2 history-blind, DL-1 detail) on a throwaway git repo. Returns the
    number of checks; a missing git is a failure, never a skip."""
    tmp = tempfile.mkdtemp(prefix='doc-claims-selftest-git.')
    env = dict(os.environ, GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull, GIT_TERMINAL_PROMPT='0',
               GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@localhost', GIT_COMMITTER_NAME='t',
               GIT_COMMITTER_EMAIL='t@localhost', TZ='UTC')

    def g(*a, **kw):
        e = dict(env, GIT_AUTHOR_DATE=kw.get('date', '2026-01-01T00:00:00'), GIT_COMMITTER_DATE=kw.get('date', '2026-01-01T00:00:00'))
        return subprocess.run(['git', '-C', tmp, '-c', 'commit.gpgsign=false', '-c', 'tag.gpgsign=false',
                               '-c', 'init.defaultBranch=main', '-c', 'core.hooksPath=' + os.devnull] + list(a),
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=e).returncode

    def put(rel, text):
        full = os.path.join(tmp, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, 'w', encoding='utf-8') as fh:
            fh.write(text)
    checks = 0
    try:
        if g('init', '-q') != 0:
            fails.append(('git self-test', 'git init failed (git missing?)'))
            return 1
        put('README.md', '# P\n\nSee [x](docs/never.md).\n')
        put('docs/guide.md', '# Guide\n')
        put('docs/ar/guide.md', '# دليل\n')
        put('src/a.ts', 'export const a = 1;\n')
        g('add', '-A'); g('commit', '-qm', 'init')
        ctx = scan(tmp, lanes=['links', 'i18n'], git=True)
        checks += 2
        if ctx.notes.get('DI-2', '').startswith('history-blind') is False:
            fails.append(('DI-2 on one commit not history-blind', ctx.notes.get('DI-2')))
        dl1 = [r for r in ctx.rows if r[2] == 'DL-1' and r[6] == 'docs/never.md']
        if not dl1 or dl1[0][7].endswith('; ') or dl1[0][7] != 'docs/never.md does not exist':
            fails.append(('DL-1 detail with a dangling separator', dl1 and dl1[0][7]))
        g('tag', 'v1.0.0', date='2026-01-01T00:00:00')
        put('src/a.ts', 'export const a = 2;\n')
        g('add', '-A'); g('commit', '-qm', 'feat!: drop the page param', date='2026-02-01T00:00:00')
        put('src/b.ts', 'export const b = 1;\n')
        g('add', '-A'); g('commit', '-qm', 'feat!: rename the export command', date='2026-02-02T00:00:00')
        put('CHANGELOG.md', '# Changelog\n\n## [Unreleased]\n\n### Changed\n\n- Order pages load faster with fewer query params.\n'
                            '- The export command is renamed to `report`.\n\n## [1.0.0] - 2026-01-01\n\n- First.\n')
        g('add', '-A'); g('commit', '-qm', 'docs: changelog', date='2026-02-03T00:00:00')
        ctx = scan(tmp, lanes=['breaking'], git=True)
        dh1 = set(r[6].split(' ', 1)[1] for r in ctx.rows if r[2] == 'DH-1' and r[1] == 'MISS')
        checks += 2
        if 'drop the page param' not in dh1:
            fails.append(('DH-1 cleared by an unrelated bullet', sorted(dh1)))
        if 'rename the export command' in dh1:
            fails.append(('DH-1 announced change reported', sorted(dh1)))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return checks


def main(argv):
    if '--self-test' in argv:
        return self_test()
    pos = [a for a in argv if not a.startswith('--')]
    opt = dict((a.split('=', 1) + [''])[:2] for a in argv if a.startswith('--'))
    if len(pos) != 1 or not os.path.isdir(pos[0]):
        sys.stderr.write(__doc__ + '\nBLOCKED: give exactly one existing repo directory\n')
        return 2
    root = os.path.realpath(pos[0])
    for k in ('--out', '--fences'):
        if opt.get(k) and inside(opt[k], root):
            sys.stderr.write('BLOCKED: %s=%s is inside the scanned repo; the engine never writes there\n' % (k, opt[k]))
            return 2
    lanes = LANES if opt.get('--lanes', 'all') in ('', 'all') else [x.strip() for x in opt['--lanes'].split(',') if x.strip()]
    bad = [x for x in lanes if x not in LANE_FN]
    if bad:
        sys.stderr.write('BLOCKED: unknown lane(s) %s; lanes: %s\n' % (','.join(bad), ','.join(LANES)))
        return 2
    only = None
    if opt.get('--docs'):
        only = set()
        for p in opt['--docs'].split(','):
            p = os.path.relpath(os.path.realpath(os.path.join(root, p)) if not os.path.isabs(p) else p, root)
            only.add(p)
    ctx = scan(root, lanes, show_all='--all' in opt, only_docs=only, git='--no-git' not in opt)
    if only is not None:
        expanded = set()
        for d, _ in ctx.docs:
            if any(d == p or d.startswith(p.rstrip('/') + '/') for p in only):
                expanded.add(d)
        if expanded != only:
            ctx = scan(root, lanes, show_all='--all' in opt, only_docs=expanded, git='--no-git' not in opt)
    rows = ctx.rows
    if opt.get('--class'):
        want = set(opt['--class'].split(','))
        rows = [r for r in rows if r[2] in want]
    if opt.get('--claim'):
        rows = [r for r in rows if r[6] == opt['--claim'] or r[6].endswith(' ' + opt['--claim'])]
    if '--check' in opt:
        rows = [r for r in rows if r[1] in ('MISS', 'WRONG')]
    rows.sort(key=lambda r: (r[2], r[4], int(r[5]) if r[5].isdigit() else 0))
    if opt.get('--recheck'):
        hit = [r for r in ctx.rows if r[0] == opt['--recheck'] and r[1] in ('MISS', 'WRONG', 'CHECK')]
        for r in hit:
            sys.stdout.write('\t'.join(r) + '\n')
        sys.stderr.write('recheck %s: %s\n' % (opt['--recheck'], 'STILL FAILING' if hit else 'closed (no such candidate now)'))
        return 2 if ctx.blocked else (1 if hit else 0)
    out = sys.stdout
    for r in rows:
        out.write('\t'.join(r) + '\n')
    ledger(ctx, lanes, sys.stderr)
    if opt.get('--out'):
        os.makedirs(opt['--out'], exist_ok=True)
        with open(os.path.join(opt['--out'], 'claims.tsv'), 'w', encoding='utf-8') as fh:
            fh.write('id\tstatus\tclass\tsurface\tdoc\tline\tclaim\tdetail\n')
            for r in ctx.rows:
                fh.write('\t'.join(r) + '\n')
        with open(os.path.join(opt['--out'], 'ledger.txt'), 'w', encoding='utf-8') as fh:
            ledger(ctx, lanes, fh)
    if opt.get('--fences'):
        k = write_fences(ctx, opt['--fences'])
        sys.stderr.write('fences: %s -> %s/fences.tsv\n' % (', '.join('%s %d' % x for x in sorted(k.items())) or 'none', opt['--fences']))
    n = sum(1 for r in rows if r[1] in ('MISS', 'WRONG', 'CHECK'))
    if ctx.blocked:
        sys.stderr.write('exit 2: lane(s) blocked: %s - their classes are blocked, never clean\n' % ', '.join(sorted(ctx.blocked)))
        return 2
    sys.stderr.write('exit %d: %d candidate row(s)%s\n' % (1 if n else 0, n, ' (--check: MISS/WRONG only)' if '--check' in opt else ''))
    return 1 if n else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
