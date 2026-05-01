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
