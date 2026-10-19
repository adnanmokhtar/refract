# Extracted codebase — Orderly

Census sha `0c23a5169e` · tracked files read with `git ls-files`; every claim below carries its provenance marker.

## Workspaces

- [found: `pnpm-workspace.yaml`] Members are `apps/*` and `packages/*`.
- [found: `apps/api/package.json`] The API depends on `@mikro-orm/postgresql` and `uuidv7`.
- [found: `apps/web/package.json`] The web app depends on React 19 and Vite 6.

## Modules [SAMPLED: 6/14 modules]

- [found: `apps/api/src/modules/orders/orders.controller.ts`] All controllers map entities through `toResponse` — confirmed.
- [found: `apps/api/src/shared/tenancy/tenant.filter.ts`] Tenancy is middleware plus `withTenant()` for jobs.
- 14 modules under `apps/api/src/modules/`, one controller and one service each.

## Entry points

- [found: `apps/api/src/main.ts`] Fastify adapter, global prefix `api`, port from the environment.
- [found: `apps/web/src/main.tsx`] React root with a query client provider.
