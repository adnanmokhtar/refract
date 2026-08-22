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

Provider-agnostic (see `STACK.md`). This pack **builds** LLM features; the **security** pack's `@llm-security-reviewer` **secures** them — complementary, not duplicative. OWASP-LLM ids are the **2026** edition; where an id moved from 2025 both are given, because a receiving reviewer treats a remembered 2025 number as a defect in itself.

## Must

- **Treat model output + retrieved content as untrusted.** Validate against a schema and encode/escape for the destination sink (HTML, SQL, shell, `eval`, file path, deserializer, another prompt) before use. The #1 defect class — cross-ref `@llm-security-reviewer` LLM10:2026 Improper Output Handling (LLM05:2025) + LLM01:2026 Prompt Injection. (AI-1)
- **Every LLM feature has a regression-gating eval set** run in CI; a change that drops a scorer below its threshold does not ship. No eval harness ⇒ unshippable, not "done later". See `ai/patterns/evals.md`. (AI-2)
- **Every LLM call has a token cap + timeout + traced cost** — a `max_output_tokens` bound, a wall-clock timeout, per-call cost logged trace-linked. Budgeted, not discovered at month-end. See `ai/patterns/llm-gateway.md`. (AI-3)
- **Structured output via schema / tool-calling — never regex over free text.** Use the provider's JSON-schema / structured-output / function-calling mode, and its *strict* variant where one exists; validate the returned object regardless. Regex-parsing a completion is a format-drift time bomb. See `ai/patterns/prompt-engineering.md`. (AI-4)
- **Constrain single-answer tasks (extraction, classification, routing, tool args) with the mechanism the provider actually exposes — and check which that is.** Where sampling parameters exist, set `temperature: 0` (+ seed where supported). Where the provider **removed** them, setting one *is* the defect: a non-default `temperature`/`top_p`/`top_k` returns **HTTP 400** on current Anthropic models (Opus 4.7+, Sonnet 5, Fable 5 — [Sonnet 5 release notes](https://platform.claude.com/docs/en/about-claude/models/whats-new-sonnet-5), read 2026-08-23), and the controls become the schema-constrained mode (AI-4) plus system-prompt instruction. Read the provider's current parameter reference before writing a sampling parameter — a removed parameter is an error, not a no-op. Temperature 0 was never determinism; don't claim reproducibility the runtime can't give. (AI-5)
- **RAG retrieval is tenant / permission-filtered AND quality-eval'd.** The query carries the caller's tenant + ACL scope; retrieval quality (recall/precision/faithfulness) is measured, not assumed. See `ai/patterns/rag-pipeline.md` + `@llm-security-reviewer` LLM09:2026 Vector & Embedding Weaknesses (LLM08:2025). (AI-6)
- **Prompts are versioned code** — checked in, reviewed, diffable, tied to a version id that flows into logs + cache keys + eval runs. A prompt change is a code change with an eval run. (AI-7)
- **All provider calls go through the gateway seam** — one place owns retry, fallback, caching, cost, redaction. (AI-8)
- **Redact PII/secrets before sending to a provider or writing to logs** — enforced once at the gateway so no call site can forget. (AI-9)

## Must not

- **No provider-SDK calls scattered across feature code.** A direct call outside the gateway can't be given a timeout, retry, cache, fallback, or cost number without touching every site. (AI-8)
- **No unbounded agent loop.** Act→observe→re-plan with no max-steps / token / cost / timeout budget is a runaway incident. See `ai/patterns/agent-design.md`. (AI-3)
- **No effectful tool (write/delete/spend/send/execute) without a confirmation-or-policy gate** — that is Excessive Agency (LLM03:2026, promoted from LLM06:2025). (AI-1)
- **No secrets / PII in prompts or logs.** Mask, hash, or omit. (AI-9)
- **No regex / string-slicing to extract structured data** where the provider offers schema/tool-calling. (AI-4)
- **No undated provider-behaviour claim.** A parameter name, context limit, price, model id, rate ceiling or API shape written into a prompt, doc, or review comment carries the date it was checked and where. Provider surfaces are withdrawn without notice and a remembered one becomes a runtime error; an undated claim can never be re-checked, so it is never retired. (AI-5)
- **No shipping an LLM feature on vibes** — "it looked good in the demo" is not an eval. (AI-2)

## Should

- **Model cascade:** try the cheapest model that passes the eval set; escalate only on failure. Don't default to the biggest. (AI-3)
- **Fallback model/provider** on outage/overload so the feature survives one vendor's incident. (AI-8)
- **Cache repeated context** (exact-match + provider prompt-caching; semantic cache only with tenant-scoped keys). Provider caches have a **minimum cacheable prefix** and a **breakpoint ceiling** — below the minimum nothing caches and *no error is raised*, so read the current limits for the model in use before claiming a cache saves anything. (AI-3)
- **Stream tokens** for long generations; handle mid-stream errors. (AI-3)
- **Tools are the model's API: design them so the wrong call is hard to make.** An argument shape the model cannot get wrong beats validation that rejects it afterwards; a failing tool returns a structured error the model can read and route around, never an exception that crashes the loop. Names and descriptions are routing surface — budget review effort on them as you would on a public API. (AI-1)
- **Exercise an autonomous loop in a sandbox before production** — a disposable workspace, real tool contracts, no real effects. Reading a trajectory is how tool-design and budget defects surface; they do not appear in a unit test. (AI-1, AI-2)
- **Compact context across agent steps** — summarize/externalize instead of unbounded growth. (AI-3)
- **Golden-set + adversarial cases in the eval** — known-hard, injection, and edge inputs, not just happy paths. (AI-2)
- **Human-in-the-loop on irreversible / high-value actions** (delete, payment, external send, prod write) — approve-then-execute with an audit trail. (AI-1)
- **Fine-tuning is the last resort** — after prompting and RAG are exhausted, for a *measurable* gap they can't close, and only if it beats the prompted baseline on a held-out eval. Never to inject knowledge; that's RAG's job. See `ai/patterns/fine-tuning.md`. (AI-2)
- **The vector index is tuned to a stated recall/latency/scale target** — algorithm, parameters and target declared and measured against a retrieval eval, never library-defaulted; the distance metric matches the embedding model. See `ai/patterns/vector-store-ops.md`. (AI-6)

## Enforcement

- **Standing sweep:** `/ai-audit` audits AI-1…AI-9 across six axes, dispatching the pack's detector skills and routing the trust boundary to `@llm-security-reviewer`. It may never print a green verdict while the eval axis is UNVERIFIED.
- **Mechanical checks:** `prompt-audit` (AI-4/5/7), `llm-gateway-audit` (AI-3/8/9), `vector-index-audit` + `retrieval-eval` (AI-6 — the audit reports whether a recall target was declared, the eval produces the number, neither invents one).
- **No harness ⇒ retrofit, not a waiver:** when `eval-run` HALTs, `/add-eval-set <feature>` builds the gate. Until that first measured run exists the eval axis is UNVERIFIED. (AI-2)
- **Eval CI gate:** the suite runs on every PR touching an LLM path; a threshold regression fails the build. (AI-2)
- **Cost/latency dashboard + budget alerts:** per-feature/tenant token + cost + latency from the gateway; a runaway trips an alert. (AI-3)
- **Lint/grep gate for the gateway boundary:** ban provider-SDK imports outside the gateway module. (AI-8)
- **Secret/PII scanners** (`gitleaks`, log-redaction tests) on prompt + log paths. (AI-9)
- **Security review hook:** an LLM-touching PR routes to `@llm-security-reviewer` for the LLM01:2026 / LLM03:2026 / LLM09:2026 / LLM10:2026 sweep. (AI-1)

## Related

- **Cross-pack owners (referenced, not duplicated — resolve when co-installed):** prompt injection / improper output handling / excessive agency / vector-store ACL → **security** `@llm-security-reviewer` (LLM01:2026 / LLM10:2026 / LLM03:2026 / LLM09:2026); trace-linked call logging, cost/latency metrics, cardinality/sampling, audit trail, PII-redaction policy → **observability**; timeout/retry/backoff/circuit-breaker mechanics the gateway applies → **distributed-systems** / **backend** resilience. Per-call token budget is AI-3 here; the **finops** pack owns the bill, not this rule.
