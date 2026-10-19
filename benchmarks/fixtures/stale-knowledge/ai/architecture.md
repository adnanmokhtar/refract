# Architecture

Orderly is a pnpm workspaces monorepo. `apps/api` serves the HTTP API, `apps/web` is the browser app, and both import
their request and response shapes from `packages/contracts`.

## Runtime

- API: NestJS 11 on Fastify; MikroORM 6 over Postgres 16; UUIDv7 primary keys.
- `apps/web` — React 18 SPA built with Vite 6; server state in TanStack Query.
- Queue workers share the API process and use Redis 7 for the webhook queue.

## API layout

The API has 12 modules under `apps/api/src/modules/`; each owns its controller, service and entities.
Cross-module calls go through exported services.

- Pricing: `apps/api/src/modules/orders/order-pricing.service.ts` computes line totals and discounts.
- Placement: a use case in `apps/api/src/modules/orders/application/` writes the order in one unit of work.
- Errors: `HttpErrorFilter` in `apps/api/src/shared/errors/http-error.filter.ts` renders problem+json.

- Tenant scoping is applied by `TenantFilter` and `withTenant` (`apps/api/src/shared/tenancy/tenant.filter.ts:12`).
- Ids: `newId()` in `apps/api/src/shared/ids.ts`.
- Persistence: repositories extend `BaseRepository` in `apps/api/src/shared/persistence/base.repository.ts`.
- Money: the `Money` value object in `apps/api/src/shared/money/money.ts`.
- Bootstrap: `apps/api/src/main.ts` registers the Fastify adapter and the error filter.

- The order list endpoint is `OrdersController.list` (`apps/api/src/modules/orders/orders.controller.ts:88`).

## Tenancy

Every query runs inside the request's tenant scope. `TenantFilter` is registered as global middleware and puts the
tenant id in an `AsyncLocalStorage`; background jobs call `withTenant()` before they touch the database. A query that
skips the scope reads another tenant's orders, so review each new query for it.

## Web

- Routes are feature folders under `apps/web/src/features/`.
- The orders screen reads through a query hook and renders a table component.

## Data flow

1. The web app calls the API through the shared client.
2. The controller parses the body with a contracts schema.
3. A service or use case runs inside the tenant scope.
4. The ORM flushes once per request.
5. Events leave through the outbox.

## Where things live

- Order rules live in `orders/orders.service.ts`.
- The webhook queue lives with the webhooks module.
