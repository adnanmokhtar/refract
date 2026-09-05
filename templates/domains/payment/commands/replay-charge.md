---
description: Replay a recorded payment provider webhook / charge event against the local dev server to verify handling.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /replay-charge

Test payment-handling code without pinging the real provider.

## Premise

Real signals only. Cite the actual fixture filename, computed signature header, HTTP status from the local endpoint, and the resulting DB row delta — never narrate a replay you didn't run. Read before writing: confirm the fixture exists at `test/fixtures/payment/<name>.json` and is sanitized (no live keys, no real PANs) BEFORE POSTing.

## Mechanical halt

Cite-or-halt: every reported result must include the fixture path, response status, and at least one DB-state line (or "no change" with a query showing it). LOCAL ONLY — refuse to run if the target URL resolves outside `localhost` / `127.0.0.1` / explicit dev hosts. Negative tests (replay, tampered sig) must show the actual response code, not an assumed one.

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
