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
#
# Usage:  validate-pack-consistency.sh [--repo-root=<dir>] [--strict] [--quiet]
# Exit:   1 on any FAIL (or any WARN under --strict); 0 otherwise.

set -uo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STRICT=0; QUIET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --strict) STRICT=1; shift ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" || exit 1

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

  # 8. source-vs-examples drift (WARN — #SYNC-05). Each _examples/<name>.md is an
  #    abridged snapshot of a same-named source artifact in the pack (NOT a literal
  #    mirror — see project_examples_are_abridged note), so we do NOT diff content.
  #    We only flag an ORPHANED example: one whose source artifact no longer exists
  #    anywhere in the pack (renamed / removed). When a `generated-from:` header is
  #    present, resolve that exact path instead (more precise provenance).
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

echo ""
echo "pack-consistency: FAIL=$fail WARN=$warn"
if [[ $fail -gt 0 ]] || { [[ $STRICT -eq 1 ]] && [[ $warn -gt 0 ]]; }; then exit 1; fi
exit 0
