---
name: webhook-flow
kind: pattern
pack: backend
---

# Pattern: Webhooks (inbound verification + outbound delivery)

Every modern SaaS backend receives webhooks (Stripe/GitHub/Slack/payment/messaging providers) and/or sends them. Both directions are subtle and are where LLM-written code fails by default: signatures compared non-constant-time, the body parsed before it's verified, retries replayed as duplicate side-effects, or an outbound retry storm that hammers a dead endpoint. This pattern is the contract for getting both right; mirror the provider's / the project's existing webhook primitive rather than inventing one.

Cross-pack: idempotent *processing* mechanism (stored-replay) is owned by `distributed-systems/ai-patterns/idempotency.md`; the async hand-off (202 + job status) by `async-job-offload.md`; delivery retry/backoff/DLQ mechanics by the distributed-systems resilience patterns. This pattern owns the **webhook-specific** discipline on top of those.

## Inbound — you RECEIVE a webhook

The endpoint is an unauthenticated, internet-exposed side-effect trigger. Treat every request as hostile until the signature verifies.

1. **Capture the RAW body before any parsing.** Signatures are computed over exact bytes — a framework that JSON-parses first (re-serializing, reordering keys) breaks verification. Use the raw-body buffer (`express.raw()`, FastAPI `await request.body()`, Rails `request.raw_post`, Spring `byte[]`/`ContentCachingRequestWrapper`).
2. **Verify the signature with a timing-safe compare**, keyed by the provider's shared secret, BEFORE touching the payload. Reject `401` on mismatch — do not process, do not log the body.
3. **Reject stale/replayed requests.** Enforce the provider's timestamp tolerance (typically ±5 min) and treat the provider's event id as an idempotency key so a redelivery is a no-op (defer the stored-replay mechanism to `idempotency.md`).
4. **Acknowledge fast, process async.** Return `2xx` within the provider's timeout (often 5–10s) the moment the event is durably enqueued; do the real work in a job (see `async-job-offload.md`). Blocking the ack on business logic causes provider-side retries → duplicate events.
5. **Return the status codes the provider expects.** `2xx` = accepted (stop retrying); `4xx` = permanent reject (bad signature/unknown event — stop retrying); `5xx`/timeout = transient (retry). Never return `200` on an internal failure you actually dropped, and never `5xx` on a bad signature (invites infinite retries).
6. **Tenant/account resolution** from the signed payload's account id feeds the tenant context (see `multi-tenancy.md`), only AFTER the signature verifies.

## Outbound — you SEND webhooks (you are the provider)

1. **Sign every delivery** — HMAC-SHA256 over the raw body + a timestamp, in a header (`X-Signature`, `X-Timestamp`); document the scheme so consumers can verify. Support secret rotation (accept two active secrets during a rotation window).
2. **At-least-once delivery, so consumers must be idempotent** — include a stable `event.id` in the payload and tell consumers to dedupe on it.
3. **Retry with exponential backoff + jitter** on transient failures (non-2xx / timeout), with a capped attempt budget. Never a tight retry loop.
4. **Dead-letter + auto-disable.** After the attempt budget is exhausted, move to a DLQ and (after sustained failure) disable the subscription + notify its owner — a permanently-dead endpoint must not be retried forever (retry-storm / cost blowout).
5. **Subscription management** — per-subscription secret, event-type filter, enabled/disabled state, and a **delivery log** (per attempt: status, response code, latency) the owner can inspect + manually replay.
6. **Ordering is not guaranteed** — consumers reconcile by `event.id` + a monotonic `sequence`/`created_at`; do not assume delivery order. Version the payload (`version` field) so the schema can evolve.
7. **Sensible timeouts** on the outbound HTTP call (a few seconds) so one slow consumer doesn't back up the delivery worker.

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix. "Webhooks look insecure" without the cited handler is not a finding.

### 1. Body parsed before signature verified

```
BAD:   const body = req.body;                         // framework already JSON-parsed → raw bytes lost
       verify(sign(JSON.stringify(body)), header)     // re-serialized ≠ original → verify fails or is bypassed
GOOD:  const raw = req.rawBody;                        // express.raw() / request.body() bytes
       if (!verifyHmac(raw, header, secret)) return res.status(401).end()
```
Flag a webhook handler that reads a parsed body (`req.body` / `request.json()`) before verifying, or verifies over a re-serialized body.

### 2. Non-constant-time signature compare

```
BAD:   if (computed === provided) …                    // early-exit string compare → timing oracle
GOOD:  if (crypto.timingSafeEqual(Buffer.from(computed), Buffer.from(provided))) …
```
Flag `==` / `===` / `.equals()` comparing a signature/HMAC/token. Use `timingSafeEqual` / `hmac.compare_digest` / `MessageDigest.isEqual`.

### 3. No replay / timestamp-window protection

Flag a verified handler with no timestamp-tolerance check and no dedupe on the provider event id → a captured request can be replayed. Fix: reject outside the tolerance window + treat event id as an idempotency key.

### 4. Business logic blocks the ack

```
BAD:   await chargeCustomer(evt); await sendEmail(evt); return res.sendStatus(200)   // ack after slow work → provider retries
GOOD:  await queue.add('webhook', evt); return res.sendStatus(202)                    // ack after durable enqueue
```
Flag heavy/external work between signature-verify and the `2xx`. Enqueue then ack.

### 5. Bad signature returns 5xx (or failure returns 2xx)

Flag `500`/`5xx` on a signature mismatch (invites infinite provider retries → return `4xx`), and a `2xx` returned on a path that actually dropped the event.

### 6. Outbound: unbounded / un-jittered retries, no DLQ

Flag an outbound delivery with a tight retry loop, retries with no cap, no exponential backoff + jitter, or no dead-letter / auto-disable for a permanently-failing endpoint.

### 7. Outbound: unsigned delivery / no consumer idempotency key

Flag an outbound webhook with no signature header + timestamp, or a payload with no stable `event.id` for consumer dedupe.

## Closure verbs

- `report-with-fix` — pattern matched at `<file:line>` + the concrete raw-body / timing-safe / enqueue-then-ack / backoff patch.
- `report-flagged` — measured-relevant but the fix is a design call (introduce a delivery worker + DLQ, add subscription management) → surface for ADR.
- `dismiss` — matched but the carve-out applies (provider verifies via mTLS not HMAC; internal-only event bus, not an internet webhook) → documented so the next scan does not re-flag it.

## Related

- `async-job-offload.md` — the enqueue-then-ack hand-off inbound webhooks require.
- `multi-tenancy.md` — resolving tenant from the signed payload.
- `distributed-systems/ai-patterns/idempotency.md` — the stored-replay mechanism for event-id dedupe.
- `rate-limiting.md` — inbound webhook endpoints still need abuse protection.
- `security` pack — secret storage / rotation.
