# Rails (Ruby) reference

> **Framework**: Rails 7.1+ / 8.0 on Ruby 3.2+
> **Official docs**: https://guides.rubyonrails.org/
> **Version-specific gotchas**: Rails 7.1 introduced `config.active_record.encryption`; Rails 8 made SQLite production-viable + added Solid Queue / Solid Cache (Redis replacement); ActiveRecord now defaults to `composite_primary_keys` support; Hotwire/Turbo replaces UJS.
> **Substitution markers**: Replace `Order` / `User` / etc. with the project's actual model names.

## Structure

```
app/
├── controllers/              # thin — delegate
├── models/                   # ActiveRecord
├── services/                 # business logic (PORO classes)
├── jobs/                     # ActiveJob / Sidekiq
├── mailers/
├── serializers/              # API responses (AMS / jbuilder / blueprinter)
└── policies/                 # Pundit authorization
config/
├── routes.rb
└── ...
db/
└── migrate/
```

## Rules

- Fat models / thin controllers — BUT extract to service objects when a model grows past ~200 lines.
- Single-intent service objects: `class CreateOrder.call(...) end`.
- Use Pundit or CanCanCan for authorization — never inline checks in controllers.
- Strong parameters for input (`params.require(:thing).permit(...)`).
- Use AMS / blueprinter / jbuilder for responses — don't `render json: model`.
- Use ActiveJob for async; pick Sidekiq as the backend unless constrained.

## Data

- Use `includes` to avoid N+1.
- Migrations are reversible by default; name them descriptively.
- Use scopes for reusable query fragments.
- `counter_cache` on frequently-counted associations.

## Anti-patterns

- God models (everything stuffed into User)
- `before_action` chains with hidden side-effects
- `render json: thing` — leaks schema
- Callbacks for business logic (`after_create :send_email`) — use jobs/events instead
- `rescue Exception` — catches too much

## Resilience, streaming & conditional requests

> See sibling patterns: `ai-patterns/rate-limiting.md`, `ai-patterns/conditional-requests.md`, `ai-patterns/response-streaming.md`, `ai-patterns/async-job-offload.md`.

- **Rate limiting** — throttle inbound with `rack-attack` (`Rack::Attack.throttle("api/ip", limit:, period:)`) backed by a *shared* `cache_store` (Redis), never the per-process memory store, or each Puma worker counts its own bucket. Rails 8 ships built-in `rate_limit to:, within:` in controllers. Emit `Retry-After` (RFC 9110 §10.2.3) + unprefixed `RateLimit-Limit/Remaining/Reset` (IETF `draft-ietf-httpapi-ratelimit-headers` — a draft, not an RFC) on the `429` (RFC 6585); render the body as `application/problem+json` (RFC 9457). → see `ai-patterns/rate-limiting.md` for per-tenant buckets, FAIL-OPEN/CLOSED, and `503` admission control.
- **Conditional requests** — `fresh_when(etag: record, last_modified: record.updated_at)` (or `stale?` for a custom body) auto-emits `ETag`/`Last-Modified` and returns `304 Not Modified` on a matching `If-None-Match`/`If-Modified-Since`, skipping render. On writes, demand `If-Match` and reject a stale/absent precondition with `412 Precondition Failed` / `428 Precondition Required` (RFC 9110, obsoletes 7232); wire the ETag to ActiveRecord's `lock_version` so optimistic locking and the HTTP precondition agree. → see `ai-patterns/conditional-requests.md`.
- **Streaming** — `include ActionController::Live`, then `response.stream.write(chunk)` and **always** `response.stream.close` in an `ensure` (a leaked stream pins a Puma thread). Drive the cursor with `find_each` / `in_batches` (constant memory, not `.all`); for SSE set `response.headers["Content-Type"] = "text/event-stream"`, for NDJSON write `"#{row.to_json}\n"`. Once the `200` + headers have flushed you cannot change the status — surface a mid-stream failure as an in-band terminal-error sentinel, not an HTTP code. → see `ai-patterns/response-streaming.md` for backpressure + disconnect cancellation (rescue `ActionController::Live::ClientDisconnected`).
- **Async job offload** — for work past the request budget, enqueue via ActiveJob / Sidekiq and return `202 Accepted` with a `Location:` header pointing at a status action (`GET /jobs/:id` → `queued → running → succeeded/failed`, with the result URL on success and a result TTL). Make submit idempotent: key the job on a client `Idempotency-Key` (or a natural unique key) so a retried POST returns the existing `202`, not a duplicate job. → see `ai-patterns/async-job-offload.md`.

## Pagination

> No built-in paginator — prefer `pagy` (page-number) and hand-wire keyset for cursor feeds. → see `ai-patterns/pagination.md`.

- **Cursor-first (keyset)** — page with `where("(created_at, id) < (?, ?)", cursor_time, cursor_id).order(created_at: :desc, id: :desc).limit(n)`; keyset is O(log n) and stable under writes, `OFFSET` rescans and skips/dupes rows on a growing scope.
- **Prefer `pagy`** — for offset/page-number needs use `pagy` (lowest-memory, actively maintained) over `kaminari` / `will_paginate`; reserve it for small quiescent tables where jump-to-page matters.
- **Bounded per-page** — set a default and a hard max (`pagy`'s `limit` / `max_items`, or clamp the `per_page` param yourself); an unbounded `.limit(params[:per_page])` is a memory/DoS risk.
- **Stable, unique order** — always append the PK tiebreaker (`order(created_at: :desc, id: :desc)`) and index the ordered columns; a bare `order(:created_at)` shuffles rows between pages.
- **No per-page `COUNT(*)`** — use `pagy_countless` (or fetch `limit + 1` for `has_more`); skip the count on large filtered scopes and render `{ data, meta: { next_cursor, has_more } }` in the serializer envelope.

> **Adjacent-pack hooks (pointer, don't duplicate):** detect `render json: thing` that bypasses the serializer (mass-assignment / schema leak) → **security pack**. Confirm every `429`/`412`/`202`/`5xx` is counted in the RED metrics + carries the trace id → **observability pack**. For *outbound* call resilience (timeouts, circuit breakers, DLQ, stored-idempotency replay on the consumer) → **distributed-systems pack**. Flag `find_each` over a `SELECT *` / over-fetched scope → **database pack**.
