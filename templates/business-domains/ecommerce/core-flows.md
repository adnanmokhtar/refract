# Ecommerce — core flows

The flows every ecommerce product must support end-to-end, in priority order. P1 is "without these, you don't have an ecommerce product." P2 is "you need these to keep customers." P3 is "competitive advantage."

## P1 — must-have for v1

### 1. Browse → add to cart → checkout → pay → confirm
The single most important flow. Failure here = no revenue.

```
Customer lands on PDP (product detail page)
  → selects variant (size/color)
  → "Add to cart" (cart created if absent; CartItem inserted)
  → opens cart → sees subtotal + shipping estimate + tax estimate
  → "Checkout"
  → enters shipping address (or selects saved)
  → selects shipping method (calculated rates)
  → enters billing address
  → enters payment (card / wallet / BNPL)
  → confirms order
  → order created (status=placed)
  → payment captured (status=paid)
  → confirmation email sent
  → redirect to /order/<id> with confirmation
```

Key invariants:
- Stock checked at "Add to cart" AND at "Place order" (race condition between cart creation and checkout).
- Price snapshot taken at order placement (not "current price" later).
- Idempotency on "Place order" — double-clicks must not create two orders. Use `Idempotency-Key` header or hash of cart contents.
- Tax + shipping shown before "Confirm" — surprise-free.

### 2. Order fulfillment
```
Order placed (paid)
  → fulfillment system picks order
  → inventory reserved (or already reserved at cart-add — depends on policy)
  → packed
  → shipping label created
  → carrier picks up
  → tracking updates pushed (webhook from carrier)
  → delivered (final state)
```

### 3. Order tracking
Customer must be able to:
- See order status without logging in (signed link in email).
- See current shipment status.
- Get notified on status change (email + SMS + WhatsApp depending on stack).

### 4. Cancel order (pre-fulfillment)
- Customer-initiated until `picked` status.
- Auto-refund payment.
- Auto-release reserved inventory.

### 5. Refund (post-fulfillment)
- Operator-initiated (or rule-based for "return window").
- Partial vs full refund.
- Restock or write-off (configurable).
- Refund payment via the same provider channel as original payment.

## P2 — keep customers

### 6. Account creation + login
- Guest checkout works (no signup required).
- Account "claimed" later via email confirmation if guest used same email.
- Address book persists across orders.

### 7. Customer support / order issues
- "Where's my order?" inbound (chat / email / WhatsApp).
- Operator can view order, refund, replace, mark as lost.
- Audit log of every operator action on an order.

### 8. Returns
- Customer-initiated return flow (RMA — return merchandise authorization).
- Return shipping label generated.
- On receipt: inspect → refund or reject.
- Restock or scrap.

### 9. Reviews
- Post-purchase prompt (verified purchase only).
- Moderation queue.
- Display on PDP.
- Affects search ranking + conversion.

### 10. Wishlist / save for later
- Per-customer (registered) or per-session (guest).
- Notify on price drop / back-in-stock if customer opted in.

## P3 — growth

### 11. Promotions / discounts
- Code-based coupons (`SAVE20`).
- Cart-level rules (free shipping over $50).
- Item-level (BOGO).
- Customer-segment-targeted (first-purchase, abandoned-cart recovery, VIP).

### 12. Abandoned cart recovery
- Cart abandoned for >1h with email captured → email sequence.
- Segment by cart value (high-value gets human follow-up).

### 13. Email marketing integration
- Customer events sent to ESP (Klaviyo / Mailchimp / Customer.io / SES).
- Order, abandoned cart, browse, post-purchase events.

### 14. Search + filtering
- Faceted search by category / price / attributes.
- Typo-tolerant (Algolia / Meilisearch / Elastic / Postgres FTS).
- Personalized ranking (recently viewed, customer history) — late-stage.

### 15. Recommendations
- "Customers also bought".
- "Recently viewed".
- "Bundle and save".
- Collaborative filtering or simple co-purchase counts.

### 16. Multi-currency / multi-region
- Display currency negotiated from header / IP / preference.
- Pricing rules per country.
- Tax rules per country.
- Shipping zones.
- Compliance: GDPR (EU), CCPA (CA), local consumer protection.

## Checkout-specific concerns

- **Single-page vs multi-step**: single-page reduces drop-off; multi-step can carry more fields. Most modern stores use single-page.
- **Saved payment methods**: PCI scope — store tokens via provider, never PANs.
- **3DS / SCA**: required in EU; provider handles UI but you handle the redirect dance.
- **Buy now, pay later**: Klarna, Affirm, Tabby, Tamara — provider integration similar to card.
- **Apple Pay / Google Pay**: shortcuts checkout; high conversion lift on mobile.
- **Inventory reservation policy**: hold at cart-add (high abandonment risk for limited stock) or hold at checkout-start (better for hot SKUs). Document the choice in an ADR.

## Webhooks the system must produce

- `order.placed` — to fulfillment, ESP, analytics.
- `order.paid` — same.
- `order.fulfilled` — to customer notification, analytics.
- `order.shipped` — same + carrier API.
- `order.delivered` — review prompts, post-purchase email.
- `order.cancelled` — analytics.
- `order.refunded` — accounting, analytics.
- `payment.failed` — recovery flow.

## Webhooks the system must consume

- Payment provider: `charge.succeeded`, `charge.failed`, `charge.refunded`, `charge.dispute.created`.
- Carrier: tracking updates.
- Tax provider (TaxJar / Avalara): tax rate updates.

## Idempotency-critical endpoints

- `POST /orders` — double-click on Place Order = catastrophe. Use `Idempotency-Key` header.
- `POST /orders/:id/cancel` — re-cancel must be safe.
- `POST /orders/:id/refund` — re-refund must be safe (return same refund record).
- Payment provider webhook handler — same event delivered multiple times.
