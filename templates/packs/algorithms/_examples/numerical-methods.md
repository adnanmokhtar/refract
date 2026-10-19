---
name: numerical-methods
kind: example
pack: algorithms
---

# Pattern: Numerical methods (precision, stability, conditioning)

> **Hard rule.** Numerical code MUST state the precision/stability regime it assumes. Accumulation over many terms uses a **cancellation-safe** formula (Kahan / pairwise / Welford), not a naive running sum; products that can underflow and exponentials that can overflow work in **log-space**; the problem's **condition number** is acknowledged when it can be large, and a solve never goes through an explicit inverse. A naive sum of many terms, a sum-of-squares variance or an unconditioned solve in shipped numeric code is a **numerical bug**, not a style nit.

## Gate — only numeric code (printed, never assumed)

Apply only when a manifest names a numeric library (`numpy`, `scipy`, `pandas`, `polars`, `statsmodels`, `scikit-learn`, `torch`, `jax`, `numba`, `mpmath`, `mathjs`, `simple-statistics`, `ml-matrix`, `@tensorflow/tfjs`, `gonum`, Commons Math, `ndarray`, `nalgebra`, `statrs`, Math.NET) **or** source calls an anchored numeric function (`np.linalg`, `np.var`/`std`/`exp`/`prod`, `pvariance`, `stdev`, `logsumexp`, `softmax(`, `lstsq`, `variance(x)`). `numeric-stability-scan` grep G prints both counts. The old bare-word gate (`mean|norm|solve|float|double|Decimal…`) matched 30 % of a CRUD monorepo with no numeric code. Gate 0 → this pattern does not apply. Money is out of scope (§ Routed).

## The regimes

| Concern | Naive (wrong) | Stable (right) |
|---|---|---|
| Summation | `for x: total += x` over many terms | Kahan / pairwise; `math.fsum`, `np.sum` |
| Variance | two-pass `Σx² − (Σx)²/n` (cancellation) | Welford's online algorithm |
| Small arguments | `exp(x) − 1`, `log(1 + x)`, `1 − cos x` | `expm1`, `log1p`, `2·sin²(x/2)` |
| Over/underflow | product of many probabilities, `exp` unshifted | log-space (`logsumexp`, max-shifted softmax) |
| Linear solves | `inv(XᵀX) @ Xᵀy` | `lstsq` / QR / SVD, `cond` checked |
| Iteration | `while err > tol` | a max-iteration bound + relative tolerance |

Catastrophic cancellation (subtracting near-equal large numbers) and ill-conditioning (a high condition number means *no* algorithm recovers accuracy the input lacks) are the two failure engines. Tolerance choice in scientific code (absolute vs relative vs ULP) is a read question, never a float-`==` finding.

## Detectors — `numeric-stability-scan`

§1 naive accumulation · §2 cancellation · §3 overflow / log-space · §4 conditioning and unbounded iteration · §5 `-ffast-math`-class flags. Proof V608 / V609 (`proof-oracles.md` § Algorithms).

## Routed — owned elsewhere

- Float `==` / NaN → code-quality `correctness-smell-scan` §2; division by zero and integer overflow → §4.
- Money as float → code-quality `correctness-smell-scan` §4 (arithmetic), database `schema-integrity-scan` §4 (column), business `pricing-rule-scan` (policy) — each when its pack is installed.

## Closure verbs

`report-with-fix` · `report-flagged` (design call → ADR) · `dismiss` (precedent cited) · `route-code-quality` (float equality, division by zero, money arithmetic → `correctness-smell-scan` §2 / §4).

## Related

- `algorithm-principles.md` — the correctness/precision budget this makes concrete.
- `sublinear-structures.md` — the sibling gated pattern (approximation with *stated error*).
- `@algorithm-designer` — picks stable formulations during DESIGN when the gate is open.
