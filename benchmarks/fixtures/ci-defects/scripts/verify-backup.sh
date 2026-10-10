#!/usr/bin/env bash
# verify-backup.sh: restore last night's dump into a scratch database and count the orders.
set -euo pipefail
latest="$(aws s3 ls "${BACKUP_BUCKET}/" | sort | tail -n 1 | awk '{print $4}')"
aws s3 cp "${BACKUP_BUCKET}/${latest}" /tmp/latest.dump
pg_restore --no-owner -d "$SCRATCH_DATABASE_URL" /tmp/latest.dump
psql "$SCRATCH_DATABASE_URL" -tAc 'select count(*) from orders' | grep -qv '^0$'
