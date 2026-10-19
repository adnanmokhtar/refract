# Contributing

Thanks for helping with Tallyhook. This page covers the local setup, the tests and the
conventions a pull request is reviewed against.

## Setup

You need Node 22.12+, pnpm 10, Docker, and Python 3.10 or later for `packages/py-money`.

```bash
npm install
pnpm --filter @tallyhook/api db:migrate
cp apps/api/.env.example apps/api/.env
make seed-db
```

Then start the API with `pnpm dev` and the worker with `pnpm dev:worker`.

## Tests

```bash
pnpm -r test
cd packages/py-money && pytest
```

Every pull request runs the same commands in CI, plus `pnpm -r typecheck`.

## Commit messages

We use Conventional Commits. A breaking change carries `!` after the type and a line in the
`## [Unreleased]` section of the changelog. See the [commit message guide](docs/commit-style.md).

## Code review

- One concern per pull request; refactors land separately from behaviour changes.
- A new endpoint lands with its entry in `apps/api/openapi.json` and a line in `docs/api.md`.
- A new environment variable lands in `apps/api/src/config/env.schema.ts`, `apps/api/.env.example`
  and `docs/config.md` in the same change.
- Money is always integer minor units; never a float in a column or a payload.

## Documentation

The merchant guide lives in `docs/guide/` and is served with MkDocs; the Arabic pages sit in
`docs/guide/ar/` next to the English ones. Reference pages (`docs/api.md`, `docs/config.md`)
and runbooks are plain Markdown read on the code host.

### Setup

```bash
pip install mkdocs-material mkdocs-static-i18n
mkdocs serve
```

The [docs-site setup](#setup-1) needs Python as well; it does not need the Node toolchain.
