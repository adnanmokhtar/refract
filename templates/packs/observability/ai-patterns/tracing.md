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

- Configure resource attributes (`service.name`, `service.version`, `deployment.environment.name`).
- Configure an exporter pointing at the project's trace backend (OTLP for vendor-neutral; vendor-specific exporter where committed).
- Register auto-instrumentations for the project's HTTP server / client / DB / queue libraries.
- Start the SDK before any instrumented module loads.

## Span names + SpanKind — the two things auto-instrumentation cannot guess for you

**Name a span for its *class* of operation, never for one instance of it.** A span name is a
low-cardinality grouping key: every backend aggregates latency by it, so `GET /orders/8814` splits
one endpoint into a million one-sample groups and makes the p95 meaningless.

- HTTP server spans: `{method} {route-template}` — `GET /orders/{id}`, not the substituted path.
  If the framework cannot supply a route template, the convention is the bare method (`GET`) — a
  low-cardinality wrong-ish name beats a high-cardinality right-ish one.
- HTTP client spans: `{method}` alone (the target lives in attributes, not the name).
- Business spans: `<domain>.<verb>` (`orders.place`) per sibling convention.

**SpanKind is load-bearing, not decoration.** `SERVER` / `CLIENT` / `PRODUCER` / `CONSUMER` /
`INTERNAL` is what tells the backend which spans are *edges* between services — the service map,
the "which upstream is slow" view, and RED-from-traces are all derived from it. A traced service
whose every span is `INTERNAL` renders as a single node with no dependencies.

## Manual spans for business logic (stack-agnostic)

Auto-instrumentation catches HTTP + DB. For business logic, wrap the operation in a manual span using the project's tracer API:

1. Open a span with a stable, low-cardinality name (`orders.place`) and the right SpanKind (`INTERNAL` for in-process work; `CLIENT` / `PRODUCER` if it leaves the process).
2. Set bounded attributes on the span (`tenant_id`, counts, `entity_id`).
3. On exception, record the exception and set status to ERROR; rethrow.
4. End the span in finally.

Match the project's tracer SDK calls and attribute key conventions to sibling services.

## Propagation across services

HTTP: W3C Trace Context headers (`traceparent`, `tracestate`) — auto by SDK.

Queues: include trace context in message metadata. Consumer extracts + continues trace.

## Attributes — use the semantic convention where one exists

Two kinds of attribute, and only one of them is yours to name.

**Convention attributes** are defined by the OpenTelemetry semantic conventions. Use the current
spelling: backends key their built-in HTTP/DB views, their service map, and their RED panels off
these exact names, so a "close enough" spelling silently produces an empty dashboard rather than an
error. **They have been renamed** — several attributes still in wide circulation are deprecated:

| Deprecated (do not write) | Current, Stable | Notes |
|---|---|---|
| `http.method` | `http.request.method` | |
| `http.status_code` | `http.response.status_code` | |
| `http.url` | `url.full` (client) | On a **server** span the pieces are `url.path`, `url.query`, `url.scheme` + `server.address` — there is no full-URL server attribute. `url.full` is the whole URL, so it is the wrong home for "path only, no query string". |
| `http.target` | `url.path` + `url.query` | Strip or redact `url.query` — it is the usual PII leak. |
| `db.system` | `db.system.name` | |
| `db.statement` | `db.query.text` | Parameterized text only; never the bound values. |
| `deployment.environment` | `deployment.environment.name` | A **resource** attribute, not a span one — set once at SDK init, so neither the `http` nor the `database` opt-in below covers it. Migrate by hand: carry **both** keys on the `Resource` while you re-point dashboard and alert filters, then drop the deprecated one. |
| — | `db.operation.name` | The operation (`SELECT`, `findAndModify`) as its own attribute. |

Verify against the registry rather than this table when you write one:
`https://opentelemetry.io/docs/specs/semconv/registry/attributes/` — the conventions version, not
this pattern, is the authority.

**Migrating an existing service is a config switch, not a rewrite.** SDKs read
`OTEL_SEMCONV_STABILITY_OPT_IN`: `http` / `database` emit the new names, and `http/dup` /
`database/dup` emit **both** old and new simultaneously. Run `/dup` while you re-point dashboards
and alert rules, then drop to the new-only value. Cutting over in one step is what breaks the
graphs — the dual-emit window is the whole point of the switch.

**Project attributes** are the ones no convention covers — your domain. Name them under a project
prefix (`tenant_id`, `entity_id`, `cache.hit`, `error_code`, `operation`) and mirror the sibling
span's spelling exactly. Every one must have a bounded value space.

Never an attribute: raw request/response bodies, a full URL carrying query params, anything
per-request-unique (that is what `trace_id` is), or a timestamp (the span already has two).

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

- **Deprecated semantic-convention attribute** — `http.url`, `http.method`, `http.status_code`,
  `db.system`, `db.statement` written on a new span, or `deployment.environment` on the resource.
  Replace per the table above; if the service is mid-migration, set
  `OTEL_SEMCONV_STABILITY_OPT_IN=http/dup,database/dup` for the span attributes and say so in the
  PR — the resource rename has no opt-in, so carry both keys until the dashboards are re-pointed.
- **High-cardinality span name** — a substituted path or an ID in the span name (`GET /orders/8814`).
  Latency aggregates by name, so this destroys the p95. Use the route template.
- **Every span `INTERNAL`** — SpanKind never set on the calls that cross a process boundary, so the
  backend renders one node with no edges and no service map.
- **Broken async boundary** — a queue publish opens a span but the consumer starts a *new* trace
  because context was never put in (or read out of) the message metadata. Two half-traces, no join.
- **Trace context but no log correlation** — spans exist and logs exist, and no log line carries
  `trace_id` / `span_id`, so a slow trace cannot be turned into the log lines that explain it.
- **Head sampler in front of the errors** — a fixed-ratio sampler applied at the edge with no
  always-sample-on-error rule, so the traces you most need are the ones most likely dropped.

## References

- OpenTelemetry HTTP spans semantic conventions — `https://opentelemetry.io/docs/specs/semconv/http/http-spans/`
- OpenTelemetry database spans semantic conventions — `https://opentelemetry.io/docs/specs/semconv/database/database-spans/`
- Attribute registry (the authority on current spellings) — `https://opentelemetry.io/docs/specs/semconv/registry/attributes/`
- HTTP semconv migration guide (`OTEL_SEMCONV_STABILITY_OPT_IN`) — `https://opentelemetry.io/docs/specs/semconv/non-normative/http-migration/`
- W3C Trace Context — `https://www.w3.org/TR/trace-context/`
- OpenTelemetry Collector (tail sampling, batching, back-pressure) — `https://opentelemetry.io/docs/collector/`

## Related

### Same pack
- `ai/patterns/metrics.md`, `ai/patterns/structured-logging.md` — the other pillars; correlate by the shared `trace_id`.
- `@telemetry-architect`, `@observability-reviewer` — design + review the spans this pattern defines.

### Cross-pack (when co-installed)
- **distributed-systems pack** — reciprocal boundary. This pattern owns the trace **how**: span naming, W3C context propagation, sampling policy. The distributed-systems rule owns **trace coverage as a resilience SLO** ("every endpoint has spans visible in the trace backend") — that pack asserts the coverage target, this pattern implements the spans that satisfy it.
