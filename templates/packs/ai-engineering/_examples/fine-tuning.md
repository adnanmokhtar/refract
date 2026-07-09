---
name: fine-tuning
description: 'Pattern: Fine-tuning — the last resort, eval-gated against the prompted baseline'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: Fine-tuning — the last resort, eval-gated against the prompted baseline

> **Hard rule:** Fine-tuning is the **LAST resort**, reached only after prompt-engineering and RAG are exhausted, and justified by a **specific failure prompting can't fix** (format/style adherence, or latency/cost at volume) — never a vague "make it better." It buys **behavior, not knowledge**: injecting facts is RAG's job, and fine-tuning to add knowledge is forbidden. Every fine-tune MUST **beat the prompted baseline on a held-out eval** before shipping, and the model + dataset + eval are **versioned together**.

**When to apply** — a well-specified task where a strong prompt (+ few-shot, + RAG where relevant) still misses a *measurable* bar (inconsistent format, tone that won't hold), or volume is high enough that a shorter-prompt fine-tune pays for itself in latency/cost. You can produce a curated dataset + a held-out eval.

**When NOT to apply** — you haven't seriously tried prompt-engineering (do that first; faster, cheaper, reversible); the gap is missing knowledge/freshness (that's RAG — a fine-tune bakes a stale, uncitable snapshot); no eval set; a still-churning task/dataset.

## The decision ladder — earn your way down

1. **Prompt** (role, constraints, structured output, temp 0) — cheapest, instant, reversible.
2. **Few-shot** — worked examples when format/edge-cases need demonstration.
3. **RAG** — when the gap is *knowledge* the model lacks (live, updatable, citable).
4. **Fine-tune** — only when the gap is *behavior* (format/style/latency/cost) that 1–3 can't close on the eval.

An ever-growing few-shot block is the **signal** to fine-tune (bake it into weights), not to keep growing the prompt.

## Dataset + method

- The dataset **is** the fine-tune: representative of prod inputs, consistent labels, deduplicated, **no eval-set leakage** (hold out the eval + near-dupes BEFORE training). Hundreds of clean examples beat tens of thousands of scraped ones.
- **LoRA / PEFT (adapter)** is the default for open models — cheap, swappable, tiny artifacts. Full fine-tune only when an adapter provably can't reach the bar. Hosted-provider fine-tunes abstract the choice.

## The eval gate — beat the prompted baseline or don't ship

Score the fine-tune AND the strongest prompted baseline on the **same held-out set**; ship only if the fine-tune wins (see `evals`). Watch for regression on adjacent tasks (over-specialization). Version the triple: model/adapter id + dataset hash + eval scores — an unversioned fine-tune is unreproducible. Set a re-tune trigger on drift, not a blind schedule.

> Note: some providers (e.g. Claude) have no general fine-tuning surface — reach the same outcome with prompt + few-shot + RAG (and prompt caching for the stable example block).

## Detectors (cite-or-halt)

- **Fine-tune proposed with no prompt/RAG baseline** → `try-prompt-baseline-first`
- **Fine-tune to inject knowledge** (stale, unattributable) → `move-knowledge-to-rag` (cross-link `rag-pipeline`)
- **No held-out eval proving it beats baseline** → `add-baseline-eval-gate` (cross-link `evals`)
- **Train/eval leakage** (inflated score) → `fix-train-eval-leakage`
- **Unversioned model / dataset / eval** → `version-model-dataset-eval`

**Closure verbs:** `try-prompt-baseline-first`, `move-knowledge-to-rag`, `add-baseline-eval-gate`, `fix-train-eval-leakage`, `version-model-dataset-eval`.

## Related

- `prompt-engineering` — the first resort and the baseline every fine-tune must beat.
- `rag-pipeline` — the resort for knowledge/freshness gaps; fine-tuning must never take over RAG's job.
- `evals` — owns the held-out eval, the baseline diff, and the ship/no-ship gate.
- `llm-gateway` — the fine-tuned model id + version is what the gateway routes and cost-tracks.
- Review `@ai-feature-reviewer` — reviews the last-resort justification, baseline diff, and versioning.
