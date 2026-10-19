# Seeded defects — `launch-gaps`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the agent scans. If you stage
the fixture by hand, delete this file from the copy first — an agent that reads it will score 100% and the number will
mean nothing.

Fixture shape: `Shelfwise` — a pnpm monorepo for an inventory SaaS with three plans and seven paid extensions: a NestJS 11 / Fastify API with two entitlement guards, a React 19 + Vite SPA with a tracking wrapper, catalogs, billing config, pricing data, success files, a tracking plan, specs and a Gherkin suite; 59 product seeds over 27 classes, 3 routed, 16 decoys.

The API runs MikroORM, Stripe Checkout and posthog-node; the SPA runs React Router 7, TanStack Query, i18next and a
`trackEvent` wrapper over PostHog, the Meta pixel and a Conversions-API server leg; the contracts package holds the
module and extension catalogs and the plan map; `ai/` holds two success definitions, the tracking plan, an assumption
ledger, a refunds spec and a run ledger.

Invocation: /audit-requirements --repo
Invocation[/security-audit]: /security-audit
Invocation[/devops-audit]: /devops-audit --whole-repo
Stage with: --git — the audits read the history for their context map, and a whole-repo run on a copy with no base
branch has no diff to scope to.

Eval source: Track A batch 7, `eval-batch7-product.md` § 2 (class map), § 3.6 (the real target's shapes), § 4.11
(fixture design), § 6 item 23. Classes are the research catalog's `PR-*` ids; precedents are
`templates/snippets/precedents/product.md` § n; proofs are `proof-oracles.md` § Product (V409–V429). Roots:
- `apps/api` — NestJS 11 on Fastify: `setGlobalPrefix('api')`, controllers with `@RequireModule`, two `APP_GUARD`s that
  split the keys (coarse `MODULE_KEYS` vs `EXTENSION_SLUGS`, each passing the other's), Stripe Checkout and an
  entitlement-summary sync, posthog-node, a CAPI forwarder that hashes identifiers;
- `apps/web` — React 19 + Vite: route objects in `app/router.tsx`, the `http` ky client (`prefixUrl: '/api'`), the
  tracking wrapper, `useModuleEnabled`, an i18next catalog, a route allow-list and the reverse-route parity test it
  feeds, `nginx.conf` (production proxy) and `vite.config.ts` (dev proxy), build-time flags in `.env.*`;
- `packages/contracts`, `config`, `marketing` — the catalogs and plan map, the billing limits and lookup keys, the
  pricing page's numbers;
- `ai/product` (success files, tracking plan, assumptions), `ai/specs`, `ai/runs`, `features/` + `cucumber.js`,
  `apps/api/test`, `.github/CODEOWNERS`.

Departures from the eval, stated so a reader can audit them:
- **59 product seeds, not 57.** The eval's seed list has no PR-TR-4 row; the task asks for two per acceptance class, so
  two are added: one the mechanical `ears-lint.py` lane finds (run-ledger format), one only the manual four tests find
  (prose spec).
- **The eval's "EN-6 UI-only gate" routed seed is PR-EN-7** (the class map's id for a client-only entitlement) and the
  "PII property" seed is PR-AN-8; both score under `/security-audit`.
- **16 decoys, not 14.** The eval's 14, plus the reverse-route control that explains an uncalled route (PP-FS-7) and an
  outcome event fired after the outcome (`Order Placed` in `onSuccess`).
- **The FastAPI + Jinja lanes are not duplicated here**, as the eval says: `half-built-crm` carries them.

Ownership and scoring. Three runs, three results rows, each staged in its own copy. **`/audit-requirements --repo`**
scores the 59 product rows. Its LR and SC seeds live in two success files: `launch-readiness` scores each success
file at feature scope (its 3,000-hit path, step 1) — a plain repo-scope run marks the feature-only rules N/A and finds
only the two assumption rows. The 3 routed rows score **only under their owner** — `/security-audit` (2: PII in
an event property, a client-only entitlement) and `/devops-audit` (1: a stale release flag) — and `/audit-requirements`
must list each as a routed row with its owner, never grade it; an `/audit-requirements` finding on them is UNMATCHED, not
credited. `bucket:` is the row's expected disposition: `report-with-fix` (the oracle can fail first and the fix is local),
`report-flagged` (a person decides: which number is the contract, build or remove, an unproven render), `Hardening`
(hygiene, or a scorecard FAIL above the feature's target level), `routed` (owner line only).

Secrets. None. The Stripe ids are fabricated and carry no key; the PostHog and pixel values in `.env.*` are public
client identifiers by design and fabricated here.

Line numbers are exact against the files in this directory and are re-checked by `benchmarks/run.sh --verify`, which also
fails if a decoy sits within 12 lines of a defect in the same file. Every line was computed from its anchor.

## Summary

| id | file:line | severity | command | class | bucket |
|----|-----------|----------|---------|-------|--------|
| LG-FS1-a | `apps/web/src/entities/permissions/use-permissions.ts:14` | critical | `/audit-requirements` | PR-FS-1 | report-with-fix |
| LG-FS1-b | `apps/web/src/features/stores/StoresPage.tsx:19` | high | `/audit-requirements` | PR-FS-1 | report-with-fix |
| LG-FS1-c | `apps/web/src/features/orders/OrderDetail.tsx:23` | high | `/audit-requirements` | PR-FS-1 | report-with-fix |
| LG-FS2-a | `apps/api/src/api-keys/api-keys.controller.ts:19` | medium | `/audit-requirements` | PR-FS-2 | report-flagged |
| LG-FS2-b | `apps/web/src/shared/api/route-reasons.txt:4` | low | `/audit-requirements` | PR-FS-2 | report-flagged |
| LG-FS3-a | `apps/web/src/layout/Sidebar.tsx:21` | high | `/audit-requirements` | PR-FS-3 | report-with-fix |
| LG-FS3-b | `apps/web/src/features/orders/OrdersPage.tsx:26` | medium | `/audit-requirements` | PR-FS-3 | report-with-fix |
| LG-FS3-c | `apps/web/src/features/onboarding/WelcomePage.tsx:12` | high | `/audit-requirements` | PR-FS-3 | report-with-fix |
| LG-FS4-a | `apps/web/src/i18n/locales/en.json:21` | high | `/audit-requirements` | PR-FS-4 | report-flagged |
| LG-FS4-b | `apps/api/src/exports/exports.controller.ts:10` | high | `/audit-requirements` | PR-FS-4 | report-with-fix |
| LG-FS4-c | `apps/web/src/features/dashboard/use-top-products.ts:11` | high | `/audit-requirements` | PR-FS-4 | report-with-fix |
| LG-FS4-d | `apps/api/src/insights/insights.service.ts:14` | high | `/audit-requirements` | PR-FS-4 | report-with-fix |
| LG-FS5-a | `apps/web/src/features/orders/OrdersToolbar.tsx:11` | medium | `/audit-requirements` | PR-FS-5 | report-with-fix |
| LG-FS5-b | `apps/web/src/features/dashboard/DashboardPage.tsx:42` | medium | `/audit-requirements` | PR-FS-5 | report-with-fix |
| LG-AN1-a | `apps/web/src/features/billing/CouponField.tsx:16` | medium | `/audit-requirements` | PR-AN-1 | report-with-fix |
| LG-AN1-b | `apps/api/src/stores/stores.service.ts:25` | medium | `/audit-requirements` | PR-AN-1 | report-with-fix |
| LG-AN2-a | `ai/product/success/referrals.md:12` | high | `/audit-requirements` | PR-AN-2 | report-with-fix |
| LG-AN2-b | `ai/product/tracking-plan.yaml:53` | medium | `/audit-requirements` | PR-AN-2 | report-with-fix |
| LG-AN2-c | `ai/product/tracking-plan.yaml:15` | medium | `/audit-requirements` | PR-AN-2 | report-with-fix |
| LG-AN3-a | `apps/web/src/features/team/AcceptInvitePage.tsx:16` | medium | `/audit-requirements` | PR-AN-3 | report-with-fix |
| LG-AN3-b | `apps/web/src/features/onboarding/ConnectStoreStep.tsx:18` | medium | `/audit-requirements` | PR-AN-3 | report-with-fix |
| LG-AN4-a | `apps/web/src/features/stores/StoresPage.tsx:25` | medium | `/audit-requirements` | PR-AN-4 | report-with-fix |
| LG-AN4-b | `apps/web/src/features/billing/TrialBanner.tsx:14` | medium | `/audit-requirements` | PR-AN-4 | report-with-fix |
| LG-AN5-a | `apps/web/src/features/billing/UpgradePage.tsx:21` | critical | `/audit-requirements` | PR-AN-5 | report-with-fix |
| LG-AN5-b | `apps/web/src/features/auth/SignupPage.tsx:26` | medium | `/audit-requirements` | PR-AN-5 | report-with-fix |
| LG-AN6-a | `apps/web/src/features/billing/PlanCompareDialog.tsx:10` | medium | `/audit-requirements` | PR-AN-6 | report-flagged |
| LG-AN6-b | `apps/web/src/features/team/AcceptInvitePage.tsx:15` | medium | `/audit-requirements` | PR-AN-6 | report-with-fix |
| LG-AN7-a | `apps/web/src/shared/tracking/TrackingProvider.tsx:44` | medium | `/audit-requirements` | PR-AN-7 | report-with-fix |
| LG-AN7-b | `apps/web/src/features/settings/ThemeToggle.tsx:11` | low | `/audit-requirements` | PR-AN-7 | Hardening |
| LG-EN1-a | `marketing/pricing.json:15` | high | `/audit-requirements` | PR-EN-1 | report-flagged |
| LG-EN1-b | `marketing/pricing.json:20` | high | `/audit-requirements` | PR-EN-1 | report-flagged |
| LG-EN2-a | `apps/api/src/reports/reports.controller.ts:16` | critical | `/audit-requirements` | PR-EN-2 | report-with-fix |
| LG-EN2-b | `apps/api/src/gift-cards/gift-cards.service.ts:17` | medium | `/audit-requirements` | PR-EN-2 | report-with-fix |
| LG-EN3-a | `apps/api/src/usage/quota.service.ts:13` | medium | `/audit-requirements` | PR-EN-3 | report-flagged |
| LG-EN3-b | `apps/web/src/features/orders/AdvancedFilters.tsx:8` | medium | `/audit-requirements` | PR-EN-3 | report-flagged |
| LG-EN4-a | `packages/contracts/src/modules.ts:15` | high | `/audit-requirements` | PR-EN-4 | report-with-fix |
| LG-EN4-b | `packages/contracts/src/modules.ts:16` | high | `/audit-requirements` | PR-EN-4 | report-with-fix |
| LG-EN5-a | `apps/web/src/features/reports/ReportsPage.tsx:33` | medium | `/audit-requirements` | PR-EN-5 | report-with-fix |
| LG-EN5-b | `apps/web/src/features/loyalty/LoyaltyPage.tsx:15` | medium | `/audit-requirements` | PR-EN-5 | report-with-fix |
| LG-EN6-a | `apps/api/src/billing/billing.service.ts:9` | medium | `/audit-requirements` | PR-EN-6 | report-with-fix |
| LG-EN6-b | `apps/api/src/billing/entitlement-sync.service.ts:17` | high | `/audit-requirements` | PR-EN-6 | report-with-fix |
| LG-LR1-a | `ai/product/success/checkout-v2.md:21` | high | `/audit-requirements` | PR-LR-1 | report-with-fix |
| LG-LR1-b | `ai/product/success/referrals.md:23` | high | `/audit-requirements` | PR-LR-1 | report-with-fix |
| LG-LR4-a | `ai/product/success/checkout-v2.md:28` | medium | `/audit-requirements` | PR-LR-4 | report-with-fix |
| LG-LR4-b | `ai/product/success/referrals.md:28` | low | `/audit-requirements` | PR-LR-4 | Hardening |
| LG-LR5-a | `ai/product/success/checkout-v2.md:27` | medium | `/audit-requirements` | PR-LR-5 | report-with-fix |
| LG-LR5-b | `ai/product/success/referrals.md:26` | high | `/audit-requirements` | PR-LR-5 | report-with-fix |
| LG-LR6-a | `ai/product/assumptions.md:8` | medium | `/audit-requirements` | PR-LR-6 | report-with-fix |
| LG-LR6-b | `ai/product/assumptions.md:10` | low | `/audit-requirements` | PR-LR-6 | Hardening |
| LG-SC2-a | `ai/product/success/checkout-v2.md:18` | high | `/audit-requirements` | PR-SC-2 | report-with-fix |
| LG-SC2-b | `ai/product/success/referrals.md:18` | high | `/audit-requirements` | PR-SC-2 | report-with-fix |
| LG-TR1-a | `ai/specs/refunds.md:12` | medium | `/audit-requirements` | PR-TR-1 | report-with-fix |
| LG-TR1-b | `ai/specs/refunds.md:14` | medium | `/audit-requirements` | PR-TR-1 | report-with-fix |
| LG-TR2-a | `apps/api/test/refunds.e2e-spec.ts:37` | low | `/audit-requirements` | PR-TR-2 | report-with-fix |
| LG-TR2-b | `features/refund.feature:12` | low | `/audit-requirements` | PR-TR-2 | report-with-fix |
| LG-TR3-a | `features/refund.feature:16` | medium | `/audit-requirements` | PR-TR-3 | report-with-fix |
| LG-TR3-b | `features/step_definitions/refund.steps.js:21` | low | `/audit-requirements` | PR-TR-3 | report-with-fix |
| LG-TR4-a | `ai/runs/2026-10-12-refund-notify/requirements.md:8` | medium | `/audit-requirements` | PR-TR-4 | report-with-fix |
| LG-TR4-b | `ai/specs/refunds.md:13` | medium | `/audit-requirements` | PR-TR-4 | report-with-fix |
| LG-HO-SEC-a | `apps/web/src/features/team/TeamPage.tsx:23` | high | `/security-audit` | PR-AN-8 | routed |
| LG-HO-SEC-b | `apps/api/src/imports/imports.controller.ts:9` | high | `/security-audit` | PR-EN-7 | routed |
| LG-HO-DEV-a | `apps/web/src/config/flags.ts:6` | low | `/devops-audit` | DP §2 stale flag | routed |

Severity split: 3 critical · 21 high · 30 medium · 8 low. Critical is reserved for the three BLOCKER shapes `/audit-requirements` names (a fail-open gate fetch, a fail-open gate-key typo on a paid feature, a revenue conversion with a value sent before payment); low is Hardening or a scorecard FAIL above the feature's target level.

---

## LG-FS1-a — The permissions fetch calls a route nobody serves, and its catch grants every permission

```defect
id:       LG-FS1-a
file:     apps/web/src/entities/permissions/use-permissions.ts
line:     14
severity: critical
command:  /audit-requirements
class:    PR-FS-1
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §1
anchor:   return await http.get('auth/me/permissions')
match:    permission
match:    unserved|not served|no (served )?(route|handler|endpoint|controller)|404|nobody serves|does not exist|missing (route|endpoint)|fail.?open|ALL_PERMISSIONS
```

`AuthController` (`apps/api/src/auth/auth.controller.ts`) serves `GET auth/me` only; `GET /api/auth/me/permissions` 404s for every user. The hook's `catch` returns `ALL_PERMISSIONS`, so the sidebar's team link and every refund button render for a staff member: the real-repo incident shape (fail-open gate fetch). Critical-candidate per the skill's §1 severity, BLOCKER under `/audit-requirements`. Fix: serve the route from the session's grants and fail closed.

## LG-FS1-b — "Sync now" POSTs to a route served as PUT

```defect
id:       LG-FS1-b
file:     apps/web/src/features/stores/StoresPage.tsx
line:     19
severity: high
command:  /audit-requirements
class:    PR-FS-1
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §1
anchor:   http.post(`stores/${id}/sync`)
match:    sync
match:    method|PUT|POST|405|404|unserved|no (route|handler)|mismatch
```

`StoresController` declares `@Put(':id/sync')`; the page sends `POST stores/:id/sync`, which Fastify answers 404. The served `PUT` route is in turn uncalled (an FS2 row with the same root cause, one finding).

## LG-FS1-c — "Download invoice" fetches `/invoice`; the API renamed it to `/receipt`

```defect
id:       LG-FS1-c
file:     apps/web/src/features/orders/OrderDetail.tsx
line:     23
severity: high
command:  /audit-requirements
class:    PR-FS-1
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §1
anchor:   fetch(`/api/orders/${orderId}/invoice`
match:    invoice
match:    unserved|not served|no (served )?(route|handler|endpoint|controller)|404|nobody serves|does not exist|missing (route|endpoint)|receipt|renamed
```

A bare `fetch()` outside the `http` wrapper, so it also escapes any wrapper-based parity check. `OrdersController` serves `GET orders/:id/receipt` (its comment records the rename); `/invoice` 404s and the merchant downloads an error body as a PDF. The uncalled `/receipt` route is the other end.

## LG-FS2-a — API keys can be revoked by the API, but no screen calls it

```defect
id:       LG-FS2-a
file:     apps/api/src/api-keys/api-keys.controller.ts
line:     19
severity: medium
command:  /audit-requirements
class:    PR-FS-2
owner:    product
bucket:   report-flagged
detector: feature-surface-scan §2
anchor:   @Delete(':id')
match:    delete|revoke|api-?keys
match:    uncalled|no (caller|client|reference|UI)|unused|never called|nothing calls
```

Settings lists and creates keys; nothing calls `DELETE /api/api-keys/:id`, and `route-reasons.txt` does not list it. The project's reverse-route test reads only `@Get`/`@Post` decorators, so its control does not cover this route (§ The project's own control first, step 3). A writing route: medium. Stop and ask: build the revoke button or remove the route.

## LG-FS2-b — The route allow-list explains an uncalled route with no reason

```defect
id:       LG-FS2-b
file:     apps/web/src/shared/api/route-reasons.txt
line:     4
severity: low
command:  /audit-requirements
class:    PR-FS-2
owner:    product
bucket:   report-flagged
detector: feature-surface-scan §2
anchor:   GET  /api/reports/legacy-summary
match:    legacy-summary
match:    reason|allow.?list|explain|uncalled|unused|no caller
```

`GET /api/reports/legacy-summary` has no caller and its `route-reasons.txt` line carries no reason, so the control passes on an unexplained route. The skill reads the allow-list: an entry with no reason is a §2 row against the list itself. Read-only and authenticated, so low.

## LG-FS3-a — Primary navigation links to a page that was never built

```defect
id:       LG-FS3-a
file:     apps/web/src/layout/Sidebar.tsx
line:     21
severity: high
command:  /audit-requirements
class:    PR-FS-3
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §3
anchor:   <NavLink to="/reports/retention">
match:    retention
match:    no (page|route)|dead (link|end)|missing (page|route)|404|not.?found|does not exist|never built|broken
```

The router (`apps/web/src/app/router.tsx`) has `/reports` and no `/reports/retention`, and no served GET answers it; every merchant with the reports module sees the entry and lands on the not-found page. Primary navigation: high.

## LG-FS3-b — The orders search form submits to a page that does not exist

```defect
id:       LG-FS3-b
file:     apps/web/src/features/orders/OrdersPage.tsx
line:     26
severity: medium
command:  /audit-requirements
class:    PR-FS-3
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §3
anchor:   <Form action="/search">
match:    search
match:    no (page|route)|dead (link|end)|missing (page|route)|404|not.?found|does not exist|never built|broken|form
```

A React Router `<Form>` with no method is a GET navigation to `/search?q=…`; no page route or served GET matches it.

## LG-FS3-c — Onboarding's only call to action navigates to a page that does not exist

```defect
id:       LG-FS3-c
file:     apps/web/src/features/onboarding/WelcomePage.tsx
line:     12
severity: high
command:  /audit-requirements
class:    PR-FS-3
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §3
anchor:   navigate('/onboarding/connect-store')
match:    connect-store|onboarding
match:    no (page|route)|dead (link|end)|missing (page|route)|404|not.?found|does not exist|never built|broken|/onboarding/connect\b
```

The router serves `/onboarding/connect`; the welcome page's button navigates to `/onboarding/connect-store`. Every new signup hits the not-found page on step one. The primary action of the onboarding flow: high.

## LG-FS4-a — The dashboard ships a "coming soon" card, and the copy lives only in the catalog

```defect
id:       LG-FS4-a
file:     apps/web/src/i18n/locales/en.json
line:     21
severity: high
command:  /audit-requirements
class:    PR-FS-4
owner:    product
bucket:   report-flagged
detector: feature-surface-scan §4
anchor:   "forecast": "Demand forecast: coming soon",
match:    forecast|coming soon
match:    placeholder|coming soon|unfinished|dashboard
```

`DashboardPage` renders `<EmptyHint title={t('dashboard.forecast')} />` unconditionally on `/`, the first screen every merchant sees; the component names only the key, so a JSX grep misses it. Stop and ask: build, flag or remove.

## LG-FS4-b — "Export CSV" posts to a mounted route that answers 501

```defect
id:       LG-FS4-b
file:     apps/api/src/exports/exports.controller.ts
line:     10
severity: high
command:  /audit-requirements
class:    PR-FS-4
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §4
anchor:   throw new NotImplementedException(
match:    export|501|NotImplemented
match:    501|not.?implemented|placeholder|stub
```

`POST /api/exports` is mounted and `ReportsPage`'s first action calls it; the handler only throws `NotImplementedException`. Note `Report Exported` is planned and never fired (LG-AN2-b): the same unbuilt feature seen from the analytics side.

## LG-FS4-c — The dashboard hook returns three hard-coded products for every merchant

```defect
id:       LG-FS4-c
file:     apps/web/src/features/dashboard/use-top-products.ts
line:     11
severity: high
command:  /audit-requirements
class:    PR-FS-4
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §4
anchor:   return [
match:    top.?products|useTopProducts|hard.?coded|mock|literal|fake
match:    mock|hard.?coded|literal|fake|placeholder|static|no (fetch|query|API)
```

`useTopProducts()` returns literal records (SKU, units, revenue) with no query; the `TODO` above it names the endpoint that does not exist yet. Every merchant sees the same oat milk and sourdough on `/`.

## LG-FS4-d — The weekly insights endpoint returns the same three literal cards for every tenant

```defect
id:       LG-FS4-d
file:     apps/api/src/insights/insights.service.ts
line:     14
severity: high
command:  /audit-requirements
class:    PR-FS-4
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §4
anchor:   return [
match:    insight|weekly
match:    mock|hard.?coded|literal|fake|placeholder|static|no (query|database|repository)|tenantId
```

`InsightsService.weekly` voids `tenantId` and returns literals; `GET /api/insights/weekly` feeds the dashboard's "This week" card, so every merchant reads "Revenue is up 12.5%".

## LG-FS5-a — "Print packing slips" does nothing

```defect
id:       LG-FS5-a
file:     apps/web/src/features/orders/OrdersToolbar.tsx
line:     11
severity: medium
command:  /audit-requirements
class:    PR-FS-5
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §5
anchor:   onClick={() => {}}
match:    packing|onClick|no.?op|noop
match:    no.?op|nothing|does nothing|empty handler|dead|no effect
```

An empty arrow handler; the sibling "Print list" button prints the table, not packing slips, so no other control on the screen performs this action (the PP-FS-3 read fails).

## LG-FS5-b — "View all products" is an `href="#"` with no handler

```defect
id:       LG-FS5-b
file:     apps/web/src/features/dashboard/DashboardPage.tsx
line:     42
severity: medium
command:  /audit-requirements
class:    PR-FS-5
owner:    product
bucket:   report-with-fix
detector: feature-surface-scan §5
anchor:   <a href="#">
match:    href|view all|#
match:    dead|nothing|no.?op|hash|no (target|handler|effect)|placeholder
```

No `onClick`, no route: activating it scrolls to the top of the dashboard.

## LG-AN1-a — `Coupon Applied` fires but the tracking plan does not list it

```defect
id:       LG-AN1-a
file:     apps/web/src/features/billing/CouponField.tsx
line:     16
severity: medium
command:  /audit-requirements
class:    PR-AN-1
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §1
anchor:   trackEvent('Coupon Applied'
match:    Coupon Applied
match:    unplanned|not in the (tracking )?plan|missing from the plan|absent from the plan|plan (lacks|does not list)|does not list|not listed|undeclared|not planned|no such event
```

`ai/product/tracking-plan.yaml` (14 events) has no coupon event, so the plan's owner cannot see or chart it.

## LG-AN1-b — A server-side `Inventory Synced` event is missing from the plan

```defect
id:       LG-AN1-b
file:     apps/api/src/stores/stores.service.ts
line:     25
severity: medium
command:  /audit-requirements
class:    PR-AN-1
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §1
anchor:   event: 'Inventory Synced'
match:    Inventory Synced
match:    unplanned|not in the (tracking )?plan|missing from the plan|absent from the plan|plan (lacks|does not list)|does not list|not listed|undeclared|not planned|no such event
```

posthog-node object form in the API; the plan lists no such event. (The script also prints it as AN7 `bypasses-wrapper`; a server leg cannot use the React wrapper, so that row is read and dropped.)

## LG-AN2-a — The referrals launch metric's event is never fired

```defect
id:       LG-AN2-a
file:     ai/product/success/referrals.md
line:     12
severity: high
command:  /audit-requirements
class:    PR-AN-2
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §2
anchor:   - `Referral Sent`
match:    Referral Sent
match:    never fired|no call site|not (fired|tracked|instrumented|sent)|missing|no data|nothing fires|fires nothing|without the event
```

`metric_event: Referral Sent` in the success file and in the plan; `ReferralsService.send` queues the e-mail and fires nothing, and no web call site exists. The beta cannot be judged: the metric will read zero. Feeds PRR-AN-2.

## LG-AN2-b — `Report Exported` is planned and never fired

```defect
id:       LG-AN2-b
file:     ai/product/tracking-plan.yaml
line:     53
severity: medium
command:  /audit-requirements
class:    PR-AN-2
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §2
anchor:   Report Exported:
match:    Report Exported
match:    never fired|no call site|not (fired|tracked|instrumented|sent)|missing|no data|nothing fires|fires nothing|without the event
```

No call site in web or API (the export endpoint is a 501 stub, LG-FS4-b).

## LG-AN2-c — `Store Disconnected` is planned; removing a store fires nothing

```defect
id:       LG-AN2-c
file:     ai/product/tracking-plan.yaml
line:     15
severity: medium
command:  /audit-requirements
class:    PR-AN-2
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §2
anchor:   Store Disconnected:
match:    Store Disconnected
match:    never fired|no call site|not (fired|tracked|instrumented|sent)|missing|no data|nothing fires|fires nothing|without the event
```

`DeleteStoreDialog` and `StoresService.remove` delete the store without the event, so churned stores are invisible.

## LG-AN3-a — Invited signups are counted under `signup_completed`, split from `Signup Completed`

```defect
id:       LG-AN3-a
file:     apps/web/src/features/team/AcceptInvitePage.tsx
line:     16
severity: medium
command:  /audit-requirements
class:    PR-AN-3
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §3
anchor:   trackEvent('signup_completed'
match:    signup_completed
match:    Signup Completed|spelling|drift|cas(e|ing)|snake|two names|split|convention
```

Same trigger and properties as the plan's `Signup Completed` (fired in `SignupPage`), different spelling: the signup funnel loses every invited member. The script prints the cluster at its first spelling (`SignupPage.tsx`) and the convention row here.

## LG-AN3-b — Onboarding fires `StoreConnected`; the plan and the stores page use `Store Connected`

```defect
id:       LG-AN3-b
file:     apps/web/src/features/onboarding/ConnectStoreStep.tsx
line:     18
severity: medium
command:  /audit-requirements
class:    PR-AN-3
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §3
anchor:   trackEvent('StoreConnected'
match:    StoreConnected
match:    Store Connected|spelling|drift|cas(e|ing)|Pascal|two names|split|convention
```

One trigger, two names: onboarding connections never reach the plan's event. Not PP-AN-3 (no distinct trigger).

## LG-AN4-a — `count` is sent as the string "1" where the plan says integer

```defect
id:       LG-AN4-a
file:     apps/web/src/features/stores/StoresPage.tsx
line:     25
severity: medium
command:  /audit-requirements
class:    PR-AN-4
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §4
anchor:   trackEvent('Store Connected', { store_type: 'manual', count: '1' })
match:    count
match:    string|integer|type|'1'
```

The plan types `count: integer`; PostHog stores the property as a string for this site and a number for the onboarding site, so a sum over `count` breaks.

## LG-AN4-b — `Trial Extended` sends `day_count`; the plan requires `days`

```defect
id:       LG-AN4-b
file:     apps/web/src/features/billing/TrialBanner.tsx
line:     14
severity: medium
command:  /audit-requirements
class:    PR-AN-4
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §4
anchor:   trackEvent('Trial Extended'
match:    Trial Extended|day_count|days
match:    required|missing|day_count|property|key
```

The required key is missing and an unplanned key is sent instead.

## LG-AN5-a — `Plan Purchased`, with its value, fires when the checkout session is created, before anyone pays

```defect
id:       LG-AN5-a
file:     apps/web/src/features/billing/UpgradePage.tsx
line:     21
severity: critical
command:  /audit-requirements
class:    PR-AN-5
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §5
anchor:   trackEvent('Plan Purchased'
match:    Plan Purchased|purchase
match:    before (the )?(payment|outcome|confirm)|checkout (session|URL)|not (yet )?paid|intent|premature|early|webhook|redirect
```

`await createCheckout.mutateAsync(plan)` only creates the Stripe Checkout session; the event fires before the redirect to Stripe, with `value` and `currency`. The wrapper's server leg forwards it to the Meta Conversions API, so the ad platform is told about a purchase for every abandoned checkout, and checkout-v2's own metric (`metric_event: Plan Purchased`) counts starts as conversions. Revenue conversion with a value to an ad platform: BLOCKER under `/audit-requirements`. Fix: fire it from the payment-confirmed webhook.

## LG-AN5-b — `Signup Completed` fires on the button click, before the account exists

```defect
id:       LG-AN5-b
file:     apps/web/src/features/auth/SignupPage.tsx
line:     26
severity: medium
command:  /audit-requirements
class:    PR-AN-5
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §5
anchor:   trackEvent('Signup Completed', { method: 'email' })
match:    Signup Completed
match:    click|intent|before (the )?(server|response|account|outcome)|on.?click|fail|error|premature
```

The plan defines it as "the account exists"; the call sits in `onClick` before `signup.mutate()`, so a rejected e-mail or a 409 still counts as a signup.

## LG-AN6-a — The comparison impression re-fires whenever the parent re-renders

```defect
id:       LG-AN6-a
file:     apps/web/src/features/billing/PlanCompareDialog.tsx
line:     10
severity: medium
command:  /audit-requirements
class:    PR-AN-6
owner:    product
bucket:   report-flagged
detector: tracking-plan-scan §6
anchor:   trackEvent('Pricing Table Viewed'
match:    Pricing Table Viewed|onClose
match:    onClose|deps|dependenc|re.?render|twice|duplicate|unstable|more than once
```

Its effect lists `onClose`, and `UpgradePage` passes `onClose={() => setCompareOpen(false)}`, a new function every render; the plan says once per opening. Settling test: render open, re-render twice, expect 1 event.

## LG-AN6-b — `Invite Accepted` is sent by the browser and by the API with no shared event id

```defect
id:       LG-AN6-b
file:     apps/web/src/features/team/AcceptInvitePage.tsx
line:     15
severity: medium
command:  /audit-requirements
class:    PR-AN-6
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §6
anchor:   trackEvent('Invite Accepted'
match:    Invite Accepted
match:    two legs|server|both|duplicate|twice|event.?id|dedup|team\.service
```

`TeamService.acceptInvite` captures the same event with posthog-node; the browser leg carries the wrapper's `event_id`, the server leg none, so PostHog counts every acceptance twice.

## LG-AN7-a — The tracking wrapper takes any string as the event name

```defect
id:       LG-AN7-a
file:     apps/web/src/shared/tracking/TrackingProvider.tsx
line:     44
severity: medium
command:  /audit-requirements
class:    PR-AN-7
owner:    product
bucket:   report-with-fix
detector: tracking-plan-scan §7
anchor:   const trackEvent = useCallback((eventName: string
match:    trackEvent|wrapper|eventName
match:    string|untyped|typed|union|any name|typo
```

`eventName: string` admits every typo; the two §3 spellings (LG-AN3-a/b) and the §4 key drift would have failed `tsc` against a union generated from the plan, so the row is medium, not Hardening.

## LG-AN7-b — A component calls `posthog.capture` directly, around the wrapper

```defect
id:       LG-AN7-b
file:     apps/web/src/features/settings/ThemeToggle.tsx
line:     11
severity: low
command:  /audit-requirements
class:    PR-AN-7
owner:    product
bucket:   Hardening
detector: tracking-plan-scan §7
anchor:   posthog.capture('Theme Toggled'
match:    Theme Toggled|posthog
match:    bypass|direct|wrapper|trackEvent|outside
```

Skips the wrapper's event id and server leg. Hygiene: Hardening.

## LG-EN1-a — The pricing page promises Growth 10 seats; the seat gate allows 5

```defect
id:       LG-EN1-a
file:     marketing/pricing.json
line:     15
severity: high
command:  /audit-requirements
class:    PR-EN-1
owner:    product
bucket:   report-flagged
detector: entitlement-consistency-scan §1
anchor:   "features": ["3 stores", "Up to 10 seats"
match:    seat
match:    10|5|maxSeats|disagree|mismatch|differ
```

`config/billing.ts` `growth.maxSeats: 5` is what `TeamService.invite` enforces (403 `SEAT_LIMIT` on the sixth invite). A paid limit stated two ways: high. Stop and ask which number is the contract.

## LG-EN1-b — Scale is $129/mo on the pricing page and 149 in the billing config

```defect
id:       LG-EN1-b
file:     marketing/pricing.json
line:     20
severity: high
command:  /audit-requirements
class:    PR-EN-1
owner:    product
bucket:   report-flagged
detector: entitlement-consistency-scan §1
anchor:   "price": "$129/mo",
match:    129|149|price
match:    129|149|displayPrice|disagree|mismatch|differ
```

`BILLING_PLANS.scale.displayPrice: 149` is the value `UpgradePage` sends with `Plan Purchased`; the page and the conversion value disagree. (The Stripe price itself is outside the repo: NOT-RUN (auth).)

## LG-EN2-a — A hyphen typo makes the paid cohort report free for everyone

```defect
id:       LG-EN2-a
file:     apps/api/src/reports/reports.controller.ts
line:     16
severity: critical
command:  /audit-requirements
class:    PR-EN-2
owner:    product
bucket:   report-with-fix
detector: entitlement-consistency-scan §2
anchor:   @RequireModule('advanced-reports')
match:    advanced-reports|advanced_reports
match:    typo|not in (the |either )?catalog|unknown|fail.?open|both guards|neither guard|ungated|free
```

Neither catalog holds `advanced-reports` (`EXTENSION_SLUGS` has `advanced_reports`), and both global guards return `true` for a key outside their own family, so `GET /api/reports/cohorts` is served to every tenant. A fail-open typo on a paid feature: BLOCKER under `/audit-requirements`. Fix: the slug, and type `RequireModule`'s parameter as `ModuleKey | ExtensionSlug`.

## LG-EN2-b — A typo makes issuing gift cards fail for every paying tenant

```defect
id:       LG-EN2-b
file:     apps/api/src/gift-cards/gift-cards.service.ts
line:     17
severity: medium
command:  /audit-requirements
class:    PR-EN-2
owner:    product
bucket:   report-with-fix
detector: entitlement-consistency-scan §2
anchor:   hasFeature(tenantId, 'giftcards')
match:    giftcards|gift_cards
match:    typo|not in (the )?catalog|unknown|fail.?closed|always (false|refused|denied|403)|never
```

`hasFeature` returns false for any slug outside `EXTENSION_SLUGS`; `giftcards` is not `gift_cards`, so every issue request is refused, while the UI (`useModuleEnabled('gift_cards')`) shows the page to Growth and Scale. Fail-closed: medium.

## LG-EN3-a — The order quota exempts the plan named `scale` instead of an entitlement

```defect
id:       LG-EN3-a
file:     apps/api/src/usage/quota.service.ts
line:     13
severity: medium
command:  /audit-requirements
class:    PR-EN-3
owner:    product
bucket:   report-flagged
detector: entitlement-consistency-scan §3
anchor:   if (tenant.plan === 'scale') return true;
match:    scale|plan
match:    plan name|hard.?coded|literal|plan ===|entitlement
```

Outside the plan map (`packages/contracts/src/plans.ts`): the next unmetered plan (an annual Scale) is silently capped.

## LG-EN3-b — Channel filters are granted by `['growth', 'scale'].includes(currentPlan)` in a component

```defect
id:       LG-EN3-b
file:     apps/web/src/features/orders/AdvancedFilters.tsx
line:     8
severity: medium
command:  /audit-requirements
class:    PR-EN-3
owner:    product
bucket:   report-flagged
detector: entitlement-consistency-scan §3
anchor:   ['growth', 'scale'].includes(currentPlan)
match:    growth|scale|currentPlan
match:    plan name|hard.?coded|literal|includes|entitlement
```

No catalog key represents the feature; the plan map does not mention it.

## LG-EN4-a — The paid AI assistant extension is gated nowhere

```defect
id:       LG-EN4-a
file:     packages/contracts/src/modules.ts
line:     15
severity: high
command:  /audit-requirements
class:    PR-EN-4
owner:    product
bucket:   report-with-fix
detector: entitlement-consistency-scan §4
anchor:   'ai_assistant',
match:    ai_assistant|assistant
match:    no gate|ungated|not (gated|enforced)|gated nowhere|nothing (reads|gates)|every plan|any plan|any tenant|free|no `?@RequireModule|unenforced
```

Scale-only on the pricing page and in `PLAN_EXTENSIONS`; `POST /api/assistant/ask` carries no `@RequireModule` and the page no client gate, so every plan uses it. A paid add-on: high.

## LG-EN4-b — The paid API access extension is gated nowhere

```defect
id:       LG-EN4-b
file:     packages/contracts/src/modules.ts
line:     16
severity: high
command:  /audit-requirements
class:    PR-EN-4
owner:    product
bucket:   report-with-fix
detector: entitlement-consistency-scan §4
anchor:   'api_access',
match:    api_access|api-?keys|API access
match:    no gate|ungated|not (gated|enforced)|gated nowhere|nothing (reads|gates)|every plan|any plan|any tenant|free|no `?@RequireModule|unenforced
```

`ApiKeysController` lets any tenant create keys for the merchant API; nothing reads `api_access`.

## LG-EN5-a — "Email this report weekly" is shown to plans the server refuses

```defect
id:       LG-EN5-a
file:     apps/web/src/features/reports/ReportsPage.tsx
line:     33
severity: medium
command:  /audit-requirements
class:    PR-EN-5
owner:    product
bucket:   report-with-fix
detector: entitlement-consistency-scan §5
anchor:   onClick={() => schedule.mutate()}
match:    schedule|advanced_reports
match:    403|refuse|dead end|no (client |UI )?gate|shown|shows|upgrade|server
```

`POST /api/reports/schedules` requires `advanced_reports` (Scale); the button has no client gate, so a Growth tenant clicks it and gets a 403 with no upgrade path.

## LG-EN5-b — "Turn on loyalty points" is shown to Starter, which the server refuses

```defect
id:       LG-EN5-b
file:     apps/web/src/features/loyalty/LoyaltyPage.tsx
line:     15
severity: medium
command:  /audit-requirements
class:    PR-EN-5
owner:    product
bucket:   report-with-fix
detector: entitlement-consistency-scan §5
anchor:   onClick={() => enable.mutate()}
match:    loyalty
match:    403|refuse|dead end|no (client |UI )?gate|shown|shows|upgrade|server
```

`POST /api/loyalty/enable` requires `loyalty_points` (Growth and Scale); the sidebar link and the button are ungated, and the refusal renders as "could not be turned on".

## LG-EN6-a — Checkout uses hard-coded Stripe price ids instead of the lookup keys

```defect
id:       LG-EN6-a
file:     apps/api/src/billing/billing.service.ts
line:     9
severity: medium
command:  /audit-requirements
class:    PR-EN-6
owner:    product
bucket:   report-with-fix
detector: entitlement-consistency-scan §6
anchor:   starter: 'price_1PzK2sLmN4oQ8rT0uV3wX5yA',
match:    price_|price id|PRICE_IDS
match:    hard.?coded|literal|live|test.?mode|lookup.?key|mode
```

Three `price_…` literals in runtime source (one finding, three sites); a price id belongs to one Stripe mode, so checkout works in one of test and live. `config/billing.ts` already holds `lookupKey` per plan.

## LG-EN6-b — The entitlement sync reads one page of the summary and never revokes

```defect
id:       LG-EN6-b
file:     apps/api/src/billing/entitlement-sync.service.ts
line:     17
severity: high
command:  /audit-requirements
class:    PR-EN-6
owner:    product
bucket:   report-with-fix
detector: entitlement-consistency-scan §6
anchor:   const slugs = summary.entitlements.data.map
match:    entitlement|summary
match:    pag|has_more|10|revoke|remov|downgrade|cancel
```

The summary event carries at most 10 entitlements; the handler maps the first page only and calls `grantExtensions`, which upserts and never deactivates: a downgrade or cancellation keeps every extension. No revoke path: high. Live proof needs a test-mode key: NOT-RUN (auth).

## LG-LR1-a — Checkout v2's counter-metric is still the template placeholder

```defect
id:       LG-LR1-a
file:     ai/product/success/checkout-v2.md
line:     21
severity: high
command:  /audit-requirements
class:    PR-LR-1
owner:    product
bucket:   report-with-fix
detector: launch-readiness §2
anchor:   counter_metric: <counter-metric and its event>
match:    counter.?metric
match:    placeholder|template|<|missing|untyped|PRR-LR-1
```

A GA feature (target silver) whose counter-metric was never defined: PRR-LR-1 (bronze) fails.

## LG-LR1-b — The referrals baseline has no measurement window

```defect
id:       LG-LR1-b
file:     ai/product/success/referrals.md
line:     23
severity: high
command:  /audit-requirements
class:    PR-LR-1
owner:    product
bucket:   report-with-fix
detector: launch-readiness §2
anchor:   baseline: 0.4 referred signups
match:    baseline
match:    date|window|ISO|last quarter|PRR-LR-1|measure
```

"last quarter" is not a dated window; PRR-LR-1 (bronze, the beta's target) fails on the baseline.

## LG-LR4-a — The checkout v2 rollback is described, never exercised

```defect
id:       LG-LR4-a
file:     ai/product/success/checkout-v2.md
line:     28
severity: medium
command:  /audit-requirements
class:    PR-LR-4
owner:    product
bucket:   report-with-fix
detector: launch-readiness §4
anchor:   rollback_record: we can revert
match:    rollback
match:    no (date|time|result|record)|never (exercised|performed|tested)|described|PRR-RB-1|not a record|exercis
```

No environment, time or result: a plan, not a record. PRR-RB-1 is silver, the GA target: medium.

## LG-LR4-b — The referrals rollback record says the rollback failed

```defect
id:       LG-LR4-b
file:     ai/product/success/referrals.md
line:     28
severity: low
command:  /audit-requirements
class:    PR-LR-4
owner:    product
bucket:   Hardening
detector: launch-readiness §4
anchor:   rollback_record: staging 2026-10-10T09:00Z
match:    rollback
match:    fail|credit|PRR-RB-1|irreversib
```

Issued credits stayed on the accounts: the emission is irreversible and the record proves it. PRR-RB-1 is silver, above the beta's bronze target: Hardening, with the irreversibility named.

## LG-LR5-a — Checkout v2 has no pre-committed decision rule

```defect
id:       LG-LR5-a
file:     ai/product/success/checkout-v2.md
line:     27
severity: medium
command:  /audit-requirements
class:    PR-LR-5
owner:    product
bucket:   report-with-fix
detector: launch-readiness §5
anchor:   decision_rule: TBD
match:    decision.?rule
match:    TBD|placeholder|template|not (pre-)?committed|PRR-LR-5
```

"TBD once the first month of data is in" is a decision made after the result. PRR-LR-5, silver at the GA target.

## LG-LR5-b — The referrals review date has passed with no decision recorded

```defect
id:       LG-LR5-b
file:     ai/product/success/referrals.md
line:     26
severity: high
command:  /audit-requirements
class:    PR-LR-5
owner:    product
bucket:   report-with-fix
detector: launch-readiness §5
anchor:   review_date: 2026-09-30
match:    review.?date|2026-09-30
match:    past|not after|passed|expired|overdue|PRR-LR-5|PRR-LR-1
```

2026-09-30 is before the run date; the keep-or-remove rule was never applied. Fails PRR-LR-5 and, at bronze, PRR-LR-1: high.

## LG-LR6-a — A fatal, uncertain checkout assumption is still open past its expiry

```defect
id:       LG-LR6-a
file:     ai/product/assumptions.md
line:     8
severity: medium
command:  /audit-requirements
class:    PR-LR-6
owner:    product
bucket:   report-with-fix
detector: launch-readiness §6
anchor:   | 1 | Growth merchants upgrade
match:    assumption|Growth merchants|sales
match:    undecided|open|not (tested|accepted)|fatal|PRR-LR-6|expir
```

Fatal × high, expired 2026-10-01, decision `open`, feature checkout-v2 (GA). PRR-LR-6, silver at the GA target.

## LG-LR6-b — A fatal referrals assumption is "accepted" by nobody

```defect
id:       LG-LR6-b
file:     ai/product/assumptions.md
line:     10
severity: low
command:  /audit-requirements
class:    PR-LR-6
owner:    product
bucket:   Hardening
detector: launch-readiness §6
anchor:   | 3 | Referred shops activate
match:    assumption|Referred shops|activate
match:    TBD|placeholder|undecided|not (tested|accepted)|named|PRR-LR-6
```

`accepted: TBD` names no person, and the row expired 2026-09-15. Silver, above the beta's bronze target: Hardening.

## LG-SC2-a — Checkout v2's API path has no code owner

```defect
id:       LG-SC2-a
file:     ai/product/success/checkout-v2.md
line:     18
severity: high
command:  /audit-requirements
class:    PR-SC-2
owner:    product
bucket:   report-with-fix
detector: launch-readiness §1
anchor:   paths: apps/web/src/features/billing/**, apps/api/src/billing/**
match:    owner|CODEOWNERS|billing
match:    no (matching )?(rule|owner)|not covered|unowned|ownerless|PRR-OWN-1
```

`.github/CODEOWNERS` lists API modules one by one and omits `apps/api/src/billing/`; PRR-OWN-1 (bronze) fails at feature scope. At repo scope the rule passes (other rules name people), which is why the feature scope exists.

## LG-SC2-b — The referrals API path is owned by a bot

```defect
id:       LG-SC2-b
file:     ai/product/success/referrals.md
line:     18
severity: high
command:  /audit-requirements
class:    PR-SC-2
owner:    product
bucket:   report-with-fix
detector: launch-readiness §1
anchor:   paths: apps/web/src/features/referrals/**, apps/api/src/referrals/**
match:    referrals|bot
match:    bot|no (human )?owner|ownerless|PRR-OWN-1|not a person
```

The last matching rule for `apps/api/src/referrals/` (`.github/CODEOWNERS` line 9) names `@shelfwise-ci-bot` only; nobody reviews the beta's server half. PRR-OWN-1, bronze at the beta's target: high.

## LG-TR1-a — AC-003 (refunds take back loyalty points) is cited only in a helper comment

```defect
id:       LG-TR1-a
file:     ai/specs/refunds.md
line:     12
severity: medium
command:  /audit-requirements
class:    PR-TR-1
owner:    product
bucket:   report-with-fix
detector: acceptance-criteria-check §1
anchor:   - **AC-003**
match:    AC-0*3\b
match:    no test|untested|comment|not (cited|named|traced|tested)|TR-1
```

`apps/api/test/helpers/loyalty-points.ts:3` names it in a `//` comment; no test title, tag or name does. The join counts it cited; step 2b shows the citation is a comment (PP-TR-1).

## LG-TR1-b — AC-005 (a provider-rejected refund leaves the order unchanged) has no test

```defect
id:       LG-TR1-b
file:     ai/specs/refunds.md
line:     14
severity: medium
command:  /audit-requirements
class:    PR-TR-1
owner:    product
bucket:   report-with-fix
detector: acceptance-criteria-check §1
anchor:   - **AC-005**
match:    AC-0*5\b
match:    no test|untested|not (cited|named|traced|tested)|TR-1
```

The failure path of the refund flow; no test anywhere names it.

## LG-TR2-a — A test cites AC-009, which no spec defines

```defect
id:       LG-TR2-a
file:     apps/api/test/refunds.e2e-spec.ts
line:     37
severity: low
command:  /audit-requirements
class:    PR-TR-2
owner:    product
bucket:   report-with-fix
detector: acceptance-criteria-check §2
anchor:   it('AC-009
match:    AC-0*9\b
match:    stale|no spec|not defined|undefined|unknown|orphan|TR-2
```

The spec stops at AC-006; the over-refund rule it asserts lives nowhere.

## LG-TR2-b — A scenario is tagged @AC-014, which no spec defines

```defect
id:       LG-TR2-b
file:     features/refund.feature
line:     12
severity: low
command:  /audit-requirements
class:    PR-TR-2
owner:    product
bucket:   report-with-fix
detector: acceptance-criteria-check §2
anchor:   @AC-014
match:    AC-0*14\b
match:    stale|no spec|not defined|undefined|unknown|orphan|TR-2
```

Neither `ai/specs/refunds.md` nor the run ledger holds AC-014.

## LG-TR3-a — The step "the refunded line's stock is back on the shelf" has no definition, so its scenario cannot run

```defect
id:       LG-TR3-a
file:     features/refund.feature
line:     16
severity: medium
command:  /audit-requirements
class:    PR-TR-3
owner:    product
bucket:   report-with-fix
detector: acceptance-criteria-check §3
anchor:   Then the refunded line's stock is back on the shelf
match:    stock|refunded line
match:    undefined|no (step )?definition|unmatched|missing step|TR-3
```

`cucumber-js --dry-run` reports it undefined and still exits 0 (the skill parses the formatter output, never the exit code).

## LG-TR3-b — The step definition "a gold loyalty member" is used by no scenario

```defect
id:       LG-TR3-b
file:     features/step_definitions/refund.steps.js
line:     21
severity: low
command:  /audit-requirements
class:    PR-TR-3
owner:    product
bucket:   report-with-fix
detector: acceptance-criteria-check §3
anchor:   Given('a gold loyalty member'
match:    gold loyalty member
match:    unused|no scenario|dead|never used|TR-3|0 match
```

No feature file, under any tag, uses it (PP-TR-2 does not apply).

## LG-TR4-a — AC-011 bounds the merchant notification with "quickly"

```defect
id:       LG-TR4-a
file:     ai/runs/2026-10-12-refund-notify/requirements.md
line:     8
severity: medium
command:  /audit-requirements
class:    PR-TR-4
owner:    product
bucket:   report-with-fix
detector: acceptance-criteria-check §4
anchor:   - AC-011: WHEN a refund fails
match:    AC-0*11\b|quickly
match:    quickly|vague|unbounded|bound|EARS|ears-lint|not (falsifiable|measurable)
```

A run-ledger criterion; `ears-lint.py` flags the vague word in the SHALL clause (exit 2).

## LG-TR4-b — AC-004 says gift-card refunds "should work properly"

```defect
id:       LG-TR4-b
file:     ai/specs/refunds.md
line:     13
severity: medium
command:  /audit-requirements
class:    PR-TR-4
owner:    product
bucket:   report-with-fix
detector: acceptance-criteria-check §4
anchor:   - **AC-004** Refunds should work properly
match:    AC-0*4\b|properly
match:    properly|deferred standard|not (falsifiable|EARS|bounded|observable|testable)|vague|unverifiable
```

A deferred standard: no observation refutes it, and its test (`AC-004 a gift-card order can be refunded`) asserts a 201 only. The prose spec is outside the run-ledger format, so `ears-lint.py` reads 0 criteria there (PP-TR-4): the manual lane's row.

## LG-HO-SEC-a — The invitee's raw e-mail goes to PostHog and Meta as an event property

```defect
id:       LG-HO-SEC-a
file:     apps/web/src/features/team/TeamPage.tsx
line:     23
severity: high
command:  /security-audit
class:    PR-AN-8
owner:    security
bucket:   routed
detector: security data-exposure-scan (routed from tracking-plan-scan)
anchor:   trackEvent('Invite Sent', { role, invitee_email: email })
match:    invitee_email|e-?mail|PII
match:    PII|personal|e-?mail|third.?part|vendor|posthog|leak|raw|Meta
```

The wrapper sends `data` to PostHog and, through the server leg, unhashed in `custom_data` to the Meta Conversions API (only `email` at the top level is hashed). Security's class: `/audit-requirements` lists the property name and routes it.

## LG-HO-SEC-b — Bulk import is gated in the UI only

```defect
id:       LG-HO-SEC-b
file:     apps/api/src/imports/imports.controller.ts
line:     9
severity: high
command:  /security-audit
class:    PR-EN-7
owner:    security
bucket:   routed
detector: security @api-security-reviewer (routed from entitlement-consistency-scan)
anchor:   @Post()
match:    import|bulk_import
match:    client.?only|UI.?only|no server|not enforced|ungated|bypass|direct (API )?(call|request)
```

`useModuleEnabled('bulk_import')` hides the page; `POST /api/imports` has no `@RequireModule`, so any tenant can call it. Client-only entitlement: security's class.

## LG-HO-DEV-a — The checkout v2 release flag `ENABLE_NEW_CHECKOUT` is a constant `true`

```defect
id:       LG-HO-DEV-a
file:     apps/web/src/config/flags.ts
line:     6
severity: low
command:  /devops-audit
class:    DP §2 stale flag
owner:    devops
bucket:   routed
detector: devops progressive-delivery §2 (routed)
anchor:   export const ENABLE_NEW_CHECKOUT = true;
match:    ENABLE_NEW_CHECKOUT
match:    stale|constant|always (true|on)|remove|dead (branch|code)|permanent|literal
```

Checkout v2 is GA; the flag is a literal and `LegacyUpgrade` is a dead branch. Devops owns flag lifecycle.

## Decoys — must NOT be reported

Each mirrors a precedent from `templates/snippets/precedents/product.md` (the class line names it) or a measured real-repo shape; reporting one is a false positive in every run its `command:` names.

```decoy
id:       LG-DECOY-01
file:     apps/web/src/features/settings/DeleteStoreDialog.tsx
line:     26
command:  /audit-requirements
class:    decoy/PR-FS-5 (precedents/product.md § 3, PP-FS-3)
anchor:   <form onSubmit={() => undefined}>
match:    no.?op|nothing|dead|undefined|onSubmit
```

The footer's "Remove store" button performs the action; the no-op submit keeps Enter from deleting a store (commented in place).

```decoy
id:       LG-DECOY-02
file:     apps/web/src/shared/tracking/TrackingProvider.tsx
line:     22
command:  /audit-requirements
class:    decoy/PR-AN-2 (§ 11, PP-AN-2)
anchor:   window.fbq?.('trackCustom'
match:    pixel|fbq|signed.?in|not (sent|fired|tracked)|missing
```

The pixel is skipped for signed-in users by design; the server leg delivers the same event with the same id.

```decoy
id:       LG-DECOY-03
file:     apps/web/src/shared/tracking/TrackingProvider.tsx
line:     27
command:  /security-audit /audit-requirements
class:    decoy/PR-AN-8 (§ 13, PP-AN-4)
anchor:   email: user?.email
match:    e-?mail|PII|raw|personal
```

The raw e-mail goes to the own API only; `apps/api/src/events/capi.ts` hashes it (sha256 of the normalised value) before Meta.

```decoy
id:       LG-DECOY-04
file:     apps/api/src/inbox/inbox.controller.ts
line:     6
command:  /audit-requirements
class:    decoy/PR-EN-2 (§ 18, PP-EN-1)
anchor:   @RequireModule('whatsapp_inbox')
match:    whatsapp_inbox|not in (the )?catalog|MODULE_KEYS|unknown|fail.?open|ungated
```

Not in `MODULE_KEYS`, but `ExtensionModuleGuard` judges it: the split-guard precedent.

```decoy
id:       LG-DECOY-05
file:     apps/api/src/webhooks/webhooks.controller.ts
line:     14
command:  /audit-requirements
class:    decoy/PR-FS-2 (§ 1, PP-FS-1)
anchor:   @Post('stripe')
match:    webhook|stripe|uncalled|no caller|unused
```

Stripe calls it; no in-app caller by design.

```decoy
id:       LG-DECOY-06
file:     apps/api/src/public/public-catalog.controller.ts
line:     11
command:  /audit-requirements
class:    decoy/PR-FS-2 (§ 1, PP-FS-1)
anchor:   @Get('products')
match:    catalog|public|uncalled|no caller|unused
```

`@Public()`, versioned `v1`, documented in `docs/public-api.md`: merchants' storefronts call it.

```decoy
id:       LG-DECOY-07
file:     apps/api/src/health/health.controller.ts
line:     8
command:  /audit-requirements
class:    decoy/PR-FS-2 (§ 1, PP-FS-1)
anchor:   @Get('healthz')
match:    health|metrics|uncalled|no caller|unused
```

Load-balancer probe and Prometheus scrape, outside the `/api` prefix.

```decoy
id:       LG-DECOY-08
file:     apps/web/src/components/EmptyHint.tsx
line:     5
command:  /audit-requirements
class:    decoy/PR-FS-4 (§ 4, PP-FS-4)
anchor:   still behind a flag use the same card with "coming soon" copy
match:    coming soon|placeholder
```

A doc comment; the script's copy lane masks comments.

```decoy
id:       LG-DECOY-09
file:     apps/web/src/features/loyalty/LoyaltyTiersCard.tsx
line:     5
command:  /audit-requirements
class:    decoy/PR-FS-4 (§ 4, PP-FS-4)
anchor:   <p>Tiered rewards are coming soon.</p>
match:    coming soon|placeholder|tiers
```

Rendered only behind `flags.loyaltyTiers`, false in `.env.production` and `.env.staging` and unset elsewhere.

```decoy
id:       LG-DECOY-10
file:     apps/web/src/features/billing/UpgradeDialog.tsx
line:     10
command:  /audit-requirements
class:    decoy/PR-AN-6 (§ 15, PP-AN-6)
anchor:   if (open) trackEvent('Upgrade Dialog Shown'
match:    Upgrade Dialog Shown|twice|duplicate|more than once|re.?fire
```

Fires once per opening, as the plan says; `source` is a literal and the wrapper is stable through a ref.

```decoy
id:       LG-DECOY-11
file:     apps/api/src/database/seeds/demo-tenants.seeder.ts
line:     11
command:  /audit-requirements
class:    decoy/PR-EN-3 (§ 19, PP-EN-2)
anchor:   if (plan === 'scale') extensions.push('api_access');
match:    plan name|hard.?coded|scale|plan ===
```

A demo seed, not a feature check.

```decoy
id:       LG-DECOY-12
file:     apps/web/src/features/dashboard/TopProducts.stories.tsx
line:     7
command:  /audit-requirements
class:    decoy/PR-FS-4 (§ 4, PP-FS-4)
anchor:   const mockProducts = [
match:    mock|hard.?coded|fake|literal
```

A Storybook story; never shipped.

```decoy
id:       LG-DECOY-13
file:     apps/web/src/features/imports/ImportPage.tsx
line:     10
command:  /audit-requirements
class:    decoy/PR-FS-1 (§ 2, PP-FS-2)
anchor:   http.get('files/import-template/signed-url')
match:    files|signed-url|unserved|no (route|handler)|404
```

Served in production by `apps/web/nginx.conf` (`location /api/files/` to the files service); the Vite proxy covers dev.

```decoy
id:       LG-DECOY-14
file:     apps/web/src/features/billing/UpgradePage.tsx
line:     41
command:  /audit-requirements
class:    decoy/PR-AN-5 (§ 14, PP-AN-5)
anchor:   trackEvent('Checkout Started', { plan: p });
match:    Checkout Started|click|before|intent|premature
```

An intent event fired on intent.

```decoy
id:       LG-DECOY-15
file:     apps/web/src/features/orders/use-place-order.ts
line:     17
command:  /audit-requirements
class:    decoy/PR-AN-5 (§ 14)
anchor:   trackEvent('Order Placed'
match:    Order Placed|before|premature|early|intent
```

An outcome event fired in `onSuccess`, after the API stored the order: the outcome.

```decoy
id:       LG-DECOY-16
file:     apps/api/src/admin/admin-jobs.controller.ts
line:     11
command:  /audit-requirements
class:    decoy/PR-FS-2 (§ 7, PP-FS-7)
anchor:   @Post('reindex')
match:    reindex|admin|uncalled|no caller|unused
```

Explained in the project's own allow-list (`route-reasons.txt`: ops CLI, docs/ops.md), which its parity test reads.

## Detector measurement — the product pre-flights and scripts run on this fixture

Measured 2026-10-19 on a copy staged the way `run.sh` stages it (the tree minus this key), from the copy's root, with
every script from `templates/packs/product/skills/` under `python3 -I` and every pre-flight block run verbatim from its
`SKILL.md` (`entitlement-consistency-scan` with `CAT_FILES=(packages/contracts/src/modules.ts)`, the catalog its 0c
printed). Nothing was written into the copy. These are the detectors' raw rows, not an `/audit-requirements` result.

**Every product seed is printed by its owning lane: 59 of 59.** One needs a tool the staged copy lacks (LG-TR3-a/b:
cucumber-js, run from a scratch install), one a script from repo-baseline (LG-TR4-a: `ears-lint.py`), and one is the
manual lane by design (LG-TR4-b).

- **`surface-map.py . --reasons=apps/web/src/shared/api/route-reasons.txt`** (0.1 s, 116 files, exit 2): 42 served
  routes (Nest, `api` stripped), 20 page routes, 66 references (34 served, 4 unserved, 3 dead targets, 22
  pages); 1 CONTROL (the reverse-route test). FS1 4 rows (3 seeds + LG-DECOY-13, cleared by `nginx.conf`'s
  `location /api/files/`, which pre-flight 0d prints), FS2 9 (2 seeds; 5 decoy rows tagged webhook / health / metrics /
  public / `explained(ops CLI…)`; `PUT /stores/{}/sync` and `GET /orders/{}/receipt`, the other ends of LG-FS1-b and
  LG-FS1-c), FS3 3 (3 seeds), FS4 5 (4 seeds + LG-DECOY-09, cleared by the flag), FS5 3 (2 seeds + LG-DECOY-01,
  `near=handler:21`). The first version of the fixture had the search form post to `/orders/search`, which the script
  correctly matched to the `orders/:orderId` page by shape; the seed moved to `/search`.
- **`event-inventory.py .`** (0.1 s, exit 2): wrapper `trackEvent` discovered (`name: string`, event id), plan
  `ai/product/tracking-plan.yaml` (14 events), 4 success events, 16 sites, 0 unresolved. AN1 2, AN2 3 (one
  `metric=yes`), AN3 4 (two clusters, printed at each cluster's first spelling, plus two `convention` rows at the seed
  lines), AN4 4, AN5 4 (2 seeds + LG-DECOY-15 `on-success` + the `signup_completed` site, `after-await`, which is
  LG-AN3-a's), AN6 2, AN7 4. One false row: AN4 `required-missing Invite Accepted` at `team.service.ts:33`, because the
  object lane does not read posthog-node's `properties: { … }` key (the site's props print `-`). Two AN7
  `bypasses-wrapper` rows sit on server legs, which cannot use the React wrapper; the read drops them.
- **`entitlement-consistency-scan` pre-flight** (0.2 s, 0 exit-2): 0a `stripe`; 0b three `APP_GUARD`s (auth + the two
  entitlement guards); 0c `MODULE_KEYS`, `EXTENSION_SLUGS`, `PLAN_KEYS`, `BILLING_PLANS`; 1a/1b both ends of both
  LG-EN1 seeds (plus `ORDER_QUOTA`, a plan-keyed map no copy states); 2 server keys `advanced-reports advanced_reports
  giftcards inventory loyalty_points orders reports whatsapp_inbox`, client keys `bulk_import gift_cards inventory
  orders reports whatsapp_inbox`, client-only `bulk_import` (LG-HO-SEC-b) and `gift_cards` (the other end of
  LG-EN2-b's typo), server-only `advanced-reports giftcards` (§2 candidates) and `advanced_reports loyalty_points` (§5);
  3 both LG-EN3 seeds; 4 `ai_assistant 0`, `api_access 0`; 6a the three price-id lines; 6b the sync handler's
  `@OnEvent` line. LG-DECOY-04 (`whatsapp_inbox`) prints in both key lists and is cleared by the guard table.
- **`acceptance-criteria-check` pre-flight**: spec roots `ai/specs ai/runs ai/product`; 10 ids defined, 10 cited;
  TR-1 `AC-5` and `REQ-10`, TR-2 `AC-9` `AC-14`, 2b the comment-only `AC-003`. One false row: `REQ-10` is the run
  ledger's story heading (`### REQ-010`), not a criterion. Step 3 prints `§3 NOT-RUN (cucumber-js / behave not
  installed)`; step 4 cannot run in a staged copy without repo-baseline's `.claude/scripts/ears-lint.py`. Run outside
  the pre-flight: `ears-lint.py` on the run ledger exits 2 (`AC-011 — vague word in the SHALL clause: quickly`) and on
  the prose spec reads `0 stories, 0 criteria` (§ 34); cucumber-js 11.3.0 (installed in scratch with
  `--ignore-scripts`, telemetry off; 12.x refuses Node 23) `--dry-run --format usage-json` exits **0** with
  `1 undefined` step and `a gold loyalty member` at 0 matches.
- **`launch-readiness`** pre-flight steps 0–4 and **`readiness-score.py --today=2026-10-19`**: inputs found (2 success
  files, the ledger, `.github/CODEOWNERS`); step 3 prints the three `TBD` / `<…>` placeholders. `--feature=checkout-v2`
  (target silver, stage ga): NOT-READY, OWN-1, LR-1, RB-1, LR-5, LR-6 FAIL, every ledger rule UNVERIFIED (no evidence
  this run), PERF-1 FAIL (gold, above target). `--feature=referrals` (target bronze, stage beta): NOT-READY, OWN-1, LR-1,
  RB-1, LR-5, LR-6 FAIL. `--scope=repo`: OWN-1 PASS, LR-1 / RB-1 / LR-5 N/A (feature-scope rules), LR-6 FAIL on both
  rows, READY-UNVERIFIED (5). Exit 2 for all three.

Decoys: 9 of 16 are printed by a script or a pre-flight (01, 04, 05, 06, 07, 09, 13, 15, 16) and each is cleared by its
precedent at the read; the other 7 never print. Routed rows: LG-HO-SEC-a prints as a property name in
`event-inventory.py --inventory` (the product skill lists it, security grades it), LG-HO-SEC-b in the EN client-only
list; LG-HO-DEV-a was not measured (the owner's pre-flight).

| id | printed by |
|----|------------|
| LG-FS1-a | surface-map FS1 `GET /auth/me/permissions`, tags `gate-fetch` |
| LG-FS1-b | surface-map FS1 `POST /stores/{}/sync`, near `method-mismatch:PUT` |
| LG-FS1-c | surface-map FS1 `GET /orders/{}/invoice` (bare fetch lane) |
| LG-FS2-a | surface-map FS2 `DELETE /api-keys/{}`, tags `writes` |
| LG-FS2-b | surface-map FS2 `GET /reports/legacy-summary`, tags `explained(listed)` (with `--reasons=`) |
| LG-FS3-a | surface-map FS3 link `/reports/retention` |
| LG-FS3-b | surface-map FS3 link `/search` (GET form lane) |
| LG-FS3-c | surface-map FS3 redirect `/onboarding/connect-store` |
| LG-FS4-a | surface-map FS4 `catalog` `en.json:21` |
| LG-FS4-b | surface-map FS4 `not-implemented`, handler `POST /exports` |
| LG-FS4-c | surface-map FS4 `mock-rows` (3 literal objects, `todo-comment`) |
| LG-FS4-d | surface-map FS4 `mock-rows` (3 literal objects) |
| LG-FS5-a | surface-map FS5 `noop-handler`, near `handler:8` (the unrelated print-list sibling) |
| LG-FS5-b | surface-map FS5 `hash-href` |
| LG-AN1-a | event-inventory AN1 `unplanned` |
| LG-AN1-b | event-inventory AN1 `unplanned` (object lane) |
| LG-AN2-a | event-inventory AN2 `never-fired` `metric=yes` |
| LG-AN2-b | event-inventory AN2 `never-fired` |
| LG-AN2-c | event-inventory AN2 `never-fired` |
| LG-AN3-a | event-inventory AN3 `spelling` cluster + AN3 `convention` (snake_case) at this line |
| LG-AN3-b | event-inventory AN3 `spelling` cluster + AN3 `convention` (PascalCase) at this line |
| LG-AN4-a | event-inventory AN4 `type-mismatch` (`count: string, plan integer`) |
| LG-AN4-b | event-inventory AN4 `required-missing` (`days`) + `unplanned-property` (`day_count`) |
| LG-AN5-a | event-inventory AN5 `after-await(createCheckout.mutateAsync)`, `value` |
| LG-AN5-b | event-inventory AN5 `on-intent` |
| LG-AN6-a | event-inventory AN6 `effect-deps` (`deps=[open, onClose, trackEvent]`) |
| LG-AN6-b | event-inventory AN6 `two-legs` (`event_id=no`) |
| LG-AN7-a | event-inventory AN7 `untyped-wrapper` (13 call sites) |
| LG-AN7-b | event-inventory AN7 `bypasses-wrapper` (`sdk` lane) |
| LG-EN1-a | grep 1b `pricing.json:15` + grep 1a `billing.ts:9` |
| LG-EN1-b | grep 1b `pricing.json:20` + grep 1a `billing.ts:10` |
| LG-EN2-a | EN grep 2s server key `advanced-reports` (server-only list); 0c catalogs; 0b two `APP_GUARD`s |
| LG-EN2-b | EN grep 2s server key `giftcards`; client-only `gift_cards` in 2c |
| LG-EN3-a | EN grep 3 `quota.service.ts:13` |
| LG-EN3-b | EN grep 3 `AdvancedFilters.tsx:8` |
| LG-EN4-a | EN grep 4 loop `ai_assistant 0` |
| LG-EN4-b | EN grep 4 loop `api_access 0` |
| LG-EN5-a | EN grep 2 server-only `advanced_reports` |
| LG-EN5-b | EN grep 2 server-only `loyalty_points` |
| LG-EN6-a | EN grep 6a `billing.service.ts:9-11` |
| LG-EN6-b | EN grep 6b `entitlement-sync.service.ts:14` |
| LG-LR1-a | readiness-score `--feature=checkout-v2` PRR-LR-1 FAIL (template placeholder, line 21); pre-flight step 3 |
| LG-LR1-b | readiness-score `--feature=referrals` PRR-LR-1 FAIL (no ISO date, line 23) |
| LG-LR4-a | readiness-score PRR-RB-1 FAIL (no ISO date/time, line 28) |
| LG-LR4-b | readiness-score PRR-RB-1 FAIL (the recorded rollback failed, line 28) |
| LG-LR5-a | readiness-score PRR-LR-5 FAIL (template placeholder TBD, line 27); pre-flight step 3 |
| LG-LR5-b | readiness-score PRR-LR-5 and PRR-LR-1 FAIL (review_date not after 2026-10-19, line 26) |
| LG-LR6-a | readiness-score PRR-LR-6 FAIL `assumptions.md:8` (feature and repo scope) |
| LG-LR6-b | readiness-score PRR-LR-6 FAIL `assumptions.md:10`; pre-flight step 3 (TBD) |
| LG-SC2-a | readiness-score `--feature=checkout-v2` PRR-OWN-1 FAIL (not covered: apps/api/src/billing/**) |
| LG-SC2-b | readiness-score `--feature=referrals` PRR-OWN-1 FAIL (CODEOWNERS:9 names a bot only) |
| LG-TR1-a | acceptance pre-flight 2b (comment-only citation) |
| LG-TR1-b | acceptance pre-flight TR-1 `AC-5` |
| LG-TR2-a | acceptance pre-flight TR-2 `AC-9` |
| LG-TR2-b | acceptance pre-flight TR-2 `AC-14` |
| LG-TR3-a | cucumber-js 11.3.0 dry run: 1 undefined step, exit 0; pre-flight 3 prints NOT-RUN without node_modules |
| LG-TR3-b | cucumber-js usage-json: `a gold loyalty member` 0 matches |
| LG-TR4-a | `ears-lint.py` exit 2: `AC-011 — vague word in the SHALL clause: quickly` |
| LG-TR4-b | manual four tests (ears-lint reads `0 stories, 0 criteria` on this file) |
| LG-HO-SEC-a | event-inventory `--inventory` SITE props `invitee_email:expr` |
| LG-HO-SEC-b | EN grep 2 client-only `bulk_import` |
| LG-HO-DEV-a | not measured in this pass (the devops pre-flight is the owner's) |
