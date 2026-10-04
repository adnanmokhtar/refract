#!/usr/bin/env bash
# lock-acceptance.sh — freeze a run's acceptance contract before any production code is written.
#
# Usage:
#   lock-acceptance.sh <run-id>                               lock (or re-seal a reopened lock)
#   lock-acceptance.sh --reopen <run-id> --reason='<why>' [--editor=<agent|main>]
#                                                             a HUMAN reopens it (test-lock.sh asks)
#   lock-acceptance.sh --check  <run-id>                      exit 0 iff every locked file matches
#   lock-acceptance.sh --status <run-id>                      print the lock
#
# WHAT IS LOCKED. ai/runs/<run-id>/acceptance.json (schema: .claude/schemas/acceptance.schema.json)
# and every test file its criteria name, by SHA-256, into .claude/locks/<run-id>.json — committed
# with the change, so CI re-checks the same hashes (gate-check.py G0). Locking refuses a contract
# that does not validate or whose tests are not written yet: the tests exist, and fail, first.
#
# WHY. A builder told to turn red tests green has cheaper moves than the fix: edit the test, delete
# the assertion, widen the tolerance, rewrite the criterion. Offered an explicit way to abort,
# GPT-5's test exploitation fell from 54% to 9% (ImpossibleBench). SPEC_CONFLICT is that abort —
# a builder that finds the contract wrong STOPS and says so — and the lock removes the edit as an
# alternative, so the cheap move is no longer available at all.
#
# CHANGING A LOCKED CONTRACT is a human act in three steps: --reopen (test-lock.sh turns this into a
# permission prompt the human must approve; refused outright when prompts are off), the editor it
# names changes the files (default `test-engineer`; the human may name `main`), then
# `lock-acceptance.sh <run-id>` re-seals. Every step lands in the lock's `history`.
#
# Idempotent: re-locking unchanged content writes nothing. Exit: 0 ok · 1 refused / mismatch.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "lock-acceptance: python3 is required" >&2; exit 1; }
mode=lock; run=""; reason=""; editor=""
while [ $# -gt 0 ]; do
  case "$1" in
    --reopen) mode=reopen; shift ;;
    --check)  mode=check; shift ;;
    --status) mode=status; shift ;;
    --reason=*) reason="${1#*=}"; shift ;;
    --editor=*) editor="${1#*=}"; shift ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "lock-acceptance: unknown flag $1" >&2; exit 1 ;;
    *) run="$1"; shift ;;
  esac
done
[ -n "$run" ] || { echo "usage: lock-acceptance.sh [--reopen|--check|--status] <run-id>" >&2; exit 1; }
case "$mode" in
  lock)   exec python3 "$DIR/refract_records.py" lock "$run" ;;
  reopen) exec python3 "$DIR/refract_records.py" reopen "$run" "--reason=$reason" ${editor:+"--editor=$editor"} ;;
  check)  exec python3 "$DIR/refract_records.py" check "$run" ;;
  status) exec python3 "$DIR/refract_records.py" status "$run" ;;
esac
