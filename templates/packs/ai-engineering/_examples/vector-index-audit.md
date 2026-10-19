---
name: vector-index-audit
kind: example
pack: ai-engineering
description: "ANN index vs a stated target: exact scan at scale, default params, metric/dim mismatch, filtered recall, stale vectors."
---

# Skill: vector-index-audit

## Premise

Every ANN index trades recall for latency and memory, and a wrong neighbour never errors. This skill reads the index as configured (word-bounded store lanes: pgvector `vector(N)` / `USING hnsw` / `vector_*_ops` / `<=>`, Pinecone, Qdrant, Weaviate, Chroma, Milvus, OpenSearch kNN, FAISS, LangChain / LlamaIndex stores) and reports the gap between what was declared and what was built. "Tuned to a recall target" needs both a written target and a measurement; otherwise `UNSTATED` / `UNMEASURED`. It never invents a recall: `retrieval-eval` measures.

## Boundaries

- Boundary: tenant / ACL scope, filter value source, provenance, semantic cache (RG-1…5) → security `llm-trust-scan` §6 and `@tenant-isolation-reviewer` when installed; counted, never graded. Measuring recall → `retrieval-eval`; pgvector build locks and migrations → the database pack.

## Inventory first — the index as configured

Store · family · params · dimension · metric · normalisation · embedding model · corpus size · filter mode · refresh path · declared target (or UNSTATED) · last measured recall (or UNMEASURED). Every unknown is a value, `NOT READ` with how, or `N/A`.

## Scans for

| § | Class | Default | Oracle |
|---|---|---|---|
| 1 | IX-1 exact scan above the measured crossover (`add-ann-index`) | medium | V539 |
| 2 | IX-2 defaulted params, no target, no measurement (`tune-ann-params`) | low | V539 |
| 3 | RG-8 metric / normalisation / dimension / model mismatch (`fix-distance-metric`) | medium | V539 |
| 4 | RG-6 selective filter with unfiltered breadth (`fix-filtered-recall`) | medium | V539 |
| 5 | RG-7 source delete with no vector delete (`add-index-refresh`) | high on revocation | V539 |
| R | RG-1…5 | routed | owner's |

## Output

```
vector-index-audit — lanes: pgvector (migrations)
Index: pgvector · HNSW · defaults · 1536 · vector_l2_ops · target UNSTATED · recall UNMEASURED
1. services/docs/delete.py:41  [report-with-fix]  high  §5 source delete leaves the vectors; served after revocation. Verb: add-index-refresh
Class coverage: §1–§5 checked | N/A (no vector store) | blocked (<reason>)
```

## When to run

On any diff touching an index definition, a vector migration, provisioning, the embedding model, the ingest path, or a delete / revoke path of indexed documents; on every whole-repo `/ai-audit`; as the corpus crosses an order of magnitude.

## Halt conditions

- A recall number not read from a real `retrieval-eval` run, a PASS on an undeclared target, or a blank inventory row → forbidden.
- Console-only config → `not run`, never inferred from library defaults. Tenancy is routed. High rows pass `refute-before-report.md` first. Never "no findings" without the coverage block.
