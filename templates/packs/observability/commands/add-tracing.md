---
description: Add distributed tracing to a service / endpoint / job. OpenTelemetry-first; vendor-agnostic. Spans + context propagation + sampling + attributes; produces a working trace + a runbook entry.
---

# /add-tracing

## The Premise (read this first, internalize, do not deviate)

**Existing span attributes are the truth.** If any sibling service or module in this repo is already traced, those span names, attribute keys, and resource attribute conventions ARE the convention. New tracing MUST mirror sibling instrumentation: same span naming pattern (`orders.placeOrder` vs `orders.place_order` vs `OrdersService.placeOrder`), same attribute keys (`order.tenant_id` vs `tenant.id`), same resource attributes, same sampler config. Don't invent new conventions.

**The agent's job is exactly this:**
1. Find one existing traced sibling module. Read its `tracer.startActiveSpan` calls, attribute keys, resource setup.
2. Mirror that shape for the new spans. Same span-name casing. Same attribute key spellings. Same exception-recording pattern.
3. Only deviate when an accepted ADR documents the divergence — otherwise, sibling parity wins.

**The agent does NOT:**
- Use `setAttribute('http.url', ...)` when sibling spans use `request.url`.
- Name a span `OrdersPlace` when sibling spans use `<domain>.<verb>` (`orders.place`).
- Add a resource attribute (`team.name`, `cost.center`) that no sibling service emits.
- Draft an ADR mid-run to legitimize a new convention. **Sibling wins. Mirror it.**

**Closure verb (default): mirror-sibling.** Auto-apply parity edits silently; batch into the end-of-run summary. Only halt on the three escalation triggers below.

**Escalation triggers (halt and ask):**
- No sibling traced module exists anywhere in the repo (greenfield — user picks the convention).
- Sibling conventions are inconsistent (two span-naming patterns coexist — user picks).
- The new tracing genuinely cannot fit sibling shape (different SDK, different exporter) — surface and ask.

That's it. Everything else is silent sibling-parity emission.

## Mechanical halt — instrumentation-naming parity

Before finishing Phase 4, run these checks. Any failure = HALT, surface, do not advance:

1. **Span name parity** — collect existing span names via `grep` for `startActiveSpan` / `start_as_current_span`. New span names MUST follow the same casing + separator (`<domain>.<verb>` vs `<Class>.<method>`).
2. **Attribute key parity** — every new `setAttribute` key MUST match sibling spans for the same semantic (`tenant_id`, `user_id`, `order.id`, `route`). No new attribute keys without an ADR.
3. **Resource attribute parity** — new bootstrap reuses sibling `service.name` / `service.version` / `deployment.environment` keys verbatim.
4. **Sampler parity** — new sampler config matches sibling services (rate, parent-based, tail-based) unless data-justified divergence is documented inline.

Add the check results to the output block under `Naming-parity: ✓ | halts=<N>`.

Add OpenTelemetry tracing where it's missing. Use when:
- Service has structured logs but no tracing → debugging "where did this slow down" requires correlating logs.
- Microservice graph but no end-to-end traces → blind to cross-service latency.
- One specific endpoint chronically slow + no visibility into which sub-call.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## Phase 1 — Understand

- What service / endpoint / job?
- Existing tracing (none, partial, vendor-specific)?
- Backend (the project's trace backend — vendor-neutral examples include Jaeger, Tempo; vendor-managed examples include Datadog APM, Honeycomb, New Relic, Cloud Trace, Lightstep)?
- Existing log aggregator? Trace ↔ log correlation needed?

## Phase 2 — Organize

Per ecosystem, the work decomposes:

1. **SDK install** — OpenTelemetry SDK + exporter for the target backend.
2. **Auto-instrumentation** — drop in for HTTP server / client / DB / queue.
3. **Manual instrumentation** — custom spans around business operations the auto-instrument doesn't cover.
4. **Context propagation** — verify trace context flows: incoming → internal → outgoing requests.
5. **Sampling** — configure (head-based / tail-based / parent-based) appropriate to volume.
6. **Trace ↔ log correlation** — inject `trace_id` into log structured fields.
7. **Resource attributes** — service.name, service.version, deployment.environment, host.name.

## Phase 3 — Retrieve

Use the project's stack-native OpenTelemetry SDK (every mainstream language has one) plus the auto-instrumentations for the project's HTTP server / client / DB / queue libraries. If a vendor APM agent is already in use, mirror that; otherwise prefer the OTel SDK + OTLP exporter for vendor neutrality.

Read project's:
- `ai/architecture.md` — service topology.
- Existing logger setup — for trace_id injection.
- Production deployment config — for resource attributes.
- Existing APM (vendor) config if any — to mirror or migrate.

## Phase 4 — Generate

Bootstrap tracing in the project's entry point BEFORE any instrumented library loads. The conceptual setup is identical across SDKs:

1. Create a tracer provider with a `Resource` carrying `service.name`, `service.version`, `deployment.environment` (read from env / build metadata).
2. Configure an exporter pointing at the project's trace backend (OTLP for vendor-neutral; vendor-specific exporter where committed).
3. Register auto-instrumentations for the project's HTTP server / client / DB / queue libraries; disable noisy ones (e.g., raw filesystem ops).
4. For business operations not covered by auto-instrumentation, wrap the operation in a manual span: open span, set attributes (`tenant_id`, `entity.id`, counts), record exception + ERROR status on failure, end span in finally.
5. Configure logger to inject the active span's `trace_id` + `span_id` as fields on every log line.
6. Configure sampler — parent-based with head-based ratio (1–10%) for steady-state; tail-based at the collector for "always sample errors / slow requests" where the collector supports it.

Production: use head-based 1-10% for steady-state + a tail-based collector for "always sample errors / slow requests."

## Phase 5 — Update

- `ai/runbooks/tracing.md` — runbook entry. How to correlate trace + log; how to find a specific request; common queries.
- `ai/architecture.md` — note that observability stack now includes tracing.
- The project's env-config example file — add `OTEL_*` env vars with defaults / placeholders.
- Add the tracing-bootstrap source file to be loaded first.
- Update CI to verify env vars set in production.

## Phase 6 — Validate

- A trace appears in the project's trace backend for a synthetic request.
- Cross-service trace works (front-end → api → DB → cache → queue) — span graph reflects reality.
- Trace ID present in log lines.
- Sampling configured (you're not sampling 100% in production).
- Resource attributes set (service.name, version, env).
- Sensitive data NOT in span attributes (no full request bodies; no auth tokens).

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
Sampling rate:            <%>
Trace↔log correlation:    enabled
Sensitive data filtering: configured

Files written:
- <tracing-bootstrap source file>
- ai/runbooks/tracing.md
- env-config example file (additions)

First trace landed: <link>
```

## Hard rules

- **No PII / secrets in span attributes.** Names, emails, tokens, full URLs with query strings — all forbidden.
- **Resource attributes set.** Without service.name + env, traces are useless across services.
- **Trace_id in logs.** Without correlation, logs and traces are two unrelated data sources.
- **Sampling configured.** 100% in production = expensive + noisy. Default ~1-10% with always-sample-errors via tail sampling.
- **Auto-instrumentation first; manual second.** Custom spans only where auto doesn't reach (business ops, sub-operations within a function).

## Failure modes

- Forgot to bootstrap tracing FIRST → some libraries won't be instrumented.
- Auto-instrumentation noisy → too many spans of low value.
- Sampling too aggressive (1%) → missing the slow tail.
- Shipped with PII in span attributes → privacy violation.
- Trace_id missing from logs → every debugging session starts with "find me the request."
- Resource attributes hardcoded → all envs look the same in the backend.

## Related

- `add-metrics` — metrics counterpart; pair them.
- `alert-design` — uses tracing data.
- `slo-audit` skill — uses tracing latencies for SLO measurement.
- `@telemetry-architect` agent — broader observability strategy.
- `.claude/rules/observability-principles.md` — A33 (telemetry local-only) reminder for dev environments.
