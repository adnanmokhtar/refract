---
name: observability-principles
kind: example
pack: observability
---

# Observability Principles

Prevents the 3am gap: incident fires, you have no correlation ID, no trace, no metric on the right thing, no runbook.

## Must

- Telemetry designed BEFORE the feature ships. Every PR adding an endpoint also adds: log fields, at least one metric, a trace span, an alert (or a documented reason there isn't one).
- Correlation / trace ID generated at the edge (or honored from `traceparent` header per W3C Trace Context) and propagated to every log line, every downstream HTTP / queue call, and DB query comment (`/* trace_id=... */`).
- Structured logs: JSON in prod, pretty in dev. Flat top-level fields for indexing — `reqId`, `traceId`, `tenantId`, `userId`, `entityId`, `operation`, `durationMs`, `error.code`, `error.message`.
- Log levels chosen consistently: `error` (page-worthy), `warn` (recovered, ticket-worthy), `info` (state change milestone), `debug` (off in prod).
- RED metrics per service endpoint: Rate, Errors, Duration histogram (not just average — average lies about p99).
- USE metrics per resource: Utilization, Saturation, Errors. CPU, memory, file descriptors, connection pool.
- Business metrics first-class and dashboarded: orders/min, payments/min, signups/min, revenue/hour. Outage detection by user impact, not CPU.
- Distributed traces via OpenTelemetry (vendor-neutral). Every incoming request = root span; every external IO = child span with attributes (`http.url`, `db.system`, `cache.hit`).
- Every alert has: an actionable symptom, an owner, a runbook link, and a severity. No runbook = ticket, not page.
- SLOs declared per critical service: availability % + latency p95 (or p99). Error budget tracked. Burn-rate alerts (fast burn 1h, slow burn 6h).

## Must not

- `console.log` / `print` / `fmt.Println` in committed code. Use the project logger with fields.
- Log passwords, full tokens, full PANs, full national IDs, full health data. Mask: last 4 digits or hash.
- Log objects whole (`logger.info(user)`) without scrubbing — leaks PII via field names you forgot.
- High-cardinality labels on metrics: `userId`, `requestId`, `email`, `path` with IDs in it. Will explode Prometheus / TSDB cardinality.
- Alert on causes (CPU > 80%, queue depth > 100) when the symptom is what users feel (latency, error rate, saturation of a SLO).
- Sample errors. 100% of errors trace; 1-10% of successes is fine.
- Ship a metric without a dashboard or alert. Dead metrics = paid storage, no value.
- "Best-effort" telemetry — drop spans on slow exporter, drop logs on full buffer. Configure async exporters with bounded queues + back-pressure.

## Should

- 100% trace sampling for errors, head-based 1-10% sampling for success (tail-based is better when affordable).
- Exemplars on metrics (Prometheus exemplars) link a histogram bucket back to a specific trace.
- Log + metric + trace use the SAME identifiers (`traceId`, `tenantId`) — easy navigation between pillars in Grafana / Datadog.
- Synthetic monitoring on critical user journeys (login, checkout, primary CRUD). Black-box probes catch what white-box misses.
- Dashboards version-controlled (Grafana JSON / Terraform / Jsonnet). UI-edited dashboards drift and disappear.
- One canonical service map + one critical-path latency dashboard. Don't make on-call hunt.

## Review checklist

- [ ] New endpoint emits structured logs with correlation ID and tenant ID.
- [ ] New endpoint exports rate + error + duration metric.
- [ ] New external call wrapped in a trace span with attributes.
- [ ] No new high-cardinality label on a metric.
- [ ] No PII / secret logged.
- [ ] If this is a user-facing feature: business metric added.
- [ ] If a new alert: runbook link + owner present.

## Enforcement

- ESLint / lint rule banning `console.log` outside of dev tooling.
- `semgrep` rules to flag `logger.info(<user>)` / `log.debug(<request>)` whole-object logs.
- Cardinality budget per metric in alerting platform; CI fails on regression.
- Dashboards + alert rules in code (Terraform / Crossplane / Jsonnet) reviewed in PRs.
- OpenTelemetry collector configured with a bounded memory queue + drop policy.
