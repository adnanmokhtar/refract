# ADR-0007 — Ticket ids

Status: Accepted (2026-08-20)

New V2 tickets get UUID primary keys. Migrated tickets keep their V1 integer id in `legacy_id`,
the API returns it as `id`, and `GET /api/tickets/{id}` resolves either form, so every e-mailed
`/tickets/123` link keeps working. `changes_baseline: ["tickets.id-shape-for-new-tickets"]`.
