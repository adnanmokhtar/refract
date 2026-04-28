#!/usr/bin/env bash
# SessionStart hook — one-time briefing when a Claude session opens.
# Surfaces: session digest (compact bootstrap), branch state, learning queue, drift findings, pending decisions.

set -uo pipefail

echo "=== Session context ==="

if git rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || echo "detached")
  uncommitted=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "Branch: $branch • uncommitted files: $uncommitted"
fi

# Tier 1 context — the compact session digest is the primary bootstrap
if [ -f "ai/_session-digest.md" ]; then
  echo ""
  echo "--- 📋 Session digest (compact project bootstrap) ---"
  echo "Full file: ai/_session-digest.md"
  cat ai/_session-digest.md | head -60
  echo "..."
  echo "(read full digest with: cat ai/_session-digest.md)"
fi

# Recent Changes from status.md (if digest absent OR for cross-reference)
if [ -f "ai/status.md" ]; then
  updated=$(grep -m1 '^Updated:' ai/status.md 2>/dev/null || echo "")
  echo ""
  echo "--- ai/status.md — $updated ---"
  awk '/^## Recent Changes/{flag=1} flag' ai/status.md | head -25
fi

# Surface learning-queue items from post-commit / post-merge hooks
if [ -f "ai/dynamic/.review-queue" ] && [ -s "ai/dynamic/.review-queue" ]; then
  echo ""
  echo "--- 🔁 Learning queue (from recent commits/merges) ---"
  tail -10 ai/dynamic/.review-queue
fi

# Surface OPEN drift findings (HIGH severity only — keep noise low)
if [ -f "ai/dynamic/drift-log.md" ]; then
  HIGH_DRIFT=$(grep -c "^Severity: high" ai/dynamic/drift-log.md 2>/dev/null || echo "0")
  if [ "$HIGH_DRIFT" -gt "0" ]; then
    echo ""
    echo "--- ⚠️  Drift findings (HIGH severity, OPEN) ---"
    awk '/^### / {h=$0; next} /^Severity: high/ {print h}' ai/dynamic/drift-log.md | head -5
  fi
fi

# Surface pending decisions aging >7 days
if [ -f "ai/dynamic/decisions-pending.md" ]; then
  AGING=$(awk '/^### / {h=$0} /^Lifespan so far: [1-9][0-9]+ days/ {print h}' ai/dynamic/decisions-pending.md 2>/dev/null | head -3)
  if [ -n "$AGING" ]; then
    echo ""
    echo "--- 📌 Decisions pending (>7 days, consider /promote-decision) ---"
    echo "$AGING"
  fi
fi

# Surface READY-status learned patterns awaiting promotion
if [ -f "ai/dynamic/learned-patterns.md" ]; then
  READY=$(awk '/^### / {h=$0} /^Status: READY/ {print h}' ai/dynamic/learned-patterns.md 2>/dev/null | head -3)
  if [ -n "$READY" ]; then
    echo ""
    echo "--- ✅ Patterns READY for /promote-pattern ---"
    echo "$READY"
  fi
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  echo ""
  echo "--- Last 5 commits ---"
  git log --oneline -5 2>/dev/null || true
fi
