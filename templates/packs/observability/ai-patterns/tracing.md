---
name: tracing
description: Pattern: Distributed Tracing (OpenTelemetry)
kind: ai-pattern
pack: observability
---

# Pattern: Distributed Tracing (OpenTelemetry)

> **Hard rule:** Every cross-service call propagates W3C trace context; spans wrap units of work with stable names, status codes, and bounded attributes. Sampling is decided at the edge (head-based) or via tail-based collector, not silently per-service. PII in span attributes is forbidden.

**When to apply**
- A request crosses ≥ 2 services and "where did the time go?" is hard to answer from logs alone.
- A latency regression's root cause lives in an upstream you don't own (DB, third-party API).
- An incident retro showed correlation IDs were missing or trace context broke at a boundary.

**When NOT to apply**
- A monolith with no outbound calls — RED metrics + structured logs cover the same ground cheaper.
- A throughput-bound batch job where every span adds overhead — sample aggressively or skip.

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

- **Collector** — local daemon/sidecar that receives spans from apps + ships to the project's trace backend (vendor-neutral examples: Jaeger, Tempo; vendor-managed examples: Datadog, New Relic, Honeycomb, Lightstep, Cloud Trace).
- **SDKs** per language auto-instrument HTTP clients, DBs, popular libraries.

## Setup per service (stack-agnostic)

In each service's entry point (loaded BEFORE any instrumented library), bootstrap the project's stack-native OpenTelemetry SDK:

- Configure resource attributes (`service.name`, `service.version`, `deployment.environment`).
- Configure an exporter pointing at the project's trace backend (OTLP for vendor-neutral; vendor-specific exporter where committed).
- Register auto-instrumentations for the project's HTTP server / client / DB / queue libraries.
- Start the SDK before any instrumented module loads.

## Manual spans for business logic (stack-agnostic)

Auto-instrumentation catches HTTP + DB. For business logic, wrap the operation in a manual span using the project's tracer API:

1. Open a span with a stable name (`placeOrder`, `<domain>.<verb>` per sibling convention).
2. Set bounded attributes on the span (`tenant_id`, counts, `entity_id`).
3. On exception, record the exception and set status to ERROR; rethrow.
4. End the span in finally.

Match the project's tracer SDK calls and attribute key conventions to sibling services.

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
