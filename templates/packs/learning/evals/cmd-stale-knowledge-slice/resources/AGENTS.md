# AGENTS.md — Orderly

Instructions for coding agents other than Claude Code (Codex, OpenCode, Copilot coding agent).

## Setup

- Package manager: npm.
- Install with `npm install`, then start everything with `npm run dev`.
- Node 22 (`.nvmrc`); local Postgres 16 and Redis 7 from `docker-compose.yml`.
- The API listens on port 4000; the web dev server runs on 5173.

## Layout

- `apps/api` — NestJS 11 API on Fastify; MikroORM 6 over Postgres 16.
- `apps/web` — React 19 + Vite 6 web app.
- `packages/contracts` — zod schemas shared by both apps.

## Rules

- Keep controllers thin; business rules live in services and use cases.
- Every query runs in the tenant scope.
- Money is stored in integer minor units.
- A bug fix comes with the test that failed before it.

## More

- Conventions: `ai/conventions.md`.
- Architecture: `ai/architecture.md`.
- Decisions: `ai/_decision-index.md`.
