---
name: migration-frontend
description: Frontend-specific extensions to migration-discipline — audit axes, anti-patterns, fingerprints. Stack examples are illustrative; substitute equivalents from your project's `_extracted-idioms.md`.
kind: rule
pack: frontend
extends: migration/rules/migration-discipline.md
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses one stack as illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# Frontend extensions to migration discipline

The universal `migration-discipline.md` rule (in the migration pack) defines the V1→V2 port discipline in stack-agnostic terms — state machine, contract, audit halts, gate. This file adds the frontend-specific surface that the universal rule references but does not enumerate.

If your project's frontend is in this pack's covered stack family (any modern component framework — Vue, React, Svelte, Angular, Nuxt, Next, etc.), follow the rules below in addition to the universal discipline. Stack-specific examples in this file are **illustrative** — substitute the actual primitives from your project's `_extracted-idioms.md`.

## Frontend audit axes (when feature is a UI page / component / route)

The 6 generic comparison axes from the universal rule (Inputs / Outputs / Error contract / Auth + permissions / Side effects / Performance) are necessary but NOT sufficient for frontend ports. Add these axes for any feature whose V1/V2 entry is a page / component / route / screen:

- **Form fields** — enumerate every input on the page: name, type, validation rules (declared + inline), default value, placeholder, required vs optional, disabled-when, hidden-when. Every form field is a contract surface; missing one = silent break.
- **UI affordances** — enumerate every button, link, dropdown, modal trigger, file-upload control, toggle switch, copy-to-clipboard button, "view detail" link. Each affordance has a permission gate, an event handler, and an observable effect.
- **Templated query params** — enumerate every URL query param the page reads (router.query, useSearchParams, useRouter, etc., per the project's framework). V1's list endpoint may filter by 6 params; V2 may send 4. The list endpoint's contract is "the union of every param V1 sends" — verify by reading the V1 list call construction line by line.
- **Event handlers** — every click / submit / change / input handler — what it calls, with what args, what the side effect is.
- **Per-button permission gates** — V1 may hide an action via a permission check (`v-if="hasPermission(...)"` / `{user.can(...) && ...}` / framework equivalent) — V2 must render the same gate. Enumerate; per-button audit. Missing a gate is a security regression.
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
- **Hardcoded translation language keys** — `{ en: '', ar: '' }` literal initialisers, `locale.value === 'en' ? 'en' : 'ar'` ternaries, flat `name_ar`/`name_en` reactive fields. Tenants with other languages enabled get broken UI; tenants with a language disabled get stale dead keys. The correct pattern is: build empty translations from the project's available-languages source (`useLanguages().buildEmptyTranslations()` for the typical Vue 3 helper; analogous in React/Svelte); use the active locale string directly without ternary reduction.

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
