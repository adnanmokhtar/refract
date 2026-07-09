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

# Extract the `paths:` glob list from a rule's frontmatter (empty if none).
rule_globs() {
  awk '
    NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
    /^---[[:space:]]*$/ { d++; if (d==2) exit; next }
    d==1 && /^paths:/ { inp=1; next }
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
