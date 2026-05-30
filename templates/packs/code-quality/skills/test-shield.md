---
description: Pre-sweep coverage gate for behaviour-preserving work (/optimize, /audit refactor + perf verbs). "Refactor, tests stay green" is only proof of preservation if a test actually exercises the touched branch — on an UNCOVERED branch a structural fix can silently change behaviour and still show green. Before such a fix, this skill detects the touched-but-uncovered branches in scope and pins current behaviour with a characterization test (dispatching /add-test) BEFORE the fix lands, or halts the row. Reuses testing/skills/coverage-gap.md for detection.
kind: skill
pack: code-quality
---

# Skill: test-shield

## Purpose

A behaviour-preserving fix (refactor, dedup, dead-code, parallelize, cache) is only *safe* if the green suite actually covers the code it touches. On an **uncovered branch**, "tests still pass" proves nothing — the fix can flip behaviour and no test notices. `test-shield` makes the guarantee real: it **pins current behaviour with a test BEFORE the fix**, so any post-fix divergence turns the suite red.

This is the pre-sweep counterpart to `smoke-verify` (which runs after). Dead-code removal is already coverage-gated via `dead-branch-scan`; this closes the same gap for the refactoring + perf verbs.

## When to use

- Dispatched in **Phase 0** of `/optimize` and `/audit` (before any structural/perf fix), per in-scope file set.
- On demand: `pin coverage before refactoring <area>`.
- N/A for pure additive work (new feature, new file) — there's no existing behaviour to preserve.

## Procedure (stack-conditional via PROJECT_KIND + project test runner)

1. **Determine the touched set**: the files/functions the planned fix will modify (from the optimize/audit finding's scope).
2. **Measure coverage** of that set using the project's coverage tool (reuse `testing/skills/coverage-gap.md`; runner from `ai/stack.md` § Scripts — `pytest --cov` / `vitest --coverage` / `jest --coverage` / `go test -cover` / etc.).
3. **For each touched branch with no covering test**:
   - Dispatch `/add-test` to write a **characterization test** that asserts the CURRENT (pre-fix) observable behaviour — inputs → outputs/side-effects as they are TODAY, bugs included (this is a pin, not a correctness judgement).
   - Re-run; confirm the new test is green against current code.
   - If the branch genuinely cannot be characterized (true side-effect-only, external dependency, non-deterministic) → **HALT** that finding with `status: blocked` + reason; do NOT apply the structural fix to an un-pinnable branch.
4. **Gate**: only after every touched branch is covered (pre-existing or freshly pinned) may the sweep apply its fix. Coverage measured here is the floor `/optimize` step 7's "coverage must not drop" compares against.

## Verify (the check on the check)

- The added characterization tests are GREEN against current code (a red pin = the pin is wrong; fix it before proceeding).
- The touched branches are demonstrably covered now (re-measure, don't assume).
- Any un-pinnable branch left a `blocked` finding with an explicit reason — never a silent skip.

## Anti-patterns this prevents

- **The Coverage Mirage** — "behaviour preserved, tests green" on a branch no test exercises.
- **The Silent Coverage Drop** — a fix removes the only path exercising a downstream branch; coverage drops unnoticed in a large suite (test-shield's pre-measure is the baseline that catches it).

## See also

- `testing/skills/coverage-gap.md` — the coverage detection this reuses.
- `code-quality/skills/dead-branch-scan.md` — the analogous gate already wired for dead-code removal.
- `code-quality/skills/smoke-verify.md` — the post-sweep counterpart (boot-check).
- `/add-test` — the command that writes the characterization tests.
