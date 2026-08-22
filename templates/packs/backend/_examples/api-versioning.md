---
name: api-versioning
kind: example
pack: backend
---

# Pattern: API Versioning

> **Hard rule:** Breaking changes within a live version are forbidden. When a break is unavoidable, ship a new version path alongside the old one with a published Sunset date, track per-consumer traffic, and remove the old version only after sustained near-zero usage past sunset.

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
| **Date-pinned / rolling** | Consumer pinned to the version active at signup; `X-Api-Version: 2026-05-01` overrides per request | Consumers upgrade on their own timeline; upgrades are opt-in and reversible | Every version you ever shipped is code you still run — needs a chained transformation layer and per-version conformance tests |
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

## Where the version branch is allowed to live

**The service layer knows nothing about versions. Only the adapter layer does.** Version-specific DTOs and mappers live beside the controller that serves them; everything below the adapter receives and returns the domain shape with no version in it.

This is the rule Detector 8 enforces, and it is what makes every scheme above survivable. A version conditional that has sunk into a service, a repository or a job cannot be removed when that version is retired — nobody can prove which branch is dead — so the versioning scheme stops being reversible, which was the whole reason to buy one.

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
Month 9-12: v1 brownouts — a percentage of requests get 503 + Retry-After.
Month 12:  v1 removed.
```

Adjust timeline to your ecosystem. Public API: 12+ months. Internal API: 3-6 months. Partner API: negotiated.

**Never `410 Gone` for a brownout** — it is cacheable by default, so a probabilistic one can be stored and replayed permanently, turning a fire drill into an outage. `410` is correct for the actual removal, where it is no longer probabilistic. Full argument in `ai/patterns/api-versioning.md` § Brownouts.

## Non-HTTP surfaces — deliberately not covered here

GraphQL and gRPC both have well-documented, tool-enforced evolution rules of their own (`@deprecated` plus field-level usage tracking; additive tag numbers plus `reserved`), and every schema-registry or linter in either ecosystem already checks them better than prose here could. Restating them would produce a fourth copy that drifts.

What **does** carry over from this file, and is the part teams get wrong on those surfaces too: you still cannot remove a field until usage is measurably zero, and "nobody should be using it" is not a measurement. The instrument is different (field-level usage tracking rather than a per-version traffic dashboard); the discipline in § Deprecation timeline is the same one.

Contract tests are the mechanical form of that discipline on any transport — a version bump with no consumer contract change is a signal, not a success. They are owned by the testing pack.

## Forbidden

- Breaking changes within a version.
- Silent semantic changes (field name same, meaning different).
- Removing a version without a deprecation period.
- Per-endpoint versions (mixing `/v1/users` + `/v2/orders`) — consumers can't track.
- Versioning before you have consumers (YAGNI — start simple).
- Forever-v1 with "we'll never break" promise (you will).
