# ADR-0014 — Invoice audit rows are written by a database trigger

Status: Accepted (2026-09-15)

V1 wrote `invoice_audit` from `InvoiceObserver::updated`, so writes that bypassed Eloquent were
not audited. V2's migration `Migration20261002000000_invoice_audit` installs
`invoices_audit_trg`, which audits every writer. Same table, same columns, the same changed-columns-only
`changes` document. `changed_by` is filled from the `norrow.user_id` setting when the writer sets it and is
NULL otherwise; the acting user of an API change is also in `activity_log`.
`changes_baseline: ["invoices.audit-changed-by"]`.
