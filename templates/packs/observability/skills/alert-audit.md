---
name: alert-audit
description: Audit the alerting system — find dead alerts (never fire), noisy alerts (fire too often), alerts without runbooks, alerts without owners, alerts on causes instead of symptoms.
---

# alert-audit

Alert fatigue kills teams. Half of "oncall hell" is garbage alerts drowning out real ones.

## Premise

Find real issues. Every "dead", "noisy", "missing runbook", "missing owner" finding cites a specific alert name, the rule file path, and the query / pager-history that supports the verdict. Fire counts come from the actual alert history (Prometheus API, PagerDuty incidents) — not estimates. A "broken query" finding cites the metric name that was renamed and the commit that did it. SLO burn-rate gaps cite the SLO from `slos.md` that lacks coverage.

## Halt conditions

- Refuse to call an alert "dead" without the 90d fire history backing it.
- Refuse to flag "no runbook" without grepping the rule file (cite path).
- Halt on hand-waves like "this alert seems noisy" — produce the fire count or drop the claim.
- Don't propose deletion without confirming nobody's runbook references it.

## Sources

- **Prometheus / Alertmanager** — `rules/` YAML + alert history from Prometheus API.
- **Grafana** — alerting UI + API.
- **Datadog** — monitors API.
- **PagerDuty / Opsgenie** — incident / page history.
- **Sentry** — error alerts.

## Checks

### Dead alerts
Never fired in the last 90 days.

```bash
# Prometheus — list alerts + check history
curl -s http://prometheus:9090/api/v1/alerts
# Cross-reference against pager history: did they fire recently?
```

Possible reasons:
- Threshold too high — never triggered (maybe good).
- Underlying metric deprecated / renamed — broken query (bad, silent failure).
- Condition can't happen — rule obsolete (remove).

For each dead alert:
- Verify the metric still exists + the query works.
- If query returns data but never crosses threshold: confirm the threshold is right.
- If broken: fix or delete.

### Noisy alerts
Fired > N times in the window, resolved quickly each time. Likely flapping.

```
alert_name              fires_7d   median_duration   action
cpu_high                      47             45s     flapping (threshold too tight or need "for 5m")
db_connection_timeout         23              2m     real issue worth investigating
disk_space_low                 3          2h to ack   real + action taken
```

Flapping alerts burn trust. Fix the rule (add `for: 5m`, raise threshold, group by instance).

### Alerts without runbooks

Every alert should link to a runbook. Grep:
```bash
grep -L "runbook" prometheus/rules/*.yaml
```

Alert without runbook = nobody knows what to do at 3am. Remediation: write the runbook OR delete the alert.

### Alerts without owners

Every alert has an owning team / on-call rotation. If the owner left the company 2 years ago, alert is orphaned.

### Alerting on causes, not symptoms

**Symptom alerts (good)**: `error_rate > 5%`, `p95_latency > 1s`, `orders_per_hour < 10` (business dropped).

**Cause alerts (often bad)**: `cpu > 80%`, `memory > 90%`, `disk > 70%`. These may not correlate with user pain.

Rule: alert on what users feel. Cause alerts useful as supplementary info on a dashboard, not as pages.

### SLO burn-rate alerts missing?

Check: do you have burn-rate alerts on the defined SLOs?
- Fast burn (1h window, 14.4x budget) → page.
- Slow burn (6h window, 6x budget) → page.
- Neither configured = you won't detect slow-burn issues.

## Output

```
Alert audit — Prometheus + PagerDuty

Total alerts: 42
Active (fired in 90d): 28
Dead (0 fires in 90d): 14

Dead alerts (candidates for removal):
  - cpu_high_api               query returns data, never > threshold 90% — raise threshold or delete
  - redis_evictions            metric renamed 3mo ago, query broken — FIX
  - kafka_consumer_lag_staging   staging-only, shouldn't be in prod alerts — move

Noisy (flapping):
  - db_pool_near_capacity      fired 47x/7d, median 45s — add `for: 5m`
  - certificate_expiring       fired 12x/7d, cert auto-renews — bump threshold to 7d

Missing runbooks:
  - payment_webhook_backlog    add runbook: rate limit Stripe? process queue manually?
  - ai_latency_high            add runbook: escalate to external AI? fall back?

Missing owners:
  - legacy_import_job_failed   last owner left Q2 2024 — assign or delete

Cause-based alerts (review — should these page?):
  - cpu_usage_high_8_cores     historically not correlated with user pain — demote to dashboard only
  - memory_pressure_node       K8s auto-evicts — alert is redundant

SLO coverage:
  ✓ api.availability      burn-rate 1h + 6h alerts configured
  ✗ checkout.success      NO burn-rate alert — critical gap
  ✓ search.latency.p95    burn-rate 1h alert only — add 6h

Action plan:
  1. Remove 3 obviously dead alerts.
  2. Fix 1 broken query (redis_evictions).
  3. Add `for: 5m` to 2 flapping alerts.
  4. Write 2 runbooks.
  5. Reassign 1 orphaned alert.
  6. Add burn-rate alert for checkout.success SLO.
```

## Rules

- Every alert has a runbook + owner.
- Every alert fires on symptoms (user impact), not causes.
- Dead alerts either fixed or deleted — don't just ignore.
- Review alerts quarterly at minimum.
- New alert PRs reviewed — same rigor as code.
