---
name: data-fetching
description: "Pattern: client-side server-state / data fetching. Detects raw useEffect+fetch with no cache layer, mutations that never invalidate, missing request cancellation (race → stale render), fetch waterfalls, missing loading/error/empty states, a hand-rolled store reinventing a query cache, and over-fetch."
kind: ai-pattern
pack: frontend
---

# Pattern: Data Fetching (client-side server-state)

> **Hard rule:** Server state is NOT client state. It is a cache of data that lives on a server you do not own, and it MUST live behind a layer with a declared **staleKey**, **staleTime**, **request dedup** (in-flight sharing), and **invalidation on mutation**. A raw `fetch`/`axios` call inside a component with no cache, no dedup, and no invalidation path is forbidden — it re-fetches on every mount, tears on races, and goes stale the moment anything writes.

Every finding cites `<file:line>` + the matched pattern + the fix. "The data-fetching looks off" without a citation is a vibe, not a finding.

**When to apply**
- A component fetches data from an API and that data can change, be re-fetched, or be shown on more than one screen.
- A mutation (create/update/delete) exists and other views display the same entity — they must reflect the write.
- Lists, detail views, dashboards, or anything paginated/infinite-scrolled reads from the server.

**When NOT to apply**
- Build-time / static data (SSG payload, imported JSON, generated content) — no runtime cache needed; see `rendering-strategy.md`.
- A one-shot form POST whose only job is submit + navigate — that is `forms.md`'s territory (it owns submit/validation; this pattern owns the cache the submit invalidates).
- Purely local UI state (open/closed, selected tab, draft input) — that IS client state; a query cache is the wrong tool.

**Halt conditions / mandatory cites**
- Every finding MUST cite the fetch/mutation site at `<path:line>` AND name the missing contract element (staleKey / staleTime / dedup / invalidation / cancellation).
- A "mutation doesn't refresh the list" claim MUST cite both the mutation site AND the query/cache key it fails to invalidate — otherwise it is unprovable.
- A "waterfall" claim MUST cite the serial `await` sites that could run in parallel; "seems slow" is not a finding.
- If the project's own server-state primitive (query lib, store, hand-rolled cache) is not extracted first, halt — do not impose a second one.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when classifying a fetch.

## Server state vs client state

They look alike (both "data in a variable") but have opposite lifecycles:

| | Client state | Server state |
|---|---|---|
| Owner | This tab | A remote server |
| Truth | Always current | A **snapshot** — stale the instant it lands |
| Shared | No | Yes — many components, many tabs |
| Needs | `useState`/`ref`/signal | cache + staleTime + dedup + invalidation + refetch |

Treating server state as client state is the root defect: you copy a snapshot into `useState`, and now it never reflects writes, never dedups, and drifts across components. The fix is not "more `useState`" — it is a cache with a contract.

## The cache contract

A server-state layer MUST provide, per resource:

- **staleKey** — a stable, serializable key (`['items', { page, filter }]`). Same inputs → same key → same cache entry. Params in the key, not in closures.
- **staleTime** — how long a cached value is "fresh" before a background refetch is allowed. `0` means refetch-on-focus; a number means trust the snapshot that long. Declare it from product freshness needs, not by guessing.
- **dedup / in-flight sharing** — two components mounting the same key at once fire ONE request, not two. This is non-negotiable and the #1 thing hand-rolled code omits.
- **invalidate-on-mutation** — a write marks the affected keys stale so dependent views refetch. A mutation with no invalidation is a lie on screen.
- **background refetch / stale-while-revalidate** — show the cached value instantly, revalidate in the background, swap when fresh. Users never see a spinner for data you already have.
- **pagination / infinite cache** — each page is its own cache entry under the same root key; invalidation targets the root so all pages refetch together.

## UI states — all four, always

Every read renders four states, not one: **loading** (first fetch, no cached value → layout-stable skeleton, not a spinner), **error** (with a retry affordance, not a dead end), **empty** (data loaded, zero rows → an empty state, distinct from loading), and **refetching** (cached value on screen + a subtle background indicator — never blank the screen you already have). Missing empty-vs-loading distinction is a real bug: users see a spinner forever or "no results" during load.

## Cancellation on unmount + param change

Two fetches for the same view can resolve out of order — the slow first response lands AFTER the fast second, painting stale data. Every fetch MUST be cancellable, and MUST cancel when the component unmounts OR its params change. Query libs do this by keying; hand-rolled code needs an `AbortController` torn down in cleanup. No cancellation = race = stale render.

## Optimistic update + rollback

For fast, low-risk writes (toggle a flag, reorder), apply the change to the cache immediately, then reconcile: on success keep it, on error **roll back to the snapshot** and surface the failure. Capture the pre-mutation cache value so rollback is exact. Destructive or expensive writes stay pessimistic. For form-driven mutations, `forms.md` owns the submit/validation/field-error mapping; THIS pattern owns the optimistic cache write + rollback + invalidation the submit triggers.

## Avoiding waterfalls

- **Parallel** independent queries (`Promise.all`, parallel query hooks) — never `await` one just to start the next when they don't depend on each other.
- **Dependent** queries are legitimate only when B genuinely needs A's result; gate B on A's key, don't serialize by accident.
- **Prefetch** on hover / on route-intent so the data is warm before navigation — pairs with `rendering-strategy.md`'s navigation axis.

## Over-fetching

Fetching a whole entity to render three fields wastes payload and hydration. Use the API's projection/field-selection (`?fields=`, GraphQL selection set, a lean list-DTO) so the query returns what the view uses. When the endpoint has no projection, that is a server-side gap — point it at the backend `api-contract` / `pagination` owners, don't paper over it client-side.

## Adapt to the codebase

Extract the project's existing primitive and route every fix through it. Do NOT introduce a second library.

| Primitive | staleTime | Invalidation | Dedup |
|---|---|---|---|
| **TanStack Query** (React/Vue/Svelte/Solid) | `staleTime` per `useQuery` | `queryClient.invalidateQueries({ queryKey })` | automatic by `queryKey` |
| **SWR** (React) | `dedupingInterval` + `revalidateIfStale` | `mutate(key)` / global `mutate` | automatic by key |
| **RTK Query** | `keepUnusedDataFor` | `invalidatesTags` / `providesTags` | automatic by endpoint+args |
| **Apollo / urql** (GraphQL) | `fetchPolicy` (`cache-first`…) | cache eviction / `refetchQueries` / typed cache updates | normalized cache by `__typename:id` |
| **Vue** (Pinia Colada / VueUse `useAsyncState`) | Colada `staleTime`; `useAsyncState` is manual | Colada `invalidateQueries`; manual re-run otherwise | Colada by key; `useAsyncState` none |
| **Angular** (`httpResource` / `resource` signals + `HttpClient`) | resource re-runs on signal params | re-trigger via param signal / manual reload | none built-in — dedup in a service |
| **Plain** (hand-rolled `Map` cache + `AbortController`) | store `fetchedAt`, compare to a TTL | delete/refetch keys on write | share the in-flight `Promise` in the map |

The plain column is the fallback ONLY when the repo has no lib — and it must still implement all five contract elements, or it graduates into Detector 6.

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix.

**1. `useEffect` + `fetch`/`axios` with no cache layer.**
```tsx
// BAD - refetches every mount, no dedup, no invalidation, races on param change
useEffect(() => { fetch(`/items/${id}`).then(r => r.json()).then(setItem); }, [id]);
// GOOD - cache + key + dedup via the project's primitive
const { data: item } = useQuery({ queryKey: ['items', id], queryFn: () => api.item(id), staleTime: 30_000 });
```
grep: `rg -n "useEffect\([^)]*(fetch|axios|\.get\()" ` and `onMounted`/`ngOnInit` fetching into a local ref.

**2. Mutation with no cache invalidation / refetch.**
```tsx
// BAD - server updated, list on screen still shows old data
await api.updateItem(id, patch);
// GOOD - invalidate the keys the write affects
await api.updateItem(id, patch);
queryClient.invalidateQueries({ queryKey: ['items'] });
```
grep: `rg -n "await (api|client)\.(create|update|delete|post|put|patch)"` then check for a following `invalidate`/`mutate`/`refetchQueries`/`providesTags`.

**3. No request cancellation on unmount / param change (race → stale render).**
```tsx
// BAD - fast + slow response can land out of order; no teardown
useEffect(() => { fetch(`/items?q=${q}`).then(r => r.json()).then(setRows); }, [q]);
// GOOD - abort on cleanup / param change
useEffect(() => { const c = new AbortController();
  fetch(`/items?q=${q}`, { signal: c.signal }).then(r => r.json()).then(setRows).catch(ignoreAbort);
  return () => c.abort(); }, [q]);
```
grep: `rg -n "fetch\(" -A2 | rg -v "signal"` — any raw `fetch` in an effect with no `AbortController` and no cleanup return.

**4. Fetch waterfall (dependent awaits that could parallelize).**
```ts
// BAD - B doesn't depend on A, but waits for it
const user = await api.user(id);
const items = await api.items(id);
// GOOD - fire in parallel
const [user, items] = await Promise.all([api.user(id), api.items(id)]);
```
grep: `rg -n "await .*\n\s*(const|let).* = await"` (consecutive awaits) — inspect for a real data dependency; parallelize if none.

**5. Missing loading / error / empty / refetching states.**
```tsx
// BAD - renders data as if it always exists; blank on error, spinner-forever on empty
return <List rows={data.rows} />;
// GOOD - all four states handled, empty distinct from loading
if (isPending) return <ListSkeleton />;
if (error) return <ErrorState onRetry={refetch} />;
if (!data.rows.length) return <EmptyState />;
return <List rows={data.rows} busy={isFetching} />;
```
grep: `rg -n "isLoading|isPending|isError"` absent near a query consumer; a render that dereferences `data.` with no guard.

**6. Global store hand-rolled as a query cache (reinventing a query lib).**
```ts
// BAD - a store slice that is really a cache without dedup/staleTime/invalidation
const items = ref([]); async function load() { items.value = await api.items(); }
```
If a store exists ONLY to hold fetched server data + a loading flag + a manual reload, it is an under-built query cache. Fix: adopt the repo's query primitive, or complete the contract (staleTime, dedup, invalidation) per the Adapt table's plain column. grep: `rg -n "loading = (true|ref\(true)|isLoading" ` inside store/composable files that fetch.

**7. Over-fetch (whole entity when few fields used).**
```ts
// BAD - pulls the full entity to show name + status
const item = await api.item(id);          // 40 fields over the wire
return <Badge>{item.name} - {item.status}</Badge>;
// GOOD - project to what the view uses (server-side selection)
const item = await api.item(id, { fields: ['name', 'status'] });
```
grep: `rg -n "\.(item|entity|get)\(" ` where the render reads ≤3 fields of a large response. When the endpoint has no projection, hand off to the backend `api-contract` / `pagination` owner.

## Closure verbs

- **report-with-fix** — a cited defect (Detectors 1–7) with the fix expressed in the project's own primitive.
- **report-flagged** — a boundary case (deliberate no-cache one-shot, admin-only view with no freshness SLO) flagged for a human, not auto-changed.
- **dismiss** — a false positive: a genuinely one-shot POST (owned by `forms.md`), build-time static data (owned by `rendering-strategy.md`), or truly local UI state. Record why so the next scan doesn't re-flag it.

## Related

- `forms.md` — mutation/optimistic overlap. Ownership boundary: forms owns submit + validation + server-`code`→field mapping; **data-fetching owns the cache write, rollback, and invalidation** that submit triggers.
- `rendering-strategy.md` — SSR/SSG data owns the initial render; this pattern owns client-side refetch, dedup, and staleness after hydration. Don't client-fetch what the server already rendered.
- `ssr-safety.md` — hydration-safe reads (no fetch-in-render mismatch) sit beside this pattern's cancellation rule.
- `realtime-client.md` — a live event patches/invalidates the cache this pattern owns; the reconcile target for a WebSocket/SSE stream.
- `error-boundaries.md` — a thrown query error surfaces to a boundary vs an inline `{error}` branch; ownership decided per subtree.
- `list-virtualization.md` — infinite/paginated list data comes from this query cache; each page is a cache entry the virtualizer windows.
- `@data-flow-auditor` — the reviewer agent that enforces these detectors on a diff.
- performance pack `inp-responsiveness` — refetch storms and over-eager revalidation are an INP/interaction cost; tune `staleTime` and dedup there.
- backend pack `pagination` / `api-contract` — the server side of paginated reads and field projection (Detector 7's hand-off target).
