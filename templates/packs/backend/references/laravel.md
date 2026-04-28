# Laravel (PHP) reference

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

## Anti-patterns

- Business logic in controllers
- Returning Eloquent models from API routes (leaks schema)
- Ignoring N+1 — Laravel is especially prone
- Firing queries in loops (`foreach ($items as $i) { $i->thing()->get(); }`)
- Leaky `dd()` calls left in code
