#!/usr/bin/env python3
"""gen-pack-matrix.py — GENERATE assets/pack-matrix.svg from the pack corpus.

The pack matrix is the README's headline diagram: one row per track, with the agents,
skills, commands and rules each pack contributes, measured on disk. It used to be
hand-authored, so it silently trailed the filesystem — the render still said "twenty
packs" three packs after data-engineering, finops and product landed, and its own
footnote described a counting method (`skills -maxdepth 1 -name '*.md'`) that yields
zero because skills ship as `<name>/SKILL.md`. Generating it removes that whole drift
class: the picture is now derived, not asserted.

  python3 scripts/gen-pack-matrix.py            # (re)write assets/pack-matrix.svg
  python3 scripts/gen-pack-matrix.py --check    # exit 1 if the committed file is stale
  python3 scripts/gen-pack-matrix.py --stdout   # print to stdout, write nothing

DO NOT hand-edit assets/pack-matrix.svg — edits are overwritten on the next run and the
CI gate (`--check`, see .github/workflows/quality-gates.yml) turns drift red.

Every field is derived mechanically:
  packs           <- templates/packs/<key>/ holding a _version.json (`_*` names skipped)
  agents/commands <- <pack>/{agents,commands}/*.md          (maxdepth 1)
  rules           <- <pack>/rules/*.md                      (maxdepth 1)
  skills          <- <pack>/skills/<name>/SKILL.md          (the shipped skill layout)
  always-applied  <- the `Always-applied` column of templates/packs/_registry.md
  summary         <- that row's `Summary` column, truncated on a word boundary to fit;
                     packs with no registry row fall back to their _essentials.md H1.
Bars are scaled per column against that column's own maximum, never across columns.
"""
import argparse
import difflib
import glob
import os
import re
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_REL = "assets/pack-matrix.svg"
REGISTRY_REL = "templates/packs/_registry.md"

SANS = ("-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,"
        "'Helvetica Neue',Arial,sans-serif")
MONO = ("ui-monospace,SFMono-Regular,'SF Mono',Menlo,Consolas,"
        "'Liberation Mono',monospace")

INK, MUTE, BODY = "#161b22", "#6b7684", "#3d4754"
TRACK, STRIPE, HAIR, PAPER = "#e7ecf2", "#f2f5f8", "#d5dce5", "#f7f9fb"

# (label, number-anchor x, bar x, bar width, bar fill). Bar width is the FULL track;
# a pack's fill is count/column-max of it.
COLUMNS = [
    ("AGENTS",   268, 274, 42, "#1a5fb4"),
    ("SKILLS",   352, 358, 42, "#0f6b52"),
    ("COMMANDS", 436, 442, 42, "#5b3d99"),
    ("RULES",    520, 526, 22, "#8a5a00"),
]

W, LEFT, RIGHT = 1040, 28, 1012
ROW_H, FIRST_BASELINE = 26, 149
ALWAYS_CX, SUMMARY_X = 176, 568
MAX_SUMMARY = 76

ONES = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight",
        "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen",
        "Sixteen", "Seventeen", "Eighteen", "Nineteen"]
TENS = ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy",
        "Eighty", "Ninety"]


def spell(n):
    """Spell a count for the headline. Falls back to digits outside 0-99."""
    if n < 20:
        return ONES[n]
    if n < 100:
        return TENS[n // 10] + ("" if n % 10 == 0 else "-" + ONES[n % 10].lower())
    return str(n)


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def num(v):
    """Trim a bar width to the repo's 5-decimal house format (6 -> '6', 22/3 -> '7.33333')."""
    return ("%.5f" % v).rstrip("0").rstrip(".")


def count(pack_dir, sub, pattern="*.md"):
    return len(glob.glob(os.path.join(pack_dir, sub, pattern)))


def count_skills(pack_dir):
    """Skills ship as <name>/SKILL.md, so a flat *.md sweep would report zero."""
    return len(glob.glob(os.path.join(pack_dir, "skills", "*", "SKILL.md")))


def read_registry(root):
    """key -> (always_applied: bool, summary: str) from the registry's markdown table."""
    path = os.path.join(root, REGISTRY_REL)
    rows = {}
    if not os.path.isfile(path):
        return rows
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if not line.startswith("| `"):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 4:
                continue
            key = cells[0].strip("`")
            rows[key] = (cells[1].lower() == "always", cells[3])
    return rows


def essentials_fallback(pack_dir):
    """A pack with no registry row still needs a summary — take its _essentials.md H1."""
    path = os.path.join(pack_dir, "_essentials.md")
    if not os.path.isfile(path):
        return ""
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("# "):
                return line[2:].strip()
    return ""


def shorten(text, limit=MAX_SUMMARY):
    """Cut to the column's width on a word boundary. Deterministic, so --check is stable."""
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    cut = text[:limit]
    if " " in cut:
        cut = cut[:cut.rfind(" ")]
    return cut.rstrip(" ,;:-—") + "…"


def collect(root):
    registry = read_registry(root)
    packs = []
    for pack_dir in sorted(glob.glob(os.path.join(root, "templates", "packs", "*"))):
        key = os.path.basename(pack_dir)
        if key.startswith("_") or not os.path.isfile(os.path.join(pack_dir, "_version.json")):
            continue
        always, summary = registry.get(key, (False, ""))
        packs.append({
            "key": key,
            "always": always,
            "summary": shorten(summary or essentials_fallback(pack_dir)),
            "counts": [count(pack_dir, "agents"), count_skills(pack_dir),
                       count(pack_dir, "commands"), count(pack_dir, "rules")],
        })
    return packs


def text(x, y, s, *, font=SANS, size=11, fill=BODY, weight=400, anchor=None, extra=""):
    a = ' text-anchor="%s"' % anchor if anchor else ""
    return ('<text x="%s" y="%s" font-family="%s" font-size="%s" fill="%s" '
            'font-weight="%d"%s%s>%s</text>' % (x, y, font, size, fill, weight, a, extra, s))


def render(root, packs):
    n = len(packs)
    maxima = [max((p["counts"][i] for p in packs), default=1) or 1 for i in range(4)]
    totals = [sum(p["counts"][i] for p in packs) for i in range(4)]
    last = FIRST_BASELINE + ROW_H * (n - 1)
    height = last + 169

    globals_ = len(glob.glob(os.path.join(root, "commands", "*.md")))
    patterns = len(glob.glob(os.path.join(root, "templates", "packs", "*", "ai-patterns", "*.md")))
    refs = len(glob.glob(os.path.join(root, "templates", "packs", "*", "references", "*.md")))
    always_keys = ", ".join(p["key"] for p in packs if p["always"])

    headline = "%s role-based packs" % spell(n)
    caption = ("Refract pack matrix: %s and the agents, skills, commands and rules "
               "each contributes" % headline.lower())
    desc = ("File counts measured on disk for each pack's agents, skills, commands and "
            "rules. Totals: %d agents, %d skills, %d pack commands, %d rules."
            % tuple(totals))

    o = []
    o.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
             'viewBox="0 0 %d %d" role="img" aria-label="%s">'
             % (W, height, W, height, esc(caption)))
    o.append("<title>%s</title>" % esc(caption))
    o.append("<desc>%s</desc>" % esc(desc))
    o.append('<rect x="0" y="0" width="%d" height="%d" rx="10" fill="%s" stroke="%s" '
             'stroke-width="1"/>' % (W, height, PAPER, HAIR))

    o.append(text(LEFT, 46, esc(headline), size=21, fill=INK, weight=700))
    o.append(text(LEFT, 70, "Work is organised by role, not by framework — one api-architect "
                            "works for every backend. /setup-project selects packs",
                  size=12.5, fill=MUTE))
    o.append(text(LEFT, 88, "from detection signals; %s are applied to every project regardless."
                  % spell(sum(1 for p in packs if p["always"])).lower(), size=12.5, fill=MUTE))

    hdr = dict(size=9.5, fill=MUTE, weight=700, extra=' letter-spacing="1.1"')
    o.append(text(LEFT, 118, "PACK", **hdr))
    o.append(text(ALWAYS_CX, 118, "ALWAYS", anchor="middle", **hdr))
    for label, nx, _, _, _ in COLUMNS:
        o.append(text(nx, 118, label, anchor="end", **hdr))
    o.append(text(SUMMARY_X, 118, "WHAT IT COVERS", **hdr))
    o.append('<line x1="%d" y1="126" x2="%d" y2="126" stroke="%s" stroke-width="1.2"/>'
             % (LEFT, RIGHT, HAIR))

    for i, p in enumerate(packs):
        y = FIRST_BASELINE + ROW_H * i
        if i % 2:
            o.append('<rect x="22" y="%d" width="996" height="%d" rx="0" fill="%s"/>'
                     % (y - 17, ROW_H, STRIPE))
        o.append(text(LEFT, y, esc(p["key"]), font=MONO, size=11.5, fill=INK, weight=600))
        if p["always"]:
            o.append('<circle cx="%d" cy="%d" r="3.5" fill="#0f6b52"/>' % (ALWAYS_CX, y - 4))
        for c, (_, nx, bx, bw, colour) in enumerate(COLUMNS):
            v = p["counts"][c]
            o.append(text(nx, y, v, font=MONO, size=11.5, weight=600, anchor="end"))
            o.append('<rect x="%d" y="%d" width="%d" height="5" rx="2.5" fill="%s"/>'
                     % (bx, y - 8, bw, TRACK))
            if v:
                o.append('<rect x="%d" y="%d" width="%s" height="5" rx="2.5" fill="%s"/>'
                         % (bx, y - 8, num(v * bw / maxima[c]), colour))
        o.append(text(SUMMARY_X, y, esc(p["summary"])))

    o.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-width="1.2"/>'
             % (LEFT, last + 15, RIGHT, last + 15, HAIR))
    o.append(text(LEFT, last + 37, "TOTAL", font=MONO, size=11.5, fill=INK, weight=700))
    for c, (_, nx, _, _, _) in enumerate(COLUMNS):
        o.append(text(nx, last + 37, totals[c], font=MONO, size=12, fill=INK,
                      weight=700, anchor="end"))
    o.append(text(SUMMARY_X, last + 37, "%d packs · %d ai-patterns and %d framework "
                  "references not counted" % (n, patterns, refs)))

    o.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-width="1"/>'
             % (LEFT, last + 67, RIGHT, last + 67, HAIR))
    o.append('<circle cx="31.5" cy="%d" r="3.5" fill="#0f6b52"/>' % (last + 107))
    foot = dict(size=10, fill=MUTE)
    o.append(text(LEFT, last + 89,
                  "Generated by scripts/gen-pack-matrix.py — {agents,commands,rules}/*.md "
                  "per pack; skills are skills/&lt;name&gt;/SKILL.md. Bars scale per column, "
                  "not across columns.", **foot))
    o.append(text(42, last + 106,
                  "Always applied — added to selected_tracks even when no detection signal "
                  "fires: %s." % esc(always_keys), **foot))
    o.append(text(LEFT, last + 123,
                  "The %d global commands in commands/ belong to no pack: %d pack + %d global "
                  "= %d. Domain and repo-baseline commands are counted in docs/CHEATSHEET.md,"
                  % (globals_, totals[2], globals_, totals[2] + globals_), **foot))
    o.append(text(LEFT, last + 140,
                  "not here. Always-applied flags and summaries come from "
                  "templates/packs/_registry.md; a pack with no row falls back to its "
                  "_essentials.md heading.", **foot))
    o.append("</svg>")
    return "\n".join(o) + "\n"


def main():
    ap = argparse.ArgumentParser(description="Generate assets/pack-matrix.svg from the pack corpus.")
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if the committed SVG differs from a fresh render")
    ap.add_argument("--stdout", action="store_true", help="print to stdout, write nothing")
    ap.add_argument("--repo-root", default=REPO_ROOT)
    args = ap.parse_args()

    root = os.path.abspath(args.repo_root)
    packs = collect(root)
    if not packs:
        print("FAIL  no packs found under templates/packs/ — wrong --repo-root?", file=sys.stderr)
        return 1
    fresh = render(root, packs)
    out_abs = os.path.join(root, OUT_REL)

    if args.stdout:
        sys.stdout.write(fresh)
        return 0

    if args.check:
        if not os.path.isfile(out_abs):
            print("FAIL  %s is missing — run: python3 scripts/gen-pack-matrix.py" % OUT_REL,
                  file=sys.stderr)
            return 1
        with open(out_abs, encoding="utf-8") as fh:
            have = fh.read()
        if have == fresh:
            print("pack-matrix: in sync (%d packs)" % len(packs))
            return 0
        diff = difflib.unified_diff(have.splitlines(True), fresh.splitlines(True),
                                    fromfile=OUT_REL + " (committed)",
                                    tofile=OUT_REL + " (regenerated)")
        sys.stderr.writelines(list(diff)[:60])
        print("\nFAIL  %s is stale — run: python3 scripts/gen-pack-matrix.py" % OUT_REL,
              file=sys.stderr)
        return 1

    with open(out_abs, "w", encoding="utf-8") as fh:
        fh.write(fresh)
    print("wrote %s (%d packs · %d agents · %d skills · %d commands · %d rules)"
          % ((OUT_REL, len(packs)) + tuple(sum(p["counts"][i] for p in packs) for i in range(4))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
