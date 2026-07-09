---
name: evals
description: 'Pattern: Evals — the regression gate for LLM features'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: Evals — the regression gate for LLM features

> **Hard rule:** Every LLM feature ships with a **versioned eval dataset** and a **CI regression gate**. LLM output is non-deterministic — you CANNOT eyeball regressions the way you diff a pure function. A prompt tweak, a model upgrade, a temperature change, or a retrieval change can silently degrade quality on inputs you never re-tested. Evals are the analog of tests for LLM features: a golden set of cases + scorers + a baseline the build must beat. "I tried a few prompts and it looked good" is not an eval. An LLM feature with no eval set is untested code.

**When to apply**
- Any feature whose output is produced by an LLM (generation, extraction, classification, summarization, RAG answer, agent action).
- Before shipping ANY change to a prompt, model, temperature, retrieval config, or few-shot set — the change must be evaluated against the set, not spot-checked.
- Any feature with a correctness or safety bar (a wrong extraction writes bad data; a wrong classification routes a ticket wrong; a hallucinated RAG answer misinforms a user).

**When NOT to apply**
- A one-off, throwaway script with a human reading every output before it's used — document that it's un-gated; don't build a harness for a script you'll delete.
- Deterministic, non-LLM code — that's what unit tests are for. Evals are specifically for the stochastic boundary.

**Halt conditions / mandatory cites**
- An LLM call site with NO corresponding eval dataset MUST be cited at `<path:line>` — "it's tested manually" is not coverage.
- A prompt / model / temperature / retrieval change in the diff with NO eval-diff (before/after scores) MUST be flagged — you cannot approve a quality change you didn't measure.
- An LLM-as-judge scorer with no written rubric, or one judged by the SAME model that produced the output, MUST be cited — self-preference + no rubric = a meaningless score.
- An eval set that has never grown from a production failure (no dated cases traceable to real incidents) is a static set rotting — cite the ingestion gap.
- A "passing" CI eval job that does not actually fail the build below a baseline threshold is enforcement theater — cite the gate that doesn't gate.

## The eval dataset (golden set)

The dataset is the asset — more valuable than any single prompt. It is **code**: versioned in the repo (or a versioned store), reviewed in PRs, and it grows over time.

- **Three case classes**, deliberately balanced:
  - **Representative** — the typical, high-frequency inputs the feature actually sees in production.
  - **Edge** — boundary cases: empty input, very long input, ambiguous input, multiple valid answers, unusual formats, non-English.
  - **Adversarial** — inputs designed to break it: prompt-injection attempts, contradictory context, out-of-scope questions, inputs that SHOULD produce "I don't know" / a refusal.
- **Each case = input + expected** (a gold answer, an assertion set, or a rubric — depending on scorer). Store the expected outcome, not just the input.
- **Grows from prod failures — this is the flywheel.** Every real-world failure (a bug report, a bad output caught in monitoring, a thumbs-down) becomes a new eval case with the correct expected output. The set that never grows is the set that stops catching real regressions.
- **Versioned.** Pin a dataset version; when you add/change cases, bump it, so a score is always attributable to (prompt version × model × dataset version).
- **Sized honestly.** Dozens of good cases beat thousands of noisy ones. Start small and representative; grow from incidents.

## Scorer types

Match the scorer to the task. Most features use **several** scorers per case.

| Scorer | How | Use for | Cost / reliability |
|---|---|---|---|
| **Exact / normalized match** | String/number equality after normalization | Classification labels, extracted IDs, enum outputs, structured fields | Cheap, deterministic — prefer whenever the answer is closed-form |
| **Assertion / programmatic** | Code asserts properties: valid JSON, matches schema, contains/omits a substring, in-range number, cites a real source id | Structured output, "must include the disclaimer", "must not name a competitor" | Cheap, deterministic — the workhorse |
| **Semantic similarity** | Embedding cosine (or ROUGE/BLEU for legacy) vs a reference | Free-text answers where wording varies but meaning must match | Cheap-ish; a similarity threshold is fuzzy — calibrate it |
| **Model-graded / LLM-as-judge** | A separate LLM scores the output against a **rubric** | Open-ended generation, "is this answer faithful / helpful / on-tone", pairwise A/B | Expensive, powerful, and **biased — see below** |
| **Human** | A person rates against a rubric | Gold labels, calibrating the judge, high-stakes launches | Slow, expensive, the ground truth — sample, don't scale it |

**Prefer the cheapest scorer that captures the requirement.** Reach for an LLM judge only when exact/assertion/similarity genuinely can't express the criterion.

## LLM-as-judge — powerful, and full of traps

When you must grade open-ended output, an LLM judge scales where humans can't — but it has systematic biases you MUST design around:

- **Needs an explicit rubric.** "Rate 1–5" with no criteria produces noise. Give the judge a concrete rubric with anchored levels and, ideally, the reference answer. Ask for a short justification BEFORE the score (chain-of-thought raises agreement with humans).
- **Position bias.** In pairwise A-vs-B grading, judges favor whichever answer came first (or second). Mitigate: run both orderings and average, or randomize position per case.
- **Self-preference / self-enhancement bias.** A model rates ITS OWN outputs (and outputs from its family) higher. **Never let the same model judge its own generations.** Use a different — ideally stronger — model as the judge, or a human-calibrated judge.
- **Verbosity / sycophancy bias.** Judges over-reward longer, more confident, more agreeable answers. Control for length in the rubric; penalize unsupported confidence.
- **Calibrate the judge against humans.** Periodically sample judged cases and have a human grade them; measure judge-vs-human agreement. A judge you never validate is a metric you can't trust.
- **Judge on a low temperature** and version the judge prompt + judge model — a judge change silently shifts every score.

## Task-specific metrics

Beyond generic correctness, measure what the task actually requires:

- **RAG / grounded generation:**
  - **Faithfulness / groundedness** — is every claim in the answer supported by the retrieved context (no hallucination beyond the sources)?
  - **Answer relevance** — does the answer actually address the question?
  - **Context relevance / precision** — were the retrieved chunks actually relevant to the question? (This isolates *retrieval* failures from *generation* failures — see `rag-pipeline`.)
  - **Context recall** — did retrieval fetch the chunks needed to answer? (Requires labeled gold contexts.)
- **Classification / extraction:** **precision, recall, F1** per class; a confusion matrix to see which classes bleed into each other. Accuracy alone hides class imbalance.
- **Summarization:** faithfulness (no invented facts) + coverage (key points retained) + conciseness.
- **Agents:** task success rate, tool-call correctness, step count / cost per task (see `agent-design`).

## The regression gate (evals as CI)

This is the mechanism that makes evals real, not decorative.

- **CI runs the full eval set** on every change to a prompt, model, retrieval config, or the harness itself.
- **The build FAILS if the aggregate score drops below a committed baseline** (or below `baseline − epsilon` to allow for judge noise). This is the exact analog of a failing unit test.
- **Store the baseline in the repo** (a checked-in scores file) so a regression is a visible diff, and an intentional baseline change is a reviewed PR.
- **Report an eval-diff on the PR** — per-metric before/after, and which specific cases regressed — so a reviewer sees the quality impact, not just green/red.
- **Budget cost + time** — an eval run that's too slow/expensive gets skipped, which defeats it. Use a fast tier (assertions + exact match) on every PR and a full tier (with the LLM judge) nightly / pre-release if needed.

## Offline vs online evals

- **Offline** — the CI eval set above. Fast, repeatable, catches regressions BEFORE ship. This is the gate.
- **Online** — measure the change in production:
  - **A/B test** the new prompt/model against the current one on live traffic; compare an outcome metric (task completion, thumbs-up rate, escalation rate).
  - **Guardrail metrics** — even in an A/B for quality, watch cost/request, p95 latency, refusal rate, and safety-flag rate so a "better" variant that doubled cost or latency is caught.
  - **Feed failures back** — production misses become new offline cases (the flywheel). Online tells you WHAT broke; offline stops it recurring.

## Detectors (cite-or-halt)

- LLM call site (`grep` for the provider client / prompt template) with **no eval dataset** referencing it →
  - BAD: a `summarize()` / `classify()` / `answer()` function shipped, tested only by "I ran it on a few examples."
  - GOOD: a versioned dataset of representative + edge + adversarial cases, scored in CI, gating the build.
  - → `add-eval-set`
- Prompt / model / temperature / retrieval change in the diff with **no eval-diff** →
  - BAD: PR edits the system prompt; description says "improved wording"; no scores.
  - GOOD: PR shows before/after per-metric scores and the cases that moved.
  - → `require-eval-diff`
- **LLM-as-judge with no rubric**, or the **same model judging itself** →
  - BAD: `judge = same_model; score = judge("rate this 1-5: ...")`.
  - GOOD: a stronger/different judge model, an anchored rubric, justification-before-score, position-bias mitigation, human-calibrated.
  - → `fix-judge-rubric`, `swap-judge-model`
- **Eval set that never grows from prod failures** →
  - BAD: a static fixtures file untouched since creation while incidents keep happening.
  - GOOD: dated cases traceable to real failures; a documented path from incident → new case.
  - → `backfill-eval-from-incident`
- **CI "eval" that doesn't fail the build** below baseline →
  - BAD: an eval script that prints a score and always exits `0`.
  - GOOD: a committed baseline + a threshold check that exits non-zero on regression.
  - → `wire-regression-gate`

**Closure verbs:** `add-eval-set`, `require-eval-diff`, `fix-judge-rubric`, `swap-judge-model`, `backfill-eval-from-incident`, `wire-regression-gate`.

## Related

- `rag-pipeline` — RAG features need retrieval-specific metrics (faithfulness, context relevance/recall) in the eval set; retrieval quality is evaluated separately from generation.
- `prompt-engineering` — prompts are versioned code; a prompt change is only safe once run through this gate. Structured-output validation is itself an assertion scorer.
- `agent-design` — agents are evaluated on task success, tool-call correctness, and cost/step budgets.
- `fine-tuning` — the eval-gate this pattern owns is what a fine-tune must clear: it ships only if it beats the prompted baseline on the held-out set, scored here.
- `llm-gateway` — online guardrail metrics (cost, latency, refusal rate) are emitted by the gateway's observability.
- `rules/ai-engineering-principles.md` — the `evals_gate` principle: no LLM change ships without a passing eval-diff.
- Security `@llm-security-reviewer` / `llm-security` — adversarial eval cases (prompt injection, jailbreaks, unsafe-output attempts) are authored WITH the security reviewer; the eval set is where injection defenses are regression-tested.
