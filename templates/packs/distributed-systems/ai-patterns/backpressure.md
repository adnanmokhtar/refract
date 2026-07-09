---
name: backpressure
description: 'Pattern: Backpressure (bounded queues, load shedding, bulkheads, adaptive concurrency)'
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Backpressure

> **Hard rule:** Every queue, buffer, and resource pool is **bounded**, and every saturated boundary **rejects or sheds** (never blocks unboundedly, never grows in memory). Unbounded in-memory queues, a saturated pool with no shed/reject path, one shared pool for all dependencies (no bulkhead), and retries with no concurrency cap are forbidden.

**When to apply**
- Any producer can outpace its consumer (ingest > processing, fan-in, burst traffic, replay).
- A service calls multiple dependencies from a shared thread/connection pool.
- Retries or client fan-out can amplify load (retry storms).

**When NOT to apply**
- Truly bounded, synchronous, 1:1 request/response with no internal queue and a natural concurrency limit already (e.g., a single-threaded worker pulling one item at a time). Even then, the *pool* still needs a bound.

## Backpressure is telling the producer to slow down

An unbounded buffer doesn't absorb overload — it **defers the crash** and makes it worse (OOM, then everything in-flight is lost, latency climbs unboundedly first). Backpressure propagates "I'm full" upstream so the system degrades predictably instead of collapsing.

## Bounded queues + load shedding

- **Bound every queue.** When full, choose a policy explicitly: **reject** (fail fast, `429`/`503`), **drop-oldest**, **drop-newest**, or **block-with-timeout**. Never "grow".
- **Shed low-priority first.** Under saturation, drop health-check noise / prefetch / analytics before user-facing work. Return **`503` + `Retry-After`** so clients back off instead of hammering.
- Shedding a request cheaply is strictly better than accepting one you'll drop expensively after holding resources.

## Adaptive concurrency

- Cap in-flight work with a **concurrency limit / semaphore**, not just a rate limit — concurrency tracks the resource that actually saturates.
- **AIMD** (additive-increase / multiplicative-decrease, TCP-style): grow the limit while latency is healthy, cut it hard on overload signals. Libraries like Netflix `concurrency-limits` estimate the limit from latency (Little's Law) automatically.
- **Credit-based flow control**: the consumer grants the producer N credits (permits); the producer may only send while it holds credits, and credits are replenished as the consumer drains. Used by gRPC/HTTP-2 and reactive streams — backpressure without polling.

## The bulkhead pattern (isolate the pools)

Named after a ship's watertight compartments: **give each dependency its own bounded resource pool** (threads / connections / semaphore permits) so one slow or failing dependency **cannot exhaust the shared pool and take down every other call**. A single global pool means a stalled `payments` call starves `catalog`, `auth`, and health checks alike — one dependency sinks the whole ship. Pair with `circuit-breaker.md` (stop calling the dead dependency) and per-call timeouts (release the permit).

## Detectors (cite-or-halt)

- An **unbounded in-memory queue / buffer / channel** fed by a producer that can outpace the consumer — cite the buffer at `<path:line>`; halt and require a bound + overflow policy.
- A saturated pool / worker with **no shed-or-reject path** (accepts work it cannot serve) — halt; require `503`/`429` + `Retry-After` or a documented drop policy.
- A **single shared connection/thread pool serving all dependencies** (no bulkhead) — one slow dependency exhausts it; halt and require per-dependency isolation.
- **Retries with no concurrency cap / no budget** (and ideally no jitter) — retry-storm amplifier; halt (cross-check `circuit-breaker.md`).
- Hand-wave (`etc.`, `appears to`, `roughly`) on "the queue won't grow unbounded" — forbidden without the bound cited.

## Related

- `circuit-breaker.md` — stops calls to a dead dependency; bulkheads contain the ones still in flight.
- `distributed-principles.md` — backpressure + bulkhead are the resilience half of the principles.
- `consistency-models.md` — shedding is choosing availability degradation deliberately.
- `outbox.md` — a bounded, durable queue with backoff instead of an in-memory buffer.
