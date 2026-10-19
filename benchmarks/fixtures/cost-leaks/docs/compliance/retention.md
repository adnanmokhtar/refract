# Retention floors

Owner: compliance lead · last reviewed 2026-07-01. A shorter retention needs this page changed
first; a longer one needs a business reason recorded here.

| Data | Where | Kept | Why |
|---|---|---|---|
| Audit log | `audit_log` | 7 years | financial audit trail required by enterprise contracts and the bookkeeping retention period |
| Invoices | `invoices`, invoice PDFs | 10 years | tax law |
| Proof-of-delivery photos | `qw-prod-media`, `pod/` | life of the merchant account | merchant agreement § 7: evidence in carrier claims |
| Archived labels and manifests | `qw-label-archive` | life of the merchant account | merchant agreement § 9 |
| Webhook delivery attempts | `webhook_deliveries` | 30 days | support investigations only |
| Exports | `qw-prod-exports`, `exports/` | until downloaded | merchants download within days; nothing relies on old exports |
