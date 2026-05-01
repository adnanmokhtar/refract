# Next.js reference (App Router, 14 / 15)

> **Framework**: Next.js 14 / 15 on Node 18.18+ • React 19+ (Next 15) / 18 (Next 14)
> **Official docs**: https://nextjs.org/docs
> **Version-specific gotchas**: Next 14 default `fetch` cache was `force-cache`; **Next 15 default is `no-store`** — ALWAYS set `cache:` + `next.revalidate` explicitly (see "Data fetching"). Next 15 also makes `cookies()` / `headers()` / `params` / `searchParams` async (must `await`); Turbopack stable for `dev`; Server Actions cookie-set restrictions tightened.
> **Substitution markers**: Replace `(marketing)` / `<name>` with the project's actual route groups + module names.

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

## Anti-patterns

- `'use client'` everywhere (defeats the point of App Router)
- Fetching on client when server could do it
- Non-serializable props across boundary
- Forgetting `revalidatePath` after mutation (stale data)
- Raw `<img>` for app-owned images
