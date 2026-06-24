---
name: async-job-offload
description: 'Pattern: Async Job Offload (202 Accepted + status URL, job-status state machine, result TTL)'
kind: ai-pattern
pack: backend
---

# Pattern: Async Job Offload

> **Hard rule:** Work that exceeds the request hot-path budget (> ~500ms wall or > 50ms CPU) or depends on a flaky upstream MUST be enqueued, not run inline — the endpoint returns `202 Accepted` + a job id + a `Location` / status URL, and the client polls (or is webhooked) for a terminal state. A controller that blocks on slow work caps throughput at (workers ÷ job-time) and makes p99 hostage to the slowest dependency. This file owns the HTTP submit/status CONTRACT; the queue/consumer mechanics (visibility timeout, DLQ, redrive) are owned by the distributed-systems pack.

**When to apply** — report/export generation, media/ML processing, bulk import, third-party fan-out — anything measured (not guessed) to exceed the budget, or that must survive a request timeout / client disconnect / mid-flight deploy.

**Halt conditions / mandatory cites**
- Proposing an offload MUST cite the measured/expected latency at `<path:line>` that exceeds the budget — don't queue work that's already fast.
- A controller doing > ~50ms CPU or a slow/flaky external call inline (no offload) MUST be cited.
- A `202` with no `Location` / status path is incomplete.
- A job-submit endpoint with no idempotency key MUST be cited — a client retry would enqueue a duplicate.

## HTTP contract

```
POST /reports  (Idempotency-Key: 9f1c...)
→ 202 Accepted
  Location: /jobs/4271
  { "jobId": "4271", "status": "queued", "statusUrl": "/jobs/4271" }

GET /jobs/4271 → 200 { "jobId":"4271", "status":"running" }     (poll; honor Retry-After)
GET /jobs/4271 → 200 { "status":"succeeded", "result": { "downloadUrl": "/reports/4271.csv" } }
                                                                 (or "failed" + error{code,message})
```

- `202 Accepted` + `Location` header + body `{ jobId, status, statusUrl }`.
- The status endpoint reuses the project response envelope — don't invent a new shape.
- Use `Retry-After` on the status response (or document a poll interval). A webhook is the push alternative to polling.

## Job-status state machine

```
queued ──► running ──► succeeded   (result or result URL)
                  └──► failed      (typed error: code + message)
```

- Terminal states are immutable; `result`/`error` lives on the terminal record.
- **Result TTL:** results expire (e.g. 24h) — the status endpoint returns `410 Gone` after expiry (the job existed), not `404`.
- Large results go to object storage; the status returns a signed, expiring `downloadUrl`, not bytes inline.

## Idempotent submission

- The client sends an `Idempotency-Key`; a retry with the same key returns the **same** `jobId` (`200` with the existing job, not a new `202`) — never a duplicate.
- The stored-replay record (key → response) is owned by `ai/patterns/idempotency.md` (distributed-systems) — this pattern just requires submit endpoints participate.

## Graceful shutdown interaction

- On shutdown, drain/ack in-flight jobs within the deadline (cross-ref `backend-principles.md` graceful-shutdown). A job killed mid-flight must be safe to redrive (idempotent consumer).
- Consumer-side durability (visibility timeout, DLQ, bounded retry, redrive) is owned by distributed-systems — **reference `outbox.md` + the dlq-replay skill; do not duplicate**. This file stops at the HTTP boundary.

## Detectors (cite-or-halt)

- A controller doing > ~Nms synchronous CPU or a slow/flaky external call inline → `offload-to-202` (cite the latency).
- A job-submit endpoint with no `Idempotency-Key` handling → `add-idempotent-submit`.
- A `202` with no `Location` / no status endpoint → `add-status-endpoint`.
- A job whose result never expires → `add-result-ttl`.

**Closure verbs:** `offload-to-202`, `add-status-endpoint`, `add-idempotent-submit`, `add-result-ttl`.

## Framework hooks (queue/runner — mechanics live in distributed-systems)

| Stack | Job runner |
|---|---|
| NestJS / Node | BullMQ, Bee-Queue |
| Rails | Sidekiq, ActiveJob |
| Django / FastAPI | Celery, RQ, Dramatiq, arq |
| Spring | `@Async` + a broker (Spring Batch for batch) |
| .NET | Hangfire, `BackgroundService` + a queue |
| Go | asynq, river, channel + workers |
| Laravel | Queues (`ShouldQueue`) |

## Forbidden

- Blocking a request thread on work that exceeds the hot-path budget (caps throughput, poisons p99).
- A `202` with no `Location` / status URL (orphaned job).
- A submit endpoint with no idempotency key (duplicate jobs on retry).
- Returning a large result inline from the status endpoint instead of a storage URL.
- A job result that never expires.
