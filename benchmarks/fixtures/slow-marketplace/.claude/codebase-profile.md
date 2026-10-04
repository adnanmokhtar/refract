# Codebase profile — stallwise

PROJECT_KIND: fullstack-web
Languages: TypeScript (api, web), Python 3.12 (reports)
Backend: NestJS 11 on Fastify 5, MikroORM 6.4 (`@mikro-orm/postgresql`), GraphQL via Mercurius, BullMQ 5 + Redis 7
Reports: Django 5.1 + Django REST framework 3.15 on gunicorn, psycopg 3
Database: PostgreSQL 16 primary + one streaming replica (`postgres-replica`); PgBouncer 1.23 in front of the reports service
Frontend: React 19 + Vite 6, react-router 7
Runtime: Kubernetes — `api` (HPA), `worker` (fixed), `reports` (fixed); manifests in `deploy/k8s/`
Tests: Jest e2e with a per-request SQL statement counter (`api/test/`); pytest-django (`reports/`)

## Data volume

`pg_class.reltuples` on the production primary, snapshot taken 2025-09-01.

| table | rows | growth |
|-------|------|--------|
| `order` | 41 M | append, ~90 k/day |
| `order_item` | 186 M | append |
| `ledger_entry` | 77 M | append |
| `review` | 9.4 M | append |
| `customer` | 6.1 M | per store |
| `refunds_refund` | 3.1 M | append |
| `product` | 2.3 M | per store |
| `payout` | 1.9 M | append |
| `outbox_event` | ~400 k live | rolling, pruned weekly |
| `store` | 18 k | slow |
| `country` | 250 | fixed |

The largest store has 2.4 M orders and 310 k products.

## Layering contract

controller / resolver → service → `EntityManager`. Services own every query; entities live
in `*.entity.ts` beside their service.

## Migrations

MikroORM TypeScript migrations in `api/src/migrations`, run by `mikro-orm migration:up` in
the release Job. Hand-written SQL in `api/db/migrations`, applied afterwards by
`deploy/k8s/sql-migrate-job.yaml`. The reports service runs `manage.py migrate` for its own
`refunds_*` tables.
