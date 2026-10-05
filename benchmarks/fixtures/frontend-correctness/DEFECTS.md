# Seeded defects — `frontend-correctness`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `Harbor Market` — Next.js 16 App Router + React 19 grocery storefront (RSC, TanStack Query 5, Tailwind 4, next-intl en/ar), Vue 3.5 + Vite dispatch back office (Pinia, vue-i18n en/de, TanStack Vue Query, axios), Angular 22 partner widgets.
Rendering, SSR/hydration, client data-flow, routing, i18n, critical-path and bundle defects — the code-correctness
half of the frontend pack, `a11y-states`' sibling — seeded across both apps and the widgets, plus decoys: correct
siblings that look like a seeded defect and must NOT be reported.

Invocation: /frontend-audit --whole-repo --classes=render,ssr,data,routing,i18n,perf
Stage with: --git — `/frontend-audit` reads the history for its context map.

Eval source: Track A batch 3, item 48 (FX-2): `RC-01…05`, `SSR-01…04` (§ 2.4), `CD-01…07` (§ 2.5), `I18N-01…07`
(§ 2.6), critical path §1–§3 and bundle §6/§7 (§ 2.7). Routing (`routing-scan` §1, §3, §4, §6, §7) is added because the
task that built this fixture names `routing-scan` as a target and no fixture had a router to break.

What makes the fixture measure more than keyword recall: the seeds sit beside correct siblings in the same tree.
`StickyHeader` adds a scroll listener and never removes it; `ConsentScripts` and `KeyboardShortcuts` remove theirs.
`SearchBox` races its responses; `AddressLookup` aborts the previous request. `AddressForm` writes without
invalidating; `ReorderButton` invalidates through a shared helper whose name is not `invalidateQueries`. `c/[...slug]`
never 404s; `recipes/[[...tags]]` does. `lib/pricing.ts` reads a secret with no `server-only` guard; `lib/server/*`
import it. And two of the SSR seeds only show once the request model is understood: `lib/server/session.ts` keeps the
signed-in customer in a module variable that every concurrent request shares, and `products/[slug]` reads
`params.slug` synchronously, which Next 16 removed.

Ownership. `render-correctness-scan`, `ssr-audit`, `client-data-scan`, `routing-scan`, `i18n-scan` (with
`scripts/catalog-parity.py`), `critical-path-scan` and `bundle-analyze` (frontend pack). `CD-06` and `SSR-04b` are
cross-user data exposure: `/frontend-audit` routes them to the security pack when it is installed; a report in either
place counts.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap. If you edit fixture source, re-run it.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| FC-RC-01a | `apps/shop/components/account/OrderHistory.tsx:13` | medium | `/frontend-audit` | render/component-in-component |
| FC-RC-01b | `apps/shop/components/cart/BasketSummary.tsx:13` | medium | `/frontend-audit` | render/derived-state-in-effect |
| FC-RC-02a | `apps/shop/components/layout/StickyHeader.tsx:17` | medium | `/frontend-audit` | render/effect-no-cleanup |
| FC-RC-02b | `apps/admin/src/components/ColumnResizer.vue:12` | medium | `/frontend-audit` | render/effect-no-cleanup |
| FC-RC-03a | `apps/shop/components/cart/BasketLines.tsx:20` | medium | `/frontend-audit` | render/index-key-mutable-list |
| FC-RC-03b | `packages/widgets/src/angular/recipe-list.component.html:4` | medium | `/frontend-audit` | render/index-key-mutable-list |
| FC-RC-04a | `apps/admin/src/views/DispatchView.vue:17` | high | `/frontend-audit` | render/reactivity-loss |
| FC-RC-04b | `apps/admin/src/components/OrderCard.vue:11` | medium | `/frontend-audit` | render/mutated-prop |
| FC-RC-05a | `apps/shop/components/checkout/CouponInput.tsx:9` | medium | `/frontend-audit` | render/uncontrolled-to-controlled |
| FC-RC-05b | `apps/shop/components/account/AddressForm.tsx:38` | medium | `/frontend-audit` | render/value-from-prop |
| FC-SSR-01a | `apps/shop/components/product/SaleCountdown.tsx:7` | medium | `/frontend-audit` | ssr/hydration-nondeterminism |
| FC-SSR-01b | `apps/shop/components/product/ProductDescription.tsx:7` | high | `/frontend-audit` | ssr/invalid-nesting |
| FC-SSR-02a | `apps/shop/components/layout/ThemeToggle.tsx:7` | critical | `/frontend-audit` | ssr/browser-global-module-scope |
| FC-SSR-02b | `apps/shop/components/search/RecentSearches.tsx:8` | critical | `/frontend-audit` | ssr/browser-global-in-render |
| FC-SSR-03a | `apps/shop/components/checkout/DeliverySlots.tsx:17` | high | `/frontend-audit` | ssr/server-only-in-client |
| FC-SSR-03b | `apps/shop/lib/pricing.ts:6` | medium | `/frontend-audit` | ssr/missing-server-only |
| FC-SSR-04a | `apps/shop/app/[locale]/(shop)/products/[slug]/page.tsx:12` | high | `/frontend-audit` | ssr/sync-request-api |
| FC-SSR-04b | `apps/shop/lib/server/session.ts:4` | critical | `/frontend-audit` | ssr/module-state-cross-request |
| FC-CD-01a | `apps/shop/app/[locale]/account/orders/page.tsx:10` | medium | `/frontend-audit` | data/waterfall |
| FC-CD-01b | `apps/admin/src/stores/pickers.ts:8` | medium | `/frontend-audit` | data/n-requests |
| FC-CD-02a | `apps/shop/components/product/NotifyMeButton.tsx:15` | medium | `/frontend-audit` | data/fetch-bypasses-client |
| FC-CD-02b | `apps/admin/src/views/ReportsView.vue:14` | medium | `/frontend-audit` | data/fetch-bypasses-client |
| FC-CD-03a | `apps/shop/components/search/SearchBox.tsx:18` | medium | `/frontend-audit` | data/out-of-order-responses |
| FC-CD-03b | `apps/admin/src/views/CustomerSearchView.vue:12` | medium | `/frontend-audit` | data/out-of-order-responses |
| FC-CD-04a | `apps/shop/components/account/AddressForm.tsx:14` | medium | `/frontend-audit` | data/mutation-no-invalidation |
| FC-CD-04b | `apps/admin/src/views/PickersView.vue:13` | medium | `/frontend-audit` | data/mutation-no-invalidation |
| FC-CD-05a | `apps/shop/components/cart/QuantityStepper.tsx:15` | medium | `/frontend-audit` | data/optimistic-no-rollback |
| FC-CD-05b | `apps/admin/src/components/PriorityToggle.vue:12` | medium | `/frontend-audit` | data/optimistic-no-rollback |
| FC-CD-06a | `apps/shop/components/account/OrderHistory.tsx:11` | high | `/frontend-audit` | data/key-missing-input |
| FC-CD-06b | `apps/admin/src/stores/session.ts:14` | high | `/frontend-audit` | data/cache-kept-on-sign-out |
| FC-CD-07a | `apps/shop/components/account/OrderTracker.tsx:13` | medium | `/frontend-audit` | data/polling-in-background |
| FC-CD-07b | `apps/admin/src/components/LiveQueue.vue:11` | medium | `/frontend-audit` | data/polling-in-background |
| FC-I18N-01a | `apps/shop/components/marketing/Recommended.tsx:7` | medium | `/frontend-audit` | i18n/hardcoded-string |
| FC-I18N-01b | `apps/admin/src/views/OrdersView.vue:28` | medium | `/frontend-audit` | i18n/hardcoded-string |
| FC-I18N-02a | `apps/shop/messages/ar.json:49` | high | `/frontend-audit` | i18n/missing-key |
| FC-I18N-02b | `apps/admin/src/views/OrdersView.vue:27` | medium | `/frontend-audit` | i18n/key-undefined |
| FC-I18N-03a | `apps/shop/components/marketing/RecipeCard.tsx:10` | medium | `/frontend-audit` | i18n/manual-plural |
| FC-I18N-03b | `apps/admin/src/components/QueueSummary.vue:6` | medium | `/frontend-audit` | i18n/manual-plural |
| FC-I18N-04a | `apps/shop/components/product/PriceTag.tsx:2` | medium | `/frontend-audit` | i18n/manual-money |
| FC-I18N-04b | `apps/admin/src/components/DeliveryRow.vue:13` | medium | `/frontend-audit` | i18n/locale-less-date |
| FC-I18N-05a | `apps/shop/components/product/ProductCard.tsx:10` | medium | `/frontend-audit` | i18n/physical-css |
| FC-I18N-05b | `apps/admin/src/styles/app.css:37` | low | `/frontend-audit` | i18n/physical-css |
| FC-I18N-06a | `apps/shop/components/layout/CategoryNav.tsx:13` | medium | `/frontend-audit` | i18n/text-expansion |
| FC-I18N-06b | `apps/admin/src/styles/app.css:48` | medium | `/frontend-audit` | i18n/text-expansion |
| FC-I18N-07a | `apps/shop/app/[locale]/layout.tsx:31` | medium | `/frontend-audit` | i18n/html-lang-static |
| FC-I18N-07b | `apps/admin/src/components/LocaleSwitcher.vue:7` | medium | `/frontend-audit` | i18n/html-lang-not-synced |
| FC-CP-01a | `apps/shop/app/[locale]/layout.tsx:33` | high | `/frontend-audit` | perf/render-blocking-script |
| FC-CP-01b | `apps/admin/index.html:9` | medium | `/frontend-audit` | perf/render-blocking-stylesheet |
| FC-CP-02a | `apps/shop/app/[locale]/layout.tsx:44` | medium | `/frontend-audit` | perf/third-party-no-strategy |
| FC-CP-02b | `apps/admin/src/main.ts:13` | medium | `/frontend-audit` | perf/third-party-injected |
| FC-CP-03a | `apps/shop/app/[locale]/layout.tsx:38` | medium | `/frontend-audit` | perf/late-inserted-layout-shift |
| FC-CP-03b | `apps/admin/src/components/HelpPanel.vue:18` | medium | `/frontend-audit` | perf/late-inserted-layout-shift |
| FC-BND-01 | `apps/admin/vite.config.ts:8` | medium | `/frontend-audit` | perf/legacy-build-target |
| FC-BND-02 | `apps/admin/src/main.ts:1` | medium | `/frontend-audit` | perf/polyfill-bundle |
| FC-BND-03 | `apps/shop/components/Providers.tsx:4` | high | `/frontend-audit` | perf/dev-code-in-build |
| FC-BND-04 | `apps/admin/src/lib/api.ts:7` | high | `/frontend-audit` | perf/dev-code-in-build |
| FC-RT-01a | `apps/shop/components/account/OrdersTable.tsx:24` | medium | `/frontend-audit` | routing/click-navigation-non-link |
| FC-RT-01b | `apps/admin/src/views/DispatchView.vue:46` | medium | `/frontend-audit` | routing/click-navigation-non-link |
| FC-RT-03a | `apps/shop/components/catalog/Pagination.tsx:11` | medium | `/frontend-audit` | routing/param-not-validated |
| FC-RT-03b | `apps/admin/src/views/OrderDetailView.vue:11` | medium | `/frontend-audit` | routing/param-not-validated |
| FC-RT-04a | `apps/shop/app/[locale]/(shop)/c/[...slug]/page.tsx:9` | medium | `/frontend-audit` | routing/soft-404 |
| FC-RT-04b | `apps/admin/src/router.ts:3` | medium | `/frontend-audit` | routing/no-catch-all |
| FC-RT-06a | `apps/shop/components/account/AccountGate.tsx:12` | high | `/frontend-audit` | routing/client-guard-flash |
| FC-RT-06b | `apps/admin/src/views/SettingsView.vue:14` | medium | `/frontend-audit` | routing/client-guard-flash |
| FC-RT-07a | `apps/shop/components/search/SearchResults.tsx:11` | high | `/frontend-audit` | routing/use-search-params-no-suspense |
| FC-RT-07b | `apps/shop/components/catalog/SortSelect.tsx:12` | high | `/frontend-audit` | routing/use-search-params-no-suspense |

Severity split: 3 critical · 13 high · 49 medium · 1 low. Total 66 seeded defects, 21 decoys.

### Coverage by class

One row per detector §; every row carries at least two seeds, and the § is the one that should produce the candidate.

| family | detector § | classes | seeded | ids |
|--------|------------|---------|--------|-----|
| render | `render-correctness-scan` §1 | render/component-in-component, render/derived-state-in-effect | 2 | FC-RC-01a, FC-RC-01b |
| render | `render-correctness-scan` §2 | render/effect-no-cleanup | 2 | FC-RC-02a, FC-RC-02b |
| render | `render-correctness-scan` §3 | render/index-key-mutable-list | 2 | FC-RC-03a, FC-RC-03b |
| render | `render-correctness-scan` §4 | render/reactivity-loss, render/mutated-prop | 2 | FC-RC-04a, FC-RC-04b |
| render | `render-correctness-scan` §5 | render/uncontrolled-to-controlled, render/value-from-prop | 2 | FC-RC-05a, FC-RC-05b |
| ssr | `ssr-audit` §1 | ssr/hydration-nondeterminism, ssr/invalid-nesting | 2 | FC-SSR-01a, FC-SSR-01b |
| ssr | `ssr-audit` §2 | ssr/browser-global-module-scope, ssr/browser-global-in-render | 2 | FC-SSR-02a, FC-SSR-02b |
| ssr | `ssr-audit` §3 | ssr/server-only-in-client, ssr/missing-server-only | 2 | FC-SSR-03a, FC-SSR-03b |
| ssr | `ssr-audit` §4 | ssr/sync-request-api, ssr/module-state-cross-request | 2 | FC-SSR-04a, FC-SSR-04b |
| data | `client-data-scan` §1 | data/waterfall, data/n-requests | 2 | FC-CD-01a, FC-CD-01b |
| data | `client-data-scan` §2 | data/fetch-bypasses-client | 2 | FC-CD-02a, FC-CD-02b |
| data | `client-data-scan` §3 | data/out-of-order-responses | 2 | FC-CD-03a, FC-CD-03b |
| data | `client-data-scan` §4 | data/mutation-no-invalidation | 2 | FC-CD-04a, FC-CD-04b |
| data | `client-data-scan` §5 | data/optimistic-no-rollback | 2 | FC-CD-05a, FC-CD-05b |
| data | `client-data-scan` §6 | data/key-missing-input, data/cache-kept-on-sign-out | 2 | FC-CD-06a, FC-CD-06b |
| data | `client-data-scan` §7 | data/polling-in-background | 2 | FC-CD-07a, FC-CD-07b |
| i18n | `i18n-scan` §1 | i18n/hardcoded-string | 2 | FC-I18N-01a, FC-I18N-01b |
| i18n | `i18n-scan` §2 | i18n/missing-key, i18n/key-undefined | 2 | FC-I18N-02a, FC-I18N-02b |
| i18n | `i18n-scan` §3 | i18n/manual-plural | 2 | FC-I18N-03a, FC-I18N-03b |
| i18n | `i18n-scan` §4 | i18n/manual-money, i18n/locale-less-date | 2 | FC-I18N-04a, FC-I18N-04b |
| i18n | `i18n-scan` §5 | i18n/physical-css | 2 | FC-I18N-05a, FC-I18N-05b |
| i18n | `i18n-scan` §6 | i18n/text-expansion | 2 | FC-I18N-06a, FC-I18N-06b |
| i18n | `i18n-scan` §7 | i18n/html-lang-static, i18n/html-lang-not-synced | 2 | FC-I18N-07a, FC-I18N-07b |
| perf | `critical-path-scan` §1 | perf/render-blocking-script, perf/render-blocking-stylesheet | 2 | FC-CP-01a, FC-CP-01b |
| perf | `critical-path-scan` §2 | perf/third-party-no-strategy, perf/third-party-injected | 2 | FC-CP-02a, FC-CP-02b |
| perf | `critical-path-scan` §3 | perf/late-inserted-layout-shift | 2 | FC-CP-03a, FC-CP-03b |
| perf | `bundle-analyze` §6 | perf/legacy-build-target, perf/polyfill-bundle | 2 | FC-BND-01, FC-BND-02 |
| perf | `bundle-analyze` §7 | perf/dev-code-in-build | 2 | FC-BND-03, FC-BND-04 |
| routing | `routing-scan` §1 | routing/click-navigation-non-link | 2 | FC-RT-01a, FC-RT-01b |
| routing | `routing-scan` §3 | routing/param-not-validated | 2 | FC-RT-03a, FC-RT-03b |
| routing | `routing-scan` §4 | routing/soft-404, routing/no-catch-all | 2 | FC-RT-04a, FC-RT-04b |
| routing | `routing-scan` §6 | routing/client-guard-flash | 2 | FC-RT-06a, FC-RT-06b |
| routing | `routing-scan` §7 | routing/use-search-params-no-suspense | 2 | FC-RT-07a, FC-RT-07b |
| **decoys (must not be reported)** | — | — | **21** | FC-DECOY-01 … FC-DECOY-21 |

---

## FC-RC-01a — `OrderRow` is declared inside `OrderHistory`

```defect
id:       FC-RC-01a
file:     apps/shop/components/account/OrderHistory.tsx
line:     13
severity: medium
command:  /frontend-audit
class:    render/component-in-component
anchor:   function OrderRow({ order }: { order: Order }) {
match:    inside|nested|defined in|component.*(component|render)|remount|static-components|identity
```

A component declared in the parent's body is a new type on every render, so React unmounts and remounts every row
(state, focus and DOM thrown away) whenever the history re-renders — eslint-plugin-react-hooks `static-components`.
Fix: hoist `OrderRow` to module scope and pass `locale` as a prop. Proof: a row-local state survives a parent
re-render (render count / remount test).

## FC-RC-01b — Basket total is derived state set from an effect

```defect
id:       FC-RC-01b
file:     apps/shop/components/cart/BasketSummary.tsx
line:     13
severity: medium
command:  /frontend-audit
class:    render/derived-state-in-effect
anchor:   setTotal(lines.reduce((sum, line) => sum + line.price * line.qty, 0));
match:    effect|derived|setState|set-state-in-effect|stale|extra render|useMemo|compute
```

`useEffect(() => setTotal(…), [lines])` renders the old total first, then re-renders with the new one: a quantity
change shows the previous subtotal for a frame (and 0 on first paint) — `set-state-in-effect`. Fix: compute
`const total = lines.reduce(…)` during render.

## FC-RC-02a — Header scroll listener is never removed

```defect
id:       FC-RC-02a
file:     apps/shop/components/layout/StickyHeader.tsx
line:     17
severity: medium
command:  /frontend-audit
class:    render/effect-no-cleanup
anchor:   window.addEventListener('scroll', onScroll, { passive: true });
match:    cleanup|remove(EventListener)?|leak|listener|unmount|memory
```

The effect adds a `scroll` listener and returns nothing. The header remounts on every locale switch (the
`[locale]` layout re-renders), so listeners and the closures they hold accumulate, each calling `setCondensed` on an
unmounted component. `ConsentScripts` (same app) removes its listener. Proof: mount/unmount with an
`addEventListener` spy — adds 1, removes 0.

## FC-RC-02b — Dispatch board resize listener survives the board

```defect
id:       FC-RC-02b
file:     apps/admin/src/components/ColumnResizer.vue
line:     12
severity: medium
command:  /frontend-audit
class:    render/effect-no-cleanup
anchor:   window.addEventListener('resize', measure);
match:    cleanup|remove(EventListener)?|leak|listener|onUnmounted|unmount|memory
```

`onMounted` adds a `resize` listener and nothing removes it: every visit to `/dispatch` leaves one more listener
writing to a dead component's ref. `KeyboardShortcuts.vue` pairs `onMounted`/`onUnmounted` (FC-DECOY-12). Proof:
navigate away and back ×10; `getEventListeners(window).resize.length` grows.

## FC-RC-03a — Basket lines keyed by index while lines can be removed

```defect
id:       FC-RC-03a
file:     apps/shop/components/cart/BasketLines.tsx
line:     20
severity: medium
command:  /frontend-audit
class:    render/index-key-mutable-list
anchor:   <li key={index}
match:    key|index|identity|remove|reorder
```

Removing line 2 shifts every later line's key, so React reuses line 3's `QuantityStepper` (and its in-flight
mutation state) for what is now line 2. The footer's `key={i}` over a constant list is fine (FC-DECOY-01). Proof:
start a quantity change on line 3, remove line 2; the pending state appears on the wrong product.

## FC-RC-03b — Recipe list tracked by `$index` and sortable, with a note input per row

```defect
id:       FC-RC-03b
file:     packages/widgets/src/angular/recipe-list.component.html
line:     4
severity: medium
command:  /frontend-audit
class:    render/index-key-mutable-list
anchor:   @for (recipe of recipes(); track $index) {
match:    track|\$index|identity|sort|reorder|key
```

`track $index` plus **Quickest first** re-sorting the signal: Angular keeps each row's DOM by position, so a note
typed against one recipe now sits under another. Fix: `track recipe.id`. Proof: type a note, sort; the note moves.

## FC-RC-04a — Dispatch board destructures the Pinia store and goes stale

```defect
id:       FC-RC-04a
file:     apps/admin/src/views/DispatchView.vue
line:     17
severity: high
command:  /frontend-audit
class:    render/reactivity-loss
anchor:   const { orders, selected } = useDispatchStore();
match:    destructur|reactiv|storeToRefs|pinia|stale|lose
```

`const { orders, selected } = useDispatchStore()` copies the state once: `store.setOrders(data)` replaces
`orders`, and the board keeps rendering the first (empty) array — the dispatch queue never appears or updates. High:
the team's main screen. Fix: `storeToRefs(store)`. Proof: a component test sets orders and asserts the cards render.

## FC-RC-04b — Order card writes to its `order` prop

```defect
id:       FC-RC-04b
file:     apps/admin/src/components/OrderCard.vue
line:     11
severity: medium
command:  /frontend-audit
class:    render/mutated-prop
anchor:   props.order.status = 'ready';
match:    prop|mutat|one-way|emit|no-mutating-props
```

`props.order.status = 'ready'` mutates the parent's object behind the store's back (`vue/no-mutating-props`):
the change is lost on the next fetch and other views of the same order disagree. Fix: emit an event or update the
store/query cache.

## FC-RC-05a — Coupon input flips from uncontrolled to controlled

```defect
id:       FC-RC-05a
file:     apps/shop/components/checkout/CouponInput.tsx
line:     9
severity: medium
command:  /frontend-audit
class:    render/uncontrolled-to-controlled
anchor:   const [coupon, setCoupon] = useState<string>();
match:    controlled|uncontrolled|undefined|value=|initial
```

`useState<string>()` starts `undefined`, so `<input value={coupon}>` is uncontrolled until the first keystroke and
React warns "changing an uncontrolled input to be controlled". Fix: `useState('')`.

## FC-RC-05b — Phone input is bound to the prop, not to its state

```defect
id:       FC-RC-05b
file:     apps/shop/components/account/AddressForm.tsx
line:     38
severity: medium
command:  /frontend-audit
class:    render/value-from-prop
anchor:   value={address?.phone}
match:    controlled|value=|address\?\.phone|prop|state|cannot (type|edit)|undefined
```

`value={address?.phone}` while `onChange` writes `setPhone`: for an existing address the field cannot be edited
(the value snaps back), and for a new one it is uncontrolled→controlled. The saved body uses `phone` state, which
the user never sees. Fix: `value={phone ?? ''}`.

## FC-SSR-01a — Sale countdown computes minutes from `Date.now()` during render

```defect
id:       FC-SSR-01a
file:     apps/shop/components/product/SaleCountdown.tsx
line:     7
severity: medium
command:  /frontend-audit
class:    ssr/hydration-nondeterminism
anchor:   Date.now()) / 60_000));
match:    hydrat|mismatch|Date\.now|server.*client|nondetermin
```

The server renders "12 minutes" and the browser hydrates a minute later with "11": a text mismatch, React
discards the server HTML for the subtree. Fix: render the end time (or a placeholder) on the server and start the
countdown in an effect. The `DeliveryEta` sibling does exactly that (FC-DECOY-04). Proof: production build,
`page.on('console')` collects "Hydration failed" on `/products/…`.

## FC-SSR-01b — `<div>` inside `<p>` on the product page

```defect
id:       FC-SSR-01b
file:     apps/shop/components/product/ProductDescription.tsx
line:     7
severity: high
command:  /frontend-audit
class:    ssr/invalid-nesting
anchor:   <p className="mt-4 text-sm text-stone-600"><div
match:    nest|<div>.*<p>|<p>.*<div>|div inside|hydrat|validateDOMNesting|invalid
```

The HTML parser closes the `<p>` before the `<div>`, so the server DOM and React's tree disagree: a hydration
error on every product page (React 19 also logs `In HTML, <div> cannot be a descendant of <p>`). Fix: make the outer
element a `div`.

## FC-SSR-02a — `window.matchMedia` at module scope in a component the layout imports

```defect
id:       FC-SSR-02a
file:     apps/shop/components/layout/ThemeToggle.tsx
line:     7
severity: critical
command:  /frontend-audit
class:    ssr/browser-global-module-scope
anchor:   const prefersDark = window.matchMedia(
match:    window|module scope|server|ReferenceError|SSR|matchMedia|crash|500
```

`'use client'` components still render on the server. Evaluating this module on the server throws
`ReferenceError: window is not defined`, and the header that imports it is in the root `[locale]` layout: every
route answers 500. Critical (a primary route blanks). Fix: read the media query in an effect or via
`useSyncExternalStore` with a server snapshot. Proof: `next build && next start`, request `/en`.

## FC-SSR-02b — Home page reads `localStorage` while rendering

```defect
id:       FC-SSR-02b
file:     apps/shop/components/search/RecentSearches.tsx
line:     8
severity: critical
command:  /frontend-audit
class:    ssr/browser-global-in-render
anchor:   JSON.parse(localStorage.getItem('recent-searches')
match:    localStorage|server|render|SSR|ReferenceError|crash|500|hydrat
```

`localStorage.getItem` in the render body of a component the home page renders: the server render throws and `/`
is a 500. Fix: read it in an effect (render nothing until then).

## FC-SSR-03a — A `'use client'` component reads a non-public env var

```defect
id:       FC-SSR-03a
file:     apps/shop/components/checkout/DeliverySlots.tsx
line:     17
severity: high
command:  /frontend-audit
class:    ssr/server-only-in-client
anchor:   process.env.SLOTS_API_TOKEN
match:    use client|client|env|secret|token|server-only|NEXT_PUBLIC|bundle|leak
```

`process.env.SLOTS_API_TOKEN` in a client component: Next inlines only `NEXT_PUBLIC_*`, so in the browser the
header is `Bearer undefined` and the slot list never loads — and the fix someone will reach for (renaming it
`NEXT_PUBLIC_…`) ships the token. Fix: a server action or route handler that holds the token. Secrets in the bundle →
security `xss-scan` §12 when installed.

## FC-SSR-03b — Pricing client reads an API key with no `server-only` guard

```defect
id:       FC-SSR-03b
file:     apps/shop/lib/pricing.ts
line:     6
severity: medium
command:  /frontend-audit
class:    ssr/missing-server-only
anchor:   process.env.PRICING_API_KEY
match:    server-only|client|import|guard|secret|env|key
```

`lib/pricing.ts` reads `PRICING_API_KEY` and does not `import 'server-only'`; nothing stops a client component from
importing it next week (the key would read as empty and the call would fail in the browser, or worse once renamed).
`lib/server/catalog.ts` and `account.ts` have the guard (FC-DECOY-05).

## FC-SSR-04a — Product page reads `params.slug` synchronously

```defect
id:       FC-SSR-04a
file:     apps/shop/app/[locale]/(shop)/products/[slug]/page.tsx
line:     12
severity: high
command:  /frontend-audit
class:    ssr/sync-request-api
anchor:   const product = await getProduct(params.slug);
match:    params|promise|await|sync|Next (15|16)|undefined|404
```

In Next 16 `params` is a Promise; synchronous access was removed. `params.slug` is `undefined`, `getProduct`
fetches `/products/undefined`, and every product page renders the 404. Fix: `const { slug } = await params` (as every
other page in the app does).

## FC-SSR-04b — Signed-in customer stored in a module variable shared by all requests

```defect
id:       FC-SSR-04b
file:     apps/shop/lib/server/session.ts
line:     4
severity: critical
command:  /frontend-audit
class:    ssr/module-state-cross-request
anchor:   let currentCustomer: { customerId: string; name: string } | null = null;
match:    module|global|shared|cross.?request|concurren|leak|another (user|customer)|singleton
```

`loadCustomer()` writes `currentCustomer` and `Greeting` reads it later in the same render — but the module is
shared by every concurrent request on the Node process, so customer B's greeting can carry customer A's name (and
any future reader of `customer()` A's id). Critical: cross-user data. Fix: `React.cache()` per request, or pass the
value down. Owner security (tenant/user isolation) when installed. Proof: two concurrent requests with different
cookies; assert each page names its own customer.

## FC-CD-01a — Orders page awaits two independent reads in sequence

```defect
id:       FC-CD-01a
file:     apps/shop/app/[locale]/account/orders/page.tsx
line:     10
severity: medium
command:  /frontend-audit
class:    data/waterfall
anchor:   const addresses = await getAddresses();
match:    sequential|waterfall|parallel|Promise\.all|one after|independent|await
```

`getOrders()` then `getAddresses()`: neither needs the other, so the page's TTFB is the sum of two account-API
round trips. Fix: `Promise.all` (or two Suspense boundaries). Proof: request log — the second request starts after
the first ends.

## FC-CD-01b — Dispatch board loads each picker with its own request, in sequence

```defect
id:       FC-CD-01b
file:     apps/admin/src/stores/pickers.ts
line:     8
severity: medium
command:  /frontend-audit
class:    data/n-requests
anchor:   for (const id of ids) {
match:    loop|per.?(picker|id|item)|n\s*\+\s*1|n requests|sequential|batch|one request
```

`loadMany` awaits `GET /pickers/:id` once per id inside a `for…of`: 30 pickers are 30 sequential round trips before
the board's query resolves. `GET /pickers` already returns the list. Grep 1b misses it because the destructured
`const { data } = await …` closes its `[^}]` window (IR-6). Proof: request count for one board load = 1 + pickers.

## FC-CD-02a — Stock-alert button calls `fetch` directly

```defect
id:       FC-CD-02a
file:     apps/shop/components/product/NotifyMeButton.tsx
line:     15
severity: medium
command:  /frontend-audit
class:    data/fetch-bypasses-client
anchor:   await fetch('/api/stock-alerts', { method: 'POST', body: JSON.stringify({ productId }) });
match:    fetch|client|bypass|api\.|timeout|credentials|error|wrapper
```

Raw `fetch` from the component: no `credentials`, no JSON content type, no timeout, and `res.ok` is never checked —
a 401 or 500 still flips the button to "We'll email you". `lib/api.ts` is the app's client. Fix: `api.post` inside a
`useMutation`.

## FC-CD-02b — Weekly report uses bare `axios` instead of the app's client

```defect
id:       FC-CD-02b
file:     apps/admin/src/views/ReportsView.vue
line:     14
severity: medium
command:  /frontend-audit
class:    data/fetch-bypasses-client
anchor:   await axios.get<Row[]>('/api/admin/reports/weekly');
match:    axios|client|bypass|api\.|timeout|credentials|cache|query
```

The global `axios` skips `lib/api.ts`'s base URL, credentials and 15 s timeout (and its demo mock switch), and the
data lives outside the query cache.

## FC-CD-03a — Search suggestions race: a slow early response overwrites a later one

```defect
id:       FC-CD-03a
file:     apps/shop/components/search/SearchBox.tsx
line:     18
severity: medium
command:  /frontend-audit
class:    data/out-of-order-responses
anchor:   api.get<Product[]>(`/search/suggest?q=${encodeURIComponent(q)}`).then(setSuggestions);
match:    race|out.of.order|abort|cancel|stale|latest|signal
```

Each keystroke starts a request and whichever resolves last wins: typing "milk" can show suggestions for "mi".
No `AbortController`, no ignore flag, no keyed cache. `AddressLookup` (same folder) aborts correctly
(FC-DECOY-08). Proof: MSW delays the first response past the second; the UI must show the second.

## FC-CD-03b — Customer search watcher writes whichever response lands last

```defect
id:       FC-CD-03b
file:     apps/admin/src/views/CustomerSearchView.vue
line:     12
severity: medium
command:  /frontend-audit
class:    data/out-of-order-responses
anchor:   watch(q, async (value) => {
match:    race|out.of.order|abort|cancel|stale|latest|signal|onWatcherCleanup
```

Same race in Vue: no `onWatcherCleanup` / `AbortController`. Proof: as above.

## FC-CD-04a — Saving an address never refreshes the address list

```defect
id:       FC-CD-04a
file:     apps/shop/components/account/AddressForm.tsx
line:     14
severity: medium
command:  /frontend-audit
class:    data/mutation-no-invalidation
anchor:   const save = useMutation({
match:    invalidat|stale|cache|refetch|setQueryData|list
```

The mutation has no `onSuccess` cache work (only the caller's callback): the address book keeps its old data until
a reload. `ReorderButton` invalidates through `invalidateOrders()` (FC-DECOY-07). Proof: e2e — add an address, the
list shows it without a reload.

## FC-CD-04b — Deactivating a picker leaves them active in the list

```defect
id:       FC-CD-04b
file:     apps/admin/src/views/PickersView.vue
line:     13
severity: medium
command:  /frontend-audit
class:    data/mutation-no-invalidation
anchor:   const deactivate = useMutation({
match:    invalidat|stale|cache|refetch|setQueryData|list
```

No invalidation of `['pickers']`: the button stays enabled and the list says active until the next refetch.

## FC-CD-05a — Optimistic quantity change has no rollback

```defect
id:       FC-CD-05a
file:     apps/shop/components/cart/QuantityStepper.tsx
line:     15
severity: medium
command:  /frontend-audit
class:    data/optimistic-no-rollback
anchor:   onMutate: async (next) => {
match:    rollback|roll back|onError|optimistic|revert|restore
```

`onMutate` writes the new quantity into the cache and returns no context; there is no `onError`. A 409 (out of
stock) leaves the wrong quantity on screen until `onSettled`'s refetch lands — and if that refetch also fails, it
stays. Fix: return the previous data from `onMutate` and restore it in `onError`.

## FC-CD-05b — Priority toggle writes the cache optimistically with no rollback

```defect
id:       FC-CD-05b
file:     apps/admin/src/components/PriorityToggle.vue
line:     12
severity: medium
command:  /frontend-audit
class:    data/optimistic-no-rollback
anchor:   onMutate: async (next: boolean) => {
match:    rollback|roll back|onError|optimistic|revert|restore
```

`setQueriesData` on every `['order', …]` query with no `onError` restore.

## FC-CD-06a — Order history cache key omits the customer

```defect
id:       FC-CD-06a
file:     apps/shop/components/account/OrderHistory.tsx
line:     11
severity: high
command:  /frontend-audit
class:    data/key-missing-input
anchor:   queryKey: ['orders'], queryFn: () => getOrders(customerId)
match:    key|customerId|cache|another (user|customer)|missing|shared device|leak
```

`queryKey: ['orders']` while the fetcher uses `customerId`: the cache entry is shared across customers, so after a
sign-out/sign-in on the same device the next customer sees the previous one's orders until the refetch lands.
`keys.orders(customerId)` exists in `lib/queries.ts` and is not used. Owner security (cross-user) when installed.

## FC-CD-06b — Signing out of the dispatch app keeps the query cache

```defect
id:       FC-CD-06b
file:     apps/admin/src/stores/session.ts
line:     14
severity: high
command:  /frontend-audit
class:    data/cache-kept-on-sign-out
anchor:   async signOut() {
match:    sign.?out|log.?out|clear|cache|queryClient|another (user|staff)|shared
```

`signOut` clears the user and routes to `/login` but never calls `queryClient.clear()`: the next dispatcher on the
shared warehouse terminal sees the previous session's orders and customers from cache. Proof: sign out, sign in as
another user; no previous data may flash.

## FC-CD-07a — Order tracker polls every 5 s even in a background tab

```defect
id:       FC-CD-07a
file:     apps/shop/components/account/OrderTracker.tsx
line:     13
severity: medium
command:  /frontend-audit
class:    data/polling-in-background
anchor:   refetchIntervalInBackground: true,
match:    poll|interval|background|hidden|visibility|backoff
```

`refetchInterval: 5_000` with `refetchIntervalInBackground: true`: 720 requests an hour per open tab, for a
status that changes four times per order. Fix: drop the background opt-in and back off.

## FC-CD-07b — Live queue polls with `setInterval` and no visibility pause

```defect
id:       FC-CD-07b
file:     apps/admin/src/components/LiveQueue.vue
line:     11
severity: medium
command:  /frontend-audit
class:    data/polling-in-background
anchor:   timer = setInterval(async () => {
match:    poll|interval|background|hidden|visibility|backoff
```

It clears its interval on unmount (no leak), but polls every 10 s whether or not the tab is visible, with no
backoff on errors.

## FC-I18N-01a — "Recommended for you" is hard-coded

```defect
id:       FC-I18N-01a
file:     apps/shop/components/marketing/Recommended.tsx
line:     7
severity: medium
command:  /frontend-audit
class:    i18n/hardcoded-string
anchor:   >Recommended for you</h2>
match:    hard.?coded|literal|translat|i18n|t\(|untranslated|string
```

An English literal on the Arabic home page. Fix: a `home.recommended` key in both catalogs.

## FC-I18N-01b — "Export CSV" is hard-coded in the German back office

```defect
id:       FC-I18N-01b
file:     apps/admin/src/views/OrdersView.vue
line:     28
severity: medium
command:  /frontend-audit
class:    i18n/hardcoded-string
anchor:   @click="exportCsv">Export CSV</button>
match:    hard.?coded|literal|translat|i18n|\$?t\(|untranslated|string
```

Every other control on the page goes through `t()`.

## FC-I18N-02a — Arabic catalog has no `checkout.placeOrder`

```defect
id:       FC-I18N-02a
file:     apps/shop/messages/ar.json
line:     49
severity: high
command:  /frontend-audit
class:    i18n/missing-key
anchor:   "slotsError":
match:    placeOrder|missing|parity|ar\b|arabic|key
```

The checkout's primary button renders the raw key (or the English fallback, depending on next-intl's
`onError`) for every Arabic customer. `catalog-parity.py` reports `missing-key … [ar] checkout.placeOrder`. The
anchor is the last key of the `checkout` block, where the row is missing.

## FC-I18N-02b — `orders.bulkRefund` is used in code and defined in no catalog

```defect
id:       FC-I18N-02b
file:     apps/admin/src/views/OrdersView.vue
line:     27
severity: medium
command:  /frontend-audit
class:    i18n/key-undefined
anchor:   t('orders.bulkRefund')
match:    bulkRefund|undefined|missing|no catalog|key
```

vue-i18n renders `orders.bulkRefund` on the button in both locales.

## FC-I18N-03a — Ingredient count pluralised with `=== 1`

```defect
id:       FC-I18N-03a
file:     apps/shop/components/marketing/RecipeCard.tsx
line:     10
severity: medium
command:  /frontend-audit
class:    i18n/manual-plural
anchor:   ingredientCount === 1 ? t('item') : t('items')
match:    plural|ICU|PluralRules|=== 1|count|arabic
```

Arabic has six plural categories; `n === 1 ? item : items` is wrong for 0, 2 and 3–10. The basket badge uses an ICU
plural (FC-DECOY-09). Fix: `t('ingredients', { count })` with an ICU message.

## FC-I18N-03b — Queue summary appends an English `s` (and is not translated at all)

```defect
id:       FC-I18N-03b
file:     apps/admin/src/components/QueueSummary.vue
line:     6
severity: medium
command:  /frontend-audit
class:    i18n/manual-plural
anchor:   order{{ count === 1 ? '' : 's' }}
match:    plural|ICU|concat|suffix|'s'|=== 1|hard.?coded
```

`{{ count }} order{{ count === 1 ? '' : 's' }} waiting for a picker` — an English-only plural rule glued onto
untranslated text in the German UI.

## FC-I18N-04a — Prices formatted by hand with `$` and `toFixed(2)`

```defect
id:       FC-I18N-04a
file:     apps/shop/components/product/PriceTag.tsx
line:     2
severity: medium
command:  /frontend-audit
class:    i18n/manual-money
anchor:   const label = `$${(cents / 100).toFixed(2)}`;
match:    toFixed|currency|Intl\.NumberFormat|\$|money|locale|format
```

Ignores the locale (Arabic digits, separators, symbol position). `BasketSummary` and `OrdersTable` use
`Intl.NumberFormat(locale, …)`.

## FC-I18N-04b — ETA formatted with the browser's locale, not the app's

```defect
id:       FC-I18N-04b
file:     apps/admin/src/components/DeliveryRow.vue
line:     13
severity: medium
command:  /frontend-audit
class:    i18n/locale-less-date
anchor:   new Date(order.eta).toLocaleTimeString()
match:    toLocale|locale|Intl|date|time|format
```

`toLocaleTimeString()` with no locale uses the OS locale: a German dispatcher on an English laptop gets 12-hour
times in a German UI. Fix: vue-i18n `d(…)` or `Intl.DateTimeFormat(locale)`.

## FC-I18N-05a — Product card uses `ml-4` in an RTL-shipping storefront

```defect
id:       FC-I18N-05a
file:     apps/shop/components/product/ProductCard.tsx
line:     10
severity: medium
command:  /frontend-audit
class:    i18n/physical-css
anchor:   className="ml-4 flex-1"
match:    rtl|ml-|margin-left|logical|ms-|physical|mirror
```

In Arabic the text block keeps its gap on the wrong side. `SubstitutionNote` uses the logical `ms-4`
(FC-DECOY-10).

## FC-I18N-05b — `.status` uses `margin-left` and `text-align: left`

```defect
id:       FC-I18N-05b
file:     apps/admin/src/styles/app.css
line:     37
severity: low
command:  /frontend-audit
class:    i18n/physical-css
anchor:   margin-left: var(--space-2);
match:    rtl|margin-left|text-align|logical|physical|inline-start
```

Low: the back office ships no RTL locale today, but `.sidebar` already uses `border-inline-end`; this rule is the
odd one out.

## FC-I18N-06a — Category labels truncated at 120 px with no full-text fallback

```defect
id:       FC-I18N-06a
file:     apps/shop/components/layout/CategoryNav.tsx
line:     13
severity: medium
command:  /frontend-audit
class:    i18n/text-expansion
anchor:   w-[120px] truncate
match:    truncat|expan|width|120px|clip|ellipsis|title
```

"Dairy & eggs" fits; its Arabic and any pseudo-locale (+40 %) do not, and the clipped label has no `title`.

## FC-I18N-06b — Status tabs fixed at 96 px with `nowrap` and `overflow: hidden`

```defect
id:       FC-I18N-06b
file:     apps/admin/src/styles/app.css
line:     48
severity: medium
command:  /frontend-audit
class:    i18n/text-expansion
anchor:   width: 96px;
match:    width|96px|expan|clip|truncat|nowrap|german
```

"Unterwegs zur Auslieferung" is clipped to "Unterwegs z" in German.

## FC-I18N-07a — `<html lang="en">` on Arabic pages

```defect
id:       FC-I18N-07a
file:     apps/shop/app/[locale]/layout.tsx
line:     31
severity: medium
command:  /frontend-audit
class:    i18n/html-lang-static
anchor:   <html lang="en" dir=
match:    lang|html|hard.?coded|locale|screen reader
```

`dir` follows the locale, `lang` does not: Arabic pages announce as English to screen readers, fonts and
hyphenation pick English rules (3.1.1 as well). Fix: `lang={locale}`.

## FC-I18N-07b — Switching the back office to German never updates `<html lang>`

```defect
id:       FC-I18N-07b
file:     apps/admin/src/components/LocaleSwitcher.vue
line:     7
severity: medium
command:  /frontend-audit
class:    i18n/html-lang-not-synced
anchor:   locale.value = next;
match:    lang|html|documentElement|locale|switch|sync
```

`locale.value = next` and nothing sets `document.documentElement.lang`; `index.html` hard-codes `lang="en"`.

## FC-CP-01a — Synchronous third-party script in `<head>` on every page

```defect
id:       FC-CP-01a
file:     apps/shop/app/[locale]/layout.tsx
line:     33
severity: high
command:  /frontend-audit
class:    perf/render-blocking-script
anchor:   focus-visible.min.js
match:    render.?block|sync|blocking|async|defer|head|script|cdn
```

A parser-blocking `<script src>` from jsdelivr in the root layout's head: every page waits on a third-party DNS +
TLS + download before first paint — for a polyfill evergreen browsers do not need (`:focus-visible` is native).
Fix: delete it.

## FC-CP-01b — Cross-origin Google Fonts stylesheet blocks the back office's first render

```defect
id:       FC-CP-01b
file:     apps/admin/index.html
line:     9
severity: medium
command:  /frontend-audit
class:    perf/render-blocking-stylesheet
anchor:   rel="stylesheet" href="https://fonts.googleapis.com
match:    render.?block|stylesheet|font|cross.?origin|google|self.?host
```

A render-blocking stylesheet on a third origin (plus the font files it then requests). Fix: self-host the font
with `font-display: swap`.

## FC-CP-02a — Intercom loaded on every route with no loading strategy

```defect
id:       FC-CP-02a
file:     apps/shop/app/[locale]/layout.tsx
line:     44
severity: medium
command:  /frontend-audit
class:    perf/third-party-no-strategy
anchor:   <Script src="https://widget.intercom.io/widget/hm42" />
match:    intercom|strategy|third.?party|lazy|afterInteractive|chat|widget
```

A chat widget (several hundred KB of JS) at the default `afterInteractive` priority on every storefront route,
competing with hydration. Fix: `strategy="lazyOnload"` or load on first click of a help button. The analytics tag
waits for consent and `lazyOnload` (FC-DECOY-13).

## FC-CP-02b — Session-replay script injected at boot

```defect
id:       FC-CP-02b
file:     apps/admin/src/main.ts
line:     13
severity: medium
command:  /frontend-audit
class:    perf/third-party-injected
anchor:   const replay = document.createElement('script');
match:    hotjar|inject|createElement|third.?party|replay|script
```

Hotjar is appended before the app mounts, on every route, with no consent and no deferral. (Session replay of
customer names and addresses is also a privacy question for the security pack.)

## FC-CP-03a — Promo banner inserted above the header after a client fetch

```defect
id:       FC-CP-03a
file:     apps/shop/app/[locale]/layout.tsx
line:     38
severity: medium
command:  /frontend-audit
class:    perf/late-inserted-layout-shift
anchor:   <PromoBanner />
match:    layout shift|CLS|banner|late|reserve|insert|shift
```

`PromoBanner` renders `null`, fetches after hydration and then inserts a 44 px band above everything: the whole
page shifts down on every route. Fix: render it on the server, or reserve its height.

## FC-CP-03b — "What's new" iframe inserted above the board with no size

```defect
id:       FC-CP-03b
file:     apps/admin/src/components/HelpPanel.vue
line:     18
severity: medium
command:  /frontend-audit
class:    perf/late-inserted-layout-shift
anchor:   <iframe v-if="notesUrl"
match:    layout shift|CLS|iframe|height|size|reserve|insert
```

An unsized iframe appears after a request on mount, at the top of `<main>`: the dispatch board jumps by the
iframe's default 150 px.

## FC-BND-01 — Back office built for ES2017

```defect
id:       FC-BND-01
file:     apps/admin/vite.config.ts
line:     8
severity: medium
command:  /frontend-audit
class:    perf/legacy-build-target
anchor:   target: 'es2017',
match:    target|es2017|legacy|transpil|baseline|browser
```

The profile's support matrix is evergreen (0.3 % older browsers in RUM); `es2017` down-levels async/await,
optional chaining, class fields and more for everyone. Fix: drop the explicit target (Vite 8's default is
baseline-widely-available).

## FC-BND-02 — Every core-js polyfill imported into the back office entry

```defect
id:       FC-BND-02
file:     apps/admin/src/main.ts
line:     1
severity: medium
command:  /frontend-audit
class:    perf/polyfill-bundle
anchor:   import 'core-js/stable';
match:    core-js|polyfill|legacy|bytes|bundle
```

`core-js/stable` pulls the full polyfill set into the initial chunk for browsers that need none of it.

## FC-BND-03 — MSW and its handlers ship in the storefront's production bundle

```defect
id:       FC-BND-03
file:     apps/shop/components/Providers.tsx
line:     4
severity: high
command:  /frontend-audit
class:    perf/dev-code-in-build
anchor:   import { setupWorker } from 'msw/browser';
match:    msw|mock|setupWorker|dev.?only|production|bundle|ship
```

A static import of `msw/browser` and `@/mocks/handlers` in the root client provider, gated by a runtime env check:
the bundler cannot drop either arm, so every customer downloads MSW. The back office's `import.meta.env.DEV`-guarded
dynamic import is the correct shape (FC-DECOY-14).

## FC-BND-04 — Demo mock API (with faker) is in every production build

```defect
id:       FC-BND-04
file:     apps/admin/src/lib/api.ts
line:     7
severity: high
command:  /frontend-audit
class:    perf/dev-code-in-build
anchor:   export const api = import.meta.env.VITE_USE_MOCKS === 'true' ? mockApi : http;
match:    mock|faker|demo|runtime|switch|production|bundle|ship
```

Both arms of a runtime switch ship: `mock-api.ts` and `@faker-js/faker` (a devDependency) are in the back office's
production bundle whatever `VITE_USE_MOCKS` says at runtime.

## FC-RT-01a — Order rows navigate with `onClick` on a `<tr>`

```defect
id:       FC-RT-01a
file:     apps/shop/components/account/OrdersTable.tsx
line:     24
severity: medium
command:  /frontend-audit
class:    routing/click-navigation-non-link
anchor:   onClick={() => router.push(`/account/orders/${o.id}`)}
match:    link|<a|href|navigat|row|router\.push|middle.?click|new tab
```

No link: no middle-click/new tab, no URL on hover, no keyboard path. Fix: a `<Link>` in the order-number cell
(stretched if the whole row should be clickable).

## FC-RT-01b — Dispatch cards navigate from a clickable `div`

```defect
id:       FC-RT-01b
file:     apps/admin/src/views/DispatchView.vue
line:     46
severity: medium
command:  /frontend-audit
class:    routing/click-navigation-non-link
anchor:   @click="router.push(`/orders/${order.id}`)"
match:    link|<a|href|navigat|RouterLink|router\.push|middle.?click|new tab
```

Dispatchers cannot open an order in a new tab while keeping the board. Fix: `RouterLink`.

## FC-RT-03a — `?page=` coerced with `Number()` and never validated

```defect
id:       FC-RT-03a
file:     apps/shop/components/catalog/Pagination.tsx
line:     11
severity: medium
command:  /frontend-audit
class:    routing/param-not-validated
anchor:   const page = Number(searchParams.get('page') ?? 1);
match:    validat|NaN|parse|search.?param|page|coerc|garbage
```

`?page=abc` is `NaN`: "Page NaN of 4" with no previous/next links; `?page=-3` renders a "previous" link to page
-4. Fix: parse with a schema (int ≥ 1) and clamp or 404.

## FC-RT-03b — Order id route param coerced to a number

```defect
id:       FC-RT-03b
file:     apps/admin/src/views/OrderDetailView.vue
line:     11
severity: medium
command:  /frontend-audit
class:    routing/param-not-validated
anchor:   Number(route.params.id)
match:    validat|NaN|parse|param|coerc|id|string
```

Order ids are strings (`o_…`): `Number('o_12')` is `NaN`, so every order detail requests `/orders/NaN`. The
picker route validates with zod (FC-DECOY-17).

## FC-RT-04a — Unknown category paths render an empty 200 page

```defect
id:       FC-RT-04a
file:     apps/shop/app/[locale]/(shop)/c/[...slug]/page.tsx
line:     9
severity: medium
command:  /frontend-audit
class:    routing/soft-404
anchor:   const category = await getCategory(slug);
match:    404|not.?found|notFound|soft|catch.?all|empty
```

`getCategory` returns `null` for an unknown path and the page renders an empty heading and grid with status 200:
a soft 404 that search engines index. `recipes/[[...tags]]` calls `notFound()` (FC-DECOY-16).

## FC-RT-04b — Back-office router has no catch-all route

```defect
id:       FC-RT-04b
file:     apps/admin/src/router.ts
line:     3
severity: medium
command:  /frontend-audit
class:    routing/no-catch-all
anchor:   export const router = createRouter({
match:    catch.?all|404|not.?found|pathMatch|unknown|blank
```

An unknown URL (an old bookmark, a typo) renders an empty `<RouterView>` inside the shell. Fix: a
`/:pathMatch(.*)*` route with a not-found view.

## FC-RT-06a — Account area guarded only by a client effect

```defect
id:       FC-RT-06a
file:     apps/shop/components/account/AccountGate.tsx
line:     12
severity: high
command:  /frontend-audit
class:    routing/client-guard-flash
anchor:   if (!session && !isPending) router.replace('/login');
match:    guard|redirect|flash|protect|server|middleware|client.?side|effect
```

`AccountGate` renders its children (the account layout and server-rendered pages) while the session is unknown and
redirects from an effect afterwards: signed-out visitors see the account shell, and the server components behind it
run anyway. The checkout uses a server `redirect()` in its layout (FC-DECOY-18). Fix: guard in the layout (or
middleware) on the server.

## FC-RT-06b — Settings guarded by an `onMounted` check

```defect
id:       FC-RT-06b
file:     apps/admin/src/views/SettingsView.vue
line:     14
severity: medium
command:  /frontend-audit
class:    routing/client-guard-flash
anchor:   if (!session.user) router.push('/login');
match:    guard|redirect|flash|protect|beforeEach|meta|effect|mount
```

The settings form renders, then redirects; the router has no `beforeEach` guard and no `returnTo`.

## FC-RT-07a — `useSearchParams` with no `<Suspense>` on the search page

```defect
id:       FC-RT-07a
file:     apps/shop/components/search/SearchResults.tsx
line:     11
severity: high
command:  /frontend-audit
class:    routing/use-search-params-no-suspense
anchor:   const searchParams = useSearchParams();
match:    suspense|useSearchParams|CSR bailout|static|build
```

Next requires a Suspense boundary around a client component that reads `useSearchParams` on a statically
rendered route: the build fails ("Missing Suspense boundary with useSearchParams"), or, with the check off, the
whole route bails out to client rendering. Fix: wrap `<SearchResults />` in `<Suspense>`.

## FC-RT-07b — Sort select reads `useSearchParams` outside the page's only `<Suspense>`

```defect
id:       FC-RT-07b
file:     apps/shop/components/catalog/SortSelect.tsx
line:     12
severity: high
command:  /frontend-audit
class:    routing/use-search-params-no-suspense
anchor:   const searchParams = useSearchParams();
match:    suspense|useSearchParams|CSR bailout|static|build
```

`c/[...slug]/page.tsx` wraps `<Pagination>` in `<Suspense>` but renders `<SortSelect />` outside it. Grep 7a
counts Suspense per renderer *file* and prints "1 with <Suspense>" for both (IR-9).

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded defect, and most need a read (or one precedent in
`templates/snippets/precedents/ui.md`) to tell apart. FX-2's eval list is covered in full: `Date` in an effect,
`suppressHydrationWarning` on a timestamp, `useQuery` with the same key twice, `invalidateQueries` through a shared
helper, `ms-4` beside `ml-4`, an ICU plural, `plugin-legacy` nomodule, a dev-only import behind
`import.meta.env.DEV`, a consent-gated tag, an `async` third party, `AbortController` in a search, a correctly imported
`server-only` module, a `vi.getTimerCount` clean-unmount test, a Vue `onUnmounted` removal and Angular
`takeUntilDestroyed`. Added: `key={i}` on a static list, a catch-all that calls `notFound()`, a zod-validated param, a
server `redirect()` guard, a `useSearchParams` client inside `<Suspense>` and an intentional `key` reset.

How they score (`score.py`, § DECOYS): a finding that names the decoy's file, cites a line within the tolerance window
of the decoy's line, and matches every one of the decoy's `match:` patterns is **pinned** to it, removed before defect
assignment, and reported as `DECOYS FLAGGED k/N`. Every decoy sits more than 12 lines from any defect in its file
(`--verify` enforces it).

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| FC-DECOY-01 | `apps/shop/components/layout/Footer.tsx:17` | FC-RC-03a | three constant links that never reorder or hold input (precedents/ui § 42) |
| FC-DECOY-02 | `apps/shop/components/layout/Footer.tsx:25` | FC-SSR-01a | a one-level opt-out on a text-only timestamp leaf (ui § 44) |
| FC-DECOY-03 | `apps/shop/lib/queries.ts:10` | FC-CD-01a | `AccountMenu` and `ProfileCard` call the same key; TanStack dedupes one request (ui § 38) |
| FC-DECOY-04 | `apps/shop/components/product/DeliveryEta.tsx:13` | FC-SSR-01a | `new Date()` runs inside `useEffect`, after hydration (ui § 43) |
| FC-DECOY-05 | `apps/shop/lib/server/catalog.ts:1` | FC-SSR-03b | the guard is present; the token never reaches a client bundle |
| FC-DECOY-06 | `packages/widgets/vite.config.ts:8` | FC-BND-01 | plugin-legacy emits nomodule chunks that modern browsers never fetch, for a partner audience that needs them (precedents/performance § 89) |
| FC-DECOY-07 | `apps/shop/components/account/ReorderButton.tsx:13` | FC-CD-04a | `invalidateOrders` wraps `invalidateQueries({ queryKey: ['orders'] })` |
| FC-DECOY-08 | `apps/shop/components/search/AddressLookup.tsx:17` | FC-CD-03a | each keystroke aborts the previous request in the effect cleanup |
| FC-DECOY-09 | `apps/shop/components/cart/BasketBadge.tsx:11` | FC-I18N-03a | an ICU `plural` message with every Arabic category in the catalog |
| FC-DECOY-10 | `apps/shop/components/cart/SubstitutionNote.tsx:10` | FC-I18N-05a | `ms-4` is the logical (RTL-aware) utility |
| FC-DECOY-11 | `apps/shop/tests/unit/HoldTimer.test.tsx:19` | FC-RC-02a | the test proves `HoldTimer` clears its interval on unmount |
| FC-DECOY-12 | `apps/admin/src/components/KeyboardShortcuts.vue:13` | FC-RC-02b | the listener is removed on unmount |
| FC-DECOY-13 | `apps/shop/components/marketing/ConsentScripts.tsx:18` | FC-CP-02a | GTM loads only after analytics consent, with `lazyOnload` |
| FC-DECOY-14 | `apps/admin/src/main.ts:31` | FC-BND-03 | behind a literal `import.meta.env.DEV`, so Vite drops it from the production build |
| FC-DECOY-15 | `apps/admin/index.html:22` | FC-CP-01a | `async defer` never blocks rendering |
| FC-DECOY-16 | `apps/shop/app/[locale]/(shop)/recipes/[[...tags]]/page.tsx:16` | FC-RT-04a | an unknown tag (or more than one segment) calls `notFound()` |
| FC-DECOY-17 | `apps/admin/src/views/PickerDetailView.vue:11` | FC-RT-03b | the param is validated with zod and an invalid id shows not-found |
| FC-DECOY-18 | `apps/shop/app/[locale]/checkout/layout.tsx:6` | FC-RT-06a | a server-side guard in the layout; nothing renders for a signed-out visitor |
| FC-DECOY-19 | `apps/shop/app/[locale]/(shop)/c/[...slug]/page.tsx:23` | FC-RT-07b | `Pagination` is inside the page's `<Suspense>` |
| FC-DECOY-20 | `packages/widgets/src/angular/basket-button.component.ts:21` | FC-RC-02b | the subscription ends with the component (ui § 46) |
| FC-DECOY-21 | `apps/shop/components/account/AddressBook.tsx:16` | FC-RC-05b | the key changes only when a lookup match is picked: resetting the form to that address is the intent |

```decoy
id:       FC-DECOY-01
file:     apps/shop/components/layout/Footer.tsx
line:     17
command:  /frontend-audit
class:    decoy/index-key-static-list
anchor:   <li key={i}>
match:    key|index
```

```decoy
id:       FC-DECOY-02
file:     apps/shop/components/layout/Footer.tsx
line:     25
command:  /frontend-audit
class:    decoy/suppress-hydration-timestamp
anchor:   <time suppressHydrationWarning>
match:    hydrat|mismatch|suppress|Date
```

```decoy
id:       FC-DECOY-03
file:     apps/shop/lib/queries.ts
line:     10
command:  /frontend-audit
class:    decoy/same-key-twice
anchor:   export function useProfile() {
match:    duplicate|twice|same (key|query|request)|dedup
```

```decoy
id:       FC-DECOY-04
file:     apps/shop/components/product/DeliveryEta.tsx
line:     13
command:  /frontend-audit
class:    decoy/date-in-effect
anchor:   const now = new Date();
match:    hydrat|mismatch|Date|nondetermin
```

```decoy
id:       FC-DECOY-05
file:     apps/shop/lib/server/catalog.ts
line:     1
command:  /frontend-audit
class:    decoy/server-only-guard
anchor:   import 'server-only';
match:    server-only|secret|env|client
```

```decoy
id:       FC-DECOY-06
file:     packages/widgets/vite.config.ts
line:     8
command:  /frontend-audit
class:    decoy/plugin-legacy-nomodule
anchor:   plugins: [legacy(
match:    legacy|polyfill|target|transpil
```

```decoy
id:       FC-DECOY-07
file:     apps/shop/components/account/ReorderButton.tsx
line:     13
command:  /frontend-audit
class:    decoy/invalidate-via-helper
anchor:   onSuccess: () => invalidateOrders(qc),
match:    invalidat|stale|cache
```

```decoy
id:       FC-DECOY-08
file:     apps/shop/components/search/AddressLookup.tsx
line:     17
command:  /frontend-audit
class:    decoy/abort-controller-search
anchor:   const controller = new AbortController();
match:    race|out.of.order|abort|cancel
```

```decoy
id:       FC-DECOY-09
file:     apps/shop/components/cart/BasketBadge.tsx
line:     11
command:  /frontend-audit
class:    decoy/icu-plural
anchor:   t('count', { count })
match:    plural|ICU|count
```

```decoy
id:       FC-DECOY-10
file:     apps/shop/components/cart/SubstitutionNote.tsx
line:     10
command:  /frontend-audit
class:    decoy/logical-margin
anchor:   className="ms-4"
match:    rtl|ml-|margin|logical|physical
```

```decoy
id:       FC-DECOY-11
file:     apps/shop/tests/unit/HoldTimer.test.tsx
line:     19
command:  /frontend-audit
class:    decoy/clean-unmount-test
anchor:   expect(vi.getTimerCount()).toBe(0);
match:    cleanup|leak|interval|timer
```

```decoy
id:       FC-DECOY-12
file:     apps/admin/src/components/KeyboardShortcuts.vue
line:     13
command:  /frontend-audit
class:    decoy/vue-onunmounted
anchor:   onUnmounted(() => window.removeEventListener('keydown', onKey));
match:    cleanup|leak|listener|remove
```

```decoy
id:       FC-DECOY-13
file:     apps/shop/components/marketing/ConsentScripts.tsx
line:     18
command:  /frontend-audit
class:    decoy/consent-gated-tag
anchor:   strategy="lazyOnload"
match:    third.?party|gtm|googletagmanager|strategy|consent|block
```

```decoy
id:       FC-DECOY-14
file:     apps/admin/src/main.ts
line:     31
command:  /frontend-audit
class:    decoy/dev-only-dynamic-import
anchor:   const { worker } = await import('./mocks/browser');
match:    msw|mock|dev.?only|production|bundle
```

```decoy
id:       FC-DECOY-15
file:     apps/admin/index.html
line:     22
command:  /frontend-audit
class:    decoy/async-third-party
anchor:   <script async defer data-domain=
match:    render.?block|sync|blocking|plausible
```

```decoy
id:       FC-DECOY-16
file:     apps/shop/app/[locale]/(shop)/recipes/[[...tags]]/page.tsx
line:     16
command:  /frontend-audit
class:    decoy/catch-all-with-notfound
anchor:   notFound();
match:    404|not.?found|soft|catch.?all
```

```decoy
id:       FC-DECOY-17
file:     apps/admin/src/views/PickerDetailView.vue
line:     11
command:  /frontend-audit
class:    decoy/validated-param
anchor:   .safeParse(route.params.id)
match:    validat|NaN|parse|param
```

```decoy
id:       FC-DECOY-18
file:     apps/shop/app/[locale]/checkout/layout.tsx
line:     6
command:  /frontend-audit
class:    decoy/server-redirect-guard
anchor:   if (!session) redirect('/login?returnTo=/checkout');
match:    guard|redirect|flash|client
```

```decoy
id:       FC-DECOY-19
file:     apps/shop/app/[locale]/(shop)/c/[...slug]/page.tsx
line:     23
command:  /frontend-audit
class:    decoy/search-params-in-suspense
anchor:   <Pagination pages={4} />
match:    suspense|useSearchParams
```

```decoy
id:       FC-DECOY-20
file:     packages/widgets/src/angular/basket-button.component.ts
line:     21
command:  /frontend-audit
class:    decoy/take-until-destroyed
anchor:   takeUntilDestroyed(this.destroyRef),
match:    cleanup|leak|unsubscribe|subscription
```

```decoy
id:       FC-DECOY-21
file:     apps/shop/components/account/AddressBook.tsx
line:     16
command:  /frontend-audit
class:    decoy/intentional-form-reset
anchor:   <AddressForm key={line1}
match:    key|reset|controlled|remount
```

## Detector measurement — the pre-flight greps run on this fixture

Measured 2026-10-05 with ripgrep 15.2.0 (PCRE2 10.45), from this directory, each skill's pre-flight block copied
verbatim from `templates/packs/frontend/skills/<skill>/SKILL.md` as of that date, plus
`i18n-scan/scripts/catalog-parity.py . --used=./apps/admin,./apps/shop,./packages/widgets`. A seed is **caught** when a
grep prints its file (file-level greps) or a line within 6 of its anchor for the class it seeds. A decoy is **hit**
when a grep prints it for the class it imitates; every decoy hit below is refuted by the read the skill already
prescribes, so the decoy produces **0 findings**. These are grep results, not a scored `/frontend-audit` run — no run
is recorded in `RESULTS.md` yet. Run from the repo root the greps print nothing here: the skills exclude `**/fixtures/**`.

| detector | seeds it owns | caught by its greps | decoys hit by the class they imitate → findings | notes |
|----------|---------------|--------------------|-----------------------------------------------|-------|
| `render-correctness-scan` | 10 (RC-01…05 × 2) | **10 / 10** (1a, 1c, 2, 3a/3a′, 4a, 4b, 5a, 5b) | FC-DECOY-01 by 3a (`key={i}`, footer) → 0: a constant list (ui § 42). FC-DECOY-21 by 5c (`<AddressForm key={line1}>`) → 0: the reset on a picked match is the point. DECOY-11, -12, -20: 0 hits | 5a also prints `CheckoutSlots`' hidden input (`value={picked}` renders only when set — refuted) |
| `ssr-audit` | 8 (SSR-01…04 × 2) | **8 / 8** (1a, 1d, 2a, 2b, 3a, 3b, 4a, 4f) | FC-DECOY-02 by 1a/1f (`suppressHydrationWarning` on a `<time>`) → 0: ui § 44. FC-DECOY-04 by 1a (`new Date()` on its own line inside a multi-line `useEffect`) → 0: ui § 43. DECOY-05: 0 hits | noise: SPA roots scanned (IR-11), Vue `<script setup>` refs in 4f (IR-12), 3b's union globs (IR-13) |
| `client-data-scan` | 14 (CD-01…07 × 2) | **13 / 14** (1a, 2a, 3a, 4a, 5a, 6a, 6c-read, 7a, 7b); **CD-01b missed** (IR-6) | DECOY-03 (same key twice), -07 (invalidate helper), -08 (`AbortController`): 0 hits | 1a also pairs `getTranslations()` with a fetch on three pages (a local message load — refuted on read); 2a leaks multi-line `queryFn`/`mutationFn` bodies (IR-7); 6a false hit on `PickersView` (IR-8) |
| `routing-scan` | 10 (§1, §3, §4, §6, §7 × 2) | **9 / 10** (1a, 3a, 4b, 4d, 6a, 7a); **RT-07b missed** — 7a prints `SortSelect … 1 with <Suspense>` (IR-9) | DECOY-16 (catch-all with `notFound()`), -17 (zod-validated param), -18 (server `redirect()`): 0 hits in 4b / 3a / 6a; -19 printed by 7a as wrapped, which is correct for `Pagination` | 4c lists all 7 static pages under `[locale]` (IR-10); 5a lists redirect sites as context |
| `i18n-scan` + `catalog-parity.py` | 14 (I18N-01…07 × 2) | **14 / 14** — greps 1a, 3a, 3b, 4a, 4b, 5a, 5c, 6 (×2), 7a; the script's `missing-key [ar] checkout.placeOrder` (02a) and `used-undefined orders.bulkRefund` (02b); 07b by 7a on `apps/admin/index.html` plus 7b listing no back-office sync site | DECOY-09 (ICU plural), -10 (`ms-4`): 0 hits | 1a also prints the widgets' English-only strings, `index.html`'s title, `/kg` and the brand name (candidates to read); the script reports 2 cross-app `missing-file` rows (IR-15) |
| `critical-path-scan` | 6 (§1–§3 × 2) | **6 / 6** (1a, 1b, 2b, 2c, 3a, 3b) | FC-DECOY-13 by 2a (GTM host) → 0: consent-gated, `lazyOnload`. FC-DECOY-15 by 2a (plausible host) → 0: `async defer`. 3d prints the `<Suspense fallback={null}>` beside FC-DECOY-19 → 0: page-bottom pagination shifts nothing above it | 3a also prints `<ConsentScripts />` (`Consent\w*`; it renders a script tag, no box) |
| `bundle-analyze` | 4 (§6, §7 × 2) | **4 / 4** (6a, 6b, 7a, 7c) — §1–§3, 6c, 7b `blocked` (no build output), §4 `blocked` (no lockfile), §5 `blocked` (no `node_modules`) | FC-DECOY-14 (`import.meta.env.DEV` dynamic import): 0 hits. FC-DECOY-06 (`plugin-legacy`): 0 hits — but only because 6a cannot match a scoped package name at all (IR-14) | |

Totals: **64 of 66** seeds are printed by their owner's pre-flight (with `catalog-parity.py` for the two catalog
seeds); **2** are missed (CD-01b, RT-07b). **0 decoys** survive their owner's prescribed read; the 6 decoy grep hits
above are the ones that read exists to refute.

### Integrator requests (skill gaps found by this fixture — the skills are other agents' files)

- **IR-6 — `client-data-scan` 1b:** `\{[^}]{0,200}?\bawait` stops at the first `}`, so a loop whose body destructures
  the result — `for (const id of ids) { const { data } = await api.get(…) }` — is invisible (FC-CD-01b). Use a
  lazy `[\s\S]{0,200}?` bounded by the loop's own closing brace, or match `await NET` on the lines following a
  `for…of` head.
- **IR-7 — `client-data-scan` 2a:** the `queryFn|mutationFn|fetcher` exclusion is per line; a multi-line
  `queryFn: async () => {` body leaks its `api.get` line (DispatchView:22, DeliverySlots:16, AddressForm:16). Exclude
  by enclosing property (read the 3 preceding lines) or move the call-site test into a `-U` pattern.
- **IR-8 — `client-data-scan` 6a:** `[^\n]*\(\s*[a-z]\w*` treats `(await` as the fetcher's argument, so
  `queryKey: ['pickers'], queryFn: async () => (await api.get('/pickers')).data` is reported. Exclude `await`/`async`
  as the captured word.
- **IR-9 — `routing-scan` 7a:** Suspense is counted per renderer *file*: a page that wraps one `useSearchParams`
  client in `<Suspense>` reports every other such client it renders as wrapped (`SortSelect` in
  `c/[...slug]/page.tsx`, FC-RT-07b). Check JSX ancestry — the `<SortSelect` tag must sit between `<Suspense` and
  `</Suspense>` in the renderer.
- **IR-10 — `routing-scan` 4c:** `find … -path '*\[*'` matches every page below an `app/[locale]/` segment, so all
  static pages are printed as "dynamic segments with no notFound()". Test the page's own segment chain below the
  locale root, or require a bracket segment other than the first under `app/`.
- **IR-11 — `ssr-audit`:** the SSR gate is repo-wide, then every grep runs over all `ROOTS`; in this monorepo the Vue
  SPA and the Angular widget loader produce 1c, 1e, 2a and 2b hits (`main.ts`, `DeliveryRow.vue`, `LocaleSwitcher.vue`,
  `loader.ts`) that cannot hydrate. Narrow `ROOTS` to the roots whose `package.json` carries the SSR framework.
- **IR-12 — `ssr-audit` 4f:** top-level `const x = ref(…)` / `let timer` inside a Vue `<script setup>` block is
  per-component-instance state, not module scope; 6 such lines are printed. Exclude `.vue` setup blocks (in Nuxt the
  real module-scope risk lives in `.ts` composables and server routes).
- **IR-13 — `ssr-audit` 3b:** `-g '**/{lib,server,services,actions,data}/**'` followed by `"${UI[@]}"`'s `-g` globs is a
  union in ripgrep, not an intersection, so every UI file with a non-public env read is listed (a `'use client'`
  component, a server page). Filter the path with a second `rg`/`grep` stage instead.
- **IR-14 — `bundle-analyze` 6a:** `\b(?:…|@babel/polyfill|@vitejs/plugin-legacy|…)\b` can never match the two scoped
  names: `\b` needs a word character beside it and `@` is not one. `packages/widgets`' `@vitejs/plugin-legacy` import
  and dependency are invisible. Use `(?<![\w@/.-])` before the alternation.
- **IR-15 — `i18n-scan/scripts/catalog-parity.py`:** catalog sets from different apps of a monorepo are folded into one
  family, so `apps/admin` (en, de) is told it lacks `ar` and `apps/shop` (en, ar) that it lacks `de`. Scope the
  declared-locale set per catalog set (or per nearest `package.json`).
