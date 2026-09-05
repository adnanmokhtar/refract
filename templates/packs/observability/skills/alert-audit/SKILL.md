---
name: alert-audit
description: Audit the alerting system — dead alerts that never fire, noisy alerts that fire too often, alerts with no runbook or owner, and alerts on causes instead of symptoms. Run as a quarterly hygiene review, after an incident where the right alert didn't fire, on any new alert-rule PR, and when on-call reports fatigue. Owns alert quality — `slo-audit` owns whether the SLO targets themselves are right.
allowed-tools: [Read, Grep, Glob, Bash]
---

# alert-audit

Alert fatigue kills teams. Half of "oncall hell" is garbage alerts drowning out real ones.

## Premise

Find real issues. Every "dead", "noisy", "missing runbook", "missing owner" finding cites a specific alert name, the rule file path, and the query / pager-history that supports the verdict. Fire counts come from the actual alert history (the project's alerting backend API + paging service incidents) — not estimates. A "broken query" finding cites the metric name that was renamed and the commit that did it. SLO burn-rate gaps cite the SLO from `slos.md` that lacks coverage.

**Two of this audit's checks read files; two read a live backend, and those two are usually
unreachable from a repo.** Runbook-presence and cause-vs-symptom are decidable by grepping the rule
files — no excuse there. Dead-alert and noisy-alert verdicts require 90d of fire history from the
alerting backend and the paging service, and an agent running where the code is generally cannot
query either. That case has a first-class verdict (`NO-DATA`); guessing a fire count is the
fabrication this skill exists to prevent.

## Halt conditions

- **A verdict with an empty evidence cell is fabricated.** Every finding records the query / grep run and what it returned. No evidence → `NO-DATA`, never a blank and never an estimate.
- Refuse to call an alert "dead" without the 90d fire history backing it — record `NO-DATA(alert history unreachable)` and move on. Do not downgrade it to "probably fine".
- Refuse to flag "no runbook" without grepping the rule file (cite path). This one is always decidable from the repo, so `NO-DATA` is never the honest answer for it.
- Halt on hand-waves like "this alert seems noisy" — produce the fire count or drop the claim.
- Don't propose deletion without confirming nobody's runbook references it.
- An adjective where a count belongs ("fires a lot") is not a finding. Produce the number or produce `NO-DATA`.

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

Check each SLO in `slos.md` for the **three** canonical tiers (`ai/patterns/slo.md` owns the derivation):
- Fast burn — 1h window, 14.4× budget, confirmed at 5m → **page**.
- Medium burn — 6h window, 6× budget, confirmed at 30m → **page**. (Not a ticket. An alert set that labels this `ticket` is a finding.)
- Slow burn — 3d window, 1× budget, confirmed at 6h → **ticket**.

The slow-burn tier is the one usually absent, and its absence is the highest-value finding in this
section: a leak burning at exactly 1× trips neither page tier by construction, so a service with
only the two page tiers has **no detector at all** for "we will miss the SLO at month-end". Flag a
two-tier set as a gap, not as coverage.

## Output (illustrative ledger)

One row per finding, and the `Evidence` column carries the query or grep that produced it plus what
came back. The shape below is illustrative; its numbers are placeholders. Reproducing them without
having queried anything is the fabrication the `NO-DATA` verdict exists to make unnecessary.

```
Alert audit — <alerting backend> + <paging service>

Rules read: 42 (from <rule file paths>)
Fire history: <reachable | UNREACHABLE — reason>

| Alert | Finding | Evidence (query/grep run → observed) | Verdict |
|---|---|---|---|
| cache_evictions | broken query — metric renamed | rules/cache.yaml:31 refs `cache_evictions_total`; series absent since <commit> | DEAD |
| cpu_high_api | never crosses threshold | backend rule-history API → 0 fires/90d; query returns data | DEAD |
| db_pool_near_capacity | flapping | paging API → 47 fires/7d, median 45s | NOISY |
| payment_webhook_backlog | no runbook annotation | `rg -L runbook rules/payment.yaml` → no match | ORPHAN |
| legacy_import_job_failed | no owner label | rules/import.yaml:8, no `team`/`owner` label | ORPHAN |
| cpu_usage_high | cause, routed as page | rules/node.yaml:12 `severity: page` on a CPU threshold | CAUSE-AS-PAGE |
| certificate_expiring | fire count not retrievable | paging API unreachable from this environment (no credentials) | NO-DATA(paging history) |

SLO coverage (from slos.md + the rule files — decidable without fire history):
  ✓ api.availability      1h/14.4× page + 6h/6× page + 3d/1× ticket — all three tiers
  ✗ checkout.success      NO burn-rate alert at all — critical gap
  ✗ search.latency.p95    1h page + 6h page only — no 3d/1× ticket; a target-rate leak is undetectable
  ✗ orders.success        6h/6× labelled `ticket` — that tier pages; a 6h outage waits for Monday

Audit status: INCOMPLETE — unmeasured: certificate_expiring (paging history unreachable;
re-run where the paging API is reachable, or paste a 90d incident export).

Action plan:
  1. Fix broken queries (a DEAD alert with a broken query is a silent failure, not a spare rule).
  2. Remove alerts confirmed dead with intent checked.
  3. Add debounce to flapping alerts.
  4. Write missing runbooks.
  5. Reassign orphaned alerts.
  6. Add the missing burn-rate tiers, slow-burn ticket first.
```

Per-row `Verdict` vocabulary — pick exactly one, no synonyms:
- **DEAD / NOISY / ORPHAN / CAUSE-AS-PAGE** — the check ran and the evidence supports it.
- **NO-DATA(reason)** — the source needed for this check was unreachable from this environment. Name what was unreachable. A NO-DATA row is UNVERIFIED, not a pass: it never rounds to "healthy", and it downgrades the run to `INCOMPLETE`.

### Closure gate — COMPLETE only when every check had its source

- **`COMPLETE`** — every alert was checked against a reachable source and every finding carries evidence.
- **`INCOMPLETE — unmeasured: <list>`** — the moment any row is `NO-DATA`. Name each alert, what was unreachable, and the one command that would close it.

**[self-policed]** on the status line, wired to checkable evidence: the rule-file paths and grep
results are inspectable, and `@observability-reviewer` will BLOCK a COMPLETE whose findings carry
empty evidence cells.

## False positives / gotchas

- A "dead" alert with a deliberately high threshold (a last-line safety net that should almost never fire) is correct — confirm intent before deleting.
- A cause-based signal (`cpu > 80%`) kept as dashboard-only context rather than a page is correct — don't flag it as a bad alert.
- Staging / non-prod alerts on a separate route are fine; only flag them if they page the prod rotation.
- A flapping alert may be a real intermittent fault, not a bad rule — check median duration + downstream impact before prescribing `for: 5m`.
- Don't propose deleting an alert that another alert's runbook references.
- **Estimating a fire count because the paging API was unreachable.** "Probably noisy" is not a finding; `NO-DATA(paging history)` is. The two checks that *are* decidable from the repo — runbook presence and cause-vs-symptom — still run, so a NO-DATA run is a partial audit, not a wasted one.

Invariants this audit enforces: every alert has a runbook + owner; alerts fire on symptoms not causes; dead alerts get fixed or deleted, never ignored; new alert PRs get code-level review.

## Related

### Skills
- `slo-audit` — sibling audit; its SLO definitions feed this audit's burn-rate coverage check.
- `synthetic-monitoring` — sibling audit; the blackbox/synthetic page routes it produces must meet this audit's runbook/owner/symptom bar.

### Agents
- `@sre-engineer` — owns SLO / error-budget / burn-rate policy.
- `@incident-responder` — consumes alert quality during a live page.
- `@observability-reviewer` — reviews new alert rules at the code-change level.

### Patterns
- `ai/patterns/metrics.md`
- `ai/patterns/slo.md`
- `ai/patterns/dashboards.md` — the alert→panel link this audit checks is defined there; a well-formed alert drills into a versioned panel.
