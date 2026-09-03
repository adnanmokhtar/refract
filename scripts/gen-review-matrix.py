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
def structural_map():
    """_review-model.md §2.2 "Material lives in" — the structural counterpart to _registry.md.

    Read from the model rather than hardcoded here, so the mapping is reviewed in the file that
    owns the vocabulary and a change there cannot silently diverge from what the grid renders.
    """
    t = open("templates/_review-model.md", encoding="utf-8").read()
    m = re.search(r"### 2\.2 .*?\n(.*?)(?=\n\*\*The \"Material)", t, re.S)
    # `m.group(1) if m else ""` turned a failed anchor into an EMPTY surface list, and the
    # generator then emitted a complete, internally coherent matrix missing four structural
    # surfaces with every percentage recomputed to agree. validate-review-matrix.sh checks
    # freshness by re-running this generator, so the wrong matrix verified against itself and
    # stayed green. A missing anchor is a broken generator, not an empty section.
    if m is None:
        raise SystemExit(
            "gen-review-matrix: the '### 2.2' anchor in templates/_review-model.md no longer "
            "matches. Refusing to emit a matrix built from zero surfaces — it would be wrong and "
            "self-consistent, which validate-review-matrix.sh cannot detect."
        )
    out = {}
    for row in re.findall(r"^\| `(_[a-z]+)` \|[^|]*\|([^|]*)\|", m.group(1), re.M):
        out[row[0]] = re.findall(r"`([a-z-]+)`", row[1])
    return out
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


def pack_evidence(packs):
    """Two signals over pack artifacts, mirroring the domain method exactly.

    curated  = the artifact's `description:` frontmatter — deliberate, high precision.
    fulltext = the artifact body, >= 3 matches — high recall, low precision.

    Every pack artifact carries a description, so the parallel is exact and no third method is
    introduced for the structural half of the grid.
    """
    per, arts = [], []
    for pk in packs:
        for f in sorted(glob.glob(f"templates/packs/{pk}/skills/*/SKILL.md") +
                        glob.glob(f"templates/packs/{pk}/agents/*.md") +
                        glob.glob(f"templates/packs/{pk}/rules/*.md")):
            body = open(f, encoding="utf-8", errors="replace").read()
            d = re.search(r"^description:\s*(.+)$", body, re.M)
            per.append(((d.group(1) if d else "").lower(), body.lower()))
            name = (f.split("/skills/")[1].split("/")[0] if "/skills/" in f
                    else os.path.basename(f)[:-3])
            arts.append(f"{pk}:{name}")
    return per, arts


def decisions():
    """templates/_review-decisions.md — human verdicts, read BEFORE both text signals.

    The two proxies exist only to triage cells nobody has read. A cell that has been read is no
    longer a triage problem, so a verdict here wins outright — including a verdict of `empty`,
    which reopens a cell automation had closed.
    """
    f = "templates/_review-decisions.md"
    if not os.path.exists(f):
        return {}
    out = {}
    for m in re.finditer(r"^\| `([a-z0-9_-]+)` \| (C\d+)[^|]*\| `(confirmed|empty|n/a)` \|",
                         open(f, encoding="utf-8").read(), re.M):
        out[(m.group(1), m.group(2))] = m.group(3)
    return out


def build():
    ships = registry_ships()
    verdicts = decisions()
    covered, na = concern_rules()
    grid, arts, backing = {}, {}, {}
    for dom in sorted(ships):
        files = sorted(glob.glob(f"templates/domains/{dom}/rules/*.md") +
                       glob.glob(f"templates/domains/{dom}/agents/*.md"))
        arts[dom] = [f for f in files]
        full = "\n".join(open(f, encoding="utf-8", errors="replace").read() for f in files).lower()
        cur = ships[dom].lower()
        for c, pat in CONCERNS.items():
            v = verdicts.get((dom, c.split()[0]))
            if v:
                grid[(dom, c)] = v
                continue
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

    # ---- structural surfaces: same two signals, pack artifacts as the source ----
    for sfc, packs in sorted(structural_map().items()):
        per, names = pack_evidence(packs)
        arts[sfc] = names
        for c, pat in CONCERNS.items():
            cid = c.split()[0]
            v = verdicts.get((sfc, cid))
            if v:
                grid[(sfc, c)] = v
                backing[(sfc, c)] = -1
                continue
            if sfc in covered.get(cid, ()):
                grid[(sfc, c)] = "confirmed"
                backing[(sfc, c)] = -1
                continue
            if sfc in na.get(cid, ()):
                grid[(sfc, c)] = "n/a"
                continue
            # PER-ARTIFACT, never a concatenated blob. Joining 17-46 pack files into one string
            # makes any threshold meaningless: the first attempt scored _routes 12/12 confirmed
            # because some description among 17 backend artifacts matches every concern.
            # `confirmed` here means >= 2 artifacts are individually ABOUT the concern.
            about = sum(1 for d, _ in per if re.search(pat, d))
            deep = sum(1 for _, b in per if len(re.findall(pat, b)) >= 3)
            backing[(sfc, c)] = about
            grid[(sfc, c)] = ("confirmed" if about >= 2 else
                              "proposed" if (about or deep) else "empty")
    return ships, grid, arts, backing


def main():
    ships, grid, arts, backing = build()
    doms = sorted(ships) + sorted(structural_map())
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
        w(f"**{tally['empty']} of {total} cells.** The concern has a real shape on that surface and")
        w("nothing addresses it. Phase 3 renders these as *live, unreviewed* and Phase 4 sizes the")
        w("work.\n")
        w("Every one of these is now a **read verdict, not an absence of keywords** — see")
        w("[`_review-decisions.md`](_review-decisions.md). The automated pass reported 0 empty; it")
        w("could not tell a fingerprint from a passing mention, and reading found these.\n")
        w("| Concern | Surfaces with no material | n |")
        w("|---|---|---|")
        for c in cs:
            if by_c[c]:
                w(f"| **{c}** | {', '.join('`%s`' % x for x in sorted(by_c[c]))} | {len(by_c[c])} |")
        w("")
        w("### Widest gaps, by concern\n")
        for c in sorted(cs, key=lambda c: -len(by_c[c]))[:3]:
            if by_c[c]:
                w(f"- **{c}** — no material on {len(by_c[c])} of {len(doms)} surfaces.")
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
    w("### The `proposed` queue\n")
    prop = collections.defaultdict(list)
    for (d, c), st in grid.items():
        if st == "proposed":
            prop[c].append(d)
    if not prop:
        w("**Empty — every cell has been read.** `proposed` meant *one text signal fired and nobody")
        w("looked*. All 242 were opened and judged in")
        w("[`_review-decisions.md`](_review-decisions.md): 142 held up, 100 did not and moved to the")
        w("empty column above.\n")
        w("> A cell can only return to this state if a **new** surface or concern is added. The")
        w("> triage proxies do not get a second vote on a cell a human has read.\n")
    else:
        w(f"**{tally['proposed']} cells.** One signal fired, no human has read them. Ranked by concern")
        w("severity × queue length, so a reader can start where a single session buys the most:\n")
    if prop:
        SEV = {"C1": 5, "C8": 5, "C12": 5, "C7": 4, "C11": 4, "C9": 4,
               "C4": 3, "C5": 3, "C10": 3, "C3": 2, "C2": 2, "C6": 2}
        w("| Concern | Queued | Severity | Read first |")
        w("|---|---|---|---|")
        for c in sorted(cs, key=lambda c: -SEV[c.split()[0]] * len(prop[c])):
            if prop[c]:
                head = ", ".join("`%s`" % x for x in sorted(prop[c])[:4])
                more = f" +{len(prop[c]) - 4}" if len(prop[c]) > 4 else ""
                w(f"| **{c}** | {len(prop[c])} | {SEV[c.split()[0]]} | {head}{more} |")
        w("")
        w("> Resolving one is a read: open the surface's material, decide whether it genuinely")
        w("> addresses the concern, and record the verdict in `_review-decisions.md`.\n")
    w("---\n")
    w("## 4. Structural surfaces — populated from packs\n")
    w("The 4 structural surfaces have no `templates/domains/` folder, so the domain signals cannot")
    w("see them. Their material lives in packs, mapped by the **Material lives in** column of")
    w("[`_review-model.md`](_review-model.md) §2.2 — read from there, not hardcoded here, so the")
    w("mapping is reviewed in the file that owns the vocabulary.\n")
    w("The evidence method is **the same two signals**, not a third one: `description:`")
    w("frontmatter is the curated signal (every pack artifact carries one), the artifact body is")
    w("the full-text signal. Same thresholds, same three states.\n")
    w("| Structural surface | Packs read | Artifacts | Concerns backed by ≥2 |")
    w("|---|---|---|---|")
    for sfc, packs in sorted(structural_map().items()):
        n2 = sum(1 for c in cs if backing.get((sfc, c), 0) >= 2)
        w(f"| `{sfc}` | {', '.join('`%s`' % p for p in packs)} | {len(arts[sfc])} | {n2} / 12 |")
    w("")
    w("**Evidence strength is not symmetric with the domain half, and the grid does not pretend")
    w("otherwise.** A domain surface is backed by 2 files; a structural one by 8 to 46. So the")
    w("structural signal is measured **per artifact, never over a concatenated blob** — the first")
    w("attempt joined each pack's files into one string and scored `_routes` 12/12 confirmed,")
    w("because among 17 backend artifacts *some* description matches every concern. `confirmed`")
    w("here means **≥ 2 artifacts are individually about that concern**; one lone artifact out of")
    w("46 is `proposed`, not coverage.\n")
    w("> **Cross-cutting packs are deliberately excluded** — `security`, `performance`,")
    w("> `observability`, `testing`, `code-quality`, `finops` and the rest are axis-major and apply")
    w("> to every surface. Listing them under each structural surface would mark every cell")
    w("> confirmed by construction, which is the same over-counting that made the first full-text")
    w("> pass score 312/420. They are dispatched in wave B as global axes instead.\n")
    w("## 5. Artifacts behind the grid\n")
    n_files = sum(len(v) for v in arts.values())
    w(f"{n_files} artifacts across {len(doms)} surfaces — domain files for the 35 signal surfaces,")
    w("pack files (written `pack:name`) for the 4 structural ones. Every path is asserted to exist by")
    w("`validate-review-matrix.sh`, in both directions — a renamed file breaks the build, and an")
    w("artifact in no cell is reported.\n")
    w("```")
    for d in doms:
        names = [x if ":" in x else os.path.basename(x)[:-3] for x in arts[d]]
        w(f"{d.ljust(22)}{', '.join(names)}")
    w("```")
    open("templates/_review-matrix.md", "w", encoding="utf-8").write("\n".join(o) + "\n")
    print(f"wrote templates/_review-matrix.md — {total} cells: "
          f"{tally['confirmed']} confirmed, {tally['proposed']} proposed, {tally['empty']} empty")


if __name__ == "__main__":
    main()
