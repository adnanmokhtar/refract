# Payment idempotency

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
