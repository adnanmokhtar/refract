---
name: request-validation
description: 'Pattern: Request Validation — boundary validation, mass-assignment allow-list, decode→validate→normalize→authorize order, bounds + body-size limits, 422 field-error contract'
kind: ai-pattern
pack: backend
---

# Pattern: Request Validation

> **Hard rule:** Every inbound request is validated at ONE declared boundary before any use-case logic runs — `decode → validate (types / bounds / format) → normalize / canonicalize → authorize` — and writes bind through an explicit allow-list of writable fields. Trusting a request body's shape, binding it straight onto a persistence model (`save(req.body)`, `Object.assign(entity, body)`), or validating deep inside business logic is forbidden. This pattern owns WHAT / WHERE / HOW to validate inbound data; the error *envelope* it emits on failure is owned by `error-handling.md`.

**When to apply**
- Any handler that reads attacker-controlled input — bodies, query params, path params, headers, cookies. That is every public endpoint.
- Any write path that persists or mutates state — over-posting is a privilege-escalation write, not a cosmetic bug.
- Retrofitting a codebase where handlers read `req.body.x` untyped and each validates ad-hoc (or not at all).

**When NOT to apply**
- Internal service-to-service payloads that crossed a trust boundary already validated at the mesh/gateway and are transported with integrity (mTLS + schema-pinned codegen) — validate once at the trust edge, don't re-ceremony every hop. Document the boundary.
- Pure static config loaded at boot from a trusted source (not request-derived).

**Halt conditions / mandatory cites**
- A handler that reads a request field with no boundary schema MUST be cited at `<path:line>` — "it looks validated" is a vibe, not a finding.
- A write that binds a whole body onto an entity MUST cite the bind site (`save(req.body)` / `Object.assign` / `Model.update(params)`) AND name the fields a client can now set that it shouldn't (`role`, `isAdmin`, `tenant_id`, `price`, `ownerId`).
- A "this is bounded" claim MUST cite the length / size / range / depth constraint at `<path:line>` — an unbounded string or array with no cite is a finding.
- A `422` shape claim MUST cite the field-error response builder; an inconsistent one hands off to `error-handling.md` + `api-consistency-audit`.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden — every input surface is named or it is not covered.

Untrusted input is the widest attack surface a service has. This pattern fixes where validation happens (one boundary), the order it runs in (so canonicalization can't smuggle a value past a check), and the allow-list that stops a client writing fields it was never offered. It deliberately stops at the failure *response shape* — that boundary belongs to `error-handling.md`.

## Validate once, at the boundary

Validation lives at the **edge** — the controller / route handler / request-schema layer — NOT scattered through services. The boundary decodes the raw request into a **typed value object** (a validated DTO / command), and only that typed object crosses inward. A use-case that receives `CreateOrderCommand` never re-checks `customerId` is a non-empty string; the type is the proof it was validated.

```ts
// NestJS illustration — substitute your stack's primitive (see Adapt table)
@Post()
create(@Body() dto: CreateOrderDto) {   // ValidationPipe already ran: dto is trusted, typed
  return this.orders.create(dto);       // service receives a value object, not req.body
}
```

Validation *deep inside a service* is the anti-pattern: the same rule gets re-implemented at three call sites, drifts, and one path forgets it. The service's job is business rules (does this customer have credit?), not "is this a string?". If a service is string-checking a field, the boundary leaked.

## The order: decode → validate → normalize → authorize

The four steps are ordered, and the order is load-bearing:

1. **Decode** — parse the wire format (JSON/form/multipart) into a candidate structure. Enforce `Content-Type` and body-size limits HERE, before parsing, so a hostile body is rejected before it costs memory.
2. **Validate** — types, presence, bounds, format (email/URL/enum). Reject on the *raw* value.
3. **Normalize / canonicalize** — trim, Unicode-normalize (NFC), lowercase emails/usernames, strip control chars, collapse path separators — AFTER validation.
4. **Authorize** — check the caller may perform this action on this (now-canonical) object.

**Why canonicalize AFTER validate:** if you lowercase/trim *before* validating, an attacker slips a value past a check that the canonical form would have failed — or defeats a later uniqueness check. `"Admin@x.com "` and `"admin@x.com"` must be the same identity for the uniqueness lookup, so canonicalize first *relative to that lookup* — but a format validator must see the raw bytes so `"a‮b"` (bidi override) or an over-long input is rejected, not silently rewritten into something that passes. Validate the shape on raw input; canonicalize for identity/storage; never let normalization *manufacture* a valid value out of an invalid one.

## Mass-assignment / over-posting — the allow-list

A client sends `{ name, email, isAdmin: true, tenant_id: "other", balance: 999 }`. If the handler binds the whole body onto the entity, the client just granted itself admin, jumped tenants, and set its own balance. This is OWASP **API3 / BOPLA** — a privilege-escalation *write*.

```ts
// WRONG — every property the client sends is now writable
Object.assign(user, req.body); await this.users.save(user);   // over-posting
await this.orders.save(req.body);                              // same hole

// RIGHT — only the offered fields bind; unknown fields are stripped or rejected
const dto = plainToInstance(UpdateUserDto, req.body);  // DTO declares name, email — nothing else
await this.users.update(id, { name: dto.name, email: dto.email });
```

The allow-list is the set of fields the DTO/schema *declares* — everything else is dropped (`whitelist`) or rejected (`forbidNonWhitelisted`). Never bind by reflection over the entity's columns, and never `save(req.body)`. Server-controlled fields (`id`, `role`, `tenant_id`, `ownerId`, `createdAt`, `price` on a customer-facing write) are set by the server from context, never accepted from the body — even if a validator is present.

## Bounds — nothing unbounded

Every input carries a ceiling, enforced server-side regardless of what the client claims:

- **String length** — a `@MaxLength` on every string; an unbounded free-text field is a memory and storage hole.
- **Array size** — `@ArrayMaxSize`; a 1M-element array kills the parser and any per-item fan-out.
- **Numeric range** — `@Min`/`@Max`; a quantity of `-1` or `2^53` is a business-logic and integer-overflow bug.
- **Nesting depth** — cap object/array nesting; deeply nested JSON is a parser-DoS (billion-laughs shape).

## Content-Type + body-size limits (DoS)

Before the body is parsed, two gates:

- **`Content-Type` allow-list** — reject anything the endpoint doesn't accept with `415 Unsupported Media Type`. A JSON endpoint must not hand an arbitrary body to a permissive parser.
- **Max body size** — a per-endpoint byte cap; reject oversize with `413 Payload Too Large` *before* buffering. A JSON write needs kilobytes; the deliberate exception is an upload route (validation of the stream itself is owned by `file-upload.md`). The framework body-parser limit that enforces this is wired in `references/<framework>.md` — declare the contract here, route the config there.

## The 422 error-to-field contract (hand-off)

When validation fails, the response is a **structured field-error** map with **stable machine codes** — not a prose blob:

```json
{ "status": "error", "code": "VALIDATION_FAILED",
  "errors": [
    { "field": "email", "code": "INVALID_FORMAT", "message": "Enter a valid email" },
    { "field": "items", "code": "TOO_MANY", "message": "At most 100 items" }
  ] }
```

`422 Unprocessable Content` for a well-formed body that fails semantic validation; `400` for a body that couldn't be parsed at all. The **envelope shape** (`status` / `code` / `errors[]` field names, the status-mapping) is owned by `error-handling.md` — this pattern's job is to *produce* per-field errors with stable codes; the wire format is that pattern's contract. Divergent `422` shapes across endpoints are an `api-consistency-audit` finding.

## Idempotency-key / header validation

Headers are untrusted input too. An `Idempotency-Key` header MUST be validated (present when required, bounded length, expected charset/format) before it's used as a store key — an unbounded or attacker-shaped key is a cache-poisoning / storage hole. The *replay semantics* of the key belong to the distributed-systems pack; validating its *shape* at the boundary belongs here.

## Adapt to the codebase

Core is stack-agnostic; the primitive differs. Column three is how each does the **writable-field allow-list + bounds** — the load-bearing part.

| Stack | Boundary primitive | Allow-list + bounds |
|---|---|---|
| **NestJS** | class-validator / class-transformer DTO + `ValidationPipe` | `whitelist: true` strips unknown fields, `forbidNonWhitelisted: true` rejects them; `@MaxLength` / `@ArrayMaxSize` / `@Min`/`@Max` for bounds |
| **Express** | `zod` / `joi` / `express-validator` middleware | `z.object({...}).strict()` rejects unknown keys; `.max()` / `.min()` / `.length()` for bounds; parse → typed, never `req.body` downstream |
| **FastAPI** | Pydantic model | `model_config = ConfigDict(extra="forbid")` rejects unknown fields; `Field(max_length=…, ge=…, le=…)` + `conlist(max_length=…)` for bounds |
| **Spring** | Bean Validation `@Valid` on a DTO record | DTO declares only writable fields (no `@JsonIgnoreProperties`-leaked setters); `@Size` / `@Max` / `@Min` / `@Pattern` for bounds |
| **Go** | `validator/v10` + explicit struct binding | Bind into a request struct with only writable tagged fields (never the domain model); `validate:"max=100,min=1"` tags for bounds |
| **Rails** | strong params | `params.require(:user).permit(:name, :email)` is the allow-list; length/range via model validations + a bounded permit set |

Record the chosen primitive + where the boundary lives in `references/<framework>.md`.

## Detectors (cite-or-halt)

Each finding cites `<path:line>` + the matched pattern + the fix. "Validation looks thin" without a cited handler / bind site is not a finding.

### 1. Whole body bound onto a persistence model (mass-assignment)

```
BAD:   Object.assign(entity, req.body); save(entity)   // or  save(req.body)  /  Model.update(params)
GOOD:  update(id, { name: dto.name, email: dto.email })  // explicit allow-list from a typed DTO
```
`grep` for `Object.assign(*, *body)`, `save(req.body)`, `.update(params)`, `new Entity(req.body)` → `report-with-fix` (name the escalatable fields). Also OWASP API3 / BOPLA — route to `@api-reviewer` / `@security-auditor`.

### 2. No boundary validation (untyped body read)

```
BAD:   const x = req.body.customerId;   // untyped, unvalidated, straight into logic
GOOD:  create(@Body() dto: CreateOrderDto)   // boundary schema produced a typed value object
```
Flag a handler reading `req.body.*` / `request.json()[…]` with no DTO/schema at the edge → `report-with-fix` (`add-boundary-schema`).

### 3. Validation deep inside a service instead of the edge

Flag a service/use-case string-checking or format-checking a field the boundary should have proven (`if (typeof x !== 'string')`, re-running an email regex) → the boundary leaked → `report-with-fix` (move the check to the edge, pass a value object inward).

### 4. No length / size / range bound (unbounded input)

Flag a string DTO field with no `@MaxLength` (or stack equivalent), an array with no `@ArrayMaxSize`, a number with no `@Min`/`@Max` → `report-with-fix` (`add-bounds`).

### 5. Missing Content-Type / body-size limit

Flag a body-parsing endpoint with no `Content-Type` allow-list or no max-body-size cap → parser-DoS surface → `report-with-fix` (`add-body-limit`; route framework config to `references/<framework>.md`).

### 6. Inconsistent 422 field-error shape

Flag validation failures returning a bare string / bespoke `{ error: "..." }` instead of the project's structured field-error envelope → hand off to `error-handling.md` + `api-consistency-audit` → `report-flagged`.

### 7. Normalization before validation (canonicalization-order bug)

Flag `.trim()` / `.toLowerCase()` / `normalize()` applied to a value *before* it is validated (rewriting input into something that passes a check the raw value would fail) → `report-with-fix` (`fix-validate-order`).

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete allow-list / boundary-schema / bound / body-limit / order patch.
- `report-flagged` — the fix is a shared-contract decision (adopt one `422` field-error envelope; carve the internal trust boundary) → surface for ADR / hand-off.
- `dismiss` — a documented carve-out applies (an already-validated internal payload behind a trust boundary; trusted static config).

## Related

- `error-handling.md` — the error *envelope*. **Boundary:** this pattern owns WHAT to validate and produces per-field errors with stable codes; `error-handling` owns the error response SHAPE + status mapping.
- `api-contract.md` — contract *evolution* (tightening input validation is a breaking change; this pattern's bounds feed that table).
- `file-upload.md` — validation of the upload stream itself (magic bytes, size, filename) hands off here.
- `api-consistency-audit` (skill) — `422` field-error consistency across endpoints.
- `@api-reviewer` / `@security-auditor` — mass-assignment is also a security sink (OWASP API3 / BOPLA); cross-pack `security` pack + `security-principles` rule (explicit field allow-list, no whole-body mass-assignment).
