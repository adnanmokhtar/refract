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
| **Date-pinned / rolling** | Consumer pinned to the version active at signup; `X-Api-Version: 2026-05-01` overrides per request | Highest consumer freedom — nobody is forced to migrate on your schedule; upgrades are opt-in and reversible | Highest server-side burden: **every pinned version is code you still run**. Needs a request-time transform layer and per-version conformance tests, or it rots into N forks of the handler |
| **No versioning** | `/api/users` | Simple | Only works if you're additive-only forever |

**Recommended**: URL path (`/api/v1`) for most teams. Simpler mental model, easier debugging, works with every HTTP tool.

**And the limit on that recommendation, which you must record rather than assume.** URL-path versioning is dominant and defensible, but it is not uncontested: Zalando's RESTful API Guidelines forbid it at **MUST** level (#115 "MUST not use URL versioning") and require media-type versioning instead (#114 "MUST use media type versioning"). Their reasoning is that the URI should identify the resource, not a representation of it — a `/v1/orders/42` and a `/v2/orders/42` are the same order, and giving them different URIs breaks the identity that caching, linking and `Location` headers depend on. That is a real argument, and it is why the choice has to be a recorded decision, not a default.

| Your situation | Choose | Because |
|---|---|---|
| Internal API, consumers deploy in lockstep with you | **URL path** | The identity objection costs you nothing when no third party is holding a link; the debuggability is worth real money. |
| Public API with long-lived third-party consumers | **Date-pinned** or **media type** | Consumers upgrade on their own timeline. With URL paths, every break is a migration project you impose on people who don't work for you. |
| Hypermedia / heavy client-side caching / URIs stored by consumers | **Media type** | This is the case Zalando's MUST is actually about — stored URIs must not go stale because you shipped a field rename. |

Record the choice and the reason in an ADR. "We used `/v1` because everyone does" is the answer this table exists to stop.

## When to bump version

**The safe/breaking classification lives in ONE place: `api-contract.md` § Evolution rules.** That table has a "Why" column, it is what `api-contract`'s own halt condition makes you cite, and duplicating it here is how the two copies drift apart. Read it there; this pattern owns what you do *after* the answer comes back "breaking".

Two additions that are versioning-specific and are not in that table:

- **Changing an endpoint's URL or method** is breaking, and it is the one break a response-shape table cannot see.
- **A new enum value** is safe only if consumers demonstrably fall back on unknown values. That is a claim about someone else's code — verify it against a real client or treat the change as breaking.

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
Month 9-12: v1 brownouts — a percentage of requests get 503 + Retry-After (see below).
Month 12:  v1 removed.
```

Adjust timeline to your ecosystem. Public API: 12+ months. Internal API: 3-6 months. Partner API: negotiated.

### Brownouts — use 503, never 410

A brownout is a deliberate, scheduled, *partial* failure: you fail a rising percentage of v1 traffic so remaining consumers discover their dependency before the removal date, while their next retry still succeeds. The status code matters more than it looks.

- **`503 Service Unavailable` + `Retry-After`.** Semantically "temporarily unavailable", which is exactly true during a brownout, and not cacheable by default.
- **Never `410 Gone` for a brownout.** [MDN, HTTP 410](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/410): "A 410 response is cacheable by default." A probabilistic 410 can be stored by an intermediary or the client's own HTTP cache and then replayed for *every* subsequent request — permanently breaking a consumer that the brownout was only meant to nudge. You wanted a fire drill and you shipped an outage.
- **`410` is correct for the actual removal**, at which point it is no longer probabilistic and its cacheability is a feature. Set an explicit `Cache-Control` anyway so you control how long.
- **Announce the schedule.** A brownout nobody was told about is indistinguishable from an incident, and your consumers will page *their* on-call, not yours.

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

Pair versioning with contract tests (see `testing/skills/contract-test/SKILL.md`). A pushed version bump AND no consumer contract change = something's wrong.

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

### 4. Per-endpoint version mixing outside a declared migration window

Routes at `/v1/users` alongside `/v2/orders` under one API, with **no** documented, time-boxed migration in `ai/adr/` or `api-conventions.md` → `unify-version-scheme`.

**Does not fire during a declared migration.** `api-contract.md` § Migration path deliberately ships v2 one endpoint per PR, which produces exactly this mixed state on purpose. That is the correct way to migrate a large surface; what makes it acceptable is that it is written down with an end date. A mixed state with no end date is the finding.

### 5. Brownout implemented with a cacheable status

A deprecation brownout returning `410` (or any cacheable status) on a percentage of requests → `fix-brownout-status`. Cite the branch that picks the status. `410` is cacheable by default, so a probabilistic one becomes permanent for whichever consumers cached it — the brownout stops being reversible, which was its entire point.

### 6. Deprecation timeline with a brownout step and no brownout mechanism  `[self-policed]`

A deprecation plan whose timeline names a brownout phase with nothing in the code or gateway config that implements it. grep cannot always see gateway-level traffic policy — mark `[self-policed]`: the reviewer asserts they located the mechanism (or its absence) rather than inferring it from the doc. A technique named once in a timeline and implemented nowhere is theatre, and this detector exists so the pack does not ship its own.

**Closure verbs:** `ship-new-version`, `add-deprecation-headers`, `add-sunset-and-tracking`, `unify-version-scheme`, `fix-brownout-status`.

## Forbidden

- Breaking changes within a version.
- Silent semantic changes (field name same, meaning different).
- Removing a version without a deprecation period.
- Per-endpoint versions (mixing `/v1/users` + `/v2/orders`) **as a steady state** — a consumer must then track a version per resource instead of one per API, and your OpenAPI document has no single version to name. (Kubernetes ships per-resource-group versions and it works, so this is a cost, not a law: it works there because the group→version map is published, machine-readable, and discoverable. If you cannot say the same, don't.) Acceptable only inside a documented, time-boxed migration window.
- Versioning before you have consumers (YAGNI — start simple).
- Forever-v1 with "we'll never break" promise (you will).
