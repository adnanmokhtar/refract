# Marketplace — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `marketplace`:

**Entity / model names**: `Seller`, `Vendor`, `Merchant`, `Store` (per-seller), `SellerProduct`, `Listing`, `Suborder`, `OrderSplit`, `Commission`, `Payout`, `Wallet` (seller-scoped), `Disbursement`, `Dispute`, `KYC`, `Verification`, `BankAccount`, `OnboardingStep`, `CommissionRule`, `PayoutSchedule`, `Reserve`.

**Folder / route names**: `seller/`, `vendor/`, `merchant/`, `dashboard/seller/`, `onboarding/`, `payouts/`, `commissions/`, `/seller/[slug]`, `/sellers/apply`, `/admin/sellers/pending`.

**Dependencies**: `stripe-connect`, `paypal-payouts`, `adyen-marketpay`, `mangopay`, `hyperwallet`, `dwolla`, `tipalti`, `tax-jar` + `marketplace-facilitator`, `persona` / `onfido` / `sumsub` / `veriff` (KYC).

**Database schema**: `sellers` + `seller_products` + `commissions` + `payouts` is the strongest signal. The presence of `parent_order_id` or `seller_order_id` in an `orders` table also signals split orders.

**Distinguishing from ecommerce**: ecommerce = single operator selling. Marketplace = operator hosts many independent sellers, splits each order, takes a commission, pays sellers on a schedule. The line: if `orders.seller_id` exists, it's a marketplace.

**Distinguishing from logistics/3PL**: 3PL = operator owns inventory across warehouses. Marketplace = sellers own inventory; operator does not take title.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Seller` / `Vendor` | the merchant onboarded to sell | `id, legal_name, display_name, status, kyc_status, default_currency, country, payout_method_id, commission_rule_id, joined_at` | applied → in_review → approved → active → suspended → terminated |
| `KYCVerification` | identity + business verification | `seller_id, provider (Persona/Onfido/SumSub), level (basic/enhanced), status, documents[], decision_at, expires_at` | submitted → in_review → approved / rejected / requires_more_info |
| `Listing` / `SellerProduct` | one seller's offer | `id, seller_id, product_id?, sku, price, stock, status, approval_status, moderation_notes` | draft → pending_review → approved → active → suspended → archived |
| `Order` | the buyer-facing umbrella | `id, buyer_id, total, currency, status, placed_at` — buyer paid ONCE | placed → split → fulfilled (when all suborders fulfilled) → completed |
| `Suborder` / `SellerOrder` | per-seller slice of an order | `id, parent_order_id, seller_id, subtotal, commission_amount, payout_amount, status, fulfillment_state` | created → accepted → fulfilled → released_for_payout (or cancelled / disputed) |
| `Commission` | operator's cut on a suborder | `id, suborder_id, rule_id, base_amount, rate, fixed_fee, total, currency` | computed at suborder placement; immutable |
| `CommissionRule` | how commission is computed | `id, seller_id?, category_id?, rate (%), fixed_fee, min_fee, applies_to (gross/net)` | versioned; rules in effect at order time apply |
| `Wallet` / `Ledger` | seller's balance with the marketplace | `seller_id, available, pending, on_hold, currency` | event-sourced from suborder + payout entries |
| `Payout` / `Disbursement` | money sent from operator to seller | `id, seller_id, amount, currency, method, status, scheduled_for, paid_at, provider_id` | scheduled → in_transit → paid (or failed → retried) |
| `PayoutSchedule` | seller's release cadence | `seller_id, frequency (daily/weekly/monthly), min_amount, hold_days_after_delivery, day_of_week?` | per seller, mutable |
| `Reserve` / `Rolling reserve` | operator-held buffer for chargeback risk | `seller_id, amount, currency, release_at` | held → released (or consumed by chargeback) |
| `Dispute` | buyer-vs-seller conflict | `id, suborder_id, opener (buyer/seller), reason, status, evidence[], resolution, opened_at, resolved_at` | opened → in_mediation → escalated → resolved (refund/release/partial) |
| `BankAccount` / `PayoutMethod` | where payouts land | `seller_id, type (bank/paypal/wallet), account_token (provider), country, currency, verified` | unverified → verified → active → revoked |
| `OnboardingStep` | tracks seller setup progress | `seller_id, step (kyc/bank/listings/policies/agreement), status, completed_at` | not_started → in_progress → complete |
| `Buyer` | the purchaser | `id, email, name` — usually NOT seller-scoped; one buyer profile across the marketplace | guest → registered |
| `MarketplaceAgreement` | T&Cs the seller accepts | `seller_id, version, accepted_at, ip, signed_pdf_url` | active version per seller; immutable record per acceptance |

## Status state machines

**Seller lifecycle:**
```
applied → in_review → approved → active → suspended → terminated
              ↓
           rejected
```

**Suborder:**
```
created → accepted → packed → shipped → delivered → released_for_payout
   ↓         ↓         ↓
cancelled cancelled cancelled (refund)
                              ↓
                          disputed → resolved
```

**Payout:**
```
scheduled → in_transit → paid
                ↓
             failed → retry_scheduled → (loop) → manual_intervention
```

**Dispute:**
```
opened → seller_response_pending → in_mediation → escalated → resolved
                                                                ↓
                                                       (refund / release / partial split)
```

## Vocabulary distinctions (don't conflate)

- **Order** vs **Suborder** — Order is what the buyer placed (one payment, one cart). Suborders are per-seller slices. A 3-seller cart = 1 Order + 3 Suborders.
- **Gross merchandise value (GMV)** vs **Net revenue** — GMV is the buyer-paid total. Net revenue (the operator's revenue) = sum of commissions, NOT GMV.
- **Take rate** vs **Commission rate** — Take rate is the operator's share of GMV (a metric). Commission rate is what's contractually charged to a specific seller (a config).
- **Available** vs **Pending** vs **On hold** balance — Available = payable now. Pending = earned but inside the hold window (commonly 7-14 days post-delivery). On hold = blocked due to dispute/chargeback risk.
- **Payout** vs **Refund** — Payout is operator → seller. Refund is operator → buyer (and clawed back from seller's pending balance).
- **Chargeback** vs **Dispute** — Chargeback comes through the card network (Visa/MC), externally. Dispute is in-platform (buyer-vs-seller mediation).
- **KYC** (Know Your Customer) vs **KYB** (Know Your Business) — KYC is for individuals (sole-prop sellers). KYB adds entity verification (UBO, registration docs) for companies.
- **Marketplace facilitator** — a US tax-law term: states require the marketplace to collect sales tax on the seller's behalf. Different from "operator owns the storefront."

## Multi-currency notes

- Buyer currency, seller currency, settlement currency are 3 separate concerns.
- Lock the FX rate at order placement; store it on the suborder. Recomputing later = drift.
- Commission can be charged in seller's currency OR settlement currency — pick one and document; mixing causes reconciliation hell.

## Multi-tenancy variants

- **Single-marketplace** (Etsy-like): one operator hosts many sellers under one brand. No tenant boundary among sellers — they share the catalog UX.
- **Marketplace-as-a-service** (Mirakl-like): operator runs the platform; many "marketplace tenants" each host their own sellers. Tenant boundary at the marketplace level + seller level — two-tier scoping.
- **B2B vs B2C** marketplaces: B2B has RFQ flows, net-30 invoicing, bulk pricing, account managers. B2C has cart + instant pay. Don't conflate the data models.
