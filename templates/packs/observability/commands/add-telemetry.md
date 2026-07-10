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
- Alert config in project's format — **SLO-linked, not static thresholds.** Each generated alert MUST name the SLO/SLI it protects and fire on burn rate, mirroring `alert-design`'s Google multi-window pattern:
  - Fast burn (1h window, 14× budget, `severity: page`) on the feature's availability SLI (`<feature>_requests_total{status="error"} / total`).
  - Slow burn (6h window, 6× budget, `severity: ticket`) on the same SLI.
  - Latency SLO burn where a latency SLO exists — burn against the `<feature>_duration_seconds` histogram's p95 objective, NOT a bare `p95 > Nms` threshold.
  - Saturation alerts (queue depth, pool wait) where applicable — cause-based, `severity: ticket`, dashboard-first.
  - **A static `error-rate > X% over Nmin` threshold is a FAILED alert here** (alert fatigue + SLO-disconnected). If no SLO exists for the feature, halt and route to `/alert-design` Phase 1 (define the SLO first) rather than emitting a blog-post threshold.
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

Emit-and-assert (executable gate per primitive — every one of the four primitives has a real verification step, not just alerts):
- **Metrics** (mirror `add-metrics` Phase 6): scrape the local `/metrics` endpoint (or run the exporter in a test) and assert the new series names + label keys emitted here actually appear. A new counter/histogram that does not show up on scrape is not instrumented — halt. Record the scrape command in `ai/runbooks/metrics.md`.
- **Traces** (mirror `add-tracing` Phase 6): emit a log inside an active span in a unit/integration test, parse the line, and assert `trace_id`/`span_id` fields are present; and run a span-export test asserting the new span is exported with its expected attributes. No `trace_id` in the log line / no exported span = correlation not wired — halt.
- **Logs**: assert the structured entry emits on entry/success/failure with the required fields (`request_id`, `tenant_id` on multi-tenant, `duration_ms`) via the same log-parse test — a missing field halts.

- **Alerts** (SLO-linkage assertion, mirror `alert-design` Phase 6): for every generated alert, assert (a) it references a metric series THIS run instrumented and asserted above (no dead-on-arrival query — the `alert-audit` dispatch is the executor), (b) it burns against a named SLO/SLI, not a static threshold, and (c) its `runbook:` annotation points at a file that EXISTS on disk (`test -f ai/runbooks/<name>.md`, not merely a string). Any alert failing (a)/(b)/(c) is a FAILED row — halt.

These three plus the `alert-audit` dispatch give all four primitives (logs, metrics, traces, alerts) an agent-executable gate; the OPERATOR CHECKLIST below is only for what genuinely cannot be statically/synthetically verified (real backend arrival, real paging).

### Emit-and-assert ledger — REQUIRED OUTPUT ARTIFACT (the run is not done until this table exists)

The Phase 6 gates above only bind closure if their evidence is RECORDED. Produce one ledger row per signal the run claims to have added. Each row carries the exact assertion evidence (the command run + its observed result), never a claim. A row with no evidence is UNVERIFIED, and UNVERIFIED is not a pass.

```
Signal (name)                     | Kind    | Assertion evidence (command → observed)                      | Status
<feature>_requests_total          | metric  | scrape /metrics → series+labels present                      | ASSERTED
<feature>_duration_seconds        | metric  | scrape /metrics → histogram+buckets present                  | ASSERTED
log: entry/success/failure fields | log     | log-parse test → request_id,tenant_id,duration_ms present    | ASSERTED
span: <feature> root + IO subspan  | trace   | span-export test → span exported w/ trace_id in log line     | ASSERTED
alert: <feature>-fast-burn (page) | alert   | alert-audit → not-dead + SLO-linked + runbook file exists    | ASSERTED
alert: <feature>-slow-burn        | alert   | alert-audit → not-dead + SLO-linked + runbook file exists    | ASSERTED
```

Per-row `Status` vocabulary — pick exactly one, no synonyms:
- **ASSERTED** — the evidence command ran and the observation confirms the signal. Only ASSERTED counts as production-grade.
- **SKIPPED(reason)** — the harness to assert it is genuinely absent (no `/metrics` endpoint in this stack, no test runner wired). Name the reason. A SKIPPED row is UNVERIFIED, not a pass — it downgrades the run to INCOMPLETE.
- **FAILED** — the assertion ran and the signal was absent / the alert was dead-on-arrival / not SLO-linked / runbook-less. Halt; do not emit COMPLETE.

Never write ASSERTED without a runnable command + its observed result in the evidence column. A fabricated ASSERTED is the enforcement-theater failure this pack exists to kill.

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
  Emit-and-assert ledger: <rows> signals — ASSERTED <a> | SKIPPED <s> | FAILED <f>
  <the ledger table above, verbatim, with evidence per row>
Phase 7 (Improved): pattern queued

Reminder: PII in logs — masked email + last-4 of card only. Verify before merging.
Status: <see gate below>
```

### Closure gate — COMPLETE only when production-grade, else INCOMPLETE with the unmet signals named

The production bar for this command: every signal is EMITTED and ASSERTED present, every alert is SLO-linked + has a runbook file, none dead-on-arrival. Compute Status from the ledger — do NOT hand-write COMPLETE:

- **`Status: COMPLETE`** — ONLY when every ledger row is `ASSERTED`, the `alert-audit` dispatch returned zero dead/orphaned/runbook-less/cause-based findings, and every `page` alert names its SLO + burn window. Nothing else earns COMPLETE.
- **`Status: INCOMPLETE — unmet: <list>`** — the moment any row is `SKIPPED` or `FAILED`, or `alert-audit` has an open finding. NAME each unmet signal and why (e.g., `checkout_duration_seconds — SKIPPED: no /metrics endpoint in this stack, scrape unverified`; `checkout-fast-burn — FAILED: no SLO defined, threshold would be blog-post`). "Functional but unverified" is INCOMPLETE, never COMPLETE.

This gate is **[self-policed]** — no shell forces the Status line — but it is wired to a checkable artifact: the ledger's evidence column and the referenced runbook files are inspectable by the operator or `@observability-reviewer`, who will BLOCK a COMPLETE whose rows lack real evidence. Do not launder a SKIPPED/FAILED run into COMPLETE.

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
