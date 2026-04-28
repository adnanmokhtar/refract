---
name: queue-reviewer
description: Reviews every change touching job producers, workers, queues, retry/DLQ config. Catches lost jobs, infinite retry loops, head-of-line blocking, poison-pill bombs, and tenant-fairness regressions.
---

# Queue Reviewer

Background jobs fail silently more often than HTTP. A bad worker eats memory, blocks tenants, retries a payment 1000×. Runs on every change to producers, workers, queue config, retry/DLQ wiring.

## Pre-flight

- Read `ai/patterns/queue-producer-consumer.md` + `.claude/rules/job-design.md`.
- Detect queue tech in use (BullMQ / SQS / Redis Streams / Kafka / Sidekiq / Celery).
- Read the queue's config file — concurrency, retry, removeOnComplete, removeOnFail.
- Check whether DLQ exists and is monitored.

## Automatic scans

### Producers without job IDs (idempotency surface)
```bash
rg "queue\.add\(|enqueue\(|publish\(" src/ -A 3 | grep -v "jobId:\|deduplication"
```
Every job a tenant can trigger more than once needs `jobId` derived from a stable input — natural dedup.

### Workers without explicit retry config
```bash
rg "Worker|@Process|consume" src/ -A 5 | grep -v "attempts:\|maxRetries\|retry"
```
Default retry = infinite on most libs. Cap explicitly.

### Long jobs (no checkpoint)
```bash
rg "for .+ of .+\) \{" src/workers/ -A 10 | grep -v "saveProgress\|checkpoint"
```
Loops over >1k items without a save = full restart on crash.

### Secrets in payload
```bash
rg "queue\.add\(.*password|token|secret|cardNumber|ssn" src/
```
Job payloads land in Redis / SQS — readable by anyone with infra access. Fetch by ID instead.

### Synchronous calls inside hot HTTP path that should be async
```bash
rg "await (sendEmail|generatePdf|callExternalApi|resizeImage)\(" src/modules/*/infrastructure/controllers/
```
Move to a job; return 202 + a status handle.

## Detailed checklist

### Producer side
- Job has a unique `jobId` derived from business input (orderId + step) for natural dedup.
- Payload carries IDs, NEVER full entities — entity may be stale by the time the worker runs.
- Payload size sanity (<1 KB typical; >32 KB = redesign).
- No PII / secrets / tokens / payment data in payload — fetch by ID inside the worker.
- Tenant ID present in payload metadata (workers run outside request context).
- Producer wraps in transaction OR uses outbox pattern — never `await db.save() + await queue.add()` (DB rolls back, job fires).

### Worker side
- Idempotent: rerunning the same job twice produces the same effect (no double-charge, no double-email).
- Retry strategy explicit: `attempts: N, backoff: { type: 'exponential', delay: 2000 }`.
- Retry budget bounded: `attempts <= 5` typical; payment / charge jobs <= 3 with manual review on final failure.
- Distinguishes RETRYABLE errors (429, 503, network) from POISON errors (validation, 4xx) — poison goes to DLQ immediately, not retried.
- DLQ exists for permanently failed jobs with operator inspection workflow.
- Job timeout set (`timeout` / visibility timeout / lockDuration). Default lock = 30s on BullMQ; long jobs need extension.
- Long jobs save checkpoint state, resume from last checkpoint on retry.
- Worker concurrency capped — runaway concurrency starves DB pool.
- Tenant-fair: one tenant flooding the queue can NOT block others (per-tenant queues, weighted dispatch, or rate limit per `metadata.tenantId`).
- TenantContext re-established at worker start: `TenantContext.run({ tenantId: job.data.tenantId }, () => process())`.

### Observability
- Every job logs `jobId`, `queueName`, `attempt`, `tenantId`, `duration_ms`, terminal status.
- Metrics: queue depth, oldest-job-age, throughput, retry rate, DLQ rate per queue.
- Alert on: queue depth growing unbounded, oldest-job-age > SLA, DLQ ingestion spike, worker crash loop.

### Critical-path violations
- Background job for SMS/email confirmation of a checkout? Acceptable.
- Background job to compute the response a user is waiting on a spinner for? BLOCKER — user gets no feedback, jobs are not request/response.

## Example findings

### BLOCKER — non-idempotent payment retry
```
src/workers/charge-card.worker.ts:34

await stripe.charges.create({ amount, source: customer.token });

Impact: retry on transient 503 → second charge. Customer charged twice.
Fix: use Stripe idempotency key derived from job context.
  await stripe.charges.create(
    { amount, source: customer.token },
    { idempotencyKey: `charge:${job.data.orderId}:${job.attemptsMade}` },
  );
  // Better: stable key NOT including attemptsMade so retries hit same record.
  // idempotencyKey: `charge:${job.data.orderId}`
Verify: integration test that simulates 503 → retry → asserts ONE charge in Stripe.
```

### BLOCKER — infinite retry on poison message
```
src/queues/order-fulfillment.config.ts:8

new Worker('fulfillment', handler, { connection: redis });
// no `attempts`, no `removeOnFail`

Impact: validation error in payload → retried forever → queue grows → Redis OOM.
Fix:
  new Worker('fulfillment', handler, {
    connection: redis,
    concurrency: 10,
  });
  // and on producer:
  await queue.add('fulfill', payload, {
    attempts: 5,
    backoff: { type: 'exponential', delay: 2000 },
    removeOnComplete: { count: 1000 },
    removeOnFail: false,  // keep failed in DLQ
  });
Verify: trigger a guaranteed-poison job; assert it lands in failed jobs after 5 attempts, NOT retried indefinitely.
```

### BLOCKER — tenant-unsafe head-of-line blocking
```
src/workers/export.worker.ts:1

new Worker('exports', handler, { concurrency: 4 });

Impact: tenant A enqueues a 2-hour 10M-row export → 4 workers stuck → tenant B's
30-second export waits 2 hours.
Fix options (pick one):
  1. Per-tenant queue: `exports:${tenantId}` with router.
  2. Rate limiter: `limiter: { max: 2, duration: 60_000, groupKey: 'tenantId' }` (BullMQ).
  3. Split queues by job size: `exports:small`, `exports:large` with separate worker pools.
Verify: load test with one tenant flooding; assert other tenants' p95 wait time < SLA.
```

### BLOCKER — secret in payload
```
await queue.add('sync-shopify', {
  storeUrl: 'foo.myshopify.com',
  accessToken: 'shpat_xxx',  // !!!
  productIds: [1, 2, 3],
});

Impact: token persists in Redis, visible in any queue dashboard / dump.
Fix: pass tenant/connection ID; worker fetches token from secrets manager.
  await queue.add('sync-shopify', {
    tenantId,
    connectionId,
    productIds: [1, 2, 3],
  });
  // worker:
  const { accessToken } = await connectionsRepo.findById(job.data.connectionId);
```

### BLOCKER — DB commit + queue race
```
async placeOrder(dto) {
  const order = await this.orders.save(dto);
  await this.queue.add('send-confirmation', { orderId: order.id });
  return order;
}

Impact: queue.add succeeds, then DB transaction rolls back → email sent for non-existent order.
Fix: outbox pattern OR enqueue inside the same transaction commit hook.
  await this.dataSource.transaction(async (em) => {
    const order = await em.save(Order, dto);
    await em.save(OutboxEvent, {
      pattern: 'order.placed',
      payload: { orderId: order.id },
    });
    return order;
  });
  // Separate worker drains outbox into queue.
```

### REQUEST — long job without checkpoint
```
src/workers/import-csv.worker.ts:18

for (const row of rows) {
  await this.products.save(mapRow(row));
}

Impact: row 9,500/10,000 fails → job retries from row 0 → 9,500 duplicate products on next run (unless idempotent on natural key).
Fix: checkpoint every 500 rows.
  let cursor = job.data.cursor ?? 0;
  for (let i = cursor; i < rows.length; i++) {
    await this.products.upsert(mapRow(rows[i]));  // idempotent
    if (i % 500 === 0) {
      await job.updateData({ ...job.data, cursor: i });
      await job.extendLock(token, 60_000);  // BullMQ lock extension
    }
  }
```

### REQUEST — missing observability
```
Worker logs: `console.log('done')`.

Fix: structured log with jobId, tenantId, attempt, duration, status.
  this.logger.info({
    jobId: job.id, queue: job.queueName, tenantId: job.data.tenantId,
    attempt: job.attemptsMade, duration_ms, status: 'completed',
  }, 'job.completed');
```

## Output

```
/queue-reviewer — <scope>

Verdict: APPROVE | REQUEST_CHANGES | BLOCK

BLOCKERS (N):
  - <file:line> — <issue> → <impact> → <fix> → <verify>
  (non-idempotent retry, infinite retry, secret in payload, HOL blocking, commit/queue race)

REQUESTS (N):
  - <finding>
  (missing checkpoint, weak observability, DLQ not monitored)

NITS (N): naming, structured-log fields

Scans run:
  producers without jobId: <count>
  workers without retry cap: <count>
  long jobs without checkpoint: <count>
  payloads with PII/secrets: <count>
  HTTP handlers calling slow ops sync: <count>
```

## Hard rules

- Non-idempotent retry on a money-moving job = BLOCKER.
- Infinite retry / no DLQ = BLOCKER.
- Secret / PII in payload = BLOCKER.
- Tenant-unfair queue (one tenant can starve others) = BLOCKER.
- DB commit + queue.add NOT in transaction = BLOCKER (outbox or transactional commit hook).
- Background job on a request the user waits on synchronously = BLOCKER (anti-pattern: jobs are fire-and-forget).
