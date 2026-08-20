---
name: eval-run
description: Run the offline LLM eval harness and gate on regression. Detects the project's framework (promptfoo / deepeval / ragas / OpenAI-evals / LangSmith / custom pytest), loads the versioned dataset, runs each case through the CURRENT prompt+model+retrieval, scores, diffs vs baseline, and FAILS below threshold.
kind: skill
pack: ai-engineering
---

# Skill: eval-run

## Premise

An LLM call is non-deterministic; "it worked when I tried it" is one uncontrolled sample. This skill turns a prompt/model/retrieval change into a measurement against a baseline. **Every finding cites the case + its score** (`<case-id>` + `<metric>=<score>` + baseline + threshold). A green "the harness ran" without per-case scores is not a pass. A PASS below baseline is forbidden.

## Adapt to the codebase

Detect + mirror the project's harness — never impose a second one:

| Framework | Detect | Run |
|---|---|---|
| promptfoo | `promptfooconfig.yaml` | `npx promptfoo eval -c … --no-cache` |
| deepeval | `rg deepeval` | `deepeval test run tests/` |
| ragas (RAG) | `rg ragas` | `pytest tests/eval_ragas.py` |
| OpenAI evals | `evals/` | `oaieval <model> <eval>` |
| LangSmith | `LANGCHAIN_API_KEY` | SDK `evaluate(...)` |
| custom pytest | `tests/eval_*.py` | `pytest tests/eval_*.py -q` |

No harness detected → HALT — run **`/add-eval-set <feature>`** first (design in `ai/patterns/evals.md`), then re-run. That command builds the dataset + scorers + declared threshold + committed baseline + CI gate and dispatches this skill for the first measured run.

## Procedure

1. Detect + load the **versioned** dataset + configured scorers (record version/commit).
2. Pin determinism — generation `temperature: 0`; LLM-as-judge model + temp + seed pinned.
3. Run each case through the CURRENT prompt+model+retrieval (not cached; not the few-shot examples).
4. Score — assertion + LLM-as-judge + retrieval metric (recall@k) if RAG.
5. Diff vs baseline; a pass→fail case or a below-threshold metric is a regression.
6. Verdict: PASS only if every gated metric ≥ threshold and no case regressed past tolerance.

## Output

```
eval-run — <feature> (promptfoo, dataset v12, 48 cases)
  Metric              Score  Baseline  Threshold  Result
  exact-match         0.92   0.94      ≥0.90      PASS
  answer-relevance    0.78   0.88      ≥0.85      FAIL (−0.10)
  context-recall@5    0.71   0.83      ≥0.80      FAIL (−0.12)

Regressions:
  - case "multi-item-order" (row 22): context-recall@5 0.40 (baseline 0.80) — top-k 8→5 dropped the line-items chunk.

Verdict: FAIL — do not merge. Baseline NOT updated.
```

## gotchas

- LLM-as-judge is non-deterministic — pin judge model/temp/seed; a small delta may be noise.
- Small eval sets (<~30 cases) are noisy — one flipped case swings the aggregate.
- Don't overfit prompts to the eval set; grow it from real production failures.
- Don't eval on the few-shot examples (measures memorization).
- A provider timeout/429 is infra flake, not a regression — retry the case.

## When to run

- Every prompt / model / temperature / retrieval / routing change; in CI as a merge gate.
- Dispatched by `@ai-feature-reviewer`, `/add-ai-feature` Phase 5, `/ai-audit` (eval axis), and `/add-eval-set` Phase 5.

## Halt conditions

- No harness → HALT (this skill runs a harness, doesn't create one) — surface **`/add-eval-set`** as the next step; the feature's eval axis is UNVERIFIED until that first run, never a faked pass.
- A finding without its cited case + score → not emittable.
- Below-baseline PASS → forbidden without an explicit recorded sign-off (ADR/PR note naming the metric + new value + why). Lowering the threshold/baseline to go green is masking.
- Evaluating on the training/few-shot examples → HALT.
- Unpinned LLM-as-judge → HALT the judged metrics.

## References

- `ai/patterns/evals.md` (the eval DESIGN this skill runs), `rag-pipeline.md` (retrieval metrics — whose **runner** is the `retrieval-eval` skill: it isolates the stage against a labelled question→gold-chunk set and reports filtered *and* unfiltered recall, while this skill scores the end answer; pair them on any RAG feature).
- `retrieval-eval`, `@ai-feature-reviewer`, `/add-ai-feature`, `/ai-audit`, `/add-eval-set`, `.claude/rules/ai-engineering-principles.md`.
