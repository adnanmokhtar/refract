---
name: distributed-principles
kind: example
pack: distributed-systems
---

# Distributed Systems Principles

> **Hard rule.** Exactly ONE service owns writes to an entity; cross-service writes go through that owner. Every external call MUST have a timeout + retry + circuit breaker; every retried mutation MUST be idempotent (server-stored idempotency key); every cross-service workflow MUST use saga + outbox — 2PC / XA and shared mutable databases are forbidden.

Prevents the failures that turn a microservice migration into a distributed monolith with extra latency: shared DBs, sync chains, missing idempotency, retries without timeouts, distributed transactions. Every rule below is a fallacy of distributed computing (Deutsch/Gosling) made enforceable — the network is not reliable, latency is not zero, topology changes.

## Must

- Exactly ONE service owns writes to an entity. Other services read via API or read replicas. Two writers = data corruption.
- Every external call has a TIMEOUT (e.g. 2s default for in-region, longer for cross-region). No-timeout calls cascade failures.
- Every write a client might retry is idempotent. Client supplies a UUID `Idempotency-Key`; server stores it with a unique constraint and returns the original response on replay.
- Correlation / trace ID generated at the edge and propagated through every hop (HTTP `traceparent` per W3C, queue metadata, RPC headers, DB query comments). OpenTelemetry preferred.
- Outbox pattern for "write to DB + publish event" atomicity: write the row + an outbox row in one transaction; a relay publishes asynchronously. No 2PC required.
- Saga / process manager for cross-service workflows that need atomicity. Each step has a compensating action; the saga is recoverable from any midpoint.
- Bounded concurrency on every dependency: connection pool size, semaphore, worker count. Unbounded fan-out kills downstreams (and you).
- Health + readiness separation. Liveness = "kill me if I'm dead". Readiness = "stop sending traffic if I can't serve". Mixing them causes traffic black-holes during dep outages.

## Must not

- Distributed monolith: services that must be deployed together, share a DB, or fail together. Either merge them or fix the boundary.
- Shared mutable database across services. Each service owns its schema; cross-service joins go through APIs or a dedicated query / CQRS service.
- 2-phase commit / XA transactions across services. Blocks, single point of failure, scales poorly. Use saga + outbox.
- Synchronous chain of services where the caller doesn't need an immediate answer. Convert to async via queue / event bus.
- Retries without idempotency. Every retried POST that isn't idempotent doubles your data.
- External call inside a DB transaction. Holds a connection across unbounded network time = pool exhaustion + lock contention.
- Catch + swallow on a network error. Either retry with policy + circuit breaker, or fail with a typed error the caller can handle.
- **Exactly-once *delivery* is impossible** across a network (the two-generals problem). What you build is **effectively-once = at-least-once delivery + idempotent processing** — the message may arrive 2+ times; idempotency makes the duplicate a no-op. For business-critical flows (payments, orders): outbox (at-least-once publish) + a stored idempotency key on the consumer. Never claim "exactly-once" — claim effectively-once and show the idempotency key.
- Cross-tenant data leak via incorrect partitioning / cache key / event filter — silent until a customer notices.
- Event / RPC pattern names as inline string literals. They live in a shared constants file or schema registry; a typo in an inline `"order.created"` is a silently-dropped subscription, not a compile error.

## Should

- Use async via queue / event bus when the caller doesn't need an immediate answer. Decouples availability — A is no longer at most as available as B.
- Wrap every external dependency in a circuit breaker (every mainstream language has at least one library — e.g., `opossum` / `cockatiel` for Node, Resilience4j for JVM, Polly for .NET, `gobreaker` / `failsafe-go` for Go, `pybreaker` for Python, `Stoplight` / `circuit_breaker` for Ruby). Fail fast when the downstream is sick; let it recover.
- Bulkheads: separate connection pools / thread pools per dependency. One slow dep MUST NOT starve the others.
- Graceful degradation: cached / default response when downstream is down. Catalog without prices beats no catalog.
- End-to-end backpressure: producer slows when consumer / queue is full. Unbounded buffers are forbidden.
- Version events / API contracts (`order.created.v2`). Breaking changes ship as a new version; old version retired with notice. The payload carries IDs, not whole entities — a fat event couples every consumer to the producer's schema.
- CDC (Debezium / Maxwell) over polling for change propagation when DB is the source of truth.
- Strong consistency within a service transaction; eventual consistency across services — design for it explicitly, never hope for it.
- Every derived or replicated store (a read-model projection, a cache, a search/analytics index, a dual-write copy, a read replica) has an anti-entropy reconciliation job: drift detection (checksum / count / sample-diff / watermark) + a resumable, idempotent repair path + an emitted divergence metric with an alert. A copy with no "how would we know it diverged, and how would we fix it?" answer is a latent incident. `cqrs` / `event-sourcing` own the single-store projection *rebuild*; this owns cross-store *divergence detect + repair* — see `reconciliation.md`.

## Enforcement

- Contract tests (the project's contract-test stack) gate consumer-incompatible changes.
- Trace coverage SLO — every endpoint has spans visible in the project's trace backend.
- Chaos drills (the project's chaos tooling, or kill-the-process in staging) validate timeout / retry / circuit breaker actually engages.
- Cross-tenant smoke tests on multi-tenant boundaries (cache key, event filter, query filter).
