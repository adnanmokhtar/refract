# NestJS Clean Architecture rules

> **Framework**: NestJS 10+ on Node 20+ • TypeScript 5+ (11.x is the `legacy` dist-tag, 12.x `latest` — npm registry, 2026-10-14)
> **Official docs**: https://docs.nestjs.com/
> **Version-specific gotchas**: NestJS 10 dropped legacy decorators that worked in v9; `@ValidateNested()` validates nothing without `@Type(() => Child)`; `@nestjs/cqrs` v10 changed event-handler discovery (must export from module). Nest 11 → 12 and Express → Fastify adapter deltas: § Validation, adapter and version traps below.
> **Substitution markers**: Replace `<Module>` / `<UseCase>` / `<Repo>` / DI `Tokens.X` with the project's actual identifiers from `_extracted-idioms.md`.

## Layer imports (strict)

- `core/` → imports NOTHING from NestJS, TypeORM, or any other framework. Pure TS.
- `application/` → imports from `core/` only. Uses ports (interfaces) from `core/ports/`.
- `infrastructure/` → imports from `core/` (ports to implement). May import TypeORM, SDKs, etc.
- `adapters/` → imports from `application/`. Never from `infrastructure/` directly.
- `<module>.module.ts` → the ONLY place that binds adapters ↔ use-cases ↔ infra via DI.

Violation = block at review.

## Dependency injection

- DI tokens are `Symbol('NAME')` declared in `tokens.ts` per module.
- Providers use `{ provide: Token.X, useClass: Y }` — no magic strings.
- Controllers inject use-cases via `@Inject(Tokens.USE_CASE)`.

## DTOs

- Every input DTO has `class-validator` decorators on every field.
- Every input DTO has a test that rejects invalid payloads.
- Output DTOs are plain classes — no decorators needed.
- NEVER return the ORM entity from a controller. Always map.

## Error handling

- Domain errors live in `core/errors/`. They extend a base `DomainError`.
- Controllers catch domain errors and map to HTTP status via a global filter.
- Never throw `new Error(...)` — use a typed error class.
- The global filter keeps an `HttpException`'s own status (`exception.getStatus()`) before its 500 arm. A `@Catch()` that maps every non-domain error to 500 turns the `ValidationPipe`'s 400, `NotFoundException` and the throttler's 429 into 500s (edge-error-scan §1). On the Fastify adapter write through `HttpAdapterHost.httpAdapter.reply(ctx.getResponse(), body, status)` — an Express-style `res.status().json()` throws inside the filter and every error becomes 500 (edge-error-scan §3).

## Validation, adapter and version traps

Each row names the version it was read or run on. Read the project's **installed** versions from the lockfile first; with no lockfile, a row resting on a default is unconfirmed until its proof runs (proof-oracles § Backend V357, the version pair rule).

### Nest 11 → 12 — read from the published tarballs (`@nestjs/common`, `core`, `platform-express`, `platform-fastify` 11.2.7 vs 12.1.3; `@nestjs/schedule` 6.1.3 vs 12.0.2), 2026-10-14

| Behaviour | 11.2.7 | 12.1.3 | What the project does |
|---|---|---|---|
| `ValidationPipe` `forbidUnknownValues` | the constructor sets `{ forbidUnknownValues: false, ...options }`, undoing class-validator 0.14's secure default | the same line | pass `forbidUnknownValues: true`; with validation `groups`, a group with no validators then accepts anything (validation-boundary-scan §6, §9) |
| `transformOptions.enableImplicitConversion` | handed to `plainToInstance`, which runs **before** `validate()` | the same code path; run on 12.1.3: `"false"` → `true`, `""` → `0`, `5` → `"5"` passes `@IsString`, `"2026-02-30"` → March 2 passes `@IsDate` | leave it off; an explicit `@Transform(({ value }) => value === 'true')` on every boolean query field (validation-boundary-scan §3–§4) |
| Body typing — `toValidate()` | skips the metatypes `String, Boolean, Number, Array, Object, Buffer, Date`: an interface, a `type`, `Dto[]`, `Partial<Dto>`, `Record<…>` or a `Dto \| null` union (under `strictNullChecks`) emits `Object`/`Array`, so **nothing is validated**, even with `whitelist` + `forbidNonWhitelisted` | the same list (run on 12.1.3) | a class DTO per body; `new ParseArrayPipe({ items: Dto })` for arrays; `PartialType(Dto)` is a class and is validated (validation-boundary-scan §1) |
| The copy the handler receives with `transform: false` | more than one validator option set → `classToPlain(instance)` (so `@Type` conversions reach the handler); otherwise the raw value | the same | `transform: true`, so the handler's type does not depend on unrelated options |
| Named primitive params | `@Body('sku') sku: string` skips validation (String metatype): `{"sku":{"$gt":""}}` arrives as an object | the same (run on 12.1.3) | a DTO, or a `Parse*Pipe` on the param (validation-boundary-scan §7) |
| 400 body shape | `message: string[]` | new `errorFormat` option (`'list'` default, `'grouped'` keyed by property path); the nested-error flattening was rewritten | snapshot the 400 body in a test when a client parses `message` |
| Standard Schema | — | `@Body({ schema })` only attaches metadata unless `StandardSchemaValidationPipe` is registered (Nest 12 release notes) | register the pipe (validation-boundary-scan §8) |
| Module format | CommonJS | `"type": "module"` (ESM); class-validator / class-transformer loaded with `import()` | a CJS toolchain `require()`-ing `@nestjs/*` breaks — `/upgrade-dep` |
| Adapter pins | `platform-fastify` → `fastify` 5.11.3; `platform-express` → `express` 5.2.1, `multer` 2.4.0, `path-to-regexp` 8.4.2 | `fastify` 5.12.5 and `@fastify/multipart` ^10.1.0 as an optional peer; Express side unchanged | Express 5 route syntax applies on **both** majors (http-contract-scan §11) |
| `@Res({ passthrough: true })` | supported | supported | the Streaming bullet in § Resilience, streaming & conditional requests |
| `@nestjs/schedule` (6.1.3: peer Nest 10 \| 11 · 12.0.2: peer Nest 11 \| 12; both pin npm `cron` 4.4.0) | `@Cron` builds `CronJob.from({ ...options })`: **no `waitForCompletion` unless the decorator passes it**, so a run longer than its period overlaps the next (npm `cron` 4.4.0 overlaps by default — 3 concurrent runs at a 1 s period with 2.5 s of work, run); `@Interval` is a bare `setInterval`; each scheduled method is wrapped in `try/catch` that only logs (`Logger('Scheduler')`); no `timeZone` → the process zone | the same | `@Cron(expr, { waitForCompletion: true, timeZone })`; a lease or a running flag first in the handler; a failure counter or run row in its `catch` (job-lifecycle-scan §4, §6, §7) |

Engines: `node >= 20` on both majors. `@nestjs/common` 11.2.6's `validation.pipe.js` and `route-params.decorator.js` are byte-identical to 11.2.7's (diffed 2026-10-14). A version pair this table does not cover (10.x, 12.2+) is read from the installed package before a row is asserted.

### Express → Fastify adapter (BN-09) — run on Nest 12.1.3, both adapters, 2026-10-14

| Request | Express adapter | Fastify adapter |
|---|---|---|
| 200 KB JSON body | **413** (`express.json` 100 KB default) | 201 (Fastify `bodyLimit` 1 MiB) |
| `Content-Type: application/json` + empty body | 201, body `{}` | **400** |
| `text/plain` body | 201, `@Body()` is `undefined` | 201, `@Body()` is the **string** |
| `application/xml` body | 201, `undefined` (silently accepted) | **415** |
| `{"__proto__": {…}}` | 201 | **400** (`onProtoPoisoning: 'error'`) |
| filter calling `res.status(500).json(…)` | maps `BadRequestException` to 500 (the catch-all defect) | `.json` is not on the reply → TypeError in the filter → **500 for every error** |
| GET handler returning `null` | 200, empty body | 200, body `null` |
| `@Res()` injected, handler returns a value | hangs | hangs |
| wrong method on an existing path | 404, no `Allow` | 404, no `Allow` |

Also different: `@Res()` is Express's `res` on one and the Fastify reply on the other; Express middleware runs through `@fastify/middie` (code reading `res.locals` or `req.route` breaks); `FileInterceptor` / `multer` come from `@nestjs/platform-express` and do not run on Fastify (`@fastify/multipart` instead). The Nest 11 adapters were not run; their body-parser wiring reads the same in the 11.2.7 source. Proof for a migration: the same e2e requests on both adapters, status and body diffed per request (proof-oracles § Backend V346; edge-error-scan §3 owns the filter half, http-contract-scan §11 the body and content half).

Sources: "run" rows were executed in the Refract backend research labs on 2026-10-14 (Nest 12.1.3, class-validator 0.15.1, class-transformer 0.5.1, npm `cron` 4.4.0; research-backend § 1.2, § 1.4, § 1.7); "read" rows come from the npm tarballs named in each heading, fetched and diffed on 2026-10-14.

## Resilience, streaming & conditional requests

- **Rate limiting**: gate inbound load with `@nestjs/throttler` — `ThrottlerModule.forRoot([...])` globally, `@Throttle({ default: { limit, ttl } })` / `@SkipThrottle()` per route. The default in-memory `ThrottlerStorage` resets per pod, so multi-instance deploys MUST use `@nestjs/throttler-storage-redis` (shared store) or each replica enforces its own quota. Throttler emits `429` + `Retry-After`; add the current draft's two quota fields yourself — `RateLimit-Policy: "default";q=100;w=60` and `RateLimit: "default";r=0;t=30` (`draft-ietf-httpapi-ratelimit-headers`, a DRAFT) — keeping any legacy `X-RateLimit-*` / `RateLimit-Limit/Remaining/Reset` set only while clients still read it. Defect: `@Throttle()` on a controller with no shared storage in a >1-replica chart `<deploy/values.yaml>`. → ai/patterns/rate-limiting.md
- **Conditional requests**: enable `ETag` (`app.use(etag())` in `main.ts`, or a response interceptor that hashes the serialized body) so reads revalidate to `304`. For writes, read `If-Match` in a guard/interceptor and compare it to the entity's `version` column (TypeORM `@VersionColumn`); mismatch → `412 Precondition Failed`, missing on an unsafe method → `428 Precondition Required`. Defect: a PATCH controller writing the ORM entity with no `If-Match` check `<*.controller.ts:PATCH>` — last-writer-wins. → conditional-requests.md
- **Streaming**: return `StreamableFile` for file/download responses and for NDJSON (`new StreamableFile(readable, { type: 'application/x-ndjson' })` over a `Readable` that yields one line per row — the default type is `application/octet-stream`; the Express adapter `pipe()`s it and destroys the source when the client leaves, the Fastify adapter hands it to `reply.send` [read, `@nestjs/platform-*` 12.1.3 source, 2026-10-14]); use `@Sse('events')` returning an `Observable` for server-sent events; cancel work on `req.on('close')`. To set a header or status and still let Nest send the return value, inject `@Res({ passthrough: true })`. A bare `@Res()` hands the whole response to the handler: a handler that injects it and **returns a value hangs the request** (Nest never sends), and interceptors (serialization, envelope) are bypassed [V Nest 12.1.3, both adapters]. Write to a bare `@Res()` only when every path — errors included — ends the response itself (`res.end()`, or `reply.raw.end()` on Fastify, whose `@Res()` is the Fastify reply, not Node's `res`). Defect: `@Get() f(@Res() res) { …; return dto; }` `<*.controller.ts>` — hangs (edge-error-scan §5). Defect: building a full array then `res.json()` for an unbounded query `<*.controller.ts>` — heap blow-up, no mid-stream error sentinel. → response-streaming.md
- **Async jobs**: offload work >~1s — a `@nestjs/bullmq` producer enqueues in the controller and returns `202 Accepted` + `Location: /jobs/:id`, a `@Processor()` consumer runs the job, and `GET /jobs/:id` exposes the status state machine (queued→running→done/failed, result behind a TTL). Make submit idempotent via a client key → existing-job lookup. Defect: a controller doing the heavy work inline and returning `200` only after it finishes `<*.controller.ts>`. → async-job-offload.md

## Pagination

- **Cursor-first (keyset)**: expose a repository `page({ limit, cursor })` over a row-value predicate — TypeORM `QueryBuilder` (`WHERE (created_at, id) < (:c, :i) ORDER BY created_at DESC, id DESC LIMIT :n`) or Prisma `cursor`/`take`/`skip: 1`. Keyset is O(log n) and stable; offset (`.skip()`) rescans and skips rows on a growing table. Use `nestjs-paginate` for the offset case on small admin tables. → ai-patterns/pagination.md
- **Bounded limit DTO**: the query DTO carries `@IsInt() @Min(1) @Max(100)` on `limit` with a default (e.g. 20). Defect: a controller reading `limit` off `@Query()` with no `@Max()` cap `<*.controller.ts>` — unbounded `take` is a memory/DoS risk.
- **Stable, unique sort**: order on a unique column set (append the PK tiebreaker); a non-unique `ORDER BY created_at` drops/repeats rows across cursor pages.
- **Opaque cursor, no per-page count**: encode the last row's sort keys as a base64 cursor in the adapter (never leak a raw offset); fetch `take + 1` for `hasMore` instead of a `COUNT(*)`; return the shared `{ data, meta: { nextCursor, hasMore } }` envelope.

## Tests

- Unit tests next to the code (`*.spec.ts`).
- Use-cases: unit tested with mocked ports.
- Controllers: e2e tested with a real DB (test container or sqlite).
- Repos: integration tested against a real DB.
- NEVER hit real external APIs in any test — always mock the client.
