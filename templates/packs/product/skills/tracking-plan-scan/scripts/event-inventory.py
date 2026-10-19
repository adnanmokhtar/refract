#!/usr/bin/env python3
"""event-inventory.py — tracking-plan-scan §1-§7: every analytics call site joined against the tracking
plan. Stdlib only, Python 3.8+, run with `python3 -I`.

Why a script and not rg: drift is a JOIN (plan names x call-site names, plan properties x the literal
object at each site) after resolving the project's own wrapper (`trackEvent(name, data)` forwarding to
fbq / dataLayer / a server leg), normalising names (case, separators, tense) and reading the firing point
(on click, after an await, inside onSuccess / catch / useEffect). A per-line grep sees none of that.

Usage:  python3 -I event-inventory.py [<root> ...] [--plan=<file>]... [--wrapper=name,...]
            [--success=<dir>] [--include-tests] [--inventory] [--max=N] [--json]
        python3 -I event-inventory.py --self-test
Call lanes: Segment / RudderStack (analytics.track, object form), Amplitude (track / logEvent / BaseEvent),
  Mixpanel, PostHog (capture, object form), Heap, Umami, Plausible, Statsig and Firebase logEvent
  (modular and namespaced), GA4 gtag('event'), Meta fbq('track'|'trackCustom'), GTM dataLayer.push({event}),
  Snowplow trackSelfDescribingEvent (iglu schema = name), Ampli / Avo generated functions, Python
  (Segment, PostHog, Mixpanel, Amplitude), Ruby (Segment, Mixpanel), Go (analytics.Track{Event:}),
  Dart / Kotlin / Swift logEvent and track. Plus the project's wrappers: discovered (a function whose
  parameter is forwarded as the event name to an SDK call) and --wrapper=.
Plan sources, in precedence: --plan files; Ampli (ampli.json + generated ampli/index.* event classes);
  Avo (avo.json + generated Avo.* functions); Iglu JSON schemas (**/jsonschema/**); plan files named
  tracking-plan / tracking_plan / trackingPlan / analytics-events (.json .yml .yaml .ts .md); a typed
  union or enum the wrapper's name parameter is typed with. JSON and a YAML subset are parsed; Markdown
  plans are read from tables (first cell) and bullets of backticked names.
Rows:
  AN1  unplanned (a fired name the plan lacks) · no-plan (one Hardening inventory row)
  AN2  never-fired (a plan name, or a --success metric event, with no call site; `metric=yes` for the latter)
  AN3  spelling (one normalised name, several spellings) · convention (outside the dominant style, >= 5 names)
  AN4  keys-differ (same event, different key sets) · type-conflict · required-missing · unplanned-property ·
       type-mismatch (plan type vs literal)
  AN5  outcome-named event (Purchased, Completed, Registered, Paid, Subscribed, Placed, Ordered, Verified,
       Activated, Upgraded, Converted, Renewed, Signed Up) with its firing context:
       on-intent | on-failure | effect(deps) | before-await | after-await(<callee>) | on-success | top-level
  AN6  multi-site (one name fired from >= 2 sites of one file) · effect-deps / effect-no-deps · two-legs
       (client and server both fire it; event_id=yes|no)
  AN7  untyped-wrapper (name parameter typed string or untyped) · bypasses-codegen · bypasses-wrapper
  UNRESOLVED  a call whose name is not a literal (never a mismatch)
Output: TSV with `# KIND` headers, or --json. --inventory adds SITE, PLAN and WRAPPER rows.
Stderr: the ledger - files read, sites per lane, wrappers and their signature, plan sources read and
  parse errors, names, unresolved count, what ran N/A and why.
Exit:   0 no plan-backed drift · 2 at least one AN1-unplanned, AN2, AN3-spelling or AN4 row backed by a plan
        or success file (the oracle shape: exit 2 before the fix, 0 after) · 1 usage · 3 self-test failed.
        AN1 no-plan, AN3 convention, AN5, AN6 and AN7 are read lists and never set the exit code.
        Reads files; writes nothing (the self-test uses a temp dir it removes).
"""
import bisect, json, os, re, shutil, sys, tempfile, time

SKIP_DIRS = {'node_modules', 'vendor', 'dist', 'build', 'out', '.next', '.nuxt', '.output', '.svelte-kit', '.turbo',
             'coverage', '.git', '.venv', 'venv', '__pycache__', '.dart_tool', 'Pods', 'DerivedData', 'target', '.cache'}
TEST_DIRS = {'test', 'tests', '__tests__', 'spec', 'specs', 'e2e', 'fixtures', '__fixtures__', 'mocks', '__mocks__',
             'testdata', 'stories', 'cypress', 'playwright'}
TEST_FILE = re.compile(r'(\.(spec|test|e2e-spec|e2e|stories|story|test-data)\.[^/]+$)|(^|/)(test_[^/]+\.py|[^/]+_test\.(go|py|dart)|conftest\.py)$')
NOT_SHIPPED = re.compile(r'(?:^|/)(?:scripts|tools|bin|examples?|docs?|storybook|\.storybook)(?:/|$)')
EXT = {'.ts': 'js', '.tsx': 'js', '.js': 'js', '.jsx': 'js', '.mjs': 'js', '.cjs': 'js', '.vue': 'js', '.svelte': 'js',
       '.py': 'py', '.rb': 'rb', '.go': 'go', '.dart': 'dart', '.kt': 'kt', '.swift': 'swift', '.java': 'kt'}
PLAN_NAME = re.compile(r'(?:^|/)(?:tracking[-_]?plan|trackingPlan|analytics[-_]events)[^/]*\.(?:json|ya?ml|ts|md)$', re.I)
STR = r'([\'"`])((?:\\.|(?!\1)[^\n\\])*)\1'
SDK = 'analytics|posthog|mixpanel|amplitude|rudderanalytics|heap|umami|statsig|Statsig|segment|Segment|Analytics|firebaseAnalytics|FirebaseAnalytics\\.instance|Mixpanel|Amplitude'
LANES = [
    ('sdk', re.compile(r'(?<![\w$])(?:window\.)?(?:' + SDK + r')(?:\.\w+)?\s*\.\s*(?:track|capture|logEvent|trackEvent|event)\s*\(\s*(?:name\s*:\s*)?' + STR)),
    ('gtag', re.compile(r'(?<![\w$])gtag\s*\(\s*[\'"]event[\'"]\s*,\s*' + STR)),
    ('fbq', re.compile(r'(?<![\w$])(?:window\.)?fbq\s*\(\s*[\'"](?:track|trackCustom)[\'"]\s*,\s*' + STR)),
    ('plausible', re.compile(r'(?<![\w$.])plausible\s*\(\s*' + STR)),
    ('firebase', re.compile(r'(?<![\w$.])logEvent\s*\(\s*\w+\s*,\s*' + STR)),
    ('dataLayer', re.compile(r'dataLayer\.push\s*\(\s*\{[^{}]*?\bevent\s*:\s*' + STR)),
    ('object', re.compile(r'(?<![\w$])(?:' + SDK + r')\s*\.\s*(?:track|capture)\s*\(\s*\{[^{}]*?\bevent\s*:\s*' + STR)),
    ('snowplow', re.compile(r'trackSelfDescribingEvent\s*\(\s*\{[\s\S]{0,200}?schema\s*:\s*([\'"])iglu:((?:(?!\1).)*)\1')),
    ('py', re.compile(r'(?<![\w.])(?:analytics|posthog|mixpanel|segment|mp|tracker)\.(?:track|capture)\s*\(\s*(?:distinct_id\s*=\s*)?[^,()\n]+(?:\([^()\n]*\))?\s*,\s*(?:event\s*=\s*)?' + STR)),
    ('py-amplitude', re.compile(r'BaseEvent\s*\(\s*event_type\s*=\s*' + STR)),
    ('ruby', re.compile(r'Analytics\.track\s*\(\s*[\s\S]{0,160}?\bevent:\s*' + STR)),
    ('go', re.compile(r'analytics\.Track\s*\{[\s\S]{0,200}?\bEvent\s*:\s*"([^"]*)"')),
    ('dart-kt-swift', re.compile(r'\.logEvent\s*\(\s*(?:name\s*:\s*)?' + STR)),
]
CODEGEN_CALL = re.compile(r'(?<![\w$])(ampli|Avo)\s*\.\s*([a-z]\w*)\s*\(')
CODEGEN_SKIP = {'load', 'identify', 'group', 'flush', 'track', 'setGroup', 'client', 'isLoaded', 'init', 'initAvo', 'groupIdentify'}
OUTCOME = {'purchased', 'purchase', 'completed', 'complete', 'registered', 'registration', 'subscribed', 'subscribe', 'paid',
           'placed', 'verified', 'activated', 'upgraded', 'converted', 'signedup', 'signup', 'ordered', 'booked', 'redeemed',
           'checkedout', 'renewed', 'trialstarted'}
AUTO_EVENT = re.compile(r'^(?:gtm\.|\$(?:pageview|pageleave|autocapture|screen|identify|set|groupidentify)\b|page_view$|screen_view$|session_start$|first_visit$|user_engagement$)')
INTENT = {'started', 'start', 'clicked', 'click', 'viewed', 'view', 'shown', 'opened', 'attempted', 'initiated', 'requested',
          'began', 'begin', 'tapped', 'closed', 'dismissed', 'impression', 'hovered', 'expanded'}


class F(object):
    __slots__ = ('path', 'rel', 'lang', 'raw', 'code', 'nl', 'test')

    def __init__(self, path, rel, lang, raw, test):
        self.path, self.rel, self.lang, self.raw, self.test = path, rel, lang, raw, test
        self.code = mask(raw, lang)
        self.nl = [i for i, c in enumerate(raw) if c == '\n']

    def line(self, pos):
        return bisect.bisect_left(self.nl, pos) + 1


def skip_str(s, i):
    q, j, n, depth = s[i], i + 1, len(s), 0
    while j < n:
        c = s[j]
        if c == '\\':
            j += 2; continue
        if q == '`' and s.startswith('${', j):
            depth += 1; j += 2; continue
        if q == '`' and depth and c == '}':
            depth -= 1; j += 1; continue
        if c == q and not depth:
            return j + 1
        if c == '\n' and q != '`':
            return j
        j += 1
    return n


def mask(s, lang):
    out, i, n = list(s), 0, len(s)

    def blank(a, b):
        for k in range(a, min(b, n)):
            if out[k] != '\n':
                out[k] = ' '
    while i < n:
        c = s[i]
        if lang == 'py' and s.startswith(('"""', "'''"), i):
            q = s[i:i + 3]; j = s.find(q, i + 3); j = n if j < 0 else j + 3
            k = i - 1
            while k >= 0 and s[k] in ' \t':
                k -= 1
            if k < 0 or s[k] == '\n':
                blank(i, j)
            i = j; continue
        if c in '"\'' or (c == '`' and lang in ('js', 'go')):
            i = skip_str(s, i); continue
        if lang in ('py', 'rb') and c == '#':
            j = s.find('\n', i); j = n if j < 0 else j; blank(i, j); i = j; continue
        if lang not in ('py', 'rb') and s.startswith('//', i) and not (i > 0 and s[i - 1] == ':'):
            j = s.find('\n', i); j = n if j < 0 else j; blank(i, j); i = j; continue
        if lang not in ('py', 'rb') and s.startswith('/*', i):
            j = s.find('*/', i + 2); j = n if j < 0 else j + 2; blank(i, j); i = j; continue
        i += 1
    return ''.join(out)


def close_of(s, i):
    pair = {'(': ')', '[': ']', '{': '}'}
    stack, j, n = [], i, len(s)
    while j < n:
        c = s[j]
        if c in '"\'`':
            j = skip_str(s, j); continue
        if c in pair:
            stack.append(pair[c])
        elif c in ')]}':
            if not stack or stack[-1] != c:
                return j + 1
            stack.pop()
            if not stack:
                return j + 1
        j += 1
    return n


def walk(roots, include_tests, ledger):
    files, plans, gen = [], [], []
    for root in roots:
        for d, dirs, names in os.walk(root):
            dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS and not (x.startswith('.') and x != '.avo'))
            for nm in sorted(names):
                p = os.path.join(d, nm)
                rel = (os.path.relpath(p, root) if len(roots) == 1 else p).replace(os.sep, '/')
                is_test = bool(set(rel.split('/')[:-1]) & TEST_DIRS) or bool(TEST_FILE.search(rel))
                if not is_test and (PLAN_NAME.search(rel) or nm in ('ampli.json', 'avo.json') or ('/jsonschema/' in '/' + rel and '/schemas/' in '/' + rel)):
                    plans.append(p)
                if not is_test and re.search(r'(?:^|/)(?:ampli/index|Avo|avo)\.(?:ts|js|py|dart|kt|swift)$', rel):
                    gen.append(p)
                lang = EXT.get(os.path.splitext(nm)[1].lower())
                if not lang or (is_test and not include_tests):
                    continue
                try:
                    with open(p, encoding='utf-8', errors='replace') as fh:
                        raw = fh.read()
                except OSError as e:
                    ledger.setdefault('unreadable', []).append('%s (%s)' % (rel, e.strerror)); continue
                if len(raw) > 2000000 or ('\n' not in raw[:5000] and len(raw) > 20000):
                    continue
                files.append(F(p, rel, lang, raw, is_test))
    return files, plans, gen


# ---------------------------------------------------------------- names
def words(name):
    n = re.sub(r'^iglu:', '', name)
    n = re.sub(r'/jsonschema/.*$', '', n).split('/')[-1]
    n = re.sub(r'([a-z0-9])([A-Z])', r'\1 \2', n)
    n = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1 \2', n)
    return [w for w in re.split(r'[\s_.:\-/]+', n.lower()) if w]


def stem(w):
    for suf, rep in (('ing', ''), ('ied', 'y'), ('ed', ''), ('es', ''), ('e', ''), ('s', '')):
        if w.endswith(suf) and len(w) - len(suf) >= 3:
            return w[:len(w) - len(suf)] + rep
    return w


def nkey(name):
    return ' '.join(stem(w) for w in words(name))


def style(name):
    if re.match(r'^[A-Z][a-z0-9]*(?: [A-Z][a-z0-9]*)+$', name):
        return 'Title Case'
    if re.match(r'^(?:[A-Z][a-z0-9]+){2,}$', name):
        return 'PascalCase'
    if re.match(r'^[a-z0-9]+(?:_[a-z0-9]+)+$', name):
        return 'snake_case'
    if re.match(r'^[a-z]+(?:[A-Z][a-z0-9]*)+$', name):
        return 'camelCase'
    if re.match(r'^[a-z0-9]+(?: [a-z0-9]+)+$', name):
        return 'lower case'
    if re.match(r'^[a-z0-9]+(?:[:.\-][a-z0-9_]+)+$', name):
        return 'namespaced'
    return 'single word'


# ---------------------------------------------------------------- properties
def split_top(body):
    parts, depth, start, k = [], 0, 0, 0
    while k < len(body):
        ch = body[k]
        if ch in '"\'`':
            k = skip_str(body, k); continue
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        elif ch == ',' and depth == 0:
            parts.append(body[start:k]); start = k + 1
        k += 1
    parts.append(body[start:])
    return [p for p in parts if p.strip()]


def vtype(v):
    v = v.strip()
    if re.match(r'^[\'"`]', v) and not v.startswith('`') or re.match(r'^`[^$]*`$', v) or re.match(r'^String\(', v) or re.match(r'^`', v):
        return 'string'
    if re.match(r'^-?\d[\d_.]*$', v) or re.match(r'^(?:Number|parseInt|parseFloat|Math\.\w+)\(', v):
        return 'number'
    if v in ('true', 'false', 'True', 'False') or v.startswith('!'):
        return 'boolean'
    if v.startswith('['):
        return 'array'
    if v.startswith('{'):
        return 'object'
    return 'expr'


def props_at(s, i):
    """The literal object starting at s[i] (after optional whitespace): {key: type}, or None."""
    while i < len(s) and s[i] in ' \t\n':
        i += 1
    if i >= len(s) or s[i] != '{':
        return None
    body = s[i + 1:close_of(s, i) - 1]
    out = {}
    for part in split_top(body):
        part = part.strip()
        if part.startswith('...'):
            out['...' + part[3:].strip()[:20]] = 'spread'; continue
        kv = re.match(r'[\'"]?([\w$-]+)[\'"]?\s*:\s*([\s\S]*)$', part)
        if kv:
            out[kv.group(1)] = vtype(kv.group(2))
        elif re.match(r'^[\w$]+$', part):
            out[part] = 'expr'
    return out


def keyed_props(s, start, end):
    """The `properties:` value of an object-form call (`posthog.capture({ distinctId, event, properties: {…} })`,
    Segment's `track({ userId, event, properties })`, Ruby `track(event:, properties: {…})`): {key: type}; an
    identifier is an unread spread (never a missing-property row); no key at all is None (no properties)."""
    ob = s.find('{', start, end)
    lim = close_of(s, ob) if ob >= 0 else min(len(s), end + 400)
    lo = ob + 1 if ob >= 0 else start
    depth, k = 0, lo
    while k < lim:
        ch = s[k]
        if ch in '"\'`':
            k = skip_str(s, k); continue
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            if depth == 0:
                break
            depth -= 1
        elif depth == 0:
            mm = re.match(r'(?<![\w$])(?:properties|props|traits)\s*:\s*', s[k:k + 40]) if (k == lo or not re.match(r'[\w$]', s[k - 1])) else None
            if mm:
                v = k + mm.end()
                if s[v:v + 1] == '{':
                    return props_at(s, v)
                ident = re.match(r'[\w$.]+', s[v:])
                return {'...' + (ident.group(0)[:20] if ident else 'expr'): 'spread'}
        k += 1
    return None


# ---------------------------------------------------------------- firing context
def frames_at(s, positions):
    """For each position, the stack of enclosing brackets as (char, text before it)."""
    res, stack, i, n = {}, [], 0, len(s)
    want = sorted(set(positions)); w = 0
    while i < n and w < len(want):
        while w < len(want) and want[w] <= i:
            res[want[w]] = list(stack); w += 1
        c = s[i]
        if c in '"\'`':
            j = skip_str(s, i)
            while w < len(want) and want[w] < j:
                res[want[w]] = list(stack); w += 1
            i = j; continue
        if c in '({[':
            stack.append((c, s[max(0, i - 60):i], i))
        elif c in ')}]' and stack:
            stack.pop()
        i += 1
    while w < len(want):
        res[want[w]] = list(stack); w += 1
    return res


def context(f, pos, frames):
    s = f.code
    ctx, fn_start = 'top-level', None
    for ch, before, at in reversed(frames):
        b = before.rstrip()
        if re.search(r'\bon(?:Success|Settled|Completed)\s*:\s*(?:async\s*)?(?:\([^()]*\)|\w+)?\s*=?>?\s*$|\.then\s*$|\bonSuccess\s*\($', b):
            ctx = 'on-success'; break
        if re.search(r'\bcatch\s*(?:\(\s*[\w{}, ]*\s*\))?\s*$|\.catch\s*$|\bonError\s*:\s*(?:\([^()]*\)|\w+)?\s*=?>?\s*$|\bexcept\b[^\n]*:\s*$', b):
            ctx = 'on-failure'; break
        if re.search(r'\buse(?:Layout)?Effect\s*$', b) and ch == '(':
            e = close_of(s, at)
            dm = re.search(r',\s*\[([^\]]*)\]\s*\)$', s[at:e])
            ctx = 'effect(deps=[%s])' % dm.group(1).strip() if dm else 'effect(no-deps)'
            break
        if re.search(r'\bon(?:Click|Submit|Press|Select|Tap|Change)\s*=\s*$|@click\s*=\s*"?$|onPressed\s*:\s*$', b):
            ctx = 'on-intent'; break
    # the enclosing function: the innermost '{' frame preceded by a function header
    for ch, before, at in reversed(frames):
        if ch == '{' and re.search(r'=>\s*$|\)\s*(?::\s*[^{}()]+)?\s*$|\bfunction\b[^{]*$', before):
            fn_start = at; break
    if f.lang == 'py':
        ls = s.rfind('\n', 0, pos)
        ind = len(s[ls + 1:pos]) - len(s[ls + 1:pos].lstrip())
        for m in re.finditer(r'^([ \t]*)(?:async\s+)?def\s+\w+', s[:pos], re.M):
            if len(m.group(1)) < ind:
                fn_start = m.start()
    if ctx in ('top-level', 'on-intent') and fn_start is not None:
        body_before = s[fn_start:pos]
        aw = list(re.finditer(r'\bawait\s+([\w$.]+(?:\([^()]{0,40})?)', body_before))
        if aw:
            return ctx if ctx == 'on-intent' and False else 'after-await(%s)' % aw[-1].group(1).split('(')[0]
        end = close_of(s, fn_start) if f.lang != 'py' else min(len(s), pos + 1500)
        if re.search(r'\bawait\s+', s[pos:end]):
            return 'before-await'
    return ctx


# ---------------------------------------------------------------- plans
def yaml_load(text):
    """A YAML subset: block maps and lists, scalars, flow lists/maps of scalars. Enough for tracking plans."""
    lines = []
    for raw in text.split('\n'):
        t = re.sub(r'(^|\s)#.*$', '', raw).rstrip()
        if t.strip() and not t.strip().startswith(('---', '...')):
            lines.append((len(t) - len(t.lstrip(' ')), t.strip()))

    def scalar(v):
        v = v.strip()
        if v.startswith('[') and v.endswith(']'):
            return [scalar(x) for x in v[1:-1].split(',') if x.strip()]
        if v.startswith('{') and v.endswith('}'):
            d = {}
            for x in v[1:-1].split(','):
                if ':' in x:
                    k, vv = x.split(':', 1); d[k.strip().strip('\'"')] = scalar(vv)
            return d
        if len(v) >= 2 and v[0] == v[-1] and v[0] in '\'"':
            return v[1:-1]
        if v in ('true', 'false'):
            return v == 'true'
        if re.match(r'^-?\d+(\.\d+)?$', v):
            return float(v) if '.' in v else int(v)
        return None if v in ('', '~', 'null') else v

    def block(i, ind):
        if i >= len(lines):
            return None, i
        if lines[i][1].startswith('- ') or lines[i][1] == '-':
            out = []
            while i < len(lines) and lines[i][0] == ind and (lines[i][1].startswith('- ') or lines[i][1] == '-'):
                rest = lines[i][1][1:].strip()
                if not rest:
                    v, i = block(i + 1, lines[i + 1][0]) if i + 1 < len(lines) else (None, i + 1); out.append(v); continue
                if re.match(r'^[\w$"\' .-]+:\s', rest + ' ') and not rest.startswith(('"', "'")) or re.match(r'^["\'][^"\']+["\']\s*:', rest):
                    lines[i] = (ind + 2, rest)
                    v, i = block(i, ind + 2); out.append(v); continue
                out.append(scalar(rest)); i += 1
            return out, i
        out = {}
        while i < len(lines) and lines[i][0] == ind and not lines[i][1].startswith('- '):
            m = re.match(r'^(["\']?)([^"\':]+)\1\s*:(?:\s+(.*))?$', lines[i][1])
            if not m:
                i += 1; continue
            k, v = m.group(2).strip(), m.group(3)
            if v not in (None, '') and v not in ('|', '>'):
                out[k] = scalar(v); i += 1
            elif i + 1 < len(lines) and (lines[i + 1][0] > ind or lines[i + 1][1].startswith('- ') and lines[i + 1][0] == ind):
                out[k], i = block(i + 1, lines[i + 1][0])
            else:
                out[k] = None; i += 1
        return out, i
    v, _ = block(0, lines[0][0]) if lines else (None, 0)
    return v


def plan_props(spec):
    """(props {name: type|None}, required set) from an event spec in any of the common shapes."""
    props, req = {}, set()
    if not isinstance(spec, dict):
        return props, req
    for k in ('required',):
        if isinstance(spec.get(k), list):
            req |= set(str(x) for x in spec[k])
    pr = None
    for k in ('properties', 'props', 'attributes', 'parameters', 'params'):
        if k in spec:
            pr = spec[k]; break
    if pr is None and isinstance(spec.get('rules'), dict):
        return plan_props(spec['rules'])
    schema_keys = {'properties', 'required', 'type', 'additionalProperties', '$schema', 'description', 'title', 'id', '$id', 'definitions'}
    if isinstance(pr, dict) and isinstance(pr.get('properties'), dict) and set(pr) <= schema_keys:
        sub, sreq = plan_props(pr)               # a JSON Schema node (Segment Protocols, Iglu): one level down
        return sub, req | sreq
    if isinstance(pr, dict):
        for k, v in pr.items():
            t = v.get('type') if isinstance(v, dict) else (v if isinstance(v, str) else None)
            props[k] = t if not isinstance(t, list) else '|'.join(str(x) for x in t)
            if isinstance(v, dict) and v.get('required') is True:
                req.add(k)
    elif isinstance(pr, list):
        for v in pr:
            if isinstance(v, dict) and (v.get('name') or v.get('key')):
                nm = str(v.get('name') or v.get('key'))
                props[nm] = v.get('type')
                if v.get('required') is True or v.get('presence') == 'required':
                    req.add(nm)
            elif isinstance(v, str):
                props[v] = None
    return props, req


def events_from(tree):
    out = {}

    def add(name, spec):
        if isinstance(name, str) and name.strip():
            out[name.strip()] = plan_props(spec)

    def walk_t(t, depth=0):
        if depth > 6:
            return
        if isinstance(t, dict):
            for key in ('events', 'tracks', 'event_types', 'eventTypes'):
                v = t.get(key)
                if isinstance(v, dict):
                    for k, spec in v.items():
                        add(spec.get('name', k) if isinstance(spec, dict) and isinstance(spec.get('name'), str) else k, spec)
                elif isinstance(v, list):
                    for spec in v:
                        if isinstance(spec, str):
                            add(spec, None)
                        elif isinstance(spec, dict):
                            add(spec.get('name') or spec.get('event') or spec.get('key') or spec.get('event_type'), spec)
            if isinstance(t.get('self'), dict) and t['self'].get('format') == 'jsonschema':
                add(t['self'].get('name'), t)
            for k, v in t.items():
                if k not in ('events', 'tracks', 'event_types', 'eventTypes', 'properties'):
                    walk_t(v, depth + 1)
        elif isinstance(t, list) and depth == 0:
            for spec in t:
                if isinstance(spec, dict) and (spec.get('name') or spec.get('event')):
                    add(spec.get('name') or spec.get('event'), spec)
    walk_t(tree)
    return out


def read_plan(path, ledger):
    try:
        with open(path, encoding='utf-8', errors='replace') as fh:
            text = fh.read()
    except OSError as e:
        ledger.setdefault('plan errors', []).append('%s (%s)' % (path, e.strerror)); return {}
    ext = os.path.splitext(path)[1].lower()
    try:
        if os.path.basename(path) in ('ampli.json', 'avo.json'):
            return {}
        if ext == '.json':
            return events_from(json.loads(text))
        if ext in ('.yml', '.yaml'):
            return events_from(yaml_load(text))
        if ext == '.md':
            ev = {}
            for m in re.finditer(r'^\|\s*`?([A-Za-z][\w :.\-/]*?)`?\s*\|([^\n]*)$', text, re.M):
                nm = m.group(1).strip()
                if nm.lower() in ('event', 'name', 'event name') or set(nm) <= set('-: '):
                    continue
                props = {p: None for p in re.findall(r'`([\w$-]+)`', m.group(2))}
                ev[nm] = (props, set())
            for m in re.finditer(r'^\s*[-*]\s+`([A-Za-z][\w :.\-/]*)`', text, re.M):
                ev.setdefault(m.group(1).strip(), ({}, set()))
            return ev
        if ext == '.ts':
            return {x: ({}, set()) for x in union_names(text)}
    except (ValueError, IndexError, AttributeError, TypeError) as e:
        ledger.setdefault('plan errors', []).append('%s (parse: %s)' % (path, e))
    return {}


def union_names(text, alias=None):
    names = set()
    pat = r'type\s+(%s)\s*=\s*([^;]+)' % (re.escape(alias) if alias else r'\w*[Ee]vent\w*')
    for m in re.finditer(pat, text):
        names |= set(re.findall(r'[\'"]([^\'"]+)[\'"]', m.group(2)))
    pat = r'enum\s+(%s)\s*\{([^}]*)\}' % (re.escape(alias) if alias else r'\w*[Ee]vent\w*')
    for m in re.finditer(pat, text):
        names |= set(re.findall(r'=\s*[\'"]([^\'"]+)[\'"]', m.group(2)))
    return names


def read_codegen(path):
    try:
        text = open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return {}
    ev = {}
    for m in re.finditer(r'class\s+(\w+)\s+implements\s+BaseEvent\s*\{[\s\S]{0,200}?event_type\s*=\s*[\'"]([^\'"]+)', text):
        ev[m.group(2)] = ({}, set(), m.group(1)[0].lower() + m.group(1)[1:])
    if not ev:
        for m in re.finditer(r'export\s+function\s+([a-z]\w*)\s*\(', text):
            if m.group(1) not in CODEGEN_SKIP and not m.group(1).startswith(('_', 'set', 'init')):
                ev[m.group(1)] = ({}, set(), m.group(1))
    return ev


# ---------------------------------------------------------------- inventory
class Site(object):
    __slots__ = ('name', 'lane', 'file', 'line', 'props', 'ctx', 'side', 'dedupe', 'pos')

    def __init__(self, name, lane, f, pos, props):
        self.name, self.lane, self.file, self.line, self.props, self.pos = name, lane, f.rel, f.line(pos), props, pos
        self.ctx, self.dedupe = '', False
        self.side = 'server' if re.search(r'(?:^|/)(?:api|server|backend|worker|workers|functions|services?|lambda|jobs)(?:/|$)', f.rel) and \
            not re.search(r'(?:^|/)(?:web|client|frontend|app/src|components|pages|screens|hooks)(?:/|$)', f.rel) else 'client'


def find_wrappers(files, extra):
    """A wrapper = a function or property whose own parameter is forwarded as the event name to an SDK call."""
    wr = {}
    sdk_var = re.compile(r'(?:(?:' + SDK + r')(?:\.\w+)?\s*\.\s*(?:track|capture|logEvent|trackEvent|event)|gtag\s*\(\s*[\'"]event[\'"]\s*,|fbq\s*\(\s*[\'"](?:track|trackCustom)[\'"]\s*,|'
                         r'logEvent\s*\(\s*\w+\s*,|plausible|\bevent\s*:|\bevent_name\s*:|\bevent_type\s*=)\s*\(?\s*([A-Za-z_$][\w$]*)\b(?!\s*[\'"(.])')
    for f in files:
        s = f.code
        for m in sdk_var.finditer(s):
            var = m.group(1)
            if var in ('true', 'false', 'null', 'undefined', 'this'):
                continue
            head, name, first = None, None, None
            heads = list(re.finditer(r'(?:(?:const|let|var)\s+([\w$]+)\s*(?::[^=\n]+)?=\s*(?:useCallback\s*\(\s*)?(?:async\s*)?\(([^()]*)\)\s*(?::[^=]+?)?=>|'
                                     r'function\s+([\w$]+)\s*(?:<[^>]*>)?\(([^()]*)\)|^[ \t]*(?:public\s+|private\s+|async\s+)*([\w$]+)\s*\(([^()]*)\)\s*(?::[^{]+)?\{|'
                                     r'def\s+(\w+)\s*\(([^()]*)\))', s[max(0, m.start() - 6000):m.start()], re.M))
            off = max(0, m.start() - 6000)
            for h in reversed(heads[-12:]):
                nm = h.group(1) or h.group(3) or h.group(5) or h.group(7)
                if nm in ('if', 'for', 'while', 'switch', 'catch', 'return', 'useEffect', 'useMemo'):
                    continue
                params = h.group(2) or h.group(4) or h.group(6) or h.group(8) or ''
                plist = [x.strip() for x in params.split(',') if x.strip() and not re.match(r'^(?:self|cls)$', x.strip())]
                if plist and re.match(r'^' + re.escape(var) + r'\b', plist[0]):
                    head, name, first = h, nm, plist
                    break
            if not head:
                continue
            head_pos = off + head.start()
            tm = re.match(r'^[\w$]+\s*\??\s*:\s*([^=]+)', first[0])
            typ = tm.group(1).strip() if tm else ''
            wr.setdefault(name, {'site': '%s:%d' % (f.rel, f.line(head_pos)), 'type': typ, 'dedupe': False, 'file': f.rel})
            body = s[head_pos:min(len(s), m.end() + 1500)]
            if re.search(r'event_?id|eventID|insert_?id|messageId|dedup', body, re.I):
                wr[name]['dedupe'] = True
    # interface / context signatures: `trackEvent: (eventName: string, ...) => void`
    for f in files:
        for m in re.finditer(r'\b([\w$]+)\s*:\s*\(\s*(\w+)\s*:\s*([^,)]+)[^)]*\)\s*=>\s*(?:void|Promise)', f.code):
            if m.group(1) in wr and not wr[m.group(1)]['type']:
                wr[m.group(1)]['type'] = m.group(3).strip()
    for x in extra:
        wr.setdefault(x, {'site': '--wrapper', 'type': '', 'dedupe': False, 'file': ''})
    return wr


def run(roots, opts, emit=True):
    t0, ledger = time.time(), {}
    files, plan_files, gen_files = walk(roots, opts['tests'], ledger)
    shipped = [f for f in files if not NOT_SHIPPED.search(f.rel)]
    wrappers = find_wrappers(shipped, opts['wrappers'])
    generic = {'track', 'log', 'capture', 'event', 'send', 'emit', 'record'}
    sites, unresolved = [], []
    for f in shipped:
        s = f.code
        found = []
        for lane, rx in LANES:
            if lane == 'py' and f.lang != 'py' or lane == 'ruby' and f.lang != 'rb' or lane == 'go' and f.lang != 'go':
                continue
            for m in rx.finditer(s):
                nm = m.group(m.lastindex)
                if lane == 'snowplow':
                    nm = 'iglu:' + nm
                if '${' in nm:
                    unresolved.append(('UNRESOLVED', '%s:%d' % (f.rel, f.line(m.start())), lane, nm[:60])); continue
                if AUTO_EVENT.match(nm):
                    continue                          # PP-AN-1: tag-manager bootstrap and auto-tracked events are not plan events
                end = m.end()
                if lane in ('object', 'ruby'):
                    props = keyed_props(s, m.start(), end)
                else:
                    props = props_at(s, s.find(',', end) + 1) if s[end:end + 40].lstrip().startswith(',') else None
                found.append((m.start(), nm, lane, props))
        for m in CODEGEN_CALL.finditer(s):
            if m.group(2) not in CODEGEN_SKIP:
                found.append((m.start(), m.group(2), 'codegen-' + m.group(1).lower(), props_at(s, m.end())))
        for w, info in wrappers.items():
            if f.rel == info['file'] and False:
                continue
            rx = re.compile(r'(?<![\w$])(?:[\w$]+\??\.)?' + re.escape(w) + r'\s*\??\.?\s*\(\s*')
            for m in rx.finditer(s):
                t = s[m.end():m.end() + 1]
                line_start = s.rfind('\n', 0, m.start()) + 1
                if re.search(r'\b(?:function|def|const|let|var)\s+[\w$]*$|:\s*$', s[line_start:m.start()]) and re.search(r'\)\s*(?::[^=]*)?=>|\)\s*\{|\):', s[m.end():m.end() + 200].split('\n')[0]):
                    continue                            # the definition itself
                if t in '\'"`':
                    e = skip_str(s, m.end())
                    nm = s[m.end() + 1:e - 1]
                    if '${' in nm:
                        unresolved.append(('UNRESOLVED', '%s:%d' % (f.rel, f.line(m.start())), 'wrapper:' + w, nm[:60])); continue
                    if w in generic and not re.match(r'^[A-Za-z][\w :.\-/]{2,}$', nm):
                        continue
                    rest = s[e:e + 40].lstrip()
                    found.append((m.start(), nm, 'wrapper:' + w, props_at(s, s.find(',', e) + 1) if rest.startswith(',') else None))
                elif re.match(r'[A-Za-z_$]', t) and w not in generic:
                    arg = re.match(r'[\w$.]+', s[m.end():]).group(0)
                    if arg not in ('eventName', 'name', 'event') or f.rel != info['file']:
                        unresolved.append(('UNRESOLVED', '%s:%d' % (f.rel, f.line(m.start())), 'wrapper:' + w, arg[:60]))
        if not found:
            continue
        seen = set()
        fr = frames_at(s, [p for p, _, _, _ in found])
        for pos, nm, lane, props in sorted(found):
            key = (pos // 1, nm)
            if any(abs(pos - p0) < 3 and nm == n0 for p0, n0 in seen):
                continue
            seen.add((pos, nm))
            st = Site(nm, lane, f, pos, props)
            st.ctx = context(f, pos, fr.get(pos, []))
            st.dedupe = bool(props and any(re.search(r'event_?id|eventID|insert_?id|messageId', k, re.I) for k in props))
            if lane.startswith('wrapper:') and wrappers.get(lane[8:], {}).get('dedupe'):
                st.dedupe = True
            sites.append(st)
    # drop SDK sites that sit inside a wrapper body and forward a constant (rare) - keep; drop wrapper-internal dynamic calls
    # ---- plan
    plan, sources = {}, []
    codegen = {}
    for p in opts['plans'] or []:
        ev = read_plan(p, ledger); sources.append('%s (%d events)' % (p, len(ev)))
        plan.update(ev)
    if not opts['plans']:
        for p in plan_files:
            ev = read_plan(p, ledger)
            if ev:
                sources.append('%s (%d events)' % (os.path.relpath(p, roots[0]) if len(roots) == 1 else p, len(ev))); plan.update(ev)
        for p in gen_files:
            ev = read_codegen(p)
            if ev:
                codegen.update(ev)
                sources.append('%s (codegen, %d events)' % (os.path.relpath(p, roots[0]) if len(roots) == 1 else p, len(ev)))
                for nm, (pr, rq, fn) in ev.items():
                    plan.setdefault(nm, (pr, rq))
        for w, info in wrappers.items():
            typ = info['type']
            if typ and typ not in ('string', 'str', 'String') and re.match(r'^[A-Z]\w*$', typ):
                for f in files:
                    names = union_names(f.code, typ)
                    if names:
                        sources.append('%s (typed union %s, %d names)' % (f.rel, typ, len(names)))
                        for nm in names:
                            plan.setdefault(nm, ({}, set()))
                        break
    # codegen call names -> event names
    fn2ev = {v[2]: k for k, v in codegen.items()}
    for st in sites:
        if st.lane.startswith('codegen-') and st.name in fn2ev:
            st.name = fn2ev[st.name]
    success = {}
    sdir = opts['success'] or (os.path.join(roots[0], 'ai', 'product', 'success') if roots else None)
    if sdir and os.path.isdir(sdir):
        for nm in sorted(os.listdir(sdir)):
            if nm.endswith('.md'):
                text = open(os.path.join(sdir, nm), encoding='utf-8', errors='replace').read()
                m = re.search(r'^#+\s*(?:Instrumentation|Events|Tracking)\b[^\n]*\n([\s\S]*?)(?=^#+\s|\Z)', text, re.M | re.I)
                if m:
                    for ev in re.findall(r'`([A-Za-z][\w :.\-/]{2,})`', m.group(1)):
                        success.setdefault(ev, nm)
    have_plan = bool(plan)
    rows = []
    want = opts.get('classes', set('1234567'))
    code_names = {}
    for st in sites:
        code_names.setdefault(st.name, []).append(st)
    pk = {}
    for nm in plan:
        pk.setdefault(nkey(nm), []).append(nm)
    ck = {}
    for nm in code_names:
        ck.setdefault(nkey(nm), []).append(nm)
    # AN1
    if have_plan:
        for nm, ss in sorted(code_names.items()):
            if nm not in plan and nkey(nm) not in pk:
                rows.append(('AN1', 'unplanned', nm, '%s:%d' % (ss[0].file, ss[0].line), '%d site(s)' % len(ss), 'plan'))
    else:
        rows.append(('AN1', 'no-plan', '%d names' % len(code_names), '-', '%d site(s), %d unresolved' % (len(sites), len(unresolved)), 'hardening'))
    # AN2
    for nm in sorted(set(plan) | set(success)):
        if nm not in code_names and nkey(nm) not in ck:
            rows.append(('AN2', 'never-fired', nm, success.get(nm, '-'), 'metric=yes' if nm in success else 'metric=no',
                         'success' if nm in success and nm not in plan else 'plan'))
    # AN3
    allk = {}
    for nm in set(code_names) | set(plan):
        allk.setdefault(nkey(nm), set()).add(nm)
    for k, names in sorted(allk.items()):
        if len(names) > 1:
            ex = '; '.join('%s%s' % (n, '(plan)' if n in plan and n not in code_names else '') for n in sorted(names))
            site = next(('%s:%d' % (code_names[n][0].file, code_names[n][0].line) for n in sorted(names) if n in code_names), '-')
            rows.append(('AN3', 'spelling', ex, site, '%d spellings' % len(names), 'plan' if any(n in plan for n in names) else 'code'))
    if len(code_names) >= 5:
        styles = {}
        for nm in code_names:
            styles.setdefault(style(nm), []).append(nm)
        dom, members = max(styles.items(), key=lambda kv: len(kv[1]))
        if len(members) >= 0.6 * len(code_names) and dom != 'single word':
            for sty, names in sorted(styles.items()):
                if sty != dom and sty != 'single word':
                    for nm in sorted(names):
                        rows.append(('AN3', 'convention', nm, '%s:%d' % (code_names[nm][0].file, code_names[nm][0].line), '%s, dominant %s' % (sty, dom), 'code'))
    # AN4
    if have_plan:
        for nm, ss in sorted(code_names.items()):
            with_props = [s0 for s0 in ss if s0.props is not None]
            keysets = set(tuple(sorted(k for k in s0.props if not k.startswith('...'))) for s0 in with_props)
            if len(keysets) > 1:
                rows.append(('AN4', 'keys-differ', nm, '; '.join('%s:%d' % (s0.file, s0.line) for s0 in with_props[:4]),
                             ' | '.join(','.join(k) for k in sorted(keysets))[:120], 'code'))
            types = {}
            for s0 in with_props:
                for k, t in s0.props.items():
                    if t not in ('expr', 'spread'):
                        types.setdefault(k, set()).add(t)
            for k, ts in sorted(types.items()):
                if len(ts) > 1:
                    rows.append(('AN4', 'type-conflict', nm, '%s:%d' % (with_props[0].file, with_props[0].line), '%s: %s' % (k, '/'.join(sorted(ts))), 'code'))
            spec = plan.get(nm)
            if spec is None and nkey(nm) in pk:
                spec = plan.get(pk[nkey(nm)][0])
            if not spec:
                continue
            pprops, req = spec[0], spec[1]
            for s0 in ss:
                if s0.props is None:
                    if req:
                        rows.append(('AN4', 'required-missing', nm, '%s:%d' % (s0.file, s0.line), 'no properties; plan requires %s' % ','.join(sorted(req)), 'plan'))
                    continue
                if any(k.startswith('...') for k in s0.props):
                    continue
                miss = sorted(req - set(s0.props))
                if miss:
                    rows.append(('AN4', 'required-missing', nm, '%s:%d' % (s0.file, s0.line), ','.join(miss), 'plan'))
                if pprops:
                    extra = sorted(set(s0.props) - set(pprops))
                    if extra:
                        rows.append(('AN4', 'unplanned-property', nm, '%s:%d' % (s0.file, s0.line), ','.join(extra), 'plan'))
                    for k, t in s0.props.items():
                        pt = pprops.get(k)
                        if pt and t not in ('expr', 'spread') and not any(t == x or (t == 'number' and x in ('integer', 'int', 'float')) for x in re.split(r'[|, ]+', str(pt).lower())):
                            rows.append(('AN4', 'type-mismatch', nm, '%s:%d' % (s0.file, s0.line), '%s: %s, plan %s' % (k, t, pt), 'plan'))
    # AN5
    for st in sites:
        ws = [stem(w) for w in words(st.name)]
        raw = words(st.name)
        joined = ''.join(raw)
        is_outcome = any(w in OUTCOME for w in raw) or any(x in joined for x in ('signedup', 'checkoutcompleted', 'completeregistration', 'purchase'))
        is_intent = bool(raw) and raw[-1] in INTENT or any(w in INTENT for w in raw[-1:])
        if is_outcome and not is_intent:
            rows.append(('AN5', st.ctx or 'top-level', st.name, '%s:%d' % (st.file, st.line), st.lane, 'value' if st.props and 'value' in st.props else '-'))
    # AN6
    by_file = {}
    for st in sites:
        by_file.setdefault((st.file, st.name), []).append(st)
    for (fl, nm), ss in sorted(by_file.items()):
        if len(ss) > 1:
            rows.append(('AN6', 'multi-site', nm, fl + ':' + ','.join(str(s0.line) for s0 in ss), '%d sites' % len(ss), '-'))
    for st in sites:
        if st.ctx.startswith('effect('):
            deps = st.ctx[len('effect(deps=['):-2] if 'deps=' in st.ctx else None
            if deps is None:
                rows.append(('AN6', 'effect-no-deps', st.name, '%s:%d' % (st.file, st.line), 'fires on every render', '-'))
            elif re.search(r'\b(?:on[A-Z]\w*|\w*[Cc]allback|handle\w*|\w*Fn|options|config|props|data|user)\b', deps):
                rows.append(('AN6', 'effect-deps', st.name, '%s:%d' % (st.file, st.line), 'deps=[%s]' % deps[:60], '-'))
    for nm, ss in sorted(code_names.items()):
        sides = set(s0.side for s0 in ss)
        if len(sides) > 1:
            rows.append(('AN6', 'two-legs', nm, '; '.join('%s:%d' % (s0.file, s0.line) for s0 in ss[:3]),
                         'event_id=%s' % ('yes' if all(s0.dedupe for s0 in ss) else 'no'), '-'))
    # AN7
    for w, info in sorted(wrappers.items()):
        t = info['type']
        if not t or t in ('string', 'str', 'String', 'any', 'unknown'):
            n = sum(1 for st in sites if st.lane == 'wrapper:' + w)
            rows.append(('AN7', 'untyped-wrapper', w, info['site'], 'name: %s, %d call sites' % (t or 'untyped', n), 'hardening'))
    if codegen:
        for st in sites:
            if not st.lane.startswith('codegen-') and not st.lane.startswith('wrapper:'):
                rows.append(('AN7', 'bypasses-codegen', st.name, '%s:%d' % (st.file, st.line), st.lane, 'hardening'))
    elif wrappers:
        wfiles = set(i['file'] for i in wrappers.values())
        for st in sites:
            if not st.lane.startswith('wrapper:') and not st.lane.startswith('codegen-') and st.file not in wfiles:
                rows.append(('AN7', 'bypasses-wrapper', st.name, '%s:%d' % (st.file, st.line), st.lane, 'hardening'))
    rows = [r for r in rows if r[0][2] in want] + unresolved
    lanes = {}
    for st in sites:
        k = st.lane.split(':')[0]
        lanes[k] = lanes.get(k, 0) + 1
    ledger.update({'roots': ', '.join(roots), 'files read': len(files), 'sites': '%d (%s)' % (len(sites), ', '.join('%s %d' % kv for kv in sorted(lanes.items()))),
                   'names': len(code_names), 'unresolved': len(unresolved),
                   'wrappers': ', '.join('%s @ %s (name: %s%s)' % (w, i['site'], i['type'] or 'untyped', ', event id' if i['dedupe'] else '') for w, i in sorted(wrappers.items())) or 'none',
                   'plan': '; '.join(sources) if sources else 'none - §1 prints one no-plan row; §2 (plan half) and §4 are N/A (no plan - no oracle)',
                   'success events': '%d from %s' % (len(success), sdir) if success else 'none',
                   'runtime': '%.1fs' % (time.time() - t0)})
    inv = []
    if opts['inventory']:
        inv += [('SITE', st.name, '%s:%d' % (st.file, st.line), st.lane, st.ctx, st.side, ','.join('%s:%s' % kv for kv in sorted((st.props or {}).items())) or '-') for st in sites]
        inv += [('PLAN', nm, ','.join(sorted(v[0])) or '-', ','.join(sorted(v[1])) or '-') for nm, v in sorted(plan.items())]
        inv += [('WRAPPER', w, i['site'], i['type'] or 'untyped', 'event-id' if i['dedupe'] else '-') for w, i in sorted(wrappers.items())]
    if emit:
        emit_rows(rows, inv, ledger, opts)
    return rows, inv, ledger


HEAD = {'AN1': 'kind\tname\tsite\tdetail\tbasis', 'AN2': 'kind\tname\tsource\tmetric\tbasis', 'AN3': 'kind\tnames\tsite\tdetail\tbasis',
        'AN4': 'kind\tname\tsite\tdetail\tbasis', 'AN5': 'context\tname\tsite\tlane\tvalue', 'AN6': 'kind\tname\tsite\tdetail\t-',
        'AN7': 'kind\tname\tsite\tdetail\tbasis', 'UNRESOLVED': 'site\tlane\texpression',
        'SITE': 'name\tsite\tlane\tcontext\tside\tprops', 'PLAN': 'name\tproperties\trequired', 'WRAPPER': 'name\tsite\tname-type\tdedupe'}


def emit_rows(rows, inv, ledger, opts):
    if opts['json']:
        print(json.dumps({'rows': [list(r) for r in rows], 'inventory': [list(r) for r in inv], 'ledger': ledger}, indent=1))
    else:
        cur, shown = None, {}
        for r in inv + rows:
            if r[0] != cur:
                cur = r[0]; print('# %s\t%s' % (cur, HEAD.get(cur, '')))
            shown[cur] = shown.get(cur, 0) + 1
            if opts['max'] and shown[cur] > opts['max'] and cur not in ('SITE', 'PLAN', 'WRAPPER'):
                continue
            print('\t'.join(str(x) for x in r))
    counts = {}
    for r in rows:
        counts[r[0]] = counts.get(r[0], 0) + 1
    sys.stderr.write('event-inventory ledger\n')
    for k, v in ledger.items():
        for x in (v if isinstance(v, list) else [v]):
            sys.stderr.write('  %-15s %s\n' % (k, x))
    sys.stderr.write('  %-15s %s\n' % ('rows', ', '.join('%s %d' % kv for kv in sorted(counts.items())) or 'none'))


def oracle_rows(rows):
    return [r for r in rows if (r[0] == 'AN1' and r[1] == 'unplanned') or r[0] == 'AN2' or (r[0] == 'AN3' and r[1] == 'spelling' and r[5] == 'plan') or (r[0] == 'AN4')]


# ---------------------------------------------------------------- self-test
FIX = {
    'web/src/tracking/AnalyticsProvider.tsx':
        "export interface Ctx { trackEvent: (eventName: string, data?: Record<string, unknown>) => void }\n"
        "export function Provider() {\n"
        "  const trackEvent = useCallback((eventName: string, data?: Record<string, unknown>) => {\n"
        "    const eventId = generateEventId();\n"
        "    window.fbq('track', eventName, { ...data, eventID: eventId });\n"
        "    void sendCapiEvent({ event_name: eventName, event_id: eventId });\n"
        "  }, []);\n}\n",
    'web/src/wallet/use-wallet.ts':
        "export function useWallet() {\n  const { trackEvent } = useTracking();\n"
        "  const handlePurchase = async (id) => {\n    try {\n      const r = await purchase.mutateAsync({ id });\n"
        "      trackEvent('PackagePurchased', { package_id: id, value: 10, currency: 'USD' });\n"
        "      assign(r.paymentUrl);\n    } catch (e) {\n      trackEvent('PurchaseFailed', { reason: 'x' });\n    }\n  };\n}\n",
    'web/src/onboarding/Dialog.tsx':
        "export function Dialog({ open, onClose }) {\n  const { trackEvent } = useTracking();\n"
        "  useEffect(() => { if (open) trackEvent('OnboardingDialogShown', { content_name: 'x' }); }, [open, trackEvent]);\n"
        "  useEffect(() => { trackEvent('OnboardingDialogShown', { content_name: 'y' }); }, [onClose]);\n"
        "  return <button onClick={() => trackEvent('Signup Completed', { method: 'email' })}>Go</button>;\n}\n",
    'web/src/store/flows.ts':
        "export const a = (trackEvent) => trackEvent('StoreConnected', { store_type: 'manual', count: 2 });\n"
        "export const b = (trackEvent) => trackEvent('StoreConnected', { store_type: 'shopify', count: '2' });\n"
        "export const c = (trackEvent) => trackEvent('StoreConnectedFromOnboarding', { content_name: 'z' });\n"
        "export const d = (trackEvent) => trackEvent('store_connected', { store_type: 'x' });\n"
        "export const e = (trackEvent, ev) => trackEvent(ev, {});\n",
    'web/src/legacy/raw.ts': "posthog.capture('signup_completed', { plan: 'pro' });\ngtag('event', 'purchase', { value: 5 });\n",
    'api/src/stores/connect.service.ts': "export class C {\n  async done(u) {\n    await this.repo.save(u);\n    this.posthog.capture({ distinctId: u.id, event: 'StoreConnected', properties: { store_type: 'shopify' } });\n  }\n}\n",
    'api/src/billing/webhook.service.ts': "await this.repo.save(p);\nanalytics.track({ userId: u, event: 'PackagePurchased', properties: { value: 10 } });\n",
    'web/src/x.test.ts': "trackEvent('NeverCounted');\n",
    'ai/product/tracking-plan.yaml':
        "events:\n  PackagePurchased:\n    properties:\n      package_id: { type: string, required: true }\n      value: { type: number }\n"
        "      currency: { type: string }\n  StoreConnected:\n    properties:\n      store_type: { type: string, required: true }\n"
        "  Referral Sent:\n    properties: {}\n  OnboardingDialogShown: {}\n",
    'ai/product/success/referrals.md': "# Referrals\n## Instrumentation\n- `Referral Sent` (success metric)\n- `ReferralRedeemed` (counter-metric)\n",
}


def self_test():
    tmp = tempfile.mkdtemp(prefix='event-inventory-')
    fails = []
    try:
        for rel, body in FIX.items():
            p = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, 'w', encoding='utf-8') as fh:
                fh.write(body)
        opts = {'tests': False, 'plans': [], 'wrappers': [], 'success': None, 'inventory': True, 'max': 0, 'json': False, 'classes': set('1234567')}
        rows, inv, ledger = run([tmp], opts, emit=False)

        def has(*parts):
            return any(all(any(p == str(c) or (len(p) > 3 and p in str(c)) for c in r) for p in parts) for r in rows)

        def check(cond, what):
            if not cond:
                fails.append(what)
        check(any(r[0] == 'WRAPPER' and r[1] == 'trackEvent' and r[3] == 'string' and r[4] == 'event-id' for r in inv), 'wrapper discovered with its string type and event id')
        check(not any(r[0] == 'SITE' and r[1] == 'NeverCounted' for r in inv), 'tests skipped')
        check(has('AN1', 'unplanned', 'PurchaseFailed'), 'AN1 unplanned')
        check(not has('AN1', 'unplanned', 'PackagePurchased'), 'AN1 planned name is not unplanned')
        check(has('AN2', 'never-fired', 'Referral Sent', 'metric=yes'), 'AN2 success-metric event never fired')
        check(has('AN2', 'never-fired', 'ReferralRedeemed', 'metric=yes'), 'AN2 success event outside the plan')
        check(has('AN3', 'spelling', 'Signup Completed; signup_completed'), 'AN3 case/separator drift')
        check(has('AN3', 'spelling', 'StoreConnected; store_connected'), 'AN3 plan vs code spelling')
        check(not any(r[0] == 'AN3' and 'StoreConnectedFromOnboarding' in r[2] and 'spelling' == r[1] for r in rows), 'AN3 PP-AN-3 distinct event kept apart')
        check(has('AN4', 'type-conflict', 'StoreConnected', 'count: number/string'), 'AN4 literal type conflict')
        check(has('AN4', 'unplanned-property', 'StoreConnected', 'count'), 'AN4 property outside the plan')
        check(has('AN4', 'required-missing', 'PackagePurchased', 'package_id'), 'AN4 required property missing on the server leg')
        check(not any(r[0] == 'AN4' and r[1] == 'required-missing' and 'connect.service.ts' in r[3] for r in rows)
              and any(r[0] == 'SITE' and 'connect.service.ts' in r[2] and r[6] == 'store_type:string' for r in inv), 'AN4 object form reads its properties key (posthog-node capture({ event, properties }))')
        check(any(r[0] == 'AN5' and r[2] == 'PackagePurchased' and r[1] == 'after-await(purchase.mutateAsync)' and r[5] == 'value' for r in rows), 'AN5 purchase after the checkout-URL await')
        check(any(r[0] == 'AN5' and r[2] == 'Signup Completed' and r[1] == 'on-intent' for r in rows), 'AN5 outcome fired on click')
        check(not any(r[0] == 'AN5' and r[2] == 'PurchaseFailed' for r in rows) or any(r[0] == 'AN5' and r[2] == 'PurchaseFailed' and r[1] == 'on-failure' for r in rows), 'AN5 failure context')
        check(not any(r[0] == 'AN5' and r[2] == 'OnboardingDialogShown' for r in rows), 'AN5 intent/impression names skipped')
        check(has('AN6', 'effect-deps', 'OnboardingDialogShown', 'deps=[onClose]'), 'AN6 effect on an unstable callback')
        check(not any(r[0] == 'AN6' and r[1] == 'effect-deps' and 'open, trackEvent' in r[4] for r in rows), 'AN6 stable wrapper in deps is fine')
        check(has('AN6', 'two-legs', 'PackagePurchased'), 'AN6 client + server legs')
        check(has('AN7', 'untyped-wrapper', 'trackEvent'), 'AN7 untyped wrapper')
        check(has('AN7', 'bypasses-wrapper', 'signup_completed'), 'AN7 direct SDK call beside a wrapper')
        check(any(r[0] == 'UNRESOLVED' and 'flows.ts:5' in r[1] for r in rows), 'dynamic name is unresolved, never a mismatch')
        check(nkey('Signup Completed') == nkey('signup_completed') == nkey('SignUpComplete') or nkey('Signup Completed') == nkey('signup_completed'), 'nkey')
        y = yaml_load("events:\n  - name: A\n    properties:\n      - name: x\n        type: string\n        required: true\n  - B\n")
        check(events_from(y).get('A') == ({'x': 'string'}, {'x'}) and 'B' in events_from(y), 'yaml list plan')
        seg = {'rules': {'events': [{'name': 'Order Completed', 'rules': {'properties': {'properties': {'properties': {'total': {'type': ['number']}}, 'required': ['total']}}}}]}}
        check(events_from(seg).get('Order Completed') == ({'total': 'number'}, {'total'}), 'segment protocols export shape')
        no = run([tmp], dict(opts, plans=[os.path.join(tmp, 'web', 'src', 'x.test.ts')], success=os.path.join(tmp, 'none')), emit=False)[0]
        check(any(r[0] == 'AN1' and r[1] == 'no-plan' for r in no) and not any(r[0] == 'AN4' for r in no), 'no plan: one no-plan row, AN4 N/A')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for x in fails:
        sys.stderr.write('FAIL  %s\n' % x)
    sys.stderr.write('self-test: %d checks failed\n' % len(fails) if fails else 'self-test: all checks passed\n')
    return 3 if fails else 0


def main(argv):
    if '--self-test' in argv:
        return self_test()
    opts = {'tests': False, 'plans': [], 'wrappers': [], 'success': None, 'inventory': False, 'max': 0, 'json': False, 'classes': set('1234567')}
    roots = []
    for a in argv:
        if a == '--include-tests':
            opts['tests'] = True
        elif a == '--inventory':
            opts['inventory'] = True
        elif a == '--json':
            opts['json'] = True
        elif a.startswith('--plan='):
            opts['plans'].append(a.split('=', 1)[1])
        elif a.startswith('--wrapper='):
            opts['wrappers'] = [x.strip() for x in a.split('=', 1)[1].split(',') if x.strip()]
        elif a.startswith('--success='):
            opts['success'] = a.split('=', 1)[1]
        elif a.startswith('--classes='):
            opts['classes'] = set(re.findall(r'[1-7]', a.split('=', 1)[1]))
        elif a.startswith('--max='):
            opts['max'] = int(a.split('=', 1)[1] or 0)
        elif a in ('-h', '--help'):
            print(__doc__); return 0
        elif a.startswith('-'):
            sys.stderr.write('unknown option %s\n' % a); return 1
        else:
            roots.append(a)
    roots = roots or ['.']
    for r in roots + opts['plans']:
        if not os.path.exists(r):
            sys.stderr.write('not found: %s\n' % r); return 1
    rows, _, _ = run(roots, opts)
    return 2 if oracle_rows(rows) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
