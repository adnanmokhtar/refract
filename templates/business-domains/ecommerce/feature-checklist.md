# Ecommerce — feature checklist

The 80%-of-projects-need-this list. Most ecommerce v1s ship missing several of these — they look "done" but customers churn out on the gap.

Use this in `business-auditor` reviews + as a P1/P2/P3 planning anchor.

## Customer-facing

### Catalog
- [ ] Product list with pagination + sort + basic filter (category, price).
- [ ] Product detail page (PDP) with: gallery, description, variants, price, stock indicator, "Add to cart", reviews, related products.
- [ ] Out-of-stock state — distinct from "draft" or "archived"; shows "Notify when available" CTA.
- [ ] Search box with autocomplete + typo tolerance.
- [ ] Category landing page with banner, description, filters.
- [ ] Empty-state UX on category with no products.
- [ ] SEO: per-product meta tags, structured data (`Product`, `Offer`, `Review` schema), canonical URLs.

### Cart
- [ ] Persistent cart (cookie or DB-backed for guests; user-backed for registered).
- [ ] Cart merging on login (guest cart + saved cart).
- [ ] Inline qty edit + remove + "save for later".
- [ ] Cart icon shows item count in header.
- [ ] Subtotal, shipping estimate, tax estimate, total — all visible before checkout.
- [ ] Promo code field with validation feedback.
- [ ] Empty-cart state with "continue shopping" CTA.

### Checkout
- [ ] Guest checkout (no forced signup).
- [ ] Saved addresses for registered users.
- [ ] Address auto-complete (Google Places, Mapbox, or local equivalent).
- [ ] Multiple shipping methods with rate calculation.
- [ ] Multiple payment methods (card minimum; wallets + BNPL +).
- [ ] Order review step before "Place order".
- [ ] Order confirmation page with order number.
- [ ] Confirmation email (transactional template).
- [ ] Mobile-optimized — most traffic is mobile.

### Account
- [ ] Sign up / sign in / forgot password.
- [ ] Order history with status + tracking link.
- [ ] Address book CRUD.
- [ ] Saved payment methods (provider tokens, never PANs).
- [ ] Email preferences (marketing on/off, notification channels).
- [ ] Account deletion (GDPR-required even if you're not in EU).

### Post-purchase
- [ ] Order tracking page (no login required via signed link).
- [ ] Status notifications (email + SMS + WhatsApp where applicable).
- [ ] Cancel button (when allowed by status).
- [ ] Return / refund request flow.
- [ ] Review prompt N days after delivery.

## Operator-facing (admin)

### Order management
- [ ] Order list with filter (status, date range, customer, value).
- [ ] Order detail with line items, customer, addresses, payment, shipments, history.
- [ ] Manual order creation (phone orders, B2B).
- [ ] Edit order (carefully — usually limited to: change shipping, add note, refund partial).
- [ ] Issue refund (full or partial; auto-syncs with provider).
- [ ] Mark as fulfilled / shipped / delivered.
- [ ] Print packing slip + invoice.
- [ ] Export to CSV / Excel for accounting.

### Catalog management
- [ ] Product CRUD with variants, images, descriptions, SEO fields.
- [ ] Bulk edit (price update across category).
- [ ] Bulk import via CSV.
- [ ] Inventory adjustment (manual + receipt-based).
- [ ] Category tree management.
- [ ] Draft / preview / publish workflow.

### Customer management
- [ ] Customer list with search + filter (lifetime value, last order, etc.).
- [ ] Customer detail: orders, addresses, lifetime value, notes.
- [ ] Add note to customer (visible to support).
- [ ] Block customer (fraud).

### Marketing
- [ ] Coupon CRUD with conditions (min spend, category, customer segment, usage limit).
- [ ] Promotion campaigns (sale period, banner, auto-apply rules).
- [ ] Email campaign integration (sync customers + segments to ESP).
- [ ] Abandoned cart automation.

### Reports
- [ ] Revenue today / yesterday / this week / month / YTD.
- [ ] Top products / categories.
- [ ] AOV (average order value), conversion rate, cart abandonment rate.
- [ ] Customer lifetime value distribution.
- [ ] Refund rate.

## Trust + compliance

- [ ] HTTPS site-wide (no exceptions).
- [ ] Privacy policy + terms of service + return policy + shipping policy pages.
- [ ] Cookie banner (GDPR / CCPA).
- [ ] PCI compliance: never see card data; use provider's hosted fields or token.
- [ ] Tax invoices for B2B / VAT regions.
- [ ] Receipts compliant with local rules (some countries require fiscal printers / e-invoice).
- [ ] Customer data deletion on request (GDPR Article 17).
- [ ] Audit log of admin actions on orders + customers + refunds.
- [ ] Rate limiting on auth + checkout (brute-force + scraping).

## Operational

- [ ] Status page or dashboard for stack health.
- [ ] Stripe / payment provider webhook handler — IDEMPOTENT.
- [ ] Carrier webhook handlers — idempotent.
- [ ] Backup + restore procedure (test annually).
- [ ] DR plan (cold spare DB at minimum).
- [ ] On-call rotation for Saturday-night order failures.

## Things v1s commonly miss

- Order tracking link in confirmation email (customers email support 3 days later).
- Refund flow (operators are stuck issuing refunds via provider dashboard, no audit trail).
- Empty states (cart, search no results, category no products) — looks broken.
- Cancel-before-fulfillment self-service (every cancel = support ticket).
- Mobile checkout polish (drop-off cliff at the address step).
- "Apply coupon" inside checkout (only at cart) — frustrates users who get the code mid-flow.
- Saving payment for later (90% of repeat checkout friction).
- Stock indicator on PDP ("Only 3 left") — drives urgency, also avoids angry "oversold" tickets.
- Per-region tax/shipping disclaimers ("does not include duties").
- Receipt download / re-send from order page.
- Search with no results → suggest categories or popular products instead of dead end.
- "Account deletion" (GDPR-mandated even for non-EU stores serving EU customers).
- Auditing: who changed an order's status? Operators screw this up; without a log, it's a black hole.

## Things often over-built in v1 (defer until validated)

- Loyalty programs.
- Subscriptions (unless that's the business model).
- Multi-currency (unless serving multiple countries).
- AR / virtual try-on.
- Live chat (chatbot is enough for v1).
- B2B-style net-30 invoicing.
