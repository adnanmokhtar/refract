---
name: observability-principles
kind: example
pack: observability
---

# Observability Principles

> **Hard rule.** Every PR adding an endpoint MUST also add: a structured-log line with correlation ID, at least one RED metric (rate / error / duration), a trace span, and an alert (or a documented reason there isn't one). PII / secrets / full tokens in logs and high-cardinality labels (`user_id`, `request_id`, `email`) on metrics are forbidden.

Prevents the 3am gap: incident fires, you have no correlation ID, no trace, no metric on the right thing, no runbook.

## Must

- Correlation / trace ID minted at the edge (or honored from the `traceparent` header per W3C Trace Context) and propagated to every log line, every downstream HTTP / queue call, and DB query comment (`/* trace_id=... */`).
- Structured logs: JSON in prod, pretty in dev. Flat top-level fields — `trace_id`, `span_id`, `request_id`, `tenant_id`, `user_id`, `entity_id`, `operation`, `duration_ms`, `error.code`, `error.message`. One casing per project (mirror the sibling), but `trace_id` / `span_id` are fixed by the OTel log-correlation convention — rename them and most backends stop linking logs to traces.
- Log levels used consistently: `error` (page-worthy), `warn` (recovered, ticket-worthy), `info` (state-change milestone), `debug` (off in prod).
- RED per endpoint (Rate, Errors, Duration **histogram** — an average lies about p99), USE per resource, ≥1 business metric — `ai/patterns/metrics.md`.
- Traces via OpenTelemetry. Incoming request = root span; every external IO = child span. Attribute keys come from the **current** OTel semantic conventions or from the sibling span — never from memory: `ai/patterns/tracing.md`.
- Every alert has an actionable symptom, an owner, a runbook link, a severity. No runbook = ticket, not page.
- Critical services declare an SLO (availability % + a latency SLI expressed as a *count under T*), track its error budget, and alert on it with a **multi-window multi-burn-rate** rule — a single-window threshold is not an SLO alert: `ai/patterns/slo.md`.

## Must not

- Direct stdout / unstructured print calls (any language's `console.log` / `print` / `fmt.Println` / `puts` / `echo` / `System.out.println`) in committed code. Use the project logger with fields.
- Log passwords, full tokens, full PANs, full national IDs, full health data. Mask: last 4 digits or hash.
- Log objects whole (e.g., logging the entire user / request object) without scrubbing — leaks PII via field names you forgot.
- High-cardinality labels on metrics: `user_id`, `request_id`, `email`, `path` with IDs in it. A label is safe only when `series = ∏(distinct label values) × replicas` is bounded and you have **computed** it, not asserted it.
- Alert on causes (CPU > 80%, queue depth > 100) when the symptom is what users feel (latency, error rate, SLO burn).
- Sample errors. 100% of errors trace; 1–10% of successes is fine.
- Ship a metric without a dashboard or alert. Dead metrics = paid storage, no value.
- "Best-effort" telemetry — dropping spans on a slow exporter or logs on a full buffer. Bounded queues + back-pressure.

## Should

- Logs, metrics and traces carry the SAME identifiers (`trace_id`, `tenant_id`); exemplars carry that link into histogram buckets — `ai/patterns/profiling.md`.
- Blackbox probes on every critical journey (login, checkout, primary CRUD): own probe-SLO, ≥2 locations, own page route firing independently of white-box signals — `skills/synthetic-monitoring/SKILL.md`.
- Dashboards tiered (fleet → service → instance), RED/USE-led, versioned as code, alert→panel linked — `ai/patterns/dashboards.md`.
- Client RUM exported over OTLP into the same collector; *performance* owns field-CWV measurement, this pack owns the pipe — `agents/telemetry-architect.md` § 5b.
- One canonical service map + one critical-path latency dashboard. On-call must not have to hunt.

## Greenfield defaults — when there is no sibling to mirror

Every rule above says "mirror the sibling". On a project with no instrumented sibling that instruction is inert, so pick these four once, write them down, and never re-litigate them per feature:

| Decision | Options | What decides it |
|---|---|---|
| Log field casing | `snake_case` / `camelCase` | Whatever the language's ecosystem already emits. `trace_id` / `span_id` stay snake_case either way — the OTel log-correlation convention fixes them. |
| Correlation-ID mechanism | honor an inbound `traceparent` / mint at the edge and echo it back | Whether anything upstream already propagates trace context. If nothing does, mint at the edge; either way it must reach every log line through the runtime's ambient-context primitive, not a threaded parameter. |
| Metric name + prefix | `<service>_<thing>_<unit>` counters/histograms / dotted OTel-style names | The metrics backend's own convention. Pick once; a rename later breaks every dashboard and alert. |
| Span attribute namespace | current OTel semantic conventions / a project-local `<domain>.<field>` prefix | Use the semantic convention wherever one exists — backends key their built-in views off it. Only invent a namespace for domain attributes no convention covers. |

Record the four in `ai/conventions.md` the first time `/add-telemetry` runs. From then on, "mirror the sibling" has a sibling.

## Review checklist

- [ ] New endpoint emits structured logs with correlation ID and tenant ID.
- [ ] New endpoint exports rate + error + duration metric.
- [ ] New external call wrapped in a trace span with attributes.
- [ ] No new high-cardinality label (series count computed, not asserted).
- [ ] No PII / secret logged.
- [ ] User-facing feature: business metric added.
- [ ] New alert: runbook link + owner present.

Enforcement tooling — `STACK.md § Enforcement`.
