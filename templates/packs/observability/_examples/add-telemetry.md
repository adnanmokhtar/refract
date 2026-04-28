---
description: Wire structured logs, metrics, and traces into a feature; create alert + runbook stubs.
---

# /add-telemetry <feature>

Build command. Adds the four observability primitives — logs, metrics, traces, alerts — using the project's existing libraries. Generates runbook stubs. All 7 phases apply.

## When to use / NOT to use
- USE: new feature shipping to staging+ — instrument before exposure.
- USE: existing feature with mystery failures (gaps in current telemetry).
- USE: as a follow-up from `/fix-bug` Phase 9 ("why didn't we know sooner?").
- NOT: feature flags off in prod or local-only tooling — instrumenting unreachable code = noise.
- NOT: as the fix for a real bug — observability surfaces problems, doesn't solve them.

## Phase 1 — Understand
- Feature name + entry points (controllers / handlers / job consumers).
- Confirm feature is reachable in staging+ — flagged-off code skips this command.
- Identify SLO targets if defined.

## Phase 2 — Organize
- Detect libraries from `package.json` / `pyproject.toml`:
  - Logs: `pino`, `winston`, `structlog`, `zerolog`, `slog`.
  - Metrics: `prom-client`, `@opentelemetry/sdk-metrics`, `statsd`, `datadog-metrics`.
  - Traces: `@opentelemetry/sdk-trace`, `dd-trace`, `elastic-apm-node`.
- Decide alert format (Prometheus rules / Datadog monitor JSON / Grafana alerting).
- Dispatch plan: `telemetry-architect` produces edits; orchestrator generates runbook stubs.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Telemetry-specific:
- Existing dashboards / alert configs — match conventions, don't invent a new format.
- `ai/observability.md` if present — SLO definitions, naming conventions for metrics.
- The feature's entry points (read source).
- An existing telemetry-instrumented module — mirror exact patterns (field names, span attributes).

## Phase 4 — Generate
- Code edits via `telemetry-architect`:
  - Structured log on entry / success / failure of each public method (fields: `request_id`, `tenant_id`, `user_id`, `duration_ms`, plus feature-specific).
  - Counters: `<feature>_requests_total{status,reason}`.
  - Histograms: `<feature>_duration_seconds` with buckets `0.005, 0.01, 0.05, 0.1, 0.5, 1, 5`.
  - Trace span around use-case entry; sub-spans on external IO (DB, HTTP, queue).
- Alert config in project's format:
  - Error-rate > 1% over 5min.
  - p95 latency > SLO over 10min.
  - Saturation alerts (queue depth, pool wait) where applicable.
- Runbook stub `ai/runbooks/alert-<name>.md`: symptom, immediate mitigation, investigation queries (log filter + trace selector), known false-positives.

## Phase 5 — Update
- `ai/observability.md` (or `ai/dashboards.md`) — note new dashboard panels.
- `ai/runbooks/` — new stubs created.
- `ai/dynamic/changelog.md` — one-line: `Telemetry added for <feature>: N alerts, M metrics`.
- `ai/status.md` — `## Recent Changes` bullet.

## Phase 6 — Validate
- Every metric has a dashboard or alert paired (no unread metrics).
- Every alert has a runbook (no 3am page without script).
- No high-cardinality labels (user_id, request_id, full URL) in metric labels — those go in logs/traces only.
- Multi-tenant projects: `tenant_id` field present on every log entry.
- PII redacted at the logger level (passwords, tokens, full PANs, full PII), not at call sites.

## Phase 7 — Improve
- `/learn-from-task` — capture instrumentation patterns introduced.
- If same instrumentation boilerplate emerges 3+ times → queue helper extraction (e.g. `@Instrumented` decorator).
- If alert thresholds vary widely → queue ADR: standard SLO baseline.

## Output format
```
## /add-telemetry — <feature>

Phase 1 (Understand): entry points = <N>; SLO = <p95 ms>
Phase 3 (Retrieved): libs = <log|metric|trace>; sibling instrumented module mirrored
Phase 4 (Generated):
  src/orders/orders.service.ts     +18 (logs, metrics, span)
  config/prometheus/orders.rules.yml  new (3 alerts)
  ai/runbooks/alert-orders-error-rate.md   stub
  ai/runbooks/alert-orders-latency.md      stub
Phase 5 (Updated): ai/observability.md, runbooks/, changelog, status.md
Phase 6 (Validated): every metric paired; tenant_id present; PII redacted
Phase 7 (Improved): pattern queued

Reminder: PII in logs — masked email + last-4 of card only. Verify before merging.
Status: COMPLETE
```

## Failure modes
- Metric without dashboard or alert → unread data; pair every metric or remove.
- Alert without runbook → 3am page with no script; never ship one without the other.
- High-cardinality labels in metric → cardinality explosion in Prometheus; move to logs/traces.
- Forgot `tenant_id` on multi-tenant project → cross-tenant noise during incident triage.
- 100% trace ingestion → expensive; head-based sampling on quiet endpoints, tail-based on errors.
- PII redaction at call site instead of logger level → one missed call site leaks data; centralize.
