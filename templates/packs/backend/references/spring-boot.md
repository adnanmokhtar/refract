# Spring Boot (Java / Kotlin) reference

> **Framework**: Spring Boot 3.2+ on Java 17+ / Kotlin 1.9+ • Spring Framework 6
> **Official docs**: https://docs.spring.io/spring-boot/docs/current/reference/html/
> **Version-specific gotchas**: Spring Boot 3 dropped Javax (now `jakarta.*` namespace) — every import broke from v2; `spring-boot-starter-validation` now opt-in; native compilation via GraalVM is first-class; `RestClient` (Spring 6.1+) preferred over deprecated `RestTemplate`.
> **Substitution markers**: Replace `com.company.app` with the project's actual base package.

## Structure

```
src/main/java/com/company/app/
├── Application.java            # @SpringBootApplication
├── config/                     # @Configuration classes
├── modules/
│   └── <name>/
│       ├── api/                # @RestController
│       ├── application/        # @Service, use cases
│       ├── domain/             # entities, value objects, domain errors
│       ├── infrastructure/     # repositories, JPA entities, adapters
│       └── dto/                # request / response DTOs
└── common/                     # shared exceptions, interceptors, utils
```

## Rules

### API layer
- `@RestController` thin — no business logic.
- `@Valid` on every request body.
- `@ControllerAdvice` for global exception mapping (domain error → HTTP status).
- `ResponseEntity<T>` for explicit status codes.
- Use records (Java 17+) or data classes (Kotlin) for DTOs.

### Service layer
- `@Service` for business logic.
- Constructor injection only (no `@Autowired` on fields).
- Transactional boundaries declared with `@Transactional` at service layer.
- Avoid `@Transactional` on public methods that call other `@Transactional` methods of the same bean (proxy bypass).

### Data layer
- Spring Data JPA for standard CRUD.
- Use projections / `@Query` for custom reads — don't fetch entities you won't fully use.
- Avoid `LAZY` fetch + `@Transactional` boundaries mismatch (classic N+1).
- `@EntityGraph` or `JOIN FETCH` to eager-load explicitly.
- Never expose JPA entities from controllers — always map to DTO.

### Validation
- Bean Validation (`jakarta.validation`) — `@NotNull`, `@Size`, `@Pattern`, custom validators.

### Security
- Spring Security 6+.
- JWT via `spring-security-oauth2-resource-server`.
- CSRF disabled for stateless JSON APIs (kept for form-based).
- Method-level: `@PreAuthorize("hasRole('ADMIN')")`.

### Testing
- `@SpringBootTest` — integration.
- `@WebMvcTest` — controller only.
- `@DataJpaTest` — repository only.
- Testcontainers for real DB / Kafka / Redis in integration tests.

## Observability

- Actuator (`/actuator/health`, `/actuator/metrics`, `/actuator/prometheus`).
- Micrometer for metrics.
- OpenTelemetry agent for traces.

## Resilience, streaming & conditional requests

- **Rate limiting** (inbound, per-tenant): Bucket4j with per-key buckets (`ProxyManager` over a shared store — Redis/Hazelcast — for multi-instance), or Resilience4j `RateLimiter`. Wrap in an `OncePerRequestFilter`/`HandlerInterceptor` keyed on tenant/API-key; on miss return `429 Too Many Requests` (RFC 6585) + `Retry-After` (RFC 9110 §10.2.3) + `RateLimit-Limit`/`RateLimit-Remaining`/`RateLimit-Reset` (IETF draft-ietf-httpapi-ratelimit-headers — a DRAFT, prefer unprefixed over legacy `X-RateLimit-*`). Decide FAIL-OPEN vs FAIL-CLOSED on store outage; emit `503` for admission control. → see `../ai-patterns/rate-limiting.md`.
- **Conditional requests**: register `ShallowEtagHeaderFilter` for auto-computed ETags on read responses, or set them explicitly via `ResponseEntity.eTag(...)` / `.lastModified(...)`; honour `If-None-Match` → `304 Not Modified` (revalidation). For writes, read `@RequestHeader(value = "If-Match", required = false)` → `412 Precondition Failed` on mismatch, `428 Precondition Required` when absent on a guarded resource; back the check with a JPA `@Version` column so optimistic-lock conflicts surface as `412` not `500` (`OptimisticLockingFailureException` → mapped in `@ControllerAdvice`). All per RFC 9110 (obsoletes RFC 7232). → see `../ai-patterns/conditional-requests.md`.
- **Streaming** (unbounded results): MVC — return `StreamingResponseBody` (chunked, RFC 9112) or `ResponseBodyEmitter`/`SseEmitter` for push; WebFlux — return `Flux<T>` with `produces = MediaType.APPLICATION_NDJSON_VALUE` (or `TEXT_EVENT_STREAM_VALUE` for SSE). Flush incrementally, emit a mid-stream terminal-error sentinel (status is already `200` once headers flush — a trailing error object, not a thrown exception), and cancel the producing query/Flux on client disconnect. → see `../ai-patterns/response-streaming.md`.
- **Async job offload** (long work off the request thread): `@Async` service method (or Spring Batch / a broker for durable jobs) → controller returns `202 Accepted` + `Location` header pointing at a status URL; expose a `GET /jobs/{id}` status endpoint over a `PENDING→RUNNING→{SUCCEEDED,FAILED}` state machine; make submit idempotent (dedupe on an `Idempotency-Key`) and TTL the stored result. → see `../ai-patterns/async-job-offload.md`.

> **Problem Details for errors**: serialise the above failures (`429`/`412`/`428`/`503`) as `application/problem+json` (RFC 9457, obsoletes RFC 7807) — Spring 6's `ProblemDetail` / `ErrorResponseException` do this natively; the `type` is a stable dereferenceable URI per error class, not the human `title`.
> **Integration hooks** (owned by sibling packs — pointer, not policy):
> - Outbound resilience (retry/circuit-breaker/bulkhead via Resilience4j, DLQ, stored idempotency-replay) → `distributed-systems` pack; this section covers only *inbound* limiting.
> - RED metrics / OTel spans on the rate-limit filter, stream emitter, and job state transitions (watch tag cardinality on tenant/job-id) + audit-log on admission decisions → `observability` pack.

## Pagination

- **Cursor-first (keyset)**: for growing tables prefer Spring Data keyset scrolling (`ScrollPosition.keyset()` → `KeysetScrollPosition`, repository returns `Window<T>`; Spring Data 3.1+) over `Pageable` offset paging, which rescans and skips/dupes rows on deep pages. → see `../ai-patterns/pagination.md`.
- **`Slice` over `Page` for feeds**: return `Slice<T>` (or `Window<T>`) so Spring Data issues no `COUNT(*)`; reserve `Page<T>` (which counts) for small admin tables that genuinely need a total + jump-to-page.
- **Bounded page size**: cap with `@PageableDefault(size = 20)` and a `PageableHandlerMethodArgumentResolver` `maxPageSize` (the default 2000 is too high) so a client can't request an unbounded page.
- **Stable, unique sort**: the `Sort` MUST be a total order — append the id, e.g. `Sort.by("createdAt").descending().and(Sort.by("id").descending())`; keyset scrolling requires it and a non-unique sort drops/repeats rows across pages.
- **Index the sort columns**: the keyset predicate + `ORDER BY` must be index-backed or deep scrolls fall back to a scan; never expose the raw offset in the cursor.

## Anti-patterns

- Field injection (`@Autowired` private field).
- Returning JPA entities from controllers.
- `@Transactional` wrapping an entire service method including external API calls.
- `findAll()` on large tables.
- `Optional` misuse (don't chain 5 `.map().orElse()` — extract to a method).
- `@ComponentScan` that scans outside your package (slow + surprising).
