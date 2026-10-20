# Seeded defects — `business-rules`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the agent scans. If you stage
the fixture by hand, delete this file from the copy first — an agent that reads it will score 100% and the number will
mean nothing.

Fixture shape: `Fernhollow` — a multi-tenant commerce platform: a NestJS 11 / Fastify / MikroORM 6 API over Postgres with raw-SQL reports, a GL with a deferred balance trigger, wallets, POS with KSA receipts, coupons, FX, seat billing and a UBL builder, a React SPA, and a Django 5 / DRF / Celery back office (settlements, invoicing, Peppol, ZATCA, a settlement ledger, reports); 114 business seeds over 57 classes, 12 routed, 37 decoys.

The API runs MikroORM, decimal.js, date-fns, Stripe, xmlbuilder2 and XState; the back office runs Django 5.2, DRF,
Celery, django-fsm-2, python-dateutil, `holidays` and lxml. `ai/business-domain.md` declares the money, tax, metric,
business-time and retention policies the code is meant to follow, and `ai/business-flows.md` the declared lifecycles;
`golden/` holds a golden ledger day, a golden Peppol invoice and a golden daily report.

Invocation: /audit-business --whole-repo
Invocation[/quality-audit]: /quality-audit --whole-repo
Invocation[/db-audit]: /db-audit
Invocation[/security-audit]: /security-audit
Invocation[/backend-audit]: /backend-audit --whole-repo
Stage with: --git — `/audit-business` checks `git diff --exit-code` before it reports, and a whole-repo run on a copy
with no base branch has no diff to scope to.

Eval source: Track A batch 7, `eval-batch7-business.md` § 2 (the 57-class map), § 3.2 (the real target's correct
shapes, used as decoys), § 5.12 (fixture design), § 6 items 21–22. Classes are the research catalog's ids, shipped as
`BIZ-<id>`; precedents are `templates/snippets/precedents/business.md` § n; proofs are `proof-oracles.md` § Business
(V450–V484). Roots:
- `apps/api/src` — NestJS 11 on Fastify (`setGlobalPrefix('api')`): money module, orders and their transition +
  reversal tables, checkout tax, coupons, refunds, seat billing and metering, UBL invoices and the PDF renderer, POS tax
  and ZATCA receipts, the GL (`accounting/`), wallets, couriers, gift cards, inventory, 15 raw-SQL report queries;
  `apps/api/migrations/*.sql` holds the schema (the GL's deferred balance trigger, the wallet unique source key);
- `services/backoffice` — Django 5 + DRF + Celery: payouts and statements, FX, promotions, invoicing (django-fsm,
  Peppol, credit notes), ZATCA standard invoices, the settlement ledger, COD remittances, retention and privacy jobs,
  inventory, ORM and raw-SQL reports, carrier webhooks, KYC, campaigns;
- `apps/web/src` — React 19: the client roots `check-business-coverage` searches for an inverse's entry point;
- `ai/`, `golden/`, `infra/stripe/webhook-endpoint.json` (the subscribed event types), `.github/workflows/`.

Departures from the eval, stated so a reader can audit them:
- **CY-1 and CY-2 have two TypeScript seeds each.** The coverage pairing pairs POST routes; product's `surface-map.py`
  reads Django/DRF routes as method `ANY`, so a DRF forward/inverse pair cannot be paired by the static lane. The Python
  CY seeds are CY-3 to CY-6.
- **BR-LC3-a is anchored in `ai/business-flows.md`** — the declared side of a declared-not-built edge; the code side is
  an absence.
- **37 decoys, not 30**, and **12 routed rows over four owner commands** (`/quality-audit` 4, `/db-audit` 3,
  `/security-audit` 3, `/backend-audit` 2); the eval's distributed-systems examples are not seeded here (`ds-defects`
  covers consumer dedupe and the outbox).
- **The golden files are small** (one ledger day, one invoice, one report day): enough for V463/V457/V471 by hand.

Ownership and scoring. Five runs, five results rows, each staged in its own copy. **`/audit-business --whole-repo`**
scores the 114 business rows. The 12 routed rows score **only under their owner** — `/quality-audit` (float money twice,
a date-only parse, a divergent copy of the commission rule), `/db-audit` (a cascade into invoices, a float money column,
a legal number from a sequence), `/security-audit` (a client-chosen price, a single-use coupon race, a refund route with
no idempotency key) and `/backend-audit` (XState swallowing `CANCEL`, money as a JSON float) — and `/audit-business` must
list each as a routed row with its owner, never grade it; an `/audit-business` finding on them is UNMATCHED, not
credited. `bucket:` is the row's expected disposition: `report-with-fix` (the V-oracle can fail first against the
fixture's own declared policy and the fix is local), `report-flagged` (a person or an authority decides: a day count, a
chaining rule `[K?]`, a jurisdiction, a calendar, a declared lifecycle to change), `routed` (owner line only).

Secrets. None. The Stripe key is read from the environment and never present; tax ids, e-mail addresses and the SMTP
host are fabricated under `fernhollow.example`.

Line numbers are exact against the files in this directory and are re-checked by `benchmarks/run.sh --verify`, which also
fails if a decoy sits within 12 lines of a defect in the same file. Every line was computed from its anchor.

## Summary

| id | file:line | severity | command | class | bucket |
|----|-----------|----------|---------|-------|--------|
| BR-MP1-a | `apps/api/src/payouts/commission.calculator.ts:5` | high | `/audit-business` | BIZ-MP-1 | report-with-fix |
| BR-MP1-b | `services/backoffice/payouts/statements.py:14` | high | `/audit-business` | BIZ-MP-1 | report-with-fix |
| BR-MP2-a | `apps/api/src/invoices/invoice-lines.builder.ts:21` | high | `/audit-business` | BIZ-MP-2 | report-with-fix |
| BR-MP2-b | `services/backoffice/payouts/fees.py:10` | high | `/audit-business` | BIZ-MP-2 | report-with-fix |
| BR-MP3-a | `apps/api/src/reports/revenue-usd.report.ts:18` | high | `/audit-business` | BIZ-MP-3 | report-with-fix |
| BR-MP3-b | `services/backoffice/payouts/fx.py:18` | high | `/audit-business` | BIZ-MP-3 | report-with-fix |
| BR-PR1-a | `apps/api/src/pricing/coupon-stack.ts:11` | high | `/audit-business` | BIZ-PR-1 | report-with-fix |
| BR-PR1-b | `services/backoffice/promotions/pricing.py:14` | high | `/audit-business` | BIZ-PR-1 | report-with-fix |
| BR-PR2-a | `apps/api/src/refunds/refund-calculator.ts:5` | high | `/audit-business` | BIZ-PR-2 | report-with-fix |
| BR-PR2-b | `services/backoffice/invoicing/invoice_render.py:9` | high | `/audit-business` | BIZ-PR-2 | report-with-fix |
| BR-PR3-a | `apps/api/src/shipping/shipping-fee.ts:8` | medium | `/audit-business` | BIZ-PR-3 | report-with-fix |
| BR-PR3-b | `services/backoffice/loyalty/tiers.py:7` | medium | `/audit-business` | BIZ-PR-3 | report-with-fix |
| BR-PR4-a | `apps/api/src/promotions/apply-coupon.ts:27` | medium | `/audit-business` | BIZ-PR-4 | report-with-fix |
| BR-PR4-b | `services/backoffice/giftcards/redeem.py:7` | medium | `/audit-business` | BIZ-PR-4 | report-with-fix |
| BR-PR5-a | `apps/api/src/promotions/apply-coupon.ts:15` | medium | `/audit-business` | BIZ-PR-5 | report-flagged |
| BR-PR5-b | `services/backoffice/promotions/campaigns.py:8` | medium | `/audit-business` | BIZ-PR-5 | report-with-fix |
| BR-PR6-a | `apps/api/src/refunds/refund.service.ts:24` | high | `/audit-business` | BIZ-PR-6 | report-with-fix |
| BR-PR6-b | `services/backoffice/refunds/store_credit.py:6` | high | `/audit-business` | BIZ-PR-6 | report-with-fix |
| BR-BL1-a | `apps/api/src/subscriptions/plan-change.service.ts:16` | high | `/audit-business` | BIZ-BL-1 | report-flagged |
| BR-BL1-b | `services/backoffice/billing/proration.py:9` | high | `/audit-business` | BIZ-BL-1 | report-flagged |
| BR-BL2-a | `apps/api/src/subscriptions/renewal.scheduler.ts:16` | high | `/audit-business` | BIZ-BL-2 | report-with-fix |
| BR-BL2-b | `services/backoffice/billing/renewals.py:12` | high | `/audit-business` | BIZ-BL-2 | report-with-fix |
| BR-BL3-a | `apps/api/src/subscriptions/billing-period.ts:11` | medium | `/audit-business` | BIZ-BL-3 | report-with-fix |
| BR-BL3-b | `services/backoffice/billing/periods.py:8` | medium | `/audit-business` | BIZ-BL-3 | report-with-fix |
| BR-BL4-a | `apps/api/src/metering/usage-aggregator.ts:13` | medium | `/audit-business` | BIZ-BL-4 | report-flagged |
| BR-BL4-b | `services/backoffice/billing/metering.py:10` | medium | `/audit-business` | BIZ-BL-4 | report-with-fix |
| BR-TX1-a | `apps/api/src/invoices/invoice-pdf.renderer.ts:4` | high | `/audit-business` | BIZ-TX-1 | report-with-fix |
| BR-TX1-b | `services/backoffice/invoicing/tax_rates.py:6` | high | `/audit-business` | BIZ-TX-1 | report-with-fix |
| BR-TX2-a | `apps/api/src/checkout/checkout-tax.ts:18` | high | `/audit-business` | BIZ-TX-2 | report-with-fix |
| BR-TX2-b | `services/backoffice/invoicing/totals.py:11` | high | `/audit-business` | BIZ-TX-2 | report-with-fix |
| BR-TX3-a | `apps/api/src/invoices/invoice-lines.builder.ts:32` | medium | `/audit-business` | BIZ-TX-3 | report-with-fix |
| BR-TX3-b | `services/backoffice/invoicing/line_tax.py:10` | medium | `/audit-business` | BIZ-TX-3 | report-with-fix |
| BR-TX4-a | `apps/api/src/invoices/ubl-invoice.builder.ts:30` | high | `/audit-business` | BIZ-TX-4 | report-with-fix |
| BR-TX4-b | `services/backoffice/invoicing/totals.py:23` | high | `/audit-business` | BIZ-TX-4 | report-with-fix |
| BR-TX5-a | `apps/api/src/checkout/checkout-tax.ts:13` | high | `/audit-business` | BIZ-TX-5 | report-flagged |
| BR-TX5-b | `services/backoffice/invoicing/ubl_lines.py:6` | high | `/audit-business` | BIZ-TX-5 | report-with-fix |
| BR-TX6-a | `apps/api/src/invoices/ubl-invoice.builder.ts:19` | medium | `/audit-business` | BIZ-TX-6 | report-with-fix |
| BR-TX6-b | `services/backoffice/invoicing/export_invoice.py:5` | medium | `/audit-business` | BIZ-TX-6 | report-with-fix |
| BR-IV1-a | `apps/api/src/invoices/invoices.service.ts:18` | critical | `/audit-business` | BIZ-IV-1 | report-with-fix |
| BR-IV1-b | `services/backoffice/invoicing/admin_views.py:12` | critical | `/audit-business` | BIZ-IV-1 | report-with-fix |
| BR-IV2-a | `apps/api/src/invoices/credit-notes.service.ts:17` | high | `/audit-business` | BIZ-IV-2 | report-with-fix |
| BR-IV2-b | `services/backoffice/invoicing/credit_notes.py:9` | high | `/audit-business` | BIZ-IV-2 | report-with-fix |
| BR-IV3-a | `apps/api/src/invoices/ubl-invoice.builder.ts:16` | high | `/audit-business` | BIZ-IV-3 | report-with-fix |
| BR-IV3-b | `services/backoffice/einvoice/fatoora_builder.py:11` | high | `/audit-business` | BIZ-IV-3 | report-flagged |
| BR-IV4-a | `apps/api/src/pos/zatca-receipt.builder.ts:21` | high | `/audit-business` | BIZ-IV-4 | report-flagged |
| BR-IV4-b | `services/backoffice/einvoice/fatoora_builder.py:12` | high | `/audit-business` | BIZ-IV-4 | report-flagged |
| BR-IV5-a | `apps/api/src/invoices/invoice-pdf.renderer.ts:13` | medium | `/audit-business` | BIZ-IV-5 | report-with-fix |
| BR-IV5-b | `services/backoffice/invoicing/invoice_render.py:15` | medium | `/audit-business` | BIZ-IV-5 | report-with-fix |
| BR-LG1-a | `apps/api/src/wallets/wallet-ledger.service.ts:11` | critical | `/audit-business` | BIZ-LG-1 | report-with-fix |
| BR-LG1-b | `services/backoffice/ledger/fee_tasks.py:11` | critical | `/audit-business` | BIZ-LG-1 | report-with-fix |
| BR-LG2-a | `apps/api/src/accounting/journal-corrections.ts:14` | high | `/audit-business` | BIZ-LG-2 | report-with-fix |
| BR-LG2-b | `services/backoffice/ledger/admin_actions.py:6` | high | `/audit-business` | BIZ-LG-2 | report-with-fix |
| BR-LG3-a | `apps/api/src/accounting/payment-postings.ts:15` | critical | `/audit-business` | BIZ-LG-3 | report-with-fix |
| BR-LG3-b | `services/backoffice/ledger/postings.py:37` | critical | `/audit-business` | BIZ-LG-3 | report-with-fix |
| BR-LG4-a | `apps/api/src/couriers/courier-cod.service.ts:12` | medium | `/audit-business` | BIZ-LG-4 | report-with-fix |
| BR-LG4-b | `services/backoffice/wallets/credit.py:9` | medium | `/audit-business` | BIZ-LG-4 | report-with-fix |
| BR-LG5-a | `apps/api/src/wallets/wallet-transfer.service.ts:20` | high | `/audit-business` | BIZ-LG-5 | report-with-fix |
| BR-LG5-b | `services/backoffice/ledger/models.py:6` | high | `/audit-business` | BIZ-LG-5 | report-with-fix |
| BR-LG6-a | `apps/api/src/accounting/payment-postings.ts:23` | medium | `/audit-business` | BIZ-LG-6 | report-flagged |
| BR-LG6-b | `services/backoffice/cod/remittances.py:15` | medium | `/audit-business` | BIZ-LG-6 | report-with-fix |
| BR-LG7-a | `apps/api/src/accounting/refund-postings.ts:11` | high | `/audit-business` | BIZ-LG-7 | report-with-fix |
| BR-LG7-b | `services/backoffice/ledger/postings.py:47` | high | `/audit-business` | BIZ-LG-7 | report-with-fix |
| BR-FR1-a | `apps/api/src/accounts/account-deletion.service.ts:14` | critical | `/audit-business` | BIZ-FR-1 | report-with-fix |
| BR-FR1-b | `services/backoffice/tenants/offboarding.py:7` | critical | `/audit-business` | BIZ-FR-1 | report-with-fix |
| BR-FR2-a | `apps/api/src/maintenance/retention.job.ts:6` | high | `/audit-business` | BIZ-FR-2 | report-with-fix |
| BR-FR2-b | `services/backoffice/maintenance/tasks.py:12` | high | `/audit-business` | BIZ-FR-2 | report-with-fix |
| BR-FR3-a | `apps/api/src/wallets/wallet-transaction.entity.ts:14` | high | `/audit-business` | BIZ-FR-3 | report-with-fix |
| BR-FR3-b | `services/backoffice/privacy/anonymise.py:8` | high | `/audit-business` | BIZ-FR-3 | report-with-fix |
| BR-DM1-a | `apps/api/src/giftcards/gift-card-redeem.repository.ts:11` | critical | `/audit-business` | BIZ-DM-1 | report-with-fix |
| BR-DM1-b | `services/backoffice/inventory/stock.py:8` | critical | `/audit-business` | BIZ-DM-1 | report-with-fix |
| BR-DM2-a | `apps/api/src/inventory/stock-import.job.ts:12` | high | `/audit-business` | BIZ-DM-2 | report-with-fix |
| BR-DM2-b | `services/backoffice/inventory/reservations.py:8` | high | `/audit-business` | BIZ-DM-2 | report-with-fix |
| BR-RP1-a | `apps/api/src/reports/sales-summary.query.ts:14` | high | `/audit-business` | BIZ-RP-1 | report-with-fix |
| BR-RP1-b | `services/backoffice/reports/merchant_report.py:10` | high | `/audit-business` | BIZ-RP-1 | report-with-fix |
| BR-RP2-a | `apps/api/src/reports/dashboard-kpis.query.ts:12` | medium | `/audit-business` | BIZ-RP-2 | report-with-fix |
| BR-RP2-b | `services/backoffice/reports/finance.py:11` | medium | `/audit-business` | BIZ-RP-2 | report-with-fix |
| BR-RP3-a | `apps/api/src/reports/payout-forecast.query.ts:11` | medium | `/audit-business` | BIZ-RP-3 | report-with-fix |
| BR-RP3-b | `services/backoffice/reports/stores.py:8` | medium | `/audit-business` | BIZ-RP-3 | report-with-fix |
| BR-RP4-a | `apps/api/src/reports/platform-gmv.query.ts:11` | high | `/audit-business` | BIZ-RP-4 | report-with-fix |
| BR-RP4-b | `services/backoffice/reports/payouts_sql.py:7` | high | `/audit-business` | BIZ-RP-4 | report-with-fix |
| BR-RP5-a | `apps/api/src/reports/delivery-kpis.query.ts:12` | medium | `/audit-business` | BIZ-RP-5 | report-with-fix |
| BR-RP5-b | `services/backoffice/reports/aov.py:9` | medium | `/audit-business` | BIZ-RP-5 | report-with-fix |
| BR-RP6-a | `apps/api/src/reports/merchant-statement.query.ts:15` | medium | `/audit-business` | BIZ-RP-6 | report-with-fix |
| BR-RP6-b | `services/backoffice/reports/commission_export.py:10` | medium | `/audit-business` | BIZ-RP-6 | report-flagged |
| BR-RP7-a | `apps/api/src/reports/confirmed-orders.query.ts:13` | medium | `/audit-business` | BIZ-RP-7 | report-with-fix |
| BR-RP7-b | `services/backoffice/reports/deliveries.py:6` | medium | `/audit-business` | BIZ-RP-7 | report-with-fix |
| BR-BT1-a | `apps/api/src/reports/daily-sales.query.ts:11` | medium | `/audit-business` | BIZ-BT-1 | report-with-fix |
| BR-BT1-b | `services/backoffice/reports/daily.py:11` | medium | `/audit-business` | BIZ-BT-1 | report-with-fix |
| BR-BT2-a | `apps/api/src/payouts/settlement-date.ts:10` | medium | `/audit-business` | BIZ-BT-2 | report-flagged |
| BR-BT2-b | `services/backoffice/payouts/calendar.py:12` | medium | `/audit-business` | BIZ-BT-2 | report-flagged |
| BR-LC1-a | `apps/api/src/orders/order-status.ts:10` | medium | `/audit-business` | BIZ-LC-1 | report-with-fix |
| BR-LC1-b | `services/backoffice/payouts/models.py:7` | medium | `/audit-business` | BIZ-LC-1 | report-with-fix |
| BR-LC2-a | `apps/api/src/orders/order-status.ts:17` | high | `/audit-business` | BIZ-LC-2 | report-with-fix |
| BR-LC2-b | `services/backoffice/billing/models.py:5` | high | `/audit-business` | BIZ-LC-2 | report-flagged |
| BR-LC3-a | `ai/business-flows.md:9` | medium | `/audit-business` | BIZ-LC-3 | report-flagged |
| BR-LC3-b | `services/backoffice/invoicing/models.py:41` | medium | `/audit-business` | BIZ-LC-3 | report-with-fix |
| BR-LC4-a | `apps/api/src/payments/payment-capture.service.ts:20` | high | `/audit-business` | BIZ-LC-4 | report-with-fix |
| BR-LC4-b | `services/backoffice/payouts/settle.py:13` | high | `/audit-business` | BIZ-LC-4 | report-with-fix |
| BR-LC5-a | `apps/api/src/payments/stripe-webhook.handler.ts:14` | high | `/audit-business` | BIZ-LC-5 | report-with-fix |
| BR-LC5-b | `services/backoffice/shipping/carrier_webhooks.py:15` | high | `/audit-business` | BIZ-LC-5 | report-with-fix |
| BR-LC6-a | `apps/api/src/admin/order-repair.controller.ts:14` | medium | `/audit-business` | BIZ-LC-6 | report-with-fix |
| BR-LC6-b | `services/backoffice/merchants/kyc.py:9` | medium | `/audit-business` | BIZ-LC-6 | report-with-fix |
| BR-CY1-a | `apps/api/src/team/invites.controller.ts:13` | high | `/audit-business` | BIZ-CY-1 | report-with-fix |
| BR-CY1-b | `apps/api/src/stores/carrier-connections.controller.ts:11` | high | `/audit-business` | BIZ-CY-1 | report-with-fix |
| BR-CY2-a | `apps/api/src/stores/integrations.controller.ts:16` | high | `/audit-business` | BIZ-CY-2 | report-with-fix |
| BR-CY2-b | `apps/api/src/api-keys/api-keys.controller.ts:16` | high | `/audit-business` | BIZ-CY-2 | report-with-fix |
| BR-CY3-a | `apps/api/src/auth/signup.service.ts:13` | medium | `/audit-business` | BIZ-CY-3 | report-with-fix |
| BR-CY3-b | `services/backoffice/reports/views.py:13` | medium | `/audit-business` | BIZ-CY-3 | report-with-fix |
| BR-CY4-a | `apps/api/src/marketing/newsletter.sender.ts:11` | high | `/audit-business` | BIZ-CY-4 | report-with-fix |
| BR-CY4-b | `services/backoffice/marketing/campaigns.py:11` | high | `/audit-business` | BIZ-CY-4 | report-with-fix |
| BR-CY5-a | `apps/web/src/features/account/AccountSettingsPage.tsx:7` | high | `/audit-business` | BIZ-CY-5 | report-flagged |
| BR-CY5-b | `services/backoffice/privacy/views.py:9` | high | `/audit-business` | BIZ-CY-5 | report-with-fix |
| BR-CY6-a | `apps/api/src/subscriptions/subscription-payments.service.ts:17` | medium | `/audit-business` | BIZ-CY-6 | report-flagged |
| BR-CY6-b | `services/backoffice/merchants/onboarding.py:11` | medium | `/audit-business` | BIZ-CY-6 | report-with-fix |
| BR-HO-CQ-a | `apps/api/src/orders/order-import.ts:17` | medium | `/quality-audit` | CQ §4 float money | routed |
| BR-HO-CQ-b | `services/backoffice/payouts/psp_fees.py:5` | medium | `/quality-audit` | CQ §4 float money | routed |
| BR-HO-CQ-c | `apps/api/src/promotions/campaign-window.ts:8` | medium | `/quality-audit` | CQ §6 calendar arithmetic | routed |
| BR-HO-CQ-d | `apps/web/src/features/payouts/commission.ts:2` | medium | `/quality-audit` | CQ divergent copy | routed |
| BR-HO-DB-a | `apps/api/migrations/0001_core.sql:80` | high | `/db-audit` | DB §2 cascade into records of fact | routed |
| BR-HO-DB-b | `apps/api/migrations/0005_payouts.sql:6` | medium | `/db-audit` | DB §4 float money column | routed |
| BR-HO-DB-c | `apps/api/migrations/0001_core.sql:81` | high | `/db-audit` | DB §11 gapless number from a sequence | routed |
| BR-HO-SEC-a | `apps/api/src/checkout/checkout.service.ts:25` | critical | `/security-audit` | SEC §1 client-trusted price | routed |
| BR-HO-SEC-b | `apps/api/src/promotions/coupon-redemption.service.ts:13` | high | `/security-audit` | SEC §6 single-use coupon race | routed |
| BR-HO-SEC-c | `apps/api/src/refunds/refunds.controller.ts:8` | high | `/security-audit` | SEC §4 Idempotency-Key on a money route | routed |
| BR-HO-BE-a | `apps/api/src/shipping/shipments.service.ts:13` | high | `/backend-audit` | ST §1 FSM swallows an illegal event | routed |
| BR-HO-BE-b | `services/backoffice/payouts/serializers.py:7` | medium | `/backend-audit` | WF §1 money as a JSON float | routed |

114 business seeds (two per class over the 57 classes, one TypeScript and one Python where the class has a Python lane), 12 routed, 37 decoys.

## BR-MP1-a — The commission calculator switches decimal.js to half-even for the whole process

```defect
id:       BR-MP1-a
file:     apps/api/src/payouts/commission.calculator.ts
line:     5
severity: high
command:  /audit-business
class:    BIZ-MP-1
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §1
anchor:   Decimal.set({ rounding: Decimal.ROUND_HALF_EVEN });
match:    commission|Decimal\.set|ROUND_HALF_EVEN
match:    half.?even|bank|rounding (mode|polic)|two (rounding )?polic|policy|half away|ADR-0004|mode
```

`ai/business-domain.md` (ADR-0004) declares half away from zero, once per order, for commission; the back-office statement prints the same commission through `to_minor()` (`ROUND_HALF_UP`, away from zero). `Decimal.set` here makes every `toDecimalPlaces(0)` in the API process half-even, so a 0.5-minor-unit tie is booked one unit lower than the statement shows. Two live policies on one booked amount. Proof V450 (tie corpus through both paths). Fix: round through `money-policy.ts` and drop the global.

## BR-MP1-b — The merchant statement rounds the processing fee with the decimal context (half-even)

```defect
id:       BR-MP1-b
file:     services/backoffice/payouts/statements.py
line:     14
severity: high
command:  /audit-business
class:    BIZ-MP-1
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §1
anchor:   fee = (gross * merchant.fee_rate).quantize(CENT)
match:    fee|quantize|statement
match:    half.?even|context|default rounding|mode.?less|no rounding mode|ROUND_HALF_UP|two (rounding )?polic|policy|rounding mode
```

`quantize(CENT)` with no `rounding=` takes the context default, half-even; the fee the merchant is charged is rounded by `money/policy.py` (`ROUND_HALF_UP`, away from zero). On a tie the PDF statement shows one minor unit less than the settlement deducted. Proof V450. Fix: `to_minor()` from the policy module.

## BR-MP2-a — The invoice reads a fixed discount as major units; checkout stored minor units

```defect
id:       BR-MP2-a
file:     apps/api/src/invoices/invoice-lines.builder.ts
line:     21
severity: high
command:  /audit-business
class:    BIZ-MP-2
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §2
anchor:   const discountMinor = order.discountType === 'fixed' ? order.discountValue! * 100
match:    discount
match:    unit|minor|major|\* ?100|scale|percent|cents|two units|depends on
```

`discount_value` holds minor units when `discount_type='fixed'` and a percent when `'percentage'` (the entity's own comment; `orders/order-discount.ts` reads the fixed branch as minor units). The invoice builder multiplies the fixed value by 100, so a 5.00 coupon (500) prints a 500.00 discount line. Two-ended: the writer and `order-discount.ts` vs this reader. Proof V451 (write each unit, read through every reader). Fix: one unit per column (`discount_fixed_minor`, `discount_bps`).

## BR-MP2-b — The processing fee divides a fraction by 100

```defect
id:       BR-MP2-b
file:     services/backoffice/payouts/fees.py
line:     10
severity: high
command:  /audit-business
class:    BIZ-MP-2
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §2
anchor:   return to_minor(gross * merchant.fee_rate / 100)
match:    fee_rate|fee
match:    fraction|percent|/ ?100|unit|scale|basis|hundred
```

`Merchant.fee_rate` is a fraction (`help_text`: 0.025 is 2.5 %), and the statement multiplies by it directly; the fee charged on the settlement divides it by 100 again, so the merchant is charged 0.025 % instead of 2.5 %. Proof V451. Fix: one unit for the rate, read the same way by both paths.

## BR-MP3-a — Group revenue in USD re-converts every historical order at today's rate

```defect
id:       BR-MP3-a
file:     apps/api/src/reports/revenue-usd.report.ts
line:     18
severity: high
command:  /audit-business
class:    BIZ-MP-3
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §3
anchor:   usdMinor += await this.fx.convertAmount(row.total_minor, row.currency, 'USD');
match:    convert|fx|USD|rate
match:    today|latest|current|read time|not pinned|stored rate|fx_rate|re-?convert|later rate
```

Checkout pins the settlement rate on the order (`fx_rate`, `fx_rate_at`, `fx_source`); this investor report ignores it and calls `convertAmount`, which fetches the latest quote, so last quarter's USD revenue changes every day. Proof V452 (convert at t1, change the rate, re-read at t2). Fix: use the rate stored on the order.

## BR-MP3-b — The USD payout multiplies an EGP amount by the USD→EGP rate

```defect
id:       BR-MP3-b
file:     services/backoffice/payouts/fx.py
line:     18
severity: high
command:  /audit-business
class:    BIZ-MP-3
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §3
anchor:   payout_amount = amount_egp * get_exchange_rate("USD", "EGP")
match:    exchange|rate|EGP|USD|payout
match:    invert|direction|wrong way|reciprocal|divide|inverse|EGP per USD|multipl
```

`get_exchange_rate('USD', 'EGP')` returns EGP per one USD (48.5); multiplying an EGP settlement by it inflates the USD payout about 2,350-fold instead of dividing. Direction inverted. Proof V452 (A→B→A never gains). Fix: `get_exchange_rate('EGP', 'USD')`, or divide, with the rate pinned on the payout.

## BR-PR1-a — Coupons stack in request order, percent on the running total, with no floor

```defect
id:       BR-PR1-a
file:     apps/api/src/pricing/coupon-stack.ts
line:     11
severity: high
command:  /audit-business
class:    BIZ-PR-1
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §4
anchor:   total = kind === 'percent' ? total * (1 - percentOff / 100) : total - amountOffMinor;
match:    coupon|discount|stack|percentOff
match:    order|permut|sequence|request|floor|negative|below zero|stack|composition|Math\.max
```

The policy is item promotions, then at most one order coupon, never below zero. Here every coupon the request lists is applied in the request's order: `[10 off, 50 %]` and `[50 %, 10 off]` give different totals, and two fixed coupons drive the total negative. Proof V453 (permutation property, 0 ≤ total ≤ undiscounted). Fix: the declared order in `discount-policy.ts`, one order coupon, `Math.max(0, …)`.

## BR-PR1-b — Phone-order promotions apply in the order the request lists them, with no floor

```defect
id:       BR-PR1-b
file:     services/backoffice/promotions/pricing.py
line:     14
severity: high
command:  /audit-business
class:    BIZ-PR-1
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §4
anchor:   total -= promo_discount(promo, total)
match:    promo|discount|phone order|total
match:    order|permut|sequence|running total|floor|negative|stack|composition
```

Each percent promotion is taken off the running total, so the result depends on the request's order, and fixed promotions can make the total negative. Proof V453. Fix: the declared composition and a floor at zero.

## BR-PR2-a — The returns desk refunds a line at today's catalog price

```defect
id:       BR-PR2-a
file:     apps/api/src/refunds/refund-calculator.ts
line:     5
severity: high
command:  /audit-business
class:    BIZ-PR-2
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §5
anchor:   return line.product.price * line.quantity;
match:    product\.price|catalog|price|return
match:    snapshot|live|current|catalog|unit_?price|today|historical|changed
```

`OrderLine` stores `unit_price_minor` and `discount_alloc_minor`; the return amount reads `line.product.price`, the live catalog price. After a price change, a return gives back more (or less) than was paid. Proof V454 (place, change the catalog price, refund). Fix: `unitPriceMinor * quantity - discountAllocMinor`.

## BR-PR2-b — Back-office invoices re-render line prices from the live variant

```defect
id:       BR-PR2-b
file:     services/backoffice/invoicing/invoice_render.py
line:     9
severity: high
command:  /audit-business
class:    BIZ-PR-2
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §5
anchor:   unit = item.variant.unit_price
match:    variant|unit_price|render|invoice
match:    snapshot|live|current|catalog|re-?render|changed|historical
```

The context is rebuilt on every download from `item.variant.unit_price`, so an invoice issued in March shows April's price after a catalog change; the invoice's own lines are not read. Proof V454. Fix: render from the invoice's stored lines.

## BR-PR3-a — Free shipping is judged on the subtotal before discounts, once

```defect
id:       BR-PR3-a
file:     apps/api/src/shipping/shipping-fee.ts
line:     8
severity: medium
command:  /audit-business
class:    BIZ-PR-3
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §6
anchor:   if (cart.subtotalMinor >= FREE_SHIPPING_THRESHOLD_MINOR) return 0;
match:    free.?shipping|threshold|subtotal|shipping
match:    before (the )?discount|after (the )?discount|base|pre-?discount|re-?check|eligib
```

`Cart.subtotalMinor` is documented as before any promotion or coupon; the policy judges free shipping on the merchandise subtotal after discounts. A 55.00 cart with a 10.00 coupon ships free, and the fee is stored on the cart when it opens and never re-checked at placement. Proof V453 (property after each cart mutation). Fix: compare the post-discount subtotal at placement.

## BR-PR3-b — Loyalty tiers qualify on gross spend, before discounts and refunds

```defect
id:       BR-PR3-b
file:     services/backoffice/loyalty/tiers.py
line:     7
severity: medium
command:  /audit-business
class:    BIZ-PR-3
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §6
anchor:   if order.gross_total >= tier.min_spend:
match:    tier|min_spend|gross_total|loyalty
match:    gross|before|base|net|discount|refund|eligib
```

The policy judges eligibility on merchandise after discounts; `gross_total` includes tax, shipping and refunded orders, so a customer who returns everything still climbs a tier. Proof V453. Fix: the post-discount, net-of-refund base.

## BR-PR4-a — A fixed-amount coupon has no currency and applies to an order in any currency

```defect
id:       BR-PR4-a
file:     apps/api/src/promotions/apply-coupon.ts
line:     27
severity: medium
command:  /audit-business
class:    BIZ-PR-4
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §7
anchor:   const amountOff = Math.min(coupon.amountOffMinor, order.subtotalMinor);
match:    amountOff|fixed|coupon
match:    currency|JPY|KWD|EGP|USD|another currency|cross
```

`Coupon` stores `amountOffMinor` with no currency; a 10.00 USD coupon (1000) takes 1000 minor units off a KWD order (1.000 KWD) or an EGP order. The policy says fixed coupons carry a currency and apply only to orders in it. Proof V453 over currency pairs. Fix: a currency on the coupon and a guard.

## BR-PR4-b — A gift card is redeemed against an order without comparing currencies

```defect
id:       BR-PR4-b
file:     services/backoffice/giftcards/redeem.py
line:     7
severity: medium
command:  /audit-business
class:    BIZ-PR-4
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §7
anchor:   store_credit_minor = min(card.balance_minor, order.total_minor)
match:    gift.?card|store_credit|balance
match:    currency|another currency|cross|compare
```

`GiftCard.currency` exists but is never compared with the order's; an EGP card pays a USD phone order unit for unit. Proof V453. Fix: reject (or convert at a pinned rate) when the currencies differ.

## BR-PR5-a — Coupon expiry is a date-only input parsed as midnight UTC and checked only in the cart

```defect
id:       BR-PR5-a
file:     apps/api/src/promotions/apply-coupon.ts
line:     15
severity: medium
command:  /audit-business
class:    BIZ-PR-5
owner:    business
bucket:   report-flagged
detector: pricing-rule-scan §8
anchor:   if (coupon.expiresAt < new Date()) throw new CouponExpiredError('coupon expired');
match:    expires|expir|coupon
match:    midnight|UTC|zone|date-?only|last day|end of day|re-?check|placement|inclusive
```

`CouponsAdminController` stores `new Date(dto.expiresOn)` for a 'YYYY-MM-DD' input, i.e. 00:00 UTC on the last day — the coupon dies at 01:00 in Berlin and at 03:00 in Riyadh on the day it should still work; the result is kept on the cart and never re-checked when the order is placed. Which zone owns 'the last day' is the store's (policy). Proof V453 (23:59 and 00:01 store time; apply → advance → place). Flagged: whether the end is inclusive is the merchant's label.

## BR-PR5-b — Campaign windows use the server's date, not the store's

```defect
id:       BR-PR5-b
file:     services/backoffice/promotions/campaigns.py
line:     8
severity: medium
command:  /audit-business
class:    BIZ-PR-5
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §8
anchor:   return Campaign.objects.filter(store=store, starts_on__lte=date.today(), ends_on__gte=date.today())
match:    campaign|ends_on|date\.today
match:    zone|UTC|server|store.?s (time)?zone|business day|local
```

`date.today()` is the server's date (`TIME_ZONE = 'UTC'`); a Cairo store's last campaign day ends at 02:00 local or starts two hours late. The policy puts a campaign's last day in the store's zone. Proof V453. Fix: today in `store.timezone`.

## BR-PR6-a — A wallet refund returns the list price and never reads earlier refunds of the line

```defect
id:       BR-PR6-a
file:     apps/api/src/refunds/refund.service.ts
line:     24
severity: high
command:  /audit-business
class:    BIZ-PR-6
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §9
anchor:   const refundMinor = line.unitPriceMinor * quantity;
match:    refund
match:    discount|paid share|alloc|prior|previous|already refunded|bound|Σ|sum of refunds|more than
```

The refund ignores the order-level discount the line absorbed (`discount_alloc_minor`) and no path reads previous refunds of the same line, so three partial wallet refunds can return more than was paid. Stripe bounds its own card refunds (precedents/business.md § 26); the wallet path has no bound. Races are security's; the arithmetic rule is this. Proof V477. Fix: the paid share, and Σ refunds ≤ paid share in the refund transaction.

## BR-PR6-b — Store-credit refunds take any amount, with no bound against the paid share

```defect
id:       BR-PR6-b
file:     services/backoffice/refunds/store_credit.py
line:     6
severity: high
command:  /audit-business
class:    BIZ-PR-6
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §9
anchor:   return StoreCredit.objects.create(
match:    store.?credit|refund
match:    prior|previous|already|bound|paid share|more than|Σ|sum|unbounded|any amount
```

Support enters `amount_minor` and the credit is created: nothing reads the line's paid share or the refunds already given. Proof V477. Fix: compute the remaining refundable share in the same transaction.

## BR-BL1-a — Seat-plan changes prorate on a 30-day month and charge the full new plan on top

```defect
id:       BR-BL1-a
file:     apps/api/src/subscriptions/plan-change.service.ts
line:     16
severity: high
command:  /audit-business
class:    BIZ-BL-1
owner:    business
bucket:   report-flagged
detector: pricing-rule-scan §10
anchor:   const prorationCreditMinor = Math.round((current.priceMinor * daysLeft) / 30);
match:    prorat|seat plan|plan change
match:    30|day.?count|days in|month length|double|full charge|net
```

The credit uses a fixed 30-day month (February over-credits, 31-day months under-credit) and the new plan is charged in full for the remaining period, not prorated. No day count is declared anywhere. Proof V455 (formula golden at day 1, 15 and the last day). Flagged: the day count is a business decision.

## BR-BL1-b — Enterprise plan changes prorate on 30 days and charge the new price in full

```defect
id:       BR-BL1-b
file:     services/backoffice/billing/proration.py
line:     9
severity: high
command:  /audit-business
class:    BIZ-BL-1
owner:    business
bucket:   report-flagged
detector: pricing-rule-scan §10
anchor:   prorated_credit = old_price * Decimal(days_remaining) / DAYS_PER_MONTH
match:    prorat|plan change|enterprise
match:    30|day.?count|days in|month length|full|charge
```

Same shape on the back office's invoiced plans: `DAYS_PER_MONTH = 30` and `charge = new_price`. Proof V455. Flagged: the day count is the business's.

## BR-BL2-a — Seat renewals add a month to the previous end with `setUTCMonth` (overflow and drift)

```defect
id:       BR-BL2-a
file:     apps/api/src/subscriptions/renewal.scheduler.ts
line:     16
severity: high
command:  /audit-business
class:    BIZ-BL-2
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §11
anchor:   next.setUTCMonth(next.getUTCMonth() + 1);
match:    setUTCMonth|renew|period
match:    overflow|Jan(uary)? 31|Mar(ch)? 3|month end|anchor|drift|clamp
```

From a 31 January end, `setUTCMonth(+1)` gives 3 March (JS overflow); and because each period starts from the previous end, the day drifts for good. The subscription stores `anchorDate` and `cyclesBilled`, which `billing-anchor.ts` uses correctly. Proof V456 (13 months from 31 January across a leap February). Fix: `addMonths(anchorDate, cyclesBilled + 1)`.

## BR-BL2-b — Enterprise renewals use `date.replace(month=m+1)`

```defect
id:       BR-BL2-b
file:     services/backoffice/billing/renewals.py
line:     12
severity: high
command:  /audit-business
class:    BIZ-BL-2
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §11
anchor:   sub.current_period_end = sub.current_period_end.replace(month=sub.current_period_end.month + 1)
match:    replace|month|renew
match:    ValueError|day 31|December|13|month end|anchor|relativedelta|raises|overflow
```

`replace` raises `ValueError` for a 31st going into a 30-day month and for December (month 13), so the nightly task dies on the first such subscription and every later one is not renewed. Proof V456. Fix: `relativedelta(months=n)` from the anchor.

## BR-BL3-a — Usage periods end where the next starts, and `inPeriod` includes both ends

```defect
id:       BR-BL3-a
file:     apps/api/src/subscriptions/billing-period.ts
line:     11
severity: medium
command:  /audit-business
class:    BIZ-BL-3
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §12
anchor:   const periodEnd = addMonths(periodStart, 1);
match:    period|inPeriod|usage
match:    overlap|inclusive|<=|both (ends|bounds)|half-?open|two periods|boundary
```

`end(n) = start(n+1)` (half-open by construction) but `inPeriod` compares `at <= p.end`, so an event at exactly 00:00:00.000 on the 1st is billed in both months. Proof V456 (generated periods tile the timeline). Fix: `at < p.end`.

## BR-BL3-b — Back-office periods end one second before the next starts

```defect
id:       BR-BL3-b
file:     services/backoffice/billing/periods.py
line:     8
severity: medium
command:  /audit-business
class:    BIZ-BL-3
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §12
anchor:   period_end = period_start + relativedelta(months=1) - timedelta(seconds=1)
match:    period_end|period|billing
match:    gap|second|23:59:59|microsecond|none|half-?open|boundary
```

Timestamps carry microseconds; an event at 23:59:59.5 on the last day belongs to no period. Proof V456. Fix: half-open `[start, start + 1 month)`.

## BR-BL4-a — Usage is assigned to a period by receipt time; late events move months

```defect
id:       BR-BL4-a
file:     apps/api/src/metering/usage-aggregator.ts
line:     13
severity: medium
command:  /audit-business
class:    BIZ-BL-4
owner:    business
bucket:   report-flagged
detector: pricing-rule-scan §13
anchor:   receivedAt: { $gte: period.start, $lt: period.end },
match:    receivedAt|usage|metering
match:    receiv|event time|occurred|late|arriv|window
```

An SMS sent at 23:58 on the 31st and received at 00:03 is billed next month, and nothing handles events that arrive after the period was invoiced. Which timestamp counts is a business rule nobody declared. Proof V455 (golden metering fixture with a late event).

## BR-BL4-b — Metered usage for a billing day is cut at UTC midnight

```defect
id:       BR-BL4-b
file:     services/backoffice/billing/metering.py
line:     10
severity: medium
command:  /audit-business
class:    BIZ-BL-4
owner:    business
bucket:   report-with-fix
detector: pricing-rule-scan §13
anchor:   events = UsageEvent.objects.filter(merchant_id=merchant_id, occurred_at__gte=start_utc, occurred_at__lt=end_utc)
match:    usage|metering|billing day|start_utc
match:    UTC|zone|merchant.?s|local|business day|midnight
```

The billing day is the merchant's (policy: business time is the store's zone); `start_utc` uses UTC, so a Riyadh merchant's events between 00:00 and 03:00 local land on the previous day. Proof V455. Fix: the day's bounds in the merchant's zone.

## BR-TX1-a — The invoice PDF recomputes VAT at render time with a constant rate

```defect
id:       BR-TX1-a
file:     apps/api/src/invoices/invoice-pdf.renderer.ts
line:     4
severity: high
command:  /audit-business
class:    BIZ-TX-1
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §1
anchor:   const VAT_RATE = 0.19;
match:    VAT_RATE|0\.19|rate|PDF|render
match:    constant|hard.?coded|render|re-?render|effective|tax point|stored|persist|line
```

Invoices store `taxMinor` and every line stores `taxRateBp`; the renderer ignores both and multiplies `netMinor` by `0.19` on every download. A rate change re-prices every old invoice, and a non-German or zero-rated invoice renders 19 %. Proof V458 (golden invoice dated the day before and after a rate change). Fix: render the stored rate and tax.

## BR-TX1-b — Back-office invoices resolve the tax rate at `now`, not at the tax point

```defect
id:       BR-TX1-b
file:     services/backoffice/invoicing/tax_rates.py
line:     6
severity: high
command:  /audit-business
class:    BIZ-TX-1
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §1
anchor:   return TaxRate.objects.filter(category=category, valid_to=None).get().rate
match:    TaxRate|valid_to|current_tax_rate|rate
match:    tax point|now|current|issue date|effective|re-?render|valid_from
```

`valid_to=None` is today's open rate; re-sending an invoice issued before a rate change computes tax at the new rate. The table is effective-dated (`valid_from`/`valid_to`) but the query ignores the date. Proof V458. Fix: the rate valid at `invoice.issued_at`, copied to the line.

## BR-TX2-a — Checkout taxes each line before its allocated discount

```defect
id:       BR-TX2-a
file:     apps/api/src/checkout/checkout-tax.ts
line:     18
severity: high
command:  /audit-business
class:    BIZ-TX-2
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §2
anchor:   line.taxMinor = Math.round(line.quantity * line.unitPriceMinor * taxRate);
match:    tax|taxMinor|taxRate
match:    discount|base|before|alloc|gross|pre-?discount
```

The base is `unitPrice × quantity`; `discount_alloc_minor` is never subtracted, so every discounted order over-collects tax. The POS computes the same thing correctly (`pos-tax.ts`). Proof V459 (the base matrix). Fix: tax `net − allocated discount`.

## BR-TX2-b — Back-office gross amounts add tax to prices that already include it

```defect
id:       BR-TX2-b
file:     services/backoffice/invoicing/totals.py
line:     11
severity: high
command:  /audit-business
class:    BIZ-TX-2
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §2
anchor:   gross = line.price * (1 + tax_rate)
match:    gross|tax_rate|price
match:    inclusive|twice|again|double|PRICES_INCLUDE_TAX|gross-?up
```

`settings.PRICES_INCLUDE_TAX = True` for the back office; `gross_line` grosses up `line.price` regardless, so manual invoices charge VAT on VAT. Proof V459. Fix: carve tax out of inclusive prices (`price × r / (1 + r)`), never add it.

## BR-TX3-a — The invoice treats a store without the flag as tax-inclusive; checkout treats it as exclusive

```defect
id:       BR-TX3-a
file:     apps/api/src/invoices/invoice-lines.builder.ts
line:     32
severity: medium
command:  /audit-business
class:    BIZ-TX-3
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §3
anchor:   const inclusive = order.store.pricesIncludeTax ?? true;
match:    inclusive|pricesIncludeTax
match:    default|\?\? ?true|exclusive|false|two paths|disagree
```

`Store.pricesIncludeTax` defaults to `false` and the policy says prices are exclusive unless the store sets it; the invoice falls back to `true`, so one order is exclusive at checkout and inclusive on its invoice. Proof V459. Fix: read the stored flag (copied to the order) with one default.

## BR-TX3-b — Back-office lines take inclusive/exclusive from one global setting

```defect
id:       BR-TX3-b
file:     services/backoffice/invoicing/line_tax.py
line:     10
severity: medium
command:  /audit-business
class:    BIZ-TX-3
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §3
anchor:   inclusive = settings.PRICES_INCLUDE_TAX
match:    inclusive|PRICES_INCLUDE_TAX
match:    global|setting|per (store|line|price)|line carries|not carried|store
```

The line carries no flag; every back-office invoice uses `settings.PRICES_INCLUDE_TAX` whatever the store's own `prices_include_tax`. Proof V459. Fix: carry the flag on the line from the store.

## BR-TX4-a — The UBL TaxTotal sums per-line rounded VAT; the TaxSubtotal rounds the category once

```defect
id:       BR-TX4-a
file:     apps/api/src/invoices/ubl-invoice.builder.ts
line:     30
severity: high
command:  /audit-business
class:    BIZ-TX-4
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §4
anchor:   txt(major(Math.round((categoryNetMinor * categoryRateBp) / 10_000)));
match:    TaxSubtotal|TaxAmount|TaxTotal|category|round
match:    BR-CO|sum|Σ|per.?line|mismatch|rounding level|differ|validator
```

`cbc:TaxTotal/TaxAmount` is Σ of line-rounded VAT; `TaxSubtotal/TaxAmount` is `round(Σ net × rate)`. Three lines of 13.33 at 19 % give 7.59 vs 7.60, so the document breaks BR-CO-14 (TaxTotal = Σ TaxSubtotal) and the rounding level is two levels in one document. Proof V457, then V462 (validator). Fix: compute both from the same rounded parts.

## BR-TX4-b — The document tax total is rounded from the unrounded sum while the lines carry rounded tax

```defect
id:       BR-TX4-b
file:     services/backoffice/invoicing/totals.py
line:     23
severity: high
command:  /audit-business
class:    BIZ-TX-4
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §4
anchor:   tax_total = round(sum(line.net for line in lines) * rate, 2)
match:    tax_total|round|document
match:    Σ|sum|lines|per.?line|level|banker|half.?even|mismatch
```

`line_taxes` rounds each line half-up; `document_totals` rounds `Σ net × rate` with Python's `round` (half-even on a Decimal), so the printed total differs from the sum of the printed lines. Proof V457. Fix: one declared level — Σ of the rounded lines.

## BR-TX5-a — Web orders are taxed at the seller's country rate for every buyer

```defect
id:       BR-TX5-a
file:     apps/api/src/checkout/checkout-tax.ts
line:     13
severity: high
command:  /audit-business
class:    BIZ-TX-5
owner:    business
bucket:   report-flagged
detector: tax-invoice-scan §5
anchor:   const taxRate = await this.rates.forCountry(store.taxCountry, order.createdAt);
match:    taxCountry|forCountry|jurisdiction|seller
match:    buyer|customer|destination|reverse.?charge|OSS|place of supply|VAT (id|number)|B2B
```

The rate is the store's `taxCountry`; the buyer's country and VAT id are never read, so an EU B2B buyer with a valid VAT id is charged domestic VAT instead of reverse charge, and B2C cross-border sales ignore the destination. Proof V457 (golden invoices for a domestic, an exempt and a reverse-charge buyer). Flagged: which rules apply depends on the seller's registrations.

## BR-TX5-b — Exempt customers get category Z (zero-rated) and no exemption reason

```defect
id:       BR-TX5-b
file:     services/backoffice/invoicing/ubl_lines.py
line:     6
severity: high
command:  /audit-business
class:    BIZ-TX-5
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §5
anchor:   line.tax_category = "Z"
match:    tax_category|exempt|"Z"|zero
match:    exemption reason|reason|category E|wrong category|zero-?rated|exempt
```

An exempt supply is category `E` with an exemption reason (BT-120/121); `Z` is zero-rated goods. The line carries neither the right category nor a reason, so the invoice states the wrong legal basis. Proof V457 then V462. Fix: map exemption to `E` with the customer's exemption reason.

## BR-TX6-a — TaxCurrencyCode is the document currency; the VAT in the accounting currency is never stated

```defect
id:       BR-TX6-a
file:     apps/api/src/invoices/ubl-invoice.builder.ts
line:     19
severity: medium
command:  /audit-business
class:    BIZ-TX-6
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §6
anchor:   root.ele('cbc:TaxCurrencyCode').txt(invoice.currency);
match:    TaxCurrencyCode|tax currency
match:    accounting currency|EUR|BT-111|second TaxTotal|document currency|national
```

A USD invoice from a German seller must also state its VAT in EUR (BT-111, a second `TaxTotal` in the tax currency); the builder writes the document currency as the tax currency and emits one `TaxTotal`. Proof V462 on a foreign-currency golden. Fix: the seller's accounting currency and the converted VAT at the rate used.

## BR-TX6-b — The VAT report's EUR amount is the USD amount, unconverted

```defect
id:       BR-TX6-b
file:     services/backoffice/invoicing/export_invoice.py
line:     5
severity: medium
command:  /audit-business
class:    BIZ-TX-6
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §6
anchor:   vat_amount_accounting = invoice.tax_total
match:    vat_amount_accounting|vat_eur|EUR
match:    convert|rate|same number|USD|not converted|currency
```

`eur_rate` is passed in and reported as 'rate used', but `vat_eur` is `invoice.tax_total` in the document currency. Proof V462. Fix: `tax_total × eur_rate`, rounded per the policy.

## BR-IV1-a — Support can rewrite an issued invoice's totals and lines in place

```defect
id:       BR-IV1-a
file:     apps/api/src/invoices/invoices.service.ts
line:     18
severity: critical
command:  /audit-business
class:    BIZ-IV-1
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §7
anchor:   await this.em.nativeUpdate(Invoice, { id }, {
match:    nativeUpdate|adjust|invoice
match:    issued|mutable|credit note|status guard|draft|edit
```

`adjust()` updates `net_minor`, `tax_minor`, `total_minor` and `lines` by id, with no status in the WHERE: an issued (even transmitted) invoice changes. `InvoiceDraftsService.editDraft` shows the guarded shape. Proof V460 (edit an issued invoice through each writer → rejected). Fix: drafts only; corrections by credit note.

## BR-IV1-b — The back-office "correct total" action updates any invoice, bypassing the FSM

```defect
id:       BR-IV1-b
file:     services/backoffice/invoicing/admin_views.py
line:     12
severity: critical
command:  /audit-business
class:    BIZ-IV-1
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §7
anchor:   Invoice.objects.filter(pk=pk).update(total=request.data["total"], tax_total=request.data["tax_total"])
match:    correct.?total|update|invoice
match:    issued|mutable|credit note|status|bypass|fsm|edit
```

A queryset `update` on `total` and `tax_total` with no status filter skips django-fsm entirely; an issued invoice's amounts change with no credit note. Proof V460. Fix: refuse unless draft; issue a credit note.

## BR-IV2-a — A credit note may have no original invoice, and nothing bounds it

```defect
id:       BR-IV2-a
file:     apps/api/src/invoices/credit-notes.service.ts
line:     17
severity: high
command:  /audit-business
class:    BIZ-IV-2
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §8
anchor:   originalInvoiceId: dto.originalInvoiceId ?? null,
match:    credit.?note|originalInvoiceId
match:    optional|null|link|original|unbounded|Σ|exceed|more than
```

`originalInvoiceId` is optional (the column is nullable) and the amount is not compared with the original or with earlier credit notes. A credit note must reference the invoice it corrects. Proof V461 (credit 60 % twice → the second rejected). Fix: required link and Σ credits ≤ original in the issuing transaction.

## BR-IV2-b — A back-office credit note can exceed the invoice it credits

```defect
id:       BR-IV2-b
file:     services/backoffice/invoicing/credit_notes.py
line:     9
severity: high
command:  /audit-business
class:    BIZ-IV-2
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §8
anchor:   note = CreditNote.objects.create(invoice=invoice, amount_minor=amount_minor, reason=reason)
match:    credit.?note|amount_minor
match:    bound|exceed|more than|original|total|Σ|unbounded|any amount
```

The FSM moves the invoice to `credited`, but `amount_minor` is never compared with the invoice total, so a 500.00 credit note can be issued against a 50.00 invoice. Proof V461. Fix: bound the amount by the invoice's remaining creditable total.

## BR-IV3-a — The API's UBL builder is never run through a validator

```defect
id:       BR-IV3-a
file:     apps/api/src/invoices/ubl-invoice.builder.ts
line:     16
severity: high
command:  /audit-business
class:    BIZ-IV-3
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §9
anchor:   root.ele('cbc:CustomizationID').txt('urn:cen.eu:en16931:2017
match:    UBL|en16931|Peppol|builder|CustomizationID
match:    validat|KoSIT|schematron|CI|never|not run
```

CI validates the back office's Peppol samples only (`einvoice.yml` generates from `services/backoffice/invoicing/peppol.py`); the API's builder ships unvalidated — and it fails BR-CO-14 today (BR-TX4-a). Proof V462 (generate from the real builder, run KoSIT offline, exit 0). Fix: add the API builder's samples to the validator job.

## BR-IV3-b — The ZATCA standard-invoice builder is validated nowhere

```defect
id:       BR-IV3-b
file:     services/backoffice/einvoice/fatoora_builder.py
line:     11
severity: high
command:  /audit-business
class:    BIZ-IV-3
owner:    business
bucket:   report-flagged
detector: tax-invoice-scan §9
anchor:   def build_standard_invoice(invoice, device):
match:    ZATCA|fatoora|standard invoice|builder
match:    validat|SDK|never|not run|CI|clearance
```

No CI job, script or test runs the authority's validator on its output. Flagged: the Fatoora SDK is proprietary — `NOT-RUN` unless the project vendors it (proof-oracles V462).

## BR-IV4-a — The receipt chain (PIH, ICV) lives in one process's memory

```defect
id:       BR-IV4-a
file:     apps/api/src/pos/zatca-receipt.builder.ts
line:     21
severity: high
command:  /audit-business
class:    BIZ-IV-4
owner:    business
bucket:   report-flagged
detector: tax-invoice-scan §10
anchor:   pih: createHash('sha256').update(this.lastBuiltXml).digest('base64'),
match:    pih|previous|hash|icv|counter|chain
match:    memory|process|restart|last built|persist|instance|reset
```

`pih` hashes the last receipt *this instance built* and `icv` is an in-memory counter: two API replicas chain independently, a restart resets the counter and hashes an empty string, and a rejected receipt still becomes the 'previous'. Flagged `[K?]`: the chaining rule is the authority's (proof-oracles V480, then V462). Fix: read the last persisted, accepted receipt per register inside a serialised transaction.

## BR-IV4-b — The invoice counter is `count() + 1`, outside any lock

```defect
id:       BR-IV4-b
file:     services/backoffice/einvoice/fatoora_builder.py
line:     12
severity: high
command:  /audit-business
class:    BIZ-IV-4
owner:    business
bucket:   report-flagged
detector: tax-invoice-scan §10
anchor:   icv = Invoice.objects.filter(device_id=device.id).count() + 1
match:    icv|counter|count\(\)
match:    race|concurren|duplicate|transaction|lock|serial|gap
```

Two invoices built concurrently for one device get the same ICV, and a deleted invoice makes the next value repeat. Flagged `[K?]` per authority (V480). Fix: a per-device counter row locked in the issuing transaction.

## BR-IV5-a — The invoice PDF prints today's date (UTC) as the issue date

```defect
id:       BR-IV5-a
file:     apps/api/src/invoices/invoice-pdf.renderer.ts
line:     13
severity: medium
command:  /audit-business
class:    BIZ-IV-5
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §11
anchor:   issueDate: new Date().toISOString().slice(0, 10),
match:    issueDate|issue date|render
match:    render|download|today|now|issuedAt|stamp|re-?render|UTC
```

Every download stamps the current UTC date; `invoice.issuedAt` is ignored, so a March invoice downloaded in May says May, and a late-evening issue in Berlin prints the previous day. Proof V457 (render, advance the clock, re-render: identical). Fix: `issuedAt` in the store's zone.

## BR-IV5-b — The seller's VAT id is read from live company settings on every render

```defect
id:       BR-IV5-b
file:     services/backoffice/invoicing/invoice_render.py
line:     15
severity: medium
command:  /audit-business
class:    BIZ-IV-5
owner:    business
bucket:   report-with-fix
detector: tax-invoice-scan §11
anchor:   "seller_vat_id": company.vat_number,
match:    vat_number|seller_vat|company
match:    live|settings|snapshot|re-?render|current|profile|changed
```

After the company registers a new VAT id, every old invoice re-renders with it. Party ids are part of the issued document. Proof V457. Fix: snapshot seller and buyer ids on the invoice at issue.

## BR-LG1-a — A wallet top-up inserts one positive leg; nothing funds it

```defect
id:       BR-LG1-a
file:     apps/api/src/wallets/wallet-ledger.service.ts
line:     11
severity: critical
command:  /audit-business
class:    BIZ-LG-1
owner:    business
bucket:   report-with-fix
detector: ledger-scan §1
anchor:   `insert into wallet_transactions (id, wallet_id, amount_minor, currency, kind, source_type, source_id, customer_email)
match:    top.?up|wallet_transactions|insert
match:    one leg|single|counter.?leg|balanc|unbalanced|nothing sums|funding|from nowhere|double.?entry
```

Support credits a customer wallet with a single raw insert: no clearing or expense leg, no `assertBalanced`, and `wallet_transactions` has no balance trigger (only the GL has one). Money appears from nowhere on the books. Proof V463 (a direct unbalanced insert must be rejected at COMMIT). Fix: post through a two-leg function against a goodwill/expense account.

## BR-LG1-b — The monthly fee task books one raw leg per merchant, bypassing `post_entry`

```defect
id:       BR-LG1-b
file:     services/backoffice/ledger/fee_tasks.py
line:     11
severity: critical
command:  /audit-business
class:    BIZ-LG-1
owner:    business
bucket:   report-with-fix
detector: ledger-scan §1
anchor:   "insert into settlement_ledger_lines (entry_id, account_id, currency, amount_minor) "
match:    fee|settlement_ledger_lines|raw|insert
match:    one leg|single|bypass|post_entry|balanc|unbalanced|trigger|sum
```

`post_entry` asserts the sum; this Celery task writes only the merchant-payable credit with raw SQL, and the settlement ledger has no database-level check, so the fee entry never balances against revenue. Proof V463. Fix: post each fee through `post_entry` with the revenue leg.

## BR-LG2-a — Finance "re-amounts" posted GL entries in place

```defect
id:       BR-LG2-a
file:     apps/api/src/accounting/journal-corrections.ts
line:     14
severity: high
command:  /audit-business
class:    BIZ-LG-2
owner:    business
bucket:   report-with-fix
detector: ledger-scan §2
anchor:   await conn.execute('update gl_journal_lines set debit_minor = ? where entry_id = ? and account_code = ?'
match:    reAmount|re-?amount|gl_journal_lines|update
match:    posted|mutable|immutable|reversal|in place|edit|amount
```

Both legs of a posted entry get a new amount: the deferred trigger is satisfied (the entry still balances), but the original amount and the correction both vanish from the books. `JournalReversalService` is the project's own correct path (mirror, then repost). Proof V464 (golden ledger diff of a correction shows added rows only). Fix: route the tool through the reversal service; refuse UPDATE of amounts.

## BR-LG2-b — A "mistaken" settlement-ledger entry is deleted, lines and all

```defect
id:       BR-LG2-b
file:     services/backoffice/ledger/admin_actions.py
line:     6
severity: high
command:  /audit-business
class:    BIZ-LG-2
owner:    business
bucket:   report-with-fix
detector: ledger-scan §2
anchor:   LedgerLine.objects.filter(entry_id=entry_id).delete()
match:    delete|LedgerLine|mistaken
match:    immutable|append|reversal|delete|erase|vanish|history
```

An operator action deletes posted lines and the entry; the ledger loses history and every balance derived from it changes retroactively. Proof V464. Fix: post a reversal linked to the entry.

## BR-LG3-a — Payment postings are de-duplicated by a find-then-insert with no unique key

```defect
id:       BR-LG3-a
file:     apps/api/src/accounting/payment-postings.ts
line:     15
severity: critical
command:  /audit-business
class:    BIZ-LG-3
owner:    business
bucket:   report-with-fix
detector: ledger-scan §3
anchor:   const existing = await this.em.findOne(GlJournalEntry, { sourceType: 'payment', sourceId: payment.id });
match:    sourceId|source_id|findOne|payment
match:    unique|idempot|twice|duplicate|race|concurren|check.?then|index
```

`gl_journal_entries (source_type, source_id)` has a plain index, not a unique one; two webhook deliveries for one capture both pass `findOne` and both post. Proof V465 (deliver the same event N times, concurrently: one entry). Fix: unique `(source_type, source_id)` and `on conflict do nothing` in the same statement.

## BR-LG3-b — The payout posting's idempotency key contains a fresh UUID

```defect
id:       BR-LG3-b
file:     services/backoffice/ledger/postings.py
line:     37
severity: critical
command:  /audit-business
class:    BIZ-LG-3
owner:    business
bucket:   report-with-fix
detector: ledger-scan §3
anchor:   idempotency_key = f"payout-{payout.id}-{uuid.uuid4()}"
match:    idempotency|uuid|post_payout
match:    random|uuid4|retr(y|ied)|every call|per call|fresh|deterministic|twice|again|duplicate
```

The key is unique per call, so a retried Celery task posts the payout again: the unique constraint can never fire. Proof V465. Fix: derive the key from the payout id alone (`payout-{id}`).

## BR-LG4-a — The courier COD cache is flushed before its ledger row, in another transaction, with no sweep

```defect
id:       BR-LG4-a
file:     apps/api/src/couriers/courier-cod.service.ts
line:     12
severity: medium
command:  /audit-business
class:    BIZ-LG-4
owner:    business
bucket:   report-with-fix
detector: ledger-scan §4
anchor:   courier.codBalanceMinor += order.codMinor;
match:    codBalance|courier|cache
match:    transaction|before|separate|flush|drift|sweep|truth|second source
```

The cache is flushed first and `courier_cod_entries` inserted afterwards in a separate statement; a failure in between leaves a balance no entry explains, and no job compares the two (the merchant wallets have one: `wallet-balance.sweep.ts`). Proof V466 (cache = Σ entries per courier; a crash between the writes is detected). Fix: one transaction plus a sweep.

## BR-LG4-b — Customer credit: the balance changes outside the atomic block that writes the entry

```defect
id:       BR-LG4-b
file:     services/backoffice/wallets/credit.py
line:     9
severity: medium
command:  /audit-business
class:    BIZ-LG-4
owner:    business
bucket:   report-with-fix
detector: ledger-scan §4
anchor:   CustomerCreditBalance.objects.filter(customer_id=customer_id).update(balance_minor=F("balance_minor") + delta_minor)
match:    balance|credit|cache|F\(
match:    transaction|atomic|outside|before|separate|drift|sweep|second source
```

The cache update runs before `transaction.atomic()`; if the entry insert fails the balance stays changed, and no sweep compares the cache with Σ `CustomerCreditEntry`. Proof V466. Fix: both writes in one atomic block, plus a drift check.

## BR-LG5-a — A cross-currency wallet transfer is one entry with a USD leg and an EGP leg

```defect
id:       BR-LG5-a
file:     apps/api/src/wallets/wallet-transfer.service.ts
line:     20
severity: high
command:  /audit-business
class:    BIZ-LG-5
owner:    business
bucket:   report-with-fix
detector: ledger-scan §5
anchor:   { walletId: from.id, amountMinor: -amountMinor, currency: fromCurrency, leg: 0 },
match:    transfer|fromCurrency|toCurrency|legs
match:    currenc|FX|liquidity|two currencies|mixed|per.?currency|conversion account
```

The pair moves value between two currencies with no FX (liquidity) account on each side, so neither currency's legs sum to zero and the FX gain or loss is invisible. Proof V463 (per-currency sums zero after an FX scenario). Fix: four legs through `fx_liquidity` per currency.

## BR-LG5-b — Settlement-ledger accounts have an optional currency

```defect
id:       BR-LG5-b
file:     services/backoffice/ledger/models.py
line:     6
severity: high
command:  /audit-business
class:    BIZ-LG-5
owner:    business
bucket:   report-with-fix
detector: ledger-scan §5
anchor:   currency = models.CharField(max_length=3, null=True, blank=True)
match:    LedgerAccount|currency|account
match:    null|optional|two currencies|mixed|fixed per account|nullable
```

Lines carry their own currency and the account's is nullable, so one account (`merchant_payable:<id>`) accumulates EGP and USD lines and its balance is a meaningless sum. Proof V463. Fix: currency required and fixed per account; reject a line in another currency.

## BR-LG6-a — Stripe clearing is booked and never reconciled with Stripe

```defect
id:       BR-LG6-a
file:     apps/api/src/accounting/payment-postings.ts
line:     23
severity: medium
command:  /audit-business
class:    BIZ-LG-6
owner:    business
bucket:   report-flagged
detector: ledger-scan §6
anchor:   (values ('stripe_clearing', ?::bigint, 0::bigint),
match:    stripe_clearing|clearing|Stripe
match:    reconcil|balance transactions|payout|settle|nets? to zero|compare
```

Stripe is in the lockfile and every capture debits `stripe_clearing`; no job ingests Stripe balance transactions or payouts and compares them with the clearing account, so missing or double captures never surface. Proof V467 (a golden provider export for a day against the ledger). Flagged: reconciliation could live in an external accounting tool — the policy does not say.

## BR-LG6-b — The COD remittance import marks parcels remitted without comparing any amount

```defect
id:       BR-LG6-b
file:     services/backoffice/cod/remittances.py
line:     15
severity: medium
command:  /audit-business
class:    BIZ-LG-6
owner:    business
bucket:   report-with-fix
detector: ledger-scan §6
anchor:   return Shipment.objects.filter(tracking_no__in=tracking_numbers).update(cod_remitted=True)
match:    remitt|COD|cod_remitted
match:    amount|compare|reconcil|ledger|clearing|courier_cod|match
```

The courier's file is trusted: every listed tracking number is flagged remitted, whatever cash the courier actually paid, and nothing compares the file with the courier's `cod_clearing` entries. Proof V467 (a golden remittance file with a short-paid row). Fix: match amounts per parcel against the ledger and post the difference.

## BR-LG7-a — Refund reversals recompute the amount from a share instead of mirroring the original legs

```defect
id:       BR-LG7-a
file:     apps/api/src/accounting/refund-postings.ts
line:     11
severity: high
command:  /audit-business
class:    BIZ-LG-7
owner:    business
bucket:   report-with-fix
detector: ledger-scan §7
anchor:   const refundMinor = Math.round(order.totalMinor * share);
match:    refund|share|postRefundReversal
match:    recomput|mirror|cent|conserv|round|stray|net(s)? to zero|original
```

Two 50 % refunds of 99.99 post 50.00 + 50.00 = 100.00 against a 99.99 capture: the stray cent stays on the books, and the refund ignores what the refund service actually returned. Proof V477 (charge → partial refunds → full refund nets to zero). Fix: post the refunded amount the refund record holds, mirroring the capture's legs.

## BR-LG7-b — A capture posts the authorised amount, not the captured one

```defect
id:       BR-LG7-b
file:     services/backoffice/ledger/postings.py
line:     47
severity: high
command:  /audit-business
class:    BIZ-LG-7
owner:    business
bucket:   report-with-fix
detector: ledger-scan §7
anchor:   amount_minor = payment.amount_authorized
match:    amount_authori[sz]ed|capture
match:    captur|partial|authori[sz]ed|received|more than
```

A partial capture of 80.00 on a 100.00 authorisation books 100.00 to `psp_receivable` and the merchant's payable; the books overstate cash by 20.00. Proof V477. Fix: post `amount_captured`.

## BR-FR1-a — "Delete my account" hard-deletes the customer's invoices and orders

```defect
id:       BR-FR1-a
file:     apps/api/src/accounts/account-deletion.service.ts
line:     14
severity: critical
command:  /audit-business
class:    BIZ-FR-1
owner:    business
bucket:   report-with-fix
detector: ledger-scan §8
anchor:   await em.nativeDelete(Invoice, { order: { customerId } });
match:    deleteAccount|nativeDelete|delete
match:    invoice|order|record|retention|pseudonym|erase|GDPR|17\(3\)
```

Issued invoices and orders are records of fact the business must keep (10 years per the policy); the self-service deletion erases them. The back office's erasure path shows the correct design (pseudonymise, keep the records). Proof V468 (delete a seeded user: records remain, pseudonymised). Fix: pseudonymise the customer, keep orders and invoices.

## BR-FR1-b — Offboarding drops the tenant schema with its invoices and ledger

```defect
id:       BR-FR1-b
file:     services/backoffice/tenants/offboarding.py
line:     7
severity: critical
command:  /audit-business
class:    BIZ-FR-1
owner:    business
bucket:   report-with-fix
detector: ledger-scan §8
anchor:   cursor.execute(f'DROP SCHEMA "{tenant.schema_name}" CASCADE')
match:    DROP SCHEMA|offboard|tenant
match:    archiv|record|invoice|retention|ledger|erase|before
```

A merchant leaving the platform loses every record of fact the platform must keep for it; nothing archives the financial tables first. Proof V468 (offboard a seeded tenant: an archive holds its records). Fix: export and archive financial records before the drop.

## BR-FR2-a — One two-year TTL purges sessions, orders and invoices alike

```defect
id:       BR-FR2-a
file:     apps/api/src/maintenance/retention.job.ts
line:     6
severity: high
command:  /audit-business
class:    BIZ-FR-2
owner:    business
bucket:   report-with-fix
detector: ledger-scan §9
anchor:   const RETENTION_YEARS = 2;
match:    RETENTION|retention|purge
match:    2 years?|two years|10 years|shorter|minimum|legal|one TTL|invoices|orders
```

The policy keeps orders and invoices 10 years (§ 147 AO for DE books); the weekly job deletes them after 2, with the same period as sessions and audit events. Proof V468 (seeded aged rows per kind). Fix: a period per record kind; records of fact excluded from this purge.

## BR-FR2-b — Back-office invoices are purged after five years

```defect
id:       BR-FR2-b
file:     services/backoffice/maintenance/tasks.py
line:     12
severity: high
command:  /audit-business
class:    BIZ-FR-2
owner:    business
bucket:   report-with-fix
detector: ledger-scan §9
anchor:   cutoff = timezone.now() - timedelta(days=5 * 365)
match:    purge|invoice|cutoff
match:    5 years?|five years|10 years|shorter|minimum|legal|retention
```

Below the declared 10-year retention for invoices of DE sellers. Proof V468. Fix: the declared period, per jurisdiction.

## BR-FR3-a — The append-only wallet ledger copies the customer's e-mail into every row

```defect
id:       BR-FR3-a
file:     apps/api/src/wallets/wallet-transaction.entity.ts
line:     14
severity: high
command:  /audit-business
class:    BIZ-FR-3
owner:    business
bucket:   report-with-fix
detector: ledger-scan §10
anchor:   @Property({ nullable: true }) customerEmail!: string;
match:    customerEmail|customer_email|e-?mail
match:    PII|personal|immutable|append|erasure|pseudonym|ledger
```

`wallet_transactions` is never updated, so an erasure request cannot remove the e-mail without mutating the ledger. Proof V468 (erase a subject: PII gone from mutable tables, ledger intact). Fix: a pseudonymous party id in the ledger; the e-mail in the erasable customer table.

## BR-FR3-b — The legacy "Anonymise customer" action blanks the buyer on issued invoices

```defect
id:       BR-FR3-b
file:     services/backoffice/privacy/anonymise.py
line:     8
severity: high
command:  /audit-business
class:    BIZ-FR-3
owner:    business
bucket:   report-with-fix
detector: ledger-scan §10
anchor:   Invoice.objects.filter(customer_id=customer_id).update(buyer_name="", buyer_address="")
match:    anonymi[sz]e|buyer_name|buyer_address|invoice
match:    issued|legal|required|blank|erase|17\(3\)|snapshot|records? of fact
```

An issued invoice must keep its legally required buyer data (kept under GDPR Art. 17(3)(b)); this admin action erases name and address on every invoice of the customer. The self-service path (`erasure.py`) does it right. Proof V468. Fix: pseudonymise the customer table only.

## BR-DM1-a — A gift card can be spent below zero: no guard, no CHECK, no conditional UPDATE

```defect
id:       BR-DM1-a
file:     apps/api/src/giftcards/gift-card-redeem.repository.ts
line:     11
severity: critical
command:  /audit-business
class:    BIZ-DM-1
owner:    business
bucket:   report-with-fix
detector: ledger-scan §11
anchor:   'update gift_cards set balance_minor = balance_minor - ? where code = ?',
match:    gift.?card|balance_minor|spend
match:    negative|below zero|guard|CHECK|>=|overdraw|nowhere|invariant
```

`gift_cards.balance_minor` has no CHECK, the UPDATE has no `and balance_minor >= ?`, and the row count is not read — the 'balance never negative' invariant is enforced nowhere. Proof V481 (spend more than the balance through the real path → rejected). Fix: conditional UPDATE with the row count checked, plus a CHECK.

## BR-DM1-b — B2B shipments decrement on-hand stock with no guard anywhere

```defect
id:       BR-DM1-b
file:     services/backoffice/inventory/stock.py
line:     8
severity: critical
command:  /audit-business
class:    BIZ-DM-1
owner:    business
bucket:   report-with-fix
detector: ledger-scan §11
anchor:   StockItem.objects.filter(pk=item.pk).update(on_hand=F("on_hand") - qty)
match:    on_hand|stock|ship_b2b
match:    negative|below zero|guard|CHECK|nowhere|invariant|reserved
```

`on_hand` is a plain `IntegerField` with no CheckConstraint, and no path checks it against the quantity or against `reserved`: stock goes negative and reservations exceed what exists. Proof V481. Fix: a conditional update (`on_hand__gte=qty`) and a CHECK.

## BR-DM2-a — The channel import decrements stock around the guard `StockService.take()` enforces

```defect
id:       BR-DM2-a
file:     apps/api/src/inventory/stock-import.job.ts
line:     12
severity: high
command:  /audit-business
class:    BIZ-DM-2
owner:    business
bucket:   report-with-fix
detector: ledger-scan §12
anchor:   await this.em.nativeUpdate(ProductVariant, { sku: row.sku }, { stockOnHand: raw('stock_on_hand - ?', [row.sold]) });
match:    stock|nativeUpdate|import|sold elsewhere
match:    guard|bypass|negative|one (write )?path|StockService|CHECK
```

Checkout refuses to take more than is on hand (`stock.service.ts`); the nightly import subtracts units sold elsewhere with a bulk native update and no guard, and the column has no CHECK. Proof V481 (the violating write through each writer). Fix: the same guard (conditional update) or a CHECK covering every writer.

## BR-DM2-b — Bulk B2B reservations skip `StockItem.reserve()`'s guard

```defect
id:       BR-DM2-b
file:     services/backoffice/inventory/reservations.py
line:     8
severity: high
command:  /audit-business
class:    BIZ-DM-2
owner:    business
bucket:   report-with-fix
detector: ledger-scan §12
anchor:   cursor.execute("update stock_items set reserved = reserved + %s where sku = %s", [qty, sku])
match:    reserv|stock_items|bulk
match:    guard|bypass|on_hand|exceed|one (write )?path|reserve\(\)
```

`reserve()` refuses to reserve more than on hand; the bulk import adds to `reserved` with raw SQL, so reservations exceed stock. Proof V481. Fix: the conditional update (`where on_hand >= reserved + %s`) with the row count read.

## BR-RP1-a — Dashboard revenue sums the order amount once per order line

```defect
id:       BR-RP1-a
file:     apps/api/src/reports/sales-summary.query.ts
line:     14
severity: high
command:  /audit-business
class:    BIZ-RP-1
owner:    business
bucket:   report-with-fix
detector: report-scan §1
anchor:   sum(o.subtotal_minor - coalesce(o.discount_minor, 0)) as revenue
match:    revenue|order_items|join|sales
match:    fan.?out|multipl|double|per (item|line)|grain|join
```

`join order_items` makes one row per line; `sum(o.subtotal_minor …)` then counts a three-line order three times. `count(distinct o.id)` in the same query shows the author knew the grain for the count only. Proof V469 (golden dataset with two lines per order). Fix: pre-aggregate items per order in a CTE (as `cross-sell.query.ts` does).

## BR-RP1-b — The quarterly review annotates two Sums across two to-many joins

```defect
id:       BR-RP1-b
file:     services/backoffice/reports/merchant_report.py
line:     10
severity: high
command:  /audit-business
class:    BIZ-RP-1
owner:    business
bucket:   report-with-fix
detector: report-scan §1
anchor:   ).annotate(revenue=Sum("orders__total_minor"), refunded=Sum("orders__refunds__amount_minor"))
match:    annotate|Sum|revenue|refunded
match:    join|fan.?out|multipl|double|two aggregat|subquery|grain
```

Django joins orders and refunds in one query: every order's total is multiplied by its refund count and every refund by the store's order count. The documented Django pitfall of combining multiple aggregations. Proof V469. Fix: `Subquery` per aggregate.

## BR-RP2-a — The KPI strip's "revenue" includes tax and shipping; the Sales card's excludes them

```defect
id:       BR-RP2-a
file:     apps/api/src/reports/dashboard-kpis.query.ts
line:     12
severity: medium
command:  /audit-business
class:    BIZ-RP-2
owner:    business
bucket:   report-with-fix
detector: report-scan §2
anchor:   sum(total_minor) as revenue,
match:    revenue|total_minor|KPI
match:    gross|net|tax|shipping|definition|two ways|differ|sales-summary
```

`revenue` is defined as net merchandise (excluding tax and shipping, minus refunds); the KPI strip sums `total_minor`, the Sales card (`sales-summary.query.ts`) and the refund rate (`refund-kpis.query.ts`) use net. Two numbers under one label on one dashboard. Proof V470 (both sites over one golden dataset). Fix: one definition, or a different label.

## BR-RP2-b — Finance's refund rate counts orders; the dashboard's divides amounts

```defect
id:       BR-RP2-b
file:     services/backoffice/reports/finance.py
line:     11
severity: medium
command:  /audit-business
class:    BIZ-RP-2
owner:    business
bucket:   report-with-fix
detector: report-scan §2
anchor:   return {"refund_rate": refunded_orders / total_orders if total_orders else 0}
match:    refund_rate|refund rate
match:    count|amount|definition|two ways|differ|orders
```

The definition is refunded amount ÷ revenue (`refund-kpis.query.ts`); the close deck reports refunded orders ÷ orders. Proof V470. Fix: one definition, or a distinct label.

## BR-RP3-a — The expected-payout figure sums failed and test-mode payments

```defect
id:       BR-RP3-a
file:     apps/api/src/reports/payout-forecast.query.ts
line:     11
severity: medium
command:  /audit-business
class:    BIZ-RP-3
owner:    business
bucket:   report-with-fix
detector: report-scan §3
anchor:   `select p.currency, coalesce(sum(p.amount_minor), 0) as expected_minor
match:    payout|forecast|expected|payments
match:    status|failed|test|livemode|exclud|filter|cancel
```

`payments` has `status` and `livemode`; the query filters neither, so a failed card attempt or a test payment raises the merchant's 'expected next payout'. Proof V473 (a golden day with one row of each excluded kind). Fix: captured, live payments only.

## BR-RP3-b — The store leaderboard counts cancelled and soft-deleted orders

```defect
id:       BR-RP3-b
file:     services/backoffice/reports/stores.py
line:     8
severity: medium
command:  /audit-business
class:    BIZ-RP-3
owner:    business
bucket:   report-with-fix
detector: report-scan §3
anchor:   rows = ReportOrder.objects.filter(store_id=store_id, created_at__date__range=(start, end))
match:    store_sales|leaderboard|ReportOrder
match:    cancel|deleted|soft|status|test|exclud|filter|paid
```

`ReportOrder` has `deleted_at` and the orders table a status and `livemode`; the leaderboard filters none of them, and buckets by `created_at` instead of `paid_at`. Proof V473. Fix: the definition's filters.

## BR-RP4-a — Platform GMV adds USD, EUR, SAR, EGP and KWD minor units into one number

```defect
id:       BR-RP4-a
file:     apps/api/src/reports/platform-gmv.query.ts
line:     11
severity: high
command:  /audit-business
class:    BIZ-RP-4
owner:    business
bucket:   report-with-fix
detector: report-scan §4
anchor:   `select sum(o.total_minor) as gmv
match:    gmv|GMV|sum
match:    currenc|USD|EUR|EGP|KWD|mixed|group by
```

The board deck's GMV sums `total_minor` across every store's currency (KWD has three minor digits). The definition says per currency. Proof V472 (golden set with two currencies). Fix: `group by currency`, or convert at each order's pinned rate.

## BR-RP4-b — Treasury's "paid out" sums payouts across currencies

```defect
id:       BR-RP4-b
file:     services/backoffice/reports/payouts_sql.py
line:     7
severity: high
command:  /audit-business
class:    BIZ-RP-4
owner:    business
bucket:   report-with-fix
detector: report-scan §4
anchor:   cursor.execute("SELECT SUM(amount_minor) AS paid_out FROM payouts_payout
match:    paid_out|payout|SUM
match:    currenc|mixed|USD|EGP|group by
```

Payouts are in the merchant's payout currency (EGP or USD); one SUM mixes them. Proof V472. Fix: group by currency.

## BR-RP5-a — The delivery rate is integer division: every carrier scores 0 or 1

```defect
id:       BR-RP5-a
file:     apps/api/src/reports/delivery-kpis.query.ts
line:     12
severity: medium
command:  /audit-business
class:    BIZ-RP-5
owner:    business
bucket:   report-with-fix
detector: report-scan §5
anchor:   sum(case when s.delivered_at is not null then 1 else 0 end) / count(*) as delivery_rate
match:    delivery_rate|delivery rate|count
match:    integer|truncat|cast|numeric|0 or 1|division|nullif|zero
```

Both sides are integers in Postgres, so 97/100 = 0; the scorecard shows 0 % for every carrier that lost one parcel. Proof V469 (golden rows with an odd count). Fix: `::numeric` on the numerator and `nullif(count(*), 0)`.

## BR-RP5-b — Platform AOV is an average of per-store averages

```defect
id:       BR-RP5-b
file:     services/backoffice/reports/aov.py
line:     9
severity: medium
command:  /audit-business
class:    BIZ-RP-5
owner:    business
bucket:   report-with-fix
detector: report-scan §5
anchor:   SELECT AVG(store_avg) FROM (
match:    AVG|average|aov|AOV
match:    average of averages|weight|unweighted|store_avg|per.?store
```

A store with three orders weighs as much as one with thirty thousand; the definition is revenue ÷ paid orders, weighted. Proof V469 (unequal group sizes). Fix: `sum(total) / count(*)` over all orders.

## BR-RP6-a — The merchant statement that drives payouts is never reconciled with the ledger

```defect
id:       BR-RP6-a
file:     apps/api/src/reports/merchant-statement.query.ts
line:     15
severity: medium
command:  /audit-business
class:    BIZ-RP-6
owner:    business
bucket:   report-with-fix
detector: report-scan §6
anchor:   sum(o.total_minor - o.commission_minor - o.fee_minor) as payable_minor
match:    statement|payable
match:    reconcil|ledger|books|merchant_payable|compare|never
```

The policy says the statement is reconciled against the ledger's `merchant_payable` before payout; nothing in the repo compares the two, and the statement is recomputed from orders (refunds, adjustments and the platform-fee run are invisible to it). Proof V470 (the statement over a golden day equals the books). Fix: a reconciliation test or job that blocks the payout run on a difference.

## BR-RP6-b — The commission CSV finance imports is never compared with the ledger

```defect
id:       BR-RP6-b
file:     services/backoffice/reports/commission_export.py
line:     10
severity: medium
command:  /audit-business
class:    BIZ-RP-6
owner:    business
bucket:   report-flagged
detector: report-scan §6
anchor:   "SELECT store_id, currency, SUM(commission_minor) AS commission FROM orders "
match:    commission|export|CSV
match:    reconcil|ledger|books|accounting|compare|never
```

The export reads `orders.commission_minor`; the books hold the commission the API actually booked (rounded by a different policy, BR-MP1-a). Nothing reconciles them. Proof V470. Flagged: the accounting system on the other end is outside the repo.

## BR-RP7-a — "Orders confirmed in the month" reads today's status over `created_at`

```defect
id:       BR-RP7-a
file:     apps/api/src/reports/confirmed-orders.query.ts
line:     13
severity: medium
command:  /audit-business
class:    BIZ-RP-7
owner:    business
bucket:   report-with-fix
detector: report-scan §7
anchor:   where store_id = ? and status = 'paid' and livemode
match:    confirmed|status
match:    current status|confirmed_at|paid_at|stamp|event|changes later|recogni|created_at
```

An order confirmed in March and shipped in April leaves `paid`, so March's figure drops in April; the schema stamps `confirmed_at` and `paid_at`. Proof V470 (change a row's status after the period closes: the figure does not move). Fix: filter on the event's timestamp.

## BR-RP7-b — "Deliveries completed in the month" counts by creation date and current status

```defect
id:       BR-RP7-b
file:     services/backoffice/reports/deliveries.py
line:     6
severity: medium
command:  /audit-business
class:    BIZ-RP-7
owner:    business
bucket:   report-with-fix
detector: report-scan §7
anchor:   return Shipment.objects.filter(status='delivered', created_at__gte=month_start, created_at__lt=month_end).count()
match:    deliver|Shipment
match:    delivered_at|created_at|current status|stamp|event|returned|month
```

A parcel created in March and delivered in April counts in March; one delivered then returned disappears. `delivered_at` exists. Proof V470. Fix: `delivered_at` in the month.

## BR-BT1-a — "Sales by day" buckets in the database session zone

```defect
id:       BR-BT1-a
file:     apps/api/src/reports/daily-sales.query.ts
line:     11
severity: medium
command:  /audit-business
class:    BIZ-BT-1
owner:    business
bucket:   report-with-fix
detector: report-scan §8
anchor:   `select to_char(o.paid_at, 'YYYY-MM-DD') as day, o.currency, count(*) as orders
match:    to_char|day|daily
match:    zone|session|UTC|store.?s|business day|local|23:
```

The store's business day is in its zone (`stores.timezone`); `to_char(paid_at, …)` uses the session zone (UTC), while `store-day.query.ts` buckets the same orders in the store's zone and the ops chart in literal UTC. An order paid at 23:40 in Berlin lands on the next day here (see `golden/report-daily-sales-2026-03-02.csv`). Proof V471. Fix: `(paid_at at time zone $zone)::date`.

## BR-BT1-b — The back-office daily chart truncates in `TIME_ZONE = "UTC"`

```defect
id:       BR-BT1-b
file:     services/backoffice/reports/daily.py
line:     11
severity: medium
command:  /audit-business
class:    BIZ-BT-1
owner:    business
bucket:   report-with-fix
detector: report-scan §8
anchor:   .annotate(day=TruncDate("paid_at"))
match:    TruncDate|day|daily
match:    zone|UTC|tzinfo|store|business day|local
```

`TruncDate` without `tzinfo` uses the current time zone (UTC); `refunds_by_day.py` passes the store's zone. Account managers see different days than the merchant. Proof V471. Fix: `TruncDate('paid_at', tzinfo=ZoneInfo(store.timezone))`.

## BR-BT2-a — Settlement T+2 counts a Saturday–Sunday weekend for a Cairo bank, with no holidays

```defect
id:       BR-BT2-a
file:     apps/api/src/payouts/settlement-date.ts
line:     10
severity: medium
command:  /audit-business
class:    BIZ-BT-2
owner:    business
bucket:   report-flagged
detector: report-scan §9
anchor:   if (d.getUTCDay() !== 0 && d.getUTCDay() !== 6) added++;
match:    getUTCDay|settlement|business day
match:    weekend|Friday|Saturday|Sunday|holiday|calendar|Cairo
```

The policy names the settlement bank's calendar (Egypt: Friday–Saturday weekend); this counts Friday as a business day and Sunday as weekend, and ignores holidays, so 'available on' dates are wrong around every weekend. Proof V479 (decision table across a weekend and a holiday). Flagged: the bank's calendar is the authority.

## BR-BT2-b — Value dates use a Saturday–Sunday weekend and a literal 2026 holiday list

```defect
id:       BR-BT2-b
file:     services/backoffice/payouts/calendar.py
line:     12
severity: medium
command:  /audit-business
class:    BIZ-BT-2
owner:    business
bucket:   report-flagged
detector: report-scan §9
anchor:   while day.weekday() >= 5 or day.isoformat() in BANK_HOLIDAYS:
match:    weekday|BANK_HOLIDAYS|value date|calendar
match:    weekend|Friday|Saturday|Sunday|holiday|literal|owner|maintain
```

Same wrong weekend for Cairo, and `BANK_HOLIDAYS` is a hard-coded list for one year with no owner — it is empty for 2027. `sla/due_dates.py` shows the maintained-calendar shape. Proof V479. Flagged: the bank's calendar decides.

## BR-LC1-a — `awaiting_review` is declared, accepted by the DB CHECK and shown as a board column — nothing ever writes it

```defect
id:       BR-LC1-a
file:     apps/api/src/orders/order-status.ts
line:     10
severity: medium
command:  /audit-business
class:    BIZ-LC-1
owner:    business
bucket:   report-with-fix
detector: lifecycle-scan §1
anchor:     'awaiting_review',
match:    awaiting_review|awaiting review
match:    unreachable|never (written|reached|a target)|no (write|edge)|stale|dead|board|review column
```

No transition-table row, write or default reaches it; `orders-board.ts` still gives it a 'review' column that is always empty, and the CHECK in `0001_core.sql` accepts it. Proof V474 (declared minus reachable is empty or the documented legacy list). Fix: remove it, or build the review step that writes it.

## BR-LC1-b — Payout `on_hold` is filtered on and badged, but nothing can put a payout on hold

```defect
id:       BR-LC1-b
file:     services/backoffice/payouts/models.py
line:     7
severity: medium
command:  /audit-business
class:    BIZ-LC-1
owner:    business
bucket:   report-with-fix
detector: lifecycle-scan §1
anchor:   ON_HOLD = "on_hold", "On hold"
match:    on_hold|ON_HOLD|on hold
match:    unreachable|never (written|reached|set)|no (write|edge)|stale|dead|filter|badge
```

`PAYOUT_TRANSITIONS` has no edge into it and no code writes it; the admin's 'needs attention' filter and badge (`admin_filters.py`) promise a risk-hold flow that does not exist. Proof V474. Fix: build the hold edge from `processing` (and its release), or drop the state.

## BR-LC2-a — `disputed` is reachable from `paid` and has no row in either table: a disputed order is stuck forever

```defect
id:       BR-LC2-a
file:     apps/api/src/orders/order-status.ts
line:     17
severity: high
command:  /audit-business
class:    BIZ-LC-2
owner:    business
bucket:   report-with-fix
detector: lifecycle-scan §2
anchor:   paid: ['fulfilling', 'cancelled', 'disputed'],
match:    disputed|dispute
match:    trap|stuck|no (way out|outgoing|row)|cannot (move|leave)|dead.?end
```

`setStatus()` allows an edge only when `ORDER_TRANSITIONS` or `ORDER_REVERSALS` lists it; `disputed` has no row, so a won dispute can never return the order to `paid` (the declared flow has `disputed -> paid`). Proof V474 (reachability from the initial state: every non-terminal state reaches a terminal one). Fix: `disputed: ['paid', 'refunded']`.

## BR-LC2-b — An enterprise subscription can never end: `cancel()` pauses it

```defect
id:       BR-LC2-b
file:     services/backoffice/billing/models.py
line:     5
severity: high
command:  /audit-business
class:    BIZ-LC-2
owner:    business
bucket:   report-flagged
detector: lifecycle-scan §2
anchor:   class SubscriptionStatus(models.TextChoices):
match:    SubscriptionStatus|subscription|cancel
match:    no terminal|never ends|paus|cancelled state|terminal
```

Every state has an outgoing edge and `cancel` targets `paused`; there is no terminal state, so cancelled customers stay in renewal queries and in MRR, and the declared lifecycle's `cancelled` does not exist. Proof V474. Flagged: whether a cancelled plan may be resumed is the business's call; a terminal `cancelled` is still missing.

## BR-LC3-a — The declared return flow (`delivered → return_requested → refunded`) is not built

```defect
id:       BR-LC3-a
file:     ai/business-flows.md
line:     9
severity: medium
command:  /audit-business
class:    BIZ-LC-3
owner:    business
bucket:   report-flagged
detector: lifecycle-scan §3
anchor:   - delivered -> return_requested -> refunded
match:    return_requested|return|business-flows
match:    declared|(?:not|n.t) built|missing|no (state|edge)|lifecycle
```

The code has no `return_requested` state; a delivered order goes straight to `refunded` through the reversal table, so no return is ever recorded before money goes back. Proof V474 (the graph diff against the declared edges). Flagged: build the step or update the declared lifecycle — a product decision.

## BR-LC3-b — The back office can void an issued invoice; the declared lifecycle allows void from draft only

```defect
id:       BR-LC3-b
file:     services/backoffice/invoicing/models.py
line:     41
severity: medium
command:  /audit-business
class:    BIZ-LC-3
owner:    business
bucket:   report-with-fix
detector: lifecycle-scan §3
anchor:   @transition(field=status, source=InvoiceStatus.ISSUED, target=InvoiceStatus.VOID)
match:    void|void_issued|transition
match:    not declared|issued|declared|credit note|forbid|lifecycle
```

`void_issued` adds `issued → void` (the docstring: a wrong invoice disappears); the declared invoice lifecycle corrects an issued invoice by a credit note (`issued → credited`). An issued document should not vanish. Proof V474. Fix: remove the edge; correct by credit note.

## BR-LC4-a — The payment is flushed `captured` before the order becomes `paid`, in a separate transaction

```defect
id:       BR-LC4-a
file:     apps/api/src/payments/payment-capture.service.ts
line:     20
severity: high
command:  /audit-business
class:    BIZ-LC-4
owner:    business
bucket:   report-with-fix
detector: lifecycle-scan §4
anchor:   order.status = 'paid';
match:    paid|captured|payment|order
match:    two (flush|transaction)|transaction|crash|between|disagree|cross.?aggregate|both
```

A crash, a timeout in `onCaptured` or a deploy between the two flushes leaves the payment captured and the order `pending_payment`; a retry of the webhook returns early (`payment.status !== Pending`), so the order is never paid. Nothing sweeps for the pair. Proof V475 (model-based run with a crash between the writes; invariant on the pair). Fix: one transaction for both, or an outbox step the order consumes idempotently.

## BR-LC4-b — A paid payout and its settlement are saved in two transactions

```defect
id:       BR-LC4-b
file:     services/backoffice/payouts/settle.py
line:     13
severity: high
command:  /audit-business
class:    BIZ-LC-4
owner:    business
bucket:   report-with-fix
detector: lifecycle-scan §4
anchor:   settlement.status = SettlementStatus.SETTLED
match:    settle|settlement|payout
match:    atomic|transaction|two (save|write)s?|crash|between|disagree|both
```

`payout.save()` and `settlement.save()` run without `transaction.atomic()`; a failure between them leaves a payout `paid` with its settlement `open`, and the next settlement run pays it again. Proof V475. Fix: one atomic block.

## BR-LC5-a — The Stripe endpoint is subscribed to four event types and handles one

```defect
id:       BR-LC5-a
file:     apps/api/src/payments/stripe-webhook.handler.ts
line:     14
severity: high
command:  /audit-business
class:    BIZ-LC-5
owner:    business
bucket:   report-with-fix
detector: lifecycle-scan §5
anchor:   case 'payment_intent.succeeded':
match:    payment_intent|webhook|payment_failed|charge\.refunded|event
match:    unhandled|no case|subscribed|ignored|falls through|default|stuck|pending
```

`infra/stripe/webhook-endpoint.json` subscribes to `payment_intent.payment_failed`, `payment_intent.canceled` and `charge.refunded` too; the switch's `default: return` drops them silently, so failed payments stay `pending` forever and refunds never reach the payment row. The graph agrees: payment `failed` and `refunded` are unreachable and `captured` is a trap. Proof V476 (replay a recorded sequence duplicated and shuffled). Fix: handle each subscribed type or list it in an ignore list.

## BR-LC5-b — Carrier scans overwrite the shipment status with no graph check

```defect
id:       BR-LC5-b
file:     services/backoffice/shipping/carrier_webhooks.py
line:     15
severity: high
command:  /audit-business
class:    BIZ-LC-5
owner:    business
bucket:   report-with-fix
detector: lifecycle-scan §5
anchor:   shipment.status = CARRIER_STATUS_MAP[payload["status"]]
match:    CARRIER_STATUS_MAP|carrier|tracking|status
match:    late|out of order|regress|monoton|overwrite|delivered|graph|KeyError|unmapped
```

A late `HUB_SCAN` after `DELIVERED` moves a delivered parcel back to `in_transit`; an unmapped code raises `KeyError` and the courier retries forever. Proof V476 (replay real scans shuffled: final state unchanged, every edge in the graph). Fix: apply the mapped state only when the graph allows the edge; list ignored codes.

## BR-LC6-a — The support "mark delivered" tool moves the order without a history row

```defect
id:       BR-LC6-a
file:     apps/api/src/admin/order-repair.controller.ts
line:     14
severity: medium
command:  /audit-business
class:    BIZ-LC-6
owner:    business
bucket:   report-with-fix
detector: lifecycle-scan §6
anchor:   order.status = 'delivered';
match:    mark.?delivered|repair|delivered
match:    history|audit|actor|setStatus|who|no record
```

Every other order transition goes through `OrderStatusService.setStatus()`, which writes `order_status_history` with the actor; this support endpoint writes the column directly, so a delivery confirmed by phone leaves no record of who did it. Proof V482 (one history row per transition). Fix: call `setStatus(order, 'delivered', agent)`.

## BR-LC6-b — KYC approval records no reviewer and no history

```defect
id:       BR-LC6-b
file:     services/backoffice/merchants/kyc.py
line:     9
severity: medium
command:  /audit-business
class:    BIZ-LC-6
owner:    business
bucket:   report-with-fix
detector: lifecycle-scan §6
anchor:   merchant.kyc_status = KycStatus.APPROVED
match:    kyc|approve|KycStatus
match:    history|audit|reviewer|who|no record|trail
```

`reviewer` is passed in and dropped; approving a merchant for payouts is a compliance decision with no trail of who made it or when. Proof V482. Fix: a `KycDecision` row (reviewer, from, to, at) in the same transaction.

## BR-CY1-a — Team invites can be sent and never revoked

```defect
id:       BR-CY1-a
file:     apps/api/src/team/invites.controller.ts
line:     13
severity: high
command:  /audit-business
class:    BIZ-CY-1
owner:    business
bucket:   report-with-fix
detector: check-business-coverage §1
anchor:   @Post()
match:    invite
match:    revoke|cancel|delete|inverse|no way to (undo|withdraw)|pending
```

`POST team/invites` has no revoke, cancel or delete under the resource; the Team page lists pending invites with no action, so an invite sent to the wrong address stays valid until accepted. Proof V478 (route-pair diff, then forward → inverse end to end). Fix: `POST team/invites/:id/revoke` and a row action.

## BR-CY1-b — A store can connect its own courier account and never disconnect it

```defect
id:       BR-CY1-b
file:     apps/api/src/stores/carrier-connections.controller.ts
line:     11
severity: high
command:  /audit-business
class:    BIZ-CY-1
owner:    business
bucket:   report-with-fix
detector: check-business-coverage §1
anchor:   @Post('connect')
match:    carrier|connect
match:    disconnect|unlink|revoke|remove|inverse|API key
```

`POST stores/:storeId/carriers/connect` stores the merchant's carrier API key; there is no disconnect, so a rotated or compromised key cannot be removed by the merchant. Proof V478. Fix: `POST …/carriers/:id/disconnect` (and the UI entry point).

## BR-CY2-a — Sales-channel integrations can be disconnected by the API only

```defect
id:       BR-CY2-a
file:     apps/api/src/stores/integrations.controller.ts
line:     16
severity: high
command:  /audit-business
class:    BIZ-CY-2
owner:    business
bucket:   report-with-fix
detector: check-business-coverage §2
anchor:   @Post(':integrationId/disconnect')
match:    integration|disconnect|channel
match:    UI|screen|page|client|entry point|no button|API.?only
```

`IntegrationsPage` offers 'Connect a marketplace'; nothing in the web app calls `…/integrations/:id/disconnect`, so the merchant who connected a channel cannot disconnect it. Proof V478 (UI test as the forward's role). Fix: a Disconnect action on the page.

## BR-CY2-b — API keys can be revoked by the API only; the keys page cannot

```defect
id:       BR-CY2-b
file:     apps/api/src/api-keys/api-keys.controller.ts
line:     16
severity: high
command:  /audit-business
class:    BIZ-CY-2
owner:    business
bucket:   report-with-fix
detector: check-business-coverage §2
anchor:   @Post(':id/revoke')
match:    api.?key|revoke
match:    UI|screen|page|client|entry point|no button|API.?only
```

`ApiKeysPage` lists and creates keys; no client code calls `api-keys/:id/revoke`. A leaked key cannot be revoked by its owner. Proof V478. Fix: a Revoke action per key.

## BR-CY3-a — The verification e-mail is sent once and cannot be re-sent

```defect
id:       BR-CY3-a
file:     apps/api/src/auth/signup.service.ts
line:     13
severity: medium
command:  /audit-business
class:    BIZ-CY-3
owner:    business
bucket:   report-with-fix
detector: check-business-coverage §3
anchor:   await this.mailer.sendVerificationEmail(email, token);
match:    verif|sendVerificationEmail|sign.?up
match:    resend|re-?send|again|lost|not (received|delivered)
```

A merchant whose verification mail bounced or expired cannot take payments and has no resend path; the only option is signing up again with another address. Proof V478 (send, simulate non-delivery, resend). Fix: a rate-limited resend route and link.

## BR-CY3-b — The back-office export starts a job and returns no job id or status

```defect
id:       BR-CY3-b
file:     services/backoffice/reports/views.py
line:     13
severity: medium
command:  /audit-business
class:    BIZ-CY-3
owner:    business
bucket:   report-with-fix
detector: check-business-coverage §3
anchor:   generate_report.apply_async(args=[merchant.id], kwargs={"kind": "orders_export"})
match:    export|apply_async|orders_export
match:    status|job id|poll|track|notif|being prepared|no way
```

The account manager gets 'Your export is being prepared' and no way to see progress, failure or the file (the API's own exports return an id and a status route). Proof V478. Fix: return the job id and a status endpoint.

## BR-CY4-a — The newsletter is sent without the one-click unsubscribe headers

```defect
id:       BR-CY4-a
file:     apps/api/src/marketing/newsletter.sender.ts
line:     11
severity: high
command:  /audit-business
class:    BIZ-CY-4
owner:    business
bucket:   report-with-fix
detector: check-business-coverage §4
anchor:   await this.transporter.sendMail({ from: 'news@fernhollow.example', to, subject, html });
match:    newsletter|sendMail|campaign
match:    List-Unsubscribe|unsubscribe|one.?click|RFC ?8058
```

Marketing mail with no `List-Unsubscribe` / `List-Unsubscribe-Post: List-Unsubscribe=One-Click` pair (RFC 8058) and no unsubscribe endpoint anywhere. Proof V483 (capture a raw message from the real sender; assert both headers). Fix: the header pair and a POST endpoint that works without a login.

## BR-CY4-b — Back-office promotional campaigns carry no unsubscribe headers

```defect
id:       BR-CY4-b
file:     services/backoffice/marketing/campaigns.py
line:     11
severity: high
command:  /audit-business
class:    BIZ-CY-4
owner:    business
bucket:   report-with-fix
detector: check-business-coverage §4
anchor:   msg = EmailMessage(subject=campaign.subject, body=campaign.html, to=[customer.email], connection=connection)
match:    campaign|EmailMessage|promotional
match:    List-Unsubscribe|unsubscribe|one.?click|RFC ?8058|headers
```

`EmailMessage(..., headers=None)`: no RFC 8058 pair, and opting out requires the customer to log in to the store. Proof V483. Fix: per-recipient `headers={...}` and an unauthenticated one-click endpoint.

## BR-CY5-a — Closing an account is a support ticket, not a web action

```defect
id:       BR-CY5-a
file:     apps/web/src/features/account/AccountSettingsPage.tsx
line:     7
severity: high
command:  /audit-business
class:    BIZ-CY-5
owner:    business
bucket:   report-flagged
detector: check-business-coverage §5
anchor:   Want to leave? <a href="/help/close-account">Contact support to close your account</a>.
match:    close.?account|account|support
match:    delet|erase|self.?serv|support.?only|GDPR|Art\.? ?17|web path
```

The account page sends the user to a help article; the API's `deleteAccount` exists (and erases too much — BR-FR1-a) but no web route or screen calls it. Proof V484 (request deletion end to end). Flagged: the jurisdiction (GDPR Art. 17 for EU customers) is the policy's.

## BR-CY5-b — The privacy endpoint erases but has no data export

```defect
id:       BR-CY5-b
file:     services/backoffice/privacy/views.py
line:     9
severity: high
command:  /audit-business
class:    BIZ-CY-5
owner:    business
bucket:   report-with-fix
detector: check-business-coverage §5
anchor:   class GdprRequestViewSet(viewsets.ViewSet):
match:    Gdpr|privacy|export
match:    export|portab|Art\.? ?20|download|data copy|missing
```

`erase-me` exists; there is no export of the customer's data in a machine-readable form (GDPR Art. 20). Proof V484. Fix: an export action that produces the customer's records.

## BR-CY6-a — A declined renewal leaves the merchant `past_due` with "contact support" as the only way out

```defect
id:       BR-CY6-a
file:     apps/api/src/subscriptions/subscription-payments.service.ts
line:     17
severity: medium
command:  /audit-business
class:    BIZ-CY-6
owner:    business
bucket:   report-flagged
detector: check-business-coverage §6
anchor:   throw new PaymentRequiredException('Declined card: contact support to update your billing details');
match:    declin|card|renewal|billing
match:    dead.?end|support|update (the )?(card|payment method)|retry|recover|no (way|path)
```

There is no route to update the stored payment method or retry the charge; the merchant must open a ticket. Proof V478 (decline the test card, assert a recovery action completes). Flagged: the screen is confirmed only by the walk lane (`--live`).

## BR-CY6-b — An expired phone code ends onboarding: there is no "send a new code"

```defect
id:       BR-CY6-b
file:     services/backoffice/merchants/onboarding.py
line:     11
severity: medium
command:  /audit-business
class:    BIZ-CY-6
owner:    business
bucket:   report-with-fix
detector: check-business-coverage §6
anchor:   raise ValidationError("Expired verification code. Please contact support.")
match:    expired|verification code|otp|phone
match:    dead.?end|support|request (a )?new|resend|recover|no (way|path)
```

The OTP is sent once at sign-up; when it expires the merchant can only contact support. Proof V478. Fix: a request-new-code path.

## Routed rows — scored only under their owner

Each is listed by `/audit-business` as `→ <owner pack> <skill> §n` (or `(owner pack <x> not installed)`) and never graded there; an `/audit-business` finding on one is UNMATCHED, not credited.

## BR-HO-CQ-a — Imported order totals go through `parseFloat(...) * 100`

```defect
id:       BR-HO-CQ-a
file:     apps/api/src/orders/order-import.ts
line:     17
severity: medium
command:  /quality-audit
class:    CQ §4 float money
owner:    code-quality
bucket:   routed
detector: code-quality correctness-smell-scan §4 (routed from pricing-rule-scan §2)
anchor:   const totalMinor = Math.round(parseFloat(row.total) * 100);
match:    parseFloat|import|total
match:    float|parseFloat|binary|precision|\* ?100|exponent|KWD
```

Float arithmetic on money and a hard-coded two-digit exponent (a KWD total loses its third digit). The arithmetic is code-quality's; `/audit-business` lists it as `pricing-rule-scan` §2 corroboration (2c prints it) and never grades it.

## BR-HO-CQ-b — The processor fee is computed in floats and truncated with `int()`

```defect
id:       BR-HO-CQ-b
file:     services/backoffice/payouts/psp_fees.py
line:     5
severity: medium
command:  /quality-audit
class:    CQ §4 float money
owner:    code-quality
bucket:   routed
detector: code-quality correctness-smell-scan §4
anchor:   fee = float(order.total_minor) / 100 * 0.029 + 0.30
match:    psp|fee|float
match:    float|precision|binary|int\(|truncat
```

`float` money and `int(fee * 100)` truncation (not rounding). Code-quality's class; business lists it, never grades it.

## BR-HO-CQ-c — A date-only campaign start is parsed with `new Date('YYYY-MM-DD')` (midnight UTC)

```defect
id:       BR-HO-CQ-c
file:     apps/api/src/promotions/campaign-window.ts
line:     8
severity: medium
command:  /quality-audit
class:    CQ §6 calendar arithmetic
owner:    code-quality
bucket:   routed
detector: code-quality correctness-smell-scan §6 (routed from pricing-rule-scan §8)
anchor:   const startsAt = new Date(dto.startsOn);
match:    startsOn|startsAt|campaign|new Date
match:    UTC|midnight|date-?only|local|parse|zone
```

And `endsAt` parses a local-time string in the server's zone. Calendar parsing is code-quality §6; the zone rule it should obey is `pricing-rule-scan` §8's policy row.

## BR-HO-CQ-d — The payouts screen previews commission with its own 8 % copy of the rule

```defect
id:       BR-HO-CQ-d
file:     apps/web/src/features/payouts/commission.ts
line:     2
severity: medium
command:  /quality-audit
class:    CQ divergent copy
owner:    code-quality
bucket:   routed
detector: code-quality duplication-scan (divergent copy of the commission rule)
anchor:   const COMMISSION_RATE = 0.08;
match:    commission|COMMISSION_RATE|0\.08
match:    duplicat|copy|diverg|rateBp|per.?store|hard.?coded|differ
```

The API computes commission per store (`rule.rateBp`, `commission.calculator.ts`); the web copy hard-codes 8 % and rounds with `Math.round`. Divergent copies of one rule are code-quality's.

## BR-HO-DB-a — Deleting a customer cascades into their invoices

```defect
id:       BR-HO-DB-a
file:     apps/api/migrations/0001_core.sql
line:     80
severity: high
command:  /db-audit
class:    DB §2 cascade into records of fact
owner:    database
bucket:   routed
detector: database schema-integrity-scan §2 (routed from ledger-scan §8)
anchor:   customer_id text not null references customers(id) on delete cascade,
match:    cascade|invoices|customer_id
match:    cascade|delete|records? of fact|retention|invoice
```

`on delete cascade` from `customers` to `invoices`. The FK mechanics are database §2's; `ledger-scan` §8 owns the application deletion flows (BR-FR1-a) and lists this as corroboration.

## BR-HO-DB-b — Payout fees are stored in a `double precision` column

```defect
id:       BR-HO-DB-b
file:     apps/api/migrations/0005_payouts.sql
line:     6
severity: medium
command:  /db-audit
class:    DB §4 float money column
owner:    database
bucket:   routed
detector: database schema-integrity-scan §4
anchor:   fee_amount double precision not null default 0,
match:    fee_amount|double precision|payouts
match:    float|double|precision|money|numeric|bigint
```

Money in a binary float column. Database §4's class.

## BR-HO-DB-c — Legal invoice numbers come from a sequence (gaps on every rollback)

```defect
id:       BR-HO-DB-c
file:     apps/api/migrations/0001_core.sql
line:     81
severity: high
command:  /db-audit
class:    DB §11 gapless number from a sequence
owner:    database
bucket:   routed
detector: database schema-integrity-scan §11 (jurisdiction fact from tax-invoice-scan)
anchor:   number bigint not null default nextval('invoice_number_seq'),
match:    invoice_number_seq|nextval|invoice number|number
match:    gap|sequence|consecutive|gapless|rollback|nextval
```

A sequence skips values on rollback; whether the jurisdiction requires consecutive numbering is the fact `tax-invoice-scan` supplies. The shape is database §11's.

## BR-HO-SEC-a — Checkout takes each line's unit price from the request body

```defect
id:       BR-HO-SEC-a
file:     apps/api/src/checkout/checkout.service.ts
line:     25
severity: critical
command:  /security-audit
class:    SEC §1 client-trusted price
owner:    security
bucket:   routed
detector: security logic-race-scan §1 (routed from pricing-rule-scan)
anchor:   unitPriceMinor: item.unitPriceMinor,
match:    unitPriceMinor|price|checkout|items
match:    client|request|body|trust|tamper|catalog|server.?side
```

`dto.items[].unitPriceMinor` is stored on the order line and charged; the catalog price is never read. A client-chosen price is security's class.

## BR-HO-SEC-b — A single-use coupon is checked, then incremented: two concurrent orders both redeem it

```defect
id:       BR-HO-SEC-b
file:     apps/api/src/promotions/coupon-redemption.service.ts
line:     13
severity: high
command:  /security-audit
class:    SEC §6 single-use coupon race
owner:    security
bucket:   routed
detector: security logic-race-scan §6
anchor:   coupon.redemptions += 1;
match:    coupon|redemption|redeem
match:    race|concurren|check.?then|atomic|single.?use|twice|TOCTOU
```

Read-check-write with no lock or conditional update. Security §6's class; pricing lists it as corroboration.

## BR-HO-SEC-c — The refund route has no idempotency key

```defect
id:       BR-HO-SEC-c
file:     apps/api/src/refunds/refunds.controller.ts
line:     8
severity: high
command:  /security-audit
class:    SEC §4 Idempotency-Key on a money route
owner:    security
bucket:   routed
detector: security logic-race-scan §4
anchor:   @Post()
match:    refund
match:    idempot|Idempotency-Key|retry|duplicate|twice|replay
```

A retried `POST orders/:orderId/refunds` refunds twice. Idempotency on money routes is security §4's; the refund arithmetic is `pricing-rule-scan` §9's (BR-PR6-a).

## BR-HO-BE-a — Cancelling an in-transit shipment is silently ignored by XState, and the shipping fee is refunded anyway

```defect
id:       BR-HO-BE-a
file:     apps/api/src/shipping/shipments.service.ts
line:     13
severity: high
command:  /backend-audit
class:    ST §1 FSM swallows an illegal event
owner:    backend
bucket:   routed
detector: backend state-transition-scan §1 (reads lifecycle-scan's graph)
anchor:   actor.send({ type: 'CANCEL' });
match:    CANCEL|actor\.send|shipment|cancel
match:    ignor|swallow|silent|in_transit|not (handled|allowed)|xstate|refund
```

`in_transit` has no `CANCEL` event; XState v5 drops it without error, and the next line refunds the fee. Library semantics are backend `state-transition-scan` §1's; `lifecycle-scan` supplies the graph (the TS shipment machine) and lists the row.

## BR-HO-BE-b — The payout API serialises the amount as a float

```defect
id:       BR-HO-BE-b
file:     services/backoffice/payouts/serializers.py
line:     7
severity: medium
command:  /backend-audit
class:    WF §1 money as a JSON float
owner:    backend
bucket:   routed
detector: backend wire-format-scan §1
anchor:   amount = serializers.FloatField(source="amount_major")
match:    FloatField|amount|serializer
match:    float|JSON|wire|decimal|precision|DecimalField
```

Decimal money leaves as a JSON float. Wire format is backend `wire-format-scan`'s.

## Decoys — must NOT be reported

Each mirrors a precedent in `templates/snippets/precedents/business.md` (the class line names it) or a measured real-repo shape (eval § 3.2); reporting one is a false positive in every run its `command:` names.

```decoy
id:       BR-DECOY-01
file:     apps/api/src/payouts/fee-schedule.entity.ts
line:     11
command:  /audit-business /quality-audit /backend-audit
class:    decoy/MP-1 (precedents/business.md § 1)
anchor:   feeRate!: string;
match:    feeRate|string|decimal|numeric
match:    string|float|type|parse|Number
```

`numeric` read back as a string (node-postgres / MikroORM `decimal`) is correct; `FeeService` wraps it in `Decimal` before any arithmetic.

```decoy
id:       BR-DECOY-02
file:     apps/api/src/money/money-policy.ts
line:     6
command:  /audit-business
class:    decoy/MP-1 (§ 2)
anchor:   export function roundHalfAwayFromZero(value: number): number {
match:    roundHalfAwayFromZero|half away|rounding
match:    half.?even|banker|not half.?even|mode|policy
```

A declared mode other than half-even, applied by the one money module the API imports, is the policy (ADR-0004), not a defect.

```decoy
id:       BR-DECOY-03
file:     services/backoffice/money/policy.py
line:     12
command:  /audit-business
class:    decoy/MP-1 (§ 2)
anchor:   return int(value.quantize(UNIT, rounding=ROUND_HALF_UP))
match:    ROUND_HALF_UP|quantize|to_minor
match:    half.?up|half.?even|mode|differ|policy
```

Python's `ROUND_HALF_UP` rounds ties away from zero — the same rule as the API's helper; one declared policy in two languages.

```decoy
id:       BR-DECOY-04
file:     apps/api/src/pos/pos-tax.ts
line:     45
command:  /audit-business
class:    decoy/TX-4 (§ 3)
anchor:   const taxMinor = lines.reduce((s, l) => s + (l.taxMinor ?? 0), 0);
match:    taxMinor|reduce|receipt
match:    per.?line|rounding level|Σ|sum|document
```

Per-line rounding, declared in the tax policy, with the receipt totals summed from the same rounded lines the receipt lists: a national rounding choice, not TX-4.

```decoy
id:       BR-DECOY-05
file:     services/backoffice/invoicing/peppol.py
line:     16
command:  /audit-business
class:    decoy/TX-4 (§ 3, EN 16931)
anchor:   return (line.unit_price * line.quantity).quantize(CENT, rounding=ROUND_HALF_UP)
match:    line_net|quantize|Peppol|per.?line
match:    per.?line|rounding|BR-CO|sum|level
```

EN 16931 line net amounts rounded per line, with BT-106/BT-116 summed from those rounded amounts and category VAT computed once: BR-CO-10 and BR-CO-17 hold, and CI validates the output.

```decoy
id:       BR-DECOY-06
file:     apps/api/src/pos/pos-tax.ts
line:     8
command:  /audit-business
class:    decoy/TX-1 (§ 7)
anchor:   export const POS_VAT_RATE_BP = 1500;
match:    POS_VAT_RATE|1500|rate
match:    hard.?coded|constant|literal|effective|tax point
```

A hard-coded rate in a single-jurisdiction (KSA, SAR-only) POS, effective-dated in `POS_VAT_RATES` and persisted on every receipt line.

```decoy
id:       BR-DECOY-07
file:     apps/api/src/pos/pos-tax.ts
line:     39
command:  /audit-business
class:    decoy/TX-2 (eval § 3.2, the real repo's carve-out)
anchor:   ? roundHalfAwayFromZero((baseMinor * bp) / (10_000 + bp))
match:    inclusive|carve|baseMinor|10_000 \+ bp
match:    inclusive|twice|base|discount|gross
```

Tax carved out of an inclusive price (`base × bp / (10000 + bp)`) on the discounted base, never added: the correct TX-2/TX-3 shape.

```decoy
id:       BR-DECOY-08
file:     apps/api/migrations/0002_ledger.sql
line:     38
command:  /audit-business
class:    decoy/LG-1 (§ 10)
anchor:   create constraint trigger gl_journal_lines_entry_balances
match:    trigger|gl_journal_lines|balanc
match:    balanc|unbalanced|bypass|raw|deferred
```

A deferred constraint trigger sums every touched GL entry per currency at COMMIT: LG-1 is Traced for every GL writer, the raw-SQL payment and refund postings included.

```decoy
id:       BR-DECOY-09
file:     apps/api/src/accounting/journal-reversal.service.ts
line:     17
command:  /audit-business
class:    decoy/LG-2 + LG-7 (§ 11)
anchor:   const mirrored = lines.map((l) => ({ account: l.accountCode, currency: l.currency, debitMinor: l.creditMinor, creditMinor: l.debitMinor }));
match:    revers|mirror|correction
match:    mutable|edit|append|correction|conserv
```

Append-only corrections: a reversal mirrors every leg with sides swapped and links to the original; the corrected amount is posted fresh.

```decoy
id:       BR-DECOY-10
file:     apps/api/src/accounting/bank-reconciliation.ts
line:     11
command:  /audit-business
class:    decoy/LG-2 (§ 11)
anchor:   'update gl_journal_entries set reconciled_at = now(), statement_line_id = ? where id = ?',
match:    reconciled_at|update|gl_journal_entries
match:    mutable|update|immutable|edit|ledger
```

UPDATE of non-financial columns (`reconciled_at`, `statement_line_id`) on the entry header is not LG-2.

```decoy
id:       BR-DECOY-11
file:     apps/api/migrations/0003_wallets.sql
line:     21
command:  /audit-business
class:    decoy/LG-3 (§ 12)
anchor:   create unique index wallet_transactions_source_uq
match:    wallet_transactions|source|unique
match:    idempot|duplicate|unique|twice
```

A unique `(source_type, source_id, leg)` closes LG-3 for every wallet posting.

```decoy
id:       BR-DECOY-12
file:     apps/api/src/wallets/wallet-posting.service.ts
line:     21
command:  /audit-business
class:    decoy/LG-4 (§ 13)
anchor:   wallet.balanceMinor += amountMinor;
match:    balanceMinor|wallet|cache
match:    cache|second source|drift|transaction|truth
```

The balance cache changes in the same transaction as the movement it reflects, and `wallet-balance.sweep.ts` compares it with Σ transactions nightly.

```decoy
id:       BR-DECOY-13
file:     apps/api/src/accounting/clearing-accounts.ts
line:     8
command:  /audit-business
class:    decoy/DM-1 (§ 14)
anchor:   if (!NEGATIVE_ALLOWED.has(account) && balanceMinor < 0) {
match:    NEGATIVE_ALLOWED|clearing|negative
match:    negative|overdraft|below zero|invariant
```

Clearing, COD-clearing and FX-liquidity accounts are meant to go negative between movements; wallets are guarded.

```decoy
id:       BR-DECOY-14
file:     apps/api/src/invoices/invoice-drafts.service.ts
line:     11
command:  /audit-business
class:    decoy/IV-1 (§ 15)
anchor:   const changed = await this.em.nativeUpdate(Invoice, { id, status: InvoiceStatus.Draft }
match:    editDraft|draft|nativeUpdate
match:    issued|mutable|edit|credit note
```

Drafts are mutable: the status is part of the WHERE and the row count is checked.

```decoy
id:       BR-DECOY-15
file:     services/backoffice/privacy/erasure.py
line:     10
command:  /audit-business
class:    decoy/FR-1 + FR-3 (§ 17)
anchor:   def pseudonymise_customer(customer_id: int) -> None:
match:    pseudonymi|erasure|erase
match:    erase|delete|retain|GDPR|17\(3\)|invoice|records? of fact
```

GDPR Art. 17(3)(b) done right: PII pseudonymised in mutable tables, invoices and ledger rows kept with their buyer snapshot.

```decoy
id:       BR-DECOY-16
file:     apps/api/src/reports/cross-sell.query.ts
line:     17
command:  /audit-business
class:    decoy/RP-1 (§ 18)
anchor:   join per_order po on po.order_id = o.id
match:    per_order|cross.?sell|join
match:    fan.?out|double|multipl|grain
```

Items are pre-aggregated per order in a CTE before the join: one row per summed order.

```decoy
id:       BR-DECOY-17
file:     apps/api/src/reports/sales-breakdown.query.ts
line:     12
command:  /audit-business
class:    decoy/RP-2 (§ 19)
anchor:   sum(subtotal_minor) as gross_sales,
match:    gross_sales|net_sales|breakdown
match:    two ways|differ|definition|metric
```

Gross sales and net sales are two named metrics, both in the definitions table.

```decoy
id:       BR-DECOY-18
file:     apps/api/src/reports/ops-throughput.query.ts
line:     14
command:  /audit-business
class:    decoy/BT-1 (§ 36)
anchor:   `select date_trunc('hour', o.created_at at time zone 'UTC') as hour_utc
match:    hour_utc|UTC|throughput
match:    zone|UTC|business day|store
```

An internal operations chart in UTC that says so on the axis and feeds no merchant figure, cutoff or payout.

```decoy
id:       BR-DECOY-19
file:     apps/api/src/reports/store-day.query.ts
line:     11
command:  /audit-business
class:    decoy/BT-1 + BT-2 (§ 20)
anchor:   `select (o.paid_at at time zone ?)::date as business_day
match:    business_day|at time zone|store
match:    zone|business day|calendar|weekend
```

The store's own zone, passed in: the declared business day. (report-scan 9 prints it for the word `business_day`; no weekday arithmetic.)

```decoy
id:       BR-DECOY-20
file:     services/backoffice/sla/due_dates.py
line:     14
command:  /audit-business
class:    decoy/BT-2 (§ 37)
anchor:   if day.weekday() in WEEKEND or day in SA_HOLIDAYS:
match:    SA_HOLIDAYS|WEEKEND|due
match:    calendar|holiday|weekend|hard.?coded|literal
```

A maintained holiday calendar (`holidays.country_holidays('SA')`) and the KSA Friday–Saturday weekend.

```decoy
id:       BR-DECOY-21
file:     apps/api/src/payouts/payout-webhook.handler.ts
line:     9
command:  /audit-business
class:    decoy/LC-5 (§ 22)
anchor:   const IGNORED_EVENT_TYPES = [
match:    IGNORED_EVENT_TYPES|payout\.|ignore
match:    unhandled|ignored|subscribed|missing|falls through
```

An explicit ignore list, and `default` throws: every subscribed payout event is either handled or listed.

```decoy
id:       BR-DECOY-22
file:     apps/api/src/orders/order-status.ts
line:     38
command:  /audit-business /backend-audit
class:    decoy/LC-2 re-open (§ 29)
anchor:   export const ORDER_REVERSALS: Partial<Record<OrderStatus, OrderStatus[]>> = {
match:    ORDER_REVERSALS|reversal|re-?open
match:    re-?open|terminal|leav|cancelled|delivered
```

A declared reversal table (finance sign-off) that `setStatus()` reads and audits: a declared way back, not a re-open.

```decoy
id:       BR-DECOY-23
file:     services/backoffice/payouts/management/commands/repair_payout.py
line:     17
command:  /audit-business /backend-audit
class:    decoy/LC (§ 21)
anchor:   payout.status = PayoutStatus.FAILED
match:    repair|FAILED|payout
match:    bypass|outside|direct|history|audit
```

An admin repair command, guarded on `processing`, writing a `PayoutAudit` row: not a bypass.

```decoy
id:       BR-DECOY-24
file:     apps/api/src/help/articles.service.ts
line:     11
command:  /audit-business
class:    decoy/LC-6 (§ 31)
anchor:   article.status = 'published';
match:    article|publish
match:    history|audit|no record
```

Publishing a help article is a low-stakes toggle; it needs no history.

```decoy
id:       BR-DECOY-25
file:     apps/api/src/payouts/payouts.controller.ts
line:     17
command:  /audit-business
class:    decoy/CY-1 (§ 23)
anchor:   @Post()
match:    payout
match:    inverse|cancel|delete|revoke|undo
```

A payout is sent on creation and cannot be recalled (documented); an irrevocable action needs no inverse.

```decoy
id:       BR-DECOY-26
file:     apps/api/src/exports/report-exports.controller.ts
line:     6
command:  /audit-business
class:    decoy/CY-1 (§ 41)
anchor:   @Post()
match:    export
match:    inverse|cancel|delete|undo
```

Starting an export runs a command; it needs no delete (and it has a status route).

```decoy
id:       BR-DECOY-27
file:     apps/api/src/notifications/receipt.mailer.ts
line:     10
command:  /audit-business
class:    decoy/CY-4 (§ 38)
anchor:   return this.transporter.sendMail({ to, subject: `Your receipt for order ${orderNumber}`, html });
match:    receipt|sendMail
match:    unsubscribe|List-Unsubscribe|one.?click
```

A receipt is transactional mail: no unsubscribe header is required.

```decoy
id:       BR-DECOY-28
file:     apps/api/src/subscriptions/stripe-subscriptions.gateway.ts
line:     15
command:  /audit-business
class:    decoy/TX-2 + TX-5 (§ 8)
anchor:   automatic_tax: { enabled: true },
match:    automatic_tax|Stripe Tax|tax
match:    jurisdiction|address|tax code|base|delegat
```

Plan tax delegated to Stripe Tax with the customer's address collected and a tax code on every price.

```decoy
id:       BR-DECOY-29
file:     apps/api/src/subscriptions/stripe-subscriptions.gateway.ts
line:     24
command:  /audit-business
class:    decoy/BL-1 (§ 9)
anchor:   proration_behavior: 'create_prorations',
match:    proration|prorat
match:    hand.?roll|day.?count|30|formula
```

Proration of the main plan delegated to Stripe Billing.

```decoy
id:       BR-DECOY-30
file:     apps/api/src/subscriptions/billing-anchor.ts
line:     9
command:  /audit-business
class:    decoy/BL-2 (§ 9)
anchor:   return addMonths(sub.anchorDate, sub.cyclesBilled + 1);
match:    addMonths|anchor
match:    drift|overflow|month end|clamp|anchor
```

date-fns `addMonths` from the anchor clamps a day-31 anchor and never drifts.

```decoy
id:       BR-DECOY-31
file:     apps/api/src/checkout/checkout.service.ts
line:     49
command:  /audit-business
class:    decoy/MP-3
anchor:   order.fxRate = quote.rate;
match:    fxRate|fx|rate
match:    pinned|stored|today|latest|not pinned|re-?convert
```

The settlement rate is pinned on the order at checkout with its time and source.

```decoy
id:       BR-DECOY-32
file:     apps/api/src/refunds/stripe-refund.gateway.ts
line:     11
command:  /audit-business /security-audit
class:    decoy/PR-6 (§ 26)
anchor:   return stripe.refunds.create({ payment_intent: await this.intentFor(orderId), amount: amountMinor });
match:    stripe|refunds\.create|card refund
match:    bound|exceed|more than|prior|Σ|sum
```

Stripe rejects card refunds above the captured amount; the bound for this path is the provider's (the wallet path is the seed, BR-PR6-a).

```decoy
id:       BR-DECOY-33
file:     apps/web/src/shared/format-money.ts
line:     6
command:  /audit-business /quality-audit
class:    decoy/MP (§ 4)
anchor:   return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(major);
match:    formatMoney|Intl|format
match:    float|division|round|display|parse
```

Display formatting after exact integer arithmetic; the string is never parsed back.

```decoy
id:       BR-DECOY-34
file:     apps/api/src/pos/zatca-receipt.builder.ts
line:     36
command:  /audit-business /backend-audit
class:    decoy/MP-2 (§ 5)
anchor:   price: formatMajor(l.priceMinor, 'SAR'),
match:    formatMajor|price|payload|decimal
match:    float|decimal string|major|unit|wire
```

Integer minor units converted to the decimal strings the authority's receipt schema requires, at the carrier only.

```decoy
id:       BR-DECOY-35
file:     apps/api/src/pos/pos-takings.query.ts
line:     11
command:  /audit-business
class:    decoy/RP-4 (§ 6)
anchor:   `select coalesce(sum(r.total_minor), 0) as takings_minor, count(*) as receipts
match:    takings|pos_receipts|sum
match:    currenc|mixed|group by
```

The POS is SAR-only by the documented tax policy; one register's takings have one currency. (report-scan 4 prints it; the policy row clears it.)

```decoy
id:       BR-DECOY-36
file:     apps/api/src/pricing/discount-policy.ts
line:     18
command:  /audit-business
class:    decoy/PR-1
anchor:   return Math.max(0, total);
match:    promotion|stackable|discount
match:    order|permut|stack|floor|composition
```

Item promotions in a declared priority order, `stackable` honoured, a floor at zero: the declared composition.

```decoy
id:       BR-DECOY-37
file:     services/backoffice/reports/refunds_by_day.py
line:     14
command:  /audit-business
class:    decoy/BT-1
anchor:   .annotate(day=TruncDate("refunded_at", tzinfo=zone))
match:    TruncDate|refunds_by_day|day
match:    zone|UTC|business day
```

Buckets in the store's own zone (`tzinfo=ZoneInfo(store.timezone)`).

## Detector measurement — the business pre-flights and `status-graph.py` run on this fixture

Measured 2026-10-19 on a copy staged the way `run.sh` stages it (the tree minus this key), from the copy's root, with
every pre-flight block run verbatim from its `SKILL.md` under `ROOTS=(apps/api/src services/backoffice)` (and
`WEB=(apps/web/src)` for the coverage block), the `SM` / `SG` paths pointed at the template scripts
(`product/…/surface-map.py`, `business/…/status-graph.py`), and `lifecycle-scan` run once per root as its `SKILL.md`
says (`writes.tsv` paths are relative to the root that holds them). Nothing was written into the copy (`find -newer` on
a stamp: 0 files). These are the detectors' raw rows, not an `/audit-business` result.

Wall time per block: `pricing-rule-scan` 0.38 s (107 lines), `tax-invoice-scan` 0.33 s (128), `ledger-scan` 0.45 s
(162), `report-scan` 0.38 s (87), `lifecycle-scan` 0.6 s per root (`status-graph.py` exit 0 on both: 118 TS files,
6 machines, 13 writes; 104 Python files, 6 machines, 10 writes), `check-business-coverage` 0.94 s (surface-map:
231 files, 25 served routes — 19 Nest, 6 DRF — 7 client references). No `rg` exit 2 in any block run as documented. Run
with both roots in one `ROOTS`, the lifecycle block's 4b and 6b print `BLOCKED (rg exit 2)` for the second root's
files — the documented behaviour, loud, not a silent zero.

**Every business seed is printed by its owning lane: 114 of 114.** 83 at their exact line; 29 as a listed file, a
graph line naming the state, a provider-map line or a printed absence the read closes (IV-3, LG-6, RP-6); the 2 CY-6
seeds through § 6's line count (the grep prints `wc -l`; run without the count it prints exactly the two seed lines).
Routed rows: `BR-HO-CQ-a` prints in pricing 2c (listed as code-quality §4 corroboration); the other 11 are other packs'
shapes no business grep looks for — the owners' pre-flights were not run in this pass.

Decoys: 21 of 37 print at their line (04–08, 10–14, 19–21, 25, 26, 28–31, 35, 36), 8 more as a listed file or a graph
line (02, 03, 15, 16, 22, 23, 24, 32), and 8 never print (01, 09, 17, 18, 27, 33, 34, 37). Each printed one is cleared
by its precedent or the policy row at the read.

What the run found in the detectors (none changes a seed's verdict; each is an integrator request):
- **`tax-invoice-scan` 9b is blind to `.github/workflows`.** `rg` skips hidden directories unless `--hidden`; the
  include glob `**/.github/workflows/*.{yml,yaml}` does not override it. 9b printed 0 lines (rg exit 1) although
  `einvoice.yml` runs the KoSIT validator; with `--hidden` it prints 3. Without the flag the back office's validated
  Peppol builder would read as an IV-3 candidate.
- **`ledger-scan` 0a has no Django lane.** Tables created by `migrations.CreateModel(… options={"db_table": …})` are
  not listed; 0b still finds the `db_table` bindings.
- **`report-scan` §4's look-ahead only reads after the `SUM`.** Django's `.values(…, "currency").annotate(Sum(…))`
  groups by currency before the aggregate: 2 grouped sums print (`daily.py:13`, `refunds_by_day.py:16`). §9 prints
  `business_day` as a column alias (`store-day.query.ts:11`, decoy 19).
- **`status-graph.py`:** `--declared` edges are not scoped to the file's `## <Machine>` sections, so order, invoice and
  subscription edges print as LC-3 rows on every machine sharing a state name (payment, shipment, payout); TS computed
  enum keys in a transition table (`[InvoiceStatus.Draft]: […]`) are not read (the fixture's table uses literal keys);
  django-fsm `source=[A, B]` reads as `*`; a comparison on another receiver's `status` inside the look-back window
  becomes the guard (`payout.status != PROCESSING` guards `settlement.status = SETTLED`, so settlement `open` prints as
  a trap); the status key of `nativeUpdate`'s WHERE object is recorded as a write when the data object has none (`→Draft`
  on the invoice machine); `article.status = 'draft'` is attributed to the invoice machine by its literal; a
  map-driven write (`CARRIER_STATUS_MAP[…]`) is invisible, so every Python shipment state prints unreachable; `paid`,
  `credited` and `approved` are not terminal words (django-fsm has no terminal marker); a response object
  `{ status: 'queued' }` reads as a write (an implied `export` machine).
- **`check-business-coverage` reads DRF routes as method `ANY`** (surface-map's Django lane), so 0b cannot pair a DRF
  forward route with its inverse and 2a misses DRF `@action(methods=["post"])` inverses — why both CY-1 and CY-2 seeds
  are TypeScript.
- Noise rows the read clears: pricing 2c prints 6 back-office `DecimalField(decimal_places=2)` lines (the policy limits
  back-office invoices to EUR and USD); pricing 2a prints `taxRate * 10_000` (a fraction to basis points); tax 11a
  prints a credit note stamped once at issue; tax 2 prints the inclusive back-out in `line_tax.py:12`.

| id | printed by |
|----|------------|
| BR-MP1-a | pricing 0b `commission.calculator.ts:5` (`Decimal.set(`); 0a lists the file beside `money-policy.ts` |
| BR-MP1-b | pricing 0b `statements.py:14` (mode-less `.quantize(CENT)`) |
| BR-MP2-a | pricing 2b `invoice-lines.builder.ts:21` (and the correct reader `order-discount.ts:7`) |
| BR-MP2-b | pricing 2a `fees.py:10` (`fee_rate / 100`) |
| BR-MP3-a | pricing 3a `revenue-usd.report.ts:18`; 3b shows the stored-rate columns it skips (`order.entity.ts:19-20`) |
| BR-MP3-b | pricing 3a `fx.py:18` (and the helper `fx.py:7`) |
| BR-PR1-a | pricing 4a `coupon-stack.ts:11`; 4b prints no stacking flag or floor in that file |
| BR-PR1-b | pricing 4a `pricing.py:14` |
| BR-PR2-a | pricing 5 `refund-calculator.ts:5` |
| BR-PR2-b | pricing 5 `invoice_render.py:9` |
| BR-PR3-a | pricing 6 `shipping-fee.ts:8` |
| BR-PR3-b | pricing 6 `tiers.py:7` |
| BR-PR4-a | pricing 7 `apply-coupon.ts:27` |
| BR-PR4-b | pricing 7 `redeem.py:7` |
| BR-PR5-a | pricing 8 `apply-coupon.ts:15` |
| BR-PR5-b | pricing 8 `campaigns.py:8` (`ends_on__gte`) |
| BR-PR6-a | pricing 9a `refund.service.ts:24`; 9b lists the file, 9c prints 0 files that read prior refunds |
| BR-PR6-b | pricing 9b lists `store_credit.py` (refund call); 9c prints 0 files |
| BR-BL1-a | pricing 10 `plan-change.service.ts:16` |
| BR-BL1-b | pricing 10 `proration.py:9` |
| BR-BL2-a | pricing 11 `renewal.scheduler.ts:16` |
| BR-BL2-b | pricing 11 `renewals.py:12` |
| BR-BL3-a | pricing 12 `billing-period.ts:11` (grep 11 prints its `addMonths` too) |
| BR-BL3-b | pricing 12 `periods.py:8` (and 11, `relativedelta`) |
| BR-BL4-a | pricing 13 lists `usage-aggregator.ts` |
| BR-BL4-b | pricing 13 lists `metering.py` |
| BR-TX1-a | tax 1a `invoice-pdf.renderer.ts:4`; 4 `:10` |
| BR-TX1-b | tax 1b `tax_rates.py:6` |
| BR-TX2-a | tax 2 `checkout-tax.ts:18` |
| BR-TX2-b | tax 2 `totals.py:11` |
| BR-TX3-a | tax 3 `invoice-lines.builder.ts:32` (and the default `store.entity.ts:8`) |
| BR-TX3-b | tax 3 `line_tax.py:10` |
| BR-TX4-a | tax 4 `ubl-invoice.builder.ts:30` (and the line rounding `:21`) |
| BR-TX4-b | tax 4 `totals.py:23` |
| BR-TX5-a | tax 5 `checkout-tax.ts:13` |
| BR-TX5-b | tax 5 `ubl_lines.py:6` |
| BR-TX6-a | tax 6 `ubl-invoice.builder.ts:19` |
| BR-TX6-b | tax 6 `export_invoice.py:5` |
| BR-IV1-a | tax 7b `invoices.service.ts:18`; 7d finds no status guard in the file |
| BR-IV1-b | tax 7b `admin_views.py:12` |
| BR-IV2-a | tax 8b `credit-notes.service.ts:17` (and the entity `:6`) |
| BR-IV2-b | tax 8a lists `credit_notes.py` (8b prints no bound) |
| BR-IV3-a | tax 9a lists `ubl-invoice.builder.ts`; 9b prints 0 — see the measurement note: the grep is blind to `.github/` |
| BR-IV3-b | tax 9a lists `fatoora_builder.py`; 9b 0 |
| BR-IV4-a | tax 10 `zatca-receipt.builder.ts:20-21` |
| BR-IV4-b | tax 10 `fatoora_builder.py:12` |
| BR-IV5-a | tax 11a `invoice-pdf.renderer.ts:13` |
| BR-IV5-b | tax 11b `invoice_render.py:15` |
| BR-LG1-a | ledger 1b `wallet-ledger.service.ts:11`; 0c shows the GL-only trigger |
| BR-LG1-b | ledger 1b `fee_tasks.py:11`; 1a prints the code-only `assert_balanced` |
| BR-LG2-a | ledger 2a `journal-corrections.ts:14-15` |
| BR-LG2-b | ledger 2b `admin_actions.py:6-7` |
| BR-LG3-a | ledger 3b `payment-postings.ts:15`; 3a prints no unique key on `gl_journal_entries` (only `wallet_transactions_source_uq`) |
| BR-LG3-b | ledger 3b `postings.py:37` |
| BR-LG4-a | ledger 4a `courier-cod.service.ts:12`; 4b prints only the merchant-wallet sweep |
| BR-LG4-b | ledger 4a `credit.py:9` (grep 12 prints it too) |
| BR-LG5-a | ledger 5a `wallet-transfer.service.ts:16-21` |
| BR-LG5-b | ledger 5b `models.py:6` |
| BR-LG6-a | ledger F1 `stripe`; 6a lists only `bank-reconciliation.ts` and the payout webhook; 6b prints no Stripe ingestion |
| BR-LG6-b | ledger 6b `remittances.py:1,13-14` |
| BR-LG7-a | ledger 7a `refund-postings.ts:10` (the function head) |
| BR-LG7-b | ledger 7b `postings.py:47` |
| BR-FR1-a | ledger 8a lists `account-deletion.service.ts`; 8b `:14-15` |
| BR-FR1-b | ledger 8a lists `offboarding.py`; 8b `:7` (`drop schema`) |
| BR-FR2-a | ledger 9a lists `retention.job.ts`; 9b `:6` and `:15` |
| BR-FR2-b | ledger 9a lists `tasks.py`; 9b `:12` (`5 * 365`) |
| BR-FR3-a | ledger 10a `wallet-transaction.entity.ts:14` (and the insert `wallet-ledger.service.ts:9`) |
| BR-FR3-b | ledger 10b `anonymise.py:8`; tax 7b prints the same line (corroboration) |
| BR-DM1-a | ledger 12 `gift-card-redeem.repository.ts:11`; 4a prints the same line; 11a prints no CHECK on `gift_cards` |
| BR-DM1-b | ledger 12 `stock.py:8`; 11a/11b print no `on_hand` guard |
| BR-DM2-a | ledger 12 `stock-import.job.ts:12`; 11b prints the guard `stock.service.ts:12` |
| BR-DM2-b | ledger 12 `reservations.py:8`; 11b prints the guard `models.py:13` |
| BR-RP1-a | report 1a lists `sales-summary.query.ts` |
| BR-RP1-b | report 1b `merchant_report.py:10`; 4 prints it too |
| BR-RP2-a | report 2 `revenue 4` (files); 0b `revenue 8` |
| BR-RP2-b | report 2 `refund_rate 2` |
| BR-RP3-a | report 3 lists `payout-forecast.query.ts` (no status/test filter in the file); 1a lists it too |
| BR-RP3-b | report 3 lists `stores.py` |
| BR-RP4-a | report 4 `platform-gmv.query.ts:11` |
| BR-RP4-b | report 4 `payouts_sql.py:7` |
| BR-RP5-a | report 5a `delivery-kpis.query.ts:12` |
| BR-RP5-b | report 5b `aov.py:9` |
| BR-RP6-a | report 6 lists no reconciliation for statements (only the payout webhook file) |
| BR-RP6-b | report 6 prints no reconciliation file for exports |
| BR-RP7-a | report 7a lists `confirmed-orders.query.ts`; 7b prints `paid_at`, `delivered_at` stamps |
| BR-RP7-b | report 7a lists `deliveries.py` |
| BR-BT1-a | report 8a `daily-sales.query.ts:11`; 8b prints three zone policies (`?`, `utc`, `asia/riyadh`) |
| BR-BT1-b | report 8a `daily.py:11` |
| BR-BT2-a | report 9 `settlement-date.ts:10` |
| BR-BT2-b | report 9 `calendar.py:12` (and the list `:4`) |
| BR-LC1-a | status-graph (ROOTS=apps/api/src) machine `order`: `LC-1 unreachable: awaiting_review` and `LC-2 traps: … awaiting_review` |
| BR-LC1-b | status-graph (ROOTS=services/backoffice) machine `payout`: `LC-1 unreachable: on_hold`, `LC-2 traps: on_hold` |
| BR-LC2-a | status-graph machine `order`: `LC-2 traps: disputed, …`; `LC-3 declared, not built: disputed→paid` |
| BR-LC2-b | status-graph (ROOTS=services/backoffice) machine `subscription`: `LC-2 no terminal state`, `LC-3 declared states missing from the code: cancelled` |
| BR-LC3-a | status-graph `--declared=ai/business-flows.md`, machine `order`: `LC-3 declared, not built: delivered→return_requested, return_requested→refunded`; `declared states missing: return_requested` |
| BR-LC3-b | status-graph (ROOTS=services/backoffice) machine `invoice`: `LC-3 built, not declared: issued→void` |
| BR-LC4-a | lifecycle 4a (ROOTS=apps/api/src) `payments/payment-capture.service.ts |payment||order|`; 4b prints no transaction in it |
| BR-LC4-b | lifecycle 4a (ROOTS=services/backoffice) `payouts/settle.py |payout||settlement|`; 4b prints no `atomic` in it |
| BR-LC5-a | lifecycle 5a `stripe-webhook.handler.ts:14` (one case); 5d `webhook-endpoint.json:4`; graph machine `payment`: `LC-1 unreachable: failed, refunded` |
| BR-LC5-b | lifecycle 5b `carrier_webhooks.py:4` (the map); the write is computed, so the graph prints every Python shipment state unreachable |
| BR-LC6-a | lifecycle 6a `order_status_history`; 6b work list (8 files, ROOTS=apps/api/src) includes `admin/order-repair.controller.ts` |
| BR-LC6-b | lifecycle 6b work list (7 files, ROOTS=services/backoffice) includes `merchants/kyc.py`; 6a prints no KYC history table |
| BR-CY1-a | coverage 0b pairs `invites POST /team/invites` (surface-map inventory) |
| BR-CY1-b | coverage 0b pairs `connect POST /stores/{}/carriers/connect` |
| BR-CY2-a | coverage 2b `apionly.txt`: `POST /stores/{}/integrations/{}/disconnect … no client reference` |
| BR-CY2-b | coverage 2b `apionly.txt`: `POST /api-keys/{}/revoke … no client reference` |
| BR-CY3-a | coverage 3a `signup.service.ts:13`; 3b counts 0 resend lines |
| BR-CY3-b | coverage 3c `views.py:13` |
| BR-CY4-a | coverage 4a lists `newsletter.sender.ts`; 4b prints 0 header lines |
| BR-CY4-b | coverage 4a lists `campaigns.py`; 4b 0 |
| BR-CY5-a | coverage 5 `AccountSettingsPage.tsx:7` |
| BR-CY5-b | coverage 5 `views.py:9-10` (erase only) |
| BR-CY6-a | coverage 6 counts 2 lines: `subscription-payments.service.ts:17` and the onboarding one |
| BR-CY6-b | coverage 6 counts it (`onboarding.py:11`) |
| BR-HO-CQ-a | pricing 2c `order-import.ts:17` (listed as corroboration) |
| BR-HO-CQ-b | not printed by a business grep (a float, not a rule) |
| BR-HO-CQ-c | not printed by pricing 8 (no comparison with the clock); code-quality §6 owns the parse |
| BR-HO-CQ-d | not printed (web root is outside the business ROOTS) |
| BR-HO-DB-a | not printed by ledger 8 (a schema FK, not an application flow) |
| BR-HO-DB-b | not printed by a business grep |
| BR-HO-DB-c | not printed by a business grep (tax 7–11 read code, not DDL) |
| BR-HO-SEC-a | not printed by a business grep |
| BR-HO-SEC-b | not printed by a business grep |
| BR-HO-SEC-c | not printed by a business grep |
| BR-HO-BE-a | graph machine `shipment` (TS) shows no `in_transit → cancelled` edge; the send itself is backend ST §1's |
| BR-HO-BE-b | not printed by a business grep |
