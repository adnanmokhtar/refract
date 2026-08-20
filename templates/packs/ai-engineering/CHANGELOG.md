# ai-engineering pack — changelog

Release history for `templates/packs/ai-engineering/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

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
