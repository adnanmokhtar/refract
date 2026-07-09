---
name: slo
kind: example
pack: observability
---

# Pattern: SLOs + Error Budgets + Burn-Rate Alerting

An SLO is a target reliability for something users feel, measured by an SLI (`good events / valid events`), with an error budget (`1 − SLO`) and a multi-window multi-burn-rate alert. It turns "is it reliable enough?" from an argument into arithmetic.

This file (`ai/patterns/slo.md`) is the *method*. The project's live per-service targets live in `ai/runtime/slos.md` (the *registry*) — don't conflate them.

## SLI menu (pick the symptom, not the cause)

| SLI | Good event | Shape |
|---|---|---|
| Availability | not 5xx / RPC not failed | request-based |
| Latency (percentile) | served **faster than T** (count, not the p99 value) | request-based |
| Correctness | response complete / accurate | request-based |
| Freshness | data ≤ staleness bound | windows-based |

SLIs measure symptoms (latency/errors/staleness). CPU%, pool saturation, queue depth are *causes* → USE warnings, never an SLO.

## Error budget arithmetic (30-day window = 43,200 min)

| SLO | Budget | Allowed bad time / 30d |
|---|---|---|
| 99%    | 1%    | 7.2 h |
| 99.9%  | 0.1%  | 43 min |
| 99.95% | 0.05% | 21.6 min |
| 99.99% | 0.01% | 4.3 min |

Keep the internal SLO *below* any contractual SLA (SLA 99.9% → SLO 99.95%) so you fix before the customer notices.

## Multi-window multi-burn-rate table (1h + 6h, not 24h)

| Severity | Long | Short (confirm) | Burn rate | Sustained spend |
|---|---|---|---|---|
| **Page** (fast) | 1h | 5m  | 14.4× | 2% of budget in 1h |
| **Ticket** (slow) | 6h | 30m | 6×    | 5% of budget in 6h |

Burn rates: fast `0.02 / (1/720) = 14.4×`; slow `0.05 / (6/720) = 6×`. The alert fires only when the long AND short windows both exceed threshold — the short window makes the burn *current* (kills the alert after recovery) and stops flapping on a momentary spike. A single-window alert does neither.

```promql
# SLO = 99.9%  →  budget = 0.001
# recording rules precompute the good/total error ratio per window

# fast-burn PAGE: 14.4x, confirmed by a 5m window
- alert: SLOErrorBudgetFastBurn
  expr: |
    (job:slo_errors:ratio_rate1h  > (14.4 * 0.001))
    and
    (job:slo_errors:ratio_rate5m  > (14.4 * 0.001))
  labels: { severity: page }

# slow-burn TICKET: 6x, confirmed by a 30m window
- alert: SLOErrorBudgetSlowBurn
  expr: |
    (job:slo_errors:ratio_rate6h  > (6 * 0.001))
    and
    (job:slo_errors:ratio_rate30m > (6 * 0.001))
  labels: { severity: ticket }
```

## SLO-as-code (Sloth) — generate the rules, don't hand-write them

```yaml
# sloth spec, checked into the repo next to the service
version: prometheus/v1
service: checkout
slos:
  - name: checkout-availability
    objective: 99.9              # → budget 0.1%, 30d
    sli:
      events:
        error_query: sum(rate(checkout_http_requests_total{status=~"5.."}[{{.window}}]))
        total_query: sum(rate(checkout_http_requests_total[{{.window}}]))
    alerting:
      page_alert:   { labels: { severity: page } }
      ticket_alert: { labels: { severity: ticket } }
```

Sloth compiles this into the recording + multi-window burn-rate rules above. OpenSLO is the vendor-neutral alternative for the source-of-truth spec.

## Detectors

- SLO with no error budget or no burn-rate alert wired.
- Single-window burn alert (no short confirmation window) — fires stale, misses fast burns.
- Cause-based SLI (CPU / pool / queue) instead of a user-facing symptom.
- Latency SLO stated as a raw `p99 < 300ms` rather than a good-request count (doesn't compose into a budget).
