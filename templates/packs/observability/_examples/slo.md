---
name: slo
kind: example
pack: observability
---

# Pattern: SLOs + Error Budgets + Burn-Rate Alerting

> **Hard rule:** Every user-facing service has ≥1 SLO with an explicit SLI (symptom-based, not cause-based), a derived error budget (`budget = 1 − SLO`), and a **multi-window multi-burn-rate** alert set — two burn *pages* (fast and medium) AND a slow-burn *ticket*, each gated by a short confirmation window. A threshold on a single window is not an SLO alert, and a two-tier set with no slow-burn ticket cannot see a leak burning at target rate. Raw CPU / queue-depth thresholds are not SLIs.

**Halt conditions / mandatory cites**
- Each SLO MUST cite the SLI's emit site at `<path:line>` (the good-events + valid-events queries) AND the burn-rate alert rule that consumes it.
- Each error budget MUST cite the SLO target it derives from and the window it's measured over (28d / 30d / calendar-month — pick one, state it).
- A burn-rate alert with only ONE window (no short confirmation window) is a bug — reject; it fires stale after recovery and misses fast burns.
- An SLI measured on a cause (CPU%, pool saturation, queue depth) rather than a symptom (user-facing latency / errors / freshness) is a bug — reject; move the cause to a saturation *warning*, keep the SLO on the symptom.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this meets its SLO".
- If the SLO backend (the project's TSDB recording rules / SLO service / OpenSLO spec — whatever is in use) isn't extracted, halt.

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

## Multi-window multi-burn-rate table — three tiers (SRE Workbook Table 5-8)

| Severity | Sustained spend | Long | Short (confirm) | Burn rate |
|---|---|---|---|---|
| **Page** (fast) | 2% | 1h | 5m | 14.4× |
| **Page** (medium) | 5% | 6h | 30m | 6× |
| **Ticket** (slow) | 10% | 3d | 6h | 1× |

`6h / 6×` is a **page**, not a ticket — a six-hour burn at that rate is an ongoing outage. The tier that tickets is `3d / 1×`, and it is the one usually missing: a leak burning at exactly 1× never trips either page tier by construction, so without this row nothing ever fires for "we will miss the SLO at month-end".

Burn rates: `0.02 / (1/720) = 14.4×`; `0.05 / (6/720) = 6×`; `0.10 / (72/720) = 1×`. Confirmation window = **1/12 of the long window** (that is where 5m/1h, 30m/6h, 6h/3d come from — use it to derive any pair this table lacks). The alert fires only when long AND short both exceed threshold: the short window makes the burn *current* (kills the alert after recovery), the long window stops flapping on a spike. A single-window alert does neither.

```promql
# SLO = 99.9%  →  budget = 0.001
# recording rules precompute the good/total error ratio per window

# fast burn PAGE: 14.4x, confirmed by a 5m window
- alert: SLOErrorBudgetFastBurn
  expr: |
    (job:slo_errors:ratio_rate1h  > (14.4 * 0.001))
    and
    (job:slo_errors:ratio_rate5m  > (14.4 * 0.001))
  labels: { severity: page }

# medium burn PAGE: 6x, confirmed by a 30m window
- alert: SLOErrorBudgetMediumBurn
  expr: |
    (job:slo_errors:ratio_rate6h  > (6 * 0.001))
    and
    (job:slo_errors:ratio_rate30m > (6 * 0.001))
  labels: { severity: page }

# slow burn TICKET: 1x over 3d, confirmed by a 6h window — the only detector
# for a persistent low-grade leak; omit it and month-end arrives unannounced
- alert: SLOErrorBudgetSlowBurn
  expr: |
    (job:slo_errors:ratio_rate3d > (1 * 0.001))
    and
    (job:slo_errors:ratio_rate6h > (1 * 0.001))
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
- Only two tiers wired (no `3d / 1×` ticket) — a leak at exactly target rate never alerts.
- `6h / 6×` labelled `ticket` — that tier pages; a six-hour outage should not wait for business hours.

## References

- Google SRE Workbook, "Alerting on SLOs" — Table 5-8 (the three tiers above) and the 1/12 short-window guideline: `https://sre.google/workbook/alerting-on-slos/`
- Google SRE Book, "Service Level Objectives": `https://sre.google/sre-book/service-level-objectives/`
- OpenSLO specification: `https://github.com/OpenSLO/OpenSLO`
- Sloth (Prometheus SLO generator): `https://sloth.dev/`
- Cause-based SLI (CPU / pool / queue) instead of a user-facing symptom.
- Latency SLO stated as a raw `p99 < 300ms` rather than a good-request count (doesn't compose into a budget).
