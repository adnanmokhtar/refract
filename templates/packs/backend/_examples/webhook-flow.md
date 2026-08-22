---
name: webhook-flow
kind: example
pack: backend
---

# Pattern: Webhooks (inbound verification + outbound delivery)

Both directions are subtle and where LLM code fails: signatures compared non-constant-time, body parsed before verify, retries replayed as duplicates, outbound retry-storms on dead endpoints. Mirror the provider's / project's webhook primitive. Cross-pack: stored-replay idempotency → `distributed-systems/idempotency.md`; enqueue-then-ack → `async-job-offload.md`.

## Inbound (you receive)

1. Capture the RAW body before parsing (signatures are over exact bytes).
2. Verify the signature with a **timing-safe** compare, keyed by the provider secret, BEFORE touching the payload → `401` on mismatch.
3. Reject stale/replayed: enforce the timestamp tolerance + dedupe on the provider `event.id`.
4. **Ack fast, process async** — return `2xx` once durably enqueued; do the work in a job.
5. **Status codes — read the provider's doc; retry semantics are NOT universal.** There is no HTTP-wide rule that `4xx` stops a webhook retry. **Stripe retries on any non-2xx, `4xx` included** — for up to three days in live mode — so "return 400 to stop the retries" is simply false there, and a bad-signature `400` will be retried for three days. Other providers never auto-retry at all, which means a `5xx` you returned because your queue was briefly full has silently dropped the event. What IS universal: never return `2xx` for an event you dropped (the one response that definitively stops delivery), and never return `5xx` for a signature failure (on a retrying provider that is an unbounded retry storm against an endpoint that will never accept it). Write the provider's actual policy into `references/<provider>` and make the handler's status choice cite it — a comment saying "400 so it stops retrying" against a provider that retries `4xx` is a bug with a confident comment on it.

## Outbound (you send)

Backoff, jitter, attempt budgets, DLQs, timeouts and worker isolation are **generic delivery mechanics owned by the distributed-systems pack** — read them there rather than keeping a second copy that drifts. Two things are genuinely webhook-shaped and have no owner elsewhere:

1. **Secret rotation is a window, and you cannot close it atomically** — the consumer swaps their stored secret at a moment you neither control nor observe. So: **sign every delivery with BOTH secrets during the window** (several `t=…,v1=…` pairs in one header), document that a consumer must accept a match on *any* offered signature (a consumer who wrote `signatures[0]` breaks exactly when you rotate), and **alert on deliveries still verifying against the old secret** as the deadline nears — that telemetry is the only way to know whether ending the window breaks someone. A rotation with no such signal is a scheduled outage with a nicer name.
2. **Auto-disable is a product decision, not the retry worker's call.** Decide, and write down: what the subscription owner sees and *when* (the most valuable notification is the one sent while the endpoint is still failing and re-enabling is free); who may re-enable and whether queued events replay or are dropped with a documented gap (silent replay of three days of `order.created` into a consumer who reconciled by hand is its own incident); whether one dead endpoint disables the account's others; and whether there is a re-enable ceiling. **The mechanical rule under all of it:** disable and notify are the *same* transition, never two jobs that can drift — a subscription disabled with no notification is indistinguishable, from outside, from your platform silently losing events.

The delivery contract consumers integrate against: sign over raw body + timestamp and treat the canonical string as an API contract (changing it is breaking); at-least-once with a stable `event.id` and say so in your docs; no ordering guarantee — reconcile by `event.id` + a monotonic `sequence`/`created_at`, and never document ordering you do not enforce; version the payload; ship a per-attempt delivery log (status, code, latency) the owner can inspect and replay.

## Detectors (cite-or-halt)

1. Body parsed (`req.body`) before verify, or verify over a re-serialized body.
2. Non-constant-time signature compare (`===`/`.equals()` → use `timingSafeEqual`/`compare_digest`).
3. No replay/timestamp-window + no event-id dedupe.
4. Heavy work between verify and the `2xx` (enqueue then ack).
5. `5xx` on bad signature, or `2xx` on a dropped event.
6. Outbound: a disable (or permanent DLQ) transition that does not emit the owner notification → the owner finds a multi-day gap after the fact. Generic retry hygiene is the distributed-systems pack's detector; flagging it here duplicates a finding against a different owner.
6b. Outbound: a signing path that can emit only one signature per delivery on a provider offering rotation → the rotation window cannot exist, so every rotation is a synchronised deploy on the consumer's side.
7. Outbound: unsigned delivery / no `event.id` for consumer dedupe.

Closure verbs: `report-with-fix` / `report-flagged` (design call — delivery worker + DLQ) / `dismiss` (mTLS not HMAC; internal bus not a webhook).

## Related

`async-job-offload.md`, `multi-tenancy.md`, `distributed-systems/idempotency.md`, `rate-limiting.md`.
