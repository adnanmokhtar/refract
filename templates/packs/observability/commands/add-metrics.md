---
description: Add metrics (counters / gauges / histograms) to a service. RED method for HTTP services + USE method for resource-bound services + SLO-relevant signals. OpenTelemetry / Prometheus.
---

# /add-metrics

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
