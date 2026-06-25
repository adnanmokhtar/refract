---
description: Analyze existing code for algorithmic complexity — derive time + space big-O per hot path (worst / amortized / expected) from the code structure, flag accidental-quadratic / wrong-container / repeated-recompute defects, and rank the asymptotic wins with their tradeoffs. Driven by the algorithm-designer agent. Stack-agnostic; analysis-first.
kind: command
pack: algorithms
---

# /analyze-complexity [<scope>]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). The default run is already analysis-only (it writes a report, edits nothing); `--plan` additionally writes the ranked candidates as an executable plan to `.claude/plans/` for `/execute-plan`. Use `--fix` to apply the unambiguous wins in place.

## The Premise (read this first, internalize, do not deviate)

**You point it at code; it derives what that code actually costs — and where an asymptotic win is hiding.** Driven by the [`algorithm-designer`](../agents/algorithm-designer.md) agent in ANALYSIS mode: *prove it, don't profile it.* Every `O(...)` is **derived from the code's structure** — the nested loop at `<path:line>`, the recurrence, the amortized argument — and cited, never guessed. This is the reasoning complement of a profiler: it finds the defects that are wrong **by design** (an `O(n²)` membership test, a list used where a hash map fits), which a flamegraph shows as "slow" but never explains.

The flow: resolve scope → **derive** time + space complexity per hot path (worst / amortized / expected) → run the **detection vocabulary** (accidental-quadratic, wrong-container, repeated-recompute, sort-in-loop, string-build-quadratic, unmemoized recursion) → keep only the **hot, asymptotic** findings → **rank** the wins by class-improvement × confidence, each with its tradeoff and the proven-primitive fix. Default is a report; `--fix` applies only the unambiguous swaps.

Two anchors: **hot and asymptotic only** (a real `O(n²)` on a path that runs once on `n=5` is not a finding — that is premature; constant-factor and I/O issues belong to `performance-optimizer`), and **derived, not guessed** (a complexity claim without the construct it came from is deleted).

## When to use
- A function/module is suspected slow **by design** and you want the complexity *derived and cited*, not a flamegraph.
- Before scaling an input by orders of magnitude — find the paths that won't survive the new `n`.
- During P2/P3 hardening or review, to catch accidental-quadratic and wrong-container defects a profiler won't explain.
- As the analysis half of a redesign — feed the ranked candidates to `/design-algorithm`.

## When NOT to use
- The code is slow for a **measured runtime** reason (N+1, missing index, blocking I/O, GC, render churn) → `/perf-audit` / `performance-optimizer`.
- You already know the algorithm is wrong and want it redesigned + implemented → `/design-algorithm`.
- You want an architectural (module/layer) diagnosis → `/optimize`.

## Pre-requisites
- A readable scope: a `<path>`, a function, a module, or no arg (defaults to changed files since the last commit). For `--fix`, a clean working tree (fixes land as reviewable commits; `git` is the rollback).

## Args
- `<scope>` — a file, directory, function name, or `<path:line>`. No arg → changed files since the last commit.
- `--fix` — apply the **unambiguous** asymptotic wins in place (wrong-container → hash/set swap, dedup-via-set, hoist-invariant-out-of-loop, memoize a pure result), each with a covering test; ambiguous or large redesigns are listed and routed to `/design-algorithm`, never auto-applied.
- `--hot=<spec>` — treat only these paths as hot (e.g. `--hot="src/feed/**"`); everything else is reported as cold/skipped. Default: infer hotness from loops over request/collection-scale data, and flag uncertainty rather than guess.
- `--include-cold` — report complexity for cold paths too (informational); they are never proposed for a fix.
- `--space` — include the space-complexity derivation per path (peak allocation + recursion depth + hidden copies), not just time.
- `--plan` — also write the ranked candidates as an executable plan to `.claude/plans/`.

```bash
/analyze-complexity src/feed/ranker.ts                 # derive complexity + rank wins
/analyze-complexity                                     # changed files since last commit
/analyze-complexity src/search/ --fix                   # apply the unambiguous asymptotic swaps
/analyze-complexity src/import/parser.py --space        # include space-complexity derivation
```

## What happens internally

**Discipline:** governed by the [`algorithm-designer`](../agents/algorithm-designer.md) agent (ANALYSIS mode); complexity derived via the [`complexity-derivation`](../skills/complexity-derivation.md) skill; any `--fix` carries the SOLID/clean-code discipline in [`core-discipline.md`](../../../governance/core-discipline.md) + a covering test. Phases are silent.

1. **Scope + hotness** — resolve the scope; classify each path hot vs cold (a defect on a cold path is informational, never a ranked fix). When hotness is uncertain, flag it rather than assume.
2. **Derive** — for each hot path, derive time complexity (and space under `--space`) from the structure: loop nesting → product, recursion → recurrence + Master theorem, amortized where structures grow, expected vs worst for hashing/randomization. Cite the construct each bound comes from. Report the dominating term with the variable defined.
3. **Detect** — run the detection vocabulary; tag each defect with its label, derived class, and the class after the proven-primitive fix.
4. **Rank** — order the hot asymptotic findings by class-improvement × confidence; for each, state the fix (data-structure / paradigm change), the tradeoff (space / readability / threshold), and the routed owner for anything out of lane (N+1 → `performance-optimizer`, structure → `/optimize`).
5. **Report or fix** — emit the Complexity Report. Under `--fix`, apply only the unambiguous swaps with tests; route the rest to `/design-algorithm`.

## What you see

```
/analyze-complexity src/feed/ranker.ts

Per hot path:
  ranker.ts:31 rankFeed()    time O(n·a)  (n=items, a=authors), space O(n)
                             dominating: `authors.find` is O(a) inside the n-item loop; derived from loops at 31,38
  ranker.ts:77 scoreOne()    time O(log n), space O(1)  ✓ within budget

Ranked asymptotic wins (hot only):
  1. accidental-quadratic @ ranker.ts:38 — O(n·a) → O(n)
     `authors.find(...)` inside the items loop → index authors into a Map once.
     tradeoff: +O(a) space for the Map. confidence: high.
  2. repeated-recompute @ ranker.ts:52 — re-sorts tags each item → O(n·m log m) → O(m log m)
     hoist the sort above the loop. tradeoff: none. confidence: high.

Out of lane (routed): the per-item DB fetch at :44 is an N+1 → performance-optimizer.
Report: .claude/artifacts/algorithm/2026-06-26T.../report.md
```

Under `--fix`, the two high-confidence swaps land as commits with tests; the report still prints, and the output then carries the house honesty footer because the tree was mutated:

```
Built (--fix):  2 swaps · 2 covering tests · tests green · commits: 2

Not validated:  the O(n²)→O(n) win is asymptotic, not benchmarked — measure if the constant factor matters
Risks:          the Map swap adds O(a) memory; confirm `a` fits the request budget
Revert:         git revert <first>..<last>
```

A pure analysis run (no `--fix`) ends at `Report:` and writes nothing, so it carries no `Revert:`. Cold-path complexity appears only under `--include-cold`.

## Hard rules
- **Derived, not guessed**: every `O(...)` cites the loop nesting / recurrence / amortized argument it came from, or it is deleted.
- **Hot + asymptotic only**: a defect on a provably cold path is informational, never a ranked fix; constant-factor / I/O / micro-op issues are **not** findings here — route them to `performance-optimizer` (and only when measured).
- **Worst-case named**: report worst-case by default; give amortized and expected separately when they differ (and note the adversarial worst for hashing on untrusted input).
- **`--fix` is conservative**: only unambiguous, behavior-preserving asymptotic swaps with a covering test land automatically; redesigns route to `/design-algorithm`. Never change observable behavior. A `--fix` run mutates the tree, so it ends with the house honesty footer (`Not validated: / Risks: / Revert:`); `git` is the rollback. The derivation/ranking is **agent-side discipline, not an automated gate**.
- **Stay in lane**: N+1 / index / blocking I/O → `performance-optimizer`; module/layer structure → `/optimize`; shape-only cleanup → `/refactor`.
- **Project-agnostic** output: anonymous examples, primitives named by role; chat brief; the full report lives in `.claude/artifacts/algorithm/<iso>/`.

## Failure modes
- **Everything is cold / runs at trivial `n`** — report the derived complexity for the record, recommend no action (premature), and stop. Do not invent urgency.
- **The dominating cost is measured-runtime, not asymptotic** (N+1, slow query, blocking I/O) — say so and route to `performance-optimizer`; do not force an algorithmic framing.
- **`--fix` on an ambiguous win** (the swap could change ordering/semantics, or needs a real redesign) — do NOT apply; list it and route to `/design-algorithm` with the brief seed.
- **Hotness genuinely unknown** (no profile, no clear scale signal) — flag the uncertainty per path; do not assume hot, and do not auto-fix an unconfirmed-hot path.
- **Recursion whose bound depends on un-derivable input shape** — state the assumption explicitly (e.g. "balanced → O(log n); skewed → O(n)") rather than a single number.

## Cross-references
- agent [`algorithm-designer`](../agents/algorithm-designer.md) — owns the derivation, the detection vocabulary, and the ranking.
- skill [`complexity-derivation`](../skills/complexity-derivation.md) — the mechanical big-O / recurrence / amortized engine.
- rule [`algorithm-principles`](../rules/algorithm-principles.md) — the always-on complexity discipline.
- `/design-algorithm` — the design counterpart: turn a ranked candidate (or a fresh problem) into a proven, implemented algorithm.
- `performance-optimizer` · `/perf-audit` · `/optimize` · `/refactor` — the measured-runtime / architectural / shape-preserving neighbors this command routes to.

## Stack scope
Stack-agnostic — complexity is language-independent. The derivation reads the code's structure in any language; `--fix` uses the project's actual stack + idioms and the language's standard containers.
