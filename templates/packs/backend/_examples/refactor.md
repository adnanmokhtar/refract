# Example: /refactor (backend)

User: `/refactor src/orders/order.controller.ts — flatten nested validation`

- Preserve HTTP status codes and JSON error shape vs sibling `product.controller.ts`.
- Apply `flatten-conditional` only inside the controller handler; delegate persistence changes to service layer only if siblings already do.
