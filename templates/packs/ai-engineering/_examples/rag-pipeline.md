---
name: rag-pipeline
description: 'Pattern: RAG Pipeline — retrieval quality is the whole game'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: RAG Pipeline — retrieval quality is the whole game

> **Hard rule:** In RAG, **retrieval quality is the #1 failure mode** — a perfect prompt over the wrong context produces a confident wrong answer. The pipeline (ingest → chunk → embed → retrieve → rerank → assemble → generate) is only as good as its weakest link, so each link is measured. Query and document embeddings MUST come from the SAME model. Multi-tenant retrieval MUST filter by tenant/permission BEFORE ranking — an unfiltered vector search is a cross-tenant leak. When nothing relevant is retrieved, the model MUST be able to say "I don't know" rather than hallucinate.

**When to apply** — answering from a corpus the model wasn't trained on (docs Q&A, support KB, chat-with-your-data). **Not** when the knowledge fits the window (just prompt it) or the question maps to structured fields (use SQL).

**Halt conditions / mandatory cites**
- Retrieval with **no recall@k / context-relevance eval** MUST be cited.
- Query & doc embeddings from **different models/versions** MUST be flagged (incompatible spaces).
- Vector search with **no tenant/permission filter** is a cross-tenant leak — cite at `<path:line>` (cross-link `tenant-isolation`).
- Context with **no token-budget check** (silent truncation) MUST be cited.
- Generation with **no "no relevant context" guard** MUST be cited (model invents an answer).

## 1. Ingestion + chunking

Highest-leverage decision. **Respect document structure** (split on headings/paragraphs/rows, not blind every-N-chars). **Size to the query** (fact-lookup → small precise chunks; synthesis → larger). **Overlap** 10–20% so boundary-straddling facts survive. **Attach metadata at ingest** (source, section, `tenant_id`, ACL, timestamp, citation anchor). Handle updates/deletes (re-chunk + re-embed on change; delete stale vectors). Consider parent/child (embed small, return parent).

## 2. Embedding

Retrieval-tuned model matched to domain+languages; check the sequence-length limit (over-long text is silently truncated). **Query + doc embeddings from the same model+version** — re-embed the WHOLE corpus atomically on upgrade. Dimensionality is a cost/quality trade (Matryoshka truncation where supported). Store L2-normalized vectors for cosine; keep the metric consistent. Apply any query/passage prefix consistently to both sides.

## 3. Retrieval

- **top-k** — retrieve wide (k=20–50) THEN rerank down; don't send raw top-k to the prompt.
- **Hybrid = dense + BM25/keyword** (fuse via RRF) — sparse catches exact terms/names/codes/IDs embeddings blur. Hybrid beats either alone.
- **Metadata filtering** cuts the candidate space before/during search.
- **Tenant/permission filter — mandatory** in multi-tenant/access-controlled corpora. Constrain the query to the caller's `tenant_id` + permitted docs at the store (namespace/partition/predicate), not in app code after retrieval. Cross-link `tenant-isolation` — security boundary.

## 4. Reranking

On a large candidate set, add a **cross-encoder / reranker** that scores (query, chunk) jointly — far more accurate than first-stage bi-encoder cosine. Pattern: **retrieve wide (cheap) → rerank narrow (accurate) → keep top few.** Lets you retrieve for high recall without polluting the final context.

## 5. Context assembly

**Dedup** near-identical chunks. **Order intentionally** — long-context models under-weight the middle ("lost in the middle"); put strongest chunks first/last. **Fit the token budget explicitly** — drop lowest-ranked chunks deliberately; never let the SDK silently truncate the chunk with the answer. **Cite sources** (carry source id/URL/anchor for faithfulness evals + user verification). **Guard the no-context case** — below a relevance threshold, say "I don't know" (biggest hallucination source). **Delimit retrieved content as untrusted** (injection — see `prompt-engineering` / `llm-security`).

## Evaluate per stage

Measure retrieval and generation separately (see `evals`): retrieval = recall@k + context precision/relevance; generation = faithfulness + answer relevance. A "generation" failure is often a retrieval failure — the split tells you which to fix. Build a labeled question→gold-chunk set; grow from real misses.

## Detectors (cite-or-halt)

- **No retrieval eval** → GOOD: labeled recall@k + context-relevance set in CI → `add-retrieval-eval`
- **Chunk size mismatched to query** → `tune-chunking`
- **Query & doc embeddings from different models** → `unify-embedding-model`
- **No reranking on a large candidate set** → `add-reranker`
- **No tenant/permission filter** (cross-tenant leak) → `add-tenant-filter` (cross-link `tenant-isolation`)
- **Context overflow / silent truncation** → `add-context-budget`
- **No no-context guard** → `add-no-context-guard`

**Closure verbs:** `add-retrieval-eval`, `tune-chunking`, `unify-embedding-model`, `add-reranker`, `add-tenant-filter`, `add-context-budget`, `add-no-context-guard`.

## Related

- `evals` — recall@k, context relevance/recall, faithfulness are the metrics; stages "work" only once gated.
- `prompt-engineering` — retrieved context is untrusted data: delimit it, place before the instruction, guard no-context.
- `llm-gateway` — embedding + generation calls route through it (caching, budgets, retries). `agent-design` — retrieval as a `search` tool.
- Security `tenant-isolation` / `@llm-security-reviewer` / `llm-security` — the retrieval tenant filter is a security boundary; retrieved content is injection surface.
