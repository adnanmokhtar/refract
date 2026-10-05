#!/usr/bin/env python3
"""risk-tier.py — the risk tier of a change, computed from what it says and what it touches; it only PROMOTES.

Usage:  risk-tier.py [--request="<text>" | --request-file=<p>]
                     [--files=a,b | --files-from=<design.md or any text>] [--diff [--base=<ref>]]
                     [--risk-map=<path>] [--graph=<path>] [--run=<run_id> [--write]]
                     [--force-lower=<T0|T1|T2> --reason="<why>"] [--ci] [--json] [--repo=<dir>]
        risk-tier.py --self-test
Exit:   0 ok · 1 usage or environment error (or run.json would not validate) · 2 refused demotion
        (--force-lower after P0) · 3 UNDER-TIERED (--ci: the diff scores above a run's recorded tier)

WHY. The tier decides how much ceremony a change gets (.claude/templates/governance/tiers.json): T3
adds a threat model, holdouts, mutation and three human gates. A model asked "how risky is this?"
answers from the framing of the ask, and a refund button framed as "just a button" is the
under-tiered T3 the whole matrix exists to catch. So the tier is computed from three inputs a
script can read — the request text, the predicted or actual file set mapped through
ai/risk-map.json, and the caller count of each touched file in .claude/_graph.json — and the
highest signal wins.

ONLY PROMOTES. With --run, the result is max(recorded, computed): a re-tier after design (predicted
files) or after P6 (the diff) can raise a run's tier, never lower it. A promotion lists the phases
the new tier requires that the run already passed without running (`backfill`). A user may force a
LOWER tier at P0 only (--force-lower, logged in run.json.forced_lower with the reason); after P0 it
is refused. A forced-lower run is promoted again only by a signal above the tier the human saw
(forced_lower.computed) — the human already overruled everything up to it. CI (--ci) re-tiers
from the diff and exits 3 when a run in the diff is under-tiered (G15 input).

SOURCES (run.schema.json tier_reasons[].source): request (the ask) · design (--files /
--files-from: the predicted set) · diff (the change) · risk-map (a path matched a rule) · graph
(caller count) · user (forced lower). A path signal names the input it came from in `detail`.

DERIVED TRIGGERS — three tiers.json triggers have no word lexicon, by design:
  blast-radius                  graph only: distinct importers of a touched file in .claude/_graph.json
                                ≥ blast_radius.callers_t3 → T3, ≥ callers_t2 → T2.
  new-dependency-on-write-path  combination: a dependency manifest is touched (the diff adds a
                                dependency line, or a predicted file set names a manifest) AND some
                                OTHER touched path is itself a T3 hit or a T2 `write-path` hit.
                                Request text alone never fires it — the words name a library, not
                                where it is called.
  cross-module                  has a small lexicon AND is path-derived: touched source files under
                                three or more module roots (first directory below src/, app/, lib/,
                                packages/<pkg>/, …; tests, docs, ai/ and .claude/ do not count).
                                Three, not two: one feature split by layer already spans two.

HONEST LIMITS:
  * Words are evidence of intent, not of risk: "fix the typo on the login page" scores T3
    (auth-roles). Over-tiering is the safe error; the user may force lower at P0 with a reason.
  * Negation is three words deep: a match is ignored when without / no / not / never / don't sits
    within the three words before it ("no new endpoint", "without changing the response shape").
    "the endpoint is not new" still counts. Over-counting is the safe direction.
  * The risk map is JSON (D1). A lone ai/risk-map.yaml is reported and NOT parsed — a hand-rolled
    YAML subset fails silently. With no risk map, path rules are off and the output says so.
  * Migration content is read with regexes for SQL and the common migration DSLs (Rails, Django,
    Laravel, Knex, Alembic, TypeORM). A migration expressed some other way is a T2 candidate by
    path only.
  * The graph is a cache and may be stale or absent; no graph means no blast-radius signal, and
    the output says the graph was not read.
"""
import datetime
import json
import os
import re
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
try:
    import refract_records as rr
except ImportError:
    rr = None

ORDER = ["T0", "T1", "T2", "T3"]
EXCLUDED = ("ai/runs/", ".claude/evidence/", ".claude/locks/")

# Write-path verbs do not count when their object is documentation ("update the README").
_DOCOBJ = r"(?!(?:\s+[\w'-]+){0,2}\s+(?:readme|docs?|documentation|changelog|comments?|wording|copy|typos?|label text|docstrings?)\b)"

# ── the lexicon: one entry per tiers.json trigger (keys MUST be trigger names — --self-test checks) ──
LEXICON = {
    # T3 ─────────────────────────────────────────────────────────────────────────────────────────
    # money-movement: anything that moves, holds or charges money.
    "money-movement": ("T3", [
        r"\brefund(s|ed|ing)?\b", r"\bcharg(e|es|ed|ing)\b", r"\bpayments?\b", r"\bpay-?outs?\b",
        r"\bcheckout\b", r"\bbilling\b", r"\binvoice payments?\b", r"\btransfer(ring)? (funds|money)\b",
        r"\bwallets?\b", r"\bbalances?\b", r"\bcapture (the )?(payment|funds|charge)s?\b",
        r"\bcredit cards?\b", r"\bsubscription (charge|billing|renewal|payment)s?\b", r"\bpayable\b",
        r"\bstripe\b", r"\bpaypal\b", r"\bpayroll\b"]),
    # auth-roles: who you are and what you may do.
    "auth-roles": ("T3", [
        r"\blog ?in\b", r"\bsign[- ]?(in|up)\b", r"\bpasswords?\b", r"\bauth(entication|orization|n|z)?\b",
        r"\bpermissions?\b", r"\broles?\b", r"\brbac\b", r"\badmins? can\b", r"\bsso\b", r"\boauth2?\b",
        r"\b(2fa|mfa|two[- ]factor)\b", r"\bsessions?\b", r"\bimpersonat\w*", r"\baccess control\b",
        r"\bapi keys?\b", r"\b(access|refresh|auth|bearer) tokens?\b"]),
    # pii: data that identifies a person.
    "pii": ("T3", [
        r"\bpii\b", r"\bpersonal (data|information)\b", r"\bemail address(es)?\b", r"\bphone numbers?\b",
        r"\bdate of birth\b", r"\bssn\b", r"\bsocial security\b", r"\bnational id\b", r"\baddress book\b",
        r"\bgdpr\b", r"\bexport (the |all )?(user|customer|my|personal) data\b",
        r"\bdelete (my|the|a|user|customer)( \w+)? account\b", r"\b(home|postal|billing|shipping) address(es)?\b",
        r"\bpassports?\b", r"\b(health|medical) records?\b"]),
    # tenant-isolation: one customer's data must never reach another.
    "tenant-isolation": ("T3", [
        r"\b(multi|cross)[- ]?tenan\w*", r"\btenants?\b", r"\btenancy\b",
        r"\b(organi[sz]ation|workspace|account) isolation\b", r"\brow[- ]level security\b"]),
    # migration-populated-table: a schema change on a table that already holds rows.
    "migration-populated-table": ("T3", [
        r"\b(alter|drop|rename) (a |the )?(\w+ )?(column|table)s?\b", r"\bbackfill\w*",
        r"\bchange (the )?column types?\b", r"\bcolumn type change\b",
        r"\bschema change (on|to) (an? |the )?existing table\b",
        r"\bmigrat(e|ion|ions) (on|of) (an? |the )?(existing|populated|production|live) \w+",
        r"\bdata migration\b", r"\badd (an? |the )?([\w-]+ )?column (to|on) (the )?\w+"]),
    # infra-ci: build, deploy and infrastructure definitions.
    "infra-ci": ("T3", [
        r"\bci\b", r"\bpipelines?\b", r"\bgithub actions?\b", r"\bworkflow files?\b",
        r"\bdeploy(ment)? (config|configuration|script|manifest)s?\b", r"\bterraform\b", r"\bk8s\b",
        r"\bkubernetes\b", r"\bhelm\b", r"\bdockerfile\b", r"\bdocker[- ]compose\b", r"\binfrastructure\b",
        r"\binfra\b", r"\bgitlab[- ]ci\b", r"\bcloudformation\b", r"\bpulumi\b", r"\bansible\b"]),
    # crypto: keys, signatures, ciphers.
    "crypto": ("T3", [
        r"\bencrypt\w*", r"\bdecrypt\w*", r"\bhash(ing)? (the )?passwords?\b", r"\bpassword hash\w*",
        r"\bsigning\b", r"\b(digital|hmac|request|webhook) signatures?\b", r"\bkey rotation\b",
        r"\brotate (the )?(\w+ )?keys?\b", r"\bcertificates?\b", r"\btls\b", r"\bssl\b", r"\bjwt\b",
        r"\bhmac\b", r"\bkms\b", r"\bcryptograph\w*"]),
    # breaking-api: a public contract changes shape under its callers.
    "breaking-api": ("T3", [
        r"\bbreaking (api )?changes?\b", r"\bremov(e|ing) (the |an? )?(\w+ )?(endpoint|route|api)s?\b",
        r"\brename (a |the )?(\w+ )?field (in|on|of) the (api|response|payload)\b",
        r"\bchang(e|es|ing) (the )?(response|payload|api) (shape|format|contract|schema)\b",
        r"\bdeprecat\w* (the )?(v\d+ )?(api|endpoint)s?\b", r"\bdrop (support for )?(the )?v\d+( api)?\b"]),
    # T2 ─────────────────────────────────────────────────────────────────────────────────────────
    # new-endpoint: a new way in from the network.
    "new-endpoint": ("T2", [
        r"\b(new|add|adds|adding|create|expose)( an?| the)? ([\w-]+ ){0,2}(endpoint|route|api|rpc|graphql (query|mutation)|mutation)s?\b",
        r"\b(get|post|put|patch|delete) /[\w/{}:.-]+"]),
    # write-path: the change writes state (verbs whose object is not documentation).
    "write-path": ("T2", [
        r"\bcreat(e|es|ing)\b" + _DOCOBJ, r"\badd\b(\s+[\w'-]+){0,3}\s+forms?\b", r"\b(save|saves|saving)\b" + _DOCOBJ,
        r"\bsubmit\w*", r"\bedit(s|ing)?\b" + _DOCOBJ, r"\bupdat(e|es|ing)\b" + _DOCOBJ,
        r"\bdelet(e|es|ing)\b" + _DOCOBJ, r"\bupload\w*",
        r"\bimport(s|ing)? (\w+ ){0,2}(csv|files?|data|spreadsheets?|records|contacts|users|orders)\b"]),
    # external-call: the change talks to a system it does not own.
    "external-call": ("T2", [
        r"\bintegrat(e|es|ing|ion) with\b", r"\bwebhooks?\b", r"\bthird[- ]party\b",
        r"\bsend(s|ing)? (an? |the )?([\w-]+ )?(emails?|sms|text messages?|push notifications?|notifications?)\b",
        r"\bcall(s|ing)? (the |an? )?[\w.-]+ api\b", r"\bexternal (api|service)s?\b"]),
    # new-ui-surface: a new place a user looks at or acts in (a creation word must precede it).
    "new-ui-surface": ("T2", [
        r"\b(add|adds|adding|new|create|build|introduce)\b(\s+[\w'-]+){0,3}?\s+"
        r"(page|screen|form|modal|dialog|dashboard|button|panel|tab|widget|component|drawer|wizard)s?\b"]),
    # new-dependency: a library the project does not have yet.
    "new-dependency": ("T2", [
        r"\badd (the |a |an )?[\w@/.-]+ (library|package|dependency|sdk)\b", r"\binstall(ing)? (the )?[\w@/.-]+",
        r"\b(npm|pnpm|yarn|pip|poetry|cargo|composer|gem|bundle) (install|add|require)\b",
        r"\bnew (library|package|dependency|dependencies|sdk)\b", r"\buse (the )?[\w@/.-]+ (library|package|sdk)\b"]),
    # cross-module: the change spans modules (also path-derived, see the docstring).
    "cross-module": ("T2", [
        r"\bcross[- ]module\b", r"\bacross (all |every |several |multiple )?(modules|services|packages|apps)\b",
        r"\bshared (library|module|package|kernel|utils?)\b"]),
    # T0 ─────────────────────────────────────────────────────────────────────────────────────────
    # typo: spelling and grammar.
    "typo": ("T0", [r"\btypos?\b", r"\bspelling\b", r"\bmisspel\w*", r"\bgrammar\b"]),
    # docs-only: documentation and comments.
    "docs-only": ("T0", [
        r"\breadme\b", r"\bdocs\b", r"\bdocumentation\b", r"\bcomments?\b", r"\bchangelog\b",
        r"\bdocstrings?\b", r"\bjsdoc\b"]),
    # copy-only: user-facing words, not behaviour.
    "copy-only": ("T0", [
        r"\bwording\b", r"\bcopy (change|tweak|edit|update)s?\b", r"\b(change|update|tweak|fix) (the )?copy\b",
        r"\brename (the |a )?label( text)?\b", r"\blabel text\b", r"\bmicrocopy\b"]),
    # config-no-runtime: tooling config the running system never reads.
    "config-no-runtime": ("T0", [
        r"\b\.?editorconfig\b", r"\b\.?gitignore\b", r"\bprettierrc\b", r"\b(eslint|lint) (config|rules?)\b",
        r"\bcodeowners\b"]),
}
DERIVED = {"blast-radius": "graph caller count", "new-dependency-on-write-path": "manifest + write-path combination",
           "cross-module": "lexicon + module roots of the touched paths"}
NEGATORS = {"without", "no", "not", "never", "don't", "dont", "nor"}

DOC_PATH = re.compile(r"(^|/)(docs?|documentation)/|(^|/)(README|CHANGELOG|CONTRIBUTING|LICENSE)[^/]*$|\.(md|mdx|rst|txt|adoc)$", re.I)
TEST_PATH = re.compile(r"(^|/)(tests?|__tests__|spec|e2e|cypress|playwright)/|\.(test|spec)\.|_test\.|(^|/)test_[^/]*\.py$")
MIGRATION_PATH = re.compile(r"(^|/)(migrations?|migrate|alembic/versions|db/migrate)/|\.sql$", re.I)
MIGRATION_ALTER = re.compile(
    r"\bALTER\s+TABLE\b|\bDROP\s+(TABLE|COLUMN|INDEX)\b|\bRENAME\s+(COLUMN|TO)\b|\bUPDATE\s+[\w.\"`]+\s+SET\b|"
    r"\bDELETE\s+FROM\b|\b(add|remove|rename|change)_column\b|\bdrop_table\b|\bmigrations\.(AddField|RemoveField|"
    r"AlterField|RenameField|DeleteModel|RunSQL|RunPython)\b|\bSchema::(table|drop|dropIfExists|rename)\b|"
    r"\b(alterTable|dropTable|renameTable|dropColumn|renameColumn)\b|\bop\.(add_column|drop_column|alter_column|"
    r"drop_table|execute)\b", re.I)
MIGRATION_CREATE = re.compile(r"\bCREATE\s+TABLE\b|\bcreate_table\b|\bmigrations\.CreateModel\b|\bSchema::create\b|"
                              r"\bcreateTable\b|\bop\.create_table\b", re.I)
MANIFESTS = re.compile(r"(^|/)(package\.json|requirements[^/]*\.txt|pyproject\.toml|Pipfile|go\.mod|Cargo\.toml|"
                       r"Gemfile|composer\.json|pubspec\.yaml|build\.gradle(\.kts)?|pom\.xml|[^/]+\.csproj|"
                       r"Package\.swift|Podfile|mix\.exs)$")
# An added line that looks like a dependency entry, per manifest family (heuristic — HONEST LIMITS).
DEP_LINE = re.compile(
    r'^\+\s*("(?!version"|name")[@\w./-]+"\s*:\s*"([\^~<>=]*\d[\w.+-]*|latest|next|\*|workspace:[^"]*|npm:[^"]*|'
    r'file:[^"]*|git[^"]*|https?://[^"]*)"|"[A-Za-z0-9_.-]+\s*[=<>~!]=?[^"]*",?\s*$|'
    r'(?!name\b|version\b)[A-Za-z0-9_.@/-]+\s*([=<>~!^]=?|\s+v?\d)|(gem|implementation|api|require)\s+["\'(]|'
    r'<artifactId>|<PackageReference)')
# Three roots, not two: one feature split by layer (a component + its page) already spans two.
CROSS_MODULE_ROOTS = 3
MODULE_PREFIX = re.compile(r"^(src|app|lib|apps|packages|services|modules|internal|pkg|cmd)/")


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def tmax(a, b):
    return a if ORDER.index(a or "T0") >= ORDER.index(b or "T0") else b


def load_tiers(repo):
    for p in filter(None, [os.path.join(repo, ".claude", "templates", "governance", "tiers.json") if repo else None,
                           os.path.join(HERE, "..", "templates", "governance", "tiers.json"),
                           os.path.join(HERE, "..", "..", "..", "governance", "tiers.json")]):
        if os.path.isfile(p):
            with open(p, encoding="utf-8") as fh:
                return json.load(fh)
    raise FileNotFoundError("tiers.json not found (.claude/templates/governance/tiers.json)")


# ── text signals ─────────────────────────────────────────────────────────────────────────────────
_COMPILED = {k: (t, [re.compile(p, re.I) for p in pats]) for k, (t, pats) in LEXICON.items()}


def negated(text, start):
    words = re.findall(r"[\w']+", text[:start].lower())[-3:]
    return any(w in NEGATORS for w in words)


def text_reasons(text, source="request"):
    out = []
    for trig, (tier, pats) in _COMPILED.items():
        hit = None
        for rx in pats:
            for m in rx.finditer(text or ""):
                if not negated(text, m.start()):
                    hit = m.group(0).strip()
                    break
            if hit:
                break
        if hit:
            out.append({"tier": tier, "signal": trig, "source": source, "detail": "'%s'" % hit})
    return out


# ── path signals ─────────────────────────────────────────────────────────────────────────────────
def glob_re(glob):
    """fnmatch-style glob → anchored regex. `**/` = zero or more directories, `**` = anything,
    `*` / `?` stay inside one path segment. A glob without `/` matches the basename at any depth."""
    i, out = 0, []
    while i < len(glob):
        c = glob[i]
        if glob.startswith("**/", i):
            out.append(r"(?:.*/)?")
            i += 3
        elif glob.startswith("**", i):
            out.append(r".*")
            i += 2
        elif c == "*":
            out.append(r"[^/]*")
            i += 1
        elif c == "?":
            out.append(r"[^/]")
            i += 1
        elif c == "[":
            j = glob.find("]", i)
            if j == -1:
                out.append(re.escape(c))
                i += 1
            else:
                out.append("[" + glob[i + 1:j].replace("\\", "\\\\") + "]")
                i = j + 1
        else:
            out.append(re.escape(c))
            i += 1
    return re.compile("^" + "".join(out) + "$")


def glob_match(glob, path):
    if "/" not in glob:
        return bool(glob_re(glob).match(os.path.basename(path)))
    return bool(glob_re(glob).match(path))


def load_risk_map(repo, path, notes):
    p = os.path.join(repo, path) if not os.path.isabs(path) else path
    if not os.path.isfile(p):
        yml = os.path.splitext(p)[0] + ".yaml"
        if os.path.isfile(yml) or os.path.isfile(os.path.splitext(p)[0] + ".yml"):
            notes.append("ai/risk-map.yaml exists but is NOT parsed — the risk map is JSON only (D1); convert it "
                         "to %s. Path rules are off for this run." % os.path.relpath(p, repo))
        else:
            notes.append("no %s — path rules are off (the baseline ships one; /setup-project generates a "
                         "project-specific one)" % os.path.relpath(p, repo))
        return []
    try:
        with open(p, encoding="utf-8") as fh:
            data = json.load(fh)
    except ValueError as e:
        notes.append("%s does not parse (%s) — path rules are off" % (os.path.relpath(p, repo), e))
        return []
    rules = []
    for r in data.get("rules", []):
        if isinstance(r, dict) and r.get("glob") and r.get("tier") in ORDER and r.get("signal"):
            rules.append(r)
    return rules


def read_text(repo, rel, limit=400000):
    try:
        with open(os.path.join(repo, rel), encoding="utf-8", errors="replace") as fh:
            return fh.read(limit)
    except OSError:
        return ""


def module_root(path):
    if DOC_PATH.search(path) or TEST_PATH.search(path) or path.startswith(("ai/", ".claude/", ".github/")):
        return None
    parts = path.split("/")
    if len(parts) < 2:
        return None
    m = MODULE_PREFIX.match(path)
    if m:
        rest = parts[1:]
        if parts[0] in ("packages", "apps", "services") and len(rest) >= 2:
            return "/".join(parts[:2])
        return "/".join(parts[:2]) if len(rest) >= 2 else None
    return parts[0]


def path_reasons(repo, files, source, rules, graph, thresholds, diff_text_for=None):
    """Signals from a file set. source: design | diff. diff_text_for(path) -> added lines or None."""
    out, per_path = [], {}

    def add(path, tier, signal, src, detail):
        r = {"tier": tier, "signal": signal, "source": src, "detail": detail}
        out.append(r)
        per_path.setdefault(path, []).append(r)

    # importers from the graph
    importers = {}
    if graph is not None:
        for e in graph.get("edges", []) or []:
            if isinstance(e, dict) and e.get("to") and e.get("from"):
                importers.setdefault(e["to"], set()).add(e["from"])
    t3n, t2n = thresholds.get("callers_t3", 20), thresholds.get("callers_t2", 5)
    manifests_added = []
    for f in files:
        dep_rule = None
        for r in rules:
            if glob_match(r["glob"], f):
                if r["signal"] == "new-dependency":
                    dep_rule = dep_rule or r              # decided below: a diff must actually add one
                    continue
                add(f, r["tier"], r["signal"], "risk-map", "%s ~ %s (%s)" % (f, r["glob"], source))
        if MIGRATION_PATH.search(f):
            body = read_text(repo, f)
            if MIGRATION_ALTER.search(body):
                add(f, "T3", "migration-populated-table", source,
                    "%s: %s on an existing table" % (f, MIGRATION_ALTER.search(body).group(0)))
            elif MIGRATION_CREATE.search(body):
                add(f, "T2", "write-path", source, "%s: new table only (%s)" % (f, MIGRATION_CREATE.search(body).group(0)))
        if dep_rule or MANIFESTS.search(f):
            if diff_text_for is not None:                 # the diff: only an ADDED dependency line counts
                added = diff_text_for(f)
                deps = [l[1:].strip() for l in (added or "").splitlines() if DEP_LINE.match(l)]
                if deps:
                    manifests_added.append(f)
                    add(f, "T2", "new-dependency", source, "%s adds %s" % (f, deps[0][:60]))
            else:                                         # a predicted set: naming the manifest is the signal
                manifests_added.append(f)
                if dep_rule:
                    add(f, dep_rule["tier"], "new-dependency", "risk-map", "%s ~ %s (%s)" % (f, dep_rule["glob"], source))
                else:
                    add(f, "T2", "new-dependency", source, "%s in the predicted file set" % f)
        n = len(importers.get(f, ()))
        if n >= t3n:
            add(f, "T3", "blast-radius", "graph", "%s has %d importers (≥ %d)" % (f, n, t3n))
        elif n >= t2n:
            add(f, "T2", "blast-radius", "graph", "%s has %d importers (≥ %d)" % (f, n, t2n))
    # new dependency on a write path
    if manifests_added:
        for f, rs in sorted(per_path.items()):
            if MANIFESTS.search(f):
                continue
            if any(r["tier"] == "T3" or r["signal"] == "write-path" for r in rs):
                out.append({"tier": "T3", "signal": "new-dependency-on-write-path", "source": source,
                            "detail": "%s + %s" % (manifests_added[0], f)})
                break
    # cross-module by module roots
    roots = sorted({m for m in (module_root(f) for f in files) if m})
    if len(roots) >= CROSS_MODULE_ROOTS:
        out.append({"tier": "T2", "signal": "cross-module", "source": source,
                    "detail": "%d module roots: %s" % (len(roots), ", ".join(roots[:4]))})
    # all docs → T0 docs-only; any non-doc file → T1 floor (code changed: never T0)
    if files:
        code = [f for f in files if not DOC_PATH.search(f) or MANIFESTS.search(f)]
        if not code:
            out.append({"tier": "T0", "signal": "docs-only", "source": source, "detail": "%d doc file(s) only" % len(files)})
        else:
            out.append({"tier": "T1", "signal": "default", "source": source, "detail": "non-doc file touched: %s" % code[0]})
    return out


PATH_TOKEN = re.compile(r"(?<![\w/.@-])((?:[\w.@-]+/)+[\w.@-]+\.[A-Za-z0-9]{1,8})(?![\w/])")


def extract_paths(text):
    found = []
    for tok in re.findall(r"`([^`\n]+)`", text) + PATH_TOKEN.findall(text):
        tok = tok.strip().strip("'\"")
        if " " in tok or "://" in tok or not tok:
            continue
        tok = re.sub(r":\d+(-\d+)?$", "", tok)
        tok = tok[2:] if tok.startswith("./") else tok
        is_path = "/" in tok and re.search(r"\.[A-Za-z0-9]{1,8}$", tok)
        if (is_path or MANIFESTS.search(tok) or os.path.basename(tok).startswith("Dockerfile")) \
                and not tok.startswith(EXCLUDED) and tok not in found:
            found.append(tok)
    return found


# ── combining ────────────────────────────────────────────────────────────────────────────────────
def decide(reasons):
    """Highest tier wins; T0 only when a T0 signal and no T1+ signal; nothing → T1 default."""
    real = [r for r in reasons if r["signal"] != "default"]
    top = "T0"
    for r in reasons:
        top = tmax(top, r["tier"])
    if top == "T0":
        return ("T0", reasons) if any(r["tier"] == "T0" for r in real) else ("T1", reasons)
    return top, reasons


def dedupe(reasons):
    seen, out = set(), []
    for r in reasons:
        k = (r["signal"], r["source"], r["detail"])
        if k not in seen:
            seen.add(k)
            out.append(r)
    return out


def phase_num(p):
    return int(p[1:]) if p and p[1:].isdigit() else -1


def backfill(run, tiers, new_tier):
    want = tiers["tiers"][new_tier]["phases"]
    cur = phase_num(run.get("phase"))
    states = run.get("phases") or {}
    ui = bool(set(run.get("lanes") or []) & {"frontend", "mobile"})
    out = []
    for p in want:
        if phase_num(p) >= cur:
            continue
        if p == "P3" and not ui:
            continue
        if (states.get(p) or {}).get("state") in ("done", "active"):
            continue
        out.append(p)
    return out


# ── inputs ───────────────────────────────────────────────────────────────────────────────────────
def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def diff_files(repo, base, ci):
    if rr is None:
        raise RuntimeError("refract_records.py is not beside this script — --diff needs it")
    base = rr.resolve_base(repo, base)
    paths = rr.touched(repo, base, ci)
    return base, paths


def added_lines(repo, base, ci, path):
    if not os.path.isfile(os.path.join(repo, path)):
        return ""
    tracked = rr.git(repo, "ls-files", "--error-unmatch", path)
    if tracked is None:
        return "\n".join("+" + l for l in read_text(repo, path).splitlines())
    rng = [base, "HEAD"] if ci else [base]
    out = rr.git(repo, "diff", "-U0", *rng, "--", path) or ""
    return "\n".join(l for l in out.splitlines() if l.startswith("+") and not l.startswith("+++"))


def run_path(repo, run_id):
    return os.path.join(repo, "ai", "runs", run_id, "run.json")


def summarize(res, notes, out_json):
    if out_json:
        print(json.dumps(res, indent=2))
    else:
        head = "risk-tier: %s" % res["tier"]
        if res.get("recorded"):
            head += " (computed %s; recorded %s%s)" % (res["computed"], res["recorded"],
                                                      " → promoted" if res["promoted"] else "")
        print(head)
        for r in res["reasons"]:
            print("  %s %s (%s: %s)" % (r["tier"], r["signal"], r["source"], r["detail"]))
        if res.get("backfill"):
            print("  backfill: %s — the new tier requires these phases and the run passed them" % ", ".join(res["backfill"]))
    for n in notes:
        print("risk-tier: note — " + n, file=sys.stderr)


def compute(repo, opts, notes, request_text=None, ci=False):
    tiers = load_tiers(repo)
    reasons = []
    if request_text:
        reasons += text_reasons(request_text, "request")
    rules = load_risk_map(repo, opts.get("risk-map", "ai/risk-map.json"), notes) if (
        opts.get("files") or opts.get("files-from") or "diff" in opts or ci) else []
    graph = None
    gp = os.path.join(repo, opts.get("graph", ".claude/_graph.json"))
    files_sets = []
    if opts.get("files"):
        files_sets.append(("design", [f.strip()[2:] if f.strip().startswith("./") else f.strip()
                                      for f in opts["files"].split(",") if f.strip() and not f.strip().startswith(EXCLUDED)], None))
    if opts.get("files-from"):
        files_sets.append(("design", extract_paths(open(os.path.join(repo, opts["files-from"]) if not os.path.isabs(
            opts["files-from"]) else opts["files-from"], encoding="utf-8", errors="replace").read()), None))
    base = None
    if "diff" in opts or ci:
        base, paths = diff_files(repo, opts.get("base"), ci)
        paths = [p for p in paths if not p.startswith(EXCLUDED)]
        files_sets.append(("diff", paths, lambda p, b=base: added_lines(repo, b, ci, p)))
    if files_sets:
        if os.path.isfile(gp):
            try:
                graph = load_json(gp)
            except ValueError:
                notes.append("%s does not parse — blast radius not computed" % os.path.relpath(gp, repo))
        else:
            notes.append("no %s — blast radius not computed (build it: build-graph.py)" % os.path.relpath(gp, repo))
    for src, files, dfn in files_sets:
        reasons += path_reasons(repo, files, src, rules, graph, tiers.get("blast_radius", {}), dfn)
    reasons = dedupe(reasons)
    tier, reasons = decide(reasons)
    if tier != "T1":                                   # the code-touched floor only matters when it decides
        reasons = [r for r in reasons if r["signal"] != "default"]
    if not reasons:
        reasons = [{"tier": "T1", "signal": "default", "source": "request",
                    "detail": "no signal — T1 until a predicted file set shows a write path, a UI surface or a T3 path "
                              "(tiers.json default_feature_tier_why)"}]
    order = {t: i for i, t in enumerate(ORDER)}
    reasons.sort(key=lambda r: (-order[r["tier"]], r["signal"]))
    return tiers, tier, reasons, base


def validate_run(repo, run):
    if rr is None:
        return ["refract_records.py is not beside this script — run.json cannot be validated"]
    try:
        schema = rr.load_schema("run", repo)
    except FileNotFoundError as e:
        return [str(e)]
    return rr.validate(run, schema)


def write_run(repo, run_id, run):
    errs = validate_run(repo, run)
    if errs:
        print("risk-tier: refused — run.json would not validate against .claude/schemas/run.schema.json:", file=sys.stderr)
        for e in errs[:10]:
            print("  - " + e, file=sys.stderr)
        return 1
    rr.write_json(run_path(repo, run_id), run)
    return 0


def cmd_ci(repo, opts, notes):
    tiers, comp, reasons, base = compute(repo, opts, notes, opts.get("request"), ci=True)
    raw = rr.touched(repo, base, True)
    runs = sorted({p.split("/")[2] for p in raw if re.match(r"^ai/runs/[^/]+/run\.json$", p)})
    res = {"schema": "refract/risk-tier/v1", "tier": comp, "computed": comp, "reasons": reasons, "recorded": None,
           "promoted": False, "backfill": [], "runs": []}
    worst = 0
    for rid in runs:
        p = run_path(repo, rid)
        if not os.path.isfile(p):
            continue
        try:
            run = load_json(p)
        except ValueError:
            res["runs"].append({"run_id": rid, "status": "UNREADABLE"})
            worst = max(worst, 1)
            continue
        rt, rreasons = decide(dedupe(reasons + text_reasons((run.get("request") or {}).get("text", ""), "request")))
        floor = run.get("tier") or "T1"
        fl = run.get("forced_lower") or None
        if fl and fl.get("computed"):
            floor = tmax(floor, fl["computed"])
        under = ORDER.index(rt) > ORDER.index(floor)
        res["runs"].append({"run_id": rid, "recorded": run.get("tier"), "computed": rt,
                            "forced_lower": bool(fl), "status": "UNDER-TIERED" if under else "ok"})
        if under:
            worst = 3
    if "json" in opts:
        print(json.dumps(res, indent=2))
    else:
        print("risk-tier --ci: diff vs %s computes %s" % ((base or "?")[:12], comp))
        for r in reasons:
            print("  %s %s (%s: %s)" % (r["tier"], r["signal"], r["source"], r["detail"]))
        for r in res["runs"]:
            if r["status"] == "UNDER-TIERED":
                print("UNDER-TIERED: run %s records %s, the diff computes %s — re-tier with risk-tier.py --run=%s "
                      "--diff --write and back-fill the phases" % (r["run_id"], r["recorded"], r["computed"], r["run_id"]))
            else:
                print("  run %s: recorded %s, computed %s — %s" % (r["run_id"], r.get("recorded"), r.get("computed"), r["status"]))
        if not runs and comp != "T0":
            print("  no run record in the diff — a %s change (G15 input)" % comp)
    for n in notes:
        print("risk-tier: note — " + n, file=sys.stderr)
    return worst


def self_test():
    tiers = load_tiers(None)
    fails = []
    trig = tiers["t3_triggers"] + tiers["t2_triggers"] + tiers["t0_triggers"]
    for t in trig:
        if t not in LEXICON and t not in DERIVED:
            fails.append("trigger %s has no lexicon entry and is not derived" % t)
    for k, (tier, _) in LEXICON.items():
        if k not in trig:
            fails.append("lexicon key %s is not a tiers.json trigger" % k)
        want = "T3" if k in tiers["t3_triggers"] else "T2" if k in tiers["t2_triggers"] else "T0"
        if tier != want:
            fails.append("lexicon %s is %s, tiers.json lists it under %s" % (k, tier, want))
    cases = [("add a refund button", "T3"), ("fix the typo in the README", "T0"),
             ("show the order date on the orders list", "T1"), ("add a page to edit a customer's notes", "T2"),
             ("tweak the spacing without changing the response shape", "T1"), ("add a list filter, no new endpoint", "T1"),
             ("update the README wording", "T0")]
    for text, want in cases:
        got, _ = decide(text_reasons(text))
        if got != want:
            fails.append("%r → %s, want %s" % (text, got, want))
    for g, p, want in [("**/billing/**", "src/billing/refund.ts", True), ("**/billing/**", "billing/x.py", True),
                       ("Dockerfile*", "deploy/Dockerfile.prod", True), (".github/workflows/**", ".github/workflows/ci.yml", True),
                       ("**/auth/**", "src/author/x.ts", False)]:
        if glob_match(g, p) != want:
            fails.append("glob %s vs %s → %s" % (g, p, not want))
    for f in fails:
        print("FAIL " + f)
    print("risk-tier self-test: %d trigger(s), %d case(s), %d failure(s)" % (len(trig), len(cases), len(fails)))
    return 1 if fails else 0


def main(argv):
    opts = {}
    for a in argv:
        if a.startswith("--"):
            k, _, v = a[2:].partition("=")
            opts[k] = v
        else:
            print("risk-tier: unexpected argument %s" % a, file=sys.stderr)
            return 1
    if "self-test" in opts:
        return self_test()
    repo = rr.toplevel(opts.get("repo") or ".") if rr else None
    if not repo:
        repo = os.path.abspath(opts.get("repo") or ".")
        if "diff" in opts or "ci" in opts or "run" in opts:
            print("risk-tier: not inside a git work tree (or refract_records.py is missing)", file=sys.stderr)
            return 1
    notes = []
    req = opts.get("request")
    if opts.get("request-file"):
        try:
            req = open(opts["request-file"], encoding="utf-8", errors="replace").read()
        except OSError as e:
            print("risk-tier: %s" % e, file=sys.stderr)
            return 1
    out_json = "json" in opts
    try:
        if "ci" in opts:
            opts["request"] = req
            return cmd_ci(repo, opts, notes)
        run, run_id = None, opts.get("run")
        if run_id is not None:
            if not run_id or not os.path.isfile(run_path(repo, run_id)):
                print("risk-tier: ai/runs/%s/run.json does not exist" % run_id, file=sys.stderr)
                return 1
            try:
                run = load_json(run_path(repo, run_id))
            except ValueError as e:
                print("risk-tier: ai/runs/%s/run.json does not parse: %s" % (run_id, e), file=sys.stderr)
                return 1
            if not req:
                req = (run.get("request") or {}).get("text")
        if not (req or opts.get("files") or opts.get("files-from") or "diff" in opts):
            print(__doc__.split("\n\n")[0] + "\n" + __doc__.split("\n\n")[1], file=sys.stderr)
            return 1
        tiers, comp, reasons, _ = compute(repo, opts, notes, req)
    except (OSError, ValueError, RuntimeError) as e:
        print("risk-tier: %s" % e, file=sys.stderr)
        return 1

    if "force-lower" in opts:
        chosen, reason = opts["force-lower"], (opts.get("reason") or "").strip()
        if run is None:
            print("risk-tier: --force-lower needs --run=<run_id>", file=sys.stderr)
            return 1
        if chosen not in ("T0", "T1", "T2") or len(reason) < 8:
            print("risk-tier: --force-lower=<T0|T1|T2> needs --reason='<why, ≥ 8 chars>'", file=sys.stderr)
            return 1
        if ((run.get("phases") or {}).get("P0") or {}).get("state") == "done" or phase_num(run.get("phase")) > 0:
            print("risk-tier: refused — demotion mid-run is forbidden. The run is past P0; a tier only goes up "
                  "(tiers.json). Close this run and open a new one if the ask itself changed.", file=sys.stderr)
            return 2
        computed = tmax(run.get("tier") or "T1", comp)
        if computed == "T0":
            computed = "T1"
        if ORDER.index(chosen) >= ORDER.index(computed):
            print("risk-tier: %s is not below the computed %s — nothing to force" % (chosen, computed), file=sys.stderr)
            return 1
        run["forced_lower"] = {"computed": computed, "chosen": chosen, "reason": reason, "at": now()}
        if chosen != "T0":
            run["tier"] = chosen
        rc = write_run(repo, run_id, run)
        if rc:
            return rc
        print("risk-tier: forced %s → %s at P0 (%s). CI re-tiers from the diff (G15)." % (computed, chosen, reason))
        if chosen == "T0":
            print("risk-tier: T0 opens no run directory — the orchestrator records one ai/status.md line and removes "
                  "ai/runs/%s/ (forced_lower is logged in its run.json until then)." % run_id)
        return 0

    recorded = run.get("tier") if run else None
    tier = comp
    floor = None
    if run:
        tier = tmax(recorded, comp)
        fl = run.get("forced_lower") or None
        if fl and fl.get("computed") and ORDER.index(comp) <= ORDER.index(fl["computed"]):
            tier = recorded                     # the human already overruled every signal up to fl.computed
            floor = fl["computed"]
    promoted = bool(run) and ORDER.index(tier) > ORDER.index(recorded or "T0")
    bf = backfill(run, tiers, tier) if promoted else []
    res = {"schema": "refract/risk-tier/v1", "tier": tier, "computed": comp, "reasons": reasons,
           "recorded": recorded, "promoted": promoted, "backfill": bf}
    if floor:
        notes.append("forced_lower is in force (a human chose %s over %s at P0); only a signal above %s promotes"
                     % (recorded, floor, floor))
    if "write" in opts:
        if run is None:
            print("risk-tier: --write needs --run=<run_id>", file=sys.stderr)
            return 1
        stamp = now()
        have = {(r.get("signal"), r.get("source"), r.get("detail")) for r in run.get("tier_reasons", [])}
        new = [dict(r, at=stamp) for r in reasons if r["signal"] != "default" and r["tier"] != "T0"
               and (r["signal"], r["source"], r["detail"]) not in have]
        if not new and not promoted:
            summarize(res, notes + ["run.json unchanged (no new signal, no promotion)"], out_json)
            return 0
        run["tier_reasons"] = run.get("tier_reasons", []) + new
        if promoted:
            run["tier"] = tier
            srcs = sorted({r["source"] for r in reasons if r["tier"] == tier})
            entry = {"from": recorded, "to": tier, "at": stamp, "by": "risk-tier.py (%s)" % ", ".join(srcs)}
            if bf:
                entry["backfill"] = bf
            run.setdefault("tier_history", []).append(entry)
        rc = write_run(repo, run_id, run)
        if rc:
            return rc
    summarize(res, notes, out_json)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
