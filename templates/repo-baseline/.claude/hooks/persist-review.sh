#!/usr/bin/env bash
# SubagentStop hook (every agent but the verifier) — persists a review lens's candidate findings.
#
# A read-only reviewer that was briefed with a run_id ends with one JSON object (schema
# refract/findings/v1). This hook validates it against .claude/schemas/findings.schema.json and the
# posting bar (templates/snippets/posting-bar.md: at most 5 NITs; IMPORTANT only from round 2; no
# style finding where a formatter is configured; every claim restated), stamps signer / authors /
# scope / round from the hook input and git, and writes ai/runs/<run_id>/reviews/<agent>-<lens>.json.
# An agent whose output carries no refract/findings/v1 object is not a typed reviewer: nothing happens.
# An investigator instance (/investigate-incident) ends with a refract/hypotheses/v1 object instead: it is
# validated (a supported hypothesis cites evidence and a root-cause line, a refuted one cites contradicting
# evidence), stamped and MERGED by hypothesis id into ai/runs/<run_id>/reviews/hypotheses.json.
#   exit 2  malformed output or a posting-bar breach — stderr goes back to the reviewer
#   exit 0  persisted, or nothing to persist
# Engine: .claude/scripts/refract_records.py persist-review.
set -uo pipefail
command -v python3 >/dev/null 2>&1 || exit 0
[ -f .claude/scripts/refract_records.py ] || exit 0
exec python3 .claude/scripts/refract_records.py persist-review
