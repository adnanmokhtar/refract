---
description: Add an event handler. Idempotent / retryable / observable / DLQ-aware. Output: handler + tests + DLQ + monitoring.
---

# /add-event-handler

Add a consumer for a single event class. Smaller than a saga — one event in, side effect(s) out, idempotent.

## Premise

Existing event handlers are the truth. Mirror sibling handler shape exactly: subscription registration, schema validation, idempotency-key pattern, error envelope, retry classification, dead-letter routing, span/metric naming. Read at least two siblings in the same service BEFORE writing — copy their conventions (idempotency table name, logger fields, metric prefix). New shapes need an ADR, not a fresh invention.

## Mechanical halt

Sibling-shape parity — refuse to generate a handler that diverges from sibling conventions without an ADR cite in the PR. If the service has zero existing handlers, halt and ask which pattern to seed from. Note the escape that is NOT available: `ai/patterns/event-handlers.md` is written by this command's own Phase 5, so on the first handler it cannot exist yet — seed from a sibling *service*'s handler, an ADR, or an explicit user decision, and let Phase 5 create the inventory that unblocks every handler after this one. The handler MUST include all five standard parts (subscription, idempotency check, validation, effect, ack/DLQ); missing any one halts generation.

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

Happy-path is the floor, not the bar. At-least-once delivery is a given on every mainstream broker, so a handler is production-grade only when it delivers **exactly-once EFFECT under redelivery** — the side effect runs once even when the same message arrives twice, arrives concurrently, or is redelivered after a crash — and when the poison-message path is bounded (a non-retryable message provably EXITS the retry loop). A handler that passes only happy + sequential-replay is FUNCTIONAL, not production-grade; this gate tests the distributed property directly.

### Precondition — dedupe reserve cited + atomic (HALT if unmet)

Before scenarios run, the dedupe reserve MUST be cited at `<path:line>` and be **atomic**. Grep the handler + its migration:

- BAD — check-then-act (races under concurrent delivery; the effect runs twice between the read and the write):

  ```
  rg -n "SELECT.*processed_events|EXISTS\(.*event_id|has(Been)?Processed\(" <handler>
  ```
  a read that gates a *separate* later INSERT is the classic non-atomic dedupe (`ai/patterns/idempotency.md` § Forbidden: "check if it exists, then create — classic race").
- GOOD — one atomic reserve: a unique-constraint `INSERT INTO processed_events(event_id)` whose **duplicate-key error IS the dedupe**, OR the `event_id` row inserted in the **same DB transaction** as the effect (both commit or both roll back). Detector:

  ```
  rg -n "ON CONFLICT|INSERT .*processed_events|UNIQUE" <handler> <migration>
  ```
  must resolve to a single atomic statement, and the effect + event-id row must share one transaction.

No atomic reserve cited → HALT. If the reserve is a distributed lock (Redis etc.) rather than a DB constraint, it MUST carry a fencing token (`ai/patterns/idempotency.md`); a lock alone is not exactly-once.

### Required failure-mode scenarios — each runs GREEN, or is marked UNVERIFIED/SKIPPED with the reason (never a faked PASS)

`scenarios_required` (all must be exercised — the last two are the exactly-once core and are the deepening over a sequential-replay test):

1. **happy path** — one delivery, one effect, ack.
2. **retryable failure → redelivery** — 5xx/network → re-enters the handler → still exactly one effect (the retry path passes through the reserve, not around it).
3. **non-retryable → DLQ, loop bounded** — assert the message reaches DLQ AND that attempts are bounded (`attempts <= maxRetries`); the message provably EXITS the loop (no infinite poison retry).
4. **schema-version unknown** — unknown `eventVersion` → skip + alert, effect not run.
5. **CONCURRENT duplicate delivery** — two deliveries of the SAME `event_id` interleaved so both pass the reserve *before* either commits → exactly one effect. A sequential twice-call CANNOT catch a check-then-act race; this scenario is what distinguishes idempotent-looking from idempotent. If the harness is single-threaded, drive the interleave explicitly (call reserve-A, reserve-B, then commit both) — otherwise mark **UNVERIFIED (no concurrency harness)**, never PASS.
6. **crash-in-the-gap (partition)** — kill the handler in the window between effect-commit and broker-ack (or between bus-publish and outbox-mark for an outbox producer); on redelivery the effect is still counted once. This proves the effect and the reserve are atomic *with respect to the ack*. If fault injection isn't available, mark **UNVERIFIED (no crash/partition harness)** — do not fake it (`chaos-test` skill is the harness for this).

Each row MUST cite the real `<test-file>::<test-name>` it ran and render that test's ACTUAL result.

**Exactly-once-effect gate — three outcomes, no fourth.** This gate is **[self-policed]**: no shell script parses this output (there is no `validate-event-handler-artifacts.sh`), so the halt is only as honest as the render — its falsifiability comes from the cited `<test-file>::<test-name>` per row, which a reviewer (or `@resilience-reviewer`) can open and re-run.

- **GREEN** — `scenarios_green == scenarios_required`, every row a cited real PASS → emit `## /add-event-handler complete`.
- **RED** — any row FAIL / unrun / cites no test → HALT, name the row, emit NOTHING but the failing row. (An asserted checklist with no `<test-file>::<test-name>` is RED by definition.)
- **INCOMPLETE** — scenarios 5/6 are UNVERIFIED because a concurrency/partition harness is absent → do NOT claim production-grade; emit the INCOMPLETE block naming exactly the unverified scenarios and the harness each needs. Functional, not shippable-as-exactly-once.

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
Dedupe reserve: <path:line>  (atomic: unique-constraint INSERT | same-tx event-id)

Files written:
- handler
- tests
- broker config
- ai/patterns/event-handlers.md (updated)

Tested (actual run — each row cites the test + renders its real result):
- happy path                              tests/onOrderCreated.spec::happy        PASS
- retryable → redelivery → effect once     …::retry_redelivers                     PASS
- non-retryable → DLQ, attempts bounded    …::poison_exits_loop                    PASS
- schema-version unknown → skip + alert    …::unknown_version                      PASS
- concurrent duplicate → exactly one       …::concurrent_dedupe                    PASS | UNVERIFIED (no concurrency harness)
- crash-in-gap → redelivery, effect once   …::crash_before_ack                     PASS | UNVERIFIED (no partition harness)
scenarios_green: <n>/<required>

Verdict: COMPLETE (production-grade) — emitted only when scenarios_green == scenarios_required with every row a cited PASS.
         INCOMPLETE — <unverified scenarios named> + the harness each needs (e.g. `chaos-test` for crash-in-gap). Functional, not exactly-once-verified.
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
- `chaos-test` skill — the fault-injection harness that turns the crash-in-gap / concurrent-duplicate scenarios from UNVERIFIED to GREEN.
- `@resilience-reviewer` agent — the challenge core; run it on the handler to audit the exactly-once-effect and check-then-act reserve before merge.
- `ai/patterns/idempotency.md` — the atomic-reserve / dedupe contract this gate enforces.
- `ai/patterns/outbox.md` — the exactly-once producer half (crash-in-gap between publish and mark).
- `ai/patterns/event-sourcing.md` — overlapping for event-sourced systems.
