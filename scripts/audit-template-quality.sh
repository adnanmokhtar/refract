#!/usr/bin/env bash
# audit-template-quality.sh — comprehensive content quality audit across all pack templates.
#
# Identifies weak / thin / non-canonical content per file:
# - Commands < 80 lines (likely thin)
# - Commands missing the canonical 7-phase structure (Hard Rule A24)
# - Agents < 80 lines
# - Agents missing pre-flight block (Hard Rule A18)
# - Agents missing concrete output format
# - Skills < 60 lines (likely thin)
# - Rules < 50 lines (likely thin)
# - Patterns < 60 lines (likely thin)
#
# Output: stdout (markdown report).
# This is a candidate finder — fixes are manual.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKS_ROOT="$REPO_ROOT/templates/packs"

echo "# Template quality audit — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

declare -i thin_cmd=0 noseven_cmd=0 thin_agent=0 nopreflight_agent=0 nooutput_agent=0
declare -i thin_skill=0 thin_rule=0 thin_pattern=0

echo "## Commands"
echo ""
for f in $(find -L "$PACKS_ROOT" -path '*/commands/*.md' -not -name '_*' | sort); do
  rel="${f#$REPO_ROOT/}"
  lines=$(wc -l < "$f")
  has_phases=$(grep -cE "^## Phase [1-7]" "$f" || echo 0)
  if [[ "$lines" -lt 80 ]]; then
    echo "- THIN ($lines lines) — \`$rel\`"
    thin_cmd=$((thin_cmd + 1))
  elif [[ "$has_phases" -lt 7 ]] \
       && ! grep -q "Phases applied" "$f" \
       && ! grep -q "Phases that adapt to command type" "$f" \
       && ! grep -qE "Phase [0-9]-[0-9]+ — N/A|read-only" "$f"; then
    echo "- NON-CANONICAL ($has_phases/7 phases) — \`$rel\`"
    noseven_cmd=$((noseven_cmd + 1))
  fi
done
echo ""
echo "summary: $thin_cmd thin / $noseven_cmd non-7-phase"
echo ""

echo "## Agents"
echo ""
for f in $(find -L "$PACKS_ROOT" -path '*/agents/*.md' -not -name '_*' | sort); do
  rel="${f#$REPO_ROOT/}"
  lines=$(wc -l < "$f")
  has_preflight=$(grep -ciE "pre-?flight|read before" "$f" || echo 0)
  has_output=$(grep -ciE "## output|output format|^## Output" "$f" || echo 0)
  if [[ "$lines" -lt 80 ]]; then
    echo "- THIN ($lines lines) — \`$rel\`"
    thin_agent=$((thin_agent + 1))
  fi
  if [[ "$has_preflight" -eq 0 ]]; then
    echo "- NO-PREFLIGHT — \`$rel\`"
    nopreflight_agent=$((nopreflight_agent + 1))
  fi
  if [[ "$has_output" -eq 0 ]]; then
    echo "- NO-OUTPUT-FORMAT — \`$rel\`"
    nooutput_agent=$((nooutput_agent + 1))
  fi
done
echo ""
echo "summary: $thin_agent thin / $nopreflight_agent no-preflight / $nooutput_agent no-output-format"
echo ""

echo "## Skills"
echo ""
for f in $(find -L "$PACKS_ROOT" -path '*/skills/*.md' -not -name '_*' | sort); do
  rel="${f#$REPO_ROOT/}"
  lines=$(wc -l < "$f")
  if [[ "$lines" -lt 60 ]]; then
    echo "- THIN ($lines lines) — \`$rel\`"
    thin_skill=$((thin_skill + 1))
  fi
done
echo ""
echo "summary: $thin_skill thin"
echo ""

echo "## Rules"
echo ""
for f in $(find -L "$PACKS_ROOT" -path '*/rules/*.md' -not -name '_*' | sort); do
  rel="${f#$REPO_ROOT/}"
  lines=$(wc -l < "$f")
  if [[ "$lines" -lt 50 ]]; then
    echo "- THIN ($lines lines) — \`$rel\`"
    thin_rule=$((thin_rule + 1))
  fi
done
echo ""
echo "summary: $thin_rule thin"
echo ""

echo "## Patterns"
echo ""
for f in $(find -L "$PACKS_ROOT" -path '*/ai-patterns/*.md' -not -name '_*' | sort); do
  rel="${f#$REPO_ROOT/}"
  lines=$(wc -l < "$f")
  if [[ "$lines" -lt 60 ]]; then
    echo "- THIN ($lines lines) — \`$rel\`"
    thin_pattern=$((thin_pattern + 1))
  fi
done
echo ""
echo "summary: $thin_pattern thin"
echo ""

echo "## Pack-by-pack inventory"
echo ""
echo "| Pack | cmd | agent | skill | rule | pattern | total |"
echo "|------|-----|-------|-------|------|---------|-------|"
for pack in "$PACKS_ROOT"/*/; do
  name=$(basename "$pack")
  cmd=$(find "$pack/commands" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null | wc -l | tr -d ' ')
  agt=$(find "$pack/agents" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null | wc -l | tr -d ' ')
  skl=$(find "$pack/skills" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null | wc -l | tr -d ' ')
  rul=$(find "$pack/rules" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null | wc -l | tr -d ' ')
  pat=$(find "$pack/ai-patterns" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null | wc -l | tr -d ' ')
  total=$((cmd + agt + skl + rul + pat))
  printf "| %-20s | %3d | %3d | %3d | %3d | %3d | %5d |\n" "$name" "$cmd" "$agt" "$skl" "$rul" "$pat" "$total"
done
echo ""

echo "## TOTAL findings"
echo ""
echo "- Thin commands:        $thin_cmd"
echo "- Non-7-phase commands: $noseven_cmd"
echo "- Thin agents:          $thin_agent"
echo "- No-preflight agents:  $nopreflight_agent"
echo "- No-output agents:     $nooutput_agent"
echo "- Thin skills:          $thin_skill"
echo "- Thin rules:           $thin_rule"
echo "- Thin patterns:        $thin_pattern"
