#!/usr/bin/env bash
# smoke-test.sh — structural smoke test for the /setup-project system.
#
# Does NOT invoke /setup-project against a real repo (that's the runner's
# job in tests/setup-project/run.sh — currently shape-only).
#
# Verifies:
#   1. All commands/*.md parse (have frontmatter; have a heading).
#   2. Every imported template file in setup-project.md exists.
#   3. Every track under templates/tracks/<name>/ passes lint-track.sh.
#   4. Every phase file declares the standard frontmatter keys.
#   5. HOT tier line budget (≤ 600 lines combined).
#   6. Sync state matches (no drift).
#   7. fixtures/ snapshot shape ok.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
warn=0

log()  { printf '%s\n' "$*"; }
ok()   { printf '  ok   %s\n' "$*"; }
err()  { printf '  ERR  %s\n' "$*"; fail=$((fail + 1)); }
warn_msg() { printf '  WARN %s\n' "$*"; warn=$((warn + 1)); }

# 1. Commands parse
log ""
log "=== 1. Commands parse ==="
for f in "$REPO_ROOT"/commands/*.md; do
  name="$(basename "$f")"
  if ! head -1 "$f" | grep -q '^---'; then
    err "$name: missing frontmatter (no leading ---)"
    continue
  fi
  if ! grep -qE '^# /' "$f"; then
    err "$name: missing top-level command heading (e.g., '# /setup-project')"
    continue
  fi
  ok "$name"
done

# 2. setup-project.md imports resolve
log ""
log "=== 2. Imports resolve ==="
imports=$(grep -oE 'templates/[A-Za-z0-9._/-]+\.md' "$REPO_ROOT/commands/setup-project.md" | sort -u)
miss=0
while IFS= read -r imp; do
  [[ -z "$imp" ]] && continue
  if [[ -f "$REPO_ROOT/$imp" ]]; then
    :
  else
    err "missing import: $imp"
    miss=$((miss + 1))
  fi
done <<<"$imports"
if [[ "$miss" -eq 0 ]]; then
  count=$(echo "$imports" | wc -l | tr -d ' ')
  ok "$count imports all resolve"
fi

# 3. Tracks lint
log ""
log "=== 3. Tracks lint ==="
if "$REPO_ROOT/scripts/lint-track.sh" >/dev/null 2>&1; then
  count=$(find "$REPO_ROOT/templates/tracks" -mindepth 1 -maxdepth 1 -type d -not -name "_*" | wc -l | tr -d ' ')
  ok "lint passed for $count tracks"
else
  err "lint-track.sh failed; run it directly to see violations"
fi

# 4. Phase files have standard frontmatter
log ""
log "=== 4. Phase frontmatter ==="
for f in "$REPO_ROOT"/templates/phases/phase-*.md; do
  name="$(basename "$f")"
  fm=$(awk '/^---[[:space:]]*$/ { c++; next } c==1' "$f")
  if [[ -z "$fm" ]]; then
    err "$name: no frontmatter"
    continue
  fi
  for key in phase name applies-to-modes; do
    if grep -qE "^${key}:" <<<"$fm" || [[ "$key" == "applies-to-modes" && "$name" == phase-4-templates.md ]] || [[ "$key" == "applies-to-modes" && "$name" == phase-5-checklist.md ]]; then
      :
    else
      warn_msg "$name: missing '$key:' in frontmatter"
    fi
  done
done
ok "phase files inspected"

# 5. HOT tier budget
log ""
log "=== 5. HOT tier budget ==="
hot_files=$(awk '
  /^  hot:[[:space:]]*$/ { in_hot = 1; next }
  /^  warm:|^  cold:/ { in_hot = 0 }
  in_hot && /^[[:space:]]+- / { gsub(/^[[:space:]]+- /, ""); print }
' "$REPO_ROOT/commands/setup-project.md")

total=0
while IFS= read -r imp; do
  [[ -z "$imp" ]] && continue
  if [[ -f "$REPO_ROOT/$imp" ]]; then
    n=$(wc -l < "$REPO_ROOT/$imp")
    total=$((total + n))
  fi
done <<<"$hot_files"

if [[ "$total" -le 600 ]]; then
  ok "HOT tier = $total lines (budget 600)"
else
  err "HOT tier = $total lines exceeds 600 budget"
fi

# 6. Sync state
log ""
log "=== 6. Sync state ==="
if "$REPO_ROOT/scripts/verify-sync.sh" >/dev/null 2>&1; then
  ok "no drift between repo and ~/.claude"
else
  err "drift detected; run scripts/verify-sync.sh for details"
fi

# 7. Fixtures shape
log ""
log "=== 7. Fixtures shape ==="
if "$REPO_ROOT/tests/setup-project/run.sh" --shape-only >/dev/null 2>&1; then
  ok "fixtures shape ok"
else
  warn_msg "fixtures shape returned non-zero (some snapshots not yet recorded; expected pre-M5)"
fi

# 8. M17 — preflight + audit regression
log ""
log "=== 8. M17 preflight + audit regression ==="
m17_tmp=$(mktemp -d /tmp/m17-smoke.XXXXXX)
trap "rm -rf '$m17_tmp'" EXIT
cp -R "$REPO_ROOT/tests/setup-project/fixtures/django/." "$m17_tmp/" 2>/dev/null
mkdir -p "$m17_tmp/.claude"

# Preflight should produce 4 reports (3 in CREATE mode — skips refresh-extract)
if "$REPO_ROOT/scripts/run-preflight.sh" "$m17_tmp" --mode=create >/dev/null 2>&1; then
  ok "run-preflight.sh CREATE mode succeeded"
else
  err "run-preflight.sh CREATE mode failed"
fi

for rpt in _pack-coverage-report.md _study-existing-report.md _codebase-scan.md; do
  if [[ -f "$m17_tmp/.claude/$rpt" ]]; then
    ok "preflight wrote $rpt"
  else
    err "preflight didn't write $rpt"
  fi
done

# Audit must REFUSE because the codebase-scan TBDs are unfilled
set +e
"$REPO_ROOT/scripts/audit-setup.sh" "$m17_tmp" --mode=create >/dev/null 2>&1
audit_exit=$?
set -e
if [[ "$audit_exit" -eq 1 ]]; then
  ok "audit-setup.sh correctly REFUSED (TBDs unfilled)"
else
  err "audit-setup.sh exited $audit_exit; expected 1 (REFUSED — TBDs should be unfilled)"
fi

# Summary
log ""
log "=== summary ==="
log "fail: $fail"
log "warn: $warn"

if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
exit 0
