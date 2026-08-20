# algorithms pack — changelog

Release history for `templates/packs/algorithms/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.2.0 — 2026-07-10

- ai-patterns +1: numerical-methods (signal-gated — float tolerance not ==, cancellation-safe
  accumulation, condition-number awareness, money->decimal handoff to business pricing-tax).

## 1.1.0 — 2026-07-09

- rules/algorithm-principles.md: added Should / Review checklist / Enforcement / Related (was Must +
  Must-not only) — brings the rule to the house contract.
- skills/complexity-derivation.md: heading drift fixed to house vocab (Purpose->Premise, When to
  use->When to run, Failure modes->Halt conditions, Cross-references->Related); content unchanged.
- NEW ai-patterns/sublinear-structures.md (kind:pattern, signal-gated on
  streaming/cardinality/sketch evidence) — Bloom/HyperLogLog/Count-Min/reservoir (+
  t-digest/MinHash) with the answer/space/error-mode table, sizing formulas (Bloom m/k, HLL register
  error, Count-Min w/d), when-NOT-to-use, and four cite-or-halt detectors (exact-won't-fit /
  unsized-no-error / wrong-error-mode / sketch-where-exact-is-cheap). Delivers the rule's sub-linear
  budget the pack previously only asserted. Registered in _topics + _essentials.

## 1.0.0 — 2026-06-26

- NEW agent algorithm-designer (model: opus) — the algorithmic/asymptotic specialist. Premise:
  prove-it-don't-profile-it, the-constraints-set-the-budget, correct-first-fast-second,
  use-the-proven-primitive. Owns the two-mode split (design + analysis), the complexity-derivation
  discipline, a detection vocabulary (accidental-quadratic, wrong-container, repeated-recompute,
  sort-in-loop, string-build-quadratic, unmemoized-recursion), and a paradigm/data-structure
  selection method. Mechanical halts (cite-or-halt complexity, correctness-or-halt,
  proven-primitive-or-halt, asymptotic-hot-only).
- NEW command /design-algorithm <problem-or-scope> — model → budget (from scale) → candidates →
  choose (simplest meeting budget, named tradeoff) → prove correctness (invariant + edge-case table)
  → implement with property (vs brute-force oracle) + adversarial tests. Flags: --scale, --budget,
  --candidates, --no-tests, --plan (design-only). Stack-agnostic.
- NEW command /analyze-complexity [<scope>] — derive cited time/space complexity per hot path
  (worst/amortized/expected), run the detection vocabulary, rank the asymptotic wins with tradeoffs.
  Analysis-first; --fix applies only the unambiguous behavior-preserving swaps with tests; --hot,
  --include-cold, --space, --plan. Routes N+1 → performance-optimizer, structure → /optimize.
- NEW skill complexity-derivation — the shared engine: loop-nesting products, divide-and-conquer
  recurrences (recursion tree / Master theorem), amortized (aggregate/accounting), expected-vs-worst
  for randomized/hashed, space (peak alloc + recursion depth + hidden copies). Every bound cites the
  construct it came from; an uncited O(...) is not a valid output.
- NEW rule algorithm-principles (severity: must) — budget-from-scale, derive-and-cite,
  prove-correctness-before-speed, proven-primitive-over-hand-rolled,
  right-container-for-access-pattern, explicit space-time tradeoff, worst-case (+ adversarial for
  hashing); must-nots: guess complexity, over-engineer past budget, optimize cold/non-asymptotic
  paths, hand-roll a solved classic, change behavior under 'optimization', ship fast-without-proof.
- Reciprocal boundary routes added to the named neighbors so the hand-offs are real, not asserted:
  refactorer (code-quality, bumped 1.5.1) now routes algorithmic/complexity-class changes here;
  commands/optimize.md (core) routes complexity-class findings (accidental-quadratic /
  wrong-container / exponential recursion) here rather than absorbing them; performance-optimizer
  (performance, bumped 1.2.1) now routes complexity-class CPU-loop defects here and states the
  boundary as a shared CPU-loop surface arbitrated by asymptotic-vs-constant-factor (not 'loops are
  mine'). The /design-algorithm + /analyze-complexity verification steps (correctness argument,
  property/adversarial tests, complexity guard) are labeled agent-side discipline, not an automated
  gate; --fix carries the honesty footer; --no-tests skips the suite but never the proof.
- Sync chain: _essentials.md + _topics.md (all topics always-on, fallbacks point at live sources —
  no _examples stubs), docs/COMMANDS.md (Other-tracks line), docs/CHEATSHEET.md regenerated (the two
  commands + their flags). Stack-agnostic single-dispatch commands — translated via the generic
  adapter pipeline, no per-pack coverage file (matches performance/database).
