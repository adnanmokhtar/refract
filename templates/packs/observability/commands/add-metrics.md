---
description: Add metrics (counters / gauges / histograms) to a service. RED method for HTTP services + USE method for resource-bound services + SLO-relevant signals. OpenTelemetry / Prometheus.
---

# /add-metrics

**A narrow entry point into `/add-telemetry`, not a lighter alternative to it.** This file owns the
metric-specific depth — meter shape, label sets, units, bucket choice, the cardinality computation.
Everything else is inherited and MUST NOT be re-derived here:

- **The Premise + mechanical halt** — sibling instrumentation is the truth; mirror the sibling's
  metric prefix, label keys, units and buckets. Full text and the three escalation triggers:
  `commands/add-telemetry.md § The Premise`. On a greenfield repo, run its four-row convention
  ledger rather than halting with "user picks".
- **Closure** — the emit-and-assert ledger, the `ASSERTED / SKIPPED(reason) / FAILED` vocabulary and
  the closure gate in `commands/add-telemetry.md`. A metrics-only run produces a one-row-per-metric
  ledger and is held to exactly the same bar. **A narrower command does not get a weaker gate.**

Use when:
- A service has logs but no metrics dashboards.
- SLOs / SLAs need defining; no signals to base them on.
- Existing metrics are ad-hoc; need standardization.

## Phases applied

All 7.

## Phase 1 — Understand

- What service / endpoint / job?
- Backend: the project's metrics backend (vendor-neutral OTel collector + a TSDB OR a managed vendor — Datadog, New Relic, Grafana Cloud, CloudWatch, etc.)?
- SLO targets if defined — they decide the histogram buckets (Phase 4).
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
- One existing instrumented module — mirror its meter setup, names, label keys, buckets.

## Phase 4 — Generate

Define the meter, then register one counter for request count, one counter for error count, one histogram for duration, and observable gauges for resource utilization (e.g., DB connection pool used / max). Use the project's stack-native API for whichever metrics library is in use; the conceptual shape is identical across libraries:

- A meter scoped to the service name.
- RED counters/histograms labeled by `method`, `route`, `status` (bounded cardinality).
- Business counters labeled by `plan` / `channel` — and by `tenant` only after running the arithmetic below.
- Observable gauges for resource saturation (pool used, queue depth, FD count).

Wire metric recording into request middleware / interceptors / decorators per the project's framework. Set unit + bucket boundaries explicitly on histograms — defaults are usually wrong.

### Units and names

- Base SI units, always: `_seconds`, `_bytes`, `_ratio`. **Never `_milliseconds`** — and never a
  bucket list expressed in milliseconds either, which is the same violation one level down.
- Counter suffix `_total`; service prefix so `requests_total` from three services is three
  distinguishable series.
- Where the project mirrors OTel semantic conventions rather than a local scheme, the stable HTTP
  server latency metric is `http.server.request.duration` — a Histogram in **seconds**. The
  pre-stabilization `http.server.duration` is not the current name.

### Histogram buckets

One rule first: **put a bucket edge exactly at the SLO threshold T.** A latency SLI is a *count* of
requests under T, and a classic histogram can only count at a bucket boundary — anything else is
interpolation, and the SLI will disagree with the burn-rate alert computed from the same series.

Default when no SLO pins it yet — the OpenTelemetry advisory set for HTTP server duration, in
seconds: `[0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1, 2.5, 5, 7.5, 10]`. Use it
verbatim rather than inventing a list, so services stay comparable and nobody re-derives it per PR.
Shift the whole range for a different workload (long jobs: `[1, 5, 10, 30, 60, 300, 1800]`).

Native / exponential histograms remove the bucket choice — but only where they are actually
scraped. Both gates in `ai/patterns/metrics.md § Histogram buckets` (server version, and the
scrape-side setting) must clear first; emitting them into a server that is not scraping them emits
nothing, silently.

### Cardinality — compute it, don't judge it

```
series = ∏(distinct values per label) × replicas
```

Write the number in the run summary before adding any label. `tenant_id` is the case that matters on
a multi-tenant service: it is the most useful dimension you have *and* the one that detonates the
TSDB — `3 statuses × 20 routes × 10,000 tenants × 6 replicas = 3.6M series`. Default resolution:
top-N tenants on the metric plus an `other` bucket, and full tenant fidelity on logs, traces and
exemplars where it costs nothing. Worked table in `ai/patterns/metrics.md § Cardinality discipline`.

## Phase 5 — Update

- `ai/runtime/metrics-catalog.md` — list every metric, what it measures, what alerts on it.
- `ai/runtime/dashboards.md` — links to each dashboard.
- `ai/runbooks/metrics.md` — what to do when each metric alarms, plus the scrape command from Phase 6 so the operator step is repeatable.
- The project's env-config example file — telemetry exporter env vars.

## Phase 6 — Validate

Split: gates the agent verifies from code/config, and a live checklist the operator confirms against the running backend (the agent can't see the backend UI — do NOT report "metrics arrived" / "dashboards render" as auto-passed).

Agent-verified (static + synthetic):
- Cardinality is bounded — the computed series count is recorded, and a test asserts the label allow-list.
- No PII in metric labels — same label-allow-list assertion.
- Histograms declare explicit buckets, in seconds, with an edge at T where an SLO exists — assert on the meter config.
- The metric is reachable: scrape the local `/metrics` endpoint (or run the exporter in a test) and assert the new series names + label keys appear.

**Record the result in the emit-and-assert ledger** defined in `commands/add-telemetry.md` — one row
per metric, evidence column carrying the scrape command and what it returned, `Status` from that
command's `ASSERTED / SKIPPED(reason) / FAILED` vocabulary, and Status computed from the ledger by
its closure gate. A metric nobody scraped is `SKIPPED`, which is UNVERIFIED, which is `INCOMPLETE` —
never a silent pass.

OPERATOR CHECKLIST (live — confirm against the metrics backend, NOT auto-passed):
- [ ] Fire a synthetic request / run the documented smoke step → the new metrics arrive at the project's metrics backend.
- [ ] Dashboards render (RED dashboard, USE dashboard, business KPI dashboard) with real data.

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
Cardinality: <computed series count> = <the arithmetic>

Emit-and-assert ledger: <rows> metrics — ASSERTED <a> | SKIPPED <s> | FAILED <f>
  <the ledger table from add-telemetry, verbatim, with evidence per row>

Dashboards: <links>
Catalog: ai/runtime/metrics-catalog.md
Status: <computed from the ledger per add-telemetry's closure gate>
```

## Hard rules

- **No PII / secrets / high-cardinality labels.** `user_id` as a label = exploding cardinality. Use `trace_id` at the trace layer for those queries.
- **Cardinality computed and recorded** per metric, not asserted. Without the number, the bound is a feeling.
- **Histograms have explicit buckets, in base SI seconds**, with an edge at the SLO threshold. Default buckets are usually wrong; millisecond buckets are wrong twice.
- **Resource attributes set** so multi-environment dashboards work.
- **Closure comes from the ledger**, not from a hand-written line.

## Failure modes

- Cardinality explosion (every `user_id` as label) → metrics backend OOM.
- No buckets set on histograms → useless P99.
- Buckets with no edge at the SLO threshold → the SLI and its own burn-rate alert disagree.
- Counter that never resets across deploys (use `_total` suffix where the project's metrics convention requires it).
- Custom metric named `error_count` then later `errors_count` → broken dashboards.
- Metric only in one environment → dashboards break in others.
- Reporting done on "the code compiles" without a scrape → the series may not exist at all.

## Related

- `add-telemetry` — the parent command; owns the Premise, the ledger and the closure gate this one inherits.
- `add-tracing` — the trace-side narrow entry point; pair them.
- `alert-design` — alerts on these metrics.
- `slo-audit` — uses these metrics for SLO measurement.
- `@telemetry-architect` — broader strategy.
- `ai/patterns/metrics.md` — buckets, cardinality arithmetic, naming, references.
- `.claude/rules/observability-principles.md`.
