---
name: tracing
kind: example
pack: observability
---

# Pattern: Distributed Tracing (OpenTelemetry)

> **Hard rule:** Every cross-service call propagates W3C trace context; spans wrap units of work with stable names, status codes, and bounded attributes. Sampling is decided at the edge (head-based) or via tail-based collector, not silently per-service. PII in span attributes is forbidden.

**Halt conditions / mandatory cites**
- Each new span MUST cite its emit site at `<path:line>` AND the parent context it inherits.
- Span attributes MUST cite their bounded value space — no `user.email`, `request.body`, raw payloads.
- A doc that loses trace context across an async boundary (queue, worker) without explicit propagation is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is traced end-to-end".
- If the OTel SDK + exporter + sampler config isn't extracted, halt.

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

## Span names + SpanKind

A span name is a low-cardinality grouping key — every backend aggregates latency by it. `GET /orders/8814` splits one endpoint into a million one-sample groups and destroys the p95.

- HTTP server: `{method} {route-template}` — `GET /orders/{id}`, never the substituted path.
- HTTP client: `{method}` alone; the target belongs in attributes.
- Business: `<domain>.<verb>` (`orders.place`) per sibling convention.

Set **SpanKind** on anything crossing a process boundary (`SERVER` / `CLIENT` / `PRODUCER` / `CONSUMER`; `INTERNAL` for in-process work). The service map and the "which upstream is slow" view are derived from it — a service whose every span is `INTERNAL` renders as one node with no edges.

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

## Attributes — the convention names have moved

**Convention attributes** are defined by the OpenTelemetry semantic conventions, and backends key their built-in HTTP/DB views off these exact strings — a stale spelling produces an empty dashboard, not an error. Several names in wide circulation are deprecated:

| Deprecated (do not write) | Current, Stable | Notes |
|---|---|---|
| `http.method` | `http.request.method` | |
| `http.status_code` | `http.response.status_code` | |
| `http.url` | `url.full` (client) | On a **server** span use `url.path`, `url.query`, `url.scheme` + `server.address`. `url.full` is the *whole* URL — it is not "path only". |
| `http.target` | `url.path` + `url.query` | Strip or redact `url.query`; it is the usual PII leak. |
| `db.system` | `db.system.name` | |
| `db.statement` | `db.query.text` | Parameterized text only, never bound values. |
| `deployment.environment` | `deployment.environment.name` | A **resource** attribute — the opt-in below does not cover it. Carry **both** keys on the `Resource`, re-point dashboard + alert filters, then drop the old one. |
| — | `db.operation.name` | The operation (`SELECT`, `findAndModify`) as its own attribute. |

Check the registry rather than memory when writing one: `https://opentelemetry.io/docs/specs/semconv/registry/attributes/`.

**Migrating an existing service is a config switch.** SDKs read `OTEL_SEMCONV_STABILITY_OPT_IN`: `http` / `database` emit the new names; `http/dup` / `database/dup` emit **both** at once. Run `/dup` while you re-point dashboards and alert rules, then drop to new-only. A one-step cutover is what breaks the graphs.

**Project attributes** — the ones no convention covers. Bounded value space, sibling spelling, project prefix:
- `tenant_id`, `entity_id`, `operation`
- `cache.hit` (boolean)
- `error_code` (closed enum)

Never an attribute: raw request/response bodies, a full URL carrying query params, anything per-request-unique (that is `trace_id`), or a timestamp (the span has two already).

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

## Detectors (what a reviewer flags)

- **Deprecated semantic-convention attribute** — `http.url`, `http.method`, `http.status_code`, `db.system`, `db.statement` on a new span, or `deployment.environment` on the resource. Replace per the table above; mid-migration, set `OTEL_SEMCONV_STABILITY_OPT_IN=http/dup,database/dup` for the span attributes and say so in the PR — the resource rename has no opt-in, so carry both keys until the dashboards are re-pointed.
- **High-cardinality span name** — a substituted path or an ID in the name. Latency aggregates by name; this destroys the p95.
- **Every span `INTERNAL`** — SpanKind never set on process-boundary calls, so the backend shows one node and no service map.
- **Broken async boundary** — publisher opens a span, consumer starts a *new* trace because context never reached the message metadata. Two half-traces, no join.
- **Trace context but no log correlation** — no log line carries `trace_id` / `span_id`, so a slow trace can't be turned into the log lines that explain it.
- **Head sampler in front of the errors** — fixed-ratio sampling at the edge with no always-sample-on-error rule; the traces you need most are the likeliest dropped.

## References

- HTTP spans semconv — `https://opentelemetry.io/docs/specs/semconv/http/http-spans/`
- Database spans semconv — `https://opentelemetry.io/docs/specs/semconv/database/database-spans/`
- Attribute registry (authority on current spellings) — `https://opentelemetry.io/docs/specs/semconv/registry/attributes/`
- HTTP semconv migration (`OTEL_SEMCONV_STABILITY_OPT_IN`) — `https://opentelemetry.io/docs/specs/semconv/non-normative/http-migration/`
- W3C Trace Context — `https://www.w3.org/TR/trace-context/`
