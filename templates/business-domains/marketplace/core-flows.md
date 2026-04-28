# Marketplace — core flows

The flows every marketplace must support. P1 is "without these, you don't have a marketplace." P2 = retention + trust. P3 = scale.

## P1 — must-have for v1

### 1. Seller onboarding → KYC → approval → first listing

```
Seller signs up
  → fills business profile (legal name, country, type)
  → KYC submission (ID + selfie OR business docs + UBO)
  → KYB if entity (registration cert, articles)
  → bank account / payout method (provider tokenizes, micro-deposits or instant verify)
  → accepts marketplace agreement (versioned T&Cs, IP + timestamp logged)
  → operator review (or auto-approval below thresholds)
  → status = active
  → can create listings
```

Invariants:
- Cannot list before `kyc_status = approved` AND `payout_method_verified = true`.
- KYC re-verification triggered at: country change, legal-name change, threshold crossings (e.g. >$10k cumulative payouts).
- Agreement version stored at acceptance — if T&Cs change, seller must re-accept on next login.

### 2. Listing creation → moderation → published

```
Seller creates listing (title, images, price, stock, category)
  → category-specific compliance check (restricted goods, regulated)
  → automated moderation (image, copy, prohibited keywords)
  → manual queue if flagged
  → operator approves / rejects with reason
  → listing.status = active → visible in catalog
```

- Approval can be tiered: trusted sellers auto-publish; new sellers always queued.
- Edits to active listings re-enter moderation if they touch price > X% delta or core fields.

### 3. Buyer browses → adds items from N sellers → checkout (single payment) → orders split per seller

```
Buyer adds items: 2 from Seller A, 1 from Seller B
  → cart shows grouped by seller (with each seller's shipping options)
  → checkout: ONE payment for the total
  → on payment success:
       Order created
       Suborder A created (Seller A's items, A's shipping)
       Suborder B created (Seller B's items, B's shipping)
       Commission rows computed per suborder
       Payment captured ONCE (provider holds funds in operator's account, escrow style)
  → buyer sees one order; each suborder fulfilled independently
```

Critical invariants:
- Buyer pays ONCE. Single charge. Marketplace splits internally — never re-charge the buyer.
- Each suborder = one seller, one shipping address (buyer's), N line items.
- Commission rule snapshot taken AT placement (rate could change next week; this suborder is locked).
- FX rate snapshot taken at placement if multi-currency.
- Idempotency-Key on Place Order — splits AND charges must be exactly-once.

### 4. Seller fulfillment per suborder

```
Suborder.created → notification to seller
  → seller accepts (within SLA, e.g. 48h, else auto-cancel)
  → seller marks packed
  → seller buys label / uses platform-provided label
  → seller marks shipped + tracking #
  → carrier webhook → delivered
  → suborder.status = delivered
  → hold timer starts (e.g. 7 days post-delivery)
  → on timer expiry: seller's pending balance → available
```

Per-seller fulfillment, per-seller SLA, per-seller cancellations. Other sellers' suborders unaffected when one seller fails.

### 5. Commission calculation + ledger entry

```
On suborder placement:
  rule = lookup_rule(seller_id, category_id, listing_id, placed_at)
  commission_amount = round(subtotal * rule.rate + rule.fixed_fee, currency_minor_units)
  payout_amount = subtotal - commission_amount - tax_remitted_by_marketplace
  ledger:
    seller.pending += payout_amount
    operator.revenue += commission_amount
    operator.tax_payable += tax_collected (if marketplace facilitator)
```

- Rounding policy explicit (banker's vs HALF_UP) — and consistent across reports.
- Commission is computed once at placement and stored. Refunds recompute via an inverse ledger entry, NOT by mutating the original.

### 6. Payout schedule + disbursement

```
Cron / scheduler runs per seller frequency:
  available_balance = wallet.available
  if available_balance >= seller.min_payout AND seller.kyc_active AND no_open_disputes_above_threshold:
       payout = create(seller, available_balance, scheduled_for=today+1)
       wallet.available -= payout.amount
       wallet.pending_payout += payout.amount
       provider.payout(seller.bank_token, amount, idempotency_key=payout.id)
  on provider webhook payout.paid:
       payout.status = paid
       wallet.pending_payout -= amount
  on payout.failed:
       wallet.available += amount  (reverse)
       payout.status = failed
       alert seller + ops
```

Critical: idempotency on the provider call. Re-running the cron must NOT double-pay.

### 7. Refund flow with commission clawback

```
Buyer requests refund OR seller approves return
  → refund initiated against original payment (full or partial)
  → on provider refund success:
       suborder.refund_total += amount
       commission row: write inverse entry (operator gives back its share)
       seller.wallet: pending or available -= seller's share of refund
       if seller.balance < 0: debt_recovery process kicks in (next payouts garnished)
```

Rule: refund priority is buyer first (always pay buyer back fast); seller balance reconciliation can lag if needed.

### 8. Dispute resolution (buyer ↔ seller)

```
Buyer opens dispute on suborder (reason: not received, not as described, damaged)
  → suborder.status = disputed; payout HOLD on seller for that suborder amount
  → seller has SLA (e.g. 5 days) to respond with evidence
  → operator mediates → resolution:
       • full refund to buyer (seller eats it)
       • partial refund (split)
       • dismiss (release to seller)
  → ledger updates accordingly
  → hold released or consumed
```

## P2 — keep both sides

### 9. Seller dashboard
- Sales today / this week / month.
- Pending payout, next payout date, lifetime payouts.
- Order queue with SLA timers.
- Listings: active, pending review, suspended.
- Disputes: open, awaiting response, resolved.
- KYC status, document expiry warnings.

### 10. Buyer order experience
- Single order view BUT with per-seller shipment status visible.
- Per-seller messaging (buyer ↔ each seller).
- Per-seller review prompts post-delivery (one star rating per seller, not per item).
- Cancel before each seller ships (independent per suborder).

### 11. Reviews + seller reputation
- Buyer reviews seller (separate from product reviews).
- Aggregate seller score visible on listings (Etsy/eBay style).
- Disputed orders excluded from rating until resolved.
- Operators can suspend low-rated sellers per policy.

### 12. Messaging (buyer ↔ seller)
- In-platform messages, NOT email-forwarded (otherwise sellers + buyers go off-platform = lost commission).
- PII filter (block phone numbers, external email) — anti-circumvention.

### 13. Returns / RMA per seller
- Each seller sets their own return policy (or platform-mandated default).
- Customer initiates return → seller approves → label generated → package sent → seller inspects → refund issued.

### 14. Multi-currency display + settlement
- Buyer pays in their currency (operator collects, FX margin captured).
- Seller paid out in their bank's currency.
- Settlement: convert at payout time at provider's rate; record both rates for audit.

## P3 — scale + sophistication

### 15. Tiered commission rules
- Volume-based (lower rate above $10k/month).
- Category-based (different rates for electronics vs handmade).
- Promotion-based (operator absorbs commission for a sale period).
- Per-seller negotiated rates.

### 16. Promoted listings / on-platform ads
- Sellers pay to boost. Auction or fixed CPC.
- Separate billing from commissions (often pre-paid wallet).

### 17. Subscription / marketplace fees
- Monthly fee for premium seller tier.
- Listing fees per item (eBay model).
- Recurring debit from wallet or separate billing.

### 18. Bulk operations for sellers
- CSV listing upload.
- Bulk price update.
- Bulk inventory sync.
- API for ERP integration (large sellers).

### 19. Fraud detection
- Buyer fraud: stolen cards, mule accounts.
- Seller fraud: fake listings, drop-ship scams, account takeovers.
- Velocity rules + manual review queues.

### 20. Compliance scaling
- Marketplace facilitator tax collection per US state.
- VAT OSS / IOSS for EU.
- 1099-K / equivalent reporting to tax authorities for sellers above thresholds.

## Idempotency-critical endpoints

- `POST /orders` — split + charge must be exactly-once.
- `POST /payouts/run` — scheduler retries must not double-pay.
- `POST /refunds` — re-issuing must return the existing refund record.
- Provider webhook handlers — payouts/refunds/disputes redelivered repeatedly.

## Webhooks to produce

- `seller.approved`, `seller.suspended`.
- `listing.published`, `listing.suspended`.
- `suborder.placed`, `suborder.shipped`, `suborder.delivered`, `suborder.cancelled`.
- `commission.computed`.
- `payout.scheduled`, `payout.paid`, `payout.failed`.
- `dispute.opened`, `dispute.resolved`.

## Webhooks to consume

- Payment provider: charge, refund, chargeback.
- Payout provider: payout.paid, payout.failed, payout.returned.
- KYC provider: verification.completed, verification.requires_action.
- Carrier: tracking events.
