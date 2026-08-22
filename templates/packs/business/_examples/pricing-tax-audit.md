---
name: pricing-tax-audit
description: Audits pricing / billing / tax / currency correctness. Money is an integer minor-unit or a decimal type, never a float; every price computation states its rounding + tax jurisdiction + currency; multi-currency values are never mixed. A float price, an unhandled proration, or a missing tax jurisdiction is a money bug.
---

# Skill: pricing-tax-audit

Money math is the one place where "looks right in the demo" and "correct" diverge silently, then reconcile into a support ticket and a refund. `0.1 + 0.2 == 0.30000000000000004`; a price rounded per-line then summed drifts a cent; a charge without a jurisdiction bills the wrong tax. This audits the money-MATH — not the billing UX.

## Premise

- **Money is an integer minor-unit (cents) or arbitrary-precision decimal — never a float.** A `float`/`double`/JS `number` holding a price is a bug on sight.
- **Every price computation states its rounding, tax jurisdiction, and currency.** A number with no currency is not money.
- **Multi-currency values are never mixed** — amount + currency travel together, convert at a defined rate/time.
- A float price, unhandled proration, missing jurisdiction, or mixed-currency sum is a **money bug**, not a style note.
- **Right shape is the floor; correct-at-the-edge is the bar.** A decimal type, a round-once step and a jurisdiction lookup are the *shape* of correct money math — necessary, not sufficient. The demo passes on `$19.99 × 1`; the cent leaks at the `.5` rounding boundary, the stacked discount, the full refund that leaves a stray cent, the second currency. `clean` is earned only when the arithmetic is **exercised at those edges and observed correct**.

## When to use

- Auditing billing / checkout / subscription / invoicing / metering code, or before a pricing / new-plan / new-currency launch.
- After a "charged the wrong amount" incident.
- Handed a money-as-float finding by `@domain-model-auditor`.

## When NOT to use

- Pure display formatting with no arithmetic (a `$` in a template) — cosmetic, out of scope.
- Non-financial numeric code (analytics counts, progress percentages) — no money invariant.

## Adapt to the money + tax stack (don't impose one)

Read what's used and audit against IT: money libs (dinero.js, py-moneyed, `decimal`, shopspring/decimal), tax engines (Stripe Tax, Avalara, TaxJar), billing platforms (Stripe, Chargebee, Recurly — they own proration; defer to them). Hand-rolled `price` column + arithmetic = highest-risk shape, all detectors live.

## Detectors (cite `<path:line>`, grade each)

- **Money as a float** (BLOCKER on sight) — `float|double|number` on `price|amount|total|balance`. A `DECIMAL` column read into a JS `number` is still a float bug.
- **Rounding per-line then summed** (drift) — round once at the documented step; confirm mode (banker's vs half-up) is deliberate. Undocumented rounding is a finding even if correct today.
- **Tax with no jurisdiction** — hardcoded rate = no nexus→jurisdiction→rate resolution; wrong outside one region. Verify tax on the *discounted* amount; inclusive vs exclusive explicit.
- **Multi-currency mixed** — `SUM(amount)` across currencies, amount stored without its currency code.
- **Proration not handled on plan change** — credit unused + charge pro-rated; defer to the platform if present.
- **Non-idempotent charge/metering** — charge/record_usage with no idempotency key double-charges on retry; ref `distributed-systems/ai-patterns/idempotency.md`.

## Edge-correctness probe (the gate — verified, not shape-checked)

The detectors find the wrong SHAPE. Passing them means the code *can* be correct, not that it *is*. Before `clean`, exercise each reachable property at its edge input and record the observed cents. A property the code cannot reach is `n-a (reason)`; one you could not exercise is `UNVERIFIED` — never a silent pass.

| # | Property (must HOLD) | Edge input that breaks a naive impl |
|---|---|---|
| P1 | Rounding mode is half-even at the `.5` boundary (or the jurisdiction's mandated mode, stated) | a value landing on a half-minor-unit, e.g. tax `2.125` → half-even `2.12`, half-up `2.13` |
| P2 | Sum-then-round == the booked total (round once) | 3 lines of `0.333` — Σ(rounded lines) drifts ≥1¢ from round-once |
| P3 | Tax base is the discounted amount; discount stacking is order-independent and non-negative | line + `%`-discount + fixed-discount + tax, in both orders |
| P4 | A full refund conserves to zero | charge X (with its rounding), refund in full — refund rounding MIRRORS the charge |
| P5 | Partial refunds never exceed the charge | charge X; refund X−1¢; then refund 2¢ → rejected / clamped |
| P6 | Multi-currency addition is refused without explicit FX | `10 USD + 10 EUR`; `SUM(amount)` across mixed rows |
| P7 | Proration credit + charge reconciles | mid-cycle upgrade at 50% elapsed; the fraction's rounding is stated |
| P8 | Zero / negative / max are handled, not assumed away | qty `0`; a credit; a line at decimal/`Int64` max |
| P9 | No invariant violation survives the pipeline | total ≥ 0; tax ≥ 0; `total == Σ lines + tax − discounts` to the cent; every persisted amount carries its currency |

**Evidence per reached property — no bare checkmarks.** `Probe:` you fed the edge input through the ACTUAL path (REPL / scratch invocation / hand-trace of the operators at `<path:line>`) — paste `input → observed → expected`. `Test:` a unit or property test already exercises this edge and passed — name `<file>::<test>`. `Traced:` the money type + round-once step make the property structurally impossible to violate — cite the type site AND the rounding site. `UNVERIFIED:` no way to exercise it — name the input that WOULD prove it; never fabricate the observed cent.

**Verdict rule.** All reached properties VERIFIED, zero fails, no BLOCKER detector → `clean`. ≥1 reached property UNVERIFIED/SKIPPED → `UNVERIFIED (N unproven)`, each unproven property named with the input that would settle it. Any property FAILS, or any BLOCKER detector hits → `money-bugs-present`.

## Output

```
## Pricing / tax audit — <scope> — <date>
Money stack: <lib/platform, or "hand-rolled">
Verdict: clean | UNVERIFIED (N unproven) | money-bugs-present

### 🔴 Money bugs (charge-affecting)
- [float-money] <path:line> — drifts on arithmetic — Fix: integer cents / decimal
- [tax-no-jurisdiction] <path:line> — hardcoded rate — Fix: resolve via nexus
### 🟡 Correctness risks — rounding-drift · proration-missing · non-idempotent-charge

### Money-math property register (REQUIRED; every reached row carries Evidence or UNVERIFIED)
| # | Property | Edge input | Expected | Observed | Evidence |
|---|---|---|---|---|---|
| P1 | half-even at .5 | tax 2.125 @ money.py:34 | 2.12 | 2.12 | Probe: REPL round_half_even(2.125)→2.12 |
| P4 | full refund → 0 remainder | charge 999, refund all | Σ=999, rem 0 | — | UNVERIFIED — no refund harness; input: charge 4.995 then full refund |
| P6 | mixed-currency refused | 10 USD + 10 EUR | throws | throws | Traced: Money.add @ money.py:12 asserts .currency |
```

## Halt

- Refuse to label a value "money" without its currency companion; refuse to pass a tax that resolves to a hardcoded rate; refuse to APPROVE any scope with a float money value (BLOCKER).
- **Refuse to print `clean` while any reached property in the register is UNVERIFIED** — the honest verdict is `UNVERIFIED (N unproven)`. A shape audit that never touched the `.5` boundary, the full refund, or the second currency has not proven correctness; do not launder it into `clean`.
- **Refuse a bare checkmark in the property register** — every reached row is `Probe:` / `Test:` / `Traced:` / `UNVERIFIED`. A fabricated observed cent is worse than an honest UNVERIFIED.
- Don't re-implement the platform's proration in your fix — point to its API.

## Related

- `@business-auditor` audits billing as a UX checklist (invoices downloadable, dunning exists); **this owns the money-MATH**. Run both on a billing feature.
- `@domain-model-auditor` routes its money-as-float / value-object findings here.
