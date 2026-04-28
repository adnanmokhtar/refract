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
pack_basenames_for_kind() {
  local kind="$1"
  find "$PACKS_ROOT" -mindepth 3 -maxdepth 3 -path "*/$kind/*.md" -not -name '_*' \
       -exec basename {} \; 2>/dev/null | sort -u | tr '\n' ' '
}

# ---------- Extract facts from profile/scan into one shared anchor block ----------

# Pull first non-empty content line under a numbered "## N. Heading" section in
# codebase-profile.md, normalize to a single line. Best-effort; tolerates missing
# sections by emitting "<not declared>".
profile_section_first_line() {
  local heading_pattern="$1"  # e.g. "Architecture", "Naming", "Testing"
  awk -v pat="$heading_pattern" '
    BEGIN { in_section = 0 }
    /^## [0-9]+\. / {
      if (in_section) exit
      if (index($0, pat)) in_section = 1
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

ARCH_LINE=$(profile_section_first_line "Architecture")
NAMING_LINE=$(profile_section_first_line "Naming")
TESTING_LINE=$(profile_section_first_line "Testing")
DATA_LINE=$(profile_section_first_line "Data access")
ERR_LINE=$(profile_section_first_line "Error handling")

# Top-level src dirs (cite-able paths) from _codebase-scan.md § "Top-level directories"
SRC_DIRS=$(awk '/^## 2\. Top-level/{flag=1; next} /^## [0-9]+\./{flag=0} flag && /^src\// && !/\/\//' "$SCAN" 2>/dev/null \
           | head -3 | tr '\n' ' ' | sed 's/[[:space:]]*$//')
[[ -z "$SRC_DIRS" ]] && SRC_DIRS="src/"

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
arch_ln=$(grep -nE '^## [0-9]+\. Architecture' "$PROFILE" | head -1 | cut -d: -f1)
naming_ln=$(grep -nE '^## [0-9]+\. Naming' "$PROFILE" | head -1 | cut -d: -f1)
testing_ln=$(grep -nE '^## [0-9]+\. Testing' "$PROFILE" | head -1 | cut -d: -f1)
data_ln=$(grep -nE '^## [0-9]+\. Data access' "$PROFILE" | head -1 | cut -d: -f1)
err_ln=$(grep -nE '^## [0-9]+\. Error handling' "$PROFILE" | head -1 | cut -d: -f1)

# Compose anchor block — uniform across artifacts. Round-one floor; REFINE
# specializes per-artifact based on `compute-anchor-density` scoring.
build_block() {
  cat <<BLOCK
<!-- project-specific:start -->
## Project-specific (auto-generated, regenerate with \`/setup-project --refine\`)

> Auto-populated by \`scripts/apply-anchors.sh\` from \`.claude/codebase-profile.md\` + \`.claude/_codebase-scan.md\`. Round-one floor — \`/setup-project --refine\` deepens shallow blocks based on \`compute-anchor-density\` scoring.
>
> - **Architecture** (\`codebase-profile.md:${arch_ln:-1}\`): ${ARCH_LINE:-<not declared in codebase-profile.md>}
> - **Naming** (\`codebase-profile.md:${naming_ln:-1}\`): ${NAMING_LINE:-<not declared in codebase-profile.md>}
> - **Testing** (\`codebase-profile.md:${testing_ln:-1}\`): ${TESTING_LINE:-<not declared in codebase-profile.md>}
> - **Data access** (\`codebase-profile.md:${data_ln:-1}\`): ${DATA_LINE:-<not declared in codebase-profile.md>}
> - **Error handling** (\`codebase-profile.md:${err_ln:-1}\`): ${ERR_LINE:-<not declared in codebase-profile.md>}
>
> Cite-able sources: ${MANIFESTS}, top-level: ${SRC_DIRS}.

<!-- project-specific:end -->

BLOCK
}

ANCHOR_BLOCK=$(build_block)

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
  local tmp
  tmp=$(mktemp)
  if [[ "$insert_after" -eq 0 ]]; then
    {
      printf '%s\n' "$ANCHOR_BLOCK"
      cat "$f"
    } > "$tmp"
  else
    {
      head -n "$insert_after" "$f"
      printf '\n%s\n' "$ANCHOR_BLOCK"
      tail -n +$((insert_after + 1)) "$f"
    } > "$tmp"
  fi
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
echo ""

for kind in commands agents skills rules ai-patterns; do
  tgt_dir=$(target_dir_for_kind "$kind")
  [[ -d "$tgt_dir" ]] || continue
  pack_bases=$(pack_basenames_for_kind "$kind")

  while IFS= read -r f; do
    base="$(basename "$f")"
    [[ "$base" == _* ]] && continue
    processed=$((processed + 1))

    # Pack-derived?
    if [[ " $pack_bases " != *" $base "* ]]; then
      orphans=$((orphans + 1))
      continue
    fi

    # Already anchored?
    if grep -qF '<!-- project-specific:start -->' "$f" 2>/dev/null; then
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

      inject_block "$f" "$insert_line"
      echo "  INJECT  $rel  (after line $insert_line)"
    else
      echo "  would-INJECT $kind/$base  (after line $insert_line)"
    fi
    injected=$((injected + 1))
  done < <(find "$tgt_dir" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null | sort)
done

echo ""
echo "=== summary ==="
echo "Processed:                     $processed"
echo "Injected (or would-inject):    $injected"
echo "Already anchored (skipped):    $already"
echo "Orphans (project-only):        $orphans"
if [[ "$APPLY" -eq 1 && "$injected" -gt 0 ]]; then
  echo "Backups:                       $backup_dir/"
fi
[[ "$APPLY" -eq 0 ]] && echo "Dry run — pass --apply to execute."
exit 0
