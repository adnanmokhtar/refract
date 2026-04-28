---
name: api-contract
description: Pattern: API Contract Evolution
kind: ai-pattern
pack: backend
---

# Pattern: API Contract Evolution

A response shape is a long-term commitment to every consumer that has ever shipped against it — frontends, mobile apps, partner integrations, scripts written by the data team. Once the contract is in someone else's release, you can no longer break it cheaply. This pattern fixes the wire format, names what's safe to change vs not, and prescribes how to evolve when you must break.

## Context

You need this discipline the moment a second consumer exists. Internal-only API consumed by a single SPA you also own? You can refactor freely with a coordinated deploy. As soon as you have a mobile app users haven't updated, a partner with a six-month integration cycle, or `curl` scripts in operations runbooks, breaking changes cost real money — and the cost lands on whoever can't ship the fix in lockstep.

Signals you've underinvested in contracts:
- A frontend deploy and a backend deploy MUST go out together or the app is broken.
- Mobile app store rejections force you to keep dead fields alive forever with no policy.
- "It works on staging but breaks in prod" because staging deserialized loosely.

## Response envelope

Every response — success or error, single or list — wraps in the same envelope:

```json
{
  "status": "success",
  "code": "OK",
  "message": "Order created",
  "data": { "id": "ord_123", "total": 4250 },
  "meta": { "requestId": "req_abc", "timestamp": "2026-04-24T10:00:00Z" }
}
```

Lists add pagination to `meta`:

```json
{
  "status": "success",
  "code": "OK",
  "message": null,
  "data": [{ "id": "ord_1" }, { "id": "ord_2" }],
  "meta": {
    "requestId": "req_abc",
    "page": 1,
    "perPage": 20,
    "total": 142,
    "hasMore": true
  }
}
```

Errors keep the same envelope so clients have one parser:

```json
{
  "status": "error",
  "code": "TENANT_NOT_FOUND",
  "message": "Tenant could not be resolved from the request",
  "data": null,
  "meta": { "requestId": "req_abc", "traceId": "trace_xyz" }
}
```

The `code` is stable and machine-readable. The `message` is human-readable and translatable — clients display `message` directly OR map `code` to their own copy. Never make clients string-match on `message`.

## Input DTOs (validation at the edge)

```ts
// NestJS + class-validator example — applies equally with zod / pydantic / FluentValidation
export class CreateOrderDto {
  @IsString() @IsNotEmpty()
  @Length(1, 64)
  customerId: string;

  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(100)
  @ValidateNested({ each: true }) @Type(() => OrderItemDto)
  items: OrderItemDto[];

  @IsOptional() @IsString() @Length(0, 500)
  @Transform(({ value }) => value?.trim() || undefined)
  note?: string;

  @IsOptional() @IsEnum(['standard', 'express', 'pickup'])
  shippingMethod?: ShippingMethod;
}
```

Rules:
- Every field has a validator. `any` or unannotated fields ship in week one and get exploited in week three.
- Optional ≠ nullable. `note?: string` accepts undefined; `note: string | null` accepts the JSON literal `null`. Pick one and document it. Mixing both ("does empty mean undefined? null? empty string?") is a bug magnet.
- Bound list lengths and string lengths server-side regardless of frontend. `@ArrayMaxSize` prevents a 1M-item POST from killing the parser.
- Normalize on the way in (`@Transform` to trim, lowercase emails, strip control chars). Validate AFTER normalize — `[email protected]` becomes `email@x.com` then validates.

## Output DTOs (separate from ORM)

The frontend consumes a `Product` shape. The database has a `products` table with `created_by_id`, `tenant_id`, `deleted_at`, internal flags. These are NOT the same type.

```ts
// WRONG — leaks ORM internals + cross-tenant fields
@Get(':id')
async getProduct(@Param('id') id: string) {
  return this.productRepo.findOne(id);  // returns full Entity
}

// RIGHT — explicit DTO mapped from entity (helper names are placeholders;
// substitute the project's actual lookup-or-throw helper + mapper from extraction)
@Get(':id')
async getProduct(@Param('id') id: string): Promise<ProductDto> {
  const entity = await this.productService.<projectLookupOrThrowHelper>(id);
  return this.productMapper.toDto(entity);
}
```

Output DTOs are plain typed shapes — no decorators. They exist so:
- Adding an internal column doesn't accidentally appear in API responses.
- Renaming an internal column doesn't break clients.
- A test `toDto` takes a fixture and produces a known string — contract change shows up as a snapshot diff.

## Evolution rules

| Change | Safe? | Why |
|---|---|---|
| Add a new optional response field | Yes | Old clients ignore unknown fields |
| Add a new endpoint | Yes | No existing consumer uses it |
| Add a new optional input field | Yes | Old clients omit it |
| Relax input validation (accept more) | Yes | Old valid inputs still valid |
| Add a new error `code` value | Yes if clients fall back on unknown codes | Verify: clients must not crash on unknown codes |
| Remove a response field | NO | Old clients may read it |
| Rename a response field | NO | Same as remove + add |
| Change a response field's type | NO | Parser breaks |
| Add a required input field | NO | Old clients send invalid input |
| Tighten input validation | NO | Inputs that were accepted are now rejected |
| Change an existing error `code` | NO | Clients keying on it break |

Everything in the NO column requires versioning OR an expand-contract migration with a deprecation window.

## Versioning when you must break

Path-segment versioning is the simplest scheme that survives operational reality:

```
POST /api/v1/orders   ← keep working for the deprecation window
POST /api/v2/orders   ← new shape
```

Concrete process:
1. Write an ADR proposing the v2 shape, the migration path, and the deprecation date for v1. Get it accepted.
2. Ship v2 alongside v1. Both backed by the same domain code; only the DTO mapping differs.
3. Add `Deprecation: <RFC-9745 date>` and `Sunset` headers to v1 responses.
4. Track v1 traffic per consumer (via `User-Agent` / API key). Reach out to integrators who are still on v1 as the date approaches.
5. Remove v1 ONLY after sustained near-zero traffic for two weeks past the sunset date.

Header-based versioning (`Accept: application/vnd.api+json;v=2`) works but is operationally harder — proxies cache by URL, not headers; analytics tools group by URL; curl users forget the header. Use path versioning unless you have a strong reason.

## Localization

```ts
// Server determines locale from Accept-Language or user setting
const message = this.i18n.t('orders.errors.tenant_not_found', {
  lang: ctx.locale,
});
return { status: 'error', code: 'TENANT_NOT_FOUND', message, data: null };
```

`code` never changes per locale. `message` does. Clients in a long-running session cache `code → local copy` mappings — they don't have to call you for translations. This is critical for offline-capable mobile apps.

## Common mistakes

- **Returning the ORM entity directly.** `return this.userRepo.findOne(id)` ships every column including `password_hash`, `created_by_ip`, `internal_notes`. The fix is a mapper layer, not "remember to delete the field" before returning.
- **`any` in DTOs as a deadline shortcut.** A `@Body() body: any` in week one is a `body.user.profile?.preferences?.["x-billing-flag"]` debugging session in month three.
- **Inconsistent envelopes across endpoints.** `/orders` returns `{ orders: [...] }`, `/products` returns `[...]`, `/users/:id` returns `{ data: {...} }`. Clients write three deserializers and bug parity is impossible.
- **Treating validation as documentation.** Decorators that are never enforced (`@MaxLength` without `ValidationPipe` registered) are worse than no decorators — they lie. Verify the pipe is wired, write a failing-input test.
- **Changing `code` values when "they were ugly".** `INVALID_ORDER` becomes `ORDER_VALIDATION_FAILED` in v1.4 without a versioning event. Mobile users on v1.3 see "unknown error" until they update — which they won't, for months.
- **Stack traces in error responses.** `data: { stack: "..." }` in production exposes file paths, dependency versions, sometimes secrets. Stack goes to logs only.

## Testing the contract

```ts
// Snapshot test — locks the shape
it('GET /products/:id returns the contracted shape', async () => {
  const res = await request(app).get('/api/v1/products/prod_test').expect(200);
  expect(res.body).toMatchSnapshot({
    meta: { requestId: expect.any(String), timestamp: expect.any(String) },
  });
});

// Schema test — validates against an OpenAPI doc
it('error response conforms to ErrorEnvelope schema', async () => {
  const res = await request(app).get('/api/v1/products/missing').expect(404);
  expect(res.body).toMatchOpenApiSchema('ErrorEnvelope');
});
```

A breaking change shows up as a failing snapshot. Reviewer asks "is this in the safe column?" — if not, the PR needs a v2.

## Migration path (retrofitting consistency on a chaotic API)

If you've inherited inconsistent endpoints:
1. Inventory every endpoint, capture current shape into snapshots. Now you have a baseline.
2. Pick the new envelope. Write a `wrapResponse(data, code, message)` helper.
3. Migrate one endpoint per PR. Add the new shape under `/api/v2/...`, leave `/api/v1/...` untouched.
4. Once frontends move, deprecate `v1` per the versioning section.
5. Add a contract test in CI that fails if any new endpoint deviates from the envelope.

## References

- Stripe API reference (stripe.com/docs/api) — gold standard for stable code, evolved for 12+ years.
- RFC 9745 (Deprecation HTTP header) and RFC 8594 (Sunset HTTP header) — standardized signaling.
- Microsoft REST API guidelines — explicit do/don't list for evolution.
