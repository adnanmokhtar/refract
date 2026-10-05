#!/usr/bin/env python3
"""state-matrix-lint.py — gate G12's computational half: every touched UI surface has a row for every
state, and every row is proved by a story or test that exists.

Usage:  state-matrix-lint.py [<matrix.md>] [--run=ai/runs/<run-id>] [--repo=<dir>]
                             [--touched=<path>,<path>…] [--base=<ref>] [--surface-glob=<glob>]…
                             [--phase=design] [--json]
        state-matrix-lint.py --self-test
Exit:   0  no finding (PASS, or N-A with its reason)    1  at least one finding    2  usage or read error
        (the convention of test-integrity.py / oracle-check.py, which gate-check.py reads: 0/1 = ran, 2 = could not)

WHERE THE MATRIX IS. An explicit <matrix.md>, else in --run: ux.md (writer @ux-designer), else design.md
(the architect's UI slice, used until @ux-designer ships). The section is the first `## State matrix`
heading; it ends at the next `## ` heading. Format (templates/packs/ui-ux/skills/state-matrix/SKILL.md):

  Surfaces:
  - `orders-list` — src/orders/OrdersPage.tsx, src/orders/OrdersTable.tsx
  | Surface | State | Source | Expected | Proof |
  |---|---|---|---|---|
  | orders-list | loading | AC-002 | 10 skeleton rows, aria-busy | src/orders/OrdersPage.stories.tsx#Loading |
  | orders-list | offline | n-a | n-a — admin surface on the office LAN; the API client has no offline mode | — |

  Proof ids, several per cell split by `;`:  path#Export (a story or named export) · path::<test title text>
  · path:<line> · path. The path is repo-relative and must be a test or story file. --phase=design (P3, before
  any test exists) checks that each proof is NAMED and points at a test or story path, not that the file exists.

FINDINGS (each fails the gate):
  no-matrix            a UI run at T2/T3, or a touched surface, and no `## State matrix` section
  surface-unlisted     a touched file that looks like a surface (page/screen/view/route) maps to no listed surface
  state-missing        a listed surface with no row for a required state (THR-UI-STATES, else the default 7)
  na-without-reason    an `n-a` row whose reason is missing or a placeholder (fewer than 3 words, tbd, none …)
  no-proof             a row that is not n-a and names no proof
  proof-missing        a proof whose file does not exist, or whose #Export / ::title / :line is not in it
  proof-not-a-test     a proof that points at a file that is not a test or a story
  unknown-state        a state outside the vocabulary (a typo would otherwise pass as an extra row)
  unknown-surface      a row for a surface the Surfaces list does not declare
  duplicate-row        the same (surface, state) twice
  source-unknown       a Source id (REQ-/AC-) that requirements.md beside the matrix does not define
ADVISORIES (printed, never fail): clause-unmapped — an AC whose sentence has IF … THEN that no row cites;
  proof-unanchored — a proof that names a file only, no export, title or line.

N-A, with its reason: no run, no matrix and no touched surface; a run with no frontend/mobile lane; a T1 run
with no matrix (P3 is not required at T1, tiers.json).

HONEST LIMITS:
  * Existence, not meaning: the lint proves the cited story or test exists, not that it forces the state or
    fails first. @ux-reviewer (the inferential half of G12) and the state-matrix tests themselves do that.
  * "Looks like a surface" is a filename rule (…Page/View/Screen/Route.{tsx,jsx,vue,svelte}, page/+page files,
    *_screen.dart, …Screen.kt, …View.swift). Add --surface-glob for a project that names surfaces otherwise.
  * One table per section; a row wrapped onto two lines is read as two rows.
"""
import fnmatch
import json
import os
import re
import subprocess
import sys

CORE = ["loading", "empty", "error", "partial", "permission", "offline", "stale"]
CONDITIONAL = ["long-content", "pending-submit", "not-found", "destructive-confirm", "unsaved-changes",
               "validation", "timeout"]
PLACEHOLDER = re.compile(r"^(?:n[-/]?a|none|tbd|todo|tba|-+|—|\.\.\.|…|later|same|see above)$", re.I)
SURFACE_NAME = re.compile(
    r"(?:^|/)(?:[A-Z]\w*(?:Page|View|Screen|Route)\.(?:tsx|jsx|vue|svelte)|\+?page\.(?:tsx|jsx|svelte)"
    r"|[\w-]+[-.]page\.(?:ts|vue|svelte)|[\w-]+\.page\.ts|\w+_(?:screen|page|view)\.dart|\w+Screen\.kt"
    r"|\w+(?:Screen|View)\.swift|pages/[\w/\[\]-]+\.vue)$")
TESTISH = re.compile(r"(?:\.(?:test|spec|stories|story|e2e|cy)\.[\w]+$|(?:^|/)(?:tests?|__tests__|e2e|spec|"
                     r"integration_test|androidTest|UITests?|stories)/|_test\.dart$|Tests?\.(?:swift|kt)$|Test\.java$)")
UI_LANES = {"frontend", "mobile"}


def read(p):
    with open(p, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def states_vocab(repo):
    """THR-UI-STATES (thresholds.json, overridable in .claude/thresholds.local.json) when installed, else the default."""
    req, cond = list(CORE), list(CONDITIONAL)
    for rel in (".claude/templates/governance/thresholds.json", ".claude/thresholds.local.json"):
        p = os.path.join(repo, rel)
        if not os.path.isfile(p):
            continue
        try:
            d = json.loads(read(p))
        except ValueError:
            continue
        v = (d.get("thresholds", d).get("THR-UI-STATES") or {}).get("value")
        if isinstance(v, list):
            req = [str(s) for s in v]
        elif isinstance(v, dict):
            req = [str(s) for s in v.get("required", req)]
            cond = [str(s) for s in v.get("conditional", cond)]
    return req, cond


def split_row(line):
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    return cells


def parse(text):
    """-> (found, start_line, surfaces {id: [paths]}, rows [(line, cells)], header)"""
    lines = text.split("\n")
    start = next((i for i, l in enumerate(lines) if re.match(r"^##\s+State matrix\b", l, re.I)), None)
    if start is None:
        return False, None, {}, [], []
    surfaces, rows, header = {}, [], []
    for i in range(start + 1, len(lines)):
        l = lines[i]
        if re.match(r"^##\s", l):
            break
        m = re.match(r"^\s*[-*]\s+`?([\w.-]+)`?\s*[—–:-]+\s*(.+)$", l)
        if m and not l.lstrip().startswith("|"):
            paths = [p.strip(" `") for p in re.split(r"[,;]", m.group(2)) if p.strip(" `")]
            surfaces[m.group(1)] = paths
            continue
        if l.lstrip().startswith("|"):
            cells = split_row(l)
            if all(re.match(r"^:?-{2,}:?$", c) for c in cells if c):
                continue
            if not header:
                header = [(re.findall(r"[a-z]+", c.lower()) or [""])[0] for c in cells]   # "Expected (message · …)" → expected
                continue
            rows.append((i + 1, cells))
    return True, start + 1, surfaces, rows, header


def col(header, row, name):
    try:
        return row[header.index(name)]
    except (ValueError, IndexError):
        return ""


def check_proof(repo, cell, mfile, line, out, adv, design=False):
    for ref in [r.strip(" `") for r in re.split(r";|<br\s*/?>", cell) if r.strip(" `")]:
        m = re.match(r"^(.+?)(?:#([\w$]+)|::(.+)|:(\d+))?$", ref)
        path, export, title, ln = m.group(1).strip(), m.group(2), m.group(3), m.group(4)
        fp = os.path.join(repo, path)
        if design:
            if not TESTISH.search(path):
                out.append(f(mfile, line, "proof-not-a-test", "%s is not a test or a story file" % path))
            continue
        if not os.path.isfile(fp):
            out.append(f(mfile, line, "proof-missing", "%s does not exist" % path))
            continue
        if not TESTISH.search(path):
            out.append(f(mfile, line, "proof-not-a-test", "%s is not a test or a story file" % path))
            continue
        body = read(fp)
        if export and not re.search(r"\b%s\b" % re.escape(export), body):
            out.append(f(mfile, line, "proof-missing", "%s names no `%s`" % (path, export)))
        elif title and title.strip() not in body:
            out.append(f(mfile, line, "proof-missing", "%s has no test titled `%s`" % (path, title.strip())))
        elif ln and int(ln) > body.count("\n") + 1:
            out.append(f(mfile, line, "proof-missing", "%s has no line %s" % (path, ln)))
        elif not (export or title or ln):
            adv.append(f(mfile, line, "proof-unanchored", "%s — name the story export, test title or line" % path))


def f(path, line, kind, message):
    return {"file": path, "line": line, "kind": kind, "message": message}


def touched_files(repo, opts):
    if opts.get("touched"):
        return [t.strip() for t in opts["touched"].split(",") if t.strip()]
    if opts.get("base"):
        out = []
        for cmd in (["git", "diff", "--name-only", opts["base"]], ["git", "ls-files", "--others", "--exclude-standard"]):
            r = subprocess.run(cmd, cwd=repo, capture_output=True, text=True)
            if r.returncode != 0:
                raise OSError("git failed: %s" % r.stderr.strip()[:200])
            out += [l for l in r.stdout.split("\n") if l]
        return sorted(set(out))
    return []


def lint(repo, matrix=None, run=None, opts=None):
    opts = opts or {}
    findings, adv = [], []
    tier, lanes = None, None
    if run:
        rj = os.path.join(repo, run, "run.json")
        if os.path.isfile(rj):
            d = json.loads(read(rj))
            tier, lanes = d.get("tier"), set(d.get("lanes") or [])
        if not matrix:
            for name in ("ux.md", "design.md"):
                if os.path.isfile(os.path.join(repo, run, name)):
                    cand = os.path.join(run, name)
                    if parse(read(os.path.join(repo, cand)))[0] or name == "design.md":
                        matrix = cand
                        break
    touched = touched_files(repo, opts)
    globs = opts.get("surface_glob", [])
    looks = [t for t in touched if SURFACE_NAME.search(t) or any(fnmatch.fnmatch(t, g) for g in globs)]
    if lanes is not None and not lanes & UI_LANES:
        return result("N-A", "run has no frontend or mobile lane", matrix, 0, [], [])
    text = read(os.path.join(repo, matrix)) if matrix and os.path.isfile(os.path.join(repo, matrix)) else ""
    found, start, surfaces, rows, header = parse(text)
    if not found:
        if tier in ("T2", "T3"):
            return result("FAIL", None, matrix, 0, [f(matrix or run, None, "no-matrix",
                          "a %s UI run needs `## State matrix` in ux.md or design.md (P3)" % tier)], [])
        if looks:
            return result("FAIL", None, matrix, 0, [f(t, None, "no-matrix", "touched surface with no state matrix")
                                                    for t in looks], [])
        why = "P3 is not required at T1" if tier == "T1" else "no state matrix and no touched surface"
        return result("N-A", why, matrix, 0, [], [])
    required, conditional = states_vocab(repo)
    vocab = set(required) | set(conditional)
    for need in ("surface", "state", "expected", "proof"):
        if need not in header:
            return result("FAIL", None, matrix, 0, [f(matrix, start, "no-matrix",
                          "the table needs the columns Surface | State | Source | Expected | Proof")], [])
    seen, by_surface = set(), {}
    for line, cells in rows:
        s, st = col(header, cells, "surface").strip("` "), col(header, cells, "state").strip("` ").lower()
        exp, proof, src = col(header, cells, "expected"), col(header, cells, "proof"), col(header, cells, "source")
        if s not in surfaces:
            findings.append(f(matrix, line, "unknown-surface", "`%s` is not in the Surfaces list" % s))
        if st not in vocab:
            findings.append(f(matrix, line, "unknown-state", "`%s` is not a state (%s)" % (st, ", ".join(sorted(vocab)))))
        if (s, st) in seen:
            findings.append(f(matrix, line, "duplicate-row", "%s × %s appears twice" % (s, st)))
        seen.add((s, st))
        by_surface.setdefault(s, set()).add(st)
        na = re.match(r"^\s*n[-/]?a\b\s*(?:[—–:-]+\s*)?(.*)$", exp, re.I)
        if na:
            reason = na.group(1).strip()
            if PLACEHOLDER.match(reason or "-") or len(reason.split()) < 3:
                findings.append(f(matrix, line, "na-without-reason", "%s × %s is n-a with no reason" % (s, st)))
            continue
        if not proof or PLACEHOLDER.match(proof.strip()):
            findings.append(f(matrix, line, "no-proof", "%s × %s names no story or test" % (s, st)))
        else:
            check_proof(repo, proof, matrix, line, findings, adv, opts.get("phase") == "design")
    for s in surfaces:
        for st in required:
            if st not in by_surface.get(s, set()):
                findings.append(f(matrix, start, "state-missing", "`%s` has no `%s` row (write it, or n-a with a reason)" % (s, st)))
    covered = [p for ps in surfaces.values() for p in ps]
    for t in looks:
        if not any(t == p or t.startswith(p.rstrip("/") + "/") for p in covered):
            findings.append(f(t, None, "surface-unlisted", "touched surface maps to no row of %s" % matrix))
    req = os.path.join(repo, os.path.dirname(matrix), "requirements.md")
    if os.path.isfile(req):
        rtext = read(req)
        ids = set(re.findall(r"\b(?:REQ|AC)-\d{3,}\b", rtext))
        cited = set()
        for line, cells in rows:
            for i in re.findall(r"\b(?:REQ|AC)-\d{3,}\b", col(header, cells, "source")):
                cited.add(i)
                if i not in ids:
                    findings.append(f(matrix, line, "source-unknown", "%s is not defined in requirements.md" % i))
        for m in re.finditer(r"(?m)^\s*[-*]\s+(?:\*\*)?(AC-\d{3,})(?:\*\*)?\s*:\s*(.*)$", rtext):
            if re.search(r"\bIF\b.*\bTHEN\b", m.group(2), re.I) and m.group(1) not in cited:
                adv.append(f(os.path.join(os.path.dirname(matrix), "requirements.md"), None, "clause-unmapped",
                             "%s is an IF … THEN clause no matrix row cites" % m.group(1)))
    return result("FAIL" if findings else "PASS", None if findings else "%d surface(s), every required state "
                  "written and proved or n-a with a reason" % len(surfaces), matrix, len(surfaces), findings, adv)


def result(verdict, reason, matrix, n, findings, adv):
    return {"verdict": verdict, "reason": reason, "matrix": matrix, "surfaces_checked": n,
            "findings": findings, "advisories": adv}


def self_test():
    import shutil
    import tempfile
    fails, cases = [], 0
    td = tempfile.mkdtemp(prefix="smlint.")
    try:
        def w(rel, body):
            p = os.path.join(td, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8") as fh:
                fh.write(body)
        w("src/orders/OrdersPage.stories.tsx", "export const Loading = {}\nexport const Empty = {}\n")
        w("src/orders/OrdersPage.states.test.tsx", "test('error shows retry', () => {})\ntest('stale keeps rows', () => {})\n")
        w("src/orders/OrdersPage.tsx", "export function OrdersPage() {}\n")
        w("ai/runs/r1/run.json", json.dumps({"tier": "T2", "lanes": ["frontend"]}))
        w("ai/runs/r1/requirements.md", "### REQ-001 — List\n- AC-001: WHEN x THE list SHALL show rows\n"
          "- AC-002: IF the list call fails THEN THE list SHALL show an error with a retry\n")
        good = ("# UX\n\n## State matrix\n\nSurfaces:\n- `orders-list` — src/orders/OrdersPage.tsx\n\n"
                "| Surface | State | Source | Expected (message · action · focus) | Proof |\n|---|---|---|---|---|\n"
                "| orders-list | loading | AC-001 | skeleton | src/orders/OrdersPage.stories.tsx#Loading |\n"
                "| orders-list | empty | AC-001 | copy + CTA | src/orders/OrdersPage.stories.tsx#Empty |\n"
                "| orders-list | error | AC-002 | ErrorState | src/orders/OrdersPage.states.test.tsx::error shows retry |\n"
                "| orders-list | partial | n-a | n-a — one endpoint feeds the whole list | — |\n"
                "| orders-list | permission | n-a | n-a — every signed-in role may read orders | — |\n"
                "| orders-list | offline | n-a | n-a — desktop admin with no offline mode | — |\n"
                "| orders-list | stale | AC-001 | rows kept, Updating… | src/orders/OrdersPage.states.test.tsx::stale keeps rows |\n"
                "\n## Flows\n")
        w("ai/runs/r1/ux.md", good)

        def expect(name, kinds, verdict, **kw):
            nonlocal cases
            cases += 1
            r = lint(td, **kw)
            got = sorted({x["kind"] for x in r["findings"]})
            if r["verdict"] != verdict or got != sorted(kinds):
                fails.append("%s: verdict %s kinds %s, want %s %s" % (name, r["verdict"], got, verdict, sorted(kinds)))
        expect("clean run", [], "PASS", run="ai/runs/r1", opts={"touched": "src/orders/OrdersPage.tsx"})
        bad = good.replace("| orders-list | stale | AC-001 | rows kept, Updating… | src/orders/OrdersPage.states.test.tsx::stale keeps rows |\n", "") \
                  .replace("n-a — desktop admin with no offline mode", "n-a") \
                  .replace("OrdersPage.stories.tsx#Empty", "OrdersPage.stories.tsx#Blank") \
                  .replace("| orders-list | loading | AC-001 | skeleton | src/orders/OrdersPage.stories.tsx#Loading |",
                           "| orders-list | loading | AC-009 | skeleton | src/orders/OrdersPage.tsx |")
        bad += "| orders-list | eror | AC-001 | x | — |\n"
        w("ai/runs/r2/run.json", json.dumps({"tier": "T2", "lanes": ["frontend"]}))
        w("ai/runs/r2/requirements.md", read(os.path.join(td, "ai/runs/r1/requirements.md")))
        w("ai/runs/r2/ux.md", bad.replace("\n## Flows\n", "") )
        expect("defects", ["state-missing", "na-without-reason", "proof-missing", "proof-not-a-test",
                           "source-unknown", "unknown-state", "no-proof"], "FAIL", run="ai/runs/r2")
        w("ai/runs/r3/run.json", json.dumps({"tier": "T2", "lanes": ["frontend"]}))
        w("ai/runs/r3/design.md", "# Design\n\n## Components\n")
        expect("T2 UI run with no matrix", ["no-matrix"], "FAIL", run="ai/runs/r3")
        w("ai/runs/r6/run.json", json.dumps({"tier": "T2", "lanes": ["frontend"]}))
        w("ai/runs/r6/ux.md", good.replace("OrdersPage.stories.tsx#Loading", "OrdersPage.states.test.tsx::loading (P3, not yet written)"))
        expect("design phase: a named, not-yet-written test passes", [], "PASS", run="ai/runs/r6", opts={"phase": "design"})
        expect("build phase: the same test must exist", ["proof-missing"], "FAIL", run="ai/runs/r6")
        w("ai/runs/r4/run.json", json.dumps({"tier": "T1", "lanes": ["frontend"]}))
        expect("T1 with no matrix", [], "N-A", run="ai/runs/r4")
        w("ai/runs/r5/run.json", json.dumps({"tier": "T3", "lanes": ["backend"]}))
        expect("backend-only run", [], "N-A", run="ai/runs/r5")
        expect("touched surface outside the matrix", ["surface-unlisted"], "FAIL", run="ai/runs/r1",
               opts={"touched": "src/orders/OrdersPage.tsx,src/billing/InvoicesPage.tsx,src/i18n/en.json"})
        expect("no run, copy-only change", [], "N-A", opts={"touched": "src/i18n/en.json,README.md"})
        w("ai/design/state-matrix/dup.md", good.replace("| orders-list | stale |", "| orders-list | empty |")
          .replace("Surfaces:\n", "Surfaces:\n- `ghost` — src/ghost/GhostView.tsx\n"))
        expect("a duplicate row; a listed surface with no rows", ["duplicate-row", "state-missing"], "FAIL",
               matrix="ai/design/state-matrix/dup.md")
        w("ai/design/state-matrix/odd.md", good.replace("| orders-list | partial |", "| order-list | partial |")
          .replace("OrdersPage.stories.tsx#Empty", "OrdersPage.stories.tsx"))
        expect("a row for an undeclared surface", ["unknown-surface", "state-missing"], "FAIL",
               matrix="ai/design/state-matrix/odd.md")
        cases += 1
        if [a["kind"] for a in lint(td, matrix="ai/design/state-matrix/odd.md")["advisories"]] != ["proof-unanchored"]:
            fails.append("a file-only proof is not flagged proof-unanchored")
        r = lint(td, run="ai/runs/r1")
        cases += 1
        if [a["kind"] for a in r["advisories"]] != []:
            fails.append("clean run advisories: %s" % r["advisories"])
    finally:
        shutil.rmtree(td, ignore_errors=True)
    for x in fails:
        print("FAIL " + x)
    print("state-matrix-lint self-test: %d case(s), %d failure(s)" % (cases, len(fails)))
    return 1 if fails else 0


def main(argv):
    opts, pos = {"surface_glob": []}, []
    for a in argv:
        if a.startswith("--surface-glob="):
            opts["surface_glob"].append(a.split("=", 1)[1])
        elif a.startswith("--"):
            k, _, v = a[2:].partition("=")
            opts[k.replace("-", "_")] = v if v else True
        else:
            pos.append(a)
    if opts.get("self_test"):
        return self_test()
    unknown = set(opts) - {"surface_glob", "run", "repo", "touched", "base", "json", "phase"}
    if opts.get("phase") not in (None, "design"):
        unknown.add("phase")
    if unknown or len(pos) > 1 or not (pos or opts.get("run") or opts.get("touched") or opts.get("base")):
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    repo = os.path.abspath(opts.get("repo") or ".")
    if pos and not os.path.isfile(os.path.join(repo, pos[0])):
        print("state-matrix-lint: no such matrix file: %s" % pos[0], file=sys.stderr)
        return 2
    try:
        r = lint(repo, pos[0] if pos else None, opts.get("run") or None,
                 {k: opts[k] for k in ("touched", "base", "surface_glob", "phase") if opts.get(k)})
    except (OSError, ValueError) as e:
        print("state-matrix-lint: %s" % e, file=sys.stderr)
        return 2
    if opts.get("json"):
        print(json.dumps(r, indent=2))
    else:
        print("G12 state matrix: %s%s%s" % (r["verdict"], " — " + r["reason"] if r["reason"] else "",
                                             " (%s)" % r["matrix"] if r["matrix"] else ""))
        for x in r["findings"] + r["advisories"]:
            tag = "advisory " if x in r["advisories"] else ""
            print("  %s%s:%s %s — %s" % (tag, x["file"], x["line"] or "-", x["kind"], x["message"]))
    return 1 if r["findings"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
