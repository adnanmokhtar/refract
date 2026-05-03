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

See [`templates/snippets/instrumentation-parity.md`](../../../snippets/instrumentation-parity.md). **This command** emphasizes metric prefix, label keys, units, and histogram buckets — mirror sibling meters per the premise above.

Add the check results to the output block under `Naming-parity: ✓ | halts=<N>`.

Add metrics where they're missing. Use when:
- A service has logs but no metrics dashboards.
- SLOs / SLAs need defining; no signals to base them on.
- Existing metrics are ad-hoc; need standardization.

## Phases applied

All 7.

## Phase 1 — Understand

- What service / endpoint / job?
- Backend: the project's metrics backend (vendor-neutral OTel collector + a TSDB OR a managed vendor — Datadog, New Relic, Grafana Cloud, CloudWatch, etc.)?
- SLO targets if defined.
- Existing dashboards if any.

## Phase 2 — Organize

Two methods + custom:

1. **RED** (Rate / Errors / Duration) — for request-driven services (HTTP, gRPC, queue consumer).
2. **USE** (Utilization / Saturation / Errors) — for resource-bound (CPU, memory, queue length, connection pool).
3. **Business metrics** — domain-specific (orders/min, signups/day, payment success rate).

## Phase 3 — Retrieve

Use the project's stack-native metrics library — every mainstream language has at least one OpenTelemetry SDK plus a native client (e.g., a Prometheus client for the language, a vendor agent SDK, or the standard library's metrics namespace if applicable). Pick the one already in use; if greenfield, prefer the OpenTelemetry SDK for vendor neutrality.

Read project's:
- `ai/architecture.md` — service topology.
- Existing dashboards (exported JSON / IaC / templating language).
- SLO declarations if any.

## Phase 4 — Generate

Define the meter, then register one counter for request count, one counter for error count, one histogram for duration, and observable gauges for resource utilization (e.g., DB connection pool used / max). Use the project's stack-native API for whichever metrics library is in use; the conceptual shape is identical across libraries:

- A meter scoped to the service name.
- RED counters/histograms labeled by `method`, `route`, `status` (bounded cardinality).
- Business counters labeled by `tenant`, `plan` (only if cardinality is bounded for your scale).
- Observable gauges for resource saturation (pool used, queue depth, FD count).

Wire metric recording into request middleware / interceptors / decorators per the project's framework. Set unit + bucket boundaries explicitly on histograms — defaults are usually wrong.

## Phase 5 — Update

- `ai/runtime/metrics-catalog.md` — list every metric, what it measures, what alerts on it.
- `ai/runtime/dashboards.md` — links to each dashboard.
- `ai/runbooks/metrics.md` — what to do when each metric alarms.
- The project's env-config example file — telemetry exporter env vars.

## Phase 6 — Validate

- Metrics arrive at the project's metrics backend.
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
- **Cardinality budget** declared per metric. Without bounds, time-series storage dies.
- **Histograms have explicit buckets.** Default buckets are usually wrong; set per metric (e.g., HTTP duration: 1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 ms).
- **Resource attributes set** so multi-environment dashboards work.

## Failure modes

- Cardinality explosion (every `user_id` as label) → metrics backend OOM.
- No buckets set on histograms → useless P99.
- Counter that never resets across deploys (use `_total` suffix where the project's metrics convention requires it).
- Custom metric named `error_count` then later `errors_count` → broken dashboards.
- Metric only in one environment → dashboards break in others.

## Related

- `add-tracing` — metrics + tracing pair.
- `alert-design` — alerts on these metrics.
- `slo-audit` — uses these metrics for SLO measurement.
- `@telemetry-architect` — broader strategy.
- `.claude/rules/observability-principles.md`.
