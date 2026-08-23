---
name: metrics
description: "Pattern: Metrics (RED + USE + Business)"
kind: ai-pattern
pack: observability
---

# Pattern: Metrics (RED + USE + Business)

> **Hard rule:** Every service exports RED (Rate, Errors, Duration) per endpoint, USE (Utilization, Saturation, Errors) per resource, and ≥1 business KPI. Metric names are stable and namespaced; cardinality is bounded (no user IDs, request IDs, or unbounded labels in tags).

**When to apply**
- A service handles non-trivial production traffic and on-call needs to detect regressions before customers.
- A new endpoint or background worker is added — RED metrics are part of the definition of done.
- A KPI (orders/min, signups/hr) is the leading signal product cares about.

**When NOT to apply**
- A short-lived script or one-off batch job — exit code + log line is enough.
- Local dev tooling — metrics infrastructure adds cost without value.

**Halt conditions / mandatory cites**
- Each metric MUST cite the emit site at `<path:line>` AND the dashboard / alert that consumes it.
- Each label set MUST cite its cardinality bound — no `user_id`, `request_id`, or unbounded enums.
- A doc proposing a new metric without a dashboard or alert that uses it is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is observable".
- If the metric backend (the project's TSDB / vendor / OTel collector — whatever is in use) isn't extracted, halt.

Numerical time series describing how the system is behaving — request rates, queue depths, business KPIs. Metrics are cheaper than logs (one number per minute vs one log line per request), aggregate naturally, and form the backbone of dashboards + alerts. Without them, you find out something's broken from a customer email.

## Context

Reach for metrics when:
- The service has any meaningful traffic (more than a handful of requests/day).
- You need to graph trends over hours/days/weeks (logs don't aggregate).
- On-call needs to answer "is anything broken right now?" in under 30 seconds.
- Capacity planning needs throughput history ("we'll hit DB limit at this growth rate").

For a one-user CLI or a cron job that runs daily, exit codes + an alert channel are enough. Don't pay metrics infrastructure for a single-call workflow.

## Three frameworks: RED, USE, Business

You need all three. Each answers a different question.

| Framework | Scope | Question |
|---|---|---|
| RED | Per request-driven service | "Is this service serving its callers well?" |
| USE | Per resource (CPU, memory, pool, queue) | "Is the resource healthy or saturated?" |
| Business | Per domain concept (orders, signups, revenue) | "Is the product working for users?" |

### RED — per service

- **Rate** — requests per second per endpoint, labelled by status.
- **Errors** — error rate (derive from rate via status label, or as a separate counter).
- **Duration** — request duration as a histogram (NOT a single average; you need percentiles).

### USE — per resource

- **Utilization** — what fraction is actively used (CPU%, memory%, DB pool in-use).
- **Saturation** — pending work (DB pool wait queue, job backlog, semaphore waiters).
- **Errors** — resource-level errors (DB connection failures, OOM kills, disk-full).

### Business — per domain concept

- Domain counters: `orders_placed_total`, `signups_total`, `payments_authorized_amount_total`.
- Domain gauges: `active_subscriptions`, `cart_in_progress`.
- Domain histograms: `order_total_amount` (revenue distribution).

## Metric types

| Type | Behavior | Use for | Example |
|---|---|---|---|
| Counter | Monotonically increasing | "How many" totals | `requests_total`, `errors_total` |
| Gauge | Goes up and down | "How many right now" | `active_connections`, `queue_depth` |
| Histogram | Bucketed distribution | Latencies, sizes | `request_duration_seconds` |
| Summary | Pre-computed quantiles per instance | Latency on a single instance | Rare; use histogram if you have multiple instances |

Histogram > summary in distributed systems: histograms aggregate across instances (you can compute `p95(global)` from per-instance buckets), summaries do not (a per-instance p95 doesn't average to a global p95).

## Naming conventions (Prometheus / OpenTelemetry style; adapt to the project's convention)

- Lowercase with underscores: `http_request_duration_seconds`.
- Counter suffix: `_total`. So `http_requests_total`, NOT `http_requests`.
- Unit suffix: `_seconds`, `_bytes`, `_ratio`. NEVER `_milliseconds` (base SI units convention).
- Service prefix: `orders_requests_total` not `requests_total` — disambiguates when you have many services.
- Labels lowercase: `status`, `method`, `endpoint`, `tenant`.

If the project's metrics backend uses a different convention (e.g., dot-separated names, or the OTel semantic conventions, where the stable HTTP server latency metric is `http.server.request.duration` — a Histogram in **seconds**, not the pre-stabilization `http.server.duration` in milliseconds), mirror sibling services rather than this pattern.

## Cardinality discipline

Cardinality = number of unique label combinations = number of time series. Each series is a row in the TSDB; series count drives storage cost.

```
http_requests_total{method="GET", endpoint="/orders", status="200"}  ← 1 series
```

If you label by `tenant_id` with 1k tenants, that becomes 1k series per (method, endpoint, status). If you ALSO label by `user_id` with 1M users, you get 1B series and the TSDB falls over.

```
GOOD labels (bounded):  status, method, endpoint, plan, region, cache_hit
BAD labels (unbounded): user_id, request_id, order_id, raw_url_with_query, email, IP
```

**Compute the series count; don't eyeball the label.** The number that decides it is a product, and every factor is knowable before you merge:

```
series = ∏(distinct values per label) × replicas
```

Worked, because this is the decision that actually bites on a multi-tenant service. `tenant_id` is
simultaneously the most useful dimension you have and the one most likely to detonate:

| Metric | Labels | Series |
|---|---|---|
| `orders_requests_total{status}` | 3 statuses × 6 replicas | 18 |
| `+ route` | 3 × 20 routes × 6 | 360 |
| `+ tenant_id`, 200 tenants | 3 × 20 × 200 × 6 | 72,000 |
| `+ tenant_id`, 10,000 tenants | 3 × 20 × 10,000 × 6 | **3,600,000** |

So "`tenant_id` is fine under 10k tenants" is not a rule — it is only true when the *rest* of the
product is small. Prometheus's own guidance is to keep a metric's cardinality below ~10 distinct
values per label and to treat anything past ~100 as needing a different design, so a tenant label
is already over budget by that standard at three-digit tenant counts.

Two moves resolve it, and they are not alternatives — use both:

- **On the metric**: label by the top-N tenants and bucket the rest into a single `other` value. You
  keep per-tenant alerting for the tenants anyone would page about, and the series count stops
  growing with signups.
- **On logs, traces and exemplars**: full tenant fidelity, always. `tenant_id` is a *field*, not a
  label — that is where "which tenant?" is answered, and it costs nothing in the TSDB.

If you need per-user analysis, that's logs or traces — never metrics.

## Shape of instrumentation (stack-agnostic)

Per service, register:

- A **request counter** labeled by `method`, `endpoint`, `status` — tracks RED rate + errors.
- A **duration histogram** labeled by `method`, `endpoint`, with explicit buckets — the OTel advisory set below, plus an edge at the SLO threshold T.
- A **resource saturation gauge** for the heaviest pool / queue (DB connection pool waiting, job queue depth) — tracks USE saturation.
- A **business counter** for the most important domain event (orders placed, signups completed) labeled by tenant + channel (only if cardinality stays bounded).

Wire request recording into the framework's middleware / interceptor / decorator chain so every route emits without per-handler boilerplate. Use the route pattern (e.g., `/orders/:id`) as the `endpoint` label — never the raw path with substituted values, which explodes cardinality.

## Histogram buckets — one rule, then a default

**The rule that actually matters: put a bucket edge exactly at your SLO threshold T.** A latency SLI
is a *count* of requests under T (see `slo.md`), and a classic histogram can only count at a bucket
boundary — everything else is interpolation. If the SLO is "99% under 300 ms" and the nearest edges
are 0.25 and 0.5, the SLI is a guess, and it will disagree with the burn-rate alert computed from
the same series. Every other bucket choice is a resolution/cost trade; this one is correctness.

**Default when no SLO pins it yet:** the OpenTelemetry advisory bucket set for
`http.server.request.duration`, in **seconds** —

```
[0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1, 2.5, 5, 7.5, 10]
```

Use it verbatim rather than inventing a list, so that every service in the repo is comparable and
nobody re-derives it per PR. Shift the whole range for a different workload (long-running jobs:
`[1, 5, 10, 30, 60, 300, 1800]`), and add an edge at T when the SLO lands. Do not hand-write
`[1, 2, 3, ... 100]` — 100 buckets per series, and `histogram_quantile` sees only the edges you
defined, so too few is imprecise and too many is pure storage cost.

**Native / exponential histograms remove the trade-off — where they're actually available.**
Prometheus **native histograms** and OTel **exponential histograms** auto-scale buckets to the
observed data with a bounded relative error: high-resolution percentiles across orders of magnitude
without hand-picking edges, at far lower series cost than a wide classic list. Two gates before you
rely on them:

- **Version.** Prometheus native histograms were experimental from v2.40 behind
  `--enable-feature=native-histograms` and became a **stable** feature in **v3.8.0**. Before 3.8,
  treat them as experimental.
- **Scrape config.** Stability is not sufficient — scraping them must still be enabled explicitly
  via the `scrape_native_histograms` setting. In 3.8 the old feature flag's only remaining effect is
  to default that setting to true; from 3.9 the flag is a no-op and the setting is required; from
  v4.0 `scrape_native_histograms` and `send_native_histograms` default to true. **A service that
  emits native histograms into a server that isn't scraping them emits nothing**, silently.

So: check the server version and the scrape config first. Where both clear, prefer
native/exponential for new latency + size metrics; otherwise use the explicit bucket list above and
revisit at the upgrade.

## Dashboards

Per service, build one dashboard with these panels:

```
Row 1: REQUEST HEALTH
  - Rate (req/s) total + per endpoint
  - Error rate (%)
  - Latency p50 / p95 / p99
  - In-flight requests (gauge)

Row 2: BUSINESS
  - Orders/min (or whatever the domain KPI is)
  - Per-tenant top-10 by activity
  - Domain success rate (e.g., payment authorization rate)

Row 3: RESOURCE
  - CPU + memory
  - DB pool: in-use / total / waiting
  - Cache: hit rate / latency
  - External dep: latency + error rate per upstream

Row 4: DEPLOYMENT
  - Build version per replica
  - Replica count
  - Restart count
```

If a panel hasn't been looked at in 90 days, delete it. Dead dashboards rot.

## Alerts (rules of engagement)

- **Page only on user impact.** "Error rate > X%" is a page if X represents user pain. CPU at 90% is NOT a page (the user doesn't care; the system might cope).
- **Burn-rate alerts on SLOs**, not raw thresholds — see `slo.md`.
- **Saturation alerts as warnings** — DB pool waiters > 10 for 5min ticket, > 50 page.
- **Absent alerts** — the project's alerting backend's "no data" / `absent(...)` predicate catches "the service died and stopped reporting".

Fast SLO burn: 14.4× over 1h burns 2% of the monthly budget. Express in the project's alerting backend syntax: ratio of error-status rate over total rate, compared to `(1 − SLO) × 14.4`. The full three-tier table (which tiers page and which tickets) is in `slo.md` — don't re-derive it here.

## Trade-offs

Pro: cheap to emit, easy to graph, perfect for trends + alerts. Pro: aggregates across instances/regions/tenants. Con: cardinality is a foot-gun — one bad label kills the TSDB. Con: metrics are pre-aggregated and lossy; you can't drill into a single request from a metric. Con: histogram bucket choice locks in percentile resolution; changing buckets later loses comparability.

For per-request investigation, use traces. For "what was in this exact request", use logs. Metrics are for "is the trend healthy".

## Common mistakes

- **Labelling by user_id, request_id, or anything user-input.** TSDB fills up, queries slow to a crawl, eventually pager goes off because the metrics backend itself is at capacity.
- **Using a gauge increment as a counter.** Gauges are for "current value"; using them as counters loses data on restart and races between instances. Use a counter primitive.
- **Average latency, not percentiles.** A mean of 100ms across 99% fast + 1% timeout is meaningless. p95/p99 reveal the slow tail.
- **Same metric name across services.** `requests_total` in three services = ambiguous in queries. Prefix: `orders_requests_total`, `auth_requests_total`.
- **Dead metrics.** Emitted but never graphed or alerted = pure cost. Delete or hide behind a feature flag.
- **Panel screenshots in incident reports.** A panel from "10 minutes ago" doesn't reproduce the data — link the dashboard at a time range.
- **Counters that reset.** A counter that goes back to 0 on restart breaks rate calculations. Counters must monotonically increase across the process lifetime; cumulative across restarts is the TSDB's job.

## Testing

- Unit-test that the metric is emitted with expected labels: spy on the registry and assert.
- Integration test: hit the endpoint, scrape the project's metrics endpoint, assert the line exists with non-zero value.
- Cardinality test in CI: count distinct label combinations after a representative test run; fail if > threshold.

## Migration path

If you have no metrics today:
1. Add the project's metrics client (OTel SDK preferred for vendor neutrality, or a stack-native client) to one service. Expose the metrics endpoint the project's backend scrapes.
2. Auto-instrument HTTP via the framework middleware. Now you have RED for free.
3. Add USE for the heaviest resource (usually DB pool or job queue).
4. Add ONE business metric — the most important domain counter. Prove the value.
5. Build the standard dashboard. Hook the first SLO burn-rate alert.
6. Repeat per service. Resist the urge to add metrics for things you'll never look at.

## Related

- `dashboards.md` — the *reading surface* for these metrics: RED/USE/business panels are visualized there, tiered and versioned-as-code, with the alert→panel linkage. The "delete a panel/metric nobody reads in 90 days" rule is shared both ways.
- `slo.md` — burn-rate alerts consume these metrics; the burn panel and the burn-rate rule come from the same spec.
- `skills/alert-audit/SKILL.md` — audits the alerts wired on top of these metrics.

## References

- Prometheus metric + label naming — `https://prometheus.io/docs/practices/naming/`
- Prometheus instrumentation practices (the cardinality guidance quoted above) — `https://prometheus.io/docs/practices/instrumentation/`
- Prometheus native histograms (stability, `scrape_native_histograms`) — `https://prometheus.io/docs/specs/native_histograms/`
- OpenTelemetry HTTP metrics semconv (`http.server.request.duration` + its advisory buckets) — `https://opentelemetry.io/docs/specs/semconv/http/http-metrics/`
- Brendan Gregg — the **USE** method (utilization / saturation / errors, per resource): `https://www.brendangregg.com/usemethod.html`
- Tom Wilkie — the **RED** method (rate / errors / duration, per request-driven service): `https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/`
- *Site Reliability Engineering* ch. 6, "Monitoring Distributed Systems" — the **four golden signals** (latency, traffic, errors, saturation), which is the ancestor of both methods above but is not itself RED or USE: `https://sre.google/sre-book/monitoring-distributed-systems/`
