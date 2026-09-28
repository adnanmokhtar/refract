---
artifact: engineering-baseline/web
purpose: Web frontend rows. Applies to PROJECT_KIND frontend-* and the browser half of mixed. mobile.md points back here for the rows both share.
---

# Baseline — web

Format and verdicts: `README.md` in this directory.

| ID | Standard | Fires when the change… | MET means | Checked by | Source |
|---|---|---|---|---|---|
| WEB-1 | UI is built from the project's shared components and design-system primitives; a raw primitive never stands where a wrapper exists, and repeated UI becomes a component instead of a copy. | adds or changes a page or component | sibling-shape verdict `aligned` on the wrapper axis | gate · sibling-shape halt · `/unify-surfaces` | `packs/frontend/rules/frontend-principles.md` · `packs/ui-ux/ai-patterns/design-systems.md` |
| WEB-2 | Colour, spacing, radius, type and motion come from design tokens; one styling system per repo; no duplicated style blocks. | adds styles | no literal colour / spacing values in the diff | gate · `standards-check.py` · `@design-system-guardian` | `packs/frontend/rules/frontend-principles.md` · `packs/ui-ux/ai-patterns/theming.md` |
| WEB-3 | Remote data goes through the project's API client and query cache — declared staleness, in-flight dedupe, invalidation on mutation, cancellation on unmount. No `fetch` / `axios` in a component body. | adds a remote read or write | the service / hook site; the invalidated keys | gate · `standards-check.py` · `@ui-reviewer` | `packs/frontend/rules/frontend-principles.md` |
| WEB-4 | Errors go through the project's standard path: API errors mapped by the shared client, an error boundary with retry on every route root and independent subtree, and a global net for async rejections. | adds a route, a request, or an independently-failing widget | the boundary and mapping sites | gate · `@ui-reviewer` | `packs/frontend/rules/frontend-principles.md` |
| WEB-5 | Every data-dependent view has a loading state (layout-stable skeleton), an empty state and an error state. | adds a view, list or widget that loads data | all three states present in the diff | gate · `@ui-reviewer` | `packs/ui-ux/rules/ui-principles.md` · `packs/frontend/rules/frontend-principles.md` |
| WEB-6 | A form validates against the backend's schema — shared or generated — and the server still validates. | adds a form | the schema import; the server-side validator it mirrors | gate | `domains/forms/rules/forms-discipline.md` · `packs/frontend/rules/frontend-principles.md` |
| WEB-7 | Role-gated UI uses the project's permission primitive, and hiding is never the control — the server denies the same action (SEC-04). | adds an action or route restricted by role | the gate primitive site and the server's denial test | gate | `domains/auth/rules/auth-discipline.md` |
| WEB-8 | WCAG 2.2 AA: semantic elements, labelled inputs, keyboard reachable, visible focus. | adds interactive UI | axe clean on the changed route and a keyboard pass | gate · `a11y-scan` · `/a11y-audit` | `packs/frontend/rules/frontend-principles.md` · `packs/ui-ux/rules/ui-principles.md` |
| WEB-9 | Layout holds at every declared breakpoint with no horizontal scroll at the narrowest. | adds or changes a layout | a screenshot per breakpoint | gate · `verify-with-playwright` | `packs/ui-ux/rules/ui-principles.md` |
| WEB-10 | Performance floor: LCP image prioritized, routes lazy, long lists virtualized, bundle delta measured, INP work bounded. | adds a route, a heavy dependency, a large list or an expensive handler | the bundle delta from `bundle-analyze` (or `unmeasured`, never `acceptable`) | gate · `bundle-analyze` · `lighthouse-ci` | `packs/frontend/rules/frontend-principles.md` · `packs/performance/rules/performance-principles.md` |
| WEB-11 | Every user-facing string is an i18n key present in every declared locale. | adds text | the keys in each locale file | gate · `/i18n-audit` | `packs/frontend/rules/frontend-principles.md` |
| WEB-12 | The changed flow was driven in a real browser: navigate, act, assert, screenshot, zero console errors. | changes anything a user sees | the Playwright run or screenshot, named | gate · `verify-with-playwright` | `packs/frontend/commands/add-feature.md` § Phase 6 |
