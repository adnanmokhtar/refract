#!/usr/bin/env bash
# smoke.sh <base-url> [--expect-sha <sha>]: the health route answers, and, when asked, /version names the sha.
set -euo pipefail
url="$1"; shift || true
expect=""
if [ "${1:-}" = "--expect-sha" ]; then expect="$2"; fi
curl -fsS --retry 5 --retry-delay 3 "$url/health" > /dev/null
if [ -n "$expect" ]; then
  served="$(curl -fsS "$url/version")"
  [ "$served" = "$expect" ] || { echo "serving $served, expected $expect" >&2; exit 1; }
fi
