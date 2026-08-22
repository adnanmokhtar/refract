# algorithms pack — changelog

Release history for `templates/packs/algorithms/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.3.0 — 2026-08-23

**The pack was reviewed for deletion and kept, on evidence.** Two measurements decided it.
1. Two neighbouring packs were *deliberately edited* to hand this lane over.
   `performance/agents/performance-optimizer.md` routes asymptotic-class CPU defects here explicitly
   ("A hot loop whose fix is an *asymptotic class change* ... is **not** this agent's finding. Route
   it to the algorithms pack"), and `code-quality/agents/refactorer.md` excludes algorithmic change
   from the refactor vocabulary by definition and names `/analyze-complexity` / `/design-algorithm`
   as the destination. Both reciprocal version bumps are recorded in this file's 1.0.0 entry.
   Absorbing algorithms into either neighbour would reverse three intentional boundary edits and park
   a "prove it, don't profile it" engine inside a pack premised on "measure, don't reason".
2. The framing that prompted the review — "a ~1,671-token rule is roughly a fifth of a 910-line pack"
   — compares a token count against a line count. Measured in one unit the rule is ~8.5 percent of
   the shipped pack, and 9th-smallest of the 22 pack rules. There was no budget emergency to solve.
   The pack is also opt-in only (`_registry.md` line 16; `grep -c algorithms scripts/detect-tracks.sh`
   returns 0), so its always-loaded cost is paid solely by a user who typed `--include=algorithms`.

**Rule budget.** `rules/algorithm-principles.md` 1,671 -> 1,369 tok (6,685 -> 5,478 chars, -18.1
percent) — shrunk anyway, because most of it was not doing always-loaded work.
- Deleted the **Review checklist**. Mapping its 7 items onto the 7 Musts returns 5-7 shared content
  words for 6 of them, and the 7th maps onto a Must-not: 7/7 restatement. It also only fires at
  review time, when `@algorithm-designer` — which carries the same discipline — is loaded anyway.
- Deleted the **Related** pointer block (5 lines), folding the one line that prevents lane-poaching
  (the `performance-optimizer` boundary) into Enforcement.
- Folded the three Must-nots that were pure inversions of Musts ("guess complexity", "hand-roll a
  solved classic", "ship a speedup with no proof") into one line, and dropped the Should bullet that
  restated an existing Must-not clause verbatim.
- Dropped the "Prevents the four failure modes" sentence, which re-stated the Hard rule directly
  above it in prose.
- **Sharpened what actually does passive work.** On an ordinary turn where nobody ran
  `/analyze-complexity`, the bullets that change what gets written are "use the proven primitive" and
  "pick the right container". The container bullet now carries its *detection signature* — a
  `.includes` / `.indexOf` / `find` / `in <list>` inside a loop — so it can fire while the code is
  being written rather than only during a later review.
- `_topics.md` `sections:` updated to match (`review_checklist` and `related` removed), so AUTHOR
  mode regenerates the rule with the sections it now has.

**No content defect was found** in `algorithm-designer`, `complexity-derivation`,
`/analyze-complexity`, `/design-algorithm`, `sublinear-structures` or `numerical-methods`, and
nothing else in the pack was edited. Re-derived in `python3` and confirmed correct: the Bloom sizing
`m = -n ln(p) / (ln 2)^2` and its "1M at 1 percent -> ~1.2 MB, 7 hashes" example, the HyperLogLog
standard error `1.04/sqrt(2^b)`, and the Master-theorem cases. Correcting a claim made during review:
`agents/algorithm-designer.md` **does** carry a boundary — "## Boundary — what is mine and what is
not" at line 39, a four-column decision table plus four explicit hand-off rules.

**Not done, and why.** The pack's real defect is that nothing selects it: `scripts/detect-tracks.sh`
has no `algorithms` block, so it is reachable only by a user who already knows the pack's name.
`_registry.md` documents this as deliberate rather than rotted. Adding a detector is the single
highest-leverage change available to this pack and it lives in `scripts/`, outside this lane —
raised as an integrator request instead.

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
