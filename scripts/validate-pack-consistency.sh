#!/usr/bin/env bash
# validate-pack-consistency.sh — assert every pack's manifest is internally consistent (#49).
# The gap this closes: _topics.md / _essentials.md drift was invisible (pack-coverage-scan checks
# filesystem presence only), so dangling _examples fallbacks (#41) and missing topic entries (#47)
# shipped unnoticed. For each templates/packs/<pack>:
#   1. has _essentials.md + _topics.md + _version.json                          (FAIL)
#   2. _version.json is valid JSON with a "version" field                       (FAIL)
#   3. every _topics `fallback: <path>` resolves to a real file in the pack      (FAIL)
#   4. every _essentials array entry (agents/commands/skills/rules/ai-patterns)
#      resolves to a real artifact (skills accept <x>.md OR <x>/SKILL.md)        (FAIL)
#   5. every command/agent/rule/skill/ai-pattern FILE has a _topics `- name:` entry (WARN)
#      (`references/` excluded by design — see the note at the check itself)
#   6. the current `version` is described in the pack changelog — either a
#      `## <version>` heading in the CHANGELOG.md that `changelog` points at, or a
#      matching key in a legacy in-JSON `changelog` object                        (WARN)
#   7. every _essentials `rule_references:` name ships as references/<name>.md     (WARN)
#   8a. every `_examples/<name>.md` still has a source artifact in the pack        (WARN)
#   3b. FALLBACK STRATEGY — check 3 asks whether a `fallback:` VALUE resolves;
#      this asks whether the STRATEGY it names can deliver anything. A
#      `stub-from-sections` with no NON-EMPTY `sections:` list emits an EMPTY
#      file (STUB-NO-SECTIONS, hard FAIL); one standing in front of a finished
#      artifact of the same kind+name delivers a heading skeleton instead of it
#      (STUB-OVER-SOURCE, ratcheted through
#      templates/packs/_topics-strategy-baseline.md); and the per-pack COUNT of
#      zero-delivery topics may not grow past
#      templates/packs/_greenfield-budget.md. `--coverage-report` prints the
#      per-pack coverage table, whose PERCENTAGES are reported and never gated
#                                                                          (FAIL if new)
#   8b. FALLBACK INTEGRITY — every `_examples/<name>.md` still AGREES with the
#      source it abridges, on the axes a text comparison can actually decide:
#      no framed magnitude / dispatch target / frontmatter value the source
#      disowns, no section the corpus keeps ≥85% of the time, no dropped safety
#      signal, no dropped sibling-boundary (agents) or closing gate/verdict
#      block, and no undeclared literal copy. It does NOT understand either
#      file — a source-side retraction or polarity flip is invisible to it, and
#      the closing family covers the 80 of 282 pairs whose SOURCE carries a
#      done-condition, not all 282; see "WHAT THIS CHECK DOES NOT CATCH" at the
#      check itself. Ratcheted through templates/packs/_fallback-baseline.md,
#      plus a per-pack COUNT budget for boundary loss outside the agents class
#      in templates/packs/_greenfield-budget.md                             (FAIL if new)
#
# Usage:  validate-pack-consistency.sh [--repo-root=<dir>] [--strict] [--quiet]
#                                      [--fallback-report] [--coverage-report]
#         validate-pack-consistency.sh --record-strategy  # regenerate the 3b ledger
#         validate-pack-consistency.sh --record-budget    # regenerate the per-pack budgets
#         validate-pack-consistency.sh --recopy         # list COPY-DRIFT repairs
#         validate-pack-consistency.sh --recopy-apply   # perform them
# Exit:   1 on any FAIL (or any WARN under --strict); 0 otherwise.
#
# `--recopy` / `--recopy-apply` close a COPY-DRIFT finding deterministically: they
# re-copy each `_examples/<name>.md` that declares `generated-from:` from the
# source it declares, preserving the example's own head. That is the step the
# file's header has always demanded ("edit the command and re-copy") and that
# nothing could perform — which is why both sides were hand-edited and this gate
# went RED. These two modes run alone and exit; they never combine with a scan.
#
# `--fallback-report` prints the full 8b picture — every baselined defect plus the
# safety-signal backlog that is counted but not gated. It is the repair worklist; it
# changes nothing about the exit code.
#
# `--coverage-report` prints the 3b picture — every ledgered strategy defect plus the
# per-pack greenfield coverage table (topics, zero-delivery topics, how many of those
# have a finished artifact on disk, and the two percentages). The percentages are
# REPORTED AND NEVER GATED; see the check-3b header for why no threshold in the
# measured distribution discriminates. It changes nothing about the exit code.
#
# `--record-strategy` regenerates the 3b ledger from what reproduces now, carrying
# existing reasons over verbatim and writing new entries WITHOUT one — so a recorded
# entry suppresses nothing until a human writes its reason. It runs the scan, writes,
# and exits.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
STRICT=0; QUIET=0; FB_REPORT=""; RECOPY=0; RECOPY_APPLY=0; ST_REPORT=""; ST_RECORD=""
BUDGET_RECORD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --strict) STRICT=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --fallback-report) FB_REPORT="--report"; shift ;;
    --coverage-report) ST_REPORT="--report"; shift ;;
    --record-strategy) ST_RECORD="--record"; shift ;;
    --record-budget) BUDGET_RECORD="--record-budget"; shift ;;
    --recopy) RECOPY=1; shift ;;
    --recopy-apply) RECOPY=1; RECOPY_APPLY=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" || exit 1
REPO_ROOT="$PWD"   # absolute from here on: check 8b resolves paths against it AFTER this cd

# ---------------------------------------------------------------------------
# --recopy / --recopy-apply — the EXECUTABLE half of COPY-DRIFT's remediation.
#
# A `_examples/<name>.md` carrying `<!-- generated-from: <path> -->` is a literal
# copy, and its own header says "REGENERATE whenever the command changes … Do not
# hand-edit; edit the command and re-copy." Until this mode existed there was
# nothing to run: the only re-copy was a human retyping it, so both sides got
# hand-edited independently and this gate went RED with
#   FAIL backend: _examples/add-feature.md [COPY-DRIFT] … differs by 34 line(s)
# The gate could name the drift; nothing could close it deterministically.
#
# Reconstruction, matching exactly what `body()` below compares:
#   1. the EXAMPLE's head, byte for byte — frontmatter, its blank-line
#      convention, and the `generated-from:` block. COPY-DRIFT is a BODY check
#      (`body()` strips frontmatter and HTML comments first) and an example's
#      frontmatter is legitimately abridged: database/_examples/schema-diff.md
#      carries a one-line `description:` where its source skill carries four.
#   2. the SOURCE's body, verbatim — the only part COPY-DRIFT grades and the only
#      part this rewrites.
# Verified lossless: on a clean tree all 10 declared copies reconstruct
# byte-identically, and a file whose body already matches is skipped before any
# reconstruction happens, so a clean run rewrites nothing.
#
# Exit: 0 when nothing drifted, or when --recopy-apply repaired everything;
#       1 when a dry run found drift; 2 when a declared source is missing.
if [[ $RECOPY -eq 1 ]]; then
  python3 - "$REPO_ROOT" "$RECOPY_APPLY" <<'RECOPY_PY'
import os, re, sys
root, apply_ = sys.argv[1], sys.argv[2] == "1"

def read(p):
    with open(p, encoding="utf-8") as fh:
        return fh.read()

def split_fm(t):
    if not t.startswith("---"):
        return "", t
    i = t.find("\n---", 3)
    if i < 0:
        return "", t
    end = t.find("\n", i + 1)
    if end < 0:
        return t, ""
    return t[:end + 1], t[end + 1:]

# Identical normalization to body() in the gate below.
def cmp_body(t):
    _, rest = split_fm(t)
    rest = re.sub(r'<!--.*?-->', '', rest, flags=re.S)
    return [l.rstrip() for l in rest.splitlines() if l.strip()]

drift, fixed, checked, errs = [], [], 0, []
packs = os.path.join(root, "templates", "packs")
for pack in sorted(os.listdir(packs)):
    exdir = os.path.join(packs, pack, "_examples")
    if not os.path.isdir(exdir):
        continue
    for name in sorted(os.listdir(exdir)):
        if not name.endswith(".md"):
            continue
        ex_path = os.path.join(exdir, name)
        ex = read(ex_path)
        m = re.search(r'<!--\s*generated-from:\s*([A-Za-z0-9._/-]+).*?-->', ex, flags=re.S)
        if not m:
            continue
        src_path = os.path.join(root, m.group(1))
        rel = os.path.relpath(ex_path, root)
        if not os.path.isfile(src_path):
            errs.append("%s: generated-from source missing: %s" % (rel, m.group(1)))
            continue
        checked += 1
        a, b = cmp_body(ex), cmp_body(read(src_path))
        if a == b:
            continue
        head = ex[:m.end()]
        gap = re.match(r'\n*', ex[m.end():]).group(0) or "\n\n"
        _, src_body = split_fm(read(src_path))
        drift.append((rel, m.group(1),
                      sum(1 for x in a if x not in b) + sum(1 for x in b if x not in a)))
        if apply_:
            with open(ex_path, "w", encoding="utf-8") as fh:
                fh.write(head + gap + src_body.lstrip("\n"))
            fixed.append(rel)

for e in errs:
    print("  ERR   " + e)
for rel, src, d in drift:
    print("  %s %s  <- %s  (body differs by %d line(s))"
          % ("RECOPIED" if apply_ else "DRIFT   ", rel, src, d))
print("recopy: declared copies checked=%d drifted=%d %s"
      % (checked, len(drift), ("recopied=%d" % len(fixed)) if apply_
         else "(dry run - pass --recopy-apply)"))
sys.exit(2 if errs else (0 if (apply_ or not drift) else 1))
RECOPY_PY
  exit $?
fi

fail=0; warn=0
err()  { echo "  FAIL  $*" >&2; fail=$((fail + 1)); }
warn_msg() { [[ $QUIET -eq 0 ]] && echo "  WARN  $*"; warn=$((warn + 1)); }
ok()   { [[ $QUIET -eq 0 ]] && echo "  ok    $*"; }

# Resolve an _essentials artifact name to a real file within the pack (kind drives the dir).
resolves_essential() {  # $1=packdir $2=kind $3=name
  local d="$1" kind="$2" n="$3"
  case "$kind" in
    agents)      [[ -f "$d/agents/$n.md" ]] ;;
    commands)    [[ -f "$d/commands/$n.md" ]] ;;
    rules)       [[ -f "$d/rules/$n.md" ]] ;;
    ai-patterns) [[ -f "$d/ai-patterns/$n.md" ]] ;;
    skills)      [[ -f "$d/skills/$n.md" || -f "$d/skills/$n/SKILL.md" ]] ;;
    *)           return 0 ;;
  esac
}

[[ -d templates/packs ]] || { echo "no templates/packs/ under $REPO_ROOT"; exit 0; }

for d in templates/packs/*/; do
  [[ -d "$d" ]] || continue
  p=$(basename "$d")
  echo "[$p]"

  # 1. sync files present
  miss=0
  for req in _essentials.md _topics.md _version.json; do
    [[ -f "$d$req" ]] || { err "$p: missing $req"; miss=1; }
  done
  [[ $miss -eq 1 ]] && continue

  # 2. _version.json valid + has version
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys; d=json.load(open('$d/_version.json')); sys.exit(0 if d.get('version') else 1)" 2>/dev/null \
      || err "$p: _version.json invalid JSON or missing 'version'"
  else
    grep -q '"version"' "$d/_version.json" || err "$p: _version.json missing 'version'"
  fi

  # 3. every PATH-like _topics fallback resolves, and every NON-path value is the one sentinel
  #    that exists. `stub-from-sections` (templates/phases/phase-4.2-apply.md:26 — the only
  #    definition anywhere in the tree) is the whole legal set; this skip used to accept any value
  #    with no `/` and no `.md`, so `stub-from-section`, `TODO` or any other misspelling read as a
  #    sentinel and passed silently. A topic whose `fallback:` names nothing 4.2 can dispatch on has
  #    NO fallback at all, which is invisible until a no-signal project receives an empty artifact.
  #    Proved by mutation before this arm existed: both typos above exited 0 with
  #    "all _topics fallbacks resolve"; a dangling PATH correctly FAILed, and still does.
  dangling=0
  while IFS= read -r fb; do
    [[ -z "$fb" ]] && continue
    if ! echo "$fb" | grep -qE '/|\.md$'; then
      [[ "$fb" == "stub-from-sections" ]] \
        || { err "$p: _topics fallback strategy '$fb' is not a path and is not the one sentinel \`stub-from-sections\` (defined at templates/phases/phase-4.2-apply.md:26) — nothing dispatches on it, so this topic has no fallback"; dangling=$((dangling + 1)); }
      continue
    fi
    # Dual-accept, symmetric with checks 4 and 6: a `skills/<name>.md` fallback also
    # resolves against the Agent Skills dir-form `skills/<name>/SKILL.md`, so a pack may
    # sit on either form without the fallback pointer having to be rewritten in lockstep.
    { [[ -f "$d$fb" ]] || { [[ "$fb" == skills/* ]] && [[ -f "$d${fb%.md}/SKILL.md" ]]; }; } \
      || { err "$p: _topics fallback does not resolve: $fb"; dangling=$((dangling + 1)); }
    # Anchored at line-start: a `fallback:` key is always its own YAML line, while the prose in
    # these files says things like "the source IS the fallback: both files are ...". The old
    # unanchored grep swept those citations up too; they were harmless only because they contain
    # no `/` and no `.md` and so hit the sentinel skip. Now that a non-path value is a FAIL, the
    # anchor is what keeps a sentence from reading as a declaration. Verified not to change the
    # PATH-like value set on any of the 23 packs — the dangling-path FAIL below is untouched.
  done < <(grep -oE '^[[:space:]]*fallback:[[:space:]]*[A-Za-z0-9._/-]+' "$d/_topics.md" 2>/dev/null | sed 's/^[[:space:]]*fallback:[[:space:]]*//')
  [[ $dangling -eq 0 ]] && ok "$p: all _topics fallbacks resolve"

  # 4. every _essentials array entry resolves
  ess_bad=0
  for kind in agents commands skills rules ai-patterns; do
    line=$(grep -E "^[[:space:]]*${kind}:" "$d/_essentials.md" 2>/dev/null | head -1)
    [[ -z "$line" ]] && continue
    names=$(echo "$line" | sed -E "s/^[[:space:]]*${kind}:[[:space:]]*\[?//; s/\]//; s/,/ /g")
    for n in $names; do
      n=$(echo "$n" | tr -d ' "'"'"'')
      [[ -z "$n" ]] && continue
      resolves_essential "$d" "$kind" "$n" || { err "$p: _essentials $kind '$n' has no artifact"; ess_bad=$((ess_bad + 1)); }
    done
  done
  [[ $ess_bad -eq 0 ]] && ok "$p: all _essentials entries resolve"

  # 5. every artifact FILE has a _topics entry (WARN)
  #    Why this matters beyond bookkeeping: _topics.md is the pack's nucleus. Phase 4.2-AUTHOR
  #    authors an artifact for THIS project only from a topic spec; an artifact the nucleus never
  #    names can still be copied literally by the deterministic Phase 4.2 `cp -R` over
  #    `{agents,commands,skills,rules,ai-patterns}/` (templates/critical-execution-rules.md
  #    § "Rule 3: Phase 4.2 (pack copy) is DETERMINISTIC shell"), so it ships — it just never gets
  #    rewritten in the project's own voice. That silent downgrade from AUTHOR to COPY is the
  #    failure this warn exists to catch, and it is invisible in every other gate.
  #
  #    Classes checked mirror check 8's artifact-class list minus `references/`. Two corrections
  #    to the original `commands agents rules` loop, both measured against the tree before landing:
  #      - `skill` was named in this script's own header contract from the start but never
  #        iterated. Skills live at `skills/<name>/SKILL.md`, so the `*.md` glob below matched
  #        nothing even when `skills` was in the list — hence the separate directory walk. 21 of
  #        23 packs already carry a `kind: skill` topic for every skill dir; the 8 that do not
  #        were unreported drift, not a competing convention.
  #      - `ai-patterns` is added: 103 of 104 shipped ai-patterns already carry a topic entry, and
  #        `kind: pattern` is the first kind the topic schema defines.
  #    `references/` is deliberately NOT checked: 0 of 31 shipped reference files carry a topic
  #    entry, because references are framework docs copied verbatim into `ai/references/`, never
  #    authored from extraction. Adding them would emit 31 warns that no author should act on.
  #
  #    Severity stays WARN for the same reason check 6 gives: pre-existing drift exists, and a
  #    hard FAIL here would red the build before the backfill wave lands.
  for sub in commands agents rules ai-patterns; do
    [[ -d "$d$sub" ]] || continue
    for f in "$d$sub"/*.md; do
      [[ -f "$f" ]] || continue
      n=$(basename "$f" .md)
      case "$n" in _*) continue ;; esac
      grep -qE "^[[:space:]]*-[[:space:]]*name:[[:space:]]*${n}([[:space:]]|$)" "$d/_topics.md" 2>/dev/null \
        || warn_msg "$p: $sub/$n.md has no '- name: $n' entry in _topics.md"
    done
  done
  if [[ -d "${d}skills" ]]; then
    for sk in "${d}skills"/*/SKILL.md; do
      [[ -f "$sk" ]] || continue
      n=$(basename "$(dirname "$sk")")
      case "$n" in _*) continue ;; esac
      grep -qE "^[[:space:]]*-[[:space:]]*name:[[:space:]]*${n}([[:space:]]|$)" "$d/_topics.md" 2>/dev/null \
        || warn_msg "$p: skills/$n/SKILL.md has no '- name: $n' entry in _topics.md"
    done
  fi

  # 6. version-in-changelog (WARN — #SYNC-05). The current top-level `version` SHOULD
  #    be described in the pack's changelog. Two shapes are accepted:
  #      "changelog": "CHANGELOG.md"  — a path relative to the pack dir (the shape all
  #        23 packs use since the release prose moved out of JSON). The file must exist
  #        and carry a `## <version>` heading for the current version.
  #      "changelog": { "<version>": {...} } — the legacy in-JSON object. Still honoured
  #        so an older pack copied in from a previous ~/.claude install validates.
  #    Packs with neither use a different convention (a single `summary:`) — skip them
  #    silently. WARN-only for now; a later wave backfills existing drift (a hard FAIL
  #    here would red the build immediately).
  if command -v python3 >/dev/null 2>&1; then
    chg_status=$(python3 -c "
import json,os,re,sys
try: d=json.load(open('$d/_version.json'))
except Exception: print('skip'); sys.exit(0)
cl=d.get('changelog'); v=d.get('version')
if isinstance(cl,str):
    f=os.path.join('$d',cl)
    if not os.path.isfile(f): print('nofile:'+cl); sys.exit(0)
    t=open(f,encoding='utf-8',errors='replace').read()
    print('ok' if re.search(r'(?m)^##[ \t]+'+re.escape(str(v))+r'\b',t) else 'drift:'+str(v))
elif isinstance(cl,dict):
    print('ok' if v in cl else 'drift:'+str(v))
else:
    print('skip')
" 2>/dev/null)
    case "$chg_status" in
      drift:*) warn_msg "$p: _version.json version '${chg_status#drift:}' has no matching changelog entry — add a '## ${chg_status#drift:}' section to the pack CHANGELOG.md" ;;
      nofile:*) warn_msg "$p: _version.json changelog points at '${chg_status#nofile:}' but no such file exists in the pack" ;;
      ok)      ok "$p: _version.json version present in changelog" ;;
      *)       : ;;  # skip / no changelog convention
    esac
  fi

  # 7. rule_references resolve (WARN — #SYNC-05). _essentials.md may carry a
  #    `rule_references: [name, ...]` array; each name ships as references/<name>.md
  #    alongside the rule (on-demand load). Warn on any that does not resolve.
  rr_line=$(grep -E "^[[:space:]]*rule_references:" "$d/_essentials.md" 2>/dev/null | head -1)
  if [[ -n "$rr_line" ]]; then
    rr_names=$(echo "$rr_line" | sed -E 's/^[[:space:]]*rule_references:[[:space:]]*\[?//; s/\].*//; s/#.*//; s/,/ /g')
    for rn in $rr_names; do
      rn=$(echo "$rn" | tr -d ' "'"'"'')
      [[ -z "$rn" ]] && continue
      [[ -f "$d/references/$rn.md" ]] \
        || warn_msg "$p: _essentials rule_references '$rn' has no references/$rn.md"
    done
  fi

  # 8a. ORPHANED example (WARN — #SYNC-05). Presence only: does a source artifact with
  #    this basename still exist somewhere in the pack (renamed / removed)? When a
  #    `generated-from:` header is present, resolve that exact path instead (more
  #    precise provenance).
  #
  #    This used to be the WHOLE of check 8, and its old comment said "so we do NOT diff
  #    content" — pointing at a `project_examples_are_abridged` note that does not exist
  #    anywhere in the repo. Presence-only was not a considered position, it was a
  #    dangling justification, and it cost real correctness: commit f2f0ccd deleted a
  #    fabricated "10-50k connections per Node process" from
  #    backend/agents/websocket-engineer.md and the identical sentence survived in
  #    backend/_examples/websocket-engineer.md — the file a project actually receives —
  #    until a human noticed it by hand two commits later (a909ac2).
  #
  #    Content is now checked, by CLASS of claim rather than by diff: see 8b below. This
  #    check keeps its original job (a fallback with no source at all) because it is the
  #    one part of check 8 that works without python3.
  if [[ -d "${d}_examples" ]]; then
    for ex in "${d}_examples"/*.md; do
      [[ -f "$ex" ]] || continue
      gen=$(grep -m1 -oE 'generated-from:[[:space:]]*[A-Za-z0-9._/-]+' "$ex" 2>/dev/null | sed 's/generated-from:[[:space:]]*//')
      if [[ -n "$gen" ]]; then
        [[ -f "$gen" || -f "$REPO_ROOT/$gen" ]] \
          || warn_msg "$p: _examples/$(basename "$ex") generated-from source missing: $gen"
        continue
      fi
      exn=$(basename "$ex" .md)
      ex_found=0
      for sub in commands agents skills rules ai-patterns references; do
        if [[ -f "$d$sub/$exn.md" || -f "$d$sub/$exn/SKILL.md" ]]; then ex_found=1; break; fi
      done
      [[ $ex_found -eq 1 ]] \
        || warn_msg "$p: _examples/$exn.md has no matching source artifact in the pack (orphaned example — source renamed/removed?)"
    done
  fi
done

# ---------------------------------------------------------------------------------------------
# 3b. FALLBACK STRATEGY INTEGRITY (FAIL on anything not ledgered) — repo-wide, runs once after the
#     per-pack loop because it needs each topic's `kind:`, `sections:` and the pack's artifact tree
#     together. Check 3 above asks whether a `fallback:` VALUE resolves. This asks whether the
#     STRATEGY it names can deliver anything.
#
#     WHY THIS IS A GATE. `templates/phases/phase-4.2-apply.md:26` is the only place in the tree
#     that defines the sentinel: "the literal `stub-from-sections`, which emits a sectioned stub
#     from that topic's `sections:` list". There is no skeleton template and no second definition.
#     With NO `sections:` key that list is empty, so the emitter has nothing to emit and a
#     no-signal project receives an EMPTY FILE. Nothing downstream rescues it:
#     `phase-4.0-preflight.md:495-510` measures the PACK SOURCE (`~/.claude/templates/packs/...`),
#     never the emitted file; `:561` counts FILES, and a 0-byte file counts as present;
#     `phase-5-verify.md:185-220` covers only the foundational `ai/` set and says so at :187;
#     `grep -n "wc -l" templates/phases/phase-5-verify.md` returns nothing. So the emitted artifact's
#     size is measured nowhere, and this is the last place the defect is visible.
#
#     THE DEFECT HAS RECURRED FIVE TIMES, hand-repaired each time and never gated:
#     security (CHANGELOG:87), infrastructure (CHANGELOG:106), distributed-systems, then all 8
#     skill topics across data-engineering and finops in one batch, then observability's four
#     (`add-metrics`, `add-tracing`, `alert-design`, `slo-audit` — 855 finished lines on disk that
#     the topics were refusing to deliver), repaired in the same commit that armed this check.
#     Note also that declaring the sentinel is strictly WORSE than omitting `fallback:` entirely
#     when a source exists: per phase-4.2-apply.md:26 a topic with NO `fallback:` falls through to
#     `_examples/<topic>.md`, then to the closest template in the pack, and only THEN to a stub.
#     The sentinel opts the topic OUT of the chain that would have found the finished file.
#
#     TWO RULES, and the split is the judgement/no-judgement line:
#       STUB-NO-SECTIONS (FAIL, never ledgerable) — the sentinel with no `sections:` key. It cannot
#         emit anything, by the only definition that exists. There is no legitimate instance, so
#         there is nothing for a reader to decide and nothing to suppress. 0 today.
#       STUB-OVER-SOURCE (FAIL if new, ledgered) — the sentinel where a finished artifact of the
#         same kind+name already ships in the pack. A heading skeleton lands where 1,196 + 133
#         lines sit unused. This one IS a judgement call — a pack may genuinely prefer a neutral
#         skeleton to a generic file — so it takes the reasoned-ledger ratchet, not a blanket FAIL.
#         6 today (infrastructure 5, testing 1), each with a reason in the ledger. backend's 9
#         sentinel topics never fire here: no shipped source exists for any of them
#         (`backend/_topics.md:26` documents that on purpose), which is exactly the discrimination
#         a per-pack exception list would have destroyed.
#
#     COVERAGE IS REPORTED, NOT GATED (`--coverage-report`). Measured survival of pack content to a
#     no-signal project was quoted three ways during review — `product` 20% (a LINE ratio),
#     `finops` ~31% (a TOPIC ratio), `algorithms` 91% (line again) — two denominators behind three
#     figures, so "the reported figure" was never one metric. Neither is gateable. The line ratio
#     inverts against harm: `ai-engineering` is second-worst at 50% with ZERO zero-delivery topics
#     (the whole gap is intentional abridgement), while `observability` sat mid-table at 72% with
#     four topics delivering an EMPTY file. Gating the percentage red-flags the healthy pack and
#     waves through the broken one. `templates/packs/_fallback-baseline.md` § "Not in the ratchet,
#     deliberately" already made this exact call for length ratio ("no threshold discriminates").
#     WHAT IS GATED IS THE COUNT, and it is gated in templates/packs/_greenfield-budget.md — a
#     per-pack number that may not GROW, regenerated with `--record-budget`, exactly the mechanism
#     scripts/check-rule-budget.sh runs against scripts/_rule-budget-baseline.txt. This sentence
#     used to claim the count was gated when nothing gated it: a topic declaring `sections:` with
#     no artifact of that name fires NEITHER rule above, so appending two of them to a pack moved
#     its coverage row from `zero 0 / 100%` to `zero 2 / 90%` while the gate printed `0 new` and
#     exited 0 — Hole 3's stated failure mode verbatim, under a comment saying it was closed.
#     The count is padding-proof where the percentage is not: nothing you ADD lowers it. Its
#     ceiling is per-pack granularity (repair one topic, regress another in the same pack, net
#     zero), stated in the budget file. The percentages remain available for review.
if command -v python3 >/dev/null 2>&1; then
  st_out=$(mktemp); st_err=$(mktemp)
  if python3 - "$REPO_ROOT" $ST_REPORT $ST_RECORD $BUDGET_RECORD >"$st_out" 2>"$st_err" <<'PYST'
import os, re, sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = sys.argv[1]
ARGS = sys.argv[2:]
REPORT = "--report" in ARGS
RECORD = "--record" in ARGS
REC_BUDGET = "--record-budget" in ARGS
PACKS = os.path.join(ROOT, "templates/packs")
LEDGER_REL = "templates/packs/_topics-strategy-baseline.md"
LEDGER = os.path.join(ROOT, LEDGER_REL)
BUDGET_REL = "templates/packs/_greenfield-budget.md"
BUDGET = os.path.join(ROOT, BUDGET_REL)
BUDGET_SECTION = "Zero-delivery topics"
SENTINEL = "stub-from-sections"
RULES = {"STUB-OVER-SOURCE"}
# STUB-NO-SECTIONS is deliberately NOT ledgerable: it names a strategy that cannot emit anything,
# so "someone read it and decided it is correct" is not a state that exists. A line claiming to
# suppress it WARNs instead of suppressing.
UNLEDGERABLE = {"STUB-NO-SECTIONS"}
KIND_DIR = {"pattern": "ai-patterns", "ai-pattern": "ai-patterns", "ai-patterns": "ai-patterns",
            "command": "commands", "agent": "agents", "rule": "rules", "convention": "rules",
            "skill": "skills", "reference": "references"}
ARTS = ("agents", "commands", "rules", "ai-patterns", "skills")
# The ledger states its own size in prose. That is a claim a file makes about ITSELF, decidable by
# counting the file, and 8b's header comment drifted for exactly this reason — it still advertised
# a 2-line backlog after the file reached zero. lint-handoffs.sh:661-670 solved it the same way.
ADVERT = re.compile(r'ledger is\s+\**(\d+)\**\s+entr')


def read(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def nlines(p):
    t = read(p)
    return len(t.splitlines()) if t else 0


def topics(packdir):
    """Every topic in a pack's _topics.md: name, kind, fallback VALUE, HOW MANY sections it
    declares, and the line it starts on. The `fallback:` value is captured with the same
    character class check 3 greps with, so a trailing `# comment` never becomes part of it.

    `sections` is a COUNT, not a flag, and that is the whole point: the emitter builds the stub
    FROM the list, so `sections: []` and a bare `sections:` with nothing under it emit exactly
    what a missing key emits — an EMPTY FILE. A presence test would have called both of those
    compliant while the finding text says an empty list emits nothing, which is the check
    contradicting itself. Both YAML spellings the corpus uses are counted: the inline flow list
    (`sections: [a, b]`, 344 topics) and the block list (`sections:` + `    - a`, 9 topics —
    align/_topics.md:21, backend/_topics.md:248, migration/_topics.md:21 among them)."""
    rows, cur, insec = [], None, None
    for i, line in enumerate(read(os.path.join(packdir, "_topics.md")).splitlines(), 1):
        m = re.match(r'^\s*-\s+name:\s*([A-Za-z0-9._-]+)', line)
        if m:
            cur = {"name": m.group(1), "kind": None, "fb": None, "sections": 0, "line": i}
            rows.append(cur)
            insec = None
            continue
        if cur is None:
            continue
        if insec is not None:
            # block-list continuation: `    - item` until the next key or a blank-line break
            if re.match(r'^\s*-\s+[A-Za-z0-9_]', line):
                insec["sections"] += 1
                continue
            if line.strip() and not line.lstrip().startswith("#"):
                insec = None
        m = re.match(r'^\s*kind:\s*([A-Za-z0-9._-]+)', line)
        if m:
            cur["kind"] = m.group(1)
            continue
        m = re.match(r'^\s*fallback:\s*([A-Za-z0-9._/-]+)', line)
        if m:
            cur["fb"] = m.group(1)
            continue
        m = re.match(r'^\s*sections:\s*(.*)$', line)
        if m:
            rest = m.group(1).split("#", 1)[0].strip()
            if rest.startswith("["):
                cur["sections"] = len([x for x in rest.strip("[]").split(",") if x.strip()])
                insec = None
            else:
                insec = cur          # bare `sections:` — count the block list that follows
    return rows


def source_for(packdir, kind, name):
    """The finished artifact this topic's own `kind:` says it is — the file a sentinel is
    standing in front of. Returns a pack-relative path or None."""
    sub = KIND_DIR.get(kind or "")
    if sub == "skills":
        for c in ("skills/%s/SKILL.md" % name, "skills/%s.md" % name):
            if os.path.isfile(os.path.join(packdir, c)):
                return c
    elif sub:
        c = "%s/%s.md" % (sub, name)
        if os.path.isfile(os.path.join(packdir, c)):
            return c
    return None


def resolves(packdir, fb):
    if os.path.isfile(os.path.join(packdir, fb)):
        return fb
    if fb.startswith("skills/") and fb.endswith(".md") \
       and os.path.isfile(os.path.join(packdir, fb[:-3], "SKILL.md")):
        return fb[:-3] + "/SKILL.md"
    return None


def load_ledger():
    """Same contract as templates/packs/_fallback-baseline.md and scripts/_handoff-baseline.md:
    a line MUST carry a trailing `# reason` or it suppresses nothing."""
    keep, unreasoned, bogus = set(), [], []
    text = read(LEDGER)
    for line in text.splitlines():
        m = re.match(r'^([a-z0-9][a-z0-9-]*/[A-Za-z0-9._-]+)[ \t]+([A-Z][A-Z-]+)[ \t]*(#.*)?$',
                     line.strip())
        if not m:
            continue
        key, rule, reason = m.group(1), m.group(2), (m.group(3) or "").strip("# \t")
        if rule in UNLEDGERABLE:
            bogus.append((key, rule))
        elif rule not in RULES:
            bogus.append((key, rule))
        elif reason:
            keep.add((key, rule))
        else:
            unreasoned.append((key, rule))
    m = ADVERT.search(text)
    return keep, unreasoned, bogus, (int(m.group(1)) if m else None)


# ---- the greenfield budget: a per-pack COUNT that may not GROW. Same mechanism as
# scripts/check-rule-budget.sh + scripts/_rule-budget-baseline.txt, and here for the same reason:
# the harm this measures is real but the RIGHT LEVEL of it is a judgement no repo-wide threshold
# can carry, while "more than yesterday" is exact. An ABSENT file or section is not an off switch —
# every pack then reads as budget 0, so deleting the budget turns every existing zero-delivery
# topic RED rather than turning the check off.
def budget_rows(section):
    m = re.search(r'(?ms)^##\s+' + re.escape(section) + r'\b.*?\n```\n(.*?)\n```', read(BUDGET))
    rows = {}
    if m:
        for line in m.group(1).splitlines():
            mm = re.match(r'^([a-z0-9][a-z0-9-]*)[ \t]+(\d+)$', line.strip())
            if mm:
                rows[mm.group(1)] = int(mm.group(2))
    return rows


def budget_record(section, counts):
    """Rewrite one section's fenced block in place, leaving every other section untouched — the
    3b and 8b blocks are separate programs recording into the same file in one run."""
    body = "\n".join("%-24s %d" % (p, n) for p, n in sorted(counts.items()) if n) or "(none)"
    text = read(BUDGET)
    new, n = re.subn(r'(?ms)(^##\s+' + re.escape(section) + r'\b.*?\n```\n).*?(\n```)',
                     lambda mm: mm.group(1) + body + mm.group(2), text, count=1)
    if n:
        open(BUDGET, "w", encoding="utf-8").write(new)
    return n


findings, packrows, n_topics, n_stub = [], [], 0, 0

for p in sorted(os.listdir(PACKS)):
    pd = os.path.join(PACKS, p)
    if not os.path.isdir(pd) or not os.path.isfile(os.path.join(pd, "_topics.md")):
        continue
    declared = zero = zero_with_src = delivered = 0
    for t in topics(pd):
        n_topics += 1
        fb, key = t["fb"], p + "/" + t["name"]
        if fb is None:
            continue          # `kind: reference-pair` — deliberately never installed
                              # (align/_topics.md:96 cites phase-4.2-apply.md:210-213)
        declared += 1
        if fb != SENTINEL:
            r = resolves(pd, fb)
            if r:
                delivered += nlines(os.path.join(pd, r))
            continue
        n_stub += 1
        zero += 1
        src = source_for(pd, t["kind"], t["name"])
        if src:
            zero_with_src += 1
        if not t["sections"]:
            findings.append((key, "STUB-NO-SECTIONS",
                             "_topics.md:%d declares `fallback: %s` with no NON-EMPTY `sections:` "
                             "list (missing key, `sections: []`, or a bare `sections:` with no "
                             "items under it are all the same thing here). phase-4.2-apply.md:26 "
                             "builds the stub FROM that list, so an empty list emits an EMPTY "
                             "FILE%s. Point `fallback:` at the source, or declare the sections."
                             % (t["line"], SENTINEL,
                                " while %s (%d lines) sits beside it on disk"
                                % (src, nlines(os.path.join(pd, src))) if src else "")))
        elif src:
            findings.append((key, "STUB-OVER-SOURCE",
                             "_topics.md:%d declares `fallback: %s` while %s (%d lines) ships in "
                             "this pack. A no-signal project gets the heading skeleton and none of "
                             "that content."
                             % (t["line"], SENTINEL, src, nlines(os.path.join(pd, src)))))
    pack_lines = 0
    for sub in ARTS:
        for dirpath, _d, files in os.walk(os.path.join(pd, sub)):
            for f in files:
                if f.endswith(".md") and f != "README.md":
                    pack_lines += nlines(os.path.join(dirpath, f))
    packrows.append((p, declared, zero, zero_with_src, pack_lines, delivered))

# ---- GREENFIELD BUDGET (Hole 3). A zero-delivery topic is one whose `fallback:` is the sentinel:
# whatever else it declares, a no-signal project receives headings and no content for it. Two of
# the three shapes that produces are gated exactly above (STUB-NO-SECTIONS, STUB-OVER-SOURCE); the
# THIRD — a sentinel with a `sections:` list and NO artifact of that name anywhere — fires neither,
# which is how a pack could add unlimited zero-delivery topics and stay green. PROVEN before this
# block existed: appending two topics with `sections: [overview, pitfalls]` + the sentinel to
# observability/_topics.md moved its coverage row from `topics 19 / zero 0 / 100%` to
# `topics 21 / zero 2 / 90%`, and the gate still printed `0 new` and exited 0.
# THE COUNT IS GATED AND THE PERCENTAGE IS NOT, deliberately. The percentage inverts against harm
# (ai-engineering reads 100% topic / 49% line with ZERO zero-delivery topics; observability read
# 72% while four of its topics delivered an empty file) and it is movable by padding a pack with
# delivering topics. The count is not: nothing you ADD lowers it, and the only way down is to make
# a topic deliver.
# CEILING, STATED: the budget is per PACK, so repairing one topic and regressing another inside the
# SAME pack nets to zero and stays green. That is the same ceiling check-rule-budget.sh accepts.
zero_now = {p: z for p, declared, z, zsrc, pl, dl in packrows}
if REC_BUDGET:
    if budget_record(BUDGET_SECTION, zero_now):
        print("I\tgreenfield budget: recorded %d pack(s) carrying zero-delivery topics -> %s"
              % (len([1 for v in zero_now.values() if v]), BUDGET_REL))
    else:
        print("F\t%s has no `## %s` section with a fenced block to record into — create it or "
              "restore it from git; an absent budget reads as 0 for every pack."
              % (BUDGET_REL, BUDGET_SECTION))
else:
    zb = budget_rows(BUDGET_SECTION)
    for p in sorted(zero_now):
        cur, rec = zero_now[p], zb.get(p, 0)
        if cur > rec:
            print("F\t%s: %d zero-delivery topic(s), %d more than the recorded budget of %d. A "
                  "topic whose `fallback:` is `%s` hands a no-signal project headings and no "
                  "content. Make the new topic(s) deliver (point `fallback:` at the artifact that "
                  "ships), or record the new level deliberately with `--record-budget` (%s)."
                  % (p, cur, cur - rec, rec, SENTINEL, BUDGET_REL))
        elif cur < rec:
            print("W\t%s: %d zero-delivery topic(s), below its recorded budget of %d — re-record "
                  "with `--record-budget` so the ratchet keeps the ground it gained (%s)"
                  % (p, cur, rec, BUDGET_REL))

# ---- RECORD: regenerate the ledger's entry block from what reproduces NOW. Reasons already
# written are carried over verbatim; a NEWLY recorded entry is emitted with no reason, which
# suppresses nothing and stays red until a human writes one. That is deliberate — a --record that
# could silence an unread finding is the mute button this whole ratchet exists to prevent.
if RECORD:
    prev = {}
    for line in read(LEDGER).splitlines():
        m = re.match(r'^([a-z0-9][a-z0-9-]*/[A-Za-z0-9._-]+)[ \t]+([A-Z][A-Z-]+)[ \t]*(#.*)?$',
                     line.strip())
        if m:
            prev[(m.group(1), m.group(2))] = (m.group(3) or "").rstrip()
    entries = sorted({(k, r) for k, r, _ in findings if r in RULES})
    body = "\n".join("%-34s %-16s %s" % (k, r, prev.get((k, r), "#"))
                     for k, r in entries) or "(empty)"
    text = read(LEDGER)
    new = re.sub(r'(?s)(## Ledger\n\n```\n).*?(\n```)', lambda mm: mm.group(1) + body + mm.group(2),
                 text, count=1)
    new = ADVERT.sub(lambda _m: "ledger is %d entr" % len(entries), new, count=1)
    open(LEDGER, "w", encoding="utf-8").write(new)
    print("I\tstrategy ledger: recorded %d entr%s -> %s (a new line carries no reason and "
          "therefore suppresses nothing until one is written)"
          % (len(entries), "y" if len(entries) == 1 else "ies", LEDGER_REL))

base, unreasoned, bogus, advertised = load_ledger()
for key, rule in sorted(unreasoned):
    print("W\tledger line `%s  %s` carries no `# reason` — it suppresses nothing until it does (%s)"
          % (key, rule, LEDGER_REL))
for key, rule in sorted(bogus):
    print("W\tledger line `%s  %s` names a rule this ledger does not ratchet%s — it suppresses "
          "nothing (%s)" % (key, rule,
                            " (STUB-NO-SECTIONS is a hard FAIL by design)"
                            if rule in UNLEDGERABLE else "", LEDGER_REL))
# THE SENTENCE ITSELF IS NOW MANDATORY. Checking the number only when a number is present made the
# check cheaper to DELETE than to correct: replacing `**The ledger is 5 entries.**` with any other
# text returned EXIT=0 and no finding. That is the failure mode this self-check exists for — the
# sentence went stale once already — so an existing ledger with no advertised count is a FAIL.
# A ledger file that does not exist at all is still not checked: 3b's fixture packs ship without
# one, and a MISSING ledger already fails safe by un-suppressing every entry it used to hold.
if read(LEDGER).strip() and advertised is None:
    print("F\t%s exists but advertises no entry count. The `**The ledger is N entries.**` sentence "
          "is the file's contract with every comment that cites it, and it is checked on every run "
          "— restore it rather than deleting it, or the next reader is sent to a worklist nobody "
          "can size." % LEDGER_REL)
if advertised is not None:
    n_entries = len(base) + len(unreasoned)
    if advertised != n_entries:
        print("F\t%s advertises a %d-entry ledger but %d parse. Either the sentence is stale or "
              "the file was read short — a truncated ledger un-suppresses its missing entries, "
              "which reads as defects going red with nothing naming the cause."
              % (LEDGER_REL, advertised, n_entries))

seen, new_f, known = set(), [], []
for key, rule, detail in findings:
    seen.add((key, rule))
    (known if (key, rule) in base else new_f).append((key, rule, detail))

for key, rule, detail in new_f:
    p, n = key.split("/", 1)
    print("F\t%s: _topics %s [%s] %s" % (p, n, rule, detail))
for key, rule in sorted(base - seen):
    print("W\t`%s  %s` no longer reproduces — drop its line from %s" % (key, rule, LEDGER_REL))
if known:
    print("W\t%d known fallback-strategy defect(s) suppressed by %s (repair backlog; "
          "--coverage-report lists them)" % (len(known), LEDGER_REL))
if REPORT:
    for key, rule, detail in sorted(known):
        print("R\tledgered   %-34s [%s] %s" % (key, rule, detail))
    print("R\t")
    print("R\tGREENFIELD COVERAGE. 'zero' = topics whose fallback delivers no content; 'src' = of "
          "those, how many have a finished artifact on disk. THE TWO PERCENTAGES ARE REPORTED AND "
          "NEVER GATED — no threshold in the measured distribution separates defect from deliberate "
          "abridgement, and the line ratio inverts against harm. THE 'zero' COLUMN IS GATED, per "
          "pack, against %s: it may not grow. Regenerate with --record-budget." % BUDGET_REL)
    print("R\t%-22s %6s %6s %5s %8s %8s" % ("pack", "topics", "zero", "src", "topic-%", "line-%"))
    for p, declared, zero, zsrc, pl, dl in sorted(packrows, key=lambda r: (-r[2], r[0])):
        print("R\t%-22s %6d %6d %5d %7d%% %7d%%"
              % (p, declared, zero, zsrc,
                 round(100.0 * (declared - zero) / declared) if declared else 100,
                 round(100.0 * dl / pl) if pl else 100))
print("I\tfallback strategy: %d topics across %d packs, %d declare `%s`, %d new, %d ledgered"
      % (n_topics, len(packrows), n_stub, SENTINEL, len(new_f), len(known)))
if new_f:
    print("H\t^ point `fallback:` at the artifact that already ships, or — for STUB-OVER-SOURCE "
          "only, and only if a neutral skeleton is genuinely the better delivery — add "
          "`<pack>/<topic>  STUB-OVER-SOURCE  # reason` to " + LEDGER_REL)
PYST
  then
    while IFS=$'\t' read -r st_tag st_msg; do
      case "$st_tag" in
        F) err "$st_msg" ;;
        W) warn_msg "$st_msg" ;;
        R) [[ $QUIET -eq 0 ]] && echo "        $st_msg" || true ;;
        I) ok "$st_msg" ;;
        H) echo "  $st_msg" >&2 ;;
      esac
    done < "$st_out"
  else
    err "fallback strategy (check 3b) did not run: $(head -3 "$st_err" | tr '\n' ' ')"
  fi
  rm -f "$st_out" "$st_err"
else
  warn_msg "fallback strategy (check 3b) skipped — python3 not found"
fi
if [[ -n "$ST_RECORD" ]]; then
  echo ""
  echo "pack-consistency: strategy ledger recorded — re-run without --record-strategy to gate"
  [[ $fail -gt 0 ]] && exit 1
  exit 0
fi

# ---------------------------------------------------------------------------------------------
# 8b. FALLBACK INTEGRITY (FAIL on anything not baselined) — repo-wide, runs once after the
#     per-pack loop because source resolution needs `_topics.md` and dangling-dispatch resolution
#     needs every pack at once.
#
#     WHY THIS IS A GATE AND NOT A NOTE. `templates/phases/phase-4.2-apply.md § 4.2-AUTHOR
#     step 2` copies `_examples/<topic>.md` VERBATIM into a project when extraction has no signal
#     for that topic; the "No-thinning rule" in that file's `§ Rules` ("pack files are copied
#     verbatim") and its `§ 4.2-AUTHOR` Output line (same destination paths as COPY mode) mean the
#     fallback IS the artifact the project receives — for greenfield, for --lightweight, and for
#     every `[EXTRACTION-WEAK]` track that `phase-4.0-preflight.md § Minimum artifacts per
#     LOAD-BEARING track` routes to COPY.
#     287 of 297 examples are named as a live `fallback:` in a `_topics.md`. The pack-depth floor
#     (`phase-4.0-preflight.md` preflight check 6, per-kind no-thin-stub floor) does not reach
#     them (its `find` predicates are keyed on
#     `*/agents/*`, `*/commands/*`, `*/rules/*`, `*/skills/*/SKILL.md` — `_examples/` matches none,
#     correctly, since 135 of 297 are under 100 lines). Nothing else measures them.
#
#     WHAT THIS CHECK DOES NOT CATCH — read this before trusting a green run. Every rule below
#     compares the fallback's TEXT against the source's TEXT. None of them understands either
#     file, so a SOURCE-side edit that silently invalidates a fallback is invisible here whenever
#     it leaves no textual trace in the fallback:
#       * a source RETRACTS a non-numeric rule (a Hard-rules bullet deleted) and the fallback goes
#         on asserting it — 0 findings;
#       * a source REVERSES a polarity (MUST -> MUST NOT) and the fallback keeps the old sense —
#         0 findings;
#       * a fallback asserts a magnitude with no framing word and no claim-shaped unit
#         ("200000 concurrent sockets per process") — the TH/UB regexes below do not fire;
#       * a fallback invents a non-dispatch instruction (an API that does not exist, an RFC number)
#         — nothing resolves those.
#     What IS caught is enumerated rule by rule below, and the two ends were re-proved on a scratch
#     tree: reintroducing the f2f0ccd defect (a fabricated `10-50k connections per Node process` in
#     the fallback, source silent) FAILS, and a machine-cut abridgement of
#     backend/agents/api-architect.md at 46% of source length (218 -> 100 lines) keeping only the
#     load-bearing band + safety blocks passes with 0 findings. Treat this check as a floor on
#     fallback integrity, never as a certificate that a fallback still says what its source says.
#     Re-cutting the fallback is still the pack author's job; this only makes some of the failures
#     to do so mechanical.
#
#     THE HARD PART, and the reason most of the obvious rules are absent. `_examples/` files are
#     DELIBERATELY ABRIDGED: 29 of 293 are under 40% of their source's length and 135 of 297 are
#     under 100 lines. Measured over all 293 pairs, every rule that compares a fallback against an
#     IDEAL is useless — "any missing H2" flags 221 (75%), "missing Related" 138 (47%),
#     "frontmatter key-set equality" 126 (43%), `kind:` value equality 133 (45%), and NO size-ratio
#     threshold discriminates at all: ratios span 22% (database/full-text-search, 33 vs 153 lines)
#     to 137% (distributed-systems/outbox, 100 vs 73), the correlation is inverted —
#     frontend/seo-audit is textbook-legitimate at 25% (47 vs 190) while BOTH files that still
#     carry a baselined defect sit at or above parity (documentation/slo 101%,
#     migration/migration-discipline 112%). A gate that flags half the corpus gets muted, and a
#     muted gate is worse than none. So this check never diffs prose and never looks at length,
#     with ONE exception that is not a judgement call: byte-equality (UNDECLARED-COPY, below).
#     It asks three questions:
#
#       (1) does the fallback ASSERT something its source does not?  (COPY-DRIFT,
#           UNSOURCED-MAGNITUDE, DANGLING-DISPATCH, FRONTMATTER-LOSS `model:`)
#       (2) did it drop something the corpus itself keeps >=85% of the time, or a safety signal?
#           (SECTION-LOSS, SECTION-ORDER, SIGNAL-LOSS, FRONTMATTER-LOSS `description:`/`name:`)
#       (3) is it secretly not an abridgement at all?  (UNDECLARED-COPY)
#
#     The >=85% band is derived, not assumed, and `LOADBEARING` below is the WHOLE band — every
#     heading meeting the criterion, with nothing hand-picked out of it. Criterion: per-heading
#     retention (normalised, H2 in the source vs H2-or-H3 in the fallback) over headings appearing
#     in >=8 sources.
#
#     WHAT THE BAND STRUCTURALLY CANNOT SEE, stated because this paragraph otherwise reads as if
#     the derivation looked at every heading, and it did not. (1) IT READS SOURCE H2s ONLY. A
#     shape the corpus writes as an H3 in the SOURCE can never enter the band at any retention —
#     which is exactly what happened to the sibling-boundary block: 70+ of the 77 agent sources
#     write it `### Sibling agents in <pack> pack`, so it was never in the sample despite retaining
#     at 96%. (2) `norm_h` does not collapse a trailing " in <pack> pack", so even as an H2 that
#     shape would have fragmented into 21 distinct normalised headings of n<=7, all under the n>=8
#     floor. Both are properties of the derivation, not verdicts on the shape. A shape in that
#     blind spot is gated as a BLOCK instead (BOUNDARY-LOSS below), the same treatment
#     `Halt conditions` gets at 40% heading retention. The blind spot was searched for other H3-only
#     shapes clearing >=85% at n>=8 and none was found, so this is a correction to the record rather
#     than a second open gap — but re-derive from source H2s AND H3s if the band is ever re-cut.
#
#     MEASURED ON THE PRE-REPAIR CORPUS — `git archive a909ac2`, 292 pairs — and that basis is
#     deliberate, not incidental. a909ac2 is the last state in which each fallback's abridgement
#     was an INDEPENDENT decision by its pack author. Re-deriving the band from a repaired corpus
#     would be circular: every repair raises retention, a higher retention widens the band, a wider
#     band demands more repairs, and the fixed point is "the fallback keeps everything" — which is
#     the abridgement premise abolished by arithmetic rather than by argument. Post-repair the 36
#     band headings all sit at 100%, which is a consequence of the repairs, NOT evidence for the
#     band. Re-derive only from a corpus that has not been repaired against this gate.
#
#     Kept 85-100% and therefore GATED (n, retention): Output (144, 94%), Hard rules (67, 90%),
#     Failure modes (60, 97%), Forbidden (49, 96%), When to use (49, 98%), When to use / NOT to use
#     (38, 100%), Procedure (40, 85%), Output format (30, 93%), References (28, 96%), Phases
#     applied (27, 96%), Invariants (24, 100%), Prerequisites (24, 92%), Must / Must not / Should
#     (20 each, 100%), Enforcement (20, 85%), Review checklist (19, 100%), Method (17, 88%),
#     Context (14, 100%), Scans for (13, 92%), Common mistakes (12, 100%), Rules (12, 100%),
#     Anti-patterns (11, 100%), When NOT to use (11, 91%), Checklist (11, 91%), Inputs (9, 89%),
#     Observability (8, 100%), Migration path (8, 100%), Testing (8, 100%), and the Phase 1-7
#     skeleton (41-43 each, 93-100%). Procedure and Enforcement sit exactly ON 85% and are IN —
#     ">=85%" is the published rule and excluding what lands on the boundary is how a derived band
#     quietly becomes a hand-picked one.
#
#     Below the band and therefore NOT gated as sections: Detectors 72% (53), Pre-flight 69% (73),
#     Boundary 67% (9), Example findings 56% (27), Adapt to the codebase 53% (32), False positives
#     / gotchas 45% (53), When to run 38% (39), Related 36% (217), Red flags 17% (12), What to do
#     next 8% (12), Closure verbs 8% (24). Halt conditions 40% (82), Premise 31% (70) / "The
#     Premise ..." 13% (105) and Mechanical halt 0% (14) are also below it — they are gated
#     instead by SIGNAL-LOSS, which matches the BLOCK rather than the heading spelling, so a
#     fallback that renames `## Halt conditions` to `## Halt` still satisfies it. The corpus voted
#     on what abridgement means; this gate enforces that vote instead of overruling it.
#
#     SOURCE RESOLUTION IS NOT check 8a's. 8a walks `commands agents skills rules ai-patterns
#     references` and takes the first basename hit, which mis-pairs 3 examples: frontend/i18n
#     (kind: pattern -> ai-patterns/i18n.md, not rules/i18n.md), security/secret-scan and
#     security/threat-model (kind: skill -> skills/<n>/SKILL.md, not commands/<n>.md). Diffing
#     against the wrong artifact is how a content gate manufactures false positives, so 8b
#     resolves through the `_topics.md` entry whose `fallback:` names the example, and falls back
#     to the 8a walk only for the 8 examples no topic declares.
#
#     RATCHET. Known violations are listed in templates/packs/_fallback-baseline.md and suppressed
#     to a single counted WARN; a violation NOT listed there is a hard FAIL. The backlog is now
#     ZERO — the last two entries (documentation/slo SECTION-ORDER and
#     migration/migration-discipline UNSOURCED-MAGNITUDE) were retired 2026-08-23, not muted but
#     made not to fire. A baseline line with NO reason suppresses nothing (see `load_baseline`),
#     and repairing a file means deleting its line — a line that no longer reproduces WARNs — so
#     the baseline cannot rot into a mute button.
#     THIS COUNT IS NO LONGER ON TRUST. Both this paragraph and the baseline file's own "the
#     backlog is N lines" sentence went stale the day it reached zero, which is how a comment sends
#     a reader to a worklist that is not there. `ADVERT` + `load_baseline` now parse that sentence
#     and FAIL when it disagrees with the entries that actually parse — the same self-check
#     scripts/lint-handoffs.sh:661-670 runs on its own ledger, added for the same reason.
#
#     THE SAFETY-SIGNAL CLASS IS NOW GATED, and the history matters. When 8b first landed, 227 of
#     292 fallbacks (78%) dropped a `> **Hard rule:` line, a halt block, a `## Premise`, or an
#     agent TRIGGER clause their source carried, and it shipped as a counted WARN on the stated
#     grounds that at 78% it "cannot separate abridgement from drift". The repair pass then closed
#     all 227. That outcome refutes the grounds: every one of them was repairable drift, not
#     abridgement, so the class discriminates perfectly and always did. At 0 of 293 the gate costs
#     nothing to arm and closes the regression path, so SIGNAL-LOSS below is a FAIL like the rest.
#     A pack that genuinely must drop a signal baselines it with a reason, same as any other rule.
if command -v python3 >/dev/null 2>&1; then
  fb_out=$(mktemp); fb_err=$(mktemp)
  if python3 - "$REPO_ROOT" $FB_REPORT $BUDGET_RECORD >"$fb_out" 2>"$fb_err" <<'PYFI'
import os, re, sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = sys.argv[1]
REPORT = "--report" in sys.argv[2:]
REC_BUDGET = "--record-budget" in sys.argv[2:]
BASELINE = os.path.join(ROOT, "templates/packs/_fallback-baseline.md")
PACKS = os.path.join(ROOT, "templates/packs")
BUDGET_REL = "templates/packs/_greenfield-budget.md"
BUDGET = os.path.join(ROOT, BUDGET_REL)
BUDGET_SECTION = "Boundary-loss outside agents"

KIND_DIR = {"pattern": "ai-patterns", "ai-pattern": "ai-patterns", "ai-patterns": "ai-patterns",
            "command": "commands", "agent": "agents", "rule": "rules", "convention": "rules",
            "skill": "skills", "reference": "references"}
SUBS = ("commands", "agents", "skills", "rules", "ai-patterns", "references")
# 40% of the phase-4.0 pack-depth floor for that class (agents 100, commands 80, rules/skills 50).
FLOOR = {"agents": 40, "commands": 32}
# The COMPLETE >=85%-retention / n>=8 band - every heading the derivation in the comment above
# admits, and nothing else. Keep this list and that derivation in lockstep: a heading that meets
# the published criterion but is missing here is an under-enforcement the docs actively deny.
LOADBEARING = re.compile(r'^(output|output format|hard rules|forbidden|failure modes|when to use|'
                         r'when to use / not to use|when not to use|must|must not|should|'
                         r'review checklist|checklist|invariants|rules|scans for|anti-patterns|'
                         r'references|prerequisites|inputs|method|procedure|enforcement|context|'
                         r'common mistakes|testing|observability|migration path|phases applied|'
                         r'phase [0-9]+.*)$')
# A magnitude only counts as a CLAIM when the line frames it as one (a target/limit/comparison)
# or when its unit is inherently a claim (rps, "connections per"). Bare numbers - RFC 9728,
# HTTP 401, a date - are not claims and must not be flagged.
TH = re.compile(r'(?i)(target|threshold|budget|limit|ceiling|quota|slo|sla|at least|at most|'
                r'no more than|p9[59]|maximum|minimum|max |min |[<>]=?)')
NUMT = re.compile(r'[0-9][0-9,]*(?:\.[0-9]+)?(?:%|[A-Za-z]{1,3})?')
UNIT = re.compile(r'(%|(?:ms|s|m|h|d|k|K|M|G|x|px|min|sec|hr|kb|mb|gb|KB|MB|GB|rps|qps)$)')
UB = re.compile(r'[0-9][0-9,.]*[kKmM]?\s*-\s*[0-9][0-9,.]*[kKmM]?\s*'
                r'(?:connections|conns|users|requests|rows|nodes|shards|events|clients)'
                r'|[0-9][0-9,.]*[kKmM]?\s*(?:rps|qps|ops/s|req/s|msg/s|connections per|conns per)'
                r'|[0-9][0-9,.]*x\s+(?:faster|slower|cheaper)')
DISP = re.compile(r'(\.claude/(?:rules|agents|commands|skills)/[A-Za-z0-9._/-]+'
                  r'|ai/patterns/[A-Za-z0-9._-]+\.md)')
# Only DISPATCH-shaped mentions count: a routing-table row, or a load/read/apply instruction.
# "Document each divergence in ai/patterns/theme.md" tells the project to WRITE that file; it is
# not a dangling pointer. Without this filter the rule is 67% false positives (3 files -> 1).
DISPLINE = re.compile(r'(?i)^\s*[-*0-9.]*\s*(load|read|see|apply|consult|dispatch|use)\b')
# Sources write 14.4x and >= as typography; fallbacks often write ASCII. Normalise before
# comparing or the two spellings read as a retracted claim (2 false positives without this).
NORM = str.maketrans({"×": "x", "–": "-", "—": "-", "≥": ">", "≤": "<"})

# BOUNDARY (agents only) — the sibling / cross-pack ownership block. Matched as a BLOCK, not as a
# heading spelling, for exactly the reason `halted` below is: the corpus writes it as
# `### Sibling agents in <pack> pack`, as `### Cross-pack boundary`, as `## Related — boundary`,
# and — legitimately, this IS the abridgement premise working — compressed into a one-line
# `- **Boundary:**` / `**Cross-pack:**` / `**Not this agent's job:**` bullet inside `## Related`.
# The `[^\n]{0,60}?` prefix window is what lets `## Related — boundary` and `- **Boundary:**` both
# hit while the prose line `Validate once, at the boundary` does not.
# THE CEILING, MEASURED, and it is the same one `halted` accepts. Matching a BLOCK means a
# domain-boundary false friend in the FALLBACK (`### Service boundaries`, `**Domain trust
# boundary**`) satisfies the rule, so a loss can be masked. The tighter alternative — requiring the
# keyword at the START of the bold run rather than within 60 chars — was written and measured
# against all 77 agent pairs: it scores 4 findings and 1 of them is FALSE
# (security/llm-security-reviewer, whose fallback carries the whole boundary as mid-line prose:
# `Boundary: LLM10 output-handling judgment ... owned here`, `**Not this agent's job:** the app's
# own endpoints ...`). The loose form scores 3 findings and 0 false. A gate that invents a finding
# on a file that did the right thing is worse than one that misses a masked loss, so the ceiling is
# taken deliberately, not by omission.
# THE OTHER CEILING, now closed. The prefix used to be heading-or-BOLD-run ONLY, so
# `- **Boundary:** this agent owns X; @sibling owns Y.` HIT while the identical sentence written
# `- Boundary: ...` or as bare prose MISSED — an author who compressed the block into an unbolded
# bullet (the compression the comment above blesses) got a FAIL that named no formatting
# requirement. The third branch below accepts the keyword when it OPENS the line (after an
# optional bullet), which is what those two forms have in common and what the prose false friend
# `Validate once, at the boundary` does not. Measured across all 282 pairs: source hits go
# agents 77->77, commands 36->36, ai-patterns 28->33, skills 21->30, and the AGENTS findings the
# rule gates stay at 0 — the widening costs no repair and removes the false-positive path.
_BKW = (r'(?:sibling\s+(?:agents?|commands?|skills?|patterns?)'
        r'|boundar(?:y|ies)\b'
        r'|what\s+(?:you|this(?:\s+agent)?)\s+(?:do|does)\s+not\s+own'
        r'|not\s+this\s+agent'
        r'|cross-pack)')
BOUNDARY = re.compile(r'(?im)^(?:'
                      r'(?:#{2,4}\s+|\s*[-*]?\s*\*\*\s*)[^\n]{0,60}?' + _BKW +
                      r'|\s*[-*]?\s*' + _BKW +
                      r')')
# CLOSING VERDICT — the block that decides whether the run may call itself done. Two spellings,
# and the OR is load-bearing: the corpus expresses it EITHER as a gate heading OR as a
# multi-valued verdict token, and abridgement freely drops one while keeping the other. Requiring
# the heading alone false-positives on business/pricing-tax-audit (keeps the token, drops the
# `### Verdict rule` heading); requiring the token alone false-positives on ai-engineering/ai-audit
# and testing/add-test (token lives ON an H2 line) and frontend/technical-seo (token inside the
# Output fence). The `[^.\n]{0,60}?` window kills the one prose false positive in the corpus,
# devops `gitops-audit/SKILL.md:12`, which contains `status: Unknown` mid-sentence.
# GATEH IS A CLOSING-GATE VOCABULARY, NOT EVERY HEADING WITH "gate" IN IT, and the difference is
# the rule's whole meaning. Measured over all 282 sources there are 85 distinct H2-H4 headings
# containing `gate`/`verdict`; the list below deliberately admits ~48 of them and excludes the
# rest, because those others gate something that is NOT the run's done-condition: a PRE-STEP
# (`Intent gate`, `Prior-art gate`, `New-dependency gate`, `Data-sensitivity gate (runs FIRST)`,
# `Comprehension gate`), a MID-RUN halt (`Cluster halt (mechanical gate)`, `Hand-wave halt`, all
# of which SIGNAL-LOSS already gates as halt blocks), or a gate in the REVIEWED SYSTEM rather than
# in the run (`3b. Biometric gates`, `6. Destructive tool with no server-side gate`, `Collection
# points — is there a consent gate`). Firing "the abridgement dropped the done-condition" because
# a fallback dropped an intent pre-step would be false about the file, so the vocabulary is scoped
# and the exclusion is stated rather than left as an unexplained 22%.
# `verdicts?` is admitted bare — a verdict IS a done-condition word — with one lookahead for the
# corpus's single negated use (`Where the token lives (the trade, not a verdict)`,
# frontend/auth-session-client).
GATEH = re.compile(r'(?im)^(#{2,4})\s+(?![^\n]*not a verdict)(.{0,60}?\b(?:'
                   r'verdicts?|ship gate|closure gate|closing gate|done-gate|done gate|'
                   r'terminal gate|production-readiness gate|production-grade gate|'
                   r'spec-conformance gate|mitigation-verification gate|migration-safety gate|'
                   r'approve gate|regression gate|eval gate|ci gate|review gate|advance gate|'
                   r'shadow gate|static gates|sla gate)\b)[^\n]*$')
# `verdict rule:` / `verdict criterion:` are the corpus's other spelling of the token line
# (infrastructure/dr-audit:118, business/pricing-tax-audit). Without the qualifier group the
# fallback that KEPT the rule and dropped only the heading reads as a total loss.
VTOK = re.compile(r'(?im)^(?:[#>\-*\s]|\*\*)*[^.\n]{0,60}?\b'
                  r'(?:ship|review|terminal|final|halt|production-grade)?\s*'
                  r'(?:verdict|status)(?:\s+(?:rule|criterion|line))?\s*:\s*(.+)$')
# ALT decides "multi-valued". It is applied to the token value with markdown emphasis STRIPPED,
# because the rule is about how many outcomes the line names, never about how they are typeset.
# PROVEN FALSE POSITIVE before this: rewriting
# `### Verdict: DURABLE | FRAGILE | ORPHAN-RISK` as ``### Verdict: `DURABLE` / `FRAGILE` / ...``
# — same three values, same heading — turned the pair red with a message that was factually wrong
# about the file and named no fix. Probes that now pass: `Verdict: **APPROVE** / **REQUEST_CHANGES**`,
# ``Verdict: `GO` / `NO-GO``` , `Verdict: _ship_ | _hold_`.
ALT = re.compile(r'[A-Za-z][A-Za-z_./-]*\s*[|/]\s*[A-Za-z][A-Za-z_./-]*')
EMPH = str.maketrans({'`': '', '*': '', '_': ''})
# A gate heading with NOTHING under it is a label, not a gate. PROVEN before this floor existed:
# restoring the historical add-ai-feature blob, inserting a bare `## Ship gate` with no criteria
# and deleting the stamp returned EXIT=0 — i.e. the cheapest-looking repair to the founding
# incident satisfied the gate without restoring the done-condition. The floor is 100 characters of
# block body, measured with headroom: the SMALLEST real gate block in the corpus is 139 chars
# (code-quality/check-health `Phase 4 — Generate (consolidate verdict)`), the next 157, 174, 175;
# a bare heading is 0 and a `TBD` is 3. Fenced `#` lines do not end a block — an Output fence
# routinely contains `## /command — <name>` and would otherwise truncate the body to nothing.
# POSITION IS DELIBERATELY NOT CHECKED, and that is the one half of "content and position" this
# rule declines. A closing gate is not reliably the last section: code-quality/simplify's gate is
# `## Phase 6` with `## Phase 7` and `## Output` after it, database/add-migration's Migration-Safety
# Gate precedes its Output fence, and frontend/technical-seo's verdict token lives INSIDE the Output
# fence. Requiring the last H2 would fail all three and force authors to reorder correct files to
# satisfy a regex — busywork, not protection. What the rule needs is that the done-condition still
# EXISTS in the delivered artifact; where it sits is the author's.
GATE_BODY_FLOOR = 100
_HEAD = re.compile(r'^(#{1,6})\s')


def gate_blocks(t):
    lines = t.splitlines()
    fenced, inf = [], False
    for l in lines:
        fenced.append(inf)
        if l.lstrip().startswith("```"):
            inf = not inf
    out = []
    for i, l in enumerate(lines):
        m = GATEH.match(l)
        if not m:
            continue
        lvl, body = len(m.group(1)), 0
        for j in range(i + 1, len(lines)):
            hm = _HEAD.match(lines[j])
            if hm and not fenced[j] and len(hm.group(1)) <= lvl:
                break
            body += len(lines[j].strip())
        if body >= GATE_BODY_FLOOR:
            out.append(m.group(2).strip())
    return out
# A terminal state with ONE value is not a verdict, it is a rubber stamp. This is the exact shape
# the ai-engineering ship-gate regression reverted to.
# The value list and the trailing window are both measured, not guessed: with the old
# end-anchored form, `Status: COMPLETE ✅`, `Status: COMPLETE — all checks pass` and
# `Status: SHIPPED` all escaped, so the exact fingerprint survived a decoration. The negative
# lookahead is what keeps the rule honest in the other direction — a line that names an
# alternative (`Status: COMPLETE | INCOMPLETE …`, `COMPLETE / INCOMPLETE`) is a real two-valued
# close and must never read as a rubber stamp.
DEGEN = re.compile(r'(?im)^\s*(?:[-*>]\s*)?(?:\*\*)?status(?:\*\*)?\s*:\s*[`*_]*\s*'
                   r'(?:complete[d]?|done|ok|pass(?:ed)?|shipped|success(?:ful)?|green|finished)'
                   r'[`*_]*(?![^\n]*[|/])[^\n]{0,40}$')


def closing(t):
    return bool(gate_blocks(t)) or any(ALT.search(m.group(1).translate(EMPH))
                                       for m in VTOK.finditer(t))


# BOUNDARY matches the block, so its FIRST hit in a long source is often a domain-boundary line
# (`- **(TXN) Transaction boundary`, `### Service boundaries`) rather than the sibling section the
# finding is actually about. Quote the most informative hit instead, or the message sends the
# reader to the wrong place.
_SIBLISH = re.compile(r'(?i)sibling|cross-pack|not\s+this\s+agent|do(?:es)?\s+not\s+own|related')


def exemplar(t):
    hits = [m.group(0).strip() for m in BOUNDARY.finditer(t)]
    for h in hits:
        if _SIBLISH.search(h):
            return h[:60]
    return (hits[0][:60] if hits else "")



def read(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def fm_block(t):
    if not t.startswith("---"):
        return None
    e = t.find("\n---", 3)
    return t[3:e] if e >= 0 else None


def fm(t, k):
    b = fm_block(t)
    if b is None:
        return None
    m = re.search(r'(?m)^' + k + r':[ \t]*(.*)$', b)
    return m.group(1).strip() if m else None


def body(t):
    if fm_block(t) is not None:
        t = t[t.find("\n---", 3) + 4:]
    t = re.sub(r'<!--.*?-->', '', t, flags=re.S)
    return [l.rstrip() for l in t.splitlines() if l.strip()]


def norm_h(h):
    """Abridgement renames and shortens headings: 'Gotchas (false positives)' for
    'False positives / gotchas', 'Adapt first - the codebase decides' for 'Adapt to the
    codebase'. Compare on the stem or those renames read as losses."""
    h = h.lower().translate(NORM)
    h = re.sub(r'\s*\(.*', '', h)
    h = re.sub(r'\s*[-]\s.*', '', h)
    return h.strip()


def topics(packdir):
    """example basename -> declared kind, for every topic whose `fallback:` names an _examples file."""
    out, name, kind, fb = {}, None, None, None

    def flush():
        if name and fb and fb.startswith("_examples/"):
            out[os.path.basename(fb)[:-3]] = kind

    for line in read(os.path.join(packdir, "_topics.md")).splitlines():
        m = re.match(r'^\s*-\s+name:\s*([A-Za-z0-9._-]+)', line)
        if m:
            flush()
            name, kind, fb = m.group(1), None, None
            continue
        if not name:
            continue
        m = re.match(r'^\s*kind:\s*([A-Za-z0-9._-]+)', line)
        if m:
            kind = m.group(1)
            continue
        m = re.match(r'^\s*fallback:\s*([A-Za-z0-9._/-]+)', line)
        if m:
            fb = m.group(1)
    flush()
    return out


_res = {}


def artifact_exists(stem):
    """Can ANY pack, the global command surface, or a domain overlay supply this name?"""
    if stem in _res:
        return _res[stem]
    hit = False
    for p in sorted(os.listdir(PACKS)):
        pd = os.path.join(PACKS, p)
        if not os.path.isdir(pd):
            continue
        for sub in SUBS:
            if os.path.isfile(os.path.join(pd, sub, stem + ".md")) or \
               os.path.isfile(os.path.join(pd, sub, stem, "SKILL.md")):
                hit = True
                break
        if hit:
            break
    if not hit and os.path.isfile(os.path.join(ROOT, "commands", stem + ".md")):
        hit = True
    if not hit:
        for _r, _d, files in os.walk(os.path.join(ROOT, "templates/domains")):
            if stem + ".md" in files:
                hit = True
                break
    _res[stem] = hit
    return hit


# The baseline states its own size in prose ("The backlog is 0 lines"). That is a claim a file
# makes about ITSELF and is decidable by counting the file, so it is checked rather than trusted.
# It is here because BOTH that sentence and this check's own header comment went stale the day the
# backlog reached zero - one advertising 1 line, the other 2 findings across 2 files - which sends
# a reader to a worklist that does not exist. It also gives a truncated ledger a name: a baseline
# read short un-suppresses its missing entries, which otherwise surfaces only as that many
# ratcheted defects going red at once with nothing pointing at the cause. Same self-check as
# scripts/lint-handoffs.sh:661-670. Absent sentence = no check, so fixture baselines are unaffected.
ADVERT = re.compile(r'backlog is\s+\**(\d+)\**\s+line')


def load_baseline():
    """A baseline line MUST carry a trailing `# reason`. A line added to silence a finding
    nobody read is the exact failure this gate exists to prevent, so a reasonless line does not
    suppress anything - the finding stays red and `unreasoned` reports why."""
    b, unreasoned = set(), []
    for line in read(BASELINE).splitlines():
        m = re.match(r'^([a-z0-9][a-z0-9-]*/[A-Za-z0-9._-]+)[ \t]+([A-Z][A-Z-]+)[ \t]*(#.*)?$',
                     line.strip())
        if m:
            if m.group(3) and m.group(3).strip("# \t"):
                b.add((m.group(1), m.group(2)))
            else:
                unreasoned.append((m.group(1), m.group(2)))
    mm = ADVERT.search(read(BASELINE))
    return b, unreasoned, (int(mm.group(1)) if mm else None)


# Same budget mechanism as check 3b's; see templates/packs/_greenfield-budget.md for why this is a
# COUNT ratchet and not a reasoned ledger, and for the per-pack ceiling it accepts.
def budget_rows(section):
    m = re.search(r'(?ms)^##\s+' + re.escape(section) + r'\b.*?\n```\n(.*?)\n```', read(BUDGET))
    rows = {}
    if m:
        for line in m.group(1).splitlines():
            mm = re.match(r'^([a-z0-9][a-z0-9-]*)[ \t]+(\d+)$', line.strip())
            if mm:
                rows[mm.group(1)] = int(mm.group(2))
    return rows


def budget_record(section, counts):
    body = "\n".join("%-24s %d" % (p, n) for p, n in sorted(counts.items()) if n) or "(none)"
    text = read(BUDGET)
    new, n = re.subn(r'(?ms)(^##\s+' + re.escape(section) + r'\b.*?\n```\n).*?(\n```)',
                     lambda mm: mm.group(1) + body + mm.group(2), text, count=1)
    if n:
        open(BUDGET, "w", encoding="utf-8").write(new)
    return n


findings, signal_loss, pairs, boundary_out, nonagent = [], [], 0, [], 0

for p in sorted(os.listdir(PACKS)):
    pd = os.path.join(PACKS, p)
    exdir = os.path.join(pd, "_examples")
    if not os.path.isdir(exdir):
        continue
    tm = topics(pd)
    for f in sorted(os.listdir(exdir)):
        if not f.endswith(".md"):
            continue
        n = f[:-3]
        key = p + "/" + n
        declared = n in tm
        # ---- source resolution: `_topics.md` kind first, check-8a's walk only as a fallback
        src, cls, sub = None, None, KIND_DIR.get(tm.get(n) or "")
        if sub == "skills":
            for c in (os.path.join(pd, "skills", n, "SKILL.md"), os.path.join(pd, "skills", n + ".md")):
                if os.path.isfile(c):
                    src, cls = c, "skills"
                    break
        elif sub:
            c = os.path.join(pd, sub, n + ".md")
            if os.path.isfile(c):
                src, cls = c, sub
        if src is None:
            for s in SUBS:
                for c in (os.path.join(pd, s, n + ".md"), os.path.join(pd, s, n, "SKILL.md")):
                    if os.path.isfile(c):
                        src, cls = c, s
                        break
                if src:
                    break
        ex = read(os.path.join(exdir, f))
        # ---- NOT-AN-ARTIFACT: 4.2 copies this file as the whole artifact, so it has to BE one.
        #      Only enforced on files a `_topics.md` actually points a topic at. Flags 0 of 297
        #      now: the one declared offender (backend/_examples/refactor.md, live under
        #      `triggers: always: true`, formerly 6 lines of prose where a command overlay belongs)
        #      is a 51-line artifact with frontmatter and a `## ` section. The two remaining thin
        #      refactor.md files (code-quality, mobile) are undeclared usage notes - a second genre
        #      sharing the directory - and are skipped below rather than gated.
        if declared:
            why = []
            if not ex.startswith("---"):
                why.append("no YAML frontmatter")
            if src:
                sh2 = sum(1 for l in read(src).splitlines() if l.startswith("## "))
                if sh2 > 0 and not any(l.startswith("## ") for l in ex.splitlines()):
                    why.append("no '## ' section (source has %d)" % sh2)
            floor = FLOOR.get(cls or "", 20)
            nl = len(ex.splitlines())
            if nl < floor:
                why.append("%d lines, below the %d-line floor for %s" % (nl, floor, cls or "artifact"))
            if why:
                findings.append((key, "NOT-AN-ARTIFACT", "; ".join(why)))
                continue
        if src is None:
            continue          # orphan - 8a already warned
        if not ex.startswith("---"):
            continue          # undeclared usage note, not a fallback
        pairs += 1
        srctxt = read(src)
        # ---- COPY-DRIFT: the file declared its own fidelity level; hold it to that level.
        #      10 of 297 carry `generated-from:` and all 10 currently match. Zero false-positive
        #      risk - the file opted in. Extending the header is the cheapest way to make more of
        #      this directory exactly gateable, and UNDECLARED-COPY below now REQUIRES it of any
        #      fallback whose body already is its source.
        m = re.search(r'generated-from:[ \t]*([A-Za-z0-9._/-]+)', ex)
        if m and os.path.isfile(os.path.join(ROOT, m.group(1))):
            a, b = body(ex), body(read(os.path.join(ROOT, m.group(1))))
            if a != b:
                d = sum(1 for x in a if x not in b) + sum(1 for x in b if x not in a)
                findings.append((key, "COPY-DRIFT", "declares generated-from: %s but its body "
                                 "differs by %d line(s) - re-copy, do not hand-edit: "
                                 "validate-pack-consistency.sh --recopy-apply" % (m.group(1), d)))
        # ---- UNDECLARED-COPY: the body IS the source's, and nothing says so. This is the one
        #      state the rest of the check cannot see BY CONSTRUCTION - it never diffs prose - and
        #      it is strictly worse than either honest option: an abridgement is held to the rules
        #      below, a DECLARED copy is held to its source line-for-line (COPY-DRIFT), an
        #      undeclared copy is held to neither, so the next source edit desyncs it in silence.
        #      Zero false-positive risk: byte-equality of the two bodies is not a judgement call.
        #      Fix by declaring `generated-from:` (see backend/add-feature.md) or by re-cutting.
        elif not m and body(ex) == body(srctxt):
            findings.append((key, "UNDECLARED-COPY", "body is byte-identical to %s but declares no "
                             "`generated-from:` - declare it (then COPY-DRIFT gates it line-for-line) "
                             "or re-cut it as an abridgement" % os.path.relpath(src, ROOT)))
        # ---- UNSOURCED-MAGNITUDE: a quantified claim the source does not make has never been
        #      through a correctness pass. This is the exact fingerprint of the f2f0ccd defect,
        #      and it reproduces it: replayed against that commit the rule stays silent at
        #      f2f0ccd~1 (both files carry "10-50k connections per Node process") and fires at
        #      f2f0ccd (the source retracted it, the fallback did not). Flags 1 of 293 now, the
        #      baselined migration/migration-discipline `>30d`; a looser `~N` token form was tried
        #      first and returned 2 pure false positives ("~1/N of keys", "~2 days to brute
        #      force"), which is why framing is required. Framing is also this rule's ceiling: an
        #      unframed fabricated magnitude with an off-list unit noun is NOT caught (see WHAT
        #      THIS CHECK DOES NOT CATCH at the top).
        exn, sn = ex.translate(NORM), srctxt.translate(NORM)
        snsq = re.sub(r'\s+', '', sn)
        toks = set()
        for line in exn.splitlines():
            if TH.search(line):
                toks.update(t for t in NUMT.findall(line) if UNIT.search(t))
        toks.update(re.sub(r'\s+', ' ', mm.group(0)) for mm in UB.finditer(exn))
        bad = sorted(t for t in toks if t not in sn and re.sub(r'\s+', '', t) not in snsq)
        if bad:
            findings.append((key, "UNSOURCED-MAGNITUDE", "claim(s) absent from %s: %s"
                             % (os.path.relpath(src, ROOT), ", ".join(bad))))
        # ---- DANGLING-DISPATCH: a routing target the source does not name and no pack can
        #      supply. Both filters earn their place: an unresolved-reference detector alone
        #      flags 17 files (mostly project-local paths that legitimately materialise in the
        #      target repo, and prose like "document each divergence in `ai/patterns/theme.md`",
        #      which tells the project to WRITE that file); + dispatch-shape -> 3; + source-diff
        #      -> 1 of 292, with no false positive left.
        srcrefs = set(DISP.findall(srctxt))
        dang = []
        for line in ex.splitlines():
            if "|" not in line and not DISPLINE.match(line):
                continue
            for r in DISP.findall(line):
                if r in srcrefs or r in dang:
                    continue
                stem = r.rstrip('`)')
                stem = stem.split('/')[-2] if re.search(r'/skills/[^/]+/SKILL\.md$', stem) \
                    else os.path.basename(stem)
                if stem.endswith(".md"):
                    stem = stem[:-3]
                if stem and stem != "SKILL" and not artifact_exists(stem):
                    dang.append(r)
        if dang:
            findings.append((key, "DANGLING-DISPATCH", "dispatches to %s - absent from the source "
                             "and no pack supplies it" % ", ".join(dang)))
        # ---- FRONTMATTER-LOSS: 4.2 copies frontmatter verbatim, so the fallback's frontmatter is
        #      what lands in the project. Scoped to the fields that are load-bearing for the
        #      resolved class: `description` is what a skill is matched on, and a wrong `model`
        #      silently downgrades an agent. Both classes are at 0 of 293 now (they were 8 and 3
        #      when the rule landed) - the rule is armed, not idle. NOT extended to `model:`
        #      MISSING (8 files), `severity:` on rule fallbacks (absent in 20 of 20 - the whole
        #      class) or `kind:` value equality (133) - a property that holds for a whole class is
        #      a convention, and gating a convention flags the convention, not a defect.
        lost = []
        if cls in ("skills", "commands", "agents") and fm(srctxt, "description") and not fm(ex, "description"):
            lost.append("description: lost (%s are dispatched on it)" % cls)
        if cls == "agents":
            sm, em = fm(srctxt, "model"), fm(ex, "model")
            if sm and em and sm != em:
                lost.append("model: %s but the source says %s" % (em, sm))
        sname = fm(srctxt, "name")
        if sname:
            ename = fm(ex, "name")
            if ename is None:
                lost.append("name: lost (source declares '%s')" % sname)
            elif ename != sname:
                lost.append("name: %s but the source says %s" % (ename, sname))
        if lost:
            findings.append((key, "FRONTMATTER-LOSS", "; ".join(lost)))
        # ---- SECTION-LOSS / SECTION-ORDER. Match H2 AND H3 in the fallback, because abridgement
        #      often demotes rather than drops. Flags 0 and 1 of 293 now (the baselined
        #      documentation/slo SECTION-ORDER), against 221 - 75% - for the naive
        #      any-missing-H2 form.
        sh = [norm_h(l[3:]) for l in srctxt.splitlines() if l.startswith("## ")]
        ehl = [norm_h(re.sub(r'^#{2,3} ', '', l)) for l in ex.splitlines() if re.match(r'^#{2,3} ', l)]
        ehs = set(ehl)
        miss = sorted({h for h in sh if LOADBEARING.match(h)} - ehs)
        if miss:
            findings.append((key, "SECTION-LOSS", "load-bearing source sections missing: " + ", ".join(miss)))

        def dedupe(seq):
            o, s = [], set()
            for i in seq:
                if i not in s:
                    o.append(i)
                    s.add(i)
            return o

        a = dedupe([h for h in sh if h in ehs])
        b = dedupe([h for h in ehl if h in set(sh)])
        if a != b:
            findings.append((key, "SECTION-ORDER", "kept sections resequenced vs source: %s -> %s"
                             % (" > ".join(a[:4]), " > ".join(b[:4]))))
        # ---- SIGNAL-LOSS. A `> **Hard rule:` line, a halt block, a `## Premise`, or an agent
        #      TRIGGER clause the source carries and the fallback drops. See the header comment
        #      for why this is now GATED rather than counted: the backlog it was measuring is 0.
        sig = []
        if re.search(r'(?m)^> \*\*Hard rule', srctxt) and not re.search(r'(?m)^> \*\*Hard rule', ex):
            sig.append("hard-rule")
        halted = lambda t: bool(re.search(r'(?mi)^\s*\*\*Halt conditions|^#{2,4}.*halt', t))
        if halted(srctxt) and not halted(ex):
            sig.append("halt")
        if re.search(r'(?mi)^#{2,3}.*premise', srctxt) and not re.search(r'(?mi)^#{2,3}.*premise', ex):
            sig.append("premise")
        if cls == "agents":
            sd, ed = (fm(srctxt, "description") or "").upper(), (fm(ex, "description") or "").upper()
            if "ANTI-TRIGGER" in sd and "ANTI-TRIGGER" not in ed:
                sig.append("anti-trigger")
            elif "TRIGGER" in sd and "TRIGGER" not in ed:
                sig.append("trigger")
        if sig:
            signal_loss.append((key, sig))
            findings.append((key, "SIGNAL-LOSS", "source carries a safety signal the fallback "
                             "drops: %s" % ", ".join(sig)))
        # ---- BOUNDARY-LOSS (agents only). The sibling / cross-pack ownership block, matched as
        #      a BLOCK exactly as `halted` above is, and for the same published reason: the gate
        #      already decided at `Halt conditions` 40% that a shape whose HEADING retention is low
        #      is still gatable when the BLOCK survives. This shape retains 74 of 77 agent sources
        #      (96%) and 25 of 25 across the last two repair batches (100%) — comfortably over the
        #      >=85% band criterion — yet it is absent from LOADBEARING for two purely structural
        #      reasons, neither of them a judgement that it does not deserve gating: the band
        #      derivation reads SOURCE H2s only (see the note at LOADBEARING) and 70+ of the 77
        #      agent sources write it as an H3; and `norm_h` does not collapse a trailing
        #      " in <pack> pack", so even as an H2 it would have fragmented into 21 headings of
        #      n<=7, all under the n>=8 floor. Arming it cost 3 repairs
        #      (frontend/api-contract-sentry, frontend/i18n-auditor, security/data-privacy-reviewer)
        #      and ZERO baseline lines.
        #      THE HARD FAIL IS SCOPED TO AGENTS; THE REST IS BUDGETED, NOT IGNORED. 77 of 77 agent
        #      sources carry the block, so in that class the gate demands a universal convention and
        #      discriminates perfectly. Outside it the convention is real but not universal
        #      (commands 36 of 44 sources, ai-patterns 33 of 81, skills 30 of 64, rules 1 of 16), so
        #      a hard FAIL there would legislate a convention rather than protect one — and it would
        #      demand a 51-line reasoned ratchet whose reasons nobody would read, which is the
        #      enforcement theatre this repo names as a failure mode.
        #      What "scoped" used to mean in practice, though, was INVISIBLE: arming the rule fixed
        #      3 agent fallbacks and left the rest unreported. Re-measured through this check's own
        #      pair resolution (282 pairs, not a directory walk) the non-agent class is 51 findings
        #      across 12 packs — commands 23, ai-patterns 14, skills 13, rules 1 — and every one of
        #      them is a file some project receives without knowing what it does NOT own. They are
        #      counted below, listed by `--fallback-report`, and budgeted per pack in
        #      templates/packs/_greenfield-budget.md, so the class can shrink and cannot grow.
        #      (An earlier revision of this comment said "48 findings across 11 packs". That figure
        #      came from a kind-directory walk rather than from the resolution the check uses.)
        if cls != "agents":
            nonagent += 1
            if BOUNDARY.search(srctxt) and not BOUNDARY.search(ex):
                boundary_out.append((key, cls, exemplar(srctxt)))
        if cls == "agents" and BOUNDARY.search(srctxt) and not BOUNDARY.search(ex):
            findings.append((key, "BOUNDARY-LOSS", "source carries a sibling / cross-pack boundary "
                             "block (%s) and the fallback carries none — a project receiving this "
                             "agent cannot tell what it does NOT own. Satisfied by a heading "
                             "(`### Sibling agents in <pack> pack`, `### Cross-pack boundary`), a "
                             "bold run (`- **Boundary:**`, `**Not this agent\'s job:**`) or a plain "
                             "line that OPENS with the keyword (`- Boundary: this agent owns X; "
                             "@sibling owns Y.`) — compression is fine, dropping it is not"
                             % exemplar(srctxt)))
        # ---- CLOSING-SIGNAL-LOSS. The gate/verdict block that decides whether the run may call
        #      itself done. THE INCIDENT: templates/packs/ai-engineering/_examples/add-ai-feature.md
        #      carried no `## Ship gate` and printed a bare `Status: COMPLETE` while its source
        #      forbade exactly that in two places (commands/add-ai-feature.md:155 and :215). The
        #      divergence opened at 7dde562 (2026-07-10) when the SOURCE gained the gate and the
        #      fallback blob did not move, and it survived 13 commits / 44 days / all of pack
        #      v1.3.0 — including 6dcb778, the commit that armed 8b, which exited 0 over it
        #      ("293 pairs checked, 0 new") and never named the file. Replayed on a reconstructed
        #      HEAD tree with that one blob restored, all 19 gates still exit 0 and none mentions
        #      it; this rule fires. Blast radius: `_essentials.md:6` lists `add-ai-feature` as the
        #      pack's ONLY essential command, so that was what every greenfield AI project got.
        #      COVERAGE, STATED RATHER THAN IMPLIED. This rule evaluates the 80 of 282 pairs (28%)
        #      whose SOURCE carries a done-condition; the other 202 sources do not close on one, so
        #      there is nothing for a fallback to drop. That is a real ceiling and neither this
        #      comment nor docs/REFERENCE.md may read as blanket protection. It was 66 of 282 before
        #      the vocabulary was widened, and the widening is what caught the one live instance the
        #      narrow form missed: code-quality/_examples/simplify.md, whose source gates on
        #      `## Phase 6 — Validate (the production-grade gate, per applied candidate)` and
        #      mandates a Verification footer, while the fallback shipped three generic bullets, no
        #      Arm 1 / Arm 2 and no revert-to-INCOMPLETE close. Repaired, not baselined.
        #      0 of 80 qualifying sources today — armed at zero, like SIGNAL-LOSS was.
        if closing(srctxt) and not closing(ex):
            gh = GATEH.search(srctxt)
            findings.append((key, "CLOSING-SIGNAL-LOSS", "source closes on a gate/verdict block "
                             "(%s) and the fallback closes on nothing — the abridgement kept the "
                             "procedure and dropped the done-condition. Satisfied by EITHER a "
                             "gate/verdict heading with at least %d characters of criteria under "
                             "it, OR a `Verdict:` / `Status:` line naming two or more outcomes "
                             "separated by `|` or `/` (backticks and bold around the values are "
                             "stripped before counting, so typography is never the issue)"
                             % ((gh.group(2).strip()[:60] if gh else "a multi-valued verdict token"),
                                GATE_BODY_FLOOR)))
        # ---- VERDICT-DEGRADED. The fallback prints a single-valued terminal stamp its source does
        #      not, where the source closes on a real verdict. This is the ai-engineering
        #      regression's exact fingerprint and it is what a fallback drifts INTO, not just what
        #      it drops.
        #      THE `not DEGEN.search(srctxt)` GUARD IS GONE, and removing it is the point. It used
        #      to blank the rule in the four highest-blast-radius files in the repo —
        #      backend/_examples/add-feature.md:488, backend/_examples/fix-bug.md,
        #      frontend/_examples/add-component.md, frontend/_examples/add-crud-page.md, every one
        #      of them closing on a bare `Status: COMPLETE` — for the sole reason that their
        #      SOURCES printed the identical line. `backend/_essentials.md:6` lists `add-feature`
        #      and `frontend/_essentials.md:6` lists `add-component`, so those are minimal-mode
        #      artifacts every greenfield project receives: the same `_essentials` blast-radius
        #      argument this header uses to rank the ai-engineering incident. "The source does it
        #      too" is a reason to fix BOTH, not a reason for the gate to stay silent about the
        #      file that actually lands in the project. All five instances (the fifth,
        #      backend/trace-flow, surfaced only once DEGEN stopped being spelling-brittle) were
        #      repaired in the same commit that removed the guard, so the rule is armed at zero.
        #      What is still REQUIRED is `closing(srctxt)`: the source must demonstrably have a
        #      real done-condition, or the finding would be legislating verdicts onto commands
        #      whose authors never wrote one. Cost to arm: 1 repair when the rule landed
        #      (backend/_examples/add-endpoint.md) + 5 pairs when the guard came off.
        d = DEGEN.search(ex)
        if d and closing(srctxt):
            findings.append((key, "VERDICT-DEGRADED", "fallback closes on `%s` — a single-valued "
                             "rubber stamp — where its source closes on a real verdict. This is "
                             "the artifact a no-signal project receives, so it is the one that "
                             "must name the failing terminal state%s. Fix: give the close two "
                             "outcomes (`Status: COMPLETE | INCOMPLETE — <what is unmet>`), as "
                             "backend/_examples/add-endpoint.md does"
                             % (d.group(0).strip(),
                                " (the source prints the same line at the same place — fix BOTH; "
                                "the source printing it is not a licence for the fallback to)"
                                if DEGEN.search(srctxt) else "")))

# ---- BOUNDARY-LOSS OUTSIDE AGENTS. Re-measured at the working tree with the check's own
# resolution (282 pairs, not a directory walk): 51 findings across 12 packs — commands 23,
# ai-patterns 20, skills 7, rules 1. The agents-only FAIL scope is right and is argued at the rule
# itself, but "scoped, therefore invisible" is how 46 live instances went unreported when the rule
# was armed. They are counted here and budgeted in templates/packs/_greenfield-budget.md, so the
# class can only shrink.
bo_now = {}
for key, cls, _ex in boundary_out:
    p = key.split("/", 1)[0]
    bo_now[p] = bo_now.get(p, 0) + 1
if REC_BUDGET:
    if budget_record(BUDGET_SECTION, bo_now):
        print("I\tboundary budget: recorded %d pack(s), %d fallback(s) outside the agents class -> %s"
              % (len(bo_now), len(boundary_out), BUDGET_REL))
    else:
        print("F\t%s has no `## %s` section with a fenced block to record into — create it or "
              "restore it from git; an absent budget reads as 0 for every pack."
              % (BUDGET_REL, BUDGET_SECTION))
else:
    bb = budget_rows(BUDGET_SECTION)
    for p in sorted(set(bo_now) | set(bb)):
        cur, rec = bo_now.get(p, 0), bb.get(p, 0)
        if cur > rec:
            print("F\t%s: %d fallback(s) outside the agents class drop the sibling / cross-pack "
                  "boundary block their source carries — %d more than the recorded budget of %d. "
                  "A project receiving one of those files cannot tell what it does NOT own. Carry "
                  "the block over (a compressed `- Boundary: …` line is enough), or record the new "
                  "level deliberately with `--record-budget` (%s)."
                  % (p, cur, cur - rec, rec, BUDGET_REL))
        elif cur < rec:
            print("W\t%s: %d boundary-loss fallback(s) outside agents, below its recorded budget "
                  "of %d — re-record with `--record-budget` so the ratchet keeps the ground it "
                  "gained (%s)" % (p, cur, rec, BUDGET_REL))
if REPORT:
    for key, cls, ex_ in sorted(boundary_out):
        print("R\tboundary   %-42s [%s] source block: %s" % (key, cls, ex_))
    print("R\tboundary outside agents: %d of %d non-agent pairs drop the block their source "
          "carries (budgeted in %s, not baselined)"
          % (len(boundary_out), nonagent, BUDGET_REL))

base, unreasoned, advertised = load_baseline()
for key, rule in sorted(unreasoned):
    print("W\tbaseline line `%s  %s` carries no `# reason` - it suppresses nothing until it does "
          "(templates/packs/_fallback-baseline.md)" % (key, rule))
if read(BASELINE).strip() and advertised is None:
    print("F\ttemplates/packs/_fallback-baseline.md exists but advertises no backlog size. The "
          "`**The backlog is N lines.**` sentence is checked on every run precisely because "
          "deleting it is cheaper than correcting it — restore it rather than removing it. "
          "(A baseline file that does not exist at all is unaffected: it suppresses nothing, "
          "which is already fail-safe.)")
if advertised is not None and advertised != len(base) + len(unreasoned):
    print("F\ttemplates/packs/_fallback-baseline.md advertises a %d-line backlog but %d entr%s "
          "parse. Either the sentence is stale, or the file was read short - a truncated ledger "
          "un-suppresses its missing entries, which reads as defects going red with nothing "
          "naming the cause." % (advertised, len(base) + len(unreasoned),
                                 "y" if len(base) + len(unreasoned) == 1 else "ies"))
seen, new, known = set(), [], []
for key, rule, detail in findings:
    seen.add((key, rule))
    (known if (key, rule) in base else new).append((key, rule, detail))

for key, rule, detail in new:
    p, n = key.split("/", 1)
    print("F\t%s: _examples/%s.md [%s] %s" % (p, n, rule, detail))
if REPORT:
    for key, rule, detail in known:
        print("R\tbaselined  %-42s [%s] %s" % (key, rule, detail))
    for key, sig in sorted(signal_loss):
        print("R\tsignal     %-42s lost: %s" % (key, ", ".join(sig)))
    print("R\tsafety signals: %d of %d fallbacks drop one their source carries (gated as "
          "SIGNAL-LOSS)" % (len(signal_loss), pairs))
for key, rule in sorted(base - seen):
    p, n = key.split("/", 1)
    print("W\t%s: _examples/%s.md [%s] no longer reproduces - drop its line from "
          "templates/packs/_fallback-baseline.md" % (p, n, rule))
if known:
    print("W\t%d known fallback defect(s) across %d file(s) suppressed by "
          "templates/packs/_fallback-baseline.md (repair backlog; --fallback-report lists them)"
          % (len(known), len({k for k, _, _ in known})))
print("I\tfallback integrity: %d pairs checked, %d new, %d baselined" % (pairs, len(new), len(known)))
if new:
    print("H\t^ fix the fallback, or - if it is correct as-is - add `<pack>/<name>  <RULE>` with a "
          "reason to templates/packs/_fallback-baseline.md")
PYFI
  then
    while IFS=$'\t' read -r fb_tag fb_msg; do
      case "$fb_tag" in
        F) err "$fb_msg" ;;
        W) warn_msg "$fb_msg" ;;
        R) [[ $QUIET -eq 0 ]] && echo "        $fb_msg" || true ;;
        I) ok "$fb_msg" ;;
        H) echo "  $fb_msg" >&2 ;;
      esac
    done < "$fb_out"
  else
    err "fallback integrity (check 8b) did not run: $(head -3 "$fb_err" | tr '\n' ' ')"
  fi
  rm -f "$fb_out" "$fb_err"
else
  warn_msg "fallback integrity (check 8b) skipped — python3 not found"
fi

echo ""
echo "pack-consistency: FAIL=$fail WARN=$warn"
if [[ $fail -gt 0 ]] || { [[ $STRICT -eq 1 ]] && [[ $warn -gt 0 ]]; }; then exit 1; fi
exit 0
