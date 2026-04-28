# Ecommerce — domain-specific anti-patterns

Generic code review (DRY, SRP, etc.) misses these. They're traps you only learn by burning customers + revenue.

## Pricing + money

- **Floats for money.** `1.1 + 2.2 = 3.3000000000000003`. Always integer minor units (cents) or `Decimal` type. Never `Number` / `float` / `double`.
- **Currency mismatch in arithmetic.** Adding USD to EUR without conversion produces a wrong total. Type-tag your money: `Money { amount: number; currency: 'USD' }`. Operations enforce currency match.
- **Recomputing order totals on display.** Order totals are FROZEN at placement. Recomputing means a refund applied to a since-changed-price order shows the wrong amount. Store the snapshot.
- **Discount stacking accidents.** Two coupons + a sale + free shipping → -120% of order value. Define stacking rules + a max-discount-per-line invariant; enforce in cart logic.
- **Tax computed in cart but not at checkout.** Tax recomputes if address changes. Cart's estimate is informational; checkout owns the final number. Make this distinction visible to the user.

## Inventory + stock

- **Stock decremented at "Add to cart" without TTL.** Cart sits forever; phantom holds = customer-visible "out of stock" while units sit in dead carts. Either: hold at checkout-start (most cases) OR hold at cart-add WITH a TTL on cart items + reaper job.
- **Race conditions at "Place order".** Two customers, last unit. Optimistic lock on stock decrement OR DB-level unique reservation. Tested under load.
- **Negative stock.** A sloppy decrement without lower bound goes to -3. Constrain at the DB level (`CHECK (stock >= 0)`).
- **Reserved stock leaked.** Cancel order → decrement reservation. Forget = phantom stock holds. Reservations must be transactional with order state.

## Orders

- **Mutable line items post-placement.** Customer changes mind, line item updated, order total now drifts from payment captured. Lines are immutable — issue a refund + new order if needed.
- **Status as free-text.** `order.status = 'shippped'` (typo) silently breaks downstream. Use enum + DB CHECK constraint.
- **Status without a state machine.** `order.status = 'cancelled'` while `payment.status = 'captured'` and no refund. Define legal transitions; enforce in code AND in DB triggers (defense in depth).
- **No `Idempotency-Key` on Place Order.** Customer double-clicks → duplicate order, duplicate charge, support ticket nightmare. Always idempotent.
- **Operator edits to orders not audited.** Support changes shipping address; six months later customer disputes; "who changed it?" → silence. Every order mutation logs actor + before + after.

## Payments

- **Storing PANs.** Even encrypted, even briefly, even "in memory". PCI scope exposure. Use provider-hosted fields; your code never sees a PAN.
- **Webhook handler not idempotent.** Provider retries → double-credit, double-refund. Always check `event.id` against a processed-events set.
- **Webhook handler that throws and fails ack.** Provider escalates. Catch + log + ack; reprocess from a queue if needed.
- **No retry on intermittent capture failures.** Authorization succeeds, capture flakes; you've reserved on customer's card and not collected. Retry capture with backoff; alert if final failure.
- **Refund initiated outside the system.** Operator refunds via provider dashboard; your DB doesn't know; reports are wrong. Operator UI calls your refund endpoint, which calls provider — single source of truth.
- **Dispute window data deleted.** ~120 days. Don't delete shipping records / customer communications until past the window.

## Checkout

- **Address validation that's too strict.** Real addresses don't match Postal-Service-API perfectly. Soft validation (warn) > hard reject.
- **Required phone with no rationale.** Conversion-killer. Make it optional unless carrier truly requires.
- **Forced account creation.** Loses 30%+ of conversions. Guest checkout always.
- **Saved cards opt-in checked by default.** Dark pattern; lawsuits in EU.
- **Promo code field hidden.** Customer Googles "discount code <store>" → leaves to find → loses cart on return.
- **Promo code field too prominent.** Customers without one feel they're paying full price; conversion drop. Collapsed-by-default with a "Have a code?" link works.

## Cart

- **Anonymous cart not transferred on signup mid-flow.** User has 5 items as guest, signs up to checkout, cart vanishes. Merge logic must be reliable.
- **Cart cookie too short-lived.** Mobile users return after meetings; empty cart = abandonment. 30 days minimum.
- **Cart without expiry.** Carts from 2 years ago accrete in DB. TTL after 60-90 days.

## Email + notifications

- **Confirmation email not sent.** Customer doesn't know order placed; calls support; tickets pile up. Send immediately, retry on transient failure, fall back to in-app banner if user is logged in.
- **Tracking link missing in confirmation.** Customer waits → support ticket. Always include the link, even if shipment hasn't been created (link to order page that updates).
- **Email sent at the moment of action vs after commit.** Order confirmed but DB rolled back → email sent for non-existent order. Fire on `order.placed` event from a queue, after commit.
- **No unsubscribe on marketing emails.** CAN-SPAM violation in US, GDPR in EU; immediate fines.
- **Transactional sender mixed with marketing.** Bounce rates from marketing kill transactional deliverability. Separate IP pools / providers / domains.

## Shipping + fulfillment

- **Shipping cost calculated wrong on weight-based carriers.** Item weight defaults to 0 if not set; ship for free. Validate weight on product creation.
- **Address book with no country.** Addresses returned as US-format for non-US customers. Always country-first in the form; format dynamically.
- **Tracking updates polling instead of webhooks.** API quota burn + lag. Webhooks first; polling fallback for missing carriers.
- **Marking "delivered" without carrier confirmation.** Operator clicks delivered to clear queue → angry customer "where's my package?" Use carrier event as ground truth.

## Search + catalog

- **Search returns out-of-stock products without indication.** Customer adds to cart, sees out-of-stock at PDP, abandons. Mark in-stock vs out in search results.
- **Faceted filter leaks tenant boundaries.** In a multi-store stack, "all products in 'shoes'" returns from sibling stores. Tenant filter on every query.
- **Slug collisions.** Two products with same name → same slug → 404 / wrong product. Append a unique suffix or use ID-slugs.
- **No 301 on slug change.** SEO destroyed. Keep redirect history.
- **Product gone with no fallback.** Archived product → 404 from organic traffic. Show "this product is no longer available" + recommendations.

## Returns + refunds

- **Refund without restocking event.** Inventory is wrong. Restock as part of refund flow (or explicitly mark "scrap").
- **Partial refund logic that adjusts line totals incorrectly.** Customer refunded $10 on a $30 line; your reports show line at $20 sold. Refunds are events, not edits to original lines.
- **Return shipping cost subsidy without policy.** Customer returns a $5 lipstick that costs $8 to ship; you eat $3 + lose customer trust ("they should pay shipping"). Define free-vs-paid policy + display.
- **Restocking fee applied without disclosure.** Refund less than expected; chargeback dispute. Disclose in return policy + at request time.

## SEO + content

- **No structured data.** Missing rich results in Google. Add `Product`, `Offer`, `Review`, `BreadcrumbList`.
- **Pagination as `?page=N` without `rel=next/prev`.** Pagination penalty.
- **Faceted URLs all indexed.** `?color=red&size=L&sort=price-desc` → infinite duplicate pages. `noindex,follow` on faceted; `index,follow` on canonical category.

## Analytics + tracking

- **Tracking script blocking the page.** PageSpeed kills conversion. Tag manager async; defer non-critical.
- **PII in event payloads to analytics.** GDPR violation. Hash emails + scrub.
- **Conversion tracking missing one step.** Funnel data has phantom drops; can't optimize. End-to-end test the funnel quarterly.

## Operational

- **Test orders polluting production reports.** Distinguish test mode (provider test keys + flag on order) and exclude from real numbers.
- **Cron jobs that run on every node in a cluster.** Race conditions, double-charges. Use a leader-elected scheduler.
- **Email service provider rate limit hit during sale.** Send queue stalls; abandonment cart drips delayed by hours. Pre-warm sending; use multiple ESPs for sale spikes.
- **DB indexes missing on foreign-key joins.** Order list page takes 30s. Index `orders.customer_id`, `orders.status`, `(tenant_id, placed_at DESC)` etc.
- **No archival policy.** `order_items` table at 500GB; queries slow. Hot table for last 90 days; archive table for older. Or partition.
- **Backup not tested.** Restore time = 6 hours when prod is down. Annual restore drill.

## Trust + UX

- **No "About Us" page.** Customers don't trust ghost stores. Photos of team, address, registration number.
- **Returns policy buried.** Conversion killer. Link in cart + checkout + confirmation email.
- **Customer support hidden.** No phone, no email, only chatbot. Trust evaporates after first issue.
- **Checkout that demands signup mid-flow.** Loss-of-cart panic.
- **Loading states absent.** Customer clicks Place Order, nothing visibly happens, clicks again → duplicate order or perceived hang.

## Multi-language / localization

- **Hard-coded English strings.** Customer in Riyadh sees "Add to cart" in English. Externalize all UI strings.
- **Date / currency / number formats hard-coded.** `$1,234.56` in a French-locale store should be `1 234,56 €`.
- **RTL layout breakage.** Arabic / Hebrew sites with `margin-left: 8px` everywhere = visual mess. Use logical properties (`margin-inline-start`).
- **Address forms not regional.** Japan addresses don't fit "street + city + state + zip" template. Either per-country form or a generic enough one.
