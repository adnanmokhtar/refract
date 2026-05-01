---
name: circuit-breaker
kind: example
pack: distributed-systems
---

# Pattern: Circuit Breaker

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

## Config per dependency

```ts
{
  name: 'claude-api',
  failureThreshold: 0.5,        // 50% of window failing opens the breaker
  windowSize: 10,                // last 10 calls
  openDuration: 30_000,          // 30s in open state before probing
  timeout: 3_000,                // call timeout
}
```

## Shape

```ts
class CircuitBreaker {
  private state: 'closed' | 'open' | 'half-open' = 'closed';
  private failures: boolean[] = [];
  private openedAt: number = 0;

  async call<T>(fn: () => Promise<T>, fallback?: () => T): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.openedAt > this.config.openDuration) {
        this.state = 'half-open';
      } else {
        if (fallback) return fallback();
        throw new CircuitOpenError();
      }
    }

    try {
      const result = await withTimeout(fn(), this.config.timeout);
      this.recordSuccess();
      return result;
    } catch (e) {
      this.recordFailure();
      if (fallback) return fallback();
      throw e;
    }
  }
}
```

## Libraries (don't hand-roll if one exists)

- Node: `opossum`, `cockatiel`
- Java/Kotlin: `resilience4j`
- Go: `sony/gobreaker`, `afex/hystrix-go`
- .NET: `Polly`
- Python: `pybreaker`

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
