#!/usr/bin/env bash
# Takes a custom-format dump of the database named by DATABASE_URL.
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL must be set}"
pg_dump --format=custom --file="backup-$(date +%Y%m%d-%H%M).dump" "$DATABASE_URL"
