---
name: vector-store-ops
description: 'Pattern: Vector Store Ops — the ANN index tuned to a stated recall/latency/scale target'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: Vector Store Ops — the ANN index tuned to a stated recall/latency/scale target

> **Hard rule:** The vector index is **chosen and tuned for a stated recall/latency/scale target** — the ANN algorithm and its parameters are **declared, not defaulted**. Every ANN index trades recall for latency and memory; shipping one whose tradeoff you never named means you don't know what retrieval misses. A **brute-force / sequential scan at scale** is forbidden, and so is a **distance metric mismatched to the embedding model**. The index is refreshed on upsert/delete, or it silently serves stale results.

**When to apply** — you operate the vector index behind RAG or semantic search: choosing, tuning, refreshing, or scaling it; recall/latency/memory/freshness matters (any non-toy corpus).

**When NOT to apply** — the corpus is small enough that exact (brute-force) search is fast + 100%-recall (state the threshold); the chunk→embed→retrieve→rerank *usage* decisions (those are `rag-pipeline`; this is the index *underneath*).

## Exact vs ANN — pick for the corpus size

- **Exact (flat)** — distance to every vector: 100% recall, O(n)/query. Correct + preferred for small n; measure the crossover, don't assume it.
- **ANN** — sub-linear, trades a little recall for large latency/memory wins. The moment you go ANN you own a **recall number** — state it.

## Index families and their knobs

- **HNSW (graph)** — common default. `m` (edges/node), `ef_construction` (build breadth), `ef_search`/`ef` — **the recall ⇄ latency dial** at query time. Tune `ef` against a recall eval, don't leave it default.
- **IVF / IVFFlat (cluster)** — `nlist` partitions; `nprobe` cells probed per query is the recall ⇄ latency dial. Needs a train step for centroids.
- **PQ / IVFPQ** — compress vectors to slash **memory** at some recall cost; reach for it when the index won't fit in RAM.

## Name the target + filter correctly

State the target ("p95 < 50 ms, recall@10 ≥ 0.95, fits in N GB") and tune to it against a retrieval eval (see `evals`). An index with an unstated target is untuned by definition.

Metadata filtering: **post-filter** (search then drop) can starve k; **pre-filter** (restrict candidates) is correct-count but a heavy filter over HNSW can **strand** traversal → recall craters unless you raise `ef`/`nprobe`. Tenant/permission filters run here — a per-tenant namespace/partition often beats a runtime predicate.

## Build, refresh, correctness

- **Dimension + distance metric MUST match the embedding model** (index dim = embedding dim; cosine expects L2-normalized vectors — mixing normalized/raw corrupts ranking).
- **Incremental upserts + deletes** wired into the write path, or the index serves stale/removed content; periodic rebuild/compaction where the structure degrades. A re-embed under a new model is a full atomic rebuild.
- **Hybrid** = dense + BM25 (RRF fusion) so exact terms/codes embeddings blur are matched — the store maintains both a vector and a keyword index.

## Detectors (cite-or-halt)

- **Brute-force vector search at scale** → `add-ann-index`
- **ANN params defaulted, recall unstated** → `tune-ann-params`
- **Distance metric mismatched to the embedding model** → `fix-distance-metric`
- **Pre-filter recall collapse** (heavy filter + tight `ef`) → `fix-filtered-recall`
- **No index refresh on upsert/delete** → `add-index-refresh`

**Closure verbs:** `add-ann-index`, `tune-ann-params`, `fix-distance-metric`, `fix-filtered-recall`, `add-index-refresh`.

## Related

- `rag-pipeline` — **boundary:** it owns chunk→embed→retrieve→rerank *usage*; this owns the ANN **index tuning underneath** (algorithm, params, refresh, sharding). Embedding-model / distance-metric match is shared.
- `evals` — retrieval recall@k makes "tuned to a recall target" a measured claim; tune `ef`/`nprobe` against it.
- Cross-pack `database` — the pgvector-in-a-relational-DB angle.
- Review `@ai-feature-reviewer` — reviews the stated target, ANN params, and refresh path.
