# Parity audit: orders
> V1 path: v1/routes/api.php
> V2 path: src/orders/orders.controller.ts
> Tier: trivial
> Verdict: PARITY

## Findings
### 1. Endpoints
GET and DELETE on the orders collection match V1.
### 2. Auth + permissions
Both routes are guarded in V2.
