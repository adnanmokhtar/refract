---
name: ssr-safety
description: Pattern — hydration correctness for server-rendered routes. Decides WHERE a browser-only read is allowed to happen (never in render), how a non-deterministic value crosses the server/client boundary, and when mismatch suppression is a decision rather than a cover-up. Framework-agnostic; ships per-framework guard primitives, BAD/GOOD detectors with working greps, and closure verbs.
kind: ai-pattern
pack: frontend
---

# Pattern: SSR Safety

> **Hard rule:** The server-rendered **DOM tree** must match the first client render — same elements, same order, same text. Reading `window` / `document` / `localStorage` / `Date.now()` / `Math.random()` **during render** without a client-only guard is forbidden; those reads belong in an effect / `onMounted` / a client-only component. A non-deterministic value must be generated on ONE side and passed across, or annotated with the framework's mismatch-suppression primitive — never left to differ silently.

**Why "tree", not "bytes".** Hydration reconciles the DOM, not the response body: attribute order and insignificant whitespace differ routinely without any mismatch, and React recovers from a mismatch by client-rendering that subtree with a warning. "Byte-for-byte" is unfalsifiable at review time — nobody diffs two byte streams — and it makes the suppression escape hatch look like a violation. Grade the tree; that is what the framework grades.

**When to apply**
- The framework does SSR (Next App Router, Nuxt, SvelteKit, Remix, Angular SSR) — every component is suspect by default.
- A hydration-mismatch warning appears in the browser console.
- Per-user content (auth state, locale, theme) renders differently on server vs client.

**When NOT to apply**
- Pure CSR SPA — there is no server render to mismatch with.
- A static export where the "server" is the build, not a request: per-request values (cookies, headers, geo) do not exist at all, and the fix is a different one — re-scope to `rendering-strategy.md` before debugging.
- A component that is client-only by construction (behind the framework's client-only boundary) — it never renders on the server, so it cannot mismatch.

**Halt conditions / mandatory cites**
- Any browser-API access in a component body MUST cite the file at `<path:line>` **and** the client-only guard that will hold it (effect, lifecycle hook, dynamic client-only import, `<ClientOnly>`).
- Any per-request value (cookies, headers, locale) used in render MUST cite the SSR-safe accessor, not a global.
- **`typeof window !== 'undefined'` branching the returned markup is the bug, not the fix** — it produces two different trees by construction. The same expression *outside* render (in an effect, an event handler, a module function called from one) is correct and must not be flagged. Grade by position, and say which position you found.
- Mismatch suppression cited without naming the value that legitimately differs (a timestamp, a locale-formatted number, a user-agent-derived class) is a cover-up — reject it.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming a component is SSR-safe.
- If the framework + version + rendering mode are not extracted, halt before debugging hydration.

SSR renders on the server, hydrates on the client. Anything that differs between the two is a hydration mismatch, and a mismatch either warns-and-reclient-renders (slow, invisible in production) or breaks the page outright.

## Scope

Applies to Nuxt, Next (App Router), SvelteKit, Remix, Angular SSR — any framework that renders on the server and hydrates on the client.

## Adapt to the codebase

Mirror the project's existing client-guard primitive; never introduce a second mechanism.

| Stack | "Am I on the client?" | Client-only subtree | SSR-stable id | External store during SSR |
|---|---|---|---|---|
| **Nuxt** | `import.meta.client` | `<ClientOnly>` | `useId()` | `useState()` payload (serialized server to client) |
| **Next (App Router)** | `useEffect` / a mounted flag | `dynamic(..., { ssr: false })` — **inside a Client Component only**; it is not allowed in a Server Component | `useId()` | `useSyncExternalStore` with `getServerSnapshot` |
| **SvelteKit** | `browser` from `$app/environment` | `{#if browser}` around the subtree | framework-generated id | store hydrated from `load` data |
| **Angular (SSR)** | `isPlatformBrowser(platformId)` | `@defer (on viewport)` / client-only component | Angular-generated id | `TransferState` |
| **Remix / React Router** | `useEffect` / a mounted flag | `<ClientOnly>` helper | `useId()` | loader data as the server snapshot |
| **Plain React SSR** | `useEffect` / a mounted flag | `lazy` + a mounted gate | `useId()` | `useSyncExternalStore` + `getServerSnapshot` |

If the guard primitive cannot be identified, halt: the wrong guard is not a smaller version of the right one, it is a different tree.

## Browser-only APIs

Guard `window`, `document`, `localStorage`, `sessionStorage`, `navigator`. **All three options below run OUTSIDE render** — that is the whole point:

```ts
// Option 1: client lifecycle - the default. The read happens after mount, never during render.
onMounted(() => { localStorage.setItem('x', 'y'); });     // Nuxt / Vue
useEffect(() => { localStorage.setItem('x', 'y'); }, []); // React

// Option 2: client-only component wrapper - the subtree never renders on the server at all.
<ClientOnly>
  <ComponentUsingWindow />
</ClientOnly>

// Option 3: an environment check INSIDE a non-render function (an event handler, a util
// called from an effect). Legitimate here; the same check in a render/template branch is
// Detector 2 and must be rejected.
function persistTheme(t) {
  if (import.meta.client /* Nuxt */ || typeof window !== 'undefined') localStorage.setItem('theme', t);
}
```

## Non-deterministic values

Anything that differs between the two renders breaks hydration:

- `new Date()` / `Date.now()` — server and client clocks differ, and so do their time zones.
- `Math.random()` / `crypto.randomUUID()` — different values by definition.
- User-agent branches — different results per environment.
- Hand-rolled element ids (`id-${counter++}`) — the counter restarts, so `aria-describedby` wiring points at nothing after hydration.

Fixes, in order of preference:
1. **Generate once, pass across** — compute on the server and ship it through the framework's state/payload channel (props, Nuxt `useState`, SvelteKit loader data, Angular `TransferState`).
2. **Use the framework's SSR-stable id API** for a11y wiring (`useId()` and its equivalents) instead of a counter or a random string.
3. **Suppress deliberately, and only for the leaf that legitimately differs** — the framework's mismatch-suppression primitive (React's `suppressHydrationWarning`) applied to the single text node holding the timestamp. It silences the warning; it does not make the values agree. Suppression on a container, or on a value that *could* have been passed across, is Detector 6.

## Data fetching

Use the framework's SSR-aware fetcher so the read happens once and its result crosses the boundary as data, not as a second request:

- Nuxt: `useFetch` / `useAsyncData` with an explicit `key`.
- Next (App Router): `await fetch()` **inside an async Server Component** is the documented primitive — a Server Component does not re-run on the client, so there is no double fetch, and identical `fetch` requests in one tree are memoized per request (nextjs.org/docs/app/getting-started/fetching-data, v16.3.1). In a **Client** Component, use `use()` on a server-passed promise or the project's query library — never a bare `fetch` in the component body.
- SvelteKit: `load` functions.
- Angular: resolvers / `resource()` with `TransferState`.

**The rule with its boundary stated:** a bare `fetch()` in a **client** component body (a `setup()` block, a function-component body that hydrates) is forbidden — SSR runs it, the client re-runs it, and the two results race. In a Server Component it is the recommended pattern. Grade by component kind, not by the presence of the word `fetch`.

## Multi-tenant SSR — the one hydration-shaped fact

Tenant resolution is a **backend** concern (host-header resolution, request-scoped storage, the one-writer rule) and `backend/multi-tenancy.md` § Resolution chain owns it; do not restate the sequence here.

What belongs on this page is the hydration half: **the tenant crosses the boundary as payload and is never re-derived on the client.** A client that re-reads the tenant — from `localStorage`, a subdomain parse, a cookie — can disagree with the server that rendered the page, and the two renders are then for two different tenants. That is Detector 4's failure mode with a security shape rather than a cosmetic one, which is why the detector's own wording says "across tenants, that is a data leak, not a glitch." Pass it down through the framework's payload channel and read it from there on both sides.

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix in the project's own primitive.

**1. Module-scope browser API.** Runs on both server and client, at import time, before any guard exists.
```ts
// BAD - throws on the server, or captures a server-side value that the client then contradicts
const width = window.innerWidth;
// GOOD - read after mount, hold it in state
const width = ref(0); onMounted(() => { width.value = window.innerWidth; });
```
grep: `rg -n '^\s*(const|let|var)\s+\w+\s*=\s*(window|document|navigator|localStorage|sessionStorage)\b'`

**2. Environment check branching the rendered markup.** Two trees by construction — this is the mismatch, not the fix.
```tsx
// BAD - server returns null, client returns <Canvas/>
if (typeof window !== 'undefined') return <Canvas />;
// GOOD - the framework's client-only boundary; one tree, filled in after mount
<ClientOnly><Canvas /></ClientOnly>
```
grep: `rg -n 'typeof window|import\.meta\.client|isPlatformBrowser'` then **classify by position**: inside a render/template branch = finding; inside an effect, handler, or a function called from one = dismiss, and record why so the next scan does not re-flag it.

**3. Non-deterministic value in render output.**
```tsx
// BAD - the server's clock and the client's clock are not the same clock
<span>{new Date().toLocaleTimeString()}</span>
// GOOD - server computes, client receives; or suppress the single leaf (Detector 6)
<span>{props.renderedAt}</span>
```
grep: `rg -n 'Math\.random\(|Date\.now\(|crypto\.randomUUID\(|new Date\(\)'` — then check whether the call site is in render.

**4. Unkeyed async data.** Two routes sharing an auto-derived key collide, and the second render serves the first one's payload — across tenants, that is a data leak, not a glitch.
```ts
// BAD - key auto-derived from the call site; collides
const { data } = await useAsyncData(() => $fetch('/api/products'));
// GOOD - explicit, scoped key
const { data } = await useAsyncData(`products-${tenantId}`, () => $fetch('/api/products'));
```
grep: `rg -n 'useAsyncData\(\s*(\(|async|function)'` (a first argument that is the fetcher rather than a key).

**5. Locale/timezone-dependent formatting with no explicit locale.** The server's locale and time zone are the container's, not the user's.
```ts
// BAD - "3/4/2026" on the server, "04/03/2026" in the browser
<span>{d.toLocaleDateString()}</span>
// GOOD - explicit locale + timeZone, both crossing the boundary as data
<span>{new Intl.DateTimeFormat(locale, { timeZone: tz }).format(d)}</span>
```
grep: `rg -n 'toLocaleDateString\(\)|toLocaleTimeString\(\)|toLocaleString\(\)|Intl\.[A-Za-z]+Format\(\)'` (empty argument list = no explicit locale).

**6. Mismatch suppression used to hide a real divergence.** Suppression is a decision about a value that *cannot* agree; it is not a way to make a fixable mismatch quiet.
```tsx
// BAD - suppressing a whole subtree so nobody has to find the real cause
<div suppressHydrationWarning>{renderEverything()}</div>
// GOOD - the one leaf that legitimately differs, with the reason recorded
<time suppressHydrationWarning>{localTime}</time>  // client clock, deliberately
```
grep: `rg -n 'suppressHydrationWarning'` — every hit must name the differing value and why it could not be passed across instead.

**7. External store read during SSR with no server snapshot.** A store initialised from browser state renders empty on the server and full on the client.
```ts
// BAD - server render throws, or the subscription's snapshot differs after hydration
const theme = useSyncExternalStore(subscribe, () => store.theme);
// GOOD - a server snapshot that matches the initial client snapshot exactly
const theme = useSyncExternalStore(subscribe, () => store.theme, () => serverTheme);
```
React documents that omitting `getServerSnapshot` makes server rendering throw, and that it "must be the same between the client and the server" (react.dev/reference/react/useSyncExternalStore). grep: `rg -n 'useSyncExternalStore\('` — the regex cannot count arguments, so read each hit and check for the third one; for non-React stacks, check that the store is hydrated from the framework's payload rather than from `localStorage`.

## Closure verbs

- `move-to-effect` — relocate a browser-API read from render/module scope into the client lifecycle, and cite the new call site.
- `wrap-client-only` — put the subtree behind the framework's client-only boundary instead of branching on the environment.
- `stabilize-value` — generate the non-deterministic value on one side and pass it across (or switch a hand-rolled id to the framework's id API).
- `key-async-data` — give the SSR fetcher an explicit, scope-including key.
- `pin-format-locale` — supply the explicit locale + time zone to the formatter, sourced from the request.
- `snapshot-external-store` — add the server snapshot (or hydrate the store from the framework payload) so both renders agree.
- `justify-suppression` — keep the suppression, narrowed to the leaf, with the reason recorded so the next scan dismisses it instead of re-opening it.
- `halt-handoff` — a finding that is really a rendering-strategy or navigation concern, handed to that owner by name.

## Auditing

Run the `ssr-audit` skill (in-pack) — it executes these greps across the repo and reports `file:line` + the matched pattern. It is static: it never runs the app, so a clean scan is a floor, not a hydration guarantee. Confirm with a real render (`visual-check`) on the routes it touched.

## Forbidden

- Module-scope `window` / `document` access.
- A bare `fetch()` in a client component body (use the SSR-aware fetcher, or `use()` on a server-passed promise).
- Non-deterministic values in render output with no transfer and no scoped suppression.
- An environment check that changes the returned markup.
- Suppression applied to a container instead of the differing leaf.
- Reading tenant from browser state during SSR.

## Related

- `data-fetching.md` — use the framework's SSR-aware fetcher for the initial read; this pattern owns hydration safety, data-fetching owns client-side refetch/dedup/cancellation after hydration.
- `rendering-strategy.md` — decides whether the route is server-rendered at all, and owns the static-export case where per-request values simply do not exist.
- `error-boundaries.md` — a hydration mismatch is a distinct error class; fix it at the source here, the boundary only contains the client-side throw.
- `auth-session-client.md` — the session is the classic per-request value: server-rendered as one user, hydrated as another (or as anonymous) is a hydration mismatch with a security shape.
- `ssr-audit` (skill) — the sweep that executes the detectors above.
- `streaming-ssr` (skill) — the speed axis of the same render; a streamed boundary does not change any rule on this page.
- `.claude/rules/frontend-principles.md` — the SSR/hydration MUSTs this pattern elaborates.
