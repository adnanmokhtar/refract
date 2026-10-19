# Requirements: refund notifications

Run 2026-10-12-refund-notify · tier T2 · spec: ai/specs/refunds.md (AC-006)

### REQ-010 — Tell the customer and the merchant what happened to a refund

- AC-010: WHEN a refund completes THE system SHALL e-mail the customer a confirmation that states the refunded amount and currency.
- AC-011: WHEN a refund fails THE system SHALL notify the merchant quickly.
- AC-012: IF the e-mail provider rejects the confirmation THEN THE system SHALL retry it three times and record `refund_email_failed` on the order timeline.
