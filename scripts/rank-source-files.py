#!/usr/bin/env python3
"""rank-source-files.py — order a repo's source files by how much they teach about it.

WHY THIS EXISTS. `extract-codebase-overview` caps its walk on a large repo, and the cap it
declared was "cap walk depth to 4; sample by file count". Depth in the directory tree is a
TOPOLOGICAL ACCIDENT: it measures how deeply someone nested a folder, not how much the file
matters. In a workspace laid out `packages/<pkg>/src/modules/<m>/service.ts` every service is at
depth 5 and the whole layer is dropped, while a top-level `scripts/` folder is kept in full. The
sample was disclosed honestly — `[SAMPLED: <seen>/<present>]` and check 7 see to that — but an
honestly-reported bad sample is still a bad sample.

What a reader actually wants, given a budget of N files out of 12,000, is the N that the rest of
the codebase is built on. That is computable, exactly and cheaply, from imports the files already
declare. No model, no embedding, no heuristic about names.

THE TWO KINDS, and why one ranking is not enough. Ranking purely by "most imported" surfaces
shared abstractions and buries every entry point, because a route file, a CLI command and a job
handler are imported by nothing — they are where the program STARTS, and they describe the
system's surface better than any util does. So files are ranked in two bands:

    hub    imported by others. Rank: distinct importing DIRECTORIES first, then importer count.
           Directories first is the point: a file pulled in by 40 files from one folder is a
           local helper; one pulled in by 12 files from 9 folders is load-bearing.
    root   imports others, imported by none. Rank: number of distinct modules it reaches.

With --limit, the budget splits 75/25 hub/root. The split is a judgement, stated here so it can
be argued with, and printed in the header so a reader knows what they got.

HONEST LIMITS — read these before trusting the order:
  * TypeScript / JavaScript and Python only. Any other extension is NOT walked and does not
    appear in the census at all — so on a Go or Java repo `present` reads 0 and the ranking is
    empty rather than wrong. This tool does not pretend to parse a language it cannot, and it
    does not pretend to have counted one either.
  * A specifier that does not resolve to a file in the repo is dropped, not guessed. Package
    imports, build aliases that RENAME (`@core/*` → `src/billing/*` via tsconfig), and generated
    barrels therefore contribute nothing. Under-counting is the intended failure direction: it
    demotes a file, it never invents importance.
  * `in_degree` counts static imports only. A file reached solely through DI, a registry, or a
    string-keyed dynamic require looks isolated here and will rank low. That is a real blind
    spot, not a rounding error.

Usage:
  rank-source-files.py <repo> [--limit N] [--format table|list|json] [--include-tests]

Exit: 0 ok · 2 usage error.
"""

import argparse
import json
import os
import re
import sys

TS_EXT = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".mts", ".cts")
PY_EXT = (".py",)
SOURCE_EXT = TS_EXT + PY_EXT
PRUNE = {".git", "node_modules", "__pycache__", ".venv", "venv", "dist", "build", ".next",
         ".mypy_cache", ".pytest_cache", "vendor", "target", ".tox", "coverage"}
TEST_HINT = re.compile(r'(^|/)(tests?|__tests__|spec)(/|$)|\.(test|spec)\.[a-z]+$|(^|/)test_[^/]+\.py$')

TS_IMPORT = re.compile(r"""(?:^|[\s;{(=])(?:import|export)\s[^'"]*?from\s*['"]([^'"]+)['"]"""
                       r"""|(?:^|[\s;{(=])import\s*['"]([^'"]+)['"]"""
                       r"""|\brequire\s*\(\s*['"]([^'"]+)['"]\s*\)"""
                       r"""|\bimport\s*\(\s*['"]([^'"]+)['"]\s*\)""", re.M)
PY_IMPORT = re.compile(r'^[ \t]*(?:from[ \t]+([.\w]+)[ \t]+import|import[ \t]+([.\w]+))', re.M)


def walk(root, include_tests):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in PRUNE and not d.startswith("."))
        for name in sorted(filenames):
            if not name.endswith(SOURCE_EXT):
                continue
            rel = os.path.relpath(os.path.join(dirpath, name), root).replace(os.sep, "/")
            if not include_tests and TEST_HINT.search(rel):
                continue
            out.append(rel)
    return out


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def specifiers(rel, text):
    if rel.endswith(PY_EXT):
        return [a or b for a, b in PY_IMPORT.findall(text) if (a or b)]
    return [next(g for g in m if g) for m in TS_IMPORT.findall(text)]


# A tsconfig/jsconfig `paths` entry RENAMES rather than shortens (`@app/database/*` ->
# `libs/database/src/*`), so no sigil rule can resolve it — the mapping exists only in the config
# file. Reading that file is deterministic: it is the same table the compiler and bundler use. When
# it is missing, unparseable, or has no `paths`, aliases stay empty and resolution behaves exactly
# as it did before — silent, never inventing a target.
JSONC_BLOCK = re.compile(r'/\*.*?\*/', re.S)
JSONC_LINE = re.compile(r'(?m)(?<![:"\w])//[^\n]*')
TRAILING_COMMA = re.compile(r',(\s*[}\]])')


def _read_jsonc(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            raw = fh.read()
    except OSError:
        return None
    raw = JSONC_BLOCK.sub("", raw)
    raw = JSONC_LINE.sub("", raw)
    raw = TRAILING_COMMA.sub(r"\1", raw)
    try:
        return json.loads(raw)
    except ValueError:
        return None                       # unparseable is not a licence to guess


# Jest's moduleNameMapper is a REGEX table, not a glob one, so only the shapes that convert
# EXACTLY are taken. Anything else is left to alias_blind_spots() to disclose. Guessing at a
# regex is how a resolver starts inventing edges.
MNM_SHAPES = (
    # ^pfx(|/.*)$ -> tgt/$1   and   ^pfx/(.*)$ -> tgt/$1   and   ^pfx$ -> tgt
    re.compile(r'^\^(?P<pfx>[^()\[\]{}|+?*\\^$]+?)/?\(\|?/?\.\*\)\$$'),
    re.compile(r'^\^(?P<pfx>[^()\[\]{}|+?*\\^$]+?)\$$'),
)


def _mnm_rules(mapper, root):
    """moduleNameMapper -> the same (prefix, suffix, target) rules, for exactly-convertible keys."""
    out, skipped = [], 0
    for key, val in mapper.items():
        if not isinstance(val, str):
            skipped += 1
            continue
        m = MNM_SHAPES[0].match(key) or MNM_SHAPES[1].match(key)
        if not m:
            skipped += 1
            continue
        pfx = m.group("pfx")
        tgt = val.replace("<rootDir>/", "").replace("<rootDir>", "")
        wild = MNM_SHAPES[0].match(key) is not None
        if wild:
            # `tgt/$1` is the only replacement shape that round-trips to a `*` template.
            if "$1" not in tgt:
                skipped += 1
                continue
            tmpl = tgt.replace("$1", "*").replace("//", "/").rstrip("/")
            if "*" not in tmpl:
                skipped += 1
                continue
            out.append((pfx + "/", "", [tmpl]))
        else:
            if "$" in tgt:
                skipped += 1
                continue
            out.append((pfx, "", [tgt]))
    return out, skipped


def package_json_aliases(root):
    """jest.moduleNameMapper from package.json — JSON, so parseable without executing anything."""
    pj = os.path.join(root, "package.json")
    cfg = _read_jsonc(pj)
    if not isinstance(cfg, dict):
        return [], 0
    jest = cfg.get("jest")
    if not isinstance(jest, dict):
        return [], 0
    mapper = jest.get("moduleNameMapper")
    if not isinstance(mapper, dict):
        return [], 0
    return _mnm_rules(mapper, root)


# Config files that DECLARE aliases in JavaScript. Reading them would mean executing JS or
# shipping a JS parser; a regex scrape would be a guess, and a guessed alias in the boundary hook
# refuses legitimate writes. So they are DETECTED and REPORTED, never parsed. A disclosed blind
# spot can be worked around; a silent one cannot.
JS_ALIAS_CONFIGS = ("vite.config.ts", "vite.config.js", "vite.config.mjs",
                    "webpack.config.js", "webpack.config.ts", "rollup.config.js",
                    "jest.config.js", "jest.config.ts", "next.config.js", "craco.config.js")
JS_ALIAS_HINT = re.compile(r'\balias\b|moduleNameMapper')


def alias_blind_spots(root):
    """Config files that look like they declare aliases and that nothing here can read."""
    out = []
    for name in JS_ALIAS_CONFIGS:
        p = os.path.join(root, name)
        if not os.path.isfile(p):
            continue
        try:
            with open(p, encoding="utf-8", errors="replace") as fh:
                if JS_ALIAS_HINT.search(fh.read(200000)):
                    out.append(name)
        except OSError:
            continue
    return out


def path_aliases(root, _depth=0, _file=None):
    """[(prefix, suffix, [target templates])] from tsconfig/jsconfig `paths`, longest first.

    `extends` is followed (capped), because a monorepo routinely keeps `paths` in a base config.
    Targets are made repo-relative through `baseUrl`, so the caller can match them against the
    file index directly.
    """
    if _depth > 4:
        return []
    if _file is None:
        for name in ("tsconfig.json", "jsconfig.json"):
            cand = os.path.join(root, name)
            if os.path.isfile(cand):
                _file = cand
                break
        else:
            # No tsconfig is not "no aliases": a project can declare them only in package.json's
            # jest block. Returning [] here made that table unreachable, which the fixture caught.
            return package_json_aliases(root)[0]
    cfg = _read_jsonc(_file)
    if not isinstance(cfg, dict):
        return []

    rules = []
    ext = cfg.get("extends")
    if isinstance(ext, str) and not ext.startswith("@") and "/" not in ext[:1]:
        parent = os.path.normpath(os.path.join(os.path.dirname(_file), ext))
        if not parent.endswith(".json"):
            parent += ".json"
        if os.path.isfile(parent):
            rules.extend(path_aliases(root, _depth + 1, parent))

    co = cfg.get("compilerOptions")
    if isinstance(co, dict):
        base_url = co.get("baseUrl") or "."
        base_dir = os.path.normpath(os.path.join(os.path.dirname(_file), base_url))
        paths = co.get("paths")
        if isinstance(paths, dict):
            for key, targets in paths.items():
                if not isinstance(targets, list) or key.count("*") > 1:
                    continue
                pre, _, suf = key.partition("*")
                tmpl = []
                for t in targets:
                    if not isinstance(t, str) or t.count("*") > 1:
                        continue
                    abs_t = os.path.normpath(os.path.join(base_dir, t))
                    r = os.path.relpath(abs_t, root).replace(os.sep, "/")
                    if not r.startswith(".."):
                        tmpl.append(r)
                if tmpl:
                    rules.append((pre, suf, tmpl))
    if _depth == 0:
        pj_rules, _ = package_json_aliases(root)
        rules.extend(pj_rules)
    # Longest literal prefix wins, which is TypeScript's own precedence rule.
    rules.sort(key=lambda r: len(r[0]), reverse=True)
    return rules


def apply_aliases(spec, aliases):
    """Every repo-relative base path `spec` could name under `paths`. Empty when none matches."""
    out = []
    for pre, suf, targets in aliases:
        if not spec.startswith(pre) or not spec.endswith(suf):
            continue
        if len(spec) < len(pre) + len(suf):
            continue
        star = spec[len(pre):len(spec) - len(suf)] if (pre or suf) else spec
        for t in targets:
            out.append(t.replace("*", star) if "*" in t else t)
        if out:
            break                          # first (longest) matching rule wins, as tsc does
    return out


def resolve(spec, rel, index, aliases=()):
    """Specifier → a repo-relative source path, or None. Never guesses."""
    here = os.path.dirname(rel)
    if rel.endswith(PY_EXT):
        if spec.startswith("."):
            up = len(spec) - len(spec.lstrip("."))
            base = here
            for _ in range(up - 1):
                base = os.path.dirname(base)
            cand = os.path.normpath(os.path.join(base, spec.lstrip(".").replace(".", "/")))
        else:
            cand = spec.replace(".", "/")
        candidates = [cand + ".py", cand + "/__init__.py"]
    else:
        if spec.startswith("."):
            bases = [os.path.normpath(os.path.join(here, spec))]
        else:
            # The config table first: it is the only thing that can undo a RENAMING alias, and
            # it is read, not inferred. With no tsconfig the list is empty and the two rules
            # below are exactly the behaviour that shipped before aliases existed.
            bases = list(apply_aliases(spec, aliases))
            if spec[:2] in ("@/", "~/", "#/"):
                bases.append(spec[2:])
            elif "/" in spec and not spec.startswith("@"):
                bases.append(spec)            # rooted, e.g. `src/billing/charge`
        if not bases:
            return None                       # bare package name, or an alias nothing declares
        candidates = []
        for cand in bases:
            cand = cand.replace(os.sep, "/")
            _, ext = os.path.splitext(cand)
            if ext in SOURCE_EXT:
                candidates.append(cand)
            for e in TS_EXT:
                candidates.append(cand + e)
                candidates.append(cand + "/index" + e)
    for c in candidates:
        c = c.lstrip("./")
        if c in index:
            return c
        for prefix in ("src/", "app/", "lib/"):
            if (prefix + c) in index:
                return prefix + c
    return None


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("repo")
    ap.add_argument("--limit", type=int, default=0, help="0 = rank everything")
    ap.add_argument("--format", choices=("table", "list", "json"), default="table")
    ap.add_argument("--include-tests", action="store_true")
    ap.add_argument("--hub-share", type=float, default=0.75,
                    help="fraction of --limit given to hubs (default 0.75)")
    ap.add_argument("--emit-edges", metavar="PATH",
                    help="write every RESOLVED import edge as TSV (kind, importer, imported, '') "
                         "and exit. A specifier that did not resolve is not an edge and is not "
                         "written; the count of those is reported on stderr rather than dropped "
                         "silently. --limit does not apply: a ranking is a selection, a graph is "
                         "not, and emitting only the top N would produce a map whose missing "
                         "edges look like absent dependencies.")
    args = ap.parse_args()

    root = os.path.abspath(args.repo)
    if not os.path.isdir(root):
        sys.stderr.write("no such directory: %s\n" % args.repo)
        return 2

    files = walk(root, args.include_tests)
    index = set(files)
    aliases = path_aliases(root)
    blind = alias_blind_spots(root)
    parseable = [f for f in files if f.endswith(SOURCE_EXT)]

    importers = {f: set() for f in files}          # file -> set of files importing it
    out_deg = {f: set() for f in files}
    unresolved = 0
    for f in parseable:
        for spec in specifiers(f, read(os.path.join(root, f))):
            tgt = resolve(spec, f, index, aliases)
            if tgt is None or tgt == f:
                unresolved += 1
                continue
            importers[tgt].add(f)
            out_deg[f].add(tgt)

    if args.emit_edges:
        with open(args.emit_edges, "w", encoding="utf-8") as fh:
            for f in sorted(out_deg):
                for tgt in sorted(out_deg[f]):
                    fh.write("code\t%s\t%s\t\n" % (f, tgt))
        n = sum(len(v) for v in out_deg.values())
        sys.stderr.write("%d resolved edge(s) written; %d specifier(s) did not resolve "
                         "(dropped, not guessed); %d alias rule(s) read from "
                         "tsconfig/package.json\n" % (n, unresolved, len(aliases)))
        if blind:
            sys.stderr.write("NOT READ: %s declare aliases in JavaScript. Reading them means "
                             "executing JS; a regex scrape would be a guess. Edges through those "
                             "aliases are MISSING, not absent.\n" % ", ".join(blind))
        return 0

    rows = []
    for f in files:
        ins = importers[f]
        dirs = {os.path.dirname(i) for i in ins}
        kind = "hub" if ins else ("root" if out_deg[f] else "isolated")
        rows.append({
            "path": f, "kind": kind,
            "importers": len(ins), "importer_dirs": len(dirs), "imports": len(out_deg[f]),
        })

    hubs = sorted([r for r in rows if r["kind"] == "hub"],
                  key=lambda r: (-r["importer_dirs"], -r["importers"], r["path"]))
    roots = sorted([r for r in rows if r["kind"] == "root"],
                   key=lambda r: (-r["imports"], r["path"]))
    rest = sorted([r for r in rows if r["kind"] == "isolated"], key=lambda r: r["path"])

    if args.limit:
        # Clamp first. A share outside [0,1] made n_root negative, and `roots[:negative]` slices
        # from the END of the list rather than returning nothing — so `--limit 8 --hub-share 1.5`
        # returned 20 rows, silently over-spending a budget the caller set precisely.
        if not 0.0 <= args.hub_share <= 1.0:
            sys.stderr.write("--hub-share must be between 0 and 1 (got %r)\n" % args.hub_share)
            return 2
        n_hub = min(len(hubs), int(round(args.limit * args.hub_share)))
        n_root = min(len(roots), args.limit - n_hub)
        n_hub = min(len(hubs), args.limit - n_root)
        picked = hubs[:n_hub] + roots[:n_root]
        picked += rest[:max(0, args.limit - len(picked))]
    else:
        picked = hubs + roots + rest

    if blind:
        sys.stderr.write("NOT READ: %s declare aliases in JavaScript. Reading them means executing "
                         "JS; a regex scrape would be a guess. Edges through those aliases are "
                         "MISSING, not absent.\n" % ", ".join(blind))

    if args.format == "json":
        print(json.dumps({
            "present": len(files), "selected": len(picked),
            "hubs": len(hubs), "roots": len(roots), "isolated": len(rest),
            "unresolved_specifiers": unresolved,
            "alias_rules": len(aliases), "alias_configs_not_read": blind,
            "rows": picked}, indent=2))
        return 0

    if args.format == "list":
        for r in picked:
            print(r["path"])
        return 0

    print("# rank-source-files — %d/%d source files selected" % (len(picked), len(files)))
    print("# hubs %d · roots %d · isolated %d · %d specifiers did not resolve (dropped, not "
          "guessed) · %d alias rule(s) read from tsconfig/package.json"
          % (len(hubs), len(roots), len(rest), unresolved, len(aliases)))
    print("# walk_scope: centrality-ranked (importing dirs, then importer count); "
          "hub share %.2f" % args.hub_share)
    print("%-4s %-9s %7s %7s %7s  %s" % ("#", "kind", "impBy", "impDirs", "imports", "path"))
    for i, r in enumerate(picked, 1):
        print("%-4d %-9s %7d %7d %7d  %s"
              % (i, r["kind"], r["importers"], r["importer_dirs"], r["imports"], r["path"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
