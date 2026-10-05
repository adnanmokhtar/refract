# Lumen Home

Home-goods storefront and the back office that runs it.

```
apps/shop/        Next.js 16 App Router + React 19, TanStack Query 5, Tailwind 4, next-intl (en, ar)
apps/admin/       Vue 3.5 + Vite, Pinia, vue-i18n, TanStack Vue Query — orders, refunds, customers, reports
packages/widgets/ embeddable widgets for partner sites: Angular 22 standalone components and Svelte 5 components
ai/design/        design-time artifacts (state matrices) written before a feature is built
```

## apps/shop

- `app/[locale]/(storefront)/` — home, product detail, sign-in. Public, statically rendered where possible.
- `app/[locale]/account/` — orders, wishlist, profile, insights (spend and points charts). Signed-in only.
- `app/[locale]/checkout/` — contact details, coupon, place order.
- `components/` — feature folders; `components/ui/` holds the shared primitives (Button, Chip, Toast, Lightbox).
- `lib/api.ts` is the one HTTP client (`ApiError` carries the status); `lib/queries.ts` holds the query hooks.

Dark mode is the `.dark` class on `<html>` (Tailwind 4 `@custom-variant dark`). Arabic renders right-to-left.

Accessibility checks: `e2e/a11y.spec.ts` runs axe in Chromium against a production build on every PR;
Storybook runs the a11y addon on every story; `tests/unit/` holds jsdom component tests.

## apps/admin

Single-page app behind SSO. `src/router.ts` is the route table; `src/lib/api.ts` the axios client; Pinia stores in
`src/stores/`. Tokens live in `src/styles/tokens.css` (light and `[data-theme="dark"]`). `e2e/a11y.spec.ts` is the
Playwright axe check CI runs.

## packages/widgets

Built separately and loaded by partner sites through a script tag. The Angular widgets bootstrap with their own
router (`app.config.ts`); the Svelte widgets mount into a host element.

## Running locally

```bash
pnpm install
pnpm dev:shop     # http://localhost:3000
pnpm dev:admin    # http://localhost:5173
```
