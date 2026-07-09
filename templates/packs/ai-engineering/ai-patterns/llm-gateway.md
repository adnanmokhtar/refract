---
name: llm-gateway
description: 'Pattern: LLM Gateway — one seam for routing, fallback, caching, cost, streaming, observability'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: LLM Gateway

> **Hard rule:** Every provider call goes through ONE internal seam (a gateway module / client / service) — no feature calls a provider SDK directly. That seam owns the timeout + token cap, retry, fallback, caching, cost/latency tracking, streaming, and trace-linked logging (with PII/secret redaction) for every call. Provider SDKs scattered across many call sites cannot be given a retry, a cache, a fallback, or a cost number without touching every site — the gateway is the point where those become one change. A direct-from-feature provider call with no timeout and no fallback is a single-point-of-failure on someone else's uptime.

**When to apply**
- Any project that calls an LLM provider from more than one place (which becomes every real project).
- The moment you need retry, caching, cost tracking, a fallback model, or an A/B of two models — all of which are trivial at a seam and painful sprinkled across sites.
- Multi-provider or self-hosted + hosted mix, where routing/fallback across vendors is a requirement.

**When NOT to over-build**
- A one-off script or a single call site with no reliability/cost requirement — a thin wrapper function is enough; don't build a routing engine for one prompt. But still give it a timeout + token cap.
- Don't reinvent a mature gateway (e.g. an OSS LLM proxy / router) if one fits — the pattern is the *seam*, not necessarily bespoke code.

**Halt conditions / mandatory cites**
- A provider SDK (`openai`, `anthropic`, `google-genai`, `mistralai`, a vLLM/Ollama client, …) imported and called from feature/business code rather than the gateway MUST be cited at `<path:line>` → the seam is bypassed.
- A model call with no timeout OR no max-output-token cap MUST be cited — unbounded latency + unbounded cost.
- A production LLM path with a single provider and no fallback on outage/overload MUST be cited as a SPOF (or the accepted-risk decision documented).
- Repeated large identical context (same system prompt / same document) sent every call with no caching MUST be cited — money left on the table.
- A model call with no logging of tokens + cost + latency + model id MUST be cited — the feature is financially unobservable.

## Responsibilities the seam owns

| Concern | What the gateway does |
|---|---|
| **Routing** | Pick model/provider per request: cheap model for easy tasks, strong model for hard ones (a **cascade**); route by task type, tenant, or feature flag. |
| **Fallback** | On error / timeout / overload / rate-limit from the primary, retry on a fallback model or provider. |
| **Caching** | Exact-match + optional semantic cache; leverage provider prompt-caching for repeated context. |
| **Budget** | Per-call timeout + max-output-token cap; track cost per call/feature; enforce a ceiling. |
| **Streaming** | Stream tokens for perceived latency; handle mid-stream errors. |
| **Observability** | Log prompt/response/tokens/cost/latency/model, trace-linked, with PII/secret redaction. |

## Routing + fallback

- **Cascade (cost-first):** try a cheaper/smaller model first; escalate to a stronger model only when the cheap one fails a quality/confidence check (validator, judge, or the cheap model declining). Most easy traffic never touches the expensive model — the biggest single cost lever.
- **Task-based routing:** classify/extract/format on a small model; reasoning/synthesis on a large one. Route on task type, not one-model-for-everything.
- **Fallback chain:** `primary → secondary (different model/provider)` on `timeout | 5xx | overloaded | rate-limited`. Cross-provider fallback survives a single vendor's outage; keep prompts portable enough to run on the fallback.
- **Retry is for transient failures only** (timeout, 429, 5xx) with backoff + jitter — never retry a 4xx validation/content error. The retry/backoff/circuit-breaker *mechanics* are distributed-systems concerns; the gateway is where you *apply* them to provider calls — reference that pack, don't re-derive the algorithm here.

## Caching

- **Exact-match cache** keyed on `(model, normalized prompt, params)` — deterministic calls (temp 0 extraction/classification) are highly cacheable; big hit-rate for free.
- **Semantic cache** keyed on embedding similarity of the request — returns a prior answer for a near-duplicate query. Powerful but risky: set a strict similarity threshold and never semantic-cache across tenants or across permission scopes (a cross-tenant cache hit is a data leak).
- **Provider prompt-caching:** when a large stable prefix (system prompt, tool schemas, a long document) repeats across calls, mark it so the provider caches the prefix — cuts input cost and latency on the repeated portion. Order context stable-prefix-first to maximize hits.
- **Cache invalidation + TTL:** version the cache key by prompt version + model; a prompt or model change MUST NOT serve stale cached answers.

## Cost + latency budget

- **Per-call:** a hard timeout and a `max_output_tokens` cap on every call — the two knobs that bound tail latency and worst-case cost.
- **Per-feature accounting:** attribute cost to a feature/tenant/request via the gateway's logging so cost is a dashboard number, not a month-end surprise. Enforce a budget/ceiling where a runaway is possible (esp. agent loops — see `agent-design`).
- **Right-size the model:** the cheapest model that passes the eval set wins; don't default to the biggest model.

## Streaming

- **Stream tokens** to the client for perceived latency on long generations (first-token-time dominates UX). The gateway exposes a streaming interface, not just request/response.
- **Mid-stream errors are real:** a stream can fail after emitting partial output. Handle it — surface a clean error, don't leave a half-message as if complete; make the operation safe to retry.
- Streaming + tool-calling: the gateway assembles streamed tool-call deltas before dispatching the tool.

## Observability

- **Log every call:** model id, prompt version, input+output tokens, cost, latency, finish reason, cache hit/miss, fallback-fired, request/tenant id — **trace-linked** so an LLM call is a span inside the request's trace.
- **Redact PII/secrets** before logging prompt/response — the gateway is the one place to enforce it, so redaction can't be forgotten per-site. Never log raw secrets/keys.
- The metric/trace *design* (RED, cardinality budgets, sampling, audit-log) is owned by the **observability** pack — the gateway is the emit point, not the spec. Reference it; don't duplicate the taxonomy here.

## Detectors (cite-or-halt)

- Provider SDK imported/called from feature code instead of the gateway seam → `route-through-gateway`.
- A model call with no timeout or no `max_output_tokens` cap → `add-call-budget`.
- A single-provider production path with no fallback model/provider on outage → `add-fallback` (or document accepted risk).
- Repeated identical large context with no exact/prompt caching → `add-prompt-cache`.
- A semantic cache with no tenant/permission scoping in the key → `scope-semantic-cache` (data-leak risk).
- A model call not logging tokens + cost + latency + model id (trace-linked) → `add-cost-logging`.
- Prompt/response logged without PII/secret redaction → `add-log-redaction`.

**Closure verbs:** `route-through-gateway`, `add-call-budget`, `add-fallback`, `add-prompt-cache`, `scope-semantic-cache`, `add-cost-logging`, `add-log-redaction`.

## Related

- **Patterns (in-pack):** `agent-design` (agent tool/model calls route through the gateway; loop budgets sit on top of per-call budgets), `prompt-engineering` (prompt versioning drives cache-key + structured-output config), `evals` (routing/model choice is validated by the eval set), `rag-pipeline` (retrieved context is what prompt-caching amortizes).
- **Rule (in-pack):** `ai-engineering-principles` (no scattered provider-SDK calls; every call has a token cap + timeout + traced cost).
- **Cross-pack owners (referenced, not duplicated):** timeout/retry/backoff/circuit-breaker/bulkhead mechanics → **distributed-systems** / **backend** resilience (the gateway *applies* them, doesn't own them); RED metrics, trace design, cardinality/sampling, audit-log, PII-redaction policy → **observability** (`tracing`, `structured-logging`, `audit-logging`); secret handling + prompt-injection/output-handling → **security** `@llm-security-reviewer`.
