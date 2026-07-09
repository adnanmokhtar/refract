---
name: rag-pipeline
description: 'Pattern: RAG Pipeline — retrieval quality is the whole game'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: RAG Pipeline — retrieval quality is the whole game

> **Hard rule:** In a RAG system, **retrieval quality is the #1 failure mode** — a perfect prompt over the wrong context produces a confident wrong answer. The pipeline is a chain (ingest → chunk → embed → retrieve → rerank → assemble → generate) and it is only as good as its weakest link, so each link is measured, not assumed. Query and document embeddings MUST come from the SAME model. Retrieval in a multi-tenant system MUST filter by tenant/permission BEFORE ranking — an unfiltered vector search is a cross-tenant data leak. And when nothing relevant is retrieved, the model MUST be able to say "I don't know" rather than hallucinate.

**When to apply**
- Any feature that answers from a corpus the base model wasn't trained on: docs Q&A, support knowledge base, internal search, "chat with your data", grounded generation over user/tenant documents.
- Any place you inject retrieved text into a prompt to ground the answer.

**When NOT to apply**
- The knowledge is small and static enough to fit in the context window every call — just put it in the prompt (or cache it); a vector store is overhead you don't need.
- The task doesn't need external knowledge (pure reasoning, transformation, or extraction over the user's own provided input) — RAG adds latency and failure surface for nothing.
- Structured, queryable data — use SQL / a real query, not embeddings, when the question maps to fields.

**Halt conditions / mandatory cites**
- Retrieval with **no evaluation of retrieval quality** (recall@k / context relevance) MUST be cited — you cannot claim RAG works if you never measured whether it fetches the right chunks.
- Query and document embeddings from **different models** (or different model versions) MUST be flagged — the vectors live in incompatible spaces; similarity is meaningless.
- A vector search in a multi-tenant system with **no tenant/permission filter** is a cross-tenant leak — cite it at `<path:line>`; this is a security defect, not a quality one (cross-link `tenant-isolation`).
- Context assembled with **no token-budget check** (silent truncation of the window) MUST be cited — dropped context = dropped answer, invisibly.
- Generation with **no "no relevant context" guard** MUST be cited — the model will invent an answer from parametric memory.

## 1. Ingestion + chunking

Chunking is the highest-leverage, most-underestimated decision in the pipeline. Bad chunks cap the ceiling on everything downstream.

- **Respect document structure.** Split on semantic boundaries (headings, sections, paragraphs, code blocks, table rows) — never blindly every N characters mid-sentence. Structure-aware chunking beats fixed-size for almost every corpus.
- **Size to the query, not a default.** Fact-lookup queries want small, precise chunks; synthesis/"explain" queries want larger context. If the chunk is much bigger than the answer, retrieval precision drops (noise dilutes the match); if much smaller, the answer gets split across chunks and neither ranks.
- **Overlap** adjacent chunks (e.g. 10–20%) so a fact straddling a boundary survives in at least one chunk. Too much overlap = duplicate hits + wasted budget.
- **Attach metadata at ingest** — source id/title, section, `tenant_id`, permissions/ACL, timestamp, URL/anchor for citation. You retrieve and filter on this later; you cannot add it after the fact.
- **Handle updates + deletes.** Documents change — re-chunk + re-embed on change, and delete stale vectors. A vector store that only ever grows serves deleted/old content.
- **Consider parent/child (small-to-big):** embed small chunks for precise matching but return the surrounding parent chunk for context.

## 2. Embedding

- **Choose the embedding model deliberately** — retrieval-tuned, matched to your domain and languages, and check the sequence-length limit (text longer than the limit is silently truncated before embedding).
- **Query and document embeddings MUST come from the same model** (and version). Re-embedding the corpus on a model upgrade means re-embedding EVERYTHING, atomically — a corpus half in the old space is corrupt. Pin the model+version alongside the index.
- **Dimensionality** is a cost/quality trade — higher dims cost more storage + slower search; some models support Matryoshka truncation to shorten vectors with graceful quality loss. Pick per your recall target and index size.
- **Normalization** — if you use cosine similarity, store L2-normalized vectors (or use the store's cosine metric). Mixing normalized and raw vectors, or cosine-vs-dot inconsistency, corrupts ranking.
- **Some models want an instruction/prefix** (e.g. distinct query vs passage prefixes). Apply it consistently to both sides.

## 3. Retrieval

- **top-k** — retrieve enough candidates to feed reranking, not so many the reranker/context drowns. Retrieve wide (e.g. k=20–50) THEN rerank down to a few — don't send raw top-k straight to the prompt.
- **Hybrid search = dense + sparse.** Dense (embeddings) captures semantics; **BM25 / keyword** captures exact terms, names, codes, IDs, and rare jargon that embeddings blur. Fuse them (e.g. Reciprocal Rank Fusion). Hybrid reliably beats either alone — pure-vector misses exact-match queries.
- **Metadata filtering** — filter by source, recency, type, language BEFORE or during the vector search to cut the candidate space to what's admissible.
- **Tenant / permission filter — mandatory in multi-tenant or access-controlled corpora.** The vector query MUST be constrained to the caller's `tenant_id` and permitted documents. An unfiltered ANN search will happily return another tenant's chunks — a cross-tenant leak. Filter at the store (metadata predicate / per-tenant namespace / partition), not after retrieval in app code where a bug drops the check. **Cross-link `tenant-isolation` — this is a security boundary.**

## 4. Reranking

- On a large candidate set, add a **reranking** stage: a **cross-encoder / reranker model** scores each (query, chunk) pair jointly — far more accurate than the bi-encoder cosine used for first-stage retrieval, which scores query and chunk independently.
- Pattern: **retrieve wide (cheap bi-encoder) → rerank narrow (accurate cross-encoder) → keep the top few.** Skipping reranking on a large candidate set leaves obvious relevance wins on the table.
- The reranker also lets you retrieve generously (high recall) without polluting the final context — it filters the noise the wide retrieval let in.

## 5. Context assembly

The last mile before the model — where good retrieval is still routinely squandered.

- **Deduplicate** near-identical chunks (overlap + hybrid fusion produce duplicates) — duplicates waste budget and bias the model.
- **Order intentionally.** Long-context models can under-weight the middle of a large context ("lost in the middle") — place the strongest chunks at the start and/or end, not buried in the middle.
- **Fit the token budget explicitly.** Compute assembled context + prompt + expected output against the model's window and a cost budget. If it overflows, drop the lowest-ranked chunks **deliberately** — never let the SDK/framework silently truncate, which can cut the one chunk with the answer.
- **Cite sources.** Carry each chunk's source id/URL/anchor through so the answer can attribute claims — enables faithfulness evals and lets users verify. (See `evals` — faithfulness/groundedness.)
- **Guard the "no relevant context" case.** If retrieval returns nothing above a relevance threshold, instruct the model to say it doesn't know / can't find it — do NOT hand it an empty or weak context and let it answer from parametric memory. This is the single biggest hallucination source in RAG.
- **Delimit retrieved content** as untrusted data in the prompt (it can contain injection payloads) — see `prompt-engineering` and `llm-security`.

## Evaluate the pipeline, per stage

You cannot fix what you don't isolate — measure retrieval and generation separately (see `evals`):

- **Retrieval:** recall@k / context recall (did the needed chunk get fetched?) and context precision/relevance (were the fetched chunks relevant?). A generation failure is often actually a retrieval failure — this split tells you which stage to fix.
- **Generation:** faithfulness/groundedness (answer supported by context) + answer relevance.
- Build a small labeled set of (question → gold source chunks) so recall@k is measurable, and grow it from real misses.

## Detectors (cite-or-halt)

- **No retrieval-quality eval** (no recall@k / context-relevance metric) →
  - BAD: RAG shipped; only the final answer is spot-checked; retrieval never measured.
  - GOOD: a labeled question→gold-chunk set scored for recall@k + context relevance in CI.
  - → `add-retrieval-eval`
- **Chunk size mismatched to the query** →
  - BAD: 2000-token chunks for single-fact lookups (precision drops), or 100-token chunks for synthesis (answer split across chunks).
  - GOOD: chunk size chosen for the query type, on semantic boundaries, tuned against the retrieval eval.
  - → `tune-chunking`
- **Query & doc embeddings from different models/versions** →
  - BAD: docs embedded with model A, queries embedded with model B (or A after an unversioned upgrade).
  - GOOD: one pinned model+version for both sides; re-embed the whole corpus on upgrade.
  - → `unify-embedding-model`
- **No reranking on a large candidate set** →
  - BAD: top-k=50 bi-encoder hits sent straight into the prompt.
  - GOOD: wide retrieve → cross-encoder rerank → top few.
  - → `add-reranker`
- **No tenant / permission filter on retrieval** (cross-tenant leak) →
  - BAD: `vectorStore.search(queryVec, k)` with no `tenant_id` / ACL predicate in a multi-tenant app.
  - GOOD: the vector query constrained to the caller's tenant + permitted docs, enforced at the store.
  - → `add-tenant-filter` (security — cross-link `tenant-isolation`)
- **Context overflowing the window (silent truncation)** →
  - BAD: all retrieved chunks concatenated and passed in; the SDK truncates whatever doesn't fit.
  - GOOD: an explicit token-budget fit that drops lowest-ranked chunks deliberately.
  - → `add-context-budget`
- **No "no-context" guard** →
  - BAD: empty/weak retrieval → model answers anyway from memory.
  - GOOD: a relevance threshold → "I don't know / no source found" path when nothing qualifies.
  - → `add-no-context-guard`

**Closure verbs:** `add-retrieval-eval`, `tune-chunking`, `unify-embedding-model`, `add-reranker`, `add-tenant-filter`, `add-context-budget`, `add-no-context-guard`.

## Related

- `evals` — retrieval quality (recall@k, context relevance/recall) and generation faithfulness are eval metrics; this pattern's stages are only "working" once gated by that eval.
- `prompt-engineering` — assembled context is untrusted data: delimit it, put long context before the instruction, and guard the no-context case in the prompt.
- `llm-gateway` — embedding + generation calls route through the gateway (caching embeddings, cost/latency budget, retries).
- `agent-design` — retrieval is often exposed to an agent as a `search` tool; the same quality + tenant-filter rules apply.
- `vector-store-ops` — **boundary:** this pattern owns chunk→embed→retrieve→rerank *usage*; `vector-store-ops` owns the ANN **index tuning underneath** it (algorithm, `ef`/`nprobe`, recall target, refresh, sharding). The embedding-model / distance-metric match and the tenant/hybrid decisions surface in both.
- `fine-tuning` — the **last-resort ladder**: when the gap is *knowledge/freshness*, stay on RAG; fine-tuning is for *behavior* only and must never take over RAG's job of injecting facts.
- Security `tenant-isolation` / `@llm-security-reviewer` / `llm-security` — the tenant/permission filter on retrieval is a security boundary (cross-tenant leak); retrieved content is untrusted input (injection). Author these WITH the security reviewer.
