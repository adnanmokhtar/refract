# tollgate

Subscription billing for SaaS products: plans, renewals, proration, coupons, usage quotas, invoices
and merchant payouts.

```
api/      NestJS 11 on Fastify + Prisma 6 (Postgres 16) — billing, subscriptions, checkout, usage
web/      React 19 + Vite — the customer portal and the finance back office
worker/   Python 3.12 — nightly renewals, dunning, ledger exports
ingest/   Go 1.23 — receives payment-provider webhooks, dedupes them, hands them to the API
deploy/   per-environment values for the Helm chart
```

Architecture rules live in `ai/architecture.md` and `docs/adr/`. Lint: `npm run lint` (ESLint 9
flat config at the root, type-aware). Types: `npm run typecheck`. Python: `ruff check worker` and
`mypy worker`. Go: `go vet ./...`.

Every service reads its configuration from the environment; nothing in this repository holds a
credential.
