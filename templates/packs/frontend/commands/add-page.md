---
description: Scaffold a page/route with view, store slice, service, types, i18n keys, and tests.
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses Vue 3 + PrimeVue + TypeScript for illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# /add-page <route>

Scaffolds a new top-level route or sub-route, mirroring an existing page in the same area. Lazy-loads if the repo's convention says so.

## Phases applied

All 7. Standard build/add command.

## The Premise (read this first, internalize, do not deviate)

**Existing siblings are the truth.** Every page in the same area is the intentional shape — its routing entry, its layout import, its data-fetch call site, its loading/error/empty states, its permission gate, its lifecycle hook, its locale-key path. New pages copy that shape silently.

**The agent's job is exactly this:**
1. Find ≥2 sibling pages in the same area (same module, same `pages/`/`views/`/`app/` subtree).
2. Mirror their structure: composables (`useCrud`, `useForm`), Base*-wrappers (`<BaseModal>`, `<BaseForm>`, `<CrudPaginator>`), `onActivated` for KeepAlive caching (NOT `onMounted`), shared service-layer (`BaseCrudService`), permission-gate import, locale-key naming, lazy-load convention.
3. Add only the delta the new page actually needs. Everything else: copy the sibling shape silently.

**The agent ONLY asks the user when:**
- **No sibling page exists** in the area (truly new shape — first list page, first wizard, first chart panel).
- **State location is genuinely ambiguous** (no sibling answers it — page-local vs store).
- **New permission gate** (route requires a role/scope that no sibling uses).

Everything else — loading/empty/error state shape, lazy-load wrapper, i18n key naming, lifecycle hook, default-true wrapper props — is silent sibling-mirror.

**Prior-art gate (all tiers):** before scaffolding, search by **behaviour, not name** — does an existing route/page already cover this user-facing capability under another name? Near-duplicate found → **HALT**: surface it (route + what it does) and ask extend / replace / deliberate parallel. (Inherited from `/add-feature` when invoked via it; runs mechanically when called standalone.)

**New-dependency gate (all tiers):** a package **no sibling already imports** needs justification + **bundle-size delta** (gzipped, tree-shakeable?) before it lands — a platform API or already-present primitive is preferred by default. **HALT** on an unreviewed new dependency; no silent `npm install`.

**Closure-verb table — page complexity → ceremony:**

| Tier | Trigger | Ceremony | Default? |
|---|---|---|---|
| **Trivial** | New page that mirrors an existing sibling (list, detail, settings tab) | Code only — page + service + types + locale keys (BOTH locales). Tests required. **No plan, no ADR.** | YES |
| **Standard** | New shape that needs 1 new composable OR a new shared loading/empty primitive | Trivial + 1-paragraph sibling-shape note inline | NO |
| **Heavy** | New routing pattern (multi-route flow, dynamic segment shape, SSR vs CSR switch on this route family) | Standard + ADR + `@ui-reviewer` + `@accessibility-auditor` cascade | NO |

**Lightweight default.** Trivial-tier is the default. Drafting an ADR for a sibling-mirror page is the same anti-pattern as the migration pack's "ADR-as-closure" trap.

## When to use / NOT to use
- USE: new top-level route; new tab/sub-route inside an existing section.
- NOT: modal/drawer (use `/add-component`); shared layout fragment (`/add-component` or compose in existing page).

## Phase 1 — Understand

### Intent gate

If description suggests a different intent, halt with redirect: "enhance / improve / polish / cleaner" → `/enhance-ui` *(ui-ux pack)*. "fix / broken / wrong" → `/fix-bug` (core). "audit / review" → `/design-review` *(ui-ux pack)*, or this pack's `/a11y-audit` / `/i18n-audit` when the ask names that axis. Proceed only for adding a new page.

**A redirect must land somewhere.** Both ui-ux destinations exist only when that pack is co-installed — check first, and if it is absent offer `/polish` (core) for visual finish and `/audit` (core) for read-only review instead of halting into a command the project does not have.

### Standard inputs

- Parse `<route>` arg.
- Consolidated question if missing: page purpose, data dependencies, required permissions.
- Success: route renders skeleton + loading + error + empty states; i18n keys exist in every locale; tests cover render + fetch + interaction.

## Phase 2 — Organize

- Detect framework (see Phase 3) — file layout depends on it.
- Sub-tasks: route file, page component, loading/error states, store slice (if shared), service method, DTO type, i18n keys, tests.
- Pause for confirmation on state-location decision (page-local vs store) before writing files.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

**MUST read** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) before generating code.

Page-specific (signal-based, on top of the universal block):
- `ai/patterns/` — the page pattern, `data-fetching.md`, `i18n.md`, and `rendering-strategy.md` for this route's strategy.
- `references/<framework>.md` — routing + metadata primitives for the detected framework.

Detect framework:
- `app/` directory with `page.tsx` → Next.js App Router.
- `pages/` with `*.tsx` → Next.js Pages Router.
- `pages/` with `*.vue` → Nuxt.
- `src/views/` + `vue-router` → Vue Router.
- `src/app/.../*.component.ts` → Angular.
- `src/routes/+page.svelte` → SvelteKit.

EXISTING CODE — read one existing page in the same area to mirror routing + state + service patterns.

## Phase 4 — Generate

Dispatch `ui-architect` for the file list + state location decision (page-local vs store).

Generate:
- Page/view file with skeleton + loading state + error state + empty state.
- Route entry (config or file-system depending on framework).
- Store slice if state is shared (and the repo uses a store for similar pages).
- Service method(s) typed against shared DTO location.
- i18n keys in EVERY locale file the repo declares.
- Tests: render + data fetch (mocked) + interaction.

Fast-by-default (mirror siblings; framework specifics → `references/<framework>.md`):
- An instant, layout-stable loading state (no CLS) — skeleton mirroring the loaded shape, NOT a spinner or blank.
- Primary inbound nav links to this route prefetch via the framework primitive (mirror siblings; the `navigation-speed` skill owns the audit).
- If the route is SSR and its above-the-fold does NOT depend on a slow query, slow regions stream behind a Suspense/await boundary (the `streaming-ssr` skill owns the boundary placement).
- If the route has a hero / above-the-fold LCP image, set the framework priority hint (the `lcp-audit` skill owns the detectors).
- If the route is public / indexable, generate its metadata via the project's own primitive (`generateMetadata` / `useSeoMeta` / `<svelte:head>` / `Title`+`Meta`): unique title + description, self-referencing canonical, OG/Twitter, and page-appropriate JSON-LD; localized routes add reciprocal `hreflang`. Mirror how sibling routes do it (the `seo-audit` skill owns the sweep; `@technical-seo` owns the judgment calls). A public route that is CSR-only is a rendering-strategy fix first.
- Content images use the framework image component — modern format, `srcset`/`sizes`, explicit `width`/`height` (no CLS), lazy below the fold (the `image-optimization` skill); a new / critical web font sets `font-display` + is self-hosted (the `font-optimization` skill).

### Sibling-shape mechanical halt (mandatory, all tiers)

Before declaring success, compare the new page against ≥2 sibling pages in the same area. For each gap, return one of: `closed` (matches sibling shape), `still-open` (divergent), `regressed` (introduced a new break on an unrelated axis).

**Halt if any of:**

- Uses raw framework components where Base*-wrappers exist — raw `<Dialog>` instead of `<BaseModal>`, raw `<Paginator>` instead of `<CrudPaginator>`, raw `<form>` instead of `<BaseForm>`.
- Uses `onMounted` instead of `onActivated` on a route page when siblings cache across navigation (KeepAlive cache divergence — silent re-mount).
- Doesn't use the project's gold-standard composable (`useCrud` for list pages, `useForm` for forms) when siblings do.
- i18n keys present in pivot locale but missing in declared alt locales (`en.ts` ✓, `ar.ts` ✗) — silent break.
- Default-true wrapper props left implicit when affordances should be hidden — pass `:show-delete="false"` / `:can-edit="false"` explicitly.
- New file placed outside the area's path convention (e.g., `pages/orders/NewOrder.vue` when siblings live at `views/orders/Form.vue`).
- Lazy-load convention diverges from siblings (sibling pages use `defineAsyncComponent` / dynamic-import; new page is statically imported, or vice versa).
- Inbound nav links to the new route don't prefetch where siblings' equivalents do (and there's no documented prefetch=off).
- Loading state missing or not layout-stable (spinner / blank / CLS) where siblings paint a skeleton.
- SSR route blocks TTFB on a below-the-fold query when siblings stream the shell behind a Suspense/await boundary.
- An unconditional `unload` / `beforeunload` listener was introduced (bfcache evictor) where it should be `pagehide`.

**Hard rule:** `gap_count_in != gap_count_closed` → HALT. Surface the open list and ask the user: refix, escalate to next tier, or accept. Any `regressed` → HALT.

## Phase 5 — Update

- `ai/status.md` — prepend Recent Changes entry.
- `ai/dynamic/changelog.md` — append one-line summary.
- `ai/modules.md` — add row if new module/feature area.
- `locales/<each>/<area>.json` — i18n keys (already covered in Phase 4).

## Phase 6 — Validate

- Lint + typecheck on new files.
- Run tests scoped to new files.
- `visual-check` skill — render in dev server, confirm states (loading/empty/error).
- Verify i18n keys exist in every locale file declared in the repo.
- **Observability sign-off** (gated on what the project ships — check `.claude/codebase-profile.md` / `CLAUDE.md`): error boundary / error-tracking captures errors from the new route the way siblings wire it; route-level perf signal (web-vitals / RUM) + analytics events added if siblings of this surface emit them. Authoritative field INP arrives via `web-vitals-field` (Lighthouse lab INP is a synthetic proxy only). If the project ships NO observability layer: note `observability: none configured` in the report — explicit, never silent.
- **Fast-by-default dispatch:** run the `navigation-speed` skill on the new route (prefetch / bfcache / instant-loading); add `lcp-audit` if the route has a hero; add `streaming-ssr` if the route is SSR with a slow query.
- **SEO / asset dispatch (public routes):** run `seo-audit` (+ `@technical-seo`) on any public / indexable route — title/description/canonical/OG/JSON-LD/hreflang + SSR/prerender crawlability. Run `image-optimization` if the route renders content images; `font-optimization` if it introduces a web font. Non-public/admin route → `seo: n/a`.

## Phase 7 — Improve

- If the page introduced a new data-fetching shape, queue to `ai/dynamic/learned-patterns.md`.
- If permission gating diverged from existing pages, queue to `ai/dynamic/decisions-pending.md`.

## Output

```
Created:
  app/orders/page.tsx              page (lazy-loaded per repo convention)
  app/orders/loading.tsx           skeleton
  app/orders/error.tsx             error boundary
  src/services/orders.service.ts   list+get methods
  src/types/order.dto.ts           shared DTO
  locales/en/orders.json           +12 keys
  locales/ar/orders.json           +12 keys
  app/orders/__tests__/page.spec.tsx  4 cases
```

## Failure modes

- New HTTP client / form library / validation lib introduced "because it's nicer" — blocker; reuse what's there.
- Hardcoded copy — blocker; every visible string has an i18n key.
- Permission guards reinvented — copy from a sibling with similar permission needs.
- Loading/empty/error states omitted — required, not optional.
- Lazy-loading mismatch with sibling pages — hurts code-split coherence; mirror the convention.
- API URL hardcoded in component — services own that.
- Navigation into the new route doesn't prefetch / no instant layout-stable loading state — the page feels slow even when it's fast.

## Related

### Sibling commands — where the boundary falls
- `/add-component` — a modal, drawer or layout fragment is a component, not a route. § When to use / NOT to use already draws this line; running this command for one produces a route nothing navigates to.
- `/add-crud-page` — **supersedes** this command when the route is a list + form + delete bundle for one entity. Running both produces two competing shapes for the same entity.
- `/add-feature` — the caller, not an alternative. It invokes this command for the route step, and the prior-art + new-dependency gates above are inherited from it.
- `/a11y-audit` · `/i18n-audit` — read-only passes over what this command produced. They grade; they never scaffold.

### Skills this command dispatches (and when)
- `navigation-speed` — Phase 4 prefetch convention + the Phase 6 fast-by-default sign-off on the new route.
- `streaming-ssr` — Phase 4 / Phase 6, SSR routes with a slow query only: stream the shell, cut TTFB.
- `lcp-audit` — Phase 4 / Phase 6, routes with a hero or above-the-fold LCP image only.
- `seo-audit` (+ `@technical-seo`) — Phase 6, public / indexable routes only. Non-public → `seo: n/a`.
- `image-optimization` / `font-optimization` — Phase 6, gated on content images / a newly introduced web font.
- `visual-check` — Phase 6, renders the loading / empty / error states this command generated.

### Patterns actually read
- `rendering-strategy.md` — Phase 3, to pick this route's strategy before Phase 4 writes it.
- `data-fetching.md` — Phase 3, the call-site shape siblings already use.
- `i18n.md` — Phase 3, and the Phase 4 halt on keys present in the pivot locale but missing from a declared alt locale.

### Rules
- `.claude/rules/frontend-principles.md` — the route-prefetch, instant layout-stable skeleton, stream-the-shell and bfcache MUSTs that the Phase 4 halt list enforces one by one.
