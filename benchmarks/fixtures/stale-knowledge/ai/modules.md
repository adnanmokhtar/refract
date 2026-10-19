# Modules

The API's modules, one folder each under `apps/api/src/modules/`. Regenerate this table when a module is added or
removed; `ai/architecture.md` has the layering rules.

| Module | Folder | Owns |
|---|---|---|
| orders | `apps/api/src/modules/orders/` | orders, pricing, order placement |
| payments | `apps/api/src/modules/payments/` | payment capture and payment provider callbacks |
| catalog | `apps/api/src/modules/catalog/` | products and price lists |
| customers | `apps/api/src/modules/customers/` | customer accounts per tenant |
| inventory | `apps/api/src/modules/inventory/` | stock levels and reservations |
| shipping | `apps/api/src/modules/shipping/` | shipments and carriers |
| invoices | `apps/api/src/modules/invoices/` | invoice numbering and rendering |
| notifications | `apps/api/src/modules/notifications/` | e-mail notifications |
| auth | `apps/api/src/modules/auth/` | sessions and roles |
| users | `apps/api/src/modules/users/` | staff users per tenant |
| reports | `apps/api/src/modules/reports/` | monthly order reports |
| webhooks | `apps/api/src/modules/webhooks/` | outgoing webhook deliveries |
| coupons | `apps/api/src/modules/coupons/` | discount codes applied at checkout |
| audit-log | `apps/api/src/modules/audit-log/` | who changed what, per tenant |

## Flows

- Placing an order: `CreateOrderUseCase` checks the input, prices the lines and saves the order.
- Listing orders: the orders service pages by cursor inside the tenant scope.
- Invoicing: the invoices service renders totals with the `Money` value object.
