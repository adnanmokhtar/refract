# Pattern: WhatsApp webhook flow

## Endpoints

- `GET /webhooks/whatsapp` — Meta verification handshake. Returns the `hub.challenge` if `hub.verify_token` matches `WHATSAPP_VERIFY_TOKEN`. No auth other than the token compare. Must be 200 within 20s or Meta marks the webhook invalid.
- `POST /webhooks/whatsapp` — message events. Protected by `WhatsAppHmacGuard`. Always returns **200** (even on internal error — see below).

## HMAC verification (non-negotiable)

Meta signs the raw request body with `WHATSAPP_APP_SECRET` and sends `X-Hub-Signature-256: sha256=<hex>`. We must:

1. Capture the **raw body bytes** before JSON parse (Nest's default parser consumes them). Use a `rawBody` body-parser or a custom middleware stashing `req.rawBody: Buffer`.
2. Recompute `HMAC-SHA256(rawBody, WHATSAPP_APP_SECRET)` and hex-encode.
3. Compare in **constant time** (`crypto.timingSafeEqual`).
4. On mismatch: 401 + log `webhook_hmac_mismatch` with the incoming signature prefix. Do NOT process the body.

This belongs in `WhatsAppHmacGuard`. See `rules/webhook-signature-verifier.md` for the full checklist.

## Always return 200 (with care)

Meta retries aggressively on non-2xx. To avoid retry storms:

- HMAC failure → **401** (deliberately rejecting — we don't want Meta retrying a forged payload).
- Everything else (tenant not found, Claude timeout, DB error) → respond **200** after logging, so Meta doesn't retry. We handle the failure internally.

## Idempotency

Meta may deliver the same message more than once (retries after our transient 5xx, rare but real). We use the Meta-provided message id:

- `messages.wa_message_id TEXT UNIQUE` where `direction = 'inbound'`.
- On INSERT conflict: skip processing (`ON CONFLICT DO NOTHING`), log `webhook_duplicate`, still return 200.

## Payload shape (what we extract)

Meta's payload is nested. The fields we care about in P1:

```
body.entry[0].changes[0].value = {
  metadata: { phone_number_id, display_phone_number },
  contacts: [{ wa_id, profile: { name } }],
  messages: [{ from, id, timestamp, type: 'text', text: { body } }]
}
```

In P1 we only process `type === 'text'`. Everything else → log `unsupported_message_type`, 200. Voice / image / location come in P5.

## Bulk batches

Meta may send multiple messages in one payload. Iterate `messages[]`, process each inside its own try/catch — a failure on message #2 shouldn't skip message #3. All still under the same tenant context.

## Error handling

| Situation | Action |
|---|---|
| HMAC mismatch | 401, log, done. |
| `phone_number_id` → no tenant | Log `tenant_not_found`, 200. |
| Claude timeout | Log, persist inbound row with `status='received'`, skip outbound, 200. |
| WhatsApp send fails | Persist outbound with `status='failed'`, retry once synchronously, give up, 200. |
| DB down | 500 — Meta will retry, that's OK here. |

## What NOT to do in P1

- **No queue.** Process synchronously. Adding BullMQ before a bottleneck exists is premature (ADR 0001 reasoning — Phase 1 bias). Move behind a queue in P4 when p95 demands it.
- **No deduplication cache in Redis** — the unique constraint on `wa_message_id` is enough at P1 volume.
- **No ack webhooks out to tenants.** Phase 2+.

## Testing

- Unit: `WhatsAppHmacGuard.spec.ts` with fixed body + fixed secret + known signature; assert pass/fail.
- E2E: `test/webhook.e2e-spec.ts` — fire a sample payload at the running app, assert message rows created. Use a fixture from `fixtures/whatsapp/text-message.json` and `/simulate-webhook` command to replay it.
- Never call the real Meta API from tests.
