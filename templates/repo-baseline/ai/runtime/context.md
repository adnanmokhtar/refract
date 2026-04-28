# Runtime context — project-specific gotchas

The "stuff a new contributor will trip on" list. Distinct from `.claude/rules/` (general framework rules) — this is THIS project's quirks.

## Format

Free-form. Bullets work well. Date-stamp entries you expect to expire.

## Categories

### Build + dev

- <e.g., "Run `pnpm dev` from `/api`, not workspace root — workspace-level run starts wrong port">
- <e.g., "Hot reload doesn't pick up changes to `prisma/schema.prisma` — restart server after schema edits">

### Database

- <e.g., "`migrations/0042_add_phone_index.sql` was applied manually in prod (out-of-band) — TypeORM thinks it's pending. Mark resolved in `migrations` table">
- <e.g., "Row-level security (RLS) is enabled on `tenants` table — test with `SET app.current_tenant = 'X'` or queries return empty">

### External APIs

- <e.g., "Meta WhatsApp Cloud API retries failed webhooks every 3min for 24h — handler MUST be idempotent + ack <5s">
- <e.g., "Stripe sends `payment_intent.succeeded` BEFORE `charge.succeeded` ~70% of the time — don't rely on order">

### Background jobs

- <e.g., "BullMQ workers don't pick up jobs in dev unless `REDIS_HOST=localhost` is set explicitly (default `redis://redis` is for Docker)">

### Production-only quirks

- <e.g., "DNS TTL for `*.ourapp.com` is 1h — DNS changes propagate slowly; plan for it">
- <e.g., "Cloudflare strips `X-Forwarded-For` header in some configs; rely on `CF-Connecting-IP` instead">

### Things that look broken but aren't

- <e.g., "First request after deploy is slow (Lambda cold-start); not a bug">
- <e.g., "TypeScript shows error on `req.user` even though it's typed in `Request` augmentation — ts-server bug; restart language server">

## How to keep this current

- Add an entry when you discover a gotcha (probably mid-debugging session).
- Date-stamp entries you expect to fix or expire.
- Periodic review: prune entries that no longer apply (don't let it become an archaeology dig).
- Surface critical entries in `CLAUDE.md` Top-of-File rules.

## See also

- `ai/runtime/environment-quirks.md` — local-dev specifics.
- `ai/runtime/dependencies-with-traps.md` — third-party lib footguns.
- `ai/runtime/domain-anti-patterns.md` — populated from `business-domains/<domain>/anti-patterns.md`.
- `.claude/rules/` — general (non-project-specific) rules.
