---
name: numerical-methods
kind: ai-pattern
pack: algorithms
---

# Pattern: Numerical methods (precision, stability, conditioning)

> **Hard rule.** Numerical code MUST state the precision/stability regime it assumes. Floating-point comparisons use a **tolerance**, never `==`. Accumulation over many terms uses a **cancellation-safe** formula (Kahan / pairwise / Welford), not a naive running sum. Division near zero is **guarded**, and the problem's **condition number** is acknowledged when it can be large. A float `==`, a naive sum of many terms, or an unguarded divide by a near-zero value is a **numerical bug**, not a style nit — it produces wrong answers that look plausible.

## Gate — only relevant when numeric/scientific signals are present

This pattern is signal-gated (like `sublinear-structures`). Apply it only when the code actually does floating-point / linear-algebra / scientific work. Gate on:

```
numpy|scipy|blas|lapack|matrix|linalg|\bfloat\b|float64|float32|double|Decimal|BigDecimal|
mean|variance|stddev|covariance|dot\s*product|norm|eigen|solve|integrate|simulation|Monte\s*Carlo
```

No numeric signal → skip; this is not a general "use more precision everywhere" rule. Pure-integer code, string handling, and business CRUD are out of scope (money is the one exception — see the decimal section — and it routes to the business pack).

## Why float lies

A `float`/`double` is a binary approximation: `0.1 + 0.2 != 0.3`, `0.1` has no exact binary form, and results carry a rounding error of ~**machine epsilon** (`≈ 2.22e-16` for float64, `≈ 1.19e-07` for float32) per operation. Errors **accumulate** over many operations and **amplify** when the problem is ill-conditioned. Every rule below follows from this.

## The regimes

| Concern | Naive (wrong) | Stable (right) |
|---|---|---|
| **Equality** | `a == b` on floats | `abs(a - b) <= eps` (absolute), or relative/ULP compare; `math.isclose` / `np.isclose` |
| **Summation** | `for x: total += x` over many terms | Kahan (compensated) or pairwise summation; `math.fsum` / `np.sum` (pairwise) |
| **Variance / std** | two-pass `Σx² − (Σx)²/n` (catastrophic cancellation) | Welford's online algorithm (one pass, stable) |
| **Near-zero divide** | `a / b` with `b → 0` | guard `if abs(b) < eps: handle`; or reformulate to avoid the divide |
| **Quadratic roots** | `(-b ± sqrt(b²−4ac)) / 2a` | cancellation-avoiding form (compute the stable root, then `x1·x2 = c/a`) |
| **Over/underflow** | `exp`/product of many probabilities | work in **log-space** (`logsumexp`, sum of logs) |
| **Exact decimal** | money/tax as `float` | a **decimal** type (see below) |

### Tolerance, not `==`

`abs(a - b) <= eps` is an **absolute** tolerance — correct near 0 but wrong for large magnitudes (where one ULP already exceeds a fixed `eps`). A **relative** tolerance `abs(a-b) <= eps * max(abs(a), abs(b))` scales with magnitude; a **ULP** compare counts representable steps between the two. Use the library primitive where it exists (`math.isclose(a, b, rel_tol=, abs_tol=)`, `numpy.isclose`, `numpy.allclose`) — it combines both. State the tolerance; a bare `< 1e-9` with no rationale is a magic number.

### Catastrophic cancellation

Subtracting two nearly-equal large numbers annihilates the significant digits and leaves noise. It appears in: the naive two-pass variance formula, `1 - cos(x)` for small `x`, the standard quadratic formula when `b² ≫ 4ac`, and any long running sum where small terms are lost against a large partial. Fixes: **Kahan/compensated summation** (carry the lost low-order bits), **pairwise summation** (tree-reduce to bound error growth), **Welford** for variance, and **algebraically reformulated** expressions that never form the near-equal difference.

### Condition number / ill-conditioning

The condition number measures how much the output can change per unit change in the input. A high condition number (an ill-conditioned matrix, a nearly-singular system, a nearly-tangent intersection) means **no algorithm** can recover accuracy the input doesn't contain — a stable algorithm merely avoids *adding* error. Acknowledge it: solving `Ax=b` for a matrix with condition number `1e12` in float64 (~16 digits) leaves ~4 significant digits; check `cond(A)` (`numpy.linalg.cond`) before trusting the solve, prefer a solver/decomposition (LU with pivoting, QR, SVD) over inverting, and never compute an explicit matrix inverse to then multiply.

### Overflow / underflow → log-space

Products of many small probabilities underflow to `0`; `exp` of a large argument overflows to `inf`. Work in **log-space**: sum logs instead of multiplying, and use the `logsumexp` trick (subtract the max before `exp`) for normalizing. Standard in likelihoods, softmax, and long Markov chains.

## When to reach for a decimal type instead of float

Use an exact **decimal** type (`decimal.Decimal`, `BigDecimal`, a fixed-point integer of minor units) when the domain is **exact base-10** and rounding must be deterministic and auditable — **money, tax, currency, billing, financial reporting**. Float `==`/tolerance discipline does not save you here: `0.1 + 0.2` is simply the wrong answer for a price. This crosses into the **business** pack — money-as-float is that pack's bug, not a numerical-stability tuning knob. Do NOT use decimals for scientific/simulation math (they're slow and don't help conditioning) — floats with the discipline above are correct there.

## Adapt (per stack)

- **Python**: `math.isclose` / `math.fsum`, `numpy.isclose`/`allclose`/`linalg.cond`, `scipy.special.logsumexp`, `decimal.Decimal` for money, `statistics` (Welford-based) or `numpy.var`.
- **NumPy/BLAS/LAPACK**: prefer vectorized reductions (`np.sum` is pairwise; `np.dot` calls BLAS), `linalg.solve`/`lstsq`/`svd` over `linalg.inv`, watch `float32` vs `float64` accumulation in GPU/ML code.
- **JS**: no float64 escape for money → integer minor units or a decimal lib; `Number.EPSILON` for tolerance.
- **Java/C#**: `BigDecimal`/`decimal` for money; `Math.ulp` for ULP compares.
- **C/C++/Fortran**: BLAS/LAPACK directly; `-ffast-math` silently breaks these guarantees — flag it.

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix. Only fire when the gate signals are present.

### 1. Float `==` / `!=` comparison
```
BAD:   if (a == b)            // a, b are floats
GOOD:  if (math.isclose(a, b, rel_tol=1e-9, abs_tol=0.0))
```
Flag `==`/`!=` where either operand is a float/double (including `x == 0.0`, loop `while t != 1.0`). Fix: tolerance or the library `isclose`. Carve-out: comparing against a value that is *exactly* representable and intentionally so (`x == 0.0` as a sentinel you set yourself) — document it.

### 2. Naive sum of many floats (cancellation risk)
```
BAD:   total = 0.0; for x in xs: total += x        // xs large / mixed magnitudes
GOOD:  total = math.fsum(xs)   # or np.sum / Kahan
```
Flag a running `+=` accumulation over a large or mixed-magnitude float sequence. Fix: `fsum` / pairwise / Kahan.

### 3. Division with no near-zero guard
```
BAD:   result = numerator / denom          // denom can approach 0
GOOD:  if abs(denom) < eps: <handle>; else: result = numerator / denom
```
Flag a float division whose denominator is derived (a difference, a dot product, a determinant, a count that can be 0) with no guard. Fix: guard, or reformulate to remove the divide.

### 4. Variance/std via the naive two-pass / sum-of-squares formula
```
BAD:   var = (sumsq - sum*sum/n) / n        // catastrophic cancellation
GOOD:  Welford's online algorithm  (or np.var / statistics.pvariance)
```
Flag `Σx² − (Σx)²/n`-shaped variance/covariance/stddev. Fix: Welford or the library.

### 5. Money as float (→ business pricing-tax)
```
BAD:   price = 19.99  (float);  total = price * qty * (1 + taxRate)
GOOD:  Decimal("19.99") / integer minor units, banker's/half-up rounding stated
```
Flag currency/price/tax/total held or computed in float/double. Fix: decimal type. **Route to the business pack `pricing-tax-audit`** — this detector *hands off*; the rounding-policy + tax-rounding rules live there.

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete stable formula / tolerance / type.
- `report-flagged` — the fix is a design call (which tolerance regime? is this matrix conditioning acceptable? decimal vs scaled-int?) → surface for ADR.
- `dismiss` — carve-out applies (integer-only math; an intentionally exact sentinel compare; a small well-conditioned problem) → documented.
- `handoff-pricing-tax` — money-as-float; the fix belongs to the business pack (detector 5).

## Related

- `algorithm-principles.md` — the correctness/precision budget this pattern makes concrete for float math.
- `complexity-derivation.md` — pairing accuracy with the cost of the stable variant (Kahan/pairwise carry a constant-factor cost).
- `sublinear-structures.md` — the sibling gated pattern (approximation with *stated error*); numerical error is the deterministic-arithmetic analog.
- `@algorithm-designer` — picks stable formulations during DESIGN when numeric signals are present.
- cross-pack `business` / `pricing-tax-audit` — owns money/tax exactness; detector 5 hands off here.
