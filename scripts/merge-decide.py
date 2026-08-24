#!/usr/bin/env python3
"""merge-decide.py — the automatic merge decision engine for /setup-project.

WHAT THE OWNER ASKED FOR, VERBATIM: "that what setup do add new files and for existing
update it it compare and adjust it the setup must decide what to do enhance change or
override and the setup for the knowledge and other it keep mind the current but adjust it
if replace is safe do it and not loose any thing important".

Unpacked: a file the project does not have -> ADD. A file it has -> COMPARE, then DECIDE
automatically between ENHANCE / CHANGE / OVERRIDE. Keep project knowledge. If replacing is
SAFE, replace without asking. Never lose anything important.

WHY THIS EXISTS. A live run against two real repos produced 235 `MERGE` rows and handed
every one of them to "human review": 166 in capsolah-api (its report's own Summary line says
"Files with action needed: 166", all MERGE) and 69 in tenant-portal. Nothing in the framework
could close a MERGE row except a person, so in practice those files stay stale forever. That
is not a merge policy; it is the absence of one.

THE MEASUREMENT THIS IMPLEMENTS. "Different" is not the useful question, and neither is "does
it contain project identifiers" — every classifier built on either produced false negatives in
the direction that deletes the owner's work. The useful question is DID THE PACKS WRITE THIS
LINE? A corpus of every distinct line that ever appeared in any *.md at any commit of
claude-config (345 commits -> 5,367 historical blobs -> 139,716 canonical lines) answers it per
line. Of the 7,003 target-side lines those 235 rows put at risk, 4,212 (60.1%) are verbatim
historical pack text. A row where that figure is 100% can be replaced with a PROOF that nothing
is lost rather than a heuristic. Run against the two live reports, this engine decides:

    NO-OP        1 row    0.4%   identical once the anchor is set aside
    ENHANCE     12 rows   5.1%   target is a strict SUBSEQUENCE of the pack — zero deletions
    OVERRIDE   163 rows  69.4%   every deleted line is verbatim historical pack text
    ADJUST      28 rows  11.9%   project sections kept byte-for-byte, pack takes the rest
    DEFER       30 rows  12.8%   project content inside a section the pack also changed
    SKIP         1 row    0.4%   two packs, one installed path (M41 collision)

204 of 235 close automatically. DEFER is 12.8%, not the default. Audited independently
afterwards: 1,225 markdown files compared across the two repos, 203 changed, 0 lost project
knowledge.

TWO RULES THAT ARE LOAD-BEARING, both learned by watching a detector destroy real files:

 1. BURDEN OF PROOF SITS ON THE ENGINE. A line whose origin the corpus cannot prove is
    PRESUMED to be the owner's. An earlier classifier that presumed the opposite reached
    B=174 and destroyed two real files on the way.

 2. DETECTION RUNS ON RAW LINES. `pack_substantive_sha8` in study-existing.sh strips
    `[*_`]` before hashing. That is correct for a hash and catastrophic for detection: it
    turns `E2E_EMAIL` into `E2EEMAIL` and eats `.env.tenant`, which silently un-protected
    two files that carry exactly those tokens. Never reuse that normalization here.

THE HARD INVARIANT is enforced mechanically, on the bytes — once on the composed result before
anything touches disk, and again on the file read back after the write. Three legs, chosen so
they do not share a failure mode (§ fingerprint):

    LINES    every non-trivial line of the ORIGINAL whose origin the corpus cannot prove
    TOKENS   every path token that RESOLVES on disk and is absent from the current pack text
    REGIONS  every anchor block and every bare `## Project-specific` section, verbatim

A file that fails is refused, or rolled back from its backup, and downgraded to DEFER; the run
exits 3 so a rollback can never be reported as success. That layering is not decorative — the
first version of the rollback fixture in scripts/test-merge-decide.sh did not fire at all,
because every leg was derived from the same corpus the decision was, so a corpus that lied made
the decision and its own audit wrong together. The token and region legs exist because of that
failed fixture.

Usage:
    merge-decide.py <target-repo> [--apply] [--report=<path>] [--json=<path>]
                                  [--verbs=OVERRIDE,ENHANCE,ADJUST] [--only=<substr>]
                                  [--conservative] [--additive-only] [--no-ledger] [--quiet]
    merge-decide.py --self-test            # fixture suite, writes nothing outside its tmpdir
    merge-decide.py --verify-pairs=<tsv> --target=<repo>
                                           # audit-setup.sh C2n: which (backup, live) pairs lost
                                           # a line whose origin the corpus cannot prove

Exit: 0 ok / 1 target or report missing / 2 usage / 3 a write failed its invariant check
      (the file was rolled back; the run is reported red so nobody mistakes it for success)
"""

import os
import re
import sys
import json
import shutil
import difflib
import hashlib
import subprocess
import datetime

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(os.path.realpath(__file__))))

# ---------------------------------------------------------------------------------------
# § Canonicalization
# ---------------------------------------------------------------------------------------
# The deploy pipeline emits a snippet/governance reference in at least four spellings, and
# apply-study-decisions.sh rewrites only one of them. Every un-canonicalized spelling
# manufactures a phantom conflict: measured, one spelling class alone forced 5 rows from
# OVERRIDE to DEFER, purely because
#     pack     [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).
#     deployed `~/.claude/templates/snippets/review-action-plan.md`.
# are the same reference. Collapse every spelling to one token BEFORE asking the corpus.
#
# NOTE THE ABSENCE of any emphasis/backtick stripping here. See rule 2 in the header.
_SNIPREF = re.compile(r"\[`?([^\]`]*?(?:snippets|governance)/[A-Za-z0-9._-]+)`?\]\([^)]*\)")
_BAREREF = re.compile(
    r"(?:~/\.claude/templates/|\.\./\.\./\.\./|\.\./templates/|templates/)?"
    r"(snippets|governance)/([A-Za-z0-9._-]+\.md)"
)
_REFBACKTICK = re.compile(r"`(«REF:[^»]+»)`")


def canon(line):
    """One canonical spelling of a line, for provenance lookup only."""
    line = _SNIPREF.sub(lambda m: "«REF:" + m.group(1).rsplit("/", 1)[-1] + "»", line)
    line = _BAREREF.sub(lambda m: "«REF:" + m.group(2) + "»", line)
    line = _REFBACKTICK.sub(r"\1", line)
    return line.rstrip()


def canon_token(tok):
    """One canonical spelling of a PATH TOKEN, for pack-membership lookup.

    Same reason canon() exists for lines, and it bit in the same place twice. The packs write
    `../../../snippets/x.md`; the deploy rewrite turns that into `../templates/snippets/x.md`;
    the link TEXT beside it says `templates/snippets/x.md`. Three spellings, one file. Without
    this the "absent from the pack corpus" half of the token test is true for the deployed
    spelling of a framework file, and the invariant refuses to replace a file over a reference
    the framework itself wrote and then rewrote. MEASURED: 3 rows in capsolah-api
    (backend/commands/refactor.md, observability add-metrics.md and add-tracing.md) were
    refused on exactly this, and the run stopped being idempotent because of it.
    """
    m = _BAREREF.search(tok)
    if m:
        return m.group(1) + "/" + m.group(2)
    return tok.lstrip("./")


def lhash(line):
    return hashlib.sha1(canon(line).encode("utf-8", "replace")).hexdigest()[:12]


# Lines that carry no evidence either way, so their absence from the corpus proves nothing.
TRIVIAL = re.compile(r"^[\s\-*#>|=+.:,;()\[\]0-9]*$")
_DIGIT_RUN = re.compile(r"\d+")
FENCE = re.compile(r"^\s*```")
# A fence line carries evidence when its INFO STRING says something beyond the language.
# ```ts is structure; ```ts title="src/lib/http.ts" is a claim about this repo. Anything with
# whitespace, `=` or `/` after the backticks is the second kind.
FENCE_INFO = re.compile(r"^\s*```+[A-Za-z0-9_+-]*[\s=/].*\S")
# Markers this engine and apply-study-decisions.sh write themselves. They are framework
# output, so they must never count as unknown-origin project content — otherwise the SECOND
# run reads its own seam markers as owner knowledge and the row flips to DEFER forever.
ENGINE_MARKER = re.compile(r"^\s*<!--\s*setup-project:(merged-from-pack|kept|adjusted)")
ANCHOR_START = re.compile(r"^<!-- project-specific:start -->\s*$")
ANCHOR_END = re.compile(r"^<!-- project-specific:end -->\s*$")

# --- Lines apply-anchors.sh REGENERATES on every run -------------------------------------
#
# THE DEFECT THIS CLOSES, measured on capsolah-api. Phase 4.6 (apply-anchors.sh, hard contract
# M25) rewrites the `> Cite-able sources:` line of every anchor block from the values the
# CURRENT run resolved. On that repo the old value was `top-level: src/.` and `src/` does not
# exist — the real dirs are apps/, libs/, chrome-extension/ — so the repair was correct and
# 176 artifacts carried a false citation before it. Phase 5 C2n then called each of those 227
# repairs a KNOWLEDGE_LOSS, because the REGIONS leg protects an anchor block verbatim, and
# ordered the file restored from the backup: 227 of the audit's 255 failures, 89%, and the
# printed remedy would have re-installed the lie. Phase 4.6 and Phase 5 were in mechanical
# opposition and /setup-project could not exit 0 on that repo no matter how well it worked.
#
# THE RULE. An anchor line whose shape apply-anchors.sh emits is MACHINE OUTPUT with a value
# slot. It is protected by SHAPE, not by VALUE: the line must still be there, and its value
# may differ, because the phase whose job is to write it ran between the backup and the live
# file. Anything else inside the block — a hand-added bullet, a note the owner wrote — has no
# generated shape, is not matched here, and stays protected verbatim as before.
#
# WHY THIS CANNOT GO BLIND. The excuse is conditional on the shape being PRESENT in the
# result. Drop the anchor block wholesale and every key disappears with it, so every line
# reads as lost and the REGION violation fires exactly as it did before. Fixture:
# scripts/test-merge-decide.sh § 6.
ANCHOR_GEN_RE = re.compile(
    r"^>\s*Cite-able sources:"
    r"|^>\s*Auto-populated by\b"
    r"|^>\s*-\s*\*\*(?:Architecture|Naming|Testing|Data access|Error handling|"
    r"Detected load-bearing idioms|Stack placeholders pending|"
    r"Where this applies here|Relevance UNCONFIRMED)\*\*"
    r"|^##\s+Project-specific \(auto-generated"
)


def anchor_gen_key(line):
    """The shape-key of a line apply-anchors.sh regenerates, or None for everything else."""
    m = ANCHOR_GEN_RE.match(line)
    if not m:
        return None
    return "\u00abanchor-gen\u00bb" + re.sub(r"\s+", " ", m.group(0)).strip().lower()


def gcanon(line):
    """canon(), except a regenerated anchor line collapses to its shape-key.

    Every comparison in verify_invariant runs in this space, so the excuse is applied once,
    consistently, to the multiset test, the region test, the contiguity test and the order
    test at the same time — rather than four times with four chances to disagree.
    """
    k = anchor_gen_key(line)
    return k if k else canon(line)


def is_trivial(line):
    """True when a line is pure markdown structure and carries no measurable content.

    `---`, `|---|---|`, `1.`, `> ` — their absence from the corpus proves nothing, so treating
    them as evidence would defer every row.

    BUT A ROW OF NUMBERS IS DATA, NOT STRUCTURE. The character class alone matched
    `| 41 | 220 | 1800 |` — a markdown table row of pure numbers — which made it invisible to
    ALL THREE legs of the invariant at once: not a line (not evidence), no path token, no
    identifier, no region. DEMONSTRATED: three real-shaped capacity rows injected into an
    OVERRIDE target were silently deleted, no violation was raised, and `_merge-decisions.md`
    recorded "all 34 target line(s) this replaces are verbatim historical pack text" — false
    for exactly those three, which were never examined. Latency, cost, capacity, throughput
    and date tables are all this shape. Two or more numbers, or one number of two digits or
    more, is content; a single digit is a list marker.
    """
    if not TRIVIAL.match(line):
        return False
    runs = _DIGIT_RUN.findall(line)
    if len(runs) >= 2 or any(len(r) >= 2 for r in runs):
        return False
    return True


def is_evidence(line):
    """True when a line's absence from the corpus is meaningful."""
    if ENGINE_MARKER.match(line):
        return False
    if FENCE.match(line):
        return bool(FENCE_INFO.match(line))
    return not is_trivial(line)


# ---------------------------------------------------------------------------------------
# § Token vocabulary — kept in sync with study-existing.sh KNOW_* and audit-setup.sh C2n
# ---------------------------------------------------------------------------------------
SRC_EXT = (
    "ts|tsx|js|jsx|mjs|cjs|vue|svelte|py|go|rb|php|java|kt|kts|swift|scala|rs|cs|"
    "cpp|hpp|ex|exs|dart|sql|prisma|graphql|proto|tf|yaml|yml|json|toml|env|sh|md|css|scss|html"
)
PATH_RE = re.compile(r"[A-Za-z0-9_@.*-]+(?:/[A-Za-z0-9_@.*-]+)+\.(?:%s)\b" % SRC_EXT)
DOTFILE_RE = re.compile(r"(?<![\w./])\.[a-z][a-z0-9]*(?:\.[a-z0-9]+)+")
FILE_RE = re.compile(r"(?<![\w/.])[A-Za-z0-9_.-]+\.(?:%s)\b" % SRC_EXT)
IDENT_RE = re.compile(
    r"[A-Z][a-z0-9]+[A-Z][A-Za-z0-9]*|[A-Z][A-Z0-9]*_[A-Z0-9_]+|"
    r"[a-z][a-z0-9]*_[a-z0-9_]+|[A-Z][A-Za-z0-9]*(?:-[A-Z][A-Za-z0-9]*)+"
)
URL_RE = re.compile(r"https?://[^\s`)\]>,]+|localhost:\d+|127\.0\.0\.1:\d+|:\d{4,5}\b")
MARKER_RE = re.compile(
    r"project-specific:start|_refresh-decisions\.md|^##+\s*Project-specific|"
    r"\bADR-\d+|docs/adr/\d|ai/decisions/\d",
    re.I | re.M,
)
DEICTIC_RE = re.compile(
    r"\bthis (repo|repository|app|project|codebase|service|product)\b|"
    r"\bour (repo|app|project|codebase|stack|convention)\b|"
    r"\bin v[12]\b|\bv[12]'s\b|\bdon'?t exist in v[12]\b",
    re.I,
)
REPO_SHAPED = re.compile(
    r"^(apps|libs|src|packages|app|lib|components|modules|services|server|"
    r"client|pages|routes|prisma|migrations|config|scripts|test|tests)/"
)


# ---------------------------------------------------------------------------------------
# § Provenance corpus
# ---------------------------------------------------------------------------------------
# Built from claude-config's own git history: every distinct line that ever appeared in any
# *.md blob at any commit. A target line found here was written by the framework, so deleting
# it loses nothing the framework cannot put back. A line NOT found here is presumed to be the
# owner's.
#
# KNOWN LIMITATION, stated out loud rather than discovered later: the packs were authored
# partly by mining these very repos, so the corpus contains some of the owner's real
# identifiers -- `libs/database/src/repository/data-access.ts` ships in a historical pack as
# an "e.g.". A line with pack provenance therefore proves "the framework wrote this", not
# "this is not about your project". For a REPLACE decision that is the correct semantics: the
# framework may put back what the framework wrote.

class Corpus:
    def __init__(self, hashes, pack_paths, pack_idents, source, commits=0, blobs=0, lines=0,
                 pack_paths_current=None):
        self.hashes = hashes
        self.pack_paths = pack_paths
        self.pack_idents = pack_idents
        # Built from the pack files ON DISK, never from git history. The invariant check
        # leans on this one so that a corrupt, stale or absent history cannot widen what the
        # engine is willing to delete. See § verify_invariant.
        self.pack_paths_current = pack_paths_current if pack_paths_current is not None else set()
        self.source = source            # "git" | "packs-only" | "cache"
        self.commits, self.blobs, self.lines = commits, blobs, lines

    def wrote(self, line):
        return lhash(line) in self.hashes

    @property
    def degraded(self):
        return self.source == "packs-only"


def _git_root_for_packs(packs_root):
    """Find the real claude-config checkout even when invoked through ~/.claude symlinks.

    ~/.claude/scripts is a directory of per-file symlinks and ~/.claude/templates/packs is a
    symlink into the repo, so `dirname $0/..` lands on ~/.claude, which has no git history.
    Resolving the packs symlink is what gets us back to the checkout.
    """
    for cand in (REPO_ROOT, os.path.realpath(packs_root)):
        d = cand
        for _ in range(8):
            if os.path.isdir(os.path.join(d, ".git")):
                return d
            nd = os.path.dirname(d)
            if nd == d:
                break
            d = nd
    return None


def _packs_fingerprint(packs_root):
    """A digest of the pack set ON DISK: which files, how big, when last written.

    THE CACHE USED TO BE KEYED ON claude-config's HEAD SHA ALONE, and that is wrong in two
    directions at once. `--packs-root=<some other dir>` reported "Provenance: git — 139716
    canonical line(s)" and decided against the WRONG PACK SET — reproduced with an empty
    directory, which should have degraded the run to almost nothing and instead reused a full
    corpus. And uncommitted edits to the packs were invisible to `pack_paths_current`, which
    is the set the invariant's TOKEN leg leans on, so editing a pack and re-running graded
    against the committed text. Path, size and mtime are enough to notice both.
    """
    h = hashlib.sha1()
    h.update(os.path.realpath(packs_root).encode("utf-8", "replace"))
    try:
        for dirpath, dirnames, filenames in sorted(os.walk(packs_root, followlinks=True)):
            dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
            for fn in sorted(filenames):
                if not fn.endswith(".md"):
                    continue
                fp = os.path.join(dirpath, fn)
                try:
                    st = os.stat(fp)
                except OSError:
                    continue
                h.update(("%s|%d|%d\n" % (os.path.relpath(fp, packs_root), st.st_size,
                                          st.st_mtime_ns)).encode("utf-8", "replace"))
    except OSError:
        pass
    return h.hexdigest()[:12]


def _cache_dir(git_root):
    env = os.environ.get("REFRACT_PROVENANCE_CACHE")
    if env:
        return env
    base = git_root or REPO_ROOT
    return os.path.join(base, "tmp", "provenance")


def build_corpus(packs_root, use_git=True, quiet=False, rebuild=False):
    git_root = _git_root_for_packs(packs_root) if use_git else None
    head = None
    if git_root:
        try:
            head = subprocess.run(
                ["git", "-C", git_root, "rev-parse", "HEAD"],
                capture_output=True, text=True, check=True, timeout=30,
            ).stdout.strip()[:12]
        except Exception:
            git_root = None

    cdir = _cache_dir(git_root)
    cpath = os.path.join(cdir, "corpus-%s-%s.json" % (head or "none", _packs_fingerprint(packs_root)))
    if head and not rebuild and os.path.isfile(cpath):
        try:
            with open(cpath, encoding="utf-8") as f:
                d = json.load(f)
            return Corpus(set(d["h"]), set(d["p"]), set(d["i"]), "git",
                          d.get("commits", 0), d.get("blobs", 0), d.get("lines", 0),
                          set(d.get("pc", ())))
        except Exception:
            pass

    lines = set()
    commits = blobs = 0
    if git_root:
        if not quiet:
            sys.stderr.write("  building provenance corpus from %s git history (one-off, cached)...\n" % os.path.basename(git_root))
        try:
            revs = subprocess.run(["git", "-C", git_root, "rev-list", "HEAD"],
                                  capture_output=True, text=True, check=True, timeout=120).stdout.split()
            commits = len(revs)
            shas = set()
            # One `ls-tree` per commit is the honest enumeration; it is also the slow part,
            # which is exactly why the result is cached by HEAD sha.
            for c in revs:
                out = subprocess.run(["git", "-C", git_root, "ls-tree", "-r", c],
                                     capture_output=True, text=True, timeout=60).stdout
                for ln in out.splitlines():
                    parts = ln.split("\t", 1)
                    if len(parts) != 2 or not parts[1].endswith(".md"):
                        continue
                    f = parts[0].split()
                    if len(f) >= 3:
                        shas.add(f[2])
            blobs = len(shas)
            batch = subprocess.run(["git", "-C", git_root, "cat-file", "--batch"],
                                   input="\n".join(sorted(shas)), capture_output=True,
                                   text=True, timeout=300).stdout
            # `--batch` output is `<sha> blob <size>\n<contents>\n` repeated; splitting on the
            # header shape is enough because a header line can never be markdown content.
            for ln in batch.splitlines():
                if re.match(r"^[0-9a-f]{40} (blob|tree|commit|tag) \d+$", ln):
                    continue
                lines.add(canon(ln))
        except Exception as e:
            if not quiet:
                sys.stderr.write("  WARN provenance corpus from git failed (%s) — degrading to packs-only\n" % e)
            git_root = None

    # Current pack text always joins the corpus. Under --no-git it IS the corpus, which makes
    # the engine strictly more conservative (fewer proven lines -> fewer OVERRIDEs, more
    # DEFERs). Degrading toward caution is the only safe direction for this failure.
    pack_text_lines = []
    for dirpath, dirnames, filenames in os.walk(packs_root, followlinks=True):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for fn in filenames:
            if not fn.endswith(".md"):
                continue
            try:
                with open(os.path.join(dirpath, fn), encoding="utf-8", errors="replace") as f:
                    for ln in f:
                        c = canon(ln.rstrip("\n"))
                        lines.add(c)
                        pack_text_lines.append(c)
            except OSError:
                continue

    lines.discard("")
    hashes = {hashlib.sha1(l.encode("utf-8", "replace")).hexdigest()[:12] for l in lines}

    # The pack-corpus token sets. These are what stop a fingerprint rule firing on a path or
    # identifier the framework itself shipped -- the defect that produced 2/20 false positives
    # on the first validation panel (`ai/patterns/api-contract.md` resolves on disk only
    # because the framework installed it). Built from the FULL historical corpus, not just the
    # current packs, because a path can ship as an "e.g." in one release and be dropped in the
    # next while the deployed file still carries it.
    blob = "\n".join(lines)
    pack_paths = set(PATH_RE.findall(blob)) | set(DOTFILE_RE.findall(blob)) | set(FILE_RE.findall(blob))
    pack_paths = {canon_token(p) for p in pack_paths}
    pack_idents = set(IDENT_RE.findall(blob))

    cur_blob = "\n".join(pack_text_lines)
    pack_paths_current = {canon_token(p) for p in
                          (set(PATH_RE.findall(cur_blob)) | set(DOTFILE_RE.findall(cur_blob))
                           | set(FILE_RE.findall(cur_blob)))}
    corpus = Corpus(hashes, pack_paths, pack_idents, "git" if git_root else "packs-only",
                    commits, blobs, len(lines), pack_paths_current)
    if git_root and head:
        try:
            os.makedirs(cdir, exist_ok=True)
            tmp = cpath + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump({"h": sorted(hashes), "p": sorted(pack_paths), "i": sorted(pack_idents),
                           "pc": sorted(pack_paths_current),
                           "commits": commits, "blobs": blobs, "lines": len(lines)}, f)
            os.replace(tmp, cpath)
        except OSError:
            pass
    return corpus


# ---------------------------------------------------------------------------------------
# § File model — anchors, sections
# ---------------------------------------------------------------------------------------
H2 = re.compile(r"^##\s+(.*?)\s*$")
PROJECT_HEADING = re.compile(r"^##\s+project-specific\b", re.I)


def sec_key(heading_text):
    return re.sub(r"[*_`]", "", heading_text).strip().lower()


def split_anchors(text):
    """Return (body_without_anchor_blocks, [anchor_block_texts]).

    Mirrors stripped_target() in study-existing.sh, including its swallow of the single
    blank line the injection appends, so the two agree on what "the pack-derived content"
    of a deployed file is.
    """
    body, anchors, cur = [], [], None
    drop_blank = False
    for ln in text.split("\n"):
        if cur is not None:
            cur.append(ln)
            if ANCHOR_END.match(ln):
                anchors.append("\n".join(cur))
                cur = None
                drop_blank = True
            continue
        if ANCHOR_START.match(ln):
            cur = [ln]
            continue
        if drop_blank and not ln.strip():
            drop_blank = False
            continue
        drop_blank = False
        body.append(ln)
    if cur is not None:               # unterminated marker — keep the bytes, protect them
        anchors.append("\n".join(cur))
    return "\n".join(body), anchors


def section_spans(lines):
    """[(key, heading_line_or_None, start, end)] over a line list; preamble first."""
    spans, cur_key, cur_head, start = [], "«preamble»", None, 0
    for i, ln in enumerate(lines):
        m = H2.match(ln)
        if m:
            spans.append((cur_key, cur_head, start, i))
            cur_key, cur_head, start = sec_key(m.group(1)), ln, i
    spans.append((cur_key, cur_head, start, len(lines)))
    return [s for s in spans if s[2] < s[3] or s[1] is not None]


def project_regions(text):
    """Every region of a file that is protected WITHOUT asking the corpus anything.

    Two kinds, and the second exists because the first is not enough:
      * the `<!-- project-specific:start --> ... :end -->` block apply-anchors.sh writes;
      * a bare `## Project-specific ...` heading section with no markers around it.
    MEASURED: capsolah-api carries the heading in 274 artifacts and the markers in only 254.
    Twenty files hold hand-extended blocks that the anchor strip walks straight past and an
    override would delete — one of them documents the repo's entire tenant-resolution chain.
    """
    body, anchors = split_anchors(text)
    regions = [("anchor", "«anchor»", a) for a in anchors]
    lines = body.split("\n")
    for k, head, a, b in section_spans(lines):
        if head and PROJECT_HEADING.match(head):
            chunk = lines[a:b]
            # A REGION ENDS WHERE A NEW H1 BEGINS. section_spans splits on `## ` alone, so a
            # project block written ABOVE the pack's own document title swallows that title
            # and everything under it: ai/patterns/structured-logging.md's
            # `## Project-specific (Capsolah V1)` ran from line 17 to line 73 and the last
            # three lines of it were `# Pattern: Structured Logging` and the pack's own
            # one-line summary. Protecting those as OWNER content is wrong twice over — they
            # are pack text, and it forces any composer that de-duplicates the title into a
            # false "region shredded" violation. The owner's block is what precedes the title.
            for i in range(1, len(chunk)):
                if chunk[i].startswith("# "):
                    chunk = chunk[:i]
                    break
            while chunk and (not chunk[-1].strip() or chunk[-1].strip() == "---"):
                chunk.pop()
            regions.append(("heading", k, "\n".join(chunk)))
    return regions


def project_heading_sections(lines):
    """Keys of `## Project-specific ...` sections that are NOT inside an anchor block.

    MEASURED: capsolah-api has 274 artifacts carrying a `## Project-specific` heading but only
    254 carrying `<!-- project-specific:start -->`. Twenty files hold hand-extended blocks the
    anchor strip does not protect, and an override would delete them. The heading is therefore
    treated as a protected region in its own right.
    """
    return {k for (k, h, s, e) in section_spans(lines) if h and PROJECT_HEADING.match(h)}


# ---------------------------------------------------------------------------------------
# § Deploy-time rewrites — MUST stay in step with apply-study-decisions.sh
# ---------------------------------------------------------------------------------------
# CONTRACT (ratcheted by scripts/lint-setup-contracts.sh Rule 7): pack sources link to
# ../../../snippets/ and ../../../governance/, which resolve under templates/packs/*/commands/
# but not under a target's .claude/commands/. Any writer of pack content into a target must
# apply the same rewrite, or the file it just wrote re-flags as MERGE on the next run forever.
_DEPLOY_SNIP = [
    (re.compile(r"\]\(\.\./\.\./\.\./snippets/"), "](../templates/snippets/"),
    (re.compile(r"\]\(\.\./\.\./\.\./governance/"), "](../templates/governance/"),
]
_SKILLREF = re.compile(r"skills/([A-Za-z0-9_-]+)/SKILL\.md")


def rewrite_deployed(text, kind, target_root):
    """Apply the two deploy rewrites: snippet/governance links, and skill cross-references.

    The skill rewrite only ever points a reference at a file that EXISTS: canonical form is
    left alone whenever it resolves, and the flat form is used only when the flat twin is the
    one on disk. It never invents a link.
    """
    if kind in ("commands", "agents"):
        for rx, rep in _DEPLOY_SNIP:
            text = rx.sub(rep, text)

    def fix(m):
        name = m.group(1)
        if os.path.isfile(os.path.join(target_root, ".claude", "skills", name, "SKILL.md")):
            return m.group(0)
        if os.path.isfile(os.path.join(target_root, ".claude", "skills", name + ".md")):
            return "skills/%s.md" % name
        return m.group(0)

    return _SKILLREF.sub(fix, text)


# ---------------------------------------------------------------------------------------
# § Target resolution — by IDENTITY, not by path (M40)
# ---------------------------------------------------------------------------------------
def artifact_identity(base):
    return (os.path.basename(os.path.dirname(base)) + ".md") if base.endswith("/SKILL.md") else os.path.basename(base)


def target_dir_for_kind(target, kind):
    return {
        "commands": os.path.join(target, ".claude", "commands"),
        "agents": os.path.join(target, ".claude", "agents"),
        "skills": os.path.join(target, ".claude", "skills"),
        "rules": os.path.join(target, ".claude", "rules"),
        "ai-patterns": os.path.join(target, "ai", "patterns"),
    }.get(kind, os.path.join(target, ".claude", kind))


def resolve_target(target, kind, base):
    d = target_dir_for_kind(target, kind)
    if kind != "skills":
        p = os.path.join(d, base)
        return p if os.path.isfile(p) else None
    name = artifact_identity(base)[:-3]
    for p in (os.path.join(d, name, "SKILL.md"), os.path.join(d, name + ".md")):
        if os.path.isfile(p):
            return p
    return None


_FM_DESC = re.compile(r"^description:\s*(.+?)\s*$")


def _frontmatter_desc(text):
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return None
    for l in lines[1:]:
        if l.strip() == "---":
            return None
        m = _FM_DESC.match(l)
        if m:
            return m.group(1)
    return None


_FM_FIELD = re.compile(r"^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$")


def frontmatter_fields(text):
    """The frontmatter block as {field: value}. Empty when there is no frontmatter."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}
    out = {}
    for l in lines[1:]:
        if l.strip() == "---":
            break
        m = _FM_FIELD.match(l)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


def frontmatter_delta(tgt_raw, pack_norm):
    """[(field, old, new)] for every frontmatter field the merge would change.

    THESE ARE POLICY, NOT PROSE, and they changed silently. Measured on one run: 18 files
    changed frontmatter — `model: sonnet -> opus` on two agents and absent -> opus on two more,
    which is a COST change nobody approved; and `.claude/rules/migration-backend.md` went from
    `applies-to: every-code-writing-task-in-backend` to `v1-to-v2-ports` with
    `severity: must` -> `must (when a migration layout is detected)`, which NARROWS a MUST rule
    to a subset of the work it used to govern. The `why` column counted lines and said nothing
    about any of it.
    """
    a, b = frontmatter_fields(tgt_raw), frontmatter_fields(pack_norm)
    keys = sorted(set(a) | set(b))
    return [(k, a.get(k), b.get(k)) for k in keys if a.get(k) != b.get(k)]


def collision_score(pack_path, tgt_path, kind, target_root):
    """How well does THIS pack's text account for the file that is actually installed?

    M41 picks a winner among packs that ship the same command name. The winner used to be
    "whichever row the study report listed first", which is not a decision — it is an
    accident of section order. MEASURED on capsolah-api: `.claude/commands/refactor.md` was
    installed from code-quality (`description: Language-agnostic targeted refactor …`), and
    `backend/commands/refactor.md` claimed the path first and OVERRODE it with the backend
    variant. `/refactor` changed what it does and nobody was told. Reordering the report's
    pack sections flipped the winner between a 56-line and an 83-line overlay.

    The right question is which pack's text the installed file MATCHES. Two signals, in
    order: the frontmatter `description:` (a near-unique fingerprint of the variant), then
    the fraction of the installed body the pack accounts for line-for-line. Pack name breaks
    a remaining tie so the answer never depends on report order.
    """
    with open(pack_path, encoding="utf-8", errors="replace") as f:
        pack_raw = f.read()
    with open(tgt_path, encoding="utf-8", errors="replace") as f:
        tgt_raw = f.read()
    pack_norm = rewrite_deployed(pack_raw, kind, target_root)
    S = {canon(l) for l in nonblank(pack_norm)}
    tgt_body, _anch = split_anchors(tgt_raw)
    T = nonblank(tgt_body)
    ratio = (sum(1 for l in T if canon(l) in S) / float(len(T))) if T else 0.0
    pd, td = _frontmatter_desc(pack_norm), _frontmatter_desc(tgt_raw)
    desc = 1 if (pd and td and pd == td) else 0
    return desc, ratio


# ---------------------------------------------------------------------------------------
# § Fingerprint detector — a REPORTED second opinion, and one promoted rule
# ---------------------------------------------------------------------------------------
# WHAT THIS IS, STATED CORRECTLY. It used to be documented as "the SECOND, independent net",
# and it was not one: `detector_positive` was written onto the record and read NOWHERE in
# scripts/ or templates/. It never blocked a write and never changed a verb. On the five
# injected-knowledge probes that flipped rows OVERRIDE -> DEFER, the LINES leg caught 5 of 5
# and this detector fired on 1. The safety was real; the mechanism was not the one the comment
# claimed. So:
#
#   * R3 (project decision markers — `ADR-\d+`, `ai/decisions/\d`, `docs/adr/\d`, a
#     `## Project-specific` heading, a `project-specific:start` marker) IS a gate now. It
#     lives in verify_invariant as the MARKER violation class, it overrules provenance, and it
#     refuses 0 of the 235 real rows — which is what a precise rule costs.
#   * R1, R2, R4-R8 stay REPORTED, not enforced, and are printed per row and written into
#     `_merge-decisions.md`. Promoting them would buy false DEFERs and no safety the LINES leg
#     does not already provide. They are a second reader's opinion for a human, and they are
#     now actually shown to that human.
#
# Runs on unknown-origin lines only, and on RAW lines. Its rules are the ones that survived
# hand-validation on a 20-row seed-fixed panel (TP 2 / FP 0 / FN 0 / TN 18) plus a
# 3,145-line recall stress over every provenance-safe row (0 true false negatives).
#
# R1 and R2 carry a mandatory pack-corpus filter. Without it, R1 fires on framework files that
# resolve on disk only because the framework installed them -- `ai/patterns/api-contract.md`,
# `ai/conventions.md` -- which cost 2 false positives out of 20 on the first panel. The same
# two-condition form ("resolves on disk" AND "absent from the pack corpus") is what
# audit-setup.sh C2n needs and now has.
class RepoIndex:
    """Lazy, capped index of what actually exists in the target repo."""

    SKIP_DIRS = {".git", "node_modules", "dist", "build", "vendor", ".next", ".nuxt",
                 "coverage", "__pycache__", ".venv", "venv", "target", ".turbo", ".cache"}

    def __init__(self, root, max_files=40000):
        self.root = root
        self.paths = set()
        self.byname = {}
        n = 0
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in self.SKIP_DIRS]
            rel = os.path.relpath(dirpath, root)
            for fn in filenames:
                p = fn if rel == "." else os.path.join(rel, fn)
                self.paths.add(p)
                self.byname.setdefault(fn, []).append(p)
                n += 1
                if n >= max_files:
                    return

    def resolves(self, tok):
        t = tok.lstrip("./")
        if t in self.paths or os.path.exists(os.path.join(self.root, t)):
            return True
        for p in self.byname.get(os.path.basename(t), ()):
            if p.endswith(t):
                return True
        return False


def detect(lines, pack_text, corpus, ridx, projrx):
    """R1..R8 over raw unknown-origin lines. Returns (fired_any, evidence)."""
    blob = "\n".join(lines)
    pk_paths = {canon_token(p) for p in
                (set(PATH_RE.findall(pack_text)) | set(DOTFILE_RE.findall(pack_text))
                 | set(FILE_RE.findall(pack_text)))}
    pk_idents = set(IDENT_RE.findall(pack_text))
    pk_urls = set(URL_RE.findall(pack_text))

    paths = sorted({canon_token(t) for t in PATH_RE.findall(blob)} - pk_paths)
    dotf = sorted(set(DOTFILE_RE.findall(blob)) - pk_paths)
    bare = sorted(set(FILE_RE.findall(blob)) - pk_paths)
    idents = sorted(set(IDENT_RE.findall(blob)) - pk_idents)
    urls = sorted(set(URL_RE.findall(blob)) - pk_urls)

    def unknown_to_packs(t):
        return canon_token(t) not in corpus.pack_paths

    r1 = [t for t in paths if unknown_to_packs(t) and (ridx is None or ridx.resolves(t))]
    r1 += [t for t in bare if unknown_to_packs(t) and (ridx is None or ridx.resolves(t))]
    r1 += [t for t in dotf if unknown_to_packs(t) and (ridx is None or ridx.resolves(t) or ridx.resolves(t.lstrip(".")))]
    r2 = [t for t in idents if t not in corpus.pack_idents]
    r3 = [l for l in lines if MARKER_RE.search(l)]
    r5 = [t for t in paths if REPO_SHAPED.match(t) and unknown_to_packs(t)]
    r6 = [l for l in lines if projrx and projrx.search(l)]
    r7 = [u for u in urls if u not in corpus.pack_paths]
    r8 = [l for l in lines if DEICTIC_RE.search(l)]

    fired = []
    for name, hits in (("R1", r1), ("R2", r2), ("R3", r3), ("R5", r5),
                       ("R6", r6), ("R7", r7), ("R8", r8)):
        if hits:
            fired.append(name)
    if len(idents) >= 3:
        fired.append("R4")
    return bool(fired), {
        "fired": fired, "R1": r1[:8], "R2": r2[:8], "R3": r3[:3], "R4": len(idents),
        "R5": r5[:8], "R6": r6[:3], "R7": r7[:6], "R8": r8[:3],
    }


# ---------------------------------------------------------------------------------------
# § The classifier
# ---------------------------------------------------------------------------------------
# ⭐ BUCKET E IS A MERGE, NOT A SURRENDER.
#
# E means "the owner's own lines sit inside a section the pack also changed". It
# used to map to DEFER, and on the owner's two live repos that abandoned 27 files
# — `ai/patterns/multi-tenancy.md` over ONE line, `audit-knowledge.md` over one,
# `learn-from-task.md` over two. Their instruction was the opposite of asking:
# "if the new is best take it, if you need to take from the old do it — the
# purpose is merge or take the best".
#
# So E takes the same verb as D and [weave_section] resolves the overlap at LINE
# level: the pack's wording wins, every line the corpus cannot attribute to the
# framework is carried into it, and nothing is dropped. If the weave is ever
# wrong, `verify_invariant` catches it independently and rolls that file — and
# only that file — back to DEFER. The escape hatch still exists; it is just no
# longer the first answer.
VERB_OF_BUCKET = {"A": "NO-OP", "C": "ENHANCE", "B": "OVERRIDE", "D": "ADJUST", "E": "ADJUST"}


def nonblank(text):
    return [l.rstrip() for l in text.split("\n") if l.strip()]


def classify(pack_path, tgt_path, kind, corpus, target_root, ridx=None, projrx=None):
    with open(pack_path, encoding="utf-8", errors="replace") as f:
        pack_raw = f.read()
    with open(tgt_path, encoding="utf-8", errors="replace") as f:
        tgt_raw = f.read()

    # Compare against the DEPLOYED shape of the pack source, exactly as study-existing.sh
    # does, or every applied command re-flags as MERGE forever. `target_root` is passed in
    # rather than derived from `tgt_path`: three dirnames gets the root for
    # `.claude/commands/x.md` and lands on `.claude/skills` for `.claude/skills/x/SKILL.md`,
    # so the skill-shape rewrite silently never fired for exactly the artifact kind that has
    # two legal shapes — and the write path, which does have the real root, then produced a
    # file different from the one the classifier had judged.
    pack_norm = rewrite_deployed(pack_raw, kind, target_root)
    tgt_body, anchors = split_anchors(tgt_raw)

    S, T = nonblank(pack_norm), nonblank(tgt_body)
    sm = difflib.SequenceMatcher(None, S, T, autojunk=False)
    loss_idx, gain = [], 0
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op in ("replace", "delete"):
            gain += i2 - i1
        if op in ("replace", "insert"):
            loss_idx.extend(range(j1, j2))

    t_spans = section_spans(T)
    s_spans = section_spans(S)
    t_key_of = {}
    for k, h, a, b in t_spans:
        for i in range(a, b):
            t_key_of[i] = k
    s_keys = {k for (k, h, a, b) in s_spans}
    t_keys = {k for (k, h, a, b) in t_spans}
    proj_keys = project_heading_sections(T)

    unknown_idx = [j for j in loss_idx if is_evidence(T[j]) and not corpus.wrote(T[j])]
    unknown = [T[j] for j in unknown_idx]
    # A `## Project-specific` heading section is protected in its own right, so unknown lines
    # inside one are not "shared-section" conflicts even when the pack has a section by that
    # name -- the ADJUST composer keeps the whole block verbatim.
    unknown_shared = [T[j] for j in unknown_idx
                      if t_key_of.get(j) in s_keys and t_key_of.get(j) not in proj_keys]
    unknown_tonly = [l for l in unknown if l not in unknown_shared]

    if not loss_idx and not gain:
        bucket = "A"
    elif not loss_idx:
        bucket = "C"
    elif not unknown:
        bucket = "B"
    elif not unknown_shared:
        bucket = "D"
    else:
        bucket = "E"

    # HOW MANY OF THE DELETED LINES DOES THE CURRENT PACK ACTUALLY CARRY BACK?
    # "verbatim historical pack text" is true and is NOT the same claim as "the pack will
    # restore it". Measured across one run: OVERRIDE deleted 2,119 substantive lines that the
    # CURRENT packs do not contain, across 138 of 149 written files — e.g.
    # `.claude/rules/engineering-principles.md` lost its entire "Applies when" clause
    # machinery and its module-boundary hard rule. The files grew overall (net +3,013), so
    # this is a trade and not a loss, but the record has to state the trade rather than a
    # comfortable half of it.
    pack_now_lines = {canon(l) for l in S}
    lost_all = [T[j] for j in loss_idx if is_evidence(T[j])]
    lost_not_in_current = [l for l in lost_all if canon(l) not in pack_now_lines]

    rec = {
        "pack_lines": len(S), "tgt_lines": len(T),
        "loss_substantive": len(lost_all),
        "loss_absent_from_current_packs": len(lost_not_in_current),
        "loss_absent_sample": lost_not_in_current[:6],
        "frontmatter_changes": [{"field": f, "from": a, "to": b}
                                for (f, a, b) in frontmatter_delta(tgt_raw, pack_norm)],
        "loss_lines": len(loss_idx), "gain_lines": gain,
        "changed_lines": len(loss_idx) + gain,
        "loss_proven_pack": len(loss_idx) - len(unknown),
        "loss_unknown": len(unknown),
        "unknown_shared": len(unknown_shared),
        "unknown_target_only": len(unknown_tonly),
        "had_anchor": bool(anchors),
        "anchor_blocks": len(anchors),
        "project_heading_sections": sorted(proj_keys),
        "target_only_sections": [k for (k, h, a, b) in t_spans if k not in s_keys],
        "pack_only_sections": [k for (k, h, a, b) in s_spans if k not in t_keys],
        "unknown_sample": unknown[:10],
        "bucket": bucket,
        "verb": VERB_OF_BUCKET[bucket],
    }
    if unknown:
        fired, ev = detect(unknown, pack_norm, corpus, ridx, projrx)
        rec["detector_positive"], rec["detector"] = fired, ev
    else:
        rec["detector_positive"], rec["detector"] = False, {"fired": []}
    return rec, pack_norm, tgt_raw, tgt_body, anchors, S, T, s_spans, t_spans, s_keys, proj_keys


# ---------------------------------------------------------------------------------------
# § The composers — one per write verb
# ---------------------------------------------------------------------------------------
def _insertion_index(lines):
    """Where apply-anchors.sh would inject: after frontmatter + H1, before the first H2.

    Reproduced from find_insertion_line() in apply-anchors.sh so an OVERRIDE puts the block
    back exactly where the anchoring pass would have put it, and Phase 4.6 then finds it
    present and skips.
    """
    i, n = 0, len(lines)
    if n and lines[0].strip() == "---":
        i = 1
        while i < n and lines[i].strip() != "---":
            i += 1
        i = min(i + 1, n)
    h1 = None
    j = i
    while j < n:
        if lines[j].startswith("## "):
            return j
        if lines[j].startswith("# ") and h1 is None:
            h1 = j
            j += 1
            continue
        j += 1
    return (h1 + 1) if h1 is not None else i


def compose_override(pack_norm, anchors, heading_blocks=()):
    """Pack text, with every project-specific anchor block carried forward verbatim.

    OVERRIDE is licensed only when the corpus proves every deleted line is framework text.
    The anchor block is NOT part of that proof -- study-existing.sh strips it before comparing
    -- so it is never examined and must never be discarded. Carrying it is what makes the
    difference between "replace the pack-derived body" and "replace the file".
    """
    lines = pack_norm.split("\n")
    while lines and not lines[-1].strip():
        lines.pop()
    # A bare `## Project-specific` section carries no markers, so nothing upstream protects
    # it. It is appended rather than spliced because that is where the owner wrote it in every
    # observed case, and because appending cannot disturb the pack's own section order.
    for hb in heading_blocks:
        lines.append("")
        lines.extend([l for l in hb.split("\n") if not ENGINE_MARKER.match(l)])
    lines.append("")
    if not anchors:
        return "\n".join(lines)
    at = _insertion_index(lines)
    block = []
    for a in anchors:
        block.extend(a.split("\n"))
        block.append("")
    return "\n".join(lines[:at] + block + lines[at:])


def _strip_pack_tail(chunk, pack_line_set):
    """Drop a trailing block a kept chunk carries only because the pack's own H1 lives there.

    `section_spans` splits on `## ` alone, so a target whose owner wrote a `## Capsolah V1 —
    primary guidance lives elsewhere` note ABOVE the pack's `# Pattern: Saga` title has that
    H1, and the pack paragraph under it, sitting inside the kept section's span. Re-emitting
    the chunk verbatim then puts a SECOND copy of the document title into the file: verified
    on disk, ai/patterns/saga.md carried `# Pattern: Saga` at line 8 and again at line 149.
    Same defect in ai/patterns/structured-logging.md.

    This drops that tail ONLY when every non-blank line in it is already pack text that the
    result carries at the top, so the lines are not lost — they are de-duplicated. Anything
    the pack does not account for keeps the tail intact and the chunk is emitted whole.
    """
    last = None
    for i, l in enumerate(chunk):
        if l.startswith("# ") and canon(l) in pack_line_set:
            last = i
    if last is None:
        return chunk
    tail = chunk[last:]
    if not all(canon(l) in pack_line_set for l in tail if l.strip()):
        return chunk
    kept = chunk[:last]
    while kept and (not kept[-1].strip() or kept[-1].strip() == "---"):
        kept.pop()
    return kept


def weave_section(pack_chunk, tgt_chunk, corpus):
    """⭐ ONE SECTION, BOTH SIDES CHANGED. The pack's body is the structure; the
    owner's own lines are carried INTO it, each after the line it followed.

    This is the case that used to be bucket E and used to DEFER the whole file.
    Measured on the owner's two repos, that meant skipping
    `ai/patterns/multi-tenancy.md` over ONE line, `audit-knowledge.md` over one,
    `learn-from-task.md` over two — 27 files abandoned to protect 4 lines on
    average. The owner's instruction was never "ask me": it was "if the new is
    best take it, if you need to take from the old do it — the purpose is merge
    or take the best".

    The engine already knows, per LINE, who wrote it. So the section is resolved
    at line level rather than being surrendered at section level:

      * a target line the pack ALSO has  → an anchor. It is not emitted here; the
        pack's own copy carries it, which is how the pack's rewording wins.
      * a target line the CORPUS wrote   → framework text the pack has moved on
        from. Dropped: the pack body is its replacement.
      * a target line nobody can account for → the owner's. KEPT, and placed
        immediately after the last anchor above it, which is what "in its real
        context" means — the neighbour it was written next to.

    Lines above the first anchor go directly under the heading, in order. Lines
    whose anchor the pack removed go at the end of the section rather than being
    dropped — losing one is the only outcome this function may never produce, and
    `verify_invariant` re-checks that independently and rolls the file back to
    DEFER if this function is ever wrong.
    """
    pack_canon = {canon(l) for l in pack_chunk if l.strip()}

    # 🔴 A PROTECTED REGION IS INDIVISIBLE, and this is what the first draft got
    # wrong. `verify_invariant` requires regions to survive CONTIGUOUSLY, not
    # merely to survive. A region — an anchor block, a `## Project-specific`
    # block — routinely contains a line the pack ALSO has; treating that line as
    # an anchor split the block around the pack's copy of it, and the invariant
    # correctly refused all 13 tenant-portal writes and 6 of capsolah-api's.
    #
    # So inside a region every line is carried and none is an anchor: the block
    # travels whole, attached to the last anchor ABOVE it.
    guarded = set()
    for _kind, _k, body in project_regions("\n".join(tgt_chunk)):
        for bl in body.split("\n"):
            if bl.strip():
                guarded.add(canon(bl))

    carried, anchor, pending = [], None, []
    for line in tgt_chunk:
        if not line.strip():
            if pending:
                pending.append(line)
            continue
        c = canon(line)
        if c in guarded:
            pending.append(line)
            continue
        if c in pack_canon:
            if pending:
                carried.append((anchor, pending))
                pending = []
            anchor = c
            continue
        if corpus.wrote(line):
            continue
        pending.append(line)
    if pending:
        carried.append((anchor, pending))
    if not carried:
        return list(pack_chunk)

    def trimmed(chunk):
        c = list(chunk)
        while c and not c[-1].strip():
            c.pop()
        return c

    top, by_anchor = [], {}
    for a, lines in carried:
        if a is None:
            top.extend(lines)
        else:
            by_anchor.setdefault(a, []).extend(lines)

    def anchored():
        out, heading_done, left = [], False, dict(by_anchor)
        for line in pack_chunk:
            out.append(line)
            if not heading_done and line.lstrip().startswith("#"):
                heading_done = True
                if top:
                    out.append("")
                    out.extend(trimmed(top))
                continue
            if line.strip():
                c = canon(line)
                if c in left:
                    out.extend(trimmed(left.pop(c)))
        # An anchor the pack deleted. The line still ships — at the end of its
        # own section, the nearest true thing left to say about where it went.
        for lines in left.values():
            out.extend(trimmed(lines))
        return out

    def appended():
        out, heading_done = [], False
        tail = list(top)
        for _a, lines in carried:
            if _a is not None:
                tail.extend(lines)
        for line in pack_chunk:
            out.append(line)
            if not heading_done and line.lstrip().startswith("#"):
                heading_done = True
        if tail:
            out.append("")
            out.extend(trimmed(tail))
        return out

    # 🔴 ORDER IS PART OF THE CONTENT, and the anchored placement can break it.
    # Anchoring each run to the pack's copy of the line it followed puts the runs
    # in PACK order — and when the pack has reordered that material, the owner's
    # notes come out shuffled. `verify_invariant`'s ORDER leg caught this on all
    # 12 tenant-portal rows, and it was right to: a document whose sentences
    # moved reads differently even though every line survived.
    #
    # So the anchored result is CHECKED, not trusted. If the owner's lines would
    # come out in a different relative order than they went in, the whole set is
    # emitted contiguously at the end of the section in the order they were
    # written. That trades some adjacency for order, which is the right way round
    # — a note in the wrong neighbourhood is still readable; a paragraph whose
    # sentences swapped is not.
    want = [canon(l) for _a, lines in carried for l in lines if l.strip()]
    got = [c for c in (canon(l) for l in anchored() if l.strip()) if c in set(want)]
    seq, i = [], 0
    for c in got:
        if i < len(want) and c == want[i]:
            seq.append(c)
            i += 1
    return anchored() if i == len(want) else appended()


def compose_adjust(pack_norm, tgt_body, anchors, s_keys, proj_keys, corpus=None):
    """Pack body for every shared section; the target's own sections kept byte-for-byte AND
    IN THE PLACE THE OWNER PUT THEM.

    ADJUST is the verb for a file where the owner added sections the pack does not have. Every
    line it deletes is a line the corpus proved the framework wrote; every line the corpus
    could not account for lives in a section this composer copies verbatim.

    PLACEMENT IS TARGET ORDER. This used to append every kept section at end-of-file, and
    compose_enhance's own docstring already called that a correctness defect rather than a
    cosmetic one — the same reasoning applies here and harder. MEASURED on capsolah-api: 43
    kept sections across 23 of 28 ADJUST rows moved more than a quarter of the file downward.
    ai/patterns/migrations.md sent `## Project-specific (Capsolah V1)` from the second heading
    to the LAST, under sixteen sections of generic guidance, while the pack's EMPTY
    `## Project-specific (auto-generated…)` placeholder took the top. ai/patterns/saga.md sent
    `## Capsolah V1 — primary guidance lives elsewhere` — a note whose entire purpose is to be
    read before the generic advice — to the bottom of the generic advice.

    verify_invariant could not see any of it, because its LINES leg is set membership over
    canon(line) and a set has no order. That is not knowledge loss in the byte sense; it is
    knowledge loss in the operational sense, because an agent reading top-down now meets the
    generic pack body first and an empty placeholder where the project block used to be.

    So the target's section ORDER is the skeleton. Each target section is emitted in place:
    a section the pack also owns is emitted with the PACK's body (that is what makes this a
    merge and not a keep), and a section only the target has is emitted verbatim, marked.
    Pack-only sections are spliced after the nearest preceding pack section the target
    actually has — the same rule compose_enhance uses, and the reason both are idempotent.
    """
    t_lines = tgt_body.split("\n")
    p_lines = pack_norm.split("\n")
    pack_line_set = {canon(l) for l in p_lines}

    def trim(chunk):
        c = list(chunk)
        while c and not c[-1].strip():
            c.pop()
        return c

    def keep_block(key, chunk):
        name = re.sub(r"\s+", "-", key)
        return (["<!-- setup-project:kept-project-section name=%s -->" % name]
                + chunk + ["<!-- setup-project:kept-project-section end -->"])

    # --- the pack, as an ORDERED LIST of sections, not a dict ----------------------------
    # SECTION KEYS REPEAT, and a dict silently swallows the repeats. ai/patterns/adr-template.md
    # ships `## Context` three times, `## Decision`, `## Consequences` and `## Alternatives
    # considered` twice each — once as the blank template, once inside the worked ADR example,
    # with different bodies. Keying by name collapsed 43 line-instances out of that one file in
    # the first draft of this composer. Occurrences are matched positionally: the n-th `##
    # Context` in the target takes the n-th `## Context` in the pack.
    p_pre, p_secs = [], []
    for k, head, a, b in section_spans(p_lines):
        if head is None:
            p_pre = p_lines[a:b]
            continue
        p_secs.append((k, trim(p_lines[a:b])))
    p_pre = trim(p_pre)
    p_by_key = {}
    for i, (k, _c) in enumerate(p_secs):
        p_by_key.setdefault(k, []).append(i)

    # --- walk the TARGET in its own order -------------------------------------------------
    # A block's key is the PACK INDEX it came from (an int) or None for a kept target section.
    # ⭐ THE PREAMBLE IS WOVEN TOO, not simply surrendered to the pack.
    #
    # "The pack owns the preamble by definition" holds when everything above the
    # first heading is framework boilerplate — and for most files it is. It is
    # false for a file whose H1 the owner rewrote: `ai/patterns/multi-tenancy.md`
    # deferred on exactly one violation, `LINE # Multi-Tenancy Pattern`, its own
    # title, because this branch dropped it before any section logic ran. Weaving
    # it costs nothing when the preamble is boilerplate (nothing is unattributed,
    # so the pack's copy is returned unchanged) and saves the file when it is not.
    t_pre = []
    for k, head, a, b in section_spans(t_lines):
        if head is None:
            t_pre = trim([l for l in t_lines[a:b] if not ENGINE_MARKER.match(l)])
            break
    blocks = [(None, weave_section(p_pre, t_pre, corpus)
               if (corpus is not None and t_pre) else p_pre)]
    consumed = set()
    seen = {}
    for k, head, a, b in section_spans(t_lines):
        if head is None:
            continue                               # handled above
        # The target's own section. Drop this engine's OWN seam markers before re-wrapping:
        # without it the second run reads the `end -->` line it wrote as part of the section
        # body, wraps it again, and the file grows one marker per run — measured, 28 of 28
        # ADJUST rows drifted on run 2.
        own = trim([l for l in t_lines[a:b] if not ENGINE_MARKER.match(l)])
        own = _strip_pack_tail(own, pack_line_set)
        if k in s_keys and k not in proj_keys:
            n = seen.get(k, 0)
            seen[k] = n + 1
            idxs = p_by_key.get(k, ())
            if n < len(idxs):
                pi = idxs[n]
                consumed.add(pi)
                chunk = p_secs[pi][1]
                # ⭐ With a corpus, a shared section is WOVEN rather than replaced:
                # the pack's body wins the wording, the owner's own lines are
                # carried into it. Without one the old behaviour stands, so a
                # degraded corpus can never silently start dropping lines.
                if corpus is not None:
                    chunk = weave_section(chunk, own, corpus)
                blocks.append((pi, chunk))
            elif own:
                # The target repeats a heading more times than the pack does. The extra copy
                # has no pack counterpart, so it is the target's own and is kept verbatim.
                blocks.append((None, keep_block(k, own)))
            continue
        if own:
            blocks.append((None, keep_block(k, own)))

    # --- splice the pack sections the target does not have, in pack order ------------------
    # Each goes next to its pack NEIGHBOUR: after the nearest preceding pack section already
    # in the result, or failing that before the nearest following one. Sections placed earlier
    # in this loop join `blocks`, so a run of consecutive pack-only sections chains off one
    # another and keeps pack order without any special case.
    #
    # THE FALLBACK IS END-OF-FILE, NOT TOP-OF-FILE, and that is the whole point. When the two
    # documents share NO section names at all — ai/patterns/tenant-isolation.md, where the
    # pack is a security lens and the installed file is the project's own row-level isolation
    # contract — there is no neighbour to anchor to, and inserting after the preamble would
    # push every one of the owner's sections below the entire generic body. That is the
    # defect, restated: `## Capsolah V1 — primary guidance lives elsewhere` is a note whose
    # only job is to be read BEFORE the generic advice. Target order wins; the pack body
    # follows it.
    for pi, (k, chunk) in enumerate(p_secs):
        if pi in consumed:
            continue
        at = None
        for prev in range(pi - 1, -1, -1):
            pos = next((n for n, (bk, _l) in enumerate(blocks) if bk == prev), None)
            if pos is not None:
                at = pos + 1
                break
        if at is None:
            for nxt in range(pi + 1, len(p_secs)):
                pos = next((n for n, (bk, _l) in enumerate(blocks) if bk == nxt), None)
                if pos is not None:
                    at = pos
                    break
        if at is None:
            at = len(blocks)
        blocks.insert(at, (pi, chunk))
        consumed.add(pi)

    out = []
    for _k, lines in blocks:
        if out:
            out.append("")
        out.extend(lines)
    while out and not out[-1].strip():
        out.pop()
    out.append("")

    if anchors:
        at = _insertion_index(out)
        block = []
        for a in anchors:
            block.extend(a.split("\n"))
            block.append("")
        out = out[:at] + block + out[at:]
    return "\n".join(out)


def compose_enhance(pack_norm, tgt_raw):
    """Splice in the pack's `## ` sections that the target does not have. Deletes nothing.

    This is the single implementation of the additive merge. `--include=merge-additive` in
    apply-study-decisions.sh routes here; the bash copy that used to live there was removed
    rather than left to drift, and lint-setup-contracts.sh Rule 7 keeps it removed.

    PLACEMENT IS PACK ORDER, not end-of-file, and that is a correctness property rather than a
    cosmetic one. Appending at the end -- what the bash version did -- leaves the new block out
    of sequence, so the NEXT diff sees the same text as both a target-only loss and a pack-side
    gain and re-classifies the row. Measured: `.claude/agents/performance-optimizer.md` was
    ENHANCE on run 1 (loss 0, gain 13) and OVERRIDE on run 2 (loss 13, gain 13). It converged
    on run 3 and lost nothing on the way, but "converges eventually" is not idempotent. Each
    pack-only section is therefore spliced directly after the nearest preceding pack section
    the target actually has, which leaves every existing target section exactly where it was.
    """
    src_lines = pack_norm.split("\n")
    tgt_lines = tgt_raw.split("\n")
    while tgt_lines and not tgt_lines[-1].strip():
        tgt_lines.pop()
    tgt_spans = section_spans(tgt_lines)
    tgt_end_of = {}
    for k, head, a, b in tgt_spans:
        tgt_end_of[k] = b

    inserts = {}          # target line index -> [lines to splice in there]
    added = []
    last_shared_key = None
    for k, head, a, b in section_spans(src_lines):
        if head is None:
            last_shared_key = "«preamble»"
            continue
        text = head[3:].strip()
        if text and text in tgt_raw:
            last_shared_key = k
            continue
        chunk = src_lines[a:b]
        while chunk and not chunk[-1].strip():
            chunk.pop()
        at = tgt_end_of.get(last_shared_key, len(tgt_lines))
        block = ["", "<!-- setup-project:merged-from-pack section=%s -->" % re.sub(r"\s+", "-", text)]
        block += [l for l in chunk if not ENGINE_MARKER.match(l)]
        block.append("<!-- setup-project:merged-from-pack end -->")
        inserts.setdefault(at, []).extend(block)
        added.append(text)

    out = []
    for i, l in enumerate(tgt_lines):
        for x in inserts.get(i, ()):
            out.append(x)
        out.append(l)
    for x in inserts.get(len(tgt_lines), ()):
        out.append(x)
    out.append("")
    return "\n".join(out), added


# ---------------------------------------------------------------------------------------
# § The hard invariant — checked on the bytes actually written
# ---------------------------------------------------------------------------------------
def fingerprint(original_text, corpus, target_root):
    """(protected_lines, protected_tokens, protected_regions) — what must survive any write.

    THREE LEGS, DELIBERATELY NOT SHARING A FAILURE MODE. This matters more than it looks:
    the first draft derived all of them from the provenance corpus, so a corpus that was
    wrong made the classifier AND its own safety net wrong in the same direction. The fixture
    in scripts/test-merge-decide.sh proved it — fed a corpus that declared the owner's lines
    to be pack text, the engine reached OVERRIDE, found nothing to protect, and wrote. A net
    that fails whenever the thing it is checking fails is not a net.

      LINES (corpus-dependent). Every non-trivial line of the ORIGINAL whose origin the
        corpus cannot prove. Strictly stronger than any token rule, and the only leg that
        catches NEGATIVE knowledge — "BaseModal, FormField, useCrud ... don't exist in v1" is
        expressed about identifiers that are ABSENT from the repo, so no presence test sees it.

      TOKENS (independent of git history). Path tokens anywhere in the ORIGINAL that RESOLVE
        on disk AND are absent from the CURRENT pack text. Both conditions are required:
        resolution alone fires on framework files that exist only because the framework
        installed them (`ai/patterns/api-contract.md`), which cost 2 false positives out of 20
        on the first validation panel.

      REGIONS (independent of everything). Anchor blocks and bare `## Project-specific`
        sections, verbatim. No corpus, no disk, no heuristic — if it was in the original it is
        in the result.
    """
    lines = [l.rstrip() for l in original_text.split("\n")]
    prot_lines = [l for l in lines if l.strip() and is_evidence(l) and not corpus.wrote(l)]

    # THE CURRENT PACKS, NOT THE HISTORICAL ONES. This is the one place the provenance thesis
    # has to be overruled, and the reason is the limitation stated in § Provenance corpus: the
    # packs were authored partly by MINING THESE REPOS, so the history contains the owner's own
    # identifiers as pack "e.g." text. `libs/database/src/repository/data-access.ts` is the
    # owner's DataAccess base class; it ships in a HISTORICAL pack as an example and in no
    # current one. Excluding it because a 2026-04 pack once mentioned it means the framework
    # gets to delete a reference to the project's own file on the strength of having once
    # copied it — which is exactly backwards.
    #
    # A path that the CURRENT packs still ship is framework text and stays excluded; the
    # framework can put back what the framework currently writes. A path that only the history
    # knows, and that RESOLVES in this repo, is about this project today.
    #
    # MEASURED cost of the change, on the real rows: 3 of 164 OVERRIDE rows across the two
    # repos stop being replaceable outright — `.claude/skills/extract-base-class-idiom.md`
    # (data-access.ts, a true protection), `.claude/commands/design-system.md`
    # (ai/patterns/event-bus.md, the project's own pattern doc — a true protection), and
    # `.claude/commands/refactor.md` (../skills/refactoring-sweep.md, a framework file — a
    # false positive in the safe direction). None of them is deferred: see the ADJUST fallback
    # in § main, which recomposes and re-verifies before giving up on a row.
    pack_now = corpus.pack_paths_current or corpus.pack_paths
    toks = set()
    whole = "\n".join(lines)
    for t in set(PATH_RE.findall(whole)) | set(FILE_RE.findall(whole)) | set(DOTFILE_RE.findall(whole)):
        tt = canon_token(t)
        if tt in pack_now:
            continue
        if (os.path.exists(os.path.join(target_root, tt))
                or os.path.exists(os.path.join(target_root, ".claude", tt))):
            toks.add(t)
    # Identifiers are harvested from the lines the OWNER wrote. A regenerated anchor line
    # (ANCHOR_GEN_RE) carries whatever the profile said this run — `Vitest`, `PascalCase`,
    # a base-class name — and Phase 4.6 rewrites it from the profile every time, so an
    # identifier that only ever appeared there is not a fact the write destroyed.
    for t in set(IDENT_RE.findall("\n".join(l for l in prot_lines if anchor_gen_key(l) is None))):
        if t not in corpus.pack_idents:
            toks.add(t)
    return prot_lines, toks, project_regions(original_text)


def _significant(lines):
    """The lines a reader would actually see: no blanks, no seam markers this engine writes.

    Compared in gcanon() space so a regenerated anchor line (see ANCHOR_GEN_RE) matches by
    shape. Without that, the contiguity test reports every re-cited anchor block as SHREDDED.
    """
    return [gcanon(l) for l in lines if l.strip() and not ENGINE_MARKER.match(l)]


def _contiguous(hay, needle):
    """Is `needle` a contiguous run inside `hay`? Both are lists of canonical lines."""
    if not needle:
        return True
    n = len(needle)
    first = needle[0]
    for i in range(len(hay) - n + 1):
        if hay[i] == first and hay[i:i + n] == needle:
            return True
    return False


def _in_order(hay, needle):
    """Is `needle` a subsequence of `hay`, in order? Returns the first line that is not."""
    it = iter(hay)
    for x in needle:
        for y in it:
            if y == x:
                break
        else:
            return x
    return None


def new_dangling_refs(original_text, result_text, target_root, ridx=None):
    """Repo-relative paths the RESULT names, the ORIGINAL did not, and that do not resolve.

    THE INVARIANT CONSTRAINS LOSS AND NOTHING CONSTRAINS GAIN. Measured against a post-run
    tree: 19 files gained 29 in-repo path references that do not resolve —
    `.claude/agents/api-contract-sentry.md` began citing src/lib/http.ts and
    src/composables/usePaymentMethods.ts; `.claude/commands/rollback-deploy.md` began citing
    ai/runbooks/2026-08-22-prod-rollback.md. Every one sampled was pack EXAMPLE output or a
    forward reference to a ledger a sibling command creates on first use, so none was a defect
    — but "none of the ones I sampled" is not a measurement, and the class was unbounded.

    This does not block a write. A pack example that names a plausible path is legitimate and
    a rule that refused it would refuse most of the packs. It is counted and recorded, so the
    class has a number attached to it and a regression would show up as that number moving.
    """
    before = set(PATH_RE.findall(original_text))
    after = set(PATH_RE.findall(result_text))
    out = []
    for t in sorted(after - before):
        tt = canon_token(t)
        if not (REPO_SHAPED.match(tt) or tt.startswith("ai/") or tt.startswith(".claude/")):
            continue
        if os.path.exists(os.path.join(target_root, tt)):
            continue
        if ridx is not None and ridx.resolves(tt):
            continue
        out.append(t)
    return out


def verify_invariant(original_text, result_text, corpus, target_root):
    """Return (ok, [violations]). Runs on the RESULT, never on the intent.

    FIVE CHECKS OVER THE THREE LEGS. The first draft compared SETS of canonical lines, which
    left three blind spots, two of them measured biting:

      * MULTISET, not set. A file that says the same protected line twice and comes back
        saying it once has lost an instance, and a set cannot see that.
      * REGIONS must survive CONTIGUOUSLY. Line-by-line membership passes a region that has
        been shredded across the file — every line present, the block gone.
      * ORDER. This is the one that bit. compose_adjust relocated 43 kept sections across 23
        of 28 ADJUST rows to end-of-file, moving `## Project-specific (Capsolah V1)` from the
        second heading to the last and `## Capsolah V1 — primary guidance lives elsewhere`
        below the generic guidance it exists to precede. Every line was still present, so a
        set-membership check returned True on all 23. Order is not decoration in a file an
        agent reads top-down.
    """
    prot_lines, prot_toks, prot_regions = fingerprint(original_text, corpus, target_root)
    res_lines = result_text.split("\n")
    # gcanon(), not canon(): a line apply-anchors.sh regenerates is compared by SHAPE, so the
    # mandatory Phase 4.6 citation repair is not scored as a Phase 5 loss. See ANCHOR_GEN_RE.
    res_canon = [gcanon(l) for l in res_lines]

    have = {}
    for c in res_canon:
        have[c] = have.get(c, 0) + 1
    need = {}
    for l in prot_lines:
        c = gcanon(l)
        need[c] = need.get(c, 0) + 1

    lost_lines, lost_dupes = [], []
    seen = set()
    for l in prot_lines:
        c = gcanon(l)
        if c in seen:
            continue
        seen.add(c)
        short = have.get(c, 0)
        if short == 0:
            lost_lines.append(l)
        elif short < need[c]:
            lost_dupes.append((l, need[c], short))

    lost_toks = sorted(t for t in prot_toks if t not in result_text)

    # MARKERS — the R3 rule from the fingerprint detector, promoted from a reported opinion to
    # a gate. A line citing this project's own decision record — `ADR-007`, `ai/decisions/7-…`,
    # `docs/adr/…`, a `## Project-specific` heading, a `project-specific:start` marker — is
    # about THIS repo whatever the corpus says about its wording, because the corpus contains
    # pack EXAMPLES of the same shape. Provenance is the wrong question for these; presence is
    # the right one. Kept as a separate violation class so its cost is separately visible:
    # measured over both repos' 235 rows, it refuses NOTHING, which is what a precise rule
    # costs. R1/R2 were deliberately NOT promoted — on the five injected-knowledge probes the
    # LINES leg caught 5 of 5 and the detector 1 of 5, so promoting the noisy rules would buy
    # false DEFERs and no safety the LINES leg does not already provide.
    lost_markers = []
    for l in original_text.split("\n"):
        if not l.strip() or not MARKER_RE.search(l):
            continue
        if have.get(gcanon(l), 0) == 0:
            lost_markers.append(l)

    res_sig = _significant(res_lines)
    lost_regions, shredded = [], []
    for kind, _k, body in prot_regions:
        blines = body.split("\n")
        missing = [l for l in blines if l.strip() and gcanon(l) not in have]
        if missing:
            lost_regions.append((kind, len(missing), missing[0].strip()[:100]))
        elif not _contiguous(res_sig, _significant(blines)):
            shredded.append((kind, _significant(blines)[0][:100]))

    # ORDER runs only over the INSTANCES that are actually present, so it reports reordering
    # and never double-reports a loss the multiset check already named.
    present, used = [], {}
    for l in prot_lines:
        c = gcanon(l)
        n = used.get(c, 0)
        if n < have.get(c, 0):
            present.append(c)
            used[c] = n + 1
    out_of_order = _in_order(res_canon, present) if present else None

    v = []
    for l in lost_markers[:8]:
        v.append("MARKER a line citing this project's own decision record was dropped: %s"
                 % l.strip()[:150])
    for kind, n, first in lost_regions:
        v.append("REGION %s block lost %d line(s), first: %s" % (kind, n, first))
    for kind, first in shredded:
        v.append("REGION %s block was SHREDDED — every line survives but the block is no longer "
                 "contiguous, first: %s" % (kind, first))
    if out_of_order is not None:
        v.append("ORDER protected content was REORDERED — the result no longer reads in the "
                 "original's order; first line out of place: %s" % out_of_order.strip()[:140])
    for l in lost_lines[:12]:
        v.append("LINE %s" % l.strip()[:160])
    if len(lost_lines) > 12:
        v.append("LINE ... and %d more" % (len(lost_lines) - 12))
    for l, want, got in lost_dupes[:6]:
        v.append("LINE (x%d in the original, x%d in the result) %s" % (want, got, l.strip()[:130]))
    for t in lost_toks[:12]:
        v.append("TOKEN %s" % t)
    if len(lost_toks) > 12:
        v.append("TOKEN ... and %d more" % (len(lost_toks) - 12))
    ok = not (lost_lines or lost_dupes or lost_toks or lost_regions or shredded
              or lost_markers or out_of_order is not None)
    return ok, v


# ---------------------------------------------------------------------------------------
# § Report parsing — same convention apply-study-decisions.sh uses
# ---------------------------------------------------------------------------------------
ROW_RE = re.compile(r"^[ \t]+-[ \t]+`([^`]+)`[ \t]+—[ \t](.*)$")
PACK_RE = re.compile(r"^## ([a-z0-9-]+)$")
KIND_RE = re.compile(r"^### ([a-z-]+)$")
DEC_RE = re.compile(r"\*\*([A-Z-]+)\*\*")


def parse_report(path):
    rows, pack, kind, in_orphans = [], None, None, False
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("## Project-only files"):
                in_orphans = True
                continue
            m = PACK_RE.match(line)
            if m:
                pack, in_orphans = m.group(1), False
                continue
            m = KIND_RE.match(line)
            if m:
                kind = m.group(1)
                continue
            if in_orphans or not pack or not kind:
                continue
            m = ROW_RE.match(line)
            if not m:
                continue
            d = DEC_RE.findall(m.group(2))
            if not d:
                continue
            rows.append({"pack": pack, "kind": kind, "base": m.group(1),
                         "decision": d[-1], "rest": m.group(2)})
    return rows


# ---------------------------------------------------------------------------------------
# § Ledger — so a resolved row stops being re-proposed and C2k can close
# ---------------------------------------------------------------------------------------
LEDGER_HDR = """# Refresh decisions ledger (M35)

Durable per-file decisions from /setup-project refresh runs. study-existing.sh
reconciles rows recorded here instead of re-proposing them every run.
KEEP-OURS / RESOLVED entries re-open automatically when the pack source changes
(pack@sha8 mismatch). REJECTED / KEEP are permanent until a human deletes the line.

Append via: apply-study-decisions.sh <target> --reject='pack/kind/file.md:rationale'
(or --keep-ours= / --resolve= / --keep=). Manual edits are fine — keep the line shape.

---
"""


def pack_substantive_sha8(path):
    """Byte-compatible with study-existing.sh's function of the same name.

    That normalization strips `[*_`]`, which is correct for a stability hash and would be
    catastrophic anywhere else in this file (see header rule 2). It is used here for exactly
    one purpose: producing the pack@sha8 stamp study-existing.sh will compare against.
    """
    out, fm, anc = [], False, False
    with open(path, encoding="utf-8", errors="replace") as f:
        for i, ln in enumerate(f):
            ln = ln.rstrip("\n")
            if i == 0 and ln.strip() == "---":
                fm = True
                continue
            if fm:
                if ln.strip() == "---":
                    fm = False
                continue
            if ANCHOR_START.match(ln):
                anc = True
                continue
            if anc:
                if ANCHOR_END.match(ln):
                    anc = False
                continue
            out.append(ln)
    body = "\n".join(out) + "\n"
    body = re.sub(r"[ \t]+$", "", body, flags=re.M)
    body = re.sub(r"[*_`]", "", body)
    body = "\n".join(l for l in body.split("\n") if l.strip()) + "\n"
    # `shasum` hashes the byte stream it is fed; the pipeline above feeds it exactly this.
    return hashlib.sha1(body.encode("utf-8", "replace")).hexdigest()[:8]


def record_ledger(ledger_path, entries, bak_dir=None):
    """entries: [(key, verb, sha8_or_None, why)] — one line per key, last write wins.

    THE LEDGER IS BACKED UP LIKE ANY OTHER FILE THIS RUN REWRITES. It was the one file a run
    mutated with no restore path: the merge backup directory held 149 artifact copies and no
    copy of `_refresh-decisions.md`, the durable record of the OWNER'S OWN decisions. The
    carry-forward of prior rationales below is what protects the content, and it was verified
    to carry 22/22 on a live run — but a carry-forward that ever regresses would be
    unrecoverable, and "verified once" is not a restore path.
    """
    if not entries:
        return 0
    os.makedirs(os.path.dirname(ledger_path), exist_ok=True)
    if not os.path.isfile(ledger_path):
        with open(ledger_path, "w", encoding="utf-8") as f:
            f.write(LEDGER_HDR)
    elif bak_dir:
        try:
            # SAME RELATIVE PATH AS EVERY OTHER BACKED-UP FILE. Putting it at the backup
            # root instead made `cp -R <backup>/. <repo>/` restore it to the wrong place,
            # which is the one operation a backup exists for.
            lb = os.path.join(bak_dir, os.path.relpath(ledger_path, os.path.dirname(os.path.dirname(ledger_path))))
            os.makedirs(os.path.dirname(lb), exist_ok=True)
            shutil.copy2(ledger_path, lb)
        except OSError as e:
            sys.stderr.write("WARN could not back up the decisions ledger (%s) — refusing to "
                             "rewrite it without a restore path\n" % e)
            return 0
    with open(ledger_path, encoding="utf-8") as f:
        existing = f.read().split("\n")
    keys = {k for (k, _v, _s, _w) in entries}
    # The prior line for a key is REPLACED (one line per key, last write wins — the ledger's
    # own contract). But a prior line a HUMAN wrote carries a rationale, and dropping it is
    # knowledge loss of exactly the kind this engine exists to prevent: measured on
    # capsolah-api, 22 lines were rewritten and 8 of them were hand-written KEEP-OURS entries
    # explaining WHY the project's version won. The verb is superseded; the reasoning is not,
    # so it is carried into the new line rather than deleted with it.
    prior = {}
    for l in existing:
        for k in keys:
            if ("`%s`" % k) in l and "→" in l:
                prior[k] = l.split("→", 1)[1].strip()
    kept = [l for l in existing if not any(("`%s`" % k) in l for k in keys)]
    while kept and not kept[-1].strip():
        kept.pop()
    today = datetime.date.today().isoformat()
    for k, verb, sha, why in entries:
        stamp = "(%s, pack@%s)" % (today, sha) if sha else "(%s)" % today
        if k in prior:
            why = "%s [supersedes: %s]" % (why, prior[k])
        kept.append("- `%s` → %s %s — %s" % (k, verb, stamp, why))
    with open(ledger_path, "w", encoding="utf-8") as f:
        f.write("\n".join(kept) + "\n")
    return len(entries)


# ---------------------------------------------------------------------------------------
# § Main
# ---------------------------------------------------------------------------------------
WRITE_VERBS = ("OVERRIDE", "ENHANCE", "ADJUST")
# REPLACE-OR-ENHANCE and ADOPT-PACK-TRIM are handled here TOO, and that is a fix, not a
# widening. apply-study-decisions.sh's blind-replace path has no invariant: it backs the file
# up and copies the pack over it. When the installed file carries a project-specific block the
# pack source lacks, that path now declines and hands the row here instead — but the engine has
# to be willing to take it. A row apply-study-decisions.sh already replaced arrives here as
# NO-OP (target == pack source), so accepting the decision costs nothing on the rows it did
# write.
HANDLED_DECISIONS = ("MERGE", "KEEP-OURS-PLUS-INJECT", "REPLACE-OR-ENHANCE", "ADOPT-PACK-TRIM")


def verify_pairs(tsv_path, target, packs_root, use_git=True, quiet=False):
    """audit-setup.sh C2n, answered by the same mechanism the engine uses to decide.

    Input: one `rel<TAB>backup<TAB>live` per line. Output on stdout: one line per pair that
    LOST something, as `rel<TAB>lines<TAB>tokens<TAB>regions<TAB>first violation`.

    WHY C2n ASKS THIS QUESTION AND NOT ITS OWN. C2n's loss test was a set difference over
    tokens: path-shaped ones with a resolve check, identifier-shaped ones with no check at all.
    Both halves misfire in the direction that deadlocks a run, because a merge that rewords a
    paragraph drops CamelCase and snake_case words by the dozen. Measured on a real target
    after a clean engine run that lost nothing: 43 KNOWLEDGE_LOSS errors, then 13 after adding
    the two-condition token filter — and all 13 named old pack EXAMPLE text (`race_id`,
    `orders.place_order`, `RelationOptions`) or framework files under their deployed spelling
    (`../templates/snippets/instrumentation-parity.md`, `ai/patterns/event-bus.md`).

    AND WHY NOT JUST WIDEN C2n's TOKEN CORPUS TO THIS ONE. Because that would BLIND it. The
    packs were authored partly by mining these repos, so the historical corpus contains
    `DomainMiddleware` and `X-Product-Id` as pack example tokens — the very identifiers whose
    disappearance (9 -> 0) is how the 2026-08-22 destruction of ai/patterns/multi-tenancy.md was
    detected. A token-level test over this corpus would shrug at that file being overwritten.

    A LINE-level test does not have that failure mode: `"`DomainMiddleware` (NOT a generic
    `TenantContext.set()`) resolves tenant in this order"` is a sentence the owner wrote, and no
    pack ever wrote it, so its deletion is caught even though every token in it is "known".
    """
    corpus = build_corpus(packs_root, use_git=use_git, quiet=quiet)
    if not quiet:
        sys.stderr.write("C2n provenance: %s corpus, %d canonical line(s) from %d blob(s) over %d commit(s)\n"
                         % (corpus.source, corpus.lines, corpus.blobs, corpus.commits))
    n = 0
    with open(tsv_path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 3:
                continue
            rel, bak, live = parts
            try:
                with open(bak, encoding="utf-8", errors="replace") as a:
                    before = a.read()
                with open(live, encoding="utf-8", errors="replace") as b:
                    after = b.read()
            except OSError:
                continue
            ok, viol = verify_invariant(before, after, corpus, target)
            if ok:
                continue
            nl = sum(1 for v in viol if v.startswith("LINE "))
            nt = sum(1 for v in viol if v.startswith("TOKEN "))
            nr = sum(1 for v in viol if v.startswith("REGION "))
            first = viol[0].replace("\t", " ")[:220]
            sys.stdout.write("%s\t%d\t%d\t%d\t%s\n" % (rel, nl, nt, nr, first))
            n += 1
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    for a in argv:
        if a.startswith("--verify-pairs="):
            pr = os.path.join(REPO_ROOT, "templates", "packs")
            tgt = None
            for b in argv:
                if b.startswith("--packs-root="):
                    pr = b[len("--packs-root="):]
                elif b.startswith("--target="):
                    tgt = b[len("--target="):]
            if not tgt:
                sys.stderr.write("ERR: --verify-pairs needs --target=<repo>\n")
                return 2
            return verify_pairs(a[len("--verify-pairs="):], tgt, pr,
                                use_git="--no-git" not in argv, quiet="--quiet" in argv)
    if not argv or argv[0].startswith("-"):
        doc = __doc__ or ""
        sys.stderr.write(doc.split("Usage:")[1] if "Usage:" in doc else
                         "usage: merge-decide.py <target-repo> [--apply] [--dry-run] "
                         "[--conservative] [--json=<path>]\n")
        return 2

    target = os.path.abspath(argv[0])
    opts = argv[1:]
    apply_ = "--apply" in opts
    quiet = "--quiet" in opts
    no_ledger = "--no-ledger" in opts
    conservative = "--conservative" in opts
    additive_only = "--additive-only" in opts
    rebuild = "--rebuild-corpus" in opts
    use_git = "--no-git" not in opts
    report = os.path.join(target, ".claude", "_study-existing-report.md")
    jsonout = None
    only = None
    verbs = set(WRITE_VERBS)
    packs_root = os.path.join(REPO_ROOT, "templates", "packs")
    for o in opts:
        if o.startswith("--report="):
            report = o[len("--report="):]
        elif o.startswith("--json="):
            jsonout = o[len("--json="):]
        elif o.startswith("--only="):
            only = o[len("--only="):]
        elif o.startswith("--verbs="):
            verbs = {v.strip().upper() for v in o[len("--verbs="):].split(",") if v.strip()}
        elif o.startswith("--packs-root="):
            packs_root = o[len("--packs-root="):]
        elif o.startswith("--record="):
            pass
        elif o not in ("--apply", "--dry-run", "--quiet", "--no-ledger", "--conservative",
                       "--additive-only", "--no-git", "--rebuild-corpus", "--self-test"):
            sys.stderr.write("unknown arg: %s\n" % o)
            return 2
    if conservative:
        verbs = set()

    if not os.path.isdir(target):
        sys.stderr.write("ERR: target not found: %s\n" % target)
        return 1
    if not os.path.isfile(report):
        sys.stderr.write("ERR: study report not found at %s — run scripts/study-existing.sh first\n" % report)
        return 1

    rows = [r for r in parse_report(report) if r["decision"] in HANDLED_DECISIONS]
    if only:
        rows = [r for r in rows if only in "%s/%s/%s" % (r["pack"], r["kind"], r["base"])]

    corpus = build_corpus(packs_root, use_git=use_git, quiet=quiet, rebuild=rebuild)
    ridx = None
    projrx = None
    bn = os.path.basename(target)
    if bn:
        projrx = re.compile(re.escape(bn.split("-")[0]), re.I)

    out = []
    # ---- M41 pre-pass: cross-pack collisions are decided BEFORE the loop, by CONTENT ------
    # Doing it here rather than first-come inside the loop is what makes the answer
    # order-independent: reordering the study report's pack sections cannot change which pack
    # owns an installed path any more.
    by_target = {}
    for _r in rows:
        _src = os.path.join(packs_root, _r["pack"], _r["kind"], _r["base"])
        _tgt = resolve_target(target, _r["kind"], _r["base"])
        if _tgt and os.path.isfile(_src):
            by_target.setdefault(_tgt, []).append(_r)
    claimed = {}      # target path -> the key that owns it this run
    collision_note = {}
    for _tgt, _rs in by_target.items():
        _key0 = "%s/%s/%s" % (_rs[0]["pack"], _rs[0]["kind"], _rs[0]["base"])
        if len(_rs) < 2:
            claimed[_tgt] = _key0
            continue
        _scored = []
        for _r in _rs:
            _src = os.path.join(packs_root, _r["pack"], _r["kind"], _r["base"])
            _d, _ratio = collision_score(_src, _tgt, _r["kind"], target)
            _scored.append((-_d, -_ratio, _r["pack"],
                            "%s/%s/%s" % (_r["pack"], _r["kind"], _r["base"]), _d, _ratio))
        _scored.sort()
        claimed[_tgt] = _scored[0][3]
        collision_note[_tgt] = {
            "winner": _scored[0][3],
            "why": ("the installed file matches this pack's text best: frontmatter "
                    "description %s, %.0f%% of the installed body accounted for"
                    % ("MATCHES" if _scored[0][4] else "differs", 100.0 * _scored[0][5])),
            "candidates": [{"key": c[3], "description_match": bool(c[4]),
                            "body_match": round(c[5], 4)} for c in _scored],
        }
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    bak_dir = os.path.join(target, ".claude", "backups", "merge-decide-%s" % ts)
    counts = {}
    written = rolled_back = 0
    ledger_entries = []

    # EVERY row is written inside this try. A row that raises — an unwritable target, a
    # read-only mount, a full disk — must not abort the run before the durable record is
    # produced. MEASURED (2026-08-23): `chmod 444` on one target raised an uncaught
    # PermissionError, the wrapper printed its summary and exited 0, and the run left a
    # partially rewritten tree with NO `_merge-decisions.md` and no ledger stamp — a
    # green run over a half-applied merge. The record now runs in every exit path and the
    # run reports 3.
    aborted = None
    try:
        for r in rows:
            key = "%s/%s/%s" % (r["pack"], r["kind"], r["base"])
            src = os.path.join(packs_root, r["pack"], r["kind"], r["base"])
            tgt = resolve_target(target, r["kind"], r["base"])
            # M36 — study-existing.sh's own project-knowledge alarm, which the engine used to
            # parse into rows[]['rest'] and never read. Eight capsolah-api rows carry it. Two
            # of them reached OVERRIDE and both happened to be correct; an engine that reaches
            # the right answer while ignoring the upstream alarm is luck, not design. It is now
            # read, recorded, printed, and it changes the composition (see § M36 below).
            m36 = "project-knowledge protected" in (r.get("rest") or "")
            rec = {"key": key, "pack": r["pack"], "kind": r["kind"], "base": r["base"],
                   "study_decision": r["decision"], "src": src, "target": tgt,
                   "study_alarm_m36": m36}
            if not os.path.isfile(src) or not tgt:
                rec.update(verb="SKIP", bucket="X",
                           why="pack source or installed target could not be resolved")
                out.append(rec)
                counts["SKIP"] = counts.get("SKIP", 0) + 1
                continue

            # M41 — cross-pack command-name collisions. `refactor.md` ships in backend,
            # code-quality, frontend and mobile; `add-feature.md` in three packs. They are
            # DIFFERENT commands that resolve to ONE installed path, so the study report emits
            # two MERGE rows for one file. Letting both write makes the run non-idempotent and
            # non-deterministic in what survives: measured on capsolah-api, backend and
            # code-quality both wrote `.claude/commands/refactor.md`, and run 2 produced a
            # different file from run 1 because each row re-classified against the other's
            # output. First row to claim the path owns it; the loser is reported, never written.
            # Installing the loser as `<name>.<pack>.md` is an ADD, which is
            # apply-study-decisions.sh's variant path (§ resolve_variant_path), not a merge.
            if claimed.get(tgt, key) != key:
                note = collision_note.get(tgt, {})
                cands = note.get("candidates", [])
                mine = next((c for c in cands if c["key"] == key), None)
                rec.update(
                    verb="SKIP", bucket="X", rel=os.path.relpath(tgt, target),
                    collision_winner=note.get("winner"), collision_candidates=cands,
                    why=("CROSS-PACK NAME COLLISION (M41): two packs ship this command name and "
                         "the project has ONE installed file. `%s` owns it — %s. This pack's "
                         "version accounts for %s of the installed body and its frontmatter "
                         "description %s, so adopting it would silently change what the command "
                         "does. Install it alongside as a variant with "
                         "`apply-study-decisions.sh <target> --include=add`, then re-run."
                         % (note.get("winner", "?"), note.get("why", "content match"),
                            ("%.0f%%" % (100.0 * mine["body_match"])) if mine else "?",
                            "differs" if (mine and not mine["description_match"]) else "matches"))
                )
                counts["SKIP"] = counts.get("SKIP", 0) + 1
                out.append(rec)
                continue

            if ridx is None and not conservative:
                ridx = RepoIndex(target)

            (c, pack_norm, tgt_raw, tgt_body, anchors, S, T,
             s_spans, t_spans, s_keys, proj_keys) = classify(src, tgt, r["kind"], corpus, target, ridx, projrx)
            rec.update(c)
            rec["rel"] = os.path.relpath(tgt, target)

            verb = rec["verb"]
            if verb == "NO-OP":
                rec["why"] = "identical to the pack source once the project-specific anchor is set aside"
            elif verb == "OVERRIDE":
                # `gain_lines` IS A GROSS COUNT — lines ADDED — and it used to be printed in
                # the grammar of a net trade ("the file gains N line(s) in exchange"), directly
                # after the sentence saying what was deleted. MEASURED against `git diff
                # --numstat` on both live repos: wrong in 113 of 119 capsolah rows and 29 of 29
                # tenant-portal rows, and in 22 of those the file actually SHRANK while the row
                # advertised a gain — `.claude/agents/websocket-engineer.md` claimed "+79" on a
                # net of −40 (+83/−123); `.claude/agents/ui-architect.md` claimed "+119" on a net
                # of −33. The gross number is not wrong, the WORD "gains" is. It is now labelled
                # as gross here, and the true net is appended from the composed result below
                # (see rec["net_lines"]), which is the number `git diff` will show.
                rec["why"] = ("all %d target line(s) this replaces are verbatim historical pack "
                              "text (provenance corpus: %d lines from %d blobs over %d commits); "
                              "%d of them are NOT in the current pack, so the pack will not put "
                              "them back — this write ADDS %d line(s) of pack text (gross, not net); "
                              "%d anchor block(s) carried forward verbatim"
                              % (rec["loss_lines"], corpus.lines, corpus.blobs, corpus.commits,
                                 rec["loss_absent_from_current_packs"], rec["gain_lines"],
                                 rec["anchor_blocks"]))
            elif verb == "ENHANCE":
                # THE STRONGEST FORM OF THE PROOF, and it is stronger than OVERRIDE's. loss == 0
                # means every line of the target already has a counterpart in the pack -- the
                # target is a strict SUBSEQUENCE of the pack source. Adopting the pack body
                # therefore deletes literally nothing, whatever the corpus does or does not know.
                #
                # WHY THIS IS NOT "append the pack-only `## ` sections". That was the shape the
                # additive merge already shipped in, and it is incomplete in two measured ways:
                # it cannot see a pack addition below H2 (`### Sibling agents in performance pack`
                # in performance-optimizer.md) and it cannot see one made INSIDE a section both
                # files have (the `Closure verbs` paragraph in seo-audit/SKILL.md). Both were left
                # behind by the append, so the row stayed dirty and the NEXT run re-classified it
                # as OVERRIDE and rewrote the file -- 4 rows across the two repos, converging only
                # on run 3. Adopting the whole body closes the row in one pass and is idempotent.
                # `--additive-only` (and `--include=merge-additive`) keeps the append-only shape
                # for callers who have contracted for it.
                rec["why"] = ("the target is a strict subsequence of the pack — adopting the pack body "
                              "deletes ZERO target lines and adds %d (gross)" % rec["gain_lines"])
            elif verb == "ADJUST":
                rec["why"] = ("%d unknown-origin line(s) all live in section(s) the pack does not have "
                              "(%s) — those are kept byte-for-byte, the shared sections take the pack version"
                              % (rec["loss_unknown"], ", ".join(rec["target_only_sections"][:4]) or "project-specific"))
            else:
                rec["why"] = ("%d unknown-origin line(s) sit INSIDE a section the pack also changed — "
                              "a real merge, not a mechanical one" % rec["unknown_shared"])

            if conservative and verb in WRITE_VERBS:
                rec["verb"], rec["downgraded_from"] = "DEFER", verb
                rec["why"] = "--conservative: automatic merges disabled, listed for human review"
                verb = "DEFER"

            if verb in WRITE_VERBS and verb in verbs:
                if verb == "ADJUST":
                    result = compose_adjust(pack_norm, tgt_body, anchors, s_keys, proj_keys, corpus)
                    rec["added"] = "pack body for %d shared section(s)" % len(s_keys)
                elif verb == "ENHANCE" and additive_only:
                    result, added = compose_enhance(pack_norm, tgt_raw)
                    rec["added"] = "%d pack-only section(s): %s" % (len(added), ", ".join(added[:6]))
                elif m36 and verb == "OVERRIDE" and any(
                        k not in s_keys for (k, _h, _a, _b) in t_spans if _h is not None):
                    # § M36 — the alarm is ANSWERED, not ignored. study-existing.sh flagged this
                    # file as carrying project knowledge no pack can regenerate. The engine's own
                    # three legs are strictly stronger than that flag, and they cleared the row —
                    # but when the target has a section the pack does not own, ADJUST keeps that
                    # section byte-for-byte and is available at no cost. Taking the weaker
                    # composition when the stronger one is free is the definition of ignoring a
                    # warning. OVERRIDE is still used when the target has nothing of its own.
                    result = compose_adjust(pack_norm, tgt_body, anchors, s_keys, proj_keys, corpus)
                    rec["verb"] = verb = "ADJUST"
                    rec["m36_honoured"] = True
                    rec["why"] = ("study-existing.sh flagged this file as project-knowledge "
                                  "protected (M36). Every deleted line is provably framework "
                                  "text, so OVERRIDE was licensed — but the target has "
                                  "section(s) the pack does not own, so ADJUST is used instead "
                                  "and keeps them byte-for-byte.")
                    rec["added"] = "pack body for %d shared section(s)" % len(s_keys)
                else:
                    # ENHANCE and OVERRIDE share one composer and differ only in the strength of
                    # the proof that licenses it. See § the C-is-a-subsequence note.
                    # A `## Project-specific ...` heading is only the OWNER's when the pack does
                    # not ship a section by that name. Two ai-patterns packs ship a literal
                    # `## Project-specific anchors` section, and treating the pack's own heading as
                    # owner content made the composer append a second copy of it on every run.
                    heading_blocks = [b for (kd, k, b) in project_regions(tgt_raw)
                                      if kd == "heading" and k not in s_keys]
                    result = compose_override(pack_norm, anchors, heading_blocks)
                    rec["added"] = "pack body (%d line(s) the target lacked)" % rec["gain_lines"]
                result = rewrite_deployed(result, r["kind"], target)
                if not result.endswith("\n"):
                    result += "\n"

                if result == tgt_raw:
                    # Idempotency: a second run recomposes the same bytes and must not churn the
                    # ledger, the backup dir or the file's mtime.
                    rec.update(verb="NO-OP", bucket="A",
                               why="already converged — recomposing produced byte-identical output")
                    counts["NO-OP"] = counts.get("NO-OP", 0) + 1
                    out.append(rec)
                    continue

                rec["new_dangling_refs"] = new_dangling_refs(tgt_raw, result, target, ridx)
                ok, viol = verify_invariant(tgt_raw, result, corpus, target)
                rec["invariant_checked"] = True
                _pl, _pt, _pr = fingerprint(tgt_raw, corpus, target)
                rec["preserved_lines"], rec["preserved_tokens"], rec["preserved_regions"] = len(_pl), len(_pt), len(_pr)

                # THE FALLBACK LADDER. A refused OVERRIDE does not have to become a human's
                # problem. OVERRIDE takes the pack body whole; ADJUST takes the pack body for
                # the sections the pack owns and keeps the target's own sections byte-for-byte.
                # When the only thing OVERRIDE would have dropped lives in a section the pack
                # does not own, ADJUST keeps it and the SAME invariant then passes — a row that
                # would have been deferred closes automatically, with a stronger composition
                # rather than a weaker check. MEASURED: this is what saves
                # `.claude/commands/design-system.md` after the TOKEN leg was tightened to the
                # current packs; without it the tightening would have cost a row of automation.
                # The invariant is never relaxed to make this work — the fallback result is
                # verified from scratch and refused on the same terms.
                if not ok and verb in ("OVERRIDE", "ENHANCE"):
                    alt = rewrite_deployed(
                        compose_adjust(pack_norm, tgt_body, anchors, s_keys, proj_keys, corpus),
                        r["kind"], target)
                    if not alt.endswith("\n"):
                        alt += "\n"
                    ok2a, viol2a = verify_invariant(tgt_raw, alt, corpus, target)
                    if ok2a:
                        rec["fallback_from"] = verb
                        rec["fallback_reason"] = viol[0] if viol else ""
                        rec["why"] = ("%s was REFUSED by the invariant (%s) — recomposed as "
                                      "ADJUST, which keeps the target's own section(s) "
                                      "byte-for-byte, and that result passes"
                                      % (verb, (viol[0] if viol else "?")[:120]))
                        rec["verb"] = verb = "ADJUST"
                        rec["added"] = "pack body for %d shared section(s)" % len(s_keys)
                        result, ok, viol = alt, True, []
                        if result == tgt_raw:
                            rec.update(verb="NO-OP", bucket="A",
                                       why="already converged — recomposing produced byte-identical output")
                            counts["NO-OP"] = counts.get("NO-OP", 0) + 1
                            out.append(rec)
                            continue
                if not ok:
                    # The engine never writes a file that fails its own check. This is the last
                    # line of defence and it is deliberately blunt.
                    rec.update(verb="DEFER", downgraded_from=verb, invariant_violations=viol,
                               why="INVARIANT FAILED before write (%d violation(s)) — refused and deferred" % len(viol))
                    counts["DEFER"] = counts.get("DEFER", 0) + 1
                    rolled_back += 1
                    out.append(rec)
                    continue

                if apply_:
                    # THE WRITE IS A REFUSABLE OPERATION, not an assumption. Three things can
                    # go wrong before a byte lands and all three used to raise: the target is
                    # read-only (chmod 444, root-owned, read-only mount), the backup cannot be
                    # taken, or the write itself fails part-way. The first two are checked
                    # before anything is touched; the third cannot happen because the bytes go
                    # to a sibling temp file and arrive by os.replace, which is atomic — a
                    # failed write leaves the ORIGINAL intact rather than a truncated file.
                    rel = os.path.relpath(tgt, target)
                    bpath = os.path.join(bak_dir, rel)
                    tmp = tgt + ".merge-decide.tmp"
                    try:
                        if not os.access(tgt, os.W_OK):
                            raise PermissionError("target file is not writable")
                        if not os.access(os.path.dirname(tgt) or ".", os.W_OK):
                            raise PermissionError("target directory is not writable")
                        os.makedirs(os.path.dirname(bpath), exist_ok=True)
                        shutil.copy2(tgt, bpath)
                        with open(tmp, "w", encoding="utf-8") as f:
                            f.write(result)
                        shutil.copystat(tgt, tmp)
                        os.replace(tmp, tgt)
                    except OSError as e:
                        try:
                            if os.path.exists(tmp):
                                os.unlink(tmp)
                        except OSError:
                            pass
                        # The original is untouched (nothing was truncated), so this is a
                        # refusal, not a rollback — but it is counted with the rollbacks so the
                        # run exits 3 and no caller can read it as success.
                        rec.update(verb="DEFER", downgraded_from=verb, write_error=str(e),
                                   why="WRITE REFUSED (%s: %s) — the file on disk is unchanged"
                                       % (type(e).__name__, e))
                        counts["DEFER"] = counts.get("DEFER", 0) + 1
                        rolled_back += 1
                        out.append(rec)
                        continue
                    # Re-verify against what is ON DISK, not against the string we intended.
                    with open(tgt, encoding="utf-8", errors="replace") as f:
                        ondisk = f.read()
                    ok2, viol2 = verify_invariant(tgt_raw, ondisk, corpus, target)
                    if not ok2:
                        shutil.copy2(bpath, tgt)
                        rec.update(verb="DEFER", downgraded_from=verb, invariant_violations=viol2,
                                   why="INVARIANT FAILED after write — file ROLLED BACK from %s" % os.path.relpath(bpath, target))
                        counts["DEFER"] = counts.get("DEFER", 0) + 1
                        rolled_back += 1
                        out.append(rec)
                        continue
                    rec["backup"] = os.path.relpath(bpath, target)
                    written += 1
                # THE NET, measured on the bytes that actually landed. This is the number
                # `git diff --numstat` will print for the file, so the record and the diff agree.
                _before_n = tgt_raw.count("\n")
                _after_n = result.count("\n")
                rec["net_lines"] = _after_n - _before_n
                rec["why"] = "%s; NET file length %+d line(s)" % (rec["why"], rec["net_lines"])
                rec["applied"] = apply_
                if apply_ and verb in ("ENHANCE", "ADJUST"):
                    # OVERRIDE needs no ledger row: the file becomes byte-equal to the pack, so the
                    # next study run calls it IDENTICAL-NO-OP by itself. ENHANCE and ADJUST leave a
                    # file that still differs by design, so without a RESOLVED stamp the row would
                    # be re-proposed forever and C2k could never reach zero.
                    ledger_entries.append((key, "RESOLVED", pack_substantive_sha8(src),
                                           "auto-%s by merge-decide.py (%s)" % (verb.lower(), rec["why"])))
            elif verb in WRITE_VERBS:
                rec["verb"], rec["skipped_by_verbs_filter"] = "SKIP", True

            counts[rec["verb"]] = counts.get(rec["verb"], 0) + 1
            out.append(rec)

    except Exception as _e:
        import traceback
        aborted = "%s: %s" % (type(_e).__name__, _e)
        sys.stderr.write("ERR merge-decide aborted mid-run: %s\n" % aborted)
        traceback.print_exc(file=sys.stderr)
    # ---- the durable record, on EVERY exit path ------------------------------------------
    # Each of these is independently guarded. A failure to write the record must not swallow
    # the reason the run is already failing, and must not stop the other two from being
    # produced; the run is reported red either way.
    ledgered = 0
    if apply_ and not no_ledger and ledger_entries:
        try:
            ledgered = record_ledger(os.path.join(target, ".claude", "_refresh-decisions.md"),
                                     ledger_entries, bak_dir=bak_dir)
        except Exception as _e:
            aborted = aborted or ("ledger write failed: %s" % _e)
            sys.stderr.write("ERR could not write the decisions ledger: %s\n" % _e)

    if apply_:
        try:
            write_record(target, out, corpus, bak_dir, ts, aborted=aborted)
        except Exception as _e:
            aborted = aborted or ("record write failed: %s" % _e)
            sys.stderr.write("ERR could not write _merge-decisions.md: %s\n" % _e)

    if jsonout:
        try:
            with open(jsonout, "w", encoding="utf-8") as f:
                json.dump(out, f, indent=1)
        except Exception as _e:
            sys.stderr.write("ERR could not write %s: %s\n" % (jsonout, _e))

    if not quiet:
        print_table(out, counts, corpus, apply_, conservative, written, rolled_back, ledgered,
                    bak_dir, target, aborted=aborted)
    if aborted:
        return 3
    return 3 if rolled_back and apply_ else 0


def print_table(out, counts, corpus, apply_, conservative, written, rolled_back, ledgered,
                bak_dir, target, aborted=None):
    print("=== merge-decide ===")
    if aborted:
        print("!! RUN ABORTED: %s" % aborted)
        print("!! The rows below are the ones that completed. The run reports exit 3.")
    print("Target:    %s" % target)
    print("Mode:      %s%s" % ("APPLY" if apply_ else "dry-run",
                               "  (--conservative: no automatic merges)" if conservative else ""))
    print("Provenance: %s — %d canonical line(s) from %d historical blob(s) over %d commit(s)%s"
          % (corpus.source, corpus.lines, corpus.blobs, corpus.commits,
             "  [DEGRADED: no git history reachable; every decision is more conservative]" if corpus.degraded else ""))
    print("Rows:      %d" % len(out))
    print("")
    order = ["NO-OP", "OVERRIDE", "ENHANCE", "ADJUST", "DEFER", "SKIP"]
    for v in order:
        if counts.get(v):
            print("  %-9s %4d" % (v, counts[v]))
    print("")
    for rec in out:
        v = rec["verb"]
        if v == "NO-OP":
            continue
        # A SKIP USED TO BE INVISIBLE HERE, and that is how a command silently changed packs.
        # `.claude/commands/refactor.md` was contested by backend and code-quality; the loser
        # was SKIPped and the only trace on stdout was the count line `SKIP 1`. It was absent
        # from `_merge-decisions.md` too — 165 rows recorded out of 166. The one row that
        # needed a human's attention was the one row nobody could see.
        mark = "  " if not apply_ else ("~ " if v in ("DEFER", "SKIP") else "* ")
        print("%s%-9s %s" % (mark, v, rec.get("rel", rec["key"])))
        print("           why: %s" % rec.get("why", ""))
        if rec.get("preserved_lines") is not None and v != "DEFER":
            print("           preserved: %d unknown-origin line(s), %d project token(s)%s"
                  % (rec.get("preserved_lines", 0), rec.get("preserved_tokens", 0),
                     ("; anchor blocks: %d" % rec["anchor_blocks"]) if rec.get("anchor_blocks") else ""))
        if rec.get("added"):
            print("           added: %s" % rec["added"])
        if rec.get("study_alarm_m36"):
            print("           M36: study-existing.sh flagged this file as project-knowledge "
                  "protected%s" % ("; honoured by composing ADJUST" if rec.get("m36_honoured")
                                   else "; every protected line, token and region checked and preserved"))
        for f in rec.get("frontmatter_changes", []):
            print("           frontmatter: %s  %s -> %s" % (f["field"], f["from"], f["to"]))
        if rec.get("pack_only_sections"):
            print("           reintroduced %d pack section(s) the file did not have: %s"
                  % (len(rec["pack_only_sections"]), ", ".join(rec["pack_only_sections"][:5])))
        if rec.get("loss_absent_from_current_packs"):
            print("           NOTE %d deleted line(s) are historical pack text the CURRENT pack "
                  "does not carry back" % rec["loss_absent_from_current_packs"])
        if rec.get("new_dangling_refs"):
            print("           new unresolved in-repo reference(s): %s"
                  % ", ".join(rec["new_dangling_refs"][:4]))
        if rec.get("detector", {}).get("fired"):
            print("           fingerprint detector: %s" % ", ".join(rec["detector"]["fired"]))
        if rec.get("backup"):
            print("           backup: %s" % rec["backup"])
        for x in rec.get("invariant_violations", [])[:4]:
            print("           !! %s" % x)
    print("")
    print("=== summary ===")
    n_auto = sum(counts.get(v, 0) for v in ("OVERRIDE", "ENHANCE", "ADJUST"))
    n_all = sum(counts.get(v, 0) for v in ("NO-OP", "OVERRIDE", "ENHANCE", "ADJUST", "DEFER"))
    print("Closed automatically:      %d" % (n_auto + counts.get("NO-OP", 0)))
    print("Left for a human (DEFER):  %d%s" % (counts.get("DEFER", 0),
          "  (%.1f%% of %d)" % (100.0 * counts.get("DEFER", 0) / n_all, n_all) if n_all else ""))
    if apply_:
        print("Files written:             %d" % written)
        # Refusals and rollbacks are counted together because they are the same event caught
        # at two different moments: the composed bytes would have lost project knowledge.
        print("Refused or rolled back:    %d" % rolled_back)
        print("Ledger RESOLVED rows:      %d" % ledgered)
        if written:
            print("Backups:                   %s/" % os.path.relpath(bak_dir, target))
    else:
        print("Dry run — pass --apply to execute.")
    if aborted:
        print("")
        print("RUN ABORTED — %s" % aborted)
        print("This run is INCOMPLETE. `.claude/_merge-decisions.md` records what did complete;")
        print("every file it names as written was verified after its write. Exit code 3.")


def write_record(target, out, corpus, bak_dir, ts, aborted=None):
    """The per-file record the owner asked for: decision, why, preserved, added, backup."""
    p = os.path.join(target, ".claude", "_merge-decisions.md")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write("# Automatic merge decisions — %s\n\n"
                % datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
        f.write("Generated by `scripts/merge-decide.py`. Every row was decided mechanically and "
                "every write was verified against the file it produced.\n\n")
        f.write("Provenance corpus: **%s** — %d canonical lines from %d historical `*.md` blobs "
                "over %d commits.\n\n" % (corpus.source, corpus.lines, corpus.blobs, corpus.commits))
        if corpus.degraded:
            f.write("> **DEGRADED RUN.** No git history was reachable, so provenance was proved "
                    "against the current pack text alone. Fewer lines are provable, so more rows "
                    "were deferred than a full run would defer. Nothing was lost by it.\n\n")
        if aborted:
            f.write("> **THIS RUN ABORTED — %s.** The table below is what completed before the\n"
                    "> abort, not the whole report. Every file it names as written was verified\n"
                    "> after its write and backed up first. Re-run once the cause is fixed.\n\n"
                    % aborted.replace("|", "\\|"))
        f.write("| verb | file | why | preserved | backup / where to look |\n|---|---|---|---|---|\n")
        for r in out:
            # A DEFER ROW'S TWO MOST USEFUL COLUMNS WERE BOTH EM-DASHES. Every OVERRIDE row
            # carries a real backup path; a DEFER row carried `—` for both preserved and
            # backup, because nothing was written and nothing was backed up — which is true and
            # useless. The reader of a DEFER row needs to know where to look, and the answer is
            # 170 lines further down the file under a different heading. Point at it.
            rel_ = r.get("rel", r["key"])
            if r.get("backup"):
                where = "`%s`" % r["backup"]
            elif r["verb"] == "DEFER":
                where = ("file UNCHANGED on disk — see § Deferred rows below for the "
                         "verbatim at-risk line(s)")
            else:
                where = "—"
            f.write("| %s | `%s` | %s | %s | %s |\n" % (
                r["verb"], rel_,
                r.get("why", "").replace("|", "\\|"),
                ("%d line(s), %d token(s)" % (r.get("preserved_lines", 0), r.get("preserved_tokens", 0)))
                if r.get("invariant_checked") else
                ("nothing written — the file is byte-identical to before this run"
                 if r["verb"] == "DEFER" else "—"),
                where))
        fm = [r for r in out if r.get("frontmatter_changes") and r["verb"] in WRITE_VERBS]
        if fm:
            f.write("\n## Frontmatter and policy fields that changed\n\n")
            f.write("These are not prose. `model:` is a cost decision and `applies-to:` / "
                    "`severity:` decide when a rule binds.\n\n")
            f.write("| file | field | from | to |\n|---|---|---|---|\n")
            for r in fm:
                for c in r["frontmatter_changes"]:
                    f.write("| `%s` | `%s` | %s | %s |\n"
                            % (r.get("rel", r["key"]), c["field"],
                               ("`%s`" % c["from"].replace("|", "\\|")) if c["from"] else "_(absent)_",
                               ("`%s`" % c["to"].replace("|", "\\|")) if c["to"] else "_(absent)_"))

        tr = [r for r in out if r["verb"] in WRITE_VERBS and r.get("loss_absent_from_current_packs")]
        if tr:
            n = sum(r["loss_absent_from_current_packs"] for r in tr)
            g = sum(r.get("gain_lines", 0) for r in tr)
            f.write("\n## The trade this run made\n\n")
            f.write("%d line(s) across %d file(s) were deleted as verbatim HISTORICAL pack text "
                    "that the CURRENT pack does not carry back, in exchange for %d line(s) of "
                    "current pack depth. Every one was proved to be framework-written; none was "
                    "project knowledge. Listed so \"the pack wrote it\" is never mistaken for "
                    "\"the pack will restore it\".\n\n" % (n, len(tr), g))
            f.write("| file | deleted & not in the current pack | gained |\n|---|---|---|\n")
            for r in sorted(tr, key=lambda x: -x["loss_absent_from_current_packs"])[:25]:
                f.write("| `%s` | %d | %d |\n" % (r.get("rel", r["key"]),
                                                  r["loss_absent_from_current_packs"],
                                                  r.get("gain_lines", 0)))

        nd = [r for r in out if r.get("new_dangling_refs")]
        if nd:
            f.write("\n## References the incoming pack text adds that do not resolve here\n\n")
            f.write("Pack example output and forward references to files a sibling command "
                    "creates on first use both look like this. Counted, not blocked.\n\n")
            for r in nd:
                f.write("- `%s` — %s\n" % (r.get("rel", r["key"]),
                                            ", ".join("`%s`" % x for x in r["new_dangling_refs"][:8])))

        sk = [r for r in out if r["verb"] == "SKIP"]
        if sk:
            f.write("\n## Skipped rows (nothing was written for these)\n\n")
            for r in sk:
                f.write("- `%s` (from `%s`) — %s\n"
                        % (r.get("rel", r["key"]), r["key"], r.get("why", "")))
                for c in r.get("collision_candidates", []):
                    f.write("  - candidate `%s`: description %s, %.0f%% of the installed body\n"
                            % (c["key"], "matches" if c["description_match"] else "differs",
                               100.0 * c["body_match"]))
        f.write("\n## Deferred rows (a human must merge these)\n\n")
        d = [r for r in out if r["verb"] == "DEFER"]
        if not d:
            f.write("None.\n")
        for r in d:
            f.write("- `%s` — %s\n" % (r.get("rel", r["key"]), r.get("why", "")))
            if r.get("study_alarm_m36"):
                f.write("  - study-existing.sh (M36) flagged this file as project-knowledge protected\n")
            if r.get("detector", {}).get("fired"):
                f.write("  - fingerprint detector (reported, not a gate): %s\n"
                        % ", ".join(r["detector"]["fired"]))
            for x in r.get("unknown_sample", [])[:5]:
                f.write("  - at risk: `%s`\n" % x.strip()[:200])
    return p


# ---------------------------------------------------------------------------------------
# § Self-test — fixtures for every rule, run by scripts/test-merge-decide.sh
# ---------------------------------------------------------------------------------------
def self_test():
    import tempfile
    fails = []

    def chk(name, cond, detail=""):
        print("  %s %s%s" % ("ok  " if cond else "FAIL", name, ("  — " + detail) if detail and not cond else ""))
        if not cond:
            fails.append(name)

    corpus = Corpus({lhash(l) for l in ["# Title", "Pack prose line.", "## Shared", "shared body",
                                        "## PackOnly", "pack only body", "old pack line"]},
                    set(), set(), "packs-only")

    chk("canon collapses the four snippet spellings",
        canon("Canonical contract: [`templates/snippets/x.md`](../../../snippets/x.md).")
        == canon("Canonical contract: `~/.claude/templates/snippets/x.md`."))
    chk("canon does NOT strip emphasis or underscores",
        "E2E_EMAIL" in canon("logs in with `E2E_EMAIL` / `E2E_PASSWORD`"))
    chk("canon does NOT eat dotted filenames", ".env.tenant" in canon("diff `.env.tenant` vs example"))

    body, anchors = split_anchors("a\n<!-- project-specific:start -->\nP\n<!-- project-specific:end -->\n\nb\n")
    chk("split_anchors extracts the block and swallows the trailing blank",
        anchors and "P" in anchors[0] and body.split("\n")[:2] == ["a", "b"], repr(body))

    lines = ["---", "name: x", "---", "# H1", "intro", "## First", "body"]
    chk("insertion index matches apply-anchors.sh (before first H2)", _insertion_index(lines) == 5,
        str(_insertion_index(lines)))

    with tempfile.TemporaryDirectory() as td:
        tgt_root = os.path.join(td, "proj")
        os.makedirs(os.path.join(tgt_root, ".claude", "commands"))
        pack = "# Title\nPack prose line.\n\n## Shared\nshared body\n\n## PackOnly\npack only body\n"

        # OVERRIDE keeps the anchor block even though the classifier never inspects it.
        t = "# Title\nold pack line\n<!-- project-specific:start -->\n## Project-specific\n> DomainMiddleware resolves tenant\n<!-- project-specific:end -->\n\n## Shared\nshared body\n"
        b, anc = split_anchors(t)
        res = compose_override(pack, anc)
        ok, viol = verify_invariant(t, res, corpus, tgt_root)
        chk("OVERRIDE carries the anchor block forward", "DomainMiddleware resolves tenant" in res)
        chk("OVERRIDE passes its own invariant", ok, "; ".join(viol))

        # ADJUST keeps a target-only section byte-for-byte.
        t2 = "# Title\nPack prose line.\n\n## Shared\nold pack line\n\n## Ours\nX-Product-Id header chain\n"
        b2, anc2 = split_anchors(t2)
        res2 = compose_adjust(pack, b2, anc2, {"shared", "packonly", "«preamble»"}, set())
        ok2, viol2 = verify_invariant(t2, res2, corpus, tgt_root)
        chk("ADJUST keeps the target-only section verbatim", "X-Product-Id header chain" in res2)
        chk("ADJUST takes the pack's version of the shared section", "shared body" in res2)
        chk("ADJUST passes its own invariant", ok2, "; ".join(viol2))
        chk("ADJUST marks the seam", "setup-project:kept-project-section" in res2)

        # Seam markers must not be read as owner content on the next run.
        chk("engine markers are not evidence",
            not is_evidence("<!-- setup-project:kept-project-section name=ours -->"))

        # ENHANCE appends and deletes nothing.
        t3 = "# Title\nPack prose line.\n\n## Shared\nshared body\n"
        res3, added = compose_enhance(pack, t3)
        chk("ENHANCE appends the pack-only section", "pack only body" in res3 and added == ["PackOnly"])
        chk("ENHANCE deletes nothing", all(l in res3 for l in t3.split("\n") if l.strip()))

        # The invariant catches a real loss.
        ok4, viol4 = verify_invariant("keep me: TenantContext.set()\n", "generic pack text\n", corpus, tgt_root)
        chk("invariant FAILS on a real loss", not ok4 and any("TenantContext" in v for v in viol4))

        # Negative knowledge — the class no identifier-presence rule can see.
        neg = "Do not recommend BaseModal, FormField or useCrud; they do not exist in v1.\n"
        ok5, _ = verify_invariant(neg, "generic pack text\n", corpus, tgt_root)
        chk("invariant catches NEGATIVE knowledge about absent identifiers", not ok5)

        # ── the evidence predicate ──────────────────────────────────────────────────────
        chk("a markdown table row of pure numbers IS evidence", is_evidence("| 41 | 220 | 1800 |"))
        chk("a table SEPARATOR row is not", not is_evidence("|---|---|---|"))
        chk("a bare list marker is not", not is_evidence("1."))
        chk("a horizontal rule is not", not is_evidence("---"))
        chk("a fence with a project info string IS evidence",
            is_evidence('```ts title="src/lib/http.ts"'))
        chk("a bare language fence is not", not is_evidence("```ts"))

        # ── the invariant's five checks ─────────────────────────────────────────────────
        okm, vm = verify_invariant("x\npack prose line\nx\n", "x\npack prose line\n", corpus, tgt_root)
        chk("MULTISET: losing one instance of a duplicated protected line is caught",
            not okm and any("x2 in the original" in v for v in vm), "; ".join(vm))

        o_ord = "# Title\n\n## A\n\nDomainMiddleware resolves tenant.\n\n## B\n\nTenantContext.set() is forbidden.\n"
        r_ord = "# Title\n\n## B\n\nTenantContext.set() is forbidden.\n\n## A\n\nDomainMiddleware resolves tenant.\n"
        oko, vo = verify_invariant(o_ord, r_ord, corpus, tgt_root)
        chk("ORDER: protected content that swaps places is caught",
            not oko and any(v.startswith("ORDER") for v in vo), "; ".join(vo))

        o_sh = ("# Title\n\n## Project-specific (V1)\n\n- DomainMiddleware resolves tenant.\n"
                "- Repos extend DataAccess<E, T, D>.\n\n## Generic\n\npack prose line\n")
        r_sh = ("# Title\n\n## Project-specific (V1)\n\n- DomainMiddleware resolves tenant.\n"
                "\n## Generic\n\npack prose line\n\n## Other\n\n- Repos extend DataAccess<E, T, D>.\n")
        oks, vs_ = verify_invariant(o_sh, r_sh, corpus, tgt_root)
        chk("REGION: a block whose lines all survive but scattered is caught",
            not oks and any("SHREDDED" in v for v in vs_), "; ".join(vs_))

        adr = "Tenant order is fixed by ADR-007; do not short-circuit it."
        c_adr = Corpus({lhash(l) for l in ["# T", "pack prose line", adr]}, set(), set(), "packs-only")
        oka, va = verify_invariant("# T\n%s\n" % adr, "# T\npack prose line\n", c_adr, tgt_root)
        chk("MARKER: an ADR citation cannot be deleted even when the corpus proves it",
            not oka and any(v.startswith("MARKER") for v in va), "; ".join(va))
        okc, _ = verify_invariant("# T\n%s\n" % adr, "# T\n%s\npack prose line\n" % adr, c_adr, tgt_root)
        chk("MARKER: control — keeping the ADR citation passes", okc)

        # ── compose_adjust keeps target order and de-duplicates the pack's own title ─────
        pack_t = "---\nname: p\n---\n\n# Doc Title\n\nintro line\n\n## Shared\n\nshared body\n"
        tgt_t = ("## Ours first — read before the generic body\n\nX-Product-Id header chain\n\n"
                 "---\n\n# Doc Title\n\nintro line\n\n## Shared\n\nold pack line\n")
        res_t = compose_adjust(pack_t, tgt_t, [], {"shared", "«preamble»"}, set())
        rl = res_t.split("\n")
        i_ours = next(i for i, l in enumerate(rl) if l.startswith("## Ours first"))
        i_shared = next(i for i, l in enumerate(rl) if l.startswith("## Shared"))
        chk("ADJUST keeps the owner's section ABOVE the generic body", i_ours < i_shared,
            "ours@%d shared@%d" % (i_ours, i_shared))
        chk("ADJUST emits the document title exactly once",
            sum(1 for l in rl if l.strip() == "# Doc Title") == 1,
            "found %d" % sum(1 for l in rl if l.strip() == "# Doc Title"))
        chk("ADJUST still takes the pack's version of the shared section", "shared body" in res_t)

        # Repeated section keys must map by OCCURRENCE, not collapse by name.
        pack_r = "# T\n\n## Context\n\nfirst context\n\n## Context\n\nsecond context\n"
        tgt_r = "# T\n\n## Context\n\nold one\n\n## Context\n\nold two\n"
        res_r = compose_adjust(pack_r, tgt_r, [], {"context", "«preamble»"}, set())
        chk("ADJUST maps repeated headings positionally, not by name",
            "first context" in res_r and "second context" in res_r, res_r)

    print("")
    if fails:
        print("SELF-TEST FAILED: %s" % ", ".join(fails))
        return 1
    print("SELF-TEST PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
