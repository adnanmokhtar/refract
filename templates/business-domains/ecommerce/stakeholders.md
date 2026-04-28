# Ecommerce — stakeholders

Each stakeholder has different needs from the same system. Understanding their workflows informs which features to prioritize, which dashboards to build, and which permissions to scope.

## Customer (the buyer)

The reason the system exists. Without conversion, nothing else matters.

**Workflows:**
- Discover product (search / browse / ad / referral).
- Evaluate (PDP, reviews, photos, FAQs).
- Decide (cart, save for later, compare).
- Buy (checkout).
- Receive (track shipment, get notifications).
- Return / refund (when needed).
- Re-buy (account, saved methods, repeat orders).

**Pain points the system must solve:**
- "Will this fit?" — sizing guides, return policy clarity.
- "When will it arrive?" — accurate delivery estimates BEFORE checkout.
- "Is this real?" — reviews, social proof, trust badges.
- "Is my data safe?" — clear privacy + security communication.
- "Can I get help?" — visible contact options at every step.

**KPIs:**
- Time-to-add-to-cart (UX speed).
- Cart-to-checkout conversion.
- Checkout-to-purchase conversion.
- Repeat purchase rate.
- Customer satisfaction (CSAT, NPS).

## Operator / Merchant (the store team)

The people running the store day-to-day. Multiple roles often:

### Owner / founder
- Wants: revenue dashboards, growth metrics, P&L.
- Logs in once a day, checks numbers, drills only when something's off.
- Permissions: everything.

### Marketing manager
- Wants: campaign performance, top products, abandoned cart reports, coupon ROI.
- Daily user. Frustrated when she can't slice data.
- Permissions: read-only on orders, write on campaigns + coupons + content.

### Customer support
- Wants: order lookup by anything (order #, email, phone, name), refund button, edit address, send replacement.
- Heaviest user by hours. UX matters most for them.
- Permissions: order CRUD limited (no delete), customer read, refund up to limit.

### Fulfillment / warehouse
- Wants: pick list, pack slip, batch print, scan-to-pack, mark shipped.
- Often uses tablet or scanner — the UI must be touch + scanner friendly.
- Permissions: order read, status update only.

### Inventory manager
- Wants: stock levels, low-stock alerts, receive shipments, transfer between locations.
- Needs reconciliation tools (compare system vs physical count).
- Permissions: inventory CRUD.

### Accountant / finance
- Wants: orders + refunds + tax exports, monthly closing data, sales tax reports.
- Uses CSV / Excel. Will demand exports if not provided.
- Permissions: read-only on orders + reports.

### Admin / IT
- Wants: user management, integrations, settings, audit log.
- Permissions: everything (with audit).

**Friction points:**
- Reading orders is fast; mass-action across orders is slow without bulk select.
- Refunds need approvals above a threshold — workflow matters.
- "Show me all orders for this customer" — basic but often missing.
- Accountant exports — if missing, they'll bug engineering monthly.

## Vendor / Supplier

(For non-marketplace stores — your suppliers, not your sellers.)

- POs (purchase orders) sent to them.
- Receive shipments, scan in, reconcile.
- Pay them on terms.

Most stores manage suppliers in spreadsheets — building a portal is mid-stage maturity.

## Carrier / Logistics

- Receives shipment data (label requests).
- Sends tracking updates back.
- Integration is webhooks + API. They have ZERO interest in your portal — they want raw data.

**Pain points to anticipate:**
- API rate limits — batch requests where possible.
- Tracking webhooks late by hours sometimes — combine with polling fallback.
- Failed deliveries / address corrections — process for handling.

## Payment provider

Same shape as carrier — their systems consume + emit data; they don't use your UI.

**Critical interactions:**
- Tokenization (card → token).
- Capture / void / refund.
- Webhook event delivery (idempotent processing required).
- Dispute / chargeback handling.

## Customer service tooling (if external)

If you use Zendesk / Intercom / Front:
- Customer + order context must be available in their tool.
- Order lookup widget or sidebar app.
- Refund + replacement actions surfaced from the tool.

## Auditor / compliance officer

- Wants: audit logs, data retention proof, deletion proof on GDPR requests.
- Episodic user (during audits).
- Permissions: read-only across audit log + customer + order data with PII access logged.

## Marketing platforms (ESP, ads)

- Receive customer events (segmented).
- Push back: opt-out signals, bounce signals.
- Integration: streaming events out.

## Stakeholder-driven feature priorities

When deciding what to build:

| If user complaint is from... | Then priority is... |
|---|---|
| Customer support drowning in tickets | Self-service: order tracking, cancel, return flows |
| Owner can't see numbers | Reports + dashboards |
| Fulfillment is slow | Batch operations, pick list, scan-to-ship |
| Marketing ROI invisible | Campaign attribution, coupon analytics |
| Accountant manually exports | Scheduled reports + accounting integration |
| IT debugging by SSH | Audit log + admin UI for common ops |

## Anti-pattern: "the operator is also the engineer"

Founders early-stage often do all roles. Build admin UI assuming a non-engineer will use it 6 months later — labels in user vocabulary, not DB columns; safe defaults; confirmations on destructive actions; restoration paths.
