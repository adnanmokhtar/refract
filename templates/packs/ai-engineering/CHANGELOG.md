# ai-engineering pack — changelog

Release history for `templates/packs/ai-engineering/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.4.0 — 2026-08-23

Currency release. Two external standards this pack cited had moved underneath it, and both failures
were invisible to all 19 gates because no gate checks external-standard currency.

- **`temperature: 0` was a MUST across 12 files and is now an HTTP 400 on the model family this
  framework itself runs on.** Sampling parameters (`temperature` / `top_p` / `top_k`) return a 400
  error on current Anthropic models — Opus 4.7 and later, Sonnet 5, Fable 5 — with system-prompt
  instruction named as the documented replacement
  ([Sonnet 5 release notes](https://platform.claude.com/docs/en/about-claude/models/whats-new-sonnet-5),
  read 2026-08-23). The pack instructed the opposite as AI-5, an always-loaded MUST, and
  `prompt-audit` detector 4 emitted `set-deterministic-params` as the *fix* — advice that breaks
  every request on the path it is applied to.
  AI-5 is rewritten to state the decision rather than the parameter: constrain a single-answer task
  with the mechanism the provider actually exposes, read the current parameter reference before
  writing a sampling parameter, and treat a withdrawn parameter as an error rather than a no-op.
  `prompt-audit` gains a three-state sampling table (`EXPOSED` / `DEFAULT-NONZERO` / `REMOVED`) and
  detector 4 now **inverts** between them, emitting the new verb `remove-sampling-params` at BLOCKER
  on a `REMOVED` provider. Model id unresolved is `UNVERIFIED`, never a pass in either direction —
  the same line is correct on one model and a 400 on another.
- **OWASP-LLM ids migrated from the 2025 to the 2026 edition — 46 citations across 14 files.**
  The security pack was migrated in batch 1 and its `@llm-security-reviewer` now HALTs on a 2025
  number, so every handoff this pack made was mis-routing *and* tripping the receiver's halt.
  Improper Output Handling LLM05→**LLM10**, Excessive Agency LLM06→**LLM03**, Vector & Embedding
  LLM08→**LLM09**; LLM01 Prompt Injection unmoved. Every citation now carries its edition inline
  (`LLM03:2026`) so the next renumbering cannot be silent, and moved ids name their 2025 number too,
  per `security/agents/llm-security-reviewer.md:57`.
- **`_examples/add-ai-feature.md` shipped `Status: COMPLETE`, which its source forbids twice.** A
  pre-1.2.0 regression on the pack's only `_essentials.md` command — so it was what *every* greenfield
  and `--minimal` install received. The 1.2.0 three-state ship verdict (PRODUCTION-READY / UNVERIFIED
  / INCOMPLETE), its evidence table, and the "never print COMPLETE on a functional-but-unmeasured
  feature" hard rule are restored. Check 8b could not see it: a closing verdict block is not in its
  protected set.
- **`prompt-audit`'s Anthropic row missed the structured-output mechanism the provider has.** JSON-
  schema structured output is GA via `output_config.format` (the older `output_format` is deprecated),
  and tool definitions take `strict: true` for guaranteed input validation. A call site using either
  matched no row, breaking the skill's own contract ("did this call site use the mechanism this
  provider has"). Both are now in the table; absent `strict: true` is a detector-3 finding.
- **`llm-gateway-audit` detector 4 recommended a cache that can silently fail to exist.** Provider
  prompt caches have a model-dependent minimum cacheable prefix below which nothing caches *and no
  error is returned*, plus a per-request breakpoint ceiling. `add-prompt-cache` now requires the
  prefix's measured token count against that model's minimum; below it, the size is the finding, not
  the missing cache. A marked prefix reporting zero cache reads is its own finding.
- **`fine-tuning.md` answered "can we fine-tune?" from the vendor's name.** It is a property of the
  deployment surface: a hosted-partner platform may offer fine-tuning for a model whose first-party
  API does not. `@ai-feature-reviewer`'s routing rule turned the incomplete claim into a misfire in
  both directions; it now grades the named surface and the date it was confirmed.
- **New always-loaded MUST-NOT: no undated provider-behaviour claim.** A parameter name, context
  limit, price, model id or API shape carries the date it was checked and where. This is the root
  cause of everything above — the pack already demanded dated prices of *cost* figures and never
  applied the rule to itself.
- Rule shrunk 2817 → 2310 tok (−507, −18%) with four obligations *added*: the corrected AI-5, the
  undated-claim ban, poka-yoke tool design, and sandbox-before-production for autonomous loops
  (the last two are gaps against Anthropic's published agent guidance). The Review checklist (10
  restatements of Must/Must-not, zero new obligations) and the in-pack `## Related` catalogue (a
  table of contents; every file states its own scope) were deleted outright.
- **Deleted `_examples/ai-engineering-principles.md`** (72 lines). `_topics.md` declares
  `fallback: rules/ai-engineering-principles.md`, so the file could never install; measured, it was
  referenced nowhere outside its own frontmatter. It had already drifted two Shoulds and three
  Enforcement lines behind, and carried four stale OWASP ids in a file that ships to nothing.
- `/ai-audit`'s closure-verb list now states that it is a copy of the patterns' own lines and that
  the pattern wins on disagreement — it was drifting silently from seven sources.

FIXED (integration pass, same release)
- **`_examples/evals.md` still carried the uncorrected "judge at low temperature".** The source's
  judge-pin bullet in `ai-patterns/evals.md` was corrected this release to a provider-conditional
  pin; the fallback was not re-cut, so greenfield received the very instruction this release exists
  to retract — on the model family this framework runs on, `temperature` is not a low-value knob but
  a 400. Re-cut to the source's wording: pin every sampling parameter the provider still exposes (a
  low temperature where one exists); where it exposes none, the judge model id + prompt ARE the
  whole pin — record that and widen the delta treated as a regression, rather than implying a
  tighter pin than you have.

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
