---
name: job-design
description: Job design rules
kind: rule
---

# Job design rules

Background jobs replace the request/response trust contract with eventual consistency. Every job MUST satisfy the rules below — they exist because each rule maps to a real production failure.

## Idempotency

- Every job is idempotent — running it twice produces the same effect as running it once.
- Use a stable `jobId` derived from business input (`order:${id}:confirmation-email`) — natural dedup at queue level.
- For external calls that mutate (payment, email send, third-party API), pass an idempotency key derived from the job context, not from the attempt count.
- Workers that write to your DB use `upsert` / `INSERT ... ON CONFLICT DO NOTHING`, never blind `INSERT`.
- Side-effects (email sent, SMS sent, external charge) are recorded in DB so a retry can detect "already done".

## Retry budget

- Every queue declares `attempts` and `backoff` explicitly. Default = infinite is the most common production fire.
- `attempts: 5` typical for transient ops; `attempts: 3` for money-moving ops.
- `backoff: { type: 'exponential', delay: 2000 }` (2s → 4s → 8s → 16s → 32s) — never linear, never zero.
- Distinguish RETRYABLE errors (network, 429, 503, lock contention) from POISON errors (4xx, validation, type errors). POISON skips retries — use `UnrecoverableError` (BullMQ) or equivalent.

## Dead-letter queue

- Every queue has a DLQ for jobs that exhausted retries.
- DLQ is monitored — non-zero count = pager.
- DLQ entries are inspectable (payload + last error) and replayable after fix.
- DLQ is NOT the trash — investigate every entry. Persistent DLQ ingestion = bug or external dep degraded.

## Long jobs

- Long job = anything that can exceed 1 minute or process > 1000 items.
- Split into chunks: parent job enqueues N children, each processes ~100 items.
- If you can't split: checkpoint progress every N items (`job.updateData({ cursor })`) and extend lock (`job.extendLock`) — restart from cursor on retry.
- NEVER hold an open transaction across a long job — break into per-batch transactions.

## Tenant fairness

- One tenant must NOT be able to starve others. Enforce one of:
  - Per-tenant queues (router enqueues to `queue:${tenantId}`).
  - Rate limiter scoped per tenant (`groupKey: 'tenantId'` on BullMQ).
  - Fair dispatch (round-robin across tenants in the queue).
- Worker concurrency capped per queue AND per tenant.
- Tenant ID lives in `job.data.metadata.tenantId` — workers re-establish `TenantContext` at start.

## Payload hygiene

- Payload carries IDs, NOT entities. Entity may have changed by the time the worker runs. Refetch.
- Payload size < 1 KB typical, < 32 KB hard limit. Larger = redesign (S3 ref, DB row).
- NEVER include secrets, tokens, payment details, passwords, raw PII. Payloads land in Redis / SQS / Kafka — readable by anyone with infra access.
- Tenant ID always in `metadata`, never load-bearing in `payload` (prevents handler spoofing).

## Critical-path discipline

- NEVER use a background job for data the user is waiting on synchronously. Jobs are fire-and-forget; if the user expects a response, return 202 + a status handle they poll, OR keep it synchronous.
- Acceptable async: confirmation email after checkout, PDF generation triggered by user action with status UI, periodic exports, webhook fan-out.
- NOT acceptable async: computing the response body of a request the user is waiting for.

## Transactional enqueue

- `await db.save() + await queue.add()` is a race: DB rolls back, job fires anyway.
- Use the OUTBOX pattern: write a `outbox_events` row in the same transaction; a separate worker drains outbox into the queue.
- Or use a transactional commit hook: `em.afterCommit(() => queue.add(...))`.
- ALWAYS the same transaction or no transaction at all — never split.

## Observability

- Every job logs structured: `jobId`, `queueName`, `tenantId`, `attempt`, `duration_ms`, terminal status, error class on failure.
- Metrics per queue: depth, oldest-job-age, throughput, retry rate, DLQ rate.
- Alerts: queue depth growing unbounded, oldest > SLA, DLQ ingestion spike, worker crash loop, retry rate spike.

## Forbidden

- Job without `attempts` cap.
- Job without `jobId` for naturally-dedupable work.
- Payload with secrets / PII / payment data.
- Long-running job without checkpoint.
- DB transaction + queue enqueue without outbox or commit hook.
- Worker that catches all errors and acks (silent data loss).
- Background job for data the user is actively waiting on.
- DLQ that no one watches.
