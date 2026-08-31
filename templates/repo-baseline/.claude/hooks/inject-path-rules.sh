#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit) — path-scoped rule injection.
#
# Rules in .claude/rules/ come in two tiers:
#   • always-loaded  — no `paths:` frontmatter; wired in via the project CLAUDE.md
#                      @-imports, so they cost tokens every session.
#   • path-scoped    — carry `paths:` frontmatter (a YAML list of globs). NOT
#                      imported by CLAUDE.md. This hook injects one, as
#                      additionalContext, exactly when Claude edits a file the
#                      rule governs — free until you're near a matched file.
#
# Context-only: always exits 0, never blocks. Needs jq to build the JSON safely;
# degrades to a silent no-op without it. Per-session dedup (keyed on session_id)
# means a rule is injected once, not on every matching edit.
#
# Opt out per project: create .claude/.no-path-rules

set -uo pipefail

[ -f ".claude/.no-path-rules" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
[ -d ".claude/rules" ] || exit 0

payload=$(cat)
file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -z "$file_path" ] && exit 0

# Normalise an absolute path to repo-relative so globs like "src/api/**" match.
rel="$file_path"
case "$rel" in "$PWD"/*) rel="${rel#"$PWD"/}" ;; esac

# glob → anchored ERE. Handles **/  /**  **  *  and literal dots.
glob_to_re() {
  local g="$1"
  g=${g//./\\.}
  g=${g//\*\*\//$'\x01'}   # **/
  g=${g//\/\*\*/$'\x02'}   # /**
  g=${g//\*\*/$'\x03'}     # **
  g=${g//\*/[^\/]*}        # *  → single segment
  g=${g//$'\x01'/(.*\/)?}
  g=${g//$'\x02'/(\/.*)?}
  g=${g//$'\x03'/.*}
  printf '^%s$' "$g"
}

# Extract the glob list from a rule's frontmatter (empty if none).
#
# 🔴 READS `globs:` AS WELL AS `paths:`, AND EVERY VALUE SHAPE ANYONE WRITES.
#
# This read ONLY `paths:` followed by a `- item` block list. Three other shapes are in active
# use across this framework, and every one of them produced a rule that loaded NEVER:
#
#   globs: a/**/*.ts, "b/**"        <- what Phase 4.2 extraction writes (inline, key `globs:`)
#   paths: ["a/**", "b/**"]         <- what scope-rules.sh used to write (flow sequence)
#   paths:                          <- the only shape this function used to understand
#     - "a/**"
#
# The failure is silent because the OTHER half of the system is more permissive:
# wire-rule-imports.sh and audit-setup.sh C2u both test `^(paths|globs):`, so they correctly
# drop such a rule from the CLAUDE.md always-loaded imports. This hook then could not read its
# globs, so it never injected it either. Both tiers disown the rule while the file sits on disk
# looking configured.
#
# 📏 MEASURED on the reference monorepo: 8 of its 9 scoped rules were dead — base-classes, cache,
# controllers, database, dtos-mappers, events, module-structure, multi-tenancy — 3,427 tok of
# PROJECT-SPECIFIC rules, the ones extracted from that codebase and the most valuable in the
# install. They had been excluded from every turn's context and injected on no turn at all.
#
# Being liberal in what this accepts is the correct asymmetry: the budget side already treats
# all these shapes as "scoped", so anything it recognises must be readable here, or the rule
# falls between them.
rule_globs() {
  awk '
    function emit_inline(v,   n, i, parts) {
      gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", v)
      n = split(v, parts, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[i])
        gsub(/^["'\'']|["'\'']$/, "", parts[i])
        if (parts[i] != "") print parts[i]
      }
    }
    NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
    /^---[[:space:]]*$/ { d++; if (d==2) exit; next }
    d==1 && /^(paths|globs):/ {
      inp=1
      rest=$0; sub(/^(paths|globs):[[:space:]]*/, "", rest)
      if (rest != "") emit_inline(rest)
      next
    }
    d==1 && inp && /^[[:space:]]*-[[:space:]]*/ {
      line=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",line);
      gsub(/^["'\'']|["'\'']$/,"",line); if (line!="") print line; next }
    d==1 && inp && /^[^[:space:]-]/ { inp=0 }
  ' "$1"
}

# Rule body (everything after the closing frontmatter fence).
rule_body() { awk 'f{print} /^---[[:space:]]*$/{c++; if(c==2)f=1}' "$1"; }

context=""
for rule in .claude/rules/*.md; do
  [ -e "$rule" ] || continue
  globs=$(rule_globs "$rule")
  [ -z "$globs" ] && continue          # no paths: → always-loaded, skip
  matched=0
  while IFS= read -r g; do
    [ -z "$g" ] && continue
    printf '%s' "$rel" | grep -qE "$(glob_to_re "$g")" && { matched=1; break; }
  done <<< "$globs"
  [ "$matched" = 1 ] || continue

  # Per-session dedup: inject each rule at most once per session.
  name=$(basename "$rule")
  if [ -n "$session_id" ]; then
    mdir="${TMPDIR:-/tmp}/claude-pathrules/$session_id"
    mkdir -p "$mdir" 2>/dev/null || true
    [ -e "$mdir/$name" ] && continue
    : > "$mdir/$name" 2>/dev/null || true
  fi
  context+="[$name — path-scoped rule, applies to $rel]"$'\n'
  context+="$(rule_body "$rule")"$'\n\n'
done

[ -z "$context" ] && exit 0
jq -cn --arg ctx "$context" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}'
exit 0
