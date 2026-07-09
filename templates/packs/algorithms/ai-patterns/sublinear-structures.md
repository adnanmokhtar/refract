---
name: sublinear-structures
kind: ai-pattern
pack: algorithms
---

# Pattern: Sub-linear / probabilistic structures

> **Hard rule.** When the exact structure won't fit the space budget (streaming, `n ≥ 1e8`, unbounded cardinality, one pass over data you can't store), a **probabilistic structure trades a bounded, quantified error for sub-linear space**. Pick the one whose error mode your use case tolerates, and **state the error** (false-positive rate / relative error / probability) — an unquantified approximation is not an answer.

The `algorithm-principles` rule sets a "streaming → sub-linear / `O(1)` memory" budget; these are the techniques that actually meet it. Each answers a different question in space that does not grow with `n`.

## The four workhorses

| Structure | Answers | Space | Error mode |
|---|---|---|---|
| **Bloom filter** | "have I seen `x`?" (set membership) | `O(1)` per element, tunable | **False positives** only (says yes when no); never a false negative. Can't delete (use a counting Bloom / cuckoo filter if you must). |
| **HyperLogLog** | "how many *distinct* values?" (cardinality) | ~1.5 KB for billions, `O(1)` | ~2% relative error (tunable via register count). Mergeable across shards. |
| **Count-Min sketch** | "how often did `x` occur?" (frequency / heavy hitters) | fixed width×depth grid | **Over-counts** (never under); error bounded by `ε` with probability `1−δ`. |
| **Reservoir sampling** | "a uniform sample of `k` from a stream of unknown length" | `O(k)` | Exact uniform sample; no error, just sampling. |

Related: t-digest / GK for streaming **quantiles** (p50/p99 over a stream in bounded space); MinHash for **set similarity** (Jaccard estimate).

## When to use — and when NOT

- **Use** when the exact structure (a `Set`/`Map`/exact counter of every key) would exceed memory, or the data is a one-pass stream you can't replay, AND a small bounded error is acceptable.
- **Do NOT use** when the answer must be exact (billing, auth, correctness-critical dedup), when `n` is small enough for the exact structure (a Bloom filter for 10k items is silly — use a `Set`), or when the error mode is the wrong one (never a Bloom filter where a false positive is unsafe without a backing exact check).
- The exact structure is the default; a sketch is the deliberate choice you make *because* you cited the space budget it doesn't fit.

## Sizing (state the parameters, not just the name)

- **Bloom filter**: for `n` items at false-positive rate `p`, bits `m = −n·ln(p) / (ln 2)²`, hash count `k = (m/n)·ln 2`. (e.g. 1M items @ 1% → ~1.2 MB, 7 hashes.) A Bloom filter with no stated `n`/`p` is unsized.
- **HyperLogLog**: `b` register bits → `2^b` registers → standard error ≈ `1.04/√(2^b)` (e.g. `b=14` → 16 KB → ~0.8%).
- **Count-Min**: width `w = ⌈e/ε⌉`, depth `d = ⌈ln(1/δ)⌉` → error `≤ ε·N` with prob `1−δ`.

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix.

### 1. Exact structure that won't fit the scale

```
BAD:   const seen = new Set();  for (const x of billionRowStream) seen.add(x)   // OOM
GOOD:  a Bloom filter (membership) or HyperLogLog (if you only need the count)
```
Flag an exact `Set`/`Map`/array accumulating over a stream or `n ≥ 1e8` where only membership/cardinality/frequency is needed.

### 2. Probabilistic structure used with no stated error / no sizing

Flag a Bloom/HLL/Count-Min with no cited `n`/`p`/`ε`/`δ` — it's unfalsifiable. Fix: state the parameters + the resulting error.

### 3. Wrong error mode for the use case

Flag a Bloom filter where a false positive is unsafe with no backing exact check (e.g. "have we already charged this card?" — a false positive skips a real charge). Fix: use the sketch as a fast negative filter, confirm positives against the source of truth.

### 4. A sketch where the exact answer is cheap

Flag a probabilistic structure at small `n` (the exact `Set`/counter fits easily) — the approximation buys nothing and adds an error. Fix: use the exact structure.

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete structure + its sizing.
- `report-flagged` — the fix is a design call (accept approximate answers here? add a backing exact check?) → surface for ADR.
- `dismiss` — carve-out applies (exact answer genuinely required; `n` small) → documented.

## Related

- `algorithm-principles.md` — the "streaming → sub-linear" budget this pattern satisfies.
- `complexity-derivation.md` — deriving the `O(1)`-space / per-op bounds these give.
- `numerical-methods.md` — the sibling signal-gated pattern: *deterministic* float precision / stability / conditioning. This one trades bounded space for a stated *approximation* error; that one governs the rounding error of exact-arithmetic-intended float math.
- `@algorithm-designer` — picks the structure during DESIGN when the budget is sub-linear.
- `performance` / `database` packs — when the real fix is an index or a materialized count, not a sketch.
