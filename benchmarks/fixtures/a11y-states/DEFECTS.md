# Seeded defects — `a11y-states`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `Lumen Home` — Next.js 16 App Router + React 19 storefront (TanStack Query 5, Tailwind 4, next-intl, Radix, motion, Recharts), Vue 3.5 + Vite back office (Pinia, vue-i18n, TanStack Vue Query, chart.js), and Angular 22 + Svelte 5 partner widgets.
Accessibility (WCAG 2.2 AA), UI-state, state-matrix, motion, design-token and chart-encoding defects — the frontend + ui-ux
counterpart of `vuln-fullstack` — seeded across the storefront, the back office, the widgets and a design-time state
matrix, plus decoys: correct siblings that look like a seeded defect and must NOT be reported.

Invocation: /frontend-audit --whole-repo --classes=a11y,states,tokens,charts
Stage with: --git — `/frontend-audit` reads the history for its context map and `state-matrix-lint.py --base` lists
touched files with `git diff`; an un-initialised copy has neither.

Eval source: Track A batch 3, item 47 (FX-1). Classes follow that eval's class map: `A11Y-nn` (§ 2.1), `ST-nn` (§ 2.3),
`VIS-05/06` and `VIS-01` (§ 2.8), and the state-matrix lint kinds (`state-matrix` skill). Two deliberate departures from
FX-1's table, both stated here so a reader can audit them: the Angular and Svelte widgets carry one a11y seed (A11Y-06)
and two decoys instead of a seed per class (the eval asks for lane coverage only), and the visual family (motion, tokens,
charts) is added because no other fixture had motion or chart code.

What makes the fixture measure more than keyword recall: most seeds have a correct sibling in the same tree.
`Chip` drops its focus ring where `Button` keeps a `focus-visible:ring`; `AddressDialog` hand-rolls a dialog beside the
native `<dialog>.showModal()` in `ConfirmDeleteDialog` and the Radix drawer in `CartDrawer`; `GiftCardsPanel` shows a
retry for a 403 that `StoreCreditPanel` tells apart; `OrdersPanel` has no loading branch because `OrdersTable` owns
them all. Several seeds are only defects once a value is computed: the dark `--color-muted-foreground` is 2.35:1 on the
dark background (the light pair is 7.63:1), and the back office's dark `--text-subtle` is 2.76:1.

Ownership. Every row names the detector that owns its class: frontend `a11y-code-scan` (static WCAG), `a11y-scan`
(rendered WCAG and gate integrity), ui-ux `ui-state-scan`, `state-matrix-lint.py`, `motion-audit`,
`design-token-audit`, `chart-encoding-audit`. `/frontend-audit` dispatches all of them; `chart-encoding-audit` is its
`charts` row since 2026-10-10 (integrator request IR-1, fixed), so every row is scored under `/frontend-audit`, the
whole-repo UI audit this fixture runs.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap. If you edit fixture source, re-run it.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| AS-A11Y-01a | `apps/shop/components/product/ProductCard.tsx:22` | medium | `/frontend-audit` | a11y/non-semantic-control |
| AS-A11Y-01b | `apps/admin/src/views/OrdersView.vue:46` | high | `/frontend-audit` | a11y/non-semantic-control |
| AS-A11Y-02a | `apps/shop/components/product/WishlistButton.tsx:27` | high | `/frontend-audit` | a11y/missing-name-icon |
| AS-A11Y-02b | `apps/admin/src/components/FilterChip.vue:9` | high | `/frontend-audit` | a11y/missing-name-glyph |
| AS-A11Y-03a | `apps/shop/components/layout/SiteSearch.tsx:23` | high | `/frontend-audit` | a11y/input-no-label |
| AS-A11Y-03b | `apps/admin/src/views/CustomersView.vue:25` | high | `/frontend-audit` | a11y/input-no-label |
| AS-A11Y-04a | `apps/shop/components/ui/Chip.tsx:17` | medium | `/frontend-audit` | a11y/focus-indicator-removed |
| AS-A11Y-04b | `apps/admin/src/styles/base.css:53` | high | `/frontend-audit` | a11y/focus-indicator-removed |
| AS-A11Y-05a | `apps/shop/components/account/AddressDialog.tsx:22` | high | `/frontend-audit` | a11y/dialog-focus |
| AS-A11Y-05b | `apps/admin/src/components/RefundDrawer.vue:14` | high | `/frontend-audit` | a11y/dialog-focus |
| AS-A11Y-06a | `apps/admin/src/router.ts:4` | high | `/frontend-audit` | a11y/route-change-unannounced |
| AS-A11Y-06b | `packages/widgets/src/angular/app.config.ts:10` | medium | `/frontend-audit` | a11y/route-change-unannounced |
| AS-A11Y-07a | `apps/shop/components/ui/Toast.tsx:22` | medium | `/frontend-audit` | a11y/status-not-announced |
| AS-A11Y-07b | `apps/admin/src/views/SettingsView.vue:34` | medium | `/frontend-audit` | a11y/status-not-announced |
| AS-A11Y-08a | `apps/shop/components/checkout/ContactForm.tsx:28` | high | `/frontend-audit` | a11y/field-error-not-associated |
| AS-A11Y-08b | `apps/admin/src/components/RefundForm.vue:34` | high | `/frontend-audit` | a11y/field-error-not-associated |
| AS-A11Y-14a | `apps/shop/components/product/ProductGallery.tsx:17` | medium | `/frontend-audit` | a11y/positive-tabindex |
| AS-A11Y-14b | `apps/admin/src/components/AppSidebar.vue:24` | high | `/frontend-audit` | a11y/aria-hidden-focusable |
| AS-A11Y-15a | `apps/shop/components/product/ProductTabs.tsx:15` | medium | `/frontend-audit` | a11y/composite-no-keyboard-model |
| AS-A11Y-15b | `apps/admin/src/components/StatusFilter.vue:7` | high | `/frontend-audit` | a11y/composite-no-keyboard-model |
| AS-A11Y-17a | `apps/shop/components/account/SavedListsSortable.tsx:35` | high | `/frontend-audit` | a11y/dragging-only |
| AS-A11Y-17b | `apps/admin/src/views/MenuBuilderView.vue:24` | high | `/frontend-audit` | a11y/dragging-only |
| AS-A11Y-18a | `apps/shop/components/auth/SignInForm.tsx:46` | high | `/frontend-audit` | a11y/auth-paste-blocked |
| AS-A11Y-18b | `apps/admin/src/views/LoginView.vue:40` | medium | `/frontend-audit` | a11y/auth-autocomplete-off |
| AS-A11Y-09a | `apps/shop/app/[locale]/globals.css:26` | high | `/frontend-audit` | a11y/contrast-dark-theme |
| AS-A11Y-09b | `apps/admin/src/styles/tokens.css:31` | high | `/frontend-audit` | a11y/contrast-dark-theme |
| AS-A11Y-11a | `apps/shop/components/cart/CartLine.tsx:30` | medium | `/frontend-audit` | a11y/target-size |
| AS-A11Y-11b | `apps/admin/src/components/Pagination.vue:29` | medium | `/frontend-audit` | a11y/target-size |
| AS-A11Y-12a | `apps/shop/app/[locale]/layout.tsx:16` | high | `/frontend-audit` | a11y/zoom-disabled |
| AS-A11Y-12b | `apps/admin/src/styles/base.css:17` | medium | `/frontend-audit` | a11y/reflow |
| AS-A11Y-16a | `apps/shop/components/layout/SiteHeader.tsx:17` | medium | `/frontend-audit` | a11y/focus-obscured |
| AS-A11Y-16b | `apps/admin/src/components/CookieNotice.vue:23` | medium | `/frontend-audit` | a11y/focus-obscured |
| AS-A11Y-22a | `apps/shop/.storybook/preview.ts:11` | high | `/frontend-audit` | a11y/gate-neutered |
| AS-A11Y-22b | `apps/admin/e2e/a11y.spec.ts:11` | high | `/frontend-audit` | a11y/gate-neutered |
| AS-ST-01a | `apps/shop/components/home/RecentlyViewed.tsx:25` | medium | `/frontend-audit` | states/no-loading |
| AS-ST-01b | `apps/admin/src/views/CustomersView.vue:10` | medium | `/frontend-audit` | states/no-loading |
| AS-ST-02a | `apps/shop/components/account/WishlistGrid.tsx:30` | medium | `/frontend-audit` | states/no-empty |
| AS-ST-02b | `apps/admin/src/views/InvoicesView.vue:31` | medium | `/frontend-audit` | states/no-empty |
| AS-ST-03a | `apps/shop/components/product/ReviewsList.tsx:17` | medium | `/frontend-audit` | states/error-as-empty |
| AS-ST-03b | `apps/admin/src/stores/notifications.ts:17` | medium | `/frontend-audit` | states/error-as-empty |
| AS-ST-04a | `apps/shop/app/[locale]/account/layout.tsx:6` | high | `/frontend-audit` | states/no-error-boundary |
| AS-ST-04b | `apps/admin/src/views/ReportsView.vue:23` | medium | `/frontend-audit` | states/error-no-recovery |
| AS-ST-05a | `apps/shop/app/[locale]/account/page.tsx:14` | high | `/frontend-audit` | states/partial-failure |
| AS-ST-05b | `apps/admin/src/views/DashboardView.vue:21` | medium | `/frontend-audit` | states/partial-failure |
| AS-ST-06a | `apps/shop/components/account/GiftCardsPanel.tsx:14` | medium | `/frontend-audit` | states/permission-as-error |
| AS-ST-06b | `apps/admin/src/views/AuditLogView.vue:15` | high | `/frontend-audit` | states/permission-as-empty |
| AS-ST-07a | `apps/shop/components/cart/CartSync.tsx:17` | medium | `/frontend-audit` | states/offline-write-lost |
| AS-ST-07b | `apps/admin/src/components/NotesEditor.vue:13` | high | `/frontend-audit` | states/offline-write-lost |
| AS-ST-08a | `apps/shop/components/checkout/PlaceOrderButton.tsx:21` | high | `/frontend-audit` | states/pending-submit |
| AS-ST-08b | `apps/admin/src/components/RefundForm.vue:31` | high | `/frontend-audit` | states/pending-submit |
| AS-ST-10a | `apps/shop/components/account/ProfileForm.tsx:19` | medium | `/frontend-audit` | states/unsaved-changes |
| AS-ST-10b | `apps/admin/src/views/ProductEditView.vue:13` | medium | `/frontend-audit` | states/unsaved-changes |
| AS-SM-01 | `ai/design/state-matrix/checkout.md:9` | medium | `/frontend-audit` | matrix/state-missing |
| AS-SM-02 | `ai/design/state-matrix/checkout.md:10` | medium | `/frontend-audit` | matrix/state-missing |
| AS-SM-03 | `ai/design/state-matrix/checkout.md:17` | low | `/frontend-audit` | matrix/na-without-reason |
| AS-SM-04 | `ai/design/state-matrix/checkout.md:27` | low | `/frontend-audit` | matrix/na-without-reason |
| AS-SM-05 | `ai/design/state-matrix/checkout.md:20` | medium | `/frontend-audit` | matrix/proof-not-a-test |
| AS-SM-06 | `ai/design/state-matrix/checkout.md:28` | medium | `/frontend-audit` | matrix/proof-not-a-test |
| AS-SM-07 | `ai/design/state-matrix/checkout.md:16` | medium | `/frontend-audit` | matrix/proof-missing |
| AS-SM-08 | `ai/design/state-matrix/checkout.md:24` | medium | `/frontend-audit` | matrix/proof-missing |
| AS-MO-01a | `apps/shop/components/home/CategoryTile.tsx:12` | low | `/frontend-audit` | visual/transition-all |
| AS-MO-01b | `apps/admin/src/styles/base.css:66` | low | `/frontend-audit` | visual/transition-all |
| AS-MO-02a | `apps/shop/components/product/CareAccordion.tsx:26` | medium | `/frontend-audit` | visual/layout-property-animated |
| AS-MO-02b | `apps/admin/src/styles/base.css:78` | medium | `/frontend-audit` | visual/layout-property-animated |
| AS-MO-03a | `apps/shop/components/home/HeroParallax.tsx:8` | high | `/frontend-audit` | visual/no-reduced-motion |
| AS-MO-03b | `apps/admin/src/components/KpiCounter.vue:12` | medium | `/frontend-audit` | visual/no-reduced-motion |
| AS-MO-04a | `apps/shop/components/home/HeroCarousel.tsx:11` | high | `/frontend-audit` | visual/auto-moving-content |
| AS-MO-04b | `apps/admin/src/components/AnnouncementTicker.vue:29` | high | `/frontend-audit` | visual/auto-moving-content |
| AS-TK-01a | `apps/shop/components/product/rating.module.css:6` | high | `/frontend-audit` | visual/raw-colour-literal |
| AS-TK-01b | `apps/admin/src/components/StatusPill.vue:24` | medium | `/frontend-audit` | visual/raw-colour-literal |
| AS-TK-02a | `apps/shop/components/layout/PromoStrip.tsx:8` | medium | `/frontend-audit` | visual/arbitrary-value |
| AS-TK-02b | `apps/shop/components/account/LoyaltyBadge.tsx:7` | medium | `/frontend-audit` | visual/arbitrary-value |
| AS-TK-04a | `apps/shop/components/layout/SiteHeader.tsx:42` | low | `/frontend-audit` | visual/z-index-magic |
| AS-TK-04b | `apps/admin/src/components/CookieNotice.vue:34` | low | `/frontend-audit` | visual/z-index-magic |
| AS-TK-08a | `apps/shop/components/product/ProductMeta.tsx:8` | medium | `/frontend-audit` | visual/default-palette |
| AS-TK-08b | `apps/shop/components/checkout/CouponField.tsx:47` | medium | `/frontend-audit` | visual/default-palette |
| AS-CH-02a | `apps/shop/components/account/SpendChart.tsx:26` | high | `/frontend-audit` | visual/truncated-baseline |
| AS-CH-02b | `apps/admin/src/components/charts/RevenueBars.vue:27` | high | `/frontend-audit` | visual/truncated-baseline |
| AS-CH-05a | `apps/shop/components/account/PointsTrend.tsx:26` | high | `/frontend-audit` | visual/gaps-drawn-as-data |
| AS-CH-05b | `apps/admin/src/components/charts/SignupsLine.vue:19` | high | `/frontend-audit` | visual/gaps-drawn-as-data |
| AS-CH-06a | `apps/shop/components/account/SpendChart.tsx:30` | high | `/frontend-audit` | visual/colour-only-red-green |
| AS-CH-06b | `apps/admin/src/components/charts/RevenueBars.vue:17` | high | `/frontend-audit` | visual/colour-only-red-green |

Severity split: 37 high · 39 medium · 6 low. Total 82 seeded defects, 23 decoys.

### Coverage by class

One row per detector §; every row carries at least two seeds. Family `a11y` is WCAG 2.2 AA (the SC is in each section); `states` is the UI-state ledger;
`matrix` is G12's computational half; `visual` is motion (`a11y` row of the ledger), tokens and charts.

| family | detector § | classes | seeded | ids |
|--------|------------|---------|--------|-----|
| a11y | `a11y-code-scan` §1 | a11y/non-semantic-control | 2 | AS-A11Y-01a, AS-A11Y-01b |
| a11y | `a11y-code-scan` §2 | a11y/missing-name-icon, a11y/missing-name-glyph, a11y/input-no-label | 4 | AS-A11Y-02a, AS-A11Y-02b, AS-A11Y-03a, AS-A11Y-03b |
| a11y | `a11y-code-scan` §3 | a11y/focus-indicator-removed | 2 | AS-A11Y-04a, AS-A11Y-04b |
| a11y | `a11y-code-scan` §4 | a11y/dialog-focus | 2 | AS-A11Y-05a, AS-A11Y-05b |
| a11y | `a11y-code-scan` §5 | a11y/route-change-unannounced | 2 | AS-A11Y-06a, AS-A11Y-06b |
| a11y | `a11y-code-scan` §6 | a11y/status-not-announced, a11y/field-error-not-associated | 4 | AS-A11Y-07a, AS-A11Y-07b, AS-A11Y-08a, AS-A11Y-08b |
| a11y | `a11y-code-scan` §8 | a11y/positive-tabindex, a11y/aria-hidden-focusable | 2 | AS-A11Y-14a, AS-A11Y-14b |
| a11y | `a11y-code-scan` §9 | a11y/composite-no-keyboard-model | 2 | AS-A11Y-15a, AS-A11Y-15b |
| a11y | `a11y-code-scan` §10 | a11y/dragging-only | 2 | AS-A11Y-17a, AS-A11Y-17b |
| a11y | `a11y-code-scan` §11 | a11y/auth-paste-blocked, a11y/auth-autocomplete-off | 2 | AS-A11Y-18a, AS-A11Y-18b |
| a11y | `a11y-scan` §3 | a11y/contrast-dark-theme | 2 | AS-A11Y-09a, AS-A11Y-09b |
| a11y | `a11y-scan` §5 | a11y/target-size | 2 | AS-A11Y-11a, AS-A11Y-11b |
| a11y | `a11y-scan` §6 | a11y/zoom-disabled, a11y/reflow | 2 | AS-A11Y-12a, AS-A11Y-12b |
| a11y | `a11y-scan` §4 | a11y/focus-obscured | 2 | AS-A11Y-16a, AS-A11Y-16b |
| a11y | `a11y-scan` §7 | a11y/gate-neutered | 2 | AS-A11Y-22a, AS-A11Y-22b |
| states | `ui-state-scan` §1 | states/no-loading | 2 | AS-ST-01a, AS-ST-01b |
| states | `ui-state-scan` §2 | states/no-empty | 2 | AS-ST-02a, AS-ST-02b |
| states | `ui-state-scan` §3 | states/error-as-empty | 2 | AS-ST-03a, AS-ST-03b |
| states | `ui-state-scan` §4 | states/no-error-boundary, states/error-no-recovery | 2 | AS-ST-04a, AS-ST-04b |
| states | `ui-state-scan` §5 | states/partial-failure | 2 | AS-ST-05a, AS-ST-05b |
| states | `ui-state-scan` §6 | states/permission-as-error, states/permission-as-empty | 2 | AS-ST-06a, AS-ST-06b |
| states | `ui-state-scan` §7 | states/offline-write-lost | 2 | AS-ST-07a, AS-ST-07b |
| states | `ui-state-scan` §8 | states/pending-submit | 2 | AS-ST-08a, AS-ST-08b |
| states | `ui-state-scan` §10 | states/unsaved-changes | 2 | AS-ST-10a, AS-ST-10b |
| matrix | `state-matrix-lint.py` (state-missing) | matrix/state-missing | 2 | AS-SM-01, AS-SM-02 |
| matrix | `state-matrix-lint.py` (na-without-reason) | matrix/na-without-reason | 2 | AS-SM-03, AS-SM-04 |
| matrix | `state-matrix-lint.py` (proof-not-a-test) | matrix/proof-not-a-test | 2 | AS-SM-05, AS-SM-06 |
| matrix | `state-matrix-lint.py` (proof-missing) | matrix/proof-missing | 2 | AS-SM-07, AS-SM-08 |
| visual | `motion-audit` §1 | visual/transition-all | 2 | AS-MO-01a, AS-MO-01b |
| visual | `motion-audit` §2 | visual/layout-property-animated | 2 | AS-MO-02a, AS-MO-02b |
| visual | `motion-audit` §3 | visual/no-reduced-motion | 2 | AS-MO-03a, AS-MO-03b |
| visual | `motion-audit` §5 | visual/auto-moving-content | 2 | AS-MO-04a, AS-MO-04b |
| visual | `design-token-audit` §1 | visual/raw-colour-literal | 2 | AS-TK-01a, AS-TK-01b |
| visual | `design-token-audit` §2 | visual/arbitrary-value | 2 | AS-TK-02a, AS-TK-02b |
| visual | `design-token-audit` §4 | visual/z-index-magic | 2 | AS-TK-04a, AS-TK-04b |
| visual | `design-token-audit` §8 | visual/default-palette | 2 | AS-TK-08a, AS-TK-08b |
| visual | `chart-encoding-audit` §2 | visual/truncated-baseline | 2 | AS-CH-02a, AS-CH-02b |
| visual | `chart-encoding-audit` §5 | visual/gaps-drawn-as-data | 2 | AS-CH-05a, AS-CH-05b |
| visual | `chart-encoding-audit` §6 | visual/colour-only-red-green | 2 | AS-CH-06a, AS-CH-06b |
| **decoys (must not be reported)** | — | — | **23** | AS-DECOY-01 … AS-DECOY-23 |

---

## AS-A11Y-01a — Quick-add is a clickable `div`

```defect
id:       AS-A11Y-01a
file:     apps/shop/components/product/ProductCard.tsx
line:     22
severity: medium
command:  /frontend-audit
class:    a11y/non-semantic-control
anchor:   onClick={() => onQuickAdd(product.id)}
match:    div|non.?semantic|not (a )?button|keyboard|tab|focus|2\.1\.1|click.?handler|role
```

The hover overlay that adds the product to the cart is a `div` with `onClick` and no role, `tabIndex` or key
handler: keyboard and switch users never reach it (2.1.1 A, 4.1.2 A). Medium, not high: the product page's
**Add to cart** is an equivalent path one click away. Fix: render the overlay as `<button type="button">` (the shared
`Button`). Proof: keyboard path — Tab through `/account/wishlist`; the quick-add control is never focused (V87).

## AS-A11Y-01b — Order rows open the refund drawer from a clickable `<li>`

```defect
id:       AS-A11Y-01b
file:     apps/admin/src/views/OrdersView.vue
line:     46
severity: high
command:  /frontend-audit
class:    a11y/non-semantic-control
anchor:   <li v-for="o in orders"
match:    \bli\b|list item|non.?semantic|not (a )?button|keyboard|tab|focus|2\.1\.1|@click|click
```

`<li … @click="select(o.id)">` is the only way to open an order's refund drawer, and it has no role, no tabindex
and no key handler (2.1.1 A). High: the sole path to a primary staff action. Fix: a `<button>` inside the row (or a
`RouterLink` to an order route). Proof: keyboard path on `/orders` — Enter on a row does nothing (V87).

## AS-A11Y-02a — Wishlist heart button has no accessible name

```defect
id:       AS-A11Y-02a
file:     apps/shop/components/product/WishlistButton.tsx
line:     27
severity: high
command:  /frontend-audit
class:    a11y/missing-name-icon
anchor:   <button
match:    name|label|icon.?only|heart|4\.1\.2|1\.1\.1|aria-label|button-name
```

The button's only child is a lucide `<Heart>` SVG with no title: a screen reader announces "button, toggle
button, not pressed" (4.1.2 A). It sits on every product card. Fix: `aria-label={t('wishlist')}` and `aria-hidden` on
the icon. Proof: `getByRole('button', { name: /wishlist/i })` finds nothing; axe `button-name` (V88).

## AS-A11Y-02b — Filter-chip remove button is a bare `×`

```defect
id:       AS-A11Y-02b
file:     apps/admin/src/components/FilterChip.vue
line:     9
severity: high
command:  /frontend-audit
class:    a11y/missing-name-glyph
anchor:   <button class="chip-remove"
match:    name|label|glyph|×|times|multiplication|4\.1\.2|aria-label|button-name
```

The only content is the `×` glyph, read as "times" or "multiplication sign" (4.1.2 A, 2.4.6). Fix:
`aria-label="Remove filter {label}"` with the glyph `aria-hidden`. Proof: role query by name; axe `button-name`.
The storefront's `CartDrawer` close button (AS-DECOY-05) is the correct shape.

## AS-A11Y-03a — Site search input labelled only by its placeholder

```defect
id:       AS-A11Y-03a
file:     apps/shop/components/layout/SiteSearch.tsx
line:     23
severity: high
command:  /frontend-audit
class:    a11y/input-no-label
anchor:   <input
match:    label|placeholder|name|3\.3\.2|1\.3\.1|4\.1\.2
```

`<input type="search" placeholder={t('placeholder')}>` has no `<label>`, `id`, `aria-label` or
`aria-labelledby`; the placeholder disappears on input and is not a reliable name (1.3.1 A, 3.3.2 A). Fix:
`aria-label={t('placeholder')}` or a visually hidden label. Proof: `getByRole('searchbox', { name })` fails; axe `label`.

## AS-A11Y-03b — Customer filter labelled only by its placeholder

```defect
id:       AS-A11Y-03b
file:     apps/admin/src/views/CustomersView.vue
line:     25
severity: high
command:  /frontend-audit
class:    a11y/input-no-label
anchor:   placeholder="Filter customers"
match:    label|placeholder|name|3\.3\.2|1\.3\.1|4\.1\.2
```

Same class in the back office: `<input v-model="query" placeholder="Filter customers">` with no label
(1.3.1 A, 3.3.2 A). Proof: axe `label` on `/customers`.

## AS-A11Y-04a — `Chip` removes the outline with no replacement ring

```defect
id:       AS-A11Y-04a
file:     apps/shop/components/ui/Chip.tsx
line:     17
severity: medium
command:  /frontend-audit
class:    a11y/focus-indicator-removed
anchor:   hover:bg-muted focus:outline-none
match:    focus|outline|ring|2\.4\.7|indicator
```

`focus:outline-none` with no `focus-visible:ring-*`, border or shadow on the line or anywhere in the component:
a keyboard user cannot see which wishlist filter chip is focused (2.4.7 AA). The shared `Button` keeps
`focus:outline-none focus-visible:ring-2` (AS-DECOY-01). Tailwind 4 `outline-none` sets `outline-style: none`
(precedents/ui § 55). Proof: focus-visible pixel delta = 0 (V89).

## AS-A11Y-04b — Sidebar links: `outline: none` on `:focus` with nothing in its place

```defect
id:       AS-A11Y-04b
file:     apps/admin/src/styles/base.css
line:     53
severity: high
command:  /frontend-audit
class:    a11y/focus-indicator-removed
anchor:   .nav-link:focus {
match:    focus|outline|2\.4\.7|indicator|nav.?link
```

`.nav-link:focus { outline: none; }` and no `:focus-visible` rule for `.nav-link` anywhere: every sidebar link
loses its focus indicator (2.4.7 AA). High: the sidebar is the back office's navigation. The `.btn` rule above uses
`:focus:not(:focus-visible)` and a `:focus-visible` outline (AS-DECOY-16). Proof: focus-visible delta (V89).

## AS-A11Y-05a — Hand-rolled address dialog: no initial focus, no trap, no Escape, no return

```defect
id:       AS-A11Y-05a
file:     apps/shop/components/account/AddressDialog.tsx
line:     22
severity: high
command:  /frontend-audit
class:    a11y/dialog-focus
anchor:   <div role="dialog" aria-modal="true" aria-labelledby="address-title"
match:    focus|trap|escape|esc\b|dialog|modal|2\.1\.2|2\.4\.3|inert
```

`role="dialog" aria-modal="true"` on a plain `div`: opening leaves focus on the trigger behind the scrim, Tab walks
the page underneath, Escape does nothing and closing drops focus to `body` (2.1.2 A, 2.4.3 A). The repo already ships
two correct shapes — native `<dialog>.showModal()` (AS-DECOY-02) and Radix Dialog (AS-DECOY-03). Proof: keyboard
path (V90) — Tab × 10 leaves the dialog; `document.activeElement` after close is `body`.

## AS-A11Y-05b — Refund drawer declares `aria-modal` and manages no focus

```defect
id:       AS-A11Y-05b
file:     apps/admin/src/components/RefundDrawer.vue
line:     14
severity: high
command:  /frontend-audit
class:    a11y/dialog-focus
anchor:   <aside role="dialog" aria-modal="true"
match:    focus|trap|escape|esc\b|dialog|drawer|modal|2\.1\.2|2\.4\.3|inert
```

Same class in Vue: the drawer never moves focus inside, does not trap Tab, ignores Escape and does not restore
focus to the order row (2.1.2 A, 2.4.3 A). Proof: keyboard path (V90) on `/orders` → open an order.

## AS-A11Y-06a — Back-office router: no per-route title, no focus move, no announcement

```defect
id:       AS-A11Y-06a
file:     apps/admin/src/router.ts
line:     4
severity: high
command:  /frontend-audit
class:    a11y/route-change-unannounced
anchor:   export const router = createRouter({
match:    title|announce|route|navigation|focus|2\.4\.2|4\.1\.3|live
```

Vue Router has no built-in announcer (precedents/ui § 27). No route sets a title (`index.html`'s
"Lumen back office" is the title of every screen), nothing moves focus after navigation, and `App.vue` mounts no live
region (2.4.2 A, 2.4.3 A, 4.1.3 AA). High because every title is identical. Proof: click a sidebar link; assert
`document.title` changed and focus moved to the new `h1` (V92).

## AS-A11Y-06b — Angular widgets router: no route titles, no TitleStrategy

```defect
id:       AS-A11Y-06b
file:     packages/widgets/src/angular/app.config.ts
line:     10
severity: medium
command:  /frontend-audit
class:    a11y/route-change-unannounced
anchor:   provideRouter(
match:    title|announce|route|navigation|focus|2\.4\.2|4\.1\.3|TitleStrategy
```

`provideRouter(routes, …)` with no `title` on any route in `app.routes.ts` and no `TitleStrategy`; the Angular
Router announces nothing (2.4.2 A, 4.1.3 AA). Medium: an embedded widget, but its routes replace the partner page's
content. Proof: navigate `stores` → `newsletter`; title and live region unchanged (V92).

## AS-A11Y-07a — Custom `Toast` renders with no live region

```defect
id:       AS-A11Y-07a
file:     apps/shop/components/ui/Toast.tsx
line:     22
severity: medium
command:  /frontend-audit
class:    a11y/status-not-announced
anchor:   fixed bottom-6 left-1/2 z-50
match:    announce|live|role.?=?.?status|status|aria-live|4\.1\.3|screen reader|toast
```

The in-house toast (used by the wishlist heart) mounts a plain `div` with the message: no `role="status"`, no
`aria-live`, and it is inserted together with its text, so nothing is announced (4.1.3 AA). The checkout uses sonner,
which owns a persistent live region (AS-DECOY-08). Fix: route these notices through sonner. Proof: live-region
presence after saving to the wishlist (V93).

## AS-A11Y-07b — "Settings saved" live region is mounted together with its text

```defect
id:       AS-A11Y-07b
file:     apps/admin/src/views/SettingsView.vue
line:     34
severity: medium
command:  /frontend-audit
class:    a11y/status-not-announced
anchor:   <p v-if="saved" aria-live="polite"
match:    announce|live|aria-live|v-if|mount|4\.1\.3|status|screen reader
```

`<p v-if="saved" aria-live="polite">` is created at the moment the message appears; most screen readers only
announce changes to a region that already existed (4.1.3 AA, precedents/ui § 25). Fix: an always-mounted
`role="status"` element whose text changes. Proof: live-region presence before the save (V93).

## AS-A11Y-08a — Checkout email error is not tied to the field

```defect
id:       AS-A11Y-08a
file:     apps/shop/components/checkout/ContactForm.tsx
line:     28
severity: high
command:  /frontend-audit
class:    a11y/field-error-not-associated
anchor:   {errors.email && <p
match:    error|describedby|aria-invalid|associat|3\.3\.1|1\.3\.1|errormessage
```

`{errors.email && <p>…</p>}` renders next to an input with no `aria-invalid` and no `aria-describedby`: a screen
reader user tabbing back to the field hears nothing about the error (3.3.1 A, 1.3.1 A). High: checkout. The profile
form wires both (`ProfileForm.tsx`). Proof: `toHaveAccessibleErrorMessage` after an invalid blur (V93).

## AS-A11Y-08b — Refund amount and reason errors are not tied to their fields

```defect
id:       AS-A11Y-08b
file:     apps/admin/src/components/RefundForm.vue
line:     34
severity: high
command:  /frontend-audit
class:    a11y/field-error-not-associated
anchor:   <p v-if="errors.amount" class="field-error">
match:    error|describedby|aria-invalid|associat|3\.3\.1|1\.3\.1|errormessage
```

Both `.field-error` paragraphs render beside inputs with no `aria-invalid` / `aria-describedby` (3.3.1 A, 1.3.1 A).
High: a money form. Proof: `toHaveAccessibleDescription` on the amount after an invalid submit (V93).

## AS-A11Y-14a — Gallery zoom button forced first in the tab order

```defect
id:       AS-A11Y-14a
file:     apps/shop/components/product/ProductGallery.tsx
line:     17
severity: medium
command:  /frontend-audit
class:    a11y/positive-tabindex
anchor:   tabIndex={1}
match:    tab.?index|focus order|2\.4\.3|positive
```

`tabIndex={1}` puts the zoom button ahead of the header, search and skip targets on every product page; the rest
of the page follows in DOM order afterwards (2.4.3 A). Proof: axe `tabindex`; Tab from the address bar lands in the
gallery (V94).

## AS-A11Y-14b — Sidebar collapse toggle is focusable and `aria-hidden`

```defect
id:       AS-A11Y-14b
file:     apps/admin/src/components/AppSidebar.vue
line:     24
severity: high
command:  /frontend-audit
class:    a11y/aria-hidden-focusable
anchor:   <button class="collapse-toggle" type="button" aria-hidden="true"
match:    aria-hidden|hidden|focusable|name|label|4\.1\.2
```

A focusable `<button>` with `aria-hidden="true"` and an SVG-only body: keyboard users land on a control the screen
reader says does not exist, and it has no name either (4.1.2 A). Fix: remove `aria-hidden`, add
`aria-label`/`aria-expanded`. Proof: axe `aria-hidden-focus` and `button-name` (V94).

## AS-A11Y-15a — Hand-rolled product tabs with no arrow-key model

```defect
id:       AS-A11Y-15a
file:     apps/shop/components/product/ProductTabs.tsx
line:     15
severity: medium
command:  /frontend-audit
class:    a11y/composite-no-keyboard-model
anchor:   <div role="tablist"
match:    tab|arrow|keyboard|roving|apg|4\.1\.2|2\.1\.1|keydown
```

`role="tablist"` / `role="tab"` buttons with no `onKeyDown`: no Arrow/Home/End, every tab is in the Tab order and
the roles promise a model the widget does not implement (4.1.2 A). Medium: the tabs are reachable by Tab. The insights
page uses Radix Tabs (AS-DECOY-12). Proof: keyboard path — ArrowRight on the selected tab moves nothing (V95).

## AS-A11Y-15b — Status listbox: options are focusable but cannot be chosen by keyboard

```defect
id:       AS-A11Y-15b
file:     apps/admin/src/components/StatusFilter.vue
line:     7
severity: high
command:  /frontend-audit
class:    a11y/composite-no-keyboard-model
anchor:   <ul role="listbox"
match:    listbox|option|arrow|keyboard|enter|space|apg|4\.1\.2|2\.1\.1|keydown
```

`role="listbox"` with `tabindex="0"` options and only a click handler: Enter and Space do nothing, so the order
status filter cannot be operated by keyboard (2.1.1 A, 4.1.2 A). High per the class default for a listbox. Proof:
keyboard path — focus an option, press Enter, the selection does not change (V95).

## AS-A11Y-17a — Saved lists reorder by dragging only

```defect
id:       AS-A11Y-17a
file:     apps/shop/components/account/SavedListsSortable.tsx
line:     35
severity: high
command:  /frontend-audit
class:    a11y/dragging-only
anchor:   const sensors = useSensors(useSensor(PointerSensor));
match:    drag|reorder|pointer|keyboard|sensor|2\.5\.7|single.?pointer|move
```

dnd-kit with only `PointerSensor`: no `KeyboardSensor` and no move-up/move-down control, so reordering needs a drag
(2.5.7 AA) and a keyboard (2.1.1 A). High: reordering is the only way to set list order. Proof: reorder with clicks or
keys only — impossible (V96).

## AS-A11Y-17b — Storefront menu reorders by dragging only

```defect
id:       AS-A11Y-17b
file:     apps/admin/src/views/MenuBuilderView.vue
line:     24
severity: high
command:  /frontend-audit
class:    a11y/dragging-only
anchor:   <draggable v-model="items"
match:    drag|reorder|pointer|keyboard|2\.5\.7|single.?pointer|move|vuedraggable
```

vuedraggable with a grip handle and no move buttons or position field: staff who cannot drag cannot change the
storefront menu order (2.5.7 AA). Proof: click-only path (V96).

## AS-A11Y-18a — Sign-in password field blocks paste

```defect
id:       AS-A11Y-18a
file:     apps/shop/components/auth/SignInForm.tsx
line:     46
severity: high
command:  /frontend-audit
class:    a11y/auth-paste-blocked
anchor:   onPaste={(e) => e.preventDefault()}
match:    paste|password manager|3\.3\.8|accessible authentication|clipboard
```

`onPaste={(e) => e.preventDefault()}` on the password defeats password managers and pasted credentials: an
accessible-authentication failure on the only sign-in route (3.3.8 AA). Static fact. Proof: paste probe (V97).

## AS-A11Y-18b — Staff password field sets `autocomplete="off"`

```defect
id:       AS-A11Y-18b
file:     apps/admin/src/views/LoginView.vue
line:     40
severity: medium
command:  /frontend-audit
class:    a11y/auth-autocomplete-off
anchor:   type="password" autocomplete="off"
match:    autocomplete|password manager|current-password|1\.3\.5|3\.3\.8|off
```

`autocomplete="off"` on the staff password tells password managers not to fill it (1.3.5 AA, 3.3.8 AA). The
storefront's OTP field (`autocomplete="one-time-code"`, AS-DECOY-13) is the correct token use. Proof: axe
`autocomplete-valid`; fill probe (V97).

## AS-A11Y-09a — Dark theme muted text is 2.35:1

```defect
id:       AS-A11Y-09a
file:     apps/shop/app/[locale]/globals.css
line:     26
severity: high
command:  /frontend-audit
class:    a11y/contrast-dark-theme
anchor:   --color-muted-foreground: #4b5563;
match:    contrast|1\.4\.3|dark|ratio|4\.5
```

`.dark { --color-muted-foreground: #4b5563 }` on `--color-background: #111827` is **2.35:1**, and 1.94:1 on
`--color-muted`; the light pair (`#57534e` on white) is 7.63:1, so a light-only axe run is clean (1.4.3 AA). Every
secondary line on the storefront uses the token. No static grep sees it: the proof is axe `color-contrast` with
`colorScheme: 'dark'` (`e2e/a11y.spec.ts` would catch it — the gate is not the defect here).

## AS-A11Y-09b — Back-office dark `--text-subtle` is 2.76:1

```defect
id:       AS-A11Y-09b
file:     apps/admin/src/styles/tokens.css
line:     31
severity: high
command:  /frontend-audit
class:    a11y/contrast-dark-theme
anchor:   --text-subtle: #5b6472;
match:    contrast|1\.4\.3|dark|ratio|4\.5
```

`[data-theme="dark"] { --text-subtle: #5b6472 }` on `--surface: #1b1f27` is **2.76:1** (2.47:1 on
`--surface-raised`); the light value is 7.58:1 (1.4.3 AA). And the back office's axe job disables `color-contrast`
outright (AS-A11Y-22b), so nothing catches it. Proof: axe `color-contrast` in the dark theme.

## AS-A11Y-11a — Cart remove and increase buttons are 16 × 16 px and 28 px apart

```defect
id:       AS-A11Y-11a
file:     apps/shop/components/cart/CartLine.tsx
line:     30
severity: medium
command:  /frontend-audit
class:    a11y/target-size
anchor:   aria-label={t('remove', { name: line.name })}
match:    target|size|24|2\.5\.8|small|tap|16
```

`size-4` buttons (16 × 16 CSS px) with a 24 px quantity label between them: below 24 × 24 and the spacing circles
overlap (2.5.8 AA). axe `target-size` runs only with the `wcag22aa` tag (precedents/ui § 49). Proof: axe `target-size`
on the cart drawer.

## AS-A11Y-11b — Pagination buttons are 20 × 20 px with no gap

```defect
id:       AS-A11Y-11b
file:     apps/admin/src/components/Pagination.vue
line:     29
severity: medium
command:  /frontend-audit
class:    a11y/target-size
anchor:   width: 20px;
match:    target|size|24|2\.5\.8|small|20
```

`.page-btn { width: 20px; height: 20px }` in a `gap: 0` row (2.5.8 AA). Proof: axe `target-size` with `wcag22aa`
— which the back office's axe job never sets (AS-A11Y-22b).

## AS-A11Y-12a — Viewport blocks pinch zoom

```defect
id:       AS-A11Y-12a
file:     apps/shop/app/[locale]/layout.tsx
line:     16
severity: high
command:  /frontend-audit
class:    a11y/zoom-disabled
anchor:   maximumScale: 1, userScalable: false
match:    zoom|scal|viewport|1\.4\.4|maximum|user-?scalable|pinch
```

`maximumScale: 1, userScalable: false` renders `user-scalable=no, maximum-scale=1`: Android browsers honour it
(precedents/ui § 57), and 78 % of storefront sessions are mobile (1.4.4 AA). Static fact; axe `meta-viewport`.

## AS-A11Y-12b — Back-office shell has a 1024 px minimum width

```defect
id:       AS-A11Y-12b
file:     apps/admin/src/styles/base.css
line:     17
severity: medium
command:  /frontend-audit
class:    a11y/reflow
anchor:   min-width: 1024px;
match:    reflow|320|horizontal|scroll|1\.4\.10|min-width|zoom
```

`.app-shell { min-width: 1024px }`: at 400 % zoom (320 CSS px) every screen scrolls in two dimensions (1.4.10 AA).
Unlike the storefront's order table in its own `overflow-x-auto` container (AS-DECOY-09), this is the whole page.
Proof: viewport 320 × 256, `scrollWidth > clientWidth` on `html`.

## AS-A11Y-16a — 80 px sticky header with no scroll padding

```defect
id:       AS-A11Y-16a
file:     apps/shop/components/layout/SiteHeader.tsx
line:     17
severity: medium
command:  /frontend-audit
class:    a11y/focus-obscured
anchor:   <header className="sticky top-0 z-40 h-20
match:    obscur|sticky|header|scroll-padding|2\.4\.11|hidden behind|cover
```

A `sticky top-0 h-20` header and no `scroll-padding-top` / `scroll-margin` anywhere: tabbing backwards up a long
page scrolls focused links under the header (2.4.11 AA). Proof: Tab path with the focused rect intersecting the
header's rect.

## AS-A11Y-16b — Cookie notice pins 140 px over the bottom of every screen

```defect
id:       AS-A11Y-16b
file:     apps/admin/src/components/CookieNotice.vue
line:     23
severity: medium
command:  /frontend-audit
class:    a11y/focus-obscured
anchor:   position: fixed;
match:    obscur|cookie|fixed|banner|2\.4\.11|cover|hidden behind
```

`position: fixed; bottom: 0; height: 140px` and no bottom padding on the content: focused rows and buttons near
the bottom sit underneath it until it is dismissed (2.4.11 AA). Proof: the focus-obscured probe.

## AS-A11Y-22a — Storybook a11y addon set to `test: 'todo'`

```defect
id:       AS-A11Y-22a
file:     apps/shop/.storybook/preview.ts
line:     11
severity: high
command:  /frontend-audit
class:    a11y/gate-neutered
anchor:   test: 'todo',
match:    todo|storybook|gate|a11y\.test|addon|error|fail|ci
```

`parameters.a11y.test: 'todo'` reports violations in the panel and never fails a test run; only `'error'` fails CI
(addon-a11y 10.6.1). The comment above it reads as if stories are checked. High: an a11y gate that cannot fail.
Proof: inject a known violation into a story; the Vitest run stays green.

## AS-A11Y-22b — Back-office axe job disables four rules and omits `wcag22aa`

```defect
id:       AS-A11Y-22b
file:     apps/admin/e2e/a11y.spec.ts
line:     11
severity: high
command:  /frontend-audit
class:    a11y/gate-neutered
anchor:   .disableRules(['color-contrast', 'region', 'label', 'button-name'])
match:    disable|gate|neuter|wcag22aa|tag|color-contrast|button-name|rule
```

`disableRules(['color-contrast', 'region', 'label', 'button-name'])` switches off exactly the rules that would fail
AS-A11Y-09b, -03b, -02b and -14b, and `withTags(['wcag2a', 'wcag2aa'])` never runs `target-size` (AS-A11Y-11b). The CI
job is green by construction. Proof: inject an unnamed button; the job stays green.

## AS-ST-01a — Recently viewed shows its empty copy while loading

```defect
id:       AS-ST-01a
file:     apps/shop/components/home/RecentlyViewed.tsx
line:     25
severity: medium
command:  /frontend-audit
class:    states/no-loading
anchor:   const items = data ?? [];
match:    loading|pending|skeleton|spinner|while.*load|flash
```

No `isPending` branch: during the fetch `data` is undefined, `items` is `[]`, and the section says "Products you open
will show up here" to a customer who has viewed twenty. Proof: hold `/me/recently-viewed` (MSW `delay('infinite')`);
the empty copy is visible and no `aria-busy` region exists.

## AS-ST-01b — Customer table renders its "—" empty row while loading

```defect
id:       AS-ST-01b
file:     apps/admin/src/views/CustomersView.vue
line:     10
severity: medium
command:  /frontend-audit
class:    states/no-loading
anchor:   const { data, isError, refetch } = useQuery({
match:    loading|pending|skeleton|spinner|while.*load|flash
```

`isPending` is never read; the table renders with `visible = []` and its "—" row until the response arrives.
Lowered one step would be medium→low on an admin surface, but the list is the support team's main screen. Proof: hold
the response; the empty row shows and nothing is busy.

## AS-ST-02a — Empty wishlist renders a blank grid

```defect
id:       AS-ST-02a
file:     apps/shop/components/account/WishlistGrid.tsx
line:     30
severity: medium
command:  /frontend-audit
class:    states/no-empty
anchor:   {data.items.map((product) => (
match:    empty|no items|nothing|zero|blank|\[\]
```

Loading and error are handled; zero items renders an empty `div` with no copy and no path to products. The
`wishlistHint` copy exists in both catalogs and is never used. Proof: fulfil `{ items: [] }`; no empty-state copy.

## AS-ST-02b — No open invoices renders a header row and nothing else

```defect
id:       AS-ST-02b
file:     apps/admin/src/views/InvoicesView.vue
line:     31
severity: medium
command:  /frontend-audit
class:    states/no-empty
anchor:   <tr v-for="invoice in invoices"
match:    empty|no (open )?invoices|nothing|zero|blank|v-else|\[\]
```

`v-for` over the invoices with no `v-else` and no length check. Contrast the Angular store locator's `@empty`
(AS-DECOY-14) and the Svelte stock badge's `{:else}` (AS-DECOY-15). Proof: fulfil `[]`.

## AS-ST-03a — Failed review fetch shows "No reviews yet."

```defect
id:       AS-ST-03a
file:     apps/shop/components/product/ReviewsList.tsx
line:     17
severity: medium
command:  /frontend-audit
class:    states/error-as-empty
anchor:   .catch(() => setReviews([]));
match:    error|catch|swallow|empty|fail|500
```

`.catch(() => setReviews([]))` turns a 500 or a timeout into "No reviews yet." on a product with 300 reviews.
Proof: fulfil 500; the empty copy shows and no error role appears.

## AS-ST-03b — Failed notification load shows "You're all caught up."

```defect
id:       AS-ST-03b
file:     apps/admin/src/stores/notifications.ts
line:     17
severity: medium
command:  /frontend-audit
class:    states/error-as-empty
anchor:   this.items = [];
match:    error|catch|swallow|empty|fail|caught up
```

The Pinia action's `catch { this.items = [] }` sets `fetched`, so `NotificationsPanel` says "You're all caught up."
when the request failed. Grep 3b once knew only `setX([])` and missed this store mutation (integrator request IR-3);
since 2026-10-10 grep 3c (multi-line) prints it.
Proof: fulfil 500 on `/notifications`; the caught-up copy shows.

## AS-ST-04a — Account segment has no `error.tsx` at or above it

```defect
id:       AS-ST-04a
file:     apps/shop/app/[locale]/account/layout.tsx
line:     6
severity: high
command:  /frontend-audit
class:    states/no-error-boundary
anchor:   export default async function AccountLayout
match:    error\.tsx|error boundary|boundary|white|crash|throw|segment|blank
```

`(storefront)` and `checkout` have an `error.tsx`; `account/` has none and neither does `[locale]`. Any throw in an
account page (AS-ST-05a throws on one failed call) renders Next's bare "Application error" with no retry and no way
back. High: the root of the signed-in area. Proof: fail `/me/loyalty`; the boundary text is Next's default.

## AS-ST-04b — Report error has no retry

```defect
id:       AS-ST-04b
file:     apps/admin/src/views/ReportsView.vue
line:     23
severity: medium
command:  /frontend-audit
class:    states/error-no-recovery
anchor:   <p v-else-if="isError" class="report-error">
match:    retry|recover|way out|refetch|try again|dead.?end|error
```

"Report failed to load." and nothing else: no retry, no refetch, no link. Every other back-office list offers
**Retry**. Proof: fail once then succeed; nothing on screen refetches.

## AS-ST-05a — Recommendations outage takes the whole account page down

```defect
id:       AS-ST-05a
file:     apps/shop/app/[locale]/account/page.tsx
line:     14
severity: high
command:  /frontend-audit
class:    states/partial-failure
anchor:   await Promise.all([getRecentOrders(), getLoyalty(), getRecommendations()])
match:    promise\.all|partial|one (call|request|endpoint|widget)|whole page|allsettled|independent
```

Three independent reads in one `Promise.all`: a failing recommendations service rejects the page, and with no
`error.tsx` (AS-ST-04a) the customer loses their orders and points too. Fix: `Promise.allSettled` or per-section
Suspense + boundaries. Proof: fail one of the three; the other two sections must still render.

## AS-ST-05b — Any one KPI error replaces the whole dashboard

```defect
id:       AS-ST-05b
file:     apps/admin/src/views/DashboardView.vue
line:     21
severity: medium
command:  /frontend-audit
class:    states/partial-failure
anchor:   const anyError = computed(() => results.value.some((r) => r.isError));
match:    usequeries|partial|one (query|request|widget|endpoint)|whole|any.?error|independent
```

`useQueries` for three independent widgets with a single `anyError` branch: a latency-service hiccup hides revenue
and sign-ups too. Proof: fail `/kpi/latency`; the other two cards must render.

## AS-ST-06a — Unverified customers get "Something went wrong" and a useless retry

```defect
id:       AS-ST-06a
file:     apps/shop/components/account/GiftCardsPanel.tsx
line:     14
severity: medium
command:  /frontend-audit
class:    states/permission-as-error
anchor:   if (isError) return <ErrorState onRetry={() => refetch()} />;
match:    403|forbidden|permission|verif|unverified|generic|retry
```

`/me/gift-cards` answers 403 `email_unverified` (documented in `lib/api.ts`), the query retries three times with
backoff (TanStack default, precedents/ui § 38 flips back), then shows the generic error with **Try again** — which
fails the same way. `StoreCreditPanel` tells the 403 apart and offers the verification email (AS-DECOY-17).
Proof: fulfil 403; assert the verify copy, not the retry.

## AS-ST-06b — Support staff are told the audit log is empty

```defect
id:       AS-ST-06b
file:     apps/admin/src/views/AuditLogView.vue
line:     15
severity: high
command:  /frontend-audit
class:    states/permission-as-empty
anchor:   const entries = computed(() => (isError.value ? [] : data.value ?? []));
match:    403|forbidden|permission|role|empty|no audit|owner
```

Only owners may read the audit log; for everyone else the API answers 403 and `entries` becomes `[]`, so the page
says "No audit entries yet." — on a security log. High: the copy is false and invites nobody to ask for access. Proof:
fulfil 403; assert a forbidden message, not the empty copy.

## AS-ST-07a — Cart sync drops writes silently offline

```defect
id:       AS-ST-07a
file:     apps/shop/components/cart/CartSync.tsx
line:     17
severity: medium
command:  /frontend-audit
class:    states/offline-write-lost
anchor:   void api.put('/me/cart', { lines: payload }).catch(() => undefined);
match:    offline|online|network|lost|silent|swallow|catch|queue
```

The debounced cart mirror swallows every failure: offline (or on any 5xx) the server cart silently diverges from
the device, and the next device shows the old cart. No `navigator.onLine` / `online` listener exists anywhere in the
repo. Proof: `context.setOffline(true)`, change quantity; no indicator, no retry, no queued write.

## AS-ST-07b — Order notes autosave loses edits offline with no sign

```defect
id:       AS-ST-07b
file:     apps/admin/src/components/NotesEditor.vue
line:     13
severity: high
command:  /frontend-audit
class:    states/offline-write-lost
anchor:   api.patch(`/orders/${props.orderId}/notes`, { text: value }).catch(() => {});
match:    offline|online|network|lost|silent|swallow|catch|autosave|queue
```

The autosave's `.catch(() => {})` discards the write; there is no saved/unsaved indicator, so a support agent on a
flaky connection believes the note is stored. High: data loss on a write staff rely on. Proof: offline, type, wait;
no indicator; reload — the note is gone.

## AS-ST-08a — Place order: no pending state, double click places two orders

```defect
id:       AS-ST-08a
file:     apps/shop/components/checkout/PlaceOrderButton.tsx
line:     21
severity: high
command:  /frontend-audit
class:    states/pending-submit
anchor:   onClick={() => placeOrder(cart.id)}
match:    double|twice|pending|disabled|submit|in.?flight|idempot|duplicate
```

No `disabled`, no busy state, no idempotency key, and no error handling: a double click posts two orders, and a
500 leaves the customer with no message. `e2e/checkout-states.spec.ts::one order per double click` already describes
the expected behaviour and fails on this code. Money flow → also security `logic-race-scan` when installed. Proof:
that test.

## AS-ST-08b — Refund form can be submitted twice

```defect
id:       AS-ST-08b
file:     apps/admin/src/components/RefundForm.vue
line:     31
severity: high
command:  /frontend-audit
class:    states/pending-submit
anchor:   <form class="refund-form" @submit.prevent="submitRefund">
match:    double|twice|pending|disabled|submit|in.?flight|idempot|duplicate
```

No pending binding on the submit button and no guard in `submitRefund`: a double Enter issues two refunds; a
failed request throws out of the handler with no message. Proof: hold the response, submit twice; one request only.

## AS-ST-10a — Profile edits are lost on navigation without a prompt

```defect
id:       AS-ST-10a
file:     apps/shop/components/account/ProfileForm.tsx
line:     19
severity: medium
command:  /frontend-audit
class:    states/unsaved-changes
anchor:   formState: { isDirty, errors },
match:    unsaved|dirty|navigat|leave|beforeunload|guard|lost
```

The form tracks `isDirty` (it gates the Save button) but nothing guards navigation or `beforeunload`. Proof:
edit the bio, click **Orders** in the account nav; no confirm, edits gone.

## AS-ST-10b — Product editor shows "Unsaved changes" and lets you leave anyway

```defect
id:       AS-ST-10b
file:     apps/admin/src/views/ProductEditView.vue
line:     13
severity: medium
command:  /frontend-audit
class:    states/unsaved-changes
anchor:   const { defineField, handleSubmit, meta, isSubmitting, errors } = useForm<ProductDraft>({
match:    unsaved|dirty|navigat|leave|onBeforeRouteLeave|guard|lost
```

`meta.dirty` drives an "Unsaved changes" label, yet there is no `onBeforeRouteLeave` or `beforeunload`: a long
description is lost on a sidebar click. Proof: dirty the form, navigate; no confirm.

## AS-SM-01 — Checkout matrix has no `offline` row

```defect
id:       AS-SM-01
file:     ai/design/state-matrix/checkout.md
line:     9
severity: medium
command:  /frontend-audit
class:    matrix/state-missing
anchor:   - `checkout-page` —
match:    offline
match:    missing|no .?offline.? row|state-missing|absent|(?:not|n.t) written
```

`checkout-page` lists loading, empty, error, partial, permission, stale — no `offline`, not even as `n-a`. The lint
reports it at the `## State matrix` heading (line 6). Fix: write the row (the checkout has no offline mode, so the
row says what the user sees when the order POST fails offline).

## AS-SM-02 — Refund matrix has no `permission` row

```defect
id:       AS-SM-02
file:     ai/design/state-matrix/checkout.md
line:     10
severity: medium
command:  /frontend-audit
class:    matrix/state-missing
anchor:   - `refund-form` —
match:    permission|403|forbidden
match:    missing|no .?permission.? row|state-missing|absent|not written
```

`refund-form` has no `permission` row; the Notes claim "every role that can open it can refund", which is exactly
what a permission row must state with its reason. Reported at line 6.

## AS-SM-03 — `checkout-page × partial` is `n-a` with no reason

```defect
id:       AS-SM-03
file:     ai/design/state-matrix/checkout.md
line:     17
severity: low
command:  /frontend-audit
class:    matrix/na-without-reason
anchor:   | checkout-page | partial | n-a | n-a | — |
match:    n-?a|reason|partial|placeholder
```

The checkout reads three things (cart, addresses, coupon) and can half-fail; `n-a` with no reason hides that.

## AS-SM-04 — `refund-form × stale` is `n-a — not needed`

```defect
id:       AS-SM-04
file:     ai/design/state-matrix/checkout.md
line:     27
severity: low
command:  /frontend-audit
class:    matrix/na-without-reason
anchor:   | refund-form | stale | n-a | n-a — not needed | — |
match:    n-?a|reason|stale|not needed|placeholder
```

"Not needed" is the example the skill names as not a reason (fewer than three words).

## AS-SM-05 — Pending-submit row cites the component as its own proof

```defect
id:       AS-SM-05
file:     ai/design/state-matrix/checkout.md
line:     20
severity: medium
command:  /frontend-audit
class:    matrix/proof-not-a-test
anchor:   apps/shop/components/checkout/PlaceOrderButton.tsx |
match:    proof|test|story|component|PlaceOrderButton|not a test
```

The proof column names `PlaceOrderButton.tsx` itself. The test that would prove the row exists
(`checkout-states.spec.ts::one order per double click`) and is not cited.

## AS-SM-06 — Refund pending-submit row cites `RefundForm.vue` as its proof

```defect
id:       AS-SM-06
file:     ai/design/state-matrix/checkout.md
line:     28
severity: medium
command:  /frontend-audit
class:    matrix/proof-not-a-test
anchor:   | apps/admin/src/components/RefundForm.vue |
match:    proof|test|story|component|RefundForm|not a test
```

Same kind on the back-office surface.

## AS-SM-07 — Checkout error row cites a test title that does not exist

```defect
id:       AS-SM-07
file:     ai/design/state-matrix/checkout.md
line:     16
severity: medium
command:  /frontend-audit
class:    matrix/proof-missing
anchor:   checkout-states.spec.ts::shows retry on 500
match:    proof|missing|no test|not (found|exist)|retry on 500|title
```

`checkout-states.spec.ts` has three tests; none is titled "shows retry on 500".

## AS-SM-08 — Refund error row cites a spec file that does not exist

```defect
id:       AS-SM-08
file:     ai/design/state-matrix/checkout.md
line:     24
severity: medium
command:  /frontend-audit
class:    matrix/proof-missing
anchor:   apps/admin/e2e/refund-states.spec.ts::refund 500 keeps the inputs
match:    proof|missing|not (found|exist)|does not exist|refund-states
```

`apps/admin/e2e/refund-states.spec.ts` is not in the repo.

## AS-MO-01a — Category tiles transition `all`

```defect
id:       AS-MO-01a
file:     apps/shop/components/home/CategoryTile.tsx
line:     12
severity: low
command:  /frontend-audit
class:    visual/transition-all
anchor:   transition-all duration-300
match:    transition.?all|all properties|transition
```

`transition-all` on the tile image animates every property that changes, including any layout property a later
class adds; the hover only needs `transform` and `filter`. Fix: `transition-[transform,filter]`.

## AS-MO-01b — `.card` transitions `all` with a literal 0.3 s

```defect
id:       AS-MO-01b
file:     apps/admin/src/styles/base.css
line:     66
severity: low
command:  /frontend-audit
class:    visual/transition-all
anchor:   transition: all 0.3s ease;
match:    transition.?all|all properties|transition|duration|off.?scale
```

`transition: all 0.3s ease` on every card, with the project's `--duration-base` / `--ease-standard` tokens beside
it unused here.

## AS-MO-02a — Care accordion animates `height`

```defect
id:       AS-MO-02a
file:     apps/shop/components/product/CareAccordion.tsx
line:     26
severity: medium
command:  /frontend-audit
class:    visual/layout-property-animated
anchor:   animate={{ height: 'auto' }}
match:    height|layout|reflow|transform|animat
```

`initial/animate/exit={{ height }}` relayouts the whole product column every frame of the open and close.
It does honour reduced motion — the defect is the property. Fix: animate a `grid-template-rows` 0fr→1fr wrapper or
`transform`/`opacity`.

## AS-MO-02b — Refund drawer slides in by animating `right`

```defect
id:       AS-MO-02b
file:     apps/admin/src/styles/base.css
line:     78
severity: medium
command:  /frontend-audit
class:    visual/layout-property-animated
anchor:   @keyframes drawer-in {
match:    right|left|layout|reflow|keyframes|transform|animat|drawer
```

`@keyframes drawer-in { from { right: -420px } to { right: 0 } }` animates a layout property. Fix:
`transform: translateX()`.

## AS-MO-03a — Scroll-linked parallax with no reduced-motion branch

```defect
id:       AS-MO-03a
file:     apps/shop/components/home/HeroParallax.tsx
line:     8
severity: high
command:  /frontend-audit
class:    visual/no-reduced-motion
anchor:   const { scrollYProgress } = useScroll({
match:    reduced.?motion|prefers-reduced|parallax|vestibular|scroll
```

`useScroll` + `useTransform` drive translate and scale from scroll; nothing reads `useReducedMotion`. The global CSS
reset in `globals.css` does not reach JS-driven motion. High: a vestibular trigger on the home page (2.3.3 is AAA —
report as the house rule it is, precedents/ui § 4). Proof: `emulateMedia({ reducedMotion: 'reduce' })`; the hero still
moves on scroll.

## AS-MO-03b — KPI count-up ignores reduced motion

```defect
id:       AS-MO-03b
file:     apps/admin/src/components/KpiCounter.vue
line:     12
severity: medium
command:  /frontend-audit
class:    visual/no-reduced-motion
anchor:   gsap.to(tween, {
match:    reduced.?motion|prefers-reduced|gsap|matchMedia|count
```

A 1.2 s gsap tween on every value change, no `gsap.matchMedia()` or `prefers-reduced-motion` check.

## AS-MO-04a — Home carousel auto-advances forever with no pause control

```defect
id:       AS-MO-04a
file:     apps/shop/components/home/HeroCarousel.tsx
line:     11
severity: high
command:  /frontend-audit
class:    visual/auto-moving-content
anchor:   Autoplay({ delay: 4000, stopOnInteraction: false })
match:    auto.?play|carousel|pause|2\.2\.2|moving|rotat
```

Embla `Autoplay` every 4 s, `loop: true`, `stopOnInteraction: false`, no pause button: content moving for more
than 5 s beside other content with no way to stop it (2.2.2 A).

## AS-MO-04b — Announcement ticker scrolls forever with no pause

```defect
id:       AS-MO-04b
file:     apps/admin/src/components/AnnouncementTicker.vue
line:     29
severity: high
command:  /frontend-audit
class:    visual/auto-moving-content
anchor:   animation: ticker-scroll 18s linear infinite;
match:    ticker|marquee|infinite|pause|2\.2\.2|moving|scroll
```

An infinite 18 s marquee at the top of every back-office screen, no pause control, no reduced-motion rule
(2.2.2 A).

## AS-TK-01a — Rating stars use a raw hex on a themed surface

```defect
id:       AS-TK-01a
file:     apps/shop/components/product/rating.module.css
line:     6
severity: high
command:  /frontend-audit
class:    visual/raw-colour-literal
anchor:   color: #f59e0b;
match:    hex|literal|token|colou?r|#f59e0b|hard.?coded
```

`#f59e0b` where `--color-accent` exists; the shop ships two themes, so a literal colour is high per the class
default.

## AS-TK-01b — `pill--late` hard-codes amber beside the `--warning-*` tokens

```defect
id:       AS-TK-01b
file:     apps/admin/src/components/StatusPill.vue
line:     24
severity: medium
command:  /frontend-audit
class:    visual/raw-colour-literal
anchor:   background: #fde68a;
match:    hex|literal|token|colou?r|#fde68a|#92400e|hard.?coded
```

The rule right above uses `--warning-bg` / `--warning-text`; `.pill--late` repeats the idea in raw hex, and the
dark theme never overrides it.

## AS-TK-02a — Promo strip uses an arbitrary `bg-[#0f766e]`

```defect
id:       AS-TK-02a
file:     apps/shop/components/layout/PromoStrip.tsx
line:     8
severity: medium
command:  /frontend-audit
class:    visual/arbitrary-value
anchor:   bg-[#0f766e]
match:    arbitrary|bg-\[|hex|token|literal
```

A Tailwind arbitrary colour on every page's first band.

## AS-TK-02b — Loyalty badge: `rounded-[10px]` and `text-[13px]` off the scale

```defect
id:       AS-TK-02b
file:     apps/shop/components/account/LoyaltyBadge.tsx
line:     7
severity: medium
command:  /frontend-audit
class:    visual/arbitrary-value
anchor:   rounded-[10px]
match:    arbitrary|text-\[|rounded-\[|13px|10px|token|literal|scale
```

Two arbitrary values on token axes (radius and type) where `--radius-card` and the `text-xs/sm` scale exist.

## AS-TK-04a — Mobile menu at `z-[9999]`

```defect
id:       AS-TK-04a
file:     apps/shop/components/layout/SiteHeader.tsx
line:     42
severity: low
command:  /frontend-audit
class:    visual/z-index-magic
anchor:   z-[9999]
match:    z-?index|z-\[|9999|magic|stack
```

A magic z-index under a header that uses `z-40`.

## AS-TK-04b — Cookie notice at `z-index: 1000` beside a `--z-overlay` scale

```defect
id:       AS-TK-04b
file:     apps/admin/src/components/CookieNotice.vue
line:     34
severity: low
command:  /frontend-audit
class:    visual/z-index-magic
anchor:   z-index: 1000;
match:    z-?index|1000|magic|stack|token
```

`tokens.css` defines `--z-overlay: 40`; the notice picks 1000, so it sits above the refund drawer.

## AS-TK-08a — `text-gray-500` on a semantic theme

```defect
id:       AS-TK-08a
file:     apps/shop/components/product/ProductMeta.tsx
line:     8
severity: medium
command:  /frontend-audit
class:    visual/default-palette
anchor:   className="text-gray-500"
match:    gray|default palette|semantic|token|muted
```

The next `dt` uses `text-muted-foreground`; this one uses Tailwind's default gray, which ignores the dark theme.

## AS-TK-08b — Coupon **Apply** button uses `bg-blue-600` instead of `bg-primary`

```defect
id:       AS-TK-08b
file:     apps/shop/components/checkout/CouponField.tsx
line:     47
severity: medium
command:  /frontend-audit
class:    visual/default-palette
anchor:   bg-blue-600
match:    blue|default palette|semantic|token|primary
```

Default-palette blue next to `text-primary-foreground`; in dark mode the pair inverts badly.

## AS-CH-02a — Monthly spend bars start at 40

```defect
id:       AS-CH-02a
file:     apps/shop/components/account/SpendChart.tsx
line:     26
severity: high
command:  /frontend-audit
class:    visual/truncated-baseline
anchor:   <YAxis domain={[40, 'auto']}
match:    zero|baseline|domain|axis|truncat|40
```

A bar chart with `domain={[40, 'auto']}`: a 60 → 80 month looks three times taller. Bars must start at zero.

## AS-CH-02b — Revenue bars do not begin at zero

```defect
id:       AS-CH-02b
file:     apps/admin/src/components/charts/RevenueBars.vue
line:     27
severity: high
command:  /frontend-audit
class:    visual/truncated-baseline
anchor:   beginAtZero: false,
match:    zero|baseline|beginAtZero|axis|truncat
```

`beginAtZero: false` on a bar chart. Contrast `LatencyLine.vue` (AS-DECOY-20): a line whose zoomed axis is
labelled.

## AS-CH-05a — Points trend bridges weeks the ledger never ran

```defect
id:       AS-CH-05a
file:     apps/shop/components/account/PointsTrend.tsx
line:     26
severity: high
command:  /frontend-audit
class:    visual/gaps-drawn-as-data
anchor:   connectNulls
match:    null|gap|bridge|connectNulls|missing|interpolat
```

`connectNulls` draws a line through weeks whose value is `null` (the file's own comment says why they are null).

## AS-CH-05b — Sign-ups line spans failed export weeks

```defect
id:       AS-CH-05b
file:     apps/admin/src/components/charts/SignupsLine.vue
line:     19
severity: high
command:  /frontend-audit
class:    visual/gaps-drawn-as-data
anchor:   spanGaps: true,
match:    null|gap|bridge|spanGaps|missing|interpolat
```

`spanGaps: true` over weeks the analytics export failed.

## AS-CH-06a — Spend bars: up/down encoded only as green vs red

```defect
id:       AS-CH-06a
file:     apps/shop/components/account/SpendChart.tsx
line:     30
severity: high
command:  /frontend-audit
class:    visual/colour-only-red-green
anchor:   <Cell key={point.month} fill=
match:    colou?r|red|green|cvd|blind|hue|only|1\.4\.1
```

`fill={change >= 0 ? '#16a34a' : '#dc2626'}`: month-over-month direction is carried by red/green alone — one series
to a deuteranope, and a 1.4.1 (A) colour-only signal.

## AS-CH-06b — Revenue bars: hit/miss target encoded only as green vs red

```defect
id:       AS-CH-06b
file:     apps/admin/src/components/charts/RevenueBars.vue
line:     17
severity: high
command:  /frontend-audit
class:    visual/colour-only-red-green
anchor:   backgroundColor: props.points.map((p) => (p.revenue >= p.target
match:    colou?r|red|green|cvd|blind|hue|only|1\.4\.1|target
```

`'#22c55e' : '#ef4444'` per bar against the monthly target, with no label, pattern or target line.

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded defect — same app, same vocabulary, no defect — and most were written so
that only reading the code (or one precedent in `templates/snippets/precedents/ui.md`) tells them apart. FX-1's eval
list is covered: `focus:outline-none focus-visible:ring-2`, `<dialog>.showModal()`, a Radix Dialog, `alt=""` on a
decorative hero, an aria-labelled `×`, `key={i}` on a static list, a backdrop `div onClick` with Escape and a close
button, sonner toasts, a data table scrolling at 320 px, an inline link under 24 px, `useQuery` with every branch in a
child component, Next's route announcer (no seed claims the storefront's route changes — the `[locale]` layout's title
template feeds the built-in announcer), an `autocomplete="one-time-code"` OTP field, `@empty` in Angular and `{:else}`
in Svelte. Added: the `:focus:not(:focus-visible)` reset, a handled 403, a jsdom-only contrast opt-out, a hex inside
`@theme`, a labelled zoomed line axis, an opacity fade, a layout arbitrary width and the reduced-motion `!important`.

How they score (`score.py`, § DECOYS): a finding that names the decoy's file, cites a line within the tolerance window
of the decoy's line, and matches every one of the decoy's `match:` patterns is **pinned** to it, removed before defect
assignment, and reported as `DECOYS FLAGGED k/N`. Every decoy sits more than 12 lines from any defect in its file
(`--verify` enforces it).

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| AS-DECOY-01 | `apps/shop/components/ui/Button.tsx:19` | AS-A11Y-04a | `focus-visible:ring-2` replaces the outline (precedents/ui § 18) |
| AS-DECOY-02 | `apps/shop/components/account/ConfirmDeleteDialog.tsx:24` | AS-A11Y-05a | `<dialog>.showModal()` is modal, inert behind and closes on Escape (ui § 13) |
| AS-DECOY-03 | `apps/shop/components/cart/CartDrawer.tsx:30` | AS-A11Y-05a | Radix Dialog owns focus, trap, Escape and return (ui § 12) |
| AS-DECOY-04 | `apps/shop/app/[locale]/(storefront)/page.tsx:28` | AS-A11Y-02a | the paper texture is decoration behind the hero heading; `alt=""` is required (ui § 11) |
| AS-DECOY-05 | `apps/shop/components/cart/CartDrawer.tsx:36` | AS-A11Y-02b | the `×` button carries `aria-label` |
| AS-DECOY-06 | `apps/shop/components/layout/SiteFooter.tsx:17` | render / RC-03 | a constant three-column list that never reorders or holds input (ui § 42) |
| AS-DECOY-07 | `apps/shop/components/ui/Lightbox.tsx:26` | AS-A11Y-01a | the backdrop also closes on Escape and the dialog has a named close button that receives focus (ui § 16) |
| AS-DECOY-08 | `apps/shop/components/checkout/CouponField.tsx:18` | AS-A11Y-07a | sonner mounts a persistent live region (ui § 26) |
| AS-DECOY-09 | `apps/shop/components/account/OrdersTable.tsx:32` | AS-A11Y-12b | a data table in its own scroll container may scroll in two dimensions at 320 px (ui § 21) |
| AS-DECOY-10 | `apps/shop/components/layout/SiteFooter.tsx:36` | AS-A11Y-11a | an inline link inside a sentence is exempt from 2.5.8 (ui § 20) |
| AS-DECOY-11 | `apps/shop/components/account/OrdersPanel.tsx:9` | AS-ST-01a | the query result is handed to `OrdersTable`, which renders pending, error and empty (ui § 36) |
| AS-DECOY-12 | `apps/shop/components/account/InsightsTabs.tsx:13` | AS-A11Y-15a | Radix Tabs implements the APG keyboard model (ui § 12) |
| AS-DECOY-13 | `apps/shop/components/auth/OtpForm.tsx:34` | AS-A11Y-18b | `one-time-code` is the right token; an OTP is not personal data (ui § 30) |
| AS-DECOY-14 | `packages/widgets/src/angular/store-locator.component.html:14` | AS-ST-02b | `@for … @empty` is the empty branch |
| AS-DECOY-15 | `packages/widgets/src/svelte/StockBadge.svelte:25` | AS-ST-02b | `{#each … {:else}` is the empty branch |
| AS-DECOY-16 | `apps/admin/src/styles/base.css:36` | AS-A11Y-04b | `outline: none` only under `:focus:not(:focus-visible)`, with a `:focus-visible` outline below (ui § 18) |
| AS-DECOY-17 | `apps/shop/components/account/StoreCreditPanel.tsx:17` | AS-ST-06a | the 403 gets its own copy and the verification action, no retry |
| AS-DECOY-18 | `apps/shop/tests/unit/a11y.test.tsx:10` | AS-A11Y-22b | jsdom cannot compute colour; `e2e/a11y.spec.ts` runs contrast in Chromium with `wcag22aa` (ui § 50, eval decoy) |
| AS-DECOY-19 | `apps/shop/app/[locale]/globals.css:10` | AS-TK-01a | a hex inside `@theme` is the token definition |
| AS-DECOY-20 | `apps/admin/src/components/charts/LatencyLine.vue:21` | AS-CH-02b | a line chart may zoom its axis when the axis says so; the title states the 300 ms start (chart-encoding §2) |
| AS-DECOY-21 | `apps/shop/components/cart/CartDrawer.tsx:29` | AS-MO-01a | a 150 ms opacity-only fade on a compositor property |
| AS-DECOY-22 | `apps/shop/components/auth/OtpForm.tsx:25` | AS-TK-02b | a width is a layout size, not a token axis (design-token-audit §2) |
| AS-DECOY-23 | `apps/shop/app/[locale]/globals.css:46` | design-token-audit §5 | the reduced-motion reset is the documented `!important` exception (design-token-audit § False positives) |

```decoy
id:       AS-DECOY-01
file:     apps/shop/components/ui/Button.tsx
line:     19
command:  /frontend-audit
class:    decoy/focus-visible-ring
anchor:   focus:outline-none focus-visible:ring-2
match:    focus|outline|2\.4\.7
```

```decoy
id:       AS-DECOY-02
file:     apps/shop/components/account/ConfirmDeleteDialog.tsx
line:     24
command:  /frontend-audit
class:    decoy/native-dialog
anchor:   if (open && !dialog.open) dialog.showModal();
match:    focus|trap|escape|dialog|modal
```

```decoy
id:       AS-DECOY-03
file:     apps/shop/components/cart/CartDrawer.tsx
line:     30
command:  /frontend-audit
class:    decoy/radix-dialog
anchor:   <Dialog.Content className="fixed inset-y-0 end-0
match:    focus|trap|escape|dialog|modal|drawer
```

```decoy
id:       AS-DECOY-04
file:     apps/shop/app/[locale]/(storefront)/page.tsx
line:     28
command:  /frontend-audit
class:    decoy/decorative-alt
anchor:   alt="" fill priority sizes="100vw"
match:    alt|name|image|1\.1\.1
```

```decoy
id:       AS-DECOY-05
file:     apps/shop/components/cart/CartDrawer.tsx
line:     36
command:  /frontend-audit
class:    decoy/labelled-glyph-button
anchor:   aria-label={tc('close')}
match:    name|label|glyph|×|button-name
```

```decoy
id:       AS-DECOY-06
file:     apps/shop/components/layout/SiteFooter.tsx
line:     17
command:  /frontend-audit
class:    decoy/index-key-static-list
anchor:   <section key={i}
match:    key|index
```

```decoy
id:       AS-DECOY-07
file:     apps/shop/components/ui/Lightbox.tsx
line:     26
command:  /frontend-audit
class:    decoy/backdrop-click
anchor:   <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 p-4" onClick={onClose}>
match:    div|click|keyboard|non.?semantic|2\.1\.1
```

```decoy
id:       AS-DECOY-08
file:     apps/shop/components/checkout/CouponField.tsx
line:     18
command:  /frontend-audit
class:    decoy/sonner-toast
anchor:   toast.success(t('couponApplied'));
match:    announce|live.?region|aria-live|role=.?.?status|status message|4\.1\.3|screen.?reader
```

```decoy
id:       AS-DECOY-09
file:     apps/shop/components/account/OrdersTable.tsx
line:     32
command:  /frontend-audit
class:    decoy/table-2d-scroll
anchor:   <div className="mt-6 overflow-x-auto rounded-card border">
match:    reflow|320|horizontal|scroll|1\.4\.10
```

```decoy
id:       AS-DECOY-10
file:     apps/shop/components/layout/SiteFooter.tsx
line:     36
command:  /frontend-audit
class:    decoy/inline-link-target
anchor:   <Link href="/legal/terms" className="underline">
match:    target|size|24|2\.5\.8
```

```decoy
id:       AS-DECOY-11
file:     apps/shop/components/account/OrdersPanel.tsx
line:     9
command:  /frontend-audit
class:    decoy/hook-in-parent-branches-in-child
anchor:   const orders = useOrders();
match:    loading|pending|error|state
```

```decoy
id:       AS-DECOY-12
file:     apps/shop/components/account/InsightsTabs.tsx
line:     13
command:  /frontend-audit
class:    decoy/radix-tabs
anchor:   <Tabs.List aria-label={t('insights')}
match:    tab|arrow|keyboard|apg
```

```decoy
id:       AS-DECOY-13
file:     apps/shop/components/auth/OtpForm.tsx
line:     34
command:  /frontend-audit
class:    decoy/otp-autocomplete
anchor:   autoComplete="one-time-code"
match:    autocomplete|1\.3\.5|3\.3\.8
```

```decoy
id:       AS-DECOY-14
file:     packages/widgets/src/angular/store-locator.component.html
line:     14
command:  /frontend-audit
class:    decoy/angular-empty
anchor:   } @empty {
match:    empty|no stores
```

```decoy
id:       AS-DECOY-15
file:     packages/widgets/src/svelte/StockBadge.svelte
line:     25
command:  /frontend-audit
class:    decoy/svelte-each-else
anchor:   {:else}
match:    empty|out of stock
```

```decoy
id:       AS-DECOY-16
file:     apps/admin/src/styles/base.css
line:     36
command:  /frontend-audit
class:    decoy/focus-not-focus-visible
anchor:   .btn:focus:not(:focus-visible) {
match:    focus|outline|2\.4\.7
```

```decoy
id:       AS-DECOY-17
file:     apps/shop/components/account/StoreCreditPanel.tsx
line:     17
command:  /frontend-audit
class:    decoy/403-handled
anchor:   if (error instanceof ApiError && error.status === 403) {
match:    403|forbidden|permission
match:    generic|not handled|unhandled(?! (?:promise|rejection|exception))|same (error|message)|ErrorState|error state|treated as
```

```decoy
id:       AS-DECOY-18
file:     apps/shop/tests/unit/a11y.test.tsx
line:     10
command:  /frontend-audit
class:    decoy/jsdom-contrast-off
anchor:   rules: { 'color-contrast': { enabled: false } },
match:    disable|gate|contrast|neuter
```

```decoy
id:       AS-DECOY-19
file:     apps/shop/app/[locale]/globals.css
line:     10
command:  /frontend-audit
class:    decoy/hex-in-token-definition
anchor:   --color-primary: #4338ca;
match:    hex|literal|token
```

```decoy
id:       AS-DECOY-20
file:     apps/admin/src/components/charts/LatencyLine.vue
line:     21
command:  /frontend-audit
class:    decoy/zoomed-labelled-line
anchor:   beginAtZero: false,
match:    zero|baseline|beginAtZero|truncat
```

```decoy
id:       AS-DECOY-21
file:     apps/shop/components/cart/CartDrawer.tsx
line:     29
command:  /frontend-audit
class:    decoy/opacity-fade
anchor:   transition-opacity duration-150
match:    transition|motion|reduced|duration
```

```decoy
id:       AS-DECOY-22
file:     apps/shop/components/auth/OtpForm.tsx
line:     25
command:  /frontend-audit
class:    decoy/layout-arbitrary-width
anchor:   w-[320px]
match:    arbitrary|token|literal
```

```decoy
id:       AS-DECOY-23
file:     apps/shop/app/[locale]/globals.css
line:     46
command:  /frontend-audit
class:    decoy/reduced-motion-important
anchor:   animation-duration: 0.01ms !important;
match:    important
```

## Detector measurement — the pre-flight greps run on this fixture

Measured 2026-10-05 with ripgrep 15.2.0 (PCRE2 10.45), from this directory, each skill's pre-flight block copied
verbatim from `templates/packs/{frontend,ui-ux}/skills/<skill>/SKILL.md` as of that date (re-measured 2026-10-10, same
ripgrep, for `ui-state-scan`, `design-token-audit` and `chart-encoding-audit` after IR-2…IR-5), plus
`state-matrix-lint.py ai/design/state-matrix/checkout.md --repo=.`. A seed is **caught** when a grep prints its file
(file-level greps) or a line within 6 of its anchor for the class it seeds. A decoy is **hit** when a grep prints it
for the class it imitates; every decoy hit below is refuted by the read the skill already prescribes, so the decoy
produces **0 findings**. These are grep results, not a scored `/frontend-audit` run — no run is recorded in
`RESULTS.md` yet. Run from the repo root the greps print nothing here: the skills exclude `**/fixtures/**`.

| detector | seeds it owns | caught by its greps | decoys hit by the class they imitate → findings | notes |
|----------|---------------|--------------------|-----------------------------------------------|-------|
| `a11y-code-scan` | 24 (A11Y-01…08, -14, -15, -17, -18 × 2) | **24 / 24** | AS-DECOY-07 by §1 (backdrop `div onClick`) → 0: Escape + a focused close button, precedents/ui § 16. DECOY-01, -04, -05, -12, -13, -16: 0 hits | also prints AS-CH-06b (§7 colour ternary). 2026-10-10: its 0d rider grep was removed (the riders are `a11y-scan` grep 6 only), so AS-A11Y-12a is now printed once, by `a11y-scan` |
| `a11y-scan` | 10 (A11Y-09, -11, -12, -16, -22 × 2) | **5 / 10** static (12a rider, 16a and 16b as pinned layers with no `scroll-padding`, 22a and 22b by 7a/7b); 09a, 09b, 11a, 11b, 12b have no static signal **by design** — axe `color-contrast` in dark, `target-size` under `wcag22aa`, the 320 px probe | AS-DECOY-18 by 7a (`color-contrast` off in jsdom) → 0: `e2e/a11y.spec.ts` runs contrast in Chromium with `wcag22aa`. DECOY-09, -10: no static grep | §2 lists `ConfirmDeleteDialog` (AS-DECOY-02) as a surface to open — a render instruction, not a candidate |
| `ui-state-scan` | 18 (ST-01…08, -10 × 2) | **15 / 18** by a printed hit (01a, 01b, 02a, 02b, 03a, 03b via 3c — `notifications.ts:16-17`, since IR-3, 04a via 4c on the five account pages, 04b via 4a, 05a, 05b, 06b via 4a, 08a, 08b, 10a, 10b); 07a and 07b by the **repo-level** signal (grep 7 prints nothing: no network-state primitive exists); 06a by **read** only (6a counts the files that tell 403 apart — `StoreCreditPanel`, `lib/api.ts`, `AuditLogView` — and `GiftCardsPanel` is absent) | AS-DECOY-11 by 1 and 3a (`OrdersPanel`) → 0: the child renders every branch, precedents/ui § 36. DECOY-14, -15: 0 hits | other printed candidates, all refuted on read: `PlaceOrderButton`/`CheckoutSummary` (suspense hook under `checkout/loading.tsx` + `error.tsx`, ui § 35), `CartSync` (renders nothing), `lib/api.ts:21` (error-body parse), axios `create` (has `timeout`), 13 on `CartLine` remove and `SavedListsSortable` delete (one is not destructive, ui § 40; the other opens a confirm) |
| `state-matrix-lint.py` | 8 (SM-01…08) | **8 / 8**, exit 1 — both `state-missing` rows at line 6, the rest at their own rows | — | |
| `motion-audit` | 8 (MO-01…04 × 2) | **8 / 8** (§1, §2, §3, §5) | AS-DECOY-21 (`transition-opacity duration-150`): 0 hits in §1/§2, counted once in the §4 duration census | §6 also prints `KpiCounter` 1.2 s and the ticker; §7 prints 11 `animate-pulse` skeletons (stop when content loads) |
| `design-token-audit` | 8 (TK-01, -02, -04, -08 × 2) | **8 / 8** (§1, §2, §4, §8) | AS-DECOY-23 by §5 (reduced-motion `!important`) → 0: the documented exception. DECOY-19 (hex inside `@theme`), DECOY-22 (`w-[320px]`): 0 hits | §1 also prints the chart colours of CH-06a/b. §5: 4 lines, all DECOY-23 (the Vue `:class` negation is gone since IR-4); §6: 10 `apps/shop` files (was 24 — the 14 cross-app `apps/admin` files are gone since IR-5); §9 none after the fixture's own unused tokens were removed |
| `chart-encoding-audit` | 6 (CH-02, -05, -06 × 2) | **6 / 6** (§2, §5, §6 — 06a `SpendChart.tsx:30` and 06b `RevenueBars.vue:17` by grep 6's two-hex ternary since IR-2; both also printed by `design-token-audit` §1, 06b by `a11y-code-scan` §7) | AS-DECOY-20 by §2 (`beginAtZero: false` on a labelled line) → 0: chart-encoding §2 allows a labelled zoom on a line | |

Totals: **76 of 82** seeds produce a grep hit (or, for ST-07, the repo-level empty result) in their owner's
pre-flight; **5** are rendered-only by design (A11Y-09a/b, -11a/b, -12b); **1** is reachable only by reading (ST-06a);
**0** are missed (ST-03b and CH-06a/b were, until IR-3 and IR-2 on 2026-10-10). **0 decoys** survive their owner's prescribed read; the 5 decoy
grep hits above are the ones that read exists to refute.

### Integrator requests (skill gaps found by this fixture — the skills are other agents' files)

- **IR-1 — `/frontend-audit` (frontend pack):** no command dispatches `chart-encoding-audit`; the class ledger has no
  chart row. Add a `charts` row (or fold it into `tokens`) so CH-02/-05/-06 have an owner in the audit. — **fixed
  2026-10-10**: `/frontend-audit` dispatches `chart-encoding-audit` (ui-ux, when installed) as the Chart encoding row,
  family `charts`; `/frontend-fix` carries its oracle row; the Invocation above adds `charts`.
- **IR-2 — `chart-encoding-audit` grep 6:** it requires the hex directly after `fill=` / `backgroundColor:`, so a series
  colour chosen by a ternary or a `.map` callback is invisible — `fill={c >= 0 ? '#16a34a' : '#dc2626'}`,
  `backgroundColor: points.map((p) => (ok ? '#22c55e' : '#ef4444'))`. Add a two-hex ternary alternation, e.g.
  `\?\s*["']#[0-9a-fA-F]{3,8}["']\s*:\s*["']#[0-9a-fA-F]{3,8}["']`, scoped to `$CFL`. — **fixed 2026-10-10**: grep 6
  gained that alternation; it prints CH-06a and CH-06b and no decoy.
- **IR-3 — `ui-state-scan` greps 3b/3c:** only `setX([])` counts as "failure turned into empty". A store or ref
  mutation in the `catch` is missed — Pinia `catch { this.items = [] }` (AS-ST-03b), Vue `items.value = []`, a MobX
  class field. Add `catch\s*(?:\([^)]*\))?\s*\{\s*(?:this\.\w+|\w+\.value)\s*=\s*(?:\[\]|null|\{\}|""|''|0)`. — **fixed
  2026-10-10**: 3b keeps the one-line `.catch(() => …)` forms; 3c (`-U`) now takes every catch block, `catch {` or
  `.catch(e => {`, whose first statement empties a setter, `this.x` or `x.value` — the IR's pattern alone could not
  match, since the seed's assignment sits on the line after `catch {`. Prints `notifications.ts:16-17`; nothing else new.
- **IR-4 — `design-token-audit` grep 5:** the class-attribute alternation matches a JS negation in a Vue object binding,
  `:class="{ unread: !n.read }"`, as a Tailwind important modifier. Exclude `:class=` / `v-bind:class=` bodies, or
  require a utility-shaped token (`!\w+-`) after the `!`. — **fixed 2026-10-10**: the modifier alternations now need a
  class *string* — `(?<![:\w.-])class(?:Name)?=\{?["'\x60]` — so bound `:class` / `className={!x …}` JS is skipped
  (`!hidden`, which has no `-`, is still caught). `NotificationsPanel.vue:19` is gone.
- **IR-5 — `design-token-audit` §6:** in a monorepo the DS root found in one app (`apps/shop/components/ui`, which
  exports `Button`) is paired against every root, so 13 `.vue` files in `apps/admin` — an app with no `Button` — are
  listed `button → Button`. Pair each DS root only with files under the root (`ROOTS` entry) that contains it. —
  **fixed 2026-10-10**: grep 6 loops per app root; a root is paired with the DS roots inside it or in a workspace
  package its `package.json` names, and nested roots are excluded. The 14 `apps/admin` rows are gone; the 10
  `apps/shop` rows remain.
