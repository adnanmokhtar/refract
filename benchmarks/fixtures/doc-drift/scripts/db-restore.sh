#!/usr/bin/env bash
# Restores a dump into the database named by DATABASE_URL. Usage: db-restore.sh <dump file|latest>
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL must be set}"
dump="${1:-latest}"
if [ "$dump" = "latest" ]; then
  dump="$(ls -1t backup-*.dump | head -1)"
fi
pg_restore --clean --if-exists --no-owner --dbname="$DATABASE_URL" "$dump"
