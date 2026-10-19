# Billing

Every paid order produces one invoice. Invoice numbers are sequential per merchant, in the form
`TH-<year>-<sequence>`, and a number is never reused, even when an order is cancelled.

## Sending invoices

The invoice PDF is emailed to the customer when the order is paid, and it can be downloaded
again at any time. Amounts are stored and shown in integer minor units of the order's currency.

## Credit notes

A correction never edits an issued invoice. It issues a credit note against it, numbered in the
same sequence, and the next statement nets the two.

## Refunds

Refunds: TBD.

Back to the [home page](index.md).
