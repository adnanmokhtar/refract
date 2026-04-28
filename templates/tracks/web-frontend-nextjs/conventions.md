---
track: web-frontend-nextjs
purpose: Stack-specific MUST / MUST-NOT rules for Next.js projects, with project-anchored RATIONALE.
imported-by: templates/tracks/web-frontend-nextjs/pack.md (emitted into ai/conventions/web-frontend-nextjs.md).
---

# Conventions — Next.js

## App Router (default for Next 13+)

- **MUST** colocate route-specific code under `app/<route>/{page,layout,loading,error}.tsx` rather than spreading across separate trees.
  - **Rationale:** Next's routing contract; deviating breaks framework discovery + nested layouts.
- **MUST** mark client-only files with `"use client"` at the top. Server is the default.
  - **Rationale:** silent server-rendering of client-only hooks raises confusing errors.
- **MUST NOT** import server-only utilities (DB clients, secrets) into a `"use client"` file.
  - **Rationale:** bundles secrets to the browser. The bundler does NOT always catch this.

## Pages Router (when present)

- **MUST** keep `_app.tsx` and `_document.tsx` minimal — they run on every page.
- **MUST** use `getServerSideProps` only when data MUST be per-request; prefer `getStaticProps` + `revalidate` otherwise.

## Server Actions (App Router)

- **MUST** mark Server Actions with `"use server"` at the top of the function body or file.
- **MUST** validate input at the action boundary (Zod or equivalent) — actions are a public RPC surface.
- **MUST NOT** trust `formData` directly without parsing.

## Data fetching

- **MUST** use Next's `fetch()` with explicit `cache:` and `next.revalidate` settings — defaults change between Next versions.
  - **Rationale:** Next 14 default was force-cache; Next 15 default is no-store. Implicit reliance on defaults breaks on upgrade.
- **MUST** prefer parallel fetches via `Promise.all` over sequential `await` of independent calls.
  - **Rationale:** the most common LLM-authored Next perf failure.

## Styling

- **MUST** use one styling system per project — pick CSS Modules, Tailwind, styled-components, or vanilla-extract; do not mix.
- **MUST NOT** import global styles outside `app/layout.tsx` (App Router) or `_app.tsx` (Pages Router).

## Components

- **MUST** colocate a component's stylesheet, test, and types in the same directory.
- **MUST** prefix client components with descriptive names (e.g., `UserMenuClient.tsx` when there's a server counterpart).
- **MUST NOT** export React Server Components from the same file as client components — separate files.

## Images + assets

- **MUST** use `next/image` for any image larger than ~100KB.
  - **Rationale:** unoptimized `<img>` shifts layout (CLS) and ships full-resolution to small viewports.
- **MUST NOT** import images from `public/` via JS — reference by path string in `<Image src="/foo.png">`.

## Routing

- **MUST** define dynamic segments with `[param]` for required, `[[...param]]` for optional catch-all.
- **MUST** put auth gates in middleware (`middleware.ts`), not in every page.

## Testing

- **MUST** use Playwright or Cypress for end-to-end; Jest or Vitest for unit; React Testing Library for components.
- **MUST NOT** test Server Components by mounting them in jsdom — they render server-only. Use Playwright instead.

## Environment variables

- **MUST** prefix browser-exposed envs with `NEXT_PUBLIC_`. Anything else stays server-only.
- **MUST** validate envs at boot (e.g., `t3-env`); silent missing-env failures cost hours.

## Project-specific anchors

(Phase 4.6 will populate this with the project's actual styling system, env validator, route conventions, and ESLint config.)
