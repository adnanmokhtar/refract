#!/usr/bin/env python3
"""ears-lint.py — every acceptance criterion is an EARS sentence a test can be written against.

Usage:  ears-lint.py <requirements.md> [--acceptance=<acceptance.json>] [--json]
        ears-lint.py --self-test
Exit:   0 clean · 2 findings · 1 usage error (file missing, unreadable JSON)

WHY. A criterion like "the refund should work properly" cannot fail: there is no trigger, no system
and no observable response, so any implementation passes it and the verifier grades a feeling. EARS
(Easy Approach to Requirements Syntax) forces the three parts a test needs — when, who, what is
observed — and the IF-THEN shape forces at least one failure path per story, the case a happy-path
build never writes. P1's exit (tiers.json, proposal §4.2) is this script green.

FORMAT (templates/snippets/run-ledger.md § Formats):
  ### REQ-001 — <title>                 a story; it owns the criteria below it until the next heading
  - AC-001: <EARS sentence>             a criterion (one line)
SHAPES, keywords case-insensitive (EARS writes them in capitals; the shape reported uses capitals):
  ubiquitous          THE <system> SHALL <response>
  event-driven        WHEN <trigger>[,] THE <system> SHALL <response>
  state-driven        WHILE <state>[,] THE <system> SHALL <response>
  optional-feature    WHERE <feature>[,] THE <system> SHALL <response>
  unwanted-behaviour  IF <condition>[,] THEN THE <system> SHALL <response>
  complex             any ordered mix, e.g. WHILE <state>, WHEN <trigger>, THE <system> SHALL …
                      (an IF clause, when present, is the last one — its THEN leads into THE).

FINDINGS: a criterion that is not EARS; a story with no IF-THEN criterion; a vague word inside the
SHALL clause (fast, quickly, properly, user-friendly, and/or, as expected, …); a SHALL clause with
fewer than three words (nothing observable); duplicate REQ or AC ids; an AC under no story; a story
with no criteria. With --acceptance: every criteria[].ears passes the shape check, and every
criteria[].id exists in requirements.md.

HONEST LIMITS:
  * Shape, not meaning: "WHEN pigs fly THE app SHALL return 200 for every request" is EARS. The
    requirements-reviewer judges whether the sentence is the right requirement.
  * One line per criterion; a criterion wrapped onto a second line is read up to the line break.
  * The main `THE <system>` is the last capitalised THE before SHALL, else the last `the` — a system
    name that itself contains "the" in lower case may be split in the wrong place.
  * A lower-case when/while/where/if inside a clause starts a new clause only after a comma.
"""
import json
import os
import re
import sys

STORY = re.compile(r"^#{3}\s+(REQ-\d{3,})\b\s*[—–:-]*\s*(.*)$")
HEADING = re.compile(r"^#{1,6}\s")
CRIT = re.compile(r"^\s*[-*]\s+(?:\*\*)?(AC-\d{3,})(?:\*\*)?\s*:\s*(.+?)\s*$")
VAGUE = ["fast", "faster", "quick", "quickly", "user-friendly", "user friendly", "intuitive", "intuitively",
         "properly", "correctly", "appropriately", "appropriate", "gracefully", "efficiently", "easily", "easy",
         "seamless", "seamlessly", "robust", "robustly", "reasonable", "reasonably", "adequate", "adequately",
         "sufficient", "sufficiently", "optimal", "optimally", "as needed", "as appropriate", "as expected",
         "as well as", "and/or", "etc", "if possible", "where possible", "nice", "better", "good",
         "smooth", "smoothly", "flexible"]
VAGUE_RE = re.compile(r"(?<![\w-])(" + "|".join(re.escape(v) for v in sorted(VAGUE, key=len, reverse=True)) + r")(?![\w-])", re.I)
KW = re.compile(r"\b(while|when|where|if)\b", re.I)
SHAPE_NAME = {"WHEN": "event-driven", "WHILE": "state-driven", "WHERE": "optional-feature", "IF": "unwanted-behaviour"}


def shape(sentence):
    """-> (shape name, response, [problems]). shape is None when the sentence is not EARS."""
    s = sentence.strip().rstrip(".").strip()
    m = re.search(r"\bSHALL\b", s) or re.search(r"\bshall\b", s, re.I)
    if not m:
        return None, "", ["not EARS — no SHALL"]
    head, resp = s[:m.start()], s[m.end():].strip()
    thes = [x for x in re.finditer(r"\bTHE\b", head)] or [x for x in re.finditer(r"\bthe\b", head, re.I)]
    if not thes:
        return None, resp, ["not EARS — no `THE <system>` before SHALL"]
    the = thes[-1]
    system = head[the.end():].strip()
    prefix = head[:the.start()].strip()
    if not system:
        return None, resp, ["not EARS — no system named between THE and SHALL"]
    kws = []
    if prefix:
        cands = []
        for k in KW.finditer(prefix):
            before = prefix[:k.start()].rstrip()
            if k.start() == 0 or before.endswith(",") or k.group(1).isupper():
                cands.append(k)
        if not cands or cands[0].start() != 0:
            return None, resp, ["not EARS — `%s…` does not open with WHEN / WHILE / WHERE / IF" % prefix[:30]]
        for i, k in enumerate(cands):
            end = cands[i + 1].start() if i + 1 < len(cands) else len(prefix)
            body = prefix[k.end():end].strip().rstrip(",").strip()
            kw = k.group(1).upper()
            if kw == "IF":
                if i + 1 != len(cands):
                    return None, resp, ["not EARS — the IF … THEN clause must come last, right before THE <system>"]
                tm = re.search(r",?\s*\bthen\s*$", body, re.I)
                if not tm:
                    return None, resp, ["not EARS — IF without THEN before THE <system>"]
                body = body[:tm.start()].strip()
            elif re.search(r"\bthen\s*$", body, re.I):
                return None, resp, ["not EARS — THEN without IF"]
            if not body:
                return None, resp, ["not EARS — empty %s clause" % kw]
            kws.append(kw)
    if not kws:
        name = "ubiquitous"
    elif len(kws) == 1:
        name = SHAPE_NAME[kws[0]]
    else:
        name = "complex (%s)" % "+".join(kws)
    return name, resp, []


def response_problems(resp):
    out = []
    if len(re.findall(r"[\w'/%-]+", resp)) < 3:
        out.append("SHALL clause has no observable object (`SHALL %s` — name what is returned, recorded or shown)" % resp)
    vague = sorted({v.group(1).lower() for v in VAGUE_RE.finditer(resp)})
    if vague:
        out.append("vague word in the SHALL clause: %s — replace it with a measurable response" % ", ".join(vague))
    return out


def lint(path, acc_path=None):
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    findings, stories, crits, shapes = [], [], [], {}
    seen_req, seen_ac = {}, {}
    cur = None

    def f(line, ident, problem, where=None):
        findings.append({"file": where or path, "line": line, "id": ident, "problem": problem})

    in_fence = False
    for n, line in enumerate(lines, 1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        sm = STORY.match(line)
        if sm:
            rid = sm.group(1)
            if rid in seen_req:
                f(n, rid, "duplicate story id (first at line %d)" % seen_req[rid])
            seen_req.setdefault(rid, n)
            cur = {"id": rid, "line": n, "criteria": [], "if_then": False}
            stories.append(cur)
            continue
        if HEADING.match(line):
            cur = None
            continue
        cm = CRIT.match(line)
        if not cm:
            continue
        aid, text = cm.group(1), cm.group(2)
        crits.append(aid)
        if aid in seen_ac:
            f(n, aid, "duplicate criterion id (first at line %d)" % seen_ac[aid])
        seen_ac.setdefault(aid, n)
        if cur is None:
            f(n, aid, "criterion under no story — put it below its `### REQ-### — title` heading")
        else:
            cur["criteria"].append(aid)
        name, resp, probs = shape(text)
        shapes[aid] = name
        for p in probs:
            f(n, aid, p)
        if name:
            for p in response_problems(resp):
                f(n, aid, p)
            if cur is not None and ("unwanted" in name or "IF" in name):
                cur["if_then"] = True
    for st in stories:
        if not st["criteria"]:
            f(st["line"], st["id"], "story has no criteria (`- AC-###: <EARS sentence>` lines)")
        elif not st["if_then"]:
            f(st["line"], st["id"], "story has no IF … THEN criterion — every story names at least one failure path")
    if acc_path:
        with open(acc_path, encoding="utf-8") as fh:
            acc = json.load(fh)
        for c in acc.get("criteria", []) if isinstance(acc, dict) else []:
            cid = c.get("id") or "?"
            if cid not in seen_ac:
                f(0, cid, "in acceptance.json but not in %s" % os.path.basename(path), acc_path)
            ears = c.get("ears") or ""
            name, resp, probs = shape(ears)
            for p in probs:
                f(0, cid, "criteria[].ears: " + p, acc_path)
            if name:
                for p in response_problems(resp):
                    f(0, cid, "criteria[].ears: " + p, acc_path)
    return {"schema": "refract/ears-lint/v1", "stories": len(stories), "criteria": len(crits),
            "shapes": shapes, "findings": findings}


SAMPLE_OK = """### REQ-001 — Refund a paid order
As a support agent, I want to refund a paid order, so that the customer gets their money back.
- AC-001: WHEN an agent submits a refund for a paid order THE refunds API SHALL record exactly one refund for the order total.
- AC-002: IF the order belongs to another tenant THEN THE refunds API SHALL return 403 and record no refund.
- AC-003: WHILE a refund is pending, WHEN the agent submits again, THE refunds API SHALL return 409 with the pending refund id.
"""


def self_test():
    import tempfile
    fails = []
    cases = [("THE orders list SHALL show the order date in ISO format", "ubiquitous"),
             ("WHEN a user saves, THE notes API SHALL persist the note body", "event-driven"),
             ("IF the token is expired, THEN THE API SHALL return 401 with no body", "unwanted-behaviour"),
             ("WHILE offline, WHEN the user saves, THE app SHALL queue the note locally", "complex (WHILE+WHEN)"),
             ("The refund should work properly", None), ("WHEN x the API returns 200", None),
             ("IF the card is declined THE API SHALL return 402 and no charge", None)]
    for s, want in cases:
        got = shape(s)[0]
        if got != want:
            fails.append("%r → %s, want %s" % (s, got, want))
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as fh:
        fh.write(SAMPLE_OK)
    try:
        r = lint(fh.name)
        if r["findings"]:
            fails.append("clean sample has findings: %s" % r["findings"])
    finally:
        os.unlink(fh.name)
    for x in fails:
        print("FAIL " + x)
    print("ears-lint self-test: %d case(s), %d failure(s)" % (len(cases) + 1, len(fails)))
    return 1 if fails else 0


def main(argv):
    opts = dict(a[2:].partition("=")[::2] for a in argv if a.startswith("--"))
    pos = [a for a in argv if not a.startswith("--")]
    if "self-test" in opts:
        return self_test()
    if len(pos) != 1:
        print(__doc__.split("\n\n")[0] + "\n" + __doc__.split("\n\n")[1], file=sys.stderr)
        return 1
    try:
        res = lint(pos[0], opts.get("acceptance") or None)
    except OSError as e:
        print("ears-lint: %s" % e, file=sys.stderr)
        return 1
    except ValueError as e:
        print("ears-lint: acceptance.json does not parse: %s" % e, file=sys.stderr)
        return 1
    if "json" in opts:
        print(json.dumps(res, indent=2))
    else:
        for x in res["findings"]:
            loc = "%s:%d" % (x["file"], x["line"]) if x["line"] else x["file"]
            print("%s %s — %s" % (loc, x["id"], x["problem"]))
        print("ears-lint: %d stor%s, %d criteri%s, %d finding(s)" % (
            res["stories"], "y" if res["stories"] == 1 else "ies", res["criteria"],
            "on" if res["criteria"] == 1 else "a", len(res["findings"])))
    return 2 if res["findings"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
