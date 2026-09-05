---
name: vector-index-audit
description: Audits the ANN index behind retrieval against a STATED recall/latency/scale target — flags a brute-force/sequential scan at scale, HNSW/IVF built with library-default parameters and no recall number, a distance metric or normalisation mismatched to the embedding model (and a dimension mismatch), a heavy metadata/tenant pre-filter combined with a tight ef/nprobe (silent filtered-recall collapse), and a write path with no vector upsert/delete or rebuild/compaction so the index serves stale or deleted content. Emits the index inventory (store, family, params, dim, metric, corpus size, filter mode, refresh path) plus findings with closure verbs. TRIGGER — any diff touching index creation/config/migration, a re-embed or embedding-model upgrade, retrieval latency or recall in question, and dispatched by /ai-audit and @ai-feature-reviewer dimension 3. ANTI-TRIGGERS (do NOT fire) — chunking, top-k, reranking, or context-assembly decisions (that is rag-pipeline, owned by @rag-architect); MEASURING recall (that is retrieval-eval — this skill reports whether a target was declared and whether it was ever measured, and never invents a recall number); relational index/lock/migration concerns (database pack).
kind: skill
pack: ai-engineering
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: vector-index-audit

## Premise

Every ANN index trades recall for latency and memory. Shipping one whose tradeoff nobody named means nobody knows what retrieval misses — and the miss is silent, because an ANN index never errors when it returns the wrong neighbours. This skill reads the index as configured and reports the gap between what was declared and what was built.

**Every finding cites `<path:line>` (or the migration / index-definition / provisioning site) + a real excerpt + the closure verb.** For an absence — no stated target, no refresh path — the citation is the site that should carry it: the index creation statement, the write path, the config module.

**"Tuned to a recall target" is a claim with two halves: the target is written down, and a measurement exists.** Where either is missing this skill reports `UNSTATED` or `UNMEASURED` and names what would settle it. It never guesses a recall figure, never converts a parameter value into an implied recall, and never writes "looks fine". Producing the number is `retrieval-eval`'s job, not this skill's.

## Adapt to your stack

Find the index definition, then read its knobs in the store's own vocabulary. Detect from `_extracted-codebase.md § AI/LLM integration` and confirm at the definition site:

| Store | Where the index is defined | Recall ⇄ latency dial | Filter mode | Refresh surface |
|---|---|---|---|---|
| **pgvector (Postgres)** | a migration: `CREATE INDEX … USING hnsw/ivfflat (… vector_<metric>_ops)` | `hnsw.ef_search` / `ivfflat.probes` (session or per-query) | predicate in the `WHERE` clause; planner decides pre/post | ordinary DML on the table + `REINDEX`; also the database pack's surface |
| **Pinecone** | index creation call / console config; namespaces per tenant | managed; namespace choice is the main lever | metadata filter, applied inside the search | upsert/delete API on the namespace |
| **Weaviate** | class/collection schema: `ef`, `efConstruction`, `maxConnections` | `ef` at query time | filtered vector search with `where` | object upsert/delete; native hybrid alongside |
| **Qdrant** | collection config: `hnsw_config` (`m`, `ef_construct`), payload indexes | `hnsw_ef` in search params | payload filter, filter-aware traversal | point upsert/delete; optimizer/compaction settings |
| **Milvus** | index params on the collection: `IVF*`/`HNSW`/`DiskANN`, `nlist` | `nprobe` / `ef` in search params | boolean expression filter | insert/delete + segment compaction |
| **Elasticsearch / OpenSearch kNN** | mapping: `dense_vector` / `knn_vector` with method params | `num_candidates` / `ef_search` | query filter combined with kNN | ordinary indexing; merge/force-merge |
| **FAISS (in-process)** | index construction in code: `IndexFlat*` / `IVF*` / `HNSW*` / `*PQ` | `nprobe` / `efSearch` set on the index object | none native — the caller filters, so post-filter by default | you own persistence, incremental add/remove, and rebuild |

Report the store's own parameter names in the findings. Translating `hnsw_ef` into "ef_search" in a Qdrant project makes the fix un-greppable.

## When to run

- On any diff touching index creation, index configuration, a vector migration, or the provisioning of a managed index.
- On a re-embed, an embedding-model upgrade, or a dimension change — each one can invalidate the metric, the dim, and every stored vector at once.
- When retrieval latency or recall is a question, as the *configuration* half; `retrieval-eval` is the measurement half.
- As the corpus crosses an order of magnitude — the exact-vs-ANN crossover and the sharding decision both move with n.
- Dispatched by `/ai-audit` (index axis) and `@ai-feature-reviewer` (dimension 3).
- NOT for chunking, top-k, reranking, or context assembly — those are `rag-pipeline` decisions owned by `@rag-architect`.

## Inventory first — the index as configured

Before any finding, write down what is actually there. An audit that cannot state the metric and the dimension has not read the index.

```
Store · index family · params (m / ef_construction / ef_search, or nlist / nprobe, or PQ config)
Vector dimension · distance metric · normalisation (are stored vectors L2-normalised?)
Embedding model + version the vectors came from
Corpus size (vectors) · growth rate if known · shard/namespace layout
Filter mode (pre-filter / post-filter / namespace-per-tenant) · which filters run in production
Refresh path (upsert on write? delete on delete? periodic rebuild/compaction? atomic rebuild on model change?)
Declared target (p95 latency · recall@k · memory/scale) — or UNSTATED
Last measured recall — or UNMEASURED
```

Every unknown in that block is either a finding or a `not read` — never blank.

## The five detectors

### 1. Brute-force / sequential scan at scale → `add-ann-index`

**Fingerprint:** a full-corpus distance computation per query — a flat/exact index, an in-app cosine loop over fetched rows, or a `vector` column with no index — on a corpus large enough that latency grows with `n`.

- BAD: an ORDER-BY-distance query over a growing table with no vector index behind it.
- GOOD: an ANN index sized to the corpus with a stated recall target; exact search **only** below a measured crossover.

Exact search is *correct and preferred* on a small corpus — the finding is not "no ANN index", it is "no ANN index **and** no measured crossover, on a corpus of size N". State N. If you cannot read N, report `not read` and say how (a count query, the store's stats endpoint).

### 2. Defaulted parameters, unstated recall → `tune-ann-params`

**Fingerprint:** an HNSW or IVF index created with the library's default `m` / `ef_construction` / `nlist`, a query-time `ef_search` / `nprobe` never set, and no recall number anywhere in the repo or the docs.

- BAD: index created with the store's defaults; no `p95 < X ms, recall@k ≥ Y` written down; no eval that would produce Y.
- GOOD: parameters chosen against a declared target and tuned against `retrieval-eval`, with the run table recorded.

**This is the pack's most common real finding and the easiest to fake.** A defaulted parameter is not automatically wrong — defaults are often reasonable. The finding is that *nobody chose*, which is provable from the absence of the target. Grade it on the two halves: target `UNSTATED`, measurement `UNMEASURED`. Never assert a recall consequence you did not measure.

### 3. Metric / normalisation / dimension mismatch → `fix-distance-metric`

**Fingerprint:** the index metric is not the one the embedding model was trained for; or cosine is configured over vectors that are not L2-normalised; or the index dimension differs from the model's output dimension (including a Matryoshka-truncated model whose truncation is applied on one side only).

- BAD: an L2 index for a model that expects cosine; or a cosine metric with raw, unnormalised vectors written by the ingest path.
- GOOD: metric + normalisation matched to the model, dim = embedding dim, both pinned beside the index definition.

Ranking corruption from a metric mismatch is invisible in every test that only checks "some results came back" — it degrades quality without failing. Cite three lines when you can: the index definition, the ingest write, and the query embed. Where the mismatch is real, the fix is an **atomic rebuild**, not a live parameter change.

### 4. Heavy pre-filter with a tight search breadth → `fix-filtered-recall`

**Fingerprint:** a selective metadata or tenant predicate applied to an ANN search whose `ef_search` / `nprobe` / `num_candidates` was tuned (or defaulted) for the unfiltered case.

- BAD: a `tenant_id` predicate over an HNSW graph at the default `ef` — the traversal strands in a sparse subgraph and recall craters, silently.
- GOOD: raise the breadth parameter under selective filters, or partition by namespace/collection per tenant so the filter becomes index selection rather than graph pruning; then verify recall **with the filter applied**.

Know which mode the store uses — post-filter loses count, pre-filter loses recall, and they need different fixes. The proof is `retrieval-eval`'s filtered-recall run; this skill reports the configuration that makes the collapse possible and whether anyone has ever measured it.

### 5. No refresh on upsert/delete, no rebuild path → `add-index-refresh`

**Fingerprint:** a write path that updates or deletes a source document without upserting or deleting its vectors; no periodic rebuild/compaction where the structure degrades under churn; no atomic rebuild procedure for a model/metric/parameter change.

- BAD: documents are edited and deleted upstream; the index only ever grows. Retrieval serves stale and deleted content — including content the user is no longer permitted to see.
- GOOD: upsert and delete wired into the write path, compaction scheduled where the structure needs it, and a documented atomic rebuild for re-embeds.

Deleted-content retrieval is the shape that turns a stale index into a **security** finding — when the deletion was a permission revocation or an erasure request, hand it to `@llm-security-reviewer` and the privacy owner rather than filing it as freshness.

## Output

```
vector-index-audit — <scope>

Index inventory:
  Store / family:     pgvector · HNSW
  Params:             m=16 (default) · ef_construction=64 (default) · ef_search=<never set>
  Dim / metric:       1536 · vector_cosine_ops · stored vectors L2-normalised: NOT READ
  Embedding model:    <pinned model>@<version> (from src/rag/embed.ts:11)
  Corpus:             ~2.1M vectors (SELECT count(*) — read at audit time)
  Filter mode:        pre-filter, tenant_id predicate in the WHERE clause
  Refresh:            upsert on write ✓ · delete on delete ✗ · rebuild/compaction ✗
  Declared target:    UNSTATED
  Last measured:      UNMEASURED

Findings (4):
  BLOCKER  fix-filtered-recall   migrations/0087_add_vector_index.sql:6
           `CREATE INDEX … USING hnsw (embedding vector_cosine_ops)`
           Selective tenant pre-filter over HNSW with ef_search never set. Filtered recall has never been
           measured → dispatch retrieval-eval for the filtered run before choosing a value.
  BLOCKER  add-index-refresh     src/corpus/documents.ts:140
           `await db.delete(documents).where(eq(documents.id, id))`
           Source delete with no matching vector delete — the index serves removed content indefinitely.
           If any delete is a permission revocation or an erasure request → HANDOFF @llm-security-reviewer.
  REQUEST  tune-ann-params       migrations/0087_add_vector_index.sql:6
           m / ef_construction left at library defaults; no recall/latency/scale target declared anywhere.
           Target UNSTATED, recall UNMEASURED. What would settle it: declare "p95 < X ms, recall@10 ≥ Y at
           2.1M vectors", then run retrieval-eval and record the run table.
  REQUEST  fix-distance-metric   src/rag/embed.ts:11
           Cosine metric configured; whether stored vectors are L2-normalised was NOT READ — the ingest
           path writes the raw model output with no normalisation call visible. Confirm before shipping.

Verdict: 2 BLOCKER · 2 REQUEST. Recall figures: none — this skill reports configuration, not measurement.
```

## False positives / gotchas

- **A flat index is right below the crossover.** Do not report `add-ann-index` on a small corpus; report the missing *measured crossover* instead, and say at what n it should be revisited.
- **Defaults are not automatically wrong.** The finding is the absent target, not the parameter value. Writing "ef_search=40 is too low" without a measurement is exactly the fabrication this skill forbids.
- **Managed stores hide the knobs.** Where a provider does not expose `m`/`ef`, `tune-ann-params` becomes "the target is undeclared and the tier/namespace choice is unjustified" — the target obligation survives even when the dial does not.
- **A per-tenant namespace already solves filtered recall.** If tenancy is index selection rather than a runtime predicate, detector 4 is `N-A` — say so rather than grading it green.
- **Normalisation may live in the model client**, not the ingest code. Read the embedding wrapper before reporting raw vectors under cosine; some SDKs normalise by default and some do not.
- **Dimension mismatches usually fail loudly** at write time — but a Matryoshka-truncated model applied on one side only produces two *valid* dimensions and a corrupt space. Check both sides.
- **Rebuild windows are an availability question.** Recommending an atomic rebuild on a live index without naming the swap mechanism (build beside, then repoint) is half a fix.
- **pgvector shares the relational surface.** Index build locks, migration safety, and `REINDEX` timing are the database pack's territory — cite the coupling, don't re-derive it.

## Halt conditions

- **A recall number this skill did not read from a real run** → forbidden. There is no such thing as an estimated recall here. Report `UNMEASURED` and dispatch `retrieval-eval`.
- **`PASS` on a target that was never declared** → forbidden; the verdict is `UNSTATED`. The target is the project's obligation (`vector-store-ops` §3), and its absence is the finding.
- **An inventory row left blank** → HALT. Every row is a value, `NOT READ` (with how to read it), or `N-A` with the reason.
- **A finding without its `<path:line>`** — index definition, migration, provisioning call, or write path → not emittable.
- **The hand-wave grep** — `etc.` / `…` / `might` / `probably` / `several similar` in a draft finding → STOP and re-enumerate.
- **Index unreachable / config not readable** (managed console-only settings, no infra-as-code) → report the axis `not run` with the reason. Never infer the configuration from the client library's defaults.
- **Grading the stale-index privacy consequence** → out of scope. Report the freshness defect; hand a revocation or erasure case to `@llm-security-reviewer` and the privacy owner.

## References

- `ai/patterns/vector-store-ops.md` — the pattern this skill mechanizes: exact-vs-ANN, index families and knobs, naming the target, pre/post-filter, hybrid at the index level, build/refresh/sharding. Its five detectors are this skill's five.
- `ai/patterns/rag-pipeline.md` — **boundary:** that pattern owns chunk → embed → retrieve → rerank *usage*; this skill audits the index *underneath* it. The embedding-model / distance-metric match surfaces in both.
- `retrieval-eval` — produces the recall number this skill refuses to invent, including the filtered run that proves or disproves detector 4. The two are a pair: configuration here, measurement there.
- `@rag-architect` — designs a new index (family, params, target, filter mode, refresh plan); this skill audits an existing one. Design there, audit here — the `@api-architect` ↔ `api-consistency-audit` relationship.
- `@ai-feature-reviewer` — dispatches this skill for dimension 3 on any diff touching the vector store.
- `@llm-security-reviewer` / `@tenant-isolation-reviewer` (security pack) — own the cross-tenant leak and the stale-permission read; detectors 4 and 5 hand across when the shape is a leak rather than a quality defect.
- **Cross-pack:** the **database** pack owns pgvector's relational surface — migration safety, index build locks, table-level scaling.
- `.claude/rules/ai-engineering-principles.md` — AI-6 (the index is tuned to a stated recall/latency/scale target; the metric matches the embedding model).
