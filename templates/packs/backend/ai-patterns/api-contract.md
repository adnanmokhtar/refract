---
name: api-contract
description: Pattern: API Contract Evolution
kind: ai-pattern
pack: backend
---

# Pattern: API Contract Evolution

> **Hard rule:** Every response (success or error) ships in the same envelope; output DTOs are explicit and decoupled from ORM entities; any change in the "NO" column of the evolution table requires a new version, never a silent edit. Stack traces, ORM entities, and English-prose error keys never reach the wire.

**When to apply**
- Two or more independent consumers exist (web + mobile, or partner integrations) — uncoordinated deploys are now possible.
- A breaking change is on the table; you need to know whether it forces a version bump.
- Retrofitting consistency on an inherited API where each endpoint shapes responses differently.

**When NOT to apply**
- Single consumer you also own with lockstep deploys; freeze it later when a second consumer ships.
- Internal RPC where consumer + producer share types via codegen and CI blocks drift.

**Halt conditions / mandatory cites**
- Any proposal to add/change/remove a field MUST cite the response shape it touches at `<path:line>` (DTO, mapper, snapshot test).
- Any "this is non-breaking" claim MUST cite the evolution table row that justifies it.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden — name the file + line for every consumer impact.
- A doc that proposes a contract change without showing the corresponding mapper + snapshot test diff is a bug.
- If the project's actual envelope or DTO shape isn't extracted, halt and run extraction before drafting the change.

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

Errors keep the same envelope so clients have one parser — **if** the project chose the project-envelope branch:

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

**One envelope decision, made once, recorded in `api-conventions.md`.** There are two defensible answers and they are mutually exclusive for error bodies:

| Branch | Success body | Error body | Pick it when |
|---|---|---|---|
| **Project envelope** (shown above) | `{ status, code, message, data, meta }` | Same five keys, `data: null` (or `data.fieldErrors[]` on a `422`) | One organisation owns the clients; a single parser across success and failure is worth more than interop. |
| **RFC 9457 Problem Details** | Bare resource or `{ data, meta }` | `application/problem+json` with `type` / `title` / `status` / `detail` **unwrapped at the top level** | Third-party or generic consumers, gateways, or anything that already speaks `problem+json`. |

You cannot have both on the same error response: Problem Details puts its members at the root, so wrapping it in `{ status, code, message, data, meta }` is no longer Problem Details. `error-handling.md` owns the error body's shape and status mapping either way; this file owns the *success* envelope and the decision record. Field errors live at `data.fieldErrors[]` in the first branch and in an `errors` extension member in the second — one place, not two.

## Resource naming and URL structure

The path is the first half of the contract and the half consumers read most. It is also the half this pack had no rules for — an agent emitting a `| Method | Path | ... |` table had nothing telling it what a good path looks like, so it copied whatever the nearest sibling did.

| Rule | Shape | Counter-shape |
|---|---|---|
| **Plural nouns for collections** | `/orders`, `/orders/{orderId}` | `/order`, `/getOrder` |
| **kebab-case path segments** | `/shipping-addresses` | `/shippingAddresses`, `/shipping_addresses` |
| **No verbs in paths** — the method is the verb | `DELETE /orders/42` | `POST /orders/42/delete` |
| **Sub-resource for containment** | `/orders/42/items/7` | `/order-items?orderId=42` when the item has no life outside the order |
| **Query string for filtering, not identity** | `/orders?status=paid` | `/orders/paid` |

Doctrine: Zalando RESTful API Guidelines #134 (MUST pluralize resource names), #129 (MUST use kebab-case for path segments, `^[a-z][a-z\-0-9]*$`), #141 (MUST keep URLs verb-free — "the only place where actions should appear is in the HTTP methods").

### The escape hatch for genuinely non-CRUD actions

Some operations are not a resource. `cancel`, `publish`, `retry`, `archive` — forcing them into a status `PATCH` produces a worse contract, not a purer one, because the transition has preconditions and side effects that "set a field" does not describe.

The sanctioned form is a **custom method**: `POST /v1/{resource}:verb` — a colon, then a camelCase verb.

```
POST /v1/orders/42:cancel        ← has side effects → POST
GET  /v1/reports/7:preview       ← pure retrieval → GET
```

Google's API Improvement Proposals define this precisely ([AIP-136](https://google.aip.dev/136)): the URI "**must** use a `:` character followed by the custom verb"; the HTTP method "**must** be `GET` or `POST`", with `GET` for methods retrieving data or resource state and `POST` "if the method has side effects or mutates resources or data"; the name "**should** be a verb followed by a noun", must not contain prepositions, and "if word separation is required, `camelCase` **must** be used".

**This is a last resort, not a second style.** Three custom methods on a surface is a design choice; thirty is a sign the resource model is wrong and you have built RPC with extra punctuation. Before reaching for one, check whether the action is really a sub-resource creation (`POST /orders/42/cancellations` — which gives you a record of *who* cancelled and *when*, for free).

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
- **Validate on the raw value, THEN normalize.** Not the other way round. `request-validation.md` § "The order" owns this rule and argues it properly, and its Detector 7 flags the reverse as a canonicalization-order bug: normalising first lets an over-long input, a bidi override, or a padded lookalike be *rewritten into something that passes* a check the raw bytes would have failed. Trim and lowercase for identity and storage — after the shape has been judged. The DTO above places `@Transform` on `note` deliberately as the exception the rule allows: a bounded free-text field where the trim cannot manufacture validity out of an invalid value. Do not copy that placement onto an identity field (`email`, `username`, `slug`).

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

**This table is the pack's single classification of safe vs breaking.** `api-versioning.md` § When to bump defers to it rather than restating it — one table, one place to update, no drift. `api-versioning` owns what happens *after* a change lands in the NO column.

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

## Bulk / batch endpoints (API-3)

A batch endpoint (`POST /orders/batch`, `PATCH /products` with an array body) MUST declare ONE failure semantic per endpoint — it is part of the contract, not an implementation detail:

- **All-or-nothing (atomic).** The whole batch commits in a single transaction or none of it does. Success is a plain `200` carrying the envelope; any item failing rolls the transaction back and returns a single `4xx` describing the first offending item. Use this when items are interdependent (an order + its line items) and a partial commit would corrupt state.
- **Best-effort (per-item).** Items are independent and each succeeds or fails on its own. Respond `207 Multi-Status`, and put the per-item outcomes in the envelope `data.results[]`, each row `{ id?, status, code, error? }` — `id` echoing the submitted item (or its index when no id exists yet), `status` one of `success` / `error`, `code` the same stable machine code vocabulary as a top-level error, `error` the human-readable message only on failures. The overall HTTP status is `207` even when some rows failed; clients branch on `results[].status`, never on the envelope-level status alone.

```json
{
  "status": "success",
  "code": "BATCH_PROCESSED",
  "message": null,
  "data": {
    "results": [
      { "id": "ord_1", "status": "success", "code": "OK" },
      { "id": "ord_2", "status": "error", "code": "INSUFFICIENT_STOCK", "error": "SKU-44 is out of stock" }
    ]
  },
  "meta": { "requestId": "req_abc", "succeeded": 1, "failed": 1 }
}
```

Rules:
- **Bound the batch size server-side.** A batch DTO without `@ArrayMaxSize` (or the framework equivalent) is the same parser-killing hole as an unbounded list input — reject an oversize batch up front with `413 Content Too Large` (RFC 9110 §15.5.14 — the section is titled "413 Content Too Large"; "Payload Too Large" is the pre-9110 name) or `422` (semantic limit exceeded), never start processing then OOM mid-stream.
- **One batch-scoped `Idempotency-Key` covers the whole batch.** A retried submit with the same key MUST replay the identical per-item `results[]` set — not re-process, not re-process-the-failures. Storing and replaying the recorded result by key is owned by the distributed-systems pack (`ai-patterns/idempotency` / stored-idempotency-replay); this endpoint's job is to scope the key to the batch and return the stored response verbatim on replay.
- A batch endpoint whose code path silently does best-effort while its OpenAPI says `200` (or vice-versa) is a contract bug — the declared semantic and the wire status MUST agree. Cite the handler `<path:line>` and the schema row.

## Field selection / expansion (API-5, opt-in)

Sparse fieldsets and relation expansion are an **opt-in** capability. Declare ONE convention project-wide, or explicitly opt out — mixing two selection grammars across endpoints is the same bug-parity trap as inconsistent envelopes:

- **Selection:** either JSON:API `fields[<type>]=id,name` OR a flat `?fields=id,name`. Pick one.
- **Expansion:** either `?expand=customer,items` OR `?include=customer,items`. Pick one.
- **Opt out:** if the API does not support selection, say so in the docs and ignore the param — never half-implement it on three endpoints.

Rules:
- **Allow-list selection against the output DTO, never reflectively against ORM columns.** `?fields=` resolved by `Object.keys(entity)` or a dynamic `SELECT` of requested columns is a contract-and-security hole — it re-leaks exactly the internal columns the Output DTO section exists to hide (`password_hash`, `tenant_id`, `deleted_at`). The selectable set is the DTO's field names; an unknown requested field is dropped or `422`'d, never passed through to the ORM.
- **`?expand=` respects the N+1 budget.** Each expandable relation MUST resolve through a batched/joined load, not a per-row lazy fetch — an `?expand=items` that fires one query per parent row is a latency cliff a client can trigger at will. Cap expansion depth and the number of expandable relations per request. Cross-ref `performance` pack `skills/n-plus-one-scan` for the detector.
- An `?expand=` that crosses a tenant or authorization boundary (expanding a relation the caller can't read directly) is a broken-object-level-authorization leak — the expanded relation goes through the same authorization check as a direct read.

## Response compression (PERF-2)

Compression is negotiated, never assumed:

- **Negotiate via `Accept-Encoding`; advertise via `Content-Encoding` + `Vary: Accept-Encoding`.** A compressed response served without `Vary: Accept-Encoding` poisons every shared/CDN cache in front of it — a client that sent `Accept-Encoding: identity` gets handed a cached `br` body it cannot decode (and vice-versa). The missing `Vary` is the classic shared-cache corruption bug; emit it on every negotiated response.
- **Only compress what pays.** Compress bodies above ~1KB (below that the framing + CPU cost loses to the few saved bytes) and only compressible types — `application/json`, `text/*`. Never re-compress already-compressed payloads: `image/*`, `video/*`, `application/zip`, `application/gzip` gain nothing and waste CPU.
- **Algorithm preference.** `br` (brotli) preferred for text where the client advertises it; `zstd` where both ends support it; `gzip` as the universal fallback. Honor the client's `Accept-Encoding` q-values rather than forcing one.

**SECURITY HALT — BREACH / CRIME.** Do NOT compress a response body that mixes a server-held secret (CSRF token, session identifier, signed cookie value reflected in-body) with attacker-influenced reflected input. Compression ratio leaks the secret byte-by-byte under a chosen-plaintext attack. If a body contains both, disable compression for that endpoint or strip the reflected input. This is a security-pack-owned threat (`security` pack) — cite the endpoint `<path:line>` and route the policy there; this file's job is the always-on hook: a compression filter with no allow-list of safe content + no secret/reflection exclusion is a finding.

## Response shaping & size limits (PERF-4)

The response body and the accepted request body are both contract surfaces with size consequences:

- **Prefer narrow list-projection DTOs over full-entity rows.** A list endpoint returning the same fat per-item DTO as the single-resource read ships fields no list view renders (long descriptions, embedded blobs, audit metadata) × N rows. Define a dedicated list-projection DTO (`OrderListItemDto`) carrying only what the collection view needs; the full `OrderDto` stays on `GET /orders/:id`. (Column-level over-fetch / `SELECT *` at the query layer is owned by the `database` pack — shape the DTO here, fix the query there.)
- **Document a max request body-size limit per endpoint; default-deny large bodies.** An endpoint with no body-size cap accepts a multi-megabyte POST that exhausts memory before validation ever runs. Set a per-endpoint limit (a JSON write needs kilobytes; an upload route is the deliberate exception) and reject oversize with `413 Content Too Large` (RFC 9110 §15.5.14). The framework body-parser limit that enforces this is wired in `references/<framework>.md` — route the concrete config there, declare the contract here.

**Cross-references for unbounded / cacheable reads:**
- A single-resource read that clients poll should emit an `ETag` and honor `If-None-Match` so an unchanged resource costs a `304` instead of a re-serialized body — see `ai-patterns/conditional-requests`.
- When a list is genuinely unbounded (export, full-table scan, log tail), do NOT buffer it into one `data[]` and compress it — stream it as NDJSON/SSE so the first row leaves before the last is computed. See `ai-patterns/response-streaming`; the choice between a bounded paginated list and a stream is part of the endpoint's declared contract.

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
3. Migrate one endpoint per PR. Add the new shape under `/api/v2/...`, leave `/api/v1/...` untouched. **Write the migration down with an end date before the first PR.** This step deliberately produces the mixed `/v1/x` + `/v2/y` state that `api-versioning.md` Detector 4 flags; what makes it legitimate rather than drift is a documented, time-boxed window, and Detector 4 is written to stand down when it finds one. A migration with no declared end is indistinguishable from a project that simply gave up halfway.
4. Once frontends move, deprecate `v1` per the versioning section.
5. Add a contract test in CI that fails if any new endpoint deviates from the envelope.

## Detectors (cite-or-halt)

Each finding cites `<path:line>` + the matched pattern + the fix. "The API looks inconsistent" without a cited handler / DTO is not a finding.

### 1. Response not in the single envelope

```
BAD:   return this.orders.list();          // returns [...] or { orders: [...] }
GOOD:  return wrapResponse(data, 'OK');     // { status, code, message, data, meta }
```
Flag a controller/handler returning a bare array/object or a bespoke `{ orders: [...] }` key instead of the project's `{ status, code, message, data, meta }` wrapper → `wrap-in-envelope`.

### 2. Output DTO leaks the ORM entity

```
BAD:   return this.productRepo.findOne(id);  // ships password_hash, tenant_id, deleted_at
GOOD:  return this.productMapper.toDto(entity);
```
`grep` for a handler returning a repository/entity result with no mapper (`return this.*Repo.find`, `return await *.findOne`) → `map-to-output-dto`.

### 3. Breaking field change with no version bump

A removed / renamed / retyped response field, a new required input field, or tightened validation shipped on the same `/vN` path with no ADR (any "NO" row in the evolution table) → `bump-version` (route to `ai-patterns/api-versioning.md`).

### 4. DTO field with no validator

`@Body() body: any`, or an input DTO field carrying no `class-validator` / zod / pydantic decorator — the "validation as documentation" trap → `add-validator`.

### 5. Changed `code` value

An error `code` renamed ("it was ugly") with no versioning event → clients keyed on it break → `restore-or-version-code`.

### 6. Resource path violates the naming contract

A route whose path is singular where its siblings are plural, mixes case styles between segments, or encodes an action as a path segment (`/orders/42/delete`, `/getOrders`) instead of a method or a sanctioned `:verb` custom method → `fix-resource-path`.

```
BAD:   POST /order/42/cancelOrder
GOOD:  POST /orders/42:cancel          (custom method — AIP-136 form)
GOOD:  POST /orders/42/cancellations   (sub-resource — better, if you want an audit record)
```

Ships through the deprecation flow like any other path change: the new path lands first, the old one redirects or dual-routes, removal follows the sunset. A path rename is a breaking change even though no field moved.

**Closure verbs:** `wrap-in-envelope`, `map-to-output-dto`, `bump-version`, `add-validator`, `restore-or-version-code`, `fix-resource-path`.

## References

- Stripe API reference (stripe.com/docs/api) — gold standard for stable code, evolved for 12+ years.
- RFC 9745 (Deprecation HTTP header) and RFC 8594 (Sunset HTTP header) — standardized signaling.
- Microsoft REST API guidelines — explicit do/don't list for evolution.
