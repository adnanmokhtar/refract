---
name: llm-gateway-audit
description: Inventories the provider-call surface and audits the seam — every provider-SDK import/call outside the gateway module (enumerated individually, never "and N others"), calls with no timeout or no max-output-token cap, a single-provider production path with no fallback, repeated large identical context with no exact/prompt caching, a semantic cache whose key is not tenant/permission-scoped, calls not logging model id + prompt version + tokens + cost + latency trace-linked, and prompt/response logging with no PII/secret redaction. Emits the seam inventory (N call sites, M behind the seam) plus one finding per site with its closure verb. TRIGGER — before adding retry/caching/fallback/cost-tracking, when cost or p95 latency is a question, any diff adding a provider call, and dispatched by /ai-audit and @ai-feature-reviewer dimension 5. ANTI-TRIGGERS (do NOT fire) — deriving retry/backoff/circuit-breaker algorithms (distributed-systems / backend own the mechanics; this audits their application to provider calls); the metric/trace taxonomy, cardinality budgets, or PII-redaction policy (observability owns those — this checks the redaction call is on this path); secret scanning (secret-scan); projecting a dollar saving or a cache hit-rate (this skill reports measured or configured facts only).
kind: skill
pack: ai-engineering
---

# Skill: llm-gateway-audit

## Premise

One internal seam owns every provider call, or nothing does. A gateway that half the codebase bypasses cannot be given a timeout, a cache, a fallback, or a cost number without touching every site — so the first output of this skill is not a finding at all, it is an **inventory**: how many provider call sites exist, and how many are behind the seam.

**Every finding cites `<path:line>` + a real 1-line excerpt + the closure verb.** Bypass sites are **enumerated individually** — `chat.ts:12`, `titles.ts:8`, `summary.py:44` — never "and 5 others". A count is not a citation, and "several call sites" is the exact hand-wave this skill exists to replace with a list.

**This skill reports measured or configured facts.** A call-site count, a present-or-absent timeout, a cap value, whether a cost field is written. It does **not** emit a projected dollar saving, a hypothetical cache hit-rate, or a "this would cut cost ~40%" figure. Where the project's own telemetry supplies a number, cite it with its source; otherwise the value is `UNMEASURED` and the finding names what would settle it.

## Adapt to the codebase

Find the seam before judging the sites. Detect from `_extracted-codebase.md § AI/LLM integration`, then confirm by reading:

| What to find | How to find it | What it tells you |
|---|---|---|
| **The gateway module** | a house `llm/`, `ai/client`, `gateway`, `model-client` module; or an OSS proxy/router the project runs; or **none** | the seam's path — every other provider call is a bypass |
| **Provider SDK imports** | the project's package manifest + `rg -n "anthropic\|openai\|google.genai\|mistralai\|cohere\|bedrock\|vertexai\|ollama\|litellm\|openrouter"` | the bypass candidates, one line each |
| **Timeout + cap conventions** | how the seam sets them (client-level default, per-call kwarg, an HTTP-client timeout, a framework config) | whether a call-site absence is really an absence or a seam default |
| **Cost/telemetry sink** | the project's logger / metrics client / tracer, and whether the LLM call is a span inside the request trace | where a cost field would be written, and whether it is |
| **Redaction primitive** | the project's own scrubber / masker / allow-list on the log path | what the finding should call for — never a second redaction library |
| **Cache layer** | an exact-match store, a semantic cache, or provider prompt-caching markers on a stable prefix | which of the three caching findings can even apply |

If the project runs a mature OSS gateway/proxy, the seam is that proxy's client — a call that bypasses the proxy is still a bypass. Mirror the project's mechanism; the pattern is the *seam*, not bespoke code.

## When to run

- Before adding retry, caching, fallback, routing, or cost tracking to anything — the inventory tells you whether there is one place to add it.
- When cost or p95 latency is the question, as the *configuration* half (the measurement half is the project's telemetry).
- On any diff that adds a provider call or a new provider dependency.
- Dispatched by `/ai-audit` (gateway/cost axis) and `@ai-feature-reviewer` (dimension 5, cost/latency).
- NOT for deriving the backoff algorithm, the circuit-breaker policy, or the bulkhead sizing — those belong to the distributed-systems / backend resilience surface. This skill checks they are *applied* to the provider call, not what they should be.

## The seven detectors

### 1. Provider SDK called outside the seam → `route-through-gateway`

**Fingerprint:** a provider SDK import or client construction in feature/business code.

- BAD: `const client = new <ProviderSDK>()` inside a request handler, with its own ad-hoc retry.
- GOOD: the handler calls the gateway module; the SDK is constructed once, inside it.

Enumerate every site. If the project has **no** seam at all, that is one finding — `route-through-gateway` on the whole surface, with the sites listed as its evidence — not N findings.

### 2. No timeout or no output-token cap → `add-call-budget`

**Fingerprint:** a model call with no wall-clock timeout, or no `max_tokens` / `max_output_tokens` equivalent.

- BAD: a generation call with neither; a hung provider hangs the request and a runaway completion is unbounded spend.
- GOOD: both set at the seam, overridable per call, with the value visible in the log line.

These are the two knobs that bound tail latency and worst-case cost. Check the seam's default before reporting a call-site absence, and cite whichever layer actually decides. Severity BLOCKER on a user-facing generation.

### 3. Single-provider production path, no fallback → `add-fallback`

**Fingerprint:** one model/provider on the production path with no secondary on timeout / 5xx / overloaded / 429.

- BAD: the only path is one vendor's endpoint; the feature's uptime is that vendor's uptime.
- GOOD: `primary → secondary (different model/provider)` on transient classes, with prompts portable enough to run on the fallback — **or** the accepted risk documented where a single provider is a deliberate constraint.

The documented-accepted-risk form is a legitimate close, not a dodge. Cite the decision record when it exists; report its absence when it does not.

### 4. Repeated large identical context, no caching → `add-prompt-cache`

**Fingerprint:** a large stable prefix — the same system prompt, tool schemas, or a long document — re-sent on every call with no exact-match cache and no provider prompt-cache marking.

- BAD: a 4k-token instruction block assembled fresh per request, unordered, unmarked.
- GOOD: stable-prefix-first ordering, provider prompt-caching marked on the prefix, and/or an exact-match cache keyed on `(model, normalized prompt, params)`.

Report the prefix's **measured size** if the project's telemetry has it, otherwise report the site and mark the saving `UNMEASURED — a token count on the gateway log line would settle it`. Never state a hit-rate you did not read.

### 5. Semantic cache not tenant/permission-scoped → `scope-semantic-cache`

**Fingerprint:** a similarity-keyed cache whose key omits `tenant_id` / the caller's permission scope.

- BAD: an embedding-similarity cache shared across tenants — a near-duplicate query returns another tenant's answer.
- GOOD: tenant and permission scope in the key (or a per-tenant partition), plus a strict similarity threshold.

This is a data-leak shape. Report the engineering defect here **and hand the leak to `@llm-security-reviewer`** (and `@tenant-isolation-reviewer` where the pack is installed) — do not clear it yourself.

### 6. Call not logging model + prompt version + tokens + cost + latency, trace-linked → `add-cost-logging`

**Fingerprint:** a call whose log/metric line omits any of: model id, prompt version, input+output tokens, derived cost, latency, finish reason, cache hit/miss, fallback-fired, tenant/request id — or one that is not a span inside the request's trace.

- BAD: `logger.info("llm ok")`. The feature is financially unobservable and cost is un-attributable.
- GOOD: one structured line at the seam carrying the full set, trace-linked so the call is a span in the request.

The metric/trace *taxonomy* (names, cardinality budget, sampling) is observability's; this detector only asserts the fields exist on this path. Say which are present and which are missing — a partial line is a REQUEST, not a pass.

### 7. Prompt/response logged with no redaction → `add-log-redaction`

**Fingerprint:** raw prompt or completion text written to a persisted log, or user PII flowing to the provider with no scrub, on a path with no redaction call.

- BAD: `logger.debug(prompt)` where the prompt carries user email/address/free-text.
- GOOD: the seam redacts before the provider call and before any log write — one enforceable point, so no call site can forget it.

A persisted **secret** is a BLOCKER. Redaction *policy* (what counts as PII, retention) is observability/security's; the *presence of the call on this path* is this detector's. Cross-check `secret-scan` where the security pack is installed rather than duplicating it.

## Output

```
llm-gateway-audit — <scope>

Seam inventory:
  Gateway module:  src/llm/gateway.ts          (exists)
  Call sites:      7 total — 4 behind the seam, 3 bypassing
  Providers:       1 (single-provider production path)
  Cache:           exact-match present; semantic none; provider prompt-cache not marked
  Telemetry:       tokens ✓  cost ✗  latency ✓  model id ✓  prompt version ✗  trace-linked ✓

Findings (6):
  BLOCKER  route-through-gateway   src/chat/handler.ts:12   `const client = new <SDK>()`
           Constructs its own client + retry; no shared cache, cost, or fallback.
  BLOCKER  route-through-gateway   src/titles/generate.ts:8 `new <SDK>({ apiKey })`
  BLOCKER  route-through-gateway   scripts/backfill.py:44   `client = <SDK>()`
  BLOCKER  add-call-budget         src/chat/handler.ts:18   `messages.create({ model, messages })`
           No timeout and no output-token cap; seam default does not apply to a bypassing call.
  REQUEST  add-fallback            src/llm/gateway.ts:61    `return primary.call(req)`
           Single provider, no secondary on timeout/5xx/429, no documented accepted risk.
  REQUEST  add-cost-logging        src/llm/gateway.ts:88    `logger.info("llm", { model, ms })`
           Tokens + cost + prompt version absent; spend is not attributable per feature or tenant.

Handed to @llm-security-reviewer:
  - (none this run — no semantic cache; no raw prompt reaches a persisted log)

Cost: UNMEASURED. No cost field is written at the seam, so no spend figure exists to report.
      What would settle it: add the token+cost fields (add-cost-logging), then one day of traffic.
```

## False positives / gotchas

- **A one-off script or a single call site is not a gateway violation.** The pattern says don't build a routing engine for one prompt — but it still owes a timeout and a cap. Grade `route-through-gateway` `N-A` there and keep detector 2.
- **A seam-level default can satisfy a call site.** Timeouts and caps are often set once on the client. Read the seam before reporting an absence, and cite the layer that decides.
- **Tests, fixtures, and eval harnesses call the SDK directly on purpose.** Exclude `tests/`, `evals/`, and notebook paths from the bypass inventory, and say you excluded them.
- **A framework wrapper may already be the seam.** If every call goes through one wrapper that owns retry/cost/caching, that wrapper *is* the gateway — report it as the seam rather than flagging the wrapper's own SDK import.
- **Retry is not fallback.** Retrying the same model on a 429 is not a fallback chain; and retrying a 4xx content error is a defect the distributed-systems pack owns. Don't merge the two findings.
- **Streaming calls still owe a cap and a timeout**, and their cost is logged *after* the stream completes — a stream with no post-completion cost line is a detector-6 finding, not an exemption.
- **Provider prompt-caching needs a stable prefix.** Reporting `add-prompt-cache` on a prompt whose first token varies per request is wrong — the finding there is the *ordering* (stable-prefix-first), not the cache.

## Halt conditions

- **A bypass finding written as a count** (`5 call sites bypass the gateway`) without each site enumerated at `<path:line>` → not emittable. Enumerate or drop.
- **The hand-wave grep** — `etc.` / `…` / `several similar` / `N+ others` / `consider` / `might` / `probably` in a draft finding → STOP and re-enumerate.
- **A projected saving, a hypothetical hit-rate, or an invented cost figure** → forbidden. Report `UNMEASURED` plus the one change that would produce the number. This skill has no benchmark and must not imply one.
- **No seam and no provider call found** → report `N-A — no provider call on this surface`, not a clean pass. A green verdict on an unexamined surface is the failure this line prevents.
- **Deriving the retry/backoff/circuit-breaker policy** → out of scope; name the distributed-systems / backend owner and stop.
- **Clearing a cross-tenant cache leak** → forbidden. Detector 5 hands to `@llm-security-reviewer`; report the defect, route the leak.

## References

- `ai/patterns/llm-gateway.md` — the pattern this skill mechanizes: the responsibilities table, cascade routing, fallback chains, the three caching modes, per-call budget, streaming, observability. Owner of the *what*; this skill is the *find it*.
- `prompt-audit` — sibling skill on the same call sites: it audits what is *inside* the call (schema, roles, temperature, version); this one audits the seam around it. A cache key unversioned by prompt version is both findings at once.
- `ai/patterns/evals.md` + `eval-run` — right-sizing the model ("the cheapest model that passes the eval") is a routing decision this skill can only report as *unproven* without a harness; `/add-eval-set` builds one.
- `@ai-feature-reviewer` — dispatches this skill for dimension 5 and folds its findings into the PR verdict.
- `@llm-security-reviewer` (security pack) — owns the semantic-cache leak and the secret-in-log exposure; detectors 5 and 7 hand across.
- **Cross-pack owners (referenced, not duplicated):** timeout/retry/backoff/circuit-breaker mechanics → distributed-systems / backend resilience; metric + trace taxonomy, cardinality, sampling, PII-redaction policy → observability.
- `.claude/rules/ai-engineering-principles.md` — AI-3 (token cap + timeout + traced cost), AI-8 (one gateway seam), AI-9 (redaction at the seam).
