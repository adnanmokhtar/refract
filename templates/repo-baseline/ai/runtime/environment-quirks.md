# Environment quirks (local-dev specifics)

Things that go wrong in your DEV environment but work in prod (or vice versa). Saves a new contributor 4 hours of debugging.

> **Read by:** bug fixes and "works on my machine" / setup debugging. **Load trigger:** dev-env failures (ports, Docker, DB/Redis connection, certs, webhooks/tunnels), CI-only failures, or onboarding a new contributor.

## Local dev setup

### Ports
- Default ports used: <list>
- Conflicts with macOS services (e.g., AirPlay uses 5000): <workaround>

### Docker / docker-compose
- <e.g., "`docker-compose up` requires Docker memory ≥4GB; default 2GB causes Postgres OOM">
- <e.g., "Volumes don't sync on Windows + WSL2 by default; use `:cached` flag">

### Database
- <e.g., "Postgres uses `host.docker.internal` from container; `localhost` from host. `.env.example` defaults to container view.">

### Redis
- <e.g., "Redis without password works locally; prod requires AUTH. `REDIS_URL` must include password segment.">

### Authentication
- <e.g., "OAuth callback won't work without `localhost.crt` cert. Run `pnpm setup:cert` first.">
- <e.g., "Stripe webhooks need ngrok in dev: `pnpm dev:tunnel`">

## OS-specific

### macOS
- <gotchas>

### Linux
- <gotchas>

### Windows / WSL2
- <gotchas>

## IDE quirks

- <e.g., "VS Code TypeScript server runs out of memory on large monorepo — set `typescript.tsserver.maxTsServerMemory: 8192` in workspace settings">

## CI quirks

- <e.g., "GitHub Actions runners use UTC; tests dependent on local TZ may fail. Set `TZ=UTC` in workflow env.">

## How to keep this current

- Add an entry when YOU spend >30min debugging a dev-environment issue.
- Pair with `README.md` "Getting started" — quirks here, instructions in README.
- Prune when fixes become standard (e.g., the cert step is now in `pnpm install` post-script).

## See also

- `ai/runtime/context.md` — broader project gotchas.
- `README.md` — onboarding / setup instructions.
- `.claude/rules/` — code-level rules.
