#!/usr/bin/env python3
"""build-graph.py — assemble ONE traversable graph from edges the gates have already proven.

WHAT IT ANSWERS: "I am about to change this file — who breaks?", "how does A reach B?",
"what sits at the centre of this corpus?". Traversal questions, answered without opening
a single one of the files involved.
WHAT IT DOES NOT ANSWER: what any file SAYS. Every node is a repo path and nothing more.
Read the file before acting; this graph routes you to it, it does not summarise it.

  python3 scripts/build-graph.py --stats
  python3 scripts/build-graph.py --who-breaks templates/capabilities.md
  python3 scripts/build-graph.py --neighbors commands/setup-project.md
  python3 scripts/build-graph.py --path commands/setup-project.md templates/quick-start.md
  python3 scripts/build-graph.py --central --limit=15
  python3 scripts/build-graph.py --json
  python3 scripts/build-graph.py --check          # build + invariants, for CI

TWO CORPORA, ONE ENGINE — the same split scripts/pack-search.py already makes.

  --corpus=self     (default) THIS repo's markdown. Edges come from the two gates below, so
                    every edge in it is one CI enforces.
  --corpus=project  a CONSUMING project's SOURCE CODE, via scripts/rank-source-files.py, which
                    resolves TS/JS and Python imports from the AST. Cached in that project's
                    own .claude/ tree, never here.

  python3 scripts/build-graph.py --corpus=project --repo=/path/to/app --stats
  python3 scripts/build-graph.py --corpus=project --repo=/path/to/app --who-breaks src/lib/db.ts

THE HONESTY DIFFERENCE, which is printed and never buried. A `self` edge was PROVEN by a gate
that fails CI when it breaks. A `project` edge was RESOLVED from an import statement: deterministic,
no model, nothing guessed — but no gate in this repo runs over that code, so nothing outside the
resolver double-checks it. A specifier that does not resolve is dropped and counted, never guessed
at. `--stats` prints which of the two you are looking at, because a reader who cannot tell
"verified" from "derived" will trust both equally, and only one has earned it.

WHY A GRAPH AND NOT A SECOND PARSER. The two edge kinds below are each already parsed, and
parsed HARD — protected commas, brace expansion, one-hop indirection, mode qualifiers. A
fresh parser here would be a second opinion that can disagree with the gate, and the day it
disagrees is the day the graph lies. So this script parses nothing. It runs each gate with
`--emit-edges` and merges what the gate emitted at the exact line where it PROVED the edge.
An edge the gate could not verify — a baselined claim, a prose fragment, a vocabulary input —
is not in this graph, and `--stats` prints how many were left out rather than hiding the gap.

  import   an `imported-by:` back-edge      verified by scripts/lint-import-edges.sh
  phase    a producer -> consumer handoff   verified by scripts/lint-phase-dag.sh

WHY IT CANNOT GO STALE. The graph is never committed. It is cached under tmp/ keyed on a
sha256 of this file, both gate scripts, and the size+mtime of every markdown file they read.
Edit any input and the fingerprint moves, the cache is rejected, and the next query rebuilds
from the gates. This is the same contract scripts/pack-search.py holds for its BM25 index;
see docs/RETRIEVAL.md for why a derived artifact in this repo is always a cache, never a source.

Notes: pure stdlib. Python 3.10+, matching the repo floor.
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from collections import deque

# Bump when the edge schema or the emitting gates change, so stale caches are rejected.
GRAPH_FORMAT = 1
CACHE_REL = "tmp/graph/graph.json"

# Each gate, and the roots whose markdown it reads. The roots feed the fingerprint, so a file
# a gate would newly see is a file that invalidates the cache.
GATES = (
    ("import", "scripts/lint-import-edges.sh", ("templates", "commands", "docs")),
    ("phase", "scripts/lint-phase-dag.sh", ("templates/phases",)),
)

# Where each corpus caches, and what it is honestly called in every report.
CORPORA = {
    "self": {
        "cache": CACHE_REL,
        "provenance": "gate-verified",
        "note": "every edge was proven by a CI gate that fails when it breaks",
    },
    "project": {
        "cache": ".claude/_graph.json",
        "provenance": "AST-resolved, NOT gate-verified",
        "note": "edges resolved from import statements — deterministic, no model, "
                "unresolved specifiers dropped and counted; but no gate re-checks them",
    },
}
SOURCE_EXT = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".mts", ".cts", ".py")
PRUNE = {".git", "node_modules", "__pycache__", ".venv", "venv", "dist", "build", ".next",
         ".claude", "tmp", "coverage", "vendor", "target"}
# Read by lint-import-edges.sh to suppress claims it cannot verify. Its content changes which
# edges are emitted, so it belongs in the fingerprint even though it is not markdown.
EXTRA_INPUTS = ("scripts/_import-edge-baseline.txt",)


def repo_root():
    here = os.path.realpath(__file__)
    return os.path.dirname(os.path.dirname(here))


def project_source_files(repo):
    """Every file the ranker would parse, in a stable order. Mirrors its walk and PRUNE set;
    a directory it skips is a directory whose edits cannot change an edge."""
    out = []
    for dirpath, dirnames, filenames in os.walk(repo):
        dirnames[:] = sorted(d for d in dirnames if d not in PRUNE and not d.startswith("."))
        for fn in sorted(filenames):
            if fn.endswith(SOURCE_EXT):
                out.append(os.path.relpath(os.path.join(dirpath, fn), repo))
    return sorted(out)


def source_files(root, corpus="self", repo=None):
    """Every file whose content can change an emitted edge, in a stable order."""
    if corpus == "project":
        return project_source_files(repo)
    seen = set()
    for _, script, roots in GATES:
        seen.add(script)
        for r in roots:
            base = os.path.join(root, r)
            for dirpath, dirnames, filenames in os.walk(base):
                dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
                for fn in sorted(filenames):
                    if fn.endswith(".md"):
                        seen.add(os.path.relpath(os.path.join(dirpath, fn), root))
    for extra in EXTRA_INPUTS:
        if os.path.isfile(os.path.join(root, extra)):
            seen.add(extra)
    seen.add(os.path.relpath(os.path.realpath(__file__), root))
    return sorted(seen)


def fingerprint(root, files, corpus="self"):
    h = hashlib.sha256()
    h.update(("build-graph/%d/%s\n" % (GRAPH_FORMAT, corpus)).encode())
    for rel in files:
        st = os.stat(os.path.join(root, rel))
        h.update(("%s|%d|%d\n" % (rel, st.st_size, st.st_mtime_ns)).encode())
    return h.hexdigest()


def run_gates(root):
    """Run every gate with --emit-edges and return (edges, gate_status).

    A gate that FAILS still emits the edges it proved before failing, so the graph degrades to
    'what is still true' rather than vanishing. Its non-zero exit is recorded and surfaced.
    """
    edges, status = [], {}
    with tempfile.TemporaryDirectory() as td:
        for kind, script, _ in GATES:
            out = os.path.join(td, kind + ".tsv")
            proc = subprocess.run(
                ["bash", os.path.join(root, script), "--quiet",
                 "--repo-root=" + root, "--emit-edges=" + out],
                capture_output=True, text=True,
            )
            status[kind] = {"script": script, "exit": proc.returncode}
            if not os.path.isfile(out):
                status[kind]["error"] = (proc.stderr or proc.stdout or "").strip()[-400:]
                continue
            with open(out, encoding="utf-8") as fh:
                for line in fh:
                    parts = line.rstrip("\n").split("\t")
                    if len(parts) != 4 or not parts[1] or not parts[2]:
                        continue
                    k, src, dst, label = parts
                    edges.append({"kind": k, "from": src, "to": dst, "label": label})
    return edges, status


def run_ranker(root, repo):
    """One producer, one corpus: rank-source-files.py resolves the project's imports.

    --limit is deliberately NOT passed. Ranking selects; a graph must not, or the edges it
    happens to omit read as dependencies that do not exist.
    """
    edges, status = [], {}
    ranker = os.path.join(root, "scripts/rank-source-files.py")
    with tempfile.TemporaryDirectory() as td:
        out = os.path.join(td, "code.tsv")
        proc = subprocess.run([sys.executable, ranker, repo, "--emit-edges", out],
                              capture_output=True, text=True)
        err = (proc.stderr or "").strip()
        status["code"] = {"script": "scripts/rank-source-files.py", "exit": proc.returncode,
                          "detail": err[:200]}
        # The ranker discloses alias configs it cannot read. That disclosure has to survive into
        # the graph, or a project whose aliases live in vite.config.ts gets a quietly partial map.
        for line in err.splitlines():
            if line.startswith("NOT READ:"):
                status["code"]["not_read"] = line
        if os.path.isfile(out):
            with open(out, encoding="utf-8") as fh:
                for line in fh:
                    parts = line.rstrip("\n").split("\t")
                    if len(parts) == 4 and parts[1] and parts[2]:
                        edges.append({"kind": parts[0], "from": parts[1],
                                      "to": parts[2], "label": parts[3]})
        else:
            status["code"]["error"] = (proc.stderr or proc.stdout or "").strip()[-400:]
    return edges, status


def build(root, corpus="self", repo=None):
    base = repo if corpus == "project" else root
    files = source_files(root, corpus, repo)
    edges, status = (run_ranker(root, repo) if corpus == "project" else run_gates(root))
    nodes = sorted({e["from"] for e in edges} | {e["to"] for e in edges})
    return {
        "format": GRAPH_FORMAT,
        "corpus": corpus,
        "root": base,
        "provenance": CORPORA[corpus]["provenance"],
        "fingerprint": fingerprint(base, files, corpus),
        "source_file_count": len(files),
        "nodes": nodes,
        "edges": edges,
        "gates": status,
    }


def load(root, rebuild=False, corpus="self", repo=None):
    base = repo if corpus == "project" else root
    cache = os.path.join(base, CORPORA[corpus]["cache"])
    files = source_files(root, corpus, repo)
    fp = fingerprint(base, files, corpus)
    if not rebuild and os.path.isfile(cache):
        try:
            with open(cache, encoding="utf-8") as fh:
                g = json.load(fh)
            if (g.get("format") == GRAPH_FORMAT and g.get("fingerprint") == fp
                    and g.get("corpus") == corpus):
                return g, True
        except (OSError, ValueError):
            pass
    g = build(root, corpus, repo)
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    tmp = cache + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(g, fh, indent=1, sort_keys=True)
    os.replace(tmp, cache)
    return g, False


# ---------------------------------------------------------------- traversal

def adjacency(g, reverse=False):
    adj = {}
    for e in g["edges"]:
        a, b = (e["to"], e["from"]) if reverse else (e["from"], e["to"])
        adj.setdefault(a, []).append((b, e))
    return adj


def reachable(g, start, reverse=False):
    """BFS with the hop count that first reached each node."""
    adj = adjacency(g, reverse)
    seen, order, q = {start: 0}, [], deque([start])
    while q:
        cur = q.popleft()
        for nxt, _ in adj.get(cur, []):
            if nxt not in seen:
                seen[nxt] = seen[cur] + 1
                order.append((nxt, seen[nxt]))
                q.append(nxt)
    return order


def shortest_path(g, a, b):
    adj = adjacency(g)
    prev, q = {a: None}, deque([a])
    while q:
        cur = q.popleft()
        if cur == b:
            break
        for nxt, e in adj.get(cur, []):
            if nxt not in prev:
                prev[nxt] = (cur, e)
                q.append(nxt)
    if b not in prev:
        return None
    path, cur = [], b
    while prev[cur] is not None:
        par, e = prev[cur]
        path.append((par, cur, e))
        cur = par
    return list(reversed(path))


def known(g, path):
    if path in g["nodes"]:
        return True
    sys.stderr.write("not a node in this graph: %s\n" % path)
    tail = os.path.basename(path)
    near = [n for n in g["nodes"] if os.path.basename(n) == tail][:5]
    if near:
        sys.stderr.write("did you mean:\n" + "".join("  %s\n" % n for n in near))
    else:
        sys.stderr.write("a file with no verified edge is absent by design; --stats "
                         "reports what the gates could not verify.\n")
    return False


# ---------------------------------------------------------------- reporting

def print_stats(g, root):
    print("=== build-graph ===")
    print("Corpus: %s — %s" % (g.get("corpus", "self"), g.get("provenance", "")))
    print("Root:   %s\n" % g.get("root", root))
    kinds = {}
    for e in g["edges"]:
        kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
    print("nodes: %d · edges: %d (%s)"
          % (len(g["nodes"]), len(g["edges"]),
             " · ".join("%s %d" % (k, kinds[k]) for k in sorted(kinds))))
    print("built from %d source files" % g["source_file_count"])
    print("")
    for kind, st in sorted(g["gates"].items()):
        state = "ok" if st["exit"] == 0 else "FAILING (exit %d)" % st["exit"]
        print("  %-7s %-34s %s" % (kind, st["script"], state))
        if st.get("error"):
            print("          %s" % st["error"].replace("\n", " ")[:200])
        if st.get("not_read"):
            print("          %s" % st["not_read"])
    print("")
    print("provenance: %s." % CORPORA[g.get("corpus", "self")]["note"])
    if g.get("corpus") == "project":
        print("")
        print("READ THIS BEFORE TRUSTING AN EMPTY ANSWER. An edge exists here only where a")
        print("specifier RESOLVED to a file in this project. Dynamic imports, string-built")
        print("paths, DI containers, build aliases that rename rather than shorten, and every")
        print("language that is not TS/JS or Python produce no edge at all. `--who-breaks`")
        print("returning nothing means 'no import edge was resolved', never 'safe to change'.")
    else:
        print("")
        print("not in this graph, by design: any claim its gate could not verify — a baselined")
        print("back-edge, a prose fragment, a vocabulary input. Run each gate directly for the")
        print("counts it withholds; this graph carries only what CI enforces.")


def main():
    ap = argparse.ArgumentParser(add_help=True, description=__doc__.split("\n")[0])
    ap.add_argument("--repo-root", default=repo_root())
    ap.add_argument("--corpus", choices=("self", "project"), default="self")
    ap.add_argument("--repo", help="the consuming project's root (required for --corpus=project)")
    ap.add_argument("--rebuild", action="store_true", help="ignore the cache")
    ap.add_argument("--who-breaks", metavar="FILE",
                    help="every file that reaches FILE, transitively")
    ap.add_argument("--neighbors", metavar="FILE", help="one hop, both directions")
    ap.add_argument("--path", nargs=2, metavar=("FROM", "TO"))
    ap.add_argument("--central", action="store_true",
                    help="nodes ranked by degree")
    ap.add_argument("--limit", type=int, default=20,
                    help="cap the rows printed; 0 = no cap (default 20)")
    ap.add_argument("--stats", action="store_true")
    ap.add_argument("--json", action="store_true", help="dump the whole graph")
    ap.add_argument("--check", action="store_true", help="build + invariants, for CI")
    a = ap.parse_args()

    root = os.path.realpath(a.repo_root)
    repo = None
    if a.corpus == "project":
        if not a.repo:
            sys.stderr.write("--corpus=project needs --repo=<path to the project>\n")
            return 2
        repo = os.path.realpath(a.repo)
        if not os.path.isdir(repo):
            sys.stderr.write("no such directory: %s\n" % a.repo)
            return 2
        if a.check:
            sys.stderr.write("--check is a CI invariant over this repo's own gates; "
                             "it does not apply to --corpus=project.\n")
            return 2
    g, cached = load(root, rebuild=a.rebuild, corpus=a.corpus, repo=repo)

    if a.json:
        json.dump(g, sys.stdout, indent=1, sort_keys=True)
        print("")
        return 0

    if a.check:
        print("=== build-graph --check ===")
        problems = []
        if not g["edges"]:
            problems.append("graph is empty — no gate emitted an edge")
        for e in g["edges"]:
            for side in ("from", "to"):
                if not os.path.isfile(os.path.join(root, e[side])):
                    problems.append("edge names a path that is not on disk: %s" % e[side])
        for kind, st in g["gates"].items():
            if st["exit"] != 0:
                problems.append("%s gate exits %d — graph is partial" % (kind, st["exit"]))
        g2, _ = load(root, rebuild=True)
        if g2["fingerprint"] != g["fingerprint"]:
            problems.append("fingerprint is not stable across two builds")
        if [(e["kind"], e["from"], e["to"]) for e in sorted(
                g2["edges"], key=lambda x: (x["kind"], x["from"], x["to"]))] != \
           [(e["kind"], e["from"], e["to"]) for e in sorted(
                g["edges"], key=lambda x: (x["kind"], x["from"], x["to"]))]:
            problems.append("rebuild produced a different edge set — not deterministic")
        for p in sorted(set(problems)):
            print("FAIL  %s" % p)
        print("\nreach: %d nodes · %d edges · %d source files"
              % (len(g["nodes"]), len(g["edges"]), g["source_file_count"]))
        if problems:
            print("\nFAIL  %d problem(s)." % len(set(problems)))
            return 1
        print("PASS  every edge resolves on disk; the build is deterministic.")
        return 0

    if a.who_breaks:
        if not known(g, a.who_breaks):
            return 2
        hits = reachable(g, a.who_breaks, reverse=True)
        # A hub in a real monorepo is reached by thousands of files. Printing all of them makes
        # the ANSWER the context problem the graph exists to remove, so the total and the
        # per-hop shape are stated first and the listing is capped. --limit=0 prints everything
        # for a human reading a terminal; an agent should leave the cap on.
        by_hop = {}
        for _, d in hits:
            by_hop[d] = by_hop.get(d, 0) + 1
        shape = " · ".join("%d at %d hop%s" % (by_hop[d], d, "" if d == 1 else "s")
                           for d in sorted(by_hop))
        print("%d file(s) reach %s" % (len(hits), a.who_breaks))
        if hits:
            print("%s\n" % shape)
        ordered = sorted(hits, key=lambda x: (x[1], x[0]))
        shown = ordered if a.limit == 0 else ordered[:a.limit]
        for n, d in shown:
            print("  %d hop%s  %s" % (d, " " if d == 1 else "s", n))
        if len(shown) < len(ordered):
            print("\n  … %d more not listed. --limit=0 for all, or narrow with --path <from> %s"
                  % (len(ordered) - len(shown), a.who_breaks))
        if not hits:
            print("  (no edge resolved into it — see the provenance note in --stats before "
                  "reading that as 'safe to change')")
        return 0

    if a.neighbors:
        if not known(g, a.neighbors):
            return 2
        out = adjacency(g).get(a.neighbors, [])
        inn = adjacency(g, reverse=True).get(a.neighbors, [])
        print("%s\n" % a.neighbors)
        print("  imports / produces for (%d):" % len(out))
        for n, e in sorted(out):
            print("    -> %-58s [%s%s]" % (n, e["kind"], (" " + e["label"]) if e["label"] else ""))
        print("  imported / consumed by (%d):" % len(inn))
        for n, e in sorted(inn):
            print("    <- %-58s [%s%s]" % (n, e["kind"], (" " + e["label"]) if e["label"] else ""))
        return 0

    if a.path:
        src, dst = a.path
        if not known(g, src) or not known(g, dst):
            return 2
        p = shortest_path(g, src, dst)
        if p is None:
            print("no declared path from %s to %s" % (src, dst))
            return 1
        print("%d hop(s)\n\n  %s" % (len(p), src))
        for _, to, e in p:
            print("    -> %s   [%s%s]" % (to, e["kind"], (" " + e["label"]) if e["label"] else ""))
        return 0

    if a.central:
        deg = {}
        for e in g["edges"]:
            deg[e["from"]] = deg.get(e["from"], 0) + 1
            deg[e["to"]] = deg.get(e["to"], 0) + 1
        ranked = sorted(deg.items(), key=lambda kv: (-kv[1], kv[0]))[:a.limit]
        print("top %d by degree (edges touching the node)\n" % len(ranked))
        for n, d in ranked:
            print("  %3d  %s" % (d, n))
        return 0

    print_stats(g, root)
    print("\n(cache %s)" % ("hit" if cached else "rebuilt"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
