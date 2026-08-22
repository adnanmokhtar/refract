---
name: retrieval-eval
description: Measures the retrieval stage in isolation — loads or builds a labelled question→gold-chunk set, runs the project's OWN retriever, and reports recall@k, context precision/relevance, and filtered recall (recall with the tenant/permission predicate applied, where a pre-filter strands an HNSW traversal and recall craters silently), plus the retrieval-vs-generation split that says which stage actually failed. Also the tuning loop for top_k, chunk size, reranker on/off, and ef_search/nprobe. TRIGGER — before tuning any retrieval parameter, when a RAG answer is wrong and nobody knows which stage broke, and dispatched by /ai-audit, @rag-architect, @ai-feature-reviewer dimension 3, and /add-ai-feature Phase 7. ANTI-TRIGGERS (do NOT fire) — end-answer quality, faithfulness, or answer relevance (that is eval-run against the project's harness); ANN index configuration, params, metric, or refresh (that is vector-index-audit); a corpus with no labelled set (HALT with the construction recipe — never score a set the model wrote for itself); the cross-tenant leak judgment (that is @llm-security-reviewer LLM09:2026).
kind: skill
pack: ai-engineering
---

# Skill: retrieval-eval

## Premise

In a RAG system retrieval quality is the #1 failure mode, and an answer-only score cannot see it: a perfect prompt over the wrong chunks produces a confident wrong answer that scores badly for reasons nobody can attribute. This skill isolates the stage — it runs the project's **own** retriever over a labelled question→gold-chunk set and reports what came back, before any generation happens.

**Every number cites its `k`, its filter state, and its dataset version.** `recall@10 = 0.82 (tenant filter applied, set v3, 40 questions)` is a measurement; "recall is good" is a vibe, and `recall = 0.82` with no `k` is not emittable. **A `PASS` requires a declared target** — the recall/latency/scale target is a `vector-store-ops` §3 obligation the project owes, not a number this skill invents. Where no target was declared, the verdict for that metric is `UNSTATED`, and the finding is the absence.

This skill measures. It does not choose the chunker, the embedding model, or the index parameters — `@rag-architect` designs those, `vector-index-audit` audits them, and this skill is the loop they both tune against.

## Adapt to the codebase

Run the project's retriever exactly as production calls it — same embedding model, same query prefix, same filters, same top-k, same reranker. A measurement taken through a hand-rolled second retriever measures the second retriever.

| What to mirror | Where it lives | Why it must not be substituted |
|---|---|---|
| **The retriever entry point** | the function the feature calls (`retrieve()`, `search()`, a repository method, a framework retriever object) | measuring anything else measures nothing about production |
| **Embedding model + version + query prefix** | the seam that embeds queries; pinned alongside the index | a different model puts the query in an incompatible space; the score is meaningless |
| **Filters** | the tenant/ACL predicate, recency + type filters, namespace selection | filtered recall is a *different number* from unfiltered recall — see detector 3 |
| **top-k and the rerank stage** | retrieval config; reranker on/off and its own top-n | recall@k is defined by *that* k; a reranker changes precision, not first-stage recall |
| **Existing eval harness** | `promptfoo` / `deepeval` / `ragas` / LangSmith / a custom pytest suite | if the harness already scores retrieval, extend **it** — never stand up a second harness beside it |
| **The labelled set** | wherever the project keeps eval data, versioned + checked in | a score is attributable to (retriever config × dataset version) or to nothing |

Where the project's harness already has a retrieval scorer, this skill's job is to run it and read the per-case output — `eval-run` owns the harness invocation; this skill owns the retrieval-specific interpretation and the tuning loop.

## When to run

- Before tuning **any** retrieval parameter — `top_k`, chunk size/overlap, reranker on/off, `ef_search`/`nprobe`. Tuning without a recall number is guessing with extra steps.
- When a RAG answer is wrong and nobody knows whether retrieval or generation failed. This split is the reason the skill exists.
- On a re-embed, an embedding-model upgrade, a chunker change, or an index rebuild — each invalidates the previous number.
- Dispatched by `/ai-audit` (retrieval axis), `@rag-architect` (to prove a design), `@ai-feature-reviewer` (dimension 3), and `/add-ai-feature` Phase 7.
- NOT for end-answer quality — faithfulness and answer relevance are generation metrics scored by `eval-run` against the project's harness.

## The labelled set — build it before you measure

The asset is the set, not the score. A question→gold-chunk set is (question, the chunk id(s) a human confirmed answer it), versioned and checked in.

- **Seed from real questions.** Support tickets, search logs, the questions the feature was built for. Invented questions measure an invented distribution.
- **A human confirms each gold chunk.** Open the chunk; confirm it actually answers the question. This is the labour and it is not delegable to the model being tested.
- **Cover the three classes** the eval pattern names — representative, edge (multi-chunk answers, near-duplicate documents, answers that straddle a chunk boundary), and adversarial (questions the corpus genuinely cannot answer, whose gold answer is *nothing* — these prove the no-context guard).
- **Grow from real misses.** Every wrong answer traced to retrieval becomes a case with its gold chunk. Thirty confirmed cases beat three hundred generated ones.
- **Version it.** Bump on every add/change so a score is attributable to (retriever config × dataset version).

**Never let the model generate the questions and the gold labels and then score itself against them.** That measures the generator's self-consistency, not retrieval. If the only available set is synthetic, say so in the output — a synthetic set is a smoke test, not a gate.

## The four measurements

### 1. recall@k — did the needed chunk come back? → `add-retrieval-eval`

For each question, is the gold chunk in the top-k returned? Aggregate over the set. This is the ceiling on everything downstream: a chunk that was never retrieved cannot be cited, reranked, or answered from.

Report as `recall@<k> = <value> (<n> questions, set v<x>)`. Report the **misses individually** — question, gold chunk id, and what came back instead. The misses are the finding; the aggregate is the headline.

### 2. Context precision / relevance — was what came back worth the budget?

Of the chunks returned, what fraction are relevant? Low precision with high recall means the reranker or top-k is doing no work and the context window is being paid for noise. High precision with low recall means the chunker or the embedding is missing whole regions of the corpus.

Where the project's harness computes it, mirror its definition and say which definition you used — precision@k, mean average precision, and an LLM-judged context-relevance score are three different numbers with the same nickname.

### 3. Filtered recall — the number that hides the bug → `fix-filtered-recall`

**Run recall@k twice: once unfiltered, once with the tenant/permission predicate applied.** A heavy pre-filter over an HNSW graph can strand the traversal so it cannot reach enough neighbours — recall collapses and *nothing errors*. Post-filtering has the mirror-image failure: the ANN returns k, the filter removes most of them, and the caller silently gets three chunks where it asked for ten.

A gap between the two numbers is the finding. The fix is `vector-index-audit`'s territory (raise `ef`/`nprobe`, or partition by namespace); the *measurement* is this skill's, and without it the collapse is invisible. **A recall figure that does not state whether the filter was applied is not emittable.**

### 4. The retrieval-vs-generation split — which stage failed?

For each failing end-to-end case, ask one question: **was the gold chunk in the retrieved context?**

- **Not retrieved** → a retrieval failure. Tuning the prompt cannot fix it. Route to chunking, embedding, top-k, hybrid fusion, or the index.
- **Retrieved and the answer is still wrong** → a generation failure. Route to `prompt-audit`, the context assembly (ordering, budget, dedupe), or the no-context guard.

Report the split as a count over the failing cases. This single table is what stops a team from spending a week rewriting a prompt to fix a chunking bug.

## The tuning loop

Change **one** variable, re-run the set, record the number. Never two at once — a joint move is unattributable.

| Knob | Owner | What moves | Watch |
|---|---|---|---|
| `top_k` (first stage) | `rag-pipeline` | recall up, precision down, cost up | retrieve wide, rerank narrow — raising k without a reranker just adds noise |
| chunk size / overlap | `rag-pipeline` | both, non-monotonically | requires re-chunk + re-embed; the gold labels may need re-anchoring |
| reranker on/off, rerank-n | `rag-pipeline` | precision up, latency + cost up | does not raise first-stage recall — it cannot recover a chunk that was never fetched |
| hybrid fusion weight | `rag-pipeline` / `vector-store-ops` | recall on exact-term queries | the classic dense-only miss: names, codes, IDs, rare jargon |
| `ef_search` / `nprobe` | `vector-store-ops` | recall up, latency up | the primary lever under a heavy filter — tune it *with* the filter applied |

Record each run: knob, value, recall@k (filtered + unfiltered), precision, p95 latency, dataset version. That table is the evidence a target was tuned to, not defaulted into.

## Output

```
retrieval-eval — <feature> (retriever=src/rag/retrieve.ts, set v3 @ 40 questions, embed=<pinned model>)

Config under test: top_k=20 → rerank→5 · hybrid=dense+BM25 (RRF) · filter=tenant_id · ef_search=64

Per-metric (vs declared target):
  Metric                        Value   Target      Result
  recall@10 (unfiltered)        0.90    ≥ 0.95      FAIL (−0.05)
  recall@10 (tenant-filtered)   0.62    ≥ 0.95      FAIL — 0.28 below the unfiltered run
  context precision@5           0.71    (none)      UNSTATED — no target declared
  p95 retrieval latency         41 ms   < 50 ms     PASS

Misses (4 of 40, filtered run):
  - q "refund window for annual plans" → gold chunk billing/refunds#3 not in top-10; returned 3 chunks only (filter dropped 7).
  - q "SSO error code AUTH-419"        → gold chunk errors/auth#12 not returned; exact code query, dense-only miss.
  - q "who owns the staging cluster"   → gold chunk absent from the index (document deleted upstream, vector not deleted).
  - q "what is our uptime SLA"         → adversarial case, correctly returned nothing above threshold.

Retrieval vs generation (over 9 failing end-to-end cases):
  Gold chunk NOT retrieved:  6   → retrieval failure — fix the filter breadth + hybrid weight, not the prompt.
  Gold chunk retrieved:      3   → generation failure — route to prompt-audit + context assembly.

Findings:
  BLOCKER  fix-filtered-recall   filtered recall 0.62 vs 0.90 unfiltered — pre-filter strands the traversal at ef_search=64.
                                 → hand the fix to vector-index-audit (raise ef / namespace partition), re-run this set to confirm.
  REQUEST  add-retrieval-eval    context-precision target never declared; PASS on it is not emittable until it is.

Verdict: FAIL — 2 gated metrics below target. Dataset v3, 40 questions, human-labelled.
```

## False positives / gotchas

- **A small set is noisy.** With under ~30 questions one flipped case swings recall by several points. Report `n` beside every number and do not chase a 1-case delta.
- **Gold labels rot.** Re-chunking re-anchors chunk ids; a re-embed or a rebuild can renumber everything. A recall drop right after a chunker change may be the labels, not the retriever — re-verify a sample before believing it.
- **Recall@k and recall@k-after-rerank are different numbers.** The reranker reorders what the first stage fetched; it cannot add a chunk. Say which stage each number describes.
- **A question with several valid gold chunks** needs an any-of rule, or recall under-reports. Decide the rule once, write it into the set, and state it in the output.
- **Adversarial "no answer exists" cases invert the metric** — success is returning nothing above threshold. Score them separately from recall or they poison the aggregate.
- **Latency measured on a warm cache is not p95.** If the number came from a handful of local calls, mark it `INDICATIVE`, not p95.
- **A perfect score is a smell.** 1.00 recall on a set the retriever was tuned against is overfitting to the eval; hold cases out and grow from real misses.

## Halt conditions

- **No labelled question→gold-chunk set** → HALT. Do not synthesize one and score against it. Emit the construction recipe above (seed from real questions, human-confirm each gold chunk, cover representative/edge/adversarial, grow from misses) and report the retrieval axis as `UNVERIFIED — no labelled set`. This absence *is* the `add-retrieval-eval` finding.
- **A recall figure without its `k`, its `n`, and its filter state** → not emittable. Re-run and capture them.
- **A `PASS` against a target that was never declared** → forbidden. Report `UNSTATED` and name the obligation (`vector-store-ops` §3: state p95, recall@k, and scale before tuning).
- **An invented recall or latency number** → forbidden. Every figure comes from a real run of the project's retriever over the labelled set. A stage that could not be run is reported `not run`, never OK.
- **Scoring through a second retriever** you stood up for the measurement → HALT; mirror the project's entry point or report that you could not reach it.
- **Two knobs moved between runs** → the delta is unattributable; discard it and re-run one at a time.
- **Grading the cross-tenant leak** → out of scope. A filtered-recall collapse is a retrieval-correctness finding here; a filter that is *absent* on a multi-tenant corpus is a security finding handed to `@llm-security-reviewer` (LLM09:2026) and `@tenant-isolation-reviewer`.

## References

- `ai/patterns/rag-pipeline.md` — "Evaluate the pipeline, per stage" is the section this skill implements; `add-retrieval-eval` is its verb. Chunking, top-k, hybrid, reranking, and assembly decisions are owned there.
- `ai/patterns/vector-store-ops.md` — §3 (name the target) and §4 (pre/post-filter recall collapse) are the *why* behind measurements 3 and the tuning loop's `ef`/`nprobe` row.
- `ai/patterns/evals.md` — "Task-specific metrics → RAG": context recall, context precision, faithfulness, answer relevance. The first two are this skill's; the last two are `eval-run`'s.
- `eval-run` — runs the project's harness end-to-end and scores the answer; this skill isolates the stage before it. If the harness already scores retrieval, `eval-run` invokes it and this skill reads the per-case output.
- `vector-index-audit` — owns the *fix* for a filtered-recall collapse and the index config this skill measures through; it never invents a recall number, it asks this skill for one.
- `@rag-architect` — designs the pipeline and the labelled set; dispatches this skill to prove the design.
- `/add-eval-set` — builds the harness when there is none; `/ai-audit` composes this skill into the retrieval axis.
- `.claude/rules/ai-engineering-principles.md` — AI-6 (retrieval is tenant-filtered AND quality-eval'd; the index is tuned to a stated recall target).
