# Laravel (PHP) reference

> **Framework**: Laravel 11.x on PHP 8.2+
> **Official docs**: https://laravel.com/docs/11.x
> **Version-specific gotchas**: Laravel 11 removed `Http/Kernel.php` (middleware now in `bootstrap/app.php`); removed `app/Console/Kernel.php` (commands auto-registered); reduced default service providers; queueing uses Redis or DB by default; Pennant for feature flags; Reverb for WebSockets.
> **Substitution markers**: Replace `Order` / `User` etc. with the project's actual model + service names.

## Structure

```
app/
├── Http/
│   ├── Controllers/
│   ├── Requests/              # FormRequest validation classes
│   ├── Resources/             # API resource responses (DTOs)
│   └── Middleware/
├── Models/                    # Eloquent models
├── Services/                  # business logic
├── Repositories/              # data access (optional — Eloquent often suffices)
├── Actions/                   # single-intent operations
├── Events/
├── Listeners/
└── Jobs/                      # queued jobs
routes/
├── api.php
└── web.php
database/
└── migrations/
```

## Rules

- Controllers stay thin — delegate to a Service or Action.
- Validation via FormRequest classes — never in the controller.
- API responses via `JsonResource` / `ResourceCollection` — never expose Eloquent models directly.
- Use Actions for single-intent operations (e.g., `CreateOrderAction`).
- Events + Listeners for side-effects (email on signup, etc.).
- Queued Jobs for slow work — never run `::chunk(1000)` in a request.
- Gates / Policies for authorization — not inline if-checks.

## Data

- Eloquent relationships: `hasMany`, `belongsTo`, `belongsToMany`.
- Use `with()` to eager-load and avoid N+1.
- Migrations must be reversible — fill `down()` even when generated.
- Use `softDeletes()` trait if you want soft delete, not a custom flag.
- **Pagination**: prefer `cursorPaginate($perPage)` (keyset — opaque base64 cursor, O(log n), stable under concurrent writes) over `paginate()` (offset + a `COUNT(*)` per page); `simplePaginate()` when you only need next/prev without the count. Clamp the page size to a default + hard max (`$request->integer('per_page', 20)` capped at 100) — never trust the raw query param. Cursor pagination REQUIRES a stable total order, so `orderBy('created_at', 'desc')->orderBy('id', 'desc')` (unique tiebreaker) before `cursorPaginate()`, else rows drop/repeat across pages. Return through a `ResourceCollection` so the meta envelope is uniform. → see `../ai-patterns/pagination.md`.

## Resilience, streaming & conditional requests

- **Rate limiting**: gate inbound load with the `throttle` middleware — `throttle:60,1` inline, or a named limiter defined via `RateLimiter::for('api', fn (Request $r) => Limit::perMinute(60)->by($r->user()?->id ?: $r->ip()))` in `AppServiceProvider::boot()` (Laravel 11 has no `RouteServiceProvider`) then `throttle:api`. Key `->by()` on tenant/user/API-key for fairness — a single global `Limit` starves every tenant. The limiter counter lives in the configured **cache store**, so a >1-replica deploy MUST use the Redis (shared) store, not `file`/`array`, or each pod enforces its own quota. Laravel returns `429` + `Retry-After` + `X-RateLimit-Reset`; it emits legacy `X-RateLimit-*` by default — add the current draft's two quota fields (`RateLimit-Policy: "default";q=100;w=60` and `RateLimit: "default";r=0;t=30`, `draft-ietf-httpapi-ratelimit-headers`, a DRAFT) via `Limit::response(...)` or a response middleware, leaving the `X-RateLimit-*` set in place while clients still read it. → see `../ai-patterns/rate-limiting.md`.
- **Conditional requests**: for reads, attach the `cache.headers:etag` middleware (`SetCacheHeaders`) to auto-compute an `ETag` and answer `If-None-Match` with `304`, or set it explicitly with `$response->setEtag(...)` + `$request->isNotModified($response)`. For writes, read `$request->header('If-Match')` and compare it to the model's `version`/`updated_at` (or a `rowVersion` column) INSIDE the update — stale → `412 Precondition Failed`, absent on a guarded mutation → `428 Precondition Required`. Back it with the DB predicate (`where('version', $expected)`; 0 rows affected → `412`) so the check is atomic, not a `SELECT`-then-`UPDATE` race. → see `../ai-patterns/conditional-requests.md`.
- **Streaming** (unbounded reads/exports): `response()->stream(fn () => ..., 200, $headers)` for chunked output, `response()->streamJson([...])` / `->streamDownload()`, or `response()->eventStream(...)` for SSE (Laravel 11.x). Source rows with `Model::cursor()` / `->lazy()` so you never load the whole table into memory, `flush()` incrementally, and stop the query on client disconnect (`connection_aborted()`). Never build a full array then `->json()` for an unbounded query. → see `../ai-patterns/response-streaming.md`.
- **Async job offload** (work >~1s): dispatch a queued `Job implements ShouldQueue` (`Job::dispatch(...)`) and return `202 Accepted` + `Location: /jobs/{id}`; expose a status endpoint over a `queued→running→{done,failed}` state machine (persist the row-id/state, TTL the result). Make submit idempotent with `ShouldBeUnique` (or a client key → existing-job lookup); use `Bus::batch()` for fan-out and Horizon to monitor the Redis queue. Never run the heavy work inline and return `200` after it finishes. → see `../ai-patterns/async-job-offload.md`.

## Anti-patterns

- Business logic in controllers
- Returning Eloquent models from API routes (leaks schema)
- Ignoring N+1 — Laravel is especially prone
- Firing queries in loops (`foreach ($items as $i) { $i->thing()->get(); }`)
- Leaky `dd()` calls left in code
