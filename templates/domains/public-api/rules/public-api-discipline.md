---
name: public-api-discipline
description: Public / external API contract discipline
kind: rule
---

# Public / external API contract discipline

## Hard rule

Every endpoint exposed to a third party is a CONTRACT, not an implementation detail. A response body MUST be built by an explicit response DTO mapper — serializing the persistence/DB model directly is FORBIDDEN (it overexposes internal ids, foreign keys, soft-delete flags, cost columns, and PII the instant a column is added). The surface MUST be VERSIONED (URL or media-type), and a breaking change MUST ship only behind a new version with a published deprecation window + `Deprecation`/`Sunset` headers on the old one — silently changing a field's type, removing a field, or tightening validation on a live version BREAKS every consumer at once. EVERY list endpoint MUST return a bounded, cursor-paginated page — an unbounded `findAll()` list is a DoS and breaks at scale. EVERY endpoint MUST share ONE error envelope + consistent status codes. Unsafe POSTs MUST accept an idempotency key so a client retry never double-creates. Every request body at the public boundary MUST be schema-validated before it reaches domain code. Every key/endpoint MUST be rate-limited per key (see `<rules-path>/rate-limit-discipline.md`). The OpenAPI spec is the SOURCE OF TRUTH — an undocumented endpoint or spec drift means the contract is undefined.

A public-API bug is not a 500 a user retries — it is a silent, simultaneous break of every integration built on you, or a leak of internal data you can never un-publish. The blast radius is everyone who ever wrote code against you.

> Boundary: this is the EXTERNAL contract discipline — versioning, third-party keys, deprecation safety, overexposure, the published spec. It COMPLEMENTS, and does not replace, the backend track's internal API-consistency polish (envelope/log/metric uniformity across your own services). Internal polish makes your endpoints tidy; this rule makes them safe to hand to strangers and never silently break.

## Must

- **Map to an explicit response DTO**: every response body is constructed by a dedicated mapper (`toPublicOrder(order)`) that names each field it emits. The persistence model / ORM entity NEVER reaches the serializer. Adding a DB column never silently adds it to the public payload.
- **Version the surface**: the public API is versioned (URL `/v1/...` or a media-type / header). The version is explicit, never implicit-latest. Consumers pin a version and that version's contract is frozen.
- **Breaking changes go behind a new version + deprecation window**: removing/renaming a field, changing a field's type, making an optional field required, tightening validation, or changing status-code semantics is a BREAKING change. It ships only in a new version. The old version stays live through a published window (e.g. ≥90 days) and emits `Deprecation: true` + `Sunset: <date>` + a `Link` to migration docs.
- **Additive changes only on a live version**: on a frozen version you may ONLY add optional fields / new endpoints. Consumers must tolerate unknown fields; you must never depend on them sending unknown ones.
- **Cursor-paginate every list**: every collection endpoint returns `{ data: [...], page: { nextCursor, hasMore } }` with a server-enforced max page size (default + hard cap). Offset pagination on a growing table is discouraged; an UNBOUNDED list (no limit) is FORBIDDEN.
- **One uniform error envelope**: every error response across every endpoint and version has the SAME shape — `{ error: { code, message, details?, requestId } }` — with a stable, documented machine-readable `code` and a consistent HTTP status mapping (400 validation, 401 unauth, 403 forbidden, 404 not-found, 409 conflict, 422 unprocessable, 429 throttled). One endpoint returning `{ msg }` and another `{ error }` is a contract break.
- **API keys: scoped, hashed-at-rest, rotatable, revocable**: keys are issued with explicit scopes (least privilege), stored only as a hash (the plaintext is shown ONCE at issuance), support overlapping rotation (issue new → grace → revoke old), and can be revoked instantly. A key prefix is stored in clear for identification; the secret never is.
- **Idempotency keys on unsafe POSTs**: any non-idempotent create/charge accepts an `Idempotency-Key` header; the server persists `(key, requestHash) -> response` and replays the stored response on retry. A retried create NEVER double-creates.
- **Validate every request body at the boundary**: every public request body/query/params is validated against a schema (reject unknown fields or strip them deliberately) BEFORE domain code runs. No raw `req.body` reaches a service.
- **Per-key rate limiting**: every key carries a per-key quota enforced against a shared atomic store, returning the `429` + `RateLimit-*` contract (see `<rules-path>/rate-limit-discipline.md`). Unauthenticated public endpoints are limited per-IP.
- **OpenAPI is the source of truth**: every public endpoint, field, error code, and auth scheme is in the committed OpenAPI/JSON-Schema spec. The spec is checked against the running surface in CI — an endpoint not in the spec, or a spec field not in a response, fails the build.
- **No PII/internal fields without authorization**: field-level sensitive data (email, phone, internal cost, owner id) is emitted only when the key's scope grants it; otherwise the field is omitted (not nulled — omitted, so its absence is unambiguous).

## Must not

- Serialize the DB/ORM model straight to the wire (`res.json(order)`, `return entity`) — the next migration leaks a new column to every consumer; an existing one already leaks ids/FKs/PII.
- Ship a breaking change on a live version (drop/rename a field, change a type, tighten validation, change a status code) without a new version + deprecation window + `Sunset` header.
- Return an unbounded list (`SELECT * FROM ... ` → `res.json(rows)`) with no page size cap — DoS + the endpoint dies as the table grows.
- Use different error shapes / inconsistent status codes across endpoints (`{msg}` here, `{error}` there, 200-with-error-body elsewhere) — consumers can't write one error handler.
- Store API keys in plaintext, issue keys with no scopes (god keys), or have no revoke / no rotation path — a single leaked key is then unbounded and permanent.
- Accept an unsafe POST with no idempotency key — a client timeout + retry double-charges / double-creates.
- Accept an unvalidated request body at the public boundary — type confusion, mass-assignment, and injection start here.
- Leave an endpoint out of the OpenAPI spec, or let the spec drift from the implementation — the contract is then undefined and consumers code against guesses.
- Expose PII / internal columns to a key whose scope doesn't grant them.
- Bump the whole API to v2 for an additive change (a new optional field), forcing consumers to migrate for nothing.

## Should

- Wrap the surface behind a project-internal `<PublicController>` / response-DTO mapper layer + an `errorEnvelope()` helper so versioning, DTO mapping, the envelope, pagination, and the spec are enforced in ONE place — feature code declares a resource + scopes, not raw `res.json`.
- Generate typed client SDKs from the OpenAPI spec so the published contract and the consumer code share one source.
- Treat the OpenAPI spec as a reviewed artifact: a contract diff (e.g. `oasdiff`) runs in CI and flags any breaking change against the previous spec, forcing an explicit version decision.
- Emit `Deprecation` / `Sunset` / `Link` headers on deprecated versions AND track per-key usage of deprecated endpoints so you know who still needs to migrate before sunset.
- Key idempotency records by `(apiKey, idempotencyKey)` and store the request hash so a reused key with a DIFFERENT body returns `422` rather than silently replaying the wrong response.
- Log structured `{ apiKeyId, version, route, status, errorCode, deprecated, latencyMs }` per public request; alert on spikes of a deprecated route near its sunset, on `4xx` validation storms (a consumer broke), and on any 5xx (you broke a consumer).
- Pin the read/streaming contract for large list endpoints to the reporting pack's keyset + async-export shape (see reporting) rather than inventing per-endpoint pagination.

## Review checklist (PRs touching public/external endpoints, API keys, the OpenAPI spec, response shapes)

- [ ] The response body is built by an explicit DTO mapper at `<path:line>` — the DB/ORM model is NOT serialized directly.
- [ ] No internal ids / FKs / soft-delete flags / cost columns / unauthorized PII appear in the payload; cite the mapper's field list.
- [ ] The endpoint is under a version (`/v1/...` or media-type); the version's contract is frozen, changes here are additive-only.
- [ ] Any breaking change is in a NEW version; the old version emits `Deprecation`/`Sunset`/`Link` and has a published window. Cite the diff.
- [ ] Every list endpoint is cursor-paginated with a server max page size; no unbounded `findAll()` → `res.json`.
- [ ] Errors use the ONE envelope `{ error: { code, message, details?, requestId } }` with the documented status mapping; cite the helper at `<path:line>`.
- [ ] API keys are scoped, hashed-at-rest (only a prefix in clear), rotatable, and revocable; cite the issuance + verify + revoke paths.
- [ ] Unsafe POSTs accept `Idempotency-Key`; the `(key,requestHash)->response` store + replay is at `<path:line>`.
- [ ] The request body is schema-validated at the boundary before domain code; cite the validator at `<path:line>`.
- [ ] The endpoint enforces a per-key rate limit (`<rules-path>/rate-limit-discipline.md`).
- [ ] The endpoint + every field + every error code is in the OpenAPI spec; CI checks spec ↔ surface for drift.

## Anti-patterns

- **Model-to-wire** — `res.json(await repo.findById(id))` ships `password_hash`, `internal_cost`, `owner_user_id`, `deleted_at` the moment those columns exist. Map to a named DTO; emit only declared fields.
- **Silent breaking change** — a "cleanup" renames `created` → `createdAt` on live `/v1`. Every consumer parsing `created` breaks at deploy, all at once, with no warning. New version + deprecation window only.
- **Implicit-latest version** — `/api/orders` with no version → every consumer is on "whatever's deployed" → you can never change anything safely. Pin a version; freeze its contract.
- **Unbounded list** — `GET /v1/orders` → `SELECT * FROM orders WHERE tenant=$1` → `res.json(rows)`; fine in dev (12 rows), a multi-MB response and a table scan in prod (4M rows). Cursor-paginate with a hard cap.
- **Envelope drift** — `/v1/orders` errors as `{ error: { code } }`, `/v1/users` as `{ message }`, `/v1/billing` returns `200` with `{ ok: false }`. Consumers can't write one handler. One envelope, one status mapping.
- **Plaintext god key** — keys stored as-is in a `api_keys.token` column, no scopes, no revoke. One DB read or one leaked key = full unbounded access forever. Hash at rest; scope; rotate; revoke.
- **Double-create on retry** — `POST /v1/charges` with no idempotency key; the client times out at 30s, retries, and the customer is charged twice. Accept `Idempotency-Key`; replay the stored response.
- **Mass-assignment via raw body** — `Object.assign(entity, req.body)` at the public boundary lets a caller set `role: 'admin'` / `tenantId: <other>`. Validate against a schema; never spread raw input.
- **Undocumented endpoint** — a partner integration depends on `/v1/internal-export` that's in no spec; a refactor deletes it; the partner's nightly job dies silently. If it's reachable, it's in the spec or it's gone.
- **PII to any key** — `customerEmail` emitted on every `/v1/orders` response regardless of scope → a read-only analytics key exfiltrates the customer list. Gate sensitive fields by scope; omit when not granted.
- **Version-bump for nothing** — adding an optional `discountCode` field forces a jump to `/v2` and a migration for every consumer. Additive optional fields stay on the current version.

## Enforcement

- `<commands-path>/audit-api-contract.md` (slash: `/audit-api-contract`) — enumerates public endpoints at `<path:line>` and audits versioning, breaking-change/deprecation handling, key scope/hashing/rotation, pagination + unbounded lists, error-envelope consistency, internal-field/PII overexposure, idempotency on POST, per-key rate limit, and OpenAPI coverage/drift — cite-or-halt, never an assumed contract.
- `<agents-path>/public-api-reviewer.md` — review gate hard-failing on model-to-wire overexposure, breaking changes without a version + deprecation window, plaintext/unscoped/non-revocable keys, unbounded lists, envelope drift, missing idempotency, missing per-key rate limit, OpenAPI drift, unauthorized PII, and unvalidated bodies.
- CI MUST run a contract diff (e.g. `oasdiff`) of the OpenAPI spec against the previous spec and FAIL on a breaking change not accompanied by a version bump.
- CI MUST assert spec ↔ surface coverage: every registered public route is in the spec, and every spec path resolves to a route (no drift, no undocumented endpoint).
- CI lint MUST reject a public response built by serializing an ORM entity directly (AST heuristic: `res.json(<repo-result>)` / `return <entity>` from a public controller) — public responses go through a DTO mapper.
- CI lint MUST reject a public list handler with no page-size cap / no cursor (heuristic; flag for review).
- TODO: `scripts/validate-public-contract.sh` to AST-walk public controllers and assert every handler maps to a DTO, every list paginates, every error uses the envelope helper, and every unsafe POST reads an idempotency key.

## Cross-references

- `<patterns-path>/public-api-contract.md` — the response-DTO mapper, versioning + deprecation/sunset headers, scoped/hashed/rotatable key issuance, cursor pagination, uniform error envelope, idempotency store, per-key limiter, and OpenAPI-as-source-of-truth code shapes.
- `<rules-path>/rate-limit-discipline.md` — per-key quotas + the `429` / `RateLimit-*` response contract every public endpoint enforces.
- `<rules-path>/auth.md` — API-key authentication + scope checks; how the key's identity + scopes reach the request context.
- `<rules-path>/webhook.md` — the outbound-events twin of this inbound contract: signed, versioned, retried delivery to the same third parties (deprecation/versioning discipline applies to event payloads too).
- reporting — for large list/export endpoints, reuse the keyset-pagination + async-job + streaming contract instead of inventing per-endpoint pagination.
- `<adr-path>/<NNN>-public-api-versioning.md` — ADR pinning the versioning scheme (URL vs media-type), the deprecation window length, and the breaking-change policy.
