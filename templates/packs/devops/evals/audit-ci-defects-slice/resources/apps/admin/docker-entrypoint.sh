#!/bin/sh
# One replica: apply pending Prisma migrations (Prisma takes a Postgres advisory lock), then hand PID to the app.
set -e
npx prisma migrate deploy
exec "$@"
