---
name: metrics
kind: example
pack: observability
---

# Pattern: Metrics (RED + USE + Business)

> **Hard rule:** Every service exports RED (Rate, Errors, Duration) per endpoint, USE (Utilization, Saturation, Errors) per resource, and ≥1 business KPI. Metric names are stable and namespaced; cardinality is bounded (no user IDs, request IDs, or unbounded labels in tags).

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

## Naming conventions (Prometheus / OpenTelemetry)

- Lowercase with underscores: `http_request_duration_seconds`.
- Counter suffix: `_total`. So `http_requests_total`, NOT `http_requests`.
- Unit suffix: `_seconds`, `_bytes`, `_ratio`. NEVER `_milliseconds` (Prometheus convention is base SI units).
- Service prefix: `orders_requests_total` not `requests_total` — disambiguates when you have many services.
- Labels lowercase: `status`, `method`, `endpoint`, `tenant`.

## Cardinality discipline

Cardinality = number of unique label combinations = number of time series. Each series is a row in the TSDB; series count drives storage cost.

```
http_requests_total{method="GET", endpoint="/orders", status="200"}  ← 1 series
```

If you label by `tenant_id` with 1k tenants, that becomes 1k series per (method, endpoint, status). If you ALSO label by `user_id` with 1M users, you get 1B series and the TSDB falls over.

```
GOOD labels (bounded):  status, method, endpoint, tenant (small N), plan, region, cache_hit
BAD labels (unbounded): user_id, request_id, order_id, raw_url_with_query, email, IP
```

Rule of thumb: each label should have ≤ ~100 distinct values, and the cross product across all labels on a metric should be ≤ ~10k series.

If you need per-user analysis, that's logs or traces — not metrics.

## Code example (Prometheus client, Node)

```ts
import { Counter, Histogram, Gauge } from 'prom-client';

// RED: rate + duration
const httpRequests = new Counter({
  name: 'orders_http_requests_total',
  help: 'Total HTTP requests to orders service',
  labelNames: ['method', 'endpoint', 'status'],
});

const httpDuration = new Histogram({
  name: 'orders_http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'endpoint'],
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],  // explicit buckets
});

// USE: pool saturation
const dbPoolWaiting = new Gauge({
  name: 'orders_db_pool_waiting',
  help: 'Number of operations waiting for a DB connection',
});

// Business
const ordersPlaced = new Counter({
  name: 'orders_placed_total',
  help: 'Orders successfully placed',
  labelNames: ['tenant', 'channel'],
});

// Middleware (Express/Fastify)
app.use((req, res, next) => {
  const end = httpDuration.startTimer({ method: req.method, endpoint: routePattern(req) });
  res.on('finish', () => {
    end();
    httpRequests.inc({
      method: req.method,
      endpoint: routePattern(req),
      status: res.statusCode.toString(),
    });
  });
  next();
});
```

Note `routePattern(req)` returns `/orders/:id`, NOT `/orders/abc-123`. Raw paths explode cardinality.

## Histogram buckets — pick deliberately

```
[0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]   // good: 9 buckets, web API range
[1, 2, 3, ...100]                              // bad: 100 buckets per series, cost explodes
```

Default buckets in most clients are not appropriate for every workload. For sub-second APIs, use the example above. For long-running jobs, shift higher: `[1, 5, 10, 30, 60, 300, 1800]`.

The percentile calculation (`histogram_quantile(0.95, ...)`) only sees the buckets you defined — too few buckets gives imprecise percentiles, too many wastes storage.

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
- **Absent alerts** — `absent(http_requests_total{service="api"})` catches "the service died and stopped reporting".

```promql
# fast SLO burn: 14.4x over 1h burns 2% of monthly budget
(
  sum(rate(orders_http_requests_total{status=~"5..|4.."}[1h])) /
  sum(rate(orders_http_requests_total[1h]))
) > (1 - 0.999) * 14.4
```

## Trade-offs

Pro: cheap to emit, easy to graph, perfect for trends + alerts. Pro: aggregates across instances/regions/tenants. Con: cardinality is a foot-gun — one bad label kills the TSDB. Con: metrics are pre-aggregated and lossy; you can't drill into a single request from a metric. Con: histogram bucket choice locks in percentile resolution; changing buckets later loses comparability.

For per-request investigation, use traces. For "what was in this exact request", use logs. Metrics are for "is the trend healthy".

## Common mistakes

- **Labelling by user_id, request_id, or anything user-input.** TSDB fills up, queries slow to a crawl, eventually pager goes off because Prometheus itself is at capacity.
- **`gauge.inc()` as a counter.** Gauges are for "current value"; using them as counters loses data on restart and races between instances. Use `Counter`.
- **Average latency, not percentiles.** A mean of 100ms across 99% fast + 1% timeout is meaningless. p95/p99 reveal the slow tail.
- **Same metric name across services.** `requests_total` in three services = ambiguous in queries. Prefix: `orders_requests_total`, `auth_requests_total`.
- **Dead metrics.** Emitted but never graphed or alerted = pure cost. Delete or hide behind a feature flag.
- **Panel screenshots in incident reports.** A panel from "10 minutes ago" doesn't reproduce the data — link the dashboard at a time range.
- **Counters that reset.** A counter that goes back to 0 on restart breaks `rate()` calculations. Counters must monotonically increase across the process lifetime; cumulative across restarts is the TSDB's job.

## Testing

- Unit-test that the metric is emitted with expected labels: spy on the registry and assert.
- Integration test: hit the endpoint, scrape `/metrics`, assert the line exists with non-zero value.
- Cardinality test in CI: count distinct label combinations after a representative test run; fail if > threshold.

## Migration path

If you have no metrics today:
1. Add the Prometheus client (or OTel SDK) to one service. Expose `/metrics`.
2. Auto-instrument HTTP via the framework middleware. Now you have RED for free.
3. Add USE for the heaviest resource (usually DB pool or job queue).
4. Add ONE business metric — the most important domain counter. Prove the value.
5. Build the standard dashboard. Hook the first SLO burn-rate alert.
6. Repeat per service. Resist the urge to add metrics for things you'll never look at.

## References

- Prometheus naming conventions (prometheus.io/docs/practices/naming) — the canonical reference.
- "Site Reliability Engineering" Google book, ch. 6 — RED + USE methodology origin.
- Brendan Gregg's USE method (brendangregg.com/usemethod.html) — resource saturation methodology.
- Tom Wilkie's RED method talk (RED Method for Microservices) — request-driven services.
- OpenTelemetry metrics SDK docs — vendor-neutral alternative to Prometheus client libs.
