---
name: api-versioning
description: Pattern: API Versioning
kind: ai-pattern
pack: backend
---

# Pattern: API Versioning

> **Hard rule:** Breaking changes within a live version are forbidden. When a break is unavoidable, ship a new version path alongside the old one with a published Sunset date, track per-consumer traffic, and remove the old version only after sustained near-zero usage past sunset.

**When to apply**
- A change falls in the "Breaking" list (remove/rename/retype field, tighten validation, change error shape, change semantics).
- A schema migration changes wire shape and you cannot map old↔new transparently.
- You need to deprecate an endpoint while N-1 clients still call it.

**When NOT to apply**
- Pure additive changes (new optional field, new endpoint, new enum value with documented fallback) — bump nothing.
- You have no consumers yet and can refactor freely; document the call but don't pre-version.

**Halt conditions / mandatory cites**
- Any proposed version bump MUST cite the breaking change at `<path:line>` (the field, the validator, the error code).
- Any "we can do this in v1" claim MUST cite the evolution-rules row that allows it.
- A deprecation plan without a Sunset date + per-consumer traffic dashboard cite is a bug.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden.
- If the project's existing version-routing scheme isn't extracted, halt before proposing v2.

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
Sunset: Thu, 31 Dec 2026 23:59:59 GMT
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

## Detectors (cite-or-halt)

Each finding cites `<path:line>` + the matched pattern + the fix. "The versioning looks wrong" without a cited route / header is not a finding.

### 1. Breaking change within a live version

A removed / renamed / retyped field, a new required input, or a changed error shape landed on an existing `/vN` route with no new version path (a "Breaking" list item shipped in place) → `ship-new-version`.

### 2. Overlapping versions with no deprecation signal

```
BAD:   /api/v1/users and /api/v2/users both live; v1 emits no Sunset
GOOD:  v1 responses carry `Deprecation` + `Sunset` + `Link: rel="successor-version"`
```
Flag a superseded version route whose responses omit `Deprecation` / `Sunset` headers → `add-deprecation-headers`.

### 3. Deprecated route with no Sunset date + traffic tracking

A version marked deprecated (docs/ADR) with no published Sunset date OR no per-consumer usage dashboard — you can't know when removal is safe → `add-sunset-and-tracking`.

### 4. Per-endpoint version mixing

Routes at `/v1/users` alongside `/v2/orders` under one API — consumers can't track a single version → `unify-version-scheme`.

**Closure verbs:** `ship-new-version`, `add-deprecation-headers`, `add-sunset-and-tracking`, `unify-version-scheme`.

## Forbidden

- Breaking changes within a version.
- Silent semantic changes (field name same, meaning different).
- Removing a version without a deprecation period.
- Per-endpoint versions (mixing `/v1/users` + `/v2/orders`) — consumers can't track.
- Versioning before you have consumers (YAGNI — start simple).
- Forever-v1 with "we'll never break" promise (you will).
