---
description: Audits pricing / billing / tax / currency correctness. Money is an integer minor-unit or a decimal type, never a float; every price computation states its rounding + tax jurisdiction + currency; multi-currency values are never mixed. A float price, an unhandled proration, or a missing tax jurisdiction is a money bug.
---

# Skill: pricing-tax-audit

Money math is the one place where "looks right in the demo" and "correct" diverge silently, then reconcile into a support ticket and a refund. `0.1 + 0.2 == 0.30000000000000004`; a price rounded per-line then summed drifts a cent from a price summed then rounded; a charge without a jurisdiction bills the wrong tax; a plan change without proration bills a full cycle twice. This skill audits the money-math correctness — not the billing UX.

## Premise

- **Money is an integer minor-unit (cents) or an arbitrary-precision decimal — never a float.** A `float`/`double`/JS `number` holding a price is a bug on sight, before any other analysis. Floating-point cannot represent `0.10`; every arithmetic op accrues error that surfaces as a mis-charge.
- **Every price computation states its rounding, its tax jurisdiction, and its currency.** A number with no currency is not money. A rounding with no documented step is a drift waiting to happen. A tax with no jurisdiction is a guess.
- **Multi-currency values are never mixed.** Adding `10 USD + 10 EUR` without an explicit conversion at a defined rate/time is a bug; amount and currency travel together or not at all.
- A float price, an unhandled proration, a missing tax jurisdiction, or a mixed-currency sum is a **money bug** — grade it as a defect, not a style note.

## When to use

- Auditing billing / checkout / subscription / invoicing / metering code.
- Before shipping a pricing change, a new plan tier, a proration path, or a new-currency / new-region launch.
- After a "customer charged the wrong amount" incident — reconstruct where the cent leaked.
- Handed a money-as-float finding by `@domain-model-auditor` (the value-object-as-primitive detector routes here).

## When NOT to use

- Pure display formatting with no arithmetic (a `$` in a template) — cosmetic, out of scope.
- Non-financial numeric code (analytics counts, progress percentages) — no money invariant.

## Adapt to the project's money + tax stack (do not impose one)

Read what the project already uses and audit against IT:

- **Money libraries** — dinero.js / money.js (JS), Java Money (JSR-354 / Moneta), Python `decimal` / py-moneyed, Ruby `Money` gem, Go `shopspring/decimal`, .NET `decimal`. Presence of one of these is a good sign; verify it's used at every arithmetic site, not just at the boundary.
- **Tax engines** — Stripe Tax, Avalara (AvaTax), TaxJar, Vertex. If one is wired, verify jurisdiction resolution actually calls it (address → tax code → rate), not a hardcoded rate.
- **Billing platforms** — Stripe Billing, Chargebee, Recurly, Paddle. These own proration + dunning; verify the app defers to the platform's proration rather than re-implementing it (and mis-implementing it).
- If the project rolled its own (a bare `price` column + hand arithmetic), the detectors below are all live — this is the highest-risk shape.

## Detectors (run these, cite `<path:line>`, grade each)

### Money as a float (BLOCKER on sight)
```
rg -n "float|double|Number|number).*(price|amount|total|cost|fee|balance)" src
rg -n "(price|amount|total|balance).*:\s*(float|number|double|real)" src migrations/
```
A `price DECIMAL` in the DB read into a JS `number` and mutated is still a float bug at the arithmetic site. The 0.1+0.2 hazard: any `+`, `*`, `/` on a float money value drifts. **Fix:** integer minor-units or a decimal type end-to-end.

### Rounding applied per-line then summed (drift)
```
rg -n "round|Math.round|toFixed|ceil|floor|Round\(" src
```
Rounding each line item then summing gives a different total than summing then rounding — the classic off-by-a-cent on multi-line invoices. **Round once, at the documented step.** Also confirm the rounding MODE is chosen deliberately: banker's rounding (round-half-to-even) vs half-up — tax authorities often mandate one. An undocumented rounding step is a finding even if it happens to be correct today.

### Tax with no jurisdiction
```
rg -n "tax|vat|gst|sales_tax" src | rg -v "jurisdiction|region|country|address|nexus|rate_for"
rg -n "0\.\d+.*tax|tax.*0\.\d+|TAX_RATE\s*=" src   # hardcoded rate = no jurisdiction resolution
```
A tax computed from a constant rate has no jurisdiction resolution — wrong for every customer outside that one region. Verify: address/nexus → jurisdiction → rate. Verify inclusive vs exclusive is explicit (VAT is usually tax-inclusive display, US sales tax exclusive). Verify **tax on the discounted amount**, not the pre-discount amount (a common over-charge).

### Multi-currency mixed without conversion
```
rg -n "amount|price|total|balance" src | rg -n "\+|sum|reduce|\.add\("   # additions of money
```
For each money addition/sum, confirm both operands are the same currency (or an explicit FX conversion happens first, at a defined rate and timestamp). An amount stored without its currency code, or a `SUM(amount)` across rows of differing currency, is a bug. **Store currency alongside every amount; convert at a defined rate/time, never implicitly.**

### Proration not handled on plan change
```
rg -n "upgrade|downgrade|change_plan|switch_plan|update.*subscription" src
```
A mid-cycle plan change must prorate: credit the unused portion of the old plan, charge the pro-rated new plan. Absent proration → the customer is double-billed or gets a free window. If a billing platform (Stripe/Chargebee) is present, verify the app uses ITS proration; if hand-rolled, verify credit + charge + the rounding of the pro-rated fraction.

### Non-idempotent metering / double-charge
```
rg -n "charge|capture|createPaymentIntent|record_usage|meter|increment.*usage" src
```
A metering or charge call with no idempotency key can double-charge on retry / webhook redelivery / double-click. Verify each charge and each usage record carries an idempotency key and the write is idempotent. Cross-references `distributed-systems/ai-patterns/idempotency.md`. Also verify **dunning**: a failed charge has a retry/dunning path (not a silently dropped invoice).

## Output

```
## Pricing / tax audit — <scope> — <date>
Money stack: <library / platform detected, or "hand-rolled">
Verdict: clean | money-bugs-present

### 🔴 Money bugs (charge-affecting)
- [float-money] <path:line> — <amount as float> — drifts on arithmetic — Fix: <integer cents / decimal>
- [tax-no-jurisdiction] <path:line> — hardcoded rate — wrong outside <region> — Fix: <resolve via nexus>
- [mixed-currency] <path:line> — SUM across currencies — Fix: <convert first / group by currency>

### 🟡 Correctness risks
- [rounding-drift] <path:line> — per-line round then sum — Fix: round once at <step>; mode <banker's/half-up>
- [proration-missing] <path:line> — plan change with no credit/charge split
- [non-idempotent-charge] <path:line> — no idempotency key — double-charge on retry

### 🔵 Documentation gaps
- [undocumented-rounding] <path:line> — mode not stated (currently correct, fragile)

### Money-math register
| Computation | Currency handling | Rounding (step · mode) | Tax (jurisdiction · incl/excl) |
|---|---|---|---|
| checkout total @ path:line | single, USD | once at total · half-up | Stripe Tax · exclusive |
| invoice line @ path:line | ⚠ float | ⚠ per-line | ⚠ hardcoded 0.20 |
```

## Gotchas

- **A `DECIMAL` column read into a `float` variable** is still a float bug — the DB type doesn't save you if the language widens it on read.
- **Tax on pre-discount amount** over-charges; tax base is the discounted line.
- **Inclusive vs exclusive flipped** silently double-applies or drops tax — always state which the price is.
- **FX rate captured at display time but charged at settle time** — the two can differ; pin the rate and store it with the transaction.
- **Refund rounding** must mirror the original charge's rounding, or a full refund leaves a stray cent.
- **Metering "at least once" delivery** without idempotency double-counts usage → over-bills.

## Halt

- Refuse to label a value "money" without finding its currency companion — a bare amount is the finding.
- Refuse to pass a tax computation that resolves to a hardcoded rate — name it a jurisdiction gap.
- Refuse to APPROVE any scope containing a float money value — that is a BLOCKER regardless of the rest.
- Do not re-implement the project's billing platform's proration in your fix suggestion — point back to the platform's proration API.

## Boundary + related

- **`@business-auditor`** audits billing as a UX checklist — invoices downloadable, upgrade/downgrade reachable, dunning flow exists, refunds possible without engineering. It checks that the money *features* are present. **This skill owns the money-MATH correctness** — is the arithmetic itself right (representation, rounding, tax base, currency, idempotency). Run both on a billing feature: business-auditor for the flow, this for the numbers.
- **`@domain-model-auditor`** — routes its money-as-float / value-object-as-primitive findings here; the missing `Money` value object is where the integer-minor-unit invariant should live.
- **`distributed-systems/ai-patterns/idempotency.md`** — the idempotent-charge / idempotent-metering primitive this skill's double-charge detector relies on.
- **`database/ai-patterns/data-retention-pii.md`** — financial records have retention obligations (tax/audit multi-year); coordinate the money model with the retention policy.
