---
name: retrieval-eval
kind: example
pack: ai-engineering
description: Measures the retrieval stage in isolation — recall@k filtered and unfiltered, context precision, and the retrieval-vs-generation split — against a labelled question→gold-chunk set, plus the tuning loop.
---

# Skill: retrieval-eval

## Premise

Retrieval quality is the #1 RAG failure mode and an answer-only score cannot see it. This skill runs the project's **own** retriever over a labelled question→gold-chunk set and reports what came back, before generation.

**Every number cites its `k`, its filter state, and its dataset version.** `recall@10 = 0.82 (tenant filter applied, set v3, n=40)` is a measurement; `recall = 0.82` is not emittable. **A `PASS` requires a declared target** — that is a `vector-store-ops` §3 obligation the project owes, not a number this skill invents. No target ⇒ `UNSTATED`, and the absence is the finding.

## Adapt to the codebase

Run the retriever exactly as production calls it — same entry point, same embedding model + query prefix, same filters, same top-k, same reranker. A hand-rolled second retriever measures the second retriever. Where the project's harness already scores retrieval, `eval-run` invokes it and this skill interprets the per-case output.

## When to run

- Before tuning **any** retrieval parameter; when a RAG answer is wrong and nobody knows which stage broke; after a re-embed, chunker change, or index rebuild.
- Dispatched by `/ai-audit`, `@rag-architect`, `@ai-feature-reviewer` dim 3, `/add-ai-feature` Phase 7.
- NOT for end-answer faithfulness / answer relevance — that is `eval-run`.

## The labelled set — build it before you measure

Seed from real questions; **a human confirms each gold chunk**; cover representative / edge (multi-chunk, straddling answers) / adversarial (questions the corpus cannot answer — gold answer is *nothing*); grow from real misses; version it. Thirty confirmed cases beat three hundred generated ones. **Never let the model write the questions and the gold labels and then score itself** — that measures self-consistency. A synthetic set is a smoke test, not a gate, and must be labelled as such in the output.

## The four measurements

1. **recall@k** → `add-retrieval-eval`. Is the gold chunk in the top-k? Report misses individually — question, gold chunk id, what came back instead. The misses are the finding.
2. **Context precision / relevance.** Low precision + high recall = the reranker or k is doing no work. High precision + low recall = the chunker or embedding misses whole regions. Say which definition you used.
3. **Filtered recall** → `fix-filtered-recall`. **Run recall twice — with and without the tenant/permission predicate.** A pre-filter can strand an HNSW traversal and recall craters silently; post-filtering silently returns fewer than k. The gap is the finding; the fix is `vector-index-audit`'s.
4. **Retrieval vs generation.** For each failing case: was the gold chunk in the context? Not retrieved → retrieval failure (no prompt edit fixes it). Retrieved and still wrong → generation failure (`prompt-audit`, assembly, no-context guard). This table stops a week spent rewriting a prompt to fix a chunking bug.

## The tuning loop

Change **one** variable, re-run, record. `top_k` (recall up, precision down) · chunk size/overlap (needs re-chunk + re-embed; labels may need re-anchoring) · reranker (precision only — it cannot recover an unfetched chunk) · hybrid weight (exact terms, codes, names) · `ef_search`/`nprobe` (the primary lever under a heavy filter — tune it *with* the filter on). Record knob, value, filtered + unfiltered recall, precision, p95, dataset version.

## Output

```
retrieval-eval — <feature> (set v3, 40 questions, top_k=20→rerank 5, filter=tenant_id, ef_search=64)

  recall@10 unfiltered      0.90   target ≥0.95   FAIL
  recall@10 tenant-filtered 0.62   target ≥0.95   FAIL — 0.28 below the unfiltered run
  context precision@5       0.71   (none)         UNSTATED — no target declared
  p95 retrieval latency     41 ms  target <50 ms  PASS

Misses (4/40): "SSO error AUTH-419" → dense-only miss on an exact code · "who owns staging" → document
deleted upstream, vector never deleted · "uptime SLA" → adversarial, correctly returned nothing.

Retrieval vs generation (9 failing cases): 6 gold chunk NOT retrieved · 3 retrieved but answered wrong.

BLOCKER fix-filtered-recall — pre-filter strands the traversal at ef_search=64 → hand to vector-index-audit.
```

## False positives / gotchas

- Under ~30 questions one flipped case swings recall — report `n` beside every number.
- Gold labels rot: re-chunking renumbers chunk ids. A drop right after a chunker change may be the labels.
- recall@k and recall-after-rerank are different numbers — say which stage.
- Multi-gold questions need an any-of rule, stated in the set and the output.
- Adversarial "no answer" cases invert the metric — score them separately.
- Warm-cache latency is not p95 — mark it `INDICATIVE`.
- A perfect score is a smell: overfitting to the eval.

## Halt conditions

- **No labelled set** → HALT with the construction recipe; report `UNVERIFIED — no labelled set`. That absence *is* the `add-retrieval-eval` finding. Never synthesize and score.
- A recall figure without `k`, `n`, and filter state → not emittable.
- `PASS` against a target that was never declared → forbidden (`UNSTATED`).
- An invented recall or latency number → forbidden; a stage that could not run is `not run`.
- Scoring through a second retriever, or two knobs moved between runs → discard and re-run.
- Grading the cross-tenant leak → `@llm-security-reviewer` (LLM08) / `@tenant-isolation-reviewer`.

## References

- `ai/patterns/rag-pipeline.md` ("Evaluate the pipeline, per stage"), `vector-store-ops.md` §3/§4, `evals.md`; skills `eval-run`, `vector-index-audit`; `@rag-architect`; `/add-eval-set`, `/ai-audit`; `.claude/rules/ai-engineering-principles.md` (AI-6).
