#!/usr/bin/env bash
# session-start.sh - print the knowledge-layer status at the start of a session (Refract baseline hook).
set -u
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# High-severity drift and patterns ready to promote, read from the learning sinks.
HIGH_DRIFT=$( { grep -c "^Severity: high" ai/dynamic/drift-log.md 2>/dev/null || echo 0; } | tail -1 )
READY_PATTERNS=$( { grep -c "^Status: READY" ai/dynamic/learned-patterns.md 2>/dev/null || echo 0; } | tail -1 )

echo "knowledge: ${HIGH_DRIFT} high-severity drift entries, ${READY_PATTERNS} patterns ready to promote"
exit 0
