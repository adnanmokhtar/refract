# marketly

Multi-vendor marketplace. Sellers list products, buyers check out, the platform takes a
fee and issues invoices on both sides.

```
api/      NestJS 10 + Prisma 5 (Postgres) — REST API under /api
web/      React 18 + Vite — storefront, buyer account, seller dashboard
deploy/   nginx edge config + Kubernetes manifests
```

## Layout — api/

- `src/auth/` — login, logout, JWT issue + guards. Access tokens are RS256, signed by
  this service with the key pair mounted at `/etc/marketly`.
- `src/account/` — the account pages (email, payout bank account). These still run on
  the `mk_sid` session cookie set at login; everything else uses the bearer token.
- `src/products/`, `src/orders/`, `src/invoices/` — the marketplace itself.
- `src/media/` — product image upload, bulk ZIP import, thumbnails, downloads.
- `src/themes/`, `src/marketing/`, `src/pricing/`, `src/settings/` — seller tooling:
  storefront themes, email templates, promotion rules, store settings and custom domains.
- `src/inventory/` — stock transfers between a seller's warehouses, and returns put back on
  the shelf. Every movement is a row in the stock ledger.
- `src/webhooks/` — payment and shipping provider callbacks, and the subscription
  handshakes of providers that confirm their callback URL first.

Routes delegate to services; services own every Prisma call.

## Running locally

```bash
docker compose up -d db
cd api && npx prisma migrate deploy && npm run start:dev
cd web && npm run dev
```

The API reads `DATABASE_URL`, `PAYMENTS_WEBHOOK_SECRET` and `SHIPPING_WEBHOOK_SECRET`
from the environment and refuses to boot without them.

## Deploying

`main` builds `api/Dockerfile` and the static `web/dist` bundle. Production runs the API
on Kubernetes (`deploy/k8s/`) behind the nginx edge in `deploy/nginx/nginx.conf`, which
also serves the SPA and seller uploads.
