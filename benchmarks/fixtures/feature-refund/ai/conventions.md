# Conventions

These are the rules every change in this repo follows. Each names the place in the code that shows it.

## Money

- A money value is `Money` — `{ amountMinor, currency }`, built with `money()` from `src/money.js`.
  `amountMinor` is an integer count of minor units. Never a float, never major units, never a bare
  number without its currency — in storage, in a ledger entry, in a request body or in a response.
- Arithmetic goes through `addMoney()`; display goes through `formatMoney()`. Nothing divides by 100
  outside `formatMoney()`.
- Example: `payOrder()` in `src/orders.js` writes the charge entry with the order's `Money` total as is.

## Write endpoints

- Every `POST` route is wrapped in `withIdempotency()` in `src/routes.js` (see the cancel route). The
  client sends an `Idempotency-Key` header; a repeat with the same key returns the first response
  unchanged and does no work a second time. A missing key is a 400.
- A state change that the current status does not allow is a `409` with the reason.

## Tenancy

- A handler loads a record only through `requireOwnOrder()` (`src/tenancy.js`): unknown id → `404`,
  another tenant's record → `403`. `findOrder()` in `src/store.js` is tenant-blind and exists for the
  payment provider's callback only.

## UI

- Pages are render functions in `web/` returning HTML strings; every interpolated value goes through
  `escapeHtml()`.
- Every list section renders the shared `emptyState()` (`web/components/EmptyState.js`) when it has no
  rows — never a bare "No …" paragraph. See the Shipments section in `web/OrderDetails.js` and
  `web/OrderList.js`.

## Tests

- `node --test`, files in `tests/`, one file per feature. A write route is covered by: the happy path,
  the idempotent replay, the other tenant's record (403, nothing changed) and every refused state
  (409). `tests/cancel.test.js` is the model.
