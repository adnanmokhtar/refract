---
description: Audit the public / external API surface — versioning, deprecation safety, key scope/hashing/rotation, pagination, error envelope, overexposure, idempotency, per-key rate limit, OpenAPI coverage — against the real routes + spec, never an assumed contract.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /audit-api-contract

Enumerate the actual public endpoints and verify each one is a safe, versioned, documented contract: not leaking the DB model, versioned with a deprecation path, key-scoped + hashed, paginated, uniformly enveloped, idempotent on writes, rate-limited per key, and present in the OpenAPI spec — from the REAL routes and the REAL spec, not a guess.

## Premise

Real signals only. Cite the actual route registration at `<path:line>`, the response mapper (or the raw entity serialization) at `<path:line>`, the version marker, the key issuance/verify/revoke code, the pagination cap, the error-envelope helper, the idempotency store, the rate-limit decorator, and the OpenAPI spec entry — never narrate a contract you didn't read. Read before auditing: locate every public route in source and resolve which controller/handler serves it BEFORE judging anything.

## Mechanical halt

Cite-or-halt: every run MUST print, per audited endpoint, (1) the route + handler at `<path:line>`, (2) how the response body is built — DTO mapper at `<path:line>` or "RAW ENTITY — overexposure", (3) the version marker (or "UNVERSIONED — implicit-latest"), (4) the pagination shape on lists (cursor + cap at `<path:line>` or "UNBOUNDED — DoS"), (5) the error-envelope source (shared helper at `<path:line>` or "DRIFT — inconsistent shapes"), (6) idempotency on unsafe POSTs (`<path:line>` or "MISSING — double-create"), (7) the per-key rate-limit (`<path:line>` or "NONE"), and (8) the OpenAPI spec entry (or "UNDOCUMENTED — contract undefined"). If any of these cannot be produced from real source/spec, HALT and say which — never an assumed contract, never an assumed mapper.

This audit READS source + the spec + key-store schema. It does NOT call the live API with a real key, does NOT issue/revoke keys, and does NOT mutate the spec. Behavioural probing (real requests, real 429s) is out of scope here.

## What it does

1. **Enumerate the public surface** — list every externally reachable route (controller/router registration) at `<path:line>`. Separate truly-public (third-party) from internal endpoints; only the public set is in scope.
2. **Response build** — for each, is the body built by a DTO mapper (cite `<path:line>`) or by serializing the ORM entity (`res.json(entity)` / `return entity`)? Flag raw serialization as OVEREXPOSURE; list the internal fields/PII it leaks.
3. **Versioning + deprecation** — is the endpoint under an explicit version? Is any field change on a live version a breaking change shipped without a new version + `Deprecation`/`Sunset` headers? Cite the version marker + header emission, or flag.
4. **API-key handling** — read the key store + issuance/verify/revoke/rotate paths: are keys scoped, hashed at rest (only a prefix clear), revocable, and rotatable? Flag plaintext / unscoped / non-revocable / non-rotatable.
5. **Pagination** — every list endpoint: cursor-paginated with a server max page size? Cite the cap. Flag any unbounded `findAll()` → `res.json`.
6. **Error envelope** — do all endpoints share one envelope `{ error: { code, message, details?, requestId } }` + one status mapping? Cite the helper/global filter. Flag drift (mixed shapes, 200-with-error-body).
7. **Overexposure / PII** — beyond raw serialization, is any sensitive/internal field emitted without a scope check? Cite the field + the missing gate.
8. **Idempotency** — unsafe POSTs accept + honour `Idempotency-Key` with a `(key,bodyHash)->response` store? Cite it, or flag double-create risk.
9. **Per-key rate limit** — each endpoint enforces a per-key quota (`<rules-path>/rate-limit-discipline.md`)? Cite the decorator/middleware, or flag.
10. **OpenAPI coverage + drift** — is every public route in the committed spec, and every spec path a real route? Cite the spec entry; flag undocumented routes and orphaned spec paths.
11. **Report** — the endpoint contract matrix + ranked findings + the top fix.

## Flow

```text
enumerate public routes (<path:line>)
  -> response build: DTO mapper | RAW ENTITY                    [BLOCKER if raw — overexposure]
  -> version marker + deprecation/Sunset on live changes        [BLOCKER if breaking w/o version]
  -> key store: scoped + hashed + revocable + rotatable         [BLOCKER if plaintext/unscoped/non-revocable]
  -> lists: cursor + max page cap | UNBOUNDED                   [BLOCKER if unbounded]
  -> errors: one envelope + status map | DRIFT                  [BLOCKER if drift]
  -> sensitive fields gated by scope | exposed                  [BLOCKER if PII w/o authz]
  -> unsafe POST: Idempotency-Key honoured | missing            [BLOCKER if missing]
  -> per-key rate limit present | none                          [BLOCKER if none]
  -> OpenAPI: route in spec + spec path real | drift            [BLOCKER if undocumented/drift]
  -> request body validated at boundary | raw                   [REQUEST if unvalidated]
  -> report: contract matrix + ranked findings + top fix
```

## Output

```
/audit-api-contract — <surface / version>

Public surface: <N> endpoints  (versioned: <v1.. >)   |   OpenAPI: openapi.yaml

Endpoint contract matrix:
  ENDPOINT                       VER   RESPONSE   PAGE      ERR-ENV  KEY-SCOPE  IDEMP  RATELIM  SPEC
  GET  /v1/orders                v1    DTO        cursor    shared   read       n/a    per-key  yes
  GET  /v1/orders/:id            v1    DTO        n/a       shared   read       n/a    per-key  yes
  POST /v1/charges               v1    DTO        n/a       shared   write      MISSING per-key  yes      <- BLOCKER
  GET  /v1/customers             v1    RAW(!)     UNBOUND(!) {msg}(!) none(!)   n/a    none(!)  NO(!)    <- BLOCKER x5
  GET  /internal/metrics         -     -          -         -        -          -      -        n/a (internal — out of scope)

Key store (api_keys @ <path:line>):
  hashed-at-rest: argon2  prefix-clear: yes   scopes: yes   revocable: yes   rotatable: yes
  [or: PLAINTEXT token column — BLOCKER]

Findings (ranked):
  BLOCKER  /v1/customers serializes the User entity      @ customers.controller.ts:22  -> leaks passwordHash, ssn, internalCostMinor
  BLOCKER  /v1/customers returns the whole table         @ customers.controller.ts:22  -> add cursor + MAX_PAGE
  BLOCKER  /v1/charges has no Idempotency-Key handling   @ charges.controller.ts:31    -> retry double-creates
  BLOCKER  /v1/customers not in openapi.yaml             -> contract undefined
  REQUEST  POST /v1/orders body not schema-validated     @ orders.controller.ts:40

Verdict: OK | NEEDS-DTO | NEEDS-PAGINATION | NEEDS-VERSION | DRIFT | BLOCKER(overexposure)

Top recommendation:
  - <e.g. route /v1/customers through toPublicCustomerV1 + cursor pagination; add it to the spec>
```

## Rules

- READ-ONLY audit. Reads source, the OpenAPI spec, and the key-store schema. Never calls the live API with a real key, never issues/revokes keys, never edits the spec.
- Cite-or-halt: real route, real mapper (or raw entity), real version marker, real pagination cap, real envelope helper, real key store, real spec entry — or halt naming what's missing.
- A public response built by serializing the DB/ORM entity is OVEREXPOSURE, reported first with the leaked fields named.
- A breaking change on a live version with no new version + `Sunset` header is a BLOCKER, not a style note.
- Always print the endpoint contract matrix; an unbounded list, an envelope drift, a plaintext key, a missing idempotency key, and an undocumented route are each BLOCKERs.
- Distinguish public (third-party) endpoints from internal ones — internal endpoints are out of scope (they're the backend track's internal-polish concern), but say which is which so nothing is mis-classified.

## Cross-references

- `<rules-path>/public-api-discipline.md` — the hard-rule list this command enforces (DTO mapping, versioning, deprecation, scoped/hashed keys, pagination, envelope, idempotency, validation, spec-as-truth).
- `<patterns-path>/public-api-contract.md` — the DTO mapper, versioning/sunset headers, key issuance, cursor pagination, envelope, idempotency, and OpenAPI-drift-check code shapes.
- `<rules-path>/rate-limit-discipline.md` — the per-key quota + `429` contract every endpoint must carry.
- `<agents-path>/public-api-reviewer.md` — review gate that consumes these findings on a PR.
