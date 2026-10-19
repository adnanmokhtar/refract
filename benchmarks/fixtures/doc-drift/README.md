# Tallyhook

Tallyhook is an invoicing API for online merchants: orders, invoices, signed webhooks and
monthly reports, with a TypeScript SDK and a small Python money library.

## Prerequisites

- Node 20+ and pnpm 10
- Python 3.12+ (only for `packages/py-money`)

## Quickstart

```bash
pnpm install
cp apps/api/.env.example apps/api/.env
docker compose up -d postgres redis
pnpm db:migrate
pnpm dev:all
```

The API listens on `http://localhost:3000`. The guide has the [install steps](docs/guide/setup.md#install-steps)
in more detail, with what each one does.

## Layout

- `apps/api` - the NestJS service and the `tallyhook` operator CLI.
- `packages/sdk` - the published TypeScript client, `@tallyhook/sdk`.
- `packages/py-money` - money helpers for the Python reporting jobs.
- `deploy/` - Kubernetes manifests and Prometheus alert rules.
- `docs/` - the guide (MkDocs, English and Arabic), the API reference, ADRs and runbooks.

Configuration is loaded by `apps/api/src/config/app.config.ts`; every variable is listed in the
[configuration reference](docs/config.md).

## Deploying

The cluster setup and the release steps are in the [deployment guide](docs/deploy.md).

## Working on Tallyhook

- [Contributing](CONTRIBUTING.md): local setup, tests and commit conventions.
- [Docs site](docs/guide/index.md): the merchant-facing guide.
- [HTTP API](docs/api.md): endpoints, retries and metrics.
- [Architecture](docs/architecture.md): the modules and how they talk.
- [Changelog](CHANGELOG.md): what changed in each release.

## Support

Merchants reach support from the dashboard. Engineers on call start from the runbooks in
`docs/runbooks/`, which the alert rules in `deploy/alerts/rules.yml` link to.

Service status: [status.example.com](https://status.example.com).
