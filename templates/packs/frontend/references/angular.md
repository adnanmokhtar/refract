# Angular reference (17+, standalone + signals)

> **Framework**: Angular 17+ / 18 / 19 • TypeScript 5.4+ • RxJS 7.8+
> **Official docs**: https://angular.dev/
> **Version-specific gotchas**: Angular 17 made standalone components default + new control flow (`@if` / `@for` / `@switch`); 17.1 added typed forms inferred from values; 18 stabilized signals + zoneless change detection (preview); 19 promoted standalone components to required default; deferred views (`@defer`) for code-splitting; `inject()` function preferred over constructor DI in new code.
> **Substitution markers**: Replace `<name>` / `<feature>` with the project's actual feature names.

## Machine-readable docs (check these before trusting this file)

Angular ships **no documentation inside the installed package** — verified against `@angular/core@22.1.3`, whose
published tarball carries 105 files and no docs directory. The hosted docs track *latest*, not what is in your
`package.json`; reconcile the two before you trust an API.

- **Index**: `https://angular.dev/llms.txt` (~7 KB) — the cheap first read.
- **Full text**: `https://angular.dev/assets/context/llms-full.txt` (~775 KB), which the Angular AI guide
  describes as the robust compiled set. Grep it; do not read it into context wholesale.
- **LLM-targeted guidance**: `https://angular.dev/assets/context/best-practices.md` (~2.8 KB) and
  `https://angular.dev/assets/context/guidelines.md` (~4.8 KB) are written to steer a model toward idiomatic
  modern Angular. The guidelines file is what Angular tells you to drop into `.github/copilot-instructions.md`
  or an equivalent rules slot. Note these are *generic* Angular opinion and do not override this pack's rules
  where the two differ — this file and `rules/frontend-principles.md` win on house conventions.
- **No per-page Markdown, and the failure is silent.** Appending `.md` to a page URL returns **HTTP 200 with
  `text/html`** — the Angular site's SPA shell, not documentation. A status-code check will report success while
  handing you an empty app shell, so do not build a fetch loop on that pattern; use the files above.

Angular also ships an **experimental** Angular CLI MCP server (`angular.dev/ai/mcp`). Experimental is the
official word for it, so treat anything it returns as advisory, not as a settled API contract.

Same rule as everywhere in this directory: hosted docs are the **API surface**, this file is the **house
opinion** (standalone by default, `OnPush` everywhere, new control flow, `provideClientHydration()`). Where the
two disagree about an API, the docs win and this file is stale — say so rather than emitting the older call.
Where the network is unavailable, this file is what you have; it does not halt.

## Structure

```
src/app/
├── core/                     # singletons — guards, interceptors, core services
├── shared/                   # reusable components, pipes, directives
├── features/
│   └── <name>/
│       ├── pages/            # route-level components
│       ├── components/       # feature-scoped components
│       ├── services/         # feature services (HTTP)
│       ├── store/            # signals / NgRx / signalStore
│       ├── models/           # DTOs, types
│       └── <name>.routes.ts
├── app.config.ts             # providers (HttpClient, Router, env)
└── app.routes.ts
```

## Rules (17+)

- Standalone components by default — no `NgModule` unless forced.
- Use `@Component({ standalone: true, imports: [...] })`.
- Use `@if` / `@for` / `@switch` — new control flow, NOT `*ngIf`/`*ngFor`.
- Signals for local reactive state: `signal()`, `computed()`, `effect()`.
- Use `inject()` function instead of constructor DI for concise DX — consistent with project convention.
- `ChangeDetectionStrategy.OnPush` for every component.

## Forms

- Reactive forms for anything beyond trivial.
- Typed forms (`FormGroup<MyFormShape>`).
- Validators composed — don't inline regex everywhere.

## HTTP

- `HttpClient` behind a feature service.
- Interceptors for auth + error + correlation id.
- `toSignal(obs)` to bridge observables into signal-based components.
- RxJS for streams; prefer `firstValueFrom` when you need a one-off promise.

## Routing

- Lazy-load every feature route: `loadChildren: () => import('./...')`.
- Route guards are functions (`canActivate: [authGuard]`), not classes (deprecated).
- Preload lazy chunks after initial load: `provideRouter(routes, withPreloading(PreloadAllModules))`, or a custom `PreloadingStrategy` / network-aware `quicklink` (`ngx-quicklink`) so the next route's chunk is already fetched on navigation.

## Deferred views & images

- `@defer` to lazy-load a block's chunk on a trigger: `(on viewport)`, `on idle`, `on interaction`, `on hover`, `on timer(2s)`. Pair with `@placeholder`, `@loading (minimum 500ms)`, and `@error` blocks. Add `prefetch on idle` to fetch the chunk early without rendering it yet.
- `NgOptimizedImage`: use `ngSrc` (not `src`) with required `width`/`height`; set `priority` on the LCP image — it emits a preload `<link>` + `fetchpriority=high` so the hero loads first.

## SSR & hydration

- SSR via `@angular/ssr` (`provideServerRendering()`); enable hydration with **`provideClientHydration()`** — without it Angular re-renders and destroys the server DOM (flicker + CLS).
- **Incremental hydration (v19)**: `withIncrementalHydration()` + `@defer (hydrate on viewport | interaction | idle)` hydrates blocks lazily, cutting TBT / INP.
- SSR is **mandatory** for `Title` / `Meta` / JSON-LD to reach crawlers — a client-only Angular app ships an empty shell. Resolve route data server-side. See `frontend/skills/ssr-audit/SKILL.md`.

## SEO

- Set metadata via the **`Title`** and **`Meta`** services (`title.setTitle()` / `meta.updateTag()`), ideally in a route resolver so it's server-rendered. Emit unique title + description, canonical, OG/Twitter, and JSON-LD (inject a `<script type="application/ld+json">`). One mechanism only. See `frontend/skills/seo-audit/SKILL.md` + `@technical-seo`.

## Fonts

- No framework font primitive — self-host `@font-face` (or `@fontsource/*`): `font-display: swap`; preload the critical font (`<link rel="preload" as="font" crossorigin>` in `index.html`); size-adjusted fallback (swap-CLS); woff2-first; variable font over ≥3 weights. See `frontend/skills/font-optimization/SKILL.md`.

## Testing

- Jest (preferred) or Karma+Jasmine.
- Component tests via `@testing-library/angular` or `TestBed`.
- Test signal updates via `fixture.detectChanges()`.

## Anti-patterns

- `*ngIf` / `*ngFor` when `@if`/`@for` is available
- NgModule when standalone would do
- Subscription leaks — use `takeUntilDestroyed()` or `async` pipe
- Manual `subscribe()` without cleanup
- Business logic in templates
- Lazy routes with no `PreloadingStrategy` on a fast network — chunks fetch only on click
- Raw `<img src>` instead of `ngSrc` (`NgOptimizedImage`)
- No `priority` on the LCP image — hero loads late, LCP regresses
