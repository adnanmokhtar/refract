#!/usr/bin/env python3
"""sink-audit.py — memory-hygiene-scan §1-§9: are the entries in the learning sinks still true,
unique, consistent, provenanced, moving through their lifecycle — and can their consumers read them?

The sinks are the nine append-only files of templates/snippets/learning-sink.md (ai/dynamic/*.md and
ai/failures/_index.md), plus the host memory directory only when --memory-dir names it (O-3: it lives
outside the repo, so it is never read by default).

Why a script: on a real NestJS + React monorepo the drift log held 77 entries whose 172 citations
split 132 resolving / 11 pointing at a deleted path / 29 at a line past the end of the file, and the
project had rewritten the sink's format (no Status line; an entry is deleted on fix). The curator's
`status OPEN` read 1 of 77 entries and the session hook's `^Severity: high` grep read the one entry
written that way — both "clean", both blind. Each sink is parsed by the format it DECLARES in its own
`## Format per entry` block first (P-24), the learning-sink template second.

Usage:  python3 -I sink-audit.py <root> [--classes=1,...,9] [--only=<sink>:<line>] [--entry=<sink>:<line>]
                 [--memory-dir=<dir>] [--stuck-days=14] [--today=YYYY-MM-DD] [--json]
        python3 -I sink-audit.py <root> --eval-coverage          JSON: cases, guards, units, unguarded
        python3 -I sink-audit.py --self-test
--entry       reconcile-on-write for /learn-from-task: the one entry at <sink>:<line> against every other
              entry (duplicate §2, contradiction §3) and its own provenance (§4).
--only        re-run one entry (the failing-first proof of /refresh-knowledge --from-audit).
Classes: 1 stale evidence (KN-20) · 2 duplicate (KN-21) · 3 contradiction pairs for a judge (KN-22) ·
4 provenance (KN-23) · 5 stuck lifecycle (KN-24) · 6 n=1 universal lesson (KN-25, advisory) ·
7 checkable lesson with no hook/lint/test (KN-26) · 8 consumer contract (KN-27) · 9 eval guard count
(KN-36, a count; /eval --coverage grades).

OUTPUT: TSV `# § class sev site subject finding verdict note` (or --json). verdict candidate |
unconfirmed | judge (a pair for the refuting judge, both quotes attached) | info. Stderr: the ledger,
one line per sink (entries, declared format, citations ok/gone/eof, states).
Exit: 0 no candidate/unconfirmed/judge row · 1 rows · 2 blocked (no root) · 3 self-test failed.
Stdlib only, Python >= 3.8, `python3 -I` safe; read-only git with GIT_OPTIONAL_LOCKS=0; writes nothing
under <root>.
"""
import sys
sys.dont_write_bytecode = True
import datetime
import json
import os
import re
import shutil
import subprocess
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

SINKS = ('ai/dynamic/learnings.md', 'ai/dynamic/learned-patterns.md', 'ai/dynamic/feedback-learned.md',
         'ai/dynamic/decisions-pending.md', 'ai/dynamic/drift-log.md', 'ai/failures/_index.md',
         'ai/dynamic/interaction-log.md', 'ai/dynamic/changelog.md', 'ai/dynamic/vocabulary.md')
# The learning-sink template: which sinks carry a Status line, and what "ready to promote" looks like.
TEMPLATE_STATUS = {'ai/dynamic/learnings.md', 'ai/dynamic/learned-patterns.md', 'ai/dynamic/feedback-learned.md',
                   'ai/dynamic/decisions-pending.md', 'ai/dynamic/drift-log.md'}
READY = re.compile(r'^(READY|PROMOTE_CANDIDATE|RULE_CANDIDATE|VALIDATED)\b')
TERMINAL = re.compile(r'^(RESOLVED|REJECTED|SUPERSEDED|PROMOTED|DISCARDED|REVERSED|ARCHIVED|FIXED|CLOSED|DONE|WONTFIX)\b', re.I)
# `Status: X`, `- Status: X`, `**Status**: X` and `- **Status:** X` (the colon inside the bold: the value is X, not `** X`).
FIELD = re.compile(r'^\s*(?:[-*]\s*)?(?:\*\*)?([A-Z][A-Za-z /_-]{1,30}?)(?:\*\*)?\s*:(?:\*\*)?\s*(.*)$')
EXT = r'(?:md|mdc|ts|tsx|js|jsx|mjs|cjs|mts|cts|json|ya?ml|py|sh|sql|toml|go|rb|php|vue|svelte|css|scss|html|txt|java|kt|cs|swift|dart|prisma|graphql|proto|tf|lock|env)'
CITE = re.compile(r'`((?:\.{0,2}/)?(?:[\w@.()\[\]+-]+/)*[\w@()\[\]+-][\w@.()\[\]+-]*\.' + EXT + r')(?::(\d+)(?:[-–]\d+)?)?`'
                  r'|(?<![\w/`])((?:[\w@.-]+/)+[\w@.-]+\.' + EXT + r'):(\d+)')
DATE = re.compile(r'\b(20\d\d-\d\d(?:-\d\d)?)\b')
UNIVERSAL = re.compile(r'\b(always|never|every|all|must|no one|nothing|everywhere)\b', re.I)
SAFETY = re.compile(r'\b(delet\w*|drop\w*|prod\w*|secret\w*|credential\w*|migrat\w*|irreversib\w*|money|payment\w*|'
                    r'force[- ]push|rm -rf|tenant\w*|backup\w*|restore\w*|wipe\w*|purge\w*|leak\w*|security)\b', re.I)
NEG = re.compile(r"\b(never|must not|mustn't|don't|do not|avoid|no longer|forbid\w*|banned)\b", re.I)
POS = re.compile(r'\b(always|must(?! not)|prefer|required?)\b', re.I)
RULE_SINKS = ('ai/dynamic/learnings.md', 'ai/dynamic/learned-patterns.md', 'ai/dynamic/feedback-learned.md',
              'ai/dynamic/decisions-pending.md', 'ai/failures/_index.md')
CHECKABLE = re.compile(r'`(@?[\w./-]+(?:\(\))?|[\w.]+\.\w+\(\))`')
ENFORCE_SPECS = ['eslint.config.*', '**/eslint.config.*', '.eslintrc*', '**/.eslintrc*', '.claude/hooks/**', '.github/workflows/**',
                 '.semgrep*', '**/.semgrep*', 'ruff.toml', 'pyproject.toml', 'biome.json*', '.husky/**', 'lefthook.y*ml',
                 '**/*.spec.*', '**/*.test.*', '**/*-spec.*', '**/test_*.py', 'dependency-cruiser*', '.dependency-cruiser*',
                 '**/.dependency-cruiser*']


def norm_heading(h):
    h = DATE.sub('', h)
    h = re.sub(r'[`*_#>\[\]()—–:;,.!?"\']', ' ', h.lower())
    return ' '.join(h.split())


def tokens(t):
    return set(w for w in re.findall(r'[a-z0-9_]{3,}', t.lower()))


class Sink(object):
    def __init__(self, repo, rel):
        self.rel = rel
        self.lines = repo.lines(rel) or []
        self.declared, self.fields, self.states = False, set(), set()
        self.entries = []
        self._parse()

    def _parse(self):
        fmt_start = fmt_end = None
        for i, l in enumerate(self.lines):
            if re.match(r'^##\s+(?:Format(?: per entry)?|Entry format)\b', l, re.I):
                fmt_start = i
                fence_seen, in_f = False, False
                for j in range(i + 1, len(self.lines)):
                    if K.FENCE_RE.match(self.lines[j]):
                        in_f = not in_f
                        if not in_f:
                            fmt_end = j + 1            # the declared format is the first fence; entries may follow it
                            break
                        fence_seen = True
                        continue
                    if not in_f and (re.match(r'^##\s', self.lines[j]) or (self.lines[j].startswith('### ') and fence_seen)):
                        fmt_end = j
                        break
                else:
                    fmt_end = len(self.lines)
                break
        self.dated_heading = False
        if fmt_start is not None:
            self.declared = True
            for l in self.lines[fmt_start:fmt_end]:
                if l.startswith('### ') and re.search(r'YYYY|\d{4}-\d\d', l):
                    self.dated_heading = True
                m = FIELD.match(l)
                if m and not l.lstrip().startswith('#'):
                    self.fields.add(m.group(1).strip().lower())
                    if m.group(1).strip().lower() == 'status':
                        self.states |= set(re.findall(r'\b([A-Z][A-Z_]{2,})\b', m.group(2)))
        fence, cur = False, None
        for i, l in enumerate(self.lines, 1):
            if K.FENCE_RE.match(l):
                fence = not fence
                continue
            if fence or (fmt_start is not None and fmt_start < i <= fmt_end):
                continue
            if l.startswith('### '):
                cur = {'line': i, 'heading': l[4:].strip(), 'body': [], 'fields': {}}
                self.entries.append(cur)
            elif re.match(r'^##?\s', l):
                cur = None
            elif cur is not None:
                cur['body'].append((i, l))
                m = FIELD.match(l)
                if m:
                    cur['fields'].setdefault(m.group(1).strip().lower(), m.group(2).strip())
        if self.dated_heading:
            # P-24: the sink declares dated entries; an undated `### ` is an entry only when it carries the
            # declared fields (otherwise it is a section such as "Already in the glossary").
            keep = []
            for e in self.entries:
                if DATE.search(e['heading']) or set(e['fields']) & self.fields:
                    keep.append(e)
            self.subheads = len(self.entries) - len(keep)
            self.entries = keep
        for e in self.entries:
            e['text'] = e['heading'] + '\n' + '\n'.join(l for _, l in e['body'])
            st = e['fields'].get('status', '')
            e['status'] = (re.match(r'([A-Z][A-Z_]+)', st).group(1) if re.match(r'([A-Z][A-Z_]+)', st) else '')
            d = DATE.findall(e['heading']) or DATE.findall(e['fields'].get('date', '')) or DATE.findall(e['text'])
            e['date'] = d[0] if d else ''
            e['last_date'] = max(DATE.findall(e['text'])) if DATE.findall(e['text']) else ''


def cites(text):
    out = []
    for m in CITE.finditer(text):
        p, ln = (m.group(1), m.group(2)) if m.group(1) else (m.group(3), m.group(4))
        if p and not re.match(r'^[a-z][\w+.-]*://', p) and '<' not in p:
            out.append((p, int(ln) if ln else None))
    return out


def scan(root, classes=tuple(range(1, 10)), only=None, entry=None, memory_dir=None, stuck_days=14, today=None):
    repo = K.Repo(root)
    today = today or datetime.date.today()
    sinks = [Sink(repo, r) for r in SINKS if r in repo.fset or repo.exists_on_disk(r)]
    if memory_dir and os.path.isdir(memory_dir):
        sinks += memory_sinks(memory_dir)
    rows, sites = [], {}

    def row(sec, kn, sev, rel, ln, subj, finding, verdict, note=''):
        rows.append({'sec': sec, 'kn': kn, 'sev': sev, 'site': '%s:%d' % (rel, ln), 'subject': subj,
                     'finding': finding, 'verdict': verdict, 'note': note})

    K.ledger('census=%s · sinks present %d of %d%s' % (repo.census, len([s for s in sinks if not s.rel.startswith('memory:')]),
                                                      len(SINKS), ' · memory dir read: %s' % memory_dir if memory_dir else
                                                      ' · memory dir NOT READ (opt-in --memory-dir, O-3)'))
    focus = only or entry
    all_entries = [(s, e) for s in sinks for e in s.entries]
    for s in sinks:
        if s.rel.startswith('memory:'):
            continue
        ok = gone = eof = 0
        stateless, first_stateless = 0, 0
        for e in s.entries:
            if focus and (s.rel, e['line']) != focus:
                continue
            terminal = bool(TERMINAL.match(e['status'])) or bool(re.search(r'\b(RESOLVED|SUPERSEDED|REJECTED)\b', e['heading']))
            cs = cites(e['text'])
            # §1 stale evidence
            if 1 in classes and cs and not terminal:
                bad = []
                for p, ln in cs:
                    if K.FOREIGN_LINE.search(next((l for _, l in e['body'] if p in l), '')):
                        continue                         # P-8: the entry quotes the other codebase (v1, legacy)
                    st, tgt, _ = repo.resolve(p, s.rel)
                    if st in ('dead',):
                        gone += 1
                        bad.append('%s gone' % p)
                    elif st == 'ambiguous':
                        ok += 1
                    elif ln and tgt and len(repo.lines(tgt) or []) < ln:
                        eof += 1
                        bad.append('%s:%d past EOF (%d lines)' % (p, ln, len(repo.lines(tgt) or [])))
                    else:
                        ok += 1
                if bad:
                    fail_sink = s.rel == 'ai/failures/_index.md'
                    row(1, 'KN-20', 'L' if fail_sink else 'M', s.rel, e['line'], e['heading'][:70],
                        '; '.join(bad[:3]) + (' …+%d' % (len(bad) - 3) if len(bad) > 3 else ''),
                        'unconfirmed' if fail_sink else 'candidate',
                        'a failure lesson may outlive its code: re-verify, mark SUPERSEDED with a reason' if fail_sink
                        else 'evidence moved: re-verify, then RESOLVED -> <sha> or re-point; never delete')
            # §4 provenance
            if 4 in classes:
                miss = []
                if not e['date']:
                    miss.append('date')
                has_src = bool(cs) or any(k in e['fields'] for k in ('source', 'where', 'evidence', 'from', 'origin', 'files',
                                                                     'seen in', 'occurrences', 'implementations')) \
                    or re.search(r'https?://|\buser\b[^.\n]{0,20}\b20\d\d-\d\d-\d\d|\b(?:PR|commit|issue)\s*#?\w+', e['text'], re.I)
                if not has_src:
                    miss.append('source / citation')
                if miss and s.rel not in ('ai/dynamic/changelog.md', 'ai/dynamic/interaction-log.md'):
                    row(4, 'KN-23', 'M' if 'source / citation' in miss else 'L', s.rel, e['line'], e['heading'][:70],
                        'no ' + ' and no '.join(miss), 'candidate', 'P-19: a preference entry cites "user, <date>"')
            # §5 lifecycle
            if 5 in classes:
                status_expected = ('status' in s.fields) if s.declared else (s.rel in TEMPLATE_STATUS)
                if status_expected and not e['status'] and not terminal:
                    stateless += 1
                    first_stateless = first_stateless or e['line']
                if e['status'] and s.states and e['status'] not in s.states and not TERMINAL.match(e['status']):
                    row(5, 'KN-24', 'L', s.rel, e['line'], e['heading'][:70], 'state %s is not one the sink declares (%s)'
                        % (e['status'], '/'.join(sorted(s.states))), 'candidate')
                rep = re.search(r'Repeated\s*[:=]\s*(\d+)', e['text'])
                ready = READY.match(e['status']) or (rep and int(rep.group(1)) >= 2 and 'feedback' in s.rel)
                if ready and e['date']:
                    y, m_, d_ = (list(map(int, e['date'].split('-'))) + [1])[:3]
                    age = (today - datetime.date(y, m_, d_)).days
                    if age > stuck_days:
                        row(5, 'KN-24', 'M' if age > 4 * stuck_days else 'L', s.rel, e['line'], e['heading'][:70],
                            '%s for %d days, never promoted' % (e['status'] or 'Repeated %s' % rep.group(1), age), 'candidate',
                            'promote (/promote-pattern, /promote-decision) or record why not')
            # §6 over-generalised
            if 6 in classes and s.rel in ('ai/dynamic/learnings.md', 'ai/dynamic/feedback-learned.md', 'ai/failures/_index.md'):
                rule = e['heading'] + ' ' + ' '.join(l for _, l in e['body'][:3])
                if UNIVERSAL.search(rule) and len(cs) < 2 and not SAFETY.search(e['text']) and not terminal:
                    row(6, 'KN-25', 'L', s.rel, e['line'], e['heading'][:70], 'universal rule from %d cited case(s)' % len(cs),
                        'unconfirmed', 'advisory: n=1 is enough only for safety or irreversible actions (P-20)')
            # §7 lesson -> enforcement
            if 7 in classes and s.rel in ('ai/dynamic/learnings.md', 'ai/dynamic/feedback-learned.md', 'ai/failures/_index.md') \
                    and not terminal:
                for l in [e['heading']] + [x for _, x in e['body']]:
                    if not (NEG.search(l) or re.search(r'\b(always|must)\b', l, re.I)):
                        continue
                    subj = [m.group(1) for m in CHECKABLE.finditer(l)
                            if re.search(r'[a-z]', m.group(1)) and not re.search(r'\.(md|ts|tsx|js|py)$', m.group(1))
                            and '/' not in m.group(1).lstrip('@').split('/')[0][:0] and len(m.group(1)) >= 3]
                    subj = [x for x in subj if not x.startswith(('ai/', '.claude/', 'docs/'))][:2]
                    for x in subj:
                        hit = enforced(repo, x.rstrip('()'))
                        if hit is False:
                            importish = re.search(r'\b(?:import\w*|require\w*|call\w*|use|using|fetch\w*)\b', l, re.I) and \
                                (x.rstrip('()') in packages(repo) or x.endswith('()'))
                            row(7, 'KN-26', 'M', s.rel, e['line'], x, 'checkable rule, no hook/lint/test names it',
                                'candidate' if importish else 'unconfirmed',
                                'hand off: /align for a convention, /add-feature for a hook or test')
                    if subj:
                        break
        if s.entries:
            K.ledger('  %-34s entries %3d · format %s · citations ok %d / gone %d / past-EOF %d' % (
                s.rel, len(s.entries), 'declared (%s)' % ','.join(sorted(s.fields)) if s.declared else 'template',
                ok, gone, eof))
        if 5 in classes and stateless and not focus:
            row(5, 'KN-24', 'L', s.rel, first_stateless, 'Status', '%d of %d entries carry no state' % (stateless, len(s.entries)),
                'candidate', 'the sink format expects a Status line')
    # §2 duplicates and §3 contradiction pairs
    if (2 in classes or 3 in classes):
        heads = {}
        for s, e in all_entries:
            heads.setdefault(norm_heading(e['heading']), []).append((s, e))
        for h, group in heads.items():
            if len(group) < 2 or len(h) < 8:
                continue
            if focus and not any((s.rel, e['line']) == focus for s, e in group):
                continue
            if 2 in classes:
                s0, e0 = group[0]
                row(2, 'KN-21', 'L', s0.rel, e0['line'], h[:70], 'same heading in %d entries: %s' % (
                    len(group), ', '.join('%s:%d' % (s.rel, e['line']) for s, e in group[1:4])), 'candidate',
                    'merge into one entry; keep both citations')
        if 2 in classes:
            toks = [(s, e, tokens(e['text'])) for s, e in all_entries]
            for i in range(len(toks)):
                for j in range(i + 1, len(toks)):
                    a, b = toks[i], toks[j]
                    if len(a[2]) < 15 or len(b[2]) < 15 or norm_heading(a[1]['heading']) == norm_heading(b[1]['heading']):
                        continue
                    if focus and focus not in ((a[0].rel, a[1]['line']), (b[0].rel, b[1]['line'])):
                        continue
                    jac = len(a[2] & b[2]) / float(len(a[2] | b[2]))
                    if jac >= 0.8:
                        row(2, 'KN-21', 'L', a[0].rel, a[1]['line'], a[1]['heading'][:60], 'near-duplicate of %s:%d (%.2f)'
                            % (b[0].rel, b[1]['line'], jac), 'judge', 'both entries attached for the judge')
        if 3 in classes:
            rules = []
            for f in ['CLAUDE.md', 'AGENTS.md'] + sorted(x for x in repo.files if x.startswith('.claude/rules/')):
                for ln, l in enumerate(repo.lines(f) or [], 1):
                    if NEG.search(l) or POS.search(l):
                        rules.append((f, ln, l))
            units = [(s.rel, e['line'], l, e) for s, e in all_entries for _, l in [(0, e['heading'])] + e['body']
                     if not TERMINAL.match(e['status']) and (s.rel in RULE_SINKS or s.rel.startswith('memory:'))]
            pairs, seen = [], set()
            for i, (ra, la, ta, ea) in enumerate(units):
                subs = set(x for x in re.findall(r'`([^`\s]{3,60})`', ta) if '/' not in x and not x.endswith('.md'))
                if not subs:
                    continue
                pa = 'neg' if NEG.search(ta) else ('pos' if POS.search(ta) else None)
                if not pa:
                    continue
                others = [(rb, lb, tb) for rb, lb, tb, eb in units[i + 1:] if eb is not ea] + rules
                for rb, lb, tb in others:
                    shared = subs & set(re.findall(r'`([^`\s]{3,60})`', tb))
                    if not shared:
                        continue
                    pb = 'neg' if NEG.search(tb) else ('pos' if POS.search(tb) else None)
                    if pb and pb != pa:
                        k = (ra, la, rb, lb)
                        if k in seen:
                            continue
                        seen.add(k)
                        if focus and focus not in ((ra, la), (rb, lb)):
                            continue
                        pairs.append((len(shared), ra, la, ta, rb, lb, tb, sorted(shared)[0]))
            for n, ra, la, ta, rb, lb, tb, sub in sorted(pairs, key=lambda p: -p[0])[:50]:
                row(3, 'KN-22', 'H' if rb in ('CLAUDE.md', 'AGENTS.md') or rb.startswith('.claude/rules/') else 'M', ra, la, sub,
                    'opposite polarity vs %s:%d' % (rb, lb), 'judge',
                    'A: "%s" | B: "%s"' % (ta.strip()[:90], tb.strip()[:90]))
            if len(pairs) > 50:
                K.ledger('§3: %d polarity pairs, top 50 printed (Live, unreviewed: the rest)' % len(pairs))
    # §8 consumer contracts
    if 8 in classes and not focus:
        for c in contracts(repo):
            s = next((x for x in sinks if x.rel == c['sink']), None)
            if not s or not s.entries:
                continue
            rx = re.compile(c['pattern'], re.M)
            n = len(s.entries)
            exact = sum(1 for e in s.entries if any(rx.search(l) for _, l in [(0, '### ' + e['heading'])] + e['body']))
            if c['kind'] == 'population':
                ratio = exact / float(n)
                if ratio < 0.5:
                    why = ('the sink declares its own format without this field (P-24): the consumer must read the declared format'
                           if s.declared and c['field'] not in s.fields else 'entries drifted from the format the consumer reads')
                    row(8, 'KN-27', 'M', c['consumer'], c['line'], c['pattern'], '%s reads %d of %d entries (%.2f)' % (
                        c['sink'], exact, n, ratio), 'candidate', why)
            else:
                # A subset consumer counts the entries whose field has ONE value (`^Severity: high`); an entry with
                # another value in the same shape (`Severity: low` at column 0) is read and rightly not counted. Compare
                # "carries the field" with "carries it in the consumer's shape" (the pattern up to its colon).
                shp = re.match(r'^(\^?\s*[A-Za-z][\w ]*?\s*:)', c['pattern'])
                srx = re.compile(shp.group(1), re.M) if shp else rx
                readable = sum(1 for e in s.entries if any(srx.search(l) for _, l in [(0, '### ' + e['heading'])] + e['body']))
                anyshape = sum(1 for e in s.entries if re.search(r'\b' + re.escape(c['field']) + r'\s*[:=]', e['text'], re.I))
                if anyshape > readable:
                    row(8, 'KN-27', 'M', c['consumer'], c['line'], c['pattern'], '%d %s entries carry `%s` in a shape the consumer '
                        'cannot read (%d match)' % (anyshape - readable, c['sink'], c['field'], exact), 'candidate',
                        'align the entry shape with the declared format, or the consumer with it')
            K.ledger('  contract %-28s %-24s matched %d of %d entries' % (c['consumer'].split('/')[-1], c['pattern'][:24], exact, n))
    # §9 eval guard count
    if 9 in classes and not focus:
        cov = eval_coverage(repo)
        row(9, 'KN-36', 'L', 'ai/evals/cases', 0, 'eval cases', '%d case(s); %d of %d promoted unit(s) guarded' % (
            cov['cases'], cov['guarded'], cov['units']), 'info', 'a count only: /eval --coverage grades')
    return rows


_PKGS = {}


def packages(repo):
    if repo.root not in _PKGS:
        v, _, d = K.lock_versions(repo)
        _PKGS[repo.root] = set(v) | set(d)
    return _PKGS[repo.root]


def enforced(repo, subject):
    """True when a lint config, hook, CI workflow or test names the subject; False when none does;
    None when the search could not run."""
    if not repo.has_git:
        return None
    specs = [':(glob)' + s for s in ENFORCE_SPECS]
    rc, out = K.git(repo.root, 'grep', '-l', '-I', '-F', '-e', subject, '--', *specs)
    if rc not in (0, 1):
        return None
    if out.strip():
        return True
    for d in ('.claude/hooks',):
        p = os.path.join(repo.root, d)
        if os.path.isdir(p):
            for f in os.listdir(p):
                if subject in (K.read_text(os.path.join(p, f)) or ''):
                    return True
    return False


def contracts(repo):
    """Consumer contracts: regexes that installed hooks, agents and commands apply to a sink."""
    out = []
    known = [('.claude/hooks/session-start.sh', r'^Severity: high', 'ai/dynamic/drift-log.md', 'severity', 'subset'),
             ('.claude/hooks/session-start.sh', r'^Status: READY', 'ai/dynamic/learned-patterns.md', 'status', 'subset'),
             ('.claude/agents/knowledge-curator.md', r'(?i)status:?\s*\**\s*OPEN', 'ai/dynamic/drift-log.md', 'status', 'population')]
    for consumer, pat, sink, field, kind in known:
        lines = repo.lines(consumer) if (consumer in repo.fset or repo.exists_on_disk(consumer)) else None
        if not lines:
            continue
        needle = {'^Severity: high': r'Severity: high', '^Status: READY': r'Status: READY'}.get(pat, r'(?i)status\s*`?OPEN')
        ln = next((i for i, l in enumerate(lines, 1) if re.search(needle, l)), 0)
        if ln:
            out.append({'consumer': consumer, 'line': ln, 'pattern': pat, 'sink': sink, 'field': field, 'kind': kind})
    hooks = [f for f in repo.files if f.startswith('.claude/hooks/')]
    for f in hooks:
        for i, l in enumerate(repo.lines(f) or [], 1):
            m = re.search(r'grep\s+(?:-\w+\s+)*["\'](\^[^"\']+)["\']\s+((?:ai)/[\w./-]+\.md)', l)
            if m and not any(c['consumer'] == f and c['pattern'] == m.group(1) for c in out):
                fld = re.match(r'\^\s*([A-Za-z]+)', m.group(1))
                out.append({'consumer': f, 'line': i, 'pattern': m.group(1), 'sink': m.group(2),
                            'field': fld.group(1).lower() if fld else '', 'kind': 'subset'})
    return out


def eval_coverage(repo):
    cases, guards = [], set()
    for f in sorted(x for x in repo.files if x.startswith('ai/evals/cases/') and x.endswith('.md')):
        if os.path.basename(f).startswith('_'):
            continue
        cases.append(f)
        fm = '\n'.join((repo.lines(f) or [])[:40])
        m = re.search(r'^guards:\s*(.*(?:\n\s+-\s+.*)*)', fm, re.M)
        if m:
            guards.update(x.strip(' -[]"\'') for x in re.split(r'[,\n]', m.group(1)) if x.strip(' -[]"\''))
    units = []
    for f in repo.files:
        if f.startswith('ai/patterns/') and f.endswith('.md') and not os.path.basename(f).startswith(('_', 'README')):
            if 'pack' not in K.frontmatter(repo.lines(f) or []):
                units.append(f)
        elif f.startswith('.claude/rules/') and f.endswith('.md') and 'pack' not in K.frontmatter(repo.lines(f) or []):
            units.append(f)
    guarded = [u for u in units if any(g and (g in u or u.endswith(g)) for g in guards)]
    return {'cases': len(cases), 'case_files': cases, 'guards': sorted(guards), 'units': len(units),
            'guarded': len(guarded), 'unguarded': sorted(set(units) - set(guarded))}


def memory_sinks(d):
    """O-3 opt-in: the host memory dir's topic files as one-entry sinks (MEMORY.md is an index, P-18)."""
    out = []
    for f in sorted(os.listdir(d)):
        if not f.endswith('.md') or f == 'MEMORY.md':
            continue
        txt = K.read_text(os.path.join(d, f)) or ''
        s = Sink.__new__(Sink)
        s.rel, s.lines, s.declared, s.fields, s.states = 'memory:' + f, K.split_lines(txt), False, set(), set()
        fm = K.frontmatter(s.lines)
        e = {'line': 1, 'heading': fm.get('description') or fm.get('name') or f, 'body': [(i, l) for i, l in enumerate(s.lines, 1)],
             'fields': {}, 'status': '', 'date': (DATE.findall(fm.get('modified', '') + txt) or [''])[0]}
        e['text'] = txt
        e['last_date'] = e['date']
        s.entries = [e]
        out.append(s)
    return out


def emit(rows, as_json):
    if as_json:
        print(json.dumps(rows, indent=1))
        return
    print('# §\tclass\tsev\tsite\tsubject\tfinding\tverdict\tnote')
    for r in sorted(rows, key=lambda r: (r['sec'], {'H': 0, 'M': 1, 'L': 2}[r['sev']], r['site'])):
        print('\t'.join(str(r[k]) for k in ('sec', 'kn', 'sev', 'site', 'subject', 'finding', 'verdict', 'note')))


# ------------------------------------------------------------------ self-test
def _w(root, rel, text):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p) or root, exist_ok=True)
    with open(p, 'w') as fh:
        fh.write(text)


def self_test():
    K.QUIET = True
    tmp = tempfile.mkdtemp(prefix='sink-audit-selftest.')
    fails = []
    try:
        root = os.path.join(tmp, 'repo')
        os.makedirs(root)
        env = dict(K.GIT_ENV, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1', HOME=tmp)
        git = lambda *a: subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@t', '-c', 'commit.gpgsign=false'] + list(a),
                                        cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        _w(root, 'src/orders.ts', '\n'.join('line %d' % i for i in range(120)) + '\n')
        _w(root, 'package.json', '{"name":"x","dependencies":{"axios":"^1","moment":"^2"}}')
        _w(root, 'eslint.config.mjs', "export default [{ rules: { 'no-restricted-imports': ['error', 'moment'] } }];\n")
        _w(root, '.claude/hooks/session-start.sh', 'HIGH=$(grep -c "^Severity: high" ai/dynamic/drift-log.md)\n')
        _w(root, '.claude/agents/knowledge-curator.md', 'Never discard a `WATCHING` / `OPEN` entry.\nDuty 4: re-verify every drift entry with status `OPEN`.\n')
        _w(root, 'CLAUDE.md', '# Rules\n- Always use `transactions` around a money write.\n')
        _w(root, 'ai/dynamic/drift-log.md', '\n'.join([
            '# Drift log', '', '## Format per entry', '', '```', '### <YYYY-MM-DD> — <area>: <drift>', '- Where: `path:line`',
            '- Drift: <what>', '```', '', 'A high entry adds a line starting `Severity: high`.', '', '## Open entries', '',
            '### 2026-09-01 — api: orders helper moved',                       # 15: KN-20 gone path
            '- Where: `src/legacy-orders.ts:10`', '- Drift: x', '',
            '### 2026-09-02 — api: list past end',                             # 19: KN-20 past EOF
            '- Where: `src/orders.ts:205`', '- Drift: y; `this.tx.run` and `engine.io` are not paths', '- Severity: high', '',   # 22: KN-27
            '### 2026-09-03 — api: still fine',
            '- Where: `src/orders.ts:5`', '- Drift: z', '',
            '### 2026-09-04 — RESOLVED api: old thing',                        # decoy: terminal, cites deleted path
            '- Where: `src/deleted.ts:1`', '']))
        _w(root, 'ai/dynamic/learnings.md', '\n'.join([
            '# Learnings', '', '## Format per entry', '', '```', '### YYYY-MM-DD — <topic>', 'Status: RAW | PROMOTE_CANDIDATE | PROMOTED',
            'Source: <where>', '```', '', '## Entries', '',
            '### 2026-08-01 — never use transactions in read paths',            # 13: KN-25 + KN-22 vs CLAUDE.md
            'Status: RAW', 'Source: `src/orders.ts:3`', 'Never wrap `transactions` around reads.', '',
            '### 2026-08-02 — moment is banned',                                 # 18: enforced -> no KN-26
            'Status: RAW', 'Source: `src/orders.ts:4`', 'Never import `moment` directly.', '',
            '### 2026-08-03 — axios must not be imported',                       # 23: KN-26 no lint
            'Status: RAW', 'Source: `src/orders.ts:6`', 'Never import `axios` directly; use the http client.', '',
            '### Undated thing with no source',                                  # 28: KN-23
            'Status: RAW', 'Some text.', '',
            '### 2026-08-03 — axios must not be imported',                       # 32: KN-21 dup heading
            'Status: RAW', 'Source: `src/orders.ts:7`', '',
            '### 2026-07-01 — stuck candidate',                                  # 36: KN-24 stuck
            'Status: PROMOTE_CANDIDATE', 'Source: `src/orders.ts:8`', '',
            '### 2026-08-05 — never force-push to main',                         # decoy P-20 safety n=1
            'Status: RAW', 'Source: user, 2026-08-05', '']))
        _w(root, 'ai/dynamic/learned-patterns.md', '# Patterns\n\n### 2026-07-01 — outbox emit\nStatus: READY\nWhere: `src/orders.ts:9`\n')
        _w(root, 'ai/evals/cases/_template.md', '---\nguards: []\n---\n')
        git('init', '-q')
        git('add', '-A')
        git('commit', '-q', '-m', 'one')
        rows = scan(root, today=datetime.date(2026, 10, 19))
        got = set((r['kn'], r['site']) for r in rows)
        for kn, site, label in [('KN-20', 'ai/dynamic/drift-log.md:15', 'gone path'), ('KN-20', 'ai/dynamic/drift-log.md:19', 'past EOF'),
                                ('KN-25', 'ai/dynamic/learnings.md:13', 'n=1 universal'),
                                ('KN-22', 'ai/dynamic/learnings.md:13', 'contradiction vs CLAUDE.md'),
                                ('KN-26', 'ai/dynamic/learnings.md:23', 'no lint for axios'),
                                ('KN-23', 'ai/dynamic/learnings.md:28', 'no date no source'),
                                ('KN-21', 'ai/dynamic/learnings.md:23', 'duplicate heading'),
                                ('KN-24', 'ai/dynamic/learnings.md:36', 'stuck PROMOTE_CANDIDATE'),
                                ('KN-24', 'ai/dynamic/learned-patterns.md:3', 'stuck READY'),
                                ('KN-27', '.claude/agents/knowledge-curator.md:2', 'population contract status OPEN'),
                                ('KN-27', '.claude/hooks/session-start.sh:1', 'Severity in a list item')]:
            if (kn, site) not in got:
                fails.append('missing %s: %s %s' % (label, kn, site))
        for pred, label in [(lambda r: r['site'].startswith('ai/dynamic/drift-log.md:2') and r['kn'] == 'KN-20' and r['site'].endswith(':24'), 'resolving entry'),
                            (lambda r: 'this.tx.run' in r['finding'] or 'engine.io' in r['finding'], 'dotted identifier read as a path'),
                            (lambda r: r['site'] == 'ai/dynamic/drift-log.md:27', 'RESOLVED entry (history)'),
                            (lambda r: r['kn'] == 'KN-26' and r['subject'] == 'moment', 'enforced lesson'),
                            (lambda r: r['kn'] == 'KN-25' and 'force-push' in r['subject'], 'P-20 safety lesson'),
                            (lambda r: r['kn'] == 'KN-23' and r['site'].endswith(':41'), 'P-19 user provenance'),
                            (lambda r: r['kn'] == 'KN-24' and 'drift-log' in r['site'] and 'carry no state' in r['finding'], 'P-24 declared format without Status')]:
            bad = [r for r in rows if pred(r)]
            if bad:
                fails.append('false row %s: %s' % (label, bad[0]))
        one = scan(root, only=('ai/dynamic/drift-log.md', 15), today=datetime.date(2026, 10, 19), classes=(1,))
        if [r['site'] for r in one] != ['ai/dynamic/drift-log.md:15']:
            fails.append('--only did not isolate the entry: %s' % [r['site'] for r in one])
        cov = eval_coverage(K.Repo(root))
        if cov['cases'] != 0:
            fails.append('_template counted as a case')
        # Subset contract: an entry the consumer's shape reads (`Severity: low` at column 0) is readable even when its
        # value is not the one the consumer counts; a bold field with the colon inside the bold carries its value.
        _w(root, 'ai/dynamic/drift-log.md', '\n'.join([
            '# Drift log', '', '## Format per entry', '', '```', '### <YYYY-MM-DD> — <area>: <drift>', '- Where: `path:line`',
            'Severity: low | high', '```', '', '## Open entries', '',
            '### 2026-09-02 — api: a', '- Where: `src/orders.ts:5`', 'Severity: low', '',
            '### 2026-09-03 — api: b', '- Where: `src/orders.ts:6`', 'Severity: high', '']))
        _w(root, 'ai/dynamic/learned-patterns.md', '# Patterns\n\n### 2026-07-01 — outbox emit\n- **Status:** READY\n- **Where:** `src/orders.ts:9`\n')
        rows = scan(root, today=datetime.date(2026, 10, 19))
        bad = [r for r in rows if r['kn'] == 'KN-27' and r['site'] == '.claude/hooks/session-start.sh:1']
        if bad:
            fails.append('subset contract: `Severity: low` at column 0 counted as unreadable: %s' % bad[0])
        rd = [r for r in rows if r['kn'] == 'KN-24' and r['site'] == 'ai/dynamic/learned-patterns.md:3']
        if not rd or not rd[0]['finding'].startswith('READY'):
            fails.append('`- **Status:** READY` (colon inside the bold) not read as READY: %s' % rd)
        bad = [r for r in rows if 'carry no state' in r['finding']]
        if bad:
            fails.append('`**Status:** READY` read as no state: %s' % bad[0])
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        sys.stderr.write('self-test FAIL: %s\n' % f)
    print('sink-audit.py --self-test %s' % ('OK' if not fails else 'FAILED (%d)' % len(fails)))
    return 0 if not fails else 3


def main(argv):
    classes, only, entry, mdir, stuck, today, as_json, root, cov = tuple(range(1, 10)), None, None, None, 14, None, False, None, False
    for a in argv:
        if a == '--self-test':
            return self_test()
        elif a.startswith('--classes='):
            classes = tuple(int(x) for x in a.split('=', 1)[1].split(',') if x.strip())
        elif a.startswith(('--only=', '--entry=')):
            f, _, l = a.split('=', 1)[1].rpartition(':')
            if not l.isdigit():
                sys.stderr.write('%s needs <sink>:<line>\n' % a.split('=')[0])
                return 2
            if a.startswith('--only='):
                only = (f, int(l))
            else:
                entry = (f, int(l))
                classes = (2, 3, 4)
        elif a.startswith('--memory-dir='):
            mdir = os.path.expanduser(a.split('=', 1)[1])
        elif a.startswith('--stuck-days='):
            stuck = int(a.split('=', 1)[1])
        elif a.startswith('--today='):
            today = datetime.date(*map(int, a.split('=', 1)[1].split('-')))
        elif a == '--eval-coverage':
            cov = True
        elif a == '--json':
            as_json = True
        elif a.startswith('-'):
            sys.stderr.write('unknown option %s\n' % a)
            return 2
        else:
            root = a
    if not root or not os.path.isdir(root):
        sys.stderr.write('usage: sink-audit.py <root> [options] | --self-test (blocked: no such root)\n')
        return 2
    if cov:
        print(json.dumps(eval_coverage(K.Repo(root)), indent=1))
        return 0
    rows = scan(root, classes, only, entry, mdir, stuck, today)
    emit(rows, as_json)
    return 1 if any(r['verdict'] in ('candidate', 'unconfirmed', 'judge') for r in rows) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
