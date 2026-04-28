# Marketplace — feature checklist

The 80%-of-projects-need-this list. Marketplaces have THREE customers (buyers, sellers, operator) and v1s usually short-change one of them.

## Buyer-facing

### Discovery
- [ ] Search across all sellers' listings (federated index).
- [ ] Seller storefronts (each seller has a vanity URL + branded page).
- [ ] Filter by seller rating, location, shipping speed, ships-from.
- [ ] "Verified seller" badge / trust signals.
- [ ] Same product offered by multiple sellers — show price + seller comparison ("Buy Box" or list).

### Cart + checkout
- [ ] Multi-seller cart with grouping by seller.
- [ ] Per-seller shipping rates + ETAs.
- [ ] Single payment for the total (one charge, even with N sellers).
- [ ] Per-seller subtotals visible at checkout.
- [ ] Coupon scoping clear (seller-specific vs platform-wide).

### Post-purchase
- [ ] Order page shows N parallel suborders, each with its own status + tracking.
- [ ] Cancel per seller (cancelling Seller A's items doesn't touch Seller B's).
- [ ] Message each seller from order page.
- [ ] Return per seller (independent RMA flow per seller).
- [ ] Review per seller post-delivery + per product.

### Trust
- [ ] Seller rating + review count on listing + storefront.
- [ ] Dispute / "Buyer Protection" promise visible at checkout.
- [ ] Seller's ships-from country (EU buyers care about customs).
- [ ] Estimated delivery dates per seller, NOT averaged.

## Seller-facing (the seller dashboard is half the product)

### Onboarding
- [ ] Multi-step wizard with progress (KYC → bank → policies → first listing).
- [ ] KYC status with clear next-action when stuck (human-readable rejection reasons, not provider error codes).
- [ ] Document upload with retry on rejection.
- [ ] Saved draft state — sellers don't complete in one sitting.
- [ ] Test mode / sandbox before going live.

### Listings
- [ ] Listing CRUD with image upload (size limits, format checks, auto-resize).
- [ ] Variants (size, color) — most v1s skip this, kills sellers with apparel/SKU complexity.
- [ ] Bulk import via CSV.
- [ ] Inventory sync (manual at minimum; API for sophisticated sellers).
- [ ] Approval status with rejection reason + re-submit.
- [ ] Schedule publish (sale launches at midnight).

### Orders
- [ ] Order queue with SLA timers (must accept within X hours).
- [ ] Print packing slip + carrier label.
- [ ] Mark shipped with tracking input or carrier-provider integration.
- [ ] Bulk-mark-shipped (high-volume sellers).
- [ ] Order export to CSV.

### Money
- [ ] Earnings dashboard: today / week / month / lifetime.
- [ ] Pending balance + available balance + on-hold balance distinct.
- [ ] Payout history with status + provider receipt.
- [ ] Next payout date forecasted.
- [ ] Commission breakdown per order (what they paid).
- [ ] Tax document download (1099-K equivalent annually).

### Disputes
- [ ] Inbox of open disputes with SLA timer.
- [ ] Evidence upload (proof of delivery, comms, photos).
- [ ] Resolution outcome notification.

### Communication
- [ ] In-app messaging with buyers per order.
- [ ] Notification preferences (email, SMS, app push).

## Operator-facing (admin)

### Seller management
- [ ] Seller list with filter (KYC status, country, sales volume, dispute rate).
- [ ] Seller detail: profile, KYC docs, bank, listings, orders, payouts, disputes, audit.
- [ ] Approve / reject KYC with reason.
- [ ] Suspend / terminate with reason + automated comms.
- [ ] Override commission rate per seller.
- [ ] Set rolling reserve per seller.

### Listing moderation
- [ ] Moderation queue with SLA timer.
- [ ] Approve / reject / request-changes.
- [ ] Bulk reject by keyword or category.
- [ ] Trusted seller fast-track toggle.

### Order + payout oversight
- [ ] Order list with split visibility (parent + children).
- [ ] Force-cancel + refund (for fraud / regulator orders).
- [ ] Payout queue with manual hold/release.
- [ ] Failed payout retry queue.

### Disputes
- [ ] Mediator dashboard with both-side evidence.
- [ ] Resolution actions (refund / release / partial).
- [ ] Dispute analytics (rate per seller, per category, per country).

### Finance
- [ ] GMV vs net revenue dashboard.
- [ ] Commission report by category / seller / period.
- [ ] Payout report with bank reconciliation.
- [ ] Tax remittance report (marketplace facilitator states).
- [ ] Reserve balances + release schedule.

### Compliance
- [ ] KYC expiry tracking + auto-suspension on expiry.
- [ ] Sanctions screening on every onboarding.
- [ ] Suspicious activity reporting (SAR) export.
- [ ] T&C version management + forced re-acceptance.

## Trust + safety

- [ ] Off-platform circumvention detection (phone/email regex in messages).
- [ ] Fake review detection.
- [ ] Counterfeit reporting (brand owners report; takedown SLA).
- [ ] Restricted-goods enforcement (alcohol, weapons, regulated).
- [ ] Buyer protection escrow (funds held until delivered).

## Operational

- [ ] Webhook idempotency on payouts + refunds + disputes.
- [ ] Reconciliation job: ledger sum = sum(suborders) - sum(refunds) - sum(payouts).
- [ ] Daily settlement reconciliation with payment provider.
- [ ] Monitoring: payout success rate, KYC pass rate, dispute rate, time-to-first-listing.

## Things v1s commonly miss

- Splitting orders correctly when one seller is out of stock at capture (do you partially ship + refund the rest? do you cancel the whole order? define the policy).
- Per-seller cancellation (cancel button cancels everything → angry buyers).
- Hold window enforcement — paying out before delivery confirmation = exposure on returns.
- KYC expiry — passport expires, seller still gets paid out, regulator fines.
- Currency handling — paying out in USD when seller's bank is in EUR with no conversion = stuck money.
- Seller signup → first sale time. Friction here = fewer sellers stick. Measure it.
- Tax remittance for marketplace facilitator states — operator on the hook even if not collecting; massive fines.
- Reserve / clawback flow when seller balance goes negative (chargeback after payout). Without this, you eat the loss silently.
- Audit trail on commission rule changes — sellers will dispute "you changed my rate retroactively."
- Separate operator-of-record from seller-of-record (legal entity ambiguity confuses tax + consumer protection).

## Things often over-built in v1

- Fancy seller analytics (sellers want clear numbers, not heatmaps).
- Live messaging (in-app messages with email notification is enough).
- Algorithmic search ranking (start with recency + rating).
- Multi-warehouse fulfillment for sellers (they don't have multiple warehouses yet).
- Promoted-listings ads (only matters at scale).
- Subscription tiers for sellers (gate it later).
- White-label seller storefronts (vanity URL is enough until top sellers ask).
