#!/usr/bin/env bash
# Seed _version.json into every template subdir that doesn't already have one.
# Idempotent: skips dirs that already have a _version.json.
# Usage: scripts/seed-versions.sh [--force]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FORCE="${1:-}"
TODAY="$(date -u +%Y-%m-%d)"
SETUP_VERSION="3.0.0"

write_version() {
  local dir="$1"
  local kind="$2"
  local name
  name="$(basename "$dir")"
  local file="$dir/_version.json"

  if [ -f "$file" ] && [ "$FORCE" != "--force" ]; then
    echo "skip   $file (exists)"
    return
  fi

  cat > "$file" <<EOF
{
  "kind": "$kind",
  "name": "$name",
  "version": "1.0.0",
  "released": "$TODAY",
  "min_setup_command": "$SETUP_VERSION",
  "deprecated": false,
  "summary": "Initial baseline."
}
EOF
  echo "wrote  $file"
}

# Tool adapters (10 + skip top-level docs)
for d in "$ROOT"/templates/tool-adapters/*/; do
  [ -d "$d" ] && write_version "${d%/}" "tool-adapter"
done

# Packs
for d in "$ROOT"/templates/packs/*/; do
  [ -d "$d" ] && write_version "${d%/}" "pack"
done

# Business domains
for d in "$ROOT"/templates/business-domains/*/; do
  [ -d "$d" ] && write_version "${d%/}" "business-domain"
done

# Technical domains
for d in "$ROOT"/templates/domains/*/; do
  [ -d "$d" ] && write_version "${d%/}" "domain"
done

echo
echo "Done. Run with --force to overwrite existing files."
