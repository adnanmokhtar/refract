#!/usr/bin/env bash
# apply-anchors.sh — deterministic Phase-4.6 round-one anchor injector.
#
# For each pack-derived artifact in <target>/.claude/{commands,agents,skills,rules}
# that lacks the canonical `<!-- project-specific:start --> ... :end -->` markers,
# inject a populated anchor block built from facts in:
#   <target>/.claude/codebase-profile.md     (Phase 2 LLM-filled facts)
#   <target>/.claude/_codebase-scan.md       (Phase 0 mechanical scan)
#
# This script is the deterministic equivalent of what the agent's Phase 4.6
# (`apply-pack-adaptation` skill) does for round-one. The agent has been
# routinely skipping that work; this closes the gap with a no-judgment script.
# REFINE (4.6-DEEP) still owns deepening shallow blocks — this only writes the
# round-one floor.
#
# Usage:
#   apply-anchors.sh <target-repo> [--apply]
#
# Exit codes:
#   0 — clean (dry-run by default, or --apply succeeded)
#   1 — target missing OR required extracts missing
#   2 — usage error
#   3 — blocks were injected but ZERO of the five profile facts resolved (the anchor is
#       structurally present and semantically empty). Reported, not fatal: the files are
#       written and the run continues; Phase 5 surfaces it. See the summary block.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKS_ROOT="$REPO_ROOT/templates/packs"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--apply]" >&2
  exit 2
fi

TARGET="$1"; shift
APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    *)       echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

PROFILE="$TARGET/.claude/codebase-profile.md"
SCAN="$TARGET/.claude/_codebase-scan.md"
IDIOMS="$TARGET/.claude/_extracted-idioms.md"   # optional — Phase 2.5 output (architecture fingerprint)

if [[ ! -f "$PROFILE" ]]; then
  echo "ERR: $PROFILE not found — Phase 2 has not run" >&2
  exit 1
fi
if [[ ! -f "$SCAN" ]]; then
  echo "ERR: $SCAN not found — Phase 0 has not run" >&2
  exit 1
fi

# Path resolution per kind — same convention as study-existing.sh
target_dir_for_kind() {
  case "$1" in
    commands)    echo "$TARGET/.claude/commands" ;;
    agents)      echo "$TARGET/.claude/agents" ;;
    skills)      echo "$TARGET/.claude/skills" ;;
    rules)       echo "$TARGET/.claude/rules" ;;
    ai-patterns) echo "$TARGET/ai/patterns" ;;
    *)           echo "$TARGET/.claude/$1" ;;
  esac
}

# Pack-derived basenames per kind
# Dual-form: flat `<kind>/<name>.md` (depth 3) AND Agent Skills dir-form
# `<kind>/<name>/SKILL.md` (depth 4). Both are reduced to the SAME identity — the
# artifact name plus `.md` — so membership below is form-independent: a target still on
# flat form still matches a pack that has moved to dir-form, and vice versa. Without the
# depth-4 branch every pack skill silently drops out of this set and anchoring skips it.
pack_basenames_for_kind() {
  local kind="$1"
  { find -L "$PACKS_ROOT" -mindepth 3 -maxdepth 3 -path "*/$kind/*.md" -not -name '_*' \
         -exec basename {} \; 2>/dev/null
    find -L "$PACKS_ROOT" -mindepth 4 -maxdepth 4 -path "*/$kind/*/SKILL.md" \
         -exec sh -c 'for p; do n=$(basename "$(dirname "$p")"); case $n in _*) ;; *) echo "$n.md" ;; esac; done' _ {} + 2>/dev/null
  } | sort -u | tr '\n' ' '
}

# Enumerate one artifact-kind dir, one line per artifact, in BOTH on-disk forms:
#   flat      <dir>/<name>.md
#   dir-form  <dir>/<name>/SKILL.md
# Emits FULL paths; callers derive the dir-relative suffix, which is the real path to the
# artifact. `_*` artifacts are dropped by the caller's existing prefix guard.
enumerate_kind_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  { find "$dir" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null
    find "$dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -not -path "$dir/_*" 2>/dev/null
  } | sort
}

# Canonical, form-independent artifact identity: `foo.md` and `foo/SKILL.md` both -> `foo.md`.
artifact_identity() {
  case "$1" in
    */SKILL.md) local d="${1%/SKILL.md}"; echo "${d##*/}.md" ;;
    *)          echo "${1##*/}" ;;
  esac
}

# ---------- Extract facts from profile/scan into one shared anchor block ----------

# Pull first non-empty content line under a "## <Heading>" section in
# codebase-profile.md, normalize to a single line. Best-effort; tolerates missing
# sections by emitting "<not declared>".
#
# BOTH heading forms are accepted — `## Architecture` AND `## 1. Architecture`.
# This used to require the numeric prefix (`/^## [0-9]+\. /`), which is NOT the form
# Phase 2 is told to write: the canonical profile shape (`templates/appendices.md`
# § Appendix D) is UNNUMBERED, and `phase-2-profile.md § Profile content` numbers the
# fields in prose only. Against a canonically-written profile the numbered-only parser
# returned nothing for all five facets, every anchor rendered five `<not declared…>`
# lines with five identical `codebase-profile.md:1` citations, and audit-anchoring.sh
# still passed it (7 substantive lines, a resolving `path:line`, and `codebase-profile.md*`
# whitelisted from its leak scan) — i.e. the deterministic auditor certified an empty
# anchor as anchored. Matching on the heading TEXT with the numeric prefix optional is
# what makes the round-one floor actually rest on extracted facts.
profile_section_first_line() {
  local heading_pattern="$1"  # e.g. "Architecture", "Naming", "Testing"
  awk -v pat="$heading_pattern" '
    function stem(h,   s) {
      s = h
      sub(/^##[[:space:]]+/, "", s)
      sub(/^[0-9]+\.[[:space:]]*/, "", s)
      return tolower(s)
    }
    BEGIN { in_section = 0; want = tolower(pat) }
    /^## / {
      if (in_section) exit
      if (index(stem($0), want) == 1) in_section = 1
      next
    }
    in_section && NF {
      gsub(/^[[:space:]]*-[[:space:]]*\*\*[^*]+\*\*[[:space:]]*:[[:space:]]*/, "")
      gsub(/^[[:space:]]*-[[:space:]]*/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print
      exit
    }
  ' "$PROFILE" 2>/dev/null
}

# Line number of a profile section, either heading form. Same optional-prefix rule as
# profile_section_first_line — the two MUST agree or a resolved fact would carry a `:1`
# citation (or vice versa).
profile_section_line() {
  # `|| true` is load-bearing under `set -o pipefail`: a profile that legitimately lacks
  # the section makes grep exit 1, which fails the whole assignment and kills the run under
  # `set -e`. A missing section must DEGRADE (fall through to `:1`), never abort — that is
  # the same degrade-never-stop discipline the extraction spec is written to.
  { grep -nE "^## ([0-9]+\.[[:space:]]*)?$1" "$PROFILE" 2>/dev/null || true; } | head -1 | cut -d: -f1
}

ARCH_LINE=$(profile_section_first_line "Architecture")
NAMING_LINE=$(profile_section_first_line "Naming")
TESTING_LINE=$(profile_section_first_line "Testing")
DATA_LINE=$(profile_section_first_line "Data access")
ERR_LINE=$(profile_section_first_line "Error handling")

# Top-level src dirs (cite-able paths) from _codebase-scan.md § "Top-level directories"
SRC_DIRS=$(awk '/^## 2\. Top-level/{flag=1; next} /^## [0-9]+\./{flag=0} flag && /^src\// && !/\/\//' "$SCAN" 2>/dev/null \
           | head -3 | tr '\n' ' ' | sed 's/[[:space:]]*$//')
# No src/ line in the scan is a real answer — this repo may not have one. Emitting a
# hard-coded "src/" ships a path that does not exist into every anchored artifact
# (measured: 288 artifacts in one run against a repo with no top-level src/).
[[ -z "$SRC_DIRS" ]] && SRC_DIRS="<none — scan found no top-level source dir>"

# Manifests we know exist (cite-able)
MANIFESTS=""
for m in package.json tsconfig.json vite.config.ts next.config.js pyproject.toml pom.xml go.mod Gemfile composer.json Cargo.toml; do
  if [[ -f "$TARGET/$m" ]]; then
    [[ -n "$MANIFESTS" ]] && MANIFESTS="$MANIFESTS, "
    MANIFESTS+="\`$m\`"
  fi
done
[[ -z "$MANIFESTS" ]] && MANIFESTS="(none detected)"

# Per-section line numbers in the profile — gives every injected block at least
# one verifiable `path:line` citation, which is what audit-anchoring.sh looks for.
arch_ln=$(profile_section_line "Architecture")
naming_ln=$(profile_section_line "Naming")
testing_ln=$(profile_section_line "Testing")
data_ln=$(profile_section_line "Data access")
err_ln=$(profile_section_line "Error handling")

# How many of the five facets actually resolved. An anchor built from zero resolved
# facts is five `<not declared…>` lines wearing a citation costume — it satisfies every
# downstream presence check while telling the reader nothing about this project. Count
# it here so the shortfall is REPORTED rather than silently shipped (see the summary
# block and exit code 3 below).
facts_resolved=0
facts_missing=""
for pair in "Architecture:$ARCH_LINE" "Naming:$NAMING_LINE" "Testing:$TESTING_LINE" \
            "Data access:$DATA_LINE" "Error handling:$ERR_LINE"; do
  if [[ -n "${pair#*:}" ]]; then
    facts_resolved=$((facts_resolved + 1))
  else
    facts_missing+="${facts_missing:+, }${pair%%:*}"
  fi
done

# Architecture fingerprint — when Phase 2.5 ran and produced _extracted-idioms.md,
# pull the base-class H1 list (top 5) so every anchor block names this project's
# actual load-bearing classes instead of just generic "Architecture: layered".
# This is what makes the anchor architecture-aware vs template-shaped.
BASE_CLASSES=""
if [[ -f "$IDIOMS" ]]; then
  # TWO on-disk shapes, both real, so read both:
  #   (a) the `_extracted-idioms.md` schema in `phase-2-profile.md § Output schema` —
  #       ONE H1 (`# Project idioms — <project>`) plus H2 sections per idiom kind,
  #       each holding `- <Name> (<path>) — <role> — <n> <dependents>` rows;
  #   (b) the per-base pattern shape `# <BaseName><Generics> Pattern` that
  #       `extract-base-class-idiom § Step 6` authors when it appends per base.
  # Reading only (b)'s `^# ` — which is what this did — turns shape (a)'s single title
  # line into a fake "base class" named `Project idioms — <project>`, and misses every
  # composable / wrapper / shared service / type primitive the file actually names.
  # Shape (a) rows are the ones a non-class project has at all.
  BASE_CLASSES=$({
    awk '
      /^## (Wrappers|Composables|Shared services|Base classes|Type primitives)/ { in_sec = 1; next }
      /^## / { in_sec = 0 }
      in_sec && /^-[[:space:]]/ {
        line = $0
        sub(/^-[[:space:]]*/, "", line)
        sub(/[[:space:]]*[(—-].*$/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line != "" && line !~ /^</) print line
      }
    ' "$IDIOMS" 2>/dev/null
    { grep -E '^# .* Pattern$' "$IDIOMS" 2>/dev/null || true; } \
      | sed -E 's/^# +//; s/ +Pattern$//'
  } | awk 'NF && !seen[$0]++' \
    | head -5 \
    | awk 'NF { printf "%s`%s`", (NR>1 ? ", " : ""), $0 } END { print "" }')
fi

# Compose anchor block — uniform across artifacts except optional TBD token count.
# Round-one floor; REFINE specializes per-artifact based on `compute-anchor-density`
# scoring. When _extracted-idioms.md is present, append an extra "Detected base classes"
# line so the anchor names the project's real architecture, not just five
# generic facets.
# $1 = optional count of <TBD:...> placeholders in the target file body (Phase 4.6 contract).
build_block() {
  local tbd_count="${1:-0}"
  local idiom_line=""
  if [[ -n "$BASE_CLASSES" ]]; then
    idiom_line="> - **Detected load-bearing idioms** (\`_extracted-idioms.md\`): ${BASE_CLASSES}"$'\n'">"
  fi
  local tbd_line=""
  if [[ "${tbd_count}" -gt 0 ]]; then
    tbd_line=$'\n''> - **Stack placeholders pending**: '"${tbd_count}"' `<TBD:...>` token(s) in this file — Phase 4.6-DEEP / REFINE substitutes from `_extracted-codebase.md` / `_extracted-idioms.md`.'
  fi
  cat <<BLOCK
<!-- project-specific:start -->
## Project-specific (auto-generated, regenerate with \`/setup-project --refine\`)

> Auto-populated by \`scripts/apply-anchors.sh\` from \`.claude/codebase-profile.md\` + \`.claude/_codebase-scan.md\`$([[ -n "$BASE_CLASSES" ]] && echo " + \`.claude/_extracted-idioms.md\`"). Round-one floor — \`/setup-project --refine\` deepens shallow blocks based on \`compute-anchor-density\` scoring.
>
> - **Architecture** (\`.claude/codebase-profile.md:${arch_ln:-1}\`): ${ARCH_LINE:-<not declared in codebase-profile.md>}
> - **Naming** (\`.claude/codebase-profile.md:${naming_ln:-1}\`): ${NAMING_LINE:-<not declared in codebase-profile.md>}
> - **Testing** (\`.claude/codebase-profile.md:${testing_ln:-1}\`): ${TESTING_LINE:-<not declared in codebase-profile.md>}
> - **Data access** (\`.claude/codebase-profile.md:${data_ln:-1}\`): ${DATA_LINE:-<not declared in codebase-profile.md>}
> - **Error handling** (\`.claude/codebase-profile.md:${err_ln:-1}\`): ${ERR_LINE:-<not declared in codebase-profile.md>}
${idiom_line}${tbd_line}
> Cite-able sources: ${MANIFESTS}, top-level: ${SRC_DIRS}.

<!-- project-specific:end -->

BLOCK
}

# ---------- Inject into eligible artifacts ----------

# Find insertion point in a file: after frontmatter (if any), after the first H1
# (if any), before the first H2 (if any). If none of those exist, prepend.
# Returns the line number AFTER which to insert (1-based; 0 = prepend).
find_insertion_line() {
  local f="$1"
  awk '
    BEGIN { state="start"; fm_end=0; h1=0; h2=0 }
    NR == 1 && /^---[[:space:]]*$/ { state="fm"; next }
    state == "fm" && /^---[[:space:]]*$/ { fm_end=NR; state="body"; next }
    state == "body" && /^# / && !h1 { h1=NR; next }
    state == "body" && /^## / && !h2 { h2=NR; exit }
    state == "start" && /^# / && !h1 { h1=NR; state="body"; next }
    state == "start" && /^## / && !h2 { h2=NR; exit }
    END {
      if (h2 > 0) print h2 - 1
      else if (h1 > 0) print h1
      else if (fm_end > 0) print fm_end
      else print 0
    }
  ' "$f"
}

inject_block() {
  local f="$1"
  local insert_after="$2"
  local block="$3"
  local tmp
  tmp=$(mktemp)
  if [[ "$insert_after" -eq 0 ]]; then
    {
      printf '%s\n' "$block"
      cat "$f"
    } > "$tmp"
  else
    {
      head -n "$insert_after" "$f"
      printf '\n%s\n' "$block"
      tail -n +$((insert_after + 1)) "$f"
    } > "$tmp"
  fi
  mv "$tmp" "$f"
}

# Safety-net: scrub leftover upstream "Project-specific block" instructional
# blockquotes that contain `<extracted-from-codebase>` placeholders. These
# blockquotes are obsolete (replaced by the canonical marker block this script
# injects); some pack source files still ship them and they survive into the
# downstream project as confusing stale prose. We only scrub blockquotes that
# both reference Phase 4.6 AND contain a placeholder line — never user content.
scrub_upstream_placeholder_blockquote() {
  local f="$1"
  grep -qF '<extracted-from-codebase>' "$f" 2>/dev/null || return 0
  grep -qE '^>[[:space:]]*\*\*Project-specific block\*\*' "$f" 2>/dev/null || return 0

  local tmp
  tmp=$(mktemp)
  awk '
    BEGIN { in_blockquote=0; saw_marker=0 }
    /^>[[:space:]]*\*\*Project-specific block\*\*.*Phase 4\.6/ {
      in_blockquote=1; saw_marker=1; next
    }
    in_blockquote && /^>/ { next }
    in_blockquote && !/^>/ { in_blockquote=0 }
    { print }
    END { exit (saw_marker ? 0 : 0) }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
}

ts=$(date +%Y%m%d-%H%M%S)
backup_dir="$TARGET/.claude/backups/anchors-$ts"

injected=0
already=0
orphans=0
processed=0

echo "=== apply-anchors ==="
echo "Target:  $TARGET"
echo "Mode:    $([[ $APPLY -eq 1 ]] && echo APPLY || echo dry-run)"
echo "Profile: $PROFILE"
echo "Scan:    $SCAN"
if [[ -f "$IDIOMS" ]]; then
  echo "Idioms:  $IDIOMS  (architecture fingerprint — anchors will name detected load-bearing idioms)"
else
  echo "Idioms:  (absent — anchors will be 5-facet only; Phase 2.5 was skipped or had no signal)"
fi
echo ""

for kind in commands agents skills rules ai-patterns; do
  tgt_dir=$(target_dir_for_kind "$kind")
  [[ -d "$tgt_dir" ]] || continue
  pack_bases=$(pack_basenames_for_kind "$kind")

  while IFS= read -r f; do
    base="${f#"$tgt_dir"/}"
    [[ "$base" == _* ]] && continue
    processed=$((processed + 1))

    # Pack-derived? (compared on the form-independent identity, so a dir-form
    # `<name>/SKILL.md` target matches the pack's `<name>.md` identity key)
    if [[ " $pack_bases " != *" $(artifact_identity "$base") "* ]]; then
      orphans=$((orphans + 1))
      continue
    fi

    # Already anchored?
    # Match the marker only when it appears as its own line (a real injected block),
    # NOT when it appears as text inside prose / backticks (pointer documentation).
    # Without `^...$` anchors, descriptive prose like "the `<!-- project-specific:start -->` block"
    # would be treated as already-anchored and skipped, leaving the file un-injected.
    if grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$f" 2>/dev/null; then
      already=$((already + 1))
      continue
    fi

    insert_line=$(find_insertion_line "$f")

    if [[ "$APPLY" -eq 1 ]]; then
      # Backup
      mkdir -p "$backup_dir"
      rel="${f#$TARGET/}"
      bak="$backup_dir/$rel"
      mkdir -p "$(dirname "$bak")"
      cp "$f" "$bak"

      tbd_count=$({ grep -oE '<TBD:[^>]+>' "$f" 2>/dev/null || true; } | wc -l | tr -d ' ')
      ANCHOR_BLOCK=$(build_block "${tbd_count:-0}")
      inject_block "$f" "$insert_line" "$ANCHOR_BLOCK"
      scrub_upstream_placeholder_blockquote "$f"
      echo "  INJECT  $rel  (after line $insert_line)"
    else
      echo "  would-INJECT $kind/$base  (after line $insert_line)"
    fi
    injected=$((injected + 1))
  done < <(enumerate_kind_dir "$tgt_dir")
done

echo ""
echo "=== summary ==="
echo "Processed:                     $processed"
echo "Injected (or would-inject):    $injected"
echo "Already anchored (skipped):    $already"
echo "Orphans (project-only):        $orphans"
echo "Profile facts resolved:        $facts_resolved/5"
if [[ -n "$facts_missing" ]]; then
  echo ""
  echo "WARN: $((5 - facts_resolved)) of 5 anchor facts did not resolve: $facts_missing"
  echo "      Every injected block renders those as \`<not declared in codebase-profile.md>\`."
  echo "      Expected headings in $PROFILE (either \`## Naming\` or \`## 3. Naming\` form):"
  echo "        ## Architecture / ## Naming / ## Testing / ## Data access / ## Error handling"
  echo "      Shape reference: templates/appendices.md § Appendix D."
fi
if [[ "$APPLY" -eq 1 && "$injected" -gt 0 ]]; then
  echo "Backups:                       $backup_dir/"
fi
[[ "$APPLY" -eq 0 ]] && echo "Dry run — pass --apply to execute."

# Exit 3 — the anchor was written, and it is empty. NOT exit 1: the injection itself
# succeeded and the run should continue; this is a REPORTED shortfall, which is the whole
# difference between "anchored" meaning something and meaning nothing. Reserved for the
# unambiguous case — ZERO of five facets resolved, i.e. a block whose every content line is
# `<not declared in codebase-profile.md>` and whose five citations all point at line 1.
# A partial shortfall (1-4 resolved) warns above and still exits 0.
if [[ "$facts_resolved" -eq 0 && "$injected" -gt 0 ]]; then
  echo ""
  echo "ERR: anchor blocks were built from ZERO resolved profile facts — the round-one floor"
  echo "     is five \`<not declared…>\` lines. Fix $PROFILE (Phase 2) and re-run."
  exit 3
fi
exit 0
