---
track: learning
purpose: Meta-track that keeps Claude's project knowledge fresh, detects convention drift, AND (round-two) deepens the setup against the real codebase. ALWAYS included regardless of --minimal.
essentials:
  agents: [knowledge-curator, convention-drift-detector, pattern-emergence-watcher]
  commands: [refresh-knowledge, detect-drift, learn-from-task, eval, recall]
  skills: [extract-project-context]
  rules: []
  ai-patterns: []
refine_mode_skills:
  - extract-domain-entities-deeply
  - extract-architecture-deeply
  - extract-flows-deeply
  - extract-conventions-emerging
  - extract-hotpaths
  - extract-failures-from-history
  - compute-anchor-density
refine_mode_patterns:
  - setup-quality-scoring
---

# Learning — essentials manifest

CRITICAL: this track is ALWAYS included regardless of `--minimal`. The learning loop is what keeps every other pack from rotting.

Pack v1.4.0: `/recall` searches the memory the loop already writes — the `ai/` tree — with the same stdlib BM25 that indexes the pack corpus. It adds **no sink**: `templates/snippets/learning-sink.md` is unchanged, the thresholds are unchanged, and the index is a gitignored derived cache.

Pack v1.2.0: the extraction engine enforces provenance discipline (`[found:]/[inferred:]/[unconfirmed]` on every `_extracted-*` claim) + the oracle approval stamp (`approved_by:`/`approved_hash:`) — see `templates/phases/phase-2-profile.md § Provenance discipline` / `§ Oracle approval`.

Files listed above are the full intended set for minimal mode (which here equals standard, except `promote-pattern` is a power-user command kept out of minimal).

Rationale per category (one line each):
- agents: all three are core — knowledge-curator (writes), convention-drift-detector (reads), pattern-emergence-watcher (notices). Removing any one breaks the loop.
- commands: refresh-knowledge, detect-drift, learn-from-task, eval, recall are the triggers a developer hits regularly — `/learn-from-task` captures, `/eval` grades, `/recall` reads back (capture without recall just grows files nobody reads, and `ai/failures/_index.md` has value only at the moment of recall); promote-pattern is advanced and excluded.
- skills: extract-project-context is the single skill in the pack and is foundational.
- rules: none — meta track, no rules to copy.
- ai-patterns: none — meta track, no patterns to copy.

## REFINE-mode skills (round-two deep extraction)

These are NOT essentials in the round-one sense — they're triggered by `/setup-project --refine` and consumed only when REFINE mode is selected. They live in this pack because they are extraction tools (the same conceptual category as `extract-base-class-idiom`):

- `extract-domain-entities-deeply` — Phase 2.7
- `extract-architecture-deeply` — Phase 2.8
- `extract-flows-deeply` — Phase 2.9
- `extract-conventions-emerging` — Phase 2.10
- `extract-hotpaths` — Phase 2.11
- `extract-failures-from-history` — Phase 2.12
- `compute-anchor-density` — Phase 5.5 (also used by `--health`)

Pattern:

- `setup-quality-scoring` — companion document to `compute-anchor-density`; documents the four-axis rubric and plateau-detection logic.

REFINE skills load in their own sub-context per Phase 2.7-2.12; they do NOT share context with round-one extraction skills.
