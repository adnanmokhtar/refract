---
name: llm-gateway-audit
kind: example
pack: ai-engineering
description: Seam inventory + seven gateway detectors — bypassing SDK calls (enumerated), missing timeout/cap, no fallback, no caching, unscoped semantic cache, missing cost logging, missing redaction.
---

# Skill: llm-gateway-audit

## Premise

One internal seam owns every provider call, or nothing does. The first output is not a finding — it is an **inventory**: how many provider call sites exist, how many are behind the seam.

**Every finding cites `<path:line>` + a real excerpt + its closure verb, and bypass sites are enumerated individually** — never "and 5 others". **This skill reports measured or configured facts only**: call-site counts, present/absent timeouts, cap values, whether a cost field is written. No projected saving, no hypothetical hit-rate. Where the project's telemetry has a number, cite it with its source; otherwise `UNMEASURED` + what would settle it.

## Adapt to the codebase

Find the seam before judging the sites: the gateway module (a house `llm/` client, an OSS proxy, or none) · provider SDK imports from the manifest · how timeouts + caps are set (client default vs per call) · the logger/metrics/tracer sink · the project's own redaction primitive · which cache layers exist. Mirror the project's mechanism; the pattern is the *seam*, not bespoke code.

## When to run

- Before adding retry / caching / fallback / cost tracking; when cost or p95 latency is the question; on any diff adding a provider call; dispatched by `/ai-audit` and `@ai-feature-reviewer` dim 5.
- NOT for deriving backoff / circuit-breaker policy (distributed-systems / backend own the mechanics — this audits their application).

## The seven detectors

1. **SDK called outside the seam** → `route-through-gateway`. Enumerate every site. No seam at all = ONE finding with the sites as evidence, not N.
2. **No timeout or no output-token cap** → `add-call-budget`. The two knobs bounding tail latency and worst-case cost. Check the seam default first; cite the deciding layer. BLOCKER on a user-facing generation.
3. **Single provider, no fallback** → `add-fallback` on timeout / 5xx / overloaded / 429 — or a documented accepted risk, which is a legitimate close. Cite the decision record or its absence.
4. **Repeated large identical context, no caching** → `add-prompt-cache`: stable-prefix-first ordering, provider prompt-caching, and/or an exact-match cache keyed on `(model, normalized prompt, params)`. **Measure the prefix against the model's minimum cacheable size first** — provider caches have a model-dependent floor (and it does not move monotonically across a vendor's generations), below which nothing caches *and no error is raised*. Below the floor the finding is not `add-prompt-cache` — it is that no cache is possible at this prefix size; consolidate the stable content or close the site `N-A` citing both the measured size and the floor. Prefix size unknown → `UNMEASURED`, never an asserted saving. There is also a per-request cache-breakpoint ceiling; exceeding it errors.
5. **Semantic cache not tenant/permission-scoped** → `scope-semantic-cache`. A data-leak shape — report the defect, **hand the leak to `@llm-security-reviewer`**.
6. **No model id + prompt version + tokens + cost + latency, trace-linked** → `add-cost-logging`. Say which fields are present; a partial line is REQUEST, not a pass. The taxonomy is observability's; presence on this path is yours.
7. **Prompt/response logged with no redaction** → `add-log-redaction`. A persisted secret is a BLOCKER. Policy is observability/security's; the call on this path is yours.

## Output

```
llm-gateway-audit — <scope>

Seam inventory: gateway=src/llm/gateway.ts · 7 call sites, 4 behind the seam, 3 bypassing
  Cache: exact-match ✓ · semantic none · provider prompt-cache unmarked
  Telemetry: tokens ✓ cost ✗ latency ✓ model ✓ prompt-version ✗ trace-linked ✓

BLOCKER route-through-gateway  chat/handler.ts:12 · titles/generate.ts:8 · scripts/backfill.py:44
BLOCKER add-call-budget        chat/handler.ts:18 — no timeout, no cap; seam default does not reach a bypass
REQUEST add-fallback           llm/gateway.ts:61 — single provider, no documented accepted risk
REQUEST add-cost-logging       llm/gateway.ts:88 — tokens+cost+prompt version absent; spend unattributable

Cost: UNMEASURED — no cost field at the seam. Settles with add-cost-logging + one day of traffic.
```

## False positives / gotchas

- A one-off script is not a gateway violation (`route-through-gateway` = `N-A`) but still owes a timeout + cap.
- A seam-level default can satisfy a call site — read it and cite the deciding layer.
- Tests, fixtures, and eval harnesses call the SDK directly on purpose; exclude them and say so.
- A framework wrapper that owns retry/cost/caching **is** the seam.
- Retry ≠ fallback; retrying a 4xx is a different (distributed-systems) defect.
- Streaming calls still owe a cap + timeout, and log cost after the stream.
- `add-prompt-cache` on a prompt whose prefix varies is wrong — the finding is the *ordering*. Likewise on a prefix under the model's minimum cacheable size: the marking would be silently inert, so the finding is the size, not the absence.
- A prefix already marked but reporting zero cache reads across identical repeats is its own finding — either it is under the floor, or something inside it varies per request (a timestamp, an unsorted map, a rotating tool list). Name which, from the bytes.

## Halt conditions

- A bypass count without every site enumerated → not emittable.
- Hand-wave grep (`etc.` / `several similar` / `probably`) → STOP and re-enumerate.
- **A projected saving, hypothetical hit-rate, or invented cost figure** → forbidden; report `UNMEASURED` + the one change that produces it.
- No seam and no provider call → `N-A`, not a clean pass.
- Deriving retry/backoff policy, or clearing a cross-tenant cache leak → route it.

## References

- `ai/patterns/llm-gateway.md` (the pattern); `prompt-audit` (inside the same calls); `eval-run` (right-sizing is unproven without a harness); `@ai-feature-reviewer` dim 5; `@llm-security-reviewer`; cross-pack: distributed-systems (retry mechanics), observability (metric/trace taxonomy, redaction policy); `.claude/rules/ai-engineering-principles.md` (AI-3/8/9).
