---
name: payment-idempotency
description: Payment idempotency
kind: rule
---

# Payment idempotency

## Hard rule

Every mutating payment endpoint MUST require an `Idempotency-Key` header, MUST forward an idempotency key to the provider derived from a stable business id, and MUST dedupe webhooks by the provider's event id with a UNIQUE constraint. Retry without the original key is FORBIDDEN. Card numbers / CVV MUST NEVER touch our storage. Amounts MUST be computed server-side; client-supplied amounts MUST NEVER be trusted. Money MUST be integer minor units with a currency tag — never floats.

Every payment-affecting request is idempotent. Double-charges are user-visible, refunds are expensive, trust erodes.

## Must

- **Client idempotency**: every mutating payment endpoint accepts an `Idempotency-Key` header (UUID per logical action). Server stores first result by key — subsequent requests with same key return the same response without re-executing. Mismatched request body under the same key → 409 Conflict (client bug).
- **Provider idempotency**: pass an idempotency key on every mutating provider API call. Key derives from a stable business id (`charge:order_<id>:v<version>`, `refund:<orderId>:<refundCount + 1>`), never from `uuid()` per attempt.
- **Webhook idempotency**: dedupe by the provider's event id with a UNIQUE constraint on `(provider, event_id)`. Insert via `ON CONFLICT DO NOTHING` (or equivalent) — atomic; never check-then-insert.
- **Server-computed amounts**: re-derive `amount` server-side from the loaded order / invoice / quote. Client-supplied amount is for UX preview only.
- **Server-side currency tag**: every monetary value carries `(amount_minor INTEGER, currency CHAR(3))`. Arithmetic across currencies throws.
- **Idempotency store TTL**: 24h typical for the (key → response) cache; document the TTL in code.
- **Reconciliation cron**: a daily job pulls the provider's recent charges and compares against the local DB; missing-in-DB / amount-mismatch / missing-at-provider rows trigger an alert.
- **Webhook signature verified before any side effect** (see `<rules-path>/webhook-signature-verification.md`) — even idempotency-key checks should not run on unverified payloads.

## Must not

- Mutating payment endpoint without `Idempotency-Key`.
- Retry a failed provider call without the original key (risk of double-charge).
- Idempotency key derived from `uuid()` / `Date.now()` / random — defeats the mechanism on retry.
- Charge / refund / capture from a `GET` request.
- Trust amount / currency / discount from the client.
- Store card numbers, CVV, full PAN, or full magnetic stripe data anywhere — escalates PCI scope to the entire app.
- Use floats for monetary arithmetic. `0.1 + 0.2 !== 0.3` becomes a real reconciliation bug at scale.
- Run side effects (mark paid, send receipt, fulfil order) before webhook signature verification + dedupe insert.
- Allow operator overrides ("manually mark as paid") without an audit log entry tied to a user id.

## Should

- Wrap the provider SDK behind a project-internal `<PaymentGateway>` interface so vendor changes are a single-file refactor.
- Cap retry attempts (≤ 3 for money-moving ops) with exponential backoff; never retry without the key.
- Treat 3DS / SCA / `requires_action` as a first-class result of `charge()` — UI completes via `clientSecret`; backend marks pending.
- Persist webhook events to a `webhook_events` table BEFORE enqueuing processing — the row IS the dedupe primitive.
- Log structured `{ provider, eventId, idempotencyKey, declineCode, latencyMs }` on every charge / refund / capture / webhook receive.
- Monitor reconciliation drift: webhook miss rate, dashboard-only operator overrides, amount-mismatch counts. Non-zero drift is a bug, not noise.

## Review checklist (PRs touching payment endpoints / webhooks / amounts)

- [ ] Mutating route reads `Idempotency-Key` header and stores first response keyed by it.
- [ ] Provider call forwards an idempotency key derived from stable business state.
- [ ] Webhook handler verifies signature on raw body BEFORE reading any field.
- [ ] Webhook dedupe uses `(provider, event_id) UNIQUE` + atomic insert-or-skip.
- [ ] Amount is recomputed server-side from the loaded entity; client `amount` is ignored or asserted equal as a sanity check.
- [ ] Monetary fields are integer minor units + currency tag — no floats, no strings, no `Number` math.
- [ ] No PAN / CVV / full card data anywhere (DTO, log, storage, analytics event).
- [ ] Reconciliation cron exists + alerts on drift; missing run > 36h pages on-call.
- [ ] Any new "manual mark as paid" path is audit-logged with user id + reason.

## Anti-patterns

- **Idempotency-key per attempt** — `uuid()` for each retry. The mechanism does nothing.
- **Trust client amount** — `POST /charge { amount: 1 }` for a $1000 order. Always recompute.
- **Float arithmetic** — `total * 1.1` for tax. Fractional cent → reconciliation drift over millions of orders.
- **Webhook double-side-effect** — `charge.succeeded` retried by provider → email + fulfilment fire twice. Dedupe by `event.id` BEFORE side effects.
- **Refund accounting drift** — operator refunds via provider dashboard → DB still says paid → reports lie. Block dashboard refund route via permissions; force operators through the app endpoint.
- **Generic decline error** — "Payment failed, try again" on `card_declined: insufficient_funds`. Surface the provider's decline code in user-readable form.
- **Capture window expired** — auth then sit on it for 10 days. Most providers expire auths in 7. Either capture early or re-auth.
- **PAN displayed in admin** — last-4 + brand + exp from the provider response is enough; full PAN escalates PCI scope.
- **Lost dispute data** — "old order, account deleted" → 90 days later: chargeback → no shipping evidence → lose. Retain dispute-window data even when the account is "deleted" (crypto-shred PII; keep transaction records).

## Enforcement

- `<commands-path>/replay-charge.md` (slash: `/replay-charge`) — replays sanitised provider webhook fixtures locally to verify dedupe + signature + idempotency-key paths end-to-end.
- `<agents-path>/payment-reviewer.md` — review gate hard-failing on missing `Idempotency-Key` extraction, missing provider key forwarding, missing webhook dedupe, float arithmetic, client-trusted amounts.
- CI lint MUST reject any DTO / DB-column field name matching `card_number` / `cvv` / `pan` / `cvc` / `track[12]_data`.
- CI lint MUST reject `messages.create(` / `paymentIntents.create(` / equivalent without a passed `idempotencyKey`.
- Nightly reconciliation job MUST run; missing run for > 36h pages on-call.
- TODO: `scripts/validate-payment-idempotency.sh` to AST-walk payment controllers and assert every mutating route extracts `Idempotency-Key` before calling the provider AND that the provider call passes an idempotency key.

## Cross-references

- `<patterns-path>/payment-integration.md` — provider-agnostic adapter, Money type, charge/refund/webhook code shapes, reconciliation cron.
- `<rules-path>/webhook-signature-verification.md` — universal webhook signature rule (raw body, constant-time compare, dedupe).
- `<patterns-path>/webhook-flow.md` — generic verify → dedupe → process inbound shape.
- `<commands-path>/replay-charge.md` — fixture-replay tool.
- `<agents-path>/payment-reviewer.md` — review gate.
- `<adr-path>/<NNN>-payment-provider-choice.md` — ADR pinning the chosen provider + scope of escape hatches.
