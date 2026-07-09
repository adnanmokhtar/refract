---
description: Build an LLM feature end-to-end — prompt/gateway wiring + structured output + retrieval (if RAG) + agent budgets (if agentic) + a MANDATORY regression-gating eval set + a security handoff. 8 phases with Evaluate load-bearing. The AI analog of /add-endpoint.
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Provider-agnostic — substitute the project's provider, gateway seam, structured-output mode, and vector store.

# /add-ai-feature

Build an LLM-backed feature the right way: eval set built FIRST or alongside and gating the change; structured output; calls through the gateway seam with cost + token + timeout budget; retrieval (if RAG) tenant-filtered + no-context guard; agent loops (if agentic) budgeted with human-in-loop on destructive tools; trust boundary handed to `@llm-security-reviewer`.

## Phases applied

All 8: **Understand → Organize → Retrieve → Generate → Evaluate → Update → Validate → Improve.** Phase 5 (Evaluate) is load-bearing — the eval set is built FIRST/alongside, never bolted on.

## Phase 1 — Understand

**Intent gate**: "broken output" → `/fix-bug`; "slow/expensive" → `/optimize`; "audit" → `@ai-feature-reviewer` / `@llm-security-reviewer`; "prompt injection / unsafe render" → `@llm-security-reviewer`; not an LLM feature → `/add-endpoint` / `/add-feature`. Proceed only when the feature calls a model.

Ask: feature (task + input + output); what defines a **good** output (the eval spec — not optional); shape (RAG / agentic / single call); provider + gateway seam?; multi-tenant?; any destructive side effect?

## Phase 2 — Organize

Design shape, prompt (roles + output schema), retrieval (if RAG), tools+loop (if agentic), gateway seam, and the **eval plan** (dataset source, scorers, baseline+threshold) — against `evals` / `prompt-engineering` / `rag-pipeline` / `agent-design` / `llm-gateway`.

## Phase 3 — Retrieve

Universals + `evals.md` + `prompt-engineering.md` (+ `rag-pipeline` / `agent-design` / `llm-gateway` per signal) + the rule + the existing gateway seam + eval harness. Mirror a sibling LLM feature EXACTLY.

## Phase 4 — Generate

- **Prompt + structured output**: owned prompt module; tool/JSON-schema mode (no regex-parse); `temperature: 0` for extraction; instruction/data separated.
- **Gateway + budget**: route through the one gateway module; `max_tokens` + timeout + traced cost on every call.
- **RAG**: tenant filter at query time; no-context guard; deliberate chunking + top-k.
- **Agentic**: loop budget (steps + tokens + timeout); human-in-loop on destructive tools; typed tool inputs.

Signal table (extract): RAG → retrieval metric in the eval; multi-tenant → tenant-scoped query+logs+cost + cross-tenant test; destructive tool → confirmation/dry-run; output→sink → hand SINK to `@llm-security-reviewer`; user content in prompt → injection surface → `@llm-security-reviewer`.

## Phase 5 — Evaluate (MANDATORY — the gate)

1. Build the versioned eval set (seeded from the Phase-2 spec; held out from few-shot).
2. Wire scorers (assertion + LLM-as-judge + retrieval metric if RAG); pin the judge.
3. Set baseline + threshold; **gate in CI**.
4. **Dispatch `eval-run`** — PASS at/above baseline or HALT.
5. **Dispatch `@llm-security-reviewer`** — required handoff for injection / output handling / excessive agency. `@ai-feature-reviewer` does NOT clear security.

HALT: no eval set; doesn't gate; below baseline; security handoff skipped.

## Phase 6 — Update

`ai/status.md`, changelog, record eval dataset version + baseline, ADR if a new pattern emerged.

## Phase 7 — Validate

Lint + tests; **`eval-run` green** (the gate); cross-tenant retrieval test (if RAG multi-tenant); agent budget + destructive-tool-confirmation test (if agentic). Review: `@ai-feature-reviewer` (engineering) + `@llm-security-reviewer` (security, required) + `@tenant-isolation-reviewer` (if multi-tenant).

## Phase 8 — Improve

`/learn-from-task`; wire the prod-failure→eval-case path (the loop that strengthens the gate); ADR for a new domain signal.

## Output

```
✅ AI feature added: <feature>
Phase 5 (Evaluated): eval set v1 (<N> cases) gated in CI; eval-run PASS @ baseline; @llm-security-reviewer cleared.
Eval: <N> cases, scorers=<assertion + judge (+ recall@k)>, baseline=<score>, gate=CI.
Cost/latency: max_tokens=<n>, timeout=<ms>, cost traced.
Review (engineering): APPROVE/REQUEST_CHANGES/BLOCK   Security handoff: CLEARED/BLOCKERS
Status: COMPLETE
```

## Hard rules

- The eval set is mandatory and gates in CI — no eval → not done.
- Structured output (no regex-parse); every generation has `max_tokens` + timeout + traced cost through the gateway seam.
- RAG: tenant-filtered at query time + no-context guard + retrieval metric. Agentic: loop budgeted + human-in-loop on destructive tools. `temperature: 0` for extraction.
- Security is a required handoff — `@llm-security-reviewer` clears injection / output handling / excessive agency.

## Related

- `/add-endpoint` (non-AI analog), `/fix-bug`, `/optimize`.
- `@ai-feature-reviewer` (engineering review), `@llm-security-reviewer` (security, required handoff).
- Skill `eval-run`. Patterns `evals` / `prompt-engineering` / `rag-pipeline` / `agent-design` / `llm-gateway`. Rule `.claude/rules/ai-engineering-principles.md`.
