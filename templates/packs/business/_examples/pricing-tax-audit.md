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

## Output

```
## Pricing / tax audit — <scope> — <date>
Money stack: <lib/platform, or "hand-rolled">
Verdict: clean | money-bugs-present

### 🔴 Money bugs (charge-affecting)
- [float-money] <path:line> — drifts on arithmetic — Fix: integer cents / decimal
- [tax-no-jurisdiction] <path:line> — hardcoded rate — Fix: resolve via nexus
### 🟡 Correctness risks — rounding-drift · proration-missing · non-idempotent-charge
```

## Halt

- Refuse to label a value "money" without its currency companion; refuse to pass a tax that resolves to a hardcoded rate; refuse to APPROVE any scope with a float money value (BLOCKER).
- Don't re-implement the platform's proration in your fix — point to its API.

## Related

- `@business-auditor` audits billing as a UX checklist (invoices downloadable, dunning exists); **this owns the money-MATH**. Run both on a billing feature.
- `@domain-model-auditor` routes its money-as-float / value-object findings here.
