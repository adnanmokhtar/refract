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
  find "$PACKS_ROOT" -mindepth 3 -maxdepth 3 -path "*/$kind/*.md" -not -name '_*' \
       -exec basename {} \; 2>/dev/null | sort -u | tr '\n' ' '
}

# Citation regex — `path:line` forms that prove the anchor cites the codebase, not
# generic prose. Accepts backticked OR plain. Path must contain a slash AND a real
# source-file extension AND be followed by `:<digits>`.
CITATION_RE='[a-zA-Z0-9._/-]+\.(ts|tsx|js|jsx|mjs|cjs|vue|py|go|rb|php|java|kt|swift|md|yaml|yml|json|toml|sh|env|html|css|scss|sql)[[:space:]]*:[[:space:]]*[0-9]+'

# Returns 0 if file has anchor section + ≥1 citation in it; else 1, with reason on stderr.
check_anchor() {
  local f="$1"
  # Look for the canonical anchor section header. Accept several phrasings to be
  # forward-compatible with markers we'll add in M25.2:
  #   ## Project-specific (anchored)
  #   ## Project-specific
  #   <!-- anchor:project-specific start --> ... <!-- anchor:project-specific end -->
  if grep -qE '^##[[:space:]]+Project-specific' "$f" 2>/dev/null \
     || grep -q 'anchor:project-specific[[:space:]]*start' "$f" 2>/dev/null; then
    : # has section
  else
    echo "no-anchor-section"
    return 1
  fi
  # Check for at least one path:line citation in the file. We don't restrict the
  # citation to the anchor section itself; some pack templates already cite inline.
  if grep -qE "$CITATION_RE" "$f" 2>/dev/null; then
    return 0
  else
    echo "anchor-without-citation"
    return 1
  fi
}

total_eligible=0
total_anchored=0
total_unanchored=0
total_orphans=0
declare -a unanchored_list

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

  printf -- '---\n\n## Summary\n\n'
  printf 'Pack-derived artifacts:        **%d**\n' "$total_eligible"
  printf 'Anchored (with citation):      %d\n' "$total_anchored"
  printf 'Unanchored:                    %d\n' "$total_unanchored"
  printf 'Orphans (project-only, skipped): %d\n\n' "$total_orphans"
  if [[ $total_eligible -gt 0 ]]; then
    pct=$(( total_anchored * 100 / total_eligible ))
    printf 'Coverage: **%d%%**\n\n' "$pct"
  fi
  if [[ $total_unanchored -eq 0 ]]; then
    printf '✓ All pack-derived artifacts are anchored.\n'
  else
    printf '⚠ %d pack-derived artifact(s) lack a `## Project-specific (anchored)` block or have it without any `path:line` citation.\n' "$total_unanchored"
    printf '\nNext: run `apply-anchors.sh %s` (M25.3) to populate from `_codebase-scan.md` + `codebase-profile.md`.\n' "$TARGET"
  fi
} > "$REPORT"

# stderr summary
if [[ $QUIET -eq 0 ]]; then
  echo "Anchoring audit: $total_anchored/$total_eligible anchored, $total_unanchored unanchored ($total_orphans orphans skipped). Report: $REPORT" >&2
fi

if [[ $STRICT -eq 1 && $total_unanchored -gt 0 ]]; then
  echo "REFUSED — $total_unanchored pack-derived artifact(s) lack project anchoring (--strict)." >&2
  exit 1
fi
exit 0
