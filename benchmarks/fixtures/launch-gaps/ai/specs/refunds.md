# Refunds

Owner: Tomas Varga · Status: shipped 2026-09 · Source: support tickets SUP-112, SUP-140

Merchants refund counter and online orders from the order page. A refund goes back to the
original payment method; gift-card payments go back to the card's balance.

## Acceptance criteria

- **AC-001** WHEN a merchant refunds every line of a paid order THE system SHALL mark the order `refunded` and return the amount to the original payment method.
- **AC-002** WHEN a merchant refunds some lines of a paid order THE system SHALL refund only those lines and mark the order `partially_refunded`.
- **AC-003** WHEN a refund is issued THE loyalty ledger SHALL deduct the points the refunded lines awarded.
- **AC-004** Refunds should work properly for orders paid with gift cards.
- **AC-005** IF the payment provider rejects a refund THEN THE system SHALL leave the order unchanged and show the provider's reason to the merchant.
- **AC-006** WHEN a refund completes THE system SHALL queue a refund confirmation e-mail to the customer within 5 minutes (p95, from the provider's success callback to the queue write).

## Out of scope

Refunds to a different payment method; refunds older than 180 days.
