#!/usr/bin/env bash
# ds-inventory.py regression: the built-in self-test, then the inventory of tree/ against expected.tsv.
# Usage: bash run.sh [--record]   (--record rewrites expected.tsv after a deliberate change)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DSI="$HERE/../../scripts/ds-inventory.py"
python3 -B "$DSI" --self-test || exit 1
out="$(python3 -B "$DSI" "$HERE/tree")" || exit 1
if [ "${1:-}" = "--record" ]; then printf '%s\n' "$out" > "$HERE/expected.tsv"; echo "recorded"; exit 0; fi
if printf '%s\n' "$out" | diff -u "$HERE/expected.tsv" - ; then echo "ds-inventory: tree matches expected.tsv"; else echo "ds-inventory: DIFF against expected.tsv" >&2; exit 1; fi
