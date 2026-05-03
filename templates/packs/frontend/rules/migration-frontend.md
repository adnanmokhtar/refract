---
name: migration-frontend
description: Frontend-specific extensions to migration-discipline — audit axes, anti-patterns, fingerprints. Stack examples are illustrative; substitute equivalents from your project's `_extracted-idioms.md`.
kind: rule
pack: frontend
extends: migration/rules/migration-discipline.md
---

> **STACK-AGNOSTIC**: Inline syntax in this doc is illustrative. Stack-specific primitives are filled by `/setup-project` Phase 4.6 from the project's `_extracted-codebase.md` / `_extracted-idioms.md`. `<TBD: ...>` placeholders survive until then. See also this pack's `STACK.md`.


# Frontend extensions to migration discipline

The universal `migration-discipline.md` rule (in the migration pack) defines the V1→V2 port discipline in stack-agnostic terms — state machine, contract, audit halts, gate. This file adds the frontend-specific surface that the universal rule references but does not enumerate.

If your project's frontend is in this pack's covered stack family (any modern component framework — Vue, React, Svelte, Angular, Nuxt, Next, etc.), follow the rules below in addition to the universal discipline. Stack-specific examples in this file are **illustrative** — substitute the actual primitives from your project's `_extracted-idioms.md`.

## Stack-aware primitive set (frontend)

The validator's `extract_inventory_primitives` extracts these primitive classes from frontend leaf-component files. Auto-promote thresholds (count differential > 30%) trigger standard-tier audit requirements.

| Primitive | What it counts (across Vue / React / Svelte / Angular / Solid) | Axis (where the audit must enumerate the gap) |
|---|---|---|
| `v_model` | Form-field bindings: Vue `v-model=`, React `value=` + `onChange=` paired (proxy: `useState` form-state hooks), Svelte `bind:value=` / `bind:checked=`, Angular `[(ngModel)]=` | Form fields |
| `dropdown` | `<Dropdown>`, `<Select>`, `<MultiSelect>`, native `<select>`, framework-specific equivalents (`<v-select>`, `<mat-select>`, `<MenuItem>`, `<Combobox>`) | UI affordances / Form fields |
| `button` | `<Button>`, `<button>`, `<v-btn>`, `<AppButton>`, `<IconButton>`, `<mat-button>` | UI affordances |
| `click_handler` | Vue `@click=` / `@submit=`, React `onClick=` / `onSubmit=` / `onChange=`, Svelte `on:click=` / `on:submit=`, Angular `(click)=` / `(submit)=` / `(ngSubmit)=` | Event handlers |
| `permission_gate` | `hasPermission(`, `meta.permission`, `<RequirePerm>`, `useAuth(`, `<ProtectedRoute>`, `*ngIf="canAccess"`, `v-can=` | Per-button permission gates |
| `tabs` | `<v-tabs>`, `<TabView>`, `<Tabs>`, `<NavLink>` in nav role, `<mat-tab-group>`, in-page tab arrays | Section 0 — Navigation Inventory |
| `route_def` | Inside `*routes*` / `*router*` files: `path:` + `name:` (Vue/Angular Router), `<Route>` (React Router), `+page.svelte` filenames (SvelteKit), `pages/` files (Next/Nuxt) | Section 0 — Navigation Inventory |
| `input_html` | Raw + framework form inputs: `<input>`, `<textarea>`, `<TextField>`, `<TextareaAutosize>`, `<Input>`, `<TextInput>`, `<v-text-field>`, `<v-textarea>` | Form fields |
| `conditional_render` | Vue `v-if=` / `v-show=` / `v-else-if=`, React `&&` JSX / ternary in JSX, Svelte `{#if}` / `{#else if}`, Angular `*ngIf=` | Event handlers / Reactive lifecycle |

The `extract_inventory_primitives` function is framework-comprehensive within `frontend-*` — it patterns Vue, React, Svelte, Angular, Solid, plus the major UI-library primitives (Vuetify, PrimeVue, MUI, Ant Design, Mantine, Chakra, shadcn). Adding a new framework requires only a new pattern alternation in the function (no new check needed).

## Frontend audit axes (when feature is a UI page / component / route)

The 6 generic comparison axes from the universal rule (Inputs / Outputs / Error contract / Auth + permissions / Side effects / Performance) are necessary but NOT sufficient for frontend ports. Add these axes for any feature whose V1/V2 entry is a page / component / route / screen:

- **Navigation inventory (MANDATORY when feature scope spans more than one page or any tabbed surface; TWO-LAYER scan)** — enumerate every user-clickable navigation target reachable from the module entry: top-level tabs, in-page sub-tabs, sidebar items, accordion groups that gate distinct content, modal-shell tabs, inner-routes (`<router-view>` siblings), tab-bar entries, and any other tab-shaped affordance. The scan MUST run in two layers; Layer-A-only is incomplete and HALTS:
  - **Layer A — Route tree**: read every router file in V1 + V2; build the route hierarchy. Catches top-level tabs + route children + redirects.
  - **Layer B — Per-leaf template grep (MANDATORY, not optional)**: for EACH leaf component identified in Layer A, open its source and grep for in-template tab patterns. If ANY match, those are ADDITIONAL nav leaves to enumerate under that parent. Patterns to scan: framework-specific tab components (`<v-tabs>`, `<TabView>`, `<TabMenu>`, `<Tabs>`, `<Tab>`, `<v-tab>`, `role="tab"`, `<nav>` with role=tablist), sidebar config arrays / sidebar `links` lists / menu data files, in-page tab arrays (`v-for tab in tabs|items|sections`, `tabs.map(t => …)`, `[{label, path|value}]` literals at template scope), `<router-view>` siblings inside a component (nested sub-routing), accordion title arrays.
  - Same two-layer scan applied to V2. Then 1:1 mapping table: every V1 navigation leaf must have a V2 equivalent navigation surface. **Burying V1 sub-tabs as scrollable sections inside another V2 tab is DRIFT.** Splitting one V1 tab into multiple V2 routes is DRIFT unless an accepted ADR documents the restructure. The path-to-reach a feature is observable behaviour; "user reaches X via this tab in V1, via that tab in V2" is parity; "user reaches X via this tab in V1, via scroll-to-section in V2" is not.
  - **Why both layers**: routes-only extraction misses in-component tab UIs (e.g., a marketing page that uses ONE route but renders 14 platform tabs via a radio-button + `v-if` pattern in its template). Without Layer B, the marketing route is marked "PARITY" while the 14 internal tabs were never compared.
  - **Section 0 completion checklist** (every box ticks before audit advances past Section 0): V1 routes extracted from every router file ✓ · V2 routes extracted ✓ · for EACH V1 route leaf, component source opened + grep'd for tab patterns; matches enumerated ✓ · same for V2 ✓ · V1 leaf set ↔ V2 leaf set diffed ✓ · every V1 leaf has a V2 equivalent OR is flagged DRIFT with closure verb ✓ · every V2-extra leaf flagged for V1-parity decision ✓.
  - This axis appears as Section 0 in every module-scoped audit, before per-axis enumeration begins.
- **Form fields** — enumerate every input on the page: name, type, validation rules (declared + inline), default value, placeholder, required vs optional, disabled-when, hidden-when. Every form field is a contract surface; missing one = silent break.
  - **Density requirement**: forms-bearing UI-leaf components (≥5 form-input elements in V1 source) MUST produce a per-field enumeration table in the audit's "Form fields" axis section, with one row per V1 input citing both `<v1-path:line>` and `<v2-path:line>`. PARITY verdicts MUST be backed by table rows where every V1 field has a corresponding V2 path; DRIFT verdicts list missing/changed fields with closure verbs. The validator's `check_per_axis_enumeration` halts on density failure.
- **UI affordances** — enumerate every button, link, dropdown, modal trigger, file-upload control, toggle switch, copy-to-clipboard button, "view detail" link. Each affordance has a permission gate, an event handler, and an observable effect.
  - **Density requirement**: UI-leaf components with ≥3 affordances in V1 (buttons + dropdowns + modal triggers + toggles, summed) MUST produce a per-affordance enumeration table citing both `<v1-path:line>` and `<v2-path:line>` plus per-row permission-gate column and observable-effect column. PARITY verdicts require every V1 affordance mapped to a V2 affordance; DRIFT verdicts list extras/missing with closure verbs. The validator's `check_per_axis_enumeration` halts on density failure.
- **Templated query params** — enumerate every URL query param the page reads (router.query, useSearchParams, useRouter, etc., per the project's framework). V1's list endpoint may filter by 6 params; V2 may send 4. The list endpoint's contract is "the union of every param V1 sends" — verify by reading the V1 list call construction line by line.
- **Event handlers** — every click / submit / change / input handler — what it calls, with what args, what the side effect is.
  - **Density requirement**: UI-leaf components with ≥3 distinct event handlers in V1 MUST produce a per-handler table citing both `<v1-path:line>` and `<v2-path:line>` plus the called function/method on each side. The validator's `check_per_axis_enumeration` halts on density failure.
- **Per-button permission gates** — V1 may hide an action via a permission check (`v-if="hasPermission(...)"` / `{user.can(...) && ...}` / framework equivalent) — V2 must render the same gate. Enumerate; per-button audit. Missing a gate is a security regression.
  - **Density requirement**: any UI-leaf with ≥1 permission gate on V1 OR V2 MUST produce a per-button gate table citing both `<v1-path:line>` and `<v2-path:line>` and listing the gate expression verbatim on each side. PARITY requires identical gate expressions; gate-divergence is a P0/P1 finding. The validator's `check_per_axis_enumeration` halts on density failure.
- **Accessibility** — keyboard navigation order, ARIA labels on icon-only buttons, focus management on modal open/close, screen-reader-only text. axe-core baseline + diff is the parity test.
- **DOM-equivalent** (use the `dom-equivalent` tolerance class from `parity-testing.md`) — semantically equal markup; pixel-perfect not required but structural parity is.
- **Reactive lifecycle** — V1's mount-only data fetch vs V2's mount-AND-reactivate (when the framework supports keep-alive / cached routes); refetch-on-locale-change; refetch-on-tenant-switch. Stale-on-tab-return is a tenant leak vector for multi-tenant apps.

## Frontend anti-pattern catalogue (V1 → V2 hot list)

These recur in every frontend V1→V2 port across most component frameworks. Add to the project-specific anchor's framework column when relevant. Examples below use Vue 3 syntax for illustration; substitute your framework's equivalent (React: `useEffect`, `useMemo`, `useCallback`; Svelte: `$:` reactive, `onMount`; Angular: `ngOnInit`, `ChangeDetectionStrategy`).

| V1 anti-pattern | Why it's bad | V2 fix (illustrative — substitute per stack) |
|---|---|---|
| `array.find()` / `array.includes()` inside a render-loop | O(N²) on every render | Build `Map` / `Set` once via memoised computed; O(1) lookup |
| Sequential `await` in mount-hook for independent fetches | Blocks first paint by sum of latencies | `Promise.all` for independent calls; lazy-load non-critical |
| Auth/session value read directly from `localStorage` outside the canonical token-storage helper | Tenant leak: stale value survives logout | Read from live store (Pinia / Redux / Zustand / NgRx / etc.); `logout()` clears the store |
| Mount-only data fetch on a cached / keep-alive'd page | Stale on tab return / tenant switch | Use the framework's reactivate hook in addition (`onActivated` for Vue 3 KeepAlive; Next/Nuxt route-revisit handler; `useFocusEffect` for React Native; etc.) |
| Raw HTML insertion (`v-html` / `dangerouslySetInnerHTML` / `innerHTML`) without sanitize | XSS surface | Route through DOMPurify wrapper; document the sanitize boundary |
| Search input wired directly to API without debounce | API spam; 1 request per keypress | `useDebounceFn(fetch, 300)` / `_.debounce` / RxJS `debounceTime` per stack |
| DDL / lookup endpoints refetched on every dialog open | N×call per session | Module-level cache with TTL; invalidate on logout |
| Missing route lazy-load (eager import of route component) | Huge initial bundle | Per-route dynamic import |
| Per-page inline business logic | Untestable; duplicated across pages | Extract to composable / hook / service per stack convention |
| Manual `Authorization: Bearer ${token}` headers in service calls | Bypasses interceptor + refresh queue; double-source-of-truth on token | Interceptor on the HTTP client only; never per-call |
| Unthrottled timer / interval / event listener in mount without cleanup | Memory leak; multiple instances on KeepAlive resume | Cleanup hook return / `onUnmounted` / `useEffect` cleanup; clean up the timer |
| Per-component `httpClient.create(...)` outside the canonical client | Double interceptors, unrelated refresh logic | Single canonical client per app; no per-feature creation |
| Routes redirect via path strings | Refactor-fragile | Named routes per framework |
| Translation fields sent as `{ en: ..., ar: ... }` flat objects | Backend may want envelope; assumes 2 languages | Match V1's submitted shape exactly; for dynamic-language tenants, build the object from the project's available-languages source |
| **The Buried Tab** — V2 collapses V1 sub-tabs into scrollable sections in another V2 tab | User-clickable navigation path is part of V1's contract; collapsing it into a section changes the way users reach the feature. Source-only audits report STRUCTURE_OK because the underlying components exist. | Restore V1's tab as a discrete navigation surface in V2 (new sidebar entry + route OR new in-page sub-tab). Do NOT leave it buried as a section unless an accepted ADR documents the navigation restructure. |
| **The Fragmented Tab** — V2 splits one V1 tab into multiple separate V2 routes/pages | Same observable-navigation drift as Buried Tab: the user's click path no longer matches V1. | Either (a) consolidate the fragmented routes back into the V1 tab shape, or (b) document the restructure with an accepted ADR that includes user-decision quote. Default closure is (a). |
| **The Consolidated Page** — V2 moves a V1 **separate page/route** into a tab inside another V2 page (e.g., V1's standalone page at `/module/subpage` → V2's "Subpage" tab inside `/module`). The reverse is also drift: a V1 tab becoming a V2 standalone page. | The user's click path changes: a separate navigation target (with its own URL, back-button behaviour, direct-linkability) becomes a tab click, or vice versa. This is observable behaviour, not structure. Source-only audits that see the component exists somewhere in V2 falsely report parity. | Restore the V1 navigation structure: if it was a separate page in V1, keep it a separate page in V2; if it was a tab in V1, keep it a tab in V2. Default closure is revert-to-V1-shape. An accepted ADR with `user_decision_quote` is required to keep the consolidation. |
| **The Layer-A-Only Scan** (audit-process anti-pattern, not a code drift) — auditor extracts route hierarchy from `<TBD: router-file>` entries (e.g. Vue `routes.ts`, Next `pages/`/`app/`, SvelteKit `+page`/`+layout`, Angular routing modules) but skips per-leaf template grep. Misses in-component tab UIs (`nav_tabs` radio arrays, `<TBD: tab-primitive>` blocks, accordion arrays, in-page `<TBD: iteration-construct>` over `tabs|items|sections`) that live inside route components — see **Stack-aware primitive set** above for Vue / React / Svelte / Angular analogues. Symptom: a route is marked "PARITY" but its 14 internal tabs were never compared between V1 and V2. | The route file shows the route exists; the auditor stops there. But routes !== tabs; many components render their own internal tabs that don't appear in route definitions. A Layer-A-only scan produces high-confidence false PARITY verdicts on the components that contain hidden tab UIs. | Mandate Layer B (per-leaf template grep) explicitly. Section 0 cannot complete until every leaf component identified by Layer A has been opened and grep'd for tab patterns. The Section 0 completion checklist enforces this. |

## Frontend Transposition Trap fingerprints

The universal `migration-discipline.md § Anti-patterns` defines The Transposition Trap as a generic concept (line-by-line copy of V1 into V2 instead of re-derivation against V2's gold standard). Concrete frontend fingerprints — the validator's `check_v2_structure` HALTs on these in V2 files (stack-conditional via `PROJECT_KIND`):

- **Raw framework / UI-library components in pages where wrappers exist.** Each project ships shared wrappers (modal / paginator / dropdown / date / phone / form-field / image-upload). Using the underlying library component directly bypasses the project's defaults (RTL, theme tokens, focus management, ARIA wiring, validation styling).
- **Double-translation on label props.** A shared field-wrapper component that calls `t()` internally must receive a bare i18n key, not a pre-translated value. Passing `:label="t('Module.key')"` produces missing-key warnings + bare keys rendered to users.
- **Wrapper col around a field-wrapper that has a `col-class` prop.** Nested grid cols inside the project's grid system break the layout silently — labels misalign, child components collapse to weird widths.
- **Hand-rolled phone field / language toggle / currency-prefix input** when the project ships dedicated wrappers.
- **Auth/session in plain `localStorage`** outside the canonical secure-storage / token-provider helper.
- **`httpClient.create(...)` outside the canonical HTTP client file** — exactly ONE authenticated client per app.
- **`console.log` / `console.debug`** in production code (ESLint rule, but check anyway).
- **Manual `Authorization: Bearer ${token}` headers** — bypasses interceptor + refresh queue.
- **Raw `<form @submit>` in dialogs/pages** when the project ships a `<BaseForm>` / form-wrapper that provides `<fieldset disabled>` + grid wrapper.
- **Inline `style="..."`** — use scoped styles + design tokens.
- **V1's grid system carried over verbatim** — V1 may use Bootstrap col wrappers; V2 may use component-level `col-class` props. Re-derive layout from V2's gold-standard equivalent feature, not from V1's template.
- **Mount-only data fetch on a page the project's KeepAlive equivalent caches** — use the framework's reactivate hook so data refreshes on tab return + tenant switch.
- **Hardcoded translation language keys** — `{ en: '', ar: '' }` literal initialisers, `locale.value === 'en' ? 'en' : 'ar'` ternaries, flat `name_ar`/`name_en` reactive fields. Tenants with other languages enabled get broken UI; tenants with a language disabled get stale dead keys. The correct pattern is: build empty translations from the project's available-languages source (Vue-style `useLanguages().buildEmptyTranslations()` · React locale hooks/stores · Angular `LocaleService` / i18n pipes · Svelte locale stores — names from `_extracted-idioms.md`); use the active locale string directly without ternary reduction.

## Phase 3 (Retrieve) — frontend specifics

The universal rule's Phase 3 mandates "read V2's gold standards before writing." For frontend:

- **CRUD list page** → read the project's gold-standard list page (`_extracted-codebase.md § Gold standards` names it).
- **Detail / show page** → read the gold-standard detail page.
- **Dialog / form** → read at least 2 V2 dialogs that use the same shared wrappers.
- **Composable / hook** → read the V2 equivalent.
- **Service / data-access** → read 1 service in the same module + the canonical `BaseCrudService` (or stack equivalent).

Mirror these files' shape: same component-composition pattern, same prop naming conventions for label / col-class / required / disabled, same shared-wrapper substitutions. The `mapping/<feature>.md` artifact (required at every tier per universal rule) names every wrapper / util / hook the port will use.

## Locale parity

- Each user-facing string lands in EVERY declared locale (typically `en` + `ar` for Arabic-first projects; varies per project).
- Per-module locale files are auto-merged at build; cross-module shared keys live in the shared locales directory.
- The validator's `check_i18n_locale_parity` enforces "if a key exists in one locale, it exists in all."

## Cross-references

- Universal discipline: `migration/rules/migration-discipline.md`
- Frontend principles: `frontend/rules/frontend-principles.md`
- Frontend i18n: `frontend/rules/i18n.md`
- Validator script: `scripts/validate-migration-artifacts.sh § check_v2_structure` (stack-conditional via `PROJECT_KIND`)
