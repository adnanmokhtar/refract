# ai-engineering pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: ai-feature-reviewer
  kind: agent
  triggers: { llm_usage_detected: true }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (prompt sites + provider client + retrieval + eval harness + agent loops)
  sections: [persona, review_checklist, eval_coverage_check, cost_latency_check, output_handling_check, output_format]
  fallback: _examples/ai-feature-reviewer.md
  cite_evidence: strict

- name: rag-architect
  kind: agent
  triggers: { grep_evidence: "embedding|vector|pgvector|pinecone|weaviate|qdrant|retriev|rerank|chunk" }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (corpus + chunker + embedding model + vector store + retriever)
  sections: [persona, preflight_reading, corpus_and_chunking, embedding_and_index_target, retrieval_and_hybrid, reranking_and_assembly, tenant_boundary, retrieval_eval_plan, output_format, failure_modes]
  fallback: _examples/rag-architect.md
  cite_evidence: strict

- name: agent-loop-architect
  kind: agent
  triggers: { grep_evidence: "tool.call|function.call|agent|tools=|tool_use|react loop|planner" }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (tools + agent loop)
  sections: [persona, autonomy_ladder_decision, tool_contract_design, loop_budget_design, human_in_loop_tiers, context_management, audit_mode, output_format, failure_modes]
  fallback: _examples/agent-loop-architect.md
  cite_evidence: strict

- name: eval-run
  kind: skill
  triggers: { llm_usage_detected: true }
  fallback: _examples/eval-run.md

- name: prompt-audit
  kind: skill
  triggers: { llm_usage_detected: true }
  fallback: _examples/prompt-audit.md

- name: llm-gateway-audit
  kind: skill
  triggers: { llm_usage_detected: true }
  fallback: _examples/llm-gateway-audit.md

- name: retrieval-eval
  kind: skill
  triggers: { grep_evidence: "embedding|vector|pgvector|pinecone|weaviate|qdrant|retriev|rerank|chunk" }
  fallback: _examples/retrieval-eval.md

- name: vector-index-audit
  kind: skill
  triggers: { grep_evidence: "hnsw|ivf|ivfflat|ef_search|nprobe|nlist|faiss|pgvector|pinecone|weaviate|qdrant|milvus|ann.?index" }
  fallback: _examples/vector-index-audit.md

- name: add-ai-feature
  kind: command
  triggers: { llm_usage_detected: true }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" + sibling LLM features
  sections: [understand, organize, retrieve, generate, evaluate, update, validate, improve]
  fallback: _examples/add-ai-feature.md

- name: ai-audit
  kind: command
  triggers: { llm_usage_detected: true }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (full surface) + existing eval harness
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: _examples/ai-audit.md

- name: add-eval-set
  kind: command
  triggers: { llm_usage_detected: true }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (existing eval harness if any) + § Tests (the project's runner)
  sections: [understand, organize, retrieve, generate, evaluate, update, validate, improve]
  fallback: _examples/add-eval-set.md

- name: evals
  kind: pattern
  triggers: { llm_usage_detected: true }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (existing eval harness if any)
  sections: [why, dataset, scorers, llm_as_judge, regression_gate, detectors]
  mirror_existing: true
  fallback: _examples/evals.md

- name: rag-pipeline
  kind: pattern
  triggers: { grep_evidence: "embedding|vector|pgvector|pinecone|weaviate|qdrant|retriev|rerank|chunk" }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (embedding model + vector store + retrieval)
  sections: [ingestion_chunking, embedding, retrieval, reranking, context_assembly, detectors]
  mirror_existing: true
  fallback: _examples/rag-pipeline.md

- name: vector-store-ops
  kind: pattern
  triggers: { grep_evidence: "hnsw|ivf|ivfflat|ef_search|nprobe|nlist|faiss|pgvector|pinecone|weaviate|qdrant|milvus|ann.?index" }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (vector store + index type + ANN params + refresh path)
  sections: [exact_vs_ann, index_families, tradeoff_target, metadata_filtering, hybrid_search, build_refresh, detectors]
  mirror_existing: true
  fallback: _examples/vector-store-ops.md

- name: fine-tuning
  kind: pattern
  triggers: { grep_evidence: "fine.?tun|lora|peft|adapter|training.?data|\\.jsonl|axolotl|unsloth" }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (any fine-tune / training pipeline + dataset + eval)
  sections: [decision_ladder, what_it_buys, dataset_curation, lora_vs_full, eval_gate, versioning_drift, detectors]
  mirror_existing: true
  fallback: _examples/fine-tuning.md

- name: prompt-engineering
  kind: pattern
  triggers: { llm_usage_detected: true }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (prompt assembly + output parsing)
  sections: [structure, structured_output, few_shot, system_vs_user, detectors]
  mirror_existing: true
  fallback: _examples/prompt-engineering.md

- name: agent-design
  kind: pattern
  triggers: { grep_evidence: "tool.call|function.call|agent|tools=|tool_use|react loop|planner" }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (tools + agent loop)
  sections: [when_agent_vs_workflow, tool_design, loop_and_budgets, human_in_loop, detectors]
  mirror_existing: true
  fallback: _examples/agent-design.md

- name: llm-gateway
  kind: pattern
  triggers: { llm_usage_detected: true }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (provider client + routing + caching)
  sections: [routing_fallback, caching, cost_latency_budget, streaming, observability, detectors]
  mirror_existing: true
  fallback: _examples/llm-gateway.md

- name: ai-engineering-principles
  kind: rule
  triggers: { llm_usage_detected: true }
  sections: [output_untrusted, evals_gate, cost_latency_budget, determinism, structured_output, retrieval_quality, observability]
  mirror_existing: true
  fallback: rules/ai-engineering-principles.md
```
