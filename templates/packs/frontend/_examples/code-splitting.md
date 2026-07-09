---
name: code-splitting
kind: example
pack: frontend
---

# Pattern: Code Splitting

> **Hard rule:** The initial bundle ships ONLY what first paint needs. Every route is a split point, and any heavy dependency not needed above the fold (rich-text editor, chart/viz lib, map SDK, PDF/video player, locale-heavy date-picker) is lazy-loaded behind a dynamic import with a Suspense/fallback boundary. A monolithic bundle, or an eager top-level import of a heavy below-the-fold dep, is forbidden. Every claim cites `<file:line>` + the import + the fix.

**Ownership boundary.** This pattern decides **WHAT** to split and **HOW** the chunk boundary is drawn. `bundle-analyze` (skill) **MEASURES** chunk names + gzipped sizes and names the heavy dep; this pattern decides where to cut it. Cross-pack `lazy-loading` owns non-JS deferral (images, scripts, hydration) — hand off, don't re-derive.

## What to split, and the traps

- **Route-based** — the highest-leverage cut: a visitor on `/` never downloads `/settings`. Meta-frameworks (Next/Nuxt/SvelteKit/Angular routes) auto-split — verify it happens; a client SPA must do it explicitly.
- **Component-based** — modal/drawer bodies, inactive tabs, below-fold sections, admin widgets; the heavy dep travels in the component's chunk.
- **Over-splitting** is its own anti-pattern — dozens of <5 KB chunks become a request waterfall; group vendor + co-used code via `manualChunks`/`splitChunks`.
- **Barrel-file trap** — `import { x } from 'huge-lib'` can pull the whole lib; prefer deep/subpath imports or the framework's package-import optimizer.
- **Never lazy the LCP subtree** — a chunk round-trip before paint; hand off to `lcp-audit`.

## Fallback + failure are mandatory

Every dynamic import pairs (1) a Suspense/fallback that reserves layout (no CLS) with (2) an **error boundary** catching the chunk-load rejection (offline / redeployed hashed chunk 404) offering retry/reload. A naked `lazy()`/`import()` with no fallback and no failure path is a bug.

## Adapt to the codebase

Mirror the router + bundler already in the repo; never add a second mechanism.

| Stack | Lazy primitive | Route auto-split? | Manual chunking |
|---|---|---|---|
| **React (SPA)** | `lazy(() => import())` + `<Suspense>` | No — explicit | bundler |
| **Next.js** | `next/dynamic` | Yes | `optimizePackageImports`; `splitChunks` |
| **Vue (SPA)** | `defineAsyncComponent` | No — async route components | Vite/Rollup |
| **SvelteKit / Nuxt** | route auto-split + `import()` | Yes | Vite `manualChunks` |
| **Angular** | `loadComponent`/`loadChildren` | Yes | builder budgets + `namedChunks` |

## Detectors (cite-or-halt)

1. **Heavy dep imported eagerly at module top, used only below fold/in a modal** — defer behind the open handler.
2. **Routes not split — every page in the entry chunk** — convert static route imports to dynamic.
3. **`lazy`/`dynamic` with no Suspense/fallback** — no loading boundary.
4. **Lazy import with no error boundary for chunk-load failure** — rejection leaves the UI on a stale skeleton.
5. **Barrel import pulling a whole lib** — rewrite to subpath / enable the optimizer.

## Related

- `bundle-analyze.md` (skill) — the measurement sibling: names the heavy chunk + gzipped size; split proposals cite its output.
- `lcp-audit.md` (skill) — the LCP-critical path must never be lazy; detector 7 hands off there.
- `error-boundaries.md` — the boundary that catches a lazy chunk-load failure (detector 4's failure path).
- `navigation-speed.md` (skill) — owns prefetching the likely-next route's chunk on hover/idle.
- `rendering-strategy.md` — the initial-render axis; keep it consistent with the code-split boundaries.
