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


def resolve(spec, rel, index):
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
            cand = os.path.normpath(os.path.join(here, spec))
        elif spec[:2] in ("@/", "~/", "#/"):
            cand = spec[2:]
        elif "/" in spec and not spec.startswith("@"):
            cand = spec                       # rooted, e.g. `src/billing/charge`
        else:
            return None                       # bare package name
        cand = cand.replace(os.sep, "/")
        base, ext = os.path.splitext(cand)
        candidates = [cand] if ext in SOURCE_EXT else []
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
    args = ap.parse_args()

    root = os.path.abspath(args.repo)
    if not os.path.isdir(root):
        sys.stderr.write("no such directory: %s\n" % args.repo)
        return 2

    files = walk(root, args.include_tests)
    index = set(files)
    parseable = [f for f in files if f.endswith(SOURCE_EXT)]

    importers = {f: set() for f in files}          # file -> set of files importing it
    out_deg = {f: set() for f in files}
    unresolved = 0
    for f in parseable:
        for spec in specifiers(f, read(os.path.join(root, f))):
            tgt = resolve(spec, f, index)
            if tgt is None or tgt == f:
                unresolved += 1
                continue
            importers[tgt].add(f)
            out_deg[f].add(tgt)

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

    if args.format == "json":
        print(json.dumps({
            "present": len(files), "selected": len(picked),
            "hubs": len(hubs), "roots": len(roots), "isolated": len(rest),
            "unresolved_specifiers": unresolved, "rows": picked}, indent=2))
        return 0

    if args.format == "list":
        for r in picked:
            print(r["path"])
        return 0

    print("# rank-source-files — %d/%d source files selected" % (len(picked), len(files)))
    print("# hubs %d · roots %d · isolated %d · %d specifiers did not resolve (dropped, not guessed)"
          % (len(hubs), len(roots), len(rest), unresolved))
    print("# walk_scope: centrality-ranked (importing dirs, then importer count); "
          "hub share %.2f" % args.hub_share)
    print("%-4s %-9s %7s %7s %7s  %s" % ("#", "kind", "impBy", "impDirs", "imports", "path"))
    for i, r in enumerate(picked, 1):
        print("%-4d %-9s %7d %7d %7d  %s"
              % (i, r["kind"], r["importers"], r["importer_dirs"], r["imports"], r["path"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
