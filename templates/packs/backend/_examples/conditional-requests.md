---
name: conditional-requests
description: 'Pattern: Conditional Requests & Optimistic Concurrency (ETag / If-Match / 304 / 412 / 428)'
kind: ai-pattern
pack: backend
---

# Pattern: Conditional Requests & Optimistic Concurrency

> **Hard rule:** A resource that can be updated concurrently MUST expose an `ETag` and require `If-Match` on writes — a matching tag proceeds, a stale tag returns `412 Precondition Failed`, a missing one returns `428 Precondition Required`. Read endpoints of cacheable resources emit an `ETag` and honor `If-None-Match` with `304 Not Modified`. A `PUT`/`PATCH` with no precondition mechanism is a lost-update bug. This file owns the HTTP wire contract; the DB-layer version column is owned by the data/event-sourcing layer.

**When to apply** — any resource with multi-actor writes (lost updates possible), and read-heavy resources where revalidation saves bandwidth. Especially when a `version`/`updated_at`/`row_version` column already exists but isn't surfaced over HTTP.

**Halt conditions / mandatory cites**
- A write endpoint whose entity has a version column but NO `If-Match` handling MUST be cited at `<path:line>` — lost-update-prone.
- A `GET` of a cacheable single resource with no `ETag` is a finding.
- The ETag→version mapping MUST fire the `412` from the precondition check BEFORE the DB write, not from a unique-constraint race after.

## ETag generation — strong vs weak

- **Strong ETag** (`"v42"` from a monotonic version column, or a content hash): byte identity. Required for `If-Match`.
- **Weak ETag** (`W/"..."`): semantic equivalence only. Fine for `If-None-Match`; NOT safe for `If-Match` writes.
- Prefer a **version column** as the ETag source over hashing the body — cheap, monotonic, maps to optimistic-lock semantics. Emit `ETag` on every single-resource `GET` and on the response of a successful write.

## Read revalidation (GET)

```
GET /orders/42 → 200 OK, ETag: "v7"
GET /orders/42  (If-None-Match: "v7") → 304 Not Modified (empty body; client reuses cache)
```

`Last-Modified` + `If-Modified-Since` is the weaker, second-resolution alternative when no version/hash exists.

## Write-path optimistic concurrency (PUT/PATCH/DELETE)

```
PATCH /orders/42  (If-Match: "v7")
  current == "v7"  → 200 OK, new ETag: "v8"
  current == "v9"  → 412 Precondition Failed   (client refetches + retries)
  no If-Match      → 428 Precondition Required
```

- Make `If-Match` **mandatory** on contended writes — `428` when absent prevents blind overwrites.
- Map the header to the version column and check inside the write transaction (`UPDATE ... WHERE id=? AND version=?`; 0 rows → `412`). This closes the read-modify-write race a separate `SELECT`+`UPDATE` leaves open.

## Status codes

| Code | Meaning | Trigger |
|---|---|---|
| `304 Not Modified` | Cached copy still valid | `If-None-Match` matches on a read |
| `412 Precondition Failed` | Precondition false | `If-Match` stale on a write |
| `428 Precondition Required` | Server requires a precondition | `If-Match` absent on a guarded write |

Reference: **RFC 9110** (HTTP Semantics — conditional requests; obsoletes RFC 7232).

## Detectors (cite-or-halt)

- Write endpoint on an entity with a version/updated_at column and NO `If-Match` read → `add-optimistic-concurrency` (subclass `optimistic-concurrency-missing`).
- `GET` of a cacheable single resource with no `ETag` → `add-etag` (subclass `etag-coverage-gap`).
- `If-Match` validated by a `SELECT` then a separate `UPDATE` (race window) → `move-precondition-into-write-transaction`.
- A 200 on a write that ignores a stale `If-Match` → blind overwrite; BLOCK.

**Closure verbs:** `add-etag`, `add-optimistic-concurrency`, `move-precondition-into-write-transaction`.

## Tests (hand to endpoint-tester)

- `If-None-Match` with the current tag → `304` + empty body.
- Stale `If-Match` on a write → `412`. Absent `If-Match` on a guarded write → `428`.
- Concurrent writers: A reads v7, B reads v7, B writes (→v8), A writes `If-Match: "v7"` → `412` (no lost update).

## Forbidden

- A contended write path with no precondition (last-write-wins by accident).
- A weak ETag (`W/"..."`) used to gate an `If-Match` write.
- Validating the precondition outside the write transaction (race window remains).
- Emitting `ETag` on reads but ignoring `If-Match` on writes.
