# Architecture — tollgate api

## Layers

The API is hexagonal (ADR 0002). Dependencies point inwards only. The executable form of these
rules is `api/.dependency-cruiser.cjs`.

| Layer | Paths | May import |
|-------|-------|------------|
| domain | `api/src/domain/**` | nothing outside `domain/` — no framework, no Prisma, no Nest |
| application | `api/src/{billing,subscriptions,checkout,refunds,usage,invoices,payouts,wallet,coupons,imports}/**` | domain, `lib/`, `common/` |
| infrastructure | `api/src/{generated,jobs}/**`, Prisma client | application, domain |
| interface | `*.controller.ts`, `webhooks/**`, `admin/**` | application |
| composition root | `api/src/app.module.ts` | everything |

## Modules

`billing` (charges, invoices, tax, proration), `subscriptions` (status, plan changes, renewals),
`checkout`, `refunds`, `usage` (quotas, retention), `payouts`, `wallet`, `coupons`, `imports`
(queue consumers), `admin`, `reports`.

Shared money rules live once: tax in `billing/tax.ts`, proration in `billing/proration.ts`.
