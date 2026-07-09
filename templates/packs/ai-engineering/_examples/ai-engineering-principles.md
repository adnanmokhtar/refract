---
name: ai-engineering-principles
kind: example
pack: ai-engineering
---

# AI / LLM Engineering Principles

Provider-agnostic (see `STACK.md`). This pack **builds** LLM features; **security** `@llm-security-reviewer` **secures** them (injection / output handling / excessive agency).

Prevents the recurring LLM failures: model output piped to a sink unescaped, features shipped with no eval so quality regresses silently, uncapped calls that blow cost/latency, regex-parsed completions, cross-tenant RAG leaks, unversioned prompts.

## Must

- Treat model output + retrieved content as **untrusted** — validate against a schema + encode for the sink (HTML/SQL/shell/`eval`/path/deserializer/re-prompt) before use. Cross-ref `@llm-security-reviewer` LLM05 + LLM01. (AI-1)
- Every LLM feature has a **regression-gating eval set** in CI; a threshold drop doesn't ship. See `evals`. (AI-2)
- Every LLM call has a **token cap + timeout + traced cost**. See `llm-gateway`. (AI-3)
- **Structured output via schema/tool-calling**, result validated — never regex over free text. See `prompt-engineering`. (AI-4)
- **Temperature 0** for extraction/classification/routing. (AI-5)
- RAG retrieval is **tenant/permission-filtered AND quality-eval'd**. See `rag-pipeline` + LLM08. (AI-6)
- **Prompts are versioned code** — version id flows to logs + cache key + eval run. (AI-7)
- All provider calls go through the **gateway** seam. See `llm-gateway`. (AI-8)
- **Redact PII/secrets** before a provider call or a log write. (AI-9)

## Must not

- No provider-SDK calls scattered outside the gateway. (AI-8)
- No unbounded agent loop (no max-steps/token/cost/timeout). See `agent-design`. (AI-3)
- No effectful tool (write/delete/spend/send/exec) without a confirmation/policy gate — Excessive Agency (LLM06). (AI-1)
- No secrets/PII in prompts or logs. (AI-9)
- No regex/string-slicing where schema/tool-calling exists. (AI-4)
- No over-claims about determinism ("exactly-once", byte-reproducible). (AI-5)
- No shipping on vibes — a demo is not an eval. (AI-2)

## Should

- **Model cascade** — cheapest model that passes the eval set; escalate on failure. (AI-3)
- **Fallback model/provider** on outage/overload. (AI-8)
- **Cache** repeated context (exact + prompt-caching; semantic only with tenant-scoped keys). (AI-3)
- **Stream** long generations; handle mid-stream errors. (AI-3)
- **Recoverable tool errors** — structured error the model reads, not an exception. (AI-1)
- **Compact context** across agent steps. (AI-3)
- **Golden-set + adversarial cases** in evals. (AI-2)
- **Human-in-the-loop** on irreversible/high-value actions, with an audit trail. (AI-1)

## Review checklist

- [ ] Model output + retrieved content validated/encoded before any sink. (AI-1)
- [ ] LLM feature has a CI eval set with thresholds. (AI-2)
- [ ] Every call has a token cap + timeout + trace-linked cost. (AI-3)
- [ ] Structured output uses schema/tool-calling + is validated — no regex. (AI-4)
- [ ] Extraction/classification/routing at temperature 0. (AI-5)
- [ ] RAG retrieval tenant/permission-filtered + quality-eval'd. (AI-6)
- [ ] Prompt versioned; id flows to logs + cache key + eval. (AI-7)
- [ ] All provider calls via the gateway. (AI-8)
- [ ] Agent loop budgeted; effectful tools gated. (AI-3, AI-1)
- [ ] No secrets/PII in prompts or logs; redaction at the gateway. (AI-9)

## Enforcement

- **Eval CI gate** — suite runs on every LLM-touching PR; threshold regression fails the build. (AI-2)
- **Cost/latency dashboard + budget alerts** from the gateway. (AI-3)
- **Lint/grep gate** banning provider-SDK imports outside the gateway module. (AI-8)
- **Secret/PII scanners** (`gitleaks`, log-redaction tests) on prompt + log paths. (AI-9)
- **Security review hook** — LLM PRs route to `@llm-security-reviewer` (LLM01/05/06/08). (AI-1)

## Related

- **Patterns (in-pack):** `evals`, `rag-pipeline`, `prompt-engineering`, `agent-design`, `llm-gateway`.
- **Cross-pack:** injection / output handling / excessive agency / vector ACL → **security** `@llm-security-reviewer`; call logging / cost metrics / audit / redaction → **observability** (`observability-principles`, `tracing`, `audit-logging`); timeout/retry/circuit-breaker → **distributed-systems**/**backend**.
