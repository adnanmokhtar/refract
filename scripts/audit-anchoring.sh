#!/usr/bin/env bash
# audit-anchoring.sh — verify pack-derived artifacts are anchored to the target project.
#
# Solves the M25 question: pack templates are generic on purpose. After install,
# every pack-derived artifact in <target>/.claude/{commands,agents,skills,rules}
# (and ai/patterns) is supposed to carry a "## Project-specific (anchored)" block
# populated with facts cited from the codebase scan (path:line). Without that
# block, the artifact is just a generic skeleton and gives no project-aware help.
#
# This script audits per-artifact anchor coverage and writes a report. M25.1 is
# WARN-ONLY (always exit 0). Once M25.3 (apply-anchors.sh) is in place and pack
# templates carry the marker, M25.4 will promote this to REFUSE on missing anchors.
#
# Usage:
#   audit-anchoring.sh <target-repo> [--strict] [--quiet]
#
# Flags:
#   --strict — exit 1 if any pack-derived artifact lacks an anchor block (or has the
#              block but with zero `path:line` citations). Default = warn-only.
#   --quiet  — suppress per-file output; only print summary + write report.
#
# Output:
#   <target>/.claude/_anchoring-audit.md  (per-artifact report)
#   stderr summary line
#
# Exit codes:
#   0  — clean, OR warn-only (default) regardless of findings
#   1  — --strict + at least one pack-derived artifact unanchored
#   2  — usage error

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKS_ROOT="$REPO_ROOT/templates/packs"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--strict] [--quiet]" >&2
  exit 2
fi

TARGET="$1"; shift
STRICT=0
QUIET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --quiet)  QUIET=1; shift ;;
    *)        echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

REPORT="$TARGET/.claude/_anchoring-audit.md"
mkdir -p "$(dirname "$REPORT")"

# Path resolution per kind — same convention as study-existing.sh / pack-coverage-scan.sh
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

# Build set of "pack-derived" basenames per kind: any basename present in ANY pack
# under templates/packs/<*>/<kind>/<base>. We treat target files matching this set
# as pack-derived (eligible for anchor audit) and skip orphans (project-only).
#
# bash 3.2 has no associative arrays; we use space-delimited strings per kind.
pack_basenames_for_kind() {
  local kind="$1"
  find -L "$PACKS_ROOT" -mindepth 3 -maxdepth 3 -path "*/$kind/*.md" -not -name '_*' \
       -exec basename {} \; 2>/dev/null | sort -u | tr '\n' ' '
}

# Citation regex — `path:line` forms that prove the anchor cites the codebase, not
# generic prose. Accepts backticked OR plain. Path must contain a slash AND a real
# source-file extension AND be followed by `:<digits>`.
CITATION_RE='[a-zA-Z0-9._/-]+\.(ts|tsx|js|jsx|mjs|cjs|vue|py|go|rb|php|java|kt|swift|md|yaml|yml|json|toml|sh|env|html|css|scss|sql)[[:space:]]*:[[:space:]]*[0-9]+'

# Placeholder tokens that prove an anchor block is a SKELETON, not a real anchor.
# An anchor block carrying any of these has been left in template state — it cites
# no real project fact. Kept conservative: each token is a literal pack-template
# placeholder that never appears in a genuinely populated block.
PLACEHOLDER_RE='<src/path|<e\.g\.,|<EntityA>|<DetectedBase>|<NNNN>|<term>|<one-line|<YYYY-MM-DD>|<ClassName>|<path/to|<detected'

# Extract just the canonical anchor block body (between the start/end markers) so
# quality checks (line count, placeholder, identifier presence) measure the BLOCK,
# not the whole artifact. Falls back to the `## Project-specific` heading-to-next-H2
# slice for older pack templates that use form 2.
extract_anchor_block() {
  local f="$1"
  # Track fenced-code state and ignore markers/content inside ``` fences — a
  # fenced block is documentation (e.g. a skill that shows what an anchor block
  # looks like), not a live anchor. Without this, example marker blocks inside
  # code fences are mis-read as real anchors and their placeholders / example
  # paths surface as skeleton + cross-project-leak false-positives.
  if grep -qF '<!-- project-specific:start -->' "$f" 2>/dev/null; then
    awk '
      /^[[:space:]]*```/ { fence = !fence; next }
      fence { next }
      /^<!-- project-specific:start -->[[:space:]]*$/ { in_b=1; next }
      /^<!-- project-specific:end -->[[:space:]]*$/ { in_b=0; next }
      in_b { print }
    ' "$f" 2>/dev/null
  else
    awk '
      /^[[:space:]]*```/ { fence = !fence; next }
      fence { next }
      /^##[[:space:]]+Project-specific/ { in_b=1; next }
      in_b && /^##[[:space:]]/ { exit }
      in_b { print }
    ' "$f" 2>/dev/null
  fi
}

# Returns 0 if file has anchor block + ≥1 citation in it; else 1, with reason on stderr.
#
# Detects the canonical Phase-4.6 anchor block as established by the existing
# REFINE infrastructure (`apply-pack-adaptation`, `compute-anchor-density`,
# test-refine-fixture.sh). Recognized forms:
#   1. `<!-- project-specific:start --> ... <!-- project-specific:end -->`  (canonical, byte-stable)
#   2. `## Project-specific` heading (any suffix — older pack templates use this)
# Either form satisfies the "has section" check; M25.3 (apply-anchors.sh) writes
# form 1, which REFINE can later rewrite.
check_anchor() {
  local f="$1"
  if grep -qF '<!-- project-specific:start -->' "$f" 2>/dev/null \
     || grep -qE '^##[[:space:]]+Project-specific' "$f" 2>/dev/null; then
    : # has section
  else
    echo "no-anchor-section"
    return 1
  fi

  # --- Anti-skeleton QUALITY gate (M25.5) -------------------------------------
  # A block that exists but is template boilerplate gives no project help. Measure
  # the BLOCK body, not the whole file: it must have ≥3 substantive lines AND must
  # NOT carry placeholder tokens AND must cite ≥1 real identifier/path.
  local block
  block=$(extract_anchor_block "$f")

  # (a) reject placeholder tokens left in the block
  if printf '%s\n' "$block" | grep -qE "$PLACEHOLDER_RE" 2>/dev/null; then
    echo "anchor-placeholder-skeleton"
    return 1
  fi

  # (b) require ≥3 non-blank, non-comment, substantive lines in the block. A line
  # is "substantive" only if it carries word content (not a bare bullet / marker).
  local substantive
  substantive=$(printf '%s\n' "$block" \
    | grep -vE '^[[:space:]]*$' \
    | grep -vE '^[[:space:]]*<!--' \
    | grep -vE '^[[:space:]]*[-*][[:space:]]*$' \
    | grep -cE '[A-Za-z0-9]' 2>/dev/null || true)
  substantive="${substantive:-0}"
  if [[ "$substantive" -lt 3 ]]; then
    echo "anchor-too-thin(${substantive}-lines)"
    return 1
  fi

  # (c) require ≥1 real identifier or path cited anywhere in the file: either a
  # `path:line` citation, OR a backticked path-with-slash, OR a backticked
  # CamelCase / snake_case identifier (proves a real symbol was named).
  if grep -qE "$CITATION_RE" "$f" 2>/dev/null \
     || grep -qE '`[a-zA-Z0-9_./-]+/[a-zA-Z0-9_.-]+`' "$f" 2>/dev/null \
     || grep -qE '`[A-Z][a-zA-Z0-9]+[A-Z][a-zA-Z0-9]*`' "$f" 2>/dev/null \
     || grep -qE '`[a-z]+_[a-z_]+`' "$f" 2>/dev/null; then
    return 0
  else
    echo "anchor-without-citation"
    return 1
  fi
}

# --- Cross-project LEAK scan (M25.6) ------------------------------------------
# Failure mode: a generated artifact "ships another project's class names" — an
# anchor block populated from a DIFFERENT repo's facts (copy-paste, stale cache).
# We flag a high-confidence identifier cited in an anchor block that does NOT
# appear ANYWHERE in the target codebase. Conservative by design (false-positives
# would block legitimate runs): we only consider `path:line` citations and
# backticked paths-with-slash, and we ignore anything that resolves under the
# target (file exists OR string is grep-findable in source).
#
# Builds a one-time corpus of source basenames + a fast grep against the tree.
LEAK_SRC_GREP_DIRS=()
for d in src app lib packages apps services internal pkg components; do
  [[ -d "$TARGET/$d" ]] && LEAK_SRC_GREP_DIRS+=("$TARGET/$d")
done
# Fall back to the whole target (minus deps) if no conventional source root.
[[ ${#LEAK_SRC_GREP_DIRS[@]} -eq 0 ]] && LEAK_SRC_GREP_DIRS=("$TARGET")

# Returns 0 (token exists in target) / 1 (not found → leak candidate).
token_in_target() {
  local tok="$1"
  # path form: strip an optional :line suffix, test for a matching file by basename
  local pathpart="${tok%%:*}"
  if [[ "$pathpart" == */* ]]; then
    local bn="${pathpart##*/}"
    [[ -e "$TARGET/$pathpart" ]] && return 0
    find "$TARGET" -name "$bn" -not -path '*/node_modules/*' -not -path '*/.git/*' \
      -not -path '*/vendor/*' -not -path '*/dist/*' -not -path '*/build/*' \
      2>/dev/null | grep -q . && return 0
    return 1
  fi
  # identifier form: must appear literally in some source file
  grep -rqIF -- "$tok" "${LEAK_SRC_GREP_DIRS[@]}" \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor \
    --exclude-dir=dist --exclude-dir=build 2>/dev/null && return 0
  return 1
}

# Scan one artifact's anchor block; echo any high-confidence leaked tokens.
scan_leaks_in_file() {
  local f="$1" block tok
  block=$(extract_anchor_block "$f")
  [[ -z "$block" ]] && return 0
  # high-confidence tokens: backticked path-with-slash, and path:line citations
  while IFS= read -r tok; do
    [[ -z "$tok" ]] && continue
    # skip our own generated paths + universal scaffolds (never "leaks").
    # `scripts/*` covers the round-one floor block's generator-provenance line
    # ("Auto-populated by `scripts/apply-anchors.sh` …") — a setup-internal reference,
    # not a cross-project identifier leak.
    case "$tok" in
      .claude/*|ai/*|templates/*|scripts/*|CLAUDE.md*|AGENTS.md*) continue ;;
    esac
    if ! token_in_target "$tok"; then
      printf '%s\n' "$tok"
    fi
  done < <(
    printf '%s\n' "$block" \
      | grep -oE '`[a-zA-Z0-9_./-]+/[a-zA-Z0-9_.-]+`' 2>/dev/null | tr -d '`'
    printf '%s\n' "$block" \
      | grep -oE "$CITATION_RE" 2>/dev/null
  )
}

total_eligible=0
total_anchored=0
total_unanchored=0
total_orphans=0
total_leaks=0
declare -a unanchored_list
declare -a leak_list

{
  printf '# Anchoring audit — %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Target: `%s`\n\n' "$TARGET"
  printf 'Mode: %s\n\n' "$([[ $STRICT -eq 1 ]] && echo STRICT || echo warn-only)"
  printf '> Each pack-derived artifact (commands/agents/skills/rules/ai-patterns) is supposed to carry a `## Project-specific (anchored)` section with at least one `path:line` citation pointing into the target codebase. Without that, the artifact is generic and gives no project-aware help.\n\n'
  printf -- '---\n\n'

  for kind in commands agents skills rules ai-patterns; do
    tgt_dir=$(target_dir_for_kind "$kind")
    [[ -d "$tgt_dir" ]] || continue

    pack_bases=$(pack_basenames_for_kind "$kind")

    kind_eligible=0
    kind_anchored=0
    kind_unanchored=0
    kind_orphans=0
    kind_rows=""

    while IFS= read -r f; do
      base="$(basename "$f")"
      [[ "$base" == _* ]] && continue

      # Pack-derived? (basename appears in any pack's same kind dir)
      if [[ " $pack_bases " != *" $base "* ]]; then
        kind_orphans=$((kind_orphans + 1))
        total_orphans=$((total_orphans + 1))
        continue
      fi

      kind_eligible=$((kind_eligible + 1))
      total_eligible=$((total_eligible + 1))

      if reason=$(check_anchor "$f"); then
        kind_anchored=$((kind_anchored + 1))
        total_anchored=$((total_anchored + 1))
      else
        kind_unanchored=$((kind_unanchored + 1))
        total_unanchored=$((total_unanchored + 1))
        unanchored_list+=("$kind/$base ($reason)")
        kind_rows+=$'\n'"  - \`$base\` — **$reason**"
      fi

      # LEAK scan (M25.6): high-confidence identifiers/paths not present in target
      while IFS= read -r leaked; do
        [[ -z "$leaked" ]] && continue
        total_leaks=$((total_leaks + 1))
        leak_list+=("$kind/$base → \`$leaked\`")
      done < <(scan_leaks_in_file "$f")
    done < <(find "$tgt_dir" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null | sort)

    [[ $kind_eligible -eq 0 && $kind_orphans -eq 0 ]] && continue

    printf '## %s\n\n' "$kind"
    printf 'eligible (pack-derived): %d / anchored: %d / unanchored: %d / orphans (project-only, skipped): %d\n' \
      "$kind_eligible" "$kind_anchored" "$kind_unanchored" "$kind_orphans"
    if [[ -n "$kind_rows" ]]; then
      printf '\nUnanchored:%b\n' "$kind_rows"
    fi
    printf '\n'
  done

  # Cross-project LEAK findings (M25.6)
  if [[ $total_leaks -gt 0 ]]; then
    printf '## Cross-project leaks (high-confidence)\n\n'
    printf '> These identifiers/paths are cited in an anchor block but do NOT exist anywhere in the target codebase — a sign the block was populated from another project.\n\n'
    for row in "${leak_list[@]}"; do
      printf -- '- %s\n' "$row"
    done
    printf '\n'
  fi

  printf -- '---\n\n## Summary\n\n'
  printf 'Pack-derived artifacts:        **%d**\n' "$total_eligible"
  printf 'Anchored (with citation):      %d\n' "$total_anchored"
  printf 'Unanchored:                    %d\n' "$total_unanchored"
  printf 'Cross-project leaks:           %d\n' "$total_leaks"
  printf 'Orphans (project-only, skipped): %d\n\n' "$total_orphans"
  if [[ $total_eligible -gt 0 ]]; then
    pct=$(( total_anchored * 100 / total_eligible ))
    printf 'Coverage: **%d%%**\n\n' "$pct"
  fi
  if [[ $total_unanchored -eq 0 && $total_leaks -eq 0 ]]; then
    printf '✓ All pack-derived artifacts are anchored with real project facts.\n'
  else
    [[ $total_unanchored -gt 0 ]] && printf '⚠ %d pack-derived artifact(s) lack an anchor block, carry a placeholder skeleton, are too thin (<3 lines), or cite nothing real.\n' "$total_unanchored"
    [[ $total_leaks -gt 0 ]] && printf '⚠ %d cross-project leak(s) — anchor cites a fact absent from the target codebase.\n' "$total_leaks"
    printf '\nNext: run `apply-anchors.sh %s` (M25.3) to populate from `_codebase-scan.md` + `codebase-profile.md`.\n' "$TARGET"
  fi
} > "$REPORT"

# stderr summary
if [[ $QUIET -eq 0 ]]; then
  echo "Anchoring audit: $total_anchored/$total_eligible anchored, $total_unanchored unanchored, $total_leaks leaks ($total_orphans orphans skipped). Report: $REPORT" >&2
fi

if [[ $STRICT -eq 1 && ( $total_unanchored -gt 0 || $total_leaks -gt 0 ) ]]; then
  echo "REFUSED — $total_unanchored unanchored/skeleton + $total_leaks cross-project leak(s) (--strict)." >&2
  exit 1
fi
exit 0
