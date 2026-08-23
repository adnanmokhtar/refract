#!/usr/bin/env bash
# audit-command-dry.sh — fail when command markdown duplicates SOLID/clean-code prose or
# the canonical Phase 3 ALWAYS list without linking the shared snippets / governance pointer.
#
# Scans: commands/*.md, templates/packs/*/commands/*.md
# Skips: */_examples/*, */references/*, basename STACK.md
#
# Exit 1 if any FAIL; 0 if warnings only.

set -euo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
fail=0
warn=0

should_skip() {
  local f=$1
  [[ "$f" == *"/_examples/"* ]] && return 0
  [[ "$f" == *"/references/"* ]] && return 0
  [[ "$(basename "$f")" == "STACK.md" ]] && return 0
  return 1
}

check_file() {
  local f=$1
  should_skip "$f" && return 0

  # FAIL — SOLID / clean-code vocabulary without governance pointer
  # Word-boundary on SOLID avoids matching "consolidates" / unrelated tokens.
  # The `\bSOLID\b` / `solid-violation` tokens are matched CASE-SENSITIVELY: the principle
  # is always uppercase, so this avoids false-matching the SolidJS framework ("Solid" in a
  # "React / Next / Svelte / Solid / Angular" stack list). The prose phrases stay case-insensitive.
  if grep -qE '\bSOLID\b|solid-violation' "$f" || \
     grep -qiE 'Single Responsibility|Open/Closed|Liskov|Interface Segregation|Dependency Inversion|\bclean code\b' "$f"; then
    if ! grep -q 'core-discipline\.md' "$f"; then
      echo "FAIL: $f — SOLID/clean-code keywords without templates/governance/core-discipline.md link"
      fail=$((fail + 1))
    fi
  fi

  # FAIL — full pasted Phase 3 ALWAYS list (all 7 canonical path markers) without snippet link
  local hits=0
  grep -qF '`CLAUDE.md`' "$f" && hits=$((hits + 1))
  grep -qF '.claude/codebase-profile.md' "$f" && hits=$((hits + 1))
  grep -qF 'ai/conventions.md' "$f" && hits=$((hits + 1))
  grep -qF 'ai/business-domain.md' "$f" && hits=$((hits + 1))
  grep -qF 'ai/project-goals.md' "$f" && hits=$((hits + 1))
  grep -qF 'ai/dynamic/feedback-learned.md' "$f" && hits=$((hits + 1))
  grep -qF 'ai/status.md' "$f" && hits=$((hits + 1))
  if [[ "$hits" -ge 7 ]] && ! grep -q 'phase-3-always-reads\.md' "$f"; then
    echo "FAIL: $f — full Phase 3 ALWAYS paste ($hits/7 markers) without phase-3-always-reads.md link"
    fail=$((fail + 1))
  fi

  # WARN — duplicated hand-wave halt heading without canonical snippet link
  if grep -qE '^## Mechanical halt — hand-wave grep' "$f"; then
    if ! grep -q 'hand-wave-grep\.md' "$f"; then
      echo "WARN: $f — Mechanical halt — hand-wave grep section without templates/snippets/hand-wave-grep.md link"
      warn=$((warn + 1))
    fi
  fi
}

while IFS= read -r -d '' f; do
  check_file "$f"
done < <(find "$ROOT/commands" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null || true)

while IFS= read -r -d '' f; do
  check_file "$f"
done < <(find "$ROOT/templates/packs" -type f -path '*/commands/*.md' -print0 2>/dev/null || true)

echo "--- audit-command-dry: FAIL=$fail WARN=$warn ---"
if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
exit 0
