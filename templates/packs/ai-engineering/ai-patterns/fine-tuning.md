---
name: fine-tuning
description: 'Pattern: Fine-tuning — the last resort, eval-gated against the prompted baseline'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: Fine-tuning — the last resort, eval-gated against the prompted baseline

> **Hard rule:** Fine-tuning is the **LAST resort**, reached only after prompt-engineering and RAG are exhausted. It is justified by a **specific failure prompting cannot fix** — consistent format/style adherence, or latency/cost at high volume — never by a vague "make it better." Fine-tuning buys **behavior**, not knowledge: injecting facts a model should look up is **RAG's job**, and fine-tuning to add knowledge is forbidden. Every fine-tune MUST **beat the prompted baseline on a held-out eval set** before it ships, and the model, its dataset, and that eval are **versioned together**. A fine-tune with no baseline eval, or with train/eval leakage, is not a model — it's an unmeasured guess.

**When to apply**
- You have a well-specified task where a strong prompt (few-shot included) and, where relevant, RAG **still** miss a bar you can measure: inconsistent output format/schema, tone/style that won't hold, or a domain behavior the base model resists.
- Volume is high enough that a **shorter prompt** (fewer few-shot tokens, smaller model) via a fine-tune pays for itself in latency and per-call cost.
- You can produce a **curated, representative dataset** and a **held-out eval** that proves the fine-tune beats the prompted baseline.

**When NOT to apply**
- You haven't seriously tried prompt-engineering (structure, few-shot, structured output, temperature) — do that first; it's faster, cheaper, and reversible.
- The gap is **missing knowledge / freshness** (facts, docs, tenant data) — that's **RAG**, not fine-tuning. A fine-tune bakes a snapshot that goes stale and can't cite sources.
- You have no eval set — you cannot prove the fine-tune helps, so you cannot ship one responsibly.
- The task or dataset is still churning — fine-tuning a moving target burns money re-training on every change.

**Halt conditions / mandatory cites**
- A fine-tune **proposed with no prompt/RAG baseline tried** MUST be cited at `<path:line>` — the last resort was reached first.
- Fine-tuning **to inject knowledge/facts** (that RAG should retrieve) MUST be flagged — wrong tool; the knowledge goes stale and unattributable (cross-link `rag-pipeline`).
- A shipped/proposed fine-tune with **no held-out eval proving it beats the prompted baseline** MUST be cited — the whole justification is unmeasured (cross-link `evals`).
- **Train/eval leakage** — eval examples (or near-duplicates) present in the training set — MUST be flagged; the win is fictitious.
- An **unversioned** model / dataset / eval (can't say which data produced which model) MUST be cited — the fine-tune is unreproducible.

## 1. The decision ladder — earn your way down

Escalate only when the rung below is genuinely exhausted, each proven by the eval set:

1. **Prompt** — role, task, constraints, structured output, temperature 0. Cheapest, instant, reversible.
2. **Few-shot** — worked examples in the prompt when the format/edge-cases need demonstration. Still reversible; costs tokens per call.
3. **RAG** — when the gap is *knowledge* the model lacks. Grounds answers in a live, updatable, citable corpus.
4. **Fine-tune** — only when the gap is *behavior* (format/style/latency/cost) that 1–3 can't close on the eval. The last rung.

If you're adding ever-more few-shot examples to hold quality, that's the **signal** to fine-tune (bake the demonstration into weights) — not to grow an unbounded prompt.

## 2. What fine-tuning actually buys

- **Behavior, format, and style** — reliable adherence to an output shape, house tone, a labeling boundary, a response protocol the base model keeps drifting from.
- **Latency + cost at volume** — a fine-tuned smaller model can match a prompted larger one with a **fraction of the prompt tokens** (the examples are in the weights), cutting per-call cost and latency.
- **NOT fresh knowledge.** Weights are a frozen snapshot: they go stale, can't cite a source, and can't be scoped per-tenant. Knowledge is retrieval's job. Fine-tune the *how*, retrieve the *what*.

## 3. Dataset curation — quality over quantity

The dataset **is** the fine-tune; a bigger dirty set loses to a smaller clean one.

- **Representative** of real production inputs — cover the distribution and the hard edge/negative cases, not just the easy middle.
- **Consistent labels/targets** — noisy or contradictory targets teach noise. One correct shape per input.
- **Deduplicated** — near-duplicates over-weight a slice and inflate apparent size without adding signal.
- **No eval-set leakage** — hold out the eval set (and near-duplicates of it) BEFORE training. Overlap makes the eval score a lie.
- **Right size** — hundreds of clean, diverse examples usually beat tens of thousands of scraped ones; start small, grow from measured misses.

## 4. LoRA / PEFT vs full fine-tune

- **LoRA / PEFT (adapter)** — trains a small set of added weights, freezing the base. Cheap, fast, tiny artifacts, swappable/stackable adapters. The **default** for open models: start here.
- **Full fine-tune** — updates all weights. More capacity but far costlier, risks catastrophic forgetting, and produces a large artifact. Reserve for when an adapter provably can't reach the bar on the eval.
- **Hosted-provider fine-tunes** abstract this choice — you supply data, they train + host the variant.

## 5. The eval gate — beat the prompted baseline or don't ship

- The bar is not "the fine-tune is good" — it's **"the fine-tune beats the strongest prompted baseline on the held-out set."** Score both, same eval, and diff (see `evals`).
- If the fine-tune doesn't clear the baseline, the prompt wins: cheaper, faster to change, no training pipeline. Ship the prompt.
- Watch for **regression on adjacent tasks** (over-specialization / forgetting) — eval the general capabilities you still need, not only the target task.
- Gate model *upgrades* the same way: a new base model re-runs the eval before the fine-tune is rebuilt on it.

## 6. Versioning, drift, and cost

- **Version the triple together:** model/adapter id + version, the exact training dataset (hash/version), and the eval + its scores. Any output must trace back to which data produced which model. An unversioned fine-tune is unreproducible.
- **Drift + re-tune cadence** — the world and the input distribution shift; the frozen weights don't. Monitor production quality against the eval and set a **re-tune trigger** (metric drop / distribution shift), not a blind schedule.
- **Cost** — account for the full loop: data curation (the real cost), training compute, eval, hosting the variant, and re-training on every dataset/base change. Fine-tuning is an ongoing commitment, not a one-off.

## Adapt to your stack

- **OpenAI** — fine-tuning API (upload JSONL, create job, call the returned model id); versioned model names; eval before promotion.
- **Anthropic / Claude** — no general customer fine-tuning surface; reach the same outcomes with **prompt-engineering + few-shot + RAG** (and prompt caching for the stable example block). If you assumed a Claude fine-tune, that's the halt — use the prompt/RAG ladder instead.
- **Open models + LoRA/PEFT** — axolotl / unsloth / PEFT for adapter training; you own the eval, versioning, and hosting.
- **Managed** — Together / Fireworks / Bedrock (and similar) host the train + serve loop for open/base models; still your job to bring the curated dataset and the held-out eval gate.

## Detectors (cite-or-halt)

- **Fine-tune proposed with no prompt/RAG baseline** →
  - BAD: "quality's low, let's fine-tune" with no strong prompt or RAG attempt on record.
  - GOOD: prompt + few-shot (+ RAG where knowledge-bound) tried and scored first; fine-tune only after they plateau below the bar.
  - → `try-prompt-baseline-first`
- **Fine-tune to inject knowledge** →
  - BAD: training on the docs/FAQ so the model "knows" them — stale, unattributable, un-scopable.
  - GOOD: retrieve that knowledge via RAG; reserve fine-tuning for behavior/format.
  - → `move-knowledge-to-rag` (cross-link `rag-pipeline`)
- **No held-out eval proving it beats baseline** →
  - BAD: fine-tune shipped on vibes; no baseline comparison on a held-out set.
  - GOOD: fine-tune vs prompted baseline scored on the same held-out eval; ship only if it wins (cross-link `evals`).
  - → `add-baseline-eval-gate`
- **Train/eval leakage** →
  - BAD: eval examples (or near-duplicates) sitting in the training data → inflated score.
  - GOOD: eval set held out and de-duplicated against the training set before training.
  - → `fix-train-eval-leakage`
- **Unversioned model / dataset / eval** →
  - BAD: a fine-tuned model with no record of which dataset version + eval produced it.
  - GOOD: model + dataset hash + eval scores versioned as one artifact, reproducible.
  - → `version-model-dataset-eval`

**Closure verbs:** `try-prompt-baseline-first`, `move-knowledge-to-rag`, `add-baseline-eval-gate`, `fix-train-eval-leakage`, `version-model-dataset-eval`.

## Related

- `prompt-engineering` — the **first** resort and the baseline every fine-tune must beat; a growing few-shot block is the signal to fine-tune, not to keep growing the prompt.
- `rag-pipeline` — the resort for **knowledge/freshness** gaps; fine-tuning must never take over RAG's job of injecting facts.
- `evals` — owns the measurement: the held-out eval set, the baseline diff, and the ship/no-ship gate. A fine-tune is only "done" once it clears that gate.
- `llm-gateway` — the fine-tuned model id + version is what the gateway routes, pins, and cost-tracks alongside its prompted alternative.
- Review `@ai-feature-reviewer` — reviews the last-resort justification, the baseline diff, and the dataset/model versioning on any fine-tune PR.
