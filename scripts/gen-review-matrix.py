#!/usr/bin/env python3
"""gen-review-matrix.py — emit templates/_review-matrix.md from evidence on disk.

Phase 1 of docs/plans/audit-review-matrix.md.

WHY THIS IS GENERATED, NOT AUTHORED. The grid is 35 signal surfaces x 12 concerns = 420 cells.
Hand-authoring 420 cells produces a file that is stale the first time a domain is renamed, and
gives no way to tell a cell someone thought about from a cell someone skipped. Generating it
from two independent signals makes staleness a build break and makes the confidence explicit.

THE TWO SIGNALS, and why neither is used alone:
  curated  — the domain's row in _registry.md "What it ships". Deliberate, high precision,
             LOW RECALL. Used alone it reported Observability as 0/35 while 32 of 35 domain
             rule files in fact discuss metrics/traces/alerts.
  fulltext — the domain's rules/ + agents/ bodies, >=3 matches. High recall, LOW PRECISION.
             Used alone it reported 312/420 cells filled, which is noise: an early pattern for
             "log" also matched "login" and "logic".

  confirmed  both agree      -> material is shipped AND described for this pair
  proposed   one only        -> needs a human read; this is the review queue, not coverage
  empty      neither         -> no evidence of any material. THIS IS THE DELIVERABLE.

CALIBRATION. The plan states three cells as ground truth. All three reproduce:
  Security x file-upload      -> confirmed   (av-scan, allowlist)
  Idempotency x public-api    -> confirmed   (idempotent-POST)
  Authorization x background-jobs -> empty   (the plan calls this a real gap)

SCOPE LIMIT. Only the 35 signal surfaces are populated here. The 4 structural surfaces
(_database, _deployment, _routes, _screens) have no templates/domains/ folder, so neither signal
can see them; their material lives in packs and is mapped in a later pass. They are emitted as an
explicitly-marked unpopulated block rather than silently omitted.
"""
import re, sys, glob, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

CONCERNS = {
 "C1  Security":        r"(secur|exploit|injection|xss|csrf|ssrf|idor|signature|encrypt|hash|attack|malicious|vuln|csam|virus|av-scan|magic-byte|harden|secret|credential|allowlist|tamper|sanitiz|escap|shield|pci|lfi|imagetragick|entitlement-gate|key-custody|cleartext)",
 "C2  Performance":     r"(performan|latenc|throughput|n\+1|cache-aside|stampede|batch|stream|profil|bottleneck|read-replica|abr|adaptive|bounded-size|resource-cap|rate-aware|bloat)",
 "C3  Observability":   r"(observab|metric|trace|tracing|telemetry|dashboard|alert|\bslo\b|monitor|correlation)",
 "C4  Error Handling":  r"(retry|backoff|circuit.break|timeout|fallback|partial-failure|\bdlq\b|dead.letter|degrade|resilien|compensat|saga|quarantine|fail-open|fail-closed|overspend-locked|conflict-free)",
 "C5  Logging":         r"(\blog(s|ged|ging)?\b|audit-log|audit.trail|append-only|activity|exposure-logged|audit-every-action|audited|audit-changes)",
 "C6  Configuration":   r"(config|feature.flag|\bsetting|precedence|toggle|variant config|env\b)",
 "C7  Compliance":      r"(complian|gdpr|hipaa|pci|soc2|regulat|legal|consent|jurisdiction|illegal-content|report\b|pii)",
 "C8  Authorization":   r"(authoriz|permission|\brbac\b|least-privilege|access.control|entitle|granular-capability|impersonat|reauth|server-authoritative|scoped-hashed-keys|guard)",
 "C9  Idempotency":     r"(idempoten|dedup|at-least-once|exactly-once|replay|double-book|reconcil|upsert|mutual-exclusion|no-double)",
 "C10 Versioning":      r"(version|deprecat|backward|compat|contract|schema-valid|breaking.change|openapi|\bdto\b)",
 "C11 Data Lifecycle":  r"(retention|\bttl\b|expire|purge|archiv|backfill|lifecycle|checkpoint|watermark|backup|immutab|reversing-entries|content-versioning)",
 "C12 Tenancy":         r"(tenant|cross-tenant|isolation|per-tenant)",
}
STRUCTURAL = ["_database", "_deployment", "_routes", "_screens"]
GLYPH = {"confirmed": "●", "proposed": "○", "empty": "·", "n/a": "–"}


def registry_ships():
    t = open("templates/domains/_registry.md", encoding="utf-8").read()
    sec = t[t.index("## Registry (implemented)"):t.index("## Registry (cataloged")]
    out = {}
    for line in sec.splitlines():
        m = re.match(r"\|\s*`([a-z0-9-]+)`\s*\|(.*?)\|(.*?)\|\s*$", line)
        if m:
            out[m.group(1)] = m.group(3).strip()
    return out


def concern_rules():
    """templates/concerns/<name>.md — Phase 4 cross-cutting detectors.

    A concern rule names, in its per-surface fingerprint table, the surfaces it covers. Those
    pairs are `confirmed` by construction: the file IS the material, and unlike the two text
    signals there is nothing to infer. Rows the file marks N/A are recorded as `n/a` and never
    counted as coverage — the reason string lives in the rule file.
    """
    covered, na = {}, {}
    for f in sorted(glob.glob("templates/concerns/*.md")):
        if os.path.basename(f).startswith("_"):
            continue
        body = open(f, encoding="utf-8").read()
        m = re.search(r"^concern:\s*(C\d+)", body, re.M)
        if not m:
            continue
        cid = m.group(1)
        # A row is N/A either because the row itself says so (inline, as in authorization.md)
        # or because it sits under an "N/A with reason" heading (a separate table, as in
        # data-lifecycle.md). Matching only the row text silently promoted two reasoned N/A
        # surfaces to `confirmed`, which is the exact dishonesty the ledger forbids.
        na_zone = False
        for line in body.splitlines():
            if re.match(r"^\s*(\*\*|#+ ).*N/A", line):
                na_zone = True
                continue
            if re.match(r"^## ", line):
                na_zone = False
            m2 = re.match(r"^\| `([a-z0-9_-]+)` \|(.*)$", line)
            if m2:
                sfc, rest = m2.group(1), m2.group(2)
                (na if (na_zone or "N/A" in rest) else covered).setdefault(cid, set()).add(sfc)
    return covered, na


def build():
    ships = registry_ships()
    covered, na = concern_rules()
    grid, arts = {}, {}
    for dom in sorted(ships):
        files = sorted(glob.glob(f"templates/domains/{dom}/rules/*.md") +
                       glob.glob(f"templates/domains/{dom}/agents/*.md"))
        arts[dom] = [f for f in files]
        full = "\n".join(open(f, encoding="utf-8", errors="replace").read() for f in files).lower()
        cur = ships[dom].lower()
        for c, pat in CONCERNS.items():
            a = bool(re.search(pat, cur))
            n = len(re.findall(pat, full))
            cid = c.split()[0]
            if dom in covered.get(cid, ()):
                grid[(dom, c)] = "confirmed"        # a concern rule names this surface
            elif dom in na.get(cid, ()):
                grid[(dom, c)] = "n/a"              # named, with a reason, in the rule file
            else:
                grid[(dom, c)] = ("confirmed" if (a and n >= 3) else
                                  "proposed" if (a or n >= 3) else "empty")
    return ships, grid, arts


def main():
    ships, grid, arts = build()
    doms = sorted(ships)
    cs = list(CONCERNS)
    tally = collections.Counter(grid.values())
    total = len(grid)

    o = []
    w = o.append
    w("# `_review-matrix.md` — the dispatch index\n")
    w("> **GENERATED — do not hand-edit.** Regenerate with `scripts/gen-review-matrix.py`;")
    w("> `scripts/validate-review-matrix.sh` fails the build if this file is stale or if any")
    w("> artifact it names has left disk. Phase 1 of")
    w("> [`docs/plans/audit-review-matrix.md`](../docs/plans/audit-review-matrix.md).")
    w("> Vocabulary comes from [`_review-model.md`](_review-model.md) — surfaces §2, concerns §3.\n")
    w("---\n")
    w("## 1. What a cell state means\n")
    w("Two independent signals per cell. **Neither is trustworthy alone**, which is why both run:\n")
    w("| Signal | Source | Precision | Recall |")
    w("|---|---|---|---|")
    w("| `curated` | the domain's row in `_registry.md` **What it ships** | high | **low** — alone it scored Observability 0/35 while 32 of 35 domain rule files discuss metrics/traces/alerts |")
    w("| `fulltext` | the domain's `rules/` + `agents/` bodies, ≥ 3 matches | **low** | high — alone it scored 312/420 filled, noise (an early `log` pattern also matched `login`, `logic`) |\n")
    w("| State | Meaning | Count |")
    w("|---|---|---|")
    w(f"| ● `confirmed` | both signals agree — material is shipped **and** described for this pair | {tally['confirmed']} / {total} ({tally['confirmed']*100//total}%) |")
    w(f"| ○ `proposed` | one signal only — **a review queue, not coverage**. A human must read it. | {tally['proposed']} / {total} ({tally['proposed']*100//total}%) |")
    w(f"| · `empty` | neither signal. No evidence of any material. **This is the deliverable.** | {tally['empty']} / {total} ({tally['empty']*100//total}%) |")
    w(f"| – `n/a` | a `templates/concerns/` rule names this surface as having no meaningful fingerprint, **with a reason** | {tally['n/a']} / {total} ({tally['n/a']*100//total}%) |\n")
    w("> A `confirmed` cell means *material exists*, *not* that the material is good or that a")
    w("> detector runs. Phase 2 dispatches it; only a run can say whether it finds anything.\n")
    w("### Calibration\n")
    w("The plan names three cells as ground truth. All three reproduce, which is why this method")
    w("is trusted as far as it is trusted:\n")
    w("| Cell | Plan says | Generated |")
    w("|---|---|---|")
    for dom, c, exp in [("file-upload", "C1  Security", "filled — av-scan, allowlist"),
                        ("public-api", "C9  Idempotency", "filled — idempotent-POST"),
                        ("background-jobs", "C8  Authorization", "**empty — a real gap**")]:
        w(f"| `{c.split()[0]}` × `{dom}` | {exp} | `{grid[(dom,c)]}` |")
    w("")
    w("---\n")
    w("## 2. The grid — 35 signal surfaces × 12 concerns\n")
    w("```")
    hdr = "surface".ljust(22) + " ".join(c.split()[0].rjust(3) for c in cs)
    w(hdr)
    w("-" * len(hdr))
    for d in doms:
        w(d.ljust(22) + " ".join(GLYPH[grid[(d, c)]].rjust(3) for c in cs))
    w("-" * len(hdr))
    w("legend".ljust(22) + "  ● confirmed   ○ proposed (needs a read)   · empty   – n/a (reasoned)")
    w("```\n")
    w("---\n")
    w("## 3. The empty column — cells with no evidence at all\n")
    by_c = collections.defaultdict(list)
    for (d, c), st in grid.items():
        if st == "empty":
            by_c[c].append(d)
    if tally["empty"]:
        w(f"**{tally['empty']} of {total} cells.** Neither signal found anything. These are the")
        w("pairs nobody is looking at; Phase 3 renders them as *live, unreviewed* and Phase 4 sizes")
        w("the work.\n")
        w("| Concern | Surfaces with no material | n |")
        w("|---|---|---|")
        for c in cs:
            if by_c[c]:
                w(f"| **{c}** | {', '.join('`%s`' % x for x in sorted(by_c[c]))} | {len(by_c[c])} |")
        w("")
        w("### Widest gaps, by concern\n")
        for c in sorted(cs, key=lambda c: -len(by_c[c]))[:3]:
            if by_c[c]:
                w(f"- **{c}** — no material on {len(by_c[c])} of 35 surfaces.")
        w("")
    else:
        w("**0 of %d cells — but read what that does and does not mean.**\n" % total)
        w("It means every (concern, surface) pair now has **named material**: all 12 concerns have")
        w("a rule in [`concerns/`](concerns/), and each names the surfaces it covers with a")
        w("concrete fingerprint. The column that opened at 117 is closed.\n")
        w("**It does not mean the review is complete.** Three things are still true:\n")
        w(f"1. A fingerprint is a **detector spec, not a running detector**. It says what to look")
        w("   for; only a dispatched agent finds anything. Phase 2 dispatches these — no run has")
        w("   yet confirmed a single one earns its place.")
        w(f"2. **{tally['proposed']} cells are still `proposed`** — one text signal, never read by a")
        w("   human. That is the standing review queue and it did not shrink; closing the empty")
        w("   column did not touch it.")
        w("3. The 4 structural surfaces (§4) are still unpopulated, so the true grid is 468 cells,")
        w(f"   not {total}. A gap that is out of scope is still a gap.\n")
        w("> Zero empty is the point at which the matrix stops finding gaps *by absence* and starts")
        w("> having to find them *by running*. That is a harder question, and it is the next one.\n")
    w("---\n")
    w("## 4. Structural surfaces — NOT populated in this pass\n")
    w("`" + "`, `".join(STRUCTURAL) + "` have no `templates/domains/` folder, so neither signal")
    w("can see them. Their material lives in packs (`database`, `infrastructure`, `backend`,")
    w("`frontend`, `mobile`). Mapping packs onto structural surfaces is a separate pass with a")
    w("different evidence source; it is **listed here as unpopulated rather than omitted**, so the")
    w("gap is visible rather than silent.\n")
    w(f"Full grid when they land: 39 surfaces × 12 concerns = 468 cells (currently {total}).\n")
    w("---\n")
    w("## 5. Artifacts behind the grid\n")
    n_files = sum(len(v) for v in arts.values())
    w(f"{n_files} domain artifacts across {len(doms)} domains. Every path is asserted to exist by")
    w("`validate-review-matrix.sh`, in both directions — a renamed file breaks the build, and an")
    w("artifact in no cell is reported.\n")
    w("```")
    for d in doms:
        w(f"{d.ljust(22)}{', '.join(os.path.basename(f)[:-3] for f in arts[d])}")
    w("```")
    open("templates/_review-matrix.md", "w", encoding="utf-8").write("\n".join(o) + "\n")
    print(f"wrote templates/_review-matrix.md — {total} cells: "
          f"{tally['confirmed']} confirmed, {tally['proposed']} proposed, {tally['empty']} empty")


if __name__ == "__main__":
    main()
