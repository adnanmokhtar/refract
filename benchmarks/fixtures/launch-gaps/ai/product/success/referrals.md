# Success definition: referrals (beta)

Written with /define-success on 2026-09-02.

## Problem

Shops hear about Shelfwise from other shops. Referrals give both shops a free month when the
referred shop activates its first store.

## Instrumentation

- `Referral Sent`: the referral e-mail was queued (server).
- `Signup Completed` with method "referral": the referred shop created its account.

## Readiness fields

stage: beta
paths: apps/web/src/features/referrals/**, apps/api/src/referrals/**
metric: referred signups per active merchant, 30-day
metric_event: Referral Sent
counter_metric: unsubscribe rate on referral e-mails, 30-day
counter_event: Email Unsubscribed
baseline: 0.4 referred signups per merchant (last quarter)
threshold: pause referrals if the unsubscribe rate exceeds 1.5%
owner: Marco Bellini
review_date: 2026-09-30
decision_rule: keep if referred signups reach 0.6 per merchant by the review date, else remove the page
rollback_record: staging 2026-10-10T09:00Z flag off, rollback failed (issued referral credits stayed on the accounts)
emissions: referral invite e-mail; account credit on activation
