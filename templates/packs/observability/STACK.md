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

Metric and attribute **names** are not a per-stack substitution — they come from the OpenTelemetry
semantic conventions, which are versioned and have moved. Read the registry before writing a name
(`https://opentelemetry.io/docs/specs/semconv/`); do not write one from memory. The pack's current
spellings and the `OTEL_SEMCONV_STABILITY_OPT_IN` migration switch are in `ai/patterns/tracing.md`.

## Enforcement

Tooling that enforces the always-loaded rule. Names are stack-specific, so they live here rather
than in `rules/observability-principles.md`:

- **Stdout ban** — the project's stack-native linter forbids direct stdout / unstructured print
  calls outside dev tooling (an ESLint rule, a Ruff/flake8 rule, `forbidigo` for Go, a Checkstyle
  rule, an analyzer for .NET). One rule, one allowlist for dev tooling.
- **Whole-object logs** — a multi-language `semgrep` rule flags logger calls that pass a user /
  request object directly instead of named fields.
- **Cardinality budget** — a CI step counts distinct label combinations emitted by a representative
  test run and fails on regression past the declared budget per metric (`ai/patterns/metrics.md`
  § Testing).
- **Dashboards + alert rules as code** — boards and rules live in the repo (Terraform / Crossplane /
  Grafonnet / vendor dashboards-as-code API) and are reviewed in PRs like any other file.
- **Telemetry pipeline back-pressure** — the OpenTelemetry Collector (or the equivalent agent) is
  configured with a bounded memory queue and an explicit drop policy, so "best-effort" is a decision
  someone made rather than a default nobody read.

## Cross-pack boundaries this pack asserts

- **RUM / field Core Web Vitals** — the *performance* pack owns field measurement + attribution (`web-vitals-field`); this pack owns RUM ingestion, retention, cardinality and dashboarding. Design the pipe here; defer the field optimisation there.
- **Profiling** — the *performance* pack owns ad-hoc / dev-time profiling (`/profile-perf`); this pack owns always-on production profiling and its trace linkage.
- **Audit logging** — the *security* pack owns WHAT must be recorded and for how long; this pack owns the pipeline that records it tamper-evidently.
- **Tracing** — the *distributed-systems* pack owns trace coverage as a resilience SLO; this pack owns the span mechanics that satisfy it.

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual logger name, log helper, trace SDK init location, metrics-registry binding.
- The project's `_extracted-codebase.md § Observability` — log-field convention, correlation-ID middleware, metrics namespace, alert-rule directory.
- The project's `ai/runbooks/` — alert-to-runbook mapping (every alert has `runbook_url` annotation).

Universal hard rules (no `console.log`, no PII in logs, no high-cardinality labels, every alert has a runbook) are framework-agnostic.
