---
name: webhook-signature-verification
description: Webhook signature verification
kind: rule
---

# Webhook signature verification

## Hard rule

Every inbound webhook MUST be signature-verified against the RAW body using a constant-time compare BEFORE any processing, parsing, persisting, or trust of payload fields. Mismatch MUST return 401. Reading `tenant_id` / `user_id` / any field from the payload before verification is FORBIDDEN. Secrets MUST be per-environment, never logged, never hardcoded.

## Must

- **Signature header read first.** Provider header (e.g., `X-Hub-Signature-256` for Meta, `Stripe-Signature` for Stripe, `X-Hub-Signature` for legacy GitHub, `X-GitHub-Signature-256` for modern GitHub, `X-Twilio-Signature` for Twilio, `X-Slack-Signature` for Slack, `X-Shopify-Hmac-Sha256` for Shopify). Missing header → 401.
- **Raw body capture before JSON parse.** Wire `express.raw()` / `@fastify/raw-body` / framework equivalent so the handler sees both the parsed body (for typed access AFTER verify) AND the raw bytes (for HMAC). If raw body is unavailable, REJECT — never trust an unverifiable payload.
- **Compute `HMAC-<algo>(raw_body, <PROVIDER>_SECRET)`** — algorithm + scheme matches the provider's spec. Some providers prefix with timestamp + version (Stripe `t=<ts>,v1=<sig>`), older Slack signs `v0:<ts>:<body>` — follow the docs exactly.
- **Constant-time compare** — `crypto.timingSafeEqual` / `hmac.compare_digest` / `MessageDigest.isEqual` / equivalent. No `===` / `==` / variable-time string compare.
- **On mismatch → 401**, log `webhook_hmac_mismatch` with source IP, endpoint, signature prefix excerpt. DO NOT process. DO NOT persist payload fields. DO NOT read tenant id from body.
- **Idempotency by provider event id**: dedupe via `(provider, event_id) UNIQUE` + atomic `ON CONFLICT DO NOTHING` (or equivalent). Duplicate → 200 without re-processing — providers retry aggressively; double-processing = duplicate charges / replies / orders.
- **Timestamp tolerance** when the provider exposes one (Stripe `t=`, Slack `X-Slack-Request-Timestamp`): reject events with skew > 5 min. Defends against captured-and-replayed payloads.
- **Per-environment secrets**: `<PROVIDER>_SECRET` differs in dev / staging / prod. Stored in env vars / secret manager. Never in code. Never logged.
- **Return 200 fast** on legitimate (signed) requests — verify + persist event row + enqueue worker (if async) + 200, all under the provider's timeout (typically 5–10s).

## Must not

- Accept a request without the signature header.
- Use non-constant-time comparison (`if (sig === expected)` exits early on first mismatching byte → leaks signature).
- Log the secret, the full computed signature, or the raw header value in production logs.
- Skip verification "for testing" / "in dev" — use a fixture POST with a locally-signed valid signature instead.
- Process before verifying (NO logging the body, NO writing to DB, NO reading payload fields).
- Trust `tenant_id` / `user_id` / `customer_id` from the payload before signature verification.
- Re-serialise the parsed body and HMAC that — JSON.stringify changes whitespace/order/numbers and signatures will not match. Sign / verify the original bytes.
- Share one webhook URL + one secret across environments. Test events trigger prod side effects.

## Should

- Wrap signature verification in a guard / middleware (`<WebhookSignatureGuard>`) so feature handlers cannot accidentally skip it.
- Persist the verified raw body (or a hash of it) to `webhook_events` for replay + audit.
- Rotate secrets quarterly OR on suspected compromise; document the rotation runbook.
- Reconcile periodically with the provider's events list — webhooks WILL be missed (your outage, theirs, network partitions). A cron pulling events since N days ago and diffing against `webhook_events` catches drift.
- Distinguish HMAC mismatch (401) from internal processing failure (200 + log) — return 5xx ONLY when the provider retry IS the right behaviour (DB unavailable; expected to be back).

## Review checklist (PRs touching webhook handlers)

- [ ] Raw body capture middleware is wired BEFORE the JSON parser for the webhook route.
- [ ] Signature header is read; missing → 401 with no further work.
- [ ] HMAC computation uses the provider's exact scheme (algorithm, prefix, timestamp inclusion).
- [ ] Compare uses the platform's constant-time primitive (cite it: `crypto.timingSafeEqual` / equivalent).
- [ ] Mismatch path: 401 + log, no persistence, no payload field read.
- [ ] Provider event id deduped via UNIQUE constraint + atomic insert-or-skip.
- [ ] Timestamp tolerance enforced when the provider supplies one.
- [ ] Internal failures return 200 (after logging + persisting event row) — no retry storm.
- [ ] Secret loaded from env / secret manager — not hardcoded, not logged.
- [ ] Test fixture per provider includes a tampered-signature case asserting 401.
- [ ] Test fixture includes a duplicate-event case asserting the second POST returns 200 with no new side effects.

## Anti-patterns

- **JSON-parsed body fed to HMAC** — recomputed signature can never match. Capture raw bytes.
- **`if (sig === expected)`** — variable-time compare. Attacker recovers secret byte-by-byte over millions of probes.
- **Trust payload before verify** — reading `payload.tenant_id` to look up "the right secret" is a chicken-and-egg leak. One secret per endpoint, or look up by provider-account-id (not tenant-controllable).
- **Verification optional in dev** — env-conditional `if (NODE_ENV !== 'prod') skip()`. Ships to prod when someone forgets the conditional. Use a fixture with a valid local signature instead.
- **5xx on application errors** — provider retry storm + your queue grows during the outage. Return 200 + persist + alert; let your own retry policy drive reprocessing.
- **200 on signature mismatch** — invites further forged traffic. 401 is the right signal.
- **One webhook URL across envs** — staging events fire prod side effects. One config + one secret per environment.
- **Logging the full signature header** — leaks the secret over time. Log a prefix excerpt (first 8 chars) or nothing.

## Enforcement

- `<commands-path>/simulate-webhook.md` (slash: `/simulate-webhook` and `/simulate-webhook --tamper`) — replays fixtures with valid + tampered signatures; asserts 401 on tamper, 200 + side-effect on valid, 200 + no-new-side-effect on duplicate.
- `<agents-path>/webhook-reviewer.md` — review gate; greps every webhook handler for raw-body access, constant-time compare, dedupe-by-event-id UNIQUE index, and the 200-on-internal-error policy.
- CI lint MUST reject `req.body.tenantId` / `req.body.userId` / `req.body.customer_id` reads in webhook handlers that occur BEFORE the signature-verification call site (AST dominance check).
- CI lint MUST reject `===` / `==` against a variable named like a signature in webhook code paths (heuristic; flag for review).
- Test fixture per provider MUST include a tampered-signature case asserting 401 — missing test fails CI.
- TODO: `scripts/validate-webhook-handlers.sh` to AST-scan handler files and verify the signature-verify call dominates every other side-effecting call.

## Cross-references

- `<patterns-path>/webhook-flow.md` — generic verify → dedupe → process pattern with response-policy table and code shape.
- `<patterns-path>/payment-integration.md § Webhook handler` — payment-specific instance (Stripe), including reconciliation cron.
- `<commands-path>/simulate-webhook.md` — fixture replay + tampered-signature tool.
- `<agents-path>/webhook-reviewer.md` — review gate.
- `<rules-path>/payment-idempotency.md` — payment-specific idempotency rules building on this.
- `<adr-path>/<NNN>-webhook-secret-rotation.md` — secret rotation policy.
