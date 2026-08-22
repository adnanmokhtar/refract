---
name: algorithm-principles
description: Algorithm Principles
kind: rule
pack: algorithms
severity: must
applies-to: algorithms-track, every-algorithm-design-or-analysis-task
---

# Algorithm Principles

> **Hard rule.** The input scale sets the complexity budget — design to it, not past it. Every `O(...)` claim is derived from the code's structure and cited, never guessed. A faster algorithm ships only with a correctness argument (invariant / induction / adversarial test). Use the proven primitive; do not hand-roll a classic algorithm or container. Asymptotic, hot paths only — constant-factor and measured-runtime work belongs to `performance-optimizer`.

## Must

- **Set the budget from the scale, first.** State the target time + space class from the input range before proposing an algorithm (`n ≤ 20` → exponential ok; `n ≤ 5e3` → `O(n²)`; `n ≤ 1e6` → `O(n log n)`; `n ≤ 1e9` / streaming → `O(n)` or sub-linear / `O(1)` memory). The simplest algorithm that meets the budget wins.
- **Derive complexity, cite the construct.** Every `O(...)` names where it came from — the nested loop at `<path:line>`, the recurrence `T(n)=…`, the amortized argument. Report the dominating term with the growth variable defined and the case (worst / amortized / expected) named.
- **Prove correctness before speed.** A designed or changed algorithm carries a loop/recursion invariant, an induction, or a greedy exchange argument — or the adversarial tests that would catch its specific failure mode (empty, single, all-equal, sorted/reverse, duplicates, max-size, overflow, adversarial input). Property-test against the brute-force oracle where one exists.
- **Use the proven primitive.** The standard library's sort, heap, hash map, balanced tree, and the textbook algorithm (BFS, Dijkstra, union-find, binary search, KMP) are correct and tuned. Reach for them first; hand-rolling one requires a named reason it doesn't fit.
- **Pick the right container for the access pattern** — the defect this rule catches most often, because it is written one line at a time and never looks wrong locally. Membership / keyed lookup → hash set/map (`O(1)`), not a linear scan (`.includes` / `.indexOf` / `find` / `in <list>` **inside a loop** is the signature). Ordered range / k-th → balanced tree / heap. Front-insert/pop → deque, not array `shift`. Repeated recompute of a value invariant across the loop → hoist or memoize. The container is part of the algorithm.
- **Make the space-time tradeoff explicit.** Memoization buys time with space; in-place buys space with clarity. State which you took and why; count recursion depth and hidden copies in the space bound.
- **Report worst-case, and the adversarial case for hashing.** Default to worst-case; give amortized / expected separately when they differ. On untrusted input, note where an adversary forces the worst case (hash collisions → `O(n)` per op).

## Must not

- **Guess complexity, hand-roll a solved classic, or ship a speedup with no proof** — the inverse of the three Musts above. "This is probably linear", "I wrote my own quicksort/hashmap", and a faster algorithm with no invariant or adversarial test are each deleted on sight, not negotiated.
- **Over-engineer past the budget.** A cleverer algorithm that buys a complexity class the inputs never reach, at a readability cost, is waste — default to the simpler one and name the `n` threshold where the complex one would pay off.
- **Optimize a cold or non-asymptotic path.** An algorithmic change on a path that runs once at trivial `n` is premature; a constant-factor / I/O / allocation issue is `performance-optimizer`'s (and only when measured). Stay in the asymptotic, hot lane.
- **Change observable behavior under "optimization."** Same output, ordering, and error semantics — a behavior change is surfaced as such, never smuggled into a complexity improvement.

## Should

- Prefer an in-place / single-pass streaming approach when the input is large and a copy would blow the space budget.
- When a sub-linear or `O(1)`-memory bound is the target (streaming, `n ≥ 1e8`, unbounded cardinality), reach for a probabilistic / sketch structure (Bloom / HyperLogLog / Count-Min / reservoir) and state the accuracy trade-off — see `sublinear-structures.md`.
- Numerical / floating-point code states its precision + stability regime: compare with a **tolerance**, never float `==`; accumulate cancellation-safely (Kahan / pairwise / Welford), not a naive running sum; guard near-zero divides and acknowledge the problem's **condition number** where it can be large. **Money / tax / currency uses an exact decimal type**, never float — and hands off to the business pricing-tax rules. See `numerical-methods.md` (signal-gated on numeric/scientific code).
- Property-test a designed algorithm against a brute-force oracle over random inputs, not just fixed cases.

## Enforcement

Convention + review — this pack ships no CI gate. `/analyze-complexity` derives + cites complexity on demand, `/design-algorithm` designs to the budget, `complexity-derivation` is the shared engine both run on, and `@algorithm-designer` owns the design + correctness verdict. A PR claiming a speedup with no derivation or correctness argument fails review. Lane boundary: a *measured* constant-factor / N+1 / index / I/O finding is `performance-optimizer`'s, not this pack's — asymptotic-vs-constant-factor is the line, not "loops".
