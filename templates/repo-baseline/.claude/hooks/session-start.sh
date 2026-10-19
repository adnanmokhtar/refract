#!/usr/bin/env bash
# SessionStart hook — one-time briefing when a Claude session opens.
# Surfaces: session digest (compact bootstrap), branch state, learning queue, drift findings, pending decisions.

set -uo pipefail

# The SessionStart input carries `source` (startup | resume | clear | compact). Read it only when
# stdin is not a terminal, so a manual run (or a closed / empty stdin) still works.
ss_input=""
if [ ! -t 0 ]; then ss_input=$(cat 2>/dev/null || true); fi

echo "=== Session context ==="

# After a compaction: print the handoff precompact-handoff.sh wrote — the newest one of an OPEN
# run, else .claude/evidence/handoff.json — so the run's state is back in context as written.
case "$ss_input" in
  *'"source"'*'"compact"'*)
    # shellcheck disable=SC2012  # run ids are [a-z0-9-] (run.schema.json), so ls -t output is safe to read
    ho=$(ls -t ai/runs/*/handoff.json 2>/dev/null | while IFS= read -r f; do
      if grep -q '"status"[[:space:]]*:[[:space:]]*"open"' "$(dirname "$f")/run.json" 2>/dev/null; then
        printf '%s\n' "$f"; break
      fi
    done)
    [ -z "$ho" ] && [ -f .claude/evidence/handoff.json ] && ho=".claude/evidence/handoff.json"
    if [ -n "$ho" ]; then
      echo ""
      echo "--- Handoff (before compaction) — $ho ---"
      head -80 "$ho"
      echo "(continue from \"next\"; the run's record is run.json + ledger.md in the same directory)"
    fi ;;
esac

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

# Surface learning-queue items from post-commit / post-merge hooks.
# NOTE: this hook only PRINTS the queue — nothing auto-runs the curator. Drain it
# manually with /audit-knowledge (sweep) or /learn-from-task (scoped to current work).
if [ -f "ai/dynamic/.review-queue" ] && [ -s "ai/dynamic/.review-queue" ]; then
  QUEUE_COUNT=$( { grep -c . ai/dynamic/.review-queue 2>/dev/null || echo 0; } | tail -1 )
  echo ""
  echo "--- 🔁 Learning queue ($QUEUE_COUNT pending — surfaced for MANUAL dispatch) ---"
  tail -10 ai/dynamic/.review-queue
  echo "→ drain with: /audit-knowledge  (or /learn-from-task for the current task)"
fi

# Sink reader shared by the drift and pattern blocks: entries are `### ` headings outside code fences
# (the template's own `## Format per entry` example is fenced); a field is read in the plain
# (`Severity: high`), list (`- Severity: high`) or bold (`- **Severity:** high`) shape. A sink whose
# entries carry NONE of the field prints `format not recognised` instead of a silent 0: a project
# that redefined the sink format (KN-27) must hear that this hook cannot read it.
sink_scan() {  # $1=file $2=field $3=value regex → prints "<entries>\t<with field>\t<heading>..." lines
  awk -v F="$2" -v V="$3" '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^### / { n++; h = $0; next }
    {
      line = $0; sub(/^[[:space:]]*[-*][[:space:]]+/, "", line); gsub(/\*\*/, "", line)
      if (tolower(substr(line, 1, length(F) + 1)) == tolower(F) ":") {
        if (!(n in seen)) { seen[n] = 1; with++ }
        val = substr(line, length(F) + 2); sub(/^[[:space:]]+/, "", val)
        if (tolower(val) ~ V && h != "") { hits[++k] = h }
      }
    }
    END { printf "%d\t%d\n", n, with; for (i = 1; i <= k; i++) print hits[i] }
  ' "$1" 2>/dev/null
}

# Surface OPEN drift findings (HIGH severity only — keep noise low)
if [ -f "ai/dynamic/drift-log.md" ]; then
  DRIFT_OUT=$(sink_scan ai/dynamic/drift-log.md Severity '^high')
  DRIFT_N=$(printf '%s\n' "$DRIFT_OUT" | head -1 | cut -f1); DRIFT_W=$(printf '%s\n' "$DRIFT_OUT" | head -1 | cut -f2)
  HIGH_DRIFT=$(printf '%s\n' "$DRIFT_OUT" | sed -n '2,$p' | grep -c . || true)
  if [ "${DRIFT_N:-0}" -gt 0 ] && [ "${DRIFT_W:-0}" -eq 0 ]; then
    echo ""
    echo "--- ⚠️  drift-log: format not recognised (0/$DRIFT_N entries carry a Severity: field this hook reads) — see its ## Format per entry ---"
  elif [ "${HIGH_DRIFT:-0}" -gt 0 ]; then
    echo ""
    echo "--- ⚠️  Drift findings (HIGH severity, OPEN) ---"
    printf '%s\n' "$DRIFT_OUT" | sed -n '2,6p'
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
  PAT_OUT=$(sink_scan ai/dynamic/learned-patterns.md Status '^ready')
  PAT_N=$(printf '%s\n' "$PAT_OUT" | head -1 | cut -f1); PAT_W=$(printf '%s\n' "$PAT_OUT" | head -1 | cut -f2)
  READY=$(printf '%s\n' "$PAT_OUT" | sed -n '2,4p')
  if [ "${PAT_N:-0}" -gt 0 ] && [ "${PAT_W:-0}" -eq 0 ]; then
    echo ""
    echo "--- ✅ learned-patterns: format not recognised (0/$PAT_N entries carry a Status: field this hook reads) ---"
  elif [ -n "$READY" ]; then
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
