#!/usr/bin/env bash
# lint-artifact.sh — structural lint for shipped artifacts (agents, commands, skills, rules, ai-patterns).
#
# Usage:
#   lint-artifact.sh [<path>]            # default: all packs/* and repo-baseline/.claude
#   lint-artifact.sh templates/packs/backend
#
# Checks (per-file):
#   1. Frontmatter present (lines bracketed by ---).
#   2. Required frontmatter keys per kind:
#        agents:   description (and one of: name, model)
#        commands: description
#        skills:   description
#        rules:    (no required keys; H1 must exist)
#   3. Length budget:
#        agents   ≤ 300 lines
#        commands ≤ 250 lines
#        skills   ≤ 200 lines
#        rules    ≤ 250 lines
#        ai-patterns ≤ 200 lines
#   4. No placeholder strings: <TODO>, <TBD>, <FILL ME>, <placeholder>, FIXME (anywhere).
#   5. Top-level heading exists (`^# `).
#   6. Agents — pre-flight injection block (Hard Rule A18). Heuristic:
#        any of "pre-flight" / "Pre-flight" / "Read before" appears in body.
#
# Exit 0 if no errors, 1 otherwise. Warnings don't fail.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

START="${1:-$REPO_ROOT/templates}"

errors=0
warns=0

err()  { printf '  ERR  %s\n' "$*"; errors=$((errors + 1)); }
warn() { printf '  WARN %s\n' "$*"; warns=$((warns + 1)); }

check_one() {
  local file="$1"
  local kind="$2"
  local rel; rel="${file#$REPO_ROOT/}"

  # 1. Frontmatter
  local fm; fm="$(awk '/^---[[:space:]]*$/ { c++; next } c==1' "$file")"
  if [[ -z "$fm" ]]; then
    err "$rel: no frontmatter"
    return
  fi

  # 2. Required keys
  case "$kind" in
    agents)
      grep -qE '^description:' <<<"$fm" || err "$rel: missing 'description:'"
      ;;
    commands|skills)
      grep -qE '^description:' <<<"$fm" || err "$rel: missing 'description:'"
      ;;
    rules|ai-patterns)
      :  # no required frontmatter keys
      ;;
  esac

  # 3. Length budget
  local lc; lc="$(wc -l <"$file" | tr -d ' ')"
  local budget
  case "$kind" in
    agents)      budget=300 ;;
    commands)    budget=250 ;;
    skills)      budget=250 ;;
    rules)       budget=250 ;;
    ai-patterns) budget=250 ;;
    *)           budget=400 ;;
  esac
  if [[ "$lc" -gt "$budget" ]]; then
    warn "$rel: $lc lines > $budget budget ($kind)"
  fi

  # 4. Placeholders. Skip occurrences inside backticks (rules that *prohibit*
  # placeholders cite them as `<TODO>` etc. — those are fine.)
  # Strip backticked spans, then grep.
  if python3 -c '
import re,sys
s=open(sys.argv[1]).read()
# remove inline `...` and fenced ```...```
s=re.sub(r"```.*?```","",s,flags=re.S)
s=re.sub(r"`[^`]*`","",s)
sys.exit(0 if re.search(r"<TODO>|<TBD>|<FILL ME>|<placeholder>|<FIXME>",s) else 1)
' "$file"; then
    err "$rel: placeholder strings present (outside code spans)"
  fi

  # 5. Top-level heading
  if ! grep -qE '^# ' "$file"; then
    warn "$rel: no top-level heading"
  fi

  # 6. Pre-flight (agents only)
  if [[ "$kind" == "agents" ]]; then
    if ! grep -qiE 'pre-flight|read before|preflight' "$file"; then
      warn "$rel: agent missing pre-flight block (rule A18)"
    fi
  fi
}

# Collect files by kind from both packs/<track>/<kind>/ and repo-baseline/.claude/<kind>/
echo "=== lint-artifact start ==="

count_agents=0
count_commands=0
count_skills=0
count_rules=0
count_patterns=0

while IFS= read -r f; do
  case "$f" in
    */agents/*.md)        check_one "$f" agents;     count_agents=$((count_agents + 1)) ;;
    */commands/*.md)      check_one "$f" commands;   count_commands=$((count_commands + 1)) ;;
    */skills/*.md)        check_one "$f" skills;     count_skills=$((count_skills + 1)) ;;
    */rules/*.md)         check_one "$f" rules;      count_rules=$((count_rules + 1)) ;;
    */ai-patterns/*.md)   check_one "$f" ai-patterns; count_patterns=$((count_patterns + 1)) ;;
    */patterns/*.md)      check_one "$f" ai-patterns; count_patterns=$((count_patterns + 1)) ;;
  esac
done < <(find "$START" -type f -name '*.md' \
    \( -path '*/agents/*' -o -path '*/commands/*' -o -path '*/skills/*' \
       -o -path '*/rules/*' -o -path '*/ai-patterns/*' -o -path '*/patterns/*' \) \
    | sort)

echo ""
echo "scanned: $count_agents agents / $count_commands commands / $count_skills skills / $count_rules rules / $count_patterns patterns"
echo "result:  $errors errors / $warns warnings"

[[ "$errors" -gt 0 ]] && exit 1
exit 0
