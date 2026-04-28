---
description: Add distributed tracing to a service / endpoint / job. OpenTelemetry-first; vendor-agnostic. Spans + context propagation + sampling + attributes; produces a working trace + a runbook entry.
---

# /add-tracing

Add OpenTelemetry tracing where it's missing. Use when:
- Service has structured logs but no tracing → debugging "where did this slow down" requires correlating logs.
- Microservice graph but no end-to-end traces → blind to cross-service latency.
- One specific endpoint chronically slow + no visibility into which sub-call.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## Phase 1 — Understand

- What service / endpoint / job?
- Existing tracing (none, partial, vendor-specific)?
- Backend (Jaeger / Tempo / Datadog APM / Honeycomb / New Relic / Cloud Trace / Lightstep / etc.)?
- Existing log aggregator? Trace ↔ log correlation needed?

## Phase 2 — Organize

Per ecosystem, the work decomposes:

1. **SDK install** — OpenTelemetry SDK + exporter for the target backend.
2. **Auto-instrumentation** — drop in for HTTP server / client / DB / queue.
3. **Manual instrumentation** — custom spans around business operations the auto-instrument doesn't cover.
4. **Context propagation** — verify trace context flows: incoming → internal → outgoing requests.
5. **Sampling** — configure (head-based / tail-based / parent-based) appropriate to volume.
6. **Trace ↔ log correlation** — inject `trace_id` into log structured fields.
7. **Resource attributes** — service.name, service.version, deployment.environment, host.name.

## Phase 3 — Retrieve

Tools:
- Node.js: `@opentelemetry/sdk-node` + auto-instrumentations.
- Python: `opentelemetry-distro` + `opentelemetry-instrumentation`.
- Go: `go.opentelemetry.io/otel` + `otelhttp`/`otelgin` etc.
- Java: OpenTelemetry Java agent (zero-code) OR manual SDK.
- Ruby: `opentelemetry-instrumentation-all`.
- .NET: OpenTelemetry SDK.
- Browser: `@opentelemetry/sdk-trace-web` + Browser Range header propagator.

Read project's:
- `ai/architecture.md` — service topology.
- Existing logger setup — for trace_id injection.
- Production deployment config — for resource attributes.
- Existing APM (vendor) config if any — to mirror or migrate.

## Phase 4 — Generate

For Node.js (illustrative; adapt per stack):

```ts
// tracing.ts — bootstrapped FIRST in main entry
import { NodeSDK } from '@opentelemetry/sdk-node'
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'
import { Resource } from '@opentelemetry/resources'
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions'

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.SERVICE_NAME ?? 'api',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.GIT_SHA ?? 'unknown',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV ?? 'production',
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT ?? 'http://localhost:4318/v1/traces',
  }),
  instrumentations: [getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-fs': { enabled: false }, // noisy
  })],
})
sdk.start()
```

Manual span around a business op:

```ts
import { trace } from '@opentelemetry/api'
const tracer = trace.getTracer('orders-service')

async function placeOrder(order) {
  return tracer.startActiveSpan('orders.placeOrder', async span => {
    span.setAttribute('order.tenant_id', order.tenantId)
    span.setAttribute('order.line_count', order.lines.length)
    try {
      const result = await processOrder(order)
      span.setAttribute('order.id', result.id)
      return result
    } catch (err) {
      span.recordException(err)
      span.setStatus({ code: SpanStatusCode.ERROR })
      throw err
    } finally {
      span.end()
    }
  })
}
```

Logger correlation (pino example):

```ts
import { context, trace } from '@opentelemetry/api'
import pino from 'pino'

const logger = pino({
  mixin: () => {
    const ctx = trace.getSpanContext(context.active())
    return ctx ? { trace_id: ctx.traceId, span_id: ctx.spanId } : {}
  }
})
```

Sampling (parent-based + head-based 10%):

```ts
import { ParentBasedSampler, TraceIdRatioBasedSampler } from '@opentelemetry/sdk-trace-base'

const sampler = new ParentBasedSampler({
  root: new TraceIdRatioBasedSampler(0.1)
})
```

Production: use head-based 1-10% for steady-state + a tail-based collector for "always sample errors / slow requests."

## Phase 5 — Update

- `ai/runbooks/tracing.md` — runbook entry. How to correlate trace + log; how to find a specific request; common queries.
- `ai/architecture.md` — note that observability stack now includes tracing.
- `.env.example` — add `OTEL_*` env vars with defaults / placeholders.
- Add `tracing.ts` (or equivalent) to bootstrap.
- Update CI to verify env vars set in production.

## Phase 6 — Validate

- A trace appears in the backend (Jaeger / Tempo / Datadog) for a synthetic request.
- Cross-service trace works (front-end → api → DB → cache → queue) — span graph reflects reality.
- Trace ID present in log lines.
- Sampling configured (you're not sampling 100% in production).
- Resource attributes set (service.name, version, env).
- Sensitive data NOT in span attributes (no full request bodies; no auth tokens).

## Phase 7 — Improve

- If many manual spans cluster around one feature → propose a tracing-aware decorator pattern.
- If the trace surfaces a perf hotspot → spawn `/profile-perf`.
- If sampling rate tuning needed → ADR for the rate decision.

## Output format

```
## /add-tracing complete

Service:                  <name>
Backend:                  <Jaeger / Tempo / DD / etc.>
Auto-instrumentations:    <count>
Manual spans:             <count>
Sampling rate:            <%>
Trace↔log correlation:    enabled
Sensitive data filtering: configured

Files written:
- tracing.ts
- ai/runbooks/tracing.md
- .env.example (additions)

First trace landed: <link>
```

## Hard rules

- **No PII / secrets in span attributes.** Names, emails, tokens, full URLs with query strings — all forbidden.
- **Resource attributes set.** Without service.name + env, traces are useless across services.
- **Trace_id in logs.** Without correlation, logs and traces are two unrelated data sources.
- **Sampling configured.** 100% in production = expensive + noisy. Default ~1-10% with always-sample-errors via tail sampling.
- **Auto-instrumentation first; manual second.** Custom spans only where auto doesn't reach (business ops, sub-operations within a function).

## Failure modes

- Forgot to bootstrap tracing FIRST → some libraries won't be instrumented.
- Auto-instrumentation noisy → too many spans of low value.
- Sampling too aggressive (1%) → missing the slow tail.
- Shipped with PII in span attributes → privacy violation.
- Trace_id missing from logs → every debugging session starts with "find me the request."
- Resource attributes hardcoded → all envs look the same in the backend.

## Related

- `add-metrics` — metrics counterpart; pair them.
- `alert-design` — uses tracing data.
- `slo-audit` skill — uses tracing latencies for SLO measurement.
- `@telemetry-architect` agent — broader observability strategy.
- `.claude/rules/observability-principles.md` — A33 (telemetry local-only) reminder for dev environments.
