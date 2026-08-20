---
name: add-eval-set
kind: example
pack: ai-engineering
description: Retrofit a regression-gating eval harness onto an LLM feature that shipped without one — dataset, scorers, pinned judge, declared threshold, committed baseline, CI gate. The artifact eval-run's no-harness HALT points at.
---

# /add-eval-set <feature> [--plan]

> **`--plan`**: see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). Phases 1–3, write the plan, exit.

`eval-run` runs a harness and halts when there is none — **this command is what that halt points at.** The deliverable is committed files: a versioned dataset, scorers, a judge rubric where unavoidable, a checked-in baseline, and the CI step that fails the build below it. The `/add-tracing` of the AI pack.

## Phases applied

All 8. Phase 5 is load-bearing: the first `eval-run` establishes the baseline **and must clear the declared absolute bar**. A first run below the bar is a FAIL, not a low baseline to ratchet from.

## Phase 1 — Understand

Intent gate: building the feature now → `/add-ai-feature` (its Phase 5 builds the set) · a harness exists → `eval-run` (but if it exists and does not *gate*, stay here — `wire-regression-gate`) · "score our knowledge base" → the learning pack's `/eval`, a different subject · "audit the AI surface" → `/ai-audit` · a throwaway script → document it un-gated, build nothing.

Ask: which feature (by path) · **what defines a good output** (the eval spec — not inferable from code) · shape (single / RAG / agentic) · any existing harness anywhere to mirror · one real production failure with its input (this is case #1) · where CI runs and what the test runner is.

## Phase 2 — Organize

**Harness: mirror, never introduce a second one.** Extend an existing harness; otherwise the project's own test runner plus a thin scoring layer, cases as data files. Record the choice and the reason.

**Case classes, budgeted before writing any case:** representative (real traffic) · edge (empty, very long, ambiguous, multi-valid, non-English, boundary) · **adversarial** (injection attempts, contradictory context, out-of-scope, and cases whose correct answer is a refusal). Dozens of good cases beat thousands of noisy ones.

**Scorer per requirement — cheapest that captures it:** exact/normalised match for closed-form · **assertion/programmatic** for structural properties (the workhorse) · semantic similarity for free text (calibrate the threshold) · a model-graded judge only where nothing cheaper expresses it · human for gold labels and calibration. RAG adds faithfulness / answer relevance / context relevance / recall (the retrieval half is `retrieval-eval`'s); classification adds P/R/F1 + a confusion matrix; agents add task success, tool-call correctness, step/cost.

**Judge design (if unavoidable):** anchored rubric · justification-before-score · position-bias mitigation · a **different, ideally stronger** model — never the generator · pinned model + prompt + temperature · a human calibration cadence.

**Thresholds:** declare the ABSOLUTE bar per gated metric **before the first run**; pick `ε` for judge noise and say why; tier fast (assertions, per PR) vs full (judge, nightly) so cost never makes the gate skippable.

## Phase 3 — Retrieve

ALWAYS: [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md). **MUST read** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md). AI-specific: `evals.md` always · `rag-pipeline.md` / `agent-design.md` / `fine-tuning.md` by shape · `prompt-engineering.md` (the prompt version this set is attributed to) · AI-2. Existing code: `§ AI/LLM integration`, `§ Tests`, **real production inputs**, and the prompt itself (so its few-shot examples are excluded).

## Phase 4 — Generate

Versioned dataset checked in, each case `input + expected` with an id, a class, and (for a backfilled case) its date + incident pointer; **held out from the prompt's few-shot examples**. Scorers as reviewed code; schema validation is itself an assertion scorer. The judge rubric + pinned config, versioned with the dataset. A **committed baseline file** carrying dataset + prompt + model ids. The **CI step** that exits non-zero below threshold — read it back from the pipeline file.

## Phase 5 — Evaluate (MANDATORY)

Dispatch **`eval-run`**. Record the measured value per gated metric vs its declared bar, plus the `Reports:` path. **A first run below the bar is a FAIL** — fix the feature, or revise the bar deliberately and record why; quietly lowering it is the failure this step prevents. Read the per-case output (a metric at threshold with every adversarial case failing is a set that measures the easy half). Commit the baseline only from a cleared run, only from the main branch.

## Phases 6–8

**Update**: dataset version + scorers + thresholds + baseline recorded; `ai/status.md`; changelog; an ADR if this is the project's first harness. **Validate**: `eval-run` green; the CI step grep-confirmed present in the pipeline file (assert the config, never the remote build's outcome); three case classes with the adversarial count stated; no few-shot overlap; judge ≠ generator and pinned; `@ai-feature-reviewer` dim 1. **Improve**: wire the **incident→case path** concretely (who files it, where it lands, who reviews) and add the Phase-1 failure as case #1; `/learn-from-task`.

## Ship gate

- **GATED** — measured (every gated metric cleared its declared bar, numbers + `Reports:` cited) · gating (CI step present, exits non-zero below threshold) · honest (three classes, no few-shot overlap, judge pinned + different, incident path named).
- **UNVERIFIED** — built but the first run could not execute (no credentials / no model reachable). Name it; the ship decision is the human's.
- **INCOMPLETE** — a named axis unmet (a below-bar metric, no adversarial cases, a CI step that exits 0, an unpinned judge, few-shot overlap). List every item.

## Hard rules

The threshold is declared before the first run, never fitted to it · a CI job that prints a score and exits 0 is enforcement theatre · never evaluate on the few-shot examples · never let a model judge its own generations · a set with no adversarial cases is not done · the first run must clear the absolute bar · cases come from real inputs · mirror the project's runner · this retrofits, it does not build the feature.

## Related

- Commands: `/add-ai-feature` (builds; its Phase 5 routes here when no harness exists), `/ai-audit` (reports the axis `UNVERIFIED` and emits this), `/add-tracing` (the same retrofit shape), and the learning pack's `/eval` — **not** this.
- Agents: `@ai-feature-reviewer` (dim 1), `@rag-architect` (the labelled retrieval set), `@agent-loop-architect` (the agent eval plan).
- Skills: `eval-run` (Phase 5 + 7), `retrieval-eval`, `prompt-audit`.
- Patterns: `evals` (the design this implements), `rag-pipeline`, `agent-design`, `fine-tuning`, `prompt-engineering`. Rule: AI-2.
