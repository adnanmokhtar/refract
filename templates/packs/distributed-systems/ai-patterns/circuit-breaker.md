---
name: circuit-breaker
description: Pattern: Circuit Breaker
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Circuit Breaker

> **Hard rule:** Every cross-service call ships through a named breaker with explicit failure threshold, open-state timeout, and half-open probe count. Hand-rolled `try/catch + retry` with no breaker, breakers without metrics, or shared global breakers across unrelated dependencies are forbidden.

**When to apply**
- Outbound calls to a third-party API or another service where transient outages cascade into your latency budget.
- A dependency has measured tail latency that already trips your timeout under load.
- Retry storms have caused incidents — the breaker stops retries from worsening the upstream's recovery.

**When NOT to apply**
- In-process calls or calls to a strongly-coupled local resource (DB on the same node) — use connection-pool + timeout instead.
- Calls already wrapped in a saga / outbox where compensation handles failure semantics.

**Halt conditions / mandatory cites**
- Each breaker MUST cite the dependency it guards at `<path:line>` AND the threshold/timeout values with their rationale.
- Open-state fallback (cached value, queued retry, error) MUST cite the fallback site or the contract that allows it.
- A doc proposing a breaker without metrics (open/close events, current state) is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when justifying threshold values.
- If the project's chosen breaker library / version isn't extracted, halt before adding new breakers.

Fails fast when a downstream is degraded, preventing cascading failure + giving it time to recover.

## States

```
        failures > threshold
CLOSED ─────────────────────▶ OPEN
  ▲                             │
  │ success                     │ timer expires
  │                             ▼
  └───── success ─────── HALF-OPEN
         │                      │
         │                      │ failure
         │                      ▼
         └──────────────────── OPEN
```

- **Closed** — normal. Calls pass through.
- **Open** — recent failures exceeded threshold. Calls fail fast without hitting downstream.
- **Half-open** — after a cooldown, let ONE probe through. Success → close. Failure → back to open.

## Config per dependency (illustrative — adapt to the project's chosen library)

- `name`: the dependency this breaker guards (e.g., `payments-api`, `model-vendor`).
- `failureThreshold`: e.g. 50% of window failing opens the breaker.
- `windowSize`: e.g. last 10 calls.
- `openDuration`: e.g. 30s in open state before probing.
- `timeout`: per-call timeout.

## Shape (stack-agnostic)

The breaker wraps the call with three behaviours:

1. **Open state**: time-since-open is checked; if expired, transition to half-open; otherwise return the fallback (or throw a typed `CircuitOpenError`).
2. **Closed / half-open state**: invoke the function under the per-call timeout; on success, record success (transitions half-open → closed); on failure, record failure and either return the fallback or rethrow.
3. **State transitions**: failure rate over the window crossing the threshold transitions closed → open; a single half-open success transitions to closed; a half-open failure transitions back to open.

Use the project's stack-native circuit-breaker library — every mainstream language has at least one (e.g., `opossum` / `cockatiel` for Node, Resilience4j for JVM, Polly for .NET, `gobreaker` / `hystrix-go` for Go, `pybreaker` for Python). Do not hand-roll when an option exists.

## When to use

- External API calls (payment, AI, email, SMS).
- Non-critical internal service calls.
- Any call where "fail fast" is better than "queue up and timeout".

## When NOT to use

- Critical path with no fallback (user-facing auth check — just fail the request).
- Extremely low-volume calls (window doesn't accumulate enough data).
- Internal function calls (in-process).

## Observability

- Emit metric per state transition.
- Alert on breaker stuck OPEN for > N minutes.
- Dashboard per breaker showing state + recent failure rate.

## Forbidden

- Circuit breaker without a fallback strategy on the caller side (just wrapping with no degradation = useless).
- Hand-rolled breaker without thread safety when the runtime has concurrency.
- Shared breaker across unrelated dependencies.
