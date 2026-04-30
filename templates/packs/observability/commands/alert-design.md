---
description: Design alerts for a service. Uses RED + USE + SLO-based alerts. Avoids the two anti-patterns: alert fatigue + missed pages. Outputs alert definitions + runbook entries.
---

# /alert-design

## The Premise (read this first, internalize, do not deviate)

**Existing alerts are the truth.** If this repo already ships alerts (Prometheus rules, Datadog monitors, Grafana alerts), those thresholds, severity tiers, burn-rate windows, and runbook conventions ARE the convention. New alerts MUST match sibling alerts: same severity labels (`page` / `ticket` / `info`), same threshold magnitudes for comparable signals (error-rate, latency, saturation), same multi-window burn-rate windows (1h fast / 6h slow), same annotation keys (`summary`, `runbook`). Match thresholds and severity tiers to sibling alerts unless data justifies divergence.

**The agent's job is exactly this:**
1. Audit existing alerts first (Phase 1 already requires this — enforce it). Read sibling thresholds, severity labels, windows, annotation shapes.
2. Mirror those shapes for the new alerts. Same severity vocabulary. Same window pairs. Same annotation keys.
3. Only deviate when historical data (past incidents, error budget burn rates) justifies a different threshold — and document the rationale inline.

**The agent does NOT:**
- Pick a threshold from a blog post (`> 1% over 5min`) when sibling alerts on the same signal use a multi-window burn-rate.
- Introduce a new severity tier (`critical`, `warn`, `urgent`) when sibling alerts use `page / ticket / info`.
- Pick burn-rate windows (2h / 12h) different from sibling SLO alerts (1h / 6h) without a data-driven reason.
- Draft an ADR mid-run to legitimize a new convention. **Sibling wins. Match it.**

**Closure verb (default): match-sibling-thresholds.** Auto-apply parity edits silently; batch into the end-of-run summary. Only halt on the three escalation triggers below.

**Escalation triggers (halt and ask):**
- No sibling alerts exist (greenfield alerting — user picks the convention).
- The new signal genuinely has no comparable sibling (novel domain — user picks threshold).
- Historical data (past incidents) shows sibling threshold would have missed a real outage — surface evidence and propose divergence.

That's it. Everything else is silent sibling-parity emission.

## Mechanical halt — hand-wave grep on rationale

Before finishing Phase 4, every alert MUST have an inline rationale tied to either (a) a sibling threshold or (b) historical data. Run these checks. Any failure = HALT, surface, do not advance:

1. **Hand-wave grep** — scan generated alert annotations + rationale notes for hand-wave phrases: `"reasonable"`, `"sensible default"`, `"industry standard"`, `"common practice"`, `"typical value"`, `"seems right"`, `"should be enough"`. Any match = HALT. Replace with either a sibling-threshold citation (`matches alert <name>`) or a data citation (`based on P95 over last 30d = X ms`).
2. **Severity tier parity** — every alert uses a severity label that already exists in sibling alerts. New tier = HALT.
3. **Window parity** — multi-window burn-rate alerts use the same `(fast, slow)` window pair as sibling SLO alerts unless data-justified.
4. **Runbook link present** — every `severity: page` alert MUST have a `runbook:` annotation pointing at an existing or newly-stubbed file. Missing = HALT.

Add the check results to the output block under `Rationale-grep: ✓ | hand-wave halts=<N> | severity-parity ✓ | window-parity ✓`.

Design alerts that fire when something is actually wrong + DON'T fire when nothing is. The two failure modes are equally bad: too many alerts → fatigue → ignored pages → real outages missed; too few → outages happen with no early warning.

## Phases applied

All 7.

## Phase 1 — Understand

Confirm:
- Service / endpoint / job in scope.
- SLOs / SLAs (or "we don't have any" — define them first).
- On-call structure (who pages, what hours, escalation policy).
- Existing alerts (audit them — many will be deletable).
- Backend: PagerDuty / Opsgenie / Datadog Monitors / Prometheus Alertmanager / Grafana Alerts.

## Phase 2 — Organize

Three alert classes:

1. **Symptom-based (SLO burn)** — alerts on user-facing symptom: error budget burning fast OR slowly.
2. **Cause-based (saturation / errors)** — alerts on resource exhaustion, error spike, queue backup.
3. **Heartbeat / liveness** — service stops emitting metrics → alert.

The healthiest alert posture is **SLO-burn-rate alerts** (slow-burn 6h + fast-burn 1h windows) plus a small set of cause-based for things SLO can't catch (security events, data integrity, dependency failures).

## Phase 3 — Retrieve

- Existing SLO definitions in `ai/runtime/slos.md` if any.
- Metrics catalog in `ai/runtime/metrics-catalog.md`.
- On-call runbook structure if any.
- Past incidents — what fired, what didn't, what should have.

## Phase 4 — Generate

### SLO burn-rate alerts (Google SRE multi-window pattern)

For an SLO of "99.9% of HTTP requests succeed in 30 days":
- Error budget: 0.1% of requests.
- Burning the budget over 1 hour at 14× speed → alarms PAGE (likely outage now).
- Burning the budget over 6 hours at 6× speed → alarms TICKET (slower; investigate).

```yaml
# Prometheus Alertmanager
- alert: APIHighErrorRate_FastBurn
  expr: |
    sum(rate(http_server_error_count{service="api"}[1h]))
      /
    sum(rate(http_server_request_count{service="api"}[1h]))
    > (1 - 0.999) * 14
  for: 5m
  labels: { severity: page, slo: api_availability }
  annotations:
    summary: "API error rate burning SLO budget at >14× rate (1h window)"
    runbook: "ai/runbooks/api-error-rate.md"

- alert: APIHighErrorRate_SlowBurn
  expr: |
    sum(rate(http_server_error_count{service="api"}[6h]))
      /
    sum(rate(http_server_request_count{service="api"}[6h]))
    > (1 - 0.999) * 6
  for: 30m
  labels: { severity: ticket, slo: api_availability }
```

### Cause-based alerts (limited set)

Alert when:
- DB connection pool > 90% utilized for 5 min.
- Queue depth > N (where N is the consumer's max throughput × 5 min).
- Memory > 90% on app servers.
- Disk > 80% on data nodes.
- Cert expiring in < 14 days.
- Vendor / dependency reports outage.

Don't alert when:
- CPU is high (often misleading; doesn't correlate with user impact).
- One pod restarted (let Kubernetes handle it; alert only if ALL pods restart).
- Single 500 (statistical noise; SLO-burn handles aggregates).
- Slow query (let APM handle; alert if P95 SLO burns).

### Heartbeat / liveness

```yaml
- alert: APIServiceMissingMetrics
  expr: absent(http_server_request_count{service="api"})
  for: 5m
  labels: { severity: page }
  annotations:
    summary: "API service emitting no metrics for 5 min — likely down"
```

### Alert hygiene

For every alert:
- **Severity** — page / ticket / info. Page = wake someone. Ticket = handle business hours. Info = context only.
- **Runbook URL** — every PAGE alert has a runbook. Without a runbook, the alert is "panic"; with one, it's "execute steps."
- **Threshold rationale** — why 90% not 80%? Document.
- **Auto-resolution rule** — when does it stop firing?
- **Escalation policy** — who if primary doesn't ack in N min?

## Phase 5 — Update

- `ai/runtime/slos.md` — SLO definitions.
- `ai/runtime/alerts.md` — alert catalog with severity / runbook / rationale per alert.
- `ai/runbooks/<alert-name>.md` — per-alert runbook.
- Backend config (Prometheus rules / Datadog Monitors / Grafana Alerts) — checked in to repo.

## Phase 6 — Validate

For each alert:
- Trigger it deliberately (toy app, staging) → verify it fires + pages right person.
- Wait for it to clear → verify auto-resolves.
- Tune threshold by replaying historical data: would this have fired during last week's incident?
- Verify alert volume budget: target ≤ 5 pages / week per on-call OR ≤ 1 / 24h.

## Phase 7 — Improve

- After each incident: post-mortem reviews alerts fired (false positives? missed?).
- Quarterly: audit alert silence-rate + ack-rate. Alerts silenced > 50% are noise; delete.
- Recurring page-and-ack-no-action → alert is informational, not actionable.

## Output format

```
## /alert-design complete

Service: <name>
SLO definitions: <count>
Page alerts: <count> (target: ≤ 5/week firing)
Ticket alerts: <count>
Heartbeat alerts: <count>
Runbooks: <count>

Alert catalog: ai/runtime/alerts.md
Backend config: <path to monitors.yaml / etc.>

Alert volume estimate (based on past 30d data): <P/T/I per week>
```

## Hard rules

- **Every PAGE has a runbook.** Without it, page = panic.
- **SLO-based alerts beat threshold-based.** Threshold (e.g., "P95 > 500ms") is symptom-removed; SLO burn rate is user impact.
- **Page rate ≤ 5/week per on-call.** More = fatigue → real pages ignored.
- **Auto-resolution defined.** Alerts that "fire and stay fired" rot.
- **No PII / secrets in alert annotations.**

## Failure modes

- Alert fires on every deploy → on-call learns to ignore → real outage missed.
- Threshold set in dev / staging values → never fires in production.
- Runbook missing or outdated.
- Page wakes person; runbook says "investigate" with no first action.
- Alert depends on a metric that wasn't actually instrumented → silently never fires.
- Escalation policy points at someone who left.

## Related

- `add-tracing` + `add-metrics` — feed this command.
- `slo-audit` — uses alert + SLO data.
- `@incident-responder` agent — runs the runbook this command links to.
- `@sre-engineer` agent — broader SRE concerns; alert-design is one dimension.
- `.claude/rules/observability-principles.md`.
