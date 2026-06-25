#!/usr/bin/env python3
"""gen-cheatsheet.py — GENERATE docs/CHEATSHEET.md from the command corpus.

The cheat sheet is a terse, auto-derived index of EVERY command (core + packs +
domains + baseline): name · one-line summary · flags · a usage example. It is
regenerated from the command files themselves so it can never silently drift —
add or change a command and re-running this reproduces the sheet.

  python3 scripts/gen-cheatsheet.py            # (re)write docs/CHEATSHEET.md
  python3 scripts/gen-cheatsheet.py --check     # exit 1 if the committed file is stale
  python3 scripts/gen-cheatsheet.py --stdout    # print to stdout, write nothing

DO NOT hand-edit docs/CHEATSHEET.md — edits are overwritten on the next run and
the CI gate (`--check`, see .github/workflows/quality-gates.yml) turns drift red.
Every field is derived mechanically:
  name/signature  ← the H1 line `# /name <args>`
  summary         ← frontmatter `description:`, first sentence
  flags           ← `--flag` tokens, minus not-supported / script / sibling noise
  example         ← first own-name line in a ``` fence, else `/name <signature>`, else `/name`
"""
import argparse
import difflib
import glob
import os
import re
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_REL = "docs/CHEATSHEET.md"
OUT_ABS = os.path.join(REPO_ROOT, OUT_REL)

# Files that live under a */commands/ path but are NOT commands.
EXCLUDE_BASENAMES = {"canonical-command-template.md"}

# External tools / runners whose flags belong to THEM, not the slash command.
EXTERNAL_TOOLS = {
    "npm", "pnpm", "yarn", "npx", "jest", "vitest", "mocha", "pytest", "tox",
    "go", "flutter", "dart", "gradle", "bash", "sh", "zsh", "fish", "python",
    "python3", "pip", "pip3", "node", "deno", "cargo", "rustc", "docker",
    "docker-compose", "kubectl", "helm", "terraform", "gh", "git", "curl",
    "wget", "jq", "sed", "awk", "grep", "tail", "head", "make", "ruby",
    "bundle", "rails", "php", "composer", "dotnet", "mvn", "xcodebuild", "pod",
    "eslint", "prettier", "tsc", "vite", "webpack", "psql", "redis-cli",
    # linters / db + migration tools / cloud CLIs that appear in example snippets
    "flake8", "pylint", "mypy", "ruff", "black", "rubocop", "prisma", "alembic",
    "sequelize", "typeorm", "knex", "goose", "dbmate", "flyway", "liquibase",
    "mongo", "mongosh", "sqlite3", "mysql", "aws", "gcloud", "az", "clinic",
}

# A line that DECLARES a flag is unsupported/invalid — its flags are not real. Kept to
# genuine non-support idioms (NOT lone words like "rejected"/"forbidden", which appear in
# ordinary flag descriptions, e.g. "the ADR was rejected").
NEG_RE = re.compile(
    r"not supported|does ?n.?.?t support|does ?n.?.?t exist|no longer support"
    r"|unsupported|not a (real )?flag|does ?n.?.?t accept|no such flag|invalid flag",
    re.I,
)

FLAG_RE = re.compile(r"(--[a-z][a-z0-9-]*)(=<[^>]+>)?")
SLASHCMD_RE = re.compile(r"^/[a-z][a-z0-9-]+$")
# Scans a line in order: each hit is either a slash-command (sets the current owner)
# or a flag (belongs to whoever the current owner is). This attributes `--target-rps`
# in `→ /audit --target-rps` to /audit, not to the command being documented.
TOKEN_RE = re.compile(r"(/[a-z][a-z0-9-]+)|(--[a-z][a-z0-9-]*)(=<[^>]+>)?")
H1_RE = re.compile(r"^#\s+(/[A-Za-z0-9][A-Za-z0-9-]*)\s*(.*)$")
# CSS custom properties (`--color-bg`, `--spacing-1`, `--radius-md`) look exactly
# like flags but are design tokens — never a command flag.
# Kept deliberately narrow: only prefixes that are design tokens AND never real flag
# names. (`surface`/`space`/`border` were removed — they collide with real flags such
# as `--surface-blockers`.)
CSS_VAR_RE = re.compile(
    r"^--(color|spacing|radius|font|shadow|ring|tracking|leading|z)(-|$)", re.I)
# A line that invokes the command's own backing project script — its flags ARE the
# command's flags (domain commands wrap a `.claude/skills/*.sh` or `pnpm/npm run`).
PROJECT_SCRIPT_RE = re.compile(r"\.claude/skills/\S+\.sh|pnpm run |npm run |yarn run ")
# Valid arg-signature tails start with one of these; anything else after the H1
# name (e.g. an em-dash tagline `# /foo — does things`) is NOT a signature.
SIG_START = ("<", "[", "(", "--", '"', "'")
# Abbreviations whose trailing period is NOT a sentence boundary (so a summary like
# "… renderer X vs. Y …" is not truncated at "vs.").
ABBREV = {"vs", "e.g", "i.e", "etc", "approx", "cf", "al", "fig", "no", "eq", "ca",
          "resp", "incl", "min", "max", "sec", "ms", "esp", "ie", "eg"}

SUMMARY_MAXLEN = 100


# ---------------------------------------------------------------------------
# discovery
# ---------------------------------------------------------------------------
def discover():
    """Return repo-relative paths of every real command file, deduped + sorted."""
    pats = [
        "commands/*.md",
        "templates/packs/*/commands/*.md",
        "templates/domains/*/commands/*.md",
        "templates/repo-baseline/.claude/commands/*.md",
        "templates/workspace-baseline/.claude/commands/*.md",
    ]
    seen = []
    for pat in pats:
        for p in glob.glob(os.path.join(REPO_ROOT, pat)):
            rel = os.path.relpath(p, REPO_ROOT).replace(os.sep, "/")
            base = os.path.basename(rel)
            if base in EXCLUDE_BASENAMES or base.startswith("_"):
                continue
            if "/tests/" in ("/" + rel):
                continue
            seen.append(rel)
    return sorted(set(seen))


# ---------------------------------------------------------------------------
# field extraction
# ---------------------------------------------------------------------------
def split_frontmatter(text):
    if not text.startswith("---"):
        return "", text
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.S)
    if not m:
        return "", text
    return m.group(1), text[m.end():]


def parse_description(frontmatter):
    m = re.search(r"^description:\s*(.*)$", frontmatter, re.M)
    if not m:
        return ""
    val = m.group(1).strip()
    # strip matching surrounding quotes
    if len(val) >= 2 and val[0] in "\"'" and val[-1] == val[0]:
        val = val[1:-1]
    return val.strip()


def first_sentence(desc):
    """First sentence — period boundary, skipping abbreviations (`vs.`, `e.g.`), single
    letters, and decimals so the summary is not truncated mid-phrase. Em/en dash is never
    a boundary."""
    desc = re.sub(r"\s+", " ", desc).strip()
    if not desc:
        return ""
    end = None
    for m in re.finditer(r"\.(\s|$)", desc):
        i = m.start()
        j = i
        while j > 0 and (desc[j - 1].isalnum() or desc[j - 1] in "-'"):
            j -= 1
        word = desc[j:i].lower().strip("-'")
        if word in ABBREV or (len(word) == 1 and word.isalpha()) or word.isdigit():
            continue
        end = i + 1
        break
    sent = strip_md(desc[:end] if end else desc)
    if len(sent) > SUMMARY_MAXLEN:
        cut = sent[:SUMMARY_MAXLEN].rsplit(" ", 1)[0].rstrip(" ,;:—-")
        sent = cut + "…"
    return sent


def strip_md(s):
    s = s.replace("`", "")
    s = re.sub(r"\*\*([^*]+)\*\*", r"\1", s)
    s = re.sub(r"\*([^*]+)\*", r"\1", s)
    return s.strip()


def parse_h1(body):
    for line in body.splitlines():
        m = H1_RE.match(line)
        if m:
            name = m.group(1)
            tail = m.group(2).strip()
            sig = tail if tail.startswith(SIG_START) else ""
            return name, sig
    return "", ""


def _norm(word):
    return word.strip("`*_~,;()[]\"'").strip()


def _is_external(tok):
    base = os.path.basename(tok)
    if tok in EXTERNAL_TOOLS or base in EXTERNAL_TOOLS:
        return True
    return tok.endswith(".sh") and ".claude/skills/" not in tok


def _ok_flag(flag):
    return not flag.endswith("-") and not CSS_VAR_RE.match(flag)


def _add_flag(flags, flag, val):
    if _ok_flag(flag):
        flags.setdefault(flag, flag + val)


def _strip_markers(line):
    """Remove leading list / quote / table markers + backtick so a flag-definition
    line exposes the flag as its first token."""
    code = re.sub(r"^[\s>*\-+|]+", "", line)
    return code.lstrip("`*")


def harvest_flags(body, own, signature):
    """Collect a command's flags ONLY from authoritative *declaration* positions, so
    prose mentions of other commands' / tools' / not-supported flags never leak in:

      1. the H1 signature  — every flag in the `# /cmd [<scope>] [--foo]` tail;
      2. a flag-definition line (outside fences) — a bullet / table row that STARTS with
         a flag after its markers; only the FIRST flag is the one being defined (later
         flags in the prose are references, e.g. "(capped by ...)");
      3. an own-invocation — flags reached after this command's own slash name or its
         backing project script on a line (an Overrides fence, a domain skills script,
         or even an inline example like "...or /migrate --from-plan <file>").

    The owner-walk starts with NO owner and only attributes flags once it has passed this
    command's own slash name (or own `.claude/skills/*.sh` / `pnpm run` script); a sibling
    command or an external tool (npm, jest, flutter, flake8, prisma, aws, ...) flips the
    owner away. So "Dispatch refactoring-sweep with --target", "No --force-overwrite", and
    "flake8 --max-complexity" never attach to the command. A "... not supported:" heading
    suppresses the flag bullets beneath it. CSS custom properties and `--glob-*` stubs are
    excluded."""
    flags = {}
    for m in FLAG_RE.finditer(signature or ""):
        _add_flag(flags, m.group(1), m.group(2) or "")

    in_fence = False
    suppress = False   # inside a "not supported:" bullet block
    for raw in body.splitlines():
        s = raw.strip()
        if s.startswith("```"):
            in_fence = not in_fence
            suppress = False
            continue
        if NEG_RE.search(raw):
            suppress = raw.rstrip().endswith(":")   # introduces a list of dead flags
            continue
        if suppress:
            if not s or not re.match(r"^[-*+|>]", s):
                suppress = False
            else:
                continue

        # (a) flag-definition line (outside fences): bullet/row whose first token is a flag
        if not in_fence:
            dm = FLAG_RE.match(_strip_markers(raw))
            if dm:
                _add_flag(flags, dm.group(1), dm.group(2) or "")

        # (b) own-invocation walk: owner starts unset; only flags reached after the own
        # slash name / own project script are collected
        script_line = bool(PROJECT_SCRIPT_RE.search(raw))
        owner = "own" if script_line else None
        for word in raw.split():
            tok = _norm(word)
            if SLASHCMD_RE.match(tok):
                owner = "own" if tok == own else "_other"
            elif ".claude/skills/" in tok or PROJECT_SCRIPT_RE.search(word):
                owner = "own"
            elif _is_external(tok) and not script_line:
                owner = "_other"
            elif tok.startswith("--") and owner == "own":
                fm = FLAG_RE.match(tok)
                if fm:
                    _add_flag(flags, fm.group(1), fm.group(2) or "")
    return list(flags.values())


def _clean_invocation(line):
    # cut a trailing aligned comment/note (real invocations use single spaces between
    # tokens; 2+ spaces precede an aligned `# ...` / `(note)` / `— note`)
    return re.split(r"\s{2,}", line.strip(), 1)[0].strip()


def find_example(body, name, signature):
    """Pick a copyable invocation: prefer a concrete own-name fence line (real args, no
    `<placeholder>`), then any arg-bearing own-name line, then the bare own-name line,
    then the H1 signature, then just the name. Syntax-tagline lines (`/foo — <id>`) and
    aligned trailing comments are stripped."""
    candidates = []
    in_fence = False
    for raw in body.splitlines():
        s = raw.strip()
        if s.startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            continue
        line = raw.strip()
        if line.startswith("$ "):
            line = line[2:].strip()
        if not line or line.startswith("#"):
            continue
        toks = line.split()
        if not toks or toks[0] != name:
            continue
        if len(toks) >= 2 and toks[1] in ("—", "–", "-", "|"):
            continue   # `/foo — <syntax>` tagline, not an invocation
        candidates.append(_clean_invocation(line))
    with_args = [c for c in candidates if len(c.split()) > 1]
    concrete = [c for c in with_args if "<" not in c]
    if concrete:
        return concrete[0], "bash-fence"
    if with_args:
        return with_args[0], "bash-fence"
    if candidates:
        return candidates[0], "bash-fence"
    if signature:
        return f"{name} {signature}", "signature"
    return name, "bare"


# ---------------------------------------------------------------------------
# classification (display grouping)
# ---------------------------------------------------------------------------
def classify(path):
    """Return (sort_key, section_title, tag)."""
    if path.startswith("commands/"):
        return ("0", "Core commands — global, run anywhere", None)
    m = re.match(r"templates/packs/([^/]+)/commands/", path)
    if m:
        pack = m.group(1)
        return (f"1:{pack}", f"Pack — {pack}", None)
    m = re.match(r"templates/domains/([^/]+)/commands/", path)
    if m:
        return ("2", "Domain commands — materialized when the domain is detected", m.group(1))
    if path.startswith("templates/repo-baseline/"):
        return ("3", "Baseline — universal infra (repo + workspace)", "repo")
    if path.startswith("templates/workspace-baseline/"):
        return ("3", "Baseline — universal infra (repo + workspace)", "workspace")
    return ("9", "Other", None)


def extract(path):
    try:
        with open(os.path.join(REPO_ROOT, path), encoding="utf-8") as fh:
            text = fh.read()
    except (OSError, UnicodeDecodeError):
        # unreadable / binary / vanished — degrade to a name-only row, never crash
        text = ""
    fm, body = split_frontmatter(text)
    name, signature = parse_h1(body)
    if not name:
        # fall back to filename so nothing is silently dropped
        name = "/" + os.path.splitext(os.path.basename(path))[0]
    summary = first_sentence(parse_description(fm))
    flags = harvest_flags(body, name, signature)
    example, _src = find_example(body, name, signature)
    sort_key, section, tag = classify(path)
    return {
        "name": name,
        "path": path,
        "summary": summary,
        "signature": signature,
        "flags": flags,
        "example": example,
        "sort_key": sort_key,
        "section": section,
        "tag": tag,
    }


# ---------------------------------------------------------------------------
# render
# ---------------------------------------------------------------------------
def cell(s):
    return s.replace("|", "\\|").strip()


def code(s):
    return "`" + s.replace("|", "\\|") + "`"


def render(records):
    # group by (sort_key, section) in sort order
    sections = {}
    for r in records:
        sections.setdefault((r["sort_key"], r["section"]), []).append(r)

    total = len(records)
    n_packs = len({k[0] for k in sections if k[0].startswith("1:")})
    n_core = sum(len(v) for k, v in sections.items() if k[0] == "0")
    n_dom = sum(len(v) for k, v in sections.items() if k[0] == "2")
    n_base = sum(len(v) for k, v in sections.items() if k[0] == "3")
    n_pack_cmds = sum(len(v) for k, v in sections.items() if k[0].startswith("1:"))

    out = []
    out.append("# Commands cheat sheet")
    out.append("")
    out.append("> **Generated file — do not edit by hand.** Regenerate with "
               "`python3 scripts/gen-cheatsheet.py`.")
    out.append("> The CI gate `gen-cheatsheet.py --check` turns drift red, so this stays "
               "in lock-step with the command files —")
    out.append("> add or change a command and re-run the generator. Full prose lives in "
               "[`COMMANDS.md`](COMMANDS.md) + [`REFERENCE.md`](REFERENCE.md).")
    out.append("")
    out.append(f"**{total} commands** — core {n_core} · {n_packs} packs ({n_pack_cmds}) · "
               f"domains {n_dom} · baseline {n_base}. Every field is derived from the "
               "command file (H1 + frontmatter); flags exclude not-supported / script / "
               "runner tokens.")
    out.append("")
    out.append("Columns: **Command** (with its arg signature shown in the example) · "
               "**Summary** (first sentence of the command's description) · "
               "**Flags** (`—` = none documented) · **Example**.")
    out.append("")

    # table of contents
    out.append("## Sections")
    out.append("")
    for (sk, title) in sorted(sections, key=lambda k: _natural(k[0])):
        anchor = _anchor(title)
        out.append(f"- [{title}](#{anchor}) — {len(sections[(sk, title)])}")
    out.append("")

    for (sk, title) in sorted(sections, key=lambda k: _natural(k[0])):
        rows = sorted(sections[(sk, title)], key=lambda r: (r["name"], r["path"]))
        out.append(f"## {title}")
        out.append("")
        out.append("| Command | Summary | Flags | Example |")
        out.append("|---|---|---|---|")
        for r in rows:
            nm = code(r["name"])
            if r["tag"]:
                nm += f" _({r['tag']})_"
            summ = cell(r["summary"]) or "—"
            flags = ", ".join(code(f) for f in r["flags"]) if r["flags"] else "—"
            ex = code(r["example"])
            out.append(f"| {nm} | {summ} | {flags} | {ex} |")
        out.append("")

    out.append("---")
    out.append("")
    out.append("_Duplicate names (e.g. `/refactor`, `/add-feature`, `/fix-bug`, "
               "`/cross-repo-task`, `/learn-from-task`) are pack-specialized variants — "
               "each appears under its own section with that pack's flags + summary._")
    out.append("")
    return "\n".join(out)


def _natural(sk):
    # sort: "0" < "1:align" < "1:backend" < ... < "2" < "3"
    head = sk.split(":", 1)[0]
    rest = sk.split(":", 1)[1] if ":" in sk else ""
    return (int(head) if head.isdigit() else 99, rest)


def _anchor(title):
    a = title.lower()
    a = re.sub(r"[^a-z0-9 -]", "", a)
    a = a.replace(" ", "-")
    return a


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def build():
    records = [extract(p) for p in discover()]
    return render(records), records


def main():
    ap = argparse.ArgumentParser(description="Generate docs/CHEATSHEET.md")
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if docs/CHEATSHEET.md is stale (no write)")
    ap.add_argument("--stdout", action="store_true",
                    help="print to stdout, write nothing")
    args = ap.parse_args()

    content, records = build()

    if args.stdout:
        sys.stdout.write(content + "\n")
        return 0

    if args.check:
        existing = ""
        if os.path.exists(OUT_ABS):
            with open(OUT_ABS, encoding="utf-8") as fh:
                existing = fh.read()
        norm = lambda t: t.replace("\r\n", "\n").rstrip("\n")
        if norm(existing) != norm(content):
            sys.stderr.write(
                f"FAIL — {OUT_REL} is stale ({len(records)} commands scanned).\n"
                "       A command was added/changed without regenerating the cheat sheet.\n"
                "       Run:  python3 scripts/gen-cheatsheet.py\n\n")
            diff = difflib.unified_diff(
                existing.splitlines(), content.splitlines(),
                fromfile=f"{OUT_REL} (committed)", tofile="generated", lineterm="")
            sys.stderr.write("\n".join(list(diff)[:60]) + "\n")
            return 1
        print(f"ok — {OUT_REL} is in sync ({len(records)} commands)")
        return 0

    with open(OUT_ABS, "w", encoding="utf-8") as fh:
        fh.write(content + "\n")
    print(f"wrote {OUT_REL} — {len(records)} commands")
    return 0


if __name__ == "__main__":
    sys.exit(main())
