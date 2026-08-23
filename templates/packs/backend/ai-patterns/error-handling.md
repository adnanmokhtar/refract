---
name: error-handling
description: "Pattern: Error Handling"
kind: ai-pattern
pack: backend
---

# Pattern: Error Handling

> **Hard rule:** Domain code throws typed `DomainError` subclasses with stable `code` values; ONE global mapper translates them to HTTP/gRPC; raw `throw new Error("...")` is forbidden in services/domain. Stack traces, English-prose matching, and double-logging never cross the wire.

**When to apply**
- The API has more than ~5 endpoints and error variety is no longer trivially enumerable.
- Frontends or partners need programmatic distinction between failure classes (field error vs toast vs redirect).
- You ship in multiple locales and need `code`-driven translations.

**When NOT to apply**
- A 100-line script with one happy path and one error class — the ceremony costs more than it saves.
- Internal-only RPC where caller and callee share a generated error union and CI blocks divergence.

**Halt conditions / mandatory cites**
- Any new error case MUST cite the throw site at `<path:line>` AND the mapper row that translates it.
- A new HTTP status MUST cite the status-mapping table row or extend the table in the same PR.
- A doc that proposes "log + throw" or "catch + return null" is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when classifying an error as 4xx vs 5xx.
- If the global mapper isn't wired (extract its location), halt before adding more error types.

Typed domain errors flow up; one global mapper translates them to HTTP/gRPC/etc. Generic `throw new Error("...")` is a leak — it loses semantics, leaks stack traces, breaks i18n, and makes API consumers parse English prose to detect specific failures.

## Context

Reach for typed errors when:
- The API has more than ~5 endpoints — the error variety stops being trivial to enumerate.
- Frontends or partner integrations need to programmatically distinguish failures (e.g., "show field-level error" vs "show toast" vs "redirect to billing").
- You ship in multiple languages — error messages need translation.
- Logs need to distinguish "expected failure" (404 on a missing resource) from "unexpected failure" (500 on a code bug).

A 100-line script with one happy path and one error doesn't need this. A production API does.

## Hierarchy

```
DomainError (abstract base)
 ├─ NotFoundError
 ├─ ValidationError
 ├─ ConflictError
 ├─ UnauthorizedError
 ├─ ForbiddenError
 ├─ RateLimitedError
 ├─ DependencyFailureError      ← upstream timeout/5xx
 └─ <feature-specific>
      ├─ TenantNotFoundError
      ├─ InsufficientStockError
      ├─ PaymentRejectedError
      └─ SubscriptionExpiredError
```

Every domain error has:
- A stable `code` (`SCREAMING_SNAKE_CASE`) — used by clients + i18n + analytics.
- A developer-facing `message` — for logs, NOT for end-user display.
- Optional `context` — structured fields (no PII) that go to logs/traces, not to clients.

## Implementation

```ts
// libs/errors/domain-error.ts
export interface ErrorOpts {
  context?: Record<string, unknown>;  // structured, PII-free, log-safe
  cause?: unknown;                    // the original throwable
}

export abstract class DomainError extends Error {
  abstract readonly code: string;
  readonly context: Record<string, unknown>;

  // ONE options object. Not `(message, context, cause)` — a positional third arg
  // is the shape that makes `new X(msg, { cause: e })` silently land the raw
  // upstream error in `context`, where the mapper spreads it into the log line.
  constructor(message: string, opts: ErrorOpts = {}) {
    super(message, { cause: opts.cause });   // ES2022 `cause` — no shadow field
    this.name = this.constructor.name;
    this.context = opts.context ?? {};
    // Maintain proper stack trace (V8)
    if (Error.captureStackTrace) Error.captureStackTrace(this, this.constructor);
  }
}

// libs/errors/common.ts
export class NotFoundError extends DomainError {
  readonly code = 'NOT_FOUND';
}

export class ValidationError extends DomainError {
  readonly code = 'VALIDATION_FAILED';
  constructor(public readonly fieldErrors: FieldError[], opts: ErrorOpts = {}) {
    super('Validation failed', { ...opts, context: { ...opts.context, fieldCount: fieldErrors.length } });
  }
}

// A subclass that names a resource in its signature still owes `super` a HUMAN message,
// and must FORWARD the options object — this is the pattern every subclass follows.
export class DependencyFailureError extends DomainError {
  readonly code = 'DEPENDENCY_FAILURE';
  constructor(public readonly dependency: string, opts: ErrorOpts = {}) {
    super(`Upstream dependency failed: ${dependency}`,
          { ...opts, context: { dependency, ...opts.context } });
  }
}

// modules/tenants/errors/tenant-not-found.ts
export class TenantNotFoundError extends NotFoundError {
  readonly code = 'TENANT_NOT_FOUND';
  constructor(public readonly phoneNumberId: string, opts: ErrorOpts = {}) {
    super(`Tenant not found for phone_number_id=${phoneNumberId}`,
          { ...opts, context: { phoneNumberId, ...opts.context } });
  }
}
```

**Two rules the shapes above enforce, both learned the hard way:**

- **`cause` is not `context`.** `context` is spread into the log line (see the mapper). `cause` is not. Putting a raw upstream error — a provider SDK error, a driver error — into `context` ships whatever that object holds (request bodies, tokens, card fragments) straight into your logs, which is the exact leak `backend-principles` forbids. Keep the two channels separate and never spread an unvetted foreign object into `context`.
- **The first argument to `super` is a message, not an identifier.** `super('stripe')` produces `Error: stripe` in every stack trace and log. Name the field on the subclass, build the message from it.

Throwing in domain code:

```ts
// services/orders/place-order.service.ts
async placeOrder(dto: PlaceOrderDto): Promise<Order> {
  const tenant = await this.tenants.findById(dto.tenantId);
  if (!tenant) throw new TenantNotFoundError(dto.tenantId);

  for (const item of dto.items) {
    const stock = await this.inventory.getStock(item.sku);
    if (stock < item.qty) throw new InsufficientStockError(item.sku, item.qty, stock);
  }

  // happy path...
}
```

Notice: NO try/catch on the happy path. Errors bubble. The service is straight-line, readable.

## The single mapper (HTTP example)

```ts
// libs/errors/http-exception-filter.ts
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  constructor(
    private readonly logger: Logger,
    private readonly i18n: I18nService,
    private readonly tracing: TracingService,   // owns the W3C trace context
    private readonly metrics: MetricsService,
  ) {}

  catch(error: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<FastifyRequest>();
    const res = ctx.getResponse<FastifyReply>();
    // Trace id comes from the tracing context (continued from an inbound W3C
    // `traceparent`, or generated at the edge) — NEVER verbatim from a client header.
    // A client-supplied id written into every log line is log-forging: an attacker
    // picks your ops team's trace id and poisons the search. If you echo an inbound
    // id at all, validate charset + length and store it as a SEPARATE field.
    const traceId = this.tracing.currentTraceId();
    const clientRequestId = parseClientRequestId(req.headers['x-request-id']); // validated, bounded, or undefined

    if (error instanceof DomainError) {
      const status = this.statusFor(error);
      // Codes are wire contract; translation keys are ours. Route through a table we
      // own so renaming either side is a one-file change (see Common mistakes).
      const message = this.i18n.translate(CODE_TO_MESSAGE_KEY[error.code], { lang: req.locale });

      this.logger.warn(error.message, { code: error.code, ...error.context, traceId, clientRequestId });

      return res.status(status).send({
        status: 'error',
        code: error.code,
        message,
        data: error instanceof ValidationError ? { fieldErrors: error.fieldErrors } : null,
        meta: { traceId },
      });
    }

    // Unmapped — programmer error or upstream surprise
    this.logger.error('Unhandled exception', { error, traceId, clientRequestId });
    return res.status(500).send({
      status: 'error',
      code: 'INTERNAL_ERROR',
      message: this.i18n.translate(CODE_TO_MESSAGE_KEY.INTERNAL_ERROR, { lang: req.locale }),
      data: null,
      meta: { traceId },
    });
  }

  private statusFor(error: DomainError): number {
    if (error instanceof NotFoundError) return 404;
    if (error instanceof ValidationError) return 422;   // well-formed body, failed semantics
    if (error instanceof UnauthorizedError) return 401;
    if (error instanceof ForbiddenError) return 403;
    if (error instanceof ConflictError) return 409;
    if (error instanceof RateLimitedError) return 429;
    if (error instanceof DependencyFailureError) return 503;

    // An unmapped DomainError is OUR missing mapper row, not the caller's mistake.
    // Defaulting it to 4xx hides the gap: it never enters the 5xx error budget and
    // never pages anyone, so the missing row survives for years. 500 + a counter
    // makes it visible, and Detector 3 below is the fix.
    this.metrics.increment('error_unmapped_total', { error: error.name });
    return 500;
  }
}
```

This file is the ONLY place domain errors become HTTP responses. Every controller benefits without writing a single try/catch.

## Status mapping

| Domain error | HTTP | When |
|---|---|---|
| `NotFoundError` (and subclasses) | 404 | Resource doesn't exist (or doesn't exist for this tenant) |
| `ValidationError` | **422** | Well-formed body that failed *semantic* validation; respond with field errors in `data.fieldErrors[]`. Reserve **400** for a body that could not be parsed at all (malformed JSON, wrong `Content-Type` framing). `request-validation.md` produces the per-field codes; this table owns the status. |
| `UnauthorizedError` | 401 | No valid auth token |
| `ForbiddenError` | 403 | Authenticated but not allowed |
| `ConflictError` | 409 | Unique violation, optimistic lock conflict, double-confirm |
| `RateLimitedError` | 429 | Caller hit a rate limit. Include `Retry-After` (RFC 9110 §10.2.3 — seconds or HTTP-date), the `RateLimit` / `RateLimit-Policy` quota fields, and — when the body is `application/problem+json` — `type: https://iana.org/assignments/http-problem-types#quota-exceeded`. 429 itself is RFC 6585. The exact field syntax, the draft's status, and the legacy-triple transition rule are owned by `ai-patterns/rate-limiting.md`; so is the limiting MECHANISM (per-tenant buckets, shared store, fail-open/closed, load shedding). The mapper owns only **status + which headers get set**. |
| `DependencyFailureError` | 503 | Upstream we depend on is down/timing out |
| Unmapped `DomainError` | 500 | A missing row in *this* table — our gap, not the caller's. Emit `error_unmapped_total` and add the row (Detector 3). |
| Unmapped throwable | 500 | Programmer error, log full context |

## Field-level validation errors

```ts
export interface FieldError {
  field: string;       // 'items[0].quantity'
  code: string;        // 'MIN_VALUE'
  message: string;     // dev-facing
  meta?: Record<string, unknown>;  // { min: 1, actual: 0 }
}
```

The shape gives frontends what they need to attach errors to fields without parsing English. NestJS' built-in `ValidationPipe` produces a similar shape; map it to your `ValidationError` in a single adapter.

**Two members of that row are routinely lost in transit, and both fail silently on the consumer.**

- **`field` is a path, not a key.** `'items[0].quantity'` addresses a nested / array element. A client that types it as a key of its input object (`keyof T`) compiles and then drops every nested and array-indexed error at runtime — the server rejected the sub-object, the user sees nothing. The path form is a deliberate part of the contract; say so when you publish it.
- **`meta` is not decoration — it is the interpolation payload.** `{ min: 1, actual: 0 }` is what renders "At least 1 required" in the user's language. `message` is dev-facing by the comment above it, and `api-contract.md`'s hard rule keeps English-prose error text off the wire. A consumer handed a row without `meta` has exactly one renderable string and it is the wrong one, so a client that shows raw `message` to users is usually a **publishing** defect here, not a copy defect there.

Publish both facts with the row: `api-contract.md` § Publishing the contract — the first delivery names the file and the lane. `@api-contract-sentry` *(frontend pack, when co-installed)* reads that lane and reports what the client actually does with a row, at `<path:line>`. **Absent** → the consumer's handling is *unverified*, not correct — grep the client for `as keyof` / `fieldErrors` yourself before calling the error contract delivered.

## Logging discipline

```ts
// At the mapper:
//   - Domain errors (mapped to 4xx)         → WARN
//   - Domain errors (mapped to 5xx, like dependency failures) → ERROR
//   - Unmapped throwables                   → ERROR + full stack

// In the service: do NOT log + throw. The mapper logs. Doing both = double-logged + reviewer confusion.

// One exception: when catching to translate (e.g., wrapping a database error in a domain error):
try {
  await db.insert(...);
} catch (e) {
  if (isUniqueViolation(e)) throw new DuplicateProductError(sku, { cause: e });
  throw e;  // unrecognized — let it bubble unchanged
}
```

Always include `traceId` (request correlation id). Single field that ties logs across services for one request.

## Wrapping vs swallowing

```ts
// WRONG — catch + log + throw (double-logging)
try { await x(); } catch (e) { logger.error(e); throw e; }

// WRONG — swallow
try { await x(); } catch (e) { /* nothing */ }

// WRONG — swallow with sketchy fallback
try { return await fetchPrice(); } catch { return 0; }  // user gets free product

// RIGHT — translate and re-throw. Both subclasses declare `(identifier, opts: ErrorOpts)`
// and forward `opts` to `super`, so `cause` reaches `Error.cause` and NOT `context`.
try { await stripe.charge(...); }
catch (e) {
  if (isStripeCardError(e)) throw new PaymentRejectedError(e.code, { cause: e });
  throw new DependencyFailureError('stripe', { cause: e });
}

// WRONG — the shape this pattern used to ship. With a positional
// `(message, context, cause)` signature, `{ cause: e }` binds to CONTEXT, the
// mapper spreads context into the log, and the raw provider error (with whatever
// request data it carries) lands in your log store. `error.cause` stays undefined.

// RIGHT — graceful degradation with explicit reasoning
try { return await this.cache.get(key); }
catch (e) {
  this.logger.warn('Cache miss due to error; falling back to DB', { error: e });
  return await this.db.get(key);
}
```

## Common mistakes

- **`throw new Error("Tenant not found")`** in domain code. Loses the error type; the mapper can't distinguish; clients can't react. Always a custom `DomainError`.
- **Stack traces in API responses.** Leaks file paths, framework versions, sometimes secrets. Stack goes to logs, never to clients.
- **Catching at the controller "to be safe".** The mapper handles it. Controller try/catch is for genuine local recovery (cache miss → DB, AI timeout → fallback content) — and it must add value, not just rethrow.
- **Empty catch blocks.** `catch (e) {}` swallows real bugs. If you don't want to handle, don't catch.
- **Logging + throwing.** Double entries in logs, reviewer confusion. Log OR throw, not both.
- **Using error codes as i18n keys directly.** `i18n.translate(error.code, …)` welds the wire contract to your translation file — renaming either one breaks the other, and the wire contract is the one you cannot rename. The mapper above routes through `CODE_TO_MESSAGE_KEY`, a table you own; that indirection is the whole fix.
- **Passing an upstream error as `context`.** See the constructor rules above — it is a log-leak, and it silently leaves `error.cause` undefined so the chain you thought you preserved is gone.
- **Returning errors as data.** `return { ok: false, error: "..." }` bypasses the type system; callers forget to check, treat the response as success.
- **Generic 500s where 4xx is correct.** "User passed invalid email" returning 500 is a bug — that's a `422` `ValidationError`. 500 is for "we broke", not "they did". The inverse is equally a bug: an *unmapped* error defaulted to 4xx says "they did" about something you have not classified.

## Testing

```ts
it('throws TenantNotFoundError when tenant missing', async () => {
  await expect(service.placeOrder({ tenantId: 'missing', items: [] }))
    .rejects.toBeInstanceOf(TenantNotFoundError);
});

it('mapper translates TenantNotFoundError to 404', async () => {
  const res = await request(app).post('/orders').send({ tenantId: 'missing' });
  expect(res.status).toBe(404);
  expect(res.body).toMatchObject({
    status: 'error',
    code: 'TENANT_NOT_FOUND',
    data: null,
  });
});

it('mapper does not leak stack on unknown error', async () => {
  jest.spyOn(repo, 'find').mockRejectedValue(new TypeError('boom'));
  const res = await request(app).get('/orders/abc');
  expect(res.status).toBe(500);
  expect(res.body).not.toHaveProperty('stack');
  expect(res.body.code).toBe('INTERNAL_ERROR');
});
```

## Migration path

If the codebase throws raw `Error`:
1. Define `DomainError` base + the common subclasses (NotFound, Validation, Conflict, etc.).
2. Add the global mapper. Wire it.
3. In the most-trafficked endpoint: replace one `throw new Error(...)` with a typed error. Test.
4. Add a CI rule: `throw new Error(` is blocked in `services/` and `domain/` directories.
5. Sweep remaining throws module by module. Each PR converts one module.
6. Frontends start consuming `code` for field errors. Drop English string-matching.

## Detectors (cite-or-halt)

Each finding cites `<path:line>` + the matched pattern + the fix. "Error handling looks off" without a cited throw site / mapper row is not a finding.

### 1. Raw `throw new Error` on a user path

```
BAD:   throw new Error('Tenant not found');   // loses type, unmappable, leaks prose
GOOD:  throw new TenantNotFoundError(id);
```
`grep -rn "throw new Error(" services/ domain/` (or the project's equivalent layers) → `throw-typed-error`.

### 2. Stack trace in the response body

A response payload carrying `stack` / `stacktrace` / a raw framework error dump (`data: { stack: ... }`) leaks file paths, versions, sometimes secrets → `strip-stack-to-logs`.

### 3. Error not mapped in the single mapper

A `DomainError` subclass with no row in the global `statusFor` / exception-filter mapping (falls through to a generic 500) → `add-mapper-row`.

### 4. catch + log + throw (double-logging), or swallow

```
BAD:   catch (e) { logger.error(e); throw e; }   // mapper logs it again
BAD:   catch (e) { /* nothing */ }                // swallows real bugs
GOOD:  catch (e) { throw new DependencyFailureError('stripe', { cause: e }); }
```
Flag a catch that logs-and-rethrows unchanged, or an empty catch → `translate-or-let-bubble`.

### 5. Generic 500 where 4xx is correct

A user-input failure (bad email, missing field) surfaced as 500 instead of a `422` `ValidationError` → `reclassify-4xx`. The mirror case is also a finding: an *unmapped* `DomainError` defaulted to a 4xx, which hides a missing mapper row behind a status nobody pages on.

**Closure verbs:** `throw-typed-error`, `strip-stack-to-logs`, `add-mapper-row`, `translate-or-let-bubble`, `reclassify-4xx`.

## References

- Sandi Metz "Practical Object-Oriented Design", chapter on exceptions — when typed errors pay off.
- "Domain-Driven Design" (Evans) — domain errors as part of the ubiquitous language.
- RFC 9457 (Problem Details for HTTP APIs, obsoletes RFC 7807) — alternative wire format if you need vendor-neutral interop. **The two are mutually exclusive at the top level**: `application/problem+json` puts `type` / `title` / `status` / `detail` unwrapped at the root, so an error body cannot simultaneously be the project's `{ status, code, message, data, meta }` envelope. Pick one per API, declare it in `api-conventions.md`, and if you pick Problem Details say so in `api-contract.md` too — that file's "errors keep the same envelope" rule is the project-envelope branch of this choice, not a contradiction of it. When exposing it, set `Content-Type: application/problem+json`, give each error class a stable, dereferenceable `type` URI (NOT the human `title` — the URI identifies the error class and should resolve to docs), and keep this project envelope's `code` mapped 1:1 to that `type` URI so the two representations never diverge.
