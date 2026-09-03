#!/usr/bin/env bash
# tests/setup-project/run.sh — fixture runner for /setup-project's deterministic subset.
#
# Drives scripts/apply-pack.sh against fixtures, captures the deterministic
# output as a snapshot, and verifies the idempotency contract round-trips.
#
# What runs today:
#   - Phase 4.0 preflight (real)
#   - Phase 4.2.b deterministic copy (real)
#   - Managed-marker wrapping (real)
#   - Idempotency assertion (real)
# What does NOT run today:
#   - Phase 1 mode detection (LLM-driven)
#   - Phase 2 deep extraction (LLM-driven)
#   - Phase 4.6 anchoring of project-specific blocks (LLM-driven)
#   - Multi-track conflict resolution
# Those need a real CLI invocation strategy. PARTLY ADDRESSED: tests/live/run.sh drives a real
# `claude -p` against fixtures and asserts the mode decision, the stack decision and the
# provenance rule. It is not in the blocking suite — it costs money and wall-clock, needs
# credentials, and depends on a service being up, so a red run there would not mean a defect.
# Multi-track conflict resolution and Phase 4.6 anchoring are still uncovered.
#
# Modes:
#   --shape-only        Validate fixture/snapshot shape (default if no flag).
#   --apply             Apply harness to a temp copy of each fixture.
#                       Diff against snapshots/<fixture>/. Fail on diff.
#   --update-snapshots  Apply harness, then COPY output INTO snapshots/
#                       (after a manual confirm prompt).
#   --idempotency-only  Run apply twice; diff the two outputs (timestamps masked).
#                       Pass = empty diff.
#   --fixture <name>    Limit to one fixture.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES_ROOT="$REPO_ROOT/tests/setup-project/fixtures"
SNAPSHOTS_ROOT="$REPO_ROOT/tests/setup-project/snapshots"
APPLY_PACK="$REPO_ROOT/scripts/apply-pack.sh"

UPDATE=0
IDEMPOTENCY=0
SHAPE_ONLY=0
APPLY=0
SELECT_FIXTURE=""

usage() {
  sed -n '2,30p' "$0"
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update-snapshots) UPDATE=1; shift ;;
    --idempotency-only) IDEMPOTENCY=1; shift ;;
    --shape-only) SHAPE_ONLY=1; shift ;;
    --apply) APPLY=1; shift ;;
    --fixture) shift; SELECT_FIXTURE="${1:-}"; shift ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

if [[ "$UPDATE" -eq 0 && "$IDEMPOTENCY" -eq 0 && "$SHAPE_ONLY" -eq 0 && "$APPLY" -eq 0 ]]; then
  SHAPE_ONLY=1
fi

# Map fixture name → track to apply. Extend as more tracks are written.
fixture_track() {
  case "$1" in
    django)   echo "web-backend-django" ;;
    nextjs)   echo "web-frontend-nextjs" ;;
    monorepo) echo "" ;;   # multi-track; needs M6+ logic
    empty)    echo "" ;;   # bootstrap-mode; needs LLM-driven authoring
    *)        echo "" ;;
  esac
}

log()  { printf '%s\n' "$*"; }
ok()   { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*" >&2; }
warn() { printf '  WARN  %s\n' "$*"; }

pass=0
failed=0
skipped=0

# Strip volatile fields from a generated artifact tree before diffing.
# Today the only volatile field is the `applied-at:` timestamp in the report.
strip_volatile() {
  local dir="$1"
  if [[ -f "$dir/.claude/_apply-pack-report.md" ]]; then
    sed -i.bak -E 's/^applied-at:.*/applied-at: <REDACTED>/' "$dir/.claude/_apply-pack-report.md"
    rm -f "$dir/.claude/_apply-pack-report.md.bak"
  fi
  # Drop runner-internal artifacts before snapshot/diff
  rm -f "$dir/_run.log" "$dir/_idem.diff" "$dir/_diff.out"
}

run_one() {
  local fixture_name="$1"
  local fixture_dir="$FIXTURES_ROOT/$fixture_name"
  local track; track="$(fixture_track "$fixture_name")"
  local snap_dir="$SNAPSHOTS_ROOT/$fixture_name"

  log ""
  log "=== fixture: $fixture_name ==="

  if [[ "$SHAPE_ONLY" -eq 1 ]]; then
    if [[ ! -d "$fixture_dir" ]]; then fail "fixture missing"; failed=$((failed + 1)); return; fi
    if [[ -z "$track" && "$fixture_name" != "empty" && "$fixture_name" != "monorepo" ]]; then
      warn "no track mapping (extend run.sh fixture_track if intended)"; skipped=$((skipped + 1)); return
    fi
    ok "shape ok"; pass=$((pass + 1)); return
  fi

  if [[ -z "$track" ]]; then
    warn "$fixture_name: no track mapping — skipped (multi-track / LLM-only fixtures need M6+)"
    skipped=$((skipped + 1)); return
  fi

  local tmp; tmp="$(mktemp -d /tmp/m5-runner.XXXXXX)"
  trap "rm -rf '$tmp'" EXIT

  log "  running apply-pack: $track -> $tmp"
  cp -R "$fixture_dir/." "$tmp/"
  if ! "$APPLY_PACK" "$track" "$tmp" --apply >"$tmp/_run.log" 2>&1; then
    # PRINT the reason. Pointing at a file inside a temp dir is useless on CI — the runner is gone
    # by the time anyone reads the log, so a real failure arrived as "see /tmp/m5-runner.RE1xJg/
    # _run.log" and nothing else. A failure message that cannot be acted on is a failure message
    # that costs a second run to diagnose.
    fail "$fixture_name: apply-pack returned non-zero"
    printf '%s\n' "----- apply-pack output -----" >&2
    tail -40 "$tmp/_run.log" >&2 2>/dev/null || true
    printf '%s\n' "-----------------------------" >&2
    failed=$((failed + 1)); return
  fi
  ok "apply-pack succeeded"

  if [[ "$IDEMPOTENCY" -eq 1 ]]; then
    local tmp2; tmp2="$(mktemp -d /tmp/m5-runner-idem.XXXXXX)"
    local diff_out; diff_out="$(mktemp /tmp/m5-runner-idem-diff.XXXXXX)"
    trap "rm -rf '$tmp' '$tmp2' '$diff_out'" EXIT
    cp -R "$tmp/." "$tmp2/"
    "$APPLY_PACK" "$track" "$tmp" --apply >/dev/null 2>&1
    strip_volatile "$tmp"
    strip_volatile "$tmp2"
    if diff -r "$tmp" "$tmp2" >"$diff_out" 2>&1; then
      ok "idempotency: empty diff between run-1 and run-2"
      pass=$((pass + 1))
    else
      fail "idempotency: non-empty diff"
      cat "$diff_out" >&2
      failed=$((failed + 1))
    fi
    return
  fi

  if [[ "$UPDATE" -eq 1 ]]; then
    log "  updating snapshot at $snap_dir"
    if [[ -d "$snap_dir" ]]; then
      log "  (existing snapshot found — diff vs new run:)"
      strip_volatile "$tmp"
      diff -r "$snap_dir" "$tmp" 2>&1 | head -30 || true
    fi
    read -r -p "  proceed with snapshot update? [y/N] " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      strip_volatile "$tmp"
      rm -rf "$snap_dir"
      mkdir -p "$snap_dir"
      cp -R "$tmp/." "$snap_dir/"
      ok "snapshot updated"
      pass=$((pass + 1))
    else
      warn "snapshot update declined"
      skipped=$((skipped + 1))
    fi
    return
  fi

  if [[ "$APPLY" -eq 1 ]]; then
    if [[ ! -d "$snap_dir" ]]; then
      warn "$fixture_name: no snapshot recorded yet — run with --update-snapshots first"
      skipped=$((skipped + 1)); return
    fi
    local diff_out; diff_out="$(mktemp /tmp/m5-runner-diff.XXXXXX)"
    trap "rm -rf '$tmp' '$diff_out'" EXIT
    strip_volatile "$tmp"
    if diff -r "$snap_dir" "$tmp" >"$diff_out" 2>&1; then
      ok "snapshot diff: empty"
      pass=$((pass + 1))
    else
      fail "snapshot diff: non-empty"
      head -40 "$diff_out" >&2
      failed=$((failed + 1))
    fi
  fi
}

fixtures=()
if [[ -n "$SELECT_FIXTURE" ]]; then
  fixtures=("$SELECT_FIXTURE")
else
  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    fixtures+=("$(basename "$d")")
  done < <(find "$FIXTURES_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)
fi

for f in "${fixtures[@]}"; do
  run_one "$f"
done

log ""
log "result: $pass passed / $failed failed / $skipped skipped"
# A SKIP is a pass only in shape-only mode. Under --apply it means the run produced nothing to
# compare — a missing snapshot, a fixture that never applied — and that is a failure of the suite,
# not a neutral outcome. Deleting snapshots/ entirely used to print "0 failed" and exit 0.
if [[ "$failed" -gt 0 ]]; then exit 1; fi
if [[ "$SHAPE_ONLY" -eq 0 && "$pass" -eq 0 ]]; then
  log "REFUSED — --apply ran and nothing was actually compared ($skipped skipped)."
  exit 1
fi
exit 0
