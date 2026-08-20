---
name: vector-index-audit
kind: example
pack: ai-engineering
description: Audits the ANN index against a STATED recall/latency/scale target — brute-force at scale, defaulted params, metric/normalisation/dim mismatch, filtered-recall collapse, missing refresh — with an inventory and closure verbs.
---

# Skill: vector-index-audit

## Premise

Every ANN index trades recall for latency and memory, and an index whose tradeoff nobody named misses results silently — an ANN search never errors when it returns the wrong neighbours.

**Every finding cites `<path:line>`** (index definition, migration, provisioning call, or write path) **+ a real excerpt + its closure verb.** **"Tuned to a recall target" has two halves: the target is written down, and a measurement exists.** Missing either ⇒ `UNSTATED` / `UNMEASURED` + what would settle it. This skill never guesses a recall figure and never writes "looks fine" — producing the number is `retrieval-eval`'s job.

## Adapt to your stack

| Store | Index defined at | Recall ⇄ latency dial | Filter mode | Refresh |
|---|---|---|---|---|
| pgvector | a migration (`USING hnsw/ivfflat … vector_<metric>_ops`) | `hnsw.ef_search` / `ivfflat.probes` | `WHERE` predicate; planner decides | DML + `REINDEX` |
| Pinecone | index creation / console; namespaces per tenant | managed tier + namespace | metadata filter inside search | upsert/delete API |
| Weaviate | class schema (`ef`, `efConstruction`, `maxConnections`) | `ef` at query time | `where` filter | object upsert/delete |
| Qdrant | collection `hnsw_config`, payload indexes | `hnsw_ef` | payload filter, filter-aware | point upsert/delete |
| Milvus | index params (`IVF*`/`HNSW`/`DiskANN`, `nlist`) | `nprobe` / `ef` | boolean expression | insert/delete + compaction |
| Elasticsearch / OpenSearch | mapping (`dense_vector` / `knn_vector`) | `num_candidates` / `ef_search` | query filter + kNN | indexing / merge |
| FAISS | index construction in code | `nprobe` / `efSearch` | none native → post-filter | you own persistence + rebuild |

Report the store's own parameter names — translating them makes the fix un-greppable.

## When to run

- Any diff touching index creation/config/migration; a re-embed or model upgrade; when latency or recall is in question; as the corpus crosses an order of magnitude. Dispatched by `/ai-audit` and `@ai-feature-reviewer` dim 3.
- NOT for chunking, top-k, reranking, or assembly (`rag-pipeline`, owned by `@rag-architect`); NOT for measuring recall (`retrieval-eval`).

## Inventory first

Store · family · params · dim · metric · normalisation · embedding model+version · corpus size · shard/namespace layout · filter mode · refresh path (upsert / delete / compaction / atomic rebuild) · **declared target** · **last measured recall**. Every unknown is a finding or a `NOT READ` — never blank.

## The five detectors

1. **Brute-force scan at scale** → `add-ann-index`. Exact search is *correct* below a measured crossover — the finding is "no ANN index **and** no measured crossover at corpus size N". State N or report `not read`.
2. **Defaulted params, unstated recall** → `tune-ann-params`. Defaults are not automatically wrong; the finding is that **nobody chose**, proven by the absent target. Grade both halves: target `UNSTATED`, measurement `UNMEASURED`.
3. **Metric / normalisation / dim mismatch** → `fix-distance-metric`. Cosine over unnormalised vectors, an L2 index for a cosine model, or a one-sided Matryoshka truncation. Cite three lines where possible: index definition, ingest write, query embed. The fix is an **atomic rebuild**.
4. **Heavy pre-filter + tight search breadth** → `fix-filtered-recall`. Raise `ef`/`nprobe` under selective filters, or partition by namespace so the filter becomes index selection. The proof is `retrieval-eval`'s filtered run.
5. **No refresh on upsert/delete, no rebuild path** → `add-index-refresh`. An index that only grows serves stale and deleted content — and where a deletion was a permission revocation or an erasure request, **hand it to `@llm-security-reviewer`**.

## Output

```
vector-index-audit — <scope>

Inventory: pgvector · HNSW · m=16 (default) · ef_construction=64 (default) · ef_search=never set
  dim 1536 · vector_cosine_ops · L2-normalised: NOT READ · corpus ~2.1M (counted at audit time)
  filter: tenant_id pre-filter · refresh: upsert ✓ delete ✗ compaction ✗
  Declared target: UNSTATED    Last measured recall: UNMEASURED

BLOCKER fix-filtered-recall  migrations/0087:6 — tenant pre-filter over HNSW, ef_search unset, never measured
BLOCKER add-index-refresh    corpus/documents.ts:140 — source delete with no vector delete
REQUEST tune-ann-params      migrations/0087:6 — defaults, no target. Settles with a declared target + retrieval-eval
REQUEST fix-distance-metric  rag/embed.ts:11 — cosine configured; normalisation NOT READ at the ingest write

Recall figures: none — this skill reports configuration, not measurement.
```

## False positives / gotchas

- A flat index is right below the crossover — report the missing *measured crossover*, not the index.
- "ef_search=40 is too low" without a measurement is the fabrication this skill forbids.
- Managed stores hide the knobs — the target obligation survives even when the dial does not.
- A per-tenant namespace already solves filtered recall → detector 4 is `N-A`, said out loud.
- Normalisation may live in the embedding wrapper, not the ingest code.
- Dim mismatches usually fail loudly — a one-sided truncation produces two valid dims and a corrupt space.
- pgvector shares the relational surface (build locks, migration safety) → cite the database pack, don't re-derive.

## Halt conditions

- A recall number not read from a real run → forbidden; `UNMEASURED` + dispatch `retrieval-eval`.
- `PASS` on a target never declared → forbidden (`UNSTATED`).
- An inventory row left blank → HALT; every row is a value, `NOT READ`, or `N-A` with a reason.
- A finding without its `<path:line>`; a hand-wave (`might` / `several similar`) → not emittable.
- Config unreadable (console-only managed settings) → report `not run` with the reason; never infer from library defaults.

## References

- `ai/patterns/vector-store-ops.md` (the pattern), `rag-pipeline.md` (boundary: usage above, index below); `retrieval-eval` (the measurement half); `@rag-architect` (designs; this audits); `@ai-feature-reviewer` dim 3; `@llm-security-reviewer` / `@tenant-isolation-reviewer`; cross-pack `database` (pgvector's relational surface); `.claude/rules/ai-engineering-principles.md` (AI-6).
