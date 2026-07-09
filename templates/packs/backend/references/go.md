# Go backend reference (chi / gin / fiber / echo)

> **Framework**: Go 1.22+ • routers: chi 5.x, gin 1.10+, fiber 2.x, echo 4.x
> **Official docs**: https://pkg.go.dev/net/http (stdlib) • https://github.com/go-chi/chi • https://gin-gonic.com/docs/ • https://docs.gofiber.io/ • https://echo.labstack.com/docs
> **Version-specific gotchas**: Go 1.22 made `for i := range N` a valid loop and fixed loop-variable scope (no more `i := i` shadow needed); `net/http.ServeMux` got method+pattern routing in 1.22 (often replaces 3rd-party routers); `slog` is the stdlib structured logger from 1.21.
> **Substitution markers**: Replace `internal/<feature>` paths with the project's actual module names.

## Structure

```
cmd/
└── api/
    └── main.go               # entrypoint
internal/
├── api/                      # http layer
│   ├── router.go
│   ├── middleware/
│   └── handlers/
├── service/                  # business logic
├── repository/               # data access
├── domain/                   # entities, domain errors
└── platform/                 # db, cache, logger, config
pkg/                          # exported libraries (if any)
```

## Rules

- Package by feature, not by layer — each feature has handler + service + repo.
- `internal/` for code that must not be imported by external modules.
- Return `error` from every function that can fail; never swallow.
- Wrap errors with context: `fmt.Errorf("get user %d: %w", id, err)`.
- Use interfaces at consumer side, not producer side — small, focused interfaces.
- Use `context.Context` as first param on every I/O function; propagate cancellation.

## Concurrency

- Never `go func()` in a request handler without a bounded worker pool.
- Always pass `ctx` into goroutines; never capture the outer one.
- Use `errgroup` for coordinated concurrent work.
- Close channels from the sender side only.

## Data

- Use `database/sql` with `pgx` / `mysql` driver, or `sqlc` for typed queries.
- Avoid ORMs (`gorm`) unless the team chooses it explicitly — raw SQL + sqlc is idiomatic.
- Always parametrize queries; `?` / `$1` — no string concatenation.

## Resilience, streaming, conditional requests & pagination

> Go is stdlib-heavy — most of these are wired by hand around `net/http`; each maps to a sibling ai-pattern that owns the policy.

- **Rate limiting** — `golang.org/x/time/rate` (token-bucket `Limiter`, keyed per client in a map+mutex or an LRU), or a router middleware (`go-chi/httprate`, `ulule/limiter`). `x/time/rate` is **in-memory per process** — behind >1 instance each replica has its own bucket, so use a Redis-backed limiter (`ulule/limiter` store) for a real global limit. On reject, set `Retry-After` + unprefixed `RateLimit-Limit/Remaining/Reset` headers then `http.Error(w, ..., http.StatusTooManyRequests)` (429) — the headers are manual. → `ai-patterns/rate-limiting.md`.
- **Conditional requests** (RFC 9110) — for files, `http.ServeContent` / `http.ServeFile` honor `If-None-Match` / `If-Modified-Since` → `304` automatically once you set `ETag`. For JSON it's manual: `w.Header().Set("ETag", tag)`, then `if r.Header.Get("If-None-Match") == tag { w.WriteHeader(304); return }` (no body). Writes: compare `If-Match` to the row `version` → `412` on mismatch, `428` when absent on an unsafe method. → `ai-patterns/conditional-requests.md`.
- **Streaming** — write incrementally and call `w.(http.Flusher).Flush()` after each record so the client sees bytes before the handler returns (NDJSON: `json.NewEncoder(w)` per line + flush; SSE: `Content-Type: text/event-stream`). `io.Pipe` bridges a producer goroutine to the response body. Cancel server work on client disconnect via `r.Context().Done()`. End with a terminal sentinel — a mid-stream error can't change the already-sent `200`. → `ai-patterns/response-streaming.md`.
- **Async job offload** — for work past a request budget, enqueue to `hibiken/asynq` (Redis) or your own worker pool + queue, return `202 Accepted` + `Location: /jobs/{id}`, and serve `GET /jobs/{id}` as the status state machine (`queued → running → succeeded|failed`, result URL + TTL). A bare `go func()` in a handler is fire-and-forget — no status, no retry, dies with the process. → `ai-patterns/async-job-offload.md`.
- **Pagination** — keyset by default, hand-written: `WHERE (created_at, id) < ($1, $2) ORDER BY created_at DESC, id DESC LIMIT $3` — the row-value comparison matches the unique, tiebroken sort and stays O(log n) on deep pages. Encode the last row's `(created_at, id)` into an opaque cursor; apply a default limit + hard cap; fetch `limit + 1` for `hasMore` instead of `COUNT(*)`. Reserve `OFFSET` for small quiescent admin tables. → `ai-patterns/pagination.md`.

## Anti-patterns

- Ignored errors (`_, _ = x()`)
- Panic in library code (return error instead)
- Global mutable state
- Naked returns in long functions
- Using `interface{}` / `any` without narrowing
