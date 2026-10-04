# stallwise

Multi-store marketplace. Independent sellers each run a store; buyers check out across
stores; the platform settles seller payouts every night.

```
api/       NestJS 11 on Fastify + MikroORM 6 (Postgres 16) — REST and GraphQL under /api,
           plus the BullMQ / polling worker (src/worker)
reports/   Django 5.1 + DRF — refunds, settlement-file imports, finance reports (same database)
web/       React 19 + Vite — storefront and seller dashboard
deploy/    Kubernetes manifests, Postgres and PgBouncer configuration
```

## api/

- `src/catalog/` — products, category browse and search, the GraphQL product graph, CSV
  and XML feed imports, the catalog snapshot used by the storefront edge.
- `src/orders/`, `src/checkout/`, `src/invoices/` — order history, seller order views,
  checkout and payment capture, invoices.
- `src/stores/`, `src/staff/` — store onboarding, settings, opening hours, members.
- `src/payouts/` — the seller ledger, payout scheduling and reminders.
- `src/outbox/`, `src/webhooks/`, `src/worker/` — background delivery: the outbox relay,
  webhook retries and the search indexer run in the worker deployment.
- `src/realtime/` — WebSocket price and stock feeds for open product pages.

Controllers and resolvers delegate to services; services own every query.

## reports/

Django project `reportsvc` with one app, `refunds`. It reads the API's tables through
unmanaged models and owns `refunds_*`. It connects through PgBouncer.

## Running locally

```bash
docker compose up -d postgres pgbouncer redis
cd api && npm ci && npx mikro-orm migration:up && npm run start:dev
cd reports && pip install -r requirements.txt && python manage.py migrate && gunicorn -c gunicorn.conf.py reportsvc.wsgi
cd web && npm ci && npm run dev
```

Every service reads its database host, user and password from the environment
(`DATABASE_HOST`, `DATABASE_USER`, `DATABASE_PASSWORD`, …) and refuses to boot without them.

## Deploying

`main` builds the api, worker and reports images. A release Job runs the MikroORM
migrations, then `deploy/k8s/sql-migrate-job.yaml` applies `api/db/migrations/*.sql` in name order.
The API autoscales on CPU (`deploy/k8s/api.yaml`); the worker and reports deployments are
fixed-size.

## Tests

`cd api && npm run test:e2e` — Jest e2e against a disposable Postgres; `test/query-counter.ts`
counts the SQL statements each request issues. `cd reports && pytest` — pytest-django.
