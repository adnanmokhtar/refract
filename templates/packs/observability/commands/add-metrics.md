---
description: Add metrics (counters / gauges / histograms) to a service. RED method for HTTP services + USE method for resource-bound services + SLO-relevant signals. OpenTelemetry / Prometheus.
---

# /add-metrics

## The Premise (read this first, internalize, do not deviate)

**Existing metrics are the truth.** If the service (or any sibling service in the same repo) already emits metrics, those naming conventions, label sets, units, and bucket boundaries ARE the convention. New metrics MUST mirror sibling instrumentation: same metric naming convention (`http.server.duration` vs `http_request_duration_seconds` — pick the one already in use), same label keys (`route` vs `path`, `status` vs `status_code`), same unit suffix, same bucket layout. Don't invent new conventions.

**The agent's job is exactly this:**
1. Find one existing instrumented module in this repo. Read its meter setup, metric names, label keys, buckets.
2. Mirror that shape for the new metrics. Same prefix. Same separator. Same label keys. Same units.
3. Only deviate when an accepted ADR documents the divergence — otherwise, sibling parity wins.

**The agent does NOT:**
- Invent a new metric prefix because "the OTel docs use dots and the codebase uses underscores."
- Add a new label key (`tenant`, `customer_id`, `region`) that no sibling metric uses.
- Pick histogram buckets from a blog post when sibling histograms have established buckets.
- Draft an ADR mid-run to legitimize a new convention. **Sibling wins. Mirror it.**

**Closure verb (default): mirror-sibling.** Auto-apply parity edits silently; batch into the end-of-run summary. Only halt on the three escalation triggers below.

**Escalation triggers (halt and ask):**
- No sibling instrumentation exists anywhere in the repo (greenfield — user picks the convention).
- Sibling convention is internally inconsistent (two services use two prefixes — user picks).
- The new metric genuinely cannot fit sibling shape (different unit domain, different cardinality envelope) — surface and ask.

That's it. Everything else is silent sibling-parity emission.

## Mechanical halt — instrumentation-naming parity

Before finishing Phase 4, run these checks. Any failure = HALT, surface, do not advance:

1. **Metric prefix parity** — `grep` the repo for existing meter `createCounter` / `createHistogram` / `createGauge` calls. Every new metric name MUST share the prefix root (e.g., `http.server.*` vs `http_server_*`) of the closest sibling. New prefix = ADR required.
2. **Label key parity** — collect the union of label keys used by sibling metrics in the same domain. New metrics MUST use the same key spellings (`route` not `path`, `status` not `status_code`) when the semantic is the same.
3. **No new field/label names without ADR** — if the new metric introduces a label key that no sibling metric uses, halt. Either drop the label, reuse a sibling key, or write an ADR.
4. **Unit + bucket parity** — histograms in the same dimension (latency ms, payload bytes) reuse sibling buckets unless data-justified divergence is documented inline.

Add the check results to the output block under `Naming-parity: ✓ | halts=<N>`.

Add metrics where they're missing. Use when:
- A service has logs but no metrics dashboards.
- SLOs / SLAs need defining; no signals to base them on.
- Existing metrics are ad-hoc; need standardization.

## Phases applied

All 7.

## Phase 1 — Understand

- What service / endpoint / job?
- Backend: Prometheus / Datadog / CloudWatch / New Relic / Grafana Cloud / OpenTelemetry collector?
- SLO targets if defined.
- Existing dashboards if any.

## Phase 2 — Organize

Two methods + custom:

1. **RED** (Rate / Errors / Duration) — for request-driven services (HTTP, gRPC, queue consumer).
2. **USE** (Utilization / Saturation / Errors) — for resource-bound (CPU, memory, queue length, connection pool).
3. **Business metrics** — domain-specific (orders/min, signups/day, payment success rate).

## Phase 3 — Retrieve

Tools by ecosystem:
- Node.js: `@opentelemetry/sdk-metrics` + Prometheus exporter OR `prom-client`.
- Python: `opentelemetry-sdk-metrics` OR `prometheus_client`.
- Go: `go.opentelemetry.io/otel/metric` OR `prometheus/client_golang`.
- Java: Micrometer + Prometheus registry.
- Ruby: `prometheus-client`.
- .NET: System.Diagnostics.Metrics + OpenTelemetry.

Read project's:
- `ai/architecture.md` — service topology.
- Existing dashboards / Grafana JSON.
- SLO declarations if any.

## Phase 4 — Generate

OpenTelemetry (Node.js example):

```ts
import { MeterProvider, PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics'
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http'
import { Resource } from '@opentelemetry/resources'

const meterProvider = new MeterProvider({
  resource: new Resource({ 'service.name': 'api' }),
  readers: [new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({ url: 'http://collector:4318/v1/metrics' }),
    exportIntervalMillis: 10_000,
  })],
})
const meter = meterProvider.getMeter('api')

// RED — HTTP server
const httpRequestCounter = meter.createCounter('http.server.request.count', {
  description: 'Total HTTP requests handled',
})
const httpErrorCounter = meter.createCounter('http.server.error.count', {
  description: 'HTTP responses with status >= 500',
})
const httpDurationHistogram = meter.createHistogram('http.server.duration', {
  description: 'HTTP request duration ms',
  unit: 'ms',
})

// In middleware
app.use((req, res, next) => {
  const start = Date.now()
  res.on('finish', () => {
    const labels = { method: req.method, route: req.route?.path ?? 'unknown', status: res.statusCode }
    httpRequestCounter.add(1, labels)
    if (res.statusCode >= 500) httpErrorCounter.add(1, labels)
    httpDurationHistogram.record(Date.now() - start, labels)
  })
  next()
})

// Business metric
const orderCounter = meter.createCounter('orders.placed.count', {
  description: 'Orders placed',
})
function onOrderPlaced(order) {
  orderCounter.add(1, { tenant: order.tenantId, plan: order.plan })
}
```

USE method (DB connection pool):

```ts
const dbConnUsed = meter.createObservableGauge('db.connections.used')
const dbConnMax = meter.createObservableGauge('db.connections.max')
dbConnUsed.addCallback(obs => obs.observe(pool.totalCount - pool.idleCount))
dbConnMax.addCallback(obs => obs.observe(pool.options.max))
```

## Phase 5 — Update

- `ai/runtime/metrics-catalog.md` — list every metric, what it measures, what alerts on it.
- `ai/runtime/dashboards.md` — links to each dashboard.
- `ai/runbooks/metrics.md` — what to do when each metric alarms.
- `.env.example` — `OTEL_*` env vars.

## Phase 6 — Validate

- Metrics arrive at backend (Prometheus / Datadog / etc.).
- Cardinality is bounded (no high-cardinality labels like `user_id` — use trace_id at the trace layer instead).
- Dashboards render (RED dashboard, USE dashboard, business KPI dashboard).
- No PII in metric labels.

## Phase 7 — Improve

- New dashboard pattern emerged → propose template.
- Alerting on this metric set → spawn `/alert-design`.
- Cardinality explosion detected → flag for cleanup.

## Output format

```
## /add-metrics complete

Service: <name>
Backend: <prom/dd/etc.>
Counters:    <count>
Histograms:  <count>
Gauges:      <count>
Cardinality budget: <count> max time series; estimated current <count>

Dashboards: <links>
Catalog: ai/runtime/metrics-catalog.md
```

## Hard rules

- **No PII / secrets / high-cardinality labels.** `user_id` as a label = exploding cardinality. Use trace_id (one-off identifier) for those queries.
- **Cardinality budget** declared per metric. Without bounds, Prometheus dies.
- **Histograms have explicit buckets.** Default buckets are usually wrong; set per metric (e.g., HTTP duration: 1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 ms).
- **Resource attributes set** so multi-environment dashboards work.

## Failure modes

- Cardinality explosion (every `user_id` as label) → Prometheus OOM.
- No buckets set on histograms → useless P99.
- Counter that never resets across deploys (use `_total` suffix; Prometheus convention).
- Custom metric named `error_count` then later `errors_count` → broken dashboards.
- Metric only in one environment → dashboards break in others.

## Related

- `add-tracing` — metrics + tracing pair.
- `alert-design` — alerts on these metrics.
- `slo-audit` — uses these metrics for SLO measurement.
- `@telemetry-architect` — broader strategy.
- `.claude/rules/observability-principles.md`.
