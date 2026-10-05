#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit|NotebookEdit) — one writer per run artifact.
#
# Every artifact of a delivery run (ai/runs/<run>/) has exactly one writer
# (templates/snippets/run-ledger.md § 2), so the agent that checks it is never the one that wrote it.
# Identity is the `agent_type` Claude Code puts in every hook input fired inside a subagent (absent =
# the main session). Engine: .claude/scripts/ownership-guard.py (role → writable globs; project
# override .claude/artifact-ownership.json).
#   * a known role (product-analyst, architect, test-engineer, ux-designer, doc-writer,
#     platform-engineer) writes only its own paths; a judge (verifier, *-reviewer, *-auditor,
#     plan-critic) writes nothing;
#   * any other agent may not write a run's role- or orchestrator-owned files, nor holdouts;
#   * the main session, while an OPEN T2/T3 run exists, does not write role-owned run artifacts
#     (it dispatches the owner), and in P6 does not edit source (it dispatches @implementer).
# Fast path: no agent_type in the payload and no open run → exit 0 without starting python.
# No python3 → allowed with a one-line note (fail open: gate-check.py and CI are the backstop).
# Exit 2 = deny (stderr names the rule and the owner). Opt out per project: .claude/.no-artifact-ownership
set -uo pipefail
[ -f ".claude/.no-artifact-ownership" ] && exit 0
payload=$(cat)
case "$payload" in
  *'"agent_type"'*) ;;
  *)
    # The main session is restricted only while a run is open.
    open_run=0
    for f in ai/runs/*/run.json; do
      [ -f "$f" ] || continue
      if grep -q '"status"[[:space:]]*:[[:space:]]*"open"' "$f" 2>/dev/null; then open_run=1; break; fi
    done
    [ "$open_run" = 1 ] || exit 0 ;;
esac
if ! command -v python3 >/dev/null 2>&1 || [ ! -f .claude/scripts/ownership-guard.py ]; then
  echo "artifact-ownership: python3 or .claude/scripts/ownership-guard.py is missing — ownership not checked (gate-check and CI still are)." >&2
  exit 0
fi
printf '%s' "$payload" | python3 .claude/scripts/ownership-guard.py guard
