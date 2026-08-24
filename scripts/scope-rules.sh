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

# 🔴 BLOCK LIST, NOT FLOW SEQUENCE. THE HOOK CAN ONLY READ ONE OF THEM.
#
# This wrote `paths: ["a/**", "b/**"]`. The consumer — inject-path-rules.sh `rule_globs()` —
# walks the frontmatter for `^paths:` and then reads the `- item` lines beneath it. Given a
# flow sequence it finds the key, finds no `- ` lines, and returns NOTHING.
#
# 📏 A rule scoped by this script therefore loaded NEVER. wire-rule-imports.sh sees the
# `paths:` key and correctly drops it from the CLAUDE.md always-loaded imports; the hook then
# cannot match it, so it is never injected either. Both tiers disown it and the file sits on
# disk looking configured. Measured on a fixture: `scope-rules.sh … "**/payment*/**"` then
# rule_globs → 0 globs.
#
# What makes it worse than a normal bug is WHOSE advice it is. wire-rule-imports.sh prints
# this exact command as the remedy when a rule will not fit the budget, and audit-setup.sh
# repeats it. Anyone who followed the framework's own instruction silently deleted the rule
# they were trying to keep — and the audit's own note about the path-scoped tier being "dead"
# was written about the hook not being registered. It was registered. This was the other half.
#
# The nine scoped rules on the live projects are all block form, written by project
# generation rather than by this script, which is why the breakage never surfaced there.
yaml_block() {
  local g
  IFS=',' read -ra parts <<< "$1"
  for g in "${parts[@]}"; do
    g="$(echo "$g" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$g" ] && continue
    printf '  - "%s"\n' "$g"
  done
}

inject() {
  local f="$1"
  [ -f "$f" ] || return 0
  # Must start with a frontmatter block.
  head -n1 "$f" | grep -q '^---$' || { echo "skip (no frontmatter): $f" >&2; return 0; }
  # Already scoped?
  awk '/^---$/{c++; next} c==1 && /^paths:/{found=1} c==2{exit} END{exit !found}' "$f" \
    && { echo "skip (already scoped): $f" >&2; return 0; }

  local blk; blk="$(yaml_block "$globs")"
  [ -z "$blk" ] && { echo "skip (no usable globs): $f" >&2; return 0; }
  # Insert `paths:` plus its block list right after the opening `---`.
  { head -n1 "$f"; printf 'paths:\n'; printf '%s\n' "$blk"; tail -n +2 "$f"; } > "$f.tmp" && mv "$f.tmp" "$f"
  echo "scoped: $f -> paths: $(printf '%s' "$globs")" >&2
}

if [ -d "$target" ]; then
  for f in "$target"/*.md; do inject "$f"; done
else
  inject "$target"
fi
