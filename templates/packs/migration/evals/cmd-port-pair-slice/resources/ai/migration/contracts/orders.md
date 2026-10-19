# Contract: orders (standard tier)

V1 pinned at the ledger row F001's `v1_commit_pinned`. Every claim cites `v1/<path>:<line>`.

## Inputs

- `GET /api/orders` — `page` (1-based, Laravel paginator), `per_page` (default 25, max 100),
  `status[]` (PHP bracket array, any of the six statuses). `v1/app/Http/Controllers/OrderController.php:21`
- `POST /api/orders` — `StoreOrderRequest` rules, trimmed and empty → null by the global
  middleware. `v1/app/Http/Requests/StoreOrderRequest.php:14`
- `PATCH /api/orders/{order}` — draft orders only. `v1/app/Http/Controllers/OrderController.php:57`

## Outputs (per code path)

- Happy path: `{ data: Order }`, `total` a 2-decimal string, `shipped_at` present and `null`
  until shipped. `v1/app/Models/Order.php:50`
- Not editable: 409 `{ message, code: "order_not_editable" }`. `v1/bootstrap/app.php:29`
- Validation: 422 `{ message, errors: { field: [..] } }` with every failing field.

## Known V1 bugs

- KB-1 (ADR-0011, `changes_baseline: orders.number-source`): order numbers are `max(id) + 1`
  inside the transaction, so two concurrent placements can collide and one answers 500.
  V2 uses a sequence; numbers may have gaps.
