---
name: queue-producer-consumer
description: Pattern: Queue producer + consumer (BullMQ reference)
kind: ai-pattern
---

# Pattern: Queue producer + consumer (BullMQ reference)

End-to-end pattern for declaring a queue, enqueuing jobs transactionally, and consuming them with retry / DLQ / tenant-fair / observable workers.

## Decision summary

Default queue tech: **BullMQ + Redis**. Reasons:
- TypeScript native, NestJS first-class.
- Built-in retry, backoff, rate limiting, repeat (cron), prioritization.
- DLQ via `removeOnFail: false` — failed jobs preserved indefinitely until replayed/deleted.
- Operates on Redis you already run.

When to choose differently:
- **SQS** if you're on AWS and want managed (no Redis ops). Trade-off: weaker primitives (no priority, no rate limit per group, manual DLQ wiring).
- **Kafka** if you need event sourcing, replay from offset, multi-consumer fanout. Overkill for jobs.
- **Redis Streams** if you want exactly-once-ish + multiple consumer groups with no extra deps. More verbose than BullMQ.

## File layout

```
src/
├── infrastructure/queues/
│   ├── connection.ts                 # one shared Redis connection
│   ├── queue-names.ts                # const enum of queue names — never inline strings
│   └── queues.module.ts              # provides Queue instances + Workers
└── modules/<feature>/
    ├── core/jobs/
    │   ├── send-confirmation.job.ts  # job class + payload type
    │   └── ...
    ├── infrastructure/workers/
    │   ├── send-confirmation.worker.ts
    │   └── ...
    └── core/services/
        └── place-order.service.ts    # producer side
```

## Connection (one per process)

```ts
// src/infrastructure/queues/connection.ts
import { Redis } from 'ioredis';

export const queueConnection = new Redis(process.env.REDIS_URL!, {
  maxRetriesPerRequest: null,    // BullMQ requires null
  enableReadyCheck: false,
});
```

## Queue names

```ts
// src/infrastructure/queues/queue-names.ts
export const QUEUE = {
  ORDER_FULFILLMENT: 'order-fulfillment',
  CONFIRMATION_EMAIL: 'confirmation-email',
  EXPORT_LARGE: 'export-large',
  WEBHOOK_FANOUT: 'webhook-fanout',
} as const;
```

## Producer (transactional, with outbox)

The unsafe pattern:
```ts
// BAD — DB rolls back, job still fires
async placeOrder(dto: PlaceOrderDto) {
  const order = await this.orders.save(dto);
  await this.queue.add('confirmation', { orderId: order.id });
  return order;
}
```

The safe pattern (outbox):
```ts
// GOOD
async placeOrder(dto: PlaceOrderDto): Promise<Order> {
  return this.dataSource.transaction(async (em) => {
    const order = await em.save(Order, dto);
    await em.save(OutboxEvent, {
      pattern: 'order.placed',
      payload: { orderId: order.id },
      tenantId: this.tenantContext.getTenantId(),
    });
    return order;
  });
}
```

Then a separate `OutboxDrainerWorker` reads `outbox_events` rows, enqueues to BullMQ, deletes the row. Workers process the BullMQ job. Two-phase: zero risk of "DB rolled back, queue fired".

## Job class (typed payload)

```ts
// src/modules/orders/core/jobs/send-confirmation.job.ts
export type SendConfirmationPayload = {
  orderId: string;
  metadata: { tenantId: string; correlationId: string };
};
```

## Enqueue helper (idempotent, tenant-aware)

```ts
// usage from outbox drainer
await this.confirmationQueue.add(
  'send',
  { orderId, metadata: { tenantId, correlationId } } as SendConfirmationPayload,
  {
    jobId: `confirmation:${orderId}`,                    // natural dedup
    attempts: 5,
    backoff: { type: 'exponential', delay: 2000 },
    removeOnComplete: { count: 1000, age: 3600 },
    removeOnFail: false,                                 // keep in failed for DLQ
    timeout: 30_000,
  },
);
```

`jobId` derived from business key → second outbox drain of the same row is a no-op.

## Worker (idempotent, tenant-fair, observable)

```ts
// src/modules/orders/infrastructure/workers/send-confirmation.worker.ts
import { Worker, UnrecoverableError } from 'bullmq';

export class SendConfirmationWorker {
  private worker: Worker;

  constructor(
    private readonly emails: EmailSender,
    private readonly orders: OrderRepository,
    private readonly logger: Logger,
    private readonly tenantContext: TenantContext,
    private readonly metrics: Metrics,
  ) {
    this.worker = new Worker<SendConfirmationPayload>(
      QUEUE.CONFIRMATION_EMAIL,
      (job) => this.process(job),
      {
        connection: queueConnection,
        concurrency: 10,
        limiter: { max: 100, duration: 60_000, groupKey: 'metadata.tenantId' as any },
        lockDuration: 30_000,
      },
    );

    this.worker.on('failed', (job, err) =>
      this.logger.error({ jobId: job?.id, err }, 'job.failed'),
    );
  }

  private async process(job: Job<SendConfirmationPayload>) {
    const start = Date.now();
    const { orderId, metadata } = job.data;

    try {
      await this.tenantContext.run({ tenantId: metadata.tenantId }, async () => {
        const order = await this.orders.findById(orderId);
        if (!order) {
          // POISON — order vanished. Don't retry forever.
          throw new UnrecoverableError(`order ${orderId} not found`);
        }
        if (order.confirmationSentAt) {
          // already done — idempotent no-op
          return;
        }

        await this.emails.send({
          to: order.email,
          template: 'order-confirmation',
          data: { orderId },
          idempotencyKey: `confirmation:${orderId}`,    // ESP-side dedup
        });

        await this.orders.markConfirmationSent(orderId);
      });

      this.logger.info({
        jobId: job.id, queue: job.queueName, tenantId: metadata.tenantId,
        attempt: job.attemptsMade, duration_ms: Date.now() - start,
        status: 'completed',
      }, 'job.completed');
      this.metrics.histogram('job.duration_ms', Date.now() - start, { queue: job.queueName, status: 'ok' });
    } catch (err) {
      this.metrics.histogram('job.duration_ms', Date.now() - start, { queue: job.queueName, status: 'error' });
      throw err;   // BullMQ handles retry/backoff
    }
  }
}
```

Three things this gets right:
1. **Idempotent** — checks `confirmationSentAt`, sends with idempotency key, marks sent atomically.
2. **Distinguishes poison** — `UnrecoverableError` for "order not found" — no point retrying 5×.
3. **Tenant-fair** — `limiter` groups by tenant; one tenant flooding can't starve others.

## DLQ inspection + replay

BullMQ failed jobs are the DLQ when `removeOnFail: false`:

```ts
const failed = await queue.getJobs(['failed'], 0, 50);
for (const job of failed) {
  console.log({ id: job.id, data: job.data, error: job.failedReason });
}

// After fixing the underlying bug:
for (const job of failed) {
  await job.retry();
}
```

Or use `bullmq-board` / `arena` for a UI.

## Long-job pattern (chunked + checkpointed)

```ts
async processLargeImport(job: Job<ImportPayload>) {
  const { fileUrl, totalRows } = job.data;
  let cursor = (job.data as any).cursor ?? 0;
  const batchSize = 500;

  for (let i = cursor; i < totalRows; i += batchSize) {
    const rows = await this.fetchRows(fileUrl, i, batchSize);
    await this.products.upsertBatch(rows);          // idempotent

    cursor = i + batchSize;
    await job.updateData({ ...job.data, cursor });
    await job.extendLock(job.token!, 60_000);       // keep lock alive

    if (Date.now() - start > 50_000) {
      // approaching lockDuration — re-queue continuation
      await this.queue.add(job.name, { ...job.data, cursor }, { jobId: `${job.id}:cont:${cursor}` });
      return;
    }
  }
}
```

On crash at row 9,500: the job retries, sees `cursor=9500`, resumes — no duplicates because `upsertBatch` is idempotent.

## Trade-off table

| Concern | BullMQ | SQS | Kafka | Redis Streams |
|---|---|---|---|---|
| Setup | ★★★★★ | ★★★★ | ★★ | ★★★ |
| Priority | yes | no | partition-based | manual |
| Rate limit per key | yes (limiter) | no | no | manual |
| DLQ | flag | separate queue | separate topic | manual XACK |
| Replay | retry per job | no (must redrive) | offset rewind ★★★★★ | XREAD from id |
| Throughput | ~10k/s | ~3k/s | ~M/s | ~50k/s |
| Multi-consumer fanout | no | no (need SNS) | yes ★★★★★ | yes (consumer groups) |
| Ops cost (Redis already up) | free | $$ at volume | $$$ | free |

## Common mistakes

- **Forgetting `attempts`** — defaults to infinite on most libs. Workers retry forever, queue grows, Redis OOM.
- **Same jobId across attempts in idempotency key for external API** — Stripe sees a different key, charges twice. Use stable key per business operation, NOT per attempt.
- **Catching all errors in worker** — the worker reports success, the job is acked, side-effect didn't happen. Re-throw retryable errors; only swallow with `UnrecoverableError` for true poison.
- **Holding DB transaction across job** — long lock on rows; deadlocks under concurrency. Per-batch transactions.
- **Worker concurrency = 100** without considering DB pool — DB pool exhausts, every query times out, cascade.
- **`removeOnComplete: true`** without `removeOnFail` config — failed jobs sit forever silently. Always think about both ends.
- **No tenant fairness** — one customer's batch import freezes the whole product. Per-tenant rate limit or queue split.
- **Job for synchronous user response** — user sees spinner forever; jobs aren't request/response.
- **Polling DB instead of using queue events** — every API call hits DB to "is my job done?". Use WebSocket / SSE pushed from a worker `completed` event.
- **No dashboard / no alerts** — first sign of trouble is a customer complaint.
