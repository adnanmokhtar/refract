#!/usr/bin/env python3
"""load-budget.py — context-load-scan §1-§5: what does the host ACTUALLY load at launch, is it inside each
loader's budget, does the instruction file the team maintains even get loaded, is the extraction oracle
older than the code it describes, and which files must security read?

Why loader truth and not `wc -l`: block-level HTML comments in CLAUDE.md are stripped before injection
(P-21), so a raw count overstates the load; `@` imports load at launch, so moving text into them saves
nothing; a rule without `paths:` loads every session whether or not anything imports it, and `globs:` is
not a field Claude Code reads (P-22; Refract platform facts, verified 2026-10-05 on Claude Code 2.1.236);
AGENTS.md is read only when no CLAUDE.md or CLAUDE.local.md exists at or above the working directory, so
a 656-line AGENTS.md beside a CLAUDE.md that never imports it is loaded by another tool only (memory
docs, code.claude.com/docs/en/memory, fetched 2026-10-19).

Usage:  python3 -I load-budget.py <root> [--classes=1,2,3,4,5] [--memory-dir=<dir>] [--rule-budget=12000]
                  [--claude-max=200] [--ai-max-files=50] [--ai-max-lines=300] [--security-list] [--json]
        python3 -I load-budget.py --self-test
Budgets and their sources (never invented here):
  CLAUDE.md effective lines <= 200 — Claude Code memory docs ("under 200 lines per CLAUDE.md file");
  @import depth <= 4 hops, relative to the importing file — memory docs, fetched 2026-10-19;
  always-loaded rule tokens <= 12,000 (bytes / 4) — Refract audit-setup.sh C2u (RULE_BUDGET_TOKENS);
  MEMORY.md: only the first 200 lines or 25,600 bytes load — memory docs (read only with --memory-dir, O-3);
  Copilot code review reads the first 4,000 characters of each instruction file — GitHub docs, fetched 2026-10-19;
  Cursor rule <= 500 lines — Cursor docs (undated);
  ai/ <= 50 files, ai/<file> <= 300 lines (non-ADR, non-history), .claude/rules <= 30 files — Refract
  /setup-project-health check 4 (templates/idempotency.md budgets).
Classes: 1 loader-truth budget (KN-31) · 2 CLAUDE.md / AGENTS.md selection (KN-32) · 3 vague-lexicon
advisory (KN-33: never a Finding) · 4 oracle freshness and approval (KN-19; KN-16/18 counts for the baseline
owner) · 5 the context-file list security reads (KN-34/35 are security's; this prints the list and a
hidden-Unicode handoff count, never a verdict).

OUTPUT: TSV `# § class sev site subject finding verdict note` (or --json). verdict candidate | unconfirmed
| advisory | handoff | info. Exit: 0 no candidate/unconfirmed row · 1 rows · 2 blocked (no root) · 3 self-test
failed. Stdlib only, Python >= 3.8, `python3 -I` safe; read-only git with GIT_OPTIONAL_LOCKS=0; writes
nothing under <root>.
"""
import sys
sys.dont_write_bytecode = True
import hashlib
import json
import os
import re
import shutil
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

IMPORT = re.compile(r'(?<![\w`@/])@((?:\.{1,2}/|~/|/)?[\w.-][\w./-]*\.(?:md|mdc|txt))\b|(?<![\w`@/])@((?:\.{1,2}/)?[\w-]+/[\w./-]+)')
VAGUE = re.compile(r'\b(clean(?:ly)?|proper(?:ly)?|best practices?|appropriate(?:ly)?|careful(?:ly)?|as needed|where possible|'
                   r'robust|nice|elegant|reasonable|sensible|good)\b', re.I)
HIDDEN = re.compile(u'[‪-‮⁦-⁩​-‍⁠﻿]')
RTL = re.compile(u'[֐-ࣿיִ-﷿ﹰ-﻿]')


def effective(lines):
    """Lines after dropping block-level HTML comments (outside fences), as Claude Code injects them."""
    out, fence, com = [], False, False
    for l in lines:
        if K.FENCE_RE.match(l):
            fence = not fence
        if not fence:
            s = l.strip()
            if com:
                if '-->' in s:
                    com = False
                continue
            if s.startswith('<!--'):
                if '-->' not in s:
                    com = True
                continue
        out.append(l)
    return out


def imports_of(repo, rel, lines):
    out, fence = [], False
    for i, l in enumerate(lines, 1):
        if K.FENCE_RE.match(l):
            fence = not fence
            continue
        if fence:
            continue
        for m in IMPORT.finditer(re.sub(r'`[^`]*`', '', l)):
            out.append((i, m.group(1) or m.group(2)))
    return out


def closure(repo, start):
    """{file: hops} reachable by @imports from start (max 4 hops), plus [(site, target)] dead imports."""
    seen, dead, todo = {start: 0}, [], [start]
    while todo:
        f = todo.pop(0)
        if seen[f] >= 4:
            continue
        for ln, tgt in imports_of(repo, f, repo.lines(f) or []):
            if tgt.startswith('~/'):
                continue                                   # a home-directory import: outside the repo, not read
            p = os.path.normpath(os.path.join(os.path.dirname(f), tgt)).replace(os.sep, '/') if not tgt.startswith('/') else tgt.lstrip('/')
            if p.startswith('..') or not repo.exists_on_disk(p):
                dead.append(('%s:%d' % (f, ln), tgt))
                continue
            if p not in seen:
                seen[p] = seen[f] + 1
                todo.append(p)
    return seen, dead


def scan(root, classes=(1, 2, 3, 4, 5), memory_dir=None, rule_budget=12000, claude_max=200, ai_max_files=50, ai_max_lines=300):
    repo = K.Repo(root)
    rows = []

    def row(sec, kn, sev, site, subj, finding, verdict, note=''):
        rows.append({'sec': sec, 'kn': kn, 'sev': sev, 'site': site, 'subject': subj, 'finding': finding,
                     'verdict': verdict, 'note': note})

    claude = [f for f in ('CLAUDE.md', '.claude/CLAUDE.md', 'CLAUDE.local.md') if repo.exists_on_disk(f)]
    loaded = {}
    dead_imports = []
    for c in claude:
        seen, dead = closure(repo, c)
        loaded.update(seen)
        dead_imports += dead
    K.ledger('census=%s · CLAUDE files: %s · @import closure: %d file(s)' % (repo.census, ', '.join(claude) or 'none', len(loaded)))
    # §1 loader truth
    if 1 in classes:
        for c in claude:
            ls = repo.lines(c) or []
            eff = effective(ls)
            note = 'raw %d, %d in HTML block comments (P-21)' % (len(ls), len(ls) - len(eff)) if len(ls) != len(eff) else ''
            if len(eff) > claude_max:
                row(1, 'KN-31', 'M', c + ':1', c, '%d effective lines (budget %d)' % (len(eff), claude_max), 'candidate',
                    (note + '; ' if note else '') + 'move detail into ai/ docs or path-scoped rules; @imports load too')
            else:
                K.ledger('  %s: %d effective lines (budget %d)%s' % (c, len(eff), claude_max, ' · ' + note if note else ''))
        launch = sum(len(effective(repo.lines(f) or [])) for f in loaded)
        if loaded and len(loaded) > len(claude):
            K.ledger('  launch load via imports: %d lines across %d files' % (launch, len(loaded)))
            if launch > claude_max:
                row(1, 'KN-31', 'M', claude[0] + ':1', '@import closure', '%d lines load at launch across %d files' % (launch, len(loaded)),
                    'candidate', 'imports load at launch: splitting CLAUDE.md into them saves nothing')
        for site, tgt in dead_imports:
            row(1, 'KN-31', 'M', site, '@' + tgt, 'import target does not exist', 'candidate', 'a dead import loads nothing')
        always, scoped, globs_only, tok = [], 0, [], 0
        rule_files = sorted(f for f in set(repo.files) | set(walk(repo, '.claude/rules')) if f.startswith('.claude/rules/') and f.endswith('.md'))
        for f in rule_files:
            fm = K.frontmatter(repo.lines(f) or [])
            if 'paths' in fm:
                scoped += 1
                continue
            always.append(f)
            try:
                tok += os.path.getsize(os.path.join(repo.root, f)) // 4
            except OSError:
                pass
            if 'globs' in fm:
                globs_only.append(f)
        K.ledger('  rules: %d always-loaded (~%d tok, budget %d) · %d path-scoped · %d globs:-only' % (
            len(always), tok, rule_budget, scoped, len(globs_only)))
        if tok > rule_budget:
            row(1, 'KN-31', 'M', '.claude/rules:0', 'always-loaded rules', '~%d tokens in %d files (budget %d)' % (tok, len(always), rule_budget),
                'candidate', 'path-scope the rules that govern a slice of the tree (`paths:`)')
        for f in globs_only:
            row(1, 'KN-31', 'L', f + ':1', 'globs:', '`globs:` is not read by Claude Code: this rule loads every session', 'candidate',
                'P-22: write `paths:` to scope it')
        if len(rule_files) > 30:
            row(1, 'KN-31', 'L', '.claude/rules:0', '.claude/rules', '%d rule files (health check 4: warn > 30)' % len(rule_files), 'candidate')
        for f in ['.github/copilot-instructions.md'] + sorted(x for x in repo.files if x.startswith('.github/instructions/')):
            if repo.exists_on_disk(f):
                n = len('\n'.join(repo.lines(f) or []))
                if n > 4000:
                    row(1, 'KN-31', 'M', f + ':1', f, '%d characters; Copilot code review reads the first 4,000' % n, 'candidate',
                        'move the rules review must see into the first 4,000 characters')
        for f in sorted(x for x in repo.files if x.startswith('.cursor/rules/')):
            n = len(repo.lines(f) or [])
            if n > 500:
                row(1, 'KN-31', 'L', f + ':1', f, '%d lines (Cursor: keep a rule under 500)' % n, 'candidate')
        ai_files = sorted(set(x for x in repo.files if x.startswith('ai/')) | set(walk(repo, 'ai')))
        if ai_files:
            hist = [f for f in ai_files if K.HISTORY_RE.match(f)]
            big = [(len(repo.lines(f) or []), f) for f in ai_files if f.endswith('.md') and not K.ADR_FILE.match(os.path.basename(f))]
            big_live = sorted([b for b in big if b[0] > ai_max_lines and not K.HISTORY_RE.match(b[1])], reverse=True)
            big_hist = [b for b in big if b[0] > ai_max_lines and K.HISTORY_RE.match(b[1])]
            K.ledger('  ai/: %d files (%d history) · %d files over %d lines (%d of them history)' % (
                len(ai_files), len(hist), len(big_live) + len(big_hist), ai_max_lines, len(big_hist)))
            if len(ai_files) > ai_max_files:
                row(1, 'KN-31', 'L', 'ai:0', 'ai/', '%d files (health check 4 budget %d; %d are history)' % (len(ai_files), ai_max_files, len(hist)),
                    'candidate', 'archive history out of the loaded tree; /recall still finds it')
            for n, f in big_live[:10]:
                row(1, 'KN-31', 'M' if f == 'ai/_session-digest.md' else 'L', f + ':1', f, '%d lines (budget %d)' % (n, ai_max_lines), 'candidate')
            if len(big_live) > 10:
                K.ledger('  ai/ over-budget files beyond the top 10: %d (Live, unreviewed)' % (len(big_live) - 10))
        if memory_dir:
            mm = os.path.join(memory_dir, 'MEMORY.md')
            txt = K.read_text(mm)
            if txt is not None:
                n_l, n_b = len(K.split_lines(txt)), len(txt.encode('utf-8'))
                if n_l > 200 or n_b > 25600:
                    row(1, 'KN-31', 'H', 'MEMORY.md:1', 'MEMORY.md', '%d lines / %d bytes: only the first 200 lines or 25,600 bytes load'
                        % (n_l, n_b), 'candidate', 'the tail is dropped silently: move detail into topic files')
                else:
                    K.ledger('  MEMORY.md: %d lines / %d bytes (within 200 / 25,600)' % (n_l, n_b))
        else:
            K.ledger('  MEMORY.md: NOT READ (opt-in --memory-dir, O-3)')
    # §2 selection
    if 2 in classes:
        agents = sorted(set(f for f in repo.files if os.path.basename(f) == 'AGENTS.md') |
                        set(['AGENTS.md'] if repo.exists_on_disk('AGENTS.md') else []))
        for a in agents:
            d = os.path.dirname(a)
            above, cur = [], d
            while True:
                for n in ('CLAUDE.md', 'CLAUDE.local.md'):
                    p = (cur + '/' + n).lstrip('/')
                    if repo.exists_on_disk(p):
                        above.append(p)
                if not cur:
                    break
                cur = os.path.dirname(cur)
            if not above:
                continue
            pa = os.path.join(repo.root, a)
            linked = any(os.path.islink(os.path.join(repo.root, c)) and os.path.realpath(os.path.join(repo.root, c)) == os.path.realpath(pa)
                         for c in above) or (os.path.islink(pa) and any(os.path.realpath(pa) == os.path.realpath(os.path.join(repo.root, c)) for c in above))
            imported = False
            for c in above:
                seen, _ = closure(repo, c)
                if a in seen:
                    imported = True
            if linked or imported:
                K.ledger('  %s: loaded (%s)' % (a, 'symlink' if linked else '@import'))
                continue
            n = len(repo.lines(a) or [])
            prose = any(re.search(r'\bAGENTS\.md\b', l) for c in above for l in (repo.lines(c) or []))
            row(2, 'KN-32', 'M', a + ':1', a, '%d lines, not loaded by Claude Code: %s exists and imports nothing that reaches it' % (n, above[0]),
                'unconfirmed', ('a prose pointer is not an import; ' if prose else '') +
                'add `@AGENTS.md` to CLAUDE.md (or symlink). Settling probe: /memory lists it? (the user setting '
                'claude-md-and-agents-md is not visible in the repo)')
    # §3 vague lexicon (advisory only)
    if 3 in classes:
        n, first = 0, []
        for f in sorted(set(loaded) | set(x for x in set(repo.files) | set(walk(repo, '.claude/rules')) if x.startswith('.claude/rules/'))):
            for i, l in enumerate(effective(repo.lines(f) or []), 1):
                if VAGUE.search(l) and not re.search(r'`|/|\d', l) and len(l.strip()) > 20:
                    n += 1
                    if len(first) < 5:
                        first.append((f, i, l.strip()[:80]))
        for f, i, t in first:
            row(3, 'KN-33', 'L', '%s:%d' % (f, i), 'vague rule text', t, 'advisory', 'never a Finding: name the file, command or number')
        K.ledger('  vague-lexicon lines in loaded files: %d (advisory, O-4)' % n)
    # §4 oracle freshness
    if 4 in classes:
        oracle = '.claude/_extracted-codebase.md'
        installed = repo.exists_on_disk('.claude/codebase-profile.md') or any(
            repo.exists_on_disk(x) for x in ('ai/_session-digest.md', 'ai/conventions.md', '.claude/agents'))
        if not installed:
            K.ledger('  §4 N/A (no knowledge layer installed: no codebase-profile, digest, conventions or .claude/agents)')
        elif not repo.exists_on_disk(oracle):
            row(4, 'KN-19', 'M', oracle + ':0', oracle, 'extraction oracle absent', 'candidate',
                'every consumer of the oracle reads nothing: /refresh-knowledge (or /setup-project --refresh) writes it')
        else:
            ls = repo.lines(oracle) or []
            sha = next((m.group(1) for l in ls for m in [re.search(r'(?:census|coverage|derived)[^\n]*?\b([0-9a-f]{7,40})\b', l, re.I)] if m), '')
            cited = sorted(set(m.group(1) for l in ls for m in re.finditer(r'`((?:[\w@.-]+/)+[\w@.-]+\.\w{1,6})`', l)
                               if m.group(1) in repo.fset))[:200]
            if sha and repo.has_git and cited:
                rc, out = K.git(repo.root, 'rev-list', '--count', sha + '..HEAD', '--', *cited)
                if rc != 0:
                    row(4, 'KN-19', 'L', oracle + ':1', 'census sha', '%s is not in this history' % sha, 'unconfirmed')
                elif out.strip() not in ('', '0'):
                    row(4, 'KN-19', 'M', oracle + ':1', 'census sha', '%s commit(s) touched %d cited path(s) since %s' % (out.strip(), len(cited), sha[:10]),
                        'candidate', 're-extract (/refresh-knowledge); the digest may be fresh while the oracle is not')
            elif not sha:
                row(4, 'KN-19', 'L', oracle + ':1', 'census sha', 'no census sha recorded: freshness cannot be computed', 'unconfirmed',
                    'record `derived_at: <sha>` in ## Coverage')
            nomark = sum(1 for l in ls if re.search(r'`[^`]+`|\d', l) and l.lstrip().startswith(('-', '*', '|'))
                         and not re.search(r'\[(found|inferred|unconfirmed|CONFIDENT|INFERRED|UNKNOWN)', l))
            K.ledger('  oracle: %d factual lines without a provenance marker (KN-16: /setup-project-health check 11 owns it)' % nomark)
        for f in [x for x in ('.claude/_extracted-codebase.md', '.claude/codebase-profile.md') if repo.exists_on_disk(x)]:
            ls = repo.lines(f) or []
            stamp = next((l.split(':', 1)[1].strip() for l in ls if l.startswith('approved_hash:')), '')
            if stamp:
                body = ''.join(l + '\n' for l in ls if not l.startswith('approved_'))
                if body.endswith('\n\n') and not (K.read_text(os.path.join(repo.root, f)) or '').endswith('\n\n'):
                    body = body[:-1]
                h = hashlib.sha256(body.encode('utf-8')).hexdigest()[:12]
                if not h.startswith(stamp[:12]) and not stamp.startswith(h):
                    row(4, 'KN-18', 'L', f + ':1', 'approved_hash', 'body changed after approval (%s != %s)' % (stamp[:12], h), 'candidate',
                        'owner: /setup-project-health check 9 (routed); re-approve after reading')
            else:
                K.ledger('  %s: no approval stamp (KN-18 routed to /setup-project-health check 9)' % f)
        if repo.has_git and repo.exists_on_disk('.claude/codebase-profile.md'):
            rc, out = K.git(repo.root, 'log', '-1', '--format=%h %cs', '--', '.claude/codebase-profile.md')
            if out.strip():
                rc2, n = K.git(repo.root, 'rev-list', '--count', out.split()[0] + '..HEAD')
                K.ledger('  codebase-profile.md last edited %s · %s commit(s) since' % (out.strip(), n.strip() or '?'))
    # §5 security handoff
    if 5 in classes:
        files = context_files(repo, memory_dir)
        hid = 0
        sites = []
        for f in files:
            p = f if f.startswith('/') else os.path.join(repo.root, f)
            for i, l in enumerate((K.read_text(p) or '').split('\n'), 1):
                for m in HIDDEN.finditer(l):
                    if RTL.search(l) and m.group(0) in u'‌‍':
                        continue                           # P-26: joiners inside RTL text are legitimate
                    hid += 1
                    if len(sites) < 5:
                        sites.append('%s:%d U+%04X' % (f, i, ord(m.group(0))))
        if hid:
            row(5, 'KN-35', 'H', sites[0].rsplit(' ', 1)[0], 'hidden Unicode', '%d bidi-override / zero-width character(s): %s'
                % (hid, ', '.join(sites)), 'handoff', 'security sast-scan (trojan-source lane) grades it, when the security pack is installed')
        K.ledger('  context files for security (KN-34/35): %d (print them with --security-list)' % len(files))
    return rows


def walk(repo, d):
    top = os.path.join(repo.root, d)
    out = []
    if os.path.isdir(top):
        for dp, dn, fn in os.walk(top):
            dn[:] = [x for x in dn if x not in K.SKIP_DIRS]
            out += [os.path.relpath(os.path.join(dp, f), repo.root).replace(os.sep, '/') for f in fn]
    return out


def context_files(repo, memory_dir=None):
    fs = set(f for f in set(repo.files) | set(walk(repo, 'ai')) | set(walk(repo, '.claude/rules')) | set(walk(repo, '.cursor'))
             if os.path.basename(f) in K.CONTEXT_NAMES or f.startswith(('ai/', '.claude/rules/', '.cursor/rules/', '.github/instructions/'))
             or f == '.github/copilot-instructions.md' or f in ('.cursorrules', '.windsurfrules'))
    for n in K.CONTEXT_NAMES:
        if repo.exists_on_disk(n):
            fs.add(n)
    out = sorted(fs)
    if memory_dir and os.path.isdir(memory_dir):
        out += sorted(os.path.join(memory_dir, f) for f in os.listdir(memory_dir) if f.endswith('.md'))
    return out


def emit(rows, as_json):
    if as_json:
        print(json.dumps(rows, indent=1))
        return
    print('# §\tclass\tsev\tsite\tsubject\tfinding\tverdict\tnote')
    for r in sorted(rows, key=lambda r: (r['sec'], {'H': 0, 'M': 1, 'L': 2}[r['sev']], r['site'])):
        print('\t'.join(str(r[k]) for k in ('sec', 'kn', 'sev', 'site', 'subject', 'finding', 'verdict', 'note')))


def _w(root, rel, text):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p) or root, exist_ok=True)
    with open(p, 'w') as fh:
        fh.write(text)


def self_test():
    K.QUIET = True
    tmp = tempfile.mkdtemp(prefix='load-budget-selftest.')
    fails = []
    try:
        a = os.path.join(tmp, 'a')
        _w(a, 'CLAUDE.md', '# P\n@docs/extra.md\n@missing/gone.md\nRead AGENTS.md for more.\nWrite clean code properly here always.\n'
                           + ''.join('- rule %d `x`\n' % i for i in range(200)))
        _w(a, 'docs/extra.md', 'extra\n' * 10)
        _w(a, 'AGENTS.md', 'agents\n' * 40)
        _w(a, '.claude/rules/big.md', 'x' * 900 + '\n')
        _w(a, '.claude/rules/scoped.md', '---\npaths: ["src/**"]\n---\n' + 'y' * 5000 + '\n')
        _w(a, '.claude/rules/globby.md', '---\nglobs: src/**\n---\nz\n')
        _w(a, '.github/copilot-instructions.md', 'c' * 4100 + '\n')
        _w(a, 'ai/one.md', 'l\n' * 320)
        _w(a, 'ai/two.md', 'x\n')
        _w(a, 'ai/three.md', u'abc ‮ evil\nمرحبا ‏ ok\n')
        _w(a, 'mem/MEMORY.md', 'm\n' * 210)
        _w(a, '.claude/codebase-profile.md', '# profile\n')
        rows = scan(a, memory_dir=os.path.join(a, 'mem'), rule_budget=150, ai_max_files=2)
        got = set((r['kn'], r['site'], r['verdict']) for r in rows)
        for want in [('KN-31', 'CLAUDE.md:1', 'candidate'), ('KN-31', 'CLAUDE.md:3', 'candidate'), ('KN-31', '.claude/rules:0', 'candidate'),
                     ('KN-31', '.claude/rules/globby.md:1', 'candidate'), ('KN-31', '.github/copilot-instructions.md:1', 'candidate'),
                     ('KN-31', 'ai:0', 'candidate'), ('KN-31', 'ai/one.md:1', 'candidate'), ('KN-31', 'MEMORY.md:1', 'candidate'),
                     ('KN-32', 'AGENTS.md:1', 'unconfirmed'), ('KN-19', '.claude/_extracted-codebase.md:0', 'candidate'),
                     ('KN-33', 'CLAUDE.md:5', 'advisory'), ('KN-35', 'ai/three.md:1', 'handoff')]:
            if want not in got:
                fails.append('missing %s' % (want,))
        if any(r['kn'] == 'KN-35' and 'three.md:2' in r['finding'] for r in rows):
            fails.append('P-26: RLM inside Arabic text flagged')
        if any('scoped.md' in r['site'] for r in rows):
            fails.append('P-22: a paths:-scoped rule counted')
        b = os.path.join(tmp, 'b')
        _w(b, 'CLAUDE.md', '# P\n@AGENTS.md\n<!--\n' + 'old note\n' * 80 + '-->\n' + '- r `x`\n' * 150)
        _w(b, 'AGENTS.md', 'agents\n' * 30)
        rows = scan(b, classes=(1, 2))
        if any(r['kn'] in ('KN-31', 'KN-32') and r['verdict'] in ('candidate', 'unconfirmed') and r['subject'] != '@import closure' for r in rows):
            fails.append('decoys (HTML-comment-heavy CLAUDE.md P-21, @AGENTS.md import P-16) fired: %s' % rows)
        c = os.path.join(tmp, 'c')                     # exactly at budget: a final newline ends a line, it adds none
        _w(c, 'CLAUDE.md', '# P\n' + '- r `x`\n' * 199)
        _w(c, 'mem/MEMORY.md', 'm\n' * 200)
        rows = scan(c, classes=(1,), memory_dir=os.path.join(c, 'mem'))
        if any(r['kn'] == 'KN-31' for r in rows):
            fails.append('a 200-line CLAUDE.md / MEMORY.md counted over the 200-line budget: %s' % rows)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        sys.stderr.write('self-test FAIL: %s\n' % f)
    print('load-budget.py --self-test %s' % ('OK' if not fails else 'FAILED (%d)' % len(fails)))
    return 0 if not fails else 3


def main(argv):
    opts = {'classes': (1, 2, 3, 4, 5), 'mem': None, 'rb': 12000, 'cm': 200, 'af': 50, 'al': 300}
    root, as_json, sec_list = None, False, False
    for a in argv:
        if a == '--self-test':
            return self_test()
        elif a.startswith('--classes='):
            opts['classes'] = tuple(int(x) for x in a.split('=', 1)[1].split(',') if x.strip())
        elif a.startswith('--memory-dir='):
            opts['mem'] = os.path.expanduser(a.split('=', 1)[1])
        elif a.startswith('--rule-budget='):
            opts['rb'] = int(a.split('=', 1)[1])
        elif a.startswith('--claude-max='):
            opts['cm'] = int(a.split('=', 1)[1])
        elif a.startswith('--ai-max-files='):
            opts['af'] = int(a.split('=', 1)[1])
        elif a.startswith('--ai-max-lines='):
            opts['al'] = int(a.split('=', 1)[1])
        elif a == '--security-list':
            sec_list = True
        elif a == '--json':
            as_json = True
        elif a.startswith('-'):
            sys.stderr.write('unknown option %s\n' % a)
            return 2
        else:
            root = a
    if not root or not os.path.isdir(root):
        sys.stderr.write('usage: load-budget.py <root> [options] | --self-test (blocked: no such root)\n')
        return 2
    if sec_list:
        for f in context_files(K.Repo(root), opts['mem']):
            print(f)
        return 0
    rows = scan(root, opts['classes'], opts['mem'], opts['rb'], opts['cm'], opts['af'], opts['al'])
    emit(rows, as_json)
    return 1 if any(r['verdict'] in ('candidate', 'unconfirmed') for r in rows) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
