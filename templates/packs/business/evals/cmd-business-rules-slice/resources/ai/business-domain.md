# Fernhollow — business domain policies

Owner: finance engineering. Last reviewed 2026-09-30.

## Money policy (ADR-0004)

| Amount kind | Representation | Rounding mode | Rounding point | Exponent source |
|---|---|---|---|---|
| order line, discount allocation | integer minor units | half away from zero | once, at the line | `apps/api/src/money/currency.ts` |
| commission, platform fee | integer minor units | half away from zero | once, per order | the same table |
| tax | integer minor units | half away from zero | per line (see Tax) | the same table |
| refund | integer minor units, the paid share of the line | — (copied, never recomputed) | — | — |
| FX conversion | rate decimal(18,8), stored on the order with its time and source | half away from zero | once, at checkout | — |

The API rounds through `apps/api/src/money/money-policy.ts` (`roundHalfAwayFromZero`); the back office
through `services/backoffice/money/policy.py` (`ROUND_HALF_UP`, which in Python's `decimal` rounds ties
away from zero). Currencies accepted: USD, EUR, SAR, EGP, KWD (three minor digits). Back-office invoices
are issued in EUR or USD only (two minor digits), so their `DecimalField(decimal_places=2)` columns are
exact for every invoice currency.

Discounts: item-level promotions first, then at most one order-level coupon; promotions are
`stackable: false` unless flagged; a total never goes below zero. Free shipping and loyalty tiers are
judged on the merchandise subtotal **after** discounts. Fixed-amount coupons and gift cards carry a
currency and apply only to orders in that currency.

Refunds return at most the paid share of a line (its price minus its allocated discount), across all
refund paths (card, wallet, store credit) together.

## Tax policy

| Field | Value |
|---|---|
| Jurisdictions | EU sellers (DE first) issue EN 16931 invoices; KSA stores issue simplified receipts from the POS |
| Rates | `tax_rates` table with `valid_from` / `valid_to`; resolved at the tax point and copied to each line |
| Inclusive / exclusive | per store: `stores.prices_include_tax` (default false — prices are exclusive) |
| Rounding level | per line, document totals summed from the rounded lines the document lists |
| Tax point | the issue date, stamped once at issue in the store's zone |
| E-invoice | Peppol BIS Billing 3.0 (back office), UBL for API-issued invoices; ZATCA simplified receipts (POS) |

POS (KSA only, SAR only): 15 % standard rate, effective-dated in `apps/api/src/pos/pos-tax.ts`
and copied to every receipt line.

## Metric definitions

| Metric | Definition | Recognised at | Filters | Zone |
|---|---|---|---|---|
| revenue | net merchandise: line totals minus discounts, excluding tax and shipping, minus refunds | `paid_at` | not cancelled, not test (`livemode`) | store zone |
| gross_sales / net_sales | two named metrics: before / after discounts | `paid_at` | as revenue | store zone |
| gmv | gross order value, per currency | `paid_at` | as revenue | store zone |
| refund_rate | refunded amount ÷ revenue | `refunded_at` | as revenue | store zone |
| delivery_rate | delivered ÷ shipped (decimal) | `delivered_at` | — | store zone |
| aov | revenue ÷ paid orders, weighted | `paid_at` | as revenue | store zone |

A merchant statement is reconciled against the ledger's merchant-payable account before payout.

## Business time

Each store has a zone (`stores.timezone`); a business day, a cutoff, a coupon's last day and a billing
day are in the store's zone. Internal operations charts are in UTC and say so on the axis.
Settlement business days follow the settlement bank's calendar (Egypt: Friday–Saturday weekend).

## Records of fact

Orders, invoices, credit notes and ledger rows are kept for 10 years (§ 147 AO for DE books; the
longest period of the jurisdictions served). Erasure requests pseudonymise the customer and keep the
records of fact (GDPR Art. 17(3)(b)).
