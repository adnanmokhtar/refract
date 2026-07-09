---
name: vector-store-ops
description: 'Pattern: Vector Store Ops — the ANN index tuned to a stated recall/latency/scale target'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: Vector Store Ops — the ANN index tuned to a stated recall/latency/scale target

> **Hard rule:** The vector index is **chosen and tuned for a stated recall/latency/scale target** — the ANN algorithm and its parameters are **declared, not defaulted**. Every ANN index trades recall for latency and memory; shipping one whose tradeoff you never named means you don't know what your retrieval misses. A **brute-force / sequential scan at scale** (no ANN index) is forbidden, and so is an index whose **distance metric doesn't match the embedding model**. The index is not "set up" once — it is refreshed on upsert, or it silently serves stale results.

**When to apply**
- You operate the vector index behind a RAG system or any semantic-search feature — choosing, tuning, refreshing, or scaling it.
- Recall, latency, memory, or freshness of retrieval is a concern (i.e. any non-toy corpus).
- You're picking a distance metric, ANN parameters, a filtering strategy, or a hybrid-search fusion.

**When NOT to apply**
- The corpus is small enough that an **exact (brute-force) search** is fast and 100%-recall — an ANN index is needless complexity below that threshold (state the threshold; revisit as it grows).
- The chunk → embed → retrieve → rerank **usage** decisions — those belong to `rag-pipeline`; this pattern is the index *underneath* that retrieval.

**Halt conditions / mandatory cites**
- A **brute-force / sequential vector scan at scale** (no ANN index, full-corpus distance compute per query) MUST be cited at `<path:line>` — latency and cost grow linearly with the corpus.
- An HNSW/IVF index built with **defaulted parameters and an unstated recall target** MUST be flagged — nobody chose the recall/latency point; you don't know what it drops.
- A **distance metric mismatched to the embedding model** (e.g. L2 where the model expects cosine, or unnormalized vectors under cosine) MUST be cited — ranking is corrupt (cross-link `rag-pipeline` §embedding).
- A **heavy metadata pre-filter combined with a tight `ef`/`nprobe`** (pre-filter recall collapse) MUST be flagged — the filter strands the ANN graph and recall silently craters.
- **No index refresh/rebuild on upsert or delete** (stale index serving old/removed vectors) MUST be cited.

## 1. Exact vs ANN — pick for the corpus size

- **Exact (brute-force / flat)** — compute distance to every vector. 100% recall, dead simple, but O(n) per query. Correct and *preferred* for small n (thousands to low tens of thousands, workload-dependent) — measure the crossover, don't assume it.
- **ANN (approximate nearest neighbor)** — sub-linear search that trades a little recall for large latency/memory wins. Mandatory once the exact scan misses your latency target. The moment you go ANN, you own a **recall number** — state it.

## 2. Index families and their knobs

- **HNSW (graph)** — the common default; strong recall/latency, higher memory.
  - `m` — edges per node (higher = better recall, more memory + slower build).
  - `ef_construction` — build-time candidate breadth (higher = better graph, slower build).
  - `ef_search` (aka `ef`) — query-time breadth: **the recall ⇄ latency dial**. Raise for recall, lower for speed. Tune it against a recall eval, don't leave it default.
- **IVF / IVFFlat (cluster)** — partition vectors into `nlist` cells; query probes `nprobe` of them.
  - `nlist` — number of partitions (build-time).
  - `nprobe` — cells searched per query: the recall ⇄ latency dial (higher = more recall, slower). Needs a training/sample step to build the centroids.
- **Product Quantization (PQ / IVFPQ)** — compress vectors into codes to slash **memory** at some recall cost. Reach for it when the index won't fit in RAM at scale; combine with IVF.

## 3. The tradeoff — name the target

Recall, latency, and memory form a triangle; you cannot max all three. **State the target** ("p95 < 50 ms, recall@10 ≥ 0.95, fits in N GB") and tune parameters to it, measured against a retrieval-recall eval (see `evals`). An index with an unstated target is untuned by definition.

## 4. Metadata filtering — pre vs post

- **Post-filter** — ANN-search first, then drop non-matching results: cheap, but a selective filter can leave *too few* survivors (you asked for k, most got filtered out) → recall hole.
- **Pre-filter** — restrict the candidate set to matching metadata before/inside the ANN search: correct result count, but a heavy filter over an HNSW graph can **strand** the traversal so it can't reach enough neighbors — recall collapses unless you raise `ef`/`nprobe` to compensate.
- Know which mode your store uses, and **raise the search-breadth parameter when filtering hard**. Tenant/permission filters (mandatory in multi-tenant — see `rag-pipeline`) run here; a per-tenant **namespace/partition** often beats a runtime predicate.

## 5. Hybrid search — vector + keyword

- Fuse dense (vector) recall with **sparse (BM25 / keyword)** so exact terms, names, codes, and rare jargon that embeddings blur are still matched. Combine via **Reciprocal Rank Fusion** or a weighted score. This is the index-level counterpart of `rag-pipeline`'s hybrid-retrieval decision — the store must actually maintain both a vector index and a keyword/inverted index.

## 6. Build, refresh, and correctness

- **Dimension + distance metric must match the embedding model** — index dim = embedding dim, and the metric (cosine / dot / L2) is the one the model was trained/normalized for. Cosine expects **L2-normalized** vectors; mixing normalized and raw corrupts ranking.
- **Incremental upserts + deletes** — updated/removed documents must upsert/delete their vectors, or the index serves stale/deleted content. Some ANN structures degrade with heavy incremental churn and need periodic **rebuild/compaction**.
- **Build vs serve** — large index builds are offline/batched; plan build time and memory, and rebuild atomically on a metric/model/param change (a re-embed under a new model is a full rebuild — see `rag-pipeline`).
- **Sharding at scale** — beyond one node's memory, shard the index (by hash or by tenant/namespace) and scatter-gather queries; each shard keeps its own recall target.

## Adapt to your stack

- **pgvector (Postgres)** — HNSW or IVFFlat index; set `ef_search` / `probes` per query; match `vector_cosine_ops` / `vector_l2_ops` to the model. The relational-DB vector-search angle — cross-pack `database`.
- **Pinecone** — managed ANN; pods/serverless, namespaces for tenant isolation, metadata filtering built in.
- **Weaviate** — HNSW with `ef`/`efConstruction`/`maxConnections`; native hybrid (BM25 + vector) fusion.
- **Qdrant** — HNSW with payload (metadata) filtering and `hnsw_ef`; filtered-search aware.
- **Milvus** — IVF/HNSW/DiskANN family, explicit `nlist`/`nprobe`, built for large-scale sharded indexes.
- **Elasticsearch / OpenSearch** — kNN (HNSW) alongside native BM25 — hybrid in one engine.
- **FAISS (in-proc library)** — flat / IVF / HNSW / PQ; you own persistence, refresh, and sharding yourself.

## Detectors (cite-or-halt)

- **Brute-force vector search at scale** →
  - BAD: a full-corpus distance scan per query on a large, growing index — latency climbs with n.
  - GOOD: an ANN index (HNSW/IVF) sized to the corpus, with a stated recall target; exact search only below a measured crossover.
  - → `add-ann-index`
- **ANN params defaulted, recall unstated** →
  - BAD: HNSW/IVF built with library defaults; no recall@k number, no `ef`/`nprobe` tuning.
  - GOOD: parameters chosen against a stated recall/latency target and a retrieval eval.
  - → `tune-ann-params`
- **Distance metric mismatched to the embedding model** →
  - BAD: L2 index (or unnormalized vectors under cosine) for a model trained for cosine similarity.
  - GOOD: metric + normalization matched to the embedding model; dim = embedding dim.
  - → `fix-distance-metric`
- **Pre-filter recall collapse** →
  - BAD: a heavy metadata/tenant pre-filter over HNSW with a tight `ef` — traversal strands, recall craters silently.
  - GOOD: raise `ef`/`nprobe` under selective filters, or partition by namespace; verify recall with the filter applied.
  - → `fix-filtered-recall`
- **No index refresh on upsert/delete** →
  - BAD: documents change but their vectors aren't upserted/deleted — the index serves stale/removed content.
  - GOOD: upsert/delete wired into the write path, with periodic rebuild/compaction where the structure degrades.
  - → `add-index-refresh`

**Closure verbs:** `add-ann-index`, `tune-ann-params`, `fix-distance-metric`, `fix-filtered-recall`, `add-index-refresh`.

## Related

- `rag-pipeline` — **boundary:** rag-pipeline owns chunk → embed → retrieve → rerank *usage*; this pattern owns the ANN **index tuning underneath** it (algorithm, params, refresh, sharding). The embedding-model / distance-metric match is shared; hybrid + tenant-filter decisions surface in both.
- `evals` — retrieval recall@k is the metric that makes "tuned to a recall target" a measured claim rather than an assertion; tune `ef`/`nprobe` against it.
- Cross-pack `database` — the pgvector-in-a-relational-DB angle: the vector index lives beside your tables and shares their operational surface (migrations, indexes, scaling).
- Review `@ai-feature-reviewer` — reviews the stated recall/latency target, the ANN params, and the refresh path on any vector-store PR.
