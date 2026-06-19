---
description: Wire structured logs, metrics, and traces into a feature; create alert + runbook stubs.
---

# /add-telemetry <feature>

## The Premise (read this first, internalize, do not deviate)

**Existing log fields, metric names, and span attributes are the truth.** If any sibling feature in this repo is already instrumented, that convention IS the convention for this feature. New telemetry MUST mirror sibling instrumentation: same log field names (`request_id` vs `requestId` vs `req_id` — pick the one already in use), same span attribute names (`order.tenant_id` vs `tenant.id`), same metric naming convention, same severity tiers. Don't invent new conventions.

**The agent's job is exactly this:**
1. Find one existing instrumented sibling module (Phase 3 already requires this — enforce it).
2. Mirror its log field names, metric prefix, span attribute keys, alert severity labels exactly.
3. Only deviate when an accepted ADR documents the divergence — otherwise, sibling parity wins.

**The agent does NOT:**
- Add a log field (`tenantId`) when sibling logs use `tenant_id`.
- Use a span attribute (`http.url`) when sibling spans use `request.url`.
- Pick a metric prefix (`feature_xxx_total`) when sibling metrics use `feature.xxx.count`.
- Draft an ADR mid-run to legitimize a new convention. **Sibling wins. Mirror it.**

**Closure verb (default): mirror-sibling.** Auto-apply parity edits silently; batch into the end-of-run summary. Only halt on the three escalation triggers below.

**Escalation triggers (halt and ask):**
- No sibling instrumented module exists anywhere in the repo (greenfield — user picks the convention).
- Sibling conventions are internally inconsistent across modules (two patterns coexist — user picks).
- The new instrumentation genuinely cannot fit sibling shape (different telemetry layer, different SDK) — surface and ask.

That's it. Everything else is silent sibling-parity emission.

## Mechanical halt — instrumentation-naming parity

See [`templates/snippets/instrumentation-parity.md`](../../../snippets/instrumentation-parity.md). Weight all four dimensions (span, metric, log, alert) per the premise above.

Add the check results to the output block under `Naming-parity: ✓ | halts=<N>`.

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
- Detect libraries from the project's manifest (the language's package / dependency manifest):
  - Logs: the project's structured logger (per the project's stack).
  - Metrics: the project's metrics client (OTel SDK / a Prometheus client / StatsD / a vendor agent).
  - Traces: the project's tracer (OTel SDK preferred; vendor APM SDKs where committed).
- Decide alert format (rule files for the project's metrics backend / vendor monitor JSON / dashboard-tool alerting).
- Dispatch plan: `telemetry-architect` produces edits; orchestrator generates runbook stubs.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

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

Agent-verified (static — this command generates alerts, so it audits them):
- Every metric has a dashboard or alert paired (no unread metrics).
- Every alert has a runbook (no 3am page without script).
- No high-cardinality labels (user_id, request_id, full URL) in metric labels — those go in logs/traces only.
- Multi-tenant projects: `tenant_id` field present on every log entry.
- PII redacted at the logger level (passwords, tokens, full PANs, full PII), not at call sites.
- **Dispatch the `alert-audit` skill** on the alerts this command just generated — confirm none are dead-on-arrival (query references a metric that was actually instrumented here), every alert has a runbook + owner, and each fires on a symptom not a cause. A broken-query / orphaned finding halts before completion.

OPERATOR CHECKLIST (live — confirm against the backends, NOT auto-passed):
- [ ] Fire a synthetic request through the feature → the new logs / metrics / trace appear in their backends.
- [ ] Deliberately trip one generated alert → it fires AND pages/tickets the right rotation.

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
  <feature service file>     +18 (logs, metrics, span)
  <alert rules file in the project's alerting format>  new (3 alerts)
  ai/runbooks/alert-<feature>-error-rate.md   stub
  ai/runbooks/alert-<feature>-latency.md      stub
Phase 5 (Updated): ai/observability.md, runbooks/, changelog, status.md
Phase 6 (Validated): every metric paired; tenant_id present; PII redacted
Phase 7 (Improved): pattern queued

Reminder: PII in logs — masked email + last-4 of card only. Verify before merging.
Status: COMPLETE
```

## Failure modes
- Metric without dashboard or alert → unread data; pair every metric or remove.
- Alert without runbook → 3am page with no script; never ship one without the other.
- High-cardinality labels in metric → cardinality explosion in time-series storage; move to logs/traces.
- Forgot `tenant_id` on multi-tenant project → cross-tenant noise during incident triage.
- 100% trace ingestion → expensive; head-based sampling on quiet endpoints, tail-based on errors.
- PII redaction at call site instead of logger level → one missed call site leaks data; centralize.

## Related

### Skills
- `alert-audit` — dispatched in Phase 6 to vet the alerts this command generates (dead/noisy/runbook-less/orphaned/cause-based).

### Patterns
- `ai/patterns/metrics.md`
- `ai/patterns/structured-logging.md`
- `ai/patterns/tracing.md`

### Rules
- `.claude/rules/observability-principles.md`
