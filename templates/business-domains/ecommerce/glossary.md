# Ecommerce — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `ecommerce`:

**Entity / model names**: `Product`, `Variant`, `Cart`, `CartItem`, `Order`, `OrderItem`, `LineItem`, `Customer`, `Shipment`, `Refund`, `Discount`, `Coupon`, `Price`, `Tax`, `Inventory`, `Stock`, `Address`, `Wishlist`, `Review`.

**Folder / route names**: `shop/`, `store/`, `cart/`, `checkout/`, `orders/`, `products/`, `catalog/`, `wishlist/`, `/checkout`, `/cart`, `/orders/[id]`, `/products/[slug]`.

**Dependencies (any language)**: `stripe`, `paypal`, `medusajs`, `commercejs`, `swell`, `vendure`, `saleor`, `bagisto`, `magento`, `shopify-api`, `tax-rates`, `shipengine`, `easypost`.

**Database schema**: tables for `orders` + `order_items` + `products` + `customers` is the strongest signal.

**Distinguishing from marketplace**: ecommerce = single seller (the operator). Marketplace = many sellers + commissions + payouts. If you see a `Seller` / `Vendor` / `Merchant` entity with payout fields → marketplace, not ecommerce.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Product` | the catalog item | `id, sku, name, description, price, currency, status (draft/active/archived), category_id` | created → active → archived |
| `Variant` | sub-SKU of a product (size/color) | `id, product_id, sku, attributes (json), price_override?, stock` | follows product |
| `Inventory` | stock counts per variant per location | `variant_id, location_id, on_hand, reserved, available = on_hand - reserved` | event-driven (reservations + receipts) |
| `Cart` | the user's session-scoped basket | `id, user_id?, anonymous_token?, currency, created_at, expires_at` | active → abandoned → converted (to order) |
| `CartItem` | line in a cart | `cart_id, variant_id, qty, price_at_add` | mutable until checkout |
| `Customer` | end-user buyer | `id, email, phone, name, addresses[], default_shipping, default_billing` | guest → registered → returning |
| `Order` | confirmed purchase | `id, customer_id, status, total, currency, billing_address, shipping_address, placed_at` | placed → paid → fulfilled → delivered → completed (or cancelled / refunded) |
| `OrderItem` | line in an order | `order_id, variant_id, qty, unit_price, line_total` | immutable post-placement |
| `Payment` | money received | `id, order_id, provider, provider_id, amount, currency, status, captured_at` | authorized → captured → refunded |
| `Shipment` | physical delivery | `id, order_id, carrier, tracking_number, status, shipped_at, delivered_at` | label_created → in_transit → delivered |
| `Refund` | money returned | `id, order_id, payment_id, amount, reason, status, refunded_at` | requested → approved → processed |
| `Discount` / `Coupon` | promotional reduction | `code, type (percent/fixed/bogo), value, conditions, usage_limit, expires_at` | active → expired |
| `Tax` | applied per region | computed at checkout based on shipping address + product category | not stored as entity in most cases |
| `Wishlist` | saved products for later | `customer_id, items[]` | persistent |
| `Review` | post-purchase feedback | `customer_id, product_id, rating, body, verified_purchase, status` | pending → approved → published |

## Status state machines

**Order:**
```
placed → paid → fulfilled → shipped → delivered → completed
   ↓        ↓        ↓
cancelled cancelled cancelled (refund)
```

**Payment:**
```
pending → authorized → captured → settled
                 ↓          ↓
              voided     refunded
```

**Shipment:**
```
label_created → picked_up → in_transit → out_for_delivery → delivered
                                                  ↓
                                           returned_to_sender
```

## Vocabulary distinctions (don't conflate)

- **Cart total** vs **Order total** — cart total recomputes; order total is frozen at placement.
- **Price** vs **Unit price** vs **Line total** — Price is per-unit current; UnitPrice is per-unit at order time; LineTotal = UnitPrice × qty.
- **Discount** vs **Coupon** vs **Promotion** — Promotion is the rule; Coupon is a code that triggers a Promotion; Discount is the applied amount on a line/order.
- **Stock** vs **Available** — Stock is on-hand; Available = Stock − Reserved (cart holds + pending shipments).
- **Refund** vs **Return** vs **Chargeback** — Refund: we initiated. Return: customer sent goods back. Chargeback: customer disputed via card network.
- **Customer** vs **User** — Customer is the buyer profile (with addresses, orders); User is the auth identity (could be admin, staff, customer).
- **SKU** vs **Variant ID** — SKU is human-readable (`SHIRT-RED-M`); Variant ID is the internal UUID.

## Multi-tenancy variants

- **Single-tenant ecommerce**: one store. Tenant boundary = none.
- **Multi-store ecommerce** (chain): one operator, multiple storefronts. `store_id` on every entity.
- **Marketplace** (out of this domain — see `marketplace/`): many sellers, each with own catalog + payouts.
