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

The essentials arrays are deliberately unchanged by the 1.3.0 build-out. Everything added in that release presupposes an AI surface that already exists — the two architects design against a sibling pipeline or an existing loop, the four detector skills need call sites to detect, and `/ai-audit` + `/add-eval-set` are retrofit doors onto shipped code. None of them is a day-one greenfield need, which is what minimal mode serves. Standard mode copies them all.

Rationale per category (one line each):
- agents: ai-feature-reviewer is the universal reviewer for an LLM feature (correctness / eval-coverage / cost / output-handling / fine-tune justification). Kept as the single essential agent. Signal-gated in standard mode: `rag-architect` (fires on `embedding|vector|retriev|rerank|chunk`) designs the retrieval pipeline and the ANN index against a stated recall/latency/scale target; `agent-loop-architect` (fires on `tools=|tool_use|agent|planner`) picks the autonomy rung and the four loop budgets — and most often argues a proposed loop down into a workflow. Both design *before* code exists, which is precisely why neither belongs in a minimal install.
- commands: add-ai-feature is the day-one entry point for building an LLM feature end-to-end. Signal-gated in standard mode: `/ai-audit` (the read-only six-axis sweep of an existing surface — eval, prompt, retrieval, ANN index, agent budgets, gateway/cost) and `/add-eval-set` (retrofits the regression gate onto a feature that shipped without one, closing `eval-run`'s no-harness HALT). Both are doors onto code that already exists.
- skills: none essential — `eval-run` becomes useful once an eval harness exists. Standard mode adds the four detector skills, each gated on its own signal: `prompt-audit` and `llm-gateway-audit` on any LLM usage (the prompt/parse sites and the provider-call seam), `retrieval-eval` on retrieval signals (recall@k filtered and unfiltered against a labelled question→gold-chunk set), and `vector-index-audit` on ANN-index signals (`hnsw|ivf|ef_search|nprobe|faiss|` a managed store). A skill with no call sites to sweep is noise in a minimal install.
- rules: ai-engineering-principles is the single rules file — treat model output as untrusted, evals gate every change, cost/latency are budgeted. AI-1…AI-9 already cover every principle the new artifacts enforce, so the build-out added enforcement pointers, not new Must items.
- ai-patterns: evals is the must-have foundation (no LLM feature ships without a regression-gating eval). rag-pipeline (retrieval quality), vector-store-ops (the ANN index under it), prompt-engineering (structured output), agent-design (tools/loops/human-in-loop/budgets), llm-gateway (routing/caching/cost/fallback/streaming), and fine-tuning (the last-resort ladder) are signal-gated. Boundary: the security pack's @llm-security-reviewer secures these features (prompt injection / output handling / excessive agency); every trust-boundary finding is routed there, never graded in this pack.
