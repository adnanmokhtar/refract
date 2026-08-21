# Express (Node) reference

> **Framework**: Express 4.x / 5.x on Node 18+ • TypeScript optional but recommended
> **Official docs**: https://expressjs.com/en/4x/api.html (v4) • https://expressjs.com/en/5x/api.html (v5)
> **Version-specific gotchas**: Express 5 returns Promises from middleware (no more `express-async-errors` shim needed); `req.params` typed differently in v5; deprecated `res.json(status, body)` removed in v5.
> **Substitution markers**: Replace `<name>` with the project's actual module name from `_extracted-idioms.md` (e.g., `users`, `orders`).

## Structure

```
src/
├── app.ts                  # express app + middleware wiring
├── server.ts               # listen()
├── config/
├── modules/
│   └── <name>/
│       ├── <name>.router.ts         # router with route handlers
│       ├── <name>.controller.ts     # request/response handling
│       ├── <name>.service.ts        # business logic
│       ├── <name>.repository.ts     # data access
│       ├── <name>.schema.ts         # zod / joi validation
│       └── <name>.types.ts
└── middleware/
    ├── auth.ts
    ├── error-handler.ts
    └── request-id.ts
```

## Rules

- Use `express-async-errors` or `asyncHandler` wrappers — never leave async errors unhandled.
- Validate inputs with `zod` / `joi` — mount as middleware per route.
- Global error handler in `app.ts` — maps domain errors to statuses.
- Don't export `req` / `res` / `next` types from service layer.
- Correlation id middleware runs first; attach to every log line.

## Resilience, streaming & conditional requests

> Express-idiomatic wiring for the four cross-cutting HTTP patterns. Each maps to a sibling ai-pattern that owns the policy; this section is the framework hook only.

- **Rate limiting** — `express-rate-limit` with a `rate-limit-redis` store (`new RedisStore({ sendCommand: (...a) => client.call(...a) })`). The default `MemoryStore` resets per process, so behind 2+ instances / a load balancer each replica counts independently and the real limit is `N × limit` — use the shared store. On 429 emit `Retry-After` plus the current draft's two quota fields — `RateLimit-Policy: "default";q=100;w=60` and `RateLimit: "default";r=0;t=30` (`draft-ietf-httpapi-ratelimit-headers`, a DRAFT). `express-rate-limit`'s `standardHeaders` option selects which draft it emits — check which one your version writes, and add the legacy `RateLimit-Limit/Remaining/Reset` triple alongside only while clients still read it. Keep per-tenant keyGenerator. → see `ai-patterns/rate-limiting.md`.
- **Conditional requests** — reads: compute a representation tag, `res.set('ETag', tag)`, then `if (req.headers['if-none-match'] === tag) return res.status(304).end();` (no body on 304). Writes: gate on `If-Match` — `412 Precondition Failed` on tag mismatch, `428 Precondition Required` when the header is absent on an unsafe method (RFC 9110). → see `ai-patterns/conditional-requests.md`.
- **Streaming** — for unbounded results stream instead of buffering. Honor backpressure: `if (!res.write(chunk)) await once(res, 'drain');` before the next chunk. For SSE set `Content-Type: text/event-stream` and `res.flushHeaders()`; end every stream with a terminal sentinel (NDJSON `{"done":true}` / SSE `event: end`) so a truncated 200 is distinguishable from success — a mid-stream throw cannot change the already-sent status. Cancel work on `req.on('close', …)` when the client disconnects. → see `ai-patterns/response-streaming.md`.
- **Async job offload** — for slow work return fast: a BullMQ / Bee-Queue producer enqueues, the handler responds `202 Accepted` + `Location: /jobs/:id`, and `GET /jobs/:id` serves the job-status state machine (`queued → running → succeeded|failed`). Key the producer by an idempotency key so a retried submit reuses the same job. → see `ai-patterns/async-job-offload.md`.

## Pagination

> No built-in paginator — keyset (cursor) pagination is hand-wired in the repository. → see `ai-patterns/pagination.md`.

- **Cursor-first (keyset)** — page with a row-value comparison that matches the sort: `WHERE (created_at, id) < (?, ?) ORDER BY created_at DESC, id DESC LIMIT ?`. O(log n) per page and stable under concurrent writes, unlike `.offset()` which rescans and skips/dupes rows on a hot table.
- **Opaque cursor** — encode the last row's `{created_at, id}` as base64 (sign/HMAC if tampering matters), decode server-side into the predicate; never expose a raw offset a client can inflate into a deep scan.
- **Stable, total sort** — always append the primary key as a tiebreaker (`, id DESC`); a bare `ORDER BY created_at` silently drops/repeats rows across cursor pages.
- **Default + max limit** — read `limit` from the query, apply a default (e.g. 20) and clamp to a hard cap (e.g. 100) in the zod/joi schema; an unbounded list is a memory/DoS risk.
- **Skip `COUNT(*)`** — fetch `limit + 1` and drop the extra to compute `hasMore`; return `{ data, meta: { nextCursor, hasMore } }` in the shared envelope, no per-page total.

## Anti-patterns

- Fat controllers with business logic
- Direct DB access in controllers
- Callback-style middleware when async is cleaner
- `try { } catch (e) { res.status(500).send(e) }` — leaks internals
