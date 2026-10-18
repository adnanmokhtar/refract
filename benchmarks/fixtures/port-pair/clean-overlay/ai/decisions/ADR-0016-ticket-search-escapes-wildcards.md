# ADR-0016 — Ticket search treats `%` and `_` literally

Status: Accepted

V1 put the raw term into `LIKE '%…%'`, so `_` matched any character and `%` matched everything.
V2 escapes both. `changes_baseline: ["tickets.search-literal-wildcards"]`.
