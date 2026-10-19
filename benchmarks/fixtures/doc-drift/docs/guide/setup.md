# Getting started

This page takes you from a fresh clone to a running API on `http://localhost:3000`.

## Requirements

- Node 22.12 or later, and pnpm 10
- Docker, for Postgres 16 and Redis 7

## Installing

```bash
pnpm install
cp apps/api/.env.example apps/api/.env
docker compose up -d postgres redis
pnpm db:migrate
pnpm dev
```

The first command installs the workspace, the second gives the API its local settings, the third
starts the databases, the fourth creates the tables and the last one starts the API in watch mode.

## Next steps

Read how [billing](billing.md) numbers and sends invoices, then wire the [SDK](sdk.md).
