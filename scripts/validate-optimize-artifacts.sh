#!/usr/bin/env bash
# validate-optimize-artifacts.sh — enforces evidence requirements on /optimize Phase 0 output.
#
# Halts the gate if:
#   1. ai/optimize/_architecture-decisions.md is missing
#   2. Phase 0 evidence blocks (Dependency map / Responsibility map / Layer attribution / Detector runs) are missing
#   3. Detector run evidence shows zero modules scanned
#   4. Findings exist but none cite <path:line> (Trusted Summary recurrence)
#   5. Hand-wave language detected ("etc.", "...", "and so on", "deferred to phase 2", "by inspection")
#
# This script is the /optimize equivalent of validate-migration-artifacts.sh's check_section_0_evidence.
# Same anti-Trusted-Summary discipline, applied to architectural diagnosis.

set -euo pipefail

ARTIFACT="${1:-ai/optimize/_architecture-decisions.md}"
QUIET="${QUIET:-0}"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILURES=()

log_pass() {
  TOTAL_PASS=$((TOTAL_PASS + 1))
  [[ $QUIET -eq 0 ]] && echo "  ✓ $1"
}

log_fail() {
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
  FAILURES+=("$1")
  echo "  ✗ $1" >&2
}

check_artifact_exists() {
  if [[ ! -f "$ARTIFACT" ]]; then
    log_fail "architecture-decisions artifact MISSING at $ARTIFACT — Phase 0 must produce this file before /optimize can proceed to Phase 1 (foundation fixes)."
    return 1
  fi
  log_pass "architecture-decisions artifact exists at $ARTIFACT"
  return 0
}

check_phase_0_evidence() {
  # Halt #A1 enforcement: every architecture-decisions.md MUST contain the 4 evidence blocks
  # from architectural-diagnosis skill. Without them, the diagnosis is a summary not a scan
  # (F039 anti-Trusted-Summary recurrence applied to /optimize Phase 0).
  local file="$ARTIFACT"
  [[ ! -f "$file" ]] && return 0

  local blocks_required=(
    "Phase 0 — Dependency map evidence"
    "Phase 0 — Responsibility map evidence"
    "Phase 0 — Layer attribution evidence"
    "Phase 0 — Detector run evidence"
  )
  local missing=()
  for block in "${blocks_required[@]}"; do
    if ! grep -qF "$block" "$file"; then
      missing+=("$block")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_fail "Phase 0 evidence blocks missing in $file: ${missing[*]}. See architectural-diagnosis.md § \"Mandatory Phase-0 evidence emission\". A summary diagnosis without these blocks = HALT."
    return 1
  fi

  # Detector evidence: at least one detector must report a non-zero modules-scanned count
  local detectors_scanned
  detectors_scanned=$(grep -cE '^[[:space:]]*Modules scanned:[[:space:]]*[1-9][0-9]*' "$file" 2>/dev/null || echo 0)
  detectors_scanned=${detectors_scanned:-0}
  if [[ "$detectors_scanned" -lt 1 ]]; then
    log_fail "Phase 0 detector evidence has zero modules scanned in $file — detector either skipped or summary-only. Each detector MUST emit \"Modules scanned: <N>\" with N≥1."
    return 1
  fi

  # Path:line citation requirement — every finding cites at least one <path:line>
  local findings_count cited_count
  findings_count=$(grep -cE '^### F-A-[0-9]+' "$file" 2>/dev/null || echo 0)
  cited_count=$(grep -cE '<[^>]+:[0-9]+>|`[^`]+:[0-9]+`' "$file" 2>/dev/null || echo 0)
  findings_count=${findings_count:-0}
  cited_count=${cited_count:-0}
  if [[ "$findings_count" -gt 0 && "$cited_count" -lt "$findings_count" ]]; then
    log_fail "Findings without <path:line> citations in $file (findings: $findings_count, citations: $cited_count). Every finding MUST cite ≥1 source location."
    return 1
  fi

  log_pass "Phase 0 evidence: 4 blocks present, $detectors_scanned detectors with non-zero scans, $cited_count citations across $findings_count findings"
  return 0
}

check_no_handwaves() {
  # Hand-wave grep — same patterns as migration validator
  local file="$ARTIFACT"
  [[ ! -f "$file" ]] && return 0

  local scrubbed handwaves
  scrubbed=$(mktemp -t optimize-scrub.XXXXXX)
  awk '
    BEGIN { in_fence=0 }
    /^```/ { in_fence = 1 - in_fence; next }
    in_fence { next }
    {
      gsub(/`[^`]*`/, "")
      print
    }
  ' "$file" > "$scrubbed"
  handwaves=$(grep -cE '\.\.\.[[:space:]]*$|, etc\.| etc\.\)|\.\.\.[[:space:]]*\||\b[0-9]+\+[[:space:]]+(modules?|imports?|cycles?|fingerprints?)\b|\band so on\b|\bdeferred to phase 2\b|\bdeferred to tactical\b|\bby inspection\b' "$scrubbed" 2>/dev/null || echo 0)
  rm -f "$scrubbed"
  handwaves=${handwaves:-0}

  if [[ "$handwaves" -gt 0 ]]; then
    log_fail "architecture-decisions has $handwaves hand-wave(s) in $file — enumerate explicitly. Patterns flagged: \"...\", \"etc.\", \"N+ modules\", \"and so on\", \"deferred to phase 2\", \"by inspection\". Phase 0 reads source line-by-line and lists every fingerprint match."
    return 1
  fi

  log_pass "no hand-wave language in architecture-decisions"
  return 0
}

main() {
  [[ $QUIET -eq 0 ]] && echo "validate-optimize-artifacts.sh"
  [[ $QUIET -eq 0 ]] && echo "  artifact: $ARTIFACT"

  check_artifact_exists || true
  check_phase_0_evidence || true
  check_no_handwaves || true

  echo
  echo "── Summary ──"
  echo "  checks passed: $TOTAL_PASS"
  echo "  checks failed: $TOTAL_FAIL"

  if [[ $TOTAL_FAIL -gt 0 ]]; then
    echo
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
      echo "  - $f"
    done
    exit 1
  fi
  exit 0
}

main "$@"
