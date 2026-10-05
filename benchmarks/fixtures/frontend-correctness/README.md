# Harbor Market

Same-day grocery delivery from independent shops around the harbour.

```
apps/shop/        Next.js 16 App Router + React 19, TanStack Query 5, Tailwind 4, next-intl (en, ar)
apps/admin/       Vue 3.5 + Vite, Pinia, vue-i18n (en, de), TanStack Vue Query — orders, pickers, deliveries, reports
packages/widgets/ Angular 22 standalone widgets embedded in partner recipe sites
```

## apps/shop

- `app/[locale]/(shop)/` — catalog (`c/[...slug]`), product detail, search, recipes. Public.
- `app/[locale]/account/` — orders, addresses. Signed-in only.
- `app/[locale]/checkout/` — basket review, delivery slot, place order.
- `lib/api.ts` is the browser HTTP client; `lib/queries.ts` the query hooks; `lib/server/*` runs only on the server.

## apps/admin

Single-page app for the dispatch team. `src/router.ts` is the route table, `src/lib/api.ts` the axios client,
`src/stores/` the Pinia stores. `VITE_USE_MOCKS=true` serves canned data for demos.

## packages/widgets

`<harbor-basket-button>` and `<harbor-recipe-list>`, Angular standalone components loaded by partner sites.

## Running locally

```bash
pnpm install
pnpm dev:shop     # http://localhost:3000
pnpm dev:admin    # http://localhost:5173
```
