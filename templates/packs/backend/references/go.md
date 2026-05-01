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

## Anti-patterns

- Ignored errors (`_, _ = x()`)
- Panic in library code (return error instead)
- Global mutable state
- Naked returns in long functions
- Using `interface{}` / `any` without narrowing
