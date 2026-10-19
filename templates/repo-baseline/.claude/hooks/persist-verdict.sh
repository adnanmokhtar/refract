#!/usr/bin/env bash
# SubagentStop hook (matcher: the verifier) — persists the independent judge's verdict.
#
# The verifier holds no Write tool; it ENDS with one JSON object (schema refract/verdict/v1). This
# hook takes that text from the hook input (`last_assistant_message`, or the subagent's transcript
# when it reported through SubagentHandback), validates it against .claude/schemas/verdict.schema.json
# and the rules a schema cannot state (every locked criterion graded once; a PASS carries exit 0 and
# an oracle that expresses the EARS clause; a regression PASS cites its RED record; a kept finding
# carries proof), stamps the signer from THIS input — never from the model — plus the authors and the
# scope fingerprint, and writes ai/runs/<run_id>/verdict.json (refute mode: verdict-refute.json).
# Refute mode also appends each refuted candidate to ai/dynamic/review-dismissals.jsonl (spec § 5.8).
#   exit 2  malformed or unsupported output — stderr goes back to the verifier, which redoes it
#   exit 0  persisted, or not the verifier's stop
# Engine: .claude/scripts/refract_records.py persist-verdict. Contract: templates/snippets/delegation-brief.md.
set -uo pipefail
if ! command -v python3 >/dev/null 2>&1; then
  echo "persist-verdict: python3 not found — the verdict was NOT persisted, so the run cannot close COMPLETE." >&2
  exit 0
fi
[ -f .claude/scripts/refract_records.py ] || { echo "persist-verdict: .claude/scripts/refract_records.py missing — re-run apply-baseline-sync.sh" >&2; exit 0; }
exec python3 .claude/scripts/refract_records.py persist-verdict
