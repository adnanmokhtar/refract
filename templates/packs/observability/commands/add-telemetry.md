---
description: Wire structured logs, metrics, and traces into a feature; create alert + runbook stubs.
---

# /add-telemetry <feature>

## This command owns closure for all four primitives

`/add-metrics` and `/add-tracing` are **narrow entry points into this one**, not lighter
alternatives to it. They carry the signal-specific depth (meter shape, bucket choice, cardinality
budget; bootstrap ordering, propagator, sampler) and then route closure back here: same
emit-and-assert ledger, same vocabulary, same gate. A run scoped to one signal produces a one-row
ledger — never a lower bar. Narrower scope, identical standard of proof.

OpenTelemetry unified logs, metrics and traces onto one SDK, one `Resource`, one exporter and one
propagator because they are one wiring job. Splitting the *closure* across three commands is what
let the narrow ones drift into weaker gates.

## The Premise (read this first, internalize, do not deviate)

**Existing log fields, metric names, and span attributes are the truth.** If any sibling feature in this repo is already instrumented, that convention IS the convention for this feature. New telemetry MUST mirror sibling instrumentation: same log field names (`request_id` vs `requestId` vs `req_id` — pick the one already in use), same span attribute names (`order.tenant_id` vs `tenant.id`), same metric naming convention, same severity tiers. Don't invent new conventions.

**The agent's job is exactly this:**
1. Find one existing instrumented sibling module (Phase 3 already requires this — enforce it).
2. Mirror its log field names, metric prefix, span attribute keys, alert severity labels exactly.
3. Only deviate when an accepted ADR documents the divergence — otherwise, sibling parity wins.

**The agent does NOT:**
- Add a log field (`tenantId`) when sibling logs use `tenant_id`.
- Invent a span attribute (`request.url`) when a semantic convention already names the thing (`url.full` / `url.path`) — or keep a deprecated one (`http.url`, `db.system`, `db.statement`) because a sibling has it. Convention names come from `ai/patterns/tracing.md`, which carries the current spellings and the `OTEL_SEMCONV_STABILITY_OPT_IN` dual-emit switch for migrating a repo that is on the old ones.
- Pick a metric prefix (`feature_xxx_total`) when sibling metrics use `feature.xxx.count`.
- Draft an ADR mid-run to legitimize a new convention. **Sibling wins. Mirror it** — except where the sibling's name is a *deprecated semantic convention*, in which case the current convention wins and the divergence is recorded in the run summary.

**Closure verb (default): mirror-sibling.** Auto-apply parity edits silently; batch into the end-of-run summary. Only halt on the three escalation triggers below.

**Escalation triggers (halt and ask):**
- No sibling instrumented module exists anywhere in the repo (greenfield). Do NOT halt empty-handed — present the greenfield convention ledger below and ask the user to pick four values.
- Sibling conventions are internally inconsistent across modules (two patterns coexist — user picks).
- The new instrumentation genuinely cannot fit sibling shape (different telemetry layer, different SDK) — surface and ask.

That's it. Everything else is silent sibling-parity emission.

## Greenfield — the four conventions to pick before writing any code

"Mirror the sibling" is inert on a project with no instrumented sibling, which is the single most
common state this command runs in. Do not halt with "user picks the convention" and stop: that hands
the user a blank. Present these four rows, with the options and what decides each, take four
answers, write them to `ai/conventions.md`, and proceed. Every later run then has a sibling.

| Decision | Options | What decides it |
|---|---|---|
| **Log field casing** | `snake_case` / `camelCase` | Whatever the language's ecosystem already emits, so nothing has to translate. `trace_id` / `span_id` are snake_case either way — the OTel log-correlation convention fixes them, and renaming them costs automatic log↔trace linking in most backends. |
| **Correlation-ID mechanism** | honor an inbound `traceparent` / mint at the edge and echo it | Whether anything upstream propagates trace context. Either way it must reach every log line through the runtime's **ambient context** primitive (async-local storage, context var, MDC, `context.Context`) — not a parameter threaded through call sites, which is where it always gets dropped. |
| **Metric name + prefix** | `<service>_<thing>_<unit>` (underscores, `_total` / `_seconds` suffixes) / dotted OTel-style names | The metrics backend's own convention. Pick once — a rename later invalidates every dashboard and alert built on it. |
| **Span attribute namespace** | current OTel semantic conventions / a project-local `<domain>.<field>` prefix | Use the semantic convention wherever one exists; backends key their built-in views off those exact strings. Invent a namespace only for domain attributes no convention covers. |

**Migrating an existing service off unstructured logging is a different job from instrumenting a new
one, and it is mostly mechanical.** Keep the existing call sites, swap the sink behind a shim that
the old call signature still satisfies, and backfill the request-scoped fields (`trace_id`,
`request_id`, `tenant_id`) from ambient context inside the shim rather than at each site. That turns
"rewrite every log line" into "change one module", and it is the correct first move whenever the
project logs through the language's stdout primitive today.

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
  - Logs: the project's structured logger (per the project's stack). **If there isn't one** — the project prints through the language's stdout primitive — that is not a blocker and not a reason to skip the phase: pick a logger whose JSON output is the default (so no parallel formatter config exists to drift), then apply the shim-and-backfill migration from the greenfield section above. Record the choice in `ai/conventions.md`.
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
  - Histograms: `<feature>_duration_seconds`, buckets from `ai/patterns/metrics.md` (the OTel advisory set, plus an edge **at** the SLO threshold T — a latency SLI is a count under T and a histogram can only count at a bucket edge).
  - Trace span around use-case entry; sub-spans on external IO (DB, HTTP, queue). Attribute keys per `ai/patterns/tracing.md` — current semantic conventions, never a deprecated spelling.
  - **Tenant labels are a computation, not a preference.** On a multi-tenant project `tenant_id` is simultaneously the most useful dimension and the one that detonates the TSDB. Compute `series = ∏(distinct label values) × replicas` before adding it (worked example in `ai/patterns/metrics.md`), and default to: top-N tenants labelled plus an `other` bucket on the *metric*; full tenant fidelity on *logs, traces and exemplars*, where it costs nothing.
- Alert config in project's format — **SLO-linked, not static thresholds.** Each generated alert MUST name the SLO/SLI it protects and fire on burn rate, mirroring `alert-design`'s three-tier multi-window pattern (derivation in `ai/patterns/slo.md`):
  - Fast burn (1h window, **14.4×** budget, confirmed at 5m, `severity: page`) on the feature's availability SLI (`<feature>_requests_total{status="error"} / total`).
  - Medium burn (6h window, 6× budget, confirmed at 30m, `severity: page`) on the same SLI. This tier **pages** — it is Google's second page tier, not a ticket.
  - Slow burn (3d window, 1× budget, confirmed at 6h, `severity: ticket`). Emit this one even though it fires rarely: a leak burning at exactly the target rate trips neither page tier by construction, so without it nothing detects "we will miss the SLO at month-end".
  - Latency SLO burn where a latency SLO exists — burn against the `<feature>_duration_seconds` histogram's objective, NOT a bare `p95 > Nms` threshold.
  - Saturation alerts (queue depth, pool wait) where applicable — cause-based, `severity: ticket`, dashboard-first.
  - **A static `error-rate > X% over Nmin` threshold is a FAILED alert here** (alert fatigue + SLO-disconnected). If no SLO exists for the feature, halt and route to `/alert-design` Phase 1, which dispatches `slo-audit` to define one — do not emit a blog-post threshold.
- Runbook stub `ai/runbooks/alert-<name>.md` — **dispatch `@incident-responder` to write the body**, not just the file. It owns live-incident procedure, so it is what turns a stub into something executable at 3am: symptom, the mitigation ladder for this failure class, investigation queries (log filter + trace selector), known false-positives, escalation path. A stub whose body says "investigate" fails the closure gate below as surely as a missing file.

## Phase 5 — Update
- `ai/observability.md` (or `ai/dashboards.md`) — note new dashboard panels.
- `ai/runbooks/` — new stubs created.
- `ai/dynamic/changelog.md` — one-line: `Telemetry added for <feature>: N alerts, M metrics`.
- `ai/status.md` — `## Recent Changes` bullet.

## Phase 6 — Validate

Agent-verified (static — this command generates alerts, so it audits them):
- Every metric has a dashboard or alert paired (no unread metrics).
- Every alert has a runbook (no 3am page without script).
- No high-cardinality labels (`user_id`, `request_id`, full URL) in metric labels — those go in logs/traces only.
- **`tenant_id` as a metric label: computed, not assumed.** State the series arithmetic in the run summary (`tenants × routes × status × replicas`). Unbounded by tenant count → top-N + `other`. This is the one label that is correct on logs and traces and usually wrong on metrics, so it needs its own line rather than membership in either list.
- Multi-tenant projects: `tenant_id` field present on every log entry and every span.
- PII redacted at the logger level (passwords, tokens, full PANs, full PII), not at call sites.
- **Dispatch the `alert-audit` skill** on the alerts this command just generated — confirm none are dead-on-arrival (query references a metric that was actually instrumented here), every alert has a runbook + owner, and each fires on a symptom not a cause. A broken-query / orphaned finding halts before completion.

Emit-and-assert (executable gate per primitive — every one of the four primitives has a real verification step, not just alerts). A run scoped to one signal runs that primitive's gate and produces a one-row ledger; it does not skip the gate:
- **Metrics** (the gate `/add-metrics` routes back to): scrape the local `/metrics` endpoint (or run the exporter in a test) and assert the new series names + label keys emitted here actually appear. A new counter/histogram that does not show up on scrape is not instrumented — halt. Record the scrape command in `ai/runbooks/metrics.md`.
- **Traces** (the gate `/add-tracing` routes back to): emit a log inside an active span in a unit/integration test, parse the line, and assert `trace_id`/`span_id` fields are present; and run a span-export test asserting the new span is exported with its expected attributes. No `trace_id` in the log line / no exported span = correlation not wired — halt.
- **Logs**: assert the structured entry emits on entry/success/failure with the required fields (`request_id`, `tenant_id` on multi-tenant, `duration_ms`) via the same log-parse test — a missing field halts.

- **Alerts** (SLO-linkage assertion, mirror `alert-design` Phase 6): for every generated alert, assert (a) it references a metric series THIS run instrumented and asserted above (no dead-on-arrival query — the `alert-audit` dispatch is the executor), (b) it burns against a named SLO/SLI, not a static threshold, and (c) its `runbook:` annotation points at a file that EXISTS on disk (`test -f ai/runbooks/<name>.md`, not merely a string) **and whose body names a first mitigation action** — a runbook that says "investigate" is a missing runbook with a filename. Any alert failing (a)/(b)/(c) is a FAILED row — halt.

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
alert: <feature>-med-burn (page)  | alert   | alert-audit → not-dead + SLO-linked + runbook file exists    | ASSERTED
alert: <feature>-slow-burn (tkt)  | alert   | alert-audit → not-dead + SLO-linked + runbook file exists    | ASSERTED
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

### Narrow entry points into this command
- `add-metrics` — metrics only. Adds meter / bucket / cardinality depth, then routes closure back to this command's ledger and gate.
- `add-tracing` — traces only. Adds bootstrap-order, propagator and sampler depth, then routes closure back here.

### Agents
- `@telemetry-architect` — produces the Phase 4 edits.
- `@incident-responder` — dispatched in Phase 4 to author the runbook bodies the alerts link to.
- `@observability-reviewer` — reviews the change; BLOCKs a `COMPLETE` whose ledger lacks evidence.

### Skills
- `alert-audit` — dispatched in Phase 6 to vet the alerts this command generates (dead/noisy/runbook-less/orphaned/cause-based).

### Patterns
- `ai/patterns/metrics.md`
- `ai/patterns/structured-logging.md`
- `ai/patterns/tracing.md`

### Rules
- `.claude/rules/observability-principles.md`
