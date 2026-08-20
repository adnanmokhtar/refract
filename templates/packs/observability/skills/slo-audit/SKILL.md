---
name: slo-audit
description: Audit SLOs against reality — whether they are being met, whether budgets are burning, and whether targets are too lax or too ambitious; reports per-SLO with a verdict and recommended action. Run quarterly, after a significant incident, before raising or lowering a target, and when defining a service's first SLOs. Judges the targets — `alert-audit` judges the alerts built on them.
---

# Skill: slo-audit

## Premise

Find real issues. Every verdict (GREEN / YELLOW / RED / TOO LAX / TOO TIGHT / STALE) cites the achieved %, the budget remaining, and the window it was measured over. Numbers come from the observability backend's SLO endpoint or dashboard — not estimates. Each SLO is named from `ai/runtime/slos.md`; incidents are named with their ID; vendor or service called out by name. "Recommend raise to 99.5%" requires both 90d data backing it AND a named stakeholder for the buy-in.

## Halt conditions

- Refuse to verdict an SLO without 90d of measurements captured.
- Refuse to call an SLO "TOO LAX" without showing achieved >> target consistently.
- Halt on hand-waves like "feels under-promised" — cite the trend or drop the recommendation.
- Don't propose tightening without naming the stakeholder who must sign off.

## When to run

A periodic audit of SLOs (Service Level Objectives):
- Quarterly review of all SLOs.
- After a significant incident (did the SLO catch it? was it too lax?).
- Before raising / lowering an SLO target.
- When defining first SLOs for a service.

## Procedure

### 1. Inventory SLOs

Read `ai/runtime/slos.md`. Per SLO, capture:
- **Statement** — "99.9% of API requests return non-5xx within 30 days."
- **SLI** — Service Level Indicator (the thing measured).
- **Target** — the percentage / threshold.
- **Window** — rolling 30 days standard.
- **Owner** — team / person.
- **Origin** — vendor SLA? Customer-promised? Engineering aspiration?

### 2. Pull last 90 days of measurement

Tools (use whichever the project's observability stack provides):
- Self-hosted: Prometheus / a TSDB + a dashboard tool → SLO dashboard; Sloth or similar SLO generator.
- Vendor-managed SLO products (Datadog SLO, New Relic SLO, Grafana Cloud SLO, Cloud-vendor service monitoring, Honeycomb SLO, etc.).

For each SLO, compute:
- Achieved % over last 30 days.
- Achieved % over last 90 days (trend).
- Error budget remaining.
- Burn rate trend (linear / accelerating / plateau).

### 3. Verdict per SLO

| Verdict | Criteria | Recommendation |
|---|---|---|
| **GREEN** | Achieved > target consistently for 90d, error budget > 50% remaining | Hold OR consider tightening (raise target if business benefits) |
| **YELLOW** | Achieved ≈ target; burn rate occasionally spikes | Monitor; investigate burn-rate spikes for systemic issue |
| **RED** | Achieved < target OR error budget exhausted | Stop feature work; fix root causes |
| **TOO LAX** | Achieved >> target consistently for 90d, no incidents | Raise target |
| **TOO TIGHT** | Achieved << target despite engineering effort, target was aspirational | Lower target with stakeholder agreement OR invest in reliability |
| **STALE** | Hasn't been measured in > 7 days | Fix instrumentation OR remove SLO |

### 4. Cross-correlate with incidents

For each incident in last 90 days:
- Did an SLO catch it? Lead time?
- Did it consume error budget? How much?
- Was the SLO definition right (right SLI? right window?)?
- If multiple SLOs exist on the same service, did they all signal? Or was one redundant?

### 5. Output report

```
## SLO audit — <service> — <date>

### SLO inventory (5 active)

| SLO | Target | Window | Achieved 30d | Budget remaining | Verdict |
|---|---|---|---|---|---|
| API availability | 99.9% | 30d | 99.93% | 70% | GREEN |
| API latency P95 | < 500ms | 30d | 480ms | 60% | GREEN |
| Order placement success | 99.5% | 30d | 99.2% | EXHAUSTED | **RED** |
| Email delivery | 99% | 30d | 99.95% | 95% | TOO LAX |
| Background-job completion | 99% | 7d | 99.1% | 80% | GREEN |

### Trend analysis

**Order placement success — RED:**
- 99.5% target; 99.2% achieved.
- Error budget exhausted on day 14 of 30.
- Cause: vendor `payments-vendor-X` outages on 3 days.
- Action: investigate retry / fallback strategy; consider dual-vendor; raise vendor concern.
- Pause feature work on order-placement until budget recovers (current SRE policy).

**Email delivery — TOO LAX:**
- 99% target; 99.95% achieved consistently for 6 months.
- Suggest raising target to 99.5% to reflect actual reliability.
- Stakeholder sign-off needed (potential customer commitment).

**Background-job completion — GREEN with note:**
- 99% target on 7-day window achieved.
- BUT: window may be too short; 7-day window can miss slow degradation.
- Recommend: add a 30-day SLO alongside the 7-day for trend visibility.

### Incidents catch-rate

Last 90 days: 4 incidents.
- INC-1014: API latency spike — caught by latency SLO at T+12 min.
- INC-1015: Order placement failure — caught by success SLO at T+8 min. Error budget exhausted same day.
- INC-1016: Email backlog — NOT caught by SLO; reached customer support ticket. SLO too lax (4h latency tolerated; should be 30min).
- INC-1017: Database failover — caught by API availability at T+3 min.

Catch rate: 3/4 = 75%. Improve email-delivery SLO to capture missed class.

### Recommended changes

| # | Change | Reason | Effort |
|---|---|---|---|
| 1 | Order placement: pause feature work; investigate vendor strategy | Budget exhausted | sprint |
| 2 | Email delivery: raise target 99% → 99.5% | TOO LAX consistent | 1 day (stakeholder) |
| 3 | Add 30-day window on background-job SLO | Catch slow degradation | 1 hour |
| 4 | Add email-delivery latency SLO (P95 < 30 min) | Existing SLO missed INC-1016 | 1 day |
| 5 | Decommission unused SLO `legacy-api-availability` | Service deprecated | 30 min |
```

## Inputs

- `ai/runtime/slos.md` (read).
- 90 days of metrics from observability backend.
- Incident log if available.

## Outputs

- `ai/audits/slo-audit-<date>.md`.

## False positives / gotchas

- Audited only the last 7 days → missed slow-burn issues.
- Treated GREEN SLOs as "no work needed" → missed that they're TOO LAX (silent under-promise).
- Compared SLOs without their windows aligned → comparing apples to oranges.
- Recommended raising target without stakeholder buy-in.
- Dismissed a missed incident as "out of scope" when really it indicated SLO gap.

## Related

### Skills
- `alert-audit` — sibling audit; this audit's SLO definitions feed its burn-rate coverage check.

### Commands
- `alert-design` — uses SLO definitions.
- `add-metrics` — provides SLI data.

### Agents
- `@sre-engineer` — broader SRE work.
- `@incident-responder` — uses SLO context during incidents.

### Patterns
- `ai/patterns/slo.md`
- `ai/patterns/metrics.md`
