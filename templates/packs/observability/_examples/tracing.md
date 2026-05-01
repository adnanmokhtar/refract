---
name: tracing
kind: example
pack: observability
---

# Pattern: Distributed Tracing (OpenTelemetry)

Follow a request across services. Find where time is spent + where errors originate.

## Concepts

- **Trace** — the full journey of a request. Has a unique `trace_id`.
- **Span** — one unit of work inside a trace. Has `span_id`, `parent_span_id`, duration, attributes.
- **Context propagation** — how `trace_id` + `span_id` pass between services (headers for HTTP, metadata for queues).

## OpenTelemetry

Vendor-neutral standard. Use it over vendor-specific SDKs.

- **Collector** — local daemon/sidecar that receives spans from apps + ships to backend (Jaeger, Tempo, Datadog, New Relic, Honeycomb).
- **SDKs** per language auto-instrument HTTP clients, DBs, popular libraries.

## Setup per service

```ts
// Node example
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({ url: 'http://otel-collector:4318/v1/traces' }),
  serviceName: 'api',
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

## Manual spans for business logic

Auto-instrumentation catches HTTP + DB. For business logic, add spans manually:

```ts
const tracer = trace.getTracer('orders');

async function placeOrder(input) {
  return tracer.startActiveSpan('placeOrder', async (span) => {
    span.setAttribute('tenant_id', input.tenantId);
    span.setAttribute('items_count', input.items.length);
    try {
      const result = await doPlace(input);
      span.setAttribute('order_id', result.id);
      return result;
    } catch (e) {
      span.recordException(e);
      span.setStatus({ code: SpanStatusCode.ERROR });
      throw e;
    } finally {
      span.end();
    }
  });
}
```

## Propagation across services

HTTP: W3C Trace Context headers (`traceparent`, `tracestate`) — auto by SDK.

Queues: include trace context in message metadata. Consumer extracts + continues trace.

## Attributes

Good attributes (searchable, bounded cardinality):
- `tenant_id`, `user_id`
- `endpoint`, `operation`
- `cache_hit` (boolean)
- `error_code`

Bad attributes (cardinality explosion):
- Raw request body
- Full URL with random query params
- Timestamps as attributes (they're already on the span)

## Sampling

- 100% of errors (always).
- 1-10% of successful requests (adjust by volume).
- Tail sampling (decide to keep/drop AFTER the trace completes) preferred to head sampling when you can run a collector.

## Dashboards + alerts

- Service map: shows services + their call edges + latencies.
- Per-endpoint latency histograms from trace spans.
- Error trace link: from an error alert, one click to the full trace.

## Forbidden

- Traces without `tenant_id` / `user_id` attribution (you'll debug blind).
- PII in span attributes.
- Raw request bodies as attributes (cardinality + PII).
- Head-sampling that drops all errors (defeats the purpose).
- Trace backend without retention policy (data grows without bound).
