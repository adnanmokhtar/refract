#!/usr/bin/env python3
"""knowledge-refs.py — knowledge-ref-scan §1-§6: does every path, symbol, command, pattern, ADR id
and marker that the AI knowledge layer states still resolve in this repository?

Why a script and not a grep: a naive "extract every backticked path and test -e" over a real
NestJS + React monorepo's 468 knowledge files returned 15,173 dead-reference candidates. 10,771 sat
in dated history files (P-3), 2,789 were abbreviations that resolve to exactly one tracked file
(P-6), and most of the rest were pack-generic illustrations outside any anchor block (P-10). The
order below is what makes the remainder worth reading:
  1. scope: the corpus (CLAUDE.md, CLAUDE.local.md, AGENTS.md, GEMINI.md, .cursor/rules, Copilot
     instructions, ai/**, .claude/rules, codebase-profile, _extracted-*) plus the LIVE anchor region
     of every installed agent, command, skill and pack pattern (column-0 markers outside fences);
  2. drop history (ai/audits, ai/incidents, ai/runs, ai/migration, *_history.md, CHANGELOG*,
     ai/dynamic/changelog + interaction-log, ADR Context sections) and the memory sinks
     (ai/dynamic, ai/failures, ai/evals: memory-hygiene-scan §1 owns their citations);
  3. resolve: exact, relative to the citing file, tsconfig `paths`, workspace package name,
     extension-less, unique tracked suffix, on disk but untracked or gitignored;
  4. classify what is left with git history (DOCER: only a reference that once resolved is
     "dead"; ReCite: RENAMED -> the successor, DELETED -> a human decides).

Usage:  python3 -I knowledge-refs.py <root> [--classes=1,2,3,4,5,6] [--only=<file>:<line>]
                 [--corpus=<list file>|-] [--global-dir=<dir>|--no-global] [--no-history]
                 [--expand] [--all] [--json]
        python3 -I knowledge-refs.py --self-test
--only       re-run one site (the failing-first proof of /refresh-knowledge --from-audit).
--corpus     an explicit file list, one repo-relative path per line (documentation's doc-drift-scan
             passes its human-doc corpus this way, O-1); '-' reads it from stdin, never implicitly.
--global-dir where user-global commands, agents and skills live (default ~/.claude): a slash command
             or @agent installed there resolves (P-23); the pack catalog under
             <global-dir>/templates/packs tells an UNINSTALLED Refract command from an unknown word.
--expand     one row per site instead of one row per (class, reference) with N sites.
--all        also print info rows (abbreviations, untracked/gitignored targets, route-like slashes).

OUTPUT: TSV `# § class sev site ref resolution verdict sites note` (or --json). verdict candidate |
unconfirmed | info. Stderr: the ledger — census, corpus by scope, refs per lane, resolution counts.
Exit: 0 no candidate or unconfirmed row · 1 rows · 2 blocked (root missing, git unreadable where
required) · 3 self-test failed. Stdlib only, Python >= 3.8, `python3 -I` safe; reads only, runs
read-only git with GIT_OPTIONAL_LOCKS=0, writes nothing under <root> (temp files go to $TMPDIR).
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
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import kn_common as K  # noqa: E402

EXT = r'(?:md|mdc|ts|tsx|js|jsx|mjs|cjs|mts|cts|json|jsonc|ya?ml|py|sh|bash|sql|toml|go|rb|php|vue|svelte|css|scss|html|txt|env|lock|java|kt|cs|swift|dart|prisma|graphql|gql|proto|tf|ini|cfg|conf)'
PATHLIKE = re.compile(r'^(?:\.{1,2}/|/)?(?:[\w@.()\[\]+-]+/)+[\w@.()\[\]+-]*/?$|^[\w.-]+\.' + EXT + r'$')
SKIP = re.compile(r'[<>{}*$?|\s,;"\']|\.\.\.|^[a-z][\w+.-]*://|^mailto:|^~|^#|path/to/|(^|/)(your|my)[-_]'
                  r'|(^|/)(foo|bar|baz|example|xxx+|nnnn|yyyy[-\w]*)(/|\.|$)|^\d+(/\d+)+$|node_modules/', re.I)
LINESUF = re.compile(r'(?::\d+(?:[-–:]\d+)?|#L\d+(?:-L?\d+)?|#[\w-]*)$')
TICK = re.compile(r'`([^`\n]{1,240})`')
LINK = re.compile(r'\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)')
REFDEF = re.compile(r'^\s{0,3}\[[^\]]+\]:\s*<?(\S+?)>?(?:\s|$)')
HREF = re.compile(r'\b(?:href|src)="([^"#?]+)')
FENCE_PATH = re.compile(r'(?<![\w@/.:-])((?:\.{1,2}/)?(?:[\w@.-]+/)+[\w@.-]+\.' + EXT + r')(?![\w/])')
FRAMEWORK = re.compile(r'^(?:templates|scripts|commands|benchmarks|governance|docs/(?:RETRIEVAL|COMMANDS|CHEATSHEET|ARCHITECTURE)'
                       r'|\.claude/_(?:codebase-scan|refine-extract|orchestration-sync)[\w.-]*)(?:/|\.md$|$)')
# P-1 / P-7: an output a command will write, or an example, is not a claim that the file exists now.
FUTURE_CTX = re.compile(r'\b(?:writes?|written|creates?|created|generat\w*|outputs?|produces?|emits?|will|lands?|'
                        r'if present|when present|optional|e\.g\.|for example|such as|gitignored|ignored)\b', re.I)
FOREIGN_LINE, FOREIGN_FILE = K.FOREIGN_LINE, K.FOREIGN_FILE
ORACLE_FILE = re.compile(r'^(?:\.claude/)?_(?:extracted-[\w-]+|refine-extract|setup-quality)\.md$')
KNOWLEDGE_XREF = re.compile(r'^ai/(?:patterns|decisions|runbooks|core)/')
ADR_ID = re.compile(r'\bADR[- ]?0*(\d{1,4})\b')
SLASH = re.compile(r'(?<![\w./:@~\-\]\)>])/([a-z][a-z0-9]*(?:[-:][a-z0-9]+)*)(?![\w/.\-])')
AGENT = re.compile(r'(?<![\w@./-])@([a-z][a-z0-9]*(?:-[a-z0-9]+)+)(?![\w/.@-])')
PM = re.compile(r'\b(pnpm|npm|yarn|bun)((?:\s+(?:-r|--recursive|-w|--workspace-root|-s|--silent|--if-present|--parallel'
                r'|(?:--filter|-F|-C|--dir|--prefix|--cwd|--workspace)(?:=|\s+)\S+))*)\s+(run\s+|run-script\s+)?([A-Za-z][\w:.-]*)')
MAKE = re.compile(r'\b(make|just)\s+([A-Za-z][\w.-]*)')
PM_BUILTIN = set('''install i add remove rm uninstall un update up upgrade exec dlx x create init ci audit outdated list ls why
publish pack link unlink store prune rebuild config set get env info view show login logout whoami version help import
patch patch-commit approve-builds setup fetch deploy dedupe licenses doctor root bin cache explain fund owner search star
team token unpublish workspace workspaces node test t start restart stop -v --version'''.split())
CC_BUILTIN = set('''help clear compact memory init doctor config model review agents mcp hooks permissions login logout status
cost resume add-dir bug terminal-setup vim release-notes pr-comments export context rewind statusline ide install-github-app
upgrade plugin plugins output-style security-review todos usage sandbox privacy-settings fast effort exit quit loop schedule
skills migrate-installer feedback ultrareview code-review simplify fewer-permission-prompts artifacts'''.split())
PASCAL = re.compile(r'^[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]*)+$')
CAMEL = re.compile(r'^[a-z][a-z0-9]*(?:[A-Z][a-z0-9]*)+$')
USNAKE = re.compile(r'^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+$')
DOTTED = re.compile(r'^([A-Za-z_]\w*)\.([A-Za-z_]\w*)$')
NOT_RECEIVER = set('this self req res request response process console JSON Math Object Promise Array String Number Date '
                   'window document em qb ctx app module exports cls super Reflect Symbol Error'.split())


def norm_path(c):
    c = c.strip().strip('"\'').rstrip('.,;:)')
    c = LINESUF.sub('', c)
    if re.match(r'^@(?:\.{0,2}/|\.[\w-]|~/)', c):
        c = c[1:]                                      # a CLAUDE.md `@path` import names the path after the @
    return c


def path_candidate(c, repo, top):
    """True when the token is a repository path claim, not prose that happens to hold a slash."""
    if not c or SKIP.search(c) or len(c) > 200:
        return False
    if c.startswith('@') and c.count('/') == 1 and c not in repo.members():
        return False                                  # a bare npm package name
    if not PATHLIKE.match(c):
        return False
    body = K.rel_body(c)
    if re.search(r'\.' + EXT + r'$', body) or body.endswith('/'):
        return True
    first = body.split('/')[0]
    # No extension and no trailing slash: a path only when it starts at a known root; otherwise it is
    # far more often an API route (`orders/:id/items`), a key (`ar/en`) or prose (`read/write`).
    return first in top or first in ('.claude', '.github', 'ai', 'docs', 'src', 'apps', 'packages', 'libs', 'scripts')


class Universe(object):
    """Every name a slash command, @agent or skill reference may resolve to (P-23)."""

    def __init__(self, repo, gdir):
        self.cmds, self.agents, self.skills, self.catalog_cmds, self.catalog_agents, self.catalog_skills = (
            set(), set(), set(), set(), set(), set())
        self.global_read = False

        def stems(d, sub=False):
            out = set()
            if not os.path.isdir(d):
                return out
            for dp, dn, fn in os.walk(d):
                dn[:] = [x for x in dn if x not in K.SKIP_DIRS]
                for f in fn:
                    if f.endswith('.md') and not f.startswith('_'):
                        rel = os.path.relpath(os.path.join(dp, f), d)
                        stem = rel[:-3].replace(os.sep, ':')
                        out.add(stem)
                        out.add(os.path.basename(stem))
                if not sub:
                    break
            return out

        def skill_dirs(d):
            return set(x for x in (os.listdir(d) if os.path.isdir(d) else []) if os.path.isdir(os.path.join(d, x)))

        r = repo.root
        self.cmds |= stems(os.path.join(r, '.claude/commands'), True)
        self.agents |= stems(os.path.join(r, '.claude/agents'), True)
        self.skills |= skill_dirs(os.path.join(r, '.claude/skills'))
        if gdir and os.path.isdir(gdir):
            self.global_read = True
            self.cmds |= stems(os.path.join(gdir, 'commands'), True)
            self.agents |= stems(os.path.join(gdir, 'agents'), True)
            self.skills |= skill_dirs(os.path.join(gdir, 'skills'))
            plug = os.path.join(gdir, 'plugins')
            if os.path.isdir(plug):
                for dp, dn, fn in os.walk(plug):
                    dn[:] = [x for x in dn if x not in K.SKIP_DIRS]
                    if os.path.basename(dp) == 'commands':
                        self.cmds |= set(f[:-3] for f in fn if f.endswith('.md'))
                    if os.path.basename(dp) == 'agents':
                        self.agents |= set(f[:-3] for f in fn if f.endswith('.md'))
                    if os.path.basename(dp) == 'skills':
                        self.skills |= set(dn)
            packs = os.path.join(gdir, 'templates', 'packs')
            if os.path.isdir(packs):
                for p in os.listdir(packs):
                    self.catalog_cmds |= stems(os.path.join(packs, p, 'commands'))
                    self.catalog_agents |= stems(os.path.join(packs, p, 'agents'))
                    self.catalog_skills |= skill_dirs(os.path.join(packs, p, 'skills'))
            base = os.path.join(gdir, 'templates', 'repo-baseline', '.claude')
            self.catalog_cmds |= stems(os.path.join(base, 'commands'))
            self.catalog_agents |= stems(os.path.join(base, 'agents'))


def scripts_universe(repo):
    """{script name: [member dirs]} from every tracked package.json; Makefile/justfile targets."""
    scripts, targets = {}, set()
    for f in repo.files:
        b = os.path.basename(f)
        if '/node_modules/' in '/' + f:
            continue
        if b == 'package.json':
            j = K.read_jsonc(os.path.join(repo.root, f))
            if isinstance(j, dict) and isinstance(j.get('scripts'), dict):
                for s in j['scripts']:
                    scripts.setdefault(s, []).append(os.path.dirname(f) or '.')
        elif b in ('Makefile', 'makefile', 'GNUmakefile', 'justfile', 'Justfile'):
            for l in repo.lines(f) or []:
                m = re.match(r'^([A-Za-z][\w.-]*)\s*(?:[\w\s-]*)?:(?!=)', l)
                if m:
                    targets.add(m.group(1))
    return scripts, targets


def collect(repo, files, classes, only):
    """Yield (sec, file, line, kind, token, in_fence, text) reference events from live lines."""
    top = repo.top_dirs()
    for rel, scope in files:
        lines = repo.lines(rel)
        if lines is None:
            continue
        live = K.live_lines(rel, lines, scope == 'pack-body')
        for ln, in_fence in sorted(live.items()):
            if only and (rel, ln) != only:
                continue
            text = lines[ln - 1]
            seen = set()
            if 1 in classes or 4 in classes or 5 in classes:
                toks = [m.group(1) for m in TICK.finditer(text)] if not in_fence else []
                toks += [m.group(1) for m in LINK.finditer(text)] + [m.group(1) for m in HREF.finditer(text)]
                m = REFDEF.match(text)
                if m:
                    toks.append(m.group(1))
                if in_fence:
                    toks += [m.group(1) for m in FENCE_PATH.finditer(text)]
                for t in toks:
                    for piece in ([t] if in_fence else re.split(r'\s+(?:->|→)\s+', t)):
                        c = norm_path(piece)
                        if c in seen or not path_candidate(c, repo, top):
                            continue
                        seen.add(c)
                        yield ('path', rel, ln, c, in_fence, text)
            if 2 in classes and not in_fence:
                for m in TICK.finditer(text):
                    s = m.group(1).strip().rstrip(';')
                    s = re.sub(r'\(\)$', '', s)
                    dm = DOTTED.match(s)
                    if s in ('Class.method', 'Foo.bar', 'obj.method', 'MyClass', 'myFunction', 'fooBar', 'FooBar'):
                        continue                               # P-4 placeholders
                    if dm and dm.group(1) not in NOT_RECEIVER and not re.search(r'\.' + EXT + '$', s) and \
                            (PASCAL.match(dm.group(2)) or CAMEL.match(dm.group(2)) or USNAKE.match(dm.group(2))):
                        yield ('symbol', rel, ln, s, in_fence, text)
                    elif PASCAL.match(s) or CAMEL.match(s) or USNAKE.match(s):
                        yield ('symbol', rel, ln, s, in_fence, text)
            if 3 in classes:
                spans = [text] if in_fence else [m.group(1) for m in TICK.finditer(text)]
                for sp in spans:                      # a command is a claim only in code: a fence line or a backtick span
                    sp = re.sub(r'^\s*(?:\$\s+)?(?:(?:cd|export)\s+\S+\s*(?:&&|;)\s*)*', '', sp)
                    if not re.match(r'(?:pnpm|npm|yarn|bun|make|just)\b', sp):
                        continue                      # `# this just died` in a shell comment is prose, not a command
                    for m in PM.finditer(sp[:sp.find('|') if '|' in sp else len(sp)]):
                        if sp[m.end():m.end() + 1] == '/' or re.search(r'\.(?:[cm]?[jt]s|py|sh)$', m.group(4)):
                            continue                  # `bun run scripts/x.ts` runs a file, not a package script
                        yield ('script', rel, ln, (m.group(1), m.group(2) or '', bool(m.group(3)), m.group(4)), in_fence, text)
                    for m in MAKE.finditer(sp):
                        if m.start() != 0:
                            continue
                        yield ('make', rel, ln, (m.group(1), m.group(2)), in_fence, text)
                if not in_fence:
                    for m in SLASH.finditer(text):
                        yield ('slash', rel, ln, m.group(1), in_fence, text)
                    for m in AGENT.finditer(text):
                        yield ('agent', rel, ln, m.group(1), in_fence, text)
                    for m in re.finditer(r'`([a-z][a-z0-9]*(?:-[a-z0-9]+)+)`\s+skill\b|\bskill\s+`([a-z][a-z0-9]*(?:-[a-z0-9]+)+)`', text):
                        yield ('skill', rel, ln, m.group(1) or m.group(2), in_fence, text)
            if 4 in classes and not in_fence:
                for m in ADR_ID.finditer(text):
                    yield ('adr', rel, ln, int(m.group(1)), in_fence, text)


def sev_for(rel, base):
    up = {'L': 'M', 'M': 'H', 'H': 'H'}
    return up[base] if (K.loaded_every_session(rel) or rel.startswith(K.PACK_BODY_DIRS)) else base


NOT_SOURCE = re.compile(r'\.(md|mdx|markdown|lock|png|jpe?g|gif|webp|avif|ico|svg|pdf|woff2?|ttf|otf|eot|zip|gz|tgz|mp4|mp3|'
                        r'wav|snap|map)$|(^|/)(ai|docs|\.claude|\.cursor|node_modules)/|-lock\.(yaml|json)$|(^|/)yarn\.lock$')
COMMENT_LINE = re.compile(r'^[ \t]*(?://|#|\*|/\*|<!--|--|;).*$', re.M)
IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')


def symbol_presence(repo, syms):
    """(found in live code, found only in comment lines, P-12). One read of every tracked, non-doc,
    non-binary file under 2 MB, tokenised in Python: measured 1.9 s over 12,215 files (68 MB) on a real
    monorepo, where `git grep -w -F -f` with 911 patterns ran past 5 minutes."""
    names = set()
    for s in syms:
        names.update(s.split('.'))
    code, comment = set(), set()
    for f in repo.files:
        if NOT_SOURCE.search(f):
            continue
        p = os.path.join(repo.root, f)
        try:
            if os.path.getsize(p) > 2 * 1024 * 1024:
                continue
            with open(p, 'rb') as fh:
                data = fh.read()
        except OSError:
            continue
        if b'\0' in data[:8000]:
            continue
        text = data.decode('utf-8', 'replace')
        hit = set(IDENT.findall(text)) & names
        if not hit:
            continue
        com = '\n'.join(m.group(0) for m in COMMENT_LINE.finditer(text))
        live = set(IDENT.findall(COMMENT_LINE.sub('', text))) & hit
        code |= live
        comment |= (set(IDENT.findall(com)) & hit) - live
    found = set(s for s in syms if all(p in code for p in s.split('.')))
    only_comment = set(s for s in syms if s not in found and all(p in code or p in comment for p in s.split('.')))
    return found, only_comment


def symbol_history(repo, syms, max_commits=3000):
    """{sym: ('RENAMED', successor) | ('DELETED', sha) | ('NEVER', '')} for every dead symbol, from ONE
    streamed `git log -p -U0 --diff-filter=MDR` pass over the last <max_commits> commits, newest first
    (the latest removal wins). Added files are filtered out, so an import commit costs nothing; -U0
    keeps only changed lines. ReCite: the successor is an identifier the same commit added that shares
    name parts and shape with the removed one. A symbol no commit ever removed never existed here (P-5)."""
    res = dict((s, ('NEVER', '')) for s in syms)
    want = set(s.split('.')[-1] for s in syms)
    if not want or not repo.has_git:
        return res
    done = {}
    cmd = ['git', '-C', repo.root, '-c', 'core.quotepath=off', '-c', 'core.fsmonitor=false', 'log', '-p', '-U0', '--no-color', '--no-ext-diff', '-M',
           '--diff-filter=MDR', '--format=@@@%H', '--max-count=%d' % max_commits, '--', '.', ':(exclude)*.md',
           ':(exclude)*.mdx', ':(exclude)ai/**', ':(exclude)docs/**', ':(exclude).claude/**', ':(exclude)*.lock',
           ':(exclude)*-lock.yaml', ':(exclude)*-lock.json', ':(exclude)*.snap', ':(exclude)*.svg']

    memo = {}

    def parts_of(t):
        v = memo.get(t)
        if v is None:
            v = memo[t] = frozenset(x.lower() for x in re.findall(r'[A-Z]?[a-z0-9]+|[A-Z]+(?![a-z])', t))
        return v

    def settle(sha, rem_tokens, add_tokens):
        hit = (rem_tokens & want) - set(done)
        if not hit:
            return
        by_part = {}
        for t in add_tokens - rem_tokens:
            for x in parts_of(t):
                by_part.setdefault(x, set()).add(t)
        for n in hit:
            shape = PASCAL if PASCAL.match(n) else CAMEL if CAMEL.match(n) else USNAKE if USNAKE.match(n) else None
            parts = parts_of(n)
            cands = set()
            for x in parts:
                cands |= by_part.get(x, set())
            best, score = None, 0
            for t in sorted(cands):
                if t == n or (shape is not None and not shape.match(t)):
                    continue
                ov = len(parts & parts_of(t))
                if ov * 2 >= len(parts) and ov > score:
                    best, score = t, ov
            done[n] = ('RENAMED', best) if best else ('DELETED', sha)

    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=K.GIT_ENV)
    except OSError:
        return res
    sha, rem, add = '', set(), set()
    tok = re.compile(r'[A-Za-z_]\w*')
    for raw in p.stdout:
        line = raw.decode('utf-8', 'replace')
        if line.startswith('@@@'):
            if sha:
                settle(sha, rem, add)
                if len(done) == len(want):
                    break
            sha, rem, add = line[3:13], set(), set()
        elif line.startswith('-') and not line.startswith('---'):
            rem.update(tok.findall(line))
        elif line.startswith('+') and not line.startswith('+++'):
            add.update(tok.findall(line))
    else:
        if sha:
            settle(sha, rem, add)
    p.kill() if p.poll() is None else None
    p.wait()
    for s in syms:
        res[s] = done.get(s.split('.')[-1], ('NEVER', ''))
    return res


def scan(root, classes=(1, 2, 3, 4, 5, 6), only=None, corpus_list=None, gdir=None, history=True,
         expand=False, show_all=False):
    repo = K.Repo(root)
    files = K.corpus(repo, corpus_list)
    by_scope = {}
    for _, s in files:
        by_scope[s] = by_scope.get(s, 0) + 1
    K.ledger('census=%s files=%d head=%s' % (repo.census, len(repo.files), repo.head_sha()[:10] or 'none'))
    K.ledger('corpus: %d files · live %d · pack-body (anchor region only, P-10) %d · history excluded (P-3) %d · '
             'sinks -> memory-hygiene-scan %d' % (len(files), by_scope.get('live', 0), by_scope.get('pack-body', 0),
                                                 by_scope.get('history', 0), by_scope.get('sink', 0)))
    scan_files = [(r, s) for r, s in files if s in ('live', 'pack-body')]
    if only:
        scan_files = [(r, s) for r, s in scan_files if r == only[0]] or [(only[0], 'live')]
    uni = Universe(repo, gdir)
    K.ledger('universe: commands %d · agents %d · skills %d · global %s · pack catalog %d commands / %d agents'
             % (len(uni.cmds), len(uni.agents), len(uni.skills), 'read (%s)' % gdir if uni.global_read else 'NOT READ',
                len(uni.catalog_cmds), len(uni.catalog_agents)))
    home, how, _ = K.adr_home(repo)
    ids = K.adr_ids(repo, home)
    scripts, targets = scripts_universe(repo)
    rows, stats = [], {}

    def bump(k):
        stats[k] = stats.get(k, 0) + 1

    def row(sec, kn, sev, rel, ln, ref, res, verdict, note=''):
        rows.append({'sec': sec, 'kn': kn, 'sev': sev, 'site': '%s:%d' % (rel, ln), 'ref': ref, 'res': res,
                     'verdict': verdict, 'note': note})

    syms = {}
    classified = 0
    hist_cache = {}
    events = list(collect(repo, scan_files, set(classes), only))
    dead_paths = set()

    def ignore_keys(tok):
        # A directory pattern (`dist/`) matches only a path git knows is a directory; the directory is absent, so the
        # trailing slash is the only thing that says so: ask with it for a slash-ended or extension-less reference.
        body = K.rel_body(tok)
        dirish = tok.rstrip().endswith('/') or not os.path.splitext(os.path.basename(body))[1]
        return (body, body + '/') if dirish and body else (body,)

    for kind, rel, ln, tok, in_fence, text in events:
        if kind == 'path' and repo.resolve(tok, rel)[0] == 'dead':
            dead_paths.update(ignore_keys(tok))
    ignored_set = repo.ignored(sorted(dead_paths))          # ONE git check-ignore for every dead candidate (P-1, P-25)
    for kind, rel, ln, tok, in_fence, text in events:
        if kind == 'path':
            bump('path refs')
            st, tgt, n = repo.resolve(tok, rel)
            bump('path ' + st)
            if st in ('exact', 'relative', 'alias', 'package'):
                continue
            if st == 'abbrev':
                if show_all:
                    row(1, 'KN-01', 'L', rel, ln, tok, 'abbrev -> ' + tgt, 'info', 'P-6 unique suffix')
                continue
            if st == 'ambiguous':
                if show_all:
                    row(1, 'KN-01', 'L', rel, ln, tok, 'ambiguous suffix (%d)' % n, 'info', 'P-6: not dead; name the full path')
                continue
            if st == 'dead' and any(k in ignored_set for k in ignore_keys(tok)):
                st = 'ignored'
            if st in ('untracked', 'ignored'):
                if show_all:
                    row(1, 'KN-01', 'L', rel, ln, tok, st, 'info', 'P-1/P-25 present on disk, not tracked' if st == 'untracked'
                        else 'P-1/P-25 gitignored: a local file or build output, never tracked')
                continue
            body = K.rel_body(tok)
            if FOREIGN_LINE.search(text) or FOREIGN_FILE.search(rel):
                bump('dead foreign-codebase (P-8, ignored)')
                continue
            if ORACLE_FILE.match(body):
                row(1, 'KN-19', 'M', rel, ln, tok, 'oracle file absent', 'unconfirmed',
                    'the extraction oracle was never written or was removed: context-load-scan §4')
                continue
            if 5 in classes and FRAMEWORK.match(body):
                fw = gdir and os.path.exists(os.path.join(gdir, body))
                row(5, 'KN-05', 'M', rel, ln, tok, 'framework path' + (' (exists under %s)' % gdir if fw else ''),
                    'candidate' if fw or body.startswith(('scripts/', 'templates/', '.claude/_')) else 'unconfirmed',
                    'a Refract repo path, absent from this project')
                continue
            full = os.path.normpath(os.path.join(os.path.dirname(rel), body)).replace(os.sep, '/') \
                if ('/' not in body and body.endswith('.md')) else body
            if 5 in classes and gdir and re.match(r'^[a-z][\w-]*/(?:rules|commands|agents|skills|ai-patterns)/', body) and \
                    os.path.isdir(os.path.join(gdir, 'templates', 'packs', body.split('/')[0])):
                row(5, 'KN-05', 'M', rel, ln, tok, 'pack-relative framework path', 'candidate',
                    'names a Refract pack file; an installed copy lives under .claude/')
                continue
            if KNOWLEDGE_XREF.match(full):
                body = full
            sec, kn = (4, 'KN-04') if KNOWLEDGE_XREF.match(body) else (1, 'KN-01')
            if sec not in classes:
                continue
            if history:
                if body not in hist_cache:
                    hist_cache[body] = repo.path_history(body)
                    classified += 1
                h, what = hist_cache[body]
            else:
                h, what = ('NOT-CLASSIFIED', '')
            bump('dead ' + h)
            if h == 'RENAMED':
                row(sec, kn, sev_for(rel, 'M'), rel, ln, tok, 'RENAMED -> ' + what, 'candidate', 'repoint')
            elif h == 'DELETED':
                row(sec, kn, sev_for(rel, 'M'), rel, ln, tok, 'DELETED in ' + what, 'candidate', 'delete the line or re-point by hand')
            elif h == 'NEVER-EXISTED' and kn == 'KN-04':
                row(sec, kn, 'M', rel, ln, body, 'never installed', 'candidate', 'cited pattern/ADR file is not in the repo')
            elif h == 'NEVER-EXISTED' and '/' not in body:
                bump('dead bare name never in history (P-4 shape example, info)')
                if show_all:
                    row(sec, kn, 'L', rel, ln, tok, 'bare name, never in history', 'info', 'P-4: a naming example, not a location')
            elif FUTURE_CTX.search(text):
                bump('dead never-existed in an output/example context (P-1/P-7, info)')
                if show_all:
                    row(sec, kn, 'L', rel, ln, tok, h.lower(), 'info', 'P-1/P-7 output or example')
            else:
                row(sec, kn, sev_for(rel, 'M'), rel, ln, tok, h.lower(), 'unconfirmed',
                    'P-7 planned? or a path the author never checked')
        elif kind == 'symbol':
            syms.setdefault(tok, []).append((rel, ln))
        elif kind == 'script':
            pm, flags, has_run, name = tok
            bump('script refs')
            if name in PM_BUILTIN and not has_run:
                continue
            if name in scripts:
                continue
            if name in ('test', 'start') and not has_run and pm == 'npm':
                continue
            row(3, 'KN-03', sev_for(rel, 'H'), rel, ln, '%s%s %s%s' % (pm, re.sub(r'\s+', ' ', flags.rstrip()), 'run ' if has_run else '', name),
                'no package.json script', 'candidate' if scripts else 'unconfirmed',
                'scripts known: %d across %d manifests' % (len(scripts), len(set(d for v in scripts.values() for d in v))))
        elif kind == 'make':
            tool, name = tok
            bump('make refs')
            if name not in targets:
                row(3, 'KN-03', sev_for(rel, 'H'), rel, ln, '%s %s' % (tool, name), 'no target',
                    'candidate' if targets else 'unconfirmed', 'no Makefile/justfile' if not targets else '')
        elif kind in ('slash', 'agent', 'skill'):
            bump(kind + ' refs')
            name = tok
            if kind == 'slash':
                if name in uni.cmds or name in uni.skills or name in CC_BUILTIN:
                    continue
                if name in uni.catalog_cmds or name in uni.catalog_skills:
                    row(3, 'KN-03', sev_for(rel, 'M'), rel, ln, '/' + name, 'uninstalled (in the Refract catalog)', 'candidate')
                elif re.search(r'\b(?:run|invoke|call|type|dispatch|use)\s+`?/' + re.escape(name) + r'\b|`/' + re.escape(name)
                               + r'(?:\s[^`]*)?`\s+(?:command|slash)', text, re.I):
                    row(3, 'KN-03', sev_for(rel, 'M'), rel, ln, '/' + name, 'unknown command', 'unconfirmed')
                else:
                    bump('slash route-like (ignored)')
            elif kind == 'agent':
                if name in uni.agents:
                    continue
                if name in uni.catalog_agents:
                    row(3, 'KN-03', sev_for(rel, 'M'), rel, ln, '@' + name, 'uninstalled agent (in the Refract catalog)', 'candidate')
                elif not uni.global_read and not uni.agents:
                    continue
                else:
                    row(3, 'KN-03', 'L', rel, ln, '@' + name, 'unknown agent', 'unconfirmed')
            else:
                if name in uni.skills:
                    continue
                v = 'candidate' if name in uni.catalog_skills else 'unconfirmed'
                row(3, 'KN-03', sev_for(rel, 'M'), rel, ln, name, 'skill not installed', v)
        elif kind == 'adr':
            bump('adr refs')
            if home is None:
                bump('adr no-home')
                continue
            if tok not in ids:
                row(4, 'KN-04', sev_for(rel, 'M'), rel, ln, 'ADR-%04d' % tok, 'no file in %s (%s)' % (home, how), 'candidate')
    # §2 symbols — one presence pass, then DOCER + ReCite on the dead ones.
    if syms:
        found, comment_only = symbol_presence(repo, set(syms))
        bump_n = len(syms)
        stats['symbol refs'] = bump_n
        stats['symbol present'] = len(found)
        dead = [s for s in syms if s not in found]
        hist = symbol_history(repo, dead) if (repo.has_git and history) else {}
        for s, sites in sorted(syms.items()):
            if s in found:
                continue
            h, what = hist.get(s, ('NOT-CLASSIFIED', ''))
            stats['symbol ' + h] = stats.get('symbol ' + h, 0) + 1
            if h == 'NEVER':
                continue                                   # P-5: external or framework symbol
            for rel, ln in sites:
                if h == 'RENAMED':
                    res = 'RENAMED -> ' + what + (' (survives only in a comment, P-12)' if s in comment_only else '')
                    row(2, 'KN-02', sev_for(rel, 'M'), rel, ln, s, res, 'candidate', 'repoint')
                elif h == 'DELETED':
                    row(2, 'KN-02', sev_for(rel, 'M'), rel, ln, s, 'DELETED in ' + what, 'candidate',
                        'comment-only survivor (P-12)' if s in comment_only else '')
                else:
                    row(2, 'KN-02', 'L', rel, ln, s, 'not classified', 'unconfirmed', 'history not read (--no-history or no git)')
    # §6 marker corruption (KN-15) over every file that carries markers.
    if 6 in classes:
        for rel, scope in files:
            if only and rel != only[0]:
                continue
            lines = repo.lines(rel) or []
            regions, problems = K.anchor_scan(lines)
            for ln, kind in problems:
                row(6, 'KN-15', 'M', rel, ln, 'project-specific marker', kind, 'candidate', 'fix in apply-anchors.sh (IR-1)')
            if len(regions) > 1:
                ph = sum(1 for a, b in regions if any('...content...' in lines[i - 1] for i in range(a, b + 1)))
                row(6, 'KN-15', 'M', rel, regions[1][0], 'project-specific marker', 'duplicate live blocks (%d)' % len(regions),
                    'candidate', ('%d placeholder block(s)' % ph) if ph else 'one file, one live anchor block')
    for k in sorted(stats):
        K.ledger('  %-34s %d' % (k, stats[k]))
    K.ledger('classified with git history: %d dead paths (one name-status pass) · %d dead symbols (one pickaxe pass)'
             % (classified, sum(v for k, v in stats.items() if k.startswith('symbol ') and k.split()[1] in ('RENAMED', 'DELETED', 'NEVER'))))
    K.ledger('ADR home: %s (%s)' % (home or 'none', how))
    return group(rows, expand)


def group(rows, expand):
    if expand:
        for r in rows:
            r['sites'] = 1
        return rows
    out, idx = [], {}
    for r in rows:
        key = (r['sec'], r['kn'], r['ref'], r['res'], r['verdict'])
        if key in idx:
            g = idx[key]
            g['sites'] += 1
            g['_all'].append(r['site'])
            order = {'H': 0, 'M': 1, 'L': 2}
            if order[r['sev']] < order[g['sev']]:
                g['sev'] = r['sev']
        else:
            g = dict(r)
            g['sites'] = 1
            g['_all'] = [r['site']]
            idx[key] = g
            out.append(g)
    for g in out:
        if g['sites'] > 1:
            g['note'] = (g['note'] + '; ' if g['note'] else '') + 'also ' + ', '.join(g['_all'][1:4]) + \
                (' …+%d' % (g['sites'] - 4) if g['sites'] > 4 else '')
        g.pop('_all', None)
    return out


def emit(rows, as_json):
    if as_json:
        print(json.dumps(rows, indent=1))
        return
    print('# §\tclass\tsev\tsite\tref\tresolution\tverdict\tsites\tnote')
    for r in sorted(rows, key=lambda r: (r['sec'], {'H': 0, 'M': 1, 'L': 2}[r['sev']], r['site'])):
        print('%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' % (r['sec'], r['kn'], r['sev'], r['site'], r['ref'], r['res'],
                                                     r['verdict'], r['sites'], r['note']))


# -------------------------------------------------------------------- self-test
def _sh(cwd, *cmd):
    env = dict(K.GIT_ENV, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1', HOME=cwd)
    subprocess.run(list(cmd), cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)


def _w(root, rel, text):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p) or root, exist_ok=True)
    with open(p, 'w') as fh:
        fh.write(text)


def self_test():
    K.QUIET = True
    tmp = tempfile.mkdtemp(prefix='kn-refs-selftest.')
    fails = []
    try:
        root = os.path.join(tmp, 'repo')
        g = os.path.join(tmp, 'global')
        os.makedirs(root)
        _w(g, 'commands/setup-project.md', '# global\n')
        _w(g, 'templates/packs/learning/commands/eval.md', '# pack\n')
        _w(g, 'templates/packs/align/agents/style-judge.md', '# pack\n')
        _w(g, 'scripts/apply-anchors.sh', '#!/bin/sh\n')
        git = lambda *a: _sh(root, 'git', '-c', 'user.name=t', '-c', 'user.email=t@t', '-c', 'commit.gpgsign=false', *a)
        git('init', '-q')
        _w(root, 'package.json', '{"name":"mono","scripts":{"test":"jest","lint":"eslint ."}}')
        _w(root, 'apps/api/package.json', '{"name":"@acme/api","scripts":{"test:e2e":"jest -c e2e"}}')
        _w(root, 'apps/web/tsconfig.json', '{ /* comment */ "compilerOptions": { "paths": { "@/*": ["src/*"] } } }')
        _w(root, 'apps/web/src/shared/client.ts', 'export const client = 1;\n')
        body = ''.join('export const rate%d = %d;\n' % (i, i) for i in range(12))
        _w(root, 'apps/api/src/old-name.service.ts', 'export class LegacyBillingService {}\n' + body)
        _w(root, 'apps/api/src/gone.helper.ts', 'export function formatLegacyCents() {}\n')
        _w(root, 'apps/api/src/shared/persistence/page-query.ts', 'export function resolvePageQuery() {}\n')
        _w(root, 'docs/decisions/0001-use-postgres.md', '# 1\nStatus: Accepted\n')
        _w(root, 'apps/web/src/ApiClient.ts', 'export const api = 1;\n')
        _w(root, '.gitignore', 'dist/\n')
        git('add', '-A')
        git('commit', '-q', '-m', 'one')
        # P-11: a case-only rename; on a case-insensitive filesystem the old spelling still opens the new file.
        git('mv', 'apps/web/src/ApiClient.ts', 'apps/web/src/apiClient.ts')
        git('mv', 'apps/api/src/old-name.service.ts', 'apps/api/src/billing.service.ts')
        _w(root, 'apps/api/src/billing.service.ts', 'export class BillingService {}\n' + body)
        git('rm', '-q', 'apps/api/src/gone.helper.ts')
        git('add', '-A')
        git('commit', '-q', '-m', 'two')
        _w(root, 'CLAUDE.md', '\n'.join([
            '# Project',
            'Billing lives in `apps/api/src/old-name.service.ts`.',               # 3 KN-01 RENAMED
            'Helpers: `apps/api/src/gone.helper.ts`.',                            # 4 KN-01 DELETED
            'Pagination: `shared/persistence/page-query.ts` (abbrev, P-6).',      # 5 decoy
            'Client: `@/shared/client` via alias.',                              # 6 decoy alias
            'See `ai/audits/2026-01-01.md` for history.',                        # 7 (target dead, but CLAUDE.md live)
            'Run `pnpm test:e2e` then `pnpm run build:all`.',                    # 8 KN-03 build:all dead; test:e2e ok
            'Then run `/eval` and `/setup-project`; the API serves `/orders`.',  # 9 /eval uninstalled; decoys
            'Call `LegacyBillingService` and `formatLegacyCents` and `ExternalThing`.',  # 10 KN-02 x2; decoy
            'Follow `ai/patterns/zero-downtime.md` and ADR-0007; ADR-0001 is fine.',      # 11 KN-04 x2
            'Placeholder `path/to/file.ts` and `<module>/x.ts` are not refs.',   # 12 decoy P-4
            '<!--',
            'Old note: `apps/api/src/never-there.ts` inside a block comment (P-21).',
            '-->',
            'Dispatch `@style-judge` when needed.',                               # 15 uninstalled agent
            'The audit writes `ai/align/ledger.md` (P-1 output).',              # 16 decoy
            'Billing helper: `src/never-was.ts`.',                                # 17 never existed -> Unconfirmed
            'Stores end in `.store.ts` (`orders.store.ts`).',                     # 18 decoy: shape example (P-4)
            'Ported from v1: `legacy/app/admin-auth.ts` (P-8).',                  # 19 decoy foreign
            'HTTP calls go through `apps/web/src/ApiClient.ts`.',                 # 20 KN-01 case-only RENAMED (P-11)
            'The web build lands in `apps/web/dist/`.',                           # 21 gitignored dir (P-25): info only
            'Reset with `pnpm --filter @acme/api db:reset`.',                    # 22 KN-03, printed with its --filter
            '']))
        _w(root, '.claude/agents/reviewer.md', '\n'.join([
            '---', 'name: reviewer', 'pack: code-quality', '---',
            'Generic body: `services.py` and `orders.repository.ts` and ADR-0042 (P-10, not claims).',
            '<!-- project-specific:start -->',
            '> Auto-populated by `scripts/apply-anchors.sh`.',                      # 7 KN-05
            '> - Base: `apps/api/src/shared/persistence/page-query.ts`.',
            '<!-- project-specific:start -->',                                     # 9 KN-15 nested
            '<!-- project-specific:end -->',
            '```',
            '<!-- project-specific:start -->',                                     # fenced: decoy
            '```',
            '']))
        _w(root, 'ai/audits/2026-01-01.md', 'Dead `apps/api/src/old-name.service.ts` in history (P-3).\n')
        _w(root, 'ai/dynamic/drift-log.md', '### 2026-01-01 — x\n- Where: `apps/api/src/gone.helper.ts`\n')
        rows = scan(root, gdir=g, expand=True)
        got = set((r['kn'], r['site'], r['ref'].split(' ')[-1] if r['kn'] == 'KN-03' else r['ref']) for r in rows if r['verdict'] != 'info')

        def want(kn, site, ref, label):
            if (kn, site, ref) not in got:
                fails.append('missing %s: %s %s %s' % (label, kn, site, ref))

        def deny(pred, label):
            bad = [r for r in rows if pred(r)]
            if bad:
                fails.append('false row %s: %s' % (label, bad[0]))

        want('KN-01', 'CLAUDE.md:2', 'apps/api/src/old-name.service.ts', 'renamed path')
        want('KN-01', 'CLAUDE.md:3', 'apps/api/src/gone.helper.ts', 'deleted path')
        want('KN-03', 'CLAUDE.md:7', 'build:all', 'dead package script')
        want('KN-03', 'CLAUDE.md:8', '/eval', 'uninstalled command')
        want('KN-02', 'CLAUDE.md:9', 'LegacyBillingService', 'renamed symbol')
        want('KN-02', 'CLAUDE.md:9', 'formatLegacyCents', 'deleted symbol')
        want('KN-04', 'CLAUDE.md:10', 'ai/patterns/zero-downtime.md', 'uninstalled pattern')
        want('KN-04', 'CLAUDE.md:10', 'ADR-0007', 'ADR id without a file')
        want('KN-03', 'CLAUDE.md:15', '@style-judge', 'uninstalled agent')
        want('KN-05', '.claude/agents/reviewer.md:7', 'scripts/apply-anchors.sh', 'framework path')
        want('KN-15', '.claude/agents/reviewer.md:9', 'project-specific marker', 'nested start')
        ren = [r for r in rows if r['ref'] == 'apps/api/src/old-name.service.ts']
        if not ren or 'billing.service.ts' not in ren[0]['res']:
            fails.append('RENAMED successor not named: %s' % ren)
        rs = [r for r in rows if r['ref'] == 'LegacyBillingService']
        if not rs or 'BillingService' not in rs[0]['res']:
            fails.append('symbol successor not named: %s' % rs)
        deny(lambda r: 'page-query' in r['ref'] and r['verdict'] != 'info', 'abbreviation P-6')
        deny(lambda r: r['ref'].startswith('@/'), 'alias')
        deny(lambda r: r['ref'] in ('/setup-project', '/orders', 'ExternalThing', 'ADR-0001', 'ADR-0042'), 'global/route/external/existing')
        deny(lambda r: 'services.py' in r['ref'] or 'orders.repository' in r['ref'], 'pack-generic body P-10')
        deny(lambda r: r['site'].startswith(('ai/audits', 'ai/dynamic')), 'history/sink scope')
        deny(lambda r: 'never-there' in r['ref'], 'HTML block comment P-21')
        deny(lambda r: 'ai/align/ledger.md' in r['ref'] or 'admin-auth' in r['ref'], 'output context P-1 / foreign codebase P-8')
        deny(lambda r: 'store.ts' in r['ref'], 'shape example P-4')
        nev = [r for r in rows if r['ref'] == 'src/never-was.ts']
        if not nev or nev[0]['verdict'] != 'unconfirmed':
            fails.append('never-existed path in a claim line is not Unconfirmed: %s' % nev)
        cr = [r for r in rows if r['ref'] == 'apps/web/src/ApiClient.ts']
        if not cr or cr[0]['kn'] != 'KN-01' or 'apiClient.ts' not in cr[0]['res']:
            fails.append('case-only rename not RENAMED to its successor (P-11): %s' % cr)
        deny(lambda r: 'apps/web/dist' in r['ref'], 'gitignored directory with a trailing slash (P-25)')
        if [r['ref'] for r in rows if r['site'] == 'CLAUDE.md:22'] != ['pnpm --filter @acme/api db:reset']:
            fails.append('KN-03 ref drops the workspace flag: %s' % [r['ref'] for r in rows if r['site'] == 'CLAUDE.md:22'])
        ign = [r for r in scan(root, gdir=g, only=('CLAUDE.md', 21), show_all=True) if 'apps/web/dist' in r['ref']]
        if not ign or ign[0]['res'] != 'ignored':
            fails.append('`dist/` pattern did not match `apps/web/dist/` (trailing slash dropped before check-ignore): %s' % ign)
        deny(lambda r: 'path/to' in r['ref'] or '<module>' in r['ref'], 'placeholder P-4')
        deny(lambda r: r['ref'] == 'pnpm test:e2e' or r['ref'].endswith(' test:e2e'), 'workspace script')
        deny(lambda r: r['kn'] == 'KN-15' and r['site'].endswith(':12'), 'fenced marker')
        only = scan(root, gdir=g, only=('CLAUDE.md', 3), expand=True)
        if [r['site'] for r in only if r['kn'] == 'KN-01'] != ['CLAUDE.md:3']:
            fails.append('--only did not isolate the site: %s' % only)
        _w(root, 'CLAUDE.md', '# fixed\nBilling lives in `apps/api/src/billing.service.ts`.\n')
        after = scan(root, gdir=g, only=('CLAUDE.md', 2), expand=True)
        if after:
            fails.append('fixed site still fires: %s' % after)
        before = set()
        for dp, dn, fn in os.walk(root):
            dn[:] = [d for d in dn if d != '.git']
            before.update(os.path.join(dp, f) for f in fn)
        scan(root, gdir=g)
        now = set()
        for dp, dn, fn in os.walk(root):
            dn[:] = [d for d in dn if d != '.git']
            now.update(os.path.join(dp, f) for f in fn)
        if now != before:
            fails.append('scan wrote into the root: %s' % sorted(now - before))
        # An untracked subtree of an enclosing repository: `git ls-files` lists nothing there, so the census walks.
        sub = os.path.join(root, 'vendor-snapshot')
        _w(sub, 'CLAUDE.md', '# Snapshot\nEntry point: `src/main.ts`; gone: `src/never-here.ts`.\n')
        _w(sub, 'src/main.ts', 'export {};\n')
        sr = K.Repo(sub)
        if sr.census != 'find-untracked' or 'src/main.ts' not in sr.fset or sr.has_git:
            fails.append('untracked subtree: census %s, %d files, has_git %s (want find-untracked, the walk, no history)'
                         % (sr.census, len(sr.files), sr.has_git))
        srows = scan(sub, gdir=g, expand=True)
        if [r['ref'] for r in srows if r['kn'] == 'KN-01'] != ['src/never-here.ts']:
            fails.append('untracked subtree: want one KN-01 row for src/never-here.ts, got %s' % [(r['kn'], r['ref']) for r in srows])
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        sys.stderr.write('self-test FAIL: %s\n' % f)
    print('knowledge-refs.py --self-test %s' % ('OK' if not fails else 'FAILED (%d)' % len(fails)))
    return 0 if not fails else 3


def main(argv):
    opts = {'classes': (1, 2, 3, 4, 5, 6), 'only': None, 'corpus': None, 'gdir': os.path.expanduser('~/.claude'),
            'history': True, 'expand': False, 'all': False, 'json': False}
    root = None
    for a in argv:
        if a == '--self-test':
            return self_test()
        elif a.startswith('--classes='):
            opts['classes'] = tuple(int(x) for x in a.split('=', 1)[1].split(',') if x.strip())
        elif a.startswith('--only='):
            f, _, l = a.split('=', 1)[1].rpartition(':')
            if not f or not l.isdigit():
                sys.stderr.write('--only needs <file>:<line>\n')
                return 2
            opts['only'] = (f, int(l))
        elif a.startswith('--corpus='):
            src = a.split('=', 1)[1]
            txt = sys.stdin.read() if src == '-' else (K.read_text(src) or '')
            opts['corpus'] = [x.strip() for x in txt.split('\n') if x.strip()]
        elif a.startswith('--global-dir='):
            opts['gdir'] = os.path.expanduser(a.split('=', 1)[1])
        elif a == '--no-global':
            opts['gdir'] = None
        elif a == '--no-history':
            opts['history'] = False
        elif a == '--expand':
            opts['expand'] = True
        elif a == '--all':
            opts['all'] = True
        elif a == '--json':
            opts['json'] = True
        elif a.startswith('-'):
            sys.stderr.write('unknown option %s\n' % a)
            return 2
        else:
            root = a
    if not root or not os.path.isdir(root):
        sys.stderr.write('usage: knowledge-refs.py <root> [options] | --self-test (blocked: no such root)\n')
        return 2
    rows = scan(root, opts['classes'], opts['only'], opts['corpus'], opts['gdir'], opts['history'],
                opts['expand'], opts['all'])
    emit(rows, opts['json'])
    return 1 if any(r['verdict'] in ('candidate', 'unconfirmed') for r in rows) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
