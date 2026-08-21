---
name: backpressure
kind: example
pack: distributed-systems
---

# Pattern: Backpressure

> **Hard rule:** Every queue, buffer, and resource pool is **bounded**, and every saturated boundary **rejects or sheds** (never blocks unboundedly, never grows in memory). Unbounded in-memory queues, a saturated pool with no shed/reject path, one shared pool for all dependencies (no bulkhead), and retries with no concurrency cap are forbidden.

Bound every queue and pool; reject or shed at a saturated boundary — never block unboundedly, never grow in memory. An unbounded buffer just defers the crash (OOM) and makes it worse.

## Bounded queue + load shedding

```
queue full → policy (reject 429/503 | drop-oldest | drop-newest | block-with-timeout)
overload   → shed low-priority first (prefetch/analytics) before user work
reject     → 503 + Retry-After   (so clients back off instead of hammering)
```

## Adaptive concurrency

- Cap **in-flight** work with a semaphore/concurrency limit (tracks the resource that saturates), not just rate.
- **AIMD**: grow the limit while latency is healthy, cut hard on overload (Netflix `concurrency-limits` derives it from latency via Little's Law).
- **Credit-based flow control**: consumer grants N credits; producer sends only while it holds them (gRPC/HTTP-2, reactive streams) — backpressure without polling.

## Bulkhead — isolate the pools

```
❌ one shared pool:   payments stalls → catalog, auth, health all starve → ship sinks
✅ per-dependency pool: payments's bounded pool drains → others unaffected
```

Watertight compartments: each dependency gets its own bounded pool (threads/connections/permits). Pair with `circuit-breaker.md` + per-call timeouts (release the permit).

## Forbidden

- Unbounded in-memory queue/buffer fed by a faster producer.
- Saturated pool with no shed/reject path.
- Single shared pool for all dependencies (no bulkhead).
- Retries with no concurrency cap / budget (retry storm).

## Detectors (cite-or-halt)

- An **unbounded in-memory queue / buffer / channel** fed by a producer that can outpace the consumer — cite the buffer at `<path:line>`; halt and require a bound + overflow policy.
- A saturated pool / worker with **no shed-or-reject path** (accepts work it cannot serve) — halt; require `503`/`429` + `Retry-After` or a documented drop policy.
- A **single shared connection/thread pool serving all dependencies** (no bulkhead) — one slow dependency exhausts it; halt and require per-dependency isolation.
- **Retries with no concurrency cap / no budget** (and ideally no jitter) — retry-storm amplifier; halt (cross-check `circuit-breaker.md`).
- Hand-wave (`etc.`, `appears to`, `roughly`) on "the queue won't grow unbounded" — forbidden without the bound cited.
