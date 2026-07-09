---
name: api-versioning
kind: example
pack: backend
---

# Pattern: API Versioning

You'll have multiple consumers (web, mobile, integrations). They won't upgrade together. Plan for it from day 1.

## Strategy options

| Strategy | Example | Pros | Cons |
|---|---|---|---|
| **URL path** | `/api/v1/users` → `/api/v2/users` | Explicit, cacheable, easy routing | Cluttered URLs |
| **Header** | `Accept: application/vnd.api+json;version=2` | Clean URLs | Harder to test via browser/curl |
| **Query param** | `/api/users?version=2` | Easy to test | Cacheability issues |
| **Media type** | `Accept: application/vnd.company.user-v2+json` | RESTful-pure | Complex for consumers |
| **No versioning** | `/api/users` | Simple | Only works if you're additive-only forever |

**Recommended**: URL path (`/api/v1`) for most teams. Simpler mental model, easier debugging, works with every HTTP tool.

## When to bump version

**Breaking** (requires new version):
- Remove a field.
- Rename a field.
- Change a field's type.
- Change a field's semantics (same name, different meaning).
- Change validation rules (required field, stricter format).
- Change error response shape.
- Remove an endpoint.
- Change endpoint URL or method.

**Non-breaking** (no version bump):
- Add a new optional field.
- Add a new endpoint.
- Add a new enum value (IF consumers fall back on unknown values — document this).
- Relax validation (accept more inputs).

## Evolution within a version

Goal: add features forever without breaking consumers.

### Additive additions
```json
// v1 response — original
{ "id": 42, "email": "a@b.com" }

// v1 response — added phone (OK, additive)
{ "id": 42, "email": "a@b.com", "phone": "+201..." }
```
Old consumers ignore `phone`, new ones use it.

### Tolerant reader pattern
Consumers ignore unknown fields. Don't error on them. Ever.

### Deprecation via response headers
```
HTTP/1.1 200 OK
Sunset: Wed, 11 Jun 2025 23:59:59 GMT
Deprecation: @1767225600
Link: </api/v2/users>; rel="successor-version"
```
Monitors hit this header; consumers know to migrate.

## When you MUST break — multi-version support

Keep N-1 and N versions live simultaneously.

```
/api/v1/users   ← deprecated, sunset 6 months out
/api/v2/users   ← current
/api/v3/users   ← next (planned)
```

### Implementation strategies

**Option A: parallel implementations**
```
controllers/
├── v1/
│   └── users.controller.ts      (reads v1 DTO, calls service)
└── v2/
    └── users.controller.ts      (reads v2 DTO, calls service)
```
Each controller has its own DTO mapping. Shared domain service.

**Option B: single controller + version adapter**
```
controllers/users.controller.ts  (version-aware: reads version, maps to right DTO in/out)
```
Harder when versions diverge significantly.

**Option C: API gateway transforms**
Gateway rewrites v1 requests to v2 format (and v2 responses back to v1). Original code only supports latest.

## Request / response DTOs

```
adapters/http/
├── v1/
│   ├── dtos/create-user.v1.dto.ts
│   └── dtos/user.v1.response.ts
├── v2/
│   ├── dtos/create-user.v2.dto.ts
│   └── dtos/user.v2.response.ts
└── mappers/
    ├── user-v1.mapper.ts    (domain → v1 DTO)
    └── user-v2.mapper.ts    (domain → v2 DTO)
```

Service layer knows NOTHING about versions. Only controller layer.

## Database migration vs API migration

These are different. A schema change doesn't require an API version bump IF you can map between old and new API shapes.

Example:
- v1 has `name`.
- You want to split into `firstName` + `lastName` internally.
- Schema: add columns, write to both, backfill, drop old.
- API v1 still accepts `name` — server splits on first space. v1 still OK.
- API v2 exposes `firstName` + `lastName` directly.

One schema migration, two live API versions, zero break.

## Deprecation timeline

```
Month 0:  v2 released. v1 still primary.
Month 1-3: Announce v1 deprecation. Sunset header appears.
Month 3-9: Dashboard tracks v1 usage. Outreach to remaining consumers.
Month 9-12: v1 returns 410 Gone on a percentage of requests (brownouts).
Month 12:  v1 removed.
```

Adjust timeline to your ecosystem. Public API: 12+ months. Internal API: 3-6 months. Partner API: negotiated.

## GraphQL versioning

GraphQL's answer: never bump versions. Evolve the schema:
- Add new fields freely.
- Deprecate old fields via `@deprecated(reason: "...")`.
- Remove fields after usage drops to 0 (instrument field-level usage).
- Field-level tracking is mandatory — otherwise you can't know when it's safe to remove.

## gRPC versioning

Protobuf is additive-friendly:
- Adding fields is safe (new tag numbers).
- Removing fields: mark `reserved` to prevent reuse.
- Changing types: not safe. New field, deprecate old.
- Services: `UserServiceV2` alongside `UserServiceV1`.

## Contract testing

Pair versioning with contract tests (see `testing/skills/contract-test.md`). A pushed version bump AND no consumer contract change = something's wrong.

## Forbidden

- Breaking changes within a version.
- Silent semantic changes (field name same, meaning different).
- Removing a version without a deprecation period.
- Per-endpoint versions (mixing `/v1/users` + `/v2/orders`) — consumers can't track.
- Versioning before you have consumers (YAGNI — start simple).
- Forever-v1 with "we'll never break" promise (you will).
