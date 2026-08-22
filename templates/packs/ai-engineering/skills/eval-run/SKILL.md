---
name: eval-run
description: Run the offline LLM eval harness and gate on regression. Detects the project's own eval framework (promptfoo / OpenAI-evals / deepeval / ragas / LangSmith / a custom pytest harness), loads the versioned dataset, runs each case through the CURRENT prompt+model+retrieval, scores with the configured scorers (assertion + LLM-as-judge), diffs against the stored baseline, and FAILS below threshold. Emits a per-metric table + the regressed cases with their cited case-id + score. The measurement half of every prompt/model/retrieval change — dispatched by @ai-feature-reviewer and /add-ai-feature's Evaluate phase.
kind: skill
pack: ai-engineering
---

# Skill: eval-run

## Premise

An LLM call is non-deterministic; "it worked when I tried it" is one uncontrolled sample, not a pass. This skill turns a prompt/model/retrieval change into a **measurement**: it runs the versioned eval set through the *current* code and reports the score against a baseline.

**Every finding cites the eval case + its score.** A regression claim is `<case-id>` (or `<dataset:row>`) + `<metric> = <score>` + `<baseline score>` + the threshold it crossed. A green "the harness ran" without the per-case scores is not a pass — it is an unread result. A PASS verdict below the baseline is forbidden (see Halt conditions). This is the runner half of the eval loop; the *design* of the dataset + scorers lives in `ai/patterns/evals.md`.

## Adapt to the codebase

Detect the project's eval framework and **mirror it** — run the harness the project already has, never impose a second one. Adapt the commands below to the detected tool:

| Framework | Detect (grep / files) | Run | Dataset shape |
|---|---|---|---|
| **promptfoo** | `promptfooconfig.yaml`, `rg promptfoo` | `npx promptfoo eval -c promptfooconfig.yaml --no-cache` | `tests:` YAML with `vars` + `assert` |
| **deepeval** | `rg deepeval`, `pip show deepeval` | `deepeval test run tests/` | `LLMTestCase` + `metrics=[...]` in pytest |
| **ragas** (RAG) | `rg ragas` | `pytest tests/eval_ragas.py` | HF dataset: `question, contexts, answer, ground_truth` |
| **OpenAI evals** | `evals/`, `rg openai.*evals` | `oaieval <model> <eval-name>` | JSONL registry samples |
| **LangSmith** | `rg langsmith`, `LANGCHAIN_API_KEY` | `langsmith eval` / SDK `evaluate(...)` | versioned dataset on the LangSmith server |
| **custom pytest** | `tests/eval_*.py`, `rg "assert.*score"` | `pytest tests/eval_*.py -q` | project-defined loader |

If NO harness is detected → HALT and surface "no eval harness — run `/add-eval-set <feature>` first, then re-run". This skill runs a harness; it does not invent the dataset or the scorers. `/add-eval-set` is the artifact that picks that halt up: it builds the versioned dataset, the scorers, the judge rubric, the declared threshold, the committed baseline, and the CI gate, then dispatches this skill for the first measured run.

Read the project's harness config for: the dataset path + version, the model/prompt under test, the configured scorers, the baseline location, and the pass threshold. Mirror those — do not substitute your own model, temperature, or threshold.

## When to run

- On **every** change to a prompt, model id, temperature, retrieval step (chunking / top-k / reranker), or gateway routing — the change is unmeasured until this runs.
- In **CI** as a merge gate (fail the build below baseline).
- Dispatched by `@ai-feature-reviewer` (eval-coverage dimension) and by `/add-ai-feature` Phase 5 (Evaluate).
- NOT for a one-off "does this prompt work" spike with no dataset — that is not an eval, and this skill will halt.

## Procedure

1. **Detect + load** — identify the framework (table above); load the **versioned** dataset (record its version/commit) and the configured scorers. Confirm the dataset is checked in, not generated ad-hoc.
2. **Pin what the provider lets you pin** — apply the generation config the harness specifies (usually `temperature: 0` for scored tasks, where sampling params exist at all). For **LLM-as-judge** scorers, pin the judge **model id** + the judge **prompt** + every sampling parameter the provider exposes; where it exposes none, the model id and prompt *are* the pin and the report says so. An unpinned judge makes the score itself non-reproducible. If the harness config sets a parameter the model no longer accepts, the run fails with a provider error, not a low score — read the error before recording a regression.
3. **Run each case** through the CURRENT prompt + model + retrieval (the code as it is now, not a cached completion). Never evaluate on the few-shot / training examples baked into the prompt.
4. **Score** with the configured scorers — assertion (exact / regex / JSON-schema / contains), model-graded / LLM-as-judge (faithfulness, relevance, correctness), and any retrieval metric (recall@k / context-precision) when RAG is in scope.
5. **Diff vs baseline** — load the stored baseline (last green run / committed `baseline.json`). Compute per-metric delta. A case that dropped from pass→fail, or a metric below its threshold, is a regression.
6. **Verdict** — PASS only if every gated metric is at/above threshold AND no case regressed past the allowed tolerance. Otherwise FAIL, listing each regressed case with its cited id + score + baseline.
7. **Report** the table below. On PASS in CI, optionally write the new run as the baseline (only from the main branch, never from a feature branch — that would ratchet the baseline down silently).

## Output

```
eval-run — <feature> (promptfoo, dataset v12 @ commit a1b2c3d, 48 cases, judge=<model>@temp0)

Per-metric (vs baseline):
  Metric                  Score    Baseline   Threshold   Result
  exact-match             0.92     0.94       ≥ 0.90      PASS
  json-schema-valid       1.00     1.00       = 1.00      PASS
  faithfulness (judge)    0.86     0.91       ≥ 0.85      PASS (−0.05, watch)
  answer-relevance        0.78     0.88       ≥ 0.85      FAIL  (−0.10)
  context-recall@5        0.71     0.83       ≥ 0.80      FAIL  (−0.12)

Regressions (3):
  - case "refund-partial" (dataset:row 14): answer-relevance 0.55 (baseline 0.90) — new prompt dropped the order-id from the answer.
  - case "multi-item-order" (row 22): context-recall@5 0.40 (baseline 0.80) — top-k lowered 8→5 stopped retrieving the line-items chunk.
  - case "unknown-policy" (row 31): faithfulness 0.60 (baseline 0.95) — no-context guard removed; model answered from memory.

Verdict: FAIL — 2 gated metrics below threshold, 3 cases regressed.
Do not merge. Baseline NOT updated.

Reports: .promptfoo/output-1745492045.json
```

## False positives / gotchas

- **LLM-as-judge is non-deterministic.** An unpinned judge makes the *score* wobble run-to-run; a "regression" may be judge noise. Pin the judge model id + prompt + whatever sampling parameters the provider exposes, and prefer multiple samples / a rubric over a single free-form judgment before believing a small delta. Where the provider exposes no sampling parameters, that wobble is irreducible — widen the delta you are willing to call a regression rather than pretending the pin is tighter than it is.
- **Small eval sets are noisy.** With < ~30 cases, one flipped case swings the aggregate metric a lot; a 1-case regression on a 15-case set is weak signal — widen the set before trusting the trend.
- **Don't overfit prompts to the eval set.** Tuning the prompt until the eval is green teaches the prompt the test, not the task. Hold out cases, grow the set from real production failures, and treat a suspiciously perfect score as a smell.
- **Don't eval on the few-shot examples.** If the dataset rows are the same examples embedded in the prompt, the score measures memorization, not generalization — a silent false-PASS.
- **A flaky provider is not a regression.** A timeout / 429 / truncated completion from the provider is an infra failure — retry the case, don't record it as a quality drop.
- **Cost of the run itself** — a large set × a judge model is real spend; cache non-judge completions where the harness supports it, but never cache across a prompt/model change (that would score stale output).

## Halt conditions

- **No eval harness detected** → HALT — surface **`/add-eval-set <feature>`** as the next step (design in `ai/patterns/evals.md`). This skill runs a harness; it does not create one, and the halt is not a dead end: `/add-eval-set` builds the dataset + scorers + threshold + baseline + CI gate and calls back here for the first measured run. Until that run exists the feature's eval axis is **UNVERIFIED**, never a faked pass.
- **A finding without its cited case + score** → not emittable; re-run and capture the per-case scores, or drop the claim.
- **Below-baseline PASS** → forbidden. Never report PASS when a gated metric is below threshold or a case regressed past tolerance without an explicit, recorded human sign-off (an ADR / PR note that names the metric, the new value, and why the drop is accepted). Silently lowering the threshold or the baseline to go green is masking, not passing.
- **Evaluating on the training / few-shot examples** → HALT — the result is meaningless; point the harness at held-out cases.
- **Unpinned LLM-as-judge** (no fixed judge model id / judge prompt / exposed sampling params) → HALT the judged metrics — pin them before reporting a judged score as a gate.

## References

- `ai/patterns/evals.md` — the eval DESIGN this skill runs: dataset construction, scorer selection, LLM-as-judge rubrics, regression-gate policy. Owner of the *what to measure*; this skill is the *run it and gate*.
- `ai/patterns/rag-pipeline.md` — retrieval metrics (recall@k / context-precision) when RAG is in scope. The **runner** for those metrics is the `retrieval-eval` skill, not this one: it isolates the retrieval stage against a labelled question→gold-chunk set and reports filtered *and* unfiltered recall. This skill scores the end answer (faithfulness / answer relevance); pair them on any RAG feature so a failure is attributable to a stage.
- `retrieval-eval` — the retrieval-stage half. Where the project's harness already computes retrieval metrics, this skill runs them and `retrieval-eval` interprets the per-case output and owns the tuning loop.
- `@ai-feature-reviewer` — dispatches this skill for the eval-coverage dimension.
- `/add-ai-feature` — Phase 5 (Evaluate) dispatches this skill as the regression gate.
- `/ai-audit` — dispatches this skill for the eval axis of the six-axis sweep; when this skill halts for lack of a harness, that audit reports the axis `UNVERIFIED` and emits `/add-eval-set` as the next step.
- `/add-eval-set` — builds the harness this skill requires; the standing answer to the no-harness HALT.
- `.claude/rules/ai-engineering-principles.md` — "evals gate every prompt/model/retrieval change".
