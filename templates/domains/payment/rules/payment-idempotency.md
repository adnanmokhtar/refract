---
name: payment-idempotency
description: Payment idempotency
kind: rule
---

# Payment idempotency

## Hard rule

Every mutating payment endpoint MUST require an `Idempotency-Key` header, MUST forward an idempotency key to the provider, and MUST dedupe webhooks by the provider's event id. Retry without the original key is FORBIDDEN. Card numbers / CVV MUST NEVER touch our storage. Amounts MUST be computed server-side; client-supplied amounts MUST NEVER be trusted.

Every payment-affecting request is idempotent. Double-charges are user-visible, refunds are expensive, trust erodes.

## Client idempotency

- Every mutating payment endpoint accepts an `Idempotency-Key` header (UUID per logical action).
- Server stores first result by key — subsequent requests with same key return the same result without re-executing.
- Store: key + request hash + response + expiry (24h typical).
- Mismatched request body under the same key → 409 Conflict (client bug).

## Provider idempotency

- Stripe: pass `idempotency_key` on every API call.
- PayPal / Paddle / Braintree: provider-specific. Consult docs. No exceptions.

## Webhook idempotency

- Provider webhooks retry. Dedupe by the provider's event id (unique index).

## Retry policy

- On payment call failure: retry ONLY with the same idempotency key.
- Max 3 retries with exponential backoff.
- NEVER retry without the key — risk of double-charge.

## Reconciliation

- Nightly job reconciles provider records vs our DB.
- Discrepancies logged + flagged for human review.

## Forbidden

- Mutating payment endpoint without `Idempotency-Key`.
- Retry without key.
- Charging from a GET request.
- Trusting amount from the client without server-side calculation.
- Storing card numbers / CVV (PCI scope escalation).

## Enforcement

- `/payment-audit` command — greps payment routes for missing `Idempotency-Key` header check, missing provider key forwarding, missing webhook dedupe (`UNIQUE` index on provider event id).
- CI lint MUST reject any payment-related field name matching `card_number` / `cvv` / `pan` in DB schema or DTO definitions.
- Nightly reconciliation job MUST run; missing run for >36h pages on-call.
- TODO: `scripts/validate-payment-idempotency.sh` to AST-walk payment controllers and assert every mutating route extracts `Idempotency-Key` before calling the provider.
