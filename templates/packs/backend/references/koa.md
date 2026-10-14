# Koa (Node) reference

> **Framework**: Koa 3.x + `@koa/router` on Node 18+ (Koa 3.2.1 and `@koa/router` 15.7.0 are `latest` on npm, 2026-10-14) • TypeScript optional
> **Official docs**: https://koajs.com/ • v2 → v3: `docs/migration-v2-to-v3.md` in the koajs/koa repository
> **Version-specific gotchas**: v3 drops generator middleware, changes `ctx.throw(status, error, props)`, removes `redirect('back')` (use `ctx.back()`) and parses query strings with `URLSearchParams`. Koa ships no body parser and no validator.
> **Substitution markers**: Replace `<router>` / `<route>` with the project's actual names from `_extracted-idioms.md`.

Every row says how it was established: **run** = executed on Koa 3.2.1 + `@koa/router` 15.7.0 (Node 22/23, `NODE_ENV=production` for the research run) on 2026-10-14; **guide** = the v2 → v3 migration guide at tag v3.2.1, read 2026-10-14. Read the installed version from the lockfile before relying on a row.

## Middleware order — `await next()`

| Code | Result (run) |
|---|---|
| `app.use(async (ctx, next) => { next() })` — not awaited, not returned — before async routes | every async route answers **404**; an async throw in that chain crashed the process (unhandled rejection) |
| `return next()` or `await next()` | correct |

An error thrown in a middleware registered **before** the error middleware never passes through it and gets Koa's default text/plain answer, so the first middleware is the error boundary: `app.use(async (ctx, next) => { try { await next() } catch (err) { ctx.status = err.status ?? 500; ctx.body = toEnvelope(err) } })`. Owner: edge-error-scan §4 (V345).

## Body and status semantics

| Code | Result (run) |
|---|---|
| route sets `ctx.body` inside an un-awaited callback (`setTimeout`, `.then` not returned) | **404 `Not Found`** — the chain returned before the body was set |
| `ctx.status = 200` with no body | 200 `OK` (text) |
| `ctx.body = null` | **204** |
| `POST` JSON with no body-parser middleware | `ctx.request.body` is `undefined` (run 2026-10-14) — destructuring it throws → 500 |

Set `ctx.body` before the middleware's promise resolves; mount `@koa/bodyparser` (or the project's parser) before the router; treat `null` as "no content" only where 204 is the documented answer. Owner: edge-error-scan §5.

## Errors

| Code | Status, content type, body (run) |
|---|---|
| `throw new Error('db at 10.0.0.5')` | 500 `text/plain` `Internal Server Error` (message hidden) |
| an `Error` with `status = 422` | 422 `text/plain` `Unprocessable Entity` (message hidden: `expose` is false for a plain error) |
| `ctx.throw(422, 'bad qty')` | 422 `text/plain` `bad qty` (4xx messages are exposed) |
| `ctx.throw(409, 'dup')` | 409 `dup` |

Every default error body is **text/plain**, outside a JSON envelope; the error middleware above maps them (edge-error-scan §6, V345). What a message leaks is security's (`data-exposure-scan`).

## Query strings and routing

- `?filter[status]=paid&t=1&t=2` → `{ "filter[status]": "paid", "t": ["1", "2"] }` (run): bracket keys are **not** nested, so `ctx.query.filter.status` is `undefined` and a filter silently does nothing; one `?t=1` is a string, two are an array. Read flat keys, or parse with `qs` explicitly (http-contract-scan §11; validation-boundary-scan §9 for one-vs-many).
- v3 parses with `URLSearchParams` instead of Node's `querystring` (guide): re-test query parsing on upgrade.
- `router.allowedMethods()` mounted → wrong method answers **405 with `Allow: HEAD, GET`** (run); without it, 404 (http-contract-scan §3).
- `ctx.redirect('back')` on v3 → **302 with `Location: back`** even when a `Referer` is sent (run) — the special value is gone; use `ctx.back()` (guide).

## Validation

Koa has none: a zod / joi / yup middleware or `schema.parse(ctx.request.body)` in the handler. Their defaults — zod strips unknown keys, joi rejects them, yup keeps them; `z.coerce.boolean('false') === true`; a `ZodError` with no branch in the error middleware → 500 — are validation-boundary-scan §4 and §6 (V341, V343) and edge-error-scan §1.

## Which detector owns what

| Concern | Owner |
|---|---|
| un-awaited `next()`, process crash | edge-error-scan §4 |
| `ctx.body` unset or set late, 204 on `null` | edge-error-scan §5 |
| text/plain default errors | edge-error-scan §6 |
| bracket query keys, 405, v2 → v3 deltas | http-contract-scan §3, §11 (V346, V357) |
| validator coercion and unknown keys | validation-boundary-scan §4, §6 |

Sources: the backend research run on Koa 3.2.1 (2026-10-14, research-backend § 1.3 BE-06, § 1.4 BN-11); the runs above on 2026-10-14; `docs/migration-v2-to-v3.md` at tag v3.2.1, fetched 2026-10-14. Paraphrased; no text reproduced beyond identifiers.
