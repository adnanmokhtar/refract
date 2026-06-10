---
name: public-api-contract
description: "Pattern: Public API contract (versioned, keyed, paginated, deprecation-safe)"
kind: ai-pattern
---

# Pattern: Public API contract (versioned, keyed, paginated, deprecation-safe)

> **Hard rule** — A public endpoint is a CONTRACT. The response is built by an explicit DTO mapper, NEVER the DB model serialized; the surface is VERSIONED and a breaking change ships only behind a new version + a published deprecation window with `Deprecation`/`Sunset` headers; API keys are SCOPED, HASHED at rest, ROTATABLE, and REVOCABLE; every list is CURSOR-paginated with a hard cap; every error uses ONE envelope; unsafe POSTs honour an `Idempotency-Key`; every key is rate-limited; and the committed OpenAPI spec is the SOURCE OF TRUTH, checked against the surface in CI.

**When to apply**
- Any endpoint a third party (external developer, partner, mobile SDK, public integration) calls — anything outside your own trust boundary.
- Any surface where consumers pin a version and you must evolve without breaking them.
- Issuing API keys / tokens to external callers, or returning collections that grow unbounded with usage.

**When NOT to apply**
- A purely internal service-to-service call inside one trust boundary, governed by the backend track's internal API-consistency polish — that's tidiness, not a frozen external contract. (This pattern still applies the moment an internal endpoint is exposed externally.)
- A BFF endpoint shaped exactly for one first-party client you ship in lockstep — version it the day a second consumer appears.
- A GraphQL/gRPC surface — the SHAPE here (DTO mapping, scoped keys, pagination, deprecation, spec-as-truth) still applies; the transport-specific mechanics (field deprecation directives, proto evolution rules) replace the REST specifics.

**Halt conditions / mandatory cites**
- Cite the response DTO mapper at `<path:line>`. A public response built from the ORM entity / `res.json(<repoResult>)` = halt (overexposure).
- Cite the version marker + the deprecation/`Sunset` header emission at `<path:line>`. A live-version field change with no new version = halt (breaking change).
- Cite key issuance (hash-at-rest + scopes) + verify + revoke + rotate at `<path:line>`. A plaintext / unscoped / non-revocable key = halt.
- Cite the cursor-pagination contract + page-size cap at `<path:line>`. An unbounded list = halt.
- Cite the single error-envelope helper at `<path:line>`. Mixed error shapes/status codes = halt.
- Cite the idempotency store + replay on unsafe POSTs, the boundary request-body validator, the per-key limiter, and the OpenAPI spec entry at `<path:line>` each.
- Grep ban: "the API is versioned/safe/documented" without file:line for the DTO mapper, the version + sunset header, the key hash, the pagination cap, the envelope, and the spec entry.

## Why

A public API is the one surface whose blast radius is everyone who ever integrated with you. Three failure modes recur and each one breaks consumers en masse, silently:

1. **Overexposure** — serializing the DB model leaks internal ids, foreign keys, cost columns, soft-delete flags, and PII; the next migration leaks a new column to every consumer with no code change. The fix is a mapper that names every field it emits.
2. **Silent breaking change** — renaming/retyping/removing a field on a live version breaks every consumer at deploy, simultaneously, with no warning. The fix is versioning + a deprecation window + `Sunset` headers, enforced by a spec diff in CI.
3. **Unbounded / inconsistent surface** — a list with no cap is a DoS that works in dev and dies at scale; mixed error envelopes mean nobody can write one handler; a leaked plaintext god key is unbounded and permanent. The fix is a cursor contract, one envelope, and scoped/hashed/revocable keys.

The pattern: build responses through a DTO mapper, version the surface, gate fields and quotas by the key's scope, paginate every list, return one envelope, dedupe unsafe POSTs by idempotency key, and treat the OpenAPI spec as the contract CI enforces.

> The TypeScript examples below use NestJS-style decorators + helpers for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the framework (Express / FastAPI / Spring / Rails / etc.), its DI, and your validation lib. The SHAPE — DTO mapper, version + sunset headers, hashed scoped key, cursor page, one envelope, idempotency store, spec-as-truth — is universal, not the helper names.

## Response DTO mapper — never serialize the DB model

```ts
// src/modules/public-api/v1/mappers/order.public-dto.ts

// The ONLY thing that reaches the wire for an order. Each field is named explicitly.
// Adding a column to the `orders` table can NEVER silently leak it here.
export interface PublicOrderV1 {
  id: string;                 // the PUBLIC id (opaque / external) — never the internal numeric PK
  status: 'pending' | 'paid' | 'shipped' | 'cancelled';
  total: { amountMinor: number; currency: string };   // Money, integer minor units + tag
  createdAt: string;          // ISO-8601 UTC
  // customerEmail is PII — emitted ONLY when the key's scope grants it (see below).
}

export function toPublicOrderV1(
  order: OrderEntity,
  scopes: ReadonlySet<Scope>,
): PublicOrderV1 & { customerEmail?: string } {
  const dto: PublicOrderV1 & { customerEmail?: string } = {
    id: order.publicId,                                  // NOT order.id (internal PK)
    status: order.status,
    total: { amountMinor: order.totalMinor, currency: order.currency },
    createdAt: order.createdAt.toISOString(),
  };
  // Field-level authorization: omit (don't null) when scope is absent — absence is unambiguous.
  if (scopes.has('orders:read:pii')) dto.customerEmail = order.customerEmail;
  return dto;
  // NEVER returned: internal id, tenantId, ownerUserId, internalCostMinor, deletedAt, raw FKs.
}
```

`res.json(entity)` is forbidden. The mapper is the allowlist; a new DB column ships nothing until someone adds it here on purpose.

## Versioning + deprecation / sunset headers

```ts
// src/modules/public-api/versioning.ts

// URL-versioned surface. v1 is FROZEN: additive (optional) changes only.
// A breaking change goes to a NEW controller (/v2), never edits /v1's contract.
@Controller({ path: 'orders', version: '1' })           // -> /v1/orders
export class OrdersV1Controller { /* ... */ }

@Controller({ path: 'orders', version: '2' })           // -> /v2/orders  (breaking change lives here)
export class OrdersV2Controller { /* ... */ }

// Deprecation middleware: once a version is past its deprecation date, every response on it
// carries the standard headers so consumers (and dashboards) see the sunset coming.
export function deprecationHeaders(version: ApiVersion) {
  return (req: Req, res: Res, next: Next) => {
    const dep = DEPRECATIONS[version];                   // { sunsetAt, migrationDoc } | undefined
    if (dep) {
      res.setHeader('Deprecation', 'true');                              // RFC 8594
      res.setHeader('Sunset', dep.sunsetAt.toUTCString());              // the hard cutoff date
      res.setHeader('Link', `<${dep.migrationDoc}>; rel="deprecation"`); // where to go
    }
    next();
  };
}
```

A breaking change is a NEW version. The old version stays live through the published window and announces its own sunset on every response. A contract diff (`oasdiff`) in CI fails the build if a breaking change lands without a version bump.

## API-key issuance — scoped, hashed at rest, rotatable, revocable

```ts
// src/modules/public-api/keys/api-key.service.ts

export class ApiKeyService {
  // Issue: the plaintext secret is returned ONCE and never stored. Only a hash + a clear prefix persist.
  async issue(tenantId: string, scopes: Scope[], label: string): Promise<{ plaintext: string; keyId: string }> {
    const secret = randomToken(32);                       // 256-bit secret
    const prefix = `pk_live_${secret.slice(0, 8)}`;       // stored CLEAR — for identification/logging only
    const hash = await argon2.hash(secret);               // stored at rest — the secret never is
    const row = await this.repo.create({
      tenantId, label, prefix, hash,
      scopes,                                              // least privilege — explicit, never a god key
      status: 'active',
      expiresAt: addDays(new Date(), 365),                 // bounded lifetime
    });
    return { plaintext: `${prefix}.${secret}`, keyId: row.id };   // shown ONCE
  }

  // Verify: constant-time hash compare; reject revoked/expired; load scopes onto the request context.
  async verify(presented: string): Promise<AuthedKey | null> {
    const [prefix] = presented.split('.');
    const row = await this.repo.findActiveByPrefix(prefix);        // prefix lookup, no plaintext scan
    if (!row || row.status !== 'active' || row.expiresAt < new Date()) return null;
    if (!(await argon2.verify(row.hash, presented.split('.')[1]))) return null;
    return { keyId: row.id, tenantId: row.tenantId, scopes: new Set(row.scopes) };
  }

  // Revoke: instant. A leaked key is killable now, not "after the next deploy".
  async revoke(keyId: string): Promise<void> {
    await this.repo.update(keyId, { status: 'revoked', revokedAt: new Date() });
  }

  // Rotate: overlapping — issue the new key, hand it over, then revoke the old after a grace window.
  // The consumer is never offline; both keys are valid during the overlap.
  async rotate(oldKeyId: string, graceDays = 14): Promise<{ plaintext: string; keyId: string }> {
    const old = await this.repo.findById(oldKeyId);
    const next = await this.issue(old.tenantId, old.scopes, `${old.label} (rotated)`);
    await this.repo.update(oldKeyId, { status: 'deprecated', revokeAt: addDays(new Date(), graceDays) });
    return next;
  }
}
```

The secret is never at rest in clear. Keys are least-privilege scoped, instantly revocable, and rotate without downtime. A scope check guards every endpoint and every sensitive field.

## Cursor pagination — bounded on every list

```ts
// src/modules/public-api/pagination.ts

const DEFAULT_PAGE = 50;
const MAX_PAGE = 200;        // hard server cap — a client asking for 1e9 gets 200, never the whole table.

export interface Page<T> { data: T[]; page: { nextCursor: string | null; hasMore: boolean }; }

// Opaque cursor encodes the keyset position — consumers treat it as a blob, not a number to increment.
export function decodeCursor(c?: string): { key: string; id: string } | null {
  return c ? JSON.parse(Buffer.from(c, 'base64url').toString()) : null;
}
export function encodeCursor(row: { createdAt: Date; publicId: string }): string {
  return Buffer.from(JSON.stringify({ key: row.createdAt.toISOString(), id: row.publicId })).toString('base64url');
}

// Keyset query — constant cost per page regardless of how deep the consumer pages.
async function listOrders(ctx: AuthedKey, q: ListQuery): Promise<Page<PublicOrderV1>> {
  const limit = Math.min(q.limit ?? DEFAULT_PAGE, MAX_PAGE);          // cap enforced server-side
  const after = decodeCursor(q.cursor);
  const rows = await this.replica.query(
    `SELECT * FROM orders
       WHERE tenant_id = $1
       ${after ? 'AND (created_at, public_id) > ($2, $3)' : ''}
       ORDER BY created_at, public_id
       LIMIT ${limit + 1}`,                                          // +1 to detect hasMore
    after ? [ctx.tenantId, after.key, after.id] : [ctx.tenantId],
  );
  const hasMore = rows.length > limit;
  const data = rows.slice(0, limit).map(r => toPublicOrderV1(r, ctx.scopes));   // map every row
  return { data, page: { nextCursor: hasMore ? encodeCursor(rows[limit - 1]) : null, hasMore } };
}
```

No endpoint ever returns the whole table. For very large exports, route to the reporting pack's async-job + streaming contract rather than paging a synchronous request.

## Uniform error envelope

```ts
// src/modules/public-api/errors/envelope.ts

// EVERY public error — across every endpoint and version — is this exact shape.
export interface ErrorEnvelope {
  error: {
    code: string;          // stable, documented, machine-readable: 'validation_failed', 'rate_limited', ...
    message: string;       // human-readable; safe to show; never a stack trace or internal detail
    details?: unknown;     // optional structured field errors
    requestId: string;     // for support correlation
  };
}

const STATUS: Record<string, number> = {
  validation_failed: 400, unauthorized: 401, forbidden: 403, not_found: 404,
  conflict: 409, unprocessable: 422, rate_limited: 429, internal: 500,
};

export function sendError(res: Res, code: keyof typeof STATUS, message: string, details?: unknown) {
  res.status(STATUS[code]).json(<ErrorEnvelope>{
    error: { code, message, details, requestId: res.locals.requestId },
  });
}

// One global exception filter routes EVERYTHING through sendError — no handler hand-rolls a shape,
// no endpoint returns 200-with-an-error-body, no raw exception leaks a stack trace to a consumer.
```

One envelope, one status mapping, stable codes. A consumer writes a single error handler and it works for the whole API.

## Idempotency keys on unsafe POSTs

```ts
// src/modules/public-api/idempotency/idempotency.middleware.ts

// Unsafe POST (create/charge): the client sends Idempotency-Key; a retry replays the stored response,
// never double-creates. The body hash guards against the same key reused with a DIFFERENT payload.
export async function idempotent(req: Req, res: Res, next: Next) {
  const key = req.header('Idempotency-Key');
  if (!key) return sendError(res, 'validation_failed', 'Idempotency-Key header required for this operation');

  const scopedKey = `${req.auth.keyId}:${key}`;            // scoped to the calling key
  const bodyHash = sha256(canonicalJson(req.body));
  const existing = await idemStore.get(scopedKey);

  if (existing) {
    if (existing.bodyHash !== bodyHash)                    // same key, different body -> reject, don't replay
      return sendError(res, 'unprocessable', 'Idempotency-Key reused with a different request body');
    return res.status(existing.status).json(existing.response);   // replay the exact prior response
  }

  // First time: reserve the key, run the handler, persist the response for replay.
  res.locals.onComplete = async (status: number, body: unknown) => {
    await idemStore.put(scopedKey, { bodyHash, status, response: body }, { ttlHours: 24 });
  };
  next();
}
```

A timed-out client that retries gets the original result, not a second charge.

## Boundary request-body validation + per-key rate limit

```ts
// src/modules/public-api/v1/orders.controller.ts

@Controller({ path: 'orders', version: '1' })
@UseGuards(ApiKeyGuard)                          // verify() above puts { keyId, tenantId, scopes } on req.auth
export class OrdersV1Controller {
  @Post()
  @RequireScope('orders:write')                  // field/endpoint authorization from the key's scopes
  @RateLimitPerKey('orders:write', { limit: 100, windowSec: 60 })   // per-key quota (see rate-limit pack)
  @UseInterceptors(IdempotencyInterceptor)
  async create(
    @Body(new ZodValidationPipe(CreateOrderSchema)) body: CreateOrderInput,   // schema-validated AT the boundary
    @Auth() ctx: AuthedKey,
  ): Promise<PublicOrderV1> {
    // body is parsed + validated + unknown fields stripped BEFORE this line. No raw req.body, no mass-assignment.
    const order = await this.orders.create(ctx.tenantId, body);
    return toPublicOrderV1(order, ctx.scopes);   // mapped, never the entity
  }
}
```

Nothing unvalidated reaches domain code; the per-key limit returns the `429` + `RateLimit-*` contract from `<rules-path>/rate-limit-discipline.md`.

## OpenAPI spec as the source of truth

```ts
// scripts/check-openapi-drift.ts  (runs in CI)

// 1. Every registered public route MUST exist in the committed spec.
// 2. Every spec path MUST resolve to a registered route.
// 3. A contract diff against the previous spec FAILS the build on any breaking change
//    not paired with a version bump.
const surface = collectPublicRoutes(app);                 // introspect the running router
const spec = loadOpenApi('openapi.yaml');                 // the committed contract

const undocumented = surface.filter(r => !spec.has(r));   // reachable but not in the spec -> contract undefined
const orphaned     = spec.paths.filter(p => !surface.has(p));   // in the spec but gone -> consumers code against a ghost
if (undocumented.length || orphaned.length) fail({ undocumented, orphaned });

const diff = await oasdiff(previousSpec, spec);
if (diff.breaking.length && !versionBumped(diff)) fail({ breakingWithoutVersionBump: diff.breaking });
```

The spec is the contract. CI refuses any endpoint that isn't in it, any spec entry that no longer exists, and any breaking change that didn't get a version.

## Common mistakes

### Model-to-wire
`res.json(await repo.findById(id))` ships internal ids / FKs / `internalCostMinor` / `deletedAt` / PII; the next migration adds a column and leaks it to every consumer. Map to a named DTO; emit only declared fields; gate PII by scope.

### Silent breaking change
Renaming `created` → `createdAt` (or retyping a field, or tightening validation) on live `/v1` breaks every consumer at once. New version + deprecation window + `Sunset` header only; a spec diff in CI catches it.

### Implicit-latest version
`/api/orders` with no version pins every consumer to "whatever deployed". You can never change anything safely. Version explicitly; freeze the contract per version.

### Plaintext / unscoped / non-revocable key
A `token` column in clear, no scopes, no revoke → one leak is unbounded and permanent. Hash at rest (prefix in clear only), scope least-privilege, support instant revoke + overlapping rotation.

### Unbounded list
`GET /v1/orders` → `res.json(rows)` with no cap; 12 rows in dev, a multi-MB table scan in prod. Cursor-paginate with a hard `MAX_PAGE`; route huge exports to the reporting async-job contract.

### Envelope drift
`{ error: { code } }` here, `{ message }` there, `200 { ok: false }` elsewhere → no consumer can write one handler. One envelope, one status mapping, stable codes, one global filter.

### Double-create on retry
`POST /v1/charges` with no idempotency key → client timeout + retry → double charge. Accept `Idempotency-Key`; persist `(key,bodyHash)->response`; replay.

### Mass-assignment via raw body
`Object.assign(entity, req.body)` at the boundary lets a caller set `role`/`tenantId`. Validate against a schema; strip unknown fields; never spread raw input.

### Undocumented endpoint / spec drift
A reachable endpoint that's in no spec, or a spec field absent from responses → the contract is undefined and a refactor silently kills a partner's job. CI checks spec ↔ surface both ways.

### PII to any key
Emitting `customerEmail` on every response regardless of scope lets a read-only key exfiltrate the customer list. Gate sensitive fields on the key's scope; omit when absent.

### Version-bump for nothing
Jumping to `/v2` for an additive optional field forces a pointless migration on every consumer. Additive optional changes stay on the current version.

## Cross-references

- `<rules-path>/public-api-discipline.md` — the hard-rule list this pattern implements (DTO mapping, versioning, deprecation window, scoped/hashed keys, pagination, envelope, idempotency, validation, spec-as-truth).
- `<rules-path>/rate-limit-discipline.md` — per-key quotas + the `429` / `RateLimit-*` response contract every public endpoint enforces.
- `<rules-path>/auth.md` — API-key authentication + scope checks; how `{ keyId, tenantId, scopes }` reaches the request context.
- `<rules-path>/webhook.md` — the outbound-events twin: signed, versioned, retried delivery; the same deprecation/versioning discipline applies to event payloads.
- reporting — for large list/export endpoints, reuse the keyset-pagination + async-job + streaming contract instead of paging a synchronous request.
- `<commands-path>/audit-api-contract.md` — enumerate + audit the live public surface against this pattern.
- `<agents-path>/public-api-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-public-api-versioning.md` — ADR pinning the versioning scheme, deprecation window, and breaking-change policy.
