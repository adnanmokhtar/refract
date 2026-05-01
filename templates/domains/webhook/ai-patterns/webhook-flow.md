---
name: webhook-flow
description: "Pattern: Inbound webhook flow (verify → dedupe → process)"
kind: ai-pattern
---

# Pattern: Inbound webhook flow (verify → dedupe → process)

> **Hard rule** — HMAC-verify the RAW body (pre-JSON-parse) in constant time before any processing; dedupe by the provider's event id with a UNIQUE constraint; return 200 on internal failures (after logging) so the provider doesn't retry-storm — but 401 on signature mismatch.

**When to apply**
- Any inbound webhook from an external provider (Stripe, GitHub, Slack, Twilio, Meta, GitLab, Shopify, custom SaaS).
- Provider retries aggressively on non-2xx (most do — 5–10s timeout, retry for hours/days).
- Per-message idempotency is required because the provider may deliver the same event more than once.

**When NOT to apply**
- Internal system-to-system webhooks under your control — use mTLS or a private signing scheme tuned to your latency budget.
- Outbound delivery callbacks where the signature scheme differs from the inbound one (treat as separate pattern; same shape, different secret + algo).
- One-shot fire-and-forget pings where lost delivery is acceptable (rare in practice).

**Halt conditions / mandatory cites**
- Cite the raw-body capture middleware at `<path:line>` (`express.raw()` / `@fastify/raw-body` / `request.body()` on a stream-able framework). JSON-parsed body fed to HMAC = halt.
- Cite the constant-time compare (`crypto.timingSafeEqual` / `hmac.compare_digest` / `MessageDigest.isEqual` / equivalent) at `<path:line>`. `===` / `==` compare = halt — leaks signature byte-by-byte.
- Cite the provider-event-id `UNIQUE` constraint + insert-or-skip path at `<path:line>` (`ON CONFLICT DO NOTHING` / `INSERT IGNORE` / equivalent). No dedupe = duplicate processing.
- Cite the per-event try/catch inside any batch loop at `<path:line>`. One bad event dropping the batch = halt.
- Grep ban: "webhook is signed" without file:line for raw-body capture, timing-safe compare, dedupe, and the 200-on-internal-error policy.

## Why

External webhooks are an untrusted, retry-heavy, partially-ordered delivery channel that often runs side-effects on your critical-path data (payments, account changes, message ingest). Three failure modes recur:

1. **Forged payloads** — anyone with the URL can POST. Without HMAC verification of the RAW bytes, an attacker mints "events" you process.
2. **Duplicate delivery** — providers retry on transient 5xx, on network blips, on their own bugs. Without idempotency, you charge twice / send twice / book twice.
3. **Retry storms** — return non-2xx during an internal outage, the provider retries faster, your queue backs up, the outage gets worse. The fix is to acknowledge fast (200) and handle the failure internally.

This pattern is the universal shape: VERIFY first, DEDUPE second, PROCESS third, ACK fast.

## Endpoints

- **`GET /webhooks/<provider>` — verification handshake** (when the provider requires one). Returns the challenge if a static verify token matches `<PROVIDER>_VERIFY_TOKEN` (env). Required by Meta-graph providers; optional/absent for Stripe, GitHub, Twilio, Slack.
- **`POST /webhooks/<provider>` — event ingest.** Protected by the signature guard. Always returns **200** for any legitimate (signed) request — even on internal error. Returns **401** only on signature mismatch.

## HMAC verification (non-negotiable)

The provider signs the raw body with `<PROVIDER>_APP_SECRET` and sends a header (`X-Hub-Signature-256` / `Stripe-Signature` / `X-Twilio-Signature` / `X-Slack-Signature` / `X-GitHub-Signature-256` / etc.). The handler MUST:

1. Capture the **raw body bytes** before any JSON parse. Most frameworks consume the body during routing — wire a raw-body middleware that stashes `req.rawBody: Buffer` (or equivalent) BEFORE the JSON parser runs.
2. Recompute `HMAC-<algo>(rawBody, <PROVIDER>_APP_SECRET)` per the provider's spec. Algorithm varies — `sha256` is the modern default; some providers (older Slack, older Stripe) use a more involved scheme with timestamp + version prefix.
3. Compare against the provided signature in **constant time** (`crypto.timingSafeEqual` / equivalent). Variable-time compare leaks signature byte-by-byte.
4. On mismatch: return 401 + log `webhook_hmac_mismatch` with source IP, endpoint, and a signature prefix excerpt. **Do NOT process the body.** Do not read tenant/user fields from it. Do not persist anything.

This logic belongs in a guard / middleware — NEVER inlined in feature handlers. See `<rules-path>/webhook-signature-verification.md` for the full checklist.

## Always return 200 (with care)

Most providers retry aggressively on non-2xx — Stripe up to 3 days, Meta in waves, GitHub hourly for 24h. To avoid retry storms during an internal outage:

| Situation | Response | Why |
|---|---|---|
| HMAC verification failed | **401** | Deliberately rejecting — we don't want the provider retrying forged payloads. |
| Tenant resolution failed (no tenant for the inbound id) | **200** + log | Provider can't fix this; retries don't help. Investigate internally. |
| Downstream service timeout | **200** + log + persist event | Reprocess from the persisted row; don't lean on provider retries. |
| Database unavailable | **5xx** | Provider retry IS the right behaviour here — we expect to be back. |
| Validation failure on event payload (unrecognized type, malformed) | **200** + log | Persist + classify; don't bounce. |

**Mental model**: 5xx means "I will be able to handle this if you retry"; 200 means "I have it (or have decided I can't ever handle it)"; 401 means "I refuse this on auth grounds." Anything in between produces retry-storm or duplicate processing.

## Idempotency (dedupe by provider event id)

Every provider exposes a unique id per event:

| Provider | Field | Where |
|---|---|---|
| Stripe | `event.id` (`evt_*`) | top-level body |
| GitHub | `X-GitHub-Delivery` | header |
| Twilio | `MessageSid` / `CallSid` | body params |
| Meta (WA / IG / Messenger) | `messages[].id` (e.g. `wamid.*`) | nested in `entry[].changes[].value.messages` |
| Slack | `event_id` | top-level body |
| Shopify | `X-Shopify-Webhook-Id` | header |

**Required:**
- A `webhook_events` table (or per-provider table) with `(provider, event_id) UNIQUE`.
- INSERT path uses `ON CONFLICT DO NOTHING` / `INSERT IGNORE` / equivalent — atomic; never check-then-insert (TOCTOU race under retry).
- On conflict: log `webhook_duplicate` at debug level, return 200, do not re-fire side effects.
- Process the event ONLY when the insert produced a fresh row.

```text
verifySignature(rawBody, signatureHeader)        // 401 on fail
  ↓
fresh = events.recordOnce(provider, eventId, body)   // ON CONFLICT DO NOTHING
  ↓
if (!fresh) return 200                            // duplicate, already handled
  ↓
processEvent(body)                                // your side-effect logic
  ↓
return 200
```

Side-effect endpoints called inside `processEvent` (DB upserts, external API calls) should themselves be idempotent — `UPDATE WHERE status != 'final'`, provider idempotency keys forwarded — so even if a worker retries the persisted row, you don't double-charge / double-email / double-fulfil.

## Sync vs. async processing

Two shapes; pick by the provider's timeout and your processing budget:

**Sync (verify → dedupe → process → 200)** — appropriate when:
- Provider timeout is generous (Stripe: 10s, GitHub: 10s, Slack: 3s).
- Processing fits comfortably under that budget (typically < 1s p95).
- No queue / worker infra yet.

**Async (verify → dedupe → enqueue → 200; worker handles)** — required when:
- p95 processing exceeds the provider timeout.
- Processing involves additional external calls (LLM, fulfilment, ESP) with their own timeouts.
- You want to absorb provider retry-storms into a queue you can drain.

The async shape just inserts the event row + enqueues a worker job (`<queue>.add('process-<provider>-event', { eventId })`) before returning 200. The worker reads the persisted body, processes idempotently, marks the row processed.

**Do NOT introduce a queue prematurely** — adding BullMQ / SQS / Sidekiq before a measured bottleneck is overhead. Start sync; move to async when p95 demands it.

## Bulk batches

Some providers (Meta, Slack `event_callback`, custom) deliver multiple events in one payload. Required behaviour:

- Iterate the events array; each event gets its OWN idempotency check (its own row in `webhook_events`).
- Each event's processing wraps in its own `try/catch` — a failure on event #2 must NOT skip events #3..N.
- Log per-event outcome; aggregate the response as 200 with no further detail (providers don't read response bodies).

Pattern:

```text
for (const event of body.events) {
  try {
    const fresh = await events.recordOnce(provider, event.id, event)
    if (fresh) await processEvent(event)
  } catch (err) {
    logger.error({ provider, eventId: event.id, err }, 'webhook_event_failed')
    // continue — do not rethrow, do not skip remaining events
  }
}
return 200
```

## Tenant resolution

Webhooks usually carry a provider-side identifier (a phone number id, a Stripe account, a GitHub installation id) that maps to ONE of your tenants. Required:

- Resolve tenant AFTER signature verification — never before. Reading `tenant_id` / `user_id` from an unverified payload trusts the attacker.
- Wrap the per-event processing in `<tenant-context>.run({ tenantId }, () => processEvent(...))` so downstream repos / queues / loggers all observe the right tenant.
- If the provider-id has no tenant: log `tenant_not_found`, return 200, alert internally. Don't 4xx — the provider can't fix it.

## Payload extraction

The shape varies wildly. Resist the urge to read deep nested fields directly in the controller:

- Define a per-provider `<Provider>Event` discriminated union (typed by `event.type` / `change.field` / etc.).
- The controller's job is: verify, dedupe, persist raw, hand off to a typed processor.
- The processor narrows on the discriminant and invokes the right handler.
- Unknown event types log `unsupported_event_type` and return 200 (don't 4xx — providers add new types over time).

## Error response policy (reference table)

| Failure mode | Response | Log | Side effect |
|---|---|---|---|
| HMAC mismatch | 401 | `webhook_hmac_mismatch` | none — do not persist |
| Verify token mismatch (handshake) | 403 | `webhook_verify_token_mismatch` | none |
| Duplicate event id | 200 | `webhook_duplicate` (debug) | none — already processed |
| Tenant not resolvable | 200 | `tenant_not_found` (warn) | persist event row, alert |
| Downstream API timeout | 200 | `webhook_downstream_timeout` (error) | persist + retry async |
| Validation error in payload | 200 | `webhook_payload_invalid` (warn) | persist + alert |
| Database write failed | 5xx | `webhook_db_error` (error) | provider retries — that's OK |
| Unknown event type | 200 | `unsupported_event_type` (info) | persist + skip |

## Testing

- **Unit**: signature-verifier test with fixed body + fixed secret + known-good + known-bad signatures; assert pass/fail and constant-time behaviour where the framework permits.
- **Integration**: replay a fixture payload at the running app via `<commands-path>/simulate-webhook.md`; assert the dedupe row appears and side effects fire exactly once.
- **Tampered-body case**: flip one byte of the body before signing, assert 401.
- **Duplicate case**: replay the same fixture twice, assert the second returns 200 with no new side effects.
- **Never** call the live provider API from tests — fixtures only, sanitised, no real keys.

## Common mistakes

- **JSON-parsed body fed to HMAC.** Most frameworks parse JSON before the handler runs; the recomputed signature will never match the provider's signature on the raw bytes. Wire a raw-body middleware specifically.
- **`if (sig === expected)` compare.** Variable-time string equality. An attacker can recover the secret byte-by-byte over millions of requests by measuring response time. Use the platform's constant-time primitive.
- **Signature over a re-serialised body.** "I'll just `JSON.stringify` the parsed body and HMAC that" — round-tripping changes whitespace, key order, number formatting. Sign / verify the original bytes only.
- **Skipping verification "in dev".** Ships to prod when someone forgets the env-conditional. Use a dev fixture POST with a valid local signature; don't bypass.
- **Trusting payload fields before verify.** Reading `payload.tenant_id` to decide which secret to verify against is a chicken-and-egg leak. Either use one-secret-per-endpoint or look up the secret keyed by provider-account-id (not tenant-controlled).
- **Returning 5xx on application errors.** Provider retries aggressively → during your outage, the queue grows. Return 200 + persist + alert; let your own retry policy drive reprocessing.
- **Returning 200 on signature failure.** "We'll just log it" — invites further forged traffic. 401 is the right signal.
- **One try/catch around the whole batch.** First bad event drops the rest. Per-event try/catch inside the loop.
- **Storing raw payloads with secrets in logs.** Some providers include access tokens in the payload (or in retry headers). Persist the body in the DB (encrypted column for long-retention) and log only `event_id` + `provider`.
- **Webhook URL shared across environments.** Dev, staging, and prod sharing one provider config = test events trigger prod side effects. One webhook config per environment, distinct secrets.
- **No reconciliation cron.** Webhooks WILL be missed (provider outages, your outages, network partitions). A daily reconciliation job that pulls the provider's event list and compares against your `webhook_events` table catches these. See `<patterns-path>/payment-integration.md § Reconciliation` for the shape.

## Cross-references

- `<rules-path>/webhook-signature-verification.md` — the universal hard-rule list (raw body, constant-time, dedupe, secret hygiene).
- `<commands-path>/simulate-webhook.md` — local replay tool for fixtures + tampered-signature tests.
- `<agents-path>/webhook-reviewer.md` — review gate enforcing this pattern.
- `<patterns-path>/payment-integration.md § Webhook handler` — payment-specific instance of this pattern (Stripe), including reconciliation cron.
- `<patterns-path>/queue-producer-consumer.md` — async-shape worker semantics (idempotency, DLQ, observability) when you move processing off the hot path.
- `<adr-path>/<NNN>-webhook-secret-rotation.md` — secret-rotation policy (when authored).
