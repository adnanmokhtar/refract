# Shelfwise

Inventory, orders and a merchant back office for independent retailers with one to a few
shops. A merchant connects their stores, keeps stock in sync, takes manual orders at the
counter, and sees what sells.

Plans: **Starter**, **Growth** and **Scale**, billed monthly through Stripe, plus paid
extensions (WhatsApp inbox, advanced reports, the AI assistant, API access, bulk import,
loyalty points, gift cards).

## Layout

| Path | What |
|---|---|
| `apps/api` | NestJS 11 on Fastify, MikroORM 6, Stripe, PostHog (server leg) |
| `apps/web` | React 19 + Vite 7 SPA, React Router 7, TanStack Query, i18next, PostHog + Meta pixel |
| `packages/contracts` | module keys, extension slugs and the plan map shared by both apps |
| `config` | billing config (Stripe lookup keys, plan limits) |
| `marketing` | the pricing page's data |
| `ai/product` | success definitions, the tracking plan, the assumption ledger |
| `ai/specs`, `features` | specs with acceptance criteria, and the Gherkin suite |

## Running it

```bash
pnpm install
pnpm --filter @shelfwise/api start:dev     # http://localhost:3000/api
pnpm --filter @shelfwise/web dev           # http://localhost:5173 (proxies /api in dev)
pnpm test                                  # unit + e2e
pnpm cucumber                              # the Gherkin suite
```

Status: checkout v2 (in-app plan upgrades) is GA; referrals are in beta.
