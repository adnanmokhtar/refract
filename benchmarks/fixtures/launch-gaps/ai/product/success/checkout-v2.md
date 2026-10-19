# Success definition: checkout v2 (in-app plan upgrades)

Written with /define-success on 2026-08-28. Brief: ai/product/briefs/checkout-v2.md.

## Problem

Merchants on Starter who outgrow it write to billing@ and wait a working day for a plan change;
about a third never follow up. Checkout v2 lets them upgrade in the app through Stripe Checkout.

## Instrumentation

- `Checkout Started`: the merchant picked a plan on /billing/upgrade.
- `Plan Purchased`: Stripe confirmed the payment. Carries plan, value and currency.

## Readiness fields

stage: ga
paths: apps/web/src/features/billing/**, apps/api/src/billing/**
metric: upgrade conversion, 14-day (Checkout Started to Plan Purchased)
metric_event: Plan Purchased
counter_metric: <counter-metric and its event>
counter_event: Subscription Cancelled
baseline: 6.1% of Starter merchants per month (2026-08-01..2026-08-31)
threshold: roll back if 14-day refund requests exceed 3% of purchases
owner: Dana Reyes
review_date: 2027-01-15
decision_rule: TBD once the first month of data is in
rollback_record: we can revert the deploy if conversion drops
emissions: Stripe subscription and invoice; plan-change receipt e-mail
