---
name: pagination
kind: example
pack: backend
---

# Pattern: Pagination (cursor-first, stable, bounded)

Every list endpoint paginates (a MUST) and it is the axis LLMs get naively wrong: raw `OFFSET`, no default limit, unstable sort, `COUNT(*)` per page. Mirror the framework's own primitive.

## Cursor (keyset) vs offset — cursor by default

- **Offset** `LIMIT n OFFSET m`: O(offset) deep-page cost; skips/duplicates rows under concurrent writes; supports jump-to-page. Use ONLY for small quiescent admin tables.
- **Cursor/keyset** (preferred): O(log n) via index; stable under writes; next/prev only. Everything user-facing / high-cardinality.

## Rules

1. Default + hard-max page size; clamp/reject over the cap (unbounded list = DoS).
2. Stable total sort — append the PK tiebreaker: `ORDER BY created_at DESC, id DESC`.
3. Opaque cursor encoding the last row's sort-key (`{created_at,id}`), not an offset; signed if tamper matters.
4. Keyset predicate matches the sort: `WHERE (created_at, id) < (:c, :i)`; index-backed.
5. Avoid `COUNT(*)` per page — return `hasMore` (fetch limit+1) or a separate cached count.
6. Pagination meta in the single project envelope (`api-contract.md`): `{data, meta:{nextCursor,hasMore}}`.

## Detectors (cite-or-halt)

1. List endpoint returning an unbounded query (`findAll` / `SELECT *` no `LIMIT`).
2. `limit`/`pageSize` read with no default + no cap.
3. `OFFSET`/`.skip()` on a growing/hot table → recommend cursor.
4. Unstable sort (non-unique column, no `id` tiebreaker) → rows drop/repeat.
5. `COUNT(*)` per page on a large table → limit+1 / cached count.
6. Pagination-meta shape drifts from sibling list endpoints.

Closure verbs: `report-with-fix` / `report-flagged` (offset justified now but growing → cursor ADR) / `dismiss` (bounded enum/config list).

## Related

`api-contract.md` (envelope), `response-streaming.md` (unbounded export → stream), `conditional-requests.md` (page ETag).
