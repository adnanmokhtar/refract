# Lumen Orders

An order and billing platform: a NestJS API on Fastify (`apps/api`), an Express admin console
(`apps/admin`), a Django/DRF billing service with Celery and APScheduler (`services/billing-py`), and
a Go storefront edge on gin (`services/edge-go`). The committed OpenAPI contract is
`openapi/openapi.yaml`; `ai/api-conventions.md` is the API contract every service follows.
