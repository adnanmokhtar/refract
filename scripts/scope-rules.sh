#!/usr/bin/env bash
# scope-rules.sh — inject a `paths:` glob into rule frontmatter so a rule loads
# only when Claude touches a matching file (native Claude Code path-scoped rules).
#
# Used by Phase 4.2 apply to scope TRACK/DOMAIN rules to their detected source root,
# preventing cross-track context pollution in full-stack / monorepo projects.
# Core baseline rules (read-before-write, code-quality, …) are universal — do NOT scope them.
#
# Usage:   scope-rules.sh <rule-file-or-dir> <glob>[,<glob>...]
# Example: scope-rules.sh .claude/rules/frontend-principles.md "apps/web/**,packages/ui/**"
#          scope-rules.sh .claude/rules/backend-principles.md "src/server/**"
#
# Idempotent: a rule that already declares `paths:` is left unchanged.

set -uo pipefail

target="${1:?usage: scope-rules.sh <file|dir> <glob[,glob...]>}"
globs="${2:?usage: scope-rules.sh <file|dir> <glob[,glob...]>}"

# Build a YAML flow-seq: paths: ["a/**", "b/**"]
yaml_arr() {
  local out="" g
  IFS=',' read -ra parts <<< "$1"
  for g in "${parts[@]}"; do
    g="$(echo "$g" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$g" ] && continue
    [ -n "$out" ] && out="$out, "
    out="$out\"$g\""
  done
  echo "[$out]"
}

inject() {
  local f="$1"
  [ -f "$f" ] || return 0
  # Must start with a frontmatter block.
  head -n1 "$f" | grep -q '^---$' || { echo "skip (no frontmatter): $f" >&2; return 0; }
  # Already scoped?
  awk '/^---$/{c++; next} c==1 && /^paths:/{found=1} c==2{exit} END{exit !found}' "$f" \
    && { echo "skip (already scoped): $f" >&2; return 0; }

  local arr; arr="$(yaml_arr "$globs")"
  # Insert `paths:` right after the opening `---`.
  awk -v line="paths: $arr" 'NR==1{print; print line; next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  echo "scoped: $f -> paths: $arr" >&2
}

if [ -d "$target" ]; then
  for f in "$target"/*.md; do inject "$f"; done
else
  inject "$target"
fi
