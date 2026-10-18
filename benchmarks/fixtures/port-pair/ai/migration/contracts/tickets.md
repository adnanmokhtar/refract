# Contract: tickets (standard tier)

V1 pinned at the ledger row F003's `v1_commit_pinned`.

## Inputs

- `GET /api/tickets?q=` — subject search, `LIKE '%q%'`. `v1/app/Http/Controllers/TicketController.php:17`
- `POST /api/tickets`, `GET /api/tickets/{ticket}`, `PATCH` (agent or admin), `POST …/reopen`,
  `POST /api/tickets/next` (agent or admin).
- Tag suggestions (`GET /api/tags?prefix=`, V2 only, typeahead): order unspecified; the picker
  sorts client-side and nothing else reads the list.

## Outputs (per code path)

- `{ data: Ticket }`: `priority` as the integer 1–4, `tags` always an array (empty when none),
  `due_at` null when unset. `v1/app/Models/Ticket.php:54`

## Known V1 bugs

- none recorded
