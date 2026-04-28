---
description: Replay a recorded payment provider webhook / charge event against the local dev server to verify handling.
---

# /replay-charge

Test payment-handling code without pinging the real provider.

## Setup

Fixtures at `test/fixtures/payment/` — record real (sanitized!) webhook payloads from provider's test mode:
- `charge.succeeded.json`
- `charge.failed.json`
- `invoice.payment_succeeded.json`
- `customer.subscription.updated.json`
- etc.

NEVER include real card numbers or live keys in fixtures.

## Flow

1. Load fixture.
2. Compute provider's signature header (`Stripe-Signature`, etc.) using the dev webhook secret.
3. POST to the local webhook endpoint.
4. Report: status, response time, DB state delta, log trace.
5. Negative tests:
   - Same event id twice → second returns 200 with "already processed"
   - Invalid signature → 401

## Rules

- LOCAL ONLY. Never point at prod.
- Dev webhook secret separate from prod.
- Fixtures sanitized — no real customer identifiers.
