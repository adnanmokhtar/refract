#!/usr/bin/env bash
# Tool-version drift watcher (Python-driven for portability).
#
# WHY THIS EXISTS:
#   Tool adapters reference the upstream tool's docs (e.g. https://cursor.com/docs/context/skills).
#   When the tool ships a new native primitive (Cursor 2.3 added .cursor/skills/), the docs page
#   is the canonical signal. Without monitoring, our adapter docs silently drift out of date.
#
#   This script fetches every documented URL listed in each adapter's _version.json, hashes
#   the meaningful content (HTML noise stripped: timestamps, telemetry, asset URLs), and
#   compares to the recorded hash from the last verification. Drift is REPORTED but not fatal
#   (default exit 0) so this can run in CI without breaking on transient doc edits.
#
# Usage:
#   scripts/check-tool-versions.sh              # informational diff report (exit 0)
#   scripts/check-tool-versions.sh --strict     # exit 1 on any drift
#   scripts/check-tool-versions.sh --update     # refresh last_verified + last_verified_hashes
#   scripts/check-tool-versions.sh --adapter=cursor          # restrict to one adapter
#
# Network: requires outbound HTTPS to vendor docs hosts. Skip + warn on fetch failure.

set -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/scripts/check-tool-versions.py" "$@"
