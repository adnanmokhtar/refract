---
name: circuit-breaker
description: "Pattern: Circuit Breaker"
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

## Config per dependency — what DETERMINES each number

The four values below are the whole pattern, and every one of them is derived from something measurable about the dependency. A breaker copied from another service's config is a breaker tuned for another service's failure distribution.

| Knob | Determined by | Gets it wrong when |
|---|---|---|
| `failureThreshold` | The dependency's **normal** error rate, measured. Set it clearly above the noise floor (a dep that baselines 2% errors cannot use a 1% threshold) and below the rate at which your own SLO breaks | Copied as "50%" onto a dep whose steady state is 0.01% — it absorbs a real outage for minutes before tripping |
| `windowSize` | Call **volume**, not time. The window must hold enough calls for the rate to mean something — a dep called 3×/min cannot support a 10-call rolling window | Low-volume deps trip on two unlucky calls, or never accumulate enough to trip at all |
| `openDuration` | The dependency's observed **recovery time** (how long its incidents actually last, from its own incident history) | Set shorter than recovery: the probe re-opens the breaker forever and you have built a slow retry loop |
| per-call `timeout` | The **caller's** latency budget minus what the rest of the request needs — not the dependency's p99 | Set from the dep's p99: your request now inherits the dep's tail and the breaker never sees a timeout to count |

If the dependency's error rate, call volume and recovery time are not extracted, **halt** — those three numbers are the config, and guessing them produces a breaker that is decorative.

**The fallback is the design, not the breaker.** An open breaker's whole value is what the caller does instead: a cached value, a queued retry, a degraded response, or a typed error the caller handles. A breaker with no fallback converts a slow failure into a fast one and nothing more — decide the open-state behaviour first, then size the knobs.
## Shape (stack-agnostic)

The breaker wraps the call with three behaviours:

1. **Open state**: time-since-open is checked; if expired, transition to half-open; otherwise return the fallback (or throw a typed `CircuitOpenError`).
2. **Closed / half-open state**: invoke the function under the per-call timeout; on success, record success (transitions half-open → closed); on failure, record failure and either return the fallback or rethrow.
3. **State transitions**: failure rate over the window crossing the threshold transitions closed → open; a single half-open success transitions to closed; a half-open failure transitions back to open.

Use the project's stack-native circuit-breaker library — every mainstream language has at least one (e.g., `opossum` / `cockatiel` for Node, Resilience4j for JVM, Polly for .NET, `gobreaker` / `failsafe-go` for Go, `pybreaker` for Python). Do not hand-roll when an option exists.

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
