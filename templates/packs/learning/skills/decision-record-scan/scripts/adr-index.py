#!/usr/bin/env python3
"""adr-index.py — decision-record-scan §0-§4: where do this project's ADRs live, what status does each
one carry, do supersede links run both ways, is a superseded decision still cited as current, and does
an Accepted decision's chosen package actually appear in a manifest?

Why a script: on a real NestJS + React monorepo the 40 ADRs live in docs/decisions/ (the decision
index says so and says "do not create a competing ai/decisions/ ledger"), while the installed
knowledge commands read and write ai/decisions/, which holds only a README and a template — so a
health check counts 0 ADRs and /promote-decision would start a second ledger (KN-29). Status is
written in five shapes there (`Status: Accepted`, `- **Status:** Superseded by [0014](…)`,
`**Status:** accepted · **Date:** …`, a `## Status` heading, frontmatter), so a single grep reads a
fraction of them.

Usage:  python3 -I adr-index.py <root> [--classes=0,1,2,3,4] [--only=<file>:<line>] [--home=<dir>] [--json]
        python3 -I adr-index.py <root> --list        one TSV row per ADR: id, file, status, superseded-by, supersedes
        python3 -I adr-index.py --self-test
--home   force the ADR home (otherwise: the directory an index declares, else the candidate with the most
         NNNN-*.md files: docs/decisions, docs/adr, doc/adr, adr, architecture/decisions, ai/decisions …).
Classes: 0 ADR home and the consumers that read another one (KN-29) · 1 status not machine-readable
(KN-28) · 2 supersede link one-way (KN-28b) · 3 superseded / retired ADR cited as current outside the
decisions dir and its index (KN-28c) · 4 Accepted ADR whose chosen package is in no manifest (KN-28a;
Unconfirmed — P-2: rejected options are expected to be absent and are never checked).
Index parity (index rows vs ADR files) is knowledge-fact-scan §5; this script prints the counts only.

OUTPUT: TSV `# § class sev site subject finding verdict note` (or --json). Stderr: the ledger (home, how
it was chosen, ADR count, status histogram, index rows). Exit: 0 none · 1 rows · 2 blocked (no root) ·
3 self-test failed. Stdlib only, Python >= 3.8, `python3 -I` safe; read-only; writes nothing under <root>.
"""
import sys
sys.dont_write_bytecode = True
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

STATUS_WORDS = ('accepted', 'proposed', 'superseded', 'deprecated', 'rejected', 'retired', 'amended', 'draft',
                'approved', 'active', 'withdrawn', 'replaced')
CURRENT = {'accepted', 'approved', 'active', 'amended'}
DEAD = {'superseded', 'deprecated', 'retired', 'withdrawn', 'replaced', 'rejected'}
ID_IN = re.compile(r'(?:\bADR[- ]?|\[|\(|#|\b)0*(\d{1,4})(?:\]|\)|\b)(?:-[a-z][\w-]*\.md)?')
HIST = re.compile(r'\b(supersed\w*|was|were|replaced|retired|deprecated|previously|formerly|historical|history|old|'
                  r'original(?:ly)?|instead|reversed|rejected|until|then|amended)\b|→|->', re.I)
FW_PKG = {'express': 'express', 'fastify': 'fastify', 'nestjs': '@nestjs/core', 'nest': '@nestjs/core', 'prisma': 'prisma',
          'typeorm': 'typeorm', 'mikroorm': '@mikro-orm/core', 'sequelize': 'sequelize', 'drizzle': 'drizzle-orm',
          'react': 'react', 'vue': 'vue', 'angular': '@angular/core', 'svelte': 'svelte', 'next.js': 'next', 'nextjs': 'next',
          'vite': 'vite', 'webpack': 'webpack', 'jest': 'jest', 'vitest': 'vitest', 'playwright': '@playwright/test',
          'cypress': 'cypress', 'redux': 'redux', 'zustand': 'zustand', 'bullmq': 'bullmq', 'kafkajs': 'kafkajs',
          'socket.io': 'socket.io', 'tailwind': 'tailwindcss', 'radix': '@radix-ui/react-slot', 'zod': 'zod', 'ky': 'ky',
          'axios': 'axios', 'django': 'django', 'fastapi': 'fastapi', 'flask': 'flask', 'sqlalchemy': 'sqlalchemy',
          'celery': 'celery', 'rails': 'rails', 'sidekiq': 'sidekiq', 'laravel': 'laravel/framework'}


def parse_status(lines):
    """(status word or '', superseded-by ids, supersedes ids, line number of the status)."""
    status, by, sup, at = '', set(), set(), 0
    fm = K.frontmatter(lines)
    if fm.get('status'):
        status, at = fm['status'].strip().lower().split()[0].strip('"\''), 2
    for i, l in enumerate(lines[:40], 1):
        m = re.match(r'^\s*(?:[-*]\s*)?(?:\*\*|__)?Status(?:\*\*|__)?\s*:?\s*(?:\*\*|__)?\s*:?\s*([A-Za-z]+)(.*)$', l)
        if not m and re.match(r'^#{1,4}\s*Status\s*$', l, re.I):
            nxt = next((x for x in lines[i:i + 4] if x.strip()), '')
            m = re.match(r'^\s*(?:[-*]\s*)?(?:\*\*)?([A-Za-z]+)(.*)$', nxt)
        if not m:
            m = re.match(r'^\s*\|\s*\*{0,2}Status\*{0,2}\s*\|\s*([A-Za-z]+)([^|]*)\|', l) or \
                re.search(r'(?:[·|;]\s*)(?:\*\*)?Status(?:\*\*)?\s*:\s*(?:\*\*)?\s*([A-Za-z]+)(.*)$', l)
        if m and not status:
            status, at = m.group(1).lower(), i
            rest = m.group(2)
            if status.startswith('supersed') or status == 'replaced' or 'superseded by' in rest.lower():
                by |= set(int(x) for x in re.findall(r'(\d{1,4})', rest.split('(')[0] + ' ' + rest)[:1])
            if status.startswith('amend') and 'by' in rest.lower():
                status = 'amended'
        lo = l.lower()
        if re.search(r'\bsuperseded by\b', lo):
            ids = [int(x) for x in re.findall(r'(?:adr[- ]?|\[|\b)0*(\d{1,4})\b', lo.split('superseded by', 1)[1])[:1]]
            by |= set(ids)
            if not status:
                status, at = 'superseded', i
        if re.search(r'^\s*(?:[-*]\s*)?(?:\*\*)?supersedes(?:\*\*)?\s*:|\bsupersed(?:es|ing)\s+(?:adr[- ]?|\[)?\d', lo):
            tail = re.split(r'supersed(?:es|ing)', lo, 1)[1]
            sup |= set(int(x) for x in re.findall(r'(?:adr[- ]?|\[|\b)0*(\d{1,4})\b', tail)[:3])
    status = re.sub(r'[^a-z]', '', status)
    for w in STATUS_WORDS:
        if status.startswith(w[:6]):
            status = w
            break
    else:
        status = status if status in STATUS_WORDS else ('' if not status else 'unknown:' + status)
    return status, by, sup, at


def load(repo, home):
    adrs = {}
    for n, f in K.adr_ids(repo, home).items():
        lines = repo.lines(f) or []
        st, by, sup, at = parse_status(lines)
        title = next((l.lstrip('# ').strip() for l in lines if l.startswith('#')), os.path.basename(f))
        adrs[n] = {'id': n, 'file': f, 'status': st, 'by': by, 'sup': sup, 'at': at or 1, 'title': title, 'lines': lines}
    return adrs


def scan(root, classes=(0, 1, 2, 3, 4), only=None, home=None):
    repo = K.Repo(root)
    how = 'forced (--home)'
    counts = {}
    if not home:
        home, how, counts = K.adr_home(repo)
    adrs = load(repo, home) if home else {}
    rows = []

    def row(sec, kn, sev, site, subj, finding, verdict, note=''):
        if only and site != '%s:%d' % only:
            return
        rows.append({'sec': sec, 'kn': kn, 'sev': sev, 'site': site, 'subject': subj, 'finding': finding,
                     'verdict': verdict, 'note': note})

    hist = {}
    for a in adrs.values():
        hist[a['status'] or '(none)'] = hist.get(a['status'] or '(none)', 0) + 1
    K.ledger('ADR home: %s (%s) · %d ADRs · candidates %s' % (home or 'none', how, len(adrs),
             ', '.join('%s=%d' % kv for kv in sorted(counts.items())) or '-'))
    K.ledger('status: ' + ', '.join('%s %d' % kv for kv in sorted(hist.items())))
    idx = [f for f in repo.files if re.search(r'(^|/)_?decision-index\.md$', f)]
    for f in idx:
        cited = index_ids('\n'.join(repo.lines(f) or []))
        K.ledger('index %s: %d ids cited vs %d files (parity is knowledge-fact-scan §5)' % (f, len(cited), len(adrs)))
    if not home:
        K.ledger('§0-§4 N/A (no ADR directory: no NNNN-*.md under any decisions/ or adr/ dir)')
        return rows
    # §0 home vs consumers
    if 0 in classes and home != 'ai/decisions':
        if os.path.isdir(os.path.join(repo.root, 'ai/decisions')):
            n_ai = counts.get('ai/decisions', 0)
            first = next((f for f in ('ai/decisions/README.md', 'ai/decisions/_template.md') if f in repo.fset), 'ai/decisions')
            row(0, 'KN-29', 'M', first + ':1', 'ai/decisions/', 'second ADR directory (%d ADRs) beside the home %s (%d ADRs)'
                % (n_ai, home, len(adrs)), 'candidate', 'one home: point the tooling at %s, keep ai/decisions/ a pointer' % home)
        cons = {}
        for f in repo.files:
            if not (f.startswith(('.claude/commands/', '.claude/agents/', '.claude/skills/', '.claude/hooks/', '.claude/rules/'))
                    or f in ('CLAUDE.md', 'AGENTS.md')):
                continue
            for i, l in enumerate(repo.lines(f) or [], 1):
                if re.search(r'(?<![\w/])ai/decisions/', l) and not re.search(re.escape(home), l):
                    cons.setdefault(f, i)
        if cons and not only:
            items = sorted(cons.items())
            loaded = [f for f, _ in items if K.loaded_every_session(f)]
            row(0, 'KN-29', 'H' if loaded else 'M', '%s:%d' % items[0], 'ai/decisions/',
                '%d installed artifact(s) read or write ai/decisions/ while ADRs live in %s' % (len(items), home), 'candidate',
                'one root cause, %d sites: %s%s' % (len(items), ', '.join('%s:%d' % x for x in items[1:5]),
                                                    ' …' if len(items) > 5 else ''))
            for f, i in items:
                K.ledger('  §0 site %s:%d' % (f, i))
    # §1 status
    for n, a in sorted(adrs.items()):
        if 1 in classes and (not a['status'] or a['status'].startswith('unknown')):
            row(1, 'KN-28', 'L', '%s:%d' % (a['file'], a['at']), 'ADR-%04d' % n, 'status %s' % (
                'missing' if not a['status'] else 'not a lifecycle word (%s)' % a['status'][8:]), 'candidate',
                'write `Status: <Proposed|Accepted|Superseded by ADR-NNNN|Deprecated>` (MADR)')
    # §2 reciprocity
    if 2 in classes:
        for n, a in sorted(adrs.items()):
            for b in sorted(a['by']):
                if b in adrs and n not in adrs[b]['sup'] and not re.search(r'(?<!\d)0*%d\b' % n, ' '.join(adrs[b]['lines'][:15])):
                    row(2, 'KN-28', 'M', '%s:%d' % (adrs[b]['file'], 1), 'ADR-%04d' % b, 'superseding ADR does not name ADR-%04d back'
                        % n, 'candidate', 'add `Supersedes: ADR-%04d`' % n)
                elif b not in adrs:
                    row(2, 'KN-28', 'M', '%s:%d' % (a['file'], a['at']), 'ADR-%04d' % n, 'superseded by ADR-%04d, which has no file' % b,
                        'candidate')
            if a['status'] == 'superseded' and not a['by']:
                row(2, 'KN-28', 'M', '%s:%d' % (a['file'], a['at']), 'ADR-%04d' % n, 'Superseded, but names no successor',
                    'candidate', 'write `Superseded by ADR-NNNN`')
            for s in sorted(a['sup']):
                if s in adrs and adrs[s]['status'] not in DEAD and n not in adrs[s]['by']:
                    partial = any(re.search(r'supersed\w*[^\n]{0,40}\b(clause|part|section|partial\w*|portion|in part)\b', l, re.I)
                                  for l in a['lines'][:20])
                    if partial and adrs[s]['status'] == 'amended':
                        continue
                    row(2, 'KN-28', 'L' if partial else 'M', '%s:%d' % (adrs[s]['file'], adrs[s]['at']), 'ADR-%04d' % s,
                        ('partly superseded by ADR-%04d, no back link' if partial else 'still %s although ADR-%04d supersedes it')
                        % ((n,) if partial else (adrs[s]['status'] or 'status-less', n)), 'unconfirmed' if partial else 'candidate',
                        ('mark `Amended by ADR-%04d`' if partial else 'mark `Superseded by ADR-%04d`; never delete the old ADR (Nygard)') % n)
    # §3 superseded cited as current
    if 3 in classes:
        dead = dict((n, a) for n, a in adrs.items() if a['status'] in DEAD)
        if dead:
            pat = re.compile(r'\bADR[- ]?0*(%s)\b|(?<![\w/-])(%s)-[a-z][\w-]*\.md' % ('|'.join(str(n) for n in dead),
                                                                                  '|'.join('%04d' % n for n in dead)))
            for rel, scope in K.corpus(repo):
                if scope not in ('live', 'pack-body') or rel.startswith(home + '/') or re.search(r'decision-index', rel):
                    continue
                lines = repo.lines(rel) or []
                for ln in sorted(K.live_lines(rel, lines, scope == 'pack-body')):
                    l = lines[ln - 1]
                    for m in pat.finditer(l):
                        n = int(m.group(1) or m.group(2))
                        succ = dead[n]['by']
                        if HIST.search(l) or any(re.search(r'(?<!\d)0*%d\b' % s, l) for s in succ):
                            continue
                        row(3, 'KN-28', 'H' if K.loaded_every_session(rel) else 'M', '%s:%d' % (rel, ln), 'ADR-%04d' % n,
                            'cited as current; it is %s%s' % (dead[n]['status'], ' by ADR-%04d' % sorted(succ)[0] if succ else ''),
                            'candidate', 're-point the citation to the successor')
    # §4 chosen option vs manifests
    if 4 in classes:
        vers, _, decl = K.lock_versions(repo)
        present = set(vers) | set(decl)
        if not present:
            K.ledger('§4 N/A (no manifest read)')
        for n, a in sorted(adrs.items()):
            if a['status'] not in CURRENT:
                continue
            chosen = chosen_text(a['lines'])
            if not chosen:
                continue
            pk = set()
            for m in re.finditer(r'`(@?[a-z0-9][\w.-]*(?:/[\w.-]+)?)`', chosen):
                if m.group(1) in present or re.match(r'^@[\w.-]+/[\w.-]+$', m.group(1)):
                    pk.add(m.group(1))
            for w, p in FW_PKG.items():
                if re.search(r'(?<![\w.-])' + re.escape(w) + r'(?![\w-])', chosen, re.I):
                    pk.add(p)
            for p in sorted(pk):
                if present and p not in present:
                    row(4, 'KN-28', 'M', '%s:%d' % (a['file'], a['at']), 'ADR-%04d' % n, 'chosen `%s` is in no manifest' % p,
                        'unconfirmed', 'Accepted but reversed in code? or not built yet (then it is Proposed)')
    return rows


def index_ids(text):
    """ADR numbers a decision index cites: `0007-slug` rows and `ADR-0007` rows (a date is neither)."""
    ids = set(int(x) for x in re.findall(r'(?<![\d-])(\d{4})-[a-z]', text))
    return ids | set(int(x) for x in re.findall(r'\bADR-(\d{4})\b', text))


def chosen_text(lines):
    """The decision outcome: a `Chosen option:` line, else the `## Decision` section's first paragraph."""
    for l in lines:
        m = re.search(r'Chosen option:\s*(.+)$', l)
        if m:
            return m.group(1)
    out, on = [], False
    for l in lines:
        if re.match(r'^#{1,3}\s*(Decision|Decision Outcome)\s*$', l, re.I):
            on = True
            continue
        if on and re.match(r'^#{1,3}\s', l):
            break
        if on:
            if not l.strip() and out:
                break
            if l.strip():
                out.append(l)
    return ' '.join(out)


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
    tmp = tempfile.mkdtemp(prefix='adr-index-selftest.')
    fails = []
    try:
        root = tmp
        _w(root, 'package.json', '{"name":"x","dependencies":{"fastify":"^5.0.0","zod":"^3"}}')
        D = 'docs/decisions/'
        _w(root, D + '0001-express.md', '# 1. Express\n\n- **Status:** Superseded by [0003](0003-fastify.md)\n\n## Decision\n\nUse `express`.\n')
        _w(root, D + '0002-http-client.md', '# 2. Client\n\n**Status:** accepted · **Date:** 2026-09-01\n\n## Decision\n\nWe use `axios` for HTTP.\n\n'
                                            '## Considered options\n\n- `ky` (rejected)\n')
        _w(root, D + '0003-fastify.md', '# 3. Fastify\n\nStatus: Accepted\n\n## Decision\n\nUse Fastify.\n')   # no back link
        _w(root, D + '0004-old.md', '---\nstatus: superseded\n---\n# 4. Old\n\nSuperseded by ADR-0005.\n')
        _w(root, D + '0005-new.md', '# 5. New\n\n## Status\n\nAccepted\n\n- **Supersedes:** [0004](0004-old.md)\n\n## Decision\n\nUse `zod`.\n')
        _w(root, D + '0006-nostatus.md', '# 6. No status\n\nWe decided things.\n')
        _w(root, D + '0007-amended.md', '# 7\n\nDate: 2026-09-28 · Status: accepted\n')
        _w(root, D + '0008-amends.md', '# 8\n\nStatus: Accepted\n\nThis ADR supersedes ADR-0007 for the API.\n')  # 0007 not marked
        _w(root, D + '0009-base.md', '# 9\n\nStatus: Accepted\n')
        _w(root, D + '0010-part.md', '# 10\n\nStatus: Accepted\nSupersedes: the chrome clause of [0009](0009-base.md)\n')
        _w(root, 'ai/runbooks/x.md', 'See `ai/audits/2026-10-01-order.md` for the audit.\n')
        _w(root, 'ai/decisions/README.md', '# Decisions\n')
        _w(root, '.claude/commands/promote-decision.md', '---\nkind: command\n---\nWrite the ADR to `ai/decisions/<NNNN>-<slug>.md`.\n')
        _w(root, 'CLAUDE.md', '# P\n- HTTP follows ADR-0001.\n- Old HTTP was ADR-0001, replaced by ADR-0003.\n- See ADR-0004 → ADR-0005.\n')
        rows = scan(root)
        got = set((r['kn'], r['site'], r['subject']) for r in rows)
        for want in [('KN-29', 'ai/decisions/README.md:1', 'ai/decisions/'), ('KN-29', '.claude/commands/promote-decision.md:4', 'ai/decisions/'),
                     ('KN-28', 'docs/decisions/0009-base.md:3', 'ADR-0009'),
                     ('KN-28', 'docs/decisions/0006-nostatus.md:1', 'ADR-0006'),
                     ('KN-28', 'docs/decisions/0003-fastify.md:1', 'ADR-0003'),
                     ('KN-28', 'docs/decisions/0007-amended.md:3', 'ADR-0007'),
                     ('KN-28', 'CLAUDE.md:2', 'ADR-0001'),
                     ('KN-28', 'docs/decisions/0002-http-client.md:3', 'ADR-0002')]:
            if want not in got:
                fails.append('missing %s' % (want,))
        for pred, label in [(lambda r: r['site'] in ('CLAUDE.md:3', 'CLAUDE.md:4', 'ai/runbooks/x.md:1'), 'history-marked citation / dated file name'),
                            (lambda r: r['subject'] == 'ADR-0009' and r['verdict'] == 'candidate', 'partial supersede is unconfirmed'),
                            (lambda r: r['subject'] in ('ADR-0004', 'ADR-0005') and r['sec'] == 2, 'reciprocal pair'),
                            (lambda r: '`ky`' in r['finding'], 'rejected option P-2'),
                            (lambda r: r['subject'] == 'ADR-0001' and r['sec'] == 4, 'superseded ADR checked in §4'),
                            (lambda r: r['sec'] == 1 and r['subject'] in ('ADR-0001', 'ADR-0002', 'ADR-0004', 'ADR-0005'), 'status shapes')]:
            bad = [r for r in rows if pred(r)]
            if bad:
                fails.append('false row %s: %s' % (label, bad[0]))
        st = dict((n, a['status']) for n, a in load(K.Repo(root), 'docs/decisions').items())
        if st != {1: 'superseded', 2: 'accepted', 3: 'accepted', 4: 'superseded', 5: 'accepted', 6: '', 7: 'accepted', 8: 'accepted',
                  9: 'accepted', 10: 'accepted'}:
            fails.append('status parse: %s' % st)
        got_ids = index_ids('| 0001-use-pg | x |\n| ADR-0002 | y |\n| [ADR-0003](x.md) | z |\n| 2026-08-01 | dated |\n')
        if got_ids != {1, 2, 3}:
            fails.append('index ids: want 0001-slug and ADR-NNNN forms, got %s' % sorted(got_ids))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        sys.stderr.write('self-test FAIL: %s\n' % f)
    print('adr-index.py --self-test %s' % ('OK' if not fails else 'FAILED (%d)' % len(fails)))
    return 0 if not fails else 3


def main(argv):
    classes, only, home, as_json, root, lst = (0, 1, 2, 3, 4), None, None, False, None, False
    for a in argv:
        if a == '--self-test':
            return self_test()
        elif a.startswith('--classes='):
            classes = tuple(int(x) for x in a.split('=', 1)[1].split(',') if x.strip())
        elif a.startswith('--only='):
            f, _, l = a.split('=', 1)[1].rpartition(':')
            if not l.isdigit():
                sys.stderr.write('--only needs <file>:<line>\n')
                return 2
            only = (f, int(l))
        elif a.startswith('--home='):
            home = a.split('=', 1)[1].rstrip('/')
        elif a == '--list':
            lst = True
        elif a == '--json':
            as_json = True
        elif a.startswith('-'):
            sys.stderr.write('unknown option %s\n' % a)
            return 2
        else:
            root = a
    if not root or not os.path.isdir(root):
        sys.stderr.write('usage: adr-index.py <root> [options] | --self-test (blocked: no such root)\n')
        return 2
    if lst:
        repo = K.Repo(root)
        h = home or K.adr_home(repo)[0]
        print('# id\tfile\tstatus\tsuperseded_by\tsupersedes')
        for n, a in sorted(load(repo, h).items() if h else []):
            print('%04d\t%s\t%s\t%s\t%s' % (n, a['file'], a['status'] or '-', ','.join('%04d' % x for x in sorted(a['by'])) or '-',
                                            ','.join('%04d' % x for x in sorted(a['sup'])) or '-'))
        return 0
    rows = scan(root, classes, only, home)
    emit(rows, as_json)
    return 1 if rows else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
