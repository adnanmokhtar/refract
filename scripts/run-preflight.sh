#!/usr/bin/env bash
# run-preflight.sh — single composite invocation of all M15+M16 deterministic checks.
#
# Solves the "agent forgot to run all 4 scripts" risk: now there is ONE script.
# The orchestrator's hard rule becomes "run scripts/run-preflight.sh <target>"
# instead of "run these 4 separate scripts in order."
#
# Usage:
#   run-preflight.sh <target-repo> [--mode=refresh|refine|enhance|create] [packs...]
#
# Modes:
#   refresh / refine / enhance — runs all 4 scripts (full deterministic preflight).
#   create — runs only deep-codebase-scan + pack-coverage (skips refresh-extract;
#            CREATE has nothing to extract from).
#
# Output: 4 reports under <target>/.claude/_*.md. Exit 0 on success.
# Failure: any sub-script returns non-zero → this script exits same code.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$REPO_ROOT/scripts"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--mode=refresh|refine|enhance|create] [packs...]" >&2
  exit 2
fi

TARGET="$1"; shift
MODE="refresh"
PACKS=()
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)     MODE="${1#--mode=}"; shift ;;
    --include=*)  IFS=',' read -ra INCLUDED <<< "${1#--include=}"
                  for p in "${INCLUDED[@]}"; do
                    [[ -n "$p" ]] && PACKS+=("$p")
                  done
                  shift ;;
    --force)      FORCE=1; shift ;;
    *)            PACKS+=("$1"); shift ;;
  esac
done

# Normalize the mode string (#4): Phase 1 emits CREATE / ENHANCE-retrofit / ENHANCE-extend /
# REFRESH / REFINE; downstream string-matches lowercase create|enhance|refresh|refine.
MODE=$(printf '%s' "$MODE" | tr 'A-Z' 'a-z' | sed 's/enhance-.*/enhance/; s/refresh-.*/refresh/; s/refine-.*/refine/')

# When --force is set, propagate to the LLM-section-preserving sub-scripts
# (refresh-extract-checklist + deep-codebase-scan) so they regenerate fresh
# templates and overwrite existing LLM-filled content. Default = preserve.
FORCE_FLAG=""
[[ "$FORCE" -eq 1 ]] && FORCE_FLAG="--force"

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

echo "=== run-preflight: mode=$MODE target=$TARGET ==="
echo ""

# STEP 0 (M28): if no packs were supplied explicitly, run signal-driven track
# detection BEFORE any pack-coverage / study work. This replaces the old
# fallback ("scan all 17 packs when no tracks declared") which polluted
# frontend projects with backend/database/mobile content.
if [[ ${#PACKS[@]} -eq 0 ]]; then
  echo "[0/5] detect-tracks.sh"
  while IFS= read -r t; do
    [[ -n "$t" ]] && PACKS+=("$t")
  done < <("$SCRIPTS/detect-tracks.sh" "$TARGET" --write 2>/dev/null)
  if [[ ${#PACKS[@]} -eq 0 ]]; then
    echo "  WARN detect-tracks returned nothing — falling back to all packs"
  else
    echo "  detected: ${PACKS[*]}"
  fi
  echo ""
fi

# STEP 0.5 (M29): MCP server recommendations driven by the same signals.
# Emits the report AND merges recommended servers into <target>/.mcp.json.
# Merge semantics: user-added servers are preserved; only adds entries whose
# server key isn't already present. Never overwrites or removes.
if [[ -x "$SCRIPTS/detect-mcp.sh" ]]; then
  echo "[0.5/5] detect-mcp.sh"
  "$SCRIPTS/detect-mcp.sh" "$TARGET" --apply 2>&1 | tail -4
  echo ""
fi

# Helper: invoke a script with target + optional pack list. Avoids the
# `"${PACKS[@]:-}"` trap (expands to "" when empty, which downstream scripts
# read as a real pack-name argument and skip their auto-detect path).
run_with_packs() {
  local script="$1"; shift
  if [[ ${#PACKS[@]} -gt 0 ]]; then
    "$script" "$TARGET" "${PACKS[@]}" 2>&1 | tail -3
  else
    "$script" "$TARGET" 2>&1 | tail -3
  fi
}

# 1. Pack coverage scan — scoped to detected/declared tracks
echo "[1/4] pack-coverage-scan.sh"
run_with_packs "$SCRIPTS/pack-coverage-scan.sh"

# 2. Refresh-extract checklist — skip in CREATE mode
if [[ "$MODE" == "create" ]]; then
  echo "[2/4] refresh-extract-checklist.sh — SKIPPED (CREATE mode has nothing to extract)"
else
  echo "[2/4] refresh-extract-checklist.sh"
  "$SCRIPTS/refresh-extract-checklist.sh" "$TARGET" $FORCE_FLAG 2>&1 | tail -2
fi

# 3. Study existing — always
echo "[3/4] study-existing.sh"
run_with_packs "$SCRIPTS/study-existing.sh"

# 4. Deep codebase scan — always
echo "[4/4] deep-codebase-scan.sh"
"$SCRIPTS/deep-codebase-scan.sh" "$TARGET" $FORCE_FLAG 2>&1 | tail -2

echo ""
echo "=== preflight complete ==="
echo ""
echo "Reports written to $TARGET/.claude/:"
ls -1 "$TARGET/.claude/" 2>/dev/null | grep -E '^_(pack-coverage|refresh-extract|study-existing|codebase-scan)' | sed 's/^/  /'
echo ""
echo "Next: agent reads ALL reports, fills <TBD> sections, applies decisions in Phase 4."
echo "Phase 5 will fail the run if any required section is left <TBD> OR if any actionable row was silently skipped."
exit 0
