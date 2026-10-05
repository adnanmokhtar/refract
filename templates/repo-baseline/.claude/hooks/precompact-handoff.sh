#!/usr/bin/env bash
# PreCompact hook — the run's state survives a compaction as a file, not as a summary.
#
# Measured on Claude Code 2.1.236: the input carries `trigger` (manual | auto) and
# `custom_instructions`; every successful PreCompact hook's trimmed STDOUT is joined into the
# summariser's custom instructions; exit 2 BLOCKS the compaction. So this hook:
#   * writes ai/runs/<run>/handoff.json for each OPEN run (intent, tier, phase, phase states, loop
#     counters, files changed, the ledger's Open and Plan lines, the next phase) — or
#     .claude/evidence/handoff.json when no run is open;
#   * prints a ≤1,200-character "Preserve for the continuation: …" brief that steers the summary;
#   * ALWAYS exits 0 — a session that cannot compact is worse than one without a handoff.
# session-start.sh prints the newest handoff back when the session resumes with source "compact".
# Engine: .claude/scripts/run-handoff.py. No python3 → prints nothing, exits 0.
# Opt out per project: .claude/.no-precompact-handoff
[ -f ".claude/.no-precompact-handoff" ] && exit 0
payload=$(cat 2>/dev/null || true)
if command -v python3 >/dev/null 2>&1 && [ -f .claude/scripts/run-handoff.py ]; then
  printf '%s' "$payload" | python3 .claude/scripts/run-handoff.py write 2>/dev/null || true
fi
exit 0
