---
name: endpoint-test
description: Hit a running dev endpoint via curl and verify status + response shape + required headers (auth, tenant). Used AFTER any controller or DTO edit to prove the route works end-to-end.
---

# endpoint-test

## Premise

Find real bugs, not hand-waves. Every assertion cites the controller/DTO `<file:line>` and the actual response body produced. "Returned 200, looks fine" is not verification — phantom-success (200 with wrong shape) is the most common regression here. Field-by-field diff against the response DTO is mandatory; key-set comparison alone is insufficient. Cross-tenant 200 is a real bug, never "dev mode".

A run that skips any of the 5 mandatory cases (golden, invalid body, no auth, wrong tenant, idempotency) is incomplete.

Make an HTTP request to a local endpoint, then verify the status, headers, and response body match what the controller + DTO declared.

## When to use

- After editing a controller method (handler, decorators, route).
- After changing an input or response DTO.
- After a guard / interceptor / pipe change that affects the route.
- When suspecting a regression — quick sanity check before blaming the frontend.

## Prerequisites

- Dev server running on a known port (multi-app convention: master `:4000`, tenant `:4001`; `localhost:3000` is the generic single-app default). Confirm with `lsof -i :4000` or check the `start:dev` script log.
- Auth credentials in `.env.local` / `.env.dev` — NEVER use `*PROD*` credentials or `*.prod.env`.
- `curl` and `jq` available.

## Safety invariants

- ONLY target `localhost`, `127.0.0.1`, `::1`, or a tunnel the user explicitly named in this session (`*.ngrok.io`, `*.trycloudflare.com`, `*.loca.lt`).
- Refuse on any other host unless the user confirms in writing with the URL.
- Print every curl so the user can replay.

## Procedure

1. Read the controller — method, path, required headers, body shape, response shape.
2. Read the input DTO — derive the **minimal valid payload** (required fields + valid types).
3. Read the response DTO — note every field that should appear.
4. Resolve base URL from `CLAUDE.md` / `ai/stack.md`. If absent, ask the user; do not guess.
5. Source credentials from `.env.local`, `.env.dev`, or `.env.example`.
6. Execute 5 cases minimum:

   **1. Golden path** (valid auth, valid body)
   ```bash
   curl -sS -X POST "http://localhost:4000/api/v1/orders" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $DEV_JWT" \
     -H "X-Tenant-Id: dev-tenant" \
     -d '{"customerId":"u_1","items":[{"sku":"A1","qty":2}]}' \
     -w "\n---\nstatus=%{http_code}\ntime=%{time_total}s\n" | tee /tmp/r1.json
   ```
   Assert: status matches documented success (201/200/204), body field-by-field matches response DTO, correlation-id header (if declared), `time_total` within SLO.

   **2. Invalid body** — drop a required field; expect 400 with `errors[]` listing the offending field.
   **3. No auth** — omit `Authorization`; expect 401 (or 403 for public-but-rate-limited).
   **4. Wrong tenant** — header that doesn't own the resource; expect 404 (preferred) or 403. A 200 here is a cross-tenant leak (file as security finding).
   **5. Idempotency** (mutating endpoints with `Idempotency-Key`) — two POSTs with the same key; second returns same body, no duplicate side effects.

7. Field-by-field shape diff vs response DTO:
   ```bash
   jq -r 'keys_unsorted|join(",")' /tmp/r1.json
   ```
   Compare the key set against the DTO file.

## Optional checks

- Rate limit: loop 60 fast requests; expect 429 + `Retry-After`.
- Pagination: `?limit=10&cursor=...` returns 10 items + a next cursor.
- Filters / sorts: each param actually changes the result.
- Soft-delete: deleted record returns 404, but `deleted_at` set in the DB.

## Output

```
## /api/v1/orders [POST]   base=http://localhost:4000 (SAFE — localhost)

| # | Case                | Status | Assertion                       | Result |
|---|---------------------|--------|---------------------------------|--------|
| 1 | Golden path         | 201    | DTO shape match                 | PASS   |
| 2 | Missing `items`     | 400    | errors[].field == 'items'       | PASS   |
| 3 | No auth             | 401    | WWW-Authenticate header         | PASS   |
| 4 | Wrong tenant        | 404    | no resource in body             | PASS   |
| 5 | Idempotency replay  | 201    | same body both calls            | FAIL — different createdAt timestamps

Bugs surfaced:
  - case 5: idempotency not honored; missing IdempotencyService.getOrSet wrap.
  - case 1: response DTO declares correlationId but response omits it.

Curl commands:
  <each executed curl preserved for replay>
```

## False positives / gotchas

- **Phantom success** — 200 with wrong shape. Always diff response keys against DTO field-by-field.
- **Too-permissive dev auth** — local server may skip tenant guards that prod enforces. Cross-tenant 200 is a real bug, not "dev mode".
- **Stale server** — code edited but server not restarted. Look for the new line of code in the log; absent = restart needed.
- **Dynamic fields** (`createdAt`, `id`, `correlationId`) differ between calls — exclude when comparing shapes, not values.
- Don't start the server yourself (side effects). Print the dev command and stop if it isn't running.

## Halt conditions

- Halt on hand-waves: every PASS must cite the case number + status code + DTO `<file:line>` it diffed against.
- Halt if any of the 5 mandatory cases (golden / invalid body / no auth / wrong tenant / idempotency) was silently skipped.
- Halt if a 200 response was accepted without field-by-field diff against the response DTO — phantom success is the classic miss.
- Halt if the target host is not localhost / 127.0.0.1 / a session-named tunnel — refuse to fire requests at unverified hosts.
