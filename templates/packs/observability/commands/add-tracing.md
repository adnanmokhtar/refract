---
description: Add distributed tracing to a service / endpoint / job. OpenTelemetry-first; vendor-agnostic. Spans + context propagation + sampling + attributes; produces a working trace + a runbook entry.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /add-tracing

**A narrow entry point into `/add-telemetry`, not a lighter alternative to it.** This file owns the
trace-specific depth — bootstrap ordering, resource attributes, propagators, samplers, span naming.
Everything else is inherited and MUST NOT be re-derived here:

- **The Premise + mechanical halt** — sibling instrumentation is the truth; mirror the sibling's span
  names, attribute keys, resource attributes and sampler config. Full text and the three escalation
  triggers: `commands/add-telemetry.md § The Premise`. On a greenfield repo, run its four-row
  convention ledger rather than halting with "user picks".
- **Closure** — the emit-and-assert ledger, the `ASSERTED / SKIPPED(reason) / FAILED` vocabulary and
  the closure gate in `commands/add-telemetry.md`. A traces-only run produces a one-row-per-span
  ledger and is held to exactly the same bar. **A narrower command does not get a weaker gate.**

One exception to sibling parity, and it is the reason this command has bitten people: **where the
sibling's attribute name is a *deprecated* OTel semantic convention, the current convention wins.**
`http.url`, `http.method`, `http.status_code`, `db.system` and `db.statement` are all deprecated;
the current spellings, and the `OTEL_SEMCONV_STABILITY_OPT_IN` dual-emit switch for migrating a repo
that is on the old ones, are in `ai/patterns/tracing.md`. Record the divergence in the run summary.

Use when:
- Service has structured logs but no tracing → debugging "where did this slow down" requires correlating logs.
- Microservice graph but no end-to-end traces → blind to cross-service latency.
- One specific endpoint chronically slow + no visibility into which sub-call.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## Phase 1 — Understand

- What service / endpoint / job?
- Existing tracing (none, partial, vendor-specific)?
- Backend (the project's trace backend — vendor-neutral examples include Jaeger, Tempo; vendor-managed examples include Datadog APM, Honeycomb, New Relic, Cloud Trace)?
- Existing log aggregator? Trace ↔ log correlation needed?

## Phase 2 — Organize

Per ecosystem, the work decomposes:

1. **SDK install** — OpenTelemetry SDK + exporter for the target backend.
2. **Auto-instrumentation** — drop in for HTTP server / client / DB / queue.
3. **Manual instrumentation** — custom spans around business operations the auto-instrument doesn't cover.
4. **Context propagation** — verify trace context flows: incoming → internal → outgoing requests.
5. **Sampling** — configure (head-based / tail-based / parent-based) appropriate to volume.
6. **Trace ↔ log correlation** — inject `trace_id` / `span_id` into log structured fields.
7. **Resource attributes** — `service.name`, `service.version`, `deployment.environment.name`, `host.name`.

## Phase 3 — Retrieve

Use the project's stack-native OpenTelemetry SDK (every mainstream language has one) plus the auto-instrumentations for the project's HTTP server / client / DB / queue libraries. If a vendor APM agent is already in use, mirror that; otherwise prefer the OTel SDK + OTLP exporter for vendor neutrality.

Read project's:
- `ai/architecture.md` — service topology.
- Existing logger setup — for `trace_id` injection.
- Production deployment config — for resource attributes.
- Existing APM (vendor) config if any — to mirror or migrate.
- One existing traced module — mirror its span-name casing, attribute keys, exception-recording shape.

## Phase 4 — Generate

Bootstrap tracing in the project's entry point BEFORE any instrumented library loads. The conceptual setup is identical across SDKs:

1. Create a tracer provider with a `Resource` carrying `service.name`, `service.version`, `deployment.environment.name` (read from env / build metadata).
2. Configure an exporter pointing at the project's trace backend (OTLP for vendor-neutral; vendor-specific exporter where committed).
3. Register auto-instrumentations for the project's HTTP server / client / DB / queue libraries; disable noisy ones (e.g., raw filesystem ops).
4. For business operations not covered by auto-instrumentation, wrap the operation in a manual span: open span with a **low-cardinality name** and the right **SpanKind**, set attributes (`tenant_id`, `entity.id`, counts), record exception + ERROR status on failure, end span in finally.
5. Configure the logger to inject the active span's `trace_id` + `span_id` as fields on every log line.
6. Configure the sampler — **parent-based** with a head-based ratio (1–10%) for steady-state (`parentbased_traceidratio`; a bare ratio sampler re-decides mid-trace and splits traces, SA-01). A head sampler decides before the outcome is known, so it cannot keep every error trace: where errors must be kept, add a collector `tail_sampling` policy on `status_code: ERROR` behind a `loadbalancing` exporter keyed on `traceID` (`telemetry-config-scan` §3), or rely on tracker capture beside the sampled trace (SA-02).

### Span names and SpanKind

A span name is a grouping key: every backend aggregates latency by it. `GET /orders/8814` splits one
endpoint into a million one-sample groups and destroys the p95. Use `{method} {route-template}` for
server spans, `{method}` for client spans, `<domain>.<verb>` for business spans.

Set SpanKind on anything that crosses a process boundary (`SERVER` / `CLIENT` / `PRODUCER` /
`CONSUMER`; `INTERNAL` otherwise). The service map and the "which upstream is slow" view are derived
from it — a service whose every span is `INTERNAL` renders as one node with no edges.

### Attributes

Convention attributes come from the current OTel semantic conventions (`ai/patterns/tracing.md`
carries the deprecated→current table). Project attributes — the ones no convention covers — take a
project prefix, a bounded value space, and the sibling's exact spelling. Never a raw body, never a
URL carrying query params, never anything per-request-unique.

Production sampling: parent-based head ratio 1–10% for steady-state, plus a tail-sampling collector
(status policy, trace-id load balancing in front) or tracker capture when errors must be kept.

## Phase 5 — Update

- `ai/runbooks/tracing.md` — runbook entry. How to correlate trace + log; how to find a specific request; common queries; the exact synthetic-request command from Phase 6.
- `ai/architecture.md` — note that the observability stack now includes tracing.
- The project's env-config example file — add `OTEL_*` env vars with defaults / placeholders. Include `OTEL_SEMCONV_STABILITY_OPT_IN` if the repo is mid-migration between attribute generations.
- Add the tracing-bootstrap source file to be loaded first.
- Update CI to verify env vars set in production.

## Phase 6 — Validate

Split: gates the agent verifies from code/config, and a live checklist the operator confirms against the running backend (the agent cannot see the backend UI — it must NOT report "trace appeared" as auto-passed).

Agent-verified (static + synthetic):
- Trace ID present in log lines (assert programmatically: emit a log inside an active span in a unit/integration test, parse the line, confirm `trace_id`/`span_id` fields equal the exporter's ids — V193).
- **Cross-hop test (V194, `trace-propagation-scan` §1–§3).** With the in-memory exporter wired into the test harness the repo already runs (same bootstrap file production uses), drive the real entry point **across every hop this run instruments**: HTTP → enqueue → consume against a real broker (testcontainers, or a local Redis for BullMQ — whose telemetry must be set on both the `Queue` and the `Worker`), HTTP → outbound call to a local sink that records the received `traceparent`, HTTP → executor or thread pool. Assert one traceId with correct parentage, or a span link, on the far side. A mocked queue or client proves nothing about headers. Context propagation is the main failure of LLM-written instrumentation (OTelBench, Quesma, 2026-01), so a span this run added is unverified until this test passes.
- **Sampler (V197, `trace-propagation-scan` §9–§10).** A config-load test prints the **resolved** sampler; its description names `ParentBased`. Rate 1.0 in production needs a per-route `tracesSampler` or a stated low-RPS budget (precedents § 33). **Where a project document (an ADR, the SLO doc, a runbook, a rule) says error traces are kept**, a head ratio alone fails that requirement (SA-02): show the collector `tail_sampling` `status_code` policy (with trace-id load balancing in front) or the error tracker capturing on the same paths, then send N error traces through the configured ratio and the collector config and count the retained ones. A requirement with no mechanism is a FAILED row. Services on one call graph resolve to the same sampler (SA-04).
- Resource attributes set (`service.name`, version, env) — assert on the `Resource` in a test.
- Span names are low-cardinality and SpanKind is set on process-boundary spans — assert on the span-export test.
- No deprecated semantic-convention attribute emitted (`http.url`, `http.method`, `http.status_code`, `db.system`, `db.statement`) unless `OTEL_SEMCONV_STABILITY_OPT_IN` is set to a `/dup` value and the migration is recorded.
- Sensitive data NOT in span attributes (no full request bodies; no auth tokens; no `url.query` carrying PII) — grep instrumentation + run a span-export test asserting the attribute allow-list.

**Record the result in the emit-and-assert ledger** defined in `commands/add-telemetry.md` — one row
per span (and one for the log-correlation assertion), evidence column carrying the test command and
what it observed, `Status` from that command's `ASSERTED / SKIPPED(reason) / FAILED` vocabulary, and
Status computed from the ledger by its closure gate. A span nobody exported in a test is `SKIPPED`,
which is UNVERIFIED, which is `INCOMPLETE` — never a silent pass.

OPERATOR CHECKLIST (live — confirm against the trace backend, NOT auto-passed):
- [ ] Fire a synthetic request through the entry point (curl the endpoint / enqueue a job / run the documented smoke command) → a trace appears in the project's trace backend.
- [ ] Cross-service trace works (front-end → api → DB → cache → queue) — span graph reflects reality.

## Phase 7 — Improve

- If many manual spans cluster around one feature → propose a tracing-aware decorator pattern.
- If the trace surfaces a perf hotspot → spawn `/profile-perf`.
- If sampling rate tuning needed → ADR for the rate decision.

## Output format

```
## /add-tracing complete

Service:                  <name>
Backend:                  <project's trace backend>
Auto-instrumentations:    <count>
Manual spans:             <count>
Sampling rate:            <%> · resolved sampler: <description> · errors kept by: <tail policy file:line | tracker | no requirement>
Cross-hop test:           <hops asserted, e.g. HTTP → BullMQ → worker: one traceId | SKIPPED(reason)>
Trace↔log correlation:    <asserted | SKIPPED(reason)>
Semconv generation:       <current | dup-emitting during migration>
Sensitive data filtering: configured

Emit-and-assert ledger: <rows> signals — ASSERTED <a> | SKIPPED <s> | FAILED <f>
  <the ledger table from add-telemetry, verbatim, with evidence per row>

Files written:
- <tracing-bootstrap source file>
- ai/runbooks/tracing.md
- env-config example file (additions)

Status: <computed from the ledger per add-telemetry's closure gate>
```

## Hard rules

- **No PII / secrets in span attributes.** Names, emails, tokens, full URLs with query strings — all forbidden.
- **Resource attributes set.** Without `service.name` + env, traces are useless across services.
- **`trace_id` in logs.** Without correlation, logs and traces are two unrelated data sources.
- **Sampling configured.** Parent-based everywhere; ~1–10% head ratio in production. Errors you must keep need a tail `status_code` policy or tracker capture — a head sampler cannot keep them (SA-02).
- **Auto-instrumentation first; manual second.** Custom spans only where auto doesn't reach.
- **Current semantic conventions.** A deprecated attribute name fails silently — the dashboard is empty, nothing errors.
- **Closure comes from the ledger**, not from a hand-written line.

## Failure modes

- Forgot to bootstrap tracing FIRST → some libraries won't be instrumented.
- Auto-instrumentation noisy → too many spans of low value.
- Sampling too aggressive (1%) → missing the slow tail.
- A bare ratio sampler (no `ParentBased`) → each service re-decides, and half-traces arrive.
- "Head sampling keeps errors" assumed → the error traces are the ones dropped.
- A queue hop with the context left out of the message → the consumer starts a new trace; only a cross-hop test shows it.
- Shipped with PII in span attributes → privacy violation.
- `trace_id` missing from logs → every debugging session starts with "find me the request."
- Resource attributes hardcoded → all envs look the same in the backend.
- Deprecated attribute names → backend's built-in HTTP/DB views stay empty and nobody gets an error.

## Related

- `add-telemetry` — the parent command; owns the Premise, the ledger and the closure gate this one inherits.
- `add-metrics` — the metrics-side narrow entry point; pair them.
- `alert-design` — uses tracing data.
- `slo-audit` skill — uses tracing latencies for SLO measurement.
- `trace-propagation-scan` skill — the detector whose in-memory-exporter oracle (V194–V197) the Phase 6 checks reuse; `/obs-audit` runs it repo-wide.
- `@telemetry-architect` agent — broader observability strategy.
- `ai/patterns/tracing.md` — span naming, SpanKind, the deprecated→current attribute table, the migration switch, detectors, references.
- `.claude/rules/observability-principles.md` — the always-loaded observability rule this command satisfies.
