---
name: conditional-requests
description: 'Pattern: Conditional Requests & Optimistic Concurrency (ETag / If-Match / 304 / 412 / 428)'
kind: ai-pattern
pack: backend
---

# Pattern: Conditional Requests & Optimistic Concurrency

> **Hard rule:** A resource that can be updated concurrently MUST expose an `ETag` and require `If-Match` on writes — a matching tag proceeds, a stale tag returns `412 Precondition Failed`, a missing one returns `428 Precondition Required`. Read endpoints of cacheable resources emit an `ETag` and honor `If-None-Match` with `304 Not Modified`. A `PUT`/`PATCH` with no precondition mechanism is a lost-update bug, not a style choice. This file owns the HTTP wire contract; the DB-layer version column it maps to is owned by the data/event-sourcing layer.

**When to apply**
- Any resource with multi-actor writes (admin + user, two tabs, mobile + web, a webhook + a human) — i.e. lost updates are possible.
- Read-heavy resources where revalidation saves bandwidth (a client polls, or a CDN/browser caches).
- An API that already has a `version` / `updated_at` / row-version column but doesn't surface it over HTTP.

**When NOT to apply**
- Append-only / create-only resources (`POST` to a collection) — there's no prior state to clobber.
- Single-writer resources (only a background job mutates them) — **document the assumption *and* name what would falsify it**, because this is the carve-out that expires silently. The assumption dies the first time an admin screen, a support tool, a bulk importer or a second consumer of the same queue writes that row, and none of those arrive with an announcement. Write it as a checkable claim ("only `reconcile.job.ts` writes `invoice.status`"), so `rg` can re-check it in one line when the next writer appears, rather than as a belief nobody can re-derive.
- Internal RPC where the caller already holds the version in a shared transaction.

**Halt conditions / mandatory cites**
- A write endpoint whose entity has a `version`/`updated_at`/`row_version` column but NO `If-Match` handling MUST be cited at `<path:line>` — it is lost-update-prone.
- A `GET` of a cacheable single resource with no `ETag` header is a finding — cite the response builder.
- A doc proposing "last write wins" on a contended resource without an explicit product sign-off is a bug — reject.
- The ETag→version mapping MUST be cited: the `412` has to fire from the precondition check BEFORE the DB write, not from a DB unique-constraint race after.

## ETag generation — strong vs weak

- **Strong ETag** (`"v42"` from a monotonic version column, or a content hash): byte-for-byte identity. Required for `If-Match` optimistic concurrency.
- **Weak ETag** (`W/"..."`): semantic equivalence only (e.g. same data, different whitespace). Fine for `If-None-Match` revalidation; NOT safe for `If-Match` writes.
- Prefer a **version/row-version column** as the ETag source over hashing the serialized body — it's cheap, monotonic, and maps directly to optimistic-lock semantics. Hash only when there's no version column.
- Emit `ETag` on every single-resource `GET` and on the response of a successful write (the new tag, so the client can chain edits).

## Read revalidation (GET)

```
GET /orders/42
→ 200 OK
  ETag: "v7"

GET /orders/42
  If-None-Match: "v7"
→ 304 Not Modified          (empty body — client reuses its cached copy)
  ETag: "v7"
```

`Last-Modified` + `If-Modified-Since` is the weaker, second-resolution alternative when no version/hash exists — emit one or the other, prefer `ETag`.

## Write-path optimistic concurrency (PUT/PATCH/DELETE)

```
PATCH /orders/42
  If-Match: "v7"
  { "status": "shipped" }

If current ETag == "v7"  → 200 OK, new ETag: "v8"
If current ETag == "v9"  → 412 Precondition Failed   (someone else updated; client refetches + retries)
If no If-Match header    → 428 Precondition Required  (force the client to send a precondition)
```

- Make `If-Match` **mandatory** on contended writes — returning `428` when it's absent prevents blind overwrites.

### Turning `428` on is a breaking change — roll it out, don't ship it

**This is the collision between this pattern and `api-versioning.md`, and it is not stated anywhere else.** A live `PATCH` that accepted requests without `If-Match` yesterday and returns `428` today has *added a required input*, which `api-contract.md` § Evolution rules classifies as breaking and `api-versioning.md` therefore routes to a new version. Flipping it on in place will 428 every existing client at once — and clients that do not understand `428` will surface it as a generic failure, so you get an outage that reads like a bug in their code.

Three phases, and the middle one is the one people skip:

1. **Advertise.** Emit `ETag` on the reads and on write responses. Accept `If-Match` when sent, honour it (`412` on stale), and **do not** require it. Nothing breaks; clients that want the guarantee can opt in today.
2. **Observe.** Instrument the proportion of writes to this route arriving *with* a valid `If-Match`, **per consumer** — not in aggregate, because one large client at 100% will hide four small ones at 0%. Enforcement is safe when every consumer you can name is sending it and the remainder is traffic you are willing to break. This is the same per-consumer traffic dashboard `api-versioning.md` requires before removing a version; it is the same question, asked before adding a requirement rather than before removing a capability.
3. **Enforce.** Now `428` on absence. If step 2 says a consumer is still not sending it, enforcing is a version bump, not a config flip — and the honest options are to ship it on `/v2` or to keep advertising until that consumer moves.

**A green-field or single-consumer route skips straight to step 3** — there is nobody to break, and the ceremony is the cost. Say which case you are in; the phases are for a surface that already has callers.
- Map the header value to the version column and check it inside the same transaction that writes (`UPDATE ... WHERE id=? AND version=?`; 0 rows affected → `412`). This closes the read-modify-write race that a separate `SELECT` then `UPDATE` leaves open.
- On `412`, the client refetches the current representation, reapplies its change, and retries — document this loop for consumers.

## Status codes

| Code | Meaning | Trigger |
|---|---|---|
| `304 Not Modified` | Cached copy still valid | `If-None-Match` matches on a read |
| `412 Precondition Failed` | Precondition was false | `If-Match` is stale on a write |
| `428 Precondition Required` | Server requires a precondition | `If-Match` absent on a guarded write |

Reference: **RFC 9110** (HTTP Semantics — conditional requests; obsoletes RFC 7232).

## Detectors (cite-or-halt)

- A route that emits `ETag` and requires `If-Match` where the change landed in place on a live version, with no advertise→observe→enforce record and no version bump → `report-flagged`, and route to `api-versioning.md`. Adding a required precondition is an added required input; the rollout above is the fix, not the removal of the precondition.
- Write endpoint (`PUT`/`PATCH`/`DELETE`) on an entity with a `version`/`updated_at`/`row_version` column and NO `If-Match` read → `add-optimistic-concurrency` (audit subclass `optimistic-concurrency-missing`).
- `GET` of a cacheable single resource with no `ETag` in the response → `add-etag` (audit subclass `etag-coverage-gap`).
- `If-Match` validated by a `SELECT` then a separate `UPDATE` (race window) → `move-precondition-into-write-transaction`.
- A 200 on a write that ignores a provided stale `If-Match` → blind overwrite; BLOCK.

**Closure verbs:** `add-etag`, `add-optimistic-concurrency`, `move-precondition-into-write-transaction`.

## Tests (hand to endpoint-tester)

- `If-None-Match` with the current tag → expect `304` + empty body.
- Stale `If-Match` on a write → expect `412`.
- Absent `If-Match` on a guarded write → expect `428`.
- Concurrent writers: A reads v7, B reads v7, B writes (→ v8), A writes with `If-Match: "v7"` → expect `412` (no lost update).

## Forbidden

- A contended write path with no precondition (last-write-wins by accident).
- A weak ETag (`W/"..."`) used to gate an `If-Match` write.
- Validating the precondition outside the write transaction (race window remains).
- Emitting `ETag` on reads but ignoring `If-Match` on writes (revalidation without concurrency control is half the pattern).
