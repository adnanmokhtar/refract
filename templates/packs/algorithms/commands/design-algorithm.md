---
description: Design an algorithm for a problem (or redesign an existing function) — model it, derive the complexity budget from the input scale, weigh candidate approaches across the paradigm spectrum, pick the simplest that meets the budget, prove it correct, then implement it with property + adversarial tests. Driven by the algorithm-designer agent. Stack-agnostic.
kind: command
pack: algorithms
---

# /design-algorithm <problem-or-scope> [<more>...]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/design-algorithm <problem> --plan` produces the **Algorithm Brief** (model → budget → candidates → choice → correctness → plan) and stops *before* implementing — review the approach, then execute later with `/execute-plan <file>`. `--plan` is the design-only mode; the default run designs AND implements.

## The Premise (read this first, internalize, do not deviate)

**You give it a problem; it chooses the right algorithm for the scale, proves it correct, and ships it.** Driven by the [`algorithm-designer`](../agents/algorithm-designer.md) agent's Premise — *prove it don't profile it*, *the constraints set the budget*, *correct first fast second*, *use the proven primitive*. This command does not hand-roll that discipline; it composes the agent for the reasoning and then implements the chosen approach with the tests that pin it.

The flow: **model** the problem (inputs, scale, constraints, exact output) → **derive the budget** (the target complexity class from the input scale) → **enumerate candidates** across the paradigm spectrum (brute force first as the correctness oracle, then the paradigm that fits) → **choose** the simplest that meets the budget, naming the tradeoff → **prove correctness** (invariant / induction / exchange argument + an edge-case table) → **implement** against proven primitives with **property + adversarial tests**. The brief is the durable artifact; the code + tests are the deliverable.

Two anchors: **the budget is set by the scale, not by taste** (an algorithm that buys a complexity class the inputs never reach is over-engineering; one that misses the budget is a defect), and **a faster algorithm that is wrong is a regression** (nothing ships without a correctness argument or the adversarial test that would catch its specific failure mode).

### `/design-algorithm` vs `/analyze-complexity` vs `/optimize` vs `/add-feature`

| | `/design-algorithm` | `/analyze-complexity` | `/optimize` | `/add-feature` |
|---|---|---|---|---|
| Input | a problem / a function to redesign | existing code | a scope (architecture + tactics) | a feature description |
| Job | **invent** the algorithm + implement it | **derive** complexity, rank asymptotic wins | architectural + tactical sweep | scaffold + implement a feature |
| Reasons or measures | **reasons** (complexity proof) | **reasons** | measures + diagnoses structure | builds to spec |
| Correctness proof | **yes — invariant + adversarial tests** | flags risk | no | tests to spec |

## When to use
- A new problem needs the *right* algorithm, not the first one that compiles (a search/match/schedule/dedup/path/ranking core).
- An existing function is the obvious bottleneck **by design** (accidental `O(n²)`, exponential recursion) and needs a genuine algorithmic redesign, not constant-factor tuning.
- The input scale changed (10³ → 10⁷) and the current approach no longer fits its budget.

## When NOT to use
- The code is slow for a **measured runtime** reason — N+1, missing index, blocking I/O, GC → `/optimize` then `performance-optimizer`.
- You only need behavior-and-complexity-preserving cleanup (extract / rename / flatten) → `/refactor`.
- You just want the complexity of existing code measured, not a redesign → `/analyze-complexity`.
- A brand-new feature that doesn't exist yet → `/add-feature` (call `/design-algorithm` for its algorithmic core if it has one).

## Pre-requisites
- A statable problem: the inputs and their **scale/ranges**, the constraints, and the exact expected output. Unstated scale → the command asks for it (the budget can't be set without it); unstated output → HALT (the correctness oracle needs it).
- For a redesign: the target `<path:line>` of the function and at least one example input/output (or an existing test) to preserve as the behavior contract.
- Working tree clean when the default run will implement (the implementation lands as reviewable commits; `git` is the rollback). Relaxed under `--plan`.

## Args
- `<problem-or-scope>` — a problem statement in prose, a spec path, or a `<path:line>` / function name to redesign. Bounds the work.
- `--scale=<spec>` — the input scale when it isn't in the problem text (e.g. `--scale="n<=1e6, values<=1e9"`). Sets the complexity budget directly.
- `--budget=<class>` — pin the target complexity class explicitly (e.g. `--budget="O(n log n) time, O(n) space"`) instead of deriving it from the scale.
- `--candidates=<n>` — how many distinct approaches to weigh in the brief before choosing (default: the brute-force baseline + the 2 best-fit paradigms).
- `--no-tests` — produce the implementation without the executable property/adversarial test *suite*. The brief's **correctness argument (invariant) still ships** — this never bypasses the proof, only the executable pinning — and the un-pinned status is flagged under `Not validated:`. NOT recommended.
- `--plan` — **design-only.** Write the Algorithm Brief to `.claude/plans/` (as the executable plan artifact for `/execute-plan`) and stop before implementing. (The default run instead writes the brief to `.claude/artifacts/algorithm/<iso>/` and proceeds to implement.)

```bash
/design-algorithm "dedup 5M event ids preserving first-seen order"   # design → implement → test
/design-algorithm src/match/scorer.ts:42 --scale="n<=1e5"            # redesign a function to its budget
/design-algorithm "top-k trending tags over a 24h sliding window" --plan   # just the brief
```

## What happens internally

**Discipline:** the design pass is governed by the [`algorithm-designer`](../agents/algorithm-designer.md) agent (cite-or-halt complexity, correct-first, proven-primitive); complexity is derived via the [`complexity-derivation`](../skills/complexity-derivation.md) skill; the implementation carries the SOLID/clean-code discipline in [`core-discipline.md`](../../../governance/core-discipline.md). Phases are silent — no phase numbers reach the user.

1. **Model** — parse the problem; pin inputs + ranges + constraints + exact output + invariants. Resolve `<scope>`; for a redesign, read the function + its behavior contract (tests/examples). HALT if the output is unspecified.
2. **Budget** — derive the target time + space class from the scale (or `--budget`/`--scale`). State it; it is the bar.
3. **Diverge** — enumerate candidates: brute force (the correctness oracle), then the best-fit paradigms; derive each one's complexity (cited). Collapse any that don't beat the baseline within the budget.
4. **Choose** — the simplest candidate that meets the budget; name the space-time tradeoff and, if not the simplest overall, the scale threshold that justifies it.
5. **Prove** — invariant / induction / exchange argument; build the edge-case table (empty, single, all-equal, sorted/reverse, duplicates, max-size, overflow, adversarial) and show each is handled. Under `--plan`, write the brief to `.claude/plans/` and STOP here.
6. **Implement + verify** — implement against proven primitives; write **property tests** (the brute force is the oracle: random inputs must agree) + **adversarial tests** (the edge-case table) + a **complexity guard** where feasible (e.g. an operation-count assertion that would fail if the bound regressed). Run them; land as commits.

> These verification steps (the correctness argument, the property/adversarial suite, the complexity guard) are **agent-side discipline, not an automated gate** — there is no validator that blocks the run if they are skipped. They are real, runnable tests the command writes and executes, but the rigor is the agent's, the way `/optimize`'s checks are agent-side. `--no-tests` opts out of the suite (not the proof).

## What you see

```
/design-algorithm "dedup 5M event ids preserving first-seen order"

Model:     in: up to 5e6 ids (64-bit), out: ids in first-seen order, dups removed
Budget:    n ≤ 5e6 → O(n) time, O(n) space
Chosen:    single pass + seen-Set, append-if-absent  (O(n) / O(n))
           over: sort+dedup O(n log n) — loses first-seen order, misses budget
Correct:   invariant — output holds exactly the distinct ids in first-seen order;
           edge cases ✓ (empty · all-dup · all-unique · 5e6 max)
Built:     impl + 4 adversarial + 1 property test (vs brute-force oracle, 10k cases)
           complexity guard: membership O(1) *expected* (hash Set), total O(n) ✓ — ids are internal 64-bit, no adversarial-collision exposure (salt/validate if untrusted)
Commits:   2 (impl · tests) · tests green

Not validated: real-data memory ceiling at 5e6 (Set overhead ~) — note under Risks
Risks:         Set holds all distinct ids in memory; if n ≫ RAM, route to an external/streaming dedup
Revert:        git revert <first>..<last>
```

Under `--plan`, output ends at `Correct:` + the brief path — nothing is implemented.

## Hard rules
- The agent Premise is read first and never deviated from: derive-don't-guess, budget-from-scale, correct-first, proven-primitive.
- **Cite-or-halt** complexity: every `O(...)` carries the loop nesting / recurrence it came from, or it is deleted.
- **Budget from scale**: the target class is set by the input scale, not taste; the simplest algorithm meeting it wins. Name the tradeoff for anything more complex.
- **No ship without a proof**: every implementation carries a correctness argument + the property/adversarial tests that would catch its failure mode (unless `--no-tests`, which flags it unproven).
- **Behavior preserved on redesign**: same output + ordering + error semantics as the contract; a behavior change is surfaced, never smuggled.
- **Stay in lane**: measured-runtime work (N+1, I/O, index) routes to `performance-optimizer`; architecture routes to `/optimize`; shape-only cleanup routes to `/refactor`. This command does not poach them.
- **Build, don't fabricate**: real commits + green tests; `git` is the rollback. Every run ends with the house honesty footer (`Not validated: / Risks: / Revert:`); chat stays brief; the full brief lives in `.claude/artifacts/algorithm/<iso>/` (or `.claude/plans/` under `--plan`, where it is the executable plan artifact).

## Failure modes
- **Output/behavior unspecified** — HALT; the correctness oracle has nothing to check against. Ask for the expected output or an example.
- **Scale unstated** — ask for it (or accept `--scale`); the budget cannot be derived without it. Do not silently assume small `n`.
- **The current code is already at its budget and correct** — HALT; do not invent a redesign. If it is *slow but optimal asymptotically*, route to `performance-optimizer` (constant factors) and stop.
- **The optimal algorithm is far more complex for a win below the relevant scale** — recommend the simpler algorithm, state the `n` threshold where the complex one pays off, and stop.
- **The win is a measured-runtime issue, not asymptotic** (N+1, missing index, blocking I/O) — route to `performance-optimizer`; this is not an algorithm-design job.
- **A proven primitive already solves it** — use it; do not hand-roll. Note the primitive and move on.

## Cross-references
- agent [`algorithm-designer`](../agents/algorithm-designer.md) — owns the design method, the complexity discipline, and the correctness argument.
- skill [`complexity-derivation`](../skills/complexity-derivation.md) — derives the budget + each candidate's class.
- rule [`algorithm-principles`](../rules/algorithm-principles.md) — the always-on budget / proven-primitive / correctness discipline.
- `/analyze-complexity` — the analysis counterpart: derive the complexity of *existing* code and rank its asymptotic wins.
- `performance-optimizer` · `/optimize` · `/refactor` — the measured-runtime / architectural / shape-preserving neighbors this command hands off to.

## Stack scope
Stack-agnostic — algorithms and complexity are language-independent. Proven primitives are named by role (the language's standard sort / heap / hash map); the implementation uses the project's actual stack + idioms.
