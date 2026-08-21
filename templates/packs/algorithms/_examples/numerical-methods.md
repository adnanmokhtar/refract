---
name: numerical-methods
kind: example
pack: algorithms
---

# Pattern: Numerical methods (precision, stability, conditioning)

> **Hard rule.** Numerical code MUST state the precision/stability regime it assumes. Floating-point comparisons use a **tolerance**, never `==`. Accumulation over many terms uses a **cancellation-safe** formula (Kahan / pairwise / Welford), not a naive running sum. Division near zero is **guarded**, and the problem's **condition number** is acknowledged when it can be large. A float `==`, a naive sum of many terms, or an unguarded divide by a near-zero value is a **numerical bug**, not a style nit — it produces wrong answers that look plausible.

## Gate — only when numeric/scientific signals are present

Signal-gated (like `sublinear-structures`). Apply only when the code does float / linear-algebra / scientific work:

```
numpy|scipy|blas|lapack|matrix|linalg|\bfloat\b|float64|float32|double|Decimal|BigDecimal|
mean|variance|stddev|covariance|dot product|norm|eigen|solve|integrate|simulation|Monte Carlo
```

No numeric signal → skip. Pure-integer, string, and business CRUD are out of scope (money is the exception — see below — and routes to the business pack).

## The regimes

| Concern | Naive (wrong) | Stable (right) |
|---|---|---|
| Equality | `a == b` on floats | `abs(a-b) <= eps` / rel / ULP; `math.isclose`, `np.isclose` |
| Summation | `for x: total += x` over many terms | Kahan / pairwise; `math.fsum`, `np.sum` |
| Variance | two-pass `Σx² − (Σx)²/n` (cancellation) | Welford's online algorithm |
| Near-zero divide | `a / b`, `b → 0` | guard `if abs(b) < eps` or reformulate |
| Over/underflow | product of many probabilities | work in log-space (`logsumexp`) |
| Exact decimal | money/tax as `float` | a decimal type (below) |

Catastrophic cancellation (subtracting near-equal large numbers) and ill-conditioning (a high condition number means *no* algorithm recovers accuracy the input lacks) are the two failure engines. Check `cond(A)` before trusting a solve; prefer a decomposition (LU/QR/SVD) over an explicit inverse.

## Money → decimal (hand off to business)

Use an exact decimal type (`decimal.Decimal`, `BigDecimal`, integer minor units) for money / tax / currency / billing — float tolerance does not save you (`0.1 + 0.2` is the wrong price). This crosses into the **business** pack (`pricing-tax-audit` owns the rounding policy). Do NOT use decimals for scientific math — floats with the discipline above are correct there.

## Detectors (cite-or-halt)

1. Float `==` / `!=` → tolerance / `isclose`.
2. Naive `+=` sum of many/mixed-magnitude floats → `fsum` / pairwise / Kahan.
3. Division by a derived denominator with no near-zero guard → guard or reformulate.
4. Variance/std via `Σx² − (Σx)²/n` → Welford or the library.
5. Money as float → decimal type; **hand off to business `pricing-tax-audit`**.

## Closure verbs

`report-with-fix` · `report-flagged` (design call → ADR) · `dismiss` (carve-out documented) · `handoff-pricing-tax` (money → business pack).

## Related

- `algorithm-principles.md` — the correctness/precision budget this makes concrete.
- `sublinear-structures.md` — the sibling gated pattern (approximation with *stated error*).
- `@algorithm-designer` — picks stable formulations during DESIGN when numeric signals are present.
- cross-pack `business` / `pricing-tax-audit` — owns money/tax exactness; detector 5 hands off here.
