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
5. Status codes: `2xx`=accepted (stop retries), `4xx`=permanent reject (bad sig/unknown), `5xx`/timeout=transient (retry). Never `5xx` on a bad signature; never `2xx` on a dropped event.

## Outbound (you send)

1. Sign every delivery (HMAC-SHA256 over raw body + timestamp header); support secret rotation.
2. At-least-once → include a stable `event.id`; consumers dedupe on it.
3. Retry with exponential backoff + jitter, capped budget.
4. DLQ + auto-disable a permanently-dead endpoint (no retry-storm).
5. Subscription mgmt: per-sub secret, event filter, enabled state, delivery log + manual replay.
6. No ordering guarantee — reconcile by `event.id` + sequence; version the payload.

## Detectors (cite-or-halt)

1. Body parsed (`req.body`) before verify, or verify over a re-serialized body.
2. Non-constant-time signature compare (`===`/`.equals()` → use `timingSafeEqual`/`compare_digest`).
3. No replay/timestamp-window + no event-id dedupe.
4. Heavy work between verify and the `2xx` (enqueue then ack).
5. `5xx` on bad signature, or `2xx` on a dropped event.
6. Outbound: unbounded/un-jittered retries, no DLQ/auto-disable.
7. Outbound: unsigned delivery / no `event.id` for consumer dedupe.

Closure verbs: `report-with-fix` / `report-flagged` (design call — delivery worker + DLQ) / `dismiss` (mTLS not HMAC; internal bus not a webhook).

## Related

`async-job-offload.md`, `multi-tenancy.md`, `distributed-systems/idempotency.md`, `rate-limiting.md`.
