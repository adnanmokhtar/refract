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
- skills: `extract-project-context` is the only round-one skill a *project* invokes directly (greenfield bootstrap), so it is the only one listed as an essential. The pack ships twelve; the other eleven are engine — `extract-codebase-overview` / `extract-business-context` / `extract-base-class-idiom` / `apply-pack-adaptation` are invoked by `templates/phases/`, and the seven round-two extractors are gated on `--refine` and listed under `refine_mode_skills:` below. All twelve are copied to every project by Phase 4.2's shape-aware skills loop regardless of this list; `essentials:` governs what MINIMAL mode names, not what ships.
- rules: none, deliberately — learning is the only pack of 23 with no `rules/` dir and it is absent from `scripts/_rule-budget-baseline.txt`, so it contributes **0 always-loaded tokens** to every project while being ALWAYS-applied. The disciplines are not scattered: provenance lives in `templates/phases/phase-2-profile.md` (framework-side, never copied into a project), promotion thresholds in `templates/snippets/learning-sink.md` (linked by all three writers so they cannot diverge), and `[SAMPLED]` / `[CONTESTED]` / `[EXTRACTION-WEAK]` in the skills that emit them. The one genuinely cross-cutting discipline — "a contested convention is not a rule; do not fix code following the minority" — is a **consumer** gap, not a rule gap, and is closed in `convention-drift-detector § Contested categories` + `/detect-drift` Phase 3 rather than by charging every project tokens on every turn. Keep `rules: []`.
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
