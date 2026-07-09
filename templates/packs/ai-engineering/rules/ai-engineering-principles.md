---
name: ai-engineering-principles
description: AI / LLM Engineering Principles
kind: rule
pack: ai-engineering
severity: must
applies-to: ai-engineering-track, every-code-writing-task-touching-an-llm
---

# AI / LLM Engineering Principles

> **Hard rule.** Model output and retrieved content are UNTRUSTED input — validate/encode them before you use, render, execute, or persist them. Every LLM feature ships with a regression-gating **eval set** (no eval, no ship). Every LLM call has a **token cap + timeout + traced cost**. Structured output comes from a **schema / tool-calling** mechanism, never regex over free text. No provider SDK is called outside the **gateway** seam; no agent loop runs without a budget.

Provider-agnostic (see `STACK.md`). This pack **builds** LLM features; the **security** pack's `@llm-security-reviewer` **secures** them (prompt injection, output handling, excessive agency) — the two are complementary, not duplicative.

Prevents the recurring LLM-feature failures: model output piped into a sink unescaped, features shipped with no eval so quality regresses silently, uncapped calls that blow cost/latency, regex-parsed completions that break on format drift, cross-tenant RAG leaks, and unversioned prompts nobody can reproduce.

## Must

- **Treat model output + retrieved content as untrusted.** Validate against a schema and encode/escape for the destination sink (HTML, SQL, shell, `eval`, file path, deserializer, another prompt) before use. This is the #1 defect class — cross-ref **security** `@llm-security-reviewer` LLM05 (Improper Output Handling) + LLM01 (Prompt Injection). (AI-1)
- **Every LLM feature has a regression-gating eval set** run in CI; a change that drops a scorer below its threshold does not ship. See `ai/patterns/evals.md`. No eval harness ⇒ the feature is unshippable, not "done later". (AI-2)
- **Every LLM call has a token cap + timeout + traced cost.** A `max_output_tokens` bound, a wall-clock timeout, and per-call cost logged trace-linked. Cost/latency are budgeted, not discovered at month-end. See `ai/patterns/llm-gateway.md`. (AI-3)
- **Structured output via schema / tool-calling — never regex over free text.** Use the provider's JSON-schema / structured-output / function-calling mode; validate the returned object. Regex-parsing a completion is a format-drift time bomb. See `ai/patterns/prompt-engineering.md`. (AI-4)
- **Temperature 0 (or near) for extraction / classification / routing** — any task with a single correct answer. Reserve higher temperature for genuinely generative surfaces. Don't claim determinism you didn't configure. (AI-5)
- **RAG retrieval is tenant / permission-filtered AND quality-eval'd.** The retrieval query carries the caller's tenant + ACL scope so no user is served another's documents; retrieval quality (recall/precision/faithfulness) is measured, not assumed. See `ai/patterns/rag-pipeline.md` + `@llm-security-reviewer` LLM08. (AI-6)
- **Prompts are versioned code** — checked in, reviewed, diffable, tied to a version id that flows into logs + cache keys + eval runs. A prompt change is a code change with an eval run, not an untracked edit. (AI-7)
- **All provider calls go through the gateway seam** — one place owns retry, fallback, caching, cost, redaction. See `ai/patterns/llm-gateway.md`. (AI-8)
- **Redact PII/secrets before sending to a provider or writing to logs** — the gateway enforces it once so no call site can forget. (AI-9)

## Must not

- **No provider-SDK calls scattered across feature code.** A direct `openai`/`anthropic`/`google-genai`/vLLM call outside the gateway can't be given a timeout, retry, cache, fallback, or cost number without touching every site. (AI-8)
- **No unbounded agent loop.** An act→observe→re-plan loop with no max-steps / token / cost / timeout budget is a runaway cost/incident. See `ai/patterns/agent-design.md`. (AI-3)
- **No effectful tool (write/delete/spend/send/execute) without a confirmation-or-policy gate** — an unguarded destructive tool is Excessive Agency (LLM06). (AI-1)
- **No secrets / PII in prompts or logs.** Mask, hash, or omit. (AI-9)
- **No regex / string-slicing to extract structured data** where the provider offers schema/tool-calling. (AI-4)
- **No over-claims about determinism.** LLM calls are not "exactly-once" or byte-reproducible; caching, model updates, and sampling all vary output. Don't promise reproducibility the runtime can't give. (AI-5)
- **No shipping an LLM feature on vibes** — "it looked good in the demo" is not an eval. (AI-2)

## Should

- **Model cascade:** try the cheapest model that passes the eval set; escalate to a stronger model only on failure. Right-size per task; don't default to the biggest model. (AI-3)
- **Fallback model/provider** on outage/overload so the feature survives a single vendor's incident. (AI-8)
- **Cache repeated context** (exact-match + provider prompt-caching; semantic cache only with tenant/permission-scoped keys). (AI-3)
- **Stream tokens** for long generations (perceived latency); handle mid-stream errors. (AI-3)
- **Make tool errors recoverable** — a failing tool returns a structured error the model can read and route around, not an exception that crashes the loop. (AI-1)
- **Compact context across agent steps** — summarize/externalize instead of unbounded growth. See `ai/patterns/agent-design.md`. (AI-3)
- **Golden-set + adversarial cases in the eval** — include known-hard, injection, and edge inputs, not just happy paths. (AI-2)
- **Human-in-the-loop on irreversible / high-value actions** (delete, payment, external send, prod write) — approve-then-execute with an audit trail. (AI-1)

## Review checklist

- [ ] Model output + retrieved content validated/encoded before any sink (render/query/exec/persist/re-prompt). (AI-1)
- [ ] New/changed LLM feature has an eval set wired into CI with thresholds. (AI-2)
- [ ] Every LLM call carries a token cap + timeout + trace-linked cost log. (AI-3)
- [ ] Structured output uses schema/tool-calling and the result is schema-validated — no regex. (AI-4)
- [ ] Extraction/classification/routing runs at temperature 0. (AI-5)
- [ ] RAG retrieval filters by tenant + permission AND has a retrieval-quality eval. (AI-6)
- [ ] Prompt is versioned; version id flows to logs + cache key + eval run. (AI-7)
- [ ] All provider calls go through the gateway; no scattered SDK calls. (AI-8)
- [ ] Agent loop has a max-steps + token + cost + timeout budget; effectful tools are gated. (AI-3, AI-1)
- [ ] No secrets/PII in prompts or logs; redaction enforced at the gateway. (AI-9)

## Enforcement

- **Eval CI gate:** the eval suite runs on every PR touching an LLM path; a threshold regression fails the build (no merge). (AI-2)
- **Cost/latency dashboard + budget alerts:** per-feature/tenant token + cost + latency tracked from the gateway; a runaway trips an alert. (AI-3)
- **Lint/grep gate for the gateway boundary:** ban provider-SDK imports outside the gateway module (dependency-cruiser / eslint import-boundaries / a CI grep). (AI-8)
- **Secret/PII scanners** (`gitleaks`, log-redaction tests) on prompt + log paths. (AI-9)
- **Security review hook:** an LLM-touching PR routes to `@llm-security-reviewer` for the LLM01/05/06/08 sweep. (AI-1)

## Related

- **Patterns (in-pack):** `evals` (regression gate — the load-bearing foundation), `rag-pipeline` (tenant-filtered, quality-eval'd retrieval), `prompt-engineering` (structured output, versioned prompts), `agent-design` (autonomy choice, tool gates, loop budgets, human-in-loop), `llm-gateway` (routing, fallback, caching, cost, streaming, observability).
- **Cross-pack owners (referenced, not duplicated — resolve when co-installed):** prompt injection / improper output handling / excessive agency / vector-store ACL → **security** `@llm-security-reviewer` (LLM01/05/06/08); trace-linked call logging, cost/latency metrics, cardinality/sampling, audit trail, PII-redaction policy → **observability** (`observability-principles`, `tracing`, `audit-logging`); timeout/retry/backoff/circuit-breaker/bulkhead mechanics the gateway applies → **distributed-systems** / **backend** resilience.
