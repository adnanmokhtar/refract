# Go backend reference (chi / gin / fiber / echo)

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
