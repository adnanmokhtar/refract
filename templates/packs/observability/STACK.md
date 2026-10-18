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
- **Alert rules gate** — CI runs `promtool check rules` and the committed `promtool test rules`
  files (fire at the failure, silent at a blip) over every loaded rule file, with pint or the
  pack's `rule-inventory.py` beside them, on the binary of the server's Prometheus major; the job
  fails on a seeded bad rule. `/obs-audit` checks this as its RULES GATE row.
- **Telemetry pipeline back-pressure** — the OpenTelemetry Collector (or the equivalent agent) is
  configured with a bounded memory queue and an explicit drop policy, so "best-effort" is a decision
  someone made rather than a default nobody read.

## Cross-pack boundaries this pack asserts

One owner per class. Each row applies **when the owner pack is installed**; without it the row is
listed by the observability detector that saw it, tagged `<class> (owner pack not installed)`, and
never graded here (`precedents/observability.md` P2). The observability column is everything this pack
may file for that class.

| Class | Owner | What observability keeps |
|---|---|---|
| A secret, token or PII value in any log, span, tracker event or telemetry sink; the redaction set; `sendDefaultPii` / `dataCollection` | **security** `data-exposure-scan` § 6 | The redaction *mechanism* in the logger and collector; `/obs-fix` re-runs that skill's canary after touching a logger, serializer or sink. Hashing an email or id is never offered as redaction (precedents § 32) |
| Log injection (CR/LF into text logs) | **security** `injection-scan` § 10 | — (a JSON encoder downgrades it) |
| Public health or actuator details · publicly served source maps · inline notification secrets (Slack webhook, PagerDuty key, Sentry auth token) | **security** `data-exposure-scan` § 3 · `xss-scan` § 13 · `secret-scan-method` | "The tracker cannot symbolicate" (`error-tracking-scan` §3); `hidden` maps + delete-after-upload satisfy both |
| A dropped or swallowed error; a cause lost on rethrow; an empty or comment-only catch | **code-quality** `error-handling-scan` | A handled failure that writes no log ≥ warn, counter or span event (LG-01, `log-signal-scan` §1) and an error log that loses its stack or type (LG-02, §2) |
| Liveness that checks a shared dependency | **performance** `request-path-scan` §15 | Readiness that lies (HC-01, `metric-hygiene-scan` §7) and probe traffic in telemetry (HC-02, §8) |
| Probe presence, shape and timings in manifests; `terminationGracePeriodSeconds` | **infrastructure** `k8s-availability-scan` §2, `@k8s-reviewer` | — (the handler's semantics above are observability's and performance's) |
| PrometheusRule / ServiceMonitor / PodMonitor schema; collector and agent RBAC wiring; proxy and ingress access-log format | **infrastructure** (`k8s-wiring-scan` §6 for RBAC wiring, `k8s-api-version-scan` §2 for schema, judged by `@k8s-reviewer`); RBAC privilege breadth → **security** `iac-scan` § 3 | Whether a rule or monitor is *selected* (AL-22, `alert-rule-lint` §4; PL-09, `telemetry-config-scan` §7) and the telemetry blast radius of a collector, as corroboration |
| A CI job that runs promtool / pint but is masked (`continue-on-error`, `\|\| true`, a skipped required check) | **devops** `pipeline-integrity-scan` §1–§3 | The RULES GATE's existence and power in `/obs-audit`, corroborated |
| The graceful-shutdown chain (SIGTERM → drain → exit) | **devops** (code chain) · **infrastructure** (manifest) | Only the telemetry flush inside it (LG-06, `trace-propagation-scan` §5) |
| Canary analysis and post-deploy watch queries | **devops** (`progressive-delivery`, `monitor-deploy`) | The grounding technique: an analysis selector that resolves in no inventory is AL-10-shaped — devops cites `rule-inventory.py --check=selectors` |
| Volume, series and retention cost in money | **finops** `@cost-reviewer` | The arithmetic: series = ∏ distinct label values × replicas, bytes per request, bytes per day |
| Native symbol upload (dSYM, R8 / ProGuard mapping) | **mobile** | Release, environment and process hooks for mobile tracker SDKs (`error-tracking-scan` §1–§2) |
| RUM / field Core Web Vitals | **performance** `web-vitals-field` (field measurement + attribution) | RUM ingestion, retention, label cardinality and dashboarding — design the pipe here, defer the field optimisation there |
| Profiling | **performance** `/profile-perf` (ad-hoc, dev-time) | Always-on production profiling and its trace linkage |
| Audit logging | **security** (WHAT must be recorded, and for how long) | The pipeline that records it tamper-evidently |
| Trace coverage as a resilience target | **distributed-systems** | The span mechanics that satisfy it |

Inside the pack, one owner per output: `alert-rule-lint` owns every decidable alert check and
`alert-audit` only alert behaviour; `slo-rule-scan` owns SLO definitions, `slo-audit` attainment and
the single write of `ai/runtime/slos.md` (`/alert-design` proposes rows and dispatches it);
`@sre-engineer` owns the budget-policy text and postmortems (`ai/reliability/**`);
`@incident-responder` owns runbook bodies (`ai/runbooks/**`). The class → detector map is
`ownership.json` rows `obs-logs` … `obs-pipeline`.

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual logger name, log helper, trace SDK init location, metrics-registry binding.
- The project's `_extracted-codebase.md § Observability` — log-field convention, correlation-ID middleware, metrics namespace, alert-rule directory.
- The project's `ai/runbooks/` — alert-to-runbook mapping (every alert has `runbook_url` annotation).

Universal hard rules (no `console.log`, no PII in logs, no high-cardinality labels, every alert has a runbook) are framework-agnostic.
