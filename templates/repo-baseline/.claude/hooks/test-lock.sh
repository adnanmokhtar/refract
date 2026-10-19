#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit|NotebookEdit and Bash) — the builder never edits the tests
# that judge it.
#
# A run's acceptance contract (ai/runs/<run>/acceptance.json) and every test it names are hashed into
# .claude/locks/<run>.json by .claude/scripts/lock-acceptance.sh before production code is written.
# From then on:
#   * an edit to a locked file is DENIED, unless a human reopened the lock (`lock-acceptance.sh
#     --reopen <run> --reason=…`) AND the editing agent is the one the reopen names (default
#     `test-engineer`; the human may name `main`). Agent identity is the `agent_type` Claude Code puts
#     in every hook input fired inside a subagent (absent = the main session, recorded as `main`).
#   * reopening is ASKED, never auto-approved: the hook returns permissionDecision "ask" so the human
#     sees the prompt even in auto mode; with prompts off (bypassPermissions / dontAsk) it is denied.
#   * hook-owned records — .claude/locks/, .claude/evidence/, ai/runs/*/verdict*.json,
#     ai/runs/*/reviews/, ai/dynamic/review-dismissals.jsonl — are never written through a tool.
#   * a human dismissal (`review-dismissals.py dismiss`) is ASKED like a reopen, denied with prompts off.
#   * a Bash command that names a locked file or a record AND has a write shape (redirect, tee,
#     sed -i, cp/mv/rm, git checkout/restore, an inline interpreter) is denied. Best effort: the
#     authoritative check is gate-check.py G0, which re-hashes every locked file at Stop and in CI.
# Every allowed edit is appended to .claude/evidence/edits.jsonl (path + agent_type): the authors a
# verdict is stamped with, so a judge can never sign its own change.
# Exit 2 = deny (stderr says why and what to do instead). Opt out per project: .claude/.no-test-lock
set -uo pipefail
[ -f ".claude/.no-test-lock" ] && exit 0
payload=$(cat)
case "$payload" in
  *'"tool_name":"Bash"'*|*'"tool_name": "Bash"'*)
    # Fast path: no lock, no record path, no reopen in the command → nothing to guard.
    if ! ls .claude/locks/*.json >/dev/null 2>&1; then
      case "$payload" in *lock-acceptance*|*refract_records*|*ai/runs/*|*.claude/evidence*|*.claude/locks*|*review-dismissals*) ;; *) exit 0 ;; esac
    fi ;;
esac
if ! command -v python3 >/dev/null 2>&1 || [ ! -f .claude/scripts/refract_records.py ]; then
  # Degraded: still refuse a tool write to a hook-owned record; locks cannot be read without python3.
  case "$payload" in
    *'"file_path"'*'.claude/locks/'*|*'"file_path"'*'.claude/evidence/'*|*'"file_path"'*'/verdict'*'.json"'*|*'"file_path"'*'review-dismissals.jsonl"'*)
      echo "Blocked by test-lock: hook-owned record (python3 or refract_records.py is missing, so locks are not checked)." >&2
      exit 2 ;;
  esac
  exit 0
fi
printf '%s' "$payload" | python3 .claude/scripts/refract_records.py guard
