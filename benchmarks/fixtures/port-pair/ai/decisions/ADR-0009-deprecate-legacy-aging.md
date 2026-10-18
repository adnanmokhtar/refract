# ADR-0009 — Deprecate `GET /api/reports/legacy-aging`

Status: Accepted (2026-09-03)

Zero callers on all six reachability axes for 120 days: no app source, no test, no cron, no route
link from the portal or the mobile app, no infra rule, and zero requests in the access logs
(2026-05-01 → 2026-08-31). Not ported; ledger row F009 is `deprecated`.
