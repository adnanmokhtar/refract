#!/usr/bin/env python3
"""gen-pack-catalog.py — EXTRACT the row-shaped metadata in this repo into one catalog.

The repo's knowledge is mostly narrative discipline (agent personas, discipline
catalogues, ordered procedures). That prose is NOT indexed — flattening an argument
into rows destroys it. What IS indexed is the row-shaped metadata *about* that prose:
topic specs, artifact frontmatter, rule directives, registry tables, domain
checklists, closure verbs, STACK substitution tables, trigger names, references.

Every row is a POINTER: it carries `path` (with `:line` where the source is
line-addressable) so the next step is a Read of the cited file, not a guess.

  python3 scripts/gen-pack-catalog.py                  # write tmp/pack-search/catalog.csv
  python3 scripts/gen-pack-catalog.py --stats          # row counts by kind, write nothing
  python3 scripts/gen-pack-catalog.py --stdout         # CSV to stdout, write nothing
  python3 scripts/gen-pack-catalog.py --format=jsonl --out=tmp/pack-search/catalog.jsonl
  python3 scripts/gen-pack-catalog.py --check          # integrity + determinism gate (exit 1 on fail)

The catalog is NOT committed. Extraction is ~100 ms over ~900 files, so a committed
copy would buy nothing and add a tenth drift surface to police. The source markdown
stays the single source of truth; `--check` proves the extraction is reproducible and
that every emitted pointer resolves.

Columns (9):
  id     stable key, e.g. rule-directive:ui-ux:ui-principles:14
  kind   what the row IS      (rule-directive | topic-agent | closure-verb | ...)
  scope  where its owner LIVES (pack | domain | business-domain | registry | core)
  owner  pack key / domain key / business-domain key   <- what --pack/--domain filter on
  name   human label
  path   repo-relative, with :line where line-addressable   <- the payload
  anchor section heading the row sits under
  stack  comma-joined stack keys this row is specific to (else empty)
  text   searchable body, deduped across fields
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
DEFAULT_OUT = "tmp/pack-search/catalog.csv"

# Artifact directories that hold ONE artifact per file with frontmatter.
ARTIFACT_DIRS = ("agents", "commands", "skills", "rules", "ai-patterns", "references")

# `kind:` values `_topics.md` is allowed to declare. Anything outside this set is a
# FAIL under --check. `pattern` vs `ai-pattern` vs `reference-pair` are all live today
# (real vocabulary drift, surfaced as a WARN below — not invented by this script).
TOPIC_KINDS = {"agent", "command", "skill", "rule", "pattern", "ai-pattern",
               "reference", "reference-pair"}
# The vocabulary the majority uses; the rest are reported as drift by --check.
TOPIC_KIND_PREFERRED = {"agent", "command", "skill", "rule", "pattern", "reference"}

# Hand-maintained catalog files — already row-shaped by design, consumed by multiple phases.
REGISTRY_FILES = [
    "templates/packs/_registry.md",
    "templates/domains/_registry.md",
    "templates/business-domains/_registry.md",
    "templates/tool-adapters/_registry.md",
]
TRIGGER_VOCAB = "templates/packs/_trigger-vocabulary.md"

# A `##`/`###` heading whose text starts with one of these gates a bullet list of atomic,
# standalone directives. Bullets under any OTHER heading are prose and stay unindexed.
DIRECTIVE_SECTION_RE = re.compile(
    r"^(must not|must|should not|should|never|always|forbidden|required|"
    r"review checklist|checklist|enforcement)\b", re.I)

# A closure verb / drift class: an UNORDERED set member, named in kebab-case.
#   `### 7. idempotency-key-missing`   -> a row (self-contained fingerprint→procedure→verify)
#   `### 7. Generate current spec`     -> an ORDERED procedure step; order is the content, NOT a row
CLOSURE_VERB_RE = re.compile(r"^#{2,4}\s+\d+\.\s+([a-z][a-z0-9]*(?:-[a-z0-9]+)+)\s*$")

HEADING_RE = re.compile(r"^(#{2,4})\s+(.*?)\s*$")
TABLE_SEP_RE = re.compile(r"^\|[\s:\-|]+\|\s*$")
BULLET_RE = re.compile(r"^\s*[-*]\s+(?:\[[ xX]\]\s+)?(.+?)\s*$")
CHECKLIST_RE = re.compile(r"^\s*- \[[ xX]\]\s+(.+?)\s*$")
TRIGGER_BULLET_RE = re.compile(r"^-\s+`([^`]+)`\s*(?:—|--|-)?\s*(.*?)\s*$")
FM_KEY_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$")
TOPIC_FIELD_CACHE = {}


# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------
def read_lines(path):
    with open(path, encoding="utf-8", errors="ignore") as fh:
        return fh.read().split("\n")


def rel(path, root):
    return os.path.relpath(path, root).replace(os.sep, "/")


def artifact_files(root, base, kind_dir):
    """(path, stem) for every artifact under `<base>/*/<kind_dir>/`, both skill layouts.

    `skills/` migrated from one flat `<name>.md` per skill to a directory per skill
    holding `SKILL.md`. Globbing only the flat form silently emptied the `skill` and
    `closure-verb` kinds out of the catalog with no gate noticing, so BOTH shapes are
    globbed here and the skill's NAME is the directory for the nested form. Every other
    artifact dir is one flat file per artifact and takes the first branch only.
    """
    out = {}
    for f in glob.glob(os.path.join(root, base, "*", kind_dir, "*.md")):
        out[f] = os.path.basename(f)[:-3]
    if kind_dir == "skills":
        for f in glob.glob(os.path.join(root, base, "*", kind_dir, "*", "SKILL.md")):
            out[f] = os.path.basename(os.path.dirname(f))
    return sorted(out.items())


def frontmatter(lines):
    """Flat scalar frontmatter only — this repo never nests artifact frontmatter."""
    out = {}
    if not lines or lines[0].strip() != "---":
        return out
    for ln in lines[1:]:
        if ln.strip() == "---":
            break
        m = FM_KEY_RE.match(ln)
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    return out


def first_h1(lines):
    for ln in lines:
        if ln.startswith("# "):
            return ln[2:].strip()
    return ""


def clean(s):
    """Strip markdown noise that carries no search signal."""
    s = re.sub(r"`+", "", s or "")
    s = re.sub(r"\*\*|__", "", s)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    return re.sub(r"\s+", " ", s).strip()


def dedupe_text(parts):
    """Join field values, dropping case-insensitive duplicates.

    Fixes the degenerate case where frontmatter `description` equals the H1 equals the
    filename — triplicated text inflates BM25 term frequency and mis-ranks the row.
    """
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


# ---------------------------------------------------------------------------
# stack keys — derived from the reference files that already exist, not invented
# ---------------------------------------------------------------------------
def stack_keys(root):
    keys = set()
    for f in glob.glob(os.path.join(root, "templates/packs/*/references/*.md")):
        base = os.path.basename(f)[:-3]
        if base.endswith("-discipline-catalogue") or base.endswith("-discipline-procedures"):
            continue          # prose, not a stack
        keys.add(base)
    return keys


# Aliases used ONLY to read a STACK.md column header ("Spring Boot (Java/Kotlin)" -> spring-boot).
# Every value must be a key produced by stack_keys() or it is dropped.
STACK_ALIASES = {
    "vue": "vue", "vue 3": "vue", "nuxt": "nuxt", "react": "react", "next": "nextjs",
    "next.js": "nextjs", "nextjs": "nextjs", "angular": "angular", "svelte": "svelte",
    "sveltekit": "svelte", "nestjs": "nestjs", "nest": "nestjs", "express": "express",
    "fastapi": "fastapi", "flask": "flask", "django": "django", "laravel": "laravel",
    "rails": "rails", "spring boot": "spring-boot", "spring": "spring-boot",
    "phoenix": "phoenix-elixir", "elixir": "phoenix-elixir", "go": "go",
    ".net": "dotnet", "dotnet": "dotnet", "postgres": "postgres",
    "postgresql": "postgres", "mysql": "mysql", "mongodb": "mongodb", "mongo": "mongodb",
    "flutter": "flutter", "react native": "react-native", "docker": "docker",
    "kubernetes": "kubernetes", "k8s": "kubernetes", "terraform": "terraform",
    "swarm": "docker-swarm",
}


def stacks_in(text, valid):
    """Stack keys named by a chunk of header text, longest alias first."""
    low = " " + re.sub(r"[^a-z0-9.+ ]+", " ", (text or "").lower()) + " "
    hits = []
    for alias in sorted(STACK_ALIASES, key=len, reverse=True):
        key = STACK_ALIASES[alias]
        if key not in valid or key in hits:
            continue
        if re.search(r"(?<![a-z0-9])" + re.escape(alias) + r"(?![a-z0-9])", low):
            hits.append(key)
    return hits


# ---------------------------------------------------------------------------
# extractor 1 — topic specs (templates/packs/*/_topics.md)
# ---------------------------------------------------------------------------
def extract_topics(root, warn):
    rows = []
    for f in sorted(glob.glob(os.path.join(root, "templates/packs/*/_topics.md"))):
        owner = os.path.basename(os.path.dirname(f))
        r = rel(f, root)
        lines = read_lines(f)
        cur, start = None, 0
        blocks = []
        for i, ln in enumerate(lines, 1):
            if ln.startswith("- name:"):
                if cur is not None:
                    blocks.append((start, cur))
                cur, start = [ln], i
            elif cur is not None:
                if ln.startswith("- ") or ln.startswith("#") or ln.startswith("```"):
                    blocks.append((start, cur))
                    cur = None
                else:
                    cur.append(ln)
        if cur is not None:
            blocks.append((start, cur))

        for lineno, block in blocks:
            body = "\n".join(block)
            name = re.match(r"^- name:\s*(\S+)", block[0]).group(1)

            def field(key):
                m = re.search(r"^\s+%s:\s*(.*)$" % re.escape(key), body, re.M)
                return m.group(1).strip() if m else ""

            kind = field("kind") or "unknown"
            if kind not in TOPIC_KINDS:
                warn("FAIL", "%s:%d — unknown topic kind '%s' (allowed: %s)"
                     % (r, lineno, kind, ", ".join(sorted(TOPIC_KINDS))))
            elif kind not in TOPIC_KIND_PREFERRED:
                warn("WARN", "%s:%d — topic '%s' uses minority kind '%s' (vocabulary drift)"
                     % (r, lineno, name, kind))
            rows.append(row(
                id="topic:%s:%s" % (owner, name),
                kind="topic-" + kind, scope="pack", owner=owner, name=name,
                path="%s:%d" % (r, lineno), anchor="- name: %s" % name,
                text=dedupe_text([name.replace("-", " "), kind, field("triggers"),
                                  field("sections"), field("extracts_from"),
                                  field("fallback")]),
            ))
    return rows


# ---------------------------------------------------------------------------
# extractor 2 — artifact frontmatter (packs, domains, core commands)
# ---------------------------------------------------------------------------
def extract_artifacts(root, valid_stacks):
    rows = []
    sources = [("templates/packs", "pack"), ("templates/domains", "domain")]
    for base, scope in sources:
        for kind_dir in ARTIFACT_DIRS:
            for f, stem in artifact_files(root, base, kind_dir):
                r = rel(f, root)
                parts = r.split("/")
                owner = parts[2]
                if stem.startswith("_"):
                    continue
                lines = read_lines(f)
                meta = frontmatter(lines)
                kind = meta.get("kind") or kind_dir.rstrip("s")
                stack = ""
                if kind_dir == "references":
                    kind = "reference"
                    stack = ",".join(stacks_in(stem, valid_stacks)) or \
                        (stem if stem in valid_stacks else "")
                rows.append(row(
                    id="%s:%s:%s" % (kind, owner, stem),
                    kind=kind, scope=scope, owner=owner,
                    name=meta.get("name") or stem, path=r, anchor="", stack=stack,
                    text=dedupe_text([stem.replace("-", " "), meta.get("name", ""),
                                      meta.get("description", ""), meta.get("applies-to", ""),
                                      meta.get("severity", ""), first_h1(lines)]),
                ))
    for f in sorted(glob.glob(os.path.join(root, "commands", "*.md"))):
        stem = os.path.basename(f)[:-3]
        if stem.startswith("_"):
            continue
        lines = read_lines(f)
        meta = frontmatter(lines)
        rows.append(row(
            id="command:core:%s" % stem, kind="command", scope="core",
            owner="core", name="/" + stem, path=rel(f, root), anchor="",
            text=dedupe_text([stem.replace("-", " "), meta.get("description", ""),
                              first_h1(lines)]),
        ))
    return rows


# ---------------------------------------------------------------------------
# extractor 3 — rule directives (one atomic assertion per bullet)
# ---------------------------------------------------------------------------
def extract_rule_directives(root):
    rows = []
    for base, scope in (("templates/packs", "pack"), ("templates/domains", "domain")):
        for f in sorted(glob.glob(os.path.join(root, base, "*", "rules", "*.md"))):
            r = rel(f, root)
            owner = r.split("/")[2]
            rule = os.path.basename(f)[:-3]
            section, n = None, 0
            for lineno, line in enumerate(read_lines(f), 1):
                h = HEADING_RE.match(line)
                if h:
                    section = h.group(2)
                    continue
                if not section or not DIRECTIVE_SECTION_RE.match(clean(section)):
                    continue
                b = BULLET_RE.match(line)
                if not b:
                    continue
                body = clean(b.group(1))
                if len(body) < 8:
                    continue
                n += 1
                rows.append(row(
                    id="rule-directive:%s:%s:%d" % (owner, rule, n),
                    kind="rule-directive", scope=scope, owner=owner,
                    name="%s § %s" % (rule, clean(section)),
                    path="%s:%d" % (r, lineno), anchor=section,
                    text=body,
                ))
    return rows


# ---------------------------------------------------------------------------
# extractor 4 — registry tables (already hand-maintained catalogs)
# ---------------------------------------------------------------------------
def extract_registries(root):
    rows = []
    for r in REGISTRY_FILES:
        f = os.path.join(root, r)
        if not os.path.isfile(f):
            continue
        registry = os.path.basename(r)[:-3].lstrip("_")
        family = r.split("/")[1] if r.startswith("templates/") else registry
        prev, header, section = "", None, ""
        for lineno, line in enumerate(read_lines(f), 1):
            h = HEADING_RE.match(line)
            if h:
                section = h.group(2)
            if TABLE_SEP_RE.match(line):
                header = prev
                continue
            if not (line.startswith("|") and header):
                prev = line
                continue
            cells = [clean(c) for c in line.strip().strip("|").split("|")]
            if not cells or not cells[0]:
                prev = line
                continue
            hdr = [clean(c) for c in header.strip().strip("|").split("|")]
            key = cells[0]
            rows.append(row(
                id="catalog-row:%s:%s" % (registry, key[:60]),
                kind="catalog-row", scope="registry", owner=registry, name=key,
                path="%s:%d" % (r, lineno), anchor=section,
                text=dedupe_text([key.replace("-", " ")] + cells[1:] + hdr[1:] + [family]),
            ))
            prev = line
    return rows


# ---------------------------------------------------------------------------
# extractor 5 — trigger vocabulary (name + one-line semantics)
# ---------------------------------------------------------------------------
def extract_triggers(root):
    rows = []
    f = os.path.join(root, TRIGGER_VOCAB)
    if not os.path.isfile(f):
        return rows
    section = ""
    for lineno, line in enumerate(read_lines(f), 1):
        h = HEADING_RE.match(line)
        if h:
            section = h.group(2)
            continue
        m = TRIGGER_BULLET_RE.match(line)
        if not m:
            continue
        name = m.group(1).strip()
        if not re.match(r"^[a-z_][A-Za-z0-9_:<>\[\], .|]*$", name):
            continue
        rows.append(row(
            id="trigger:vocabulary:%s" % name[:60], kind="trigger", scope="registry",
            owner="trigger-vocabulary", name=name,
            path="%s:%d" % (TRIGGER_VOCAB, lineno), anchor=section,
            text=dedupe_text([name.replace("_", " "), m.group(2), section]),
        ))
    return rows


# ---------------------------------------------------------------------------
# extractor 6 — business-domain checklist items
# ---------------------------------------------------------------------------
def extract_domain_checklists(root):
    rows = []
    for f in sorted(glob.glob(os.path.join(root, "templates/business-domains/*/*.md"))):
        r = rel(f, root)
        owner = os.path.basename(os.path.dirname(f))
        doc = os.path.basename(f)[:-3]
        if doc.startswith("_") or owner.startswith("_"):
            continue
        section, n = "", 0
        for lineno, line in enumerate(read_lines(f), 1):
            h = HEADING_RE.match(line)
            if h:
                section = h.group(2)
                continue
            m = CHECKLIST_RE.match(line)
            if not m:
                continue
            body = clean(m.group(1))
            if len(body) < 4:
                continue
            n += 1
            rows.append(row(
                id="domain-checklist:%s:%s:%d" % (owner, doc, n),
                kind="domain-checklist", scope="business-domain", owner=owner,
                name="%s § %s" % (doc, clean(section)) if section else doc,
                path="%s:%d" % (r, lineno), anchor=section,
                text=dedupe_text([body, owner.replace("-", " "), doc.replace("-", " ")]),
            ))
    return rows


# ---------------------------------------------------------------------------
# extractor 7 — closure verbs / drift classes (unordered set members)
# ---------------------------------------------------------------------------
def extract_closure_verbs(root):
    rows = []
    for kind_dir in ("skills", "commands", "rules"):
        for f, doc in artifact_files(root, "templates/packs", kind_dir):
            r = rel(f, root)
            owner = r.split("/")[2]
            lines = read_lines(f)
            hits = [(i, m.group(1)) for i, m in
                    ((i, CLOSURE_VERB_RE.match(ln)) for i, ln in enumerate(lines, 1)) if m]
            if len(hits) < 3:
                continue          # <3 kebab-numbered headings is not a vocabulary
            for idx, (lineno, verb) in enumerate(hits):
                end = hits[idx + 1][0] - 1 if idx + 1 < len(hits) else min(lineno + 24, len(lines))
                body = " ".join(clean(x) for x in lines[lineno:end])
                rows.append(row(
                    id="closure-verb:%s:%s:%s" % (owner, doc, verb),
                    kind="closure-verb", scope="pack", owner=owner, name=verb,
                    path="%s:%d" % (r, lineno), anchor=doc,
                    text=dedupe_text([verb.replace("-", " "), body[:600]]),
                ))
    return rows


# ---------------------------------------------------------------------------
# extractor 8 — STACK.md substitution tables (the --stack flag's native data)
# ---------------------------------------------------------------------------
def extract_stack_substitutions(root, valid_stacks):
    rows = []
    for f in sorted(glob.glob(os.path.join(root, "templates/packs/*/STACK.md"))):
        r = rel(f, root)
        owner = os.path.basename(os.path.dirname(f))
        prev, header, section = "", None, ""
        for lineno, line in enumerate(read_lines(f), 1):
            h = HEADING_RE.match(line)
            if h:
                section = h.group(2)
            if TABLE_SEP_RE.match(line):
                header = prev
                continue
            if not (line.startswith("|") and header):
                prev = line
                continue
            cells = [clean(c) for c in line.strip().strip("|").split("|")]
            hdr = [clean(c) for c in header.strip().strip("|").split("|")]
            if not cells or not cells[0]:
                prev = line
                continue
            # Last column of a substitution table names the abstract concept.
            concept = cells[-1] if len(cells) > 1 else cells[0]
            stacks = []
            for hc in hdr:
                for s in stacks_in(hc, valid_stacks):
                    if s not in stacks:
                        stacks.append(s)
            rows.append(row(
                id="stack-subst:%s:%s" % (owner, concept[:60] or str(lineno)),
                kind="stack-subst", scope="pack", owner=owner, name=concept,
                path="%s:%d" % (r, lineno), anchor=section,
                stack=",".join(stacks),
                text=dedupe_text([concept] + cells + hdr),
            ))
            prev = line
    return rows


# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------
def source_files(root):
    """Every file the catalog is derived from — the freshness fingerprint's input."""
    pats = [
        "templates/packs/*/_topics.md",
        "templates/packs/*/STACK.md",
        "templates/business-domains/*/*.md",
        "commands/*.md",
        TRIGGER_VOCAB,
    ]
    out = set()
    for pat in pats:
        out.update(glob.glob(os.path.join(root, pat)))
    for base in ("templates/packs", "templates/domains"):
        for d in ARTIFACT_DIRS:
            out.update(f for f, _ in artifact_files(root, base, d))
    for r in REGISTRY_FILES:
        p = os.path.join(root, r)
        if os.path.isfile(p):
            out.add(p)
    return sorted(out)


def build(root, warn=None):
    """Extract every row. Deterministic: sorted globs, stable sort, no dict iteration order."""
    if warn is None:
        warn = lambda level, msg: None
    valid = stack_keys(root)
    rows = []
    rows += extract_topics(root, warn)
    rows += extract_artifacts(root, valid)
    rows += extract_rule_directives(root)
    rows += extract_registries(root)
    rows += extract_triggers(root)
    rows += extract_domain_checklists(root)
    rows += extract_closure_verbs(root)
    rows += extract_stack_substitutions(root, valid)
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
    """Integrity gate. `out_is_explicit` promotes a stale on-disk catalog from WARN to FAIL:
    the default path is a scratch dump under tmp/, so a leftover copy going stale is not a
    defect — but a catalog someone deliberately writes somewhere IS expected to stay fresh."""
    problems, warnings = [], []

    def warn(level, msg):
        (problems if level == "FAIL" else warnings).append(msg)

    rows = build(root, warn)
    print("[1] extraction")
    print("    %d rows from %d source files" % (len(rows), len(source_files(root))))

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

    print("[5] topic `kind:` vocabulary")
    print("    %d FAIL / %d WARN (see below)"
          % (sum(1 for p in problems if "unknown topic kind" in p),
             sum(1 for w in warnings if "minority kind" in w)))

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
            msg = "%s is stale — rerun gen-pack-catalog.py" % out_path
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
    print("\ncatalog check: OK (%d rows, %d warnings)" % (len(rows), len(warnings)))
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv=None):
    ap = argparse.ArgumentParser(description="Extract the repo's row-shaped metadata catalog.")
    ap.add_argument("--repo-root", default=REPO_ROOT)
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
        by_scope = Counter(r["scope"] for r in rows)
        print("  scopes: " + ", ".join("%s=%d" % kv for kv in sorted(by_scope.items())))
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
