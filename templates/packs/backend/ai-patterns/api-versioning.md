---
name: api-versioning
description: "Pattern: API Versioning"
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

## Date-pinned (rolling) versions — the model, and what it costs to run

The row above reads like "header versioning with nicer strings." It is not. Date-pinning is a different contract: **a consumer never picks a version, it inherits one, and it keeps that one until it acts.** Three moving parts, and you need all three — two out of three is worse than `/v1`.

**1. The pin.** An account is bound to the version that was current the first time it called you. Stripe: *"Your version gets set the first time you make an API request"* ([Stripe, API upgrades](https://docs.stripe.com/upgrades)); their engineering write-up says the account *"is automatically pinned to the most recent version available"* at that moment ([Stripe, API versioning at Stripe](https://stripe.com/blog/api-versioning)). Nobody is ever silently moved to latest. That is the entire value proposition.

**2. The per-request override.** A header names a version and beats the pin for that one call — `Stripe-Version`, `anthropic-version`, `X-GitHub-Api-Version`. Resolution order has to be written down, because it is what gets argued about during an incident. Stripe's is: the `Stripe-Version` header if supplied, then the version of the authorized OAuth application acting on the user's behalf, then *"the user's pinned version"* ([Stripe blog](https://stripe.com/blog/api-versioning)).

**3. The transformation chain.** Not one branch per version — a registry of small **version-change modules**, each of which *"defines documentation about the change, a transformation, and the set of API resource types that are eligible to be modified"* ([Stripe blog](https://stripe.com/blog/api-versioning)). To render a response the server produces the latest shape, then *"walks back through time"* applying every module between latest and the target version, in order.

The consequence is the part people miss: **your handlers only ever know the current shape.** An old version is not old code. It is today's response pushed backwards through N small functions. That is why the model scales to hundreds of versions where parallel controllers (Option A below) die at four.

### The property the whole thing rests on

Every version change must be a **pure, order-dependent, composable function of the payload** — response one way, request the other. No I/O, no database, no clock.

The moment a transformation needs to *look something up* — a column the current schema dropped, a flag on the account, the state of another service — the chain cannot express it. Stripe's answer is an escape hatch rather than a fix: such changes are annotated `has_side_effects`, become no-ops inside the transformation layer, and the real behaviour is handled by checks scattered elsewhere in the codebase ([Stripe blog](https://stripe.com/blog/api-versioning)). Read that as the honest cost line. The model degrades gracefully, but it *does* degrade, and what it degrades into is version conditionals spread through business logic — which the same post names as the debt it is trying to avoid: *"every new version is more code to understand and maintain."*

### What each approach actually buys you

| Approach | The failure mode it prevents | The failure mode it creates |
|---|---|---|
| **URL path** `/v1` → `/v2` | A consumer cannot accidentally receive a shape it was not compiled against — the version is in the string it typed. | Every break is a migration project you impose on people who do not work for you, on your calendar. |
| **Header / media type**, explicit per request | Same as above, without giving one resource two URIs (the Zalando objection). | A caller that forgets the header gets *something* — and whatever you chose as the default is now a silent contract. |
| **Date-pinned / rolling** | The forced-march migration. No consumer is ever moved by your release; upgrades are opt-in, per consumer, and reversible. | You now run every shape you have ever shipped, forever, and the transformation registry is a permanent staffed asset. |

### What it costs to run

- **The transformation layer never shrinks.** Each break adds a module and no release removes one. Stripe states the trade openly: *"Versioning is always a compromise between improving developer experience and the additional burden of maintaining old versions"* ([Stripe blog](https://stripe.com/blog/api-versioning)).
- **Removal needs a written policy or it never happens.** Stripe's public versioning and upgrade pages describe no sunset or removal process for old versions at all — whether any version has ever been retired is **UNVERIFIED** from their own docs; a changelog entry or a published deprecation policy would settle it. GitHub bounds the liability instead: *"the previous API version will be supported for at least 24 more months following the release of the new API version"*, and *"If you specify an API version that is no longer supported, you will receive a `410 Gone` response"* ([GitHub, API Versions](https://docs.github.com/en/rest/about-the-rest-api/api-versions)). That `410` is the correct use — a permanent, non-probabilistic removal, exactly as § Brownouts requires.
- **Conformance tests are per version, not per handler.** The whole chain is only as good as the oldest version you can still prove renders. A version with no test is a version you have already broken and not noticed.
- **Caching gets harder, not easier.** The version is not in the URL, so any shared cache must key on it: *"Including a `Vary` header ensures that responses are separately cached based on the headers listed in the `Vary` field"* ([MDN, `Vary`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Vary)). The *pinned* version is worse — it is derived from the credential, so the only honest cache key is the credential itself, at which point the shared cache is storing one entry per consumer and doing no sharing at all. Mark those responses private.
- **Async deliveries carry a version too.** A webhook is a response you send later, so it is rendered at *some* version, and the naive answer (the account's current pin) means upgrading your API silently changes the payload shape arriving at a receiver you did not deploy. Give each endpoint its own explicit pin: Stripe's *"if an endpoint has an explicit version set, it always uses that version"* ([Stripe, API upgrades](https://docs.stripe.com/upgrades)). See `webhook-flow.md`.
- **The payoff is reversibility.** Because the pin is data, an upgrade is a config change and a rollback is the same change backwards. Stripe allows rollback for 72 hours after an upgrade, and re-delivers webhooks that failed under the new shape using the old one ([Stripe, API upgrades](https://docs.stripe.com/upgrades)). No URL-path scheme can offer that; there, "roll back" means "redeploy the consumer."

### When it is right

- **Public API, many third-party consumers, long tail of integrations you cannot contact.** The people who would bear a forced migration are not on your payroll.
- **You break things often enough that a migration project per break is untenable** — several breaking changes a year, not one every three.
- **Your breaks are structural** (rename, split, retype, re-nest). Those are exactly what a pure payload transform expresses well.
- **You can name the owner of the version registry.** Not the team. The person.

### When it is the wrong choice — which is most of the time

- **Consumers deploy in lockstep with you.** You are paying a permanent tax for a freedom nobody asked for. Use URL path.
- **The break is semantic, not structural.** A transformation can turn `firstName` + `lastName` back into `name`. It cannot turn "`amount` now excludes tax" back into "`amount` includes tax" — the old number is not recoverable from the new payload. Semantic changes are precisely the ones the chain cannot express, and precisely the ones that hurt consumers most. If your breaks look like this, date-pinning buys you nothing and hides the problem behind machinery.
- **Nobody has committed to the test matrix.** The failure does not arrive on adoption day. It arrives at version 14, when a transformation that quietly does I/O ships green because version 3 has no conformance test, and one customer's integration has been receiving malformed payloads for a month. Most teams do not sustain this. Assume yours is most teams until it has held the discipline for a year.
- **You have no removal policy.** Without a published support window you have not chosen date-pinning, you have chosen "support everything forever" and given it a nicer name.

### Date-*named* is not date-*pinned* — and it is the cheaper half

Worth separating, because the two get conflated whenever someone points at a dated version string:

- **Anthropic** requires the header on every request: *"you must send an `anthropic-version` request header. For example, `anthropic-version: 2023-06-01`"* ([Anthropic, Versions](https://platform.claude.com/docs/en/api/versioning)). No account-level pin appears anywhere in that page, and its version history lists exactly two entries — `2023-01-01` and `2023-06-01` — with *"Previous versions are considered deprecated and may be unavailable for new users."* Within a version they preserve existing input and output parameters and allow only additive drift — new optional inputs, new output values, new variants of enum-like output values, changed conditions for specific error types. That is the tolerant-reader contract above, with a date on it. No chain, no registry, no pin.
- **GitHub** is date-named and header-selected with a *frozen* default: *"Requests without the `X-GitHub-Api-Version` header will default to use the `2022-11-28` version"* ([GitHub, API Versions](https://docs.github.com/en/rest/about-the-rest-api/api-versions)). Header-less callers are pinned to a fixed point in the past, not carried forward.
- **Stripe** is the full model: account pin, header override, transformation chain, plus named major releases (`Acacia`, `Basil`) where *"each monthly release includes only backward-compatible changes, and uses the same name as the last major release"* ([Stripe, Versioning](https://docs.stripe.com/api/versioning)).

**The default for a missing version header must be a fixed version, never "latest."** GitHub freezes it; Anthropic refuses to have one. Neither tracks latest, and that is not an accident: defaulting to latest converts every future release into a silent breaking change for every caller that omitted the header, which is the exact failure the versioning scheme exists to prevent. If you cannot decide, require the header and reject requests without it — a `400` today beats a mystery outage on your next release.

Dated strings are cheap. The pin and the chain are the expensive part, and you can adopt the first without the second — that is the option most teams should actually take.

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

**Option D: version-change chain** *(date-pinned schemes only)*
The registry described in § Date-pinned. Like C, the handler only knows the latest shape — unlike C, the mapping is in-process, decomposed one module per breaking change, and **chained**: rendering v1 from v6 replays five modules in order rather than running one v1↔v6 rule. That is what makes the fifteenth version cost the same as the second, and it is why A and B collapse at four versions while this does not. A → D is a rewrite, not a refactor; choose it before you have consumers, or not at all.

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

## Non-HTTP surfaces — deliberately not covered here

GraphQL and gRPC both have well-documented, tool-enforced evolution rules of their own (`@deprecated` plus field-level usage tracking; additive tag numbers plus `reserved`), and every schema-registry or linter in either ecosystem already checks them better than prose here could. Restating them would produce a fourth copy that drifts.

What **does** carry over from this file, and is the part teams get wrong on those surfaces too: you still cannot remove a field until usage is measurably zero, and "nobody should be using it" is not a measurement. The instrument is different (field-level usage tracking rather than a per-version traffic dashboard); the discipline in § Deprecation timeline is the same one.

Contract tests are the mechanical form of that discipline on any transport — a version bump with no consumer contract change is a signal, not a success. They are owned by the testing pack.

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

### 7. Absent version header defaults to "latest"

The version-resolution site (header parse → fallback) resolves a missing/unparseable version to the newest version rather than a fixed one → `pin-default-version`. Cite the fallback expression. Every future release then silently changes the shape delivered to every header-less caller, which is the failure the scheme was bought to prevent. Fixed default (GitHub's `2022-11-28` model) or hard reject (Anthropic's required-header model) — both are defensible, "latest" is not. Fires on date-pinned, header and media-type schemes alike; not on URL-path, where the version cannot be absent.

### 8. Version conditional outside the adapter layer

`if (version < …)` / `apiVersion >= …` / a version constant read inside a service, domain, repository or job — anywhere below the HTTP adapter → `move-version-branch-to-adapter`. Cite the branch and the layer it sits in. § Request / response DTOs already states the rule (the service layer knows nothing about versions); this is the detector for it, and it is the specific way a transformation chain rots — Stripe names version-checking logic spread through a codebase as the debt the version-change module exists to contain ([Stripe blog](https://stripe.com/blog/api-versioning)). A branch that cannot move because it needs state the payload does not carry is a **semantic** break wearing a structural costume: it does not belong in the chain, and § When it is the wrong choice is the section to re-read.

**Closure verbs:** `ship-new-version`, `add-deprecation-headers`, `add-sunset-and-tracking`, `unify-version-scheme`, `fix-brownout-status`, `pin-default-version`, `move-version-branch-to-adapter`.

## Forbidden

- Breaking changes within a version.
- Silent semantic changes (field name same, meaning different).
- Removing a version without a deprecation period.
- Per-endpoint versions (mixing `/v1/users` + `/v2/orders`) **as a steady state** — a consumer must then track a version per resource instead of one per API, and your OpenAPI document has no single version to name. (Kubernetes ships per-resource-group versions and it works, so this is a cost, not a law: it works there because the group→version map is published, machine-readable, and discoverable. If you cannot say the same, don't.) Acceptable only inside a documented, time-boxed migration window.
- Defaulting an absent version header to "latest" — see Detector 7.
- Date-pinning consumers with no per-version conformance suite and no published support window. That is not a versioning scheme, it is an open-ended promise to run every shape you have ever shipped, and it will be inherited by someone who did not make it.
- Versioning before you have consumers (YAGNI — start simple).
- Forever-v1 with "we'll never break" promise (you will).
