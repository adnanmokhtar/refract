# Modules — apps/web

## apps/web/src/features

| Module | Path | Owns |
|---|---|---|
| orders | `orders/` | order list, detail and actions |
| customers | `customers/` | customer lookup |
| checkout | `checkout/` | checkout flow |
| payments | `payments/` | saved payment methods |
| search | `search/` | global search |
| audit-log | `audit-log/` | the read-only audit trail |
| refunds | `refunds/` | refund requests |
| cart | `cart/` | the cart (Redux, moving to hooks) |
| reviews | `reviews/` | product reviews |
| catalog | `catalog/` | catalogue filters |
| settings | `settings/` | user settings |
| order-history | `order-history/` | past orders |
| reports | `reports/` | reports (wraps legacy-reports until ADR-0009's date) |

Each feature exposes `index.ts`; other features import the barrel only.
