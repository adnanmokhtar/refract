---
description: Retrofit a regression-gating eval harness onto an existing LLM feature that has none — pick the harness that matches the stack, build the versioned dataset from real inputs (representative / edge / adversarial), wire the cheapest scorer that captures each requirement, pin and de-bias the judge where one is unavoidable, declare an absolute threshold per gated metric before the first run, commit the baseline, and wire the CI gate that fails the build below it. TRIGGER — eval-run HALTing with "no eval harness detected"; @ai-feature-reviewer BLOCKING on "no eval set"; /ai-audit reporting the eval axis UNVERIFIED; a production failure that must become a permanent test case; a fine-tune or model upgrade needing a held-out baseline to beat. ANTI-TRIGGERS (do NOT fire) — a feature being built new (/add-ai-feature Phase 5 already builds its set; this is the retrofit); running a set that already exists (eval-run); grading the project's accumulated knowledge base (the learning pack's /eval — different artifact, different subject); a throwaway script a human reads every output of (document it as un-gated, do not build a harness).
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. This pack is provider-agnostic — examples name a framework illustratively; substitute the project's from `_extracted-codebase.md § AI/LLM integration` and § Tests.

# /add-eval-set <feature> [--plan]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). Runs Phases 1–3, writes the plan, exits before any file is generated.

Retrofit the regression gate onto an LLM feature that shipped without one. `eval-run` runs a harness; it explicitly halts when there is none — **this command is what that halt points at.** The deliverable is committed files: a versioned dataset, the scorers, a judge rubric where one is unavoidable, a checked-in baseline, and the CI step that fails the build below it. The `/add-tracing` of the AI pack — instrumentation retrofitted onto code that already exists.

## Phases applied

All 8: **Understand → Organize → Retrieve → Generate → Evaluate → Update → Validate → Improve.** Phase 5 (Evaluate) is load-bearing — the first `eval-run` establishes the baseline **and must clear the declared absolute bar**. A first run below the bar is a FAIL, not a low baseline to ratchet from.

## Phase 1 — Understand (the ask)

### Intent gate

If the ask suggests a different intent, halt with a redirect:
- **Building the feature now** → `/add-ai-feature`, whose Phase 5 builds the set alongside the code. This command is the retrofit for a feature that already shipped.
- **A harness already exists** → `eval-run` runs it. If it exists but does not *gate*, stay here — `wire-regression-gate` is this command's job.
- **"Score our knowledge base / our saved decisions"** → the learning pack's `/eval`. It grades the project's accumulated knowledge against saved cases; it has nothing to do with LLM-feature evals despite the name. Name it explicitly and route.
- **"Audit the AI surface"** → `/ai-audit`; it *reports* the missing eval axis and then emits this command as the next step.
- **"Fix the bad output"** → `/fix-bug`, then come back here so the failure becomes a permanent case.
- **A throwaway script a human reads every output of** → the `evals` pattern's own "When NOT to apply". Document it as un-gated and stop; do not build a harness for a script that will be deleted.

### Standard inputs

Ask (one consolidated question):
- **Which feature** — the model call(s) in scope, by path.
- **What defines a good output** — the properties an eval must check: correctness, format/schema, faithfulness to sources, refusal-on-unknown, tone, absence of a forbidden claim. *This is the eval spec. It is not optional, and it cannot be inferred from the code.*
- **Shape** — single call (generation / extraction / classification), RAG, or agentic. Each brings different metrics.
- **Is there any existing harness anywhere in the repo** to mirror — even one for a different feature. Mirroring beats introducing.
- **What does a real production failure look like** — one concrete bad output, with its input. This is case #1 and the reason the flywheel exists.
- **Where does CI run**, and what does the project's test runner look like.

State the success criteria: a versioned dataset checked in · a scorer per requirement · a declared absolute threshold per gated metric · a committed baseline from a measured first run that cleared the bar · a CI step that exits non-zero below threshold, grep-confirmed present in the pipeline file · the incident→case path wired · zero placeholders.

## Phase 2 — Organize (design the harness before writing it)

### Harness choice — mirror, never introduce a second one

Detect what the project already has and extend it. Only when there is genuinely nothing does the choice open up, and then the tiebreaker is the project's **test runner**, not the framework's popularity — an eval suite that runs under the existing runner gets run.

| Situation | Choice |
|---|---|
| A harness exists for another feature | extend **it**. New cases, new scorers, same runner, same baseline mechanism. |
| No harness, project has a mature test runner | the runner + a thin scoring layer, cases as data files. Fewest moving parts, runs in the existing CI job. |
| No harness, RAG feature, a retrieval-metrics library is already a dependency | that library, wired into the runner. |
| No harness, a prompt-eval tool is already a dependency or a team standard | that tool, with its config checked in. |
| Nothing at all, and the feature is a single extraction/classification call | assertions in the existing runner. An LLM judge is unjustified here — the answer is closed-form. |

Record the choice and the *reason* — the next person adding cases must know why they are writing them in this shape.

### Case-class budget

Plan the counts before writing any case. All three classes, deliberately balanced (`evals` "The eval dataset"):

- **Representative** — the typical, high-frequency inputs the feature actually sees. Sampled from real traffic where possible.
- **Edge** — empty input, very long input, ambiguous input, multiple valid answers, unusual formats, non-English, a value at a boundary.
- **Adversarial** — inputs designed to break it: prompt-injection attempts, contradictory context, out-of-scope questions, and inputs whose **correct** answer is "I don't know" or a refusal. **A set with no adversarial cases is not done.**

Dozens of good cases beat thousands of noisy ones. Start at a size a human can actually review, and grow from incidents.

### Scorer per requirement — cheapest that captures it

Map each property from the Phase-1 eval spec to exactly one scorer. Reach up the table only when the row above genuinely cannot express the requirement.

| Requirement shape | Scorer | Note |
|---|---|---|
| a closed-form answer — a label, an id, an enum, a number | exact / normalised match | deterministic, free, prefer always |
| a structural property — valid against the schema, contains the disclaimer, omits a competitor, in range, cites a real source id | **assertion / programmatic** | the workhorse; most requirements land here |
| free text where wording varies but meaning must match | semantic similarity vs a reference | the threshold is fuzzy — calibrate it, don't guess it |
| open-ended quality — faithful, helpful, on-tone | model-graded judge | expensive and biased; see below |
| gold labels, judge calibration, a high-stakes launch | human | sample; never scale |

RAG adds faithfulness / answer relevance / context relevance / context recall — and the retrieval half is `retrieval-eval`'s, scored separately from generation so a failure is attributable. Classification adds precision / recall / F1 per class plus a confusion matrix; accuracy alone hides class imbalance. Agents add task success rate, tool-call correctness, and step/cost per task.

### Judge design — only where nothing cheaper works

If a judge is unavoidable, design it now, not at implementation time:
- **An anchored rubric** with concrete levels, and the reference answer where one exists. "Rate 1–5" with no criteria produces noise.
- **Justification before score** — the judge writes its reasoning first; agreement with humans rises.
- **Position-bias mitigation** for any pairwise grading: run both orderings and average, or randomise position per case.
- **A different — ideally stronger — judge model.** Never let a model judge its own generations; self-preference is systematic, not incidental.
- **Pin the judge model + judge prompt + temperature**, and version them. A silent judge change shifts every score.
- **Plan the human calibration cadence** — periodically sample judged cases, have a human grade them, and measure agreement. A judge nobody validates is a metric nobody can trust.

### Threshold + gate design

- **Declare the ABSOLUTE bar per gated metric now, before the first run.** It is the production requirement, not a number fitted to whatever the first run produces. Fitting the threshold to the result is how a gate becomes decoration.
- Decide the tolerance `ε` for judge noise on subsequent runs (`baseline − ε`), and say why that value.
- Decide the tiering: a fast tier (assertions + exact match) on every PR, a full tier (with the judge) nightly or pre-release, where cost or runtime would otherwise get the whole thing skipped.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

**MUST read** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) before generating code.

AI-SPECIFIC:
- `ai/patterns/evals.md` — **always**. Dataset classes, scorer table, judge traps, the regression gate, offline-vs-online.
- `ai/patterns/rag-pipeline.md` — if RAG (the per-stage split; retrieval metrics are `retrieval-eval`'s).
- `ai/patterns/agent-design.md` — if agentic (task success, tool-choice accuracy, step/cost budgets).
- `ai/patterns/fine-tuning.md` — if the reason for this command is a fine-tune needing a held-out baseline to beat.
- `ai/patterns/prompt-engineering.md` — the prompt version this set will be attributed to.
- `.claude/rules/ai-engineering-principles.md` — AI-2.

EXISTING CODE:
- `_extracted-codebase.md § AI/LLM integration` — the feature's call sites, the prompt version, any existing harness.
- `_extracted-codebase.md § Tests` — the project's runner, its fixture conventions, how CI invokes it.
- Real production inputs — logs, tickets, a thumbs-down store. **Cases come from reality or they measure a fiction.**
- The prompt itself — so the few-shot examples baked into it can be **excluded** from the dataset.

## Phase 4 — Generate (the committed files)

### The dataset

- **Versioned and checked in** — a data file (or a versioned store) with a dataset version id, not fixtures scattered in a notebook. A score is attributable to (prompt version × model × dataset version) or to nothing.
- Each case: **input + expected** — a gold answer, an assertion set, or a rubric, matching its scorer. Store the expected outcome, not just the input.
- Each case carries an id, a class (representative / edge / adversarial), and — for a case backfilled from an incident — its date and a pointer to the incident.
- **Cases are held out from the prompt's few-shot examples.** Evaluating on the examples baked into the prompt measures memorization and produces a silent false PASS.

### The scorers

- One scorer per requirement, per the Phase-2 table. Assertions are code and get reviewed like code.
- Schema validation is itself an assertion scorer — wire it where the feature uses structured output.
- Where the feature is RAG, the retrieval metrics are produced by `retrieval-eval` against its own labelled question→gold-chunk set; wire that set alongside, do not fold retrieval into the answer score.

### The judge (only if Phase 2 justified one)

Write the rubric file, pin the judge model + prompt + temperature in config, implement justification-before-score and the position-bias mitigation, and record the calibration cadence. The judge config is versioned with the dataset.

### The baseline + the CI gate

- A **committed baseline file** — per-metric scores from the first measured run, with the dataset version, the prompt version, and the model id beside them. A regression is then a visible diff and an intentional baseline change is a reviewed PR.
- The **CI step**: run the set, compare each gated metric to its threshold, **exit non-zero below it**. A job that prints a score and exits 0 is enforcement theatre and is not done.
- Confirm the step is **present in the pipeline file** by reading it back — assert the config, never the remote build's runtime outcome. This command cannot prove a remote build fails; it can prove the step exists and that `eval-run` measured the numbers.

## Phase 5 — Evaluate (MANDATORY — the first measured run)

1. **Dispatch `eval-run`.** It detects the harness (now present), runs every case through the CURRENT prompt + model + retrieval, and scores with the configured scorers.
2. **The first run establishes the baseline AND must clear the declared absolute bar.** Record the measured value per gated metric (`<metric> = <score>` vs `≥ <threshold>`) from `eval-run`'s per-metric table plus its `Reports:` path. A first run below the bar is a **FAIL** — the feature does not meet its own stated requirement, and the honest outcomes are: fix the feature, or revise the bar deliberately and say so in the artifact. Quietly lowering the bar to match the run is the failure this step exists to prevent.
3. **Read the per-case output**, not just the aggregate. A metric at threshold with every adversarial case failing is a set that measures the easy half.
4. **Commit the baseline** only from a run that cleared the bar, and only from the main branch — ratcheting a baseline down from a feature branch is silent masking.

HALT conditions for this phase: `eval-run` reports a gated metric below its declared bar; the judge is unpinned; cases overlap the prompt's few-shot examples; the set has no adversarial cases; the CI step is absent from the pipeline file.

## Phase 6 — Update (persist to the knowledge base)

- Record the dataset version, the scorer set, the thresholds, and the baseline scores in the feature's doc (and `ai/patterns/evals.md § datasets` where the project keeps that index).
- Prepend an `ai/status.md` Recent Changes entry — a feature moved from unmeasurable to gated, and that fact must survive the session.
- Append one line to `ai/dynamic/changelog.md`.
- New ADR if this is the project's **first** eval harness — the harness choice, the threshold policy, and the incident→case path are decisions the next feature will mirror.

## Phase 7 — Validate (verify + review)

- **`eval-run` green** at/above every declared bar — re-run; this is the gate, not a formality.
- **The CI eval step is grep-confirmed present** in the pipeline config file. Assert the config; do not claim a remote outcome.
- The dataset contains all three case classes, with the adversarial count stated.
- No case duplicates a few-shot example from the prompt (grep the prompt's examples against the dataset).
- The judge model differs from the generating model, and judge model + prompt + temperature are pinned in checked-in config.
- **`@ai-feature-reviewer`** — dimension 1 (eval gate). It re-grades the set's coverage and the cited measured score independently.
- If a named agent is not installed, run its checklist inline — never silently skip the axis. If any check fails: HALT, report, do not paper over.

## Phase 8 — Improve (wire the flywheel — the point of all this)

- **Wire the incident→case path.** A real bad output — a bug report, a monitoring catch, a thumbs-down — becomes a dated case with the correct expected output. Name the mechanism concretely: who files it, where the case lands, who reviews it. A set that never grows is a set that stops catching real regressions (`backfill-eval-from-incident`).
- Case #1 of that path is the production failure from Phase 1. Add it now.
- Run `/learn-from-task` to capture: the harness choice and why, the threshold policy, the scorer mapping, the cases that were hardest to label.
- If the set exposed a systemic defect (the feature fails every adversarial case) → that is a `/fix-bug` or `/add-ai-feature` follow-up, filed by name, not a threshold to lower.

## Ship gate — GATED or it is not done

An eval harness is **done** only when a below-threshold run actually stops a merge. Pick exactly one terminal state, honestly:

| Axis | The bar (verified, not asserted) | How it's enforced |
|---|---|---|
| **Measured** | `eval-run` produced a per-metric table and every gated metric cleared its **declared absolute** bar — cite the numbers and the `Reports:` path. | **mechanical** — read from `eval-run`'s recorded output; the baseline file is committed with the dataset + prompt + model ids beside it. |
| **Gating** | The CI step runs the set and **exits non-zero** below threshold, and that step is grep-confirmed present in the pipeline file. | **mechanical for presence** — the step is read back from the config. **[self-policed]** for the remote build's behaviour; this command asserts the config, not the pipeline's runtime outcome. |
| **Honest** | All three case classes present with counts stated; no overlap with the prompt's few-shot examples; the judge (if any) is a different model, pinned; the incident→case path is named. | **[self-policed]** here, and independently re-graded by `@ai-feature-reviewer` dimension 1. |

- **GATED** — all three axes satisfied with the cited evidence. The feature is now regression-gated.
- **UNVERIFIED** — the set and the gate are built, but the first run could not be executed (no provider credentials in this environment, harness cannot reach the model). Name it exactly; the ship decision is the human's, eyes-open. This command does NOT upgrade it to GATED.
- **INCOMPLETE** — a named axis is unmet: a metric below its declared bar, no adversarial cases, a CI step that exits 0, an unpinned judge, cases overlapping the few-shot examples. List every unmet item; do not paper over it.

## Output

```
✅ Eval set added: <feature>

Phase 1 (Understand): shape=<single|RAG|agentic>, spec=<the properties a good output must have>, prod failure #1 captured.
Phase 2 (Organize): harness=<mirrored from X | chosen because Y>; cases 24 (14 representative / 6 edge / 4 adversarial);
                    scorers = schema-assert + exact-match + judge(faithfulness); thresholds declared BEFORE the run.
Phase 3 (Retrieved): evals.md (+ rag-pipeline / agent-design / fine-tuning by signal), § Tests, real production inputs.
Phase 4 (Generated): dataset v1 (checked in), scorers, judge rubric (pinned, different model), baseline file, CI step.
Phase 5 (Evaluated): eval-run measured — schema-valid 1.00 vs =1.00 · exact-match 0.92 vs ≥0.90 ·
                     faithfulness 0.88 vs ≥0.85. First run cleared the absolute bar; baseline committed.
Phase 6 (Updated): ai/status.md, changelog, dataset version + baseline recorded, ADR (first harness).
Phase 7 (Validated): eval-run green; CI step present in <pipeline file>; 3 case classes; no few-shot overlap;
                     judge != generator; @ai-feature-reviewer dim 1 APPROVE.
Phase 8 (Improved): incident→case path wired (<who files it, where it lands>); /learn-from-task queued.

Files:
  - evals/<feature>/dataset.v1.<ext>       (24 cases, versioned, checked in)
  - evals/<feature>/scorers.<ext>          (schema assert + exact match)
  - evals/<feature>/judge-rubric.md        (anchored levels, justification-before-score, pinned model)
  - evals/<feature>/baseline.json          (per-metric, with dataset + prompt + model ids)
  - <pipeline file>                        (eval-gate step — exits non-zero below threshold)

Gate: <metric>=<measured> vs ≥<declared bar> for each gated metric · dataset v1 · judge=<model>@temp0
Ship verdict: GATED | UNVERIFIED | INCOMPLETE
  Measured axis: <per-metric numbers + Reports: path>
  Gating axis:   CI step present in <file>:<line> · exits non-zero below threshold
  Honest axis:   14/6/4 case classes · no few-shot overlap · judge pinned + different model · incident path named
  Unmet (if UNVERIFIED/INCOMPLETE): <the exact items>

Next:
  - eval-run  (on every prompt / model / retrieval change from now on)
  - /review-changes
```

## Hard rules

- **The threshold is declared before the first run, never fitted to it.** A bar chosen after seeing the score measures nothing.
- **A CI job that prints a score and exits 0 is enforcement theatre and is not done.** The build fails below baseline, or there is no gate.
- **Never evaluate on the few-shot / training examples baked into the prompt.** That measures memorization and produces a silent false PASS.
- **Never let a model judge its own generations.** Self-preference is systematic. A different — ideally stronger — judge, pinned with its prompt and temperature.
- **A set with no adversarial cases is not done.** Injection attempts, contradictory context, out-of-scope questions, and the cases whose correct answer is a refusal are where the gate earns its keep.
- **The first run must clear the declared absolute bar.** Below it is a FAIL — fix the feature or revise the bar deliberately and record why. Ratcheting the baseline down to go green is masking.
- **Cases come from real inputs.** Invented cases measure an invented distribution; the flywheel from production failure to permanent case is the whole mechanism.
- **Mirror the project's runner and any existing harness** — a second eval framework beside the first is how both stop being run.
- **This command retrofits; it does not build the feature.** A new feature builds its set in `/add-ai-feature` Phase 5.

## Related

### Sibling commands
- `/add-ai-feature` — builds an LLM feature end-to-end; its Phase 5 builds the set alongside the code, and its Phase 5.4 routes here when no harness exists.
- `/ai-audit` — reports the eval axis as `UNVERIFIED` and emits this command as the paste-ready next step.
- `/add-tracing`, `/add-metrics` (observability pack) — the same retrofit shape for instrumentation; mirror their phase discipline.
- `/eval` (learning pack) — **not** this. It scores the project's accumulated knowledge base against saved cases. Different subject entirely; named here so the two are never conflated.

### Agents
- `@ai-feature-reviewer` — dimension 1 re-grades this set's coverage and the cited measured score (Phase 7).
- `@rag-architect` — owns the labelled question→gold-chunk set when the feature is RAG; its retrieval metrics are scored separately from generation.
- `@agent-loop-architect` — owns the agent eval plan (task success, tool-choice accuracy, step + cost per task) when the feature is a loop.

### Skills
- `eval-run` — the runner this command's harness exists for; dispatched in Phase 5 and Phase 7. Its "no eval harness detected" HALT is what routes here.
- `retrieval-eval` — the retrieval half for a RAG feature; its labelled set is a separate artifact from this dataset.
- `prompt-audit` — a prompt with no version id makes a score unattributable; run it first where the prompt is unversioned.

### Patterns
- `ai/patterns/evals.md` (the design this command implements) · `rag-pipeline.md` · `agent-design.md` · `fine-tuning.md` (the held-out baseline a fine-tune must beat) · `prompt-engineering.md`.

### Rules
- `.claude/rules/ai-engineering-principles.md` — AI-2 (every LLM feature has a regression-gating eval set run in CI).
