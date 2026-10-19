#!/usr/bin/env bash
# preview environments get production shape with masked people: pg_anonymizer runs before the dump
set -euo pipefail
psql "$PROD_REPLICA_URL" -c "SELECT anon.start_dynamic_masking();"
pg_dump "$PROD_REPLICA_URL" --no-owner --exclude-table-data=customers | psql "$PREVIEW_DATABASE_URL"
