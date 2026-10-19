#!/usr/bin/env python3
"""refract_records.py — the records that make "the judge is not the builder" a fact, not a promise.

One module, imported by gate-check.py and run by four hooks and lock-acceptance.sh:

  persist-verdict   SubagentStop (verifier): extract the verdict JSON from the verifier's final
                    message, validate it (schema + the rules a schema cannot state), stamp the signer
                    from the hook input, the authors from the edit ledger and the scope fingerprint
                    from git, write ai/runs/<run_id>/verdict.json (or verdict-refute.json).
  persist-review    SubagentStop (any other agent): the same for a review lens's candidate findings
                    → ai/runs/<run_id>/reviews/<agent>-<lens>.json, with the posting bar enforced.
                    A refute-mode verdict also lands each REFUTED candidate in the review-dismissals
                    sink (ai/dynamic/review-dismissals.jsonl, append-only; review-dismissals.py reads it).
  guard             PreToolUse (test-lock.sh): deny edits to locked acceptance files and tests and to
                    hook-owned records; ask the human before a lock is reopened; keep the edit ledger.
  lock | reopen | check | status   lock-acceptance.sh's engine (.claude/locks/<run_id>.json).
  scope <run_id>    print the scope a record made now would carry (debugging staleness).
  validate <schema-name> <file>    validate a file against .claude/schemas/<schema-name>.schema.json.

Exit codes: 0 ok / allowed · 2 rejected (a hook's exit 2: Claude Code feeds stderr back to the agent)
            1 usage or environment error.

WHY STAMPED AND NOT CLAIMED. A model asked "who reviewed this, and was it this code?" answers what
it believes. The hook knows: Claude Code puts the subagent's agent_type in the hook input, git knows
the bytes. So identity and scope are written by this script and a model that writes them itself is
refused — an honest verifier never needs to.

HONEST LIMITS (named, so a green record is not read as more than it is):
  * Tool-path enforcement only. test-lock.sh stops Edit/Write/MultiEdit and recognisable Bash writes;
    a determined agent can still write bytes through a shell construct the guard does not parse.
    gate-check.py G0 re-hashes every locked file, so that write is DETECTED at Stop and in CI even
    when it was not prevented. Forging a lock or a record by hand is not detected — review
    .claude/locks/ like code (CODEOWNERS is the owner's call).
  * The edit ledger sees tool edits, not Bash edits; a scoped path the ledger never saw is
    attributed to `main` (the main session), which is the builder in every Phase-2 flow.
  * Scope is "every path this change touched", untracked files included locally. An untracked file
    judged locally but never committed reads as STALE in CI — the tree CI sees is not the tree that
    was judged, which is the truth, if a noisy one.
"""
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RUN_ID = re.compile(r"^([0-9]{8}-[a-z0-9][a-z0-9-]{0,60}-[0-9a-f]{4}|plan-[A-Za-z0-9][A-Za-z0-9-]{0,60})$")
EXCLUDED = ("ai/runs/", ".claude/evidence/", ".claude/locks/")
STAMPED = ("signer", "authors", "scope", "round", "escalate", "persisted_at")
JUDGES_DEFAULT = "verifier"
FORMATTER_FILES = (".prettierrc", ".prettierrc.json", ".prettierrc.js", ".prettierrc.cjs", ".prettierrc.yaml",
                   ".prettierrc.yml", "prettier.config.js", "prettier.config.cjs", "prettier.config.mjs",
                   "biome.json", "dprint.json", "rustfmt.toml", ".rustfmt.toml", ".clang-format",
                   ".php-cs-fixer.php", ".php-cs-fixer.dist.php", ".swiftformat", ".scalafmt.conf")
STYLE_CLASSES = {"formatting", "whitespace", "indentation", "import-order", "quotes", "semicolons",
                 "trailing-comma", "line-length", "brace-style"}


# ── small helpers ──────────────────────────────────────────────────────────────────────────────
def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, "-c", "core.quotepath=false"] + list(args),
                       capture_output=True, text=True, errors="replace", stdin=subprocess.DEVNULL)
    return r.stdout if r.returncode == 0 else None


def toplevel(start="."):
    out = git(os.path.abspath(start), "rev-parse", "--show-toplevel")
    return out.strip() if out else None


def agent_base(agent_type):
    """`my-plugin:verifier` and `verifier` are the same role."""
    return (agent_type or "").rsplit(":", 1)[-1]


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = "%s.tmp.%d" % (path, os.getpid())
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)


def evidence_dir(repo):
    d = os.path.join(repo, ".claude", "evidence")
    os.makedirs(d, exist_ok=True)
    gi = os.path.join(d, ".gitignore")
    if not os.path.exists(gi):
        with open(gi, "w") as fh:
            fh.write("# gate-check.py evidence: local records, never committed (see gate-check.py § EVIDENCE)\n*\n")
    return d


# ── schema validation: the subset the refract schemas use ──────────────────────────────────────
TYPES = {"object": dict, "array": list, "string": str, "boolean": bool, "integer": int,
         "number": (int, float), "null": type(None)}


def load_schema(name, repo=None):
    for base in filter(None, [os.path.join(repo, ".claude", "schemas") if repo else None,
                              os.path.join(HERE, "..", "schemas"),
                              os.path.join(HERE, "..", "..", "..", "schemas", "refract")]):
        p = os.path.join(base, name + ".schema.json")
        if os.path.isfile(p):
            with open(p, encoding="utf-8") as fh:
                return json.load(fh)
    raise FileNotFoundError("schema %s.schema.json is not installed in .claude/schemas/" % name)


def validate(value, schema, root=None, at="$", errs=None):
    """Errors as strings; [] means valid. Keywords: type enum const required properties
    additionalProperties items pattern minLength maxLength minItems maxItems minimum maximum
    oneOf $ref(#/$defs/...)."""
    root = root if root is not None else schema
    errs = [] if errs is None else errs
    if "$ref" in schema:
        name = schema["$ref"].rsplit("/", 1)[-1]
        return validate(value, root.get("$defs", {})[name], root, at, errs)
    if "oneOf" in schema:
        ok = sum(1 for s in schema["oneOf"] if not validate(value, s, root, at, []))
        if ok != 1:
            errs.append("%s: matches %d of the allowed shapes, not exactly one" % (at, ok))
        return errs
    ts = schema.get("type")
    if ts:
        allowed = [ts] if isinstance(ts, str) else ts
        if not any(isinstance(value, TYPES[t]) and not (t in ("integer", "number") and isinstance(value, bool))
                   for t in allowed):
            errs.append("%s: expected %s, got %s" % (at, "/".join(allowed), type(value).__name__))
            return errs
    if "const" in schema and value != schema["const"]:
        errs.append("%s: must be %r" % (at, schema["const"]))
    if "enum" in schema and value not in schema["enum"]:
        errs.append("%s: %r is not one of %s" % (at, value, ", ".join(map(str, schema["enum"]))))
    if isinstance(value, str):
        if "pattern" in schema and not re.search(schema["pattern"], value):
            errs.append("%s: %r does not match %s" % (at, value[:80], schema["pattern"]))
        if len(value) < schema.get("minLength", 0):
            errs.append("%s: shorter than %d characters" % (at, schema["minLength"]))
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            errs.append("%s: longer than %d characters" % (at, schema["maxLength"]))
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errs.append("%s: below %s" % (at, schema["minimum"]))
        if "maximum" in schema and value > schema["maximum"]:
            errs.append("%s: above %s" % (at, schema["maximum"]))
    if isinstance(value, dict):
        for k in schema.get("required", []):
            if k not in value:
                errs.append("%s: missing `%s`" % (at, k))
        props = schema.get("properties", {})
        for k, v in value.items():
            if k in props:
                validate(v, props[k], root, "%s.%s" % (at, k), errs)
            elif schema.get("additionalProperties") is False:
                errs.append("%s: unexpected key `%s`" % (at, k))
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            errs.append("%s: needs at least %d item(s)" % (at, schema["minItems"]))
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errs.append("%s: more than %d item(s)" % (at, schema["maxItems"]))
        if "items" in schema:
            for i, v in enumerate(value):
                validate(v, schema["items"], root, "%s[%d]" % (at, i), errs)
    return errs


# ── the change a record judged: scope + fingerprint ────────────────────────────────────────────
def resolve_base(repo, want=None):
    head = git(repo, "rev-parse", "--verify", "-q", "HEAD")
    if not head:
        return None
    cands = [want] if want else []
    if os.environ.get("REFRACT_BASE"):
        cands.insert(0, os.environ["REFRACT_BASE"])
    if os.environ.get("GITHUB_BASE_REF"):
        cands.append("origin/" + os.environ["GITHUB_BASE_REF"])
    cands += ["origin/HEAD", "origin/main", "origin/master", "main", "master"]
    for c in filter(None, cands):
        mb = git(repo, "merge-base", "HEAD", c)
        if mb and mb.strip():
            return mb.strip()
    return head.strip()


def touched(repo, base, ci=False):
    if not base:
        out = git(repo, "ls-files") or ""
        return sorted(set(filter(None, out.splitlines())))
    rng = [base, "HEAD"] if ci else [base]
    changed = (git(repo, "diff", "--name-only", "--no-renames", *rng) or "").splitlines()
    untracked = [] if ci else (git(repo, "ls-files", "-o", "--exclude-standard") or "").splitlines()
    return sorted(set(p for p in changed + untracked if p))


def blobs(repo, paths):
    present = [p for p in paths if os.path.isfile(os.path.join(repo, p))]
    hashed = {}
    if present:
        r = subprocess.run(["git", "-C", repo, "hash-object", "--stdin-paths"], input="\n".join(present) + "\n",
                           capture_output=True, text=True)
        if r.returncode == 0:
            hashed = dict(zip(present, r.stdout.split()))
    return [{"path": p, "blob": hashed.get(p, "deleted")} for p in paths]


def scope(repo, run_id, base=None, ci=False):
    base = base or resolve_base(repo)
    paths = [p for p in touched(repo, base, ci) if not p.startswith(EXCLUDED)]
    acc = "ai/runs/%s/acceptance.json" % run_id
    if os.path.isfile(os.path.join(repo, acc)):
        paths.append(acc)
    entries = blobs(repo, sorted(set(paths)))
    fp = hashlib.sha256("\n".join("%s\t%s" % (e["path"], e["blob"]) for e in entries).encode()).hexdigest()
    return {"base": base, "paths": entries, "fingerprint": fp}


def freshness(repo, record, ci=False, fallback_base=None):
    """(fresh, [difference ...]) — a record is fresh when the change it judged is the change now."""
    sc = record.get("scope") or {}
    base = sc.get("base")
    if not base or git(repo, "cat-file", "-e", base + "^{commit}") is None:   # base not in this clone
        base = fallback_base
    now_sc = scope(repo, record.get("run_id", ""), base, ci)
    if now_sc["fingerprint"] == sc.get("fingerprint"):
        return True, []
    was = {e["path"]: e["blob"] for e in sc.get("paths", [])}
    cur = {e["path"]: e["blob"] for e in now_sc["paths"]}
    diffs = ["changed after review: %s" % p for p in sorted(was) if p in cur and cur[p] != was[p]]
    diffs += ["touched after review: %s" % p for p in sorted(cur) if p not in was]
    diffs += ["judged but no longer in the change: %s" % p for p in sorted(was) if p not in cur]
    return False, diffs or ["fingerprint differs (base %s)" % (base or "?")[:12]]


# ── the edit ledger: who edited what ───────────────────────────────────────────────────────────
def ledger_append(repo, path, agent_type, agent_id, tool):
    try:
        with open(os.path.join(evidence_dir(repo), "edits.jsonl"), "a", encoding="utf-8") as fh:
            fh.write(json.dumps({"ts": now(), "path": path, "agent_type": agent_type or "main",
                                 "agent_id": agent_id, "tool": tool}) + "\n")
    except OSError:
        pass


def authors(repo, paths):
    seen, by_path = set(), {}
    p = os.path.join(repo, ".claude", "evidence", "edits.jsonl")
    if os.path.isfile(p):
        for line in open(p, encoding="utf-8", errors="replace"):
            try:
                e = json.loads(line)
            except ValueError:
                continue
            by_path.setdefault(e.get("path"), set()).add(e.get("agent_type") or "main")
    for path in paths:
        seen |= by_path.get(path, {"main"})
    return sorted(seen)


# ── reading an agent's final output ────────────────────────────────────────────────────────────
def output_text(hook, marker):
    """The text holding the record: last_assistant_message, else the agent transcript's last
    SubagentHandback message or assistant text carrying the marker (on Claude Code >= 2.1.271 a
    subagent may deliver its report through SubagentHandback, and last_assistant_message then holds
    only its closing words)."""
    msg = hook.get("last_assistant_message") or ""
    if marker in msg:
        return msg
    found = None
    tp = hook.get("agent_transcript_path")
    if tp:
        tp = os.path.expanduser(tp)
        if os.path.isfile(tp):
            for line in open(tp, encoding="utf-8", errors="replace"):
                if marker not in line:
                    continue
                try:
                    content = (json.loads(line).get("message") or {}).get("content")
                except ValueError:
                    continue
                for c in content if isinstance(content, list) else []:
                    if c.get("type") == "tool_use" and c.get("name") == "SubagentHandback":
                        t = (c.get("input") or {}).get("message") or ""
                    elif c.get("type") == "text":
                        t = c.get("text") or ""
                    else:
                        continue
                    if marker in t:
                        found = t
    return found or msg


def extract_json(text, marker):
    """The last JSON object in text that carries the schema marker: a fenced block, the whole text,
    or the outermost braces. -> (obj, error)"""
    blocks = re.findall(r"```(?:json)?[ \t]*\n(.*?)```", text, re.S)
    cands = [b for b in blocks if marker in b][::-1]
    if text.strip().startswith("{"):
        cands.append(text.strip())
    i, j = text.find("{"), text.rfind("}")
    if 0 <= i < j:
        cands.append(text[i:j + 1])
    last_err = "no JSON object carrying \"schema\": \"%s\" was found" % marker
    for c in cands:
        try:
            obj = json.loads(c)
        except ValueError as e:
            last_err = "the JSON does not parse: %s" % e
            continue
        if isinstance(obj, dict) and obj.get("schema") == marker:
            return obj, None
    return None, last_err


# ── verdict rules a schema cannot state ────────────────────────────────────────────────────────
def test_runs(repo):
    p = os.path.join(repo, ".claude", "evidence", "test-runs.jsonl")
    runs = []
    if os.path.isfile(p):
        for line in open(p, encoding="utf-8", errors="replace"):
            try:
                runs.append(json.loads(line))
            except ValueError:
                pass
    return runs


def derive(rec):
    if rec["mode"] == "acceptance":
        st = [c["status"] for c in rec.get("criteria", [])]
        return "FAIL" if "FAIL" in st else "CONCERNS" if "UNVERIFIED" in st else "PASS"
    f = rec.get("findings", [])
    if any(x["bucket"] == "confirmed" and x["severity"] == "IMPORTANT" for x in f):
        return "FAIL"
    if any(x["bucket"] == "unconfirmed" and x["severity"] == "IMPORTANT" for x in f):
        return "CONCERNS"
    return "PASS"


def verdict_rules(repo, rec):
    errs = []
    run_dir = os.path.join(repo, "ai", "runs", rec["run_id"])
    if rec["mode"] == "acceptance":
        crit = rec.get("criteria")
        if not crit:
            return ["acceptance mode: `criteria` must grade every criterion of the contract"]
        acc_path = os.path.join(run_dir, "acceptance.json")
        if os.path.isfile(acc_path):
            try:
                acc = json.load(open(acc_path, encoding="utf-8"))
            except ValueError as e:
                return ["ai/runs/%s/acceptance.json does not parse: %s" % (rec["run_id"], e)]
            want = [c.get("id") for c in acc.get("criteria", [])]
            got = [c["id"] for c in crit]
            missing = [i for i in want if i not in got]
            extra = [i for i in got if i not in want]
            dup = sorted({i for i in got if got.count(i) > 1})
            if missing:
                errs.append("criteria not graded: %s — every criterion of the locked contract gets a status" % ", ".join(missing))
            if extra:
                errs.append("criteria not in the contract: %s — grade the contract, do not extend it" % ", ".join(extra))
            if dup:
                errs.append("criteria graded twice: %s" % ", ".join(dup))
            kinds = {c.get("id"): c.get("kind") for c in acc.get("criteria", [])}
        elif not rec["run_id"].startswith("plan-"):
            return ["ai/runs/%s/acceptance.json does not exist — there is no contract to grade" % rec["run_id"]]
        else:
            kinds = {}
        runs = None
        for c in crit:
            if c["status"] == "PASS":
                if c.get("exit_code") != 0 or not c.get("command"):
                    errs.append("%s: PASS needs the command you ran at HEAD and its exit_code 0" % c["id"])
                if c.get("oracle") != "expresses-clause":
                    errs.append("%s: PASS needs oracle `expresses-clause` — a %s oracle does not prove the EARS clause"
                                % (c["id"], c.get("oracle")))
                if kinds.get(c["id"]) == "regression":
                    rr = c.get("red_run")
                    runs = test_runs(repo) if runs is None else runs
                    if not rr:
                        errs.append("%s: a regression criterion PASSes only with the red_run test-lane.sh recorded "
                                    "BEFORE the fix (.claude/evidence/test-runs.jsonl)" % c["id"])
                    elif rr.get("exit_code", 0) == 0 or not any(
                            r.get("ts") == rr.get("ts") and r.get("cmd") == rr.get("cmd")
                            and r.get("exit_code") == rr.get("exit_code") for r in runs):
                        errs.append("%s: red_run %s `%s` is not a non-zero record in .claude/evidence/test-runs.jsonl — "
                                    "cite the record verbatim" % (c["id"], rr.get("ts"), rr.get("cmd")))
    else:
        if "criteria" in rec and rec["criteria"]:
            errs.append("refute mode grades findings, not criteria")
        for f in rec.get("findings", []):
            b, fid = f["bucket"], f["id"]
            if b == "confirmed":
                if not f.get("file") or not f.get("line"):
                    errs.append("%s: a confirmed finding cites file and line" % fid)
                if not f.get("proof"):
                    errs.append("%s: a confirmed finding without proof is not kept — attach the failing test, probe, "
                                "measurement or two-ended trace, or move it to unconfirmed with its probe" % fid)
            elif b == "unconfirmed":
                if not f.get("probe") or not f.get("gate"):
                    errs.append("%s: an unconfirmed finding names the gate it could not pass and the probe that settles it" % fid)
            elif b == "refuted":
                if not f.get("gate") or not f.get("reason"):
                    errs.append("%s: a refuted candidate names the gate that failed and why" % fid)
    if not errs and rec["verdict"] != derive(rec):
        errs.append("verdict %s does not follow from the graded items — it is %s (FAIL on any failed criterion or "
                    "confirmed IMPORTANT finding; CONCERNS on anything unverified or unconfirmed IMPORTANT)"
                    % (rec["verdict"], derive(rec)))
    return errs


# ── review-dismissals sink (spec § 5.8 calibration; review-dismissals.py is its CLI) ─────────────
DISMISSALS = os.path.join("ai", "dynamic", "review-dismissals.jsonl")
DISMISS_REASONS = ("refuted", "accepted-risk", "false-positive")


def fingerprint(repo, kind, path, line):
    """Stable across runs while the flagged line is unchanged: class + path + the trimmed text of the
    line (whitespace collapsed); the line number only when the file cannot be read."""
    text = None
    try:
        with open(os.path.join(repo, path or ""), encoding="utf-8", errors="replace") as fh:
            for i, l in enumerate(fh, 1):
                if i == int(line or 0):
                    text = " ".join(l.split())
                    break
    except (OSError, ValueError, TypeError):
        pass
    key = "%s\0%s\0%s" % (kind or "", path or "", text if text is not None else "line:%s" % line)
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:16]


def review_finding(repo, run_id, ref):
    """`<reviews file>#F-n` (relative to the repo or to ai/runs/<run_id>/) -> (review record, finding)."""
    if not ref or "#" not in ref:
        return None, None
    path, fid = ref.rsplit("#", 1)
    for cand in (os.path.join(repo, path), os.path.join(repo, "ai", "runs", run_id, path)):
        if os.path.isfile(cand):
            try:
                rec = json.load(open(cand, encoding="utf-8"))
            except ValueError:
                return None, None
            for f in rec.get("findings", []):
                if f.get("id") == fid:
                    return rec, f
            return rec, None
    return None, None


def dismissal(repo, run_id, source, finding, reason, by, note, recorded_by, gate=None, lens=None):
    kind = finding.get("kind") or "unclassified/unclassified"
    return {"schema": "refract/dismissal/v1", "date": now()[:10], "ts": now(), "run_id": run_id,
            "source": source, "lens": lens or kind.split("/", 1)[0], "class": kind,
            "detector": finding.get("detector"), "severity": finding.get("severity"),
            "file": finding.get("file"), "line": finding.get("line"),
            "fingerprint": fingerprint(repo, kind, finding.get("file"), finding.get("line")),
            "reason": reason, "gate": gate, "note": note, "by": by, "recorded_by": recorded_by}


def read_dismissals(repo):
    p = os.path.join(repo, DISMISSALS)
    out = []
    if os.path.isfile(p):
        for l in open(p, encoding="utf-8", errors="replace"):
            try:
                d = json.loads(l)
            except ValueError:
                continue
            if isinstance(d, dict) and d.get("schema") == "refract/dismissal/v1":
                out.append(d)
    return out


def append_dismissals(repo, recs):
    """Append-only; a (run, fingerprint, reason) already in the sink is not written twice. -> count"""
    seen = {(d.get("run_id"), d.get("fingerprint"), d.get("reason")) for d in read_dismissals(repo)}
    new = []
    for r in recs:
        k = (r["run_id"], r["fingerprint"], r["reason"])
        if k not in seen:
            seen.add(k)
            new.append(r)
    if new:
        p = os.path.join(repo, DISMISSALS)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "a", encoding="utf-8") as fh:
            for r in new:
                fh.write(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n")
    return len(new)


def refuted_dismissals(repo, verdict):
    """Every refuted candidate of a refute-mode verdict as a dismissal record (reason `refuted`)."""
    recs = []
    for f in verdict.get("findings", []):
        if f.get("bucket") != "refuted":
            continue
        rev, rf = review_finding(repo, verdict["run_id"], f.get("id"))
        src = rf or {"file": f.get("file"), "line": f.get("line"), "severity": f.get("severity")}
        recs.append(dismissal(repo, verdict["run_id"], f.get("id"), src, "refuted",
                              (verdict.get("signer") or {}).get("agent_type") or "verifier", f.get("reason"),
                              "persist-verdict.sh", gate=f.get("gate"), lens=(rev or {}).get("lens")))
    return recs


# ── persist (SubagentStop) ─────────────────────────────────────────────────────────────────────
HYPOTHESES = "refract/hypotheses/v1"


def persist_hypotheses(hook, repo):
    """An investigator instance's hypothesis record (/investigate-incident) -> MERGED by id into
    ai/runs/<run_id>/reviews/hypotheses.json. A supported hypothesis must cite supporting evidence and
    the line its cause lives on; a refuted one must cite contradicting evidence."""
    rec, err = extract_json(output_text(hook, HYPOTHESES), HYPOTHESES)
    if err:
        return reject([err])
    claimed = [k for k in STAMPED if k in rec]
    if claimed:
        return reject(["remove %s — the hook stamps who signed, who authored and what was judged" % ", ".join(claimed)])
    errs = validate(rec, load_schema("hypotheses", repo))
    if errs:
        return reject(errs)
    for h in rec["hypotheses"]:
        if h["verdict"] == "supported" and (not h["supporting"] or "root_cause" not in h):
            errs.append("%s is `supported` with no supporting evidence or no root_cause {file, line, claim}" % h["id"])
        if h["verdict"] == "refuted" and not h["contradicting"]:
            errs.append("%s is `refuted` with no contradicting evidence" % h["id"])
    if errs:
        return reject(errs)
    run_dir = os.path.join(repo, "ai", "runs", rec["run_id"])
    if not os.path.isdir(run_dir):
        return reject(["run %s has no ai/runs/%s/ — use the run_id your brief named" % (rec["run_id"], rec["run_id"])])
    out = os.path.join(run_dir, "reviews", "hypotheses.json")
    merged = {}
    if os.path.isfile(out):
        try:
            prev = json.load(open(out, encoding="utf-8"))
        except ValueError:
            prev = {}
        if prev.get("incident") == rec["incident"]:
            merged = dict((h.get("id"), h) for h in prev.get("hypotheses", []))
    rec = stamp(repo, rec, hook, "persist-review.sh")
    for h in rec["hypotheses"]:
        merged[h["id"]] = h
    rec["hypotheses"] = [merged[k] for k in sorted(merged, key=lambda i: int(i.split("-")[1]))]
    write_json(out, rec)
    return 0


def reject(lines):
    print("Not persisted — fix and end again with the corrected JSON:", file=sys.stderr)
    for l in lines[:12]:
        print("  - " + l, file=sys.stderr)
    return 2


def stamp(repo, rec, hook, who):
    sc = scope(repo, rec["run_id"])
    rec["signer"] = {"agent_type": hook.get("agent_type") or "", "agent_id": hook.get("agent_id"),
                     "stamped_by": who, "ts": now(), "transcript": hook.get("agent_transcript_path")}
    rec["authors"] = authors(repo, [e["path"] for e in sc["paths"]])
    rec["scope"] = sc
    rec["persisted_at"] = rec["signer"]["ts"]
    return rec


def persist(kind, hook, repo):
    is_verdict = kind == "verdict"
    agent = agent_base(hook.get("agent_type"))
    judges = set(filter(None, os.environ.get("REFRACT_JUDGE_AGENTS", JUDGES_DEFAULT).split(",")))
    if is_verdict and agent not in judges:
        return 0
    if not is_verdict and (not agent or agent in judges):
        return 0
    if not is_verdict and HYPOTHESES in output_text(hook, HYPOTHESES):
        return persist_hypotheses(hook, repo)
    marker = "refract/verdict/v1" if is_verdict else "refract/findings/v1"
    text = output_text(hook, marker)
    if marker not in text:
        if is_verdict:
            return reject(["your final message carries no verdict JSON — end with one object whose \"schema\" is "
                           "\"refract/verdict/v1\" (.claude/agents/verifier.md § Output)"])
        return 0                                                    # not a typed reviewer: nothing to persist
    rec, err = extract_json(text, marker)
    if err:
        return reject([err])
    claimed = [k for k in STAMPED if k in rec]
    if claimed:
        return reject(["remove %s — the hook stamps who signed, who authored and what was judged; a record never "
                       "claims them" % ", ".join(claimed)])
    schema = load_schema("verdict" if is_verdict else "findings", repo)
    errs = validate(rec, schema)
    if errs:
        return reject(errs)
    run_dir = os.path.join(repo, "ai", "runs", rec["run_id"])
    if not os.path.isdir(run_dir):
        if rec["run_id"].startswith("plan-"):
            os.makedirs(run_dir, exist_ok=True)
        else:
            return reject(["run %s has no ai/runs/%s/ — use the run_id your brief named" % (rec["run_id"], rec["run_id"])])
    if is_verdict:
        errs = verdict_rules(repo, rec)
        if errs:
            return reject(errs)
        rec = stamp(repo, rec, hook, "persist-verdict.sh")
        if agent in [agent_base(a) for a in rec["authors"]]:
            return reject(["the signer `%s` edited a path in scope — a judge that edits is a builder; the verdict "
                           "cannot be signed by it" % agent])
        name = "verdict.json" if rec["mode"] == "acceptance" else "verdict-refute.json"
        write_json(os.path.join(run_dir, name), rec)
        if rec["mode"] == "refute":
            try:
                append_dismissals(repo, refuted_dismissals(repo, rec))
            except (OSError, ValueError) as e:                       # the verdict stands; the sink is advisory
                print("persist-verdict: review-dismissals sink not written: %s" % e, file=sys.stderr)
        return 0
    # review: the posting bar (templates/snippets/posting-bar.md)
    safe_agent = re.sub(r"[^a-z0-9-]", "-", agent.lower())
    out = os.path.join(run_dir, "reviews", "%s-%s.json" % (safe_agent, rec["lens"]))
    prev_round = 0
    if os.path.isfile(out):
        try:
            prev_round = int(json.load(open(out, encoding="utf-8")).get("round") or 1)
        except (ValueError, TypeError):
            prev_round = 1
    rnd = prev_round + 1
    nits = [f for f in rec["findings"] if f["severity"] == "NIT"]
    errs = []
    if len(nits) > 5:
        errs.append("%d NIT findings — the posting bar caps nits at 5; keep the five that matter most" % len(nits))
    if rnd >= 2 and nits:
        errs.append("round %d: after round 1 the posting bar admits IMPORTANT findings only — drop the %d NIT(s)"
                    % (rnd, len(nits)))
    fmt = any(os.path.exists(os.path.join(repo, f)) for f in FORMATTER_FILES) or (
        os.path.isfile(os.path.join(repo, "package.json")) and '"prettier"' in open(os.path.join(repo, "package.json"),
                                                                                      errors="replace").read())
    style = [f["id"] for f in rec["findings"] if f["kind"].split("/", 1)[-1] in STYLE_CLASSES]
    if fmt and style:
        errs.append("%s: a formatter is configured here — style is the formatter's, never a review comment" % ", ".join(style))
    no_claim = [f["id"] for f in rec["findings"] if not re.search(r"\b(when|if|under|on)\b", f["claim"], re.I)]
    if no_claim:
        errs.append("%s: restate each claim as `When <condition>, <code at file:line> produces <wrong outcome> "
                    "instead of <expected>`" % ", ".join(no_claim[:5]))
    if errs:
        return reject(errs)
    rec = stamp(repo, rec, hook, "persist-review.sh")
    rec["round"] = rnd
    rec["escalate"] = bool(rnd >= 3 and any(f["severity"] == "IMPORTANT" for f in rec["findings"]))
    write_json(out, rec)
    if rec["escalate"]:
        print(json.dumps({"systemMessage": "review %s/%s reached round %d with IMPORTANT findings still open — "
                          "escalate to a human as an upstream problem (posting bar § Rounds)" % (agent, rec["lens"], rnd)}))
    return 0


# ── locks ──────────────────────────────────────────────────────────────────────────────────────
def lock_path(repo, run_id):
    return os.path.join(repo, ".claude", "locks", run_id + ".json")


def load_lock(repo, run_id):
    p = lock_path(repo, run_id)
    return json.load(open(p, encoding="utf-8")) if os.path.isfile(p) else None


def all_locks(repo):
    d = os.path.join(repo, ".claude", "locks")
    out = []
    if os.path.isdir(d):
        for n in sorted(os.listdir(d)):
            if n.endswith(".json"):
                try:
                    out.append(json.load(open(os.path.join(d, n), encoding="utf-8")))
                except ValueError:
                    pass
    return out


def locked_paths(lock):
    return [lock["acceptance"]["path"]] + [t["path"] for t in lock.get("tests", [])]


def lock_hashes(repo, run_id):
    acc_rel = "ai/runs/%s/acceptance.json" % run_id
    acc_abs = os.path.join(repo, acc_rel)
    if not os.path.isfile(acc_abs):
        return None, ["%s does not exist — write the contract first" % acc_rel]
    try:
        acc = json.load(open(acc_abs, encoding="utf-8"))
    except ValueError as e:
        return None, ["%s does not parse: %s" % (acc_rel, e)]
    errs = validate(acc, load_schema("acceptance", repo))
    if not errs and acc.get("run_id") != run_id:
        errs.append("%s says run_id %s" % (acc_rel, acc.get("run_id")))
    tests = sorted({t["path"] for c in acc.get("criteria", []) for t in c.get("tests", [])})
    missing = [t for t in tests if not os.path.isfile(os.path.join(repo, t))]
    if missing:
        errs.append("test file(s) not written yet: %s — the acceptance tests exist (and fail) before the lock"
                    % ", ".join(missing))
    if errs:
        return None, errs
    return {"acceptance": {"path": acc_rel, "sha256": sha256_file(acc_abs)},
            "tests": [{"path": t, "sha256": sha256_file(os.path.join(repo, t))} for t in tests]}, []


def lock_diffs(repo, lock):
    out = []
    for e in [lock["acceptance"]] + lock.get("tests", []):
        p = os.path.join(repo, e["path"])
        if not os.path.isfile(p):
            out.append("%s: deleted" % e["path"])
        elif sha256_file(p) != e["sha256"]:
            out.append("%s: content differs from the lock" % e["path"])
    return out


def cmd_lock(repo, run_id):
    if not RUN_ID.match(run_id or ""):
        print("lock-acceptance: %r is not a run id (<YYYYMMDD>-<slug>-<4hex>)" % run_id, file=sys.stderr)
        return 1
    h, errs = lock_hashes(repo, run_id)
    if errs:
        print("lock-acceptance: not locked —", file=sys.stderr)
        for e in errs[:10]:
            print("  - " + e, file=sys.stderr)
        return 1
    cur = load_lock(repo, run_id)
    if cur and cur.get("state") == "locked":
        if cur["acceptance"] == h["acceptance"] and cur.get("tests") == h["tests"]:
            print("lock-acceptance: %s already locked, unchanged (%d test file(s))" % (run_id, len(h["tests"])))
            return 0
        print("lock-acceptance: %s is locked and its content changed:" % run_id, file=sys.stderr)
        for d in lock_diffs(repo, cur) or ["the set of locked tests changed"]:
            print("  - " + d, file=sys.stderr)
        print("A locked contract changes only through a human: lock-acceptance.sh --reopen %s --reason='…', "
              "then the editor it names changes it, then lock-acceptance.sh %s re-seals." % (run_id, run_id), file=sys.stderr)
        return 1
    event = "relock" if cur else "lock"
    lock = {"schema": "refract/lock/v1", "run_id": run_id, "state": "locked", "editor": None,
            "acceptance": h["acceptance"], "tests": h["tests"],
            "history": (cur or {}).get("history", []) + [{"event": event, "at": now()}]}
    write_json(lock_path(repo, run_id), lock)
    print("lock-acceptance: %s %sed — acceptance.json + %d test file(s); edits to them are now denied (test-lock.sh)"
          % (run_id, event, len(h["tests"])))
    return 0


def cmd_reopen(repo, run_id, reason, editor):
    cur = load_lock(repo, run_id)
    if not cur:
        print("lock-acceptance: %s has no lock to reopen" % run_id, file=sys.stderr)
        return 1
    if not (reason or "").strip():
        print("lock-acceptance: --reopen needs --reason='<why the contract must change>'", file=sys.stderr)
        return 1
    cur["state"], cur["editor"] = "reopened", editor or "test-engineer"
    cur.setdefault("history", []).append({"event": "reopen", "at": now(), "reason": reason, "editor": cur["editor"]})
    write_json(lock_path(repo, run_id), cur)
    print("lock-acceptance: %s reopened for `%s` — re-seal with lock-acceptance.sh %s when the change is made"
          % (run_id, cur["editor"], run_id))
    return 0


def cmd_check(repo, run_id):
    cur = load_lock(repo, run_id)
    if not cur:
        print("lock-acceptance: %s is not locked" % run_id, file=sys.stderr)
        return 1
    d = lock_diffs(repo, cur)
    if cur.get("state") != "locked":
        d.insert(0, "the lock is %s (editor %s) and was never re-sealed" % (cur.get("state"), cur.get("editor")))
    for x in d:
        print("  - " + x, file=sys.stderr)
    if not d:
        print("lock-acceptance: %s intact — acceptance.json + %d test file(s) match the lock" % (run_id, len(cur.get("tests", []))))
    return 1 if d else 0


# ── guard (test-lock.sh) ───────────────────────────────────────────────────────────────────────
HOOK_OWNED = re.compile(r"^(\.claude/locks/|\.claude/evidence/|ai/runs/[^/]+/verdict[^/]*\.json$|ai/runs/[^/]+/reviews/"
                        r"|ai/dynamic/review-dismissals\.jsonl$)")
WRITE_SHAPE = re.compile(
    r"(^|[^0-9&<>])>{1,2}\s*[^\s&>]|\btee\b|\bsed\s+(-[a-zA-Z]*i|--in-place)|\bperl\s+-[a-zA-Z]*i|\b(rm|mv|cp|truncate|dd|install|ln|touch|chmod)\s"
    r"|\bgit\s+(checkout|restore|rm|mv|stash|apply|reset|clean|am|cherry-pick)\b|\bpatch\b|\b(python3?|node|ruby|perl|php|deno|bun)\s+-[ce]\b")


def deny(msg):
    print(msg, file=sys.stderr)
    return 2


def guard(hook, repo):
    tool = hook.get("tool_name") or ""
    ti = hook.get("tool_input") or {}
    agent_type = hook.get("agent_type") or ""
    locks = all_locks(repo)
    if tool == "Bash":
        cmd = ti.get("command") or ""
        if re.search(r"(lock-acceptance\.sh|refract_records\.py)\b.*\b(--reopen|reopen)\b", cmd):
            if hook.get("permission_mode") in ("bypassPermissions", "dontAsk"):
                return deny("Blocked by test-lock: reopening a locked acceptance contract needs a human, and this "
                            "session runs with permission prompts off. Report SPEC_CONFLICT with the criterion and the "
                            "evidence; the owner runs `.claude/scripts/lock-acceptance.sh --reopen <run> --reason=…` "
                            "in a terminal.")
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse", "permissionDecision": "ask",
                "permissionDecisionReason": "test-lock: this REOPENS a locked acceptance contract so its criteria or "
                "tests can change. Approve only if you agree the contract itself is wrong (a SPEC_CONFLICT), not "
                "because the code fails it."}}))
            return 0
        if re.search(r"review-dismissals\.py\b.*\bdismiss\b", cmd):
            if hook.get("permission_mode") in ("bypassPermissions", "dontAsk"):
                return deny("Blocked by test-lock: dismissing a review finding as accepted-risk or false-positive "
                            "is a human's call, and this session runs with permission prompts off. List the finding "
                            "and why; the owner runs `.claude/scripts/review-dismissals.py dismiss …` in a terminal.")
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse", "permissionDecision": "ask",
                "permissionDecisionReason": "test-lock: this DISMISSES a review finding (accepted-risk / "
                "false-positive) into ai/dynamic/review-dismissals.jsonl, which later demotes the detector that "
                "raised it. Approve only if you, not the builder, judge the finding wrong or the risk accepted."}}))
            return 0
        protected = [p for l in locks if l.get("state") == "locked" for p in locked_paths(l)]
        hits = [p for p in protected if p in cmd or (os.path.basename(p) in cmd and "/" not in os.path.basename(p)
                                                      and len(os.path.basename(p)) > 6)]
        owned = re.search(r"\.claude/locks/|\.claude/evidence/(edits|test-runs)\.jsonl|ai/runs/[^ ]+/(verdict[^ ]*\.json|reviews/)"
                          r"|ai/dynamic/review-dismissals\.jsonl", cmd)
        if (hits or owned) and WRITE_SHAPE.search(cmd):
            what = ", ".join(hits[:4]) if hits else owned.group(0)
            return deny("Blocked by test-lock: this command can write %s, which is %s. Locked acceptance tests and "
                        "hook-written records change only through their owner. If the contract is wrong, stop and "
                        "report SPEC_CONFLICT (criterion, the conflicting requirement, the evidence) instead of "
                        "changing the test. Read-only commands on these files are fine without a redirect."
                        % (what, "locked by .claude/locks/" if hits else "written only by Refract's hooks"))
        return 0
    path = ti.get("file_path") or ti.get("notebook_path") or ""
    if not path:
        return 0
    ab = os.path.abspath(os.path.join(repo, path) if not os.path.isabs(path) else path)
    real_repo = os.path.realpath(repo)
    real = os.path.realpath(ab)
    if not (real == real_repo or real.startswith(real_repo + os.sep)):
        return 0
    rel = os.path.relpath(real, real_repo)
    if HOOK_OWNED.match(rel):
        return deny("Blocked by test-lock: %s is written only by Refract's hooks and scripts (locks, evidence, "
                    "verdicts, persisted reviews). A record a model writes about itself is not evidence." % rel)
    for l in locks:
        if rel in locked_paths(l):
            editor = l.get("editor") or "test-engineer"
            mine = agent_base(agent_type) or "main"
            if l.get("state") == "reopened" and mine == editor:
                ledger_append(repo, rel, agent_type, hook.get("agent_id"), tool)
                return 0
            why = ("the lock is reopened for `%s`, not `%s`" % (editor, mine)) if l.get("state") == "reopened" \
                else "it is part of the locked acceptance contract of run %s" % l.get("run_id")
            return deny("Blocked by test-lock: %s — %s. The builder never edits the tests that judge it. If the "
                        "criterion contradicts the requirement, STOP and report SPEC_CONFLICT: the criterion id, the "
                        "requirement it contradicts, and the evidence. A human reopens the contract "
                        "(lock-acceptance.sh --reopen %s --reason=…); then `%s` edits and re-seals it."
                        % (rel, why, l.get("run_id"), editor))
    ledger_append(repo, rel, agent_type, hook.get("agent_id"), tool)
    return 0


# ── CLI ────────────────────────────────────────────────────────────────────────────────────────
def main(argv):
    if not argv:
        print(__doc__.split("\n\n")[0], file=sys.stderr)
        return 1
    cmd, rest = argv[0], argv[1:]
    opts = dict(a[2:].split("=", 1) for a in rest if a.startswith("--") and "=" in a)
    pos = [a for a in rest if not a.startswith("--")]
    repo = toplevel(opts.get("repo", "."))
    if not repo:
        print("refract_records: not inside a git work tree", file=sys.stderr)
        return 1 if cmd not in ("guard", "persist-verdict", "persist-review") else 0
    if cmd in ("persist-verdict", "persist-review", "guard"):
        try:
            hook = json.loads(sys.stdin.read() or "{}")
        except ValueError:
            return 0
        if cmd == "guard":
            return guard(hook, repo)
        return persist(cmd.split("-", 1)[1], hook, repo)
    if cmd == "lock" and pos:
        return cmd_lock(repo, pos[0])
    if cmd == "reopen" and pos:
        return cmd_reopen(repo, pos[0], opts.get("reason"), opts.get("editor"))
    if cmd == "check" and pos:
        return cmd_check(repo, pos[0])
    if cmd == "status" and pos:
        l = load_lock(repo, pos[0])
        print(json.dumps(l, indent=2) if l else "%s: not locked" % pos[0])
        return 0
    if cmd == "scope" and pos:
        print(json.dumps(scope(repo, pos[0]), indent=2))
        return 0
    if cmd == "validate" and len(pos) == 2:
        errs = validate(json.load(open(pos[1], encoding="utf-8")), load_schema(pos[0], repo))
        for e in errs:
            print(e)
        return 2 if errs else 0
    print("refract_records: unknown or incomplete command: %s" % " ".join(argv), file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
