# .NET (ASP.NET Core 8+) reference

> **Framework**: ASP.NET Core 8 LTS / 9 STS on .NET 8+
> **Official docs**: https://learn.microsoft.com/aspnet/core/?view=aspnetcore-8.0
> **Version-specific gotchas**: .NET 8 added native AOT for ASP.NET Core; keyed services in DI; `[FromKeyedServices]` attribute; Identity API endpoints; `TimeProvider` abstraction (replace `DateTime.Now`); .NET 9 added hybrid cache + improved OpenAPI.
> **Substitution markers**: Replace project-namespace paths with the project's actual layout.

## Structure (Clean Architecture)

```
src/
├── Api/                        # Controllers, Minimal APIs
├── Application/                # Use cases, interfaces, DTOs
├── Domain/                     # Entities, value objects, domain events
├── Infrastructure/             # EF Core, external services, adapters
└── Shared/                     # Cross-cutting (logging, errors, common)
tests/
├── UnitTests/
├── IntegrationTests/
└── E2ETests/
```

## Rules

### API
- Minimal APIs for small / microservice-style apps.
- Controllers (`ControllerBase`) for larger apps with complex routing / model binding.
- `[ApiController]` attribute for automatic model validation + ProblemDetails errors.
- `ProblemDetails` (RFC 9457, obsoletes 7807) for all error responses.
- Endpoint grouping: `/api/v1/...` + OpenAPI per group.

### DI
- Constructor injection only.
- Service lifetimes: `Scoped` by default (per request), `Singleton` for stateless, `Transient` for lightweight.
- Options pattern (`IOptions<T>`) for config, not magic strings.

### EF Core
- `AsNoTracking()` on read-only queries.
- `Include()` + `ThenInclude()` for eager loading — avoid N+1.
- Projection via `.Select()` into DTOs — don't fetch full entity when you need 2 fields.
- Migrations committed; `dotnet ef database update` in deploy.
- NEVER use `.ToList()` inside queries (brings data to memory unnecessarily).

### Error handling
- `Result<T, Error>` pattern (preferred) OR exceptions for exceptional paths.
- Custom domain errors with codes.
- `ExceptionHandlerMiddleware` → ProblemDetails.

### Validation
- FluentValidation (recommended) OR DataAnnotations.
- Validators in Application layer, registered in DI.

### Async
- `async`/`await` all the way down. NEVER `.Result` / `.Wait()`.
- `CancellationToken` on every endpoint + propagated through services.
- `Task<T>` returns — don't block.

### Auth
- `Microsoft.AspNetCore.Authentication.JwtBearer` for JWT.
- Policies (`AddAuthorization`) over inline role checks.
- `[Authorize]` on controllers / endpoints; `[AllowAnonymous]` explicit for public.

## Observability

- `ILogger<T>` — structured via Serilog / built-in + OTLP exporter.
- `System.Diagnostics.Metrics` + `ActivitySource` for traces.
- `/health` via `AddHealthChecks()`.

## Testing

- xUnit (preferred) or NUnit.
- Testcontainers.NET for DB / Redis / Kafka.
- `WebApplicationFactory<Program>` for integration / controller tests.
- FluentAssertions for readable assertions.

## Anti-patterns

- `.Result` / `.Wait()` on Tasks (sync-over-async deadlock).
- `Repository<T>` generic + service layer that just passes through (pointless abstraction).
- Data annotations AND FluentValidation on the same DTO.
- Auto-mapping with AutoMapper for trivial cases (explicit mapping is often clearer).
- `IEnumerable<T>` return when caller will enumerate multiple times — materialize to `List<T>`.
- Global static config — use Options pattern.
