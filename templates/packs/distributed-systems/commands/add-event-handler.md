---
description: Add an event handler. Idempotent / retryable / observable / DLQ-aware. Output: handler + tests + DLQ + monitoring.
---

# /add-event-handler

Add a consumer for a single event class. Smaller than a saga — one event in, side effect(s) out, idempotent.

## Premise

Existing event handlers are the truth. Mirror sibling handler shape exactly: subscription registration, schema validation, idempotency-key pattern, error envelope, retry classification, dead-letter routing, span/metric naming. Read at least two siblings in the same service BEFORE writing — copy their conventions (idempotency table name, logger fields, metric prefix). New shapes need an ADR, not a fresh invention.

## Mechanical halt

Sibling-shape parity — refuse to generate a handler that diverges from sibling conventions without an ADR cite in the PR. If the service has zero existing handlers, halt and ask which pattern to seed from (or require `ai/patterns/event-handlers.md` to define one). The handler MUST include all five standard parts (subscription, idempotency check, validation, effect, ack/DLQ); missing any one halts generation.

## Phases applied

All 7.

## When to use / NOT to use

- USE: a service needs to react to an event on the project's message bus / queue / event-stream platform (e.g., Kafka / Pulsar / Kinesis / SQS / RabbitMQ / NATS / EventBridge / Cloud Pub/Sub / Redis Streams).
- USE: cross-service communication where the producer doesn't care who consumes.
- NOT: complex multi-step coordination → use `/add-saga`.
- NOT: synchronous request/response → use a regular endpoint.

## Phase 1 — Understand

- Event source: what's the producer? What schema?
- Event delivery: at-least-once (typical) / exactly-once / at-most-once?
- Side effect: what happens when this event is consumed?
- Idempotency: can the side effect run twice safely?
- Latency tolerance: must process within Xs / Xm / Xh?
- Failure mode: retry forever / DLQ after N / drop and alert?

## Phase 2 — Organize

The handler has 5 standard parts:

1. **Subscription** — register handler with the project's broker / queue / event-stream platform using the platform's native consumer / poller / subscription API.
2. **Idempotency check** — was this event already processed? (idempotency key in the project's transactional DB or distributed cache).
3. **Validation** — schema check; ignore unknown event versions.
4. **Effect** — the actual work.
5. **Ack / DLQ** — on success ack; on failure retry with backoff; on max-retry → DLQ.

## Phase 3 — Retrieve

- `ai/architecture.md` — message bus topology.
- `ai/patterns/event-sourcing.md` if event-sourced.
- Existing handlers in same service — mirror their shape (logger, metrics, idempotency table name).
- Schema of the event (per the project's serialization choice — Avro / JSON Schema / Protobuf / Cap'n Proto / etc.).

## Phase 4 — Generate (stack-agnostic shape)

The handler function:

1. **Validate** — parse the raw event with the project's schema validator (per the project's stack); reject malformed events. Set span attributes for the event's identifying fields (e.g., `event.orderId`, `event.tenantId`).
2. **Idempotency** — compute a key (e.g., `handler:onOrderCreated:<orderId>`). Atomically check + reserve the key in the project's idempotency store with a TTL longer than the broker's max-retry window; if already processed, return `skipped`.
3. **Effect** — perform the side effect (call other services, write to DB, etc.).
4. **Outcome** — on success, increment success counter, return `processed`. On retryable failure (network blip, 5xx, timeout), record exception, release the idempotency reservation, increment retryable-failure counter, rethrow so the broker re-delivers. On non-retryable failure (validation, business-rule violation), record exception, increment permanent-failure counter, publish to the DLQ, return `dead-lettered`.

Configure the broker / queue / event-stream platform's consumer with: max retries, exponential backoff base, dead-letter topic / queue. Use the platform's native consumer-config primitive.

## Phase 5 — Update

- `ai/patterns/event-handlers.md` — add this handler's row to the inventory.
- `ai/architecture.md` — show the new event flow if non-trivial.
- Tests in handler test file.
- Metrics dashboard updated to include this handler's counters.
- Alert added if `handler.<name>.permanent_failure` rate exceeds threshold.

## Phase 6 — Validate

Enumerate the required scenarios; each MUST actually run and be GREEN:

- Unit test: happy path, retryable failure, non-retryable failure, idempotency replay.
- Integration test: produce a real event; verify handler processes; verify ack to broker.
- DLQ test: produce an event that triggers non-retryable; verify it lands in DLQ.
- Idempotency test: produce same event twice; verify side effect runs once.
- Schema-version test: produce event with unknown `eventVersion`; verify graceful skip + alert.
- Replay test: re-run from earlier offset; verify idempotency holds (no duplicate effects).

**Green-or-HALT gate (mechanical, mirrors `perf-audit`'s after-projection halt).** `scenarios_green == scenarios_required OR HALT`. Every enumerated scenario test above must have actually EXECUTED and PASSED — an intended-but-unrun scenario counts as red. If any scenario is red / failing / unrun: HALT, report the failing scenario, do NOT emit the `## /add-event-handler complete` / success block. The output must render the real per-scenario pass/fail result (from the actual test run), never an asserted checklist.

## Phase 7 — Improve

- Common idempotency pattern → extract helper.
- Common DLQ replay procedure → automate via `dlq-replay` skill.
- Schema versioning conventions → propose pattern.

## Output format

```
## /add-event-handler complete

Handler: <name>
Subscribes: <topic / queue>
Side effect: <what>
Idempotency: enabled (key: <pattern>)
Retry policy: <max>, <backoff>
DLQ: <topic / queue>

Files written:
- handler
- tests
- broker config
- ai/patterns/event-handlers.md (updated)

Tested (actual run — PASS/FAIL per scenario, all must be PASS):
- happy / retryable / non-retryable / idempotency (unit)   PASS
- integration (process + ack)                              PASS
- DLQ (non-retryable lands in DLQ)                         PASS
- idempotency (same event twice → effect once)             PASS
- schema-version (unknown version → skip + alert)          PASS
- replay (earlier offset → no duplicate effects)           PASS
scenarios_green: <n>/<required>  (block emitted only when equal)
```

## Hard rules

- **Idempotent.** Same event twice → same effect once.
- **Schema-validated.** Reject malformed events; log, don't crash.
- **Schema-version aware.** Unknown version → skip + alert; don't process.
- **Retryable errors retry; non-retryable DLQ.** Both metrics counted.
- **Observable.** Span per handler invocation; counters per outcome.
- **Bounded retry.** Eventually DLQ; never infinite retry.
- **No PII in event payload logs.** Log IDs; mask PII.

## Failure modes

- Idempotency key wrong (not actually unique per event) → effect skipped.
- Idempotency table never cleaned → unbounded growth.
- Treated all errors as retryable → poison-message stuck retrying forever.
- Treated all errors as non-retryable → transient failures lost in DLQ.
- DLQ has no replay procedure → events accumulate; never re-processed.
- Schema migration: producer ships v2; handler assumes v1 → silent skip OR crash.
- Order-dependent processing (event A must complete before event B) but no guarantee from broker.
- Handler reads from cache that hasn't propagated yet → stale state.

## Related

- `add-saga` command — when 2+ events coordinate.
- `audit-distributed-tx` command — periodic stuck-saga check.
- `dlq-replay` skill — re-process DLQ.
- `ai/patterns/event-sourcing.md` — overlapping for event-sourced systems.
