---
name: evals
description: 'Pattern: Evals — the regression gate for LLM features'
kind: ai-pattern
pack: ai-engineering
---

# Pattern: Evals — the regression gate for LLM features

> **Hard rule:** Every LLM feature ships with a **versioned eval dataset** and a **CI regression gate**. LLM output is non-deterministic — you cannot eyeball regressions the way you diff a pure function; a prompt/model/temperature/retrieval change can silently degrade quality on inputs you never re-tested. Evals are the analog of tests for LLM features. "I tried a few prompts and it looked good" is not an eval.

**When to apply** — any LLM-produced output (generation/extraction/classification/RAG/agent), and BEFORE any change to a prompt, model, temperature, retrieval config, or few-shot set (evaluate, don't spot-check).

**Halt conditions / mandatory cites**
- An LLM call site with NO eval dataset MUST be cited at `<path:line>` — "tested manually" is not coverage.
- A prompt/model/temperature/retrieval change with NO eval-diff (before/after scores) MUST be flagged.
- An LLM-as-judge with no rubric, or the same model judging its own output, MUST be cited.
- An eval set that never grows from prod failures is rotting; a "passing" CI job that never fails below baseline is enforcement theater.

## The eval dataset (golden set)

The dataset is the asset — it is code (versioned, PR-reviewed) and it grows.
- **Three case classes:** representative (typical, high-frequency), edge (empty/long/ambiguous/multi-valid), adversarial (injection, out-of-scope, should-refuse).
- Each case = input + expected (gold answer / assertions / rubric).
- **Grows from prod failures — the flywheel.** Every real miss becomes a new case with the correct expected output.
- Versioned + sized honestly (dozens of good cases beat thousands of noisy ones).

## Scorer types

| Scorer | Use for | Note |
|---|---|---|
| Exact / normalized match | Labels, IDs, enums | Cheap, deterministic — prefer for closed-form |
| Assertion / programmatic | Valid schema, contains/omits, in-range, cites a real source | The workhorse |
| Semantic similarity | Free-text where wording varies | Threshold is fuzzy — calibrate |
| **LLM-as-judge** | Open-ended, on-tone, pairwise A/B | Expensive + **biased** — see below |
| Human | Gold labels, judge calibration | Ground truth — sample, don't scale |

Prefer the cheapest scorer that captures the requirement.

## LLM-as-judge — traps to design around

- **Needs an explicit rubric** + justification-before-score (raises human agreement).
- **Position bias** — average both orderings in pairwise. **Self-preference** — never let a model judge its own outputs; use a different/stronger judge. **Verbosity/sycophancy** — control for length + confidence.
- **Calibrate against humans** periodically; version the judge model + prompt; judge at low temperature.

## Task-specific metrics

- **RAG:** faithfulness/groundedness, answer relevance, context relevance/precision, context recall (isolates retrieval vs generation failures — see `rag-pipeline`).
- **Classification/extraction:** precision, recall, F1 per class + confusion matrix (accuracy hides imbalance).
- **Agents:** task success, tool-call correctness, cost/steps per task.

## The regression gate (evals as CI)

CI runs the full set on every prompt/model/retrieval change; the build **FAILS below a committed baseline** (minus an epsilon for judge noise). Baseline lives in the repo (a diff-able scores file); the PR shows a per-metric eval-diff + which cases regressed. Fast tier (assertions/exact) every PR; full tier (with judge) nightly/pre-release.

## Offline vs online

- **Offline** = the CI gate (catches regressions before ship).
- **Online** = A/B on live traffic with **guardrail metrics** (cost/req, p95 latency, refusal rate) so a "better" variant that doubled cost is caught. Prod misses feed back into the offline set.

## Detectors (cite-or-halt)

- LLM call site with **no eval dataset** → BAD: shipped, "ran a few examples"; GOOD: versioned rep+edge+adversarial set gating CI → `add-eval-set`
- Prompt/model change with **no eval-diff** → `require-eval-diff`
- **LLM-judge with no rubric / self-judging** → GOOD: stronger judge, anchored rubric, position-bias mitigation, human-calibrated → `fix-judge-rubric`, `swap-judge-model`
- **Eval set that never grows from incidents** → `backfill-eval-from-incident`
- **CI "eval" that always exits 0** (no baseline gate) → `wire-regression-gate`

**Closure verbs:** `add-eval-set`, `require-eval-diff`, `fix-judge-rubric`, `swap-judge-model`, `backfill-eval-from-incident`, `wire-regression-gate`.

## Related

- `rag-pipeline` — retrieval-specific metrics (faithfulness, context relevance/recall) in the set.
- `prompt-engineering` — prompts are versioned code; a change is safe only through this gate.
- `agent-design` — agents evaluated on task success + cost/step budgets. `llm-gateway` — online guardrail metrics.
- `rules/ai-engineering-principles.md` — `evals_gate`.
- Security `@llm-security-reviewer` / `llm-security` — adversarial cases (injection/jailbreak) authored WITH the security reviewer; the eval set regression-tests injection defenses.
