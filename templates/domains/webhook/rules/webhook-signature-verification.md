---
name: webhook-signature-verification
description: Webhook signature verification
kind: rule
---

# Webhook signature verification

## Hard rule

Every inbound webhook MUST be signature-verified against the raw body using a constant-time compare BEFORE any processing, parsing, persisting, or trust of payload fields. Mismatch MUST return 401. Processing a webhook before verification — including reading `tenant_id` / `user_id` from the payload — is FORBIDDEN.

Every inbound webhook MUST be signature-verified BEFORE any processing.

## The rule

- Signature header present (e.g., `X-Hub-Signature-256` for Meta, `Stripe-Signature` for Stripe, `X-Hub-Signature` for GitHub, `X-Twilio-Signature` for Twilio).
- Compute `HMAC-<algo>(raw_body, WEBHOOK_SECRET)` — algo matches the provider's spec.
- **Constant-time compare** — no early exit that leaks timing.
- Mismatch → `401`, log the failure (with source IP, endpoint, signature excerpt), DO NOT process.

## Raw body is mandatory

- Signature is computed over the RAW bytes. Must use `@fastify/raw-body` / `express.raw()` / equivalent so the handler sees both parsed JSON AND raw.
- If raw body isn't available, REJECT — never trust an unverifiable payload.

## Idempotency

- After verification, dedupe by a provider-supplied unique id (e.g., `message_id`, `event_id`, `delivery_id`) — unique index in DB.
- Duplicate → return 200 without re-processing. Providers retry aggressively; double-processing = duplicate charges / duplicate replies / duplicate orders.

## Timeouts

- Providers retry on non-200 after 5–10s. Return 200 FAST:
  - Phase 1 (simple): synchronous processing must finish under budget.
  - Phase 4+ (at scale): verify + persist inbound + enqueue job + return 200. Worker processes async.

## Secrets per environment

- `WEBHOOK_SECRET` / `APP_SECRET` different in dev / staging / prod.
- Stored in env vars. Never in code. Never logged.
- Rotate on compromise.

## Forbidden

- Accepting a request without the signature header.
- Non-constant-time comparison (`if (sig === expected)` with early exit leaks timing).
- Logging the secret / full signature.
- Skipping verification "for testing" — use a proper fixture POST with a valid signature instead.
- Processing before verifying.
- Trusting `tenant_id` / `user_id` from the payload BEFORE signature verification.

## Enforcement

- `/webhook-audit` command — greps every webhook handler for raw-body access, signature header read, constant-time compare (`crypto.timingSafeEqual` / equivalent), and dedupe-by-event-id unique index.
- CI lint MUST reject `req.body.tenantId` / `req.body.userId` reads in webhook handlers that occur before the signature-verification call site.
- Test fixture per provider MUST include a tampered-signature case asserting 401 — missing test fails CI.
- TODO: `scripts/validate-webhook-handlers.sh` to AST-scan handler files and verify the signature-verify call dominates every other side-effecting call.
