# Codebase profile — orders-api

PROJECT_KIND: backend-service
Language: JavaScript (Node 18, CommonJS)
Framework: Express 4
Datastore: PostgreSQL (via `pg` pool)
Auth: JWT bearer, HS256, issued by the identity service
Tenancy: multi-tenant, `tenant_id` column on every table
Target scale: 400 rps steady, 1200 rps peak; p95 budget 250 ms

## Layering contract

`routes/` → `services/` → `db/`. Routes MUST NOT import from `src/db/`
directly; the service layer owns every query. Middleware may read config.

## Known operating constraints

- Runs as 6 replicas behind an ALB. Any per-process state is per-replica.
- Deploys are rolling; a replica may be restarted at any time.
