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
- **Pagination**: keyset (cursor) by default over `.Skip(n)` offset (which scans + discards `n` rows and skips/dupes under concurrent writes). Decode the cursor, then `.Where(x => x.CreatedAt < c.CreatedAt || (x.CreatedAt == c.CreatedAt && x.Id < c.Id)).OrderByDescending(x => x.CreatedAt).ThenByDescending(x => x.Id).Take(limit + 1)` — the row-value predicate must match the sort, both index-backed. Clamp `limit` to a default + hard max; fetch `limit + 1` to derive `hasMore` instead of a `.Count()` per page. `.Skip()/.Take()` offset only for small quiescent admin tables. → see `../ai-patterns/pagination.md`.

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

## Resilience, streaming & conditional requests

- **Rate limiting**: use the built-in middleware — `builder.Services.AddRateLimiter(o => o.AddSlidingWindowLimiter / AddTokenBucketLimiter / AddFixedWindowLimiter / AddConcurrencyLimiter(...))`, `app.UseRateLimiter()`, `[EnableRateLimiting("policy")]`. For per-tenant fairness use a partitioned policy: `RateLimitPartition.GetTokenBucketLimiter(partitionKey: tenant, ...)` — a single global partition starves every tenant. Set `o.OnRejected` to write `429` + `Retry-After` (pull `RetryAfterMetadata` off the lease) and add the current draft's two quota fields — `RateLimit-Policy: "default";q=100;w=60` and `RateLimit: "default";r=0;t=30` (`draft-ietf-httpapi-ratelimit-headers`, a DRAFT); the legacy `RateLimit-Limit/Remaining/Reset` triple only while clients still read it; `o.RejectionStatusCode = 429`. The built-in limiter is **in-process**, so a >1-replica deploy needs a distributed store (Redis-backed limiter / gateway / YARP) or each pod enforces its own quota. → see `../ai-patterns/rate-limiting.md`.
- **Conditional requests**: for reads, `OutputCache` (.NET 8+) revalidates via ETag, or set one explicitly — `Response.Headers.ETag = new EntityTagHeaderValue("\"v7\"").ToString()` (minimal APIs: `Results.Ok(dto)` + header) and answer `If-None-Match` with `Results.StatusCode(304)`. For writes, read `Request.Headers.IfMatch` and map it to the EF Core concurrency token (`[Timestamp] byte[] RowVersion` or `.IsConcurrencyToken()`); a stale token surfaces as `DbUpdateConcurrencyException` → `412 Precondition Failed`, absent on a guarded mutation → `428 Precondition Required`. The concurrency token makes the check atomic (`UPDATE ... WHERE Id=? AND RowVersion=?`), not a read-then-write race. → see `../ai-patterns/conditional-requests.md`.
- **Streaming** (unbounded reads/exports): return `IAsyncEnumerable<T>` from a minimal API / controller — ASP.NET Core serializes it as a JSON array incrementally without buffering; source it from EF Core `.AsAsyncEnumerable()` so rows stream from the DB. Use `Results.Stream(...)` for raw/binary output and `TypedResults.ServerSentEvents(...)` (.NET 10) for SSE (manual writes to `Response.Body` on .NET 8/9). Honor the endpoint `CancellationToken` to stop the query on client disconnect; never materialize the whole set with `.ToListAsync()` first. → see `../ai-patterns/response-streaming.md`.
- **Async job offload** (work >~1s): enqueue onto a `System.Threading.Channels.Channel<T>` drained by a `BackgroundService`/`IHostedService` (or Hangfire/Quartz.NET for durable jobs), return `Results.Accepted($"/jobs/{id}", ...)` — `202 Accepted` + `Location`; expose a status endpoint over a `pending→running→{succeeded,failed}` state machine and TTL the stored result. Dedupe submits on an `Idempotency-Key`. Never do the heavy work inline and return `200` after it completes. → see `../ai-patterns/async-job-offload.md`.

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
