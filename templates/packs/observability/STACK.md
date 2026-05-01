# Observability pack — stack assumption

This pack's rules, agents, skills, and patterns assume:

- **A structured logger** emitting JSON in production (Pino / Winston / structlog / Logback / slog / zerolog / serilog)
- **OpenTelemetry** as the trace + metrics primitive (vendor-neutral; collector exports to Prom / Datadog / Tempo / Honeycomb / etc.)
- **A metrics backend** with histogram support (Prometheus / Datadog / OTLP-compatible TSDB)
- **A trace backend** (Jaeger / Tempo / Datadog APM / Honeycomb / New Relic)
- **A log aggregation sink** (Loki / Datadog / CloudWatch / Elasticsearch / Splunk)
- **An alerting platform** with runbook-link annotations (Prometheus Alertmanager / Datadog Monitors / PagerDuty / Opsgenie)

## Inline examples in this pack

Wherever this pack's files show concrete syntax, examples lean **Node.js + Pino + OpenTelemetry SDK** for illustration. Substitute per stack:

| Node + Pino + OTel (illustrated) | Java + Logback + Micrometer | Python + structlog | Go + zerolog + otel-go | .NET + Serilog | Substitution source |
|---|---|---|---|---|---|
| `pino` w/ `pino-http` | `Logback` JSON encoder | `structlog.configure(...)` | `zerolog` JSON | `Serilog.Sinks.Console` JSON | structured logger |
| `@opentelemetry/api` | `io.micrometer.tracing` | `opentelemetry.trace` | `go.opentelemetry.io/otel` | `OpenTelemetry .NET` | trace API |
| `Counter` / `Histogram` (OTel Metrics) | Micrometer `Counter` / `Timer` | `meter.create_histogram` | `prometheus.NewHistogram` | `Meter.CreateHistogram` | metrics primitive |
| `traceparent` header propagation | Spring Sleuth / OTel auto | `opentelemetry.propagate` | otel propagators | `ActivitySource` | trace context |
| Prometheus scrape `/metrics` | Actuator `/actuator/prometheus` | `prometheus_client` | `promhttp.Handler()` | `prometheus-net` | metrics endpoint |
| Grafana / Datadog dashboards (Terraform / Jsonnet) | same | same | same | same | dashboard-as-code |

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual logger name, log helper, trace SDK init location, metrics-registry binding.
- The project's `_extracted-codebase.md § Observability` — log-field convention, correlation-ID middleware, metrics namespace, alert-rule directory.
- The project's `ai/runbooks/` — alert-to-runbook mapping (every alert has `runbook_url` annotation).

Universal hard rules (no `console.log`, no PII in logs, no high-cardinality labels, every alert has a runbook) are framework-agnostic.
