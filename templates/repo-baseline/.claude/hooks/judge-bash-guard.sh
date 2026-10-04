#!/usr/bin/env bash
# PreToolUse hook (Bash · Read|Grep|Glob · Agent|Task) — the judge stays a judge.
#
# Applies only to judges: agents whose `agent_type` in the hook input is listed in
# REFRACT_JUDGE_AGENTS (default `verifier`). Identity comes from Claude Code, not from the model.
#   Bash            tests, test runners, linters / type checkers / scanners in check mode, read-only
#                   shell and git, probes to localhost, scratch files under /tmp. No repository
#                   write, no git write, no commit messages, no network past localhost.
#   Read|Grep|Glob  no builder narrative: run ledgers, commit messages, session logs, status entries.
#   Agent|Task      brief-lint on a dispatch TO a judge: run_id + mode + paths, never "I implemented…",
#                   "all tests pass", "safe to merge", a ledger or PR text
#                   (templates/snippets/delegation-brief.md).
# Every other agent, and the main session, passes untouched (fast path below: no python started).
# Exit 2 = deny (stderr says why). Opt out per project: .claude/.no-judge-guard
# Engine: .claude/scripts/judge-guard.py — no python3 → a judge's Bash is refused (fail closed).
set -uo pipefail
[ -f ".claude/.no-judge-guard" ] && exit 0
payload=$(cat)
case "$payload" in
  *'"agent_type"'*|*'"subagent_type"'*) ;;
  *) exit 0 ;;
esac
if ! command -v python3 >/dev/null 2>&1 || [ ! -f .claude/scripts/judge-guard.py ]; then
  case "$payload" in
    *'"agent_type":"verifier"'*|*'"agent_type": "verifier"'*)
      case "$payload" in *'"tool_name":"Bash"'*|*'"tool_name": "Bash"'*)
        echo "Blocked by judge-guard: python3 or .claude/scripts/judge-guard.py is missing, so a judge's commands cannot be checked — refused." >&2
        exit 2 ;;
      esac ;;
  esac
  exit 0
fi
printf '%s' "$payload" | python3 .claude/scripts/judge-guard.py
