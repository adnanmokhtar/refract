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

**Judge design (if unavoidable):** anchored rubric · justification-before-score · position-bias mitigation · a **different, ideally stronger** model — never the generator · pinned model id + prompt + every exposed sampling param (where the provider exposes none, say so; the pin is looser than it looks) · a human calibration cadence.

**Thresholds:** declare the ABSOLUTE bar per gated metric **before the first run**; pick `ε` for judge noise and say why; tier fast (assertions, per PR) vs full (judge, nightly) so cost never makes the gate skippable.

## Phase 3 — Retrieve

ALWAYS: [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md). **MUST read** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md). AI-specific: `evals.md` always · `rag-pipeline.md` / `agent-design.md` / `fine-tuning.md` by shape · `prompt-engineering.md` (the prompt version this set is attributed to) · AI-2. Existing code: `§ AI/LLM integration`, `§ Tests`, **real production inputs**, and the prompt itself (so its few-shot examples are excluded).

## Phase 4 — Generate

Versioned dataset checked in, each case `input + expected` with an id, a class, and (for a backfilled case) its date + incident pointer; **held out from the prompt's few-shot examples**. Scorers as reviewed code; schema validation is itself an assertion scorer. The judge rubric + pinned config, versioned with the dataset. A **committed baseline file** carrying dataset + prompt + model ids. The **CI step** that exits non-zero below threshold — read it back from the pipeline file.

## Phase 5 — Evaluate (MANDATORY)

Dispatch **`eval-run`**. Record the measured value per gated metric vs its declared bar, plus the `Reports:` path. **A first run below the bar is a FAIL** — fix the feature, or revise the bar deliberately and record why; quietly lowering it is the failure this step prevents. Read the per-case output (a metric at threshold with every adversarial case failing is a set that measures the easy half). Commit the baseline only from a cleared run, only from the main branch.

## Phase 6 — Update (persist to the knowledge base)

Record the dataset version, the scorer set, the thresholds, and the baseline scores in the feature's doc (and `ai/patterns/evals.md § datasets`). Prepend an `ai/status.md` Recent Changes entry — a feature moved from unmeasurable to gated, and that fact must survive the session. Append one line to `ai/dynamic/changelog.md`. New ADR if this is the project's **first** eval harness — the harness choice, the threshold policy, and the incident→case path are decisions the next feature will mirror.

## Phase 7 — Validate (verify + review)

**`eval-run` green** at/above every declared bar — re-run; this is the gate, not a formality. **The CI eval step is grep-confirmed present** in the pipeline config file — assert the config, never claim a remote build's outcome. All three case classes present with the adversarial count stated; no case duplicates a few-shot example from the prompt; the judge model differs from the generating model and judge model id + prompt + every exposed sampling param are pinned in checked-in config. **`@ai-feature-reviewer`** — dimension 1 (eval gate), re-grading coverage and the cited measured score independently. If a named agent is not installed, run its checklist inline — never silently skip the axis. If any check fails: HALT, report, do not paper over.

## Phase 8 — Improve (wire the flywheel — the point of all this)

**Wire the incident→case path.** A real bad output — a bug report, a monitoring catch, a thumbs-down — becomes a dated case with the correct expected output. Name the mechanism concretely: who files it, where the case lands, who reviews it. A set that never grows is a set that stops catching real regressions. Case #1 of that path is the production failure from Phase 1 — add it now. Run `/learn-from-task`. If the set exposed a systemic defect (the feature fails every adversarial case) → that is a `/fix-bug` or `/add-ai-feature` follow-up, filed by name, **not a threshold to lower**.

## Ship gate

- **GATED** — measured (every gated metric cleared its declared bar, numbers + `Reports:` cited) · gating (CI step present, exits non-zero below threshold) · honest (three classes, no few-shot overlap, judge pinned + different, incident path named).
- **UNVERIFIED** — built but the first run could not execute (no credentials / no model reachable). Name it; the ship decision is the human's.
- **INCOMPLETE** — a named axis unmet (a below-bar metric, no adversarial cases, a CI step that exits 0, an unpinned judge, few-shot overlap). List every item.

## Output

```
✅ Eval set added: <feature>

Phase 2 (Organize): harness=<mirrored from X | chosen because Y>; cases <n> (<representative> / <edge> / <adversarial>);
                    scorers = <cheapest that captures each requirement>; thresholds declared BEFORE the run.
Phase 5 (Evaluated): eval-run measured — <metric>=<measured> vs <declared bar>, per gated metric. Reports: <path>
Phase 7 (Validated): eval-run green; CI step present in <pipeline file>:<line>; 3 case classes; no few-shot overlap;
                     judge != generator; @ai-feature-reviewer dim 1 <verdict>.
Phase 8 (Improved): incident→case path wired (<who files it, where it lands>); /learn-from-task queued.

Files:
  - evals/<feature>/dataset.v1.<ext>       (versioned, checked in)
  - evals/<feature>/scorers.<ext>
  - evals/<feature>/judge-rubric.md        (anchored levels, justification-before-score, pinned model)
  - evals/<feature>/baseline.json          (per-metric, with dataset + prompt + model ids)
  - <pipeline file>                        (eval-gate step — exits non-zero below threshold)

Ship verdict: GATED | UNVERIFIED | INCOMPLETE
  Measured axis: <per-metric numbers + Reports: path>
  Gating axis:   CI step present in <file>:<line> · exits non-zero below threshold
  Honest axis:   <case classes> · no few-shot overlap · judge pinned + different model · incident path named
  Unmet (if UNVERIFIED/INCOMPLETE): <the exact items>

Next:
  - eval-run  (on every prompt / model / retrieval change from now on)
  - /review-changes
```

## Hard rules

The threshold is declared before the first run, never fitted to it · a CI job that prints a score and exits 0 is enforcement theatre · never evaluate on the few-shot examples · never let a model judge its own generations · a set with no adversarial cases is not done · the first run must clear the absolute bar · cases come from real inputs · mirror the project's runner · this retrofits, it does not build the feature.

## Related

- Commands: `/add-ai-feature` (builds; its Phase 5 routes here when no harness exists), `/ai-audit` (reports the axis `UNVERIFIED` and emits this), `/add-tracing` (the same retrofit shape), and the learning pack's `/eval` — **not** this.
- Agents: `@ai-feature-reviewer` (dim 1), `@rag-architect` (the labelled retrieval set), `@agent-loop-architect` (the agent eval plan).
- Skills: `eval-run` (Phase 5 + 7), `retrieval-eval`, `prompt-audit`.
- Patterns: `evals` (the design this implements), `rag-pipeline`, `agent-design`, `fine-tuning`, `prompt-engineering`. Rule: AI-2.
