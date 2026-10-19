#!/usr/bin/env bash
# copies production into staging every Monday so QA tests on real orders
set -euo pipefail
pg_dump "$PROD_DATABASE_URL" --no-owner | psql "$STAGING_DATABASE_URL"
