#!/usr/bin/env python3
"""readiness-score.py — the production-readiness scorecard, deterministic (launch-readiness, product pack).

Usage:  python3 -I readiness-score.py --repo=<dir> --feature=<slug> [options]     a feature's gate
        python3 -I readiness-score.py --repo=<dir> --scope=repo [options]         the repo scorecard
        python3 -I readiness-score.py --self-test
Options:
  --evidence=<tsv>   results for ledger / tool / runtime rules, written by the skill in THIS run
  --target=bronze|silver|gold   default: the feature's `stage` (experiment|beta -> bronze, ga -> silver);
                     repo scope -> bronze
  --rule=<id>        evaluate every rule, print and grade only this one (exit 0 PASS or N/A, 2 otherwise)
  --today=YYYY-MM-DD  the date typed fields are judged against (default: today)
  --max-age-days=N   a ledger row's report must be dated within N days of --today (default 0: same day)
  --rules=<json>     default: ../rules.json beside this script
  --out=<dir>        where readiness-<scope>.{txt,json} are written (default ${TMPDIR}); refused inside --repo
  --json             print the JSON result instead of the table
Exit:   0 the target level is met (READY) · 2 not met (NOT-READY or READY-UNVERIFIED) · 1 usage error

WHY. A launch checklist read by an agent turns green from a file's existence: a runbook that is the
template, an owner that is a team alias, a review date already past, a "ledger" nobody ran. This script
types every field it can read itself, accepts the rest only as evidence rows that name a report on disk
or a command with its exit code, and grades levels as cumulative gates: silver means every bronze AND
every silver rule passed. Ten passing rules never hide one failing kill switch.

INPUTS
  ai/product/success/<slug>.md   a `## Readiness fields` section of `key: value` lines (written by
                                 /define-success): stage, paths, metric, metric_event, counter_metric,
                                 counter_event, baseline, threshold, owner, review_date, decision_rule,
                                 rollback_record, emissions. Anything outside the section is ignored.
  ai/product/assumptions.md      assumption-ledger tables with Impact, Uncertainty, Expiry and Decision
                                 columns (Feature optional).
  owners                         CODEOWNERS in the four places GitHub/GitLab read (dot-directories walked
                                 by Python, never a shell `**`), catalog-info.yaml spec.owner.
  evidence TSV                   rule <TAB> status <TAB> token <TAB> source <TAB> note
      status  PASS | FAIL | N/A | UNVERIFIED | NOT-INSTALLED | NO-DATA | STALE
      token   Run (a tool or query executed this run) | Static (a report or file read)
      source  ai/audits/<YYYY-MM-DD>-<pack>.md   a ledger row: the file must exist and be fresh
              cmd:<command> exit=<n>             a tool row: PASS iff exit=0
              query:<lane> at=<ISO time> rows=<n> a runtime row: NO-DATA and STALE grade FAIL
      note    the reason; required for N/A and NOT-INSTALLED (the pack name)

RESULT PER RULE: PASS · FAIL · UNVERIFIED(<reason>) · NOT-INSTALLED(<pack>) · N/A(<reason>), with an
evidence token Run / Static / UNVERIFIED / N/A. No rule is ever PASS by default: a ledger, tool or
runtime rule with no evidence row is UNVERIFIED (no evidence this run).

HONEST LIMITS
  * CODEOWNERS matching is gitignore-style by fnmatch, not git's exact matcher; a feature glob is
    reduced to its literal prefix.
  * `person` rejects team handles (@org/team) and group words; it cannot tell a real name from a made-up one.
  * The script judges what the evidence row says about the owner's ledger; it never re-greps that class.
"""
import datetime
import fnmatch
import json
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_RULES = os.path.normpath(os.path.join(HERE, "..", "rules.json"))
LEVELS = ["bronze", "silver", "gold"]
STATUSES = {"PASS", "FAIL", "N/A", "UNVERIFIED", "NOT-INSTALLED", "NO-DATA", "STALE"}
PLACEHOLDER = re.compile(r"<[^<>\n]{1,60}>|\b(?:TBD|TODO|FIXME|XXX)\b|\?\?\?|\{\{|\blorem\b|\bplaceholder\b", re.I)
ISO_DATE = re.compile(r"(?<!\d)(\d{4})-(\d{2})-(\d{2})(?!\d)")
GROUP_WORD = re.compile(r"\b(?:team|teams|squad|group|guild|department|dept|everyone|all|engineering|eng|product|ops|devs|developers|stakeholders|tbd)\b", re.I)
BOT = re.compile(r"\[bot\]|(?:^|[-_@/])bot(?:$|[-_@.])|dependabot|renovate", re.I)
RESULT_OK = re.compile(r"\b(?:pass|passed|ok|reverted|succeeded|success|restored|green)\b", re.I)
RESULT_BAD = re.compile(r"\b(?:fail|failed|failure|aborted|red)\b", re.I)
SKIP_DIRS = {"node_modules", ".git", "dist", "build", ".next", "vendor", ".venv", "venv", "coverage", "target", "__pycache__"}


class Usage(Exception):
    pass


# ---------------------------------------------------------------- helpers
def parse_date(s):
    m = ISO_DATE.search(s or "")
    if not m:
        return None
    try:
        return datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    except ValueError:
        return None


def read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except (OSError, UnicodeDecodeError):
        return None


def readiness_fields(text):
    """`## Readiness fields` -> {key: (value, line)}; keys lower-cased, '-' and ' ' -> '_'."""
    out, on = {}, False
    for i, line in enumerate(text.split("\n"), 1):
        if re.match(r"^#{1,6}\s", line):
            on = bool(re.match(r"^#{1,6}\s+readiness fields\b", line, re.I))
            continue
        if not on:
            continue
        m = re.match(r"^\s*(?:[-*]\s+)?`?([A-Za-z][\w -]*?)`?\s*:\s*(.*?)\s*$", line)
        if m:
            key = re.sub(r"[\s-]+", "_", m.group(1).strip().lower())
            val = re.sub(r"\s+#\s.*$", "", m.group(2)).strip()
            out[key] = (val, i)
    return out


def type_check(kind, val, today):
    """-> None when the value passes, else the reason it fails."""
    if val is None or val == "":
        return "missing"
    if PLACEHOLDER.search(val):
        return "template placeholder (%s)" % PLACEHOLDER.search(val).group(0)
    if kind == "text":
        return None if len(val) >= 3 else "too short to be a definition"
    if kind == "number":
        return None if re.search(r"\d", val) else "no number"
    if kind == "number+date":
        if not re.search(r"\d", ISO_DATE.sub("", val)):
            return "no number besides the date"
        return None if parse_date(val) else "no ISO date (YYYY-MM-DD) for the baseline window"
    if kind == "person":
        if val.startswith("@") and "/" in val:
            return "a team handle, not a named person"
        if GROUP_WORD.search(val):
            return "a group, not a named person"
        return None
    if kind == "future-date":
        d = parse_date(val)
        if not d:
            return "no ISO date"
        return None if d > today else "date %s is not after %s" % (d.isoformat(), today.isoformat())
    if kind == "record":
        if not parse_date(val):
            return "no ISO date/time in the record"
        if RESULT_BAD.search(val):
            return "the recorded rollback failed"
        if not RESULT_OK.search(val):
            return "no result (pass / reverted / ok) in the record"
        if len(ISO_DATE.sub("", RESULT_OK.sub("", val)).strip(" ,;:-")) < 3:
            return "no environment in the record"
        return None
    if kind == "list-or-none":
        return None
    if kind == "stage":
        return None if val.lower() in ("experiment", "beta", "ga") else "stage must be experiment, beta or ga"
    raise Usage("unknown field type %r in rules.json" % kind)


def walk_files(repo):
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            yield os.path.relpath(os.path.join(root, f), repo).replace(os.sep, "/")


def glob_match(rel, pat):
    """`**/x/**` style match against a relative posix path."""
    rx = re.escape(pat).replace(r"\*\*/", "(?:.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*").replace(r"\?", "[^/]")
    return re.fullmatch(rx, rel) is not None


def owners_rules(repo, files):
    rules = []
    for f in files:
        text = read(os.path.join(repo, f))
        if text is None:
            continue
        for i, line in enumerate(text.split("\n"), 1):
            line = line.split("#", 1)[0].strip()
            if not line or line.startswith("["):
                continue
            parts = line.split()
            rules.append((f, i, parts[0], parts[1:]))
    return rules


def codeowners_match(pattern, path):
    p = pattern
    anchored = p.startswith("/") or "/" in p.rstrip("/")
    p = p.lstrip("/")
    if p in ("*", "**"):
        return True
    if p.endswith("/"):
        p = p + "**"
    if not anchored:
        return any(fnmatch.fnmatch(seg, p.rstrip("/*") or p) for seg in path.split("/")) or fnmatch.fnmatch(path, "*/" + p) or fnmatch.fnmatch(path, p)
    if glob_match(path, p) or glob_match(path, p + "/**"):
        return True
    return False


def owner_for(rules, path):
    hit = None
    for r in rules:                      # the LAST matching rule wins (GitHub and GitLab)
        if codeowners_match(r[2], path):
            hit = r
    return hit


def literal_prefix(glob):
    m = re.match(r"^[^*?\[{]*", glob)
    pre = m.group(0) if m else ""
    if not pre or pre.endswith("/"):
        return (pre or "") + "__readiness_probe__"
    return pre


# ---------------------------------------------------------------- evidence TSV
def load_evidence(path, rules_by_id, repo, today, max_age):
    rows = {}
    if not path:
        return rows
    text = read(path)
    if text is None:
        raise Usage("cannot read evidence file %s" % path)
    for n, line in enumerate(text.split("\n"), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cols = line.split("\t")
        if cols[0].strip().lower() == "rule":
            continue
        cols += [""] * (5 - len(cols))
        rid, status, token, source, note = (c.strip() for c in cols[:5])
        if rid not in rules_by_id:
            raise Usage("evidence line %d: unknown rule id %r" % (n, rid))
        kind = rules_by_id[rid]["evidence"]["kind"]
        if kind in ("file", "doc-field"):
            raise Usage("evidence line %d: %s is a %s rule the script evaluates itself; evidence rows are refused"
                        % (n, rid, kind))
        status = status.upper()
        if status not in STATUSES:
            raise Usage("evidence line %d: status %r is not one of %s" % (n, status, ", ".join(sorted(STATUSES))))
        rows.setdefault(rid, []).append(grade_row(status, token, source, note, repo, today, max_age))
    return rows


def grade_row(status, token, source, note, repo, today, max_age):
    """-> (result, token, evidence text)."""
    ev = (source + (" — " + note if note else "")).strip(" —")
    if status == "N/A":
        return ("N/A", "N/A", ev) if note else ("UNVERIFIED", "UNVERIFIED", "N/A without a reason")
    if status == "NOT-INSTALLED":
        return ("NOT-INSTALLED", "UNVERIFIED", note or "owner pack not named")
    if status == "UNVERIFIED":
        return ("UNVERIFIED", "UNVERIFIED", ev or "no reason given")
    if source.startswith("cmd:"):
        m = re.search(r"\bexit=(\d+)\b", source)
        if not m:
            return ("UNVERIFIED", "UNVERIFIED", "tool row with no exit code: " + source)
        derived = "PASS" if m.group(1) == "0" else "FAIL"
        if status in ("PASS", "FAIL") and status != derived:
            return ("UNVERIFIED", "UNVERIFIED", "status %s contradicts %s" % (status, m.group(0)))
        return (derived, "Run", ev)
    if source.startswith("query:"):
        if not re.search(r"\bat=\d{4}-\d{2}-\d{2}", source):
            return ("UNVERIFIED", "UNVERIFIED", "query row with no at=<ISO time>: " + source)
        if status in ("NO-DATA", "STALE"):
            return ("FAIL", "Run", status + " — " + ev)
        return (status if status in ("PASS", "FAIL") else "UNVERIFIED", "Run", ev)
    # a ledger row: the report must exist and be fresh
    rel = source.split("#", 1)[0].split(":", 1)[0].strip()
    if not rel:
        return ("UNVERIFIED", "UNVERIFIED", "ledger row with no source report")
    full = rel if os.path.isabs(rel) else os.path.join(repo, rel)
    if not os.path.isfile(full):
        return ("UNVERIFIED", "UNVERIFIED", "cited report missing: " + rel)
    d = parse_date(os.path.basename(rel))
    if d is None:
        return ("UNVERIFIED", "UNVERIFIED", "cited report has no date in its name: " + rel)
    if (today - d).days > max_age:
        return ("UNVERIFIED", "UNVERIFIED", "stale ledger (%s, %d days before %s)" % (rel, (today - d).days, today))
    if status in ("NO-DATA", "STALE"):
        return ("FAIL", "Static", status + " — " + ev)
    return (status if status in ("PASS", "FAIL") else "UNVERIFIED", "Static", ev)


def combine(rows):
    res = [r[0] for r in rows]
    for want in ("FAIL", "UNVERIFIED", "NOT-INSTALLED"):
        if want in res:
            i = res.index(want)
            return rows[i]
    if all(r == "N/A" for r in res):
        return rows[0]
    passing = [r for r in rows if r[0] == "PASS"]
    return ("PASS", passing[0][1], "; ".join(r[2] for r in passing if r[2]))


# ---------------------------------------------------------------- rule evaluation
def eval_owners(rule, ctx):
    ev = rule["evidence"]
    files = [f for f in ev["owners_files"] if os.path.isfile(os.path.join(ctx["repo"], f))]
    rules = owners_rules(ctx["repo"], files)
    catalog = []
    for f in ctx["files"]:
        if os.path.basename(f) in ev["catalog_files"]:
            m = re.search(r"^\s*owner\s*:\s*(\S.*)$", read(os.path.join(ctx["repo"], f)) or "", re.M)
            if m:
                catalog.append((f, m.group(1).strip()))
    if not rules and not catalog:
        return ("FAIL", "Static", "no CODEOWNERS (root, .github/, docs/, .gitlab/) and no catalog-info.yaml spec.owner")
    paths = ctx["paths"]
    if ctx["scope"] == "repo" or not paths:
        human = [r for r in rules if r[3] and not all(BOT.search(o) for o in r[3])]
        if human or catalog:
            src = ("%s:%d" % human[0][:2]) if human else catalog[0][0]
            return ("PASS", "Static", "owner metadata at " + src)
        return ("FAIL", "Static", "every owners rule names a bot only or no owner")
    gaps = []
    for g in paths:
        probe = literal_prefix(g)
        hit = owner_for(rules, probe)
        if hit is None or not hit[3]:
            gaps.append("%s (no matching rule)" % g)
        elif all(BOT.search(o) for o in hit[3]):
            gaps.append("%s (%s:%d names a bot only)" % (g, hit[0], hit[1]))
    if gaps and catalog:
        return ("PASS", "Static", "catalog-info.yaml owner at %s (CODEOWNERS gaps: %s)" % (catalog[0][0], ", ".join(gaps)))
    if gaps:
        return ("FAIL", "Static", "not covered: " + ", ".join(gaps))
    return ("PASS", "Static", "every feature path covered (%s)" % ", ".join(files))


def eval_success_fields(rule, ctx):
    sf = ctx["success"]
    if sf is None:
        return ("FAIL", "Static", "no %s — run /define-success" % ctx["success_rel"])
    bad = []
    for key, kind in rule["evidence"]["fields"].items():
        val, line = sf.get(key, (None, None))
        why = type_check(kind, val, ctx["today"])
        if why:
            bad.append("%s: %s%s" % (key, why, (" (line %d)" % line) if line else ""))
    if bad:
        return ("FAIL", "Static", "%s — %s" % (ctx["success_rel"], "; ".join(bad)))
    return ("PASS", "Static", "%s fields typed" % ctx["success_rel"])


def eval_assumptions(rule, ctx):
    rel = ctx["assumptions_rel"]
    text = read(os.path.join(ctx["repo"], rel))
    if text is None:
        return ("UNVERIFIED", "UNVERIFIED", "no %s — run assumption-ledger" % rel)
    open_rows, seen = [], 0
    header = None
    for i, line in enumerate(text.split("\n"), 1):
        if not line.strip().startswith("|"):
            header = None if not line.strip() else header
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        low = [c.lower() for c in cells]
        if "impact" in low and "uncertainty" in low:
            header = low
            continue
        if header is None or all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue
        row = dict(zip(header, cells))
        if row.get("impact", "").lower() != "fatal" or row.get("uncertainty", "").lower() != "high":
            continue
        feat = row.get("feature", "").strip()
        if ctx["scope"] == "feature" and feat not in ("", "*", "-", ctx["slug"]):
            continue
        exp = parse_date(row.get("expiry", ""))
        if ctx["scope"] == "repo" and (exp is None or exp >= ctx["today"]):
            continue
        seen += 1
        dec = (row.get("decision") or row.get("status") or "").strip()
        decided = re.match(r"(?i)^(tested|accepted)\b\s*[:(—-]?\s*\S", dec) and not PLACEHOLDER.search(dec)
        if not decided:
            open_rows.append("%s:%d %s" % (rel, i, (row.get("assumption (falsifiable)") or row.get("assumption") or cells[1] if len(cells) > 1 else "")[:60]))
    if open_rows:
        return ("FAIL", "Static", "undecided fatal x high: " + "; ".join(open_rows))
    return ("PASS", "Static", "%s: %d fatal x high row(s) in scope, all decided" % (rel, seen))


def eval_external(rule, ctx, rows):
    ev = rule["evidence"]
    if ev.get("requires_files"):
        hits = [f for f in ctx["files"] if any(glob_match(f, g) for g in ev["requires_files"])]
        if not hits:
            return ("FAIL", "Static", "no file matching %s" % ", ".join(ev["requires_files"][:4]) + " …")
    if rows:
        return combine(rows)
    return ("UNVERIFIED", "UNVERIFIED", "needs %s" % ev.get("external", "a recorded run"))


def evaluate(rule, ctx, ev_rows):
    if ctx["scope"] not in rule["scope"]:
        return ("N/A", "N/A", "a %s-scope rule; this run is %s scope" % ("/".join(rule["scope"]), ctx["scope"]))
    kind = rule["evidence"]["kind"]
    rows = ev_rows.get(rule["id"], [])
    if kind == "file":
        return eval_owners(rule, ctx)
    if kind == "doc-field":
        if rule["evidence"].get("source") == "assumptions":
            return eval_assumptions(rule, ctx)
        return eval_success_fields(rule, ctx)
    if kind == "runtime":
        return eval_external(rule, ctx, rows)
    if kind in ("ledger", "tool"):
        if not rows:
            return ("UNVERIFIED", "UNVERIFIED", "no evidence this run (%s)" % rule["owner"])
        return combine(rows)
    raise Usage("rule %s: unknown evidence kind %r" % (rule["id"], kind))


def validate_rules(spec):
    rules = spec.get("rules")
    if not isinstance(rules, list) or not rules:
        raise Usage("rules.json has no rules")
    ids = set()
    for r in rules:
        for k in ("id", "level", "scope", "owner", "evidence", "pass", "why"):
            if k not in r:
                raise Usage("rule %s lacks %r" % (r.get("id", "?"), k))
        if r["id"] in ids:
            raise Usage("duplicate rule id %s" % r["id"])
        ids.add(r["id"])
        if r["level"] not in LEVELS:
            raise Usage("rule %s: level %r" % (r["id"], r["level"]))
        if r["evidence"].get("kind") not in spec.get("evidence_kinds", []):
            raise Usage("rule %s: evidence kind %r" % (r["id"], r["evidence"].get("kind")))
    return rules


# ---------------------------------------------------------------- the run
def score(argv):
    opts = {"json": False}
    for a in argv:
        if a == "--json":
            opts["json"] = True
        elif a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            opts[k] = v
        else:
            raise Usage("unknown argument %r" % a)
    repo = opts.get("repo")
    if not repo or not os.path.isdir(repo):
        raise Usage("--repo=<dir> is required and must exist")
    repo = os.path.realpath(repo)
    scope = opts.get("scope", "feature" if "feature" in opts else None)
    if scope not in ("feature", "repo"):
        raise Usage("give --feature=<slug> or --scope=repo")
    slug = opts.get("feature", "")
    if scope == "feature" and not re.fullmatch(r"[\w.-]+", slug or ""):
        raise Usage("--feature=<slug> must be a file-name slug")
    try:
        today = datetime.date.fromisoformat(opts["today"]) if "today" in opts else datetime.date.today()
        max_age = int(opts.get("max-age-days", "0"))
    except ValueError as e:
        raise Usage(str(e))
    spec_text = read(opts.get("rules", DEFAULT_RULES))
    if spec_text is None:
        raise Usage("cannot read rules file %s" % opts.get("rules", DEFAULT_RULES))
    spec = json.loads(spec_text)
    rules = validate_rules(spec)
    by_id = {r["id"]: r for r in rules}
    if "rule" in opts and opts["rule"] not in by_id:
        raise Usage("--rule=%s is not in rules.json" % opts["rule"])
    out_dir = os.path.realpath(opts.get("out", tempfile.gettempdir()))
    if out_dir == repo or out_dir.startswith(repo + os.sep):
        raise Usage("--out=%s is inside the audited repo; this script never writes there" % out_dir)

    success_rel = "%s/%s.md" % (spec["success_dir"], slug) if scope == "feature" else None
    success = None
    if success_rel:
        t = read(os.path.join(repo, success_rel))
        success = readiness_fields(t) if t is not None else None
    stage = (success or {}).get("stage", ("", 0))[0].lower() if success else ""
    if "target" in opts:
        target = opts["target"]
        if target not in LEVELS:
            raise Usage("--target must be one of %s" % ", ".join(LEVELS))
        target_from = "--target"
    elif scope == "feature" and stage in spec["stage_target"]:
        target, target_from = spec["stage_target"][stage], "stage %s" % stage
    elif scope == "feature":
        target, target_from = "bronze", "no valid stage in the success file (bronze floor)"
    else:
        target, target_from = spec["repo_default_target"], "repo default"
    paths = [p.strip() for p in (success or {}).get("paths", ("", 0))[0].split(",") if p.strip()] if success else []
    if "paths" in opts:
        paths = [p.strip() for p in opts["paths"].split(",") if p.strip()]
    ctx = {"repo": repo, "scope": scope, "slug": slug, "today": today, "success": success,
           "success_rel": success_rel, "assumptions_rel": spec["assumptions_file"], "paths": paths,
           "files": list(walk_files(repo))}
    ev_rows = load_evidence(opts.get("evidence"), by_id, repo, today, max_age)

    results = []
    for r in rules:
        res, tok, ev = evaluate(r, ctx, ev_rows)
        results.append({"id": r["id"], "level": r["level"], "owner": r["owner"], "result": res,
                        "token": tok, "evidence": ev})
    # cumulative levels: a level is reached only when it and every level below it is all PASS / N/A
    reached, per_level = "none", {}
    for lv in LEVELS:
        rs = [x for x in results if x["level"] == lv]
        per_level[lv] = {k: sum(1 for x in rs if x["result"] == k) for k in ("PASS", "FAIL", "N/A", "UNVERIFIED", "NOT-INSTALLED")}
    for lv in LEVELS:
        upto = [x for x in results if LEVELS.index(x["level"]) <= LEVELS.index(lv)]
        if all(x["result"] in ("PASS", "N/A") for x in upto):
            reached = lv
        else:
            break
    gate = [x for x in results if LEVELS.index(x["level"]) <= LEVELS.index(target)]
    fails = [x for x in gate if x["result"] == "FAIL"]
    unver = [x for x in gate if x["result"] in ("UNVERIFIED", "NOT-INSTALLED")]
    if fails:
        verdict = "NOT-READY (%d failing)" % len(fails)
    elif unver:
        verdict = "READY-UNVERIFIED (%d)" % len(unver)
    else:
        verdict = "READY"
    nxt = "bronze" if reached == "none" else (LEVELS[LEVELS.index(reached) + 1] if reached != "gold" else None)
    gap = [x for x in results if nxt and LEVELS.index(x["level"]) <= LEVELS.index(nxt) and x["result"] not in ("PASS", "N/A")]
    doc = {"schema": "refract/readiness-score/v1", "scope": scope, "feature": slug or None, "stage": stage or None,
           "target": target, "target_from": target_from, "today": today.isoformat(), "level_reached": reached,
           "verdict": verdict, "levels": per_level, "next_level": nxt,
           "gap": [x["id"] for x in gap], "rules": results}

    lines = ["readiness-score — scope=%s%s  target=%s (%s)  today=%s" % (
        scope, (" feature=" + slug) if slug else "", target, target_from, today.isoformat())]
    shown = [x for x in results if "rule" not in opts or x["id"] == opts["rule"]]
    lines.append("%-11s %-7s %-14s %-10s %s" % ("rule", "level", "result", "token", "evidence"))
    for x in shown:
        res = x["result"] if x["result"] in ("PASS", "FAIL") else "%s" % x["result"]
        lines.append("%-11s %-7s %-14s %-10s %s" % (x["id"], x["level"], res, x["token"], x["evidence"]))
    if "rule" not in opts:
        lines.append("Levels: " + " · ".join("%s %d pass / %d fail / %d unverified / %d n/a" % (
            lv, per_level[lv]["PASS"], per_level[lv]["FAIL"], per_level[lv]["UNVERIFIED"] + per_level[lv]["NOT-INSTALLED"],
            per_level[lv]["N/A"]) for lv in LEVELS))
        lines.append("Level reached: %s (cumulative; UNVERIFIED never counts as PASS)" % reached)
        if nxt:
            lines.append("Gap to %s: %s" % (nxt, ", ".join("%s %s" % (x["id"], x["result"]) for x in gap) or "none"))
        lines.append("Verdict: %s" % verdict)
    text = "\n".join(lines)
    try:
        os.makedirs(out_dir, exist_ok=True)
        base = os.path.join(out_dir, "readiness-%s%s" % (scope, ("-" + slug) if slug else ""))
        with open(base + ".json", "w", encoding="utf-8") as f:
            json.dump(doc, f, indent=1)
        with open(base + ".txt", "w", encoding="utf-8") as f:
            f.write(text + "\n")
    except OSError as e:
        raise Usage("cannot write --out: %s" % e)
    print(json.dumps(doc, indent=1) if opts["json"] else text)
    if "rule" in opts:
        r = next(x for x in results if x["id"] == opts["rule"])
        return 0 if r["result"] in ("PASS", "N/A") else 2
    return 0 if verdict == "READY" else 2


# ---------------------------------------------------------------- self-test
SUCCESS_OK = """# Success — checkout-v2

## Readiness fields
stage: beta
paths: apps/web/src/checkout/**, apps/api/src/checkout/**
metric: checkout completion rate, 7-day
metric_event: CheckoutCompleted
counter_metric: refund rate, 30-day
counter_event: RefundIssued
baseline: 34% (2026-09-01..2026-10-01)
threshold: rollback if refund rate > 4%
owner: Dana Reyes
review_date: 2026-12-01
decision_rule: keep if completion >= 38% and refunds <= 4% by 2026-12-01
rollback_record: staging 2026-10-12T14:00Z flag off, reverted ok
emissions: order-confirmation email; webhook order.created
"""


def _self_test():
    import contextlib
    import io
    import shutil
    fails, n_checks = [], [0]
    base = tempfile.mkdtemp(prefix="readiness-selftest-")
    out = tempfile.mkdtemp(prefix="readiness-out-")

    def mk(files):
        d = tempfile.mkdtemp(dir=base)
        for rel, body in files.items():
            p = os.path.join(d, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8") as f:
                f.write(body)
        return d

    def run(args):
        buf = io.StringIO()
        try:
            with contextlib.redirect_stdout(buf):
                code = score(args + ["--out=" + out, "--today=2026-10-19"])
        except Usage as e:
            return 1, str(e)
        return code, buf.getvalue()

    def check(name, cond):
        n_checks[0] += 1
        if not cond:
            fails.append(name)

    def rule_of(text, rid):
        for line in text.split("\n"):
            if line.startswith(rid + " "):
                return line
        return ""

    owners = "* @acme/platform\napps/web/src/checkout/ @dana\napps/api/src/checkout/ @dana\n"
    ok = {"ai/product/success/checkout-v2.md": SUCCESS_OK, ".github/CODEOWNERS": owners,
          "ai/audits/2026-10-19-devops.md": "ledger", "ai/audits/2026-10-19-product.md": "ledger",
          "ai/audits/2026-10-19-ui-ux.md": "ledger", "ai/audits/2026-10-19-security.md": "ledger"}
    ev_ok = ("rule\tstatus\ttoken\tsource\tnote\n"
             "PRR-AN-2\tPASS\tStatic\tai/audits/2026-10-19-product.md\tAN §2 quiet for CheckoutCompleted, RefundIssued\n"
             "PRR-FL-1\tPASS\tStatic\tai/audits/2026-10-19-devops.md\tDP §4 0 rows\n"
             "PRR-UX-1\tPASS\tStatic\tai/audits/2026-10-19-ui-ux.md\tUS §1-§4 0 rows\n"
             "PRR-FS-1\tPASS\tStatic\tai/audits/2026-10-19-product.md\tFS §1 §4 0 rows\n"
             "PRR-SEC-1\tPASS\tStatic\tai/audits/2026-10-19-security.md\t0 open high\n")

    # 1. a complete beta feature with fresh evidence is READY at bronze (its stage's target)
    d = mk(dict(ok, **{"ev.tsv": ev_ok}))
    code, txt = run(["--repo=" + d, "--feature=checkout-v2", "--evidence=" + os.path.join(d, "ev.tsv")])
    check("1 beta READY at bronze", code == 0 and "Verdict: READY" in txt and "target=bronze (stage beta)" in txt)
    check("1 level bronze reached", "Level reached: bronze" in txt)
    check("1 no evidence -> UNVERIFIED never PASS", "UNVERIFIED" in rule_of(txt, "PRR-OBS-1"))
    # 2. no evidence at all: bronze ledger rules are UNVERIFIED, verdict READY-UNVERIFIED, exit 2
    d2 = mk(ok)
    code, txt = run(["--repo=" + d2, "--feature=checkout-v2"])
    check("2 READY-UNVERIFIED exit 2", code == 2 and "READY-UNVERIFIED (5)" in txt)
    # 3. template placeholder, past review date, group owner, baseline without date -> PRR-LR-1 FAIL
    bad = SUCCESS_OK.replace("Dana Reyes", "growth team").replace("2026-12-01\ndecision", "2026-10-01\ndecision") \
                    .replace("checkout completion rate, 7-day", "<metric name>").replace("(2026-09-01..2026-10-01)", "(last month)")
    d3 = mk(dict(ok, **{"ai/product/success/checkout-v2.md": bad}))
    code, txt = run(["--repo=" + d3, "--feature=checkout-v2", "--rule=PRR-LR-1"])
    l = rule_of(txt, "PRR-LR-1")
    check("3 LR-1 FAIL exit 2", code == 2 and " FAIL " in l)
    check("3 placeholder named", "template placeholder" in l)
    check("3 group owner named", "a group, not a named person" in l)
    check("3 past date named", "is not after 2026-10-19" in l)
    check("3 baseline date named", "no ISO date" in l)
    # 4. missing success file -> FAIL, stage unknown -> bronze floor
    d4 = mk({".github/CODEOWNERS": owners})
    code, txt = run(["--repo=" + d4, "--feature=nope"])
    check("4 missing success FAIL", " FAIL " in rule_of(txt, "PRR-LR-1") and "run /define-success" in txt and code == 2)
    # 5. ledger rows: missing report, stale report, tool without exit, contradicting exit, N/A without reason
    ev5 = ("PRR-FL-1\tPASS\tStatic\tai/audits/2026-10-19-nothere.md\t\n"
           "PRR-UX-1\tPASS\tStatic\tai/audits/2026-10-01-ui-ux.md\t\n"
           "PRR-FS-1\tPASS\tRun\tcmd:surface-map.py --check\t\n"
           "PRR-TR-1\tPASS\tRun\tcmd:trace-matrix.py r1 exit=2\t\n"
           "PRR-I18N-1\tN/A\tN/A\t\t\n"
           "PRR-EN-1\tN/A\tN/A\t\tno plans or catalog in the product\n"
           "PRR-OBS-1\tNOT-INSTALLED\tUNVERIFIED\t\tobservability\n"
           "PRR-AN-2\tNO-DATA\tRun\tquery:posthog at=2026-10-19T08:00Z rows=0\t\n")
    d5 = mk(dict(ok, **{"ai/audits/2026-10-01-ui-ux.md": "old", "ev.tsv": ev5}))
    code, txt = run(["--repo=" + d5, "--feature=checkout-v2", "--evidence=" + os.path.join(d5, "ev.tsv")])
    check("5 missing report UNVERIFIED", "cited report missing" in rule_of(txt, "PRR-FL-1"))
    check("5 stale report UNVERIFIED", "stale ledger" in rule_of(txt, "PRR-UX-1"))
    check("5 no exit UNVERIFIED", "no exit code" in rule_of(txt, "PRR-FS-1"))
    check("5 contradicting exit UNVERIFIED", "contradicts exit=2" in rule_of(txt, "PRR-TR-1"))
    check("5 N/A without reason", "N/A without a reason" in rule_of(txt, "PRR-I18N-1"))
    check("5 N/A with reason", rule_of(txt, "PRR-EN-1").split()[2] == "N/A")
    check("5 NOT-INSTALLED", "NOT-INSTALLED" in rule_of(txt, "PRR-OBS-1"))
    check("5 NO-DATA is FAIL", " FAIL " in rule_of(txt, "PRR-AN-2") and code == 2 and "NOT-READY" in txt)
    code, txt = run(["--repo=" + d5, "--feature=checkout-v2", "--evidence=" + os.path.join(d5, "ev.tsv"), "--max-age-days=30"])
    check("5 max-age widens the window", "stale ledger" not in rule_of(txt, "PRR-UX-1"))
    # 6. owners: bot-only, a path no rule covers, no owners file at all, a .gitlab/ file
    d6 = mk(dict(ok, **{".github/CODEOWNERS": "* @renovate-bot\napps/api/ @dana\n"}))
    code, txt = run(["--repo=" + d6, "--feature=checkout-v2", "--rule=PRR-OWN-1"])
    check("6 bot-only owner FAIL", code == 2 and "names a bot only" in txt)
    d6b = mk(dict(ok, **{".github/CODEOWNERS": "apps/api/ @dana\n"}))
    code, txt = run(["--repo=" + d6b, "--feature=checkout-v2", "--rule=PRR-OWN-1"])
    check("6 uncovered path FAIL", code == 2 and "apps/web/src/checkout/** (no matching rule)" in txt)
    d6c = mk({k: v for k, v in ok.items() if "CODEOWNERS" not in k})
    code, txt = run(["--repo=" + d6c, "--feature=checkout-v2", "--rule=PRR-OWN-1"])
    check("6 no owners FAIL", code == 2 and "no CODEOWNERS" in txt)
    d6d = mk(dict({k: v for k, v in ok.items() if "CODEOWNERS" not in k}, **{".gitlab/CODEOWNERS": "/apps/ @dana\n"}))
    code, txt = run(["--repo=" + d6d, "--feature=checkout-v2", "--rule=PRR-OWN-1"])
    check("6 dot-dir CODEOWNERS found", code == 0)
    # 7. usage errors: --out inside the repo, unknown rule id, an evidence row for a script-evaluated rule
    code, msg = run(["--repo=" + d, "--feature=checkout-v2", "--out=" + os.path.join(d, "x")])
    # run() appends its own --out last; a second --out inside the repo must also be refused
    try:
        score(["--repo=" + d, "--feature=checkout-v2", "--today=2026-10-19", "--out=" + os.path.join(d, "x")])
        check("7 out inside repo refused", False)
    except Usage as e:
        check("7 out inside repo refused", "inside the audited repo" in str(e))
    d7 = mk(dict(ok, **{"ev.tsv": "PRR-NOPE-9\tPASS\tStatic\tx\t\n"}))
    code, msg = run(["--repo=" + d7, "--feature=checkout-v2", "--evidence=" + os.path.join(d7, "ev.tsv")])
    check("7 unknown rule id exit 1", code == 1 and "unknown rule id" in msg)
    d7b = mk(dict(ok, **{"ev.tsv": "PRR-LR-1\tPASS\tStatic\tai/audits/2026-10-19-product.md\t\n"}))
    code, msg = run(["--repo=" + d7b, "--feature=checkout-v2", "--evidence=" + os.path.join(d7b, "ev.tsv")])
    check("7 doc-field evidence refused", code == 1 and "evaluates itself" in msg)
    # 8. assumptions: an undecided fatal x high row FAILs, an accepted one passes, other features ignored
    tbl = ("| # | Assumption | Impact | Uncertainty | Expiry | Decision | Feature |\n|---|---|---|---|---|---|---|\n"
           "| 1 | buyers trust saved cards | fatal | high | 2026-11-01 | open | checkout-v2 |\n"
           "| 2 | refunds stay under 4% | fatal | high | 2026-09-01 | accepted: Dana Reyes | checkout-v2 |\n"
           "| 3 | referrals convert | fatal | high | 2026-09-01 | | referrals |\n")
    d8 = mk(dict(ok, **{"ai/product/assumptions.md": tbl}))
    code, txt = run(["--repo=" + d8, "--feature=checkout-v2", "--rule=PRR-LR-6"])
    check("8 undecided fatal FAIL", code == 2 and "assumptions.md:3" in txt and "assumptions.md:5" not in txt)
    code, txt = run(["--repo=" + d8, "--scope=repo", "--rule=PRR-LR-6"])
    check("8 repo scope: only past expiry", code == 2 and "assumptions.md:5" in txt and "assumptions.md:3" not in txt)
    code, txt = run(["--repo=" + d, "--feature=checkout-v2", "--rule=PRR-LR-6"])
    check("8 no ledger UNVERIFIED", code == 2 and "run assumption-ledger" in txt)
    # 9. stage ga -> silver target; a gold FAIL never moves a bronze verdict; a bronze FAIL caps the level
    d9 = mk(dict(ok, **{"ai/product/success/checkout-v2.md": SUCCESS_OK.replace("stage: beta", "stage: ga"), "ev.tsv": ev_ok}))
    code, txt = run(["--repo=" + d9, "--feature=checkout-v2", "--evidence=" + os.path.join(d9, "ev.tsv")])
    check("9 ga targets silver", "target=silver (stage ga)" in txt and code == 2)
    code, txt = run(["--repo=" + d, "--feature=checkout-v2", "--evidence=" + os.path.join(d, "ev.tsv"), "--target=bronze"])
    check("9 gold FAIL ignored at bronze", code == 0 and " FAIL " in rule_of(txt, "PRR-PERF-1"))
    ev9 = ev_ok.replace("PRR-SEC-1\tPASS", "PRR-SEC-1\tFAIL")
    d9b = mk(dict(ok, **{"ev.tsv": ev9}))
    code, txt = run(["--repo=" + d9b, "--feature=checkout-v2", "--evidence=" + os.path.join(d9b, "ev.tsv")])
    check("9 bronze FAIL caps level", code == 2 and "Level reached: none" in txt and "NOT-READY (1 failing)" in txt)
    # 10. runtime: load-test script present without a recorded run is UNVERIFIED; a recorded run PASSes
    d10 = mk(dict(ok, **{"load-tests/checkout.k6.js": "export default function () {}",
                         "ev.tsv": "PRR-PERF-1\tPASS\tRun\tquery:k6 at=2026-10-19T09:00Z p95=210ms\tbudget 300ms\n"}))
    code, txt = run(["--repo=" + d10, "--feature=checkout-v2", "--rule=PRR-PERF-1"])
    check("10 script without run UNVERIFIED", code == 2 and "needs load-test results" in txt)
    code, txt = run(["--repo=" + d10, "--feature=checkout-v2", "--rule=PRR-PERF-1", "--evidence=" + os.path.join(d10, "ev.tsv")])
    check("10 recorded run PASS", code == 0)
    # 11. repo scope: feature-only rules are N/A with a reason, never deleted
    code, txt = run(["--repo=" + d, "--scope=repo"])
    check("11 repo scope keeps feature rules as N/A", "a feature-scope rule" in rule_of(txt, "PRR-LR-1")
          and len([l for l in txt.split("\n") if l.startswith("PRR-")]) == 29)
    # 12. rules.json integrity: 29 rules, 7 / 14 / 8 per level, ids unique (validate_rules raises otherwise)
    spec = json.loads(read(DEFAULT_RULES))
    rs = validate_rules(spec)
    check("12 29 rules", len(rs) == 29)
    check("12 7/14/8 per level", [sum(1 for r in rs if r["level"] == lv) for lv in LEVELS] == [7, 14, 8])
    # 13. rollback record typing
    check("13 failed rollback", type_check("record", "staging 2026-10-12 rollback failed", datetime.date(2026, 10, 19)) is not None)
    check("13 record without env", type_check("record", "2026-10-12 ok", datetime.date(2026, 10, 19)) is not None)
    check("13 good record", type_check("record", "staging 2026-10-12T14:00Z reverted ok", datetime.date(2026, 10, 19)) is None)
    check("13 team handle", type_check("person", "@acme/growth", datetime.date(2026, 10, 19)) is not None)
    shutil.rmtree(base, ignore_errors=True)
    shutil.rmtree(out, ignore_errors=True)
    total = n_checks[0]
    if fails:
        print("self-test: %d failed: %s" % (len(fails), "; ".join(fails)))
        return 1
    print("self-test: all checks passed (%d)" % total)
    return 0


def main(argv):
    if argv == ["--self-test"]:
        return _self_test()
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 1 if not argv else 0
    try:
        return score(argv)
    except Usage as e:
        print("readiness-score: " + str(e), file=sys.stderr)
        return 1
    except json.JSONDecodeError as e:
        print("readiness-score: rules.json is not valid JSON: %s" % e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
