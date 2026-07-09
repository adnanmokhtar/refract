---
name: data-fetching
kind: example
pack: frontend
---

# Pattern: Data Fetching (client-side server-state)

> **Hard rule:** Server state is NOT client state. It is a cache of data on a server you don't own, and it MUST live behind a layer with a declared **staleKey**, **staleTime**, **request dedup**, and **invalidation on mutation**. A raw `fetch`/`axios` in a component with no cache, no dedup, and no invalidation path is forbidden — it re-fetches every mount, tears on races, and goes stale the moment anything writes.

Every finding cites `<file:line>` + the matched pattern + the fix.

## Server state vs client state

Both look like "data in a variable" but have opposite lifecycles: client state is owned by this tab and always current (`useState`); server state is a shared **snapshot**, stale the instant it lands, and needs cache + staleTime + dedup + invalidation + refetch. Copying a snapshot into `useState` is the root defect.

## The cache contract (per resource)

- **staleKey** — stable serializable key (`['items', { page, filter }]`); params in the key, not closures.
- **staleTime** — how long a value is fresh before a background refetch; declare from product freshness needs.
- **dedup** — two mounts of the same key fire ONE request; the #1 thing hand-rolled code omits.
- **invalidate-on-mutation** — a write marks affected keys stale; a mutation with no invalidation is a lie on screen.
- Plus background refetch (stale-while-revalidate) and per-page cache entries for pagination.

Every read renders all four states — loading (skeleton) / error (with retry) / empty (distinct from loading) / refetching (cached value + subtle indicator).

## Adapt to the codebase

Extract the project's primitive; route every fix through it. Never add a second library.

| Primitive | staleTime | Invalidation | Dedup |
|---|---|---|---|
| **TanStack Query** | `staleTime` per query | `invalidateQueries({ queryKey })` | automatic by key |
| **SWR** | `dedupingInterval` | `mutate(key)` | automatic by key |
| **RTK Query** | `keepUnusedDataFor` | `invalidatesTags`/`providesTags` | by endpoint+args |
| **Apollo/urql** | `fetchPolicy` | eviction / `refetchQueries` | normalized cache |
| **Plain** (`Map` + `AbortController`) | store `fetchedAt` vs TTL | delete/refetch keys | share in-flight `Promise` |

## Detectors (cite-or-halt)

1. **`useEffect` + `fetch`/`axios` with no cache layer** — refetches every mount, races on param change → route through the query primitive.
2. **Mutation with no invalidation/refetch** — cite the mutation site AND the query key it fails to invalidate.
3. **No cancellation on unmount/param change** — fast+slow responses land out of order; needs `AbortController` teardown or keyed query.
4. **Fetch waterfall** — consecutive `await`s with no real data dependency → `Promise.all`.
5. **Global store hand-rolled as a query cache** — a store slice holding fetched data + a loading flag, missing dedup/staleTime/invalidation.

## Related

- `forms.md` — forms owns submit + validation + server-`code`→field mapping; this pattern owns the cache write, rollback, and invalidation the submit triggers.
- `realtime-client.md` — live events patch/invalidate the cache this pattern owns.
- `error-boundaries.md` — a thrown query error surfaces to a boundary vs an inline `{error}` branch.
- `list-virtualization.md` — infinite/paginated list data comes from this query cache.
- `@data-flow-auditor` — the reviewer agent that enforces these detectors on a diff.
