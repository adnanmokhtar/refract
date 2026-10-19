# Capacity notes (2026-09 snapshot)

Row counts in production, for sizing indexes and workers.

| Table | Rows | Growth / month |
|---|---|---|
| `kb_article_chunks` (api) | 2.6 M | +140 k |
| `ticket_embeddings` (api) | 9.4 M | +600 k |
| `shared_playbook_chunks` (api) | 38 k | +2 k |
| `ticket_chunks` (rag) | 3.1 M | +210 k |
| `doc_chunks` (rag) | 1.2 M | +90 k |
| `faq_vectors` (rag) | 210 k | +15 k |
| `global_kb_chunks` (rag) | 4 k | migration only |

Workers: `quill-worker` runs 3 replicas x BullMQ concurrency 8. API: 4 replicas. RAG: 3 replicas.
Largest workspace: 41 % of `doc_chunks`; median workspace: 0.03 %.
