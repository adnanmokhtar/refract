# tRPC (Node) reference

> **Framework**: tRPC 11.x (`@trpc/server` 11.19.0 is `latest` on npm, published 2026-09-16; peer `typescript >= 5.7.2`) on any Node adapter (standalone, Express, Fastify, Next.js)
> **Official docs**: https://trpc.io/docs • validators: https://trpc.io/docs/server/validators
> **Version-specific gotchas**: an output is validated only when the procedure declares `.output(...)`; a batch whose calls end differently answers **207**; the error code, not the thrown class, decides the HTTP status.
> **Substitution markers**: Replace `<router>` / `<procedure>` with the project's actual names from `_extracted-idioms.md`.

Every row says how it was established: **run** = executed on `@trpc/server` 11.19.0 with zod 4.6.7 (`NODE_ENV=production`) in the backend research labs, 2026-10-14; **read** = `@trpc/server` 11.19.0's published source (`getHTTPStatusCode.ts` and the input parser), read 2026-10-14. Read the installed version from the lockfile before relying on a row.

## Output — nothing checks it unless you ask

| Procedure | Result (run) |
|---|---|
| `.query(() => db.user.findFirst())` with no `.output()`, the row carries `secret` | 200, **`secret` returned** |
| `.output(UserOut)` and the resolver returns a value that does not match | **500** `Output validation failed` (`INTERNAL_SERVER_ERROR`) |

Declare `.output(Schema)` on every procedure that returns rows; the schema is the projection. A procedure without one ships every column it returns (the field that leaks is security's `data-exposure-scan`; the missing projection and the shape drift are wire-format-scan §3, V338). Numbers past 2^53 and `Decimal` need a transformer (`superjson`) that the client link uses too — a mismatch between client and server transformer was not run here; test the round trip (wire-format-scan §2).

## Input

`.input(schema)` runs the validator as written, so its defaults apply unchanged (run, zod 4.6.7): `z.object` strips unknown keys silently, `z.strictObject` rejects them; `z.coerce.boolean('false')` is `true`, `z.coerce.number('')` is `0`; `z.stringbool()` parses `"false"` correctly. A query input arrives URL-encoded in `?input=`; keep coercion off and type the field. Owner: validation-boundary-scan §4 and §6 (V341, V343).

## Errors and status

| Thrown | HTTP status and body (run / read) |
|---|---|
| `throw new Error('db down at 10.0.0.5')` | 500, the **raw message** in `error.message` even in production (stack omitted) — the leak is security's |
| `throw new TRPCError({ code: 'NOT_FOUND' })` | 404; the map (read): `BAD_REQUEST` 400, `UNAUTHORIZED` 401, `FORBIDDEN` 403, `NOT_FOUND` 404, `METHOD_NOT_SUPPORTED` 405, `TIMEOUT` 408, `CONFLICT` 409, `PRECONDITION_FAILED` 412, `PAYLOAD_TOO_LARGE` 413, `UNSUPPORTED_MEDIA_TYPE` 415, `UNPROCESSABLE_CONTENT` 422, `PRECONDITION_REQUIRED` 428, `TOO_MANY_REQUESTS` 429, `CLIENT_CLOSED_REQUEST` 499, `INTERNAL_SERVER_ERROR` 500, `NOT_IMPLEMENTED` 501, `BAD_GATEWAY` 502, `SERVICE_UNAVAILABLE` 503, `GATEWAY_TIMEOUT` 504; an unknown code → 500 |
| an input validation failure | 400 `BAD_REQUEST` (read) |
| a batch (`?batch=1`) whose calls end with different statuses (`ok` + `fail`, or `fail` + `conflict`) | **207** with per-call results (run); the read source returns 207 whenever the set of per-call statuses has more than one member, and the shared status otherwise |
| GET to a mutation | 405 `METHOD_NOT_SUPPORTED` (run) |
| POST with `text/plain` | 415 (run) |

Map domain and ORM errors to a `TRPCError` code in one place — a middleware or the procedure base — and shape the body with `initTRPC.create({ errorFormatter })`. A monitor or retry policy keyed on HTTP status must read per-call results inside a 207. Owners: edge-error-scan §7 (RPC error mapping, V345), edge-error-scan §2 (domain and ORM errors, V330), http-contract-scan §8 (batch partial failure, V336).

## Which detector owns what

| Concern | Owner |
|---|---|
| no `.output()`, output reshaped | wire-format-scan §3 |
| big numbers and decimals through the transformer | wire-format-scan §1–§2 |
| input coercion and unknown keys | validation-boundary-scan §4, §6 |
| plain `Error` → 500, code mapping, `errorFormatter` | edge-error-scan §2, §7 |
| 207 batches | http-contract-scan §8 |

Sources: the backend research run on `@trpc/server` 11.19.0 (2026-10-14, research-backend § 1.3 BE-07, § 1.4 BN-12, § 1.2 BV-07/15); the `@trpc/server` 11.19.0 npm tarball, fetched and read 2026-10-14. Paraphrased; no text reproduced beyond identifiers.
