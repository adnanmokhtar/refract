#!/usr/bin/env bash
# scaffold.sh — writes the refresh checklist skeleton.
# Output: <target>/.claude/_demo-report.md
set -euo pipefail
cat >"$1/.claude/_demo-report.md" <<'REPORT'
## 1. Existing artifact inventory

## 2. Decisions preserved

## 3. Validated user corrections

REPORT
