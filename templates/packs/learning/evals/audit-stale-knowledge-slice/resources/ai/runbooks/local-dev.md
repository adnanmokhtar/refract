# Local development

## Payment provider sandbox

The sandbox account is shared by the team. Copy these lines into `.env.local`; they are not read from anywhere else.

- `ORDERLY_PSP_API_URL=https://sandbox.psp.example.com`
- `ORDERLY_PSP_API_KEY=psp-key-7c41e09b2a4f6e3d51c9`

## Services

- `docker compose up -d` starts Postgres 16 and Redis 7.
- `pnpm dev` starts the API and the web app.
- A fresh clone needs `pnpm install` before anything else.
- The web dev server proxies API calls to the local API.
- Reset the local database by recreating the container; there is no reset script.
- Logs print to the terminal; local runs ship nothing to the log backend.

## Environments

- Ports by environment: dev API 3000, e2e API 3100, staging API 8080 behind the gateway.

## Builds

- `pnpm build` writes `apps/web/dist/` (gitignored); serve it with `pnpm --filter @orderly/web preview`.

## Notes

- Session notes go to `ai/dynamic/session-log.md` (gitignored, one per machine).
