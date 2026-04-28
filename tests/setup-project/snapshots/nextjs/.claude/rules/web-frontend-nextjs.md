<!-- setup-project:managed start id=web-frontend-nextjs.claude.rules.web-frontend-nextjs v=1.0.0 track=web-frontend-nextjs -->
# Next.js rules

These rules ship when the `web-frontend-nextjs` track is selected. They sit alongside the universal `repo-baseline` rules.

## Server vs client component discipline

- A file with hooks (`useState`, `useEffect`, `useRouter`, etc.) MUST start with `"use client"`.
- A file with server-only deps (DB clients, file-system, secrets) MUST NOT carry `"use client"` and MUST NOT be imported by a client file.
- The boundary lives in props: pass primitives + plain JSON across the boundary, not class instances.

## Server Action discipline

- Mark with `"use server"`; validate every input.
- Never log raw `FormData`. Sanitize first.
- Wrap risky operations in `revalidatePath` / `revalidateTag` so caches stay consistent.

## Cache discipline

- Be explicit about `fetch()` cache settings. Implicit defaults change between Next versions.
- Use `cache()` from React for memoization within a single render.
- Use `unstable_cache` from Next for cross-request caching with explicit tags.

## Data parallelism

- Independent `await` calls = `Promise.all`. Sequential `await` of independent I/O is a perf bug.
- Use Next's streaming + Suspense boundaries to ship UI progressively.

## Image discipline

- `next/image` for any image, with `width` + `height` set OR `fill` with a positioned container.
- Use `priority` on the LCP image (typically the hero).

## Project-specific anchors

(Phase 4.6 will inject the project's actual `next.config` settings, ESLint rules, and styling system here.)
<!-- setup-project:managed end -->
