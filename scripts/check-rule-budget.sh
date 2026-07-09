#!/usr/bin/env bash
# check-rule-budget.sh — guard the ALWAYS-LOADED rule budget.
#
# Two-tier rule model (see templates/repo-baseline/.claude/rules/README.md):
#   • always-loaded — no `paths:` frontmatter; @-imported by the project CLAUDE.md,
#                     so it costs tokens EVERY session. This is what we budget.
#   • path-scoped   — carries `paths:` frontmatter; injected on-match by
#                     inject-path-rules.sh. Exempt from the budget (near-zero cost).
#
# Fails (exit 1) if the always-loaded set exceeds the budget. The point is not a
# hard 1200-token diet (we deliberately always-load 4 rich foundational rules) —
# it is to force any NEW rule to justify always-loading, or carry `paths:` and be
# path-scoped instead. Token estimate = chars / 4.
#
# Budget override: RULE_BUDGET_TOKENS=<n> bash scripts/check-rule-budget.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$REPO_ROOT/templates/repo-baseline"
RULES_DIR="$BASE/.claude/rules"
BUDGET="${RULE_BUDGET_TOKENS:-6000}"

[ -d "$RULES_DIR" ] || { echo "no rules dir at $RULES_DIR"; exit 0; }

is_path_scoped() {
  # frontmatter must start on line 1 and contain a top-level `paths:` key
  head -1 "$1" | grep -qE '^---[[:space:]]*$' || return 1
  awk '/^---[[:space:]]*$/{d++; if(d==2)exit} d==1 && /^paths:/{found=1} END{exit !found}' "$1"
}

tok() { echo $(( $(wc -c < "$1") / 4 )); }

total=0
echo "Always-loaded (budgeted):"
# CLAUDE.md is always loaded and pulls the @-imports.
if [ -f "$BASE/CLAUDE.md" ]; then
  t=$(tok "$BASE/CLAUDE.md"); total=$((total+t))
  printf "  %-40s ~%5d tok\n" "CLAUDE.md" "$t"
fi
for f in "$RULES_DIR"/*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  [ "$base" = "README.md" ] && continue
  if is_path_scoped "$f"; then continue; fi
  t=$(tok "$f"); total=$((total+t))
  printf "  %-40s ~%5d tok\n" ".claude/rules/$base" "$t"
done

echo "Path-scoped (exempt — injected on match):"
any_scoped=0
for f in "$RULES_DIR"/*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  [ "$base" = "README.md" ] && continue
  if is_path_scoped "$f"; then
    any_scoped=1
    printf "  %-40s ~%5d tok  (free until matched)\n" ".claude/rules/$base" "$(tok "$f")"
  fi
done
[ "$any_scoped" = 0 ] && echo "  (none)"

echo "------------------------------------------------"
printf "always-loaded total: ~%d tokens   (budget: %d)\n" "$total" "$BUDGET"
if [ "$total" -gt "$BUDGET" ]; then
  echo "::error::always-loaded rule content (~${total} tok) exceeds the ${BUDGET}-token budget."
  echo "Trim a foundational rule, or give the new rule \`paths:\` frontmatter so it becomes path-scoped."
  exit 1
fi
echo "OK — within budget."
