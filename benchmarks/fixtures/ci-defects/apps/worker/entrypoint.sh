#!/bin/sh
# Apply pending migrations, then start the consumer.
set -e
npx mikro-orm migration:up
node dist/main.js "$@"
