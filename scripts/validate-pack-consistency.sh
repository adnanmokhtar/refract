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
#   8b. FALLBACK INTEGRITY — every `_examples/<name>.md` still AGREES with the
#      source it abridges, on the axes a text comparison can actually decide:
#      no framed magnitude / dispatch target / frontmatter value the source
#      disowns, no section the corpus keeps ≥85% of the time, no dropped safety
#      signal, and no undeclared literal copy. It does NOT understand either
#      file — a source-side retraction or polarity flip is invisible to it; see
#      "WHAT THIS CHECK DOES NOT CATCH" at the check itself. Ratcheted through
#      templates/packs/_fallback-baseline.md                                (FAIL if new)
#
# Usage:  validate-pack-consistency.sh [--repo-root=<dir>] [--strict] [--quiet]
#                                      [--fallback-report]
# Exit:   1 on any FAIL (or any WARN under --strict); 0 otherwise.
#
# `--fallback-report` prints the full 8b picture — every baselined defect plus the
# safety-signal backlog that is counted but not gated. It is the repair worklist; it
# changes nothing about the exit code.

set -uo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STRICT=0; QUIET=0; FB_REPORT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --strict) STRICT=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --fallback-report) FB_REPORT="--report"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" || exit 1
REPO_ROOT="$PWD"   # absolute from here on: check 8b resolves paths against it AFTER this cd

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

  # 3. every PATH-like _topics fallback resolves. Sentinel strategies (e.g. `stub-from-sections`
  #    — generate a stub from the section headings) are not files; only check fallbacks that look
  #    like a path (contain `/` or end in `.md`).
  dangling=0
  while IFS= read -r fb; do
    [[ -z "$fb" ]] && continue
    echo "$fb" | grep -qE '/|\.md$' || continue   # skip sentinels
    # Dual-accept, symmetric with checks 4 and 6: a `skills/<name>.md` fallback also
    # resolves against the Agent Skills dir-form `skills/<name>/SKILL.md`, so a pack may
    # sit on either form without the fallback pointer having to be rewritten in lockstep.
    { [[ -f "$d$fb" ]] || { [[ "$fb" == skills/* ]] && [[ -f "$d${fb%.md}/SKILL.md" ]]; }; } \
      || { err "$p: _topics fallback does not resolve: $fb"; dangling=$((dangling + 1)); }
  done < <(grep -oE 'fallback:[[:space:]]*[A-Za-z0-9._/-]+' "$d/_topics.md" 2>/dev/null | sed 's/fallback:[[:space:]]*//')
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
# 8b. FALLBACK INTEGRITY (FAIL on anything not baselined) — repo-wide, runs once after the
#     per-pack loop because source resolution needs `_topics.md` and dangling-dispatch resolution
#     needs every pack at once.
#
#     WHY THIS IS A GATE AND NOT A NOTE. `templates/phases/phase-4.2-apply.md:26` copies
#     `_examples/<topic>.md` VERBATIM into a project when extraction has no signal for that topic;
#     `:306` ("pack files are copied verbatim") and `:30` (same destination paths as COPY mode)
#     mean the fallback IS the artifact the project receives — for greenfield, for --lightweight,
#     and for every `[EXTRACTION-WEAK]` track that `phase-4.0-preflight.md:534` routes to COPY.
#     287 of 297 examples are named as a live `fallback:` in a `_topics.md`. The pack-depth floor
#     at `phase-4.0-preflight.md:206-225` does not reach them (its `find` predicates are keyed on
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
#     to a single counted WARN; a violation NOT listed there is a hard FAIL. The backlog now
#     stands at 2 findings across 2 files (documentation/slo SECTION-ORDER — a rule artifact, and
#     migration/migration-discipline UNSOURCED-MAGNITUDE — sourced in a companion reference this
#     check's single-source resolution cannot see); each carries its reason in the file, and a
#     baseline line with NO reason suppresses nothing (see `load_baseline`). Repairing a file means
#     deleting its line — a line that no longer reproduces WARNs — so the baseline cannot rot into
#     a mute button. Keep this count in step with that file: a comment advertising a backlog larger
#     than the file holds sends readers to a worklist that is not there, which is how the last
#     version of this comment went stale.
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
  if python3 - "$REPO_ROOT" $FB_REPORT >"$fb_out" 2>"$fb_err" <<'PYFI'
import os, re, sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = sys.argv[1]
REPORT = "--report" in sys.argv[2:]
BASELINE = os.path.join(ROOT, "templates/packs/_fallback-baseline.md")
PACKS = os.path.join(ROOT, "templates/packs")

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
    return b, unreasoned


findings, signal_loss, pairs = [], [], 0

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
                                 "differs by %d line(s) - re-copy, do not hand-edit" % (m.group(1), d)))
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

base, unreasoned = load_baseline()
for key, rule in sorted(unreasoned):
    print("W\tbaseline line `%s  %s` carries no `# reason` - it suppresses nothing until it does "
          "(templates/packs/_fallback-baseline.md)" % (key, rule))
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
