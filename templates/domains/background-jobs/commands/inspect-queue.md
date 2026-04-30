---
description: Dump queue health — depth, oldest-job-age, failed count, throughput. BullMQ / SQS / Redis Streams / Kafka aware.
---

# /inspect-queue

Purpose: in 30 seconds, answer "is this queue healthy?" without opening a dashboard.

## Premise

Real signals only. Cite the actual queue name, depth, oldest-job id, DLQ count from the live broker — never guess from code. Read before writing: this command observes; it does NOT requeue, ack, or mutate. If the broker connection fails, halt and surface the connection error — do not infer health from stale data.

## Mechanical halt

Cite-or-halt: every reported metric must come from a live `getJobCounts` / `get-queue-attributes` / `XLEN` / `kafka-consumer-groups --describe` call. No "looks healthy" without numbers. If a queue is unreachable, mark it `UNREACHABLE` — never `OK` by default.

## What it reports

For each queue:

| Metric | Healthy | Watch | Alert |
|---|---|---|---|
| `depth` (waiting jobs) | < 100 | 100-1000 | > 1000 sustained |
| `active` | ≤ concurrency | at concurrency steadily | stuck at concurrency for >5min with no completions |
| `oldest_age_seconds` | < 30 | 30-300 | > 300 |
| `failed_24h` | < 1% of completed | 1-5% | > 5% |
| `dlq_count` | 0 | non-zero, growing slowly | growing fast |
| `throughput_per_min` | matches expected | dipping | flat (worker dead) |
| `retry_rate` | < 5% | 5-20% | > 20% (poison or external dep flapping) |

## BullMQ

```bash
.claude/skills/inspect-queue.sh                    # all queues
.claude/skills/inspect-queue.sh fulfillment        # one queue
.claude/skills/inspect-queue.sh fulfillment --dlq  # show DLQ contents head
```

Implementation pulls from Redis directly:

```ts
import { Queue } from 'bullmq';
const q = new Queue(name, { connection });
const counts = await q.getJobCounts('waiting', 'active', 'completed', 'failed', 'delayed', 'paused');
const oldest = (await q.getJobs(['waiting'], 0, 0))[0];
const oldestAge = oldest ? Date.now() - oldest.timestamp : 0;
const failedSample = await q.getJobs(['failed'], 0, 5);
```

## AWS SQS

```bash
aws sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names ApproximateNumberOfMessages \
                    ApproximateNumberOfMessagesNotVisible \
                    ApproximateNumberOfMessagesDelayed \
                    ApproximateAgeOfOldestMessage
```

Map:
- `ApproximateNumberOfMessages` → depth
- `ApproximateNumberOfMessagesNotVisible` → active (in-flight)
- `ApproximateAgeOfOldestMessage` → oldest_age_seconds

DLQ: separate queue, inspect with same call. Alert on any non-zero count.

## Redis Streams

```bash
redis-cli XLEN <stream>                                  # depth
redis-cli XPENDING <stream> <consumer-group>             # in-flight + oldest age
redis-cli XPENDING <stream> <consumer-group> - + 10      # head of pending list
redis-cli XINFO STREAM <stream>                          # full state
```

Stuck consumers: pending entries with `idle_ms > consumer_timeout` are abandoned. Use `XCLAIM` to reassign or `XACK` + DLQ if poison.

## Kafka

```bash
kafka-consumer-groups.sh --bootstrap-server $BROKER \
  --describe --group <group>
```

Reports per-partition `LAG` (messages behind). Alert on:
- LAG growing unbounded → consumer too slow.
- LAG flat at >0 → consumer dead.

## Output table

```
Queue: fulfillment
  depth:           42       OK
  active:          8/10     OK
  oldest_age:      4s       OK
  failed_24h:      12 (0.3%) OK
  dlq:             3        WATCH — non-zero, see /inspect-queue fulfillment --dlq
  throughput/min:  1240     OK (expected ~1200)
  retry_rate:      2.1%     OK

Queue: exports
  depth:           1847     ALERT — > 1000 sustained
  active:          4/4      ALERT — at concurrency for 12 min, no completions
  oldest_age:      820s     ALERT
  → likely cause: a single 2hr job blocking workers (HOL). See /queue-reviewer rules on tenant-fairness.

Queue: webhooks
  depth:           0        OK
  failed_24h:      481 (12%) ALERT — high retry rate
  → check: external endpoint health, signature mismatch logs.
```

## When to run

- Daily during early production (catch the queue before it catches you).
- Whenever an alert fires.
- Before declaring a deploy successful — workers still draining old version's jobs.
- When a downstream dependency (payment provider, email service) is reportedly degraded.

## Follow-ups

- Depth > alert + oldest-age > alert: consumer dead OR producer surge. Check `kubectl get pods` / equivalent.
- DLQ growing: dump head, identify pattern, fix code, replay (`bullmq-board` or custom replay command).
- High retry rate, low completion: external dep flapping. Add circuit breaker.
- Stuck active jobs (no completion, lock not released): worker crashed mid-job. BullMQ recovers via `lockDuration` expiry; SQS via `VisibilityTimeout`. Investigate why.
