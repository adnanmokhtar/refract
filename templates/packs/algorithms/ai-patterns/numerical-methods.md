---
name: numerical-methods
kind: ai-pattern
pack: algorithms
---

# Pattern: Numerical methods (precision, stability, conditioning)

> **Hard rule.** Numerical code MUST state the precision/stability regime it assumes. Accumulation over many terms uses a **cancellation-safe** formula (Kahan / pairwise / Welford), not a naive running sum; products that can underflow and exponentials that can overflow work in **log-space**; the problem's **condition number** is acknowledged when it can be large, and a solve never goes through an explicit inverse. A naive sum of many terms, a sum-of-squares variance or an unconditioned solve in shipped numeric code is a **numerical bug**, not a style nit — it produces wrong answers that look plausible.

## Gate — only numeric code

This pattern is gated, and the gate is printed. Apply it only when the repo holds numeric code:

- **A numeric library in a manifest:** `numpy`, `scipy`, `pandas`, `polars`, `statsmodels`, `scikit-learn`, `torch`, `jax`, `numba`, `mpmath`, `mathjs`, `simple-statistics`, `ml-matrix`, `@tensorflow/tfjs`, `gonum`, Apache Commons Math, `ndarray`, `nalgebra`, `statrs`, Math.NET Numerics; **or**
- **An anchored numeric call in source:** `np.linalg`, `np.var` / `std` / `cov` / `exp` / `log` / `prod`, `pvariance`, `pstdev`, `stdev`, `logsumexp`, `log_softmax`, `softmax(`, `cholesky`, `lstsq`, `variance(x)` / `stddev(x)` / `covariance(x)` called as functions.

`numeric-stability-scan` grep G runs both and prints their counts. The earlier gate — bare words such as `mean`, `norm`, `solve`, `float`, `double`, `Decimal` — matched 3,574 of 11,875 files of a real CRUD monorepo with no numeric code, and 20 of 24 benchmark fixtures; it never gated. With the gate at 0 this pattern does not apply, and the detectors print `N/A (no numeric code: gate 0)`. Pure-integer code, string handling, business CRUD and **money** are out of scope (§ Routed).

## Why float lies

A `float`/`double` is a binary approximation: `0.1 + 0.2 != 0.3`, `0.1` has no exact binary form, and results carry a rounding error of ~**machine epsilon** (`≈ 2.22e-16` for float64, `≈ 1.19e-07` for float32) per operation. Errors **accumulate** over many operations and **amplify** when the problem is ill-conditioned. Every rule below follows from this.

## The regimes

| Concern | Naive (wrong) | Stable (right) |
|---|---|---|
| **Summation** | `for x: total += x` over many terms | Kahan (compensated) or pairwise summation; `math.fsum` / `np.sum` (pairwise) |
| **Variance / std** | two-pass `Σx² − (Σx)²/n` (catastrophic cancellation) | Welford's online algorithm (one pass, stable) |
| **Small-argument forms** | `exp(x) − 1`, `log(1 + x)`, `1 − cos x` | `expm1`, `log1p`, `2·sin²(x/2)` |
| **Quadratic roots** | `(-b ± sqrt(b²−4ac)) / 2a` | cancellation-avoiding form (compute the stable root, then `x1·x2 = c/a`) |
| **Over/underflow** | `exp`/product of many probabilities | work in **log-space** (`logsumexp`, sum of logs, max-shifted softmax) |
| **Linear solves** | `inv(XᵀX) @ Xᵀy` | `lstsq` / QR / SVD with `cond` checked |
| **Iteration** | `while err > tol` | a max-iteration bound and a relative + absolute tolerance |

### Choosing a tolerance in scientific code

`abs(a - b) <= eps` is an **absolute** tolerance — correct near 0 but wrong for large magnitudes (where one ULP already exceeds a fixed `eps`). A **relative** tolerance `abs(a-b) <= eps * max(abs(a), abs(b))` scales with magnitude; a **ULP** compare counts representable steps between the two. Use the library primitive where it exists (`math.isclose(a, b, rel_tol=, abs_tol=)`, `numpy.isclose`, `numpy.allclose`). This choice is a read question inside `numeric-stability-scan` §1; a bare float `==` is code-quality's finding, not this pattern's (§ Routed).

### Catastrophic cancellation

Subtracting two nearly-equal large numbers annihilates the significant digits and leaves noise. It appears in: the naive two-pass variance formula, `1 - cos(x)` for small `x`, the standard quadratic formula when `b² ≫ 4ac`, and any long running sum where small terms are lost against a large partial. Fixes: **Kahan/compensated summation**, **pairwise summation**, **Welford** for variance, and **algebraically reformulated** expressions that never form the near-equal difference.

### Condition number / ill-conditioning

The condition number measures how much the output can change per unit change in the input. A high condition number (an ill-conditioned matrix, a nearly-singular system, a nearly-tangent intersection) means **no algorithm** can recover accuracy the input doesn't contain — a stable algorithm merely avoids *adding* error. Acknowledge it: solving `Ax=b` for a matrix with condition number `1e12` in float64 (~16 digits) leaves ~4 significant digits; check `cond(A)` (`numpy.linalg.cond`) before trusting the solve, prefer a solver/decomposition (LU with pivoting, QR, SVD) over inverting, and never compute an explicit matrix inverse to then multiply.

### Overflow / underflow → log-space

Products of many small probabilities underflow to `0`; `exp` of a large argument overflows to `inf`. Work in **log-space**: sum logs instead of multiplying, and use the `logsumexp` trick (subtract the max before `exp`) for normalizing. Standard in likelihoods, softmax, and long Markov chains.

### Build flags

`-ffast-math`, `-Ofast`, `numba.jit(fastmath=True)` and `/fp:fast` let the compiler reassociate sums and assume no NaN or Inf — NaN checks fold away and summation order changes. Keep them off numeric code that checks NaN or depends on order.

## Adapt (per stack)

- **Python**: `math.fsum`, `numpy.linalg.cond` / `lstsq`, `scipy.special.logsumexp`, `statistics.pvariance` / `fmean`, `numpy.var`, `np.expm1` / `np.log1p`.
- **NumPy/BLAS/LAPACK**: prefer vectorized reductions (`np.sum` is pairwise; `np.dot` calls BLAS), `linalg.solve`/`lstsq`/`svd` over `linalg.inv`, watch `float32` vs `float64` accumulation in GPU/ML code.
- **JS**: `Math.expm1` / `Math.log1p`; a compensated sum for long series; `Number.EPSILON` is relative to 1, not an absolute tolerance for large values.
- **Java/C#**: `Math.ulp` for ULP compares; Commons Math / Math.NET decompositions over inverses.
- **C/C++/Fortran**: BLAS/LAPACK directly; no `-ffast-math` on code that checks NaN or sums.

## Detectors — run by `numeric-stability-scan`

The runnable detectors (pre-flight greps, lanes, the gate, the 3,000-hit path, coverage block, halts) live in `skills/numeric-stability-scan/SKILL.md`; each finding cites `<file:line>` + the data's regime + the consumer's tolerance + the fix, proved by V608 / V609 in `proof-oracles.md` § Algorithms.

| This pattern's concern | Detector § | Proof |
|---|---|---|
| Naive sum of many or mixed-magnitude floats; float32 accumulators | `numeric-stability-scan` §1 | V608 |
| Two-pass / sum-of-squares variance; `1 − cos x`; `exp(x) − 1`; `log(1 + x)`; the textbook quadratic | §2 | V608 |
| Products and `exp` without log-space or a max shift | §3 | V608 |
| Explicit inverse, normal equations, no `cond`, unbounded iteration | §4 | V608 |
| `-ffast-math`-class flags | §5 | V609 |

## Routed — owned elsewhere (cite, never grade here)

- **Float `==` / `!=`, NaN compares, `-0`** → code-quality `correctness-smell-scan` §2 (its lane table runs clippy `float_cmp`, RuboCop `Lint/FloatComparison`, ESLint `use-isnan`, Ruff `PLW0177`), when the code-quality pack is installed.
- **Division by zero, integer overflow, truncating division** → code-quality `correctness-smell-scan` §4.
- **Money as float** — arithmetic in code → code-quality `correctness-smell-scan` §4; a float money column → database `schema-integrity-scan` §4; rounding and allocation policy → business `pricing-rule-scan` §1–§2 (each when its pack is installed). Use an exact decimal or integer minor units there; never decimals for scientific or simulation math (they are slow and do not help conditioning).
- Without the owning pack, the row is listed as `<class> (owner pack <x> not installed)` and never graded here.

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete stable formula, reduction or solver.
- `report-flagged` — the fix is a design call (which tolerance regime? is this conditioning acceptable?) → surface for ADR.
- `dismiss` — a precedent applies (`precedents/algorithms.md` § 36–§ 38: a pairwise library reduction, integer minor units, float32 inference with a stated tolerance) → documented.
- `route-code-quality` — float equality, division by zero or money arithmetic → `correctness-smell-scan` §2 / §4 (the money column → database `schema-integrity-scan` §4); cited, not graded here.

## Related

- `algorithm-principles.md` — the correctness/precision budget this pattern makes concrete for float math.
- `skills/numeric-stability-scan` — the detectors; `skills/complexity-derivation` — pairing accuracy with the cost of the stable variant (Kahan/pairwise carry a constant-factor cost).
- `sublinear-structures.md` — the sibling gated pattern (approximation with *stated error*).
- `@algorithm-designer` — picks stable formulations during DESIGN when the gate is open.
