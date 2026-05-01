---
name: slo
kind: example
pack: documentation
---

# Pattern: SLO (Service Level Objective)

A target reliability number, measured over a window, that defines what "good enough" means for a specific service. SLOs anchor on-call alerting, prioritization between feature work vs reliability work, and the conversation with stakeholders when something breaks. Without one, every outage feels equally bad and every reliability investment feels arbitrary.

## Context

Reach for SLOs when:
- The team owns a service in production with real users.
- Alerts are either too noisy ("everyone ignores PagerDuty") or too quiet ("we found out from a customer").
- Product wants to ship faster, ops wants more stability, and there's no shared definition of "stable enough".
- You're past the experimentation phase — for a P1 prototype, "monitor errors and fix them" is enough.

Skip SLOs when the service has no SLI you can measure honestly. A service whose telemetry is "we'll know when users complain" needs metrics first; SLOs second.

## Three components: SLI, target, window

```
SLO: <service>.<SLI>  <comparator> <target>  over <window>

api.availability      ≥  99.9%   over rolling 30d
api.latency_p95       ≤  500ms   over rolling 30d
checkout.success_rate ≥  99.5%   over rolling 30d
```

### SLI — what you measure

```
Availability:    successful_requests / total_requests
Latency:         p95(request_duration) where < threshold counts as "good"
Freshness:       p95(time_since_last_update) for derived data
Correctness:     successful_responses_with_correct_data / total_responses
Throughput:      requests served per second sustained
```

The SLI must be computable from real telemetry, NOT a survey or a feeling. If you can't write a Prometheus query (or equivalent) for it today, you can't have an SLO on it.

### Target — the promise

| Target | Allowed downtime / month | Real-world feel |
|---|---|---|
| 99% | ~7h 18m | "Sometimes broken, recoverable" — internal tools, async pipelines |
| 99.5% | ~3h 39m | "Mostly works" — early-stage products |
| 99.9% | ~43m 50s | "Reliable" — most SaaS APIs |
| 99.95% | ~21m 55s | "Tight" — payment paths, login |
| 99.99% | ~4m 22s | "Expensive" — needs multi-region, redundant deps |
| 99.999% | ~26s | "Telco-grade" — overkill for almost anything |

Pick the lowest target that's commercially acceptable. Each extra 9 roughly doubles infrastructure cost.

The bigger trap: setting the SLO at current performance. If the API runs at 99.95% today and you set the SLO to 99.95%, every minor regression breaches and the team gets numb to alerts. Set it at the level you COMMIT to defend, with margin against normal noise — usually one notch below current observed performance.

### Window — how it's averaged

```
Rolling 30-day:  industry standard. Smooths weekly seasonality.
Rolling 7-day:   fast iteration / pre-GA products. Reacts faster to regressions.
Calendar quarter: strategic rollups for leadership; never alert on this.
```

A rolling window means today's number includes data from 30 days ago. Calendar windows reset on the 1st — they create end-of-month panics and beginning-of-month "we have all the budget" recklessness.

## Error budget

```
Budget = (1 − SLO) × eligible_requests_in_window

Example: 99.9% over 100M requests/month
       = 0.001 × 100,000,000
       = 100,000 errors allowed
```

The budget is the LICENSE TO SHIP RISK. It's not a target to hit zero — unspent budget is wasted reliability investment. Spend it on:
- Risky deploys (new infrastructure, schema changes).
- Experiments that may degrade slightly (canaries, new caching tiers).
- Operational practice (chaos drills, failover tests).

```
Budget healthy (>50% remaining):       ship freely, take risks
Budget half-burned (25-50% remaining): slow deploys, focus reliability work
Budget exhausted (<10% or burned):     FREEZE feature work; on-call until restored
```

## Burn-rate alerts (the modern alerting form)

Static thresholds ("alert if error rate > 1%") miss two failure modes:
- Slow-burn outage: 0.3% errors for 10 hours quietly burns the entire monthly budget without ever tripping the threshold.
- Spike that recovers: 5% for 90 seconds, gone before the alert fires; 30 days of false triggers if it doesn't.

Burn-rate alerts compute "how fast are we burning the budget RIGHT NOW relative to what's sustainable":

```
Sustainable rate = SLO failure rate (e.g., 0.1% for 99.9% SLO)
Current rate    = errors_in_window / requests_in_window
Burn rate       = current_rate / sustainable_rate
```

Standard SRE recommendations (Google SRE Workbook, ch. 5):

| Severity | Burn rate | Window | Meaning | Response |
|---|---|---|---|---|
| Page (fast) | 14.4× | 1h | 1h burns 2% of monthly budget | Wake someone |
| Page (medium) | 6× | 6h | 6h burns 10% of budget | Wake someone if business hours, ticket otherwise |
| Ticket | 1× | 3d | Steady drift through entire budget | Investigate next business day |

Alert manager rule sketch:

```yaml
- alert: APILatencyBurnRateFast
  expr: |
    (
      sum(rate(http_request_duration_seconds_count{le="0.5",service="api",status="success"}[1h]))
      /
      sum(rate(http_request_duration_seconds_count{service="api"}[1h]))
    ) < (1 - 14.4 * (1 - 0.999))
  for: 5m
  annotations:
    summary: "API latency p95 SLO burning 14.4x — 1h burns 2% of monthly budget"
```

## Common mistakes

- **SLO without budget accounting.** "We have a 99.9% SLO" but no one tracks burn or freezes deploys. The number is decoration.
- **Setting SLO = best observed quarter.** Now every normal week breaches.
- **Different SLOs per environment.** Staging "SLO" doesn't exist — staging is for pre-production validation. SLO is production-only.
- **Aggregating SLIs that hide problems.** A 99.9% global availability where one tenant runs at 95% looks fine in the rollup. Slice SLIs by critical dimension (tenant tier, customer segment, region).
- **No owner per SLO.** "The team" owns it = nobody owns it. One named team in `ai/` docs, reviewed quarterly.
- **Alerting on the SLO directly.** "Page when SLO is breached" arrives 30 days late. Burn rate is the right alert primitive.
- **Hard targets without graceful degradation.** A 99.99% SLO on the API while the database is 99.9% is mathematically impossible — you'd need redundancy at the DB layer too. Math out the dependency tree.

## Documentation template

Every SLO lives in `ai/runbooks/slo-<name>.md`:

```markdown
# SLO: api.availability ≥ 99.9% / 30d

**Owner:** Platform team
**Reviewed:** 2026-04-01 (quarterly)
**Status:** Active

## SLI
Successful HTTP responses (status 2xx-3xx, excluding 4xx client errors) over total HTTP responses, measured at the load balancer.

## Why this target
Customers in plan tiers Pro+ have 99.9% in their MSA. Free tier consumers tolerate slightly lower. We commit to 99.9% to leave 5min/month operational margin for paid customers.

## Excluded
- Scheduled maintenance announced 24h+ in advance.
- 4xx responses (caller error).
- Endpoints under /api/internal (not customer-facing).

## Burn-rate alerts
- Fast (1h, 14.4×) → PagerDuty platform-oncall
- Medium (6h, 6×) → PagerDuty platform-oncall (business hours), ticket otherwise
- Ticket (3d, 1×) → Linear ticket P2

## Runbook on breach
Link → ai/runbooks/api-availability-breach.md
```

## Migration path

If you have no SLOs today:
1. Pick the single most user-impacting service. Don't try to SLO-ify everything at once.
2. Pick ONE SLI (usually availability). Don't add latency on day one.
3. Measure existing performance for two weeks. Don't set the target until you see real numbers.
4. Set the target one notch below observed minimum (e.g., observed 99.95% → target 99.9%).
5. Wire one burn-rate alert. Live with it for a month.
6. Add latency SLI and/or expand to second service after the team is comfortable.

## References

- Google SRE Book + SRE Workbook — the canonical text. Chapters on SLOs and on burn-rate alerting are essential reading.
- "Implementing Service Level Objectives" by Alex Hidalgo — full-length book; the SLO playbook for non-Google contexts.
- sre.google/workbook/alerting-on-slos — burn-rate math and recommended thresholds.
