# orders-api

Order + fulfilment service behind the storefront. Express, Postgres, JWT bearer auth.

- `src/routes/` — HTTP surface. Route handlers validate input and delegate.
- `src/services/` — business logic. The only layer allowed to touch `src/db/`.
- `src/db/` — pool + query helpers. No business rules here.
- `src/middleware/` — auth, rate limiting, request logging.

Run locally: `npm run dev` (expects a Postgres on `DB_HOST`).

Multi-tenant: every row carries `tenant_id`; `req.user.tenantId` is the tenant
for the current request.
