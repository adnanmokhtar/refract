# Next.js reference (App Router, 14 / 15)

> **Framework**: Next.js 14 / 15 on Node 18.18+ • React 19+ (Next 15) / 18 (Next 14)
> **Official docs**: https://nextjs.org/docs
> **Version-specific gotchas**: Next 14 default `fetch` cache was `force-cache`; **Next 15 default is `no-store`** — ALWAYS set `cache:` + `next.revalidate` explicitly (see "Data fetching"). Next 15 also makes `cookies()` / `headers()` / `params` / `searchParams` async (must `await`); Turbopack stable for `dev`; Server Actions cookie-set restrictions tightened.
> **Substitution markers**: Replace `(marketing)` / `<name>` with the project's actual route groups + module names.
> **Scope, stated honestly**: this file is written against **14 / 15**. Next **16** exists and removed APIs named
> below. Only ONE 16 delta has been verified against a primary source in this pack — the PPR → Cache Components
> move recorded under "Navigation & streaming" (source cited there, and enforced by the `streaming-ssr` skill).
> The rest of this file has NOT been re-audited against 16. So: read the `next` major from `package.json` before
> you emit any config-level or route-segment API from here, and if it is 16+, verify the call against the
> installed version's docs rather than trusting this page. A reference that emits a deleted API is worse than no
> reference.

## Structure

```
app/
├── (marketing)/              # route groups
│   └── page.tsx
├── api/                      # route handlers
│   └── <name>/route.ts
├── layout.tsx
├── error.tsx
├── loading.tsx
└── not-found.tsx
components/
lib/                          # shared utils, db, auth
```

## Server vs Client

- Default to Server Components. Add `'use client'` ONLY when a component needs state / effects / browser APIs.
- Server Components can fetch directly (`async function Page() { const data = await fetch() }`).
- Client Components receive server data via props — don't re-fetch on client.
- Never pass non-serializable props from Server → Client (functions, class instances).

## Navigation & streaming

- `<Link href>` auto-prefetches on viewport entry in prod; set `prefetch={false}` for low-value links. Default prefetch is **partial** (full for static routes, partial for dynamic). Never hand-roll `<a>` for internal nav.
- `loading.tsx` wraps a segment in `<Suspense>` and streams a fallback instantly.
- Wrap slow subtrees in `<Suspense fallback>` to stream them independently.
- **Static shell + dynamic holes** — the shape is stable across majors, the enable line is NOT. Read the `next`
  major from `package.json` first:
  - **15**: `export const experimental_ppr = true` on the segment + `experimental: { ppr: 'incremental' }` in `next.config`.
  - **16+**: both of those were **removed**; use Cache Components — `cacheComponents: true` in `next.config`, then
    mark the cacheable shell with the `"use cache"` directive and wrap each dynamic hole in `<Suspense>`.
    Emitting the 15 form against a 16+ project is a build failure, not a warning.
    (Source: the Next.js 16 release notes list `experimental.ppr` and `export const experimental_ppr` in the
    Removals table, superseded by Cache Components — nextjs.org/blog/next-16, published 2025-10-21.)
  Either way the payoff is the same: the static shell prerenders and serves instantly, and only the dynamic holes
  (anything reading `cookies()` / `headers()` / `searchParams`) stream. Detector: a `dynamic = 'force-dynamic'`
  route with a large static header/footer is a candidate. The enable is a config + boundary decision — the
  `streaming-ssr` skill §5 owns the version gate and halts if it is emitted without reading the major.
- `next/dynamic(() => import(...), { ssr: false })` for heavy client-only widgets — **only from inside a Client
  Component**. The Next docs state the `ssr: false` option "is not supported in Server Components. You will see an
  error if you try to use it in Server Components." Same caveat in `ai/patterns/code-splitting.md`.
- Parallel routes `app/@modal/...` + intercepting routes `app/(.)photo/[id]`.
- `useRouter().prefetch()` to warm a route ahead of an imperative navigation.

## Data fetching

- Server Component: `await fetch(..., { cache: 'force-cache' | 'no-store' })` with revalidate tags.
- Client Component: TanStack Query or SWR, hitting Route Handlers.

## Actions / mutations

- Server Actions (`'use server'`) for form submissions / mutations.
- Validate server action inputs with zod.
- Use `revalidatePath` / `revalidateTag` after mutation.

## SEO

- `generateMetadata` on every page.
- OpenGraph + Twitter card metadata.
- Structured data for pages that benefit.

## Images

- `next/image` always — never raw `<img>` for app-owned images.
- Explicit `width` + `height` or `fill` + container sizing.
- `<Image priority>` on the LCP image emits `fetchpriority="high"` + `loading="eager"` (in Next 15 the preload `<link>` emission is reduced/conditional — do NOT assume it always emits one); forbidden on below-the-fold images.

## Core Web Vitals levers

- `next/font` with `display` + `preload` to avoid CLS / FOIT (self-hosts + size-adjusts the font).
- `useReportWebVitals` hook to ship field metrics (INP / LCP / CLS) to RUM.
- `generateMetadata` preload `<link>` for the LCP resource.
- **103 Early Hints** is a HOST/CDN feature (Vercel / Cloudflare emit `Link: rel=preload` / `rel=preconnect` before the `200`) — Next's document-level `<link rel=preload>` tag injection is a SEPARATE, complementary lever, NOT a `103` emitted by `next.config`; don't conflate them.
- `Cache-Control: stale-while-revalidate` to serve a cached document instantly while revalidating.

## Anti-patterns

- `'use client'` everywhere (defeats the point of App Router)
- Fetching on client when server could do it
- Non-serializable props across boundary
- Forgetting `revalidatePath` after mutation (stale data)
- Raw `<img>` for app-owned images
- Raw `<a>` for internal links (kills prefetch + soft nav)
- No `priority` on the LCP image
