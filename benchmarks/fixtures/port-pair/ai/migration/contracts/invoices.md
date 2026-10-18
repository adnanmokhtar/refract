# Contract: invoices (standard tier)

V1 pinned at the ledger row F002's `v1_commit_pinned`.

## Inputs

- `GET /api/invoices`, `GET /api/invoices/{invoice}` (policy `view`: same account and
  `invoices.view`), `GET /api/invoices/{invoice}/pdf`, `POST /api/invoices/{invoice}/issue`.

## Outputs (per code path)

- `{ data: Invoice }`: `subtotal`, `tax`, `total` as 2-decimal strings; tax rounded per line,
  half away from zero, then summed. `v1/app/Services/InvoiceService.php:12`
- `lines`: the invoice lines with a non-zero quantity. `v1/app/Models/Invoice.php:45`
- Issue: number `INV-<year>-<6 digits>` from `invoice_sequences`; the e-mail job is dispatched
  after commit. `v1/app/Services/InvoiceService.php:39`

## Known V1 bugs

- none recorded
