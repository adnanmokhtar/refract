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
> reference. The mechanism for doing that is the next section — on 16.2+ the matching docs are already on disk.

## Read the installed docs before you read this file

Next ships its own documentation **inside the package**. Where it is present it **outranks this file**, because it
is version-matched to the exact `next` in `package.json` while this file is a hand-maintained snapshot that
drifts — as the scope note above concedes, this pack has already proved that on itself. Restating an API from
memory is how a reference emits a deleted call; routing to the installed copy is how it stops.

**Precedence ladder — stop at the first rung that resolves:**

1. **`node_modules/next/dist/docs/`** — bundled Markdown, no network, always matching the installed version.
   Verified in `next@16.3.1`: 444 `.md` files (~3.0 MB) under `01-app/`, `02-pages/`, `03-architecture/`,
   `04-community/`, plus `index.md`. The tree mirrors the docs site, so the page at `/docs/app/guides/<topic>`
   is `01-app/02-guides/<topic>.md`. Resolve it **from the file that sent you, not the repo root** — in a
   monorepo the `next` package may not be visible from the root.
2. **Hosted Markdown** — append `.md` to any page URL under `nextjs.org/docs` (returns `text/markdown`; an
   `Accept: text/markdown` request header does the same), indexed by `/docs/llms.txt`. Use this rung when the
   docs are not bundled, and for the per-error pages under `/docs/messages`, which are **not** bundled. It
   tracks *latest*, not your installed version — reconcile against `package.json` before trusting an API.
3. **This file** — the fallback. See "What this file is still for" below.

`/docs/llms-full.txt` also exists, but it is a single ~3.9 MB file: treat it as a download for grepping, not
something to read into context. Prefer the index plus the one page you need.

**Which rung you land on is decided by the installed major.** Read it from `package.json` first:

| Installed | Bundled docs | `AGENTS.md` |
|---|---|---|
| **16.3+** | yes | `next dev` auto-generates `AGENTS.md` + `CLAUDE.md` when it detects a coding agent in the environment; `create-next-app` also generates both (`--no-agents-md` opts out) |
| **16.2** | yes | not generated — write it yourself, pointing at `node_modules/next/dist/docs/` |
| **16.1 and earlier, incl. 14 / 15** | **no** | `npx @next/codemod@canary agents-md` downloads a version-matched copy to `.next-docs/` and indexes it; otherwise fall through to rung 2 |

**The generated block is managed, not yours.** It is fenced by `<!-- BEGIN:nextjs-agent-rules -->` /
`<!-- END:nextjs-agent-rules -->`; content outside the markers survives the upsert, and the generated
`CLAUDE.md` is a single `@AGENTS.md` line. Deleting the block from a diff only re-creates it as an uncommitted
change — commit it and put project-specific instructions outside the markers. Opt out with `agentRules: false`
in `next.config.ts`. (Verified against the shipped implementation, not just the guide: `next@16.3.1` contains
`dist/server/lib/generate-agent-files.js`, which defines exactly those two markers, strips the legacy
`<!-- NEXT-AGENTS-MD-START -->` pair on upsert, and writes that `CLAUDE.md` body.)

**Why the routing is worth these lines.** Vercel's own evaluation, on Next 16 APIs absent from model training
data, measured 53% baseline, 79% with Skills carrying explicit instructions, and **100%** with an ~8 KB
`AGENTS.md` docs index (compressed from a ~40 KB first attempt). Their stated reason is that a docs index is
passive context with "no decision point" — present every turn, where a skill must first be chosen and loaded.
(Source: nextjs.org/docs/app/guides/ai-agents, and vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals.)

**When this does NOT apply.** No `node_modules` (fresh clone, docs-only task, offline), a pinned pre-16.2 major,
or a monorepo where `next` does not resolve from where you are. Then rung 1 is simply unavailable — fall to
rung 2, and to this file. The ladder degrades; it does not halt.

**What this file is still for.** The bundled docs are the *API surface*; they will not tell you which lever this
pack wants pulled. The judgement stays here — the anti-patterns list, "never a raw `<img>` for app-owned
images", the LCP-priority boundary this file shares with the `lcp-audit` skill. So: **API shape from the
installed docs, judgement from here.** Where the two disagree about an API, the docs win and this file is stale
— say so in the diff rather than quietly emitting the older call.

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
