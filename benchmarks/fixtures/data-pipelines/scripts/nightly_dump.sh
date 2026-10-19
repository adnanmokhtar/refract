#!/usr/bin/env bash
# legacy MySQL shop database: nightly logical backup copied to the reporting box
set -euo pipefail
mysqldump --host "$LEGACY_MYSQL_HOST" --user backup shopdb > "/backups/shopdb-$(date +%F).sql"
