---
name: error-handling
kind: example
pack: backend
---

# Pattern: Error Handling

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
export abstract class DomainError extends Error {
  abstract readonly code: string;
  readonly context: Record<string, unknown>;
  readonly cause?: unknown;

  constructor(message: string, context: Record<string, unknown> = {}, cause?: unknown) {
    super(message);
    this.name = this.constructor.name;
    this.context = context;
    this.cause = cause;
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
  constructor(public readonly fieldErrors: FieldError[], message = 'Validation failed') {
    super(message, { fieldErrors });
  }
}

// modules/tenants/errors/tenant-not-found.ts
export class TenantNotFoundError extends NotFoundError {
  readonly code = 'TENANT_NOT_FOUND';
  constructor(public readonly phoneNumberId: string) {
    super(
      `Tenant not found for phone_number_id=${phoneNumberId}`,
      { phoneNumberId },
    );
  }
}
```

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
  constructor(private readonly logger: Logger, private readonly i18n: I18nService) {}

  catch(error: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<FastifyRequest>();
    const res = ctx.getResponse<FastifyReply>();
    const traceId = req.headers['x-request-id'] as string;

    if (error instanceof DomainError) {
      const status = this.statusFor(error);
      const message = this.i18n.translate(error.code, { lang: req.locale });

      this.logger.warn(error.message, { code: error.code, ...error.context, traceId });

      return res.status(status).send({
        status: 'error',
        code: error.code,
        message,
        data: error instanceof ValidationError ? { fieldErrors: error.fieldErrors } : null,
        meta: { traceId },
      });
    }

    // Unmapped — programmer error or upstream surprise
    this.logger.error('Unhandled exception', { error, traceId });
    return res.status(500).send({
      status: 'error',
      code: 'INTERNAL_ERROR',
      message: this.i18n.translate('INTERNAL_ERROR', { lang: req.locale }),
      data: null,
      meta: { traceId },
    });
  }

  private statusFor(error: DomainError): number {
    if (error instanceof NotFoundError) return 404;
    if (error instanceof ValidationError) return 400;
    if (error instanceof UnauthorizedError) return 401;
    if (error instanceof ForbiddenError) return 403;
    if (error instanceof ConflictError) return 409;
    if (error instanceof RateLimitedError) return 429;
    if (error instanceof DependencyFailureError) return 503;
    return 400;  // unknown DomainError = client problem
  }
}
```

This file is the ONLY place domain errors become HTTP responses. Every controller benefits without writing a single try/catch.

## Status mapping

| Domain error | HTTP | When |
|---|---|---|
| `NotFoundError` (and subclasses) | 404 | Resource doesn't exist (or doesn't exist for this tenant) |
| `ValidationError` | 400 | Input failed validation; respond with field errors |
| `UnauthorizedError` | 401 | No valid auth token |
| `ForbiddenError` | 403 | Authenticated but not allowed |
| `ConflictError` | 409 | Unique violation, optimistic lock conflict, double-confirm |
| `RateLimitedError` | 429 | Caller hit a rate limit; include `Retry-After` |
| `DependencyFailureError` | 503 | Upstream we depend on is down/timing out |
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

// RIGHT — translate and re-throw
try { await stripe.charge(...); }
catch (e) {
  if (isStripeCardError(e)) throw new PaymentRejectedError(e.code, { cause: e });
  throw new DependencyFailureError('stripe', { cause: e });
}

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
- **Using error codes as i18n keys directly.** Tying `code` to a translation key locks them — renaming the code breaks translations or the wire format. Keep them in lockstep via a translation table you control.
- **Returning errors as data.** `return { ok: false, error: "..." }` bypasses the type system; callers forget to check, treat the response as success.
- **Generic 500s where 4xx is correct.** "User passed invalid email" returning 500 is a bug — that's 400 ValidationError. 500 is for "we broke", not "they did".

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

## References

- Sandi Metz "Practical Object-Oriented Design", chapter on exceptions — when typed errors pay off.
- "Domain-Driven Design" (Evans) — domain errors as part of the ubiquitous language.
- RFC 7807 (Problem Details for HTTP APIs) — alternative wire format if you need vendor-neutral interop.
