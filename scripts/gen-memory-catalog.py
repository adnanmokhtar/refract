#!/usr/bin/env python3
"""gen-memory-catalog.py — EXTRACT a PROJECT's existing `ai/` memory into one catalog.

Second row producer for `scripts/pack-search.py`. Same 9 columns, same module interface
(`COLUMNS`, `DEFAULT_OUT`, `source_files(root)`, `build(root, warn=None)`, `run_check(...)`),
different corpus: where `gen-pack-catalog.py` reads THIS repo's `templates/`, this reads a
consuming project's `ai/` tree — the sinks `/learn-from-task` writes and `knowledge-curator`
promotes from.

  python3 scripts/gen-memory-catalog.py --repo-root=/path/to/project --stats
  python3 scripts/gen-memory-catalog.py --repo-root=/path/to/project --check
  python3 scripts/pack-search.py "tenant cache" --catalog=memory --repo-root=/path/to/project

**Nothing new is stored.** The corpus is the project's existing `ai/` files; the catalog is a
derived cache, never committed, and every row is a POINTER carrying `path:line` so the next
step is a Read of the memory file, not a paraphrase of it. This producer NEVER writes into
`ai/` — it only reads. Adding a sink is `templates/snippets/learning-sink.md`'s business, and
that table is unchanged.

Row units, and why each one survives being read alone (the `docs/RETRIEVAL.md` discriminator):

  ai/dynamic/*.md          each `### <date> — <label>` block   memory-learning / -pattern /
                                                              -correction / -decision / -drift /
                                                              -interaction / -note
  ai/dynamic/session-log.md each `## <timestamp>` entry        memory-session  (POINTER ONLY —
                                                              branch + file count, no content)
  ai/failures/_index.md    each `###` block under `## Catalog` memory-failure
  ai/decisions/*.md        one row per ADR                     memory-adr
  ai/patterns/*.md         one row per file                    memory-pattern
  ai/runbooks/*.md         one row per file                    memory-runbook
  ai/conventions.md        bullets under a MUST / MUST-NOT /   memory-convention
                           Never / Always / Checklist heading
  ai/audits/**/*.md        each `###` block                    memory-archived

Deliberately NOT indexed, for the same reason the pack catalog leaves prose alone:
  - `ai/dynamic/changelog.md` — a one-line activity log, pruned at 200 lines. A line out of
    order carries nothing; the file is reachable by path.
  - `ai/dynamic/.review-queue` — transient hook hints, gitignored, not markdown.
  - `README.md` / `_template.md` scaffolds — format documentation, not memory.
  - Fenced code blocks — every baseline sink documents its entry shape inside a ``` fence.
    Indexing those would return `### <YYYY-MM-DD> — <short observation>` as a "memory".
  - Headings carrying an unfilled `<placeholder>` — the same guard, for projects that write
    their format notes outside a fence.

Scope is the project, always. There is no cross-project index: a lesson learned in project A
stays in project A. `scripts/verify-global-scope.sh` keeps the global surface core-only, and
the per-user memory store at `~/.claude/projects/<encoded>/memory/` belongs to the host, not
to this framework.
"""
import argparse
import csv
import difflib
import glob
import io
import json
import os
import re
import sys
from collections import Counter

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

COLUMNS = ["id", "kind", "scope", "owner", "name", "path", "anchor", "stack", "text"]
DEFAULT_OUT = "tmp/memory-catalog/catalog.csv"

# Corpus label + disclaimer used by pack-search.py's renderers, so the footer names the
# right corpus instead of claiming rows came from templates/.
CORPUS_LABEL = "this project's ai/ tree"
# `memory-interaction` is the longest kind at 18 chars; the default 16-wide column would
# print `memory-interacti`, which reads like a different kind.
KIND_WIDTH = 18
# No fixed smoke vocabulary: a project corpus has no words this script can assume. The
# engine falls back to a self-probe (a row's own name must retrieve that row).
SMOKE = []
EMPTY_MESSAGE = (
    "no memory captured yet — this project's ai/ tree holds no indexable entries.\n"
    "Run /learn-from-task at the end of a session; the sinks it writes are what this searches.")

# One row per `### …` block. `ai/dynamic/<sink>.md` -> the kind that sink holds.
SINK_KINDS = {
    "learnings": "memory-learning",
    "learned-patterns": "memory-pattern",
    "feedback-learned": "memory-correction",
    "decisions-pending": "memory-decision",
    "drift-log": "memory-drift",
    "interaction-log": "memory-interaction",
}
# A project may add its own `ai/dynamic/` sink (knowledge-curator's
# `project_specific_dynamic_files` duty). Those still index, under a neutral kind, rather
# than being silently dropped.
SINK_DEFAULT_KIND = "memory-note"
# Not sinks: a one-line activity log and the scaffold prose.
SINK_SKIP = {"changelog", "README"}

SKIP_BASENAMES = {"README.md", "_template.md"}

BODY_CAP = 600          # matches the closure-verb cap in gen-pack-catalog.py
FENCE_RE = re.compile(r"^\s*(```|~~~)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
BULLET_RE = re.compile(r"^\s*[-*]\s+(?:\[[ xX]\]\s+)?(.+?)\s*$")
PLACEHOLDER_RE = re.compile(r"<[^>]+>")
# Same directive vocabulary the pack catalog uses — a heading that gates a bullet list of
# atomic, standalone assertions. Bullets under a topical heading (`## Imports`) are prose.
DIRECTIVE_SECTION_RE = re.compile(
    r"^(must not|must|should not|should|never|always|forbidden|required|"
    r"review checklist|checklist|enforcement)\b", re.I)
# `### 2026-08-20 — tenant cache key` / `### <pattern name>` — the label after the date.
DATED_HEADING_RE = re.compile(r"^\s*(\d{4}-\d{2}-\d{2})\s*(?:—|--|-)\s*(.+?)\s*$")
ADR_H1_RE = re.compile(r"^#\s+ADR\s*(\d+)\s*(?:—|--|-)\s*(.+?)\s*$", re.I)
STATUS_RE = re.compile(r"^Status:\s*(.+?)\s*$", re.I)


# ---------------------------------------------------------------------------
# small helpers (mirrors of gen-pack-catalog.py's, so the two producers stay comparable)
# ---------------------------------------------------------------------------
def read_lines(path):
    with open(path, encoding="utf-8", errors="ignore") as fh:
        return fh.read().split("\n")


def rel(path, root):
    return os.path.relpath(path, root).replace(os.sep, "/")


def clean(s):
    s = re.sub(r"`+", "", s or "")
    s = re.sub(r"\*\*|__", "", s)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    return re.sub(r"\s+", " ", s).strip()


def dedupe_text(parts):
    seen, out = set(), []
    for p in parts:
        p = clean(p)
        if not p:
            continue
        key = p.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(p)
    return " ".join(out)


def row(**kw):
    r = {c: "" for c in COLUMNS}
    r.update(kw)
    r["name"] = clean(r["name"])
    r["anchor"] = clean(r["anchor"])[:120]
    r["text"] = re.sub(r"\s+", " ", r["text"]).strip()
    return r


def slug(text, fallback="entry"):
    s = re.sub(r"[^a-z0-9]+", "-", clean(text).lower()).strip("-")
    return (s[:60] or fallback)


def is_placeholder(text):
    """`### <YYYY-MM-DD> — <short observation>` is a format note, not a memory."""
    return bool(PLACEHOLDER_RE.search(text or ""))


def blocks(lines, level=3, start_after=None):
    """Yield (lineno, heading, anchor, body) for each heading at exactly `level`.

    Skips fenced code (every baseline sink documents its entry shape inside a fence) and
    placeholder headings. `anchor` is the nearest enclosing heading one level up.
    `start_after` is a regex; when given, nothing before the first line matching it counts
    (that is how `ai/failures/_index.md` limits rows to the `## Catalog` section).
    """
    want = "#" * level + " "
    fence = False
    armed = start_after is None
    anchor, cur, out = "", None, []

    def flush(end):
        if cur is not None:
            lineno, heading, anch, start = cur
            body = " ".join(clean(x) for x in lines[start:end])
            out.append((lineno, heading, anch, body))

    for i, line in enumerate(lines):
        if FENCE_RE.match(line):
            fence = not fence
            continue
        if fence:
            continue
        if not armed:
            if re.search(start_after, line):
                armed = True
            continue
        m = HEADING_RE.match(line)
        if not m:
            continue
        depth = len(m.group(1))
        if depth == level - 1:
            flush(i)
            cur, anchor = None, m.group(2)
            continue
        if depth <= level:
            flush(i)
            cur = None
        if line.startswith(want):
            heading = m.group(2)
            if is_placeholder(heading):
                continue
            cur = (i + 1, heading, anchor, i + 1)
    flush(len(lines))
    return out


def entry_name(heading):
    """`2026-08-20 — tenant cache key` -> ("tenant cache key", "2026-08-20")."""
    m = DATED_HEADING_RE.match(clean(heading))
    if m:
        return m.group(2), m.group(1)
    return clean(heading), ""


# ---------------------------------------------------------------------------
# extractor 1 — the ai/dynamic/ sink set (learnings, patterns, corrections, decisions, drift)
# ---------------------------------------------------------------------------
def extract_sinks(root):
    rows = []
    for f in sorted(glob.glob(os.path.join(root, "ai/dynamic/*.md"))):
        stem = os.path.basename(f)[:-3]
        if stem in SINK_SKIP or os.path.basename(f) in SKIP_BASENAMES:
            continue
        if stem == "session-log":
            continue          # extractor 7 — pointer rows only
        kind = SINK_KINDS.get(stem, SINK_DEFAULT_KIND)
        r = rel(f, root)
        lines = read_lines(f)
        for lineno, heading, anchor, body in blocks(lines, level=3):
            name, date = entry_name(heading)
            rows.append(row(
                id="%s:%s:%s:%d" % (kind, stem, slug(name), lineno),
                kind=kind, scope="project", owner=stem, name=name,
                path="%s:%d" % (r, lineno), anchor=anchor,
                text=dedupe_text([name, date, body[:BODY_CAP]]),
            ))
    return rows


# ---------------------------------------------------------------------------
# extractor 2 — the don't-retry catalog. Its whole value is at the moment of recall.
# ---------------------------------------------------------------------------
def extract_failures(root):
    f = os.path.join(root, "ai/failures/_index.md")
    if not os.path.isfile(f):
        return []
    rows, r = [], rel(f, root)
    for lineno, heading, anchor, body in blocks(read_lines(f), level=3,
                                                start_after=r"^##\s+Catalog\b"):
        name, date = entry_name(heading)
        rows.append(row(
            id="memory-failure:failures:%s:%d" % (slug(name), lineno),
            kind="memory-failure", scope="project", owner="failures", name=name,
            path="%s:%d" % (r, lineno), anchor=anchor or "Catalog",
            text=dedupe_text([name, date, body[:BODY_CAP]]),
        ))
    return rows


# ---------------------------------------------------------------------------
# extractor 3 — formal ADRs (number, title, status, the Context paragraph)
# ---------------------------------------------------------------------------
def extract_adrs(root):
    rows = []
    for f in sorted(glob.glob(os.path.join(root, "ai/decisions/*.md"))):
        base = os.path.basename(f)
        if base in SKIP_BASENAMES or base.startswith("_"):
            continue
        lines = read_lines(f)
        r = rel(f, root)
        title, number = "", ""
        for ln in lines:
            if ln.startswith("# "):
                m = ADR_H1_RE.match(ln)
                title = m.group(2) if m else ln[2:].strip()
                number = m.group(1) if m else ""
                break
        if is_placeholder(title):
            continue          # an unfilled `ai/decisions/_template.md` copy
        status = ""
        for ln in lines[:20]:
            m = STATUS_RE.match(ln.strip())
            if m:
                status = m.group(1)
                break
        context, in_ctx = [], False
        for ln in lines:
            if ln.startswith("## "):
                if in_ctx:
                    break
                in_ctx = ln[3:].strip().lower().startswith("context")
                continue
            if in_ctx and ln.strip():
                context.append(clean(ln))
                if sum(len(c) for c in context) > BODY_CAP:
                    break
        rows.append(row(
            id="memory-adr:decisions:%s" % (number or slug(base[:-3])),
            kind="memory-adr", scope="project", owner="decisions",
            name=title or base[:-3], path=r, anchor=("ADR %s" % number) if number else "",
            text=dedupe_text([title, number, status, " ".join(context)[:BODY_CAP]]),
        ))
    return rows


# ---------------------------------------------------------------------------
# extractor 4 — formal patterns + runbooks (one file-level pointer each)
# ---------------------------------------------------------------------------
def extract_docs(root):
    rows = []
    for sub, kind in (("patterns", "memory-pattern"), ("runbooks", "memory-runbook")):
        for f in sorted(glob.glob(os.path.join(root, "ai", sub, "*.md"))):
            base = os.path.basename(f)
            if base in SKIP_BASENAMES or base.startswith("_"):
                continue
            lines = read_lines(f)
            title = next((ln[2:].strip() for ln in lines if ln.startswith("# ")), base[:-3])
            if is_placeholder(title):
                continue
            body = " ".join(clean(x) for x in lines[:40] if x.strip() and not x.startswith("#"))
            rows.append(row(
                id="%s:%s:%s" % (kind, sub, slug(base[:-3])),
                kind=kind, scope="project", owner=sub, name=title,
                path=rel(f, root), anchor="",
                text=dedupe_text([title, base[:-3].replace("-", " "), body[:BODY_CAP]]),
            ))
    return rows


# ---------------------------------------------------------------------------
# extractor 5 — conventions, under a directive heading only
# ---------------------------------------------------------------------------
def extract_conventions(root):
    f = os.path.join(root, "ai/conventions.md")
    if not os.path.isfile(f):
        return []
    rows, r = [], rel(f, root)
    fence, section, directive = False, "", False
    for lineno, line in enumerate(read_lines(f), 1):
        if FENCE_RE.match(line):
            fence = not fence
            continue
        if fence:
            continue
        h = HEADING_RE.match(line)
        if h:
            section = h.group(2)
            directive = bool(DIRECTIVE_SECTION_RE.match(clean(section)))
            continue
        if not directive:
            continue
        b = BULLET_RE.match(line)
        if not b:
            continue
        text = clean(b.group(1))
        if not text or is_placeholder(text):
            continue
        rows.append(row(
            id="memory-convention:conventions:%s:%d" % (slug(text), lineno),
            kind="memory-convention", scope="project", owner="conventions",
            name=text[:80], path="%s:%d" % (r, lineno), anchor=section,
            text=dedupe_text([text, section]),
        ))
    return rows


# ---------------------------------------------------------------------------
# extractor 6 — the archives. This is the extractor that makes the curator's budgets
# affordable: `archive` stops meaning "gone" once the archive is indexed.
# ---------------------------------------------------------------------------
def extract_audits(root):
    rows = []
    for f in sorted(glob.glob(os.path.join(root, "ai/audits/**/*.md"), recursive=True)):
        base = os.path.basename(f)
        if base in SKIP_BASENAMES:
            continue
        stem = base[:-3]
        r = rel(f, root)
        lines = read_lines(f)
        found = blocks(lines, level=3)
        if not found:
            title = next((ln[2:].strip() for ln in lines if ln.startswith("# ")), stem)
            if is_placeholder(title):
                continue
            body = " ".join(clean(x) for x in lines[:40] if x.strip() and not x.startswith("#"))
            rows.append(row(
                id="memory-archived:audits:%s" % slug(stem),
                kind="memory-archived", scope="project", owner="audits", name=title,
                path=r, anchor="",
                text=dedupe_text([title, stem.replace("-", " "), body[:BODY_CAP]]),
            ))
            continue
        for lineno, heading, anchor, body in found:
            name, date = entry_name(heading)
            rows.append(row(
                id="memory-archived:audits:%s:%s:%d" % (slug(stem), slug(name), lineno),
                kind="memory-archived", scope="project", owner="audits", name=name,
                path="%s:%d" % (r, lineno), anchor=anchor or stem,
                text=dedupe_text([name, date, stem.replace("-", " "), body[:BODY_CAP]]),
            ))
    return rows


# ---------------------------------------------------------------------------
# extractor 7 — session pointers. POINTER ONLY: the heading, the branch, the file count.
# Session CONTENT is never copied here — the harness already keeps the verbatim transcript
# under `~/.claude/projects/<encoded>/`, and a copy in the repo would be a secret-leak
# surface `secret-scan.sh` never sees (a hook write is not an Edit).
# ---------------------------------------------------------------------------
def extract_sessions(root):
    f = os.path.join(root, "ai/dynamic/session-log.md")
    if not os.path.isfile(f):
        return []
    rows, r = [], rel(f, root)
    lines = read_lines(f)
    for lineno, heading, anchor, body in blocks(lines, level=2):
        head = clean(heading)
        if not head or is_placeholder(head):
            continue
        # "POINTER ONLY — session CONTENT is never copied" was not true. Splitting on " - "
        # drops the changed-file bullets and nothing else, so two things the Stop hook writes
        # still landed in the searchable text: the absolute `Transcript: /Users/<name>/…` path,
        # and `Opened with: <the user's first prompt, verbatim>`. Both are content, and one of
        # them carries a home directory into a file that gets committed. Drop them by name.
        meta = [x for x in body.split(" - ")[0].split(" ") if x]
        _drop = ("Transcript:", "Opened", "with:")
        if any(d in body for d in ("Transcript:", "Opened with:")):
            _cut = body.split(" - ")[0]
            for _marker in ("Transcript:", "Opened with:"):
                _i = _cut.find(_marker)
                if _i != -1:
                    _cut = _cut[:_i]
            meta = [x for x in _cut.split(" ") if x]
        rows.append(row(
            id="memory-session:sessions:%s:%d" % (slug(head), lineno),
            kind="memory-session", scope="project", owner="sessions", name=head,
            path="%s:%d" % (r, lineno), anchor="session-log",
            text=dedupe_text([head, " ".join(meta)[:240]]),
        ))
    return rows


# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------
def source_files(root):
    """Every file the catalog is derived from — the freshness fingerprint's input."""
    pats = [
        "ai/dynamic/*.md",
        "ai/failures/_index.md",
        "ai/decisions/*.md",
        "ai/patterns/*.md",
        "ai/runbooks/*.md",
        "ai/conventions.md",
    ]
    out = set()
    for pat in pats:
        out.update(glob.glob(os.path.join(root, pat)))
    out.update(glob.glob(os.path.join(root, "ai/audits/**/*.md"), recursive=True))
    return sorted(p for p in out if os.path.isfile(p))


def build(root, warn=None):
    """Extract every row. Deterministic: sorted globs, stable sort, no dict iteration order."""
    if warn is None:
        warn = lambda level, msg: None
    rows = []
    rows += extract_sinks(root)
    rows += extract_failures(root)
    rows += extract_adrs(root)
    rows += extract_docs(root)
    rows += extract_conventions(root)
    rows += extract_audits(root)
    rows += extract_sessions(root)
    rows = [r for r in rows if r["text"]]
    rows.sort(key=lambda r: (r["kind"], r["scope"], r["owner"], r["path"], r["id"]))
    seen = Counter()
    for r in rows:                     # ids must be unique + stable
        seen[r["id"]] += 1
        if seen[r["id"]] > 1:
            r["id"] = "%s#%d" % (r["id"], seen[r["id"]])
    return rows


def to_csv(rows):
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=COLUMNS, lineterminator="\n")
    w.writeheader()
    for r in rows:
        w.writerow({c: r.get(c, "") for c in COLUMNS})
    return buf.getvalue()


def to_jsonl(rows):
    return "".join(json.dumps({c: r.get(c, "") for c in COLUMNS},
                              sort_keys=True, separators=(",", ":")) + "\n" for r in rows)


# ---------------------------------------------------------------------------
# --check
# ---------------------------------------------------------------------------
def run_check(root, out_path, out_is_explicit=False):
    """Integrity gate, same shape as gen-pack-catalog.py's.

    An EMPTY corpus is not a failure. A project that has never run `/learn-from-task` has
    nothing to index, and saying so is the honest result — inventing rows would be worse.
    """
    problems, warnings = [], []

    def warn(level, msg):
        (problems if level == "FAIL" else warnings).append(msg)

    rows = build(root, warn)
    srcs = source_files(root)
    print("[1] extraction")
    print("    %d rows from %d source files (root: %s)" % (len(rows), len(srcs), root))

    print("[2] determinism (build twice, byte-compare)")
    again = to_csv(build(root))
    if again != to_csv(rows):
        problems.append("extraction is NOT deterministic — two builds differ")
        print("    FAIL — two builds of the same tree differ")
    else:
        print("    ok — identical")

    print("[3] pointer integrity (every path:line resolves)")
    lengths, bad = {}, 0
    for r in rows:
        p, _, ln = r["path"].partition(":")
        abs_p = os.path.join(root, p)
        if p not in lengths:
            lengths[p] = len(read_lines(abs_p)) if os.path.isfile(abs_p) else -1
        if lengths[p] < 0:
            problems.append("%s — dangling path (row %s)" % (p, r["id"]))
            bad += 1
        elif ln and not (1 <= int(ln) <= lengths[p]):
            problems.append("%s:%s — line out of range 1..%d (row %s)"
                            % (p, ln, lengths[p], r["id"]))
            bad += 1
    print("    %s — %d distinct files, %d bad pointers"
          % ("ok" if bad == 0 else "FAIL", len(lengths), bad))

    print("[4] id uniqueness")
    dupes = [i for i, c in Counter(r["id"] for r in rows).items() if c > 1]
    if dupes:
        problems.append("duplicate ids after disambiguation: %s" % dupes[:5])
    print("    %s — %d ids" % ("ok" if not dupes else "FAIL", len(rows)))

    print("[5] corpus presence")
    if not os.path.isdir(os.path.join(root, "ai")):
        print("    skip — no ai/ tree at this root (nothing to index; not a defect)")
    elif not rows:
        print("    empty — ai/ exists but holds no indexable entries. Run /learn-from-task;")
        print("            an empty index is reported honestly, never padded.")
    else:
        for k, n in sorted(Counter(r["kind"] for r in rows).items()):
            print("    %-20s %5d" % (k, n))

    print("[6] on-disk catalog freshness (%s)" % out_path)
    abs_out = os.path.join(root, out_path)
    if not os.path.isfile(abs_out):
        print("    skip — not generated (the catalog is a cache, not a committed artifact)")
    else:
        fresh = to_csv(rows)
        with open(abs_out, encoding="utf-8") as fh:
            stale = fh.read()
        if fresh != stale:
            d = list(difflib.unified_diff(stale.splitlines(), fresh.splitlines(),
                                          "on-disk", "regenerated", lineterm="", n=0))
            msg = "%s is stale — rerun gen-memory-catalog.py" % out_path
            (problems if out_is_explicit else warnings).append(msg)
            print("    %s — stale (%d diff lines); first:"
                  % ("FAIL" if out_is_explicit else "WARN", len(d)))
            for ln in d[:6]:
                print("      %s" % ln[:160])
        else:
            print("    ok — regenerates identically")

    if warnings:
        print("\nWARN (%d):" % len(warnings))
        for w in warnings[:20]:
            print("  WARN  %s" % w)
        if len(warnings) > 20:
            print("  ... %d more" % (len(warnings) - 20))
    if problems:
        print("\nFAIL (%d):" % len(problems))
        for p in problems[:20]:
            print("  FAIL  %s" % p)
        if len(problems) > 20:
            print("  ... %d more" % (len(problems) - 20))
        return 1
    print("\nmemory catalog check: OK (%d rows, %d warnings)" % (len(rows), len(warnings)))
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Extract a project's ai/ memory into the row catalog pack-search.py reads.")
    ap.add_argument("--repo-root", default=REPO_ROOT,
                    help="the PROJECT root that holds ai/ (a monorepo package dir is a valid root)")
    ap.add_argument("--out", default=None,
                    help="repo-relative output path (default %s); passing it explicitly "
                         "makes --check FAIL rather than WARN on a stale copy" % DEFAULT_OUT)
    ap.add_argument("--format", choices=("csv", "jsonl"), default="csv")
    ap.add_argument("--stdout", action="store_true", help="print, write nothing")
    ap.add_argument("--stats", action="store_true", help="row counts by kind, write nothing")
    ap.add_argument("--check", action="store_true", help="integrity + determinism gate")
    a = ap.parse_args(argv)
    root = os.path.abspath(a.repo_root)

    if a.check:
        return run_check(root, a.out or DEFAULT_OUT, out_is_explicit=a.out is not None)

    rows = build(root)
    if a.stats:
        print("%d rows  (%d source files)" % (len(rows), len(source_files(root))))
        for k, n in sorted(Counter(r["kind"] for r in rows).items(), key=lambda x: (-x[1], x[0])):
            print("  %6d  %s" % (n, k))
        if not rows:
            print("  (empty — nothing captured in ai/ yet)")
        return 0

    body = to_csv(rows) if a.format == "csv" else to_jsonl(rows)
    if a.stdout:
        sys.stdout.write(body)
        return 0
    out_rel = a.out or DEFAULT_OUT
    out = os.path.join(root, out_rel)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(body)
    print("wrote %s — %d rows, %d bytes" % (out_rel, len(rows), len(body)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
