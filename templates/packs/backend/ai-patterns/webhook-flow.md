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
5. **Return the status codes the provider expects — and read the provider's doc, because retry semantics are NOT universal.** There is no HTTP-wide rule that `4xx` stops a webhook retry; each provider decides.
   - **Stripe retries on any non-2xx, `4xx` included** — ["Stripe attempts to deliver events to your destination for up to three days with an exponential back off in live mode"](https://docs.stripe.com/webhooks), and its own troubleshooting table lists `4xx` responses as delivery failures alongside `5xx`. So the "return 400 to stop the retries" folk rule is simply false there: a bad-signature `400` will be retried for three days.
   - **Some providers never auto-retry at all**, which means a `5xx` you returned because your queue was briefly full has silently dropped the event.
   - **What IS universal**, whatever the provider does: never return `2xx` for an event you actually dropped (that is the one response that definitively stops delivery), and never return `5xx` for a signature failure (on a retrying provider that invites an unbounded retry storm against an endpoint that will never accept it).

   Write the provider's actual policy into `references/<provider>` or the subscription record, and make the handler's status choice cite it. A handler whose comment says "400 so it stops retrying" against a provider that retries `4xx` is a bug with a confident comment on it.
6. **Tenant/account resolution** from the signed payload's account id feeds the tenant context (see `multi-tenancy.md`), only AFTER the signature verifies.

## Outbound — you SEND webhooks (you are the provider)

**Most of outbound delivery is not webhook-specific and this pattern does not own it.** Backoff, jitter, attempt budgets, DLQs, timeouts and worker isolation are generic delivery mechanics owned by the **distributed-systems** pack's resilience patterns — restating them here would give you a second, drifting copy of a contract that already exists. Read them there. Two things are genuinely webhook-shaped, get decided wrong, and have no owner anywhere else:

### 1. Secret rotation is a *window*, and both halves are yours to build

A per-subscription secret is table stakes. What is not is the fact that **you cannot rotate it atomically** — the consumer changes their stored secret at a moment you do not control and cannot observe. So rotation is a state, not an event, and the mechanics follow from that:

- **Sign every delivery with BOTH secrets during the window**, as two values in the signature header (the shape most providers converge on: one header, several `t=…,v1=…` pairs). A consumer verifying against either one passes. Signing with only the new secret makes the rotation a synchronised deploy you are asking a stranger to perform.
- **The consumer's verification loop must accept a match on ANY offered signature** — say this in your consumer docs explicitly, because a consumer who wrote `signatures[0]` against your single-signature era breaks precisely when you rotate, and the failure lands on your incident channel.
- **The window has to end, and nothing ends it automatically.** Decide the length up front (it is a product decision about how long a consumer may ignore an email), show the window's expiry in the subscription UI, and **alert on deliveries still verifying against the old secret as the deadline approaches** — that signal is the only way to know whether ending the window will break someone. Without it, "rotation complete" means "we stopped sending the old one and found out afterwards."
- A rotation with no telemetry on which secret is being used is not a rotation, it is a scheduled outage with a nicer name.

### 2. Auto-disable is a product decision wearing an infrastructure costume

Every provider eventually disables an endpoint that has failed for long enough — that part is not the decision. The decision is what a *human on the other side* experiences, and it is routinely left to whoever wrote the retry worker:

| Question | Why it is not the worker's call |
|---|---|
| **What does the subscription owner see, and when?** A dashboard state they have to go looking for, or an email at the moment of disabling — or, better, one *before* it, while the endpoint is still failing and re-enabling costs nothing. | The most valuable notification is the one sent before the data stops flowing. A worker that only fires on disable has already let the gap open. |
| **Who may re-enable, and what happens to the events that arrived while it was off?** Replayed from the DLQ, or dropped with a documented gap? | These are opposite products. Silent replay of three days of `order.created` into a consumer that has since reconciled by hand is its own incident. Say which one you do, in the docs, before anyone needs to know. |
| **Does disabling one endpoint disable the account's others?** | Almost always no — but if the failure is a whole-domain outage, N subscriptions each burning their full retry budget against the same dead host is a self-inflicted load problem. |
| **Is there a re-enable ceiling?** An endpoint re-enabled five times in a week is not flaky, it is abandoned. | Without a ceiling you have built a permanent retry loop with a human in it. |

**The one mechanical rule under all of that:** the disable decision and the notification must be the *same* transition, not two jobs that can drift apart. A subscription disabled with no notification sent is indistinguishable, from the outside, from your platform silently losing events.

### 3. The delivery contract itself (the parts consumers integrate against)

- **Sign over the raw body + a timestamp**, publish the scheme, and treat it as an API contract — changing the canonical string is a breaking change (`api-versioning.md`).
- **At-least-once, so consumers must be idempotent** — carry a stable `event.id` and say so in your docs. This is the one line of your documentation that prevents the most consumer-side bugs.
- **Ordering is not guaranteed** — consumers reconcile by `event.id` plus a monotonic `sequence`/`created_at`. Never document ordering you do not actually enforce; a consumer that believes you will build on it.
- **Version the payload** (`version` field) so the schema can evolve without a second endpoint.
- **Delivery log** — per attempt: status, response code, latency — inspectable and manually replayable by the subscription owner. This is what turns "your webhooks are broken" into a five-minute conversation.

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

### 6. Outbound: auto-disable with no owner-facing transition

Flag a delivery worker that disables (or permanently DLQs) a subscription without emitting the owner notification in the same transition → the owner discovers a multi-day data gap after the fact. Cite the disable site and the absence of the notification. Generic retry hygiene — cap, backoff, jitter, DLQ — is the distributed-systems pack's detector, not this one's; flagging it here produces a duplicate finding against a different owner.

### 6b. Outbound: single-secret rotation

Flag a signing path that can emit only one signature per delivery, on a provider that offers secret rotation → the rotation window cannot exist, so every rotation is a synchronised deploy on the consumer's side. Cite the signing call.

### 7. Outbound: unsigned delivery / no consumer idempotency key

Flag an outbound webhook with no signature header + timestamp, or a payload with no stable `event.id` for consumer dedupe.

## Closure verbs

Exactly one verb per finding. What each means for *this* pattern:

- `report-with-fix` — pattern matched at `<file:line>` + the concrete raw-body / timing-safe / enqueue-then-ack / backoff patch.
- `report-flagged` — measured-relevant but the fix is a design call (introduce a delivery worker + DLQ, add subscription management) → surface for ADR.
- `dismiss` — matched but the carve-out applies (provider verifies via mTLS not HMAC; internal-only event bus, not an internet webhook) → documented so the next scan does not re-flag it.

## Related

- `async-job-offload.md` — the enqueue-then-ack hand-off inbound webhooks require.
- `multi-tenancy.md` — resolving tenant from the signed payload.
- `distributed-systems/ai-patterns/idempotency.md` — the stored-replay mechanism for event-id dedupe.
- `rate-limiting.md` — inbound webhook endpoints still need abuse protection.
- `security` pack — secret storage / rotation.
