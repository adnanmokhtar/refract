#!/usr/bin/env python3
"""score.py — map reported findings onto seeded defect ids and score detection.

Stdlib only. No network, no install step.

  python3 benchmarks/score.py --fixture=node-api --findings=run.md \
      --model="<model id>" --model-version="<build/date>" --date=2026-08-20

  python3 benchmarks/score.py --fixture=node-api --verify     # anchor/line drift check
  python3 benchmarks/score.py --fixture=node-api --list       # print the seeded ids

What it does NOT do: decide whether a finding is *correct*. It decides whether a finding
points at a place we deliberately broke and describes the thing we broke. Everything the
matcher cannot map is reported as UNMATCHED, never as "wrong" — see benchmarks/README.md
(§ Unmatched is not the same as false).

THE MATCH RULE (the whole of it; nothing else is consulted)
----------------------------------------------------------
A reported finding F matches seeded defect D when BOTH hold:

  1. basename(F.file) == basename(D.file), and
  2. every one of D's `match:` patterns hits F's text (case-insensitive regex search).

Text is always required. A finding that lands on the right line while describing
something else does not match — landing near a defect is not detecting it. Conversely a
line number is never required, because agents legitimately cite a function head or a
range rather than the exact line.

A match is then labelled by how close it landed:

  EXACT   F carries a line number within `--tolerance` of D's line
  TEXT    F carries no line number, or one outside the tolerance

Both count as detected; the split is reported so a reader can see how many detections
were also line-accurate. `--strict-line` promotes the tolerance to a hard requirement,
which is the harsher reading of the same run.

Assignment is one-to-one and greedy: EXACT pairs first, then TEXT, ties broken by line
distance. Each finding is credited to at most one defect and each defect is claimed by at
most one finding — so two co-located defects need two findings to both count.

FINDINGS INPUT — two accepted shapes, auto-detected
---------------------------------------------------
  JSON   a list of objects, or {"findings": [...]}, with a path-ish key
         (file / path / location) plus optional line and any of
         text / title / summary / description / message / detail.

  TEXT   anything else, including the markdown an agent prints. Every line holding a
         `path` or `path:line` token starts a finding; the line is its text. Lines with
         no path token are appended to the finding above them, so wrapped prose and
         indented detail bullets stay attached to their finding.

         HTML comment blocks (<!-- ... -->) are stripped first. That is how the findings
         template run.sh writes keeps its own instructions — which contain an example
         `path:line` — from being read back as a finding.
"""

import argparse
import json
import os
import re
import sys
from datetime import date as _date

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FIXTURES_DIR = os.path.join(REPO_ROOT, "benchmarks", "fixtures")

SEVERITY_WEIGHT = {"critical": 4, "high": 3, "medium": 2, "low": 1}
SEVERITY_ORDER = ["critical", "high", "medium", "low"]

# A path-ish token: at least one slash or a dotted filename, optional :line suffix.
PATH_RE = re.compile(
    r"(?<![\w./-])"
    r"((?:[\w.@-]+/)*[\w.@-]+\.[A-Za-z][A-Za-z0-9]{0,5})"
    r"(?::(\d+))?"
    r"(?![\w/])"
)


# --------------------------------------------------------------------------- defects


class Defect:
    __slots__ = ("id", "file", "line", "severity", "command", "cls", "anchor", "patterns", "raw")

    def __init__(self, fields, raw):
        self.id = fields.get("id", "")
        self.file = fields.get("file", "")
        self.line = int(fields["line"]) if fields.get("line", "").isdigit() else 0
        self.severity = fields.get("severity", "unknown").lower()
        self.command = fields.get("command", "")
        self.cls = fields.get("class", "")
        self.anchor = fields.get("anchor", "")
        self.patterns = []
        for pat in fields.get("_match", []):
            try:
                self.patterns.append(re.compile(pat, re.IGNORECASE))
            except re.error as exc:
                die(f"defect {self.id}: bad match pattern {pat!r}: {exc}")
        self.raw = raw

    @property
    def basename(self):
        return os.path.basename(self.file).lower()


def parse_defects(path):
    """Pull every ```defect fenced block out of a DEFECTS.md."""
    with open(path, encoding="utf-8") as fh:
        text = fh.read()

    defects, seen = [], set()
    for block in re.findall(r"^```defect[ \t]*\n(.*?)^```", text, re.S | re.M):
        fields, matches = {}, []
        for line in block.splitlines():
            if not line.strip() or ":" not in line:
                continue
            key, _, value = line.partition(":")
            key, value = key.strip().lower(), value.strip()
            if key == "match":
                matches.append(value)
            else:
                fields[key] = value
        fields["_match"] = matches
        defect = Defect(fields, block)

        for required in ("id", "file", "severity"):
            if not fields.get(required):
                die(f"{path}: a defect block is missing `{required}:`")
        if defect.id in seen:
            die(f"{path}: duplicate defect id {defect.id}")
        seen.add(defect.id)
        defects.append(defect)

    if not defects:
        die(f"{path}: no ```defect blocks found")
    return defects


# --------------------------------------------------------------------------- findings


class Finding:
    __slots__ = ("file", "line", "text", "source")

    def __init__(self, file, line, text, source=""):
        self.file = file or ""
        self.line = line
        self.text = text or ""
        self.source = source or text

    @property
    def basename(self):
        return os.path.basename(self.file).lower()


def _first_str(obj, keys):
    for key in keys:
        value = obj.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def parse_findings(path):
    with open(path, encoding="utf-8") as fh:
        raw = fh.read()

    stripped = raw.lstrip()
    if stripped.startswith("[") or stripped.startswith("{"):
        try:
            return _findings_from_json(json.loads(raw))
        except json.JSONDecodeError:
            pass  # looked like JSON, is not — fall through to the text reader
    return _findings_from_text(raw)


def _findings_from_json(payload):
    if isinstance(payload, dict):
        for key in ("findings", "results", "items", "defects"):
            if isinstance(payload.get(key), list):
                payload = payload[key]
                break
        else:
            payload = [payload]
    if not isinstance(payload, list):
        die("findings JSON must be a list, or an object with a findings/results list")

    out = []
    for entry in payload:
        if isinstance(entry, str):
            out.extend(_findings_from_text(entry))
            continue
        if not isinstance(entry, dict):
            continue
        loc = _first_str(entry, ("file", "path", "filepath", "file_path", "location"))
        line = entry.get("line", entry.get("lineno", entry.get("line_number")))
        text = " ".join(
            v for v in (
                _first_str(entry, ("title", "summary", "name")),
                _first_str(entry, ("text", "description", "message", "detail", "details")),
                _first_str(entry, ("class", "category", "kind", "type")),
                _first_str(entry, ("severity", "priority")),
            ) if v
        )
        # "src/a.js:31" in the location field, not split out into `line`
        if loc and line is None:
            hit = PATH_RE.search(loc)
            if hit and hit.group(2):
                loc, line = hit.group(1), hit.group(2)
        try:
            line = int(line) if line is not None else None
        except (TypeError, ValueError):
            line = None
        if not loc:
            hit = PATH_RE.search(text)
            if hit:
                loc = hit.group(1)
                if line is None and hit.group(2):
                    line = int(hit.group(2))
        out.append(Finding(loc, line, text, json.dumps(entry)[:400]))
    return out


HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.S)


def _findings_from_text(raw):
    # Instructions live in HTML comments (see the findings template run.sh writes), and
    # they contain an example path:line. Drop them before anything else looks at the text.
    raw = HTML_COMMENT_RE.sub("", raw)
    out = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        hit = PATH_RE.search(line)
        if hit:
            out.append(
                Finding(
                    hit.group(1),
                    int(hit.group(2)) if hit.group(2) else None,
                    line.strip(),
                    line.strip(),
                )
            )
        elif out:
            # continuation of the finding above
            out[-1].text += " " + line.strip()
    return out


# --------------------------------------------------------------------------- matching

EXACT, TEXT = 2, 1
NO_LINE = 10_000  # sorts every line-less match behind every line-bearing one


def pair_strength(defect, finding, tolerance, strict_line=False):
    """(EXACT|TEXT, line_distance) or None when the pair cannot match."""
    if not finding.basename or finding.basename != defect.basename:
        return None

    if defect.patterns:
        if not all(p.search(finding.text) for p in defect.patterns):
            return None
    elif finding.line is None or not defect.line:
        return None  # a pattern-less defect can only be claimed by line

    distance = (
        abs(finding.line - defect.line)
        if finding.line is not None and defect.line
        else None
    )
    if distance is not None and distance <= tolerance:
        return (EXACT, distance)
    if strict_line:
        return None
    return (TEXT, distance if distance is not None else NO_LINE)


def assign(defects, findings, tolerance, strict_line=False):
    candidates = []
    for di, defect in enumerate(defects):
        for fi, finding in enumerate(findings):
            pair = pair_strength(defect, finding, tolerance, strict_line)
            if pair:
                candidates.append((-pair[0], pair[1], di, fi))
    candidates.sort()

    by_defect, by_finding = {}, {}
    for neg_strength, distance, di, fi in candidates:
        if di in by_defect or fi in by_finding:
            continue
        by_defect[di] = (fi, -neg_strength, distance)
        by_finding[fi] = di
    return by_defect, by_finding


# --------------------------------------------------------------------------- reporting


def die(msg):
    sys.stderr.write(f"score.py: {msg}\n")
    raise SystemExit(2)


def fixture_defects_path(fixture, override):
    if override:
        return override
    path = os.path.join(FIXTURES_DIR, fixture, "DEFECTS.md")
    if not os.path.isfile(path):
        available = sorted(
            d for d in os.listdir(FIXTURES_DIR)
            if os.path.isfile(os.path.join(FIXTURES_DIR, d, "DEFECTS.md"))
        ) if os.path.isdir(FIXTURES_DIR) else []
        die(f"no DEFECTS.md for fixture {fixture!r}. Available: {', '.join(available) or '(none)'}")
    return path


def cmd_verify(fixture, defects):
    """Every anchor must occur exactly once in its file, at the recorded line."""
    root = os.path.join(FIXTURES_DIR, fixture)
    problems = 0
    for defect in defects:
        target = os.path.join(root, defect.file)
        if not os.path.isfile(target):
            print(f"  DRIFT {defect.id}: {defect.file} does not exist")
            problems += 1
            continue
        if not defect.anchor:
            print(f"  DRIFT {defect.id}: no anchor: field to verify")
            problems += 1
            continue
        with open(target, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
        hits = [i + 1 for i, text in enumerate(lines) if defect.anchor in text]
        if not hits:
            print(f"  DRIFT {defect.id}: anchor not found in {defect.file}")
            problems += 1
        elif len(hits) > 1:
            print(f"  DRIFT {defect.id}: anchor is ambiguous in {defect.file} (lines {hits})")
            problems += 1
        elif hits[0] != defect.line:
            print(f"  DRIFT {defect.id}: recorded line {defect.line}, anchor is at {hits[0]}")
            problems += 1
    total = len(defects)
    if problems:
        print(f"\n{fixture}: {problems}/{total} anchors drifted — fix DEFECTS.md or the fixture.")
        return 1
    print(f"{fixture}: {total}/{total} anchors resolve to their recorded line.")
    return 0


def main():
    ap = argparse.ArgumentParser(
        description="Score reported findings against a fixture's seeded defects.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--fixture", required=True, help="fixture name under benchmarks/fixtures/")
    ap.add_argument("--findings", help="file holding the agent's reported findings (JSON or text)")
    ap.add_argument("--defects", help="override the DEFECTS.md path")
    ap.add_argument("--command", default="", help="score only defects targeting this command, e.g. /audit")
    ap.add_argument("--tolerance", type=int, default=6, help="line window that makes a match EXACT (default 6)")
    ap.add_argument("--strict-line", action="store_true", help="require the line window; TEXT-only matches stop counting")
    ap.add_argument("--model", default="", help="model id the run used — REQUIRED to emit a results row")
    ap.add_argument("--model-version", default="", help="build/date/snapshot of that model")
    ap.add_argument("--date", default="", help="run date, ISO (default: today)")
    ap.add_argument("--notes", default="", help="free-text note for the results row")
    ap.add_argument("--row", action="store_true", help="print the RESULTS.md table row")
    ap.add_argument("--json", action="store_true", help="print the full result as JSON")
    ap.add_argument("--verify", action="store_true", help="check anchors still resolve; score nothing")
    ap.add_argument("--list", action="store_true", help="list the seeded defects; score nothing")
    args = ap.parse_args()

    defects = parse_defects(fixture_defects_path(args.fixture, args.defects))
    if args.command:
        defects = [d for d in defects if d.command == args.command]
        if not defects:
            die(f"no seeded defects target {args.command} in fixture {args.fixture!r}")

    if args.verify:
        raise SystemExit(cmd_verify(args.fixture, defects))

    if args.list:
        for d in defects:
            print(f"{d.id:<14} {d.severity:<9} {d.command:<10} {d.file}:{d.line}  {d.cls}")
        print(f"\n{len(defects)} seeded defects in fixture {args.fixture!r}.")
        return

    if not args.findings:
        die("--findings=<file> is required (or use --verify / --list)")
    if not os.path.isfile(args.findings):
        die(f"no such findings file: {args.findings}")

    findings = parse_findings(args.findings)
    if not findings:
        die(
            f"parsed 0 findings from {args.findings}. Every finding needs a file path "
            "(optionally file:line) on its line — see the FINDINGS INPUT section of this file."
        )

    by_defect, by_finding = assign(defects, findings, args.tolerance, args.strict_line)

    detected = [d for i, d in enumerate(defects) if i in by_defect]
    missed = [d for i, d in enumerate(defects) if i not in by_defect]
    unmatched = [f for i, f in enumerate(findings) if i not in by_finding]

    total = len(defects)
    rate = len(detected) / total if total else 0.0
    weight_total = sum(SEVERITY_WEIGHT.get(d.severity, 1) for d in defects)
    weight_found = sum(SEVERITY_WEIGHT.get(d.severity, 1) for d in detected)
    weighted = weight_found / weight_total if weight_total else 0.0

    per_sev = {}
    for sev in SEVERITY_ORDER:
        seeded = [d for d in defects if d.severity == sev]
        if seeded:
            per_sev[sev] = (sum(1 for d in seeded if d in detected), len(seeded))

    run_date = args.date or _date.today().isoformat()

    # ---- human report
    print(f"fixture        {args.fixture}")
    print(f"command        {args.command or '(all seeded commands)'}")
    print(f"findings read  {len(findings)} from {args.findings}")
    print(f"tolerance      +/-{args.tolerance} lines" + ("  (strict: line required)" if args.strict_line else ""))
    print(f"model          {args.model or '(NOT RECORDED)'} {args.model_version}".rstrip())
    print(f"date           {run_date}")
    print()
    print(f"DETECTED       {len(detected)}/{total}  ({rate:.0%})")
    print(f"severity-wtd   {weighted:.0%}  (critical 4 / high 3 / medium 2 / low 1)")
    print(f"UNMATCHED      {len(unmatched)}  (findings mapped to no seeded defect — read them)")
    print()

    if per_sev:
        print("by severity")
        for sev in SEVERITY_ORDER:
            if sev in per_sev:
                found, seeded = per_sev[sev]
                print(f"  {sev:<9} {found}/{seeded}")
        print()

    n_exact = sum(1 for v in by_defect.values() if v[1] == EXACT)
    if detected:
        print("detected")
        for i, defect in enumerate(defects):
            if i in by_defect:
                fi, strength, distance = by_defect[i]
                label = f"EXACT(+/-{distance})" if strength == EXACT else "TEXT"
                print(f"  [+] {defect.id:<14} {label:<12} <- {findings[fi].source[:86]}")
        print()

    if missed:
        print("missed")
        for defect in missed:
            print(f"  [-] {defect.id:<14} {defect.severity:<9} {defect.file}:{defect.line}  {defect.cls}")
        print()

    if unmatched:
        print("unmatched findings (NOT scored as wrong — see benchmarks/README.md)")
        for finding in unmatched:
            loc = f"{finding.file}:{finding.line}" if finding.line else finding.file
            print(f"  [?] {loc:<44} {finding.text[:76]}")
        print()

    result = {
        "date": run_date,
        "fixture": args.fixture,
        "command": args.command,
        "model": args.model,
        "model_version": args.model_version,
        "seeded": total,
        "detected": len(detected),
        "detection_rate": round(rate, 4),
        "severity_weighted": round(weighted, 4),
        "unmatched": len(unmatched),
        "exact_line_matches": n_exact,
        "text_only_matches": len(detected) - n_exact,
        "tolerance": args.tolerance,
        "strict_line": args.strict_line,
        "by_severity": {k: {"detected": v[0], "seeded": v[1]} for k, v in per_sev.items()},
        "detected_ids": [d.id for d in detected],
        "missed_ids": [d.id for d in missed],
        "notes": args.notes,
    }

    if args.json:
        print(json.dumps(result, indent=2))

    if args.row:
        if not args.model:
            die(
                "--row needs --model. A results row without a model id is not reproducible, "
                "and benchmarks/RESULTS.md will not accept one."
            )
        version = args.model_version or "unrecorded"
        print()
        print("paste into benchmarks/RESULTS.md:")
        print(
            f"| {run_date} | {args.fixture} | {args.command or 'all'} | {args.model} | {version} "
            f"| {len(detected)}/{total} | {rate:.0%} | {weighted:.0%} | {len(unmatched)} "
            f"| {args.notes or '—'} |"
        )


if __name__ == "__main__":
    main()
