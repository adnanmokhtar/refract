#!/usr/bin/env bash
# add-related-sections.sh — append a "## Related" section to commands + agents that lack one.
#
# For each command/agent under templates/packs/<pack>/<kind>/, generates a
# Related section listing:
#   - sibling commands/agents in the same pack
#   - patterns in the same pack
#   - rules in the same pack
#
# Idempotent: files that already have ## Related are skipped.
# Default dry-run; --apply to write.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

added=0
skipped=0

for pack_dir in "$REPO_ROOT"/templates/packs/*/; do
  pack="$(basename "$pack_dir")"
  [[ "$pack" == _* ]] && continue

  for kind in commands agents; do
    kind_dir="$pack_dir$kind"
    [[ -d "$kind_dir" ]] || continue

    # Build sibling lists once per pack/kind
    siblings=""
    while IFS= read -r f; do
      base="$(basename "$f" .md)"
      [[ "$base" == _* ]] && continue
      [[ -z "$siblings" ]] && siblings="$base" || siblings="$siblings $base"
    done < <(find "$kind_dir" -maxdepth 1 -name '*.md' -not -name '_*' | sort)

    patterns=""
    if [[ -d "$pack_dir/ai-patterns" ]]; then
      while IFS= read -r f; do
        base="$(basename "$f" .md)"
        [[ "$base" == _* ]] && continue
        [[ -z "$patterns" ]] && patterns="$base" || patterns="$patterns $base"
      done < <(find "$pack_dir/ai-patterns" -maxdepth 1 -name '*.md' -not -name '_*' | sort)
    fi

    rules=""
    if [[ -d "$pack_dir/rules" ]]; then
      while IFS= read -r f; do
        base="$(basename "$f" .md)"
        [[ "$base" == _* ]] && continue
        [[ -z "$rules" ]] && rules="$base" || rules="$rules $base"
      done < <(find "$pack_dir/rules" -maxdepth 1 -name '*.md' -not -name '_*' | sort)
    fi

    # Iterate each file in this kind and append if missing
    while IFS= read -r f; do
      base="$(basename "$f" .md)"
      [[ "$base" == _* ]] && continue

      if grep -q "^## Related" "$f"; then
        skipped=$((skipped + 1))
        continue
      fi

      # Build the Related section, excluding the file itself from siblings
      sibs_out=""
      for s in $siblings; do
        [[ "$s" == "$base" ]] && continue
        if [[ "$kind" == "commands" ]]; then
          sibs_out="$sibs_out\n- \`/$s\` — sibling command in $pack pack"
        else
          sibs_out="$sibs_out\n- \`@$s\` — sibling agent in $pack pack"
        fi
      done

      pats_out=""
      for p in $patterns; do
        pats_out="$pats_out\n- \`ai/patterns/$p.md\`"
      done

      rules_out=""
      for r in $rules; do
        rules_out="$rules_out\n- \`.claude/rules/$r.md\`"
      done

      related_block=$'\n## Related\n'
      [[ -n "$sibs_out" ]]   && related_block="$related_block"$'\n### Sibling '"$kind"$' in '"$pack"$' pack'$"$sibs_out"$'\n'
      [[ -n "$pats_out" ]]   && related_block="$related_block"$'\n### Patterns'$"$pats_out"$'\n'
      [[ -n "$rules_out" ]]  && related_block="$related_block"$'\n### Rules'$"$rules_out"$'\n'

      if [[ "$APPLY" -eq 1 ]]; then
        printf '%b' "$related_block" >> "$f"
        echo "  added  $pack/$kind/$base"
      else
        echo "  would-add  $pack/$kind/$base"
      fi
      added=$((added + 1))
    done < <(find "$kind_dir" -maxdepth 1 -name '*.md' -not -name '_*' | sort)
  done
done

echo ""
echo "summary: $added added (or would-add) / $skipped skipped (already had ## Related)"
[[ "$APPLY" -eq 0 ]] && echo "(dry run — pass --apply to write)"
