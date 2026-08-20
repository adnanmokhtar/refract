# ai-engineering pack — changelog

Release history for `templates/packs/ai-engineering/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.3.0 — 2026-08-20

- The seven ai-patterns carried 39 closure verbs and zero artifacts that ran them: `eval-run` was the
  only skill, and its no-harness HALT pointed at a pattern file rather than at anything that could
  build one. This release puts an owner behind every pattern.
- agents +2: `rag-architect` (opus) designs the retrieval pipeline AND the ANN index underneath it as
  one artifact — corpus, chunking table, metadata schema, embedding model, the index with a **stated**
  recall/latency/scale target, hybrid fusion, reranker, the tenant predicate enforced at the store,
  context assembly + token budget, the no-context guard, and the labelled question→gold-chunk set that
  proves any of it. `agent-loop-architect` (opus) designs an LLM agent's control flow and more often
  argues it down the autonomy ladder into a workflow; tool contracts, the four budgets (steps, tokens,
  dollars, wall-clock), HITL tiers by blast radius, context compaction, plus an Audit mode that runs
  the `agent-design` detectors on an existing loop. Its name is deliberately unambiguous — "agent" is
  overloaded in this repo, and the file opens by disambiguating an LLM agent loop from a
  `.claude/agents/*.md` artifact.
- skills +4: `prompt-audit` (the five prompt-engineering detectors, with a per-provider table for what
  structured output and the system channel even ARE — and "no schema mechanism on this provider" as a
  distinct reportable state), `llm-gateway-audit` (the seam inventory plus seven detectors; bypass
  sites enumerated individually, never counted), `retrieval-eval` (recall@k **filtered and
  unfiltered**, context precision, and the retrieval-vs-generation split that says which stage failed),
  `vector-index-audit` (the index inventory plus five detectors against a stated target).
- commands +2: `/ai-audit` — read-only six-axis sweep of an existing AI surface, with a mechanical
  signal→dispatch table, ranked findings carrying their owning pattern's closure verb, and a dated
  artifact; it may never print a green verdict while the eval axis is UNVERIFIED. `/add-eval-set` —
  retrofits the regression gate onto a feature that shipped without one (dataset, scorers, pinned
  de-biased judge, an absolute threshold declared BEFORE the first run, committed baseline, CI step
  that exits non-zero). Named for the `evals` closure verb and deliberately distinct from the learning
  pack's existing `/eval`, which grades the project's knowledge base — both new commands carry that
  anti-trigger in their intent gates.
- Honesty discipline carried through every new artifact: no projected cost saving, no estimated recall,
  no implied cache hit-rate. Where a number cannot be read the output is `UNSTATED` / `UNMEASURED` /
  `UNVERIFIED` plus the one change that would settle it.
- ai-feature-reviewer: pre-flight now reads `vector-store-ops.md` and `fine-tuning.md` (both patterns
  named this agent as their reviewer while it ignored them); dimension 3 grades the index layer
  (stated target, non-defaulted params, metric/normalisation/dim match, refresh path); **new dimension
  7** enforces the fine-tuning ladder, behaviour-not-knowledge, the held-out baseline diff, train/eval
  leakage, and the versioned model+dataset+eval triple; a per-dimension dispatch table names which
  skill backs each axis; `UNVERIFIED` added to the grade legend; sibling-agent boundaries added.
- eval-run: the no-harness HALT now names `/add-eval-set` — the single most important de-orphaning
  edit in this release; references gained `retrieval-eval` (the runner behind the retrieval metrics it
  previously named with nothing behind them) and `/ai-audit` as a dispatcher.
- add-ai-feature: Phase 2 dispatches `@rag-architect` / `@agent-loop-architect` instead of saying
  "mirror the pattern"; Phase 5 routes the no-harness case to `/add-eval-set`; Phase 7 adds
  `retrieval-eval` + `vector-index-audit` and a `prompt-audit` + `llm-gateway-audit` pre-review sweep;
  the intent gate gained the `/ai-audit` and `/add-eval-set` redirects.
- ai-engineering-principles: Enforcement now names the standing sweep (`/ai-audit`), the mechanical
  checks behind AI-3…AI-9, and the no-harness retrofit path; Related lists the in-pack agents, skills,
  and commands. No new Must/Should items — AI-1…AI-9 already covered the ground.
- `_examples/` +8 condensed fallbacks (one per new artifact) — these are what a greenfield project
  receives in COPY mode, so the three pre-existing fallbacks (`add-ai-feature`, `ai-feature-reviewer`,
  `eval-run`) were re-wired too. That second failure mode is invisible: skipping it keeps every gate
  green while silently shipping the pre-build-out wiring.

## 1.2.0 — 2026-07-10

- add-ai-feature Ship gate — production-grade or INCOMPLETE: 3-axis table (eval / guardrails /
  budget); a NEW feature gates on the ABSOLUTE declared threshold (first run establishes baseline
  yet must clear the bar); binary Status: COMPLETE replaced with a Ship-verdict block.
- ai-feature-reviewer: Eval gate now requires a cited eval-run + cleared measured score; Guardrails
  dimension adds bounded input validation / injection / PII checks.

## 1.1.1 — 2026-07-10

- add-ai-feature: completion criterion made honest — asserts what it can verify (eval-run PASS at
  baseline + the CI eval-gate step is present in the pipeline config), not the unprovable 'the build
  will fail'. The real eval-run below-baseline HALT is untouched.

## 1.1.0 — 2026-07-10

- ai-patterns +2: fine-tuning (last-resort decision ladder after prompt+RAG, eval-gated + versioned)
  and vector-store-ops (ANN index tuning — HNSW/IVF params, recall/latency, filtered-recall, refresh
  — under rag-pipeline's retrieval).

## 1.0.0 — 2026-07-09

- Initial baseline.
