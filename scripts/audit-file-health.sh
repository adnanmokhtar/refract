#!/usr/bin/env bash
# audit-file-health.sh — heuristic scan of every .md / .sh file in the repo.
# Output: TSV with risk score per file, sorted descending.
# Risk signals: large size, hand-waves, rule sprawl, heavy phase ladders,
# zero inbound references, stale.
#
# Usage: bash scripts/audit-file-health.sh [--threshold N]
#        Default threshold = 5 (only show files with score >= 5).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
THRESHOLD="${1:-5}"
[[ "${1:-}" == "--threshold" ]] && THRESHOLD="${2:-5}"

cd "$ROOT"

# Files in scope: .md + .sh, excluding .git, .archive, node_modules, tests.
FILES=()
while IFS= read -r line; do FILES+=("$line"); done < <(find . -type f \( -name '*.md' -o -name '*.sh' \) \
  -not -path './.git/*' \
  -not -path './.archive/*' \
  -not -path './node_modules/*' \
  -not -path './tests/*' \
  | sort)

printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
  "score" "lines" "handwaves" "musts" "phase_ladder" "inbound_refs" "file"

for f in "${FILES[@]}"; do
  rel="${f#./}"
  lines=$(wc -l < "$f" | tr -d ' ')

  # Hand-wave count (the F039 anti-pattern: etc., ..., N+ items, and so on)
  handwaves=$(grep -cE '\betc\.|\band so on\b|\b[0-9]+\+ (filters?|buttons?|fields?|params?|columns?|items?)\b|\bdeferred to (port-phase|future)\b|\bby audit-by-inspection\b' "$f" 2>/dev/null || true)

  # MUST sprawl (rule density — heavy = many MUSTs)
  musts=$(grep -cE '\bMUST\b|\bMUST NOT\b' "$f" 2>/dev/null || true)

  # Heavy phase ladder (Phase N — repeated ≥5 times signals 7-phase ceremony)
  phase_ladder=$(grep -cE '^## Phase [1-9]|^### Phase [1-9]|Phase [1-9] —|\*\*Phase [1-9]' "$f" 2>/dev/null || true)

  # Inbound references — how many other files mention this file's basename?
  base=$(basename "$f")
  refs=$(grep -rlF "$base" --include='*.md' --include='*.sh' \
    --exclude-dir='.git' --exclude-dir='.archive' . 2>/dev/null \
    | grep -v "^./$rel$" | wc -l | tr -d ' ' || true)

  # Risk score: weight each signal.
  #   handwaves × 3 (severe)
  #   musts > 15 → +2 (rule sprawl)
  #   phase_ladder >= 5 → +3 (heavy ceremony)
  #   lines > 300 → +1, > 500 → +2
  #   refs == 0 → +2 (orphan candidate)
  score=0
  score=$(( score + handwaves * 3 ))
  [[ $musts -gt 15 ]] && score=$(( score + 2 ))
  [[ $phase_ladder -ge 5 ]] && score=$(( score + 3 ))
  [[ $lines -gt 300 ]] && score=$(( score + 1 ))
  [[ $lines -gt 500 ]] && score=$(( score + 1 ))
  [[ $refs -eq 0 ]] && score=$(( score + 2 ))

  if [[ $score -ge $THRESHOLD ]]; then
    printf "%d\t%d\t%d\t%d\t%d\t%d\t%s\n" \
      "$score" "$lines" "$handwaves" "$musts" "$phase_ladder" "$refs" "$rel"
  fi
done | sort -t$'\t' -k1,1 -nr
