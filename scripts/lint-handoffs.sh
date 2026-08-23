#!/usr/bin/env bash
# lint-handoffs.sh — the EDGE gate. Fail when one repo file states a property OF another
# named repo file that opening that file disproves.
#
# WHY THIS EXISTS. Eight review passes produced one recurring defect class, and none of the
# other 18 gates can see any instance of it: **a reference that resolves as TEXT but not as
# CONTRACT**. Every path in every instance resolved; what was wrong was the claim made about
# what is inside the target. The shape, stated once:
#
#     File A states a property OF a named artifact B.
#     The property is decidable by opening B.
#     Nothing opens B.
#
# The other gates COUNT (verify-readme-stats, verify-pack-matrix, check-rule-budget), check
# PRESENCE (validate-pack-consistency check 3 stats a `fallback:` path and never opens it), or
# compare two catalogs of NAMES (lint-tool-parity, lint-overlay-catalog, verify-doc-sync).
# audit-setup.sh is the only one that resolves a section BY NAME, and only inside a generated
# runtime artifact, never inside this repo's own prose. The gates verify the catalog; nothing
# verified the edges. This does.
#
# THE FOUR CHECKS — each was measured over the whole tree before it was kept, and the two
# candidates that did not survive measurement are recorded under "NOT IMPLEMENTED" below so the
# next person does not re-derive them.
#
#   1. check_skill_input_contract  (FAIL, no baseline)
#      A fenced key-block dispatched to a named skill may only use keys that skill's
#      `## Inputs` declares. Measured at HEAD 5ffd22b: 114 uniquely-named skills, 11 with a
#      parseable `## Inputs`, 1 real caller handoff site, 0 findings. BE HONEST ABOUT THE REACH:
#      this is a regression lock on exactly ONE edge — templates/phases/phase-2-profile.md:176
#      handing repo_shape / shape_signal / members / name / root / manifest to
#      extract-codebase-overview. Reconstructing the defect state (HEAD's caller block against
#      that skill's `## Inputs` as it stood at 2e77692, which declared only project_root /
#      output_path / parallelism) turns it RED with 6 findings, one per key. Note the honest
#      caveat: at 2e77692 ITSELF the caller block did not exist yet, so the rule had nothing to
#      see there — it locks the repaired edge, it did not predict it. It is not a broad
#      input-contract audit and must not be read as one. The reason the population is 1 is
#      itself the finding: 103 of 114 skills declare no machine-readable inputs at all, so there
#      is no contract there for anything to break.
#
#   2. check_section_anchor  (FAIL + ratchet)
#      `<path>.md § <section>` where <path> identifies a file in THIS repo must name a section
#      that exists in it. Anchors accepted: any heading (raw and numbering-stripped), any
#      `**bold**` run, any line-leading ordinal. A target is identified two ways: the cited
#      path IS a repo path, or the cited path is a UNIQUE SUFFIX of exactly one repo file
#      (`frontend/rules/migration-frontend.md` -> templates/packs/frontend/rules/...). Suffix
#      keys always keep at least one `/`, so bare basenames are excluded by construction — see
#      BARE BASENAMES below for why that line is drawn there. Measured at 5ffd22b (a commit, not
#      "the tree this ships in" — that tree moves, and the run prints its own live totals):
#      1141 `.md`-target `§` citations, 114 identify a repo file and were opened, 17 findings
#      (15% of the checked population) — every one opened by hand. 9 of the 17 are ratcheted in
#      scripts/_handoff-baseline.md and 7 of those 9 are simply absent anchors; the other 8 are
#      repaired in this change set, so a pristine 5ffd22b prints FAIL=8 and the shipped tree
#      prints FAIL=0. Suffix resolution is what took the checked population from 80 to 114; it
#      surfaced those 8 further findings, all real and all repaired in the commit that added it
#      (three dangling `§ lifecycle-hooks` / `§ default-true-wrapper-props` / `§ permission-gate`
#      anchors in align-discipline-catalogue.md, a self-citation in
#      migration-discipline-procedures.md naming a section that file does not have, and
#      ui-ux/_topics.md extracting from an align-discipline.md `§ closure verbs` that is not a
#      section there).
#
#   3. check_artifact_name_drift  (FAIL + ratchet)
#      An `_artifact.md` name that PROSE names, no script writes, and that sits one small edit
#      (difflib ratio >= 0.72) from a name the scripts DO write, is a spelling that drifted off
#      its writer. Measured at 5ffd22b: 53 prose names, 26 script names, 22 shared, 6 findings —
#      all six read and all six benign, hence the 6-line baseline. Retro-run over `git archive
#      2e77692` (pre-fix): the same six PLUS `_refresh-knowledge-extract.md ~ _refresh-extract.md`
#      — i.e. this rule would have been RED on the original defect.
#
#   4. check_scaffold_ordinal  (FAIL, no baseline)
#      A script that emits `## <N>. <Title>` into a named artifact publishes an ordinal->title
#      map. Prose writing `§ N (gloss)` about that artifact must agree with it. Measured at 5ffd22b:
#      2 scaffolders mapped (`_refresh-extract.md` 11 sections from refresh-extract-checklist.sh,
#      `_codebase-scan.md` 8 from deep-codebase-scan.sh), 19 glossed ordinal claims, 0 findings.
#      BE PRECISE ABOUT THE RETRO, because the first draft of this comment was not. A PLAIN run
#      of this script over `git archive 2e77692` finds NOTHING: it reports `_refresh-extract.md
#      =8§` and **0 glossed ordinal claims**. The reason is mechanical, not semantic — at
#      2e77692 the prose still spelled the artifact `_refresh-knowledge-extract.md`, and this
#      rule's scope test (`[a for a in smap if a in scope]`) is a substring match that never
#      fires on the drifted spelling. Check 3 is the rule that goes red there. The 11 findings
#      this comment used to claim as a retro-run are a RECONSTRUCTION: `git archive 2e77692`,
#      then `sed _refresh-knowledge-extract.md -> _refresh-extract.md` across the 7 prose files
#      that carried the drifted name, then run. That tree yields 11 findings across 2 files
#      (templates/phases/phase-4.0-preflight.md, templates/phases/phase-5-verify.md), including
#      `§7 "validated corrections"` (emitted as "Architecture decisions implicit in code") and
#      `§9 "uncategorized user-touched files"` (emitted as "Migration / V1<->V2 mapping"). So
#      the honest claim is narrower than "loud on the broken repo": this rule fires on an
#      ordinal gloss only once the artifact NAME is right, i.e. check 3 has to fire and be
#      repaired first. It is a lock on the second half of that defect, not a predictor of it.
#
# WHAT THIS GATE CANNOT SEE — read before trusting a green run.
#
# Every rule compares TEXT against TEXT and understands neither side. It decides whether a
# named thing EXISTS where the citation says it does. It never decides whether what is there
# SAYS what the citing sentence claims. Specifically:
#
#   * POLARITY. A citation that states the OPPOSITE of the section it points at is invisible.
#     The worked instance: commands/do.md:116 read "resolve by the noun per the precedence note
#     under the routing table", contradicting the very note it cited — do.md:86, "never by which
#     nouns happen to appear ... A surface noun is evidence, never the verdict". The anchor
#     resolved, so check 2 passed it. LIVE AT 5ffd22b, REPAIRED IN THIS CHANGE SET: do.md:116 now
#     resolves by the remedy and says in as many words that counting nouns would answer with the
#     one signal the authority it cites rules out. The RULE stays ungated, because the repair
#     removed an instance and not the blind spot — the population of assertive citations (a
#     `§`-or-"per the … note" citation on a line that also carries
#     must|never|always|only|forbidden|refuse|halt) is 525 lines at 5ffd22b, and no shell rule
#     separates a contradicting one from the rest. Grepping the phrase the two known instances
#     shared ("by the noun") is not the shortcut it looks like: after the repair it survives in
#     exactly one non-self file — templates/tool-adapters/_orchestration-sync.md:33, where it
#     asserts the CORRECT polarity ("never by the noun") — so that grep now matches only a true
#     statement. A rule tuned to a defect already found proves nothing about the next one.
#   * COUNTED FIDELITY CLAIMS. "keeps every halt condition (11 for X, 14 for Y), every invariant
#     (9 each), every row (9 and 10)" in templates/packs/mobile/_topics.md is decidable only by
#     counting per-file structures whose spelling differs between source and abridgement. Not
#     gated. Verified by hand during design and true at HEAD; nothing keeps it true.
#   * SOURCE-SIDE RETRACTION. A section renamed or deleted in the TARGET leaves the citing file
#     textually unchanged. Check 2 catches that only because the anchor stops resolving. A
#     section REWRITTEN under the same heading is invisible.
#   * RUNTIME ARTIFACTS AND BARE BASENAMES — the real shape of the corpus, counted, not
#     estimated. EVERY FIGURE BELOW IS ANCHORED TO 5ffd22b and re-derivable with
#     `git archive 5ffd22b | tar -x -C "$d" && lint-handoffs.sh --repo-root="$d"`. It is stated
#     against a commit rather than "the tree this ships in" on purpose: the live totals move
#     with every citation anyone adds, the run already prints them, and a header that restates a
#     moving number is the very defect this gate exists to catch — it was wrong here twice
#     before it was pinned. At 5ffd22b the 1141 `.md`-target `§` citations break down as:
#         175  name `.claude/` or `ai/` — runtime artifacts that do not exist in this repo.
#              audit-setup.sh's lane, by name, inside a generated artifact. Out of scope here,
#              and excluded BEFORE suffix resolution so a `.claude/rules/x.md` citation can
#              never be silently re-pointed at this repo's template of the same name.
#          82  cite a full repo path.
#          39  cite a partial path that is a unique suffix of exactly one repo file. CHECKED
#              since this rule grew suffix resolution.
#         845  are a bare basename with no `/` at all — which is where every citation of a
#              root-level generic name (README.md, CONTRIBUTING.md, CHANGELOG.md, AGENTS.md,
#              CLAUDE.md) lands, since those carry no `/`. The GENERIC guard exists for the
#              path-bearing form (`docs/README.md § …`, meaning the CONSUMING project's file);
#              at 5ffd22b that form occurs 0 times, so the guard currently costs nothing.
#     175 + 82 + 39 + 845 = 1141: the four buckets are the whole corpus, and that identity is
#     the check on them. The 82 + 39 = 121 path-identified citations are the candidate
#     population, of which 114 survive the section-name guards and are opened. The 845 are the
#     whole of what this gate does not see, and the next bullet is why.
#   * UNDECLARED CONTRACTS. Check 1 can only compare against a `## Inputs` section. 103 of 114
#     skills have none, so 103 skills have no input contract for anything to break.
#   * SEMANTIC SECTION SPECS. `_topics.md` `sections:` lists are CONTENT specs, not heading
#     specs. Comparing them against fallback headings flags 1004 misses across 232 of 293 pairs
#     (79%) — top misses `output_format` x83, `persona` x82, `overview` x53 — and is not
#     implemented at any severity. Same measurement, same conclusion, as check 8b of
#     validate-pack-consistency.sh, whose own header records 221 of 293 (75%) for the identical
#     rule and concludes "a gate that flags half the corpus gets muted, and a muted gate is worse
#     than none". Downgrading it to WARN is the mute button with extra steps.
#   * BARE BASENAMES. A citation with no `/` is not resolved, and the reason is that the name
#     usually does not identify a file: of the 845 bare-basename citations at 5ffd22b, 169 name
#     a basename that more than one repo file carries (`SKILL.md`, `_topics.md`, `CHANGELOG.md`,
#     `adapter.md`) and 532 name no repo file at all — overwhelmingly the CONSUMING project's
#     files, which a pack is supposed to talk about. Only 144 name a basename unique in this
#     tree, and picking those out would resolve one citation in six on a rule ("unique
#     basename") that the corpus itself contradicts five times in six. That is the line: a
#     target is checked when the citation IDENTIFIES it — as a path, or as a suffix that only
#     one file can satisfy — and skipped when the citation merely NAMES it. The intermediate
#     option was measured before it was rejected, and the productive half of it (unique suffix,
#     `/` required) was adopted rather than filed under "not implemented": measured at 5ffd22b it
#     moves the checked population 80 -> 114 and surfaces exactly 8 findings, every one real and
#     every one repaired in this change set. Re-running this gate against a pristine 5ffd22b is
#     the regression test for that repair set: it must print FAIL=8, and each of the 8 must name
#     a citation repaired here.
#
# This gate is a floor on edge integrity. It never certifies that a citation still MEANS what it
# meant.
#
# SCOPE. `tests/` and `.archive/` are skipped on both the citing and the target side —
# `.archive/setup-project.M1.monolith.md` alone contributes two correct-history findings. This
# script and `scripts/_handoff-baseline.md` exclude THEMSELVES from every scan: the ledger quotes
# the defects it records verbatim, so scanning it would re-detect what it exists to record, and
# this header names `_refresh-knowledge-extract.md` (check 3's original instance), which would
# otherwise enter check 3's script-name set and blind the rule to its own regression.
#
# RATCHET. Known violations live in scripts/_handoff-baseline.md as `<key> <RULE> # reason`,
# suppressed to one counted summary WARN; anything NOT listed is a hard FAIL. A baseline line
# with NO trailing reason suppresses nothing — the finding stays red and the gate WARNs that the
# line is inert. A baselined key that stops reproducing WARNs to be deleted, so the file cannot
# rot into a mute button. Reasons beginning `REPAIR:` mark a pending fix rather than an accepted
# state and are counted separately in their own WARN, because a backlog seeded on day one is
# exactly how baselining becomes the normal response. The ledger's advertised size is not taken
# on trust: it states its own count in prose ("The backlog is N lines — M of them REPAIR:"), and
# check_baseline_hygiene FAILs when the entries it actually parses disagree with either number.
# That is the same TEXT-vs-CONTRACT test the four rules apply between two files, turned on the
# gate's own ledger — the last time a comment here advertised a bigger backlog than its baseline
# held, it sent readers to a worklist that was not there. It also gives a TRUNCATED ledger a name:
# read short, a baseline silently un-suppresses its missing entries, which otherwise surfaces as a
# batch of ratcheted defects going red at once with nothing pointing at the file that caused it.
#
# Usage:  lint-handoffs.sh [--repo-root=<dir>] [--strict] [--quiet] [--handoff-report]
# Exit:   1 on any FAIL (or any WARN under --strict); 0 otherwise.
#
# `--handoff-report` prints the full picture — every baselined defect and the per-check
# populations. It is the repair worklist; it changes nothing about the exit code.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
STRICT=0; QUIET=0; HO_REPORT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --strict) STRICT=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --handoff-report) HO_REPORT="--report"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" || exit 1
REPO_ROOT="$PWD"   # absolute from here on: the analysis resolves paths against it AFTER this cd

fail=0; warn=0
err()      { echo "  FAIL  $*" >&2; fail=$((fail + 1)); }
warn_msg() { [[ $QUIET -eq 0 ]] && echo "  WARN  $*"; warn=$((warn + 1)); }
ok()       { [[ $QUIET -eq 0 ]] && echo "  ok    $*"; return 0; }
note()     { [[ $QUIET -eq 0 ]] && echo "        $*"; return 0; }

HO_OUT="$(mktemp)"; HO_ERR="$(mktemp)"
trap 'rm -f "$HO_OUT" "$HO_ERR"' EXIT

# Emit every analysis line belonging to one check, at its declared severity.
# `while IFS=$'\t' read` over a temp file (not a pipe) so the counters survive — bash 3.2 on
# macOS has no `lastpipe`, and a subshell would drop every increment.
emit_for() {  # $1 = check tag
  local tag chk msg
  while IFS=$'\t' read -r tag chk msg; do
    [[ "$chk" == "$1" ]] || continue
    case "$tag" in
      F) err "$msg" ;;
      W) warn_msg "$msg" ;;
      R) note "$msg" ;;
      I) ok "$msg" ;;
      H) echo "  $msg" >&2 ;;
    esac
  done < "$HO_OUT"
}

# The four rules, one function each. Named so `lint-validator-parity.sh` can resolve any
# rule/doc/phase/command that cites them as live gate behaviour.
check_skill_input_contract() { emit_for skill-input; }
check_section_anchor()       { emit_for section-anchor; }
check_artifact_name_drift()  { emit_for name-drift; }
check_scaffold_ordinal()     { emit_for scaffold-ordinal; }
check_baseline_hygiene()     { emit_for baseline; }

if ! command -v python3 >/dev/null 2>&1; then
  # A hard FAIL, never a WARN: a gate that quietly does nothing when its interpreter is missing is
  # indistinguishable from a gate that passes. A WARN would change the exit code only under
  # --strict, and the CI step deliberately runs without it (the baseline's summary WARN has to stay
  # informational) — so a WARN here would be an exit-0 step that checked nothing, which is the
  # failure this gate exists to make impossible. scripts/verify-pack-matrix.sh:35-38 takes exactly
  # this line for exactly this condition; this matches its precedent rather than inventing a
  # second policy for the same missing interpreter.
  err "handoff edges not checked — python3 not found (all four rules skipped)"
  echo ""
  echo "handoffs: FAIL=$fail WARN=$warn"
  exit 1
fi

if ! python3 - "$REPO_ROOT" $HO_REPORT >"$HO_OUT" 2>"$HO_ERR" <<'PYHO'
import os, re, sys, difflib

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = os.path.abspath(sys.argv[1])
REPORT = "--report" in sys.argv[2:]
BASELINE = os.path.join(ROOT, "scripts", "_handoff-baseline.md")
BASELINE_REL = "scripts/_handoff-baseline.md"
SELF = {"scripts/_handoff-baseline.md", "scripts/lint-handoffs.sh"}
PRUNE = {".git", "node_modules", "__pycache__", ".venv", "venv", "dist", "build", ".mypy_cache"}
SKIP_TOP = {"tests", ".archive"}
GENERIC = {"README.md", "CONTRIBUTING.md", "CHANGELOG.md", "AGENTS.md", "CLAUDE.md"}
RULES = ("SKILL-INPUT", "SECTION-ANCHOR", "NAME-DRIFT", "SCAFFOLD-ORDINAL")


def read(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def out(tag, check, msg):
    print("%s\t%s\t%s" % (tag, check, msg))


# ---- file universe. A filesystem walk, deliberately NOT `git ls-files`: the fixture roots
# under tests/validators/ are mini-repos whose files may be untracked at the moment the harness
# runs them, and a gate that silently sees nothing there would pass every bad fixture.
FILES = []
for dp, dn, fn in os.walk(ROOT):
    rel_dir = os.path.relpath(dp, ROOT)
    dn[:] = sorted(d for d in dn if d not in PRUNE)
    if rel_dir == ".":
        dn[:] = [d for d in dn if d not in SKIP_TOP]
    for f in sorted(fn):
        FILES.append(f if rel_dir == "." else os.path.normpath(os.path.join(rel_dir, f)))
FILESET = set(FILES)
MD = [f for f in FILES if f.endswith(".md") and f not in SELF]
SCRIPTS = [f for f in FILES
           if f.startswith("scripts" + os.sep) and f.count(os.sep) == 1
           and (f.endswith(".sh") or f.endswith(".py")) and f not in SELF]

findings = []   # (rule, key, check-tag, human message)


# ================================================================ 1. SKILL-INPUT CONTRACT
SKILL_DIR = re.compile(r'(?:^|/)skills/([a-z0-9][a-z0-9-]*)/SKILL\.md$')
KEY = re.compile(r'^\s*(?:[-*]\s*)?([a-z_][a-z0-9_]*)\s*:')
# A DISPATCH verb only counts LINE-LEADING and capitalised, i.e. as the imperative that hands
# the block over. "closed by the dispatch table" mid-sentence is prose about dispatch, not an
# act of it, and admitting it turns a file-content example into a false handoff.
DISPATCH = re.compile(r'(?m)^[ \t]*(?:[-*>]\s*)?(?:\*\*)?'
                      r'(?:Pass|Hand|Hands|Invoke|Invokes|Dispatch|Dispatches|Call|Calls'
                      r'|Delegate|Delegates)(?![a-z])')


def _skill_index():
    idx = {}
    for f in FILES:
        m = SKILL_DIR.search(f.replace(os.sep, "/"))
        if m:
            idx.setdefault(m.group(1), f)
    return idx


def _declared_inputs(path):
    """The `## Inputs` section AS A WHOLE declares: bullet identifiers AND any `key:` inside it,
    because a required input whose shape is spelled out in a fenced sub-block (`members:` with
    its `name:`/`root:`/`manifest:` rows) is declared just as much as a one-line bullet is."""
    lines = read(os.path.join(ROOT, path)).splitlines()
    start = None
    for i, line in enumerate(lines):
        if re.match(r'^#{2,4}\s+Inputs\b', line.strip()):
            start = i + 1
            break
    if start is None:
        return None
    decl = set()
    for line in lines[start:]:
        if re.match(r'^#{1,4}\s+\S', line):
            break
        m = re.match(r'^\s*[-*]\s+`([a-z_][a-z0-9_]*)`', line)
        if m:
            decl.add(m.group(1))
        m = KEY.match(line)
        if m:
            decl.add(m.group(1))
    return decl


def check_skill_input_contract():
    idx = _skill_index()
    decl = {n: _declared_inputs(p) for n, p in idx.items()}
    have = {n: d for n, d in decl.items() if d}
    sites = 0
    for f in MD:
        # `_topics.md` entries MENTION a skill name in a `name:/kind:/fallback:` block; that is a
        # topic spec, not an invocation, and admitting it was 6 of the 14 raw candidates.
        if os.path.basename(f) == "_topics.md":
            continue
        own = SKILL_DIR.search(f.replace(os.sep, "/"))
        own = own.group(1) if own else None
        lines = read(os.path.join(ROOT, f)).splitlines()
        i = 0
        while i < len(lines):
            if not re.match(r'^\s*```', lines[i]):
                i += 1
                continue
            j = i + 1
            while j < len(lines) and not re.match(r'^\s*```\s*$', lines[j]):
                j += 1
            # LEAD = the lines that actually introduce this block. A heading resets the scope:
            # the paragraph on the far side of `#### Always-write fallback` is a different
            # subsection and its verbs do not dispatch this block.
            lo = max(0, i - 12)
            for k in range(i - 1, lo - 1, -1):
                if re.match(r'^\s*#{1,6}\s+\S', lines[k]):
                    lo = k + 1
                    break
            lead = "\n".join(lines[lo:i])
            window = "\n".join(lines[max(0, i - 12):min(len(lines), j + 13)])
            named = sorted(n for n in idx
                           if re.search(r'(?<![a-z0-9-])%s(?![a-z0-9-])' % re.escape(n), window))
            if len(named) == 1 and named[0] != own and named[0] in have and DISPATCH.search(lead):
                skill = named[0]
                keys = [(k + 1, KEY.match(lines[k]).group(1))
                        for k in range(i + 1, j) if KEY.match(lines[k])]
                if keys:
                    sites += 1
                    for ln, k in keys:
                        if k not in have[skill]:
                            findings.append((
                                "SKILL-INPUT", "%s::%s::%s" % (f, skill, k), "skill-input",
                                "%s:%d hands `%s:` to `%s`, whose `## Inputs` "
                                "(%s) does not declare it" % (f, ln, k, skill, idx[skill])))
            i = j + 1
    return len(idx), len(have), sites


# ================================================================ 2. SECTION-ANCHOR RESOLUTION
CITE = re.compile(r'`?([A-Za-z0-9_][A-Za-z0-9_./-]*\.md)`?\s*§§?\s*')
TERM = re.compile(r'\s+[—–]\s|[`(),;|"]|\.\s|\s-\s|\s+§')


def _norm(s):
    s = s.replace("`", " ").replace("*", " ").replace("_", " ")
    return re.sub(r'[^a-z0-9]+', ' ', s.lower()).strip()


def _anchors(text):
    a = set()
    for line in text.splitlines():
        s = line.strip()
        m = re.match(r'^(#{1,6})\s+(.*?)\s*#*$', s)
        if m:
            h = m.group(2).strip()
            a.add(_norm(h))
            a.add(_norm(re.sub(r'^\d+(?:\.\d+)*[.)]?\s*', '', h)))
        for b in re.findall(r'\*\*(.+?)\*\*', line):
            a.add(_norm(b))
        # Line-leading ordinal ONLY — the number, never the sentence after it. Admitting the
        # trailing text makes every numbered step an anchor, and `§ Dispatch` then resolves
        # against "3. Dispatch **refactoring-sweep** with ..." in a file that has no such section.
        m = re.match(r'^(?:[-*]\s+)?\**\s*(\d+(?:\.\d+)*)[.)]\s+\S', s)
        if m:
            a.add(_norm(m.group(1)))
    a.discard("")
    return a


def _section_of(run):
    run = run.lstrip()
    m = re.match(r'^[`"“]([^`"”]{2,80})[`"”]', run)
    if m:
        return m.group(1).strip(), True
    t = TERM.search(run)
    return (run[:t.start()] if t else run).strip().rstrip(".:"), False


def _suffix_index():
    """Every `/`-bearing path suffix that identifies exactly ONE repo file. This is what makes a
    partial citation decidable: `frontend/rules/migration-frontend.md` is not a repo path, but
    exactly one repo file ends with it, so the target is not in doubt. Bare basenames are
    excluded by construction (the loop starts at 1, so every key keeps at least one `/`) —
    `SKILL.md` or `README.md` alone name nothing in particular."""
    idx = {}
    for f in FILES:
        parts = f.replace(os.sep, "/").split("/")
        for i in range(1, len(parts)):
            idx.setdefault("/".join(parts[i:]), set()).add(f)
    return {k: next(iter(v)) for k, v in idx.items() if len(v) == 1}


def check_section_anchor():
    total = 0
    checked = 0
    cache = {}
    sfx = _suffix_index()
    for f in MD:
        for ln, line in enumerate(read(os.path.join(ROOT, f)).splitlines(), 1):
            hits = list(CITE.finditer(line))
            for i, m in enumerate(hits):
                total += 1
                path = m.group(1)
                if "/" not in path or os.path.basename(path) in GENERIC:
                    continue
                # RUNTIME TARGETS ARE OUT OF SCOPE, and must be excluded BEFORE suffix
                # resolution or a `.claude/rules/x.md` citation could be silently re-pointed at
                # this repo's template of the same name. CITE cannot start on `.`, so a
                # `.claude/...` citation arrives here as `claude/...`; check the char before.
                st = m.start(1)
                if (st > 0 and line[st - 1] == ".") or path.startswith(("ai/", "claude/")):
                    continue
                if path not in FILESET:
                    path = sfx.get(path.replace(os.sep, "/"), "")
                    if not path:
                        continue
                end = hits[i + 1].start() if i + 1 < len(hits) else len(line)
                sec, quoted = _section_of(line[m.end():end])
                if len(sec) < 3 or (not quoted and len(sec.split()) > 5):
                    continue
                c = _norm(sec)
                if len(c) < 3:
                    continue
                checked += 1
                if path not in cache:
                    cache[path] = _anchors(read(os.path.join(ROOT, path)))
                if any(c == a or a.startswith(c + " ") or c.startswith(a + " ")
                       or (" " + c + " ") in (" " + a + " ") for a in cache[path]):
                    continue
                findings.append((
                    "SECTION-ANCHOR",
                    "%s::%s::%s" % (f, path, re.sub(r'\s+', '-', c)), "section-anchor",
                    "%s:%d cites `%s § %s` — no heading, bold run or ordinal in that file "
                    "answers to it" % (f, ln, path, sec)))
    return total, checked


# ================================================================ 3. ARTIFACT-NAME / WRITER DRIFT
ART = re.compile(r'(_[a-z0-9][a-z0-9-]*\.(?:md|json|jsonl))')


def check_artifact_name_drift():
    prose, script = {}, {}
    real = {os.path.basename(f) for f in FILES}
    for f in MD:
        for ln, line in enumerate(read(os.path.join(ROOT, f)).splitlines(), 1):
            for n in ART.findall(line):
                prose.setdefault(n, (f, ln))
    for f in SCRIPTS:
        for n in ART.findall(read(os.path.join(ROOT, f))):
            script.setdefault(n, f)
    prose = {k: v for k, v in prose.items() if k not in real}
    script = {k: v for k, v in script.items() if k not in real}
    for n in sorted(set(prose) - set(script)):
        best, ratio = None, 0.0
        for m in script:
            r = difflib.SequenceMatcher(None, n, m).ratio()
            if r > ratio:
                best, ratio = m, r
        if best and ratio >= 0.72:
            f, ln = prose[n]
            findings.append((
                "NAME-DRIFT", "%s::%s" % (n, best), "name-drift",
                "%s:%d names `%s`, which no script writes, and which sits %.2f from `%s` — "
                "written by %s" % (f, ln, n, ratio, best, script[best])))
    return len(prose), len(script), len(set(prose) & set(script))


# ================================================================ 4. SCAFFOLD-ORDINAL CONTRACT
SEC = re.compile(r'^## (\d+)\. (.+?)\s*$', re.M)
ORD = re.compile(r'(?:§§?|[Ss]ections?)\s*(\d+)\s*\(([^)]{3,60})\)')
STOP = set("the a an of and or to in for on by with is are be it its this that from as at not "
           "must may should all any each per no if then than what which when where who how "
           "only also into out over under only".split())


def _words(s):
    return {w for w in re.findall(r'[a-z0-9]+', s.lower()) if len(w) > 2 and w not in STOP}


def _scaffolders():
    """Map artifact -> (script, {ordinal: title}). The artifact is taken ONLY from a declared
    output (`# Output:` header line or a `VAR="…_x.md"` assignment), never from a mention in the
    body: a script that merely READS another artifact would otherwise claim its ordinals."""
    m = {}
    for f in SCRIPTS:
        txt = read(os.path.join(ROOT, f))
        secs = dict((int(a), b) for a, b in SEC.findall(txt))
        if len(secs) < 3:
            continue
        art = None
        mm = re.search(r'^\s*#\s*Output:\s*\S*?(_[a-z0-9-]+\.md)\s*$', txt, re.M)
        if mm:
            art = mm.group(1)
        else:
            mm = re.search(r'^[A-Za-z_][A-Za-z0-9_]*="[^"]*?(_[a-z0-9-]+\.md)"\s*$', txt, re.M)
            if mm:
                art = mm.group(1)
        if art:
            m.setdefault(art, (f, secs))
    return m


def check_scaffold_ordinal(smap):
    claims = 0
    for f in MD:
        lines = read(os.path.join(ROOT, f)).splitlines()
        blocks, cur, start = [], [], 1
        for i, line in enumerate(lines, 1):
            if line.strip() == "":
                if cur:
                    blocks.append((start, cur))
                    cur = []
            else:
                if not cur:
                    start = i
                cur.append(line)
        if cur:
            blocks.append((start, cur))
        for bi, (bstart, blk) in enumerate(blocks):
            scope = "\n".join("\n".join(b) for _, b in blocks[max(0, bi - 2):bi + 1])
            arts = [a for a in smap if a in scope]
            if len(arts) != 1:            # ambiguous scope decides nothing
                continue
            art = arts[0]
            sf, secs = smap[art]
            for li, line in enumerate(blk):
                for m in ORD.finditer(line):
                    n, gloss = int(m.group(1)), m.group(2)
                    claims += 1
                    gw = _words(gloss)
                    if not gw:
                        continue
                    title = secs.get(n)
                    if title is not None and (gw & _words(title)):
                        continue
                    alt = [str(k) for k, v in sorted(secs.items()) if gw & _words(v)]
                    findings.append((
                        "SCAFFOLD-ORDINAL", "%s::%s::%d" % (f, art, n), "scaffold-ordinal",
                        "%s:%d calls %s §%d \"%s\", but %s emits it as \"%s\"%s"
                        % (f, bstart + li, art, n, gloss, sf,
                           title if title is not None
                           else "(no §%d at all — it emits %d sections)" % (n, len(secs)),
                           "" if not alt else " — that gloss matches §" + "/§".join(alt))))
    return claims


# ================================================================ RATCHET
# The ledger states its own size in prose ("The backlog is 15 lines — 7 of them `REPAIR:`"). That
# is a claim a file makes about ITSELF and is decidable by counting the file — the same shape this
# gate checks between two files, so it is checked here rather than trusted. It also gives a
# truncated or half-written ledger a name: a baseline read while missing its trailing entries
# otherwise surfaces only as that many ratcheted defects going red at once, with nothing pointing
# at the ledger as the cause. Absent sentence = no check, so fixture baselines are unaffected.
ADVERT = re.compile(r'backlog is\s+\**(\d+)\s+lines?\b[^\n]*?\b(\d+)\s+of them')


def _advertised(text):
    m = ADVERT.search(text)
    return (int(m.group(1)), int(m.group(2))) if m else None


def load_baseline():
    """A baseline line MUST carry a trailing `# reason`. A line added to silence a finding
    nobody read is the exact failure this gate exists to prevent, so a reasonless line does not
    suppress anything — the finding stays red and `unreasoned` reports why."""
    keep, unreasoned, repair = set(), [], set()
    text = read(BASELINE)
    for line in text.splitlines():
        m = re.match(r'^([^\s#]+)[ \t]+([A-Z][A-Z-]+)[ \t]*(#.*)?$', line.strip())
        if not m or m.group(2) not in RULES:
            continue
        reason = (m.group(3) or "").strip("# \t")
        if reason:
            keep.add((m.group(2), m.group(1)))
            if reason.upper().startswith("REPAIR:"):
                repair.add((m.group(2), m.group(1)))
        else:
            unreasoned.append((m.group(2), m.group(1)))
    return keep, unreasoned, repair, _advertised(text)


n_skills, n_inputs, n_sites = check_skill_input_contract()
n_cites, n_checked = check_section_anchor()
n_prose, n_script, n_shared = check_artifact_name_drift()
smap = _scaffolders()
n_claims = check_scaffold_ordinal(smap)

base, unreasoned, repair, advertised = load_baseline()
for rule, key in sorted(unreasoned):
    out("W", "baseline", "baseline line `%s  %s` carries no `# reason` — it suppresses nothing "
                         "until it does (%s)" % (key, rule, BASELINE_REL))

if advertised is not None:
    n_entries, (a_lines, a_repair) = len(base) + len(unreasoned), advertised
    if a_lines != n_entries:
        out("F", "baseline", "%s advertises a %d-line backlog but %d entr%s parse. Either the "
                             "sentence is stale, or the file was read short — a truncated ledger "
                             "un-suppresses its missing entries, which reads as defects going red "
                             "with nothing naming the cause."
                             % (BASELINE_REL, a_lines, n_entries,
                                "y" if n_entries == 1 else "ies"))
    if a_repair != len(repair):
        out("F", "baseline", "%s advertises %d `REPAIR:` entr%s but %d parse — the pending-fix "
                             "count is the number a reader acts on, so it may not drift."
                             % (BASELINE_REL, a_repair, "y" if a_repair == 1 else "ies",
                                len(repair)))

seen, new, known = set(), [], []
for rule, key, check, msg in findings:
    seen.add((rule, key))
    (known if (rule, key) in base else new).append((rule, key, check, msg))

for rule, key, check, msg in new:
    out("F", check, "[%s] %s" % (rule, msg))

out("I", "skill-input", "skill-input contract: %d skills indexed, %d declare `## Inputs`, "
                        "%d dispatched key-block(s) checked" % (n_skills, n_inputs, n_sites))
out("I", "section-anchor", "section anchors: %d `.md §` citation(s), %d name a path that "
                           "resolves here and were opened" % (n_cites, n_checked))
out("I", "name-drift", "artifact names: %d in prose, %d in scripts, %d shared"
                       % (n_prose, n_script, n_shared))
out("I", "scaffold-ordinal", "scaffold ordinals: %d scaffolder(s) mapped (%s), %d glossed "
    "ordinal claim(s)" % (len(smap), ", ".join("%s=%d§" % (a, len(v[1]))
                                               for a, v in sorted(smap.items())) or "none",
                          n_claims))

if REPORT:
    for rule, key, check, msg in sorted(known):
        out("R", check, "baselined  [%s] %s" % (rule, msg))
    for rule, key, _c, _m in sorted(known):
        if (rule, key) in repair:
            out("R", "baseline", "REPAIR-pending  %-14s %s" % (rule, key))

for rule, key in sorted(base - seen):
    out("W", "baseline", "`%s  %s` no longer reproduces — drop its line from %s"
                         % (key, rule, BASELINE_REL))

if known:
    n_rep = len([1 for r, k, _c, _m in known if (r, k) in repair])
    out("W", "baseline", "%d known handoff defect(s) suppressed by %s (%d marked REPAIR: a "
                         "pending fix, not an accepted state)%s"
                         % (len(known), BASELINE_REL, n_rep,
                            "" if REPORT else " — --handoff-report lists them"))
if new:
    out("H", "baseline", "^ fix the citation, or — if it is correct as-is — add "
                         "`<key>  <RULE>` with a reason to %s. A reason that starts `REPAIR:` "
                         "records a pending fix instead of accepting the state." % BASELINE_REL)
PYHO
then
  err "handoff edge analysis did not run: $(head -3 "$HO_ERR" | tr '\n' ' ')"
else
  check_skill_input_contract
  check_section_anchor
  check_artifact_name_drift
  check_scaffold_ordinal
  check_baseline_hygiene
fi

echo ""
echo "handoffs: FAIL=$fail WARN=$warn"
if [[ $fail -gt 0 ]] || { [[ $STRICT -eq 1 ]] && [[ $warn -gt 0 ]]; }; then exit 1; fi
exit 0
