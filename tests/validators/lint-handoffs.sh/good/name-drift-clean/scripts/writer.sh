#!/usr/bin/env bash
# writer.sh — emits the mechanical inventory.
# Output: <target>/.claude/_codebase-scan.md
set -euo pipefail
REPORT="$1/.claude/_codebase-scan.md"
printf '# scan\n' > "$REPORT"
