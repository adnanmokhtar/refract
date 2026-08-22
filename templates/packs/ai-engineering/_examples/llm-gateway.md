---
name: llm-gateway
description: 'Pattern: LLM Gateway — one seam for routing, fallback, caching, cost, streaming, observability'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: LLM Gateway

> **Hard rule:** Every provider call goes through ONE internal seam — no feature calls a provider SDK directly. The seam owns timeout + token cap, retry, fallback, caching, cost/latency tracking, streaming, and trace-linked logging with PII/secret redaction. Scattered SDK calls can't be given a retry, cache, fallback, or cost number without touching every site. A direct call with no timeout + no fallback is a SPOF on someone else's uptime.

**When to apply** — any project calling a provider from more than one place, or the moment you need retry/caching/cost/fallback/A-B. **Don't over-build** a routing engine for a one-off script (but still cap tokens + timeout); reuse a mature OSS gateway if one fits — the pattern is the *seam*.

**Halt conditions / mandatory cites**
- Provider SDK called from feature code, not the gateway → cite `<path:line>`.
- Call with no timeout OR no `max_output_tokens` → cite.
- Single-provider prod path, no fallback → cite as SPOF (or document accepted risk).
- Repeated large identical context, no caching → cite.
- Call with no tokens+cost+latency+model logged → cite (financially unobservable).

## Responsibilities the seam owns

| Concern | Gateway does |
|---|---|
| Routing | cheap model for easy tasks, strong for hard (cascade); by task/tenant/flag |
| Fallback | on error/timeout/overload/rate-limit → fallback model/provider |
| Caching | exact-match + semantic + provider prompt-caching |
| Budget | per-call timeout + token cap; cost per call/feature; ceiling |
| Streaming | stream tokens; handle mid-stream errors |
| Observability | log prompt/response/tokens/cost/latency/model, trace-linked, PII-redacted |

## Routing + fallback

- **Cascade (cost-first):** cheap model first, escalate to strong only on a quality/confidence check — biggest single cost lever.
- **Task-based:** classify/extract/format on small; reasoning/synthesis on large.
- **Fallback chain** `primary → secondary` on `timeout|5xx|overloaded|429`; cross-provider survives a vendor outage.
- **Retry transient only** (timeout/429/5xx) with backoff+jitter — never a 4xx. The retry/circuit-breaker *mechanics* are distributed-systems'; the gateway *applies* them.

## Caching

- **Exact-match** on `(model, normalized prompt, params)` — single-answer calls cache well.
- **Provider prompt-caching has a floor that fails silently.** Below the model's minimum cacheable prefix nothing caches and *no error is returned*; the minimum is model-dependent and not monotonic across a vendor's generations, so read it per model rather than remembering it. Keep volatile content (timestamps, per-request ids, the question) after the last cache marker — prefix caching is byte-prefix matching, so one varying character invalidates everything after it. Confirm from the response's cache-read counter before claiming a saving. A per-request breakpoint ceiling also applies.
- **Semantic** on request-embedding similarity — strict threshold; **never across tenants/permission scopes** (cross-tenant hit = data leak).
- **Provider prompt-caching** for a large stable prefix (system prompt, tool schemas, long doc) — order stable-prefix-first.
- **Invalidate + TTL** keyed by prompt version + model — a prompt/model change must not serve stale answers.

## Cost + latency budget

Per-call hard timeout + `max_output_tokens`. Attribute cost per feature/tenant via gateway logging (dashboard, not month-end surprise); enforce a ceiling where runaway is possible (agent loops — see `agent-design`). Right-size: cheapest model that passes the eval set wins.

## Streaming

Stream tokens for perceived latency (first-token-time dominates UX). Handle mid-stream failure — don't leave a half-message as complete; keep it retry-safe. Assemble streamed tool-call deltas before dispatch.

## Observability

Log model id, prompt version, in/out tokens, cost, latency, finish reason, cache hit/miss, fallback-fired, request/tenant id — **trace-linked**. **Redact PII/secrets** once at the gateway. Metric/trace design (RED, cardinality, sampling, audit) is owned by observability — the gateway is the emit point.

## Detectors (cite-or-halt)

- Provider SDK in feature code, not the gateway → `route-through-gateway`.
- Call with no timeout / no token cap → `add-call-budget`.
- Single-provider prod path, no fallback → `add-fallback`.
- Repeated identical large context, no caching → `add-prompt-cache` — but only once the prefix is measured above the model's minimum cacheable size; below it, the size is the finding.
- Semantic cache with no tenant/permission scoping → `scope-semantic-cache`.
- Call not logging tokens+cost+latency+model (trace-linked) → `add-cost-logging`.
- Prompt/response logged without redaction → `add-log-redaction`.

**Closure verbs:** `route-through-gateway`, `add-call-budget`, `add-fallback`, `add-prompt-cache`, `scope-semantic-cache`, `add-cost-logging`, `add-log-redaction`.

## Related

- **Patterns (in-pack):** `agent-design` (agent calls route through the gateway; loop budgets on top of per-call budgets), `prompt-engineering` (versioning drives cache key + structured-output config), `evals` (routing/model choice validated by evals), `rag-pipeline` (retrieved context is what prompt-caching amortizes).
- **Rule (in-pack):** `ai-engineering-principles`.
- **Cross-pack:** timeout/retry/circuit-breaker/bulkhead → **distributed-systems**/**backend** (gateway applies, doesn't own); RED/trace/cardinality/audit/redaction policy → **observability** (`tracing`, `structured-logging`, `audit-logging`); secrets + injection/output → **security** `@llm-security-reviewer`.
