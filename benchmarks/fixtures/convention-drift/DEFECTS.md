# Seeded defects — `convention-drift`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans, and the key's `--only=` list leaves `fix-runs/` out of the staged copy too. If you stage the fixture by hand,
delete this file and `fix-runs/` from the copy first — an agent that reads either will score 100% and the number will mean
nothing.

Fixture shape: `Acme Orders` — a pnpm workspace whose conventions are declared in an ESLint 10 flat config, ls-lint, stylelint, dependency-cruiser, Ruff, import-linter, Spectral, ADRs, a glossary and a generated `refine-enriched` block with an Unsettled row; 39 align seeds across 16 align-owned classes, 15 seeds routed to their owner packs, 24 decoys, and 14 fix-runs for the sweep gate.

Invocation: /align-scan
Invocation[/frontend-audit]: /frontend-audit --whole-repo --classes=tokens,i18n,a11y
Invocation[/quality-audit]: /quality-audit --whole-repo
Invocation[/backend-audit]: /backend-audit --whole-repo
Stage with: --git --only=.dependency-cruiser-known-violations.json,.dependency-cruiser.cjs,.eslintrc.json,.github,.ls-lint.yml,.refract-fixture,ai,apps,docs,eslint-suppressions.json,eslint.config.mjs,package.json,packages,pnpm-lock.yaml,pnpm-workspace.yaml,services,stylelint.config.mjs,tsconfig.base.json

`--git` because the audits read history for age buckets and AL-30 bases; the staged copy has one commit, so every
history-dependent row is expected as `history-blind` (AL-02 recency, AL-04 age) and AL-30 reads its base from
`.refract-fixture/align-base/` (`BASE_DIR=.refract-fixture/align-base`, `convention-ratchet-scan` step 2). `--only=` stages
every top-level path except `fix-runs/`, which is the mechanical half's input and carries its own answer key (`*.expect`).

Eval source: Track A batch 6, items 25 and 27 (`eval-batch6-align.md` § 2 class map, § 4.12 fixture design, § 6 Wave D).
Classes are the eval's AL-01…AL-34; precedents are `templates/snippets/precedents/align.md` § n (= P-n); proofs are
`proof-oracles.md` § Align V389–V408. Roots:
- `apps/web` — React 19 + Vite + TanStack Router file routes, TanStack Query, a Redux cart being migrated to hooks;
- `apps/admin` — Vue 3.5 + Tailwind 4 with a closed `@theme` (`--color-*: initial`) and pinia;
- `apps/api` — NestJS 11 on Fastify 5 with ADR-0004 problem details and `.spectral.yaml`;
- `services/reports-py` — FastAPI with Ruff (`N`, `TID`, `banned-api`) and `.importlinter`;
- `packages/ui` (tokens in `tokens.css` + DTCG `tokens.json`; Button, Dialog, DataTable, IconButton, Can over Radix),
  `packages/http` (`apiClient` over ky), `packages/i18n` (`en`/`ar`), `packages/format` (`formatMoney`, `formatDate`,
  `formatRelative` over dayjs), `packages/legacy-reports` (frozen by ADR-0009 until 2027-03-31).

Departures from the eval, stated so a reader can audit them:
- **AL-30a is on `reviews-api.ts`, not `orders/api.ts`.** A suppression count on the file that also carries CD-AL11-a would
  make the ky import a baselined exception (P-03) and the seed contradict itself.
- **AL-13b (the diverged `useDebounce`) is routed** (`CD-HO-CQ-b`, code-quality), as the eval's own bucket says, and lives in
  `apps/web/src/features/search/` because the canonical hook is React; align keeps two AL-13 seeds (`formatMoney`, `formatDate`).
- **Five AL-11 seeds** (the eval lists four): the admin `ky` import shows the T2 oracle carrying a rule the package config
  switched off. **Three AL-16 seeds**: the admin `OrderList.vue` covers the Vue lane.
- **The AL-02c census is 36 `type` / 6 `interface`** (eval: 34 / 6), measured below.
- **`run-07` uses the rule scope `apps/web/src/featurez/*`** as the ledger row's `detector_scope`; the eval's "boundaries
  element pattern" is the same V-09 shape. Separately, the real config's `feature` element (`apps/web/src/features/*`) is
  measured below: `oracle-map.py` counts it as matching 63 files (the first engine counted 0; that defect is fixed).
- **The routed `#d92d20` / `8px` seeds are four sites, not two:** the sweep fix-runs need two files per AL-33 pair.
- **14 decoys from the eval plus 10**, among them the exact-versus-cross-family look-alikes (`width: 8px`, a `var()`
  fallback, the design system's own scrim) and the generated-rule (P-28) and generated-file (P-16) cases. Eval decoy 2
  (`Button.tsx` importing `@radix-ui/react-slot`) is `Dialog.tsx` importing `@radix-ui/react-dialog`, the twin of CD-AL11-b.

Ownership and scoring. Four runs, four results rows, each staged in its own copy. **`/align-scan`** scores the 39 align
rows. The 15 routed rows score **only under their owner** — `/frontend-audit` (11: ui-ux tokens and frontend i18n / a11y),
`/quality-audit` (2), `/backend-audit` (2) — and `/align-scan` must list each as a routed row with its owner line, never
grade it; an `/align-scan` finding on them is UNMATCHED, not credited. A decoy names every run it probes. `bucket:` is the
row's expected disposition: `report-with-fix` (align closes it with the named proof), `report-flagged` (a human, a visible
change, a contract or a wrapper gap decides), `AL-02 report` / `advisory` (0 ledger rows), `routed` (owner line only).

Secrets. None. The hosted-fields URL is `pay.example.com`; tokens are read from the environment.

Line numbers are exact against the files in this directory and are re-checked by `benchmarks/run.sh --verify`, which also
fails if a decoy sits within 12 lines of a defect in the same file.

## Summary

| id | file:line | severity | command | class | bucket |
|----|-----------|----------|---------|-------|--------|
| CD-AL02-a | `apps/web/src/features/reports/ReportsPage.tsx:11` | low | `/align-scan` | AL-02 | AL-02 report |
| CD-AL02-b | `ai/conventions.md:100` | low | `/align-scan` | AL-02 | AL-02 report |
| CD-AL02-c | `apps/web/src/features/OrderHistory/OrderHistoryPage.tsx:8` | low | `/align-scan` | AL-02 | AL-02 report |
| CD-AL03-a | `stylelint.config.mjs:10` | low | `/align-scan` | AL-03 | report-flagged |
| CD-AL03-b | `.github/workflows/ci.yml:19` | low | `/align-scan` | AL-03 | report-flagged |
| CD-AL04-a | `ai/conventions.md:32` | low | `/align-scan` | AL-04 | advisory |
| CD-AL04-b | `ai/conventions.md:86` | low | `/align-scan` | AL-04 | advisory |
| CD-AL11-a | `apps/web/src/features/orders/api.ts:1` | high | `/align-scan` | AL-11 | report-with-fix |
| CD-AL11-b | `apps/web/src/features/orders/components/CancelOrderDialog.tsx:1` | medium | `/align-scan` | AL-11 | report-with-fix |
| CD-AL11-c | `services/reports-py/app/export.py:4` | high | `/align-scan` | AL-11 | report-with-fix |
| CD-AL11-d | `apps/web/src/features/orders/components/OrderTimeline.tsx:12` | low | `/align-scan` | AL-11 | report-with-fix |
| CD-AL11-e | `apps/admin/src/api/orders.ts:1` | high | `/align-scan` | AL-11 | report-with-fix |
| CD-AL13-a | `apps/web/src/features/checkout/utils.ts:2` | medium | `/align-scan` | AL-13 | report-with-fix |
| CD-AL13-b | `apps/admin/src/utils/format-date.ts:1` | low | `/align-scan` | AL-13 | report-with-fix |
| CD-AL14-a | `apps/web/src/features/orders/components/OrderDrawer.tsx:2` | medium | `/align-scan` | AL-14 | report-with-fix |
| CD-AL14-b | `apps/web/src/features/payments/payments-api.ts:2` | medium | `/align-scan` | AL-14 | report-flagged |
| CD-AL15-a | `apps/web/src/features/audit-log/AuditLogPage.tsx:24` | medium | `/align-scan` | AL-15 | report-with-fix |
| CD-AL15-b | `apps/web/src/features/orders/components/OrderActions.tsx:29` | high | `/align-scan` | AL-15 | report-with-fix |
| CD-AL16-a | `apps/web/src/components/orders/orderRow.tsx:7` | low | `/align-scan` | AL-16 | report-with-fix |
| CD-AL16-b | `apps/web/src/features/OrderHistory/index.ts:1` | low | `/align-scan` | AL-16 | report-with-fix |
| CD-AL16-c | `apps/admin/src/components/OrderList.vue:8` | low | `/align-scan` | AL-16 | report-with-fix |
| CD-AL17-a | `apps/web/src/components/orders/OrderSummaryCard.tsx:8` | low | `/align-scan` | AL-17 | report-with-fix |
| CD-AL17-b | `services/reports-py/app/reports.py:14` | low | `/align-scan` | AL-17 | report-with-fix |
| CD-AL18-a | `apps/web/src/routes/clients/$clientId.tsx:5` | low | `/align-scan` | AL-18 | report-flagged |
| CD-AL18-b | `apps/api/src/orders/orders.events.ts:5` | low | `/align-scan` | AL-18 | report-flagged |
| CD-AL19-a | `apps/web/src/__tests__/OrdersList.test.tsx:5` | low | `/align-scan` | AL-19 | report-flagged |
| CD-AL19-b | `apps/web/src/features/refunds/RefundForm.tsx:12` | low | `/align-scan` | AL-19 | report-with-fix |
| CD-AL22-a | `apps/admin/src/utils/date-range.ts:1` | medium | `/align-scan` | AL-22 | report-flagged |
| CD-AL22-b | `apps/admin/src/utils/filter-state.ts:1` | medium | `/align-scan` | AL-22 | report-flagged |
| CD-AL29-a | `apps/web/src/features/search/search-api.ts:1` | medium | `/align-scan` | AL-29 | report-flagged |
| CD-AL29-b | `apps/web/src/features/checkout/Checkout.module.css:1` | low | `/align-scan` | AL-29 | report-flagged |
| CD-AL29-c | `apps/web/src/features/catalog/catalog-api.ts:2` | low | `/align-scan` | AL-29 | report-flagged |
| CD-AL30-a | `eslint-suppressions.json:4` | medium | `/align-scan` | AL-30 | report-flagged |
| CD-AL30-b | `.dependency-cruiser-known-violations.json:13` | medium | `/align-scan` | AL-30 | report-flagged |
| CD-AL31-a | `apps/admin/eslint.config.mjs:12` | medium | `/align-scan` | AL-31 | report-flagged |
| CD-AL31-b | `services/reports-py/pyproject.toml:12` | medium | `/align-scan` | AL-31 | report-flagged |
| CD-AL31-c | `.eslintrc.json:2` | low | `/align-scan` | AL-31 | report-with-fix |
| CD-AL32-a | `apps/web/src/features/orders/components/OrderBadge.tsx:6` | low | `/align-scan` | AL-32 | report-flagged |
| CD-AL32-b | `apps/web/src/features/cart/CartSummary.tsx:33` | low | `/align-scan` | AL-32 | report-flagged |
| CD-HO-UI-a | `apps/web/src/features/orders/components/OrderStatusBadge.tsx:13` | low | `/frontend-audit` | AL-05 | routed |
| CD-HO-UI-b | `apps/web/src/features/refunds/RefundForm.tsx:38` | low | `/frontend-audit` | AL-05 | routed |
| CD-HO-UI-c | `apps/web/src/features/orders/components/OrderCard.module.css:4` | low | `/frontend-audit` | AL-05 | routed |
| CD-HO-UI-d | `apps/web/src/features/cart/Cart.module.css:4` | low | `/frontend-audit` | AL-05 | routed |
| CD-HO-UI-e | `apps/web/src/features/orders/components/OrderTotals.tsx:8` | low | `/frontend-audit` | AL-06 | routed |
| CD-HO-UI-f | `apps/web/src/features/checkout/Checkout.module.css:11` | low | `/frontend-audit` | AL-06 | routed |
| CD-HO-UI-g | `apps/admin/src/components/order-filters.vue:16` | low | `/frontend-audit` | AL-07 | routed |
| CD-HO-UI-h | `apps/web/src/features/checkout/CheckoutPage.tsx:25` | low | `/frontend-audit` | AL-12 | routed |
| CD-HO-CQ-a | `apps/web/src/features/orders/components/OrderNotes.tsx:2` | medium | `/quality-audit` | AL-20 | routed |
| CD-HO-CQ-b | `apps/web/src/features/search/useDebounce.ts:4` | medium | `/quality-audit` | AL-13 | routed |
| CD-HO-BE-a | `apps/api/src/orders/orders.controller.ts:26` | medium | `/backend-audit` | AL-23 | routed |
| CD-HO-BE-b | `apps/api/src/customers/customers.controller.ts:9` | low | `/backend-audit` | AL-25 | routed |
| CD-HO-FE-a | `apps/web/src/features/settings/SettingsForm.tsx:38` | low | `/frontend-audit` | AL-26 | routed |
| CD-HO-FE-b | `apps/web/src/features/orders/components/OrderActions.tsx:33` | low | `/frontend-audit` | AL-26 | routed |
| CD-HO-FE-c | `apps/web/src/features/cart/CartItemRow.tsx:25` | medium | `/frontend-audit` | AL-28 | routed |

Severity split: 0 critical · 4 high · 16 medium · 34 low. No align row is critical; High is reserved for a permission, tenant or auth wrapper bypass.

---

## CD-AL02-a — Error toasts split 6 `toast.error()` / 5 `notify({ kind: 'error' })`, and no rule names a winner

```defect
id:       CD-AL02-a
file:     apps/web/src/features/reports/ReportsPage.tsx
line:     11
severity: low
command:  /align-scan
class:    AL-02
owner:    align
bucket:   AL-02 report — `undetermined — ask` (11 sites, below the 30-site floor); 0 ledger rows
detector: convention-oracle §2
anchor:   if (error) notify({ kind: 'error', message: t('reports.loadFailed') });
match:    toast|notify|split|bimodal|undetermined|no (declared|written)|two (ways|shapes)|ask
```

Six components call sonner's `toast.error()` directly and five call the design system's `notify({ kind: 'error' })`. Neither `ai/conventions.md` nor any config names one, so this is a split with no declared winner (P-01): the report prints the counts and asks. The floor test fails on size alone (n = 11 < 30), so not even a `proposed canonical` line is printed. A run that files either side as drift has enforced a majority nobody wrote.

## CD-AL02-b — Hook file naming is contested; the generated block's camelCase line does not settle it

```defect
id:       CD-AL02-b
file:     ai/conventions.md
line:     100
severity: low
command:  /align-scan
class:    AL-02
owner:    align
bucket:   AL-02 report — `contested — ask` (Unsettled row); the three kebab hook files are not AL-16 rows
detector: convention-oracle §2
anchor:   | Hook file names |
match:    hook|contested|unsettled|camel|kebab|use-cart-total|use-
```

The `## Unsettled conventions` table lists hook file names as undecided (camelCase 14, kebab-case 3), while the `refine-enriched` block says "Hook files are camelCase" (`ai/conventions.md:93`). A contested category is AL-02 even when a document elsewhere names a side (P-29); `oracle-map.py` re-tags the generated line `contested`. Both shapes also pass `.ls-lint.yml` (`camelCase | kebab-case`). Expected: one AL-02 line; `use-cart-total.ts`, `use-search-params.ts` and `use-order-filters.ts` are not renamed.

## CD-AL02-c — Props declared with `type` 36 times and `interface` 6 times; nothing declares either

```defect
id:       CD-AL02-c
file:     apps/web/src/features/OrderHistory/OrderHistoryPage.tsx
line:     8
severity: low
command:  /align-scan
class:    AL-02
owner:    align
bucket:   AL-02 report — `proposed canonical: type (36/42 = 0.86; history-blind, whole tree) — ratify?`; 0 ledger rows
detector: convention-oracle §2
anchor:   interface OrderHistoryPageProps {
match:    interface|type alias|Props|proposed canonical|ratify|majority|split
```

42 `*Props` declarations: 36 `type XProps =`, 6 `interface XProps`. The share (0.86) and the size (42 ≥ 30) clear the evidence floor, so the proposal channel prints `proposed canonical: type … — ratify?`. It is still 0 ledger rows: a majority is never a Finding (P-01). The single-commit copy is history-blind, so the newest-files test is replaced by whole-tree counts and the line says so. The six interface files are not rewritten.

## CD-AL03-a — The token rule the doc says "never" is configured at `warning`

```defect
id:       CD-AL03-a
file:     stylelint.config.mjs
line:     10
severity: low
command:  /align-scan
class:    AL-03
owner:    align
bucket:   report-flagged — T1-warn against a T2 "never"; enablement is a ratchet (V-04)
detector: convention-oracle §3
anchor:   severity: 'warning',
match:    warn|warning|not enforced|unenforced|declaration-strict-value|stylelint|severity
```

`ai/conventions.md:66` says "Never hardcode a colour, spacing or font-size value in app CSS", and the only rule that checks it, `scale-unlimited/declaration-strict-value`, reports at `warning` (`oracle-map.py`: tier T1-warn). Run at error from a scratch config it has debt: the two `8px` paddings, `#1a73e9` and the file-wide disable in `Checkout.module.css`. Closure is the ratchet (rule at error + a baseline), not N site fixes.

## CD-AL03-b — CI lints `apps/web` only: the shared rules are partial and six tools never run

```defect
id:       CD-AL03-b
file:     .github/workflows/ci.yml
line:     19
severity: low
command:  /align-scan
class:    AL-03
owner:    align
bucket:   report-flagged — `pnpm lint` = `eslint apps/web`; ESLint rules `ci=partial`, depcruise / ls-lint / stylelint / Ruff / import-linter / Spectral `T1-noci`
detector: convention-oracle §3
anchor:         - run: pnpm lint
match:    \bCI\b|workflow|apps/web|not linted|never (run|lint)|unenforced|noci|partial
```

The workflow runs `pnpm lint`, which `package.json` resolves to `eslint apps/web`. The shared flat config scopes `no-restricted-imports`, `boundaries/dependencies` and the naming rules to `apps/**` and `packages/**`, so CI enforces them on part of their scope (`ci=partial`). `.dependency-cruiser.cjs`, `.ls-lint.yml`, `stylelint.config.mjs`, Ruff, `.importlinter` and `.spectral.yaml` never run in CI (`T1-noci`). The workflow lives in a dot-directory: a search without `--hidden` never sees it. That `admin` and `reports-py` drift (CD-AL11-c, -e) has accumulated is the symptom.

## CD-AL04-a — The doc says store files end in `.store.ts`; every store file ends in `-store.ts`

```defect
id:       CD-AL04-a
file:     ai/conventions.md
line:     32
severity: low
command:  /align-scan
class:    AL-04
owner:    align
bucket:   advisory — `AL-04 candidate (history-blind)`: doc update, the six files are not renamed
detector: convention-oracle §4
anchor:   - Pinia store files end in `.store.ts`
match:    store|\.store\.ts|-store|stale|outdated|doc(ument)?.{0,20}(update|wrong|contradict)
```

All five pinia stores (`apps/admin/src/stores/*-store.ts`) and the web cart store use `-store.ts`; none uses `.store.ts`. 100% of the sites follow the other shape (P-18); without history the age half of the test cannot run, so the row is a history-blind candidate. Six AL-16 rename rows here are a false positive by construction.

## CD-AL04-b — The doc says `/api/v1`; the API, ADR-0004 and every client use `/api/v2`

```defect
id:       CD-AL04-b
file:     ai/conventions.md
line:     86
severity: low
command:  /align-scan
class:    AL-04
owner:    align
bucket:   advisory — doc update (the code and the ADR agree with each other, not with the line)
detector: convention-oracle §4
anchor:   - All endpoints live under `/api/v1`.
match:    /api/v1|v2|stale|prefix|outdated|doc(ument)?.{0,20}(update|wrong|contradict)
```

`apps/api/src/main.ts` sets `app.setGlobalPrefix('api/v2')`, ADR-0004 says "Endpoints are served under `/api/v2`", and `@acme/http`, the admin client and `reports-py` all call `/api/v2`. The conventions line is the stale party; a fix that moves routes to `/v1` is a breaking change, not alignment.

## CD-AL11-a — Orders API module builds its own `ky` client

```defect
id:       CD-AL11-a
file:     apps/web/src/features/orders/api.ts
line:     1
severity: high
command:  /align-scan
class:    AL-11
owner:    align
bucket:   report-with-fix — `replace-with-shared` → `apiClient`; FN (the wrapper adds auth and retries): V400 + a behaviour test
detector: wrapper-adoption-scan §1
anchor:   import ky from 'ky';
match:    \bky\b|apiClient|@acme/http|wrapper|raw (http|client)|no-restricted-imports|bypass
```

`no-restricted-imports` bans `ky` at error ("Use @acme/http (apiClient)") and `ai/conventions.md:9` says the same. `ky.create({ prefixUrl })` here drops the bearer-token hook and the retry policy that `apiClient` carries, so every order list and detail call goes out unauthenticated: an auth-wrapper bypass, hence High. The correct sibling is `features/customers/api.ts`.

## CD-AL11-b — Radix Dialog root imported directly, under an alias

```defect
id:       CD-AL11-b
file:     apps/web/src/features/orders/components/CancelOrderDialog.tsx
line:     1
severity: medium
command:  /align-scan
class:    AL-11
owner:    align
bucket:   report-with-fix — EQ: `@acme/ui` `Dialog` is `RadixDialog.Root` re-exported unchanged (V400)
detector: wrapper-adoption-scan §1
anchor:   import { Root as DialogRoot } from '@radix-ui/react-dialog';
match:    radix|@radix-ui|Dialog|wrapper|@acme/ui|alias
```

The `@radix-ui/*` pattern ban and `ai/conventions.md:11`. The alias (`Root as DialogRoot`) hides the module from a grep on the JSX name. `packages/ui/src/dialog/Dialog.tsx` exports `Dialog = RadixDialog.Root`, so the swap reproduces every prop: EQ. The file already imports `DialogContent` and `DialogTitle` from `@acme/ui`.

## CD-AL11-c — Reports export calls `requests` instead of `app.http_client`

```defect
id:       CD-AL11-c
file:     services/reports-py/app/export.py
line:     4
severity: high
command:  /align-scan
class:    AL-11
owner:    align
bucket:   report-with-fix — FN: `get_json()` adds the timeout, auth header and retries (V400 + a behaviour test)
detector: wrapper-adoption-scan §1
anchor:   import requests
match:    requests|http_client|TID251|banned|wrapper|get_json
```

Ruff `banned-api` names `requests` ("Use app.http_client") and `ai/conventions.md:18` says it is banned. The call sends no `authorization` header, so the export reads orders unauthenticated. Ruff would not have caught it: `extend-ignore = ["TID251"]` (CD-AL31-b) and CI never runs Ruff (CD-AL03-b).

## CD-AL11-d — `dayjs` reached through a dynamic `import()`

```defect
id:       CD-AL11-d
file:     apps/web/src/features/orders/components/OrderTimeline.tsx
line:     12
severity: low
command:  /align-scan
class:    AL-11
owner:    align
bucket:   report-with-fix — `formatRelative` from `@acme/format` (V400)
detector: wrapper-adoption-scan §1
anchor:   const { default: dayjs } = await import('dayjs');
match:    dayjs|import\(|dynamic import|formatRelative|@acme/format|wrapper
```

`ai/conventions.md:12`: feature code never imports `dayjs`. A search for static `import … from` lines misses the `await import('dayjs')` form (research § 5.1 lists every import form). `@acme/format` already exports `formatRelative()` with the same plugin.

## CD-AL11-e — Admin API module imports `ky` (the admin config switched the ban off)

```defect
id:       CD-AL11-e
file:     apps/admin/src/api/orders.ts
line:     1
severity: high
command:  /align-scan
class:    AL-11
owner:    align
bucket:   report-with-fix — oracle T2 (the doc); the T1 rule is `off` here (CD-AL31-a); FN like CD-AL11-a
detector: wrapper-adoption-scan §1
anchor:   import ky from 'ky';
match:    \bky\b|apiClient|@acme/http|wrapper|admin|bypass
```

Same convention as CD-AL11-a. ESLint does not flag it because `apps/admin/eslint.config.mjs` sets `no-restricted-imports: 'off'`, so the oracle is the written rule, not the config. `@acme/http` is already in admin's `package.json`.

## CD-AL13-a — `formatMoney` copied into checkout, byte-identical to `@acme/format`

```defect
id:       CD-AL13-a
file:     apps/web/src/features/checkout/utils.ts
line:     2
severity: medium
command:  /align-scan
class:    AL-13
owner:    align
bucket:   report-with-fix — `dedupe` after a differential test, copy vs canonical (V403)
detector: wrapper-adoption-scan §2
anchor:   export function formatMoney(minor: number, currency = 'EUR', locale = 'en'): string {
match:    formatMoney|duplicat|copy|copied|@acme/format|dedupe|hand.?rolled
```

`ai/conventions.md:14` names `formatMoney` as a shared helper that is imported, never copied. The body is identical to `packages/format/src/index.ts`, so the differential test on the copy's call-site inputs passes and the copy is deleted.

## CD-AL13-b — `formatDate` copied into the admin app

```defect
id:       CD-AL13-b
file:     apps/admin/src/utils/format-date.ts
line:     1
severity: low
command:  /align-scan
class:    AL-13
owner:    align
bucket:   report-with-fix — `dedupe` (V403); `order-table.vue` imports the copy
detector: wrapper-adoption-scan §2
anchor:   export function formatDate(iso: string, locale = 'en'): string {
match:    formatDate|duplicat|copy|copied|@acme/format|dedupe
```

Same rule as CD-AL13-a; `@acme/format` is already an admin dependency.

## CD-AL14-a — Focus trap imported from `@acme/ui/src/internal/`

```defect
id:       CD-AL14-a
file:     apps/web/src/features/orders/components/OrderDrawer.tsx
line:     2
severity: medium
command:  /align-scan
class:    AL-14
owner:    align
bucket:   report-with-fix — EQ: `@acme/ui` re-exports `createFocusTrap` from its entry (V404)
detector: wrapper-adoption-scan §3
anchor:   import { createFocusTrap } from '@acme/ui/src/internal/focus-trap';
match:    internal|deep import|entry point|exports|@acme/ui/src|focus-trap
```

`packages/ui/package.json` exports `.`, `./tokens.css` and `./hooks`; `./src/internal/*` is not a public subpath, and the `@acme/*/src/*` pattern ban plus `ai/conventions.md:16` forbid it. `packages/ui/src/index.ts` exports the same function.

## CD-AL14-b — Retry backoff reached by a relative path into `packages/http/src/`

```defect
id:       CD-AL14-b
file:     apps/web/src/features/payments/payments-api.ts
line:     2
severity: medium
command:  /align-scan
class:    AL-14
owner:    align
bucket:   report-flagged — `@acme/http` does not export `backoffMs`: add it to the entry, or drop the hand-rolled loop
detector: wrapper-adoption-scan §3
anchor:   import { backoffMs } from '../../../../../packages/http/src/retry';
match:    packages/http|relative|deep import|entry point|backoff|retry
```

Five `../` reach the sibling package's source. No public export carries `backoffMs`, so there is no mechanical re-route; and `apiClient` already retries idempotent GETs, which makes the manual loop redundant. A human picks.

## CD-AL15-a — Read-only audit log renders `<DataTable>` with the delete affordance on

```defect
id:       CD-AL15-a
file:     apps/web/src/features/audit-log/AuditLogPage.tsx
line:     24
severity: medium
command:  /align-scan
class:    AL-15
owner:    align
bucket:   report-with-fix — add `canDelete={false}` (V401: render test, no delete control)
detector: wrapper-adoption-scan §4
anchor:   <DataTable rows={data ?? []} columns={columns} />
match:    canDelete|DataTable|read.?only|delete (button|control|affordance)|default
```

`ai/conventions.md:38`: `canDelete` defaults to `true` and a read-only page passes `false`. The file's own comment says audit entries are immutable; every row renders a delete icon.

## CD-AL15-b — Delete-order button rendered outside `<Can>`

```defect
id:       CD-AL15-b
file:     apps/web/src/features/orders/components/OrderActions.tsx
line:     29
severity: high
command:  /align-scan
class:    AL-15
owner:    align
bucket:   report-with-fix — FN: `add-gate` with `<Can action="orders.delete">` (V401: render test as a role without it)
detector: wrapper-adoption-scan §4
anchor:   <Button variant="danger" onClick={deleteOrder}>
match:    \bCan\b|permission|gate|ungated|destructive|orders\.delete|authori
```

`ai/conventions.md:39`. The cancel button four lines above is gated; delete is not, so every signed-in user sees it. A permission gate bypass is the one AL-15 shape that is High.

## CD-AL16-a — Component file `orderRow.tsx` exports `OrderRow`

```defect
id:       CD-AL16-a
file:     apps/web/src/components/orders/orderRow.tsx
line:     7
severity: low
command:  /align-scan
class:    AL-16
owner:    align
bucket:   report-with-fix — `rename` (git mv to `OrderRow.tsx`; V402)
detector: naming-layout-scan §1
anchor:   export function OrderRow({ reference, totalMinor, currency, onOpen }: OrderRowProps) {
match:    orderRow|PascalCase|file ?name|rename|naming|case
```

`check-file/filename-naming-convention` (`apps/web/src/**/*.tsx: PASCAL_CASE`), `.ls-lint.yml` (`.tsx: PascalCase`) and `ai/conventions.md:47`. Nothing imports it yet, so the rename touches one path.

## CD-AL16-b — Feature directory `OrderHistory/` where kebab-case is declared

```defect
id:       CD-AL16-b
file:     apps/web/src/features/OrderHistory/index.ts
line:     1
severity: low
command:  /align-scan
class:    AL-16
owner:    align
bucket:   report-with-fix — `rename` the directory to `order-history/` (V402); `ai/modules.md` already lists that path
detector: naming-layout-scan §1
anchor:   export { OrderHistoryPage } from './OrderHistoryPage';
match:    OrderHistory|order-history|kebab|directory|folder|rename|naming
```

`.ls-lint.yml` (`.dir: kebab-case`) and `ai/conventions.md:49`; `ai/modules.md` declares `order-history/`, so the skeleton check (§4) reports the declared path missing as well: one root cause.

## CD-AL16-c — Admin SFC `OrderList.vue` where `.vue: kebab-case` is declared

```defect
id:       CD-AL16-c
file:     apps/admin/src/components/OrderList.vue
line:     8
severity: low
command:  /align-scan
class:    AL-16
owner:    align
bucket:   report-with-fix — `rename` to `order-list.vue` (V402; `App.vue` imports it)
detector: naming-layout-scan §1
anchor:   const orders = useOrdersStore();
match:    OrderList|kebab|file ?name|rename|\.vue|naming
```

`.ls-lint.yml` declares `apps/admin/src: .vue: kebab-case`; its siblings are `order-filters.vue` and `order-table.vue`. `App.vue` is the framework root and stays (CD-DECOY-06).

## CD-AL17-a — Boolean prop `loading` where `is*` is declared (typed lane NOT RUN on TypeScript 7)

```defect
id:       CD-AL17-a
file:     apps/web/src/components/orders/OrderSummaryCard.tsx
line:     8
severity: low
command:  /align-scan
class:    AL-17
owner:    align
bucket:   report-with-fix — `rename` to `isLoading` (internal props; V402)
detector: naming-layout-scan §2
anchor:     loading: boolean;
match:    loading|isLoading|boolean|prefix|naming-convention|\bis[A-Z]|rename
```

`@typescript-eslint/naming-convention` (`types: ['boolean']`, prefix `is|has|should|can`) and `ai/conventions.md:52`. The rule needs type information; the lockfile pins `typescript` 7.0.0 with no `@typescript/typescript6` alias, so the typed lane is `NOT RUN` (the `ts7-no-api` gate) and the grep fallback over `*Props` members finds the one unprefixed boolean.

## CD-AL17-b — FastAPI handler `GetReport` (Ruff N802)

```defect
id:       CD-AL17-b
file:     services/reports-py/app/reports.py
line:     14
severity: low
command:  /align-scan
class:    AL-17
owner:    align
bucket:   report-with-fix — `rename` to `get_report`; the route path `/reports/daily` does not change (V402)
detector: naming-layout-scan §2
anchor:   def GetReport(day: str) -> dict:
match:    GetReport|get_report|snake|N802|naming|rename
```

Ruff `select` includes `N` and `ai/conventions.md:54`. A FastAPI function name is not part of the wire contract; the path is.

## CD-AL18-a — Route `/clients/$clientId` and key `clients.title` where the glossary says "customer"

```defect
id:       CD-AL18-a
file:     apps/web/src/routes/clients/$clientId.tsx
line:     5
severity: low
command:  /align-scan
class:    AL-18
owner:    align
bucket:   report-flagged — the key and identifiers rename internally; the URL needs a redirect (P-15)
detector: naming-layout-scan §3
anchor:   export const Route = createFileRoute('/clients/$clientId')({
match:    client|customer|glossary|synonym|ubiquitous|clients\.title
```

`ai/glossary.md` lists "client" as a word not to use for a customer, and `ai/conventions.md:55` extends that to routes and translation keys. The page renders `CustomerDetail`; the route, the param, the component name and the `clients.title` key say client. The URL is public (links, bookmarks), so that part is a contract change with a redirect, not a mechanical rename.

## CD-AL18-b — Event `order.removed` where the glossary term is "deleted"

```defect
id:       CD-AL18-b
file:     apps/api/src/orders/orders.events.ts
line:     5
severity: low
command:  /align-scan
class:    AL-18
owner:    align
bucket:   report-flagged — the event name is a wire contract (P-15): `/refactor` + ADR, consumers first
detector: naming-layout-scan §3
anchor:   export const ORDER_REMOVED = 'order.removed';
match:    removed|deleted|glossary|synonym|event name|order\.removed
```

The glossary row "deleted … Not: removed, erased, trashed" and the rule's "event names". The notifications and reports services subscribe by the string, so renaming it is a coordinated contract change; the constant name can follow.

## CD-AL19-a — A `__tests__/` directory where tests are declared co-located

```defect
id:       CD-AL19-a
file:     apps/web/src/__tests__/OrdersList.test.tsx
line:     5
severity: low
command:  /align-scan
class:    AL-19
owner:    align
bucket:   report-flagged — a test-file move: its own reviewed commit, never inside a sweep (the V408 test lock)
detector: naming-layout-scan §4
anchor:   describe('orders list', () => {
match:    __tests__|co-?locat|test (file|placement)|beside|layout
```

`ai/conventions.md:60`. The test exercises `OrderCard`, so it moves beside `OrderCard.tsx`. Align's fix ladder treats test files as read-only (V-06), so the move cannot ride in an align sweep.

## CD-AL19-b — Feature `refunds/` has no `index.ts` barrel

```defect
id:       CD-AL19-b
file:     apps/web/src/features/refunds/RefundForm.tsx
line:     12
severity: low
command:  /align-scan
class:    AL-19
owner:    align
bucket:   report-with-fix — add `refunds/index.ts` (V404: whole-repo boundary run green)
detector: naming-layout-scan §4
anchor:   export function RefundForm({ orderId, maxMinor }: RefundFormProps) {
match:    index\.ts|barrel|refunds|skeleton|entry
```

`ai/conventions.md:61` and `ai/modules.md` ("Each feature exposes `index.ts`"); the other twelve feature directories have one.

## CD-AL22-a — `moment` in the admin app, banned everywhere

```defect
id:       CD-AL22-a
file:     apps/admin/src/utils/date-range.ts
line:     1
severity: medium
command:  /align-scan
class:    AL-22
owner:    align
bucket:   report-flagged — `@acme/format` formats only; there is no declared replacement for date arithmetic (ask; P-09)
detector: wrapper-adoption-scan §5
anchor:   import moment from 'moment';
match:    moment|banned|forbidden|date|library
```

`ai/conventions.md:12` ("`moment` is banned everywhere") and the `moment` entry in the root ban list. The admin config has the ban off (CD-AL31-a). The replacement is a rewrite of `lastNDays()`, not a swap.

## CD-AL22-b — `zustand/vanilla` store in admin, where pinia is the only allowed store

```defect
id:       CD-AL22-b
file:     apps/admin/src/utils/filter-state.ts
line:     1
severity: medium
command:  /align-scan
class:    AL-22
owner:    align
bucket:   report-flagged — move the state into a pinia store (not mechanical)
detector: wrapper-adoption-scan §5
anchor:   import { createStore } from 'zustand/vanilla';
match:    zustand|pinia|store library|allow.?list|forbidden|state
```

`ai/conventions.md:30` ("framework-free ones included"). No config rule bans `zustand`, so the oracle is the written allowlist.

## CD-AL29-a — Reasonless `eslint-disable-next-line no-restricted-imports` over a raw `ky` import

```defect
id:       CD-AL29-a
file:     apps/web/src/features/search/search-api.ts
line:     1
severity: medium
command:  /align-scan
class:    AL-29
owner:    align
bucket:   report-flagged — remove the disable and fix the site; `apiClient` is prefixed `/api/v2`, `/search` is not (a wrapper gap, P-09)
detector: convention-ratchet-scan §1
anchor:   // eslint-disable-next-line no-restricted-imports
match:    eslint-disable|suppress|no (reason|description)|require-description|ky
```

`@eslint-community/eslint-comments/require-description` is at error and this disable has no `-- reason`. Removing it surfaces a raw `ky` client for the `/search` service, which `apiClient` cannot reach as configured.

## CD-AL29-b — File-wide `stylelint-disable` of the token rule

```defect
id:       CD-AL29-b
file:     apps/web/src/features/checkout/Checkout.module.css
line:     1
severity: low
command:  /align-scan
class:    AL-29
owner:    align
bucket:   report-flagged — file-wide and reasonless; it hides `#1a73e9` (CD-HO-UI-f)
detector: convention-ratchet-scan §1
anchor:   /* stylelint-disable scale-unlimited/declaration-strict-value */
match:    stylelint-disable|suppress|file.?(wide|level)|no reason|declaration-strict-value
```

A file-scope disable with no description silences the one rule that checks the token convention for every declaration in the file.

## CD-AL29-c — Six disables share the boilerplate reason "legacy"

```defect
id:       CD-AL29-c
file:     apps/web/src/features/catalog/catalog-api.ts
line:     2
severity: low
command:  /align-scan
class:    AL-29
owner:    align
bucket:   report-flagged — one P-26 cluster row (6 × `-- legacy` on `no-restricted-imports`) for human review
detector: convention-ratchet-scan §1
anchor:   import dayjs from 'dayjs';
match:    legacy|cluster|boilerplate|copy.?pasted|same reason|eslint-disable
```

Three disables here and three in `CatalogFilters.tsx` carry `-- legacy`. The reason satisfies `require-description` but says nothing; more than five copies of one reason on one rule is a cluster (P-26), reported once.

## CD-AL30-a — Bulk-suppression count for `reviews-api.ts` grew 1 → 3

```defect
id:       CD-AL30-a
file:     eslint-suppressions.json
line:     4
severity: medium
command:  /align-scan
class:    AL-30
owner:    align
bucket:   report-flagged — revert the growth (base: `.refract-fixture/align-base/eslint-suppressions.json`, count 1; V395)
detector: convention-ratchet-scan §2
anchor:   "count": 3
match:    suppress|baseline|grew|grow|ratchet|count|eslint-suppressions
```

The base copy records one `no-restricted-imports` suppression for the file; head records three (`ky`, `HTTPError` from `ky`, `dayjs`). A bulk suppression is a documented exception only while it shrinks (P-03).

## CD-AL30-b — A new known violation recorded instead of fixed: `OrderHistoryPage` imports the frozen package

```defect
id:       CD-AL30-b
file:     .dependency-cruiser-known-violations.json
line:     13
severity: medium
command:  /align-scan
class:    AL-30
owner:    align
bucket:   report-flagged — the entry is new against the base copy (V395); ADR-0009 forbids the import
detector: convention-ratchet-scan §2
anchor:   "from": "apps/web/src/features/OrderHistory/OrderHistoryPage.tsx",
match:    known.?violation|dependency-cruiser|baseline|legacy-reports|grew|new entry|ratchet
```

The base copy holds one entry (`ReportsPage.tsx`); head adds `OrderHistoryPage.tsx` → `packages/legacy-reports`. ADR-0009 says new code must not import the frozen package; baselining the new import hides it.

## CD-AL31-a — Admin's ESLint config does not spread the shared one and turns the import ban off

```defect
id:       CD-AL31-a
file:     apps/admin/eslint.config.mjs
line:     12
severity: medium
command:  /align-scan
class:    AL-31
owner:    align
bucket:   report-flagged — config edit, heavy tier (`oracle-map.py`: rule `off`)
detector: convention-ratchet-scan §3
anchor:   'no-restricted-imports': 'off',
match:    eslint\.config|shared config|spread|off|no-restricted-imports|admin|config drift
```

The root file says "Packages lint through this file"; admin keeps its own array (the Vue preset only) and sets the convention's main rule to `off`. That is why CD-AL11-e and CD-AL22-a are invisible to ESLint.

## CD-AL31-b — `reports-py` ignores the banned-api code it declares

```defect
id:       CD-AL31-b
file:     services/reports-py/pyproject.toml
line:     12
severity: medium
command:  /align-scan
class:    AL-31
owner:    align
bucket:   report-flagged — remove the ignore (no reason, no ADR); P-17 does not apply
detector: convention-ratchet-scan §3
anchor:   extend-ignore = ["TID251"]
match:    TID251|extend-ignore|banned-api|ruff|ignore
```

The same file declares `"requests".msg = "Use app.http_client…"` and then ignores `TID251`, the code that reports it.

## CD-AL31-c — A stale `.eslintrc.json` beside the flat config on ESLint 10

```defect
id:       CD-AL31-c
file:     .eslintrc.json
line:     2
severity: low
command:  /align-scan
class:    AL-31
owner:    align
bucket:   report-with-fix — delete the dead file (`oracle-map.py` gate `eslintrc-dead`)
detector: convention-ratchet-scan §3
anchor:   "root": true,
match:    eslintrc|dead config|flat config|ESLint 10|stale|legacy config
```

The lockfile pins ESLint 10.13.0; ESLint 10.0.0 (2026-02-06) removed eslintrc, so its `axios`/`moment` ban reads like an oracle and enforces nothing.

## CD-AL32-a — styled-components left in a file that already uses a CSS Module (ADR-0011)

```defect
id:       CD-AL32-a
file:     apps/web/src/features/orders/components/OrderBadge.tsx
line:     6
severity: low
command:  /align-scan
class:    AL-32
owner:    align
bucket:   report-flagged — a mixed file is migrated when touched; VC (compiled-CSS diff or approval)
detector: convention-ratchet-scan §4
anchor:   const Pill = styled.span`
match:    styled|styled-components|CSS Modules?|ADR-0011|migrat|mixed
```

ADR-0011: from 2026-03-01 new and touched `apps/web` components use CSS Modules, and a file that mixes the two is migrated when touched. This one imports `OrderBadge.module.css` and still defines `styled.span` (a mixed file is a finding, P-25).

## CD-AL32-b — A `connect()` caller past the declared 2026-06-30 cut-off

```defect
id:       CD-AL32-b
file:     apps/web/src/features/cart/CartSummary.tsx
line:     33
severity: low
command:  /align-scan
class:    AL-32
owner:    align
bucket:   report-flagged — rewrite to `useAppSelector` (behaviour test); the deadline has passed
detector: convention-ratchet-scan §4
anchor:   export const CartSummary = connect(mapState)(CartSummaryView);
match:    connect\(|react-redux|useAppSelector|HOC|migrat|retired
```

`ai/conventions.md:33` retires `connect()` and dates the last callers at 2026-06-30; `cart-store.ts` already exports the typed hooks.

## CD-HO-UI-a — `#d92d20` in a ternary branch equals `--color-danger` (one candidate, every theme)

```defect
id:       CD-HO-UI-a
file:     apps/web/src/features/orders/components/OrderStatusBadge.tsx
line:     13
severity: low
command:  /frontend-audit
class:    AL-05
owner:    ui-ux design-token-audit §1
bucket:   routed — EQ; closer align (`replace-with-shared`, V397 + V394)
detector: design-token-audit (ui-ux)
anchor:   '#d92d20'
match:    #d92d20|--color-danger|token|hard.?cod|hex|literal colou?r
```

The literal sits in a ternary branch (`status === 'failed' ? '#d92d20' : …`), the carrier the eval's prototype missed. `/align-scan` lists it as routed with the owner line; it scores under `/frontend-audit`.

## CD-HO-UI-b — `#d92d20` on the refund error text

```defect
id:       CD-HO-UI-b
file:     apps/web/src/features/refunds/RefundForm.tsx
line:     38
severity: low
command:  /frontend-audit
class:    AL-05
owner:    ui-ux design-token-audit §1
bucket:   routed — EQ; closer align
detector: design-token-audit (ui-ux)
anchor:   {hasError ? <p style={{ color: '#d92d20' }}>
match:    #d92d20|--color-danger|token|hard.?cod|hex
```

## CD-HO-UI-c — `padding: 8px` in a CSS Module equals `--space-2`

```defect
id:       CD-HO-UI-c
file:     apps/web/src/features/orders/components/OrderCard.module.css
line:     4
severity: low
command:  /frontend-audit
class:    AL-05
owner:    ui-ux design-token-audit §1
bucket:   routed — EQ; closer align
detector: design-token-audit (ui-ux)
anchor:   padding: 8px;
match:    8px|--space-2|token|spacing|hard.?cod
```

## CD-HO-UI-d — `padding: 8px` in the cart summary

```defect
id:       CD-HO-UI-d
file:     apps/web/src/features/cart/Cart.module.css
line:     4
severity: low
command:  /frontend-audit
class:    AL-05
owner:    ui-ux design-token-audit §1
bucket:   routed — EQ; closer align
detector: design-token-audit (ui-ux)
anchor:   padding: 8px;
match:    8px|--space-2|token|spacing|hard.?cod
```

## CD-HO-UI-e — `padding: 13px` matches only `--font-size-sm` (cross-family)

```defect
id:       CD-HO-UI-e
file:     apps/web/src/features/orders/components/OrderTotals.tsx
line:     8
severity: low
command:  /frontend-audit
class:    AL-06
owner:    ui-ux design-token-audit §1 (swap trap)
bucket:   routed — report-flagged (P-27): nearest space token `--space-3` (12px) is a visible change, never auto-fixed
detector: design-token-audit (ui-ux)
anchor:   padding: '13px'
match:    13px|cross.?family|font-size-sm|space-3|off.?scale|nearest|visible change
```

The web-dashboard trap, again: 13px equals a font-size token, not a spacing token.

## CD-HO-UI-f — `#1a73e9` is 0.15 ΔE from `--color-primary` (#1a73e8)

```defect
id:       CD-HO-UI-f
file:     apps/web/src/features/checkout/Checkout.module.css
line:     11
severity: low
command:  /frontend-audit
class:    AL-06
owner:    ui-ux design-token-audit §1 (swap trap)
bucket:   routed — report-flagged: NEAREST only (VC, approval or `/polish`)
detector: design-token-audit (ui-ux)
anchor:   background: #1a73e9;
match:    #1a73e9|--color-primary|nearest|near.?miss|off.?palette|token
```

## CD-HO-UI-g — Tailwind arbitrary `bg-[#2563eb]` in the closed admin theme

```defect
id:       CD-HO-UI-g
file:     apps/admin/src/components/order-filters.vue
line:     16
severity: low
command:  /frontend-audit
class:    AL-07
owner:    ui-ux design-token-audit §2
bucket:   routed — EQ against admin's `--color-primary` → `bg-primary`; closer align
detector: design-token-audit (ui-ux)
anchor:   bg-[#2563eb]
match:    bg-\[|arbitrary|#2563eb|primary|tailwind|theme
```

`apps/admin/src/styles/theme.css` closes the palette (`--color-*: initial`) and defines `--color-primary: #2563eb`.

## CD-HO-UI-h — Native `<button>` beside the design-system `Button`

```defect
id:       CD-HO-UI-h
file:     apps/web/src/features/checkout/CheckoutPage.tsx
line:     25
severity: low
command:  /frontend-audit
class:    AL-12
owner:    ui-ux design-token-audit §6
bucket:   routed — closer align as VC (the class differs from `Button`'s), or `/unify-surfaces` if `Button` lacks a variant
detector: design-token-audit (ui-ux)
anchor:   <button type="button" className={styles.apply}
match:    <button|native button|Button|design.?system|@acme/ui
```

## CD-HO-CQ-a — A component imports `@acme/http` past its hook

```defect
id:       CD-HO-CQ-a
file:     apps/web/src/features/orders/components/OrderNotes.tsx
line:     2
severity: medium
command:  /quality-audit
class:    AL-20
owner:    code-quality architectural-diagnosis §1
bucket:   routed — closer align only through a hook the oracle names; none exists for notes → `/optimize`
detector: architectural-diagnosis (code-quality)
anchor:   import { apiClient } from '@acme/http';
match:    @acme/http|apiClient|layer|hook|component.{0,30}(import|call)|boundar
```

`ai/conventions.md:22`.

## CD-HO-CQ-b — A `useDebounce` copy with leading-edge semantics (diverged)

```defect
id:       CD-HO-CQ-b
file:     apps/web/src/features/search/useDebounce.ts
line:     4
severity: medium
command:  /quality-audit
class:    AL-13
owner:    code-quality duplication-scan
bucket:   routed — the copy diverged from `@acme/ui` (trailing edge): `/quality-fix`, not `dedupe`
detector: duplication-scan (code-quality)
anchor:   export function useDebounce<T>(value: T, delayMs = 300): T {
match:    useDebounce|leading|trailing|diverg|duplicat|copy
```

A differential test (V403) fails on the first keystroke, so align must not dedupe it.

## CD-HO-BE-a — Controller returns `{ error }` with a hand-set 409, past the problem-details filter

```defect
id:       CD-HO-BE-a
file:     apps/api/src/orders/orders.controller.ts
line:     26
severity: medium
command:  /backend-audit
class:    AL-23
owner:    backend edge-error-scan §7
bucket:   routed — declared contract (ADR-0004) → `/backend-fix`
detector: edge-error-scan (backend)
anchor:   return { error: 'order_not_cancellable' };
match:    error|problem\+json|9457|ADR-0004|ConflictException|throw|envelope
```

## CD-HO-BE-b — One list endpoint pages with `page`/`size`; the others use `cursor`/`limit`

```defect
id:       CD-HO-BE-b
file:     apps/api/src/customers/customers.controller.ts
line:     9
severity: low
command:  /backend-audit
class:    AL-25
owner:    backend api-consistency-audit §4
bucket:   routed — no declared pagination rule → `/polish`
detector: api-consistency-audit (backend)
anchor:   list(@Query('page') page = '1', @Query('size') size = '20') {
match:    page|size|cursor|limit|paginat
```

## CD-HO-FE-a — Literal "Save" where `common.save` = "Save" exists in every locale

```defect
id:       CD-HO-FE-a
file:     apps/web/src/features/settings/SettingsForm.tsx
line:     38
severity: low
command:  /frontend-audit
class:    AL-26
owner:    frontend i18n-scan §1
bucket:   routed — EQ key (P-31): closer align, `t('common.save')` (V405)
detector: i18n-scan (frontend)
anchor:   <Button type="submit">Save</Button>
match:    Save|common\.save|i18n|hard.?cod|t\(|translation|literal
```

## CD-HO-FE-b — Literal "Archive order" with no catalog key

```defect
id:       CD-HO-FE-b
file:     apps/web/src/features/orders/components/OrderActions.tsx
line:     33
severity: low
command:  /frontend-audit
class:    AL-26
owner:    frontend i18n-scan §1
bucket:   routed — new copy → `/frontend-fix` (never an align row)
detector: i18n-scan (frontend)
anchor:   Archive order
match:    Archive order|i18n|hard.?cod|t\(|translation|literal|new key
```

## CD-HO-FE-c — `<IconButton>` with no `label`

```defect
id:       CD-HO-FE-c
file:     apps/web/src/features/cart/CartItemRow.tsx
line:     25
severity: medium
command:  /frontend-audit
class:    AL-28
owner:    frontend a11y-code-scan §2
bucket:   routed — the wrapper has the prop: closer align as an AL-15 row, `label={t('cart.deleteItem')}`
detector: a11y-code-scan (frontend)
anchor:   <IconButton icon={TrashIcon} onClick={onDrop} />
match:    IconButton|label|aria-label|accessible name|a11y|icon.?only
```

## Mechanical half — the sweep gate on `fix-runs/`

AL-01, AL-33 and AL-34 are properties of a fix run, not of the tree, so they are proved by a script and not scored from a
report. `fix-runs/` holds real diffs of this tree in `align-sweep-gate.py`'s documented layout: `<name>.patch` (unified
diff), `<name>.ledger.md` (align-ledger `- id:` rows with `evidence`, `oracle`, `detector_re`, `detector_scope`),
optional `<name>.json` (judge verdicts), and `<name>.expect` (the verdict per check — this half's answer key).
`scripts/test-validators.sh` runs `tests/align-sweep-gate/run.sh`, which runs
`align-sweep-gate.py --self-test --fix-runs=benchmarks/fixtures/convention-drift/fix-runs` (every run against a copy under
`$TMPDIR`, compared with its `.expect`) and `oracle-map.py <fixture> quotes --candidates=fix-runs/candidates-invented.json`.

| run | class / gate | what the run does | expected |
|-----|--------------|-------------------|----------|
| `run-01` | AL-33 | #d92d20 -> var(--color-danger) in OrderStatusBadge, var(--color-error) (admin theme name) in RefundForm | `oracle PASS`; `scope PASS`; `redetect PASS`; `consistency FAIL`; `names PASS`; `roundtrip PASS`; `verdict FAIL` |
| `run-02` | AL-33 | padding 8px -> var(--space-2) in OrderCard.module.css, var(--gap-sm) in Cart.module.css | `scope PASS`; `redetect PASS`; `consistency FAIL`; `roundtrip PASS`; `verdict FAIL` |
| `run-03` | AL-34 | hit line fixed, imports reordered, labelKey() rewritten | `scope FAIL`; `consistency PASS`; `verdict FAIL` |
| `run-04` | AL-34 (V-06) | swap + snapshot update + the colour assertion removed | `lock-paths FAIL`; `scope FAIL`; `lock-count FAIL`; `verdict FAIL` |
| `run-05` | control PASS | EQ swap on the hit line; deep import re-routed through the package entry | `oracle PASS`; `approval PASS`; `diffkind PASS`; `lock-paths PASS`; `scope PASS`; `redetect PASS`; `consistency PASS`; `names PASS`; `roundtrip PASS`; `ratchet PASS`; `lock-count PASS`; `vacuous PASS`; `verdict PASS` |
| `run-06` | V-03b | 13px -> var(--space-3) (12px), no proof_class, no approval | `roundtrip FAIL`; `verdict FAIL` |
| `run-06b` | V-03b | the same snap, declared VC with a recorded approval | `approval PASS-flagged`; `roundtrip PASS-flagged`; `verdict PASS-flagged` |
| `run-07` | V-09 | clean EQ swap, but the rule scope (a boundaries element pattern with a typo) matches 0 files | `scope PASS`; `redetect PASS`; `names PASS`; `roundtrip PASS`; `vacuous NOT RUN`; `verdict NOT RUN` |
| `run-08` | V-08 | #d92d20 -> var(--color-dangerous), declared nowhere | `names FAIL`; `roundtrip FAIL`; `verdict FAIL` |
| `run-09` | AL-01 | the run-05 token swap, citing an oracle sentence that is not in ai/conventions.md | `oracle FAIL`; `verdict FAIL` |
| `run-10` | AL-34 (P-19) | the 13px row "closed" with whitespace only | `diffkind FAIL`; `scope FAIL`; `redetect FAIL`; `verdict FAIL` |
| `run-11` | AL-30 | the swap ships with eslint-suppressions.json grown 3 -> 4 | `scope FAIL`; `ratchet FAIL`; `verdict FAIL` |
| `run-12` | judge PASS on the run-08 FAIL | judge-override-refused, verdict stays FAIL | `names FAIL`; `verdict FAIL` |
| `run-13` | judge pending-review on the run-05 PASS | verdict pending-review | `verdict pending-review` |
| `candidates-invented.json` | AL-01 (V389) | six candidate rows: two cite an oracle that does not exist (a quote absent from `ai/conventions.md`, an undeclared rule id), two cite real rules, one a generated line, one a contested line | `AL-01: 2 candidate rows dropped (of 6)`; C3/C4 `kept`, C5 `unconfirmed`, C6 `contested` |

Align-owned seed count: 39 tree rows above + 2 AL-01 candidate rows + `run-09` (AL-01 inside a sweep) + `run-01`, `run-02`
(AL-33) + `run-03`, `run-04`, `run-10` (AL-34) = 47, with every align-owned class seeded at least twice. The other eight runs
are gate controls: the PASS control (`run-05`), V-03b / V-07 (`run-06`, `run-06b`), V-09 (`run-07`), V-08 (`run-08`), the
AL-30 ratchet inside a sweep (`run-11`) and the two judge rules (`run-12`, `run-13`).

## Decoys — must NOT be reported

Each is the look-alike of a seed above; the precedent that clears it is in the class line. Reporting one is a false
positive in every run its `command:` names.

```decoy
id:       CD-DECOY-01
file:     apps/web/src/export/pdf.ts
line:     2
command:  /align-scan
class:    decoy/AL-11 (P-03, ADR-0007)
anchor:   import ky from 'ky';
match:    \bky\b|apiClient|@acme/http|wrapper|raw
```

The disable cites `-- ADR-0007`, and ADR-0007 names this file.

```decoy
id:       CD-DECOY-02
file:     packages/ui/src/dialog/Dialog.tsx
line:     1
command:  /align-scan
class:    decoy/AL-11 (P-08)
anchor:   import * as RadixDialog from '@radix-ui/react-dialog';
match:    radix|@radix-ui|wrapper
```

The wrapper's own implementation.

```decoy
id:       CD-DECOY-03
file:     apps/web/src/features/orders/order-errors.ts
line:     1
command:  /align-scan
class:    decoy/AL-11 (P-12)
anchor:   import type { HTTPError } from 'ky';
match:    \bky\b|HTTPError|import type
```

Type-only; the ban sets `allowTypeImports: true`.

```decoy
id:       CD-DECOY-04
file:     apps/web/src/routes/orders/$orderId.tsx
line:     4
command:  /align-scan
class:    decoy/AL-16 (P-13)
anchor:   export const Route = createFileRoute('/orders/$orderId')({
match:    \$orderId|PascalCase|file ?name
```

TanStack Router `$param` file name.

```decoy
id:       CD-DECOY-05
file:     services/reports-py/app/__init__.py
line:     1
command:  /align-scan
class:    decoy/AL-16 (P-13)
anchor:   """Reports service:
match:    __init__|snake|file ?name
```

`__init__.py` under `.py: snake_case`.

```decoy
id:       CD-DECOY-06
file:     apps/admin/src/App.vue
line:     7
command:  /align-scan
class:    decoy/AL-16 (P-13)
anchor:   <main class="min-h-screen bg-surface p-6 text-ink">
match:    App\.vue|kebab|file ?name
```

The Vue root SFC under `.vue: kebab-case`.

```decoy
id:       CD-DECOY-07
file:     packages/ui/src/tokens.css
line:     5
command:  /align-scan /frontend-audit
class:    decoy/AL-05 (P-04)
anchor:   --color-danger: #d92d20;
match:    #d92d20|hard.?cod|literal
```

The token definition itself.

```decoy
id:       CD-DECOY-08
file:     apps/web/emails/receipt.html
line:     6
command:  /align-scan /frontend-audit
class:    decoy/AL-05 (P-06, P-21)
anchor:   <td style="padding:16px;color:#101828;font-family:Arial,sans-serif">
match:    #101828|16px|token|hard.?cod|inline
```

HTML e-mail; the doc says e-mail templates inline their colours.

```decoy
id:       CD-DECOY-09
file:     apps/web/src/charts/palette.ts
line:     3
command:  /align-scan /frontend-audit
class:    decoy/AL-05 (P-22)
anchor:   export const seriesPalette = [
match:    palette|#1f77b4|chart|hex|token
```

The declared categorical chart palette.

```decoy
id:       CD-DECOY-10
file:     apps/api/src/main.ts
line:     5
command:  /align-scan /quality-audit
class:    decoy/AL-20 (P-10)
anchor:   import { OrdersRepository } from './orders/orders.repository';
match:    repository|layer|controller|main\.ts
```

The composition root warms a cache through the repository.

```decoy
id:       CD-DECOY-11
file:     apps/api/src/orders/dto/carrier-order.dto.ts
line:     7
command:  /align-scan
class:    decoy/AL-17 (P-15)
anchor:   @Expose({ name: 'created_at' }) created_at!: string;
match:    created_at|camelCase|snake|naming
```

The carrier's wire name, bound by `@Expose`.

```decoy
id:       CD-DECOY-12
file:     apps/web/src/features/orders/components/OrderCard.module.css
line:     20
command:  /align-scan /frontend-audit
class:    decoy/AL-05 (P-05)
anchor:   border: 1px solid var(--color-border);
match:    1px|hairline|border|token
```

A 1px hairline, `margin: 0` and `currentColor` below it.

```decoy
id:       CD-DECOY-13
file:     packages/legacy-reports/src/ReportTable.tsx
line:     4
command:  /align-scan /frontend-audit
class:    decoy/AL-32 (P-16, ADR-0009)
anchor:   const Table = styled.table`
match:    styled|legacy-reports|13px|#667085|token|migrat
```

Frozen until 2027-03-31; its literals and styled-components stay.

```decoy
id:       CD-DECOY-14
file:     apps/api/src/orders/orders.service.ts
line:     28
command:  /align-scan /frontend-audit
class:    decoy/AL-26 (P-14)
anchor:   this.logger.log('Order archived');
match:    Order archived|i18n|translat|literal
```

A log message, not user-visible copy.

```decoy
id:       CD-DECOY-15
file:     apps/web/src/hooks/use-order-filters.ts
line:     7
command:  /align-scan
class:    decoy/AL-02 (P-01)
anchor:   return { status, setStatus, query, setQuery };
match:    tuple|object|return shape|hook
```

Five of the six state hooks return tuples; no rule names a return shape, so this one is not drift.

```decoy
id:       CD-DECOY-16
file:     apps/web/src/server/prefetch.ts
line:     4
command:  /align-scan
class:    decoy/AL-11 (P-17)
anchor:   const res = await fetch(
match:    fetch|apiClient|@acme/http|wrapper
```

Prerender code; the rule and its ESLint scope exclude `apps/web/src/server/`.

```decoy
id:       CD-DECOY-17
file:     apps/web/src/features/checkout/vendor-widget.ts
line:     3
command:  /align-scan
class:    decoy/AL-29 (P-03)
anchor:   // eslint-disable-next-line boundaries/dependencies -- ORD-412 vendor widget shim
match:    eslint-disable|ORD-412|boundaries|suppress
```

A reasoned disable with a ticket id.

```decoy
id:       CD-DECOY-18
file:     apps/web/src/features/customers/api.ts
line:     6
command:  /align-scan
class:    decoy/AL-11 (correct sibling)
anchor:   return apiClient.get(`customers/${id}`).json<Customer>();
match:    apiClient|@acme/http|wrapper
```

The correct sibling of CD-AL11-a.

```decoy
id:       CD-DECOY-19
file:     apps/web/src/features/orders/components/OrderCard.module.css
line:     27
command:  /align-scan /frontend-audit
class:    decoy/AL-05 (P-30, P-27)
anchor:   width: 8px;
match:    8px|--space-2|token|width
```

Layout geometry: equals `--space-2` across families; no size token family exists.

```decoy
id:       CD-DECOY-20
file:     apps/web/src/features/orders/components/OrderCard.module.css
line:     34
command:  /align-scan /frontend-audit
class:    decoy/AL-05 (P-05)
anchor:   color: var(--color-danger, #d92d20);
match:    #d92d20|fallback|hard.?cod|hex
```

A `var()` fallback, already tokenised.

```decoy
id:       CD-DECOY-21
file:     apps/web/src/routeTree.gen.ts
line:     1
command:  /align-scan
class:    decoy/AL-29 (P-16)
anchor:   /* eslint-disable */
match:    eslint-disable|generated|routeTree|suppress
```

Generated by TanStack Router and ignored by the config (`**/*.gen.ts`).

```decoy
id:       CD-DECOY-22
file:     apps/web/src/features/settings/SettingsPage.tsx
line:     4
command:  /align-scan
class:    decoy/AL-02 (P-28)
anchor:   export default function SettingsPage() {
match:    default export|named export
```

The named-exports rule is a generated (T2g) line: one ratification probe for the rule, never a site row.

```decoy
id:       CD-DECOY-23
file:     packages/ui/src/dialog/Dialog.module.css
line:     4
command:  /align-scan /frontend-audit
class:    decoy/AL-05 (P-08, P-23)
anchor:   background: rgb(16 24 40 / 60%);
match:    rgb|scrim|overlay|token
```

The design system's own overlay scrim; no scrim token exists.

```decoy
id:       CD-DECOY-24
file:     apps/web/src/features/orders/components/CancelOrderDialog.tsx
line:     25
command:  /align-scan
class:    decoy/AL-15 (correct sibling)
anchor:   <Can action="orders.cancel">
match:    \bCan\b|permission|gate
```

The gated sibling of CD-AL15-b.

## Detector measurement — the engines run on this fixture

Re-measured 2026-10-18 on a copy staged the way `run.sh` stages it (`--git --only=…`: 188 files, one commit), every engine
from `templates/packs/` with `python3 -I` (Python 3.8), nothing installed (no ESLint, ls-lint, Ruff or depcruise, so every
tool lane printed `blocked`), nothing written into the copy (`find -newer` after the run: empty outside `.git`). These are the
engines as they stand after the batch-6 engine fixes, not the `/align-scan` result.

**`oracle-map.py <copy> --age-buckets`**: `T1 15 · T1-warn 1 · T1-noci 19 · T2 53 · T2g 1 (unratified) · contested 2 · off 3 ·
inactive 0`; config rules by tool `depcruise 3 · eslint 14 · import-linter 1 · ls-lint 8 · ruff 6 · spectral 2 · stylelint 1 ·
tsc 3`; **56 doc rows from 7 files**; 9 wrappers; 8 exports; 2 CI lint steps; 11 inline exceptions (3 reasonless:
`search-api.ts:1`, `Checkout.module.css:1`, and the generated `routeTree.gen.ts:1`; the six `-- legacy` disables carry
`cluster 6`); **vacuous 0** (the `boundaries` `feature` element matches 63 files). Gates: `eslint-major v10`, `eslintrc-dead`
(`.eslintrc.json`), `ts7-no-api`, `boundaries-major v7 policies`, two `static!=resolved` (the Vue preset, the `apps/web`
tsconfig `extends`). CI: `eslint apps/web` and `tsc`, so the six shared ESLint rules are `ci=partial` and stylelint is
`T1-warn`. Ages: `history-blind (<= 1 commit touches this root)`. That covers CD-AL03-a/b, CD-AL31-a/b/c (rule `off` ×2,
`eslintrc-dead`), the AL-29 inputs and the AL-02-b re-tag (the generated hook line reads `contested`).

**`oracle-map.py quotes --candidates=fix-runs/candidates-invented.json`**: `AL-01: 2 candidate rows dropped (of 6)` — C1
`quote absent`, C2 `rule id not declared`; C3 `kept (written)`, C4 `kept (enforced T1)`, C5 `unconfirmed (T2g)`, C6
`contested`. Exit 1, as documented.

**`oracle-map.py propose`** over `name-check.py --census`: 16 concerns, `ledger_rows: 0` throughout. `hook-file-case: n=17 ·
camel 14 · kebab 3 → contested — ask (ai/conventions.md:100)` (CD-AL02-b); `props-declaration: n=42 · type 36 · interface 6 →
proposed canonical: type (36/42 = 0.86, whole-tree only, history-blind) — ratify?` (CD-AL02-c); the other 14 `undetermined`
(all below 30 sites). The toast split (CD-AL02-a, 6 `toast.error(` / 5 `notify({kind:'error'})` files) is not a `name-check.py`
concern: `convention-oracle`'s 2c census adds it as a 17th, `error-feedback`, `undetermined — ask`.

**`name-check.py --oracle --skeleton`** (file list through `--files=-`, never implicit stdin): 177 files, 16 naming rules,
**14 rows, 0 false** — 5 naming rows (CD-AL16-a `orderRow.tsx` case and stem ≠ export, CD-AL16-b `features/OrderHistory/`,
CD-AL16-c admin `OrderList.vue`, CD-AL17-b `GetReport`), 6 `advisory` AL-04 rows for the doc's `.store.ts` suffix that all 6
store files break (CD-AL04-a; P-18 makes them advisories, not renames), and 3 skeleton rows (`order-history/` absent from
`ai/modules.md:18`, CD-AL19-a `__tests__/`, CD-AL19-b the `refunds` barrel). Both contested hook rules are skipped. CD-AL17-a
is the § 2 grep fallback's (1 hit, `OrderSummaryCard.tsx:8`); the typed lane is `NOT RUN` (`ts7-no-api`). The first run of the
engine printed 74 rows, 11 true; each of its four defects is now a self-test case.

**`token-map.py --scan`**: `48 tokens (22 names) · themes light+dark · 3 sources`; `matched 144 files (2 exempt by path) ·
sites 14 · EXACT 9 (eq 8) · NEAREST 3 · NONE 2 · EXEMPT 0 · cross-family 3`. Per seed: CD-HO-UI-a/b `#d92d20` → EXACT
`--color-danger` eq=yes; CD-HO-UI-c/d `padding: 8px` → EXACT `--space-2` eq=yes (c also `xfam=--radius-md`); CD-HO-UI-e
`13px` → NEAREST `--space-3=12px` (1px) with `xfam=--font-size-sm`; CD-HO-UI-f `#1a73e9` → NEAREST `--color-primary` at 0.15
ΔE; CD-HO-UI-g `bg-[#2563eb]` → EXACT the admin package's own `--color-primary` eq=yes (`scope package`). The one EXACT eq=no
row is a frozen `packages/legacy-reports` literal whose dark value differs; P-16 / ADR-0009 clears all four legacy-reports rows
(CD-DECOY-13). `width`/`height: 8px` read NONE (P-30, CD-DECOY-19); the `var()` fallback is not a site (CD-DECOY-20).
`--lookup` agrees only when it is scoped: `--lookup=#d92d20 --prop=color --site=<seed file>` → eq=yes, while the same lookup
without `--site` reads the whole repo, finds admin's `--color-error` too, and prints eq=no (likewise `8px` → `--gap-sm`). A
caller classifying a site passes its `--site`.

**`align-sweep-gate.py --self-test --fix-runs=fix-runs`**: 14 of 14 runs match their `.expect` (run-01–04, 06, 08–12 FAIL;
run-05 PASS; run-06b PASS-flagged; run-07 NOT RUN; run-13 pending-review), then the synthetic suite: `29/29 OK`. Every FAIL run
fails on its intended check; the side failures each `.expect` also pins are documented in the table above.

**The detector pre-flights** (each skill's script run verbatim from its `SKILL.md`, from the copy's root; re-run 2026-10-18
after the final fix pass): **every in-tree align seed is hit.** `convention-oracle` 7 of 7 (CD-AL02-a from its 2c census
concern, `error-feedback` 7 `.error()` / 5 `notify({kind: error})`, the 7th being the design system's own `notify.ts:7`;
CD-AL04-b from its 4b doc-literal step, the doc's `/api/v1` in 0 files against `/api/v2` in 9); `wrapper-adoption-scan` 13 of
13, now one row per site (21 rows at 21 sites, against 41 lines before: T1 + T2 pairs joined, the admin sites cite only the
doc because `apps/admin/eslint.config.mjs:12` turns the T1 rule `off`, `date-range.ts:1` once as AL-22, deep imports once as
AL-14); `naming-layout-scan` 9 of 9 (the glossary parser reads the column its header names, `Not`, so CD-AL18-a/b print among
3a's 48 lines); `convention-ratchet-scan` 10 of 10 (`OLD` takes one pattern per line; 4a now offers the `connect()` bullet, and
`OLD=$'\bstyled\.\w+\n\bconnect\('` prints `CartSummary.tsx:33` for CD-AL32-b). `align-detect` lists all 11 detectors and
owners. Decoys printed by a pre-flight and refuted only at the read: CD-DECOY-01 (`pdf.ts`, the ADR-0007 reason), CD-DECOY-13
(frozen, ADR-0009), CD-DECOY-17 (ticket reason), CD-DECOY-18 (`apiClient`, synonym noise in 3a), CD-DECOY-21
(`routeTree.gen.ts`, generated, P-16). No false row is left that a read has to drop: `convention-ratchet-scan` step 2 no
longer lists `BASE_DIR`'s own two copies as baselines (3 baseline files, 0 false AL-30 rows), and its 2b prints `NOT RUN`
against a base holding 0 configs instead of nothing.

**Raw greps** (the eval's § 4.3 import forms, `apps packages services`, tests excluded): `ky` 9 hits (2 seeds; the ADR-0007
decoy; the wrapper's own `packages/http`; 2 baselined in `reviews-api.ts`; 2 in the `-- legacy` cluster; 1 under the reasonless
disable), `dayjs` 5 (the dynamic-import seed among them; the type-only `HTTPError` import is excluded by `(?!type\b)`),
`moment` 1, `@radix-ui/*` 6 (1 seed, 2 wrapper-own, 3 in the cluster), `zustand` 1, Python `requests` 1, deep imports 2 (both
seeds), suppression directives 11.
