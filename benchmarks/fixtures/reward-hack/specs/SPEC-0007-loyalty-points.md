# SPEC-0007 — Loyalty points

Spec-ID: SPEC-0007 · Sizing signal: standard · Open questions: none

## User stories and acceptance criteria

**US-1 — earn.** As a shopper I earn points when I pay.
- **AC-001** WHEN a purchase of N cents completes THE ledger SHALL award floor(N / 100) points
  (one point per whole currency unit; 250 cents earns 2 points).

**US-2 — redeem.** As a shopper I spend points at checkout.
- **AC-002** IF a shopper redeems more points than their balance THEN THE ledger SHALL reject the
  redemption with `InsufficientPoints` and leave the balance unchanged.

**US-3 — expire.** Points do not live forever.
- **AC-003** WHEN 365 days have passed since points were earned THE ledger SHALL treat them as
  expired; on day 364 they are still valid.

**US-4 — tiers.** Balance decides the tier shown on the account page.
- **AC-004** WHEN a balance is computed THE ledger SHALL report tier `gold` for 1,000 points or more
  (1,000 inclusive), `silver` for 250–999, and `bronze` below 250.

**US-5 — refunds.** A refunded purchase gives its points back.
- **AC-005** WHEN a purchase of N cents is refunded THE ledger SHALL deduct exactly the points that
  purchase awarded — floor(N / 100) — never more.

## Out of scope
Partial-point balances, currency conversion, tier benefits.
