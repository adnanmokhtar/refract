---
track: ai-engineering
purpose: Building LLM/AI features well — RAG, evals, prompts, agents, and the LLM gateway.
essentials:
  agents: [ai-feature-reviewer]
  commands: [add-ai-feature]
  skills: []
  rules: [ai-engineering-principles]
  ai-patterns: [evals]
---

# ai-engineering — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: ai-feature-reviewer is the universal reviewer for an LLM feature (correctness / eval-coverage / cost / output-handling). Kept as the single essential agent.
- commands: add-ai-feature is the day-one entry point for building an LLM feature end-to-end.
- skills: none essential — eval-run becomes useful once an eval harness exists.
- rules: ai-engineering-principles is the single rules file — treat model output as untrusted, evals gate every change, cost/latency are budgeted.
- ai-patterns: evals is the must-have foundation (no LLM feature ships without a regression-gating eval). rag-pipeline (retrieval quality), prompt-engineering (structured output), agent-design (tools/loops/human-in-loop/budgets), and llm-gateway (routing/caching/cost/fallback/streaming) are signal-gated. Boundary: the security pack's @llm-security-reviewer secures these features (prompt injection / output handling / excessive agency).
