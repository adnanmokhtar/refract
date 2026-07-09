---
name: alert-audit
description: Audit the alerting system — find dead alerts (never fire), noisy alerts (fire too often), alerts without runbooks, alerts without owners, alerts on causes instead of symptoms.
---

# alert-audit

Alert fatigue kills teams. Half of "oncall hell" is garbage alerts drowning out real ones.

## Premise

Find real issues. Every "dead", "noisy", "missing runbook", "missing owner" finding cites a specific alert name, the rule file path, and the query / pager-history that supports the verdict. Fire counts come from the actual alert history (the project's alerting backend API + paging service incidents) — not estimates. A "broken query" finding cites the metric name that was renamed and the commit that did it. SLO burn-rate gaps cite the SLO from `slos.md` that lacks coverage.

## Halt conditions

- Refuse to call an alert "dead" without the 90d fire history backing it.
- Refuse to flag "no runbook" without grepping the rule file (cite path).
- Halt on hand-waves like "this alert seems noisy" — produce the fire count or drop the claim.
- Don't propose deletion without confirming nobody's runbook references it.

## When to run

- Quarterly alert-hygiene review.
- After an incident where the right alert didn't fire (or the wrong one paged).
- On a new alert-rule PR — same rigor as code review.
- When on-call reports alert fatigue.

## Sources

- **The project's alerting backend** — rule files (whatever format the backend uses) + alert history via its API (Prometheus / Alertmanager, Grafana alerting, Datadog Monitors, vendor monitor APIs).
- **The project's paging service** — incident / page history (PagerDuty, Opsgenie, Grafana OnCall, etc.).
- **The project's error tracker** — error alerts (Sentry, Rollbar, Bugsnag, etc.).

## Checks

### Dead alerts
Never fired in the last 90 days.

Query the project's alerting backend API for the rule list, then cross-reference against the paging service's incident history: did they fire recently?

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

Every alert should link to a runbook. Grep the project's alert rule files for a `runbook`-style annotation; flag any rule lacking one.

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

## Output (illustrative shape)

```
Alert audit — <alerting backend> + <paging service>

Total alerts: 42
Active (fired in 90d): 28
Dead (0 fires in 90d): 14

Dead alerts (candidates for removal):
  - cpu_high_api               query returns data, never > threshold 90% — raise threshold or delete
  - cache_evictions            metric renamed 3mo ago, query broken — FIX
  - consumer_lag_staging       staging-only, shouldn't be in prod alerts — move

Noisy (flapping):
  - db_pool_near_capacity      fired 47x/7d, median 45s — add a "for: 5m" debounce
  - certificate_expiring       fired 12x/7d, cert auto-renews — bump threshold to 7d

Missing runbooks:
  - payment_webhook_backlog    add runbook: rate limit upstream? process queue manually?
  - external_api_latency_high  add runbook: escalate to vendor? fall back?

Missing owners:
  - legacy_import_job_failed   last owner left Q2 2024 — assign or delete

Cause-based alerts (review — should these page?):
  - cpu_usage_high             historically not correlated with user pain — demote to dashboard only
  - memory_pressure_node       orchestrator auto-evicts — alert is redundant

SLO coverage:
  ✓ api.availability      burn-rate 1h + 6h alerts configured
  ✗ checkout.success      NO burn-rate alert — critical gap
  ✓ search.latency.p95    burn-rate 1h alert only — add 6h

Action plan:
  1. Remove obviously dead alerts.
  2. Fix broken queries.
  3. Add debounce to flapping alerts.
  4. Write missing runbooks.
  5. Reassign orphaned alerts.
  6. Add burn-rate alerts for SLOs lacking coverage.
```

## False positives / gotchas

- A "dead" alert with a deliberately high threshold (a last-line safety net that should almost never fire) is correct — confirm intent before deleting.
- A cause-based signal (`cpu > 80%`) kept as dashboard-only context rather than a page is correct — don't flag it as a bad alert.
- Staging / non-prod alerts on a separate route are fine; only flag them if they page the prod rotation.
- A flapping alert may be a real intermittent fault, not a bad rule — check median duration + downstream impact before prescribing `for: 5m`.
- Don't propose deleting an alert that another alert's runbook references.

Invariants this audit enforces: every alert has a runbook + owner; alerts fire on symptoms not causes; dead alerts get fixed or deleted, never ignored; new alert PRs get code-level review.

## Related

### Skills
- `slo-audit` — sibling audit; its SLO definitions feed this audit's burn-rate coverage check.

### Agents
- `@sre-engineer` — owns SLO / error-budget / burn-rate policy.
- `@incident-responder` — consumes alert quality during a live page.
- `@observability-reviewer` — reviews new alert rules at the code-change level.

### Patterns
- `ai/patterns/metrics.md`
- `ai/patterns/slo.md`
