# Fernhollow Commerce

A multi-tenant commerce platform: merchants run online stores and point-of-sale registers, pay a
monthly plan, and are paid out from a wallet. A NestJS API on Fastify with MikroORM over Postgres
(`apps/api`), a React SPA (`apps/web`), and a Django/DRF back office with Celery for finance
operations — settlements, invoicing, reconciliation and reports (`services/backoffice`).

- `ai/business-domain.md` — the money, tax, metric and time policies the code is meant to follow.
- `ai/business-flows.md` — the declared lifecycles of orders, invoices and subscriptions.
- `golden/` — a golden ledger day, a golden invoice and a golden daily report, used by the finance
  team's offline checks.
