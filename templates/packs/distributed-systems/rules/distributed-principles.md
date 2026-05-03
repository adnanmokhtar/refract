---
name: distributed-principles
description: Distributed Systems Principles
kind: rule
pack: distributed-systems
---

# Distributed Systems Principles

> **Hard rule.** Exactly ONE service owns writes to an entity; cross-service writes go through that owner. Every external call MUST have a timeout + retry + circuit breaker; every retried mutation MUST be idempotent (server-stored idempotency key); every cross-service workflow MUST use saga + outbox — 2PC / XA and shared mutable databases are forbidden.

Prevents the failures that turn a microservice migration into a distributed monolith with extra latency: shared DBs, sync chains, missing idempotency, retries without timeouts, distributed transactions.

## The 8 fallacies (Deutsch / Gosling)

Memorize. Every design that assumes otherwise is wrong.

1. The network is reliable.
2. Latency is zero.
3. Bandwidth is infinite.
4. The network is secure.
5. Topology doesn't change.
6. There is one administrator.
7. Transport cost is zero.
8. The network is homogeneous.

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
- "Best effort" for business-critical exactly-once semantics (payments, orders). Use outbox + idempotency.
- Cross-tenant data leak via incorrect partitioning / cache key / event filter — silent until a customer notices.

## Should

- Use async via queue / event bus when the caller doesn't need an immediate answer. Decouples availability — A is no longer at most as available as B.
- Wrap every external dependency in a circuit breaker (every mainstream language has at least one library — e.g., `opossum` / `cockatiel` for Node, Resilience4j for JVM, Polly for .NET, `gobreaker` / `hystrix-go` for Go, `pybreaker` for Python, `Stoplight` / `circuit_breaker` for Ruby). Fail fast when the downstream is sick; let it recover.
- Bulkheads: separate connection pools / thread pools per dependency. One slow dep MUST NOT starve the others.
- Graceful degradation: cached / default response when downstream is down. Catalog without prices beats no catalog.
- End-to-end backpressure: producer slows when consumer / queue is full. Unbounded buffers are forbidden.
- Version events / API contracts (`order.created.v2`). Breaking changes ship as a new version; old version retired with notice.
- CDC (Debezium / Maxwell) over polling for change propagation when DB is the source of truth.
- Strong consistency within a service transaction; eventual consistency across services — design for it explicitly, never hope for it.

## Communication patterns

- Sync (HTTP/gRPC) when caller needs the result NOW and downstream is in-region + fast.
- Async (queue / event) when caller doesn't need the result, or to decouple availability.
- Stream (the project's log-based / partitioned event-stream platform — e.g., Kafka, Pulsar, Kinesis, Redpanda, NATS JetStream) for fan-out, replay, log-based integration.
- RPC pattern names (`order.created`, `payment.captured`) live in a shared constants file or schema registry — never inline magic strings.

## Review checklist

- [ ] New service has a single owner of its data; doesn't read another service's tables directly.
- [ ] New external call has timeout + retry policy + circuit breaker.
- [ ] New mutating endpoint accepts an idempotency key.
- [ ] New cross-service workflow uses saga or outbox, not 2PC.
- [ ] Correlation ID propagated through new code paths.
- [ ] No external call inside a DB transaction.
- [ ] Tenant isolation preserved across the boundary (cache keys, event filters, query filters).
- [ ] New event has a versioned name; payload carries IDs not full entities.

## Enforcement

- Contract tests (the project's contract-test stack — e.g., Pact, Spring Cloud Contract, the schema-registry compatibility check for the project's serialization format) gate consumer-incompatible changes.
- Trace coverage SLO — every endpoint has spans visible in the project's trace backend.
- Chaos drills (the project's chaos tooling — LitmusChaos / Gremlin / Chaos Mesh / kill-the-process in staging) validate timeout / retry / circuit breaker actually engages.
- Cross-tenant smoke tests on multi-tenant boundaries (cache key, event filter, query filter).

## References

- L. Peter Deutsch, "The 8 fallacies of distributed computing".
- Pat Helland, "Life Beyond Distributed Transactions".
- microservices.io patterns catalog (Saga, Outbox, CQRS, API Gateway).
- Cloud-vendor Well-Architected frameworks (AWS / GCP / Azure / etc., resilience pillars).
