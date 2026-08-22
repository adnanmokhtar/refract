---
name: async-job-offload
description: 'Pattern: Async Job Offload (202 Accepted + status URL, job-status state machine, result TTL)'
kind: ai-pattern
pack: backend
---

# Pattern: Async Job Offload

> **Hard rule:** Work that exceeds **this service's** request hot-path budget (derived — see § Deriving the budget, never imported) or depends on a flaky upstream MUST be enqueued, not run inline — the endpoint returns `202 Accepted` + a job id + a `Location` / status URL, and the client polls (or is webhooked) for a terminal state. A controller that blocks on slow work caps your throughput at (workers ÷ job-time) and makes p99 hostage to the slowest dependency. This file owns the HTTP submit/status CONTRACT; the queue/consumer mechanics (visibility timeout, DLQ, redrive) are owned by the distributed-systems pack.

**When to apply**
- Report/export generation, video/image processing, bulk import, ML inference, third-party fan-out — anything measured (not guessed) to exceed the hot-path budget.
- Work that must survive a request timeout, a client disconnect, or a deploy mid-flight.
- An operation whose retry should not re-run the whole HTTP request (the job is the unit of retry).

**When NOT to apply**
- Fast, deterministic work under the budget — inline is simpler; don't add a queue for a 20ms call.
- Work the client genuinely needs synchronously to proceed (it blocks the user's next step and can't show a "processing" state) — optimize it instead, or stream partial results (`response-streaming.md`).
- Fire-and-forget telemetry — that's an event, not a job with a status the client tracks.

**Halt conditions / mandatory cites**
- Proposing an offload MUST cite the measured/expected latency at `<path:line>` that exceeds the budget — don't queue work that's already fast.
- A controller doing synchronous work over the derived CPU budget, or a slow/flaky external call inline (no offload), MUST be cited — with the derived budget and its inputs alongside the measurement, so the reader can check the arithmetic rather than trust the verdict.
- A `202` response with no `Location` / status path is incomplete — the client can't find the result.
- A job-submit endpoint with no idempotency key MUST be cited — a client retry would enqueue a duplicate job.

## Deriving the budget (do not import one)

This pattern's halt condition makes you cite a measurement against a budget, and that is only honest if the budget is yours. A figure quoted without your telemetry behind it is a guess wearing a MUST — the failure this pack names in `rate-limiting.md` (*"Do not import a number for this"*) and `agent-callable-api.md`. So derive it, from whichever of these two you can actually measure today. They answer different questions and a service usually fails one long before the other.

**1. The latency derivation — "does this fit in the response?"**

```
hot-path budget  =  the endpoint's p99 latency objective
                 −  time already spent in the rest of the handler (auth, validation, the DB reads
                    this work does not replace, serialisation)
                 −  headroom for the tail you do not control (GC pause, cold connection, a
                    retried DB call)
```

Everything left is what this unit of work may take. If the subtraction leaves nothing, the objective is the finding — you cannot offload your way out of a handler that is already over budget before the slow part starts.

**2. The throughput derivation — "does this fit in the fleet?"** Usually the binding one, and the one that produces an outage rather than a slow page:

```
sustainable RPS per instance  =  concurrent request slots  ÷  mean job wall-time
```

Slots is workers/threads for a thread-per-request runtime, or the event loop's practical in-flight ceiling for an async one. When that number drops below peak RPS ÷ instances, the work must move off the request path regardless of what the latency objective says — you have run out of capacity, not out of time. This is why **wall-clock, not CPU time, is the number that matters on a thread-per-request stack**: a handler blocked on a slow upstream is occupying a slot while using no CPU at all, and a CPU-time budget scores it as free.

**Where the CPU-time budget applies instead:** a single-threaded event loop, where CPU work blocks *every* concurrent request rather than one. There the budget is per-tick and much smaller than any wall-clock figure, because the cost is paid by the p99 of unrelated traffic.

**If you have neither measurement, say so.** Write `budget: NOT DERIVED` in the proposal and offload on the qualitative trigger instead — an unbounded input, a third-party dependency, or work that must survive a deploy. Those three are decidable without numbers. What is not acceptable is a borrowed threshold presented as this service's, because the halt condition above then makes every future proposal cite a fiction.

## HTTP contract

```
POST /reports
  Idempotency-Key: 9f1c...            (client-generated; a retry returns the SAME jobId)
  { ...params }
→ 202 Accepted
  Location: /jobs/4271
  { "jobId": "4271", "status": "queued", "statusUrl": "/jobs/4271" }

GET /jobs/4271
→ 200 OK
  { "jobId": "4271", "status": "running", ... }          (poll; honor Retry-After for backoff)

GET /jobs/4271   (later)
→ 200 OK
  { "jobId": "4271", "status": "succeeded",
    "result": { "downloadUrl": "/reports/4271.csv" } }    (or "status":"failed","error":{code,message})
```

- `202 Accepted` + `Location` header + body `{ jobId, status, statusUrl }`.
- The status endpoint reuses the project's response envelope (`api-contract.md`) — don't invent a new shape.
- Use `Retry-After` on the status response (or document a poll interval) so clients back off instead of busy-polling. A webhook callback is the push alternative to polling.

## Job-status state machine

```
queued ──► running ──► succeeded   (carries result or a result URL)
                  └──► failed      (carries a typed error: code + message)
              (└──► cancelled, if cancellation is supported)
```

- Terminal states are immutable. `result` / `error` lives on the terminal record.
- **Result TTL:** results expire (e.g. 24h) — document it; the status endpoint returns `410 Gone` after expiry rather than `404` (the job existed).
- Large results go to object storage; the status returns a (signed, expiring) `downloadUrl`, not the bytes inline.

## Idempotent submission

- The client sends an `Idempotency-Key`; a retry with the same key returns the **same** `jobId` — never a duplicate job.
- **Replay the stored response verbatim, status included.** If the original submit answered `202` + `Location`, the replay answers `202` + the same `Location`. `backend-principles` API-7 requires persisting `(key → response_status + response_body)` atomically with the side effect and replaying *that*; inventing a different status on replay defeats the point, because a client branching on `202` vs `200` now behaves differently depending on whether its first attempt was the one that landed — which is precisely the non-determinism idempotency keys exist to remove. The stored-replay mechanism itself is owned by the distributed-systems pack (`ai/patterns/idempotency.md`); this pattern only requires that submit endpoints participate and that the replayed status is the recorded one.

## Graceful shutdown interaction

- On shutdown, drain/ack in-flight jobs within the deadline (cross-ref `backend-principles.md` graceful-shutdown). A job killed mid-flight must be safe to redrive (idempotent consumer).
- Consumer-side durability (visibility timeout, DLQ, bounded retry, redrive) is owned by the distributed-systems pack — **reference `outbox.md` + the dlq-replay skill; do not duplicate** them here. This file stops at the HTTP boundary.

## Detectors (cite-or-halt)

- A controller whose measured work exceeds the derived budget, or a slow/flaky external call inline → `offload-to-202` (cite the measured latency **and** the budget it exceeds; a latency with no budget beside it is a number, not a finding).
- A job-submit endpoint with no `Idempotency-Key` handling → `add-idempotent-submit`.
- A `202` with no `Location` / no status endpoint → `add-status-endpoint`.
- A job whose result never expires (unbounded storage) → `add-result-ttl`.

**Closure verbs:** `offload-to-202`, `add-status-endpoint`, `add-idempotent-submit`, `add-result-ttl`.

## Framework hooks (queue/runner — mechanics live in distributed-systems)

| Stack | Job runner |
|---|---|
| NestJS / Node | BullMQ, Bee-Queue |
| Rails | Sidekiq, ActiveJob |
| Django / FastAPI | Celery, RQ, Dramatiq, arq |
| Spring | `@Async` + a broker (Spring Batch for batch) |
| .NET | Hangfire, `BackgroundService` + a queue |
| Go | asynq, river, or a channel + workers |
| Laravel | Queues (`ShouldQueue` jobs) |

## Forbidden

- Blocking a request thread on work that exceeds the derived hot-path budget (caps throughput, poisons p99).
- A `202` with no `Location` / status URL (orphaned job).
- A submit endpoint with no idempotency key (duplicate jobs on retry).
- Returning a large result inline from the status endpoint instead of a storage URL.
- A job result that never expires.
