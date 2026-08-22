---
name: pagination
kind: pattern
pack: backend
---

# Pattern: Pagination (cursor-first, stable, bounded)

Every list endpoint paginates — `backend-principles` makes it a MUST — yet it is the axis LLMs most often get naively wrong: raw `OFFSET`, no default limit, an unstable sort, or a `COUNT(*)` on every page. This pattern is the contract for correct, cheap pagination; mirror the framework's own primitive rather than hand-rolling.

## Cursor (keyset) vs offset — choose cursor by default

| | Offset / `LIMIT n OFFSET m` | **Cursor / keyset (preferred)** |
|---|---|---|
| Deep-page cost | O(offset) — the DB scans + discards m rows; page 10,000 is slow | O(log n) via the index — constant per page |
| Correctness under writes | **skips/duplicates rows** when items are inserted/deleted between pages | stable — anchored to a row's key, not a position |
| Jump-to-page N | supported | not supported (next/prev only) — acceptable for feeds/APIs |
| Total count | easy but expensive | usually omitted (see below) |

Use **offset only** for small, bounded, admin-style tables where jump-to-page matters and the data is quiescent. Everything user-facing or high-cardinality is cursor.

## Rules

1. **Default + max limit.** Every list endpoint applies a default page size and a hard cap (e.g. default 20, max 100). An unbounded list is a DoS + memory risk. Reject or clamp `limit` over the cap.
2. **Stable, total ordering.** Sort on a column set that is unique — append a tiebreaker (the primary key) so `created_at` ties don't shuffle between pages: `ORDER BY created_at DESC, id DESC`. A non-unique sort silently drops/repeats rows across cursor pages.
3. **Opaque cursor.** The cursor encodes the last row's sort-key values (base64/HMAC of `{created_at, id}`), not a raw offset. Opaque so clients can't forge it into an expensive scan; signed if tampering matters. Decode → `WHERE (created_at, id) < (:c, :i)`.
4. **The keyset predicate matches the sort.** For `ORDER BY a DESC, b DESC`, page with the row-value comparison `WHERE (a, b) < (:a, :b)` — not `a < :a OR (a = :a AND b < :b)` hand-expanded wrong. Filters + sort must both be index-backed.
5. **Avoid `COUNT(*)` per page.** Total count on a large filtered table is expensive; omit it, return `hasMore` (fetch limit+1, drop the extra), or provide an approximate/cached count on a separate endpoint.
6. **Consistent envelope.** Return the page items + pagination meta in the project's single response envelope (see `api-contract.md`): `{ data, meta: { nextCursor, hasMore } }` for cursor, `{ data, meta: { page, pageSize, total } }` for offset. Same shape across every list endpoint.

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix.

### 1. List endpoint with no pagination at all

```
BAD:   const rows = await repo.findAll()        // returns the whole table
GOOD:  const rows = await repo.page({ limit, cursor })
```
Flag a list/collection handler returning an unbounded query result (`findAll`, `SELECT *` with no `LIMIT`, `.all()`).

### 2. No default / max limit

Flag a `limit`/`per_page`/`pageSize` param read straight from the query with no default and no cap → client can request a million rows.

### 3. Offset pagination on a large/hot table

```
BAD:   .limit(20).offset(page * 20)             // O(offset) scan; skips rows under concurrent writes
GOOD:  keyset: WHERE (created_at, id) < (:c, :i) ORDER BY created_at DESC, id DESC LIMIT 20
```
Flag `OFFSET` / `.skip()` / `.offset()` on an endpoint over a growing table — recommend cursor.

### 4. Unstable sort (no unique tiebreaker)

Flag `ORDER BY <non-unique column>` used for pagination with no `, id` tiebreaker → rows drop/repeat across pages.

### 5. `COUNT(*)` on every page of a large table

Flag a total-count query issued alongside each page on a big/filtered table → recommend `hasMore` (limit+1) or a separate cached count.

### 6. Envelope drift

Flag a list endpoint whose pagination meta shape differs from its siblings (some return `nextCursor`, some `next_page`, some a bare array) → unify on the project envelope.

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete default-limit / keyset / tiebreaker / limit+1 patch.
- `report-flagged` — offset is currently justified (small quiescent table) but the endpoint is growing → surface for a cursor migration ADR.
- `dismiss` — carve-out applies (single-row lookup; a genuinely bounded enum/config list) → documented so the next scan does not re-flag it.

## Related

- `api-contract.md` — the single response envelope the pagination meta lives in.
- `response-streaming.md` — for unbounded exports, stream (keyset-sourced) instead of paginating.
- `conditional-requests.md` — a page response can still carry an ETag for revalidation.

### Crossing to the consumer

Rule 6 fixes the `meta` keys and Detector 2 names three live query-param spellings (`limit` / `per_page` / `pageSize`). Both are contract, and neither is in the OpenAPI schema in a form a consumer can infer: a client that guesses reads `meta.total` off a cursor response that carries only `nextCursor` / `hasMore`, gets `undefined`, renders page 1, and never pages again — with no error anywhere.

- **Publish the choice**, don't just make it. `api-contract.md` § Publishing the contract — the first delivery names the file (`api-snapshots/README.md`) and the lane. One line — mode, meta keys, param spelling — is the whole obligation.
- `@api-contract-sentry` *(frontend pack, when co-installed)* — reads that lane and reports what the client actually assumes, at `<path:line>`. On a first delivery it reports the read; on a change it reports the breakage. **Absent** → the consumer's assumption is *unchecked*, not correct: grep the client for `per_page|pageSize|meta\.total|nextCursor` yourself and reconcile against rule 6 before calling a list endpoint done.
