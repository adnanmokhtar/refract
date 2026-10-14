# Fastify (Node) reference

> **Framework**: Fastify 5.x on Node 20+ (5.12.7 is `latest` on npm, published 2026-10-13; 6.0.0 is in alpha) • TypeScript optional
> **Official docs**: https://fastify.dev/docs/latest/ • v4 → v5: https://fastify.dev/docs/latest/Guides/Migration-Guide-V5/
> **Version-specific gotchas**: v5 needs full JSON Schema (with `type`) for `body`, `querystring`, `params` and response schemas; `reply.redirect(url, code)` swapped its arguments; `req.params` has no prototype. Under NestJS's `FastifyAdapter` every row below still applies — the Express vs Fastify adapter table is in `nestjs.md`.
> **Substitution markers**: Replace `<plugin>` / `<route>` with the project's actual names from `_extracted-idioms.md`.

Every row says how it was established: **run** = executed on Fastify 5.12.7 with `@fastify/ajv-compiler` 4.0.7, ajv 8.20.0, fast-json-stringify 7.1.0 and fastify-plugin 5.1.0 on 2026-10-14; **guide** = the v5 migration guide at the v5.12.7 tag, read 2026-10-14. Read the installed version from the lockfile before relying on a row.

## Request validation — ajv defaults

`@fastify/ajv-compiler` 4.0.7 `lib/default-ajv-options.js`: `coerceTypes: 'array'`, `useDefaults: true`, `removeAdditional: true`, `allErrors: false`.

| Input (body schema with `additionalProperties: false`) | Default (run) | With `ajv: { customOptions: { removeAdditional: false, coerceTypes: false, useDefaults: false } }` (run) |
|---|---|---|
| unknown key `isAdmin: true` | **200**, key silently removed — not rejected | 400 `body must NOT have additional properties` |
| `"42"` into `integer` | 200, `42` | 400 |
| `null` into `boolean` / `integer` | 200, **`false` / `0`** | 400 |
| `"solo"` into `string[]` | 200, `["solo"]` | — |
| missing field with `default: 5` | 200, `5` written into `req.body` (the request is mutated) | absent |
| `1.5` into `integer` | 400 | 400 |
| `date-time` without an offset | 400 (v5 `ajv-formats` enforce a zone; `iso-date-time` accepts none — guide) | 400 |

- Turning `coerceTypes` off is global: `?page=2` against `{ type: 'integer' }` then answers **400** (run), because query strings are strings. Keep coercion for `querystring`/`params` and reject on bodies: `removeAdditional: false` alone (run: unknown body key → 400, `?page=2` still → `2`), and type booleans in queries as `enum: ['true','false']` or a string with a `preValidation` mapper.
- Without `additionalProperties: false`, the unknown key reaches the handler (research run). Over-posting into a model is security's (`injection-scan`); the silent drop is validation-boundary-scan §6.
- Coercion and drops answer 200 with a different value: validation-boundary-scan §4 (coercion table, V341) and §6 (unknown keys, V343).

## Response schema — a serializer, not a validator

`schema.response[200]` compiles fast-json-stringify. It reshapes, it does not reject (run):

| Handler returns | Client receives |
|---|---|
| `{ id: 1, total: 12.7 }` under `total: { type: 'integer' }` | `total: 12` — truncated, **200** |
| `flag: "no"` under `boolean` | `true` |
| `name: null` under non-nullable `string` | `""` |
| fields not in the schema (`passwordHash`, a newly added column) | **dropped** |
| a required field missing | 500 `"name" is required!` |
| `"7abc"` under `integer` | 500 |
| a `BigInt` with no response schema | 500 `Do not know how to serialize a BigInt` |

Generate the response schema from the type the handler returns, mark nullable columns `type: ['string', 'null']`, and send money as a string decimal. A dropped field that was meant to ship is drift; a dropped internal field is the projection working (wire-format-scan §3, V338). Proof: capture the pre-serialization object in an `onSend` hook in tests and compare it with `inject()`'s JSON.

## Reply lifecycle

| Code | Result (run) |
|---|---|
| `async (req, reply) => { reply.send(a); return b }` | `a` is sent; `FST_ERR_REP_ALREADY_SENT` logged |
| `async` handler that calls `reply.send` inside `setTimeout` without `return reply` | **200 empty** sent at once, then the late send logs the error (research run) |
| `async` handler that returns `undefined` | 200 empty body, nothing logged |
| `throw new Error('boom')` | 500 with `message: "boom"` — the raw message reaches the client (security's `data-exposure-scan`) |
| an error with `statusCode = 409` | 409 |

Rule: in an `async` handler either `return value` or `return reply.send(value)`; never both, never a send from a callback without `return reply`. `reply.hijack()` is for streams that write `reply.raw` themselves. Owner: edge-error-scan §5 (V345).

## Encapsulation and hooks

| Setup | Result (run) |
|---|---|
| auth `onRequest` hook added inside a registered plugin (no `fastify-plugin`) | protects that plugin's routes; a **sibling** plugin's route answers **200** without credentials |
| the same hook registered through `fp(...)` inside a scope | applies to that scope and its children; a sibling scope is still unprotected |
| `setErrorHandler` inside a plugin | handles that plugin's errors only (418 inside, default 500 in the sibling) |
| `onRequest` reading `request.body` | `undefined` — the body is parsed later; read it in `preValidation` / `preHandler` |

Put cross-cutting hooks (auth, tenant, error envelope) on the root instance or in an `fp()`-wrapped plugin registered at the root; a hook's auth meaning is security's, its reach is http-contract-scan §11.

## v4 → v5 changes that alter behaviour (guide unless marked run)

- Full JSON Schema required for `body`, `querystring`, `params` and responses (`jsonShortHand` removed).
- `req.params` has no prototype: `req.params.hasOwnProperty` is `undefined` (run) — use `Object.hasOwn(req.params, k)`.
- `DELETE` with `Content-Type: application/json` and an empty body → 400 `FST_ERR_CTP_EMPTY_JSON_BODY` (run); without the header → 200.
- `reply.redirect(url, code)` (was `code, url`); `reply.sent` is read-only; `request.connection` removed; `reply.getResponseTime()` → `reply.elapsedTime`.
- `useSemicolonDelimiter` defaults to `false` (`?a=1;b=2` is one value).
- A plugin is either `async (instance, opts)` or `(instance, opts, done)`, never both.
- `req.hostname` no longer includes the port (`req.host` does).
- `time` / `date-time` formats require an offset.
- Node 20+ only.

Server defaults printed from `initialConfig` (run): `bodyLimit` 1 MiB, `onProtoPoisoning: 'error'`, `caseSensitive: true`, `ignoreTrailingSlash: false`, `exposeHeadRoutes: true`, `requestTimeout: 0`, `connectionTimeout: 0`. Timeouts and body limits as capacity are performance's (`request-path-scan` §13). Wrong method → 404, no `Allow` (research run).

## Which detector owns what

| Concern | Owner |
|---|---|
| ajv coercion, strip, defaults | validation-boundary-scan §4, §6 |
| response schema reshaping | wire-format-scan §3; spec drift http-contract-scan §10 |
| double send, empty 200 | edge-error-scan §5 |
| Express-API calls on the Fastify adapter (Nest) | edge-error-scan §3 |
| hook order, encapsulation, v5 route and parser deltas | http-contract-scan §11 (V346, V357) |

Sources: the run rows above, plus the backend research runs on Fastify 5.12.7 (2026-10-14, research-backend § 1.2 BV-06/07/15, § 1.4 BN-06/07/08); the migration guide `docs/Guides/Migration-Guide-V5.md` at tag v5.12.7, fetched 2026-10-14. Paraphrased; no text reproduced beyond identifiers.
