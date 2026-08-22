---
description: Wire structured logs, metrics, and traces into a feature; create alert + runbook stubs.
---

# /add-telemetry <feature>

Build command. Adds the four observability primitives — logs, metrics, traces, alerts — using the project's existing libraries. Generates runbook stubs. All 7 phases apply.

## This command owns closure for all four primitives

`/add-metrics` and `/add-tracing` are **narrow entry points into this one**, not lighter alternatives. They carry the signal-specific depth and route closure back here: same emit-and-assert ledger, same vocabulary, same gate. A run scoped to one signal produces a one-row ledger — never a lower bar.

## The Premise (read this first, internalize, do not deviate)

**Existing log fields, metric names, and span attributes are the truth.** If any sibling feature in this repo is already instrumented, that convention IS the convention for this feature. New telemetry MUST mirror sibling instrumentation: same log field names (`request_id` vs `requestId` vs `req_id` — pick the one already in use), same span attribute names, same metric naming convention, same severity tiers. Don't invent new conventions.

**The agent's job is exactly this:**
1. Find one existing instrumented sibling module (Phase 3 already requires this — enforce it).
2. Mirror its log field names, metric prefix, span attribute keys, alert severity labels exactly.
3. Only deviate when an accepted ADR documents the divergence — otherwise, sibling parity wins.

**The agent does NOT:**
- Add a log field (`tenantId`) when sibling logs use `tenant_id`.
- Invent a span attribute (`request.url`) when a semantic convention already names the thing (`url.full` / `url.path`) — or keep a deprecated one (`http.url`, `db.system`, `db.statement`) because a sibling has it. Current spellings and the `OTEL_SEMCONV_STABILITY_OPT_IN` dual-emit switch: `ai/patterns/tracing.md`.
- Pick a metric prefix (`feature_xxx_total`) when sibling metrics use `feature.xxx.count`.
- Draft an ADR mid-run to legitimize a new convention. **Sibling wins. Mirror it** — except where the sibling's name is a *deprecated semantic convention*, in which case the current convention wins and the divergence goes in the run summary.

**Closure verb (default): mirror-sibling.** Auto-apply parity edits silently; batch into the end-of-run summary. Only halt on the three escalation triggers below.

**Escalation triggers (halt and ask):**
- No sibling instrumented module exists anywhere in the repo (greenfield). Do NOT halt empty-handed — present the four-row ledger below and ask the user to pick.
- Sibling conventions are internally inconsistent across modules (two patterns coexist — user picks).
- The new instrumentation genuinely cannot fit sibling shape (different telemetry layer, different SDK) — surface and ask.

## Greenfield — the four conventions to pick before writing any code

"Mirror the sibling" is inert on a project with no instrumented sibling, which is the most common state this command runs in. Present these four rows, take four answers, write them to `ai/conventions.md`, and proceed. Every later run then has a sibling.

| Decision | Options | What decides it |
|---|---|---|
| **Log field casing** | `snake_case` / `camelCase` | Whatever the language's ecosystem already emits. `trace_id` / `span_id` stay snake_case either way — the OTel log-correlation convention fixes them, and renaming them costs automatic log↔trace linking in most backends. |
| **Correlation-ID mechanism** | honor an inbound `traceparent` / mint at the edge and echo it | Whether anything upstream propagates trace context. Either way it must reach every log line through the runtime's **ambient context** primitive (async-local storage, context var, MDC, `context.Context`) — not a parameter threaded through call sites, which is where it always gets dropped. |
| **Metric name + prefix** | `<service>_<thing>_<unit>` / dotted OTel-style names | The metrics backend's convention. Pick once — a rename invalidates every dashboard and alert built on it. |
| **Span attribute namespace** | current OTel semantic conventions / a project-local `<domain>.<field>` prefix | Use the convention wherever one exists; backends key built-in views off those exact strings. Invent a namespace only for domain attributes no convention covers. |

**Migrating off unstructured logging is a different, mostly mechanical job.** Keep the existing call sites, swap the sink behind a shim the old signature still satisfies, and backfill request-scoped fields (`trace_id`, `request_id`, `tenant_id`) from ambient context inside the shim. That turns "rewrite every log line" into "change one module".

## Mechanical halt — instrumentation-naming parity

See `templates/snippets/instrumentation-parity.md`. Weight all four dimensions (span, metric, log, alert) per the premise above. Any dimension where the new instrumentation diverges from the sibling — and the sibling is not on a deprecated semantic convention — is a **halt**, not a note.

Add the check results to the output block under `Naming-parity: ✓ | halts=<N>`.

## When to use / NOT to use
- USE: new feature shipping to staging+ — instrument before exposure.
- USE: existing feature with mystery failures (gaps in current telemetry).
- USE: as a follow-up from `/fix-bug` Phase 9 ("why didn't we know sooner?").
- NOT: feature flags off in prod or local-only tooling — instrumenting unreachable code = noise.
- NOT: as the fix for a real bug — observability surfaces problems, doesn't solve them.

## Phase 1 — Understand
- Feature name + entry points (controllers / handlers / job consumers).
- Confirm feature is reachable in staging+ — flagged-off code skips this command.
- Identify SLO targets if defined — they decide the histogram bucket edges.

## Phase 2 — Organize
- Detect libraries from `package.json` / `pyproject.toml` / the project's manifest:
  - Logs: `pino`, `winston`, `structlog`, `zerolog`, `slog`. **If there isn't one** — the project prints through the language's stdout primitive — that is the case this command handles, not a blocker: pick a logger whose JSON output is the default, then apply the shim-and-backfill migration above.
  - Metrics: `prom-client`, `@opentelemetry/sdk-metrics`, `statsd`, a vendor agent.
  - Traces: `@opentelemetry/sdk-trace`, `dd-trace`, a vendor APM SDK.
- Decide alert format (Prometheus rules / Datadog monitor JSON / Grafana alerting).
- Dispatch plan: `telemetry-architect` produces edits; `incident-responder` writes runbook bodies.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): `CLAUDE.md`, `.claude/codebase-profile.md`, `ai/conventions.md`, `ai/business-domain.md`, `ai/project-goals.md`, `ai/dynamic/feedback-learned.md`, `ai/status.md`.

Telemetry-specific:
- Existing dashboards / alert configs — match conventions, don't invent a new format.
- `ai/runtime/slos.md` — the SLO the generated alerts will burn against.
- The feature's entry points (read source).
- An existing telemetry-instrumented module — mirror exact patterns (field names, span attributes).

## Phase 4 — Generate
- Code edits via `telemetry-architect`:
  - Structured log on entry / success / failure of each public method (fields: `request_id`, `tenant_id`, `user_id`, `duration_ms`, plus feature-specific).
  - Counters: `<feature>_requests_total{status,reason}`.
  - Histograms: `<feature>_duration_seconds`, buckets from `ai/patterns/metrics.md` (the OTel advisory set) **plus an edge at the SLO threshold T** — a latency SLI is a count under T and a histogram can only count at a bucket edge.
  - Trace span around use-case entry; sub-spans on external IO. Low-cardinality span names, SpanKind set, attribute keys per `ai/patterns/tracing.md`.
  - **Tenant labels are a computation, not a preference.** Compute `series = ∏(distinct label values) × replicas` before labelling by `tenant_id` (`3 statuses × 20 routes × 10,000 tenants × 6 replicas = 3.6M series`). Default: top-N tenants + an `other` bucket on the metric; full tenant fidelity on logs, traces and exemplars, where it costs nothing.
- Alert config in project's format — **SLO-linked, not static thresholds.** Three tiers per `ai/patterns/slo.md`:
  - Fast burn — 1h window, **14.4×** budget, confirmed at 5m, `severity: page`.
  - Medium burn — 6h window, 6× budget, confirmed at 30m, `severity: page`. This tier **pages**; it is Google's second page tier, not a ticket.
  - Slow burn — 3d window, 1× budget, confirmed at 6h, `severity: ticket`. Emit it even though it fires rarely: a leak burning at exactly the target rate trips neither page tier by construction.
  - Latency SLO burn against the histogram's objective, NOT a bare `p95 > Nms` threshold.
  - **A static `error-rate > X% over Nmin` threshold is a FAILED alert here.** If no SLO exists, halt and route to `/alert-design` Phase 1, which dispatches `slo-audit` to define one.
- Runbook stub `ai/runbooks/alert-<name>.md` — **dispatch `@incident-responder` to write the body**: symptom, blast-radius query, mitigation ladder with exact commands, known false-positives, escalation. A body that says "investigate" fails the gate below exactly as a missing file does.

## Phase 5 — Update
- `ai/observability.md` (or `ai/dashboards.md`) — note new dashboard panels.
- `ai/runbooks/` — new stubs created.
- `ai/dynamic/changelog.md` — one-line: `Telemetry added for <feature>: N alerts, M metrics`.
- `ai/status.md` — `## Recent Changes` bullet.

## Phase 6 — Validate

Agent-verified (static):
- Every metric has a dashboard or alert paired (no unread metrics).
- Every alert has a runbook whose body names a first action.
- No high-cardinality labels (`user_id`, `request_id`, full URL) in metric labels.
- `tenant_id` as a metric label: the series arithmetic is stated in the run summary. Unbounded by tenant count → top-N + `other`.
- Multi-tenant projects: `tenant_id` present on every log entry and every span.
- PII redacted at the logger level, not at call sites.
- **Dispatch the `alert-audit` skill** on the alerts just generated — dead-on-arrival, runbook, owner, symptom-vs-cause. An open finding halts before completion.

Emit-and-assert (executable gate per primitive — a run scoped to one signal runs that primitive's gate and produces a one-row ledger; it does not skip it):
- **Metrics**: scrape the local `/metrics` endpoint (or run the exporter in a test) and assert the new series names + label keys appear. A counter that doesn't show up on scrape is not instrumented — halt.
- **Traces**: emit a log inside an active span in a test, parse the line, assert `trace_id`/`span_id` present; and run a span-export test asserting the new span is exported with its expected attributes.
- **Logs**: assert the structured entry emits on entry/success/failure with the required fields via the same log-parse test — a missing field halts.
- **Alerts**: for every generated alert assert (a) it references a series THIS run instrumented and asserted, (b) it burns against a named SLO/SLI, and (c) `test -f` on its `runbook:` path succeeds AND the body names a first action.

### Emit-and-assert ledger — REQUIRED OUTPUT ARTIFACT (the run is not done until this table exists)

The gates above only bind closure if their evidence is RECORDED. One row per signal the run claims to have added, each carrying the exact assertion evidence (the command run + its observed result), never a claim. A row with no evidence is UNVERIFIED, and UNVERIFIED is not a pass.

```
Signal (name)                     | Kind    | Assertion evidence (command → observed)                      | Status
<feature>_requests_total          | metric  | scrape /metrics → series+labels present                      | ASSERTED
<feature>_duration_seconds        | metric  | scrape /metrics → histogram+buckets present                  | ASSERTED
log: entry/success/failure fields | log     | log-parse test → request_id,tenant_id,duration_ms present    | ASSERTED
span: <feature> root + IO subspan | trace   | span-export test → span exported w/ trace_id in log line     | ASSERTED
alert: <feature>-fast-burn (page) | alert   | alert-audit → not-dead + SLO-linked + runbook w/ first action| ASSERTED
alert: <feature>-med-burn (page)  | alert   | alert-audit → not-dead + SLO-linked + runbook w/ first action| ASSERTED
alert: <feature>-slow-burn (tkt)  | alert   | alert-audit → not-dead + SLO-linked + runbook w/ first action| ASSERTED
```

Per-row `Status` — pick exactly one, no synonyms:
- **ASSERTED** — the evidence command ran and the observation confirms the signal. Only ASSERTED counts as production-grade.
- **SKIPPED(reason)** — the harness to assert it is genuinely absent (no `/metrics` endpoint in this stack, no test runner wired). Name the reason. A SKIPPED row is UNVERIFIED, not a pass — it downgrades the run to INCOMPLETE.
- **FAILED** — the assertion ran and the signal was absent / the alert was dead-on-arrival / not SLO-linked / runbook-less. Halt; do not emit COMPLETE.

Never write ASSERTED without a runnable command + its observed result in the evidence column. A fabricated ASSERTED is the enforcement-theater failure this pack exists to kill.

OPERATOR CHECKLIST (live — confirm against the backends, NOT auto-passed):
- [ ] Fire a synthetic request through the feature → the new logs / metrics / trace appear in their backends.
- [ ] Deliberately trip one generated alert → it fires AND pages/tickets the right rotation.

## Phase 7 — Improve
- `/learn-from-task` — capture instrumentation patterns introduced.
- If the same instrumentation boilerplate emerges 3+ times → queue helper extraction.
- If alert thresholds vary widely → queue ADR: standard SLO baseline.

## Output format
```
## /add-telemetry — <feature>

Phase 1 (Understand): entry points = <N>; SLO = <target + window>
Phase 3 (Retrieved): libs = <log|metric|trace>; sibling instrumented module mirrored
Phase 4 (Generated):
  src/orders/orders.service.ts     +18 (logs, metrics, span)
  config/prometheus/orders.rules.yml  new (3 burn tiers)
  ai/runbooks/alert-orders-fast-burn.md   body by @incident-responder
  ai/runbooks/alert-orders-slow-burn.md   body by @incident-responder
Phase 5 (Updated): ai/observability.md, runbooks/, changelog, status.md
Phase 6 (Validated): every metric paired; tenant_id present; PII redacted
  Tenant cardinality: <computed series count> = <the arithmetic>
  Emit-and-assert ledger: <rows> signals — ASSERTED <a> | SKIPPED <s> | FAILED <f>
  <the ledger table above, verbatim, with evidence per row>
Phase 7 (Improved): pattern queued

Reminder: PII in logs — masked email + last-4 of card only. Verify before merging.
Status: <computed from the ledger by the gate below — never hand-written>
```

### Closure gate — COMPLETE only when production-grade, else INCOMPLETE with the unmet signals named

Compute Status from the ledger — do NOT hand-write COMPLETE:

- **`Status: COMPLETE`** — ONLY when every ledger row is `ASSERTED`, the `alert-audit` dispatch returned zero dead/orphaned/runbook-less/cause-based findings, and every `page` alert names its SLO + burn window. Nothing else earns COMPLETE.
- **`Status: INCOMPLETE — unmet: <list>`** — the moment any row is `SKIPPED` or `FAILED`, or `alert-audit` has an open finding. NAME each unmet signal and why (e.g., `checkout_duration_seconds — SKIPPED: no /metrics endpoint in this stack, scrape unverified`). "Functional but unverified" is INCOMPLETE, never COMPLETE.

**[self-policed]** — no shell forces the Status line — but wired to a checkable artifact: the evidence column and the referenced runbook files are inspectable by the operator or `@observability-reviewer`, who will BLOCK a COMPLETE whose rows lack real evidence.

## Failure modes
- Metric without dashboard or alert → unread data; pair every metric or remove.
- Alert without a runbook body that names a first action → 3am page with no script.
- High-cardinality labels in a metric → cardinality explosion; move to logs/traces.
- Forgot `tenant_id` on multi-tenant project → cross-tenant noise during incident triage.
- 100% trace ingestion → expensive; head-based sampling on quiet endpoints, tail-based on errors.
- PII redaction at call site instead of logger level → one missed call site leaks data; centralize.
- Writing `Status: COMPLETE` because the code compiles → the signal may not exist at all; only the ledger decides.
