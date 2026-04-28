# Express (Node) reference

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

## Anti-patterns

- Fat controllers with business logic
- Direct DB access in controllers
- Callback-style middleware when async is cleaner
- `try { } catch (e) { res.status(500).send(e) }` — leaks internals
